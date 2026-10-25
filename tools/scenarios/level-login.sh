#!/usr/bin/env bash
# Phase 7.5 — the stored level follows the weapon in hand at login. PlayerManager::calculatePlayerLevel (the held weapon
# line's private_<weapon>_combat_difficulty / 100 + 1, capped at 25) runs only when a skill box is awarded, so a character
# that picked its weapon up afterwards (every veteran start, made unarmed) read level 1 to every con, mission terminal and
# aggro check. The login hook (FBLogin.recomputeLevel → CreatureObject:recomputeLevel) runs it again. Here: the master
# marksman box is awarded with bare hands (level 1 stored), a CDEF rifle is given and equipped (still 1: nothing recomputes),
# then the login hook runs and the stored level matches the rifle line.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BOX=combat_marksman_master
RIFLE=
cleanup() {
	[ -n "$RIFLE" ] && lab "destroyObject:$RIFLE" >/dev/null 2>&1
	lab "skillDrop:$CHAR:$BOX" >/dev/null 2>&1
	lab "skillDrop:$CHAR:combat_marksman_novice" >/dev/null 2>&1
}

bot_bg --wait 45
wait_online || die "$CHAR never came online"
# bare hands first: whatever the character holds goes back to the bag so the award computes from the unarmed line
HELD=$(lab_kv "level:$CHAR" held)
lab "skillDrop:$CHAR:$BOX" >/dev/null 2>&1
lab "unequip:$CHAR" >/dev/null
lab "skill:$CHAR:$BOX" >/dev/null
L0=$(lab_kv "level:$CHAR" stored)
check "stored_level_from_bare_hands" "$( [ "${L0:-0}" -ge 1 ] && echo 1 || echo 0 )" "stored=$L0 held=$(lab_kv "level:$CHAR" held)"

RIFLE=$(lab "give:$CHAR:object/weapon/ranged/rifle/rifle_cdef.iff" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | head -n1)
EQ=$(lab "equip:$CHAR:$RIFLE" | grep -a '^INFO equip' | head -n1)
check "rifle_equipped" "$( grep -q 'ok=true' <<<"$EQ" && echo 1 || echo 0 )" "CDEF rifle oid ${RIFLE:-none}"
L1=$(lab_kv "level:$CHAR" stored)
check_eq "equip_leaves_level_stale" "${L1:-x}" "${L0:-y}" "stored=$L1 after equipping the rifle (stock recomputes only on a skill award)"

MOD=$(lab_kv "skillmod:$CHAR:private_rifle_combat_difficulty" private_rifle_combat_difficulty)
EXPECT=$(( MOD / 100 + 1 )); [ "$EXPECT" -gt 25 ] && EXPECT=25
check "rifle_line_above_bare_hands" "$( [ "$EXPECT" -gt "${L0:-0}" ] && echo 1 || echo 0 )" "private_rifle_combat_difficulty=$MOD → level $EXPECT"

# the login hook
lab "loginHook:$CHAR" >/dev/null
ROW=$(lab "level:$CHAR" | grep -a '^INFO level' | head -n1)
L2=$(grep -o 'stored=[0-9]*' <<<"$ROW" | cut -d= -f2)
check_eq "login_recomputes_level" "${L2:-x}" "$EXPECT" "$ROW"
check "strength_agrees" "$( [ "$(grep -o 'strength=[0-9]*' <<<"$ROW" | cut -d= -f2)" = "$L2" ] && echo 1 || echo 0 )" "the lab's fighting strength and the stored level agree once both read the rifle"

cleanup
wait "$BOT_PID"
check_eq "client_exit_0" "$?" "0"
finish
