-- fb_resource_dealer.lua — Final Boss 2.14 / 2.14b: raw resource dealer (Mehra Tulk, Mos Eisley Trade Hall, foyer).
--
-- Sells every leaf type of the resource tree (titanium aluminum, duralloy steel, … ~ every class the game knows), grouped
-- by family. A type's stack is the best spawn of that type the server has ever known (quality = the mean of the spawn's
-- attributes; a despawned spawn keeps its object, so it can still be sold), and a type nobody has seen yet gets a fresh
-- spawn made on the spot (spawnResourceOfType: it enters the world like any shift spawn, and can be harvested too). The
-- stack is the spawn's real resource container (givePlayerResourceNamed), so it crafts like a hopper's.
-- The catalogue is read from the server (getResourceTypes, getResourceSpawnsAll) and cached five minutes per Lua state;
-- a window keeps its choices in quest status (SUI callbacks run on whichever thread handles them).
-- purchase(pPlayer, typeOrSpawn, units) is public for the lab.
FbResourceDealer = ScreenPlay:new {
	screenplayName = "FbResourceDealer",
}

FbResourceDealer.amounts = { 1000, 5000, 20000, 100000 }
FbResourceDealer.pricePerUnit = 1          -- credits a unit (a harvester gives a few hundred an hour for free; this is convenience)
FbResourceDealer.cacheSeconds = 300

function FbResourceDealer:start() end

local function quality(attrs)
	local sum, n = 0, 0
	for _, v in pairs(attrs or {}) do sum = sum + v; n = n + 1 end
	return n > 0 and math.floor(sum / n) or 0
end

-- catalogue() -> { { name = family, items = { { type, class, family, classes, best = spawnName|nil, quality, inShift }, … } }, … }
function FbResourceDealer:catalogue()
	local now = os.time()
	if self._cat ~= nil and now - (self._catAt or 0) < self.cacheSeconds then return self._cat end
	local bestOf = {}
	for _, s in ipairs(getResourceSpawnsAll() or {}) do
		local q = quality(s.attributes)
		local b = bestOf[s.type]
		if b == nil or q > b.quality or (q == b.quality and s.inShift and not b.inShift) then
			bestOf[s.type] = { name = s.name, quality = q, inShift = s.inShift }
		end
	end
	local families, index = {}, {}
	for _, t in ipairs(getResourceTypes() or {}) do
		local b = bestOf[t.type]
		local e = { type = t.type, class = t.finalClass, family = t.family, classes = t.classes, zone = t.zone,
			best = b and b.name or nil, quality = b and b.quality or 0, inShift = b and b.inShift or false }
		local f = index[e.family]
		if f == nil then f = { name = e.family, items = {} }; index[e.family] = f; table.insert(families, f) end
		table.insert(f.items, e)
	end
	table.sort(families, function(a, b) return a.name < b.name end)
	for _, f in ipairs(families) do table.sort(f.items, function(a, b) return a.class < b.class end) end
	self._cat, self._catAt = families, now
	return families
end

function FbResourceDealer:family(name)
	for _, f in ipairs(self:catalogue()) do if f.name == name then return f end end
	return nil
end

-- entry(key) -> the catalogue row for a type name, a class name or a known spawn name
function FbResourceDealer:entry(key)
	for _, f in ipairs(self:catalogue()) do
		for _, e in ipairs(f.items) do
			if e.type == key or e.class == key or e.best == key then return e end
		end
	end
	return nil
end

-- purchase(pPlayer, key, units) -> "ok" | "no_credits" | "inventory_full" | "bad_item" | "failed"; key = type, class or spawn
function FbResourceDealer:purchase(pPlayer, key, units)
	if pPlayer == nil then return "failed" end
	units = tonumber(units) or 0
	local e = self:entry(key)
	if e == nil or units <= 0 then return "bad_item" end
	local price = math.ceil(units * self.pricePerUnit)
	local creature = CreatureObject(pPlayer)
	if creature:getCashCredits() < price then
		creature:sendSystemMessage("Not enough cash for " .. units .. " units of " .. e.class .. ". Need " .. price .. " cr.")
		return "no_credits"
	end
	local pInventory = creature:getSlottedObject("inventory")
	if pInventory == nil or SceneObject(pInventory):isContainerFullRecursive() then
		creature:sendSystemMessage("Your inventory is full.")
		return "inventory_full"
	end
	local name = e.best
	if name == nil then
		name = spawnResourceOfType(e.type)   -- nobody has seen this one: a vein is found for it
		if name == nil then
			creature:sendSystemMessage("Mehra shakes her head: no " .. e.class .. " to be found anywhere this week.")
			return "failed"
		end
		self._cat = nil   -- the new spawn joins the catalogue
		creature:sendSystemMessage("Mehra puts the word out, and a vein of " .. e.class .. " is found: " .. name .. ".")
	end
	if not givePlayerResourceNamed(pPlayer, name, units) then
		creature:sendSystemMessage("Mehra checks her ledger: " .. name .. " is gone for good. Ask again and a new one is found.")
		self._cat = nil
		return "failed"
	end
	creature:subtractCashCredits(price)
	creature:sendSystemMessage("Purchased " .. units .. " units of " .. name .. " (" .. e.class .. ") for " .. price .. " credits.")
	self._lastName = name
	return "ok"
end

-- ---- windows: family -> type -> amount; the choices ride in quest status keyed by the player oid --------------
local function key(pPlayer, what) return "FbResourceDealer." .. SceneObject(pPlayer):getObjectID() .. "." .. what end

local function rowText(e)
	if e.best == nil then return e.class .. " — none found yet (ask and a vein is found)" end
	return e.class .. " — " .. e.best .. ", q" .. e.quality .. (e.inShift and " (in shift)" or " (last known)")
end

function FbResourceDealer:showList(pPlayer, pNpc)
	if pPlayer == nil then return end
	local families = self:catalogue()
	local pSui = SuiListBox.new("FbResourceDealer", "onFamilyPicked")
	pSui.setTitle("Resource Dealer")
	pSui.setPrompt("Every resource there is, by family. The best spawn ever seen of each kind, or a fresh one found for you. " .. self.pricePerUnit .. " cr a unit, cash only.")
	for _, f in ipairs(families) do
		pSui.add(f.name .. "  (" .. #f.items .. " kinds)", "")
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
	local pInner = SuiListBox.new("FbResourceDealer", "onTypePicked")
	pInner.setTitle(f.name)
	pInner.setPrompt("Quality is the mean of the spawn's stats (0-1000). A kind nobody has seen yet is found when you buy it.")
	for _, e in ipairs(f.items) do
		pInner.add(rowText(e), "")
	end
	pInner.sendTo(pPlayer)
end

function FbResourceDealer:onTypePicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local idx = tonumber(args)
	if idx == nil then return end
	local f = self:family(getQuestStatus(key(pPlayer, "family")) or "")
	local e = f and f.items[idx + 1]
	if e == nil then return end
	setQuestStatus(key(pPlayer, "type"), e.type)
	local pAmt = SuiListBox.new("FbResourceDealer", "onAmountPicked")
	pAmt.setTitle(e.class)
	pAmt.setPrompt(rowText(e) .. ". How many units?")
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
	self:purchase(pPlayer, getQuestStatus(key(pPlayer, "type")) or "", n)
end
