#!/usr/bin/env bash
# Phase 4b.5: the companion. A light Knight is offered Mirren Solas by Master Venn; the Padawan is a hireling pet in
# the datapad, out and beside the character; stored and called back through the real datapad radial; it grows with
# the kills it sees (stage 2 at 20, 3 at 50), defends the character, speaks; the trials (three shrines, Padawan
# beside) and the knighting (robe with his name, Master Venn's "Master"). Then the dark side: Ryka Dathe, the
# betrayal (permanent pools, 20 darker), the turn (she hunts you), the loss (a quarter of the cash, the former
# master) and the slaying.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MASTER=$(lab "findNpc:fb_jedi_master" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1)
[ -n "$MASTER" ] || die "no Jedi Master in the enclave"
kv() { lab "companion:$CHAR" | sed -n "s/.*[[:space:]]$1=\([^[:space:]]*\).*/\1/p" | head -n1; }

light_knight() {
	lab "attunementReset:$CHAR" >/dev/null
	lab "attunementFlag:$CHAR:padawan:1" >/dev/null
	lab "attunementFlag:$CHAR:alignment:light" >/dev/null
	lab "alignmentSet:$CHAR:30" >/dev/null
	lab "skill:$CHAR:force_title_jedi_novice" >/dev/null
	lab "jediMasterTake:$CHAR" >/dev/null
	for t in stillness shadows rank1 rank2; do lab "trainingSet:$CHAR:$t:done" >/dev/null; done
	lab "knightGive:$CHAR" >/dev/null
	lab "knightChoose:$CHAR:spare" >/dev/null
	lab "knightGraduate:$CHAR" >/dev/null
}
dark_knight() {
	lab "attunementReset:$CHAR" >/dev/null
	lab "attunementFlag:$CHAR:padawan:1" >/dev/null
	lab "attunementFlag:$CHAR:alignment:dark" >/dev/null
	lab "alignmentSet:$CHAR:-30" >/dev/null
	lab "skill:$CHAR:force_title_jedi_novice" >/dev/null
	lab "sithMasterTake:$CHAR" >/dev/null
	for t in patience prey rank1 rank2; do lab "trainingSet:$CHAR:$t:done" >/dev/null; done
	lab "knightGive:$CHAR" >/dev/null
	lab "knightChoose:$CHAR:kill" >/dev/null
	lab "knightGraduate:$CHAR" >/dev/null
}

# --- A: the Knight is offered the Padawan; taken, he stands beside the character; stored for the radial --------------
bot_bg --wait 75
wait_online || die "$CHAR never came online"
lab "attunementSit:$CHAR:stand" >/dev/null
sleep 4
lab "travel:$CHAR:tatooine:5264:113" >/dev/null     # a Force shrine: open ground, a no-spawn region
sleep 3
light_knight
check_eq "padawan_offered_to_a_knight" "$(kv screen)" "comp_offer" "$(lab "companion:$CHAR" | head -n1 | cut -c1-200)"
lab "companionGive:$CHAR" >/dev/null
sleep 9                                              # a pet call lands after the stock five seconds
C=$(lab "companion:$CHAR" | head -n1)
check "padawan_taken_and_out" "$(grep -q 'state=active stage=1' <<<"$C" && grep -q 'out=true near=true' <<<"$C" && echo 1 || echo 0)" "$C"
check_eq "padawan_named" "$(kv petName)" "Mirren_Solas"
check_eq "padawan_level_stage1" "$(kv petLevel)" "25"
DEVICE=$(kv device); PET=$(kv pet)
check "device_in_the_datapad" "$( [ -n "$DEVICE" ] && [ "$DEVICE" != "-" ] && echo 1 || echo 0 )" "device $DEVICE pet $PET"
lab "companionStore:$CHAR" >/dev/null
sleep 3
check_eq "padawan_stored" "$(kv out)" "false"
wait "$BOT_PID"
check "client_got_the_given_line" "$(grep -aq 'fb_force:comp_light_given' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'comp_' "$BOTLOG" | cut -c1-80 | tail -n1)"

# --- B: called back through the datapad radial (the real packet); kills, stages, the defence, the trials, the knighting
sleep 6
bot_bg --wait 12 --radial "$DEVICE" 44 --wait 200
wait_online || die "$CHAR never came back online"
sleep 24
check_eq "radial_call_accepted" "$(bot_action_status radial)" "ok" "$(grep -ao '=> #[0-9]* {"action":"radial"[^}]*}' "$BOTLOG" | tail -n1 | cut -c1-160)"
check_eq "padawan_out_again" "$(kv out)" "true" "$(lab "companion:$CHAR" | head -n1 | cut -c1-200)"
lab "companionKills:$CHAR:19" >/dev/null
check_eq "stage_waits_for_the_twentieth" "$(kv stage)" "1"
lab "companionKills:$CHAR:1" >/dev/null
sleep 9
C=$(lab "companion:$CHAR" | head -n1)
check "stage_two_at_twenty" "$(grep -q 'stage=2 kills=20' <<<"$C" && grep -q 'out=true' <<<"$C" && echo 1 || echo 0)" "$C"
check_eq "padawan_level_stage2" "$(kv petLevel)" "50"
PET2=$(kv pet)
check "a_new_pet_for_the_stage" "$( [ -n "$PET2" ] && [ "$PET2" != "$PET" ] && echo 1 || echo 0 )" "$PET -> $PET2"
# the defence: a raider beside the character, as if it hit them
X=$(lab "where:$CHAR" | sed -n 's/.* x=\([-0-9.]*\).*/\1/p' | head -n1); Y=$(lab "where:$CHAR" | sed -n 's/.* y=\([-0-9.]*\).*/\1/p' | head -n1)
RAIDER=$(lab "spawnNpcAt:tusken_raider:tatooine:$(python3 -c "print(round($X + 6, 1))"):$Y:0" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | head -n1)
check "raider_spawned" "$( [ -n "$RAIDER" ] && echo 1 || echo 0 )"
lab "companionDefend:$CHAR:$RAIDER" >/dev/null
sleep 6
check_eq "padawan_defends" "$(kv petCombat)" "true" "$(lab "companionProbe:$CHAR:$RAIDER" | grep -a 'INFO companionProbe' | head -n1 | cut -c1-220)"
[ -n "$RAIDER" ] && lab "killNpc:$CHAR:$RAIDER" >/dev/null
lab "revive:$CHAR" >/dev/null
sleep 2
lab "companionKills:$CHAR:30" >/dev/null
sleep 9
check_eq "stage_three_at_fifty" "$(kv stage)" "3" "$(lab "companion:$CHAR" | head -n1 | cut -c1-200)"
check_eq "trials_offered" "$(kv screen)" "comp_trial_offer"
lab "companionTrialGive:$CHAR" >/dev/null
check_eq "trial_given" "$(kv state)" "trial"
for k in tatooine_force_shrine_02 tatooine_force_shrine_02 tatooine_force_shrine_05 dantooine_force_shrine_01; do lab "companionShrine:$CHAR:$k" >/dev/null; done
C=$(lab "companion:$CHAR" | head -n1)
check "three_shrines_once_each" "$(grep -q 'trial=3' <<<"$C" && echo 1 || echo 0)" "$C"
check_eq "report_waits" "$(kv screen)" "comp_trial_report"
ALIGN0=$(kv align)
lab "companionKnight:$CHAR" >/dev/null
sleep 3
C=$(lab "companion:$CHAR" | head -n1)
check "padawan_knighted_and_gone" "$(grep -q 'state=knighted' <<<"$C" && grep -q 'device=- pet=-' <<<"$C" && echo 1 || echo 0)" "$C"
check "robe_with_his_name" "$(lab "findItem:$CHAR:robe_jedi_light" | grep -q 'INFO item' && echo 1 || echo 0)" "$(lab "findItem:$CHAR:robe_jedi_light" | head -n1 | cut -c1-120)"
check_eq "master_calls_you_master" "$(kv screen)" "comp_knighted_after"
check_eq "knighting_leans_light" "$(kv align)" "$(( ALIGN0 + 10 ))"
check_eq "status_says_knighted" "$(kv statusLine)" "@fb_force:comp_status_knighted"
lab "takeItems:$CHAR:robe_jedi" >/dev/null
wait "$BOT_PID"
check "client_got_the_knighting" "$(grep -aq 'fb_force:comp_light_knighted' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'comp_light' "$BOTLOG" | cut -c1-80 | tail -n1)"
check "client_heard_the_padawan" "$(grep -aq "SpatialChat from=$PET2" "$BOTLOG" && echo 1 || echo 0)" "$(grep -a "SpatialChat from=$PET2" "$BOTLOG" | head -n1 | cut -c1-100)"

# --- C: the dark side: the betrayal; the turn and the loss; the turn and the slaying -----------------------------------
sleep 6
bot_bg --wait 200
wait_online || die "$CHAR never came back online"
lab "attunementSit:$CHAR:stand" >/dev/null
sleep 3
dark_knight
check_eq "apprentice_offered" "$(kv screen)" "comp_offer" "$(lab "companion:$CHAR" | head -n1 | cut -c1-200)"
lab "companionGive:$CHAR" >/dev/null
sleep 9
check_eq "apprentice_named" "$(kv petName)" "Ryka_Dathe"
hmax() { lab "ham:$CHAR" | sed -n 's/.*[[:space:]]health=[0-9]*\/\([0-9]*\)\/.*/\1/p' | head -n1; }
H0=$(hmax)
A0=$(kv align)
lab "companionBetray:$CHAR" >/dev/null
sleep 3
C=$(lab "companion:$CHAR" | head -n1)
check "betrayed_and_gone" "$(grep -q 'state=betrayed' <<<"$C" && grep -q 'device=- pet=-' <<<"$C" && echo 1 || echo 0)" "$C"
H1=$(hmax)
check_eq "a_hundred_health_for_good" "$(( ${H1:-0} - ${H0:-0} ))" "100" "healthMax $H0 -> $H1"
check_eq "betrayal_leans_dark" "$(kv align)" "$(( A0 - 20 ))"
check_eq "master_knows_you_spent_her" "$(kv screen)" "comp_betrayed_after"
# the turn and the loss (the character is made to last: a level-95 apprentice drops a fresh one in two swings)
lab "hamSet:$CHAR:60000" >/dev/null
lab "companionReset:$CHAR" >/dev/null
lab "companionGive:$CHAR" >/dev/null
sleep 8
lab "companionKills:$CHAR:50" >/dev/null
sleep 8
check_eq "fully_trained" "$(kv stage)" "3"
CASH0=$(lab_kv "cash:$CHAR" cash)
lab "cashSet:$CHAR:40000" >/dev/null
# the turn's own line is read: a level-95 apprentice set on a lab character wins within seconds
T=$(lab "companionTurn:$CHAR" | grep -a 'INFO companion char=' | head -n1)
TURNED=$(sed -n 's/.*[[:space:]]turned=\([^[:space:]]*\).*/\1/p' <<<"$T")
check "apprentice_turned_and_hunting" "$(grep -q 'state=turned' <<<"$T" && grep -q 'turnedAlive=true' <<<"$T" && grep -q 'device=- pet=-' <<<"$T" && echo 1 || echo 0)" "$T"
check "master_waits_for_the_outcome" "$(grep -q 'screen=comp_turned_wait' <<<"$T" && echo 1 || echo 0)" "$T"
TX=$(lab "objectPos:$TURNED" | sed -n 's/.* x=\([-0-9.]*\).*/\1/p' | head -n1); TY=$(lab "objectPos:$TURNED" | sed -n 's/.* y=\([-0-9.]*\).*/\1/p' | head -n1)
check "turned_apprentice_beside_you" "$( [ -n "$TX" ] && python3 -c "import sys; sys.exit(0 if (($TX-5264)**2+($TY-113)**2)**0.5 < 15 else 1)" && echo 1 || echo 0 )" "$(lab "objectPos:$TURNED" | sed 's/.*zone=/zone=/' | cut -c1-100)"
sleep 3
lab "companionLose:$CHAR" >/dev/null                 # a no-op when she has already won
lab "revive:$CHAR" >/dev/null
sleep 3
C=$(lab "companion:$CHAR" | head -n1)
check "former_master" "$(grep -q 'state=former' <<<"$C" && grep -q 'former=true' <<<"$C" && echo 1 || echo 0)" "$C"
check_eq "a_quarter_of_the_cash" "$(lab_kv "cash:$CHAR" cash)" "30000"
check_eq "status_says_former" "$(kv statusLine)" "@fb_force:comp_status_former"
check_eq "master_names_the_former_master" "$(kv screen)" "comp_former_after"
sleep 10
check_eq "turned_apprentice_cleared_away" "$(kv turned)" "-"
[ -n "${CASH0:-}" ] && lab "cashSet:$CHAR:$CASH0" >/dev/null
# the turn and the slaying
lab "companionReset:$CHAR" >/dev/null
lab "companionGive:$CHAR" >/dev/null
sleep 8
lab "companionKills:$CHAR:50" >/dev/null
sleep 8
lab "companionTurn:$CHAR" >/dev/null
sleep 3
TURNED=$(kv turned)
A1=$(kv align)
[ -n "$TURNED" ] && [ "$TURNED" != "-" ] && lab "killNpc:$CHAR:$TURNED" >/dev/null
lab "revive:$CHAR" >/dev/null
sleep 4
C=$(lab "companion:$CHAR" | head -n1)
check "apprentice_slain" "$(grep -q 'state=slain' <<<"$C" && echo 1 || echo 0)" "$C"
check_eq "slaying_leans_dark" "$(kv align)" "$(( A1 - 5 ))"
check_eq "master_knows_the_slaying" "$(kv screen)" "comp_slain_after"
wait "$BOT_PID"
check "client_got_the_turn_and_the_loss" "$(grep -aq 'fb_force:comp_dark_turned' "$BOTLOG" && grep -aq 'fb_force:comp_dark_lost' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'comp_dark' "$BOTLOG" | cut -c1-70 | tr '\n' ' ' | cut -c1-200)"
lab "companionReset:$CHAR" >/dev/null
lab "attunementReset:$CHAR" >/dev/null
finish
