#!/usr/bin/env bash
# Phase 3.11 (ambush mode): a convoy forms with its guards and cargo droid; the character, standing
# next to it, kills every guard (oracle-dealt lethal blows credited to the character); the convoy is
# destroyed: a loot crate with items appears, the character's Rebel standing goes up and Imperial
# standing down, the reward credits arrive, and the galaxy news carries the story.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

lab "territorySet:mos_eisley:65" >/dev/null   # Phase 3.4: a destroyed convoy costs the Empire 10 points here
ST=$(lab "convoySpawn" | grep '^INFO convoy ' | head -1)
check "convoy_spawned" "$(printf '%s' "$ST" | grep -q 'active=1' && echo 1 || echo 0)" "$ST"
GUARDS=$(printf '%s\n' "$ST" | sed -n 's/.*guards=\([0-9]*\)\/\([0-9]*\).*/\1\/\2/p')
check_eq "guards_alive" "${GUARDS%/*}" "${GUARDS#*/}" "guards $GUARDS"
check "cargo_droid_present" "$(printf '%s' "$ST" | grep -q 'cargo=[1-9]' && echo 1 || echo 0)"
LX=$(printf '%s\n' "$ST" | sed -n 's/.*leader=[0-9]* x=\([-0-9]*\).*/\1/p')
LY=$(printf '%s\n' "$ST" | sed -n 's/.*leader=[0-9]* x=[-0-9]* y=\([-0-9]*\).*/\1/p')
GUARD_OIDS=$(lab "questStatus:FbConvoys.mos_eisley.guards" | sed -n 's/.*value=\(.*\)$/\1/p' | tr ',' ' ')

bot_bg --wait 60
wait_online || die "$CHAR never came online"
lab "travel:$CHAR:tatooine:$((LX + 4)):$((LY + 4))" >/dev/null
REB0=$(lab_kv "factionStanding:$CHAR:rebel" standing); IMP0=$(lab_kv "factionStanding:$CHAR:imperial" standing)
CASH0=$(lab_kv "cash:$CHAR" cash)
sleep 2

KILLED=0
for oid in $GUARD_OIDS; do
	[ "$(lab_kv "killNpc:$CHAR:$oid" dead)" = "1" ] && KILLED=$((KILLED + 1))
	sleep 1
done
check_eq "all_guards_killed_by_character" "$KILLED" "${GUARDS#*/}"
sleep 4
ST2=$(lab "convoy" | grep '^INFO convoy ' | head -1)
check "convoy_destroyed" "$(printf '%s' "$ST2" | grep -q 'outcome=destroyed' && echo 1 || echo 0)" "$ST2"
CRATE=$(printf '%s\n' "$ST2" | sed -n 's/.*crate=\([0-9]*\).*/\1/p')
check "loot_crate_dropped" "$( [ -n "$CRATE" ] && [ "$CRATE" != "0" ] && echo 1 || echo 0 )" "crate=$CRATE"
if [ -n "$CRATE" ] && [ "$CRATE" != "0" ]; then
	ITEMS=$(lab_kv "containerItems:$CRATE" count)
	check_ge "crate_has_loot" "${ITEMS:-0}" 1 "$ITEMS items"
fi
REB1=$(lab_kv "factionStanding:$CHAR:rebel" standing); IMP1=$(lab_kv "factionStanding:$CHAR:imperial" standing)
check_gt "rebel_standing_up" "${REB1:-0}" "${REB0:-0}" "rebel $REB0 -> $REB1"
check "imperial_standing_down" "$( [ "${IMP1:-0}" -lt "${IMP0:-0}" ] && echo 1 || echo 0 )" "imperial $IMP0 -> $IMP1"
CASH1=$(lab_kv "cash:$CHAR" cash)
check_eq "reward_credits_paid" "$(( CASH1 - CASH0 ))" "750" "cash $CASH0 -> $CASH1"
check "news_posted" "$(lab "galaxyNews" | grep -q 'convoy was destroyed' && echo 1 || echo 0)"
check "territory_lost_ten" "$(lab "territory" | grep -q 'mos_eisley=55(' && echo 1 || echo 0)" "$(lab "territory" | grep '^INFO territory')"
wait "$BOT_PID"
check "character_told" "$(grep -aq 'convoy is destroyed' "$BOTLOG" && echo 1 || echo 0)"

# clean up the crate so it does not pile up outside the starport
[ -n "$CRATE" ] && [ "$CRATE" != "0" ] && lab "destroyObject:$CRATE" >/dev/null
finish
