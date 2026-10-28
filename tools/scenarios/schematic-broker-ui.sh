#!/usr/bin/env bash
# Phase 2.2 through the real UI: the bot converses with the schematic broker, picks "Show me the
# catalogue", answers the two server UI windows (catalogue list, then item list) by row text, and
# the oracle confirms the datapad and the price. Exercises the bot's --sui action end to end.
# covers: fb_schematic_broker
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NPC=fb_schematic_broker
ITEM_NAME="Throw Pillow"; PRICE=400; SKILL=crafting_artisan_domestic_01
ITEM_TEMPLATE="loot_schematic/throwpillow_schematic"

LINE=$(lab "npc:$NPC" | grep '^INFO npc ' | head -1)
OID=$(printf '%s\n' "$LINE" | sed -n 's/.*[[:space:]]oid=\([0-9]*\).*/\1/p')
ZONE=$(printf '%s\n' "$LINE" | sed -n 's/.*[[:space:]]zone=\([a-z0-9_]*\).*/\1/p')
NX=$(printf '%s\n' "$LINE" | sed -n 's/.*[[:space:]]x=\([-0-9.]*\).*/\1/p' | cut -d. -f1)
NY=$(printf '%s\n' "$LINE" | sed -n 's/.*[[:space:]]y=\([-0-9.]*\).*/\1/p' | cut -d. -f1)
check "broker_spawned" "$( [ -n "$OID" ] && echo 1 || echo 0 )" "oid=$OID"
[ -n "$OID" ] || die "no $NPC spawn found"

# --- stage: stand next to the broker with the skill and a known inventory count -----------------
bot_bg --wait 15
wait_online || die "$CHAR never came online"
lab "gotoNpc:$CHAR:$OID" >/dev/null   # 2 m in front of the NPC, inside the Trade Hall (Phase 2.11)
check_eq "skill_for_item" "$(lab_kv "skill:$CHAR:$SKILL" has)" "true"
CASH0=$(lab_kv "cash:$CHAR" cash)
BEFORE=$(lab "inventory:$CHAR" | grep -c "$ITEM_TEMPLATE")
wait "$BOT_PID"

# --- act: conversation -> catalogue window -> item window, all through packets ------------------
bot --wait 2 --converse "$OID" --options 0 --wait 1 \
    --sui "Furniture" --sui-match "Schematic Broker" \
    --sui "$ITEM_NAME" --sui-match "Furniture" --wait 2
RC=$?
check_eq "client_exit_0" "$RC" "0"
[ "$RC" = 0 ] || bot_errors
check_eq "catalogue_window_answered" "$(bot_action_count sui ok)" "2" "$(bot_action_count sui failed) sui actions failed"
check "catalogue_window_listed_rows" "$(grep -aq 'SUI page .*Schematic Broker.*rows=3' "$BOTLOG" && echo 1 || echo 0)"

# --- observe --------------------------------------------------------------------------------
CASH1=$(lab_kv "cash:$CHAR" cash)
check_eq "price_deducted_via_ui" "$(( CASH0 - CASH1 ))" "$PRICE" "cash $CASH0 -> $CASH1"
AFTER=$(lab "inventory:$CHAR" | grep -c "$ITEM_TEMPLATE")
check_eq "datapad_in_inventory" "$(( AFTER - BEFORE ))" "1" "$ITEM_TEMPLATE $BEFORE -> $AFTER"

finish
