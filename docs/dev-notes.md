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
- The seat serves every driver on its own engine3 `Thread` (2026-10-21): a `std::thread` cannot hold engine3 locks
  (see CLAUDE.md gotchas). Requests other than `wait` are serialized by one lock; `quit` shuts the other drivers'
  sockets and joins them. A `--seat` path must fit `sun_path` (107 bytes; the scratchpad is too deep — use `~/.swg-lab`).

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
- **2026-10-21 (morning) — the seat serves several drivers.** Teyla's re-seated pilot made every other `seat`
  command time out: the seat served one driver connection at a time and a pilot keeps its connection for life, spending
  most of it in 30 s `wait` calls (seen as `Zone::waitFor` on the seat thread in a `sudo gdb -p` backtrace — plain gdb
  gets `ptrace: Operation not permitted`, yama scope 1). Now a thread per driver: `wait` blocks only on the zone's
  condition, everything else runs under one lock, `quit` shuts the other drivers' sockets and joins. Also: the pilot's
  log is line-buffered (a redirected stdout showed nothing for minutes), `seat prune` and `seat start` delete the
  state directories scenario seats leave behind (106 of them this morning), and the NetStatusRequest exception the
  trials lane flagged is engine3 on both sides (CLAUDE.md known noise).
  **Citizens between tells:** `tools/citizens/crew up|down|status|log` runs any set of citizens (seat + pilot in the
  background, pids under `~/.swg-lab/citizens/<name>/`). Teyla's first idle wake on the new rules still chose `rest`:
  in town there is nothing to hunt and the plan said only "Master Rifleman" — so persona files now carry a
  `## Playbook` (Teyla: the flats east of Mos Eisley; Wex: the gatherer's round and how to open a site), the
  perception carries `xp` (lab `progress:<char>`: amount/cap per XP type) so a citizen can tell whether its work pays,
  and the pilot logs the model's text (`{"text": …}` in log.jsonl) so a wake can be read afterwards.
  **First real walks (14:00):** Teyla set off for the flats (535 m) and Wex for a steel spot (1.5 km), both logged
  "timed out": the seat's walk blocks until arrival but the driver's socket timeout was 120 s, and the late reply was
  then read as the answer to the *next* request ("no self in view"). Now `Seat.request` drops replies whose id is not
  the request's, `walk_seat` waits length/speed + 60 s, `sample` 30 s per round, and the seat answers `ping`/`quit`
  outside the action lock so a seat can be stopped mid-walk. `citizen outfit` gave Wex three ore deeds and 6000 wind;
  Teyla already carried a CDEF rifle (equipped now). Lock lesson: the bench copy of `tools/swg` locks as "bench" and
  the worktree's tools are then refused as "alice" — the pilot's lab calls failed silently all morning.
- **2026-10-21 (small hours) — Teyla's first wakes, the cast online, fighting on a seat.** Chuck's Console key arrived
  (`sk-ant-usr-…` works with the SDK; stored in `~/.env`, read by the pilot). First live `/tell` exchange: she answered
  in character but opened with her own name; the perception now carries `you` and `now` (first open milestone) and
  the rules say answer the sender by name. Haiku 5.5 cost per wake: ~3.3k cached prefix once, ~1k input + ~50 output
  per round. **Bench/seat lessons:** a `swg build` or `bench use` by another lane restarts the server and drops every
  seat (coordinate before deploys; the trials lane and I now message each other); `pkill -f "<pattern>"` matched my
  own shell; a stopped pilot's seat died of SIGPIPE on the reply write (ignored now). **Cast:** eleven citizens created
  in four minutes with `citizen new`; Wookiees may not have a surname (`name_declined_racially_inappropriate`,
  NameManager species rules 0/0) — Brakk is "Brakk". All veteran skill names were checked against
  `string/en/skl_n.stf` (1481 keys, in `/tre/patch_12_00.tre` and others) before creation. **Combat on a seat:**
  `attack` once starts combat; a player repeating `defaultattack` gets INVALIDLOCOMOTION (error 2 in the
  CommandQueueRemove) — repeat `attack` instead; unarmed the server wants the target within ~5 m
  (`max(10, weapon range)` is the check, `@error_message:target_out_of_range` otherwise); a womp rat is level 10 and
  took a fresh character to a tenth of its health in 20 s, a kreetle is level 1–3; `loot all` on the corpse sends no
  CommandQueueRemove at all; equipping from Lua is `transferObject(item, 4, true)` with the hand freed first.
  **A gate failed on the weather:** a natural heavy sandstorm was on at the gate's start (`weather.event_matches_sky`
  saw weather=3 before the 3.9 event's tick), the storm's Tusken raiders camp on the Mos Eisley outskirts where
  scenarios park their characters, the gate's character died (every command came back `error=1 state=20`:
  locomotion 20 = DEAD) and ten scenarios failed in a row. `swg test all` and `lib.sh` now clear Tatooine's sky first
  (`weatherSet:tatooine:0`, the automatic pattern stays). Also: `trap - EXIT` before `finish` skips a scenario's
  cleanup on the happy path — call `cleanup` explicitly (seat-fight left a level-10 womp rat at the shared desert
  spot until the next restart).
- **2026-10-20 (night) — 7.6a travel on a seat.** Chuck: "get started on the seats", key to follow. Built the trip:
  ticket terminal → `purchaseTicket` → shuttle → `boardShuttle` → the new scene. **Where the terminals are:** not
  in the `.ws` snapshot (`lotsurvey near` finds none) — they are `childObjects` of the port building's Lua template,
  spawned with it; a starport's four stand inside the building (cell 4), a shuttleport's one outdoors. Hence
  `getObjectsInRange(zone, x, y, range[, type])` (zone tree + every building's cell contents, world and cell-local
  positions) and `findPath(zone, x1, y1, x2, y2[, cell1, cell2])` returning `{x, z, y, cell}` rows: the
  pathfinder's world→cell path puts the door node on both sides, so the client's walk makes one short step across
  the space change and sends `DataTransformWithParent` (0xF1: parent oid right after moveCount, position
  cell-local) inside. **Zone switch on the bot client:** `switchZone` destroys the character from the old world and
  `sendToOwner` sends a second `CmdStartScene` (same planet too); the client never reset anything, so it now counts
  scenes (`Scene/count`, `Scene/terrain|x|y`, `Scene/readyCount` from the server's `CmdSceneReady`) and clears its
  object map on a re-scene (`ObjectManager::clear`). `board` polls those vars instead of `waitFor` (the packet can
  land before a waiter registers — same lesson as CommandQueueRemove). The shuttle's "ready to board in N minutes and
  M seconds" is parsed and slept through. **Python runtime:** Debian 12 ships no pip/ensurepip; `apt-get install
  python3-venv python3-pip` (sudo is passwordless here), venv at `~/.swg-lab/venv` with `anthropic` 1.17.0; the pilot
  re-execs itself there when the system python lacks the SDK — compare `sys.prefix` with the venv dir, **not**
  `realpath(sys.executable)` (the venv's python is a symlink to the system one, so that compared equal). The key is
  read from `~/.env` when the environment has none. Scenario `seat-travel`: Mos Eisley Shuttleport → Bestine
  Shuttleport (outdoor terminal), then Bestine Starport → Mos Eisley Starport (indoor terminal, cell walk).
  **Harvesters** followed in the same session: the seat places from a deed, lists what the spot offers (0xEA), selects,
  pays maintenance and deposits power through the real transfer boxes (radial 129/51; `sui` learned `values`, the
  server reads the second argument as the amount — `StructurePayMaintenanceSuiCallback`, `InsertPowerSuiCallback`),
  activates and empties the hopper (0xED). The installation's hopper/surplus state only reaches a client as baseline 7,
  so the lab's `getStructureStatus` binding is the citizens' status window. Scenario `seat-harvester` (the lab fills the
  hopper with `harvesterAddToHopper` instead of waiting hours; `structureDestroy` = `destroyBuilding` cleans up).
  **Bench lessons from getting both scenarios green:** (1) every object the bot client held was type 0 and nameless —
  the client-side Lua templates only carry `clientTemplateFileName` ("data below here is deprecated and loaded from the
  tres"); the fix is a server dump of its template table (`dumpTemplates` → `~/.swg-lab/templates.jsonl`, 15 926 lines,
  2.5 MB) that `core3client` reads at start — and `createObject` leaked one Lua stack slot per object (the result table was
  never popped). (2) `getObjectsInRange` crashed twice: `getCell(idx)` is a VectorMap keyed by cell number (1..N), and
  `getCellName()` wants the number, not the oid (an oid as an index → ArrayIndexOutOfBounds). (3) The AI navmesh does not
  cover a port's pad: `findPath` to the terminal or shuttle stops at the mesh edge ~29 m short; players are not bound by
  the mesh, so the seat walks a straight final leg (the server only speed-checks). (4) `purchaseTicket` and
  `boardShuttle` send no `CommandQueueRemove` at all — the ticket action waits for the ticket object, the board action for
  the new scene. A scenario run right after a server restart twice saw the purchase vanish without any reply while every
  later manual run worked; not reproduced since, watch the gate. (5) `EmptyHopper` 0xED: the server's callback skips 12
  bytes after the header oid (int pad + player oid) before harvester/resource/quantity. (6) `placeStructure` said
  `not_permitted` 600 m east of Mos Eisley: the no-build region is huge; `isBuildingPermittedAt` is now a binding
  (`canBuild`). (7) A lab-made harvester deed has extraction rate 0 and hopper size 0 (crafting sets them:
  `updateCraftingValues`), so the placed harvester would never fill: `deedValues` sets them. (8) `addResourceToHopper`
  appends; the hopper already holds an empty container for the active resource, and `EmptyHopper` takes the first
  container for the spawn — top that one up instead. (9) The bench build (`swg build`) builds the *bench* checkout, not
  the worktree: uncommitted worktree changes need a commit + `bench use`; and copying a file onto the bench to test it
  leaves the bench dirty, which `bench use` refuses (restore it with `git checkout --` there). (10) **The bot client's
  packet dispatcher switches on the opcount first** (the short before the opcode): a new `case` must sit in the branch
  for its packet's opcount (`UpdateTransformMessage` is `insertShort(0x08)` → `case 8:`); under the wrong opcount it
  never runs and nothing says so. Others' movement is decoded now (`Moves/count`); the seat-daemon scenario sends a
  spawned stormtrooper walking (lab `walkNpc` = `setNextPosition`) to prove it, since `moveNpc`/`teleportObject`
  re-create the object instead of moving it.
- **2026-10-20 (evening) — 7.6a resources: oracle, survey, sample.** Chuck: crafters cannot sit in one town, resources
  are elsewhere. What the code says is in `docs/Game-Systems.md`. Built: `getResourceSpawns(zone)` /
  `getResourceDensityAt` Lua bindings (the citizens' spreadsheet: every spawn in shift with attributes and up to
  three best spots — a 256 m scan of the simplex concentration map refined to 32 m; ~4k noise reads per spawn, ms),
  lab `resources:<planet>[:<class>]` / `resourceDensity`, seat `survey` / `sample` / `resources`. **Survey on the
  wire:** radial 20 on the survey tool → `ResourceListForSurveyMessage` (opcount 4, 0x8A64B1D5: int n, n × (ascii
  name, long oid, ascii type), ascii toolType, long player) — or first the range window (`@survey:select_range`,
  rows "64m x 3pts" … "384m x 5pts" by skill; after answering, use the tool again) → command `requestsurvey
  <resource name>` → `SurveyMessage` (opcount 2, 0x877F79AC: int n, n × (x, 0, y, pct)). **Sample:** command
  `requestcoresample <name>` → `@survey:sample_located` (DI units) after 3 s, then the server re-samples every 25 s
  on its own until the player moves / fights / cancels; `@survey:trace_amount`, `sample_failed`,
  `density_below_threshold` are the other verdicts. **String-id system messages** (`ChatSystemMessage(StringIdChatParameter&)`):
  byte type, int 0 (empty unicode), int size, then `ChatParameter::insertToMessage` writes a **short** (odd-length pad
  flag), **byte 1** (TYPE_STRINGID), **int** STRINGID, and only then `addToPacketStream` (ascii file, int, ascii id,
  TU/TT/TO as long + ascii + int + ascii + unicode, int DI, float DF, byte) — the bot read one byte where three fields
  stood, so every `@file:id` message had arrived empty since the lab was built; fixed with 7.6a. **New characters** land
  in `characters_dirty` and reach `characters` (which the login server lists) only at the next ODB commit — console
  `save` forces it; and they wake in the tutorial zone (`FbAttunement: Teyla settled at tutorial`), so `citizen new`
  sends them home with the lab's `travel`. Yield ≈ density × 25–28 × surveying/100 per sample, so a
  fresh artisan (surveying 10) gets single digits; the scenario grants `crafting_artisan_survey_04`. Untested on
  the bench yet (held by the trials agent for hours; `SWG_WAIT` gives up after an hour and the lock is renewed).
- **2026-10-20 — Phase 7 planned, 7.0 seat daemon.** Chuck's ask: a galaxy that feels alive, and AI "players"
  (real accounts) he can group, trade and talk with. Plan written into the roadmap (Phase 3.13–3.18 galaxy-wide
  life, Phase 7 Citizens: seat / autopilot / playbooks / pilot / cast), cast of ten drafted in
  `docs/Citizens-Cast.md`. **Subscription vs API:** the docs say Pro/Max OAuth is for ordinary individual use of
  Claude Code and automated agents must use an API key, but a Max plan includes monthly API credits ($100 / $200)
  that cover the API and the Agent SDK — link a Console org under claude.ai Settings → Billing, cap a workspace.
  **7.0 the seat:** `core3client --seat <unix socket>` is just another action in the chain (after the auto-inserted
  login / zone-in, before the auto-appended logout): it serves JSON lines — `action` runs any registered action from
  its JSON form through `ActionManager::fromJSON`, `vars` dumps the var store under the packet handler's lock,
  `objects` walks the ObjectMap, `wait` blocks on `Zone::waitFor(hash)`. New actions `say` (`spatialchatinternal`
  with `"<target> <chatType> <mood> <flags> <language> <text>"`), `tell` (a `ChatInstantMessageToCharacter` packet:
  ascii SWG, galaxy, name, unicode text, int 0, int sequence; the verdict comes back as `ChatOnSendInstantMessage`
  opcount 3 / 0x88DBB381: int result, int seq — 0 delivered, 4 no such player, 5 offline, 6 ignored) and `emote`
  (`socialinternal` `"<target> <id> 1 1"`). **Emote ids** are the 1-based row numbers of
  `datatables/chat/social_types.iff` (the newest copy is in `patch_11_02.tre`; 382 rows, DTII with two string
  columns, the second always empty) — `tools/seat_emotes.json` is generated from it; a guessed table was wrong
  (wave is 364). The client never set positions on created objects (`SceneCreateObjectByCrc` carries x,z,y; now
  `initializePosition`); others' movement (`UpdateTransformMessage`) is still not decoded, that is 7.2.
  **Worktrees have no engine3 submodule** (`MMOCoreORB/utils/engine3` is empty in `Core3-alice`), so a local build
  is impossible; a syntax check works by taking the compile command for a sibling file from the bench's
  `build/unix/ninja-debug/compile_commands.json`, rewriting the `-I…/Core3/MMOCoreORB/src` paths to the worktree and
  running `clang++ … -fsyntax-only` on the new file (the engine3 headers come from the bench). **Name filter:** the
  canon/profanity regexes in `managers/name/name_manager.lua` can be run from Python (`re`, case-insensitive) to
  vet names before character creation; some patterns are broad (anything with a `k` + vowel, words starting with
  `p`), so pick names that match none. Scenario `seat-daemon` covers the channel end to end.
  **Lab run lessons (same day):** (1) `tools/tre` resolved `TrePath` from its own checkout's conf — a worktree has no
  `config-local.lua`, so `swg start` from a worktree tried to install the archive into the upstream default path;
  it now reads the bench's conf. (2) The client's `ObjectManager::registerObjectTypes()` has every typed class
  commented out, so `createObject` returned null for everything and the ObjectMap stayed empty; a plain
  `SceneObject` is created instead now. (3) `spatialchatinternal` and `socialinternal` never get a
  `CommandQueueRemove`: only an explicit rejection counts. (4) **Movement:** the server flags a player as
  *teleporting* at character select and after every `teleport()` and silently drops every `DataTransform` until a
  `TeleportAck` (ObjController 0x13F, int counter) arrives — the real client sends one after loading; the bot now
  acks on `CmdSceneReady` and on every server move. (5) **Client→server ObjController payloads have no pad int
  after the oid**: `ObjectControllerMessageCallback::parse` reads priority, type, oid and hands the rest to the
  sub-callback. The server's *outbound* `ObjectControllerMessage` carries an extra int, and `CommandQueueEnqueue`'s
  parser happens to read one as "size", which is why the command action got away with it — the walk's transform
  arrived shifted by four bytes (timestamp 0, speed = y) and was dropped as "deltaTime". `#define TRANSFORM_DEBUG`
  in `packets/object/transform/Transform.h` prints the server's verdict per packet (`DT ---- …` in the console
  log); worth a temporary build when movement is silently ignored. (6) Movement rules that hold now: ≥ 200 ms
  between packets and ≥ 400 ms unless speed/yaw change, average speed ≤ run speed × 1.05 measured against the last
  fully validated position (one per second), posture upright/sitting/prone ok. 60 m at 4.5 m/s = 34 packets in
  16 s, server position exact. (7) `seat-walk` and `pilot-dry` pass; `pilot-dry` proves the loop, files and the
  seat round trip without a model.
- **2026-10-20 — 4a.3 the Padawan trials.** Engine: a data table of eight trials and one `tick` that the
  attunement trigger calls; a trial starts with "word from the old man" and completes through whichever
  channel fits it (a 5 s position poll inside a shrine, a 10 s outdoors poll that combat resets, the kill hook,
  a conversation, a shrine entry, an observer on the duel opponent). The visitors reuse the Village `Encounter`
  recipe from 4a.1/4a.2 with the same two fixes (declare `isEncounterFinished`, stop the follow before
  despawning). `awardSkill(pPlayer, name)` is the global the Village itself uses for the novice box; it skips
  prerequisites. The duel opponent is chosen by `CreatureObject:getLevel()` at spawn (the Sith Shadow tiers
  17 / 32 / 51 / 69). The riddle's right option differs per riddle so a client cannot always pick the first;
  the lab reads the chosen riddle from the state and answers accordingly.
  Three visitor bugs found by the riddle step, each only visible across a client logout: (1) the Village
  `Encounter` base schedules its despawn with the *player* as the event key, so the ten-minute timer of an
  earlier visit of the same task (the Old Man's first, a previous spirit) despawns whatever visitor stands
  when it fires — every visit now writes a generation number (`<oid>:fbVisitGen:<task>`), stamps it into
  its despawn events, and `handleDespawnEvent` ignores any other or unstamped stamp (the per-object sweep in
  `recordVisitor` is the backstop); (2) a following agent whose target logs out leashes back to its spawn
  point (`CLAUDE.md` gotcha) — once in range a visitor stops following, goes `AI_STATIC` and is re-homed where
  it stands; (3) a follower's own z still carries its spawn height when it arrives, so the new home uses
  `getTerrainHeightAt`, or the visitor snaps 16 m underground and no conversation can start. The Padawan box
  is awarded on its own event (the last trial completes inside a kill observer) **after** `PlayerObject:setJediState(1)`:
  without the Jedi state the skill manager refuses every `force_*` skill silently (a brawler box awards, the
  novice box does not) — the Village sets the state the same way just before its own award.
- **2026-10-20 — 4a.2 the shrines.** First feature built the parallel way: worktree `Core3-shrines`, branch
  `feature/shrines`, `swg bench use feature/shrines` to test. Content: 49 lore lines (five per world, four where a
  world has four shrines), keyed by shrine index so a shrine always says the same thing; the Old Man's return
  reuses the 4a.1 NPC and conversation with `return_*` screens (the handler picks the screen by which encounter
  owns the NPC); the ambush reuses the stock `sith_shadow_outlaw` and the stock recipe (follow, then
  `addDefender` + a threaten line in range). Kill credit: `OBJECTDESTRUCTION` on each shadow gives the killer as
  the argument, which is a pet or the lab as often as the player, so each shadow carries `<oid>:fbAmbushFor`
  (writeData) naming the player it was sent for. The lab's lore check reads `../../tre-src/…` relative to
  `bin/`, i.e. the bench's source tree — fine while the bench is deployed at the commit under test.
  Worktree traps found by running the whole gate from one: `tools/tre` read the server config (and so the
  TrePath) from the worktree, where the git-ignored `config-local.lua` does not exist; the site-preview
  scenario and the planner wrote `tasks/sites/.preview/preview.lua` into the worktree while the server reads
  the bench. Rule of thumb now in every tool: **source** (strings, scenarios, site files to commit) comes from
  the checkout the tool runs in; **runtime** (config, console log, client binary, files the server reads at
  runtime) comes from the bench.
- **2026-10-20 — 0.7 working in parallel.** Design: the thing agents fight over is not the code (git worktrees
  solve that for free) but the *one* server with its one ODB, console and lab accounts — so the main checkout
  becomes "the bench" nobody edits, every agent gets `~/workspace/Core3-<name>` on `feature/<name>` with its
  identity in a git-ignored `.swg-agent`, and `tools/swg` wraps every server-touching command in a lock
  (`~/.swg-lab/server.lock`: agent|purpose|pid|since|until; automatic locks die with their process, holds expire).
  `swg bench use <branch>` checks the bench out detached at that commit and picks reload / restart / build from
  what changed against the last built and last running commits (`bench.built`, `bench.running`); `swg test all`
  appends a green commit to `gate.passed`; `swg bench merge` refuses without it. Nested `swg` calls from a
  scenario pass through because they carry the same agent name. First trap found at once: a worktree's
  wrapper must still point `BIN` (console log, client binary) at the bench, since only the bench has a
  server — `BIN` is now derived from `git worktree list`, in `tools/swg` and `scenarios/lib.sh` alike. Second:
  agents must be created *after* the tooling is on `unstable`, or their worktree carries the old wrapper.
  Claude's memory directory is per checkout path, so shared knowledge lives in the repo docs (CLAUDE.md,
  BOARD.md, dev-notes), never only in memory.
- **2026-10-20 — 4a.1 Force attunement.** What the stock code offers and what had to be added: badges are
  Lua globals named by their datatable key (`datatables/badge/badge_map.iff`: `poi_heromark` is the Mark of
  the Hero, `bdg_thm_park_*` the four theme parks, `warren_*`, `bdg_corvette_*`, `exp_*` the exploration
  badges, every `*_master` the profession masters; `getBadgeListByType("master")` lists the latter); stock
  `force_shrine` regions resolve with `getRegion(planet, name)` and take an `ENTEREDAREA` observer like any
  active area (handler gets `(pArea, pCreature)`; the shrine is found again by position, so nothing has to be
  remembered across Lua states); `KILLEDCREATURE` is notified on the killer (and group) with the victim as
  the argument; `OBJECTDESTRUCTION` on a player fires at incapacitation; `/meditate` only sets a creature
  flag (`setMeditateState`, no posture/state Lua could see) → new binding `CreatureObject:isMeditating()`.
  The Village's `Encounter` base (`quest_tasks/encounter.lua`) does the spawn-near-player-and-follow dance
  and refuses buildings and NPC cities, which is exactly the "after a fight, outdoors" rule; its per-player
  started flag lives in `writeData` (in memory), so a visit that never despawns is reset by `maybeVisit`
  when its quest-status stamp is older than 3 min. `/checkForceStatus` stays with `VillageJediManager` (the
  progression type is not changed so the Dathomir village keeps working); we replace that one method after
  load. Mobile templates need `level > 0` or `LuaMobileTemplatesTest` fails — the two new NPCs did not have it.
  Getting the scenario green took eight rounds; the traps, in order: (1) `writeScreenPlayData(pPlayer,
  screenplay, key, value)` — I had folded screenplay and key into one string; the bindings read from the stack
  top, so a missing argument is silent garbage and the score stayed at 0 with no error. (2) Badge keys are
  Lua globals **in upper case** (`POI_HEROMARK`, `BDG_THM_PARK_JABBA_BADGE`). (3) `Encounter:taskStart` treats a
  missing `isEncounterFinished` as *finished* (`callFunctionIfNotNil(nil, true)`) and never spawns, while
  `Task:start` still marks the task started — define it, and only mark a visit sent when `start()` returns
  true. (4) `SpawnMobiles.despawnMobilesInList` hands a mobile that still *follows* someone to
  `HelperFuncs:despawnMobileTask`, which re-schedules itself every 10 s for as long as the follow stands — so
  a follower never despawns: clear `AI_FOLLOW`/`AI_ESCORT` and `setFollowObject(nil)` before despawning
  (five stale spirits stood in the desert before that). (5) The lab's `findNpc` only sees spawns the
  `spawnMobile` wrapper recorded from `fb_*` files; encounter spawns come from `utils/spawn_mobiles.lua`, so
  the visits add themselves to the registry. (6) The bot client cannot `/sit` or `/meditate` as a fresh
  character; `--command sitServer --command-nowait` (the modifier *follows* the command) is the posture
  command and works. (7) Posture persists across logins: a seated character logging in at a shrine is
  credited by the login watch at once — right in game, surprising in a test. (8) Inside the login trigger the
  zone/position are not final: the shrine check runs 6 s later (`loginSettled`). The `isMeditating` state is
  what `/meditate` sets, but since the command is Teras Kasi only, sitting for 10 s inside the shrine counts.
- **2026-10-19 — a blank map, and how to see page errors from here.** Replacing the terrain block "from the
  relief marker up to `function drawMap()`" also swallowed the planet-map function that sat between them;
  `drawMap` then threw `drawMapImage is not defined` inside the async start-up, which `window.onerror` never
  sees — the page looked fine except for an empty map. Now `unhandledrejection` is reported too, both to the
  status line and to `POST /api/clientlog` (printed on the planner's stderr). To reproduce without a desktop:
  `tools/siteplanner serve --port 8766 > log 2>&1 &`, then `firefox-esr --headless --new-instance --profile
  <empty dir> http://127.0.0.1:8766/` for ~45 s (no `--screenshot`: that exits at the load event, before the
  async loads run) and grep the log for `page reports`. Chuck's profile is locked by his own Firefox, hence
  the private profile.
- **2026-10-19 — terrain tiles by zoom.** Chuck asked whether scaling up our own grid beats the painted map: it
  does, because the heights are exact. The relief now loads 128² tiles whose step follows the zoom (1 m when
  close), one console call each, served and cached per tile; the page keeps coarser tiles under finer ones so
  zooming never blanks. Seams were the trap: a percentile ramp per tile recolours each tile differently, and
  bands relative to a tile minimum break at tile edges — so the ramp is one range per planet (re-rendering every
  loaded tile when the range shifts by more than 2 m) and bands use absolute height.
- **2026-10-19 — the real planet map as backdrop.** `texture/ui_map_<planet>.dds` (patch_03.tre, 1024², DXT1, no
  mipmaps) is the texture the in-game map window draws; a 60-line DXT1 decoder + PNG writer in the planner serves it
  (1.2 s once, cached). Orientation: north up, world x → column (x + 8192)/16384, world y → row (8192 − y)/16384 —
  checked by plotting the seven Tatooine cities, which land in the familiar arrangement. I tried to confirm it
  against the server's height grid by correlation and could not: the texture is an artist's overview whose fine
  ridges do not follow the real height field, so expect a backdrop, not a survey (the relief layer is the survey).
- **2026-10-19 — terrain in the planner (2.12f, first half).** Reimplementing the `.trn` terrain generator in
  Python is a project of its own (procedural layers, affectors, filters), so the server does the work: a Lua
  oracle loops `getTerrainHeightAt` over a box and writes the grid to a file — 15 876 points in well under a
  second on the main thread, so the console hitch is invisible. The planner caches each box forever under
  `~/.swg-lab/terrain/`. Rendering is one canvas pixel per grid point (hillshade + bands + slope tint) drawn
  scaled under the map; smoothing on when zoomed out, crisp cells when zoomed in. Percentile ramp because
  the mesas east of Mos Eisley (180 m) would otherwise flatten the town (5 m) into one colour.
- **2026-10-19 — the sandstorm scenario's `client_saw_the_storm` flake, explained.** `WeatherManager::sendWeatherTo`
  computes `map.getWeatherAt(x, y) + baseWeather` and upstream set anything above 4 to **0**. `setZoneWeather(4)`
  therefore showed *clear* to any player standing where the local map was above 0 — the scenario passed only
  when the bot happened to stand on a map cell at 0 (and in game Chuck's "sky goes dark" check could have failed
  the same way). Clamped to 4 instead (one line, `WeatherManagerImplementation.cpp`). The bot log is the
  tell: `Weather id=…` lines without a 4 while `storm` says `weather=4`. Players receive weather on their own
  periodic tick (`PlayerObjectImplementation`, also at login), which is why a forced change takes a few
  seconds to arrive.
- **2026-10-19 — 2.12g, world edits (moving the stock world).** Chuck asked whether the filler blocks could be
  moved or added. They can, because the client and the server read the same `snapshot/<planet>.ws` and our
  archive wins on both sides (`searchTree_00_26=finalboss.tre` in the client cfg, first in `Core3.TreFiles`).
  Format (`tools/worldedit`): `FORM WSNP { FORM 0001 { FORM NODS { FORM NODE { FORM 0000 { DATA(52) , child
  NODEs… } } … } , OTNL } }`; DATA = `oid parent nameid cell | qw qx qy qz | x z y | radius | portal-crc`
  (little-endian, the FORM/chunk sizes big-endian; a FORM size includes its type tag). Server side
  (`PlanetManager::loadSnapshotObject`): `createClientObject(serverTemplate.hashCode(), oid)` with the
  `shared_` prefix stripped, cells attached from child nodes by `cellid`, nothing persisted. Stock oids run
  2…9 995 370 across all planets; adds use 10 000 000 + 64k (db objects start at 2^48). An add is a *clone* of a
  stock instance of the template (radius, portal CRC, cell children) so the client never sees a node shape it
  does not know. Pipeline: planner → `tre-src/world/<planet>.json` → `tre build` (patched `.ws` into the archive
  + Lua twin) → `swg start` installs both copies → `checkWorldEdits` compares the booted server with the twin.
  Proved end to end with a temporary filler block east of the bank (0.00 m off, heading exact), then removed.
  Two bugs found on the way: the form-size gotcha above, and `getDirectionAngle()` is already degrees (the
  check said "heading off by −109°" until the `math.deg` came out — six call sites fixed). Not done: terrain
  pads do not move (baked into the `.trn`), stock NPCs/terminals from city scripts stay put; both are visible
  in the planner so Chuck can judge. Client-side caveat: every player needs the patched archive.
- **2026-10-19 — 2.12d, the planner's game loop.** Design: the planner never talks to the server directly;
  it writes the draft as a real site file into `tasks/sites/.preview/` (a dot-directory, so the boot loader's
  `ls …/sites/*.lua` never sees it; git-ignored) and asks the lab (`swg cmd runLuaFunction FbLabTests:sitePreview:preview`)
  to build it. `FbSites:build` now records every NPC oid it spawns in quest status (`FbSites.<name>.npcs`), which
  is what makes a teardown possible at all — nothing else remembers which stock-looking NPC belongs to which
  site. A preview *replaces* the live site of the same name (so dragging the Trade Hall and previewing shows
  one hall, not two); `previewEnd` rebuilds the boot-time table. The site file is parsed in a sandbox
  (`loadfile(path, "t", env)` with a stub `FbSites.add` that captures the table) so previewing never registers
  anything. Teleport reuses `travel` (3 m outside the door offset). Undo keeps serialized drafts (shell by
  server template name) and takes one entry per drag, at mouse-up; the same snapshot is the autosave.
  Scenario `site-preview` moves the hall 60 m, audits the 12 NPCs by site, ends the preview and checks the
  saved hall is back at its x. Gotcha found while writing it: the planner selftest had the hall's heading
  hard-coded (180); Chuck's relocation turned it to 215 — assert shape, not the current layout.
- **2026-10-19 — Site planner, Chuck's first hands-on round (feedback branch `feature/phase2.12c-planner-fixes`).**
  What a real user found in an hour, in order: double-click only worked on a placed shell (now any
  building opens, read-only for stock); Firefox under WSLg does not deliver `dblclick` reliably (own
  double-click from click timing) nor drop-down popups (every `<select>` is an inline list / button
  row now); the point-in-rectangle test assumed one winding, so rectangles were never "inside"
  (winding-agnostic test, ported to the Lua builder and lotsurvey too); an `id` shared by the place
  dropdown and the Place button made clicking the dropdown place a shell; buttons keep focus so Enter
  re-fired the last one (buttons blur after a click, Enter in the area fields loads); region
  `RECTANGLE`s are two corners, not centre + size (Theed loaded off-centre). Then the asks: stock
  NPCs per building (city files + snapshot cells), snapshot objects inside cells and parented to
  buildings, **server-spawned child objects** from each building template's `childObjects` (travel
  terminals, ticket collectors, the bank's four terminals — these are in no snapshot), a Layers box,
  planet buttons + place list (region tables + travel points), floor levels from room heights, real
  outlines (exterior floor meshes; the **RADR** radar shape in `.lod` files for solid shells —
  IDTL VERT/INDX, 60-byte-free flat triangles — drawn as boundary-edge silhouettes), drag/rotate of
  existing sites with a rotate knob at the entrance arrow, terrain under the footprint via a new
  `terrainHeights` oracle (the planner shells out to `swg cmd`), and clashes against the neighbours'
  real silhouettes with a 3 m gap. First real use: Chuck dragged the Trade Hall to a clear lot the
  circle rule accepted; the lab's `lot_is_flat` then failed (porch end 3.1 m below the centre) and he
  confirmed in game that the hall was not flush — the terrain line in the lot report exists because
  of that. Checker note: my structure check strips strings before comments, so an apostrophe inside a
  `//` comment reports a false mismatch — avoid them in the planner's script comments.
- **2026-10-19 — Windows → WSL TCP loopback does not work on Chuck's PC.** Opening the planner from the
  Windows browser times out (so does the game's TCP status port 44455); the game's UDP passes. Evidence:
  `curl.exe` from Windows (via interop) times out on localhost / 127.0.0.1 / [::1] / the LAN address;
  tcpdump inside WSL on eth0, lo and any sees no SYN; a 127.0.0.1-only bind gets "refused" instead of a
  timeout (so Windows does mirror ports bound on all interfaces, the steered packets just never arrive).
  Tried, each with no effect: Hyper-V firewall `LoopbackEnabled True`, `DefaultInboundAction Allow`, a
  Hyper-V rule for TCP 8765, a Defender inbound rule, `wsl --shutdown` after all of that, and
  `[wsl2] firewall=false` (reverted). No third-party adapter filters. Parked; the workaround is a browser
  inside WSL: `sudo apt-get install firefox-esr`, `tools/siteplanner serve --browser` (WSLg puts the window
  on the Windows desktop). Note for the future: `wsl --shutdown` with the game server running is an
  unclean stop (Chuck did one tonight; the ODB came back with 0 errors, but stop the server first).
- **2026-10-19 — Phase 2.12c site planner (web UI).** Chuck: "a top view of the buildings that I can click
  and drag around, view the layout of the building and show where vendors should go". `tools/siteplanner`
  is a stdlib `ThreadingHTTPServer` serving `tools/siteplanner_ui/index.html` (vanilla JS canvas, no
  dependencies) and JSON built on `tools/lotsurvey`: `/api/area` (snapshot buildings with footprints +
  headings, props), `/api/shells` (147 shells: footprint, rooms with **floor triangles** — the `.flr` TRIS
  chunk is 60-byte records, first three ints are vertex indices; count-prefixed only in version 0006 —
  furniture boxes), `/api/sites` (regex parse of `tasks/sites/*.lua`), `/api/npcs` (fb_ mobiles with
  `customName`), `/api/live` (shells out to `swg cmd … findNpc`), `POST /api/save` (writes the site file,
  refuses to overwrite unless the page loaded that file). The page does the same lot check (footprint
  rectangle vs neighbour circles, +3 m) and furniture clearance as the Lua builder, so the three tools
  agree. First `/api/shells` costs ~15 s (every archive is read once); afterwards it is cached in the
  process. `swg test planner` (`siteplanner selftest`) guards the data path inside `test all`. The page
  is not browser-tested by the lab (no browser here): Chuck's walk-through is the test; `node --check`
  passes on the script.
- **2026-10-18/19 (night) — Phase 2.12b site builder + data-driven sites.** Chuck: "a tool that helps me
  translate where I'd like to put a building, what direction it faces, what vendors are in it and where".
  Pieces: (1) `tools/lotsurvey export` writes `custom_scripts/fb_world_data.lua` (239 stock footprints,
  147 shells with rooms; 200 KB, loaded in every state) and `fb_world_furniture.lua` (12k props, 700 KB,
  `FbWorldData.loadFurniture()` on demand) — the furniture is client-only, this is how the server learns
  it; `.flr` versions 0003/0005 have no vertex count prefix (0006 does), detect by chunk size. (2) A
  C++ Lua binding `SceneObject:getStructuresInRange(range)` (buildings + static shells via
  `Zone::getInRangeObjects(…, includeBuildingObjects=true)`; `isStaticObjectClass()`), so the lot check
  uses the server's own snapshot objects plus the exported footprint radii. (3) `FbSites` loader:
  `tasks/sites/*.lua` (`io.popen("ls")` + `includeFile`) each `FbSites:add {…}`; building by `spawnSceneObject`,
  tenants by cell name, outdoor NPCs; the Trade Hall became the first site file and `FbTradeHall` a
  wrapper (keeper handler and scenarios unchanged). (4) `FbSiteBuilder` (architect mode on the remote):
  draft in quest status (`FbSiteDraft.<oid>.site|tenants|outside`), preview = real building spawned at
  the player's position with a chosen heading, `lotReport` (neighbours' footprint circles vs the
  shell's rotated footprint rectangle, +3 m; terrain corners), `nudge` respawns preview + draft NPCs,
  `addTenant` converts the player's cell-local position + heading and grades it against the furniture
  (`spotReport`, the Python `prop_clearance` ported), `siteText` emits the site file; `swg site save
  <char> <name>` pulls it through `FbLabTests:siteText` into `tasks/sites/`. Gotchas: the game data names
  shells `…/shared_x.iff` but the server spawns `…/x.iff` (`clientForm`/`serverForm`; the first preview
  silently returned nil); the lot check must ignore the draft's own preview; a destroyed building still
  resolves through `getSceneObject` with an empty zone name (test liveness by zone, not by cells);
  player houses have no interior layout, so their furniture verdict is "no data". Scenario
  `site-builder` (23 checks, admin bot via oracles: preview clear in the desert, nudge respawn, tenant from
  inside, outdoor NPC, site text, `swg site save` round trip, the starport apron reported as a clash on
  the square, discard leaves nothing) and a Site builder window in `lab-remote`.
- **2026-10-18 (night) — Phase 2.12a Lab Remote.** Chuck: "is it possible to have in-game commands that
  serve this info up?" A new slash command is out (the client rejects commands missing from its own
  command table unless we ship a patched datatable in the TRE), so the lab became an **item**: the old
  magic-8-ball "field probe" turned into the Lab Remote (`clientTemplateFileName` lets a server template
  borrow a stock client appearance — the camp-remote radio — while binding our `objectMenuComponent`;
  the probe's template path stays registered as an alias so old items keep working). Radial → SUI
  windows (`SuiListBox`/`SuiInputBox`/`SuiMessageBox` from `screenplays/sui/`, callbacks
  `(pPlayer, pSui, eventIndex, args)`, list rows are 0-based in `args`, input text arrives in `args`).
  Two Lua-state lessons made it work: (1) radial and window callbacks run on whichever thread handles
  the packet, so the remote keeps per-player state (the found-NPC list, the picked oid) in quest status,
  not in Lua tables; (2) the per-state `FbLabTests.spawns` registry misses spawns made elsewhere (the
  Trade Hall tenants, seat churn, the merchant's moves — the admin bot's Lua run failed on
  `fb_traveling_merchant.spawned 0/1` for exactly that reason), so the `spawnMobile` wrapper now also
  writes a quest-status registry (`FbLabSpawns.<template>` = `oid|zone|cell|x|y|z|src;` records, pruned
  on read) that `liveSpawns` and `checkNpc` merge in. `FbLabTests.capture(fn, …)` swaps `print` for
  the call so the remote can show what an oracle prints. Admin login hands a remote out
  (`FBLogin.onLogin`); `swg test bot --user claude-admin` creates a privileged bot character and the
  `lab-remote` scenario drives the windows with `--radial <oid> 20` and `--sui <row|text> --sui-match
  <title>`.
- **2026-10-18 (late) — Phase 2.11 Mos Eisley Trade Hall (server-placed building, proof of concept).**
  Chuck asked for a mall to put the vendors in. Facts: cities' buildings come from `snapshot/<planet>.ws`
  (client and server read it), but a building is also just an object — `spawnSceneObject` with a
  building template creates the structure *and* its cells (`DirectorManager::spawnSceneObject`,
  persistence 0, so it is respawned every boot like any stock prop; cell ids change per boot, so the
  screenplay finds rooms by `getCellName`). The client already owns every stock mesh and portal
  layout, so no TRE change was needed. Picked `guild_commerce_tatooine_style_01` (9 cells: foyer,
  halla/b, mainroom, meetinga–e). Chuck's first walk-through found Doctor Yan'lara standing in a dining
  table: **furniture is client-only** — `interiorlayout/shared_guild_commerce_style_tatooine.ilf` (NODE
  chunks: prop template, cell name, 3×4 matrix) places 201 props the server never loads, so LOS probes and
  the placement audit cannot see them. `lotsurvey furniture` lists them with bounding boxes (template
  → `.apt` → `.lod`/`.msh` BOX chunk; items on tables, rugs, paintings and wall gear ignored) and
  `lotsurvey check --lua <screenplay>` grades every tenant spot (inside a box = FAIL, < 0.8 m = warn); it
  found Vex Renn in the mirrored table and Greelo inside the bar counter — at the exact point the stock
  city file spawns its mercenary, so stock spots are not proof either. The `trade-hall` scenario runs the
  check. **Lot survey tooling — now `tools/lotsurvey` (near / cells / footprint / rooms / lots, reads the archives through `tools/tre`; the hall's lot search takes 7 s):**
  a `.ws` reader (WSNP → NODS → NODE/DATA: ids, quaternion, position, little-endian payload, big-endian
  IFF sizes; OTNL name table) listed every building near the square; footprints came from each
  template's `.pob` → `r0 … collision_floor.flr` VERT extents — the starport's apron is x −89..81,
  z ±89 (170 m across!), so every "free" spot east of the square is on it; the nearest lot clearing
  every footprint is 150 m north: origin (3580, −4638), heading 180, porch facing the square. Room
  coordinates: `.flr` per cell gives x range, floor height and z range; cell-local y = mesh z, cell-local
  z = floor height (foyer/halls 2.50, main room back and meeting rooms 1.13) — matched the three stock
  spawns found in the same hall type across Tatooine (Bestine/Anchorhead/Wayfar/Mos Eisley city files,
  cells looked up through the snapshot's child nodes). Tenants: the 11 square vendors (their plaza
  entries commented out in their screenplays), FB-21 and HN-7 stay outside. Doorman "Hallkeeper Jyn
  Odaro" on the square (`addWaypoint` to the doors, tenant list via `setDialogTextTT`); galaxy chatter
  line. Lessons: a conversation template needs the trailing `addConversationTemplate(...)` call or the
  NPC is silent (the lab's `conversation_registered_as_*` check caught it); non-existent mobile
  appearance templates fail only at spawn (`dressed_commoner_tatooine_human_male_01` does not exist —
  ishitib does); `gotoNpc` now tries several spots and keeps the first the NPC has line of sight to
  (2 m "in front" of a shopkeeper behind a counter crosses a wall); the lab's purchase oracles need the
  bot online (buy inside the `bot_bg` window). The bot logs out inside the hall at the end of the
  `trade-hall` scenario, so a later `test all` restart + bot login of that character exercises "my cell
  is gone" (not yet observed: the next cycle's bot created a fresh character instead; watch for it). Scenarios touched:
  `parts-dealer`, `schematic-broker`, `schematic-broker-ui`, `npc-conversation` now `gotoNpc` to the NPC
  instead of walking to plaza coordinates.
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

### 2026-10-21 — the trials gate after the rebase onto alice's merge

- **Visitors stop past the conversation rule.** A following NPC (`AI_FOLLOW`) halts about 5.6–6.4 m from the
  player; `NpcConversationStartCommand` wants ≤ 5 m (2-D, against the player's *last validated position*) and
  line of sight. The Old Man's talk had passed before only by luck of the stop distance. `FbTrials.settleBeside`
  (the 30 s settle of every visit) now moves a visitor farther than 4 m to 2.5 m on the same bearing.
- **`SceneObject:teleport` did not move an AI agent** (probe `zz-oldman`: position unchanged after the call);
  `switchZone(zone, x, z, y, 0)` + `setHomeLocation` does — the same pair the lab's `teleportObject` uses.
- **The shared-wrapper gotcha, again:** `local ps = SceneObject(pPlayer)` kept across `SceneObject(pNpc)` reads
  the NPC. settleBeside measured the visitor against itself (distance 0) for three runs before the probe
  showed it. Take the numbers out first, then wrap the next object.
- A `local function` must be defined *above* the function that calls it, or the call compiles as a nil
  global (`settle … attempt to call a nil value (global 'settleBeside')`); the lab's `visitSettle:<char>`
  runs the settle on demand, and the console state has no `SpawnMobiles` global (`require` it in oracles).
- Scenarios share one character within the hour (the server's one-creation-per-hour rule): a scenario that
  sets the cash (`cashSet`) must put it back, or the purchase scenarios after it fail with `no_credits`.
- `rebase` conflicts in CLAUDE.md / BOARD.md / dev-notes.md between two agents' lanes: keep both sides.
- **Bot client conversation race.** `StartNpcConversation` (0xDD) arrives first, the option list (`StringList`
  0xE0) on its own packet a little later; `ConverseAction` waited a fixed 300 ms and then read 0 options on a
  slow server (`Option 0 out of range (screen has 0)`, intermittent across the gate: riddle, prisoner, sacrifice).
  Worse, the client can process the screen (message + `StringList`) *before* the `StartNpcConversation` packet,
  so a start handler that resets the options wipes a list already received (the first fix did, and every
  conversation then timed out). Now `ConverseAction` clears the conversation state and sets `optionCount = -1`
  before it asks, the start packet only marks the conversation active, and the action waits for the list (or the
  close) and then for the start. Not a server-side recognition failure, which is what three rounds of visitor
  fixes assumed.
- **Jedi manager functions cannot be wrapped from a screenplay.** Every thread's Lua state loads the screenplays
  first and `jedi_manager.lua` + `village_jedi_manager.lua` later (`JediManager::loadConfiguration`, on first use
  in that thread: `[JediManager] Thread N loaded.` in core3.log), so `VillageJediManager.checkForceStatusCommand`
  set in `fb_attunement.lua` was overwritten and the stock `@jedi_spam:fs_progress_1` went out. It had passed in
  earlier gates only because `swg test lua`'s `reloadscreenplays` re-ran the screenplays into states that already
  held the manager. `JediManager.cpp` now runs `custom_scripts/managers/jedi/fb_jedi_hooks.lua` after the stock
  files; Jedi-manager wrappers live there (Phase 4b will add more).
- Bot client sessions log `handleNetStatusRequest … StreamIndexOutOfBoundsException at 8` every 5 s in core3.log
  (not the console): the client's 4-byte NetStatusRequestMessage and the server's handler are both engine3 (the
  submodule), so there is no Core3 fix; known noise (alice, CLAUDE.md).

### 2026-10-21 — 4a.4 visions

- **A private place without instancing:** the `dungeon1` zone is a flat plane at z = 0 (its `.trn` is under 1 KB)
  holding the Corellian Corvette instances at x 1250–2700, y 600–1900 and nothing else; `switchZone("dungeon1",
  x, 0, y, 0)` puts a character there and back. `FbVisions` uses a row of slots at (−1500 + 80·(oid mod 12),
  −1500): dreamers never see each other. `lotsurvey near dungeon1` finds nothing (no snapshot); `objectsNear`
  on the live server is what listed the ships.
- Canon figures with real models in this client: `darth_vader.iff`, `dressed_luke_skywalker.iff`; Obi-Wan uses
  the old Jedi trainer, Exar Kun a dark Jedi. No Yoda, no Emperor (only his Hands and herald).
- A vision holds the shared `FbAttunement.visit.<oid>` slot while it runs so a visitor and a vision never
  overlap; the lab's shortcuts (`attunementAccept`, `trialsUnlock`) mark every vision seen, or the
  attunement / shrines / trials scenarios' trigger order would change under them.
- **`writeData` / `readData` hold numbers only** (uint64): a string written there reads back as 0 without any
  error. The visions' cast went that way and every vision ended at once. Strings go into screenplay data
  (`writeScreenPlayData`) or quest status. An event scheduled with an object pointer (`createEvent(ms, play,
  fn, pObj, "")`) panics the Lua state if the object is gone by then: pass the oid as the string argument and
  `getSceneObject` it — **keyed to a long-lived object such as the player**: `createEvent` with a nil object
  builds a task that never runs (4b.4's spared enemy stayed; the visions' 180 s figure sweep had the same hole).
  `createServerEvent` is the object-less form, for persistent server-wide events. And the handler runs as
  `Play:fn(pObject, args)` — self first — so a dot-defined `function Play.fn(_, args)` reads the object as
  `args` and the id is lost (the spared enemy stayed a second time).
- **A dead lab character looks alive and cannot talk.** The server reports a refused queued command to the client
  as `CommandQueueRemove count=N error=E state=S`; `error=1` with `state=20` is the locomotion check (20 = DEAD,
  19 = INCAPACITATED, `CreatureLocomotion.h`). Locomotion is recomputed only on a real posture change, so a revive
  that sets an already-upright posture leaves it DEAD; the lab's `revive` toggles the posture. And the open desert
  at (4100, −4700) east of Mos Eisley is Tusken ground: a level-one character parked there dies within a minute,
  which is what every "did not start a conversation" of the Knight gate was. Scenarios park at a shrine.

### 2026-10-21 — 4b.1 the Jedi Master

- **Stock enclave facts.** Light Jedi Enclave = snapshot building `8525417` at (−5513.7, 4911.8, h 270), entrance
  at (−5575, 4910); 27 cells (`lotsurvey cells yavin4 -5575 4910`, `rooms object/building/yavin/shared_light_enclave.iff`),
  the training room (cell 24) is flat at −24.1 with no furniture, the lobby (22) is a ramp, the auditorium's
  centre is a throne. Snapshot cell ids are stable across boots (stock city scripts rely on that), but
  `BuildingObject:getNamedCell("trainingroom")` is the readable way. The door is `EnclaveContainerComponent::
  checkBuildingPermission` (god mode, then FRS council match); cells have their own rule for the tier rooms.
  The `light_jedi_sentinel`s outside (`customAiMap = "enclaveSentinel"`) only attack a player for whom
  `CheckProspectJediTrial` holds, i.e. mid stock Knight trial — a Padawan walks past them.
- **FRS as the ladder.** `frs_manager.lua` keeps `frsEnabled = 1`; the rank skills are `force_rank_light_novice`,
  `force_rank_light_rank_01..10`, `force_rank_light_master` (dark likewise), the robes are certified on them.
  Enrolment = `PlayerObject:setFrsCouncil(1)` (COUNCIL_LIGHT; 2 = dark), `setFrsRank(0)`, `awardSkill` of the
  novice box. Jedi XP type is `jedi_general` (`CreatureObject:awardExperience(type, amount, true)`).
- **The FRS rank boxes cannot be awarded the normal way:** `skills.iff` requires a Jedi Knight (required skills +
  Jedi state) behind `force_rank_light_novice`, and `SkillManager::awardSkill` checks that even with
  `noXpRequired`. New `awardSkill(..., ignorePrerequisites)` + the Lua global `awardSkillUnchecked(pPlayer,
  skill)` grant a box regardless (skill mods, titles and schematics still applied). **The stock FRS manager is
  now off** (`custom_scripts/managers/jedi/fb_frs_hooks.lua`, run by `FrsManagerImplementation::loadLuaConfig`
  before it reads `frsEnabled`): enabled, its login validation forced light-council characters to Rebel overt
  and dark to Imperial overt, which would have set every patrol in Phase 3 on a fresh Padawan; it also ran votes,
  petitions and XP debt. The enclave doors and the Masters only need the council in the player's FRS data.
- **A visitor must be seen, not just near.** The conversation rule is ≤ 5 m *and* line of sight; a follower
  that stops behind a shrine's stone 3 m away fails it. `FbTrials.settleBeside` now places the visitor at 2.5 m
  on its own bearing and walks the compass until `AiAgent:checkLineOfSight(pPlayer)` holds (gate 2026-10-21,
  the Old Man at Tatooine shrine 02).
- **The enclave admits the Padawan *box*, not the flag.** A lab character given only `FbAttunement` flag
  `padawan` was ejected from the enclave's cells at login (the door rule reads `force_title_jedi_novice`);
  the jedi-master scenario grants the skill as the trials do, and the lab's `skill` oracle falls back to
  `awardSkillUnchecked` for boxes with prerequisites.

### 2026-10-21 — 4b.2 the Sith Master

- Dark Jedi Enclave = snapshot building `3435626` at (5070.1, 310.2, h 90), entrance (5068, 310); 27 cells, a long
  descent (ramps → foyer → antechamber → main room → chamber ramp → *chamber*, cell 16, flat at −43.3, two chairs
  at its far end: (0, −150) is clear, (0, −155) is in a chair). `fb_jedi_master.lua` became `fb_masters.lua`:
  `FbMasterBase:new{…}` carries everything, the two Masters are data (side, council, rank box, room, tasks,
  string prefix). The `master` flag on the character says whose student it is; the other Master turns it away.

### 2026-10-21 — 4b.3 alignment, the ladder, the turn

- Murder detection uses the AI bindings: a victim that `isAiAgent()` and not `isCreature()` (a humanoid NPC), with
  `AiAgent:isKiller()` false and `AiAgent:isAggressiveTo(pPlayer)` false. Animals never count; hostile NPCs
  never count.
- The ladder reuses the Masters' task engine: rank tasks are ordinary entries with `rank` and `xp`; `screenFor`
  gates the offer on `PlayerObject:getExperience("jedi_general")`, `reward` promotes. The stock FRS XP thresholds
  (5000, 15000, 25000, …) are the numbers used. Surrendering the old side's boxes on the turn is
  `CreatureObject:surrenderSkill(name)` (the binding passes verify/notify/… = true).

### 2026-10-22 — 4b.4 the Knight trial

- Stock places with interiors and ids: the Dantooine crystal hunters' cave is building `8535482` (cells 1–9, oids
  8535483…8535491; rooms r1–r9, `lotsurvey rooms object/building/general/shared_dantooine_force_crystal_hunter_sd_cave.iff`),
  the stock spawns sit in r1–r4; the Nightsister stronghold is outdoors (every stock spawn cell 0) around
  (−4052, −161) on Dathomir, open ground at (−4040, −100). A yielding enemy = `DAMAGERECEIVED` observer on the
  mobile (`onBossHit(pBoss, pAttacker, damage)`, return 1 to drop the observer), then `clearCombatState(true)`,
  `setPvpStatusBitmask(0)`, AI off, `setOptionBit(CONVERSABLE)` — the conversation template is on the mobile from
  the start, the bit decides whether it talks. The stock Knight unlock (`JediTrials:unlockJediKnight`) sets the
  Jedi state 4/8 and the Knight title but also forces faction overt; ours leaves faction alone.
## 2026-10-22 (alice) — rebased on the Phase 4b merges, two pilot lessons

- `origin/unstable` took three Phase 4b lanes (master, sith, ranks) while `feature/alice` waited for its gate; the merge
  into `feature/alice` auto-resolved (CLAUDE.md, `fb_lab_tests.lua`, the roadmap and dev-notes all changed on both
  sides, no overlapping hunks).
- **Teyla's real directory was wiped a second time** (2026-10-22 13:03 local): every other lane's gate ran the
  `pilot-dry` scenario from `unstable`, which still lacks the `--home` fix from 6e19297a17, so `rm -rf
  ~/.swg-lab/citizens/teyla` ran on each gate and left the dry run's memory in its place. Nothing to do but merge
  this branch; until then, treat Teyla's memory as disposable.
- Wex's pilot died on 2026-10-21 09:13 with a `TimeoutError` in `Senses.gather()`: its seat was still finishing a walk
  that the previous pilot had started (the action lock was held, so `vars`/`objects` waited past the 60 s socket
  timeout). The wake loop now catches a seat timeout, waits 30 s and tries again instead of exiting.

### 2026-10-23 — 4a.0 crystal formations

- Several stock caves share one portal layout: the Tatooine squill cave and the Lok droid engineer's cave are the
  same POB (room coordinates transfer), the Dathomir rancor cave is the Dantooine crystal hunters' cave mirrored
  (x negated). `lotsurvey rooms` on each shows it; a cave's world position comes from `objectPos:<any of its cell
  oids>` (the cell's world position is the building's).
- Saber crystal colours are `@jedi_spam:saber_color_N`: 0 Red, 1 Dark Red, 2 Light Green, 3 Dark Green, 4 Blue,
  5 Dark Blue, 6 Yellow, 7 Dark Yellow, 8 Light Purple, 9 Dark Purple, 10 Orange, 11 Brown (12+ are the named
  rares, 31 the special red). Lua has no colour setter; a loot item with `craftingValues = {{"color", N, N}}` pins
  it, and `custom_scripts/loot/serverobjects.lua` is included by the stock loot loader, so custom loot items work.
- A harvestable world object = a server-only object template (`clientTemplateFileName` of a stock look +
  `objectMenuComponent`), spawned with `spawnSceneObject(zone, template, x, z, y, cellOid, qw, qx, qy, qz)`; the
  Lab Remote established the pattern.
- Scenarios that hand the shared character items that count for attunement (crystals, holocrons) take them back
  at their end (`takeItems:<char>:<fragment>`), or the attunement scenario's capped-sum check fails on `items`.
- **The first unattended day of the citizens, read back from the logs (2026-10-22 evening):**
  - Teyla was found **dead** at 3947,-4744 (health −263) and her pilot had spent the day resting and asking for a medic:
    `my_health` showed pools only and the model never learned the word for it. Likeliest killer: the `sandstorm`
    scenario, which every gate runs — twelve Tusken raiders walk in over the east outskirts, exactly where her playbook
    parked her (knight's lane lost the shared lab character the same way). The perception now carries `condition`
    (fine / incapacitated / dead), `my_health` says it too, and a `clone` tool answers the revive window
    (`seat.action("sui", value="0", match="revive")` — the server opens `@base_player:revive_title` on login for a dead
    character, so cloning works even after a restart). While the citizens live on the test bench, scenario events can
    and will kill them; the live-world server proposed to Chuck is the real fix.
  - **Wild creatures spawn only around a player who moves**: `SpawnArea::notifyPositionUpdate` → `tryToSpawn` (every
    5 s at most, `Core3.Regions.minimumLairSpawnInterval`), lairs placed near the player and never inside the city
    circle (Mos Eisley: 456 m around 3460,-4768). `objectsNear:tatooine:4010:-4700:600:1024` was empty until Teyla had
    walked one leg; then worrts, womp rats, a rill and rockmites stood between 3600 and 3830. `creatures_near` now falls
    back to a server-side 300 m scan (droids and named NPCs filtered out) and says so when nothing roams; Teyla's
    playbook tells her to walk legs and never to stand on the outskirts.
  - Wex surveyed "Bihommo" (a Corellian wooly hide: `tool=-1`, hunted, not surveyed) because `resources_here("mineral")`
    returned nothing — the oracle's text filter matches class names like "Axidite Iron", never the word *mineral*. The
    pilot now maps the class words to survey-tool codes (`SurveyTool.idl`: mineral 6, chemical 2, …), hides creature
    resources unless asked for `all`, and `survey` accepts a unique fragment and lists what the tool finds here on a
    miss. His deed request `harvester_ore` found nothing because the client names the deed
    `@deed:ore_s1_harvester_deed_name`: object lookup now matches every word of the fragment, and the error lists the
    deeds carried.
  - A seat reply nests its error under `result`; the pilot's log line printed `None` for every failed action.
  - Both citizens cloned themselves on the next wake once the tool existed (Wex had died too, at his Bihommo spot, and
    cloned in Coronet). Then neither could leave the cloning facility: `findPath` from a cell to the world works only for
    a target near the building (30 m yes, 190 m no — `findPathFromCellToWorld` ends on the exterior floor mesh), so
    `pathTo` now steps out first (a reachable world point 30–60 m from the building, eight bearings) and continues with
    a world path. The client reports cell-local coordinates indoors: the perception's position now comes from the
    server's `where` line and says "indoors" when it is.
  - The API caps **strict tools at 20**; adding `clone` made 21 and both pilots died on a 400 at their first wake. Tools
    without arguments go unstrict, and a decider exception is now a 120 s wait, not the end of the pilot.
  - **Wex walked into the sea.** His "best spot" for Bomide (−3072, −3648 on Corellia) is 37 m under water: the
    server snaps a walking player to `findClosestWorldFloor`, which on open water is the surface (z −1.0), sets the
    SWIMMING state, and `SurveySession::startSurvey` then refuses with `@error_message:survey_swimming` — a string-id
    system message the bot client does not decode, so the seat saw "no SurveyMessage within 10 s" and nothing else.
    The lab character surveyed fine at the same spot because a teleport sets z to the terrain and never swims. Found by
    comparing the two characters' `where` lines (z −1.0 vs −37.6). Fixes: `getWaterHeightAt(zone, x, y)` Lua binding,
    the resource oracle's best spots skip underwater points, `terrainHeights` prints `water=`, `where` prints
    `swimming=` (`hasState(0x40000)`; the binding returns a number, compare with 1), the pilot's condition says
    "swimming … walk back to land". `pendingTask:<char>:<name>[:cancel]` oracle (new exact-name bindings
    `hasPendingTaskNamed` / `cancelPendingTaskNamed`; the stock Lua ones build `screenplay:key` names) came out of the
    first, wrong theory and stays as a lab tool.
  - **Never ask the terrain at the planet edge**: `TerrainManager::getHeight` at x or y = ±8192 prints a WARNING *with a
    full stack trace* per call; the first land-only `resources` scan touched the edge rows and columns for every
    spawn and flooded the console thread for nine minutes (the queued `shutdown` ran only after; `swg stop` gave up
    at 240 s). The scan now stays strictly inside (−8192, 8192). `swg status` reported RUNNING throughout — a flooded
    console looks healthy from outside.
  - **The bot client names creatures by appearance template**, not by what the server calls them: the rills east of Mos
    Eisley are `@monster_name:dune_lizard` in the client's view (`rill.iff` shares the lizard's shared template name)
    while the server says "a rill", so Teyla's hunt for "rill" never matched anything standing in front of her.
    `creatures_near` now joins the client's view to the server's `objectsNear` scan by oid and uses the server's names.
    Decoding the CREO3 name in the client would be the proper fix (follow-up).
  - **Teyla's hunts "timed out" while her rifle XP climbed**: she was killing the worrts (a level 5 minor worrt, 143 health,
    died 30 s into a manual `seat fight` watched with the new `creatureHam:<oid>` oracle), but `objectAlive` answered
    alive=1 for the corpse — it only checked that the object was still in the zone, and a dead creature stays there for
    a while. It now counts a dead creature as not alive, so the fight loop sees the kill, loots and moves on.
  - **The story camp killed Teyla, not the worrt** (2026-10-23, after the gates): her memory said a worrt took her
    from 748 health to −6 in 23 s; a worrt hits for 50. `FbLabTests:story` showed the weekly story event *tusken_raid*
    live with five raiders camped at 3985,−4770 — the `story-ticker` scenario fires it in every gate, so the camp
    stands 100 m from her old hunting ground after every bench run, refilled hourly for a week. Tusken raiders are
    level 19 and hit for 180–190: five of them empty 1100 health in one three-second tick of the fight loop, and the
    pilot never saw them because the perception listed *creatures* (type 0x400) and the raiders are NPCs. Her server
    level also read **1**: `calculatePlayerLevel` (`private_<weapon>_combat_difficulty / 100 + 1`, cap 25) is only
    stored when a skill box is awarded, and the veteran start awarded hers unarmed; her rifle difficulty mod is 1150,
    so she is really a 12. Fixes: lab `threats:<char>[:<radius>]` (aggressive AI agents and wild creatures above the
    character's *fighting strength*, computed from the best weapon line; `objectsNear` prints `level=`), the pilot's
    perception carries `fighting_strength` and `threats` (with `pack`), `creatures_near` rows carry `level` and `pack`,
    `hunt` refuses to start with a winning threat within 120 m (above the strength alone, or a pack above half of it),
    skips prey by the same rule and, after a retreat, **walks 300 m toward the nearest travel point** — the old loop
    stopped attacking and stood still, which is how an incapacitation became a death. Verified live: at the new south
    ground (3450,−5300) she met three level-10 zucca boars and five aggressive sevorrts, refused, and walked back
    toward the starport. Her ground is now south of Mos Eisley (`mos_eisley_easy_newbie` circle, outside the `_sw`
    rectangle's slaver theaters); the east is written off in her playbook.

### 2026-10-23 — 4c the bounty

- Stock visibility: `PlayerObject:getVisibility()` / `setVisibility(n)` (Lua), raised by the server on saber and Force
  use near others, decayed hourly over 21 days (`visibility_manager.lua`: maxVisibility 8000, termThreshold 1500,
  falloffThreshold 100). `FbBounty` reads it and nothing else; the price and the hunters are ours.
- Setting a spawned NPC on a player: `AiAgent:setDefender(pPlayer)` (the invasions' pattern) with an AGGRESSIVE +
  ATTACKABLE + ENEMY pvp mask; `addDefender` exists on AiAgent only, not on a player's CreatureObject.
- The Mos Eisley cantina is stock building `1082874` (h 38); its main room is cell 3 (`cantina`, oid 1082877, the
  ambient life's anchor cell); a spot by the north wall at (8, 4) is 4 m from the nearest furniture. The stock
  mobile library has no male criminal smuggler dress, only the female one and the Binayre Trandoshans.
- A lab character shared by every gate accumulates: after a dozen runs its `jedi_general` experience sat at the
  stock cap (90 000) and a Master's reward added nothing. Scenarios that pay experience zero it first (`xpSet`,
  through `awardExperience` by the difference).
- **A gate is good for one tip.** Three gated branches merged in a row: the first two went in, the third
  (`feature/crystals`) no longer merged cleanly once the bounty lane was on `unstable` (both had added to
  `fb_lab_tests.lua`, `screenplays.lua`, `fb_force.stf.txt` and the docs). The owner merges `unstable` into the
  branch, resolves, and re-gates before Chuck merges; `bench merge` refuses a dirty bench, so a conflicted merge
  must be finished (committed) before the next one runs. Keep-both resolutions of Lua need a `luac -p` before the
  commit: the crystals merge lost two `end`s at a hunk border and committed anyway because the shell chain used `;`.
- Lua 5.3's `%d` refuses a float with a fraction (`bad argument to 'format': number has no integer representation`):
  anything read from C++ as `lua_pushnumber` (visibility, HAM, heights) goes through `math.floor` before `%d`. The
  bounty's hunt log line died on a decayed visibility of 1999.6, after the squad was spawned, and the lab tick
  returned nothing — a check that passed when the number was still whole.

### 2026-10-23 — 7.5 the citizens train (alice)

- **Why training first:** Teyla's stored level read 1 against a fighting strength of 12 (her veteran start was awarded
  unarmed; `calculatePlayerLevel` only runs on a skill award), and her first wake on the new south ground met giant
  worrts (level 13, pairs) above that strength and found nowhere to hunt. A citizen that never spends its experience
  never grows; the stock answer is the trainer NPC.
- **How stock training works** (`screenplays/trainers/trainerConvHandler.lua`, `skillTrainer.lua`, `trainerData.lua`):
  the trainer's conversation lists the boxes of its `trainerSkills[<type>]` the player can take (`fulfillsSkillPrerequisitesAndXp`)
  as options `@skl_n:<skill>` under *learn* (option 0 of the intro), then a cost screen (yes = option 0) that pays
  the credits (cash first, then bank) and calls `LuaSkillManager:awardSkill`. The trainer type is the NPC's mobile
  template name (`trainer_rifleman`); `AiAgent:getCreatureTemplateName()` reads it. Skill points are not exposed to
  Lua: `canLearnSkill(pPlayer, skill, false)` is the one check that covers prerequisites, experience and points.
- **Lab:** `trainable:<char>[:all]` (INFO trainable = buy now; INFO next = prerequisites met, experience short; for the
  professions the character holds a box of, `all` adds every novice box; `INFO training … level= strength=` summary),
  `trainers:<planet>:<type>[:x:y]` (trainer NPCs by template within 500 m of each travel point, nearest first, cell-local
  coordinates indoors), `skillDrop:<char>:<skill>` (`surrenderSkill`; the scenario resets the shared lab character).
- **Pilot:** perception `training` (`ready` with credits, `next` with experience have/cost, sorted by how close); tool
  `train(skill)` — lab trainable → nearest trainer by template → walk (`within=3`, indoors too) → the stock conversation
  over real packets (converse `[0]`, find `@skl_n:<skill>` among the options, converse `[0, i, 0]`) → `hasSkill` read
  back; the result carries the new level and strength. The tool has an argument and is the 21st, so it is unstrict.
- **`AiAgent:getCreatureTemplateName()` halted the server** (null `npcTemplate->getTemplateName()`): an AI agent from the
  world snapshot (oid 16796195, a stock static NPC) has no creature template. The binding now returns "" for those.
  The symptom was a gdb catchpoint with the Lua oracle printing nothing at all, and every later `swg cmd` answering
  nothing while `swg status` said HALTED IN GDB — read `swg status` before blaming the oracle.
- **An indoor path ended under the floor.** `findPath` returns the indoor target itself as the last point, at the z it
  was asked for (0): the walk's last `DataTransformWithParent` set the character 1.1 m below the room, the position was
  accepted (the server checks speed, not floors), the travel code never noticed (a ticket terminal needs no line of
  sight) — and `NpcConversationStartCommand` refused the trainer with its silent GENERALERROR, because
  `checkLineOfSightInBuilding` casts the ray from the character's cell-local z + 1 through the floor triangles. `pathTo`
  now gives the last indoor point the floor height of the node before it; `path_within` stops short indoors too (a
  zero-length ray from inside the NPC is not a line of sight either).
- **`seat.action(…, timeout=)` is the socket's timeout**, not the action's: the converse action's own wait is its
  `timeout` field, so the train tool sends the action JSON through `seat.request` directly.
- Scenario `seat-train`: the lab character with the Scout novice box and 5000 scout + trapping experience trains
  `outdoors_scout_movement_01` from the square (outdoor trainer, 8 m) and `outdoors_scout_tools_01` from beside the
  trainers' hall (indoor trainer in cell `meetingb`, through the door); 14 checks, both boxes read back, 1000 credits
  each, the box gone from `ready` afterwards. Mos Eisley has eight scout trainers near its shuttleport.
- **What Teyla can train:** nothing yet — the next Rifleman boxes cost 175 000–350 000 rifle experience (she has 1025)
  and the Scout boxes 1000 scout/trapping/camp experience (she has 0). Her level stays 1 until the first award; the
  stock grind is the stock grind (XP ×2 already) — whether the citizens get more is Chuck's call. Follow-ups: a bazaar
  `sell` tool for Wex (the bot client already lists and buys), crafting.
- **Scouts harvest corpses** (same batch, after the gate above went red on a flake — see below). The rules
  (`HarvestCorpseCommand.h`, `CreatureImplementation::canHarvestMe`, `CreatureManagerImplementation::harvest`): within
  10 m of the corpse, not in combat, the `outdoors_scout_novice` box and `creature_harvesting` ≥ 1, the creature has
  organics (a kreetle: insect meat / scaley hide; a worrt: meat, hide, bone), once per player per corpse,
  `harvestcorpse [meat|hide|bone]` (random when unsaid). Scout experience = level × 5 + 19 (a kreetle paid 71 with the
  ×2), the message is `@skl_use:creature_quality_<fat|medium|scrawny>` with the resource name — the client decodes it
  now, and the seat reads the kill by the experience (`xp:<char>:scout` before and after) rather than the message.
  `tools/seat fight … --harvest` (after the loot, waits up to 12 s for `where` to say combat=false, nowait command);
  the pilot's `hunt` asks lab `skillmod:<char>:creature_harvesting` once and harvests every kill when it is at least 1,
  reports `harvested`. Teyla holds the Scout novice box, so twenty worrts are one scout box (1000) and the first award
  with the rifle in hand recomputes her level from 1 to the real number. Scenario `seat-fight` grants the box and checks
  the corpse and the experience (14 checks).
- **Gate flake, 2026-10-23 ~21:30:** `schematic-broker-ui` and `schematic-broker` both failed on the bot's converse with
  Dannik Vosa in the Trade Hall ("did not start a conversation within 5s"), the same broker oid twice, right after the
  `sandstorm` scenario; `gotoNpc` reported the teleport done both times, the lab-side purchase worked, and the scenario
  passed on its own a few minutes later (12/12) as it had in every earlier gate. Pattern: the bot logs in 2 s after a
  relog into a cell and talks after 2 s more; nothing in the batch touches that path. Unexplained; if it repeats, give
  those two scenarios a longer `--wait` before the converse or a `where` check that the character came back in the cell.
- **Gate flake 2, 2026-10-23 ~22:20, explained and fixed:** the re-gate on `3d172f429f` was green everywhere except
  `survey-sample` (`sample_ok`: "no sample result at all"), which passed alone right after. Cause, in the server: one
  sample start in 51 (`SurveySessionImplementation::startSample`, `System::random(50) == 7`) opens the *concentrated
  sample* list box (`@survey:cnode_t`: a richer spot nearby, or `@survey:gnode_t`: gamble 300 action) instead of
  sampling; the real client answers it, the seat's `sample` action only counted result messages for 5 s. Row 0 of either
  window ("ignore / keep sampling here") calls `rescheduleSample`, which schedules the sample **25 s** out (not 3 s).
  Fix in `tools/seat` (`sample_seat`, used by the CLI and the pilot's `sample` tool): on "no sample result" answer a
  window whose title contains `node_t` with row 0 and re-send the sample with two rounds (a sample with a task pending is
  swallowed; the 30 s wait catches the rescheduled result), else re-send once (a first result slower than the action's
  5 s); the result carries `minigame`, `retried` and the survey/sample system messages seen (`said`) so the next flake
  explains itself. The seat's `sui` answer needs its own `timeout` field in the action body: the Python `timeout`
  keyword of `Seat.action` is the socket wait and is not sent.
