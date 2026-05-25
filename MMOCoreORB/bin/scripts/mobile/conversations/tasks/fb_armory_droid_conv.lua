-- fb_armory_droid_conv.lua
-- Conversation template for FB-72 (Armory Droid). Sells basic starter weapons.
--
-- Player flow:
--   intro -> "I'd like to buy a weapon"   -> do_buy   (opens SUI listbox via handler)
--   intro -> "What do you have in stock?" -> do_price_list
--   intro -> "Just looking around"        -> do_decline
--
-- Install path: MMOCoreORB/bin/scripts/mobile/conversations/tasks/fb_armory_droid_conv.lua
-- Register in: mobile/conversations.lua

fbArmoryDroidConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbArmoryDroidConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Welcome to the FB Armory. I am FB-72, your starter weapons supplier. We carry basic-grade armaments for new recruits and casual travelers. For higher-quality equipment, please consult a licensed weaponsmith in the bazaar.",
	stopConversation = "false",
	options = {
		{"I'd like to buy a weapon.",          "do_buy"},
		{"What do you have in stock?",         "do_price_list"},
		{"Just looking around. Thank you.",    "do_decline"},
	}
}
fbArmoryDroidConvoTemplate:addScreen(intro)

-- Opens the SUI buy list. customDialogText shows briefly before the SUI pops.
do_buy = ConvoScreen:new {
	id = "do_buy",
	customDialogText = "Accessing inventory catalogue. Please make your selection.",
	stopConversation = "true",
	options = {}
}
fbArmoryDroidConvoTemplate:addScreen(do_buy)

-- Plain-text price list for players who want to read before opening the buy UI.
do_price_list = ConvoScreen:new {
	id = "do_price_list",
	customDialogText = "Current stock: Vibroblade (500cr), Vibroaxe (800cr), Vibrolance (1000cr), CDEF Pistol (600cr), CDEF Carbine (1200cr), CDEF Rifle (1500cr). All weapons are factory-standard. For combat-grade equipment, see a weaponsmith.",
	stopConversation = "false",
	options = {
		{"I'd like to buy one.",          "do_buy"},
		{"Just looking around.",          "do_decline"},
	}
}
fbArmoryDroidConvoTemplate:addScreen(do_price_list)

do_decline = ConvoScreen:new {
	id = "do_decline",
	customDialogText = "Understood. Return whenever you require basic armaments.",
	stopConversation = "true",
	options = {}
}
fbArmoryDroidConvoTemplate:addScreen(do_decline)

addConversationTemplate("fbArmoryDroidConvoTemplate", fbArmoryDroidConvoTemplate)
