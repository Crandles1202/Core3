-- fb_cantina_dancer.lua — Twi'lek cantina dancer creature template.

fb_cantina_dancer = Creature:new {
	customName = "Oola Var (Cantina Dancer)",
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
	-- Twi'lek dancer trainer — perfect cantina dancer look.
	templates = {"object/mobile/dressed_dancer_trainer_twk_female_01.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbCantinaDancerConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_cantina_dancer, "fb_cantina_dancer")
