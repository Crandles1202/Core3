#!/usr/bin/env bash
# Phase 7.5 — a seat sells on the bazaar: the lab character is handed a resource stack, a bazaar terminal is spawned
# 30 m away, and the pilot's sell tool finds the stack by resource name in the inventory (lab inventory with names and
# units, the 7.5 getInventoryItems binding), finds the terminal (lab bazaarNear), walks to it and lists the stack with one
# CreateImmediateAuction packet; the oracle sees the stack leave the inventory and the 20 cr fee leave the bank. Then the
# seat takes the listing back (retrieve) and the stack is destroyed.
# covers: src/client tools/seat sell
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SEAT="$REPO/tools/seat"
NAME="labsell-$$"
TERMINAL="object/tangible/terminal/terminal_bazaar.iff"
PRICE=1500; FEE=20
[ -n "$CHAR" ] || die "no Lab* character on account $BOT_USER (run: swg test bot)"

TOID=""; STACK=""
cleanup() {
    [ -n "$STACK" ] && lab "destroyObject:$STACK" >/dev/null 2>&1
    [ -n "$TOID" ] && lab "destroyObject:$TOID" >/dev/null 2>&1
    "$SEAT" stop "$NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sell_with_pilot() {   # <item> <price> → the sell tool's JSON result on one line
    python3 - "$1" "$2" <<PY
import sys, json
sys.path.insert(0, "$REPO/tools/citizens")
import pilot
seat_mod = pilot.load_seat_module()
seat = seat_mod.Seat("$NAME", timeout=600)
impl, schema = pilot.seat_tools(seat, None, "$CHAR", "$NAME")
print("RESULT " + json.dumps(impl["sell"](sys.argv[1], int(sys.argv[2]))))
PY
}

OUT=$("$SEAT" start "$BOT_USER" "$CHAR" --name "$NAME" --timeout 600 2>&1); RC=$?
check_eq "seat_started" "$RC" "0" "$(tail -n1 <<<"$OUT")"
[ "$RC" = 0 ] || { "$SEAT" log "$NAME" 30 | sed 's/^/   client: /'; die "seat did not start"; }
lab "travel:$CHAR:tatooine:3520:-4800" >/dev/null
sleep 2
"$SEAT" cmd "$NAME" stand --nowait >/dev/null 2>&1 || true

# --- stage: a resource stack with a name, a terminal 30 m east -------------------------------------------------
lab "giveResource:$CHAR:mineral:5000" >/dev/null
INV=$(lab "inventory:$CHAR" 15)
LINE=$(grep -a '^INFO item .* resource=' <<<"$INV" | tail -n1)
STACK=$(sed -n 's/.*oid=\([0-9]*\).*/\1/p' <<<"$LINE")
RES=$(sed -n 's/.* resource=\([^ ]*\).*/\1/p' <<<"$LINE")
UNITS=$(sed -n 's/.* units=\([0-9]*\).*/\1/p' <<<"$LINE")
check "stack_with_a_name" "$( [ -n "$STACK" ] && [ -n "$RES" ] && [ "$RES" != "-" ] && echo 1 || echo 0 )" "$(cut -c1-160 <<<"$LINE")"
check_ge "stack_units_read" "${UNITS:-0}" "5000" "units=${UNITS:-?}"
TOID=$(lab_kv "spawnObjectNear:$CHAR:$TERMINAL:30:0" oid)
check "bazaar_spawned" "$( [ -n "$TOID" ] && echo 1 || echo 0 )" "oid=$TOID"
[ -n "$TOID" ] || die "could not spawn a bazaar terminal"
NEAR=$(lab "bazaarNear:$CHAR:200" 15)
check "bazaar_found_by_oracle" "$( grep -q "^INFO bazaar oid=$TOID " <<<"$NEAR" && echo 1 || echo 0 )" "$(grep -a '^INFO bazaars' <<<"$NEAR")"
BANK0=$(lab_kv "cash:$CHAR" bank)
RESNAME=$(tr '_' ' ' <<<"$RES")

# --- act: the pilot's sell tool, by resource name -----------------------------------------------------------
R=$(sell_with_pilot "$RESNAME" "$PRICE" 2>&1)
J=$(grep -a '^RESULT ' <<<"$R" | sed 's/^RESULT //')
check "sell_tool_ok" "$( grep -q '"ok": true' <<<"$J" && echo 1 || echo 0 )" "$(cut -c1-240 <<<"$J")"
grep -q '"ok": true' <<<"$J" || sed 's/^/   pilot: /' <<<"$R" | tail -n 12
check "listed_at_the_spawned_terminal" "$( grep -q "\"terminal\": $TOID" <<<"$J" && echo 1 || echo 0 )"
check "listing_status_zero" "$( grep -q '"status": 0' <<<"$J" && echo 1 || echo 0 )" "ItemSoldMessage 0 = listed"

# --- observe --------------------------------------------------------------------------------------------------
check_eq "stack_left_inventory" "$(lab "inventory:$CHAR" 15 | grep -c "^INFO item oid=$STACK ")" "0" "the stack moved to the bazaar"
BANK1=$(lab_kv "cash:$CHAR" bank)
check_eq "sales_fee_paid" "$(( BANK0 - BANK1 ))" "$FEE" "bank $BANK0 -> $BANK1"

# --- clean up: take it back through the seat, then destroy -----------------------------------------------------
RET=$("$SEAT" retrieve "$NAME" "$STACK" "$TOID" 2>&1)
check "retrieved" "$( grep -q '"ok": true' <<<"$RET" && echo 1 || echo 0 )" "$(cut -c1-160 <<<"$RET")"
check_eq "stack_back_in_inventory" "$(lab "inventory:$CHAR" 15 | grep -c "^INFO item oid=$STACK ")" "1"

cleanup
trap - EXIT
finish
