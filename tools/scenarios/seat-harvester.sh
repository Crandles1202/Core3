#!/usr/bin/env bash
# Phase 7.6a — a harvester run on a seat: the lab hands the character an ore harvester deed and wind energy, puts it
# in the open desert east of Mos Eisley; the seat places the harvester (placeStructure), reads what it could extract
# here (HarvesterResourceDataMessage), selects the densest spawn, pays maintenance and deposits power through the
# real management windows (transfer boxes), activates it; the lab stands in for hours of extraction by filling the
# hopper, and the seat empties the hopper into its inventory (EmptyHopper). The harvester is torn down at the end.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SEAT="$REPO/tools/seat"
NAME="labharv-$$"
Y0=-4700
[ -n "$CHAR" ] || die "no Lab* character on account $BOT_USER (run: swg test bot)"

# a buildable spot east of Mos Eisley: the city's no-build region reaches far out, so ask the oracle
X0=""
for X in 4100 4400 4800 5200 5600 6000; do
  if lab "canBuild:tatooine:$X:$Y0" 8 | grep -aq 'permitted=true'; then X0=$X; break; fi
done
check "buildable_spot_found" "$( [ -n "$X0" ] && echo 1 || echo 0 )" "x=${X0:-none} y=$Y0 (canBuild oracle)"
[ -n "$X0" ] || die "no buildable spot east of Mos Eisley"

HOID=""
cleanup() {
  [ -n "$HOID" ] && lab "structureDestroy:$HOID" >/dev/null 2>&1
  "$SEAT" stop "$NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

json() { python3 -c "import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1], {'d': d}))" "$1" 2>/dev/null; }

# --- seat up, deed and energy in hand, standing in the desert ------------------------------------------
OUT=$("$SEAT" start "$BOT_USER" "$CHAR" --name "$NAME" --timeout 600 2>&1); RC=$?
check_eq "seat_started" "$RC" "0" "$(tail -n1 <<<"$OUT")"
[ "$RC" = 0 ] || { "$SEAT" log "$NAME" 30 | sed 's/^/   client: /'; die "seat did not start"; }
DEED=$(lab "give:$CHAR:object/tangible/deed/harvester_deed/harvester_ore_s1_deed.iff" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | head -n1)
check "deed_given" "$( [ -n "$DEED" ] && echo 1 || echo 0 )" "ore harvester deed oid $DEED"
lab "deedValues:$DEED:120:12000" >/dev/null     # a crafted deed carries these; a lab-made one has 0 and 0
lab "giveResource:$CHAR:wind:2000" >/dev/null
lab "travel:$CHAR:tatooine:$X0:$Y0" >/dev/null
sleep 3
"$SEAT" cmd "$NAME" stand --nowait >/dev/null 2>&1 || true
LOTS0=$(lab "structures:$CHAR" | sed -n 's/.*remaining=\([0-9-]*\).*/\1/p' | head -n1)

# --- place -----------------------------------------------------------------------------------------------
PLACE=$("$SEAT" place "$NAME" "$DEED" $((X0 + 12)) "$Y0" 0 2>&1); RC=$?
check_eq "place_ok" "$RC" "0" "$(grep -o '"error": "[^"]*"' <<<"$PLACE" | head -n1)$(grep -o '"serverSaid": "[^"]*"' <<<"$PLACE" | head -n1)"
HOID=$(sed -n 's/.*"structure": \([0-9]*\).*/\1/p' <<<"$PLACE" | head -n1)
[ "${HOID:-0}" != 0 ] || { HOID=""; "$SEAT" log "$NAME" 30 | sed 's/^/   client: /'; die "no harvester placed"; }
OWNED=$(lab "structures:$CHAR")
check "owner_sees_it" "$( grep -q "oid=$HOID " <<<"$OWNED" && echo 1 || echo 0 )" "$(grep -a "oid=$HOID " <<<"$OWNED" | cut -c6-120)"
LOTS1=$(sed -n 's/.*remaining=\([0-9-]*\).*/\1/p' <<<"$OWNED" | head -n1)
check_eq "one_lot_used" "$(( ${LOTS0:-0} - ${LOTS1:-0} ))" "1" "lots $LOTS0 -> $LOTS1"

# --- what is here, pick the densest ------------------------------------------------------------------------
RES=$("$SEAT" harvester "$NAME" "$HOID" resources 2>&1); RC=$?
check_eq "resource_list_ok" "$RC" "0" "$(grep -o '"error": "[^"]*"' <<<"$RES" | head -n1)"
NRES=$(json "len(d['result']['resources'])" <<<"$RES")
check_ge "resources_listed" "${NRES:-0}" 1 "${NRES:-0} spawns offered"
SPAWN=$(json "max(d['result']['resources'], key=lambda r: r['density'])['spawn']" <<<"$RES")
SNAME=$(json "max(d['result']['resources'], key=lambda r: r['density'])['name']" <<<"$RES")
SDENS=$(json "max(d['result']['resources'], key=lambda r: r['density'])['density']" <<<"$RES")
say "   densest here: $SNAME ($SDENS%) spawn $SPAWN"
SEL=$("$SEAT" harvester "$NAME" "$HOID" select "$SPAWN" 2>&1); RC=$?
check_eq "select_ok" "$RC" "0" "$(grep -o '"error": "[^"]*"' <<<"$SEL" | head -n1)"

# --- maintenance and power through the management windows ---------------------------------------------------
M=$("$SEAT" harvester "$NAME" "$HOID" maintain 500 2>&1); RC=$?
check_eq "maintenance_window_answered" "$RC" "0" "$(grep -o '"error": "[^"]*"' <<<"$M" | head -n1)"
P=$("$SEAT" harvester "$NAME" "$HOID" power 300 2>&1); RC=$?
check_eq "power_window_answered" "$RC" "0" "$(grep -o '"error": "[^"]*"' <<<"$P" | head -n1)"
A=$("$SEAT" harvester "$NAME" "$HOID" activate 2>&1); RC=$?
check_eq "activate_ok" "$RC" "0" "$(grep -o '"error": "[^"]*"' <<<"$A" | head -n1)"
sleep 2
ST=$(lab "harvester:$HOID" | grep -a '^INFO harvester' | head -n1)
check "server_says_active" "$( grep -q ' active=true' <<<"$ST" && echo 1 || echo 0 )" "$(grep -o 'active=[a-z]*' <<<"$ST")"
check_ge "maintenance_deposited" "$(sed -n 's/.*[[:space:]]maintenance=\([0-9-]*\).*/\1/p' <<<"$ST")" 400 "$(grep -o 'maintenance=[0-9-]* maintenanceRate=[0-9]*' <<<"$ST")"
check_ge "power_deposited" "$(sed -n 's/.*[[:space:]]power=\([0-9-]*\).*/\1/p' <<<"$ST")" 250 "$(grep -o 'power=[0-9-]* powerRate=[0-9]*' <<<"$ST")"
check_eq "hopper_max_from_the_deed" "$(sed -n 's/.*hopperMax=\([0-9]*\).*/\1/p' <<<"$ST")" "12000" "$(grep -o 'extractionRate=[0-9.]* actualRate=[0-9.]* hopperSize=[0-9]* hopperMax=[0-9]*' <<<"$ST")"
check_eq "active_resource_is_the_pick" "$(sed -n 's/.*activeResource=\([0-9]*\).*/\1/p' <<<"$ST")" "$SPAWN" "$(grep -o 'activeResourceName=[^ ]*' <<<"$ST")"

# --- the hopper: filled by the lab, emptied by the seat -----------------------------------------------------
lab "harvesterFill:$HOID:150" >/dev/null
HOP=$(lab "harvester:$HOID" | grep -a "^INFO hopper .* spawn=$SPAWN " | head -n1)
check "hopper_holds_the_fill" "$( grep -q 'quantity=150' <<<"$HOP" && echo 1 || echo 0 )" "$(cut -c6-120 <<<"$HOP")"
E=$("$SEAT" harvester "$NAME" "$HOID" empty "$SPAWN" 150 2>&1); RC=$?
check_eq "empty_hopper_ok" "$RC" "0" "$(grep -o '"error": "[^"]*"' <<<"$E" | head -n1)"
sleep 1
HOP2=$(lab "harvester:$HOID" | grep -a '^INFO harvester' | head -n1)
check_eq "hopper_emptied" "$(sed -n 's/.*hopperSize=\([0-9]*\).*/\1/p' <<<"$HOP2")" "0" "$(grep -o 'hopperSize=[0-9]* hopperMax=[0-9]* hopperItems=[0-9]*' <<<"$HOP2")"
CB=$(sed -n 's/.*"containersBefore": \([0-9]*\).*/\1/p' <<<"$E" | head -n1); CA=$(sed -n 's/.*"containersAfter": \([0-9]*\).*/\1/p' <<<"$E" | head -n1)
check "resource_container_arrived" "$( [ "${CA:-0}" -gt "${CB:-0}" ] && echo 1 || echo 0 )" "resource containers in view $CB -> $CA (the wind energy was one already)"

"$SEAT" harvester "$NAME" "$HOID" deactivate >/dev/null 2>&1 || true
lab "structureDestroy:$HOID" >/dev/null 2>&1; HOID=""
"$SEAT" stop "$NAME" >/dev/null 2>&1
trap - EXIT
finish
