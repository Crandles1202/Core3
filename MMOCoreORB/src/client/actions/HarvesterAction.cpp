/*
 * HarvesterAction.cpp — place a structure and run a harvester (Phase 7.6a harvesters, Final Boss)
 *
 *   place      {"action":"place","deed":<oid>,"x":3900,"y":-4700,"angle":0}
 *       placeStructure "<deed> <x> <y> <angle 0-3>" (PlaceStructureCommand: the deed in the inventory, the spot
 *       within 100 m and 10 m of height, outdoors, outside cities and no-build areas, a free lot). The structure is
 *       built at once (PlaceStructureSession) and sent to the client: the result is the new installation's oid.
 *
 *   harvester  {"action":"harvester","target":<oid>,"op":"resources"}       harvesterGetResourceData → the spawns
 *                                                                           this harvester could extract here, with
 *                                                                           their density % (ObjController 0xEA)
 *              {"action":"harvester","target":<oid>,"op":"select","resource":<spawn oid>}   harvesterSelectResource
 *              {"action":"harvester","target":<oid>,"op":"activate"|"deactivate"}
 *              {"action":"harvester","target":<oid>,"op":"maintain","amount":500}   radial 129 (Pay Maintenance) →
 *                                                                           the transfer box, answered with the amount
 *              {"action":"harvester","target":<oid>,"op":"power","amount":200}      radial 51 (Deposit Power) → the
 *                                                                           transfer box; energy from the resource
 *                                                                           containers (wind, solar, …) in the inventory
 *              {"action":"harvester","target":<oid>,"op":"empty","resource":<spawn oid>,"quantity":100,"discard":false}
 *                                                                           ObjController 0xED EmptyHopper: that many
 *                                                                           units of the hopper line into the inventory
 *                                                                           (or thrown away)
 *       Every op needs the character within range of the harvester (the commands check ~16 m; stand next to it) and
 *       on its admin list (the owner is). What the harvester holds, earns and burns is read server-side:
 *       FbLabTests:harvester:<oid>.
 */

#include "client/ActionBase.h"
#include "client/ActionResult.h"
#include "client/ActionManager.h"
#include "client/ClientCore.h"
#include "client/zone/Zone.h"
#include "client/zone/ZoneClient.h"
#include "client/zone/objects/scene/SceneObject.h"
#include "client/zone/objects/ObjectMap.h"
#include "client/zone/managers/object/ObjectManager.h"
#include "client/actions/CommandQueueSend.h"
#include "engine/service/proto/BaseMessage.h"

namespace {

bool harvesterInZone(ClientCore& core, ActionResult& result, const char* what) {
	if (core.zone == nullptr || !core.zone->isConnected() || !core.zone->isSceneReady()) {
		result.setError(String("Not in the zone (") + what + " needs a zoned-in character)", 1);
		return false;
	}
	return true;
}

int systemMessagesCount(ClientCore& core) {
	try {
		const auto& kept = core.vars.at(JSONSerializationType::json_pointer("/SystemMessages"));
		return kept.is_array() ? (int) kept.size() : 0;
	} catch (...) {
		return 0;
	}
}

String systemMessagesJoined(ClientCore& core, int since) {
	String out;
	try {
		const auto& kept = core.vars.at(JSONSerializationType::json_pointer("/SystemMessages"));
		if (!kept.is_array())
			return out;
		int start = since < (int) kept.size() ? since : (int) kept.size();
		for (int i = start; i < (int) kept.size(); ++i)
			if (kept[i].is_string())
				out = out.isEmpty() ? String(kept[i].get<std::string>().c_str()) : out + " | " + String(kept[i].get<std::string>().c_str());
	} catch (...) {
	}
	return out;
}

// objects of a game object type range the client holds (installations 0x1000..0x1007, resource containers 0x400000..0x40FFFF)
Vector<uint64> objectsOfType(ClientCore& core, int typeFrom, int typeTo) {
	Vector<uint64> found;
	ObjectManager* objectManager = core.zone->getObjectManager();
	if (objectManager == nullptr)
		return found;
	Locker lock(objectManager);
	ObjectMap* map = objectManager->getObjectMap();
	if (map == nullptr)
		return found;
	HashTableIterator<uint64, Reference<SceneObject*> > iterator = map->iterator();
	while (iterator.hasNext()) {
		SceneObject* object = iterator.getNextValue();
		if (object == nullptr)
			continue;
		int type = object->getGameObjectType();
		if (type >= typeFrom && type <= typeTo)
			found.add(object->getObjectID());
	}
	return found;
}

bool runSubAction(ClientCore& core, const char* name, const JSONSerializationType& config, String& error) {
	ActionBase* action = ActionManager::fromJSON(name, config);
	if (action == nullptr) {
		error = String("no action ") + name;
		return false;
	}
	action->run(core);
	bool ok = action->isOK();
	if (!ok)
		error = action->getError();
	delete action;
	return ok;
}

// ObjController 0xED EmptyHopper as the client sends it (EmptyHopperCallback::parse): long harvester, long resource,
// int quantity, byte retrieve(0)/discard(1), byte checksum
class ClientEmptyHopper : public BaseMessage {
public:
	ClientEmptyHopper(uint64 playerOid, uint64 harvester, uint64 resource, uint32 quantity, bool discard) {
		insertShort(0x05);
		insertInt(0x80CE5E46);   // ObjControllerMessage
		insertInt(0x0B);         // priority
		insertInt(0xED);         // EmptyHopper
		insertLong(playerOid);
		insertLong(harvester);
		insertLong(resource);
		insertInt(quantity);
		insertByte(discard ? 1 : 0);
		insertByte(0);
	}
};

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

} // namespace

// ------------------------------------------------------------------------------------------ place
class PlaceAction : public ActionBase {
	uint64 deed;
	float x, y;
	int angle;

	ActionResult result;
	bool skipped;
	uint64 structure;
	String serverSaid;

public:
	PlaceAction() : deed(0), x(0), y(0), angle(0), skipped(false), structure(0) {
		setLogLevel(Logger::INFO);
		setLoggingName("Place");
	}

	const char* getName() const override { return "place"; }
	bool needsZone() const override { return true; }
	bool needsTarget() const override { return true; }
	bool needsCharacter() const override { return true; }

	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		if (startIndex + 3 < args.size() && args.get(startIndex) == "--place") {
			PlaceAction* me = new PlaceAction();
			me->deed = UnsignedLong::valueOf(args.get(startIndex + 1));
			me->x = Float::valueOf(args.get(startIndex + 2));
			me->y = Float::valueOf(args.get(startIndex + 3));
			consumed = 4;
			if (startIndex + 4 < args.size() && !args.get(startIndex + 4).beginsWith("--")) {
				me->angle = Integer::valueOf(args.get(startIndex + 4));
				consumed = 5;
			}
			result.add(me);
		}
		return result;
	}

	static ActionBase* fromJSON(const JSONSerializationType& config) {
		PlaceAction* me = new PlaceAction();
		if (config.contains("deed")) me->deed = config["deed"].get<uint64>();
		if (config.contains("x")) me->x = config["x"].get<float>();
		if (config.contains("y")) me->y = config["y"].get<float>();
		if (config.contains("angle")) me->angle = config["angle"].get<int>();
		return me;
	}

	void run(ClientCore& core) override {
		if (!harvesterInZone(core, result, "place")) return;
		if (deed == 0) { result.setError("place needs the deed's oid", 2); return; }
		if (angle < 0 || angle > 3) { result.setError("angle is 0..3 (quarter turns)", 2); return; }

		Vector<uint64> before = objectsOfType(core, 0x1000, 0x1007);
		int msgBefore = systemMessagesCount(core);

		StringBuffer args;
		args << deed << " " << x << " " << y << " " << angle;
		info() << "placeStructure " << args.toString();
		uint32 qerr = 0, qstate = 0;
		sendQueueCommand(core, "placestructure", 0, UnicodeString(args.toString()), 8, qerr, qstate, this);

		int waited = 0;
		while (waited < 20000) {
			Thread::sleep(250); waited += 250;
			Vector<uint64> now = objectsOfType(core, 0x1000, 0x1007);
			for (int i = 0; i < now.size() && structure == 0; ++i)
				if (!before.contains(now.get(i)))
					structure = now.get(i);
			if (structure != 0)
				break;
			if (systemMessagesCount(core) > msgBefore && waited >= 3000)
				break;
		}
		serverSaid = systemMessagesJoined(core, msgBefore);

		if (structure == 0) {
			if (qerr != 0 && qerr != 0xFFFFFFFF)
				result.setError("placeStructure refused (error " + String::valueOf(qerr) + ", state " + String::valueOf(qstate) + "): " + serverSaid, 3);
			else
				result.setError("no structure appeared within 20 s: " + (serverSaid.isEmpty() ? String("(no system message)") : serverSaid), 4);
			return;
		}
		info() << "structure " << structure << " placed: " << serverSaid;
		result.setSuccess();
	}

	bool isOK() const override { return !skipped && result.isOK(); }
	String getError() const override { return result.getError(); }
	uint16 getErrorCode() const override { return result.getErrorCode(); }
	void setSkipped() override { skipped = true; }

	JSONSerializationType toJSON() const override {
		JSONSerializationType json;
		json["action"] = getName();
		json["deed"] = deed;
		json["x"] = x; json["y"] = y; json["angle"] = angle;
		json["structure"] = structure;
		json["serverSaid"] = serverSaid.toCharArray();
		fillStatus(json, skipped, result);
		return json;
	}

	String getHelpText() const override {
		return "--place <deed oid> <x> <y> [angle 0-3]  Place a structure from a deed in the inventory (within 100 m, outdoors, outside cities)";
	}

	static ActionBase* factory() { return new PlaceAction(); }
};

static bool _registered_place =
	(ActionManager::registerAction("place", PlaceAction::factory, PlaceAction::fromArgs, PlaceAction::fromJSON), true);

// ------------------------------------------------------------------------------------------ harvester
class HarvesterAction : public ActionBase {
	uint64 target;
	String op;
	uint64 resource;
	uint32 quantity;
	int amount;
	bool discard;

	ActionResult result;
	bool skipped;
	String serverSaid;
	JSONSerializationType resources;
	int containersBefore, containersAfter;

public:
	HarvesterAction() : target(0), resource(0), quantity(0), amount(0), discard(false), skipped(false), containersBefore(0), containersAfter(0) {
		setLogLevel(Logger::INFO);
		setLoggingName("Harvester");
	}

	const char* getName() const override { return "harvester"; }
	bool needsZone() const override { return true; }
	bool needsTarget() const override { return true; }
	bool needsCharacter() const override { return true; }

	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		if (startIndex + 2 < args.size() && args.get(startIndex) == "--harvester") {
			HarvesterAction* me = new HarvesterAction();
			me->target = UnsignedLong::valueOf(args.get(startIndex + 1));
			me->op = args.get(startIndex + 2);
			consumed = 3;
			while (startIndex + consumed + 1 < args.size()) {
				const String& key = args.get(startIndex + consumed);
				const String& val = args.get(startIndex + consumed + 1);
				if (key == "--harvester-resource") me->resource = UnsignedLong::valueOf(val);
				else if (key == "--harvester-quantity") me->quantity = Integer::valueOf(val);
				else if (key == "--harvester-amount") me->amount = Integer::valueOf(val);
				else break;
				consumed += 2;
			}
			if (startIndex + consumed < args.size() && args.get(startIndex + consumed) == "--harvester-discard") {
				me->discard = true;
				consumed++;
			}
			result.add(me);
		}
		return result;
	}

	static ActionBase* fromJSON(const JSONSerializationType& config) {
		HarvesterAction* me = new HarvesterAction();
		if (config.contains("target")) me->target = config["target"].get<uint64>();
		if (config.contains("op")) me->op = String(config["op"].get<std::string>().c_str());
		if (config.contains("resource")) me->resource = config["resource"].get<uint64>();
		if (config.contains("quantity")) me->quantity = config["quantity"].get<uint32>();
		if (config.contains("amount")) me->amount = config["amount"].get<int>();
		if (config.contains("discard")) me->discard = config["discard"].get<bool>();
		return me;
	}

	bool command(ClientCore& core, const char* name, const String& args, int msgBefore) {
		uint32 qerr = 0, qstate = 0;
		bool ok = sendQueueCommand(core, name, target, UnicodeString(args), 8, qerr, qstate, this);
		Thread::sleep(500);
		serverSaid = systemMessagesJoined(core, msgBefore);
		if (!ok && qerr != 0xFFFFFFFF) {
			result.setError(String(name) + " refused (error " + String::valueOf(qerr) + ", state " + String::valueOf(qstate) + "): " + serverSaid, 3);
			return false;
		}
		if (serverSaid.contains("too far") || serverSaid.contains("@player_structure:")) {
			result.setError(String(name) + ": " + serverSaid, 4);
			return false;
		}
		return true;
	}

	// radial on the harvester, then the transfer box it opens (pay maintenance / deposit power), answered with
	// [what stays, what moves]: the server reads the second argument as the amount
	bool transferBox(ClientCore& core, int radialId, const char* match, int msgBefore) {
		int suiBefore = core.getVar<int>("Sui/count", 0);
		JSONSerializationType radial;
		radial["action"] = "radial"; radial["target"] = target; radial["radialId"] = radialId; radial["settleMs"] = 800;
		String err;
		if (!runSubAction(core, "radial", radial, err)) { result.setError("radial " + String::valueOf(radialId) + " failed: " + err, 5); return false; }
		int waited = 0;
		while (core.getVar<int>("Sui/count", 0) == suiBefore && waited < 5000) { Thread::sleep(100); waited += 100; }
		if (core.getVar<int>("Sui/count", 0) == suiBefore) {
			serverSaid = systemMessagesJoined(core, msgBefore);
			result.setError("no window after radial " + String::valueOf(radialId) + " (not the owner, or too far?): " + serverSaid, 6);
			return false;
		}
		JSONSerializationType sui;
		sui["action"] = "sui"; sui["values"] = JSONSerializationType::array({"0", String::valueOf(amount).toCharArray()}); sui["match"] = match; sui["timeout"] = 5;
		if (!runSubAction(core, "sui", sui, err)) { result.setError(String("answering the ") + match + " window failed: " + err, 7); return false; }
		Thread::sleep(800);
		serverSaid = systemMessagesJoined(core, msgBefore);
		return true;
	}

	void run(ClientCore& core) override {
		if (!harvesterInZone(core, result, "harvester")) return;
		if (target == 0 || op.isEmpty()) { result.setError("harvester needs a target oid and an op", 2); return; }
		int msgBefore = systemMessagesCount(core);

		if (op == "resources") {
			String key = "Harvester/h" + String::valueOf(target) + "/count";
			core.vars.erase("Harvester");
			if (!command(core, "harvestergetresourcedata", "", msgBefore)) return;
			int waited = 0;
			while (!core.hasVar(key) && waited < 5000) { Thread::sleep(100); waited += 100; }
			if (!core.hasVar(key)) { result.setError("no HarvesterResourceDataMessage within 5 s: " + serverSaid, 8); return; }
			try { resources = core.vars.at(JSONSerializationType::json_pointer("/Harvester/h" + std::string(String::valueOf(target).toCharArray()) + "/resources")); } catch (...) {}
			result.setSuccess();
		} else if (op == "select") {
			if (resource == 0) { result.setError("select needs the spawn oid (resource)", 2); return; }
			if (!command(core, "harvesterselectresource", String::valueOf(resource), msgBefore)) return;
			result.setSuccess();
		} else if (op == "activate") {
			if (!command(core, "harvesteractivate", "", msgBefore)) return;
			result.setSuccess();
		} else if (op == "deactivate") {
			if (!command(core, "harvesterdeactivate", "", msgBefore)) return;
			result.setSuccess();
		} else if (op == "maintain") {
			if (amount <= 0) { result.setError("maintain needs an amount of credits", 2); return; }
			if (!transferBox(core, 129, "select_amount", msgBefore)) return;
			result.setSuccess();
		} else if (op == "power") {
			if (amount <= 0) { result.setError("power needs an amount of energy units", 2); return; }
			if (!transferBox(core, 51, "add_power", msgBefore)) return;
			result.setSuccess();
		} else if (op == "empty") {
			if (resource == 0 || quantity == 0) { result.setError("empty needs the spawn oid (resource) and a quantity", 2); return; }
			containersBefore = objectsOfType(core, 0x400000, 0x40FFFF).size();   // resource containers: 0x400000 + subtype
			core.zone->getZoneClient()->sendMessage(new ClientEmptyHopper(core.selectedCharacterOid, target, resource, quantity, discard));
			Thread::sleep(1500);
			containersAfter = objectsOfType(core, 0x400000, 0x40FFFF).size();
			serverSaid = systemMessagesJoined(core, msgBefore);
			if (serverSaid.contains("too far")) { result.setError("empty hopper: " + serverSaid, 4); return; }
			result.setSuccess();
		} else {
			result.setError("unknown op '" + op + "' (resources, select, activate, deactivate, maintain, power, empty)", 2);
		}
	}

	bool isOK() const override { return !skipped && result.isOK(); }
	String getError() const override { return result.getError(); }
	uint16 getErrorCode() const override { return result.getErrorCode(); }
	void setSkipped() override { skipped = true; }

	JSONSerializationType toJSON() const override {
		JSONSerializationType json;
		json["action"] = getName();
		json["target"] = target;
		json["op"] = op.toCharArray();
		if (resource) json["resource"] = resource;
		if (quantity) json["quantity"] = quantity;
		if (amount) json["amount"] = amount;
		if (op == "empty") { json["discard"] = discard; json["containersBefore"] = containersBefore; json["containersAfter"] = containersAfter; }
		if (op == "resources") json["resources"] = resources;
		json["serverSaid"] = serverSaid.toCharArray();
		fillStatus(json, skipped, result);
		return json;
	}

	String getHelpText() const override {
		return "--harvester <oid> <resources|select|activate|deactivate|maintain|power|empty> [--harvester-resource <spawn oid>] [--harvester-quantity N] [--harvester-amount N] [--harvester-discard]  Run a harvester you own";
	}

	static ActionBase* factory() { return new HarvesterAction(); }
};

static bool _registered_harvester =
	(ActionManager::registerAction("harvester", HarvesterAction::factory, HarvesterAction::fromArgs, HarvesterAction::fromJSON), true);
