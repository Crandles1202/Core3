#!/usr/bin/env bash
# Phase 3.10: HoloNet relays. The starport relay is up; a forced broadcast reads a full segment
# (sting, top story, wanted, news, commerce, propaganda, outro) and the lines reach the client as
# spatial chat from the relay. Also exercises the relay's "replay" conversation option.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LOC=1
ST=$(lab "holonet" | grep "^INFO holonet loc=$LOC " | head -1)
OID=$(printf '%s\n' "$ST" | sed -n 's/.*relay=\([0-9]*\).*/\1/p')
PLANET=$(printf '%s\n' "$ST" | sed -n 's/.*planet=\([a-z0-9_]*\).*/\1/p')
RX=$(printf '%s\n' "$ST" | sed -n 's/.*[[:space:]]x=\([-0-9.]*\).*/\1/p' | cut -d. -f1)
RY=$(printf '%s\n' "$ST" | sed -n 's/.*[[:space:]]y=\([-0-9.]*\).*/\1/p' | cut -d. -f1)
check "starport_relay_up" "$( [ -n "$OID" ] && [ "$OID" != "0" ] && echo 1 || echo 0 )" "$ST"
[ -n "$OID" ] && [ "$OID" != "0" ] || die "no relay"

N=$(lab_kv "holonetSegment" "")
LINES=$(lab "holonetSegment" | grep -c '^INFO holonet_line ')
check_ge "segment_has_lines" "$LINES" 5 "$LINES lines"
check "segment_has_top_story" "$(lab "holonetSegment" | grep -q 'Top story:' && echo 1 || echo 0)"

# --- listen at the relay --------------------------------------------------------------------------
bot_bg --wait 40
wait_online || die "$CHAR never came online"
lab "travel:$CHAR:$PLANET:$((RX + 3)):$RY" >/dev/null
sleep 2
READ=$(lab_kv "holonetBroadcast:$LOC" lines)
check_ge "broadcast_started" "${READ:-0}" 5 "$READ lines queued"
sleep $(( 3 * READ + 3 ))
wait "$BOT_PID"
HEARD=$(grep -ac "SpatialChat from=$OID" "$BOTLOG")
check_ge "client_heard_the_segment" "$HEARD" "$READ" "$HEARD of $READ lines from relay $OID"
check "client_heard_top_story" "$(grep -aq 'Top story:' "$BOTLOG" && echo 1 || echo 0)"

# --- replay on demand through the conversation ---------------------------------------------------
bot --wait 2 --converse "$OID" --options 0 --wait 3
check_eq "replay_converse_exit_0" "$?" "0"
check "replay_acknowledged" "$(grep -aq 'Replaying. Stand by.' "$BOTLOG" && echo 1 || echo 0)"

finish
