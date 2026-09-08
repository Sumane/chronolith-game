# CHRONOLITH — Progress (keep this file short)

## Current milestone

**M3 — Engrams, full planning pause, persistence: BUILT (branch `v1`).**
M1 feel review (camera/weight) still open — tuning-only when it lands.
Next: **M4 — Prove counter freedom and the progression model**.

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
N early start, R new attempt after loss. **M3: G opens Engram Research
between waves (1-6 buy, Esc/G closes; the whole sim pauses).** Gamepad
works too.

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


## M3 — engrams, planning pause, persistence (DONE, committed)

- **Engrams**: 1 per cleared wave (incl. the final wave on win), idempotent
  per `attempt:wave` receipt — reloading a wave-clear state never re-grants.
- **Research tree** (`knowledge/research_tree.gd`): 3 lines × 2 tiers, 6
  nodes, deterministic (costs 1/2, tier-2 requires tier-1): turret
  damage / cooldown, wall hp / self-repair, rover hp / speed.
- **Ledger** (`knowledge/knowledge.gd`): earned/spent/balance, atomic
  research, `applied()` stat rollup.
- **Research screen** (`ui/research_screen.gd`, blockout): full tree pause;
  earned/spent/balance, prereq + effect + cost per row; keys 1-6 buy.
  Purchase = memory apply → **verified save** → on save failure the purchase
  is rolled back (refund invariant).
- **ProfileStore** (`core/profile_store.gd`): schema-versioned JSON at
  `user://chronolith_v1_profile.json`; save = tmp write → round-trip verify
  → backup → rename; load = original → `.bak` (recovered) → fresh.
- **Checkpoint**: attempt identity (id, wave, cargo) saved at every
  wave-clear/purchase/attempt-end; boot resumes the same attempt identity.
  Physical resources/equipment reset on a new attempt; knowledge + receipts
  + story flags persist.
- **Effects**: applied at construction (`BuildService._apply_effects`),
  rover at boot (`apply_research`); turret damage/cooldown via new
  `combat.fire(from,to,exclude,dmg)` parameter.

Probe: `res://tests/v1/m3_probe.tscn` → **13/13, exit 0** (fresh boot;
wave-clear engram + receipt-once; research opens only in prep and pauses the
tree; **no sim drift across a 4 s planning pause**; purchase f1 → wall
spawns with 90 hp; **save failure refunds the purchase**; checkpoint load =
same attempt id/wave/cargo/knowledge; **reloaded wave-clear does not
re-grant**; nested menu cannot unpause combat; **corrupt save recovers from
backup**; prereq invariant). M1 **8/8**, M2 **13/13**, 2D **71/71** all
re-run green.

## Known limitations

- Navigation = steering + real collision (forward probe + side bias +
  stuck-breaker). A grid navmesh is a later upgrade, not a blocker.
- Wall/turret HP and all economy numbers are unvalidated guesses.
- M1 feel review (camera/orbit/weight) still pending from Marc; M2 tuning
  knobs: `Grunt` SPEED/ATTACK, `WaveDirector` WAVE_SIZES/PREP_TIME,
  `Turret` RANGE/COOLDOWN, costs in `BuildService.COSTS`; M3:
  `ResearchTree.NODES` (costs/effects), `PREP_TIME` (planning window).
- **Pause semantics**: the entry root sets `process_mode = PAUSABLE`
  explicitly — under an ALWAYS parent (headless probes) an INHERIT subtree
  would never pause; caught by the M3 drift check.
- Probes clear `user://chronolith_v1_profile.json*` at boot (shared
  XDG-isolated user:// — real player saves under `~/.local/share` are
  untouched).
- **Release gap (accepted for M3)**: research is between-wave only
  (PREP phase); mid-wave suspension not implemented.
- v0 `user://chronolith_save.json` (schema v1) is NOT migratable to the
  v1 ProfileStore.
- 4.7.1 API notes: raycasts =
  `PhysicsRayQueryParameters3D.create(from,to,mask,exclude)` +
  `space.intersect_ray(query)`; mesh arrays = `ARRAY_MAX`-sized slot array
  (`Mesh.ARRAY_TEX_UV`, not `ARRAY_UV`); `Node` has no `get_world_3d()`;
  `InputMap.action_add_keyevent` takes an `InputEventKey`, not a Key;
  a `class_name` shadows 2D preload-const names (2D `Enemy` is a preload
  const in waves_controller — 3D grunt is `Grunt`); `:=` cannot infer from
  Variant members (untyped `Node` refs / Dictionary indexes).

## M4 — counter freedom + progression model (DONE, committed)

- **Warden** (`combat/warden.gd`, joins wave 3 via `WaveDirector.WARDEN_WAVES`):
  150 hp, armor 5 (flat; bypassed by pierce/ram/deflect), seek->tell (1.2 s
  telegraph)->charge (3.5 m/s, 1.6 s)->hit 25 dmg; deflects turret rounds
  (40 dmg, 5 m) unless hit while charging; rovers aggro within 6 m and take
  priority over the crystal.
- **Three counter paths, all machine-verified (M4 probe 18/18):**
  1. *Turret (pierce)* - research t1 gives piercing shots that bypass armor;
     verified: 10-dmg pierce kills a charging Warden, armor shows `resist`
     HUD feedback against flat shots.
  2. *Wall* - Warden path blocked by wall; melee branch attacks buildings
     (<7 m) instead of the crystal; wall hp drain verified.
  3. *Rover (ram)* - LShift: 30 pierce damage, -15 rover hp, 3 s cooldown,
     4.5 m ray (long enough for camera-aim muzzle offset); verified 5 rams
     kill a 150 hp Warden (armor bypassed).
- **Nuke**: F, 1 charge/attempt (standard), clears the whole field; permissive
  2-charge case exists only in the progression model (GDD check case).
- **Progression model** (`progression/progression_model.gd` +
  `tests/v1/progression_probe.tscn`, 10/10): shares `ResearchTree` data,
  ledger/nuke/respec rules; reproduces the GDD reference table (5/9/13/17
  clears, cumulative 5/14/27/44, win attempt 5); exhaustive search over
  nukes 0/1/2 x respec x placements proves **earliest win = attempt 5
  under every strategy** and attempts 1-4 infeasible (gaps exported to
  `docs/progression-traces.json`); real catalog depth (9) vs wave-16
  threshold (45) quantifies the M6 research-graph expansion.
  Full limitation list: `docs/progression-model.md`.
- **Regression note (M2 probe)**: wave 3 now carries a Warden - the M2
  kill loop ray is blocked by the (9,-2) rock at the Warden's spawn edge,
  so the probe finishes unreachable enemies with a direct hit (test
  convenience, documented in `tests/v1/m2_probe.gd`).
- **4.7.1 API notes added**: crystal collider is a *child* StaticBody3D
  (ray hits the child, never the Chronolith node); a ray starting inside a
  non-excluded StaticBody3D returns `{}`; a freshly spawned collider is not
  visible to same-frame rays (~15 frames to sync); `var x := <Variant>`
  parse error -> use explicit types.
- **Tuning bug note**: `turret.gd` had `var damage` shadowing the parent
  `func damage(n)` - renamed `dmg` (M4 parse-error fix).

## Exact next task (M5, from chronolith-agent-tasks.md)

Prototype the mech payoff: one Hybrid stage + one warrior-mech stage
research/construct; clearly changed body, mobility, weapons, camera;
command target that requires the mech while base enemies keep attacking;
defence-heavy and rover-heavy routes both reachable. Short integrated
scenario proves the mech is exciting and necessary.

## Changed files (this milestone)

- New: `combat/warden.gd`, `progression/progression_model.gd`,
  `tests/v1/m4_probe.{gd,tscn}`, `tests/v1/progression_probe.{gd,tscn}`,
  `docs/progression-model.md`, `docs/progression-traces.json`
- Changed: `waves/wave_director.gd` (WARDEN_WAVES, warden spawn/relay),
  `player/player_rig.gd` (ram), `scenes/v1/entry.gd` (ram/nuke keys,
  nuke charge, warden events to HUD), `ui/hud.gd` (resist/telegraph/
  nuke/ram feedback), `combat/combat.gd` (pierce/deflect hit kinds),
  `building/turret.gd` (dmg var, deflect), `building/build_service.gd`,
  `tests/v1/m2_probe.gd` (Warden-aware kill loop), `docs/progress.md`

## M5 — the mech payoff (DONE, committed)

Hybrid stage prototype: research "mech" (3 engrams, needs r2) → build
(8 scrap, T key) → the body changes to the warrior mech. B key spawns
the Golem command target (debug).

- `MechData` (mech stats): 250 hp / armor 3 / speed 6.5 / gun 40 pierce
  @ 0.5 s cd / camera 5.0 (rover: 100 hp / 9.0 / 6.5).
- `Golem` (command target): 300 hp, armor 20 (flat shots fully blocked,
  pierce bypasses), 1.2 m/s, melee 40 @ 1.5 s, always advances on the
  crystal, attacks buildings.
- Payoff verified by probe: flat fire blocked (hp stays 300); rams chip
  exactly 10 each (30 flat − 20 armor) while the body still pays 15 hp
  per ram — the body cannot finish it; the mech gun (20 net/shot) kills
  it in ~15 shots; base grunts keep advancing on the crystal while the
  mech fights; a new attempt returns the body to the starter rover but
  blueprint knowledge (and its applied stats: +50 hp, +1.5 speed)
  persists.
- Both routes reach the mech (probe): defence-heavy (turret+wall,
  r1+r2 from 3 engrams) and rover-heavy (no builds, 2 harvests:
  6+2 ≥ 8 build cost).
- Progression model sync: `ProgressionModel.MECH` now mirrors the real
  catalog (cost 3 / req r2 / build 8); the gate check searches all
  attempts up to the win because research persists across attempts
  (mech buys in attempt 2, wave 7, builds on the winning attempt).

### M5 gotchas (learned the hard way)

- **Checkpoint pollution**: never re-arm `entry.flow.running = true`
  after a WIN and then save — `_profile_data()` persists a mid-attempt
  checkpoint (`attempt {wave: 3}`) and the next entry boots into wave 3
  (instant warden + `attempt_won`). Probes unpause the tree only.
- **`rig.ram()` miss is free**: no cost, no cooldown — a stale
  camera-owned aim loops forever. Re-aim with `debug_set_aim` in the
  SAME FRAME as the ram (no await between).
- Ram ray is 4.5 m from the muzzle — the probe teleports the rover 3 m
  behind the Golem on its approach line each try (in ram range, out of
  its 2.2 m melee range).
- Golem melee on the rover body: the Rover (CharacterBody3D) has no
  `damage()`; the Golem falls back to the parent rig.

### Open gaps carried forward

- Grunt/Warden attacks on the rover body are silently skipped
  (`has_method("damage")` guard) — only the Golem got the parent
  fallback (M3 gap, still open).
- `debug_instant_wave(n)` does not increment `wave`, so the Warden
  (tied to director `wave`) only appears on the 3rd cleared wave.
- Model ↔ game data sync is a mirror const (documented in
  docs/progression-model.md).

## Changed files (M5)

- New: `combat/golem.gd`, `mechanic/mech_data.gd`, `tests/v1/m5_probe.{gd,tscn}`
- Changed: `knowledge/research_tree.gd` (7th node "mech"),
  `ui/research_screen.gd` (keys 1–9), `player/player_rig.gd`
  (mech transform/demolish, mech fire, cam dist), `scenes/v1/entry.gd`
  (T/B keys, mech fire branch, HUD body label),
  `progression/progression_model.gd` (MECH mirror const),
  `tests/v1/progression_probe.gd` (gate searches all attempts),
  `docs/progress.md`
