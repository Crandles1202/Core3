#!/usr/bin/env bash
# /healdamage with the starter stimpack heals health, action AND mind (Phase 1.9; stock Core3
# stimpacks leave mind alone). Regen moves every pool while the bot is logged in, so a control
# round with no command measures regen first, and the stimpack's share is delta - regen.
# Each round: staging session (bot online, oracle hurts the character) -> command session.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

STIMPACK="object/tangible/medicine/stimpack_sm_s1.iff"
MIN_HEAL=50          # a 100-effectiveness stimpack heals ~100-150 per pool on a fresh character

# stage <label>: log in, make sure the stimpack is usable, full pools, then hurt the character.
# inflict/heal need the character online, so this happens inside a bot session.
stage() {
	bot_bg --wait 25
	wait_online || die "$CHAR never came online"
	if [ "$(lab_kv "findItem:$CHAR:stimpack" oid)" = "" ]; then
		lab "give:$CHAR:$STIMPACK" >/dev/null
	fi
	# stimpack_sm_s1 needs healing_ability >= 5 (its medicineUse); a fresh non-medic has 0 and
	# gets "No valid medicine found". Give the character Novice Medic so the command is reachable.
	HA=$(lab_kv "skillmod:$CHAR:healing_ability" healing_ability)
	if [ "${HA:-0}" -lt 5 ]; then
		lab "skill:$CHAR:science_medic_novice" >/dev/null
		HA=$(lab_kv "skillmod:$CHAR:healing_ability" healing_ability)
	fi
	for p in health action mind; do lab "heal:$CHAR:$p:100000" >/dev/null; done
	lab "inflict:$CHAR:health:400" >/dev/null
	lab "inflict:$CHAR:action:300" >/dev/null
	lab "inflict:$CHAR:mind:300" >/dev/null
	H0=$(ham health); A0=$(ham action); M0=$(ham mind)
	say "INFO $1 start: health=$H0 action=$A0 mind=$M0"
	wait "$BOT_PID"
}
deltas() { DH=$(( $(ham health) - H0 )); DA=$(( $(ham action) - A0 )); DM=$(( $(ham mind) - M0 )); }

# --- control round: same session shape, no stimpack -> regen per pool ------------------------
stage control
check "has_stimpack" "$( [ -n "$(lab_kv "findItem:$CHAR:stimpack" oid)" ] && echo 1 || echo 0 )"
check_ge "healing_ability_for_stimpack" "${HA:-0}" 5 "healing_ability=$HA (stimpack_sm_s1 medicineUse=5)"
bot --wait 2 --wait 2
check_eq "control_client_exit_0" "$?" "0"
deltas; RH=$DH; RA=$DA; RM=$DM
say "INFO regen during a 4 s session: health +$RH action +$RA mind +$RM"

# --- stimpack round: use it via the real command path ----------------------------------------
stage stimpack
bot --wait 2 --command healdamage --wait 2
RC=$?
check_eq "client_exit_0" "$RC" "0"
check_eq "healdamage_accepted" "$(bot_action_status command)" "ok" "command status: $(bot_action_status command)"
[ "$RC" = 0 ] || bot_errors

# --- observe --------------------------------------------------------------------------------
deltas
say "INFO after:  delta health=$DH action=$DA mind=$DM  (stimpack share: $((DH - RH)) / $((DA - RA)) / $((DM - RM)))"
check_ge "health_healed_beyond_regen" "$((DH - RH))" "$MIN_HEAL" "health +$DH, regen +$RH"
check_ge "action_healed_beyond_regen" "$((DA - RA))" "$MIN_HEAL" "action +$DA, regen +$RA"
check_ge "mind_healed_beyond_regen"   "$((DM - RM))" "$MIN_HEAL" "mind +$DM, regen +$RM  (Phase 1.9)"
# HealDamageCommand::sendHealMessage: "You heal <target> for N health, M action, and K mind."
check "heal_message_mentions_mind" "$(grep -aqE '[0-9]+ mind' "$BOTLOG" && echo 1 || echo 0)" \
	"$(grep -a 'You heal' "$BOTLOG" | tail -1 | sed 's/.*> //')"

finish
