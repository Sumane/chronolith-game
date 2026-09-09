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

## M6a — expanded research: five lines, depth 45, temporal stasis (v1)

**Scope**: the research tree grows from 9 nodes/depth 21 to **14 nodes, depth 45,
five lines** — the wave-16 barrier (45 engram) is now reachable with no dead zone.
New: turret range + twin-cartridge (dmg/cd-split), aegis crystal shield, ram
capacitor, mag-coil harvest range, and the TEMPORAL line (Stasis Burst / Deep
Stasis). All effects are wired through the existing build/boot apply paths.

**Changes**
- `knowledge/research_tree.gd` — 14 nodes (t1-t4, f1-f3, r1-r4, x1-x2, mech);
  f2 Auto-Welder stays cost 3 (fort depth 9); total 45.
- `knowledge/knowledge.gd` — `applied()` min-merges `MIN_KEYS` (`time_factor`):
  x1 0.7 + x2 0.5 -> 0.5, never a speedup.
- `game/time_warp.gd` (new) — arena-mounted burst state: `factor()` /
  `active()` / `can_burst()` / `burst(f, dur, cd)`.
- `combat/enemy.gd`, `combat/warden.gd`, `combat/golem.gd` — movement scales by
  `arena.TimeWarp.factor()` (0.5x under Deep Stasis). Golem gains `arena`.
- `building/turret.gd` — `class_name Turret`, `range_m` (research 12 m max);
  `build_service` applies dmg 10+sum, cd 0.8-cd_base then × split (0.25 floor),
  range 8+sum.
- `player/player_rig.gd` — ram CD `maxf(1.0, 3.0 - ram_recharge)`; harvest
  radius `2.6 + harvest_range` (4.1 max) in both interact loops.
- `scenes/v1/entry.gd` — TimeWarp mounted on arena; **C** = stasis burst
  (x1: 2.5 s/12 s cd @ 0.7; x2: 5.0 s/10 s cd @ 0.5); crystal shield applies
  at boot (+25 integrity/max, f3).
- `ui/research_screen.gd` — two pages of 7 (P flips, 1-7 buy the visible page,
  key labels relabel per page).
- `progression/progression_model.gd` — model purchase rule gains the TEMPORAL
  chain.

**Validation** — `tests/v1/m6_probe.gd`: **14/14** (catalog 14/5/45; full-catalog
buy at 45/5; mech wallet gate 6<8; turret 25/0.25/12 m; wall 90; burst state
0.5/5/10 + recharge lock; grunt 0.93 m in 0.67 s under stasis; UI 2-page flip;
persist: crystal 75/75, rover 150 hp/10.5/2.0 s cd/4.1 m radius, turret line
persisted, harvest + mech transform at persisted chassis). Regression: m1 8/8,
m2 13/13, m3 13/13, m4 18/18, m5 13/13, progression 10/10 (catalog check
flipped to >= 45, earliest-win 5/9/13/17 + attempt-5 win unchanged), 2D smoke
71/71.

**Gotchas**
- `debug_instant_wave(n)` spawns exactly **n** grunts — probes asserting wave
  size 3 must pass 3.
- Edge spawns can be mid-fall: vertical velocity inflates `|v|`; speed probes
  must measure horizontal displacement.
- Starting cargo is **2** (M2 design) — probes funding the mech transform set
  `entry.cargo` directly; deposits are single-use per attempt.
- Saving while an attempt is still running resurrects its checkpoint on the
  next boot: probes must WIN (flow stopped) before the save that seeds entry 2.
- New `class_name` (TimeWarp, Turret) requires `--import` before the first run
  or dependent scripts fail to compile.

## M6b — 20-wave campaign (v1)

**Done (files only, NOT verified)**
- `waves/wave_director.gd` — `WAVE_PLAN` (20): `[3,3,4,4,5,4,6,5,7,6,8,7,9,8,10,9,11,10,12,14]`
  (145 grunts; breather dips every ~3 waves; wave 20 climax 14);
  `WARDEN_WAVES {3,7,11,15,19,20}`, `GOLEM_WAVES {5,10,16,20}`; live
  `wave_plan` var (probes override to the 3-wave prototype); `_spawn_golem`
  + `golem_event` signal; WIN at `wave >= wave_plan.size()`.
- `scenes/v1/entry.gd` — labels/HUD/grant now use `director.wave_plan.size()`;
  director golem events -> armor-blocked banner.
- m2/m4/m5/m6 probes: `director.wave_plan = [3,4,5]` on every entry that
  expects the old 3-wave win (m3 never wins — no override needed).
- `tests/v1/m6b_probe.{gd,tscn}` — NEW, not yet run: plan shape (20/145/
  schedule), full 20-wave debug run (warden+golem observed on the right
  waves, WIN only at 20, 20 engrams), prototype-mode win at 3.

**Tomorrow: in order**
1. `godot --headless --import` (no new class_names expected, but safe).
2. Run `tests/v1/m6b_probe.tscn` (~60 s: 20 waves + 3 waves).
3. Full regression (m1-m6, progression, 2D smoke) — the wave_plan overrides
   are the risk area.
4. Commit M6b; then M6c (map: corridors/cover/4 deposits), M6d (earliest-win
   rerun on real campaign data), M6e (counter hints + input remapping),
   M6 wrap (doc + commit).

**Scope**: the campaign is now the full twenty waves. `WAVE_PLAN`
`[3,3,4,4,5,4,6,5,7,6,8,7,9,8,10,9,11,10,12,14]` = 145 grunts with breather
dips every ~3 waves; Warden on 3/7/11/15/19/20; Golem on 5/10/16/20;
wave 20 is the 14-grunt + Warden + Golem climax. WIN fires at
`wave >= wave_plan.size()`.

**Changes**
- `waves/wave_director.gd` — `WAVE_PLAN` (20) replaces `WAVE_SIZES` (3);
  `wave_plan` is a live instance var (probes set it to the 3-wave
  prototype); `GOLEM_WAVES` + `_spawn_golem` + `golem_event` signal;
  `debug_instant_wave` spawns the golem too on golem waves.
- `scenes/v1/entry.gd` — win label "CAMPAIGN CLEAR: N WAVES", checkpoint
  banner "WAVE n OF N", HUD wave count, engram grant all read
  `director.wave_plan.size()`; director golem events feed the armor-blocked
  banner.
- m2/m4/m5/m6 probes: `director.wave_plan = [3,4,5]` on every entry that
  expects the old 3-wave win (m3 never wins — untouched).
- `tests/v1/m6b_probe.{gd,tscn}` — NEW: **26/26**.

**Validation** — m6b probe: plan shape (20 waves / 145 grunts / exact
schedule); a full 20-wave debug run observes Warden live on 3/7/11/15/19 and
Golem on 5/10/16 (wave 20 = both), no early win, 20 engrams earned, prototype
`[3,4,5]` still wins at wave 3. Regression: m1 8/8, m2 13/13, m3 13/13,
m4 18/18, m5 13/13, m6 14/14, progression 10/10, 2D smoke 71/71.

**45-minute tuning** (feel is Marc's review): PREP_TIME 20 s between waves;
assaults scale ~15 s (wave 1) to ~90 s (wave 20); breather dips (waves
6/8/12/14/16/18) are the build windows. Knob to tighten: PREP_TIME -> 15.

**Gotchas**
- `for w in 20` in GDScript iterates 0..19 — campaign probes must do
  `var w := i + 1`.
- The probe kill loop must pierce Golems (`damage(999, true)`): flat shots
  (turret 10) are fully blocked by armor 20, and a one-shot direct fallback
  (99 -> 79 net) leaves a 300 hp Golem alive, which blocks the wave relay and
  contaminates the next boot's checkpoint.
- `director.wave_plan` override must come after the `director` ref is
  acquired (m2 acquires it late — the override used to hit a Nil base).

## M6c — recognisable campaign map (v1)

**Scope**: the arena becomes a readable map — four rock cover clusters
flanking the eight edge approaches, lane pinch rocks, and a five-deposit
resource distance ladder (7 / 10 / 13 / 17 / 21 m from the crystal). Each
deposit sits off the main lanes, most beside a cover cluster: harvesting is
always a detour with a partial view of the approach that feeds it.

**Changes**
- `world/arena.gd` — `ROCKS` relayout: NE cluster + pinch (lanes E1/E3),
  NW cluster (E2/E5), SW cluster (E6), SE cluster (E4/E7), four mid-ring
  solos holding the central approach; blocker rock (0,-2) kept — it flanks
  the north-centre lane and the m1 LOS test; M1 Target1-3 kept (probe
  dependency, M7/M8 can re-home them). `DEPOSIT_POS` ladder: (6,4) (7.2 m),
  (-7,7) (9.9), (11,-6) (12.5), (-14,10) (17.2), (15,15) (21.2).
- `tests/v1/m6c_probe.{gd,tscn}` — NEW: **5/5** (ladder within 0.4 m, 18
  colliders, 8 edges, grunts from N/NW/SE/SW each close 4+ m toward the
  crystal in 90 frames, north-centre lane still occluded).

**Validation** — full regression after the relayout: m1 8/8 (blocker LOS
intact), m2 13/13, m3 13/13, m4 18/18, m5 13/13, m6 14/14, m6b 26/26 (full
campaign navigation over the new rocks), m6c 5/5, progression 10/10, 2D
smoke 71/71.

**Gotchas**
- Build exclusion: a cell center must stay >= r+0.9 from every rock. The
  m2/m3 probes canonically build at world (10,10) — the SE cluster was
  moved to wrap that pocket, not fill it. Map edits near probe build
  points (m2 (10,10)/(13,13), m3 (10,10), m6 (5.5,3.5)/(3.5,5.5)) must be
  checked against this rule.

## M6d — model sync + earliest-win revalidation (v1)

**Scope**: the progression model consumes the expanded catalog and the
TEMPORAL line; the earliest-win validation is rerun against the real
20-wave campaign barrier data.

**Result** — `progression_model.gd` purchase rule includes
`line_chain("TEMPORAL")` (done in M6a). `docs/progression-traces.json`
regenerated: catalog depth **45** (wave-16 barrier gap closed), reference
clears `[5, 9, 13, 17, 20]` (cumulative engrams `[5, 14, 27, 44, 64]`),
**earliest win attempt 5 for 0/1/2 nukes — unchanged by the catalog
expansion**, exactly as the barrier semantics predict (barriers check
earned engrams; purchase dynamics never move the earliest win).
Progression probe 10/10 with the catalog check flipped to >= 45.
