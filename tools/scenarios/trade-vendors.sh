#!/usr/bin/env bash
# Final Boss 2.13 / 2.14: the vehicle dealer and the raw resource dealer in the Trade Hall. The bot talks to each;
# the oracle buys a speederbike deed and a stack of the first family's best resource through the public purchase()
# (SUI cannot be driven by the bot) and checks the cash and the inventory.
# covers: fb_vehicle_dealer fb_resource_dealer mos_eisley_trade_hall givePlayerResourceNamed
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

npc_oid() { lab "npc:$1" | grep '^INFO npc ' | head -1 | sed -n 's/.*[[:space:]]oid=\([0-9]*\).*/\1/p'; }
VOID=$(npc_oid fb_vehicle_dealer); ROID=$(npc_oid fb_resource_dealer)
check "vehicle_dealer_spawned" "$( [ -n "$VOID" ] && echo 1 || echo 0 )" "oid=$VOID"
check "resource_dealer_spawned" "$( [ -n "$ROID" ] && echo 1 || echo 0 )" "oid=$ROID"
[ -n "$VOID" ] && [ -n "$ROID" ] || die "a dealer is missing"

CAT=$(lab "resourceDealer" 60)
FAMILIES=$(printf '%s\n' "$CAT" | sed -n 's/.*families=\([0-9]*\).*/\1/p' | head -n1)
FIRST=$(printf '%s\n' "$CAT" | grep '^INFO resourceFamily' | head -n1 | sed -n 's/.*name=\(.*\) spawns=.*/\1/p')
SPAWN=$(printf '%s\n' "$CAT" | grep '^INFO resourceFamily' | head -n1 | sed -n 's/.*first=\(.*\) class=.*/\1/p')
check_ge "catalogue_has_families" "${FAMILIES:-0}" 5 "$FAMILIES families, first '$FIRST' → $SPAWN"

bot_bg --wait 15
wait_online || die "$CHAR never came online"
lab "gotoNpc:$CHAR:$VOID" >/dev/null
wait "$BOT_PID"
bot --wait 2 --converse "$VOID" --options 1 --wait 1     # option 1 = "What should I ride?"
check_eq "vehicle_converse_exit_0" "$?" "0"
check "vehicle_greeting" "$(grep -aqi 'Rook Valdane' "$BOTLOG" && echo 1 || echo 0)"
check "vehicle_explain_reached" "$(grep -aqi 'family landspeeder' "$BOTLOG" && echo 1 || echo 0)"

bot_bg --wait 15
wait_online || die "$CHAR never came back online"
lab "gotoNpc:$CHAR:$ROID" >/dev/null
wait "$BOT_PID"
bot --wait 2 --converse "$ROID" --options 1 --wait 1     # option 1 = "How does this work?"
check_eq "resource_converse_exit_0" "$?" "0"
check "resource_greeting" "$(grep -aqi 'Mehra Tulk' "$BOTLOG" && echo 1 || echo 0)"
check "resource_explain_reached" "$(grep -aqi 'shifts of a few days' "$BOTLOG" && echo 1 || echo 0)"

bot_bg --wait 25
wait_online || die "$CHAR never came back online"
CASH0=$(lab_kv "cash:$CHAR" cash)
check_eq "speederbike_bought" "$(lab_kv "buyVehicle:$CHAR:Speederbike" result)" "ok"
check_ge "speederbike_deed_in_inventory" "$(lab "inventory:$CHAR" | grep -c 'vehicle_deed/speederbike_deed')" 1
check_eq "jetpack_refused_without_cash" "$(lab "cashSet:$CHAR:1000" >/dev/null; lab_kv "buyVehicle:$CHAR:Jetpack" result)" "no_credits"
lab "cashSet:$CHAR:$CASH0" >/dev/null
check_eq "resource_bought" "$(lab_kv "buyResource:$CHAR:$FIRST:5000" result)" "ok"
check_ge "resource_stack_in_inventory" "$(lab "inventory:$CHAR" | grep -c -F "$SPAWN")" 1 "stack of $SPAWN"
CASH1=$(lab_kv "cash:$CHAR" cash)
check_eq "prices_deducted" "$(( CASH0 - CASH1 ))" "$(( 6000 + 5000 ))" "cash $CASH0 -> $CASH1"
check_eq "unknown_resource_refused" "$(lab_kv "buyResource:$CHAR:no_such_spawn_xyz:1000" result)" "bad_item"
wait "$BOT_PID"
finish
