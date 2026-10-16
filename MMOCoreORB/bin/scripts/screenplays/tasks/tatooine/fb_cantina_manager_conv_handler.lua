-- fb_cantina_manager_conv_handler.lua
local ObjectManager = require("managers.object.object_manager")

fbCantinaManagerConvoHandler = conv_handler:new {}

function fbCantinaManagerConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()
	if screenID == "do_buy" then
		FbCantinaManager:showCategoryList(pPlayer, pNpc)
		return pConvScreen
	end
	return pConvScreen
end
