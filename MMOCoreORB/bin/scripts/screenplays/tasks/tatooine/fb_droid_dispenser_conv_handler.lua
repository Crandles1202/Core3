-- fb_droid_dispenser_conv_handler.lua
local ObjectManager = require("managers.object.object_manager")

fbDroidDispenserConvoHandler = conv_handler:new {}

function fbDroidDispenserConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()
	if screenID == "do_buy" then
		FbDroidDispenser:showCategoryList(pPlayer, pNpc)
		return pConvScreen
	end
	return pConvScreen
end
