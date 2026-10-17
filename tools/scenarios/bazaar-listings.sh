#!/usr/bin/env bash
# Phase 2.5: a character may hold more than 25 bazaar listings (Final Boss default 100; stock 25).
# The oracle spawns a bazaar terminal next to the character and hands over 26 cheap items; the bot
# lists all 26 for instant sale through real CreateImmediateAuction packets. Stock Core3 would
# answer the 26th with ItemSoldMessage status 13 (TOOMANYITEMS). Also checks the 20 cr sales fee.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TERMINAL="object/tangible/terminal/terminal_bazaar.iff"
ITEM="object/tangible/food/bread_loaf_full_s1.iff"
N=26; PRICE=10; FEE=20

# --- stage: terminal + items while the character is online -----------------------------------
bot_bg --wait 40
wait_online || die "$CHAR never came online"
lab "travel:$CHAR:tatooine:3520:-4800" >/dev/null
sleep 1
TOID=$(lab_kv "spawnObjectNear:$CHAR:$TERMINAL:2:0" oid)
check "bazaar_spawned" "$( [ -n "$TOID" ] && echo 1 || echo 0 )" "oid=$TOID"
[ -n "$TOID" ] || { wait "$BOT_PID"; die "could not spawn a bazaar terminal"; }

LOAVES0=$(lab "inventory:$CHAR" | grep -c 'bread_loaf')
OIDS=()
for i in $(seq 1 $N); do
	oid=$(lab_kv "give:$CHAR:$ITEM" oid)
	[ -n "$oid" ] && OIDS+=("$oid")
done
check_eq "items_handed_over" "${#OIDS[@]}" "$N"
BANK0=$(lab_kv "cash:$CHAR" bank)
wait "$BOT_PID"

# --- act: list every item in one session -------------------------------------------------------
ARGS=(--keep-going --wait 3)          # keep going so a rejected listing is counted, not fatal
for oid in "${OIDS[@]}"; do ARGS+=(--sell "$oid" "$TOID" "$PRICE" --auction-timeout 8); done
ARGS+=(--wait 1)
bot "${ARGS[@]}"
RC=$?
check_eq "client_exit_0" "$RC" "0"
OK=$(bot_action_count sell ok); FAILED=$(bot_action_count sell failed)
REJECTED13=$(grep -ao '=> #[0-9]* {"action":"sell"[^}]*"auctionStatus":13' "$BOTLOG" | wc -l)
check_eq "all_26_listings_accepted" "$OK" "$N" "$OK ok, $FAILED failed ($REJECTED13 with status 13 = stock 25-listing cap)"

# --- observe --------------------------------------------------------------------------------
BANK1=$(lab_kv "cash:$CHAR" bank)
check_eq "sales_fee_per_listing" "$(( BANK0 - BANK1 ))" "$(( N * FEE ))" "bank $BANK0 -> $BANK1"
LEFT=$(lab "inventory:$CHAR" | grep -c 'bread_loaf')
check_eq "listed_items_left_inventory" "$LEFT" "$LOAVES0" "loaves in inventory $LOAVES0 -> $LEFT (listed ones moved to the bazaar)"

# --- clean up: take the listings back (exercises --retrieve), destroy the loaves and the terminal
ARGS=(--keep-going --wait 2)
for oid in "${OIDS[@]}"; do ARGS+=(--retrieve "$oid" "$TOID" --auction-timeout 8); done
ARGS+=(--wait 1)
bot "${ARGS[@]}"
check_eq "retrieve_client_exit_0" "$?" "0"
check_eq "all_26_retrieved" "$(bot_action_count retrieve ok)" "$N" "$(bot_action_count retrieve failed) failed"
for oid in "${OIDS[@]}"; do lab "destroyObject:$oid" >/dev/null; done
check_eq "loaves_cleaned_up" "$(lab "inventory:$CHAR" | grep -c 'bread_loaf')" "$LOAVES0"
lab "destroyObject:$TOID" >/dev/null
finish
