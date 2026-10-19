#!/usr/bin/env bash
# Phase 2.12g: world edits. The snapshot writer re-serialises every planet byte-identically (so a patched
# snapshot differs from stock only where an edit says), and every edit in tre-src/world/ is what the booted
# server shows (checkWorldEdits does the same inside `swg test lua`; here the oracle's lines are inspected).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

RT=$("$REPO/tools/worldedit" check 2>&1)
check_eq "snapshot_writer_roundtrips" "$(grep -c 'roundtrip ok' <<<"$RT")" "10" "$(grep -v 'roundtrip ok' <<<"$RT" | head -n3 | tr '\n' ' ')"
check "lua_twin_in_sync" "$("$REPO/tools/worldedit" lua | grep -q 'unchanged' && echo 1 || echo 0)" "tre-src/world/*.json and custom_scripts/fb_world_edits.lua agree"

WE=$(lab "worldEdits" 20)
N=$(grep -ac '^INFO worldedit planet=' <<<"$WE")
check_eq "every_edit_is_in_the_world" "$(grep -ac 'ok=true' <<<"$WE")" "$N" "$(grep -a 'ok=false' <<<"$WE" | head -n3 | tr '\n' ' ')"
check "oracle_answered" "$(grep -aq '^INFO worldedit' <<<"$WE" && echo 1 || echo 0)" "$WE"
finish
