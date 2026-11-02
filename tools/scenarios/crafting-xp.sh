#!/usr/bin/env bash
# QoL: crafting experience at its own rate (x5) while everything else keeps the global x3. The oracle awards 100 points of
# crafting types and of a combat type through the player manager with the multipliers on and compares the deltas: the
# species modifier scales both alike (a Lab character read 524 and 314), so the test is the ratio, 5/3.
# covers: PlayerManager player_manager LuaCreatureObject crafting
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bot_bg --wait 25
wait_online || die "$CHAR never came online"
lab "xp:$CHAR:crafting_general" >/dev/null   # a warm-up call: the first lab line after a login has been swallowed before
award() { local out; out=$(lab "xpAward:$CHAR:$1" 20); printf '   %s\n' "$(grep -a 'INFO xpAward' <<<"$out" | head -n1 | cut -c1-150)" >&2; sed -n 's/.*[[:space:]]delta=\(-\?[0-9]*\).*/\1/p' <<<"$out" | head -n1; }
# crafting_general caps at 1000 on a reused character; the weapons and shipwright types have room
W=$(award "crafting_weapons_general:100"); S=$(award "shipwright:100"); G=$(award "combat_general:100"); R=$(award "crafting_weapons_general:100:raw")
ratio() { python3 -c "import sys; a=float('${1:-0}'); b=float('${2:-0}'); print(round(a/b,3) if b else 0)"; }
check "crafting_weapons_vs_combat_5_to_3" "$(python3 -c "r=$(ratio "$W" "$G"); import sys; sys.exit(0 if 1.6 <= r <= 1.74 else 1)" && echo 1 || echo 0)" "weapons $W, combat $G"
check "shipwright_vs_combat_5_to_3" "$(python3 -c "r=$(ratio "$S" "$G"); import sys; sys.exit(0 if 1.6 <= r <= 1.74 else 1)" && echo 1 || echo 0)" "shipwright $S, combat $G"
check "combat_keeps_the_global_x3" "$(python3 -c "import sys; g=float('${G:-0}'); sys.exit(0 if 300 <= g <= 330 else 1)" && echo 1 || echo 0)" "combat $G (300 plus the species modifier at most)"
check_eq "raw_award_unchanged" "${R:-0}" "100" "the stock three-argument Lua award stays bare"
wait "$BOT_PID"
finish
