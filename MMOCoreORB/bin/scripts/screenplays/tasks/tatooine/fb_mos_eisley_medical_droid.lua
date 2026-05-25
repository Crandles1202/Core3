-- fb_mos_eisley_medical_droid.screenplay.lua
-- Screenplay: spawns the FB-21 medical droid at medcenter locations across the galaxy.
--
-- Install path: MMOCoreORB/bin/scripts/screenplays/tasks/tatooine/fb_mos_eisley_medical_droid.lua
-- (Path keeps original "tatooine" subdir for git history continuity; the screenplay itself is galaxy-wide.)
--
-- Phase 2.6 MVP — Final Boss server custom content.
-- Each spawn uses the same fb_mos_eisley_medical_droid creature template,
-- so they all behave identically (same conversation, same buffs).

FbMosEisleyMedicalDroid = ScreenPlay:new {
	screenplayName = "FbMosEisleyMedicalDroid",

	-- Medical droid spawn points across the galaxy.
	--
	-- Coordinate semantics:
	--   * cellID nil/absent -> x/z/y are WORLD coords, droid spawns OUTDOORS
	--   * cellID set        -> x/z/y are CELL-LOCAL coords (relative to building
	--                          origin), droid spawns INSIDE that specific cell
	--
	-- Harvest cellIDs in-game via the FB-21 [ADMIN] debug option (admin only):
	-- talk to any existing FB-21, pick the debug option, walk into the target
	-- building during the 15-second countdown, and the system message will print
	-- the parentID + cellPos to hardcode here.
	spawns = {
		-- Tatooine
		-- Mos Eisley: INSIDE the medcenter, in the entrance/lobby cell
		{ planet = "tatooine", label = "Mos Eisley",                  x = 12.50, z = 0.18, y = -0.09,  dir = 1, cellID = 9655496 },
		-- Bestine: INSIDE the medcenter
		{ planet = "tatooine", label = "Bestine",                     x = -12.20, z = 0.18, y = -0.04,  dir = 1, cellID = 4005383 },
		-- Mos Espa: INSIDE the medcenter
		{ planet = "tatooine", label = "Mos Espa",                    x = -12.33, z = 0.18, y = -0.09, dir = 1, cellID = 4005424 },
		-- Mos Entha: INSIDE the medcenter (different building template — note larger cell)
		{ planet = "tatooine", label = "Mos Entha",                   x = -24.02, z = 0.26, y = 0.96,  dir = 1, cellID = 1153586 },
		-- Anchorhead: INSIDE the medcenter
		{ planet = "tatooine", label = "Anchorhead",                  x = 1.40,  z = 1.00, y = 5.23,  dir = 1, cellID = 1213346 },

		-- Naboo
		-- Theed: INSIDE the medcenter
		{ planet = "naboo", label = "Theed",                          x = 29.27, z = 0.26, y = 0.02,  dir = 1, cellID = 1697360 },
		-- Keren: INSIDE the medcenter
		{ planet = "naboo", label = "Keren",                          x = 29.31, z = 0.26, y = -0.08, dir = 1, cellID = 1661366 },
		-- Moenia: INSIDE the medcenter
		{ planet = "naboo", label = "Moenia",                         x = 29.10, z = 0.26, y = -0.03, dir = 1, cellID = 1717502 },

		-- Corellia
		-- Coronet: INSIDE the medcenter
		{ planet = "corellia", label = "Coronet",                     x = -23.98, z = 0.26, y = 1.16, dir = 1, cellID = 1855535 },
		-- Tyrena: INSIDE the medcenter
		{ planet = "corellia", label = "Tyrena",                      x = 29.20, z = 0.26, y = 0.27, dir = 1, cellID = 1935831 },
		-- Kor Vella: OUTDOOR (near the vehicle garage)
		{ planet = "corellia", label = "Kor Vella",                   x = -3137.85, z = 31.00, y = 2791.61, dir = 1 },
		-- Bela Vistal: INSIDE the medcenter
		{ planet = "corellia", label = "Bela Vistal",                 x = -12.29, z = 0.18, y = 0.01, dir = 1, cellID = 3375374 },
		-- Doaba Guerfel: INSIDE the medcenter
		{ planet = "corellia", label = "Doaba Guerfel",               x = -12.12, z = 0.18, y = 0.00, dir = 1, cellID = 4345354 },

		-- Talus
		-- Dearic: INSIDE the medcenter
		{ planet = "talus", label = "Dearic",                         x = -12.64, z = 0.18, y = 0.06, dir = 1, cellID = 3305354 },
		-- Nashal: INSIDE the medcenter
		{ planet = "talus", label = "Nashal",                         x = -12.06, z = 0.18, y = 0.01, dir = 1, cellID = 4265477 },

		-- Rori
		-- Narmle: INSIDE the medcenter
		{ planet = "rori", label = "Narmle",                          x = 29.20, z = 0.26, y = 0.07, dir = 1, cellID = 4635420 },
		-- Restuss: INSIDE the medcenter
		{ planet = "rori", label = "Restuss",                         x = 29.41, z = 0.26, y = 0.01, dir = 1, cellID = 4635789 },

		-- Outer rim — one per planet at the main settlement
		-- Dantooine Mining Outpost: INSIDE a small outpost building
		{ planet = "dantooine", label = "Mining Outpost",             x = 2.98, z = 0.13, y = 0.16, dir = 1, cellID = 1366007 },
		-- Nym's Stronghold: INSIDE
		{ planet = "lok",       label = "Nym's Stronghold",           x = 16.84, z = 0.26, y = 8.49, dir = 1, cellID = 2745866 },
		-- Dathomir Science Outpost: INSIDE
		{ planet = "dathomir",  label = "Science Outpost",            x = 2.89, z = 0.13, y = -0.15, dir = 1, cellID = 1392893 },
		-- Endor Smuggler Outpost: INSIDE
		{ planet = "endor",     label = "Endor Smuggler Outpost",     x = 4.60, z = 0.13, y = -3.68, dir = 1, cellID = 6705359 },
		-- Yavin IV Mining Outpost: INSIDE
		{ planet = "yavin4",    label = "Mining Outpost",             x = 4.18, z = 0.13, y = 0.60, dir = 1, cellID = 7925457 },
	},
}

registerScreenPlay("FbMosEisleyMedicalDroid", true)

function FbMosEisleyMedicalDroid:start()
	local spawned = 0
	local skipped = 0

	for _, spawn in ipairs(self.spawns) do
		if isZoneEnabled(spawn.planet) then
			spawnMobile(
				spawn.planet,
				"fb_mos_eisley_medical_droid",   -- creature template name (matches the mobile/quest/tatooine/ file)
				0,                                 -- respawn timer (0 = never despawn)
				spawn.x, spawn.z, spawn.y,
				spawn.dir,
				spawn.cellID or 0                  -- parent cellID (0 = world; non-zero = inside that cell)
			)
			spawned = spawned + 1
		else
			skipped = skipped + 1
		end
	end

	printf("FbMedicalDroidNetwork: spawned " .. spawned .. " droids (" .. skipped .. " skipped, zone disabled)\n")
end
