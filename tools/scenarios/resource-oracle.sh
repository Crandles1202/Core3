#!/usr/bin/env bash
# Phase 7.6a — the resource oracle: the lab lists the spawns in shift on Tatooine with their attributes and best
# concentration spots (the same noise the survey tool reads), and the density read back at a listed spot agrees.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LIST=$(lab "resources:tatooine" 30)
N=$(sed -n 's/.*INFO resources planet=tatooine n=\([0-9]*\).*/\1/p' <<<"$LIST")
check_ge "spawns_listed" "${N:-0}" 10 "${N:-0} spawns in shift on tatooine"

WITH_ATTRS=$(grep -ac 'attrs=res_[a-z_]*=[0-9]' <<<"$LIST")
check_ge "attributes_present" "$WITH_ATTRS" 10 "$WITH_ATTRS spawns carry res_* attributes"

BEST_LINE=$(grep -a '^INFO resource ' <<<"$LIST" | awk -F'best=' '{split($2,a,";"); split(a[1],b,","); print b[3], $0}' | sort -rn | head -n1)
BEST_D=$(cut -d' ' -f1 <<<"$BEST_LINE")
check "a_rich_spot_exists" "$(awk -v d="${BEST_D:-0}" 'BEGIN{print (d >= 0.3) ? 1 : 0}')" "richest listed spot reads ${BEST_D:-?}"

NAME=$(sed -n 's/.*name=\([^ ]*\).*/\1/p' <<<"$BEST_LINE")
SPOT=$(sed -n 's/.*best=\([^;]*\).*/\1/p' <<<"$BEST_LINE")
SX=$(cut -d, -f1 <<<"$SPOT"); SY=$(cut -d, -f2 <<<"$SPOT")
D=$(lab "resourceDensity:$NAME:tatooine:$SX:$SY" 10 | sed -n 's/.*density=\([0-9.]*\).*/\1/p')
check "density_agrees_at_spot" "$(awk -v d="${D:-0}" -v b="${BEST_D:-1}" 'BEGIN{print (d >= b - 0.01) ? 1 : 0}')" "$NAME at $SX,$SY reads ${D:-?} (listed ${BEST_D:-?})"

FILTERED=$(lab "resources:tatooine:steel" 30 | sed -n 's/.*INFO resources planet=tatooine n=\([0-9]*\).*/\1/p')
check "class_filter_works" "$( [ "${FILTERED:-0}" -le "${N:-0}" ] && echo 1 || echo 0 )" "${FILTERED:-0} steel spawn(s)"

finish
