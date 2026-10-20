#!/usr/bin/env bash
# Phase 4a.3: the Padawan trials, one after another on a called character: the word for each trial arrives at
# a trigger, stillness is counted at a shrine, restraint and strength through the kill hook, the prisoner's
# conversation sets the alignment, the far shrine is reached, the spirit's riddle is answered (the lab reads
# which riddle), the sacrifice is paid, the duel is won alone, and the Padawan box is awarded at the end.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

shrine_oid_of() { lab "findNpc:$1" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1; }

# --- setup: called, six worlds, trials unlocked, standing at a shrine ---------------------------------------
bot_bg --wait 200
wait_online || die "$CHAR never came online"
lab "attunementSit:$CHAR:stand" >/dev/null
sleep 8
lab "attunementReset:$CHAR" >/dev/null
lab "attunementSet:$CHAR:100" >/dev/null
lab "attunementAccept:$CHAR" >/dev/null
lab "attunementWorlds:$CHAR:naboo,corellia,talus,rori,lok,tatooine" >/dev/null
T=$(lab "trialsUnlock:$CHAR")
check "trials_unlocked" "$(grep -q 'task=trials' <<<"$T" && echo 1 || echo 0)" "$T"
lab "travel:$CHAR:tatooine:5264:113" >/dev/null
sleep 3

# --- 1 stillness: the word at the first trigger; the shrine watch counts 60 s without moving ------------------
T=$(lab "trialTick:$CHAR")
check "word_stillness" "$(grep -q 'current=stillness' <<<"$T" && echo 1 || echo 0)" "$T"
lab "attunementEnter:$CHAR" >/dev/null     # (re)enter the shrine: starts the stillness watch
sleep 68
T=$(lab "trials:$CHAR")
check "stillness_done" "$(grep -q 'done=stillness' <<<"$T" && echo 1 || echo 0)" "$T"

# --- 2 restraint: the word; progress is set near the end; one more quiet poll completes it ---------------------
T=$(lab "trialTick:$CHAR")
check "word_restraint" "$(grep -q 'current=restraint' <<<"$T" && echo 1 || echo 0)" "$T"
lab "trialProgress:$CHAR:290" >/dev/null
sleep 14
T=$(lab "trials:$CHAR")
check "restraint_done" "$(grep -q 'done=stillness,restraint' <<<"$T" && echo 1 || echo 0)" "$T"

# --- 3 strength: five Tusken through the kill hook --------------------------------------------------------------
T=$(lab "trialTick:$CHAR")
check "word_strength" "$(grep -q 'current=strength' <<<"$T" && echo 1 || echo 0)" "$T"
for i in 1 2 3 4 5; do lab "attunementKill:$CHAR:tusken_raider" >/dev/null; done
T=$(lab "trials:$CHAR")
check "strength_done" "$(grep -q 'done=stillness,restraint,strength' <<<"$T" && echo 1 || echo 0)" "$T"

# --- 4 mercy: the prisoner comes; the client frees him → light -----------------------------------------------
T=$(lab "trialTick:$CHAR")
check "word_mercy" "$(grep -q 'current=mercy' <<<"$T" && echo 1 || echo 0)" "$T"
T=$(lab "trialTick:$CHAR")
check "prisoner_sent" "$(grep -q 'sent=true' <<<"$T" && echo 1 || echo 0)" "$T"
sleep 6
PRIS=$(shrine_oid_of fb_prisoner)
check "prisoner_stands" "$( [ -n "$PRIS" ] && echo 1 || echo 0 )"
wait "$BOT_PID"
sleep 8
bot --wait 4 --converse "$PRIS" --options 1 --wait 3 >/dev/null 2>&1 || true
check_eq "prisoner_converse_ok" "$(bot_action_status converse)" "ok" "status: $(bot_action_status converse)"
T=$(lab "trials:$CHAR")
check "mercy_done_light" "$(grep -q 'done=stillness,restraint,strength,mercy' <<<"$T" && grep -q 'alignment=light' <<<"$T" && echo 1 || echo 0)" "$T"

# --- 5 farwalk: the far shrine on this world; reaching it completes ----------------------------------------------
sleep 8
bot_bg --wait 160
wait_online || die "$CHAR never came back online"
T=$(lab "trialTick:$CHAR")
check "word_farwalk" "$(grep -q 'current=farwalk target=tatooine_force_shrine' <<<"$T" && echo 1 || echo 0)" "$T"
TARGET=$(sed -n 's/.*target=\(tatooine_force_shrine_0[0-9]\).*/\1/p' <<<"$T" | head -n1)
case "$TARGET" in
	tatooine_force_shrine_01) XY="-6506:-3668" ;; tatooine_force_shrine_02) XY="5264:113" ;; tatooine_force_shrine_03) XY="-3623:5281" ;;
	tatooine_force_shrine_04) XY="5633:6015" ;; tatooine_force_shrine_05) XY="5958:-5684" ;; *) XY="" ;;
esac
check "far_target_known" "$( [ -n "$XY" ] && echo 1 || echo 0 )" "$TARGET"
lab "travel:$CHAR:tatooine:${XY%%:*}:${XY##*:}" >/dev/null
sleep 5
T=$(lab "trials:$CHAR")
check "farwalk_done" "$(grep -q 'done=stillness,restraint,strength,mercy,farwalk' <<<"$T" && echo 1 || echo 0)" "$T"

# --- 6 insight: the spirit asks; the lab reads which riddle, the client answers right -----------------------------
T=$(lab "trialTick:$CHAR")
check "word_insight" "$(grep -q 'current=insight' <<<"$T" && echo 1 || echo 0)" "$T"
RIDDLE=$(sed -n 's/.*riddle=\([1-3]\).*/\1/p' <<<"$T" | head -n1)
T=$(lab "trialTick:$CHAR")
check "spirit_sent" "$(grep -q 'sent=true' <<<"$T" && echo 1 || echo 0)" "$T"
sleep 14
SPIRIT=$(shrine_oid_of fb_trial_spirit)
check "spirit_stands" "$( [ -n "$SPIRIT" ] && echo 1 || echo 0 )"
wait "$BOT_PID"
sleep 8
case "$RIDDLE" in 1) RIGHT=0 ;; 2) RIGHT=1 ;; 3) RIGHT=2 ;; *) RIGHT=0 ;; esac
bot --wait 4 --converse "$SPIRIT" --options "$RIGHT" --wait 3 >/dev/null 2>&1 || true
check_eq "riddle_converse_ok" "$(bot_action_status converse)" "ok" "riddle $RIDDLE option $RIGHT: $(bot_action_status converse)"
T=$(lab "trials:$CHAR")
check "insight_done" "$(grep -q 'done=stillness,restraint,strength,mercy,farwalk,insight' <<<"$T" && echo 1 || echo 0)" "$T"

# --- 7 sacrifice: the spirit again; 10 000 credits change hands -----------------------------------------------------
sleep 8
bot_bg --wait 60
wait_online || die "$CHAR never came back online"
lab "cashSet:$CHAR:12000" >/dev/null
T=$(lab "trialTick:$CHAR")
check "word_sacrifice" "$(grep -q 'current=sacrifice' <<<"$T" && echo 1 || echo 0)" "$T"
T=$(lab "trialTick:$CHAR")
check "spirit_sent_again" "$(grep -q 'sent=true' <<<"$T" && echo 1 || echo 0)" "$T"
sleep 14
SPIRIT=$(shrine_oid_of fb_trial_spirit)
wait "$BOT_PID"
sleep 8
bot --wait 4 --converse "$SPIRIT" --options 0 --wait 3 >/dev/null 2>&1 || true
check_eq "sacrifice_converse_ok" "$(bot_action_status converse)" "ok"
T=$(lab "trials:$CHAR")
check "sacrifice_done_and_paid" "$(grep -q 'done=stillness,restraint,strength,mercy,farwalk,insight,sacrifice' <<<"$T" && grep -q 'cash=2000' <<<"$T" && echo 1 || echo 0)" "$T"

# --- 8 duel: one hunter; the character kills it alone; the Padawan box follows -----------------------------------------
sleep 8
bot_bg --wait 60
wait_online || die "$CHAR never came back online"
T=$(lab "trialTick:$CHAR")
check "word_duel" "$(grep -q 'current=duel' <<<"$T" && echo 1 || echo 0)" "$T"
T=$(lab "trialTick:$CHAR")
check "hunter_sent" "$(grep -q 'sent=true' <<<"$T" && echo 1 || echo 0)" "$T"
sleep 6
HUNTER=$(lab "findNpc:sith_shadow" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1)
check "hunter_stands" "$( [ -n "$HUNTER" ] && echo 1 || echo 0 )"
lab "killNpc:$CHAR:$HUNTER" >/dev/null
sleep 4
T=$(lab "trials:$CHAR")
check "duel_done" "$(grep -q 'count=8' <<<"$T" && echo 1 || echo 0)" "$T"
check "padawan_awarded" "$(grep -q 'padawan=true novice=true' <<<"$T" && grep -q 'task=padawan' <<<"$T" && echo 1 || echo 0)" "$T"
wait "$BOT_PID"
check "client_got_the_end" "$(grep -aq 'fb_force:trials_complete' "$BOTLOG" && grep -aq 'fb_force:trials_light' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'fb_force:trial' "$BOTLOG" | tail -n3 | tr '\n' ' ')"
lab "attunementSit:$CHAR:stand" >/dev/null
lab "attunementReset:$CHAR" >/dev/null
finish
