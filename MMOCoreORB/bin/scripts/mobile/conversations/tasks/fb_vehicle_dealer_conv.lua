-- fb_vehicle_dealer_conv.lua — Final Boss 2.13: Rook Valdane, vehicle dealer. intro -> "Show me the vehicles." -> do_list (opens the window).
fbVehicleDealerConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbVehicleDealerConvoHandler",
	screens = {}
}
intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Rook Valdane. Speeders, swoops, a jetpack if your credit is good. Every deed is new in the crate: call it from your datapad and it is yours.",
	stopConversation = "false",
	options = {
		{"Show me the vehicles.", "do_list"},
		{"What should I ride?", "do_explain"},
		{"Just looking, thanks.", "do_decline"},
	}
}
fbVehicleDealerConvoTemplate:addScreen(intro)
do_list = ConvoScreen:new {
	id = "do_list",
	customDialogText = "Have a look. Cash only, and mind the throttle on the swoop.",
	stopConversation = "true",
	options = {}
}
fbVehicleDealerConvoTemplate:addScreen(do_list)
do_explain = ConvoScreen:new {
	id = "do_explain",
	customDialogText = "A speederbike gets you across the dunes. The swoop and the flash are quicker and turn tighter. The X-34 is the family landspeeder, the AV-21 the one people stare at. The jetpack is for those who have stopped counting credits.",
	stopConversation = "false",
	options = {
		{"Show me the vehicles.", "do_list"},
		{"Just looking, thanks.", "do_decline"},
	}
}
fbVehicleDealerConvoTemplate:addScreen(do_explain)
do_decline = ConvoScreen:new {
	id = "do_decline",
	customDialogText = "Keep the sand out of the intake.",
	stopConversation = "true",
	options = {}
}
fbVehicleDealerConvoTemplate:addScreen(do_decline)
addConversationTemplate("fbVehicleDealerConvoTemplate", fbVehicleDealerConvoTemplate)
