#!/usr/bin/env bash
# Phase 7.5 — a seat clears its wounds: the lab wounds the character (wound:<char>:<pool>:<n>), the ham line reports the wounds,
# the clinic oracle lists the FB-21 medical droids nearest first (Mos Eisley's stands in a medcenter cell), and the pilot's
# clinic tool walks there through the door, takes "Clear my battle wounds and shock damage" over real packets, and reads the
# wounds back at 0. Teyla carried ~500 wounds in every pool for two days on production asking passers-by for a medic, because
# nothing told her that resting cannot close a wound (2026-10-28).
# covers: tools/citizens/pilot.py LuaCreatureObject clinic wound medical_droid
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SEAT="$REPO/tools/seat"
NAME="labclinic-$$"
[ -n "$CHAR" ] || die "no Lab* character on account $BOT_USER (run: swg test bot)"

clear_wounds() { for p in health action mind; do lab "wound:$CHAR:$p:0" >/dev/null 2>&1; done; }
cleanup() { clear_wounds; "$SEAT" stop "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

clinic_with_pilot() {   # my_health's JSON, then the clinic tool's JSON, one line each
    python3 - <<EOF
import sys, json
sys.path.insert(0, "$REPO/tools/citizens")
import pilot
seat_mod = pilot.load_seat_module()
seat = seat_mod.Seat("$NAME", timeout=600)
impl, schema = pilot.seat_tools(seat, None, "$CHAR", "$NAME")
print("HEALTH " + json.dumps(impl["my_health"]()))
print("RESULT " + json.dumps(impl["clinic"]()))
EOF
}

OUT=$("$SEAT" start "$BOT_USER" "$CHAR" --name "$NAME" --timeout 600 2>&1); RC=$?
check_eq "seat_started" "$RC" "0" "$(tail -n1 <<<"$OUT")"
[ "$RC" = 0 ] || { "$SEAT" log "$NAME" 30 | sed 's/^/   client: /'; die "seat did not start"; }
lab "travel:$CHAR:tatooine:3515:-4780" >/dev/null   # the Mos Eisley square
sleep 3
"$SEAT" cmd "$NAME" stand --nowait >/dev/null 2>&1 || true

# the wounds, and the ham line that shows them
lab "wound:$CHAR:health:300" >/dev/null; lab "wound:$CHAR:action:200" >/dev/null; lab "wound:$CHAR:mind:100" >/dev/null
HAM=$(lab "ham:$CHAR" 8 | grep -a '^INFO ham' | head -n1)
check "ham_shows_wounds" "$( grep -q ' wounds=300/200/100 ' <<<"$HAM" && echo 1 || echo 0 )" "$HAM"

# the oracle: the Mos Eisley droid first, inside its medcenter cell, within a walk
CL=$(lab "clinic:tatooine:3515:-4780" 30)
check "clinic_found" "$( grep -q 'INFO clinics planet=tatooine count=[1-9]' <<<"$CL" && echo 1 || echo 0 )" "$(grep -a '^INFO clinics' <<<"$CL")"
FIRST=$(grep -a '^INFO clinic ' <<<"$CL" | head -n1)
check "nearest_indoors" "$( grep -q ' cell=[1-9]' <<<"$FIRST" && echo 1 || echo 0 )" "$(grep -o 'name=[^ ]* .*distance=[0-9]*' <<<"$FIRST")"
DIST=$(sed -n 's/.*distance=\([0-9]*\).*/\1/p' <<<"$FIRST")
check "nearest_within_walk" "$( [ "${DIST:-9999}" -lt 600 ] && echo 1 || echo 0 )" "distance=$DIST"

# the tool: my_health names the wounds and points at the clinic, clinic clears them through the droid
R=$(clinic_with_pilot 2>&1)
H=$(grep -a '^HEALTH ' <<<"$R" | sed 's/^HEALTH //')
check "my_health_reports_wounds" "$( grep -q '"wounds": {"health": 300, "action": 200, "mind": 100}' <<<"$H" && echo 1 || echo 0 )" "$(cut -c1-200 <<<"$H")"
check "my_health_points_to_clinic" "$( grep -q 'tool clinic' <<<"$H" && echo 1 || echo 0 )"
J=$(grep -a '^RESULT ' <<<"$R" | sed 's/^RESULT //')
check "clinic_ok" "$( grep -q '"ok": true' <<<"$J" && echo 1 || echo 0 )" "$(cut -c1-220 <<<"$J")"
grep -q '"ok": true' <<<"$J" || sed 's/^/   pilot: /' <<<"$R" | tail -n 12
check "walked_indoors" "$( grep -q '"indoors": true' <<<"$J" && echo 1 || echo 0 )" "the walk went through the medcenter door"
HAM2=$(lab "ham:$CHAR" 8 | grep -a '^INFO ham' | head -n1)
check "wounds_cleared_on_server" "$( grep -q ' wounds=0/0/0 ' <<<"$HAM2" && echo 1 || echo 0 )" "$HAM2"

cleanup
trap - EXIT
finish
