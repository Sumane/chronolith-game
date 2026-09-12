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

## M6e — counter explanations + input remapping (v1)

**Scope**: the game tells you what is coming and what beats it, and the
core actions answer to a gamepad.

**Changes**
- `scenes/v1/entry.gd` — `_on_wave_started` appends a counter warning to
  the inbound banner: WARDEN waves ("PIERCE OR RAM"), GOLEM waves ("FLAT
  SHOTS BLOCKED (PIERCE OR RAM)"), both on wave 20.
- `ui/research_screen.gd` — static counter strip under the stats line:
  "COUNTERS — Grunt: any damage · Warden: pierce shot or ram · Golem:
  armor 20 blocks flat shots — pierce or ram".
- `core/input_map_setup.gd` — `GAMEPAD_BINDINGS` (Xbox layout): A fire,
  B interact, X/Y build 1/2, right-stick cancel, Start pause, Back new
  attempt, d-pad movement. Registered alongside the existing keyboard and
  mouse events; runtime-added v1 keys (G/C/T/F/P) stay keyboard for now.
- `tests/v1/m6e_probe.{gd,tscn}` — NEW: **11/11** (banner warnings on
  3/5/20/1, no false warning on wave 1, counter strip present, six core
  actions carry gamepad + legacy bindings).

## M6 — complete

**Done criteria**: playable twenty-wave route (m6b: full campaign run,
exact counter schedule, WIN only at wave 20) + recognisable map (m6c) +
~45 active minutes (tuning knobs documented in wave_director.gd: PREP_TIME
20 s, wave 1 ~15 s assault to wave 20 ~90 s, breather dips — feel is Marc's
review) + usable final route per specialisation (M6a: all five lines reach
their terminal node, mech gate 8 scrap, five routes demonstrated in the
progression traces) + counter explanations and warnings + input remapping
(m6e). Earliest-win revalidated on real campaign data (M6d: attempt 5,
unchanged).

**Validation** — final regression: m1 8, m2 13, m3 13, m4 18, m5 13, m6 14,
m6b 26, m6c 5, m6e 11, progression 10 (131 v1 checks) + 2D smoke 71 — all
green.

**Known gaps carried to M7/M8**: right-stick camera aim and stick movement
(gamepad aim deferred — buttons/d-pad work); grunt/warden attacks on the
rover body are skipped where the node lacks damage(); build.occupied not
cleared on building destruction; kill scrap is probe-only; M1 target
dummies and the 2D-era blocker remain on the map (probe dependencies,
re-home in M7/M8).

## M7 — story, finale and one ending (v1)

**Scope**: the GDD's single ending, playable and probe-verified. Vael's
upload opens the first boot; milestone memories fire once; Vrax commands
the wave-20 finale; the seal is repaired, the loop ends, Vael answers
NASA. Completion is recorded before the ending plays; a finale defeat is a
normal defeat; the ending skips after completion. No victory reset, no
second ending, temporal builds keep their abilities.

**Changes**
- `combat/vrax.gd` — NEW: Vrax (extends Warden, 400 hp, biomechanical
  dark-red, 1.4x). The GDD's "mech is required to defeat the final boss":
  flat shots fully ignored, non-mech piercing chips (n/4 — fortresses
  "actively control" the fight), only the mech's heavy round deals full.
  Wall deflect still stuns, never damages.
- `combat/combat.gd` — `fire(..., mech: bool = false)`; Vrax branch passes
  the mech flag (checked before the Warden branch — Vrax is-a Warden).
- `waves/wave_director.gd` — `_spawn_vrax` replaces the Warden on the
  final full-plan wave (20); `warden_died`/`golem_died` relays; `vrax` ref.
  `debug_instant_wave` spawns the boss on wave 20 of the full plan.
- `scenes/v1/entry.gd` — story state in the profile (`story_flags`:
  seen_opening, memories, completion, ending_seen); pausable skippable
  beat overlay (CanvasLayer 20) driven by `story/beat_gate.gd`
  (PROCESS_MODE_ALWAYS, any key or gamepad button closes); opening beat on
  first boot; one-shot memory beats (first Warden, first Golem, mech
  transform); Vrax taunt on wave 15 and finale text on wave 20; win path:
  completion persisted **before** the ending beat, ending seen once, then
  skipped; `_on_fired` mech round passes the mech flag.
- Nine v1 probes set `entry.story_enabled = false` (beats off; the m7
  probe drives the story itself).
- `tests/v1/m7_probe.{gd,tscn}` — NEW: **24/24** across three entries
  (fresh: opening + memory beats + Vrax gate + finale; returning:
  death-in-finale keeps completion; second victory skips the ending).

**Validation** — full regression after M7: m1 8, m2 13, m3 13, m4 18,
m5 13, m6 14, m6b 26, m6c 5, m6e 11, m7 24, progression 10 (155 v1 checks)
+ 2D smoke 71 — all green.

**Gotchas**
- GDScript: no implicit multi-line string concatenation inside parentheses
  (parse error "Expected closing ')'"); STORY_* consts are single-line.
- `MeshInstance3D` in 4.7.1: tint via `get_material_override()` — there is
  no `get_material`/`get_surface_material`.
- Beats pause the tree: probe waits must use `process_frame`, never
  `physics_frame` (physics frames stop while paused = silent hang).
- Control has no `layer` — beat UI lives in a CanvasLayer (layer 20).
- A beat may open with the tree already paused (the ending): the close
  restores the pre-beat pause state, it never unpauses the win screen.

## M8 — endless continuation and release hardening (v1)

**Scope**: post-victory endless defence, safe pause, bounded spawns, the
tested performance envelope and the documented remaining limitations.

**Changes**
- `waves/wave_director.gd` — `endless` mode: `begin_endless()` (wave 21,
  prep countdown, no WIN state — the relay only advances); endless budget
  `endless_size(w) = min(14 + (w-20)/2, 20)` (knob: slope/cap); endless
  counters: Warden on `w % 3 == 2`, Golem on `w % 5 == 0`, Vrax never
  respawns; `MAX_ALIVE = 24` spawn bound applied to real and debug waves.
- `scenes/v1/entry.gd` — C on the win screen continues the victorious
  physical state (rover/mech, buildings, cargo) into endless; endless
  defeat is a separate "ENDLESS RUN ENDED AT WAVE n" screen — completion
  and knowledge stay recorded, the finale never replays, and C does not
  restart endless from a loss screen (R = fresh attempt with knowledge);
  the nuke now skips Vrax (9999/4 chip would have killed the boss — the
  mech is required); `_last_win_was_full` gates the continue path.
- `ui/hud.gd` — "WAVE n (ENDLESS)" readout.
- `tests/v1/m8_probe.{gd,tscn}` — NEW: **19/19** (continue into wave 21,
  relay past the campaign, endless engram once, Warden-but-never-Vrax on
  23, spawn bound 30→22, pause freeze/resume incl. nuke charges,
  endless defeat separation, refused endless restart from loss).

**Performance envelope (measured)** — headless, Godot 4.7.1, this machine
(30 GB RAM; a healthy run holds ~118 MB): 250 frames at the 22-enemy
spawn bound = ~6.9 ms/frame average, no errors, no leaked node groups.
Headless numbers bound the CPU cost of simulation only; expect the
frame budget to be display-bound, not simulation-bound, on real hardware
up to the spawn bound. Above MAX_ALIVE the director simply stops
spawning — a viable strategy is never destroyed by an uncapped field.

**Remaining limitations (documented, not blockers)**
- No right-stick camera aim / stick movement (d-pad + buttons work);
  no audio, no final art pass, no weather, no bounded adaptation AI —
  all explicitly deferred by the GDD.
- Grunt/Warden attacks on the rover body are skipped where the node
  lacks damage(); build.occupied is not cleared on building
  destruction; M1 target dummies + the 2D-era blocker rock stay on the
  map as probe dependencies.
- 2D save corrupt-guard still prints the pre-existing JSON error line.

## M9 — input fix: every menu is closable (v1)

Playtest reports: research could not be closed with G/Esc; the pause
menu could not be closed with Esc (only R, and R was dead while paused);
terrain hard to read; no way to remove buildings (last two follow on).

Root cause: the entry sets `PROCESS_MODE_PAUSABLE` on its subtree (required
so headless probes see the tree stop when paused). While `tree.paused`,
the whole subtree is input-dead — even children set to `PROCESS_MODE_ALWAYS`
do not receive `_unhandled_input`. Any gate inside the subtree could never
close what it guarded. Secondary: mid-event state flips — a handler that
unpauses mid-propagation makes the subtree live again and it re-processes
the same event (double-toggle: gate unpauses, rig re-pauses).

Fix: the four always-live gates (Beat, Pause, Research, Restart) are now
attached to `get_tree().root` (deferred, so they survive scene setup),
each owning its keys exclusively and calling `set_input_as_handled()` so
the mid-event unpause cannot let the entry subtree re-process the same
event. The rig no longer handles `pause_toggle` (PauseGate owns it and now
toggles both ways); the entry no longer handles `research_toggle`
(ResearchGate owns open+close). Gates detach via `queue_free()` in
`_exit_tree` (synchronous `remove_child` fails during reload teardown).

New `tests/v1/input_probe.tscn` (16 checks): research open/close via G and
Esc with a no-self-close stability window; pause Esc-toggle stability x2;
opening beat opens on first boot with its text and closes on any key;
explicit beat close; end screen + root-level restart gate (ALWAYS, bound
callable) after a 1-wave win; all root gates freed with the entry.

Full regression green: m1-m8 142 + progression 10 + input 16 + 2D smoke 71.

## M10 — terrain readability (v1)

Playtest: "the terrain is difficult to see ... a horizon / some square
placeholder tiles to make out the terrain."

`world/arena.gd` changes:
- Terrain albedo is now a generated 640 px grid texture (16 px per metre
  tile = 1 m square placeholder tiles across the 40 m pad): base Mars tone
  with deterministic speckle noise plus a bright line at every tile edge.
  UVs rescaled 0..1 so the texture covers the arena 1:1 (no repeat-mode
  dependency).
- A 500 m dark plain sits 2.5 m under the heightmap, so looking over the
  arena edge meets the fog instead of the void — a real horizon.
- Fog density 0.01 -> 0.03 so the far arena edge softens into the plain.

New `tests/v1/terrain_probe.tscn` (3 checks): grid texture on the terrain
mesh, wide plain present, fog raised. Full regression green (158 v1 +
this probe + 2D smoke 71).

## M11 — selling buildings (v1)

Playtest: "there doesn't seem to be an option to drop turrets and walls
etc."

New mechanic — aim the crosshair at a building, press **Z / RMB /
gamepad RIGHT_SHOULDER**, get half its cost back (wall 2 -> 1, turret
4 -> 2). RMB while a placement is active still cancels the placement
(it is checked first in the input chain), so the two never clash.

- `building/build_service.gd`: `sell(b)` — validates the target is a
  living `BuildingBase`, frees its grid cell (`occupied`), credits the
  refund (`floor(cost / 2)`) via the wallet, emits `build_sold`,
  `queue_free`s the building. Guards: non-building, already-destroyed.
  A freed reference is rejected by the typed parameter itself.
- `scenes/v1/entry.gd`: `sell_build` action (Z) + RMB fallback route in
  `_unhandled_input`; `_try_sell()` fires the crosshair ray (200 m,
  rover excluded) and sells the first living building it hits, with a
  "SOLD WALL (+1 scrap)" / "CANNOT SELL: reason" banner.
- `player/player_rig.gd`: `aim_ray()` (screen-centre ray for
  raycast-based interactions) and `debug_set_orbit()` / `debug_aim_at()`
  test hooks.
- `building/wall.gd`: `class_name Wall` (needed for the `is Wall` type
  check; was missing).
- `core/input_map_setup.gd`: `sell_build` -> RIGHT_SHOULDER binding.

Input-registration bug fixed along the way: `InputSetup.setup()` ran
before `_register_actions()`, so the gamepad-created `sell_build`
action made `_add_key`'s `has_action` guard silently skip the Z key.
The call order is swapped and `_add_key` now only skips a key it has
already added (static per-action map — InputMap has no public event
enumeration API), so reloads stay duplicate-free.

New `tests/v1/sell_probe.tscn` (17 checks): sell refunds + wallet +
cell freed + rebuildable; dead/non-building guards; keyboard Z and
gamepad RIGHT_SHOULDER routes through the real crosshair ray (a
verified wall on the live ray, camera fully converged); RMB cancels a
placement instead of selling; gamepad `build_1` (X) reaches the entry.

Full regression green: m1-m8 142 + input 16 + terrain 3 + progression
10 + sell 17 + 2D smoke 71.

## M12 — health bars (v1)

Playtest: "a health bar for enemies above their head, for the player
top-left of the screen, and the crystal bottom-center."

- `ui/enemy_hp_bar.gd` (new): `EnemyHpBar` — a floating 3D bar (unshaded
  backing plate + left-anchored red fill with a polygon offset, so no
  z-fighting). Hidden while the enemy is at full health, shown on
  damage, and billboards toward the active camera every frame.
- `combat/enemy.gd` (Grunt), `combat/warden.gd`, `combat/golem.gd`:
  each owns an `hp_bar` child named "HpBar" (placed above the head:
  1.55 / 2.35 / 2.55 m), gets a `max_hp` var, and refreshes the bar in
  its `damage()`. Warden fraction is armor-aware (the bar shows the hp
  after armor is applied).
- `ui/hud.gd`: rover health bar top-left (green, 220 px, label moved
  below it) and crystal health bar bottom-center (blue, 260 px, label
  moved above it); both left-anchored ColorRect fills driven by the
  existing `set_rover()` / `set_crystal()` refresh path, so they stay
  in sync with nukes, rams, and crystal damage with no new wiring.

New `tests/v1/hpbar_probe.tscn` (13 checks): grunts spawn with hidden
bars; a damaged grunt's bar shows at the exact remaining fraction;
warden bar is armor-aware; golem bar (direct spawn) works; rover bar
full at boot and shrunk to 70% after 30 dmg; crystal bar full then
70% after 15 dmg; a killed grunt and its bar are freed with the
corpses' death timer.

Full regression green: m1-m8 142 + input 16 + terrain 3 + progression
10 + sell 17 + hpbar 13 + 2D smoke 71.

## M13 — live wave accounting + real combat routing (v1)

Two live-path defects from the v1 review:

- **M13a — waves could not clear correctly.** `alive` budgeted only the
  grunts, so a Warden/Golem/Vrax standing on the field never blocked the
  relay. `WaveDirector._start_assault` now budgets every spawn
  (`alive = size + wcnt + gcnt`) — a wave cannot clear while a boss is
  alive. Vrax became **mech-only**: non-mech damage (including piercing
  chip) is fully ignored; only `mech=true` projectiles land. The old
  chip divisor is deleted — the Hybrid Chassis is the one thing that
  matters against him.
- **M13b — enemy melee hit nothing.** Grunts/wardens targeted the Rover
  *body* (a collider child) which has no `damage()`; hp lives on
  `PlayerRig`. Enemy attacks now hop to the hp owner (the rig) — warden
  melee and charge, golem ram and grunt bite all land on
  `PlayerRig.damage()`, which applies mech armor in mech mode and feeds
  the HUD `hp_changed` bar.

New `tests/v1/wave_fix_probe.tscn` (14 checks): a live wave 3 (real
prep → early start → staggered spawns) reaches the full roster of 5
grunts + Warden, and `alive` stays 6 until the Warden dies; the finale
wave 20 spawns 14 grunts + Vrax + Golem with `alive` = 16 and only
clears after **all three** kinds are dead. `tests/v1/rover_damage_probe.tscn`
(7 checks) exercises the normal combat path — a live wave-1 grunt and a
live wave-3 Warden are teleported onto the player body and their real
melee/charge damage the rig (100→80, 88→76) with the HUD bar tracking;
a directly-spawned Golem rams for the full 40. m7's Vrax assertions
were updated to the mech-only contract (non-mech pierce ignored, mech
heavy lands).

Full regression green: m1-m8 142 + input 16 + terrain 3 + progression
10 + sell 17 + hpbar 13 + wave_fix 14 + rover_damage 7.

## M15 — save integrity: full attempt state (v1)

The checkpoint previously stored only attempt id / wave / scrap, so a
resume rebuilt an empty arena and a dead player.

- The `ProfileStore` attempt block now round-trips **cargo, crystal
  integrity, rover hp, mech mode, nuke charges, endless flag, depleted
  deposits** and the **building snapshot** (type + cell + current hp).
- `BuildService.snapshot()/restore()` rebuild walls/turrets on resume
  (turret re-wired to the combat service); `Arena` exposes its deposit
  group as a member so depletion flags can be restored and re-rendered.
- Dead-end edge: a run that saved *after* the crystal or rover died
  respawns both whole (integrity → max, hp → max) instead of booting
  into an instant loss.

New `tests/v1/save_probe.tscn` (18 checks): boot a run, place a wall +
turret (damage-chipped), deplete a deposit, transform to mech at 77 hp,
bank 3 nukes, drop the crystal to 31, jump to endless wave 7 and save;
a fresh boot restores every field exactly (building cells, hp, occupied
cells, deposit state). Second pass: save with a destroyed crystal +
dead rover and verify the respawn-whole rule on the next boot.

Full regression green: + save 18 (211 checks across 16 probes).

## M16 — progression is live, the model is honest (v1)

The review's core objection: the game enforced none of the GDD
progression, and the simulator was presented as an exhaustive search
that it was not.

- **The barrier schedule is live.** `ProgressionModel.required_threshold()`
  is now the shared source of truth: `WaveDirector._start_assault`
  (both the timer and early-start paths) seals a wave until lifetime
  knowledge (`Knowledge.earned_total` — receipts persist across
  attempts) reaches the threshold. A sealed wave ends the attempt with
  a new flow result `sealed` ("WAVE n SEALED — THE CRYSTAL HOLDS AT x
  LIFETIME ENGRAM"); the next attempt starts with more carried
  knowledge. This is exactly the five-attempt structure the model
  proved (blocked at 6/10/14/18 with 5/14/26/42 carried).
- **Nuked waves award no engram.** The nuke bypasses the wave instead
  of clearing it: `_fire_nuke` flags the wave, and
  `entry._on_wave_cleared` skips the receipt and the banner
  ("WAVE n BYPASSED BY NUKE — NO ENGRAM"). The GDD reading is now the
  shipped rule.
- **The model reads real data.** Campaign length = live
  `WaveDirector.WAVE_PLAN.size()` (the duplicated constant is gone);
  the mech gate = the real catalog node (`mech`, cost 3, req `r2`) +
  the real `MechData.BUILD_COST` (8) — the parameterized `MECH`
  constant is gone.
- **Honest search.** Code and doc no longer claim a "mixed builds"
  dimension: the search varies exactly nukes × respec × holdout (18
  configurations, fixed deterministic order), and the doc explains why
  line choice is not a variable — barriers gate on lifetime EARNED, so
  which line is bought cannot change a clear.
- `docs/progression-model.md` updated: schedule is shipped and
  enforced; limitations 1/5/7 closed; search space restated.

The progression probe now boots the scene (19 checks): the offline
suite (reference reproduction, 18-config search, infeasibility, nuke
invariance, respec, mech gate, catalog depth, real-data wiring) plus
live-path checks — wave 1 nuked → no engram; wave 2 cleared normally →
+1 engram; wave 6 sealed below threshold (BLOCKED, no spawn, flow
result `sealed`); wave 6 opens once the threshold is carried.
`wave_fix_probe` banks 45 knowledge before its live finale (the wave-18
barrier now gates it, as it gates the real game).

Full regression green: 219 checks across 16 probes.

**Open design item (review finding 5):** deferred at M16, **resolved in
M18** — the user chose *cargo cost on deployment*: each attempt boots at
base stats, and researched ROVER-line blueprints deploy in-run for cargo
equal to their engram cost.

## M17 — the 3D game is the game (v1)

`run/main_scene` now points at `res://scenes/v1/entry.tscn`. Launching
the project opens the 3D Chronolith; the 2D prototype remains intact at
`res://core/main.tscn` (run it explicitly, `tests/smoke_test.tscn` still
covers it).

Full regression green: v1 219 checks across 16 probes + 2D smoke 71.

## M18 — manufactured power: research persists, stats deploy (finding 5)

GDD §6 — "Power still has to be manufactured and deployed during the new
attempt. Do not award permanent unexplained damage or health for each
death." The user chose the resolution: **cargo cost on deployment**.

- Each attempt boots the rover at BASE stats (100 hp, 9.0 speed, 1.0 s
  ram recharge, 2.6 m harvest radius). Knowledge (the researched
  blueprints) persists across attempts — that is the engram loop.
- **V deploys** the next researched ROVER node in chain order (r1 Heavy
  Chassis +50 hp → r2 Ion Coils +1.5 speed → r3 Ram Capacitor 1.0 s →
  r4 Mag Coil +1.5 m), costing its engram value in cargo, once per
  attempt. Deployment raises the ceiling but does not heal.
- The **crystal shield (f3) stays boot-applied** — GDD §5: the world
  reset physically restores the prison, so the shield is reset state,
  not manufactured power. The TEMPORAL line is an ability, untouched.
- **Mech transform resets the hp pool to 250** (the mech is its own
  hull); deploying into/onto the mech is refused, and a saved mech run
  restores at the mech pool. Deployment records persist in the save
  (no re-deploy of a consumed node; cargo not re-charged).
- `apply_research` now treats each node's effect dict as PARTIAL — a
  node without a key no longer clobbers an earlier deployment's value
  (the m6 probe caught a real clobber: r4 reset r3's ram recharge).
- **Model:** the deployment is now a SCRAP sink in `simulate_attempt`
  (chain order, deploy earliest, reserving `mech_build_cost()` while
  the mech is researched-but-unbuilt — the only scrap race that gates
  the win). The five-attempt proof re-verified: earliest win is still
  attempt 5; the sink changes survivability, not the barrier schedule.
- `progression-traces.json` re-exported (catalog now carries the deploy
  policy); `docs/progression-model.md` limitation 3 updated.

Full regression green: v1 238 checks across 16 probes + 2D smoke 71.

## Playtest fix 3 — grounded horizon (floating-ground report)

The 500 m plain under the arena was a FLAT COLOUR: beyond the arena edge
the ground faded into the fog colour, which matched the sky's mirrored
below-horizon gradient — the horizon read as an inverted sky and the
arena as a floating slab (the user's "inverted ground / everything is
floating").

- The plain now carries a 256 px textured tile (256 px = 32 m, 4 m grid,
  dimmer than the arena, repeated across the 500 m field) so the ground
  stays legible ground to the fog line.
- The plain sits at y = -1.8 (was -2.5): near the terrain's low edge, so
  the arena reads as raised ground over a closed plain, not a see-through
  gap.
- `terrain_probe` now asserts the plain's texture and position (5 checks).

Full regression green: v1 240 checks across 16 probes + 2D smoke 71.

### 3b — real tiling + mipmaps (renderer-verified)

The tiling used Godot 3.x property names (`u_tile`/`v_tile`/
`texture_repeat_enabled`), which Godot 4 warns about and silently
ignores — the tile stretched over the whole 500 m field and still read
as a flat gradient (the user's second "inverted texture" report). Fixed
with `uv1_scale` (a Vector3 in 4.7) for the plain's 32 m repeat, and
`generate_mipmaps()` + `LINEAR_WITH_MIPMAPS` on both ground textures
(without a mipmap chain the 1 m arena grid minifies and aliases out at
range).

Renderer-verified on the playtest GPU via `tests/v1/ground_debug.tscn`
(arena only, no profile, 3 camera shots): the player view shows the 1 m
grid crisp in the foreground, the edge view shows the plain's 4 m tile
repeating to the fog line, and the horizon now reads as ground fading
into haze. (A 60 m straight-down shot is ~96% fog by design, not a
defect.) Full regression re-run green: 240 v1 + 71 2D.

### 4 — one continuous ground (the plain was the wrong layer)

The user's third report: the texture he sees is on the BOTTOM layer
(the 500 m plain at y = -1.8, visible under the main ground at certain
camera angles) while the rover sits on the main surface above it —
"all you have done is ground the bottom layer, which will never be
used." Diagnosis: fixes 3/3b textured the plain, but the plain is a
dead second floor. Also verified along the way that the collision
geometry was never the problem — Godot 4.7 removed
`map_origin`/`map_size` from `HeightMapShape3D`; the map is centred on
the body origin, one world unit per sample, absolute heights. The arena
body sits at the origin, so collision already matched the visible mesh
exactly (`tests/v1/heightmap_probe.gd` drops bodies at four points and
confirms the convention empirically).

Fix: there is now exactly ONE ground surface.

- The terrain mesh is the whole visible field: 120 m (121 x 121
  vertices), the arena relief (centre pad, edge hills, west ridge)
  unchanged for r < 20, tapering to 0 between r = 20 and r = 30
  (`height_at` gets a `taper = 1 - smoothstep(20, 30, d)`; every arena
  placement is bit-identical).
- Same 640 px / 16 px-per-metre grid texture, UVs now span 0..3 so the
  1 m grid tiles continuously from the arena centre to the field edge —
  no scale change, no visible seam.
- The plain (and its `_plain_texture`/`_plain_material`) is deleted.
  The horizon is the textured field fading into the existing fog
  (96% at 60 m — the field edge at 60 m is invisible by design).
- Collision heightmap grows with the field (121 x 121 samples) so
  nothing can walk off the world.
- `terrain_probe` re-pointed: wide field (>= 100 m), no PlaneMesh
  second floor, heightmap >= 121^2 (5 checks).

Full regression green: v1 240 checks across 16 probes + 2D smoke 71.

### 5 — the grid must hold at glancing angles (the "inverted face" report)

The user's fourth report: the face of the ground that carries the grid is
not the face the rover drives on — the texture appears on the far side of
the relief coming down ("the visible face of the ground is inverted").
Diagnosis (and the one mechanism that makes a texture appear and
disappear with camera angle — the user's "visible at certain angles"
note from day one): the player camera is nearly horizontal, so the flat
ground in front is sampled at extreme minification. With a 1 px line
(6 cm of ground) and no anisotropic filtering, the grid averages out on
the face you are looking at while it survives on steeper ground further
away — the texture appears to live on the other face of the ground.
(Also verified: the mesh winding is NOT inverted — the triangle
winding's right-hand normal is +Y, so the top face is the front face;
the perception is purely a sampling artefact.)

- Grid lines widened 1 px -> 6 px (6 cm -> 37.5 cm of ground) so the
  grid survives to the deepest mipmap.
- Terrain material: `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC`
  (the 4.7 enum name — `TEXTURE_FILTER_ANISOTROPIC` does not exist)
  + `rendering/textures/default_filters/anisotropic_filtering_level=16`
  in project.godot (the 4.7 key — the old
  `anisotropic_filtering/enable|max` pair is gone).
- `terrain_probe` locks it in: line width >= 4 px, material filter
  anisotropic, project level >= 8.
- `ground_debug` gains shot 4 (`gd_glance.png`): near-horizontal at
  rover height across flat ground toward the relief — the grid must be
  visible on the flat ground in front, not only on the steeper ground
  behind it.
