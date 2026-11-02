#!/usr/bin/env bash
# QoL: crafting experience at its own rate (x5) while everything else keeps the global x3. The oracle awards 100 points of
# a crafting type and of a combat type through the player manager with the multipliers on and reads the deltas.
# covers: PlayerManager player_manager LuaCreatureObject crafting
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bot_bg --wait 25
wait_online || die "$CHAR never came online"
C=$(lab_kv "xpAward:$CHAR:crafting_general:100" delta)
check_eq "crafting_general_x5" "${C:-0}" "500" "100 asked"
W=$(lab_kv "xpAward:$CHAR:crafting_weapons_general:100" delta)
check_eq "crafting_weapons_x5" "${W:-0}" "500"
S=$(lab_kv "xpAward:$CHAR:shipwright:100" delta)
check_eq "shipwright_x5" "${S:-0}" "500"
G=$(lab_kv "xpAward:$CHAR:combat_general:100" delta)
check_eq "combat_keeps_the_global_x3" "${G:-0}" "300"
R=$(lab_kv "xpAward:$CHAR:crafting_general:100:raw" delta)
check_eq "raw_award_unchanged" "${R:-0}" "100" "the stock three-argument Lua award stays bare"
wait "$BOT_PID"
finish
