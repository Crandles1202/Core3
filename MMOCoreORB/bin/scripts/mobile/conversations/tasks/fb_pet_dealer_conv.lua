-- fb_pet_dealer_conv.lua  — Handler Toobu conversation template.

fbPetDealerConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbPetDealerConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Hsst. Handler Toobu here. I broker tameable beasts of every variety — runt-of-the-litter to apex predators. The deeds I sell instantiate the creature when you use them. Higher-quality specimens come from licensed Bio-Engineers; what I carry is field-stock.",
	stopConversation = "false",
	options = {
		{"Show me your stock.",   "do_buy"},
		{"Just looking. Thanks.", "do_decline"},
	}
}
fbPetDealerConvoTemplate:addScreen(intro)

do_buy = ConvoScreen:new { id = "do_buy", customDialogText = "Right. Let me show you the registry.", stopConversation = "true", options = {} }
fbPetDealerConvoTemplate:addScreen(do_buy)

do_decline = ConvoScreen:new { id = "do_decline", customDialogText = "Hssss. Come back when you want a companion.", stopConversation = "true", options = {} }
fbPetDealerConvoTemplate:addScreen(do_decline)

addConversationTemplate("fbPetDealerConvoTemplate", fbPetDealerConvoTemplate)
