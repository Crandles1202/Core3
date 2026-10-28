-- fb_checkpoints.lua — Phase 3.15: checkpoints at the starports of held cities.
--
-- Where the Empire holds a city (3.4 territory ≥ 60 %) an officer and two stormtroopers stand ten metres in from the
-- starport pad and hail everyone who walks through: a Rebel is set upon, an Imperial saluted, a neutral waved on or,
-- one time in four, pulled aside for a short search that costs a point of Imperial standing. Where the Rebellion holds
-- the city (≤ 40 %) a picket of commandos does the same the other way round. Contested cities have no post. The holder
-- is read again every ten minutes; a post whose side lost the city is relieved. Cities come from the city data.
--
-- Public for the lab: FbCheckpoints:hail(city, pPlayer) -> what happened; :refresh() re-reads every holder; :status(city).

FbCheckpoints = ScreenPlay:new {
	screenplayName = "FbCheckpoints",
	tickSeconds = 5,          -- how often a post looks at who is passing
	refreshSeconds = 600,     -- how often the holder is read again
	hailRange = 12,
	hailAgainAfter = 180,     -- seconds before the same player is hailed again
	searchChance = 25,        -- % of neutrals pulled aside
	standingTilt = 1,         -- what a search costs with the post's faction
	posts = {
		imperial = { officer = "stormtrooper_squad_leader", troops = { "stormtrooper", "stormtrooper" },
			hailLine = "Identification.", friend = "Carry on, citizen. The Empire thanks you.", wave = "Move along.",
			search = "Random search. Hands where we can see them.", clean = "Clean. Don't make us look twice.",
			enemy = "Rebel! Take them!" },
		rebel = { officer = "rebel_commando", troops = { "rebel_trooper", "rebel_trooper" },
			hailLine = "Hold up there.", friend = "Good to see a friendly face. Go on through.", wave = "Go on, you're fine.",
			search = "Quick check. Imperial spies come through here dressed like anyone.", clean = "You're clean. Sorry about that.",
			enemy = "Imperial! Open fire!" },
	},
}

FbCheckpoints.cities, FbCheckpoints.order = {}, {}
if FbCities ~= nil then
	for _, c in ipairs(FbCities.list) do
		local relay
		for _, r in ipairs(c.relays or {}) do if r.key == "starport" then relay = r end end
		local sx, sy = relay and relay.x or (c.starport and c.starport[1]), relay and relay.y or (c.starport and c.starport[2])
		if sx ~= nil and c.centre ~= nil then
			-- ten metres further in from the relay spot, toward the city centre
			local dx, dy = c.centre[1] - sx, c.centre[2] - sy
			local len = math.max(1, math.sqrt(dx * dx + dy * dy))
			FbCheckpoints.cities[c.key] = { label = c.label, planet = c.planet, x = sx + dx / len * 10, y = sy + dy / len * 10, dir = math.atan2(-dx, -dy) }
			FbCheckpoints.order[#FbCheckpoints.order + 1] = c.key
		end
	end
end

registerScreenPlay("FbCheckpoints", true)

local PLAYER_TYPE = 0x409
local function key(city, k) return "FbCheckpoints." .. city .. "." .. k end
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

local function oids(city)
	local out = {}
	for oid in get(city, "post"):gmatch("%d+") do out[#out + 1] = tonumber(oid) end
	return out
end

-- the side that should hold the post right now: "imperial", "rebel" or nil
function FbCheckpoints:holder(city)
	if FbTerritory == nil then return nil end
	local f = FbTerritory.faction(city)
	if f == "imperial" or f == "rebel" then return f end
	return nil
end

-- ---- lifecycle --------------------------------------------------------------------------------

function FbCheckpoints:start()
	local n = 0
	for _, city in ipairs(self.order) do
		local cfg = self.cities[city]
		if isZoneEnabled(cfg.planet) then
			set(city, "post", ""); set(city, "side", "")   -- spawns do not survive a restart
			self:refreshCity(city)
			createEvent((self.tickSeconds + getRandomNumber(0, 5)) * 1000, "FbCheckpoints", "onTick", nil, city)
			n = n + 1
		end
	end
	createEvent(self.refreshSeconds * 1000, "FbCheckpoints", "onRefresh", nil, "")
	printf("FbCheckpoints: %d starports watched\n", n)
end

-- refreshCity(city): spawn, keep or relieve the post according to the holder
function FbCheckpoints:refreshCity(city)
	local cfg = self.cities[city]
	if cfg == nil then return "no such city" end
	local want, have = self:holder(city), get(city, "side")
	local living = 0
	for _, oid in ipairs(oids(city)) do if alive(oid) then living = living + 1 end end
	if want == nil or want ~= have or living < 3 then
		for _, oid in ipairs(oids(city)) do
			local p = getSceneObject(oid)
			if p ~= nil then SceneObject(p):destroyObjectFromWorld(true) end
		end
		set(city, "post", ""); set(city, "side", "")
	end
	if want ~= nil and get(city, "side") == "" then
		local post = self.posts[want]
		local list = {}
		local templates = { post.officer, post.troops[1], post.troops[2] }
		local offsets = { { 0, 0 }, { -2.5, 1 }, { 2.5, 1 } }
		for i, t in ipairs(templates) do
			local x, y = cfg.x + offsets[i][1], cfg.y + offsets[i][2]
			local p = spawnMobile(cfg.planet, t, 0, x, getTerrainHeightAt(cfg.planet, x, y), y, cfg.dir, 0)
			if p ~= nil then
				AiAgent(p):addObjectFlag(AI_STATIC)
				list[#list + 1] = tostring(SceneObject(p):getObjectID())
			end
		end
		set(city, "post", table.concat(list, ",")); set(city, "side", want)
	end
	return get(city, "side") ~= "" and get(city, "side") or "none"
end

function FbCheckpoints:refresh()
	local out = {}
	for _, city in ipairs(self.order) do
		if isZoneEnabled(self.cities[city].planet) then out[#out + 1] = city .. "=" .. self:refreshCity(city) end
	end
	return table.concat(out, " ")
end

function FbCheckpoints:onRefresh()
	pcall(function() self:refresh() end)
	createEvent(self.refreshSeconds * 1000, "FbCheckpoints", "onRefresh", nil, "")
end

function FbCheckpoints:status(city)
	local cfg = self.cities[city]
	if cfg == nil then return "no such city" end
	local living = 0
	for _, oid in ipairs(oids(city)) do if alive(oid) then living = living + 1 end end
	return string.format("city=%s planet=%s x=%.0f y=%.0f holder=%s side=%s post=%d/3 hails=%s", city, cfg.planet, cfg.x, cfg.y,
		tostring(self:holder(city) or "none"), get(city, "side") ~= "" and get(city, "side") or "none", living, get(city, "hails") ~= "" and get(city, "hails") or "0")
end

-- ---- the hail ---------------------------------------------------------------------------------

local function recentlyHailed(city, oid)
	local now = os.time()
	local kept, hit = {}, false
	for o, t in get(city, "hailed"):gmatch("(%d+)=(%d+)") do
		if now - tonumber(t) < FbCheckpoints.hailAgainAfter then
			kept[#kept + 1] = o .. "=" .. t
			if o == tostring(oid) then hit = true end
		end
	end
	if not hit then kept[#kept + 1] = tostring(oid) .. "=" .. now end
	set(city, "hailed", table.concat(kept, ","))
	return hit
end

-- hail(city, pPlayer): the post deals with one player; returns "enemy" | "friend" | "waved" | "searched" | why not
function FbCheckpoints:hail(city, pPlayer)
	local cfg = self.cities[city]
	if cfg == nil or pPlayer == nil then return "no such city" end
	local side = get(city, "side")
	if side == "" then return "no post" end
	local post = self.posts[side]
	local members = {}
	for _, oid in ipairs(oids(city)) do local p = alive(oid); if p ~= nil then members[#members + 1] = p end end
	if #members == 0 then return "no post" end
	local pOfficer = members[1]
	local c = CreatureObject(pPlayer)
	local playerSide = c:isImperial() and "imperial" or (c:isRebel() and "rebel" or "neutral")
	set(city, "hails", (tonumber(get(city, "hails")) or 0) + 1)
	spatialChat(pOfficer, post.hailLine)
	for _, p in ipairs(members) do SceneObject(p):faceObject(pPlayer, true) end
	if playerSide ~= "neutral" and playerSide ~= side then
		spatialChat(pOfficer, post.enemy)
		for _, p in ipairs(members) do pcall(function() AiAgent(p):setDefender(pPlayer) end) end
		return "enemy"
	end
	if playerSide == side then
		spatialChat(pOfficer, post.friend)
		CreatureObject(pOfficer):doAnimation("bow")
		return "friend"
	end
	if getRandomNumber(1, 100) <= self.searchChance then
		spatialChat(pOfficer, post.search)
		createEvent(4000, "FbCheckpoints", "onSearchDone", pOfficer, city)
		local pGhost = c:getPlayerObject()
		if pGhost ~= nil then PlayerObject(pGhost):decreaseFactionStanding(side, self.standingTilt) end
		return "searched"
	end
	spatialChat(pOfficer, post.wave)
	return "waved"
end

function FbCheckpoints:onSearchDone(pOfficer, city)
	local side = get(city, "side")
	if pOfficer ~= nil and side ~= "" and SceneObject(pOfficer):getZoneName() ~= "" then spatialChat(pOfficer, self.posts[side].clean) end
end

function FbCheckpoints:onTick(pNil, city)
	local cfg = self.cities[city]
	if cfg == nil then return end
	pcall(function()
		if get(city, "side") ~= "" then
			local near = getObjectsInRange(cfg.planet, cfg.x, cfg.y, self.hailRange, PLAYER_TYPE)
			for _, o in ipairs(near or {}) do
				if not recentlyHailed(city, o.oid) then
					local pPlayer = getSceneObject(o.oid)
					if pPlayer ~= nil and not CreatureObject(pPlayer):isDead() then self:hail(city, pPlayer) end
				end
			end
		end
	end)
	createEvent(self.tickSeconds * 1000, "FbCheckpoints", "onTick", nil, city)
end
