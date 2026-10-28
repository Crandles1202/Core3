#!/usr/bin/env bash
# Phase 2.12: the Final Boss Lab Remote — the lab's find / goto / audit / actions as in-game windows on an
# admin's item. Runs the bot as claude-admin (privileged): the remote is handed out, its radial opens the
# console, "Where am I" reads out the position, "Find NPC" + "Teleport me to it" lands the bot inside the
# Trade Hall in front of Tamsin Rook, and a lab action (Trade Hall status) answers in a window.
# covers: fb_lab_remote
export SWG_BOT_USER=claude-admin
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

bot_bg --wait 45
wait_online || die "$CHAR (claude-admin) never came online — create one with: swg test bot --user claude-admin"
GIVE=$(lab "giveRemote:$CHAR")
REMOTE=$(sed -n 's/.*oid=\([0-9]*\).*/\1/p' <<<"$GIVE" | head -n1)
check "remote_handed_out_to_admin" "$( [ -n "$REMOTE" ] && [ "$REMOTE" != "0" ] && echo 1 || echo 0 )" "$GIVE"
check "admin_is_allowed" "$(grep -q 'allowed=true' <<<"$GIVE" && echo 1 || echo 0)" "$GIVE"
check_eq "hand_out_is_idempotent" "$(lab "giveRemote:$CHAR" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | head -n1)" "$REMOTE"
lab "travel:$CHAR:tatooine:3520:-4810" >/dev/null     # the starport square, outdoors
wait "$BOT_PID"

# --- the console: Where am I, then Find NPC -> Teleport me to it, then a lab action -----------------
bot --wait 3 \
	--radial "$REMOTE" 20 --sui "Where am I (world + room coordinates)" --sui-match "Lab Remote" --wait 1 --sui 0 --sui-match "Where am I" \
	--radial "$REMOTE" 20 --sui "Find NPC" --sui-match "Lab Remote" --sui "Tamsin" --sui-match "Find NPC" --sui 0 --sui-match "Find NPC: Tamsin" --sui "Teleport me to it" --sui-match "Tamsin" --wait 2 \
	--radial "$REMOTE" 20 --sui "Trade Hall status" --sui-match "Lab Remote" --sui 0 --sui-match "Trade Hall" \
	--radial "$REMOTE" 20 --sui "Site builder" --sui-match "Lab Remote" --sui 0 --sui-cancel --sui-match "Site builder" \
	--keep-going
check_eq "console_windows_answered" "$(bot_action_count sui failed)" "0" "$(bot_action_count sui ok) sui actions ok, $(bot_action_count sui failed) failed"
check "main_window_opened" "$(grep -aq "title='Final Boss Lab Remote'" "$BOTLOG" && echo 1 || echo 0)"
check "where_am_i_in_chat" "$(grep -aq '\[lab\] planet tatooine' "$BOTLOG" && echo 1 || echo 0)"
check "where_am_i_outdoors" "$(grep -aq '\[lab\] outdoors (cell 0)' "$BOTLOG" && echo 1 || echo 0)"
check "find_listed_tamsin" "$(grep -aq "title='Find NPC: Tamsin'" "$BOTLOG" && echo 1 || echo 0)"
check "trade_hall_window" "$(grep -aq "title='Trade Hall'" "$BOTLOG" && echo 1 || echo 0)"
check "site_builder_window" "$(grep -aq "title='Site builder'" "$BOTLOG" && echo 1 || echo 0)"
WHERE=$(lab "where:$CHAR")
check "teleported_into_the_hall" "$(grep -q 'cell=[1-9]' <<<"$WHERE" && echo 1 || echo 0)" "$WHERE"
DIST=$(lab "npc:fb_parts_dealer:$CHAR" | grep -a 'cell=' | sed -n 's/.*dist=\([0-9.]*\).*/\1/p' | sort -n | head -n1)
check "standing_in_front_of_tamsin" "$(awk "BEGIN{print (${DIST:-99} < 4) ? 1 : 0}")" "distance ${DIST:-?} m"
finish
