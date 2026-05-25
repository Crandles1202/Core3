-- fb_mos_eisley_medical_droid.lua
-- Mobile template for the medical droid NPC in Mos Eisley.
--
-- Install path: MMOCoreORB/bin/scripts/mobile/quest/tatooine/fb_mos_eisley_medical_droid.lua
--
-- Provides buffs and wound clearing to players who talk to it.
-- Phase 2.6 MVP — NPC buff providers. Final Boss server custom content.

fb_mos_eisley_medical_droid = Creature:new {
	objectName = "",
	customName = "FB-21 (Medical Droid)",
	socialGroup = "townsperson",
	faction = "",
	level = 1,
	chanceHit = 0.0,
	damageMin = 0,
	damageMax = 0,
	baseXp = 0,
	baseHAM = 100,
	baseHAMmax = 100,
	armor = 0,
	resists = {0,0,0,0,0,0,0,0,-1},
	meatType = "",
	meatAmount = 0,
	hideType = "",
	hideAmount = 0,
	boneType = "",
	boneAmount = 0,
	milk = 0,
	tamingChance = 0.0,
	ferocity = 0,
	pvpBitmask = NONE,
	creatureBitmask = NONE,
	diet = HERBIVORE,

	templates = {"object/mobile/21b_surgical_droid.iff"},
	lootGroups = {},

	primaryWeapon = "unarmed",
	secondaryWeapon = "none",

	primaryAttacks = {},
	secondaryAttacks = {},

	conversationTemplate = "fbMosEisleyMedicalDroidConvoTemplate",
	optionsBitmask = INVULNERABLE + CONVERSABLE
}

CreatureTemplates:addCreatureTemplate(fb_mos_eisley_medical_droid, "fb_mos_eisley_medical_droid")
