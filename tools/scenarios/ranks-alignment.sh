#!/usr/bin/env bash
# Phase 4b.3: the alignment score, the ladder and the turn. The mercy choice leans the score; kills move it by
# template and murder; /checkForceStatus shows the vague line; a trained student is offered rank 1 when the Jedi
# experience is there and promoted on reporting it (FRS rank, the rank box); a student whose score leans the other
# way is offered the turn by the other Master and comes out at that side's novice with the old boxes gone.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SITH=$(lab "findNpc:fb_sith_master" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1)
[ -n "$SITH" ] || die "no Sith Master in the enclave"

bot_bg --wait 60
wait_online || die "$CHAR never came online"
lab "attunementSit:$CHAR:stand" >/dev/null
sleep 4
lab "attunementReset:$CHAR" >/dev/null
lab "travel:$CHAR:tatooine:4100:-4700" >/dev/null
sleep 3

# --- A: the score ----------------------------------------------------------------------------------------------
check "nothing_before_the_choice" "$(lab "alignment:$CHAR" | grep -q 'align=0 .*side=- statusLine=-' && echo 1 || echo 0)" "$(lab "alignment:$CHAR")"
lab "attunementKill:$CHAR:sith_shadow_outlaw" >/dev/null                 # no side yet: nothing moves
check "kills_do_not_move_it_before_the_choice" "$(lab "alignment:$CHAR" | grep -q 'align=0 ' && echo 1 || echo 0)" "$(lab "alignment:$CHAR")"
lab "attunementFlag:$CHAR:alignment:light" >/dev/null
lab "alignmentSet:$CHAR:30" >/dev/null                                  # what the mercy choice does
lab "attunementKill:$CHAR:sith_shadow_outlaw" >/dev/null                 # +3
check "shadow_kill_leans_light" "$(lab "alignment:$CHAR" | grep -q 'align=33 ' && echo 1 || echo 0)" "$(lab "alignment:$CHAR")"
lab "attunementKill:$CHAR:light_jedi_sentinel" >/dev/null                # -5
check "sentinel_kill_leans_dark" "$(lab "alignment:$CHAR" | grep -q 'align=28 ' && echo 1 || echo 0)" "$(lab "alignment:$CHAR")"
lab "attunementKill:$CHAR:commoner" >/dev/null                           # murder: a humanoid that was not hostile, -3
check "murder_leans_dark" "$(lab "alignment:$CHAR" | grep -q 'align=25 ' && echo 1 || echo 0)" "$(lab "alignment:$CHAR")"
check_eq "status_shows_the_light_lean" "$(lab "alignment:$CHAR" | sed -n 's/.*statusLine=\([^ ]*\).*/\1/p')" "@fb_force:align_tier_4"
lab "alignmentSet:$CHAR:-70" >/dev/null
check_eq "deep_dark_tier" "$(lab "alignment:$CHAR" | sed -n 's/.*statusLine=\([^ ]*\).*/\1/p')" "@fb_force:align_tier_1"
check_eq "clamped_at_minus_100" "$(lab "alignmentShift:$CHAR:-500" | sed -n 's/.*align=\(-*[0-9]*\).*/\1/p')" "-100"

# --- B: the ladder: rank 1 given when the experience is there, promotion on the report -----------------------------
lab "alignmentSet:$CHAR:30" >/dev/null
lab "attunementFlag:$CHAR:padawan:1" >/dev/null
lab "skill:$CHAR:force_title_jedi_novice" >/dev/null
lab "jediMasterTake:$CHAR" >/dev/null
lab "trainingSet:$CHAR:stillness:done" >/dev/null
lab "trainingSet:$CHAR:shadows:done" >/dev/null                           # 10000 Jedi XP so far; rank 1 wants 5000
M=$(lab "jediMaster:$CHAR" | head -n1)
check "training_shifts_the_score" "$(grep -q 'align=40' <<<"$M" && echo 1 || echo 0)" "$M"
check_eq "rank1_offered" "$(lab "jediMaster:$CHAR" | sed -n 's/.*screen=\([a-z_0-9]*\).*/\1/p')" "train_rank1" "$M"
lab "trainingSet:$CHAR:rank1:told" >/dev/null
for i in 1 2 3 4 5 6 7 8 9 10; do lab "attunementKill:$CHAR:sith_shadow_outlaw" >/dev/null; done
M=$(lab "jediMaster:$CHAR" | head -n1)
check "rank1_task_done" "$(grep -q 'current=rank1 told=true ready=true' <<<"$M" && echo 1 || echo 0)" "$M"
lab "trainingSet:$CHAR:rank1:done" >/dev/null
M=$(lab "jediMaster:$CHAR" | head -n1)
check "promoted_to_rank1" "$(grep -q 'frsRank=1' <<<"$M" && lab "jediMaster:$CHAR" | grep -q 'current=rank2' && echo 1 || echo 0)" "$M"
check "rank1_skill_box" "$(grep -q 'rank=true' <<<"$M" && echo 1 || echo 0)" "$M"
check_eq "rank2_waits_for_xp" "$(lab "jediMaster:$CHAR" | sed -n 's/.*screen=\([a-z_0-9]*\).*/\1/p')" "rank_wait_xp" "15000 Jedi XP wanted; $(lab "xp:$CHAR:jedi_general" | tail -n1)"
wait "$BOT_PID"
check "client_got_promoted" "$(grep -aq 'fb_force:master_promoted' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'promoted\|rank1_done' "$BOTLOG" | cut -c1-90 | tail -n1)"

# --- C: the turn: a light student whose heart leans dark is offered temptation by the Sith Master -----------------
sleep 8
bot_bg --wait 60
wait_online || die "$CHAR never came back online"
check_eq "sith_turns_the_student_away" "$(lab "sithMaster:$CHAR" | sed -n 's/.*screen=\([a-z_0-9]*\).*/\1/p')" "otherdoor"
lab "alignmentSet:$CHAR:-45" >/dev/null
check_eq "sith_offers_the_turn" "$(lab "sithMaster:$CHAR" | sed -n 's/.*screen=\([a-z_0-9]*\).*/\1/p')" "turn"
lab "gotoNpc:$CHAR:fb_sith_master" >/dev/null
sleep 6
wait "$BOT_PID"
bot_bg --wait 14 --converse "$SITH" --options 0 --wait 3
wait_online || die "$CHAR never came back online"
lab "gotoNpc:$CHAR:fb_sith_master" >/dev/null
wait "$BOT_PID"
check_eq "turn_accepted" "$(bot_action_status converse)" "ok" "$(grep -ao '=> #[0-9]* {"action":"converse"[^}]*}' "$BOTLOG" | tail -n1 | cut -c1-200)"
M=$(lab "sithMaster:$CHAR" | head -n1)
check "now_the_sith_masters_student" "$(grep -q 'master=dark student=true' <<<"$M" && grep -q 'alignment=dark' <<<"$M" && echo 1 || echo 0)" "$M"
check "dark_novice_rank0_council2" "$(grep -q 'rank=true' <<<"$M" && grep -q 'council=2' <<<"$M" && grep -q 'frsRank=0' <<<"$M" && echo 1 || echo 0)" "$M"
check "light_boxes_gone" "$(lab "jediMaster:$CHAR" | grep -q 'rank=false' && echo 1 || echo 0)" "$(lab "jediMaster:$CHAR" | head -n1)"
check "starts_the_dark_training" "$(grep -q 'current=patience' <<<"$M" && echo 1 || echo 0)" "$M"
check "client_got_turned" "$(grep -aq 'fb_force:sith_turned' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'sith_turn' "$BOTLOG" | cut -c1-90 | tail -n1)"
lab "attunementReset:$CHAR" >/dev/null
finish
