extends Node
## M8 probe: endless continuation and release hardening.
## 1. the victorious state continues into non-canonical wave 21+
## 2. endless waves advance past the campaign with bounded spawns and
##    no Vrax respawn
## 3. headless performance envelope at the spawn bound
## 4. pause freezes enemy state and resumes it cleanly
## 5. endless defeat is separated from the campaign: completion stays,
##    the finale never replays, C does not restart endless from a loss

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
	print("  [%s] %s" % ["ok" if cond else "FAIL", label])

func _wipe() -> void:
	for pth in ["chronolith_v1_profile.json", "chronolith_v1_profile.json.bak", "chronolith_v1_profile.json.tmp"]:
		var gp := ProjectSettings.globalize_path("user://" + pth)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)

func _profile() -> Dictionary:
	var gp := ProjectSettings.globalize_path("user://chronolith_v1_profile.json")
	if not FileAccess.file_exists(gp):
		return {}
	var t := FileAccess.get_file_as_string(gp)
	var j: Variant = JSON.parse_string(t)
	return j if j is Dictionary else {}

func _kill_all(with_mech_vrax: bool) -> void:
	for _r in 12:
		var es: Array = get_tree().get_nodes_in_group("enemy")
		if es.is_empty():
			return
		for e in es:
			if e is Vrax:
				e.damage(999, true, with_mech_vrax)
			elif e is Golem:
				e.damage(999, true)
			elif e is Warden:
				e.damage(999, true)
			else:
				e.damage(99)
		await get_tree().process_frame

func _run() -> void:
	_wipe()
	var es := ResourceLoader.load("res://scenes/v1/entry.tscn") as PackedScene
	var e1 = es.instantiate()
	e1.story_enabled = false
	add_child(e1)
	await _wait(40)
	var d: Node = e1.get_node("WaveDirector")
	var crystal: Node = e1.get_node("Arena").get_node("Chronolith")

	# 1 continue after the campaign win
	d.wave = 20
	d.call("debug_instant_wave", 0)  # Vrax + Golem, no grunts
	await _wait(4)
	await _kill_all(true)
	await _wait(10)
	var paused_now := get_tree().paused
	check("e1: campaign win before endless (tree paused on the end screen)",
		e1._last_win_was_full and paused_now)
	e1.call("_start_endless")
	await _wait(10)
	check("e1: endless continues into wave 21 (flow running, tree live)",
		e1.flow.running and d.endless and d.wave == 21 and not get_tree().paused)
	check("e1: HUD reads ENDLESS", e1.hud.wave_label.text.contains("ENDLESS"))

	# 2 endless waves advance with bounded spawns, no Vrax
	d.call("debug_instant_wave", 5)  # wave 21
	await _wait(4)
	var es21: Array = get_tree().get_nodes_in_group("enemy")
	check("e1: wave 21 has 5 grunts", es21.size() == 5)
	await _kill_all(true)
	await _wait(6)
	check("e1: relay advances past the campaign (wave 22)", d.wave == 22)
	check("e1: endless engram granted for wave 21",
		e1.hud.banner_label.text.contains("WAVE 21 CLEARED"))

	d.wave = 23
	d.call("debug_instant_wave", 5)  # 23 % 3 == 2 -> a Warden, never Vrax
	await _wait(4)
	var es23: Array = get_tree().get_nodes_in_group("enemy")
	var has_plain_warden := false
	var has_vrax := false
	for e in es23:
		if e is Vrax:
			has_vrax = true
		elif e is Warden:
			has_plain_warden = true
	check("e1: wave 23 adds a Warden (5 grunts + 1)", es23.size() == 6 and has_plain_warden)
	check("e1: Vrax never respawns in endless", not has_vrax)
	await _kill_all(true)
	await _wait(6)

	# 3 spawn bound + headless performance envelope at the bound
	d.wave = 24
	d.call("debug_instant_wave", 30)  # spawn bound
	await _wait(4)
	var es24: Array = get_tree().get_nodes_in_group("enemy")
	var kinds := {}
	for e in es24:
		var k := "grunt"
		if e is Vrax:
			k = "vrax"
		elif e is Golem:
			k = "golem"
		elif e is Warden:
			k = "warden"
		kinds[k] = int(kinds.get(k, 0)) + 1
	check("e1: spawn bound caps the field (30 requested, 22 alive) got %s %s" % [es24.size(), str(kinds)], es24.size() == 22)
	var t0 := Time.get_ticks_usec()
	await _wait(250)
	var ms_frame: float = float(Time.get_ticks_usec() - t0) / 1000.0 / 250.0
	check("envelope: %d headless frames at the spawn bound, %.2f ms/frame" % [250, ms_frame],
		ms_frame < 20.0)
	await _kill_all(true)
	await _wait(6)

	# 4 pause freezes and resumes enemy state
	d.call("debug_instant_wave", 5)  # wave 25: %5 == 0 -> golem
	await _wait(4)
	var es25: Array = get_tree().get_nodes_in_group("enemy")
	check("e1: wave 25 has 5 grunts + golem", es25.size() == 6)
	var mover: Node = es25[0]
	e1.nuke_charge = 2
	await _wait(20)
	var p0: Vector3 = (mover as Node3D).global_position
	get_tree().paused = true
	await _wait(40)
	var p1: Vector3 = (mover as Node3D).global_position
	check("e1: pause freezes enemy state (40 frames, zero movement)", p0.distance_to(p1) < 0.001)
	check("e1: nuke charges frozen while paused", e1.nuke_charge == 2)
	get_tree().paused = false
	await _wait(20)
	var p2: Vector3 = (mover as Node3D).global_position
	check("e1: resume restores movement", p1.distance_to(p2) > 0.001)

	# 5 endless defeat is separated from the campaign
	crystal.damage(9999)
	await _wait(30)
	check("e1: endless defeat ends the run (campaign intact label)",
		e1._end_label.text.contains("ENDLESS RUN ENDED") and e1._end_label.text.contains("REMAINS COMPLETE"))
	check("e1: completion survives the endless defeat",
		_profile().get("story_flags", {}).get("completion", false))
	check("e1: C does not restart endless from a loss screen", not e1._last_win_was_full)
	e1.call("_start_endless")
	await _wait(4)
	check("e1: endless restart from a loss is refused", not e1.flow.running)
	check("e1: R offers a fresh attempt", e1._end_label.text.contains("R — new attempt"))
	e1.queue_free()
	await _wait(10)

	print("== M8 probe: %d ok, %d fail ==" % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
