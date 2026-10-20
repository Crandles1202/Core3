#!/usr/bin/env bash
# Phase 2.12d: the site planner's game loop. A site file dropped into tasks/sites/.preview/ is spawned on
# the running server in place of the live site of the same name (FbSites:preview), its NPCs are audited
# by site (sitePlacement), and ending the preview puts the saved site back on its lot — no restart.
# Here: the Trade Hall itself, moved 60 m and turned, previewed and then restored.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SITES="$BIN/scripts/screenplays/tasks/sites"   # the server reads the bench, not an agent's worktree
mkdir -p "$SITES/.preview"
ORIG=$(lab "tradeHall")
OX=$(sed -n 's/.*[[:space:]]x=\([-0-9.]*\).*/\1/p' <<<"$ORIG" | head -n1)
check "hall_open_before" "$(grep -q 'open=1' <<<"$ORIG" && echo 1 || echo 0)" "$ORIG"

# the preview file: the saved hall, shifted north-east and turned (same rooms, same tenants)
sed -e 's/^\tx = \([-0-9.]*\), y = \([-0-9.]*\), heading = \([0-9]*\),/\tx = 3620.0, y = -4600.0, heading = 90,/' \
    "$SITES/mos_eisley_trade_hall.lua" > "$SITES/.preview/preview.lua"
check "preview_file_differs" "$(grep -q 'x = 3620.0' "$SITES/.preview/preview.lua" && echo 1 || echo 0)"

PV=$(lab "sitePreview:preview" 20)
check "preview_spawned" "$(grep -q '^INFO sitePreview' <<<"$PV" && echo 1 || echo 0)" "$PV"
check_eq "preview_at_the_new_spot" "$(sed -n 's/.*[[:space:]]x=\([-0-9.]*\).*/\1/p' <<<"$PV" | head -n1)" "3620.0" "$PV"
check_eq "preview_all_npcs" "$(sed -n 's/.*npcs=\([0-9]*\) of \([0-9]*\).*/\1/p' <<<"$PV")" "$(sed -n 's/.*npcs=\([0-9]*\) of \([0-9]*\).*/\2/p' <<<"$PV")" "$PV"
check "no_fail_line" "$(grep -q '^FAIL' <<<"$PV" && echo 0 || echo 1)" "$(grep '^FAIL' <<<"$PV" | head -n2)"
check_eq "live_hall_replaced" "$(lab "tradeHall" | sed -n 's/.*[[:space:]]x=\([-0-9.]*\).*/\1/p' | head -n1)" "3620.0" "the FbSites building of that name is now the preview"
check_eq "one_set_of_tenants" "$(lab "findNpc:fb_sites" | grep -ac 'cell=[1-9]')" "11" "the old tenants were torn down with the old building"

PL=$(lab "sitePlacement:mos_eisley_trade_hall" 20 | grep -a 'INFO placement summary')
check_eq "preview_audited" "$(sed -n 's/.*spawns=\([0-9]*\).*/\1/p' <<<"$PL")" "12" "$PL"
check_eq "preview_placement_clean" "$(sed -n 's/.*fail=\([0-9]*\).*/\1/p' <<<"$PL")" "0" "$PL"

# the teardown + rebuild can outlast the console capture window; lab() then asks again and gets the
# "nothing was previewed" answer of an already finished end — both mean it ran (the next checks prove it)
END=$(lab "sitePreviewEnd" 30)
check "preview_ended" "$(grep -q 'restored=true\|nothing was previewed' <<<"$END" && echo 1 || echo 0)" "$END"
AFTER=$(lab "tradeHall")
check_eq "saved_hall_is_back" "$(sed -n 's/.*[[:space:]]x=\([-0-9.]*\).*/\1/p' <<<"$AFTER" | head -n1)" "$OX" "$AFTER"
check_eq "tenants_back" "$(lab "findNpc:fb_sites" | grep -ac 'cell=[1-9]')" "11"
check "nothing_previewed_now" "$(lab "sitePreviewEnd" | grep -q 'nothing was previewed' && echo 1 || echo 0)"
rm -f "$SITES/.preview/preview.lua"
finish
