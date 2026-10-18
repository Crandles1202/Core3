# SWG Pre-CU Server: Complete Setup & Operations Guide

Your personal Star Wars Galaxies Pre-CU server, built on SWGEmu Core3, running on Windows via WSL2 Debian 12\.

**Your GitHub fork:** [https\://github.com/crandles1202/Core3](https://github.com/crandles1202/Core3) **Your WSL distro:** `Debian` (Debian 12 bookworm) **Your Linux username:** `chuck` **Your server source location:** `~/workspace/Core3` (inside WSL) **Your tre files location:** `/tre` (inside WSL)

---

## Table of contents

1. [Quick reference](#quick-reference)  
2. [Architecture overview](#architecture-overview)  
3. [Daily operations](#daily-operations)  
4. [Connecting a client](#connecting-a-client)  
5. [Account management](#account-management)  
6. [In-game admin commands](#in-game-admin-commands)  
7. [Customizing the server](#customizing-the-server)  
8. [Pulling upstream changes](#pulling-upstream-changes)  
9. [The gotchas reference](#the-gotchas-reference)  
10. [File and path reference](#file-and-path-reference)  
11. [From-scratch rebuild](#from-scratch-rebuild)  
12. [Troubleshooting](#troubleshooting)

---

## Quick reference

The five things you'll do most often.

### Start the server

wsl \-d Debian

cd \~/workspace/Core3

run

Wait for `READY` and the `>` prompt. Server is up.

### Stop the server cleanly

In the server console (the `>` prompt):

shutdown

Wait for it to exit. **Don't `Ctrl+C`** — that can leave state unwritten.

### Rebuild after code changes

cd \~/workspace/Core3

build

3–10 minutes for incremental builds, \~30 minutes for clean.

### Tail the live server log

tail \-f \~/workspace/Core3/MMOCoreORB/bin/log/core3.log

### Get into the database

mysql \-u swgemu \-p'<DB\_PASSWORD>' swgemu

(Password redacted from the repo copy. It lives in `~/.my.cnf`, so plain `mysql swgemu` works without `-p`.)

---

## Architecture overview

What's running, and where.

Windows host (your PC)

├─ C:\\SWGDev\\Core3                  Optional Windows clone of your fork (for browsing in VS Code)

│  └─ wsl2\\bootstrap.bat            One-time WSL setup helper

│

└─ WSL2 → Debian distro

   ├─ /home/chuck/

   │  ├─ workspace/Core3/           THE running server source (your fork, on Linux fs)

   │  │  ├─ MMOCoreORB/             Server code \+ game scripts

   │  │  │  ├─ src/                 C++ source

   │  │  │  ├─ bin/                 Compiled binary \+ Lua scripts \+ config \+ tre data

   │  │  │  │  ├─ conf/

   │  │  │  │  │  ├─ config.lua     Defaults (don't edit)

   │  │  │  │  │  └─ config-local.lua   Your overrides (DB password, etc.)

   │  │  │  │  ├─ scripts/          Game logic in Lua (hot-reloadable)

   │  │  │  │  ├─ log/              Server log files

   │  │  │  │  └─ core3             The compiled server binary

   │  │  │  └─ utils/engine3/       engine3 submodule (C++ engine)

   │  │  └─ wsl2/, docker/, linux/  Setup scripts

   │  ├─ bin/                       Wrapper scripts: \`build\`, \`run\`, \`gdb\_settings\`

   │  ├─ .env                       Database password and other secrets

   │  └─ .my.cnf                    MySQL client config (auto-uses DB password)

   │

   ├─ /tre/                         The 53 .tre data files from your SWG client

   └─ /var/lib/mysql/               MariaDB data directory (swgemu DB lives here)

**Key insight:** The server runs entirely inside WSL2 on the Linux filesystem (`/home/chuck/...`). The `C:\SWGDev\Core3` folder on Windows is optional — useful for browsing source in VS Code, but it's not what runs.

---

## Daily operations

### Starting your day

\# In PowerShell — only needed if you've rebooted Windows

wsl \-d Debian

\# Now inside Debian

cd \~/workspace/Core3

run

### Stopping your day

In the server console:

shutdown

Then close the WSL window. (Optional: `wsl --shutdown` from PowerShell to fully stop the WSL VM and free RAM.)

### Run the server in the background

If you want to close the window but keep the server running, use `screen` or `tmux`:

sudo apt-get install \-y tmux        \# one-time install

tmux new \-s swg

cd \~/workspace/Core3

run

\# detach with Ctrl+B then D

\# reattach later with: tmux attach \-t swg

### View logs while it runs

\# Live tail

tail \-f \~/workspace/Core3/MMOCoreORB/bin/log/core3.log

\# Search for errors

grep \-i error \~/workspace/Core3/MMOCoreORB/bin/log/core3.log | tail \-50

### Restart MariaDB if it gets weird

sudo systemctl restart mariadb

(This requires `systemd=true` in `/etc/wsl.conf`, which the setup already enabled.)

---

## Connecting a client

### One-time client setup

1. Install **Microsoft Visual C++ 2010 Redistributable (x86)** from [https\://www\.microsoft.com/en-us/download/details.aspx?id=26999](https://www.microsoft.com/en-us/download/details.aspx?id=26999) (required by the SWGEmu Launchpad)  
2. Have an SWG client installed (the one your `.tre` files came from)  
3. Find or download SWGEmu Launchpad

### Point the client at your server

Edit `login.cfg` in your SWG client folder (create it if missing):

\[ClientGame\]

loginServerAddress0=172.19.53.128

loginServerPort0=44453

⚠️ **The IP `172.19.53.128` is your current WSL2 IP and will change on Windows reboot.** Two long-term fixes:

**Recommended: enable mirrored networking** so `127.0.0.1` actually works.

Create `C:\Users\rac35\.wslconfig` with:

\[wsl2\]

networkingMode=mirrored

Then in PowerShell:

wsl \--shutdown

After this, you can put `127.0.0.1` in `login.cfg` and the galaxy table forever. No more IP chasing.

**Or: re-check and update after each reboot:**

hostname \-I    \# get current WSL2 IP

Then update both `login.cfg` *and* the MySQL `galaxy` table (see the [galaxy address gotcha](#galaxy-address-is-in-mysql-not-config-localllua)).

### Install the Final Boss data archive (finalboss.tre)

Custom names, titles and messages live in `finalboss.tre`, built from `tre-src/` in the repo. The server
reads it from `/tre` (installed automatically by `tools/swg start`); the client needs the same file in its
folder plus a `searchTree_00_N=finalboss.tre` line at the top of `swgemu_live.cfg`. One command does both,
once it knows the folder (remembered in `~/.swg-lab/client-dir`):

```bash
tools/swg tre install --client '/mnt/c/path/to/your/SWGEmu'
```

Rerun `tools/swg tre install` after every change to `tre-src/` (the server side happens on `swg start`).
Without the file the client shows raw ids such as `@fb_lab:probe_first` instead of text.

### Launch the client

Either through SWGEmu Launchpad (with your custom server selected), or by running `SwgClient_r.exe` directly. The direct launch skips the launcher news screen and is more reliable.

---

## Account management

### Create a new account

mysql \-u swgemu \-p'<DB\_PASSWORD>' swgemu \<\<'SQL'

SET @username \= 'newuser';

SET @password \= 'theirpassword';

SET @db\_secret \= '<Core3.DBSecret from bin/conf/config-local.lua>';

SET @salt \= SUBSTRING(SHA1(RAND()), 1, 32);

INSERT INTO accounts (username, password, station\_id, salt, admin\_level)

VALUES (@username, SHA2(CONCAT(@db\_secret, @password, @salt), 256), 1, @salt, 0);

SELECT account\_id, username, admin\_level FROM accounts WHERE username \= @username;

SQL

`admin_level` values:

- `0` \= normal player  
- `15` \= full admin / dev (god mode, all slash commands)

### Reset a password

mysql \-u swgemu \-p'<DB\_PASSWORD>' swgemu \<\<'SQL'

SET @username \= 'chuck';

SET @new\_password \= 'newpassword';

SET @db\_secret \= '<Core3.DBSecret from bin/conf/config-local.lua>';

UPDATE accounts

SET password \= SHA2(CONCAT(@db\_secret, @new\_password, salt), 256\)

WHERE username \= @username;

SQL

### Promote an existing account to admin

mysql \-u swgemu \-p'<DB\_PASSWORD>' swgemu \\

  \-e "UPDATE accounts SET admin\_level \= 15 WHERE username \= 'someuser';"

### How the password hash works

For accounts with a salt (any modern account):

stored\_password \= SHA256(DBSecret \+ password \+ salt)

Where `DBSecret` is `Core3.DBSecret` from `config-local.lua` (this server uses its own value since 2026-10-16; `config.lua` keeps the upstream default and is overridden). Hex output, stored as a string. `tools/swg account create <user> <level> [--reset]` does all of this for you.

For legacy accounts with empty salt (very old):

stored\_password \= SHA1(password)

You'll almost certainly never see one of those.

---

## In-game admin commands

You need `admin_level >= 15` for most of these. Type them in the in-game chat.

### Movement and teleport

| Command | What it does |
| :---- | :---- |
| `/setGodMode` | Toggle god mode (invincibility, can fly, no aggro) |
| `/jumpTo <planet> <x> <y>` | Teleport to coords on a planet |
| `/jumpClient <character>` | Teleport to another player |
| `/summon <character>` | Pull a player to your location |
| `/setSpeed <multiplier>` | Movement speed multiplier (try `5`, then `1` to revert) |
| `/getCoordinates` | Print your current X/Y/Z |

Planet names: `tatooine`, `naboo`, `corellia`, `dantooine`, `rori`, `talus`, `lok`, `dathomir`, `endor`, `yavin4`, `tutorial`

### Items and inventory

| Command | What it does |
| :---- | :---- |
| `/createItem <template>` | Spawn an item by its iff/template path |
| `/grant <skill_name>` | Grant a skill to yourself |
| `/setMoney <amount>` | Set your cash on hand |
| `/setBank <amount>` | Set your bank balance |
| `/addExperience <type> <amount>` | Grant XP (e.g. `combat_general 100000`) |
| `/dropItem` | Drop the item you have selected |

### Player and character

| Command | What it does |
| :---- | :---- |
| `/setHam <amount>` | Set HAM (Health/Action/Mind) to value |
| `/info` | Show info about your character |
| `/promote <character> <level>` | Promote another player's admin level |
| `/ban <character>` | Ban a player |
| `/kick <character>` | Disconnect a player |

### Server and world

| Command | What it does |
| :---- | :---- |
| `/server help` | List all admin commands available to you |
| `/server info` | Show server status |
| `/broadcast <message>` | Broadcast to all online players |
| `/lookup <id>` | Look up an object by ID |
| `/object` | Open object editor for whatever you click |
| `/destroyObject <id>` | Delete an object by ID |

> Commands vary by Core3 version. **`/server help` in-game is the source of truth** — it shows exactly what your build supports.

---

## Customizing the server

### Where game logic lives

Most behavior is in **Lua**, not C++. That means many changes are hot-reloadable and need no rebuild.

\~/workspace/Core3/MMOCoreORB/bin/scripts/

├─ managers/                    Player creation, XP rates, loot management, etc.

├─ mobile/                      Creature stats, AI, spawn defs

├─ loot/                        Loot tables and drop chances

├─ object/

│  ├─ tangible/                 Wearable items, weapons, vendor stock

│  └─ ...

├─ player/                      Player-related logic

├─ commands/                    In-game slash commands

└─ screenplays/                 Quests, missions, events

### Easy first-customization ideas

**Bump starting credits.** Find the player creation script:

grep \-rn 'creditBalance\\|startingCredits' \~/workspace/Core3/MMOCoreORB/bin/scripts/managers/

**Boost XP rates.** Look for an XP multiplier in:

ls \~/workspace/Core3/MMOCoreORB/bin/scripts/managers/ | grep \-i xp

**Change creature stats.** Each creature is its own Lua file:

ls \~/workspace/Core3/MMOCoreORB/bin/scripts/mobile/creature/

**Tune loot.** Loot tables and item templates:

ls \~/workspace/Core3/MMOCoreORB/bin/scripts/loot/loot\_groups/

### Reload scripts without restarting

Some Lua changes can be reloaded in-game via:

/server reload

Or by editing then `/server reloadScreenPlays`. Big structural changes still need a restart. C++ changes always need `build` \+ restart.

### Commit your customizations to your fork

cd \~/workspace/Core3

git checkout \-b feature/double-credits      \# name your branch

\# ... edit files ...

git diff                                    \# review what changed

git add \-A

git commit \-m "Double starting credits"

git push \-u origin feature/double-credits

Open a PR against your own `unstable` branch on GitHub if you want code review tooling, or just merge locally.

---

## Pulling upstream changes

Keep up with SWGEmu fixes.

### Check what's new upstream

cd \~/workspace/Core3

git fetch swgemu                            \# canonical SWGEmu

git fetch mtg                               \# ModTheGalaxy (community custom-content fork)

git log \--oneline HEAD..swgemu/unstable | head \-20      \# what's new in SWGEmu

git log \--oneline HEAD..mtg/update-wip | head \-20       \# what's new in mtgserver

### Merge SWGEmu fixes into your branch

git checkout unstable

git merge swgemu/unstable

\# resolve conflicts if any

git push origin unstable

### Cherry-pick a single commit from mtgserver

git log mtg/update-wip \--oneline | head            \# find the SHA

git cherry-pick \<sha\>

### Update the engine3 submodule

cd \~/workspace/Core3

git submodule update \--remote                       \# pull latest engine3

\# or to lock to a specific version, cd into the submodule and git checkout \<sha\>

### Rebuild after pulling

build

---

## The gotchas reference

Every nasty surprise we hit, in one place. Read this section before you ever rebuild from scratch.

### WSL installs Debian 13 by default; SWGEmu bootstrap only supports Debian 11 or 12

**Symptom:** `bootstrap.bat` exits with `!! ERROR: Current support is for debian versions 11|12 only.`

**Fix:** Don't use Microsoft Store's Debian (always latest). Import a Debian 12 rootfs from the official Debian Docker image:

wsl \--unregister Debian

mkdir C:\\WSL\\Debian12 \-Force

cd C:\\WSL\\Debian12

docker pull debian:12

docker create \--name temp-debian debian:12

docker export temp-debian \-o C:\\WSL\\Debian12\\debian12-rootfs.tar

docker rm temp-debian

wsl \--import Debian C:\\WSL\\Debian12 C:\\WSL\\Debian12\\debian12-rootfs.tar \--version 2

wsl \--set-default Debian

### Debian cloud "nocloud" tarball is NOT a WSL-importable rootfs

**Symptom:** `wsl --import` fails with `WSL_E_NOT_A_LINUX_DISTRO`.

**Why:** That tarball is a disk image, not a flat filesystem rootfs.

**Fix:** Use the Docker-exported rootfs (above) or the LXC project's images.

### `bootstrap.bat` is a Windows batch file, run it from PowerShell not bash

**Symptom:** `bash: .bootstrap.bat: command not found`

**Fix:** Exit WSL with `exit`, then run `cd C:\SWGDev\Core3\wsl2; .\bootstrap.bat` from PowerShell. The .bat file *calls into* WSL itself.

### Bootstrap-installed rootfs is missing Java

**Symptom:** Build fails with `Could NOT find Java (missing: Java_JAVA_EXECUTABLE Runtime)`

**Fix:**

sudo apt-get update && sudo apt-get install \-y default-jre

### `build` script searches upward for `.git` — be in the right directory\!

**Symptom:** Build runs but creates artifacts in `/mnt/c/SWGDev/Core3/MMOCoreORB/build/` (extremely slow). You wanted it to build the Linux-side clone.

**Why:** The `build` wrapper script walks up from your current directory looking for a `.git`. If you're in `/mnt/c/SWGDev/Core3/wsl2`, it finds the Windows clone and builds that.

**Fix:** Always `cd ~/workspace/Core3` before running `build`.

### Building on `/mnt/c/` (Windows filesystem) is brutally slow

**Symptom:** Build takes 30+ minutes when it should take 3\.

**Why:** WSL2's `/mnt/c/` mount has high per-file overhead from translating Linux semantics to NTFS.

**Fix:** Always build on the native Linux filesystem (`/home/...` or `/root/...`).

### `config-local.lua` is gitignored — wiping the repo destroys your DB password config

**Symptom:** After re-cloning, server fails with `1045: Access denied for user 'swgemu'@'localhost' (using password: YES)`

**Why:** `config-local.lua` is intentionally not in git (so secrets don't leak). It got nuked when you did `rm -rf Core3 && git clone`.

**Fix:** Recreate `config-local.lua` with your DB password. To prevent this happening again, store it outside the repo and symlink:

mv \~/workspace/Core3/MMOCoreORB/bin/conf/config-local.lua \~/config-local.lua

ln \-s \~/config-local.lua \~/workspace/Core3/MMOCoreORB/bin/conf/config-local.lua

### Password hash formula is non-obvious

The actual formula in Core3:

SHA256(DBSecret \+ password \+ salt)

Not SHA1, not SHA256 of just password+salt — the DBSecret prefix matters. See [Account management](#account-management) for the correct SQL.

### `DBSecret` default is hardcoded and well-known

**The default `DBSecret` is `swgemus3cr37!`**, set in `config.lua`. The file's own comment says "Change this\!"

**Done on this server (Phase 0.2, 2026-10-16):** `config-local.lua` sets `Core3.DBSecret` to a private
64-character value (it is the `Core3` table entry that `ConfigManager::getDBSecret` reads, not a top-level
`DBSecret`), `config.lua` is left at the upstream default, and all four accounts were re-hashed with
`tools/swg account create <user> <level> --reset`. Changing the secret again means re-hashing every account.

### SWGEmu uses UDP, not TCP

**Symptom:** `Test-NetConnection` says the port isn't reachable, but the server is fine.

**Why:** SWG client/server traffic is UDP. `Test-NetConnection` only tests TCP. The status port (44455) is TCP, but login/zone/ping are all UDP.

**Fix:** Use `ss -ulnp` (not `-tlnp`) inside WSL to see UDP listeners.

### WSL2 UDP forwarding to localhost is broken/flaky

**Symptom:** Client hangs at "Connecting to the Login Server..." even though TCP services on the same WSL2 distro work fine over `127.0.0.1` from Windows.

**Fix (short-term):** Use the WSL2 VM's IP instead of `127.0.0.1`. Get it with `hostname -I` from WSL.

**Fix (permanent):** Enable mirrored networking. Create `C:\Users\rac35\.wslconfig`:

\[wsl2\]

networkingMode=mirrored

Then `wsl --shutdown` in PowerShell. After this, `127.0.0.1` works for UDP from Windows into WSL2 and survives reboots.

### Galaxy address is in MySQL, not `config-local.lua`

**Symptom:** Login works (you see the galaxy list), but clicking the galaxy hangs at "Connecting to the Galaxy..."

**Why:** The login server reads the galaxy connection address from the `galaxy` table and hands it to the client. The default is `127.0.0.1`, which hits the same UDP-forwarding problem.

**Fix:**

mysql \-u swgemu \-p'<DB\_PASSWORD>' swgemu \\

  \-e "UPDATE galaxy SET address \= '172.19.53.128' WHERE galaxy\_id \= 2;"

Or after enabling mirrored networking, set it to `127.0.0.1` and forget about it.

### WSL2 IP changes on every Windows reboot

**Symptom:** Yesterday's `login.cfg` and `galaxy.address` no longer work after a reboot.

**Fix:** Mirrored networking (see above). One-time setup, permanent solution.

### SWGEmu Launchpad needs MSVCR100.dll

**Symptom:** `SWGEmuLaunchpad.exe - System Error: The code execution cannot proceed because MSVCR100.dll was not found.`

**Fix:** Install Microsoft Visual C++ 2010 Redistributable (x86) from [https\://www\.microsoft.com/en-us/download/details.aspx?id=26999](https://www.microsoft.com/en-us/download/details.aspx?id=26999)

### Bootstrap clones its own Core3 separately from your fork

**Why it matters:** After bootstrap, `/home/chuck/workspace/Core3` is a fresh swgemu/Core3 clone, not your GitHub fork. If you build and run from there without changes, you're not actually exercising your fork.

**Fix:** Replace it with your fork (this guide already did):

cd \~/workspace

rm \-rf Core3

git clone \--recurse-submodules https\://github.com/crandles1202/Core3.git

cd Core3

git remote add swgemu https\://github.com/swgemu/Core3.git

git remote set-url \--push swgemu no\_push

git remote add mtg https\://github.com/ModTheGalaxy/mtgserver.git

git remote set-url \--push mtg no\_push

### Don't `Ctrl+C` the running server

**Why:** It can leave state unwritten to MariaDB, lose recent player progress, and occasionally corrupt the database.

**Do:** Type `shutdown` at the `>` prompt and wait for it to exit cleanly.

---

## File and path reference

### Inside WSL

| Path | What |
| :---- | :---- |
| `~/workspace/Core3/` | Your fork (working copy) |
| `~/workspace/Core3/MMOCoreORB/bin/` | Where `core3` binary lives, plus configs/scripts/log |
| `~/workspace/Core3/MMOCoreORB/bin/core3` | The compiled server binary |
| `~/workspace/Core3/MMOCoreORB/bin/conf/config.lua` | Default config (don't edit) |
| `~/workspace/Core3/MMOCoreORB/bin/conf/config-local.lua` | Your overrides (DB password, etc.) |
| `~/workspace/Core3/MMOCoreORB/bin/scripts/` | Lua game logic |
| `~/workspace/Core3/MMOCoreORB/bin/log/core3.log` | Live server log |
| `~/workspace/Core3/MMOCoreORB/utils/engine3/` | engine3 submodule |
| `~/workspace/Core3/MMOCoreORB/sql/swgemu.sql` | Database schema |
| `~/bin/build` | The `build` wrapper script |
| `~/bin/run` | The `run` wrapper script |
| `~/.env` | DB password and other secrets |
| `~/.my.cnf` | MySQL client config (auto-uses DB password) |
| `/tre/` | Your 53 SWG client `.tre` data files |
| `/var/lib/mysql/` | MariaDB data directory |

### On Windows

| Path | What |
| :---- | :---- |
| `C:\SWGDev\Core3\` | Optional Windows clone of your fork (for browsing in VS Code; not used at runtime) |
| `C:\SWGDev\Core3\wsl2\bootstrap.bat` | One-time WSL setup helper |
| `C:\SWGDev\SWG-PreCU-Server-Guide.md` | This document |
| `C:\WSL\Debian12\debian12-rootfs.tar` | The original Debian 12 rootfs (can be deleted now) |
| `C:\Users\rac35\.wslconfig` | WSL2 settings (use for `networkingMode=mirrored`) |

### Accessing WSL files from Windows

In File Explorer or VS Code, use:

\\\\wsl\$\\Debian\\home\\chuck\\workspace\\Core3

Or in VS Code, install the **WSL** extension and use `Remote-WSL: Open Folder in WSL`. That's the right way to develop server code on Windows.

### Network ports

| Port | Protocol | What |
| :---- | :---- | :---- |
| 44453 | UDP | Login server |
| 44455 | TCP | HTTP-ish status endpoint |
| 44462 | UDP | Ping server |
| 44463 | UDP | Zone server |

---

## From-scratch rebuild

If you ever need to do this from zero (new machine, full reset, etc.), here's the abbreviated path.

### 1\. Fork on GitHub (once)

Fork [https\://github.com/swgemu/Core3](https://github.com/swgemu/Core3) to your account. Already done — yours lives at [https\://github.com/crandles1202/Core3](https://github.com/crandles1202/Core3).

### 2\. Set up WSL2 with Debian 12

In PowerShell as admin:

\# Install WSL2 if not already

wsl \--install \--no-distribution

\# Remove any auto-installed Debian (it'll be wrong version)

wsl \--unregister Debian

\# Get a proper Debian 12 rootfs via Docker (requires Docker Desktop)

mkdir C:\\WSL\\Debian12 \-Force

cd C:\\WSL\\Debian12

docker pull debian:12

docker create \--name temp-debian debian:12

docker export temp-debian \-o C:\\WSL\\Debian12\\debian12-rootfs.tar

docker rm temp-debian

\# Import as a WSL distro named "Debian"

wsl \--import Debian C:\\WSL\\Debian12 C:\\WSL\\Debian12\\debian12-rootfs.tar \--version 2

wsl \--set-default Debian

### 3\. Create your user inside Debian

wsl \-d Debian

Inside:

apt-get update

apt-get install \-y sudo

adduser chuck

usermod \-aG sudo chuck

printf "\[user\]\\ndefault=chuck\\n\[boot\]\\nsystemd=true\\n" \> /etc/wsl.conf

exit

wsl \--shutdown

wsl \-d Debian

### 4\. Get the bootstrap scaffolding

Clone your fork to Windows first, just to grab `bootstrap.bat`:

git clone https\://github.com/crandles1202/Core3.git C:\\SWGDev\\Core3

cd C:\\SWGDev\\Core3\\wsl2

.\\bootstrap.bat

When it asks for tre files, point it at one .tre from your SWG client install. **Save the generated MariaDB password.**

### 5\. Enable mirrored networking (do this once, save yourself pain)

Create `C:\Users\rac35\.wslconfig`:

\[wsl2\]

networkingMode=mirrored

wsl \--shutdown

wsl \-d Debian

### 6\. Replace bootstrap's Core3 clone with your fork

sudo apt-get install \-y default-jre

cd \~/workspace

rm \-rf Core3

git clone \--recurse-submodules https\://github.com/crandles1202/Core3.git

cd Core3

git remote add swgemu https\://github.com/swgemu/Core3.git

git remote set-url \--push swgemu no\_push

git remote add mtg https\://github.com/ModTheGalaxy/mtgserver.git

git remote set-url \--push mtg no\_push

git fetch swgemu mtg

### 7\. Recreate config-local.lua (with the password from step 4\)

cat \> \~/config-local.lua \<\<'EOF'

GalaxyName \= "core3-docker"

ZoneGalaxyID \= 2

DBHost \= "127.0.0.1"

DBPort \= "3306"

DBName \= "swgemu"

DBUser \= "swgemu"

DBPass \= "YOUR\_GENERATED\_PASSWORD\_HERE"

LoginPort \= "44453"

PingPort \= "44462"

StatusPort \= "44455"

ZoneServerPort \= "44463"

MakeLogin \= "1"

MakeZone \= "1"

MakePing \= "1"

MakeStatus \= "1"

LogSync \= "1"

LogFileLevel \= "4"

ProgressMonitors \= "false"

TrePath \= "/tre"

ZonesEnabled \= { "corellia", "dantooine", "dathomir", "dungeon1", "endor", "lok", "naboo", "rori", "talus", "tatooine", "tutorial", "yavin4" }

EOF

ln \-s \~/config-local.lua \~/workspace/Core3/MMOCoreORB/bin/conf/config-local.lua

### 8\. Build and run

build

run

### 9\. Create your admin account and update galaxy address

\# Create account

mysql \-u swgemu \-p'YOUR\_DB\_PASSWORD' swgemu \<\<'SQL'

SET @username \= 'chuck';

SET @password \= '<choose\_a\_password>';

SET @db\_secret \= '<Core3.DBSecret from bin/conf/config-local.lua>';

SET @salt \= SUBSTRING(SHA1(RAND()), 1, 32);

INSERT INTO accounts (username, password, station\_id, salt, admin\_level)

VALUES (@username, SHA2(CONCAT(@db\_secret, @password, @salt), 256), 1, @salt, 15);

SQL

\# Set galaxy address to 127.0.0.1 (works because mirrored networking is on)

mysql \-u swgemu \-p'YOUR\_DB\_PASSWORD' swgemu \\

  \-e "UPDATE galaxy SET address \= '127.0.0.1' WHERE galaxy\_id \= 2;"

### 10\. Set up the client

`login.cfg` in your SWG client folder:

\[ClientGame\]

loginServerAddress0=127.0.0.1

loginServerPort0=44453

Log in. Done.

---

## Troubleshooting

### Build fails with cmake error about a missing dep

Re-run apt install for the deps:

sudo apt-get install \-y build-essential libmariadb-dev libmariadb-dev-compat \\

  liblua5.3-dev libdb5.3-dev libssl-dev cmake git default-jre libboost-all-dev \\

  gdb ninja-build libjemalloc-dev clang-19 lld-19

If clang-19 isn't available, install via LLVM's apt repo:

sudo apt-get install \-y apt-transport-https ca-certificates wget gnupg lsb-release

wget \-O /tmp/llvm.sh https\://apt.llvm.org/llvm.sh

chmod \+x /tmp/llvm.sh

sudo /tmp/llvm.sh 19 all

sudo bash \-c 'cd /usr/bin; for i in ../lib/llvm-\*/bin/\*; do ln \-sfv \$i .; done'

### Server crashes immediately on `run` with "Access denied for user 'swgemu'"

`config-local.lua` is missing or has wrong password. See [the gotcha](#config-locallua-is-gitignored--wiping-the-repo-destroys-your-db-password-config).

### Server starts but client hangs at "Connecting to the Login Server"

UDP forwarding. Either use `hostname -I` for the actual WSL2 IP in `login.cfg`, or enable mirrored networking. See [WSL2 UDP forwarding gotcha](#wsl2-udp-forwarding-to-localhost-is-brokenflaky).

### Login works but client hangs at "Connecting to the Galaxy"

`galaxy` table has wrong address. See [the gotcha](#galaxy-address-is-in-mysql-not-config-localllua).

### Login fails with "Wrong Password"

You used the wrong hash formula when creating the account. See [Account management](#account-management) for the correct SQL.

### Server says `Could not load tre file: /tre/bottom.tre`

Either `/tre` is empty or missing tre files. Verify:

ls /tre | wc \-l       \# should be 30+

If empty, copy from your Windows client install:

cp /mnt/c/path/to/swg/client/\*.tre /tre/

### MariaDB won't start after a WSL restart

systemd isn't running:

cat /etc/wsl.conf

\# should contain:

\# \[boot\]

\# systemd=true

If missing, add it, then `wsl --shutdown` from PowerShell and restart WSL.

### `build` fails with "ninja: error: ..." about a stale file

Clean build:

cd \~/workspace/Core3/MMOCoreORB

rm \-rf build/

cd \~/workspace/Core3

build

### Server log is full of warnings, is that bad?

Yellow `WARNING` lines are mostly normal on Pre-CU Core3 — there are dozens of unimplemented features that warn loudly. Red `ERROR` lines are worth investigating; `FATAL` lines crash the server.

---

## Resources

- **Your fork:** [https\://github.com/crandles1202/Core3](https://github.com/crandles1202/Core3)  
- **SWGEmu upstream:** [https\://github.com/swgemu/Core3](https://github.com/swgemu/Core3)  
- **engine3 source:** [https\://github.com/swgemu/engine3](https://github.com/swgemu/engine3)  
- **ModTheGalaxy (custom content fork):** [https\://github.com/ModTheGalaxy/mtgserver](https://github.com/ModTheGalaxy/mtgserver)  
- **SWGEmu forums (dev discussion):** [https\://www\.swgemu.com/forums/forumdisplay.php?f=10](https://www.swgemu.com/forums/forumdisplay.php?f=10)  
- **SWGEmu wiki:** [https\://swgemulator.fandom.com/wiki/Servers](https://swgemulator.fandom.com/wiki/Servers)  
- **mtgserver wiki (custom content guides):** [https\://github.com/ModTheGalaxy/mtgserver/wiki](https://github.com/ModTheGalaxy/mtgserver/wiki)

---

*Document version: 1.0. Generated from the setup work done on 2026-05-22. Update as you learn more.*  
