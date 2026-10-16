/*
 * WaitAction.cpp
 *
 * Sleeps for N seconds in the middle of an action list, so a scenario can let the server
 * tick (buff timers, regen, respawns) between steps.
 *
 *   --wait <seconds>
 *   JSON: {"action":"wait","seconds":5}
 */

#include "client/ActionBase.h"
#include "client/ActionResult.h"
#include "client/ActionManager.h"
#include "client/ClientCore.h"

class WaitAction : public ActionBase {
	int seconds;
	ActionResult result;
	bool skipped;

public:
	WaitAction() : seconds(1), skipped(false) {
		setLogLevel(Logger::INFO);
		setLoggingName("Wait");
	}

	const char* getName() const override { return "wait"; }
	bool needsZone() const override { return false; }

	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		if (startIndex + 1 < args.size() && args.get(startIndex) == "--wait") {
			WaitAction* me = new WaitAction();
			me->seconds = Integer::valueOf(args.get(startIndex + 1));
			consumed = 2;
			result.add(me);
		}
		return result;
	}

	static ActionBase* fromJSON(const JSONSerializationType& config) {
		WaitAction* me = new WaitAction();
		if (config.contains("seconds")) me->seconds = config["seconds"].get<int>();
		return me;
	}

	void run(ClientCore& core) override {
		info() << "waiting " << seconds << "s";
		Thread::sleep(seconds * 1000);
		result.setSuccess();
	}

	bool isOK() const override { return !skipped && result.isOK(); }
	String getError() const override { return result.getError(); }
	uint16 getErrorCode() const override { return result.getErrorCode(); }
	void setSkipped() override { skipped = true; }

	JSONSerializationType toJSON() const override {
		JSONSerializationType json;
		json["action"] = getName();
		json["seconds"] = seconds;
		json["status"] = skipped ? "skipped" : (result.isOK() ? "ok" : "failed");
		return json;
	}

	String getHelpText() const override {
		return "--wait <seconds>  Pause between actions";
	}

	static ActionBase* factory() { return new WaitAction(); }
};

static bool _registered_wait =
	(ActionManager::registerAction("wait", WaitAction::factory, WaitAction::fromArgs, WaitAction::fromJSON), true);
