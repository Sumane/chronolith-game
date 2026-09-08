# CHRONOLITH — Qwen Implementation Milestones

Version 1.0 · 7 September 2026

## How to use this document

Read `chronolith-gdd.md` and the relevant architecture sections before starting. Execute one milestone at a time. Each must leave a playable, integrated build. Do not interpret the complete design as permission to implement every deferred feature immediately.

Marc has assigned Qwen implementation work. Do not require him to write Core, maintain every contract or perform routine integration. Work in a separate branch/worktree when adapting the old prototype; preserve existing work and respect local repository instructions. No repository-specific filenames or existing functionality have been verified by this document.

Maintain a short `docs/progress.md`: current milestone, completed acceptance checks, changed files, known limitations, exact next task and how to launch the playable. Before finishing a task, run available relevant checks, then report concrete visible behaviour. If blocked, report the specific dependency rather than inventing a feature or changing the design.

At each visual milestone provide screenshots or a brief recording plus concise play instructions. Marc's camera/feel review is the first product checkpoint; routine subsequent work continues within the assigned scope. Headless checks alone cannot approve feel. Do not add internet/library searches or large rewrites merely to satisfy a checklist.

### Asset rule for every milestone

Marc will provide the finished 3D models and production animations in a later version. Qwen should use simple primitive meshes or blockouts and focus on gameplay. Do not attempt detailed modelling or treat missing final art as a blocker. Placeholder attacks and mech transformation can use simple movement/state changes. Keep visuals replaceable as specified in the architecture guide and maintain a small asset manifest for Marc. Later art passes mean importing and integrating supplied assets, not asking Qwen to create production-quality models.

## M0 — Preserve and inspect

**Goal:** Establish a safe, runnable 3D starting point.

- Read repository instructions and inspect the project entry scene, editor version, inputs, save code and existing 2D components.
- Preserve the current prototype; create a separate 3D entry scene and working branch as appropriate.
- Produce a brief reuse assessment: keep data/pure logic, adapt sound services, replace 2D spatial systems. Do not audit unrelated files exhaustively.
- Record the pinned engine version and exact launch procedure. Resolve version assumptions locally rather than accepting the old 4.7 claim.

**Done:** Existing work remains recoverable; the new entry launches a real 3D world. A concise migration note lists verified reuse decisions. Do not implement a nine-module event framework.

## M1 — Establish the intended game view

**Goal:** Driving and aiming feel like the two third-person reference images.

- One small 3D arena with slopes, rocks, a fixed crystal and rover placeholder.
- Forgiving WASD vehicle control; mouse orbit/aim; camera obstruction handling.
- One manually fired weapon hitting 3D targets and respecting weapon obstruction.
- Basic pause and input contexts.
- Separate the placeholder visual from controller/collision logic and record scale, orientation and attachment conventions for later assets from Marc.

**Done:** Marc can drive around and through terrain features, turn the camera, aim and shoot. Shots cannot pass through a nearby wall because the camera sees beyond it. Rover stays readable in the lower part of the view, with a horizon. Show a screenshot/recording and obtain camera/feel feedback before treating the presentation as settled.

**Exclude:** Enemy roster, research, procedural maps and final graphics.

## M2 — Playable three-wave defence

**Goal:** A short integrated scavenge/build/fight loop.

- Harvestable scrap deposits; transparent placement preview, wall snapping and one automated turret.
- Construction/repair in live time, atomic spending and occupied-footprint validation.
- One enemy attacks the crystal and attacks obstructing walls when appropriate.
- Three preparation/assault rounds, early-start control, wave direction alerts and crystal/rover health.
- Both rover and crystal death end the attempt; a new prototype attempt starts cleanly.

**Done:** Drive out to harvest while turrets fight, return and repair/place structures. An enclosed base does not freeze enemies. Cannot double-spend, duplicate placements or harvest from a paused world. Wave clear is reliable. A three-wave win is labelled a prototype result, not campaign completion.

**Checks:** Targeted transaction checks plus one complete playthrough using walls and turrets. No full power network until this loop works.

## M3 — Engrams, full planning pause and persistence

**Goal:** Knowledge survives while the physical attempt resets.

- One engram per cleared wave; a small deterministic research tree with turret, fortification and rover options.
- Research screen shows earned total, unspent balance, prerequisites, effects and construction costs.
- Fully pause simulation while viewing/researching; resume exactly on exit.
- Persist knowledge, reward receipts and story flags; reset physical resources/equipment.
- Between-wave suspension initially; checkpoint loads resume the same attempt identity.

**Done:** Clear a wave, research while paused, lose, start again and construct a learned upgrade from newly gathered materials. No supplies or installed upgrades survive. Reloading the same wave-clear state does not grant another engram. Nested menus cannot unpause combat.

**Checks:** Snapshot simulation before/after a long planning pause; exact reward-once tests; save/quit/load; failure during save with backup recovery; spend/refund invariants. Record the release gap if mid-wave suspension is not implemented yet.

## M4 — Prove counter freedom and the progression model

**Goal:** Validate multiple solutions and the five-attempt requirement before expanding content.

- Add one protected enemy with at least three counter paths: a turret answer, a wall answer and a rover answer. Make resistance and successful counter feedback visible.
- Prototype emergency nukes with bounded charges and one explicit wave-clearing behaviour.
- Build a fast offline progression model sharing game data. Start with the GDD's illustrative thresholds, then add actual costs/prerequisites, respec boundaries, all bypass routes and the final mech requirement.
- Search shorter attempts and intentional resets, hoarding/spending, mixed builds and all nuke placements. Include immediately usable research after wave clear.

**Done:** Export route traces showing why attempts 1–4 cannot win under the represented rules and at least one attainable fifth-attempt path. Include model limitations. Playtest the protected enemy using each of the three solutions. An advanced alternate branch can overcome an earlier problem without an early campaign exploit.

**Important:** Changing a nuke ceiling, rewards, loot-derived research, free starting blueprints or alternate counter strength invalidates the relevant check. Do not add a hidden attempt-count lock as a shortcut.

## M5 — Prototype the mech payoff

**Goal:** Prove the central fantasy early with placeholder assets.

- Research and construct one Hybrid stage and one warrior-mech stage.
- Clearly change body, mobility, weapons and camera tuning. Powerful combat must remain controllable and readable.
- Prototype a command target that requires the mech while base enemies continue attacking.
- Verify that a defence-heavy route can afford/reach the transformation and a rover-heavy route can defend with minimal supporting construction.

**Done:** A short integrated scenario demonstrates why the mech is exciting and necessary. A player can traverse their own base, fight large targets, and still understand crystal danger. Final art/animation is not required for this proof.

## M6 — Build the twenty-wave campaign

**Goal:** Turn validated systems into the full campaign curve.

- Expand the research graph, resources and infrastructure only where they support distinct choices.
- Configure all four barrier bands and guaranteed wave pressure with variation inside permitted budgets.
- Populate one recognisable map with meaningful resource distances and approach routes.
- Tune round phases to approximately 45 active minutes for a complete run; failed attempts remain shorter.
- Add a usable final research/build route for every supported specialisation, all including the mech.
- Implement accessible counter explanations, warnings and appropriate input remapping.

**Done:** Playable twenty-wave route plus recorded early defeats. Verify turret-focused, fortification-focused, rover-focused, temporal-focused and mixed routes; none needs equal efficiency, but none is merely advertised without a demonstrated counter/build path. Rerun earliest-win validation using the actual campaign data.

**Measure:** Active time versus pause time, first barrier reached, engrams per attempt, causes of death, time spent rebuilding familiar opening structures, resource bottlenecks and time at maximum mech power. If the mech arrives too late to enjoy, tune its availability and supporting progression without bypassing the five-attempt requirement.

## M7 — Story, finale and one ending

**Goal:** Deliver the recovered story without a mandatory narrative route through research.

- Brief Vael upload opening; milestone-triggered memories and contextual dialogue.
- Explain Sorrak's imprisonment, the Corsairs' purpose and Vrax's memory.
- Integrate Vrax's command pressure and wave-20 climax with the established combat loop.
- Defeat Vrax, repair Sorrak's seal, end the loop, keep Vael alive and have him answer NASA.
- Record completion before the ending plays. No victory reset, second ending or final-act shutdown of temporal builds.

**Done:** Someone can understand the stakes and conclusion without reading the GDD. Defeat in the finale permits another normal attempt and never deletes progress. The ending can be skipped after completion without compromising state.

## M8 — Endless continuation and release hardening

**Goal:** Offer post-completion experimentation and dependable saves.

- Continue the victorious physical state into wave 21+ as optional noncanonical endless defence; allow fresh attempts using learned knowledge.
- Separate campaign completion from endless failure; avoid re-triggering final cinematics.
- Full safe pause/suspend/resume, including nukes, enemy state and in-progress transactions.
- Profile maximal defence layouts and high-wave combat. Bound spawning, navigation and effects without destroying viable strategies.
- Add final audio/art passes and only then optional bounded adaptation or weather if justified by playtests.

**Done:** Continue after the ending, suspend/load, play further waves, lose, and still have a completed campaign with intact knowledge. No duplicate rewards, free nukes or lost progression. Document the tested hardware/performance envelope and remaining limitations.

## Compact task handoff template

Use for one bounded Qwen assignment:

1. Current milestone and exact player-visible objective.
2. Relevant GDD/architecture sections and local repository instructions.
3. Current scene/launch command and known verified state.
4. Cohesive files/systems likely involved; permit necessary integration edits.
5. Acceptance behaviours and relevant existing checks.
6. Explicit deferred features and unresolved balance assumptions.
7. Required return: changed files, checks actually run, screenshot/recording when relevant, known issue and next task.

Never report a checklist as passed because code exists. Never replace third person with a 2D or overhead prototype to simplify an assignment. Preserve the distinction between a design rule, a tuned number and a tested result.
