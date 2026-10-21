/*
 * SurveyAction.cpp — survey and sample (Phase 7.6a, Final Boss)
 *
 *   --survey <tool oid> <resource name> [--survey-range <0-5>]
 *       uses the survey tool (radial 20), answers the range window if it opens (row = --survey-range, default the
 *       biggest the skill allows), sends requestSurvey <resource> and waits for the SurveyMessage grid.
 *       JSON: {"action":"survey","tool":<oid>,"resource":"Name","range":5}
 *       Result: the grid and the best point (Survey/grid, bestX, bestY, bestPct in the var store too).
 *   --sample <resource name> [--sample-rounds N]
 *       sends requestCoreSample <resource>; the server answers in ~3 s and then re-samples every 25 s on its own
 *       until the character moves, fights or the session ends. Waits for N rounds (default 1) and reports the
 *       "@survey:…" system messages seen (sample_located = units gained, trace_amount, sample_failed,
 *       density_below_threshold). The open survey tool must have been used first (a survey of the same resource).
 *       JSON: {"action":"sample","resource":"Name","rounds":2}
 */

#include "client/ActionBase.h"
#include "client/ActionResult.h"
#include "client/ActionManager.h"
#include "client/ClientCore.h"
#include "client/zone/Zone.h"
#include "client/actions/CommandQueueSend.h"

namespace {

bool inZoneFor(ClientCore& core, ActionResult& result, const char* what) {
	if (core.zone == nullptr || !core.zone->isConnected() || !core.zone->isSceneReady()) {
		result.setError(String("Not in the zone (") + what + " needs a zoned-in character)", 1);
		return false;
	}
	return true;
}

// run another registered action from its JSON form (radial, sui) and tell whether it succeeded
bool runSub(ClientCore& core, const char* name, const JSONSerializationType& config, String& error) {
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

int countSystemMessages(ClientCore& core, const char* needle) {
	int n = 0;
	try {
		const auto& kept = core.vars.at(JSONSerializationType::json_pointer("/SystemMessages"));
		if (kept.is_array())
			for (const auto& line : kept)
				if (line.is_string() && line.get<std::string>().find(needle) != std::string::npos)
					n++;
	} catch (...) {
	}
	return n;
}

}

// ===================================================================== survey
class SurveyAction : public ActionBase {
	uint64 tool;
	String resource;
	int range;
	ActionResult result;
	bool skipped;
	JSONSerializationType grid;
	float bestX, bestY, bestPct;

public:
	SurveyAction() : tool(0), range(-1), skipped(false), bestX(0), bestY(0), bestPct(-1) {
		setLogLevel(Logger::INFO);
		setLoggingName("Survey");
	}

	const char* getName() const override { return "survey"; }
	bool needsZone() const override { return true; }
	bool needsTarget() const override { return true; }
	bool needsCharacter() const override { return true; }

	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		SurveyAction* me = nullptr;
		int i = startIndex;
		while (i < args.size()) {
			int lastConsumed = consumed;
			if (args.get(i) == "--survey" && i + 2 < args.size()) {
				if (me != nullptr) break;
				me = new SurveyAction();
				me->tool = UnsignedLong::valueOf(args.get(i + 1));
				me->resource = args.get(i + 2);
				consumed += 3; i += 3;
			} else if (me != nullptr && args.get(i) == "--survey-range" && i + 1 < args.size()) {
				me->range = Integer::valueOf(args.get(i + 1));
				consumed += 2; i += 2;
			}
			if (consumed == lastConsumed) break;
		}
		if (me != nullptr) result.add(me);
		return result;
	}

	static ActionBase* fromJSON(const JSONSerializationType& config) {
		SurveyAction* me = new SurveyAction();
		if (config.contains("tool")) me->tool = config["tool"].is_string() ? UnsignedLong::valueOf(String(config["tool"].get<std::string>().c_str())) : config["tool"].get<uint64>();
		if (config.contains("resource")) me->resource = String(config["resource"].get<std::string>().c_str());
		if (config.contains("range")) me->range = config["range"].get<int>();
		return me;
	}

	void run(ClientCore& core) override {
		if (!inZoneFor(core, result, "survey")) return;
		if (tool == 0 || resource.isEmpty()) { result.setError("survey needs a tool oid and a resource name", 2); return; }

		// forget the last survey so a stale grid cannot pass as this one
		core.vars.erase("Survey");
		int suiBefore = core.getVar<int>("Sui/count", 0);

		// 1. use the tool: the server answers with the resource list, or with the range window first
		JSONSerializationType radial;
		radial["action"] = "radial"; radial["target"] = tool; radial["radialId"] = 20; radial["settleMs"] = 800;
		String err;
		if (!runSub(core, "radial", radial, err)) { result.setError("using the survey tool failed: " + err, 3); return; }

		int waited = 0;
		while (!core.hasVar("Survey/toolType") && core.getVar<int>("Sui/count", 0) == suiBefore && waited < 5000) {
			Thread::sleep(100); waited += 100;
		}

		if (!core.hasVar("Survey/toolType") && core.getVar<int>("Sui/count", 0) > suiBefore) {
			// the range window ("64m x 3pts" … "384m x 5pts"): pick the asked row, else the last one
			int rows = 0;
			int last = core.getVar<int>("Sui/last", 0);
			rows = core.getVar<int>("Sui/p" + String::valueOf(last) + "/rowCount", 0);
			int pick = range >= 0 ? range : rows - 1;
			if (pick < 0) pick = 0;
			JSONSerializationType sui;
			sui["action"] = "sui"; sui["value"] = String::valueOf(pick).toCharArray(); sui["match"] = "select_range"; sui["timeout"] = 5;
			if (!runSub(core, "sui", sui, err)) { result.setError("answering the range window failed: " + err, 4); return; }
			info() << "range window answered with row " << pick << " of " << rows;
			// the tool must be used again after the range is set
			if (!runSub(core, "radial", radial, err)) { result.setError("using the survey tool (again) failed: " + err, 3); return; }
			waited = 0;
			while (!core.hasVar("Survey/toolType") && waited < 5000) { Thread::sleep(100); waited += 100; }
		}

		if (!core.hasVar("Survey/toolType")) { result.setError("no resource list from the survey tool within 5 s (wrong oid, or not a survey tool?)", 5); return; }

		// 2. is the resource on this tool's list?
		bool listed = false;
		try {
			for (const auto& r : core.vars.at(JSONSerializationType::json_pointer("/Survey/resources")))
				if (r.contains("name") && String(r["name"].get<std::string>().c_str()).toLowerCase() == resource.toLowerCase())
					listed = true;
		} catch (...) {}
		if (!listed) { result.setError("'" + resource + "' is not on this tool's list here (see Survey/resources)", 6); return; }

		// 3. the survey itself
		uint32 qerr = 0, qstate = 0;
		sendQueueCommand(core, "requestsurvey", 0, UnicodeString(resource), 1, qerr, qstate, this);
		if (qerr != 0xFFFFFFFF && qerr != 0) { result.setError("requestSurvey rejected: error=" + String::valueOf(qerr) + " state=" + String::valueOf(qstate), 7); return; }

		waited = 0;
		while (!core.hasVar("Survey/bestPct") && waited < 10000) { Thread::sleep(100); waited += 100; }
		if (!core.hasVar("Survey/bestPct")) { result.setError("no SurveyMessage within 10 s", 8); return; }

		try { grid = core.vars.at(JSONSerializationType::json_pointer("/Survey/grid")); } catch (...) {}
		bestX = core.getVar<float>("Survey/bestX", 0);
		bestY = core.getVar<float>("Survey/bestY", 0);
		bestPct = core.getVar<float>("Survey/bestPct", -1);
		// the server sends the concentration as a 0..1 fraction (the client shows it as a percentage)
		info() << "surveyed " << resource << ": best " << (bestPct * 100.f) << "% at " << bestX << ", " << bestY;
		result.setSuccess();
	}

	bool isOK() const override { return !skipped && result.isOK(); }
	String getError() const override { return result.getError(); }
	uint16 getErrorCode() const override { return result.getErrorCode(); }
	void setSkipped() override { skipped = true; }

	JSONSerializationType toJSON() const override {
		JSONSerializationType json;
		json["action"] = getName();
		json["tool"] = tool;
		json["resource"] = resource.toCharArray();
		if (range >= 0) json["range"] = range;
		if (bestPct >= 0) { json["bestX"] = bestX; json["bestY"] = bestY; json["bestPct"] = bestPct; json["grid"] = grid; }
		if (skipped) json["status"] = "skipped";
		else if (result.isOK()) json["status"] = "ok";
		else { json["status"] = "failed"; json["error"] = result.getError().toCharArray(); json["errorCode"] = result.getErrorCode(); }
		return json;
	}

	String getHelpText() const override {
		return "--survey <tool oid> <resource name> [--survey-range <0-5>]  Use a survey tool, survey that resource, report the grid and the best point";
	}

	static ActionBase* factory() { return new SurveyAction(); }
};

static bool _registered_survey =
	(ActionManager::registerAction("survey", SurveyAction::factory, SurveyAction::fromArgs, SurveyAction::fromJSON), true);

// ===================================================================== sample
class SampleAction : public ActionBase {
	String resource;
	int rounds;
	ActionResult result;
	bool skipped;
	int located, trace, failed, below;

public:
	SampleAction() : rounds(1), skipped(false), located(0), trace(0), failed(0), below(0) {
		setLogLevel(Logger::INFO);
		setLoggingName("Sample");
	}

	const char* getName() const override { return "sample"; }
	bool needsZone() const override { return true; }
	bool needsTarget() const override { return true; }
	bool needsCharacter() const override { return true; }

	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		SampleAction* me = nullptr;
		int i = startIndex;
		while (i < args.size()) {
			int lastConsumed = consumed;
			if (args.get(i) == "--sample" && i + 1 < args.size()) {
				if (me != nullptr) break;
				me = new SampleAction();
				me->resource = args.get(i + 1);
				consumed += 2; i += 2;
			} else if (me != nullptr && args.get(i) == "--sample-rounds" && i + 1 < args.size()) {
				me->rounds = Integer::valueOf(args.get(i + 1));
				consumed += 2; i += 2;
			}
			if (consumed == lastConsumed) break;
		}
		if (me != nullptr) result.add(me);
		return result;
	}

	static ActionBase* fromJSON(const JSONSerializationType& config) {
		SampleAction* me = new SampleAction();
		if (config.contains("resource")) me->resource = String(config["resource"].get<std::string>().c_str());
		if (config.contains("rounds")) me->rounds = config["rounds"].get<int>();
		return me;
	}

	void run(ClientCore& core) override {
		if (!inZoneFor(core, result, "sample")) return;
		if (resource.isEmpty()) { result.setError("sample needs a resource name", 2); return; }
		if (rounds < 1) rounds = 1;

		int locatedBefore = countSystemMessages(core, "sample_located");
		int traceBefore = countSystemMessages(core, "trace_amount");
		int failedBefore = countSystemMessages(core, "sample_failed");
		int belowBefore = countSystemMessages(core, "density_below_threshold");

		uint32 qerr = 0, qstate = 0;
		sendQueueCommand(core, "requestcoresample", 0, UnicodeString(resource), 1, qerr, qstate, this);
		if (qerr != 0xFFFFFFFF && qerr != 0) { result.setError("requestCoreSample rejected: error=" + String::valueOf(qerr) + " state=" + String::valueOf(qstate), 3); return; }

		// first result after ~3 s, then one every 25 s
		int waitMs = 5000 + (rounds - 1) * 25000;
		info() << "sampling " << resource << " for " << rounds << " round(s), " << waitMs / 1000 << " s";
		Thread::sleep(waitMs);

		located = countSystemMessages(core, "sample_located") - locatedBefore;
		trace = countSystemMessages(core, "trace_amount") - traceBefore;
		failed = countSystemMessages(core, "sample_failed") - failedBefore;
		below = countSystemMessages(core, "density_below_threshold") - belowBefore;

		if (located + trace + failed + below == 0) {
			result.setError("no sample result at all (no open survey tool / survey session?)", 4);
			return;
		}
		info() << "located " << located << ", trace " << trace << ", failed " << failed << ", below threshold " << below;
		result.setSuccess();
	}

	bool isOK() const override { return !skipped && result.isOK(); }
	String getError() const override { return result.getError(); }
	uint16 getErrorCode() const override { return result.getErrorCode(); }
	void setSkipped() override { skipped = true; }

	JSONSerializationType toJSON() const override {
		JSONSerializationType json;
		json["action"] = getName();
		json["resource"] = resource.toCharArray();
		json["rounds"] = rounds;
		json["located"] = located; json["trace"] = trace; json["failed"] = failed; json["belowThreshold"] = below;
		if (skipped) json["status"] = "skipped";
		else if (result.isOK()) json["status"] = "ok";
		else { json["status"] = "failed"; json["error"] = result.getError().toCharArray(); json["errorCode"] = result.getErrorCode(); }
		return json;
	}

	String getHelpText() const override {
		return "--sample <resource name> [--sample-rounds N]  Sample the surveyed resource where you stand (first result in 3 s, then every 25 s)";
	}

	static ActionBase* factory() { return new SampleAction(); }
};

static bool _registered_sample =
	(ActionManager::registerAction("sample", SampleAction::factory, SampleAction::fromArgs, SampleAction::fromJSON), true);
