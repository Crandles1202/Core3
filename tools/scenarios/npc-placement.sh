#!/usr/bin/env bash
# Lab: NPC placement toolkit. Every Final Boss spawn is recorded with where it was put; the placement
# audit (line of sight to probes 3 m around, height above terrain, drift from the spawn spot) flags
# NPCs boxed into geometry, under the floor or wandered off; gotoNpc puts a character in conversation
# range of any NPC by name (the play-tester's way to eyeball a new NPC); waypointTo marks it.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# --- the audit on the live world --------------------------------------------------------------
SUMMARY=$(lab "placement" | grep -a 'INFO placement summary')
check "audit_ran" "$( [ -n "$SUMMARY" ] && echo 1 || echo 0 )" "$SUMMARY"
check_ge "audit_covers_the_npcs" "$(sed -n 's/.*spawns=\([0-9]*\).*/\1/p' <<<"$SUMMARY")" 40 "$SUMMARY"
check_eq "no_npc_boxed_in_or_underground" "$(sed -n 's/.*fail=\([0-9]*\).*/\1/p' <<<"$SUMMARY")" "0" "$SUMMARY"

# --- a deliberately bad spawn is caught: a droid 20 m under the Mos Eisley plaza ----------------
BAD=$(lab "spawnNpcAt:fb_holonet_relay:tatooine:3522:-4800:0:-15" | sed -n 's/.*INFO spawnNpcAt oid=\([0-9]*\).*/\1/p' | head -n1)   # this line only: the tail of the 380-spawn audit before it can bleed into this capture
check "bad_spawn_created" "$( [ -n "$BAD" ] && echo 1 || echo 0 )" "oid=$BAD"
check "bad_spawn_is_the_relay" "$(lab "oidInfo:$BAD" | grep -aq 'fb_holonet_relay' && echo 1 || echo 0)" "$(lab "oidInfo:$BAD" | grep -a '^INFO oid' | cut -c1-160)"   # never destroy a stranger
lab "oidInfo:$BAD" | grep -aq 'fb_holonet_relay' || die "the planted id resolves to another object; not touching it"
BADLINE=$(lab "placement:$BAD" | grep -a "oid=$BAD")
check "bad_spawn_flagged" "$(grep -aq 'verdict=fail' <<<"$BADLINE" && echo 1 || echo 0)" "$BADLINE"
check "bad_spawn_reason_is_terrain" "$(grep -aq 'off_the_terrain' <<<"$BADLINE" && echo 1 || echo 0)"
lab "destroyObject:$BAD" >/dev/null
check_eq "bad_spawn_removed" "$(lab "findNpc:$BAD" | grep -ac '^INFO npc')" "0"

# --- findNpc by name / template / source ---------------------------------------------------------
check_ge "find_by_name" "$(lab "findNpc:dannik" | grep -ac '^INFO npc')" 1
check_ge "find_by_template" "$(lab "findNpc:fb_holonet_relay" | grep -ac '^INFO npc')" 3 "three relays"
check_ge "find_by_source_file" "$(lab "findNpc:fb_ambient_life" | grep -ac '^INFO npc')" 3 "patrons spawned by fb_ambient_life.lua are recorded (stock templates)"

# --- gotoNpc lands the bot in conversation range; waypointTo marks the NPC ------------------------
bot_bg --wait 25
wait_online || die "$CHAR never came online"
GOTO=$(lab "gotoNpc:$CHAR:HN-7")
OID=$(sed -n 's/.*oid=\([0-9]*\).*/\1/p' <<<"$GOTO" | head -n1)
check "goto_found_the_relay" "$( [ -n "$OID" ] && echo 1 || echo 0 )" "$GOTO"
sleep 2
DIST=$(lab "npc:fb_holonet_relay:$CHAR" | grep -a "oid=$OID" | sed -n 's/.*dist=\([0-9.]*\).*/\1/p')
check "goto_within_conversation_range" "$(awk "BEGIN{print (${DIST:-99} < 4) ? 1 : 0}")" "distance ${DIST:-?} m"
check "waypoint_added" "$(lab "waypointTo:$CHAR:HN-7" | grep -aq 'waypoint=[1-9]' && echo 1 || echo 0)"
wait "$BOT_PID"
bot --wait 2 --converse "$OID" --options 0 --wait 2
check_eq "converse_after_goto" "$(bot_action_status converse)" "ok" "status: $(bot_action_status converse)"
finish
