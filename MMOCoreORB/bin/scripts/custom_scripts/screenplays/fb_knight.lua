-- fb_knight.lua — Phase 4b.4: the Knight trial.
--
-- After the Master's last rank task the Master offers the trial: one hard place per side, a named enemy at its
-- end spawned for this student alone, and a token to bring back. Light: the crystal hunters' cave on Dantooine
-- (stock building 8535482, entrance −6228 7380), the chief Teshan Vorr in its deepest room (r9), a light holocron.
-- Dark: the Nightsister stronghold on Dathomir (outdoors, −4052 −161), the elder Ishara Kell on the open ground
-- inside the walls, a dark holocron. The enemy yields when beaten below a quarter of its health (a damage observer
-- turns it harmless and conversable); the student then spares or finishes it — the choice moves the alignment
-- score, the token comes either way. Beaten outright, it drops the token too. The report to the Master is the
-- graduation: the Knight title box (`force_title_jedi_rank_03`), the Jedi state of the side (4 light, 8 dark: what
-- the client and the stock systems read as Knight), rank 3 of the ladder and its box, the side's robe, the music.
-- Nothing is timed; a student who falls simply tries again, the enemy is respawned when needed.
--
-- State: screenplay data "FbKnight" — `state` (nil / given / token / done), `choice` (spare / kill), `boss` (oid).
-- Per-boss notes through writeData (`<bossOid>:fbKnightFor` = the student, `:fbKnightYielded`).
--
-- Lab: FbLabTests knight / knightGive / knightBossHere / knightYield / knightChoose / knightGraduate, checkKnight;
-- scenario `knight-trial`.

FbKnight = {
	DATA = "FbKnight",
	yieldAt = 0.25,
	bossLifetime = 30 * 60 * 1000,
	sides = {
		light = {
			zone = "dantooine", entrance = { x = -6228, y = 7380, name = "The crystal hunters' cave" },
			buildingOid = 8535482, room = "r9", x = 178.0, z = -66.2, y = -102.0, heading = 90,   -- the cave's deepest room
			boss = "fb_hunter_chief", token = "object/tangible/jedi/no_drop_jedi_holocron_light.iff",
			robe = "object/tangible/wearables/robe/robe_jedi_light_s01.iff", music = "sound/music_become_light_jedi.snd", jediState = 4,
		},
		dark = {
			zone = "dathomir", entrance = { x = -4052, y = -161, name = "The Nightsister stronghold" },
			buildingOid = nil, x = -4040.0, z = nil, y = -100.0, heading = 0,   -- open ground inside the walls; z from the terrain
			boss = "fb_nightsister_witch", token = "object/tangible/jedi/no_drop_jedi_holocron_dark.iff",
			robe = "object/tangible/wearables/robe/robe_jedi_dark_s01.iff", music = "sound/music_become_dark_jedi.snd", jediState = 8,
		},
	},
}

-- ---------------------------------------------------------------- state

function FbKnight:get(pPlayer, k) local v = readScreenPlayData(pPlayer, self.DATA, k); if v == nil or v == "" then return nil end; return v end
function FbKnight:set(pPlayer, k, v) writeScreenPlayData(pPlayer, self.DATA, k, tostring(v)) end
function FbKnight:clear(pPlayer, k) deleteScreenPlayData(pPlayer, self.DATA, k) end
function FbKnight:state(pPlayer) return self:get(pPlayer, "state") end
function FbKnight:isKnight(pPlayer) return self:state(pPlayer) == "done" end

function FbKnight:side(pPlayer)
	local m = FbMasters ~= nil and FbMasters.of(pPlayer) or nil
	return m and m.side or nil, m
end

function FbKnight:reset(pPlayer)
	self:despawnBoss(pPlayer)
	for _, k in ipairs({ "state", "choice", "boss" }) do self:clear(pPlayer, k) end
end

-- the Master's task list is done: the trial is what comes next
function FbKnight:eligible(pPlayer, m)
	if pPlayer == nil or m == nil or not m:isStudent(pPlayer) then return false end
	local t = m:currentTask(pPlayer)
	return t == nil
end

-- the screen the Master opens with once the tasks are done (nil = nothing of the trial's)
function FbKnight:screenFor(pPlayer, m)
	if not self:eligible(pPlayer, m) then return nil end
	local s = self:state(pPlayer)
	if s == nil then return "knight_offer" end
	if s == "given" then self:ensureBoss(pPlayer); return "knight_wait" end
	if s == "token" then return "knight_report" end
	return nil   -- done: the ladder's end for now
end

local function say(pPlayer, m, id) CreatureObject(pPlayer):sendSystemMessage("@fb_force:" .. m.prefix .. id) end
local function waypointTo(pPlayer, planet, x, y, label)
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost == nil then return end
	PlayerObject(pGhost):addWaypoint(planet, label, "", x, getTerrainHeightAt(planet, x, y), y, 1, true, true, 0)
end

-- ---------------------------------------------------------------- the trial given

function FbKnight:give(pPlayer)
	local side, m = self:side(pPlayer)
	if side == nil or not self:eligible(pPlayer, m) or self:state(pPlayer) ~= nil then return false end
	local d = self.sides[side]
	self:set(pPlayer, "state", "given")
	FbAttunement:setFlag(pPlayer, "task", "knight")
	waypointTo(pPlayer, d.zone, d.entrance.x, d.entrance.y, d.entrance.name)
	say(pPlayer, m, "knight_given")
	self:ensureBoss(pPlayer)
	printf("FbKnight: %s is sent on the %s trial\n", CreatureObject(pPlayer):getFirstName(), side)
	return true
end

function FbKnight:bossOf(pPlayer)
	local oid = tonumber(self:get(pPlayer, "boss") or 0) or 0
	if oid == 0 then return nil end
	local p = getSceneObject(oid)
	if p == nil or SceneObject(p):getZoneName() == "" or CreatureObject(p):isDead() then return nil end
	return p
end

-- the enemy stands at the end of the place, for this student, until beaten or swept
function FbKnight:ensureBoss(pPlayer)
	if pPlayer == nil or self:state(pPlayer) ~= "given" then return nil end
	local pBoss = self:bossOf(pPlayer)
	if pBoss ~= nil then return pBoss end
	local side = self:side(pPlayer)
	if side == nil then return nil end
	local d = self.sides[side]
	if not isZoneEnabled(d.zone) then return nil end
	local cell = 0
	if d.buildingOid ~= nil then
		local pBuilding = getSceneObject(d.buildingOid)
		if pBuilding == nil then printf("FbKnight: the %s trial's place (%d) is missing\n", side, d.buildingOid); return nil end
		local pCell = BuildingObject(pBuilding):getNamedCell(d.room)
		if pCell == nil then printf("FbKnight: no room %s in %d\n", d.room, d.buildingOid); return nil end
		cell = SceneObject(pCell):getObjectID()
	end
	local z = d.z or getTerrainHeightAt(d.zone, d.x, d.y)
	return self:spawnBossAt(pPlayer, d, d.zone, d.x, z, d.y, d.heading, cell)
end

function FbKnight:spawnBossAt(pPlayer, d, zone, x, z, y, heading, cell)
	local pBoss = spawnMobile(zone, d.boss, 0, x, z, y, math.rad(heading or 0), cell)
	if pBoss == nil then printf("FbKnight: spawnMobile %s failed\n", d.boss); return nil end
	local oid = SceneObject(pBoss):getObjectID()
	self:set(pPlayer, "boss", oid)
	writeData(oid .. ":fbKnightFor", SceneObject(pPlayer):getObjectID())
	createObserver(DAMAGERECEIVED, "FbKnight", "onBossHit", pBoss)
	createObserver(OBJECTDESTRUCTION, "FbKnight", "onBossDown", pBoss)
	-- keyed to the student: an event with no object never fires (DirectorManager::createEvent), and the enemy's own
	-- pointer may be dead by then
	createEvent(self.bossLifetime, "FbKnight", "sweepBoss", pPlayer, tostring(oid))
	if FbLabTests ~= nil and FbLabTests.registryAdd ~= nil then
		FbLabTests.registryAdd({ oid = oid, zone = zone, cell = cell, x = x, y = y, z = z, template = d.boss, src = "fb_knight", name = SceneObject(pBoss):getObjectName() })
	end
	return pBoss
end

function FbKnight:despawnBoss(pPlayer)
	local oid = tonumber(self:get(pPlayer, "boss") or 0) or 0
	if oid ~= 0 then FbKnight:sweepBoss(nil, tostring(oid)) end
	self:clear(pPlayer, "boss")
end

-- an event handler is called as play:fn(pObject, args) — self first; a dot-defined handler would read the object as args
function FbKnight:sweepBoss(pObj, args)
	local oid = tonumber(args)
	if oid == nil or oid == 0 then return end
	local p = getSceneObject(oid)
	if p == nil then return end
	deleteData(oid .. ":fbKnightFor"); deleteData(oid .. ":fbKnightYielded")
	if SceneObject(p):getZoneName() ~= "" then
		SceneObject(p):destroyObjectFromWorld(true)
		SceneObject(p):destroyObjectFromDatabase()
	end
	if FbLabTests ~= nil and FbLabTests.registryRemove ~= nil then FbLabTests.registryRemove(oid) end
end

-- ---------------------------------------------------------------- the fight, the yield, the choice

function FbKnight:ownerOf(pBoss)
	local oid = tonumber(readData(SceneObject(pBoss):getObjectID() .. ":fbKnightFor") or 0) or 0
	if oid == 0 then return nil end
	return getSceneObject(oid)
end

-- the damage observer: below a quarter of its health the enemy stops, becomes harmless and talks
function FbKnight:onBossHit(pBoss, pAttacker, damage)
	if pBoss == nil then return 1 end
	local c = CreatureObject(pBoss)
	if c:isDead() or readData(SceneObject(pBoss):getObjectID() .. ":fbKnightYielded") == 1 then return 1 end
	if c:getHAM(0) > c:getMaxHAM(0) * self.yieldAt then return 0 end
	self:yield(pBoss)
	return 1
end

function FbKnight:yield(pBoss)
	if pBoss == nil then return false end
	local oid = SceneObject(pBoss):getObjectID()
	writeData(oid .. ":fbKnightYielded", 1)
	CreatureObject(pBoss):clearCombatState(true)
	CreatureObject(pBoss):setPvpStatusBitmask(0)
	AiAgent(pBoss):addObjectFlag(AI_STATIC)
	CreatureObject(pBoss):clearOptionBit(AIENABLED)
	CreatureObject(pBoss):setOptionBit(CONVERSABLE)
	local pPlayer = self:ownerOf(pBoss)
	if pPlayer ~= nil then
		CreatureObject(pPlayer):clearCombatState(true)
		local side = self:side(pPlayer)
		spatialChat(pBoss, "@fb_force:knight_" .. tostring(side) .. "_yield")
		printf("FbKnight: the %s enemy yields to %s\n", tostring(side), CreatureObject(pPlayer):getFirstName())
	end
	return true
end

function FbKnight:yielded(pBoss) return pBoss ~= nil and readData(SceneObject(pBoss):getObjectID() .. ":fbKnightYielded") == 1 end
function FbKnight:belongsTo(pPlayer, pBoss)
	if pPlayer == nil or pBoss == nil then return false end
	return tonumber(readData(SceneObject(pBoss):getObjectID() .. ":fbKnightFor")) == SceneObject(pPlayer):getObjectID()
end

-- the token into the student's hands and the state forward
function FbKnight:award(pPlayer, choice)
	local side, m = self:side(pPlayer)
	if side == nil or self:state(pPlayer) ~= "given" then return false end
	local d = self.sides[side]
	local pInventory = SceneObject(pPlayer):getSlottedObject("inventory")
	if pInventory ~= nil then giveItem(pInventory, d.token, -1) end
	self:set(pPlayer, "state", "token")
	self:set(pPlayer, "choice", choice)
	self:clear(pPlayer, "boss")
	if FbAlignment ~= nil then FbAlignment:shift(pPlayer, choice == "spare" and 5 or -5, "knight:" .. choice) end
	say(pPlayer, m, "knight_" .. choice)
	printf("FbKnight: %s %s the %s enemy and holds the token\n", CreatureObject(pPlayer):getFirstName(), choice == "spare" and "spares" or "finishes", side)
	return true
end

-- spared: the enemy walks away (despawns a moment after the talk)
function FbKnight:spare(pPlayer, pBoss)
	if not self:belongsTo(pPlayer, pBoss) or not self:yielded(pBoss) then return false end
	local oid = SceneObject(pBoss):getObjectID()
	if self:award(pPlayer, "spare") then createEvent(4000, "FbKnight", "sweepBoss", pPlayer, tostring(oid)) end
	return true
end

-- finished: the enemy dies where it kneels
function FbKnight:execute(pPlayer, pBoss)
	if not self:belongsTo(pPlayer, pBoss) or not self:yielded(pBoss) then return false end
	local oid = SceneObject(pBoss):getObjectID()
	if self:award(pPlayer, "kill") then createEvent(1500, "FbKnight", "sweepBoss", pPlayer, tostring(oid)) end
	return true
end

-- beaten outright (never yielded): the token drops the same way, as a kill
function FbKnight:onBossDown(pBoss, pKiller)
	if pBoss == nil or self:yielded(pBoss) then return 1 end
	local pPlayer = self:ownerOf(pBoss)
	if pPlayer ~= nil and self:state(pPlayer) == "given" then self:award(pPlayer, "kill") end
	return 1
end

-- ---------------------------------------------------------------- the report: the graduation

function FbKnight:graduate(pPlayer)
	local side, m = self:side(pPlayer)
	if side == nil or self:state(pPlayer) ~= "token" then return false end
	local d = self.sides[side]
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if not CreatureObject(pPlayer):hasSkill("force_title_jedi_rank_03") then awardSkillUnchecked(pPlayer, "force_title_jedi_rank_03") end
	if pGhost ~= nil then PlayerObject(pGhost):setJediState(d.jediState) end
	m:promote(pPlayer, 3)
	local pInventory = SceneObject(pPlayer):getSlottedObject("inventory")
	if pInventory ~= nil then
		-- the holocron is handed over (it would also keep counting as an attunement item)
		for i = SceneObject(pInventory):getContainerObjectsSize() - 1, 0, -1 do
			local pItem = SceneObject(pInventory):getContainerObject(i)
			if pItem ~= nil and SceneObject(pItem):getTemplateObjectPath() == d.token then
				SceneObject(pItem):destroyObjectFromWorld(true)
				SceneObject(pItem):destroyObjectFromDatabase()
			end
		end
		giveItem(pInventory, d.robe, -1)
	end
	CreatureObject(pPlayer):playMusicMessage(d.music)
	self:set(pPlayer, "state", "done")
	FbAttunement:setFlag(pPlayer, "task", "knight_done")
	FbAttunement:setFlag(pPlayer, "knight", os.time())
	say(pPlayer, m, "knight_graduated")
	printf("FbKnight: %s is a Knight of the %s\n", CreatureObject(pPlayer):getFirstName(), side)
	return true
end

-- a login while the trial is on puts the enemy back if it was swept
function FbKnight:onLogin(pPlayer)
	if pPlayer ~= nil and self:state(pPlayer) == "given" then self:ensureBoss(pPlayer) end
end

function FbKnight:status(pPlayer)
	local side = self:side(pPlayer)
	local pBoss = self:bossOf(pPlayer)
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	return string.format("side=%s state=%s choice=%s boss=%s yielded=%s knightTitle=%s jediState=%s",
		tostring(side or "-"), tostring(self:state(pPlayer) or "-"), tostring(self:get(pPlayer, "choice") or "-"),
		pBoss and tostring(SceneObject(pBoss):getObjectID()) or "-", tostring(pBoss ~= nil and self:yielded(pBoss)),
		tostring(CreatureObject(pPlayer):hasSkill("force_title_jedi_rank_03")), pGhost and tostring(PlayerObject(pGhost):getJediState()) or "-")
end
