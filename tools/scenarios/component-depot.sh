#!/usr/bin/env bash
# Final Boss 2.15: the component depot sells every crafting component. The bot talks to BX-4; the oracle reads the
# generated catalogue, buys a rolled part (real stats through createLoot) and a raw one (the bare template) and checks
# the cash and the inventory.
# covers: fb_component_depot components_gen mos_eisley_trade_hall
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

OID=$(lab "npc:fb_component_depot" | grep '^INFO npc ' | head -1 | sed -n 's/.*[[:space:]]oid=\([0-9]*\).*/\1/p')
check "depot_spawned" "$( [ -n "$OID" ] && echo 1 || echo 0 )" "oid=$OID"
[ -n "$OID" ] || die "no depot keeper"
CAT=$(lab "componentDepot" 30)
ROWS=$(sed -n 's/.*INFO componentDepot categories=[0-9]* rows=\([0-9]*\).*/\1/p' <<<"$CAT" | head -n1)
ROLLED=$(sed -n 's/.*rolled=\([0-9]*\) raw=.*/\1/p' <<<"$CAT" | head -n1)
check_ge "catalogue_rows" "${ROWS:-0}" 400 "$ROWS rows, $ROLLED rolled"
check_ge "catalogue_rolled_parts" "${ROLLED:-0}" 120

bot_bg --wait 15
wait_online || die "$CHAR never came online"
lab "gotoNpc:$CHAR:$OID" >/dev/null
wait "$BOT_PID"
bot --wait 2 --converse "$OID" --options 1 --wait 1     # option 1 = rolled vs raw
check_eq "converse_exit_0" "$?" "0"
check "greeting" "$(grep -aqi 'component depot' "$BOTLOG" && echo 1 || echo 0)"
check "explain_reached" "$(grep -aqi 'bare component' "$BOTLOG" && echo 1 || echo 0)"

bot_bg --wait 25
wait_online || die "$CHAR never came back online"
lab "cashSet:$CHAR:200000" >/dev/null
CASH0=$(lab_kv "cash:$CHAR" cash)
R=$(lab "buyComponent:$CHAR:Blaster Power Handler")
check_eq "rolled_part_bought" "$(sed -n 's/.*result=\([a-z_]*\).*/\1/p' <<<"$R" | head -n1)" "ok" "$R"
check_eq "rolled_part_is_rolled" "$(sed -n 's/.*kind=\([a-z]*\).*/\1/p' <<<"$R" | head -n1)" "rolled"
check_ge "rolled_part_in_inventory" "$(lab "inventory:$CHAR" | grep -c 'component/weapon/blaster_power_handler')" 1
R=$(lab "buyComponent:$CHAR:Droid parts (raw):1")
[ -n "$R" ] || true
RAWKEY=$(lab "componentDepot" 30 | grep '^INFO depotCategory name=Droid_parts_(raw)' | sed -n 's/.*first=\([^ ]*\).*/\1/p' | tr '_' ' ')
R=$(lab "buyComponent:$CHAR:$RAWKEY")
check_eq "raw_part_bought" "$(sed -n 's/.*result=\([a-z_]*\).*/\1/p' <<<"$R" | head -n1)" "ok" "$R"
check_eq "raw_part_is_raw" "$(sed -n 's/.*kind=\([a-z]*\).*/\1/p' <<<"$R" | head -n1)" "raw"
check_ge "raw_part_in_inventory" "$(lab "inventory:$CHAR" | grep -c 'component/droid/')" 1
CASH1=$(lab_kv "cash:$CHAR" cash)
check_eq "prices_deducted" "$(( CASH0 - CASH1 ))" "$(( 2000 + 500 ))" "cash $CASH0 -> $CASH1"
check_eq "unknown_part_refused" "$(lab_kv "buyComponent:$CHAR:no_such_part_xyz" result)" "bad_item"
wait "$BOT_PID"
finish
