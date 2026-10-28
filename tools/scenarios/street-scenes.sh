#!/usr/bin/env bash
# Phase 3.14: a street scene plays when a player is near its spot — the cast appears, the beats are spoken and seen by the
# client, the cast leaves afterwards; a scene reads idle again and keeps its cooldown.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
KEY=mos_eisley_jawa_haggle

N=$(lab "scenes" | grep -c '^INFO scene ')
check_ge "scenes_loaded" "$N" 10 "$N scenes"
SPOT=$(lab "scenes" | grep "^INFO scene scene=$KEY " | head -n1)
X=$(sed -n 's/.* x=\(-\?[0-9]*\).*/\1/p' <<<"$SPOT"); Y=$(sed -n 's/.* y=\(-\?[0-9]*\).*/\1/p' <<<"$SPOT")
check "scene_has_a_spot" "$( [ -n "$X" ] && [ -n "$Y" ] && echo 1 || echo 0 )" "$SPOT"

bot_bg --wait 70
wait_online || die "$CHAR never came online"
lab "travel:$CHAR:tatooine:$((X + 6)):$((Y + 6))" >/dev/null
sleep 2
ST=$(lab "sceneRun:$KEY" | grep '^INFO scene ' | head -n1)
check "scene_started" "$(grep -q 'active=1' <<<"$ST" && echo 1 || echo 0)" "$ST"
check "cast_spawned" "$(grep -q 'cast=2/2' <<<"$ST" && echo 1 || echo 0)" "$ST"
sleep 2
B=$(lab_kv "sceneBeat:$KEY" did)
check "first_beat_is_the_jawa" "$( [ "$B" = "say:jawa" ] && echo 1 || echo 0 )" "did=$B"
# let the scheduled beats run their course (8 beats, ~4 s each, then the cast leaves)
sleep 40
ST2=$(lab "scenes" | grep "^INFO scene scene=$KEY " | head -n1)
check "scene_idle_again" "$(grep -q 'active=0' <<<"$ST2" && echo 1 || echo 0)" "$ST2"
check "cast_gone" "$(grep -q 'cast=0/2' <<<"$ST2" && echo 1 || echo 0)" "$ST2"
check "cooldown_set" "$(sed -n 's/.*next_in=\([0-9]*\).*/\1/p' <<<"$ST2" | awk '{ print ($1 > 0) ? 1 : 0 }')" "$ST2"
wait "$BOT_PID"
check "client_heard_the_jawa" "$(grep -aq 'Utinni' "$BOTLOG" && echo 1 || echo 0)"
check "client_heard_the_farmer" "$(grep -aq 'vaporator coil' "$BOTLOG" && echo 1 || echo 0)"
finish
