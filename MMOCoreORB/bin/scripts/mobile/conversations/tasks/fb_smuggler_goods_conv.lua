-- fb_smuggler_goods_conv.lua

fbSmugglerGoodsConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbSmugglerGoodsConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Hsss. You looking for something the regular shops don't carry? Greelo can help. Slicing kits, spice, things to make your equipment... better. No questions asked, no paperwork. Just credits.",
	stopConversation = "false",
	options = {
		{"Show me your wares.",         "do_buy"},
		{"What do you have?",           "do_price_list"},
		{"Forget I asked.",             "do_decline"},
	}
}
fbSmugglerGoodsConvoTemplate:addScreen(intro)

do_buy = ConvoScreen:new {
	id = "do_buy",
	customDialogText = "Heh, smart customer. Take a look.",
	stopConversation = "true",
	options = {}
}
fbSmugglerGoodsConvoTemplate:addScreen(do_buy)

do_price_list = ConvoScreen:new {
	id = "do_price_list",
	customDialogText = "Slicing kits: Laser Knife (300cr), Flow Analyzer (400cr), Molecular Clamp (500cr), Armor Upgrade Kit (1000cr). Spice: Booster Blue (200cr), Giggledust (250cr), Droid Lube (200cr). All cash. No refunds.",
	stopConversation = "false",
	options = {
		{"Show me the wares.",   "do_buy"},
		{"Forget I asked.",      "do_decline"},
	}
}
fbSmugglerGoodsConvoTemplate:addScreen(do_price_list)

do_decline = ConvoScreen:new {
	id = "do_decline",
	customDialogText = "Hssss. Yeah. You never saw me.",
	stopConversation = "true",
	options = {}
}
fbSmugglerGoodsConvoTemplate:addScreen(do_decline)

addConversationTemplate("fbSmugglerGoodsConvoTemplate", fbSmugglerGoodsConvoTemplate)
