#!/usr/bin/env bash
# Known-good behaviour used to prove the scenario plumbing: /healdamage with a stimpack in
# the inventory heals health. Also records what happens to mind damage (stock: untouched),
# which Phase 1.9 will change.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

STIMPACK="object/tangible/medicine/stimpack_sm_s1.iff"

# --- stage: log in, make sure there is a stimpack, hurt the character -------------------------
bot_bg --wait 30          # staging below takes ~15 s of lab calls; the bot must stay logged in
wait_online || die "$CHAR never came online"

if [ "$(lab_kv "findItem:$CHAR:stimpack" oid)" = "" ]; then
	lab "give:$CHAR:$STIMPACK" >/dev/null
fi
check "has_stimpack" "$( [ -n "$(lab_kv "findItem:$CHAR:stimpack" oid)" ] && echo 1 || echo 0 )"

# stimpack_sm_s1 needs healing_ability >= 5 (its medicineUse); a fresh non-medic has 0 and gets
# "No valid medicine found". Give the character Novice Medic so the known-good path is reachable.
HA=$(lab_kv "skillmod:$CHAR:healing_ability" healing_ability)
if [ "${HA:-0}" -lt 5 ]; then
	lab "skill:$CHAR:science_medic_novice" >/dev/null
	HA=$(lab_kv "skillmod:$CHAR:healing_ability" healing_ability)
fi
check_ge "healing_ability_for_stimpack" "${HA:-0}" 5 "healing_ability=$HA (stimpack_sm_s1 medicineUse=5)"

lab "heal:$CHAR:health:100000" >/dev/null       # start from full so the numbers are clean
lab "heal:$CHAR:mind:100000" >/dev/null
lab "inflict:$CHAR:health:400" >/dev/null
lab "inflict:$CHAR:mind:300" >/dev/null
H0=$(ham health); M0=$(ham mind)
say "INFO before: health=$H0 mind=$M0"
check_gt "damage_applied" "$(( $(lab_kv "ham:$CHAR" health | cut -d/ -f2) ))" "$H0" "max $(lab_kv "ham:$CHAR" health | cut -d/ -f2) > current $H0"
wait "$BOT_PID"

# --- act: use the stimpack via the real command path -----------------------------------------
bot --wait 2 --command healdamage --wait 2     # let the login settle before acting
RC=$?
check_eq "client_exit_0" "$RC" "0"
check_eq "healdamage_accepted" "$(bot_action_status command)" "ok" "command status: $(bot_action_status command)"
[ "$RC" = 0 ] || bot_errors

# --- observe --------------------------------------------------------------------------------
H1=$(ham health); M1=$(ham mind)
say "INFO after:  health=$H1 mind=$M1  (delta health=$((H1 - H0)) mind=$((M1 - M0)))"
# Regen moves every pool by about the same amount while we wait; a stimpack moves only health.
# So the stimpack's contribution is health_delta - mind_delta (a small stimpack is ~100+).
check_ge "health_healed_beyond_regen" "$(( (H1 - H0) - (M1 - M0) ))" 50 "health +$((H1 - H0)) vs mind +$((M1 - M0)) (regen); stimpack share $(( (H1 - H0) - (M1 - M0) ))"
say "INFO stock stimpacks leave mind alone; Phase 1.9 changes this (then expect mind delta > regen too)"

finish
