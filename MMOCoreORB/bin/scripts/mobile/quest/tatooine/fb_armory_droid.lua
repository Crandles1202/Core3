-- fb_armory_droid.lua
-- Creature template for FB-72, the armory droid that sells basic weapons.
-- Phase 2.0 MVP — sister NPC to FB-21 medical droid, part of the FB-network.
--
-- Install path: MMOCoreORB/bin/scripts/mobile/quest/tasks/fb_armory_droid.lua
-- Register in: mobile/quest/serverobjects.lua

fb_armory_droid = Creature:new {
	customName = "FB-72 (Armory Droid)",
	socialGroup = "townsperson",
	faction = "",
	level = 1,
	fireBreathChance = 0,
	ferocity = 0,
	pvpBitmask = NONE,
	creatureBitmask = NONE,

	-- INVULNERABLE + CONVERSABLE: can't be attacked, has conversation interaction.
	optionsBitmask = INVULNERABLE + CONVERSABLE,
	diet = HERBIVORE,

	-- Droid appearance. 3PO protocol droid — canonical merchant/service look,
	-- visually distinct from FB-21's 21B surgical droid. Other verified options
	-- if you want to swap: object/mobile/battle_droid.iff (militaristic),
	-- object/mobile/le_repair_droid.iff (utility), object/mobile/eg6_power_droid.iff.
	templates = {"object/mobile/3po_protocol_droid.iff"},

	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbArmoryDroidConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_armory_droid, "fb_armory_droid")
