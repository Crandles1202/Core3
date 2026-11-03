-- fb_food_vendor_conv_handler.lua — Final Boss 2.16.
local ObjectManager = require("managers.object.object_manager")
fbFoodVendorConvoHandler = conv_handler:new {}
function fbFoodVendorConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	if screen:getScreenID() == "do_list" then
		FbFoodVendor:showList(pPlayer, pNpc)
	end
	return pConvScreen
end
