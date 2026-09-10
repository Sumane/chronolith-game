extends Node
## M6 probe: expanded research (14 nodes, depth 45, five lines), temporal
## stasis burst, per-line effect application at build/boot, research UI
## paging, and persistence of the new effects into the next attempt.
## e1 must WIN (all 3 waves) before saving: saving a still-running attempt
## resurrects a mid-attempt checkpoint in the next boot (M5 lesson).

var entry
var rig
var director
var crystal
var arena
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

func _press_v() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_V
	e.physical_keycode = KEY_V
	e.pressed = true
	Input.parse_input_event(e)

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
	for _r in 24:
		var es: Array = get_tree().get_nodes_in_group("enemy")
		if es.is_empty():
			return
		var rover_pos: Vector3 = rig.get_node("Rover").global_position
		for e in es:
			var p: Vector3 = (e as Node3D).global_position + Vector3(0, 0.6, 0)
			combat.fire(rover_pos, p, [rig.rover_rid()])
			combat.fire(rover_pos, p, [rig.rover_rid()])
		await get_tree().physics_frame
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Warden:
			e.damage(999, true)
		else:
			e.damage(99)

func _clear_wave(w: int) -> void:
	director.call("debug_instant_wave", w)
	await _wait(20)
	await _kill_enemies()
	await _wait(40)

func _run() -> void:
	for pth in ["chronolith_v1_profile.json", "chronolith_v1_profile.json.bak", "chronolith_v1_profile.json.tmp"]:
		var gp := ProjectSettings.globalize_path("user://" + pth)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)

	# ---- attempt 1: buy the whole catalog, verify every line's effect ----
	entry = await _boot_entry()
	rig = entry.get_node("PlayerRig")
	director = entry.get_node("WaveDirector")
	arena = entry.get_node("Arena")
	crystal = arena.crystal
	combat = entry.get_node("Combat")
	director.wave_plan = [3, 4, 5]  # prototype mode: campaign is 20 waves

	# 1 catalog shape: 14 nodes, five lines, depth 45
	var total := 0
	var lines := {}
	for id in ResearchTree.ORDER:
		total += int(ResearchTree.NODES[id]["cost"])
		lines[String(ResearchTree.NODES[id]["line"])] = true
	check("catalog: 14 nodes, 5 lines, depth 45",
		ResearchTree.ORDER.size() == 14 and lines.size() == 5 and total == 45
		and lines.has("TEMPORAL"))

	# 2 ledger: fund the probe and buy everything in order
	entry.knowledge.earned_total = 50
	var all_ok := true
	for id in ResearchTree.ORDER:
		var res: Dictionary = entry.knowledge.research(id)
		if not bool(res.get("ok", false)):
			all_ok = false
			print("  diag research fail: %s %s" % [id, str(res)])
	check("ledger: full catalog researched (spent 45, balance 5)",
		all_ok and entry.knowledge.spent_total == 45 and entry.knowledge.balance() == 5)

	# 3 mech wallet gate: cargo 6 < 8 scrap -> transform refused
	entry._try_transform_mech()
	check("mech: transform refused with 6/8 cargo", not rig.mech_mode)

	# 4 turret build: t1+t4 damage, t2+t4 cooldown, t3 range
	entry.build.start_build("turret")
	rig.debug_set_aim(Vector3(5.5, arena.height_at(5.5, 3.5) + 0.3, 3.5))
	var tr: Dictionary = entry.build.commit()
	check("turret route: dmg 25, cd 0.25, range 12 (t1+t4, t2+t4, t3)",
		bool(tr.get("ok", false))
		and absf(float(tr["building"].cooldown) - 0.25) < 0.001
		and int(tr["building"].dmg) == 25
		and absf(float(tr["building"].range_m) - 12.0) < 0.001)

	# 5 fort build: f1 wall hp
	entry.build.start_build("wall")
	rig.debug_set_aim(Vector3(3.5, arena.height_at(3.5, 5.5) + 0.3, 5.5))
	var wl: Dictionary = entry.build.commit()
	check("fort route: wall hp 90 (f1)",
		bool(wl.get("ok", false)) and int(wl["building"].max_hp) == 90)

	# 6 temporal: stasis burst (x1+x2 -> min factor 0.5, 5 s, 10 s cd)
	entry._try_time_burst()
	var tw = arena.get_node("TimeWarp")
	await _wait(2)
	check("temporal: burst active (factor 0.5, dur 5, cd 10)",
		tw.active() and absf(tw.factor() - 0.5) < 0.001
		and absf(tw._dur - 5.0) < 0.001 and absf(tw._cooldown - 10.0) < 0.001)
	var again: bool = entry.time.burst(0.5, 5.0, 10.0)
	check("temporal: recharge blocks an immediate second burst", again == false)

	# 7 temporal: slowed enemies actually move slower
	director.call("debug_instant_wave", 1)
	await _wait(15)
	var es: Array = get_tree().get_nodes_in_group("enemy")
	var g0 = es[0]
	var p0: Vector3 = (g0 as Node3D).global_position
	await _wait(40)
	# horizontal only: edge spawns can be mid-fall, and the vertical
	# component would inflate the speed reading
	var pa: Vector3 = p0
	pa.y = 0.0
	var pb: Vector3 = (g0 as Node3D).global_position
	pb.y = 0.0
	var moved: float = pa.distance_to(pb)
	print("  diag stasis: count=%d moved=%.2f factor=%s" % [es.size(), moved, str(tw.factor())])
	# debug_instant_wave(n) spawns exactly n grunts, so 1 here
	check("temporal: grunt crawls under stasis (0.67 s moved < 1.6 m)",
		es.size() == 1 and moved < 1.6)
	await _kill_enemies()
	await _clear_wave(2)
	await _clear_wave(3)
	get_tree().paused = false  # WIN paused the tree; unpause only (M5 lesson)
	await _wait(10)

	# 8 UI paging: page 1 = turret/fort, page 2 = rover/temporal/mech
	var screen = entry.get_node("ResearchScreen")
	screen.show_screen()
	var p1: bool = bool(screen._rows["t1"]["row"].visible) and not bool(screen._rows["mech"]["row"].visible)
	screen._flip_page()
	var p2: bool = bool(screen._rows["mech"]["row"].visible) and not bool(screen._rows["t1"]["row"].visible)
	var key_ok: bool = (screen._rows["mech"]["key"].text == "[7]") and (screen._rows["r1"]["key"].text == "[1]")
	screen._flip_page()
	screen._close()
	check("research UI: two pages of 7, P flips, keys relabel",
		p1 and p2 and key_ok and screen._page == 0)
	entry._save_profile()

	# ---- attempt 2: persisted effects re-apply on the next boot ----
	entry.queue_free()
	await _wait(20)
	entry = await _boot_entry()
	rig = entry.get_node("PlayerRig")
	arena = entry.get_node("Arena")
	crystal = arena.crystal
	check("persist: crystal starts shielded (75/75) from f3",
		crystal.integrity == 75 and crystal.max_integrity == 75)
	check("persist: crystal shield is reset state (f3), rover body at base (M18: deploy in-run)",
		crystal.integrity == 75 and crystal.max_integrity == 75
		and rig.max_hp == 100
		and absf(rig.speed - 9.0) < 0.01
		and absf(rig._ram_recharge - 0.0) < 0.001
		and absf(rig._harvest_radius - 2.6) < 0.001)
	entry.build.start_build("turret")
	rig.debug_set_aim(Vector3(5.5, arena.height_at(5.5, 3.5) + 0.3, 3.5))
	var tr2: Dictionary = entry.build.commit()
	check("persist: turret built with full turret line (dmg 25 / cd 0.25 / range 12)",
		bool(tr2.get("ok", false)) and int(tr2["building"].dmg) == 25
		and absf(float(tr2["building"].cooldown) - 0.25) < 0.001
		and absf(float(tr2["building"].range_m) - 12.0) < 0.001)
	# rover line: M18 — deploy the researched ROVER nodes in-run (V, real
	# input path) and verify the manufactured stats, then one real harvest
	# at the enlarged radius; the transform is funded directly (deposits are
	# single-use and four cannot bridge 2 -> 8 scrap in a probe)
	entry.cargo = 13
	for _d in 4:
		_press_v()
		await _wait(3)
	check("rover line: 4 deployments (13 cargo) -> hp 150 / speed 10.5 / ram 1.0 / harvest 4.1",
		entry.cargo == 0
		and entry.deployed_rover == ["r1", "r2", "r3", "r4"]
		and rig.max_hp == 150
		and absf(rig.speed - 10.5) < 0.01
		and absf(rig._ram_recharge - 1.0) < 0.001
		and absf(rig._harvest_radius - 4.1) < 0.001)
	rig.debug_set_pos(Vector3(7.2, arena.height_at(7.2, 4.0) + 0.3, 4.0))
	var c0: int = entry.cargo
	rig.debug_interact(0.9)
	await _wait(80)
	var c1: int = entry.cargo
	check("rover line: harvest works at the deployed 4.1 m radius",
		c1 == c0 + 1)
	entry.cargo = 8
	entry._try_transform_mech()
	print("  diag mech: mode=%s hp=%d mech_res=%s" % [
		str(rig.mech_mode), rig.hp, str(entry.knowledge.researched.has("mech"))])
	check("mech route: persisted chassis -> transform (cargo 8, hp 250)",
		rig.mech_mode and rig.hp == MechData.MAX_HP)

	print("== M6 probe: %d ok, %d fail ==" % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
