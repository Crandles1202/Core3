#!/usr/bin/env python3
"""
tools/citizens/pilot.py — the pilot of a citizen (Phase 7.3, Final Boss).

A pilot sits on a seat (tools/seat: a core3client kept logged in) and decides at goal level what the
character does next. Everything frame-level is the seat's job; the pilot is woken by events (a /tell,
someone speaking nearby, a system message, a timer) and answers with a few tool calls.

  pilot.py run <citizen> [--seat NAME] [--model ID] [--effort low|medium|high] [--idle SECONDS]
                         [--ticks N] [--dry]
  pilot.py show <citizen>            the persona, plan and memory the pilot would load

Per-citizen files:
  tools/citizens/cast/<citizen>.md        the persona (in the repo; drafted from docs/Citizens-Cast.md)
  ~/.swg-lab/citizens/<citizen>/plan.md   the committed life plan: milestones in order, one "- [ ]" per line,
                                          and a "## Changes" log — the pilot may change the plan only with a reason
  ~/.swg-lab/citizens/<citizen>/memory.md what the citizen remembers (append-only notes; read back every wake)
  ~/.swg-lab/citizens/<citizen>/state.json seat name, counters of chat already seen, last wake
  ~/.swg-lab/citizens/<citizen>/log.jsonl  every decision with the model's usage, for the cost dial

Runtime: the Anthropic Python SDK with an API key from the environment (ANTHROPIC_API_KEY — Chuck's Max
plan credits through a Console workspace; read from ~/.env when the environment lacks it). The SDK lives in
the venv ~/.swg-lab/venv (python3 -m venv ~/.swg-lab/venv && ~/.swg-lab/venv/bin/pip install anthropic);
the pilot re-executes itself there when the system python has no `anthropic`. --dry runs a scripted decider
instead (no model, no key) so the loop, the seat and the files can be exercised in the lab.
"""
import argparse
import importlib.machinery
import importlib.util
import json
import os
import re
import sys
import time
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
LABDIR = os.environ.get("SWG_LABDIR", os.path.expanduser("~/.swg-lab"))
CAST_DIR = os.path.join(HERE, "cast")

VENV_PYTHON = os.path.join(LABDIR, "venv", "bin", "python")
ENV_FILE = os.path.expanduser("~/.env")

# survey tool codes (SurveyTool.idl): what resources_here means by a class word
RESOURCE_TOOLS = {"solar": 1, "chemical": 2, "flora": 3, "gas": 4, "geothermal": 5, "mineral": 6, "water": 7, "wind": 8, "fusion": 9}
TOOL_NAMES = {v: k for k, v in RESOURCE_TOOLS.items()}
# CommandQueueRemove error=1 state=N names the locomotion that refused the command
MAX_WALK_M = 2000
LOCOMOTION_REFUSALS = {20: "you are dead: clone first", 19: "you are incapacitated: wait", 14: "you are sitting: stand up first",
                       13: "you are kneeling", 21: "you are blocked"}
DEFAULT_MODEL = "claude-haiku-5-5"   # Chuck 2026-10-20: cheapest by default; a persona may set "model:" in its ## Character section
DEFAULT_EFFORT = "low"        # a game character's next move is a chat-sized decision
MAX_ROUNDS_PER_WAKE = 6       # tool rounds the model may take before the wake ends
MAX_TOKENS = 2048


def ensure_runtime(dry):
    """A model run needs the SDK (from the lab venv) and the key (from the environment or ~/.env)."""
    if dry:
        return
    if "ANTHROPIC_API_KEY" not in os.environ and os.path.exists(ENV_FILE):
        with open(ENV_FILE) as f:
            for line in f:
                line = line.strip()
                if line.startswith("export "):
                    line = line[7:]
                if line.startswith("ANTHROPIC_API_KEY=") :
                    os.environ["ANTHROPIC_API_KEY"] = line.split("=", 1)[1].strip().strip('"').strip("'")
    if "ANTHROPIC_API_KEY" not in os.environ:
        sys.exit("pilot: no ANTHROPIC_API_KEY in the environment or ~/.env (Chuck's Console key); use --dry for the scripted decider")
    try:
        import anthropic  # noqa: F401
    except ImportError:
        # (compare prefixes, not executables: the venv's python is a symlink to the system one)
        in_venv = os.path.abspath(sys.prefix) == os.path.abspath(os.path.dirname(os.path.dirname(VENV_PYTHON)))
        if os.path.exists(VENV_PYTHON) and not in_venv:
            os.execv(VENV_PYTHON, [VENV_PYTHON] + sys.argv)
        sys.exit(f"pilot: the anthropic SDK is not installed (python3 -m venv {os.path.dirname(os.path.dirname(VENV_PYTHON))} && {os.path.dirname(VENV_PYTHON)}/pip install anthropic)")


def load_seat_module():
    # tools/seat has no .py suffix, so name the loader explicitly
    loader = importlib.machinery.SourceFileLoader("seat", os.path.join(TOOLS, "seat"))
    spec = importlib.util.spec_from_loader("seat", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")


# ------------------------------------------------------------------ the citizen's files
class CitizenFiles:
    def __init__(self, name, home=None):
        self.name = name
        self.persona_path = os.path.join(CAST_DIR, f"{name}.md")
        # the live state lives in ~/.swg-lab/citizens/<name>; a scenario passes its own --home so a test wake as a
        # persona never touches (or deletes) the real citizen's memory and plan
        self.dir = home or os.path.join(LABDIR, "citizens", name)
        os.makedirs(self.dir, exist_ok=True)
        self.plan_path = os.path.join(self.dir, "plan.md")
        self.memory_path = os.path.join(self.dir, "memory.md")
        self.state_path = os.path.join(self.dir, "state.json")
        self.log_path = os.path.join(self.dir, "log.jsonl")

    def character_field(self, key):
        """A key: value line of the persona's '## Character' section (model, account, …), or None."""
        if not os.path.exists(self.persona_path):
            return None
        m = re.search(r"^## Character\s*\n(.*?)(?=^## |\Z)", open(self.persona_path).read(), re.S | re.M)
        if not m:
            return None
        for line in m.group(1).splitlines():
            line = line.strip().lstrip("-* ")
            if line.lower().startswith(key.lower() + ":"):
                return line.split(":", 1)[1].strip() or None
        return None

    def persona(self):
        if not os.path.exists(self.persona_path):
            sys.exit(f"pilot: no persona at {self.persona_path} (draft it from docs/Citizens-Cast.md)")
        text = open(self.persona_path).read()
        # the "## Character" section (account, race, skill boxes) is for tools/citizens/citizen, not for the model
        return re.sub(r"^## Character\s*\n.*?(?=^## |\Z)", "", text, flags=re.S | re.M).rstrip() + "\n"

    def plan(self):
        if not os.path.exists(self.plan_path):
            # seed the plan from the persona's "## Life plan" section, once
            text = self.persona()
            m = re.search(r"^## Life plan\s*\n(.*?)(?=^## |\Z)", text, re.S | re.M)
            body = m.group(1).strip() if m else "- [ ] (no plan written yet)"
            lines = []
            for line in body.splitlines():
                line = line.strip()
                if not line:
                    continue
                if not line.startswith("- ["):
                    line = "- [ ] " + line.lstrip("-* ").strip()
                lines.append(line)
            with open(self.plan_path, "w") as f:
                f.write("# Life plan\n\n" + "\n".join(lines) + "\n\n## Changes\n")
        return open(self.plan_path).read()

    def memory(self):
        if not os.path.exists(self.memory_path):
            open(self.memory_path, "w").write("# Memory\n")
        return open(self.memory_path).read()

    def remember(self, note):
        with open(self.memory_path, "a") as f:
            f.write(f"- {now_iso()} {note.strip()}\n")

    def change_plan(self, reason, new_milestones):
        plan = self.plan()
        head, _, changes = plan.partition("## Changes")
        lines = ["- [ ] " + m.strip().lstrip("-* ").replace("[ ] ", "").replace("[x] ", "") for m in new_milestones if m.strip()]
        with open(self.plan_path, "w") as f:
            f.write("# Life plan\n\n" + "\n".join(lines) + "\n\n## Changes" + changes.rstrip("\n") + f"\n- {now_iso()} {reason.strip()}\n")

    def complete_milestone(self, text):
        plan = self.plan()
        new = plan.replace(f"- [ ] {text}", f"- [x] {text}", 1)
        if new == plan:
            return False
        open(self.plan_path, "w").write(new)
        return True

    def state(self):
        try:
            return json.load(open(self.state_path))
        except (OSError, ValueError):
            return {}

    def save_state(self, state):
        json.dump(state, open(self.state_path, "w"), indent=1)

    def log(self, entry):
        entry["at"] = now_iso()
        with open(self.log_path, "a") as f:
            f.write(json.dumps(entry) + "\n")


# ------------------------------------------------------------------ what the seat lets the pilot do
class Senses:
    """Perception from the seat, as deltas since the last wake."""

    def __init__(self, seat, state, character_name="", files=None):
        self.seat = seat
        self.state = state
        self.character_name = character_name
        self.files = files

    def current_milestone(self):
        """the first unticked milestone of the life plan: what the character is working on"""
        if self.files is None:
            return None
        for line in self.files.plan().splitlines():
            if line.startswith("- [ ]"):
                return line[5:].strip()
        return None

    def progress(self):
        """XP by type as 'amount/cap' (lab progress oracle); {} when the oracle is missing or the lab is unreachable"""
        try:
            line = next((l for l in load_seat_module().lab(f"progress:{self.character_name}", 8).splitlines()
                         if l.startswith("INFO progress")), "")
        except Exception:
            return {}
        xp = {}
        for part in line.split(" xp=", 1)[1].split(",") if " xp=" in line else []:
            if "=" in part:
                k, v = part.split("=", 1)
                xp[k] = v
        return xp

    def _new_lines(self, path, key):
        reply = self.seat.request({"op": "vars", "path": path})
        lines = reply.get("vars") or []
        seen = self.state.get(key, 0)
        # the seat keeps a bounded tail: if it rotated, take everything we have not reported
        total = self.state.get(key + "_total", 0)
        fresh = lines[seen:] if seen <= len(lines) else lines
        self.state[key] = len(lines)
        self.state[key + "_total"] = total + len(fresh)
        return fresh

    def where_fields(self):
        """the server's INFO where line: zone, world x/y, cell, posture, dead/incap (the client sees cell-local
        coordinates indoors and decodes no creature deltas, so this is the truth about position and condition)"""
        seat_mod = load_seat_module()
        line = next((l for l in seat_mod.lab(f"where:{self.character_name}", 8).splitlines() if l.startswith("INFO where")), "")
        return seat_mod.lab_fields(line)

    @staticmethod
    def condition_of(f):
        if f.get("dead") == "true":
            return "dead (clone first)"
        if f.get("incap") == "true":
            return "incapacitated"
        if f.get("swimming") == "true":
            return "swimming in open water: nothing can be surveyed, sampled or placed here; walk back to land first"
        return "fine"

    def gather(self):
        ping = self.seat.request({"op": "ping"})
        chat = self._new_lines("/SpatialChat", "chat_seen")
        tells = self._new_lines("/Tells", "tells_seen")
        system = self._new_lines("/SystemMessages", "system_seen")
        objects = self.seat.request({"op": "objects"}).get("objects", [])
        me = next((o for o in objects if o["oid"] == ping.get("character")), None)
        planet = self.seat.request({"op": "vars", "path": "/Scene/terrain"}).get("vars")
        near = []
        if me:
            # the client names a creature by its appearance template (a rill reads "dune_lizard"): ask the server
            names = {}
            if isinstance(planet, str):
                seat_mod = load_seat_module()
                for line in seat_mod.lab(f"objectsNear:{planet}:{me['x']:.0f}:{me['y']:.0f}:60:1024", 20).splitlines():
                    if line.startswith("INFO object "):
                        f = seat_mod.lab_fields(line)
                        names[int(f.get("oid") or 0)] = (f.get("name") or "").replace("_", " ")
            for o in objects:
                if o["oid"] == me["oid"] or o["type"] not in (0x400, 0x401, 0x402, 0x409):
                    continue
                d = ((o["x"] - me["x"]) ** 2 + (o["y"] - me["y"]) ** 2) ** 0.5
                if d < 40:
                    near.append({"oid": o["oid"], "name": names.get(o["oid"], o["name"]), "player": o["type"] == 0x409, "distance": round(d, 1)})
            near.sort(key=lambda n: n["distance"])
        w = self.where_fields()
        threats, strength = [], None
        if me and isinstance(planet, str):
            t = threats_of(self.character_name, 150)
            strength = t.get("strength")
            threats = [{k: v for k, v in r.items() if k in ("name", "level", "pack", "distance", "aggressive")} for r in t.get("threats", [])[:6]]
        training = None
        if me:
            tr = trainable_of(self.character_name)
            if tr.get("ok"):
                training = {"ready": [f"{r['skill']} ({r['credits']} cr)" for r in tr["ready"]][:6],
                            "next": [f"{r['skill']} needs {r['xp_type']} {r['xp']}" for r in tr["next"]][:4]}
        position = {"x": round(me["x"], 1), "y": round(me["y"], 1)} if me else None
        if w.get("x") is not None:
            position = {"x": round(float(w["x"]), 1), "y": round(float(w["y"]), 1)}
            if (w.get("cell") or "0") != "0":
                position["indoors"] = "inside a building; walk_to a spot outside leaves it through the door"
        return {
            "xp": self.progress(),
            "you": self.character_name,
            "condition": self.condition_of(w),
            "now": self.current_milestone(),
            "character": ping.get("character"),
            "planet": planet if isinstance(planet, str) else None,
            "position": position,
            "heard": chat[-12:],
            "tells": tells[-12:],
            "system": [s for s in system if not s.startswith("@") or "combat" in s][-8:],
            "nearby": near[:12],
            "fighting_strength": strength,
            "threats": threats,
            "training": training,
        }


def threats_of(character_name, radius=150):
    """what would attack the character within radius (lab threats: aggressive AI agents, wild creatures above its
    strength) and its fighting strength: the level its best weapon line earns (the stored level goes stale)"""
    seat_mod = load_seat_module()
    out = seat_mod.lab(f"threats:{character_name}:{int(radius)}", 15)
    me = next((seat_mod.lab_fields(l) for l in out.splitlines() if l.startswith("INFO me ")), {})
    rows = []
    for line in out.splitlines():
        if line.startswith("INFO threat "):
            f = seat_mod.lab_fields(line)
            rows.append({"oid": int(f.get("oid") or 0), "name": (f.get("name") or "").replace("_", " "), "level": int(f.get("level") or 0),
                         "distance": int(float(f.get("distance") or 0)), "aggressive": f.get("aggressive") == "true",
                         "x": float(f.get("x") or 0), "y": float(f.get("y") or 0)})
    for r in rows:   # a pack: the same kind within 25 m of it (five sevorrts are a different matter from one)
        r["pack"] = sum(1 for o in rows if o["name"] == r["name"] and ((o["x"] - r["x"]) ** 2 + (o["y"] - r["y"]) ** 2) ** 0.5 <= 25)
    rows.sort(key=lambda r: r["distance"])
    return {"ok": bool(me), "strength": int(me.get("strength") or 0) if me else None, "threats": rows}


def trainable_of(character_name, scope=""):
    """lab trainable: the skill boxes the character can buy at a trainer right now (ready: prerequisites, experience,
    skill points) and the ones it is working toward (next: prerequisites met, experience short), with the trainer
    type, the experience have/cost, credits and points; plus its credits, stored level and fighting strength"""
    seat_mod = load_seat_module()
    out = seat_mod.lab(f"trainable:{character_name}" + (f":{scope}" if scope else ""), 20)
    ready, nxt, summary = [], [], {}
    for line in out.splitlines():
        if line.startswith("INFO trainable ") or line.startswith("INFO next "):
            f = seat_mod.lab_fields(line)
            row = {"skill": f.get("skill"), "trainer": f.get("trainer"), "xp_type": f.get("xpType"),
                   "xp": f"{f.get('xpHave')}/{f.get('xpCost')}", "credits": int(f.get("credits") or 0), "points": int(f.get("points") or 0)}
            (ready if line.startswith("INFO trainable ") else nxt).append(row)
        elif line.startswith("INFO training "):
            summary = seat_mod.lab_fields(line)
    def fraction(r):
        have, cost = r["xp"].split("/")
        return float(have) / max(1.0, float(cost))
    nxt.sort(key=fraction, reverse=True)
    return {"ok": bool(summary), "ready": ready, "next": nxt, "level": int(summary.get("level") or 0),
            "strength": int(summary.get("strength") or 0), "cash": int(summary.get("cash") or 0), "bank": int(summary.get("bank") or 0)}


def seat_tools(seat, files, character_name, seat_name):
    """The pilot's tools: thin wrappers over seat primitives and the citizen's files."""

    def say(text):
        return seat.action("say", text=text)

    def tell(name, text):
        return seat.action("tell", name=name, text=text)

    def emote(name, target=0):
        seat_mod = load_seat_module()
        eid = seat_mod.EMOTES.get(name)
        if eid is None:
            return {"ok": False, "error": f"unknown emote '{name}'"}
        fields = {"id": eid}
        if target:
            fields["target"] = int(target)
        return seat.action("emote", **fields)

    def walk_to(x, y):
        seat_mod = load_seat_module()
        here = seat_mod.where(character_name)
        if here:
            dist = ((float(x) - here["x"]) ** 2 + (float(y) - here["y"]) ** 2) ** 0.5
            if dist > MAX_WALK_M:
                return {"ok": False, "error": f"{dist:.0f} m is too far to walk alone through the wild (both of you who tried died on the way); "
                        f"use travel_to for a shuttle to the nearest city, or pick a spot within {MAX_WALK_M} m"}
        r = seat_mod.walk_seat(seat, character_name, float(x), float(y))
        cond = _condition()
        if cond and cond != "fine":
            r = dict(r); r["ok"] = False; r["condition"] = cond; r["error"] = f"the walk ended with you {cond}"
        return r

    def travel_to(planet, point):
        seat_mod = load_seat_module()
        reply = seat_mod.travel_seat(seat, seat_name, planet, point)
        if reply.get("ok"):
            arrived = reply.get("arrived") or {}
            return {"ok": True, "planet": arrived.get("zone", planet), "x": arrived.get("x"), "y": arrived.get("y"),
                    "departure": reply.get("departure"), "waitedS": reply.get("waitedS")}
        return {"ok": False, "error": reply.get("error"), "step": reply.get("step")}

    def _objects():
        return seat.request({"op": "objects"}).get("objects", [])

    def _name_matches(fragment, name):
        """every word of the fragment appears in the name, case-insensitive: 'harvester_ore' finds
        '@deed:ore_s1_harvester_deed_name', 'survey tool mineral' finds '@item_n:survey_tool_mineral'"""
        words = [w for w in fragment.lower().replace("-", "_").replace(" ", "_").split("_") if w]
        hay = name.lower()
        return all(w in hay for w in words)

    def _find_object(fragment, otype=None):
        for o in _objects():
            if (otype is None or o["type"] == otype) and _name_matches(fragment, o["name"]):
                return o
        return None

    def _names_of(otype):
        return sorted({o["name"] for o in _objects() if o["type"] == otype})

    def _travel_points(planet):
        seat_mod = load_seat_module()
        pts = []
        for line in seat_mod.lab(f"travelPoints:{planet}", 20).splitlines():
            if line.startswith("INFO travelpoint "):
                f = seat_mod.lab_fields(line)
                pts.append({"name": f.get("name"), "x": float(f.get("x")), "y": float(f.get("y")),
                            "interplanetary": f.get("interplanetary") == "1"})
        return pts

    def _nearest_point(pts, x, y):
        best = None
        for p in pts:
            d = ((p["x"] - x) ** 2 + (p["y"] - y) ** 2) ** 0.5
            if best is None or d < best["distance"]:
                best = {"name": p["name"], "distance": round(d)}
        return best

    def spots_near_shuttles(resource):
        """for one resource: the best land spot within 1.5 km of each shuttle point on this planet (a harvester wants a
        good spot near a town, not the planet's single peak)"""
        seat_mod = load_seat_module()
        planet = seat.request({"op": "vars", "path": "/Scene/terrain"}).get("vars")
        if not isinstance(planet, str):
            return {"ok": False, "error": "planet unknown (no scene yet)"}
        rows = []
        for line in seat_mod.lab(f"resourceNear:{planet}:{resource}", 60).splitlines():
            if line.startswith("INFO resourceNear "):
                f = seat_mod.lab_fields(line)
                rows.append({"shuttle": f.get("point"), "x": float(f.get("x")), "y": float(f.get("y")), "density": float(f.get("density")),
                             "walk_from_shuttle_m": float(f.get("distance"))})
        rows.sort(key=lambda r: -r["density"])
        if not rows:
            return {"ok": False, "error": f"'{resource}' is below 10% near every shuttle on {planet} (exact name? see resources_here)"}
        return {"ok": True, "planet": planet, "resource": resource, "spots": rows[:8],
                "how": "travel_to the shuttle, walk_to the spot (under 2 km), survey, place_harvester"}

    def travel_points(planet):
        """the shuttle and starport points of a planet, with positions: where a shuttle can take you"""
        pts = _travel_points(planet)
        if not pts:
            return {"ok": False, "error": f"no travel points on '{planet}' (planet names: tatooine, corellia, naboo, …)"}
        return {"ok": True, "planet": planet, "points": pts}

    def resources_here(resource_class):
        """the resource oracle for the planet the character is on (the citizens' spreadsheet)"""
        seat_mod = load_seat_module()
        planet = seat.request({"op": "vars", "path": "/Scene/terrain"}).get("vars")
        if not isinstance(planet, str):
            return {"ok": False, "error": "planet unknown (no scene yet)"}
        rows = []
        shuttles = _travel_points(planet)
        want = (resource_class or "").strip().lower()
        tool_code = RESOURCE_TOOLS.get(want)
        # a known class word selects by the survey tool that finds it; any other word is a text filter on the oracle
        for line in seat_mod.lab(f"resources:{planet}" + (f":{want}" if want and tool_code is None and want != "all" else ""), 40).splitlines():
            if line.startswith("INFO resource "):
                f = seat_mod.lab_fields(line)
                tool = int(f.get("tool") or 0)
                if tool_code is not None and tool != tool_code:
                    continue
                if tool_code is None and tool < 0 and want != "all":
                    continue   # creature resources (hides, meat, bone) come from hunting, not from a survey tool
                spots = []
                for spot in (f.get("best") or "").split(";"):
                    v = spot.split(",")
                    if len(v) >= 3:
                        sx, sy = float(v[0]), float(v[1])
                        spots.append({"x": sx, "y": sy, "density": float(v[2]), "nearest_shuttle": _nearest_point(shuttles, sx, sy)})
                best = (f.get("best") or "").split(";")[0].split(",")
                attrs = dict(kv.split("=", 1) for kv in (f.get("attrs") or "").split(",") if "=" in kv)
                rows.append({"name": f.get("name"), "class": f.get("class"), "family": f.get("family"),
                             "tool": TOOL_NAMES.get(tool, "none (hunted)"),
                             "best": {"x": float(best[0]), "y": float(best[1]), "density": float(best[2])} if len(best) >= 3 else None,
                             "spots": spots,
                             "attributes": attrs})
        return {"ok": True, "planet": planet, "resources": rows[:40]}

    def survey(resource):
        tool = _find_object("survey_tool_mineral") or _find_object("survey_tool")
        if tool is None:
            return {"ok": False, "error": "no survey tool in the inventory"}
        reply = seat.action("survey", tool=tool["oid"], resource=resource)
        if not reply.get("ok"):
            # the tool wants the exact name: try the fragment against its list, else say what it can find here
            names = [r.get("name") for r in (seat.request({"op": "vars", "path": "/Survey/resources"}).get("vars") or []) if r.get("name")]
            hit = [n for n in names if resource.lower() in n.lower()]
            if len(hit) == 1 and hit[0] != resource:
                reply = seat.action("survey", tool=tool["oid"], resource=hit[0])
            if not reply.get("ok"):
                err = (reply.get("result") or {}).get("error") or reply.get("error")
                return {"ok": False, "error": err, "this_tool_finds_here": names[:30]}
        return reply

    def sample(resource, rounds):
        n = max(1, min(int(rounds), 6))
        return seat.action("sample", resource=resource, rounds=n, timeout=30 * n + 30)

    def place_harvester(deed_fragment, x, y):
        deed = _find_object(deed_fragment, 0x800002) or _find_object(deed_fragment)
        if deed is None:
            return {"ok": False, "error": f"no deed matching '{deed_fragment}' in the inventory", "deeds_carried": _names_of(0x800002)}
        # the server refuses a no-build spot with a bare not_permitted: ask first, and name the nearest spot that works
        seat_mod = load_seat_module()
        planet = seat.request({"op": "vars", "path": "/Scene/terrain"}).get("vars")
        if isinstance(planet, str):
            line = next((l for l in seat_mod.lab(f"canBuildNear:{planet}:{float(x):.0f}:{float(y):.0f}", 20).splitlines() if l.startswith("INFO canBuildNear")), "")
            f = seat_mod.lab_fields(line)
            if f.get("permitted") == "false":
                r = {"ok": False, "error": f"no structure may stand at {float(x):.0f},{float(y):.0f} (a town's no-build belt, water or a protected area)"}
                if f.get("nearestX"):
                    r["nearest_permitted"] = {"x": float(f["nearestX"]), "y": float(f["nearestY"]), "distance": float(f.get("distance") or 0)}
                    r["hint"] = "walk_to that point and place there (the resource hardly changes over such a distance)"
                else:
                    r["hint"] = "nothing within 200 m is buildable; use another spot from spots_near_shuttles"
                return r
        return seat.action("place", deed=deed["oid"], x=float(x), y=float(y), angle=0)

    def harvester(oid, op, resource, amount):
        fields = {"target": int(oid), "op": op}
        if op == "select":
            fields["resource"] = int(resource)
        elif op in ("maintain", "power"):
            fields["amount"] = int(amount)
        elif op == "empty":
            fields["resource"] = int(resource); fields["quantity"] = int(amount)
        if op in ("maintain", "power") and int(amount) <= 0:
            return {"ok": False, "error": f"{op} needs an amount: credits for maintain, energy units for power (hours wanted × the hourly rate from harvester_status; you carry wind energy)"}
        reply = seat.action("harvester", **fields)
        if op == "activate" and reply.get("ok"):
            # the server accepts the switch and leaves it off when the machine has no power or no resource selected
            st = harvester_status(oid)
            if st.get("ok") and str(st.get("active")).lower() in ("false", "0", "none"):
                why = []
                if float(st.get("power") or 0) <= 0: why.append("no power: op power with an amount of energy units first")
                if not (st.get("resource") or st.get("activeResource") or st.get("hopper")): why.append("no resource selected: op resources, then op select")
                return {"ok": False, "error": "did not switch on (" + ("; ".join(why) or "see harvester_status") + ")", "status": st}
        return reply

    def harvester_status(oid):
        seat_mod = load_seat_module()
        out = seat_mod.lab(f"harvester:{int(oid)}", 15)
        head = next((l for l in out.splitlines() if l.startswith("INFO harvester")), None)
        if not head:
            return {"ok": False, "error": "no such structure"}
        status = seat_mod.lab_fields(head)
        status["hopper"] = [seat_mod.lab_fields(l) for l in out.splitlines() if l.startswith("INFO hopper")]
        status["ok"] = True
        return status

    def my_structures():
        seat_mod = load_seat_module()
        out = seat_mod.lab(f"structures:{character_name}", 15)
        rows = [seat_mod.lab_fields(l) for l in out.splitlines() if l.startswith("INFO structure")]
        lots = next((seat_mod.lab_fields(l).get("remaining") for l in out.splitlines() if l.startswith("INFO lots")), None)
        return {"ok": True, "structures": rows, "lotsRemaining": lots}

    def _condition():
        """dead / incapacitated / fine, from the server (the client decodes no creature deltas)"""
        seat_mod = load_seat_module()
        line = next((l for l in seat_mod.lab(f"where:{character_name}", 8).splitlines() if l.startswith("INFO where")), "")
        f = seat_mod.lab_fields(line)
        if f.get("dead") == "true":
            return "dead: you cannot move or act until you clone (tool clone)"
        if f.get("incap") == "true":
            return "incapacitated: wait a minute, you get up on your own"
        if f.get("swimming") == "true":
            return "swimming in open water: walk back to land before surveying, sampling or placing"
        return "fine" if f else None

    def my_health(returning=None):
        seat_mod = load_seat_module()
        line = next((l for l in seat_mod.lab(f"ham:{character_name}", 8).splitlines() if l.startswith("INFO ham")), "")
        f = seat_mod.lab_fields(line)
        return {"ok": bool(f), "condition": _condition(), "health": f.get("health"), "action": f.get("action"), "mind": f.get("mind")}

    def my_inventory():
        """what you carry: names with counts (type 0x800002 deeds, 0x8002 tools, …), from the client's view"""
        counts = {}
        for o in _objects():
            if o["type"] in (0x400, 0x401, 0x402, 0x409) or o.get("parent", 0) == 0:
                continue
            key = o["name"].split(":")[-1].replace("_", " ")
            counts[key] = counts.get(key, 0) + 1
        return {"ok": True, "items": [{"name": k, "count": v} for k, v in sorted(counts.items())][:60]}

    def clone():
        """dead: answer the revive window (closest cloning facility); the server moves you there"""
        reply = seat.action("sui", value="0", match="revive", timeout=10)
        if not reply.get("ok"):
            return {"ok": False, "error": "no revive window open" + ("" if _condition().startswith("dead") else " (you are not dead)"),
                    "detail": (reply.get("result") or {}).get("error")}
        time.sleep(3)
        seat_mod = load_seat_module()
        line = next((l for l in seat_mod.lab(f"where:{character_name}", 8).splitlines() if l.startswith("INFO where")), "")
        f = seat_mod.lab_fields(line)
        return {"ok": True, "cloned": True, "condition": _condition(), "planet": f.get("zone"), "x": f.get("x"), "y": f.get("y")}

    def creatures_near(name_fragment):
        """creatures (not players, not city NPCs) within 80 m, nearest first; the server names them (the bot client
        only knows a creature's appearance template: a rill shows as "dune_lizard"), joined to the view by oid"""
        objs = _objects()
        me = next((o for o in objs if o["oid"] == seat.request({"op": "ping"}).get("character")), None)
        if me is None:
            return {"ok": False, "error": "no self in view"}
        seat_mod = load_seat_module()
        planet = seat.request({"op": "vars", "path": "/Scene/terrain"}).get("vars")
        server = {}
        if isinstance(planet, str):
            for line in seat_mod.lab(f"objectsNear:{planet}:{me['x']:.0f}:{me['y']:.0f}:300:1024", 20).splitlines():
                if not line.startswith("INFO object "):
                    continue
                f = seat_mod.lab_fields(line)
                nm, tpl = f.get("name") or "", f.get("template") or ""
                if "droid" in tpl or "3po" in tpl or "/r2" in tpl or "/r3" in tpl or "/r4" in tpl or "/r5" in tpl or "(" in nm:
                    continue   # droids and named NPCs are not game
                server[int(f.get("oid") or 0)] = (nm.replace("_", " "), float(f.get("x")), float(f.get("y")), int(f.get("level") or 0))
        frag = (name_fragment or "").lower()
        out, seen = [], set()
        for o in objs:
            if o["type"] != 0x400 or o["oid"] not in server:
                continue
            nm, sx, sy, lvl = server[o["oid"]]
            if frag and frag not in nm.lower():
                continue
            d = ((o["x"] - me["x"]) ** 2 + (o["y"] - me["y"]) ** 2) ** 0.5
            if d <= 80:
                seen.add(o["oid"])
                pack = sum(1 for (n2, x2, y2, _l) in server.values() if n2 == nm and ((x2 - sx) ** 2 + (y2 - sy) ** 2) ** 0.5 <= 25)
                out.append({"oid": o["oid"], "name": nm, "level": lvl, "pack": pack, "distance": round(d, 1), "x": round(o["x"], 1), "y": round(o["y"], 1)})
        out.sort(key=lambda c: c["distance"])
        result = {"ok": True, "creatures": out[:12]}
        if not out:
            far = []
            for oid, (nm, x, y, lvl) in server.items():
                if oid in seen or (frag and frag not in nm.lower()):
                    continue
                far.append({"name": nm, "level": lvl, "distance": round(((x - me["x"]) ** 2 + (y - me["y"]) ** 2) ** 0.5), "x": x, "y": y})
            far.sort(key=lambda c: c["distance"])
            result["farther"] = far[:8]
            result["hint"] = ("walk_to one of these, then hunt" if far else
                              "nothing roams within 300 m; creatures appear around a player who keeps moving through open ground outside town: walk a 150 m leg and look again")
        return result

    def threats_near():
        """what would attack you within 150 m, with level and distance, and your own fighting strength"""
        return threats_of(character_name, 150)

    def train(skill):
        """buy a skill box at its trainer, the way a player does: the box must be ready (lab trainable), the nearest
        trainer NPC of its type on this planet is found by its mobile template (lab trainers), the character walks to it
        and talks through the stock conversation (learn → the box → yes); the award is read back server-side"""
        seat_mod = load_seat_module()
        skill = (skill or "").strip()
        t = trainable_of(character_name)
        if not t["ok"]:
            return {"ok": False, "error": "could not read your skills from the server"}
        row = next((r for r in t["ready"] if r["skill"] == skill), None)
        if row is None:
            n = next((r for r in t["next"] if r["skill"] == skill), None)
            if n is not None:
                return {"ok": False, "error": f"{skill} is not yours yet: {n['xp_type']} experience {n['xp']}; it will cost {n['credits']} credits and {n['points']} skill points"}
            return {"ok": False, "error": f"{skill} is not a box you can train now", "ready": [r["skill"] for r in t["ready"]][:8],
                    "next": [f"{r['skill']} ({r['xp_type']} {r['xp']})" for r in t["next"]][:6]}
        if t["cash"] + t["bank"] < row["credits"]:
            return {"ok": False, "error": f"{skill} costs {row['credits']} credits and you have {t['cash'] + t['bank']}"}
        here = seat_mod.where(character_name)
        if not here:
            return {"ok": False, "error": "could not read where you are"}
        trainers = [seat_mod.lab_fields(l) for l in seat_mod.lab(f"trainers:{here['zone']}:{row['trainer']}:{here['x']:.0f}:{here['y']:.0f}", 60).splitlines()
                    if l.startswith("INFO trainer ")]
        if not trainers:
            return {"ok": False, "error": f"no {row['trainer'].replace('trainer_', '')} trainer near any shuttle point on {here['zone']}; travel to another world's big city"}
        tr = trainers[0]
        name = (tr.get("name") or "").replace("_", " ")
        dist = float(tr.get("distance") or 0)
        if dist > MAX_WALK_M:
            return {"ok": False, "error": f"the nearest {row['trainer'].replace('trainer_', '')} trainer, {name}, stands {dist:.0f} m away by {tr.get('point')}: travel_to that point first"}
        cell = int(tr.get("cell") or 0)
        if cell:
            w = seat_mod.walk_seat(seat, character_name, float(tr["localX"]), float(tr["localY"]), cell=cell, within=3)
        else:
            w = seat_mod.walk_seat(seat, character_name, float(tr["x"]), float(tr["y"]), within=3)
        if not w.get("ok"):
            return {"ok": False, "error": f"could not reach {name}: {seat_mod.action_error(w)}"}
        npc = int(tr["oid"])
        # the converse action's own wait is its "timeout" field (seat.action's timeout is the socket's)
        c = seat.request({"op": "action", "action": {"action": "converse", "npc": npc, "options": [0], "timeout": 12}}, timeout=90)
        if not c.get("ok"):
            return {"ok": False, "error": f"{name} would not talk: {seat_mod.action_error(c)}"}
        opts = seat.request({"op": "vars", "path": "/Conversation/options"}).get("vars") or []
        want = f"@skl_n:{skill}"
        if want not in opts:
            offered = [o.split(":", 1)[1] for o in opts if isinstance(o, str) and o.startswith("@skl_n:")]
            return {"ok": False, "error": f"{name} did not offer {skill}", "offered": offered, "said": seat.request({"op": "vars", "path": "/Conversation/message"}).get("vars")}
        c = seat.request({"op": "action", "action": {"action": "converse", "npc": npc, "options": [0, opts.index(want), 0], "timeout": 12}}, timeout=90)
        line = next((l for l in seat_mod.lab(f"hasSkill:{character_name}:{skill}", 8).splitlines() if l.startswith("INFO hasSkill")), "")
        has = "has=true" in line
        after = trainable_of(character_name)
        result = {"ok": has, "skill": skill, "trainer": name, "indoors": bool(cell), "paid": row["credits"] if has else 0,
                  "level": after["level"], "fighting_strength": after["strength"], "ready_now": [r["skill"] for r in after["ready"]][:8]}
        if not has:
            result["error"] = f"{name} did not grant {skill}: " + (seat_mod.action_error(c) if not c.get("ok") else
                              str(seat.request({"op": "vars", "path": "/Conversation/message"}).get("vars")))
        return result

    def _escape(reason):
        """walk away from a fight toward the nearest travel point (a town), at most 300 m in this leg — a character
        that stops attacking and stands still is finished by whatever it was fighting (Teyla, 2026-10-23)"""
        seat_mod = load_seat_module()
        objs = _objects()
        me = next((o for o in objs if o["oid"] == seat.request({"op": "ping"}).get("character")), None)
        planet = seat.request({"op": "vars", "path": "/Scene/terrain"}).get("vars")
        if me is None or not isinstance(planet, str):
            return f"{reason}; could not read where you are"
        best = None
        for p in _travel_points(planet):
            d = ((p["x"] - me["x"]) ** 2 + (p["y"] - me["y"]) ** 2) ** 0.5
            if best is None or d < best[0]:
                best = (d, p)
        if best is None:
            return f"{reason}; no travel point known to run toward"
        d, p = best
        leg = min(d, 300.0)
        tx = me["x"] + (p["x"] - me["x"]) / d * leg if d > 0 else me["x"]
        ty = me["y"] + (p["y"] - me["y"]) / d * leg if d > 0 else me["y"]
        w = seat_mod.walk_seat(seat, character_name, round(tx, 1), round(ty, 1), within=15)
        if not w.get("ok"):
            return f"{reason}; could not walk away: {seat_mod.action_error(w)}"
        return f"{reason}; walked {leg:.0f} m toward {p['name']}"

    def hunt(name_fragment, kills):
        """the fighter's loop: nearest matching creature you can take, walk to 20 m, fight, loot; up to `kills` times.
        Refuses while something that would attack you stands within 120 m, skips prey above your strength (or a pack of
        it), and walks you toward town after a retreat"""
        seat_mod = load_seat_module()
        done, log = 0, []
        strength = 1
        # a scout harvests every corpse it drops: meat, hide or bone into the inventory and scout experience (the cheap
        # boxes a fighter can actually reach: level × 5 + 19 a corpse against 1000 a box)
        mod = seat_mod.lab_fields(next((l for l in seat_mod.lab(f"skillmod:{character_name}:creature_harvesting", 8).splitlines() if l.startswith("INFO skillmod")), ""))
        can_harvest = int(mod.get("creature_harvesting") or 0) >= 1
        harvested = 0
        for _ in range(max(1, min(int(kills), 5))):
            th = threats_of(character_name, 150)
            strength = th.get("strength") or 1
            # what would attack you and win: above your strength alone, or a pack of anything above half of it
            danger = [t for t in th["threats"] if t["aggressive"] and t["distance"] <= 120
                      and (t["level"] > strength or (t.get("pack", 1) >= 2 and t["level"] * 2 > strength))]
            if danger:
                t = danger[0]
                what = f"{t['name']} (level {t['level']}" + (f", a pack of {t['pack']}" if t.get("pack", 1) > 1 else "") + ")"
                log.append(_escape(f"danger: {what} {t['distance']} m away would attack you")); break
            near = creatures_near(name_fragment)
            if near.get("ok") and not near["creatures"] and near.get("farther"):
                # nothing in view but the server knows one roaming farther out: walk there and look again
                f = near["farther"][0]
                w = seat_mod.walk_seat(seat, character_name, f["x"], f["y"], within=18)
                if not w.get("ok"):
                    log.append(f"could not reach {f['name']} {f['distance']} m away: {seat_mod.action_error(w)}"); break
                log.append(f"walked {f['distance']} m toward {f['name']}")
                near = creatures_near(name_fragment)
            if not near.get("ok") or not near["creatures"]:
                log.append("nothing matching in view" + (" or within 300 m" if near.get("ok") else "")); break
            prey = [c for c in near["creatures"] if c["level"] <= strength and (c.get("pack", 1) <= 2 or c["level"] * 2 <= strength)]
            if not prey:
                skipped = "; ".join(f"{c['name']} level {c['level']}" + (f" in a pack of {c['pack']}" if c.get("pack", 1) > 1 else "")
                                    for c in near["creatures"][:4])
                log.append(f"too strong for you (your strength {strength}): {skipped}"); break
            c = prey[0]
            if c["distance"] > 22:
                w = seat_mod.walk_seat(seat, character_name, c["x"], c["y"], within=18)
                if not w.get("ok"):
                    log.append(f"could not reach {c['name']}: {seat_mod.action_error(w)}"); break
            r = seat_mod.fight_seat(seat, character_name, c["oid"], 90, harvest=can_harvest)
            log.append(f"{c['name']}: {r['verdict']} in {r['seconds']} s" + (", looted" if r["looted"] else "") + (", harvested" if r.get("harvested") else ""))
            if r["verdict"] == "killed":
                done += 1
                harvested += 1 if r.get("harvested") else 0
            elif r["verdict"] == "retreat":
                log.append(_escape("retreat")); break
        result = {"ok": done > 0, "kills": done, "harvested": harvested, "strength": strength, "log": log, "health": my_health().get("health")}
        if done == 0:
            result["error"] = "no kill: " + ("; ".join(str(l) for l in log[-3:]) or "nothing matching to hunt")
        return result

    def tend_harvesters(hours_of_reserve):
        """the gatherer's round: every harvester you own on this planet — walk to it, empty every hopper line into
        your inventory, top up maintenance and power to `hours_of_reserve` hours at its rates"""
        seat_mod = load_seat_module()
        hours = max(6, min(int(hours_of_reserve), 168))
        planet = seat.request({"op": "vars", "path": "/Scene/terrain"}).get("vars")
        mine = my_structures()
        visited, log = 0, []
        for st in mine.get("structures", []):
            if st.get("zone") != planet or st.get("type") not in ("0x1003", "0x1002", "0x1000"):
                continue
            oid, x, y = int(st["oid"]), float(st["x"]), float(st["y"])
            w = seat_mod.walk_seat(seat, character_name, x, y, within=12)
            if not w.get("ok"):
                log.append(f"{oid}: unreachable ({seat_mod.action_error(w)})"); continue
            status = harvester_status(oid)
            if not status.get("ok"):
                log.append(f"{oid}: no status"); continue
            lines = []
            for h in status.get("hopper", []):
                q = int(h.get("quantity", 0))
                if q > 0:
                    r = seat.action("harvester", target=oid, op="empty", resource=int(h["spawn"]), quantity=q)
                    lines.append(f"emptied {q} {h.get('name')}" if r.get("ok") else f"empty failed: {seat_mod.action_error(r)}")
            m_rate, p_rate = int(status.get("maintenanceRate", 0)), int(status.get("powerRate", 0))
            need_m = hours * m_rate - int(status.get("maintenance", 0))
            need_p = hours * p_rate - int(status.get("power", 0))
            if need_m > 0:
                r = seat.action("harvester", target=oid, op="maintain", amount=need_m)
                lines.append(f"paid {need_m} maintenance" if r.get("ok") else f"maintenance failed: {seat_mod.action_error(r)}")
            if need_p > 0:
                r = seat.action("harvester", target=oid, op="power", amount=need_p)
                lines.append(f"deposited {need_p} power" if r.get("ok") else f"power failed: {seat_mod.action_error(r)}")
            if status.get("active") != "true":
                r = seat.action("harvester", target=oid, op="activate")
                lines.append("activated" if r.get("ok") else f"activate failed: {seat_mod.action_error(r)}")
            visited += 1
            log.append(f"{oid} ({status.get('activeResourceName', '?')}): " + ("; ".join(lines) or "fine"))
        return {"ok": visited > 0 or not mine.get("structures"), "visited": visited, "log": log}

    def remember(note):
        files.remember(note)
        return {"ok": True}

    def complete_milestone(text):
        return {"ok": files.complete_milestone(text)}

    def change_plan(reason, milestones):
        if not reason or len(reason.strip()) < 20:
            return {"ok": False, "error": "a plan change needs a real reason (one or two sentences)"}
        files.change_plan(reason, milestones)
        return {"ok": True}

    def rest(seconds):
        return {"ok": True, "rest": max(30, min(int(seconds), 1800))}

    impl = {
        "say": say, "tell": tell, "emote": emote, "walk_to": walk_to, "travel_to": travel_to,
        "resources_here": resources_here, "survey": survey, "sample": sample, "place_harvester": place_harvester,
        "harvester": harvester, "harvester_status": harvester_status, "my_structures": my_structures,
        "my_health": my_health, "clone": clone, "my_inventory": my_inventory, "travel_points": travel_points, "spots_near_shuttles": spots_near_shuttles, "creatures_near": creatures_near, "hunt": hunt, "tend_harvesters": tend_harvesters,
        "threats_near": threats_near,
        "train": train,
        "remember": remember, "complete_milestone": complete_milestone, "change_plan": change_plan, "rest": rest,
    }
    schema = [
        {"name": "say", "description": "Speak out loud where you stand (everyone within ~60 m hears it).",
         "input_schema": {"type": "object", "properties": {"text": {"type": "string"}}, "required": ["text"], "additionalProperties": False}, "strict": True},
        {"name": "tell", "description": "Send a private /tell to a player by first name.",
         "input_schema": {"type": "object", "properties": {"name": {"type": "string"}, "text": {"type": "string"}}, "required": ["name", "text"], "additionalProperties": False}, "strict": True},
        {"name": "emote", "description": "Play a social emote (wave, bow, salute, nod, shrug, cheer, laugh, thank, greet, sigh…).",
         "input_schema": {"type": "object", "properties": {"name": {"type": "string"}, "target": {"type": "integer"}}, "required": ["name", "target"], "additionalProperties": False}, "strict": True},
        {"name": "walk_to", "description": "Walk to a world position on this planet (takes real time: 4.5 m/s). Refused beyond 2000 m: the wild kills a lone walker; take a shuttle (travel_to) between cities and walk from there.",
         "input_schema": {"type": "object", "properties": {"x": {"type": "number"}, "y": {"type": "number"}}, "required": ["x", "y"], "additionalProperties": False}, "strict": True},
        {"name": "travel_to", "description": "Take the shuttle to a travel point: walk to the nearest terminal, buy a ticket (a few hundred credits), board when the shuttle lands. Points are named like Mos_Eisley_Starport, Coronet_Starport, Theed_Starport, Bestine_Shuttleport; another planet needs a starport on both ends. Takes minutes.",
         "input_schema": {"type": "object", "properties": {"planet": {"type": "string"}, "point": {"type": "string"}}, "required": ["planet", "point"], "additionalProperties": False}, "strict": True},
        {"name": "resources_here", "description": "What resources are currently spawning on this planet (name, class, best spot and density, stats). Class filter by the survey tool that finds it: mineral, chemical, flora, gas, water, wind, solar, geothermal, fusion; empty = everything a tool can find; 'all' adds creature resources (hides, meat: hunted, not surveyed). Each resource lists up to three land spots with the nearest shuttle point and its distance: travel_to that point, then walk. Use the exact name from here with survey.",
         "input_schema": {"type": "object", "properties": {"resource_class": {"type": "string"}}, "required": ["resource_class"], "additionalProperties": False}, "strict": True},
        {"name": "survey", "description": "Survey a resource (exact name from resources_here, or a unique fragment) with the survey tool you carry: how rich it is around you and the best nearby point. A mineral tool only finds minerals.",
         "input_schema": {"type": "object", "properties": {"resource": {"type": "string"}}, "required": ["resource"], "additionalProperties": False}, "strict": True},
        {"name": "sample", "description": "Sample a resource by name where you stand (needs a survey of it first; each round takes ~25 s and yields a few units when the concentration is good).",
         "input_schema": {"type": "object", "properties": {"resource": {"type": "string"}, "rounds": {"type": "integer"}}, "required": ["resource", "rounds"], "additionalProperties": False}, "strict": True},
        {"name": "place_harvester", "description": "Place a harvester from a deed you carry (words of its name, e.g. 'ore harvester'; an ore harvester mines minerals) at a world spot within 100 m, outdoors and outside cities. Uses a lot.",
         "input_schema": {"type": "object", "properties": {"deed_fragment": {"type": "string"}, "x": {"type": "number"}, "y": {"type": "number"}}, "required": ["deed_fragment", "x", "y"], "additionalProperties": False}, "strict": True},
        {"name": "harvester", "description": "Operate a harvester you own while standing next to it. op: resources (what it can extract here, with density), select (resource = spawn oid from resources), activate, deactivate, maintain (amount = credits), power (amount = energy units from wind/solar containers you carry), empty (resource = spawn oid, amount = units from the hopper into your inventory). Pass 0 for unused fields.",
         "input_schema": {"type": "object", "properties": {"oid": {"type": "integer"}, "op": {"type": "string"}, "resource": {"type": "integer"}, "amount": {"type": "integer"}}, "required": ["oid", "op", "resource", "amount"], "additionalProperties": False}, "strict": True},
        {"name": "harvester_status", "description": "A harvester's state: active, active resource, maintenance and power left and their hourly rates, hopper contents.",
         "input_schema": {"type": "object", "properties": {"oid": {"type": "integer"}}, "required": ["oid"], "additionalProperties": False}, "strict": True},
        {"name": "my_structures", "description": "The structures you own (oid, planet, position, active) and the lots you have left.",
         "input_schema": {"type": "object", "properties": {}, "required": [], "additionalProperties": False}, "strict": True},
        {"name": "my_health", "description": "Your condition (fine, incapacitated, dead) and health/action/mind pools as current/max/wounds.",
         "input_schema": {"type": "object", "properties": {}, "required": [], "additionalProperties": False}, "strict": True},
        {"name": "threats_near", "description": "What would attack you within 150 m (aggressive creatures and NPCs, wild creatures stronger than you) with level and distance, and your own fighting strength. Hunt only when it is empty; with anything in it, walk 300 m toward town first.",
         "input_schema": {"type": "object", "properties": {}, "required": [], "additionalProperties": False}, "strict": True},
        {"name": "train", "description": "Buy a skill box at its trainer (the exact name from \"training\" → \"ready\" in your perception, e.g. outdoors_scout_movement_01): walks to the nearest trainer of that profession in this city and pays the credits. This is how you grow stronger; a box in \"next\" needs more experience first.",
         "input_schema": {"type": "object", "properties": {"skill": {"type": "string"}}, "required": ["skill"]}},
        {"name": "spots_near_shuttles", "description": "For one resource (exact name from resources_here): the best spot within 1.5 km of each shuttle point on this planet, with density and the walk from the shuttle. A harvester only needs a good spot near a town.",
         "input_schema": {"type": "object", "properties": {"resource": {"type": "string"}}, "required": ["resource"], "additionalProperties": False}, "strict": True},
        {"name": "travel_points", "description": "The shuttle and starport points of a planet with positions: pick the one nearest a spot, travel_to it, then walk the rest (under 2 km).",
         "input_schema": {"type": "object", "properties": {"planet": {"type": "string"}}, "required": ["planet"], "additionalProperties": False}, "strict": True},
        {"name": "my_inventory", "description": "What you carry, by name with counts (deeds, tools, weapons, resources).",
         "input_schema": {"type": "object", "properties": {}, "required": [], "additionalProperties": False}, "strict": True},
        {"name": "clone", "description": "When you are dead: revive at the closest cloning facility. Nothing else works until you do.",
         "input_schema": {"type": "object", "properties": {}, "required": [], "additionalProperties": False}, "strict": True},
        {"name": "creatures_near", "description": "Creatures within 80 m whose name contains the fragment (empty for all), nearest first, with positions; when none, what roams within 300 m (walk there first). Wild creatures appear only around a player moving through open ground outside town.",
         "input_schema": {"type": "object", "properties": {"name_fragment": {"type": "string"}}, "required": ["name_fragment"], "additionalProperties": False}, "strict": True},
        {"name": "hunt", "description": "Fight creatures whose name contains the fragment: walk to the nearest, attack until it dies, loot, harvest the corpse if you are a scout (meat/hide/bone and scout experience), repeat up to `kills` times (1-5). Stops if your health drops to a third. Takes a minute or two per kill.",
         "input_schema": {"type": "object", "properties": {"name_fragment": {"type": "string"}, "kills": {"type": "integer"}}, "required": ["name_fragment", "kills"], "additionalProperties": False}, "strict": True},
        {"name": "tend_harvesters", "description": "The gatherer's round on this planet: walk to each harvester you own, empty its hopper into your inventory, pay maintenance and power up to this many hours of reserve, switch it on. Takes minutes.",
         "input_schema": {"type": "object", "properties": {"hours_of_reserve": {"type": "integer"}}, "required": ["hours_of_reserve"], "additionalProperties": False}, "strict": True},
        {"name": "remember", "description": "Write a note into your long-term memory (people met, promises, what happened).",
         "input_schema": {"type": "object", "properties": {"note": {"type": "string"}}, "required": ["note"], "additionalProperties": False}, "strict": True},
        {"name": "complete_milestone", "description": "Tick a milestone of your life plan, quoting its text exactly.",
         "input_schema": {"type": "object", "properties": {"text": {"type": "string"}}, "required": ["text"], "additionalProperties": False}, "strict": True},
        {"name": "change_plan", "description": "Replace your life plan's milestones. Only for a strong, in-character reason; the reason is logged and reviewed.",
         "input_schema": {"type": "object", "properties": {"reason": {"type": "string"}, "milestones": {"type": "array", "items": {"type": "string"}}}, "required": ["reason", "milestones"], "additionalProperties": False}, "strict": True},
        {"name": "rest", "description": "Nothing to do right now: sleep this many seconds (30–1800) unless something happens.",
         "input_schema": {"type": "object", "properties": {"seconds": {"type": "integer"}}, "required": ["seconds"], "additionalProperties": False}, "strict": True},
    ]
    # the API allows 20 strict tools: a tool without arguments has nothing to validate, so it goes without
    for t in schema:
        if not t["input_schema"]["properties"]:
            t.pop("strict", None)
    assert sum(1 for t in schema if t.get("strict")) <= 20, "too many strict tools"
    return impl, schema


# ------------------------------------------------------------------ deciders
SYSTEM_RULES = """You are playing a character in Star Wars Galaxies on a small private server. You act only through the tools.
Stay in character at all times; never mention being an AI, a model or a program. Speak the way the persona's voice
samples do: one or two short sentences, in your own words, like a person typing in a game. Other players are real
people: be a good companion, answer tells, remember them.
The perception JSON tells you who you are ("you"), where you are, what you are working on now ("now"), who is nearby
and what you heard. A tell arrives as "Sender: text": answer that sender with the tell tool, by that name. Do not
announce your own name unless asked who you are; people see your name over your head. Say concretely what you are
doing (your "now"), not "on my way somewhere".
Your life plan is a commitment: work its milestones in order and do not abandon it on a whim; change_plan only for a
reason your character would give out loud, and expect it to be reviewed. Keep your memory honest and short.
If "condition" says dead, call clone before anything else; incapacitated, wait a minute. "threats" lists what would
attack you where you stand, each with its level against your "fighting_strength": with anything in it, walk 300 m toward
town before any other work; never hunt there. hunt itself refuses prey above your strength and walks you toward town
after a retreat — read its log and do not send it again at the same spot.
"training" lists the skill boxes you can buy right now ("ready", with the credits) and what you are working toward
("next", experience have/cost): when a box is ready and you can pay, call train with its name before anything else —
that is how a character grows, and your fighting_strength and level follow it.
When nothing needs you, work your current milestone ("now") before resting: a combat skill grows by hunting creatures
you can take near where you are (walk a leg through open ground outside town, creatures_near, then hunt; "xp" in the perception shows amount/cap per type, so you
can see whether it pays), a gatherer tends harvesters, a crafter samples and keeps resources, and anyone with nothing
to do walks somewhere people are. Then call rest. One wake is a few actions at most; the world keeps running between
wakes."""


class ModelDecider:
    def __init__(self, model, effort):
        import anthropic   # the SDK is only needed when a model drives the pilot
        self.anthropic = anthropic
        self.client = anthropic.Anthropic()
        self.model = model
        self.effort = effort

    def decide(self, system_blocks, perception, tools_schema, run_tool, log):
        messages = [{"role": "user", "content": "Perception since your last wake (JSON):\n" + json.dumps(perception, ensure_ascii=False)}]
        rest = None
        for _ in range(MAX_ROUNDS_PER_WAKE):
            response = self.client.messages.create(
                model=self.model,
                max_tokens=MAX_TOKENS,
                output_config={"effort": self.effort},
                system=system_blocks,
                tools=tools_schema,
                messages=messages,
            )
            usage = response.usage
            log({"usage": {"in": usage.input_tokens, "out": usage.output_tokens,
                           "cache_read": getattr(usage, "cache_read_input_tokens", 0),
                           "cache_write": getattr(usage, "cache_creation_input_tokens", 0)},
                 "stop": response.stop_reason})
            if response.stop_reason == "refusal":
                log({"refusal": getattr(response.stop_details, "category", None) if response.stop_details else None})
                break
            for b in response.content:
                if b.type == "text" and b.text.strip():
                    log({"text": b.text.strip()[:400]})
            tool_uses = [b for b in response.content if b.type == "tool_use"]
            if not tool_uses:
                break
            messages.append({"role": "assistant", "content": response.content})
            results = []
            for use in tool_uses:
                result = run_tool(use.name, dict(use.input))
                if use.name == "rest" and result.get("ok"):
                    rest = result["rest"]
                results.append({"type": "tool_result", "tool_use_id": use.id,
                                "content": json.dumps(result, ensure_ascii=False)[:2000],
                                "is_error": not result.get("ok", False)})
            messages.append({"role": "user", "content": results})
            if response.stop_reason == "end_turn":
                break
        return rest


class DryDecider:
    """No model: answer tells and nearby greetings with the persona's first voice line, then rest."""

    def __init__(self, persona_text):
        m = re.search(r"^## Voice\s*\n\s*- \"(.*?)\"", persona_text, re.S | re.M)
        self.line = m.group(1) if m else "Well met."

    def decide(self, system_blocks, perception, tools_schema, run_tool, log):
        acted = False
        for t in perception.get("tells", []):
            who = t.split(":", 1)[0].strip()
            if who:
                run_tool("tell", {"name": who, "text": self.line})
                run_tool("remember", {"note": f"{who} sent me a tell; I answered."})
                acted = True
        if perception.get("heard") and not acted:
            run_tool("emote", {"name": "nod", "target": 0})
            acted = True
        return 60 if acted else 300


# ------------------------------------------------------------------ the loop
def run(args):
    files = CitizenFiles(args.citizen, args.home)
    persona = files.persona()
    ensure_runtime(args.dry)
    seat_mod = load_seat_module()
    seat_name = args.seat or files.state().get("seat") or args.citizen
    seat = seat_mod.Seat(seat_name, timeout=60)
    character = seat_mod.seat_character_name(seat_name)

    state = files.state()
    state["seat"] = seat_name
    senses = Senses(seat, state, character, files)
    impl, schema = seat_tools(seat, files, character, seat_name)

    def run_tool(name, inputs):
        fn = impl.get(name)
        if fn is None:
            return {"ok": False, "error": f"unknown tool {name}"}
        try:
            result = fn(**inputs)
        except Exception as e:   # a tool failure is a result the model should see, not a crash of the pilot
            result = {"ok": False, "error": str(e)}
        if not result.get("ok") and result.get("error") is None and isinstance(result.get("result"), dict):
            result["error"] = result["result"].get("error") or result["result"].get("status")
        err = str(result.get("error") or "")
        for code, meaning in LOCOMOTION_REFUSALS.items():
            if f"state={code}" in err:
                result["error"] = err + f" ({meaning})"
        files.log({"tool": name, "input": inputs, "ok": result.get("ok")})
        print(f"[{args.citizen}] {name} {json.dumps(inputs, ensure_ascii=False)[:160]} -> {'ok' if result.get('ok') else result.get('error')}")
        return result

    model = args.model or files.character_field("model") or DEFAULT_MODEL
    decider = DryDecider(persona) if args.dry else ModelDecider(model, args.effort)
    print(f"[{args.citizen}] decider: {'dry' if args.dry else model + ' effort ' + args.effort}")
    ticks = 0
    while args.ticks == 0 or ticks < args.ticks:
        ticks += 1
        try:
            perception = senses.gather()
        except (TimeoutError, OSError) as e:
            # the seat is busy (a walk left over from an earlier pilot holds its action lock): wait, do not die
            print(f"[{args.citizen}] seat not answering ({e}); trying again in 30 s", flush=True)
            ticks -= 1
            time.sleep(30)
            continue
        # the stable prefix first (cached), the plan and memory after it (they change rarely)
        system_blocks = [
            {"type": "text", "text": SYSTEM_RULES + "\n\n# Persona\n" + persona, "cache_control": {"type": "ephemeral"}},
            {"type": "text", "text": "# Life plan\n" + files.plan() + "\n\n# Memory\n" + files.memory()[-6000:]},
        ]
        files.log({"wake": ticks, "perception": {k: (len(v) if isinstance(v, list) else v) for k, v in perception.items()}})
        try:
            rest = decider.decide(system_blocks, perception, schema, run_tool, files.log)
        except Exception as e:   # an API refusal or outage is a wait, not the end of the citizen
            print(f"[{args.citizen}] decider failed: {str(e)[:300]}; trying again in 120 s", flush=True)
            files.log({"decider_error": str(e)[:300]})
            time.sleep(120)
            continue
        state["last_wake"] = now_iso()
        files.save_state(state)

        if args.ticks and ticks >= args.ticks:
            break
        # wait for something to happen, or the rest to end
        wait = rest or args.idle
        deadline = time.time() + wait
        while time.time() < deadline:
            r = seat.request({"op": "wait", "signal": "Tell", "timeoutMs": int(min(30, deadline - time.time()) * 1000)}, timeout=40)
            if r.get("fired"):
                break
    print(f"[{args.citizen}] done after {ticks} wake(s)")


def show(args):
    files = CitizenFiles(args.citizen)
    print(files.persona())
    print("\n==== plan ====\n" + files.plan())
    print("\n==== memory ====\n" + files.memory())


def main():
    # the log is usually a redirected file: flush every line so a tail shows the current wake, not the last buffer
    try:
        sys.stdout.reconfigure(line_buffering=True)
        sys.stderr.reconfigure(line_buffering=True)
    except (AttributeError, ValueError):
        pass
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run")
    r.add_argument("citizen")
    r.add_argument("--seat")
    r.add_argument("--home", default=None, help="state directory (default ~/.swg-lab/citizens/<citizen>; scenarios use their own)")
    r.add_argument("--model", default=None, help=f"model id (default: the persona's model:, else {DEFAULT_MODEL})")
    r.add_argument("--effort", default=DEFAULT_EFFORT, choices=["low", "medium", "high"])
    r.add_argument("--idle", type=int, default=300, help="seconds between wakes when nothing happens")
    r.add_argument("--ticks", type=int, default=0, help="stop after N wakes (0 = run until killed)")
    r.add_argument("--dry", action="store_true", help="scripted decider, no model")
    r.set_defaults(fn=run)
    s = sub.add_parser("show")
    s.add_argument("citizen")
    s.set_defaults(fn=show)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
