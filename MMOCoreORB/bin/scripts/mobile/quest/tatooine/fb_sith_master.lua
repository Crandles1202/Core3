-- fb_sith_master.lua — Darth Ysanne Vhal, the Sith Master of the Dark Enclave on Yavin 4 (Phase 4b.2).
-- Spawned at boot by FbSithMaster into the chamber at the far end of the enclave; static, never fights. Her conversation
-- (fb_sith_master_conv) takes a dark Padawan as a student and hears the training tasks reported.

fb_sith_master = Creature:new {
	customName = "Darth Ysanne Vhal",
	socialGroup = "fs_villager",
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

	templates = {"object/mobile/dressed_dark_jedi_human_female_01.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fb_sith_master_conv",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_sith_master, "fb_sith_master")
