-- fb_resource_dealer_conv_handler.lua — Final Boss 2.14.
local ObjectManager = require("managers.object.object_manager")
fbResourceDealerConvoHandler = conv_handler:new {}
function fbResourceDealerConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	if screen:getScreenID() == "do_list" then
		FbResourceDealer:showList(pPlayer, pNpc)
	end
	return pConvScreen
end
