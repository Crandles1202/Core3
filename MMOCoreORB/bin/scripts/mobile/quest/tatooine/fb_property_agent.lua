-- fb_property_agent.lua — Property Agent Garlen (building deeds vendor) mobile.

fb_property_agent = Creature:new {
	customName = "Property Agent Garlen (FB Real Estate)",
	socialGroup = "townsperson",
	faction = "",
	level = 1,
	pvpBitmask = NONE,
	creatureBitmask = NONE,
	optionsBitmask = INVULNERABLE + CONVERSABLE,
	diet = HERBIVORE,
	-- Architect trainer model — sells what they would build.
	templates = {"object/mobile/dressed_architect_trainer_01.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbPropertyAgentConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_property_agent, "fb_property_agent")
