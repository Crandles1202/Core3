-- fb_old_man.lua — the Old Man who comes for a fully attuned character (Phase 4a.1).
-- Stock Village appearance; our own conversation (fbOldManConvoTemplate), spawned by FbOldManVisit.

fb_old_man = Creature:new {
	customName = "an old man",
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
	optionsBitmask = AIENABLED + INVULNERABLE + CONVERSABLE,
	diet = HERBIVORE,

	templates = {"object/mobile/dressed_fs_village_oldman.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbOldManConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_old_man, "fb_old_man")
