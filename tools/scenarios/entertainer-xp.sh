#!/usr/bin/env bash
# Phase 1.10: no-grind entertainer. A novice entertainer who dances alone and never flourishes
# still earns dance XP every 10 s tick (stock Core3 pays nothing on a tick without a flourish,
# and nothing extra without an audience).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DANCE_SECONDS=25     # two full entertainer ticks (10 s each) plus slack

# --- stage: make sure the character can dance ------------------------------------------------
bot_bg --wait 15
wait_online || die "$CHAR never came online"
lab "skill:$CHAR:social_entertainer_novice" >/dev/null   # grants dance "basic"; no-op if known
lab "heal:$CHAR:action:100000" >/dev/null                 # dancing drains action
XP0=$(lab_kv "xp:$CHAR:dance" amount)
say "INFO dance xp before: $XP0"
wait "$BOT_PID"

# --- act: dance "basic" with no flourishes and nobody watching --------------------------------
# startdance/stopdance never send CommandQueueRemove, so the client must not wait for one.
# A performance survives a disconnect, so stop any leftover dance first for a clean measurement.
bot --wait 2 --command stopdance --command-nowait --wait 2 \
    --command startdance --args basic --command-nowait --wait "$DANCE_SECONDS" \
    --command stopdance --command-nowait --wait 1
RC=$?
check_eq "client_exit_0" "$RC" "0"
check "server_said_dance_started" "$(grep -aq '@performance:dance_start_self' "$BOTLOG" && echo 1 || echo 0)"
[ "$RC" = 0 ] || bot_errors

# --- observe --------------------------------------------------------------------------------
XP1=$(lab_kv "xp:$CHAR:dance" amount)
say "INFO dance xp after:  $XP1  (gained $((XP1 - XP0)) in ${DANCE_SECONDS}s, no flourish, no audience)"
check_gt "dance_xp_without_flourish_or_audience" "${XP1:-0}" "${XP0:-0}" "dance xp $XP0 -> $XP1"

finish
