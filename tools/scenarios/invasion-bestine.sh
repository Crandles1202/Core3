#!/usr/bin/env bash
# Phase 3.1: a Rebel invasion of Bestine. Construction: both squads muster and the galaxy is warned.
# Assault: the attackers advance; at the plaza opposing-faction NPCs fight on their own (the screenplay
# re-homes them there first, or they leash back to the desert, and pairs off stragglers). The character finishes the
# attackers off (credited as fighting for the garrison), the battle resolves as "held": standing,
# credits, news, territory shift, everything despawned.
# covers: fb_invasions tatooine_bestine
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CITY=bestine
bot_bg --wait 110
wait_online || die "$CHAR never came online"
lab "travel:$CHAR:tatooine:-1200:-3610" >/dev/null   # Bestine plaza, by the trainers
lab "questStatus:FbTerritory.$CITY:50" >/dev/null   # start from contested so the shift is visible
TERR0=$(lab "invasion:$CITY" | sed -n 's/.*territory=\([0-9]*\).*/\1/p' | head -1)
REB0=$(lab_kv "factionStanding:$CHAR:rebel" standing); IMP0=$(lab_kv "factionStanding:$CHAR:imperial" standing)
CASH0=$(lab_kv "cash:$CHAR" cash)

# --- construction -----------------------------------------------------------------------------------
ST1=$(lab "invasionBegin:$CITY" | grep '^INFO invasion ' | head -1)
check "construction_phase" "$(printf '%s' "$ST1" | grep -q 'phase=construction' && echo 1 || echo 0)" "$ST1"
A=$(printf '%s\n' "$ST1" | sed -n 's/.*attackers=\([0-9]*\)\/\([0-9]*\).*/\1\/\2/p'); D=$(printf '%s\n' "$ST1" | sed -n 's/.*defenders=\([0-9]*\)\/\([0-9]*\).*/\1\/\2/p')
check_eq "attackers_mustered" "${A%/*}" "7" "attackers $A"
check_eq "defenders_mustered" "${D%/*}" "6" "defenders $D"

# --- assault -----------------------------------------------------------------------------------------
ST2=$(lab "invasionAssault:$CITY" | grep '^INFO invasion ' | head -1)
check "combat_phase" "$(printf '%s' "$ST2" | grep -q 'phase=combat' && echo 1 || echo 0)" "$ST2"
check_eq "undecided_while_both_stand" "$(lab_kv "invasionResolve:$CITY" outcome)" "undecided"
# bring the fight to the plaza so it happens inside the scenario's window: move the attackers next to the garrison
for oid in $(lab "invasionSide:$CITY:attackers" | sed -n 's/.*oids=\(.*\)$/\1/p' | tr ',' ' '); do
	lab "teleportObject:$oid:tatooine:-1222:-3615" >/dev/null 2>&1
done
sleep 3
say "INFO engage pairs=$(lab_kv "invasionEngage:$CITY" pairs) (0 when both sides already found each other)"
sleep 25
ST3=$(lab "invasion:$CITY" | grep '^INFO invasion ' | head -1)
FIGHTING=$(printf '%s\n' "$ST3" | sed -n 's/.*fighting=\([0-9]*\).*/\1/p'); HURT=$(printf '%s\n' "$ST3" | sed -n 's/.*hurt=\([0-9]*\).*/\1/p')
A3=$(printf '%s\n' "$ST3" | sed -n 's/.*attackers=\([0-9]*\)\/.*/\1/p'); D3=$(printf '%s\n' "$ST3" | sed -n 's/.*defenders=\([0-9]*\)\/.*/\1/p')
check "factions_fight_each_other" "$( [ "${FIGHTING:-0}" -gt 0 ] || [ "${HURT:-0}" -gt 0 ] || [ "${A3:-7}" -lt 7 ] || [ "${D3:-6}" -lt 6 ] && echo 1 || echo 0 )" "$ST3"

# --- the character finishes the attackers ------------------------------------------------------------
for oid in $(lab "invasionSide:$CITY:attackers" | sed -n 's/.*oids=\(.*\)$/\1/p' | tr ',' ' '); do
	lab "killNpc:$CHAR:$oid" >/dev/null
done
sleep 2
OUT=$(lab_kv "invasionResolve:$CITY" outcome)
check_eq "garrison_held" "$OUT" "held"
ST4=$(lab "invasion:$CITY" | grep '^INFO invasion ' | head -1)
check "everything_despawned" "$(printf '%s' "$ST4" | grep -q 'phase=idle attackers=0/0 defenders=0/0' && echo 1 || echo 0)" "$ST4"
TERR1=$(printf '%s\n' "$ST4" | sed -n 's/.*territory=\([0-9]*\).*/\1/p')
check_eq "territory_shifted_to_empire" "$TERR1" "$(( TERR0 + 10 ))" "territory $TERR0 -> $TERR1"
IMP1=$(lab_kv "factionStanding:$CHAR:imperial" standing); REB1=$(lab_kv "factionStanding:$CHAR:rebel" standing)
check_gt "imperial_standing_up" "${IMP1:-0}" "${IMP0:-0}" "imperial $IMP0 -> $IMP1"
check "rebel_standing_down" "$( [ "${REB1:-0}" -lt "${REB0:-0}" ] && echo 1 || echo 0 )" "rebel $REB0 -> $REB1"
CASH1=$(lab_kv "cash:$CHAR" cash)
check_eq "winners_paid" "$(( CASH1 - CASH0 ))" "1000" "cash $CASH0 -> $CASH1"
check "news_posted" "$(lab "galaxyNews" | grep -q 'bounced off the garrison' && echo 1 || echo 0)"
wait "$BOT_PID"
check "client_got_the_warning" "$(grep -aq 'Rebel forces are massing' "$BOTLOG" && echo 1 || echo 0)"
check "client_got_the_assault_call" "$(grep -aq 'Rebel assault has begun' "$BOTLOG" && echo 1 || echo 0)"
check "client_got_the_result" "$(grep -aq 'repelled the Rebel assault' "$BOTLOG" && echo 1 || echo 0)"
check "character_rewarded_message" "$(grep -aq 'notes your part in it' "$BOTLOG" && echo 1 || echo 0)"
finish
