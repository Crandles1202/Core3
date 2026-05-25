-- fb_stim_dealer.lua
-- Creature template for Vex Renn, an FB-affiliated combat medic who sells
-- basic medical consumables. Phase 2.1 — Final Boss server.
--
-- Humanoid NPC (not a droid) — third FB-network vendor type after FB-21
-- (medical droid, services) and FB-72 (armory droid, weapons). Stim dealer
-- being humanoid adds visual variety to the FB-network and fits the
-- "field medic running a supply stand" feel.
--
-- Install path: MMOCoreORB/bin/scripts/mobile/quest/tatooine/fb_stim_dealer.lua
-- Register in:  mobile/quest/serverobjects.lua  as
--               includeFile("quest/tatooine/fb_stim_dealer.lua")

fb_stim_dealer = Creature:new {
	customName = "Vex Renn (FB Medical Supplier)",
	socialGroup = "townsperson",
	faction = "",
	level = 1,
	fireBreathChance = 0,
	ferocity = 0,
	pvpBitmask = NONE,
	creatureBitmask = NONE,

	-- INVULNERABLE + CONVERSABLE: same pattern as FB-21 and FB-72.
	optionsBitmask = INVULNERABLE + CONVERSABLE,
	diet = HERBIVORE,

	-- Humanoid combat medic appearance. Verified template path.
	templates = {"object/mobile/dressed_combatmedic_trainer_human_male_01.iff"},

	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbStimDealerConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_stim_dealer, "fb_stim_dealer")
