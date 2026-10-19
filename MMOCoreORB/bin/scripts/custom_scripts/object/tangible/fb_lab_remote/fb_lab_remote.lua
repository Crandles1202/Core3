-- fb_lab_remote.lua — the Final Boss Lab Remote (Phase 2.12): the admin's in-game lab console.
--
-- A tangible that lives in an admin's inventory. Right-click -> "Lab console" opens server UI windows
-- (find / teleport / audit NPCs, lab event triggers, position read-outs, the site builder). Pure Lua:
-- the client renders the stock camp-remote radio (clientTemplateFileName), the server template binds
-- our menu component (fb_lab_remote.lua in custom_scripts/screenplays).
--
-- Every privileged character receives one at login (FBLogin.onLogin); `swg cmd "runLuaFunction
-- FbLabTests:giveRemote:<char>"` hands one out by hand. Non-admins who hold one get a polite refusal.
--
-- The earlier "FB Field Probe" (magic 8-ball that printed your position) is folded into this item;
-- its template path stays registered so probes already in inventories keep working as remotes.

object_tangible_fb_lab_remote_fb_lab_remote = SharedTangibleObjectTemplate:new {
	clientTemplateFileName = "object/tangible/loot/quest/force_sensitive/shared_camp_remote.iff",
	objectMenuComponent = "FbLabRemoteMenuComponent",
	gameObjectType = 8249,
}

ObjectTemplates:addTemplate(object_tangible_fb_lab_remote_fb_lab_remote, "object/tangible/fb_lab_remote/fb_lab_remote.iff")
ObjectTemplates:addTemplate(object_tangible_fb_lab_remote_fb_lab_remote, "object/tangible/fb_field_probe/fb_field_probe.iff")   -- legacy probes
