-- fb_vehicle_dealer_conv_handler.lua — Final Boss 2.13.
local ObjectManager = require("managers.object.object_manager")
fbVehicleDealerConvoHandler = conv_handler:new {}
function fbVehicleDealerConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	if screen:getScreenID() == "do_list" then
		FbVehicleDealer:showList(pPlayer, pNpc)
	end
	return pConvScreen
end
