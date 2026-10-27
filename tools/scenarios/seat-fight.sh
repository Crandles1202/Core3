#!/usr/bin/env bash
# Phase 7.4 — a seat fights: the lab puts the character in the open desert with a master marksman's skills and
# hands it a CDEF rifle (equipped by the lab) and spawns a kreetle 15 m away; tools/seat fight closes to reach,
# attacks it (attack, then defaultattack every 3 s, both real queue commands), reads the kill server-side and loots
# the corpse with `loot all`. The oracle confirms the kreetle is dead and the character is not.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SEAT="$REPO/tools/seat"
NAME="labfight-$$"
X0=3700; Y0=-4700
[ -n "$CHAR" ] || die "no Lab* character on account $BOT_USER (run: swg test bot)"

RAT=""; RAIDER=""
cleanup() { [ -n "$RAT" ] && lab "destroyObject:$RAT" >/dev/null 2>&1; [ -n "$RAIDER" ] && lab "destroyObject:$RAIDER" >/dev/null 2>&1; "$SEAT" stop "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

OUT=$("$SEAT" start "$BOT_USER" "$CHAR" --name "$NAME" --timeout 600 2>&1); RC=$?
check_eq "seat_started" "$RC" "0" "$(tail -n1 <<<"$OUT")"
[ "$RC" = 0 ] || { "$SEAT" log "$NAME" 30 | sed 's/^/   client: /'; die "seat did not start"; }
lab "skill:$CHAR:combat_marksman_master" >/dev/null
lab "skill:$CHAR:outdoors_scout_novice" >/dev/null   # a scout harvests the corpse after the loot (7.5)
SCOUT0=$(lab "xp:$CHAR:scout" 8 | sed -n 's/.*amount=\([0-9]*\).*/\1/p' | head -n1)
RIFLE=$(lab "give:$CHAR:object/weapon/ranged/rifle/rifle_cdef.iff" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | head -n1)
EQ=$(lab "equip:$CHAR:$RIFLE" | grep -a '^INFO equip' | head -n1)
check "rifle_equipped" "$( grep -q 'ok=true' <<<"$EQ" && echo 1 || echo 0 )" "CDEF rifle oid ${RIFLE:-none}: $(grep -o 'ok=[a-z]*' <<<"$EQ")"
lab "heal:$CHAR:health:2000" >/dev/null; lab "heal:$CHAR:action:2000" >/dev/null; lab "heal:$CHAR:mind:2000" >/dev/null
lab "travel:$CHAR:tatooine:$X0:$Y0" >/dev/null
sleep 3
"$SEAT" cmd "$NAME" stand --nowait >/dev/null 2>&1 || true

RAT=$(lab "spawnNpcAt:kreetle:tatooine:$((X0 + 15)):$Y0:0" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | head -n1)
check "rat_spawned" "$( [ -n "$RAT" ] && echo 1 || echo 0 )" "kreetle oid ${RAT:-none} 15 m east"
[ -n "$RAT" ] || die "no rat"
sleep 2

T0=$(date +%s)
FIGHT=$("$SEAT" fight "$NAME" "$RAT" --max 120 --reach 20 --harvest 2>&1); RC=$?
T1=$(date +%s)
check_eq "fight_won" "$RC" "0" "$(grep -a '^fight:' <<<"$FIGHT" | head -n1) ($((T1 - T0)) s)"
ALIVE=$(lab "objectAlive:$RAT" 8 | sed -n 's/.*alive=\([0-9]*\).*/\1/p' | head -n1)
check_eq "rat_dead_on_server" "${ALIVE:-1}" "0" "alive=${ALIVE:-?}"
check "corpse_looted" "$( grep -q '"looted": true' <<<"$FIGHT" && echo 1 || echo 0 )" "loot all sent on the corpse"
SCOUT1=$(lab "xp:$CHAR:scout" 8 | sed -n 's/.*amount=\([0-9]*\).*/\1/p' | head -n1)
check "corpse_harvested" "$( grep -q '"harvested": true' <<<"$FIGHT" && echo 1 || echo 0 )" "harvestcorpse on the kreetle: scout experience ${SCOUT0:-?} → ${SCOUT1:-?} $(grep -o '"harvestSaid": "[^"]*"' <<<"$FIGHT")"
check "scout_xp_paid" "$( [ "${SCOUT1:-0}" -gt "${SCOUT0:-0}" ] && echo 1 || echo 0 )" "a kreetle is level 10: 69 experience"
HAM=$(lab "ham:$CHAR" 8 | grep -a '^INFO ham' | head -n1)
check "character_standing" "$( grep -q 'incap=true\|dead=true' <<<"$(lab "where:$CHAR" 8)" && echo 0 || echo 1 )" "$(grep -o 'health=[0-9/]*' <<<"$HAM")"
# the threat oracle the pilot's hunt asks before every fight: a Tusken raider 110 m north is aggressive and level 19
RAIDER=$(lab "spawnNpcAt:tusken_raider:tatooine:$X0:$((Y0 + 110)):0" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | head -n1)
check "raider_spawned" "$( [ -n "$RAIDER" ] && echo 1 || echo 0 )" "tusken_raider oid ${RAIDER:-none} 110 m north"
TH=$(lab "threats:$CHAR:150" 10)
ME=$(grep -a '^INFO me ' <<<"$TH" | head -n1)
STRENGTH=$(sed -n 's/.*strength=\([0-9]*\).*/\1/p' <<<"$ME")
check "threats_strength" "$( [ "${STRENGTH:-0}" -ge 1 ] && echo 1 || echo 0 )" "$ME"
ROW=$(grep -a '^INFO threat ' <<<"$TH" | grep -a "oid=$RAIDER" | head -n1)
check "raider_is_a_threat" "$( grep -q 'aggressive=true' <<<"$ROW" && echo 1 || echo 0 )" "${ROW:-no threat row for the raider}"
check "threat_level_read" "$( grep -q 'level=19' <<<"$ROW" && echo 1 || echo 0 )" "$(grep -o 'level=[0-9]*' <<<"$ROW")"
LVL=$(lab "objectsNear:tatooine:$X0:$((Y0 + 110)):40:1025" 8 | grep -a "oid=$RAIDER" | grep -o 'level=[0-9]*' | head -n1)
check_eq "objectsNear_level" "${LVL:-none}" "level=19" "the object scan carries the level the pilot picks prey by"
cleanup   # the creature too: a leftover level-10 rat at the shared desert spot kills the next scenario's character
trap - EXIT
finish
