-- fb_vehicle_dealer.lua — Final Boss 2.13: vehicle dealer (Rook Valdane, Mos Eisley Trade Hall, hall B).
--
-- Sells the stock vehicle deeds for cash. A deed from the template is the same object a crafter's deed is (the
-- vehicle is generated from the deed when it is called), so nothing is lost by buying it. The NPC is a tenant of
-- the Trade Hall site (tasks/sites/mos_eisley_trade_hall.lua); this file holds the catalogue and the window.
-- purchase(pPlayer, idx | name) is public for the lab.
FbVehicleDealer = ScreenPlay:new {
	screenplayName = "FbVehicleDealer",
}

FbVehicleDealer.items = {
	{ name = "Speederbike",                 template = "object/tangible/deed/vehicle_deed/speederbike_deed.iff",       price = 6000 },
	{ name = "Swoop bike",                  template = "object/tangible/deed/vehicle_deed/speederbike_swoop_deed.iff", price = 9000 },
	{ name = "Flash speeder",               template = "object/tangible/deed/vehicle_deed/speederbike_flash_deed.iff", price = 20000 },
	{ name = "X-31 landspeeder",            template = "object/tangible/deed/vehicle_deed/landspeeder_x31_deed.iff",   price = 12000 },
	{ name = "X-34 landspeeder",            template = "object/tangible/deed/vehicle_deed/landspeeder_x34_deed.iff",   price = 15000 },
	{ name = "AV-21 landspeeder",           template = "object/tangible/deed/vehicle_deed/landspeeder_av21_deed.iff",  price = 60000 },
	{ name = "Jetpack",                     template = "object/tangible/deed/vehicle_deed/jetpack_deed.iff",           price = 120000 },
}

function FbVehicleDealer:start() end

function FbVehicleDealer:find(key)
	local idx = tonumber(key)
	if idx ~= nil then return self.items[idx], idx end
	for i, it in ipairs(self.items) do
		if it.name == key or string.find(string.lower(it.name), string.lower(tostring(key)), 1, true) then return it, i end
	end
	return nil
end

-- purchase(pPlayer, idx | name) -> "ok" | "no_credits" | "inventory_full" | "bad_item" | "failed"
function FbVehicleDealer:purchase(pPlayer, key)
	if pPlayer == nil then return "failed" end
	local item = self:find(key)
	if item == nil then return "bad_item" end
	local creature = CreatureObject(pPlayer)
	if creature:getCashCredits() < item.price then
		creature:sendSystemMessage("Not enough cash for a " .. item.name .. ". Need " .. item.price .. " cr.")
		return "no_credits"
	end
	local pInventory = creature:getSlottedObject("inventory")
	if pInventory == nil or SceneObject(pInventory):isContainerFullRecursive() then
		creature:sendSystemMessage("Your inventory is full.")
		return "inventory_full"
	end
	local pDeed = giveItem(pInventory, item.template, -1)
	if pDeed == nil then
		creature:sendSystemMessage("Rook pats the crate and shrugs: no " .. item.name .. " deed came out of it.")
		return "failed"
	end
	creature:subtractCashCredits(item.price)
	creature:sendSystemMessage("Purchased a " .. item.name .. " deed for " .. item.price .. " credits. Call it from your datapad.")
	return "ok"
end

function FbVehicleDealer:showList(pPlayer, pNpc)
	if pPlayer == nil then return end
	local pSui = SuiListBox.new("FbVehicleDealer", "onPicked")
	pSui.setTitle("Vehicle Dealer")
	pSui.setPrompt("New deeds, cash only. The vehicle is generated when you call the deed from your datapad.")
	for _, it in ipairs(self.items) do
		pSui.add("[" .. it.price .. " cr] " .. it.name, "")
	end
	pSui.sendTo(pPlayer)
end

function FbVehicleDealer:onPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local idx = tonumber(args)
	if idx == nil then return end
	self:purchase(pPlayer, idx + 1)
end
