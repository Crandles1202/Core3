#!/usr/bin/env bash
# Phase 4c: the bounty. Visibility over the terminal threshold puts a price on a Jedi; the next trigger sends hunters
# scaled by level and rank, who attack on sight; all down → a cooldown; a deep alignment puts a Force user of the
# other side in the squad; the fixer in the Mos Eisley cantina takes the price plus a markup and the hunters stay
# away; /checkForceStatus carries the line.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

FIXER=$(lab "findNpc:fb_fixer" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1)
check "fixer_stands" "$( [ -n "$FIXER" ] && echo 1 || echo 0 )" "$(lab "findNpc:fb_fixer" | head -n1 | cut -c1-160)"

bot_bg --wait 70
wait_online || die "$CHAR never came online"
lab "attunementSit:$CHAR:stand" >/dev/null
sleep 3
lab "attunementReset:$CHAR" >/dev/null
lab "bountyClear:$CHAR" >/dev/null
lab "travel:$CHAR:tatooine:5264:113" >/dev/null        # a shrine: open, outdoors, no spawns of its own
sleep 3

# --- A: no price below the threshold; a price above it -----------------------------------------------------------
lab "skill:$CHAR:force_title_jedi_novice" >/dev/null
lab "bountySet:$CHAR:800" >/dev/null
check "quiet_below_threshold" "$(lab "bounty:$CHAR" | grep -q 'bounty=0 .*due=false(no bounty)' && echo 1 || echo 0)" "$(lab "bounty:$CHAR" | head -n1)"
B=$(lab "bountySet:$CHAR:2000" | head -n1)
check "price_placed" "$(grep -q 'bounty=20000 price=30000' <<<"$B" && grep -q 'due=true' <<<"$B" && echo 1 || echo 0)" "$B"
check_eq "fixer_offers" "$(lab "bounty:$CHAR" | sed -n 's/.*fixerScreen=\([a-z]*\).*/\1/p')" "offer"

# --- B: the hunt: one thug for a low-level novice, on the character, down → cooldown ------------------------------
T=$(lab "bountyTick:$CHAR")
check "hunt_sent" "$(grep -q 'hunt=true' <<<"$T" && grep -q 'hunters=1 ' <<<"$T" && echo 1 || echo 0)" "$T"
HUNTER=$(lab "findNpc:fb_bounty_thug" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1)
check "thug_for_a_low_level" "$( [ -n "$HUNTER" ] && echo 1 || echo 0 )" "$(lab "findNpc:fb_bounty_thug" | head -n1 | cut -c1-140)"
check "second_tick_waits" "$(lab "bountyTick:$CHAR" | grep -q 'hunt=false' && echo 1 || echo 0)"
sleep 6
check "hunter_closes_in" "$(lab "objectPos:$HUNTER" | grep -q 'combat=true' && echo 1 || lab "where:$CHAR" | grep -q 'combat=true' && echo 1 || echo 0)" "$(lab "objectPos:$HUNTER" | sed 's/.*zone=/zone=/' | cut -c1-90); $(lab "where:$CHAR" | sed 's/.*combat=/combat=/' | cut -c1-30)"
lab "killNpc:$CHAR:$HUNTER" >/dev/null
lab "revive:$CHAR" >/dev/null                          # a level-30 hunter can drop a lab character in seconds
sleep 3
B=$(lab "bounty:$CHAR" | head -n1)
check "cooldown_after_the_squad" "$(grep -q 'hunters=0' <<<"$B" && grep -q 'due=false(cooldown)' <<<"$B" && echo 1 || echo 0)" "$B"
wait "$BOT_PID"
check "client_got_placed_and_hunted" "$(grep -aq 'fb_force:bounty_placed' "$BOTLOG" && grep -aq 'fb_force:bounty_hunted' "$BOTLOG" && grep -aq 'fb_force:bounty_squad_down' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'bounty_' "$BOTLOG" | cut -c1-70 | tr '\n' ' ')"

# --- C: a deep-light Jedi's squad has a Dark Jedi in it (rank 2 here: one hunter, and that one is the Dark Jedi) -------
sleep 8
bot_bg --wait 40
wait_online || die "$CHAR never came back online"
lab "attunementFlag:$CHAR:alignment:light" >/dev/null
lab "alignmentSet:$CHAR:80" >/dev/null
lab "attunementFlag:$CHAR:nextHuntAt:0" >/dev/null
lab "jediMasterTake:$CHAR" >/dev/null
for t in stillness shadows rank1 rank2; do lab "trainingSet:$CHAR:$t:done" >/dev/null; done   # rank 2; the squad grows at rank 4
T=$(lab "bountyTick:$CHAR")
check "hunt_again" "$(grep -q 'hunt=true' <<<"$T" && echo 1 || echo 0)" "$T"
DARK=$(lab "findNpc:fb_bounty_dark_hunter" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1)
check "dark_jedi_in_the_squad" "$( [ -n "$DARK" ] && echo 1 || echo 0 )" "$(lab "findNpc:fb_bounty_dark_hunter" | head -n1 | cut -c1-140)"
[ -n "$DARK" ] && lab "killNpc:$CHAR:$DARK" >/dev/null
lab "revive:$CHAR" >/dev/null
sleep 3
check "squad_down_again" "$(lab "bounty:$CHAR" | grep -q 'hunters=0' && echo 1 || echo 0)" "$(lab "bounty:$CHAR" | head -n1)"
wait "$BOT_PID"

# --- D: the fixer: the price plus the markup, then nothing hunts ---------------------------------------------------
CASH0=$(lab_kv "cash:$CHAR" cash)
lab "cashSet:$CHAR:50000" >/dev/null
PRICE=$(lab "bounty:$CHAR" | sed -n 's/.*price=\([0-9]*\).*/\1/p' | head -n1)
sleep 8
bot_bg --wait 14 --converse "$FIXER" --options 0 --wait 3
wait_online || die "$CHAR never came back online"
lab "gotoNpc:$CHAR:fb_fixer" >/dev/null
wait "$BOT_PID"
check_eq "paid_in_conversation" "$(bot_action_status converse)" "ok" "$(grep -ao '=> #[0-9]* {"action":"converse"[^}]*}' "$BOTLOG" | tail -n1 | cut -c1-160)"
B=$(lab "bounty:$CHAR" | head -n1)
check "price_cleared_and_paused" "$(grep -q 'bounty=0 ' <<<"$B" && grep -q 'paid=true' <<<"$B" && grep -q 'due=false(no bounty)' <<<"$B" && echo 1 || echo 0)" "$B"
check_eq "charged_the_markup" "$(( 50000 - $(lab_kv "cash:$CHAR" cash) ))" "$PRICE" "price $PRICE; cash now $(lab_kv "cash:$CHAR" cash)"
check "client_got_the_receipt" "$(grep -aq 'fb_force:bounty_paid\|fixer_price' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'bounty_paid\|fixer_' "$BOTLOG" | cut -c1-80 | tail -n1)"
check_eq "fixer_knows_the_arrangement" "$(lab "bounty:$CHAR" | sed -n 's/.*fixerScreen=\([a-z]*\).*/\1/p')" "paid"
check_eq "status_says_paid" "$(lab "attunementStatus:$CHAR" >/dev/null; lab "bounty:$CHAR" | grep -c 'paid=true')" "1"
[ -n "${CASH0:-}" ] && lab "cashSet:$CHAR:$CASH0" >/dev/null
lab "bountyClear:$CHAR" >/dev/null
lab "attunementReset:$CHAR" >/dev/null
finish
