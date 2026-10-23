#!/usr/bin/env bash
# Phase 7.3 — the pilot loop without a model: a seat is up as the lab character, a /tell is sent to it,
# then tools/citizens/pilot.py runs one dry wake as "teyla": it must read the tell from the seat, answer
# with the persona's voice line through the seat, write a memory note, and seed the life plan from the
# persona file. No API key is used (--dry).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SEAT="$REPO/tools/seat"
PILOT="$REPO/tools/citizens/pilot.py"
NAME="labpilot-$$"
CITIZEN="teyla"
CDIR="$LABDIR/scenario/pilot-dry"   # never the real ~/.swg-lab/citizens/teyla: a gate once wiped her memory and plan
NONCE="pilotcheck$RANDOM"
[ -n "$CHAR" ] || die "no Lab* character on account $BOT_USER (run: swg test bot)"

cleanup() { "$SEAT" stop "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

rm -rf "$CDIR"   # a fresh citizen: the plan must be seeded from the persona
OUT=$("$SEAT" start "$BOT_USER" "$CHAR" --name "$NAME" --timeout 600 2>&1); RC=$?
check_eq "seat_started" "$RC" "0" "$(tail -n1 <<<"$OUT")"
[ "$RC" = 0 ] || die "seat did not start"

"$SEAT" tell "$NAME" "$CHAR" "Hello there $NONCE" >/dev/null 2>&1
sleep 1

PLOG=$(python3 "$PILOT" run "$CITIZEN" --seat "$NAME" --home "$CDIR" --dry --ticks 1 2>&1); RC=$?
check_eq "pilot_ran" "$RC" "0" "$(tail -n1 <<<"$PLOG")"
check "pilot_answered_tell" "$( grep -q '^\[teyla\] tell .*-> ok' <<<"$PLOG" && echo 1 || echo 0 )" "$(grep '^\[teyla\] tell' <<<"$PLOG" | head -n1 | cut -c1-120)"
sleep 1
TELLS=$("$SEAT" vars "$NAME" /Tells 2>&1)
check "answer_arrived" "$( grep -q "Vosk. If you" <<<"$TELLS" && echo 1 || echo 0 )" "the persona's voice line came back as a tell"
check "memory_written" "$( grep -q 'sent me a tell' "$CDIR/memory.md" 2>/dev/null && echo 1 || echo 0 )"
MILESTONES=$(grep -c '^- \[ \]' "$CDIR/plan.md" 2>/dev/null || echo 0)
check_ge "plan_seeded" "$MILESTONES" 4 "$MILESTONES milestones from the persona"
check "decisions_logged" "$( grep -q '"tool": "tell"' "$CDIR/log.jsonl" 2>/dev/null && echo 1 || echo 0 )"

"$SEAT" stop "$NAME" >/dev/null 2>&1
trap - EXIT
finish
