# CHRONOLITH — 3D Conversion Roadmap

**Status:** planning. The decision is recorded 2026-08-27: the game is 3D, in Godot 4.x
(see `NOTE-3D.md`). Everything currently in the repo is a **2D (Node2D) vertical-slice
prototype** that proves the systems; this doc is the plan for rebuilding presentation in 3D
without throwing the proven gameplay architecture away.

> Read this before writing any 3D visual-layer code. The golden rule:
> **convert presentation, never contracts.** `core/contracts.gd`, the EventBus signals,
> and every `data/*.json` file survive unchanged unless a stage below explicitly says why.

---

## 1. What survives the conversion (do not touch)

| Layer | Files | Why it survives |
|---|---|---|
| Contracts | `core/contracts.gd` | One-Dictionary payload law; positions become `{x,y,z}` (see §3) |
| EventBus | `core/event_bus.gd` | All ~45 signals are presentation-agnostic |
| Game state / main | `core/game_state.gd`, `core/main.gd` | Phase flow, run/sol logic, reset timing |
| Economy | `modules/economy/*` | Pure ledger, zero visuals |
| Meta | `modules/meta/*` | Save/unlocks/hub; hub is UI (Control), mostly unchanged |
| UI | `modules/ui/*` | HUD is a `Control` tree — works identically over 3D |
| Audio | `modules/audio/*` | 2D positional audio can be upgraded later |
| All `data/*.json` | every module | Tuning is presentation-agnostic |
| Tests | `tests/smoke_test.gd` | Drives the Bus like a player; must keep passing through every stage |

## 2. What gets replaced (the `internal/` visual layer)

| Module | 2D today | 3D becomes |
|---|---|---|
| environment | `mars_map.gd` (draw calls + procedural Image) | `Node3D` world: terrain mesh (heightmap), crater decals, tunnel-hole props, crashed-vessel model, skybox/fog |
| chronolith | `crystal.gd` (draw calls) | Crystal `Node3D` (emissive material + light), dilation bubble as translucent sphere / shader, plinth model |
| rover | `rover_body.gd` (draw calls) | Rover model (body, arms, turret), laser as `CSGShape3D`/trail, wreck state |
| build | `building.gd`, `ghost.gd` (draw calls) | Prop meshes per building type, `SpatialMenu` ghost with translucent material, placement on terrain |
| waves | `enemy.gd` (draw calls) | Trooper/stalker/burrower models, burrower emergence = sink-into-terrain + dust VFX |
| ui (only) | `input_forwarder.gd` mouse→2D coords | Mouse→**raycast onto the ground plane / terrain** for placement and aiming |

## 3. The migration seam: positions gain a `z`

**Convention (adopt from Stage 0):** every position payload in `core/contracts.gd`
becomes `{"x": float, "y": float, "z": float}`.

- **`z` is the vertical axis, `z = 0` is the ground plane.**
- Every consumer must read `z` with a default of `0.0`
  (`Contracts.vec2_of` stays for legacy 2D consumers; add `Contracts.vec3_of` with
  `z` defaulting to 0). This means a half-converted game still runs: a 3D emitter and
  a 2D consumer interoperate at ground level.
- `CONTRACT_VERSION` bumps **1 → 2 exactly once**, at the end of Stage 0, after every
  module is written against `vec3_of`. No per-stage version churn.
- Map data (`maps.json`): `map_w/map_h` become `map_w/map_d` (width/depth in world
  units) plus optional `heightmap` reference; `tunnel_holes` and `craters` gain `z`
  (default 0).

**World units:** 1 unit = 1 meter. The 2D map (1920×1280 px) maps to roughly
**48 m × 32 m** of playable terrain (÷40 px/m) — keep the numbers in `maps.json`
until Stage 0 says otherwise.

## 4. Camera and renderer

- **Camera:** top-down 3D with a slight tilt (~55–65° from vertical), dolly zoom on
  scroll, mouse-look orbit disabled (the 2D slice is a fixed-camera game — keep it).
  One `Camera3D` owned by the **rover module** (the 2D slice already puts the
  `Camera2D` on the rover body; the 2D camera is the only per-module camera, keep that
  ownership rule).
- **Renderer:** the prototype uses `gl_compatibility` (fine for 2D). For 3D choose
  **`mobile`** (or `gl_compatibility` if we commit to low-end/console targets —
  decide in Stage 0; `mobile` gets us SDF-ish lighting without forward+ cost).
  Real forward+ only if we want PBR + bloom on PC and accept the perf cost.
- `project.godot`: `window/stretch/mode` → `"viewport"` (canvas_items stretch is a
  2D concept), keep 1600×900 base.

## 5. Stages (each stage ends with a green smoke test + a playable scene)

**Stage 0 — Proof of concept (1–2 days, highest value, do first)**
New `res://scenes/poc/poc.tscn` (separate from the 2D slice; do not delete the slice):
lit terrain plane + crystal + one trooper + rover capsule, orbit-correct top-down
camera, `Contracts.vec3_of` added, `CONTRACT_VERSION` → 2 once all POC code is on it.
Exit: runs headless, runs in editor, the 2D smoke test still passes unmodified
(it never touches the POC scene).
*Answers the open GDD questions (exact camera angle, renderer) with something
playable instead of a moodboard.*

**Stage 1 — Environment (M8)**
Terrain heightmap mesh, craters as geometry + decals, tunnel holes as props with
emitter triggers, crashed vessel as a real model, Mars skybox + dust fog, storm
VFX (storm_tables.json already drives intensity — wire to fog/visibility).
Exit: a 3D walk-through of the battlefield; `maps.json` converted.

**Stage 2 — Chronolith (M4)**
Crystal model (emissive core + facet material), Dilation Bubble as a shader sphere
(the slow effect is logic, already in `enemy.gd.effective_speed()` — unchanged),
integrity cracks as material state, damage flash via light pulse.
Exit: chronolith death run (smoke test step 8) plays correctly in 3D.

**Stage 3 — Rover + Build (M1, M2)**
Rover model + turret aim, laser as 3D beam/tracer (rover_fired payload already
carries from/to — now 3D), building props (turret/solar/scanner/wall) with
translucent placement ghost, mouse raycast placement replacing 2D mouse coords,
repair/upgrade visuals.
Exit: full build phase playable in 3D; placement validity rules unchanged
(`grid_rules.json` cell_snap becomes a world-space grid).

**Stage 4 — Waves (M3)**
Trooper/stalker/burrower models + animation states (walk/attack/die/burrow),
burrower emergence (sink + dust), stalker cloak as transparency shader,
wall-blocking uses the same `layout` contract (radius → 3D collider),
rewind restoration unchanged (it operates on position+hp snapshots).
Exit: full 3-sol run completable; wave smoke tests pass.

**Stage 5 — HUD, hub, memory fragments (M7, M6)**
HUD is already a Control tree — reposition over the 3D view, swap the 2D map
thumbnail for a 3D minimap (render the battle to a texture via a second viewport —
the one genuinely new subsystem). Hub/memory screens unchanged except styling.
Exit: a complete play session from HUB through victory in 3D.

**Stage 6 — Audio, polish, perf**
2D positional audio → `AudioStreamPlayer3D`, storm/rewind audio, first-person
camera sway (if any), draw-call and shadow budget pass (target: 60 fps on the
weakest target we commit to), mobile/low-end pass if the renderer choice demands it.
Exit: the 3D build is the game; the 2D slice is archived under `legacy/2d-slice/`
(or kept as the automated-test rig — it's actually a great headless harness).

## 6. Risks and how the plan contains them

| Risk | Contained by |
|---|---|
| Scope creep: 3D turns into a rewrite | Stages 1–6 touch only `internal/` + map data; contracts/economy/meta/UI logic is explicitly off-limits |
| Terrain collision breaks movement/aiming rules | Stage 1 ships with the raycast placement helper; rover/enemy ground-lock is one utility function in the environment module |
| Renderer choice rework | Decided in Stage 0 with a real scene; `mobile` is the safe default |
| Minimap complexity | Isolated to Stage 5 as a second-viewport texture; HUD layout never blocks a stage |
| Test regression mid-conversion | The 2D smoke test keeps running in CI until Stage 5; every stage adds its own 3D checks before the next starts |
| Asset dependency (no artist yet) | Every stage uses primitive/CSG geometry first (the 2D slice did the same with draw calls); swap in models when they exist |

## 7. Definition of done (the whole conversion)

1. `godot --headless` smoke suite passes on the 3D build (the Bus-driven test never
   knows or cares which renderer drew the frame).
2. A complete run — HUB → 3 sols → victory or defeat — is playable in the exported
   build on the target hardware.
3. `chronolith-gdd.md` §1 and §13 read 3D with no "TBD" left on perspective.
4. The 2D slice is either archived or documented as the headless test rig.
