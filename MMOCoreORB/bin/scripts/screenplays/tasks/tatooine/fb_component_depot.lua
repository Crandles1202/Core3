-- fb_component_depot.lua — Final Boss 2.15: the component depot (BX-4, Mos Eisley Trade Hall, foyer).
--
-- Sells every crafting component the game has. The catalogue is generated (tools/components_gen.py →
-- fb_component_depot_catalogue.lua): a row with `loot` is made through createLoot at its level, so the part carries
-- real rolled stats (weapon, armor, chemistry, clothing, lightsaber crystals and pearls); a row without is the bare
-- template (droid, structure, vehicle, food, munitions …), which every schematic accepts but which brings no values.
-- The NPC is a tenant of the Trade Hall site; purchase(pPlayer, cat, idx | name) is public for the lab.
FbComponentDepot = ScreenPlay:new {
	screenplayName = "FbComponentDepot",
}

function FbComponentDepot:start() end

function FbComponentDepot:categories() return FbComponentDepotCatalogue or {} end

-- find(key) -> item, catIdx, itemIdx; key = an exact name, a lower-case fragment, or "cat:idx"
function FbComponentDepot:find(key)
	key = tostring(key or "")
	local c, i = key:match("^(%d+):(%d+)$")
	if c ~= nil then
		local cat = self:categories()[tonumber(c)]
		return cat and cat.items[tonumber(i)], tonumber(c), tonumber(i)
	end
	for ci, cat in ipairs(self:categories()) do
		for ii, it in ipairs(cat.items) do if it.name == key then return it, ci, ii end end
	end
	for ci, cat in ipairs(self:categories()) do
		for ii, it in ipairs(cat.items) do
			if string.find(string.lower(it.name), string.lower(key), 1, true) then return it, ci, ii end
		end
	end
	return nil
end

-- purchase(pPlayer, key) -> "ok" | "no_credits" | "inventory_full" | "bad_item" | "failed"
function FbComponentDepot:purchase(pPlayer, key)
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
	local made
	if item.loot ~= nil then
		local oid = createLoot(pInventory, item.loot, item.level, false)
		made = oid ~= nil and oid ~= 0
	else
		made = giveItem(pInventory, item.template, -1) ~= nil
	end
	if not made then
		creature:sendSystemMessage("BX-4 checks the shelf twice: no " .. item.name .. " came out of it.")
		return "failed"
	end
	creature:subtractCashCredits(item.price)
	creature:sendSystemMessage("Purchased " .. item.name .. (item.loot and " (rolled)" or " (raw)") .. " for " .. item.price .. " credits.")
	return "ok"
end

-- ---- windows: category -> item (the parts dealer pattern; one handler per category) ---------------------------
function FbComponentDepot:showList(pPlayer, pNpc)
	if pPlayer == nil then return end
	local pSui = SuiListBox.new("FbComponentDepot", "onCategoryPicked")
	pSui.setTitle("Component Depot")
	pSui.setPrompt("Every crafting component. Rolled parts carry real stats; (raw) shelves hold bare components with none. Cash only.")
	for _, cat in ipairs(self:categories()) do
		pSui.add(cat.name .. "  (" .. #cat.items .. ")", "")
	end
	pSui.sendTo(pPlayer)
end

function FbComponentDepot:onCategoryPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local catIdx = tonumber(args)
	if catIdx == nil then return end
	catIdx = catIdx + 1
	local cat = self:categories()[catIdx]
	if cat == nil then return end
	local pInner = SuiListBox.new("FbComponentDepot", "onItemPickedCat" .. catIdx)
	pInner.setTitle(cat.name)
	pInner.setPrompt(cat.items[1] and cat.items[1].loot and "Rolled fresh at purchase." or "Bare components: no stats of their own.")
	for _, it in ipairs(cat.items) do
		pInner.add("[" .. it.price .. " cr] " .. it.name, "")
	end
	pInner.sendTo(pPlayer)
end

for i = 1, 40 do   -- one callback per category slot (the catalogue has 25; room to grow)
	local catIdx = i
	FbComponentDepot["onItemPickedCat" .. catIdx] = function(self, pPlayer, pSui, eventIndex, args)
		if pPlayer == nil or eventIndex == 1 then return end
		local idx = tonumber(args)
		if idx == nil then return end
		self:purchase(pPlayer, catIdx .. ":" .. (idx + 1))
	end
end
