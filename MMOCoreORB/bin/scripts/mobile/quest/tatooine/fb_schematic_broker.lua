-- fb_schematic_broker.lua — Phase 2.2 schematic broker mobile template.
fb_schematic_broker = Creature:new {
	customName = "Dannik Vosa (Schematic Broker)",
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
	-- merchant look: the working-crafter's contact, not a back-alley type
	templates = {"object/mobile/dressed_merchant_trainer_01.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbSchematicBrokerConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_schematic_broker, "fb_schematic_broker")
