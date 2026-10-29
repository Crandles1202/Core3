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

-- Which Final Boss file asked for a spawn (nil for stock callers). debug.getinfo level 3 = the caller of
-- the wrapper's caller: wrapper -> screenplay function -> ...; level 2 is the wrapper itself.
local function fbSpawnSource()
	if debug == nil or debug.getinfo == nil then return nil end
	for level = 2, 6 do
		local info = debug.getinfo(level, "S")
		if info == nil then return nil end
		local src = tostring(info.short_src or info.source or "")
		local name = src:match("([%w_]+)%.lua$")
		if name ~= nil and name:sub(1, 3) == "fb_" and name ~= "fb_lab_tests" then return name end
	end
	return nil
end

if not FbLabTests._spawnMobileWrapped2 then
	local origSpawnMobile = spawnMobile

	-- Same signature as the C binding: (zoneName, template, respawn, x, z, y, heading, cellID).
	-- Everything is forwarded untouched; we take note of every spawn an fb_* file makes (own fb_*
	-- templates and stock ones such as the ambient patrons), with where it was put, so the placement
	-- audit (FbLabTests:placement) and goto/findNpc can find them later.
	spawnMobile = function(...)
		local pMobile = origSpawnMobile(...)
		local zoneName, template, _, x, z, y, heading, cellID = ...
		local src = fbSpawnSource()

		if pMobile ~= nil and type(template) == "string" and (template:sub(1, 3) == "fb_" or src ~= nil) then
			local oid = SceneObject(pMobile):getObjectID()
			local list = FbLabTests.spawns[template] or {}
			-- an older wrapper may still sit under this one (reloadscreenplays keeps it): no duplicates
			local last = list[#list]
			if last ~= nil and last.oid == oid then
				last.x, last.y, last.z, last.src = x, y, z, src
			else
				list[#list + 1] = { oid = oid, zone = zoneName, cell = cellID or 0, x = x, y = y, z = z, template = template, src = src }
			end
			FbLabTests.spawns[template] = list
			FbLabTests.registryAdd({ oid = oid, zone = zoneName, cell = cellID or 0, x = x, y = y, z = z, template = template, src = src })
		end

		return pMobile
	end

	FbLabTests._spawnMobileWrapped2 = true
end

-- ---------------------------------------------------------------- shared spawn registry
-- Every Lua state has its own FbLabTests.spawns, so a spawn made on a worker thread (seat churn, a
-- scenario's probe, the Trade Hall tenants spawned at start on another state) is invisible to the
-- console and to the Lab Remote's windows. The quest-status copy is the shared truth: one key per
-- template holding "oid|zone|cell|x|y|z|src;" records, plus an index of templates. Stale records (the
-- object is gone, or from a previous boot) are dropped whenever they are read.
local REG_INDEX = "FbLabSpawns.templates"
local function regKey(template) return "FbLabSpawns." .. template end

-- Spawns that come and go by design (a landing party, a street scene's cast) are not placements to audit: they stay
-- out of the registry. Everything else is bounded: a template's record list is pruned of dead objects when it passes
-- REG_SOFT records and never exceeds REG_HARD — a quest status is one string, and the engine aborts the write-back
-- thread past 65 535 bytes (production crashed on exactly that on 2026-10-28, an hour after shuttle arrivals went live).
FbLabTests.registryTransient = { fb_arrivals = true, fb_scenes = true }
local REG_SOFT, REG_HARD = 200, 400

function FbLabTests.registryAdd(s)
	if s.src ~= nil and FbLabTests.registryTransient[s.src] then return end
	local rec = string.format("%d|%s|%d|%s|%s|%s|%s;", s.oid, s.zone or "", s.cell or 0, tostring(s.x or ""), tostring(s.y or ""), tostring(s.z or ""), s.src or "")
	local cur = getQuestStatus(regKey(s.template)) or ""
	if cur:find("^" .. s.oid .. "|") or cur:find(";" .. s.oid .. "|", 1, true) then return end
	local _, n = cur:gsub(";", "")
	if n >= REG_SOFT then
		local kept = {}
		for r in cur:gmatch("[^;]+") do
			local pObj = getSceneObject(tonumber(r:match("^(%d+)|")) or 0)
			if pObj ~= nil and SceneObject(pObj):getZoneName() ~= "" then kept[#kept + 1] = r .. ";" end
		end
		while #kept >= REG_HARD do table.remove(kept, 1) end   -- the oldest go first
		cur = table.concat(kept)
	end
	setQuestStatus(regKey(s.template), cur .. rec)
	local idx = getQuestStatus(REG_INDEX) or ","
	if not idx:find("," .. s.template .. ",", 1, true) then setQuestStatus(REG_INDEX, idx .. s.template .. ",") end
end

function FbLabTests.registryRemove(oid)
	for template in (getQuestStatus(REG_INDEX) or ""):gmatch("[^,]+") do
		local cur = getQuestStatus(regKey(template)) or ""
		local kept = {}
		for rec in cur:gmatch("[^;]+") do
			if tonumber(rec:match("^(%d+)|")) ~= tonumber(oid) then kept[#kept + 1] = rec .. ";" end
		end
		local joined = table.concat(kept)
		if joined ~= cur then setQuestStatus(regKey(template), joined) end
	end
end

-- Records whose object is still in the world; rewrites a template's key when it held stale ones.
function FbLabTests.registryLive()
	local out = {}
	for template in (getQuestStatus(REG_INDEX) or ""):gmatch("[^,]+") do
		local cur = getQuestStatus(regKey(template)) or ""
		local kept = {}
		for rec in cur:gmatch("[^;]+") do
			local oid, zone, cell, x, y, z, src = rec:match("^(%d+)|([^|]*)|(%d+)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
			if oid ~= nil then
				local pObj = getSceneObject(tonumber(oid))
				if pObj ~= nil and SceneObject(pObj):getZoneName() ~= "" then
					kept[#kept + 1] = rec .. ";"
					out[#out + 1] = { oid = tonumber(oid), zone = zone, cell = tonumber(cell), x = tonumber(x), y = tonumber(y), z = tonumber(z),
						template = template, src = src ~= "" and src or nil }
				end
			end
		end
		local joined = table.concat(kept)
		if joined ~= cur then setQuestStatus(regKey(template), joined) end
	end
	return out
end

-- Spawns these files make walk by design (patrol legs, convoys, columns, raiding parties, story camps
-- respawn on the move): the placement audit skips their drift check.
FbLabTests.walkerSources = { fb_faction_patrols = true, fb_convoys = true, fb_invasions = true, fb_weather_events = true }

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

-- Every Final Boss NPC follows one layout, so the list is discovered rather than maintained:
--   mobile template   scripts/mobile/quest/tatooine/<name>.lua          (defines <name> = Creature:new{...})
--   conversation      scripts/mobile/conversations/tasks/<name>_conv.lua (addConversationTemplate(...))
--   screenplay(s)     scripts/screenplays/tasks/tatooine/fb_*.lua        (registerScreenPlay("Name", true))
-- Add a new fb_* NPC with those files and it is covered automatically.
FbLabTests.mobileDir = "scripts/mobile/quest/tatooine"
FbLabTests.convoDir = "scripts/mobile/conversations/tasks"
FbLabTests.screenplayDir = "scripts/screenplays/tasks/tatooine"

-- Fallback when io.popen is unavailable: keep in sync with the files above.
FbLabTests.knownNpcs = {
	"fb_mos_eisley_medical_droid", "fb_armory_droid", "fb_stim_dealer",
	"fb_armor_droid", "fb_cantina_dancer", "fb_cantina_manager", "fb_cantina_musician",
	"fb_combat_quartermaster", "fb_droid_dispenser", "fb_imperial_armorer", "fb_pet_dealer",
	"fb_pet_vet", "fb_property_agent", "fb_smuggler_goods", "fb_speeder_dealer",
}

local function listFiles(dir, pattern)
	local names = {}
	local p = io.popen and io.popen("ls " .. dir .. "/" .. pattern .. " 2>/dev/null")
	if p ~= nil then
		for line in p:lines() do names[#names + 1] = line:match("([^/]+)%.lua$") end
		p:close()
	end
	return names
end

function FbLabTests.discoverNpcs()
	local templates = listFiles(FbLabTests.mobileDir, "fb_*.lua")
	if #templates == 0 then templates = FbLabTests.knownNpcs end
	table.sort(templates)
	local npcs = {}
	for _, t in ipairs(templates) do
		npcs[#npcs + 1] = {
			template = t,
			mobileFile = FbLabTests.mobileDir .. "/" .. t .. ".lua",
			convoFile = ((FbLabTests.eventNpcs or {})[t] or {}).convoFile or (FbLabTests.convoDir .. "/" .. t .. "_conv.lua"),   -- eventNpcs may name a shared one
		}
	end
	return npcs
end

function FbLabTests.discoverScreenplays()
	local names = {}
	local files = listFiles(FbLabTests.screenplayDir, "fb_*.lua")
	for _, f in ipairs(files) do
		local fh = io.open(FbLabTests.screenplayDir .. "/" .. f .. ".lua", "r")
		if fh ~= nil then
			local text = fh:read("a"); fh:close()
			for name in text:gmatch('registerScreenPlay%("([A-Za-z0-9_]+)"') do names[#names + 1] = name end
		end
	end
	table.sort(names)
	return names
end

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

-- NPCs that break the usual conventions on purpose: no conversation (a spirit that only speaks), or
-- spawned on demand by an event instead of at boot (visitors, ambushes). The checks adapt.
FbLabTests.eventNpcs = {
	fb_force_ghost = { conversation = false, spawnedAtBoot = false },   -- Phase 4a.1
	fb_old_man = { spawnedAtBoot = false },                             -- Phase 4a.1
	fb_prisoner = { spawnedAtBoot = false },                            -- Phase 4a.3
	fb_trial_spirit = { spawnedAtBoot = false },                        -- Phase 4a.3
	fb_vision_kenobi = { conversation = false, spawnedAtBoot = false }, -- Phase 4a.4
	fb_vision_luke = { conversation = false, spawnedAtBoot = false },   -- Phase 4a.4
	fb_vision_vader = { conversation = false, spawnedAtBoot = false },  -- Phase 4a.4
	fb_vision_exar_kun = { conversation = false, spawnedAtBoot = false }, -- Phase 4a.4
	fb_hunter_chief = { spawnedAtBoot = false, convoFile = "scripts/mobile/conversations/tasks/fb_knight_boss_conv.lua" },      -- Phase 4b.4
	fb_nightsister_witch = { spawnedAtBoot = false, convoFile = "scripts/mobile/conversations/tasks/fb_knight_boss_conv.lua" }, -- Phase 4b.4
	fb_bounty_thug = { conversation = false, spawnedAtBoot = false },        -- Phase 4c
	fb_bounty_hunter = { conversation = false, spawnedAtBoot = false },      -- Phase 4c
	fb_bounty_veteran = { conversation = false, spawnedAtBoot = false },     -- Phase 4c
	fb_bounty_dark_hunter = { conversation = false, spawnedAtBoot = false }, -- Phase 4c
	fb_bounty_light_hunter = { conversation = false, spawnedAtBoot = false }, -- Phase 4c
	fb_companion_light_1 = { conversation = false, spawnedAtBoot = false },    -- Phase 4b.5 (a hireling pet)
	fb_companion_light_2 = { conversation = false, spawnedAtBoot = false },
	fb_companion_light_3 = { conversation = false, spawnedAtBoot = false },
	fb_companion_dark_1 = { conversation = false, spawnedAtBoot = false },
	fb_companion_dark_2 = { conversation = false, spawnedAtBoot = false },
	fb_companion_dark_3 = { conversation = false, spawnedAtBoot = false },
	fb_companion_dark_turned = { conversation = false, spawnedAtBoot = false },
}

function FbLabTests.checkNpc(npc)
	local p = npc.template .. "."
	local ev = FbLabTests.eventNpcs[npc.template] or {}

	check(p .. "mobile_template_registered", creatureTemplateExists(npc.template))
	check(p .. "included_in_serverobjects", fileContains("scripts/mobile/quest/serverobjects.lua", npc.mobileFile:gsub("^scripts/mobile/", "")))
	if ev.conversation ~= false then
		check(p .. "included_in_conversations", fileContains("scripts/mobile/conversations.lua", npc.convoFile:gsub("^scripts/mobile/", "")))
	else
		report("INFO", p .. "no_conversation", "by design (eventNpcs)")
	end

	-- mobile template file: lives in CreatureTemplateManager's Lua state, so run it here with a
	-- stand-in Creature class; unknown globals (MOB_NPC, NONE, INVULNERABLE, ...) read as 0.
	-- It tells us which conversation template the NPC expects.
	local mobEnv = setmetatable({
		Creature = { new = function(self, t) return t end },
		CreatureTemplates = { addCreatureTemplate = function() end },
		includeFile = function() end,
		-- the stock templates build their attack lists with merge(table, table, …); the attack groups are
		-- unknown here (they read as 0) and are skipped
		merge = function(...) local r = {}; for _, t in ipairs({ ... }) do if type(t) == "table" then for _, v in ipairs(t) do r[#r + 1] = v end end end; return r end,
	}, { __index = function(_, k) local v = _G[k]; if v == nil then return 0 end; return v end })
	local mchunk, merr = loadfile(npc.mobileFile, "t", mobEnv)
	if mchunk ~= nil then
		local mok, mrerr = pcall(mchunk)
		if not mok then mchunk, merr = nil, mrerr end
	end
	if not check(p .. "mobile_file_loads", mchunk ~= nil, merr) then return end
	local mob = mobEnv[npc.template]
	local convoName = type(mob) == "table" and mob.conversationTemplate or nil
	if ev.conversation ~= false then
	if not check(p .. "mobile_names_conversation", type(convoName) == "string" and convoName ~= "",
			"global " .. npc.template .. " missing or has no conversationTemplate") then return end

	-- conversation template: run the file in an isolated env that has the real ConvoTemplate /
	-- ConvoScreen classes (scripts/mobile/conversation.lua) and a capturing addConversationTemplate,
	-- then make sure it registers the name the mobile points at and that its luaClassHandler is a
	-- loaded global in this (DirectorManager) Lua state.
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

	local tmpl = registered[convoName]
	local names = {}
	for n in pairs(registered) do names[#names + 1] = n end
	check(p .. "conversation_registered_as_" .. convoName, tmpl ~= nil, "registered: " .. table.concat(names, ", "))
	if tmpl ~= nil then
		check(p .. "conversation_handler_loaded",
			type(tmpl.luaClassHandler) == "string" and type(_G[tmpl.luaClassHandler]) == "table",
			"luaClassHandler=" .. tostring(tmpl.luaClassHandler) .. " is not a loaded global")
		check(p .. "conversation_has_screens", type(tmpl.screens) == "table" and #tmpl.screens > 0,
			"screens=" .. tostring(tmpl.screens and #tmpl.screens))
	end
	end   -- ev.conversation ~= false

	if ev.spawnedAtBoot == false then
		report("INFO", p .. "spawned", "event NPC, spawned on demand (eventNpcs); its scenario covers the spawn")
		return
	end

	-- live spawns recorded by the spawnMobile wrapper
	-- lab probes (spawnNpcAt) are not the screenplay's spawns; respawns made on other Lua states (the
	-- merchant's moves, seat churn) are only in the shared registry, so merge its live records in
	local spawns, seen = {}, {}
	for _, s in ipairs(FbLabTests.spawns[npc.template] or {}) do
		if s.src ~= "lab" then spawns[#spawns + 1] = s; seen[s.oid] = true end
	end
	for _, s in ipairs(FbLabTests.registryLive()) do
		if s.template == npc.template and s.src ~= "lab" and not seen[s.oid] then spawns[#spawns + 1] = s; seen[s.oid] = true end
	end
	if #spawns == 0 then
		check(p .. "spawned", false, "no spawnMobile calls recorded for this template (no screenplay spawns it, or fb_lab_tests.lua loaded after start())")
		return
	end

	-- Records accumulate over a server run: the traveling merchant despawns its old self when it moves,
	-- dead patrol squads are replaced, scenarios kill and respawn things. Every such event leaves an
	-- older record gone and a newer one alive, so the rule is: the newest record of the template must be
	-- alive, and nothing recorded after the newest gone one may be missing. Older gone records are INFO.
	local alive, gone, zones, newestGone, newestAlive = 0, {}, {}, 0, 0
	for i, s in ipairs(spawns) do
		local pObj = getSceneObject(s.oid)
		if pObj ~= nil and SceneObject(pObj):getZoneName() == s.zone then
			alive = alive + 1
			zones[s.zone] = (zones[s.zone] or 0) + 1
			newestAlive = i
		else
			gone[#gone + 1] = s.zone .. "#" .. tostring(s.oid)
			newestGone = i
		end
	end
	local where = {}
	for z, n in pairs(zones) do where[#where + 1] = z .. "=" .. n end
	table.sort(where)
	check(p .. "spawned", alive > 0 and newestAlive == #spawns,
		alive .. "/" .. #spawns .. " alive; missing: " .. table.concat(gone, ", "))
	if #gone > 0 and newestAlive == #spawns then
		report("INFO", p .. "retired_spawns", #gone .. " older record(s) gone (moved/respawned): " .. table.concat(gone, ", "))
	end
	report("INFO", p .. "spawn_zones", table.concat(where, " "))
end

function FbLabTests.checkScreenplays()
	local names = FbLabTests.discoverScreenplays()
	check("screenplays.discovered", #names > 0, "no registerScreenPlay() found under " .. FbLabTests.screenplayDir)
	for _, name in ipairs(names) do
		check("screenplay." .. name .. ".loaded", type(_G[name]) == "table", "global missing")
	end
end

function FbLabTests.checkShuttles()
	local env, err = loadIsolated("scripts/managers/planet/planet_manager.lua")
	if env == nil then
		check("shuttle.config_loads", false, err)
		return
	end
	check("shuttle.shuttleportAwayTime_60s", env.shuttleportAwayTime == 60, "shuttleportAwayTime=" .. tostring(env.shuttleportAwayTime))
	check("shuttle.starportAwayTime_60s", env.starportAwayTime == 60, "starportAwayTime=" .. tostring(env.starportAwayTime))
	-- every travel point of a running planet resolves to its own shuttle (the nearest one; two points sharing a shuttle is the
	-- Mos Espa bug); a point with no shuttle within 120 m is only a warning (Theed Spaceport boards without one)
	for planet, cfg in pairs(env) do
		if type(cfg) == "table" and type(cfg.planetTravelPoints) == "table" and isZoneEnabled(planet) then
			local seen = {}
			for _, pt in ipairs(cfg.planetTravelPoints) do
				local label = "shuttle." .. planet .. "." .. pt.name:gsub("%s", "_")
				local s, d = FbLabTests.shuttleFor(planet, pt)
				if s == nil then
					print("WARN " .. label .. " — no shuttle within 120 m of the travel point")
				else
					check(label .. ".own_shuttle", seen[s.oid] == nil,
						seen[s.oid] ~= nil and string.format("shuttle %d (%.0f m) also serves %s", s.oid, d, seen[s.oid]) or string.format("shuttle %d at %.0f m", s.oid, d))
					seen[s.oid] = pt.name
				end
			end
		end
	end
end

function FbLabTests.checkQol()
	local env, err = loadIsolated("scripts/managers/player_manager.lua")
	if env == nil then
		check("qol.player_manager_loads", false, err)
		return
	end
	check("qol.globalExpMultiplier_3x", env.globalExpMultiplier == 3.0, "globalExpMultiplier=" .. tostring(env.globalExpMultiplier))
	check("qol.groupExpMultiplier_1.25", env.groupExpMultiplier == 1.25, "groupExpMultiplier=" .. tostring(env.groupExpMultiplier))
end

-- Phase 1.9: every player stimpack template re-registered by fb_stimpack_mind.lua must list
-- health (0), action (3) and mind (6). Object templates live in another Lua state, so load the
-- override file into a sandbox whose ObjectTemplates records what it is handed and whose unknown
-- globals (the upstream template tables) are empty tables.
function FbLabTests.checkStimMind()
	local path = "scripts/custom_scripts/object/tangible/medicine/fb_stimpack_mind.lua"
	local captured = {}
	local env = setmetatable({
		ObjectTemplates = { addTemplate = function(_, template, iff) captured[iff] = template.attributes end },
	}, { __index = function(_, key)
		local v = _G[key]
		if v ~= nil then return v end
		return {}
	end })
	env._G = env   -- the override indexes _G[name]; route that through the stub too
	local chunk, err = loadfile(path, "t", env)
	if chunk == nil then check("stim_mind.override_loads", false, err); return end
	local ok, rerr = pcall(chunk)
	if not ok then check("stim_mind.override_loads", false, rerr); return end

	local n, allMind = 0, true
	for iff, atts in pairs(captured) do
		n = n + 1
		if not (contains(atts, 0) and contains(atts, 3) and contains(atts, 6)) then
			allMind = false
			check("stim_mind." .. iff:match("([^/]+)%.iff$"), false, "attributes missing 0/3/6")
		end
	end
	check("stim_mind.templates_reregistered", n == 15, n .. " templates (expected 15)")
	check("stim_mind.all_heal_health_action_mind", allMind and n > 0)
	check("stim_mind.included_in_serverobjects",
		fileContains("scripts/custom_scripts/object/serverobjects.lua", "fb_stimpack_mind.lua"))
	check("stim_mind.starter_stimpack_covered", captured["object/tangible/medicine/stimpack_sm_s1.iff"] ~= nil)
end

-- Phase 1.5: inventory template re-registered with 100 and the login hook that raises old ones.
function FbLabTests.checkInventory()
	local limit = FbLabTests:inventoryTemplateLimit()
	check("inventory.template_limit_100", limit == "100", "limit=" .. tostring(limit))
	check("inventory.included_in_serverobjects",
		fileContains("scripts/custom_scripts/object/serverobjects.lua", "fb_inventory_100.lua"))
	check("inventory.login_hook_included",
		fileContains("scripts/custom_scripts/screenplays/screenplays.lua", "fb_player_login.lua"))
	check("inventory.login_hook_wrapped", FBLogin ~= nil and PlayerTriggers.playerLoggedIn == FBLogin._wrapper
		and FBLogin.INVENTORY_VOLUME == 100, "PlayerTriggers.playerLoggedIn must be FBLogin's wrapper (survives reloadscreenplays)")
	-- the setContainerVolumeLimit binding itself is proven live by the inventory-100 scenario
end

-- Phase 2.5: the auction manager reads its limits from Core3.Auction.* (static check; the bot has no
-- auction packets yet, so this only proves the wiring is in the source the binary was built from).
function FbLabTests.checkBazaar()
	local src = "../src/server/zone/managers/auction/AuctionManagerImplementation.cpp"
	for _, key in ipairs({ "Core3.Auction.MaxSales", "Core3.Auction.CommodityExpireSeconds", "Core3.Auction.VendorExpireSeconds" }) do
		check("bazaar.config_key_" .. key:match("([^.]+)$"), fileContains(src, '"' .. key .. '"'))
	end
	check("bazaar.no_raw_MAXSALES_left", not fileContains(src, ">= MAXSALES"))
end

-- Phase 2.2: every catalogue entry of the schematic broker must point at a loot_schematic template
-- that names a targetDraftSchematic (38 upstream files are stubs) and carry that file's requiredSkill.
function FbLabTests.checkSchematicBroker()
	if FbSchematicBroker == nil then check("schematic_broker.loaded", false); return end
	local total, badDraft, badSkill = 0, {}, {}
	for _, cat in ipairs(FbSchematicBroker.categories) do
		for _, item in ipairs(cat.items) do
			total = total + 1
			local file = "scripts/" .. item.template:gsub("%.iff$", ".lua")
			if not fileContains(file, "targetDraftSchematic") then badDraft[#badDraft + 1] = item.name end
			local f = io.open(file, "r")
			if f ~= nil then
				local text = f:read("a"); f:close()
				local required = text:match('requiredSkill%s*=%s*"([^"]*)"') or ""
				if required ~= (item.skill or "") then badSkill[#badSkill + 1] = item.name .. "(" .. required .. ")" end
			end
		end
	end
	check("schematic_broker.catalogue_size", total >= 30, total .. " items")
	check("schematic_broker.every_item_has_draft", #badDraft == 0, table.concat(badDraft, ", "))
	check("schematic_broker.skills_match_templates", #badSkill == 0, table.concat(badSkill, ", "))
	check("schematic_broker.purchase_is_public", type(FbSchematicBroker.purchase) == "function")
end

-- Phase 2.3: every parts-dealer row names a component_loot item that exists (standard and advanced).
function FbLabTests.checkPartsDealer()
	if FbPartsDealer == nil then check("parts_dealer.loaded", false); return end
	local total, missing = 0, {}
	for _, cat in ipairs(FbPartsDealer.categories) do
		for _, item in ipairs(cat.items) do
			total = total + 1
			local f = io.open("scripts/loot/items/component_loot/" .. item.loot .. ".lua", "r")
			if f == nil then missing[#missing + 1] = item.loot else f:close() end
		end
	end
	check("parts_dealer.catalogue_size", total >= 40, total .. " parts")
	check("parts_dealer.every_loot_item_exists", #missing == 0, table.concat(missing, ", "))
	check("parts_dealer.purchase_is_public", type(FbPartsDealer.purchase) == "function")
end

-- Phase 2.9: traveling merchant — every pool item is a real template, stops are sane, stock rotates.
function FbLabTests.checkTravelingMerchant()
	if FbTravelingMerchant == nil then check("merchant.loaded", false); return end
	local missing = {}
	for _, item in ipairs(FbTravelingMerchant.pool) do
		if not templateExists(item.template) then missing[#missing + 1] = item.name end
	end
	check("merchant.pool_templates_exist", #missing == 0, table.concat(missing, ", "))
	check("merchant.pool_size", #FbTravelingMerchant.pool >= 30, #FbTravelingMerchant.pool .. " items")
	check("merchant.stops", #FbTravelingMerchant.stops >= 5, #FbTravelingMerchant.stops .. " stops")
	local s1, s2 = FbTravelingMerchant:stockFor(1), FbTravelingMerchant:stockFor(2)
	check("merchant.stock_size", #s1 == FbTravelingMerchant.stockSize)
	check("merchant.stock_rotates", s1[1].name ~= s2[1].name, s1[1].name .. " vs " .. s2[1].name)
	check("merchant.move_event_scheduled", hasServerEvent(FbTravelingMerchant.eventName) == true)
	check("merchant.purchase_is_public", type(FbTravelingMerchant.purchase) == "function" and type(FbTravelingMerchant.move) == "function")
end

-- Phase 3.7: every ambient seat has a live patron in the right cell, and the beat is quiet with nobody near.
function FbLabTests.checkAmbientLife()
	if FbAmbientLife == nil then check("ambient.loaded", false); return end
	for li, loc in ipairs(FbAmbientLife.locations) do
		local alive, rightCell = 0, 0
		for si = 1, #loc.seats do
			local pMobile = FbAmbientLife:seatMobile(li, si)
			if pMobile ~= nil then
				alive = alive + 1
				if SceneObject(pMobile):getParentID() == loc.seats[si].cell then rightCell = rightCell + 1 end
			end
		end
		check("ambient." .. loc.key .. ".all_seats_filled", alive == #loc.seats, alive .. "/" .. #loc.seats)
		check("ambient." .. loc.key .. ".patrons_in_their_cells", rightCell == alive, rightCell .. "/" .. alive)
		check("ambient." .. loc.key .. ".has_lines", #loc.chatter >= 8 and #loc.newcomer >= 3 and #loc.emotes >= 4)
	end
end

-- Phase 3.6: galaxy chatter has a static pool, reports the merchant's current city, and expires news.
function FbLabTests.checkGalaxyChatter()
	if FbGalaxyChatter == nil then check("galaxy.loaded", false); return end
	check("galaxy.static_pool", #FbGalaxyChatter.static >= 8, #FbGalaxyChatter.static .. " lines")
	local live = FbGalaxyChatter.liveLines()
	local merchantLine = false
	if FbTravelingMerchant ~= nil then
		local label = FbTravelingMerchant.stops[FbTravelingMerchant:currentStop()].label
		for _, l in ipairs(live) do if l:find(label, 1, true) then merchantLine = true end end
	end
	check("galaxy.mentions_merchant_city", merchantLine, table.concat(live, " | "))
	FbGalaxyChatter.addNews("labtest_expired", "This line must never be heard.", -10)
	local heard = false
	for _, l in ipairs(FbGalaxyChatter.lines()) do if l == "This line must never be heard." then heard = true end end
	check("galaxy.expired_news_dropped", not heard)
	check("galaxy.ambient_uses_it", FbAmbientLife ~= nil and (FbAmbientLife.galaxyShare or 0) > 0)
end

-- Phase 3.5: the story ticker has a current story with its mobs alive and the weekly event scheduled.
function FbLabTests.checkStoryTicker()
	if FbStoryTicker == nil then check("story.loaded", false); return end
	check("story.table", #FbStoryTicker.stories >= 3, #FbStoryTicker.stories .. " stories")
	local idx = FbStoryTicker:current()
	check("story.current_set", idx >= 1 and idx <= #FbStoryTicker.stories, "current=" .. idx)
	local alive, total = FbStoryTicker:aliveSpawns()
	check("story.mobs_spawned", total > 0 and alive == total, alive .. "/" .. total .. " alive")
	check("story.weekly_event_scheduled", hasServerEvent(FbStoryTicker.eventName) == true)
	for _, st in ipairs(FbStoryTicker.stories) do
		check("story." .. st.key .. ".has_text", #st.news >= 1 and st.broadcast ~= nil and st.title ~= nil)
	end
end

-- Phase 3.2: every faction patrol route has a live leader with its members, standing on its route.
function FbLabTests.checkFactionPatrols()
	if FbFactionPatrols == nil then check("patrols.loaded", false); return end
	check("patrols.routes", #FbFactionPatrols.routes >= 2, #FbFactionPatrols.routes .. " routes")
	for ri, route in ipairs(FbFactionPatrols.routes) do
		local st = FbFactionPatrols:status(ri)
		check("patrols." .. route.key .. ".leader_alive", not st:find("leader=0 ", 1, true), st)
		local living, total = st:match("members=(%d+)/(%d+)")
		check("patrols." .. route.key .. ".members_alive", living ~= nil and living == total and tonumber(total) >= 1, st)
	end
end

-- Phase 3.10: every HoloNet relay is up in its place and the segment carries the live story.
function FbLabTests.checkHoloNet()
	if FbHoloNet == nil then check("holonet.loaded", false); return end
	for li, loc in ipairs(FbHoloNet.locations) do
		local st = FbHoloNet:status(li)
		check("holonet." .. loc.key .. ".relay_up", not st:find("relay=0 ", 1, true), st)
		check("holonet." .. loc.key .. ".in_cell", st:find("cell=" .. (loc.cell or 0), 1, true) ~= nil, st)
	end
	local lines = FbHoloNet:segment()
	check("holonet.segment_length", #lines >= 5, #lines .. " lines")
	local hasStory = false
	for _, l in ipairs(lines) do if l:find("Top story:", 1, true) then hasStory = true end end
	check("holonet.segment_has_top_story", hasStory)
end

-- Phase 3.11: the convoy screenplay is loaded with a walkable route and loot plan, and is idle or consistent.
function FbLabTests.checkConvoys()
	if FbConvoys == nil then check("convoys.loaded", false); return end
	check("convoys.cities", #FbConvoys.order >= 1, #FbConvoys.order .. " cities")
	for _, city in ipairs(FbConvoys.order) do
		local route = FbConvoys:routeFor(city)
		check("convoys." .. city .. ".route", route ~= nil and #route >= 2, route and (#route .. " points") or "no route")
		local st = FbConvoys:status(city)
		check("convoys." .. city .. ".status_readable", st:find("active=", 1, true) ~= nil, st)
	end
	check("convoys.crate_template", templateExists(FbConvoys.crateTemplate), FbConvoys.crateTemplate)
	check("convoys.loot_plan", #FbConvoys.crateLoot >= 1)
end

-- Phase 3.9: weather is readable from Lua, the sandstorm event is loaded and consistent with the sky.
function FbLabTests.checkWeatherEvents()
	if FbWeatherEvents == nil then check("weather.loaded", false); return end
	local w = getZoneWeather("tatooine")
	check("weather.readable", w ~= nil and w >= 0 and w <= 4, "base=" .. tostring(w))
	check("weather.no_manager_is_minus_one", getZoneWeather("no_such_zone") == -1)
	check("weather.parties", #FbWeatherEvents.planets.tatooine.parties >= 3)
	for _, planet in ipairs(FbWeatherEvents.order) do
		local cfg = FbWeatherEvents.planets[planet]
		for _, party in ipairs(cfg.parties or {}) do
			check("weather." .. planet .. ".party_" .. party.key .. "_on_terrain", getTerrainHeightAt(planet, party.spawn[1], party.spawn[2]) ~= 0 and getTerrainHeightAt(planet, party.rally[1], party.rally[2]) ~= 0)
		end
		local pw = getZoneWeather(planet)
		pcall(function() FbWeatherEvents:tick(planet) end)   -- the first minute tick may not have fired yet after a boot
		local st = FbWeatherEvents:status(planet)
		local active = st:find("active=1", 1, true) ~= nil
		local between = pw > (cfg.clearAt or 1) and pw < (cfg.stormAt or 3)
		check("weather." .. planet .. ".event_matches_sky", pw < 0 or between or ((pw >= (cfg.stormAt or 3)) == active), st)
	end
	local env = loadIsolated("scripts/managers/weather_manager.lua")
	check("weather.tatooine_sandstorms_damaging", env ~= nil and env.tatooine ~= nil and env.tatooine.hasDamagingSandstorms == 1)
end

-- Phase 3.1: the invasion screenplay is loaded, its city points are on terrain, its schedule is armed.
function FbLabTests.checkInvasions()
	if FbInvasions == nil then check("invasions.loaded", false); return end
	for city, cfg in pairs(FbInvasions.cities) do
		for _, k in ipairs({ "staging", "plaza", "muster" }) do
			check("invasions." .. city .. "." .. k .. "_on_terrain", getTerrainHeightAt(cfg.planet, cfg[k][1], cfg[k][2]) ~= 0)
		end
		check("invasions." .. city .. ".sides_differ", cfg.attacker ~= cfg.defender)
		local st = FbInvasions:status(city)
		check("invasions." .. city .. ".status_readable", st:find("phase=", 1, true) ~= nil, st)
	end
	check("invasions.schedule_armed", hasServerEvent(FbInvasions.eventName))
end

-- Phase 3.4: the territory map is loaded, every region is readable, thresholds are sane and the
-- readers (patrol squads, HoloNet propaganda, chatter) agree with it.
function FbLabTests.checkTerritory()
	if FbTerritory == nil then check("territory.loaded", false); return end
	check("territory.thresholds", FbTerritory.rebelAt < FbTerritory.imperialAt)
	for _, region in ipairs(FbTerritory.order) do
		local pct = FbTerritory.control(region)
		check("territory." .. region .. ".readable", pct >= 0 and pct <= 100, tostring(pct))
	end
	check("territory.unknown_region_is_minus_one", FbTerritory.control("no_such_region") == -1)
	check("territory.faction_at", FbTerritory.factionAt(100) == "imperial" and FbTerritory.factionAt(0) == "rebel" and FbTerritory.factionAt(50) == "contested")
	if FbFactionPatrols ~= nil then
		for _, route in ipairs(FbFactionPatrols.routes) do
			check("territory.patrol_" .. route.key .. "_has_region", route.region ~= nil and FbTerritory.regions[route.region] ~= nil)
			local squad = FbTerritory.squadFor(route)
			local holder = FbTerritory.faction(route.region)
			local expected = #route.members + (holder == route.faction and 1 or (holder ~= "contested" and -1 or 0))
			check("territory.patrol_" .. route.key .. "_squad_size", #squad == math.max(1, expected), #squad .. " vs " .. expected)
		end
	end
	if FbHoloNet ~= nil then
		for li, loc in ipairs(FbHoloNet.locations) do
			check("territory.holonet_" .. loc.key .. "_has_region", loc.region ~= nil and FbTerritory.regions[loc.region] ~= nil)
		end
		local hasReport = false
		for _, l in ipairs(FbHoloNet:segment(1)) do if l:find("Sector report:", 1, true) then hasReport = true end end
		check("territory.holonet_sector_report", hasReport)
	end
end

-- Phase 4.0: strings from finalboss.tre (tre-src/, built by tools/tre) reach the server. StringIdManager
-- caches every string table in the ODB at first boot; `swg start` passes reloadstrings when the archive changed.
function FbLabTests.checkTreStrings()
	local hint = " (finalboss.tre not installed in TrePath, or the server was started without reloadstrings?)"
	local first = getStringId("@fb_lab:probe_first")
	check("tre.probe_first", first == "Final Boss TRE probe: first", tostring(first) .. hint)
	local last = getStringId("@fb_lab:probe_last")
	check("tre.probe_last", last == "Final Boss TRE probe: last", tostring(last) .. hint)
	local mid = getStringId("@fb_lab:probe_middle")
	check("tre.probe_middle_escapes", mid:find("\n", 1, true) ~= nil and mid:find("%TT", 1, true) ~= nil, (mid:gsub("\n", "\\n")))
	check("tre.stock_strings_intact", getStringId("@jedi_spam:fs_progress_1") ~= "", "stock jedi_spam table unreadable")
end

-- Phase 2.11: the Trade Hall stands on its lot with every room, every tenant in a cell and the doorman
-- on the square (the placement check covers how they stand).
function FbLabTests.checkTradeHall()
	if FbTradeHall == nil then check("tradehall.loaded", false); return end
	local st = FbTradeHall:status()
	check("tradehall.open", st:find("open=1", 1, true) ~= nil, st)
	check("tradehall.nine_cells", st:find("cells=9", 1, true) ~= nil, st)
	local site = FbSites ~= nil and FbSites:get(FbTradeHall.site) or nil
	check("tradehall.site_defined", site ~= nil, "tasks/sites/mos_eisley_trade_hall.lua not loaded by FbSites")
	if site == nil then return end
	local inside, names = 0, {}
	for _, e in ipairs(FbLabTests.liveSpawns("fb_sites")) do
		if e.cell ~= 0 and SceneObject(e.pObj):getParentID() ~= 0 then inside = inside + 1 end
		names[e.template] = true
	end
	check("tradehall.tenants_inside", inside >= #site.tenants, inside .. " of " .. #site.tenants .. " tenants in a cell")
	for _, t in ipairs(site.tenants) do
		check("tradehall.tenant." .. t.template, names[t.template] == true, "not spawned by the site loader")
	end
	check("tradehall.keeper_on_square", #FbLabTests.liveSpawns("fb_trade_hall_keeper") >= 1)
end

-- Phase 2.12: the Lab Remote's screenplay, menu component and item template are wired; nobody but an
-- admin is allowed (no player object = not allowed), and the shared spawn registry sees spawns.
function FbLabTests.checkLabRemote()
	check("labremote.screenplay_loaded", FbLabRemote ~= nil)
	check("labremote.menu_component", FbLabRemoteMenuComponent ~= nil and FbLabRemoteMenuComponent.handleObjectMenuSelect ~= nil)
	check("labremote.template_included", fileContains("scripts/custom_scripts/object/serverobjects.lua", "fb_lab_remote/fb_lab_remote.lua"))
	check("labremote.denies_non_players", FbLabRemote ~= nil and FbLabRemote:allowed(nil) == false)
	check("labremote.shared_registry_populated", #FbLabTests.registryLive() > 0, "quest-status spawn registry is empty")
	if FbLabRemote ~= nil then
		local lines = FbLabTests.capture("tradeHall")
		check("labremote.capture_works", #lines > 0 and lines[1]:find("INFO tradehall", 1, true) ~= nil, tostring(lines[1]))
	end
end

-- ---------------------------------------------------------------- entry points

-- runLuaFunction passes the FbLabTests table as the first argument, then the ':'-separated args.
function FbLabTests:runAll(charName)
	results = {}
	print("INFO FbLabTests start " .. getFormattedTime())

	local ok, err = pcall(function()
		FbLabTests.checkStarterGear(charName)
		FbLabTests.checkScreenplays()
		for _, npc in ipairs(FbLabTests.discoverNpcs()) do
			FbLabTests.checkNpc(npc)
		end
		FbLabTests.checkShuttles()
		FbLabTests.checkQol()
		FbLabTests.checkStimMind()
		FbLabTests.checkInventory()
		FbLabTests.checkBazaar()
		FbLabTests.checkSchematicBroker()
		FbLabTests.checkPartsDealer()
		FbLabTests.checkTravelingMerchant()
		FbLabTests.checkAmbientLife()
		FbLabTests.checkGalaxyChatter()
		FbLabTests.checkStoryTicker()
		FbLabTests.checkFactionPatrols()
		FbLabTests.checkHoloNet()
		FbLabTests.checkConvoys()
		FbLabTests.checkWeatherEvents()
		FbLabTests.checkInvasions()
		FbLabTests.checkTerritory()
		FbLabTests.checkTreStrings()
		FbLabTests.checkTradeHall()
		FbLabTests.checkLabRemote()
		FbLabTests.checkPlacement()
		FbLabTests.checkWorldEdits()
		FbLabTests.checkAttunement()
		FbLabTests.checkTrials()
		FbLabTests.checkVisions()
		FbLabTests.checkJediMaster()
		FbLabTests.checkSithMaster()
		FbLabTests.checkAlignment()
		FbLabTests.checkKnight()
		FbLabTests.checkCompanion()
		FbLabTests.checkCrystals()
		FbLabTests.checkKits()
		FbLabTests.checkScenes()
		FbLabTests.checkCheckpoints()
		FbLabTests.checkArrivals()
		FbLabTests.checkBounty()
	end)
	if not ok then
		report("FAIL", "runAll.crashed", err)
	end

	local summary = string.format("%d passed, %d failed, %d skipped",
		results.PASS or 0, results.FAIL or 0, results.SKIP or 0)
	print("INFO summary: " .. summary)
	return summary
end

-- ---------------------------------------------------------------- scenario helpers (oracle + stage hand)
--
-- Used by tools/scenarios/*.sh through tools/swg (lab <fn>:<args>). Every helper prints one or
-- more lines starting with "INFO " (machine-readable, key=value) or "ERROR " and returns a string.
-- Pools: 0 health 1 strength 2 constitution 3 action 4 quickness 5 stamina 6 mind 7 focus 8 willpower.
-- The CreatureObject write bindings (inflictDamage, setHAM, setWounds, healDamage) take their own
-- locks, so they are safe to call from the console thread.

FbLabTests.pools = { health = 0, strength = 1, constitution = 2, action = 3, quickness = 4, stamina = 5, mind = 6, focus = 7, willpower = 8 }

local function poolIndex(name)
	if FbLabTests.pools[name] ~= nil then return FbLabTests.pools[name] end
	return tonumber(name)
end

local function onlinePlayer(charName)
	local pPlayer = charName and getPlayerByName(charName) or nil
	if pPlayer == nil then
		print("ERROR no player named " .. tostring(charName))
		return nil
	end
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost == nil or not PlayerObject(pGhost):isOnline() then
		print("ERROR " .. charName .. " is not online")
		return nil
	end
	return pPlayer
end

-- read-only helpers accept a loaded-but-offline player (link-dead right after a bot run)
local function loadedPlayer(charName)
	local pPlayer = charName and getPlayerByName(charName) or nil
	if pPlayer == nil then print("ERROR no player named " .. tostring(charName)) end
	return pPlayer
end

local function hamLine(charName, pPlayer)
	local parts = { "INFO ham", "char=" .. charName }
	local wounds = {}
	for _, name in ipairs({ "health", "action", "mind" }) do
		local i = FbLabTests.pools[name]
		parts[#parts + 1] = string.format("%s=%d/%d/%d", name,
			CreatureObject(pPlayer):getHAM(i), CreatureObject(pPlayer):getMaxHAM(i), CreatureObject(pPlayer):getBaseHAM(i))
		wounds[#wounds + 1] = string.format("%d", CreatureObject(pPlayer):getWounds(i))   -- the binding pushes a float: 300.0
	end
	-- wounds cap regeneration at max minus wounds (healDamage); a wounded character never fills up by resting
	parts[#parts + 1] = "wounds=" .. table.concat(wounds, "/")
	parts[#parts + 1] = string.format("shock=%d", CreatureObject(pPlayer):getShockWounds())
	local line = table.concat(parts, " ")
	print(line)
	return line
end

-- ham:<char> → health/action/mind as current/max/base
function FbLabTests:ham(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	return hamLine(charName, pPlayer)
end

-- progress:<char> → every XP type the character has, amount/cap (the pilot's view of whether its work pays)
function FbLabTests:progress(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost == nil then print("ERROR " .. charName .. " has no player object"); return "none" end
	local parts = {}
	for _, xpType in ipairs(PlayerObject(pGhost):getExperienceList()) do
		local amount = PlayerObject(pGhost):getExperience(xpType)
		local cap = PlayerObject(pGhost):getExperienceCap(xpType)
		table.insert(parts, string.format("%s=%d/%d", xpType, amount, cap))
	end
	table.sort(parts)
	print(string.format("INFO progress char=%s xp=%s", charName, table.concat(parts, ",")))
	return "ok"
end

-- inventory:<char> → one line per item
function FbLabTests:inventory(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local pInv = SceneObject(pPlayer):getSlottedObject("inventory")
	local n = SceneObject(pInv):getContainerObjectsSize()
	-- with the 7.5 binding the rows carry the displayed name, the type, the use count and, for a resource stack, its
	-- spawn name, class and units (Lua has no ResourceContainer methods); an older server prints oid and path only
	local rows = type(getInventoryItems) == "function" and getInventoryItems(charName) or nil
	if rows ~= nil then
		for _, r in ipairs(rows) do
			local extra = r.resource ~= nil and string.format(" resource=%s rtype=%s units=%d", (r.resource ~= "" and r.resource or "-"):gsub("%s", "_"), (r.resourceType ~= "" and r.resourceType or "-"):gsub("%s", "_"), r.units or 0) or ""
			print(string.format("INFO item oid=%d path=%s name=%s type=0x%x count=%d%s", r.oid, r.template, (r.name ~= "" and r.name or "-"):gsub("%s", "_"), r.type, r.useCount or 1, extra))
		end
		print("INFO inventory char=" .. charName .. " count=" .. #rows)
		return tostring(#rows)
	end
	for i = 0, n - 1 do
		local pItem = SceneObject(pInv):getContainerObject(i)
		if pItem ~= nil then
			print("INFO item oid=" .. SceneObject(pItem):getObjectID() .. " path=" .. SceneObject(pItem):getTemplateObjectPath())
		end
	end
	print("INFO inventory char=" .. charName .. " count=" .. n)
	return tostring(n)
end

-- bazaarNear:<char>[:<radius>] → the bazaar terminals (game object type 0x4002) within radius m (default 600) of the
-- character, nearest first, with cell-local coordinates for the ones inside buildings; the pilot's sell tool walks to
-- the first. The server accepts a bazaar sale from any distance (checkSaleItem has no range rule); the walk is manners.
function FbLabTests:bazaarNear(charName, radius)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	radius = tonumber(radius) or 600
	local zone = SceneObject(pPlayer):getZoneName()
	local px, py = SceneObject(pPlayer):getWorldPositionX(), SceneObject(pPlayer):getWorldPositionY()
	local objects = getObjectsInRange(zone, px, py, radius, 0x4002) or {}
	for _, o in ipairs(objects) do o.distance = math.sqrt((o.x - px) ^ 2 + (o.y - py) ^ 2) end
	table.sort(objects, function(a, b) return a.distance < b.distance end)
	for _, o in ipairs(objects) do
		print(string.format("INFO bazaar oid=%d name=%s x=%.1f y=%.1f z=%.1f cell=%d cellName=%s building=%d localX=%.2f localY=%.2f localZ=%.2f distance=%.0f",
			o.oid, (o.name ~= "" and o.name or "bazaar_terminal"):gsub("%s", "_"), o.x, o.y, o.z, o.cell, o.cellName ~= "" and o.cellName or "-", o.building,
			o.localX or 0, o.localY or 0, o.localZ or 0, o.distance))
	end
	print(string.format("INFO bazaars char=%s zone=%s radius=%.0f count=%d", charName, zone, radius, #objects))
	return tostring(#objects)
end

-- findItem:<char>:<fragment> → first inventory item whose template path contains <fragment>
function FbLabTests:findItem(charName, fragment)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local pInv = SceneObject(pPlayer):getSlottedObject("inventory")
	local n = SceneObject(pInv):getContainerObjectsSize()
	for i = 0, n - 1 do
		local pItem = SceneObject(pInv):getContainerObject(i)
		if pItem ~= nil then
			local path = SceneObject(pItem):getTemplateObjectPath()
			if path:find(fragment, 1, true) then
				print("INFO item oid=" .. SceneObject(pItem):getObjectID() .. " path=" .. path)
				return tostring(SceneObject(pItem):getObjectID())
			end
		end
	end
	print("ERROR no item matching '" .. tostring(fragment) .. "' in " .. charName .. "'s inventory")
	return "none"
end

-- npc:<template>[:<char>] → every live spawn of that template, with distance to <char> if given
function FbLabTests:npc(template, charName)
	local pPlayer = charName and getPlayerByName(charName) or nil
	local n = 0
	for _, s in ipairs(FbLabTests.spawns[template] or {}) do
		local pObj = getSceneObject(s.oid)
		-- a despawned object can still resolve for a while; one with no zone is not in the world
		if pObj ~= nil and SceneObject(pObj):getZoneName() ~= "" then
			local line = string.format("INFO npc template=%s oid=%d zone=%s x=%.1f y=%.1f cell=%d", template, s.oid,
				SceneObject(pObj):getZoneName(), SceneObject(pObj):getWorldPositionX(), SceneObject(pObj):getWorldPositionY(), s.cell or 0)
			if pPlayer ~= nil and SceneObject(pPlayer):getZoneName() == s.zone then
				line = line .. string.format(" dist=%.1f", SceneObject(pPlayer):getDistanceTo(pObj))
			end
			print(line)
			n = n + 1
		end
	end
	if n == 0 then print("ERROR no live spawns recorded for " .. tostring(template)) end
	return tostring(n)
end

-- inflict:<char>:<pool>:<amount> → damage the character (attacker = itself), then print ham
function FbLabTests:inflict(charName, pool, amount)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	CreatureObject(pPlayer):inflictDamage(pPlayer, poolIndex(pool), tonumber(amount), 1)
	return hamLine(charName, pPlayer)
end

-- heal:<char>:<pool>:<amount> → direct heal (bypasses items), then print ham
function FbLabTests:heal(charName, pool, amount)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	CreatureObject(pPlayer):healDamage(tonumber(amount), poolIndex(pool))
	return hamLine(charName, pPlayer)
end

-- takeItems:<char>:<fragment> → destroy every inventory item whose template path contains the fragment (a scenario
-- cleans up what it handed out: a crystal or holocron left in the shared character's bag counts for attunement)
function FbLabTests:takeItems(charName, fragment)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local pInv = SceneObject(pPlayer):getSlottedObject("inventory")
	if pInv == nil then print("ERROR no inventory"); return "none" end
	local taken = 0
	for i = SceneObject(pInv):getContainerObjectsSize() - 1, 0, -1 do
		local pItem = SceneObject(pInv):getContainerObject(i)
		if pItem ~= nil and SceneObject(pItem):getTemplateObjectPath():find(fragment, 1, true) then
			SceneObject(pItem):destroyObjectFromWorld(true); SceneObject(pItem):destroyObjectFromDatabase(); taken = taken + 1
		end
	end
	print("INFO takeItems char=" .. charName .. " fragment=" .. tostring(fragment) .. " taken=" .. taken)
	return tostring(taken)
end

-- xpSet:<char>:<type>:<amount> → that experience pool set to the amount (through awardExperience by the difference,
-- so the stock caps apply: a reused character hit the jedi_general cap and a Master's reward could not add)
function FbLabTests:xpSet(charName, xpType, amount)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost == nil then print("ERROR " .. charName .. " has no player object"); return "none" end
	local have = PlayerObject(pGhost):getExperience(xpType)
	local want = tonumber(amount) or 0
	if want ~= have then CreatureObject(pPlayer):awardExperience(xpType, want - have, false) end
	print(string.format("INFO xpSet char=%s type=%s was=%d now=%d", charName, tostring(xpType), have, PlayerObject(pGhost):getExperience(xpType)))
	return "ok"
end

-- revive:<char> → a dead or incapacitated lab character back on its feet with full pools (what a cloning would do,
-- without the cloner); harmless on a healthy one
function FbLabTests:revive(charName)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	local c = CreatureObject(pPlayer)
	local was = string.format("dead=%s incap=%s posture=%d", tostring(c:isDead()), tostring(c:isIncapacitated()), c:getPosture())
	-- only a character that is down: a seated one must stay seated across a login (the shrine meditation and the
	-- Masters' sit tasks count on it; standing everyone up at every login failed all of them, gate 2026-10-22)
	c:clearCombatState(true)   -- always: a lab character left "in combat" is refused a hunt, a talk, a sit
	if not (c:isDead() or c:isIncapacitated() or c:getPosture() == 13 or c:getPosture() == 14) then
		print("INFO revive char=" .. charName .. " not needed (" .. was .. "), combat cleared")
		return "ok"
	end
	for _, pool in ipairs({ 0, 3, 6 }) do c:setHAM(pool, c:getMaxHAM(pool)) end
	-- a real posture change: setPosture is a no-op when the posture already reads upright, and the locomotion
	-- (what every queued command checks) is only recomputed on a change — a character that died kept
	-- locomotion DEAD under an upright posture and could not start a talk (CommandQueueRemove error=1 state=20)
	c:setPosture(1)
	c:setPosture(0)
	-- the transient states a character can be left in: a talk is refused with INVALIDSTATE while any is set
	-- (SITTINGONCHAIR 0x80000 survived a stand and cost a gate, 2026-10-22; CreatureState.h)
	for _, st in ipairs({ 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x400, 0x1000, 0x2000, 0x4000, 0x8000, 0x10000, 0x20000, 0x80000, 0x100000 }) do
		if c:hasState(st) then c:clearState(st) end
	end
	print("INFO revive char=" .. charName .. " was " .. was .. " now dead=" .. tostring(c:isDead()) .. " posture=" .. c:getPosture())
	return "ok"
end

-- wound:<char>:<pool>:<amount> → set wounds on a pool, then print ham
function FbLabTests:wound(charName, pool, amount)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	CreatureObject(pPlayer):setWounds(poolIndex(pool), tonumber(amount))
	return hamLine(charName, pPlayer)
end

-- give:<char>:<templatePath> → put an item in the inventory
function FbLabTests:give(charName, template)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	local pInv = SceneObject(pPlayer):getSlottedObject("inventory")
	local pItem = giveItem(pInv, template, -1)
	if pItem == nil then
		print("ERROR giveItem failed for " .. tostring(template))
		return "failed"
	end
	print("INFO item oid=" .. SceneObject(pItem):getObjectID() .. " path=" .. SceneObject(pItem):getTemplateObjectPath())
	return tostring(SceneObject(pItem):getObjectID())
end

-- skill:<char>:<skillName> → award a skill (e.g. science_medic_novice)
function FbLabTests:skill(charName, skillName)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	awardSkill(pPlayer, skillName)
	-- a box with prerequisites the character lacks (the Jedi titles want the Jedi state, the rank boxes a Knight):
	-- the lab wants the box, not the path to it
	if not CreatureObject(pPlayer):hasSkill(skillName) and awardSkillUnchecked ~= nil then awardSkillUnchecked(pPlayer, skillName) end
	print("INFO skill char=" .. charName .. " awarded=" .. skillName .. " has=" .. tostring(CreatureObject(pPlayer):hasSkill(skillName)))
	return tostring(CreatureObject(pPlayer):hasSkill(skillName))
end

-- skillDrop:<char>:<skillName> → surrender a skill box (SkillManager::surrenderSkill: experience is not refunded; a box
-- another held box depends on stays). The training scenario resets the shared lab character with it.
function FbLabTests:skillDrop(charName, skillName)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	if CreatureObject(pPlayer):hasSkill(skillName) then CreatureObject(pPlayer):surrenderSkill(skillName) end
	print("INFO skillDrop char=" .. charName .. " skill=" .. skillName .. " has=" .. tostring(CreatureObject(pPlayer):hasSkill(skillName)))
	return tostring(not CreatureObject(pPlayer):hasSkill(skillName))
end

-- hasSkill:<char>:<skillName> → whether a loaded character has that skill box (7.2: citizen status)
function FbLabTests:hasSkill(charName, skillName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then print("ERROR hasSkill: no loaded player " .. tostring(charName)); return "none" end
	local has = CreatureObject(pPlayer):hasSkill(skillName)
	print("INFO hasSkill char=" .. charName .. " skill=" .. skillName .. " has=" .. tostring(has))
	return tostring(has)
end

-- skillmod:<char>:<modName> → current value of a skill mod (e.g. healing_ability)
function FbLabTests:skillmod(charName, modName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "none" end
	local v = math.floor(CreatureObject(pPlayer):getSkillMod(modName))   -- bindings hand back floats; scripts compare integers
	print("INFO skillmod char=" .. charName .. " " .. modName .. "=" .. string.format("%d", v))
	return string.format("%d", v)
end

-- travel:<char>:<planet>:<x>:<y> → move the character (cross-planet allowed), z from the terrain
function FbLabTests:travel(charName, planet, x, y)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	x, y = tonumber(x), tonumber(y)
	-- height in the *destination* zone (getTerrainHeight uses the creature's current zone)
	local z = getTerrainHeightAt(planet, x, y)
	SceneObject(pPlayer):switchZone(planet, x, z, y, 0)
	print(string.format("INFO travel char=%s planet=%s x=%.1f z=%.1f y=%.1f", charName, planet, x, z, y))
	return "ok"
end

-- where:<char> → current position
function FbLabTests:where(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local line = string.format("INFO where char=%s oid=%d zone=%s x=%.1f z=%.1f y=%.1f cell=%d lx=%.2f ly=%.2f posture=%d combat=%s incap=%s dead=%s swimming=%s", charName,
		SceneObject(pPlayer):getObjectID(), SceneObject(pPlayer):getZoneName(),
		SceneObject(pPlayer):getWorldPositionX(), SceneObject(pPlayer):getWorldPositionZ(), SceneObject(pPlayer):getWorldPositionY(),
		SceneObject(pPlayer):getParentID(), SceneObject(pPlayer):getPositionX(), SceneObject(pPlayer):getPositionY(), CreatureObject(pPlayer):getPosture(),
		tostring(CreatureObject(pPlayer):isInCombat()), tostring(CreatureObject(pPlayer):isIncapacitated()), tostring(CreatureObject(pPlayer):isDead()), tostring(CreatureObject(pPlayer):hasState(262144) == 1))
	print(line)
	return line
end

-- runLuaFunction FbLabTests:isOnline:<firstName> — cheap poll used by tools/swg test bot.
-- inventoryLimit:<char> → the live inventory's item count and persisted containerVolumeLimit
function FbLabTests:inventoryLimit(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "none" end
	local pInventory = CreatureObject(pPlayer):getSlottedObject("inventory")
	if pInventory == nil then print("ERROR " .. charName .. " has no inventory"); return "none" end
	local limit = SceneObject(pInventory):getContainerVolumeLimit()
	local count = SceneObject(pInventory):getCountableObjectsRecursive()
	print(string.format("INFO inventory char=%s count=%d limit=%d", charName, count, limit))
	return tostring(limit)
end

-- spawnObjectNear:<char>:<template>:<dx>:<dy> → spawn a scene object (e.g. a mission terminal) next
-- to the character, at their height; prints oid. Clean up with destroyObject:<oid>.
function FbLabTests:spawnObjectNear(charName, template, dx, dy)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "none" end
	local zone = SceneObject(pPlayer):getZoneName()
	local x = SceneObject(pPlayer):getWorldPositionX() + (tonumber(dx) or 0)
	local y = SceneObject(pPlayer):getWorldPositionY() + (tonumber(dy) or 0)
	local z = SceneObject(pPlayer):getWorldPositionZ()
	local pObject = spawnSceneObject(zone, template, x, z, y, 0, 0)
	if pObject == nil then print("ERROR spawnSceneObject failed for " .. tostring(template)); return "none" end
	print(string.format("INFO spawned oid=%s template=%s zone=%s x=%d y=%d", tostring(SceneObject(pObject):getObjectID()), template, zone, x, y))
	return tostring(SceneObject(pObject):getObjectID())
end

-- destroyObject:<oid> → remove a lab-spawned object from the world and the database
function FbLabTests:destroyObject(oid)
	local pObject = getSceneObject(tonumber(oid))
	if pObject == nil then print("ERROR no object " .. tostring(oid)); return "none" end
	SceneObject(pObject):destroyObjectFromWorld(true)
	SceneObject(pObject):destroyObjectFromDatabase()
	-- forget it in the spawn registry too, so the spawned/placement checks never count a removed probe
	for template, list in pairs(FbLabTests.spawns) do
		for i = #list, 1, -1 do
			if list[i].oid == tonumber(oid) then table.remove(list, i) end
		end
	end
	FbLabTests.registryRemove(oid)
	print("INFO destroyed oid=" .. tostring(oid))
	return "ok"
end

-- missions:<char> → one line per mission in the character's mission bag (after a terminal list request)
function FbLabTests:missions(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "none" end
	local pBag = CreatureObject(pPlayer):getSlottedObject("mission_bag")
	if pBag == nil then print("ERROR " .. charName .. " has no mission bag"); return "none" end
	local n = SceneObject(pBag):getContainerObjectsSize()
	local shown = 0
	for i = 0, n - 1 do
		local pMission = SceneObject(pBag):getContainerObject(i)
		if pMission ~= nil and LuaMissionObject(pMission):getTypeCRC() ~= 0 then
			shown = shown + 1
			print(string.format("INFO mission i=%d type=%d lvl=%d reward=%d planet=%s start=%.0f,%.0f creator=%s",
				i, LuaMissionObject(pMission):getTypeCRC(), LuaMissionObject(pMission):getDifficultyLevel(),
				LuaMissionObject(pMission):getRewardCredits(), LuaMissionObject(pMission):getStartPlanet(),
				LuaMissionObject(pMission):getStartPositionX(), LuaMissionObject(pMission):getStartPositionY(),
				LuaMissionObject(pMission):getCreatorName()))
		end
	end
	print(string.format("INFO missions char=%s bag=%d randomized=%d", charName, n, shown))
	return tostring(shown)
end

-- missionDir:<char>[:<N|NE|E|SE|S|SW|W|NW|any>] → read or set the character's mission direction (what the terminal radial stores)
function FbLabTests:missionDir(charName, dir)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "none" end
	if dir ~= nil then writeScreenPlayData(pPlayer, "FbMissionDir", "dir", dir == "any" and "" or dir) end
	local cur = readScreenPlayData(pPlayer, "FbMissionDir", "dir")
	print(string.format("INFO missionDir char=%s dir=%s", charName, (cur ~= nil and cur ~= "") and cur or "any"))
	return (cur ~= nil and cur ~= "") and cur or "any"
end

-- xp:<char>:<type> → the character's experience of one type (dance, music, combat_general, …)
function FbLabTests:xp(charName, xpType)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "none" end
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost == nil then print("ERROR " .. charName .. " has no player object"); return "none" end
	local amount = PlayerObject(pGhost):getExperience(xpType)
	print(string.format("INFO xp char=%s type=%s amount=%d", charName, tostring(xpType), amount))
	return tostring(amount)
end

-- setInventoryLimit:<char>:<n> → force the persisted limit (scenarios use it to simulate an old character)
function FbLabTests:setInventoryLimit(charName, limit)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "none" end
	local pInventory = CreatureObject(pPlayer):getSlottedObject("inventory")
	if pInventory == nil then print("ERROR " .. charName .. " has no inventory"); return "none" end
	SceneObject(pInventory):setContainerVolumeLimit(tonumber(limit))
	return FbLabTests:inventoryLimit(charName)
end

-- loginHook:<char> → run FBLogin.onLogin on a loaded character by hand, then print the inventory line
function FbLabTests:loginHook(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "none" end
	if FBLogin == nil then print("ERROR FBLogin not loaded in this Lua state"); return "none" end
	FBLogin.onLogin(pPlayer)
	return FbLabTests:inventoryLimit(charName)
end

-- inventoryTemplateLimit → what fb_inventory_100.lua registers, read in a sandbox (templates live
-- in another Lua state)
function FbLabTests:inventoryTemplateLimit()
	local captured
	local env = setmetatable({
		ObjectTemplates = { addTemplate = function(_, template) captured = template.containerVolumeLimit end },
	}, { __index = function(_, key)
		local v = _G[key]
		if v ~= nil then return v end
		return {}
	end })
	env._G = env
	local chunk, err = loadfile("scripts/custom_scripts/object/tangible/inventory/fb_inventory_100.lua", "t", env)
	if chunk == nil then print("ERROR " .. tostring(err)); return "none" end
	local ok, rerr = pcall(chunk)
	if not ok then print("ERROR " .. tostring(rerr)); return "none" end
	print("INFO inventory_template limit=" .. tostring(captured))
	return tostring(captured)
end

-- cash:<char> → cash and bank credits
function FbLabTests:cash(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "none" end
	local cash = CreatureObject(pPlayer):getCashCredits()
	print(string.format("INFO credits char=%s cash=%d bank=%d", charName, cash, CreatureObject(pPlayer):getBankCredits()))
	return tostring(cash)
end

-- buySchematic:<char>:<catIdx>:<itemIdx>  or  buySchematic:<char>:<item name>
-- → FbSchematicBroker:purchase() without the SUI window; the name form survives catalogue edits
function FbLabTests:buySchematic(charName, catIdx, itemIdx)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	if FbSchematicBroker == nil then print("ERROR FbSchematicBroker not loaded"); return "none" end
	local c, i = tonumber(catIdx), tonumber(itemIdx)
	if c == nil then
		for ci, cat in ipairs(FbSchematicBroker.categories) do
			for ii, item in ipairs(cat.items) do
				if item.name == catIdx then c, i = ci, ii end
			end
		end
		if c == nil then print("ERROR no catalogue item named '" .. tostring(catIdx) .. "'"); return "bad_item" end
	end
	local item = FbSchematicBroker.categories[c].items[i]
	local result = FbSchematicBroker:purchase(pPlayer, c, i)
	print(string.format("INFO buySchematic cat=%d item=%d name=%s price=%d skill=%s result=%s",
		c, i, item and item.name or "?", item and item.price or 0, item and item.skill or "", tostring(result)))
	return tostring(result)
end

-- hasSchematic:<char>:<draft iff path> → 1/0
function FbLabTests:hasSchematic(charName, draftPath)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "none" end
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost == nil then print("ERROR no player object"); return "none" end
	local has = PlayerObject(pGhost):hasSchematic(draftPath) and 1 or 0
	print(string.format("INFO schematic char=%s draft=%s has=%d", charName, draftPath, has))
	return tostring(has)
end

-- buyPart:<char>:<item name>  or  buyPart:<char>:<catIdx>:<itemIdx> → FbPartsDealer:purchase()
function FbLabTests:buyPart(charName, catIdx, itemIdx)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	if FbPartsDealer == nil then print("ERROR FbPartsDealer not loaded"); return "none" end
	local c, i = tonumber(catIdx), tonumber(itemIdx)
	if c == nil then
		for ci, cat in ipairs(FbPartsDealer.categories) do
			for ii, item in ipairs(cat.items) do
				if item.name == catIdx then c, i = ci, ii end
			end
		end
		if c == nil then print("ERROR no part named '" .. tostring(catIdx) .. "'"); return "bad_item" end
	end
	local item = FbPartsDealer.categories[c].items[i]
	local result = FbPartsDealer:purchase(pPlayer, c, i)
	print(string.format("INFO buyPart cat=%d item=%d name=%s loot=%s level=%d price=%d result=%s",
		c, i, item and item.name or "?", item and item.loot or "?", item and item.level or 0, item and item.price or 0, tostring(result)))
	return tostring(result)
end

-- questStatus:<key>[:<value>] → read (or set) a global quest-status entry; screenplays keep
-- cross-state data there (e.g. FbTravelingMerchant.stop / .visit / .oid; keys must not contain ":")
function FbLabTests:questStatus(key, value)
	if value ~= nil then setQuestStatus(key, tostring(value)) end
	local current = getQuestStatus(key)
	print(string.format("INFO queststatus key=%s value=%s", tostring(key), tostring(current)))
	return tostring(current)
end

-- stringId:<file>:<key> → the text the server resolves for @file:key ("" when unknown)
function FbLabTests:stringId(file, key)
	local id = "@" .. tostring(file) .. ":" .. tostring(key)
	local v = getStringId(id)
	print(string.format("INFO stringid id=%s text=%s", id, (tostring(v):gsub("\n", "\\n"))))
	return v
end

-- systemMessage:<char>:<file>:<key> → send @file:key to an online character as a string-id system message
-- (the client renders it from its own copy of the string table; the bot logs the id)
function FbLabTests:systemMessage(charName, file, key)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then print("ERROR " .. tostring(charName) .. " is not online"); return "offline" end
	local id = "@" .. tostring(file) .. ":" .. tostring(key)
	CreatureObject(pPlayer):sendSystemMessage(id)
	print(string.format("INFO systemmessage char=%s id=%s", charName, id))
	return "sent"
end

-- merchant → where the traveling merchant is and what he sells this visit
function FbLabTests:merchant()
	if FbTravelingMerchant == nil then print("ERROR FbTravelingMerchant not loaded"); return "none" end
	print("INFO merchant " .. FbTravelingMerchant:status())
	local stock = FbTravelingMerchant:stockFor(FbTravelingMerchant:visit())
	for i, item in ipairs(stock) do
		print(string.format("INFO merchant_item i=%d price=%d name=%s template=%s", i, item.price, item.name, item.template))
	end
	return tostring(#stock)
end

-- merchantShowStock:<char> → open the merchant's stock window for an online character by hand,
-- reporting any Lua error the conversation handler would have swallowed
function FbLabTests:merchantShowStock(charName)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	if FbTravelingMerchant == nil then print("ERROR FbTravelingMerchant not loaded"); return "none" end
	local ok, err = pcall(function() FbTravelingMerchant:showStock(pPlayer, nil) end)
	print("INFO merchantShowStock ok=" .. tostring(ok) .. " err=" .. tostring(err))
	return tostring(ok)
end

-- merchantStops → one line per configured stop
function FbLabTests:merchantStops()
	if FbTravelingMerchant == nil then print("ERROR FbTravelingMerchant not loaded"); return "none" end
	for i, stop in ipairs(FbTravelingMerchant.stops) do
		print(string.format("INFO merchant_stop idx=%d planet=%s label=%s x=%d y=%d", i, stop.planet, stop.label, stop.x, stop.y))
	end
	return tostring(#FbTravelingMerchant.stops)
end

-- merchantMove[:<stopIdx>] → relocate the traveling merchant now (what the 3-hour server event does)
function FbLabTests:merchantMove(target)
	if FbTravelingMerchant == nil then print("ERROR FbTravelingMerchant not loaded"); return "none" end
	local status = FbTravelingMerchant:move(tonumber(target))
	print("INFO merchant " .. status)
	return status
end

-- buyMerchant:<char>:<item name> → FbTravelingMerchant:purchase() for the named item of this visit
function FbLabTests:buyMerchant(charName, itemName)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	if FbTravelingMerchant == nil then print("ERROR FbTravelingMerchant not loaded"); return "none" end
	local stock = FbTravelingMerchant:stockFor(FbTravelingMerchant:visit())
	for i, item in ipairs(stock) do
		if item.name == itemName then
			local result = FbTravelingMerchant:purchase(pPlayer, i)
			print(string.format("INFO buyMerchant idx=%d name=%s price=%d result=%s", i, item.name, item.price, tostring(result)))
			return tostring(result)
		end
	end
	print("ERROR '" .. tostring(itemName) .. "' is not in this visit's stock"); return "bad_item"
end

-- travelCell:<char>:<planet>:<x>:<z>:<y>:<cellID> → teleport into a building cell (travel: is outdoors only)
function FbLabTests:travelCell(charName, planet, x, z, y, cellID)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	SceneObject(pPlayer):switchZone(planet, tonumber(x), tonumber(z), tonumber(y), tonumber(cellID))
	print(string.format("INFO travelCell char=%s planet=%s x=%s z=%s y=%s cell=%s", charName, planet, x, z, y, cellID))
	return "ok"
end

-- territory → one INFO line: every region's Imperial % and holder
function FbLabTests:territory()
	if FbTerritory == nil then print("ERROR FbTerritory not loaded"); return "none" end
	print("INFO territory " .. FbTerritory.status())
	return "ok"
end

-- territorySet:<region>:<pct> → set a region's Imperial % (no news); prints the holder
function FbLabTests:territorySet(region, pct)
	if FbTerritory == nil then print("ERROR FbTerritory not loaded"); return "none" end
	local v = FbTerritory.set(region, pct)
	print(string.format("INFO territorySet region=%s pct=%d faction=%s", tostring(region), v, FbTerritory.faction(region)))
	return tostring(v)
end

-- territoryShift:<region>:<delta> → shift with the news/broadcast side effects; prints the new %
function FbLabTests:territoryShift(region, delta)
	if FbTerritory == nil then print("ERROR FbTerritory not loaded"); return "none" end
	local v = FbTerritory.shift(region, tonumber(delta) or 0, "lab")
	print(string.format("INFO territoryShift region=%s pct=%d faction=%s", tostring(region), v, FbTerritory.faction(region)))
	return tostring(v)
end

-- objectPos:<oid> → one INFO line with an object's zone, world position, combat flag and HAM
function FbLabTests:objectPos(oid)
	local p = getSceneObject(tonumber(oid))
	if p == nil then print("ERROR no object " .. tostring(oid)); return "none" end
	local extra = ""
	if SceneObject(p):isCreatureObject() then
		extra = string.format(" combat=%s dead=%s ham=%d/%d", tostring(CreatureObject(p):isInCombat()), tostring(CreatureObject(p):isDead()), CreatureObject(p):getHAM(0), CreatureObject(p):getMaxHAM(0))
	end
	print(string.format("INFO objectPos oid=%s zone=%s x=%.1f y=%.1f z=%.1f heading=%.1f cell=%d%s", tostring(oid), SceneObject(p):getZoneName(),
		SceneObject(p):getWorldPositionX(), SceneObject(p):getWorldPositionY(), SceneObject(p):getWorldPositionZ(), SceneObject(p):getDirectionAngle() % 360, SceneObject(p):getParentID(), extra))
	return "ok"
end

-- teleportObject:<oid>:<planet>:<x>:<y> → move any scene object (NPC, prop) to terrain height there
function FbLabTests:teleportObject(oid, planet, x, y)
	local p = getSceneObject(tonumber(oid))
	if p == nil then print("ERROR no object " .. tostring(oid)); return "none" end
	x, y = tonumber(x), tonumber(y)
	local z = getTerrainHeightAt(planet, x, y)
	SceneObject(p):switchZone(planet, x, z, y, 0)
	if SceneObject(p):isAiAgent() then AiAgent(p):setHomeLocation(x, z, y, nil) end   -- or it leashes straight back
	print(string.format("INFO teleportObject oid=%s planet=%s x=%.0f y=%.0f z=%.1f", tostring(oid), planet, x, y, z))
	return "ok"
end

-- invasion[:<city>] → the invasion's status line
function FbLabTests:invasion(city)
	if FbInvasions == nil then print("ERROR FbInvasions not loaded"); return "none" end
	print("INFO invasion " .. FbInvasions:status(city or "bestine"))
	return "ok"
end

-- invasionBegin[:<city>] → construction phase now (what the 6 h schedule does)
function FbLabTests:invasionBegin(city)
	if FbInvasions == nil then print("ERROR FbInvasions not loaded"); return "none" end
	print("INFO invasion " .. tostring(FbInvasions:begin(city or "bestine")))
	return "ok"
end

-- invasionAssault[:<city>] → combat phase now
function FbLabTests:invasionAssault(city)
	if FbInvasions == nil then print("ERROR FbInvasions not loaded"); return "none" end
	print("INFO invasion " .. tostring(FbInvasions:assault(city or "bestine")))
	return "ok"
end

-- invasionResolve[:<city>[:force]] → decide the battle now; prints outcome=
function FbLabTests:invasionResolve(city, force)
	if FbInvasions == nil then print("ERROR FbInvasions not loaded"); return "none" end
	local out = FbInvasions:resolve(city or "bestine", force)
	print("INFO invasionResolve outcome=" .. tostring(out))
	return tostring(out)
end

-- invasionEngage[:<city>] → pair idle attackers near the plaza with defenders now; prints pairs=
function FbLabTests:invasionEngage(city)
	if FbInvasions == nil then print("ERROR FbInvasions not loaded"); return "none" end
	local n = FbInvasions:engage(city or "bestine")
	print("INFO invasionEngage pairs=" .. tostring(n))
	return tostring(n)
end

-- invasionSide:<city>:<attackers|defenders> → the living oids of one side, comma-separated
function FbLabTests:invasionSide(city, side)
	local oids = getQuestStatus("FbInvasions." .. (city or "bestine") .. "." .. (side or "attackers")) or ""
	print("INFO invasionSide side=" .. tostring(side) .. " oids=" .. oids)
	return oids
end

-- weather[:<zone>] → the zone's base weather (0 clear .. 4 extreme storm)
function FbLabTests:weather(zone)
	zone = zone or "tatooine"
	local w = getZoneWeather(zone)
	print(string.format("INFO weather zone=%s base=%d", zone, w))
	return tostring(w)
end

-- weatherSet:<zone>:<0-4> → force the zone's base weather (the automatic pattern keeps running)
function FbLabTests:weatherSet(zone, w)
	local now = setZoneWeather(zone or "tatooine", tonumber(w) or 0)
	print(string.format("INFO weatherSet zone=%s base=%d", zone or "tatooine", now))
	return tostring(now)
end

-- storm[:<planet>] → the storm event's status line (default tatooine)
function FbLabTests:storm(planet)
	if FbWeatherEvents == nil then print("ERROR FbWeatherEvents not loaded"); return "none" end
	print("INFO storm " .. FbWeatherEvents:status(planet))
	return "ok"
end

-- stormTick[:<planet>] → evaluate the weather now instead of waiting for the minute tick; prints what it did
function FbLabTests:stormTick(planet)
	if FbWeatherEvents == nil then print("ERROR FbWeatherEvents not loaded"); return "none" end
	local did = FbWeatherEvents:tick(planet)
	print("INFO stormTick did=" .. tostring(did) .. " " .. FbWeatherEvents:status(planet))
	return did
end

-- convoy[:<city>] → the convoy event's status line (default the first city, Mos Eisley)
function FbLabTests:convoy(city)
	if FbConvoys == nil then print("ERROR FbConvoys not loaded"); return "none" end
	print("INFO convoy " .. FbConvoys:status(city))
	return "ok"
end

-- convoySpawn[:<city>] → form a convoy now (what the 30-60 min schedule does)
function FbLabTests:convoySpawn(city)
	if FbConvoys == nil then print("ERROR FbConvoys not loaded"); return "none" end
	print("INFO convoy " .. tostring(FbConvoys:spawn(city)))
	return "ok"
end

-- convoyArrive[:<city>] → the convoy reaches its destination now (despawn, news, +5 territory)
function FbLabTests:convoyArrive(city)
	if FbConvoys == nil then print("ERROR FbConvoys not loaded"); return "none" end
	print("INFO convoy " .. tostring(FbConvoys:arrive(city)))
	return "ok"
end

-- cities → one INFO line per city in the registry (3.13)
function FbLabTests:cities()
	if FbCities == nil then print("ERROR FbCities not loaded"); return "none" end
	for _, c in ipairs(FbCities.list) do
		print(string.format("INFO city key=%s planet=%s label=%s lean=%d patrols=%d relays=%d ambient=%d convoy=%s invasion=%s", c.key, c.planet, c.label:gsub(" ", "_"),
			c.lean, (c.patrols.imperial and 1 or 0) + (c.patrols.rebel and 1 or 0), #c.relays, #c.ambient, c.convoy and "1" or "0", c.invasion and "1" or "0"))
	end
	return tostring(#FbCities.list)
end

-- killNpc:<char>:<oid> → the character deals a lethal blow to an NPC (observers see the character as attacker)
function FbLabTests:killNpc(charName, oid)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	local pNpc = getSceneObject(tonumber(oid))
	if pNpc == nil or not SceneObject(pNpc):isCreatureObject() then print("ERROR no creature " .. tostring(oid)); return "none" end
	CreatureObject(pNpc):inflictDamage(pPlayer, 0, 1000000, 1)
	local dead = CreatureObject(pNpc):isDead() and 1 or 0
	print(string.format("INFO killNpc oid=%s dead=%d", tostring(oid), dead))
	return tostring(dead)
end

-- factionStanding:<char>:<faction> → the character's standing with rebel / imperial
function FbLabTests:factionStanding(charName, faction)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "none" end
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost == nil then print("ERROR no player object"); return "none" end
	local v = PlayerObject(pGhost):getFactionStanding(faction)
	print(string.format("INFO faction char=%s faction=%s standing=%.0f", charName, faction, v))
	return tostring(math.floor(v))
end

-- containerItems:<oid> → one INFO line per item inside a container object (e.g. a loot crate)
function FbLabTests:containerItems(oid)
	local pBox = getSceneObject(tonumber(oid))
	if pBox == nil then print("ERROR no object " .. tostring(oid)); return "none" end
	local n = SceneObject(pBox):getContainerObjectsSize()
	for i = 0, n - 1 do
		local pItem = SceneObject(pBox):getContainerObject(i)
		if pItem ~= nil then print(string.format("INFO container_item i=%d oid=%d path=%s", i, SceneObject(pItem):getObjectID(), SceneObject(pItem):getTemplateObjectPath())) end
	end
	print(string.format("INFO container oid=%s count=%.0f", tostring(oid), n))
	return string.format("%.0f", n)
end

-- holonet → one INFO line per HoloNet relay (oid, cell, players near)
function FbLabTests:holonet()
	if FbHoloNet == nil then print("ERROR FbHoloNet not loaded"); return "none" end
	for li, loc in ipairs(FbHoloNet.locations) do
		print(string.format("INFO holonet %s planet=%s x=%s y=%s z=%s", FbHoloNet:status(li), loc.planet, tostring(loc.x), tostring(loc.y), tostring(loc.z or "terrain")))
	end
	return tostring(#FbHoloNet.locations)
end

-- holonetSegment → the lines the next broadcast would read
function FbLabTests:holonetSegment()
	if FbHoloNet == nil then print("ERROR FbHoloNet not loaded"); return "none" end
	local lines = FbHoloNet:segment()
	for i, l in ipairs(lines) do print(string.format("INFO holonet_line i=%d text=%s", i, l)) end
	return tostring(#lines)
end

-- holonetBroadcast[:<loc>] → read a segment now at a relay; prints the line count
function FbLabTests:holonetBroadcast(li)
	if FbHoloNet == nil then print("ERROR FbHoloNet not loaded"); return "none" end
	local n = FbHoloNet:broadcast(li or 1)
	print("INFO holonetBroadcast lines=" .. tostring(n))
	return tostring(n)
end

-- patrols → one INFO line per faction patrol route (leader oid/position, members alive, point)
function FbLabTests:patrols()
	if FbFactionPatrols == nil then print("ERROR FbFactionPatrols not loaded"); return "none" end
	for ri, route in ipairs(FbFactionPatrols.routes) do
		local pt = route.points[1]
		print("INFO patrol " .. FbFactionPatrols:status(ri) .. string.format(" planet=%s start=%d,%d points=%d", route.planet, pt[1], pt[3], #route.points))
	end
	return tostring(#FbFactionPatrols.routes)
end

-- patrolStep:<route> → send the squad to its next point now; prints the status afterwards
-- patrolRespawn:<route> → replace a patrol squad now (what happens when one dies); prints its status
function FbLabTests:patrolRespawn(ri)
	if FbFactionPatrols == nil then print("ERROR FbFactionPatrols not loaded"); return "none" end
	print("INFO patrolRespawn " .. tostring(FbFactionPatrols:respawn(tonumber(ri) or 1)))
	return "ok"
end

function FbLabTests:patrolStep(ri)
	if FbFactionPatrols == nil then print("ERROR FbFactionPatrols not loaded"); return "none" end
	local result = FbFactionPatrols:step(tonumber(ri) or 1)
	print("INFO patrolStep result=" .. tostring(result))
	print("INFO patrol " .. FbFactionPatrols:status(tonumber(ri) or 1))
	return tostring(result)
end

-- objectAlive:<oid> → 1 if the object resolves and is in a zone, else 0
function FbLabTests:objectAlive(oid)
	local p = getSceneObject(tonumber(oid))
	-- a corpse is still an object in the zone for a while: a dead creature counts as not alive
	local alive = (p ~= nil and SceneObject(p):getZoneName() ~= "" and not (SceneObject(p):isCreatureObject() and CreatureObject(p):isDead())) and 1 or 0
	print(string.format("INFO object oid=%s alive=%d", tostring(oid), alive))
	return tostring(alive)
end

-- story → the story ticker's current story, its live mobs and whether the weekly event is scheduled
function FbLabTests:story()
	if FbStoryTicker == nil then print("ERROR FbStoryTicker not loaded"); return "none" end
	print("INFO story " .. FbStoryTicker:status())
	for i, st in ipairs(FbStoryTicker.stories) do
		local n = 0
		for _, g in ipairs(st.mobs) do n = n + g.count end
		print(string.format("INFO story_def idx=%d key=%s planet=%s x=%d y=%d mobs=%d", i, st.key, st.planet, st.x, st.y, n))
	end
	return tostring(FbStoryTicker:current())
end

-- storyFire:<idx> → run a story now (news, broadcast, mobs), as the weekly event would
function FbLabTests:storyFire(idx)
	if FbStoryTicker == nil then print("ERROR FbStoryTicker not loaded"); return "none" end
	local status = FbStoryTicker:fire(tonumber(idx))
	print("INFO story " .. tostring(status))
	return tostring(status)
end

-- galaxyNews → every line the galaxy chatter can say right now (static + live + posted news)
function FbLabTests:galaxyNews()
	if FbGalaxyChatter == nil then print("ERROR FbGalaxyChatter not loaded"); return "none" end
	local lines = FbGalaxyChatter.lines()
	for i, l in ipairs(lines) do print(string.format("INFO galaxy_line i=%d text=%s", i, l)) end
	print("INFO galaxy static=" .. #FbGalaxyChatter.static .. " live=" .. #FbGalaxyChatter.liveLines() .. " news=" .. #FbGalaxyChatter.newsLines() .. " total=" .. #lines)
	return tostring(#lines)
end

-- galaxyAddNews:<key>:<ttlSeconds>:<text> → post a dated news line (what the Phase 3.5 ticker will do)
function FbLabTests:galaxyAddNews(key, ttl, text)
	if FbGalaxyChatter == nil then print("ERROR FbGalaxyChatter not loaded"); return "none" end
	FbGalaxyChatter.addNews(key, text, tonumber(ttl))
	print("INFO galaxy_news_added key=" .. tostring(key))
	return "ok"
end

-- ambientLocations → one INFO line per ambient-life location with its anchor (for the lab to teleport to)
function FbLabTests:ambientLocations()
	if FbAmbientLife == nil then print("ERROR FbAmbientLife not loaded"); return "none" end
	for li, loc in ipairs(FbAmbientLife.locations) do
		print(string.format("INFO ambient_location idx=%d key=%s planet=%s x=%.1f z=%.1f y=%.1f cell=%d seats=%d",
			li, loc.key, loc.planet, loc.anchor.x, loc.anchor.z, loc.anchor.y, loc.anchor.cell, #loc.seats))
	end
	return tostring(#FbAmbientLife.locations)
end

-- ambient[:<loc>] → one INFO seat line per ambient patron of a location (default 1)
function FbLabTests:ambient(li)
	if FbAmbientLife == nil then print("ERROR FbAmbientLife not loaded"); return "none" end
	local status = FbAmbientLife:status(li or 1)
	local n = 0
	for line in status:gmatch("[^\n]+") do print("INFO ambient " .. line); n = n + 1 end
	return tostring(n)
end

-- ambientTick[:<loc>] → force one ambience beat; prints what happened
function FbLabTests:ambientTick(li)
	if FbAmbientLife == nil then print("ERROR FbAmbientLife not loaded"); return "none" end
	local result = FbAmbientLife:tick(li or 1)
	print("INFO ambientTick result=" .. tostring(result))
	return tostring(result)
end

-- ambientChurn[:<loc>[:<seat>]] → replace the patron in a seat; prints the new oid
function FbLabTests:ambientChurn(li, si)
	if FbAmbientLife == nil then print("ERROR FbAmbientLife not loaded"); return "none" end
	local oid = FbAmbientLife:churn(li or 1, si)
	print("INFO ambientChurn seat=" .. tostring(si or "random") .. " oid=" .. tostring(oid))
	return tostring(oid)
end

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

-- ---------------------------------------------------------------- NPC placement (find, goto, audit)

-- Every recorded spawn that is still in the world, optionally filtered by oid, template, source file or
-- displayed-name substring (case-insensitive). Each entry: oid, pObj, template, src, zone, cell, x, y, z
-- (where it was spawned), name.
-- Spawns made from other Lua states (seat churn and relay respawns run on worker threads, whose
-- FbLabTests.spawns table the console never sees) are reached through the modules' own quest-status
-- backed lookups instead. Add a provider here when a module respawns things after start().
local function providedSpawns()
	local out = {}
	if FbAmbientLife ~= nil and FbAmbientLife.locations ~= nil then
		for li, loc in ipairs(FbAmbientLife.locations) do
			for si, seat in ipairs(loc.seats) do
				local pMobile = FbAmbientLife:seatMobile(li, si)
				if pMobile ~= nil then
					out[#out + 1] = { oid = SceneObject(pMobile):getObjectID(), zone = loc.planet, cell = seat.cell or 0, x = seat.x, y = seat.y, z = seat.z,
						template = "seat:" .. loc.key .. ":" .. si, src = "fb_ambient_life" }
				end
			end
		end
	end
	if FbHoloNet ~= nil and FbHoloNet.locations ~= nil then
		for li, loc in ipairs(FbHoloNet.locations) do
			local pRelay = FbHoloNet:relay(li)
			if pRelay ~= nil then
				out[#out + 1] = { oid = SceneObject(pRelay):getObjectID(), zone = loc.planet, cell = loc.cell or 0, x = loc.x, y = loc.y, z = loc.z,
					template = FbHoloNet.mobile or "fb_holonet_relay", src = "fb_holonet" }
			end
		end
	end
	return out
end

function FbLabTests.liveSpawns(filter)
	local out = {}
	local f = filter ~= nil and tostring(filter):lower() or nil
	local seen = {}
	local all = {}
	for template, list in pairs(FbLabTests.spawns) do
		for _, s in ipairs(list) do all[#all + 1] = s; s.template = s.template or template end
	end
	for _, s in ipairs(providedSpawns()) do all[#all + 1] = s end
	for _, s in ipairs(FbLabTests.registryLive()) do all[#all + 1] = s end
	for _, s in ipairs(all) do
		local template = s.template
		if not seen[s.oid] then
			seen[s.oid] = true
			local pObj = getSceneObject(s.oid)
			if pObj ~= nil and SceneObject(pObj):getZoneName() ~= "" and not (SceneObject(pObj):isCreatureObject() and CreatureObject(pObj):isDead()) then
				local name = SceneObject(pObj):getDisplayedName()
				local hit = f == nil or tostring(s.oid) == f or template:lower():find(f, 1, true) ~= nil
					or (s.src ~= nil and s.src:lower():find(f, 1, true) ~= nil) or name:lower():find(f, 1, true) ~= nil
				if hit then
					out[#out + 1] = { oid = s.oid, pObj = pObj, template = template, src = s.src, zone = s.zone, cell = s.cell or 0,
						x = s.x, y = s.y, z = s.z, name = name }
				end
			end
		end
	end
	-- an oid nobody recorded (a stock NPC, a probe from another state): audit it anyway
	if #out == 0 and f ~= nil and tonumber(f) ~= nil then
		local pObj = getSceneObject(tonumber(f))
		if pObj ~= nil and SceneObject(pObj):getZoneName() ~= "" then
			out[1] = { oid = tonumber(f), pObj = pObj, template = SceneObject(pObj):getObjectName(), src = nil, zone = SceneObject(pObj):getZoneName(),
				cell = SceneObject(pObj):getParentID(), x = SceneObject(pObj):getWorldPositionX(), y = SceneObject(pObj):getWorldPositionY(),
				z = SceneObject(pObj):getWorldPositionZ(), name = SceneObject(pObj):getDisplayedName() }
		end
	end
	table.sort(out, function(a, b) return a.oid < b.oid end)
	return out
end

local function spawnLine(e)
	local pObj = e.pObj
	local wx, wy, wz = SceneObject(pObj):getWorldPositionX(), SceneObject(pObj):getWorldPositionY(), SceneObject(pObj):getWorldPositionZ()
	local drift = (e.x ~= nil and e.cell == 0) and math.sqrt((wx - e.x) ^ 2 + (wy - e.y) ^ 2) or 0
	return string.format("oid=%d name=%s template=%s src=%s zone=%s x=%.1f y=%.1f z=%.1f cell=%d drift=%.1f",
		e.oid, (e.name:gsub(" ", "_")), e.template, tostring(e.src), SceneObject(pObj):getZoneName(), wx, wy, wz, SceneObject(pObj):getParentID(), drift), wx, wy, wz
end

-- findNpc[:<filter>] → one line per live Final Boss spawn (name, template, source file, position)
function FbLabTests:findNpc(filter)
	local list = FbLabTests.liveSpawns(filter)
	for _, e in ipairs(list) do print("INFO npc " .. (spawnLine(e))) end
	if #list == 0 then print("INFO findNpc none: no live spawn matches " .. tostring(filter)) end   -- a lookup miss is an answer, not an error
	return tostring(#list)
end

-- gotoNpc:<char>:<filter> → put the character 2 m in front of the first matching NPC (same cell), facing it
function FbLabTests:gotoNpc(charName, filter)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	local e = FbLabTests.liveSpawns(filter)[1]
	if e == nil then print("ERROR no live spawn matches " .. tostring(filter)); return "none" end
	local pNpc = e.pObj
	-- in front of the NPC, in its own (cell-local) coordinates; a cramped shop can put "2 m ahead"
	-- behind a counter or through a portal, so try a few spots and keep the first the NPC can see
	local a = SceneObject(pNpc):getDirectionAngle()
	local lx, ly, lz = SceneObject(pNpc):getPositionX(), SceneObject(pNpc):getPositionY(), SceneObject(pNpc):getPositionZ()
	local cell = SceneObject(pNpc):getParentID()
	local zone = SceneObject(pNpc):getZoneName()
	local tries = { { 1.5, 0 }, { 2.5, 0 }, { 1.5, math.pi / 2 }, { 1.5, -math.pi / 2 }, { 1.5, math.pi }, { 1.0, 0 } }
	local spot = "?"
	for i, t in ipairs(tries) do
		local tx, ty = lx + t[1] * math.sin(a + t[2]), ly + t[1] * math.cos(a + t[2])
		SceneObject(pPlayer):switchZone(zone, tx, lz, ty, cell)
		spot = string.format("try=%d d=%.1f", i, t[1])
		if not SceneObject(pNpc):isAiAgent() or AiAgent(pNpc):checkLineOfSight(pPlayer) then break end
	end
	SceneObject(pPlayer):faceObject(pNpc, true)
	print(string.format("INFO gotoNpc char=%s %s %s", charName, spot, (spawnLine(e))))
	return "ok"
end

-- waypointTo:<char>:<filter> → a datapad waypoint on the first matching NPC (world coordinates)
function FbLabTests:waypointTo(charName, filter)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local e = FbLabTests.liveSpawns(filter)[1]
	if e == nil then print("ERROR no live spawn matches " .. tostring(filter)); return "none" end
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost == nil then print("ERROR no player object"); return "none" end
	local line, wx, wy, wz = spawnLine(e)
	local wp = PlayerObject(pGhost):addWaypoint(SceneObject(e.pObj):getZoneName(), "Lab: " .. e.name, e.template .. " (" .. tostring(e.src) .. ")", wx, wz, wy, 2, true, true, 0)
	print(string.format("INFO waypointTo char=%s waypoint=%s %s", charName, tostring(wp), line))
	return "ok"
end

-- Line of sight from the NPC to a probe placed <dist> m away in <n> compass directions (same cell).
-- Returns the number of clear directions and the pattern ("N.E.S.W." style, '.' = blocked).
FbLabTests.probeTemplate = "object/tangible/furniture/all/frn_all_tiki_torch_s1.iff"
local function losAround(pNpc, dist, n)
	if not SceneObject(pNpc):isAiAgent() then return nil end
	local zone = SceneObject(pNpc):getZoneName()
	local cell = SceneObject(pNpc):getParentID()
	local lx, ly, lz = SceneObject(pNpc):getPositionX(), SceneObject(pNpc):getPositionY(), SceneObject(pNpc):getPositionZ()
	local clear, pattern = 0, ""
	for i = 0, n - 1 do
		local a = i * (2 * math.pi / n)
		local px, py = lx + dist * math.sin(a), ly + dist * math.cos(a)
		local pz = lz
		if cell == 0 then pz = getTerrainHeightAt(zone, px, py) end
		local pProbe = spawnSceneObject(zone, FbLabTests.probeTemplate, px, pz, py, cell, 0)
		local ok = false
		if pProbe ~= nil then
			ok = AiAgent(pNpc):checkLineOfSight(pProbe)
			SceneObject(pProbe):destroyObjectFromWorld(true)
			SceneObject(pProbe):destroyObjectFromDatabase()
		end
		if ok then clear = clear + 1 end
		pattern = pattern .. (ok and "o" or ".")
	end
	return clear, pattern
end

-- One NPC's placement facts: los (clear directions of 8 at 3 m), floor (outdoor: height above the
-- terrain), drift (outdoor: metres from where it was spawned, unless its file is a walker).
-- verdict: ok | warn | fail. A wall-embedded NPC gets 0–1 clear directions; a corner gets 3–4.
function FbLabTests.placementOf(e)
	local pNpc = e.pObj
	local line, wx, wy, wz = spawnLine(e)
	local facts = { verdict = "ok", reasons = {} }
	local clear, pattern = losAround(pNpc, 3, 8)
	facts.los, facts.pattern = clear, pattern
	if clear ~= nil then
		if clear <= 1 then facts.verdict = "fail"; facts.reasons[#facts.reasons + 1] = "boxed in (" .. pattern .. ")"
		elseif clear <= 3 then facts.verdict = "warn"; facts.reasons[#facts.reasons + 1] = "mostly obstructed (" .. pattern .. ")" end
	end
	if SceneObject(pNpc):getParentID() == 0 then
		local floor = wz - getTerrainHeightAt(SceneObject(pNpc):getZoneName(), wx, wy)
		facts.floor = floor
		if math.abs(floor) > 3 then
			facts.verdict = "fail"
			facts.reasons[#facts.reasons + 1] = string.format("%.1f m off the terrain", floor)
		elseif math.abs(floor) > 1.5 then
			facts.verdict = (facts.verdict == "fail") and "fail" or "warn"
			facts.reasons[#facts.reasons + 1] = string.format("%.1f m off the terrain", floor)
		end
		local drift = tonumber(line:match("drift=([%d%.]+)")) or 0
		if drift > 3 and not FbLabTests.walkerSources[e.src or ""] then
			facts.verdict = (facts.verdict == "fail") and "fail" or "warn"
			facts.reasons[#facts.reasons + 1] = string.format("wandered %.0f m from its spot", drift)
		end
	end
	-- a walker caught mid-step (a follower crossing a terrace, a squad in a narrow street) is not a placement: for the
	-- walking sources only a wildly wrong height (world coordinates where cell-local ones were meant) is a failure
	if FbLabTests.walkerSources[e.src or ""] and facts.verdict == "fail" and math.abs(facts.floor or 0) <= 30 then
		facts.verdict = "warn"
	end
	facts.line = line
	return facts
end

-- placement[:<filter>] → audit every live Final Boss spawn (or the matching ones); returns the number
-- of fail verdicts. INFO lines carry the facts, WARN/FAIL lines the problems.
function FbLabTests:placement(filter)
	local list = FbLabTests.liveSpawns(filter)
	local fails, warns, gone = 0, 0, 0
	for _, e in ipairs(list) do
		-- a spawn another thread removes while the audit runs (a cantina seat churning, a visitor fading) loses its
		-- zone and collapses to cell-local coordinates: that reads as "boxed in", so check the zone around the audit
		local f = SceneObject(e.pObj):getZoneName() ~= "" and FbLabTests.placementOf(e) or nil
		if f == nil or SceneObject(e.pObj):getZoneName() == "" then
			gone = gone + 1
			print(string.format("INFO placement oid=%d name=%s template=%s src=%s verdict=gone why=removed_during_the_audit",
				e.oid, (e.name:gsub(" ", "_")), e.template, tostring(e.src)))
		else
			print(string.format("INFO placement %s los=%s/8 pattern=%s floor=%s verdict=%s why=%s", f.line, tostring(f.los), tostring(f.pattern),
				f.floor and string.format("%.1f", f.floor) or "-", f.verdict, (table.concat(f.reasons, ";"):gsub(" ", "_"))))
			if f.verdict == "fail" then fails = fails + 1; print("FAIL placement " .. e.name .. " (" .. e.oid .. "): " .. table.concat(f.reasons, "; "))
			elseif f.verdict == "warn" then warns = warns + 1; print("WARN placement " .. e.name .. " (" .. e.oid .. "): " .. table.concat(f.reasons, "; ")) end
		end
	end
	print(string.format("INFO placement summary spawns=%d fail=%d warn=%d gone=%d", #list - gone, fails, warns, gone))
	return tostring(fails)
end

-- creatureHam:<oid> → health/action/mind of any creature (an NPC or a wild animal, by oid): how a fight is going
function FbLabTests:creatureHam(oid)
	local p = getSceneObject(tonumber(oid))
	if p == nil or not SceneObject(p):isCreatureObject() then print("ERROR creatureHam: no creature " .. tostring(oid)); return "none" end
	local c = CreatureObject(p)
	print(string.format("INFO creatureHam oid=%s name=%s level=%d health=%d/%d action=%d/%d mind=%d/%d dead=%s incap=%s", tostring(oid),
		(SceneObject(p):getDisplayedName():gsub(" ", "_")), c:getLevel(), c:getHAM(0), c:getMaxHAM(0), c:getHAM(3), c:getMaxHAM(3), c:getHAM(6), c:getMaxHAM(6),
		tostring(c:isDead()), tostring(c:isIncapacitated())))
	return tostring(c:getHAM(0))
end

-- A character's fighting strength for the pilot: the level the server computes from a weapon line
-- (PlayerManager::calculatePlayerLevel: private_<weapon>_combat_difficulty / 100 + 1, capped at 25), taken over every
-- line. The stored level is only recomputed when a skill box is awarded, so a veteran start made unarmed reads level 1
-- for ever (Teyla: level 1, rifle difficulty 1150 = strength 12).
local STRENGTH_LINES = { "unarmed", "onehandmelee", "twohandmelee", "polearm", "pistol", "carbine", "rifle", "heavyweapon" }
local function fightingStrength(pPlayer)
	local best = 0
	for _, w in ipairs(STRENGTH_LINES) do
		local mod = CreatureObject(pPlayer):getSkillMod("private_" .. w .. "_combat_difficulty") or 0
		if mod > best then best = mod end
	end
	return math.min(25, math.floor(best / 100) + 1)
end

-- level:<char> → the stored level (what every con, mission terminal and aggro check reads), the weapon line held, and
-- the fighting strength (the level the best line would give). The two differ when the weapon changed since the last skill
-- award; the login hook (FBLogin.recomputeLevel, 7.5) brings the stored one up to the weapon in hand.
function FbLabTests:level(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local pWeapon = SceneObject(pPlayer):getSlottedObject("hold_r")
	local held = "none"
	if pWeapon ~= nil then held = SceneObject(pWeapon):getTemplateObjectPath() end
	print(string.format("INFO level char=%s stored=%d strength=%d held=%s", charName, CreatureObject(pPlayer):getLevel(),
		fightingStrength(pPlayer), held))
	return tostring(CreatureObject(pPlayer):getLevel())
end

-- threats:<char>[:<radius>] → every live AI agent within radius (default 150 m) that is aggressive to the character
-- (isAggressiveTo: aggressive creatures, enemy factions) or a wild creature above its strength: name, level, distance;
-- first an INFO me line with the character's stored level and fighting strength. Five level-19 Tusken raiders of the
-- story camp at 3985,-4770 took Teyla's 1100 health in one tick while she shot a worrt (2026-10-23): the pilot never
-- saw them because the perception listed creatures, not NPCs.
function FbLabTests:threats(charName, radius)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	radius = tonumber(radius) or 150
	local zone = SceneObject(pPlayer):getZoneName()
	local px, py = SceneObject(pPlayer):getWorldPositionX(), SceneObject(pPlayer):getWorldPositionY()
	local strength = fightingStrength(pPlayer)
	print(string.format("INFO me char=%s level=%d strength=%d x=%.1f y=%.1f", charName, CreatureObject(pPlayer):getLevel(), strength, px, py))
	local objects = getObjectsInRange(zone, px, py, radius)
	if objects == nil then print("ERROR threats: no zone " .. tostring(zone)); return "none" end
	local n = 0
	for _, o in ipairs(objects) do
		if o.type == 0x400 or o.type == 0x401 then
			local p = getSceneObject(o.oid)
			if p ~= nil and SceneObject(p):isAiAgent() and not CreatureObject(p):isDead() then
				local level = CreatureObject(p):getLevel()
				local aggressive = AiAgent(p):isAggressiveTo(pPlayer)
				if aggressive or (o.type == 0x400 and level > strength) then
					n = n + 1
					local d = math.sqrt((o.x - px) ^ 2 + (o.y - py) ^ 2)
					print(string.format("INFO threat oid=%d name=%s template=%s level=%d distance=%.0f aggressive=%s x=%.1f y=%.1f",
						o.oid, (o.name or ""):gsub("%s", "_"), tostring(o.template), level, d, tostring(aggressive), o.x, o.y))
				end
			end
		end
	end
	print(string.format("INFO threats char=%s radius=%d count=%d strength=%d", charName, radius, n, strength))
	return tostring(n)
end

-- ---------------------------------------------------------------- training (7.5: a citizen buys skill boxes at a trainer)

-- trainable:<char>[:all] → the skill boxes the character can buy at a trainer right now (INFO trainable: prerequisites,
-- experience and skill points all met, the stock canLearnSkill) and the boxes it is working toward (INFO next:
-- prerequisites met, experience or points short), for every profession it already holds a box of; `all` adds the
-- novice box of every other profession. Each line names the trainer type (the mobile template of the NPC who
-- teaches it: trainers:<planet>:<type> finds one), the experience type with have/cost, the credits and the points.
function FbLabTests:trainable(charName, scope)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	if trainerSkills == nil then print("ERROR trainable: trainerSkills (screenplays/trainers/trainerData.lua) not loaded"); return "none" end
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost == nil then print("ERROR trainable: " .. charName .. " has no player object"); return "none" end
	local sm = LuaSkillManager()
	local types = {}
	for t in pairs(trainerSkills) do table.insert(types, t) end
	table.sort(types)
	local n, ready = 0, 0
	for _, trainerType in ipairs(types) do
		local list = trainerSkills[trainerType]
		local inside = false
		for _, s in ipairs(list) do
			if CreatureObject(pPlayer):hasSkill(s) then inside = true; break end
		end
		for _, s in ipairs(list) do
			local novice = s:find("_novice$") ~= nil
			if not CreatureObject(pPlayer):hasSkill(s) and (inside or (scope == "all" and novice)) and sm:fulfillsSkillPrerequisites(pPlayer, s) then
				local pSkill = sm:getSkill(s)
				if pSkill ~= nil then
					local sk = LuaSkill(pSkill)
					local xpType, xpCost = sk:getXpType(), sk:getXpCost()
					local have = (xpType ~= nil and xpType ~= "") and PlayerObject(pGhost):getExperience(xpType) or 0
					local can = sm:canLearnSkill(pPlayer, s, false)
					if can then ready = ready + 1 end
					print(string.format("INFO %s skill=%s trainer=%s xpType=%s xpHave=%d xpCost=%d credits=%d points=%d",
						can and "trainable" or "next", s, trainerType, (xpType ~= nil and xpType ~= "") and xpType or "-", have, xpCost,
						sk:getMoneyRequired(), sk:getSkillPointsRequired()))
					n = n + 1
				end
			end
		end
	end
	print(string.format("INFO training char=%s trainable=%d next=%d cash=%d bank=%d level=%d strength=%d", charName, ready, n - ready,
		CreatureObject(pPlayer):getCashCredits(), CreatureObject(pPlayer):getBankCredits(), CreatureObject(pPlayer):getLevel(), fightingStrength(pPlayer)))
	return tostring(ready)
end

-- trainers:<planet>:<trainerType>[:<x>:<y>] → every trainer NPC of that type (its mobile template name, e.g.
-- trainer_rifleman) within 500 m of a travel point of the planet, nearest to x,y first (or to its travel point), with
-- the point it stands by; cell-local coordinates for one indoors (what pathTo/walk want).
function FbLabTests:trainers(planet, trainerType, x, y)
	local env, err = loadIsolated("scripts/managers/planet/planet_manager.lua")
	if env == nil then print("ERROR trainers: planet_manager.lua: " .. tostring(err)); return "none" end
	local cfg = env[planet]
	if cfg == nil or cfg.planetTravelPoints == nil then print("ERROR trainers: no travel points for " .. tostring(planet)); return "none" end
	if trainerType == nil or trainerType == "" then print("ERROR trainers: planet trainerType [x y]"); return "none" end
	x, y = tonumber(x), tonumber(y)
	local seen, rows = {}, {}
	for _, pt in ipairs(cfg.planetTravelPoints) do
		for _, o in ipairs(getObjectsInRange(planet, pt.x, pt.y, 500, 0x401) or {}) do
			if not seen[o.oid] then
				seen[o.oid] = true
				local p = getSceneObject(o.oid)
				if p ~= nil and SceneObject(p):isAiAgent() and AiAgent(p):getCreatureTemplateName() == trainerType and not CreatureObject(p):isDead() then
					local d = (x ~= nil and y ~= nil) and math.sqrt((o.x - x) ^ 2 + (o.y - y) ^ 2) or math.sqrt((o.x - pt.x) ^ 2 + (o.y - pt.y) ^ 2)
					table.insert(rows, { o = o, point = pt.name:gsub("%s", "_"), d = d })
				end
			end
		end
	end
	table.sort(rows, function(a, b) return a.d < b.d end)
	for _, r in ipairs(rows) do
		local o = r.o
		print(string.format("INFO trainer oid=%d name=%s type=%s x=%.1f y=%.1f z=%.1f cell=%d cellName=%s building=%d localX=%.2f localY=%.2f localZ=%.2f point=%s distance=%.0f",
			o.oid, (o.name or ""):gsub("%s", "_"), trainerType, o.x, o.y, o.z, o.cell, o.cellName ~= "" and o.cellName or "-", o.building,
			o.localX or 0, o.localY or 0, o.localZ or 0, r.point, r.d))
	end
	print(string.format("INFO trainers planet=%s type=%s count=%d", planet, trainerType, #rows))
	return tostring(#rows)
end

-- clinic:<planet>[:<x>:<y>] → the FB-21 medical droids on the planet (live spawns of fb_mos_eisley_medical_droid, one in each
-- medcenter: cell-local coordinates for the walk), nearest to x,y first. The droid clears wounds and shock for free (2.6) — the
-- only wound care a citizen has: regeneration stops at max minus wounds, and Teyla sat wounded for two days (2026-10-28).
function FbLabTests:clinic(planet, x, y)
	x, y = tonumber(x), tonumber(y)
	local rows = {}
	for _, e in ipairs(FbLabTests.liveSpawns(nil)) do
		local pObj = e.pObj
		if e.template == "fb_mos_eisley_medical_droid" and pObj ~= nil and SceneObject(pObj):getZoneName() == planet and not CreatureObject(pObj):isDead() then
			local wx, wy, wz = SceneObject(pObj):getWorldPositionX(), SceneObject(pObj):getWorldPositionY(), SceneObject(pObj):getWorldPositionZ()
			local d = (x ~= nil and y ~= nil) and math.sqrt((wx - x) ^ 2 + (wy - y) ^ 2) or 0
			rows[#rows + 1] = { oid = e.oid, name = e.name, wx = wx, wy = wy, wz = wz, cell = SceneObject(pObj):getParentID(),
				lx = SceneObject(pObj):getPositionX(), ly = SceneObject(pObj):getPositionY(), lz = SceneObject(pObj):getPositionZ(), d = d }
		end
	end
	table.sort(rows, function(a, b) return a.d < b.d end)
	for _, r in ipairs(rows) do
		print(string.format("INFO clinic oid=%d name=%s x=%.1f y=%.1f z=%.1f cell=%d localX=%.2f localY=%.2f localZ=%.2f distance=%.0f",
			r.oid, (r.name:gsub("%s", "_")), r.wx, r.wy, r.wz, r.cell, r.lx, r.ly, r.lz, r.d))
	end
	print(string.format("INFO clinics planet=%s count=%d", planet, #rows))
	return tostring(#rows)
end

-- resourceNear:<planet>:<resource>[:<radius>] → for every travel point of the planet, the best buildable land spot of that
-- resource within radius m (default 1500, a 250 m grid): where a harvester can stand within a walk of a shuttle.
function FbLabTests:resourceNear(planet, resource, radius)
	radius = tonumber(radius) or 1500
	local env, err = loadIsolated("scripts/managers/planet/planet_manager.lua")
	local cfg = env ~= nil and env[planet] or nil
	if cfg == nil or cfg.planetTravelPoints == nil then print("ERROR resourceNear: no travel points for " .. tostring(planet) .. " " .. tostring(err)); return "none" end
	local points = cfg.planetTravelPoints
	local n = 0
	for _, tp in ipairs(points) do
		local bx, by, bd = nil, nil, 0
		for dy = -radius, radius, 250 do
			for dx = -radius, radius, 250 do
				local x, y = tp.x + dx, tp.y + dy
				if x > -8191 and x < 8191 and y > -8191 and y < 8191 then
					local d = getResourceDensityAt(resource, planet, x, y) or 0
					if d > bd then
						-- land, and a lot may be placed there (a town's no-build belt reaches 700–900 m past its walls)
						local water = getWaterHeightAt(planet, x, y)
						if (water == nil or getTerrainHeightAt(planet, x, y) >= water) and isBuildingPermittedAt(planet, x, y) then bx, by, bd = x, y, d end
					end
				end
			end
		end
		if bx ~= nil and bd >= 0.1 then
			n = n + 1
			print(string.format("INFO resourceNear planet=%s resource=%s point=%s px=%.0f py=%.0f x=%.0f y=%.0f density=%.2f distance=%.0f",
				planet, resource, tp.name, tp.x, tp.y, bx, by, bd, math.sqrt((bx - tp.x) ^ 2 + (by - tp.y) ^ 2)))
		end
	end
	return tostring(n)
end

-- canBuildNear:<planet>:<x>:<y>[:<radius>] → is a structure permitted at x,y and, if not, the nearest permitted land point
-- within radius m (default 200, 25 m rings): where to step to when a placement is refused as not_permitted.
function FbLabTests:canBuildNear(planet, x, y, radius)
	x, y, radius = tonumber(x), tonumber(y), tonumber(radius) or 200
	if planet == nil or x == nil or y == nil then print("ERROR canBuildNear: planet x y [radius]"); return "none" end
	local function ok(px, py)
		if px <= -8191 or px >= 8191 or py <= -8191 or py >= 8191 then return false end
		local water = getWaterHeightAt(planet, px, py)
		return isBuildingPermittedAt(planet, px, py) and (water == nil or getTerrainHeightAt(planet, px, py) >= water)
	end
	if ok(x, y) then print(string.format("INFO canBuildNear planet=%s x=%.0f y=%.0f permitted=true", planet, x, y)); return "true" end
	for r = 25, radius, 25 do
		for k = 0, 15 do
			local px, py = x + r * math.cos(k * math.pi / 8), y + r * math.sin(k * math.pi / 8)
			if ok(px, py) then
				print(string.format("INFO canBuildNear planet=%s x=%.0f y=%.0f permitted=false nearestX=%.0f nearestY=%.0f distance=%d", planet, x, y, px, py, r))
				return "false"
			end
		end
	end
	print(string.format("INFO canBuildNear planet=%s x=%.0f y=%.0f permitted=false nearest=none within %d m", planet, x, y, radius))
	return "false"
end

-- pendingTask:<char>:<name>[:cancel] → is a pending task of that name registered on the character (survey, sample,
-- incapacitationRecovery, …); with cancel it is removed. A survey task left pending makes every later requestsurvey a
-- silent no-op (RequestSurveyCommand returns SUCCESS without a word).
function FbLabTests:pendingTask(charName, taskName, cancel)
	local pPlayer = getPlayerByName(charName)
	if pPlayer == nil then print("ERROR pendingTask: no player " .. tostring(charName)); return "none" end
	local had = SceneObject(pPlayer):hasPendingTaskNamed(taskName)
	if cancel == "cancel" and had then SceneObject(pPlayer):cancelPendingTaskNamed(taskName) end
	print(string.format("INFO pendingTask char=%s task=%s pending=%s%s", charName, taskName, tostring(had),
		(cancel == "cancel" and had) and " cancelled=true" or ""))
	return tostring(had)
end

-- spawnNpcAt:<template>:<planet>:<x>:<y>[:<cell>[:<z>]] → a mobile for placement experiments (recorded
-- like any FB spawn; remove with destroyObject)
function FbLabTests:spawnNpcAt(template, planet, x, y, cell, z)
	x, y, cell = tonumber(x), tonumber(y), tonumber(cell) or 0
	z = tonumber(z) or getTerrainHeightAt(planet, x, y)
	local pMobile = spawnMobile(planet, template, 0, x, z, y, 0, cell)
	if pMobile == nil then print("ERROR spawnMobile failed for " .. tostring(template)); return "none" end
	AiAgent(pMobile):addObjectFlag(AI_STATIC)
	local oid = SceneObject(pMobile):getObjectID()
	-- stock templates spawned from the console carry no fb_ source: record them by hand
	local list = FbLabTests.spawns[template] or {}
	if list[#list] == nil or list[#list].oid ~= oid then
		list[#list + 1] = { oid = oid, zone = planet, cell = cell, x = x, y = y, z = z, template = template, src = "lab" }
		FbLabTests.spawns[template] = list
		FbLabTests.registryAdd(list[#list])
	end
	-- read the object back by its id: two gates (2026-10-27) saw a console spawn report the id of a cantina patron
	-- churned on another thread, and the scenario then destroyed the patron. Until that is understood, a mismatch is an error.
	local pBack = getSceneObject(oid)
	local backTemplate = pBack ~= nil and SceneObject(pBack):getObjectName() or "-"
	local backX = pBack ~= nil and SceneObject(pBack):getWorldPositionX() or 0
	print(string.format("INFO spawnNpcAt oid=%d template=%s planet=%s x=%.1f y=%.1f z=%.1f cell=%d back=%s backX=%.1f", oid, template, planet, x, y, z, cell, tostring(backTemplate):gsub("%s", "_"), backX))
	if pBack ~= pMobile then print("ERROR spawnNpcAt: the object at that id is not the one just spawned"); return "none" end
	return tostring(oid)
end

-- oidInfo:<oid> → what object an id resolves to (template, name, position, cell, zone)
function FbLabTests:oidInfo(oid)
	local p = getSceneObject(tonumber(oid))
	if p == nil then print("INFO oid=" .. tostring(oid) .. " none=1"); return "none" end
	local mobile = "-"
	if SceneObject(p):isAiAgent() then mobile = AiAgent(p):getCreatureTemplateName() end
	print(string.format("INFO oid=%s template=%s mobile=%s name=%s zone=%s x=%.1f y=%.1f z=%.1f cell=%d", tostring(oid), SceneObject(p):getTemplateObjectPath(), mobile,
		tostring(SceneObject(p):getObjectName()):gsub("%s", "_"), SceneObject(p):getZoneName(), SceneObject(p):getWorldPositionX(), SceneObject(p):getWorldPositionY(),
		SceneObject(p):getWorldPositionZ(), SceneObject(p):getParentID()))
	return "ok"
end

-- Lab check: no placed Final Boss NPC is boxed into geometry, floating, or has wandered off (one
-- check per spawn; walkers only get the line-of-sight part).
function FbLabTests.checkPlacement()
	local list = FbLabTests.liveSpawns(nil)
	check("placement.spawns_recorded", #list > 0, #list .. " live spawns")
	for _, e in ipairs(list) do
		local f = FbLabTests.placementOf(e)
		local label = "placement." .. (e.src or e.template) .. "." .. e.name:gsub("[^%w]", "_") .. "." .. e.oid
		if f.verdict == "fail" then
			check(label, false, table.concat(f.reasons, "; ") .. " @ " .. f.line)
		elseif f.verdict == "warn" then
			print("WARN " .. label .. " — " .. table.concat(f.reasons, "; ") .. " @ " .. f.line)
		else
			check(label, true)
		end
	end
end

-- ---------------------------------------------------------------- buildings (lab)

-- spawnBuildingAt:<template>:<planet>:<x>:<y>[:<heading deg>] → a (non-persistent) structure on the
-- terrain, as the mall screenplay does it; prints the cells. Remove with destroyObject.
function FbLabTests:spawnBuildingAt(template, planet, x, y, heading)
	x, y = tonumber(x), tonumber(y)
	local z = getTerrainHeightAt(planet, x, y)
	local rad = math.rad(tonumber(heading) or 0)
	local pBuilding = spawnSceneObject(planet, template, x, z, y, 0, math.cos(rad / 2), 0, math.sin(rad / 2), 0)
	if pBuilding == nil then print("ERROR spawnSceneObject failed for " .. tostring(template)); return "none" end
	local oid = SceneObject(pBuilding):getObjectID()
	print(string.format("INFO building oid=%d template=%s planet=%s x=%.1f y=%.1f z=%.1f", oid, template, planet, x, y, z))
	FbLabTests:buildingInfo(oid)
	return tostring(oid)
end

-- buildingInfo:<oid> → one line per cell (oid, name) and the corner heights of the lot
function FbLabTests:buildingInfo(oid)
	local p = getSceneObject(tonumber(oid))
	if p == nil or not SceneObject(p):isBuildingObject() then print("ERROR no building " .. tostring(oid)); return "none" end
	local n = BuildingObject(p):getTotalCellNumber()
	for i = 1, n do
		local pCell = BuildingObject(p):getCell(i)
		if pCell ~= nil then
			print(string.format("INFO cell building=%s idx=%d oid=%d name=%s", tostring(oid), i, SceneObject(pCell):getObjectID(), tostring(BuildingObject(p):getCellName(i))))
		end
	end
	local zone = SceneObject(p):getZoneName()
	local bx, by, bz = SceneObject(p):getWorldPositionX(), SceneObject(p):getWorldPositionY(), SceneObject(p):getWorldPositionZ()
	local hs = {}
	for _, d in ipairs({ {-12, -12}, {12, -12}, {-12, 12}, {12, 12}, {0, 0} }) do
		hs[#hs + 1] = string.format("%.1f", getTerrainHeightAt(zone, bx + d[1], by + d[2]) - bz)
	end
	print(string.format("INFO lot building=%s zone=%s x=%.1f y=%.1f z=%.1f cells=%d corner_dz=%s", tostring(oid), zone, bx, by, bz, n, table.concat(hs, ",")))
	return tostring(n)
end

-- tradeHall → the Trade Hall's status line plus the lot's corner heights (lot_ok=1 when the terrain under
-- the building's four corners is within 1.5 m of its floor)
function FbLabTests:tradeHall()
	if FbTradeHall == nil then print("ERROR FbTradeHall not loaded"); return "none" end
	local st = FbTradeHall:status()
	local lotOk = 0
	local pBuilding = FbTradeHall:building()
	if pBuilding ~= nil then
		local zone = SceneObject(pBuilding):getZoneName()
		local bx, by, bz = SceneObject(pBuilding):getWorldPositionX(), SceneObject(pBuilding):getWorldPositionY(), SceneObject(pBuilding):getWorldPositionZ()
		local worst = 0
		for _, d in ipairs({ {-20, -20}, {20, -20}, {-20, 20}, {20, 20}, {0, 30}, {0, -30} }) do
			worst = math.max(worst, math.abs(getTerrainHeightAt(zone, bx + d[1], by + d[2]) - bz))
		end
		lotOk = (worst <= 1.5) and 1 or 0
		st = st .. string.format(" worst_corner_dz=%.1f lot_ok=%d", worst, lotOk)
	end
	print("INFO tradehall " .. st)
	return st
end

-- moveNpc:<filter>:<x>:<z>:<y> → move the first matching NPC to cell-local (world when outdoors) coordinates
-- inside the cell it is in now; re-homes it so it does not leash back. For trying spots without a restart.
function FbLabTests:moveNpc(filter, x, z, y)
	local e = FbLabTests.liveSpawns(filter)[1]
	if e == nil then print("ERROR no live spawn matches " .. tostring(filter)); return "none" end
	local p = e.pObj
	x, z, y = tonumber(x), tonumber(z), tonumber(y)
	local cell = SceneObject(p):getParentID()
	SceneObject(p):switchZone(SceneObject(p):getZoneName(), x, z, y, cell)
	if SceneObject(p):isAiAgent() then AiAgent(p):setHomeLocation(x, z, y, cell ~= 0 and getSceneObject(cell) or nil) end
	print(string.format("INFO moveNpc %s -> x=%.1f z=%.2f y=%.1f cell=%d", e.name:gsub(" ", "_"), x, z, y, cell))
	return "ok"
end

-- capture(fnName, ...) → the lines an oracle printed (and its return value); the Lab Remote shows them
-- in windows. The oracles report through the global print, which is swapped for the call.
function FbLabTests.capture(fnName, ...)
	local lines = {}
	local fn = FbLabTests[fnName]
	if fn == nil then return { "ERROR no oracle " .. tostring(fnName) }, nil end
	local realPrint = print
	print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
		lines[#lines + 1] = table.concat(parts, " ")
	end
	local ok, res = pcall(fn, FbLabTests, ...)
	print = realPrint
	if not ok then lines[#lines + 1] = "ERROR " .. tostring(res) end
	return lines, res
end

-- giveRemote:<char> → a Final Boss Lab Remote in the character's inventory (admins only; idempotent)
function FbLabTests:giveRemote(charName)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	if FbLabRemote == nil then print("ERROR FbLabRemote not loaded"); return "none" end
	local oid = FbLabRemote:give(pPlayer)
	print(string.format("INFO giveRemote char=%s oid=%d allowed=%s", charName, oid, tostring(FbLabRemote:allowed(pPlayer))))
	return tostring(oid)
end

-- ---------------------------------------------------------------- site builder (lab)

-- structuresNear:<char>[:<range>] → the server's buildings/static shells around the character, with the
-- footprint radius FbWorldData knows for each (what the site builder's lot check uses)
function FbLabTests:structuresNear(charName, range)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	local list = SceneObject(pPlayer):getStructuresInRange(tonumber(range) or 100) or {}
	for _, p in ipairs(list) do
		local tmpl = SceneObject(p):getTemplateObjectPath()
		print(string.format("INFO structure oid=%d template=%s x=%.1f y=%.1f radius=%s", SceneObject(p):getObjectID(), tmpl,
			SceneObject(p):getWorldPositionX(), SceneObject(p):getWorldPositionY(), tostring(FbWorldData and FbWorldData.footprints[tmpl] or "?")))
	end
	print("INFO structures count=" .. #list)
	return tostring(#list)
end

-- siteNew:<char>:<template>:<heading|look|face>[:<name>] → preview a shell at the character's position
function FbLabTests:siteNew(charName, template, heading, name)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	local h = tonumber(heading)
	if heading == "look" then h = SceneObject(pPlayer):getDirectionAngle() % 360 end
	local d, verdict, lines = FbSiteBuilder:newSite(pPlayer, template, h, name)
	if d == nil then print("ERROR no preview"); return "none" end
	for _, l in ipairs(lines) do print("INFO lot " .. l) end
	print(string.format("INFO site name=%s preview=%d x=%.1f y=%.1f heading=%.0f verdict=%s", d.name, d.preview, d.x, d.y, d.heading, verdict))
	return verdict
end

-- siteNudge:<char>:<op>[:<amount>]
function FbLabTests:siteNudge(charName, op, amount)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	local d, verdict, lines = FbSiteBuilder:nudge(pPlayer, op, amount)
	if d == nil then print("ERROR nudge failed"); return "none" end
	print(string.format("INFO site name=%s preview=%d x=%.1f y=%.1f heading=%.0f verdict=%s", d.name, d.preview, d.x, d.y, d.heading, verdict))
	return verdict
end

-- siteTenant:<char>:<template>[:<label>] / siteOutside:<char>:<template>
function FbLabTests:siteTenant(charName, template, label)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	local t, verdict, why = FbSiteBuilder:addTenant(pPlayer, template, label)
	if t == nil then print("ERROR tenant not placed"); return "none" end
	print(string.format("INFO tenant template=%s room=%s x=%.2f z=%.2f y=%.2f dir=%.0f oid=%d furniture=%s why=%s", t.template, t.room, t.x, t.z, t.y, t.dir, t.oid, verdict, (why:gsub(" ", "_"))))
	return verdict
end

function FbLabTests:siteOutside(charName, template)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	local o = FbSiteBuilder:addOutside(pPlayer, template)
	if o == nil then print("ERROR not placed"); return "none" end
	print(string.format("INFO outside template=%s x=%.1f y=%.1f dir=%.0f oid=%d", o.template, o.x, o.y, o.dir, o.oid))
	return "ok"
end

-- siteDraft:<char> → the draft's state; siteText:<char> → the site file text (one INFO line per file line)
function FbLabTests:siteDraft(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local d = FbSiteBuilder:draft(pPlayer)
	if d == nil then print("INFO site none"); return "none" end
	print(string.format("INFO site name=%s template=%s x=%.1f y=%.1f heading=%.0f preview=%d tenants=%d outside=%d", d.name, d.template, d.x, d.y, d.heading, d.preview, #d.tenants, #d.outside))
	return d.name
end

function FbLabTests:siteText(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local d = FbSiteBuilder:draft(pPlayer)
	if d == nil then print("ERROR no draft"); return "none" end
	for _, l in ipairs(FbSiteBuilder:siteText(d)) do print("INFO sitefile " .. l) end
	return d.name
end

function FbLabTests:siteRename(charName, name)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbSiteBuilder:rename(pPlayer, name)
	return FbLabTests:siteDraft(charName)
end

function FbLabTests:siteDiscard(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbSiteBuilder:discard(pPlayer)
	print("INFO site discarded")
	return "ok"
end

-- terrainHeights:<planet>:<x1>,<y1>;<x2>,<y2>;… → one INFO line per point with the terrain height (the site
-- planner's lot report asks for a building's corners this way; "x,y|x,y" also accepted)
function FbLabTests:terrainHeights(planet, pts)
	local n = 0
	for pair in tostring(pts or ""):gmatch("[^;|]+") do
		local x, y = pair:match("^%s*(-?[%d%.]+)%s*,%s*(-?[%d%.]+)%s*$")
		if x ~= nil then
			n = n + 1
			local z, water = getTerrainHeightAt(planet, tonumber(x), tonumber(y)), getWaterHeightAt(planet, tonumber(x), tonumber(y))
			print(string.format("INFO terrain x=%s y=%s z=%.2f water=%s", x, y, z, water and string.format("%.2f", water) or "-"))
		end
	end
	return tostring(n)
end

-- resources:<planet>[:<class substring>] → every spawn in shift on that planet (7.6a: the citizens' spreadsheet):
--   "INFO resource name=… class=… family=… tool=N despawn=<epoch> attrs=res_x=N,… best=x,y,density;…"
function FbLabTests:resources(planet, filter)
	if planet == nil then print("ERROR resources: planet [class]"); return "none" end
	local list = getResourceSpawns(planet)
	if list == nil then print("ERROR resources: no resource manager / zone " .. tostring(planet)); return "none" end
	local n = 0
	for _, r in ipairs(list) do
		local hay = (r.finalClass or "") .. " " .. (r.type or "") .. " " .. (r.family or "") .. " " .. (r.name or "")
		if filter == nil or filter == "" or hay:lower():find(filter:lower(), 1, true) then
			n = n + 1
			local attrs, best = {}, {}
			for k, v in pairs(r.attributes or {}) do attrs[#attrs + 1] = k .. "=" .. tostring(v) end
			table.sort(attrs)
			for _, b in ipairs(r.best or {}) do best[#best + 1] = string.format("%.0f,%.0f,%.2f", b.x, b.y, b.density) end
			print(string.format("INFO resource name=%s class=%s family=%s tool=%d despawn=%d attrs=%s best=%s",
				r.name, r.finalClass or r.type, r.family or "", r.tool or 0, r.despawn or 0, table.concat(attrs, ","), table.concat(best, ";")))
		end
	end
	print(string.format("INFO resources planet=%s n=%d of %d", planet, n, #list))
	return tostring(n)
end

-- resourceDensity:<spawn name>:<planet>:<x>:<y> → the concentration 0..1 (what a survey there would read)
function FbLabTests:resourceDensity(name, planet, x, y)
	local d = getResourceDensityAt(name, planet, tonumber(x) or 0, tonumber(y) or 0)
	if d == nil or d < 0 then print("ERROR resourceDensity: no spawn " .. tostring(name)); return "none" end
	print(string.format("INFO resourceDensity name=%s planet=%s x=%s y=%s density=%.3f", name, planet, x, y, d))
	return string.format("%.3f", d)
end

-- pathTo:<planet>:<x1>:<y1>:<x2>:<y2> → the AI pathfinder's outdoor route as "x,z,y;x,z,y;…" (7.1: a seat walks it)
-- pathTo:<char>:<x2>:<y2> → the same from where that character stands
-- pathTo:<char>:<x>:<y>[:<cellOid>]  or  pathTo:<planet>:<x1>:<y1>:<x2>:<y2>[:<cell1>:<cell2>]
-- A cell oid makes that end's coordinates cell-local (what a creature inside a building reports); the character
-- form starts from where the character stands, indoors or out. Rows come back as x,z,y,cell (cell 0 = outdoors,
-- world coordinates; otherwise cell-local, for a DataTransformWithParent) — what tools/seat walk sends.
function FbLabTests:pathTo(a, b, c, d, e, f, g)
	local planet, x1, y1, x2, y2, cell1, cell2
	if e ~= nil then
		planet, x1, y1, x2, y2 = a, tonumber(b), tonumber(c), tonumber(d), tonumber(e)
		cell1, cell2 = tonumber(f) or 0, tonumber(g) or 0
	else
		local pPlayer = getPlayerByName(a)
		if pPlayer == nil then print("ERROR pathTo: no player " .. tostring(a)); return "none" end
		planet = SceneObject(pPlayer):getZoneName()
		cell1 = SceneObject(pPlayer):getParentID()
		if cell1 ~= 0 then
			x1, y1 = SceneObject(pPlayer):getPositionX(), SceneObject(pPlayer):getPositionY()
		else
			x1, y1 = SceneObject(pPlayer):getWorldPositionX(), SceneObject(pPlayer):getWorldPositionY()
		end
		x2, y2, cell2 = tonumber(b), tonumber(c), tonumber(d) or 0
	end
	if planet == nil or x1 == nil or y1 == nil or x2 == nil or y2 == nil then print("ERROR pathTo: planet x1 y1 x2 y2 [cell1 cell2] (or char x y [cell])"); return "none" end
	local path
	if cell1 ~= 0 or cell2 ~= 0 then
		path = findPath(planet, x1, y1, x2, y2, cell1, cell2)
	else
		path = findPath(planet, x1, y1, x2, y2)
	end
	if path == nil and cell1 ~= 0 then
		-- the pathfinder leaves a building only for a target close to it (the cloning facility to a spot 190 m away
		-- failed, 30 m away worked) and never crosses from one building's cells into another's (a Mos Espa shop to the
		-- starport's ticket foyer: Wex, twice, 2026-10-28): step out first — a world point near the building the mesh can
		-- reach — then walk on, into the target's cell when it has one
		local pCell = getSceneObject(cell1)
		local pBuilding = pCell ~= nil and SceneObject(pCell):getParent() or nil
		local pCell2 = cell2 ~= 0 and getSceneObject(cell2) or nil
		local pBuilding2 = pCell2 ~= nil and SceneObject(pCell2):getParent() or nil
		if pBuilding ~= nil and pBuilding2 ~= nil and SceneObject(pBuilding):getObjectID() == SceneObject(pBuilding2):getObjectID() then
			pBuilding = nil   -- same building, the mesh inside is the whole story
		end
		if pBuilding ~= nil then
			local bx, by = SceneObject(pBuilding):getWorldPositionX(), SceneObject(pBuilding):getWorldPositionY()
			for _, r in ipairs({ 30, 45, 60 }) do
				for k = 0, 7 do
					local ex, ey = bx + r * math.cos(k * math.pi / 4), by + r * math.sin(k * math.pi / 4)
					local out = findPath(planet, x1, y1, ex, ey, cell1, 0)
					if out ~= nil and #out > 0 then
						local on = cell2 ~= 0 and findPath(planet, ex, ey, x2, y2, 0, cell2) or findPath(planet, ex, ey, x2, y2)
						if on ~= nil and #on > 0 then
							path = out
							for i = 1, #on do path[#path + 1] = on[i] end
							print(string.format("INFO pathTo: left the building via %.1f,%.1f", ex, ey))
							break
						end
					end
				end
				if path ~= nil then break end
			end
		end
	end
	if path == nil then print(string.format("ERROR pathTo: no path on %s from %.1f,%.1f (cell %d) to %.1f,%.1f (cell %d)", planet, x1, y1, cell1, x2, y2, cell2)); return "none" end
	-- the pathfinder returns the indoor target itself as the last point, at the z it was asked for (0): a walker sent
	-- there stands a floor's height under the room, and the in-building line-of-sight check (an NPC conversation)
	-- refuses it without a word — give it the floor of the last node in the same cell
	local last, prev = path[#path], path[#path - 1]
	if last ~= nil and prev ~= nil and (last[4] or 0) ~= 0 and last[4] == prev[4] and math.abs(last[2]) < 0.001 and math.abs(prev[2]) >= 0.001 then
		last[2] = prev[2]
	end
	local parts, length, px, py, pc = {}, 0, x1, y1, cell1
	for i, pt in ipairs(path) do
		local cell = pt[4] or 0
		parts[#parts + 1] = string.format("%.2f,%.2f,%.2f,%d", pt[1], pt[2], pt[3], cell)
		if cell == pc then length = length + math.sqrt((pt[1] - px) ^ 2 + (pt[3] - py) ^ 2) end
		px, py, pc = pt[1], pt[3], cell
	end
	print(string.format("INFO path planet=%s n=%d length=%.1f pts=%s", planet, #path, length, table.concat(parts, ";")))
	return tostring(#path)
end

-- objectsNear:<planet>:<x>:<y>:<range>[:<type>] → every object within range of a point, the contents of buildings'
-- cells included (getObjectsInRange binding); type is a SceneObjectType number (travel terminal 16402 = 0x4012).
function FbLabTests:objectsNear(planet, x, y, range, otype)
	x, y, range, otype = tonumber(x), tonumber(y), tonumber(range), tonumber(otype)
	if planet == nil or x == nil or y == nil or range == nil then print("ERROR objectsNear: planet x y range [type]"); return "none" end
	local objects = otype and getObjectsInRange(planet, x, y, range, otype) or getObjectsInRange(planet, x, y, range)
	if objects == nil then print("ERROR objectsNear: no zone " .. tostring(planet)); return "none" end
	for _, o in ipairs(objects) do
		local level = ""
		if o.type == 0x400 or o.type == 0x401 then   -- a creature or an NPC: its level too (the pilot picks prey by it)
			local p = getSceneObject(o.oid)
			if p ~= nil and SceneObject(p):isCreatureObject() then level = " level=" .. CreatureObject(p):getLevel() end
		end
		print(string.format("INFO object oid=%d type=0x%x template=%s name=%s x=%.1f y=%.1f z=%.1f cell=%d cellName=%s building=%d localX=%.2f localY=%.2f localZ=%.2f%s",
			o.oid, o.type, o.template, (o.name or ""):gsub("%s", "_"), o.x, o.y, o.z, o.cell, o.cellName ~= "" and o.cellName or "-", o.building,
			o.localX or 0, o.localY or 0, o.localZ or 0, level))
	end
	return tostring(#objects)
end

-- clearWild:<planet>:<x>:<y>[:<radius>] → remove the wild lairs and the wild creatures (type 0x400, not pets, not lab
-- spawns) around a scenario spot. The world rolls for lairs around a player on every position update — a walk, and a
-- zone switch home from a vision: the visions scenario came back to 4100,-4700 into three scyks (gate 2026-10-26).
function FbLabTests:clearWild(planet, x, y, range)
	x, y, range = tonumber(x), tonumber(y), tonumber(range or 80)
	if planet == nil or x == nil or y == nil then print("ERROR clearWild: planet x y [radius]"); return "none" end
	local objects = getObjectsInRange(planet, x, y, range)
	if objects == nil then print("ERROR clearWild: no zone " .. tostring(planet)); return "none" end
	local ours = {}
	for _, r in ipairs(FbLabTests.registryLive()) do ours[r.oid] = true end
	local lairs, creatures = 0, 0
	for _, o in ipairs(objects) do
		local isLair = string.find(o.template or "", "/lair/", 1, true) ~= nil
		local isWild = o.type == 0x400 and not ours[o.oid]
		if isLair or isWild then
			local p = getSceneObject(o.oid)
			if p ~= nil and not SceneObject(p):isPlayerCreature() and not (SceneObject(p):isAiAgent() and AiAgent(p):isPet()) then
				SceneObject(p):destroyObjectFromWorld(true)
				SceneObject(p):destroyObjectFromDatabase()
				if isLair then lairs = lairs + 1 else creatures = creatures + 1 end
			end
		end
	end
	print(string.format("INFO clearWild zone=%s x=%.0f y=%.0f radius=%.0f lairs=%d creatures=%d", planet, x, y, range, lairs, creatures))
	return tostring(lairs + creatures)
end

-- landAt:<planet>:<x>:<y> → what the ground is at a point: terrain height, water height, land (terrain above water),
-- building permitted (outside no-build), in the planet (3.13 city generator; every generated point passes through it)
function FbLabTests:landAt(planet, x, y)
	x, y = tonumber(x), tonumber(y)
	if planet == nil or x == nil or y == nil then print("ERROR landAt: planet x y"); return "none" end
	if math.abs(x) >= 8000 or math.abs(y) >= 8000 then print(string.format("INFO land planet=%s x=%.0f y=%.0f inside=0", planet, x, y)); return "0" end
	local z = getTerrainHeightAt(planet, x, y)
	local w = getWaterHeightAt(planet, x, y)
	local water = (w ~= nil and w > -10000) and w or -10000
	local land = z > water
	local build = isBuildingPermittedAt(planet, x, y) and 1 or 0
	print(string.format("INFO land planet=%s x=%.0f y=%.0f inside=1 z=%.1f water=%s land=%d build=%d", planet, x, y, z, water > -10000 and string.format("%.1f", water) or "-", land and 1 or 0, build))
	return land and "1" or "0"
end

-- pathBetween:<planet>:<x1>:<y1>:<x2>:<y2> → the navmesh path between two outdoor points: point count, how many are
-- outdoors (cell 0), its length, and where it really ends (a path that stops short means the mesh has a gap)
function FbLabTests:pathBetween(planet, x1, y1, x2, y2)
	x1, y1, x2, y2 = tonumber(x1), tonumber(y1), tonumber(x2), tonumber(y2)
	if planet == nil or x1 == nil or y1 == nil or x2 == nil or y2 == nil then print("ERROR pathBetween: planet x1 y1 x2 y2"); return "none" end
	local path = findPath(planet, x1, y1, x2, y2)
	if path == nil or #path == 0 then print(string.format("INFO path planet=%s points=0", planet)); return "0" end
	local outdoor, length, lx, ly = 0, 0, x1, y1
	for _, pt in ipairs(path) do   -- rows are { x, z, y, cell }
		if (pt[4] or 0) == 0 then outdoor = outdoor + 1 end
		length = length + math.sqrt((pt[1] - lx) ^ 2 + (pt[3] - ly) ^ 2); lx, ly = pt[1], pt[3]
	end
	local last = path[#path]
	local short = math.sqrt((last[1] - x2) ^ 2 + (last[3] - y2) ^ 2)
	print(string.format("INFO path planet=%s points=%d outdoor=%d length=%.0f endX=%.0f endY=%.0f short=%.0f", planet, #path, outdoor, length, last[1], last[3], short))
	return tostring(#path)
end

-- scenes → one INFO line per street scene (3.14)
function FbLabTests:scenes()
	if FbScenes == nil then print("ERROR FbScenes not loaded"); return "none" end
	for _, k in ipairs(FbScenes.order) do print("INFO scene " .. FbScenes:status(k)) end
	return tostring(#FbScenes.order)
end

-- sceneRun:<key> → play a scene now (no trigger, no cooldown); sceneBeat:<key> → the next beat now; sceneStop:<key>
function FbLabTests:sceneRun(k)
	if FbScenes == nil then print("ERROR FbScenes not loaded"); return "none" end
	print("INFO scene " .. tostring(FbScenes:run(k)))
	return "ok"
end
function FbLabTests:sceneBeat(k)
	if FbScenes == nil then print("ERROR FbScenes not loaded"); return "none" end
	local what = FbScenes:beat(k)
	print("INFO sceneBeat did=" .. tostring(what) .. " " .. FbScenes:status(k))
	return tostring(what)
end
function FbLabTests:sceneStop(k)
	if FbScenes == nil then print("ERROR FbScenes not loaded"); return "none" end
	print("INFO scene " .. tostring(FbScenes:stop(k)))
	return "ok"
end

-- Phase 3.14: every scene has a spot in a known city, a cast the beats refer to, and reads back
function FbLabTests.checkScenes()
	if FbScenes == nil then check("scenes.loaded", false); return end
	check("scenes.count", #FbScenes.order >= 10, #FbScenes.order .. " scenes")
	for _, k in ipairs(FbScenes.order) do
		local s = FbScenes.scenes[k]
		local planet, x, y = FbScenes:spot(s)
		check("scenes." .. k .. ".spot", planet ~= nil and getTerrainHeightAt(planet, x, y) ~= 0, string.format("%s %s,%s", tostring(planet), tostring(x), tostring(y)))
		local names = {}
		for _, c in ipairs(s.cast) do names[c.name] = true end
		local ok = true
		for _, b in ipairs(s.beats) do
			local who = b.say or b.emote or b.walk or b.face or b.leave
			if who ~= nil and not names[who] then ok = false end
			if b.face ~= nil and not names[b.to or ""] then ok = false end
		end
		check("scenes." .. k .. ".beats_refer_to_the_cast", ok)
		check("scenes." .. k .. ".idle", FbScenes:status(k):find("active=0", 1, true) ~= nil or FbScenes:status(k):find("active=1", 1, true) ~= nil)
	end
end

-- checkpoints → one INFO line per watched starport (3.15); checkpointRefresh → re-read every holder now;
-- checkpointHail:<city>:<char> → the post deals with the character now (enemy / friend / waved / searched)
function FbLabTests:checkpoints()
	if FbCheckpoints == nil then print("ERROR FbCheckpoints not loaded"); return "none" end
	for _, city in ipairs(FbCheckpoints.order) do print("INFO checkpoint " .. FbCheckpoints:status(city)) end
	return tostring(#FbCheckpoints.order)
end
function FbLabTests:checkpointRefresh()
	if FbCheckpoints == nil then print("ERROR FbCheckpoints not loaded"); return "none" end
	print("INFO checkpointRefresh " .. FbCheckpoints:refresh())
	return "ok"
end
function FbLabTests:checkpointHail(city, charName)
	if FbCheckpoints == nil then print("ERROR FbCheckpoints not loaded"); return "none" end
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	local what = FbCheckpoints:hail(city, pPlayer)
	print("INFO checkpointHail city=" .. tostring(city) .. " result=" .. tostring(what))
	return tostring(what)
end

-- Phase 3.15: every held city's starport has its post standing, and no post stands in a contested city
function FbLabTests.checkCheckpoints()
	if FbCheckpoints == nil then check("checkpoints.loaded", false); return end
	check("checkpoints.cities", #FbCheckpoints.order >= 20, #FbCheckpoints.order .. " starports")
	for _, city in ipairs(FbCheckpoints.order) do
		local st = FbCheckpoints:status(city)
		local holder = st:match("holder=(%a+)")
		if holder == "none" then
			check("checkpoints." .. city .. ".no_post_when_contested", st:find("side=none", 1, true) ~= nil, st)
		else
			check("checkpoints." .. city .. ".post_standing", st:find("side=" .. holder, 1, true) ~= nil and st:find("post=3/3", 1, true) ~= nil, st)
		end
	end
end

-- arrivals → one INFO line per starport (3.16); arrivalsLand:<city> → a landing party now; arrivalsSweep:<city> → clear it
function FbLabTests:arrivals()
	if FbArrivals == nil then print("ERROR FbArrivals not loaded"); return "none" end
	for _, city in ipairs(FbArrivals.order) do print("INFO arrivals " .. FbArrivals:status(city)) end
	return tostring(#FbArrivals.order)
end
function FbLabTests:arrivalsLand(city)
	if FbArrivals == nil then print("ERROR FbArrivals not loaded"); return "none" end
	print("INFO arrivals " .. tostring(FbArrivals:land(city)))
	return "ok"
end
function FbLabTests:arrivalsSweep(city)
	if FbArrivals == nil then print("ERROR FbArrivals not loaded"); return "none" end
	print("INFO arrivalsSweep city=" .. tostring(city) .. " swept=" .. tostring(FbArrivals:sweep(city)))
	return "ok"
end

-- Phase 3.16: every starport with a convoy route takes part and reads back
function FbLabTests.checkArrivals()
	if FbArrivals == nil then check("arrivals.loaded", false); return end
	check("arrivals.cities", #FbArrivals.order >= 5, #FbArrivals.order .. " starports")
	for _, city in ipairs(FbArrivals.order) do
		local st = FbArrivals:status(city)
		check("arrivals." .. city .. ".readable", st:find("route=", 1, true) ~= nil, st)
	end
end

-- structures:<char> → the structures the character owns (oid per line) and the lots left.
function FbLabTests:structures(charName)
	local t = getOwnedStructures(charName)
	if t == nil then print("ERROR structures: no player " .. tostring(charName)); return "none" end
	for _, oid in ipairs(t) do
		local st = getStructureStatus(oid)
		if st ~= nil then
			print(string.format("INFO structure oid=%d type=0x%x template=%s zone=%s x=%.1f y=%.1f active=%s", oid, st.type, st.template, st.zone, st.x, st.y, tostring(st.active)))
		else
			print(string.format("INFO structure oid=%d missing=1", oid))
		end
	end
	print(string.format("INFO lots char=%s remaining=%d owned=%d", charName, t.lotsRemaining or -1, #t))
	return tostring(#t)
end

-- harvester:<oid> → the management view of a harvester (or any structure): maintenance/power surplus and rates,
-- active flag, active resource, rates, hopper size and every hopper line (getStructureStatus binding).
function FbLabTests:harvester(oid)
	oid = tonumber(oid)
	local st = oid and getStructureStatus(oid)
	if st == nil then print("ERROR harvester: no structure " .. tostring(oid)); return "none" end
	print(string.format("INFO harvester oid=%d template=%s zone=%s x=%.1f y=%.1f owner=%d lotSize=%d maintenance=%d maintenanceRate=%d power=%d powerRate=%d active=%s activeResource=%d activeResourceName=%s extractionRate=%.1f actualRate=%.2f hopperSize=%.0f hopperMax=%.0f hopperItems=%d",
		st.oid, st.template, st.zone, st.x, st.y, st.owner, st.lotSize, st.maintenance, st.maintenanceRate, st.power, st.powerRate,
		tostring(st.active), st.activeResource or 0, st.activeResourceName or "-", st.extractionRate or 0, st.actualRate or 0,
		st.hopperSize or 0, st.hopperMax or 0, st.hopper and #st.hopper or 0))
	for i, item in ipairs(st.hopper or {}) do
		print(string.format("INFO hopper oid=%d spawn=%d name=%s quantity=%d", st.oid, item.spawn, item.name, item.quantity))
	end
	return "ok"
end

-- harvesterFill:<oid>:<units> → units of the active resource straight into the hopper (stands in for hours of
-- extraction so the hopper can be emptied in a scenario).
function FbLabTests:harvesterFill(oid, units)
	local added = harvesterAddToHopper(tonumber(oid) or 0, tonumber(units) or 0)
	if added == nil then print("ERROR harvesterFill: no harvester " .. tostring(oid) .. " with an active resource"); return "none" end
	print(string.format("INFO harvesterFill oid=%s added=%d", tostring(oid), added))
	return tostring(added)
end

-- templateDump:<path> → every loaded object template as JSON lines (crc, serverCrc, type, name, file) at path: the
-- bot client's type/name table (tools/seat templates writes ~/.swg-lab/templates.jsonl with it).
function FbLabTests:templateDump(path)
	local n = dumpTemplates(path or "/tmp/templates.jsonl")
	if n == nil then print("ERROR templateDump: no template manager"); return "none" end
	print(string.format("INFO templateDump path=%s n=%d", path, n))
	return tostring(n)
end

-- queueSize:<char> → how many actions wait in the character's command queue (a stuck queue swallows every command)
function FbLabTests:queueSize(charName)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then print("ERROR queueSize: " .. tostring(charName) .. " is offline"); return "offline" end
	local n = CreatureObject(pPlayer):getQueueSize()
	print(string.format("INFO queue char=%s size=%d posture=%d", charName, n, CreatureObject(pPlayer):getPosture()))
	return tostring(n)
end

-- canBuild:<planet>:<x>:<y> → whether a structure may be placed there (no-build areas, client cities, footprint).
function FbLabTests:canBuild(planet, x, y)
	local ok = isBuildingPermittedAt(planet, tonumber(x), tonumber(y))
	if ok == nil then print("ERROR canBuild: no zone " .. tostring(planet)); return "none" end
	print(string.format("INFO canBuild planet=%s x=%s y=%s permitted=%s", planet, x, y, tostring(ok)))
	return tostring(ok)
end

-- deedValues:<oid>:<extractionRate>:<hopperSize> → the crafting values a lab-made harvester deed lacks (both 0
-- otherwise: the harvester would extract nothing into a hopper of size 0).
function FbLabTests:deedValues(oid, rate, hopper)
	local ok = setDeedValues(tonumber(oid) or 0, tonumber(rate) or 0, tonumber(hopper) or 0)
	if ok == nil then print("ERROR deedValues: no deed " .. tostring(oid)); return "none" end
	print(string.format("INFO deedValues oid=%s extractionRate=%s hopperSize=%s", tostring(oid), tostring(rate), tostring(hopper)))
	return "ok"
end

-- walkNpc:<oid>:<x>:<y> → an AI agent walks there (setNextPosition, home moved too): real movement packets for
-- anyone watching, unlike moveNpc/teleportObject which re-create the object.
function FbLabTests:walkNpc(oid, x, y)
	local p = getSceneObject(tonumber(oid))
	if p == nil or not SceneObject(p):isAiAgent() then print("ERROR walkNpc: no AI agent " .. tostring(oid)); return "none" end
	x, y = tonumber(x), tonumber(y)
	local z = getTerrainHeightAt(SceneObject(p):getZoneName(), x, y)
	AiAgent(p):setHomeLocation(x, z, y, nil)
	AiAgent(p):stopWaiting()
	AiAgent(p):setNextPosition(x, z, y, 0)
	print(string.format("INFO walkNpc oid=%s x=%.1f y=%.1f z=%.1f", tostring(oid), x, y, z))
	return "ok"
end

-- resourceUnits:<char>:<resource name> → units of that resource in the inventory, all containers summed.
function FbLabTests:resourceUnits(charName, resourceName)
	local n = getResourceUnits(charName, resourceName)
	if n == nil then print("ERROR resourceUnits: " .. tostring(charName) .. " is offline"); return "offline" end
	print(string.format("INFO resourceUnits char=%s resource=%s units=%d", charName, resourceName, n))
	return tostring(n)
end

-- equip:<char>:<item oid> → move an inventory item into its equipped slot (weapons, clothing, armour).
function FbLabTests:equip(charName, oid)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then print("ERROR equip: " .. tostring(charName) .. " is offline"); return "offline" end
	local pItem = getSceneObject(tonumber(oid))
	if pItem == nil then print("ERROR equip: no item " .. tostring(oid)); return "none" end
	-- a weapon already in hand goes back to the inventory first (the slot must be free)
	local pHeld = SceneObject(pPlayer):getSlottedObject("hold_r")
	local pInventory = SceneObject(pPlayer):getSlottedObject("inventory")
	if pHeld ~= nil and pInventory ~= nil and SceneObject(pHeld):getObjectID() ~= tonumber(oid) then
		SceneObject(pInventory):transferObject(pHeld, -1, true)
	end
	local ok = SceneObject(pPlayer):transferObject(pItem, 4, true)
	print(string.format("INFO equip char=%s oid=%s ok=%s", charName, tostring(oid), tostring(ok)))
	return tostring(ok)
end

-- unequip:<char> → the weapon in hand goes back to the inventory (bare hands: the default unarmed weapon). The level
-- scenario awards a box bare-handed so the stored level is computed from the unarmed line.
function FbLabTests:unequip(charName)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then print("ERROR unequip: " .. tostring(charName) .. " is offline"); return "offline" end
	local pHeld = SceneObject(pPlayer):getSlottedObject("hold_r")
	local pInventory = SceneObject(pPlayer):getSlottedObject("inventory")
	local moved = false
	if pHeld ~= nil and pInventory ~= nil then moved = SceneObject(pInventory):transferObject(pHeld, -1, true) end
	print(string.format("INFO unequip char=%s moved=%s", charName, tostring(moved)))
	return tostring(moved)
end

-- structureDestroy:<oid> → tear a structure down the proper way (DestroyStructureTask: lot refunded, owner list
-- updated), for scenario cleanup.
function FbLabTests:structureDestroy(oid)
	local pStructure = getSceneObject(tonumber(oid))
	if pStructure == nil then print("ERROR structureDestroy: no object " .. tostring(oid)); return "none" end
	destroyBuilding(tonumber(oid))
	print("INFO structureDestroy oid=" .. tostring(oid))
	return "ok"
end

-- giveResource:<char>:<type>:<units> → a resource container of that survey type (mineral, chemical, flora, gas,
-- water, wind, solar, fusion, organic, geothermal) into the inventory (givePlayerResource binding; wind/solar/fusion
-- are the power a harvester burns).
function FbLabTests:giveResource(charName, rtype, units)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then print("ERROR giveResource: " .. tostring(charName) .. " is offline"); return "offline" end
	givePlayerResource(pPlayer, rtype, tonumber(units) or 100)
	print(string.format("INFO giveResource char=%s type=%s units=%d", charName, rtype, tonumber(units) or 100))
	return "ok"
end

-- travelPoints:<planet> → the planet's travel points (planet_manager.lua data) with, for each, the nearest travel
-- terminal (where purchaseTicket must be sent from: within 8 m; starport terminals stand inside the starport
-- building, cell given) and the shuttle creature (boardShuttle within 25 m). Names carry underscores for
-- spaces, the way purchaseTicket wants them.
-- the shuttle of a travel point: the NEAREST player_shuttle / player_transport within 120 m, never the last one seen —
-- Mos Espa's East shuttleport stands 66 m from the starport pad, and boardShuttle matches the ticket against the travel
-- point nearest the character, so the wrong shuttle means "no ticket" with a valid ticket in hand (Wex, nine tickets, 2026-10-28)
function FbLabTests.shuttleFor(planet, pt, objects)
	local shuttle, sdist = nil, 1e9
	for _, o in ipairs(objects or getObjectsInRange(planet, pt.x, pt.y, 120) or {}) do
		if o.template:find("player_shuttle") or o.template:find("player_transport") then
			local d = math.sqrt((o.x - pt.x) ^ 2 + (o.y - pt.y) ^ 2)
			if d < sdist then shuttle, sdist = o, d end
		end
	end
	return shuttle, sdist
end

function FbLabTests:travelPoints(planet)
	local env, err = loadIsolated("scripts/managers/planet/planet_manager.lua")
	if env == nil then print("ERROR travelPoints: planet_manager.lua: " .. tostring(err)); return "none" end
	local cfg = env[planet]
	if cfg == nil or cfg.planetTravelPoints == nil then print("ERROR travelPoints: no travel points for " .. tostring(planet)); return "none" end
	local n = 0
	for _, pt in ipairs(cfg.planetTravelPoints) do
		local terminal, tdist = nil, 1e9
		local objects = getObjectsInRange(planet, pt.x, pt.y, 120) or {}
		for _, o in ipairs(objects) do
			if o.type == 16402 then
				local d = math.sqrt((o.x - pt.x) ^ 2 + (o.y - pt.y) ^ 2)
				if d < tdist then terminal, tdist = o, d end
			end
		end
		local shuttle = FbLabTests.shuttleFor(planet, pt, objects)
		local line = string.format("INFO travelpoint planet=%s name=%s x=%.1f y=%.1f z=%.1f interplanetary=%d incoming=%d",
			planet, pt.name:gsub("%s", "_"), pt.x, pt.y, pt.z or 0, pt.interplanetaryTravelAllowed or 0, pt.incomingTravelAllowed or 0)
		if terminal ~= nil then
			line = line .. string.format(" terminal=%d tx=%.2f ty=%.2f tz=%.2f tcell=%d tcellName=%s tbuilding=%d tlx=%.2f tly=%.2f tlz=%.2f",
				terminal.oid, terminal.x, terminal.y, terminal.z, terminal.cell, terminal.cellName ~= "" and terminal.cellName or "-", terminal.building,
				terminal.localX or 0, terminal.localY or 0, terminal.localZ or 0)
		else
			line = line .. " terminal=0"
		end
		if shuttle ~= nil then
			line = line .. string.format(" shuttle=%d sx=%.1f sy=%.1f", shuttle.oid, shuttle.x, shuttle.y)
		else
			line = line .. " shuttle=0"
		end
		print(line)
		n = n + 1
	end
	return tostring(n)
end

-- ---------------------------------------------------------------- site preview (2.12d: the planner's game loop)

-- sitePreview:<file> → spawn sites/.preview/<file>.lua in place of the live site of the same name
function FbLabTests:sitePreview(file)
	if FbSites == nil then print("ERROR FbSites not loaded"); return "none" end
	local site, pBuilding = FbSites:preview(file or "preview")
	if site == nil then print("ERROR sitePreview " .. tostring(pBuilding)); return "none" end
	local placed = 0
	for _ in tostring(getQuestStatus("FbSites." .. site.name .. ".npcs") or ""):gmatch("[^,]+") do placed = placed + 1 end
	print(string.format("INFO sitePreview name=%s building=%d x=%.1f y=%.1f heading=%.0f cells=%d npcs=%d of %d", site.name,
		SceneObject(pBuilding):getObjectID(), site.x, site.y, site.heading or 0, BuildingObject(pBuilding):getTotalCellNumber(), placed, #site.tenants + #site.outside))
	if placed < #site.tenants + #site.outside then print(string.format("FAIL sitePreview %d NPC(s) did not spawn (unknown room or template?)", #site.tenants + #site.outside - placed)) end
	return site.name
end

-- sitePreviewEnd → remove the preview, rebuild the saved site of that name if there is one
function FbLabTests:sitePreviewEnd()
	if FbSites == nil then print("ERROR FbSites not loaded"); return "none" end
	local name, gone, restored = FbSites:previewEnd()
	if name == nil then print("INFO sitePreviewEnd nothing was previewed"); return "none" end
	print(string.format("INFO sitePreviewEnd name=%s removed=%d restored=%s", name, gone, tostring(restored)))
	return name
end

-- sitePlacement:<name> → the placement audit (line of sight, floor, drift) of every NPC a site spawned
function FbLabTests:sitePlacement(name)
	local fails, warns, n = 0, 0, 0
	for oid in tostring(getQuestStatus("FbSites." .. tostring(name) .. ".npcs") or ""):gmatch("[^,]+") do
		for _, e in ipairs(FbLabTests.liveSpawns(oid)) do
			n = n + 1
			local f = FbLabTests.placementOf(e)
			print(string.format("INFO placement %s los=%s/8 floor=%s verdict=%s why=%s", f.line, tostring(f.los), f.floor and string.format("%.1f", f.floor) or "-", f.verdict, (table.concat(f.reasons, ";"):gsub(" ", "_"))))
			if f.verdict == "fail" then fails = fails + 1; print("FAIL placement " .. e.name .. " (" .. e.oid .. "): " .. table.concat(f.reasons, "; "))
			elseif f.verdict == "warn" then warns = warns + 1; print("WARN placement " .. e.name .. " (" .. e.oid .. "): " .. table.concat(f.reasons, "; ")) end
		end
	end
	if n == 0 then print("INFO placement summary spawns=0 — site " .. tostring(name) .. " is not standing (spawn the preview first)") end
	print(string.format("INFO placement summary spawns=%d fail=%d warn=%d", n, fails, warns))
	return tostring(fails)
end

-- ---------------------------------------------------------------- world edits (2.12g: patched snapshots)

-- One line per edit of a planet: does the booted server show it? (the snapshot it loaded came from finalboss.tre)
function FbLabTests.worldEditLines(planet)
	local out = {}
	for _, e in ipairs((FbWorldEdits or {})[planet] or {}) do
		local p = getSceneObject(e.oid)
		local alive = p ~= nil and SceneObject(p):getZoneName() ~= ""
		local ok, why
		if e.op == "delete" then
			ok = not alive; why = alive and "still standing" or "gone"
		elseif not alive then
			ok = false; why = "missing"
		else
			local dx, dy = SceneObject(p):getWorldPositionX() - e.x, SceneObject(p):getWorldPositionY() - e.y
			local dist = math.sqrt(dx * dx + dy * dy)
			local h = e.heading and ((SceneObject(p):getDirectionAngle() - e.heading + 540) % 360 - 180) or 0
			ok = dist < 0.5 and math.abs(h) < 2
			why = string.format("at %.1f,%.1f (%.2f m off, heading off by %.0f)", SceneObject(p):getWorldPositionX(), SceneObject(p):getWorldPositionY(), dist, h)
		end
		out[#out + 1] = { op = e.op, oid = e.oid, ok = ok, why = why, template = e.template or (alive and SceneObject(p):getObjectName()) or "?", planet = planet }
	end
	return out
end

-- worldEdits[:<planet>] → INFO line per edit, verdict included
function FbLabTests:worldEdits(planet)
	local n = 0
	for _, pl in ipairs(planet and { planet } or { "tatooine", "naboo", "corellia", "talus", "rori", "dantooine", "lok", "yavin4", "endor", "dathomir" }) do
		for _, l in ipairs(FbLabTests.worldEditLines(pl)) do
			n = n + 1
			print(string.format("INFO worldedit planet=%s op=%s oid=%d template=%s ok=%s why=%s", l.planet, l.op, l.oid, tostring(l.template), tostring(l.ok), (l.why:gsub(" ", "_"))))
		end
	end
	if n == 0 then print("INFO worldedit none (tre-src/world/ has no edits)") end
	return tostring(n)
end

-- Lab check: every world edit in fb_world_edits.lua is what the server built from the installed snapshot
function FbLabTests.checkWorldEdits()
	local n = 0
	for _, pl in ipairs({ "tatooine", "naboo", "corellia", "talus", "rori", "dantooine", "lok", "yavin4", "endor", "dathomir" }) do
		if isZoneEnabled(pl) then
			for _, l in ipairs(FbLabTests.worldEditLines(pl)) do
				n = n + 1
				check("worldedit." .. pl .. "." .. l.op .. "." .. l.oid, l.ok, l.why .. (l.ok and "" or " — is the patched finalboss.tre installed and the server restarted since the edit?"))
			end
		end
	end
	if n == 0 then print("INFO worldedit: no edits to check") end
end

-- terrainGrid:<planet>:<x0>:<y0>:<x1>:<y1>:<step>:<path> → writes the terrain heights of the box (south-west to
-- north-east corner, every <step> m, rows from y0 northwards) into <path> as text: a header line
-- "planet x0 y0 x1 y1 step cols rows" then one row per line of %.2f heights. The site planner draws it as relief.
function FbLabTests:terrainGrid(planet, x0, y0, x1, y1, step, path)
	x0, y0, x1, y1, step = tonumber(x0), tonumber(y0), tonumber(x1), tonumber(y1), tonumber(step) or 4
	if planet == nil or x0 == nil or y0 == nil or x1 == nil or y1 == nil or path == nil or step <= 0 then print("ERROR terrainGrid: planet x0 y0 x1 y1 step path"); return "none" end
	if not isZoneEnabled(planet) then print("ERROR terrainGrid: zone " .. tostring(planet) .. " is not enabled"); return "none" end
	local cols, rows = math.floor((x1 - x0) / step) + 1, math.floor((y1 - y0) / step) + 1
	if cols * rows > 160000 then print(string.format("ERROR terrainGrid: %d points is too many (coarser step)", cols * rows)); return "none" end
	local f, err = io.open(path, "w")
	if f == nil then print("ERROR terrainGrid: cannot write " .. tostring(path) .. ": " .. tostring(err)); return "none" end
	f:write(string.format("%s %.1f %.1f %.1f %.1f %g %d %d\n", planet, x0, y0, x1, y1, step, cols, rows))
	local lo, hi = math.huge, -math.huge
	for r = 0, rows - 1 do
		local y = y0 + r * step
		local line = {}
		for c = 0, cols - 1 do
			local h = getTerrainHeightAt(planet, x0 + c * step, y)
			if h < lo then lo = h end
			if h > hi then hi = h end
			line[c + 1] = string.format("%.2f", h)
		end
		f:write(table.concat(line, " "), "\n")
	end
	f:close()
	print(string.format("INFO terrainGrid planet=%s cols=%d rows=%d step=%g min=%.2f max=%.2f path=%s", planet, cols, rows, step, lo, hi, path))
	return tostring(cols * rows)
end

-- ---------------------------------------------------------------- Force attunement (Phase 4a.1)

local function attunementLine(charName, pPlayer)
	local st = FbAttunement:status(pPlayer)
	local f = st.flags
	print(string.format("INFO attunement char=%s total=%d tier=%d places=%d/%d learning=%d/%d deeds=%d/%d quests=%d/%d items=%d/%d ghost25=%s ghost50=%s ghost75=%s called=%s task=%s medWorlds=%s lore=%d returned=%s trials=%s ambushDue=%s ambushDone=%s",
		charName, st.total, st.tier, st.per.places, st.raw.places, st.per.learning, st.raw.learning, st.per.deeds, st.raw.deeds, st.per.quests, st.raw.quests, st.per.items, st.raw.items,
		tostring(f.ghost25 ~= nil), tostring(f.ghost50 ~= nil), tostring(f.ghost75 ~= nil), tostring(f.called ~= nil), tostring(f.task or "-"), tostring(f.medWorlds or "-"),
		FbAttunement:loreCount(pPlayer), tostring(f["return"] ~= nil), tostring(f.trials ~= nil), tostring(f.ambushDue or "-"), tostring(f.ambushDone ~= nil)))
	return st
end

-- attunement:<char> → the hidden score with its per-source breakdown and flags
function FbLabTests:attunement(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local st = attunementLine(charName, pPlayer)
	return tostring(st.total)
end

-- attunementGrant:<char>:<source>:<key>:<pts> → FbAttunement:grant
function FbLabTests:attunementGrant(charName, source, key, pts)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local added = FbAttunement:grant(pPlayer, source, key, tonumber(pts) or 0, nil)
	print("INFO attunementGrant added=" .. tostring(added))
	attunementLine(charName, pPlayer)
	return tostring(added)
end

-- attunementReset:<char>
function FbLabTests:attunementReset(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbAttunement:reset(pPlayer)
	attunementLine(charName, pPlayer)
	return "ok"
end

-- attunementSet:<char>:<total> → reset, then fill debug points across the sources up to their caps
function FbLabTests:attunementSet(charName, total)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbAttunement:reset(pPlayer)
	local left = tonumber(total) or 0
	for _, src in ipairs(FbAttunement.sources) do
		local take = math.min(left, FbAttunement.caps[src])
		if take > 0 then FbAttunement:grant(pPlayer, src, "debug", take, nil) end
		left = left - take
	end
	-- a character set straight to this score has "had" the spirits below it (a real one met them on the way)
	for _, th in ipairs(FbAttunement.thresholds) do
		if (tonumber(total) or 0) >= th then FbAttunement:setFlag(pPlayer, "ghost" .. th, os.time()) end
	end
	attunementLine(charName, pPlayer)
	return tostring(FbAttunement:total(pPlayer))
end

-- attunementVisit:<char> → run the trigger now; says whether a visitor was sent
function FbLabTests:attunementVisit(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local sent = FbAttunement:maybeVisit(pPlayer)
	print(string.format("INFO attunementVisit sent=%s inPosition=%s combat=%s", tostring(sent), tostring(FbForceGhostVisit:isPlayerInPositionForEncounter(pPlayer)), tostring(CreatureObject(pPlayer):isInCombat())))
	attunementLine(charName, pPlayer)
	return tostring(sent)
end

-- attunementEnter:<char> → the place-entry handler for wherever the character stands (the region observer path minus the region)
function FbLabTests:attunementEnter(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local so = SceneObject(pPlayer)
	local key, kind = FbAttunement:placeAt(so:getZoneName(), so:getWorldPositionX(), so:getWorldPositionY())
	FbAttunement:onEnterArea(nil, pPlayer)
	print(string.format("INFO attunementEnter place=%s kind=%s", tostring(key), tostring(kind)))
	attunementLine(charName, pPlayer)
	return tostring(key)
end

-- attunementKill:<char>:<template> → spawn that template beside the character, run the kill handler as if the
-- character had killed it, remove it (nothing fights). attunementIncap:<char> marks an incapacitation just before.
function FbLabTests:attunementKill(charName, template)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local so = SceneObject(pPlayer)
	local pMob = spawnMobile(so:getZoneName(), template, 0, so:getWorldPositionX() + 3, so:getWorldPositionZ(), so:getWorldPositionY() + 3, 0, 0)
	if pMob == nil then print("ERROR attunementKill: spawnMobile failed for " .. tostring(template)); return "none" end
	FbAttunement:onKill(pPlayer, pMob)
	local oid = SceneObject(pMob):getObjectID()
	SceneObject(pMob):destroyObjectFromWorld(true); SceneObject(pMob):destroyObjectFromDatabase()
	FbLabTests.registryRemove(oid)
	attunementLine(charName, pPlayer)
	return "ok"
end

function FbLabTests:attunementIncap(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbAttunement:onIncap(pPlayer, nil)
	print("INFO attunementIncap at=" .. tostring(FbAttunement:flag(pPlayer, "incapAt")))
	return "ok"
end

-- attunementMeditate:<char> → is the character meditating, and is a shrine watch running?
function FbLabTests:attunementMeditate(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local med = CreatureObject(pPlayer):isMeditating()
	print(string.format("INFO attunementMeditate meditating=%s posture=%d watch=%s", tostring(med), CreatureObject(pPlayer):getPosture(), tostring(getQuestStatus("FbAttunement.poll." .. SceneObject(pPlayer):getObjectID()) or "-")))
	return tostring(med)
end

-- attunementLogin:<char> → run the login hook by hand (observers, silent credit, the deferred shrine check)
function FbLabTests:attunementLogin(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbAttunement:onLogin(pPlayer)
	print("INFO attunementLogin ran")
	return "ok"
end

-- attunementAccept:<char> → as if the Old Man's offer were accepted in conversation (called, task=shrines, ambush due)
function FbLabTests:attunementAccept(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbAttunement:accept(pPlayer)
	if FbVisions ~= nil then FbVisions:skipAll(pPlayer) end   -- 4a.4: the shortcut past the path skips its visions too
	attunementLine(charName, pPlayer)
	return "ok"
end

-- attunementWorlds:<char>:<planet,planet,…> → set the worlds meditated on (the shrine task's progress)
function FbLabTests:attunementWorlds(charName, worlds)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbAttunement:setFlag(pPlayer, "medWorlds", tostring(worlds or ""))
	attunementLine(charName, pPlayer)
	return tostring(FbAttunement:worldCount(pPlayer))
end

-- attunementAmbush:<char> → make the ambush due now and run the trigger
function FbLabTests:attunementAmbush(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbAttunement:setFlag(pPlayer, "ambushDue", os.time() - 1)
	deleteScreenPlayData(pPlayer, FbAttunement.DATA, "flag:ambushDone")
	local sent = FbAttunement:maybeVisit(pPlayer)
	print("INFO attunementAmbush sent=" .. tostring(sent))
	attunementLine(charName, pPlayer)
	return tostring(sent)
end

-- ---------------------------------------------------------------- the Padawan trials (4a.3)

local function trialsLine(charName, pPlayer)
	print(string.format("INFO trials char=%s task=%s done=%s count=%d current=%s prog=%s target=%s riddle=%s alignment=%s padawan=%s novice=%s cash=%d",
		charName, tostring(FbAttunement:flag(pPlayer, "task") or "-"), tostring(FbTrials:get(pPlayer, "done") or "-"), FbTrials:doneCount(pPlayer),
		tostring(FbTrials:current(pPlayer) or "-"), tostring(FbTrials:get(pPlayer, "prog") or "-"), tostring(FbTrials:get(pPlayer, "target") or "-"),
		tostring(FbTrials:get(pPlayer, "riddle") or "-"), tostring(FbAttunement:flag(pPlayer, "alignment") or "-"), tostring(FbAttunement:flag(pPlayer, "padawan") ~= nil),
		tostring(CreatureObject(pPlayer):hasSkill("force_title_jedi_novice")), CreatureObject(pPlayer):getCashCredits()))
end

-- trials:<char> → the trial state
function FbLabTests:trials(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	trialsLine(charName, pPlayer)
	return tostring(FbTrials:doneCount(pPlayer))
end

-- trialsUnlock:<char> → as if the Old Man's return were accepted (task=trials)
function FbLabTests:trialsUnlock(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbAttunement:trialsUnlocked(pPlayer)
	if FbVisions ~= nil then FbVisions:skipAll(pPlayer) end   -- 4a.4: the trials scenario is about the trials
	-- the lab's unlock skips the Old Man's return, so the hunters he warned of are marked as already come:
	-- the due ambush takes the trigger before a trial word and would interrupt a trials run (gate 2026-10-21)
	FbAttunement:setFlag(pPlayer, "ambushDone", os.time())
	trialsLine(charName, pPlayer)
	return "ok"
end

-- trialTick:<char> → run the trigger (the word for the next trial, or its visitor)
function FbLabTests:trialTick(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local sent = FbAttunement:maybeVisit(pPlayer)
	print("INFO trialTick sent=" .. tostring(sent))
	if not sent then
		-- why not: the gates the trigger passes through, read the same way maybeVisit / FbVisions read them
		local oid = SceneObject(pPlayer):getObjectID()
		local visit = tonumber(getQuestStatus("FbAttunement.visit." .. oid) or 0) or 0
		local c = CreatureObject(pPlayer)
		print(string.format("INFO trialTickWhy visitAge=%s combat=%s dead=%s incap=%s riding=%s parent=%s zone=%s visionActive=%s visionDue=%s canLeave=%s trialActive=%s",
			visit > 0 and tostring(os.time() - visit) or "-", tostring(c:isInCombat()), tostring(c:isDead()), tostring(c:isIncapacitated()), tostring(c:isRidingMount()),
			tostring(SceneObject(pPlayer):getParentID()), SceneObject(pPlayer):getZoneName(),
			tostring(FbVisions and FbVisions:active(pPlayer) or "-"), tostring(FbVisions and FbVisions:due(pPlayer) or "-"), tostring(FbVisions and FbVisions:canLeave(pPlayer) or "-"),
			tostring(FbTrials and FbTrials:active(pPlayer) or "-")))
	end
	trialsLine(charName, pPlayer)
	return tostring(sent)
end

-- trialProgress:<char>:<n> → set the current trial's progress counter (seconds or kills)
function FbLabTests:trialProgress(charName, n)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbTrials:set(pPlayer, "prog", tonumber(n) or 0)
	trialsLine(charName, pPlayer)
	return "ok"
end

-- trialSetDone:<char>:<id,id,…> → mark trials done (and clear the current one)
function FbLabTests:trialSetDone(charName, ids)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbTrials:set(pPlayer, "done", tostring(ids or ""))
	FbTrials:clear(pPlayer, "current"); FbTrials:clear(pPlayer, "prog"); FbTrials:clear(pPlayer, "target")
	trialsLine(charName, pPlayer)
	return "ok"
end

-- cashSet:<char>:<credits> → set the character's cash (the sacrifice trial)
-- visitSettle:<char>: run the visitors' settle now (what the 30 s event does) and report where each stands
function FbLabTests:visitSettle(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local SpawnMobiles = require("utils.spawn_mobiles")
	local px, py = SceneObject(pPlayer):getWorldPositionX(), SceneObject(pPlayer):getWorldPositionY()
	for _, v in ipairs({ FbOldManVisit, FbOldManReturn, FbTrialSpirit }) do
		if v ~= nil and v.settle ~= nil then
			local spawned = SpawnMobiles.getSpawnedMobiles(pPlayer, v.taskName)
			if spawned ~= nil and #spawned > 0 then
				v:settle(pPlayer)
				for _, pNpc in ipairs(spawned) do
					if SpawnMobiles.isValidMobile(pNpc) then
						local so = SceneObject(pNpc)
						local dx, dy = so:getWorldPositionX() - px, so:getWorldPositionY() - py
						print(string.format("INFO visitSettle task=%s oid=%s dist=%.1f x=%.1f y=%.1f ai=%s", v.taskName, tostring(so:getObjectID()), math.sqrt(dx * dx + dy * dy), so:getWorldPositionX(), so:getWorldPositionY(), tostring(CreatureObject(pNpc):getOptionsBitmask())))
					end
				end
			end
		end
	end
	return "ok"
end

function FbLabTests:cashSet(charName, amount)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local have = CreatureObject(pPlayer):getCashCredits()
	local want = tonumber(amount) or 0
	if want > have then CreatureObject(pPlayer):addCashCredits(want - have, true) elseif want < have then CreatureObject(pPlayer):subtractCashCredits(have - want) end
	print("INFO cashSet cash=" .. CreatureObject(pPlayer):getCashCredits())
	return tostring(CreatureObject(pPlayer):getCashCredits())
end

-- Lab check: the trials are wired and every trial has its word and done line in the string source
-- ---------------------------------------------------------------- Phase 4a.4: visions

local function visionsLine(charName, pPlayer)
	print("INFO visions char=" .. charName .. " " .. FbVisions:status(pPlayer) .. " zone=" .. SceneObject(pPlayer):getZoneName() .. " alignment=" .. tostring(FbAttunement:flag(pPlayer, "alignment") or "-"))
end

-- visions:<char> → seen / due / active and where the character is
function FbLabTests:visions(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	visionsLine(charName, pPlayer)
	return "ok"
end

-- visionBegin:<char>:<id> → start that vision now (eligibility not checked; the character must be outdoors)
function FbLabTests:visionBegin(charName, id)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local ok = FbVisions:begin(pPlayer, id)
	print("INFO visionBegin id=" .. tostring(id) .. " began=" .. tostring(ok))
	visionsLine(charName, pPlayer)
	return tostring(ok)
end

-- visionEnd:<char> → wake now (the fade), as if the lines were over
function FbLabTests:visionEnd(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local active = FbVisions:active(pPlayer)
	if active ~= nil then FbVisions:finish(pPlayer, false) end
	print("INFO visionEnd ended=" .. tostring(active or "-"))
	visionsLine(charName, pPlayer)
	return "ok"
end

-- visionsReset:<char> → forget every vision seen (the lab shortcuts mark them all seen)
-- visionsSkip:<char> → every vision marked seen (what attunementAccept / trialsUnlock do): a scenario that sets the path's
-- flags by hand would otherwise get a vision at its first kill, and the zone change stores the character's pets
function FbLabTests:visionsSkip(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbVisions:skipAll(pPlayer)
	print("INFO visionsSkip done")
	return "ok"
end
function FbLabTests:visionsReset(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbVisions:reset(pPlayer)
	visionsLine(charName, pPlayer)
	return "ok"
end

-- attunementFlag:<char>:<flag>[:<value>] → set (or clear) one FbAttunement flag, e.g. alignment light
function FbLabTests:attunementFlag(charName, flag, value)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	if value == nil or value == "" or value == "-" then deleteScreenPlayData(pPlayer, FbAttunement.DATA, "flag:" .. flag) else FbAttunement:setFlag(pPlayer, flag, value) end
	print("INFO attunementFlag " .. tostring(flag) .. "=" .. tostring(FbAttunement:flag(pPlayer, flag) or "-"))
	return "ok"
end

function FbLabTests.checkVisions()
	check("visions.loaded", FbVisions ~= nil and FbVisions.list ~= nil)
	if FbVisions == nil then return end
	check("visions.six", #FbVisions.list == 6)
	check("visions.zone_enabled", isZoneEnabled(FbVisions.zone), FbVisions.zone)
	local f = io.open("../../tre-src/string/en/fb_force.stf.txt", "r")
	if f ~= nil then
		local text = f:read("a"); f:close()
		local missing = {}
		local function need(k) if not text:find("\n" .. k .. " = ", 1, true) then missing[#missing + 1] = k end end
		need("vision_enter"); need("vision_fade")
		for _, v in ipairs(FbVisions.list) do
			for _, who in ipairs({ v.light, v.dark }) do
				for n = 1, v.lines do need(string.format("vision_%s_%s_%d", v.id, who, n)) end
				need(string.format("vision_%s_%s_whisper", v.id, who))
			end
			-- after the alignment is set both figures of a side speak: their lines must exist for every vision
			for key, fig in pairs(FbVisions.figures) do
				for n = 1, v.lines do need(string.format("vision_%s_%s_%d", v.id, key, n)) end
			end
		end
		check("visions.strings", #missing == 0, #missing == 0 and "every line of every figure in every vision" or ("missing: " .. table.concat(missing, ", ")))
	end
	-- the figures' mobile files (checkNpc loads and audits them like every fb_* mobile; eventNpcs says they
	-- never spawn at boot and never converse)
	for key, fig in pairs(FbVisions.figures) do
		local mf = io.open("scripts/mobile/quest/tatooine/" .. fig.template .. ".lua", "r")
		check("visions.figure." .. key, mf ~= nil, fig.template)
		if mf ~= nil then mf:close() end
	end
end

-- ---------------------------------------------------------------- Phase 4b.1 / 4b.2: the Masters

local function masterLine(charName, pPlayer, m)
	print("INFO " .. (m.side == "light" and "jediMaster" or "sithMaster") .. " char=" .. charName .. " " .. m:status(pPlayer) .. " xp=" .. tostring(PlayerObject(CreatureObject(pPlayer):getPlayerObject()):getExperience("jedi_general")))
end
-- the Master a lab call means: the student's own, else the named side, else the light one
local function masterFor(pPlayer, side)
	if side == "dark" then return FbSithMaster elseif side == "light" then return FbJediMaster end
	return FbMasters.of(pPlayer) or FbJediMaster
end

-- jediMaster:<char> / sithMaster:<char> → the student's state as that Master sees it, and her opening screen
local function masterStatus(charName, m)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	masterLine(charName, pPlayer, m)
	print("INFO " .. (m.side == "light" and "jediMaster" or "sithMaster") .. " screen=" .. m:screenFor(pPlayer) .. " npc=" .. tostring(m:npc() ~= nil))
	return "ok"
end
function FbLabTests:jediMaster(charName) return masterStatus(charName, FbJediMaster) end
function FbLabTests:sithMaster(charName) return masterStatus(charName, FbSithMaster) end

-- jediMasterTake:<char> / sithMasterTake:<char> → be taken as that Master's student without the conversation
local function masterTake(charName, m)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	print("INFO " .. (m.side == "light" and "jediMasterTake" or "sithMasterTake") .. " taken=" .. tostring(m:take(pPlayer)))
	masterLine(charName, pPlayer, m)
	return "ok"
end
function FbLabTests:jediMasterTake(charName) return masterTake(charName, FbJediMaster) end
function FbLabTests:sithMasterTake(charName) return masterTake(charName, FbSithMaster) end

-- trainingSet:<char>:<task>:told|ready|done[:light|dark] → push a task of the student's Master to that state
function FbLabTests:trainingSet(charName, id, state, side)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local m = masterFor(pPlayer, side)
	if state == "told" then m:told(pPlayer, id)
	elseif state == "ready" then m:set(pPlayer, "told:" .. id, os.time()); m:complete(pPlayer, id)
	elseif state == "done" then m:set(pPlayer, "told:" .. id, os.time()); m:set(pPlayer, "ready:" .. id, os.time()); m:reward(pPlayer, id) end
	masterLine(charName, pPlayer, m)
	return "ok"
end

-- trainingTick:<char>[:light|dark] → run the sit poll of the student's Master once, now
function FbLabTests:trainingTick(charName, side)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local m = masterFor(pPlayer, side)
	removeQuestStatus(m.name .. ".sit." .. SceneObject(pPlayer):getObjectID())   -- the poll chain restarts from here
	m:pollSit(pPlayer)
	masterLine(charName, pPlayer, m)
	return "ok"
end

local function checkMaster(m, tag)
	check(tag .. ".loaded", m ~= nil and m.tasks ~= nil)
	if m == nil then return end
	check(tag .. ".four_tasks", #m.tasks == 4, "two of training, two ranks")
	if isZoneEnabled(m.zone) then
		check(tag .. ".enclave_room", m:cell() ~= nil, m.room .. " of " .. m.buildingOid)
		check(tag .. ".stands", m:npc() ~= nil, "spawned at boot into the " .. m.room)
	end
	local f = io.open("../../tre-src/string/en/fb_force.stf.txt", "r")
	if f ~= nil then
		local text = f:read("a"); f:close()
		local missing = {}
		local function need(k) if not text:find("\n" .. k .. " = ", 1, true) then missing[#missing + 1] = k end end
		for _, k in ipairs({ "stranger", "otherdoor", "offer", "take", "later", "taken", "told", "trained", "trained_note", "rank_wait_xp", "turn", "turned", "promoted" }) do need(m.prefix .. k) end
		for _, t in ipairs(m.tasks) do
			for _, k in ipairs({ "train", "wait", "done", "reward" }) do need(m.prefix .. k .. "_" .. t.id) end
			need(m.prefix .. t.id .. "_done")
			if t.kind == "kill" then need(m.prefix .. t.id .. "_progress") end
		end
		check(tag .. ".strings", #missing == 0, #missing == 0 and "every screen and note" or ("missing: " .. table.concat(missing, ", ")))
	end
end
function FbLabTests.checkJediMaster() checkMaster(FbJediMaster, "jedimaster") end

-- masterTurn:<char>:light|dark → turn to that Master's side without the conversation (4b.3)
function FbLabTests:masterTurn(charName, side)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local m = side == "dark" and FbSithMaster or FbJediMaster
	print("INFO masterTurn side=" .. tostring(side) .. " turned=" .. tostring(m:turn(pPlayer)))
	masterLine(charName, pPlayer, m)
	return "ok"
end

-- alignment:<char> / alignmentShift:<char>:<delta> / alignmentSet:<char>:<score> → the 4b.3 score
local function alignmentLine(charName, pPlayer)
	print("INFO alignment char=" .. charName .. " " .. FbAlignment:status(pPlayer) .. " statusLine=" .. tostring(FbAlignment:statusLine(pPlayer) or "-"))
end
function FbLabTests:alignment(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	alignmentLine(charName, pPlayer)
	return "ok"
end
function FbLabTests:alignmentShift(charName, delta)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbAlignment:shift(pPlayer, tonumber(delta) or 0, "lab")
	alignmentLine(charName, pPlayer)
	return "ok"
end
function FbLabTests:alignmentSet(charName, score)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbAlignment:set(pPlayer, tonumber(score) or 0)
	alignmentLine(charName, pPlayer)
	return "ok"
end

function FbLabTests.checkAlignment()
	check("alignment.loaded", FbAlignment ~= nil and FbAlignment.killShifts ~= nil)
	if FbAlignment == nil then return end
	check("alignment.tiers", FbAlignment:tier(100) == 5 and FbAlignment:tier(0) == 3 and FbAlignment:tier(-100) == 1 and FbAlignment:tier(30) == 4 and FbAlignment:tier(-30) == 2)
	local f = io.open("../../tre-src/string/en/fb_force.stf.txt", "r")
	if f ~= nil then
		local text = f:read("a"); f:close()
		local missing = {}
		for n = 1, 5 do if not text:find("\nalign_tier_" .. n .. " = ", 1, true) then missing[#missing + 1] = "align_tier_" .. n end end
		check("alignment.strings", #missing == 0, #missing == 0 and "five tiers" or ("missing: " .. table.concat(missing, ", ")))
	end
end
function FbLabTests.checkSithMaster() checkMaster(FbSithMaster, "sithmaster") end

-- ---------------------------------------------------------------- Phase 4b.4: the Knight trial

local function knightLine(charName, pPlayer)
	print("INFO knight char=" .. charName .. " " .. FbKnight:status(pPlayer) .. " frsRank=" .. tostring(PlayerObject(CreatureObject(pPlayer):getPlayerObject()):getFrsRank()) .. " align=" .. tostring(FbAlignment ~= nil and FbAlignment:score(pPlayer) or 0))
end
function FbLabTests:knight(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	knightLine(charName, pPlayer)
	local m = FbMasters.of(pPlayer)
	print("INFO knight screen=" .. tostring(m ~= nil and m:screenFor(pPlayer) or "-"))
	return "ok"
end
-- knightGive:<char> → the trial given without the conversation (the enemy spawns at its place)
function FbLabTests:knightGive(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	print("INFO knightGive given=" .. tostring(FbKnight:give(pPlayer)))
	knightLine(charName, pPlayer)
	return "ok"
end
-- knightBossHere:<char> → the student's enemy moved beside the student (the bot does not walk a cave)
function FbLabTests:knightBossHere(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local pBoss = FbKnight:ensureBoss(pPlayer)
	if pBoss == nil then print("ERROR no enemy"); return "none" end
	-- harmless before it stands beside a lab character: a level-125 aggressive enemy two metres from a fresh
	-- character killed it in two seconds (gate 2026-10-22), and a dead character failed every scenario after
	if not FbKnight:yielded(pBoss) then FbKnight:yield(pBoss) end
	local so = SceneObject(pPlayer)
	local x, y, zone, cell = so:getWorldPositionX() + 2.5, so:getWorldPositionY(), so:getZoneName(), so:getParentID()
	local z = cell == 0 and getTerrainHeightAt(zone, x, y) or so:getWorldPositionZ()
	if cell == 0 then SceneObject(pBoss):switchZone(zone, x, z, y, 0) else SceneObject(pBoss):switchZone(zone, so:getPositionX() + 2.5, so:getPositionZ(), so:getPositionY(), cell) end
	AiAgent(pBoss):setHomeLocation(x, z, y, nil)
	print("INFO knightBossHere oid=" .. tostring(SceneObject(pBoss):getObjectID()) .. " los=" .. tostring(AiAgent(pBoss):checkLineOfSight(pPlayer)))
	return "ok"
end
-- knightYield:<char> → the enemy yields now, as the damage observer would below a quarter of its health
function FbLabTests:knightYield(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local pBoss = FbKnight:bossOf(pPlayer)
	if pBoss == nil then print("ERROR no enemy"); return "none" end
	print("INFO knightYield yielded=" .. tostring(FbKnight:yield(pBoss)))
	knightLine(charName, pPlayer)
	return "ok"
end
-- knightChoose:<char>:spare|kill → the choice without the conversation
function FbLabTests:knightChoose(charName, choice)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local pBoss = FbKnight:bossOf(pPlayer)
	if pBoss == nil then print("ERROR no enemy"); return "none" end
	if not FbKnight:yielded(pBoss) then FbKnight:yield(pBoss) end
	local ok = choice == "kill" and FbKnight:execute(pPlayer, pBoss) or FbKnight:spare(pPlayer, pBoss)
	print("INFO knightChoose choice=" .. tostring(choice) .. " ok=" .. tostring(ok))
	knightLine(charName, pPlayer)
	return "ok"
end
-- knightGraduate:<char> → the report without the conversation
function FbLabTests:knightGraduate(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	print("INFO knightGraduate ok=" .. tostring(FbKnight:graduate(pPlayer)))
	knightLine(charName, pPlayer)
	return "ok"
end

function FbLabTests.checkKnight()
	check("knight.loaded", FbKnight ~= nil and FbKnight.sides ~= nil)
	if FbKnight == nil then return end
	for side, d in pairs(FbKnight.sides) do
		local mf = io.open("scripts/mobile/quest/tatooine/" .. d.boss .. ".lua", "r")
		check("knight." .. side .. ".enemy_file", mf ~= nil, d.boss); if mf ~= nil then mf:close() end
		if isZoneEnabled(d.zone) and d.buildingOid ~= nil then
			local pB = getSceneObject(d.buildingOid)
			check("knight." .. side .. ".place", pB ~= nil and BuildingObject(pB):getNamedCell(d.room) ~= nil, d.room .. " of " .. d.buildingOid)
		end
	end
	local f = io.open("../../tre-src/string/en/fb_force.stf.txt", "r")
	if f ~= nil then
		local text = f:read("a"); f:close()
		local missing = {}
		local function need(k) if not text:find("\n" .. k .. " = ", 1, true) then missing[#missing + 1] = k end end
		for _, k in ipairs({ "boss_nothing", "boss_yield", "boss_spared", "boss_killed", "light_yield", "dark_yield" }) do need("knight_" .. k) end
		for _, prefix in ipairs({ "master_", "sith_" }) do
			for _, k in ipairs({ "offer", "go", "given", "wait", "report", "done", "spare", "kill", "graduated" }) do need(prefix .. "knight_" .. k) end
		end
		check("knight.strings", #missing == 0, #missing == 0 and "every line of the trial" or ("missing: " .. table.concat(missing, ", ")))
	end
end

-- ---------------------------------------------------------------- Phase 4b.5: the companion

local function companionLine(charName, pPlayer)
	local m = FbMasters ~= nil and FbMasters.of(pPlayer) or nil
	local _, pPet = FbCompanion:isOut(pPlayer)
	print("INFO companion char=" .. charName .. " " .. FbCompanion:status(pPlayer)
		.. " petName=" .. (pPet and tostring(SceneObject(pPet):getCustomObjectName()):gsub(" ", "_") or "-")
		.. " petCombat=" .. (pPet and tostring(CreatureObject(pPet):isInCombat()) or "-")
		.. " screen=" .. tostring(m and m:screenFor(pPlayer) or "-")
		.. " align=" .. tostring(FbAlignment and FbAlignment:score(pPlayer) or "-")
		.. " statusLine=" .. tostring(FbCompanion:statusLine(pPlayer) or "-"))
end
-- companion:<char> → the companion's state, the pet, the Master's opening screen
function FbLabTests:companion(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	companionLine(charName, pPlayer)
	return "ok"
end
local function companionDo(name, fn)
	FbLabTests[name] = function(self, charName, a, b)
		local pPlayer = loadedPlayer(charName)
		if pPlayer == nil then return "offline" end
		print("INFO " .. name .. " ok=" .. tostring(fn(pPlayer, a, b)))
		companionLine(charName, pPlayer)
		return "ok"
	end
end
-- companionGive:<char> → taken from the Master without the conversation; companionCall / companionStore → the pet out / away
companionDo("companionGive", function(p) return FbCompanion:give(p) end)
companionDo("companionCall", function(p) return FbCompanion:call(p) end)
companionDo("companionStore", function(p) return FbCompanion:store(p) end)
-- companionKills:<char>:<n> → n kills credited with the companion out (the stages follow)
companionDo("companionKills", function(p, n) return FbCompanion:credit(p, tonumber(n) or 1) end)
-- companionDefend:<char>:<attackerOid> → as if the attacker hit the character: the companion goes for it
companionDo("companionDefend", function(p, oid) local pMob = getSceneObject(tonumber(oid) or 0); if pMob == nil then return false end; FbCompanion:onDamage(p, pMob, 1); return true end)
-- companionSpeak:<char>:<kind> → one line of that kind (idle, fight, kill, down, shrine, farewell, betray_last)
companionDo("companionSpeak", function(p, kind) local _, d = FbCompanion:sideOf(p); return d ~= nil and FbCompanion:speak(p, kind, d[kind] or 1) end)
-- companionTrialGive:<char>, companionShrine:<char>:<shrineKey>, companionKnight:<char> → the light capstone
companionDo("companionTrialGive", function(p) return FbCompanion:trialGive(p) end)
companionDo("companionShrine", function(p, key) FbCompanion:onShrine(p, key); return true end)
companionDo("companionKnight", function(p) return FbCompanion:knight(p) end)
-- companionBetray:<char>, companionTurn:<char> (the turn now, whatever the day's roll), companionLose:<char> (the turned apprentice wins)
companionDo("companionBetray", function(p) return FbCompanion:betray(p) end)
companionDo("companionTurn", function(p) return FbCompanion:turn(p) end)
companionDo("companionLose", function(p) local pT = FbCompanion:turnedOf(p); if pT == nil then return false end; FbCompanion:onIncap(p, pT); return true end)
companionDo("companionReset", function(p) FbCompanion:reset(p); return true end)
-- companionDied:<char> → the device destroyed as the stock kill path does it, then the state read (the companion is dead)
companionDo("companionDied", function(p) local pD = FbCompanion:deviceOf(p); if pD == nil then return false end; FbCompanion:store(p); SceneObject(pD):destroyObjectFromWorld(true); SceneObject(pD):destroyObjectFromDatabase(); FbCompanion:checkAlive(p); return true end)
companionDo("companionTakeAgain", function(p) return FbCompanion:takeAgain(p) end)
-- companionProbe:<char>[:<attackerOid>] → the pet's AI as the server sees it: last command and target, movement state,
-- follow object, combat, owner, and whether the attacker is attackable by the pet (for the defence's debugging)
function FbLabTests:companionProbe(charName, attackerOid)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local out, pPet = FbCompanion:isOut(pPlayer)
	if pPet == nil then print("INFO companionProbe pet=-"); return "none" end
	-- the AiAgent getters on a stored (zoneless) pet throw a C++ exception that dirties the console Lua stack: stop short
	if not out then
		-- no AiAgent getter here (they segfault on a stored pet); the plain object getters are safe
		print(string.format("INFO companionProbe out=false zone=%s dead=%s posture=%d parent=%s x=%.1f y=%.1f ham=%d/%d (stored or dead; no AI state read)",
			SceneObject(pPet):getZoneName(), tostring(CreatureObject(pPet):isDead()), CreatureObject(pPet):getPosture(), tostring(SceneObject(pPet):getParentID()),
			SceneObject(pPet):getWorldPositionX(), SceneObject(pPet):getWorldPositionY(), CreatureObject(pPet):getHAM(0), CreatureObject(pPet):getMaxHAM(0)))
		return "stored"
	end
	local a = AiAgent(pPet)
	local pF, pT = a:getFollowObject(), a:getLastCommandTarget()
	local line = string.format("INFO companionProbe out=%s lastCommand=%s lastTarget=%s moveState=%s follow=%s combat=%s owner=%s level=%d",
		tostring(out), tostring(a:getLastCommand()), pT and tostring(SceneObject(pT):getObjectID()) or "-", tostring(a:getMovementState()),
		pF and tostring(SceneObject(pF):getObjectID()) or "-", tostring(CreatureObject(pPet):isInCombat()), tostring(a:getOwner() ~= nil), CreatureObject(pPet):getLevel())
	local pMob = getSceneObject(tonumber(attackerOid) or 0)
	line = line .. string.format(" petFaction=%s ownerFaction=%s", tostring(CreatureObject(pPet):getFaction()), tostring(CreatureObject(pPlayer):getFaction()))
	if pMob ~= nil then line = line .. " attackableByPet=" .. tostring(AiAgent(pMob):isAttackableBy(pPet)) .. " attackableByOwner=" .. tostring(AiAgent(pMob):isAttackableBy(pPlayer)) .. " petAttackableByMob=" .. tostring(AiAgent(pPet):isAttackableBy(pMob)) .. " mobFaction=" .. tostring(CreatureObject(pMob):getFaction()) end
	print(line)
	return "ok"
end
-- hamSet:<char>:<value> → the three pools' maxima and current values set (a lab character that must survive a fight)
function FbLabTests:hamSet(charName, value)
	local pPlayer = onlinePlayer(charName)
	if pPlayer == nil then return "offline" end
	local v = tonumber(value) or 1000
	for _, pool in ipairs({ 0, 3, 6 }) do CreatureObject(pPlayer):setMaxHAM(pool, v); CreatureObject(pPlayer):setHAM(pool, v) end
	return hamLine(charName, pPlayer)
end

function FbLabTests.checkCompanion()
	check("companion.loaded", FbCompanion ~= nil and FbCompanion.sides ~= nil)
	if FbCompanion == nil then return end
	for side, d in pairs(FbCompanion.sides) do
		local files = { table.unpack(d.stages) }
		if d.turned ~= nil then files[#files + 1] = d.turned end
		for _, name in ipairs(files) do
			local f = io.open("scripts/mobile/quest/tatooine/" .. name .. ".lua", "r")
			check("companion." .. side .. "." .. name, f ~= nil, name .. ".lua"); if f ~= nil then f:close() end
		end
	end
	local function fileText(path) local f = io.open(path, "r"); if f == nil then return nil end; local t = f:read("a"); f:close(); return t end
	local conv = { light = fileText("scripts/mobile/conversations/tasks/fb_jedi_master_conv.lua"), dark = fileText("scripts/mobile/conversations/tasks/fb_sith_master_conv.lua") }
	local screens = { light = { "comp_offer", "comp_take", "comp_later", "comp_has", "comp_trial_offer", "comp_trial_go", "comp_trial_wait", "comp_trial_report", "comp_knighted", "comp_knighted_after", "comp_dead", "comp_take_again" },
		dark = { "comp_offer", "comp_take", "comp_later", "comp_dark_has", "comp_betray_ask", "comp_betray_do", "comp_betrayed_after", "comp_turned_wait", "comp_former_after", "comp_slain_after", "comp_dead", "comp_take_again" } }
	for side, list in pairs(screens) do
		local missing = {}
		for _, id in ipairs(list) do if conv[side] == nil or not conv[side]:find('screen("' .. id .. '"', 1, true) then missing[#missing + 1] = id end end
		check("companion." .. side .. ".screens", #missing == 0, #missing == 0 and "every screen" or ("missing: " .. table.concat(missing, ", ")))
	end
	local hooks = fileText("scripts/custom_scripts/screenplays/fb_attunement.lua") or ""
	local masters = fileText("scripts/custom_scripts/screenplays/fb_masters.lua") or ""
	check("companion.hooks", hooks:find("FbCompanion:onKill", 1, true) ~= nil and hooks:find("FbCompanion:onIncap", 1, true) ~= nil and hooks:find("FbCompanion:onShrine", 1, true) ~= nil
		and masters:find("FbCompanion:screenFor", 1, true) ~= nil and masters:find("FbCompanion:onLogin", 1, true) ~= nil and masters:find("FbCompanion:reset", 1, true) ~= nil, "attunement kill/incap/shrine, Masters screen/login/reset")
	check("companion.bindings", type(callControlDevice) == "function" and type(storeControlDevice) == "function" and type(getControlledObject) == "function", "callControlDevice / storeControlDevice / getControlledObject (DirectorManager)")
	local text = fileText("../../tre-src/string/en/fb_force.stf.txt")
	if text ~= nil then
		local missing = {}
		local function need(k) if not text:find("\n" .. k .. " = ", 1, true) then missing[#missing + 1] = k end end
		for _, k in ipairs({ "offer", "take", "later", "has", "trial_offer", "trial_go", "trial_wait", "trial_report", "knighted", "knighted_after", "dead" }) do need("master_comp_" .. k) end
		for _, k in ipairs({ "offer", "take", "later", "has", "betray_ask", "betray_do", "betrayed_after", "turned_wait", "former_after", "slain_after", "dead" }) do need("sith_comp_" .. k) end
		for _, k in ipairs({ "light_dead", "dark_dead", "status_dead_light", "status_dead_dark" }) do need("comp_" .. k) end
		for _, k in ipairs({ "light_given", "light_stage2", "light_stage3", "light_trial_given", "light_trial_shrine", "light_trial_ready", "light_knighted", "dark_given", "dark_stage2", "dark_stage3", "dark_betrayed", "dark_turned", "dark_lost", "dark_slain", "dark_escaped",
			"status_light", "status_dark", "status_knighted", "status_betrayed", "status_hunted", "status_former", "status_slain", "light_down_1", "light_shrine_1", "light_farewell_1", "dark_down_1", "dark_betray_last_1", "dark_turn_1", "dark_win_1" }) do need("comp_" .. k) end
		for side, d in pairs(FbCompanion.sides) do
			for _, kind in ipairs({ "idle", "fight", "kill" }) do for n = 1, d[kind] do need("comp_" .. side .. "_" .. kind .. "_" .. n) end end
		end
		check("companion.strings", #missing == 0, #missing == 0 and "every line" or ("missing: " .. table.concat(missing, ", ")))
	end
end

-- ---------------------------------------------------------------- Phase 2.4: loot kits

local function kitInventory(pPlayer) return SceneObject(pPlayer):getSlottedObject("inventory") end
local function kitItems(pInv, fragment)
	local list = {}
	for i = 0, SceneObject(pInv):getContainerObjectsSize() - 1 do
		local pItem = SceneObject(pInv):getContainerObject(i)
		if pItem ~= nil and SceneObject(pItem):getTemplateObjectPath():find(fragment, 1, true) then list[#list + 1] = pItem end
	end
	return list
end
-- kits → what the kit data and the roll look like from here
function FbLabTests:kits()
	local f = io.open("scripts/custom_scripts/object/tangible/fb_kits/fb_kits.lua", "r")
	local kits, parts = 0, 0
	if f ~= nil then for line in f:lines() do if line:find("templateType = LOOTKIT", 1, true) then kits = kits + 1 elseif line:find("SharedTangibleObjectTemplate:new", 1, true) then parts = parts + 1 end end; f:close() end
	print(string.format("INFO kits loaded=%s kitTemplates=%d partTemplates=%d tiers=%d", tostring(FbLootKits ~= nil), kits, parts, FbLootKits and #FbLootKits.tiers or 0))
	return "ok"
end
-- kitGive:<char>:<kitId> → that kit in the bag (kitId as in the generated data: bone_chest_plate_1, dl44_2 …)
function FbLabTests:kitGive(charName, kitId)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local pInv = kitInventory(pPlayer)
	createLoot(pInv, "fb_kit_" .. kitId, 10, false)
	local have = kitItems(pInv, "fb_kits/kit_" .. kitId .. ".iff")
	print("INFO kitGive kit=" .. kitId .. " oid=" .. (have[#have] and tostring(SceneObject(have[#have]):getObjectID()) or "-") .. " count=" .. #have)
	return "ok"
end
-- kitParts:<char>:<class>:<tier> → the tier's parts of that class (armor / weapon) in the bag, one of each kind
function FbLabTests:kitParts(charName, class, tier)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local pInv = kitInventory(pPlayer)
	local kinds = class == "weapon" and { "mechanism", "cell", "barrel", "core", "sight" } or { "plating", "mesh", "fastener", "lining", "trim" }
	local want = ({ 3, 4, 5 })[tonumber(tier) or 1] or 5   -- a tier's kit asks for the first 3 / 4 / 5 kinds
	local n = 0
	for i, k in ipairs(kinds) do if i <= want and createLoot(pInv, "fb_part_" .. class .. "_" .. k .. "_" .. tier, 10, false) ~= nil then n = n + 1 end end
	print("INFO kitParts class=" .. class .. " tier=" .. tostring(tier) .. " made=" .. n .. " inBag=" .. #kitItems(pInv, "fb_kits/part_"))
	return "ok"
end
-- kitAssemble:<char>:<kitOid> → every part in the bag moved into the kit (the stock container path: the last one makes the piece)
function FbLabTests:kitAssemble(charName, kitOid)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local pKit = getSceneObject(tonumber(kitOid) or 0)
	if pKit == nil then print("ERROR no kit " .. tostring(kitOid)); return "none" end
	local pInv = kitInventory(pPlayer)
	local moved = 0
	for _, pPart in ipairs(kitItems(pInv, "fb_kits/part_")) do
		if SceneObject(pKit):transferObject(pPart, -1, true) then moved = moved + 1 end
	end
	local gone = #kitItems(pInv, "fb_kits/kit_") == 0   -- the finished kit destroys itself; a destroyed object may still resolve by id for a moment
	print("INFO kitAssemble moved=" .. moved .. " kitGone=" .. tostring(gone) .. " partsLeft=" .. #kitItems(pInv, "fb_kits/part_"))
	return "ok"
end
-- lootItem:<char>:<lootItemName> → that loot item made straight into the bag (the kit path aside) and its stats
function FbLabTests:lootItem(charName, name)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local pInv = kitInventory(pPlayer)
	local before = SceneObject(pInv):getContainerObjectsSize()
	createLoot(pInv, name, 10, true)
	local pNew = SceneObject(pInv):getContainerObject(SceneObject(pInv):getContainerObjectsSize() - 1)
	if SceneObject(pInv):getContainerObjectsSize() == before or pNew == nil then print("ERROR lootItem: nothing made for " .. tostring(name)); return "none" end
	print("INFO lootItem name=" .. name .. " oid=" .. tostring(SceneObject(pNew):getObjectID()) .. " " .. getItemStats(pNew))
	return "ok"
end
-- itemStats:<oid> → what the piece does (getItemStats, DirectorManager)
function FbLabTests:itemStats(oid)
	local pObj = getSceneObject(tonumber(oid) or 0)
	if pObj == nil then print("ERROR no object " .. tostring(oid)); return "none" end
	print("INFO itemStats oid=" .. tostring(oid) .. " path=" .. SceneObject(pObj):getTemplateObjectPath() .. " " .. getItemStats(pObj))
	return "ok"
end
-- kitRoll:<char>:<level>:<humanoid 0/1>[:<socialGroup>[:force]] → the drop roll into the character's bag; force skips the dice
function FbLabTests:kitRoll(charName, level, humanoid, social, force)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local pInv = kitInventory(pPlayer)
	local before = #kitItems(pInv, "fb_kits/")
	local what = FbLootKits:roll(pInv, tonumber(level) or 0, humanoid == "1", social or "", force == "force")
	print("INFO kitRoll level=" .. tostring(level) .. " humanoid=" .. tostring(humanoid) .. " social=" .. tostring(social or "") .. " " .. what .. " newKitItems=" .. (#kitItems(pInv, "fb_kits/") - before))
	return "ok"
end

function FbLabTests.checkKits()
	check("kits.loaded", FbLootKits ~= nil and FbLootKits.tiers ~= nil)
	if FbLootKits == nil then return end
	local function text(path) local f = io.open(path, "r"); if f == nil then return nil end; local t = f:read("a"); f:close(); return t end
	local tpl = text("scripts/custom_scripts/object/tangible/fb_kits/fb_kits.lua") or ""
	local items = text("scripts/custom_scripts/loot/items/fb_kits.lua") or ""
	local kits, parts = 0, 0
	for _ in tpl:gmatch("templateType = LOOTKIT") do kits = kits + 1 end
	for _ in tpl:gmatch("SharedTangibleObjectTemplate:new") do parts = parts + 1 end
	check("kits.templates", kits >= 70 and parts == 30, kits .. " kits, " .. parts .. " parts")
	local missing = {}
	for id in tpl:gmatch('collectibleLootReward = { "([%w_]+)" }') do if not items:find('addLootItemTemplate("' .. id .. '"', 1, true) then missing[#missing + 1] = id end end
	check("kits.rewards_are_loot_items", #missing == 0, #missing == 0 and "every kit's reward exists" or ("missing: " .. table.concat(missing, ", ")))
	for t = 1, 3 do
		for _, s in ipairs(FbLootKits.sets[t]) do check("kits.group.fb_kits_" .. s .. "_" .. t, items:find('addLootGroupTemplate("fb_kits_' .. s .. '_' .. t .. '"', 1, true) ~= nil) end
		check("kits.group.fb_kits_weapon_" .. t, items:find('addLootGroupTemplate("fb_kits_weapon_' .. t .. '"', 1, true) ~= nil)
		check("kits.group.fb_kit_parts_" .. t, items:find('addLootGroupTemplate("fb_kit_parts_armor_' .. t .. '"', 1, true) ~= nil and items:find('addLootGroupTemplate("fb_kit_parts_weapon_' .. t .. '"', 1, true) ~= nil)
	end
	check("kits.hook", (text("scripts/custom_scripts/screenplays/fb_attunement.lua") or ""):find("FbLootKits:onKill", 1, true) ~= nil)
	check("kits.binding", type(getItemStats) == "function", "getItemStats (DirectorManager)")
	local stf = text("../../tre-src/string/en/fb_kits.stf.txt") or ""
	local nameless = {}
	for key in tpl:gmatch('objectName = "@fb_kits:([%w_]+)"') do if not stf:find("\n" .. key .. " = ", 1, true) then nameless[#nameless + 1] = key end end
	check("kits.strings", #nameless == 0, #nameless == 0 and "every kit and part is named" or ("unnamed: " .. table.concat(nameless, ", "):sub(1, 200)))
	check("kits.ladder", FbLootKits:tierFor(10) ~= nil and FbLootKits:tierFor(10).tier == 1 and FbLootKits:tierFor(40).tier == 2 and FbLootKits:tierFor(80).tier == 3 and FbLootKits:tierFor(2) == nil)
end

-- ---------------------------------------------------------------- Phase 4a.0: crystal formations

-- crystals → every formation: cave, oid, ready/bare, seconds to regrow; and where each stands (world and cell-local)
function FbLabTests:crystals()
	print("INFO crystals " .. FbCrystals:status())
	for _, pNode in ipairs(FbCrystals:nodes()) do
		local so = SceneObject(pNode)
		print(string.format("INFO crystalNode oid=%s zone=%s x=%.1f y=%.1f z=%.1f cell=%s lx=%.2f ly=%.2f lz=%.2f", tostring(so:getObjectID()), so:getZoneName(), so:getWorldPositionX(), so:getWorldPositionY(), so:getWorldPositionZ(), tostring(so:getParentID()), so:getPositionX(), so:getPositionY(), so:getPositionZ()))
	end
	return "ok"
end
-- crystalHarvest:<char>:<nodeOid>[:power|<colour>] → work the formation as the radial would (a forced roll for the lab)
function FbLabTests:crystalHarvest(charName, nodeOid, forced)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local pNode = getSceneObject(tonumber(nodeOid) or 0)
	if pNode == nil then print("ERROR no such formation"); return "none" end
	print("INFO crystalHarvest ok=" .. tostring(FbCrystals:harvest(pPlayer, pNode, forced)) .. " " .. FbCrystals:status())
	return "ok"
end
-- crystalReset:<nodeOid> → the formation regrows now
function FbLabTests:crystalReset(nodeOid)
	local pNode = getSceneObject(tonumber(nodeOid) or 0)
	if pNode == nil then print("ERROR no such formation"); return "none" end
	FbCrystals:reset(pNode)
	print("INFO crystalReset " .. FbCrystals:status())
	return "ok"
end

function FbLabTests.checkCrystals()
	check("crystals.loaded", FbCrystals ~= nil and FbCrystals.caves ~= nil)
	if FbCrystals == nil then return end
	check("crystals.four_caves", #FbCrystals.caves == 4)
	local f = io.open("scripts/custom_scripts/object/tangible/fb_crystal_node/fb_crystal_node.lua", "r")
	check("crystals.node_template_file", f ~= nil); if f ~= nil then f:close() end
	f = io.open("scripts/custom_scripts/loot/items/fb_crystals.lua", "r")
	if f ~= nil then
		local text = f:read("a"); f:close()
		local missing = {}
		for n = 0, 11 do if not text:find("addLootItemTemplate(\"fb_crystal_c" .. n .. "\"", 1, true) then missing[#missing + 1] = tostring(n) end end
		check("crystals.loot_items", #missing == 0, #missing == 0 and "twelve colours" or ("missing colours: " .. table.concat(missing, ", ")))
	else
		check("crystals.loot_items", false, "custom_scripts/loot/items/fb_crystals.lua missing")
	end
	local grown = 0
	for _, cave in ipairs(FbCrystals.caves) do
		if isZoneEnabled(cave.zone) then
			local pB = getSceneObject(cave.buildingOid)
			check("crystals." .. cave.key .. ".cave", pB ~= nil, cave.label .. " " .. cave.buildingOid)
			if pB ~= nil then for _, n in ipairs(cave.nodes) do check("crystals." .. cave.key .. ".room." .. n.room, BuildingObject(pB):getNamedCell(n.room) ~= nil) end end
			grown = grown + #cave.nodes
		end
	end
	check("crystals.grown", #FbCrystals:nodes() == grown, #FbCrystals:nodes() .. " of " .. grown .. " formations stand")
	f = io.open("../../tre-src/string/en/fb_force.stf.txt", "r")
	if f ~= nil then
		local text = f:read("a"); f:close()
		local missing = {}
		for _, k in ipairs({ "radial", "taken", "power", "bare", "bag_full" }) do if not text:find("\ncrystal_" .. k .. " = ", 1, true) then missing[#missing + 1] = k end end
		check("crystals.strings", #missing == 0, #missing == 0 and "every line" or ("missing: " .. table.concat(missing, ", ")))
	end
end

-- ---------------------------------------------------------------- Phase 4c: the bounty

local function bountyLine(charName, pPlayer) print("INFO bounty char=" .. charName .. " " .. FbBounty:status(pPlayer)) end
function FbLabTests:bounty(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbBounty:updateAmount(pPlayer)
	bountyLine(charName, pPlayer)
	print("INFO bounty fixerScreen=" .. FbBounty:fixerScreen(pPlayer) .. " fixer=" .. tostring(FbBounty:fixerNpc() ~= nil))
	return "ok"
end
-- bountySet:<char>:<visibility> → the stock visibility set to that value (what saber and Force use raise)
function FbLabTests:bountySet(charName, vis)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost ~= nil then PlayerObject(pGhost):setVisibility(tonumber(vis) or 0) end
	FbBounty:updateAmount(pPlayer)
	bountyLine(charName, pPlayer)
	return "ok"
end
-- bountyTick:<char> → the trigger once, now (a hunt if one is due)
function FbLabTests:bountyTick(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local ok, why = FbBounty:due(pPlayer)
	print("INFO bountyTick hunt=" .. tostring(FbBounty:maybe(pPlayer)) .. " was=" .. tostring(ok) .. "(" .. tostring(why) .. ") " .. FbBounty:status(pPlayer))
	return "ok"
end
-- bountyPay:<char> → pay the fixer without the conversation
function FbLabTests:bountyPay(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	print("INFO bountyPay paid=" .. tostring(FbBounty:pay(pPlayer)))
	bountyLine(charName, pPlayer)
	return "ok"
end
-- bountyClear:<char> → the price, the pause, the cooldown and the hunters gone; visibility to 0
function FbLabTests:bountyClear(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbBounty:reset(pPlayer)
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost ~= nil then PlayerObject(pGhost):setVisibility(0) end
	bountyLine(charName, pPlayer)
	return "ok"
end

function FbLabTests.checkBounty()
	check("bounty.loaded", FbBounty ~= nil and FbBounty.tiers ~= nil)
	if FbBounty == nil then return end
	for _, t in ipairs(FbBounty.tiers) do
		local mf = io.open("scripts/mobile/quest/tatooine/" .. t.template .. ".lua", "r")
		check("bounty.tier." .. t.template, mf ~= nil); if mf ~= nil then mf:close() end
	end
	for side, t in pairs(FbBounty.forceHunters) do
		local mf = io.open("scripts/mobile/quest/tatooine/" .. t .. ".lua", "r")
		check("bounty.forcehunter." .. side, mf ~= nil, t); if mf ~= nil then mf:close() end
	end
	if isZoneEnabled(FbBounty.fixer.zone) then check("bounty.fixer_stands", FbBounty:fixerNpc() ~= nil, FbBounty.fixer.room .. " of " .. FbBounty.fixer.buildingOid) end
	local f = io.open("../../tre-src/string/en/fb_force.stf.txt", "r")
	if f ~= nil then
		local text = f:read("a"); f:close()
		local missing = {}
		local function need(k) if not text:find("\n" .. k .. " = ", 1, true) then missing[#missing + 1] = k end end
		for _, k in ipairs({ "placed", "hunted", "squad_down", "paid", "short", "status_active", "status_paid" }) do need("bounty_" .. k) end
		for _, k in ipairs({ "nothing", "paid", "offer", "price", "pay", "refuse" }) do need("fixer_" .. k) end
		check("bounty.strings", #missing == 0, #missing == 0 and "every line" or ("missing: " .. table.concat(missing, ", ")))
	end
end

function FbLabTests.checkTrials()
	check("trials.loaded", FbTrials ~= nil and FbTrialPrisoner ~= nil and FbTrialSpirit ~= nil and FbTrialDuel ~= nil)
	if FbTrials == nil then return end
	check("trials.eight", #FbTrials.list == 8)
	local f = io.open("../../tre-src/string/en/fb_force.stf.txt", "r")
	if f ~= nil then
		local text = f:read("a"); f:close()
		local missing = {}
		for _, t in ipairs(FbTrials.list) do
			for _, k in ipairs({ "word", "done" }) do
				if not text:find(string.format("\ntrial_%s_%s = ", t.id, k), 1, true) then missing[#missing + 1] = t.id .. "_" .. k end
			end
		end
		check("trials.strings", #missing == 0, #missing == 0 and "word + done for all eight" or ("missing: " .. table.concat(missing, ", ")))
	end
end

-- attunementSit:<char>[:stand] → seat (or stand) the character server-side, the way /sit would
function FbLabTests:attunementSit(charName, stand)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	CreatureObject(pPlayer):setPosture(stand == "stand" and 0 or 8)
	if stand == "stand" and CreatureObject(pPlayer):hasState(0x80000) then CreatureObject(pPlayer):clearState(0x80000) end   -- SITTINGONCHAIR outlives the posture
	print("INFO attunementSit posture=" .. CreatureObject(pPlayer):getPosture() .. " onChair=" .. tostring(CreatureObject(pPlayer):hasState(0x80000)))
	return tostring(CreatureObject(pPlayer):getPosture())
end

-- attunementStatus:<char> → what /checkForceStatus would say (the tier string id)
function FbLabTests:attunementStatus(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	FbAttunement:showStatus(pPlayer)
	local st = FbAttunement:status(pPlayer)
	print("INFO attunementStatus tier=@fb_force:tier_" .. st.tier)
	return tostring(st.tier)
end

-- Lab check: every shrine region the attunement watches resolves on an enabled zone, the wiring is loaded
function FbLabTests.checkAttunement()
	check("attunement.loaded", FbAttunement ~= nil and FbForceGhostVisit ~= nil and FbOldManVisit ~= nil)
	if FbAttunement == nil then return end
	local missing = {}
	for _, s in ipairs(FbAttunement.shrines) do
		if isZoneEnabled(s[2]) and getRegion(s[2], s[1]) == nil then missing[#missing + 1] = s[1] end
	end
	check("attunement.shrine_regions_resolve", #missing == 0, #missing == 0 and (#FbAttunement.shrines .. " shrines") or ("missing: " .. table.concat(missing, ", ")))
	check("attunement.caps_sum_to_170", (function() local t = 0; for _, c in pairs(FbAttunement.caps) do t = t + c end; return t end)() == 170)
	local bad = {}
	for _, q in ipairs(FbAttunement.questBadges) do for _, n in ipairs(q[3]) do if _G[n:upper()] == nil then bad[#bad + 1] = n end end end
	for _, b in ipairs(FbAttunement.badgeSites) do if _G[b[1]:upper()] == nil then bad[#bad + 1] = b[1] end end
	check("attunement.badge_names_exist", #bad == 0, #bad == 0 and "all badge globals present" or ("unknown badges: " .. table.concat(bad, ", ")))
	check("attunement.status_command_wrapped", VillageJediManager == nil or VillageJediManager.checkForceStatusCommand ~= nil)
	-- 4a.2: every shrine has a lore line in the string source (the server reads the packed table; the source is the truth)
	local f = io.open("../../tre-src/string/en/fb_force.stf.txt", "r")
	if f == nil then
		print("WARN attunement.lore_strings — tre-src not reachable from " .. (os.getenv("PWD") or "?"))
	else
		local text = f:read("a"); f:close()
		local missing = {}
		for _, s in ipairs(FbAttunement.shrines) do
			local planet, n = s[1]:match("^(%a+%d*)_force_shrine_(%d+)$")
			n = math.min(tonumber(n), 5)
			if not text:find(string.format("\nlore_%s_%d = ", planet, n), 1, true) then missing[#missing + 1] = s[1] end
		end
		check("attunement.lore_strings", #missing == 0, #missing == 0 and "a fragment for every shrine" or ("no lore for: " .. table.concat(missing, ", ")))
	end
	check("attunement.4a2_loaded", FbOldManReturn ~= nil and FbShadowAmbush ~= nil and FbAttunement.trialsUnlocked ~= nil)
end

