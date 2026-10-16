-- fb_imperial_armorer.lua — Imperial Armorer (Major Tarkus) creature template.
-- Themed faction-split vendor: stormtrooper armor + Imperial blasters.

fb_imperial_armorer = Creature:new {
	customName = "Major Tarkus (FB Imperial Armorer)",
	socialGroup = "imperial",
	faction = "imperial",
	level = 1,
	pvpBitmask = NONE,
	creatureBitmask = NONE,
	optionsBitmask = INVULNERABLE + CONVERSABLE,
	diet = HERBIVORE,
	-- Imperial officer in the dress uniform — looks the part.
	templates = {"object/mobile/dressed_imperial_officer_m.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbImperialArmorerConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_imperial_armorer, "fb_imperial_armorer")
