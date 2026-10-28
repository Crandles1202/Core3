#!/usr/bin/env bash
# Phase 3.6: galaxy chatter. Post a news line, stand in the Mos Eisley cantina and listen to beats
# until the patrons repeat galaxy news (a static line, the merchant's city, or the posted item), and
# check that the posted line is also delivered to the client as spatial chat.
# covers: fb_galaxy_chatter fb_ambient_life
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LOC=1
ANCHOR_PLANET=tatooine; ANCHOR_X=12.0; ANCHOR_Z=-0.9; ANCHOR_Y=1.5; ANCHOR_CELL=1082877
NEWS="Lab bulletin - the Final Boss test run is in progress."   # no ":" (runLuaFunction splits on it)

TOTAL0=$(lab_kv "galaxyNews" total)
check_gt "galaxy_pool_not_empty" "${TOTAL0:-0}" 8 "$TOTAL0 lines"
check "merchant_city_in_pool" "$(lab "galaxyNews" | grep -qi 'traveling merchant, Ozlo' && echo 1 || echo 0)"

lab "galaxyAddNews:labtest_bulletin:600:$NEWS" >/dev/null
check "posted_news_in_pool" "$(lab "galaxyNews" | grep -qF "$NEWS" && echo 1 || echo 0)"

bot_bg --wait 60
wait_online || die "$CHAR never came online"
lab "travelCell:$CHAR:$ANCHOR_PLANET:$ANCHOR_X:$ANCHOR_Z:$ANCHOR_Y:$ANCHOR_CELL" >/dev/null
sleep 2

GALAXY=""; HEARD_POSTED=0; TRIES=0
while [ "$TRIES" -lt 14 ]; do
	TRIES=$((TRIES + 1))
	R=$(lab "ambientTick:$LOC" | sed -n 's/^INFO ambientTick result=//p')
	case "$R" in
		galaxy:*) GALAXY="${R#galaxy:}"; [ "$GALAXY" = "$NEWS" ] && HEARD_POSTED=1 ;;
	esac
	[ -n "$GALAXY" ] && [ "$TRIES" -ge 6 ] && break
done
say "INFO after $TRIES beats, galaxy line: '$GALAXY' (posted item heard: $HEARD_POSTED)"
check "patrons_repeat_galaxy_news" "$( [ -n "$GALAXY" ] && echo 1 || echo 0 )"
wait "$BOT_PID"
if [ -n "$GALAXY" ]; then
	check "galaxy_line_reached_client" "$(grep -aqF "$GALAXY" "$BOTLOG" && echo 1 || echo 0)"
fi

# clean up the posted item so it does not linger in the live pool
lab "galaxyAddNews:labtest_bulletin:-1:$NEWS" >/dev/null
check "posted_news_expired" "$(lab "galaxyNews" | grep -qF "$NEWS" && echo 0 || echo 1)"

finish
