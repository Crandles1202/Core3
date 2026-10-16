-- fb_pet_dealer_conv_handler.lua
local ObjectManager = require("managers.object.object_manager")

fbPetDealerConvoHandler = conv_handler:new {}

function fbPetDealerConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()
	if screenID == "do_buy" then
		FbPetDealer:showCategoryList(pPlayer, pNpc)
		return pConvScreen
	end
	return pConvScreen
end
