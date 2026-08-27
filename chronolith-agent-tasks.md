# CHRONOLITH — Agent Task Assignments
*One agent per module. Paste an agent its brief verbatim, plus `core/contracts.gd` and the Architecture doc §1 (Golden Rules).*

**Universal instructions for every agent (prepend to each brief):**
> You are building one isolated module of a Godot 4.x game. You may only create/edit files inside your assigned folder. You communicate with the rest of the game exclusively via the `Bus` autoload signals defined in `core/contracts.gd` — never reference other modules' nodes or scripts. All gameplay numbers go in `data/` resource files, never hardcoded. Your module must run standalone via your `test_harness.tscn` using the mocks in `core/mocks/`. Validate every incoming payload; log-and-drop malformed events, never crash. Definition of done = harness checklist passes + contract version logged at boot + zero references outside your folder.

---

## AGENT 0 — CORE *(reserved for Marc — build this yourself first)*
**Folder:** `core/`
**Task:** EventBus autoload, `contracts.gd` (full signal list, payload docs, enums, `CONTRACT_VERSION`), phase state machine (HUB → CALM → ASSAULT → ... → RESET), mock event library, bus debug logger, empty `main.tscn` composition root.
**Done when:** a dummy scene can emit and receive every contract signal; logger prints ordered event stream.
**Why you:** whoever owns contracts owns the project. This is the one module everyone depends on — don't delegate it.

---

## AGENT 1 — ROVER
**Folder:** `modules/rover/`
**Scope:** player-controlled rover. Movement (wheeled physics, stage-dependent speed), harvesting interaction, weapon slots + firing, damage/repair state, three visual upgrade stages (NASA → Hybrid → Ascendant) driven by `rover_upgraded` data, consumable deploys (drone, mine, decoy — spawn + lifetime only; drones' targeting can be dumb v1).
**Emits:** `rover_harvested`, `rover_fired`, `rover_damaged`, `rover_destroyed`, `rover_upgraded_ack`
**Listens:** `phase_changed`, `input_move`, `input_fire`, `input_interact`, `chronolith_active_triggered` (Overclock = speed/fire-rate multiplier from payload), `purchase_result` (upgrade confirmations)
**Data files:** `rover_stages.tres` (speed, hp, slots per stage), `weapons.tres`, `consumables.tres`
**Harness checklist:** drives via mocked input; harvest node interaction emits correct payload; takes mock damage and emits `rover_destroyed` at 0 HP; Overclock event visibly doubles fire rate; stage swap changes sprite/scene and stats.
**Forbidden:** touching resource counts (request via Economy), spawning enemies, any UI.

---

## AGENT 2 — BUILD SYSTEM
**Folder:** `modules/build/`
**Scope:** placement grid + validity rules, building lifecycle (place/repair/destroy), turret behaviour (target acquisition against enemy positions carried in wave events — v1 may use a registered-position dictionary maintained from `enemy_spawned`/`enemy_moved`/`enemy_killed` events), power network (generators, relays, powered/unpowered states), walls, traps.
**Emits:** `build_placed`, `build_destroyed`, `turret_fired`, `power_state_changed`, `purchase_request` (on placement attempt)
**Listens:** `purchase_result`, `enemy_spawned/enemy_moved/enemy_killed`, `phase_changed`, `environment_state` (storms cut solar), `chronolith_field_state` (fire-rate zones if gradient adopted)
**Data files:** `buildings.tres` (cost, hp, dps, power draw per building), `grid_rules.tres`
**Harness checklist:** placement rejected without mock `purchase_result: ok`; turret tracks and "kills" mocked enemy positions; storm event powers down solar-dependent turrets; destroying a relay unpowers downstream buildings.
**Forbidden:** mutating resources directly, defining enemy AI, Chronolith logic.

---

## AGENT 3 — WAVE DIRECTOR & ENEMY AI
**Folder:** `modules/waves/`
**Scope:** wave scheduling per sol (composition, counts, spawn edges/tunnels/orbital drops from data), all six enemy behaviours (Trooper rush, Stalker cloak, Burrower tunnel, Dropper pod, Dampener anti-field aura, Broodmother spawner), boss framework (one boss v1), enemy movement respecting slow factors from `chronolith_field_state`, salvage payloads on death.
**Emits:** `wave_started`, `wave_cleared`, `enemy_spawned`, `enemy_moved` (throttled — batch per physics tick), `enemy_killed`, `enemy_reached_target`, `dampener_field_state`
**Listens:** `phase_changed`, `chronolith_field_state`, `environment_state` (storms slow air drops), `turret_fired`/`rover_fired` (v1 damage resolution: fire events carry target_id + damage; you resolve HP)
**Data files:** `enemy_types.tres`, `wave_tables.tres` (per-sol composition), `boss_01.tres`
**Harness checklist:** full 3-sol wave schedule runs against mock phase events; each enemy type demonstrates its signature behaviour on a test map; slow-field payload visibly slows units inside mock radius; Stalker only targetable after mock `scanner_ping`.
**Forbidden:** touching buildings/rover nodes (damage goes out as `enemy_attack` events with target ids), resource mutation.

---

## AGENT 4 — CHRONOLITH
**Folder:** `modules/chronolith/`
**Scope:** integrity pool (the lose condition), dilation bubble (radius + slow factor → broadcast as `chronolith_field_state`), map-wide dilation gradient (behind a data flag — build it toggleable), three actives with shared cooldown pool: Rewind (broadcast `rewind_window` event — v1 implementation: each module handles its own 5-second state buffer; your job is the trigger, timing, and cooldown), Overclock (drains integrity, emits multiplier), Stasis Snap (freeze payload with radius + duration).
**Emits:** `chronolith_damaged`, `chronolith_destroyed`, `chronolith_field_state`, `chronolith_active_triggered`, `rewind_window`
**Listens:** `enemy_attack` (targeting chronolith id), `player_activated_rewind/overclock/stasis`, `dampener_field_state` (suppresses bubble locally), `purchase_result` (bubble upgrades)
**Data files:** `chronolith.tres` (integrity, bubble radius/slow curves, active costs/cooldowns, gradient on/off + curve)
**Harness checklist:** mock attacks reduce integrity and emit `chronolith_destroyed` at 0; field state broadcasts on change and on interval; Overclock drains integrity over mock duration; Dampener payload zeroes slow factor within its radius only.
**Forbidden:** implementing other modules' rewind buffers, enemy logic, UI.

---

## AGENT 5 — ECONOMY
**Folder:** `modules/economy/`
**Scope:** THE resource ledger — single source of truth for Regolith, Scrap, Rare, Power(budget), Shards, DNA. Processes `purchase_request` → validates → emits `purchase_result` (ok/insufficient + costs). Accrues from `rover_harvested` and `enemy_killed` salvage payloads. Salvage tech-tree state (Grey vs Reptilian branch ownership per run, synergy thresholds — data-driven, logic minimal v1).
**Emits:** `resource_changed` (full ledger snapshot each change), `purchase_result`
**Listens:** `rover_harvested`, `enemy_killed`, `purchase_request`, `run_ended` (reset in-run currencies, report shards/DNA to Meta via payload), `phase_changed`
**Data files:** `costs.tres`, `salvage_trees.tres`, `starting_resources.tres`
**Harness checklist:** ledger never goes negative; concurrent purchase requests resolve deterministically (queue them); harvest/kill events accrue correct amounts; `run_ended` emits final meta-currency payload and resets.
**Forbidden:** knowing what a "turret" or "rover" is beyond cost ids. Pure bookkeeping.

---

## AGENT 6 — META-PROGRESSION *(build last)*
**Folder:** `modules/meta/`
**Scope:** save/load (JSON in `user://`), permanent unlock registry (blueprints, stats, actives), hub scene (crashed vessel interior — placeholder art), memory fragment events (repair = permanent bonus / purge = in-run resources, content from data), echo recording (subscribe to `rover_*` events during runs, buffer final 60s, emit `echo_playback` at next run start — behind a data flag).
**Emits:** `unlocks_loaded`, `memory_event`, `echo_playback`, `purchase_request` (hub purchases)
**Listens:** `run_ended`, `resource_changed`, `purchase_result`, `phase_changed`
**Data files:** `unlocks.tres`, `memory_fragments.json` (text + effects), `save_schema.json`
**Harness checklist:** save→quit→load restores unlock state exactly; corrupt save file is detected and quarantined, fresh save created (never crash); memory choice applies correct effect; echo buffer replays a mocked 60s event stream.
**Forbidden:** in-run gameplay logic of any kind.

---

## AGENT 7 — UI/HUD
**Folder:** `modules/ui/`
**Scope:** HUD (resources, integrity, wave telemetry, cooldowns), build menu (renders from `buildings.tres` read-only + `resource_changed`), input capture → `input_*` and `player_activated_*` and `purchase_request` events, hub UI, memory choice dialog, bus-driven damage indicators. **Holds zero game state — everything rendered is the latest event payload.**
**Emits:** `input_move/fire/interact`, `player_activated_*`, `purchase_request`, `build_intent` (grid coords for Build to validate)
**Listens:** basically everything (display).
**Harness checklist:** full HUD renders from a scripted mock event stream with no game modules present; button spam cannot emit malformed payloads; UI reflects `purchase_result: insufficient` with feedback.
**Forbidden:** any gameplay decision. If UI is deleted, the harness game must still "run" headless.

---

## AGENT 8 — ENVIRONMENT (MARS)
**Folder:** `modules/environment/`
**Scope:** map generation (crater/ridge/lava-tube layouts from seed — v1: 3 handcrafted layouts loaded from data, proc-gen later), sol day/night cycle driving `sol_changed`, dust storm scheduler (`environment_state` payloads: visibility, solar multiplier, airdrop delay), harvest node placement.
**Emits:** `environment_state`, `sol_changed`, `map_loaded` (node/spawn-edge layout payload)
**Listens:** `phase_changed`, `run_ended` (reroll seed)
**Data files:** `maps/*.tres`, `storm_tables.tres`, `sol_timing.tres`
**Harness checklist:** three maps load with valid spawn edges + harvest nodes; storm schedule fires correct payloads across a mocked 5-sol run; day/night timing matches data file.
**Forbidden:** enemy spawning (Waves reads your `map_loaded` payload), building logic.

---

## AGENT 9 — AUDIO
**Folder:** `modules/audio/`
**Scope:** event→sound mapping table (data-driven), music state machine per phase, dilation pitch-shift bus effect driven by `chronolith_field_state`, rover voice processing stages (more human per upgrade stage). Placeholder sounds fine — the mapping architecture is the deliverable.
**Emits:** nothing.
**Listens:** everything in the mapping table.
**Data files:** `sound_map.json` (event → sfx id, cooldown, volume), `music_states.tres`
**Harness checklist:** scripted event stream triggers mapped sounds; per-sound cooldown prevents machine-gun SFX spam from `enemy_moved`-scale events; phase change crossfades music.
**Forbidden:** everything else. Pure consumer.

---

## Dispatch Order & Merge Protocol

1. **You build Agent 0 (Core) first.** Nothing dispatches until `contracts.gd` v1 is frozen.
2. Dispatch **Agents 1, 2, 4, 5 in parallel** (Phase B).
3. Dispatch **Agents 3, 8** once field/phase contracts are proven in at least one Phase-B harness.
4. Dispatch **Agents 7, 9** anytime after Core (pure consumers).
5. **Agent 6 last** — it needs real `run_ended` flows to be meaningful.
6. One branch per agent (`module/rover`, `module/waves`...). Merge one module at a time into `main.tscn`, watch the bus log, only then merge the next.
7. **Contract changes:** any agent needing a new signal/payload field files a request to you; you update `contracts.gd`, bump `CONTRACT_VERSION`, and notify affected agents. Agents never edit contracts themselves.
