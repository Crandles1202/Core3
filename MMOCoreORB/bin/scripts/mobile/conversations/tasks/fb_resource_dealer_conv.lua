-- fb_resource_dealer_conv.lua — Final Boss 2.14: Mehra Tulk, raw resource dealer. intro -> "Show me the resources." -> do_list (opens the window).
fbResourceDealerConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbResourceDealerConvoHandler",
	screens = {}
}
intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Mehra Tulk, raw materials. Every kind of resource there is, by the thousand units, no harvester needed: the best vein ever seen of each, and if nobody has seen one yet I put the word out and it is found. Pick a family.",
	stopConversation = "false",
	options = {
		{"Show me the resources.", "do_list"},
		{"How does this work?", "do_explain"},
		{"Just looking, thanks.", "do_decline"},
	}
}
fbResourceDealerConvoTemplate:addScreen(intro)
do_list = ConvoScreen:new {
	id = "do_list",
	customDialogText = "Here is the ledger. Mind the quality: it is the best of each kind I have ever seen.",
	stopConversation = "true",
	options = {}
}
fbResourceDealerConvoTemplate:addScreen(do_list)
do_explain = ConvoScreen:new {
	id = "do_explain",
	customDialogText = "Resources come and go in shifts of a few days, but a vein that has been seen once can always be dug again. I keep the best of every kind I have ever seen, and a kind nobody has seen yet I have found for you on the spot — it goes into the ground somewhere, so the surveyors will find it too. You pay by the unit and the stack lands in your inventory, the same as a harvester hopper would give you.",
	stopConversation = "false",
	options = {
		{"Show me the resources.", "do_list"},
		{"Just looking, thanks.", "do_decline"},
	}
}
fbResourceDealerConvoTemplate:addScreen(do_explain)
do_decline = ConvoScreen:new {
	id = "do_decline",
	customDialogText = "Come back when the shift turns.",
	stopConversation = "true",
	options = {}
}
fbResourceDealerConvoTemplate:addScreen(do_decline)
addConversationTemplate("fbResourceDealerConvoTemplate", fbResourceDealerConvoTemplate)
