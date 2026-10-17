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
| TRE client files | `/tre` (`TrePath`) |
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
- Incremental rebuild with a warm ccache is ~3.5 min wall clock; a changed `.idl` regenerates code and costs much more.
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
- Known baseline log noise: `[MantisDatabase0] ERROR - 1045: Access denied for user 'swgemu'` (and the
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
tools/swg test bot              # core3client: claude-player creates a char, zones in, 30 s, logs out
tools/swg test scenario <name>  # tools/scenarios/<name>.sh: bot acts + Lua oracle observes (gameplay tests)
tools/swg test all              # stop if running → unit → start → lua → bot → scenarios (server left running)
tools/swg build                 # ~/bin/build with the client on; prints only errors/warnings and timing
tools/swg logs --lua            # bin/log/lua.log
tools/swg snap save|list <name> # mysqldump + copy of bin/databases (~700 MB) to ~/swg-snapshots/<name>
tools/swg snap load <name> --yes  # restore (server stopped). Ask Chuck first.
tools/swg account create <user> <admin_level> [--reset]   # server's own hash recipe; pw → ~/.swg-lab/
```

- Lua content checks live in `bin/scripts/custom_scripts/screenplays/fb_lab_tests.lua` (wraps `spawnMobile`
  to record every `fb_*` spawn; discovers NPCs from the filesystem; static-loads manager/mobile/conversation
  files to verify wiring). It also holds the **scenario oracle**: `ham`, `inventory`, `findItem`, `npc`,
  `where`, `skillmod` (read) and `inflict`, `heal`, `wound`, `give`, `skill`, `travel` (set up), all callable
  as `runLuaFunction FbLabTests:<fn>:<args>` or `lab fn:args` inside a scenario.
- **Gameplay scenarios** (`tools/scenarios/*.sh`, see `lib.sh`): the bot acts through real packets
  (`--command <slash command>`, `--radial <oid> <id>`, `--converse <npcOid> --options 0,2`, `--wait n`),
  the oracle observes. Templates: `stimpack-heals.sh` (control round measures regen, then the command
  round; asserts per-pool heal beyond regen), `npc-conversation.sh`. Write one for every mechanic
  change; `swg test all` runs them.
- Test accounts: `claude-admin` (admin_level 15), `claude-player` (admin_level 0). Passwords are in
  `~/.swg-lab/*.pass` (mode 600), never in the repo. Account hash = `SHA256(DBSecret + password + salt)`,
  salt = 32 hex chars (`AccountManager::createAccount`). `~/bin/run` resets an `admin` account that does
  not exist in this DB, so that line is a no-op.
- Bot characters are named `Lab` + three consonant-vowel syllables (random letters trip the server's
  name filter) on account `claude-player` and accumulate; delete them when they get in the way.
- Snapshots: `baseline` (2026-10-16, post-upstream-merge, before Phase 2 and any bot characters) and
  `post-phase2` (2026-10-16, `unstable` @ `fa635eaa38`, after the Phase 2 merge).

## Shipped Final Boss content (what tests should protect)

| Phase | Change | Where |
|---|---|---|
| 0.5 | `custom-features.lua` git-ignored | `.gitignore` |
| 1.3 | Starter gear: CDEF pistol, shirt, pants, stimpack added to `commonStartingItems` | `managers/player_creation_manager.lua` |
| 1.7 | Shuttleport away time 300 s → 60 s (`shuttleportAwayTime`) | `managers/planet/planet_manager.lua` |
| 1.9 | Player stimpacks (starter, crafted A–E, ranged/area, quest) heal mind too: `attributes = {0, 3, 6}` re-registered from `custom_scripts` | `custom_scripts/object/tangible/medicine/fb_stimpack_mind.lua` |
| — | Blue frog "Combat Test Character" menu; Jedi trials no longer teleport to Yavin; FRS test build uses Defender Master | `terminal_character_builder.lua`, `jedi_trials.lua`, `PlayerManagerImplementation.cpp` |
| 2.6 | FB-21 medical droid network (buffs, wound clear, travel) | `fb_mos_eisley_medical_droid*.lua` |
| 2.7 | FB-72 armory droid (Mos Eisley starport + 2 weapon shops) | `fb_armory_droid*.lua` |
| — | QoL: 100k cash/bank start, global XP ×2, group XP ×1.25, pet/vehicle call 5 s, 20 housing lots, resource stack 10M, admin `flag = 2` | `player_creation_manager.lua`, `player_manager.lua`, `*ControlDeviceImplementation.cpp`, `PlayerObject.idl`, `ResourceContainer.idl`, `staff/levels/admin.lua` |
| 2.1 | Vex Renn stim/medical dealer (Mos Eisley) | `fb_stim_dealer*.lua` |
| lab | FB mobiles given `mobType`/`chanceHit`/`damageMin`/`baseHAM` so `LuaMobileTemplatesTest` passes; `core3client` create-character race fixed (`ZonePacketHandler.cpp`) | `mobile/quest/tatooine/fb_*.lua`, `src/client/zone/` |

Non-combat NPC templates still need positive `chanceHit`, `damageMin/Max`, `baseHAM/HAMmax` and a `mobType`
(`MOB_NPC` / `MOB_DROID`) or the unit tests fail — copy from an existing FB mobile.

**Changing an upstream object template:** don't edit the upstream file (merge conflicts). Add a file under
`custom_scripts/object/…`, include it from `custom_scripts/object/serverobjects.lua` (loaded after every
upstream template), modify the existing global table and call `ObjectTemplates:addTemplate(tbl, iff)` again;
the later registration replaces the earlier one. Pattern: `fb_stimpack_mind.lua`. Restart to load.
`~/custom-features.lua` (`FBFeatures.*` flags) is a scaffold nothing reads yet; shipped features are
unconditional.

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

_Updated: 2026-10-17 (session 1 wrap-up: lab merged into unstable)_

- `unstable` @ `fa635eaa38` = `origin/unstable`: upstream sync (14 commits, engine3 `4cbf3933`), Phase 2
  Mos Eisley NPCs (15 FB mobiles with valid combat stats), CLAUDE.md/docs, `tools/swg`, lab tests,
  `core3client` actions. No feature branches exist locally; `origin/feature/qol-starter-gear` is merged
  and awaits deletion by Chuck.
- Binaries: `bin/core3` and `bin/core3client` built 2026-10-16 from this tree.
- Snapshots: `baseline` (702 MB, pre-Phase 2) and `post-phase2` (700 MB, `unstable` @ `fa635eaa38`).
- Accounts: `claude-admin` (id 4, level 15), `claude-player` (id 5, level 0), `Chuckertons` (id 2, level 15)
  and `chuck` (id 3, level 0) all hashed with the custom `Core3.DBSecret` from `config-local.lua`;
  passwords in `~/.swg-lab/<user>.pass`. `config.lua` is back to the upstream default (no skip-worktree).
- Phase 1.9 (stimpacks heal mind) shipped 2026-10-17 from `feature/phase1.9-stim-heals-mind`: Lua-only
  template override, scenario `stimpack-heals` (9 checks), 4 new content checks. 177 Lua checks total.
- Roadmap next: 1.4 (mission terminal level/direction), 1.5 (inventory `containerVolumeLimit` 80 → 100 in
  `object/tangible/inventory/objects.lua`; the 20 lots half is done), 1.10 (entertainer XP without
  audience), 1.11 (group bonus). 1.1, 1.2, 1.3, 1.6, 1.7, 1.8 were in before the lab.
- Stash list empty; no stray backup files in `bin/conf`.

### To-do

- [x] `.claude/settings.json` created by Chuck 2026-10-16 and committed.
- [x] `feature/test-lab` merged into `unstable` and pushed (2026-10-16). Tag `chuck-stable-20261016`
  once Chuck has play-tested the Phase 2 NPCs.
- [x] **Phase 0.2 — DBSecret.** All four accounts re-hashed under the custom secret; guide SQL updated.
- [x] Snapshot `post-phase2` taken.
- [x] Remote cleanup (Chuck, 2026-10-17): `origin/feature/qol-starter-gear` deleted, origin URL now
  `https://github.com/Crandles1202/Core3.git`. Only `origin/unstable` remains on the fork.
- [ ] **Chuck: starter stimpack is unusable by non-medics** (`stimpack_sm_s1` needs `healing_ability >= 5`,
  a fresh character has 0 — found by the stimpack scenario). Decide: own starter template with
  `medicineUse = 0`, a small `healing_ability` grant, or a different consumable. Ties into Phase 1.9.
- [ ] Phase 0.3 backups: Chuck's cron (`~/bin/swg-backup-daily.sh` 03:00 → `~/backups/daily`, 7 days) last
  fired 2026-09-03 because WSL is rarely up at 03:00. `swg start` now runs it when the newest dump is
  >24 h old. For a true nightly job, a Windows Task Scheduler entry running
  `wsl -d Debian -- /home/chuck/bin/swg-backup-daily.sh` is the fix.
- [x] `decreaseOnlineCharCount missing account` ERROR — was the bot logging out mid-connect after
  creating a character; `CreateCharacterAction` now waits for the scene. Not a server bug.
