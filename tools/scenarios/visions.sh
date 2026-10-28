#!/usr/bin/env bash
# Phase 4a.4: Force visions. The character is taken out of the world into the dungeon1 vision ground, two
# figures speak their lines, and the world comes back where it was left. Then the alignment skews the cast,
# a vision is due by the path's state and comes at the attunement trigger, and a seen vision does not return.
# covers: fb_visions fb_vision
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# --- A: a vision begun by the lab: away, figures, lines, back -------------------------------------------------
bot_bg --wait 110
wait_online || die "$CHAR never came online"
lab "attunementSit:$CHAR:stand" >/dev/null
sleep 4
lab "attunementReset:$CHAR" >/dev/null
lab "travel:$CHAR:tatooine:4100:-4700" >/dev/null        # open desert east of Mos Eisley, outdoors
sleep 4
HOME_LINE=$(lab "where:$CHAR" | sed 's/.*zone=/zone=/' | cut -c1-60)
V=$(lab "visionBegin:$CHAR:calling")
check "vision_began" "$(grep -q 'began=true' <<<"$V" && echo 1 || echo 0)" "$V"
sleep 8
W=$(lab "where:$CHAR")
check "character_in_the_vision_ground" "$(grep -q 'zone=dungeon1' <<<"$W" && echo 1 || echo 0)" "$W"
KENOBI=$(lab "findNpc:fb_vision_kenobi" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1)
VADER=$(lab "findNpc:fb_vision_vader" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1)
check "both_figures_stand" "$( [ -n "$KENOBI" ] && [ -n "$VADER" ] && echo 1 || echo 0 )" "kenobi=$KENOBI vader=$VADER"
check "figures_in_the_vision_zone" "$(lab "objectPos:$KENOBI" | grep -q 'zone=dungeon1' && echo 1 || echo 0)" "$(lab "objectPos:$KENOBI" | sed 's/.*zone=/zone=/' | cut -c1-80)"
check "vision_active" "$(lab "visions:$CHAR" | grep -q 'active=calling' && echo 1 || echo 0)" "$(lab "visions:$CHAR")"
# six lines six seconds apart, then the fade five seconds later: ~50 s from the first line
sleep 50
W=$(lab "where:$CHAR")
check "character_back_in_the_world" "$(grep -q 'zone=tatooine' <<<"$W" && echo 1 || echo 0)" "$W"
check "back_where_it_stood" "$(grep -q 'x=4100' <<<"$W" && grep -q 'y=-4700' <<<"$W" && echo 1 || echo 0)" "home: $HOME_LINE; now: $(sed 's/.*zone=/zone=/' <<<"$W" | cut -c1-60)"
check "vision_seen" "$(lab "visions:$CHAR" | grep -q 'seen=calling' && echo 1 || echo 0)" "$(lab "visions:$CHAR")"
check "figures_gone" "$(lab "objectAlive:$KENOBI" | grep -q 'alive=0' && lab "objectAlive:$VADER" | grep -q 'alive=0' && echo 1 || echo 0)" "$(lab "objectAlive:$KENOBI") $(lab "objectAlive:$VADER")"
wait "$BOT_PID"
check_ge "client_heard_kenobi" "$(grep -ac "SpatialChat from=$KENOBI" "$BOTLOG")" 3 "$(grep -a "SpatialChat from=$KENOBI" "$BOTLOG" | head -n1 | cut -c1-120)"
check_ge "client_heard_vader" "$(grep -ac "SpatialChat from=$VADER" "$BOTLOG")" 3 "$(grep -a "SpatialChat from=$VADER" "$BOTLOG" | head -n1 | cut -c1-120)"
check "client_got_enter_and_fade" "$(grep -aq 'fb_force:vision_enter' "$BOTLOG" && grep -aq 'fb_force:vision_fade' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'vision_enter\|vision_fade' "$BOTLOG" | cut -c1-80 | tr '\n' ' ')"

# --- B: due by state, at the trigger; seen once ---------------------------------------------------------------
sleep 8
bot_bg --wait 90
wait_online || die "$CHAR never came back online"
lab "clearWild:tatooine:4100:-4700:80" >/dev/null           # the trip home is a position update: the world may have rolled a lair onto the spot
lab "attunementAccept:$CHAR" >/dev/null                      # called → the 'calling' vision is due (the shortcut marks all seen)
lab "visionsReset:$CHAR" >/dev/null
sleep 2                                                      # a scyk's last swing: out of combat before the trigger
check_eq "calling_due" "$(lab_kv "visions:$CHAR" due)" "calling" "$(lab "visions:$CHAR")"
T=$(lab "trialTick:$CHAR")                                   # the attunement trigger
check "trigger_begins_the_vision" "$(grep -q 'sent=true' <<<"$T" && lab "visions:$CHAR" | grep -q 'active=calling' && echo 1 || echo 0)" "$T; $(lab "visions:$CHAR")"
sleep 6
check "second_trigger_waits" "$(lab "trialTick:$CHAR" | grep -q 'sent=false' && echo 1 || echo 0)"
lab "visionEnd:$CHAR" >/dev/null                             # wake now
sleep 3
check "woken_at_home" "$(lab "where:$CHAR" | grep -q 'zone=tatooine' && echo 1 || echo 0)" "$(lab "where:$CHAR" | sed 's/.*zone=/zone=/' | cut -c1-60)"
check_eq "nothing_due_after" "$(lab_kv "visions:$CHAR" due)" "-" "$(lab "visions:$CHAR")"

# --- C: the alignment skews the cast; the other side whispers ------------------------------------------------
lab "attunementFlag:$CHAR:alignment:light" >/dev/null
lab "visionBegin:$CHAR:padawan" >/dev/null
sleep 8
LUKE=$(lab "findNpc:fb_vision_luke" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1)
VADER2=$(lab "findNpc:fb_vision_vader" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | sort -n | tail -n1)
check "light_cast_is_kenobi_and_luke" "$( [ -n "$LUKE" ] && lab "objectAlive:${VADER2:-0}" | grep -q 'alive=0' && echo 1 || echo 0 )" "luke=$LUKE vader=$VADER2 $(lab "objectAlive:${VADER2:-0}")"
sleep 48
wait "$BOT_PID"
check "client_got_the_dark_whisper" "$(grep -aq 'fb_force:vision_padawan_vader_whisper' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'whisper' "$BOTLOG" | cut -c1-100 | tail -n1)"
check "padawan_seen" "$(lab "visions:$CHAR" | grep -q 'padawan' && echo 1 || echo 0)" "$(lab "visions:$CHAR")"
lab "attunementReset:$CHAR" >/dev/null
finish
