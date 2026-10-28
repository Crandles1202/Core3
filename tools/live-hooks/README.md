# Production deploy hooks

`swg live deploy` runs every executable file in `pre/` (sorted by name) before it stops the production server, and every
file in `post/` after the new build is up. Environment for each hook: `SWG_INSTANCE=live`, `SWG_DEPLOY_TAG` (the stable tag),
`SWG_DEPLOY_REV` (its commit), `SWG_LIVE_ROOT`, `SWG_REPO`. A pre hook that exits non-zero aborts the deploy before anything is
touched; a failing post hook only warns. `swg live deploy --skip-hooks` runs none; `SWG_DEPLOY_GRACE=0` skips the players' grace.

Shipped: `pre/10-warn-players` (console broadcast, then the grace period, default 60 s), `pre/20-citizens-down` (logs the seated
citizens out cleanly and remembers who was up), `post/20-citizens-up` (seats them again). A deploy with `--no-restart` runs no hooks.

The citizens hooks follow the crew tool's rules (alice, 2026-10-27): no `--idle`/`--model` from a hook (a citizen's own settings
survive a deploy), `crew down` strictly before the server stop (a seat cut by the stop leaves an orphaned client that still
reads "seat up"; the post hook downs such orphans first), `crew up` only after READY plus a few seconds, and only for the
citizens the pre hook took down — one that was down before the deploy stays down. When `crew status --up` lands, the hooks
can use it instead of the "seat up (pid N, live)" pattern.
