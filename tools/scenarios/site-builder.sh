#!/usr/bin/env bash
# Phase 2.12b: the site builder (architect mode on the Lab Remote), driven through its lab oracles as the
# admin bot: a shell is previewed where the bot stands in the open desert east of Mos Eisley (lot clear),
# nudged, a tenant is placed from inside (room coordinates + furniture verdict), an outdoor NPC outside,
# the draft is renamed and its site-file text matches what FbSites:add expects, then it is discarded and
# nothing of it remains. A second preview on the starport square must report the apron as a clash.
# covers: fb_site_builder fb_sites
export SWG_BOT_USER=claude-admin
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SHELL_T="object/building/tatooine/shared_housing_tatt_style01_small.iff"

bot_bg --wait 70
wait_online || die "$CHAR (claude-admin) never came online"
lab "siteDiscard:$CHAR" >/dev/null
lab "travel:$CHAR:tatooine:3900:-4800" >/dev/null       # open desert
sleep 1
ST=$(lab "structuresNear:$CHAR:150")
check "structures_binding_answers" "$(grep -q 'INFO structures count=' <<<"$ST" && echo 1 || echo 0)" "$(tail -n1 <<<"$ST")"

NEW=$(lab "siteNew:$CHAR:$SHELL_T:90:lab_desert_house")
check_eq "preview_lot_clear_in_the_desert" "$(sed -n 's/.*verdict=\([a-z]*\).*/\1/p' <<<"$NEW" | tail -n1)" "ok" "$(grep -a 'INFO lot' <<<"$NEW" | tr '\n' ' ')"
PREVIEW=$(sed -n 's/.*preview=\([0-9]*\).*/\1/p' <<<"$NEW" | tail -n1)
check "preview_building_spawned" "$( [ -n "$PREVIEW" ] && [ "$PREVIEW" != "0" ] && echo 1 || echo 0 )" "oid=$PREVIEW"
INFO=$(lab "buildingInfo:$PREVIEW")
check_ge "preview_has_rooms" "$(grep -ac '^INFO cell' <<<"$INFO")" 1 "$(grep -a '^INFO lot' <<<"$INFO")"

NUDGE=$(lab "siteNudge:$CHAR:forward:5")
check_eq "nudge_moved_the_preview" "$(sed -n 's/.*x=\([0-9.]*\) y=.*/\1/p' <<<"$NUDGE" | tail -n1)" "3905.0" "$NUDGE"
PREVIEW2=$(sed -n 's/.*preview=\([0-9]*\).*/\1/p' <<<"$NUDGE" | tail -n1)
check "nudge_respawned_the_building" "$( [ -n "$PREVIEW2" ] && [ "$PREVIEW2" != "$PREVIEW" ] && echo 1 || echo 0 )" "$PREVIEW -> $PREVIEW2"
check_eq "old_preview_gone" "$(lab "objectPos:$PREVIEW" | grep -ac 'zone=tatooine')" "0" "$(lab "objectPos:$PREVIEW" | head -n1)"

# inside: the first room of the respawned preview
CELL=$(lab "buildingInfo:$PREVIEW2" | grep -a '^INFO cell' | head -n1 | sed -n 's/.*oid=\([0-9]*\).*/\1/p')
ROOM=$(lab "buildingInfo:$PREVIEW2" | grep -a '^INFO cell' | head -n1 | sed -n 's/.*name=\([a-z0-9_]*\).*/\1/p')
lab "travelCell:$CHAR:tatooine:0:0.5:0:$CELL" >/dev/null
sleep 1
TEN=$(lab "siteTenant:$CHAR:fb_stim_dealer:Vex Renn, medical supplies")
check "tenant_placed_inside" "$(grep -q '^INFO tenant' <<<"$TEN" && echo 1 || echo 0)" "$TEN"
check_eq "tenant_in_the_room_i_stood_in" "$(sed -n 's/.*room=\([a-z0-9_]*\).*/\1/p' <<<"$TEN" | tail -n1)" "$ROOM"
check "tenant_furniture_verdict_given" "$(grep -q 'furniture=\(ok\|warn\|fail\)' <<<"$TEN" && echo 1 || echo 0)"
TEN_OID=$(sed -n 's/.*oid=\([0-9]*\).*/\1/p' <<<"$TEN" | tail -n1)
check "tenant_npc_live" "$(lab "objectPos:$TEN_OID" | grep -q "cell=$CELL" && echo 1 || echo 0)"

lab "travel:$CHAR:tatooine:3915:-4800" >/dev/null
sleep 1
OUT=$(lab "siteOutside:$CHAR:fb_trade_hall_keeper")
check "outdoor_npc_placed" "$(grep -q '^INFO outside' <<<"$OUT" && echo 1 || echo 0)" "$OUT"

TXT=$(lab "siteText:$CHAR")
check "site_text_is_a_site" "$(grep -q 'INFO sitefile FbSites:add {' <<<"$TXT" && echo 1 || echo 0)"
check "site_text_names_the_shell" "$(grep -qF "object/building/tatooine/housing_tatt_style01_small.iff" <<<"$TXT" && echo 1 || echo 0)"   # the server form FbSites spawns
check "site_text_has_the_tenant" "$(grep -q 'template = "fb_stim_dealer".*room = "'"$ROOM"'"' <<<"$TXT" && echo 1 || echo 0)"
check "site_text_has_the_outdoor_npc" "$(grep -q 'template = "fb_trade_hall_keeper", x = 3915' <<<"$TXT" && echo 1 || echo 0)"
check_eq "site_text_heading" "$(sed -n 's/.*heading = \([0-9]*\),.*/\1/p' <<<"$TXT" | head -n1)" "90"

# swg site save writes the draft into the repo's sites folder (removed again: a lab artefact)
SAVED="$REPO/MMOCoreORB/bin/scripts/screenplays/tasks/sites/lab_desert_house.lua"
rm -f "$SAVED"
"$SWG" site save "$CHAR" lab_desert_house >/dev/null 2>&1
check "site_save_wrote_the_file" "$( [ -f "$SAVED" ] && grep -q '^FbSites:add {' "$SAVED" && echo 1 || echo 0 )" "$SAVED"
check "saved_file_is_valid_lua" "$(luac -p "$SAVED" 2>/dev/null && echo 1 || echo 0)"
rm -f "$SAVED"

# the square: the starport apron must be reported
lab "travel:$CHAR:tatooine:3568:-4802" >/dev/null
sleep 1
SQ=$(lab "siteNew:$CHAR:$SHELL_T:270:lab_square_house")
check_eq "square_lot_reports_the_apron" "$(sed -n 's/.*verdict=\([a-z]*\).*/\1/p' <<<"$SQ" | tail -n1)" "fail" "$(grep -a 'CLASH' <<<"$SQ" | head -n1)"
check "square_clash_names_the_starport" "$(grep -q 'CLASH.*starport' <<<"$SQ" && echo 1 || echo 0)"

lab "siteDiscard:$CHAR" >/dev/null
check_eq "discard_clears_the_draft" "$(lab "siteDraft:$CHAR" | grep -ac 'INFO site none')" "1"
check_eq "discard_removed_the_tenant" "$(lab "findNpc:$TEN_OID" | grep -ac '^INFO npc')" "0"
wait "$BOT_PID"
finish
