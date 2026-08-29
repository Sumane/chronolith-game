# LEAK HUNT — RESOLVED (2026-08-29 ~12:00)

## Root cause (one bug, two symptoms)
`modules/ui/internal/hud.gd` `add_toast()` capped the toast stack with:

    while _toasts.get_child_count() > 5:
        _toasts.get_child(0).queue_free()

`queue_free()` is DEFERRED (removal happens at end of frame), so while the loop
runs the child count never drops. With 6 toasts alive at once the loop spun
forever:
- **Freeze**: the main loop stalled mid-frame — physics frames, process timers,
  even `process_always` timers stopped. (The "stuck at step 8" symptom.)
- **370 MB/s RSS growth**: the spin churns small per-iteration allocations
  (GDScript + repeated queue_free error path), fragmenting the heap until the
  process hit 20–25 GB. That's what the overnight OOMs were; the game itself
  never leaked (idle and live-combat probes flat at ~118 MB).

Trigger = 6+ concurrent toasts (4–6 s lifetimes overlap in the smoke test:
intro toasts + CALM + Earth-TX + ASSAULT + rewind/kill toasts). Also reachable
in real play (storm + wave + rewind + upgrade toasts).

## Proof chain
1. `tests/mem_probe` (boot + 35s live assault + 45s HUB idle): flat 118 MB → game clean.
2. `tests/leak_matrix` (one mechanic per arm, 40s each): spawnwait/kill/killhub flat
   and exit cleanly; the **rewind arm leaked to 12.8 GB and froze**.
3. Toast count in the rewind arm hits 6 exactly when the leak ramps (t≈3.6 s:
   CALM + Earth-TX + ASSAULT + intro#1 + rewind toast alive while intro#2 is added).
4. Fix = `remove_child()` immediately, then `queue_free()`. Re-ran the toasts arm
   (6 toasts, no rewind) and the rewind arm: both flat ~118 MB, clean exit.

## Related bugs found on the way
- `build_controller.gd:253` — `b.range` on a building that only has `range_r`:
  turrets threw a script error every frame and NEVER FIRED. Fixed.
- `tests/smoke_test.gd` step 9 was non-deterministic: a save persisted by a
  previous run pre-owns `plating1`, and `_on_purchase_result` silently skips
  `unlock_purchased` for already-owned unlocks (it still spends the shards).
  Test now writes a fresh save before booting.
- `tests/smoke_test.gd` step 11 used a lambda that reassigned a captured local
  (GDScript capture quirk — update never landed); now reads the ledger node
  directly / Dictionary-holder pattern.

## Standing process (overnight-safe)
- One godot at a time; every run detached, logs + per-2s RSS to workspace dotfiles;
  commit immediately; XDG_DATA_HOME=$PWD/.xdg is mandatory (sandbox blocks the
  default user dir).
- With the leak fixed a test run is a flat ~118 MB process for its whole life —
  duration is no longer a memory risk. The llama-server (160k ctx) was never the
  problem and is unchanged.
