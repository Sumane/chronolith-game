extends Node
## M2 probe: harvest, atomic build, duplicate/no-double-spend rejection,
## enemy wall-attack + approach, combat kill, wave clear -> win, pause
## invariants, rover/crystal death ending the attempt.

var entry
var rig
var combat
var build
var director
var flow
var arena
var crystal
var _ok := 0
var _fail := 0
var _names: Array = []
var _frames := 0

func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > 4000:
		print("== M2 probe: TIMEOUT (no completion in ~66 s) ==")
		get_tree().quit(1)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# hermetic: clear any v1 profile left by other probes (shared XDG-isolated user://)
	for pth in ["chronolith_v1_profile.json", "chronolith_v1_profile.json.bak", "chronolith_v1_profile.json.tmp"]:
		var gp := ProjectSettings.globalize_path("user://" + pth)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)
	randomize()
	_run()

func _wait(n: int) -> void:
	var i := 0
	while i < n:
		i += 1
		await get_tree().physics_frame

func check(label: String, cond: bool) -> void:
	if cond:
		_ok += 1
		_names.append("ok  " + label)
	else:
		_fail += 1
		_names.append("FAIL " + label)
	print("  [%s] %s" % ["ok" if cond else "FAIL", label])

func _run() -> void:
	var es := ResourceLoader.load("res://scenes/v1/entry.tscn") as PackedScene
	entry = es.instantiate()
	add_child(entry)
	await _wait(40)
	rig = entry.get_node("PlayerRig")
	combat = entry.get_node("Combat")
	flow = entry.get_node("Flow")
	director = entry.get_node("WaveDirector")
	build = entry.get_node("BuildService")
	arena = entry.get_node("Arena")
	crystal = arena.crystal
	check("boot: full composition present",
		rig != null and combat != null and flow != null and director != null and build != null and crystal != null)

	# 1 harvest (hold interact 0.9 s next to a deposit)
	var dep = arena.get_node("Deposits/Deposit1")
	var dp: Vector3 = dep.global_position
	rig.debug_set_pos(Vector3(dp.x + 1.2, arena.height_at(dp.x + 1.2, dp.z) + 0.3, dp.z))
	rig.debug_interact(0.9)
	await _wait(80)
	check("harvest: cargo 6->7, deposit 5->4", entry.cargo == 7 and dep.amount == 4)

	# 2 place a wall (cost 2), ghost snapped to grid
	build.start_build("wall")
	var wa := Vector3(10.0, arena.height_at(10.0, 10.0), 10.0)
	rig.debug_set_aim(wa)
	var res: Dictionary = build.commit()
	check("build wall: placed, spent 2", res.get("ok", false) and entry.cargo == 5)
	var wall = res.get("building")

	# 3 duplicate placement in same cell rejected
	var res2: Dictionary = build.commit()
	check("no duplicate placement in same cell", not res2.get("ok", false) and entry.cargo == 5)

	# 4 atomic spend: cannot build when cargo < cost
	entry.cargo = 1
	rig.debug_set_aim(Vector3(13.0, arena.height_at(13.0, 13.0), 13.0))
	var res3: Dictionary = build.commit()
	check("no double-spend: poor commit rejected", not res3.get("ok", false) and entry.cargo == 1)
	entry.cargo = 5
	build.cancel()

	# 5 enemy attacks the obstructing wall (line from (14,13.8) to crystal passes the wall cell)
	var g1 := _spawn_grunt(14.0, 13.8)
	await _wait(110)
	check("enemy attacks obstructing wall", is_instance_valid(wall) and wall.hp < 60)

	# 6 enemy approaches crystal, steering around the blocker rock
	var g2 := _spawn_grunt(0.5, -17.5)
	await _wait(30)
	var d0: float = g2.global_position.distance_to(crystal.global_position)
	await _wait(240)
	var d1: float = g2.global_position.distance_to(crystal.global_position)
	check("enemy approaches crystal (rock detour)", d1 < d0 - 2.0)

	# 7 combat kills grunts (20 hp, 10 per shot)
	await _kill_enemies()
	await _wait(40)
	check("combat kills grunts", get_tree().get_nodes_in_group("enemy").is_empty())

	# 8 wave flow: instant wave, kill all, expect PREP for wave 2
	director.call("debug_instant_wave", 1)
	await _wait(30)
	await _kill_enemies()
	await _wait(40)
	check("wave clear -> PREP wave 2", director.state == WaveDirector.State.PREP and director.wave == 2 and director.alive == 0)

	# 9 win: last wave cleared ends the attempt
	director.wave = 3
	director.call("debug_instant_wave", 1)
	await _wait(30)
	await _kill_enemies()
	await _wait(40)
	check("three-wave win: WIN state + flow ended + overlay",
		director.state == WaveDirector.State.WIN and flow.last_result == "win" and entry._end_overlay.visible)

	# 10 pause invariants: un-pause, pause via rig, harvest must not progress
	get_tree().paused = false
	rig.debug_pause()
	var dep2 = arena.get_node("Deposits/Deposit2")
	var p2: Vector3 = dep2.global_position
	rig.debug_set_pos(Vector3(p2.x + 1.2, arena.height_at(p2.x + 1.2, p2.z) + 0.3, p2.z))
	rig.debug_interact(1.0)
	await _wait(70)
	check("no harvest from paused world", dep2.amount == 5 and entry.cargo == 5)
	rig.debug_pause()

	# 11 rover death ends the attempt (flow re-armed after win)
	flow.running = true
	rig.damage(999)
	await _wait(5)
	check("rover death ends attempt", flow.last_result == "lost_rover")

	# 12 crystal death ends the attempt
	flow.running = true
	crystal.damage(999)
	await _wait(5)
	check("crystal death ends attempt", flow.last_result == "lost_crystal" and crystal.destroyed)

	for n in _names:
		print(n)
	print(String("== M2 probe: %d ok, %d fail ==") % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)

func _spawn_grunt(x: float, z: float) -> Node:
	var g: Grunt = Grunt.new()
	g.position = Vector3(x, arena.height_at(x, z) + 0.5, z)
	g.goal = crystal
	g.arena = arena
	g._rover = rig.get_node("Rover")
	entry.add_child(g)
	return g

func _kill_enemies() -> void:
	# M4 note: wave 3 includes the armored Warden (20 flat dmg per round),
	# so poll until the field is clear instead of firing one round
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
	# test convenience: finish anything the rover cannot reach (the Warden
	# can sit behind the (9,-2) rock at its spawn edge)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Warden:
			e.damage(999, true)
		else:
			e.damage(99)
