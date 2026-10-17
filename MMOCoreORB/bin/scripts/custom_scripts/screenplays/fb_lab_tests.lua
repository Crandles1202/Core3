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
			convoFile = FbLabTests.convoDir .. "/" .. t .. "_conv.lua",
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

function FbLabTests.checkNpc(npc)
	local p = npc.template .. "."

	check(p .. "mobile_template_registered", creatureTemplateExists(npc.template))
	check(p .. "included_in_serverobjects", fileContains("scripts/mobile/quest/serverobjects.lua", npc.mobileFile:gsub("^scripts/mobile/", "")))
	check(p .. "included_in_conversations", fileContains("scripts/mobile/conversations.lua", npc.convoFile:gsub("^scripts/mobile/", "")))

	-- mobile template file: lives in CreatureTemplateManager's Lua state, so run it here with a
	-- stand-in Creature class; unknown globals (MOB_NPC, NONE, INVULNERABLE, ...) read as 0.
	-- It tells us which conversation template the NPC expects.
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
	if not check(p .. "mobile_file_loads", mchunk ~= nil, merr) then return end
	local mob = mobEnv[npc.template]
	local convoName = type(mob) == "table" and mob.conversationTemplate or nil
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

	-- live spawns recorded by the spawnMobile wrapper
	local spawns = FbLabTests.spawns[npc.template] or {}
	if #spawns == 0 then
		check(p .. "spawned", false, "no spawnMobile calls recorded for this template (no screenplay spawns it, or fb_lab_tests.lua loaded after start())")
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
	for _, name in ipairs({ "health", "action", "mind" }) do
		local i = FbLabTests.pools[name]
		parts[#parts + 1] = string.format("%s=%d/%d/%d", name,
			CreatureObject(pPlayer):getHAM(i), CreatureObject(pPlayer):getMaxHAM(i), CreatureObject(pPlayer):getBaseHAM(i))
	end
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

-- inventory:<char> → one line per item
function FbLabTests:inventory(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local pInv = SceneObject(pPlayer):getSlottedObject("inventory")
	local n = SceneObject(pInv):getContainerObjectsSize()
	for i = 0, n - 1 do
		local pItem = SceneObject(pInv):getContainerObject(i)
		if pItem ~= nil then
			print("INFO item oid=" .. SceneObject(pItem):getObjectID() .. " path=" .. SceneObject(pItem):getTemplateObjectPath())
		end
	end
	print("INFO inventory char=" .. charName .. " count=" .. n)
	return tostring(n)
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
		if pObj ~= nil then
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
	print("INFO skill char=" .. charName .. " awarded=" .. skillName .. " has=" .. tostring(CreatureObject(pPlayer):hasSkill(skillName)))
	return tostring(CreatureObject(pPlayer):hasSkill(skillName))
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
	local z = getTerrainHeight(pPlayer, x, y)
	SceneObject(pPlayer):switchZone(planet, x, z, y, 0)
	print(string.format("INFO travel char=%s planet=%s x=%.1f z=%.1f y=%.1f", charName, planet, x, z, y))
	return "ok"
end

-- where:<char> → current position
function FbLabTests:where(charName)
	local pPlayer = loadedPlayer(charName)
	if pPlayer == nil then return "offline" end
	local line = string.format("INFO where char=%s oid=%d zone=%s x=%.1f z=%.1f y=%.1f cell=%d posture=%d combat=%s incap=%s dead=%s", charName,
		SceneObject(pPlayer):getObjectID(), SceneObject(pPlayer):getZoneName(),
		SceneObject(pPlayer):getWorldPositionX(), SceneObject(pPlayer):getWorldPositionZ(), SceneObject(pPlayer):getWorldPositionY(),
		SceneObject(pPlayer):getParentID(), CreatureObject(pPlayer):getPosture(),
		tostring(CreatureObject(pPlayer):isInCombat()), tostring(CreatureObject(pPlayer):isIncapacitated()), tostring(CreatureObject(pPlayer):isDead()))
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
