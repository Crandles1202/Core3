#!/usr/bin/env bash
# Phase 3.4: the territory map drives the world. Hand Mos Eisley to the Rebellion: the Imperial patrol
# respawns a man short and the Rebel patrol a man stronger, the Mos Eisley HoloNet relay reads Rebel
# propaganda and the sector report, the cantina chatter pool mentions it. A threshold crossing posts
# news and reaches the client as a broadcast. Hand it back and everything flips.
# covers: fb_territory fb_faction_patrols fb_holonet
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

bot_bg --wait 50
wait_online || die "$CHAR never came online"

# --- Rebel Mos Eisley ---------------------------------------------------------------------------------
lab "territorySet:mos_eisley:45" >/dev/null                      # contested, so the next shift crosses into Rebel
check_eq "crossed_into_rebel" "$(lab_kv "territoryShift:mos_eisley:-15" faction)" "rebel"
check "news_posted" "$(lab "galaxyNews" | grep -q 'Rebellion holds Mos Eisley' && echo 1 || echo 0)"
lab "patrolRespawn:1" >/dev/null 2>&1
lab "patrolRespawn:2" >/dev/null 2>&1
ST=$(lab "patrols")
IMPM=$(printf '%s\n' "$ST" | grep '^INFO patrol route=1 ' | sed -n 's/.*members=\([0-9]*\)\/\([0-9]*\).*/\2/p')
REBM=$(printf '%s\n' "$ST" | grep '^INFO patrol route=2 ' | sed -n 's/.*members=\([0-9]*\)\/\([0-9]*\).*/\2/p')
check_eq "imperial_patrol_thinned" "$IMPM" "1" "imperial members $IMPM"
check_eq "rebel_patrol_reinforced" "$REBM" "3" "rebel members $REBM"
SEG=$(lab "holonetSegment")
check "holonet_sector_report" "$(printf '%s' "$SEG" | grep -q 'Sector report: Mos Eisley Rebel-held' && echo 1 || echo 0)"
check "holonet_rebel_voice" "$(printf '%s' "$SEG" | grep -q 'Alliance\|answers to you now' && echo 1 || echo 0)"
check "chatter_knows" "$(lab "galaxyNews" | grep -q 'Rebels run Mos Eisley' && echo 1 || echo 0)"

# --- back to the Empire ----------------------------------------------------------------------------
check_eq "crossed_into_imperial" "$(lab_kv "territoryShift:mos_eisley:40" faction)" "imperial"
lab "patrolRespawn:1" >/dev/null 2>&1
lab "patrolRespawn:2" >/dev/null 2>&1
ST=$(lab "patrols")
IMPM=$(printf '%s\n' "$ST" | grep '^INFO patrol route=1 ' | sed -n 's/.*members=\([0-9]*\)\/\([0-9]*\).*/\2/p')
REBM=$(printf '%s\n' "$ST" | grep '^INFO patrol route=2 ' | sed -n 's/.*members=\([0-9]*\)\/\([0-9]*\).*/\2/p')
check_eq "imperial_patrol_reinforced" "$IMPM" "3" "imperial members $IMPM"
check_eq "rebel_patrol_thinned" "$REBM" "1" "rebel members $REBM"
check "holonet_imperial_voice" "$(lab "holonetSegment" | grep -q 'Sector report: Mos Eisley Imperial-held' && echo 1 || echo 0)"
lab "territorySet:mos_eisley:65" >/dev/null                      # leave the default behind
wait "$BOT_PID"
check "client_heard_the_change" "$(grep -aq 'Rebellion holds Mos Eisley' "$BOTLOG" && echo 1 || echo 0)"
check "client_heard_it_flip_back" "$(grep -aq 'firmly in Imperial hands' "$BOTLOG" && echo 1 || echo 0)"
finish
