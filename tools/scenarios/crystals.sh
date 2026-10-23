#!/usr/bin/env bash
# Phase 4a.0: crystal formations. Eight stand in the four caves; the client works one through the radial and a
# colour crystal lands in the bag; the formation is then bare until it regrows; a forced power roll gives a power
# crystal; red grows only on Dathomir; a crystal in the bag counts for attunement.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

C=$(lab "crystals")
check "eight_formations" "$(grep -q 'nodes=8 ' <<<"$C" && echo 1 || echo 0)" "$(head -n1 <<<"$C" | cut -c1-200)"
for cave in dantooine tatooine lok dathomir; do
	check "formations_in_$cave" "$(grep -o "$cave:[0-9]*:" <<<"$C" | wc -l | grep -qx 2 && echo 1 || echo 0)"
done
NODE=$(grep -o 'dantooine:[0-9]*:' <<<"$C" | head -n1 | cut -d: -f2)
POS=$(grep -a "crystalNode oid=$NODE " <<<"$C")
NZ=$(sed -n 's/.*zone=\([a-z0-9]*\).*/\1/p' <<<"$POS"); NCELL=$(sed -n 's/.*cell=\([0-9]*\).*/\1/p' <<<"$POS")
LX=$(sed -n 's/.* lx=\([-0-9.]*\).*/\1/p' <<<"$POS"); LY=$(sed -n 's/.* ly=\([-0-9.]*\).*/\1/p' <<<"$POS"); LZ=$(sed -n 's/.* lz=\([-0-9.]*\).*/\1/p' <<<"$POS")
check "node_stands_in_a_cell" "$( [ -n "$NCELL" ] && [ "$NCELL" != "0" ] && echo 1 || echo 0 )" "$POS"

# --- A: the client works a formation through the radial -------------------------------------------------------------
bot_bg --wait 60
wait_online || die "$CHAR never came online"
lab "attunementSit:$CHAR:stand" >/dev/null
sleep 3
lab "attunementReset:$CHAR" >/dev/null
lab "crystalReset:$NODE" >/dev/null
BEFORE=$(lab "findItem:$CHAR:lightsaber_module_force_crystal" | grep -c 'INFO item')
wait "$BOT_PID"
# beside the formation, inside its room (cell-local coordinates, 1.5 m off the node)
bot_bg --wait 14 --radial "$NODE" 20 --wait 4
wait_online || die "$CHAR never came back online"
lab "travelCell:$CHAR:$NZ:$(python3 -c "print(round($LX + 1.5, 2))"):$LZ:$LY:$NCELL" >/dev/null
wait "$BOT_PID"
check_eq "radial_accepted" "$(bot_action_status radial)" "ok" "$(grep -ao '=> #[0-9]* {"action":"radial"[^}]*}' "$BOTLOG" | tail -n1 | cut -c1-160)"
AFTER=$(lab "findItem:$CHAR:lightsaber_module_force_crystal" | grep -c 'INFO item')
check "a_crystal_in_the_bag" "$( [ "${AFTER:-0}" -gt "${BEFORE:-0}" ] && echo 1 || echo 0 )" "crystals $BEFORE -> $AFTER; $(lab "findItem:$CHAR:lightsaber_module_force_crystal" | head -n1 | cut -c1-120)"
check "client_got_the_crystal_line" "$(grep -aq 'fb_force:crystal_taken\|fb_force:crystal_power' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'crystal_' "$BOTLOG" | cut -c1-80 | tail -n1)"
check "formation_bare" "$(lab "crystals" | grep -q "dantooine:$NODE:bare" && echo 1 || echo 0)" "$(lab "crystals" | head -n1 | cut -c1-160)"
check "attunement_counts_the_crystal" "$(lab "attunement:$CHAR" | grep -q 'items=10' && echo 1 || echo 0)" "$(lab "attunement:$CHAR" | head -n1 | cut -c1-120)"

# --- B: bare until it regrows; a forced power roll; red only on Dathomir -------------------------------------------------
sleep 6
bot_bg --wait 30
wait_online || die "$CHAR never came back online"
H=$(lab "crystalHarvest:$CHAR:$NODE")
check "bare_refuses" "$(grep -q 'ok=false' <<<"$H" && echo 1 || echo 0)" "$H"
lab "crystalReset:$NODE" >/dev/null
P0=$(lab "findItem:$CHAR:power_crystal\|lightsaber_module" | grep -c 'INFO item')
H=$(lab "crystalHarvest:$CHAR:$NODE:power")
check "power_roll_gives_a_crystal" "$(grep -q 'ok=true' <<<"$H" && echo 1 || echo 0)" "$H"
check "red_grows_only_on_dathomir" "$(lab "crystals" >/dev/null; grep -c 'red = true' "$REPO/MMOCoreORB/bin/scripts/custom_scripts/screenplays/fb_crystals.lua")" "one cave carries red"
lab "crystalReset:$NODE" >/dev/null
lab "attunementReset:$CHAR" >/dev/null
wait "$BOT_PID"
finish
