#!/usr/bin/env bash
# Phase 7.6a — travel on a seat. Leg 1: the lab puts the character outside the Mos Eisley shuttleport; tools/seat
# travel walks to the ticket terminal, buys a ticket to Bestine Shuttleport, walks to the pad, boards when the
# shuttle lands (waiting out its away time) and the oracle sees the character at Bestine. Leg 2: from outside
# the Bestine starport, whose ticket terminals stand inside the building (cell walk through the door), a ticket
# to Mos Eisley Starport and the shuttle back. Both are real packets: no teleport once the trip starts.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SEAT="$REPO/tools/seat"
NAME="labtravel-$$"
[ -n "$CHAR" ] || die "no Lab* character on account $BOT_USER (run: swg test bot)"

cleanup() { "$SEAT" stop "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

near() {  # near <x> <y> <radius> → 1 when the character stands within radius of x,y
  local POS PX PY
  POS=$(lab "where:$CHAR" 8 | grep -a '^INFO where' | head -n1)
  PX=$(sed -n 's/.*[[:space:]]x=\(-\{0,1\}[0-9.]*\).*/\1/p' <<<"$POS"); PY=$(sed -n 's/.*[[:space:]]y=\(-\{0,1\}[0-9.]*\).*/\1/p' <<<"$POS")
  LAST_DIST=$(awk -v px="${PX:-0}" -v py="${PY:-0}" -v gx="$1" -v gy="$2" 'BEGIN{printf "%.0f", sqrt((px-gx)^2+(py-gy)^2)}')
  LAST_POS="$PX,$PY"
  [ "$LAST_DIST" -le "$3" ] && echo 1 || echo 0
}

# --- the oracle knows the points, their terminals and shuttles ------------------------------------
POINTS=$(lab "travelPoints:tatooine" 30 | grep -a '^INFO travelpoint')
ME=$(grep -a 'name=Mos_Eisley_Shuttleport ' <<<"$POINTS")
BS=$(grep -a 'name=Bestine_Starport ' <<<"$POINTS")
check "shuttleport_has_terminal_and_shuttle" "$( grep -q ' terminal=[1-9]' <<<"$ME" && grep -q ' shuttle=[1-9]' <<<"$ME" && echo 1 || echo 0 )" "$(sed 's/INFO travelpoint //' <<<"$ME" | cut -c1-120)"
check "starport_terminal_is_indoors" "$( grep -q ' tcell=[1-9]' <<<"$BS" && echo 1 || echo 0 )" "$(grep -o 'tcellName=[^ ]*' <<<"$BS")"

# --- seat up, character placed by the shuttleport ---------------------------------------------------
OUT=$("$SEAT" start "$BOT_USER" "$CHAR" --name "$NAME" --timeout 900 2>&1); RC=$?
check_eq "seat_started" "$RC" "0" "$(tail -n1 <<<"$OUT")"
[ "$RC" = 0 ] || { "$SEAT" log "$NAME" 30 | sed 's/^/   client: /'; die "seat did not start"; }
lab "travel:$CHAR:tatooine:3440:-4640" >/dev/null
sleep 3
"$SEAT" cmd "$NAME" stand --nowait >/dev/null 2>&1 || true

# --- leg 1: shuttleport to shuttleport ------------------------------------------------------------
T0=$(date +%s)
TRIP=$("$SEAT" travel "$NAME" tatooine Bestine_Shuttleport --wait 300 2>&1); RC=$?
T1=$(date +%s)
check_eq "leg1_trip_ok" "$RC" "0" "$(grep -o '"error": "[^"]*"' <<<"$TRIP" | head -n1)"
check "leg1_ticket_bought" "$( grep -q '^ticket [1-9]' <<<"$TRIP" && echo 1 || echo 0 )" "$(grep -a '^ticket' <<<"$TRIP" | cut -c1-100)"
check_eq "leg1_new_scene" "$(sed -n 's/.*"terrain": "\([a-z0-9_]*\)".*/\1/p' <<<"$TRIP" | head -n1)" "tatooine" "arrival scene $(grep -o '"terrain": "[^"]*"' <<<"$TRIP" | head -n1) after $((T1 - T0)) s"
check "leg1_arrived_at_bestine" "$(near -1098.5 -3563.5 60)" "server says $LAST_POS — $LAST_DIST m from the Bestine shuttleport pad"
SCENES=$("$SEAT" vars "$NAME" /Scene 2>&1 | sed -n 's/.*"count": \([0-9]*\).*/\1/p' | head -n1)
check_ge "client_counted_two_scenes" "${SCENES:-0}" 2 "Scene/count=${SCENES:-?}"
[ "$RC" = 0 ] || { "$SEAT" log "$NAME" 40 | sed 's/^/   client: /'; die "leg 1 failed"; }

# --- leg 2: starport to starport, ticket terminal inside the building -----------------------------
lab "travel:$CHAR:tatooine:-1330:-3620" >/dev/null
sleep 3
"$SEAT" cmd "$NAME" stand --nowait >/dev/null 2>&1 || true
T0=$(date +%s)
TRIP=$("$SEAT" travel "$NAME" tatooine Mos_Eisley_Starport --from Bestine_Starport --wait 300 2>&1); RC=$?
T1=$(date +%s)
check_eq "leg2_trip_ok" "$RC" "0" "$(grep -o '"error": "[^"]*"' <<<"$TRIP" | head -n1)"
check "leg2_walked_indoors_to_the_terminal" "$( grep -q 'ends indoors' <<<"$TRIP" && echo 1 || echo 0 )" "$(grep -a '^path' <<<"$TRIP" | head -n1)"
check "leg2_ticket_bought" "$( grep -q '^ticket [1-9]' <<<"$TRIP" && echo 1 || echo 0 )" "$(grep -a '^ticket' <<<"$TRIP" | cut -c1-100)"
check "leg2_arrived_at_mos_eisley_starport" "$(near 3599.9 -4780.4 60)" "server says $LAST_POS — $LAST_DIST m from the starport pad after $((T1 - T0)) s"
[ "$RC" = 0 ] || "$SEAT" log "$NAME" 40 | sed 's/^/   client: /'

"$SEAT" stop "$NAME" >/dev/null 2>&1
trap - EXIT
finish
