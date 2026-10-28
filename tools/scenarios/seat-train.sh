#!/usr/bin/env bash
# Phase 7.5 — a seat trains: the lab character holds the Scout novice box and enough scout and trapping experience, the
# pilot's train tool asks the lab what is trainable (trainable:<char>), finds the nearest scout trainer by mobile
# template (trainers:tatooine:trainer_scout), walks to it, and talks through the stock trainer conversation
# (learn → the box → yes) over real packets; the oracle reads the box back. Twice: first from the Mos Eisley square,
# where the scout trainer stands outdoors, then from beside the trainers' hall, where the nearest one stands in a cell
# (the walk and the conversation then go through a door). The shared lab character is reset before and after.
# covers: src/client tools/seat train trainable
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SEAT="$REPO/tools/seat"
NAME="labtrain-$$"
NOVICE=outdoors_scout_novice
SKILL1=outdoors_scout_movement_01   # scout experience, 1000 credits
SKILL2=outdoors_scout_tools_01      # trapping experience, 1000 credits
[ -n "$CHAR" ] || die "no Lab* character on account $BOT_USER (run: swg test bot)"

reset_skills() { lab "skillDrop:$CHAR:$SKILL1" >/dev/null 2>&1; lab "skillDrop:$CHAR:$SKILL2" >/dev/null 2>&1; }
cleanup() { reset_skills; "$SEAT" stop "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

train_with_pilot() {   # <skill> → the train tool's JSON result on one line
    python3 - "$1" <<EOF
import sys, json
sys.path.insert(0, "$REPO/tools/citizens")
import pilot
seat_mod = pilot.load_seat_module()
seat = seat_mod.Seat("$NAME", timeout=600)
impl, schema = pilot.seat_tools(seat, None, "$CHAR", "$NAME")
print("RESULT " + json.dumps(impl["train"](sys.argv[1])))
EOF
}

OUT=$("$SEAT" start "$BOT_USER" "$CHAR" --name "$NAME" --timeout 600 2>&1); RC=$?
check_eq "seat_started" "$RC" "0" "$(tail -n1 <<<"$OUT")"
[ "$RC" = 0 ] || { "$SEAT" log "$NAME" 30 | sed 's/^/   client: /'; die "seat did not start"; }
reset_skills
lab "skill:$CHAR:$NOVICE" >/dev/null
lab "xpSet:$CHAR:scout:5000" >/dev/null
lab "xpSet:$CHAR:trapping:5000" >/dev/null
lab "cashSet:$CHAR:20000" >/dev/null
lab "heal:$CHAR:health:2000" >/dev/null; lab "heal:$CHAR:action:2000" >/dev/null; lab "heal:$CHAR:mind:2000" >/dev/null

# the oracle: both boxes ready, the next rifle box (if the character has the Marksman line from seat-fight) listed as next
TR=$(lab "trainable:$CHAR" 20)
check "box_trainable" "$( grep -q "^INFO trainable skill=$SKILL1 trainer=trainer_scout xpType=scout" <<<"$TR" && echo 1 || echo 0 )" "$(grep -a "skill=$SKILL1" <<<"$TR" | head -n1 | cut -c1-140)"
SUMMARY=$(grep -a '^INFO training' <<<"$TR" | head -n1)
LEVEL0=$(sed -n 's/.*level=\([0-9]*\).*/\1/p' <<<"$SUMMARY")
check "training_summary" "$( grep -q 'trainable=[1-9]' <<<"$SUMMARY" && echo 1 || echo 0 )" "$SUMMARY"
# the trainer finder: scout trainers on Tatooine near the Mos Eisley square, the outdoor one first
FOUND=$(lab "trainers:tatooine:trainer_scout:3515:-4780" 60)
check "trainers_found" "$( grep -q 'INFO trainers planet=tatooine type=trainer_scout count=[1-9]' <<<"$FOUND" && echo 1 || echo 0 )" "$(grep -a '^INFO trainers' <<<"$FOUND")"
check "nearest_outdoors" "$( grep -a '^INFO trainer ' <<<"$FOUND" | head -n1 | grep -q ' cell=0 ' && echo 1 || echo 0 )" "$(grep -a '^INFO trainer ' <<<"$FOUND" | head -n1 | grep -o 'name=[^ ]* .*distance=[0-9]*')"

# 1. outdoors: from the square, the scout trainer by the cantina
lab "travel:$CHAR:tatooine:3515:-4780" >/dev/null
sleep 3
"$SEAT" cmd "$NAME" stand --nowait >/dev/null 2>&1 || true
R1=$(train_with_pilot "$SKILL1" 2>&1)
J1=$(grep -a '^RESULT ' <<<"$R1" | sed 's/^RESULT //')
check "train_outdoors_ok" "$( grep -q '"ok": true' <<<"$J1" && echo 1 || echo 0 )" "$(cut -c1-220 <<<"$J1")"
grep -q '"ok": true' <<<"$J1" || sed 's/^/   pilot: /' <<<"$R1" | tail -n 12
HAS1=$(lab "hasSkill:$CHAR:$SKILL1" 8 | grep -o 'has=[a-z]*' | head -n1)
check_eq "box_on_server" "$HAS1" "has=true" "$SKILL1"
check "paid_credits" "$( grep -q '"paid": 1000' <<<"$J1" && echo 1 || echo 0 )" "the trainer's price"
check "trainer_was_outdoors" "$( grep -q '"indoors": false' <<<"$J1" && echo 1 || echo 0 )"

# 2. indoors: beside the trainers' hall north of the shuttleport, whose scout trainer stands in a cell
lab "travel:$CHAR:tatooine:3468:-4700" >/dev/null
sleep 3
R2=$(train_with_pilot "$SKILL2" 2>&1)
J2=$(grep -a '^RESULT ' <<<"$R2" | sed 's/^RESULT //')
check "train_indoors_ok" "$( grep -q '"ok": true' <<<"$J2" && echo 1 || echo 0 )" "$(cut -c1-220 <<<"$J2")"
grep -q '"ok": true' <<<"$J2" || sed 's/^/   pilot: /' <<<"$R2" | tail -n 12
HAS2=$(lab "hasSkill:$CHAR:$SKILL2" 8 | grep -o 'has=[a-z]*' | head -n1)
check_eq "second_box_on_server" "$HAS2" "has=true" "$SKILL2"
check "trainer_was_indoors" "$( grep -q '"indoors": true' <<<"$J2" && echo 1 || echo 0 )" "the walk went through a door into a cell"

# the stored level is recomputed on every award (calculatePlayerLevel): never lower than before
AFTER=$(lab "trainable:$CHAR" 20 | grep -a '^INFO training' | head -n1)
LEVEL1=$(sed -n 's/.*level=\([0-9]*\).*/\1/p' <<<"$AFTER")
check_ge "level_recomputed" "${LEVEL1:-0}" "${LEVEL0:-0}" "level $LEVEL0 → $LEVEL1 ($AFTER)"
# the box is no longer offered, the next one in its line is
check "box_gone_from_ready" "$( lab "trainable:$CHAR" 20 | grep -q "^INFO trainable skill=$SKILL1 " && echo 0 || echo 1 )"

cleanup
trap - EXIT
finish
