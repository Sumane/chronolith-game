# CHRONOLITH — Game Design Document

Version 1.0 · 7 September 2026 · Design baseline for Marc and Qwen

## 1. Authority and intent

This document replaces GDD v0.2. Read it with `chronolith-architecture.md` and `chronolith-agent-tasks.md`. The conversation's latest decisions supersede earlier scrap notes, including their 25-wave structure, two endings and run-number difficulty formula.

**LOCKED** means an agreed requirement. **TUNING** means an initial value or mechanism to validate, not a proven balance result. **DEFERRED** means do not implement in the initial playable. Do not silently turn a tuning failure into a change to a locked requirement.

**Pitch:** A dying alien Archivist anchors his consciousness in a NASA rover. On Mars he defends a crystal prison from an army trying to release its ancient warlord. Each defeat resets the physical world; knowledge survives. The rover ultimately becomes an extraordinarily powerful warrior mech. Strategy, construction and direct combat secure a lasting victory.

**LOCKED:** A fully 3D, third-person action/base-defence game in Godot 4.x, PC first. The existing top-down 2D prototype is reference material, not the target experience. No repository audit has been performed; reuse decisions require local inspection.

## 2. Non-negotiable experience

1. Drive within the battlefield: visible horizon, uneven terrain, physical structures and a camera behind the rover.
2. Choose a strategy: turret fortress, damaging fortifications, rover combat, temporal systems or combinations. Every supported specialisation needs a credible route through earlier enemy requirements. Poor spending and layouts can still fail.
3. Become immensely powerful: the NASA rover visibly evolves into a warrior mech. This transformation is required to defeat the final boss, including for defence-focused players.
4. Learn across timelines: engrams, blueprints and memories persist; harvested materials, installed upgrades and built defences do not.
5. Plan without penalty: the engram screen fully freezes simulation. Executing the plan happens in the live world.
6. Finish a story: one ending, then optional endless defence. No compulsory second completion.

Strategic freedom has one explicit exception: all winning builds ultimately field the mech. Their earlier research and defensive investments determine how they reach and support the final confrontation.

## 3. Camera, controls and presentation

**LOCKED:** Third-person chase camera, mouse-controlled orbit and aim; WASD driving with responsive, forgiving vehicle handling. Preserve a sense of mass without realistic low-speed rover simulation. Weapons are manually aimed; turrets fire automatically.

Initial control proposal: left mouse fires, E interacts/harvests, B opens building selection, Tab opens engrams, Escape pauses. Treat bindings as remappable implementation defaults. Use distinct input contexts so menu actions never fire weapons or place objects behind the menu.

The camera sits behind and above the chassis, with the rover in the lower centre and a clear sightline ahead. It must respond to obstructions and avoid terrain clipping. The aim marker must reflect an actual reachable shot: nearby walls can obstruct a weapon even when the camera sees past them. Mech scale and aiming need a separate tuned camera profile, retaining third-person control.

**Visual references supplied by Marc:**

| Reference filename | Use |
| --- | --- |
| `0778c7df-53d1-4859-b8ce-338ea1f560eb.png` | Primary early-game camera, rover scale, horizon and combat view. |
| `be2e98cb-d492-4b55-94f6-62961dea947b.png` | Driving beside a physical defended base; HUD direction. |
| `8c8598c4-e281-4673-9708-e9c973144805.png` | Base layout, walls and turret atmosphere; not an overhead gameplay-camera requirement. |
| `9b155bc6-095c-4a3b-97dc-de1391ed1ddc.png` | Hardware versus consciousness research presentation. |
| `646f8fa2-7034-40d4-9224-9acc7d1ee67a.png` | Rover/alien-tech contrast and temporal effects. The large crystal on the rover is superseded: only a shard travels with Vael. |

These filenames identify the previously supplied images; images are not bundled in this text pack. Art establishes direction, not a promise of matching generated-image fidelity. Start with readable 3D placeholder models. NASA hardware uses recognisable wheels, mast, arm and foil; alien additions develop into clean precision engineering. Grey/Archivist technology is not organic. Corsair technology can be brutal, asymmetric and biomechanical. Rust-orange terrain contrasts with cyan technology. HUD text must remain readable over bright dust and sky.

### Asset responsibility — locked

**Marc will supply the production 3D assets in a later version. Qwen is responsible for functional implementation using simple placeholders, not creating quality finished models.** Do not delay playable milestones while waiting for art, or spend implementation time modelling detailed characters, vehicles, buildings or environments. Concept images communicate the intended experience; they are not a request for Qwen to reproduce finished artwork.

Use labelled primitive meshes or lightweight blockouts for the rover, mech, enemies, structures and terrain. Distinguish them through silhouette, scale and flat colours. Demonstrate transformation and attacks using simple motion/state changes until Marc provides production models and animations. Placeholder quality is judged by gameplay readability, not visual polish.

Prepare for asset replacement: keep visual models separate from gameplay logic, define consistent scale/orientation and named attachment points, and document the required models and animations. Later integration of Marc's assets is an explicit art pass. Existing usable assets may be reused; do not purchase, download large asset packs or build a finished-art pipeline as an unsolicited substitute.

## 4. Story and ending

Vael is an Archivist, a scholar rather than a soldier. The Chronolith imprisons the fragmented consciousness of Sorrak the Undying, an ancient Reptilian conqueror. The Corsairs are his descendants and cult; they attack to shatter his prison. Vrax commands them and possesses temporal memory.

The Archivists had custodians, escorts and relay safeguards. A coordinated Corsair operation destroyed that protection. Vael survives the catastrophe and crash-lands on Mars, the last surviving Archivist. A shard bridges his dying consciousness into a dormant NASA rover. Detailed seal-key counts and casualty lists from the scraps are not locked lore; avoid contradictions about Vael already being dead or absent.

**Physical rules:** The main Chronolith remains at the base. Its destruction releases stored temporal energy, resets the world to the post-upload starting state and restores the prison physically. Vael's shard-linked consciousness retains knowledge. Sorrak's consciousness and Vrax's established temporal memory are explicit exceptions to ordinary forgetting; no inventory travels back. A fleeting Sorrak manifestation can accompany destruction before the reset. Exact cinematics are production work, not another gameplay system.

Rover destruction also ends the attempt: present the base's eventual fall and Chronolith reset without making the player watch an unattended battle. Knowledge already earned remains earned.

Vael's emotional arc progresses from sardonic denial to determined mastery and finally attachment to his unlikely new body. Memories and accomplishments trigger story beats; do not require eight or twenty attempts before critical dialogue. Vrax's taunts and bounded adaptation may acknowledge prior tactics. Sorrak's presence grows with meaningful progression, not an uncapped penalty per death. There is no hidden deadline that makes a campaign unwinnable.

**Single ending, agreed direction:** In the final sequence Vael's warrior mech defeats Vrax and his command threat while the base protects the prison. Vael uses his Archivist knowledge and evolved machinery to permanently repair the seal. Sorrak remains imprisoned, the surviving Corsairs retreat, and the loop ends. Vael survives in the rover/mech and finally answers NASA. The first peaceful moment beyond the former reset point closes the story. Dialogue, choreography and repair apparatus are still to be authored; the outcome is fixed.

Removed: mandatory self-sacrifice, Ending B, transmission-array collection as a second ending, and a successful campaign causing a victory reset. Temporal builds retain their abilities during the finale; do not implement the old blanket ban on dilation.

## 5. Attempt structure, timing and pause

**LOCKED:** A complete campaign attempt has 20 waves and targets approximately 45 minutes of active gameplay. Early failed attempts are shorter. The minimum campaign completion is five attempts from a fresh profile; five is not the expected experience for every player.

Forty-five minutes divided by twenty is 135 seconds per round including preparation, gathering, building, transitions and combat. **TUNING:** Treat this as a pacing budget, not a fixed assault timer. The next preparation phase follows a cleared wave; an early-start command ends preparation. Longer combat may lengthen an attempt. No new wave silently overlaps an uncleared one in the baseline.

Sequence: prepare and gather → assault while gathering remains available → clear wave and earn engram → optional paused research → next preparation. Wave 20 culminates in the final confrontation rather than adding an unbudgeted extra full boss run. **TUNING:** Vrax's command ship can become an active pressure from wave 15.

Engram view pauses enemies, projectiles, physics gameplay, harvesting, construction, cooldowns, hazards, timers and simulation audio. Research UI remains interactive; purchases can update persistent knowledge while paused. Resume the same world state on close. No catch-up time, passive income or completed construction accrues during pause. Nested pause reasons must not accidentally resume gameplay. Active-time telemetry excludes pauses and noninteractive ending cinematics.

Preparation is time for physical action, not an enforced menu deadline. The player may gather, repair, build and fight during assaults when safe enough. The game must support leaving the base to operate elsewhere, with direction alerts and breach warnings compensating for limited third-person visibility.

## 6. Engrams and research

Each successfully cleared wave earns an engram. **TUNING baseline:** One point per wave, once per attempt/wave pair. Repeating a wave in a later genuine attempt earns another; reloading the same clear does not. Death itself and simply starting an attempt earn nothing.

Use a research tree, not mandatory random upgrade offers. Hardware and consciousness are the presentation families; practical branches include fortifications, turrets, rover systems, temporal abilities and supporting logistics. All main strategies begin with useful starter options.

Persistent knowledge can contain increasingly powerful blueprints. This is not restricted to sidegrades: deliberate deeper research can overpower an earlier problem. Power still has to be manufactured and deployed during the new attempt. Do not award permanent unexplained damage or health for each death.

Track separately: lifetime engrams earned, unspent engrams, and purchased blueprint IDs. Earned totals may unlock research tiers; spending does not reduce tier eligibility. Specific blueprints may also require prerequisite knowledge and an engram purchase. Research availability and in-run construction affordability are separate questions. UI must state both clearly and show alternatives for known enemy requirements.

| State | On destruction/reset |
| --- | --- |
| Earned/unspent engrams, learned blueprints, recovered memories | Persist. |
| Enemy knowledge, story flags and campaign completion | Persist. |
| Gathered resources, power infrastructure, consumables and structures | Reset. |
| Installed rover upgrades and current mech body | Reset to starter rover; blueprint knowledge remains. |
| Current wave, active-world entities and temporary effects | Reset. |

**Implementation default:** Allow full research respec between attempts, refunding spent engrams and rebuilding valid dependencies; no negative totals or deleting dependants without refund. Do not allow in-run respec exploits that repeatedly unlock/build/refund branches. This preserves experimentation without requiring permanent commitment to a mistaken choice. Respec policy is tunable; its earliest-win implications must be included in progression checks.

## 7. Multiple barriers and the five-attempt requirement

The first attempt is not expected to clear all twenty waves. Capability barriers occur throughout the sequence and persist across later waves. Each barrier has several sustainable answers: e.g. armour-piercing turrets, crushing spike walls, a cutting beam, or a temporal vulnerability effect. Specific names and enemy assignments are **TUNING**, not final content.

Supported strategies must have credible answers to relevant threats. Do not invalidate a wall-focused strategy with an unavoidable roster that ignores every barrier. Different routes may cost more or require more skill. Sufficiently deep alternate research can brute-force earlier resistance; it cannot create a campaign win before the minimum.

**Nukes:** Scarce emergency wave-clearing options can bypass an early knowledge gap and earn additional engrams. Initial allowance proposal is one per attempt, with an upgrade to two. Use two immediately available nukes when checking the most permissive earliest-win case. Charges do not regenerate, duplicate through saves, or multiply via research respec. Availability, cost and maximum are provisional; raising the ceiling requires rechecking progression. Introduce required enemies across successive waves so nukes cannot carry an unprepared player to wave 20.

### Arithmetic reference model — not a finished balance design

The following simplified model establishes a useful upper bound under its assumptions: one engram per clear; zero starting engrams; counters activate immediately once their earned-total threshold is reached; at most two nukes, each bypassing one failed wave; no other bypass; each new requirement remains present in subsequent waves. Ignoring counter purchase/construction costs favours the player in this model.

| Requirement begins | Lifetime knowledge threshold | Maximum clear without that counter |
| --- | ---: | --- |
| Wave 4 | 6 | Wave 5, then stop at 6. |
| Wave 8 | 15 | Wave 9, then stop at 10. |
| Wave 12 | 28 | Wave 13, then stop at 14. |
| Wave 16 | 45 | Wave 17, then stop at 18. |

| Attempt | Best clears that attempt | Cumulative engrams |
| --- | ---: | ---: |
| 1 | 5 | 5 |
| 2 | 9 | 14 |
| 3 | 13 | 27 |
| 4 | 17 | 44 |
| 5 | 20 becomes possible | 64 if complete |

This example does NOT prove the final game has a five-attempt minimum. It excludes deliberate overlevelling routes, real blueprint costs, resources, respec and other abilities. The shipped data must be searched for the earliest winning route across all those options. Include the mandatory mech's prerequisite and acquisition timing in that search. A valid path must also be able to build the required equipment before the final fight.

Do not enforce the minimum with an unexplained `attempt_count < 5` boss immunity. Enforce it through coherent research depth, persistent wave pressure and bounded bypasses. Deep alternatives may clear a particular barrier earlier only if the whole campaign still requires five attempts. If freedom, balance and the minimum conflict, show Marc the concrete exploit or inaccessible route rather than quietly changing the rule.

## 8. Economy, building and combat

**Resource proposal:** Regolith for bulk fortifications, scrap for mechanisms, rare minerals for advanced technology. Power is infrastructure capacity/supply, not spendable money. The first playable uses scrap alone; additional resources enter when they create meaningful choices. No shards/DNA meta-currencies competing with engrams.

Nearby deposits provide accessible starter construction; richer deposits or salvage lie further from safety. Active harvesting requires presence and time. Later drones can automate it, with travel, throughput and protection costs. Nothing requires a forced expedition order. A player may succeed by investing heavily in defences and choosing safe resource routes.

Third-person placement uses a transparent ground preview, rotation, footprint checks and wall snapping. A construction radius around the rover is the baseline; remote construction can be researched. Placement validates terrain, overlap, reach and resources. Complete the transaction once: reserve space, spend once and create the construction site; cancel/refund exactly if it cannot be committed. Construction and repairs take active time. Demolition/refund ratios, costs and timing are data values to tune. No arbitrary small turret or wall-type caps that prevent intended specialisations; use costs, space, power and a measured overall technical budget.

Enemies can attack obstructing structures. Fully enclosing the crystal is a valid strategy, not grounds for cancelling enemy navigation or rejecting every wall. Walls and turrets occupy the 3D world; line of sight, projectile collision, firing height and approach width must work from rover level. Powered gates or accessible openings let the rover traverse its own base.

Rover stages: NASA → Hybrid → Ascendant warrior mech. Each stage visibly changes the body and combat capability. Exact mech silhouette, mobility and weapon roster remain art/tuning work. The final stage must deliver a dramatic increase in power and is research-gated; placeholder transformation must be tested early, not left to final polish. An upgraded rover can carry most direct combat, while even a fortress specialist actively controls the final mech engagement.

The fixed Chronolith has integrity and a readable enemy/projectile slow field. Specify effects per entity category; never globally slow player input or UI to imitate the field. Initial active: a brief local stasis effect excluding the rover. Additional temporal abilities can support every barrier. Full five-second world rewind, gradient fields and echo replay are deferred; they are not prerequisites for implementing reset or research.

## 9. Enemies, wave assembly and feedback

Use a data-driven wave budget with guaranteed capability pressure at barrier waves. Random composition is subordinate to the progression rules: randomness must neither omit a required threat nor introduce an impossible later-tier threat too early. Fixed/reproducible seeds support comparisons.

Initial enemies: one crystal attacker, then one ranged attacker and one protected enemy to exercise counter routes. Expand towards stealth, burrowing, orbital drops, anti-temporal units and spawners only after a corresponding readable response exists in supported builds. Shared AI behaviours are useful; weights alone do not implement burrowing, line of sight, counterplay or collision.

Communicate incoming directions, newly observed defences, ineffective attacks, resource shortages, unpowered structures and damaged sectors. Explain why a counter works. Do not require guessing an invisible immunity. Sorrak's phantom and environment effects must preserve readability. Random defence shutdown at low integrity is deferred because it can create an unrecoverable failure spiral.

Vrax may adapt within bounded rules to previous tactics. He must not punish repeated deaths with uncapped stat growth, alter the guaranteed gate envelope, or make a specialisation permanently unusable. Initial version uses authored dialogue and bounded composition variation; adaptive AI is later scope.

## 10. Completion, endless defence and saving

Wave-20 success records campaign completion before the ending. It never erases persistent progress. The player can continue the victorious rover/base into wave 21+, start another attempt with learned knowledge, or stop. Endless defence is explicitly outside the canonical ending, so endless defeat cannot undo Vael's victory. Fresh endless-mode attempts may use the same opening progression before continuing beyond 20; do not require the ending cinematic again.

Endless escalation primarily uses wave budgets and varied combinations. Do not raise every enemy stat simultaneously by a run-number formula. Preserve performance/readability caps; tune later escalation separately. Knowledge rewards may continue until research is complete; handling surplus engrams is tuning and must not affect campaign balance. Late unlocks become available to later campaign attempts and must not compromise fresh-profile validation.

Save persistent knowledge immediately after a cleared-wave reward or research transaction. Support suspend/resume of the current attempt; loading it restores the same attempt, not a new source of wave rewards or nukes. Quit/resume is not a temporal reset. Early prototypes may use between-wave suspension; full release needs a safe pause-and-suspend path. Endless continuation preserves the victorious state and completion flag independently.

## 11. Scope and verification priorities

First playable: one handcrafted 3D arena, correct camera/drive/aim, harvestable scrap, snapped walls, one turret, one enemy, three waves and visible crystal damage. This tests embodiment and the loop, not campaign progression.

Next, validate a small research/counter experiment and early mech placeholder. Build the progression simulator before authoring a large tree. Then expand to the twenty-wave campaign, story and endless continuation.

Defer procedural map tiles, random upgrade-card generation, full rewind, spectral replay, elaborate weather/power failures, multiplayer, transmission-array ending and broad adaptive AI. Keep the recognisable map across attempts. No calendar promises: advance through playable acceptance gates in the task document.

Release gates: correct 3D feel; meaningful in-world building; reliable pause/save/reward transactions; multiple viable strategies; no fresh-profile completion in fewer than five attempts under the supported rule set; a demonstrated attainable fifth-attempt route; final mech payoff; a definitive ending; optional endless play. Arithmetic checks are necessary but cannot prove that the game is fun.
