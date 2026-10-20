/*
 * ChatActions.cpp — say, tell, emote (Phase 7.0, Final Boss)
 *
 * The three ways a player talks, sent the way the real client sends them:
 *
 *   --say <text> [--say-target <oid>] [--say-mood <n>] [--say-language <n>]
 *       spatial chat: the "spatialchatinternal" queue command with "<target> <chatType> <mood> <flags> <language> <text>"
 *       JSON: {"action":"say","text":"...","target":0,"mood":0,"language":0}
 *   --tell <first name> <text>
 *       a ChatInstantMessageToCharacter packet; waits for the server's ChatOnSendInstantMessage verdict
 *       (0 delivered, 4 no such player, 5 offline, 6 ignored — stored as Tell/c<seq>/result)
 *       JSON: {"action":"tell","name":"Teyla","text":"..."}
 *   --emote <id> [--emote-target <oid>]
 *       the "socialinternal" queue command with "<target> <emoteId> 1 1" (ids are the row numbers of
 *       datatables/chat/social_types.iff, 1-based; tools/seat knows the common ones by name)
 *       JSON: {"action":"emote","id":123,"target":0}
 */

#include "client/ActionBase.h"
#include "client/ActionResult.h"
#include "client/ActionManager.h"
#include "client/ClientCore.h"
#include "client/zone/Zone.h"
#include "client/zone/ZoneClient.h"
#include "client/login/LoginSession.h"
#include "engine/service/proto/BaseMessage.h"

#include "client/actions/CommandQueueSend.h"

namespace {

bool inZone(ClientCore& core, ActionResult& result, const char* what) {
	if (core.zone == nullptr || !core.zone->isConnected() || !core.zone->isSceneReady()) {
		result.setError(String("Not in the zone (") + what + " needs a zoned-in character)", 1);
		return false;
	}
	return true;
}

void fillStatus(JSONSerializationType& json, bool skipped, const ActionResult& result) {
	if (skipped) {
		json["status"] = "skipped";
	} else if (result.isOK()) {
		json["status"] = "ok";
	} else {
		json["status"] = "failed";
		json["error"] = result.getError().toCharArray();
		json["errorCode"] = result.getErrorCode();
	}
}

}

// ===================================================================== say
class SayAction : public ActionBase {
	String text;
	uint64 target;
	int mood;
	int language;
	ActionResult result;
	bool skipped;

public:
	SayAction() : target(0), mood(0), language(0), skipped(false) {
		setLogLevel(Logger::INFO);
		setLoggingName("Say");
	}

	const char* getName() const override { return "say"; }
	bool needsZone() const override { return true; }
	bool needsTarget() const override { return true; }
	bool needsCharacter() const override { return true; }

	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		SayAction* me = nullptr;
		int i = startIndex;

		while (i < args.size()) {
			int lastConsumed = consumed;
			if (args.get(i) == "--say" && i + 1 < args.size()) {
				if (me != nullptr) break;
				me = new SayAction();
				me->text = args.get(i + 1);
				consumed += 2; i += 2;
			} else if (me != nullptr && args.get(i) == "--say-target" && i + 1 < args.size()) {
				me->target = UnsignedLong::valueOf(args.get(i + 1));
				consumed += 2; i += 2;
			} else if (me != nullptr && args.get(i) == "--say-mood" && i + 1 < args.size()) {
				me->mood = Integer::valueOf(args.get(i + 1));
				consumed += 2; i += 2;
			} else if (me != nullptr && args.get(i) == "--say-language" && i + 1 < args.size()) {
				me->language = Integer::valueOf(args.get(i + 1));
				consumed += 2; i += 2;
			}
			if (consumed == lastConsumed) break;
		}

		if (me != nullptr) result.add(me);
		return result;
	}

	static ActionBase* fromJSON(const JSONSerializationType& config) {
		SayAction* me = new SayAction();
		if (config.contains("text")) me->text = String(config["text"].get<std::string>().c_str());
		if (config.contains("target")) me->target = config["target"].get<uint64>();
		if (config.contains("mood")) me->mood = config["mood"].get<int>();
		if (config.contains("language")) me->language = config["language"].get<int>();
		return me;
	}

	void run(ClientCore& core) override {
		if (!inZone(core, result, "say")) return;
		if (text.isEmpty()) { result.setError("--say needs text", 2); return; }

		StringBuffer args;
		args << target << " 0 " << mood << " 0 " << language << " " << text;

		uint32 err = 0, state = 0;
		bool ok = sendQueueCommand(core, "spatialchatinternal", 0, UnicodeString(args.toString()), 5, err, state, this);

		if (err == 0xFFFFFFFF) {
			result.setError("No CommandQueueRemove for spatialchatinternal within 5s", 3);
			return;
		}
		if (!ok) {
			result.setError("say rejected: error=" + String::valueOf(err) + " state=" + String::valueOf(state), 4);
			return;
		}

		info() << "said: " << text;
		result.setSuccess();
	}

	bool isOK() const override { return !skipped && result.isOK(); }
	String getError() const override { return result.getError(); }
	uint16 getErrorCode() const override { return result.getErrorCode(); }
	void setSkipped() override { skipped = true; }

	JSONSerializationType toJSON() const override {
		JSONSerializationType json;
		json["action"] = getName();
		json["text"] = text.toCharArray();
		if (target != 0) json["target"] = target;
		if (mood != 0) json["mood"] = mood;
		if (language != 0) json["language"] = language;
		fillStatus(json, skipped, result);
		return json;
	}

	String getHelpText() const override {
		return "--say <text> [--say-target <oid>] [--say-mood <n>] [--say-language <n>]  Speak in spatial chat";
	}

	static ActionBase* factory() { return new SayAction(); }
};

static bool _registered_say =
	(ActionManager::registerAction("say", SayAction::factory, SayAction::fromArgs, SayAction::fromJSON), true);

// ===================================================================== tell
// Wire format read by ChatInstantMessageToCharacter::parse(): ascii game, ascii galaxy, ascii name,
// unicode message, 4 bytes, int sequence.
class ClientChatInstantMessageToCharacter : public BaseMessage {
public:
	ClientChatInstantMessageToCharacter(const String& galaxy, const String& name, const UnicodeString& text, uint32 sequence) {
		insertShort(0x05);
		insertInt(0x84BB21F7);   // ChatInstantMessageToCharacter
		insertAscii("SWG");
		insertAscii(galaxy);
		insertAscii(name);
		insertUnicode(text);
		insertInt(0);
		insertInt(sequence);
	}
};

class TellAction : public ActionBase {
	String name;
	String text;
	int timeoutSeconds;
	ActionResult result;
	bool skipped;
	int verdict;

	static uint32 nextSequence() {
		static AtomicInteger counter(1000);
		return counter.increment();
	}

public:
	TellAction() : timeoutSeconds(5), skipped(false), verdict(-1) {
		setLogLevel(Logger::INFO);
		setLoggingName("Tell");
	}

	const char* getName() const override { return "tell"; }
	bool needsZone() const override { return true; }
	bool needsTarget() const override { return true; }
	bool needsCharacter() const override { return true; }

	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		if (startIndex + 2 < args.size() && args.get(startIndex) == "--tell") {
			TellAction* me = new TellAction();
			me->name = args.get(startIndex + 1);
			me->text = args.get(startIndex + 2);
			consumed = 3;
			result.add(me);
		}
		return result;
	}

	static ActionBase* fromJSON(const JSONSerializationType& config) {
		TellAction* me = new TellAction();
		if (config.contains("name")) me->name = String(config["name"].get<std::string>().c_str());
		if (config.contains("text")) me->text = String(config["text"].get<std::string>().c_str());
		if (config.contains("timeout")) me->timeoutSeconds = config["timeout"].get<int>();
		return me;
	}

	void run(ClientCore& core) override {
		if (!inZone(core, result, "tell")) return;
		if (name.isEmpty() || text.isEmpty()) { result.setError("--tell needs a name and text", 2); return; }

		String galaxy;
		if (core.loginSession != nullptr) {
			const VectorMap<uint32, Galaxy>& galaxies = core.loginSession->getGalaxies();
			if (galaxies.contains(core.targetGalaxyId))
				galaxy = galaxies.get(core.targetGalaxyId).getName();
		}

		uint32 sequence = nextSequence();
		String key = "Tell/c" + String::valueOf(sequence) + "/result";

		info() << "tell " << name << ": " << text << " (seq " << sequence << ")";
		core.zone->getZoneClient()->sendMessage(new ClientChatInstantMessageToCharacter(galaxy, name, UnicodeString(text), sequence));

		int waited = 0;
		while (!core.hasVar(key) && waited < timeoutSeconds * 1000) {
			Thread::sleep(50);
			waited += 50;
		}

		if (!core.hasVar(key)) {
			result.setError("No ChatOnSendInstantMessage for the tell within " + String::valueOf(timeoutSeconds) + "s", 3);
			return;
		}

		verdict = core.getVar<int>(key, -1);
		if (verdict != 0) {
			result.setError("tell to '" + name + "' not delivered: result=" + String::valueOf(verdict)
				+ (verdict == 4 ? " (no such player)" : verdict == 5 ? " (offline)" : verdict == 6 ? " (ignored)" : ""), 4);
			return;
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
		json["name"] = name.toCharArray();
		json["text"] = text.toCharArray();
		if (verdict >= 0) json["result"] = verdict;
		fillStatus(json, skipped, result);
		return json;
	}

	String getHelpText() const override {
		return "--tell <first name> <text>  Send a /tell and wait for the server's verdict";
	}

	static ActionBase* factory() { return new TellAction(); }
};

static bool _registered_tell =
	(ActionManager::registerAction("tell", TellAction::factory, TellAction::fromArgs, TellAction::fromJSON), true);

// ===================================================================== emote
class EmoteAction : public ActionBase {
	int emoteId;
	uint64 target;
	ActionResult result;
	bool skipped;

public:
	EmoteAction() : emoteId(0), target(0), skipped(false) {
		setLogLevel(Logger::INFO);
		setLoggingName("Emote");
	}

	const char* getName() const override { return "emote"; }
	bool needsZone() const override { return true; }
	bool needsTarget() const override { return true; }
	bool needsCharacter() const override { return true; }

	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		EmoteAction* me = nullptr;
		int i = startIndex;

		while (i < args.size()) {
			int lastConsumed = consumed;
			if (args.get(i) == "--emote" && i + 1 < args.size()) {
				if (me != nullptr) break;
				me = new EmoteAction();
				me->emoteId = Integer::valueOf(args.get(i + 1));
				consumed += 2; i += 2;
			} else if (me != nullptr && args.get(i) == "--emote-target" && i + 1 < args.size()) {
				me->target = UnsignedLong::valueOf(args.get(i + 1));
				consumed += 2; i += 2;
			}
			if (consumed == lastConsumed) break;
		}

		if (me != nullptr) result.add(me);
		return result;
	}

	static ActionBase* fromJSON(const JSONSerializationType& config) {
		EmoteAction* me = new EmoteAction();
		if (config.contains("id")) me->emoteId = config["id"].get<int>();
		if (config.contains("target")) me->target = config["target"].get<uint64>();
		return me;
	}

	void run(ClientCore& core) override {
		if (!inZone(core, result, "emote")) return;
		if (emoteId <= 0) { result.setError("--emote needs a positive id", 2); return; }

		StringBuffer args;
		args << target << " " << emoteId << " 1 1";

		uint32 err = 0, state = 0;
		bool ok = sendQueueCommand(core, "socialinternal", 0, UnicodeString(args.toString()), 5, err, state, this);

		if (err == 0xFFFFFFFF) {
			result.setError("No CommandQueueRemove for socialinternal within 5s", 3);
			return;
		}
		if (!ok) {
			result.setError("emote rejected: error=" + String::valueOf(err) + " state=" + String::valueOf(state), 4);
			return;
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
		json["id"] = emoteId;
		if (target != 0) json["target"] = target;
		fillStatus(json, skipped, result);
		return json;
	}

	String getHelpText() const override {
		return "--emote <id> [--emote-target <oid>]  Play a social emote by its social_types row number";
	}

	static ActionBase* factory() { return new EmoteAction(); }
};

static bool _registered_emote =
	(ActionManager::registerAction("emote", EmoteAction::factory, EmoteAction::fromArgs, EmoteAction::fromJSON), true);
