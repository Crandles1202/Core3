-- Final Boss overrides for the Force Ranking System manager. Run by FrsManagerImplementation::loadLuaConfig
-- (C++) after the stock scripts/managers/jedi/frs_manager.lua, before its globals are read.
--
-- Phase 4 decision (Chuck, 2026-10-18): FRS voting and enclave politics are off on this solo server. The stock
-- manager, when enabled, also forces every light-council character to Rebel overt and every dark one to
-- Imperial overt at login, deducts rank-maintenance XP, runs votes and petitions. All of that is this flag.
-- The rank skill boxes (force_rank_light_*, force_rank_dark_*) stay: they are the visible Jedi ladder, given by
-- the Masters (FbJediMaster, 4b.1; the Sith Master, 4b.2; the promotions, 4b.3). The enclave doors read the
-- council from the player's FRS data, which the Masters still set.
frsEnabled = 0
