#!/usr/bin/env bash
# Phase 2.9: the traveling merchant. Find him, travel there, buy through the real UI (conversation
# -> stock window), then force a move and check he is gone from the old city and present in a new
# one with a different stock.
# covers: fb_traveling_merchant
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

NPC=fb_traveling_merchant

# --- where is he, what does he sell -----------------------------------------------------------
STATUS=$(lab "merchant" | grep '^INFO merchant ' | head -1)
STOP0=$(printf '%s\n' "$STATUS" | sed -n 's/.*[[:space:]]stop=\([0-9]*\).*/\1/p')
PLANET=$(printf '%s\n' "$STATUS" | sed -n 's/.*[[:space:]]planet=\([a-z0-9_]*\).*/\1/p')
MX=$(printf '%s\n' "$STATUS" | sed -n 's/.*[[:space:]]x=\([-0-9]*\).*/\1/p')
MY=$(printf '%s\n' "$STATUS" | sed -n 's/.*[[:space:]]y=\([-0-9]*\).*/\1/p')
check "merchant_has_a_stop" "$( [ -n "$STOP0" ] && echo 1 || echo 0 )" "$STATUS"
FIRST_ITEM=$(lab "merchant" | grep '^INFO merchant_item i=1 ' | sed -n 's/.*name=\(.*\) template=.*/\1/p')
PRICE=$(lab "merchant" | grep '^INFO merchant_item i=1 ' | sed -n 's/.*price=\([0-9]*\).*/\1/p')
check "stock_listed" "$( [ -n "$FIRST_ITEM" ] && echo 1 || echo 0 )" "first item: $FIRST_ITEM ($PRICE cr)"

OID=$(printf '%s\n' "$STATUS" | sed -n 's/.*[[:space:]]oid=\([0-9]*\).*/\1/p')
LIVE=$(lab "objectAlive:$OID" | grep -c 'alive=1')     # the object itself; the spawn registry can lag a boot-time spawn
check "merchant_spawned_in_world" "$( [ -n "$OID" ] && [ "$OID" != "0" ] && [ "$LIVE" = "1" ] && echo 1 || echo 0 )" "oid=$OID live=$LIVE"
[ -n "$OID" ] || die "no $NPC spawn found"

# --- stage: travel to him -----------------------------------------------------------------------
bot_bg --wait 15
wait_online || die "$CHAR never came online"
lab "travel:$CHAR:$PLANET:$((MX + 2)):$MY" >/dev/null
CASH0=$(lab_kv "cash:$CHAR" cash)
wait "$BOT_PID"

# --- act: buy the first item through conversation + stock window ------------------------------
# step up to him inside the talking session (a logged-in character placed 2 m east can still lack line of sight
# at a stop by a wall; gotoNpc puts it 1.5 m in front, facing him)
bot_bg --wait 12 --converse "$OID" --options 0 --wait 1 --sui "$FIRST_ITEM" --sui-match "Traveling Goods" --wait 2
wait_online || die "$CHAR never came back online"
lab "gotoNpc:$CHAR:fb_traveling_merchant" >/dev/null
wait "$BOT_PID"
RC=$?
check_eq "client_exit_0" "$RC" "0"
[ "$RC" = 0 ] || bot_errors
check "greeting_seen" "$(grep -aqi 'purveyor of the odd' "$BOTLOG" && echo 1 || echo 0)"
check_eq "stock_window_answered" "$(bot_action_count sui ok)" "1"
CASH1=$(lab_kv "cash:$CHAR" cash)
check_eq "price_deducted_via_ui" "$(( CASH0 - CASH1 ))" "$PRICE" "cash $CASH0 -> $CASH1"

# --- act 2: he moves on ---------------------------------------------------------------------------
MOVED=$(lab "merchantMove" | grep '^INFO merchant ' | head -1)
STOP1=$(printf '%s\n' "$MOVED" | sed -n 's/.*[[:space:]]stop=\([0-9]*\).*/\1/p')
check "moved_to_a_different_stop" "$( [ -n "$STOP1" ] && [ "$STOP1" != "$STOP0" ] && echo 1 || echo 0 )" "stop $STOP0 -> $STOP1"
sleep 2
COUNT=$(lab "npc:$NPC" | grep -c '^INFO npc ')
check_eq "exactly_one_merchant_after_move" "$COUNT" "1" "$COUNT spawns of $NPC"
GONE=$(lab "npc:$NPC" | grep -c "oid=$OID")
check_eq "old_merchant_gone" "$GONE" "0"
NEW_FIRST=$(lab "merchant" | grep '^INFO merchant_item i=1 ' | sed -n 's/.*name=\(.*\) template=.*/\1/p')
check "stock_rotated" "$( [ "$NEW_FIRST" != "$FIRST_ITEM" ] && echo 1 || echo 0 )" "'$FIRST_ITEM' -> '$NEW_FIRST'"

finish
