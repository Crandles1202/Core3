#!/usr/bin/env bash
# Phase 3.7: ambient life in the Mos Eisley cantina. All extra patrons are seated in the right cell;
# a beat with nobody near is quiet; with the character in the room a beat produces a newcomer line,
# chatter or an emote, and spoken lines reach the client as spatial chat; a seat can change hands.
# covers: fb_ambient_life fb_cities tasks/cities/
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LOC=1
ANCHOR_PLANET=tatooine; ANCHOR_X=12.0; ANCHOR_Z=-0.9; ANCHOR_Y=1.5; ANCHOR_CELL=1082877

# --- seats --------------------------------------------------------------------------------------
SEATS=$(lab "ambient:$LOC" | grep -c '^INFO ambient seat=')
ALIVE=$(lab "ambient:$LOC" | grep '^INFO ambient seat=' | grep -v -c 'oid=0$')
check_eq "all_seats_filled" "$ALIVE" "$SEATS" "$ALIVE of $SEATS seats have a live patron"
WRONG=$(lab "ambient:$LOC" | grep '^INFO ambient seat=' | grep -v 'oid=0$' | grep -v -c "cell=$ANCHOR_CELL")
check_eq "patrons_in_the_cantina_cell" "$WRONG" "0" "$WRONG patrons outside cell $ANCHOR_CELL"

# --- quiet room: nobody near -> the beat does nothing ------------------------------------------
# (the lab character may be standing somewhere else; make sure they are not in the cantina first)
bot_bg --wait 40
wait_online || die "$CHAR never came online"
lab "travel:$CHAR:tatooine:3520:-4800" >/dev/null
sleep 1
check_eq "quiet_when_nobody_near" "$(lab_kv "ambientTick:$LOC" result)" "quiet"

# --- someone walks in --------------------------------------------------------------------------
lab "travelCell:$CHAR:$ANCHOR_PLANET:$ANCHOR_X:$ANCHOR_Z:$ANCHOR_Y:$ANCHOR_CELL" >/dev/null
sleep 2
R1=$(lab "ambientTick:$LOC" | sed -n 's/^INFO ambientTick result=//p')
R2=$(lab "ambientTick:$LOC" | sed -n 's/^INFO ambientTick result=//p')
R3=$(lab "ambientTick:$LOC" | sed -n 's/^INFO ambientTick result=//p')
say "INFO beats: [$R1] [$R2] [$R3]"
check "beats_not_quiet_with_player_near" "$( [ "$R1" != quiet ] && [ "$R2" != quiet ] && [ "$R3" != quiet ] && echo 1 || echo 0 )"
check "first_beat_notices_newcomer_or_talks" "$( printf '%s' "$R1" | grep -qE '^(newcomer|chat|galaxy|emote):' && echo 1 || echo 0 )" "$R1"
SPOKEN=$(printf '%s\n%s\n%s\n' "$R1" "$R2" "$R3" | sed -n 's/^\(newcomer\|chat\|galaxy\)://p' | head -1)

# --- a seat changes hands -----------------------------------------------------------------------
OLD=$(lab "ambient:$LOC" | grep '^INFO ambient seat=1 ' | sed -n 's/.*oid=\([0-9]*\).*/\1/p')
NEW=$(lab_kv "ambientChurn:$LOC:1" oid)
check "seat1_churned_to_new_patron" "$( [ -n "$NEW" ] && [ "$NEW" != "0" ] && [ "$NEW" != "$OLD" ] && echo 1 || echo 0 )" "oid $OLD -> $NEW"
sleep 1
NOW=$(lab "ambient:$LOC" | grep '^INFO ambient seat=1 ' | sed -n 's/.*oid=\([0-9]*\).*/\1/p')
check_eq "seat1_status_shows_new_patron" "$NOW" "$NEW"
wait "$BOT_PID"

# --- the client heard it --------------------------------------------------------------------------
if [ -n "$SPOKEN" ]; then
	check "spoken_line_reached_client" "$(grep -aqF "SpatialChat from=" "$BOTLOG" && grep -aqF "$SPOKEN" "$BOTLOG" && echo 1 || echo 0)" "'$SPOKEN'"
else
	say "INFO no spoken line in three beats (all emotes); spatial chat check skipped"
fi

finish
