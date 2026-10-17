-- fb_schematic_broker_conv_handler.lua — Phase 2.2 schematic broker conversation handler.
local ObjectManager = require("managers.object.object_manager")

fbSchematicBrokerConvoHandler = conv_handler:new {}

function fbSchematicBrokerConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()

	if screenID == "do_catalogue" then
		FbSchematicBroker:showCatalogue(pPlayer, pNpc)
	end

	return pConvScreen
end
