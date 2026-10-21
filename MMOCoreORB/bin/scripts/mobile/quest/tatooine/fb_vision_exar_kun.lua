-- fb_vision_exar_kun.lua — Exar Kun, the Sith Lord whose temple stands on Yavin 4 (Phase 4a.4). A vision figure: FbVisions spawns it in the dungeon1
-- vision ground beside the dreamer, it speaks its lines and is swept away with the vision. It never stands in
-- the physical world, never fights, never talks back.

fb_vision_exar_kun = Creature:new {
	customName = "Exar Kun",
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

	templates = {"object/mobile/dressed_dark_jedi_human_male_01.iff"},
	lootGroups = {},
	weapons = {},
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_vision_exar_kun, "fb_vision_exar_kun")
