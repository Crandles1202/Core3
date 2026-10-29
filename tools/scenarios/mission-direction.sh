#!/usr/bin/env bash
# QoL: a mission terminal's "Missions by direction" radial pins the destroy and scout missions to a compass sector. The lab
# stores the choice the radial would (north), the bot lists a terminal, the oracle reads the bag: at least the six destroy
# missions point north of the character; with the choice cleared the list spreads again.
# covers: MissionManager MissionTerminal missionDir
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
TERMINAL="object/tangible/terminal/terminal_mission.iff"
ZONE=tatooine; X=3520; Y=-4800

bot_bg --wait 25
wait_online || die "$CHAR never came online"
lab "travel:$CHAR:$ZONE:$X:$Y" >/dev/null
sleep 1
TOID=$(lab_kv "spawnObjectNear:$CHAR:$TERMINAL:2:0" oid)
check "terminal_spawned" "$( [ -n "$TOID" ] && echo 1 || echo 0 )" "oid=$TOID"
[ -n "$TOID" ] || { wait "$BOT_PID"; die "could not spawn a mission terminal"; }
sleep 2
wait "$BOT_PID"

sector_count() {   # how many of the listed missions lie in the sector around bearing $1 (degrees, 0 = north) within ±40°
	lab "missions:$CHAR" | grep '^INFO mission ' | sed -n 's/.*start=\(-\?[0-9]*\),\(-\?[0-9]*\).*/\1 \2/p' | awk -v cx="$X" -v cy="$Y" -v want="$1" '
		{ dx = $1 - cx; dy = $2 - cy; if (dx*dx + dy*dy < 100*100) next; b = atan2(dx, dy) * 180 / 3.14159265; if (b < 0) b += 360;
		  d = b - want; if (d > 180) d -= 360; if (d < -180) d += 360; if (d < 0) d = -d; if (d <= 40) n++; t++ }
		END { print n+0 " " t+0 }'
}

check_eq "direction_set_north" "$(lab_kv "missionDir:$CHAR:N" dir)" "N"
bot --wait 3 --missions "$TOID" --missions-settle 3000 --wait 1
check_eq "list_request_sent" "$(bot_action_status missions)" "ok"
read -r IN TOTAL <<<"$(sector_count 0)"
check_ge "missions_listed" "$TOTAL" 6 "$TOTAL missions"
check_ge "six_point_north" "$IN" 6 "$IN of $TOTAL within 40° of north"

check_eq "direction_cleared" "$(lab_kv "missionDir:$CHAR:any" dir)" "any"
bot --wait 3 --missions "$TOID" --missions-settle 3000 --wait 1
read -r IN2 TOTAL2 <<<"$(sector_count 0)"
check "spread_again_when_cleared" "$( [ "${TOTAL2:-0}" -ge 6 ] && [ "${IN2:-0}" -lt "${TOTAL2:-0}" ] && echo 1 || echo 0 )" "$IN2 of $TOTAL2 north"
lab "destroyObject:$TOID" >/dev/null
finish
