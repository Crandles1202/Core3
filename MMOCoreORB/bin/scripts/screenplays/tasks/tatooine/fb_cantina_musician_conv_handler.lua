-- fb_cantina_musician_conv_handler.lua
local ObjectManager = require("managers.object.object_manager")

fbCantinaMusicianConvoHandler = conv_handler:new {}

function fbCantinaMusicianConvoHandler:getInitialScreen(pPlayer, pNpc, pConvTemplate)
	local convoTemplate = LuaConversationTemplate(pConvTemplate)
	if CreatureObject(pPlayer):isInCombat() then
		return convoTemplate:getScreen("do_in_combat")
	end
	return convoTemplate:getScreen("intro")
end

function fbCantinaMusicianConvoHandler:clearBattleFatigue(pPlayer)
	if pPlayer == nil then return end
	CreatureObject(pPlayer):setShockWounds(0)
end

function fbCantinaMusicianConvoHandler:applyBuffs(pPlayer)
	if pPlayer == nil then return end
	CreatureObject(pPlayer):enhanceCharacter()
end

function fbCantinaMusicianConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()

	if CreatureObject(pPlayer):isInCombat() then
		local convoTemplate = LuaConversationTemplate(pConvTemplate)
		return convoTemplate:getScreen("do_in_combat")
	end

	if screenID == "do_listen" then
		self:clearBattleFatigue(pPlayer)
		self:applyBuffs(pPlayer)
		return pConvScreen
	elseif screenID == "do_clear_bf" then
		self:clearBattleFatigue(pPlayer)
		return pConvScreen
	end

	return pConvScreen
end
