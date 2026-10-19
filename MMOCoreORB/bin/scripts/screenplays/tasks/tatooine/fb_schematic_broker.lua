-- fb_schematic_broker.lua — Phase 2.2: schematic broker NPC (Mos Eisley starport).
--
-- Sells loot-schematic items (the one-use "You acquire a new crafting schematic!" items) for
-- starter and intermediate crafting: decor, cantina furniture, recyclers, tech props. Only templates
-- that actually name a targetDraftSchematic are listed (38 upstream loot_schematic files are stubs
-- with no draft and no skill: buying one would "learn" nothing).
-- Master-tier loot schematics (Mandalorian / Death Watch, Geonosian, corvette items) are NOT sold —
-- those stay quest rewards and rare drops. Prices sit above what a player crafter would ask so the
-- crafter market keeps its value (roadmap Phase 2 rule).
--
-- Flow (same as FbSmugglerGoods): converse -> "Show me the catalogue" -> SUI category list ->
-- SUI item list -> FbSchematicBroker:purchase(pPlayer, catIdx, itemIdx). The purchase function is
-- public so the lab can call it directly (SUI windows cannot be driven by the bot).

FbSchematicBroker = ScreenPlay:new {
	screenplayName = "FbSchematicBroker",
	spawns = {
		-- moved into the Mos Eisley Trade Hall (fb_trade_hall.lua), Phase 2.11: { planet = "tatooine", label = "Mos Eisley Starport", x = 3535, z = 5, y = -4813, dir = 1 },
	},
}

local LS = "object/tangible/loot/loot_schematic/"

FbSchematicBroker.categories = {
	{ name = "Furniture & Decor", items = {
		{ name = "Cantina Chair",        template = LS .. "cantina_chair_schematic.iff",        price = 600, skill = "crafting_artisan_master" },
		{ name = "Blue Couch",           template = LS .. "couch_blue_schematic.iff",           price = 900, skill = "crafting_architect_production_03" },
		{ name = "Elegant Cabinet",      template = LS .. "elegant_cabinet_schematic.iff",      price = 1200, skill = "crafting_architect_production_04" },
		{ name = "Street Lamp",          template = LS .. "streetlamp_schematic.iff",           price = 700, skill = "crafting_artisan_master" },
		{ name = "Tatooine Tapestry",    template = LS .. "tatooine_tapestry_schematic.iff",    price = 800, skill = "crafting_tailor_field_01" },
		{ name = "Throw Pillow",         template = LS .. "throwpillow_schematic.iff",          price = 400, skill = "crafting_artisan_domestic_01" },
		{ name = "Spear Rack",           template = LS .. "spear_rack_schematic.iff",           price = 700, skill = "crafting_weaponsmith_munitions_04" },
		{ name = "Slave Brazier",        template = LS .. "slave_brazier_schematic.iff",        price = 900, skill = "crafting_architect_production_04" },
	}},
	{ name = "Kitchen & Cantina", items = {
		{ name = "Stove",                template = LS .. "stove_schematic.iff",                price = 900, skill = "crafting_chef_master" },
		{ name = "Tumble Blender",       template = LS .. "tumble_blender_schematic.iff",       price = 700, skill = "crafting_artisan_engineering_01" },
		{ name = "Utensils",             template = LS .. "utensils_schematic.iff",             price = 300, skill = "crafting_chef_novice" },
		{ name = "Carved Bowl",          template = LS .. "bowl_carved_schematic.iff",          price = 300, skill = "crafting_artisan_domestic_02" },
		{ name = "Plain Bowl",           template = LS .. "bowl_plain_schematic.iff",           price = 250, skill = "crafting_artisan_domestic_02" },
		{ name = "Fat Bottle",           template = LS .. "bottle_fat_schematic.iff",           price = 250, skill = "crafting_artisan_domestic_01" },
		{ name = "Pear Bottle",          template = LS .. "bottle_pear_schematic.iff",          price = 250, skill = "crafting_artisan_domestic_02" },
		{ name = "Tall Bottle",          template = LS .. "bottle_tall_schematic.iff",          price = 250, skill = "crafting_artisan_domestic_02" },
		{ name = "Closed Basket",        template = LS .. "basket_closed_schematic.iff",        price = 300, skill = "crafting_architect_novice" },
		{ name = "Gambling Table",       template = LS .. "gambling_table_schematic.iff",       price = 1500, skill = "combat_smuggler_underworld_01" },
	}},
	{ name = "Workshop & Tech", items = {
		{ name = "Chemical Recycler",    template = LS .. "chemical_recycler_schematic.iff",    price = 5000, skill = "crafting_artisan_engineering_01" },
		{ name = "Metal Recycler",       template = LS .. "metal_recycler_schematic.iff",       price = 5000, skill = "crafting_artisan_engineering_01" },
		{ name = "Ore Recycler",         template = LS .. "ore_recycler_schematic.iff",         price = 5000, skill = "crafting_artisan_engineering_01" },
		{ name = "Flora Recycler",       template = LS .. "flora_recycler_schematic.iff",       price = 5000, skill = "crafting_artisan_engineering_01" },
		{ name = "Creature Recycler",    template = LS .. "creature_recycler_schematic.iff",    price = 5000, skill = "crafting_artisan_engineering_01" },
		{ name = "Agitator Motor",       template = LS .. "agitator_motor_schematic.iff",       price = 1500, skill = "crafting_artisan_engineering_01" },
		{ name = "Droid Body",           template = LS .. "droid_body_schematic.iff",           price = 2500, skill = "crafting_droidengineer_techniques_02" },
		{ name = "Bubble Tank",          template = LS .. "bubble_tank_schematic.iff",          price = 1500, skill = "combat_smuggler_spice_02" },
		{ name = "Technical Console I",  template = LS .. "technical_console_s01_schematic.iff", price = 1500, skill = "crafting_architect_production_04" },
		{ name = "Technical Console II", template = LS .. "technical_console_s02_schematic.iff", price = 1500, skill = "crafting_architect_production_04" },
		{ name = "Radar Screen",         template = LS .. "radar_screen_schematic.iff",         price = 1200, skill = "crafting_architect_production_04" },
		{ name = "Radio",                template = LS .. "radio_schematic.iff",                price = 800, skill = "crafting_artisan_master" },
		{ name = "Tanning Hide I",       template = LS .. "tanning_hide_s01_schematic.iff",     price = 600, skill = "crafting_architect_production_04" },
		{ name = "Tanning Hide II",      template = LS .. "tanning_hide_s02_schematic.iff",     price = 600, skill = "crafting_architect_production_04" },
		{ name = "Shisa",                template = LS .. "shisa_schematic.iff",                price = 700, skill = "combat_smuggler_spice_04" },
	}},
}

registerScreenPlay("FbSchematicBroker", true)

function FbSchematicBroker:start()
	for _, spawn in ipairs(self.spawns) do
		if isZoneEnabled(spawn.planet) then
			spawnMobile(spawn.planet, "fb_schematic_broker", 0,
				spawn.x, spawn.z, spawn.y, spawn.dir, spawn.cellID or 0)
		end
	end
	printf("FbSchematicBroker: spawned\n")
end

-- Human-readable skill box name for labels ("crafting_artisan_domestic_01" -> "Artisan Domestic 1").
function FbSchematicBroker.skillLabel(skill)
	if skill == nil or skill == "" then return "anyone" end
	local s = skill:gsub("^crafting_", ""):gsub("^combat_", ""):gsub("^social_", ""):gsub("_0", " ")
	s = s:gsub("_", " "):gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end)
	return s
end

-- purchase(pPlayer, catIdx, itemIdx) -> "ok" | "no_skill" | "no_credits" | "inventory_full" | "bad_item" | "failed"
-- Cash only. Each loot schematic template carries a requiredSkill that LootSchematicMenuComponent
-- enforces when the datapad is used, so refuse the sale up front rather than take credits for a
-- datapad the player cannot read. Public so the lab oracle can exercise it without a SUI window.
function FbSchematicBroker:purchase(pPlayer, catIdx, itemIdx)
	if pPlayer == nil then return "failed" end
	local cat = self.categories[catIdx]
	if cat == nil then return "bad_item" end
	local item = cat.items[itemIdx]
	if item == nil then return "bad_item" end

	local creature = CreatureObject(pPlayer)
	if item.skill ~= nil and item.skill ~= "" and not creature:hasSkill(item.skill) then
		creature:sendSystemMessage("The " .. item.name .. " schematic needs " .. self.skillLabel(item.skill) .. " to read. No sale.")
		return "no_skill"
	end
	if creature:getCashCredits() < item.price then
		creature:sendSystemMessage("Not enough cash for the " .. item.name .. " schematic. Need " .. item.price .. " cr.")
		return "no_credits"
	end

	local pInventory = creature:getSlottedObject("inventory")
	if pInventory == nil or SceneObject(pInventory):isContainerFullRecursive() then
		creature:sendSystemMessage("Your inventory is full.")
		return "inventory_full"
	end

	local pItem = giveItem(pInventory, item.template, -1)
	if pItem == nil then
		creature:sendSystemMessage("The broker fumbles the datapad. (" .. item.template .. " could not be created)")
		return "failed"
	end

	creature:subtractCashCredits(item.price)
	creature:sendSystemMessage("Purchased the " .. item.name .. " schematic for " .. item.price .. " credits. Use it from your inventory to learn it.")
	return "ok"
end

-- ---- SUI plumbing ----------------------------------------------------------------------------

function FbSchematicBroker:showCatalogue(pPlayer, pNpc)
	if pPlayer == nil then return end
	local pSui = SuiListBox.new("FbSchematicBroker", "onCategoryPicked")
	pSui.setTitle("Schematic Broker")
	pSui.setPrompt("Single-use schematics. Each is labelled with the profession box needed to read it. Cash only, no refunds. Pick a catalogue:")
	for i = 1, #self.categories do
		local cat = self.categories[i]
		pSui.add(cat.name .. "  (" .. #cat.items .. " schematics)", "")
	end
	pSui.sendTo(pPlayer)
end

function FbSchematicBroker:onCategoryPicked(pPlayer, pSui, eventIndex, args)
	if pPlayer == nil or eventIndex == 1 then return end
	local catIdx = tonumber(args)
	if catIdx == nil then return end
	catIdx = catIdx + 1
	local cat = self.categories[catIdx]
	if cat == nil then return end

	local pInner = SuiListBox.new("FbSchematicBroker", "onItemPickedCat" .. catIdx)
	pInner.setTitle(cat.name)
	pInner.setPrompt("Pick a schematic:")
	for i = 1, #cat.items do
		local it = cat.items[i]
		pInner.add("[" .. it.price .. " cr] " .. it.name .. "  - " .. self.skillLabel(it.skill), "")
	end
	pInner.sendTo(pPlayer)
end

for i = 1, #FbSchematicBroker.categories do
	local catIdx = i
	FbSchematicBroker["onItemPickedCat" .. catIdx] = function(self, pPlayer, pSui, eventIndex, args)
		if pPlayer == nil or eventIndex == 1 then return end
		local idx = tonumber(args)
		if idx == nil then return end
		FbSchematicBroker:purchase(pPlayer, catIdx, idx + 1)
	end
end
