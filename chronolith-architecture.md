# CHRONOLITH — Modular Architecture Framework
*How the game is split so every module can be built, tested, and broken independently.*

Engine: **Godot 4.x (4.7 in this repo)**. **Presentation is 3D** (decided 2026-08-27, see `NOTE-3D.md` and `docs/3D-CONVERSION.md`); the code that currently ships is a 2D (Node2D) vertical-slice prototype of the same module boundaries. The EventBus/contracts architecture below is presentation-agnostic and survives the 3D conversion — the `_controller.gd` doors and `data/` files stay, the `internal/` visual layer is what gets rebuilt in 3D.

---

## 1. The Golden Rules (every agent obeys these, no exceptions)

1. **No module ever references another module directly.** No `get_node("../Rover")`, no cross-module preloads, no shared mutable state. All communication goes through the **EventBus** (a Core autoload).
2. **Contracts are law.** Every signal name, payload shape, and enum lives in `core/contracts.gd`. Agents *consume* contracts; only the Core owner (you) *changes* them. A contract change bumps `CONTRACT_VERSION` and every module logs a warning if versions mismatch at boot.
3. **Data, not code, for tuning.** All numbers (damage, costs, wave sizes, cooldowns) live in Resource files (`.tres`) or JSON under the module's `data/` folder. Agents never hardcode gameplay values.
4. **Every module ships with a mock harness.** Each module folder contains a `test_harness.tscn` that runs the module in isolation using Core's mock library — fake events in, asserted events out. If the harness doesn't run standalone, the task isn't done.
5. **Own your folder, touch nothing else.** Each agent has write access to exactly one folder tree (plus its own harness). Anything outside it is read-only reference.
6. **Fail loud, fail local.** Modules validate incoming event payloads and log-and-drop malformed ones rather than crashing. A broken module should degrade (its feature stops working) — never take the game down.

---

## 2. Project Layout

```
res://
├── core/                      # M0 — YOURS. The spine.
│   ├── event_bus.gd           # autoload singleton
│   ├── contracts.gd           # all signals, payload schemas, enums, CONTRACT_VERSION
│   ├── game_state.gd          # run/phase state machine (CALM, ASSAULT, RESET, HUB)
│   ├── mocks/                 # mock event emitters + fake data for harnesses
│   └── main.tscn              # composition root: instances all modules
│
├── modules/
│   ├── rover/                 # M1
│   ├── build/                 # M2
│   ├── waves/                 # M3
│   ├── chronolith/            # M4
│   ├── economy/               # M5
│   ├── meta/                  # M6
│   ├── ui/                    # M7
│   ├── environment/           # M8
│   └── audio/                 # M9
│
└── shared_assets/             # art, sfx, fonts — read-only for all agents
```

Every module folder follows the same internal shape:

```
modules/<name>/
├── <name>.tscn            # the module's root scene (instanced by main.tscn)
├── <name>_controller.gd   # entry point; ONLY file that talks to EventBus
├── data/                  # .tres / .json tuning files
├── internal/              # everything else — private, never referenced externally
└── test_harness.tscn      # standalone run with Core mocks
```

The `_controller.gd` is the module's single door. Internally the agent can structure however they like; externally, only events cross the boundary.

---

## 3. The EventBus & Contract Pattern

```gdscript
# core/event_bus.gd (autoload "Bus")
extends Node
# All signals declared here, defined in contracts.gd documentation.
signal rover_harvested(payload: Dictionary)
signal build_placed(payload: Dictionary)
signal wave_started(payload: Dictionary)
signal enemy_killed(payload: Dictionary)
signal chronolith_damaged(payload: Dictionary)
signal resource_changed(payload: Dictionary)
signal phase_changed(payload: Dictionary)
signal run_ended(payload: Dictionary)
# ...full list in contracts.gd
```

```gdscript
# core/contracts.gd — excerpt
const CONTRACT_VERSION := 3

## enemy_killed payload:
## { "enemy_id": String, "enemy_type": Contracts.EnemyType,
##   "position": Vector2, "salvage": { "scrap": int, "dna": int } }

enum EnemyType { TROOPER, STALKER, BURROWER, DROPPER, DAMPENER, BROODMOTHER }
enum Phase { HUB, CALM, ASSAULT, RESET }
enum ResourceKind { REGOLITH, SCRAP, RARE, POWER, SHARDS, DNA }
```

**Payload discipline:** dictionaries with documented keys (or typed `RefCounted` classes if you prefer — pick one and enforce it). Every consumer validates keys before use.

**Why this works for your goal:** if the Waves agent ships a bug, enemies misbehave — but Rover, Build, Chronolith and UI keep functioning because they never held a reference to anything inside `modules/waves/`. You open one folder, fix one thing.

---

## 4. Module Boundary Map

| # | Module | Owns (single responsibility) | Emits (examples) | Listens (examples) |
|---|---|---|---|---|
| M0 | **Core** | EventBus, contracts, phase state machine, mocks, composition root | `phase_changed`, `run_ended` | everything (routing only) |
| M1 | **Rover** | Movement, harvesting, weapons, upgrade stages, consumable deploys | `rover_harvested`, `rover_fired`, `rover_damaged`, `rover_upgraded` | `phase_changed`, `chronolith_active_triggered`, `input_*` |
| M2 | **Build** | Placement grid, building instances, power network, repair, traps | `build_placed`, `build_destroyed`, `power_state_changed` | `resource_changed`, `enemy_killed` (turret targeting is internal), `phase_changed` |
| M3 | **Waves** | Wave director, enemy spawning, all enemy AI, bosses | `wave_started`, `wave_cleared`, `enemy_killed`, `enemy_reached_target` | `phase_changed`, `chronolith_field_state` (for slow factors), `environment_state` |
| M4 | **Chronolith** | Integrity, dilation bubble/gradient, actives (Rewind/Overclock/Stasis) | `chronolith_damaged`, `chronolith_field_state`, `chronolith_active_triggered` | `enemy_reached_target`, `player_activated_*` |
| M5 | **Economy** | Resource ledger (single source of truth), costs, salvage trees | `resource_changed`, `purchase_result` | `rover_harvested`, `enemy_killed`, `build_placed` (spend), `purchase_request` |
| M6 | **Meta** | Save/load, permanent unlocks, hub scene, memory fragments, echo recording | `unlocks_loaded`, `memory_event`, `echo_playback` | `run_ended`, `enemy_killed` (shard accrual), `purchase_request` (hub) |
| M7 | **UI** | HUD, build menu, wave telemetry, hub UI, memory choice dialogs | `input_*`, `purchase_request`, `player_activated_*` | almost everything (display only — UI holds **zero** game state) |
| M8 | **Environment** | Mars map gen, dust storms, day/night, terrain hazards | `environment_state`, `sol_changed` | `phase_changed` |
| M9 | **Audio** | All SFX/music, dilation pitch-shift zones | — | almost everything (pure consumer) |

Two deliberately strict calls:
- **Economy owns the ledger.** Nobody else mutates resource counts — modules send `purchase_request` and get `purchase_result`. Kills an entire class of desync bugs.
- **UI is stateless.** It renders events and forwards input. If UI crashes, gameplay continues headless in the harness.

---

## 5. Testing & Integration Protocol

1. **Standalone first.** Agent builds against mocks until its harness passes its checklist (defined per-task in the assignments doc).
2. **Contract check.** Module logs its expected `CONTRACT_VERSION` at `_ready()`; mismatch = loud warning, not a crash.
3. **Integration is yours alone.** Only you touch `core/main.tscn`. Adding a finished module = instance its `.tscn`, run, watch the bus log.
4. **Bus logger.** Core includes a debug console printing every event + payload in order. When something breaks in integration, the log tells you *which module emitted garbage* — you fix one folder.
5. **One-module rollback.** Because modules are folder-isolated, reverting a module is `git checkout <commit> -- modules/<name>/`. Keep each agent's work on its own branch, merge one at a time.

---

## 6. Build Order (dependency-aware)

```
Phase A (blocking):    M0 Core  →  must exist before anything else
Phase B (parallel):    M1 Rover · M2 Build · M4 Chronolith · M5 Economy
Phase C (parallel):    M3 Waves · M8 Environment      (need field/phase events to exist)
Phase D (parallel):    M7 UI · M9 Audio               (pure consumers, mock everything)
Phase E (solo, last):  M6 Meta                        (needs run_ended + real currencies flowing)
```

Phase B–D modules genuinely don't need each other — that's the point. Integrate in the same order.
