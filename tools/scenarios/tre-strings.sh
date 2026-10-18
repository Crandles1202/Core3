#!/usr/bin/env bash
# Phase 4.0: custom strings shipped in finalboss.tre (tre-src/, tools/tre). The server resolves the
# lab's @fb_lab:* ids from its string cache (re-read on a reloadstrings start, which swg start adds when
# the archive changed), unknown ids stay empty, stock tables are untouched, and a system message built
# from one of our ids reaches the client with the id intact (the real client renders it from its own
# copy of the archive; Chuck's play-test item).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

check "server_resolves_probe_first" "$(lab "stringId:fb_lab:probe_first" | grep -qF 'text=Final Boss TRE probe: first' && echo 1 || echo 0)"
check "server_resolves_probe_last" "$(lab "stringId:fb_lab:probe_last" | grep -qF 'text=Final Boss TRE probe: last' && echo 1 || echo 0)"
check "server_keeps_line_break_and_token" "$(lab "stringId:fb_lab:probe_middle" | grep -qF 'with a\nline break and a %TT token' && echo 1 || echo 0)"
check_eq "unknown_id_is_empty" "$(lab_kv "stringId:fb_lab:no_such_key" text)" ""
check "stock_table_intact" "$(lab "stringId:jedi_spam:fs_progress_1" | grep -q 'text=.' && echo 1 || echo 0)"
check_eq "archive_installed_matches_build" "$("$SWG" tre status --json | tail -1 | python3 -c 'import json,sys; d=json.load(sys.stdin); print(1 if d["built"] and d["built"]==d["server"] else 0)')" "1"

# the client-side cfg patch (install --client), on a scratch copy of a CRLF cfg: one line added, one
# bumped, nothing else touched, CRLF kept, second run a no-op
CFG="$LABDIR/scenario-$SCENARIO.live.cfg"; rm -f "$CFG" "$CFG.finalboss.bak"
printf '[SharedFile]\r\n\tmaxSearchPriority=3\r\n\tsearchTree_00_2=patch.tre\r\n\tsearchTree_00_1=base.tre\r\n' > "$CFG"
check "client_cfg_patched" "$("$SWG" tre patchcfg "$CFG" | grep -q 'maxSearchPriority 3 -> 4, searchTree_00_3=finalboss.tre' && echo 1 || echo 0)"
check_eq "client_cfg_result" "$(tr -d '\r' < "$CFG" | tr '\n' '|')" "[SharedFile]|	maxSearchPriority=4|	searchTree_00_3=finalboss.tre|	searchTree_00_2=patch.tre|	searchTree_00_1=base.tre|"
check_eq "client_cfg_keeps_crlf" "$(grep -c $'\r$' "$CFG")" "5"
check "client_cfg_patch_idempotent" "$("$SWG" tre patchcfg "$CFG" | grep -q 'already lists' && echo 1 || echo 0)"

bot_bg --wait 12
wait_online || die "$CHAR never came online"
check_eq "message_sent" "$(lab "systemMessage:$CHAR:fb_lab:probe_first" | grep -c '^INFO systemmessage')" "1"
wait "$BOT_PID"
check "client_received_string_id" "$(grep -aqF '@fb_lab:probe_first' "$BOTLOG" && echo 1 || echo 0)"
finish
