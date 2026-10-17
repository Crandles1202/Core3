-- fb_combat_quartermaster.lua — Quartermaster Sehrev creature template.
-- Sells combat consumables (grenades). Phase 2.3 MVP.
--
-- Install:  mobile/quest/tatooine/fb_combat_quartermaster.lua
-- Register: includeFile("quest/tatooine/fb_combat_quartermaster.lua")

fb_combat_quartermaster = Creature:new {
	customName = "Quartermaster Sehrev (FB Combat Supply)",
	socialGroup = "townsperson",
	mobType = MOB_NPC,
	chanceHit = 0.25,
	damageMin = 1,
	damageMax = 5,
	baseXp = 0,
	baseHAM = 100,
	baseHAMmax = 100,
	armor = 0,
	faction = "",
	level = 1,
	fireBreathChance = 0,
	ferocity = 0,
	pvpBitmask = NONE,
	creatureBitmask = NONE,
	optionsBitmask = INVULNERABLE + CONVERSABLE,
	diet = HERBIVORE,

	-- Zabrak brigade sergeant — military quartermaster look.
	templates = {"object/mobile/dressed_brigade_sergeant_zabrak_male_01.iff"},

	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbCombatQuartermasterConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_combat_quartermaster, "fb_combat_quartermaster")
