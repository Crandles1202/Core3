#!/usr/bin/env bash
# Phase 4a.2: the shrines. A called character (the Old Man's task accepted) sits at a shrine: the meditation
# pays and teaches a lore fragment (the client receives @fb_force:lore_<planet>_<n>); with six worlds
# listened to the Old Man returns at the shrine, the conversation unlocks the trials (task=trials); the
# ambush he warned about comes when due: two Sith Shadows threaten and attack, and with both down the
# "survive a Force power" deed is paid.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# --- phase A: called, at a shrine, standing; the first world -------------------------------------------------
bot_bg --wait 40
wait_online || die "$CHAR never came online"
lab "attunementSit:$CHAR:stand" >/dev/null
sleep 8
lab "attunementReset:$CHAR" >/dev/null
lab "attunementSet:$CHAR:100" >/dev/null
A=$(lab "attunementAccept:$CHAR")
check "called_with_the_shrine_task" "$(grep -q 'called=true task=shrines' <<<"$A" && echo 1 || echo 0)" "$A"
check "ambush_scheduled" "$(grep -q 'ambushDue=[0-9]' <<<"$A" && echo 1 || echo 0)" "$A"
lab "travel:$CHAR:tatooine:5264:113" >/dev/null
wait "$BOT_PID"

# --- phase B: sit at the shrine: credit + lore fragment ------------------------------------------------------
sleep 8
bot_bg --wait 2 --command sitServer --command-nowait --wait 45
wait_online || die "$CHAR never came back online"
sleep 22
A=$(lab "attunement:$CHAR")
check "world_one_noted" "$(grep -q 'medWorlds=tatooine' <<<"$A" && echo 1 || echo 0)" "$A"
check "one_fragment_learned" "$(grep -q 'lore=1' <<<"$A" && echo 1 || echo 0)" "$A"
lab "attunementWorlds:$CHAR:naboo,corellia,talus,rori,lok" >/dev/null
lab "travel:$CHAR:tatooine:-6506:-3668" >/dev/null
wait "$BOT_PID"
check "client_got_the_fragment" "$(grep -aq 'fb_force:lore_tatooine_2' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'fb_force' "$BOTLOG" | tail -n3 | tr '\n' ' ')"

# --- phase C: five more worlds already listened to; a new shrine on this world is the sixth, and the Old Man
# comes back. The character is moved to that shrine still seated, so the login watch credits it at once. --------
sleep 8
bot_bg --wait 70
wait_online || die "$CHAR never came back online"
sleep 22
A=$(lab "attunement:$CHAR")
check "sixth_world_counted" "$(grep -q 'medWorlds=naboo,corellia,talus,rori,lok,tatooine' <<<"$A" && echo 1 || echo 0)" "$A"
check "old_man_return_sent" "$(grep -q 'returned=true' <<<"$A" && echo 1 || echo 0)" "$A"
sleep 25
OLD=$(lab "findNpc:fb_old_man" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1)
check "old_man_is_back" "$( [ -n "$OLD" ] && echo 1 || echo 0 )"
wait "$BOT_PID"
sleep 8
bot --wait 4 --converse "$OLD" --options 0 --wait 2 --command checkForceStatus --wait 3 >/dev/null 2>&1 || true
check_eq "return_converse_ok" "$(bot_action_status converse)" "ok" "status: $(bot_action_status converse)"
A=$(lab "attunement:$CHAR")
check "trials_unlocked" "$(grep -q 'task=trials' <<<"$A" && grep -q 'trials=true' <<<"$A" && echo 1 || echo 0)" "$A"
check "client_got_lore_count" "$(grep -aq 'fb_force:lore_count\|fb_force:trials_unlocked' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'fb_force' "$BOTLOG" | tail -n3 | tr '\n' ' ')"
sleep 30
check "old_man_gone_again" "$(lab "objectAlive:$OLD" | grep -q 'alive=0' && echo 1 || echo 0)"

# --- phase D: the ambush, forced due; the lab drops the shadows before they reach the character ---------------
lab "attunementSit:$CHAR:stand" >/dev/null
sleep 8
bot_bg --wait 80
wait_online || die "$CHAR never came back online"
V=$(lab "attunementAmbush:$CHAR")
check "ambush_sent" "$(grep -q 'sent=true' <<<"$V" && echo 1 || echo 0)" "$V"
sleep 6
SHADOWS=$(lab "findNpc:sith_shadow_outlaw" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n2 | tr '\n' ' ')
check_eq "two_shadows_came" "$(wc -w <<<"$SHADOWS")" "2" "$SHADOWS"
for oid in $SHADOWS; do lab "killNpc:$CHAR:$oid" >/dev/null; done
sleep 4
A=$(lab "attunement:$CHAR")
check "survived_the_ambush" "$(grep -q 'ambushDone=true' <<<"$A" && grep -q 'deeds=3/3' <<<"$A" && echo 1 || echo 0)" "$A"
wait "$BOT_PID"
check "client_saw_the_threat_and_the_end" "$(grep -aq 'fb_force:shadow_survived' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'fb_force\|SpatialChat' "$BOTLOG" | tail -n3 | tr '\n' ' ')"
lab "attunementSit:$CHAR:stand" >/dev/null
lab "attunementReset:$CHAR" >/dev/null
finish
