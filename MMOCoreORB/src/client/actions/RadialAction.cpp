/*
 * RadialAction.cpp
 *
 * Picks a radial-menu option on an object (ObjectMenuSelect), e.g. ITEM_USE (20) on a
 * stimpack or CONVERSE_START on an NPC. See server/zone/managers/radial/RadialOptions.h
 * for the ids.
 *
 *   --radial <oid> <radialId> [--radial-settle <ms>]
 *   JSON: {"action":"radial","target":123,"radialId":20,"settleMs":500}
 */

#include "client/ActionBase.h"
#include "client/ActionResult.h"
#include "client/ActionManager.h"
#include "client/ClientCore.h"
#include "client/zone/Zone.h"
#include "client/zone/ZoneClient.h"
#include "engine/service/proto/BaseMessage.h"

class ClientObjectMenuSelect : public BaseMessage {
public:
	ClientObjectMenuSelect(uint64 objectID, uint8 radialID) {
		insertShort(0x03);
		insertInt(0x7CA18726);   // ObjectMenuSelect
		insertLong(objectID);
		insertByte(radialID);
	}
};

class RadialAction : public ActionBase {
	String targetSpec;
	int radialId;
	int settleMs;

	ActionResult result;
	bool skipped;

public:
	RadialAction() : radialId(0), settleMs(500), skipped(false) {
		setLogLevel(Logger::INFO);
		setLoggingName("Radial");
	}

	const char* getName() const override { return "radial"; }
	bool needsZone() const override { return true; }
	bool needsTarget() const override { return true; }
	bool needsCharacter() const override { return true; }

	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		RadialAction* me = nullptr;
		int i = startIndex;

		while (i < args.size()) {
			int lastConsumed = consumed;

			if (args.get(i) == "--radial" && i + 2 < args.size()) {
				if (me != nullptr) break;
				me = new RadialAction();
				me->targetSpec = args.get(i + 1);
				me->radialId = Integer::valueOf(args.get(i + 2));
				consumed += 3; i += 3;
			} else if (me != nullptr && args.get(i) == "--radial-settle" && i + 1 < args.size()) {
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
		RadialAction* me = new RadialAction();
		if (config.contains("radialId")) me->radialId = config["radialId"].get<int>();
		if (config.contains("settleMs")) me->settleMs = config["settleMs"].get<int>();
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
			result.setError("Not in the zone (radial needs a zoned-in character)", 1);
			return;
		}

		uint64 target = (targetSpec == "self") ? core.selectedCharacterOid : UnsignedLong::valueOf(targetSpec);
		if (target == 0) {
			result.setError("--radial needs an object id", 2);
			return;
		}

		info() << "ObjectMenuSelect object=" << target << " radialId=" << radialId;
		core.zone->getZoneClient()->sendMessage(new ClientObjectMenuSelect(target, (uint8) radialId));

		// There is no direct acknowledgement; give the server a moment to act on it.
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
		json["target"] = targetSpec.toCharArray();
		json["radialId"] = radialId;
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
		return "--radial <oid> <radialId> [--radial-settle <ms>]  Select a radial menu option on an object (20 = use)";
	}

	static ActionBase* factory() { return new RadialAction(); }
};

static bool _registered_radial =
	(ActionManager::registerAction("radial", RadialAction::factory, RadialAction::fromArgs, RadialAction::fromJSON), true);
