-- fb_food_vendor.lua — Final Boss 2.16: the chef (Oola Prenn, Mos Eisley Trade Hall, meeting room A).
--
-- Sells every crafted dish, dessert and drink and the cantina's drinks; never spice. A crafted food is given from its
-- template and set to a master chef's numbers (tools/foods_gen.py reads them off the template's experimentation bands;
-- setConsumableValues writes nutrition, duration, uses and filling), so it is as good as the recipe allows.
-- The NPC is a Trade Hall tenant; purchase(pPlayer, name | "shelf:idx") is public for the lab.
FbFoodVendor = ScreenPlay:new {
	screenplayName = "FbFoodVendor",
}

function FbFoodVendor:start() end

function FbFoodVendor:shelves() return FbFoodVendorCatalogue or {} end

function FbFoodVendor:find(key)
	key = tostring(key or "")
	local c, i = key:match("^(%d+)[:/](%d+)$")   -- "shelf:row", or "shelf/row" through the console (it splits on colons)
	if c ~= nil then
		local shelf = self:shelves()[tonumber(c)]
		return shelf and shelf.items[tonumber(i)]
	end
	for _, shelf in ipairs(self:shelves()) do
		for _, it in ipairs(shelf.items) do if it.name == key then return it end end
	end
	for _, shelf in ipairs(self:shelves()) do
		for _, it in ipairs(shelf.items) do
			if string.find(string.lower(it.name), string.lower(key), 1, true) then return it end
		end
	end
	return nil
end

-- purchase(pPlayer, key) -> "ok" | "no_credits" | "inventory_full" | "bad_item" | "failed"
function FbFoodVendor:purchase(pPlayer, key)
	if pPlayer == nil then return "failed" end
	local item = self:find(key)
	if item == nil then return "bad_item" end
	local creature = CreatureObject(pPlayer)
	if creature:getCashCredits() < item.price then
		creature:sendSystemMessage("Not enough cash for " .. item.name .. ". Need " .. item.price .. " cr.")
		return "no_credits"
	end
	local pInventory = creature:getSlottedObject("inventory")
	if pInventory == nil or SceneObject(pInventory):isContainerFullRecursive() then
		creature:sendSystemMessage("Your inventory is full.")
		return "inventory_full"
	end
	local pItem = giveItem(pInventory, item.template, -1)
	if pItem == nil then
		creature:sendSystemMessage("Oola looks in the oven and finds no " .. item.name .. ".")
		return "failed"
	end
	self._lastUses = -1
	if item.nutrition ~= nil then
		self._lastUses = setConsumableValues(pItem, item.nutrition, item.duration, item.quantity, item.filling) or -1
	end
	creature:subtractCashCredits(item.price)
	creature:sendSystemMessage("Purchased " .. item.name .. " for " .. item.price .. " credits.")
	self._last = pItem
	return "ok"
end

function FbFoodVendor:showList(pPlayer, pNpc)
	if pPlayer == nil then return end
	local pSui = SuiListBox.new("FbFoodVendor", "onShelfPicked")
	pSui.setTitle("Oola Prenn, Chef")
	pSui.setPrompt("Every dish, dessert and drink, done as a master does it, and the cantina's drinks. Cash only.")
	for _, shelf in ipairs(self:shelves()) do
		pSui.add(shelf.name .. "  (" .. #shelf.items .. ")", "")
	end
	pSui.sendTo(pPlayer)
end

local function rowText(it)
	if it.nutrition == nil then return "[" .. it.price .. " cr] " .. it.name end
	return string.format("[%d cr] %s — %d uses, %d min", it.price, it.name, it.quantity, math.floor(it.duration / 60 + 0.5))
end

function FbFoodVendor:onShelfPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local idx = tonumber(args)
	if idx == nil then return end
	idx = idx + 1
	local shelf = self:shelves()[idx]
	if shelf == nil then return end
	local pInner = SuiListBox.new("FbFoodVendor", "onItemPickedShelf" .. idx)
	pInner.setTitle(shelf.name)
	pInner.setPrompt(shelf.items[1] and shelf.items[1].nutrition and "The full effect, the longest duration, the most helpings." or "As the bartender pours them.")
	for _, it in ipairs(shelf.items) do
		pInner.add(rowText(it), "")
	end
	pInner.sendTo(pPlayer)
end

for i = 1, 8 do
	local shelfIdx = i
	FbFoodVendor["onItemPickedShelf" .. shelfIdx] = function(self, pPlayer, pSui, eventIndex, args)
		if pPlayer == nil or eventIndex == 1 then return end
		local idx = tonumber(args)
		if idx == nil then return end
		self:purchase(pPlayer, shelfIdx .. ":" .. (idx + 1))
	end
end
