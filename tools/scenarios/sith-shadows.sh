#!/usr/bin/env bash
# 4b.1: the Sith Shadow camps. Four camps stand (two on Yavin 4, two on Dantooine) with their members alive; one
# member removed is replaced by the refill; the camp NPCs are the stock aggressive sith_shadow templates the
# Masters' kill tasks count.
# covers: fb_sith_shadows fb_masters
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

S=$(lab "shadowCamps" 20)
CAMPS=$(sed -n 's/.*shadowCamps camps=\([0-9]*\).*/\1/p' <<<"$S" | head -n1)
ALIVE=$(sed -n 's/.*shadowCamps camps=[0-9]* alive=\([0-9]*\).*/\1/p' <<<"$S" | head -n1)
check_eq "four_camps" "${CAMPS:-0}" "4" "$S"
check_ge "camps_manned" "${ALIVE:-0}" 18 "$ALIVE shadows alive of 20"
check "camp_near_light_enclave" "$(grep -q 'camp=yavin_light planet=yavin4 x=-5150 y=4900' <<<"$S" && echo 1 || echo 0)"
FIRST=$(lab "questStatus:FbSithShadows.camp.yavin_light" | sed -n 's/.*value=\([0-9]*\)=.*/\1/p' | head -n1)
check "first_member_recorded" "$( [ -n "$FIRST" ] && echo 1 || echo 0 )" "oid=$FIRST"
check "member_is_a_sith_shadow" "$(lab "oidInfo:$FIRST" | grep -q 'sith_shadow' && echo 1 || echo 0)"
lab "destroyObject:$FIRST" >/dev/null
check_ge "refill_replaces_the_dead" "$(lab_kv "shadowCampsRefill" replaced)" 1
ALIVE2=$(lab "shadowCamps" 20 | sed -n 's/.*shadowCamps camps=[0-9]* alive=\([0-9]*\).*/\1/p' | head -n1)
check_ge "camps_manned_again" "${ALIVE2:-0}" "${ALIVE:-0}"
finish
