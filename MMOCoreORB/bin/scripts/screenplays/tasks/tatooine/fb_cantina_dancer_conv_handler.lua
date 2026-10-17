-- fb_cantina_dancer_conv_handler.lua
local ObjectManager = require("managers.object.object_manager")

fbCantinaDancerConvoHandler = conv_handler:new {}

function fbCantinaDancerConvoHandler:getInitialScreen(pPlayer, pNpc, pConvTemplate)
	local convoTemplate = LuaConversationTemplate(pConvTemplate)
	if CreatureObject(pPlayer):isInCombat() then
		return convoTemplate:getScreen("do_in_combat")
	end
	return convoTemplate:getScreen("intro")
end

function fbCantinaDancerConvoHandler:clearBattleFatigue(pPlayer)
	if pPlayer == nil then return end
	-- ShockWounds == Battle Fatigue. Clearing it lets future buffs land cleanly.
	CreatureObject(pPlayer):setShockWounds(0)
end

function fbCantinaDancerConvoHandler:applyBuffs(pPlayer)
	if pPlayer == nil then return end
	-- enhanceCharacter applies the full 9-buff package (6 Doctor + 3 Entertainer).
	-- Pre-CU lore-correct would be Entertainer-only, but Core3 ships a single
	-- combined helper; splitting requires a C++ change. The dancer giving
	-- "Doctor too" reads as "the cantina is also fully staffed" — fine for a
	-- low-pop server. We can split later if we add a dedicated C++ helper.
	CreatureObject(pPlayer):enhanceCharacter()
end

function fbCantinaDancerConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()

	if CreatureObject(pPlayer):isInCombat() then
		local convoTemplate = LuaConversationTemplate(pConvTemplate)
		return convoTemplate:getScreen("do_in_combat")
	end

	if screenID == "do_watch" then
		self:clearBattleFatigue(pPlayer)
		self:applyBuffs(pPlayer)
		return pConvScreen
	elseif screenID == "do_clear_bf" then
		self:clearBattleFatigue(pPlayer)
		return pConvScreen
	end

	return pConvScreen
end
