-- fb_droid_dispenser.lua — FB-3D droid vendor creature template.

fb_droid_dispenser = Creature:new {
	customName = "FB-3D (Droid Dispenser)",
	socialGroup = "townsperson",
	faction = "",
	level = 1,
	pvpBitmask = NONE,
	creatureBitmask = NONE,
	optionsBitmask = INVULNERABLE + CONVERSABLE,
	diet = HERBIVORE,
	-- Human Droid Engineer trainer model — fits "I sell droids" theme.
	templates = {"object/mobile/dressed_droidengineer_trainer_human_male_01.iff"},
	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbDroidDispenserConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_droid_dispenser, "fb_droid_dispenser")
