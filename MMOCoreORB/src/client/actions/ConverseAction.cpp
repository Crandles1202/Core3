/*
 * ConverseAction.cpp
 *
 * Talks to an NPC: starts the conversation, optionally picks a sequence of options, and
 * records what the NPC said (core.vars "Conversation/transcript", also logged).
 *
 *   --converse <npcOid> [--options 0,2,1] [--converse-timeout <sec>]
 *   JSON: {"action":"converse","npc":123,"options":[0,2],"timeout":5}
 *
 * Option indexes are 0-based positions in the option list the server sent for the current
 * screen. The conversation is closed at the end unless the NPC already closed it.
 * Needs ZonePacketHandler's ObjController decoding (0xDD/0xDF/0xE0/0xDE).
 */

#include "client/ActionBase.h"
#include "client/ActionResult.h"
#include "client/ActionManager.h"
#include "client/ClientCore.h"
#include "client/zone/Zone.h"
#include "client/zone/ZoneClient.h"
#include "engine/service/proto/BaseMessage.h"

// same wire format as CommandAction's ClientCommandQueueEnqueue
class ConverseCommandQueueEnqueue : public BaseMessage {
public:
	ConverseCommandQueueEnqueue(uint64 playerOid, uint32 actionCount, uint32 actionCRC, uint64 targetOid, const UnicodeString& arguments) {
		insertShort(0x05);
		insertInt(0x80CE5E46);
		insertInt(0x23);
		insertInt(0x116);
		insertLong(playerOid);
		insertInt(0);
		insertInt(actionCount);
		insertInt(actionCRC);
		insertLong(targetOid);
		insertUnicode(arguments);
	}
};

class ConverseAction : public ActionBase {
	String npcSpec;
	Vector<int> options;
	int timeoutSeconds;

	ActionResult result;
	bool skipped;
	int screensSeen;

	static uint32 nextActionCount() {
		static AtomicInteger counter(5000);
		return counter.increment();
	}

	void sendCommand(ClientCore& core, const String& name, uint64 target, const String& args) {
		core.zone->getZoneClient()->sendMessage(new ConverseCommandQueueEnqueue(
			core.selectedCharacterOid, nextActionCount(), name.toLowerCase().hashCode(), target, UnicodeString(args)));
	}

	// wait until the option list changes (new screen) or the NPC closes the conversation
	bool waitForScreen(ClientCore& core, int previousCount) {
		int waited = 0;
		while (waited < timeoutSeconds * 1000) {
			if (!core.getVar<bool>("Conversation/active", false) && core.hasVar("Conversation/npc"))
				return true;
			if (core.hasVar("Conversation/optionCount") && core.getVar<int>("Conversation/optionCount", -1) != previousCount)
				return true;
			Thread::sleep(50);
			waited += 50;
		}
		return false;
	}

	void logScreen(ClientCore& core) {
		screensSeen++;
		info() << "screen " << screensSeen << ": " << core.getVar("Conversation/message", String("<no text>"));
		int count = core.getVar<int>("Conversation/optionCount", 0);
		if (count < 0) count = 0;   // the option list never came (a screen that closes at once)
		for (int i = 0; i < count; ++i) {
			info() << "   [" << i << "] " << core.getVar("Conversation/options/" + String::valueOf(i), String(""));
		}
	}

public:
	ConverseAction() : timeoutSeconds(5), skipped(false), screensSeen(0) {
		setLogLevel(Logger::INFO);
		setLoggingName("Converse");
	}

	const char* getName() const override { return "converse"; }
	bool needsZone() const override { return true; }
	bool needsTarget() const override { return true; }
	bool needsCharacter() const override { return true; }

	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		ConverseAction* me = nullptr;
		int i = startIndex;

		while (i < args.size()) {
			int lastConsumed = consumed;

			if (args.get(i) == "--converse" && i + 1 < args.size()) {
				if (me != nullptr) break;
				me = new ConverseAction();
				me->npcSpec = args.get(i + 1);
				consumed += 2; i += 2;
			} else if (me != nullptr && args.get(i) == "--options" && i + 1 < args.size()) {
				StringTokenizer tok(args.get(i + 1));
				tok.setDelimeter(",");
				while (tok.hasMoreTokens())
					me->options.add(tok.getIntToken());
				consumed += 2; i += 2;
			} else if (me != nullptr && args.get(i) == "--converse-timeout" && i + 1 < args.size()) {
				me->timeoutSeconds = Integer::valueOf(args.get(i + 1));
				consumed += 2; i += 2;
			}

			if (consumed == lastConsumed) break;
		}

		if (me != nullptr)
			result.add(me);

		return result;
	}

	static ActionBase* fromJSON(const JSONSerializationType& config) {
		ConverseAction* me = new ConverseAction();
		if (config.contains("timeout")) me->timeoutSeconds = config["timeout"].get<int>();
		if (config.contains("npc")) {
			if (config["npc"].is_string())
				me->npcSpec = String(config["npc"].get<std::string>().c_str());
			else
				me->npcSpec = String::valueOf(config["npc"].get<uint64>());
		}
		if (config.contains("options")) {
			for (auto& o : config["options"])
				me->options.add(o.get<int>());
		}
		return me;
	}

	void run(ClientCore& core) override {
		if (core.zone == nullptr || !core.zone->isConnected() || !core.zone->isSceneReady()) {
			result.setError("Not in the zone (converse needs a zoned-in character)", 1);
			return;
		}

		uint64 npc = UnsignedLong::valueOf(npcSpec);
		if (npc == 0) {
			result.setError("--converse needs the NPC's object id", 2);
			return;
		}

		// reset state from any earlier conversation
		core.vars.erase("Conversation");
		core.vars[JSONSerializationType::json_pointer("/Conversation/transcript")] = JSONSerializationType::array();

		info() << "starting conversation with " << npc;
		sendCommand(core, "npcconversationstart", npc, "");

		if (!waitForScreen(core, -1) || !core.hasVar("Conversation/npc")) {
			result.setError("NPC " + String::valueOf(npc) + " did not start a conversation within " + String::valueOf(timeoutSeconds) + "s (out of range? not conversable?)", 3);
			return;
		}
		// waitForScreen returned on the option list (optionCount left -1 by the start packet until the StringList
		// lands) or on the close; a short pause lets the message text settle too
		Thread::sleep(100);
		logScreen(core);

		for (int i = 0; i < options.size(); ++i) {
			if (!core.getVar<bool>("Conversation/active", false)) {
				result.setError("Conversation ended before option " + String::valueOf(options.get(i)) + " could be picked", 4);
				return;
			}

			int pick = options.get(i);
			int count = core.getVar<int>("Conversation/optionCount", 0);
			if (count < 0) count = 0;
			if (pick < 0 || pick >= count) {
				result.setError("Option " + String::valueOf(pick) + " out of range (screen has " + String::valueOf(count) + ")", 5);
				return;
			}

			info() << "picking [" << pick << "] " << core.getVar("Conversation/options/" + String::valueOf(pick), String(""));
			core.vars[JSONSerializationType::json_pointer("/Conversation/transcript")].push_back(
				std::string("ME: ") + core.getVar("Conversation/options/" + String::valueOf(pick), String("")).toCharArray());

			// clear the option count so a same-sized next screen still counts as a change
			core.setVar("Conversation/optionCount", -1);
			sendCommand(core, "npcconversationselect", npc, String::valueOf(pick));

			if (!waitForScreen(core, -1)) {
				result.setError("No reply to option " + String::valueOf(pick) + " within " + String::valueOf(timeoutSeconds) + "s", 6);
				return;
			}
			Thread::sleep(300);
			if (core.getVar<bool>("Conversation/active", false))
				logScreen(core);
			else
				info() << "NPC closed the conversation";
		}

		if (core.getVar<bool>("Conversation/active", false)) {
			sendCommand(core, "npcconversationstop", npc, "");
			Thread::sleep(200);
		}

		result.setSuccess();
	}

	bool isOK() const override { return !skipped && result.isOK(); }
	String getError() const override { return result.getError(); }
	uint16 getErrorCode() const override { return result.getErrorCode(); }
	void setSkipped() override { skipped = true; }

	JSONSerializationType toJSON() const override {
		JSONSerializationType json;
		json["action"] = getName();
		json["npc"] = npcSpec.toCharArray();
		JSONSerializationType opts = JSONSerializationType::array();
		for (int i = 0; i < options.size(); ++i) opts.push_back(options.get(i));
		json["options"] = opts;
		json["screens"] = screensSeen;
		if (skipped) {
			json["status"] = "skipped";
		} else if (result.isOK()) {
			json["status"] = "ok";
		} else {
			json["status"] = "failed";
			json["error"] = result.getError().toCharArray();
			json["errorCode"] = result.getErrorCode();
		}
		return json;
	}

	String getHelpText() const override {
		return "--converse <npcOid> [--options 0,2,1] [--converse-timeout <sec>]  Talk to an NPC and walk its conversation";
	}

	static ActionBase* factory() { return new ConverseAction(); }
};

static bool _registered_converse =
	(ActionManager::registerAction("converse", ConverseAction::factory, ConverseAction::fromArgs, ConverseAction::fromJSON), true);
