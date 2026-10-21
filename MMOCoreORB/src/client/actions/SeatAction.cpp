/*
 * SeatAction.cpp — the seat daemon (Phase 7.0, Final Boss)
 *
 * Keeps the character logged in and serves a JSON-lines control channel on a unix socket, so a
 * driver (tools/seat, later a citizen's pilot) can act and perceive for hours without a new login
 * per step. Everything the one-shot client can do (command, radial, converse, sui, missions,
 * auctions, say, tell, emote, wait) is available as an "action" request; the var store the packet
 * handler fills (SpatialChat, SystemMessages, Tells, Sui pages, Conversation) is the perception.
 *
 *   --seat <socket path> [--seat-timeout <seconds>]     JSON: {"action":"seat","socket":"/tmp/x.sock","timeout":0}
 *
 * Protocol: one JSON object per line each way; a reply repeats the request's "id" when given.
 *   {"op":"ping"}                                   -> {"ok":true,"character":<oid>,"sceneReady":true,"uptimeMs":n,"requests":n}
 *   {"op":"action","action":{"action":"command","name":"sitServer","nowait":true}}
 *                                                   -> {"ok":<the action's verdict>,"result":<the action's toJSON()>}
 *   {"op":"vars"[,"path":"/SpatialChat"]}          -> {"ok":true,"vars":<the store, or the value at path (null if none)>}
 *   {"op":"objects"}                                -> {"ok":true,"objects":[{"oid","crc","name","type","x","y","z","parent"}…]}
 *                                                      (what the server has created in our view; positions are the ones
 *                                                      sent at creation — others' movement is not decoded yet)
 *   {"op":"wait","signal":"SpatialChat","timeoutMs":5000} -> {"ok":true,"fired":bool}  (blocks until that packet arrives;
 *                                                      signals: SpatialChat, Tell, ChatSystemMessage, SuiCreatePage,
 *                                                      StartNpcConversation, CommandQueueRemove, Weather, …)
 *   {"op":"quit"}                                   -> {"ok":true}, the seat ends and the auto-appended logout runs
 *
 * The seat ends on its own when the zone connection drops or the timeout passes. Login-phase
 * actions (loginAccount, zoneInCharacter, logoutCharacter, createCharacter, seat) are refused on
 * the channel: they would break the session the seat is keeping.
 */

#include <signal.h>
#include "client/ActionBase.h"
#include "client/ActionResult.h"
#include "client/ActionManager.h"
#include "client/ClientCore.h"
#include "client/zone/Zone.h"
#include "client/zone/ZoneClient.h"
#include "client/zone/objects/ObjectMap.h"
#include "client/zone/objects/scene/SceneObject.h"
#include "client/zone/managers/object/ObjectManager.h"

#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <unistd.h>
#include <poll.h>
#include <errno.h>
#include <string.h>
#include <string>
#include <thread>
#include <mutex>
#include <atomic>
#include <vector>
#include <set>

class SeatAction : public ActionBase {
	String socketPath;
	int timeoutSeconds;   // 0 = serve until quit

	ActionResult result;
	bool skipped;
	bool failed;
	std::atomic<int> requests;
	Time started;

	// every driver gets its own thread (a pilot holds its connection for life and spends most of it in 30 s waits;
	// with one driver at a time every other seat command queued behind it until it timed out): requests other than
	// wait are serialized by handleLock, a wait blocks only on the zone's condition
	std::mutex handleLock;
	std::mutex driversLock;
	std::set<int> driverFds;
	std::vector<std::thread> driverThreads;
	std::atomic<bool> stopping;

public:
	SeatAction() : timeoutSeconds(0), skipped(false), failed(false), requests(0), stopping(false) {
		setLogLevel(Logger::INFO);
		setLoggingName("Seat");
	}

	const char* getName() const override { return "seat"; }
	bool needsZone() const override { return true; }
	bool needsTarget() const override { return true; }
	bool needsCharacter() const override { return true; }

	// ===== Static Factories =====
	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		SeatAction* me = nullptr;
		int i = startIndex;

		while (i < args.size()) {
			int lastConsumed = consumed;

			if (args.get(i) == "--seat" && i + 1 < args.size()) {
				if (me != nullptr) break;
				me = new SeatAction();
				me->socketPath = args.get(i + 1);
				consumed += 2; i += 2;
			} else if (me != nullptr && args.get(i) == "--seat-timeout" && i + 1 < args.size()) {
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
		SeatAction* me = new SeatAction();
		if (config.contains("socket")) me->socketPath = String(config["socket"].get<std::string>().c_str());
		if (config.contains("timeout")) me->timeoutSeconds = config["timeout"].get<int>();
		return me;
	}

	// ===== The channel =====
	void fail(const String& msg, uint16 code) {
		std::lock_guard<std::mutex> guard(handleLock);
		if (failed)
			return;
		error() << msg;
		result.setError(msg, code);
		failed = true;
	}

	bool timedOut() const {
		return timeoutSeconds > 0 && started.miliDifference() > (int64) timeoutSeconds * 1000;
	}

	static bool writeAll(int fd, const std::string& data) {
		size_t done = 0;
		while (done < data.size()) {
			ssize_t n = ::write(fd, data.data() + done, data.size() - done);
			if (n < 0) {
				if (errno == EINTR) continue;
				return false;
			}
			done += n;
		}
		return true;
	}

	JSONSerializationType listObjects(ClientCore& core) {
		JSONSerializationType list = JSONSerializationType::array();
		ObjectManager* objectManager = core.zone->getObjectManager();
		if (objectManager == nullptr)
			return list;

		Locker lock(objectManager);
		ObjectMap* map = objectManager->getObjectMap();
		if (map == nullptr)
			return list;

		HashTableIterator<uint64, Reference<SceneObject*> > iter = map->iterator();
		while (iter.hasNext()) {
			SceneObject* object = iter.getNextValue();
			if (object == nullptr)
				continue;

			JSONSerializationType entry;
			entry["oid"] = object->getObjectID();
			entry["crc"] = object->getObjectCRC();
			entry["name"] = object->getObjectName().toCharArray();
			entry["type"] = object->getGameObjectType();
			entry["x"] = object->getPositionX();
			entry["y"] = object->getPositionY();
			entry["z"] = object->getPositionZ();
			SceneObject* parent = object->getParent();
			entry["parent"] = parent != nullptr ? parent->getObjectID() : (uint64) 0;
			list.push_back(entry);
		}

		return list;
	}

	JSONSerializationType handle(ClientCore& core, const JSONSerializationType& req, bool& quit) {
		JSONSerializationType reply = JSONSerializationType::object();
		if (req.contains("id"))
			reply["id"] = req["id"];

		std::string op = req.value("op", std::string(""));

		try {
			if (op == "ping") {
				reply["ok"] = true;
				reply["character"] = core.selectedCharacterOid;
				reply["sceneReady"] = core.zone->isSceneReady();
				reply["connected"] = core.zone->isConnected();
				reply["uptimeMs"] = started.miliDifference();
				reply["requests"] = requests.load();
			} else if (op == "action") {
				if (!req.contains("action") || !req["action"].is_object() || !req["action"].contains("action")) {
					reply["ok"] = false;
					reply["error"] = "action needs {\"action\":{\"action\":\"<name>\", ...}}";
					return reply;
				}

				std::string name = req["action"]["action"].get<std::string>();
				if (name == "seat" || name == "loginAccount" || name == "selectContext" || name == "connectToZone"
						|| name == "zoneInCharacter" || name == "createCharacter" || name == "logoutCharacter") {
					reply["ok"] = false;
					reply["error"] = "login-phase action '" + name + "' is not allowed on the seat channel";
					return reply;
				}

				ActionBase* action = ActionManager::fromJSON(name.c_str(), req["action"]);
				if (action == nullptr) {
					reply["ok"] = false;
					reply["error"] = "unknown action '" + name + "'";
					return reply;
				}

				info(true) << "running " << name.c_str();
				action->run(core);
				reply["ok"] = action->isOK();
				reply["result"] = action->toJSON();
				delete action;
			} else if (op == "vars") {
				// the zone thread writes the store while we read it: hold the handler's lock
				Locker lock(core.zone->getZoneClient()->getZonePacketHandler());
				reply["ok"] = true;
				if (req.contains("path")) {
					std::string path = req["path"].get<std::string>();
					try {
						reply["vars"] = core.vars.at(JSONSerializationType::json_pointer(path));
					} catch (...) {
						reply["vars"] = nullptr;
					}
				} else {
					reply["vars"] = core.vars;
				}
			} else if (op == "objects") {
				reply["ok"] = true;
				reply["objects"] = listObjects(core);
			} else if (op == "wait") {
				std::string signal = req.value("signal", std::string(""));
				int timeoutMs = req.value("timeoutMs", 5000);
				if (signal.empty()) {
					reply["ok"] = false;
					reply["error"] = "wait needs a signal name";
					return reply;
				}
				// the only request served outside handleLock (the caller decides by op)
				bool fired = core.zone->waitFor(String(signal.c_str()).hashCode(), timeoutMs);
				reply["ok"] = true;
				reply["fired"] = fired;
			} else if (op == "quit") {
				reply["ok"] = true;
				quit = true;
			} else {
				reply["ok"] = false;
				reply["error"] = "unknown op '" + op + "' (ping, action, vars, objects, wait, quit)";
			}
		} catch (const Exception& e) {
			reply["ok"] = false;
			reply["error"] = std::string("exception: ") + e.getMessage().toCharArray();
		} catch (const std::exception& e) {
			reply["ok"] = false;
			reply["error"] = std::string("exception: ") + e.what();
		}

		return reply;
	}

	// Serve one driver connection. Returns true when the seat should end (quit, timeout, zone lost).
	bool serve(ClientCore& core, int fd) {
		std::string buffer;
		char chunk[4096];

		while (true) {
			struct pollfd pfd;
			pfd.fd = fd;
			pfd.events = POLLIN;
			pfd.revents = 0;

			int r = ::poll(&pfd, 1, 1000);
			if (r < 0) {
				if (errno == EINTR) continue;
				return false;
			}

			if (stopping)
				return true;
			if (!core.zone->isConnected()) {
				fail("zone connection lost", 7);
				return true;
			}
			if (timedOut()) {
				return true;
			}
			if (r == 0)
				continue;

			ssize_t n = ::read(fd, chunk, sizeof(chunk));
			if (n <= 0)
				return false;   // the driver went away; wait for the next one

			buffer.append(chunk, n);

			size_t nl;
			while ((nl = buffer.find('\n')) != std::string::npos) {
				std::string line = buffer.substr(0, nl);
				buffer.erase(0, nl + 1);
				if (line.empty())
					continue;

				bool quit = false;
				JSONSerializationType reply;
				try {
					JSONSerializationType req = JSONSerializationType::parse(line);
					if (req.value("op", std::string("")) == "wait") {
						reply = handle(core, req, quit);
					} else {
						std::lock_guard<std::mutex> guard(handleLock);
						reply = handle(core, req, quit);
					}
				} catch (const std::exception& e) {
					reply = JSONSerializationType::object();
					reply["ok"] = false;
					reply["error"] = std::string("bad request: ") + e.what();
				}

				requests++;
				if (!writeAll(fd, reply.dump() + "\n"))
					return false;
				if (quit) {
					info(true) << "quit requested after " << requests.load() << " request(s)";
					return true;
				}
			}
		}
	}

	void run(ClientCore& core) override {
		// a driver that drops the channel mid-request (a stopped pilot) must not take the seat down: without this the
		// write of the pending reply to the closed socket raises SIGPIPE and the client dies with its character
		::signal(SIGPIPE, SIG_IGN);
		if (core.zone == nullptr || !core.zone->isConnected() || !core.zone->isSceneReady()) {
			result.setError("Not in the zone (seat needs a zoned-in character)", 1);
			return;
		}
		if (socketPath.isEmpty()) {
			result.setError("--seat needs a socket path", 2);
			return;
		}

		int listenFd = ::socket(AF_UNIX, SOCK_STREAM, 0);
		if (listenFd < 0) {
			result.setError(String("socket(): ") + strerror(errno), 3);
			return;
		}

		::unlink(socketPath.toCharArray());

		struct sockaddr_un addr;
		memset(&addr, 0, sizeof(addr));
		addr.sun_family = AF_UNIX;
		strncpy(addr.sun_path, socketPath.toCharArray(), sizeof(addr.sun_path) - 1);

		if (::bind(listenFd, (struct sockaddr*) &addr, sizeof(addr)) < 0) {
			result.setError(String("bind(") + socketPath + "): " + strerror(errno), 4);
			::close(listenFd);
			return;
		}
		::chmod(socketPath.toCharArray(), 0600);

		if (::listen(listenFd, 4) < 0) {
			result.setError(String("listen(): ") + strerror(errno), 5);
			::close(listenFd);
			::unlink(socketPath.toCharArray());
			return;
		}

		started.updateToCurrentTime();
		info(true) << "seat listening on " << socketPath << (timeoutSeconds > 0 ? " for " + String::valueOf(timeoutSeconds) + "s" : String(" until quit"));

		while (!stopping) {
			struct pollfd pfd;
			pfd.fd = listenFd;
			pfd.events = POLLIN;
			pfd.revents = 0;

			int r = ::poll(&pfd, 1, 1000);
			if (r < 0 && errno != EINTR) {
				fail(String("poll(): ") + strerror(errno), 6);
				break;
			}
			if (!core.zone->isConnected()) {
				fail("zone connection lost", 7);
				break;
			}
			if (timedOut()) {
				info(true) << "seat timeout after " << timeoutSeconds << "s";
				break;
			}
			if (r <= 0)
				continue;

			int fd = ::accept(listenFd, nullptr, nullptr);
			if (fd < 0)
				continue;

			std::lock_guard<std::mutex> guard(driversLock);
			driverFds.insert(fd);
			info(true) << "driver connected (" << (int) driverFds.size() << " now)";
			driverThreads.emplace_back([this, &core, fd]() {
				bool done = serve(core, fd);
				::close(fd);
				{
					std::lock_guard<std::mutex> guard(driversLock);
					driverFds.erase(fd);
					info(true) << "driver disconnected (" << (int) driverFds.size() << " left)";
				}
				if (done)
					stopping = true;
			});
		}

		stopping = true;
		::close(listenFd);
		::unlink(socketPath.toCharArray());

		// wake the drivers still blocked in read/poll so their threads end, then join them
		{
			std::lock_guard<std::mutex> guard(driversLock);
			for (int fd : driverFds)
				::shutdown(fd, SHUT_RDWR);
		}
		for (std::thread& t : driverThreads)
			t.join();

		if (!failed)
			result.setSuccess();
	}

	bool isOK() const override { return !skipped && result.isOK(); }
	String getError() const override { return result.getError(); }
	uint16 getErrorCode() const override { return result.getErrorCode(); }
	void setSkipped() override { skipped = true; }

	JSONSerializationType toJSON() const override {
		JSONSerializationType json;
		json["action"] = getName();
		json["socket"] = socketPath.toCharArray();
		json["timeout"] = timeoutSeconds;
		json["requests"] = requests.load();
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
		return "--seat <socket path> [--seat-timeout <sec>]  Stay logged in and serve a JSON-lines control channel on that unix socket (tools/seat drives it)";
	}

	static ActionBase* factory() { return new SeatAction(); }
};

static bool _registered_seat =
	(ActionManager::registerAction("seat", SeatAction::factory, SeatAction::fromArgs, SeatAction::fromJSON), true);
