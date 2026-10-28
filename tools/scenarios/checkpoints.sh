#!/usr/bin/env bash
# Phase 3.15: the Mos Eisley starport checkpoint. The Empire holds the city: an officer and two troopers stand in from
# the pad; a neutral walking through is hailed and waved on or searched (the client hears it). Hand the city to the
# Rebellion and a refresh relieves the post for a picket; hand it back and the post returns.
# covers: fb_checkpoints fb_territory fb_cities
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
CITY=mos_eisley

lab "territorySet:$CITY:65" >/dev/null
lab "checkpointRefresh" >/dev/null
ST=$(lab "checkpoints" | grep "^INFO checkpoint city=$CITY " | head -n1)
check "imperial_post_standing" "$(grep -q 'side=imperial post=3/3' <<<"$ST" && echo 1 || echo 0)" "$ST"
X=$(sed -n 's/.* x=\(-\?[0-9]*\).*/\1/p' <<<"$ST"); Y=$(sed -n 's/.* y=\(-\?[0-9]*\).*/\1/p' <<<"$ST")

bot_bg --wait 45
wait_online || die "$CHAR never came online"
lab "travel:$CHAR:tatooine:$((X + 3)):$((Y + 2))" >/dev/null
sleep 2
R=$(lab_kv "checkpointHail:$CITY:$CHAR" result)
check "neutral_waved_or_searched" "$( [ "$R" = waved ] || [ "$R" = searched ] && echo 1 || echo 0 )" "result=$R"
sleep 6

# the city changes hands
lab "territorySet:$CITY:30" >/dev/null
lab "checkpointRefresh" >/dev/null
ST2=$(lab "checkpoints" | grep "^INFO checkpoint city=$CITY " | head -n1)
check "rebel_picket_after_the_flip" "$(grep -q 'side=rebel post=3/3' <<<"$ST2" && echo 1 || echo 0)" "$ST2"
lab "territorySet:$CITY:50" >/dev/null
lab "checkpointRefresh" >/dev/null
ST3=$(lab "checkpoints" | grep "^INFO checkpoint city=$CITY " | head -n1)
check "no_post_when_contested" "$(grep -q 'side=none post=0/3' <<<"$ST3" && echo 1 || echo 0)" "$ST3"
lab "territorySet:$CITY:65" >/dev/null
lab "checkpointRefresh" >/dev/null
ST4=$(lab "checkpoints" | grep "^INFO checkpoint city=$CITY " | head -n1)
check "imperial_post_back" "$(grep -q 'side=imperial post=3/3' <<<"$ST4" && echo 1 || echo 0)" "$ST4"
wait "$BOT_PID"
check "client_heard_the_hail" "$(grep -aq 'Identification\.' "$BOTLOG" && echo 1 || echo 0)"
check "client_heard_the_verdict" "$(grep -aqE 'Move along|Random search' "$BOTLOG" && echo 1 || echo 0)"
finish
