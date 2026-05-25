-- fb_mos_eisley_medical_droid_conv.lua
-- Conversation template for the FB-21 medical droid network.
-- Now includes a Travel submenu making each droid a fast-travel hub.
--
-- Install path: MMOCoreORB/bin/scripts/mobile/conversations/tasks/fb_mos_eisley_medical_droid_conv.lua
--
-- Phase 2.6 — Final Boss server custom content.

fbMosEisleyMedicalDroidConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbMosEisleyMedicalDroidConvoHandler",
	screens = {}
}

-- ==== Top-level intro ====

-- Standard intro shown to all players. No debug option.
intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "Greetings, citizen. I am medical droid FB-21. I can provide medical services or transport you to other Empire-licensed medical facilities. How may I assist you?",
	stopConversation = "false",
	options = {
		{"Provide me with the full medical enhancement package.",       "do_buff"},
		{"Clear my battle wounds and shock damage.",                    "do_clear_wounds"},
		{"Both, please buff me up and clear my wounds.",                "do_both"},
		{"I would like to travel to another medical facility.",         "travel_menu"},
		{"Just looking around. Thank you, droid.",                      "do_decline"},
	}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(intro)

-- Admin-only intro: same content as `intro` plus the [ADMIN] cell-info options.
-- The handler's getInitialScreen routes players with hasGodMode() here.
-- Used as a permanent admin tool for harvesting cellIDs of static world
-- buildings when placing interior NPCs (medcenters, shops, etc.).
--
-- Three duration variants:
--   * NOW:    you're already standing where you want the data (no walk)
--   * 60s:    moderate walk (cross-town, outdoor FB-21 to building entrance)
--   * 5min:   long walk or just-in-case headroom (any distance on planet)
intro_admin = ConvoScreen:new {
	id = "intro_admin",
	customDialogText = "Greetings, administrator. I am medical droid FB-21. I can provide medical services, transport you to other Empire-licensed medical facilities, or assist with diagnostic routines. How may I assist you?",
	stopConversation = "false",
	options = {
		{"Provide me with the full medical enhancement package.",        "do_buff"},
		{"Clear my battle wounds and shock damage.",                     "do_clear_wounds"},
		{"Both, please buff me up and clear my wounds.",                 "do_both"},
		{"I would like to travel to another medical facility.",          "travel_menu"},
		{"[ADMIN] Report my cell info NOW (no delay).",                  "do_debug_cell_now"},
		{"[ADMIN] Report my cell info in 60 seconds.",                   "do_debug_cell_60"},
		{"[ADMIN] Report my cell info in 5 minutes.",                    "do_debug_cell_300"},
		{"Just looking around. Thank you, droid.",                       "do_decline"},
	}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(intro_admin)

-- ==== Service screens ====

do_buff = ConvoScreen:new {
	id = "do_buff",
	customDialogText = "Administering medical enhancements. Please remain stationary while the injections take effect.",
	stopConversation = "true",
	options = {}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(do_buff)

do_clear_wounds = ConvoScreen:new {
	id = "do_clear_wounds",
	customDialogText = "Wounds treated and shock dissipated. You are clear to resume normal activity.",
	stopConversation = "true",
	options = {}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(do_clear_wounds)

do_both = ConvoScreen:new {
	id = "do_both",
	customDialogText = "Full treatment course administered. Enhancement compounds and wound treatments applied. Have a productive day.",
	stopConversation = "true",
	options = {}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(do_both)

do_decline = ConvoScreen:new {
	id = "do_decline",
	customDialogText = "Acknowledged. Return at your convenience for medical services.",
	stopConversation = "true",
	options = {}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(do_decline)

do_in_combat = ConvoScreen:new {
	id = "do_in_combat",
	customDialogText = "Medical protocol prohibits administering enhancements during active combat. Please return when you are out of combat.",
	stopConversation = "true",
	options = {}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(do_in_combat)

-- ==== Debug: cell-info reporter (admin only, three duration variants) ====
-- Handler picks the matching screenID and calls scheduleCellReport(player, secs).
-- secs=0 fires immediately. Non-zero schedules a createEvent that fires later.
-- All three eventually call FbDebugReporter:reportCellInfo(player), which sends
-- the player a system message with their current parentID + cell-local position.

do_debug_cell_now = ConvoScreen:new {
	id = "do_debug_cell_now",
	customDialogText = "Diagnostic routine initiated. Cell information will be transmitted to your HUD shortly.",
	stopConversation = "true",
	options = {}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(do_debug_cell_now)

do_debug_cell_60 = ConvoScreen:new {
	id = "do_debug_cell_60",
	customDialogText = "Diagnostic routine initiated. You have 60 seconds to position yourself inside the target building. A report will be transmitted when the timer expires.",
	stopConversation = "true",
	options = {}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(do_debug_cell_60)

do_debug_cell_300 = ConvoScreen:new {
	id = "do_debug_cell_300",
	customDialogText = "Diagnostic routine initiated. You have 5 minutes to position yourself inside the target building. A report will be transmitted when the timer expires.",
	stopConversation = "true",
	options = {}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(do_debug_cell_300)

-- ==== Travel menu hub ====

travel_menu = ConvoScreen:new {
	id = "travel_menu",
	customDialogText = "Which planet's medical network would you like to access?",
	stopConversation = "false",
	options = {
		{"Tatooine",  "travel_planet_tatooine"},
		{"Naboo",     "travel_planet_naboo"},
		{"Corellia",  "travel_planet_corellia"},
		{"Talus",     "travel_planet_talus"},
		{"Rori",      "travel_planet_rori"},
		{"Dantooine", "travel_planet_dantooine"},
		{"Lok",       "travel_planet_lok"},
		{"Dathomir",  "travel_planet_dathomir"},
		{"Endor",     "travel_planet_endor"},
		{"Yavin IV",  "travel_planet_yavin4"},
		{"Cancel.",   "do_decline"},
	}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(travel_menu)

-- ==== Per-planet submenus ====

travel_planet_tatooine = ConvoScreen:new {
	id = "travel_planet_tatooine",
	customDialogText = "Tatooine facilities. Select a destination.",
	stopConversation = "false",
	options = {
		{"Mos Eisley",   "travel_mos_eisley"},
		{"Bestine",      "travel_bestine"},
		{"Mos Espa",     "travel_mos_espa"},
		{"Mos Entha",    "travel_mos_entha"},
		{"Anchorhead",   "travel_anchorhead"},
		{"Back",         "travel_menu"},
	}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(travel_planet_tatooine)

travel_planet_naboo = ConvoScreen:new {
	id = "travel_planet_naboo",
	customDialogText = "Naboo facilities. Select a destination.",
	stopConversation = "false",
	options = {
		{"Theed",   "travel_theed"},
		{"Keren",   "travel_keren"},
		{"Moenia",  "travel_moenia"},
		{"Back",    "travel_menu"},
	}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(travel_planet_naboo)

travel_planet_corellia = ConvoScreen:new {
	id = "travel_planet_corellia",
	customDialogText = "Corellia facilities. Select a destination.",
	stopConversation = "false",
	options = {
		{"Coronet",         "travel_coronet"},
		{"Tyrena",          "travel_tyrena"},
		{"Kor Vella",       "travel_kor_vella"},
		{"Bela Vistal",     "travel_bela_vistal"},
		{"Doaba Guerfel",   "travel_doaba_guerfel"},
		{"Back",            "travel_menu"},
	}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(travel_planet_corellia)

travel_planet_talus = ConvoScreen:new {
	id = "travel_planet_talus",
	customDialogText = "Talus facilities. Select a destination.",
	stopConversation = "false",
	options = {
		{"Dearic",  "travel_dearic"},
		{"Nashal",  "travel_nashal"},
		{"Back",    "travel_menu"},
	}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(travel_planet_talus)

travel_planet_rori = ConvoScreen:new {
	id = "travel_planet_rori",
	customDialogText = "Rori facilities. Select a destination.",
	stopConversation = "false",
	options = {
		{"Narmle",   "travel_narmle"},
		{"Restuss",  "travel_restuss"},
		{"Back",     "travel_menu"},
	}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(travel_planet_rori)

travel_planet_dantooine = ConvoScreen:new {
	id = "travel_planet_dantooine",
	customDialogText = "Dantooine. Select a destination.",
	stopConversation = "false",
	options = {
		{"Mining Outpost",  "travel_dantooine_mining"},
		{"Back",            "travel_menu"},
	}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(travel_planet_dantooine)

travel_planet_lok = ConvoScreen:new {
	id = "travel_planet_lok",
	customDialogText = "Lok. Select a destination.",
	stopConversation = "false",
	options = {
		{"Nym's Stronghold", "travel_lok_nym"},
		{"Back",             "travel_menu"},
	}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(travel_planet_lok)

travel_planet_dathomir = ConvoScreen:new {
	id = "travel_planet_dathomir",
	customDialogText = "Dathomir. Select a destination.",
	stopConversation = "false",
	options = {
		{"Science Outpost",  "travel_dathomir_science"},
		{"Back",             "travel_menu"},
	}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(travel_planet_dathomir)

travel_planet_endor = ConvoScreen:new {
	id = "travel_planet_endor",
	customDialogText = "Endor. Select a destination.",
	stopConversation = "false",
	options = {
		{"Smuggler Outpost", "travel_endor_smuggler"},
		{"Back",             "travel_menu"},
	}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(travel_planet_endor)

travel_planet_yavin4 = ConvoScreen:new {
	id = "travel_planet_yavin4",
	customDialogText = "Yavin IV. Select a destination.",
	stopConversation = "false",
	options = {
		{"Mining Outpost",  "travel_yavin4_mining"},
		{"Back",            "travel_menu"},
	}
}
fbMosEisleyMedicalDroidConvoTemplate:addScreen(travel_planet_yavin4)

-- ==== Destination screens (the actual teleport target IDs) ====
-- All of these use the same "transporting" text. The handler sees the screenID
-- and looks up the correct planet/coords in the TRAVEL_DESTINATIONS table.

local function makeTravelScreen(id)
	local screen = ConvoScreen:new {
		id = id,
		customDialogText = "Initiating transport. Please remain still during the procedure.",
		stopConversation = "true",
		options = {}
	}
	fbMosEisleyMedicalDroidConvoTemplate:addScreen(screen)
	return screen
end

makeTravelScreen("travel_mos_eisley")
makeTravelScreen("travel_bestine")
makeTravelScreen("travel_mos_espa")
makeTravelScreen("travel_mos_entha")
makeTravelScreen("travel_anchorhead")
makeTravelScreen("travel_theed")
makeTravelScreen("travel_keren")
makeTravelScreen("travel_moenia")
makeTravelScreen("travel_coronet")
makeTravelScreen("travel_tyrena")
makeTravelScreen("travel_kor_vella")
makeTravelScreen("travel_bela_vistal")
makeTravelScreen("travel_doaba_guerfel")
makeTravelScreen("travel_dearic")
makeTravelScreen("travel_nashal")
makeTravelScreen("travel_narmle")
makeTravelScreen("travel_restuss")
makeTravelScreen("travel_dantooine_mining")
makeTravelScreen("travel_lok_nym")
makeTravelScreen("travel_dathomir_science")
makeTravelScreen("travel_endor_smuggler")
makeTravelScreen("travel_yavin4_mining")

addConversationTemplate("fbMosEisleyMedicalDroidConvoTemplate", fbMosEisleyMedicalDroidConvoTemplate)
