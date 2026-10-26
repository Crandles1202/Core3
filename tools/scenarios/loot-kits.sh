#!/usr/bin/env bash
# Phase 2.4: loot kits. The kit data loads; a kit and its parts land in the bag; moving the parts into the kit (the stock
# container path) makes the finished piece with the tier's stats; the three armor tiers and a weapon tier sit where the
# ladder says (docs/Loot-Kits-Design.md); the drop roll gives parts to a creature kill and parts plus a kit to a humanoid
# kill, matching the source; nothing falls below the first band.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

K=$(lab "kits")
check "kit_data_loaded" "$(grep -q 'loaded=true' <<<"$K" && grep -q 'partTemplates=30' <<<"$K" && echo 1 || echo 0)" "$K"

bot_bg --wait 150
wait_online || die "$CHAR never came online"
lab "attunementSit:$CHAR:stand" >/dev/null
sleep 3
lab "takeItems:$CHAR:fb_kits/" >/dev/null
lab "takeItems:$CHAR:wearables/armor" >/dev/null
lab "takeItems:$CHAR:weapon/ranged/pistol/pistol_dl44" >/dev/null

assemble() {   # <kitId> <class> <tier> <reward path fragment> → REWARD oid and STATS
	lab "kitGive:$CHAR:$1" >/dev/null
	KIT=$(lab "findItem:$CHAR:fb_kits/kit_$1.iff" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | tail -n1)
	lab "kitParts:$CHAR:$2:$3" >/dev/null
	A=$(lab "kitAssemble:$CHAR:$KIT")
	REWARD=$(lab "findItem:$CHAR:$4" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | tail -n1)
	STATS=$( [ -n "$REWARD" ] && lab "itemStats:$REWARD" | head -n1 || echo "no reward" )
}
within() { python3 -c "import sys; v=float('$1'); sys.exit(0 if $2 <= v <= $3 else 1)" 2>/dev/null; }
kv() { sed -n "s/.*[[:space:]]$2=\([^[:space:]]*\).*/\1/p" <<<"$1" | head -n1; }

# --- A: tier I, a bone chest plate -----------------------------------------------------------------------------------
assemble bone_chest_plate_1 armor 1 "armor/bone/armor_bone_s01_chest_plate"
check "kit_consumed_its_parts" "$(grep -q 'kitGone=true' <<<"$A" && grep -q 'partsLeft=0' <<<"$A" && echo 1 || echo 0)" "$A"
check "bone_chest_made" "$( [ -n "$REWARD" ] && echo 1 || echo 0 )" "$STATS"
check "tier1_effectiveness_28_33" "$(within "$(kv "$STATS" energy)" 28 33 && within "$(kv "$STATS" electricity)" 28 33 && echo 1 || echo 0)" "bone protects energy and electricity (the stock set is vulnerable to the rest); $STATS"
check_eq "tier1_integrity" "$(kv "$STATS" maxCondition)" "15000"
check_eq "bone_encumbrance_from_template" "$(kv "$STATS" encumbrance)" "56/22/4"

# --- B: tier II composite: kinetic special; tier III veteran composite --------------------------------------------------
lab "takeItems:$CHAR:wearables/armor" >/dev/null
assemble composite_chest_plate_2 armor 2 "armor/composite/armor_composite_chest_plate"
check "tier2_effectiveness_42_48" "$(within "$(kv "$STATS" energy)" 42 48 && echo 1 || echo 0)" "$STATS"
check "tier2_composite_kinetic_special_plus_10" "$(within "$(kv "$STATS" kinetic)" 52 58 && echo 1 || echo 0)" "$STATS"
check_eq "tier2_integrity" "$(kv "$STATS" maxCondition)" "25000"
lab "takeItems:$CHAR:wearables/armor" >/dev/null
assemble composite_adv_chest_plate_3 armor 3 "armor/composite/armor_composite_chest_plate"
check "tier3_effectiveness_52_58" "$(within "$(kv "$STATS" energy)" 52 58 && echo 1 || echo 0)" "$STATS"
check "tier3_kinetic_special_plus_15" "$(within "$(kv "$STATS" kinetic)" 67 73 && echo 1 || echo 0)" "$STATS"
check_eq "tier3_integrity" "$(kv "$STATS" maxCondition)" "35000"
check "tier3_needs_five_parts" "$(grep -q 'moved=5' <<<"$A" && echo 1 || echo 0)" "$A"
check "kit_short_of_parts_waits" "$(lab "kitGive:$CHAR:padded_boots_1" >/dev/null; K2=$(lab "findItem:$CHAR:fb_kits/kit_padded_boots_1.iff" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | tail -n1); lab "kitParts:$CHAR:weapon:1" >/dev/null; lab "kitAssemble:$CHAR:$K2" | grep -q 'moved=0.*kitGone=false' && echo 1 || echo 0)" "weapon parts do not fit an armor kit"
lab "takeItems:$CHAR:fb_kits/" >/dev/null

# --- C: a tier II DL44 ---------------------------------------------------------------------------------------------------
assemble dl44_2 weapon 2 "pistol/pistol_dl44"
check "dl44_made" "$( [ -n "$REWARD" ] && echo 1 || echo 0 )" "$STATS"
check_eq "dl44_tier2_damage" "$(kv "$STATS" min)-$(kv "$STATS" max)" "24-108" "template 20-90 x1.2; $STATS"
check "dl44_tier2_speed" "$(within "$(kv "$STATS" speed)" 3.0 3.12 && echo 1 || echo 0)" "template 3.4 x0.9; $STATS"
check_eq "dl44_tier2_integrity" "$(kv "$STATS" maxCondition)" "25000"

# --- D: the drop roll: a creature gives parts only, a Tusken gives parts and a bone or padded kit; level 2 gives nothing
lab "takeItems:$CHAR:fb_kits/" >/dev/null
R=$(lab "kitRoll:$CHAR:15:0:worrt:force")
check "creature_drops_parts_not_kits" "$(grep -q 'parts=fb_kit_parts_' <<<"$R" && grep -q 'kit=-' <<<"$R" && echo 1 || echo 0)" "$R"
R=$(lab "kitRoll:$CHAR:15:1:tusken_raider:force")
check "tusken_drops_matching_kit" "$(grep -q 'kit=fb_kits_\(bone\|padded\|weapon\)_1' <<<"$R" && echo 1 || echo 0)" "$R"
R=$(lab "kitRoll:$CHAR:40:1:stormtrooper:force")
check "stormtrooper_drops_composite_or_weapon_2" "$(grep -q 'kit=fb_kits_\(composite\|weapon\)_2' <<<"$R" && echo 1 || echo 0)" "$R"
R=$(lab "kitRoll:$CHAR:80:1:nightsister:force")
check "level80_nightsister_tier3" "$(grep -q 'kit=fb_kits_\(3\|weapon_3\)' <<<"$R" && grep -q 'parts=fb_kit_parts_[a-z]*_3' <<<"$R" && echo 1 || echo 0)" "chitin has no tier III, so the tier's whole pool; $R"
R=$(lab "kitRoll:$CHAR:2:1:tusken_raider:force")
check "below_the_first_band_nothing" "$(grep -q 'parts=-,kit=-' <<<"$R" && echo 1 || echo 0)" "$R"
# the real path: the kill hook schedules the drop into the corpse
X=$(lab "where:$CHAR" | sed -n 's/.* x=\([-0-9.]*\).*/\1/p' | head -n1); Y=$(lab "where:$CHAR" | sed -n 's/.* y=\([-0-9.]*\).*/\1/p' | head -n1)
RAIDER=$(lab "spawnNpcAt:tusken_raider:tatooine:$(python3 -c "print(round($X + 8, 1))"):$Y:0" | sed -n 's/.*oid=\([0-9]*\).*/\1/p' | head -n1)
check "raider_for_the_hook" "$( [ -n "$RAIDER" ] && echo 1 || echo 0 )"
lab "attunementKill:$CHAR:tusken_raider" >/dev/null     # the kill observer path, a throwaway victim
sleep 2
check "hook_is_wired" "$(grep -q 'FbLootKits:onKill' "$REPO/MMOCoreORB/bin/scripts/custom_scripts/screenplays/fb_attunement.lua" && echo 1 || echo 0)"
[ -n "$RAIDER" ] && lab "killNpc:$CHAR:$RAIDER" >/dev/null
lab "revive:$CHAR" >/dev/null
lab "takeItems:$CHAR:fb_kits/" >/dev/null
lab "takeItems:$CHAR:wearables/armor" >/dev/null
lab "takeItems:$CHAR:weapon/ranged/pistol/pistol_dl44" >/dev/null
wait "$BOT_PID"
check "client_saw_the_kit_message" "$(grep -aq 'loot_kit:new_item_created' "$BOTLOG" && echo 1 || echo 0)" "$(grep -a 'loot_kit' "$BOTLOG" | head -n1 | cut -c1-100)"
finish
