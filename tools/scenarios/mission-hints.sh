#!/usr/bin/env bash
# Phase 1.4: mission terminals show level and direction. The server appends "[Lvl N · 1.4km NE]"
# to each mission's creator name when it randomizes a terminal's list. The oracle spawns a general
# mission terminal next to the character, the bot requests its list, the oracle reads the bag.
# covers: MissionManager LuaMissionObject
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TERMINAL="object/tangible/terminal/terminal_mission.iff"
# outside Mos Eisley starport, same spot the other scenarios use
ZONE=tatooine; X=3520; Y=-4800

bot_bg --wait 25
wait_online || die "$CHAR never came online"

lab "travel:$CHAR:$ZONE:$X:$Y" >/dev/null
sleep 1
TOID=$(lab_kv "spawnObjectNear:$CHAR:$TERMINAL:2:0" oid)
check "terminal_spawned" "$( [ -n "$TOID" ] && echo 1 || echo 0 )" "oid=$TOID"
[ -n "$TOID" ] || { wait "$BOT_PID"; die "could not spawn a mission terminal"; }
sleep 2   # let the terminal reach the client before it is used
wait "$BOT_PID"

bot --wait 3 --missions "$TOID" --missions-settle 3000 --wait 1
RC=$?
check_eq "client_exit_0" "$RC" "0"
check_eq "list_request_sent" "$(bot_action_status missions)" "ok"
[ "$RC" = 0 ] || bot_errors

# --- observe: every randomized mission carries a hint ----------------------------------------
LINES=$(lab "missions:$CHAR" | grep '^INFO mission ')
TOTAL=$(printf '%s\n' "$LINES" | grep -c 'type=')
HINTED=$(printf '%s\n' "$LINES" | grep -c -E 'creator=.*\[Lvl [0-9]+')
DIRECTED=$(printf '%s\n' "$LINES" | grep -c -E '\[Lvl [0-9]+ - [0-9.]+(km|m) (N|NE|E|SE|S|SW|W|NW)\]')
printf '%s\n' "$LINES" | head -3 | sed 's/^/   /'
check_ge "missions_generated" "$TOTAL" 6 "$TOTAL missions in the bag"
check_eq "every_mission_has_level_hint" "$HINTED" "$TOTAL" "$HINTED of $TOTAL carry [Lvl N …]"
check_ge "most_missions_have_direction" "$DIRECTED" "$(( TOTAL / 2 ))" "$DIRECTED of $TOTAL carry distance+compass"

# --- clean up the test terminal ------------------------------------------------------------
lab "destroyObject:$TOID" >/dev/null

finish
