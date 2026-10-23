#!/usr/bin/env bash
# Phase 4b.2: the Sith Master. A light Padawan is turned away at the Dark Enclave; a dark one is taken as
# Darth Vhal's student (council dark, the dark novice rank box, the first task); the patience task is done by
# sitting in her chamber, the prey task through the kill hook (anything that lives); each report pays Jedi
# experience; after both she has nothing more yet.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MASTER=$(lab "findNpc:fb_sith_master" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1)
check "master_stands" "$( [ -n "$MASTER" ] && echo 1 || echo 0 )" "$(lab "findNpc:fb_sith_master" | head -n1 | cut -c1-160)"
[ -n "$MASTER" ] || die "no Master in the enclave"
CELL=$(lab "objectPos:$MASTER" | sed -n 's/.*cell=\([0-9]*\).*/\1/p' | head -n1)

# --- A: the dark Padawan is sent to the other door -------------------------------------------------------------
bot_bg --wait 70
wait_online || die "$CHAR never came online"
lab "attunementSit:$CHAR:stand" >/dev/null
sleep 4
lab "attunementReset:$CHAR" >/dev/null
lab "xpSet:$CHAR:jedi_general:0" >/dev/null       # a reused character may sit at the stock cap, where a reward adds nothing
lab "attunementFlag:$CHAR:padawan:1" >/dev/null
lab "skill:$CHAR:force_title_jedi_novice" >/dev/null       # the Padawan box itself: the enclave's cells admit it, a flag alone is ejected at the door
lab "attunementFlag:$CHAR:alignment:light" >/dev/null
check_eq "light_padawan_screen" "$(lab "sithMaster:$CHAR" | sed -n 's/.*screen=\([a-z_]*\).*/\1/p')" "otherdoor" "$(lab "sithMaster:$CHAR" | tail -n1)"
# --- B: the light Padawan is taken: council, novice box, first task ----------------------------------------------
lab "attunementFlag:$CHAR:alignment:dark" >/dev/null
check_eq "dark_padawan_screen" "$(lab "sithMaster:$CHAR" | sed -n 's/.*screen=\([a-z_]*\).*/\1/p')" "offer"
lab "gotoNpc:$CHAR:fb_sith_master" >/dev/null
sleep 6
wait "$BOT_PID"
# the talking session: in beside her, then the offer accepted and the first task given
bot_bg --wait 14 --converse "$MASTER" --options 0 --wait 3 --converse "$MASTER" --options 0 --wait 3
wait_online || die "$CHAR never came back online"
lab "gotoNpc:$CHAR:fb_sith_master" >/dev/null
wait "$BOT_PID"
check_eq "offer_accepted" "$(bot_action_count converse ok)" "2" "$(grep -ao '=> #[0-9]* {"action":"converse"[^}]*}' "$BOTLOG" | tr '\n' ' ' | cut -c1-300)"
M=$(lab "sithMaster:$CHAR" | head -n1)
check "taken_as_student" "$(grep -q 'student=true' <<<"$M" && echo 1 || echo 0)" "$M"
check "novice_rank_and_council" "$(grep -q 'rank=true' <<<"$M" && grep -q 'council=2' <<<"$M" && echo 1 || echo 0)" "$M"
check "patience_given" "$(grep -q 'current=patience told=true' <<<"$M" && echo 1 || echo 0)" "$M"
check "client_got_taken" "$(grep -aq 'fb_force:sith_taken' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'sith_' "$BOTLOG" | cut -c1-90 | tr '\n' ' ')"

# --- C: patience — sit in her room; the poll credits five seconds at a time ----------------------------------
XP0=$(lab "xp:$CHAR:jedi_general" | sed -n 's/.*amount=\([0-9-]*\).*/\1/p' | head -n1)
sleep 8
bot_bg --wait 2 --command sitServer --command-nowait --wait 80
wait_online || die "$CHAR never came back online"
lab "gotoNpc:$CHAR:fb_sith_master" >/dev/null
sleep 10
for i in $(seq 1 13); do lab "trainingTick:$CHAR" >/dev/null; sleep 1; done
M=$(lab "sithMaster:$CHAR" | head -n1)
check "patience_credited" "$(grep -q 'current=patience told=true ready=true' <<<"$M" && echo 1 || echo 0)" "$M"
wait "$BOT_PID"
check "client_told_patience_done" "$(grep -aq 'fb_force:sith_patience_done' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'patience_done' "$BOTLOG" | cut -c1-90 | tail -n1)"
# report it: experience, the prey task given
lab "attunementSit:$CHAR:stand" >/dev/null
bot_bg --wait 14 --converse "$MASTER" --options 0 --wait 3 --converse "$MASTER" --options 0 --wait 3
wait_online || die "$CHAR never came back online"
lab "gotoNpc:$CHAR:fb_sith_master" >/dev/null
wait "$BOT_PID"
XP1=$(lab "xp:$CHAR:jedi_general" | sed -n 's/.*amount=\([0-9-]*\).*/\1/p' | head -n1)
check_eq "patience_paid" "$(( ${XP1:-0} - ${XP0:-0} ))" "5000" "jedi_general $XP0 -> $XP1"
M=$(lab "sithMaster:$CHAR" | head -n1)
check "prey_given" "$(grep -q 'current=prey told=true' <<<"$M" && echo 1 || echo 0)" "$M"

# --- D: prey through the kill hook; the report; nothing more yet -------------------------------------------
sleep 8
bot_bg --wait 40
wait_online || die "$CHAR never came back online"
for i in 1 2 3 4 5; do lab "attunementKill:$CHAR:tusken_raider" >/dev/null; done
M=$(lab "sithMaster:$CHAR" | head -n1)
check "prey_credited" "$(grep -q 'current=prey told=true ready=true' <<<"$M" && echo 1 || echo 0)" "$M"
wait "$BOT_PID"
check "client_counted_prey" "$(grep -aq 'sith_prey_progress\|sith_prey_done' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'prey' "$BOTLOG" | cut -c1-90 | tail -n1)"
bot_bg --wait 14 --converse "$MASTER" --options 0 --wait 3 --converse "$MASTER" --wait 3
wait_online || die "$CHAR never came back online"
lab "gotoNpc:$CHAR:fb_sith_master" >/dev/null
wait "$BOT_PID"
XP2=$(lab "xp:$CHAR:jedi_general" | sed -n 's/.*amount=\([0-9-]*\).*/\1/p' | head -n1)
check_eq "prey_paid" "$(( ${XP2:-0} - ${XP1:-0} ))" "5000" "jedi_general $XP1 -> $XP2"
M=$(lab "sithMaster:$CHAR" | head -n1)
check "training_complete" "$(grep -q 'done=patience,prey' <<<"$M" && grep -q 'current=rank1' <<<"$M" && echo 1 || echo 0)" "$M"
check_eq "ladder_offers_rank1" "$(lab "sithMaster:$CHAR" | sed -n 's/.*screen=\([a-z_0-9]*\).*/\1/p')" "train_rank1"   # 10000 Jedi XP from the two tasks clears the 5000 of rank 1
check "client_was_offered_rank1" "$(grep -aq 'option\[0\] I will\.' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'option\[' "$BOTLOG" | tail -n2 | cut -c1-80 | tr '\n' ' ')"   # the second talk shows the rank task's screen (its text is a StringId the client does not decode)
lab "attunementReset:$CHAR" >/dev/null
finish
