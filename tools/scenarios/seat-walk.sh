#!/usr/bin/env bash
# Phase 7.1 — a seat walks: the lab puts the character on open ground east of Mos Eisley, tools/seat asks
# the server's pathfinder for a route 60 m away and walks it with real movement packets; the oracle
# then reads the character's server-side position. Nothing is teleported during the walk.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SEAT="$REPO/tools/seat"
NAME="labwalk-$$"
X0=3700; Y0=-4700          # open desert east of the Mos Eisley walls
X1=3760; Y1=-4700
[ -n "$CHAR" ] || die "no Lab* character on account $BOT_USER (run: swg test bot)"

cleanup() { "$SEAT" stop "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# --- path from the oracle, before anyone is online --------------------------------------------
PATHLINE=$(lab "pathTo:tatooine:$X0:$Y0:$X1:$Y1" 15 | grep -a '^INFO path' | head -n1)
NPTS=$(sed -n 's/.*[[:space:]]n=\([0-9]*\).*/\1/p' <<<"$PATHLINE")
check_ge "pathfinder_route" "${NPTS:-0}" 2 "$(sed 's/ pts=.*//' <<<"$PATHLINE")"

# --- seat up, character placed (a teleport the client must ack) --------------------------------
OUT=$("$SEAT" start "$BOT_USER" "$CHAR" --name "$NAME" --timeout 600 2>&1); RC=$?
check_eq "seat_started" "$RC" "0" "$(tail -n1 <<<"$OUT")"
[ "$RC" = 0 ] || { "$SEAT" log "$NAME" 30 | sed 's/^/   client: /'; die "seat did not start"; }

lab "travel:$CHAR:tatooine:$X0:$Y0" >/dev/null
sleep 3
TP=$("$SEAT" vars "$NAME" /Teleport 2>&1)
check "teleport_acked" "$( grep -q '"count"' <<<"$TP" && echo 1 || echo 0 )" "the client saw and acked the server's move"
"$SEAT" cmd "$NAME" stand --nowait >/dev/null 2>&1 || true

# --- walk ---------------------------------------------------------------------------------------
T0=$(date +%s)
WALK=$("$SEAT" walk "$NAME" "$X1" "$Y1" 2>&1); RC=$?
T1=$(date +%s)
check_eq "walk_ok" "$RC" "0" "$(grep -o '"error": "[^"]*"' <<<"$WALK" | head -n1)"
PACKETS=$(sed -n 's/.*"packets": \([0-9]*\).*/\1/p' <<<"$WALK")
check_ge "movement_packets_sent" "${PACKETS:-0}" 10 "${PACKETS:-0} packets in $((T1 - T0)) s"
check_ge "took_real_time" "$((T1 - T0))" 8 "60 m at 4.5 m/s is ~13 s"

POS=$(lab "where:$CHAR" 8 | grep -a '^INFO' | head -n1)
PX=$(sed -n 's/.*[[:space:]]x=\(-\{0,1\}[0-9.]*\).*/\1/p' <<<"$POS")
PY=$(sed -n 's/.*[[:space:]]y=\(-\{0,1\}[0-9.]*\).*/\1/p' <<<"$POS")
DIST=$(awk -v px="${PX:-0}" -v py="${PY:-0}" -v gx="$X1" -v gy="$Y1" 'BEGIN{d=sqrt((px-gx)^2+(py-gy)^2); printf "%.1f", d}')
check "arrived_on_server" "$(awk "BEGIN{print ($DIST < 3) ? 1 : 0}")" "server says $PX,$PY — $DIST m from the goal"

"$SEAT" stop "$NAME" >/dev/null 2>&1
trap - EXIT
finish
