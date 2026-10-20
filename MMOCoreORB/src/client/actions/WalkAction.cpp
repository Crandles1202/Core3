/*
 * WalkAction.cpp — walk a route with real movement packets (Phase 7.1, Final Boss)
 *
 * The seat gets a route from the server's pathfinder (FbLabTests:pathTo → findPath) and walks it the
 * way the real client moves a character: a DataTransform (ObjController 0x71) every `interval` ms
 * along the polyline at `speed` m/s, heading turned toward the next point, then a final packet with
 * speed 0. Nothing is teleported; the server validates every step as it would for a human.
 *
 *   --walk-points "x,z,y;x,z,y;…" [--walk-speed <m/s>] [--walk-interval <ms>]
 *   JSON: {"action":"walk","points":[[x,z,y],…],"speed":4.5,"interval":450}
 *
 * Server rules this obeys (packets/object/DataTransform.h, transform/Transform.h, PlayerManager):
 *   - at least MIN_DELTA 200 ms between packets, and under MID_DELTA 400 ms a packet must be an
 *     "inertia" change (speed or yaw) or it is dropped — so the default interval is 450 ms;
 *   - average speed since the last fully validated position (checked once a second) must stay under
 *     run speed × 1.05 (player run speed 5.376 m/s) — default 4.5 m/s;
 *   - the posture must allow movement (stand first), and no DataTransform is accepted while the
 *     server waits for a TeleportAck after a teleport — ZonePacketHandler acks those automatically.
 * Each packet also moves our own SceneObject in the client's map so `objects` stays truthful.
 */

#include "client/ActionBase.h"
#include "client/ActionResult.h"
#include "client/ActionManager.h"
#include "client/ClientCore.h"
#include "client/zone/Zone.h"
#include "client/zone/ZoneClient.h"
#include "client/zone/objects/scene/SceneObject.h"
#include "engine/service/proto/BaseMessage.h"

#include <math.h>

// ObjController 0x71 as the client sends it (parsed by Transform::parseDataTransform):
// int timeStamp, int moveCount, direction x y z w, position x z y, float speed
class ClientDataTransform : public BaseMessage {
public:
	ClientDataTransform(uint64 playerOid, uint32 timeStamp, uint32 moveCount, float yawRadians, float x, float z, float y, float speed) {
		insertShort(0x05);
		insertInt(0x80CE5E46);   // ObjControllerMessage
		insertInt(0x1B);         // priority
		insertInt(0x71);         // DataTransform
		insertLong(playerOid);   // ObjectControllerMessageCallback::parse reads priority, type, oid — then the payload at once
		insertInt(timeStamp);
		insertInt(moveCount);
		insertFloat(0.f);                       // direction: yaw about y
		insertFloat(sinf(yawRadians / 2.f));
		insertFloat(0.f);
		insertFloat(cosf(yawRadians / 2.f));
		insertFloat(x);
		insertFloat(z);
		insertFloat(y);
		insertFloat(speed);
	}
};

// one movement clock per client run: the server wants monotonic client stamps across every walk
uint32 walkClockMs() {
	static Time start;
	static bool started = false;
	if (!started) {
		start.updateToCurrentTime();
		started = true;
	}
	return (uint32) start.miliDifference() + 1;
}

uint32 nextMoveCount() {
	static AtomicInteger counter(1);
	return counter.increment();
}

class WalkAction : public ActionBase {
	Vector<Vector3> points;   // x, z, y as the server orders them (Vector3 = x, y, z here: we keep x, z, y in that order)
	float speed;
	int intervalMs;

	ActionResult result;
	bool skipped;
	int packets;
	float walked;

public:
	WalkAction() : speed(4.5f), intervalMs(450), skipped(false), packets(0), walked(0.f) {
		setLogLevel(Logger::INFO);
		setLoggingName("Walk");
	}

	const char* getName() const override { return "walk"; }
	bool needsZone() const override { return true; }
	bool needsTarget() const override { return true; }
	bool needsCharacter() const override { return true; }

	static bool parsePoints(const String& spec, Vector<Vector3>& out) {
		StringTokenizer pts(spec);
		pts.setDelimeter(";");
		while (pts.hasMoreTokens()) {
			String pt;
			pts.getStringToken(pt);
			StringTokenizer nums(pt);
			nums.setDelimeter(",");
			float v[3];
			for (int i = 0; i < 3; ++i) {
				if (!nums.hasMoreTokens()) return false;
				v[i] = nums.getFloatToken();
			}
			out.add(Vector3(v[0], v[1], v[2]));
		}
		return out.size() > 0;
	}

	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		WalkAction* me = nullptr;
		int i = startIndex;

		while (i < args.size()) {
			int lastConsumed = consumed;
			if (args.get(i) == "--walk-points" && i + 1 < args.size()) {
				if (me != nullptr) break;
				me = new WalkAction();
				parsePoints(args.get(i + 1), me->points);
				consumed += 2; i += 2;
			} else if (me != nullptr && args.get(i) == "--walk-speed" && i + 1 < args.size()) {
				me->speed = Float::valueOf(args.get(i + 1));
				consumed += 2; i += 2;
			} else if (me != nullptr && args.get(i) == "--walk-interval" && i + 1 < args.size()) {
				me->intervalMs = Integer::valueOf(args.get(i + 1));
				consumed += 2; i += 2;
			}
			if (consumed == lastConsumed) break;
		}

		if (me != nullptr) result.add(me);
		return result;
	}

	static ActionBase* fromJSON(const JSONSerializationType& config) {
		WalkAction* me = new WalkAction();
		if (config.contains("points") && config["points"].is_array()) {
			for (const auto& pt : config["points"]) {
				if (pt.is_array() && pt.size() >= 3)
					me->points.add(Vector3(pt[0].get<float>(), pt[1].get<float>(), pt[2].get<float>()));
			}
		} else if (config.contains("points") && config["points"].is_string()) {
			parsePoints(String(config["points"].get<std::string>().c_str()), me->points);
		}
		if (config.contains("speed")) me->speed = config["speed"].get<float>();
		if (config.contains("interval")) me->intervalMs = config["interval"].get<int>();
		return me;
	}

	// a Vector3 here holds (x, z, y); planar distance uses x and y
	static float planar(const Vector3& a, const Vector3& b) {
		float dx = b.getX() - a.getX(), dy = b.getZ() - a.getZ();
		return sqrtf(dx * dx + dy * dy);
	}

	void sendStep(ClientCore& core, const Vector3& p, float yaw, float stepSpeed) {
		core.zone->getZoneClient()->sendMessage(new ClientDataTransform(core.selectedCharacterOid, walkClockMs(), nextMoveCount(), yaw, p.getX(), p.getY(), p.getZ(), stepSpeed));
		packets++;

		SceneObject* self = core.zone->getObject(core.selectedCharacterOid);
		if (self != nullptr) {
			Locker lock(self);
			self->setPosition(p.getX(), p.getY(), p.getZ());
		}
	}

	void run(ClientCore& core) override {
		if (core.zone == nullptr || !core.zone->isConnected() || !core.zone->isSceneReady()) {
			result.setError("Not in the zone (walk needs a zoned-in character)", 1);
			return;
		}
		if (points.size() < 1) {
			result.setError("walk needs at least one point (x,z,y)", 2);
			return;
		}
		if (speed <= 0.f || speed > 5.6f) {
			result.setError("walk speed must be in (0, 5.6] m/s (player run speed 5.376 × 1.05)", 2);
			return;
		}
		if (intervalMs < 400) {
			result.setError("walk interval must be >= 400 ms (the server drops faster non-inertia updates)", 2);
			return;
		}

		float stepLength = speed * intervalMs / 1000.f;
		Vector3 current = points.get(0);
		float yaw = 0.f;

		info() << "walking " << points.size() << " point(s) at " << speed << " m/s, " << stepLength << " m every " << intervalMs << " ms";

		for (int i = 1; i < points.size(); ++i) {
			const Vector3& target = points.get(i);
			float length = planar(current, target);
			if (length < 0.01f)
				continue;

			yaw = atan2f(target.getX() - current.getX(), target.getZ() - current.getZ());

			while (length > stepLength) {
				float t = stepLength / length;
				Vector3 next(current.getX() + (target.getX() - current.getX()) * t,
				             current.getY() + (target.getY() - current.getY()) * t,
				             current.getZ() + (target.getZ() - current.getZ()) * t);
				sendStep(core, next, yaw, speed);
				walked += planar(current, next);
				current = next;
				length = planar(current, target);
				Thread::sleep(intervalMs);

				if (!core.zone->isConnected()) {
					result.setError("zone connection lost while walking", 3);
					return;
				}
			}

			// the leg's end point itself
			walked += planar(current, target);
			current = target;
			sendStep(core, current, yaw, speed);
			Thread::sleep(intervalMs);
		}

		// come to a stop where we are
		sendStep(core, current, yaw, 0.f);
		Thread::sleep(intervalMs);

		info() << "walked " << walked << " m in " << packets << " packet(s), now at " << current.getX() << ", " << current.getZ();
		result.setSuccess();
	}

	bool isOK() const override { return !skipped && result.isOK(); }
	String getError() const override { return result.getError(); }
	uint16 getErrorCode() const override { return result.getErrorCode(); }
	void setSkipped() override { skipped = true; }

	JSONSerializationType toJSON() const override {
		JSONSerializationType json;
		json["action"] = getName();
		json["pointCount"] = points.size();
		json["speed"] = speed;
		json["interval"] = intervalMs;
		json["packets"] = packets;
		json["walked"] = walked;
		if (points.size() > 0) {
			const Vector3& last = points.get(points.size() - 1);
			json["endX"] = last.getX();
			json["endY"] = last.getZ();
		}
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
		return "--walk-points \"x,z,y;x,z,y;…\" [--walk-speed <m/s>] [--walk-interval <ms>]  Walk a route with real movement packets (route from FbLabTests:pathTo)";
	}

	static ActionBase* factory() { return new WalkAction(); }
};

static bool _registered_walk =
	(ActionManager::registerAction("walk", WalkAction::factory, WalkAction::fromArgs, WalkAction::fromJSON), true);
