#!/usr/bin/env bash
# Walk up to a Final Boss NPC and talk to it through the real conversation packets.
# Usage: npc-conversation.sh [creatureTemplate] [optionIndexes]   (default: FB-72 at Mos Eisley starport, option 0)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TEMPLATE=${1:-fb_armory_droid}
PICKS=${2:-0}

# --- stage: find an outdoor spawn of the NPC on tatooine and stand next to it ------------------
bot_bg --wait 30
wait_online || die "$CHAR never came online"

NPC_LINE=$(lab "npc:$TEMPLATE:$CHAR" | grep -a "zone=tatooine" | grep -a "cell=0" | head -n1)
NPC_OID=$(sed -n 's/.*oid=\([0-9]*\).*/\1/p' <<<"$NPC_LINE")
NPC_X=$(sed -n 's/.*x=\(-\{0,1\}[0-9.]*\).*/\1/p' <<<"$NPC_LINE")
NPC_Y=$(sed -n 's/.*y=\(-\{0,1\}[0-9.]*\).*/\1/p' <<<"$NPC_LINE")
check "npc_spawned_outdoors_on_tatooine" "$( [ -n "$NPC_OID" ] && echo 1 || echo 0 )" "$TEMPLATE oid=$NPC_OID at $NPC_X,$NPC_Y"
[ -n "$NPC_OID" ] || die "no outdoor tatooine spawn of $TEMPLATE recorded"

lab "travel:$CHAR:tatooine:$(awk "BEGIN{print $NPC_X+1.5}"):$(awk "BEGIN{print $NPC_Y+1.5}")" >/dev/null
sleep 2
DIST=$(lab "npc:$TEMPLATE:$CHAR" | grep -a "oid=$NPC_OID" | sed -n 's/.*dist=\([0-9.]*\).*/\1/p')
check "within_conversation_range" "$(awk "BEGIN{print (${DIST:-99} < 6) ? 1 : 0}")" "distance ${DIST:-?} m"
wait "$BOT_PID"

# --- act: converse ----------------------------------------------------------------------------
bot --wait 2 --converse "$NPC_OID" --options "$PICKS" --wait 1
RC=$?
check_eq "client_exit_0" "$RC" "0"
check_eq "conversation_ok" "$(bot_action_status converse)" "ok" "status: $(bot_action_status converse)"
[ "$RC" = 0 ] || bot_errors

SCREENS=$(grep -ac "\[Converse\] screen " "$BOTLOG")
OPTIONS=$(grep -ac "\[Converse\]    \[" "$BOTLOG")
# Picking an option either shows the next screen or ends the conversation (FB-72's "buy" option
# closes it and opens an SUI window instead) — both are fine; what matters is the greeting + options.
check_ge "greeting_screen_seen" "$SCREENS" 1 "$SCREENS screen(s)"
check_ge "options_offered" "$OPTIONS" 1 "$OPTIONS option(s) on the first screen"
grep -a "\[Converse\]" "$BOTLOG" | sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' -e 's/^.*\[Converse\] /INFO transcript: /' | cut -c1-200

finish
