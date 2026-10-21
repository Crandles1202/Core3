-- fb_prisoner.lua — the bound prisoner of the fourth Padawan trial (Phase 4a.3). Spawned by FbTrialPrisoner.

fb_prisoner = Creature:new {
	customName = "a bound prisoner",
	socialGroup = "townsperson",
	mobType = MOB_NPC,
	level = 10,
	chanceHit = 0.25,
	damageMin = 1,
	damageMax = 5,
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
	optionsBitmask = AIENABLED + CONVERSABLE,
	diet = HERBIVORE,

	templates = {"object/mobile/dressed_dathomir_prisoner_01.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbPrisonerConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_prisoner, "fb_prisoner")
