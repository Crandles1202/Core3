-- fb_imperial_armorer_conv_handler.lua
local ObjectManager = require("managers.object.object_manager")

fbImperialArmorerConvoHandler = conv_handler:new {}

function fbImperialArmorerConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()
	if screenID == "do_buy" then
		FbImperialArmorer:showCategoryList(pPlayer, pNpc)
		return pConvScreen
	end
	return pConvScreen
end
