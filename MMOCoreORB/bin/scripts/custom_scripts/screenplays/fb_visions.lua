-- fb_visions.lua — Phase 4a.4: Force visions.
--
-- At the milestones of the Force-sensitive path a character is taken out of the world for a minute: the ground
-- falls away, two figures stand in a grey nowhere and speak, and the world comes back where it was left.
-- The figures are canon Force users — Obi-Wan Kenobi, Luke Skywalker, Darth Vader, Exar Kun — and they appear
-- here and nowhere else: the vision ground is the dungeon1 zone (the flat empty plane the Corellian Corvette
-- instances float in), far from the ships, one slot per character so two dreamers never see each other.
--
-- Which figures come depends on the alignment: before the mercy trial one of each side; after it both figures of
-- the chosen side, and the other side gets one whispered line. Yoda has no model in this client and is only ever
-- spoken of.
--
-- Visions are due by state, never by a timer: FbAttunement:maybeVisit asks FbVisions:maybe(pPlayer) at every
-- attunement trigger (a kill, a shrine, a badge), after the Old Man's return and the hunters and before a trial
-- acts. Milestones: `calling` (the Old Man's task accepted), `worlds` (three worlds listened to), `return` (the
-- trials unlocked), `mercy` / `duel` (those trials begun, before their visitor comes), `padawan` (the box).
--
-- State: screenplay data "FbVisions" — `seen` (comma list), `active` (vision id while away), `home`
-- (zone;x;z;y to return to; the login hook brings a character home that logged out inside a vision), `gen`
-- (the running vision's stamp: a stale event is ignored). Per-object visitor notes go through writeData.
--
-- Lab: FbLabTests visions / visionBegin / visionEnd / visionsReset / attunementFlag, checkVisions; scenario `visions`.

local SpawnMobiles = require("utils.spawn_mobiles")

FbVisions = {
	DATA = "FbVisions",
	zone = "dungeon1",
	-- the vision ground: a slot per character on a line in the quadrant opposite the corvette instances (those
	-- float at x 1250–2700, y 600–1900); the flat plane has z = 0 everywhere
	groundX = -1500, groundY = -1500, slotStep = 80, slots = 12,
	lineGap = 6000,     -- ms between lines
	fadeDelay = 5000,   -- ms after the last line
	-- the figures: template → side
	figures = {
		kenobi = { template = "fb_vision_kenobi", side = "light" },
		luke = { template = "fb_vision_luke", side = "light" },
		vader = { template = "fb_vision_vader", side = "dark" },
		exar_kun = { template = "fb_vision_exar_kun", side = "dark" },
	},
	-- the visions in path order: who comes before the alignment is set, and how many lines each speaks
	list = {
		{ id = "calling", light = "kenobi", dark = "vader", lines = 3 },
		{ id = "worlds", light = "luke", dark = "exar_kun", lines = 3 },
		{ id = "return", light = "kenobi", dark = "vader", lines = 3 },
		{ id = "mercy", light = "kenobi", dark = "vader", lines = 3 },
		{ id = "duel", light = "luke", dark = "exar_kun", lines = 3 },
		{ id = "padawan", light = "kenobi", dark = "vader", lines = 3 },
	},
}

-- ---------------------------------------------------------------- state

function FbVisions:get(pPlayer, k) local v = readScreenPlayData(pPlayer, self.DATA, k); if v == nil or v == "" then return nil end; return v end
function FbVisions:set(pPlayer, k, v) writeScreenPlayData(pPlayer, self.DATA, k, tostring(v)) end
function FbVisions:clear(pPlayer, k) deleteScreenPlayData(pPlayer, self.DATA, k) end
function FbVisions:byId(id) for _, v in ipairs(self.list) do if v.id == id then return v end end return nil end
function FbVisions:seen(pPlayer, id) local s = self:get(pPlayer, "seen") or ""; return s:find(id, 1, true) ~= nil end
function FbVisions:seenList(pPlayer) return self:get(pPlayer, "seen") or "" end
function FbVisions:markSeen(pPlayer, id)
	if self:seen(pPlayer, id) then return end
	local s = self:get(pPlayer, "seen")
	self:set(pPlayer, "seen", s == nil and id or (s .. "," .. id))
end
function FbVisions:active(pPlayer) return self:get(pPlayer, "active") end

-- the lab's shortcuts past the real path (attunementAccept, trialsUnlock) mark every vision as seen so the
-- scenarios of the visits and the trials keep their trigger order; the visions scenario resets them
function FbVisions:skipAll(pPlayer)
	local ids = {}
	for _, v in ipairs(self.list) do ids[#ids + 1] = v.id end
	self:set(pPlayer, "seen", table.concat(ids, ","))
end
function FbVisions:reset(pPlayer)
	if self:active(pPlayer) ~= nil then self:finish(pPlayer, true) end
	for _, k in ipairs({ "seen", "active", "home", "gen", "line", "cast" }) do self:clear(pPlayer, k) end
end

-- ---------------------------------------------------------------- what is due

-- the first vision due for this character by the path's state, or nil
function FbVisions:due(pPlayer)
	if FbAttunement == nil then return nil end
	local flag = function(n) return FbAttunement:flag(pPlayer, n) end
	local current = (FbTrials ~= nil and FbTrials.current ~= nil) and FbTrials:current(pPlayer) or nil
	local eligible = {
		calling = flag("called") ~= nil,
		worlds = flag("called") ~= nil and FbAttunement:worldCount(pPlayer) >= 3,
		["return"] = flag("trials") ~= nil,
		mercy = current == "mercy",
		duel = current == "duel",
		padawan = flag("padawan") ~= nil,
	}
	for _, v in ipairs(self.list) do
		if eligible[v.id] and not self:seen(pPlayer, v.id) then return v.id end
	end
	return nil
end

-- the attunement trigger: begin the due vision if the character can leave the world right now
function FbVisions:maybe(pPlayer)
	if pPlayer == nil then return false end
	if self:active(pPlayer) ~= nil then return false end
	local id = self:due(pPlayer)
	if id == nil then return false end
	if not self:canLeave(pPlayer) then return false end
	return self:begin(pPlayer, id)
end

function FbVisions:canLeave(pPlayer)
	local c = CreatureObject(pPlayer)
	if c:isInCombat() or c:isDead() or c:isIncapacitated() or c:isRidingMount() then return false end
	local so = SceneObject(pPlayer)
	if so:getParentID() ~= 0 then return false end           -- outdoors only: the way back is a world position
	if so:getZoneName() == self.zone or so:getZoneName() == "" then return false end
	return true
end

-- ---------------------------------------------------------------- the vision itself

local function say(pPlayer, id) CreatureObject(pPlayer):sendSystemMessage("@fb_force:" .. id) end

-- which two figures speak, and who whispers: {first, second, whisper-or-nil}
function FbVisions:cast(pPlayer, v)
	local a = FbAttunement ~= nil and FbAttunement:flag(pPlayer, "alignment") or nil
	if a == "light" then return "kenobi", "luke", v.dark
	elseif a == "dark" then return "vader", "exar_kun", v.light
	else return v.light, v.dark, nil end
end

function FbVisions:slot(pPlayer)
	local n = SceneObject(pPlayer):getObjectID() % self.slots
	return self.groundX + n * self.slotStep, self.groundY
end

-- begin: remember home, go, spawn the figures, start the lines
function FbVisions:begin(pPlayer, id)
	if pPlayer == nil then return false end
	local v = self:byId(id)
	if v == nil then return false end
	if self:active(pPlayer) ~= nil then return false end
	local so = SceneObject(pPlayer)
	if so:getParentID() ~= 0 or so:getZoneName() == "" or so:getZoneName() == self.zone then return false end
	local gen = getRandomNumber(1000000)
	self:set(pPlayer, "home", string.format("%s;%.2f;%.2f;%.2f", so:getZoneName(), so:getWorldPositionX(), so:getWorldPositionZ(), so:getWorldPositionY()))
	self:set(pPlayer, "active", id)
	self:set(pPlayer, "gen", gen)
	self:set(pPlayer, "line", 0)
	if FbAttunement ~= nil then setQuestStatus("FbAttunement.visit." .. so:getObjectID(), tostring(os.time())) end   -- one thing at a time
	say(pPlayer, "vision_enter")
	printf("FbVisions: %s enters the vision '%s'\n", CreatureObject(pPlayer):getFirstName(), id)
	createEvent(1500, "FbVisions", "arrive", pPlayer, tostring(gen))
	return true
end

function FbVisions:stale(pPlayer, args)
	return pPlayer == nil or self:active(pPlayer) == nil or tostring(self:get(pPlayer, "gen")) ~= tostring(args)
end

function FbVisions:arrive(pPlayer, args)
	if self:stale(pPlayer, args) then return end
	local x, y = self:slot(pPlayer)
	SceneObject(pPlayer):switchZone(self.zone, x, 0, y, 0)
	createEvent(2500, "FbVisions", "appear", pPlayer, args)   -- the client needs the scene before the figures
end

local function faceEachOther(pNpc, pPlayer)
	if pNpc ~= nil and pPlayer ~= nil then SceneObject(pNpc):faceObject(pPlayer, true) end
end

function FbVisions:appear(pPlayer, args)
	if self:stale(pPlayer, args) then return end
	local v = self:byId(self:active(pPlayer))
	if v == nil then return end
	local first, second = self:cast(pPlayer, v)
	local so = SceneObject(pPlayer)
	local px, py = so:getWorldPositionX(), so:getWorldPositionY()
	local oid = so:getObjectID()
	local spots = { { px - 2.2, py + 4 }, { px + 2.2, py + 4 } }
	for i, key in ipairs({ first, second }) do
		local f = self.figures[key]
		local pNpc = spawnMobile(self.zone, f.template, 0, spots[i][1], 0, spots[i][2], 0, 0)
		if pNpc ~= nil then
			local n = SceneObject(pNpc)
			AiAgent(pNpc):addObjectFlag(AI_STATIC)
			CreatureObject(pNpc):clearOptionBit(AIENABLED)
			faceEachOther(pNpc, pPlayer)
			writeData(oid .. ":fbVisionFigure:" .. i, n:getObjectID())
			writeData(n:getObjectID() .. ":fbVisionFor", oid)
			if FbLabTests ~= nil and FbLabTests.registryAdd ~= nil then
				FbLabTests.registryAdd({ oid = n:getObjectID(), zone = self.zone, cell = 0, x = spots[i][1], y = spots[i][2], z = 0, template = f.template, src = "fb_visions", name = n:getObjectName() })
			end
			-- the figure sweeps itself if the dreamer never wakes (server hiccup, logout); by oid, the pointer may be dead
			createEvent(180000, "FbVisions", "sweepFigure", pPlayer, tostring(n:getObjectID()))   -- keyed to the dreamer: a nil object never fires
		end
	end
	-- writeData holds numbers only (a string reads back as 0): the cast goes into the screenplay data
	self:set(pPlayer, "cast", first .. "," .. second)
	createEvent(2000, "FbVisions", "speak", pPlayer, args)
end

-- the lines alternate: first 1, second 1, first 2, second 2, …; then the whisper; then the fade
function FbVisions:speak(pPlayer, args)
	if self:stale(pPlayer, args) then return end
	local v = self:byId(self:active(pPlayer))
	if v == nil then return end
	local oid = SceneObject(pPlayer):getObjectID()
	local cast = tostring(self:get(pPlayer, "cast") or "")
	local first, second = cast:match("^([%w_]+),([%w_]+)$")
	if first == nil then self:fade(pPlayer, args); return end
	local n = tonumber(self:get(pPlayer, "line") or 0) or 0
	local total = v.lines * 2
	if n < total then
		local speakerIdx = (n % 2) + 1
		local lineNo = math.floor(n / 2) + 1
		local who = speakerIdx == 1 and first or second
		local pNpc = getSceneObject(readData(oid .. ":fbVisionFigure:" .. speakerIdx))
		if pNpc ~= nil then spatialChat(pNpc, "@fb_force:vision_" .. v.id .. "_" .. who .. "_" .. lineNo) end
		self:set(pPlayer, "line", n + 1)
		createEvent(self.lineGap, "FbVisions", "speak", pPlayer, args)
		return
	end
	if n == total then
		-- after the alignment is set the other side gets one line, from nowhere
		local _, _, whisper = self:cast(pPlayer, v)
		self:set(pPlayer, "line", n + 1)
		if whisper ~= nil then
			CreatureObject(pPlayer):sendSystemMessage("@fb_force:vision_" .. v.id .. "_" .. whisper .. "_whisper")
			createEvent(self.lineGap, "FbVisions", "speak", pPlayer, args)
			return
		end
	end
	createEvent(self.fadeDelay, "FbVisions", "fade", pPlayer, args)
end

function FbVisions:fade(pPlayer, args)
	if self:stale(pPlayer, args) then return end
	say(pPlayer, "vision_fade")
	self:finish(pPlayer, false)
end

-- back to the world: figures gone, home position restored, the vision marked seen (unless aborted)
function FbVisions:finish(pPlayer, aborted)
	if pPlayer == nil then return end
	local id = self:active(pPlayer)
	-- plain values first: sweeping a figure wraps another object in the one shared SceneObject wrapper
	local oid, here = SceneObject(pPlayer):getObjectID(), SceneObject(pPlayer):getZoneName()
	for i = 1, 2 do
		local foid = readData(oid .. ":fbVisionFigure:" .. i)
		if foid ~= nil and foid ~= 0 then
			FbVisions:sweepFigure(nil, tostring(foid))
			deleteData(oid .. ":fbVisionFigure:" .. i)
		end
	end
	local home = self:get(pPlayer, "home")
	if home ~= nil then
		local zone, x, z, y = home:match("^([^;]+);([^;]+);([^;]+);([^;]+)$")
		if zone ~= nil and here == self.zone then SceneObject(pPlayer):switchZone(zone, tonumber(x), tonumber(z), tonumber(y), 0) end
	end
	if id ~= nil and not aborted then self:markSeen(pPlayer, id) end
	for _, k in ipairs({ "active", "home", "gen", "line", "cast" }) do self:clear(pPlayer, k) end
	if FbAttunement ~= nil then removeQuestStatus("FbAttunement.visit." .. oid) end
	if id ~= nil then printf("FbVisions: %s %s the vision '%s'\n", CreatureObject(pPlayer):getFirstName(), aborted and "leaves" or "wakes from", id) end
end

-- sweepFigure(nil, "<oid>"): an event's object pointer may be dead by the time it fires (a swept figure panicked
-- the Lua state the first time), so the figure is looked up by its id
function FbVisions:sweepFigure(pObj, args)   -- called as play:fn(pObject, args): self first
	local oid = tonumber(args)
	if oid == nil or oid == 0 then return end
	local pNpc = getSceneObject(oid)
	if pNpc == nil then return end
	local so = SceneObject(pNpc)
	if so:getZoneName() == "" then return end
	deleteData(oid .. ":fbVisionFor")
	so:destroyObjectFromWorld(true)
	so:destroyObjectFromDatabase()
	if FbLabTests ~= nil and FbLabTests.registryRemove ~= nil then FbLabTests.registryRemove(oid) end
end

-- a character who logged out inside a vision wakes at home (called from FbAttunement:onLogin)
function FbVisions:onLogin(pPlayer)
	if pPlayer == nil or self:active(pPlayer) == nil then return end
	printf("FbVisions: %s logged in inside a vision; sent home\n", CreatureObject(pPlayer):getFirstName())
	self:finish(pPlayer, true)
end

-- one status line (the lab's oracle and the Lab Remote read it)
function FbVisions:status(pPlayer)
	return string.format("seen=%s due=%s active=%s", self:seenList(pPlayer) ~= "" and self:seenList(pPlayer) or "-", tostring(self:due(pPlayer) or "-"), tostring(self:active(pPlayer) or "-"))
end
