-- fb_armor_droid_conv.lua
-- Install:  mobile/conversations/tasks/fb_armor_droid_conv.lua
-- Register: includeFile("conversations/tasks/fb_armor_droid_conv.lua")

fbArmorDroidConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbArmorDroidConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Greetings. I am FB-44, armor fitting unit. The FB network stocks factory-standard padded armor pieces — adequate protection against low-level threats. Licensed armorsmiths produce superior equipment for serious combat.",
	stopConversation = "false",
	options = {
		{"Show me your armor catalogue.",  "do_buy"},
		{"What's in stock?",               "do_price_list"},
		{"Just looking. Thanks.",          "do_decline"},
	}
}
fbArmorDroidConvoTemplate:addScreen(intro)

do_buy = ConvoScreen:new {
	id = "do_buy",
	customDialogText = "Catalogue loading. Please make your selection.",
	stopConversation = "true",
	options = {}
}
fbArmorDroidConvoTemplate:addScreen(do_buy)

do_price_list = ConvoScreen:new {
	id = "do_price_list",
	customDialogText = "I carry pieces from 20 armor lines — civilian and faction. Bone, Bounty Hunter, Chitin, Composite, Ithorian (3 lines), Kashyyykian (3 lines), Mandalorian, Marauder (3 series), Marine, Padded, RIS, Singing Mountain, Stormtrooper, Tantel, Ubese, Zam Wesell, plus a Nightsister fragment. Each armor line has multiple pieces. Select 'Show me your armor catalogue' to browse.",
	stopConversation = "false",
	options = {
		{"Show me the catalogue.",  "do_buy"},
		{"Just looking.",           "do_decline"},
	}
}
fbArmorDroidConvoTemplate:addScreen(do_price_list)

do_decline = ConvoScreen:new {
	id = "do_decline",
	customDialogText = "Acknowledged. Return when you require armor.",
	stopConversation = "true",
	options = {}
}
fbArmorDroidConvoTemplate:addScreen(do_decline)

addConversationTemplate("fbArmorDroidConvoTemplate", fbArmorDroidConvoTemplate)
