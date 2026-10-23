# Board — who is doing what (read this before you start, update it when you start and when you finish)

The repo is shared by several agents and by Chuck. One game server exists: **the bench**, the main checkout at
`~/workspace/Core3`, running from its `MMOCoreORB/bin/`. Everyone else works in a **worktree** of their own
(`~/workspace/Core3-<name>`, branch `feature/<name>`) and borrows the bench to test. `tools/swg` enforces the
borrowing with a lock; this file carries the intent.

## Lanes

| Agent | Branch | Task (roadmap item) | Status | Bench | Updated |
|---|---|---|---|---|---|
| chuck | — | play-testing, design calls, merges by request | ongoing | as needed | 2026-10-20 |
| alice | `feature/alice` | Phase 7 Citizens: batches merged 2026-10-21 (421d50e15d) and 2026-10-22 (f1c39d871f); third batch 2026-10-23 (the citizens' first day read back: condition/clone, server-named creatures, land-only and buildable resource spots, shuttle routing, the hunt and harvester loops verified live — Teyla kills worrts, Wex runs an ore harvester near Kor Vella) gating, then Chuck's `bench merge feature/alice`; next: the live-world server (Chuck's call), grouping/follow | gate | yes | 2026-10-23 + the threat scan (lab `threats`, hunt guards, escape walk; Teyla's ground moved south after the story camp killed her twice), merged 2026-10-23; 7.5 training (lab `trainable`/`trainers`, pilot `train` through the stock trainer conversation, indoor paths on the floor, the snapshot-NPC crash in `getCreatureTemplateName`) gating 2026-10-23 |
| _(add a row with `swg agent new <name>`)_ | | | | | |

Status words: `planning`, `coding`, `testing` (holds the bench), `gate` (running `swg test all`), `ready to merge`,
`merged`, `blocked: <why>`. Keep one row per agent; retire the row with the agent.

## Rules

1. **Never edit files in the bench checkout.** It is the deployment target, not a workspace; `swg bench use` moves
   its checkout around and will refuse a dirty tree. Work in your worktree; commit there.
2. **One branch per agent, one roadmap item per branch.** Branch from `unstable`, name it `feature/<agent>` or
   `feature/<agent>-<item>`. Commit messages `Phase X.Y: <what>`.
3. **Testing means the bench, and the bench is locked.** `swg bench use <your-branch>` takes the lock for you
   (90 min, renew with `swg lock`), deploys your commit (build / restart / reload as needed), then `swg test …`.
   Every `swg` command that touches the server refuses to run while another agent holds the lock; `SWG_WAIT=1`
   queues you. Read-only looks (`swg status`, `swg logs`, `swg cmd --shared …`) never need it.
4. **Release the bench when you stop testing** (`swg bench release`): it goes back to `unstable` and the lock
   opens. A hold expires on its own; an abandoned lock may be broken with `swg unlock --force` after checking the
   board.
5. **Merge only through the gate.** `swg test all` on the bench with your commit deployed records a pass for that
   commit; `swg bench merge <branch>` refuses without it, then merges `--no-ff` into `unstable` and pushes.
   After that, `git -C <your worktree> rebase unstable` or retire the worktree (`swg agent done <name>`).
6. **Shared state that is not code:** the test accounts (`claude-admin`, `claude-player`, ten-character cap),
   quest-status registries, world edits in `tre-src/world/`, sites in `tasks/sites/`, the ODB. Scenarios may
   use the lab accounts freely *while holding the lock*. Do not load snapshots or write to other accounts
   without Chuck.
7. **Write it down the same session:** `docs/dev-notes.md` for what you learned, `CLAUDE.md` for anything the next
   agent needs before touching the code, the roadmap tick when an item ships, this board when your status
   changes. Commit docs with the work they describe.
8. **Ask Chuck** before: pushing anything but `unstable` through the gate, merging into `unstable` by hand,
   loading a snapshot, DB writes outside the lab accounts, changing `.claude/settings.json`.

## How a session goes

```
cd ~/workspace/Core3-<name> && claude          # your worktree; CLAUDE.md and this board load with it
tools/swg whoami                                # "<name>" — the lock will carry this
# … code, commit on feature/<name> …
tools/swg bench use feature/<name>              # lock + deploy (reload for Lua, restart for mobiles, build for C++)
tools/swg test scenario <yours>                 # iterate: edit in the worktree, commit, bench use again
tools/swg test all                              # the gate, ~30 min, records a pass for this commit
tools/swg bench merge feature/<name>            # --no-ff into unstable + push (needs the pass)
tools/swg bench release                         # bench back on unstable, lock open (before agent done)
tools/swg agent done <name>                     # retire the worktree; releases the bench if you still hold it
```
