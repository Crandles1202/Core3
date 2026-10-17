/*
 * MissionListAction.cpp
 *
 * Asks a mission terminal for its mission list (ObjController 0xF5, MissionListRequestCallback),
 * which makes the server randomize the 12 missions in the character's mission bag and send their
 * baselines. Pair it with the Lua oracle (FbLabTests:missions:<char>) to read what was generated.
 *
 *   --missions <terminalOid> [--missions-settle <ms>]
 *   JSON: {"action":"missions","terminal":123,"settleMs":1500}
 */

#include "client/ActionBase.h"
#include "client/ActionResult.h"
#include "client/ActionManager.h"
#include "client/ClientCore.h"
#include "client/zone/Zone.h"
#include "client/zone/ZoneClient.h"
#include "engine/service/proto/BaseMessage.h"

// Wire format: ObjectControllerMessageCallback::parse (priority, type, objid) then
// MissionListRequestCallback::parse (int "size", byte flags, byte seq, long terminal). The common
// parser does not consume the size int; each callback's parse() starts with it.
class ClientMissionListRequest : public BaseMessage {
public:
	ClientMissionListRequest(uint64 playerOid, uint64 terminalOid, uint8 seq) {
		insertShort(0x05);
		insertInt(0x80CE5E46);   // ObjControllerMessage
		insertInt(0x23);         // priority
		insertInt(0xF5);         // MissionListRequest
		insertLong(playerOid);
		insertInt(0);            // "size" (read and ignored by the callback)
		insertByte(0);           // flags
		insertByte(seq);
		insertLong(terminalOid);
	}
};

class MissionListAction : public ActionBase {
	String terminalSpec;
	int settleMs;

	ActionResult result;
	bool skipped;

public:
	MissionListAction() : settleMs(1500), skipped(false) {
		setLogLevel(Logger::INFO);
		setLoggingName("Missions");
	}

	const char* getName() const override { return "missions"; }
	bool needsZone() const override { return true; }
	bool needsTarget() const override { return true; }
	bool needsCharacter() const override { return true; }

	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		MissionListAction* me = nullptr;
		int i = startIndex;

		while (i < args.size()) {
			int lastConsumed = consumed;

			if (args.get(i) == "--missions" && i + 1 < args.size()) {
				if (me != nullptr) break;
				me = new MissionListAction();
				me->terminalSpec = args.get(i + 1);
				consumed += 2; i += 2;
			} else if (me != nullptr && args.get(i) == "--missions-settle" && i + 1 < args.size()) {
				me->settleMs = Integer::valueOf(args.get(i + 1));
				consumed += 2; i += 2;
			}

			if (consumed == lastConsumed) break;
		}

		if (me != nullptr)
			result.add(me);

		return result;
	}

	static ActionBase* fromJSON(const JSONSerializationType& config) {
		MissionListAction* me = new MissionListAction();
		if (config.contains("settleMs")) me->settleMs = config["settleMs"].get<int>();
		if (config.contains("terminal")) {
			if (config["terminal"].is_string())
				me->terminalSpec = String(config["terminal"].get<std::string>().c_str());
			else
				me->terminalSpec = String::valueOf(config["terminal"].get<uint64>());
		}
		return me;
	}

	void run(ClientCore& core) override {
		if (core.zone == nullptr || !core.zone->isConnected() || !core.zone->isSceneReady()) {
			result.setError("Not in the zone (missions needs a zoned-in character)", 1);
			return;
		}

		uint64 terminal = UnsignedLong::valueOf(terminalSpec);
		if (terminal == 0) {
			result.setError("--missions needs a mission terminal object id", 2);
			return;
		}

		info() << "MissionListRequest terminal=" << terminal;
		core.zone->getZoneClient()->sendMessage(new ClientMissionListRequest(core.selectedCharacterOid, terminal, 1));

		// The server answers with mission baselines; give it time to randomize and send them.
		Thread::sleep(settleMs);
		result.setSuccess();
	}

	bool isOK() const override { return !skipped && result.isOK(); }
	String getError() const override { return result.getError(); }
	uint16 getErrorCode() const override { return result.getErrorCode(); }
	void setSkipped() override { skipped = true; }

	JSONSerializationType toJSON() const override {
		JSONSerializationType json;
		json["action"] = getName();
		json["terminal"] = terminalSpec.toCharArray();
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
		return "--missions <terminalOid> [--missions-settle <ms>]  Request a mission terminal's list (server randomizes the mission bag)";
	}

	static ActionBase* factory() { return new MissionListAction(); }
};

static bool _registered_missions =
	(ActionManager::registerAction("missions", MissionListAction::factory, MissionListAction::fromArgs, MissionListAction::fromJSON), true);
