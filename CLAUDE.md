# Final Boss — SWG Pre-CU private server (SWGEmu Core3 fork)

Solo/small-group Pre-CU server. Chuck owns gameplay feel and play-tests; Claude edits, builds,
runs and tests. Host: WSL2 Debian 12.

## Docs

- [docs/SWG-Server-Roadmap.md](docs/SWG-Server-Roadmap.md) — vision, design questions Q1–Q10, Phases 0–6 with
  numbered items (commit messages reference these, e.g. "Phase 1.7").
- [docs/SWG-PreCU-Server-Guide.md](docs/SWG-PreCU-Server-Guide.md) — Chuck's setup/ops guide: client connection,
  WSL networking, account SQL, gotchas, from-scratch rebuild. DB password and DBSecret are redacted in
  the repo copy (`config-local.lua` holds the real values).
- [docs/dev-notes.md](docs/dev-notes.md) — the long-form gotchas list and per-session log. Append to it.

## Paths

| What | Where |
|---|---|
| Repo root | `~/workspace/Core3` |
| Server tree (Makefile, CMake) | `MMOCoreORB/` |
| Runtime dir (binary, conf, logs, DB) | `MMOCoreORB/bin/` (server must be started from here) |
| Server binary | `MMOCoreORB/bin/core3` (built by ninja-debug, ~300 MB, Debug) |
| Build tree | `MMOCoreORB/build/unix/ninja-debug/` (`COMPILE_TESTS=ON`, `ENABLE_BUILD_CLIENT=OFF`) |
| Config | `bin/conf/config.lua`, overridden by `bin/conf/config-local.lua` (git-ignored, holds DB creds and `Core3.DBSecret`). `~/custom-features.lua` is `dofile`d from config-local |
| Lua scripts | `bin/scripts/` (custom content goes in `bin/scripts/custom_scripts/`, loaded last) |
| Final Boss NPCs | `bin/scripts/screenplays/tasks/tatooine/fb_*.lua` (spawn + conv handler), `bin/scripts/mobile/quest/tatooine/fb_*.lua` (mobile templates), `bin/scripts/mobile/conversations/tasks/fb_*_conv.lua` (conversation templates) |
| ODB (object store, BerkeleyDB) | `bin/databases/` (~850 MB) |
| MySQL | `127.0.0.1:3306`, db `swgemu`, user `swgemu`; `mysql swgemu` works via `~/.my.cnf` |
| Logs | `bin/screenlog.0` (console of the current run), `bin/log/core3.log`, `bin/log/lua.log`, `bin/log/player.log` |
| TRE client files | `/tre` (`TrePath`); `/tre/finalboss.tre` is ours, installed by `tools/swg tre install` from the build output `MMOCoreORB/bin/tre/finalboss.tre` (ignored). Chuck's game client: `/mnt/c/EMU/swg - Copy/SWGEmu` (remembered in `~/.swg-lab/client-dir`; `/mnt/c/SWGDev/SWG_Game/swg - Copy/SWGEmu` is a stale duplicate still pointing at nova.swgemu.com) |
| Lot / room survey | `tools/lotsurvey near|cells|footprint|rooms|furniture|check|lots …` reads the stock snapshot, portal layouts and floor meshes through the server's archives: where buildings stand, a template's footprint and rooms (cell-local coordinates for `spawnMobile`), and free lots for a building near a point. Used to place the 2.11 Trade Hall |
| Custom client/server data (strings, templates) | `tre-src/` → packed by `tools/tre` (stdlib Python; `build/list/extract/strings/verify/roundtrip/install/status/crc`). `string/en/fb_*.stf.txt` = `key = text` lines → `@fb_*:key` |
| Wrapper scripts | `~/bin/build`, `~/bin/run` (both `source ~/.env`) |
| Unit tests (gtest) | `MMOCoreORB/src/tests/*.cpp` |

## Build

```bash
~/bin/build            # ninja-debug incremental build (runs IDL), Debug, ccache
~/bin/build clean      # clean rebuild
```
- `~/bin/build` forces `-DENABLE_BUILD_CLIENT=OFF`, so `bin/core3client` (bot client) is **not** built by it.
  To build the client: `CMAKE_ARGS=-DENABLE_BUILD_CLIENT=ON ~/bin/build` (caller's `CMAKE_ARGS` are appended
  after the OFF, and cmake keeps the last `-D`). The next plain `~/bin/build` switches it back OFF, but an
  already-built `bin/core3client` stays.
- Incremental rebuild with a warm ccache is ~3.5 min wall clock; a changed `.idl` regenerates code; a small edit to a rarely included one (the `WeatherManager` getter) rebuilt in 16 s, a widely included one costs much more.
- **Custom strings / client data** live in `tre-src/` and are packed into `finalboss.tre` (`swg tre build`).
  `swg start` and `swg test unit` build + install it into `/tre` themselves; the server caches string
  tables in its ODB, so `swg start` adds the `reloadstrings` argument whenever the archive changed.
  The client needs the same file in its folder plus a `searchTree_00_N=finalboss.tre` line in
  `swgemu_live.cfg`: `swg tre install --client '<client folder>'` does both (folder remembered in
  `~/.swg-lab/client-dir`, so a plain `swg tre install` keeps the client current too; `swg tre patchcfg FILE`
  is the cfg step alone, `swg tre status` reports the client file + cfg state). The first archive in `Core3.TreFiles` wins, so ours is listed first in
  `config.lua` (and `Core3.TreManager.LatestTre` must name it or `ConfigManagerTest.TreFiles` fails).
- Lua-only changes need no rebuild. `swg cmd reloadscreenplays` re-runs `screenplays.lua` into each thread's
  *existing* Lua state on next use (globals persist, functions are redefined, screenplay `start()` is **not**
  re-run, so nothing re-spawns). Mobile/conversation/manager Lua lives in other Lua states and needs a restart.

## Run / stop

- **Never Ctrl+C / kill the server.** Stop it by typing `shutdown` at its console and waiting for clean exit.
- `~/bin/run` (Chuck's interactive way): rotates `screenlog.0`, resets the `admin` account password from
  `$ADMIN_PASS`, starts `gdb core3` inside `screen -S swgemu-server`, and attaches.
- `tools/swg` (Claude's way, tmux session `swg`) — see Test commands. Do not run both at once
  (`pgrep core3` first).
- Boot takes ~45 s; ready when the console prints `[Core] initialized` followed by `READY`.
- Console commands (`help` lists them): `shutdown`, `save`, `info`, `chars`, `reloadscreenplays`,
  `reloadmanager`, `loglevel`, `broadcast`, `runLuaFunction module:function[:arg...]`, `dumpcfg`.
- Chuck's client connects to `127.0.0.1` over UDP, which needs WSL **mirrored** networking
  (`C:\Users\rac35\.wslconfig`: `networkingMode=mirrored`; re-enabled 2026-10-18, nat copy kept as
  `.wslconfig.nat.bak`). Under nat the client hangs at "Connecting to the Login Server" while the lab bot,
  inside WSL, still works. Changing it needs `wsl --shutdown` from Windows: stop the server first.
- Known baseline log noise (filtered by `swg logs --errors`): `[TemplateManager] ERROR - unknown appearance
  type SPRT` (upstream: the server's appearance loader has no sprite reader; fires when a character with
  randomized missions in their bag logs in), and `[MantisDatabase0] ERROR - 1045: Access denied for user 'swgemu'` (and the
  matching `[Console]` line). Not ours; ignore when diffing ERROR lines.

## Branch and release rules

- `unstable` is the main branch (tracks `origin/unstable`). Upstream: `swgemu/unstable`.
- New work goes on `feature/<name>` branched from `unstable`, then merged into `unstable` with `--no-ff`.
  Doc-only touch-ups (status, to-do ticks) may go straight onto `unstable`.
- Stable points are tagged `chuck-stable-YYYYMMDD` (the older `stable-20260523` tag predates this convention).
- Remotes: `origin` (crandles1202/Core3, the only push target), `swgemu` (upstream), `mtg` (ModTheGalaxy),
  `flurry`, `orkwerks` — all non-origin remotes are fetch-only.
- **Ask Chuck before:** `git push`, merging into `unstable`, loading a snapshot, or any DB write outside
  the `claude-admin` / `claude-player` accounts.
- **Never commit passwords or secrets.** `config-local.lua` (`DBSecret`), `~/.env`, `~/.my.cnf` stay out of git.
- Commit messages: Chuck uses `Phase X.Y: <what>`; keep that style for roadmap work.

## Test commands

All via `tools/swg` (run from anywhere; `tools/swg --help` for the full list):

```bash
tools/swg start [--no-gdb]      # start core3 (under gdb by default) in tmux "swg", wait for READY (~45 s)
tools/swg stop                  # send "shutdown", wait for clean exit (~80 s), quit gdb
tools/swg status                # running? pid, branch, binary date, error count
tools/swg cmd "<console cmd>"   # send a console command, print the log lines it produced
tools/swg logs --errors         # ERROR/FATAL lines from the current run, minus known noise
tools/swg test unit             # core3 runUnitTests (258 gtests, ~12 s; server must be stopped)
tools/swg test lua [<char>]     # reloadscreenplays, then FbLabTests:runAll on the live server → PASS/FAIL lines
tools/swg test bot [--user claude-admin]  # core3client: the account creates a char, zones in, 30 s, logs out
tools/swg test scenario <name>  # tools/scenarios/<name>.sh: bot acts + Lua oracle observes (gameplay tests)
tools/swg test all              # stop if running → unit → start → lua → bot → scenarios (server left running)
tools/swg build                 # ~/bin/build with the client on; prints only errors/warnings and timing
tools/swg logs --lua            # bin/log/lua.log
tools/swg snap save|list <name> # mysqldump + copy of bin/databases (~700 MB) to ~/swg-snapshots/<name>
tools/swg snap load <name> --yes  # restore (server stopped). Ask Chuck first.
tools/swg account create <user> <admin_level> [--reset]   # server's own hash recipe; pw → ~/.swg-lab/
tools/swg account prune <user> [--keep N]  # delete oldest Lab* chars of a claude-* account (10-char cap); test bot does it
tools/swg tre build|install [--client DIR]|patchcfg FILE|status|strings … # finalboss.tre from tre-src/ (see Build)
```

- Lua content checks live in `bin/scripts/custom_scripts/screenplays/fb_lab_tests.lua` (wraps `spawnMobile`
  to record every `fb_*` spawn; discovers NPCs from the filesystem; static-loads manager/mobile/conversation
  files to verify wiring). It also holds the **scenario oracle**: `ham`, `inventory`, `findItem`, `npc`,
  `where`, `skillmod` (read) and `inflict`, `heal`, `wound`, `give`, `skill`, `travel` (set up), all callable
  as `runLuaFunction FbLabTests:<fn>:<args>` or `lab fn:args` inside a scenario.
- **Gameplay scenarios** (`tools/scenarios/*.sh`, see `lib.sh`): the bot acts through real packets
  (`--command <slash command>` [`--args`, `--command-nowait` for commands that send no queue ack such as
  `startdance`], `--radial <oid> <id>`, `--converse <npcOid> --options 0,2`, `--missions <terminalOid>`,
  `--wait n`, `--sell <item> <vendor> <price>` / `--buy <item> <price>` / `--retrieve <item> <vendor>` for bazaars; `--sui <row|text> [--sui-match <title fragment>]` answers server UI windows (list boxes by
  row index or row text, input boxes by text); `--keep-going` runs on after a failed action),
  the oracle observes. Templates: `stimpack-heals.sh` (control round measures regen, then the command
  round; asserts per-pool heal beyond regen), `npc-conversation.sh`. Write one for every mechanic
  change; `swg test all` runs them. `*.manual.sh` scenarios (long audits such as `merchant-stops`, which
  walks every merchant stop) run only by name: `swg test scenario merchant-stops`.
- Test accounts: `claude-admin` (admin_level 15), `claude-player` (admin_level 0). Passwords are in
  `~/.swg-lab/*.pass` (mode 600), never in the repo. Account hash = `SHA256(DBSecret + password + salt)`,
  salt = 32 hex chars (`AccountManager::createAccount`). `~/bin/run` resets an `admin` account that does
  not exist in this DB, so that line is a no-op.
- Bot characters are named `Lab` + three consonant-vowel syllables (random letters trip the server's
  name filter) on account `claude-player` and accumulate; the galaxy caps an account at 10, so
  `swg test bot` prunes the oldest (`swg account prune`) when it gets there.
- Snapshots: `baseline` (2026-10-16, post-upstream-merge, before Phase 2 and any bot characters) and
  `post-phase2` (2026-10-16, `unstable` @ `fa635eaa38`, after the Phase 2 merge).

## Shipped Final Boss content (what tests should protect)

| Phase | Change | Where |
|---|---|---|
| 2.12a | **Lab Remote** — the lab in game, for admins: an inventory item (`object/tangible/fb_lab_remote/fb_lab_remote.iff`, stock camp-remote look, handed to every privileged character at login by `FBLogin`; the old field probe's path is an alias) whose radial opens server UI windows: *Where am I* (world + room coordinates and a ready-to-paste tenant line, also echoed to chat), *Find NPC* (name / template / source file / oid → teleport me, waypoint, audit, move it to where I stand facing my way, make it face me), *Audit NPCs within 50 m*, *Lab actions* (convoy, invasion begin/assault, storm on/off here, story, merchant, HoloNet, ambient beat), Trade Hall / territory / news windows. Every window calls the FbLabTests oracles through `FbLabTests.capture`. Non-admins get a refusal. Spawn registry is now shared across Lua states through quest status (`FbLabSpawns.*`), so find/placement see respawns made on worker threads | `custom_scripts/screenplays/fb_lab_remote.lua`, `custom_scripts/object/tangible/fb_lab_remote/`, scenario `lab-remote` (bot as `claude-admin`) |
| 2.11 | **Mos Eisley Trade Hall** — proof of concept for server-placed buildings: `FbTradeHall` spawns a stock Commerce Guild hall (9 cells) on a surveyed lot 150 m north of the starport square (3580, −4638, porch facing south) at every boot (stock prop pattern, not persisted; cell ids change per boot), spawns the 11 FB vendors into its rooms by cell *name* (room coordinates from the floor meshes), and a doorman "Hallkeeper Jyn Odaro" on the square who marks the hall on the map (`addWaypoint`) and lists the tenants; galaxy chatter mentions it. The vendors' plaza entries are commented out in their screenplays. Lot survey tooling: the world snapshot and portal-layout readers in the lab's scratch scripts (dev-notes) — the starport apron alone is 170 m across, which is why the hall is not on the square | `fb_trade_hall*.lua`, `fb_trade_hall_keeper*.lua`, scenario `trade-hall` |
| 4.0 | Custom data archive: `tools/tre` packs `tre-src/` (string tables as `key = text` text files, anything else verbatim) into `finalboss.tre`, byte-identical on repack of stock archives; listed first in `Core3.TreFiles` (+ `Core3.TreManager.LatestTre`), installed into `/tre` by `swg start`/`swg test unit`, which also pass `reloadstrings` when it changed; client side via `swg tre install --client DIR` (copies + patches `swgemu_live.cfg`). Probe table `string/en/fb_lab.stf` for the tests. Prerequisite for every Phase 4 custom name/title/journal entry | `tools/tre`, `tre-src/`, `config.lua`, `src/tests/FbTreTest.cpp`, scenario `tre-strings` |
| 0.5 | `custom-features.lua` git-ignored | `.gitignore` |
| 1.3 | Starter gear: CDEF pistol, shirt, pants, stimpack added to `commonStartingItems` | `managers/player_creation_manager.lua` |
| 1.7 | Shuttleport away time 300 s → 60 s (`shuttleportAwayTime`) | `managers/planet/planet_manager.lua` |
| 2.2 | Schematic broker "Dannik Vosa" at Mos Eisley starport (3535, -4813): 33 single-use loot schematics in three catalogues (decor, kitchen/cantina, workshop/tech incl. recyclers), 250–5000 cr cash, each labelled with and gated by its template's `requiredSkill`. Master-tier sets (Mandalorian, Geonosian, corvette) excluded, as are the 38 upstream stub templates with no draft. `FbSchematicBroker:purchase(pPlayer, cat, item)` is public for the lab | `fb_schematic_broker*.lua` (screenplay, conv handler, conv template, mobile) |
| 2.3 | Parts dealer "Tamsin Rook" at Mos Eisley starport (3535, -4818): 46 crafting sub-components (weapon parts, armor segments, chemistry parts) generated through `createLoot` with the `component_loot` item names, standard rolled at level 30, advanced at level 60 for 3× the price | `fb_parts_dealer*.lua` |
| 3.4 | Faction territory map: Mos Eisley (default 65 % Imperial), Bestine (80) and Anchorhead (35) each carry an Imperial % in quest status `FbTerritory.<region>`; ≥60 Imperial-held, ≤40 Rebel-held, contested between. Shifted by invasions (±10) and convoys (destroyed −10, arrived +5). Read by patrols (the holder's squad +1 man, the other −1), HoloNet (sector report line; Rebel propaganda where the Rebellion holds the relay) and cantina chatter (live lines). Threshold crossings post news and broadcast. Vendor faction / mission types not wired | `fb_territory.lua` + hooks in patrols/holonet/chatter/convoys/invasions |
| 3.1 | GCW invasions (Bestine first; cities are data): every 6 h (persistent event `FbInvasionTick`) a Rebel column (commando + 6) musters in the desert east of Bestine while the garrison (squad leader + 5) forms up at the plaza — galaxy warning + news; after 10 min the attackers are re-homed at the plaza (or they leash back) and advance; opposing-faction NPCs fight on sight, stragglers are paired off (`setDefender`/`addDefender`); all attackers dead → held, all defenders dead → fell, 20 min → withdrew. Players who hit either side get +50/−50 standing, winners 1000 cr; the city's `FbTerritory.bestine` Imperial % shifts ±10 (seed of 3.4). Keren/Dearic wait for Phase 5 planets | `fb_invasions.lua` |
| 3.9 | Weather as world events (Tatooine): extreme sandstorms now blind and hurt the unsheltered (upstream mechanic switched on in `weather_manager.lua`, `sandstormDamage = 25`, one point less per covering piece worn), and a heavy or extreme storm is an event: galaxy warning, news line, three Tusken raiding parties (leader + 3) walk in on Mos Eisley's east, north-east and south-east outskirts and withdraw when the sky clears. Lua `getZoneWeather(zone)` / `setZoneWeather(zone, 0-4)` (keeps the automatic pattern, unlike `/weather`). Covers the weather half of 3.3; vehicle slow-down not done | `fb_weather_events.lua`, `WeatherManager.idl/Implementation.cpp` (`forceWeather`), `DirectorManager.cpp` |
| 3.11 | Convoys, ambush mode: every 30–60 min an Imperial supply convoy (squad leader, 3 stormtroopers, cargo droid) walks from the starport to the garrison end of Mos Eisley. First hit summons 2 reinforcements after 60 s; killing every guard drops a loot crate (2× junk, 1× crafting component), pays 750 cr and +50 Rebel / −50 Imperial standing to everyone who hit it, posts news and broadcasts; untouched, it arrives and the news says so. Escort mode is the follow-up | `fb_convoys.lua` |
| 3.10 | HoloNet relays "HN-7" (silver protocol droid) at the Mos Eisley starport, Mos Eisley cantina and Bestine cantina read a produced segment every 45–75 s while listeners are near: sting, top story (live ticker), this week's wanted (the story's mobs), a galaxy item, where the merchant trades, propaganda, outro. Conversation option replays it | `fb_holonet*.lua` |
| 3.2 | Faction patrols: an Imperial squad (squad leader + 2 stormtroopers) walks the stock Mos Eisley patrol loop and a Rebel squad (commando + 2 troopers) the desert west of the walls; leader walks `setNextPosition` legs with a dwell at each point, members follow, dead squads are replaced. Stock faction rules apply (they fight declared enemies, ignore neutrals). Routes are data | `fb_faction_patrols.lua` |
| 3.5 | Story event ticker: once a week (persistent event `FbStoryTick`) one of three stories fires — Tusken raiders east of Mos Eisley, pirates outside Anchorhead, Imperial crackdown around Bestine. Each posts its news into the galaxy chatter (one-week TTL), broadcasts one line to everyone online, and camps 4–5 killable mobs at its spot, refilled hourly for the week. `FbStoryTicker:fire(idx)` public | `fb_story_ticker.lua` |
| 3.6 | Galaxy chatter: a shared pool the ambient patrons draw 35% of their spoken lines from — 10 static galaxy news lines, live facts (where the traveling merchant is, Bestine election phase) and dated news posted via `FbGalaxyChatter.addNews(key, line, ttl)` (quest-status backed, expires; a repeated line refreshes its entry, the pool keeps the newest `maxNews = 8`). The 3.5 story ticker plugs in there | `fb_galaxy_chatter.lua` |
| 3.7 / 3.8 | Ambient life in three cantinas, each with its own voice: Mos Eisley (wretched hive, 5 patrons), Bestine (Imperial-leaning, tense, 4), Coronet (pilot-heavy, gambling, 4), plus three travellers waiting outside the Mos Eisley starport (outdoor seats, terrain height). Patrons mutter, gesture, notice newcomers and change seats every 5–10 min — only while a player is within 20 m. Stock Core3 already seats the silent crowd; this is the behaviour layer. Data-driven `FbAmbientLife.locations`; `tick`/`churn`/`status` public. Theed pending (its cantina cell is not in the stock city file) | `fb_ambient_life.lua` |
| 2.9 | Traveling merchant "Ozlo Vantrek": one NPC that moves between 9 audited city stops every 3 h (persistent server event `FbMerchantMove`, state in quest status), selling 8 of a 34-item cosmetic pool (paintings, jewellery, hats, goggles) that rotates per visit. `FbTravelingMerchant:move()` / `:status()` are public for the lab | `fb_traveling_merchant*.lua` |
| 2.10 | Vendor maintenance auto-skim: on a player vendor 5% of each sale (`Core3.Vendor.SaleMaintenancePercent`) goes into the vendor's maintenance, the owner banks 95%; bazaar sales untouched. **Not lab-verified** (a vendor needs an owned structure); Chuck checks with a real vendor | `AuctionManagerImplementation.cpp` (`doInstantBuy`), `VendorDataComponent.h` |
| 2.5 | Bazaar limits config-driven with new defaults: 100 listings per character (was 25), one-year bazaar and vendor listing times (were 7 / 30 days); price caps unchanged. Scenario `bazaar-listings` lists 26 items. Keys `Core3.Auction.MaxSales`, `.CommodityExpireSeconds`, `.VendorExpireSeconds`, `.MaxBazaarPrice` in `config-local.lua` override | `AuctionManagerImplementation.cpp` (helpers at top) |
| 1.10 | No-grind entertainer: a 10 s tick without a flourish pays one flourish's XP (`flourishXpMod`; `baseXp` is 0 in the datatable, so stock pays nothing), and a solo performer counts as 25 watchers (`fbSoloAudienceMod = 0.5`). Healing XP still needs patrons | `EntertainingSessionImplementation.cpp` (`awardEntertainerExperience`) |
| 1.11 | Group XP ×1.25 (`groupExpMultiplier`, already in) + group loot bonus: a grouped kill gets a second loot roll 25% of the time (`Core3.Loot.GroupBonusChance`). **Not lab-verified** (needs a grouped kill) | `player_manager.lua`, `CreatureManagerImplementation.cpp` |
| 1.4 | Mission terminals show level + direction: creator name becomes `Name [Lvl 23 - 1.4km NE]` when a list is randomized (`fbApplyMissionHint` in `populateMissionList`); `core3client --missions <terminalOid>`; Lua mission getters | `MissionManagerImplementation.cpp`, `LuaMissionObject.cpp`, `client/actions/MissionListAction.cpp` |
| 1.5 | Character inventory 80 → 100 items: template re-registered (new characters) + `FBLogin` raises persisted limits on login (existing characters); Lua `SceneObject:setContainerVolumeLimit` added. Client's "/80" counter is cosmetic | `custom_scripts/object/tangible/inventory/fb_inventory_100.lua`, `custom_scripts/screenplays/fb_player_login.lua`, `LuaSceneObject.cpp` |
| 1.9 | Player stimpacks (starter, crafted A–E, ranged/area, quest) heal mind too: `attributes = {0, 3, 6}` re-registered from `custom_scripts` | `custom_scripts/object/tangible/medicine/fb_stimpack_mind.lua` |
| — | Blue frog "Combat Test Character" menu; Jedi trials no longer teleport to Yavin; FRS test build uses Defender Master | `terminal_character_builder.lua`, `jedi_trials.lua`, `PlayerManagerImplementation.cpp` |
| 2.6 | FB-21 medical droid network (buffs, wound clear, travel) | `fb_mos_eisley_medical_droid*.lua` |
| 2.7 | FB-72 armory droid (Mos Eisley starport + 2 weapon shops) | `fb_armory_droid*.lua` |
| — | QoL: 100k cash/bank start, global XP ×2, group XP ×1.25, pet/vehicle call 5 s, 20 housing lots, resource stack 10M, admin `flag = 2` | `player_creation_manager.lua`, `player_manager.lua`, `*ControlDeviceImplementation.cpp`, `PlayerObject.idl`, `ResourceContainer.idl`, `staff/levels/admin.lua` |
| 2.1 | Vex Renn stim/medical dealer (Mos Eisley) | `fb_stim_dealer*.lua` |
| lab | NPC placement toolkit: every spawn an `fb_*` file makes is recorded with its spot (stock templates too); `placement[:filter]` audits line of sight (8 probes at 3 m), terrain height and drift, `findNpc`/`gotoNpc`/`waypointTo` find an NPC by name, template or source file; `checkPlacement` in `runAll` fails the Lua run for a boxed-in or underground NPC. Found and fixed: Rori Restuss medical droid in a wrong cell (underground), starport travellers wandering (now `AI_STATIC`) and the starport HoloNet relay behind the plinth (moved to the plaza) | `fb_lab_tests.lua`, scenario `npc-placement` |
| lab | FB mobiles given `mobType`/`chanceHit`/`damageMin`/`baseHAM` so `LuaMobileTemplatesTest` passes; `core3client` create-character race fixed (`ZonePacketHandler.cpp`) | `mobile/quest/tatooine/fb_*.lua`, `src/client/zone/` |

Non-combat NPC templates still need positive `chanceHit`, `damageMin/Max`, `baseHAM/HAMmax` and a `mobType`
(`MOB_NPC` / `MOB_DROID`) or the unit tests fail — copy from an existing FB mobile.

**Changing an upstream object template:** don't edit the upstream file (merge conflicts). Add a file under
`custom_scripts/object/…`, include it from `custom_scripts/object/serverobjects.lua` (loaded after every
upstream template), modify the existing global table and call `ObjectTemplates:addTemplate(tbl, iff)` again;
the later registration replaces the earlier one. Pattern: `fb_stimpack_mind.lua`. Restart to load.
`~/custom-features.lua` (`FBFeatures.*` flags) is a scaffold nothing reads yet; shipped features are
unconditional.

**Per-login fix-ups** (anything every existing character must be migrated to) go in `FBLogin.onLogin`
(`custom_scripts/screenplays/fb_player_login.lua`), which wraps upstream `PlayerTriggers:playerLoggedIn`.
Persisted object fields (`containerVolumeLimit`, …) are only read from the template at creation.

## Gotchas (read before writing Lua or tests) — detail in [docs/dev-notes.md](docs/dev-notes.md)

- `SceneObject(p)` / `CreatureObject(p)` / … return one **shared wrapper per class**, re-pointed on every
  call. Never keep `local o = SceneObject(p)` across another `SceneObject(...)` call; wrap inline.
  Breaking this throws a C++ exception that `pcall` can't catch and dirties the console Lua stack.
- There are many Lua states. Screenplay Lua can't see manager globals (`shuttleportAwayTime`,
  `commonStartingItems`), mobile/conversation templates, or `FBFeatures`. Sandbox-`loadfile` the file
  to inspect it (pattern in `fb_lab_tests.lua`).
- `reloadscreenplays` re-runs `screenplays.lua` into the existing state: functions update, `start()` does
  not re-run, nothing re-spawns. Mobile/conversation/manager Lua needs a restart.
- Non-combat mobiles still need `mobType`, `chanceHit`, `damageMin/Max`, `baseHAM/HAMmax` > 0 or the
  unit tests fail.
- Non-admin accounts create one character per hour; failed attempts reset the timer. The name filter
  runs first, so a declined name does not count.
- Allow-list rules match the whole command: run `git merge`, `git push`, `tools/swg …` as a single
  command per Bash call, never inside `a && b`. The classifier still refuses some things (remote
  URL changes, remote branch deletes, `git checkout -- <conf file>`); hand those to Chuck.
- The admin `/weather <n>` command stops the automatic weather pattern on that planet until `/weather enable`;
  use the lab's `weatherSet` (Lua `setZoneWeather`) to force weather without stopping it.
- An AI agent leashes back to its spawn point when sent or teleported far away; move its home too
  (`AiAgent:setHomeLocation(x, z, y, nil)`) before long walks. Short legs (patrols, convoy) are fine.
- **Placing a building** (2.11 pattern): `spawnSceneObject(zone, "object/building/…iff", x, z, y, 0, cos(h/2), 0, sin(h/2), 0)`
  creates the structure *and* its cells (not persisted: spawn at every boot, find cells by name with
  `BuildingObject:getCellName(i)`, never store cell ids). Room coordinates: cell-local x = floor-mesh x,
  cell-local y = floor-mesh z, cell-local z = the floor height (`appearance/collision/<pob>_r<N>_<room>_collision_floor.flr`,
  VERT chunk, little-endian floats). Footprint = the `r0` exterior floor's extents — check the lot against
  every stock footprint from `snapshot/<planet>.ws` (WSNP/NODS/NODE DATA, payload little-endian) before
  choosing it — `tools/lotsurvey lots <planet> <x> <y> --template <building iff>` does exactly that and
  `lotsurvey rooms <iff>` prints the rooms; the lab's `spawnBuildingAt`/`buildingInfo` oracles spawn and measure a candidate.
  **Furniture is client-only** (the building's `interiorlayout/*.ilf`; the server never loads it), so neither
  the placement audit nor line of sight can see an NPC standing in a table: `tools/lotsurvey check <iff> --lua
  <screenplay>` (or `--spot room,x,y`) tests spots against the furniture boxes — run it for every indoor spot
  and keep it in the scenario (trade-hall does). Stock city files are not a safe source of spots either (their
  Trade Hall "mercenary" point is inside the bar counter).
- Starting a conversation needs same cell, ≤ 5 m and line of sight to the NPC, and fails silently otherwise.
  **Before trusting an NPC spot:** `swg cmd "runLuaFunction FbLabTests:placement:<name>"` (line of sight to
  probes 3 m around, height above terrain, drift; `checkPlacement` runs it for every FB spawn in `swg test lua`),
  then `gotoNpc:<char>:<name>` and look at it in the client — the server's collision data misses some decorative
  world meshes, so an 8/8 spot can still be hidden behind a plinth (HN-7 at the starport, 2026-10-18). A wrong
  `cellID` makes `spawnMobile` fall back to the cell-local numbers as world coordinates (Rori droid at 29,0,
  84 m underground); the audit's terrain rule catches that. Stock commoner templates wander unless
  `AiAgent:addObjectFlag(AI_STATIC)` (+ `clearOptionBit(AIENABLED)` when not pvp-flagged).
- Spawns made by server events (seat churn, respawns) are recorded in *that* Lua state's `FbLabTests.spawns`,
  invisible to the console; the shared registry in quest status (`FbLabTests.registryAdd/registryLive`, written
  by the `spawnMobile` wrapper in every state) is the truth across states — `liveSpawns`, `checkNpc` and the
  Lab Remote read it. Keep per-window state in quest status too: SUI callbacks run on whichever thread
  handles the packet (pattern in `fb_lab_remote.lua`).
- Screenplay table fields set in `start()` are not visible from the console or server-event Lua states;
  persist cross-call state with `setQuestStatus`/`getQuestStatus` (keys without `:`). `getTerrainHeight`
  needs a creature; use `getTerrainHeightAt(zone, x, y)` when there is none.
- gtest's `<<` cannot print an engine3 `String`; use `.toCharArray()` in assertion messages.
- Lua bindings read arguments from the top of the stack and do not validate: a call with the wrong
  arity (`faceObject(pNpc)` instead of `faceObject(pNpc, true)`) passes garbage/null into C++ and
  segfaults the server. Check the binding's signature in `Lua*.cpp` before using a method for the first
  time. If the server is halted at a gdb catchpoint (`swg status` says HALTED IN GDB), a null-deref in a
  leaf function can be skipped with `frame N` / `return` / `continue` in the tmux pane; otherwise
  `swg stop` kills it from gdb and keeps the backtrace in `~/.swg-lab/crashes/`.
- `git ls-files -v | grep ^S` shows skip-worktree files. `resource_manager_spawns.lua` is written by the
  server and must stay that way; nothing else should carry the flag.

## Permissions (Chuck-owned)

`.claude/settings.json` (committed) is the allow-list that lets Claude push/merge/manage accounts without
the classifier stepping in. Claude is not allowed to edit it; Chuck does. Intended content:

```json
{ "permissions": { "allow": [
  "Bash(git push origin *)", "Bash(git push -u origin *)", "Bash(git merge *)",
  "Bash(git submodule update *)", "Bash(git stash drop *)",
  "Bash(tools/swg *)", "Bash(/home/chuck/workspace/Core3/tools/swg *)",
  "Bash(/home/chuck/bin/build *)", "Bash(mysql swgemu *)" ] } }
```
Settings are read at session start, so restart Claude Code after creating it.
- Keep this list and `docs/dev-notes.md` current: every non-obvious lesson gets written down the same
  session it is learned (Chuck's standing request).

## Current status

_Updated: 2026-10-18 (session 3: Phase 4 design settled with Chuck, 4.0 TRE tooling shipped; Phase 1 done, Phase 2 bar 2.4, Phase 3 bar 3.12 and the time-of-day half of 3.3)_

- `unstable` = `origin/unstable`, no local feature branches, stash empty. Each phase went through its own
  `feature/phaseX.Y-*` branch, a `--no-ff` merge and a push; all seven are **unplay-tested by Chuck** (he
  tests tonight) — see the checklist in To-do.
- Shipped today: 1.9 stimpacks heal mind (Lua template override), 1.5 inventory 100 (template + login
  hook + Lua setter), 1.4 mission level/direction hints (C++ `populateMissionList`), 1.10 no-grind
  entertainer XP (C++ `awardEntertainerExperience`), 2.5 config-driven bazaar limits (C++), 2.2 schematic
  broker NPC (Lua), 2.3 parts dealer NPC (Lua, loot-generated components). Phase 1 complete (1.11 loot half
  shipped unverified). Phase 2 left: 2.4 loot kits (scoping question open). Phase 3 so far: 3.2 faction patrols, 3.5 story ticker, 3.10 HoloNet relays, 3.11 convoys (ambush), 3.9 sandstorm events, 3.1 Bestine invasions, 3.4 territory map, 3.6 galaxy chatter, 3.7/3.8 ambient life (three cantinas + starport travellers). 2.10 shipped unverified (needs an owned
  structure to place a vendor; the bot has no SUI driving yet). **Phase 3 left:** 3.12 podracing (large; no
  podracer assets in the TRE, would be speeder NPCs + a bookie), the time-of-day half of 3.3 (the server has no
  day length, only `Zone::getGalacticTime()`), 3.11 escort mode. **Phase 4 (Jedi/Sith): design decided 2026-10-18** — the decisions
  block at the top of the roadmap's Phase 4 section is the spec (attunement score with capped sources, Force-ghost
  clues, FRS rank trees as the ladder, Masters in the Yavin 4 enclaves, cosmetic colour crystals, fixer-paid
  bounties). 4.0 custom TRE tooling shipped and installed in Chuck's client (`/mnt/c/EMU/swg - Copy/SWGEmu`). **2.11 Mos Eisley Trade Hall** shipped the same night (server-placed stock building with the 11 square vendors inside, doorman on the square) — the pattern for every later shop/enclave. Next: 4a.1 attunement + Old Man on `feature/phase4a.1-*`; TRE object templates (custom building names) when a shop needs its own name.
- Binaries: `bin/core3` and `bin/core3client` built 2026-10-17 from this tree (`swg build`).
- Lab now: 261 unit, ~420 Lua checks (one placement check per live FB spawn), bot, 23 scenarios (+2 manual audits) (`lab-remote`, `trade-hall`, `npc-placement`, `tre-strings`, `stimpack-heals`, `npc-conversation`,
  `inventory-100`, `mission-hints`, `entertainer-xp`, `schematic-broker`, `schematic-broker-ui` (real SUI path),
  `parts-dealer`, `bazaar-listings`, `traveling-merchant`, `ambient-cantina`, `galaxy-chatter`, `story-ticker`, `faction-patrols`, `holonet`, `convoy-ambush`, `sandstorm`, `invasion-bestine`, `territory`; manual: `merchant-stops`, `ambient-locations`). Oracle
  additions today: `inventoryLimit`, `setInventoryLimit`, `loginHook`, `spawnObjectNear`, `destroyObject`,
  `missions`, `xp`, `cash`, `buySchematic` / `buyPart` / `buyMerchant` (by item name), `hasSchematic`, `merchant`,
  `merchantMove[:stop]`, `merchantStops`, `questStatus`, `travelCell`, `findNpc`, `gotoNpc`, `waypointTo`, `placement`, `spawnNpcAt`, `moveNpc`, `spawnBuildingAt`, `buildingInfo`, `tradeHall`, `giveRemote`, `capture`, `ambient`, `ambientTick`, `ambientChurn`, `ambientLocations`, `galaxyNews`, `galaxyAddNews`, `story`, `storyFire`, `objectAlive`, `patrols`, `patrolStep`, `holonet`, `holonetSegment`, `holonetBroadcast`, `convoy`, `convoySpawn`, `killNpc`, `factionStanding`, `containerItems`, `weather`, `weatherSet`, `storm`, `stormTick`, `invasion`, `invasionBegin`, `invasionAssault`, `invasionEngage`, `invasionResolve`, `invasionSide`, `teleportObject`, `objectPos`, `territory`, `territorySet`, `territoryShift`, `patrolRespawn`, `stringId`, `systemMessage`. The
  client now logs spatial chat (`SpatialChat from=<oid>: text`, last 50 kept in its var store). Bot
  additions: `--missions <terminalOid>`, `--command-nowait`, `--sell`/`--buy`/`--retrieve`, `--sui`, `--keep-going`, and an
  end-of-run `=> #N {...}` results dump that `bot_action_status`/`bot_action_count` read. Known gap: the client does not decode every
  StringId system-message shape (e.g. `@loot_schematic:not_enough_skill` arrived as an empty line).
- Snapshots: `baseline` (702 MB, pre-Phase 2) and `post-phase2` (700 MB, `unstable` @ `fa635eaa38`,
  before today's Phase 1 work).
- Accounts: `claude-admin` (id 4, level 15), `claude-player` (id 5, level 0), `Chuckertons` (id 2, level 15)
  and `chuck` (id 3, level 0) all hashed with the custom `Core3.DBSecret` from `config-local.lua`;
  passwords in `~/.swg-lab/<user>.pass`. `config.lua` is back to the upstream default (no skip-worktree).

### To-do

- [x] `.claude/settings.json` created by Chuck 2026-10-16 and committed.
- [x] `feature/test-lab` merged into `unstable` and pushed (2026-10-16). Tag `chuck-stable-20261016`
  once Chuck has play-tested the Phase 2 NPCs.
- [x] **Phase 0.2 — DBSecret.** All four accounts re-hashed under the custom secret; guide SQL updated.
- [x] Snapshot `post-phase2` taken.
- [x] Remote cleanup (Chuck, 2026-10-17): `origin/feature/qol-starter-gear` deleted, origin URL now
  `https://github.com/Crandles1202/Core3.git`. Only `origin/unstable` remains on the fork.
- [ ] **Chuck play-test checklist (2026-10-17 build):** (1.9) take mind damage, use a stimpack, examine
  it — mind listed and healed; (1.5) drop a 90th item into the inventory — server allows it, counter may
  read "90/80"; (1.4) open a mission terminal — creator column reads `Name [Lvl N - 1.4km NE]`, check the
  direction against the waypoint; (1.10) dance alone without flourishing — XP message every 10 s; (2.2) talk to Dannik Vosa at the
  starport, buy a schematic you have the skill for, use the datapad; (2.3) buy a part from
  Tamsin Rook next to him and examine its stats; (2.5) list 26+ items on a bazaar; (2.10) sell something from one of your vendors — 5% of the
  price lands in its maintenance, 95% in your bank; (2.9) `swg cmd "runLuaFunction FbLabTests:merchant"` tells
  you where Ozlo is; visit him, buy something, check he is not standing in a wall at that stop (the lab
  audited all nine stops as reachable, but not as pretty); (3.7) sit in the Mos Eisley cantina for a minute —
  patrons mutter and gesture, one notices you, and over 5–10 min a face at a table changes; same in the
  Bestine and Coronet cantinas with their own lines; (3.6) listen for a minute — some lines are galaxy
  news, one of them names the city Ozlo is in right now; (3.5) `swg cmd "runLuaFunction FbLabTests:story"` says which
  story is live and where its mobs camp — go fight them, and note the broadcast line at login; (3.2) watch a
  stormtrooper squad walk the Mos Eisley loop and a Rebel squad in the desert west of town — declared
  players should get attacked by the enemy one; (3.10) stand by the silver protocol droid outside the
  starport for a minute and listen to the news; (3.11) `swg cmd "runLuaFunction FbLabTests:convoySpawn"` forms a
  convoy at the vendor row — ambush it with a declared Rebel (reinforcements after the first hit, crate
  when the last guard drops) or watch it walk to the garrison; (3.9) `swg cmd "runLuaFunction FbLabTests:weatherSet:tatooine:4"`
  then stand outside Mos Eisley: within a minute the warning arrives, the sky goes dark, you take sandstorm
  damage unless indoors or wrapped up, and Tusken parties close in from the east; `weatherSet:tatooine:0` ends it.
  Tune `sandstormDamage` in `weather_manager.lua` if 25 feels wrong; (3.1) `swg cmd "runLuaFunction FbLabTests:invasionBegin"`
  then `invasionAssault` (or wait 10 min) and go to the Bestine plaza: Rebels and stormtroopers fight it out, join either
  side, and check the result broadcast, your standing and `invasion` (territory %); (3.4) `swg cmd "runLuaFunction FbLabTests:territory"`
  shows who holds what; hand Mos Eisley to the Rebels with `territoryShift:mos_eisley:-40` and watch the next patrol
  respawn, the HoloNet relay's voice and the cantina gossip change.
  (4.0) **verified 2026-10-18**: Chuck's client rendered `@fb_lab:probe_first` as "Final Boss TRE probe: first"
  (`swg cmd "runLuaFunction FbLabTests:systemMessage:<YourChar>:fb_lab:probe_first"` is the probe). The untouched
  duplicate `/mnt/c/SWGDev/SWG_Game/swg - Copy/SWGEmu` (2.8 GB, still pointing at nova.swgemu.com) is his to delete.
  (2.11) talk to Hallkeeper Jyn Odaro on the starport square (where the vendor row stood), take the
  waypoint, walk 150 m north into the Trade Hall: nine rooms, eleven vendors — buy something from each
  room you pass, check nobody stands in a desk, and say whether the walk is too far (the square itself is
  boxed in by the starport apron; a closer lot needs a smaller building). `gotoNpc:<You>:Tamsin` skips the walk.
  (2.12a) log in as an admin character: a **Final Boss Lab Remote** lands in your inventory; right-click it →
  *Lab console*: try *Where am I* indoors (the tenant line is what a screenplay needs), *Find NPC* → Tamsin →
  *Teleport me to it*, *Audit NPCs within 50 m*, and *Lab actions* → *Convoy: spawn one now* (the convoy you
  tabled). *Move it to where I stand* re-seats any NPC live — the quick way to try a spot before I write it down.
  Then `swg snap save phase1-quickwins` and tag `chuck-stable-20261017`.
- [ ] Lab characters are followed by the new-player helper droid (R2-H4), which opens a SUI greeting every
  second (visible in every bot log). Harmless for the scenarios now that `--sui` scans all windows, but
  noisy; fix by letting lab accounts skip the tutorial or by finishing it once per character.
- [ ] **Chuck: starter stimpack is unusable by non-medics** (`stimpack_sm_s1` needs `healing_ability >= 5`,
  a fresh character has 0 — found by the stimpack scenario). Decide: own starter template with
  `medicineUse = 0`, a small `healing_ability` grant, or a different consumable. Ties into Phase 1.9.
- [ ] Phase 0.3 backups: Chuck's cron (`~/bin/swg-backup-daily.sh` 03:00 → `~/backups/daily`, 7 days) last
  fired 2026-09-03 because WSL is rarely up at 03:00. `swg start` now runs it when the newest dump is
  >24 h old. For a true nightly job, a Windows Task Scheduler entry running
  `wsl -d Debian -- /home/chuck/bin/swg-backup-daily.sh` is the fix.
- [x] `decreaseOnlineCharCount missing account` ERROR — was the bot logging out mid-connect after
  creating a character; `CreateCharacterAction` now waits for the scene. Not a server bug.
