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

## Server / lab
- Boot ~45 s to `READY`; clean `shutdown` ~80 s. Start under gdb (`~/bin/gdb_settings`) so crashes
  leave a backtrace in `bin/gdb.log`; `swg stop` quits gdb afterwards.
- Known noise on every boot: `[MantisDatabase0] ERROR - 1045` + `[Console] ERROR - 1045` (Mantis
  integration, not ours). `swg logs --errors` filters them.
- `decreaseOnlineCharCount missing account N in onlineZoneClientMap` ERROR appears when a client drops
  before its scene finished loading. Harmless.
- `ServerCore::runLuaFunction` keeps a dirty Lua stack after a C++ exception; restart to clear.
- `getPlayerByName` returns offline (cached) players too; check `PlayerObject(ghost):isOnline()`.
- Accounts: `password = SHA256(DBSecret .. password .. salt)` hex, `salt` = 32 hex chars, `station_id`
  any uint32. `DBSecret` = `Core3.DBSecret` in `config-local.lua`. `swg account create` does this.
- `~/bin/build` passes `-DENABLE_BUILD_CLIENT=OFF` then your `CMAKE_ARGS`; the last `-D` wins.
- Incremental rebuild ≈ 3.5 min (ccache warm, 24 threads). Client-only change ≈ 1 min.

## Git / workflow
- Claude's tooling is not allowed to merge into `unstable`, run `git submodule update`, or push.
  Claude works on `feature/*`; Chuck merges/pushes. Engine3 can be moved by
  `git -C MMOCoreORB/utils/engine3 checkout <sha>` after a fetch.
- Upstream (`swgemu/unstable`) merges so far have never touched a Final Boss file; check with
  `comm -12 <(git diff --name-only HEAD...swgemu/unstable | sort) <(git diff --name-only stable-20260523 HEAD | sort)`.
- `MMOCoreORB/.gitignore` has an upstream `*test*` rule: any file with "test" in its name is silently
  ignored (`git status` never shows it). `fb_lab_tests.lua` is whitelisted with a `!` line; do the same
  for any new test file, or name it without "test".
- Never commit: `conf/config-local.lua*`, `~/.env`, `~/.my.cnf`, `~/.swg-lab/`, anything with the
  MySQL password or `DBSecret`. The guide in `docs/` had the password redacted before it went in.

## Session log
- **2026-10-16** — Lab set up: CLAUDE.md, docs/, `tools/swg`, test accounts, upstream merge (14
  commits) on `feature/test-lab`, baseline snapshot, 258/258 unit tests, 41/41 Lua content checks, bot
  smoke test. Phase 2.x uncommitted work parked on `feature/phase2-mos-eisley-npcs`.
