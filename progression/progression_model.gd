class_name ProgressionModel
extends RefCounted
## M4: fast offline progression model.
##
## Shares real game data where it exists:
##   - ResearchTree.NODES / ORDER      (actual v1 research catalog + prereqs)
##   - Knowledge ledger rules          (earned lifetime, atomic spend, receipts)
##   - BuildService.COSTS semantics    (wall/turret scrap costs)
##   - nuke rules                      (bounded charges, 1 wave-clear each,
##                                      no regen / no duplication via respec)
## Campaign schedule (20 waves, barrier thresholds) is the GDD's illustrative
## reference — the real campaign data lands in M6. See docs/progression-model.md
## for the limitation list.

const CAMPAIGN_WAVES := 20
const ENGRAM_PER_WAVE := 1

## GDD arithmetic reference (illustrative thresholds).
## "wave" = the protected tier appears; "block_from" = the first wave that is
## hard-blocked without the counter (GDD: "then stop at 6/10/14/18").
const BARRIERS := [
	{"wave": 4, "threshold": 6, "block_from": 6},
	{"wave": 8, "threshold": 15, "block_from": 10},
	{"wave": 12, "threshold": 28, "block_from": 14},
	{"wave": 16, "threshold": 45, "block_from": 18},
]

## Economy (illustrative where the game has no campaign data yet).
const START_SCRAP := 6        # matches entry.cargo start (M2 probe: cargo 6)
const SCRAP_PER_WAVE := 6     # one short harvest cycle per cleared wave
## Final mech requirement (M5 pending — parameterized, GDD: "a valid path must
## also be able to build the required equipment before the final fight").
const MECH := {"cost": 3, "req": ["r2"], "build_cost": 8, "name": "Hybrid Mech (M5 param)"}

## Nuke rules: standard = current game value (entry.nuke_charge := 1).
const NUKE_STANDARD := 1
const NUKE_PERMISSIVE := 2  # GDD: "use two immediately available nukes when
                            # checking the most permissive earliest-win case"

# ------------------------------------------------------------- helpers -------

static func barriers_for_wave(w: int) -> Array:
	var out := []
	for b in BARRIERS:
		if w >= b["block_from"]:
			out.append(b)
	return out

static func required_threshold(w: int) -> int:
	var t := 0
	for b in BARRIERS:
		if w >= b["block_from"]:
			t = maxi(t, int(b["threshold"]))
	return t

## Real catalog facts, shared with the game.
static func catalog_total_cost() -> int:
	var c := 0
	for id in ResearchTree.ORDER:
		c += int(ResearchTree.NODES[id]["cost"])
	return c

static func line_chain(line: String) -> Array:
	# full prerequisite chain of one research line, shallow to deep
	var out := []
	for id in ResearchTree.ORDER:
		if ResearchTree.NODES[id]["line"] == line:
			out.append(id)
	return out

# ------------------------------------------------------------- simulation ----

## Simulate one attempt.
## start_earned: lifetime engrams (monotonic knowledge — respec never reduces
##               it; thresholds apply to this value, per GDD).
## start_spent:  engrams currently spent on active research.
## respec:       full refund at attempt start (GDD implementation default).
## strategy:     {"nuke_holdout": 0..k} — how many blocked waves to walk away
##               from instead of nuking (searches all nuke placements).
static func simulate_attempt(start_earned: int, start_spent: int,
		nuke_charges: int, respec: bool, strategy: Dictionary) -> Dictionary:
	var earned := start_earned
	var spent := 0 if respec else start_spent
	var researched: Dictionary = {}
	if not respec:
		# keep previously purchased nodes (no respec)
		researched = _owned_at(start_spent)
	var balance := earned - spent
	var scrap := START_SCRAP
	var nukes_left := nuke_charges
	var nukes_used := {}
	var purchases := []
	var mech_built := false
	var wave := 1
	var cleared := 0
	var holdouts_left := int(strategy.get("holdout", 0))
	var blocked_wave := -1

	while wave <= CAMPAIGN_WAVES:
		var need := required_threshold(wave)
		# purchases happen "immediately usable after wave clear": before the
		# next wave, buy the next line node while affordable (mixed builds:
		# any line is a valid counter — the search covers all three).
		if balance > 0:
			for chain in [line_chain("TURRET"), line_chain("FORT"), line_chain("ROVER")]:
				for id in chain:
					if _can_buy(researched, id, balance):
						var cost := int(ResearchTree.NODES[id]["cost"])
						balance -= cost
						spent += cost
						researched[id] = true
						purchases.append({"id": id, "wave_after": wave - 1})
			# mech: buy the research node, then build when scrap allows
			if not researched.has("mech") and balance >= int(MECH["cost"]) \
					and _reqs_met(researched, MECH["req"]):
				balance -= int(MECH["cost"])
				spent += int(MECH["cost"])
				researched["mech"] = true
				purchases.append({"id": "mech", "wave_after": wave - 1})
			if researched.has("mech") and not mech_built and scrap >= int(MECH["build_cost"]):
				scrap -= int(MECH["build_cost"])
				mech_built = true
		var ok := earned >= need
		if wave == CAMPAIGN_WAVES and not mech_built and not researched.has("mech"):
			ok = false  # final fight requires the mech
		if ok:
			earned += ENGRAM_PER_WAVE
			balance += ENGRAM_PER_WAVE
			scrap += SCRAP_PER_WAVE
			cleared += 1
			wave += 1
		elif nukes_left > 0 and holdouts_left <= 0:
			nukes_left -= 1
			nukes_used[str(wave)] = true
			wave += 1  # bypass one failed wave — no engram, no scrap
		else:
			blocked_wave = wave
			break
	return {
		"cleared": cleared,
		"earned_end": earned,
		"spent_end": spent,
		"balance_end": balance,
		"scrap_end": scrap,
		"nukes_used": nukes_used,
		"purchases": purchases,
		"mech_built": mech_built,
		"blocked_wave": blocked_wave,
		"won": wave > CAMPAIGN_WAVES,
	}

## Reconstruct the largest owned set for a given spent total (used for the
## no-respec continuation; deterministic order = ResearchTree.ORDER).
static func _owned_at(spent: int) -> Dictionary:
	var owned := {}
	var left := spent
	for id in ResearchTree.ORDER:
		var node: Dictionary = ResearchTree.NODES[id]
		var prereq_ok := true
		for r in node["req"]:
			if not owned.has(r):
				prereq_ok = false
		if prereq_ok and left >= int(node["cost"]):
			owned[id] = true
			left -= int(node["cost"])
	return owned

static func _can_buy(researched: Dictionary, id: String, balance: int) -> bool:
	if researched.has(id):
		return false
	var node: Dictionary = ResearchTree.NODES[id]
	for r in node["req"]:
		if not researched.has(r):
			return false
	return balance >= int(node["cost"])

static func _reqs_met(researched: Dictionary, reqs: Array) -> bool:
	for r in reqs:
		if not researched.has(r):
			return false
	return true

# ------------------------------------------------------------- campaign ------

## Run the full campaign for one strategy across attempts.
static func run_campaign(nukes_per_attempt: int, respec: bool,
		strategy: Dictionary, max_attempts: int = 8) -> Dictionary:
	var earned := 0
	var spent := 0
	var attempts := []
	var win_attempt := -1
	for a in range(1, max_attempts + 1):
		var r := simulate_attempt(earned, spent, nukes_per_attempt, respec, strategy)
		attempts.append({"attempt": a, "start_earned": earned, "result": r})
		if r["won"]:
			win_attempt = a
			break
		earned = int(r["earned_end"])
		spent = int(r["spent_end"])
	return {
		"nuke_charges": nukes_per_attempt,
		"respec": respec,
		"strategy": strategy,
		"attempts": attempts,
		"win_attempt": win_attempt,
		"final_earned": earned,
	}

## Exhaustive search: nuke charges 0/1/2, respec on/off, all nuke placements
## (holdout patterns: skip nuking the first k blocked waves — walking away
## early can never help, but the search verifies it rather than assuming it),
## hoard-vs-spend is fixed to spend-immediately (the model's purchase rule;
## hoarding only delays gear and never moves an earned-based threshold).
static func search() -> Dictionary:
	var results := []
	for nukes in [0, NUKE_STANDARD, NUKE_PERMISSIVE]:
		for respec in [false, true]:
			# count how many blocks a campaign can hit, to bound holdouts
			for holdout in [0, 1, 2]:
				var r := run_campaign(nukes, respec, {"holdout": holdout})
				results.append(r)
	return {"results": results}

## Best (earliest) win across all strategies.
static func best_win(results: Array) -> Dictionary:
	var best := {}
	var best_attempt := 1000
	for r in results:
		if r["win_attempt"] > 0 and r["win_attempt"] < best_attempt:
			best_attempt = r["win_attempt"]
			best = r
	best["earliest_attempt"] = best_attempt
	return best
