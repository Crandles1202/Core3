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
- Changing a `.idl` file regenerates code and triggers a large rebuild.
- Lua-only changes need no rebuild: restart the server, or `reloadscreenplays` at the console for screenplays.

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

All via `tools/swg` (run from anywhere):

```bash
tools/swg start                 # start server in tmux "swg", wait for READY
tools/swg stop                  # send "shutdown", wait for clean exit
tools/swg cmd "<console cmd>"   # send a console command, print the log lines it produced
tools/swg logs --errors         # ERROR lines from the current run
tools/swg test unit             # core3 runUnitTests (gtest; server must be stopped)
tools/swg test lua              # runLuaFunction on the live Final Boss content checks → PASS/FAIL lines
tools/swg test bot              # core3client smoke test with claude-player
tools/swg test all
tools/swg snap save|load <name> # mysqldump + copy of bin/databases (server stopped). load = ask Chuck first
```

Test accounts: `claude-admin` (admin_level 15), `claude-player` (admin_level 0). Passwords live outside git.

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

## Current status

_Updated: 2026-10-16 (session 1, step 1 of lab setup)_

- `unstable` @ `d57444a85e` (Phase 2.1 Vex Renn), even with `origin/unstable`. Not yet merged with
  the 14 new `swgemu/unstable` commits.
- **Large uncommitted work in the tree** (Phase 2.x, never committed): ~12 new Mos Eisley NPCs (armor droid,
  cantina dancer/manager/musician, combat quartermaster, droid dispenser, imperial armorer, pet dealer,
  pet vet, property agent, smuggler goods, speeder dealer), FB field probe item, big rewrites of
  `fb_armory_droid.lua` and `fb_stim_dealer.lua`, buff tuning in `player_manager.lua`
  (backup at `player_manager.lua.fb_backup_pre_buff_tuning`). Must be committed to a feature branch or
  stashed before merging upstream.
- `stash@{0}` (auto-stash from the 2026-05-25 merge) has the same tree as HEAD, so it is redundant.
- `bin/core3` is dated 2026-05-24, older than commit `2c87042d5e` (C++/IDL changes) — rebuild before trusting it.
- `bin/core3client` does not exist yet (client build disabled in `~/bin/build`).
- Lab setup plan: 1 CLAUDE.md ✅ · 2 `tools/swg` · 3 test accounts · 4 upstream merge + baseline snap ·
  5 unit + Lua content tests · 6 bot smoke test.

### To-do

- [ ] **Phase 0.2 — change the default DBSecret.** Partly done already: `config-local.lua` sets a custom
  random `Core3.DBSecret` (read by `ConfigManager::getDBSecret()`, used as `SHA256(DBSecret + password + salt)`
  in `AccountManager.cpp`). Still to do: confirm `config.lua`'s default isn't winning; confirm existing
  accounts (`chuck`, others) were re-hashed with the new secret (`~/bin/run` resets `admin` to a legacy
  unsalted SHA1 on every start, which bypasses the secret); update the guide's account SQL to match.
  Rotating the secret means re-hashing every account — ask Chuck first (DB write outside test accounts).
- [ ] Decide what to do with the uncommitted Phase 2.x NPC work before the upstream merge.
- [ ] Drop the redundant `stash@{0}` (same tree as HEAD) — with Chuck's OK.
