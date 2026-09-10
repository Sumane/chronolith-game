extends Node
## M4/M16 progression probe: offline model verification + LIVE enforcement.
## Offline: GDD reference reproduction, 18-configuration strategy search,
## attempts 1-4 infeasibility, nuke invariance, respec boundary, mech gate,
## catalog depth, JSON export, real-data wiring (campaign length, mech node).
## Live (M16): the barrier schedule seals waves under the threshold (flow
## result "sealed"), and a nuked wave is bypassed without an engram.

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
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _wait(n: int) -> void:
	var i := 0
	while i < n:
		i += 1
		await get_tree().process_frame

## Real-time wait (headless frames are not a reliable 1/60 s).
func _wait_s(sec: float) -> void:
	await (get_tree().create_timer(sec)).timeout

func _wipe() -> void:
	for pth in ["chronolith_v1_profile.json", "chronolith_v1_profile.json.bak", "chronolith_v1_profile.json.tmp"]:
		var gp := ProjectSettings.globalize_path("user://" + pth)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)

func _run() -> void:
	# ---------------------------------------------------------- offline ------
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

	# strategy search (18 configurations: nukes x respec x holdout)
	var sr := ProgressionModel.search()
	check("search: 18 strategy configurations completed", sr["results"].size() == 18)
	var best := ProgressionModel.best_win(sr["results"])
	check("search: earliest win = attempt 5", int(best.get("earliest_attempt", 0)) == 5)

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
	check("mech gate: bought before final wave and built (real node %s)" % str(ProgressionModel.mech_node().get("name", "?")),
		mech_trace and mech_buy_wave >= 0 and mech_buy_wave < ProgressionModel.campaign_waves() - 1)

	var cat := ProgressionModel.catalog_total_cost()
	check("catalog depth: real tree %d >= wave-16 threshold 45 (M6: gap closed)" % cat,
		cat >= 45)

	# M16: the model is wired to real gameplay data, not model-local constants
	check("real data: campaign length = live WAVE_PLAN (%d)" % ProgressionModel.campaign_waves(),
		ProgressionModel.campaign_waves() == int(WaveDirector.WAVE_PLAN.size()) and ProgressionModel.campaign_waves() == 20)
	var mn: Dictionary = ProgressionModel.mech_node()
	check("real data: mech = catalog node (cost 3, req r2) + real build cost 8",
		int(mn.get("cost", -1)) == 3 and mn.get("req", []) == ["r2"]
		and ProgressionModel.mech_build_cost() == MechData.BUILD_COST and ProgressionModel.mech_build_cost() == 8)

	var trace_export := {
		"model": "M4 progression model (GDD barrier schedule enforced live, M16 + real v1 data)",
		"reference_table": {"clears": clears, "cumulative": cumul},
		"earliest_win_by_nukes": _nukes_map(by_nukes),
		"attempt_1_4_gaps": gaps,
		"winning_strategy": _tag(best),
		"winning_trace": best["attempts"],
		"catalog_total_cost": cat,
		"mech_node": mn,
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

	# ------------------------------------------------------- live (M16) ------
	_wipe()
	var es := ResourceLoader.load("res://scenes/v1/entry.tscn") as PackedScene
	var e1 = es.instantiate()
	e1.story_enabled = false
	add_child(e1)
	await _wait(40)
	var d: Node = e1.director
	var k: Knowledge = e1.knowledge

	# live wave 1: a nuked wave is bypassed — no engram
	d.wave = 1
	d.state = d.State.PREP
	d.early_start()
	await _wait_s(2.0)
	check("live: wave 1 assault running", d.state == d.State.ASSAULT and get_tree().get_nodes_in_group("enemy").size() == 3)
	e1._fire_nuke()
	await _wait_s(2.5)  # death timers + relay
	check("live: nuked wave bypassed WITHOUT engram", int(k.earned_total) == 0 and d.state == d.State.PREP and d.wave == 2)

	# live wave 2: a normal clear still awards the engram
	d.early_start()
	await _wait_s(2.0)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.call("damage", 9999)
	await _wait_s(2.5)
	check("live: normal clear awards the engram", int(k.earned_total) == 1 and d.state == d.State.PREP and d.wave == 3)

	# live seal: wave 6 sits under barrier A (threshold 6); nothing carried
	d.wave = 6
	d.state = d.State.PREP
	d.prep_left = d.PREP_TIME
	d.early_start()
	await _wait(4)
	check("live: wave 6 sealed below the threshold (no assault, no spawn)",
		d.state == d.State.BLOCKED and get_tree().get_nodes_in_group("enemy").is_empty())
	check("live: sealed wave ends the attempt (flow result sealed)",
		e1.flow.last_result == "sealed" and not e1.flow.running)
	# probe re-arm: the end overlay paused the tree
	get_tree().paused = false
	e1.flow.running = true
	check("live: sealed wave awarded no engram", int(k.earned_total) == 1)

	# live threshold pass: carrying the threshold opens the same wave
	k.earned_total = 6
	d.wave = 6
	d.state = d.State.PREP
	d.prep_left = d.PREP_TIME
	d.early_start()
	await _wait_s(3.5)  # 4 grunts stagger to 2.4 s — window must clear the last spawn
	check("live: wave 6 opens at threshold 6 (assault with 4 grunts)",
		d.state == d.State.ASSAULT and get_tree().get_nodes_in_group("enemy").size() == 4)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.call("damage", 9999)
	await _wait_s(2.5)

	e1.queue_free()
	await _wait(5)
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
