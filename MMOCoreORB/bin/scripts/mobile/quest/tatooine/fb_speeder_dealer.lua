-- fb_speeder_dealer.lua — Drosa Vex (vehicle deed vendor) creature template.

fb_speeder_dealer = Creature:new {
	customName = "Drosa Vex (FB Speeder Dealer)",
	socialGroup = "townsperson",
	faction = "",
	level = 1,
	pvpBitmask = NONE,
	creatureBitmask = NONE,
	optionsBitmask = INVULNERABLE + CONVERSABLE,
	diet = HERBIVORE,
	templates = {"object/mobile/dressed_commoner_tatooine_sullustan_male_01.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbSpeederDealerConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_speeder_dealer, "fb_speeder_dealer")
