#!/usr/bin/env bash
# Phase 4b.4: the Knight trial. A light student with the ladder's tasks done is offered the trial by Master Venn;
# the chief stands in the Dantooine cave's deepest room; brought beside the character and beaten to the yield, he
# is spared in conversation (the token, the alignment shift); the report to the Master is the graduation (Knight
# title, Jedi state 4, rank 3 and its box, the robe). Then the dark side through the lab: the elder at the Dathomir
# stronghold, finished, graduation to the dark Knight.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MASTER=$(lab "findNpc:fb_jedi_master" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1)
[ -n "$MASTER" ] || die "no Jedi Master in the enclave"

bot_bg --wait 60
wait_online || die "$CHAR never came online"
lab "attunementSit:$CHAR:stand" >/dev/null
sleep 4
lab "attunementReset:$CHAR" >/dev/null
lab "travel:$CHAR:tatooine:4100:-4700" >/dev/null
sleep 3

# --- A: the light trial offered once the ladder's tasks are done --------------------------------------------------
lab "attunementFlag:$CHAR:padawan:1" >/dev/null
lab "attunementFlag:$CHAR:alignment:light" >/dev/null
lab "alignmentSet:$CHAR:30" >/dev/null
lab "skill:$CHAR:force_title_jedi_novice" >/dev/null
lab "jediMasterTake:$CHAR" >/dev/null
for t in stillness shadows rank1 rank2; do lab "trainingSet:$CHAR:$t:done" >/dev/null; done
check_eq "trial_offered_after_the_ladder" "$(lab "knight:$CHAR" | sed -n 's/.*screen=\([a-z_0-9]*\).*/\1/p')" "knight_offer" "$(lab "knight:$CHAR" | head -n1)"
K=$(lab "knightGive:$CHAR")
check "trial_given" "$(grep -q 'given=true' <<<"$K" && echo 1 || echo 0)" "$K"
CHIEF=$(lab "knight:$CHAR" | sed -n 's/.*boss=\([0-9]*\).*/\1/p' | head -n1)
check "chief_stands_in_the_cave" "$( [ -n "$CHIEF" ] && lab "objectPos:$CHIEF" | grep -q 'zone=dantooine' && [ "$(lab "objectPos:$CHIEF" | sed -n 's/.*cell=\([0-9]*\).*/\1/p')" != "0" ] && echo 1 || echo 0 )" "$(lab "objectPos:$CHIEF" | sed 's/.*zone=/zone=/' | cut -c1-80)"
check_eq "master_waits" "$(lab "knight:$CHAR" | sed -n 's/.*screen=\([a-z_0-9]*\).*/\1/p')" "knight_wait"

# --- B: the chief beside the character, beaten to the yield, spared in conversation --------------------------------
lab "knightBossHere:$CHAR" >/dev/null
sleep 2
lab "knightYield:$CHAR" >/dev/null
check "chief_yielded" "$(lab "knight:$CHAR" | grep -q 'yielded=true' && echo 1 || echo 0)" "$(lab "knight:$CHAR" | head -n1)"
wait "$BOT_PID"
check "client_heard_the_yield" "$(grep -aq "SpatialChat from=$CHIEF" "$BOTLOG" && echo 1 || echo 0)" "$(grep -a "SpatialChat from=$CHIEF" "$BOTLOG" | head -n1 | cut -c1-100)"
bot_bg --wait 14 --converse "$CHIEF" --options 0 --wait 3
wait_online || die "$CHAR never came back online"
lab "knightBossHere:$CHAR" >/dev/null
wait "$BOT_PID"
check_eq "spared_in_conversation" "$(bot_action_status converse)" "ok" "$(grep -ao '=> #[0-9]* {"action":"converse"[^}]*}' "$BOTLOG" | tail -n1 | cut -c1-200)"
K=$(lab "knight:$CHAR" | head -n1)
check "token_held_choice_spare" "$(grep -q 'state=token choice=spare' <<<"$K" && echo 1 || echo 0)" "$K"
check "light_holocron_in_the_bag" "$(lab "findItem:$CHAR:holocron" | grep -qi 'holocron' && echo 1 || echo 0)" "$(lab "findItem:$CHAR:holocron" | head -n1 | cut -c1-120)"
check "sparing_leans_light" "$(grep -q 'align=55' <<<"$K" && echo 1 || echo 0)" "30 + four tasks' 5 + the spare's 5; $K"
sleep 6
check "chief_gone" "$(lab "objectAlive:$CHIEF" | grep -q 'alive=0' && echo 1 || echo 0)" "$(lab "objectAlive:$CHIEF")"
check_eq "master_hears_the_report" "$(lab "knight:$CHAR" | sed -n 's/.*screen=\([a-z_0-9]*\).*/\1/p')" "knight_report"

# --- C: the report is the graduation ---------------------------------------------------------------------------
sleep 8
bot_bg --wait 14 --converse "$MASTER" --options 0 --wait 3
wait_online || die "$CHAR never came back online"
lab "gotoNpc:$CHAR:fb_jedi_master" >/dev/null
wait "$BOT_PID"
check_eq "report_accepted" "$(bot_action_status converse)" "ok" "$(grep -ao '=> #[0-9]* {"action":"converse"[^}]*}' "$BOTLOG" | tail -n1 | cut -c1-200)"
K=$(lab "knight:$CHAR" | head -n1)
check "knight_of_the_light" "$(grep -q 'state=done' <<<"$K" && grep -q 'knightTitle=true' <<<"$K" && grep -q 'jediState=4' <<<"$K" && grep -q 'frsRank=3' <<<"$K" && echo 1 || echo 0)" "$K"
check "rank3_box" "$(lab "jediMaster:$CHAR" | grep -q 'frsRank=3' && echo 1 || echo 0)"
check "light_robe_in_the_bag" "$(lab "findItem:$CHAR:robe_jedi_light" | grep -qi 'robe' && echo 1 || echo 0)" "$(lab "findItem:$CHAR:robe_jedi_light" | head -n1 | cut -c1-120)"
check "client_got_graduated" "$(grep -aq 'fb_force:master_knight_graduated' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'knight_' "$BOTLOG" | cut -c1-90 | tail -n1)"
check_eq "ladder_ends_for_now" "$(lab "knight:$CHAR" | sed -n 's/.*screen=\([a-z_0-9]*\).*/\1/p')" "trained"

# --- D: the dark trial through the lab: the elder at the stronghold, finished ---------------------------------------
lab "attunementReset:$CHAR" >/dev/null
lab "attunementFlag:$CHAR:padawan:1" >/dev/null
lab "attunementFlag:$CHAR:alignment:dark" >/dev/null
lab "alignmentSet:$CHAR:-30" >/dev/null
lab "sithMasterTake:$CHAR" >/dev/null
for t in patience prey rank1 rank2; do lab "trainingSet:$CHAR:$t:done" >/dev/null; done
lab "knightGive:$CHAR" >/dev/null
ELDER=$(lab "knight:$CHAR" | sed -n 's/.*boss=\([0-9]*\).*/\1/p' | head -n1)
check "elder_stands_at_the_stronghold" "$( [ -n "$ELDER" ] && lab "objectPos:$ELDER" | grep -q 'zone=dathomir' && echo 1 || echo 0 )" "$(lab "objectPos:$ELDER" | sed 's/.*zone=/zone=/' | cut -c1-80)"
check "elder_placement" "$(lab "placement:fb_nightsister_witch" | grep -q 'verdict=ok\|verdict=warn' && echo 1 || echo 0)" "$(lab "placement:fb_nightsister_witch" | grep -a 'verdict' | head -n1 | cut -c1-160)"
lab "knightChoose:$CHAR:kill" >/dev/null
K=$(lab "knight:$CHAR" | head -n1)
check "elder_finished_token_held" "$(grep -q 'state=token choice=kill' <<<"$K" && grep -q 'align=-60' <<<"$K" && echo 1 || echo 0)" "-30, the dark tasks' -25, the kill's -5; $K"
lab "knightGraduate:$CHAR" >/dev/null
K=$(lab "knight:$CHAR" | head -n1)
check "knight_of_the_dark" "$(grep -q 'state=done' <<<"$K" && grep -q 'jediState=8' <<<"$K" && grep -q 'frsRank=3' <<<"$K" && echo 1 || echo 0)" "$K"
lab "attunementReset:$CHAR" >/dev/null
finish
