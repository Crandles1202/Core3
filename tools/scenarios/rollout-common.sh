#!/usr/bin/env bash
# rollout-common.sh — Phase 3.13: the per-planet audit of the living-world systems (sourced by rollout-<planet>.sh with
# PLANET set). Lab-only, no bot: every city of the planet is read back — its territory region, its patrol squads
# (and one squad is stepped), its HoloNet relays (one reads a segment), its convoy (formed and sent home), its
# invasion state, its ambient seats. Placement (line of sight, terrain, cells) is the Lua gate's checkPlacement.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
: "${PLANET:?PLANET must be set by the wrapper}"

CITIES=$(lab "cities" | grep "^INFO city " | grep " planet=$PLANET " | sed -n 's/.*key=\([^ ]*\).*/\1/p')
check "has_cities" "$( [ -n "$CITIES" ] && echo 1 || echo 0 )" "$(printf '%s' "$CITIES" | tr '\n' ' ')"
TERR=$(lab "territory" | grep '^INFO territory')
for city in $CITIES; do
	check "territory_$city" "$(printf '%s' "$TERR" | grep -q " $city=[0-9]*(" && echo 1 || echo 0)"
done

# patrols: every squad of the planet has a live leader; the first one steps and moves
PATROLS=$(lab "patrols" | grep '^INFO patrol ' | grep " planet=$PLANET ")
N=$(printf '%s\n' "$PATROLS" | grep -c 'route=')
check "patrols_present" "$( [ "$N" -ge 1 ] && echo 1 || echo 0 )" "$N routes on $PLANET"
check "patrol_leaders_alive" "$( [ "$N" -ge 1 ] && ! printf '%s\n' "$PATROLS" | grep -q 'leader=0 ' && echo 1 || echo 0 )" "$(printf '%s\n' "$PATROLS" | grep 'leader=0 ' | head -n 2 | cut -c1-120)"
ROUTE=$(printf '%s\n' "$PATROLS" | head -n1 | sed -n 's/.*route=\([0-9]*\).*/\1/p')
if [ -n "$ROUTE" ]; then
	R=$(lab_kv "patrolStep:$ROUTE" result)
	check "patrol_step_accepted" "$(printf '%s' "$R" | grep -qE '^[0-9]+$' && echo 1 || echo 0)" "route $ROUTE step -> $R"
fi

# relays: every relay of the planet is up; the first one reads a full segment about its own planet
RELAYS=$(lab "holonet" | grep '^INFO holonet ' | grep " planet=$PLANET ")
RN=$(printf '%s\n' "$RELAYS" | grep -c 'loc=')
check "relays_present" "$( [ "$RN" -ge 1 ] && echo 1 || echo 0 )" "$RN relays on $PLANET"
check "relays_up" "$( [ "$RN" -ge 1 ] && ! printf '%s\n' "$RELAYS" | grep -q 'relay=0 ' && echo 1 || echo 0 )" "$(printf '%s\n' "$RELAYS" | grep 'relay=0 ' | head -n 2 | cut -c1-120)"
LOC=$(printf '%s\n' "$RELAYS" | head -n1 | sed -n 's/.*loc=\([0-9]*\).*/\1/p')
if [ -n "$LOC" ]; then
	LINES=$(lab_kv "holonetBroadcast:$LOC" lines)
	check "relay_reads_a_segment" "$( [ "${LINES:-0}" -ge 5 ] && echo 1 || echo 0 )" "loc $LOC read $LINES lines"
fi

# convoys: each starport city forms one and sends it home (the route is the navmesh path starport -> plaza)
for city in $CITIES; do
	if lab "cities" | grep "^INFO city key=$city " | grep -q 'convoy=1'; then
		ST=$(lab "convoySpawn:$city" | grep '^INFO convoy ' | head -n1)
		check "convoy_forms_$city" "$(printf '%s' "$ST" | grep -q 'active=1 leader=[1-9]' && echo 1 || echo 0)" "$ST"
		ST2=$(lab "convoyArrive:$city" | grep '^INFO convoy ' | head -n1)
		check "convoy_home_$city" "$(printf '%s' "$ST2" | grep -q 'active=0' && echo 1 || echo 0)" "$ST2"
	fi
done

# invasions: a contested city reads idle (nothing started)
for city in $CITIES; do
	if lab "cities" | grep "^INFO city key=$city " | grep -q 'invasion=1'; then
		check "invasion_readable_$city" "$(lab "invasion:$city" | grep -q 'phase=' && echo 1 || echo 0)"
	fi
done

# ambient: every seat of the planet's locations has a live patron
AMB=$(lab "ambientLocations" | grep '^INFO ambient_location ' | grep " planet=$PLANET ")
for idx in $(printf '%s\n' "$AMB" | sed -n 's/.*idx=\([0-9]*\).*/\1/p'); do
	KEY=$(printf '%s\n' "$AMB" | grep " idx=$idx " | sed -n 's/.*key=\([^ ]*\).*/\1/p')
	SEATS=$(lab "ambient:$idx" | grep -c '^INFO ambient seat=')
	EMPTY=$(lab "ambient:$idx" | grep '^INFO ambient seat=' | grep -c 'oid=0$')
	check "seats_filled_$KEY" "$( [ "$SEATS" -ge 1 ] && [ "$EMPTY" = 0 ] && echo 1 || echo 0 )" "$EMPTY of $SEATS seats empty"
done
finish
