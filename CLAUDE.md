# Final Boss — SWG Pre-CU private server (SWGEmu Core3 fork)

Solo/small-group Pre-CU server. Chuck owns gameplay feel and play-tests; Claude edits, builds,
runs and tests. Host: WSL2 Debian 12.

## Docs

- [docs/SWG-Server-Roadmap.md](docs/SWG-Server-Roadmap.md) — vision, design questions Q1–Q10, Phases 0–6 with
  numbered items (commit messages reference these, e.g. "Phase 1.7").
- [docs/SWG-PreCU-Server-Guide.md](docs/SWG-PreCU-Server-Guide.md) — Chuck's setup/ops guide: client connection,
  WSL networking, account SQL, gotchas, from-scratch rebuild. DB password is redacted in the repo copy.
  Stale on one point: it says DBSecret is still the default `swgemus3cr37!`; `config-local.lua` now sets
  its own `Core3.DBSecret`.
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
tools/swg test lua [<char>]     # runLuaFunction FbLabTests:runAll on the live server → PASS/FAIL lines
tools/swg test bot              # core3client: claude-player creates a char, zones in, 30 s, logs out
tools/swg test all              # stop if running → unit → start → lua → bot (server left running)
tools/swg snap save|list <name> # mysqldump + copy of bin/databases (~700 MB) to ~/swg-snapshots/<name>
tools/swg snap load <name> --yes  # restore (server stopped). Ask Chuck first.
tools/swg account create <user> <admin_level> [--reset]   # server's own hash recipe; pw → ~/.swg-lab/
```

- Lua content checks live in `bin/scripts/custom_scripts/screenplays/fb_lab_tests.lua` (wraps `spawnMobile`
  to record every `fb_*` spawn; static-loads manager/mobile/conversation files to verify wiring). Add a
  check there whenever new content ships.
- Test accounts: `claude-admin` (admin_level 15), `claude-player` (admin_level 0). Passwords are in
  `~/.swg-lab/*.pass` (mode 600), never in the repo. Account hash = `SHA256(DBSecret + password + salt)`,
  salt = 32 hex chars (`AccountManager::createAccount`). `~/bin/run` resets an `admin` account that does
  not exist in this DB, so that line is a no-op.
- Bot characters are named `Lab<6 letters>` on account `claude-player` and accumulate; delete them from the
  blue-frog/`chars` side when they get in the way.
- Snapshot `baseline` = post-upstream-merge boot, taken 2026-10-16 before any bot characters existed.

## Shipped Final Boss content (what tests should protect)

| Phase | Change | Where |
|---|---|---|
| 0.5 | `custom-features.lua` git-ignored | `.gitignore` |
| 1.3 | Starter gear: CDEF pistol, shirt, pants, stimpack added to `commonStartingItems` | `managers/player_creation_manager.lua` |
| 1.7 | Shuttleport away time 300 s → 60 s (`shuttleportAwayTime`) | `managers/planet/planet_manager.lua` |
| — | Blue frog "Combat Test Character" menu; Jedi trials no longer teleport to Yavin; FRS test build uses Defender Master | `terminal_character_builder.lua`, `jedi_trials.lua`, `PlayerManagerImplementation.cpp` |
| 2.6 | FB-21 medical droid network (buffs, wound clear, travel) | `fb_mos_eisley_medical_droid*.lua` |
| 2.7 | FB-72 armory droid (Mos Eisley starport + 2 weapon shops) | `fb_armory_droid*.lua` |
| — | QoL: 100k cash/bank start, global XP ×2, group XP ×1.25, pet/vehicle call 5 s, 20 housing lots, resource stack 10M, admin `flag = 2` | `player_creation_manager.lua`, `player_manager.lua`, `*ControlDeviceImplementation.cpp`, `PlayerObject.idl`, `ResourceContainer.idl`, `staff/levels/admin.lua` |
| 2.1 | Vex Renn stim/medical dealer (Mos Eisley) | `fb_stim_dealer*.lua` |
| lab | FB mobiles given `mobType`/`chanceHit`/`damageMin`/`baseHAM` so `LuaMobileTemplatesTest` passes; `core3client` create-character race fixed (`ZonePacketHandler.cpp`) | `mobile/quest/tatooine/fb_*.lua`, `src/client/zone/` |

Non-combat NPC templates still need positive `chanceHit`, `damageMin/Max`, `baseHAM/HAMmax` and a `mobType`
(`MOB_NPC` / `MOB_DROID`) or the unit tests fail — copy from an existing FB mobile.

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
- Non-admin accounts create one character per hour; failed attempts reset the timer.
- Claude can't merge into `unstable`, `git submodule update`, or push — those are Chuck's; Claude works
  on `feature/*` and asks.
- Keep this list and `docs/dev-notes.md` current: every non-obvious lesson gets written down the same
  session it is learned (Chuck's standing request).

## Current status

_Updated: 2026-10-16 (session 1: test lab set up)_

- Branches:
  - `unstable` @ `d57444a85e` (Phase 2.1 Vex Renn) = `origin/unstable`. **Does not yet contain the upstream
    merge** — the tooling refused to let Claude merge into `unstable`; Chuck does that (see to-do).
  - `feature/test-lab` (current) = `unstable` + CLAUDE.md/docs + `tools/swg` + lab tests + mobile stat fixes
    + `core3client` race fix + **merge of `swgemu/unstable` (14 commits, engine3 → `4cbf3933`)**. Merge was
    conflict-free; no overlap with any Final Boss file. Boots clean (0 ERROR), 258/258 unit tests pass.
  - `feature/phase2-mos-eisley-npcs` @ `e75728d6e1`: the previously uncommitted Phase 2.x work (12 new Mos
    Eisley NPCs, field probe, armory/stim-dealer rewrites, buff tuning). Committed as-is, **untested**,
    not merged anywhere. (The `player_manager.lua.fb_backup_pre_buff_tuning` file was identical to the
    committed pre-tuning version and was deleted 2026-10-16.)
- Binaries: `bin/core3` and `bin/core3client` built 2026-10-16 from `feature/test-lab`.
- Snapshot `baseline` saved (`~/swg-snapshots/baseline`, 702 MB).
- Test accounts `claude-admin` (id 4) and `claude-player` (id 5) exist; login verified via core3client.
- `stash@{0}` (auto-stash from the 2026-05-25 merge) has the same tree as `d57444a85e`; safe to drop.

### To-do

- [ ] **Chuck:** `git merge --no-ff feature/test-lab` into `unstable` (brings upstream + lab), then
  `git submodule update --init --recursive`, then push. Tag `chuck-stable-20261016` once play-tested.
- [ ] **Chuck:** decide whether `feature/phase2-mos-eisley-npcs` gets tested/merged or stays parked.
- [ ] **Phase 0.2 — DBSecret.** `config-local.lua` already sets a custom `Core3.DBSecret`, and both test
  accounts were hashed with it and log in, so the custom secret is live. Remaining: confirm `Chuckertons`
  and `chuck` still log in (if they predate the change they need `swg account create <user> <lvl> --reset`
  — ask first); fix the guide's SQL, which still hardcodes the old default `swgemus3cr37!`.
- [ ] Drop the redundant `stash@{0}` — with Chuck's OK.
- [ ] Server-side: `decreaseOnlineCharCount missing account` ERROR when a client drops before its scene
  finishes (`PlayerManagerImplementation.cpp:5350`). Harmless, upstream code; seen once from the bot race.
