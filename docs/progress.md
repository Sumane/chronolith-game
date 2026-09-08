# CHRONOLITH — Progress (keep this file short)

## Current milestone

**M1 — Establish the intended game view: BUILT (2026-09-07, branch `v1`).**
Awaiting Marc's camera/feel review (the first product checkpoint). Next:
**M2 — Playable threat loop** (only after feel feedback is settled).

## M1 acceptance (machine-verified)

- [x] Isolated 3D entry: `res://scenes/v1/entry.tscn` — arena + PlayerRig +
      Combat; 2D `main.tscn` untouched.
- [x] Hand-built arena: 40 m heightmap terrain (real `HeightMapShape3D`
      collision), west slope ridge, flat central build-pad, 11 shot-blocking
      rocks, fixed Chronolith crystal, 3 damageable targets.
- [x] Third-person driving: camera-relative WASD, forgiving accel/turn,
      bounds clamp; **not inverted** — forward is always toward where you look.
- [x] Rover-following orbit camera (mouse drag, clamped pitch, obstacle
      pull-in raycast, rover kept lower-centre) + gamepad: left stick move,
      right stick camera, A fire, Start pause.
- [x] Manual weapon: hitscan with real 3D obstruction (rock provably blocks a
      shot in the probe), tracer FX, muzzle socket.
- [x] Pause: tree-pause + distinct input context (only the pause gate reads
      input while paused); rover provably frozen; resume works.
- [x] Placeholder-visual separation + `docs/asset-conventions.md` (sockets:
      `Turret`/`Muzzle`, 1 unit = 1 m, origin at ground contact).
- [x] Probe: `res://tests/v1/m1_probe.tscn` → **8/8, exit 0**; 2D suite still
      **71/71, exit 0**.
- [ ] **Marc's feel review** — camera distance/height/orbit speed and driving
      weight are tuning guesses (6.5 m, +1.3 m, 9 m/s). Not settled until seen.

## Launch the current 3D playable

```bash
cd /home/marc/AI/Chronolith-Game
godot --path . res://scenes/v1/entry.tscn
```
WASD drive, mouse orbit/aim (cursor hidden, crosshair ring), LMB fire,
Esc pause. Gamepad works too.

## Known limitations

- No enemies/waves/research/building yet (M2+).
- Camera feel + driving weight unreviewed — expect tuning.
- v1 economy numbers unvalidated; `data/*.json` values are v0 tuning only.
- 4.7.1 API notes for future work: raycasts =
  `PhysicsRayQueryParameters3D.create(from,to,mask,exclude)` +
  `space.intersect_ray(query)`; mesh arrays = `ARRAY_MAX`-sized slot array
  (`Mesh.ARRAY_TEX_UV`, not `ARRAY_UV`); `Node` has no `get_world_3d()`.

## Exact next task (M2, from chronolith-agent-tasks.md)

First enemy + threat loop in the v1 entry: enemy that navigates the 3D
terrain toward the rover/base, combat round-trips with real damage and death,
spawn/wave budget hook, kill→reward flow — all blockout visuals, headless
probe for the loop, then back to Marc for feel.

## Changed files (this milestone)

- New: `player/player_rig.{gd,tscn}`, `combat/combat.gd`,
  `combat/target_dummy.gd`, `world/arena.gd`, `scenes/v1/{entry.tscn,
  entry.gd,arena.tscn}`, `tests/v1/m1_probe.{gd,tscn}`,
  `docs/asset-conventions.md`
- `docs/progress.md` (this file)
