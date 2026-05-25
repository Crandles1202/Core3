-- fb_mos_eisley_medical_droid_conv_handler.lua
-- Conversation handler for FB-21 medical droid.
-- Dispatches to buff/wound/travel actions based on which destination screen
-- the player selected.
--
-- Install path: MMOCoreORB/bin/scripts/screenplays/tasks/tatooine/fb_mos_eisley_medical_droid_conv_handler.lua
--
-- Phase 2.6 — Final Boss server custom content.

local ObjectManager = require("managers.object.object_manager")

-- ==== Travel destinations table ====
-- Keys MUST match the destination screenIDs defined in the conversation file.
-- Coordinates mirror those in the screenplay's spawns table.

-- Coordinate semantics mirror the screenplay's spawns table:
--   * cellID nil/absent -> x/z/y are WORLD coords, drops player OUTDOORS
--   * cellID set        -> x/z/y are CELL-LOCAL coords, drops player INSIDE
--                          the cell (ideally right at the destination droid)
local TRAVEL_DESTINATIONS = {
	-- Tatooine
	-- Mos Eisley: INSIDE the medcenter entrance/lobby at the droid (matches spawn entry)
	travel_mos_eisley         = { planet = "tatooine",  x = 12.50, z = 0.18, y = -0.09,  cellID = 9655496 },
	-- Bestine: INSIDE the medcenter (matches spawn entry)
	travel_bestine            = { planet = "tatooine",  x = -12.20, z = 0.18, y = -0.04, cellID = 4005383 },
	-- Mos Espa: INSIDE the medcenter (matches spawn entry)
	travel_mos_espa           = { planet = "tatooine",  x = -12.33, z = 0.18, y = -0.09, cellID = 4005424 },
	-- Mos Entha: INSIDE the medcenter (matches spawn entry)
	travel_mos_entha          = { planet = "tatooine",  x = -24.02, z = 0.26, y = 0.96, cellID = 1153586 },
	-- Anchorhead: INSIDE the medcenter (matches spawn entry)
	travel_anchorhead         = { planet = "tatooine",  x = 1.40,  z = 1.00, y = 5.23, cellID = 1213346 },

	-- Naboo
	-- Theed: INSIDE the medcenter (matches spawn entry)
	travel_theed              = { planet = "naboo",     x = 29.27, z = 0.26, y = 0.02, cellID = 1697360 },
	-- Keren: INSIDE the medcenter (matches spawn entry)
	travel_keren              = { planet = "naboo",     x = 29.31, z = 0.26, y = -0.08, cellID = 1661366 },
	-- Moenia: INSIDE the medcenter (matches spawn entry)
	travel_moenia             = { planet = "naboo",     x = 29.10, z = 0.26, y = -0.03, cellID = 1717502 },

	-- Corellia
	-- Coronet: INSIDE the medcenter (matches spawn entry)
	travel_coronet            = { planet = "corellia",  x = -23.98, z = 0.26, y = 1.16, cellID = 1855535 },
	-- Tyrena: INSIDE the medcenter (matches spawn entry)
	travel_tyrena             = { planet = "corellia",  x = 29.20, z = 0.26, y = 0.27, cellID = 1935831 },
	-- Kor Vella: OUTDOOR (matches spawn entry — at vehicle garage area)
	travel_kor_vella          = { planet = "corellia",  x = -3137.85, z = 31.00, y = 2791.61 },
	-- Bela Vistal: INSIDE the medcenter (matches spawn entry)
	travel_bela_vistal        = { planet = "corellia",  x = -12.29, z = 0.18, y = 0.01, cellID = 3375374 },
	-- Doaba Guerfel: INSIDE the medcenter (matches spawn entry)
	travel_doaba_guerfel      = { planet = "corellia",  x = -12.12, z = 0.18, y = 0.00, cellID = 4345354 },

	-- Talus
	-- Dearic: INSIDE the medcenter (matches spawn entry)
	travel_dearic             = { planet = "talus",     x = -12.64, z = 0.18, y = 0.06, cellID = 3305354 },
	-- Nashal: INSIDE the medcenter (matches spawn entry)
	travel_nashal             = { planet = "talus",     x = -12.06, z = 0.18, y = 0.01, cellID = 4265477 },

	-- Rori
	-- Narmle: INSIDE the medcenter (matches spawn entry)
	travel_narmle             = { planet = "rori",      x = 29.20, z = 0.26, y = 0.07, cellID = 4635420 },
	-- Restuss: INSIDE the medcenter (matches spawn entry)
	travel_restuss            = { planet = "rori",      x = 29.41, z = 0.26, y = 0.01, cellID = 4635789 },

	-- Outer rim
	-- Dantooine Mining Outpost: INSIDE (matches spawn entry)
	travel_dantooine_mining   = { planet = "dantooine", x = 2.98, z = 0.13, y = 0.16, cellID = 1366007 },
	-- Nym's Stronghold: INSIDE (matches spawn entry)
	travel_lok_nym            = { planet = "lok",       x = 16.84, z = 0.26, y = 8.49, cellID = 2745866 },
	-- Dathomir Science Outpost: INSIDE (matches spawn entry)
	travel_dathomir_science   = { planet = "dathomir",  x = 2.89, z = 0.13, y = -0.15, cellID = 1392893 },
	-- Endor Smuggler Outpost: INSIDE (matches spawn entry)
	travel_endor_smuggler     = { planet = "endor",     x = 4.60, z = 0.13, y = -3.68, cellID = 6705359 },
	-- Yavin IV Mining Outpost: INSIDE (matches spawn entry)
	travel_yavin4_mining      = { planet = "yavin4",    x = 4.18, z = 0.13, y = 0.60, cellID = 7925457 },
}

fbMosEisleyMedicalDroidConvoHandler = conv_handler:new {}

-- Route admins (hasGodMode) to the admin-flavored intro that exposes the
-- [ADMIN] debug-cell-info option. Regular players see the standard intro
-- and never know the option exists.
--
-- This is the conversation-engine's per-player initial-screen hook.
function fbMosEisleyMedicalDroidConvoHandler:getInitialScreen(pPlayer, pNpc, pConvTemplate)
	local convoTemplate = LuaConversationTemplate(pConvTemplate)

	if pPlayer == nil then
		return convoTemplate:getScreen("intro")
	end

	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost ~= nil and PlayerObject(pGhost):hasGodMode() then
		return convoTemplate:getScreen("intro_admin")
	end

	return convoTemplate:getScreen("intro")
end

function fbMosEisleyMedicalDroidConvoHandler:applyBuffs(pPlayer)
	if pPlayer == nil then return end
	CreatureObject(pPlayer):enhanceCharacter()
end

function fbMosEisleyMedicalDroidConvoHandler:clearAllWounds(pPlayer)
	if pPlayer == nil then return end
	for i = 0, 8 do
		CreatureObject(pPlayer):setWounds(i, 0)
	end
	CreatureObject(pPlayer):setShockWounds(0)
end

function fbMosEisleyMedicalDroidConvoHandler:teleportTo(pPlayer, dest)
	if pPlayer == nil or dest == nil then return end

	-- Dismount if riding anything (switchZone with a vehicle is fragile)
	local player = CreatureObject(pPlayer)
	if player:isRidingMount() then
		player:dismount()
	end

	SceneObject(pPlayer):switchZone(dest.planet, dest.x, dest.z, dest.y, dest.cellID or 0)
end

-- ==== Debug: schedule (or fire immediately) a cell-info report ====
-- Player picks one of the [ADMIN] options from FB-21; we route here with the
-- right delay. seconds == 0 fires immediately (no createEvent). Non-zero
-- schedules a createEvent so the player can walk somewhere first.
-- The actual reporting happens in FbDebugReporter:reportCellInfo (a separate
-- screenplay), which sends the player a system message with their current
-- zone, position, and parentID.
function fbMosEisleyMedicalDroidConvoHandler:scheduleCellReport(pPlayer, seconds)
	if pPlayer == nil then return end

	if seconds == nil or seconds <= 0 then
		-- Fire immediately. FbDebugReporter:reportCellInfo accepts pPlayer
		-- directly, same as it does via createEvent.
		FbDebugReporter:reportCellInfo(pPlayer)
		return
	end

	local msg = string.format(
		"FB-21 Debug: You have %d seconds. Walk to the target spot and wait.",
		seconds
	)
	CreatureObject(pPlayer):sendSystemMessage(msg)
	createEvent(seconds * 1000, "FbDebugReporter", "reportCellInfo", pPlayer, "")
end

function fbMosEisleyMedicalDroidConvoHandler:runScreenHandlers(pConvTemplate, pPlayer, pNpc, selectedOption, pConvScreen)
	local screen = LuaConversationScreen(pConvScreen)
	local screenID = screen:getScreenID()

	-- ==== Debug: cell-info reporter (admin only, runs even in combat) ====
	-- Three screenIDs map to three duration choices:
	--   do_debug_cell_now -> fire immediately
	--   do_debug_cell_60  -> 60-second deferred
	--   do_debug_cell_300 -> 5-minute deferred
	if screenID == "do_debug_cell_now" then
		self:scheduleCellReport(pPlayer, 0)
		return pConvScreen
	elseif screenID == "do_debug_cell_60" then
		self:scheduleCellReport(pPlayer, 60)
		return pConvScreen
	elseif screenID == "do_debug_cell_300" then
		self:scheduleCellReport(pPlayer, 300)
		return pConvScreen
	end

	-- ==== Travel ====
	-- Check if this screen is a travel destination
	local dest = TRAVEL_DESTINATIONS[screenID]
	if dest ~= nil then
		self:teleportTo(pPlayer, dest)
		return pConvScreen
	end

	-- ==== Combat safety ====
	if CreatureObject(pPlayer):isInCombat() then
		local pIntermediate = LuaConversationTemplate(pConvTemplate):getScreen("do_in_combat")
		return pIntermediate
	end

	-- ==== Medical services ====
	if screenID == "do_buff" then
		self:applyBuffs(pPlayer)
	elseif screenID == "do_clear_wounds" then
		self:clearAllWounds(pPlayer)
	elseif screenID == "do_both" then
		self:applyBuffs(pPlayer)
		self:clearAllWounds(pPlayer)
	end
	-- "do_decline", "do_in_combat", and travel_menu/travel_planet_* navigation screens have no side effects

	return pConvScreen
end
