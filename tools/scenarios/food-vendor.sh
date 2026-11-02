#!/usr/bin/env bash
# Final Boss 2.16: the chef sells every crafted dish, dessert and drink at a master's numbers, and the cantina drinks.
# The bot talks to her; the oracle buys a dish and a cantina drink and reads the dish's use count back (the chef's
# quantity, set through setConsumableValues, not the template's default).
# covers: fb_food_vendor foods_gen Consumable mos_eisley_trade_hall
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

OID=$(lab "npc:fb_food_vendor" | grep '^INFO npc ' | head -1 | sed -n 's/.*[[:space:]]oid=\([0-9]*\).*/\1/p')
check "chef_spawned" "$( [ -n "$OID" ] && echo 1 || echo 0 )" "oid=$OID"
[ -n "$OID" ] || die "no chef"
CAT=$(lab "foodVendor" 20)
ROWS=$(sed -n 's/.*INFO foodVendor shelves=[0-9]* rows=\([0-9]*\).*/\1/p' <<<"$CAT" | head -n1)
check_ge "shelves_stocked" "${ROWS:-0}" 100 "$ROWS rows"
check "no_spice" "$(grep -qi 'spice' <<<"$CAT" && echo 0 || echo 1)"

bot_bg --wait 15
wait_online || die "$CHAR never came online"
lab "gotoNpc:$CHAR:$OID" >/dev/null
wait "$BOT_PID"
bot --wait 2 --converse "$OID" --options 1 --wait 1     # option 1 = "How good is it?"
check_eq "converse_exit_0" "$?" "0"
check "greeting" "$(grep -aqi 'Oola Prenn' "$BOTLOG" && echo 1 || echo 0)"
check "explain_reached" "$(grep -aqi 'master chef' "$BOTLOG" && echo 1 || echo 0)"

bot_bg --wait 25
wait_online || die "$CHAR never came back online"
lab "cashSet:$CHAR:200000" >/dev/null
CASH0=$(lab_kv "cash:$CHAR" cash)
B=$(lab "buyFood:$CHAR:Blood_Chowder")
check_eq "dish_bought" "$(sed -n 's/.*result=\([a-z_]*\).*/\1/p' <<<"$B" | head -n1)" "ok" "$B"
USES=$(sed -n 's/.*[[:space:]]uses=\([-0-9]*\).*/\1/p' <<<"$B" | head -n1); WANT=$(sed -n 's/.*[[:space:]]wanted=\([-0-9]*\).*/\1/p' <<<"$B" | head -n1)
check_eq "dish_has_the_chefs_helpings" "${USES:-x}" "${WANT:-y}" "uses $USES, the catalogue says $WANT (the template's default is less)"
check_ge "dish_in_inventory" "$(lab "inventory:$CHAR" | grep -c 'food/crafted/dish_blood_chowder')" 1
C=$(lab "buyFood:$CHAR:4:1")   # the cantina shelf, first row (a crafted drink shares the Bantha Blaster name)
check_eq "cantina_drink_bought" "$(sed -n 's/.*result=\([a-z_]*\).*/\1/p' <<<"$C" | head -n1)" "ok" "$C"
check "cantina_drink_is_the_bartenders" "$(grep -q 'bartender_drinks/' <<<"$C" && echo 1 || echo 0)"
CASH1=$(lab_kv "cash:$CHAR" cash)
check_eq "prices_deducted" "$(( CASH0 - CASH1 ))" "$(( 500 + 150 ))" "cash $CASH0 -> $CASH1"
check_eq "unknown_food_refused" "$(lab_kv "buyFood:$CHAR:no_such_food_xyz" result)" "bad_item"
wait "$BOT_PID"
finish
