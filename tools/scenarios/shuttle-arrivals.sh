#!/usr/bin/env bash
# Phase 3.16: a landing party steps off the Mos Eisley pad and walks into town along the convoy route; a boarder or two
# walk to the pad. The lab lands one now (no player needed), the walkers move off the pad, the sweep clears them.
# covers: fb_arrivals fb_convoys
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
CITY=mos_eisley

N=$(lab "arrivals" | grep -c '^INFO arrivals ')
check_ge "starports_take_part" "$N" 5 "$N starports"
ST=$(lab "arrivalsLand:$CITY" | grep '^INFO arrivals ' | head -n1)
W=$(sed -n 's/.*walkers=\([0-9]*\)\/\([0-9]*\).*/\2/p' <<<"$ST")
check "party_landed" "$( [ "${W:-0}" -ge 4 ] && [ "${W:-0}" -le 8 ] && echo 1 || echo 0 )" "$ST"
sleep 25
ST2=$(lab "arrivals" | grep "^INFO arrivals city=$CITY " | head -n1)
A=$(sed -n 's/.*walkers=\([0-9]*\)\/\([0-9]*\).*/\1/p' <<<"$ST2")
check "walkers_still_about_or_arrived" "$( [ "${A:-0}" -le "${W:-0}" ] && echo 1 || echo 0 )" "$ST2"
SW=$(lab_kv "arrivalsSweep:$CITY" swept)
check "sweep_clears_the_rest" "$( [ -n "$SW" ] && echo 1 || echo 0 )" "swept=$SW"
ST3=$(lab "arrivals" | grep "^INFO arrivals city=$CITY " | head -n1)
check "nobody_left" "$(grep -q 'walkers=0/0' <<<"$ST3" && echo 1 || echo 0)" "$ST3"
finish
