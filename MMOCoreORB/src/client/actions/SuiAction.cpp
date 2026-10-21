/*
 * SuiAction.cpp
 *
 * Answers a server UI window (SUI). ZonePacketHandler::handleSuiCreatePageMessage records every
 * window the server opens under Sui/p<pageId>/... and Sui/last; this action waits for a window
 * (optionally one whose root/title/prompt contains --sui-match) and answers it:
 *
 *   --sui <row|text> [--sui-match <fragment>] [--sui-cancel] [--sui-timeout <sec>]
 *       list box: <row> is the 0-based row index; input box: <text> is typed into the field
 *       --sui-cancel presses Cancel instead of OK
 *   JSON: {"action":"sui","value":"0","match":"Schematic Broker","cancel":false,"timeout":10}
 *         {"action":"sui","values":["4500","500"],"match":"select_amount"}   several arguments: a transfer box
 *         (pay maintenance, deposit power) reads the second one as the amount moved
 *
 * Wire: SuiEventNotification (0x092D3564): int pageId, int eventIndex, int listSize1, int listSize2,
 * then listSize1 unicode arguments. For Lua page boxes eventIndex is the index of the
 * subscribeToEvent command for the pressed button (OK = event type 9, Cancel = 0x0A), recorded by
 * the handler as Sui/p<id>/okEvent and /cancelEvent; legacy C++ boxes use 0 (OK) / 1 (Cancel).
 */

#include "client/ActionBase.h"
#include "client/ActionResult.h"
#include "client/ActionManager.h"
#include "client/ClientCore.h"
#include "client/zone/Zone.h"
#include "client/zone/ZoneClient.h"
#include "engine/service/proto/BaseMessage.h"

class ClientSuiEventNotification : public BaseMessage {
public:
	ClientSuiEventNotification(uint32 pageId, uint32 eventIndex, const Vector<UnicodeString>& args) {
		insertShort(0x05);
		insertInt(0x092D3564);   // SuiEventNotification
		insertInt(pageId);
		insertInt(eventIndex);
		insertInt(args.size());  // listSize1: number of unicode arguments
		insertInt(args.size());  // listSize2 (ignored by the server)
		for (int i = 0; i < args.size(); ++i)
			insertUnicode(args.get(i));
	}
};

class SuiAction : public ActionBase {
	String value;
	Vector<String> values;   // several arguments (transfer boxes); when set, value is ignored
	String match;
	bool cancel;
	int timeoutSeconds;

	ActionResult result;
	bool skipped;
	uint32 pageId;

public:
	SuiAction() : cancel(false), timeoutSeconds(10), skipped(false), pageId(0) {
		setLogLevel(Logger::INFO);
		setLoggingName("Sui");
	}

	const char* getName() const override { return "sui"; }
	bool needsZone() const override { return true; }
	bool needsTarget() const override { return true; }
	bool needsCharacter() const override { return true; }

	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		SuiAction* me = nullptr;
		int i = startIndex;
		while (i < args.size()) {
			int last = consumed;
			if (args.get(i) == "--sui" && i + 1 < args.size()) {
				if (me != nullptr) break;
				me = new SuiAction();
				me->value = args.get(i + 1);
				consumed += 2; i += 2;
			} else if (me != nullptr && args.get(i) == "--sui-match" && i + 1 < args.size()) {
				me->match = args.get(i + 1);
				consumed += 2; i += 2;
			} else if (me != nullptr && args.get(i) == "--sui-timeout" && i + 1 < args.size()) {
				me->timeoutSeconds = Integer::valueOf(args.get(i + 1));
				consumed += 2; i += 2;
			} else if (me != nullptr && args.get(i) == "--sui-cancel") {
				me->cancel = true;
				consumed += 1; i += 1;
			}
			if (consumed == last) break;
		}
		if (me != nullptr) result.add(me);
		return result;
	}

	static ActionBase* fromJSON(const JSONSerializationType& config) {
		SuiAction* me = new SuiAction();
		if (config.contains("value")) me->value = String(config["value"].get<std::string>().c_str());
		if (config.contains("values") && config["values"].is_array())
			for (const auto& v : config["values"])
				me->values.add(v.is_string() ? String(v.get<std::string>().c_str()) : String::valueOf(v.get<long long>()));
		if (config.contains("match")) me->match = String(config["match"].get<std::string>().c_str());
		if (config.contains("cancel")) me->cancel = config["cancel"].get<bool>();
		if (config.contains("timeout")) me->timeoutSeconds = config["timeout"].get<int>();
		return me;
	}

	// The newest unanswered page whose root/title/prompt contains --sui-match (any page if no
	// match given), scanning every page seen newest first: unrelated windows (e.g. the new-player
	// helper droid's greetings) must not hide the one the scenario is waiting for.
	uint32 findPage(ClientCore& core) {
		int count = core.getVar<int>("Sui/count", 0);
		for (int n = count - 1; n >= 0; --n) {
			uint32 id = core.getVar<uint32>("Sui/ids/i" + String::valueOf(n), 0);
			if (id == 0) continue;
			String base = "Sui/p" + String::valueOf(id);
			if (core.getVar<bool>(base + "/answered", false)) continue;
			if (!match.isEmpty()) {
				String hay = core.getVar(base + "/root", String("")) + " | " + core.getVar(base + "/title", String("")) + " | " + core.getVar(base + "/prompt", String(""));
				if (hay.toLowerCase().indexOf(match.toLowerCase()) == -1) continue;
			}
			return id;
		}
		return 0;
	}

	void run(ClientCore& core) override {
		if (core.zone == nullptr || !core.zone->isConnected() || !core.zone->isSceneReady()) {
			result.setError("Not in the zone", 1);
			return;
		}

		int waited = 0;
		while ((pageId = findPage(core)) == 0 && waited < timeoutSeconds * 1000) {
			Thread::sleep(100);
			waited += 100;
		}
		if (pageId == 0) {
			result.setError("No SUI window" + (match.isEmpty() ? String("") : " matching '" + match + "'") + " within " + String::valueOf(timeoutSeconds) + "s", 3);
			return;
		}

		String base = "Sui/p" + String::valueOf(pageId);
		uint32 eventIndex = cancel ? core.getVar<uint32>(base + "/cancelEvent", 1) : core.getVar<uint32>(base + "/okEvent", 0);
		int rows = core.getVar<int>(base + "/rowCount", 0);

		// A list box answers with the row index. A non-numeric value picks the first row whose text
		// contains it (case-insensitive), so scenarios can say --sui "Throw Pillow" instead of a
		// position that moves when the catalogue changes. Input boxes get the text as typed.
		String answer = value;
		bool numeric = !value.isEmpty();
		for (int i = 0; i < value.length() && numeric; ++i)
			numeric = ::isdigit((unsigned char) value.charAt(i)) != 0;
		if (!numeric && rows > 0) {
			String needle = value.toLowerCase();
			for (int r = 0; r < rows; ++r) {
				String row = core.getVar(base + "/rows/r" + String::valueOf(r), String(""));
				if (row.toLowerCase().indexOf(needle) != -1) {
					answer = String::valueOf(r);
					info() << "row '" << row << "' matches '" << value << "' -> index " << r;
					break;
				}
			}
			if (answer == value) {
				result.setError("No list row contains '" + value + "' (" + String::valueOf(rows) + " rows)", 5);
				core.setVar(base + "/answered", true);
				return;
			}
		}

		info() << "answering SUI page " << pageId << " root='" << core.getVar(base + "/root", String("")) << "' title='" << core.getVar(base + "/title", String(""))
			<< "' rows=" << rows << " with " << (cancel ? "cancel" : "ok") << " value='" << answer << "' event=" << eventIndex;

		Vector<UnicodeString> args;
		if (values.size() > 0) {
			for (int i = 0; i < values.size(); ++i)
				args.add(UnicodeString(values.get(i)));
		} else {
			args.add(UnicodeString(answer));
		}
		core.zone->getZoneClient()->sendMessage(new ClientSuiEventNotification(pageId, eventIndex, args));
		core.setVar(base + "/answered", true);

		Thread::sleep(500);   // let the server act (a purchase, the next window, ...)
		result.setSuccess();
	}

	bool isOK() const override { return !skipped && result.isOK(); }
	String getError() const override { return result.getError(); }
	uint16 getErrorCode() const override { return result.getErrorCode(); }
	void setSkipped() override { skipped = true; }

	JSONSerializationType toJSON() const override {
		JSONSerializationType json;
		json["action"] = getName();
		json["value"] = value.toCharArray();
		if (!match.isEmpty()) json["match"] = match.toCharArray();
		if (cancel) json["cancel"] = true;
		if (pageId) json["pageId"] = pageId;
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
		return "--sui <row|text> [--sui-match <fragment>] [--sui-cancel] [--sui-timeout <sec>]  Answer the next server UI window (list row index or input text)";
	}
	static ActionBase* factory() { return new SuiAction(); }
};

static bool _registered_sui =
	(ActionManager::registerAction("sui", SuiAction::factory, SuiAction::fromArgs, SuiAction::fromJSON), true);
