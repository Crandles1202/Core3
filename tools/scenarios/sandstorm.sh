#!/usr/bin/env bash
# Phase 3.9: a Tatooine sandstorm as a world event. Force an extreme storm; the next tick spawns three
# Tusken raiding parties on Mos Eisley's outskirts, warns everyone and posts news; the client in the
# zone receives the storm in its weather packet and the warning. Clear the sky; the raiders withdraw.
# covers: fb_weather_events WeatherManager
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# start from a clear sky with no event running
lab "weatherSet:tatooine:0" >/dev/null
lab "stormTick" >/dev/null
ST0=$(lab "storm" | grep '^INFO storm ' | head -1)
check "starts_clear" "$(printf '%s' "$ST0" | grep -q 'weather=0 active=0' && echo 1 || echo 0)" "$ST0"

bot_bg --wait 45
wait_online || die "$CHAR never came online"
lab "travel:$CHAR:tatooine:3600:-4800" >/dev/null   # outdoors, east side of Mos Eisley
sleep 4

# --- the storm rolls in ------------------------------------------------------------------------------
check_eq "weather_forced_extreme" "$(lab_kv "weatherSet:tatooine:4" base)" "4"
DID=$(lab_kv "stormTick" did)   # "steady" when the screenplay's own minute tick got there first
check "tick_started_event" "$( [ "$DID" = "storm" ] || [ "$DID" = "steady" ] && echo 1 || echo 0 )" "did=$DID"
ST1=$(lab "storm" | grep '^INFO storm ' | head -1)
check "event_active" "$(printf '%s' "$ST1" | grep -q 'active=1' && echo 1 || echo 0)" "$ST1"
RAIDERS=$(printf '%s\n' "$ST1" | sed -n 's/.*raiders=\([0-9]*\)\/\([0-9]*\).*/\1\/\2/p')
check_eq "all_raiders_spawned" "${RAIDERS%/*}" "12" "raiders $RAIDERS"
check "news_posted" "$(lab "galaxyNews" | grep -q 'sandstorm hit Mos Eisley' && echo 1 || echo 0)"
sleep 8   # weather is re-sent to players every 3 s

# --- the sky clears ----------------------------------------------------------------------------------
check_eq "weather_forced_clear" "$(lab_kv "weatherSet:tatooine:0" base)" "0"
check_eq "tick_ended_event" "$(lab_kv "stormTick" did)" "clear"
ST2=$(lab "storm" | grep '^INFO storm ' | head -1)
check "event_over" "$(printf '%s' "$ST2" | grep -q 'active=0 raiders=0/0' && echo 1 || echo 0)" "$ST2"
sleep 6
wait "$BOT_PID"

check "client_saw_the_storm" "$(grep -aq 'Weather id=4' "$BOTLOG" && echo 1 || echo 0)"
# the base weather is clear again but a player's weather adds the local map's value, so "clear" = no longer extreme
check "client_saw_it_clear" "$(grep -a 'Weather id=' "$BOTLOG" | tail -n1 | grep -q 'Weather id=4' && echo 0 || echo 1)" "$(grep -a 'Weather id=' "$BOTLOG" | tail -n1 | cut -c1-60)"
check "client_got_the_warning" "$(grep -aq 'sandstorm is sweeping in' "$BOTLOG" && echo 1 || echo 0)"
check "client_got_the_all_clear" "$(grep -aq 'sandstorm has passed' "$BOTLOG" && echo 1 || echo 0)"
finish
