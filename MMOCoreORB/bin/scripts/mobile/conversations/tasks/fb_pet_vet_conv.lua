-- fb_pet_vet_conv.lua

fbPetVetConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbPetVetConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Welcome to FB Veterinary Supply. Doctor Yan'lara at your service — I stock basic medical supplies for tamed creatures and droid pets: stim packs and vitapacks. A licensed Bio-Engineer will produce more potent kits, but I'll get your companion through a rough day.",
	stopConversation = "false",
	options = {
		{"Show me your supplies.",      "do_buy"},
		{"What do you carry?",          "do_price_list"},
		{"Just looking. Thanks.",       "do_decline"},
	}
}
fbPetVetConvoTemplate:addScreen(intro)

do_buy = ConvoScreen:new {
	id = "do_buy",
	customDialogText = "Right here, take a look.",
	stopConversation = "true",
	options = {}
}
fbPetVetConvoTemplate:addScreen(do_buy)

do_price_list = ConvoScreen:new {
	id = "do_price_list",
	customDialogText = "Stock: Pet Stim Pack A (75cr), Pet Stim Pack B (150cr), Pet Vitapack A (75cr), Pet Vitapack B (150cr). For higher tiers see a Bio-Engineer.",
	stopConversation = "false",
	options = {
		{"Show me the supplies.",  "do_buy"},
		{"Just looking.",          "do_decline"},
	}
}
fbPetVetConvoTemplate:addScreen(do_price_list)

do_decline = ConvoScreen:new {
	id = "do_decline",
	customDialogText = "Take care of your companion out there.",
	stopConversation = "true",
	options = {}
}
fbPetVetConvoTemplate:addScreen(do_decline)

addConversationTemplate("fbPetVetConvoTemplate", fbPetVetConvoTemplate)
