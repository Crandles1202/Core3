-- fb_cantina_musician.lua — Cantina musician creature template.

fb_cantina_musician = Creature:new {
	customName = "Figrin Bren (Cantina Musician)",
	socialGroup = "townsperson",
	mobType = MOB_NPC,
	chanceHit = 0.25,
	damageMin = 1,
	damageMax = 5,
	baseXp = 0,
	baseHAM = 100,
	baseHAMmax = 100,
	armor = 0,
	faction = "",
	level = 1,
	pvpBitmask = NONE,
	creatureBitmask = NONE,
	optionsBitmask = INVULNERABLE + CONVERSABLE,
	diet = HERBIVORE,
	-- Bith musician trainer — Cantina Band vibes.
	templates = {"object/mobile/dressed_musician_trainer_01.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbCantinaMusicianConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_cantina_musician, "fb_cantina_musician")
