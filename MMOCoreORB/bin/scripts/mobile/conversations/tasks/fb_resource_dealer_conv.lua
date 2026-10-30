-- fb_resource_dealer_conv.lua — Final Boss 2.14: Mehra Tulk, raw resource dealer. intro -> "Show me the resources." -> do_list (opens the window).
fbResourceDealerConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbResourceDealerConvoHandler",
	screens = {}
}
intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Mehra Tulk, raw materials. Every resource in shift on the ten worlds, by the thousand units, no harvester needed. Pick a family and I will show you what is in the ground this week.",
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
	customDialogText = "Here is what is in shift. Mind the stats: the best of each class is at the top.",
	stopConversation = "true",
	options = {}
}
fbResourceDealerConvoTemplate:addScreen(do_list)
do_explain = ConvoScreen:new {
	id = "do_explain",
	customDialogText = "Resources come and go in shifts of a few days. I list every spawn currently in the ground across the ten worlds, grouped by family, best first. You pay by the unit and the stack lands in your inventory, the same as a harvester hopper would give you. When a spawn leaves the ground it leaves my list.",
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
