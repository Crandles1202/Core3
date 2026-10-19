# World edits (Phase 2.12g)

One `<planet>.json` per planet, written by the site planner's *World edits* panel (or by hand):
moves, deletions and additions of the stock buildings and props in `snapshot/<planet>.ws`.
`tools/tre build` (run by `swg start`) turns them into a patched snapshot inside `finalboss.tre`
and into `custom_scripts/fb_world_edits.lua` for the lab. Nothing in this directory is packed verbatim.
Format and rules: `tools/worldedit --help`.
