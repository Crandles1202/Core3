-- fb_component_depot.lua — Final Boss 2.15: the component depot keeper (Trade Hall tenant).
fb_component_depot = Creature:new {
	customName = "BX-4 (Component Depot)",
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
	templates = {"object/mobile/dressed_droidengineer_trainer_human_male_01.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbComponentDepotConvoTemplate",
	attacks = {}
}
CreatureTemplates:addCreatureTemplate(fb_component_depot, "fb_component_depot")
