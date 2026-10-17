-- fb_parts_dealer.lua — Phase 2.3 parts dealer mobile template.
fb_parts_dealer = Creature:new {
	customName = "Tamsin Rook (Parts Dealer)",
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
	-- artisan look: the crafter's supplier
	templates = {"object/mobile/dressed_artisan_trainer_01.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbPartsDealerConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_parts_dealer, "fb_parts_dealer")
