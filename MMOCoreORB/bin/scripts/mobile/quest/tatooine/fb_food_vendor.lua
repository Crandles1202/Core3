-- fb_food_vendor.lua — Final Boss 2.16: the chef (Trade Hall tenant).
fb_food_vendor = Creature:new {
	customName = "Oola Prenn (Chef)",
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
	templates = {"object/mobile/dressed_chef_trainer_human_female_01.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbFoodVendorConvoTemplate",
	attacks = {}
}
CreatureTemplates:addCreatureTemplate(fb_food_vendor, "fb_food_vendor")
