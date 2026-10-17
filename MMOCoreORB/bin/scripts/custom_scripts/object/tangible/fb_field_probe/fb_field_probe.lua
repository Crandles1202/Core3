-- fb_field_probe.lua  — FB Field Diagnostic Probe item template.
--
-- A portable cell-info diagnostic tool. Sits in the player's inventory.
-- Right-click -> "Use" -> prints player's current zone, parentID, and
-- world/cell coordinates as system messages.
--
-- Pure Lua. Inherits appearance from the Magic 8-Ball (no client-side .iff
-- needed) but binds a custom objectMenuComponent that fires our handler.
--
-- Install path: bin/scripts/custom_scripts/object/tangible/fb_field_probe/fb_field_probe.lua
-- Register in:  bin/scripts/custom_scripts/object/serverobjects.lua
-- Companion:    bin/scripts/custom_scripts/screenplays/fb_field_probe_menu_component.lua
--
-- Spawn one in-game with admin /createItem:
--   /createItem object/tangible/fb_field_probe/fb_field_probe.iff

object_tangible_fb_field_probe_fb_field_probe = object_tangible_magic_eight_ball_shared_magic_eight_ball:new {
	objectMenuComponent = "FBFieldProbeMenuComponent",
}

ObjectTemplates:addTemplate(object_tangible_fb_field_probe_fb_field_probe, "object/tangible/fb_field_probe/fb_field_probe.iff")
