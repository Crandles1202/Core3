#!/usr/bin/env bash
# Phase 4a.1: Force attunement. The bot stands in a stock Force shrine region (places +3 on entry), meditates
# there (+6), "kills" a krayt dragon after an incapacitation (deeds +10 +5), the quest and learning sources are
# granted, the score crosses 25 and a robed spirit comes and speaks, then at 100 the Old Man comes, the bot
# accepts his task in conversation and /checkForceStatus reads the called tier.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# --- phase A: a lab-driven session at a shrine: entry pays 3, the kill pays and triggers the first visit ------
bot_bg --wait 150
wait_online || die "$CHAR never came online"
# a clean slate: standing (a seated character logging in at a shrine is credited at once, by design), and
# the login path's deferred shrine check must have passed before the reset
lab "attunementSit:$CHAR:stand" >/dev/null
sleep 8
lab "attunementReset:$CHAR" >/dev/null
check_eq "starts_at_zero" "$(lab_kv "attunement:$CHAR" total)" "0"
lab "travel:$CHAR:tatooine:5264:113" >/dev/null
sleep 4
A=$(lab "attunement:$CHAR")
check "shrine_entry_credited" "$(grep -q 'places=3/3' <<<"$A" && echo 1 || echo 0)" "$A"
check "meditation_watch_running" "$(lab "attunementMeditate:$CHAR" | grep -q 'watch=tatooine_force_shrine_02' && echo 1 || echo 0)"
lab "attunementGrant:$CHAR:quests:hero_of_tatooine:15" >/dev/null
lab "attunementGrant:$CHAR:quests:jabba:10" >/dev/null
lab "attunementGrant:$CHAR:quests:nym:10" >/dev/null
A=$(lab "attunementGrant:$CHAR:quests:imperial:10")
check "quests_capped_at_40" "$(grep -q 'quests=40/45' <<<"$A" && echo 1 || echo 0)" "$A"
check "no_visit_below_25_was_sent" "$(grep -q 'ghost25=false' <<<"$A" && echo 1 || echo 0)" "$A"
lab "attunementIncap:$CHAR" >/dev/null
A=$(lab "attunementKill:$CHAR:canyon_krayt_dragon")
check "named_kill_and_incap_win" "$(grep -q 'deeds=15/15' <<<"$A" && echo 1 || echo 0)" "$A"
A=$(lab "attunementKill:$CHAR:canyon_krayt_dragon")
check "same_kill_kind_once" "$(grep -q 'deeds=15/15' <<<"$A" && echo 1 || echo 0)" "$A"
check_eq "total_is_the_capped_sum" "$(lab_kv "attunement:$CHAR" total)" "58" "places 3 + deeds 15 + quests 40"
# the kill is a trigger: 20 s later the first due visitor (25) comes, walks up and speaks three lines
sleep 32
GHOST=$(lab "findNpc:fb_force_ghost" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1)
check "ghost_came_after_the_fight" "$( [ -n "$GHOST" ] && echo 1 || echo 0 )"
check "ghost25_flag_set" "$(lab "attunement:$CHAR" | grep -q 'ghost25=true' && echo 1 || echo 0)"
check "no_second_visit_while_one_is_live" "$(lab "attunementVisit:$CHAR" | grep -q 'sent=false' && echo 1 || echo 0)"
sleep 85
check "ghost_faded" "$(lab "objectAlive:$GHOST" | grep -q 'alive=0' && echo 1 || echo 0)" "$(lab "objectAlive:$GHOST")"
wait "$BOT_PID"
# the bot client logs string-table chat without its text: count the lines the spirit sent
check_ge "ghost_spoke_three_lines" "$(grep -ac "SpatialChat from=$GHOST" "$BOTLOG")" 3 "$(grep -a 'SpatialChat' "$BOTLOG" | tail -n3 | tr '\n' ' ')"
check "ghost_fade_message" "$(grep -aq 'ghost_fades\|robed figure is gone' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'fb_force' "$BOTLOG" | tail -n2 | tr '\n' ' ')"

# --- phase B: sitting down in the shrine pays the meditation (/meditate itself is a Teras Kasi ability, so
# sitting still counts: two polls 5 s apart). A fresh session logs in where it logged out, the login path
# starts the watch 6 s in; the client sits (sitServer is the posture command, sent without an ack). The
# credit lifts the score past 50 and a shrine is a trigger, so the second spirit comes in the same session.
sleep 8
bot_bg --wait 2 --command sitServer --command-nowait --wait 75
wait_online || die "$CHAR never came back online"
sleep 8
check "login_starts_the_watch" "$(lab "attunementMeditate:$CHAR" | grep -q 'watch=tatooine_force_shrine_02\|posture=8' && echo 1 || echo 0)" "$(lab "attunementMeditate:$CHAR")"
sleep 14
A=$(lab "attunement:$CHAR")
check "meditation_credited" "$(grep -q 'places=9/9' <<<"$A" && echo 1 || echo 0)" "$A"
check "world_noted" "$(grep -q 'medWorlds=tatooine' <<<"$A" && echo 1 || echo 0)" "$A"
check "ghost50_sent_by_the_shrine" "$(grep -q 'ghost50=true' <<<"$A" && echo 1 || echo 0)" "$A"
sleep 25
GHOST=$(lab "findNpc:fb_force_ghost" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1)
check "ghost50_stands_near" "$( [ -n "$GHOST" ] && echo 1 || echo 0 )"
wait "$BOT_PID"
check_ge "ghost50_spoke" "$(grep -ac "SpatialChat from=$GHOST" "$BOTLOG")" 1 "$(grep -a 'SpatialChat' "$BOTLOG" | tail -n3 | tr '\n' ' ')"

# --- phase D: the Old Man at 100, spawned in one session, spoken to in the next ------------------------------
sleep 8
bot_bg --wait 45
wait_online || die "$CHAR never came back online"
lab "attunementSet:$CHAR:100" >/dev/null
V=$(lab "attunementVisit:$CHAR")
check "old_man_sent" "$(grep -q 'sent=true' <<<"$V" && echo 1 || echo 0)" "$V"
sleep 25
OLD=$(lab "findNpc:fb_old_man" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1)
check "old_man_stands_near" "$( [ -n "$OLD" ] && echo 1 || echo 0 )"
wait "$BOT_PID"
check_ge "old_man_greeted" "$(grep -ac "SpatialChat from=$OLD" "$BOTLOG")" 1 "$(grep -a 'SpatialChat' "$BOTLOG" | tail -n2 | tr '\n' ' ')"
bot --wait 4 --converse "$OLD" --options 1,0 --wait 2 --command checkForceStatus --wait 3 >/dev/null 2>&1 || true
check_eq "old_man_converse_ok" "$(bot_action_status converse)" "ok" "$(grep -ao '=> #[0-9]* {"action":"converse"[^}]*}' "$BOTLOG" | tail -n1 | cut -c1-160); old man: $(lab "objectPos:$OLD" | sed 's/.*zone=/zone=/' | cut -c1-70); char: $(lab "where:$CHAR" | sed 's/.*zone=/zone=/' | cut -c1-70)"
A=$(lab "attunement:$CHAR")
check "task_accepted" "$(grep -q 'called=true task=shrines' <<<"$A" && echo 1 || echo 0)" "$A"
check_eq "called_tier" "$(lab_kv "attunementStatus:$CHAR" tier)" "@fb_force:tier_4"
check "client_got_the_tier" "$(grep -aq 'fb_force:tier_4\|You have been called' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'tier_\|called' "$BOTLOG" | tail -n2 | tr '\n' ' ')"
sleep 35
check "old_man_left" "$(lab "objectAlive:$OLD" | grep -q 'alive=0' && echo 1 || echo 0)" "$(lab "objectAlive:$OLD")"
lab "attunementSit:$CHAR:stand" >/dev/null
lab "attunementReset:$CHAR" >/dev/null
finish
