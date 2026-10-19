-- fb_site_builder.lua — architect mode on the Lab Remote (Phase 2.12b).
--
-- Design a site standing in the world: preview a stock building where you stand (facing chosen from a
-- list), check the lot against the stock footprints around it and the terrain under it, nudge and rotate
-- it, place tenants from inside (your position becomes room coordinates, checked against the furniture),
-- place outdoor NPCs, then export the draft as a site file (screenplays/tasks/sites/<name>.lua) that
-- FbSites rebuilds at every boot. `tools/swg site save <char> <name>` writes the exported text into the
-- repo. Previews and draft NPCs are ordinary non-persistent spawns: a restart clears an unsaved draft.
--
-- Lua-state note: the draft lives in quest status (FbSiteDraft.<playerOid>), never in Lua tables, because
-- every window callback may run on a different thread. World data: FbWorldData (tools/lotsurvey export).

FbSiteBuilder = ScreenPlay:new {
	screenplayName = "FbSiteBuilder",
	gap = 3,          -- metres kept between the new footprint and a neighbour's
	body = 0.35,      -- an NPC inside a piece of furniture when closer than this
	margin = 0.8,     -- a warning when closer than this
}

registerScreenPlay("FbSiteBuilder", true)

function FbSiteBuilder:start() end

-- ---------------------------------------------------------------- draft (quest status)

local function dkey(pPlayer, what) return "FbSiteDraft." .. SceneObject(pPlayer):getObjectID() .. "." .. what end

local function say(pPlayer, text) CreatureObject(pPlayer):sendSystemMessage("[site] " .. text) end

local function split(s, sep)
	local out = {}
	for part in (s or ""):gmatch("[^" .. sep .. "]+") do out[#out + 1] = part end
	return out
end

-- draft record: fields in one quest status, lists in two more
function FbSiteBuilder:draft(pPlayer)
	local raw = getQuestStatus(dkey(pPlayer, "site"))
	if raw == nil or raw == "" then return nil end
	local f = split(raw, "|")
	local d = { name = f[1], planet = f[2], template = f[3], x = tonumber(f[4]), y = tonumber(f[5]), heading = tonumber(f[6]), preview = tonumber(f[7]) or 0, tenants = {}, outside = {} }
	for _, rec in ipairs(split(getQuestStatus(dkey(pPlayer, "tenants")), ";")) do
		local t = split(rec, "|")
		d.tenants[#d.tenants + 1] = { template = t[1], room = t[2], x = tonumber(t[3]), z = tonumber(t[4]), y = tonumber(t[5]), dir = tonumber(t[6]), oid = tonumber(t[7]) or 0 }
	end
	for _, rec in ipairs(split(getQuestStatus(dkey(pPlayer, "outside")), ";")) do
		local t = split(rec, "|")
		d.outside[#d.outside + 1] = { template = t[1], x = tonumber(t[2]), z = tonumber(t[3]), y = tonumber(t[4]), dir = tonumber(t[5]), oid = tonumber(t[6]) or 0 }
	end
	return d
end

function FbSiteBuilder:saveDraft(pPlayer, d)
	setQuestStatus(dkey(pPlayer, "site"), table.concat({ d.name, d.planet, d.template, string.format("%.1f", d.x), string.format("%.1f", d.y), string.format("%.0f", d.heading), tostring(d.preview or 0) }, "|"))
	local t = {}
	for _, e in ipairs(d.tenants) do t[#t + 1] = string.format("%s|%s|%.2f|%.2f|%.2f|%.0f|%d", e.template, e.room, e.x, e.z, e.y, e.dir, e.oid or 0) end
	setQuestStatus(dkey(pPlayer, "tenants"), table.concat(t, ";"))
	local o = {}
	for _, e in ipairs(d.outside) do o[#o + 1] = string.format("%s|%.1f|%.2f|%.1f|%.0f|%d", e.template, e.x, e.z, e.y, e.dir, e.oid or 0) end
	setQuestStatus(dkey(pPlayer, "outside"), table.concat(o, ";"))
end

function FbSiteBuilder:clearDraft(pPlayer)
	removeQuestStatus(dkey(pPlayer, "site")); removeQuestStatus(dkey(pPlayer, "tenants")); removeQuestStatus(dkey(pPlayer, "outside"))
end

-- ---------------------------------------------------------------- geometry

local function headingOf(pObj) return SceneObject(pObj):getDirectionAngle() % 360 end

-- The game data (snapshot, FbWorldData) names a building by its client template, object/…/shared_x.iff;
-- the server spawns the matching server template, object/…/x.iff. Keep both forms at hand.
function FbSiteBuilder.clientForm(t) return (t:gsub("/([^/]+)$", function(f) return f:find("^shared_") and "/" .. f or "/shared_" .. f end)) end
function FbSiteBuilder.serverForm(t) return (t:gsub("/shared_([^/]+)$", "/%1")) end
local function shellData(t) return FbWorldData and (FbWorldData.shells[FbSiteBuilder.clientForm(t)] or FbWorldData.shells[t]) or nil end
local function footprintRadius(t) return FbWorldData and (FbWorldData.footprints[FbSiteBuilder.clientForm(t)] or FbWorldData.footprints[t]) or nil end

-- building-local (x forward-right frame) -> world, for a building at (bx, by) with heading h
local function toWorld(bx, by, h, lx, ly)
	local a = math.rad(h)
	return bx + lx * math.cos(a) + ly * math.sin(a), by - lx * math.sin(a) + ly * math.cos(a)
end

-- distance from a point to a convex polygon, 0 inside; winding-agnostic (all cross products share a sign)
local function distPointRect(px, py, poly)
	local pos, neg, best = 0, 0, 1e9
	for i = 1, #poly do
		local ax, ay = poly[i][1], poly[i][2]
		local bx, by = poly[i % #poly + 1][1], poly[i % #poly + 1][2]
		local ex, ey = bx - ax, by - ay
		local t = math.max(0, math.min(1, ((px - ax) * ex + (py - ay) * ey) / (ex * ex + ey * ey)))
		best = math.min(best, math.sqrt((px - (ax + t * ex)) ^ 2 + (py - (ay + t * ey)) ^ 2))
		local cross = ex * (py - ay) - ey * (px - ax)
		if cross > 0 then pos = pos + 1 elseif cross < 0 then neg = neg + 1 end
	end
	if pos == 0 or neg == 0 then return 0 end
	return best
end

-- The lot report for a shell at (x, y, heading) on the player's planet: neighbours within reach (from
-- the server's own structure list + FbWorldData footprints) and the terrain under the corners.
-- Returns verdict ("ok" | "warn" | "fail"), lines.
function FbSiteBuilder:lotReport(pPlayer, template, x, y, heading, ignoreOid)
	local zone = SceneObject(pPlayer):getZoneName()
	local shell = shellData(template)
	local fp = shell and shell.footprint or { x0 = -12, x1 = 12, y0 = -12, y1 = 12 }
	local lines, verdict = {}, "ok"
	local poly = {}
	for _, c in ipairs({ { fp.x0, fp.y0 }, { fp.x1, fp.y0 }, { fp.x1, fp.y1 }, { fp.x0, fp.y1 } }) do
		local wx, wy = toWorld(x, y, heading, c[1], c[2])
		poly[#poly + 1] = { wx, wy }
	end
	-- terrain under the corners and the centre
	local z0 = getTerrainHeightAt(zone, x, y)
	local worst = 0
	for _, c in ipairs(poly) do worst = math.max(worst, math.abs(getTerrainHeightAt(zone, c[1], c[2]) - z0)) end
	lines[#lines + 1] = string.format("terrain: corners within %.1f m of the centre height", worst)
	if worst > 3 then verdict = "fail" elseif worst > 1.5 then verdict = "warn" end
	-- neighbours
	local reach = math.max(math.abs(fp.x0), math.abs(fp.x1), math.abs(fp.y0), math.abs(fp.y1))
	local near = SceneObject(pPlayer):getStructuresInRange(reach + 120)
	local clashes = 0
	for _, pS in ipairs(near or {}) do
		local so = SceneObject(pS)
		local tmpl = so:getTemplateObjectPath()
		local r = footprintRadius(tmpl) or 22
		if so:getObjectID() == ignoreOid then r = -1e9 end   -- the draft's own preview is not a neighbour
		local d = distPointRect(so:getWorldPositionX(), so:getWorldPositionY(), poly)
		if d < r + self.gap then
			clashes = clashes + 1
			if clashes <= 6 then lines[#lines + 1] = string.format("CLASH %s at %.0f,%.0f (radius %.0f, %.1f m from the new footprint)", tmpl:match("([^/]+)%.iff$") or tmpl, so:getWorldPositionX(), so:getWorldPositionY(), r, d) end
		end
	end
	if clashes > 0 then verdict = "fail"; lines[#lines + 1] = clashes .. " neighbouring structure(s) overlap the footprint (+" .. self.gap .. " m)"
	else lines[#lines + 1] = "no stock structure within " .. self.gap .. " m of the footprint" end
	if shell == nil then lines[#lines + 1] = "no footprint data for this shell (FbWorldData): used a 24 m box" end
	return verdict, lines
end

-- Furniture clearance of a room-local spot (building-local frame == cell-local frame).
function FbSiteBuilder:spotReport(template, room, x, y)
	local furniture = FbWorldData and (FbWorldData.loadFurniture()[FbSiteBuilder.clientForm(template)] or FbWorldData.furniture[template]) or nil
	if furniture == nil then return "ok", "no furniture data for this shell" end
	local best, bestName = 1e9, nil
	for _, f in ipairs(furniture) do
		if f[1] == room then
			local a = math.rad(-f[4])
			local dx, dy = x - f[2], y - f[3]
			local lx = dx * math.cos(a) - dy * math.sin(a)
			local ly = dx * math.sin(a) + dy * math.cos(a)
			local ox = math.max(f[5] - lx, 0, lx - f[7])
			local oy = math.max(f[6] - ly, 0, ly - f[8])
			local d = math.sqrt(ox * ox + oy * oy)
			if d < best then best, bestName = d, string.format("piece at %.1f,%.1f", f[2], f[3]) end
		end
	end
	if bestName == nil then return "ok", "no furniture in this room" end
	if best <= self.body then return "fail", string.format("inside furniture (%s)", bestName) end
	if best < self.margin then return "warn", string.format("%.2f m from %s", best, bestName) end
	return "ok", string.format("%.1f m from the nearest piece", best)
end

-- ---------------------------------------------------------------- the draft's objects

function FbSiteBuilder:destroyOid(oid)
	if oid == nil or oid == 0 then return end
	local p = getSceneObject(oid)
	if p ~= nil then
		SceneObject(p):destroyObjectFromWorld(true)
		SceneObject(p):destroyObjectFromDatabase()
	end
end

-- (re)spawn the preview building and every draft NPC from the draft record
function FbSiteBuilder:respawn(pPlayer, d)
	for _, t in ipairs(d.tenants) do self:destroyOid(t.oid); t.oid = 0 end
	for _, o in ipairs(d.outside) do self:destroyOid(o.oid); o.oid = 0 end
	self:destroyOid(d.preview); d.preview = 0
	local z = getTerrainHeightAt(d.planet, d.x, d.y)
	local rad = math.rad(d.heading)
	local pB = spawnSceneObject(d.planet, FbSiteBuilder.serverForm(d.template), d.x, z, d.y, 0, math.cos(rad / 2), 0, math.sin(rad / 2), 0)
	if pB == nil then say(pPlayer, "could not spawn " .. FbSiteBuilder.serverForm(d.template)); self:saveDraft(pPlayer, d); return nil end
	d.preview = SceneObject(pB):getObjectID()
	for _, t in ipairs(d.tenants) do
		local pCell = self:cellByName(pB, t.room)
		if pCell ~= nil then
			local pN = spawnMobile(d.planet, t.template, 0, t.x, t.z, t.y, t.dir, SceneObject(pCell):getObjectID())
			if pN ~= nil then t.oid = SceneObject(pN):getObjectID() end
		end
	end
	for _, o in ipairs(d.outside) do
		local pN = spawnMobile(d.planet, o.template, 0, o.x, o.z, o.y, o.dir, 0)
		if pN ~= nil then o.oid = SceneObject(pN):getObjectID() end
	end
	self:saveDraft(pPlayer, d)
	return pB
end

function FbSiteBuilder:cellByName(pBuilding, room)
	local n = BuildingObject(pBuilding):getTotalCellNumber()
	for i = 1, n do
		if BuildingObject(pBuilding):getCellName(i) == room then return BuildingObject(pBuilding):getCell(i) end
	end
	return nil
end

function FbSiteBuilder:roomOf(pBuilding, cellOid)
	local n = BuildingObject(pBuilding):getTotalCellNumber()
	for i = 1, n do
		local pC = BuildingObject(pBuilding):getCell(i)
		if pC ~= nil and SceneObject(pC):getObjectID() == cellOid then return BuildingObject(pBuilding):getCellName(i) end
	end
	return nil
end

-- ---------------------------------------------------------------- operations (also the lab oracles' entry points)

-- A new draft: shell at the player's position with the given heading (number of degrees, or "toward_me"
-- = entrance side toward the player is meaningless at the origin, so "face_me" turns the entrance toward
-- the direction the player faces + 180, i.e. the door looks back at where the player came from).
function FbSiteBuilder:newSite(pPlayer, template, heading, name)
	local old = self:draft(pPlayer)
	if old ~= nil then self:discard(pPlayer) end
	local so = SceneObject(pPlayer)
	if so:getParentID() ~= 0 then say(pPlayer, "stand outdoors where the building's centre should be"); return nil end
	local h = tonumber(heading)
	if h == nil then h = (headingOf(pPlayer) + 180) % 360 end
	local d = { name = name or ("site_" .. os.time()), planet = so:getZoneName(), template = FbSiteBuilder.serverForm(template), x = so:getWorldPositionX(), y = so:getWorldPositionY(), heading = h, preview = 0, tenants = {}, outside = {} }
	local pB = self:respawn(pPlayer, d)
	if pB == nil then return nil end
	local verdict, lines = self:lotReport(pPlayer, template, d.x, d.y, d.heading, d.preview)
	say(pPlayer, string.format("preview of %s at %.0f,%.0f heading %.0f — lot %s", template:match("([^/]+)%.iff$") or template, d.x, d.y, d.heading, string.upper(verdict)))
	for _, l in ipairs(lines) do say(pPlayer, l) end
	return d, verdict, lines
end

-- op: forward|back|left|right <metres>, rotate <degrees>, here (origin to the player), face_me
function FbSiteBuilder:nudge(pPlayer, op, amount)
	local d = self:draft(pPlayer)
	if d == nil then say(pPlayer, "no draft: start with 'New site here'"); return nil end
	amount = tonumber(amount) or 1
	local a = math.rad(d.heading)
	if op == "forward" then d.x, d.y = d.x + amount * math.sin(a), d.y + amount * math.cos(a)
	elseif op == "back" then d.x, d.y = d.x - amount * math.sin(a), d.y - amount * math.cos(a)
	elseif op == "right" then d.x, d.y = d.x + amount * math.cos(a), d.y - amount * math.sin(a)
	elseif op == "left" then d.x, d.y = d.x - amount * math.cos(a), d.y + amount * math.sin(a)
	elseif op == "rotate" then d.heading = (d.heading + amount) % 360
	elseif op == "here" then
		if SceneObject(pPlayer):getParentID() ~= 0 then say(pPlayer, "stand outdoors to move the origin here"); return nil end
		d.x, d.y = SceneObject(pPlayer):getWorldPositionX(), SceneObject(pPlayer):getWorldPositionY()
	elseif op == "face_me" then
		local dx, dy = SceneObject(pPlayer):getWorldPositionX() - d.x, SceneObject(pPlayer):getWorldPositionY() - d.y
		d.heading = math.deg(math.atan(dx, dy)) % 360
	else say(pPlayer, "unknown nudge " .. tostring(op)); return nil end
	self:respawn(pPlayer, d)
	local verdict, lines = self:lotReport(pPlayer, d.template, d.x, d.y, d.heading, d.preview)
	say(pPlayer, string.format("now at %.1f,%.1f heading %.0f — lot %s", d.x, d.y, d.heading, string.upper(verdict)))
	for _, l in ipairs(lines) do say(pPlayer, l) end
	return d, verdict, lines
end

-- A tenant where the player stands (inside the preview), facing the player's way. Returns the record.
function FbSiteBuilder:addTenant(pPlayer, template, label)
	local d = self:draft(pPlayer)
	if d == nil then say(pPlayer, "no draft"); return nil end
	local so = SceneObject(pPlayer)
	local cell = so:getParentID()
	if cell == 0 then say(pPlayer, "stand inside the preview building to place a tenant (use 'Add outdoor NPC' outside)"); return nil end
	local pB = getSceneObject(d.preview)
	local room = pB ~= nil and self:roomOf(pB, cell) or nil
	if room == nil then say(pPlayer, "you are not inside the draft's building"); return nil end
	local t = { template = template, label = label, room = room, x = so:getPositionX(), z = so:getPositionZ(), y = so:getPositionY(), dir = headingOf(pPlayer), oid = 0 }
	local verdict, why = self:spotReport(d.template, room, t.x, t.y)
	local pN = spawnMobile(d.planet, template, 0, t.x, t.z, t.y, t.dir, cell)
	if pN == nil then say(pPlayer, "could not spawn " .. template); return nil end
	t.oid = SceneObject(pN):getObjectID()
	d.tenants[#d.tenants + 1] = t
	self:saveDraft(pPlayer, d)
	say(pPlayer, string.format("tenant %d: %s in '%s' at x=%.1f z=%.2f y=%.1f dir=%.0f — furniture %s (%s)", #d.tenants, template, room, t.x, t.z, t.y, t.dir, string.upper(verdict), why))
	return t, verdict, why
end

function FbSiteBuilder:addOutside(pPlayer, template)
	local d = self:draft(pPlayer)
	if d == nil then say(pPlayer, "no draft"); return nil end
	local so = SceneObject(pPlayer)
	if so:getParentID() ~= 0 then say(pPlayer, "stand outdoors to place an outdoor NPC"); return nil end
	local o = { template = template, x = so:getWorldPositionX(), z = so:getWorldPositionZ(), y = so:getWorldPositionY(), dir = headingOf(pPlayer), oid = 0 }
	local pN = spawnMobile(d.planet, template, 0, o.x, o.z, o.y, o.dir, 0)
	if pN == nil then say(pPlayer, "could not spawn " .. template); return nil end
	o.oid = SceneObject(pN):getObjectID()
	d.outside[#d.outside + 1] = o
	self:saveDraft(pPlayer, d)
	say(pPlayer, string.format("outdoor NPC %d: %s at %.1f,%.1f dir %.0f", #d.outside, template, o.x, o.y, o.dir))
	return o
end

function FbSiteBuilder:removeLast(pPlayer)
	local d = self:draft(pPlayer)
	if d == nil then return end
	local t = table.remove(d.tenants)
	if t ~= nil then self:destroyOid(t.oid); say(pPlayer, "removed tenant " .. t.template) else say(pPlayer, "no tenants in the draft") end
	self:saveDraft(pPlayer, d)
end

function FbSiteBuilder:discard(pPlayer)
	local d = self:draft(pPlayer)
	if d == nil then return end
	for _, t in ipairs(d.tenants) do self:destroyOid(t.oid) end
	for _, o in ipairs(d.outside) do self:destroyOid(o.oid) end
	self:destroyOid(d.preview)
	self:clearDraft(pPlayer)
	say(pPlayer, "draft discarded")
end

function FbSiteBuilder:rename(pPlayer, name)
	local d = self:draft(pPlayer)
	if d == nil then return end
	d.name = name:gsub("[^%w_]", "_"):lower()
	self:saveDraft(pPlayer, d)
end

-- The site file text for the draft (what FbSites:add expects).
function FbSiteBuilder:siteText(d)
	local out = {}
	local shell = d.template:match("([^/]+)%.iff$") or d.template
	out[#out + 1] = string.format("-- Site %s: %s on %s, drafted in game with the Lab Remote's site builder.", d.name, shell, d.planet)
	out[#out + 1] = "FbSites:add {"
	out[#out + 1] = string.format('\tname = "%s",', d.name)
	out[#out + 1] = string.format('\tlabel = "%s",', (d.name:gsub("_", " "):gsub("^%l", string.upper)))
	out[#out + 1] = string.format('\tplanet = "%s",', d.planet)
	out[#out + 1] = string.format('\ttemplate = "%s",', d.template)
	out[#out + 1] = string.format("\tx = %.1f, y = %.1f, heading = %.0f,", d.x, d.y, d.heading)
	local sd = shellData(d.template)
	local front = sd and sd.footprint and sd.footprint.y1 or 10
	out[#out + 1] = string.format("\tdoor = { dx = 0, dy = %.0f },   -- entrance side of the footprint; adjust if the door is elsewhere", front * 0.5)
	out[#out + 1] = "\ttenants = {"
	for _, t in ipairs(d.tenants) do
		out[#out + 1] = string.format('\t\t{ template = "%s", label = "%s", room = "%s", x = %.2f, z = %.2f, y = %.2f, dir = %.0f },', t.template, t.label or t.template, t.room, t.x, t.z, t.y, t.dir)
	end
	out[#out + 1] = "\t},"
	out[#out + 1] = "\toutside = {"
	for _, o in ipairs(d.outside) do
		out[#out + 1] = string.format('\t\t{ template = "%s", x = %.1f, z = %.2f, y = %.1f, dir = %.0f },', o.template, o.x, o.z, o.y, o.dir)
	end
	out[#out + 1] = "\t},"
	out[#out + 1] = "}"
	return out
end

-- ---------------------------------------------------------------- windows (from the Lab Remote)

local function msg(pPlayer, title, lines)
	local sui = SuiMessageBox.new("FbSiteBuilder", "noop")
	sui.setTitle(title)
	sui.setPrompt(table.concat(lines, "\n"))
	sui.hideCancelButton()
	sui.sendTo(pPlayer)
end

function FbSiteBuilder:noop() end

-- shells for a planet: the stock buildings whose path names the planet (its architecture), or all
function FbSiteBuilder:shellList(planet, all)
	local list = {}
	if FbWorldData == nil then return list end
	for tmpl, _ in pairs(FbWorldData.shells) do
		if all or tmpl:find("/" .. planet .. "/", 1, true) then list[#list + 1] = tmpl end
	end
	table.sort(list)
	return list
end

FbSiteBuilder.menu = {
	{ "New site here…", "new" },
	{ "New site here (any planet's shells)…", "newall" },
	{ "Nudge / rotate the preview…", "nudge" },
	{ "Add tenant here (inside)…", "tenant" },
	{ "Add outdoor NPC here…", "outside" },
	{ "Remove the last tenant", "removelast" },
	{ "Name the site…", "rename" },
	{ "Show the draft (site file)", "show" },
	{ "Export the draft (then: swg site save)", "export" },
	{ "Discard the draft", "discard" },
}

function FbSiteBuilder:showMenu(pPlayer)
	local d = self:draft(pPlayer)
	local sui = SuiListBox.new("FbSiteBuilder", "onMenu")
	sui.setTitle("Site builder")
	sui.setPrompt(d and string.format("Draft '%s': %s at %.0f,%.0f heading %.0f, %d tenant(s), %d outside.", d.name, d.template:match("([^/]+)%.iff$") or d.template, d.x, d.y, d.heading, #d.tenants, #d.outside)
		or "No draft. Stand outdoors where the building's centre should be and pick 'New site here'.")
	for _, m in ipairs(self.menu) do sui.add(m[1], m[2]) end
	sui.sendTo(pPlayer)
end

function FbSiteBuilder:onMenu(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local m = self.menu[(tonumber(args) or -1) + 1]
	if m == nil then return end
	local what = m[2]
	if what == "new" or what == "newall" then
		local shells = self:shellList(SceneObject(pPlayer):getZoneName(), what == "newall")
		if #shells == 0 then msg(pPlayer, "Site builder", { "No shells for this planet in FbWorldData (try the any-planet list)." }); return end
		setQuestStatus(dkey(pPlayer, "shells"), table.concat(shells, ","))
		local sui = SuiListBox.new("FbSiteBuilder", "onShell")
		sui.setTitle("Pick a shell")
		sui.setPrompt("Stock buildings with an interior. Rooms and furniture come from the game data.")
		for _, t in ipairs(shells) do
			local sh = FbWorldData.shells[t]
			local rooms = 0
			for _ in pairs(sh.rooms) do rooms = rooms + 1 end
			sui.add(string.format("%s  (%d rooms, %.0f x %.0f m)", t:match("([^/]+)%.iff$"), rooms, sh.footprint.x1 - sh.footprint.x0, sh.footprint.y1 - sh.footprint.y0), "")
		end
		sui.sendTo(pPlayer)
	elseif what == "nudge" then self:showNudge(pPlayer)
	elseif what == "tenant" or what == "outside" then
		setQuestStatus(dkey(pPlayer, "placing"), what)
		local sui = SuiListBox.new("FbSiteBuilder", "onNpcPick")
		sui.setTitle(what == "tenant" and "Tenant: who stands here?" or "Outdoor NPC: who stands here?")
		sui.setPrompt("Final Boss NPC templates. The NPC spawns where you stand, facing your way.")
		local npcs = FbLabTests.discoverNpcs()
		local names = {}
		for _, n in ipairs(npcs) do names[#names + 1] = n.template end
		setQuestStatus(dkey(pPlayer, "npcs"), table.concat(names, ","))
		for _, n in ipairs(names) do sui.add(n, "") end
		sui.sendTo(pPlayer)
	elseif what == "removelast" then self:removeLast(pPlayer)
	elseif what == "rename" then
		local sui = SuiInputBox.new("FbSiteBuilder", "onRename")
		sui.setTitle("Name the site")
		sui.setPrompt("A file name: letters, digits, underscores (mos_eisley_weapon_shop).")
		sui.sendTo(pPlayer)
	elseif what == "show" or what == "export" then
		local d = self:draft(pPlayer)
		if d == nil then msg(pPlayer, "Site builder", { "No draft." }); return end
		local lines = self:siteText(d)
		if what == "export" then
			setQuestStatus(dkey(pPlayer, "export"), table.concat(lines, "\n"))
			say(pPlayer, string.format("draft '%s' exported — ask Claude: swg site save %s %s", d.name, CreatureObject(pPlayer):getFirstName(), d.name))
		end
		msg(pPlayer, "Site file: " .. d.name, lines)
	elseif what == "discard" then self:discard(pPlayer)
	end
end

FbSiteBuilder.facings = {
	{ "Entrance toward where I look", "look" },
	{ "Entrance toward me (door looks back at me)", "face" },
	{ "North (0)", "0" }, { "East (90)", "90" }, { "South (180)", "180" }, { "West (270)", "270" },
}

function FbSiteBuilder:onShell(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local shells = split(getQuestStatus(dkey(pPlayer, "shells")), ",")
	local t = shells[(tonumber(args) or -1) + 1]
	if t == nil then return end
	setQuestStatus(dkey(pPlayer, "shell"), t)
	local sui = SuiListBox.new("FbSiteBuilder", "onFacing")
	sui.setTitle("Which way does the entrance face?")
	sui.setPrompt(t:match("([^/]+)%.iff$") .. " will be previewed with its centre where you stand.")
	for _, f in ipairs(self.facings) do sui.add(f[1], f[2]) end
	sui.sendTo(pPlayer)
end

function FbSiteBuilder:onFacing(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local f = self.facings[(tonumber(args) or -1) + 1]
	local t = getQuestStatus(dkey(pPlayer, "shell"))
	if f == nil or t == nil or t == "" then return end
	local heading
	if f[2] == "look" then heading = headingOf(pPlayer)
	elseif f[2] == "face" then heading = (headingOf(pPlayer) + 180) % 360
	else heading = tonumber(f[2]) end
	local d, verdict, lines = self:newSite(pPlayer, t, heading)
	if d ~= nil then msg(pPlayer, "Preview: lot " .. string.upper(verdict), lines) end
end

FbSiteBuilder.nudges = {
	{ "Forward 1 m", "forward", 1 }, { "Forward 5 m", "forward", 5 }, { "Back 1 m", "back", 1 }, { "Back 5 m", "back", 5 },
	{ "Left 1 m", "left", 1 }, { "Left 5 m", "left", 5 }, { "Right 1 m", "right", 1 }, { "Right 5 m", "right", 5 },
	{ "Rotate +15", "rotate", 15 }, { "Rotate -15", "rotate", -15 }, { "Rotate +90", "rotate", 90 },
	{ "Entrance toward me", "face_me", 0 }, { "Move the centre to where I stand", "here", 0 },
}

function FbSiteBuilder:showNudge(pPlayer)
	local sui = SuiListBox.new("FbSiteBuilder", "onNudge")
	sui.setTitle("Nudge / rotate")
	sui.setPrompt("Forward is the entrance direction. The preview and its tenants are respawned each time.")
	for _, n in ipairs(self.nudges) do sui.add(n[1], "") end
	sui.sendTo(pPlayer)
end

function FbSiteBuilder:onNudge(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local n = self.nudges[(tonumber(args) or -1) + 1]
	if n == nil then return end
	local d, verdict, lines = self:nudge(pPlayer, n[2], n[3])
	if d ~= nil then self:showNudge(pPlayer) end
end

function FbSiteBuilder:onNpcPick(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local names = split(getQuestStatus(dkey(pPlayer, "npcs")), ",")
	local t = names[(tonumber(args) or -1) + 1]
	if t == nil then return end
	if getQuestStatus(dkey(pPlayer, "placing")) == "outside" then self:addOutside(pPlayer, t) else self:addTenant(pPlayer, t) end
end

function FbSiteBuilder:onRename(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	if args ~= nil and args ~= "" then self:rename(pPlayer, tostring(args)); say(pPlayer, "draft renamed") end
end
