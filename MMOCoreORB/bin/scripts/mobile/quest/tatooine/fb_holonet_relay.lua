-- fb_holonet_relay.lua — Phase 3.10 HoloNet relay droid mobile template.
fb_holonet_relay = Creature:new {
	customName = "HN-7 (HoloNet Relay)",
	socialGroup = "townsperson",
	mobType = MOB_DROID,
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
	templates = {"object/mobile/3po_protocol_droid_silver.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbHolonetRelayConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_holonet_relay, "fb_holonet_relay")
