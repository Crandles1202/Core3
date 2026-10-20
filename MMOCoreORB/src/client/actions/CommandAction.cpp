/*
 * CommandAction.cpp
 *
 * Sends any ObjectController slash command (the way the real client does) and waits
 * for the server's CommandQueueRemove so the test knows whether it was accepted.
 *
 *   --command <name> [--target <oid>|self] [--args "<text>"] [--command-timeout <sec>] [--command-nowait]
 *   JSON: {"action":"command","name":"healdamage","target":123,"args":"","timeout":10}
 *
 * Several --command groups may appear on one command line; they run in order.
 */

#include "client/ActionBase.h"
#include "client/actions/CommandQueueSend.h"
#include "client/ActionResult.h"
#include "client/ActionManager.h"
#include "client/ClientCore.h"
#include "client/zone/Zone.h"
#include "client/zone/ZoneClient.h"
#include "engine/service/proto/BaseMessage.h"

// Wire format expected by ObjectControllerMessageCallback + CommandQueueEnqueueCallback::parse()
class ClientCommandQueueEnqueue : public BaseMessage {
public:
	ClientCommandQueueEnqueue(uint64 playerOid, uint32 actionCount, uint32 actionCRC, uint64 targetOid, const UnicodeString& arguments) {
		insertShort(0x05);
		insertInt(0x80CE5E46);   // ObjControllerMessage
		insertInt(0x23);         // priority (parsed, not checked)
		insertInt(0x116);        // CommandQueueEnqueue
		insertLong(playerOid);
		insertInt(0);            // "size" (ignored)
		insertInt(actionCount);
		insertInt(actionCRC);
		insertLong(targetOid);
		insertUnicode(arguments);
	}
};

class CommandAction : public ActionBase {
	String commandName;
	String targetSpec;      // "", "self" or a decimal OID
	String arguments;
	int timeoutSeconds;
	bool noWait;   // --command-nowait: some commands (startdance, stopdance, ...) never send CommandQueueRemove

	ActionResult result;
	bool skipped;
	uint32 actionCount;
	uint32 errorCode;
	uint32 errorState;

	static uint32 nextActionCount() {
		static AtomicInteger counter(100);
		return counter.increment();
	}

public:
	CommandAction() : timeoutSeconds(10), noWait(false), skipped(false), actionCount(0), errorCode(0), errorState(0) {
		setLogLevel(Logger::INFO);
		setLoggingName("Command");
	}

	const char* getName() const override { return "command"; }
	bool needsZone() const override { return true; }
	bool needsTarget() const override { return true; }
	bool needsCharacter() const override { return true; }

	static uint64 resolveTarget(const String& spec, ClientCore& core) {
		if (spec.isEmpty())
			return 0;
		if (spec == "self")
			return core.selectedCharacterOid;
		return UnsignedLong::valueOf(spec);
	}

	// Public so other actions (converse) can reuse it.
	// Returns true when the server reported the command as executed without error.
	static bool send(ClientCore& core, const String& name, uint64 target, const UnicodeString& args, int timeoutSeconds, uint32& outError, uint32& outState, Logger* log = nullptr) {
		uint32 count = nextActionCount();
		uint32 crc = name.toLowerCase().hashCode();

		String key = "CommandQueueRemove/c" + String::valueOf(count);

		if (log != nullptr)
			log->info() << "sending '" << name << "' target=" << target << " args='" << args.toString() << "' count=" << count;

		core.zone->getZoneClient()->sendMessage(new ClientCommandQueueEnqueue(core.selectedCharacterOid, count, crc, target, args));

		// CommandQueueRemove may land before waitFor() registers, so poll the var store instead.
		int waited = 0;
		while (!core.hasVar(key + "/error") && waited < timeoutSeconds * 1000) {
			Thread::sleep(50);
			waited += 50;
		}

		if (!core.hasVar(key + "/error")) {
			outError = 0xFFFFFFFF;
			outState = 0;
			return false;
		}

		outError = core.getVar<uint32>(key + "/error", 0);
		outState = core.getVar<uint32>(key + "/state", 0);
		return outError == 0;
	}

	// ===== Static Factories =====
	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		CommandAction* me = nullptr;
		int i = startIndex;

		while (i < args.size()) {
			int lastConsumed = consumed;

			if (args.get(i) == "--command" && i + 1 < args.size()) {
				if (me != nullptr) break;   // next group
				me = new CommandAction();
				me->commandName = args.get(i + 1);
				consumed += 2; i += 2;
			} else if (me != nullptr && args.get(i) == "--target" && i + 1 < args.size()) {
				me->targetSpec = args.get(i + 1);
				consumed += 2; i += 2;
			} else if (me != nullptr && args.get(i) == "--args" && i + 1 < args.size()) {
				me->arguments = args.get(i + 1);
				consumed += 2; i += 2;
			} else if (me != nullptr && args.get(i) == "--command-timeout" && i + 1 < args.size()) {
				me->timeoutSeconds = Integer::valueOf(args.get(i + 1));
				consumed += 2; i += 2;
			} else if (me != nullptr && args.get(i) == "--command-nowait") {
				me->noWait = true;
				consumed += 1; i += 1;
			}

			if (consumed == lastConsumed) break;
		}

		if (me != nullptr)
			result.add(me);

		return result;
	}

	static ActionBase* fromJSON(const JSONSerializationType& config) {
		CommandAction* me = new CommandAction();
		if (config.contains("name")) me->commandName = String(config["name"].get<std::string>().c_str());
		if (config.contains("args")) me->arguments = String(config["args"].get<std::string>().c_str());
		if (config.contains("timeout")) me->timeoutSeconds = config["timeout"].get<int>();
		if (config.contains("nowait")) me->noWait = config["nowait"].get<bool>();
		if (config.contains("target")) {
			if (config["target"].is_string())
				me->targetSpec = String(config["target"].get<std::string>().c_str());
			else
				me->targetSpec = String::valueOf(config["target"].get<uint64>());
		}
		return me;
	}

	void run(ClientCore& core) override {
		if (core.zone == nullptr || !core.zone->isConnected() || !core.zone->isSceneReady()) {
			result.setError("Not in the zone (command needs a zoned-in character)", 1);
			return;
		}
		if (commandName.isEmpty()) {
			result.setError("--command needs a name", 2);
			return;
		}

		uint64 target = resolveTarget(targetSpec, core);

		if (noWait) {
			// fire and forget: the server's verdict (if any) shows up as a system message in the log
			send(core, commandName, target, UnicodeString(arguments), 0, errorCode, errorState, this);
			errorCode = 0; errorState = 0;
			Thread::sleep(500);
			result.setSuccess();
			return;
		}

		bool ok = send(core, commandName, target, UnicodeString(arguments), timeoutSeconds, errorCode, errorState, this);

		if (errorCode == 0xFFFFFFFF) {
			result.setError("No CommandQueueRemove for '" + commandName + "' within " + String::valueOf(timeoutSeconds) + "s", 3);
			return;
		}

		if (!ok) {
			result.setError("Command '" + commandName + "' rejected: error=" + String::valueOf(errorCode) + " state=" + String::valueOf(errorState), 4);
			return;
		}

		info() << "'" << commandName << "' executed";
		result.setSuccess();
	}

	bool isOK() const override { return !skipped && result.isOK(); }
	String getError() const override { return result.getError(); }
	uint16 getErrorCode() const override { return result.getErrorCode(); }
	void setSkipped() override { skipped = true; }

	JSONSerializationType toJSON() const override {
		JSONSerializationType json;
		json["action"] = getName();
		json["name"] = commandName.toCharArray();
		if (!targetSpec.isEmpty()) json["target"] = targetSpec.toCharArray();
		if (!arguments.isEmpty()) json["args"] = arguments.toCharArray();
		json["timeout"] = timeoutSeconds;
		if (noWait) json["nowait"] = true;
		if (skipped) {
			json["status"] = "skipped";
		} else if (result.isOK()) {
			json["status"] = "ok";
			json["queueError"] = errorCode;
			json["queueState"] = errorState;
		} else {
			json["status"] = "failed";
			json["error"] = result.getError().toCharArray();
			json["errorCode"] = result.getErrorCode();
		}
		return json;
	}

	String getHelpText() const override {
		return "--command <name> [--target <oid>|self] [--args <text>] [--command-timeout <sec>] [--command-nowait]  Send a slash command and wait for the server's verdict (nowait: just send)";
	}

	static ActionBase* factory() { return new CommandAction(); }
};

static bool _registered_command =
	(ActionManager::registerAction("command", CommandAction::factory, CommandAction::fromArgs, CommandAction::fromJSON), true);

bool sendQueueCommand(ClientCore& core, const String& name, uint64 target, const UnicodeString& args, int timeoutSeconds, uint32& outError, uint32& outState, Logger* log) {
	return CommandAction::send(core, name, target, args, timeoutSeconds, outError, outState, log);
}
