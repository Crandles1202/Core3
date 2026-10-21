/*
 * TravelAction.cpp — buy a ticket and board a shuttle (Phase 7.6a travel, Final Boss)
 *
 * Two actions, the two halves of a trip; the walking between them is the seat's business
 * (tools/seat travel puts them together with FbLabTests:travelPoints and pathTo):
 *
 *   ticket  {"action":"ticket","fromPlanet":"tatooine","fromPoint":"Mos_Eisley_Shuttleport",
 *            "toPlanet":"tatooine","toPoint":"Bestine_Shuttleport","roundTrip":false}
 *       sends purchaseTicket (PurchaseTicketCommand: the character must stand within 8 m of a travel
 *       terminal; underscores in point names become spaces), closes the "ticket purchase complete" window
 *       and reports the ticket object(s) that landed in the inventory. A refusal is reported with the
 *       server's system message (@travel:too_far, short_funds, no_location_found, …).
 *
 *   board   {"action":"board","ticket":<oid or 0>,"maxWaitS":240}
 *       sends boardShuttle with the ticket as target (BoardShuttleCommand: within 25 m of the shuttle, a
 *       ticket for this point in the inventory). "The next shuttle will be ready to board in N minutes and
 *       M seconds." is the server's way of saying wait: the action sleeps that long and sends again, up to
 *       maxWaitS. Boarding is a zone switch: the server destroys us from the old world and starts a new
 *       scene (CmdStartScene → ZonePacketHandler: Scene/count, Scene/terrain, Scene/x, Scene/y). The action
 *       waits for that new scene and for the server's CmdSceneReady (Scene/readyCount), then reports where
 *       the character arrived.
 */

#include "client/ActionBase.h"
#include "client/ActionResult.h"
#include "client/ActionManager.h"
#include "client/ClientCore.h"
#include "client/zone/Zone.h"
#include "client/zone/objects/scene/SceneObject.h"
#include "client/zone/objects/ObjectMap.h"
#include "client/zone/managers/object/ObjectManager.h"
#include "client/actions/CommandQueueSend.h"

namespace {

bool travelInZone(ClientCore& core, ActionResult& result, const char* what) {
	if (core.zone == nullptr || !core.zone->isConnected() || !core.zone->isSceneReady()) {
		result.setError(String("Not in the zone (") + what + " needs a zoned-in character)", 1);
		return false;
	}
	return true;
}

int systemMessageCount(ClientCore& core) {
	try {
		const auto& kept = core.vars.at(JSONSerializationType::json_pointer("/SystemMessages"));
		return kept.is_array() ? (int) kept.size() : 0;
	} catch (...) {
		return 0;
	}
}

// the system messages that arrived after index `since` (the store keeps the last 200; `since` is clamped)
Vector<String> systemMessagesSince(ClientCore& core, int since) {
	Vector<String> lines;
	try {
		const auto& kept = core.vars.at(JSONSerializationType::json_pointer("/SystemMessages"));
		if (!kept.is_array())
			return lines;
		int start = since < (int) kept.size() ? since : (int) kept.size();
		for (int i = start; i < (int) kept.size(); ++i)
			if (kept[i].is_string())
				lines.add(String(kept[i].get<std::string>().c_str()));
	} catch (...) {
	}
	return lines;
}

// every object the client holds that is a travel ticket (SceneObjectType::TRAVELTICKET 0x2012)
Vector<uint64> ticketsInView(ClientCore& core) {
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
		if (object->getGameObjectType() == 0x2012)
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

} // namespace

// ------------------------------------------------------------------------------------------ ticket
class TicketAction : public ActionBase {
	String fromPlanet, fromPoint, toPlanet, toPoint;
	bool roundTrip;

	ActionResult result;
	bool skipped;
	Vector<uint64> tickets;
	String serverSaid;

public:
	TicketAction() : roundTrip(false), skipped(false) {
		setLogLevel(Logger::INFO);
		setLoggingName("Ticket");
	}

	const char* getName() const override { return "ticket"; }
	bool needsZone() const override { return true; }
	bool needsTarget() const override { return true; }
	bool needsCharacter() const override { return true; }

	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		if (startIndex + 4 < args.size() && args.get(startIndex) == "--ticket") {
			TicketAction* me = new TicketAction();
			me->fromPlanet = args.get(startIndex + 1);
			me->fromPoint = args.get(startIndex + 2);
			me->toPlanet = args.get(startIndex + 3);
			me->toPoint = args.get(startIndex + 4);
			consumed = 5;
			if (startIndex + 5 < args.size() && args.get(startIndex + 5) == "--ticket-round-trip") {
				me->roundTrip = true;
				consumed = 6;
			}
			result.add(me);
		}
		return result;
	}

	static ActionBase* fromJSON(const JSONSerializationType& config) {
		TicketAction* me = new TicketAction();
		if (config.contains("fromPlanet")) me->fromPlanet = String(config["fromPlanet"].get<std::string>().c_str());
		if (config.contains("fromPoint")) me->fromPoint = String(config["fromPoint"].get<std::string>().c_str());
		if (config.contains("toPlanet")) me->toPlanet = String(config["toPlanet"].get<std::string>().c_str());
		if (config.contains("toPoint")) me->toPoint = String(config["toPoint"].get<std::string>().c_str());
		if (config.contains("roundTrip")) me->roundTrip = config["roundTrip"].get<bool>();
		return me;
	}

	void run(ClientCore& core) override {
		if (!travelInZone(core, result, "ticket")) return;
		if (fromPlanet.isEmpty() || fromPoint.isEmpty() || toPlanet.isEmpty() || toPoint.isEmpty()) {
			result.setError("ticket needs fromPlanet, fromPoint, toPlanet, toPoint", 2);
			return;
		}

		Vector<uint64> before = ticketsInView(core);
		int msgBefore = systemMessageCount(core);
		int suiBefore = core.getVar<int>("Sui/count", 0);

		String args = fromPlanet.replaceAll(" ", "_") + " " + fromPoint.replaceAll(" ", "_") + " " + toPlanet.replaceAll(" ", "_") + " " + toPoint.replaceAll(" ", "_") + (roundTrip ? "" : " single");
		info() << "purchaseTicket " << args;

		uint32 qerr = 0, qstate = 0;
		sendQueueCommand(core, "purchaseticket", 0, UnicodeString(args), 8, qerr, qstate, this);

		// the ticket object arrives as its own create message right after the command; give it a moment
		int waited = 0;
		while (waited < 4000) {
			Thread::sleep(200); waited += 200;
			if (ticketsInView(core).size() > before.size())
				break;
		}

		Vector<uint64> after = ticketsInView(core);
		for (int i = 0; i < after.size(); ++i)
			if (!before.contains(after.get(i)))
				tickets.add(after.get(i));

		Vector<String> said = systemMessagesSince(core, msgBefore);
		for (int i = 0; i < said.size(); ++i)
			serverSaid = serverSaid.isEmpty() ? said.get(i) : serverSaid + " | " + said.get(i);

		// close the "@travel:ticket_purchase_complete" box (a plain message box, OK is enough)
		if (core.getVar<int>("Sui/count", 0) > suiBefore) {
			JSONSerializationType sui;
			sui["action"] = "sui"; sui["value"] = "0"; sui["match"] = "ticket_purchase_complete"; sui["timeout"] = 2;
			String err;
			runSubAction(core, "sui", sui, err);
		}

		if (tickets.size() == 0) {
			if (qerr != 0 && qerr != 0xFFFFFFFF)
				result.setError("purchaseTicket refused (error " + String::valueOf(qerr) + ", state " + String::valueOf(qstate) + "): " + serverSaid, 3);
			else
				result.setError("no ticket landed in the inventory: " + (serverSaid.isEmpty() ? String("(no system message)") : serverSaid), 4);
			return;
		}

		info() << tickets.size() << " ticket(s) bought: " << serverSaid;
		result.setSuccess();
	}

	bool isOK() const override { return !skipped && result.isOK(); }
	String getError() const override { return result.getError(); }
	uint16 getErrorCode() const override { return result.getErrorCode(); }
	void setSkipped() override { skipped = true; }

	JSONSerializationType toJSON() const override {
		JSONSerializationType json;
		json["action"] = getName();
		json["from"] = (fromPlanet + " " + fromPoint).toCharArray();
		json["to"] = (toPlanet + " " + toPoint).toCharArray();
		json["roundTrip"] = roundTrip;
		json["tickets"] = JSONSerializationType::array();
		for (int i = 0; i < tickets.size(); ++i)
			json["tickets"].push_back(tickets.get(i));
		json["ticket"] = tickets.size() > 0 ? tickets.get(0) : (uint64) 0;
		json["serverSaid"] = serverSaid.toCharArray();
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
		return "--ticket <fromPlanet> <fromPoint> <toPlanet> <toPoint> [--ticket-round-trip]  Buy a travel ticket at the terminal you stand by (underscores for spaces in point names)";
	}

	static ActionBase* factory() { return new TicketAction(); }
};

static bool _registered_ticket =
	(ActionManager::registerAction("ticket", TicketAction::factory, TicketAction::fromArgs, TicketAction::fromJSON), true);

// ------------------------------------------------------------------------------------------ board
class BoardAction : public ActionBase {
	uint64 ticket;
	int maxWaitS;

	ActionResult result;
	bool skipped;
	int attempts;
	int waitedS;
	String serverSaid;
	String terrain;
	float arrivedX, arrivedY;

public:
	BoardAction() : ticket(0), maxWaitS(240), skipped(false), attempts(0), waitedS(0), arrivedX(0), arrivedY(0) {
		setLogLevel(Logger::INFO);
		setLoggingName("Board");
	}

	const char* getName() const override { return "board"; }
	bool needsZone() const override { return true; }
	bool needsTarget() const override { return true; }
	bool needsCharacter() const override { return true; }

	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		if (startIndex < args.size() && args.get(startIndex) == "--board") {
			BoardAction* me = new BoardAction();
			consumed = 1;
			if (startIndex + 1 < args.size() && !args.get(startIndex + 1).beginsWith("--")) {
				me->ticket = UnsignedLong::valueOf(args.get(startIndex + 1));
				consumed = 2;
			}
			if (startIndex + consumed + 1 < args.size() && args.get(startIndex + consumed) == "--board-wait") {
				me->maxWaitS = Integer::valueOf(args.get(startIndex + consumed + 1));
				consumed += 2;
			}
			result.add(me);
		}
		return result;
	}

	static ActionBase* fromJSON(const JSONSerializationType& config) {
		BoardAction* me = new BoardAction();
		if (config.contains("ticket")) me->ticket = config["ticket"].get<uint64>();
		if (config.contains("maxWaitS")) me->maxWaitS = config["maxWaitS"].get<int>();
		return me;
	}

	// "The next shuttle will be ready to board in 1 minute and 12 seconds." → seconds, or -1
	static int parseDelay(const String& line) {
		if (!line.contains("ready to board in"))
			return -1;
		int seconds = 0;
		StringTokenizer words(line);
		int number = -1;
		while (words.hasMoreTokens()) {
			String word;
			words.getStringToken(word);
			if (word.length() > 0 && Character::isDigit(word.charAt(0))) {
				number = Integer::valueOf(word);
			} else if (number >= 0 && word.beginsWith("minute")) {
				seconds += number * 60; number = -1;
			} else if (number >= 0 && word.beginsWith("second")) {
				seconds += number; number = -1;
			}
		}
		return seconds;
	}

	void run(ClientCore& core) override {
		if (!travelInZone(core, result, "board")) return;

		int sceneBefore = core.getVar<int>("Scene/count", 0);
		int readyBefore = core.getVar<int>("Scene/readyCount", 0);
		Time started;

		while (true) {
			int msgBefore = systemMessageCount(core);
			attempts++;
			uint32 qerr = 0, qstate = 0;
			sendQueueCommand(core, "boardshuttle", ticket, UnicodeString(""), 5, qerr, qstate, this);

			// a zone switch shows up as a new scene within a few seconds; a refusal as a system message
			int waited = 0;
			while (waited < 6000 && core.getVar<int>("Scene/count", 0) == sceneBefore) {
				Thread::sleep(200); waited += 200;
				Vector<String> said = systemMessagesSince(core, msgBefore);
				if (said.size() > 0)
					break;
			}

			if (core.getVar<int>("Scene/count", 0) > sceneBefore)
				break;

			Vector<String> said = systemMessagesSince(core, msgBefore);
			serverSaid = "";
			for (int i = 0; i < said.size(); ++i)
				serverSaid = serverSaid.isEmpty() ? said.get(i) : serverSaid + " | " + said.get(i);

			int delay = -1;
			for (int i = 0; i < said.size() && delay < 0; ++i)
				delay = parseDelay(said.get(i));
			if (delay < 0 && serverSaid.contains("about to begin boarding"))
				delay = 5;

			if (delay < 0) {
				if (said.size() == 0 && qerr != 0 && qerr != 0xFFFFFFFF)
					result.setError("boardShuttle refused (error " + String::valueOf(qerr) + ", state " + String::valueOf(qstate) + ")", 3);
				else if (said.size() == 0)
					result.setError("boardShuttle sent, no scene change and no system message within 6 s", 4);
				else
					result.setError("boardShuttle refused: " + serverSaid, 5);
				return;
			}

			int elapsed = (int) (started.miliDifference() / 1000);
			if (elapsed + delay > maxWaitS) {
				result.setError("shuttle not back within maxWaitS (" + String::valueOf(maxWaitS) + " s): " + serverSaid, 6);
				return;
			}
			info() << "shuttle away: " << serverSaid << " — waiting " << delay + 2 << " s";
			Thread::sleep((delay + 2) * 1000);
			waitedS = (int) (started.miliDifference() / 1000);

			if (!core.zone->isConnected()) {
				result.setError("zone connection lost while waiting for the shuttle", 7);
				return;
			}
		}

		// the new scene: wait for the server's CmdSceneReady, then let the objects stream in
		int waited = 0;
		while (waited < 20000 && core.getVar<int>("Scene/readyCount", 0) == readyBefore) {
			Thread::sleep(200); waited += 200;
		}
		if (core.getVar<int>("Scene/readyCount", 0) == readyBefore) {
			result.setError("new scene started but no CmdSceneReady within 20 s", 8);
			return;
		}
		Thread::sleep(2000);

		terrain = core.getVar("Scene/terrain", String(""));
		arrivedX = core.getVar<float>("Scene/x", 0);
		arrivedY = core.getVar<float>("Scene/y", 0);
		waitedS = (int) (started.miliDifference() / 1000);
		info() << "arrived on " << terrain << " at " << arrivedX << ", " << arrivedY << " after " << attempts << " attempt(s), " << waitedS << " s";
		result.setSuccess();
	}

	bool isOK() const override { return !skipped && result.isOK(); }
	String getError() const override { return result.getError(); }
	uint16 getErrorCode() const override { return result.getErrorCode(); }
	void setSkipped() override { skipped = true; }

	JSONSerializationType toJSON() const override {
		JSONSerializationType json;
		json["action"] = getName();
		json["ticket"] = ticket;
		json["attempts"] = attempts;
		json["waitedS"] = waitedS;
		json["serverSaid"] = serverSaid.toCharArray();
		json["terrain"] = terrain.toCharArray();
		json["x"] = arrivedX;
		json["y"] = arrivedY;
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
		return "--board [<ticket oid>] [--board-wait <s>]  Board the shuttle you stand by with that ticket, waiting for it to land (default up to 240 s)";
	}

	static ActionBase* factory() { return new BoardAction(); }
};

static bool _registered_board =
	(ActionManager::registerAction("board", BoardAction::factory, BoardAction::fromArgs, BoardAction::fromJSON), true);
