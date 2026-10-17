-- fb_traveling_merchant.lua — Phase 2.9: the traveling merchant.
--
-- One wandering merchant, "Ozlo Vantrek", who shows up in a city for a few hours, sells a small
-- rotating stock of cosmetic and unusual items (paintings, jewellery, hats, goggles), then moves on
-- to another city. The schedule survives restarts: the next move is a persistent server event
-- (createServerEvent) and the current stop / visit number live in the quest-status store.
--
-- Public for the lab: FbTravelingMerchant:move() relocates him now; :stockFor(visit) is the stock
-- function; :purchase(pPlayer, idx) buys; :status() returns a one-line description.

FbTravelingMerchant = ScreenPlay:new {
	screenplayName = "FbTravelingMerchant",
	mobile = "fb_traveling_merchant",
	stayMinutes = 180,           -- how long he stays in one city
	stockSize = 8,               -- items offered per visit
	eventName = "FbMerchantMove",
	stateKey = "FbTravelingMerchant.stop",     -- no ":" in keys: runLuaFunction splits its arguments on ":"
	visitKey = "FbTravelingMerchant.visit",
	oidKey = "FbTravelingMerchant.oid",     -- the live NPC's object id; screenplay tables are per Lua
	                                        -- state, so anything move() needs must live in quest status
}

-- Outdoor stops: city centres from the planet region tables (terrain height looked up at spawn
-- with getTerrainHeightAt, a Final Boss Lua binding).
FbTravelingMerchant.stops = {
	{ planet = "tatooine", label = "Mos Eisley starport", x = 3505,  y = -4806 },
	{ planet = "tatooine", label = "Bestine",             x = -1218, y = -3688 },
	{ planet = "tatooine", label = "Wayfar",              x = -5174, y = -6582 },
	{ planet = "tatooine", label = "Mos Espa",            x = -2940, y = 2190 },
	{ planet = "tatooine", label = "Mos Entha",           x = 1488,  y = 3256 },
	{ planet = "corellia", label = "Coronet",             x = -178,  y = -4504 },
	{ planet = "corellia", label = "Tyrena",              x = -5282, y = -2526 },
	{ planet = "talus",    label = "Dearic",              x = 425,   y = -3000 },
	{ planet = "tatooine", label = "Mos Taike",           x = 3832,  y = 2360 },
}
-- Audit every stop with tools/scenarios/merchant-stops.manual.sh after changing this table.
-- 2026-10-17 audit: all nine conversable; Anchorhead's centre (102, -5360) was not (dropped).

local P = "object/tangible/painting/"
local W = "object/tangible/wearables/"

-- Cosmetic, low-power, a little unusual. Prices well above crafted equivalents on purpose.
FbTravelingMerchant.pool = {
	{ name = "Painting: Krayt Skeleton",      template = P .. "painting_bestine_krayt_skeleton.iff",  price = 2500 },
	{ name = "Painting: Lucky Despot",        template = P .. "painting_bestine_lucky_despot.iff",    price = 2500 },
	{ name = "Painting: Stormtrooper",        template = P .. "painting_bw_stormtrooper.iff",         price = 3000 },
	{ name = "Painting: Dance Party",         template = P .. "painting_dance_party.iff",             price = 2000 },
	{ name = "Painting: Double Helix",        template = P .. "painting_double_helix.iff",            price = 2200 },
	{ name = "Painting: Bright Droid",        template = P .. "painting_droid_bright.iff",            price = 2200 },
	{ name = "Painting: Endor",               template = P .. "painting_endor_style_01.iff",          price = 2400 },
	{ name = "Painting: Fighter Pilot",       template = P .. "painting_fighter_pilot_human_01.iff",  price = 2600 },
	{ name = "Painting: Cargo Port",          template = P .. "painting_cargoport.iff",               price = 2000 },
	{ name = "Painting: Golden Flower",       template = P .. "painting_bestine_golden_flower_01.iff", price = 2300 },
	{ name = "Painting: Moncal Eye",          template = P .. "painting_bestine_moncal_eye_01.iff",   price = 2300 },
	{ name = "Painting: Agrilat",             template = P .. "painting_agrilat_s01.iff",             price = 2100 },
	{ name = "Necklace: Hologram Locket",     template = W .. "necklace/necklace_hologram_locket.iff", price = 3500 },
	{ name = "Necklace: Ice Pendant",         template = W .. "necklace/necklace_ice_pendant.iff",    price = 3200 },
	{ name = "Necklace: Flashy Choker",       template = W .. "necklace/necklace_flashy_choker.iff",  price = 3000 },
	{ name = "Necklace: Brass Charm",         template = W .. "necklace/necklace_brass_charm.iff",    price = 2400 },
	{ name = "Necklace: Adorned Beads",       template = W .. "necklace/necklace_adorned_beads.iff",  price = 2400 },
	{ name = "Necklace: Bright Bauble",       template = W .. "necklace/necklace_bright_bauble.iff",  price = 2600 },
	{ name = "Earrings I",                    template = W .. "earring/earring_s01.iff",              price = 1500 },
	{ name = "Earrings IV",                   template = W .. "earring/earring_s04.iff",              price = 1500 },
	{ name = "Earrings VII",                  template = W .. "earring/earring_s07.iff",              price = 1500 },
	{ name = "Earrings XI",                   template = W .. "earring/earring_s11.iff",              price = 1500 },
	{ name = "Ring I",                        template = W .. "ring/ring_s01.iff",                    price = 1800 },
	{ name = "Ring II",                       template = W .. "ring/ring_s02.iff",                    price = 1800 },
	{ name = "Ring IV",                       template = W .. "ring/ring_s04.iff",                    price = 1800 },
	{ name = "Chef's Hat",                    template = W .. "hat/hat_chef_s01.iff",                 price = 1200 },
	{ name = "Imperial Cap",                  template = W .. "hat/hat_imp_s01.iff",                  price = 2000 },
	{ name = "Hat II",                        template = W .. "hat/hat_s02.iff",                      price = 1400 },
	{ name = "Hat X",                         template = W .. "hat/hat_s10.iff",                      price = 1400 },
	{ name = "Hat XIII",                      template = W .. "hat/hat_s13.iff",                      price = 1400 },
	{ name = "Twi'lek Headwrap",              template = W .. "hat/hat_twilek_s01.iff",               price = 1600 },
	{ name = "Goggles I",                     template = W .. "goggles/goggles_s01.iff",              price = 1700 },
	{ name = "Goggles IV",                    template = W .. "goggles/goggles_s04.iff",              price = 1700 },
	{ name = "Rebreather",                    template = W .. "goggles/rebreather.iff",               price = 2200 },
}

registerScreenPlay("FbTravelingMerchant", true)

-- ---- state ------------------------------------------------------------------------------------

function FbTravelingMerchant:currentStop()
	local idx = tonumber(getQuestStatus(self.stateKey))
	if idx == nil or idx < 1 or idx > #self.stops then
		idx = getRandomNumber(1, #self.stops)
		setQuestStatus(self.stateKey, tostring(idx))
	end
	return idx
end

function FbTravelingMerchant:visit()
	return tonumber(getQuestStatus(self.visitKey)) or 1
end

-- Deterministic rotating stock: visit v offers stockSize consecutive pool entries starting at
-- (v * 5) mod pool size, so consecutive visits overlap little and every item comes around.
function FbTravelingMerchant:stockFor(visit)
	local stock = {}
	local n = #self.pool
	local startIdx = ((visit or 1) * 5) % n
	for i = 0, self.stockSize - 1 do
		stock[#stock + 1] = self.pool[((startIdx + i) % n) + 1]
	end
	return stock
end

function FbTravelingMerchant:status()
	local idx = self:currentStop()
	local stop = self.stops[idx]
	return string.format("stop=%d planet=%s label=%s x=%d y=%d visit=%d oid=%s",
		idx, stop.planet, stop.label, stop.x, stop.y, self:visit(), getQuestStatus(self.oidKey) or "0")
end

-- ---- lifecycle --------------------------------------------------------------------------------

function FbTravelingMerchant:start()
	self:spawnAtCurrentStop()
	if not hasServerEvent(self.eventName) then
		createServerEvent(self.stayMinutes * 60 * 1000, "FbTravelingMerchant", "onMoveEvent", self.eventName)
	end
	printf("FbTravelingMerchant: %s\n", self:status())
end

function FbTravelingMerchant:spawnAtCurrentStop()
	local stop = self.stops[self:currentStop()]
	if not isZoneEnabled(stop.planet) then
		printf("FbTravelingMerchant: zone %s disabled, skipping ahead\n", stop.planet)
		self:advanceStop()
		stop = self.stops[self:currentStop()]
		if not isZoneEnabled(stop.planet) then return end
	end
	local z = getTerrainHeightAt(stop.planet, stop.x, stop.y)   -- getTerrainHeight() needs a creature; this takes a zone name
	local pMobile = spawnMobile(stop.planet, self.mobile, 0, stop.x, z, stop.y, getRandomNumber(0, 6), 0)
	if pMobile ~= nil then
		setQuestStatus(self.oidKey, tostring(SceneObject(pMobile):getObjectID()))
	else
		printf("FbTravelingMerchant: spawn failed at %s\n", stop.label)
	end
end

function FbTravelingMerchant:despawn()
	local oid = tonumber(getQuestStatus(self.oidKey))
	if oid == nil or oid == 0 then return end
	local pMobile = getSceneObject(oid)
	if pMobile ~= nil then
		SceneObject(pMobile):destroyObjectFromWorld(true)
	end
	setQuestStatus(self.oidKey, "0")
end

function FbTravelingMerchant:advanceStop(target)
	local idx = self:currentStop()
	local nextIdx = tonumber(target)
	if nextIdx == nil or nextIdx < 1 or nextIdx > #self.stops then
		nextIdx = idx
		if #self.stops > 1 then
			while nextIdx == idx do nextIdx = getRandomNumber(1, #self.stops) end
		end
	end
	setQuestStatus(self.stateKey, tostring(nextIdx))
	setQuestStatus(self.visitKey, tostring(self:visit() + 1))
	return nextIdx
end

-- move([stopIdx]): leave the current city for another one (random unless given) and reset the
-- stay timer.
function FbTravelingMerchant:move(target)
	self:despawn()
	self:advanceStop(target)
	self:spawnAtCurrentStop()
	if hasServerEvent(self.eventName) then
		rescheduleServerEvent(self.eventName, self.stayMinutes * 60 * 1000)
	else
		createServerEvent(self.stayMinutes * 60 * 1000, "FbTravelingMerchant", "onMoveEvent", self.eventName)
	end
	printf("FbTravelingMerchant: moved, %s\n", self:status())
	return self:status()
end

function FbTravelingMerchant:onMoveEvent()
	self:move()
end

-- ---- selling ----------------------------------------------------------------------------------

-- purchase(pPlayer, idx) -> "ok" | "no_credits" | "inventory_full" | "bad_item" | "failed"
function FbTravelingMerchant:purchase(pPlayer, idx)
	if pPlayer == nil then return "failed" end
	local item = self:stockFor(self:visit())[idx]
	if item == nil then return "bad_item" end

	local creature = CreatureObject(pPlayer)
	if creature:getCashCredits() < item.price then
		creature:sendSystemMessage("Not enough cash for the " .. item.name .. ". Need " .. item.price .. " cr.")
		return "no_credits"
	end
	local pInventory = creature:getSlottedObject("inventory")
	if pInventory == nil or SceneObject(pInventory):isContainerFullRecursive() then
		creature:sendSystemMessage("Your inventory is full.")
		return "inventory_full"
	end
	local pItem = giveItem(pInventory, item.template, -1)
	if pItem == nil then
		creature:sendSystemMessage("Ozlo pats his crates. 'Hm. Seem to have sold the last one.' (" .. item.template .. ")")
		return "failed"
	end
	creature:subtractCashCredits(item.price)
	creature:sendSystemMessage("Purchased " .. item.name .. " for " .. item.price .. " credits. Ozlo moves on in a few hours.")
	return "ok"
end

function FbTravelingMerchant:showStock(pPlayer, pNpc)
	if pPlayer == nil then return end
	local stock = self:stockFor(self:visit())
	local pSui = SuiListBox.new("FbTravelingMerchant", "onItemPicked")
	pSui.setTitle("Ozlo Vantrek - Traveling Goods")
	pSui.setPrompt("This visit's stock. Cash only, no refunds, and I won't be here long.")
	for i = 1, #stock do
		pSui.add("[" .. stock[i].price .. " cr] " .. stock[i].name, "")
	end
	pSui.sendTo(pPlayer)
end

function FbTravelingMerchant:onItemPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local idx = tonumber(args)
	if idx == nil then return end
	self:purchase(pPlayer, idx + 1)
end
