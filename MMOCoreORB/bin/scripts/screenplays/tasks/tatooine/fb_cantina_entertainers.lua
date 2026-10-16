-- fb_cantina_entertainers.screenplay.lua
-- Spawns Oola Var (dancer) and Figrin Bren (musician) inside cantinas.
-- Both NPCs grant the full buff package and clear Battle Fatigue.
--
-- Mos Eisley cantina interior harvested via FB Field Probe:
--   cellID 1082877, cellPos near (17.51, -0.89, 0.95)
--
-- Animation strategy:
--   * Dancer:   loops groove_01 / 02 / 03 mood strings with brief "calm"
--               pauses between, mimicking the bertos_goodner pattern used
--               in screenplays/cities/naboo_moenia.lua. Plays the standard
--               client-side dance animations without needing a full
--               EntertainingSession.
--   * Musician: sits at the bar in the "entertained" mood. The actual
--               instrument-playing animation requires a held instrument
--               and the EntertainingSession state machine, neither of
--               which is exposed to Lua. Seated + entertained reads as
--               "the band's on break, this is the front man chilling."
--               (Easy to swap to groove cycle later if you'd rather have
--               him bob in place.)

FbCantinaEntertainers = ScreenPlay:new {
	screenplayName = "FbCantinaEntertainers",
	spawns = {
		-- Mos Eisley cantina interior (cellID 1082877)
		{ which = "dancer",   planet = "tatooine", label = "Mos Eisley Cantina (Dancer)",   x = 17.00, z = -0.89, y = 0.95, dir = 1, cellID = 1082877 },
		{ which = "musician", planet = "tatooine", label = "Mos Eisley Cantina (Musician)", x = 18.50, z = -0.89, y = 0.95, dir = 1, cellID = 1082877 },
	},
}

-- Posture constants (from CreaturePosture.h)
local POSTURE_UPRIGHT  = 0
local POSTURE_SITTING  = 8

registerScreenPlay("FbCantinaEntertainers", true)

function FbCantinaEntertainers:start()
	for _, spawn in ipairs(self.spawns) do
		if isZoneEnabled(spawn.planet) then
			local mob = (spawn.which == "dancer") and "fb_cantina_dancer" or "fb_cantina_musician"
			local pMobile = spawnMobile(spawn.planet, mob, 0, spawn.x, spawn.z, spawn.y, spawn.dir, spawn.cellID or 0)
			if pMobile ~= nil then
				-- AI_STATIC + clearing AIENABLED keeps them from wandering or
				-- reacting to anything. Pattern matches naboo_moenia.lua.
				AiAgent(pMobile):addObjectFlag(AI_STATIC)
				if CreatureObject(pMobile):getPvpStatusBitmask() == 0 then
					CreatureObject(pMobile):clearOptionBit(AIENABLED)
				end

				if spawn.which == "dancer" then
					-- Kick off the dance loop after a brief settle period.
					createEvent(5000, "FbCantinaEntertainers", "startDancingEvent", pMobile, "")
				else
					-- Sit the musician at the bar and set the "entertained" mood.
					CreatureObject(pMobile):setPosture(POSTURE_SITTING)
					CreatureObject(pMobile):setMoodString("entertained")
				end
			end
		end
	end
	printf("FbCantinaEntertainers: spawned\n")
end

-- Dance loop: pick a groove, hold for 9-12s, drop to calm for 9-12s, repeat.
-- Same pattern as NabooMoeniaScreenPlay:startDancingEvent / stopDancingEvent.
function FbCantinaEntertainers:startDancingEvent(pNpc)
	if pNpc == nil then return end
	local grooveNumber = math.random(1, 3)
	local moodString = "groove_0" .. grooveNumber
	CreatureObject(pNpc):setMoodString(moodString)
	createEvent(math.random(9000, 12000), "FbCantinaEntertainers", "stopDancingEvent", pNpc, "")
end

function FbCantinaEntertainers:stopDancingEvent(pNpc)
	if pNpc == nil then return end
	CreatureObject(pNpc):setMoodString("calm")
	createEvent(math.random(9000, 12000), "FbCantinaEntertainers", "startDancingEvent", pNpc, "")
end
