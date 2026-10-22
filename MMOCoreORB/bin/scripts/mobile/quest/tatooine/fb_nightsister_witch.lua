-- fb_nightsister_witch.lua — Elder Ishara Kell (Phase 4b.4). A Nightsister elder of the Dathomir stronghold; the dark Knight trial's enemy (from nightsister_elder, scaled down).
-- Spawned per student by FbKnight at the end of the trial's place; yields below a quarter of its health and talks.

fb_nightsister_witch = Creature:new {
	customName = "Elder Ishara Kell",
	randomNameType = NAME_GENERIC,
	randomNameTag = true,
	mobType = MOB_NPC,
	socialGroup = "nightsister",
	faction = "nightsister",
	level = 150,
	chanceHit = 27.25,
	damageMin = 900,
	damageMax = 1500,
	baseXp = 26654,
	baseHAM = 48000,
	baseHAMmax = 56000,
	armor = 3,
	resists = {200,25,25,200,200,200,200,200,-1},
	meatType = "",
	meatAmount = 0,
	hideType = "",
	hideAmount = 0,
	boneType = "",
	boneAmount = 0,
	milk = 0,
	tamingChance = 0,
	ferocity = 0,
	pvpBitmask = AGGRESSIVE + ATTACKABLE + ENEMY,
	creatureBitmask = PACK + KILLER + HEALER,
	optionsBitmask = AIENABLED,
	diet = HERBIVORE,

	templates = {"object/mobile/dressed_dathomir_nightsister_elder.iff"},
	lootGroups = {},

	-- Primary and secondary weapon should be different types (rifle/carbine, carbine/pistol, rifle/unarmed, etc)
	-- Unarmed should be put on secondary unless the mobile doesn't use weapons, in which case "unarmed" should be put primary and "none" as secondary
	primaryWeapon = "force_sword",
	secondaryWeapon = "force_sword_ranged",
	conversationTemplate = "fb_knight_boss_conv",

	-- primaryAttacks and secondaryAttacks should be separate skill groups specific to the weapon type listed in primaryWeapon and secondaryWeapon
	-- Use merge() to merge groups in creatureskills.lua together. If a weapon is set to "none", set the attacks variable to empty brackets
	primaryAttacks = merge(tkamaster,swordsmanmaster,fencermaster,pikemanmaster,brawlermaster,forcepowermaster),
	secondaryAttacks = forcepowermaster
}

CreatureTemplates:addCreatureTemplate(fb_nightsister_witch, "fb_nightsister_witch")
