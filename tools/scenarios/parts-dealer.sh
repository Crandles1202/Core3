#!/usr/bin/env bash
# Phase 2.3: component vendor. The bot talks to the dealer; the oracle buys a standard and an
# advanced part through the screenplay's public purchase() (SUI cannot be driven by the bot) and
# checks the cash and the generated components in the inventory.
# covers: fb_parts_dealer
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NPC=fb_parts_dealer
STD_NAME="Blaster Power Handler";            STD_PRICE=1500
ADV_NAME="Blaster Power Handler (advanced)"; ADV_PRICE=4500
PART_TEMPLATE="component/weapon/blaster_power_handler"

LINE=$(lab "npc:$NPC" | grep '^INFO npc ' | head -1)
OID=$(printf '%s\n' "$LINE" | sed -n 's/.*[[:space:]]oid=\([0-9]*\).*/\1/p')
ZONE=$(printf '%s\n' "$LINE" | sed -n 's/.*[[:space:]]zone=\([a-z0-9_]*\).*/\1/p')
NX=$(printf '%s\n' "$LINE" | sed -n 's/.*[[:space:]]x=\([-0-9.]*\).*/\1/p' | cut -d. -f1)
NY=$(printf '%s\n' "$LINE" | sed -n 's/.*[[:space:]]y=\([-0-9.]*\).*/\1/p' | cut -d. -f1)
check "dealer_spawned" "$( [ -n "$OID" ] && echo 1 || echo 0 )" "oid=$OID zone=$ZONE at $NX,$NY"
[ -n "$OID" ] || die "no $NPC spawn found"

bot_bg --wait 15
wait_online || die "$CHAR never came online"
lab "gotoNpc:$CHAR:$OID" >/dev/null   # 2 m in front of the NPC, inside the Trade Hall (Phase 2.11)
wait "$BOT_PID"

# --- act 1: the conversation ------------------------------------------------------------------
bot --wait 2 --converse "$OID" --options 1 --wait 1    # option 1 = "Why buy parts from you?"
check_eq "converse_client_exit_0" "$?" "0"
check "greeting_mentions_parts" "$(grep -aqi 'Parts, crafter' "$BOTLOG" && echo 1 || echo 0)"
check "explain_screen_reached" "$(grep -aqi 'rolled fresh with real stats' "$BOTLOG" && echo 1 || echo 0)"

# --- act 2: buy a standard and an advanced part (character must be online) --------------------
bot_bg --wait 20
wait_online || die "$CHAR never came back online"
CASH0=$(lab_kv "cash:$CHAR" cash)
BEFORE=$(lab "inventory:$CHAR" | grep -c "$PART_TEMPLATE")

check_eq "standard_purchase_ok" "$(lab_kv "buyPart:$CHAR:$STD_NAME" result)" "ok"
check_eq "advanced_purchase_ok" "$(lab_kv "buyPart:$CHAR:$ADV_NAME" result)" "ok"
CASH1=$(lab_kv "cash:$CHAR" cash)
check_eq "prices_deducted" "$(( CASH0 - CASH1 ))" "$(( STD_PRICE + ADV_PRICE ))" "cash $CASH0 -> $CASH1"
AFTER=$(lab "inventory:$CHAR" | grep -c "$PART_TEMPLATE")
check_eq "two_components_added" "$(( AFTER - BEFORE ))" "2" "$PART_TEMPLATE items $BEFORE -> $AFTER"
wait "$BOT_PID"

finish
