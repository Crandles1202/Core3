-- fb_crystal_node.lua — a crystal formation in a cave (Phase 4a.0). A server template with the stock force crystal's
-- look (the client renders clientTemplateFileName) and our radial: FbCrystalNodeMenuComponent in fb_crystals.lua.
-- Same pattern as the Lab Remote.

object_tangible_fb_crystal_node_fb_crystal_node = SharedTangibleObjectTemplate:new {
	clientTemplateFileName = "object/tangible/loot/misc/shared_force_crystal.iff",
	objectMenuComponent = "FbCrystalNodeMenuComponent",
	gameObjectType = 8249,
}
ObjectTemplates:addTemplate(object_tangible_fb_crystal_node_fb_crystal_node, "object/tangible/fb_crystal_node/fb_crystal_node.iff")
