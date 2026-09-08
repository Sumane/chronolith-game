# CHRONOLITH v1 — Migration Note (M0)

Date: 2026-09-07 · Branch: `v1` (2D prototype preserved intact on `main`).
Written for design pack v1.0 (`chronolith-v1/`); replaces `docs/3D-CONVERSION.md`,
which is retired planning material for the (now superseded) Stage-0 approach.

## Engine pin (verified locally, not inherited from old docs)

- Binary: `~/.bin/godot` = **4.7.1.stable.official.a13da4feb** (official build,
  no sanitizers). The old docs' "targets 4.7" claim is confirmed by
  `project.godot` features = "4.7". No engine upgrade performed.
- Renderer: `mobile` (desktop), `gl_compatibility` (mobile fallback) — already
  switched for the Stage-0 3D work; the 2D suite passes under it (71/71).

## Launch procedure (exact)

User terminal (game window):

```bash
cd /home/marc/AI/Chronolith-Game
godot --path . res://scenes/poc/poc.tscn        # current 3D entry (Stage-0 tilt)
godot --path .                                   # 2D prototype (main branch scene)
godot --path . -e                                # editor
```

Agent sandbox runs (headless verification; XDG override is mandatory there —
the sandbox blocks the default user dir; the 4.7 build has no `--user-dir`):

```bash
cd /home/marc/AI/Chronolith-Game
env XDG_DATA_HOME=$PWD/.xdg godot --headless --path . res://scenes/poc/poc.tscn
env XDG_DATA_HOME=$PWD/.xdg godot --headless --path . res://tests/smoke_test.tscn
```

Safety rule that survived the overnight leak hunt: one godot at a time;
detach long runs (`setsid nohup ... > log 2>&1 &`); a healthy run is a flat
~118 MB RSS process. `POC_SECONDS=N env var` auto-quits the POC headless.

## Reuse assessment (verified — author familiarity + 71/71 green run on v1 HEAD)

### Keep (data / pure rules / patterns)

| Item | Disposition |
|---|---|
| `core/contracts.gd` | Keep payload conventions + `vec3_of`/`pack_v3` (3D seam: payload `y` = depth, `z` = up, ground 0). v1 architecture prefers typed calls; Contracts stays as the shared reference, not a new mandatory framework. |
| `core/event_bus.gd` | Keep as coarse global notifications only (wave clear, run end, toasts). Not for mouse movement, enemy positions, or per-hit traffic. |
| `data/*.json` | Keep **structure** as initial tuning input (map/nodes, waves, enemy stats, buildings, unlocks, memories). Values are v0 tuning — **not** validated against the v1 economy (engrams, 20 waves, nukes, barriers are absent from these files). v1 numbers come from the progression simulator, per GDD. |
| `modules/economy/economy_controller.gd` | Keep ledger + grant/purchase flow; adapt to **atomic spend/refund with idempotent result keys** (architecture §5). The one-request-per-frame queue pattern is reusable. |
| `modules/waves/waves_controller.gd` | Keep budget/required-threat spawn logic; adapt into WaveDirector (v1: 20 waves, engram gates, capability barriers). |
| `modules/meta/meta_controller.gd` + `save_store.gd` | Keep transactional purchase flow + corrupt-save quarantine; adapt into Research (blueprint graph, eligibility) and ProfileStore (schema version + atomic file replacement + attempt checkpoints). Old save schema is NOT migrated. |
| `modules/chronolith/chronolith_controller.gd` | Keep cooldown/dilation/rewind state machine; adapt to v1 Chronolith owner (integrity, field config, time effects, nuke charges, destruction → defeat). |
| `modules/build/build_controller.gd` | Keep placement validation, footprint/occupancy, repair, power-graph logic; adapt into BuildService with 3D snap + occupied footprints. |
| `modules/rover/rover_controller.gd` (rules only) | Keep harvest/upgrade/stage rules; the 2D movement is replaced by PlayerRig. |
| `core/game_state.gd` (phase flow) | Keep phase skeleton; adapt into GameFlow (attempt lifecycle, engram full-pause mode, nukes, mech phases, terminal precedence). |
| `modules/audio/*` | Keep (2D positional audio; upgrade to 3D positional later). |

### Replace (2D spatial + presentation — discard, rebuild in 3D)

| Item | Replaced by |
|---|---|
| All `modules/*/internal/*.gd` draw-call visuals (mars_map, crystal, rover_body, building, ghost, enemy, hub_screen, hud) | v1 3D presentation with replaceable blockout visuals (architecture asset rule) |
| `modules/environment/environment_controller.gd` (procedural Image) | World owner: heightmap terrain, deposits, spawn points, spatial queries/navigation |
| Rover `CharacterBody2D` + `Camera2D` | PlayerRig: 3D vehicle movement, chase camera (mouse orbit + aim), input contexts |
| `input_forwarder.gd` (mouse → 2D coords) | 3D raycast for placement/aiming; distinct input contexts so menus never fire weapons |
| `tests/smoke_test.gd`, `leak_matrix.gd`, `mem_probe.gd` | Stay on `main` as the 2D regression rig; v1 gets new checks per architecture §10 (atomic spend, duplicate rewards, pause invariants, save/recovery, reset persistence, terminal precedence, prerequisite graph, earliest-win search) |
| `scenes/poc/poc.tscn` (Stage-0 top-down tilt) | Superseded by M1's isolated third-person entry under `scenes/v1/`; kept for git-history reference |

### Legacy data

- `user://chronolith_save.json` (2D prototype, schema v1) is incompatible with
  v1 profiles. v1 ProfileStore uses its own file + schema version; no migration
  path. Old profile on `main` remains playable there.
- Reference images: `reference images/*.png` = Marc's supplied art. NOTE: the
  GDD filename table has `8c8598c4…` and `9b155bc6…` swapped vs actual content —
  actual content: `0778c7df` combat camera/HUD, `be2e98cb` driving by base wall,
  `8c8598c4` research tree screen (Mechanical | Chronolith | Consciousness),
  `9b155bc6` Chronolith hero shot, `646f8fa2` rover/ali-tech + time-echo contrast.
