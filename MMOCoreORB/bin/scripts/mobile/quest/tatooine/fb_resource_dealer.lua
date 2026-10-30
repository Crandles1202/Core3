-- fb_resource_dealer.lua — Final Boss 2.14: raw resource dealer (Trade Hall tenant).
fb_resource_dealer = Creature:new {
	customName = "Mehra Tulk (Resource Dealer)",
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
	fireBreathChance = 0,
	ferocity = 0,
	pvpBitmask = NONE,
	creatureBitmask = NONE,
	optionsBitmask = INVULNERABLE + CONVERSABLE,
	diet = HERBIVORE,
	templates = {"object/mobile/dressed_artisan_trainer_01.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbResourceDealerConvoTemplate",
	attacks = {}
}
CreatureTemplates:addCreatureTemplate(fb_resource_dealer, "fb_resource_dealer")
