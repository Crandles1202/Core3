-- fb_traveling_merchant.lua — Phase 2.9 traveling merchant mobile template.
fb_traveling_merchant = Creature:new {
	customName = "Ozlo Vantrek (Traveling Merchant)",
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
	-- a merchant who has clearly been on the road
	templates = {"object/mobile/dressed_merchant_trainer_02.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbTravelingMerchantConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_traveling_merchant, "fb_traveling_merchant")
