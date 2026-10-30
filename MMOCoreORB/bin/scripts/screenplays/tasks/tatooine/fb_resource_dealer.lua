-- fb_resource_dealer.lua — Final Boss 2.14: raw resource dealer (Mehra Tulk, Mos Eisley Trade Hall, foyer).
--
-- Sells units of every resource currently in shift on the ten planets, grouped by family, the best of each class
-- first (quality = the mean of the spawn's attributes). The stack is the real spawn's resource container (the Lua
-- global givePlayerResourceNamed, the admin /giveresource path), so it crafts like anything a harvester pulls.
-- The catalogue is read from the server (getResourceSpawns without the best-spot scan) and cached five minutes per
-- Lua state; a window keeps its choices in quest status because SUI callbacks run on whichever thread handles them.
-- purchase(pPlayer, spawnName, units) is public for the lab.
FbResourceDealer = ScreenPlay:new {
	screenplayName = "FbResourceDealer",
}

FbResourceDealer.planets = { "tatooine", "naboo", "corellia", "talus", "rori", "lok", "dantooine", "dathomir", "endor", "yavin4" }
FbResourceDealer.amounts = { 1000, 5000, 20000, 100000 }
FbResourceDealer.pricePerUnit = 1          -- credits a unit (a harvester gives a few hundred an hour for free; this is convenience)
FbResourceDealer.cacheSeconds = 300

function FbResourceDealer:start() end

-- catalogue() -> { { name = family, items = { { name, type, class, family, quality, planets = {…} }, … } }, … } sorted
function FbResourceDealer:catalogue()
	local now = os.time()
	if self._cat ~= nil and now - (self._catAt or 0) < self.cacheSeconds then return self._cat end
	local byName = {}
	for _, planet in ipairs(self.planets) do
		if isZoneEnabled(planet) then
			local rows = getResourceSpawns(planet, true) or {}
			for _, r in ipairs(rows) do
				local e = byName[r.name]
				if e == nil then
					local sum, n = 0, 0
					for _, v in pairs(r.attributes or {}) do sum = sum + v; n = n + 1 end
					e = { name = r.name, type = r.type, class = r.finalClass or r.type, family = r.family or "other",
						quality = n > 0 and math.floor(sum / n) or 0, planets = {} }
					byName[r.name] = e
				end
				table.insert(e.planets, planet)
			end
		end
	end
	local families, index = {}, {}
	for _, e in pairs(byName) do
		local f = index[e.family]
		if f == nil then f = { name = e.family, items = {} }; index[e.family] = f; table.insert(families, f) end
		table.insert(f.items, e)
	end
	table.sort(families, function(a, b) return a.name < b.name end)
	for _, f in ipairs(families) do
		table.sort(f.items, function(a, b)
			if a.class ~= b.class then return a.class < b.class end
			if a.quality ~= b.quality then return a.quality > b.quality end
			return a.name < b.name
		end)
	end
	self._cat, self._catAt = families, now
	return families
end

function FbResourceDealer:family(name)
	for _, f in ipairs(self:catalogue()) do if f.name == name then return f end end
	return nil
end

function FbResourceDealer:spawn(name)
	for _, f in ipairs(self:catalogue()) do
		for _, e in ipairs(f.items) do if e.name == name then return e end end
	end
	return nil
end

-- purchase(pPlayer, spawnName, units) -> "ok" | "no_credits" | "inventory_full" | "bad_item" | "failed"
function FbResourceDealer:purchase(pPlayer, spawnName, units)
	if pPlayer == nil then return "failed" end
	units = tonumber(units) or 0
	local e = self:spawn(spawnName)
	if e == nil or units <= 0 then return "bad_item" end
	local price = math.ceil(units * self.pricePerUnit)
	local creature = CreatureObject(pPlayer)
	if creature:getCashCredits() < price then
		creature:sendSystemMessage("Not enough cash for " .. units .. " units of " .. e.name .. ". Need " .. price .. " cr.")
		return "no_credits"
	end
	local pInventory = creature:getSlottedObject("inventory")
	if pInventory == nil or SceneObject(pInventory):isContainerFullRecursive() then
		creature:sendSystemMessage("Your inventory is full.")
		return "inventory_full"
	end
	if not givePlayerResourceNamed(pPlayer, e.name, units) then
		creature:sendSystemMessage("Mehra checks her ledger: " .. e.name .. " has left the ground. The list is stale, ask again.")
		self._cat = nil
		return "failed"
	end
	creature:subtractCashCredits(price)
	creature:sendSystemMessage("Purchased " .. units .. " units of " .. e.name .. " (" .. e.class .. ") for " .. price .. " credits.")
	return "ok"
end

-- ---- windows: family -> spawn -> amount; the choices ride in quest status keyed by the player oid ------------
local function key(pPlayer, what) return "FbResourceDealer." .. SceneObject(pPlayer):getObjectID() .. "." .. what end

function FbResourceDealer:showList(pPlayer, pNpc)
	if pPlayer == nil then return end
	local families = self:catalogue()
	local pSui = SuiListBox.new("FbResourceDealer", "onFamilyPicked")
	pSui.setTitle("Resource Dealer")
	pSui.setPrompt("Every resource in shift on the ten worlds. " .. self.pricePerUnit .. " cr a unit, cash only. Pick a family.")
	for _, f in ipairs(families) do
		pSui.add(f.name .. "  (" .. #f.items .. " in shift)", "")
	end
	pSui.sendTo(pPlayer)
end

function FbResourceDealer:onFamilyPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local idx = tonumber(args)
	if idx == nil then return end
	local f = self:catalogue()[idx + 1]
	if f == nil then return end
	setQuestStatus(key(pPlayer, "family"), f.name)
	local pInner = SuiListBox.new("FbResourceDealer", "onSpawnPicked")
	pInner.setTitle(f.name)
	pInner.setPrompt("Best of each class first. Quality is the mean of the spawn's stats (0-1000).")
	for _, e in ipairs(f.items) do
		pInner.add(e.name .. " — " .. e.class .. ", q" .. e.quality .. " (" .. table.concat(e.planets, ", ") .. ")", "")
	end
	pInner.sendTo(pPlayer)
end

function FbResourceDealer:onSpawnPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local idx = tonumber(args)
	if idx == nil then return end
	local f = self:family(getQuestStatus(key(pPlayer, "family")) or "")
	local e = f and f.items[idx + 1]
	if e == nil then return end
	setQuestStatus(key(pPlayer, "spawn"), e.name)
	local pAmt = SuiListBox.new("FbResourceDealer", "onAmountPicked")
	pAmt.setTitle(e.name)
	pAmt.setPrompt(e.class .. ", quality " .. e.quality .. ". How many units?")
	for _, n in ipairs(self.amounts) do
		pAmt.add("[" .. math.ceil(n * self.pricePerUnit) .. " cr] " .. n .. " units", "")
	end
	pAmt.sendTo(pPlayer)
end

function FbResourceDealer:onAmountPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local idx = tonumber(args)
	local n = idx and self.amounts[idx + 1]
	if n == nil then return end
	self:purchase(pPlayer, getQuestStatus(key(pPlayer, "spawn")) or "", n)
end
