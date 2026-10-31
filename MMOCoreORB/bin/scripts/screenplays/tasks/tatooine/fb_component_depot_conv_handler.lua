-- fb_component_depot_conv_handler.lua — Final Boss 2.15.
local ObjectManager = require("managers.object.object_manager")
fbComponentDepotConvoHandler = conv_handler:new {}
function fbComponentDepotConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	if screen:getScreenID() == "do_list" then
		FbComponentDepot:showList(pPlayer, pNpc)
	end
	return pConvScreen
end
