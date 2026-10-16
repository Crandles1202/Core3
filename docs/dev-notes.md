# Final Boss dev notes — things we learned the hard way

Running log of non-obvious facts about this codebase and lab. CLAUDE.md carries the short version;
this file has the detail. Add an entry whenever something costs more than ten minutes to figure out.

## Core3 Lua

### `SceneObject(p)` and friends are ONE shared wrapper per class
`SceneObject(p)`, `CreatureObject(p)`, `PlayerObject(p)`, `AiAgent(p)` … do not construct a new object;
they return a per-class wrapper (Luna) that is re-pointed at `p`. Consequence:

```lua
local inv = SceneObject(pInv)
local pItem = inv:getContainerObject(0)
local path = SceneObject(pItem):getTemplateObjectPath()   -- re-points the SAME wrapper at pItem
inv:getContainerObject(1)                                 -- now indexes the ITEM's container → throws
```

The throw is a C++ `ArrayIndexOutOfBoundsException` — Lua `pcall` cannot catch it, `runLuaFunction`
reports "Exception in runLuaFunction … at N", and the console Lua stack is left dirty (every later
`runLuaFunction` logs `Lua::checkStack FAILED` until the server restarts). Rule: wrap inline, every
call: `SceneObject(pInv):getContainerObject(i)`. Upstream screenplays all do this; copy the habit.
(Found 2026-10-16 while writing `fb_lab_tests.lua`; cost ~40 minutes.)

### Several Lua states, not one
- DirectorManager (screenplays, conversation *handlers*, `runLuaFunction`): `scripts/screenplays/screenplays.lua`.
  One Lua instance per thread. `reloadscreenplays` bumps a version; each thread re-runs
  `screenplays.lua` into its *existing* state on next use — globals persist, `start()` is not re-run.
- CreatureTemplateManager: mobile templates + `conversations.lua` (conversation *templates*).
- PlayerCreationManager, PlanetManager, PlayerManager, LootManager …: each loads its own
  `scripts/managers/*.lua` into its own state at boot. No reload — restart.
- Config (`conf/config.lua`, `config-local.lua`, `~/custom-features.lua` → `FBFeatures`): yet another
  state, read by `ConfigManager`. `FBFeatures` is **not visible** from screenplay Lua.

To check a value from another state in a test, `loadfile(path, "t", env)` the file into a sandbox env
(`setmetatable({}, {__index = _G})`) and read the global out of `env` (see `fb_lab_tests.lua`).

### Spawned NPCs are not findable afterwards
`spawnMobile` returns the pointer and nothing records it; there is no "objects in range" Lua call
(`getZoneByName` returns a bare lightuserdata with no methods). The lab test wraps `spawnMobile` from
`custom_scripts` (loaded before the `fb_*` screenplays' `start()`) and records `fb_*` spawns by OID.

### Console `runLuaFunction module:function[:arg…]`
- Calls `module.function(module, args…)` — define with `:` and ignore `self`, or use `.` and accept
  the table as first arg.
- Args are split on `:`; strings only.
- `print()` goes to the console/`screenlog.0`; `printLuaError` to `log/lua.log`.
- Lua on the console thread holds no object locks. Read-only probes are fine; don't mutate world
  objects from there.
- The "result=[<no value>]" line is meaningless (it reads stack index 0).

### Mobile templates must have combat stats even for vendors
`LuaMobileTest.LuaMobileTemplatesTest` fails on any mobile with `mobType` unset/0, `chanceHit <= 0`,
`damageMin <= 0`, `baseHAM <= 0`. Non-combat NPCs: `mobType = MOB_NPC` (people) / `MOB_DROID`,
`chanceHit = 0.25`, `damageMin = 1`, `damageMax = 5`, `baseHAM/baseHAMmax = 100`, keep
`INVULNERABLE + CONVERSABLE`.

## core3client (bot)
- Built only with `-DENABLE_BUILD_CLIENT=ON` (`CMAKE_ARGS=-DENABLE_BUILD_CLIENT=ON ~/bin/build`).
- Race, name `--char-race`, must be the full template path `object/creature/player/human_male.iff`.
- Non-admin accounts (admin_level < 9) may create **one character per hour**
  (`PlayerCreationManager.cpp:467`), and a failed attempt resets the timer. `swg test bot` falls back
  to zoning in as the newest `Lab*` character.
- Its log is block-buffered when redirected to a file: you cannot poll it for progress. `swg` polls the
  server instead (`runLuaFunction FbLabTests:isOnline:<name>`).
- Two fixes live in our fork: `ZonePacketHandler::handleClientCreateCharacterSuccess` sets
  `selectedCharacterOid` before sending `SelectCharacter` (otherwise the scene is aborted as "wrong
  OID"), and `--wait-after-zone` now sleeps *before* the auto-appended `logoutCharacter` action.
- Exit codes: 0 ok, `100 + action error code` (104 = create failed, 105 = create timeout).

## Scenario testing (bot + oracle)
- `tools/swg test scenario <name>` runs `tools/scenarios/<name>.sh`; `lib.sh` gives `bot …` (core3client
  as the lab character), `lab fn:args` (Lua oracle via `runLuaFunction FbLabTests:…`), `check*`, `finish`.
- Each `lab` round trip costs ~1 s; a `bot_bg --wait N` staging window must cover all of them.
- Client action flags: `--command`, `--radial`, `--converse … --options`, `--wait`. Boost's option
  parser used to prefix-match these to `--wait-after-zone`/`--options-json` (crash: "cannot be
  specified more than once"); guessing is now disabled in `ClientCore.cpp`.
- Actions that need a character set `needsCharacter()`; `resolveDependencies` auto-inserts
  `zoneInCharacter` before the first one, so `--character-firstname X --command foo` just works.
- CommandQueueRemove `error` (tab1): 1 locomotion, 2 general failure (command refused for its own
  reasons, e.g. "No valid medicine found"), 3 invalid target, 4 too far, 5 state (state bit in tab2).
- The client now renders string-id system messages as `@file:id TO=… DI=n` in its log, so a refused
  command usually explains itself there.
- New characters created by the bot land in the **tutorial** zone (`canSkipTutorial=false` for the
  account). `lab travel:<char>:tatooine:3520:-4800` parks them at Mos Eisley starport, next to FB-72.
- Lua bindings return floats (`getSkillMod` → `0.0`); format with `%d` / `math.floor` before bash
  compares them.
- Regen moves every pool by about the same amount while a scenario waits; compare the pool under
  test against an untouched pool (health delta − mind delta) instead of a raw threshold.
- **Content finding (Phase 1.3):** `stimpack_sm_s1` has `medicineUse = 5` and `HealDamageCommand`
  only picks stimpacks whose `medicineUse <= healing_ability`. A fresh non-medic has
  `healing_ability = 0`, so the starter stimpack cannot be used by most new characters. Either lower
  `medicineUse` on the starter pack (own template), grant a small `healing_ability`, or hand out a
  different consumable. Chuck's call.

## Server / lab
- Boot ~45 s to `READY`; clean `shutdown` ~80 s. Start under gdb (`~/bin/gdb_settings`) so crashes
  leave a backtrace in `bin/gdb.log`; `swg stop` quits gdb afterwards.
- Known noise on every boot: `[MantisDatabase0] ERROR - 1045` + `[Console] ERROR - 1045` (Mantis
  integration, not ours). `swg logs --errors` filters them.
- `decreaseOnlineCharCount missing account N in onlineZoneClientMap` ERROR = a client disconnected
  while the server was still connecting its player (SelectCharacter sent, scene not yet up). Our bot
  did exactly that after character creation until `CreateCharacterAction` learned to wait for the
  scene. If it shows up again, some client is logging out mid-connect.
- `ServerCore::runLuaFunction` keeps a dirty Lua stack after a C++ exception; restart to clear.
- `getPlayerByName` returns offline (cached) players too; check `PlayerObject(ghost):isOnline()`.
- Accounts: `password = SHA256(DBSecret .. password .. salt)` hex, `salt` = 32 hex chars, `station_id`
  any uint32. `DBSecret` = `Core3.DBSecret` in `config-local.lua`. `swg account create` does this.
- `~/bin/build` passes `-DENABLE_BUILD_CLIENT=OFF` then your `CMAKE_ARGS`; the last `-D` wins.
- Incremental rebuild ≈ 3.5 min (ccache warm, 24 threads). Client-only change ≈ 1 min.
- Phase 0.3 backups already exist: cron `0 3 * * * ~/bin/swg-backup-daily.sh` → `~/backups/daily`
  (7-day retention, source in `/mnt/c/SWGDev/phase0/`). WSL cron only fires while the distro is up, so
  it last ran 2026-09-03; `swg start` runs the script when the newest dump is >24 h old. Don't add a
  second backup mechanism.

## Git / workflow
- Claude's auto-mode classifier refuses, regardless of what Chuck says in chat: `git merge` into
  `unstable`, `git submodule update`, `git push`, writing `.claude/settings.json` ("self-modification"),
  and `swg account create --reset` on a real account ("secret-store write"). The fix is an allow-list
  in `.claude/settings.json` (see CLAUDE.md "Permissions") which only Chuck can create. Until then
  Claude works on `feature/*`; engine3 can be moved by `git -C MMOCoreORB/utils/engine3 checkout <sha>`
  after a fetch.
- `git stash drop` and `git merge` into a *feature* branch are fine.
- Upstream (`swgemu/unstable`) merges so far have never touched a Final Boss file; check with
  `comm -12 <(git diff --name-only HEAD...swgemu/unstable | sort) <(git diff --name-only stable-20260523 HEAD | sort)`.
- `fb_lab_tests.lua` discovers NPCs from the filesystem (`io.popen("ls …")` works in Core3's Lua):
  one mobile file + one `<name>_conv.lua` + a screenplay that spawns it is all a new NPC needs to be
  covered. The hard-coded `knownNpcs` list is only the popen fallback.
- `MMOCoreORB/.gitignore` has an upstream `*test*` rule: any file with "test" in its name is silently
  ignored (`git status` never shows it). `fb_lab_tests.lua` is whitelisted with a `!` line; do the same
  for any new test file, or name it without "test".
- Never commit: `conf/config-local.lua*`, `~/.env`, `~/.my.cnf`, `~/.swg-lab/`, anything with the
  MySQL password or `DBSecret`. The guide in `docs/` had the password redacted before it went in.

## Session log
- **2026-10-16 (evening)** — Test infrastructure: core3client gained command/radial/converse/wait
  actions and decodes command results, conversations and string-id messages; `fb_lab_tests.lua` grew
  an oracle/stage-hand API (ham, inflict, heal, wound, give, skill, travel, npc, findItem…);
  `swg test scenario`, `swg build`, `swg logs --lua`; first scenarios: stimpack-heals-health,
  npc-conversation; nightly MySQL backup script. Found the starter-stimpack medicineUse problem.
- **2026-10-16 (later)** — Phase 2.x NPC batch merged into `feature/test-lab` (12 new Mos Eisley NPCs
  given combat stats for the unit test), lab tests made discovery-based, stash dropped, Chuck's
  accounts re-hashed (by Chuck), permissions allow-list handed to Chuck.
- **2026-10-16** — Lab set up: CLAUDE.md, docs/, `tools/swg`, test accounts, upstream merge (14
  commits) on `feature/test-lab`, baseline snapshot, 258/258 unit tests, 41/41 Lua content checks, bot
  smoke test. Phase 2.x uncommitted work parked on `feature/phase2-mos-eisley-npcs`.
