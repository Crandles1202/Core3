-- fb_holonet_relay_conv.lua — Phase 3.10 HoloNet relay conversation (replay on demand).
fbHolonetRelayConvoTemplate = ConvoTemplate:new {
	initialScreen = "intro",
	templateType = "Lua",
	luaClassHandler = "fbHolonetRelayConvoHandler",
	screens = {}
}

intro = ConvoScreen:new {
	id = "intro",
	customDialogText = "HoloNet Relay unit HN-7 at your service. Broadcasts play automatically while listeners are present. Shall I replay the current segment?",
	stopConversation = "false",
	options = {
		{"Replay the latest broadcast.",   "do_replay"},
		{"No, thank you.",                 "do_decline"},
	}
}
fbHolonetRelayConvoTemplate:addScreen(intro)

do_replay = ConvoScreen:new {
	id = "do_replay",
	customDialogText = "Replaying. Stand by.",
	stopConversation = "true",
	options = {}
}
fbHolonetRelayConvoTemplate:addScreen(do_replay)

do_decline = ConvoScreen:new {
	id = "do_decline",
	customDialogText = "Very good. Stay informed.",
	stopConversation = "true",
	options = {}
}
fbHolonetRelayConvoTemplate:addScreen(do_decline)

addConversationTemplate("fbHolonetRelayConvoTemplate", fbHolonetRelayConvoTemplate)
