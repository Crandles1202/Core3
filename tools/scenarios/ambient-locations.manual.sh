#!/usr/bin/env bash
# Phase 3.7/3.8 audit (manual, ~2 min per location): for every ambient-life location, every seat has
# a live patron in the location's cell, a beat is quiet with nobody there, and with the character
# teleported to the anchor a beat produces a newcomer line / chatter / emote. Run after adding or
# moving a location: swg test scenario ambient-locations
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

mapfile -t LOCS < <(lab "ambientLocations" | grep '^INFO ambient_location ')
check_gt "locations_known" "${#LOCS[@]}" 0 "${#LOCS[@]} locations"

bot_bg --wait $(( 25 * ${#LOCS[@]} + 20 ))
wait_online || die "$CHAR never came online"

for line in "${LOCS[@]}"; do
	IDX=$(printf '%s\n' "$line" | sed -n 's/.*idx=\([0-9]*\).*/\1/p')
	KEY=$(printf '%s\n' "$line" | sed -n 's/.*key=\([a-z0-9_]*\).*/\1/p')
	PL=$(printf '%s\n' "$line" | sed -n 's/.*planet=\([a-z0-9_]*\).*/\1/p')
	AX=$(printf '%s\n' "$line" | sed -n 's/.*[[:space:]]x=\([-0-9.]*\).*/\1/p')
	AZ=$(printf '%s\n' "$line" | sed -n 's/.*[[:space:]]z=\([-0-9.]*\).*/\1/p')
	AY=$(printf '%s\n' "$line" | sed -n 's/.*[[:space:]]y=\([-0-9.]*\).*/\1/p')
	CELL=$(printf '%s\n' "$line" | sed -n 's/.*cell=\([0-9]*\).*/\1/p')
	SEATS=$(printf '%s\n' "$line" | sed -n 's/.*seats=\([0-9]*\).*/\1/p')

	ALIVE=$(lab "ambient:$IDX" | grep '^INFO ambient seat=' | grep -v -c 'oid=0$')
	check_eq "${KEY}_all_seats_filled" "$ALIVE" "$SEATS"
	WRONG=$(lab "ambient:$IDX" | grep '^INFO ambient seat=' | grep -v 'oid=0$' | grep -v -c "cell=$CELL")
	check_eq "${KEY}_patrons_in_cell" "$WRONG" "0"

	lab "travel:$CHAR:tatooine:3520:-4800" >/dev/null       # far from every cantina
	sleep 1
	check_eq "${KEY}_quiet_when_empty" "$(lab_kv "ambientTick:$IDX" result)" "quiet"

	lab "travelCell:$CHAR:$PL:$AX:$AZ:$AY:$CELL" >/dev/null
	sleep 2
	R1=$(lab "ambientTick:$IDX" | sed -n 's/^INFO ambientTick result=//p')
	R2=$(lab "ambientTick:$IDX" | sed -n 's/^INFO ambientTick result=//p')
	say "INFO $KEY beats: [$R1] [$R2]"
	check "${KEY}_alive_with_player" "$( [ "$R1" != quiet ] && [ "$R2" != quiet ] && echo 1 || echo 0 )"
done

wait "$BOT_PID"
finish
