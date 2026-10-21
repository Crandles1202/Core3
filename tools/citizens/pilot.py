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
    def __init__(self, name):
        self.name = name
        self.persona_path = os.path.join(CAST_DIR, f"{name}.md")
        self.dir = os.path.join(LABDIR, "citizens", name)
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

    def __init__(self, seat, state):
        self.seat = seat
        self.state = state

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

    def gather(self):
        ping = self.seat.request({"op": "ping"})
        chat = self._new_lines("/SpatialChat", "chat_seen")
        tells = self._new_lines("/Tells", "tells_seen")
        system = self._new_lines("/SystemMessages", "system_seen")
        objects = self.seat.request({"op": "objects"}).get("objects", [])
        me = next((o for o in objects if o["oid"] == ping.get("character")), None)
        near = []
        if me:
            for o in objects:
                if o["oid"] == me["oid"] or o["type"] not in (0x400, 0x401, 0x402, 0x409):
                    continue
                d = ((o["x"] - me["x"]) ** 2 + (o["y"] - me["y"]) ** 2) ** 0.5
                if d < 40:
                    near.append({"oid": o["oid"], "name": o["name"], "player": o["type"] == 0x409, "distance": round(d, 1)})
            near.sort(key=lambda n: n["distance"])
        planet = self.seat.request({"op": "vars", "path": "/Scene/terrain"}).get("vars")
        return {
            "character": ping.get("character"),
            "planet": planet if isinstance(planet, str) else None,
            "position": {"x": round(me["x"], 1), "y": round(me["y"], 1)} if me else None,
            "heard": chat[-12:],
            "tells": tells[-12:],
            "system": [s for s in system if not s.startswith("@") or "combat" in s][-8:],
            "nearby": near[:12],
        }


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
        return seat_mod.walk_seat(seat, character_name, float(x), float(y))

    def travel_to(planet, point):
        seat_mod = load_seat_module()
        reply = seat_mod.travel_seat(seat, seat_name, planet, point)
        if reply.get("ok"):
            arrived = reply.get("arrived") or {}
            return {"ok": True, "planet": arrived.get("zone", planet), "x": arrived.get("x"), "y": arrived.get("y"),
                    "departure": reply.get("departure"), "waitedS": reply.get("waitedS")}
        return {"ok": False, "error": reply.get("error"), "step": reply.get("step")}

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
        "remember": remember, "complete_milestone": complete_milestone, "change_plan": change_plan, "rest": rest,
    }
    schema = [
        {"name": "say", "description": "Speak out loud where you stand (everyone within ~60 m hears it).",
         "input_schema": {"type": "object", "properties": {"text": {"type": "string"}}, "required": ["text"], "additionalProperties": False}, "strict": True},
        {"name": "tell", "description": "Send a private /tell to a player by first name.",
         "input_schema": {"type": "object", "properties": {"name": {"type": "string"}, "text": {"type": "string"}}, "required": ["name", "text"], "additionalProperties": False}, "strict": True},
        {"name": "emote", "description": "Play a social emote (wave, bow, salute, nod, shrug, cheer, laugh, thank, greet, sigh…).",
         "input_schema": {"type": "object", "properties": {"name": {"type": "string"}, "target": {"type": "integer"}}, "required": ["name", "target"], "additionalProperties": False}, "strict": True},
        {"name": "walk_to", "description": "Walk to a world position on this planet (takes real time: 4.5 m/s).",
         "input_schema": {"type": "object", "properties": {"x": {"type": "number"}, "y": {"type": "number"}}, "required": ["x", "y"], "additionalProperties": False}, "strict": True},
        {"name": "travel_to", "description": "Take the shuttle to a travel point: walk to the nearest terminal, buy a ticket (a few hundred credits), board when the shuttle lands. Points are named like Mos_Eisley_Starport, Coronet_Starport, Theed_Starport, Bestine_Shuttleport; another planet needs a starport on both ends. Takes minutes.",
         "input_schema": {"type": "object", "properties": {"planet": {"type": "string"}, "point": {"type": "string"}}, "required": ["planet", "point"], "additionalProperties": False}, "strict": True},
        {"name": "remember", "description": "Write a note into your long-term memory (people met, promises, what happened).",
         "input_schema": {"type": "object", "properties": {"note": {"type": "string"}}, "required": ["note"], "additionalProperties": False}, "strict": True},
        {"name": "complete_milestone", "description": "Tick a milestone of your life plan, quoting its text exactly.",
         "input_schema": {"type": "object", "properties": {"text": {"type": "string"}}, "required": ["text"], "additionalProperties": False}, "strict": True},
        {"name": "change_plan", "description": "Replace your life plan's milestones. Only for a strong, in-character reason; the reason is logged and reviewed.",
         "input_schema": {"type": "object", "properties": {"reason": {"type": "string"}, "milestones": {"type": "array", "items": {"type": "string"}}}, "required": ["reason", "milestones"], "additionalProperties": False}, "strict": True},
        {"name": "rest", "description": "Nothing to do right now: sleep this many seconds (30–1800) unless something happens.",
         "input_schema": {"type": "object", "properties": {"seconds": {"type": "integer"}}, "required": ["seconds"], "additionalProperties": False}, "strict": True},
    ]
    return impl, schema


# ------------------------------------------------------------------ deciders
SYSTEM_RULES = """You are playing a character in Star Wars Galaxies on a small private server. You act only through the tools.
Stay in character at all times; never mention being an AI, a model or a program. Speak the way the persona's voice
samples do, briefly. Other players are real people: be a good companion, answer tells, remember them.
Your life plan is a commitment: work its milestones in order and do not abandon it on a whim; change_plan only for a
reason your character would give out loud, and expect it to be reviewed. Keep your memory honest and short.
When nothing needs you, call rest. One wake is a few actions at most; the world keeps running between wakes."""


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
    files = CitizenFiles(args.citizen)
    persona = files.persona()
    ensure_runtime(args.dry)
    seat_mod = load_seat_module()
    seat_name = args.seat or files.state().get("seat") or args.citizen
    seat = seat_mod.Seat(seat_name, timeout=60)
    character = seat_mod.seat_character_name(seat_name)

    state = files.state()
    state["seat"] = seat_name
    senses = Senses(seat, state)
    impl, schema = seat_tools(seat, files, character, seat_name)

    def run_tool(name, inputs):
        fn = impl.get(name)
        if fn is None:
            return {"ok": False, "error": f"unknown tool {name}"}
        try:
            result = fn(**inputs)
        except Exception as e:   # a tool failure is a result the model should see, not a crash of the pilot
            result = {"ok": False, "error": str(e)}
        files.log({"tool": name, "input": inputs, "ok": result.get("ok")})
        print(f"[{args.citizen}] {name} {json.dumps(inputs, ensure_ascii=False)[:160]} -> {'ok' if result.get('ok') else result.get('error')}")
        return result

    model = args.model or files.character_field("model") or DEFAULT_MODEL
    decider = DryDecider(persona) if args.dry else ModelDecider(model, args.effort)
    print(f"[{args.citizen}] decider: {'dry' if args.dry else model + ' effort ' + args.effort}")
    ticks = 0
    while args.ticks == 0 or ticks < args.ticks:
        ticks += 1
        perception = senses.gather()
        # the stable prefix first (cached), the plan and memory after it (they change rarely)
        system_blocks = [
            {"type": "text", "text": SYSTEM_RULES + "\n\n# Persona\n" + persona, "cache_control": {"type": "ephemeral"}},
            {"type": "text", "text": "# Life plan\n" + files.plan() + "\n\n# Memory\n" + files.memory()[-6000:]},
        ]
        files.log({"wake": ticks, "perception": {k: (len(v) if isinstance(v, list) else v) for k, v in perception.items()}})
        rest = decider.decide(system_blocks, perception, schema, run_tool, files.log)
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
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run")
    r.add_argument("citizen")
    r.add_argument("--seat")
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
