-- fb_traveling_merchant_conv_handler.lua — Phase 2.9 traveling merchant conversation handler.
local ObjectManager = require("managers.object.object_manager")

fbTravelingMerchantConvoHandler = conv_handler:new {}

function fbTravelingMerchantConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()

	if screenID == "do_stock" then
		FbTravelingMerchant:showStock(pPlayer, pNpc)
	end

	return pConvScreen
end
