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

## The crashes — what I found (asked about this morning)

1. **Godot segfault (early, solved)**: the DSH file sandbox blocked Godot's default
   user dir (`~/.local/share/godot`) → null-deref on log-file open → SIGSEGV.
   Workaround: run all headless Godot with
   `XDG_DATA_HOME=/home/marc/AI/Chronolith-Game/.xdg` (inside the workspace).
2. **Recurring OOMs (the "you crashed" loop)**: kernel log shows ~6 OOM-kill events
   overnight, **all victims were `godot`** (my test runs). The sandbox marks spawned
   processes `oom_score_adj=200`, so they die first when memory peaks. The llama.cpp
   server (this agent's model) holds a **fixed ~10 GB KV cache** for the 160k context
   — non-negotiable since the context size can't change — plus Chrome; the machine
   has 30 GB RAM. When those peak together, the kernel OOMs and the session's
   in-flight background work dies with it. The llama server itself never died
   (10+ h uptime).
3. **Mitigations in place**: every step committed to git (a crash loses minutes, not
   work); logs written in the workspace, not /tmp; context kept lean; an on-disk RSS
   probe (`rss_probe.sh` → `.rss-probe`) is sampling Godot's real memory to confirm
   whether Godot itself is ballooning (one OOM reported 17.9 GB RSS, which would be
   a real leak) or just a sacrificial victim.
4. **Suggested long-term levers (your side, none require changing the context
   window)**: grow swap (8→16 GB) as the OOM cushion; keep Chrome light; optionally
   auto-restart the llama server (loop in `run.sh`) so even a server-side blip is a
   2-second dip instead of a session death.

## Suggested next steps (when you're around)

1. Look at `rss_probe.sh`'s output (`.rss-probe`) if a Godot-side memory leak
   confirms — that's the only thing that could be a real game bug.
2. Run the suite once yourself:
   `XDG_DATA_HOME=$PWD/.xdg godot --headless --path . res://tests/smoke_test.tscn`
   (expect ~45 `ok` lines, exit 0).
3. First 3D task per the roadmap: Stage 0 proof-of-concept scene.
