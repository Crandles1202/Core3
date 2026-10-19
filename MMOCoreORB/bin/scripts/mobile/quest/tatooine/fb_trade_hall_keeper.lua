-- fb_trade_hall_keeper.lua — Hallkeeper Jyn Odaro, the Mos Eisley Trade Hall's doorman (Phase 2.11).
-- Stands where the vendor row used to be and points people at the hall.

fb_trade_hall_keeper = Creature:new {
	customName = "Hallkeeper Jyn Odaro (Mos Eisley Trade Hall)",
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

	templates = {"object/mobile/dressed_commoner_tatooine_ishitib_male_01.iff"},   -- a stock Mos Eisley commoner model (the human_male_01 variant does not exist)

	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbTradeHallKeeperConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_trade_hall_keeper, "fb_trade_hall_keeper")
