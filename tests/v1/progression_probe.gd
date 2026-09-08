extends Node
## M4 progression probe: offline model verification, headless, no scene.
## Checks: GDD reference reproduction, exhaustive search (nuke charges 0/1/2,
## respec on/off, all holdout placements), attempts 1-4 infeasibility, nuke
## invariance, respec boundary, mech gate, catalog depth gap, JSON export.

var _ok := 0
var _fail := 0

func check(name: String, cond: bool) -> void:
	if cond:
		_ok += 1
		print("  [ok] " + name)
	else:
		_fail += 1
		print("  [FAIL] " + name)

func _ready() -> void:
	var trace_export := {}

	# 1 reference reproduction (0 nukes, no respec): must match the GDD table
	var ref := ProgressionModel.run_campaign(0, false, {"holdout": 0})
	var clears := []
	var cumul := []
	for a in ref["attempts"]:
		clears.append(int(a["result"]["cleared"]))
		cumul.append(int(a["result"]["earned_end"]))
	check("reference: attempt best clears 5/9/13/17",
		clears.size() >= 4 and clears[0] == 5 and clears[1] == 9
		and clears[2] == 13 and clears[3] == 17)
	check("reference: cumulative engrams 5/14/27/44",
		cumul[0] == 5 and cumul[1] == 14 and cumul[2] == 27 and cumul[3] == 44)
	check("reference: win on attempt 5", ref["win_attempt"] == 5)

	# 2 exhaustive search
	var sr := ProgressionModel.search()
	check("search: 18 strategy runs completed", sr["results"].size() == 18)
	var best := ProgressionModel.best_win(sr["results"])
	check("search: earliest win = attempt 5", int(best.get("earliest_attempt", 0)) == 5)

	# 3 attempts 1-4 infeasible under every strategy
	var infeasible := true
	var gaps := []
	for r in sr["results"]:
		for a in r["attempts"]:
			if int(a["attempt"]) >= 5:
				break
			var res: Dictionary = a["result"]
			if bool(res["won"]):
				infeasible = false
			var bw := int(res["blocked_wave"])
			gaps.append({
				"strategy": _tag(r), "attempt": int(a["attempt"]),
				"blocked_wave": bw,
				"earned_end": int(res["earned_end"]),
				"threshold_at_block": ProgressionModel.required_threshold(maxi(bw, 1)),
			})
	check("infeasible: no strategy wins in attempts 1-4", infeasible)

	# 4 nuke invariance: 0 / 1 / 2 charges all give earliest win 5
	var inv := true
	var by_nukes := {}
	for r in sr["results"]:
		var k := int(r["nuke_charges"])
		var ea: int = _earliest_of(r)
		by_nukes[k] = ea
		if ea != 5:
			inv = false
	check("nuke invariance: 0/1/2 charges -> earliest win 5",
		inv and by_nukes.has(0) and by_nukes.has(1) and by_nukes.has(2))

	# 5 respec boundary: full refund does not lower the earliest win;
	#    no negative balances anywhere
	var respec_same := true
	var neg_balance := false
	for r in sr["results"]:
		if bool(r["respec"]):
			var twin: Variant = _twin_without_respec(r, sr["results"])
			if twin != null and _earliest_of(r) != _earliest_of(twin):
				respec_same = false
		for a in r["attempts"]:
			if int(a["result"]["balance_end"]) < 0:
				neg_balance = true
	check("respec boundary: earliest win unchanged, no negative balances",
		respec_same and not neg_balance)

	# 6 mech gate: the winning path buys + builds the mech before wave 20.
	# Research persists across attempts (GDD), so the purchase may sit in an
	# earlier attempt; it only needs to exist before the final fight.
	var win_attempt_data: Dictionary = best["attempts"][int(best["win_attempt"]) - 1]["result"]
	var mech_trace := bool(win_attempt_data["mech_built"])
	var mech_buy_wave := -1
	for att in best["attempts"]:
		if int(att["attempt"]) > int(best["win_attempt"]):
			break
		var ar: Dictionary = att["result"]
		for p in ar["purchases"]:
			if p["id"] == "mech":
				mech_buy_wave = int(p["wave_after"])
	check("mech gate: bought before final wave and built (param %s)" % str(ProgressionModel.MECH["name"]),
		mech_trace and mech_buy_wave >= 0 and mech_buy_wave < ProgressionModel.CAMPAIGN_WAVES - 1)

	# 7 real catalog depth vs the deepest barrier
	var cat := ProgressionModel.catalog_total_cost()
	check("catalog gap: real tree depth %d < wave-16 threshold 45 (M6 expansion quantified)" % cat,
		cat < 45)

	# 8 export
	trace_export = {
		"model": "M4 progression model (GDD reference schedule + real v1 rules)",
		"reference_table": {"clears": clears, "cumulative": cumul},
		"earliest_win_by_nukes": _nukes_map(by_nukes),
		"attempt_1_4_gaps": gaps,
		"winning_strategy": _tag(best),
		"winning_trace": best["attempts"],
		"catalog_total_cost": cat,
		"mechanic_param": ProgressionModel.MECH,
	}
	var gp := ProjectSettings.globalize_path("res://docs/progression-traces.json")
	var f := FileAccess.open(gp, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(trace_export, "\t"))
		f.close()
		print("  [ok] exported " + gp)
	else:
		_fail += 1
		print("  [FAIL] export docs/progression-traces.json")

	print("== progression probe: %d ok, %d fail ==" % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

func _nukes_map(m: Dictionary) -> Dictionary:
	var out := {}
	for k in m:
		out[str(k)] = int(m[k])
	return out

func _tag(r: Dictionary) -> String:
	return "nukes=%d respec=%s holdout=%d" % [int(r["nuke_charges"]), str(r["respec"]), int(r["strategy"]["holdout"])]

func _earliest_of(r: Dictionary) -> int:
	return int(r["win_attempt"]) if int(r["win_attempt"]) > 0 else 99

func _twin_without_respec(r: Dictionary, results: Array) -> Variant:
	for t in results:
		if int(t["nuke_charges"]) == int(r["nuke_charges"]) and not bool(t["respec"]) \
				and int(t["strategy"]["holdout"]) == int(r["strategy"]["holdout"]):
			return t
	return null
