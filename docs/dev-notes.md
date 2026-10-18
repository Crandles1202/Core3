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

### Overriding an upstream object template from custom_scripts
Object templates (`bin/scripts/object/**`) are globals in the TemplateManager Lua state, created in
include order; `object/serverobjects.lua` includes `../custom_scripts/object/serverobjects.lua` last.
`ObjectTemplates:addTemplate(tbl, iff)` ends in `templateCRCMap->put(crc, obj)`, which silently replaces
an existing entry (the "duplicate template" error is commented out upstream). So a custom file can take
the existing global, change a field and re-register it — no upstream file touched, no merge conflicts.
Phase 1.9 does this for 15 stimpack templates (`fb_stimpack_mind.lua`): `attributes = {0, 3, 6}` makes
`HealDamageCommand` heal mind as well, and the examine window shows "heals mind" automatically. Needs a
restart; `reloadscreenplays` does not touch templates. Pet stimpacks and crafted `medpack_damage_*`
already listed mind upstream. Mind is also the *cost* of `/healdamage` (50, focus-adjusted), so healing
yourself now refunds part of it — fine for solo play.

### Wrapping an upstream Lua function so it survives `reloadscreenplays`
`reloadscreenplays` re-runs every screenplay file into the existing state, so a Lua-defined function
you wrapped (e.g. `PlayerTriggers.playerLoggedIn`) is *put back* by its own file before your custom file
runs again. A "wrapped already" flag then leaves it unwrapped — exactly what happened to the Phase 1.5
login hook on its first scenario run (`swg test lua` reloads before every run). Guard by identity instead:
`if Target.fn ~= Mine._wrapper then local up = Target.fn; Mine._wrapper = function(...) up(...) … end;
Target.fn = Mine._wrapper end`. C-registered functions (`spawnMobile`) are not redefined by a reload, so
a flag is fine for those.

### Screenplay state does not travel between Lua states
`FbX.someField = …` set in `start()` lives only in the thread state that ran `start()`; a later call
from the console (`runLuaFunction`) or from a server event may run in a different state and see nil.
Persist with `setQuestStatus(key, value)` / `getQuestStatus(key)` (strings; keys without `:`), as
`FbTravelingMerchant` does for its stop, visit counter and live NPC id.

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
- **Allow-list rules match the whole command string.** `Bash(git merge *)` allows `git merge …` but
  not `cd x && git merge …` or `git switch … && git merge …`. Run one allow-listed command per Bash
  call; chain only unprivileged steps. Settings are read at session start, so a freshly created
  `.claude/settings.json` does nothing until Claude Code restarts. Even then the classifier still
  refused (2026-10-16): `git remote set-url`, `git push --delete <branch>`, `git checkout -- <file>`
  on a config file, and a `grep -F "$secret"` over tracked files ("credential materialization").
- **`skip-worktree` files.** `git ls-files -v | grep ^S` lists them; `git status` hides their changes.
  `bin/scripts/managers/resource_manager_spawns.lua` is *written by the server* (`ResourceSpawner`
  dumps resource spawns into it, +23k lines) — upstream's own docker firstboot marks it
  assume-unchanged. Keep the flag; never commit it. `bin/conf/config.lua` also carried the flag with
  the real `DBSecret` pasted in (May setup); removed 2026-10-16 and the file restored to the upstream
  default, because `config-local.lua` is parsed *after* `config.lua` and sets `Core3.DBSecret` to the
  same value (`ConfigManager::getDBSecret` reads `Core3.DBSecret`). One place for the secret, no
  hidden local edits that a `git stash`/`checkout` could clobber.
- **Branch first, then edit.** The 3.8 cantina work was started on `unstable` straight after a merge and
  had to be moved onto a branch with `git switch -c` before committing (uncommitted changes travel
  with the switch, so it is recoverable, but it is the wrong order). First command of every item:
  `git switch -c feature/<name>`.
- **Scripted doc edits need a diff check.** A Python rewrite of the CLAUDE.md status block duplicated
  ~90 lines (two copies of the shipped table, gotchas, permissions, status) and the 2.2 merge carried
  it. The tell was `CLAUDE.md | 97 +++` in a merge that should have touched a few lines. Before
  committing, eyeball `git diff --stat` and `grep -c '^## '` on CLAUDE.md (each header once).
- **Name filter.** `scripts/managers/name/name_manager.lua` holds regexes (DEV/GM/CSR/QA/profanity…)
  that `PlayerManager::checkPlayerName` runs *before* the one-per-hour rate limit, so a declined name
  costs nothing. Random letter soup gets declined (`Labvartgm` → `name_declined_developer`); the bot
  now builds `Lab` + three consonant-vowel syllables and retries up to 3 times on `name_declined_*`.

## Session log
- **2026-10-18 — Phase 4 design + 4.0 TRE tooling.** Chuck settled the Phase 4 design (recorded at the top
  of the roadmap's Phase 4 section: Village optional, hidden attunement score with capped sources and
  Force-ghost clues, FRS rank trees as the ladder with quest promotions, Masters in the Yavin 4
  enclaves, colour crystals cosmetic, bounty never shrinks but a fixer sells it off). Prerequisite
  shipped: `tools/tre`, a stdlib-only Python packer for `.tre` archives and `.stf` string tables, fed
  from `tre-src/`, producing `MMOCoreORB/bin/tre/finalboss.tre` (ignored). Formats were taken from the
  server's own readers (`src/tre3/TreeFile.cpp`, `templates/string/StringFile.cpp`) and confirmed
  against the stock archives: record checksum = engine3 `String::hashCode` (CRC-32, poly 0x04C11DB7,
  MSB-first) of the path, records sorted by that CRC, md5 over the stored (compressed) bytes, zlib
  type 2; `tre roundtrip` repacks `patch_14_00.tre` byte-for-byte identical (a few SOE records carry
  md5s that match nothing, the client evidently does not check them). Server precedence: the **first**
  archive in `Core3.TreFiles` wins (`TreeDirectory` is a no-duplicate sorted vector), so
  `finalboss.tre` is listed first in `config.lua` and `Core3.TreManager.LatestTre` names it (the
  upstream `ConfigManagerTest.TreFiles` asserts the two agree). The server caches every `string/en`
  table in the ODB `strings` database at first boot and only re-reads with the `reloadstrings`
  argument (or `Core3.TreManager.ReloadStrings`); `swg start` now builds + installs the archive and
  adds `reloadstrings` when its hash changed since the last start (`~/.swg-lab/last-tre.sha`);
  `swg test unit` builds + installs too. Chuck's client folders on Windows all have 53 stock TREs and
  a `swgemu_live.cfg` with `searchTree_NN_prio=` lines; `tre install --client DIR` copies the archive
  there and inserts `searchTree_00_<max>=finalboss.tre` + bumps `maxSearchPriority` once. Chuck's live
  client is `/mnt/c/EMU/swg - Copy/SWGEmu` (login cfg → 127.0.0.1, `user.cfg` admin unlock, character
  list); `/mnt/c/SWGDev/SWG_Game/swg - Copy/SWGEmu` is a never-launched earlier copy (nova.swgemu.com),
  his to delete. The first real `--client` install hit a bug in the cfg patcher: `bytes.join` over `str`
  lines raised *after* the cfg had been opened for writing, leaving a 0-byte `swgemu_live.cfg` (restored
  from the `.finalboss.bak` it had just written). Lesson: build the whole payload first, write to a
  `.tmp` and `os.replace` it, and never ship a file-rewriting path without a test — `tre patchcfg FILE`
  now exists so the `tre-strings` scenario exercises the patch on a CRLF fixture (insert, bump, CRLF
  kept, idempotent), and `tre status` reports whether the client cfg lists the archive. First real client
  login since May: hung at "Connecting to the Login Server" because `.wslconfig` had gone back to
  `networkingMode=nat` (2026-06-15) and WSL2 NAT does not forward UDP from Windows `127.0.0.1` into the VM
  (the lab bot, running inside WSL, never notices). Diagnostic: `ss -ulnp` shows core3 on 44453 and
  the log has no login line for the account. Fix: `networkingMode=mirrored` + `wsl --shutdown` (server
  stopped cleanly first). After that Chuck logged in as Banta and the client rendered
  `@fb_lab:probe_first` as text — 4.0 verified end to end. First starport play-test: Chuck could not find
  the HoloNet relay or the three travellers; the vendors (2.2, 2.3, 2.6, 2.7) all worked. Built the
  **NPC placement toolkit** he asked for (`feature/lab-npc-placement`): the lab's `spawnMobile` wrapper now
  records every spawn made from an `fb_*` file (via `debug.getinfo` on the caller chain, so stock templates
  such as the ambient patrons count too) with its spawn position; `placement[:filter]` spawns a probe
  object 3 m away in 8 directions and asks `AiAgent:checkLineOfSight` (a binding that already existed),
  compares z with the terrain outdoors and measures drift from the spawn spot (walker files exempt);
  `findNpc`, `gotoNpc` (teleports a character 2 m in front of the NPC, same cell, facing it) and
  `waypointTo` (datapad waypoint via `PlayerObject:addWaypoint`). `checkPlacement` runs it in `runAll`
  (boxed-in = ≤1/8, underground/floating = >3 m fail). Findings on the live world: the Restuss (Rori)
  FB-21 droid sat at world (29, 0) 84 m underground because its `cellID` 4635789 does not exist (stock
  `rori_restuss.lua` puts the medic trainers in 4635728 — fixed in the spawn table and the travel menu);
  the starport travellers had wandered 20–30 m (stock commoner AI) — now `AI_STATIC` like the cantina
  entertainers, seats moved onto the plaza; the starport relay at (3540, −4816) measured 8/8 clear yet
  no player found it behind the vendor-row plinth — moved to (3530, −4809). Lesson: the server's
  collision knows buildings, not every decorative world mesh, so the audit is a floor, not a proof;
  `gotoNpc` + eyes is the last step for any new NPC. Gotcha: `goto` is a Lua keyword (hence `gotoNpc`);
  the `lab` scenario helper only passes `INFO`/`ERROR` lines, so verdicts go on the INFO line.
  **Crash and rescue:** the first `gotoNpc` call segfaulted the server — `SceneObject:faceObject(obj,
  notifyClient)` takes two arguments and the binding reads them from the top of the stack, so a
  one-argument call hands it a null target (the Lua bindings do not validate; a wrong arity is a
  crash, not an error). gdb's SIGSEGV catchpoint froze the process with Chuck in game. Rescue that
  worked instead of a kill: in the tmux pane `frame 1` (the void `faceObject` implementation, nothing
  locked yet), `return`, `y`, `continue` — the server carried on, the Lua call even returned ok, and a
  clean `shutdown` followed; Chuck's client had timed out in the 90 s freeze. `swg status` now reports
  "HALTED IN GDB" (process state `t`), `swg stop` kills such a process from gdb instead of typing
  `shutdown` into a dead console, and both copy `bin/gdb.log` to `~/.swg-lab/crashes/`. `swg stop`'s
  crash-marker check made the next `test all` stop after the clean shutdown — intended; archive the
  log and rerun. Second pass of the audit (after the restart, now with `src=` populated): Mos Eisley
  cantina seat 3 at cell-local (−1.0, 12.6) was 0/8 for every patron that sat there — inside the wall;
  three probe patrons (`spawnNpcAt:patron:tatooine:x:y:1082877:-0.9` + `placement:<oid>`) found
  (16, 10) clear 8/8 and the seat moved there. Lua-state lesson again: seat churn and relay respawns run
  on worker threads, whose copy of `FbLabTests.spawns` the console never sees, so `liveSpawns` also asks
  the modules' quest-status lookups (`FbAmbientLife:seatMobile`, `FbHoloNet:relay`) — add a provider
  there for any module that respawns after `start()`. `placement:<oid>` audits any object, recorded or
  not. Lab probes carry `src="lab"`, are skipped by the `spawned` check and forgotten by `destroyObject`.
  Remaining WARNs (3/8 in the weapon-shop and droid-shop cells, two FB-21 droids in tight medcenters,
  Tamsin Rook with her back to the plinth) are tight rooms, not bugs; Chuck used all of them. The merge
  gate then failed three `news_posted` checks although the lines were in the pool: a day of test runs
  had grown the galaxy news to 66 dated entries (every convoy/storm/invasion posts under an
  `os.time()` key, one-week TTL) — bad for players (patrons repeat sixty stale headlines) and heavy for
  the console. `FbGalaxyChatter.addNews` now refreshes an entry whose text is already there, drops
  expired keys and keeps only the newest `maxNews = 8`; the scenario `lab` helper retries once when the
  `result=` line never arrived (the console runs commands on the main thread, so a delta save or a busy
  world can push the reply past the 8 s capture window). Tests: gtest `FbTreTest` (first in list, lab table parses
  with first/middle/last keys, stock `jedi_spam` still resolves), Lua `checkTreStrings` through
  `getStringId`, oracle `stringId:<file>:<key>`. Lesson: gtest `<<` cannot print engine3 `String`;
  use `.toCharArray()`. Two lab fixes found by the full cycle: (1) `claude-player` hit the galaxy's
  10-characters-per-account cap (bot characters accumulate), so `swg account prune <user> [--keep N]`
  now moves the oldest `Lab*` characters into `deleted_characters` and drops them from `characters`
  (the login server's own DeleteCharacter SQL; the zone server purges the objects later), and
  `swg test bot` runs it at the cap; (2) the lab's `<npc>.spawned` check failed after the
  traveling-merchant scenario moved Ozlo in the same server run (old spawn record gone). Rule now:
  the newest spawn record of a template must be alive; older gone records are reported as INFO
  `retired_spawns`.
- **2026-10-17 — Phase 3.4.** `fb_territory.lua` is a plain module (no `ScreenPlay:new`, no `start()`),
  included first among the living-galaxy files so the others can call it; every reader guards with
  `if FbTerritory ~= nil` so the files still load alone. State is quest status with table defaults, so
  a fresh server starts from the designed map and `territorySet` resets it. Patrol squad size comes
  from `FbTerritory.squadFor(route)` at respawn only (live squads keep their size until they die).
  Scenario `territory` drives both crossings and checks patrols, HoloNet voice, chatter and the
  client's broadcast; `convoy-ambush` now also asserts the −10.
- **2026-10-17 — Phase 3.1.** Bestine invasions (`fb_invasions.lua`): construction → combat → resolve
  with a persistent server event, two squads (`setFollowObject` followers), `DAMAGERECEIVED` observers
  on both sides to remember which side each player fought for, rewards via faction standing + cash,
  a per-city `FbTerritory.<city>` Imperial % in quest status. **Lesson: an AiAgent leashes back to
  its home location** (`AiAgent::FOLLOWING` → `leash()` when out of `MAX_OOS_RANGE` of home without
  line of sight; `PATHING_HOME` otherwise), so NPCs sent or teleported far from where they spawned walk
  straight back — which looked like "opposing-faction NPCs do not fight each other". They do
  (`isAggressive`: `targetIsAgent → true`) once in awareness range: with `AiAgent:setHomeLocation(x, z, y, nil)`
  set to the plaza, seven Rebels and six stormtroopers were all fighting within 25 s. Any screenplay
  that moves an NPC more than ~100 m must move its home too (the convoy and patrols get away with
  shorter legs). `setDefender`/`addDefender` (Lua-bound) still pair off stragglers. Lab:
  `teleportObject:<oid>:<planet>:<x>:<y>` (any scene object, `switchZone`, re-homes agents),
  `objectPos:<oid>`, `invasion*` oracles. Scenario `invasion-bestine`. Rebel troopers (level 15) were
  wiped by stormtroopers (25) in 30 s; the column is commandos now.
- **2026-10-17 — Phase 3.9.** Weather plumbing: each zone's `PlanetManager` owns a `WeatherManager`
  that rolls a base weather 0–4 (`createNewWeatherPattern`, stability-weighted, storms last
  `duration/(weather+1)`) plus a `WeatherMap` of local variation; `sendWeatherTo(player)` runs from
  `PlayerObjectImplementation::doRecovery` every 3 s, so a forced base weather reaches clients at once,
  and with `hasDamagingSandstorms` an EXTREMESTORM blinds and damages the unsheltered (`sandstormDamage`
  minus one per covering piece, config in `scripts/managers/weather_manager.lua`, read by the manager's
  own Lua state). `changeWeather()` (the `/weather` command) *disables* the automatic pattern first;
  added `forceWeather()` + Lua `getZoneWeather`/`setZoneWeather` that keep it running. First `.idl`
  edit of the project (a getter and a native): `swg build` took 16 s with a warm ccache — only the weather
  and director units recompiled, so a small `.idl` change is not the multi-minute hit feared. The lab's
  `npc:<template>` finder only knows `fb_*` spawns (it reads the `spawnMobile` wrapper's records), so
  scenarios assert stock-template spawns through the feature's own status line. The core3client now decodes
  `ServerWeatherMessage` (`Weather id=N` log line, `Weather/id` var). `FbWeatherEvents` polls the sky
  each minute; heavy/extreme → three Tusken parties spawn on the outskirts and walk toward the city
  (`setNextPosition` + followers), warning + news; clear → withdraw. Scenario `sandstorm`.
  Time-of-day (the other half of 3.3) has no server-side notion beyond `Zone::getGalacticTime()`
  (seconds since zone start) — the client derives day/night from it, so a day-length constant would
  have to be reverse-engineered first.
- **2026-10-17 — Phase 3.11 (ambush mode).** Convoys (`fb_convoys.lua`) reuse the patrol walk (leader
  `setNextPosition` legs + `DESTINATIONREACHED`, followers `setFollowObject`). Combat hooks: a
  `DAMAGERECEIVED` observer on every guard (callback `(pVictim, pAttacker, damage)`) records player
  attackers in quest status and arms a one-shot reinforcement spawn; an `OBJECTDESTRUCTION` observer
  (callback gets only the victim) checks whether any guard is still alive and, if not, schedules
  `defeat()` a second later (so the last death finishes first). Defeat spawns
  `object/tangible/container/loot/loot_crate.iff` with `createLoot` rolls, pays each attacker through
  `PlayerObject:increaseFactionStanding("rebel", n)` / `decreaseFactionStanding("imperial", n)` and
  `CreatureObject:addCashCredits`, posts a galaxy news line and broadcasts. Lab: `killNpc:<char>:<oid>`
  deals a lethal `inflictDamage` *from the character* so observers credit them; `factionStanding`,
  `containerItems`, `convoy`, `convoySpawn`. Scenario `convoy-ambush` runs the whole ambush.
- **2026-10-17 — Phase 3.10.** HoloNet relays (`fb_holonet.lua` + relay mobile/conv). A segment is
  assembled at read time from the live systems — story ticker title and mobs ("this week's wanted"),
  a galaxy chatter line, the merchant's stop — framed by sting / propaganda / outro, and read one line
  every 3 s with `createEvent(delay, "FbHoloNet", "onLine", pRelay, line)` (the event carries the text
  as its string argument). Broadcasts only while `getPlayersInRange(25)` is non-empty. Every `fb_*`
  mobile needs a conversation template or the discovery-based content checks fail, so the relay got
  a two-screen one whose "replay" option triggers a broadcast. Scenario `holonet`: relay up, segment
  ≥ 5 lines with "Top story:", client receives every line as spatial chat from the relay, replay via
  conversation. Lesson: `NpcConversationStartCommand` requires the player's *last validated position*
  to be in the same cell as the NPC, within 5 m (2-D outdoors), **and** `CollisionManager::
  checkLineOfSight`; it fails silently (no packet back). The relay's first spot (3512, -4790) was 3 m
  from the character and still unreachable — geometry in between. Rule of thumb for new NPC spots:
  stand next to an existing FB vendor row, and make the scenario converse before trusting the spot.
- **2026-10-17 — Phase 3.2.** Faction patrols (`fb_faction_patrols.lua`), built on the stock city
  patrol loop: the leader gets `AiAgent:setNextPosition(x, z, y, cell)` for the next point, a
  `DESTINATIONREACHED` observer schedules the next leg after a dwell, and a 3-minute safety `onStep`
  covers a leader that never arrives; members `setFollowObject(leader)`. Squad oids and the current
  point live in quest status (`FbFactionPatrols.<key>.leader/.members/.point`); a dead or missing
  leader makes the next step respawn the whole squad. The Imperial route reuses the city file's
  `cll8_1` points (known walkable); the Rebel route is open desert with `getTerrainHeightAt`. Stock
  `stormtrooper*` / `rebel_*` templates are `ATTACKABLE` with a faction, so they engage declared
  enemies only. Level-aware squads (roadmap) are a follow-up. Scenario `faction-patrols`: squad alive,
  forced step with the character nearby (AI sleeps without players), leader moved ≥ 5 m in 20 s.
- **2026-10-17 — Phase 3.5.** Story ticker (`fb_story_ticker.lua`): a persistent weekly server
  event cycles through a story table; `fire(idx)` posts the story's lines through
  `FbGalaxyChatter.addNews` (7-day TTL), broadcasts one line with `broadcastToGalaxy(pCreature, text)`
  (needs a creature as sender — the first story mob is used) and camps the story's mobs at a spot
  outside town (terrain height via `getTerrainHeightAt`). Mobs are spawned with respawn 0 and an hourly
  `createEvent` refill replaces the dead ones, because AiAgent respawn timers would resurrect a story
  we have moved past and there is no Lua binding to clear them. Spawn records are `oid=template`
  pairs in quest status so a restart (which drops `spawnMobile` NPCs) can respawn the current story in
  `start()`. Scenario `story-ticker`: fire the next story with the bot online (mobs alive, news in the
  pool, broadcast received), fire another (previous mobs gone via the new `objectAlive` oracle).
- **2026-10-17 — Phase 3.6.** Galaxy chatter as a module (`fb_galaxy_chatter.lua`, included before
  `fb_ambient_life.lua`): `lines()` = 10 static news lines + live facts (merchant's current stop label
  via `FbTravelingMerchant:currentStop()`, Bestine election phase, each wrapped in `pcall`) + dated
  news posted with `addNews(key, line, ttl)` into quest status (`FbGalaxyChatter.news.<key>` =
  `<expires>|<line>`, key list in `FbGalaxyChatter.newsKeys`; expired entries are skipped). The 3.5
  story ticker will call `addNews`. `FbAmbientLife.tick` spends `galaxyShare` (35 %) of spoken beats on
  it and returns `galaxy:<text>`. Also added an outdoor ambient location (starport travellers: seats
  without `z` get `getTerrainHeightAt`, cell 0). Scenario `galaxy-chatter` posts a bulletin, listens
  to beats until a galaxy line is heard, confirms the client received it, then expires the bulletin.
- **2026-10-17 — Phase 3.7 (first location).** Ambient cantina life. Finding first: stock Core3's city
  screenplays (`screenplays/cities/tatooine_mos_eisley.lua`, base `cities/city.lua`) already seat ~40
  patrons with moods (`npc_sitting_chair`, `npc_standing_drinking`, "conversation", …) in the Mos Eisley
  cantina (cells 1082876/1082877), so 3.7 adds behaviour, not bodies: `FbAmbientLife` spawns five extra
  patrons (stock `patron*` creature templates, random moods) and runs two in-memory `createEvent` loops
  per location — a beat every 25–45 s (spatial chatter 65 % / emote otherwise, a newcomer line when a
  player id is seen for the first time since the last beat) and a churn every 5–10 min (one seat's
  patron despawns and a different face sits down). Beats are quiet when `getPlayersInRange(20)` is empty
  for every seat, so an empty server stays silent. Seat oids live in quest status
  (`FbAmbientLife.<key>.seatN`) because the event callbacks run in whichever Lua state picks them up.
  `createEvent(ms, play, callback, pObject, args)` accepts `nil` for the object. Lab: `travelCell` oracle
  (`switchZone` with a cell id), `ambient`/`ambientTick`/`ambientChurn`, and the client now decodes
  `SpatialChat` (ObjController 0xF4: long sender, long target, unicode text, …) so a scenario can prove a
  spoken line reached a player. Scenario `ambient-cantina`. Then 3.8 as data: Bestine (stock cell
  1528397, floor z 0.4, found by grouping the city file's seated-mood spawns by cell) and Coronet (cell
  8105496 from its `-- Cantina` block) got their own patron mixes and lines. Theed's city file spawns
  nothing seated in its cantina, so its cell is unknown — left out until someone reads it off the
  client. `ambient-locations.manual.sh` audits every location (seats, quiet when empty, alive when a
  player is at the anchor).
- **2026-10-17 — Phase 1.11 (loot half).** `CreatureManagerImplementation::droidHarvest…/notifyDestruction`
  kill-loot site: after the normal `createLoot`, a grouped killer gets a second `createLoot` roll with
  probability `Core3.Loot.GroupBonusChance` % (default 25), logged as its own `NPCLOOT` transaction with
  state `fbGroupLootBonus`. Chosen over scaling `lootChance` because `createLootFromCollection` has no
  caller-supplied multiplier and LootManager is IDL-managed (changing its signatures regenerates code).
  **Not lab-verified:** a grouped kill needs two characters, group invite/join packets and combat in the
  bot — the next lab milestone if group play matters to Chuck. Statistical by nature; set the chance to
  100 in `config-local.lua` to see it every kill.
- **2026-10-17 — Phase 2.9.** Traveling merchant. Lua only: a screenplay with a stop table (city
  centres from `managers/planet/*_regions.lua`, z from `getTerrainHeight`), a 34-item cosmetic pool and
  a deterministic rotating stock (`stockFor(visit)` = 8 consecutive pool entries from `visit*5 mod n`).
  Persistence: `createServerEvent(ms, "FbTravelingMerchant", "onMoveEvent", "FbMerchantMove")` is the
  3-hour timer (survives restarts; `hasServerEvent` guards re-creation, `rescheduleServerEvent` after a
  forced move) and the current stop / visit counter live in the global quest-status store
  (`setQuestStatus("FbTravelingMerchant:stop", …)`). `spawnMobile` NPCs are not persisted, so `start()`
  respawns him at the stored stop after every restart and `move()` despawns with
  `destroyObjectFromWorld(true)`. Scenario `traveling-merchant`: oracle finds him, bot travels, buys
  through the real conversation + stock window, oracle forces a move and checks exactly one merchant,
  a different stop, a different stock. City-centre coordinates are a guess at "open ground"; Chuck's
  checklist asks him to confirm Ozlo is not inside a wall at each stop. Four lessons from getting it
  green: (1) **`getTerrainHeight(pCreature, x, y)` takes a creature**, not a zone name — passing a
  string returned 0 and the merchant spawned underground, where the conversation greeting still
  worked but option picks got no reply. Added `getTerrainHeightAt(zoneName, x, y)` (DirectorManager,
  C++). (2) **Screenplay tables are per Lua state**: `self.merchantOid` set by `start()` in the main
  state was nil in the console state that ran `move()`, so nothing despawned. Anything a later call
  needs goes into the quest-status store (`setQuestStatus`/`getQuestStatus`). (3) Quest-status keys
  must not contain `:` if the lab is ever to touch them — `runLuaFunction` splits arguments on `:`
  (keys are now `FbTravelingMerchant.stop/.visit/.oid`; oracle `questStatus:<key>[:<value>]`). (4) A
  `destroyObjectFromWorld` object still resolves through `getSceneObject` for a while; the `npc` oracle
  now skips objects whose `getZoneName()` is empty. (5) The lab's own `travel` oracle had the same
  height bug as (1): `getTerrainHeight(pPlayer, …)` uses the character's *current* zone, so a
  cross-planet teleport put the character at the wrong height and conversation option picks silently
  failed (the greeting, a 2-D range check, still worked). Fixed with `getTerrainHeightAt(planet, …)`.
  Stop audit (`merchant-stops.manual.sh`, places him at every stop and runs a two-screen
  conversation): 9 of 10 candidate city centres reachable; Anchorhead's (102, -5360) was not and is
  not in the table.
- **2026-10-17 — Lab: server UI (SUI) windows.** The bot now reads `SuiCreatePageMessage`
  (0xD44B7259, opcount 2, zlib-compressed — the engine inflates it): int pageId, ascii root
  (`Script.listBox`, `Script.inputBox`…), int commandCount, then commands as (byte type, int wideCount,
  unicode…, int narrowCount, ascii…). Type 3 = setProperty (wide value; narrow widget, property):
  `bg.caption.lblTitle/Text` is the title, `Prompt.lblPrompt/Text` the prompt, `List.dataList.N/Text`
  the rows. Type 5 = subscribeToEvent (narrow parent, one-byte event type, callback): OK = 0x09,
  Cancel = 0x0A, and for Lua page boxes the *index of that command* is the `eventIndex` the reply must
  carry (legacy C++ boxes: 0 / 1). Reply `SuiEventNotification` 0x092D3564: int pageId, int eventIndex,
  int listSize1, int listSize2, unicode args (a list box wants the row index as text, an input box the
  typed text). `--sui "<row text>" --sui-match "<title fragment>"` picks the newest unanswered window
  whose root/title/prompt contains the fragment and the first row containing the text. Findings: (1)
  lab characters are shadowed by the new-player helper droid, which opens a greeting list box *every
  second*, so "answer the latest window" was wrong; the handler keeps an ordered list of all pages and
  the action scans newest-first with the match filter. (2) My earlier "keep the first failure's exit
  code" guard compared against 0, but `exit_result` starts at 1, so for a few commits a failed action
  exited 0 — scenarios' `client_exit_0` checks were vacuous during that window; fixed (`< 100`).
  Scenario `schematic-broker-ui` buys a Throw Pillow through conversation → catalogue window → item
  window, the way a player does.
- **2026-10-17 — Phase 2.10.** Vendor maintenance auto-skim, C++ in `doInstantBuy`: for a sale on a
  player vendor (not `item->isOnBazaar()`), `skim = price * Core3.Vendor.SaleMaintenancePercent / 100`
  (default 5) goes into `VendorDataComponent::addMaintenanceCredits` (new one-liner next to `getMaint`),
  the seller banks the rest, logged as a `VENDORMAINTANENCE` transaction grouped with the sale. Bids on
  auction-style listings (`doAuctionBid`) are not touched. **Not lab-verified:** placing a vendor needs
  a structure the character owns plus two SUI windows (`/createvendor` → type list → name box), and the
  bot cannot drive SUI yet. Bot SUI support (parse SuiCreatePageMessage 0xD44B7259, answer with
  SuiEventNotification 0x092D3564) is the next lab upgrade worth doing — it would also let the NPC
  vendor scenarios buy through the real UI instead of the public `purchase()` helpers.
- **2026-10-17 — Lab: auction packets.** `core3client` gained `--sell <item> <vendor> <price>`
  (CreateImmediateAuctionMessage 0x1E9CE308: long item, long vendor, int price, int duration, unicode
  description, byte premium), `--buy <item> <price>` (BidAuctionMessage 0x91125453: long, int, int;
  instant-sale items go through `doInstantBuy` whatever the prices) and `--retrieve <item> <vendor>`
  (RetrieveAuctionItemMessage 0x12B0D449: long, long). Replies are three (long oid, int status) packets
  with opcount 3: ItemSoldMessage 0x0E61CC92, BidAuctionResponseMessage 0x8FCBEF4A,
  RetrieveAuctionItemResponseMessage 0x9499EF8C; status codes in the server's headers (13 =
  TOOMANYITEMS, 12 = FULLINVENTORY, 0x100 = TOOFAR). Three lab lessons: (1) the client var store is a
  JSON pointer tree — a path segment that is a bare number (`Auction/sold/2814749…`) makes nlohmann
  create an *array* and throw inside the packet task ("unreported exception caught while running a
  task", no reply ever arrives); prefix such segments (`o2814749…`, `c101`). (2) Until today the client
  only dumped the *pre-run plan* (`#N {...}` with default status ok), so `bot_action_status` had been
  reading the plan, not the outcome; the client now prints `=> #N {...}` results after the run and
  `lib.sh` reads those (`bot_action_status`, `bot_action_count`). (3) `--keep-going` lets a session
  run every action even after a failure (exit code still reports the first failure), which is what a
  "list 26 items, count the rejections" scenario needs. Scenario `bazaar-listings` spawns a bazaar
  terminal, lists 26 loaves, checks fee and inventory, then retrieves and destroys them so the
  character's listing count stays flat. Listings left on a destroyed lab terminal are
  dropped by `doAuctionMaint` ("missing vendor") at the next server start.
- **2026-10-17 — Phase 2.3.** Component vendor. Components spawned bare from an object template
  would have no crafting values, so the dealer generates them through the loot system: Lua
  `createLoot(pInventory, "<component_loot item>", level, false)` — `LootManager::createLoot` accepts a
  loot *item* name as well as a group name (`lootGroupMap->lootItemExists`) and rolls the item's
  `craftingValues` at that level. 27 standard items under `scripts/loot/items/component_loot/` each
  have an `_advanced` twin; the dealer sells 23 of them in both tiers (standard = level 30, advanced =
  level 60 at 3× price), skipping the exotic Kashyyykian/Zam segments. Scenario `parts-dealer` buys one
  of each tier through the public `purchase()` (oracle `buyPart`) and counts the components.
- **2026-10-17 — Phase 2.2.** Schematic broker NPC, built on Chuck's vendor pattern
  (`fb_smuggler_goods`: screenplay with a data table + SUI list boxes, conv template with a
  `do_<thing>` screen the handler turns into a SUI, mobile template, three include lines). "Starter and
  intermediate schematics" = the 85 `object/tangible/loot/loot_schematic/*` items minus the master-tier
  sets; using one calls `PlayerObject::addRewardedSchematic(..., SchematicList::LOOT, useCount)` — no
  profession needed (`LootSchematicMenuComponent`). Lab: the bot cannot drive SUI windows, so the
  scenario buys through the public `FbSchematicBroker:purchase()` via the oracle (`buySchematic`), then
  the bot *uses* the datapad with a real radial (id **50**, "Learn Schematic" — not ITEM_USE) and the
  oracle confirms `hasSchematic`. New oracle helpers: `cash`, `buySchematic`, `hasSchematic`. The
  content checks found the NPC by themselves (filesystem discovery), ~10 new checks.
  Findings: (1) every loot schematic template has a `requiredSkill` enforced at learn time — the
  cantina chair wants `crafting_artisan_master`, 17 of the first 50 picks wanted nothing — but those 17 are *stubs* (no `targetDraftSchematic`, 38 such files upstream) that would "learn" nothing, so they were dropped; 33 items remain. The
  catalogue carries a `skill` field generated from the templates, the SUI labels it, and `purchase()`
  refuses with `no_skill` instead of taking credits. (2) The client did not decode the
  `@loot_schematic:not_enough_skill` reply (`ChatSystemMessage type=0 len=0`): a StringId message
  shape the `handleChatSystemMessage` decoder does not handle yet. To-do; scenarios assert through
  the oracle instead.
- **2026-10-17 — Phase 2.5.** Bazaar listing count/time. The limits are `final static int` constants in
  `AuctionManager.idl` (`MAXSALES` 25, `COMMODITYEXPIREPERIOD` 7 d, `VENDOREXPIREPERIOD` 30 d). Changing
  the IDL regenerates code and recompiles everything that includes it, so instead the ~20 use sites in
  `AuctionManagerImplementation.cpp` now call file-local helpers that read `Core3.Auction.*` from the
  config (defaults 100 / 1 y / 1 y). `ConfigManager::getInt` does *not* register unknown keys, so
  `dumpcfg` won't list them unless set in `config-local.lua`. Verified later the same day by
  scenario `bazaar-listings` once the bot learned auction packets: 26 listings accepted in one
  session (stock would reject the 26th with ItemSoldMessage status 13), 20 cr fee each.
- **2026-10-17 — Phase 1.10.** No-grind entertainer. `EntertainingSessionImplementation::
  awardEntertainerExperience` runs every 10 s (`EntertainingSessionTask`); stock pays
  `(flourishXp + baseXp) × (1 + audience/50 + applause/100 + 0.05/grouped entertainer)` but only when
  `flourishXp > 0`, i.e. the player flourished during that tick (max 1 counted per tick for dance, 2 for
  music). First attempt (pay `baseXp` every tick) awarded nothing: a debug line showed `baseXp=0` for
  the basic dance — the datatable's baseXp is 0 for performances, stock XP is flourishes only. Shipped
  rule: a tick without a flourish pays `flourishXpMod` once (dance caps at 1 flourish/tick anyway, so
  idle dancing = flourishing dancing; music caps at 2, so idle music = half rate), and the audience
  modifier is floored at 0.5 (a solo performer = 25 watchers). Healing XP (`entertainer_healing`) still
  needs patrons; nothing to heal solo. Performance values come from the TRE datatable
  (`PerformanceManager::loadPerformances`), not Lua. Scenario `entertainer-xp`: grant
  `social_entertainer_novice`, `--command startdance --args basic`, wait 25 s with no flourish, read
  dance XP through the new oracle `xp:<char>:<type>`. Two bot lessons: (1) `startdance`/`stopdance`
  (and other non-queued commands) never produce a `CommandQueueRemove`, so `--command` timed out —
  added `--command-nowait` (send, sleep 0.5 s, success; the server's verdict is still visible as a
  system message such as `@performance:dance_start_self`); (2) `ClientCore` skips every remaining
  action after one fails, so a failed command silently shortened the session to ~10 s.
- **2026-10-17 — Phase 1.4.** Mission terminals show level + direction. Mission title/description are
  StringIds the client resolves from its own STFs, so no free text there; the one free-text field the
  client shows per mission is the creator name (`MissionObjectMessage3` unicode). A static helper in
  `MissionManagerImplementation.cpp` (no IDL change) appends `[Lvl N - 1.4km NE]` (ASCII only: the creator name is a byte-per-char unicode string, UTF-8 renders as junk) after
  `populateMissionList` randomizes the bag: N = `getDifficultyLevel()` (lair level for destroy, 5 for
  deliver), distance/compass from the player's position to the mission start position (Core3: +y north,
  +x east), planet name when it differs. Re-randomized missions get the bracket replaced, not stacked.
  Test plumbing: `core3client --missions <terminalOid>` sends ObjController `0xF5`
  (`MissionListRequestCallback`: int, byte flags, byte seq, long terminal). ObjController wire rule:
  `ObjectControllerMessageCallback::parse` consumes priority, type, objid only; every callback's own
  `parse()` starts with the "size" int. One extra int shifted the terminal id into garbage and the
  server answered `@skill_teacher:skill_terminal_disabled` (its "terminal not found" message); Lua `LuaMissionObject`
  gained read getters; oracle `spawnObjectNear` / `destroyObject` / `missions`. Scenario
  `mission-hints` spawns a general terminal next to the character (terminals in the world have no
  Lua lookup by template), requests the list, asserts every mission carries `[Lvl N` and at least
  half carry distance+compass. Side finding: once a character has randomized missions in the bag,
  every login logs `[TemplateManager] ERROR - unknown appearance type SPRT` (upstream, harmless: no
  sprite appearance reader). Added to `NOISE_RE` in `tools/swg`.
- **2026-10-17 — Phase 1.5.** Inventory 80 → 100. `containerVolumeLimit` is persisted per object and
  only read from the template when the inventory is created, so two halves: template re-registered in
  `custom_scripts/object/tangible/inventory/fb_inventory_100.lua` (new characters) and a login hook
  (`fb_player_login.lua` wraps `PlayerTriggers:playerLoggedIn`, which `PlayerObjectImplementation::
  notifyOnline` calls in the DirectorManager Lua state) that raises older inventories. Needed a one-line
  C++ addition: `LuaSceneObject::setContainerVolumeLimit`. The client is never told the limit (not in any
  baseline), so its "/80" counter is cosmetic; Chuck to confirm the client lets a 90th item drop in.
  Scenario `inventory-100` reads the limit through the oracle after a login.
- **2026-10-17 — Phase 1.9.** Stimpacks heal mind. Turned out to be a template field, not C++:
  `attributes = {0, 3, 6}` re-registered for 15 player stimpack templates from
  `custom_scripts/object/tangible/medicine/fb_stimpack_mind.lua`. New scenario `stimpack-heals`
  (control round measures regen: +54 per pool in a 4 s session on a fresh character; stimpack round
  then showed "You heal yourself for 104 health, 104 action, and 104 mind damage"). Replaced the
  health-only scenario. `swg test lua` now runs `reloadscreenplays` first so test-file edits apply
  without a restart. Lesson: sandbox loaders must also stub `_G` (`env._G = env`) when the loaded
  file indexes `_G[name]` directly.
- **2026-10-16 (night) → 10-17** — `.claude/settings.json` allow-list created by Chuck and committed.
  `feature/test-lab` merged `--no-ff` into `unstable` (`fa635eaa38`) and pushed; all five merged local
  `feature/*` branches deleted. `Chuckertons` (15) and `chuck` (0) re-hashed under the custom DBSecret
  (passwords in `~/.swg-lab/`). Snapshot `post-phase2` taken (700 MB). Housekeeping: four May
  `conf/*.backup-*` files removed, `config.lua` skip-worktree edit undone (secret lives only in
  `config-local.lua`), resource spawns file left skip-worktree on purpose. `swg test all` after the
  merge: 258 unit, 173 Lua, 2 scenarios PASS; bot FAIL on a filtered random name → CV-syllable names +
  retry. Still Chuck's: delete `origin/feature/qol-starter-gear`, `git remote set-url origin` to the
  capitalised URL GitHub now reports, Windows Task Scheduler backup.
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
