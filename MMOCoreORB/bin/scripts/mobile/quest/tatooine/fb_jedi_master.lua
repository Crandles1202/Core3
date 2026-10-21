-- fb_jedi_master.lua — Master Ilara Venn, the Jedi Master of the Light Enclave on Yavin 4 (Phase 4b.1).
-- Spawned at boot by FbJediMaster into the enclave's training room; static, never fights. Her conversation
-- (fb_jedi_master_conv) takes a light Padawan as a student and hears the training tasks reported.

fb_jedi_master = Creature:new {
	customName = "Master Ilara Venn",
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

	templates = {"object/mobile/dressed_jedi_trainer_twilek_female_01.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fb_jedi_master_conv",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_jedi_master, "fb_jedi_master")
