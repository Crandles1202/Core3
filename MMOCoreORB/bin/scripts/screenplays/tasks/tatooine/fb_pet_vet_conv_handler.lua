-- fb_pet_vet_conv_handler.lua
local ObjectManager = require("managers.object.object_manager")

fbPetVetConvoHandler = conv_handler:new {}

function fbPetVetConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()

	if screenID == "do_buy" then
		FbPetVet:showPetMedList(pPlayer, pNpc)
		return pConvScreen
	end

	return pConvScreen
end
