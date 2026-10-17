-- fb_smuggler_goods.lua — Greelo creature template (smuggler goods).

fb_smuggler_goods = Creature:new {
	customName = "Greelo (Independent Merchant)",
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

	-- Cobral thug — Rodian criminal look, perfect for back-alley smuggler.
	-- Note: faction is empty but the model has a slightly hostile look; that
	-- fits "independent" / "not exactly legitimate" vibe.
	templates = {"object/mobile/dressed_cobral_thug_rodian_male_01.iff"},

	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbSmugglerGoodsConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_smuggler_goods, "fb_smuggler_goods")
