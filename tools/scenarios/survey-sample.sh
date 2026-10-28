#!/usr/bin/env bash
# Phase 7.6a — survey and sample on a seat: the resource oracle names the richest mineral spawn on Tatooine and
# its best spot; the lab gives the character the survey skill and a mineral survey tool and puts it there; the
# seat uses the tool (answering the range window), surveys the resource, and samples it into its inventory.
# covers: SurveyAction src/client
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SEAT="$REPO/tools/seat"
NAME="labsurvey-$$"
[ -n "$CHAR" ] || die "no Lab* character on account $BOT_USER (run: swg test bot)"

cleanup() { "$SEAT" stop "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# --- the target: the mineral spawn (survey tool type 6) with the richest listed spot ------------------
PICK=$(lab "resources:tatooine" 40 | grep -a '^INFO resource ' | grep -a ' tool=6 ' | awk -F'best=' '{split($2,a,";"); split(a[1],b,","); print b[3], $0}' | sort -rn | head -n1)
RNAME=$(sed -n 's/.*name=\([^ ]*\).*/\1/p' <<<"$PICK")
SPOT=$(sed -n 's/.*best=\([^;]*\).*/\1/p' <<<"$PICK")
SX=$(cut -d, -f1 <<<"$SPOT"); SY=$(cut -d, -f2 <<<"$SPOT"); SD=$(cut -d, -f3 <<<"$SPOT")
check "mineral_spawn_chosen" "$( [ -n "$RNAME" ] && echo 1 || echo 0 )" "$RNAME at $SX,$SY density ${SD:-?}"
[ -n "$RNAME" ] || die "no mineral spawn in shift on tatooine"

# --- seat up, skill, tool, position ---------------------------------------------------------------
OUT=$("$SEAT" start "$BOT_USER" "$CHAR" --name "$NAME" --timeout 900 2>&1); RC=$?
check_eq "seat_started" "$RC" "0" "$(tail -n1 <<<"$OUT")"
[ "$RC" = 0 ] || die "seat did not start"

lab "skill:$CHAR:crafting_artisan_survey_04" >/dev/null
SURVEYING=$(lab_kv "skillmod:$CHAR:surveying" surveying)
check_ge "surveying_skill" "${SURVEYING:-0}" 60 "surveying=${SURVEYING:-?}"
TOOL=$(lab "give:$CHAR:object/tangible/survey_tool/survey_tool_mineral.iff" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | head -n1)
check "tool_given" "$( [ -n "$TOOL" ] && echo 1 || echo 0 )" "survey tool oid $TOOL"
lab "travel:$CHAR:tatooine:$SX:$SY" >/dev/null
sleep 3
"$SEAT" cmd "$NAME" stand --nowait >/dev/null 2>&1 || true

# --- survey ------------------------------------------------------------------------------------------
SURVEY=$("$SEAT" survey "$NAME" "$TOOL" "$RNAME" 2>&1); RC=$?
check_eq "survey_ok" "$RC" "0" "$(grep -o '"error": "[^"]*"' <<<"$SURVEY" | head -n1)"
PCT=$(sed -n 's/.*"bestPct": \([0-9.]*\).*/\1/p' <<<"$SURVEY" | head -n1)
check "survey_sees_the_resource" "$(awk -v p="${PCT:-0}" 'BEGIN{print (p > 0.10) ? 1 : 0}')" "best grid point $(awk -v p="${PCT:-0}" 'BEGIN{printf "%.0f", p*100}')% (oracle said $(awk -v d="${SD:-0}" 'BEGIN{printf "%.0f", d*100}')%)"

# --- sample ------------------------------------------------------------------------------------------
SAMPLE=$("$SEAT" sample "$NAME" "$RNAME" 1 2>&1); RC=$?
check_eq "sample_ok" "$RC" "0" "$(grep -o '"error": "[^"]*"' <<<"$SAMPLE" | head -n1)"
LOCATED=$(sed -n 's/.*"located": \([0-9]*\).*/\1/p' <<<"$SAMPLE" | head -n1)
check_ge "sample_yielded" "${LOCATED:-0}" 1 "located=${LOCATED:-0} $(grep -o '"trace": [0-9]*\|"failed": [0-9]*\|"belowThreshold": [0-9]*' <<<"$SAMPLE" | tr '\n' ' ')"
ITEM=$(lab "findItem:$CHAR:resource_container" | grep -a '^INFO item' | head -n1)
check "resource_container_in_inventory" "$( [ -n "$ITEM" ] && echo 1 || echo 0 )" "$(sed 's/INFO item //' <<<"$ITEM")"

"$SEAT" stop "$NAME" >/dev/null 2>&1
trap - EXIT
finish
