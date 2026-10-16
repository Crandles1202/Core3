-- fb_pet_dealer.lua — Handler Toobu (creature pet vendor) creature template.

fb_pet_dealer = Creature:new {
	customName = "Handler Toobu (Beast Auctioneer)",
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
	-- Zabrak creature handler trainer — distinct from Yan'lara's human CH.
	templates = {"object/mobile/dressed_creaturehandler_trainer_zabrak_male_01.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbPetDealerConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_pet_dealer, "fb_pet_dealer")
