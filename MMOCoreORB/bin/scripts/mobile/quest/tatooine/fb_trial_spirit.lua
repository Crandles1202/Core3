-- fb_trial_spirit.lua — the spirit that asks the riddle and takes the sacrifice (Phase 4a.3). Spawned by FbTrialSpirit.

fb_trial_spirit = Creature:new {
	customName = "a robed figure",
	socialGroup = "fs_villager",
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
	optionsBitmask = AIENABLED + INVULNERABLE + CONVERSABLE,
	diet = HERBIVORE,

	templates = {"object/mobile/dressed_jedi_trainer_old_human_male_01.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbTrialSpiritConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_trial_spirit, "fb_trial_spirit")
