-- fb_trials.lua — Phase 4a.3: the Padawan trials.
--
-- Unlocked by the Old Man's return (FbAttunement flag task=trials). Eight small trials, taken one at a time in
-- order; each begins as "word from the old man" (a system message, a waypoint where one helps) at the next
-- attunement trigger (after a fight, at a shrine, a badge — never at login), and ends with its own line.
--   stillness  stand without moving for 60 s inside any Force shrine
--   restraint  five minutes in open country, outside cities, without a kill or a fight (a fight resets)
--   strength   five Tusken (any template containing "tusken")
--   mercy      a bound prisoner on the road: free him (light) or kill him (dark) — the alignment choice
--   farwalk    reach the Force shrine on this world farthest from where the word came
--   insight    a spirit asks one of three riddles; wrong → it leaves, asks again later
--   sacrifice  the spirit asks for 10 000 credits
--   duel       one Sith Shadow, matched to the character's level, alone (grouped kills do not count)
-- All eight done: awardSkill force_title_jedi_novice (the Padawan box), flag padawan, task=padawan; the
-- alignment (light/dark) is FbAttunement flag "alignment", for 4b.
--
-- State: screenplay data "FbTrials" — done (csv of ids), current, prog (number), target (farwalk key),
-- riddle (1..3), plus the attunement flags. Lab: FbLabTests trials/trialStart/trialProgress/trialReset/cashSet.

local SpawnMobiles = require("utils.spawn_mobiles")

FbTrials = ScreenPlay:new {
	screenplayName = "FbTrials",
	DATA = "FbTrials",
	list = {
		{ id = "stillness", kind = "stay", seconds = 60 },
		{ id = "restraint", kind = "nokill", seconds = 300 },
		{ id = "strength", kind = "kill", match = "tusken", count = 5 },
		{ id = "mercy", kind = "prisoner" },
		{ id = "farwalk", kind = "reach" },
		{ id = "insight", kind = "riddle" },
		{ id = "sacrifice", kind = "credits", amount = 10000 },
		{ id = "duel", kind = "duel" },
	},
}

function FbTrials:get(pPlayer, k) local v = readScreenPlayData(pPlayer, self.DATA, k); if v == nil or v == "" then return nil end; return v end
function FbTrials:set(pPlayer, k, v) writeScreenPlayData(pPlayer, self.DATA, k, tostring(v)) end
function FbTrials:clear(pPlayer, k) deleteScreenPlayData(pPlayer, self.DATA, k) end
function FbTrials:byId(id) for _, t in ipairs(self.list) do if t.id == id then return t end end return nil end
function FbTrials:current(pPlayer) return self:get(pPlayer, "current") end
function FbTrials:isDone(pPlayer, id) local d = self:get(pPlayer, "done") or ""; return d:find(id, 1, true) ~= nil end
function FbTrials:doneCount(pPlayer) local d = self:get(pPlayer, "done") or ""; if d == "" then return 0 end; return select(2, d:gsub(",", ",")) + 1 end
function FbTrials:riddleOf(pPlayer) return tonumber(self:get(pPlayer, "riddle") or 1) or 1 end

function FbTrials:active(pPlayer)
	return FbAttunement ~= nil and FbAttunement:flag(pPlayer, "task") == "trials" and FbAttunement:flag(pPlayer, "padawan") == nil
end

function FbTrials:reset(pPlayer)
	for _, k in ipairs({ "done", "current", "prog", "target", "riddle", "startedAt", "lastX", "lastY" }) do self:clear(pPlayer, k) end
	-- a visitor still standing must go through the spawn helper's despawn, or its bookkeeping refuses the next one
	for _, V in ipairs({ FbTrialPrisoner, FbTrialSpirit, FbTrialDuel }) do
		if SpawnMobiles.getSpawnedMobiles(pPlayer, V.taskName) ~= nil then V:doDespawn(pPlayer) elseif V:hasTaskStarted(pPlayer) then V:finish(pPlayer) end
	end
end

-- ---------------------------------------------------------------- starting and finishing trials

local function say(pPlayer, id) CreatureObject(pPlayer):sendSystemMessage("@fb_force:" .. id) end

local function waypointTo(pPlayer, planet, x, y, label)
	local pGhost = CreatureObject(pPlayer):getPlayerObject()
	if pGhost == nil then return end
	PlayerObject(pGhost):addWaypoint(planet, label, "", x, getTerrainHeightAt(planet, x, y), y, 1, true, true, 0)
end

-- the shrine on the player's world farthest from them (farwalk) or nearest (stillness)
local function shrineOnWorld(pPlayer, farthest)
	local so = SceneObject(pPlayer)
	local best, bestD
	for _, s in ipairs(FbAttunement.shrines) do
		if s[2] == so:getZoneName() then
			local d = (so:getWorldPositionX() - s[3]) ^ 2 + (so:getWorldPositionY() - s[4]) ^ 2
			if bestD == nil or (farthest and d > bestD) or (not farthest and d < bestD) then best, bestD = s, d end
		end
	end
	return best
end

function FbTrials:nextTrial(pPlayer)
	for _, t in ipairs(self.list) do if not self:isDone(pPlayer, t.id) then return t end end
	return nil
end

-- the word from the old man: begin the trial
function FbTrials:startTrial(pPlayer, t)
	self:set(pPlayer, "current", t.id)
	self:set(pPlayer, "prog", 0)
	self:set(pPlayer, "startedAt", os.time())
	say(pPlayer, "trial_word_prefix")
	say(pPlayer, "trial_" .. t.id .. "_word")
	if t.kind == "stay" then
		local s = shrineOnWorld(pPlayer, false)
		if s ~= nil then waypointTo(pPlayer, s[2], s[3], s[4], "A quiet place") end
	elseif t.kind == "reach" then
		local s = shrineOnWorld(pPlayer, true)
		if s ~= nil then self:set(pPlayer, "target", s[1]); waypointTo(pPlayer, s[2], s[3], s[4], "The far quiet place") end
	elseif t.kind == "kill" then
		if SceneObject(pPlayer):getZoneName() == "tatooine" then waypointTo(pPlayer, "tatooine", 4100, -4700, "Sand People") end
	elseif t.kind == "nokill" then
		createEvent(10000, "FbTrials", "pollNoKill", pPlayer, "")
	elseif t.kind == "riddle" then
		self:set(pPlayer, "riddle", getRandomNumber(3))
	end
	printf("FbTrials: %s begins %s\n", CreatureObject(pPlayer):getFirstName(), t.id)
end

function FbTrials:complete(pPlayer, id)
	if self:current(pPlayer) ~= id or self:isDone(pPlayer, id) then return false end
	local d = self:get(pPlayer, "done") or ""
	self:set(pPlayer, "done", d == "" and id or (d .. "," .. id))
	self:clear(pPlayer, "current"); self:clear(pPlayer, "prog"); self:clear(pPlayer, "target")
	say(pPlayer, "trial_" .. id .. "_done")
	printf("FbTrials: %s completed %s (%d of %d)\n", CreatureObject(pPlayer):getFirstName(), id, self:doneCount(pPlayer), #self.list)
	if self:doneCount(pPlayer) >= #self.list then self:finishAll(pPlayer) end
	return true
end

function FbTrials:finishAll(pPlayer)
	FbAttunement:setFlag(pPlayer, "padawan", os.time())
	FbAttunement:setFlag(pPlayer, "task", "padawan")
	if not CreatureObject(pPlayer):hasSkill("force_title_jedi_novice") then awardSkill(pPlayer, "force_title_jedi_novice") end
	say(pPlayer, "trials_complete")
	local a = FbAttunement:flag(pPlayer, "alignment")
	if a == "light" then say(pPlayer, "trials_light") elseif a == "dark" then say(pPlayer, "trials_dark") end
end

-- the fourth trial's choice
function FbTrials:choose(pPlayer, alignment)
	FbAttunement:setFlag(pPlayer, "alignment", alignment)
	self:complete(pPlayer, "mercy")
end

function FbTrials:takeCredits(pPlayer)
	local t = self:byId("sacrifice")
	if CreatureObject(pPlayer):getCashCredits() < t.amount then return false end
	CreatureObject(pPlayer):subtractCashCredits(t.amount)
	return true
end

-- ---------------------------------------------------------------- the trigger (from FbAttunement:maybeVisit)

-- Returns true when something was sent (a word, a visitor) so the caller treats it as this trigger's visit.
function FbTrials:tick(pPlayer)
	if not self:active(pPlayer) then return false end
	local cur = self:current(pPlayer)
	if cur == nil then
		local t = self:nextTrial(pPlayer)
		if t == nil then self:finishAll(pPlayer); return true end
		self:startTrial(pPlayer, t)
		return true
	end
	local t = self:byId(cur)
	if t == nil then self:clear(pPlayer, "current"); return false end
	-- visit kinds: send the visitor when the player is somewhere for one
	local V = (t.kind == "prisoner" and FbTrialPrisoner) or (t.kind == "riddle" and FbTrialSpirit) or (t.kind == "credits" and FbTrialSpirit) or (t.kind == "duel" and FbTrialDuel) or nil
	if V ~= nil then
		if V:hasTaskStarted(pPlayer) then
			local spawned = SpawnMobiles.getSpawnedMobiles(pPlayer, V.taskName)
			if spawned ~= nil and spawned[1] ~= nil then return false end   -- still standing
			V:finish(pPlayer)
		end
		if V:isPlayerInPositionForEncounter(pPlayer) and V:start(pPlayer) then
			setQuestStatus("FbAttunement.visit." .. SceneObject(pPlayer):getObjectID(), tostring(os.time()))
			return true
		end
		return false
	end
	if t.kind == "nokill" then createEvent(10000, "FbTrials", "pollNoKill", pPlayer, "") end   -- (re)arm the watch after a login
	return false
end

-- ---------------------------------------------------------------- stillness and restraint (polls)

function FbTrials:onShrine(pPlayer, key)
	local cur = self:current(pPlayer)
	if cur == "stillness" then
		self:set(pPlayer, "prog", 0)
		local so = SceneObject(pPlayer)
		self:set(pPlayer, "lastX", so:getWorldPositionX()); self:set(pPlayer, "lastY", so:getWorldPositionY())
		createEvent(5000, "FbTrials", "pollStay", pPlayer, "")
	elseif cur == "farwalk" and self:get(pPlayer, "target") == key then
		self:complete(pPlayer, "farwalk")
	end
end

function FbTrials:pollStay(pPlayer)
	if pPlayer == nil or self:current(pPlayer) ~= "stillness" then return end
	local so = SceneObject(pPlayer)
	local key = FbAttunement:placeAt(so:getZoneName(), so:getWorldPositionX(), so:getWorldPositionY())
	if key == nil then return end   -- left the shrine: the watch ends; entering again restarts it
	local lx, ly = tonumber(self:get(pPlayer, "lastX") or 0), tonumber(self:get(pPlayer, "lastY") or 0)
	local moved = math.sqrt((so:getWorldPositionX() - lx) ^ 2 + (so:getWorldPositionY() - ly) ^ 2)
	local prog = tonumber(self:get(pPlayer, "prog") or 0)
	prog = moved > 1.5 and 0 or prog + 5
	self:set(pPlayer, "prog", prog)
	self:set(pPlayer, "lastX", so:getWorldPositionX()); self:set(pPlayer, "lastY", so:getWorldPositionY())
	if prog >= self:byId("stillness").seconds then self:complete(pPlayer, "stillness"); return end
	createEvent(5000, "FbTrials", "pollStay", pPlayer, "")
end

function FbTrials:pollNoKill(pPlayer)
	if pPlayer == nil or self:current(pPlayer) ~= "restraint" then return end
	local oid = SceneObject(pPlayer):getObjectID()
	-- one watch per player: a second arming of the event must not double the count
	local stamp = tonumber(getQuestStatus("FbTrials.nokill." .. oid) or 0)
	if os.time() - stamp < 8 then return end
	setQuestStatus("FbTrials.nokill." .. oid, tostring(os.time()))
	local prog = tonumber(self:get(pPlayer, "prog") or 0)
	if CreatureObject(pPlayer):isInCombat() then
		if prog > 0 then say(pPlayer, "trial_restraint_reset") end
		prog = 0
	elseif FbTrialSpirit:isPlayerInPositionForEncounter(pPlayer) then   -- outdoors, outside a city: counts
		prog = prog + 10
	end
	self:set(pPlayer, "prog", prog)
	if prog >= self:byId("restraint").seconds then removeQuestStatus("FbTrials.nokill." .. oid); self:complete(pPlayer, "restraint"); return end
	createEvent(10000, "FbTrials", "pollNoKill", pPlayer, "")
end

-- ---------------------------------------------------------------- kills (from FbAttunement:onKill)

function FbTrials:onKill(pPlayer, pVictim)
	local cur = self:current(pPlayer)
	if cur == nil then return end
	local t = self:byId(cur)
	if t.kind == "nokill" then
		if tonumber(self:get(pPlayer, "prog") or 0) > 0 then say(pPlayer, "trial_restraint_reset") end
		self:set(pPlayer, "prog", 0)
	elseif t.kind == "kill" and pVictim ~= nil then
		local path = SceneObject(pVictim):getTemplateObjectPath() .. " " .. tostring(SceneObject(pVictim):getObjectName())
		if path:lower():find(t.match, 1, true) then
			local prog = tonumber(self:get(pPlayer, "prog") or 0) + 1
			self:set(pPlayer, "prog", prog)
			if prog >= t.count then self:complete(pPlayer, "strength") end
		end
	end
end

registerScreenPlay("FbTrials", true)
function FbTrials:start() end

-- ---------------------------------------------------------------- the visitors

local function record(pPlayer, spawned, template, lifetime)
	if spawned == nil then return end
	for _, pNpc in ipairs(spawned) do
		if pNpc ~= nil then
			local so = SceneObject(pNpc)
			if FbLabTests ~= nil and FbLabTests.registryAdd ~= nil then
				FbLabTests.registryAdd({ oid = so:getObjectID(), zone = so:getZoneName(), cell = so:getParentID(), x = so:getWorldPositionX(), y = so:getWorldPositionY(), z = so:getWorldPositionZ(), template = template, src = "fb_trials" })
			end
			writeData(so:getObjectID() .. ":fbTrialFor", SceneObject(pPlayer):getObjectID())
			createEvent((lifetime or 300000) + 30000, "FbAttunement", "sweepVisitor", pNpc, "")
		end
	end
end

local function unfollowAndDespawn(task, pPlayer)
	local spawned = SpawnMobiles.getSpawnedMobiles(pPlayer, task.taskName)
	local oids = {}
	if spawned ~= nil then
		for _, pNpc in ipairs(spawned) do
			if SpawnMobiles.isValidMobile(pNpc) then
				oids[#oids + 1] = SceneObject(pNpc):getObjectID()
				AiAgent(pNpc):removeObjectFlag(AI_ESCORT); AiAgent(pNpc):removeObjectFlag(AI_FOLLOW); AiAgent(pNpc):setFollowObject(nil)
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
	removeQuestStatus("FbAttunement.visit." .. SceneObject(pPlayer):getObjectID())
end

-- the prisoner (mercy)
FbTrialPrisoner = Encounter:new {
	taskName = "FbTrialPrisoner",
	encounterDespawnTime = 10 * 60 * 1000,
	despawnMessage = "",
	spawnObjectList = { { template = "fb_prisoner", minimumDistance = 15, maximumDistance = 25, referencePoint = 0, followPlayer = false, setNotAttackable = true } },
	inRangeValue = 12,
}
function FbTrialPrisoner:isEncounterFinished(pPlayer) return false end
function FbTrialPrisoner:onEncounterSpawned(pPlayer, spawned)
	record(pPlayer, spawned, "fb_prisoner", self.encounterDespawnTime)
	for _, pNpc in ipairs(spawned or {}) do if pNpc ~= nil then AiAgent(pNpc):addObjectFlag(AI_STATIC) end end
end
function FbTrialPrisoner:onEncounterInRange(pPlayer, spawned)
	if spawned ~= nil and spawned[1] ~= nil then spatialChat(spawned[1], "@fb_force:prisoner_plea") end
end
function FbTrialPrisoner:belongsTo(pPlayer, pNpc) return pPlayer ~= nil and pNpc ~= nil and SpawnMobiles.isFromSpawn(pPlayer, self.taskName, pNpc) end
function FbTrialPrisoner:runOff(pPlayer, pNpc)
	if pNpc ~= nil then AiAgent(pNpc):removeObjectFlag(AI_STATIC); AiAgent(pNpc):setAITemplate(); AiAgent(pNpc):runAway(pPlayer, 80) end
	createEvent(12000, self.taskName, "handleDespawnEvent", pPlayer, "")
end
function FbTrialPrisoner:execute(pPlayer, pNpc)
	if pNpc ~= nil then CreatureObject(pNpc):inflictDamage(pPlayer, 0, 1000000, 1) end
	createEvent(8000, self.taskName, "handleDespawnEvent", pPlayer, "")
end
function FbTrialPrisoner:doDespawn(pPlayer) unfollowAndDespawn(self, pPlayer) end

-- the spirit (insight, sacrifice)
FbTrialSpirit = Encounter:new {
	taskName = "FbTrialSpirit",
	encounterDespawnTime = 10 * 60 * 1000,
	despawnMessage = "@fb_force:spirit_leaves",
	spawnObjectList = { { template = "fb_trial_spirit", minimumDistance = 18, maximumDistance = 28, referencePoint = 0, followPlayer = true, setNotAttackable = true } },
	inRangeValue = 9,
}
function FbTrialSpirit:isEncounterFinished(pPlayer) return false end
function FbTrialSpirit:onEncounterSpawned(pPlayer, spawned) record(pPlayer, spawned, "fb_trial_spirit", self.encounterDespawnTime) end
function FbTrialSpirit:onEncounterInRange(pPlayer, spawned)
	if spawned ~= nil and spawned[1] ~= nil then spatialChat(spawned[1], "@fb_force:spirit_greeting") end
end
function FbTrialSpirit:belongsTo(pPlayer, pNpc) return pPlayer ~= nil and pNpc ~= nil and SpawnMobiles.isFromSpawn(pPlayer, self.taskName, pNpc) end
function FbTrialSpirit:scheduleDespawn(pPlayer) if pPlayer ~= nil then createEvent(8000, self.taskName, "handleDespawnEvent", pPlayer, "") end end
function FbTrialSpirit:doDespawn(pPlayer) unfollowAndDespawn(self, pPlayer) end

-- the duel: one Sith Shadow matched to the character's level
FbTrialDuel = Encounter:new {
	taskName = "FbTrialDuel",
	encounterDespawnTime = 5 * 60 * 1000,
	despawnMessage = "@fb_force:shadow_gone",
	spawnObjectList = { { template = "sith_shadow_outlaw", minimumDistance = 40, maximumDistance = 60, referencePoint = 0, followPlayer = true, setNotAttackable = false, runOnDespawn = true } },
	inRangeValue = 20,
}
function FbTrialDuel:isEncounterFinished(pPlayer) return false end
function FbTrialDuel:taskStart(pPlayer)
	local lvl = CreatureObject(pPlayer):getLevel()
	self.spawnObjectList[1].template = lvl >= 65 and "sith_shadow_mercenary" or lvl >= 45 and "sith_shadow_thug" or lvl >= 25 and "sith_shadow_pirate" or "sith_shadow_outlaw"
	return Encounter.taskStart(self, pPlayer)
end
function FbTrialDuel:onEncounterSpawned(pPlayer, spawned)
	record(pPlayer, spawned, self.spawnObjectList[1].template, self.encounterDespawnTime)
	for _, pMob in ipairs(spawned or {}) do if pMob ~= nil then createObserver(OBJECTDESTRUCTION, self.taskName, "onDuelDown", pMob) end end
	dropObserver(OBJECTDESTRUCTION, self.taskName, "onPlayerDown", pPlayer); createObserver(OBJECTDESTRUCTION, self.taskName, "onPlayerDown", pPlayer)
end
function FbTrialDuel:onEncounterInRange(pPlayer, spawned)
	if spawned == nil or spawned[1] == nil then return end
	for _, pMob in ipairs(spawned) do
		if pMob ~= nil then AiAgent(pMob):removeObjectFlag(AI_ESCORT); AiAgent(pMob):removeObjectFlag(AI_FOLLOW); AiAgent(pMob):setAITemplate(); AiAgent(pMob):addDefender(pPlayer) end
	end
	local msg = LuaStringIdChatParameter("@fb_force:duel_threaten"); msg:setTT(CreatureObject(pPlayer):getFirstName())
	spatialChat(spawned[1], msg:_getObject())
end
function FbTrialDuel:onDuelDown(pMob, pKiller)
	if pMob == nil then return 1 end
	local owner = readData(SceneObject(pMob):getObjectID() .. ":fbTrialFor")
	local pPlayer = owner ~= 0 and getSceneObject(owner) or nil
	if pPlayer == nil then return 1 end
	if CreatureObject(pPlayer):isGrouped() then
		say(pPlayer, "trial_duel_grouped")
	elseif not CreatureObject(pPlayer):isDead() and not CreatureObject(pPlayer):isIncapacitated() then
		FbTrials:complete(pPlayer, "duel")
	end
	createEvent(10000, self.taskName, "handleDespawnEvent", pPlayer, "")
	return 1
end
function FbTrialDuel:onPlayerDown(pPlayer)
	if pPlayer ~= nil then createEvent(20000, self.taskName, "handleDespawnEvent", pPlayer, "") end
	return 1
end
function FbTrialDuel:doDespawn(pPlayer) unfollowAndDespawn(self, pPlayer) end
function FbTrialDuel:onEncounterDespawned(pPlayer) if pPlayer ~= nil then dropObserver(OBJECTDESTRUCTION, self.taskName, "onPlayerDown", pPlayer) end end
