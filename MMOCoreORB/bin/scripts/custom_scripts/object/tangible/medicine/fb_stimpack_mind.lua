-- fb_stimpack_mind.lua — Phase 1.9: stimpacks heal mind damage.
--
-- Pre-CU mind damage could only be healed by an entertainer (or slow regen), which is a
-- multiplayer dependency. A stimpack template lists the HAM pools it heals in `attributes`
-- (CreatureAttribute: 0 = health, 3 = action, 6 = mind); HealDamageCommand heals every pool
-- in that list with the same power. Pet stimpacks and crafted medpacks already list all three.
-- This file re-registers the player stimpacks with mind added.
--
-- How it works: object templates are plain Lua globals, loaded in one Lua state in the order
-- object/serverobjects.lua includes them; custom_scripts/object/serverobjects.lua is included
-- last, so these globals already exist here. ObjectTemplates:addTemplate() on an existing key
-- replaces the earlier entry (TemplateManager::addTemplate -> templateCRCMap->put).
-- Needs a server restart to take effect (templates load at boot).
--
-- Side effect worth knowing: /healdamage costs the healer mind; healing yourself now gives
-- some of it back. Intended for solo play.

local fbStimpacksHealMind = {
	-- starter / dispensed stimpack (the Phase 1.3 starter-gear item)
	{ "object_tangible_medicine_stimpack_sm_s1", "object/tangible/medicine/stimpack_sm_s1.iff" },
	-- medic-crafted stimpacks A–E
	{ "object_tangible_medicine_crafted_crafted_stimpack_sm_s1_a", "object/tangible/medicine/crafted/crafted_stimpack_sm_s1_a.iff" },
	{ "object_tangible_medicine_crafted_crafted_stimpack_sm_s1_b", "object/tangible/medicine/crafted/crafted_stimpack_sm_s1_b.iff" },
	{ "object_tangible_medicine_crafted_crafted_stimpack_sm_s1_c", "object/tangible/medicine/crafted/crafted_stimpack_sm_s1_c.iff" },
	{ "object_tangible_medicine_crafted_crafted_stimpack_sm_s1_d", "object/tangible/medicine/crafted/crafted_stimpack_sm_s1_d.iff" },
	{ "object_tangible_medicine_crafted_crafted_stimpack_sm_s1_e", "object/tangible/medicine/crafted/crafted_stimpack_sm_s1_e.iff" },
	-- combat-medic ranged stimpacks A–E and area stimpacks A–C
	{ "object_tangible_medicine_crafted_medpack_grenade_damage_a", "object/tangible/medicine/crafted/medpack_grenade_damage_a.iff" },
	{ "object_tangible_medicine_crafted_medpack_grenade_damage_b", "object/tangible/medicine/crafted/medpack_grenade_damage_b.iff" },
	{ "object_tangible_medicine_crafted_medpack_grenade_damage_c", "object/tangible/medicine/crafted/medpack_grenade_damage_c.iff" },
	{ "object_tangible_medicine_crafted_medpack_grenade_damage_d", "object/tangible/medicine/crafted/medpack_grenade_damage_d.iff" },
	{ "object_tangible_medicine_crafted_medpack_grenade_damage_e", "object/tangible/medicine/crafted/medpack_grenade_damage_e.iff" },
	{ "object_tangible_medicine_crafted_medpack_grenade_area_a", "object/tangible/medicine/crafted/medpack_grenade_area_a.iff" },
	{ "object_tangible_medicine_crafted_medpack_grenade_area_b", "object/tangible/medicine/crafted/medpack_grenade_area_b.iff" },
	{ "object_tangible_medicine_crafted_medpack_grenade_area_c", "object/tangible/medicine/crafted/medpack_grenade_area_c.iff" },
	-- quest-reward stimpack (templateType STIMPACK despite living under component/chemistry)
	{ "object_tangible_component_chemistry_quest_stimpack_a", "object/tangible/component/chemistry/quest_stimpack_a.iff" },
}

for _, entry in ipairs(fbStimpacksHealMind) do
	local template = _G[entry[1]]
	if template ~= nil then
		template.attributes = { 0, 3, 6 }
		ObjectTemplates:addTemplate(template, entry[2])
	end
end
