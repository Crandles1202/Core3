-- fb_masters.lua — Phase 4b.1 / 4b.2: the two Masters.
--
-- Master Ilara Venn (light) teaches in the training room of the Light Jedi Enclave on Yavin 4 (stock building
-- 8525417, entrance −5575 4910); Darth Ysanne Vhal (dark) waits in the chamber at the far end of the Dark Jedi
-- Enclave (3435626, entrance 5068 310). A Padawan — the Padawan box from the trials (flag `padawan`) — who speaks
-- to the Master of their alignment is taken as a student: enrolled on that side of the rank ladder (FRS council
-- light = 1 / dark = 2, the `force_rank_<side>_novice` box; the visible ladder of the Phase 4 decisions) and given
-- the first training task. Each task is reported back in conversation and pays Jedi experience; after the last
-- the Master waits for the rank quests of 4b.3. A Padawan of the other alignment is pointed at the other door
-- (an unset alignment counts as light); anyone else the Masters do not know. One student, one Master: the side is
-- the FbAttunement flag `master`.
--
-- Training tasks are data per Master (in order). `sit`: sit or meditate N seconds in the Master's own room (a
-- poll every 5 s); `kill`: N kills matching a template fragment through the attunement kill hook ("" = any).
-- State per student is screenplay data named after the Master: `step` (index of the current task), `told:<id>`
-- (the task was given), `ready:<id>` (done, not yet reported), `done` (comma list), `sat`, `prog`.
--
-- 4b.3: the task list continues with the *rank* tasks (`rank = N, xp = …`): once the training is done, each rank of
-- the ladder is a quest from the Master, offered when the character's Jedi experience has reached the rank's
-- threshold; reporting it is the promotion (FRS rank N, the `force_rank_<side>_rank_0N` box). Every task also
-- carries an alignment shift (`align`). A student of the other Master whose score leans this way is offered the
-- turn (`FbMasterBase:turn`: the old side's rank boxes are surrendered, the new side starts at the novice).
--
-- Lab: FbLabTests jediMaster / sithMaster / jediMasterTake / sithMasterTake / masterTurn / trainingSet /
-- trainingTick, checkJediMaster / checkSithMaster; scenarios `jedi-master`, `sith-master`, `ranks-alignment`.

local SITTING = 8   -- CreaturePosture::SITTING (see fb_attunement)

FbMasterBase = {}
FbMasterBase.__index = FbMasterBase
function FbMasterBase:new(o) o = o or {}; setmetatable(o, self); return o end

-- ---------------------------------------------------------------- state

function FbMasterBase:get(pPlayer, k) local v = readScreenPlayData(pPlayer, self.DATA, k); if v == nil or v == "" then return nil end; return v end
function FbMasterBase:set(pPlayer, k, v) writeScreenPlayData(pPlayer, self.DATA, k, tostring(v)) end
function FbMasterBase:clear(pPlayer, k) deleteScreenPlayData(pPlayer, self.DATA, k) end
function FbMasterBase:isDone(pPlayer, id) local d = self:get(pPlayer, "done") or ""; return d:find(id, 1, true) ~= nil end
function FbMasterBase:currentTask(pPlayer)
	local step = tonumber(self:get(pPlayer, "step") or 0) or 0
	return self.tasks[step], step
end
function FbMasterBase:isStudent(pPlayer) return FbAttunement ~= nil and FbAttunement:flag(pPlayer, "master") == self.side end
function FbMasterBase:isPadawan(pPlayer) return FbAttunement ~= nil and FbAttunement:flag(pPlayer, "padawan") ~= nil end
function FbMasterBase:alignment(pPlayer)
	local a = FbAttunement ~= nil and FbAttunement:flag(pPlayer, "alignment") or nil
	return a == "dark" and "dark" or "light"   -- unset counts as light
end

function FbMasterBase:reset(pPlayer)
	for _, k in ipairs({ "step", "done", "sat", "prog" }) do self:clear(pPlayer, k) end
	for _, t in ipairs(self.tasks) do self:clear(pPlayer, "told:" .. t.id); self:clear(pPlayer, "ready:" .. t.id) end
	removeQuestStatus(self.name .. ".sit." .. SceneObject(pPlayer):getObjectID())
end

-- ---------------------------------------------------------------- the Master in the enclave

function FbMasterBase:cell()
	local pBuilding = getSceneObject(self.buildingOid)
	if pBuilding == nil then return nil end
	return BuildingObject(pBuilding):getNamedCell(self.room)
end

function FbMasterBase:spawn()
	if not isZoneEnabled(self.zone) then return nil end
	local pCell = self:cell()
	if pCell == nil then printf("%s: the enclave (%d) or its %s is missing; no Master\n", self.name, self.buildingOid, self.room); return nil end
	local pNpc = spawnMobile(self.zone, self.template, 0, self.x, self.z, self.y, math.rad(self.heading), SceneObject(pCell):getObjectID())
	if pNpc == nil then printf("%s: spawnMobile failed\n", self.name); return nil end
	AiAgent(pNpc):addObjectFlag(AI_STATIC)
	CreatureObject(pNpc):clearOptionBit(AIENABLED)
	setQuestStatus(self.name .. ".oid", tostring(SceneObject(pNpc):getObjectID()))
	return pNpc
end

function FbMasterBase:npc()
	local oid = tonumber(getQuestStatus(self.name .. ".oid") or 0) or 0
	if oid == 0 then return nil end
	return getSceneObject(oid)
end

-- ---------------------------------------------------------------- the conversation's decisions

function FbMasterBase:say(pPlayer, id) CreatureObject(pPlayer):sendSystemMessage("@fb_force:" .. self.prefix .. id) end

-- which screen the Master opens with
function FbMasterBase:screenFor(pPlayer)
	if not self:isPadawan(pPlayer) then return "stranger" end
	local m = FbAttunement:flag(pPlayer, "master")
	if m ~= nil and m ~= self.side then
		-- the other Master's student: theirs, unless the heart has turned this way (4b.3)
		if FbAlignment ~= nil and FbAlignment:leans(pPlayer) == self.side then return "turn" end
		return "otherdoor"
	end
	if m == nil and self:alignment(pPlayer) ~= self.side then return "otherdoor" end
	if not self:isStudent(pPlayer) then return "offer" end
	local t = self:currentTask(pPlayer)
	if t == nil then return "trained" end
	if t.rank ~= nil and self:get(pPlayer, "told:" .. t.id) == nil and self:jediXp(pPlayer) < (t.xp or 0) then return "rank_wait_xp" end
	if self:get(pPlayer, "ready:" .. t.id) ~= nil then return "done_" .. t.id end
	if self:get(pPlayer, "told:" .. t.id) == nil then return "train_" .. t.id end
	return "wait_" .. t.id
end

-- the Padawan of the other side is sent to the other door
function FbMasterBase:turnAway(pPlayer)
	waypointTo(pPlayer, self.zone, self.otherEntrance.x, self.otherEntrance.y, self.otherEntrance.name)
end

-- "I am ready": the side's novice rank box, the council, the first task
function FbMasterBase:take(pPlayer)
	if pPlayer == nil or FbAttunement == nil or FbAttunement:flag(pPlayer, "master") ~= nil then return false end
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost ~= nil then
		PlayerObject(pGhost):setFrsCouncil(self.council)
		PlayerObject(pGhost):setFrsRank(0)
	end
	if not CreatureObject(pPlayer):hasSkill("force_title_jedi_novice") then awardSkillUnchecked(pPlayer, "force_title_jedi_novice") end
	-- the rank box is given, not earned: stock requires a Knight behind it (awardSkillUnchecked, DirectorManager.cpp)
	if not CreatureObject(pPlayer):hasSkill(self.rankSkill) then awardSkillUnchecked(pPlayer, self.rankSkill) end
	FbAttunement:setFlag(pPlayer, "master", self.side)
	FbAttunement:setFlag(pPlayer, "task", "training")
	self:set(pPlayer, "step", 1)
	self:say(pPlayer, "taken")
	printf("%s: %s is taken as a student\n", self.name, CreatureObject(pPlayer):getFirstName())
	return true
end

-- the task's screen was shown: it is given
function FbMasterBase:told(pPlayer, id)
	self:set(pPlayer, "told:" .. id, os.time())
	local t = self:currentTask(pPlayer)
	if t ~= nil and t.id == id and t.kind == "sit" then self:armSit(pPlayer) end
end

-- the task reported: Jedi experience, the next step
function FbMasterBase:reward(pPlayer, id)
	if self:get(pPlayer, "ready:" .. id) == nil then return false end
	self:clear(pPlayer, "ready:" .. id)
	local d = self:get(pPlayer, "done")
	self:set(pPlayer, "done", d == nil and id or (d .. "," .. id))
	CreatureObject(pPlayer):awardExperience("jedi_general", self.xpPerTask, true)
	local t, step = self:currentTask(pPlayer)
	if t ~= nil and t.align ~= nil and FbAlignment ~= nil then FbAlignment:shift(pPlayer, t.align, self.name .. ":" .. id) end
	if t ~= nil and t.rank ~= nil then self:promote(pPlayer, t.rank) end
	self:set(pPlayer, "step", step + 1)
	self:clear(pPlayer, "prog"); self:clear(pPlayer, "sat")
	if self.tasks[step + 1] == nil then
		FbAttunement:setFlag(pPlayer, "task", "trained")
		self:say(pPlayer, "trained_note")
	end
	printf("%s: %s reports %s (%d of %d)\n", self.name, CreatureObject(pPlayer):getFirstName(), id, step, #self.tasks)
	return true
end

function FbMasterBase:complete(pPlayer, id)
	if self:get(pPlayer, "ready:" .. id) ~= nil or self:isDone(pPlayer, id) then return end
	self:set(pPlayer, "ready:" .. id, os.time())
	self:say(pPlayer, id .. "_done")
	printf("%s: %s has done %s\n", self.name, CreatureObject(pPlayer):getFirstName(), id)
end

function FbMasterBase:jediXp(pPlayer)
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost == nil then return 0 end
	return PlayerObject(pGhost):getExperience("jedi_general")
end

function FbMasterBase:rankSkillFor(rank)
	if rank >= 11 then return "force_rank_" .. self.side .. "_master" end
	return string.format("force_rank_%s_rank_%02d", self.side, rank)
end

-- the ladder: FRS rank N and its box (4b.3)
function FbMasterBase:promote(pPlayer, rank)
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost ~= nil then PlayerObject(pGhost):setFrsRank(rank) end
	local box = self:rankSkillFor(rank)
	if not CreatureObject(pPlayer):hasSkill(box) then awardSkillUnchecked(pPlayer, box) end
	local msg = LuaStringIdChatParameter("@fb_force:" .. self.prefix .. "promoted"); msg:setDI(rank)
	CreatureObject(pPlayer):sendSystemMessage(msg:_getObject())
	printf("%s: %s promoted to rank %d (%s)\n", self.name, CreatureObject(pPlayer):getFirstName(), rank, box)
end

-- the turn: redemption or temptation. The old side's rank boxes go, the new side starts at the novice (4b.3)
function FbMasterBase:turn(pPlayer)
	if pPlayer == nil or FbAttunement == nil then return false end
	local oldSide = FbAttunement:flag(pPlayer, "master")
	if oldSide == nil or oldSide == self.side then return false end
	local old = nil
	for _, m in ipairs(FbMasters) do if m.side == oldSide then old = m end end
	-- removeSkill, highest first: surrenderSkill refuses a box whose children are held and any force_ box the
	-- Village manager would keep (the FrsManager removes its rank boxes the same way)
	for rank = 11, 0, -1 do
		local box = rank == 0 and ("force_rank_" .. oldSide .. "_novice") or (old ~= nil and old:rankSkillFor(rank) or nil)
		if box ~= nil and CreatureObject(pPlayer):hasSkill(box) then CreatureObject(pPlayer):removeSkill(box) end
	end
	if old ~= nil then old:reset(pPlayer) end
	self:reset(pPlayer)
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost ~= nil then
		PlayerObject(pGhost):setFrsCouncil(self.council)
		PlayerObject(pGhost):setFrsRank(0)
	end
	if not CreatureObject(pPlayer):hasSkill(self.rankSkill) then awardSkillUnchecked(pPlayer, self.rankSkill) end
	FbAttunement:setFlag(pPlayer, "master", self.side)
	FbAttunement:setFlag(pPlayer, "alignment", self.side)
	FbAttunement:setFlag(pPlayer, "task", "training")
	self:set(pPlayer, "step", 1)
	self:say(pPlayer, "turned")
	printf("%s: %s turns from the %s to the %s\n", self.name, CreatureObject(pPlayer):getFirstName(), oldSide, self.side)
	return true
end

-- ---------------------------------------------------------------- the tasks

-- sit: a poll while the student sits in the Master's room (one chain per student, keyed in quest status)
function FbMasterBase:armSit(pPlayer)
	if pPlayer == nil then return end
	local oid = SceneObject(pPlayer):getObjectID()
	if getQuestStatus(self.name .. ".sit." .. oid) ~= "" then return end
	setQuestStatus(self.name .. ".sit." .. oid, tostring(os.time()))
	createEvent(self.sitPoll, self.name, "pollSit", pPlayer, "")
end

function FbMasterBase:pollSit(pPlayer)
	if pPlayer == nil then return end
	local oid = SceneObject(pPlayer):getObjectID()
	local t = self:currentTask(pPlayer)
	if t == nil or t.kind ~= "sit" or self:get(pPlayer, "ready:" .. t.id) ~= nil or SceneObject(pPlayer):getZoneName() == "" or not self:isStudent(pPlayer) then
		removeQuestStatus(self.name .. ".sit." .. oid)
		return
	end
	local pCell = self:cell()
	local inRoom = pCell ~= nil and SceneObject(pPlayer):getParentID() == SceneObject(pCell):getObjectID()
	local still = CreatureObject(pPlayer):isMeditating() or CreatureObject(pPlayer):getPosture() == SITTING
	if inRoom and still then
		local sat = (tonumber(self:get(pPlayer, "sat") or 0) or 0) + self.sitPoll / 1000
		self:set(pPlayer, "sat", sat)
		if sat >= t.seconds then
			removeQuestStatus(self.name .. ".sit." .. oid)
			self:complete(pPlayer, t.id)
			return
		end
	end
	createEvent(self.sitPoll, self.name, "pollSit", pPlayer, "")
end

-- kill: through FbAttunement's kill observer
function FbMasterBase:onKill(pPlayer, pVictim)
	if pPlayer == nil or pVictim == nil or not self:isStudent(pPlayer) then return end
	local t = self:currentTask(pPlayer)
	if t == nil or t.kind ~= "kill" or self:get(pPlayer, "told:" .. t.id) == nil or self:get(pPlayer, "ready:" .. t.id) ~= nil then return end
	if t.match ~= "" then
		local path = SceneObject(pVictim):getTemplateObjectPath() .. " " .. tostring(SceneObject(pVictim):getObjectName())
		if not path:lower():find(t.match, 1, true) then return end
	end
	local prog = (tonumber(self:get(pPlayer, "prog") or 0) or 0) + 1
	self:set(pPlayer, "prog", prog)
	local msg = LuaStringIdChatParameter("@fb_force:" .. self.prefix .. t.id .. "_progress")
	msg:setDI(prog)
	CreatureObject(pPlayer):sendSystemMessage(msg:_getObject())
	if prog >= t.count then self:complete(pPlayer, t.id) end
end

-- a login re-arms the sit poll (events do not survive a restart)
function FbMasterBase:onLogin(pPlayer)
	if pPlayer == nil or not self:isStudent(pPlayer) then return end
	removeQuestStatus(self.name .. ".sit." .. SceneObject(pPlayer):getObjectID())
	local t = self:currentTask(pPlayer)
	if t ~= nil and t.kind == "sit" and self:get(pPlayer, "told:" .. t.id) ~= nil and self:get(pPlayer, "ready:" .. t.id) == nil then self:armSit(pPlayer) end
end

-- one status line (lab)
function FbMasterBase:status(pPlayer)
	local t, step = self:currentTask(pPlayer)
	return string.format("padawan=%s alignment=%s master=%s student=%s step=%d current=%s told=%s ready=%s done=%s sat=%s prog=%s rank=%s council=%s frsRank=%s align=%d",
		tostring(self:isPadawan(pPlayer)), tostring(FbAttunement:flag(pPlayer, "alignment") or "-"), tostring(FbAttunement:flag(pPlayer, "master") or "-"), tostring(self:isStudent(pPlayer)), step,
		t and t.id or "-", t and tostring(self:get(pPlayer, "told:" .. t.id) ~= nil) or "-", t and tostring(self:get(pPlayer, "ready:" .. t.id) ~= nil) or "-",
		self:get(pPlayer, "done") or "-", self:get(pPlayer, "sat") or "0", self:get(pPlayer, "prog") or "0",
		tostring(CreatureObject(pPlayer):hasSkill(self.rankSkill)), tostring(PlayerObject(CreatureObject(pPlayer):getPlayerObject()):getFrsCouncil()),
		tostring(PlayerObject(CreatureObject(pPlayer):getPlayerObject()):getFrsRank()), FbAlignment ~= nil and FbAlignment:score(pPlayer) or 0)
end

-- ---------------------------------------------------------------- the two Masters

FbJediMaster = FbMasterBase:new {
	name = "FbJediMaster", DATA = "FbJediMaster", side = "light", council = 1, rankSkill = "force_rank_light_novice", prefix = "master_",
	zone = "yavin4", buildingOid = 8525417, room = "trainingroom",   -- cell 24; flat floor at −24.1, no furniture
	x = 20.0, z = -24.1, y = 68.0, heading = 180, template = "fb_jedi_master",
	entrance = { x = -5575, y = 4910 }, otherEntrance = { x = 5068, y = 310, name = "The Dark Enclave" },
	xpPerTask = 5000, sitPoll = 5000,
	tasks = {
		{ id = "stillness", kind = "sit", seconds = 60, align = 5 },
		{ id = "shadows", kind = "kill", match = "sith_shadow", count = 5, align = 5 },
		-- the ladder (4b.3): rank N is given for the task, once the Jedi experience is there
		{ id = "rank1", rank = 1, xp = 5000, kind = "kill", match = "sith_shadow", count = 10, align = 5 },
		{ id = "rank2", rank = 2, xp = 15000, kind = "sit", seconds = 180, align = 5 },
	},
}

FbSithMaster = FbMasterBase:new {
	name = "FbSithMaster", DATA = "FbSithMaster", side = "dark", council = 2, rankSkill = "force_rank_dark_novice", prefix = "sith_",
	zone = "yavin4", buildingOid = 3435626, room = "chamber",   -- cell 16, the far end of the enclave; flat floor at −43.3
	x = 0.0, z = -43.3, y = -150.0, heading = 0, template = "fb_sith_master",
	entrance = { x = 5068, y = 310 }, otherEntrance = { x = -5575, y = 4910, name = "The Light Enclave" },
	xpPerTask = 5000, sitPoll = 5000,
	tasks = {
		{ id = "patience", kind = "sit", seconds = 60, align = -5 },
		{ id = "prey", kind = "kill", match = "", count = 5, align = -10 },   -- anything that lives
		{ id = "rank1", rank = 1, xp = 5000, kind = "kill", match = "mauler", count = 5, align = -5 },   -- the Maulers, Dathomir's dark pretenders
		{ id = "rank2", rank = 2, xp = 15000, kind = "sit", seconds = 180, align = -5 },
	},
}

FbMasters = { FbJediMaster, FbSithMaster }

-- the Master a character belongs to (nil when none)
function FbMasters.of(pPlayer)
	if pPlayer == nil or FbAttunement == nil then return nil end
	local side = FbAttunement:flag(pPlayer, "master")
	for _, m in ipairs(FbMasters) do if m.side == side then return m end end
	return nil
end
function FbMasters.onKill(pPlayer, pVictim) for _, m in ipairs(FbMasters) do m:onKill(pPlayer, pVictim) end end
function FbMasters.onLogin(pPlayer) for _, m in ipairs(FbMasters) do m:onLogin(pPlayer) end end
function FbMasters.reset(pPlayer) for _, m in ipairs(FbMasters) do m:reset(pPlayer) end end

-- ---------------------------------------------------------------- boot

FbMastersScreenPlay = ScreenPlay:new { screenplayName = "FbMastersScreenPlay" }
registerScreenPlay("FbMastersScreenPlay", true)
function FbMastersScreenPlay:start()
	for _, m in ipairs(FbMasters) do m:spawn() end
end
