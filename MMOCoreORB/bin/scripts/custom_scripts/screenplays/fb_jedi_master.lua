-- fb_jedi_master.lua — Phase 4b.1: the Jedi Master.
--
-- Master Ilara Venn teaches in the training room of the Light Jedi Enclave on Yavin 4 (the stock building at
-- −5513.7, 4911.8; entrance −5575, 4910). A Padawan — the Padawan box from the trials (flag `padawan`) and a
-- light or unset alignment — who speaks to her is taken as her student: she enrols the character on the light
-- side of the rank ladder (FRS council light, the `force_rank_light_novice` box; the visible Jedi ladder of the
-- Phase 4 decisions) and sets the first training task. Each task is reported back to her in conversation and
-- pays Jedi experience; after the last she waits for the rank quests of 4b.3. A dark Padawan is sent to the
-- other door (4b.2); anyone else she does not know.
--
-- Training (data in `tasks`, in order): `stillness` — sit or meditate 60 s in her training room; `shadows` —
-- five Sith Shadows (any `sith_shadow_*`), through the attunement kill hook. State is per-player screenplay
-- data "FbJediMaster": `master` (light), `step` (index of the current task), `told:<id>` (the task was given),
-- `ready:<id>` (done, not yet reported), `done` (comma list), `sat` (seconds of stillness so far).
--
-- Lab: FbLabTests jediMaster / jediMasterTake / trainingSet / trainingTick, checkJediMaster; scenario `jedi-master`.

FbJediMaster = {
	DATA = "FbJediMaster",
	zone = "yavin4",
	buildingOid = 8525417,          -- the stock Light Jedi Enclave (snapshot object: the id is stable)
	room = "trainingroom",          -- cell 24; flat floor at −24.1, no furniture (lotsurvey check)
	x = 20.0, z = -24.1, y = 68.0, heading = 180,
	template = "fb_jedi_master",
	entrance = { x = -5575, y = 4910 },
	darkEntrance = { x = 5068, y = 310 },
	xpPerTask = 5000,               -- jedi_general
	tasks = {
		{ id = "stillness", kind = "sit", seconds = 60 },
		{ id = "shadows", kind = "kill", match = "sith_shadow", count = 5 },
	},
	sitPoll = 5000,
}

-- ---------------------------------------------------------------- state

function FbJediMaster:get(pPlayer, k) local v = readScreenPlayData(pPlayer, self.DATA, k); if v == nil or v == "" then return nil end; return v end
function FbJediMaster:set(pPlayer, k, v) writeScreenPlayData(pPlayer, self.DATA, k, tostring(v)) end
function FbJediMaster:clear(pPlayer, k) deleteScreenPlayData(pPlayer, self.DATA, k) end
function FbJediMaster:isDone(pPlayer, id) local d = self:get(pPlayer, "done") or ""; return d:find(id, 1, true) ~= nil end
function FbJediMaster:currentTask(pPlayer)
	local step = tonumber(self:get(pPlayer, "step") or 0) or 0
	return self.tasks[step], step
end
function FbJediMaster:isStudent(pPlayer) return self:get(pPlayer, "master") ~= nil end
function FbJediMaster:isPadawan(pPlayer) return FbAttunement ~= nil and FbAttunement:flag(pPlayer, "padawan") ~= nil end
function FbJediMaster:alignment(pPlayer) return FbAttunement ~= nil and FbAttunement:flag(pPlayer, "alignment") or nil end

function FbJediMaster:reset(pPlayer)
	for _, k in ipairs({ "master", "step", "done", "sat", "prog" }) do self:clear(pPlayer, k) end
	for _, t in ipairs(self.tasks) do self:clear(pPlayer, "told:" .. t.id); self:clear(pPlayer, "ready:" .. t.id) end
end

-- ---------------------------------------------------------------- the Master herself

function FbJediMaster:cell()
	local pBuilding = getSceneObject(self.buildingOid)
	if pBuilding == nil then return nil end
	return BuildingObject(pBuilding):getNamedCell(self.room)
end

function FbJediMaster:spawn()
	if not isZoneEnabled(self.zone) then return nil end
	local pCell = self:cell()
	if pCell == nil then printf("FbJediMaster: the Light Enclave (%d) or its %s is missing; no Master\n", self.buildingOid, self.room); return nil end
	local pNpc = spawnMobile(self.zone, self.template, 0, self.x, self.z, self.y, math.rad(self.heading), SceneObject(pCell):getObjectID())
	if pNpc == nil then printf("FbJediMaster: spawnMobile failed\n"); return nil end
	AiAgent(pNpc):addObjectFlag(AI_STATIC)
	CreatureObject(pNpc):clearOptionBit(AIENABLED)
	setQuestStatus("FbJediMaster.oid", tostring(SceneObject(pNpc):getObjectID()))
	return pNpc
end

function FbJediMaster:npc()
	local oid = tonumber(getQuestStatus("FbJediMaster.oid") or 0) or 0
	if oid == 0 then return nil end
	return getSceneObject(oid)
end

-- ---------------------------------------------------------------- the conversation's decisions

local function say(pPlayer, id) CreatureObject(pPlayer):sendSystemMessage("@fb_force:" .. id) end

-- which screen the Master opens with
function FbJediMaster:screenFor(pPlayer)
	if not self:isPadawan(pPlayer) then return "stranger" end
	if self:alignment(pPlayer) == "dark" then return "dark" end
	if not self:isStudent(pPlayer) then return "offer" end
	local t = self:currentTask(pPlayer)
	if t == nil then return "trained" end
	if self:get(pPlayer, "ready:" .. t.id) ~= nil then return "done_" .. t.id end
	if self:get(pPlayer, "told:" .. t.id) == nil then return "train_" .. t.id end
	return "wait_" .. t.id
end

-- the dark Padawan is sent to the other door
function FbJediMaster:turnAway(pPlayer)
	waypointTo(pPlayer, self.zone, self.darkEntrance.x, self.darkEntrance.y, "The Dark Enclave")
end

-- "I am ready to learn": the light side's novice rank, and the first task
function FbJediMaster:take(pPlayer)
	if pPlayer == nil or self:isStudent(pPlayer) then return false end
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost ~= nil then
		PlayerObject(pGhost):setFrsCouncil(1)   -- FrsManager::COUNCIL_LIGHT
		PlayerObject(pGhost):setFrsRank(0)
	end
	if not CreatureObject(pPlayer):hasSkill("force_title_jedi_novice") then awardSkill(pPlayer, "force_title_jedi_novice") end
	-- the rank box is given, not earned: stock requires a Knight behind it (awardSkillUnchecked, DirectorManager.cpp)
	if not CreatureObject(pPlayer):hasSkill("force_rank_light_novice") then awardSkillUnchecked(pPlayer, "force_rank_light_novice") end
	self:set(pPlayer, "master", "light")
	self:set(pPlayer, "step", 1)
	if FbAttunement ~= nil then FbAttunement:setFlag(pPlayer, "task", "training") end
	say(pPlayer, "master_taken")
	printf("FbJediMaster: %s is taken as a student\n", CreatureObject(pPlayer):getFirstName())
	return true
end

-- the task's screen was shown: it is given
function FbJediMaster:told(pPlayer, id)
	self:set(pPlayer, "told:" .. id, os.time())
	local t = self:currentTask(pPlayer)
	if t ~= nil and t.id == id and t.kind == "sit" then self:armSit(pPlayer) end
end

-- the task reported: Jedi experience, the next step
function FbJediMaster:reward(pPlayer, id)
	if self:get(pPlayer, "ready:" .. id) == nil then return false end
	self:clear(pPlayer, "ready:" .. id)
	local d = self:get(pPlayer, "done")
	self:set(pPlayer, "done", d == nil and id or (d .. "," .. id))
	CreatureObject(pPlayer):awardExperience("jedi_general", self.xpPerTask, true)
	local _, step = self:currentTask(pPlayer)
	self:set(pPlayer, "step", step + 1)
	self:clear(pPlayer, "prog"); self:clear(pPlayer, "sat")
	if self.tasks[step + 1] == nil then
		if FbAttunement ~= nil then FbAttunement:setFlag(pPlayer, "task", "trained") end
		say(pPlayer, "master_trained_note")
	end
	printf("FbJediMaster: %s reports %s (%d of %d)\n", CreatureObject(pPlayer):getFirstName(), id, step, #self.tasks)
	return true
end

function FbJediMaster:complete(pPlayer, id)
	if self:get(pPlayer, "ready:" .. id) ~= nil or self:isDone(pPlayer, id) then return end
	self:set(pPlayer, "ready:" .. id, os.time())
	say(pPlayer, "master_" .. id .. "_done")
	printf("FbJediMaster: %s has done %s\n", CreatureObject(pPlayer):getFirstName(), id)
end

-- ---------------------------------------------------------------- the tasks

-- stillness: a poll while the student sits in the training room
function FbJediMaster:armSit(pPlayer)
	if pPlayer == nil then return end
	local oid = SceneObject(pPlayer):getObjectID()
	if getQuestStatus("FbJediMaster.sit." .. oid) ~= "" then return end   -- one poll per student
	setQuestStatus("FbJediMaster.sit." .. oid, tostring(os.time()))
	createEvent(self.sitPoll, "FbJediMaster", "pollSit", pPlayer, "")
end

function FbJediMaster:pollSit(pPlayer)
	if pPlayer == nil then return end
	local oid = SceneObject(pPlayer):getObjectID()
	local t = self:currentTask(pPlayer)
	if t == nil or t.kind ~= "sit" or self:get(pPlayer, "ready:" .. t.id) ~= nil or SceneObject(pPlayer):getZoneName() == "" then
		removeQuestStatus("FbJediMaster.sit." .. oid)
		return
	end
	local pCell = self:cell()
	local inRoom = pCell ~= nil and SceneObject(pPlayer):getParentID() == SceneObject(pCell):getObjectID()
	local still = CreatureObject(pPlayer):isMeditating() or CreatureObject(pPlayer):getPosture() == 8   -- SITTING (see fb_attunement)
	if inRoom and still then
		local sat = (tonumber(self:get(pPlayer, "sat") or 0) or 0) + self.sitPoll / 1000
		self:set(pPlayer, "sat", sat)
		if sat >= t.seconds then
			removeQuestStatus("FbJediMaster.sit." .. oid)
			self:complete(pPlayer, t.id)
			return
		end
	end
	createEvent(self.sitPoll, "FbJediMaster", "pollSit", pPlayer, "")
end

-- shadows: through FbAttunement's kill observer
function FbJediMaster:onKill(pPlayer, pVictim)
	if pPlayer == nil or pVictim == nil or not self:isStudent(pPlayer) then return end
	local t = self:currentTask(pPlayer)
	if t == nil or t.kind ~= "kill" or self:get(pPlayer, "told:" .. t.id) == nil or self:get(pPlayer, "ready:" .. t.id) ~= nil then return end
	local path = SceneObject(pVictim):getTemplateObjectPath() .. " " .. tostring(SceneObject(pVictim):getObjectName())
	if not path:lower():find(t.match, 1, true) then return end
	local prog = (tonumber(self:get(pPlayer, "prog") or 0) or 0) + 1
	self:set(pPlayer, "prog", prog)
	local msg = LuaStringIdChatParameter("@fb_force:master_shadows_progress")
	msg:setDI(prog)
	CreatureObject(pPlayer):sendSystemMessage(msg:_getObject())
	if prog >= t.count then self:complete(pPlayer, t.id) end
end

-- a login re-arms the stillness poll (events do not survive a restart)
function FbJediMaster:onLogin(pPlayer)
	if pPlayer == nil or not self:isStudent(pPlayer) then return end
	removeQuestStatus("FbJediMaster.sit." .. SceneObject(pPlayer):getObjectID())
	local t = self:currentTask(pPlayer)
	if t ~= nil and t.kind == "sit" and self:get(pPlayer, "told:" .. t.id) ~= nil and self:get(pPlayer, "ready:" .. t.id) == nil then self:armSit(pPlayer) end
end

-- one status line (lab)
function FbJediMaster:status(pPlayer)
	local t, step = self:currentTask(pPlayer)
	return string.format("padawan=%s alignment=%s student=%s step=%d current=%s told=%s ready=%s done=%s sat=%s prog=%s novice=%s council=%s",
		tostring(self:isPadawan(pPlayer)), tostring(self:alignment(pPlayer) or "-"), tostring(self:isStudent(pPlayer)), step,
		t and t.id or "-", t and tostring(self:get(pPlayer, "told:" .. t.id) ~= nil) or "-", t and tostring(self:get(pPlayer, "ready:" .. t.id) ~= nil) or "-",
		self:get(pPlayer, "done") or "-", self:get(pPlayer, "sat") or "0", self:get(pPlayer, "prog") or "0",
		tostring(CreatureObject(pPlayer):hasSkill("force_rank_light_novice")), tostring(PlayerObject(CreatureObject(pPlayer):getPlayerObject()):getFrsCouncil()))
end

-- ---------------------------------------------------------------- boot

FbJediMasterScreenPlay = ScreenPlay:new { screenplayName = "FbJediMasterScreenPlay" }
registerScreenPlay("FbJediMasterScreenPlay", true)
function FbJediMasterScreenPlay:start()
	FbJediMaster:spawn()
end
