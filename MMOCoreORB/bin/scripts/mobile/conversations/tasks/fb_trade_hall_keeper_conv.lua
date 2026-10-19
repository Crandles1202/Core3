-- fb_trade_hall_keeper_conv.lua — the Trade Hall doorman (Phase 2.11)

fbTradeHallKeeperConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbTradeHallKeeperConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Looking for the traders? They're out of the sun now. The Mos Eisley Trade Hall is the big commerce house south-east of this square, down past the bank. Armour, weapons, medicine, parts, schematics, pets, property, droids — all under one roof.",
	stopConversation = "false",
	options = {
		{"Mark it on my map.",        "do_waypoint"},
		{"Who trades there?",         "do_tenants"},
		{"Thanks, I'll find it.",     "do_bye"},
	}
}
fbTradeHallKeeperConvoTemplate:addScreen(intro)

do_waypoint = ConvoScreen:new {
	id = "do_waypoint",
	customDialogText = "There. Follow the marker to the doors; the keepers inside will see to you.",
	stopConversation = "true",
	options = {}
}
fbTradeHallKeeperConvoTemplate:addScreen(do_waypoint)

do_tenants = ConvoScreen:new {
	id = "do_tenants",
	customDialogText = "%TT",   -- filled by the handler from the live tenant list
	stopConversation = "false",
	options = {
		{"Mark it on my map.",        "do_waypoint"},
		{"Thanks.",                   "do_bye"},
	}
}
fbTradeHallKeeperConvoTemplate:addScreen(do_tenants)

do_bye = ConvoScreen:new {
	id = "do_bye",
	customDialogText = "Mind the Jawas on the way.",
	stopConversation = "true",
	options = {}
}
fbTradeHallKeeperConvoTemplate:addScreen(do_bye)

addConversationTemplate("fbTradeHallKeeperConvoTemplate", fbTradeHallKeeperConvoTemplate)
