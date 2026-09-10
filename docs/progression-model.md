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

## Campaign schedule (GDD — enforced live since M16)

The table below is the shared source of truth: the live game seals a wave
(`WaveDirector._start_assault`) until lifetime knowledge reaches the
threshold, and the model simulates the same gate. 20 waves (the live
`WAVE_PLAN`), 1 engram/clear, barriers (protected tier appears / hard-block
wave / lifetime-knowledge threshold):

| Barrier | appears | blocks from | threshold |
| --- | ---: | ---: | ---: |
| A | 4 | 6 | 6 |
| B | 8 | 10 | 15 |
| C | 12 | 14 | 28 |
| D | 16 | 18 | 45 |

A wave is clearable iff lifetime earned ≥ every active barrier threshold
(live: a wave under its threshold is *sealed* — the attempt ends; the next
attempt carries more knowledge). The final wave additionally requires the
mech (real data since M16: the catalog's "mech" node + `MechData.BUILD_COST`).
A nuked wave is bypassed, not cleared — it awards no engram (live rule
since M16, matching the model).

## Search space

18 configurations: nuke charges 0/1/2 × respec on/off × nuke placement
(holdout 0/1/2 = walk away from the first k blocked waves instead of nuking
them — verifies the greedy placement is optimal), enumerated in a fixed
deterministic order.

Deliberately **not** varied: which research line is bought cannot change a
clear — the barriers gate on lifetime EARNED, not gear — and the purchase
policy is fixed to spend-immediately, the only timing that can help, since
the only purchase that matters is the mech chain (hoarding can only delay
it, never shorten it).

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
- Catalog depth (closed in M6): the real v1 tree is 45 engrams deep —
  exactly the wave-16 barrier threshold.

## Model limitations

1. ~~Schedule is illustrative~~ — **closed in M6/M16.** The 20-wave plan,
   barriers and thresholds are shipped data: the live game seals waves under
   their threshold, and the model reads the live `WAVE_PLAN` for the wave
   count. The probe re-verifies the reproduction on every run.
2. **Counter representation.** Barriers are modelled as threshold gates on
   lifetime knowledge. Since the barriers gate on EARNED (not gear), the
   abstract node→counter mapping does not affect the five-attempt proof;
   what a counter *does in combat* is a gameplay question the model cannot
   answer (see limitation 4).
3. **Scrap economy is illustrative** (start 6, +6/wave, lump build costs).
   Real harvest distance, deposit depletion and repair drain are not modelled.
4. **No in-run timing.** The model is a clear-level simulation: no wave
   duration, no skill ceiling, no crystal-damage races. A path the model
   calls attainable still has to be *defended* in real time.
5. ~~Mech is a parameter~~ — **closed in M16.** The model uses the real
   catalog node (`mech`, cost 3, req `r2`) and the real build cost
   (`MechData.BUILD_COST = 8`).
6. **No endless-mode or post-20 rules** (GDD §10) — out of scope for the
   five-attempt proof.
7. ~~Nuke "skip one failed wave" is the GDD reading~~ — **settled in M16.**
   The live rule is now exactly the model's reading: a nuke bypasses the
   wave, which awards no engram. The permissive (2-charge) case remains in
   the search for sensitivity only.

## Invalidation

Per the task's Important note: changing the nuke ceiling, rewards, loot-
derived research, free starting blueprints or alternate counter strength
invalidates the relevant check — re-run the probe after any such change.
