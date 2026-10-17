-- fb_armor_droid.lua  — FB-44 Armor Droid creature template.
-- Sells basic padded armor pieces. Phase 2.2 MVP.
--
-- Install:  mobile/quest/tatooine/fb_armor_droid.lua
-- Register: includeFile("quest/tatooine/fb_armor_droid.lua")

fb_armor_droid = Creature:new {
	customName = "FB-44 (Armor Droid)",
	socialGroup = "townsperson",
	mobType = MOB_DROID,
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

	-- Repair/utility droid look — distinct from FB-72's protocol droid.
	templates = {"object/mobile/le_repair_droid.iff"},

	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbArmorDroidConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_armor_droid, "fb_armor_droid")
