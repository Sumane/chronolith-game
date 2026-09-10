extends Node
## M13 probe: LIVE wave accounting. Runs the normal spawn path
## (PREP -> early_start -> _start_assault), NOT debug_instant_wave, so the
## roster the player actually sees is the one being counted.

var _ok := 0
var _fail := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _wait(n: int) -> void:
	var i := 0
	while i < n:
		i += 1
		await get_tree().process_frame

func check(label: String, cond: bool) -> void:
	if cond:
		_ok += 1
	else:
		_fail += 1
		print("  [FAIL] %s" % label)
	if cond:
		print("  [ok] %s" % label)

func _wipe() -> void:
	for pth in ["chronolith_v1_profile.json", "chronolith_v1_profile.json.bak", "chronolith_v1_profile.json.tmp"]:
		var gp := ProjectSettings.globalize_path("user://" + pth)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)

## Poll until the staggered live roster is complete (or the cap elapses).
## The spawn stagger is real time, so the cap is measured in real time.
func _await_roster(want: int, cap_s: float) -> int:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < cap_s:
		await _wait(10)
		if get_tree().get_nodes_in_group("enemy").size() >= want:
			break
	return get_tree().get_nodes_in_group("enemy").size()

func _kill_all(exclude_vrax: bool) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if exclude_vrax and e is Vrax:
			continue
		e.call("damage", 9999)

func _run() -> void:
	_wipe()
	var es := ResourceLoader.load("res://scenes/v1/entry.tscn") as PackedScene
	var e1 = es.instantiate()
	e1.story_enabled = false
	add_child(e1)
	await _wait(40)
	var d: Node = e1.director

	# --- normal wave 3: WAVE_PLAN[2] = 4 grunts + 1 Warden
	d.wave = 3
	d.state = d.State.PREP
	d.early_start()
	var n := await _await_roster(5, 20.0)
	check("live wave 3 spawns full roster (4 grunts + warden)", n == 5)
	check("alive budgets the Warden (5, not 4)", d.alive == 5)
	var has_warden := false
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Warden:
			has_warden = true
	check("Warden present in live wave 3", has_warden)
	var i := 0
	while i < 300 and not get_tree().get_nodes_in_group("enemy").is_empty():
		_kill_all(false)
		await _wait(10)
		i += 1
	check("wave clears through deaths", get_tree().get_nodes_in_group("enemy").is_empty())
	check("cleared wave advances the relay to wave 4", d.wave == 4 and d.state == d.State.PREP)

	# --- finale wave 20: WAVE_PLAN[19] = 14 grunts + Vrax + Golem
	d.wave = 20
	d.state = d.State.PREP
	d.early_start()
	n = await _await_roster(16, 40.0)
	check("live finale spawns full roster (14 + vrax + golem)", n == 16)
	check("alive budgets both bosses (16, not 14)", d.alive == 16)
	check("Vrax is the live finale boss", d.vrax != null and d.vrax is Vrax)
	var v: Node = d.vrax
	# --- Vrax gate: only the mech's heavy round deals damage
	v.call("damage", 300)
	check("Vrax ignores flat shots", v.hp == 400)
	v.call("damage", 300, true)
	check("Vrax ignores non-mech piercing (turret) shots", v.hp == 400)
	v.call("damage", 60, true, true)
	check("mech round damages Vrax (400 -> 340)", v.hp == 340)
	# --- the core regression: 14 grunts + golem dead must NOT end the wave
	i = 0
	while i < 600 and get_tree().get_nodes_in_group("enemy").size() > 1:
		_kill_all(true)
		await _wait(10)
		i += 1
	check("wave stays ASSAULT while Vrax lives", d.state == d.State.ASSAULT)
	check("alive counts the surviving boss (1)", d.alive == 1)
	v.call("damage", 9999, true, true)
	var i2 := 0
	while i2 < 300 and not get_tree().get_nodes_in_group("enemy").is_empty():
		await _wait(10)
		i2 += 1
	check("campaign ends only after Vrax dies (WIN)", d.state == d.State.WIN)

	e1.queue_free()
	await _wait(5)
	print("== wave_fix probe: %d ok, %d fail ==" % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
