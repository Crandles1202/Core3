#!/usr/bin/env bash
# Phase 3.5: the story ticker. With the character online, fire the next story: its mobs appear
# (all alive), its news lines enter the galaxy chatter pool, and the broadcast reaches the client.
# Then fire another story: the previous story's mobs are gone and the new ones stand.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CUR=$(lab_kv "story" story)
check "ticker_has_current_story" "$( [ -n "$CUR" ] && [ "$CUR" != "0" ] && echo 1 || echo 0 )" "current=$CUR"
N=$(lab "story" | grep -c '^INFO story_def ')
NEXT=$(( CUR % N + 1 ))
AFTER=$(( NEXT % N + 1 ))
KEY_NEXT=$(lab "story" | grep "^INFO story_def idx=$NEXT " | sed -n 's/.*key=\([a-z_]*\).*/\1/p')
MOBS_NEXT=$(lab "story" | grep "^INFO story_def idx=$NEXT " | sed -n 's/.*mobs=\([0-9]*\).*/\1/p')

bot_bg --wait 25
wait_online || die "$CHAR never came online"
sleep 2
ST=$(lab "storyFire:$NEXT" | grep '^INFO story ' | head -1)
check "story_fired" "$(printf '%s' "$ST" | grep -q "key=$KEY_NEXT" && echo 1 || echo 0)" "$ST"
ALIVE=$(printf '%s\n' "$ST" | sed -n 's/.*alive=\([0-9]*\)\/\([0-9]*\).*/\1/p')
TOTAL=$(printf '%s\n' "$ST" | sed -n 's/.*alive=\([0-9]*\)\/\([0-9]*\).*/\2/p')
check_eq "story_mobs_spawned" "$TOTAL" "$MOBS_NEXT"
check_eq "story_mobs_alive" "$ALIVE" "$TOTAL"
WORD=${KEY_NEXT%%_*}   # tusken / pirates / bestine: every story's news lines name their subject
check "news_in_galaxy_pool" "$(lab "galaxyNews" | grep -qi "$WORD" && echo 1 || echo 0)" "a galaxy line mentions '$WORD'"
sleep 2
wait "$BOT_PID"
check "broadcast_reached_client" "$(grep -aqiE "militia|constab|Governor|CorSec|port authority|Nym's word|Outpost:" "$BOTLOG" && echo 1 || echo 0)"   # every story's broadcast opens with its sender (eleven stories since 3.13)

# --- the next story replaces this one -------------------------------------------------------------
OLD_OIDS=$(lab "questStatus:FbStoryTicker.spawns" | sed -n 's/.*value=\(.*\)$/\1/p' | grep -o '[0-9]\{6,\}' | tr '\n' ' ')
ST2=$(lab "storyFire:$AFTER" | grep '^INFO story ' | head -1)
check "second_story_fired" "$(printf '%s' "$ST2" | grep -q "story=$AFTER" && echo 1 || echo 0)" "$ST2"
sleep 1
DEAD=0; TOTAL_OLD=0
for oid in $OLD_OIDS; do
	TOTAL_OLD=$((TOTAL_OLD + 1))
	[ "$(lab_kv "objectAlive:$oid" alive)" = "0" ] && DEAD=$((DEAD + 1))
done
check_eq "previous_story_mobs_gone" "$DEAD" "$TOTAL_OLD" "$DEAD of $TOTAL_OLD despawned"
ALIVE2=$(printf '%s\n' "$ST2" | sed -n 's/.*alive=\([0-9]*\)\/\([0-9]*\).*/\1/p')
TOTAL2=$(printf '%s\n' "$ST2" | sed -n 's/.*alive=\([0-9]*\)\/\([0-9]*\).*/\2/p')
check_eq "second_story_mobs_alive" "$ALIVE2" "$TOTAL2"

finish
