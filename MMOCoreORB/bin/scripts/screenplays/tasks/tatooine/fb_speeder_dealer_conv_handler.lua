-- fb_speeder_dealer_conv_handler.lua
local ObjectManager = require("managers.object.object_manager")

fbSpeederDealerConvoHandler = conv_handler:new {}

function fbSpeederDealerConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()
	if screenID == "do_buy" then
		FbSpeederDealer:showCategoryList(pPlayer, pNpc)
		return pConvScreen
	end
	return pConvScreen
end
