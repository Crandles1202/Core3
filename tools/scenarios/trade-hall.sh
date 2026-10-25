#!/usr/bin/env bash
# Phase 2.11: the Mos Eisley Trade Hall — a server-placed stock building with the FB vendors inside.
# The hall stands with nine cells, every tenant is in its room and placed sanely, the doorman on the
# square marks the hall on the map, and the bot walks in (gotoNpc), talks to a tenant and buys. The bot
# logs out inside the hall, so the next restart + bot login exercises "my cell no longer exists".
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ST=$(lab "tradeHall")
check "hall_open" "$(grep -q 'open=1' <<<"$ST" && echo 1 || echo 0)" "$ST"
check_eq "hall_has_nine_cells" "$(sed -n 's/.*cells=\([0-9]*\).*/\1/p' <<<"$ST")" "9" "$ST"
check_eq "tenants_recorded" "$(lab "findNpc:fb_sites" | grep -ac 'cell=[1-9]')" "11" "11 tenants spawned into cells by the site loader (fb_sites)"
check_eq "keeper_on_the_square" "$(lab "findNpc:Hallkeeper" | grep -ac 'cell=0')" "1"
PL=$(lab "placement:fb_sites" | grep -a 'INFO placement summary')
check_eq "placement_clean" "$(sed -n 's/.*fail=\([0-9]*\).*/\1/p' <<<"$PL")" "0" "$PL"
check "lot_is_flat" "$(lab "tradeHall" | grep -q 'lot_ok=1' && echo 1 || echo 0)" "$ST"
# the furniture is client-only (interior layout file): the server cannot see a tenant standing in a table,
# so the survey tool checks every tenant spot in the screenplay against it
FURN=$("$REPO/tools/lotsurvey" check object/building/tatooine/shared_guild_commerce_tatooine_style_01.iff --lua "$REPO/MMOCoreORB/bin/scripts/screenplays/tasks/sites/mos_eisley_trade_hall.lua" 2>&1)
check_eq "no_tenant_in_the_furniture" "$(sed -n 's/.*summary spots=\([0-9]*\) fail=\([0-9]*\).*/\2/p' <<<"$FURN")" "0" "$(grep -a '^FAIL\|^summary' <<<"$FURN" | tr '\n' ' ')"
check_ge "furniture_check_covered_tenants" "$(sed -n 's/.*summary spots=\([0-9]*\).*/\1/p' <<<"$FURN")" 11

# --- the doorman marks the hall ---------------------------------------------------------------
bot_bg --wait 25
wait_online || die "$CHAR never came online"
KEEPER=$(lab "gotoNpc:$CHAR:Hallkeeper" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | head -n1)
check "goto_keeper" "$( [ -n "$KEEPER" ] && echo 1 || echo 0 )"
wait "$BOT_PID"
lab "questStatus:FbTradeHall.lastWaypoint:none" >/dev/null
bot --wait 10 --converse "$KEEPER" --options 0 --wait 3    # ten seconds in: a converse two seconds after zone-in failed three gates running on 2026-10-24
check_eq "keeper_converse_ok" "$(bot_action_status converse)" "ok" "status: $(bot_action_status converse)"
check "keeper_mentions_the_hall" "$(grep -aq 'Trade Hall' "$BOTLOG" && echo 1 || echo 0)"
check_eq "waypoint_given" "$(lab_kv "questStatus:FbTradeHall.lastWaypoint" value)" "$CHAR"

# --- inside: talk to a tenant and buy -----------------------------------------------------------
bot_bg --wait 25
wait_online || die "$CHAR never came back online"
TAMSIN=$(lab "gotoNpc:$CHAR:Tamsin" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | head -n1)
check "goto_tenant_inside" "$(lab "where:$CHAR" | grep -q 'cell=[1-9]' && echo 1 || echo 0)" "$(lab "where:$CHAR")"
CASH0=$(lab_kv "cash:$CHAR" cash)
check "buy_inside_the_hall" "$(lab "buyPart:$CHAR:1:1" | grep -aq '^INFO' && echo 1 || echo 0)"   # while the bot is still online
CASH1=$(lab_kv "cash:$CHAR" cash)
check "paid_for_it" "$( [ "${CASH1:-0}" -lt "${CASH0:-0}" ] && echo 1 || echo 0 )" "cash $CASH0 -> $CASH1"
wait "$BOT_PID"
bot --wait 10 --converse "$TAMSIN" --options 0 --wait 3    # the bot's last act: it logs out inside the hall
check_eq "tenant_converse_ok" "$(bot_action_status converse)" "ok" "status: $(bot_action_status converse)"
finish
