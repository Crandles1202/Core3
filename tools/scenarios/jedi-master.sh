#!/usr/bin/env bash
# Phase 4b.1: the Jedi Master. A dark Padawan is turned away at the Light Enclave; a light one is taken as
# Master Venn's student (council light, the novice rank box, the first task); the stillness task is done by
# sitting in her training room, the shadows task through the kill hook; each report pays Jedi experience; after
# both she has nothing more yet.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MASTER=$(lab "findNpc:fb_jedi_master" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1)
check "master_stands" "$( [ -n "$MASTER" ] && echo 1 || echo 0 )" "$(lab "findNpc:fb_jedi_master" | head -n1 | cut -c1-160)"
[ -n "$MASTER" ] || die "no Master in the enclave"
CELL=$(lab "objectPos:$MASTER" | sed -n 's/.*cell=\([0-9]*\).*/\1/p' | head -n1)

# --- A: the dark Padawan is sent to the other door -------------------------------------------------------------
bot_bg --wait 70
wait_online || die "$CHAR never came online"
lab "attunementSit:$CHAR:stand" >/dev/null
sleep 4
lab "attunementReset:$CHAR" >/dev/null
lab "attunementFlag:$CHAR:padawan:1" >/dev/null
lab "attunementFlag:$CHAR:alignment:dark" >/dev/null
check_eq "dark_padawan_screen" "$(lab "jediMaster:$CHAR" | sed -n 's/.*screen=\([a-z_]*\).*/\1/p')" "dark" "$(lab "jediMaster:$CHAR" | tail -n1)"
# --- B: the light Padawan is taken: council, novice box, first task ----------------------------------------------
lab "attunementFlag:$CHAR:alignment:light" >/dev/null
check_eq "light_padawan_screen" "$(lab "jediMaster:$CHAR" | sed -n 's/.*screen=\([a-z_]*\).*/\1/p')" "offer"
lab "gotoNpc:$CHAR:fb_jedi_master" >/dev/null
sleep 6
wait "$BOT_PID"
# the talking session: in beside her, then the offer accepted and the first task given
bot_bg --wait 14 --converse "$MASTER" --options 0 --wait 3 --converse "$MASTER" --options 0 --wait 3
wait_online || die "$CHAR never came back online"
lab "gotoNpc:$CHAR:fb_jedi_master" >/dev/null
wait "$BOT_PID"
check_eq "offer_accepted" "$(bot_action_count converse ok)" "2" "$(grep -ao '=> #[0-9]* {"action":"converse"[^}]*}' "$BOTLOG" | tr '\n' ' ' | cut -c1-300)"
M=$(lab "jediMaster:$CHAR" | head -n1)
check "taken_as_student" "$(grep -q 'student=true' <<<"$M" && echo 1 || echo 0)" "$M"
check "novice_rank_and_council" "$(grep -q 'novice=true' <<<"$M" && grep -q 'council=1' <<<"$M" && echo 1 || echo 0)" "$M"
check "stillness_given" "$(grep -q 'current=stillness told=true' <<<"$M" && echo 1 || echo 0)" "$M"
check "client_got_taken" "$(grep -aq 'fb_force:master_taken' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'master_' "$BOTLOG" | cut -c1-90 | tr '\n' ' ')"

# --- C: stillness — sit in her room; the poll credits five seconds at a time ----------------------------------
XP0=$(lab "xp:$CHAR:jedi_general" | sed -n 's/.*jedi_general=\([0-9-]*\).*/\1/p' | head -n1)
sleep 8
bot_bg --wait 2 --command sitServer --command-nowait --wait 80
wait_online || die "$CHAR never came back online"
lab "gotoNpc:$CHAR:fb_jedi_master" >/dev/null
sleep 10
for i in $(seq 1 13); do lab "trainingTick:$CHAR" >/dev/null; sleep 1; done
M=$(lab "jediMaster:$CHAR" | head -n1)
check "stillness_credited" "$(grep -q 'current=stillness told=true ready=true' <<<"$M" && echo 1 || echo 0)" "$M"
wait "$BOT_PID"
check "client_told_stillness_done" "$(grep -aq 'fb_force:master_stillness_done' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'stillness_done' "$BOTLOG" | cut -c1-90 | tail -n1)"
# report it: experience, the shadows task given
lab "attunementSit:$CHAR:stand" >/dev/null
bot_bg --wait 14 --converse "$MASTER" --options 0 --wait 3 --converse "$MASTER" --options 0 --wait 3
wait_online || die "$CHAR never came back online"
lab "gotoNpc:$CHAR:fb_jedi_master" >/dev/null
wait "$BOT_PID"
XP1=$(lab "xp:$CHAR:jedi_general" | sed -n 's/.*jedi_general=\([0-9-]*\).*/\1/p' | head -n1)
check_eq "stillness_paid" "$(( ${XP1:-0} - ${XP0:-0} ))" "5000" "jedi_general $XP0 -> $XP1"
M=$(lab "jediMaster:$CHAR" | head -n1)
check "shadows_given" "$(grep -q 'current=shadows told=true' <<<"$M" && echo 1 || echo 0)" "$M"

# --- D: shadows through the kill hook; the report; nothing more yet -------------------------------------------
sleep 8
bot_bg --wait 40
wait_online || die "$CHAR never came back online"
for i in 1 2 3 4 5; do lab "attunementKill:$CHAR:sith_shadow_outlaw" >/dev/null; done
M=$(lab "jediMaster:$CHAR" | head -n1)
check "shadows_credited" "$(grep -q 'current=shadows told=true ready=true' <<<"$M" && echo 1 || echo 0)" "$M"
wait "$BOT_PID"
check "client_counted_shadows" "$(grep -aq 'master_shadows_progress\|master_shadows_done' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'shadows' "$BOTLOG" | cut -c1-90 | tail -n1)"
bot_bg --wait 14 --converse "$MASTER" --options 0 --wait 3 --converse "$MASTER" --wait 3
wait_online || die "$CHAR never came back online"
lab "gotoNpc:$CHAR:fb_jedi_master" >/dev/null
wait "$BOT_PID"
XP2=$(lab "xp:$CHAR:jedi_general" | sed -n 's/.*jedi_general=\([0-9-]*\).*/\1/p' | head -n1)
check_eq "shadows_paid" "$(( ${XP2:-0} - ${XP1:-0} ))" "5000" "jedi_general $XP1 -> $XP2"
M=$(lab "jediMaster:$CHAR" | head -n1)
check "training_complete" "$(grep -q 'done=stillness,shadows' <<<"$M" && grep -q 'current=-' <<<"$M" && echo 1 || echo 0)" "$M"
check_eq "trained_screen" "$(lab "jediMaster:$CHAR" | sed -n 's/.*screen=\([a-z_]*\).*/\1/p')" "trained"
check "client_got_trained_note" "$(grep -aq 'fb_force:master_trained_note' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'master_trained' "$BOTLOG" | cut -c1-90 | tail -n1)"
lab "attunementReset:$CHAR" >/dev/null
finish
