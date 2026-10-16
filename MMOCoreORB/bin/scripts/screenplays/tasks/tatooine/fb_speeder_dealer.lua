-- fb_speeder_dealer.screenplay.lua — Drosa Vex vehicle deed vendor.

FbSpeederDealer = ScreenPlay:new {
	screenplayName = "FbSpeederDealer",
	spawns = {
		{ planet = "tatooine", label = "Mos Eisley Vehicle Shop", x = 3.26, z = 1.13, y = -9.43, dir = 1, cellID = 1279964 },
	},
}

FbSpeederDealer.vehicleCategories = {
	{ name = "Vehicle Deeds", items = {
		{ name="Jetpack",                template="object/tangible/deed/vehicle_deed/jetpack_deed.iff",                price=15000 },
		{ name="Speederbike",            template="object/tangible/deed/vehicle_deed/speederbike_deed.iff",            price=8000  },
		{ name="Flash Speederbike",      template="object/tangible/deed/vehicle_deed/speederbike_flash_deed.iff",      price=12000 },
		{ name="Swoop",                  template="object/tangible/deed/vehicle_deed/speederbike_swoop_deed.iff",      price=25000 },
		{ name="Landspeeder X-31",       template="object/tangible/deed/vehicle_deed/landspeeder_x31_deed.iff",        price=18000 },
		{ name="Landspeeder X-34 (Luke)", template="object/tangible/deed/vehicle_deed/landspeeder_x34_deed.iff",        price=22000 },
		{ name="Landspeeder AV-21",      template="object/tangible/deed/vehicle_deed/landspeeder_av21_deed.iff",       price=20000 },
		{ name="Prototype Speederbike",  template="object/tangible/deed/vehicle_deed/vehicular_prototype_bike_deed.iff", price=5000  },
		{ name="Prototype Vehicle",      template="object/tangible/deed/vehicle_deed/vehicular_prototype_deed.iff",     price=5000  },
	}},
}

registerScreenPlay("FbSpeederDealer", true)

function FbSpeederDealer:start()
	for _, spawn in ipairs(self.spawns) do
		if isZoneEnabled(spawn.planet) then
			spawnMobile(spawn.planet, "fb_speeder_dealer", 0, spawn.x, spawn.z, spawn.y, spawn.dir, spawn.cellID or 0)
		end
	end
	printf("FbSpeederDealer: spawned\n")
end

function FbSpeederDealer:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local creature = CreatureObject(pPlayer)
	if catIdx < 1 or catIdx > #FbSpeederDealer.vehicleCategories then return end
	local idx = tonumber(args); if idx == nil then return end
	if idx == 0 then FbSpeederDealer:_purchaseOneOfEach(pPlayer, catIdx); return end
	local cat = FbSpeederDealer.vehicleCategories[catIdx]
	if idx < 1 or idx > #cat.items then return end
	local item = cat.items[idx]
	if creature:getCashCredits() < item.price then
		creature:sendSystemMessage("Not enough credits for " .. item.name .. ". Need " .. item.price .. " cr.")
		return
	end
	local pInventory = creature:getSlottedObject("inventory")
	if pInventory == nil then return end
	if SceneObject(pInventory):isContainerFullRecursive() then
		creature:sendSystemMessage("Inventory full.")
		return
	end
	local pItem = giveItem(pInventory, item.template, -1)
	if pItem == nil then
		creature:sendSystemMessage("Transaction failed: " .. item.template)
		return
	end
	creature:subtractCashCredits(item.price)
	creature:sendSystemMessage("Purchased " .. item.name .. " for " .. item.price .. " credits.")
end

function FbSpeederDealer:_purchaseOneOfEach(pPlayer, catIdx)
	local creature = CreatureObject(pPlayer)
	local cat = FbSpeederDealer.vehicleCategories[catIdx]
	local total = 0
	for i = 1, #cat.items do total = total + cat.items[i].price end
	if creature:getCashCredits() < total then
		creature:sendSystemMessage("Not enough credits. Need " .. total .. " cr.")
		return
	end
	local pInventory = creature:getSlottedObject("inventory")
	if pInventory == nil then return end
	if SceneObject(pInventory):isContainerFullRecursive() then
		creature:sendSystemMessage("Inventory full.")
		return
	end
	local givenCount, totalSpent = 0, 0
	local failed = {}
	for i = 1, #cat.items do
		local item = cat.items[i]
		if SceneObject(pInventory):isContainerFullRecursive() then
			table.insert(failed, item.name .. " (full)")
		else
			local pItem = giveItem(pInventory, item.template, -1)
			if pItem ~= nil then
				givenCount = givenCount + 1; totalSpent = totalSpent + item.price
			else
				table.insert(failed, item.name)
			end
		end
	end
	if totalSpent > 0 then creature:subtractCashCredits(totalSpent) end
	if givenCount == #cat.items then
		creature:sendSystemMessage("Got one of each: " .. givenCount .. " deeds for " .. totalSpent .. " credits.")
	elseif givenCount > 0 then
		creature:sendSystemMessage("Partial: " .. givenCount .. " of " .. #cat.items .. " for " .. totalSpent .. " cr. Failed: " .. table.concat(failed, ", "))
	else
		creature:sendSystemMessage("No deeds delivered.")
	end
end

for i = 1, #FbSpeederDealer.vehicleCategories do
	local catIdx = i
	FbSpeederDealer["onVehiclePickedCat" .. catIdx] = function(self, pPlayer, pSui, eventIndex, args)
		FbSpeederDealer:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	end
end

function FbSpeederDealer:showCategoryList(pPlayer, pNpc)
	if pPlayer == nil then return end
	local pSui = SuiListBox.new("FbSpeederDealer", "onCategoryPicked")
	pSui.setTitle("Drosa Vex's Speeders")
	pSui.setPrompt("Select a category:")
	for i = 1, #FbSpeederDealer.vehicleCategories do
		local cat = FbSpeederDealer.vehicleCategories[i]
		pSui.add(cat.name .. "  (" .. #cat.items .. " items)", "")
	end
	pSui.sendTo(pPlayer)
end

function FbSpeederDealer:onCategoryPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local catIdx = tonumber(args); if catIdx == nil then return end
	catIdx = catIdx + 1
	if catIdx < 1 or catIdx > #FbSpeederDealer.vehicleCategories then return end
	local cat = FbSpeederDealer.vehicleCategories[catIdx]
	local pInner = SuiListBox.new("FbSpeederDealer", "onVehiclePickedCat" .. catIdx)
	pInner.setTitle(cat.name)
	pInner.setPrompt("Pick a deed, or buy one of each:")
	local total = 0
	for i = 1, #cat.items do total = total + cat.items[i].price end
	pInner.add("[" .. total .. " cr]  *** Buy one of each (" .. #cat.items .. ", testing) ***", "")
	for i = 1, #cat.items do
		local it = cat.items[i]
		pInner.add("[" .. it.price .. " cr] " .. it.name, "")
	end
	pInner.sendTo(pPlayer)
end
