#!/usr/bin/env bash
# Phase 2.12f: the terrain relief in the site planner comes from FbLabTests:terrainGrid, which writes a height
# grid of a box to a file in one console call. A 40 m box every 10 m is 5×5 heights, the header describes it,
# and the heights are plausible ground (Mos Eisley starport square sits near 5 m).
# covers: terrainGrid siteplanner
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

OUT=/tmp/fb-terrain-grid-test.txt
rm -f "$OUT"
TG=$(lab "terrainGrid:tatooine:3500:-4830:3540:-4790:10:$OUT" 30)
check "oracle_ran" "$(grep -q '^INFO terrainGrid' <<<"$TG" && echo 1 || echo 0)" "$TG"
check_eq "grid_is_5x5" "$(sed -n 's/.*cols=\([0-9]*\) rows=\([0-9]*\).*/\1x\2/p' <<<"$TG")" "5x5" "$TG"
check "file_written" "$( [ -s "$OUT" ] && echo 1 || echo 0 )" "$OUT"
check_eq "header_matches" "$(head -n1 "$OUT" | awk '{print $1, $6, $7, $8}')" "tatooine 10 5 5" "$(head -n1 "$OUT")"
check_eq "five_rows_of_five" "$(tail -n +2 "$OUT" | awk 'NF==5' | wc -l)" "5"
MIN=$(sed -n 's/.*min=\([-0-9.]*\).*/\1/p' <<<"$TG"); MAX=$(sed -n 's/.*max=\([-0-9.]*\).*/\1/p' <<<"$TG")
check "heights_are_ground" "$(awk -v a="$MIN" -v b="$MAX" 'BEGIN{print (a > -50 && b < 300 && b >= a) ? 1 : 0}')" "min $MIN max $MAX"
rm -f "$OUT"
finish
