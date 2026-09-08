# M4 Progression Model

Offline, headless simulation of the multi-attempt campaign. Proves the
five-attempt minimum under the represented rules and exports route traces
(`docs/progression-traces.json`).

## Files

- `progression/progression_model.gd` — pure GDScript, no scene.
- `tests/v1/progression_probe.{gd,tscn}` — 10 checks, headless.
  `env XDG_DATA_HOME=$PWD/.xdg XDG_CONFIG_HOME=$PWD/.xdg godot --headless --path . tests/v1/progression_probe.tscn`
  → `== progression probe: 10 ok, 0 fail ==`

## Shared game data (real, not model-local)

- `ResearchTree.NODES` / `ORDER` — actual v1 catalog, costs, prerequisites.
- Knowledge ledger semantics — lifetime `earned_total` is monotonic
  (thresholds apply to it); spend is atomic and balance-gated; receipts are
  idempotent per attempt:wave.
- Nuke rules — bounded charges per attempt, each bypasses exactly one failed
  wave (no engram, no scrap), no regen, no duplication through respec.
  Standard = 1 (current `entry.nuke_charge`); permissive = 2 (GDD check case).
- Respec boundary — GDD implementation default: full refund between attempts,
  no in-run unlock/build/refund loop; refund restores spendable balance,
  never lifetime knowledge.
- Build costs — wall/turret scrap costs mirror `BuildService.COSTS`; scrap
  economy (start 6, +6/wave) is illustrative.

## Campaign schedule (GDD illustrative reference)

20 waves, 1 engram/clear, barriers (protected tier appears / hard-block
wave / lifetime-knowledge threshold):

| Barrier | appears | blocks from | threshold |
| --- | ---: | ---: | ---: |
| A | 4 | 6 | 6 |
| B | 8 | 10 | 15 |
| C | 12 | 14 | 28 |
| D | 16 | 18 | 45 |

A wave is clearable iff lifetime earned ≥ every active barrier threshold.
The final wave additionally requires the mech (parameterized below).

## Search space

Nuke charges 0/1/2 × respec on/off × nuke placement (holdout 0/1/2 = walk
away from the first k blocked waves instead of nuking them — verifies the
greedy placement is optimal) × mixed builds (any of the three research lines
as the counter; spend-immediately after each wave clear, the only purchase
timing that can help, since thresholds are earned-based). 18 runs total.

## Results

- Reference reproduction (0 nukes): best clears **5 / 9 / 13 / 17**,
  cumulative **5 / 14 / 27 / 44**, win on attempt 5 — matches the GDD table.
- **Earliest win = attempt 5 under all 18 strategies.** Nuke invariance:
  0, 1 and 2 charges never beat attempt 5 — the persisted barrier
  requirements make a nuke a one-wave skip, not a threshold bypass.
- Attempts 1–4 are infeasible under every strategy; the JSON export lists
  each strategy's blocked wave, end-of-attempt engrams and the threshold gap.
- Respec boundary: full refund does not lower the earliest win; no strategy
  produces a negative balance.
- Mech gate: the winning path buys the mech node (3 engrams, requires `r2`)
  and builds it (8 scrap) well before wave 20.
- Catalog gap: the real v1 tree is 9 engrams deep; the wave-16 barrier needs
  45 lifetime knowledge — **M6 must expand the research graph by ~4×**
  (or rebalance thresholds) before the 20-wave campaign is represented by
  real nodes.

## Model limitations

1. **Schedule is illustrative.** Barriers/thresholds/wave-count are the GDD
   reference, not shipped data; the game currently has 3 waves. M6 replaces
   the schedule with real campaign data — the search must be re-run.
2. **Counter representation.** Barriers are modelled as threshold gates on
   lifetime knowledge; the real v1 tree (6 nodes) is too shallow to be the
   actual counter source, so purchase cost is shared but the node→counter
   mapping is abstract. M6 maps barriers to concrete nodes.
3. **Scrap economy is illustrative** (start 6, +6/wave, lump build costs).
   Real harvest distance, deposit depletion and repair drain are not modelled.
4. **No in-run timing.** The model is a clear-level simulation: no wave
   duration, no skill ceiling, no crystal-damage races. A path the model
   calls attainable still has to be *defended* in real time.
5. **Mech is a parameter** (cost 3 / req `r2` / build 8), pending M5.
6. **No endless-mode or post-20 rules** (GDD §10) — out of scope for the
   five-attempt proof.
7. Nuke "skip one failed wave" is the GDD reading; if nukes instead heal
   the crystal or clear an active wave mid-fight, the permissive case must
   be re-run.

## Invalidation

Per the task's Important note: changing the nuke ceiling, rewards, loot-
derived research, free starting blueprints or alternate counter strength
invalidates the relevant check — re-run the probe after any such change.
