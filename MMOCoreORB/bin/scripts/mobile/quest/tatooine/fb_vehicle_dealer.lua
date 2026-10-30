-- fb_vehicle_dealer.lua — Final Boss 2.13: vehicle dealer (Trade Hall tenant).
fb_vehicle_dealer = Creature:new {
	customName = "Rook Valdane (Vehicle Dealer)",
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
	templates = {"object/mobile/dressed_smuggler_trainer_01.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbVehicleDealerConvoTemplate",
	attacks = {}
}
CreatureTemplates:addCreatureTemplate(fb_vehicle_dealer, "fb_vehicle_dealer")
