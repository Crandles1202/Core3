-- fb_attunement.lua — Phase 4a.1: Force attunement, the Force ghosts and the Old Man.
--
-- A hidden 0–100 score replaces the Village "glowing" unlock (design: docs/SWG-Server-Roadmap.md, Phase 4
-- decisions, Chuck 2026-10-18). Five capped sources, none of which unlocks alone:
--   places   (cap 50)  first visit to a stock force_shrine region 3, meditating there 6, a big Force site 8
--   learning (cap 30)  each mastered profession (a "master" badge) 10
--   deeds    (cap 30)  win a fight after being incapacitated in it 5 (once a day), kill a Dark Jedi /
--                      Nightsister elder / krayt dragon 10
--   quests   (cap 40)  Hero of Tatooine 15, a badge theme park (Jabba, Nym, Imperial, Rebel) 10, Warren /
--                      Corvette 5  (Death Watch bunker, Geonosian lab, krayt skull, Nightsister / Marauder
--                      parks have no badge: FbAttunement:questDone(pPlayer, key) is the hook for 4a.3)
--   items    (cap 20)  a colour crystal 10, a found holocron 10 (scanned in the inventory)
-- At 25 / 50 / 75 a robed spirit visits (after a fight or at a shrine, outdoors, outside cities — never at
-- login) and names the nearest unvisited place; at 100 the Old Man comes and gives the shrine task (4a.2).
-- /checkForceStatus shows one of five vague tiers, never a number.
--
-- Persistence: screenplay data per player (writeScreenPlayData), one "key=points;…" string per source, plus
-- flags (ghost thresholds, called, task). Cross-state scratch (meditation polling, active visit) in quest status.
--
-- 4a.2: every shrine meditation also teaches a lore fragment (@fb_force:lore_<planet>_<n>, counted in flag
-- "lore"); at six worlds the Old Man returns (FbOldManReturn) and the trials are unlocked (task=trials); the
-- ambush he warned about (FbShadowAmbush, two Sith Shadow outlaws) comes 5–15 min after the first visit at the
-- next trigger outdoors — surviving it is the "survive a Force power" deed (3).
-- Public (also the lab oracles): FbAttunement:status(pPlayer) → table, :grant(pPlayer, source, key, pts, why),
-- :reset(pPlayer), :maybeVisit(pPlayer), :questDone(pPlayer, key), :accept(pPlayer), :onLogin(pPlayer).

local ObjectManager = require("managers.object.object_manager")
local SpawnMobiles = require("utils.spawn_mobiles")

FbAttunement = ScreenPlay:new {
	screenplayName = "FbAttunement",
	DATA = "FbAttunement",
	caps = { places = 50, learning = 30, deeds = 30, quests = 40, items = 20 },
	sources = { "places", "learning", "deeds", "quests", "items" },
	thresholds = { 25, 50, 75 },

	-- the stock force_shrine regions (managers/planet/<planet>_regions.lua): key, planet, x, y, radius
	shrines = {
		{ "tatooine_force_shrine_01", "tatooine", -6506, -3668, 199 }, { "tatooine_force_shrine_02", "tatooine", 5264, 113, 199 },
		{ "tatooine_force_shrine_03", "tatooine", -3623, 5281, 199 }, { "tatooine_force_shrine_04", "tatooine", 5633, 6015, 199 },
		{ "tatooine_force_shrine_05", "tatooine", 5958, -5684, 199 },
		{ "naboo_force_shrine_01", "naboo", 7182, -235, 199 }, { "naboo_force_shrine_02", "naboo", -6859, -1938, 199 },
		{ "naboo_force_shrine_03", "naboo", 2378, -474, 199 }, { "naboo_force_shrine_04", "naboo", -2583, -6185, 199 },
		{ "corellia_force_shrine_01", "corellia", -6907, 4527, 199 }, { "corellia_force_shrine_02", "corellia", -7392, -3938, 199 },
		{ "corellia_force_shrine_03", "corellia", 6093, -5578, 199 }, { "corellia_force_shrine_04", "corellia", 6301, 6688, 199 },
		{ "corellia_force_shrine_05", "corellia", -2384, 6393, 199 },
		{ "talus_force_shrine_01", "talus", -5786, 4478, 199 }, { "talus_force_shrine_02", "talus", -5494, -3240, 199 },
		{ "talus_force_shrine_03", "talus", 5760, -5208, 199 }, { "talus_force_shrine_04", "talus", 318, 5843, 199 },
		{ "rori_force_shrine_01", "rori", 307, -979, 200 }, { "rori_force_shrine_02", "rori", -6376, 6404, 200 },
		{ "rori_force_shrine_03", "rori", 6854, -1222, 200 }, { "rori_force_shrine_04", "rori", -4497, -7535, 200 },
		{ "rori_force_shrine_05", "rori", -926, 6040, 200 },
		{ "dantooine_force_shrine_01", "dantooine", -6173, 4120, 199 }, { "dantooine_force_shrine_02", "dantooine", 2164, 7548, 199 },
		{ "dantooine_force_shrine_03", "dantooine", 2641, -1537, 199 }, { "dantooine_force_shrine_04", "dantooine", -1814, -6202, 199 },
		{ "dantooine_force_shrine_05", "dantooine", -6999, -5270, 199 },
		{ "lok_force_shrine_01", "lok", -3641, -6031, 199 }, { "lok_force_shrine_02", "lok", -5807, 1977, 199 },
		{ "lok_force_shrine_03", "lok", -2124, 5959, 199 }, { "lok_force_shrine_04", "lok", 5455, 3806, 199 },
		{ "lok_force_shrine_05", "lok", 4979, -5674, 199 },
		{ "yavin4_force_shrine_01", "yavin4", -4585, -3761, 199 }, { "yavin4_force_shrine_02", "yavin4", 2390, -4935, 199 },
		{ "yavin4_force_shrine_03", "yavin4", 6455, 6420, 199 }, { "yavin4_force_shrine_04", "yavin4", -3362, 6915, 199 },
		{ "endor_force_shrine_01", "endor", -3871, -4468, 199 }, { "endor_force_shrine_02", "endor", 5117, 1924, 199 },
		{ "endor_force_shrine_03", "endor", 670, 5548, 199 }, { "endor_force_shrine_04", "endor", -5627, 4814, 199 },
		{ "endor_force_shrine_05", "endor", -5056, -1703, 199 },
		{ "dathomir_force_shrine_01", "dathomir", -4961, -3493, 30 }, { "dathomir_force_shrine_02", "dathomir", -4148, 5926, 30 },
		{ "dathomir_force_shrine_03", "dathomir", 3087, 4887, 30 }, { "dathomir_force_shrine_04", "dathomir", 5571, -1513, 30 },
		{ "dathomir_force_shrine_05", "dathomir", 1654, -5765, 30 },
	},
	-- big Force sites that have no badge: our own areas (key, planet, x, y, radius, label)
	sites = {
		{ "dantooine_crystal_cave", "dantooine", -6228, 7380, 125, "the crystal cave" },
		{ "yavin4_light_enclave", "yavin4", -5514, 4912, 150, "the enclave in the north-west" },
		{ "yavin4_dark_enclave", "yavin4", 5070, 310, 150, "the enclave in the east" },
		{ "dathomir_nightsister_stronghold", "dathomir", -4052, -161, 300, "the stronghold of the witches" },
	},
	-- big Force sites the stock exploration badges already mark (badge global name → place key)
	badgeSites = {
		{ "exp_tat_bens_hut", "bens_hut" }, { "exp_tat_krayt_graveyard", "krayt_graveyard" },
		{ "exp_yav_temple_exar_kun", "exar_kun_temple" }, { "exp_dan_jedi_temple", "dantooine_jedi_temple" },
	},
	-- quests by badge: key, points, badge global names (any of them)
	questBadges = {
		{ "hero_of_tatooine", 15, { "poi_heromark" } },
		{ "jabba", 10, { "bdg_thm_park_jabba_badge" } }, { "nym", 10, { "bdg_thm_park_nym_badge" } },
		{ "imperial", 10, { "bdg_thm_park_imperial_badge" } }, { "rebel", 10, { "bdg_thm_park_rebel_badge" } },
		{ "warren", 5, { "warren_compassion", "warren_hero" } },
		{ "corvette", 5, { "bdg_corvette_imp_destroy", "bdg_corvette_imp_rescue", "bdg_corvette_imp_assassin", "bdg_corvette_neutral_destroy", "bdg_corvette_neutral_rescue", "bdg_corvette_neutral_assassin", "bdg_corvette_reb_destroy", "bdg_corvette_reb_rescue", "bdg_corvette_reb_assassin" } },
	},
	-- deeds: a kill of a template whose name contains one of these pays 10 (one credit per kind)
	killKinds = { { "dark_jedi", "dark_jedi" }, { "nightsister_elder", "nightsister_elder" }, { "krayt_dragon", "krayt_dragon" } },
	-- items: template fragment → key, points
	itemKinds = { { "lightsaber_module_force_crystal", "colour_crystal", 10 }, { "holocron", "holocron", 10 } },
}

local SITTING_POSTURE = 8   -- CreaturePosture::SITTING (the Lua global POSTURESITTING is shadowed by the observer event of the same name)

local planetNames = { tatooine = "Tatooine", naboo = "Naboo", corellia = "Corellia", talus = "Talus", rori = "Rori", dantooine = "Dantooine", lok = "Lok", yavin4 = "Yavin 4", endor = "Endor", dathomir = "Dathomir" }

-- ---------------------------------------------------------------- storage

function FbAttunement:bucket(pPlayer, source)
	local t = {}
	local raw = readScreenPlayData(pPlayer, self.DATA, source)
	if raw ~= nil and raw ~= "" then
		for k, v in raw:gmatch("([^=;]+)=([%-%d]+)") do t[k] = tonumber(v) end
	end
	return t
end

function FbAttunement:saveBucket(pPlayer, source, t)
	local parts = {}
	for k, v in pairs(t) do parts[#parts + 1] = k .. "=" .. tostring(v) end
	table.sort(parts)
	writeScreenPlayData(pPlayer, self.DATA, source, table.concat(parts, ";"))
end

function FbAttunement:flag(pPlayer, name) local v = readScreenPlayData(pPlayer, self.DATA, "flag:" .. name); return v ~= nil and v ~= "" and v or nil end
function FbAttunement:setFlag(pPlayer, name, value) writeScreenPlayData(pPlayer, self.DATA, "flag:" .. name, tostring(value)) end

function FbAttunement:sourceTotal(pPlayer, source)
	local sum = 0
	for _, v in pairs(self:bucket(pPlayer, source)) do sum = sum + v end
	return math.min(sum, self.caps[source]), sum
end

function FbAttunement:total(pPlayer)
	local t = 0
	for _, s in ipairs(self.sources) do t = t + self:sourceTotal(pPlayer, s) end
	return math.min(100, t)
end

-- the one way points come in. Idempotent per (source, key). Returns true when something was added.
function FbAttunement:grant(pPlayer, source, key, pts, why)
	if pPlayer == nil or self.caps[source] == nil or key == nil or key == "" then return false end
	local b = self:bucket(pPlayer, source)
	if b[key] ~= nil then return false end
	b[key] = tonumber(pts) or 0
	self:saveBucket(pPlayer, source, b)
	if why ~= nil and why ~= "" then CreatureObject(pPlayer):sendSystemMessage("@fb_force:" .. why) end
	printf("FbAttunement: %s +%s %s/%s (total %d)\n", CreatureObject(pPlayer):getFirstName(), tostring(pts), source, key, self:total(pPlayer))
	return true
end

-- A visit task that is marked started but has nothing standing (a failed spawn, an earlier version of this
-- file, a restart mid-visit) would refuse every later start: finish it.
local function clearStaleVisit(task, pPlayer)
	if not task:hasTaskStarted(pPlayer) then return end
	local spawned = SpawnMobiles.getSpawnedMobiles(pPlayer, task.taskName)
	if spawned == nil or spawned[1] == nil then task:finish(pPlayer) end
end

function FbAttunement:reset(pPlayer)
	for _, s in ipairs(self.sources) do deleteScreenPlayData(pPlayer, self.DATA, s) end
	for _, f in ipairs({ "ghost25", "ghost50", "ghost75", "oldman", "called", "task", "incapAt", "incapDay", "medWorlds", "lore", "return", "trials", "ambushDue", "ambushDone", "alignment", "padawan", "master" }) do deleteScreenPlayData(pPlayer, self.DATA, "flag:" .. f) end
	if FbTrials ~= nil then FbTrials:reset(pPlayer) end
	if FbVisions ~= nil then FbVisions:reset(pPlayer) end
	if FbMasters ~= nil then FbMasters.reset(pPlayer) end
	deleteScreenPlayData(pPlayer, self.DATA, "ghostTier")
	removeQuestStatus("FbAttunement.visit." .. SceneObject(pPlayer):getObjectID())
	removeQuestStatus("FbAttunement.poll." .. SceneObject(pPlayer):getObjectID())
	for _, V in ipairs({ FbForceGhostVisit, FbOldManVisit, FbOldManReturn, FbShadowAmbush }) do
		if V ~= nil then
			if SpawnMobiles.getSpawnedMobiles(pPlayer, V.taskName) ~= nil then V:doDespawn(pPlayer) else clearStaleVisit(V, pPlayer) end
		end
	end
end

function FbAttunement:tier(total)
	if total >= 100 then return 4 elseif total >= 75 then return 3 elseif total >= 50 then return 2 elseif total >= 25 then return 1 end
	return 0
end

function FbAttunement:status(pPlayer)
	local st = { total = self:total(pPlayer), per = {}, raw = {}, flags = {} }
	st.tier = self:tier(st.total)
	for _, s in ipairs(self.sources) do st.per[s], st.raw[s] = self:sourceTotal(pPlayer, s) end
	for _, f in ipairs({ "ghost25", "ghost50", "ghost75", "called", "task", "medWorlds", "lore", "return", "trials", "ambushDue", "ambushDone", "alignment", "padawan", "master" }) do st.flags[f] = self:flag(pPlayer, f) end
	return st
end

-- ---------------------------------------------------------------- places

function FbAttunement:placeAt(planet, x, y)
	for _, s in ipairs(self.shrines) do
		if s[2] == planet then
			local dx, dy = x - s[3], y - s[4]
			if dx * dx + dy * dy <= (s[5] + 5) * (s[5] + 5) then return s[1], "shrine", s end
		end
	end
	for _, s in ipairs(self.sites) do
		if s[2] == planet then
			local dx, dy = x - s[3], y - s[4]
			if dx * dx + dy * dy <= (s[5] + 5) * (s[5] + 5) then return s[1], "site", s end
		end
	end
	return nil
end

-- ENTEREDAREA on a shrine region or one of our site areas
function FbAttunement:onEnterArea(pArea, pCreature)
	if pCreature == nil or not SceneObject(pCreature):isPlayerCreature() then return 0 end
	local so = SceneObject(pCreature)
	local key, kind = self:placeAt(so:getZoneName(), so:getWorldPositionX(), so:getWorldPositionY())
	if key == nil then return 0 end
	self:grant(pCreature, "places", "visit:" .. key, kind == "shrine" and 3 or 8, "stir_place")
	if kind == "shrine" then self:startMeditationWatch(pCreature, key) end
	if kind == "shrine" and FbTrials ~= nil then FbTrials:onShrine(pCreature, key) end
	self:maybeVisit(pCreature)
	return 0
end

-- while the player stands in a shrine, look every 5 s for the meditate state (the /meditate command);
-- the watch stops when they leave or after 10 minutes
function FbAttunement:startMeditationWatch(pPlayer, key)
	local oid = SceneObject(pPlayer):getObjectID()
	if getQuestStatus("FbAttunement.poll." .. oid) ~= nil and getQuestStatus("FbAttunement.poll." .. oid) ~= "" then return end
	setQuestStatus("FbAttunement.poll." .. oid, key .. "|0")
	createEvent(5000, "FbAttunement", "pollMeditation", pPlayer, "")
end

function FbAttunement:pollMeditation(pPlayer)
	if pPlayer == nil then return end
	local oid = SceneObject(pPlayer):getObjectID()
	local raw = getQuestStatus("FbAttunement.poll." .. oid)
	if raw == nil or raw == "" then return end
	local key, n = raw:match("^(.-)|(%d+)$")
	n = tonumber(n) or 0
	local so = SceneObject(pPlayer)
	local here = self:placeAt(so:getZoneName(), so:getWorldPositionX(), so:getWorldPositionY())
	if here ~= key or n >= 120 then removeQuestStatus("FbAttunement.poll." .. oid); return end
	-- /meditate is a Teras Kasi ability, so sitting still in the shrine counts too: two polls (10 s) seated
	local seated = CreatureObject(pPlayer):getPosture() == SITTING_POSTURE
	local satBefore = getQuestStatus("FbAttunement.sat." .. oid) == key
	if CreatureObject(pPlayer):isMeditating() or (seated and satBefore) then
		removeQuestStatus("FbAttunement.poll." .. oid)
		removeQuestStatus("FbAttunement.sat." .. oid)
		if self:grant(pPlayer, "places", "meditate:" .. key, 6, "stir_meditate") then
			self:teachLore(pPlayer, key)
			self:noteMeditationWorld(pPlayer, so:getZoneName())
		end
		self:maybeVisit(pPlayer)
		return
	end
	if seated then setQuestStatus("FbAttunement.sat." .. oid, key) else removeQuestStatus("FbAttunement.sat." .. oid) end
	setQuestStatus("FbAttunement.poll." .. oid, key .. "|" .. (n + 1))
	createEvent(5000, "FbAttunement", "pollMeditation", pPlayer, "")
end

-- one fragment of the old lore per shrine (key <planet>_force_shrine_NN → @fb_force:lore_<planet>_<N>)
function FbAttunement:teachLore(pPlayer, key)
	local planet, n = key:match("^(%a+%d*)_force_shrine_(%d+)$")
	if planet == nil then return end
	n = tonumber(n)
	if n > 5 then n = 5 end
	local known = self:flag(pPlayer, "lore") or ""
	if known:find(key, 1, true) then return end
	self:setFlag(pPlayer, "lore", known == "" and key or (known .. "," .. key))
	CreatureObject(pPlayer):sendSystemMessage("@fb_force:lore_learned")
	CreatureObject(pPlayer):sendSystemMessage(string.format("@fb_force:lore_%s_%d", planet, n))
end

function FbAttunement:loreCount(pPlayer)
	local known = self:flag(pPlayer, "lore") or ""
	if known == "" then return 0 end
	return select(2, known:gsub(",", ",")) + 1
end

function FbAttunement:worldCount(pPlayer)
	local worlds = self:flag(pPlayer, "medWorlds") or ""
	if worlds == "" then return 0 end
	return select(2, worlds:gsub(",", ",")) + 1
end

-- worlds meditated on (the Old Man's task, 4a.2 reads it): "tatooine,naboo,…"
function FbAttunement:noteMeditationWorld(pPlayer, planet)
	local worlds = self:flag(pPlayer, "medWorlds") or ""
	if worlds:find(planet, 1, true) then return end
	worlds = worlds == "" and planet or (worlds .. "," .. planet)
	self:setFlag(pPlayer, "medWorlds", worlds)
	if self:flag(pPlayer, "called") ~= nil then
		local n = select(2, worlds:gsub(",", ",")) + 1
		local msg = LuaStringIdChatParameter("@fb_force:called_progress"); msg:setDI(n)
		CreatureObject(pPlayer):sendSystemMessage(msg:_getObject())
	end
end

-- nearest place the player has not visited: "<phrase>" for the ghost's hint, or nil
function FbAttunement:unvisitedHint(pPlayer)
	local so = SceneObject(pPlayer)
	local planet, px, py = so:getZoneName(), so:getWorldPositionX(), so:getWorldPositionY()
	local visited = self:bucket(pPlayer, "places")
	local best, bestD
	local elsewhere
	for _, list in ipairs({ self.shrines, self.sites }) do
		for _, s in ipairs(list) do
			if visited["visit:" .. s[1]] == nil then
				if s[2] == planet then
					local d = math.sqrt((px - s[3]) ^ 2 + (py - s[4]) ^ 2)
					if bestD == nil or d < bestD then best, bestD = s, d end
				elseif elsewhere == nil then
					elsewhere = s
				end
			end
		end
	end
	if best ~= nil then
		local dx, dy = best[3] - px, best[4] - py
		local dirs = { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" }
		local a = (math.deg(math.atan(dx, dy)) + 360) % 360
		local dir = dirs[math.floor((a + 22.5) / 45) % 8 + 1]
		local km = bestD / 1000
		local dist = km < 0.3 and "close by" or km < 1 and "a short walk" or string.format("about %d kilometres", math.floor(km + 0.5))
		return string.format("%s to the %s", dist, dir), true
	elseif elsewhere ~= nil then
		return planetNames[elsewhere[2]] or elsewhere[2], false
	end
	return nil
end

-- ---------------------------------------------------------------- learning, quests, items (scans)

function FbAttunement:scanBadges(pPlayer)
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost == nil then return end
	local ghost = PlayerObject(pGhost)
	for _, idx in ipairs(getBadgeListByType("master") or {}) do
		if ghost:hasBadge(idx) then self:grant(pPlayer, "learning", "master:" .. idx, 10, nil) end
	end
	for _, q in ipairs(self.questBadges) do
		for _, name in ipairs(q[3]) do
			local idx = _G[name:upper()]   -- badge keys are Lua globals in upper case (DirectorManager)
			if idx ~= nil and ghost:hasBadge(idx) then self:grant(pPlayer, "quests", q[1], q[2], "stir_quest"); break end
		end
	end
	for _, b in ipairs(self.badgeSites) do
		local idx = _G[b[1]:upper()]
		if idx ~= nil and ghost:hasBadge(idx) then self:grant(pPlayer, "places", "visit:" .. b[2], 8, "stir_place") end
	end
end

function FbAttunement:scanItems(pPlayer)
	local pInventory = CreatureObject(pPlayer):getSlottedObject("inventory")
	if pInventory == nil then return end
	local n = SceneObject(pInventory):getContainerObjectsSize()
	for i = 0, n - 1 do
		local pItem = SceneObject(pInventory):getContainerObject(i)
		if pItem ~= nil then
			local path = SceneObject(pItem):getTemplateObjectPath()
			for _, k in ipairs(self.itemKinds) do
				if path:find(k[1], 1, true) then self:grant(pPlayer, "items", k[2], k[3], "stir_item") end
			end
		end
	end
end

-- hook for quests without a badge (4a.3 and the theme parks that leave no mark)
function FbAttunement:questDone(pPlayer, key, pts)
	return self:grant(pPlayer, "quests", key, pts or 10, "stir_quest")
end

-- ---------------------------------------------------------------- deeds (observers on the player)

function FbAttunement:onBadge(pPlayer, pPlayer2, badgeNumber)
	if pPlayer == nil then return 0 end
	self:scanBadges(pPlayer)
	self:maybeVisit(pPlayer)
	return 0
end

function FbAttunement:onIncap(pPlayer, pAttacker)
	if pPlayer == nil then return 0 end
	self:setFlag(pPlayer, "incapAt", os.time())
	return 0
end

function FbAttunement:onKill(pPlayer, pVictim)
	if pPlayer == nil then return 0 end
	if pVictim ~= nil then
		local path = SceneObject(pVictim):getTemplateObjectPath() .. " " .. tostring(SceneObject(pVictim):getObjectName())
		for _, k in ipairs(self.killKinds) do
			if path:find(k[1], 1, true) then self:grant(pPlayer, "deeds", "kill:" .. k[2], 10, "stir_deed") end
		end
	end
	local incapAt = tonumber(self:flag(pPlayer, "incapAt") or 0)
	if incapAt > 0 and os.time() - incapAt < 600 then
		local day = os.date("%Y%m%d")
		if self:flag(pPlayer, "incapDay") ~= day then
			self:setFlag(pPlayer, "incapDay", day)
			self:grant(pPlayer, "deeds", "incapwin:" .. day, 5, "stir_deed")
		end
		self:setFlag(pPlayer, "incapAt", 0)
	end
	self:scanItems(pPlayer)
	if FbTrials ~= nil then FbTrials:onKill(pPlayer, pVictim) end
	if FbMasters ~= nil then FbMasters.onKill(pPlayer, pVictim) end   -- 4b.1/4b.2: the Masters' kill tasks
	-- the fight may still be on: look again in 20 s
	createEvent(20000, "FbAttunement", "maybeVisitLater", pPlayer, "")
	return 0
end

function FbAttunement:maybeVisitLater(pPlayer) if pPlayer ~= nil then self:maybeVisit(pPlayer) end end

-- ---------------------------------------------------------------- the visits

-- Called on every trigger. Starts the next due visit when the player is in a place for one.
function FbAttunement:maybeVisit(pPlayer)
	if pPlayer == nil then return false end
	local oid = SceneObject(pPlayer):getObjectID()
	clearStaleVisit(FbForceGhostVisit, pPlayer)
	clearStaleVisit(FbOldManVisit, pPlayer)
	clearStaleVisit(FbOldManReturn, pPlayer)
	clearStaleVisit(FbShadowAmbush, pPlayer)
	local active = getQuestStatus("FbAttunement.visit." .. oid)
	if active ~= nil and active ~= "" then
		if os.time() - (tonumber(active) or 0) < 180 then return false end   -- one visitor at a time
		removeQuestStatus("FbAttunement.visit." .. oid)
		-- a visit that never despawned (spawn failed, server hiccup) would block the next one forever
		if FbForceGhostVisit:hasTaskStarted(pPlayer) then FbForceGhostVisit:finish(pPlayer) end
		if FbOldManVisit:hasTaskStarted(pPlayer) then FbOldManVisit:finish(pPlayer) end
		if FbOldManReturn:hasTaskStarted(pPlayer) then FbOldManReturn:finish(pPlayer) end
		if FbShadowAmbush:hasTaskStarted(pPlayer) then FbShadowAmbush:finish(pPlayer) end
	end
	if CreatureObject(pPlayer):isInCombat() or CreatureObject(pPlayer):isDead() or CreatureObject(pPlayer):isIncapacitated() then return false end
	local total = self:total(pPlayer)
	-- 4a.2: the shrine task done → the Old Man returns (once)
	if self:flag(pPlayer, "called") ~= nil and self:flag(pPlayer, "task") == "shrines" and self:worldCount(pPlayer) >= 6 and self:flag(pPlayer, "return") == nil then
		if FbOldManReturn:isPlayerInPositionForEncounter(pPlayer) and FbOldManReturn:start(pPlayer) then
			setQuestStatus("FbAttunement.visit." .. oid, tostring(os.time()))
			self:setFlag(pPlayer, "return", os.time())
			return true
		end
		return false
	end
	-- 4a.2: the ambush the Old Man warned about, once it is due
	local due = tonumber(self:flag(pPlayer, "ambushDue") or 0)
	if due > 0 and os.time() >= due and self:flag(pPlayer, "ambushDone") == nil then
		if FbShadowAmbush:isPlayerInPositionForEncounter(pPlayer) and FbShadowAmbush:start(pPlayer) then
			setQuestStatus("FbAttunement.visit." .. oid, tostring(os.time()))
			return true
		end
	end
	-- 4a.4: a vision due at this point of the path comes before a trial acts (the mercy and duel visions come
	-- after the word, before the visitor)
	if FbVisions ~= nil and FbVisions:maybe(pPlayer) then return true end
	-- 4a.3: a trial in progress or due takes the trigger (after the hunters the Old Man warned about)
	if FbTrials ~= nil and FbTrials:active(pPlayer) then
		if FbTrials:tick(pPlayer) then return true end
	end
	if total >= 100 then
		if self:flag(pPlayer, "called") == nil and self:flag(pPlayer, "oldman") == nil then
			if FbOldManVisit:isPlayerInPositionForEncounter(pPlayer) and FbOldManVisit:start(pPlayer) then
				setQuestStatus("FbAttunement.visit." .. oid, tostring(os.time()))
				self:setFlag(pPlayer, "oldman", os.time())
				return true
			end
		end
	end
	for _, th in ipairs(self.thresholds) do
		if total >= th and self:flag(pPlayer, "ghost" .. th) == nil then
			if FbForceGhostVisit:isPlayerInPositionForEncounter(pPlayer) then
				writeScreenPlayData(pPlayer, self.DATA, "ghostTier", tostring(th))
				if FbForceGhostVisit:start(pPlayer) then
					setQuestStatus("FbAttunement.visit." .. oid, tostring(os.time()))
					self:setFlag(pPlayer, "ghost" .. th, os.time())
					return true
				end
			end
			return false   -- not here, not now: the next trigger tries again
		end
	end
	return false
end

-- the Old Man's offer accepted (conversation handler)
function FbAttunement:accept(pPlayer)
	self:setFlag(pPlayer, "called", os.time())
	self:setFlag(pPlayer, "task", "shrines")
	self:setFlag(pPlayer, "ambushDue", os.time() + 300 + getRandomNumber(600))   -- 5–15 min, at the next trigger outdoors
	CreatureObject(pPlayer):sendSystemMessage("@fb_force:called_task")
	-- a waypoint to the nearest shrine not yet meditated at
	local so = SceneObject(pPlayer)
	local med = self:bucket(pPlayer, "places")
	local best, bestD
	for _, s in ipairs(self.shrines) do
		if s[2] == so:getZoneName() and med["meditate:" .. s[1]] == nil then
			local d = (so:getWorldPositionX() - s[3]) ^ 2 + (so:getWorldPositionY() - s[4]) ^ 2
			if bestD == nil or d < bestD then best, bestD = s, d end
		end
	end
	if best ~= nil then
		local pGhost = CreatureObject(pPlayer):getPlayerObject()
		if pGhost ~= nil then PlayerObject(pGhost):addWaypoint(best[2], "A quiet place", "", best[3], getTerrainHeightAt(best[2], best[3], best[4]), best[4], 1, true, true, 0) end
	end
end

-- the Old Man's return accepted: the shrine task is complete, 4a.3 takes over from task=trials
function FbAttunement:trialsUnlocked(pPlayer)
	self:setFlag(pPlayer, "task", "trials")
	self:setFlag(pPlayer, "trials", os.time())
	CreatureObject(pPlayer):sendSystemMessage("@fb_force:trials_unlocked")
end

-- ---------------------------------------------------------------- /checkForceStatus

function FbAttunement:showStatus(pPlayer)
	if pPlayer == nil then return end
	local st = self:status(pPlayer)
	CreatureObject(pPlayer):sendSystemMessage("@fb_force:tier_" .. st.tier)
	if st.flags.called ~= nil and st.flags.task == "shrines" then
		local msg = LuaStringIdChatParameter("@fb_force:called_progress"); msg:setDI(self:worldCount(pPlayer))
		CreatureObject(pPlayer):sendSystemMessage(msg:_getObject())
	end
	if st.flags.task == "trials" and FbTrials ~= nil then
		local msg = LuaStringIdChatParameter("@fb_force:trials_progress"); msg:setDI(FbTrials:doneCount(pPlayer))
		CreatureObject(pPlayer):sendSystemMessage(msg:_getObject())
	end
	local lore = self:loreCount(pPlayer)
	if lore > 0 then
		local msg = LuaStringIdChatParameter("@fb_force:lore_count"); msg:setDI(lore)
		CreatureObject(pPlayer):sendSystemMessage(msg:_getObject())
	end
end

-- The Village manager owns the command (jediProgressionType stays VILLAGE so the Dathomir village keeps
-- working as optional content); its status report is ours now. Re-applied on every (re)load.
if VillageJediManager ~= nil then
	VillageJediManager.checkForceStatusCommand = function(self, pPlayer) FbAttunement:showStatus(pPlayer) end
end
if JediManager ~= nil and VillageJediManager == nil then
	JediManager.checkForceStatusCommand = function(self, pPlayer) FbAttunement:showStatus(pPlayer) end
end

-- ---------------------------------------------------------------- login and boot

function FbAttunement:onLogin(pPlayer)
	if pPlayer == nil then return end
	printf("FbAttunement: login hook for %s\n", CreatureObject(pPlayer):getFirstName())
	if FbVisions ~= nil then FbVisions:onLogin(pPlayer) end   -- 4a.4: a logout inside a vision ends it at home
	if FbMasters ~= nil then FbMasters.onLogin(pPlayer) end   -- 4b.1/4b.2: re-arm the sit polls
	dropObserver(KILLEDCREATURE, "FbAttunement", "onKill", pPlayer); createObserver(KILLEDCREATURE, "FbAttunement", "onKill", pPlayer)
	dropObserver(OBJECTDESTRUCTION, "FbAttunement", "onIncap", pPlayer); createObserver(OBJECTDESTRUCTION, "FbAttunement", "onIncap", pPlayer)
	dropObserver(BADGEAWARDED, "FbAttunement", "onBadge", pPlayer); createObserver(BADGEAWARDED, "FbAttunement", "onBadge", pPlayer)
	-- silent credit for what the character already has (no visit is triggered by a login)
	self:scanBadges(pPlayer)
	self:scanItems(pPlayer)
	-- the zone and position are not final inside the login trigger: look where they stand a few seconds later
	createEvent(6000, "FbAttunement", "loginSettled", pPlayer, "")
end

function FbAttunement:loginSettled(pPlayer)
	if pPlayer == nil then return end
	local so = SceneObject(pPlayer)
	if so:getZoneName() == "" then return end
	local key, kind = self:placeAt(so:getZoneName(), so:getWorldPositionX(), so:getWorldPositionY())
	printf("FbAttunement: %s settled at %s %.0f,%.0f place=%s\n", CreatureObject(pPlayer):getFirstName(), so:getZoneName(), so:getWorldPositionX(), so:getWorldPositionY(), tostring(key))
	if kind == "shrine" then self:startMeditationWatch(pPlayer, key) end
end

function FbAttunement:start()
	local regions, areas = 0, 0
	for _, s in ipairs(self.shrines) do
		if isZoneEnabled(s[2]) then
			local pRegion = getRegion(s[2], s[1])
			if pRegion ~= nil then
				createObserver(ENTEREDAREA, "FbAttunement", "onEnterArea", pRegion); regions = regions + 1
			else
				local pArea = spawnActiveArea(s[2], "object/active_area.iff", s[3], 0, s[4], s[5], 0)
				if pArea ~= nil then createObserver(ENTEREDAREA, "FbAttunement", "onEnterArea", pArea); areas = areas + 1 end
			end
		end
	end
	for _, s in ipairs(self.sites) do
		if isZoneEnabled(s[2]) then
			local pArea = spawnActiveArea(s[2], "object/active_area.iff", s[3], 0, s[4], s[5], 0)
			if pArea ~= nil then createObserver(ENTEREDAREA, "FbAttunement", "onEnterArea", pArea); areas = areas + 1 end
		end
	end
	printf("FbAttunement: watching %d shrine regions and %d areas\n", regions, areas)
end

registerScreenPlay("FbAttunement", true)

-- encounter spawns go through utils/spawn_mobiles, which the lab's spawn wrapper does not record: put the
-- visitor into the shared registry by hand so findNpc / placement / the Lab Remote can see it
local function recordVisitor(pPlayer, spawned, template, lifetime)
	if spawned == nil then return end
	for _, pNpc in ipairs(spawned) do
		if pNpc ~= nil then
			local so = SceneObject(pNpc)
			if FbLabTests ~= nil and FbLabTests.registryAdd ~= nil then
				FbLabTests.registryAdd({ oid = so:getObjectID(), zone = so:getZoneName(), cell = so:getParentID(), x = so:getWorldPositionX(), y = so:getWorldPositionY(), z = so:getWorldPositionZ(), template = template, src = "fb_attunement" })
			end
			-- safety net: the Encounter despawn runs off the player; if the player logs out mid-visit the
			-- visitor must still go, so the object sweeps itself a little after its time is up
			createEvent((lifetime or 75000) + 30000, "FbAttunement", "sweepVisitor", pNpc, "")
		end
	end
end

-- The spawn helper defers the despawn of a mobile that still follows someone to a later helper event; our
-- visitors always follow the player, so stop the following first and the despawn is immediate (the fade).
local function despawnVisitors(task, pPlayer)
	local spawned = SpawnMobiles.getSpawnedMobiles(pPlayer, task.taskName)
	local oids = {}
	if spawned ~= nil then
		for _, pNpc in ipairs(spawned) do
			if SpawnMobiles.isValidMobile(pNpc) then
				oids[#oids + 1] = SceneObject(pNpc):getObjectID()
				AiAgent(pNpc):removeObjectFlag(AI_ESCORT)
				AiAgent(pNpc):removeObjectFlag(AI_FOLLOW)
				AiAgent(pNpc):setFollowObject(nil)
			end
		end
	end
	Encounter.doDespawn(task, pPlayer)
	for _, oid in ipairs(oids) do
		local p = getSceneObject(oid)
		if p ~= nil and SceneObject(p):getZoneName() ~= "" then SceneObject(p):destroyObjectFromWorld(true) end
		if p ~= nil then SceneObject(p):destroyObjectFromDatabase() end
		if FbLabTests ~= nil and FbLabTests.registryRemove ~= nil then FbLabTests.registryRemove(oid) end
	end
end

function FbAttunement:sweepVisitor(pNpc)
	if pNpc == nil then return end
	local so = SceneObject(pNpc)
	if so:getZoneName() == "" then return end
	local oid = so:getObjectID()
	printf("FbAttunement: sweeping visitor %d\n", oid)
	so:destroyObjectFromWorld(true)
	so:destroyObjectFromDatabase()
	if FbLabTests ~= nil and FbLabTests.registryRemove ~= nil then FbLabTests.registryRemove(oid) end
end

-- The Encounter base schedules its despawn with the player as the key, so a timer left by an earlier visit
-- (the Old Man's first, ten minutes) would despawn a later visitor of the same task. Every visit therefore
-- carries a generation number, and a despawn event that names another generation is ignored.
function FbAttunement.visitTaskStart(task, pPlayer)
	if not task:isPlayerInPositionForEncounter(pPlayer) or CreatureObject(pPlayer):isDead() then return false end
	if not task:createEncounter(pPlayer) then return false end
	local gen = getRandomNumber(1000000)
	writeData(SceneObject(pPlayer):getObjectID() .. ":fbVisitGen:" .. task.taskName, gen)
	createEvent(task.encounterDespawnTime, task.taskName, "handleDespawnEvent", pPlayer, tostring(gen))
	return true
end
function FbAttunement.visitGen(task, pPlayer) return readData(SceneObject(pPlayer):getObjectID() .. ":fbVisitGen:" .. task.taskName) end
function FbAttunement.visitHandleDespawn(task, pPlayer, args)
	if pPlayer == nil then return end
	-- our visits always stamp their timers; an unstamped one is a leftover of the stock base (or of an older
	-- build) and is ignored — the per-object sweep in recordVisitor is the backstop for anything stuck
	if args == nil or args == "" or tonumber(args) ~= FbAttunement.visitGen(task, pPlayer) then return end
	Encounter.handleDespawnEvent(task, pPlayer)
end
function FbAttunement.visitScheduleDespawn(task, pPlayer, ms)
	if pPlayer ~= nil then createEvent(ms or 10000, task.taskName, "handleDespawnEvent", pPlayer, tostring(FbAttunement.visitGen(task, pPlayer))) end
end

-- ---------------------------------------------------------------- the robed spirit (25 / 50 / 75)

FbForceGhostVisit = Encounter:new {
	taskName = "FbForceGhostVisit",
	encounterDespawnTime = 75 * 1000,
	despawnMessage = "@fb_force:ghost_fades",
	spawnObjectList = {
		{ template = "fb_force_ghost", minimumDistance = 18, maximumDistance = 28, referencePoint = 0, followPlayer = true, setNotAttackable = true }
	},
	inRangeValue = 9,
}

-- the Encounter base reads a missing isEncounterFinished as "already finished" and never spawns: say so explicitly
function FbForceGhostVisit:isEncounterFinished(pPlayer) return false end
function FbForceGhostVisit:taskStart(pPlayer) return FbAttunement.visitTaskStart(self, pPlayer) end
function FbForceGhostVisit:handleDespawnEvent(pPlayer, args) FbAttunement.visitHandleDespawn(self, pPlayer, args) end
function FbForceGhostVisit:onEncounterSpawned(pPlayer, spawned) recordVisitor(pPlayer, spawned, "fb_force_ghost", self.encounterDespawnTime) end

function FbForceGhostVisit:onEncounterInRange(pPlayer, spawned)
	if pPlayer == nil or spawned == nil or spawned[1] == nil then return end
	local tier = readScreenPlayData(pPlayer, FbAttunement.DATA, "ghostTier")
	if tier == nil or tier == "" then tier = "25" end
	writeData(SceneObject(pPlayer):getObjectID() .. ":fbGhostLine", 1)
	self:speak(pPlayer)
end

function FbForceGhostVisit:speak(pPlayer)
	if pPlayer == nil then return end
	local spawned = SpawnMobiles.getSpawnedMobiles(pPlayer, self.taskName)
	if spawned == nil or spawned[1] == nil then return end
	local oid = SceneObject(pPlayer):getObjectID()
	local line = readData(oid .. ":fbGhostLine")
	local tier = readScreenPlayData(pPlayer, FbAttunement.DATA, "ghostTier")
	if line == 3 then
		local hint, here = FbAttunement:unvisitedHint(pPlayer)
		local msg = LuaStringIdChatParameter("@fb_force:ghost_" .. tier .. "_3")
		local where
		if hint == nil then where = "somewhere you have not yet been"
		elseif here then where = hint
		else where = "on " .. hint end
		msg:setTT(where)
		spatialChat(spawned[1], msg:_getObject())
		deleteData(oid .. ":fbGhostLine")
		return
	end
	spatialChat(spawned[1], "@fb_force:ghost_" .. tier .. "_" .. line)
	writeData(oid .. ":fbGhostLine", line + 1)
	createEvent(5000, self.taskName, "speak", pPlayer, "")
end

function FbForceGhostVisit:doDespawn(pPlayer) despawnVisitors(self, pPlayer) end

function FbForceGhostVisit:onEncounterDespawned(pPlayer)
	if pPlayer ~= nil then removeQuestStatus("FbAttunement.visit." .. SceneObject(pPlayer):getObjectID()) end
end
-- the Encounter base despawns through utils/spawn_mobiles; the registry notices a gone oid on its own (liveSpawns
-- checks the object), so nothing to do here beyond the stamp

-- ---------------------------------------------------------------- the Old Man (100)

FbOldManVisit = Encounter:new {
	taskName = "FbOldManVisit",
	encounterDespawnTime = 10 * 60 * 1000,
	despawnMessage = "@fb_force:oldman_leaves",
	spawnObjectList = {
		{ template = "fb_old_man", minimumDistance = 30, maximumDistance = 45, referencePoint = 0, followPlayer = true, setNotAttackable = true, runOnDespawn = true }
	},
	inRangeValue = 10,
}

function FbOldManVisit:isEncounterFinished(pPlayer) return false end
function FbOldManVisit:taskStart(pPlayer) return FbAttunement.visitTaskStart(self, pPlayer) end
function FbOldManVisit:handleDespawnEvent(pPlayer, args) FbAttunement.visitHandleDespawn(self, pPlayer, args) end
function FbOldManVisit:onEncounterSpawned(pPlayer, spawned)
	recordVisitor(pPlayer, spawned, "fb_old_man", self.encounterDespawnTime)
	createEvent(30000, self.taskName, "settle", pPlayer, "")   -- settles where it got to if the ground never lets it in range
end
function FbOldManVisit:settle(pPlayer)
	if pPlayer ~= nil and FbTrials ~= nil and FbTrials.settleBeside ~= nil then FbTrials.settleBeside(pPlayer, SpawnMobiles.getSpawnedMobiles(pPlayer, self.taskName)) end
end

function FbOldManVisit:onEncounterInRange(pPlayer, spawned)
	if pPlayer == nil or spawned == nil or spawned[1] == nil then return end
	if FbTrials ~= nil and FbTrials.standStill ~= nil then FbTrials.standStill(spawned) end   -- stays put through a logout
	local msg = LuaStringIdChatParameter("@fb_force:oldman_greeting")
	msg:setTT(CreatureObject(pPlayer):getFirstName())
	spatialChat(spawned[1], msg:_getObject())
end

function FbOldManVisit:belongsTo(pPlayer, pNpc)
	if pPlayer == nil or pNpc == nil then return false end
	return SpawnMobiles.isFromSpawn(pPlayer, self.taskName, pNpc)
end

function FbOldManVisit:scheduleDespawn(pPlayer) FbAttunement.visitScheduleDespawn(self, pPlayer, 10 * 1000) end

function FbOldManVisit:doDespawn(pPlayer) despawnVisitors(self, pPlayer) end

function FbOldManVisit:onEncounterDespawned(pPlayer)
	if pPlayer ~= nil then removeQuestStatus("FbAttunement.visit." .. SceneObject(pPlayer):getObjectID()) end
end

-- ---------------------------------------------------------------- the Old Man returns (six worlds)

FbOldManReturn = Encounter:new {
	taskName = "FbOldManReturn",
	encounterDespawnTime = 10 * 60 * 1000,
	despawnMessage = "@fb_force:oldman_return_bye",
	spawnObjectList = {
		{ template = "fb_old_man", minimumDistance = 30, maximumDistance = 45, referencePoint = 0, followPlayer = true, setNotAttackable = true, runOnDespawn = true }
	},
	inRangeValue = 10,
}

function FbOldManReturn:isEncounterFinished(pPlayer) return false end
function FbOldManReturn:taskStart(pPlayer) return FbAttunement.visitTaskStart(self, pPlayer) end
function FbOldManReturn:handleDespawnEvent(pPlayer, args) FbAttunement.visitHandleDespawn(self, pPlayer, args) end
function FbOldManReturn:onEncounterSpawned(pPlayer, spawned)
	recordVisitor(pPlayer, spawned, "fb_old_man", self.encounterDespawnTime)
	createEvent(30000, self.taskName, "settle", pPlayer, "")   -- settles where it got to if the ground never lets it in range
end
function FbOldManReturn:settle(pPlayer)
	if pPlayer ~= nil and FbTrials ~= nil and FbTrials.settleBeside ~= nil then FbTrials.settleBeside(pPlayer, SpawnMobiles.getSpawnedMobiles(pPlayer, self.taskName)) end
end
function FbOldManReturn:onEncounterInRange(pPlayer, spawned)
	if pPlayer == nil or spawned == nil or spawned[1] == nil then return end
	if FbTrials ~= nil and FbTrials.standStill ~= nil then FbTrials.standStill(spawned) end   -- stays put through a logout
	local msg = LuaStringIdChatParameter("@fb_force:oldman_return_greeting")
	msg:setTT(CreatureObject(pPlayer):getFirstName())
	spatialChat(spawned[1], msg:_getObject())
end
function FbOldManReturn:belongsTo(pPlayer, pNpc)
	if pPlayer == nil or pNpc == nil then return false end
	return SpawnMobiles.isFromSpawn(pPlayer, self.taskName, pNpc)
end
function FbOldManReturn:scheduleDespawn(pPlayer) FbAttunement.visitScheduleDespawn(self, pPlayer, 10 * 1000) end
function FbOldManReturn:doDespawn(pPlayer) despawnVisitors(self, pPlayer) end
function FbOldManReturn:onEncounterDespawned(pPlayer)
	if pPlayer ~= nil then removeQuestStatus("FbAttunement.visit." .. SceneObject(pPlayer):getObjectID()) end
end

-- ---------------------------------------------------------------- the ambush (two Sith Shadow outlaws)

FbShadowAmbush = Encounter:new {
	taskName = "FbShadowAmbush",
	encounterDespawnTime = 4 * 60 * 1000,
	despawnMessage = "@fb_force:shadow_gone",
	spawnObjectList = {
		{ template = "sith_shadow_outlaw", minimumDistance = 48, maximumDistance = 70, referencePoint = 0, followPlayer = true, setNotAttackable = false, runOnDespawn = true },
		{ template = "sith_shadow_outlaw", minimumDistance = 4, maximumDistance = 8, referencePoint = 1, followPlayer = true, setNotAttackable = false, runOnDespawn = true },
	},
	inRangeValue = 24,
}

function FbShadowAmbush:isEncounterFinished(pPlayer) return false end
function FbShadowAmbush:taskStart(pPlayer) return FbAttunement.visitTaskStart(self, pPlayer) end
function FbShadowAmbush:handleDespawnEvent(pPlayer, args) FbAttunement.visitHandleDespawn(self, pPlayer, args) end

function FbShadowAmbush:onEncounterSpawned(pPlayer, spawned)
	if pPlayer == nil or spawned == nil then return end
	recordVisitor(pPlayer, spawned, "sith_shadow_outlaw", self.encounterDespawnTime)
	local oid = SceneObject(pPlayer):getObjectID()
	writeData(oid .. ":fbAmbushLeft", #spawned)
	for _, pMob in ipairs(spawned) do if pMob ~= nil then writeData(SceneObject(pMob):getObjectID() .. ":fbAmbushFor", oid) end end
	for _, pMob in ipairs(spawned) do
		if pMob ~= nil then createObserver(OBJECTDESTRUCTION, self.taskName, "onShadowDown", pMob) end
	end
	dropObserver(OBJECTDESTRUCTION, self.taskName, "onPlayerDown", pPlayer)
	createObserver(OBJECTDESTRUCTION, self.taskName, "onPlayerDown", pPlayer)
	writeData(oid .. ":fbAmbushPlayerDown", 0)
end

function FbShadowAmbush:onEncounterInRange(pPlayer, spawned)
	if pPlayer == nil or spawned == nil or spawned[1] == nil then return end
	for _, pMob in ipairs(spawned) do
		if pMob ~= nil then
			AiAgent(pMob):removeObjectFlag(AI_ESCORT)
			AiAgent(pMob):removeObjectFlag(AI_FOLLOW)
			AiAgent(pMob):setAITemplate()
			AiAgent(pMob):addDefender(pPlayer)
		end
	end
	local msg = LuaStringIdChatParameter("@fb_force:shadow_threaten")
	msg:setTT(CreatureObject(pPlayer):getFirstName())
	spatialChat(spawned[1], msg:_getObject())
end

-- a shadow went down: the observer argument is the killer; the player it was sent for is found through the spawn record
function FbShadowAmbush:onShadowDown(pMob, pKiller)
	if pMob == nil then return 1 end
	local pPlayer = pKiller
	if pPlayer == nil or not SceneObject(pPlayer):isPlayerCreature() then
		-- killed by a pet, a group member or the lab: the record names the player
		local owner = readData(SceneObject(pMob):getObjectID() .. ":fbAmbushFor")
		pPlayer = owner ~= 0 and getSceneObject(owner) or nil
	end
	if pPlayer == nil then return 1 end
	local oid = SceneObject(pPlayer):getObjectID()
	local left = readData(oid .. ":fbAmbushLeft") - 1
	writeData(oid .. ":fbAmbushLeft", left)
	if left <= 0 and readData(oid .. ":fbAmbushPlayerDown") ~= 1 then
		FbAttunement:setFlag(pPlayer, "ambushDone", os.time())
		FbAttunement:grant(pPlayer, "deeds", "survive:ambush", 3, "shadow_survived")
		FbAttunement.visitScheduleDespawn(self, pPlayer, 15000)
	end
	return 1
end

function FbShadowAmbush:onPlayerDown(pPlayer)
	if pPlayer == nil then return 1 end
	-- they got you this time: no deed, and they will try again later
	writeData(SceneObject(pPlayer):getObjectID() .. ":fbAmbushPlayerDown", 1)
	FbAttunement:setFlag(pPlayer, "ambushDue", os.time() + 1800)
	FbAttunement.visitScheduleDespawn(self, pPlayer, 20000)
	return 1
end

function FbShadowAmbush:doDespawn(pPlayer) despawnVisitors(self, pPlayer) end
function FbShadowAmbush:onEncounterDespawned(pPlayer)
	if pPlayer ~= nil then
		removeQuestStatus("FbAttunement.visit." .. SceneObject(pPlayer):getObjectID())
		dropObserver(OBJECTDESTRUCTION, self.taskName, "onPlayerDown", pPlayer)
	end
end

