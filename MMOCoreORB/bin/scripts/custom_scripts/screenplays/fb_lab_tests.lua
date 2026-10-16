-- fb_lab_tests.lua — Final Boss test-lab checks for shipped custom content.
--
-- Run on the live server from the console:
--     runLuaFunction FbLabTests:runAll
--     runLuaFunction FbLabTests:runAll:<characterFirstName>   (also checks that character's inventory)
-- or via  tools/swg test lua [<char>]
--
-- Prints one line per check:  PASS <name> | FAIL <name> — <detail> | SKIP <name> — <why>
-- and a final  INFO summary: ...  line. tools/swg greps for these.
--
-- Loaded from custom_scripts/screenplays/screenplays.lua, which screenplays.lua includes
-- before the fb_* screenplays and before DirectorManager calls their start(), so the
-- spawnMobile wrapper below sees every fb_* NPC the screenplays spawn.

FbLabTests = FbLabTests or {}
FbLabTests.spawns = FbLabTests.spawns or {}   -- creature template name -> list of { oid, zone, cell }

-- ---------------------------------------------------------------- spawn tracking

if not FbLabTests._spawnMobileWrapped then
	local origSpawnMobile = spawnMobile

	-- Same signature as the C binding: (zoneName, template, respawn, x, z, y, heading, cellID).
	-- Everything is forwarded untouched; we only take note of fb_* spawns.
	spawnMobile = function(...)
		local pMobile = origSpawnMobile(...)
		local zoneName, template, _, _, _, _, _, cellID = ...

		if pMobile ~= nil and type(template) == "string" and template:sub(1, 3) == "fb_" then
			local list = FbLabTests.spawns[template] or {}
			list[#list + 1] = { oid = SceneObject(pMobile):getObjectID(), zone = zoneName, cell = cellID or 0 }
			FbLabTests.spawns[template] = list
		end

		return pMobile
	end

	FbLabTests._spawnMobileWrapped = true
end

-- ---------------------------------------------------------------- reporting

local results

local function report(kind, name, detail)
	local line = kind .. " " .. name
	if detail ~= nil and detail ~= "" then
		line = line .. " — " .. tostring(detail)
	end
	print(line)
	results[kind] = (results[kind] or 0) + 1
end

local function check(name, ok, detail)
	if ok then report("PASS", name, nil) else report("FAIL", name, detail) end
	return ok
end

local function skip(name, why) report("SKIP", name, why) end

-- Load a Lua file into its own environment (falls back to _G for reads) so we can
-- inspect globals from scripts that normally live in other managers' Lua states.
local function loadIsolated(path)
	local env = setmetatable({}, { __index = _G })
	local chunk, err = loadfile(path, "t", env)
	if chunk == nil then return nil, err end
	local ok, rerr = pcall(chunk)
	if not ok then return nil, rerr end
	return env
end

local function fileContains(path, needle)
	local f = io.open(path, "r")
	if f == nil then return false, "cannot open " .. path end
	local text = f:read("a")
	f:close()
	return text:find(needle, 1, true) ~= nil
end

local function contains(list, value)
	for _, v in ipairs(list or {}) do
		if v == value then return true end
	end
	return false
end

local function templateExists(path)
	return getObjectTemplatePathByCRC(getHashCode(path)) == path
end

-- ---------------------------------------------------------------- the content under test

FbLabTests.starterGear = {
	"object/weapon/ranged/pistol/pistol_cdef.iff",
	"object/tangible/wearables/shirt/shirt_s03.iff",
	"object/tangible/wearables/pants/pants_s01.iff",
	"object/tangible/medicine/stimpack_sm_s1.iff",
}

FbLabTests.npcs = {
	{ label = "FB-21 medical droid", template = "fb_mos_eisley_medical_droid", screenplay = "FbMosEisleyMedicalDroid",
	  convo = "fbMosEisleyMedicalDroidConvoTemplate", handler = "fbMosEisleyMedicalDroidConvoHandler",
	  mobileFile = "scripts/mobile/quest/tatooine/fb_mos_eisley_medical_droid.lua",
	  convoFile = "scripts/mobile/conversations/tasks/fb_mos_eisley_medical_droid_conv.lua" },
	{ label = "FB-72 armory droid", template = "fb_armory_droid", screenplay = "FbArmoryDroid",
	  convo = "fbArmoryDroidConvoTemplate", handler = "fbArmoryDroidConvoHandler",
	  mobileFile = "scripts/mobile/quest/tatooine/fb_armory_droid.lua",
	  convoFile = "scripts/mobile/conversations/tasks/fb_armory_droid_conv.lua" },
	{ label = "Vex Renn stim dealer", template = "fb_stim_dealer", screenplay = "FbStimDealer",
	  convo = "fbStimDealerConvoTemplate", handler = "fbStimDealerConvoHandler",
	  mobileFile = "scripts/mobile/quest/tatooine/fb_stim_dealer.lua",
	  convoFile = "scripts/mobile/conversations/tasks/fb_stim_dealer_conv.lua" },
}

-- ---------------------------------------------------------------- checks

function FbLabTests.checkStarterGear(charName)
	local env, err = loadIsolated("scripts/managers/player_creation_manager.lua")
	if env == nil then
		check("starter_gear.config_loads", false, err)
	else
		local missing = {}
		for _, t in ipairs(FbLabTests.starterGear) do
			if not contains(env.commonStartingItems, t) then missing[#missing + 1] = t end
		end
		check("starter_gear.in_commonStartingItems", #missing == 0, "missing: " .. table.concat(missing, ", "))
		check("starter_gear.starting_cash_100k", env.startingCash == 100000 and env.startingBank == 100000,
			"cash=" .. tostring(env.startingCash) .. " bank=" .. tostring(env.startingBank))
	end

	local bad = {}
	for _, t in ipairs(FbLabTests.starterGear) do
		if not templateExists(t) then bad[#bad + 1] = t end
	end
	check("starter_gear.templates_exist", #bad == 0, "unknown templates: " .. table.concat(bad, ", "))

	if charName == nil or charName == "" then
		skip("starter_gear.in_new_inventory", "no character name given (runAll:<firstName>)")
		return
	end

	local pPlayer = getPlayerByName(charName)
	if pPlayer == nil then
		skip("starter_gear.in_new_inventory", "player '" .. charName .. "' not online")
		return
	end

	local pInventory = SceneObject(pPlayer):getSlottedObject("inventory")
	if pInventory == nil then
		check("starter_gear.in_new_inventory", false, "no inventory object")
		return
	end

	-- GOTCHA: SceneObject(p) / CreatureObject(p) / ... hand back one shared wrapper per class, not a
	-- new object. `local inv = SceneObject(pInv)` is silently re-pointed by the next SceneObject(...)
	-- call (here: SceneObject(pItem)), after which inv:getContainerObject(i) indexes the *item*
	-- and throws ArrayIndexOutOfBoundsException — a C++ exception that pcall cannot catch and
	-- that leaves the console Lua stack dirty until restart. Always wrap inline.
	local have, count = {}, SceneObject(pInventory):getContainerObjectsSize()
	for i = 0, count - 1 do
		local pItem = SceneObject(pInventory):getContainerObject(i)
		if pItem ~= nil then
			have[SceneObject(pItem):getTemplateObjectPath()] = true
		end
	end

	local missing = {}
	for _, t in ipairs(FbLabTests.starterGear) do
		if not have[t] then missing[#missing + 1] = t end
	end
	check("starter_gear.in_new_inventory", #missing == 0,
		charName .. " has " .. tostring(count) .. " items; missing: " .. table.concat(missing, ", "))
end

function FbLabTests.checkNpc(npc)
	local p = npc.template .. "."

	check(p .. "mobile_template_registered", creatureTemplateExists(npc.template))
	check(p .. "screenplay_loaded", type(_G[npc.screenplay]) == "table", "global " .. npc.screenplay .. " missing")
	check(p .. "conv_handler_loaded", type(_G[npc.handler]) == "table", "global " .. npc.handler .. " missing")

	-- include wiring
	check(p .. "included_in_serverobjects", fileContains("scripts/mobile/quest/serverobjects.lua", npc.mobileFile:gsub("^scripts/mobile/", "")))
	check(p .. "included_in_conversations", fileContains("scripts/mobile/conversations.lua", npc.convoFile:gsub("^scripts/mobile/", "")))

	-- conversation template: run the file in an isolated env that has the real ConvoTemplate /
	-- ConvoScreen classes (scripts/mobile/conversation.lua) and a capturing addConversationTemplate,
	-- then make sure the name it registers is the one the mobile template points at and that its
	-- handler is loaded in this (DirectorManager) Lua state.
	local registered = {}
	local stubEnv = setmetatable({
		addConversationTemplate = function(name, tmpl) registered[name] = tmpl end,
		includeFile = function() end,
	}, { __index = _G })
	local ok, err
	local base = loadfile("scripts/mobile/conversation.lua", "t", stubEnv)
	if base == nil then
		ok, err = false, "cannot load scripts/mobile/conversation.lua"
	else
		ok, err = pcall(base)
		if ok then
			local chunk, lerr = loadfile(npc.convoFile, "t", stubEnv)
			if chunk == nil then ok, err = false, lerr else ok, err = pcall(chunk) end
		end
	end
	if not check(p .. "conversation_file_loads", ok, err) then return end

	local tmpl = registered[npc.convo]
	check(p .. "conversation_registered_as_" .. npc.convo, tmpl ~= nil,
		"registered names: " .. table.concat((function() local k = {} for n in pairs(registered) do k[#k + 1] = n end return k end)(), ", "))
	if tmpl ~= nil then
		check(p .. "conversation_handler_matches", tmpl.luaClassHandler == npc.handler,
			"luaClassHandler=" .. tostring(tmpl.luaClassHandler))
		check(p .. "conversation_has_screens", type(tmpl.screens) == "table" and #tmpl.screens > 0,
			"screens=" .. tostring(tmpl.screens and #tmpl.screens))
	end

	-- mobile template file: lives in CreatureTemplateManager's Lua state, so run it here with a
	-- stand-in Creature class; unknown globals (MOB_NPC, NONE, INVULNERABLE, ...) read as 0.
	local mobEnv = setmetatable({
		Creature = { new = function(self, t) return t end },
		CreatureTemplates = { addCreatureTemplate = function() end },
		includeFile = function() end,
	}, { __index = function(_, k) local v = _G[k]; if v == nil then return 0 end; return v end })
	local mchunk, merr = loadfile(npc.mobileFile, "t", mobEnv)
	if mchunk ~= nil then
		local mok, mrerr = pcall(mchunk)
		if not mok then mchunk, merr = nil, mrerr end
	end
	if mchunk == nil then
		check(p .. "mobile_file_loads", false, merr)
	else
		local mob = mobEnv[npc.template]
		check(p .. "mobile_points_at_conversation", type(mob) == "table" and mob.conversationTemplate == npc.convo,
			"conversationTemplate=" .. tostring(type(mob) == "table" and mob.conversationTemplate))
	end

	-- live spawns
	local spawns = FbLabTests.spawns[npc.template] or {}
	if #spawns == 0 then
		check(p .. "spawned", false, "no spawnMobile calls recorded for this template (was fb_lab_tests.lua loaded before the screenplay started?)")
		return
	end

	local alive, gone, zones = 0, {}, {}
	for _, s in ipairs(spawns) do
		local pObj = getSceneObject(s.oid)
		if pObj ~= nil and SceneObject(pObj):getZoneName() == s.zone then
			alive = alive + 1
			zones[s.zone] = (zones[s.zone] or 0) + 1
		else
			gone[#gone + 1] = s.zone .. "#" .. tostring(s.oid)
		end
	end
	local where = {}
	for z, n in pairs(zones) do where[#where + 1] = z .. "=" .. n end
	table.sort(where)
	check(p .. "spawned", alive == #spawns and alive > 0,
		alive .. "/" .. #spawns .. " alive; missing: " .. table.concat(gone, ", "))
	report("INFO", p .. "spawn_zones", table.concat(where, " "))
end

function FbLabTests.checkShuttles()
	local env, err = loadIsolated("scripts/managers/planet/planet_manager.lua")
	if env == nil then
		check("shuttle.config_loads", false, err)
		return
	end
	check("shuttle.shuttleportAwayTime_60s", env.shuttleportAwayTime == 60, "shuttleportAwayTime=" .. tostring(env.shuttleportAwayTime))
	check("shuttle.starportAwayTime_60s", env.starportAwayTime == 60, "starportAwayTime=" .. tostring(env.starportAwayTime))
end

function FbLabTests.checkQol()
	local env, err = loadIsolated("scripts/managers/player_manager.lua")
	if env == nil then
		check("qol.player_manager_loads", false, err)
		return
	end
	check("qol.globalExpMultiplier_2x", env.globalExpMultiplier == 2.0, "globalExpMultiplier=" .. tostring(env.globalExpMultiplier))
	check("qol.groupExpMultiplier_1.25", env.groupExpMultiplier == 1.25, "groupExpMultiplier=" .. tostring(env.groupExpMultiplier))
end

-- ---------------------------------------------------------------- entry points

-- runLuaFunction passes the FbLabTests table as the first argument, then the ':'-separated args.
function FbLabTests:runAll(charName)
	results = {}
	print("INFO FbLabTests start " .. getFormattedTime())

	local ok, err = pcall(function()
		FbLabTests.checkStarterGear(charName)
		for _, npc in ipairs(FbLabTests.npcs) do
			FbLabTests.checkNpc(npc)
		end
		FbLabTests.checkShuttles()
		FbLabTests.checkQol()
	end)
	if not ok then
		report("FAIL", "runAll.crashed", err)
	end

	local summary = string.format("%d passed, %d failed, %d skipped",
		results.PASS or 0, results.FAIL or 0, results.SKIP or 0)
	print("INFO summary: " .. summary)
	return summary
end

-- runLuaFunction FbLabTests:isOnline:<firstName> — cheap poll used by tools/swg test bot.
function FbLabTests:isOnline(charName)
	local pPlayer = charName and getPlayerByName(charName) or nil
	local pGhost = pPlayer ~= nil and CreatureObject(pPlayer):getPlayerObject() or nil
	local online = pGhost ~= nil and PlayerObject(pGhost):isOnline()
	print("INFO " .. (online and "online " or "offline ") .. tostring(charName))
	return online and "online" or "offline"
end

-- runLuaFunction FbLabTests:listSpawns — dump what the wrapper recorded.
function FbLabTests:listSpawns()
	local n = 0
	for template, list in pairs(FbLabTests.spawns) do
		for _, s in ipairs(list) do
			print("INFO spawn " .. template .. " oid=" .. tostring(s.oid) .. " zone=" .. s.zone .. " cell=" .. tostring(s.cell))
			n = n + 1
		end
	end
	print("INFO " .. n .. " fb_* spawns recorded")
	return tostring(n)
end
