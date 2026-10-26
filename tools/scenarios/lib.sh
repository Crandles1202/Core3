#!/usr/bin/env bash
#
# lib.sh — helpers for tools/scenarios/*.sh (sourced, not executed).
#
# A scenario drives the game with two hands:
#   bot  …   core3client as $BOT_USER / $CHAR  (acts: commands, radials, conversations, waits)
#   lab  …   runLuaFunction FbLabTests:<fn>:<args> on the server console (observes / sets up state)
# and reports with check/finish, printing PASS/FAIL lines that tools/swg understands.
#
# Env: SWG_BOT_USER (claude-player), SWG_BOT_CHAR (newest Lab* character of that account),
#      SWG_LABDIR (~/.swg-lab), SWG_LOGIN_HOST/PORT.

set -uo pipefail

SCENARIO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SWG=${SWG:-$SCENARIO_DIR/../swg}
REPO=$(cd "$SCENARIO_DIR/../.." && pwd)
BENCH=$(git -C "$REPO" worktree list --porcelain 2>/dev/null | head -n1 | sed 's/^worktree //'); [ -n "$BENCH" ] || BENCH=$REPO
BIN=${SWG_BIN:-$BENCH/MMOCoreORB/bin}   # the server and its client live in the bench, not in an agent's worktree; swg exports the instance's
LABDIR=${SWG_LABDIR:-$HOME/.swg-lab}
BOT_USER=${SWG_BOT_USER:-claude-player}
PASSFILE="$LABDIR/$BOT_USER.pass"
SCENARIO=${SCENARIO:-$(basename "${BASH_SOURCE[1]:-scenario}" .sh)}
BOTLOG="$LABDIR/scenario-$SCENARIO.bot.log"

CHAR=${SWG_BOT_CHAR:-$(mysql -N swgemu -e "SELECT c.firstname FROM characters c JOIN accounts a ON a.account_id = c.account_id WHERE a.username = '$BOT_USER' AND c.firstname LIKE 'Lab%' ORDER BY c.character_oid DESC LIMIT 1" 2>/dev/null)}

_pass=0; _fail=0

say()  { printf '%s\n' "$*"; }
die()  { printf 'FAIL %s — %s\n' "$SCENARIO.aborted" "$*"; finish; }

# check <name> <0|1> [detail]
check() {
	local name=$1 ok=$2 detail=${3:-}
	if [ "$ok" = 1 ] || [ "$ok" = 0 -a -z "$ok" ]; then :; fi
	if [ "$ok" = 1 ]; then
		say "PASS $SCENARIO.$name${detail:+ — $detail}"; _pass=$((_pass + 1))
	else
		say "FAIL $SCENARIO.$name${detail:+ — $detail}"; _fail=$((_fail + 1))
	fi
}

# check_gt <name> <a> <b> [detail] : a > b
check_gt() { check "$1" "$( [ "${2:-0}" -gt "${3:-0}" ] && echo 1 || echo 0 )" "${4:-$2 > $3}"; }
check_ge() { check "$1" "$( [ "${2:-0}" -ge "${3:-0}" ] && echo 1 || echo 0 )" "${4:-$2 >= $3}"; }
check_eq() { check "$1" "$( [ "${2:-}" = "${3:-}" ] && echo 1 || echo 0 )" "${4:-$2 == $3}"; }

finish() {
	say "INFO summary: $SCENARIO $_pass passed, $_fail failed"
	[ "$_fail" = 0 ] && exit 0 || exit 1
}

# lab <fn[:args]> [timeout]  → prints the INFO/ERROR lines the Lua helper produced
lab() {
	# the console runs commands on the main thread; during a delta save or a busy world the output can
	# arrive after the capture window closes — in that case ask once more
	local raw try
	for try in 1 2; do
		raw=$("$SWG" cmd "runLuaFunction FbLabTests:$1" --timeout "${2:-8}")
		grep -aq 'runLuaFunction FbLabTests:[A-Za-z]*: result=' <<<"$raw" && break   # the function ran to the end
		sleep 2
	done
	printf '%s\n' "$raw" | grep -aE '^(INFO|ERROR) ' | grep -av '^INFO FbLabTests start' || true
}

# lab_kv <fn[:args]> <key>  → value of key=… from the helper's INFO line
lab_kv() { lab "$1" | sed -n "s/.*[[:space:]]$2=\([^[:space:]]*\).*/\1/p" | head -n1; }

# ham <pool>  → current value of health|action|mind for $CHAR
ham() { lab "ham:$CHAR" | sed -n "s/.*[[:space:]]$1=\([0-9]*\)\/.*/\1/p" | head -n1; }

# bot <core3client action flags…>  (foreground; log in $BOTLOG). Returns the client's exit code.
bot() {
	[ -r "$PASSFILE" ] || die "no credentials at $PASSFILE"
	[ -n "$CHAR" ] || die "no Lab* character on account $BOT_USER (run: swg test bot)"
	( cd "$BIN" && CORE3_CLIENT_PASSWORD="$(cat "$PASSFILE")" ./core3client \
		--username "$BOT_USER" --login-host "${SWG_LOGIN_HOST:-127.0.0.1}" --login-port "${SWG_LOGIN_PORT:-44453}" \
		--character-firstname "$CHAR" "$@" >"$BOTLOG" 2>&1 )
}

# bot_bg <flags…>  → background client, pid in $BOT_PID
bot_bg() { bot "$@" & BOT_PID=$!; }

# wait_online [seconds]  → 0 once the server reports $CHAR online
_revived=0
wait_online() {
	local i
	for i in $(seq 1 "${1:-40}"); do
		if lab "isOnline:$CHAR" 5 | grep -aq "^INFO online"; then
			# the character is shared by every scenario of a gate: one left dead by an earlier one (the Knight trial's
			# enemy, 2026-10-22) failed everything after it, so the first login of a scenario puts it back on its feet
			lab "revive:$CHAR" 5 >/dev/null 2>&1   # every login: a wandering raider can kill a parked character between sessions
			return 0
		fi
		sleep 1
	done
	return 1
}

# bot_action_status <actionName>  → "ok" / "failed" / "skipped" for that action in the last client log
# status of the last action of a kind, from the client's end-of-run "=> #N {...}" results (falls
# back to any JSON line for older client builds, which only dumped the pre-run plan)
bot_action_status() {
	local line
	line=$(grep -ao "=> #[0-9]* {\"action\":\"$1\"[^}]*}" "$BOTLOG" | tail -n1)
	[ -n "$line" ] || line=$(grep -ao "{\"action\":\"$1\"[^}]*}" "$BOTLOG" | tail -n1)
	printf '%s\n' "$line" | sed -n 's/.*"status":"\([a-z]*\)".*/\1/p'
}
# count end-of-run results of a kind with a given status (ok|failed|skipped)
bot_action_count() { grep -ao "=> #[0-9]* {\"action\":\"$1\"[^}]*\"status\":\"$2\"" "$BOTLOG" | wc -l; }

bot_errors() { grep -a "ERROR" "$BOTLOG" | sed 's/^/   bot: /'; }

# Clear skies before every scenario (the sandstorm scenario sets its own afterwards): a natural Tatooine storm sends
# Tusken raiders to the outskirts where scenarios park their characters, and a dead character fails everything.
if [ "${SCENARIO:-}" != "sandstorm" ]; then lab "weatherSet:tatooine:0" 8 >/dev/null 2>&1 || true; fi
