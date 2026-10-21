#!/usr/bin/env bash
# Phase 7.0 — the seat daemon: a core3client kept logged in, driven over its unix-socket channel
# by tools/seat. Checks the round trip, spatial chat, a /tell, an emote, the object list and a
# clean stop; the lab oracle confirms the character is online while the seat is up and gone after.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SEAT="$REPO/tools/seat"
NAME="lab-$$"
NONCE="seatcheck$RANDOM"
[ -n "$CHAR" ] || die "no Lab* character on account $BOT_USER (run: swg test bot)"

cleanup() { "$SEAT" stop "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# --- start ------------------------------------------------------------------------------------
OUT=$("$SEAT" start "$BOT_USER" "$CHAR" --name "$NAME" --timeout 600 2>&1); RC=$?
check_eq "seat_started" "$RC" "0" "$(tail -n1 <<<"$OUT")"
[ "$RC" = 0 ] || { "$SEAT" log "$NAME" 30 | sed 's/^/   client: /'; die "seat did not start"; }

PING=$("$SEAT" ping "$NAME" 2>&1)
CHAR_OID=$(sed -n 's/.*"character": \([0-9]*\).*/\1/p' <<<"$PING")
check "ping_ok" "$( grep -q '"ok": true' <<<"$PING" && echo 1 || echo 0 )" "character oid $CHAR_OID"
check "online_while_seated" "$( lab "isOnline:$CHAR" 5 | grep -aq '^INFO online' && echo 1 || echo 0 )"

# --- act: talk ---------------------------------------------------------------------------------
SAY=$("$SEAT" say "$NAME" "Seat check $NONCE" 2>&1)
check "say_accepted" "$( grep -q '"ok": true' <<<"$SAY" && echo 1 || echo 0 )" "$(grep -o '"error": "[^"]*"' <<<"$SAY" | head -n1)"
sleep 2
CHAT=$("$SEAT" vars "$NAME" /SpatialChat 2>&1)
check "say_echoed_back" "$( grep -q "$NONCE" <<<"$CHAT" && echo 1 || echo 0 )" "own spatial chat arrives from the server"

TELL=$("$SEAT" tell "$NAME" "$CHAR" "Tell check $NONCE" 2>&1)
check "tell_delivered" "$( grep -q '"ok": true' <<<"$TELL" && echo 1 || echo 0 )" "$(grep -o '"error": "[^"]*"' <<<"$TELL" | head -n1)"
sleep 1
TELLS=$("$SEAT" vars "$NAME" /Tells 2>&1)
check "tell_received" "$( grep -q "$NONCE" <<<"$TELLS" && echo 1 || echo 0 )" "a tell to ourselves lands in Tells"

EMOTE=$("$SEAT" emote "$NAME" wave 2>&1)
check "emote_accepted" "$( grep -q '"ok": true' <<<"$EMOTE" && echo 1 || echo 0 )" "$(grep -o '"error": "[^"]*"' <<<"$EMOTE" | head -n1)"

# --- perceive -----------------------------------------------------------------------------------
OBJS=$("$SEAT" objects "$NAME" 2>&1)
COUNT=$(sed -n 's/^\([0-9]*\) objects$/\1/p' <<<"$OBJS")
check_gt "objects_listed" "${COUNT:-0}" 0 "${COUNT:-0} objects in view"
check "self_in_objects" "$( grep -q "^ *$CHAR_OID " <<<"$OBJS" && echo 1 || echo 0 )" "own creature is in the list"

# others move around us (the helper droid that follows a new character, patrols, ambient life): the client
# keeps their positions current from UpdateTransformMessage, counted in Moves/count
"$SEAT" wait "$NAME" UpdateTransform 15000 >/dev/null 2>&1 || true
MOVES=$("$SEAT" vars "$NAME" /Moves 2>&1 | sed -n 's/.*"count": \([0-9]*\).*/\1/p' | head -n1)
check_ge "others_movement_decoded" "${MOVES:-0}" 1 "Moves/count=${MOVES:-0} within 15 s"

# a slash command through the channel (sit: the posture command, no queue ack)
CMD=$("$SEAT" cmd "$NAME" sitServer --nowait 2>&1)
check "command_via_channel" "$( grep -q '"ok": true' <<<"$CMD" && echo 1 || echo 0 )"

# --- stop ---------------------------------------------------------------------------------------
STOP=$("$SEAT" stop "$NAME" 2>&1)
check "seat_stopped" "$( grep -q "stopped" <<<"$STOP" && echo 1 || echo 0 )" "$(tail -n1 <<<"$STOP")"
LOG="$LABDIR/seats/$NAME/client.log"
check "seat_action_ok" "$( grep -aq '=> #[0-9]* {"action":"seat".*"status":"ok"' "$LOG" && echo 1 || echo 0 )"
check "logout_ok" "$( grep -aq '=> #[0-9]* {"action":"logoutCharacter".*"status":"ok"' "$LOG" && echo 1 || echo 0 )"
sleep 3
check "offline_after_stop" "$( lab "isOnline:$CHAR" 5 | grep -aq '^INFO online' && echo 0 || echo 1 )"
grep -a "ERROR" "$LOG" | grep -av 'decreaseOnlineCharCount' | sed 's/^/   client: /' | head -n 5

trap - EXIT
finish
