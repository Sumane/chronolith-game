# Morning Report — 2026-08-29

Overnight autonomous build session (started ~23:00 Aug 28). All work committed to git
(branch `main`, 4 commits). This is the state of the workspace when you read this.

## Done

### 1. The 3D decision is documented (your explicit ask)
- `chronolith-gdd.md` — §1 now says **3D, Godot 4.x** (was "TBD"), a prominent
  decision note at the top, and open-question #1 (perspective/camera) is resolved.
- `chronolith-architecture.md` — header states the current tree is a 2D (Node2D)
  vertical-slice prototype and the architecture survives the 3D conversion.
- `NOTE-3D.md` (repo root) — the plain-English note: the game is 3D in Godot;
  everything visual currently in the repo must be rebuilt; what stays, what goes.
- `docs/3D-CONVERSION.md` — full staged roadmap (7 stages, contracts-unchanged rule,
  `z`-axis migration seam with `CONTRACT_VERSION` 1→2 exactly once, camera/renderer
  choices, risk table, definition of done). **Stage 0 is a 1–2 day proof-of-concept
  scene** — that's the natural first task after tonight.

### 2. Six core-loop bugs fixed (the slice was unplayable as found)
| Bug | Fix |
|---|---|
| **U (rover upgrade) did nothing** — signal emitted, never connected | `rover_controller` connects `player_requested_upgrade` → `request_upgrade()` |
| **Hub unlocks never registered** — `unlock_id` wasn't echoed back by economy, so meta read `""` forever | req_id→unlock_id map in `meta_controller` (contract unchanged) |
| **Building repair was dead** — result handler read a `building_id` key economy never sends | req_id→building_id map in `build_controller` |
| **Banked SHARDS wiped every run** — economy zeroed *all* resources on run start, then re-applied starting resources that skip SHARDS | SHARDS/DNA excluded from the zeroing loop; `meta_loaded` now seeds the ledger (the signal existed but had no consumer) |
| **Enemies walked through walls** — controller-level `layout` never injected into Enemy nodes | injected every physics tick in `waves_controller` |
| **Burrowers ignored the map's tunnel holes** — `setup()` ran before `add_child`, so `get_parent()` was null and the hole list was always empty | holes passed as a `setup()` parameter |

### 3. Two perf fixes
- `crystal.gd` loaded its JSON config **every frame** (`_draw`); now once in `_ready`.
- `mars_map.gd` generated the 1920×1280 background per-pixel in GDScript (≈600k
  iterations); now renders at ¼ horizontal resolution and nearest-neighbor upscales
  (4× fewer iterations, visually identical 4-px blocks).
- Repair cost was hardcoded `{"SCRAP": 2}`; now data-driven from
  `modules/economy/data/costs.json` (`repair_tick`), per the architecture's
  "Economy owns costs" boundary.

### 4. Test suite extended (30 → ~45 checks)
`tests/smoke_test.gd` steps 11–17 now cover, end-to-end through the real Bus:
second-run shard persistence + in-run reset, `meta_loaded` ledger seeding, the U
upgrade path, held-E repair (damage → hold → heal), trooper wall-blocking, burrower
tunnel-hole targeting, and corrupt-save quarantine/recovery.

### 5. Balance reviewed — no changes needed
Sol 1 easy (as intended), sol 2 introduces cloak/rover-hunt pressure, sol 3 is a
full gauntlet; hybrid upgrade (RARE 25) is a real mid-run decision; shard economy
pays for plating after ~1–2 wins. Left the data files untouched.

## Blocked / pending at the moment of writing

- **Final green run of the extended suite**: the headless Godot runs keep dying at
  the same test step (see below). Latest status will be appended to this file or in
  the git log.

## The crashes — root cause found and fixed (asked about this morning)

1. **Godot segfault (early, solved)**: the DSH file sandbox blocked Godot's default
   user dir (`~/.local/share/godot`) → null-deref on log-file open → SIGSEGV.
   Workaround: run all headless Godot with
   `XDG_DATA_HOME=/home/marc/AI/Chronolith-Game/.xdg` (inside the workspace).
2. **Recurring OOMs (the "you crashed" loop) — SOLVED, real root cause found.**
   The earlier "Godot is a sacrificial OOM victim" theory was wrong. The smoke-test
   process genuinely ballooned to 20–25 GB, and the OOM kills were correct behavior:
   - **The game itself does not leak.** Idle-game and live-combat RSS probes stayed
     flat at ~118 MB for 75+ s of active play. Your normal sessions were never at risk.
   - **The bug**: `hud.gd` capped the toast stack with
     `while _toasts.get_child_count() > 5: _toasts.get_child(0).queue_free()`.
     `queue_free()` is *deferred* (the child is removed at end of frame), so while the
     loop ran the child count never dropped — with 6 toasts alive at once the loop
     spun forever. That spin (a) stalled the main loop — the "stuck at step 8" freeze,
     physics frames and even `process_always` timers stopped firing — and (b) churning
     small allocations per iteration fragmented the heap, so RSS climbed ~370 MB/s
     until the process died.
   - **The trigger**: 6+ concurrent toasts. The smoke test overlaps intro toasts, the
     CALM/Earth-TX/ASSAULT toasts, kill/rewind toasts (4–6 s lifetimes) and hit the
     6th-toast threshold seconds into the run. It is also reachable in real play
     (storm + wave + rewind + upgrade toasts stacking), which is why the probe without
     heavy toast traffic stayed flat.
   - **The fix** (`modules/ui/internal/hud.gd`): `remove_child()` immediately, then
     `queue_free()`. Verified with a 6-toast arm and a rewind arm that previously
     leaked 12+ GB and froze: both now flat at ~118 MB and exit cleanly.
   - Crash chain for the record: leaking test process → 20+ GB → swap thrash → kernel
     OOM-kills godot (sandbox `oom_score_adj=200`) and page-faults the 11 GB
     llama-server → the agent session's in-flight work dies. The llama server
     (160k context, `--ctx-size 160000`) never died and needs no changes.
3. **Also fixed along the way**: `tests/smoke_test.gd` step 11 used a lambda that
   reassigned a captured local (GDScript capture quirk — the update never landed);
   now a Dictionary holder, like the rest of the suite.
4. **Long-term process (what makes overnight runs safe now)**: the leak is gone, so a
   test run is a flat ~118 MB process for its whole life — duration is no longer a
   memory risk. Standing rules I follow: one Godot process at a time; every run
   detached with logs + per-2s RSS samples written to workspace dotfiles (a mid-run
   death loses nothing); everything committed to git immediately; and the suite is
   re-run after any test-side change. No change to the llama-server/context setup
   needed. Optional cushion if you want one anyway: swap 8→16 GB.

## Run record (appended ~12:05)

```
== CHRONOLITH smoke ==
== 71 checks, 0 failures ==
EXIT: 0        (three consecutive runs, identical result)
RSS: flat ~118 MB for the whole run (previously: 20-25 GB at the same point)
```

Extra bug found and fixed while getting green: `build_controller.gd` read
`b.range` on buildings that only have `range_r` — turrets threw a script error
every frame and never fired. Now `b.range_r`; turrets work.
