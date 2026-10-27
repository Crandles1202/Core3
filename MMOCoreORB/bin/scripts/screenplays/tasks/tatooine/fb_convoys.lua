-- fb_convoys.lua — Phase 3.11: convoy events (ambush mode), per city since 3.13.
--
-- Every 30–60 minutes an Imperial supply convoy forms at a city's starport and walks to the garrison side of
-- town: a squad leader, three stormtroopers and a cargo droid that follows them.
--   * Ambush it: once the first shot lands, reinforcements arrive a minute later if the convoy is still
--     standing. Kill every guard and the cargo droid drops a loot crate, everyone who hit the convoy gains
--     Rebel standing and loses Imperial standing, a galaxy news line is posted and the galaxy is told.
--   * Leave it alone and it reaches the garrison, despawns and the news says it arrived safely.
-- Escort mode (protect a Rebel convoy) is the follow-up; the machinery is the same.
--
-- Cities come from the city files (FbCities): convoy = true | { route = {{x, 0, y}, …} | from = {x, y}, to = {x, y}
-- [, leader, guards, cargo, reinforcements] }. A city without `route` gets one from the navmesh (findPath from its
-- starport to its plaza) the first time a convoy forms there. Quest status: FbConvoys.<city>.<k>.
--
-- Public for the lab: FbConvoys:spawn(city), :status(city), :arrive(city), :defeat(city), :routeFor(city); a nil
-- city is the first one (Mos Eisley).

FbConvoys = ScreenPlay:new {
	screenplayName = "FbConvoys",
	intervalMinutes = { 30, 60 },
	leader = "stormtrooper_squad_leader",
	guards = { "stormtrooper", "stormtrooper", "stormtrooper" },
	cargo = "r2",
	reinforcements = { "stormtrooper", "stormtrooper" },
	reinforceAfterSeconds = 60,
	legMetres = 45,   -- a navmesh route is sampled into legs about this long
	crateTemplate = "object/tangible/container/loot/loot_crate.iff",
	crateLoot = { { group = "junk", count = 2, level = 25 }, { group = "crafting_component", count = 1, level = 30 } },
	rewardCredits = 750,
	rewardStanding = 50,
	dwellSeconds = 20,
}

FbConvoys.cities, FbConvoys.order = {}, {}
if FbCities ~= nil then
	for _, c in ipairs(FbCities.list) do
		if c.convoy then
			local cv = type(c.convoy) == "table" and c.convoy or {}
			FbConvoys.cities[c.key] = {
				label = c.label, planet = c.planet, region = c.key,
				route = cv.route, from = cv.from or c.starport, to = cv.to or c.plaza,
				leader = cv.leader, guards = cv.guards, cargo = cv.cargo, reinforcements = cv.reinforcements,
			}
			FbConvoys.order[#FbConvoys.order + 1] = c.key
		end
	end
end

registerScreenPlay("FbConvoys", true)

local function cityOf(name)
	name = name or FbConvoys.order[1]
	return name ~= nil and FbConvoys.cities[name] ~= nil and name or nil
end
local function key(city, k) return "FbConvoys." .. city .. "." .. k end
local function get(city, k) return getQuestStatus(key(city, k)) or "" end
local function set(city, k, v) setQuestStatus(key(city, k), tostring(v)) end
local function between(r) return getRandomNumber(r[1], r[2]) end

local function alive(oid)
	oid = tonumber(oid)
	if oid == nil or oid == 0 then return nil end
	local p = getSceneObject(oid)
	if p == nil or SceneObject(p):getZoneName() == "" then return nil end
	if SceneObject(p):isCreatureObject() and CreatureObject(p):isDead() then return nil end
	return p
end

local function pointZ(planet, pt) return getTerrainHeightAt(planet, pt[1], pt[3]) end

local function oids(city, k)
	local out = {}
	for oid in get(city, k):gmatch("%d+") do out[#out + 1] = tonumber(oid) end
	return out
end

-- which city's convoy an NPC belongs to (observers get the NPC, not the city)
local function remember(city, p) setQuestStatus("FbConvoys.by." .. tostring(SceneObject(p):getObjectID()), city) end
local function cityOfObject(p)
	if p == nil then return nil end
	return cityOf(getQuestStatus("FbConvoys.by." .. tostring(SceneObject(p):getObjectID())))
end

-- ---- lifecycle --------------------------------------------------------------------------------

function FbConvoys:start()
	for _, city in ipairs(self.order) do
		if get(city, "active") == "1" then self:cleanup(city) end   -- a convoy from before the restart no longer exists as NPCs
		createEvent(between(self.intervalMinutes) * 60 * 1000, "FbConvoys", "onSchedule", nil, city)
	end
	printf("FbConvoys: %d cities, next convoy in %d-%d min\n", #self.order, self.intervalMinutes[1], self.intervalMinutes[2])
end

function FbConvoys:onSchedule(pNil, city)
	city = cityOf(city)
	if city == nil then return end
	pcall(function() if get(city, "active") ~= "1" then self:spawn(city) end end)
	createEvent(between(self.intervalMinutes) * 60 * 1000, "FbConvoys", "onSchedule", nil, city)
end

function FbConvoys:status(city)
	city = cityOf(city)
	if city == nil then return "no such city" end
	local guardsAlive = 0
	for _, oid in ipairs(oids(city, "guards")) do if alive(oid) then guardsAlive = guardsAlive + 1 end end
	local pLeader = alive(get(city, "leader"))
	local pos = pLeader and string.format("x=%.0f y=%.0f", SceneObject(pLeader):getWorldPositionX(), SceneObject(pLeader):getWorldPositionY()) or "x=0 y=0"
	return string.format("city=%s active=%s leader=%s %s guards=%d/%d cargo=%s point=%s attackers=%d reinforced=%s crate=%s outcome=%s",
		city, get(city, "active") == "1" and "1" or "0", pLeader and get(city, "leader") or "0", pos, guardsAlive, #oids(city, "guards"),
		alive(get(city, "cargo")) and get(city, "cargo") or "0", get(city, "point") ~= "" and get(city, "point") or "0", #oids(city, "attackers"),
		get(city, "reinforced") == "1" and "1" or "0", get(city, "crate") ~= "" and get(city, "crate") or "0", get(city, "outcome") ~= "" and get(city, "outcome") or "none")
end

-- ---- the route ----------------------------------------------------------------------------------

-- routeFor(city): the legs the convoy walks — the city's own points, or a navmesh path from its starport to its
-- plaza sampled every legMetres (computed once per Lua state). nil when the city has neither.
function FbConvoys:routeFor(city)
	city = cityOf(city)
	local cfg = city and self.cities[city]
	if cfg == nil then return nil end
	if cfg.route ~= nil then return cfg.route end
	if cfg.routeCache ~= nil then return cfg.routeCache end
	if cfg.from == nil or cfg.to == nil then return nil end
	local path = findPath(cfg.planet, cfg.from[1], cfg.from[2], cfg.to[1], cfg.to[2])
	if path == nil or #path < 2 then return nil end
	local route, lx, ly = { { cfg.from[1], 0, cfg.from[2] } }, cfg.from[1], cfg.from[2]
	for i = 2, #path do
		local p = path[i]
		if (p.cell or 0) == 0 then
			local dx, dy = p.x - lx, p.y - ly
			if i == #path or dx * dx + dy * dy >= self.legMetres * self.legMetres then
				route[#route + 1] = { p.x, 0, p.y }
				lx, ly = p.x, p.y
			end
		end
	end
	if #route < 2 then return nil end
	cfg.routeCache = route
	return route
end

-- ---- spawn / move -------------------------------------------------------------------------------

function FbConvoys:spawn(city)
	city = cityOf(city)
	local cfg = city and self.cities[city]
	if cfg == nil then return "no such city" end
	if not isZoneEnabled(cfg.planet) then return "zone disabled" end
	local route = self:routeFor(city)
	if route == nil then return "no route" end
	self:cleanup(city)
	local pt = { route[1][1], pointZ(cfg.planet, route[1]), route[1][3] }
	local pLeader = spawnMobile(cfg.planet, cfg.leader or self.leader, 0, pt[1], pt[2], pt[3], 1, 0)
	if pLeader == nil then return "spawn failed" end
	set(city, "leader", SceneObject(pLeader):getObjectID())
	remember(city, pLeader)
	createObserver(DESTINATIONREACHED, "FbConvoys", "onLeaderArrived", pLeader)
	createObserver(DAMAGERECEIVED, "FbConvoys", "onDamaged", pLeader)
	createObserver(OBJECTDESTRUCTION, "FbConvoys", "onGuardKilled", pLeader)

	local guardOids = { tostring(SceneObject(pLeader):getObjectID()) }
	for i, template in ipairs(cfg.guards or self.guards) do
		local p = spawnMobile(cfg.planet, template, 0, pt[1] - i * 2, pt[2], pt[3] + (i % 2) * 2, 1, 0)
		if p ~= nil then
			AiAgent(p):setFollowObject(pLeader)
			remember(city, p)
			createObserver(DAMAGERECEIVED, "FbConvoys", "onDamaged", p)
			createObserver(OBJECTDESTRUCTION, "FbConvoys", "onGuardKilled", p)
			guardOids[#guardOids + 1] = tostring(SceneObject(p):getObjectID())
		end
	end
	set(city, "guards", table.concat(guardOids, ","))

	local pCargo = spawnMobile(cfg.planet, cfg.cargo or self.cargo, 0, pt[1] - 3, pt[2], pt[3] - 3, 1, 0)
	if pCargo ~= nil then
		AiAgent(pCargo):setFollowObject(pLeader)
		CreatureObject(pCargo):setPvpStatusBitmask(0)
		remember(city, pCargo)
		set(city, "cargo", SceneObject(pCargo):getObjectID())
	end

	set(city, "active", "1"); set(city, "point", "1"); set(city, "attackers", ""); set(city, "reinforced", "0"); set(city, "crate", ""); set(city, "outcome", "")
	createEvent(self.dwellSeconds * 1000, "FbConvoys", "onStep", nil, city)
	printf("FbConvoys: convoy spawned, %s\n", self:status(city))
	return self:status(city)
end

function FbConvoys:step(city)
	city = cityOf(city)
	if city == nil then return "no such city" end
	if get(city, "active") ~= "1" then return "inactive" end
	local pLeader = alive(get(city, "leader"))
	if pLeader == nil then return "no_leader" end
	if CreatureObject(pLeader):isInCombat() then return "in_combat" end
	local route = self:routeFor(city)
	local idx = (tonumber(get(city, "point")) or 1) + 1
	if route == nil or idx > #route then return self:arrive(city) end
	local pt = route[idx]
	AiAgent(pLeader):setNextPosition(pt[1], pointZ(self.cities[city].planet, pt), pt[3], 0)
	set(city, "point", idx)
	return tostring(idx)
end

function FbConvoys:onStep(pNil, city)
	city = cityOf(city)
	if city == nil then return end
	local ok, result = pcall(function() return self:step(city) end)
	if get(city, "active") == "1" and (not ok or result == "in_combat" or result == "no_leader") then
		createEvent(30 * 1000, "FbConvoys", "onStep", nil, city)
	elseif get(city, "active") == "1" then
		createEvent(240 * 1000, "FbConvoys", "onStep", nil, city)   -- safety net if arrival never fires
	end
end

function FbConvoys:onLeaderArrived(pLeader)
	local city = cityOfObject(pLeader)
	if city ~= nil and get(city, "active") == "1" then createEvent(self.dwellSeconds * 1000, "FbConvoys", "onStep", nil, city) end
	return 0
end

-- ---- combat -----------------------------------------------------------------------------------

local function recordAttacker(city, pAttacker)
	if pAttacker == nil or not SceneObject(pAttacker):isPlayerCreature() then return end
	local oid = tostring(SceneObject(pAttacker):getObjectID())
	local list = get(city, "attackers")
	if not list:find(oid, 1, true) then set(city, "attackers", list == "" and oid or (list .. "," .. oid)) end
end

function FbConvoys:onDamaged(pVictim, pAttacker, damage)
	local city = cityOfObject(pVictim)
	if city == nil or get(city, "active") ~= "1" or pAttacker == nil then return 0 end
	recordAttacker(city, pAttacker)
	if get(city, "reinforced") ~= "1" then
		set(city, "reinforced", "1")
		createEvent(self.reinforceAfterSeconds * 1000, "FbConvoys", "onReinforce", nil, city)
	end
	return 0
end

function FbConvoys:onReinforce(pNil, city)
	city = cityOf(city)
	if city == nil or get(city, "active") ~= "1" then return end
	local cfg = self.cities[city]
	local pLeader = alive(get(city, "leader"))
	local pAnchor = pLeader or alive(get(city, "cargo"))
	if pAnchor == nil then return end
	local x, z, y = SceneObject(pAnchor):getWorldPositionX(), SceneObject(pAnchor):getWorldPositionZ(), SceneObject(pAnchor):getWorldPositionY()
	local guardOids = get(city, "guards")
	for i, template in ipairs(cfg.reinforcements or self.reinforcements) do
		local p = spawnMobile(cfg.planet, template, 0, x + i * 3, z, y + i * 2, 1, 0)
		if p ~= nil then
			remember(city, p)
			createObserver(DAMAGERECEIVED, "FbConvoys", "onDamaged", p)
			createObserver(OBJECTDESTRUCTION, "FbConvoys", "onGuardKilled", p)
			guardOids = guardOids .. "," .. tostring(SceneObject(p):getObjectID())
			spatialChat(p, "Convoy under attack! Reinforcing!")
		end
	end
	set(city, "guards", guardOids)
end

function FbConvoys:onGuardKilled(pVictim, pAttacker)
	local city = cityOfObject(pVictim)
	if city == nil or get(city, "active") ~= "1" then return 1 end
	recordAttacker(city, pAttacker)
	for _, oid in ipairs(oids(city, "guards")) do
		if alive(oid) ~= nil and (pVictim == nil or oid ~= SceneObject(pVictim):getObjectID()) then return 1 end
	end
	createEvent(1000, "FbConvoys", "onDefeatEvent", nil, city)   -- let the last death finish before looting
	return 1
end

function FbConvoys:onDefeatEvent(pNil, city) pcall(function() self:defeat(city) end) end

-- defeat(city): every guard is down. Crate, rewards, news.
function FbConvoys:defeat(city)
	city = cityOf(city)
	local cfg = city and self.cities[city]
	if cfg == nil then return "no such city" end
	if get(city, "active") ~= "1" then return "inactive" end
	local route = self:routeFor(city) or { { 0, 0, 0 } }
	local pCargo = alive(get(city, "cargo"))
	local pAnchor = pCargo or alive(get(city, "leader"))
	local x, z, y = route[1][1], pointZ(cfg.planet, route[1]), route[1][3]
	if pAnchor ~= nil then
		x, z, y = SceneObject(pAnchor):getWorldPositionX(), SceneObject(pAnchor):getWorldPositionZ(), SceneObject(pAnchor):getWorldPositionY()
	end
	if pCargo ~= nil then
		spatialChat(pCargo, "*the cargo droid powers down and its hold springs open*")
		SceneObject(pCargo):destroyObjectFromWorld(true)
	end

	local pCrate = spawnSceneObject(cfg.planet, self.crateTemplate, x + 1, z, y + 1, 0, 0)
	if pCrate ~= nil then
		for _, spec in ipairs(self.crateLoot) do
			for i = 1, spec.count do createLoot(pCrate, spec.group, spec.level, false) end
		end
		set(city, "crate", SceneObject(pCrate):getObjectID())
	end

	local rewarded = 0
	for _, oid in ipairs(oids(city, "attackers")) do
		local pPlayer = getSceneObject(oid)
		if pPlayer ~= nil and SceneObject(pPlayer):isPlayerCreature() then
			local pGhost = CreatureObject(pPlayer):getPlayerObject()
			if pGhost ~= nil then
				PlayerObject(pGhost):increaseFactionStanding("rebel", self.rewardStanding)
				PlayerObject(pGhost):decreaseFactionStanding("imperial", self.rewardStanding)
			end
			CreatureObject(pPlayer):addCashCredits(self.rewardCredits, true)
			CreatureObject(pPlayer):sendSystemMessage("The Imperial convoy is destroyed. The Alliance notes your part in it: +" .. self.rewardStanding .. " Rebel standing, " .. self.rewardCredits .. " credits.")
			rewarded = rewarded + 1
		end
	end

	if FbGalaxyChatter ~= nil then
		FbGalaxyChatter.addNews("convoy_" .. tostring(os.time()), "An Imperial supply convoy was destroyed in " .. cfg.label .. ". The garrison is furious.", 2 * 24 * 3600)
	end
	local pAny = alive(get(city, "leader"))
	if pAny ~= nil then broadcastToGalaxy(pAny, cfg.label .. ": an Imperial supply convoy has been destroyed near the starport.") end

	if FbTerritory ~= nil then FbTerritory.shift(cfg.region, -10, "convoy destroyed") end
	set(city, "active", "0"); set(city, "outcome", "destroyed")
	printf("FbConvoys: %s convoy destroyed, %d attackers rewarded\n", city, rewarded)
	return self:status(city)
end

-- arrive(city): the convoy made it. Quiet despawn, a news line.
function FbConvoys:arrive(city)
	city = cityOf(city)
	local cfg = city and self.cities[city]
	if cfg == nil then return "no such city" end
	if get(city, "active") ~= "1" then return "inactive" end
	if FbGalaxyChatter ~= nil then
		FbGalaxyChatter.addNews("convoy_" .. tostring(os.time()), "An Imperial supply convoy reached the " .. cfg.label .. " garrison untouched. Business as usual.", 2 * 24 * 3600)
	end
	self:cleanup(city)
	if FbTerritory ~= nil then FbTerritory.shift(cfg.region, 5, "convoy arrived") end
	set(city, "outcome", "arrived")
	printf("FbConvoys: %s convoy arrived\n", city)
	return self:status(city)
end

function FbConvoys:cleanup(city)
	city = cityOf(city)
	if city == nil then return end
	for _, k in ipairs({ "leader", "cargo" }) do
		local p = getSceneObject(tonumber(get(city, k)) or 0)
		if p ~= nil then SceneObject(p):destroyObjectFromWorld(true) end
		if get(city, k) ~= "" then removeQuestStatus("FbConvoys.by." .. get(city, k)) end
	end
	for _, oid in ipairs(oids(city, "guards")) do
		local p = getSceneObject(oid)
		if p ~= nil then SceneObject(p):destroyObjectFromWorld(true) end
		removeQuestStatus("FbConvoys.by." .. tostring(oid))
	end
	set(city, "active", "0"); set(city, "leader", ""); set(city, "guards", ""); set(city, "cargo", ""); set(city, "point", ""); set(city, "attackers", ""); set(city, "reinforced", "0")
end
