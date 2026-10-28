-- fb_scenes.lua — Phase 3.14: street scenes.
--
-- A scene is a data file in screenplays/tasks/scenes/<key>.lua calling FbScenes:add { … }: a cast (stock templates), a
-- spot in a city (from the city data: "plaza", "starport", or {x, y}), a trigger (a player within `radius` m, checked
-- every `tick` s, at most once per `every` s) and a script of beats — say, emote, walk, face, wait — played on the
-- 3.7 ambient-life pattern: the cast is spawned when the scene starts and despawned after the last beat. Nothing
-- plays to an empty street. "{player}" in a line is the first name of the nearest player when the scene started.
--
-- Public for the lab: FbScenes:run(key) starts a scene now (no trigger, no cooldown), :stop(key) despawns it,
-- :status(key) one line, FbScenes.order the keys.

FbScenes = ScreenPlay:new {
	screenplayName = "FbScenes",
	dir = "scripts/screenplays/tasks/scenes",
	scenes = {},
	order = {},
	tickSeconds = 20,             -- how often a scene looks for a player near its spot
	defaultRadius = 30,
	defaultEvery = { 600, 1200 }, -- cooldown after a play, seconds
	beatSeconds = 4,              -- default pause between beats
	linger = 3,                   -- seconds after the last beat before the cast goes
}

function FbScenes:add(s)
	if s == nil or s.key == nil or s.city == nil or s.cast == nil or s.beats == nil then printf("FbScenes: a scene without key/city/cast/beats was ignored\n"); return end
	if self.scenes[s.key] == nil then self.order[#self.order + 1] = s.key end
	self.scenes[s.key] = s
end

-- the scene files
do
	local p = io.popen and io.popen("ls " .. FbScenes.dir .. "/*.lua 2>/dev/null")
	if p ~= nil then
		for line in p:lines() do
			local f = line:match("([^/]+%.lua)$")
			if f ~= nil then includeFile("tasks/scenes/" .. f) end
		end
		p:close()
	end
	table.sort(FbScenes.order)
end

registerScreenPlay("FbScenes", true)

local PLAYER_TYPE = 0x409
local function key(k, what) return "FbScenes." .. k .. "." .. what end
local function get(k, what) return getQuestStatus(key(k, what)) or "" end
local function set(k, what, v) setQuestStatus(key(k, what), tostring(v)) end
local function between(r) return getRandomNumber(r[1], r[2]) end

local function alive(oid)
	oid = tonumber(oid)
	if oid == nil or oid == 0 then return nil end
	local p = getSceneObject(oid)
	if p == nil or SceneObject(p):getZoneName() == "" then return nil end
	if SceneObject(p):isCreatureObject() and CreatureObject(p):isDead() then return nil end
	return p
end

-- where a scene plays: the city's plaza, its starport relay spot, or explicit coordinates; plus the scene's own offset
function FbScenes:spot(s)
	local c = FbCities ~= nil and FbCities:get(s.city) or nil
	if c == nil then return nil end
	local x, y
	if type(s.at) == "table" then x, y = s.at[1], s.at[2]
	elseif s.at == "starport" then
		for _, r in ipairs(c.relays or {}) do if r.key == "starport" then x, y = r.x, r.y end end
		if x == nil and c.starport ~= nil then x, y = c.starport[1], c.starport[2] end
	else
		if c.plaza ~= nil then x, y = c.plaza[1], c.plaza[2] end
	end
	if x == nil then return nil end
	if s.offset ~= nil then x, y = x + s.offset[1], y + s.offset[2] end
	return c.planet, x, y
end

function FbScenes:playersNear(planet, x, y, radius)
	local objects = getObjectsInRange(planet, x, y, radius, PLAYER_TYPE)
	local out = {}
	if objects ~= nil then for _, o in ipairs(objects) do out[#out + 1] = o end end
	return out
end

-- ---- lifecycle --------------------------------------------------------------------------------

function FbScenes:start()
	local n = 0
	for _, k in ipairs(self.order) do
		local s = self.scenes[k]
		local planet = self:spot(s)
		if planet ~= nil and isZoneEnabled(planet) then
			if get(k, "active") == "1" then self:stop(k) end   -- a cast from before the restart no longer exists
			createEvent((self.tickSeconds + getRandomNumber(0, 15)) * 1000, "FbScenes", "onTick", nil, k)
			n = n + 1
		elseif planet == nil then
			printf("FbScenes: %s has no spot (city %s unknown)\n", k, tostring(s.city))
		end
	end
	printf("FbScenes: %d scenes armed\n", n)
end

function FbScenes:onTick(pNil, k)
	local s = self.scenes[k]
	if s == nil then return end
	pcall(function()
		if get(k, "active") ~= "1" and os.time() >= (tonumber(get(k, "next")) or 0) then
			local planet, x, y = self:spot(s)
			if planet ~= nil and #self:playersNear(planet, x, y, s.radius or self.defaultRadius) > 0 then self:run(k) end
		end
	end)
	createEvent(self.tickSeconds * 1000, "FbScenes", "onTick", nil, k)
end

function FbScenes:status(k)
	local s = self.scenes[k]
	if s == nil then return "no such scene" end
	local planet, x, y = self:spot(s)
	local living = 0
	for oid in get(k, "cast"):gmatch("%d+") do if alive(oid) then living = living + 1 end end
	return string.format("scene=%s city=%s planet=%s x=%.0f y=%.0f active=%s beat=%s cast=%d/%d plays=%s next_in=%d",
		k, s.city, tostring(planet), x or 0, y or 0, get(k, "active") == "1" and "1" or "0", get(k, "beat") ~= "" and get(k, "beat") or "0",
		living, #s.cast, get(k, "plays") ~= "" and get(k, "plays") or "0", math.max(0, (tonumber(get(k, "next")) or 0) - os.time()))
end

-- ---- playing ----------------------------------------------------------------------------------

function FbScenes:actor(k, name)
	local i = 0
	for idx, c in ipairs(self.scenes[k].cast) do if c.name == name then i = idx end end
	if i == 0 then return nil end
	local oids = {}
	for oid in get(k, "cast"):gmatch("%d+") do oids[#oids + 1] = oid end
	return alive(oids[i])
end

-- run(k): spawn the cast around the spot and schedule the beats. Returns the status line.
function FbScenes:run(k)
	local s = self.scenes[k]
	if s == nil then return "no such scene" end
	local planet, x, y = self:spot(s)
	if planet == nil then return "no spot" end
	if not isZoneEnabled(planet) then return "zone disabled" end
	if get(k, "active") == "1" then self:stop(k) end
	local playerName = "friend"
	local near = self:playersNear(planet, x, y, (s.radius or self.defaultRadius) + 20)
	if #near > 0 then
		local pPlayer = getSceneObject(near[1].oid)
		if pPlayer ~= nil then playerName = CreatureObject(pPlayer):getFirstName() end
	end
	set(k, "player", playerName)
	local oids = {}
	for i, c in ipairs(s.cast) do
		local ax, ay = x + (c.dx or 0), y + (c.dy or 0)
		local p = spawnMobile(planet, c.template, 0, ax, getTerrainHeightAt(planet, ax, ay), ay, c.dir or getRandomNumber(0, 6), 0)
		if p == nil then printf("FbScenes: %s could not spawn %s\n", k, c.template); oids[#oids + 1] = "0"
		else
			oids[#oids + 1] = tostring(SceneObject(p):getObjectID())
			if not c.walks then AiAgent(p):addObjectFlag(AI_STATIC) end
			if CreatureObject(p):getPvpStatusBitmask() == 0 and not c.walks then CreatureObject(p):clearOptionBit(AIENABLED) end
			if c.mood ~= nil then CreatureObject(p):setMoodString(c.mood) end
		end
	end
	set(k, "cast", table.concat(oids, ","))
	set(k, "active", "1"); set(k, "beat", "0")
	set(k, "plays", (tonumber(get(k, "plays")) or 0) + 1)
	set(k, "next", os.time() + between(s.every or self.defaultEvery))
	createEvent(1500, "FbScenes", "onBeat", nil, k)
	return self:status(k)
end

-- beat(k): play the next beat; returns what it did
function FbScenes:beat(k)
	local s = self.scenes[k]
	if s == nil or get(k, "active") ~= "1" then return "inactive" end
	local i = (tonumber(get(k, "beat")) or 0) + 1
	local b = s.beats[i]
	if b == nil then return "done" end
	set(k, "beat", i)
	local what = "wait"
	if b.say ~= nil then
		local p = self:actor(k, b.say)
		if p ~= nil then
			local text = (b.text or ""):gsub("{player}", get(k, "player"))   -- one value: gsub's count must not reach the binding
			spatialChat(p, text); what = "say:" .. b.say
		end
	elseif b.emote ~= nil then
		local p = self:actor(k, b.emote)
		if p ~= nil then CreatureObject(p):doAnimation(b.anim or "nod_head_once"); what = "emote:" .. b.emote end
	elseif b.walk ~= nil then
		local p = self:actor(k, b.walk)
		local planet, x, y = self:spot(s)
		if p ~= nil and planet ~= nil then
			local tx, ty = x + (b.dx or 0), y + (b.dy or 0)
			AiAgent(p):setNextPosition(tx, getTerrainHeightAt(planet, tx, ty), ty, 0); what = "walk:" .. b.walk
		end
	elseif b.face ~= nil then
		local p, q = self:actor(k, b.face), self:actor(k, b.to or "")
		if p ~= nil and q ~= nil then SceneObject(p):faceObject(q, true); what = "face:" .. b.face end
	elseif b.leave ~= nil then
		local p = self:actor(k, b.leave)
		if p ~= nil then SceneObject(p):destroyObjectFromWorld(true); what = "leave:" .. b.leave end
	end
	return what
end

function FbScenes:onBeat(pNil, k)
	local ok, what = pcall(function() return self:beat(k) end)
	if not ok then printf("FbScenes: %s beat error %s\n", k, tostring(what)); self:stop(k); return end
	if what == "done" then
		createEvent(self.linger * 1000, "FbScenes", "onEnd", nil, k)
	elseif what ~= "inactive" then
		local s = self.scenes[k]
		local i = tonumber(get(k, "beat")) or 1
		local pause = (s.beats[i] and s.beats[i].pause) or (s.beats[i] and s.beats[i].wait) or self.beatSeconds
		createEvent(pause * 1000, "FbScenes", "onBeat", nil, k)
	end
end

function FbScenes:onEnd(pNil, k) pcall(function() self:stop(k) end) end

function FbScenes:stop(k)
	if self.scenes[k] == nil then return "no such scene" end
	for oid in get(k, "cast"):gmatch("%d+") do
		local p = getSceneObject(tonumber(oid))
		if p ~= nil then SceneObject(p):destroyObjectFromWorld(true) end
	end
	set(k, "cast", ""); set(k, "active", "0"); set(k, "beat", "0")
	return self:status(k)
end
