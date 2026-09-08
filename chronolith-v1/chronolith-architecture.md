# CHRONOLITH — Architecture and Integration Guide

Version 1.0 · 7 September 2026 · Companion to `chronolith-gdd.md`

## 1. Purpose and migration

Build a single-player 3D game in Godot 4.x. Inspect the installed editor and project configuration locally, then pin the compatible version in the repository. The old documents' claim that the project targets 4.7 has not been verified here. Do not upgrade engines as an incidental task.

The existing 2D prototype has not been audited. Preserve it in version control and create an isolated 3D entry scene/branch. Classify useful code into reusable data/pure rules, adaptable systems, and 2D-specific presentation/physics. Movement, aiming, collision, navigation and placement require genuine 3D implementations; conversion is not a sprite replacement. Do not replace the entire repository or copy old contracts blindly.

## 2. Ownership and communication

Use small, explicit components and a composition root. Typed direct calls or injected interfaces handle commands and queries. Signals notify listeners of completed facts. An event bus is useful for coarse global notifications, not mandatory for every interaction, mouse movement or enemy position.

| Owner | Authority |
| --- | --- |
| GameFlow | Attempt lifecycle, phase transitions, wave clear, death/victory precedence and mode. |
| PlayerRig | Rover/mech movement, camera, aiming, equipment and input contexts. |
| Combat | Authoritative hit/damage/effect rules and target interfaces. |
| World | Terrain, deposits, spawn points and spatial queries/navigation integration. |
| BuildService | Placement, occupied footprints, construction lifecycle and repair. |
| Economy | In-run material balances and atomic spend/refund. |
| PowerNetwork | Generation, consumption and connectivity; one owner for supply state. |
| WaveDirector | Data budgets, required threats, spawning and living-wave membership. |
| Chronolith | Integrity, field configuration, local time effects and destruction notification. |
| Research | Lifetime/unspent engrams, blueprint graph, eligibility and purchases. |
| ProfileStore | Durable profile transactions and attempt checkpoint serialization. |
| UI/Audio | Presentation and input forwarding; may keep view state but never authoritative gameplay balances. |

Entity health belongs to that entity's damageable component. Combat resolves accepted hits once; UI and Waves must not independently decrement health. Enemy AI selects intent; navigation supplies movement; target queries do not copy all enemy positions through a global dictionary every frame.

Proposed repository areas: `game/` for flow/composition, `player/`, `combat/`, `world/`, `building/`, `waves/`, `chronolith/`, `progression/`, `persistence/`, `ui/`, `audio/`, `data/`, `tests/`. Adapt existing names if sound. Do not create empty frameworks for every future feature.

### Replaceable visual assets

Marc supplies production 3D assets later. Qwen uses primitive meshes/blockouts throughout functional milestones. Keep a replaceable visual child/root beneath each gameplay entity; controller identity, health, collision, navigation, targeting and save IDs must not depend on imported model hierarchy or mesh names. Keep camera and weapon attachment contracts explicit rather than searching for arbitrary bones in a placeholder.

Document a common scale, forward/up orientation, origin, approximate dimensions, attachment points and required animation actions before final art integration. Use stable sockets for weapon muzzles, chassis attachments, crystal shard and camera targets where needed. An asset-specific adapter can map the final rig to these contracts. Visual-only scaling must not silently change movement, range or damage; revise collision/navigation dimensions deliberately when final silhouettes require it.

Maintain a compact asset manifest listing each placeholder, expected production replacement, dimensions, sockets and animations needed from Marc. Validate the approach by replacing one placeholder visual with a differently structured test mesh while preserving gameplay. Full rigging, detailed modelling and finished animation production are outside Qwen's implementation assignment.

## 3. Spatial and data contracts

World positions and directions use 3D vectors. Two-dimensional coordinates are allowed only for UI and a documented ground-grid index; conversion maps grid cells onto world-space X/Z and sampled Y elevation. Use stable entity IDs for saves, commands and diagnostics. References may be injected for live services; serialized state stores IDs, not scene paths.

Prefer typed resource definitions for authored tuning and typed command/result objects for critical transactions. Definitions include stable IDs, prerequisites, costs, capability tags and schema versions. Validate definitions at load. Avoid free-form dictionary payloads as the sole executable contract.

Minimal command/query examples (specifications, not verified engine API snippets):

| Operation | Required information/result |
| --- | --- |
| AttemptPlacement | Request ID, blueprint ID, 3D transform, actor ID → accepted site ID or reason; authoritative service derives cost. |
| PurchaseResearch | Request ID, blueprint ID, profile revision → purchased or reason; validates prerequisites/balance. |
| ApplyHit | Hit ID, source/target IDs, damage/effect specification → one accepted resolution. |
| AwardWave | Attempt ID, wave index → idempotent profile reward receipt. |
| GetBuildPreview | Blueprint and candidate transform → terrain/overlap/reach/resource validity. |
| GetTargetCandidates | Position, range and faction/capability filters → current valid targets. |

Facts such as `wave_cleared`, `research_changed`, `building_completed`, `chronolith_destroyed` and `campaign_completed` are emitted only after their authoritative state change. HUD can request an initial snapshot when opened; it must not depend on having heard every past event.

Programming invariants fail visibly in development. Malformed external saves produce recoverable errors. Do not silently drop critical commands and pretend success, or assume a broken core system can always degrade safely.

## 4. Simulation, pause and clocks

Suggested lifecycle: READY → PREPARATION → ASSAULT → WAVE_RESOLUTION → PREPARATION, with terminal transitions to DEFEAT/RESET or CAMPAIGN_VICTORY. Endless continuation switches mode after recording victory. Pause is an orthogonal set of reasons, not a wave phase.

One simulation clock owns active elapsed time. Engram UI and normal pause freeze gameplay processing, physics interactions, timers and any worker-produced world mutations. UI/navigation in menus and persistent research transactions remain allowed. Pause and resume simulation audio; separate menu audio if desired. Wall-clock elapsed time must never become catch-up gameplay on resume.

Use a pause-token/reason mechanism. Closing engrams removes its reason but cannot override another menu's pause. Closing a menu clears or consumes relevant input so clicking a purchase does not fire a shot on resume. Harvest/build timers, projectile lifetimes, ability cooldowns and wave countdowns all use the same pause semantics.

Local dilation is separate: eligible enemy movement, attack cadence and enemy projectiles receive explicit local modifiers. Player controls, UI, engram time and the preparation clock stay unaffected. Stasis expiry uses active simulation time, not an entity's own frozen local clock. Each effect has a documented stacking rule; placeholder defaults must be centralized. Do not implement whole-world snapshots merely to support ordinary timeline resets.

## 5. Economy and construction transactions

Placement preview is advisory. On confirmation, BuildService revalidates blueprint knowledge, terrain, reach, occupancy and resources. Reserve the footprint, atomically debit authoritative cost and create the construction site. If creation fails, release reservation and refund exactly once. Duplicate request IDs return the original result. Never spend both on placement request and a later `build_placed` notification.

Economy owns material quantities. PowerNetwork owns power capacity/connectivity and publishes snapshots. Research purchases affect persistent engrams, not the in-run material ledger. Costs come from definitions; callers cannot claim an arbitrary zero price.

Destroyed sites free their footprints. Damage, demolition and cancellation have explicit refund rules. Structures never generate refunds exceeding original spending through rounding, upgrades or repeated cancellation. Navigation changes are batched when necessary; fully blocked enemies attack a reachable obstruction instead of freezing.

## 6. Wave and terminal resolution

WaveDirector owns pending spawns and wave-member IDs. A wave clears only when required spawns/objectives are resolved and no blocking enemy remains. Off-screen enemies need a recoverable navigation policy, not an arbitrary silent award. A nuke applies normal authoritative outcomes and cannot skip reward bookkeeping.

Resolve lethal damage and objective states before rewards. Proposed tie rule: if the rover or crystal is destroyed on the same simulation step as the last enemy, defeat takes precedence and that wave is not awarded. This is an implementation default to keep deterministic; expose it in tests. Prior cleared-wave knowledge remains intact.

Reward persistence must be committed before publishing the clear to consumers. Mark an attempt terminal exactly once; simultaneous death notifications cannot create two resets or refunds. Record campaign completion durably before playing the ending or transitioning to endless mode.

## 7. Saves, reset and recovery

Profile fields: schema version, profile ID/revision, lifetime earned, unspent engrams, purchased blueprint IDs, story/memory flags, enemy knowledge, campaign-completed flag and applied reward receipts. Attempt checkpoint fields: attempt ID, mode, seed, wave/phase, active time, resources, structures, player equipment/health, crystal state, consumables including nuke charges and enough world state for the supported suspension boundary.

A reset discards the current physical snapshot and creates a new attempt from starter definitions plus retained knowledge. A checkpoint load resumes the same ID and world. Reopening the same cleared-wave checkpoint cannot issue another reward. Keep the reward receipt and knowledge update in one durable transaction; coordinate the attempt checkpoint revision so crash recovery is deterministic.

Use atomic file replacement, a validated schema and a last-known-good backup. Detect incompatible/corrupt saves, preserve the original for recovery and inform the player; do not silently overwrite their progress with a fresh profile. Save writes are serialized. Internal callbacks must not independently write conflicting copies of the profile.

Early between-wave suspension is acceptable during prototyping. Before release, implement safe suspension from pause, either serializing the full active attempt or using a clearly defined equivalent mechanism that cannot duplicate resources/rewards. Do not quietly reset a wave when the user expects exact suspension.

## 8. Progression data and validation

Share research and wave definitions between the game and an offline progression model. Model earned/spent points, prerequisites, current knowledge, research respec boundaries, remaining nukes, wave-required capabilities and mandatory mech access. Include alternate high-power routes and conservative upper bounds on harvesting/construction affordability. Treat uncertainty in the player's favour when searching for early wins.

The simplified GDD table is a reference case, not the complete shipped graph. Validate its arithmetic separately, then expand the model. Search all reachable choices across attempts 1–4 for an early win; find at least one attainable attempt-5 plan. A script that asserts `attempt >= 5` by construction does not validate gating. Produce route traces with purchases, bypasses and limiting barriers.

Simulation can find logical violations; playtests still establish handling, available building time, navigation, viable specialisations and fun. Do not claim exhaustive gameplay proof from an abstract model.

## 9. Integration and performance

Use one integrated playable scene continuously. Small isolation tests suit research, economy and lifecycle rules; compulsory per-folder scene harnesses and manual contract ownership by Marc are removed. Qwen may edit cohesive dependencies needed for its current milestone and is responsible for integration.

Measure enemy, structure, projectile, navigation and draw cost before choosing pooling or custom batch simulation. No all-entity per-frame bus logs. Use a debug overlay with wave, active time, attempt ID, earned knowledge, nuke charges and last rejected action. Event logging is opt-in and filters high-frequency traffic.

Declare a measured target-machine performance budget before scaling final hordes; the supplied concept art is not a performance specification. Use real 3D geometry, collision and navigation from the first milestone. Profile maximal wall/turret layouts as well as rover-focused play. Do not optimise away required strategic freedom through arbitrary low type caps.

## 10. Required verification

Automate where failure loses progress or invalidates the design: atomic spending, duplicate rewards, pause invariants, save/recovery, reset persistence, terminal precedence, prerequisite graph and earliest-win search. Use manual or recorded playthroughs for camera, vehicle feel, readability and progression pacing. Engine startup without parser errors is necessary but not a gameplay acceptance test.
