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
Esc pause. M2: E harvest/repair, 1 wall / 2 turret (LMB place, X/Esc cancel),
N early start, R new attempt after loss. Gamepad works too.

## M2 — playable three-wave defence (DONE, committed)

Full loop in `res://scenes/v1/entry.tscn`:
- **Harvest**: 5 scrap deposits (hold E, 0.5 s per scrap, 5 each).
- **Build**: 1 wall (2 scrap, 60 hp) / 2 turret (4 scrap, 40 hp, 8 m range,
  0.8 s cd, 10 dmg). Transparent ghost preview snapped to 1 m grid
  (green/red), occupied-footprint + rock + flatness validation, atomic
  spend→place, repair with E (1 scrap → +10 hp).
- **Enemy**: Grunt (20 hp, 3.2 m/s) seeks crystal, melees it (6/hit); aggro
  to rover within 6 m (5/hit); attacks obstructing walls (4/hit); steers
  around rocks with forward-probe + bias flip; stuck-breaker keeps it acting
  (an enclosed base never freezes enemies).
- **Waves**: 3 prep/assault rounds, sizes 3/4/5, 20 s prep, N = early start,
  staggered edge spawns, direction banner. Wave clear → next prep; wave 3
  clear → attempt won ("PROTOTYPE RESULT" overlay, not campaign completion).
- **Attempt**: rover 100 hp / crystal 50 integrity; either death → ATTEMPT
  LOST overlay; R (or Start) reloads a clean new attempt.
- HUD blockout: scrap + costs, wave state, rover/crystal HP, banners, hints.

Probe: `res://tests/v1/m2_probe.tscn` → **13/13, exit 0** (harvest; build;
no duplicate placement; no double-spend when poor; enemy attacks obstructing
wall; enemy approaches crystal with rock detour; combat kill; wave clear →
wave 2; three-wave win + overlay; no harvest while paused; rover death and
crystal death end the attempt). M1 probe **8/8**, 2D suite **71/71** — both
re-run after M2.

Input: v1 entry calls `InputSetup.setup()` (2D runtime InputMap) — fix for a
real bug where v1 never registered any input actions. v1 adds
restart_attempt (R), build_wall (1), build_turret (2), early_start (N);
cancel_build (X/RMB) and fire (Space/LMB), interact (E) come from InputSetup.

## Known limitations

- Navigation = steering + real collision (forward probe + side bias +
  stuck-breaker). A grid navmesh is a later upgrade, not a blocker.
- Wall/turret HP and all economy numbers are unvalidated guesses.
- M1 feel review (camera/orbit/weight) still pending from Marc; M2 tuning
  knobs: `Grunt` SPEED/ATTACK, `WaveDirector` WAVE_SIZES/PREP_TIME,
  `Turret` RANGE/COOLDOWN, costs in `BuildService.COSTS`.
- 4.7.1 API notes: raycasts =
  `PhysicsRayQueryParameters3D.create(from,to,mask,exclude)` +
  `space.intersect_ray(query)`; mesh arrays = `ARRAY_MAX`-sized slot array
  (`Mesh.ARRAY_TEX_UV`, not `ARRAY_UV`); `Node` has no `get_world_3d()`;
  `InputMap.action_add_keyevent` takes an `InputEventKey`, not a Key;
  a `class_name` shadows 2D preload-const names (2D `Enemy` is a preload
  const in waves_controller — 3D grunt is `Grunt`); `:=` cannot infer from
  Variant members (untyped `Node` refs / Dictionary indexes).

## Exact next task (M3, from chronolith-agent-tasks.md)

Engrams: full planning pause, engram spend/preview, persistence +
ProfileStore (schema-versioned saves).

## Changed files (this milestone)

- New: `world/deposit.gd`, `chronolith/crystal.gd`, `building/{
  building_base,wall,turret,build_service}.gd`, `combat/enemy.gd`,
  `waves/wave_director.gd`, `game/flow.gd`, `ui/hud.{gd,tscn}`,
  `tests/v1/m2_probe.{gd,tscn}`
- Changed: `world/arena.gd` (crystal node, deposits, rock_list),
  `player/player_rig.gd` (hp, interact channel, can_fire, debug hooks),
  `scenes/v1/entry.gd` (full M2 wiring, overlays, wallet), `docs/progress.md`
