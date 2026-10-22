-- fb_hunter_chief.lua — Teshan Vorr, the hunters' chief (Phase 4b.4). The crystal hunters' chief in the Dantooine cave; the light Knight trial's enemy (from force_crystal_hunter).
-- Spawned per student by FbKnight at the end of the trial's place; yields below a quarter of its health and talks.

fb_hunter_chief = Creature:new {
	customName = "Teshan Vorr, the hunters' chief",
	randomNameType = NAME_GENERIC,
	randomNameTag = true,
	mobType = MOB_NPC,
	socialGroup = "kun",
	faction = "",
	level = 125,
	chanceHit = 1,
	damageMin = 700,
	damageMax = 1150,
	baseXp = 10921,
	baseHAM = 32000,
	baseHAMmax = 38000,
	armor = 2,
	resists = {80,80,80,80,80,80,80,80,-1},
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
	creatureBitmask = PACK + KILLER,
	optionsBitmask = AIENABLED,
	diet = HERBIVORE,

	templates = {"object/mobile/dressed_dark_force_crystal_hunter.iff"},
	lootGroups = {},

	-- Primary and secondary weapon should be different types (rifle/carbine, carbine/pistol, rifle/unarmed, etc)
	-- Unarmed should be put on secondary unless the mobile doesn't use weapons, in which case "unarmed" should be put primary and "none" as secondary
	primaryWeapon = "force_sword",
	secondaryWeapon = "force_sword_ranged",
	conversationTemplate = "fb_knight_boss_conv",

	-- primaryAttacks and secondaryAttacks should be separate skill groups specific to the weapon type listed in primaryWeapon and secondaryWeapon
	-- Use merge() to merge groups in creatureskills.lua together. If a weapon is set to "none", set the attacks variable to empty brackets
	primaryAttacks = merge(pikemanmaster,brawlermaster,fencermaster,swordsmanmaster,forcewielder),
	secondaryAttacks = forcewielder
}

CreatureTemplates:addCreatureTemplate(fb_hunter_chief, "fb_hunter_chief")
