-- fb_inventory_100.lua — Phase 1.5: character inventory holds 100 items instead of 80.
--
-- containerVolumeLimit is read from the template when an inventory is *created*
-- (SceneObjectImplementation::loadTemplateData) and then persisted with the object, so this
-- covers new characters only. Existing characters are raised on login by
-- custom_scripts/screenplays/fb_player_login.lua. Same re-register pattern as fb_stimpack_mind.lua.
--
-- The client is not told the limit (it is not in any baseline packet); the server simply allows
-- 100 items. The inventory window's "/80" counter comes from the client's own TRE and may read
-- e.g. 85/80 — cosmetic.

FB_INVENTORY_VOLUME = 100

local template = _G["object_tangible_inventory_character_inventory"]
if template ~= nil then
	template.containerVolumeLimit = FB_INVENTORY_VOLUME
	ObjectTemplates:addTemplate(template, "object/tangible/inventory/character_inventory.iff")
end
