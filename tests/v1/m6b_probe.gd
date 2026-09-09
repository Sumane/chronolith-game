extends Node
## M6b probe: the twenty-wave campaign plan.
## 1. plan shape: 20 waves, 145 grunts, wardens 3/7/11/15/19/20, golems 5/10/16/20
## 2. a full campaign run (one grunt per wave, debug fast-forward) must
##    observe the schedule live and WIN exactly at wave 20
## 3. prototype mode (wave_plan = [3,4,5]) still wins at wave 3

var entry
var rig
var director
var combat
var _ok := 0
var _fail := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _wait(n: int) -> void:
	var i := 0
	while i < n:
		i += 1
		await get_tree().physics_frame

func check(label: String, cond: bool) -> void:
	if cond:
		_ok += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["ok" if cond else "FAIL", label])

func _boot_entry() -> Node:
	var es := ResourceLoader.load("res://scenes/v1/entry.tscn") as PackedScene
	var e = es.instantiate()
	e.story_enabled = false  # story beats off: probe drives the flow itself
	add_child(e)
	await _wait(40)
	return e

func _kill_enemies() -> void:
	# direct damage only: turret-grade flat shots are fully blocked by the
	# golem's armor 20, so rays alone can never finish it — pierce the
	# big enemies, flat-hit the grunts
	for _r in 6:
		var es: Array = get_tree().get_nodes_in_group("enemy")
		if es.is_empty():
			return
		for e in es:
			if e is Warden:
				e.damage(999, true)
			elif e is Golem:
				e.damage(999, true)
			else:
				e.damage(99)
		await get_tree().physics_frame

func _run() -> void:
	for pth in ["chronolith_v1_profile.json", "chronolith_v1_profile.json.bak", "chronolith_v1_profile.json.tmp"]:
		var gp := ProjectSettings.globalize_path("user://" + pth)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)

	# 1 plan shape
	var total := 0
	for w in WaveDirector.WAVE_PLAN:
		total += int(w)
	var wkeys: Array = []
	for k in WaveDirector.WARDEN_WAVES:
		wkeys.append(int(k))
	wkeys.sort()
	var gkeys: Array = []
	for k in WaveDirector.GOLEM_WAVES:
		gkeys.append(int(k))
	gkeys.sort()
	check("plan: 20 waves, 145 grunts total",
		WaveDirector.WAVE_PLAN.size() == 20 and total == 145)
	check("schedule: wardens 3/7/11/15/19/20, golems 5/10/16/20",
		wkeys == [3, 7, 11, 15, 19, 20] and gkeys == [5, 10, 16, 20])

	# 2 full campaign run (default 20-wave plan)
	entry = await _boot_entry()
	rig = entry.get_node("PlayerRig")
	director = entry.get_node("WaveDirector")
	combat = entry.get_node("Combat")
	check("campaign boots at wave 1 of 20 (default plan)",
		director.wave == 1 and director.wave_plan.size() == 20)

	var seen_warden := {}
	var seen_golem := {}
	var early_win := false
	var won := false
	for i in 20:
		var w: int = i + 1  # the director's wave counter is 1-based
		var expect_warden: bool = WaveDirector.WARDEN_WAVES.has(w)
		var expect_golem: bool = WaveDirector.GOLEM_WAVES.has(w)
		director.call("debug_instant_wave", 1)
		await _wait(20)
		var es: Array = get_tree().get_nodes_in_group("enemy")
		for e in es:
			if e is Warden:
				seen_warden[w] = true
			elif e is Golem:
				seen_golem[w] = true
		await _kill_enemies()
		await _wait(40)
		if w < 20 and director.state == WaveDirector.State.WIN:
			early_win = true
		if w == 20:
			won = director.state == WaveDirector.State.WIN
		if w < 20:
			check("wave %d cleared: warden=%s golem=%s (expected %s/%s)" % [
				w, str(seen_warden.has(w)), str(seen_golem.has(w)),
				str(expect_warden), str(expect_golem)],
				seen_warden.has(w) == expect_warden and seen_golem.has(w) == expect_golem
				and director.wave == w + 1)
		else:
			check("wave 20 cleared: warden+golem present, campaign WON" ,
				seen_warden.has(w) and seen_golem.has(w) and won)
			if won:
				get_tree().paused = false
	check("campaign: no early win before wave 20", not early_win)
	check("campaign: 20 engrams earned (fresh ledger, no research)",
		entry.knowledge.earned_total == 20)

	# 3 prototype mode still wins at wave 3
	entry.queue_free()
	await _wait(20)
	entry = await _boot_entry()
	rig = entry.get_node("PlayerRig")
	director = entry.get_node("WaveDirector")
	combat = entry.get_node("Combat")
	director.wave_plan = [3, 4, 5]
	for i in 3:
		director.call("debug_instant_wave", 1)
		await _wait(20)
		await _kill_enemies()
		await _wait(40)
	check("prototype mode: [3,4,5] still wins at wave 3 (warden on 3)",
		director.state == WaveDirector.State.WIN and director.wave == 3)
	get_tree().paused = false

	print("== M6b probe: %d ok, %d fail ==" % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
