# CHRONOLITH
## Game Design Document — v0.2
*Working title. Base building / tower defence / roguelite.*

> **DECISION (2026-08-27, Marc):** the game is **3D, built in Godot 4.x**.
> This overrides the earlier "top-down or isometric recommended" note below.
> The current codebase (`core/` + `modules/`) is a **2D (Node2D) vertical-slice
> prototype** of the gameplay systems — it is *not* the final presentation.
> The 3D conversion is the next major work item; see
> `docs/3D-CONVERSION.md` for the roadmap and `NOTE-3D.md` at the repo root.

---

## 1. High Concept

A grey alien, ambushed by Reptilian forces, crash-lands on Mars beside a NASA rover. Mortally wounded, he uploads his consciousness into the rover's computer. His mission: protect the **Chronolith** — a crystal with time-dilation properties — from the Reptilian armada that will stop at nothing to claim it.

**One-liner:** *A dying alien's mind inside a NASA rover defends a time-bending crystal against an invading armada — dying only makes him smarter.*

**Genre:** Base building / tower defence / roguelite
**Perspective:** **3D** (decided 2026-08-27). Camera: top-down 3D / orbit — see `docs/3D-CONVERSION.md`.
**Target platform:** TBD (PC first)
**Engine:** **Godot 4.x** (decided; repo currently targets 4.7 — see `project.godot`)

### Design Pillars
1. **Contrast is the fantasy.** Clunky, real-world NASA hardware slowly transcending into precision alien technology. Every upgrade should be *visible* on the rover.
2. **Time is a resource, not a gimmick.** The Chronolith's dilation properties shape combat, layout, economy, and the roguelite loop itself.
3. **Death is generative.** Every timeline reset feeds the next run — mechanically (unlocks) and narratively (memory recovery).
4. **The base is an argument with the map.** Terrain, dilation gradient, and enemy approach vectors make layout a puzzle, not a checklist.

---

## 2. Narrative

### Setup
The Greys and the Reptilians have been at war in the shadows for millennia. The Chronolith — origin unknown, possibly pre-dating both species — is the prize. Our protagonist was its custodian in transit when his ship was ambushed. He crash-lands on Mars, dying, within crawling distance of a dormant NASA rover. With his last act he uploads his consciousness into it.

### Ongoing Narrative Delivery
- **Memory fragments** (see §6.3): the upload was imperfect. Corrupted memories surface between waves, gradually revealing who the Grey was, what the Chronolith is, and why the war started.
- **Earth transmissions** (proposal): NASA still believes the rover is theirs. Command packets arrive — "drill sample at site B7" — and mission control's flavour-text reactions escalate as the rover visibly ignores them / grows plasma cannons. Comic relief and a slow-burn subplot (does Earth ever work out what's happening?).
- **Environmental storytelling:** the crashed grey vessel is a persistent map landmark and the meta-progression hub.

### Tone
Grounded sci-fi with dry wit. The horror of the Reptilians and the loneliness of Mars, undercut by the absurdity of a NASA rover with a soul. Think *The Martian* meets *X-COM* meets conspiracy-theory pulp.

---

## 3. Core Gameplay Loop

Each **run** = one timeline. A run consists of alternating phases:

### 3.1 Calm Phase (Sol / Day)
- Drive the rover to **scavenge**: regolith, scrap from the crashed ship, rare minerals, downed enemy salvage.
- **Build and repair** defences around the Chronolith.
- Choose wave modifiers / scout incoming threat composition (telemetry from the rover's instruments — reuse of real NASA kit as gameplay: spectrometer = enemy scanner, drill = mining, etc.).

### 3.2 Assault Phase (Night / Storm)
- Reptilian waves attack from orbit drops, surface approach, and underground tunnels.
- Player fights directly with the rover (action layer) while built defences hold the line (tower defence layer).
- Wave count and intensity scale per sol.

### 3.3 Timeline Reset (Run End)
- Run ends when the Chronolith is destroyed, the rover is totaled, or the player survives the final assault of the cycle (victory reset).
- The Chronolith triggers a **Time Dilation Flash** — the timeline resets, but data persists (see §6).

---

## 4. The Rover

### 4.1 Progression Fantasy
The rover's transformation is the visual spine of the game. Three broad stages:

| Stage | Look | Capability |
|---|---|---|
| **NASA** | Gold foil, six wheels, single arm, mast camera | Slow. Weak single-target laser (spectrometer overdriven). Basic physical walls only. |
| **Hybrid** | Plasma shielding over NASA chassis, mag-lev wheel replacements, extra manipulator arms | Faster traversal, deployable mini-drones, first energy weapons, AoE options. |
| **Ascendant** | Sleek biomechanical frame built around the original rover core — grey-tech precision engineering | Hover movement, telekinetic remote building, short-range teleport, disintegrator beam. |

**Art rule (locked):** the rover track and the grey vessel track are *separate aesthetics*. The vessel is clean, straight-lined, precision-engineered, futuristic — never organic. The rover starts grounded/functional and *converges toward* the grey aesthetic as it ascends.

### 4.2 Player Verbs
- Drive / hover
- Harvest (arm/drill)
- Build & repair (in range early game; remote late game)
- Fire primary weapon (upgradeable slots)
- Deploy consumables (drones, mines, decoys)
- Trigger Chronolith actives (see §5)

---

## 5. The Chronolith

Not a passive health bar — an active battlefield participant.

### 5.1 Passive: The Dilation Bubble
A field around the Chronolith slows enemy movement and projectiles. Upgrades expand radius and slow factor.

### 5.2 Proposal: The Dilation Gradient
Extend the bubble into a map-wide gradient: time runs *slower* near the Chronolith and *faster* at the map edge. Consequences:
- Enemies at range move (and spawn) at up to 2× speed; inside the perimeter everything crawls.
- Long-range turrets placed at the edge fire faster but are exposed.
- Base layout becomes about *choosing where to fight*, not just wall placement.

### 5.3 Actives (unlockable, shared cooldown pool)
- **Rewind:** undo the last ~5 seconds of combat. High cooldown. The signature "oh no" button.
- **Overclock:** drain Chronolith integrity to hyper-accelerate the rover's speed and fire rate.
- **Stasis Snap:** freeze everything inside the bubble for 3 seconds (rover excluded).

### 5.4 Risk Economy
Chronolith integrity is both the lose condition *and* a spendable resource (Overclock, certain top-tier buildings). Tension: the strongest tools eat your win condition.

---

## 6. Roguelite Meta-Progression

Hub: the interior of the crashed grey vessel.

### 6.1 Currencies
- **Chronal Shards** — earned per wave survived; spent on permanent unlocks.
- **Alien DNA** — rare drops from elite/boss kills; spent on rover evolution stages.

### 6.2 Permanent Unlocks
- New turret/building blueprints added to the run pool.
- Baseline stat improvements (repair speed, starting resources, harvest rate).
- New Chronolith actives and bubble upgrades.
- Starting loadout variants (run archetypes).

### 6.3 Memory Retrieval (narrative-mechanical hybrid)
Between waves, corrupted memory fragments surface. Player chooses per fragment:
- **Repair** it → small permanent stat bonus + a piece of story.
- **Purge** it → immediate in-run resource injection, story lost for this timeline.
Long-term completionists reconstruct the full backstory; speedrunners strip-mine the Grey's soul. Both are thematically on-message.

### 6.4 Proposal: Echo Rovers
The Chronolith leaves residue across timelines. At the start of each run, a spectral echo of your *previous* run's rover replays its final 60 seconds of combat as a friendly ghost-turret. Dying well becomes a gift to your next self. Cheap to implement (record input/position buffer), enormous thematic payoff.

---

## 7. Building & Economy

### 7.1 Resources (in-run)
- **Regolith** — bulk material, walls and foundations. Everywhere, slow to gather.
- **Scrap** — from the crash site and destroyed enemies. Turrets and mechanisms.
- **Rare minerals** — vein deposits, contested map locations. Energy weapons and grey tech.
- **Power** — solar generation; storms and night reduce it (see §9).

### 7.2 Proposal: Two-Tree Salvage Economy
Two distinct tech identities per run:
- **Grey Tech** — precision, energy, control. Slow-fields, phase walls, beam emitters, hard-light barriers. Clean, reliable, expensive.
- **Reptilian Salvage** — brutal, biological, unstable. Acid mortars, pheromone lures that redirect enemies, spawnable beast-turrets. Cheap and powerful but with drawbacks (attracts larger waves, degrades over time, occasional friendly-fire chaos).
Mixing is allowed but synergy bonuses reward commitment — creates run identity.

### 7.3 Building Categories
- **Walls & terrain** (regolith ramparts, trenches, hard-light gates)
- **Turrets** (kinetic → energy → temporal)
- **Support** (repair bays, power relays, radar/scanner masts, drone hangars)
- **Chronolith augments** (bubble extenders, rewind capacitors)
- **Traps** (mines, gravity wells, tunnel collapsers)

---

## 8. Enemies: The Reptilian Armada

Design rule: every enemy type must force a *layout* response, not just more DPS.

| Type | Behaviour | Counter-pressure |
|---|---|---|
| **Shock Troopers** | Mass rush at walls | Baseline; chokepoints and AoE |
| **Chameleon Stalkers** | Cloaked, bypass turret targeting | Rover scanner illumination; scanner mast coverage becomes a layout consideration |
| **Burrowers** | Tunnel under walls, emerge near the Chronolith | Interior defence, seismic sensors, tunnel collapsers |
| **Orbital Droppers** | Skip the perimeter entirely, pod-drop mid-base | Anti-air, reaction play from the rover |
| **Dampeners** (elite) | Project anti-dilation fields, neutralising the bubble locally | Priority targets; punish pure-bubble strategies |
| **Broodmothers** (mini-boss) | Spawn streams of lesser units until killed | Forces the player to leave the base and strike out |

### Bosses
One per cycle-end. Each should attack the *premise*, not just the walls — e.g., a Reptilian temporal engineer who reverses the dilation gradient; a salvager titan that eats your buildings and deploys them against you.

---

## 9. Mars: The Third Faction (proposal)

The planet is neutral and lethal.
- **Dust storms:** blind turret targeting, cut solar power, but also slow Reptilian air drops.
- **Freezing nights:** power drain; unpowered turrets sleep.
- **Terrain:** craters, ridges and lava tubes shape approach vectors — procedural map variation per run.
- **Late-game grey tech** can weaponise weather: storm redirection, localised freezes.

---

## 10. Run Structure (draft)

- A run = **1 cycle = 7–10 sols**, each sol = calm phase + assault phase.
- Every 3rd sol: elite wave. Cycle end: boss.
- Difficulty tiers unlock post-victory (deeper timelines, harder Reptilian tech, mutators).
- Target run length: 40–70 minutes early on; shorter as players get efficient.

---

## 11. Art Direction

- **Grey vessel / grey tech:** sleek, aerodynamic, straight lines, simplistic, precision engineering. Star Wars-style straight-leg landing gear. **Never organic.**
- **Rover:** authentic NASA grounding at start (gold foil, wheels, mast) converging toward the grey aesthetic through upgrade stages.
- **Reptilians:** the deliberate opposite — organic, brutal, asymmetric, bio-mechanical.
- **Mars:** muted ochres and rust; the Chronolith and grey tech provide the only cold, clean light on the map. Colour language: warm = danger/planet, cool = sanctuary/tech.
- Existing concept art: grey alien A-pose (pre-merge), grey vessel exterior (multiple angles in progress).

---

## 12. Audio Direction (sketch)

- Sparse, wind-driven ambience during calm phases; NASA-style telemetry beeps as UI language.
- Assault phases: percussion builds; time-dilation effects pitch-shift audio inside the bubble (slowed audio inside, sped up at map edge — free feedback for the gradient mechanic).
- The Grey's "voice" is processed rover speech synthesis — gradually less robotic as he ascends.

---

## 13. Open Questions

1. ~~Perspective and camera: top-down, isometric, or third-person hybrid?~~ **RESOLVED (2026-08-27): 3D in Godot.** Exact camera angle/dolly and whether the rover is seen from a fixed top-down 3D view or an orbitable third-person view are still open — first answerable once the 3D prototype (see `docs/3D-CONVERSION.md`) exists.
2. Direct rover combat: how action-heavy? (Twin-stick? Point-and-click abilities?)
3. Session structure: single long runs vs. save-mid-run?
4. Scope check: which proposals (§2 Earth transmissions, §5.2 gradient, §6.4 echoes, §7.2 dual trees, §9 Mars faction) make the vertical slice, and which wait?
5. Multiplayer/co-op: out of scope, or a second rover ("two survivors uploaded") later?

---

## 14. Vertical Slice Definition (suggested)

One procedurally-lite map, 3 sols, NASA-stage rover with one upgrade visible, 4 building types, 3 enemy types (Troopers, Stalkers, Burrowers), Dilation Bubble passive + Rewind active, one memory fragment event, timeline reset returning the player to a stub hub with one purchasable unlock. That's the whole fantasy in miniature — if that 20 minutes is fun, the game is fun.
