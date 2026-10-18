-- fb_convoys.lua — Phase 3.11: convoy events (ambush mode).
--
-- Every 30–60 minutes an Imperial supply convoy forms at the Mos Eisley starport and walks to the
-- garrison side of town: a squad leader, three stormtroopers and a cargo droid that follows them.
--   * Ambush it: once the first shot lands, reinforcements arrive a minute later if the convoy is
--     still standing. Kill every guard and the cargo droid drops a loot crate, everyone who hit the
--     convoy gains Rebel standing and loses Imperial standing, a galaxy news line is posted and the
--     galaxy is told.
--   * Leave it alone and it reaches the garrison, despawns and the news says it arrived safely.
-- Escort mode (protect a Rebel convoy) is the follow-up; the machinery is the same.
--
-- Public for the lab: FbConvoys:spawn(), :status(), :arrive(), :defeat().

FbConvoys = ScreenPlay:new {
	screenplayName = "FbConvoys",
	intervalMinutes = { 30, 60 },
	planet = "tatooine",
	leader = "stormtrooper_squad_leader",
	guards = { "stormtrooper", "stormtrooper", "stormtrooper" },
	cargo = "r2",
	reinforcements = { "stormtrooper", "stormtrooper" },
	reinforceAfterSeconds = 60,
	-- starport vendor row -> through town -> the garrison end of the patrol loop (known walkable points)
	route = { { 3540, 0, -4816 }, { 3470, 0, -4795 }, { 3430, 0, -4772 }, { 3403, 0, -4775 }, { 3359, 0, -4755 }, { 3318, 0, -4811 } },   -- z is looked up from the terrain
	crateTemplate = "object/tangible/container/loot/loot_crate.iff",
	crateLoot = { { group = "junk", count = 2, level = 25 }, { group = "crafting_component", count = 1, level = 30 } },
	rewardCredits = 750,
	rewardStanding = 50,
	dwellSeconds = 20,
}

registerScreenPlay("FbConvoys", true)

local K = "FbConvoys."
local function get(k) return getQuestStatus(K .. k) or "" end
local function set(k, v) setQuestStatus(K .. k, tostring(v)) end
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

local function oids(k)
	local out = {}
	for oid in get(k):gmatch("%d+") do out[#out + 1] = tonumber(oid) end
	return out
end

-- ---- lifecycle --------------------------------------------------------------------------------

function FbConvoys:start()
	if get("active") == "1" then
		self:cleanup()   -- a convoy from before the restart no longer exists as NPCs
	end
	createEvent(between(self.intervalMinutes) * 60 * 1000, "FbConvoys", "onSchedule", nil, "")
	printf("FbConvoys: next convoy in %d-%d min\n", self.intervalMinutes[1], self.intervalMinutes[2])
end

function FbConvoys:onSchedule()
	pcall(function() if get("active") ~= "1" then self:spawn() end end)
	createEvent(between(self.intervalMinutes) * 60 * 1000, "FbConvoys", "onSchedule", nil, "")
end

function FbConvoys:status()
	local guardsAlive = 0
	for _, oid in ipairs(oids("guards")) do if alive(oid) then guardsAlive = guardsAlive + 1 end end
	local pLeader = alive(get("leader"))
	local pos = pLeader and string.format("x=%.0f y=%.0f", SceneObject(pLeader):getWorldPositionX(), SceneObject(pLeader):getWorldPositionY()) or "x=0 y=0"
	return string.format("active=%s leader=%s %s guards=%d/%d cargo=%s point=%s attackers=%d reinforced=%s crate=%s outcome=%s",
		get("active") == "1" and "1" or "0", alive(get("leader")) and get("leader") or "0", pos, guardsAlive, #oids("guards"),
		alive(get("cargo")) and get("cargo") or "0", get("point") ~= "" and get("point") or "0", #oids("attackers"),
		get("reinforced") == "1" and "1" or "0", get("crate") ~= "" and get("crate") or "0", get("outcome") ~= "" and get("outcome") or "none")
end

-- ---- spawn / move -------------------------------------------------------------------------------

function FbConvoys:spawn()
	if not isZoneEnabled(self.planet) then return "zone disabled" end
	self:cleanup()
	local pt = { self.route[1][1], pointZ(self.planet, self.route[1]), self.route[1][3] }
	local pLeader = spawnMobile(self.planet, self.leader, 0, pt[1], pt[2], pt[3], 1, 0)
	if pLeader == nil then return "spawn failed" end
	set("leader", SceneObject(pLeader):getObjectID())
	createObserver(DESTINATIONREACHED, "FbConvoys", "onLeaderArrived", pLeader)
	createObserver(DAMAGERECEIVED, "FbConvoys", "onDamaged", pLeader)
	createObserver(OBJECTDESTRUCTION, "FbConvoys", "onGuardKilled", pLeader)

	local guardOids = { tostring(SceneObject(pLeader):getObjectID()) }
	for i, template in ipairs(self.guards) do
		local p = spawnMobile(self.planet, template, 0, pt[1] - i * 2, pt[2], pt[3] + (i % 2) * 2, 1, 0)
		if p ~= nil then
			AiAgent(p):setFollowObject(pLeader)
			createObserver(DAMAGERECEIVED, "FbConvoys", "onDamaged", p)
			createObserver(OBJECTDESTRUCTION, "FbConvoys", "onGuardKilled", p)
			guardOids[#guardOids + 1] = tostring(SceneObject(p):getObjectID())
		end
	end
	set("guards", table.concat(guardOids, ","))

	local pCargo = spawnMobile(self.planet, self.cargo, 0, pt[1] - 3, pt[2], pt[3] - 3, 1, 0)
	if pCargo ~= nil then
		AiAgent(pCargo):setFollowObject(pLeader)
		CreatureObject(pCargo):setPvpStatusBitmask(0)
		set("cargo", SceneObject(pCargo):getObjectID())
	end

	set("active", "1"); set("point", "1"); set("attackers", ""); set("reinforced", "0"); set("crate", ""); set("outcome", "")
	createEvent(self.dwellSeconds * 1000, "FbConvoys", "onStep", nil, "")
	printf("FbConvoys: convoy spawned, %s\n", self:status())
	return self:status()
end

function FbConvoys:step()
	if get("active") ~= "1" then return "inactive" end
	local pLeader = alive(get("leader"))
	if pLeader == nil then return "no_leader" end
	if CreatureObject(pLeader):isInCombat() then return "in_combat" end
	local idx = (tonumber(get("point")) or 1) + 1
	if idx > #self.route then return self:arrive() end
	local pt = self.route[idx]
	AiAgent(pLeader):setNextPosition(pt[1], pointZ(self.planet, pt), pt[3], 0)
	set("point", idx)
	return tostring(idx)
end

function FbConvoys:onStep()
	local ok, result = pcall(function() return self:step() end)
	if get("active") == "1" and (not ok or result == "in_combat" or result == "no_leader") then
		createEvent(30 * 1000, "FbConvoys", "onStep", nil, "")
	elseif get("active") == "1" then
		createEvent(240 * 1000, "FbConvoys", "onStep", nil, "")   -- safety net if arrival never fires
	end
end

function FbConvoys:onLeaderArrived(pLeader)
	if get("active") == "1" then createEvent(self.dwellSeconds * 1000, "FbConvoys", "onStep", nil, "") end
	return 0
end

-- ---- combat -----------------------------------------------------------------------------------

local function recordAttacker(pAttacker)
	if pAttacker == nil or not SceneObject(pAttacker):isPlayerCreature() then return end
	local oid = tostring(SceneObject(pAttacker):getObjectID())
	local list = get("attackers")
	if not list:find(oid, 1, true) then set("attackers", list == "" and oid or (list .. "," .. oid)) end
end

function FbConvoys:onDamaged(pVictim, pAttacker, damage)
	if get("active") ~= "1" or pAttacker == nil then return 0 end
	recordAttacker(pAttacker)
	if get("reinforced") ~= "1" then
		set("reinforced", "1")
		createEvent(self.reinforceAfterSeconds * 1000, "FbConvoys", "onReinforce", nil, "")
	end
	return 0
end

function FbConvoys:onReinforce()
	if get("active") ~= "1" then return end
	local pLeader = alive(get("leader"))
	local pAnchor = pLeader or alive(get("cargo"))
	if pAnchor == nil then return end
	local x, z, y = SceneObject(pAnchor):getWorldPositionX(), SceneObject(pAnchor):getWorldPositionZ(), SceneObject(pAnchor):getWorldPositionY()
	local guardOids = get("guards")
	for i, template in ipairs(self.reinforcements) do
		local p = spawnMobile(self.planet, template, 0, x + i * 3, z, y + i * 2, 1, 0)
		if p ~= nil then
			createObserver(DAMAGERECEIVED, "FbConvoys", "onDamaged", p)
			createObserver(OBJECTDESTRUCTION, "FbConvoys", "onGuardKilled", p)
			guardOids = guardOids .. "," .. tostring(SceneObject(p):getObjectID())
			spatialChat(p, "Convoy under attack! Reinforcing!")
		end
	end
	set("guards", guardOids)
end

function FbConvoys:onGuardKilled(pVictim, pAttacker)
	if get("active") ~= "1" then return 1 end
	recordAttacker(pAttacker)
	for _, oid in ipairs(oids("guards")) do
		if alive(oid) ~= nil and (pVictim == nil or oid ~= SceneObject(pVictim):getObjectID()) then return 1 end
	end
	createEvent(1000, "FbConvoys", "onDefeatEvent", nil, "")   -- let the last death finish before looting
	return 1
end

function FbConvoys:onDefeatEvent() pcall(function() self:defeat() end) end

-- defeat(): every guard is down. Crate, rewards, news.
function FbConvoys:defeat()
	if get("active") ~= "1" then return "inactive" end
	local pCargo = alive(get("cargo"))
	local pAnchor = pCargo or alive(get("leader"))
	local x, z, y = self.route[1][1], pointZ(self.planet, self.route[1]), self.route[1][3]
	if pAnchor ~= nil then
		x, z, y = SceneObject(pAnchor):getWorldPositionX(), SceneObject(pAnchor):getWorldPositionZ(), SceneObject(pAnchor):getWorldPositionY()
	end
	if pCargo ~= nil then
		spatialChat(pCargo, "*the cargo droid powers down and its hold springs open*")
		SceneObject(pCargo):destroyObjectFromWorld(true)
	end

	local pCrate = spawnSceneObject(self.planet, self.crateTemplate, x + 1, z, y + 1, 0, 0)
	if pCrate ~= nil then
		for _, spec in ipairs(self.crateLoot) do
			for i = 1, spec.count do createLoot(pCrate, spec.group, spec.level, false) end
		end
		set("crate", SceneObject(pCrate):getObjectID())
	end

	local rewarded = 0
	for _, oid in ipairs(oids("attackers")) do
		local pPlayer = getSceneObject(oid)
		if pPlayer ~= nil and SceneObject(pPlayer):isPlayerCreature() then
			local pGhost = CreatureObject(pPlayer):getPlayerObject()
			if pGhost ~= nil then
				PlayerObject(pGhost):increaseFactionStanding("rebel", self.rewardStanding)
				PlayerObject(pGhost):decreaseFactionStanding("imperial", self.rewardStanding)
			end
			CreatureObject(pPlayer):addCashCredits(self.rewardCredits, true)
			CreatureObject(pPlayer):sendSystemMessage("The Imperial convoy is destroyed. The Alliance notes your part in it: +" .. self.rewardStanding .. " Rebel standing, " .. self.rewardCredits .. " credits from the crate's manifest.")
			rewarded = rewarded + 1
		end
	end

	if FbGalaxyChatter ~= nil then
		FbGalaxyChatter.addNews("convoy_" .. tostring(os.time()), "An Imperial supply convoy was destroyed in Mos Eisley. The garrison is furious.", 2 * 24 * 3600)
	end
	local pAny = alive(get("leader"))
	if pAny ~= nil then broadcastToGalaxy(pAny, "Mos Eisley: an Imperial supply convoy has been destroyed near the starport.") end

	set("active", "0"); set("outcome", "destroyed")
	printf("FbConvoys: convoy destroyed, %d attackers rewarded\n", rewarded)
	return self:status()
end

-- arrive(): the convoy made it. Quiet despawn, a news line.
function FbConvoys:arrive()
	if get("active") ~= "1" then return "inactive" end
	if FbGalaxyChatter ~= nil then
		FbGalaxyChatter.addNews("convoy_" .. tostring(os.time()), "An Imperial supply convoy reached the Mos Eisley garrison untouched. Business as usual.", 2 * 24 * 3600)
	end
	self:cleanup()
	set("outcome", "arrived")
	printf("FbConvoys: convoy arrived\n")
	return self:status()
end

function FbConvoys:cleanup()
	for _, k in ipairs({ "leader", "cargo" }) do
		local p = getSceneObject(tonumber(get(k)) or 0)
		if p ~= nil then SceneObject(p):destroyObjectFromWorld(true) end
	end
	for _, oid in ipairs(oids("guards")) do
		local p = getSceneObject(oid)
		if p ~= nil then SceneObject(p):destroyObjectFromWorld(true) end
	end
	set("active", "0"); set("leader", ""); set("guards", ""); set("cargo", ""); set("point", ""); set("attackers", ""); set("reinforced", "0")
end
