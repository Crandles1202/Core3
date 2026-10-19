-- fb_droid_dispenser.screenplay.lua — FB-3D droid vendor screenplay.

FbDroidDispenser = ScreenPlay:new {
	screenplayName = "FbDroidDispenser",
	spawns = {
		-- moved into the Mos Eisley Trade Hall (fb_trade_hall.lua), Phase 2.11: { planet = "tatooine", label = "Mos Eisley Starport",       x = 3513,   z = 5,    y = -4813, dir = 1 },
		-- Themed indoor spawn inside the Mos Eisley Droid Engineer Shop.
		{ planet = "tatooine", label = "Mos Eisley Droid Shop",     x = -13.96, z = 1.13, y = -9.02, dir = 1, cellID = 1189580 },
	},
}

FbDroidDispenser.droidCategories = {
	{ name = "Protocol Droids", items = {
		{ name="3PO (basic)",          template="object/tangible/deed/pet_deed/deed_3p0_basic.iff",           price=3000 },
		{ name="3PO (advanced)",       template="object/tangible/deed/pet_deed/deed_3p0_advanced_basic.iff",  price=8000 },
	}},
	{ name = "Astromech Droids", items = {
		{ name="R2 unit (basic)",      template="object/tangible/deed/pet_deed/deed_r2_basic.iff",            price=4000 },
		{ name="R2 unit (advanced)",   template="object/tangible/deed/pet_deed/deed_r2_advanced_basic.iff",   price=10000 },
		{ name="R3 unit (basic)",      template="object/tangible/deed/pet_deed/deed_r3_basic.iff",            price=4000 },
		{ name="R3 unit (advanced)",   template="object/tangible/deed/pet_deed/deed_r3_advanced_basic.iff",   price=10000 },
		{ name="R4 unit (basic)",      template="object/tangible/deed/pet_deed/deed_r4_basic.iff",            price=4000 },
		{ name="R4 unit (advanced)",   template="object/tangible/deed/pet_deed/deed_r4_advanced_basic.iff",   price=10000 },
		{ name="R5 unit (basic)",      template="object/tangible/deed/pet_deed/deed_r5_basic.iff",            price=4000 },
		{ name="R5 unit (advanced)",   template="object/tangible/deed/pet_deed/deed_r5_advanced_basic.iff",   price=10000 },
	}},
	{ name = "Utility Droids", items = {
		{ name="MSE-6 (basic)",          template="object/tangible/deed/pet_deed/deed_mse_basic.iff",                 price=1500 },
		{ name="MSE-6 (advanced)",       template="object/tangible/deed/pet_deed/deed_mse_advanced_basic.iff",        price=4000 },
		{ name="LE-Repair (basic)",      template="object/tangible/deed/pet_deed/deed_le_repair_basic.iff",           price=2500 },
		{ name="LE-Repair (advanced)",   template="object/tangible/deed/pet_deed/deed_le_repair_advanced_basic.iff",  price=6000 },
		{ name="Binary Load Lifter (basic)",    template="object/tangible/deed/pet_deed/deed_binary_load_lifter_basic.iff",         price=2500 },
		{ name="Binary Load Lifter (advanced)", template="object/tangible/deed/pet_deed/deed_binary_load_lifter_advanced_basic.iff", price=6000 },
	}},
	{ name = "Power Droids", items = {
		{ name="Power Droid (basic)",    template="object/tangible/deed/pet_deed/deed_power_basic.iff",          price=2500 },
		{ name="Power Droid (advanced)", template="object/tangible/deed/pet_deed/deed_power_advanced_basic.iff", price=6000 },
	}},
	{ name = "Surveillance Droids", items = {
		{ name="DZ-70 Probe (basic)",     template="object/tangible/deed/pet_deed/deed_dz70_basic.iff",            price=5000 },
		{ name="DZ-70 Probe (advanced)",  template="object/tangible/deed/pet_deed/deed_dz70_advanced_basic.iff",   price=15000 },
		{ name="Probot (basic)",          template="object/tangible/deed/pet_deed/deed_probot_basic.iff",          price=5000 },
		{ name="Probot (advanced)",       template="object/tangible/deed/pet_deed/deed_probot_advanced_basic.iff", price=15000 },
	}},
}

registerScreenPlay("FbDroidDispenser", true)

function FbDroidDispenser:start()
	for _, spawn in ipairs(self.spawns) do
		if isZoneEnabled(spawn.planet) then
			spawnMobile(spawn.planet, "fb_droid_dispenser", 0, spawn.x, spawn.z, spawn.y, spawn.dir, spawn.cellID or 0)
		end
	end
	printf("FbDroidDispenser: spawned\n")
end

function FbDroidDispenser:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local creature = CreatureObject(pPlayer)
	if catIdx < 1 or catIdx > #FbDroidDispenser.droidCategories then return end
	local idx = tonumber(args); if idx == nil then return end
	if idx == 0 then FbDroidDispenser:_purchaseOneOfEach(pPlayer, catIdx); return end
	local cat = FbDroidDispenser.droidCategories[catIdx]
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

function FbDroidDispenser:_purchaseOneOfEach(pPlayer, catIdx)
	local creature = CreatureObject(pPlayer)
	local cat = FbDroidDispenser.droidCategories[catIdx]
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
		creature:sendSystemMessage("Got one of each: " .. givenCount .. " items for " .. totalSpent .. " credits.")
	elseif givenCount > 0 then
		creature:sendSystemMessage("Partial: " .. givenCount .. " of " .. #cat.items .. " for " .. totalSpent .. " cr. Failed: " .. table.concat(failed, ", "))
	else
		creature:sendSystemMessage("No items delivered.")
	end
end

for i = 1, #FbDroidDispenser.droidCategories do
	local catIdx = i
	FbDroidDispenser["onDroidPickedCat" .. catIdx] = function(self, pPlayer, pSui, eventIndex, args)
		FbDroidDispenser:_purchaseFromCategory(pPlayer, eventIndex, args, catIdx)
	end
end

function FbDroidDispenser:showCategoryList(pPlayer, pNpc)
	if pPlayer == nil then return end
	local pSui = SuiListBox.new("FbDroidDispenser", "onCategoryPicked")
	pSui.setTitle("FB-3D — Droid Catalogue")
	pSui.setPrompt("Select a droid line:")
	for i = 1, #FbDroidDispenser.droidCategories do
		local cat = FbDroidDispenser.droidCategories[i]
		pSui.add(cat.name .. "  (" .. #cat.items .. " items)", "")
	end
	pSui.sendTo(pPlayer)
end

function FbDroidDispenser:onCategoryPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil then return end
	if eventIndex == 1 then return end
	local catIdx = tonumber(args); if catIdx == nil then return end
	catIdx = catIdx + 1
	if catIdx < 1 or catIdx > #FbDroidDispenser.droidCategories then return end
	local cat = FbDroidDispenser.droidCategories[catIdx]
	local pInner = SuiListBox.new("FbDroidDispenser", "onDroidPickedCat" .. catIdx)
	pInner.setTitle(cat.name)
	pInner.setPrompt("Pick a droid, or buy one of each:")
	local total = 0
	for i = 1, #cat.items do total = total + cat.items[i].price end
	pInner.add("[" .. total .. " cr]  *** Buy one of each (" .. #cat.items .. ", testing) ***", "")
	for i = 1, #cat.items do
		local it = cat.items[i]
		pInner.add("[" .. it.price .. " cr] " .. it.name, "")
	end
	pInner.sendTo(pPlayer)
end
