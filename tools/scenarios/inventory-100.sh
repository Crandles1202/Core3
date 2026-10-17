#!/usr/bin/env bash
# Phase 1.5: a character's inventory accepts 100 items. New inventories get it from the template
# (fb_inventory_100.lua); older ones are raised on login (fb_player_login.lua). The reused Lab*
# character usually predates the change, so a run here exercises the login path too.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

EXPECT=100

# simulate a character created before the change (persisted limit 80), then log in
BEFORE=$(lab_kv "setInventoryLimit:$CHAR:80" limit)
check_eq "limit_forced_to_80_before_login" "${BEFORE:-0}" "80" "limit=$BEFORE"

bot_bg --wait 12
wait_online || die "$CHAR never came online"
LIMIT=$(lab_kv "inventoryLimit:$CHAR" limit)
COUNT=$(lab_kv "inventoryLimit:$CHAR" count)
say "INFO $CHAR inventory: $COUNT items, limit $LIMIT"
check_eq "inventory_limit_after_login" "${LIMIT:-0}" "$EXPECT" "limit=$LIMIT (expected $EXPECT)"
wait "$BOT_PID"
check_eq "client_exit_0" "$?" "0"

# the oracle's static view of the override file
check_eq "template_override_says_100" "$(lab_kv "inventoryTemplateLimit" limit)" "$EXPECT"

finish
