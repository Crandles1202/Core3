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

bot_bg --wait 12
wait_online || die "$CHAR never came online"
check_eq "message_sent" "$(lab "systemMessage:$CHAR:fb_lab:probe_first" | grep -c '^INFO systemmessage')" "1"
wait "$BOT_PID"
check "client_received_string_id" "$(grep -aqF '@fb_lab:probe_first' "$BOTLOG" && echo 1 || echo 0)"
finish
