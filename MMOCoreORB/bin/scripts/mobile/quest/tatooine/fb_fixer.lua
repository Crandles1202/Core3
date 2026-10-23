-- fb_fixer.lua — Dax Ventrell, the fixer in the Mos Eisley cantina (Phase 4c). A Jedi with a price on their
-- head pays him a markup and the hunters stay away for a day. Spawned at boot by FbBounty; static, never fights.

fb_fixer = Creature:new {
	customName = "Dax Ventrell",
	socialGroup = "townsperson",
	mobType = MOB_NPC,
	chanceHit = 0.25,
	damageMin = 1,
	damageMax = 5,
	level = 10,
	baseXp = 0,
	baseHAM = 1000,
	baseHAMmax = 1200,
	armor = 0,
	resists = {0,0,0,0,0,0,0,0,0},
	meatType = "",
	meatAmount = 0,
	hideType = "",
	hideAmount = 0,
	boneType = "",
	boneAmount = 0,
	milk = 0,
	tamingChance = 0,
	ferocity = 0,
	pvpBitmask = NONE,
	creatureBitmask = NONE,
	optionsBitmask = AIENABLED + CONVERSABLE + INVULNERABLE,
	diet = HERBIVORE,

	templates = {"object/mobile/dressed_criminal_smuggler_human_female_01.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fb_fixer_conv",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_fixer, "fb_fixer")
