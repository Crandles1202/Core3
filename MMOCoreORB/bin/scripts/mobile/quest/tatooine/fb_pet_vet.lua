-- fb_pet_vet.lua — Doctor Yan'lara creature template (pet medical supplier).

fb_pet_vet = Creature:new {
	customName = "Doctor Yan'lara (FB Veterinary Supply)",
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

	-- Creature handler trainer model — fits the veterinary look.
	templates = {"object/mobile/dressed_creaturehandler_trainer_human_male_01.iff"},

	lootGroups = {},
	weapons = {},
	conversationTemplate = "fbPetVetConvoTemplate",
	attacks = {}
}

CreatureTemplates:addCreatureTemplate(fb_pet_vet, "fb_pet_vet")
