-- fb_cantina_manager.lua — Cantina Manager Klee (chef vendor) creature template.

fb_cantina_manager = Creature:new {
	customName = "Cantina Manager Klee (FB Food & Drink)",
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
	-- Devaronian chef trainer — perfect bartender/chef look.
	templates = {"object/mobile/dressed_chef_trainer_devaronian_male_01.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbCantinaManagerConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_cantina_manager, "fb_cantina_manager")
