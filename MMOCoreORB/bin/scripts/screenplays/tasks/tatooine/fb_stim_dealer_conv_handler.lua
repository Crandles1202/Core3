-- fb_stim_dealer_conv_handler.lua
-- Conversation handler for Vex Renn the stim dealer.
--
-- Identical pattern to FB-72: detect the "do_buy" screenID and hand off to
-- the screenplay's showStimList() function which sends a SUI listbox.
-- The purchaseStimCallback in the screenplay handles the actual transaction.
--
-- Install path: MMOCoreORB/bin/scripts/screenplays/tasks/tatooine/fb_stim_dealer_conv_handler.lua
-- Register in:  screenplays/screenplays.lua as
--               includeFile("tasks/tatooine/fb_stim_dealer_conv_handler.lua")

local ObjectManager = require("managers.object.object_manager")

fbStimDealerConvoHandler = conv_handler:new {}

function fbStimDealerConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()

	-- Buy branch: open SUI listbox via the screenplay
	if screenID == "do_buy" then
		FbStimDealer:showStimList(pPlayer, pNpc)
		return pConvScreen
	end

	-- Other screens (do_price_list, do_decline) are pure dialog
	return pConvScreen
end
