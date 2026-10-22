-- fb_vision_kenobi.lua — Obi-Wan Kenobi, the old Jedi, as he was on Tatooine (Phase 4a.4). A vision figure: FbVisions spawns it in the dungeon1
-- vision ground beside the dreamer, it speaks its lines and is swept away with the vision. It never stands in
-- the physical world, never fights, never talks back.

fb_vision_kenobi = Creature:new {
	customName = "Obi-Wan Kenobi",
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
	optionsBitmask = AIENABLED + INVULNERABLE,
	diet = HERBIVORE,

	templates = {"object/mobile/dressed_jedi_trainer_old_human_male_01.iff"},
	lootGroups = {},
	weapons = {},
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_vision_kenobi, "fb_vision_kenobi")
