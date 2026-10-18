#!/usr/bin/env bash
# Phase 3.2: faction patrols. Each route has a live squad; with the character nearby (AI only moves
# with a player in range) a forced step sends the Imperial squad towards its next point and the
# leader's position changes within 20 s; the followers stay with the leader.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROUTE=1
ST=$(lab "patrols" | grep "^INFO patrol route=$ROUTE " | head -1)
check "route_has_squad" "$(printf '%s' "$ST" | grep -q 'leader=[1-9]' && echo 1 || echo 0)" "$ST"
MEMBERS=$(printf '%s\n' "$ST" | sed -n 's/.*members=\([0-9]*\)\/\([0-9]*\).*/\1\/\2/p')
check "members_alive" "$( [ "${MEMBERS%/*}" = "${MEMBERS#*/}" ] && echo 1 || echo 0 )" "members $MEMBERS"
PLANET=$(printf '%s\n' "$ST" | sed -n 's/.*planet=\([a-z0-9_]*\).*/\1/p')
LX=$(printf '%s\n' "$ST" | sed -n 's/.*leader=[0-9]* x=\([-0-9.]*\).*/\1/p' | cut -d. -f1)
LY=$(printf '%s\n' "$ST" | sed -n 's/.*leader=[0-9]* x=[-0-9.]* y=\([-0-9.]*\).*/\1/p' | cut -d. -f1)

bot_bg --wait 45
wait_online || die "$CHAR never came online"
lab "travel:$CHAR:$PLANET:$((LX + 6)):$((LY + 6))" >/dev/null
sleep 2
R=$(lab_kv "patrolStep:$ROUTE" result)
check "step_accepted" "$(printf '%s' "$R" | grep -qE '^[0-9]+$' && echo 1 || echo 0 )" "step -> $R"
sleep 20
ST2=$(lab "patrols" | grep "^INFO patrol route=$ROUTE " | head -1)
LX2=$(printf '%s\n' "$ST2" | sed -n 's/.*leader=[0-9]* x=\([-0-9.]*\).*/\1/p' | cut -d. -f1)
LY2=$(printf '%s\n' "$ST2" | sed -n 's/.*leader=[0-9]* x=[-0-9.]* y=\([-0-9.]*\).*/\1/p' | cut -d. -f1)
MOVED=$(( (LX2 - LX) * (LX2 - LX) + (LY2 - LY) * (LY2 - LY) ))
say "INFO leader moved from $LX,$LY to $LX2,$LY2 (squared distance $MOVED)"
check "leader_moved" "$( [ "$MOVED" -ge 4 ] && echo 1 || echo 0 )" "at least 2 m in 20 s (short legs near the loop end move slowly)"
check "members_still_alive_after_step" "$(printf '%s' "$ST2" | grep -q "members=${MEMBERS#*/}/${MEMBERS#*/}" && echo 1 || echo 0)" "$ST2"
wait "$BOT_PID"

finish
