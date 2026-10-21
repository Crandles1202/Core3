-- fb_trials_conv_handlers.lua — the Padawan trials' conversations (Phase 4a.3): the prisoner (trial four) and the
-- spirit (riddle, sacrifice). The NPCs are spawned per player by FbTrialPrisoner / FbTrialSpirit
-- (custom_scripts/screenplays/fb_trials.lua) and only talk to the character they came for.

fbPrisonerConvoHandler = conv_handler:new {}

function fbPrisonerConvoHandler:getInitialScreen(pPlayer, pNpc, pConvTemplate)
	local convoTemplate = LuaConversationTemplate(pConvTemplate)
	if FbTrialPrisoner ~= nil and FbTrialPrisoner:belongsTo(pPlayer, pNpc) then
		return convoTemplate:getScreen("plea")
	end
	if FbTrialPrisoner ~= nil then FbTrialPrisoner:explain(pPlayer, pNpc) end
	return convoTemplate:getScreen("nothing")
end

function fbPrisonerConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()
	if screenID == "free" then
		FbTrials:choose(pPlayer, "light")
		CreatureObject(pNpc):clearOptionBit(CONVERSABLE)
		FbTrialPrisoner:runOff(pPlayer, pNpc)
	elseif screenID == "kill" then
		FbTrials:choose(pPlayer, "dark")
		CreatureObject(pNpc):clearOptionBit(CONVERSABLE)
		FbTrialPrisoner:execute(pPlayer, pNpc)
	end
	return pConvScreen
end

fbTrialSpiritConvoHandler = conv_handler:new {}

function fbTrialSpiritConvoHandler:getInitialScreen(pPlayer, pNpc, pConvTemplate)
	local convoTemplate = LuaConversationTemplate(pConvTemplate)
	if FbTrialSpirit ~= nil and FbTrialSpirit:belongsTo(pPlayer, pNpc) then
		local current = FbTrials:current(pPlayer)
		if current == "insight" then return convoTemplate:getScreen("riddle_" .. FbTrials:riddleOf(pPlayer)) end
		if current == "sacrifice" then return convoTemplate:getScreen("sacrifice") end
	end
	if FbTrialSpirit ~= nil and FbTrialSpirit.explain ~= nil then FbTrialSpirit:explain(pPlayer, pNpc) end
	return convoTemplate:getScreen("nothing")
end

function fbTrialSpiritConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()
	if screenID == "right" then
		FbTrials:complete(pPlayer, "insight")
		CreatureObject(pNpc):clearOptionBit(CONVERSABLE)
		FbTrialSpirit:scheduleDespawn(pPlayer)
	elseif screenID == "wrong" then
		CreatureObject(pPlayer):sendSystemMessage("@fb_force:trial_insight_wrong")
		CreatureObject(pNpc):clearOptionBit(CONVERSABLE)
		FbTrialSpirit:scheduleDespawn(pPlayer)
	elseif screenID == "give" then
		if FbTrials:takeCredits(pPlayer) then
			FbTrials:complete(pPlayer, "sacrifice")
		else
			CreatureObject(pPlayer):sendSystemMessage("@fb_force:trial_sacrifice_short")
		end
		CreatureObject(pNpc):clearOptionBit(CONVERSABLE)
		FbTrialSpirit:scheduleDespawn(pPlayer)
	elseif screenID == "keep" then
		CreatureObject(pNpc):clearOptionBit(CONVERSABLE)
		FbTrialSpirit:scheduleDespawn(pPlayer)
	end
	return pConvScreen
end
