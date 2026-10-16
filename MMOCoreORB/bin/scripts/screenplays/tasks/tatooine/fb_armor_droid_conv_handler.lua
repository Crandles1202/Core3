-- fb_armor_droid_conv_handler.lua
-- Install:  screenplays/tasks/tatooine/fb_armor_droid_conv_handler.lua
-- Register: includeFile("tasks/tatooine/fb_armor_droid_conv_handler.lua")

local ObjectManager = require("managers.object.object_manager")

fbArmorDroidConvoHandler = conv_handler:new {}

function fbArmorDroidConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()

	if screenID == "do_buy" then
		-- Two-step UX: open category picker first; selecting a category
		-- opens a focused SUI with that category's pieces. Big inventory
		-- (20+ armor types) makes a flat list unworkable.
		FbArmorDroid:showCategoryList(pPlayer, pNpc)
		return pConvScreen
	end

	return pConvScreen
end
