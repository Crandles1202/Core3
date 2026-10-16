-- fb_property_agent_conv_handler.lua
local ObjectManager = require("managers.object.object_manager")

fbPropertyAgentConvoHandler = conv_handler:new {}

function fbPropertyAgentConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()
	if screenID == "do_buy" then
		FbPropertyAgent:showCategoryList(pPlayer, pNpc)
		return pConvScreen
	end
	return pConvScreen
end
