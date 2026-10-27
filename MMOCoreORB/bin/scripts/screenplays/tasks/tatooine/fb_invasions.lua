-- fb_invasions.lua — Phase 3.1: GCW invasion events (Bestine first; cities are data).
--
-- Every few hours (persistent server event "FbInvasionTick") the attacking faction moves on a city:
--   construction (10 min): the attackers muster at a staging point outside town, the garrison musters
--                          at the plaza; galaxy warning + news.
--   combat (up to 20 min):  the attackers' commander walks to the plaza, the rest follow, and the two
--                          factions fight (opposing GCW-faction NPCs attack each other; their home is
--                          moved to the plaza first or they leash back to the desert).
--                          Players may join either side; every hit is remembered.
--   resolve:               all attackers dead -> the garrison holds; all defenders dead -> the city falls
--                          for the day; time out -> the attackers withdraw. Broadcast, news, standing
--                          (+50 with the side you fought for, -50 with the other), 1000 cr to winners,
--                          and the city's territory control (quest status FbTerritory.<city>, Imperial %)
--                          shifts 10 points — the seed of 3.4.
-- Fires regardless of who is online; nothing requires players.
--
-- Public for the lab: FbInvasions:begin(city) -> construction now; :assault(city) -> combat now;
-- :resolve(city[, force]) -> evaluate (force ends it as a time-out); :engage(city) -> pair idle attackers
-- near the plaza with defenders; :status(city); :territory(city).

FbInvasions = ScreenPlay:new {
	screenplayName = "FbInvasions",
	eventName = "FbInvasionTick",
	intervalHours = 6,
	constructionSeconds = 600,
	combatSeconds = 1200,
	checkSeconds = 60,
	rewardCredits = 1000,
	rewardStanding = 50,
	territoryShift = 10,
}

-- 3.13: the cities come from the city files (invasion = { defender, attacker, staging, plaza, muster, attackers,
-- defenders, warn, assault, held, fell, withdrew, news }); the city key is the territory region
FbInvasions.cities, FbInvasions.order = {}, {}
if FbCities ~= nil then
	for _, c in ipairs(FbCities.list) do
		if c.invasion ~= nil then
			local cfg = { label = c.label, planet = c.planet }
			for k, v in pairs(c.invasion) do cfg[k] = v end
			FbInvasions.cities[c.key] = cfg
			FbInvasions.order[#FbInvasions.order + 1] = c.key
		end
	end
end

registerScreenPlay("FbInvasions", true)

local function key(city, k) return "FbInvasions." .. city .. "." .. k end
local function get(city, k) return getQuestStatus(key(city, k)) or "" end
local function set(city, k, v) setQuestStatus(key(city, k), tostring(v)) end

local function alive(oid)
	oid = tonumber(oid)
	if oid == nil or oid == 0 then return nil end
	local p = getSceneObject(oid)
	if p == nil or SceneObject(p):getZoneName() == "" then return nil end
	if SceneObject(p):isCreatureObject() and CreatureObject(p):isDead() then return nil end
	return p
end

local function list(city, k)
	local out = {}
	for oid in get(city, k):gmatch("%d+") do out[#out + 1] = tonumber(oid) end
	return out
end

local function count(city, k)
	local living, fighting, hurt = 0, 0, 0
	for _, oid in ipairs(list(city, k)) do
		local p = alive(oid)
		if p ~= nil then
			living = living + 1
			if CreatureObject(p):isInCombat() then fighting = fighting + 1 end
			if CreatureObject(p):getHAM(0) < CreatureObject(p):getMaxHAM(0) then hurt = hurt + 1 end
		end
	end
	return living, #list(city, k), fighting, hurt
end

local function cityOf(name)
	name = name or (FbInvasions.cities.bestine ~= nil and "bestine" or FbInvasions.order[1])
	return name ~= nil and FbInvasions.cities[name] ~= nil and name or nil
end

-- ---- lifecycle --------------------------------------------------------------------------------

function FbInvasions:start()
	for city, _ in pairs(self.cities) do
		if get(city, "phase") ~= "" and get(city, "phase") ~= "idle" then self:cleanup(city) end   -- spawns do not survive a restart
	end
	if not hasServerEvent(self.eventName) then
		createServerEvent(self.intervalHours * 3600 * 1000, "FbInvasions", "onTick", self.eventName)
	end
	printf("FbInvasions: next invasion in <= %d h\n", self.intervalHours)
end

-- onTick: one idle city per planet, round robin (3.13: twenty cities must not go to war on the same hour)
function FbInvasions:onTick()
	local byPlanet, planets = {}, {}
	for _, city in ipairs(self.order) do
		if get(city, "phase") == "" or get(city, "phase") == "idle" then
			local planet = self.cities[city].planet
			if byPlanet[planet] == nil then byPlanet[planet] = {}; planets[#planets + 1] = planet end
			table.insert(byPlanet[planet], city)
		end
	end
	for _, planet in ipairs(planets) do
		local cities = byPlanet[planet]
		local n = (tonumber(getQuestStatus("FbInvasions.next." .. planet)) or 0) % #cities + 1
		setQuestStatus("FbInvasions.next." .. planet, tostring(n))
		local city = cities[n]
		pcall(function() self:begin(city) end)
	end
	if hasServerEvent(self.eventName) then
		rescheduleServerEvent(self.eventName, self.intervalHours * 3600 * 1000)
	else
		createServerEvent(self.intervalHours * 3600 * 1000, "FbInvasions", "onTick", self.eventName)
	end
end

function FbInvasions:territory(city)
	city = cityOf(city)
	if city == nil then return -1 end
	if FbTerritory ~= nil then return FbTerritory.control(city) end
	return tonumber(getQuestStatus("FbTerritory." .. city)) or 50
end

function FbInvasions:status(city)
	city = cityOf(city)
	if city == nil then return "no such city" end
	local aL, aT, aF, aH = count(city, "attackers")
	local dL, dT, dF, dH = count(city, "defenders")
	return string.format("city=%s phase=%s attackers=%d/%d defenders=%d/%d fighting=%d hurt=%d participants=%d outcome=%s territory=%d",
		city, get(city, "phase") ~= "" and get(city, "phase") or "idle", aL, aT, dL, dT, aF + dF, aH + dH,
		#list(city, "for_attackers") + #list(city, "for_defenders"), get(city, "outcome") ~= "" and get(city, "outcome") or "none", self:territory(city))
end

-- ---- spawning ---------------------------------------------------------------------------------

local function spawnSquad(cfg, squad, at, sideKey, city)
	local x, y = at[1], at[2]
	local pLeader = spawnMobile(cfg.planet, squad.leader, 0, x, getTerrainHeightAt(cfg.planet, x, y), y, getRandomNumber(0, 6), 0)
	if pLeader == nil then return nil end
	local oids = { tostring(SceneObject(pLeader):getObjectID()) }
	createObserver(DAMAGERECEIVED, "FbInvasions", "on" .. sideKey .. "Damaged", pLeader)
	for i, template in ipairs(squad.troops) do
		local tx, ty = x + (i % 3) * 3 - 3, y + math.floor(i / 3) * 3
		local p = spawnMobile(cfg.planet, template, 0, tx, getTerrainHeightAt(cfg.planet, tx, ty), ty, getRandomNumber(0, 6), 0)
		if p ~= nil then
			AiAgent(p):setFollowObject(pLeader)
			createObserver(DAMAGERECEIVED, "FbInvasions", "on" .. sideKey .. "Damaged", p)
			oids[#oids + 1] = tostring(SceneObject(p):getObjectID())
		end
	end
	set(city, string.lower(sideKey), table.concat(oids, ","))
	return pLeader
end

-- begin(city): construction phase — both sides muster, the galaxy is warned.
function FbInvasions:begin(city)
	city = cityOf(city)
	local cfg = city and self.cities[city]
	if cfg == nil then return "no such city" end
	if not isZoneEnabled(cfg.planet) then return "zone disabled" end
	self:cleanup(city)
	local pAttackLeader = spawnSquad(cfg, cfg.attackers, cfg.staging, "Attackers", city)
	spawnSquad(cfg, cfg.defenders, cfg.muster, "Defenders", city)
	set(city, "phase", "construction"); set(city, "outcome", ""); set(city, "since", os.time())
	set(city, "for_attackers", ""); set(city, "for_defenders", "")
	if pAttackLeader ~= nil then broadcastToGalaxy(pAttackLeader, cfg.warn) end
	createEvent(self.constructionSeconds * 1000, "FbInvasions", "onAssault", nil, city)
	printf("FbInvasions: %s construction, %s\n", city, self:status(city))
	return self:status(city)
end

function FbInvasions:onAssault(pNil, city) pcall(function() if get(city, "phase") == "construction" then self:assault(city) end end) end

-- assault(city): combat phase — the attackers advance on the plaza.
function FbInvasions:assault(city)
	city = cityOf(city)
	local cfg = city and self.cities[city]
	if cfg == nil then return "no such city" end
	if get(city, "phase") ~= "construction" then return "not in construction" end
	local oids = list(city, "attackers")
	local pz = getTerrainHeightAt(cfg.planet, cfg.plaza[1], cfg.plaza[2])
	-- an AiAgent leashes back to its home when it strays; the attackers' home is now the plaza
	for _, oid in ipairs(oids) do
		local p = alive(oid)
		if p ~= nil then AiAgent(p):setHomeLocation(cfg.plaza[1], pz, cfg.plaza[2], nil) end
	end
	local pLeader = oids[1] and alive(oids[1]) or nil
	if pLeader ~= nil then
		AiAgent(pLeader):setNextPosition(cfg.plaza[1], pz, cfg.plaza[2], 0)
		broadcastToGalaxy(pLeader, cfg.assault)
	end
	set(city, "phase", "combat"); set(city, "since", os.time())
	createEvent(self.checkSeconds * 1000, "FbInvasions", "onCheck", nil, city)
	return self:status(city)
end

-- engage(city): opposing-faction NPCs do attack each other once in awareness range, but a straggler
-- can idle; every check pairs each idle attacker within engageRange of the plaza with a living defender
-- (and the defender with them). Attackers still outside keep walking in. Returns the number of pairs made.
FbInvasions.engageRange = 90

function FbInvasions:engage(city)
	city = cityOf(city)
	local cfg = city and self.cities[city]
	if cfg == nil or get(city, "phase") ~= "combat" then return 0 end
	local defenders = {}
	for _, oid in ipairs(list(city, "defenders")) do
		local p = alive(oid)
		if p ~= nil then defenders[#defenders + 1] = oid end
	end
	if #defenders == 0 then return 0 end
	local pairs_, di = 0, 1
	local pz = getTerrainHeightAt(cfg.planet, cfg.plaza[1], cfg.plaza[2])
	for _, oid in ipairs(list(city, "attackers")) do
		local pA = alive(oid)
		if pA ~= nil and not CreatureObject(pA):isInCombat() then
			local dx, dy = SceneObject(pA):getWorldPositionX() - cfg.plaza[1], SceneObject(pA):getWorldPositionY() - cfg.plaza[2]
			if dx * dx + dy * dy <= self.engageRange * self.engageRange then
				local pD = alive(defenders[di])
				if pD ~= nil then
					AiAgent(pA):setDefender(pD)
					AiAgent(pD):addDefender(pA)
					pairs_ = pairs_ + 1
				end
				di = di % #defenders + 1
			else
				AiAgent(pA):setNextPosition(cfg.plaza[1] + getRandomNumber(-6, 6), pz, cfg.plaza[2] + getRandomNumber(-6, 6), 0)
			end
		end
	end
	return pairs_
end

function FbInvasions:onCheck(pNil, city)
	if get(city, "phase") ~= "combat" then return end
	local timedOut = (os.time() - (tonumber(get(city, "since")) or os.time())) >= self.combatSeconds
	pcall(function() return self:resolve(city, timedOut) end)
	if get(city, "phase") == "combat" then
		pcall(function() self:engage(city) end)
		createEvent(self.checkSeconds * 1000, "FbInvasions", "onCheck", nil, city)
	end
end

-- ---- participants -----------------------------------------------------------------------------

local function remember(city, k, pAttacker)
	if pAttacker == nil or not SceneObject(pAttacker):isPlayerCreature() then return end
	local oid = tostring(SceneObject(pAttacker):getObjectID())
	local cur = get(city, k)
	if not cur:find(oid, 1, true) then set(city, k, cur == "" and oid or (cur .. "," .. oid)) end
end

local function cityOfVictim(pVictim)
	if pVictim == nil then return nil end
	local oid = tostring(SceneObject(pVictim):getObjectID())
	for city, _ in pairs(FbInvasions.cities) do
		if get(city, "attackers"):find(oid, 1, true) or get(city, "defenders"):find(oid, 1, true) then return city end
	end
	return nil
end

-- hitting an attacker means fighting for the defenders, and the other way round
function FbInvasions:onAttackersDamaged(pVictim, pAttacker, damage)
	local city = cityOfVictim(pVictim)
	if city ~= nil then remember(city, "for_defenders", pAttacker) end
	return 0
end

function FbInvasions:onDefendersDamaged(pVictim, pAttacker, damage)
	local city = cityOfVictim(pVictim)
	if city ~= nil then remember(city, "for_attackers", pAttacker) end
	return 0
end

-- ---- outcome ----------------------------------------------------------------------------------

local function reward(pPlayer, forFaction, againstFaction, credits, standing)
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost ~= nil then
		PlayerObject(pGhost):increaseFactionStanding(forFaction, standing)
		PlayerObject(pGhost):decreaseFactionStanding(againstFaction, standing)
	end
	if credits > 0 then CreatureObject(pPlayer):addCashCredits(credits, true) end
	CreatureObject(pPlayer):sendSystemMessage(string.format("The battle for the city is over. %s command notes your part in it: +%d %s standing%s.",
		forFaction == "imperial" and "Imperial" or "Alliance", standing, forFaction, credits > 0 and (", " .. credits .. " credits") or ""))
end

-- resolve(city, force): decide the battle if it is decided (or forced). Returns the outcome or "undecided".
function FbInvasions:resolve(city, force)
	city = cityOf(city)
	local cfg = city and self.cities[city]
	if cfg == nil then return "no such city" end
	if get(city, "phase") ~= "combat" then return "not in combat" end
	local aL = count(city, "attackers")
	local dL = count(city, "defenders")
	local outcome
	if aL == 0 then outcome = "held"
	elseif dL == 0 then outcome = "fell"
	elseif force == true or force == "true" or force == "1" then outcome = "withdrew"
	else return "undecided" end

	local attackersWon = (outcome == "fell")
	for _, oid in ipairs(list(city, "for_attackers")) do
		local p = getSceneObject(oid)
		if p ~= nil and SceneObject(p):isPlayerCreature() then reward(p, cfg.attacker, cfg.defender, attackersWon and self.rewardCredits or 0, self.rewardStanding) end
	end
	for _, oid in ipairs(list(city, "for_defenders")) do
		local p = getSceneObject(oid)
		if p ~= nil and SceneObject(p):isPlayerCreature() then reward(p, cfg.defender, cfg.attacker, (not attackersWon) and self.rewardCredits or 0, self.rewardStanding) end
	end

	if outcome ~= "withdrew" then
		local delta = (outcome == "fell") and -self.territoryShift or self.territoryShift
		if FbTerritory ~= nil then
			FbTerritory.shift(city, delta, "invasion " .. outcome)
		else
			setQuestStatus("FbTerritory." .. city, tostring(math.max(0, math.min(100, self:territory(city) + delta))))
		end
	end

	local pAny = nil
	for _, k in ipairs({ "defenders", "attackers" }) do
		for _, oid in ipairs(list(city, k)) do pAny = pAny or alive(oid) end
	end
	if pAny ~= nil then broadcastToGalaxy(pAny, cfg[outcome]) end
	if FbGalaxyChatter ~= nil then FbGalaxyChatter.addNews("invasion_" .. city .. "_" .. tostring(os.time()), cfg.news[outcome], 2 * 24 * 3600) end

	self:cleanup(city)
	set(city, "outcome", outcome)
	printf("FbInvasions: %s %s, %s\n", city, outcome, self:status(city))
	return outcome
end

function FbInvasions:cleanup(city)
	for _, k in ipairs({ "attackers", "defenders" }) do
		for _, oid in ipairs(list(city, k)) do
			local p = getSceneObject(oid)
			if p ~= nil then SceneObject(p):destroyObjectFromWorld(true) end
		end
		set(city, k, "")
	end
	set(city, "phase", "idle")
end
