-- fb_stim_dealer_conv.lua
-- Conversation template for Vex Renn (FB Medical Supplier).
--
-- Player flow:
--   intro -> "I'd like to buy medical supplies" -> do_buy   (opens SUI listbox)
--   intro -> "What do you have in stock?"       -> do_price_list
--   intro -> "Just looking around"              -> do_decline
--
-- Install path: MMOCoreORB/bin/scripts/mobile/conversations/tasks/fb_stim_dealer_conv.lua
-- Register in:  mobile/conversations.lua  as
--               includeFile("conversations/tasks/fb_stim_dealer_conv.lua")

fbStimDealerConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbStimDealerConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Welcome, traveler. Vex Renn here, FB Medical Supply network. I carry the basics — stim packs, wound treatments, disease and poison cures, emergency revival kits. For higher-grade pharmaceuticals you'll want a licensed doctor or chemist. What can I get for you?",
	stopConversation = "false",
	options = {
		{"I'd like to buy medical supplies.",     "do_buy"},
		{"What do you have in stock?",            "do_price_list"},
		{"Just looking. Thanks.",                 "do_decline"},
	}
}
fbStimDealerConvoTemplate:addScreen(intro)

do_buy = ConvoScreen:new {
	id = "do_buy",
	customDialogText = "Sure thing. One moment while I pull up the catalogue.",
	stopConversation = "true",
	options = {}
}
fbStimDealerConvoTemplate:addScreen(do_buy)

do_price_list = ConvoScreen:new {
	id = "do_price_list",
	customDialogText = "Current stock: Basic Stim Pack (50cr), Basic Wound Pack (100cr), Disease Cure Pack (150cr), Poison Cure Pack (150cr), Revival Pack (500cr). All starter-grade — a real doctor's work is going to be miles better, but this'll keep you alive in a pinch.",
	stopConversation = "false",
	options = {
		{"I'd like to buy something.",            "do_buy"},
		{"Just looking. Thanks.",                 "do_decline"},
	}
}
fbStimDealerConvoTemplate:addScreen(do_price_list)

do_decline = ConvoScreen:new {
	id = "do_decline",
	customDialogText = "Take care out there. Come back if you need patching up.",
	stopConversation = "true",
	options = {}
}
fbStimDealerConvoTemplate:addScreen(do_decline)

addConversationTemplate("fbStimDealerConvoTemplate", fbStimDealerConvoTemplate)
