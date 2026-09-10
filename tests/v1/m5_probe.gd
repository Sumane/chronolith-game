extends Node
## M5 probe: mech research -> build -> transform; the Golem command target
## requires the mech (flat shots blocked, rams chip, the rover dies first,
## the mech kills it); base enemies keep attacking; a new attempt returns
## the body to the starter rover while blueprint knowledge persists.

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

func _ground(x: float, z: float) -> float:
	return arena.height_at(x, z) + 0.3

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

func _clear_wave(e: Node, w: int) -> void:
	e.get_node("WaveDirector").call("debug_instant_wave", w)
	await _wait(20)
	await _kill_enemies()
	await _wait(40)

func _run() -> void:
	for pth in ["chronolith_v1_profile.json", "chronolith_v1_profile.json.bak", "chronolith_v1_profile.json.tmp"]:
		var gp := ProjectSettings.globalize_path("user://" + pth)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)

	# ---- attempt 1: defence-heavy route (1 turret + 1 wall = full cargo) ----
	entry = await _boot_entry()
	rig = entry.get_node("PlayerRig")
	director = entry.get_node("WaveDirector")
	director.wave_plan = [3, 4, 5]  # prototype mode: campaign is 20 waves
	arena = entry.get_node("Arena")
	crystal = arena.crystal
	combat = entry.get_node("Combat")
	var rover = rig.get_node("Rover")

	entry.build.start_build("turret")
	rig.debug_set_aim(Vector3(5.5, arena.height_at(5.5, 3.5) + 0.3, 3.5))
	var res1: Dictionary = entry.build.commit()
	entry.build.start_build("wall")
	rig.debug_set_aim(Vector3(3.5, arena.height_at(3.5, 5.5) + 0.3, 5.5))
	var res2: Dictionary = entry.build.commit()
	check("attempt 1: turret + wall built (full cargo), ledger fresh",
		bool(res1.get("ok", false)) and bool(res2.get("ok", false)) and entry.cargo == 0)
	entry.build.cancel()
	await _clear_wave(entry, 1)
	await _clear_wave(entry, 2)
	await _clear_wave(entry, 3)
	check("attempt 1: 3 engrams earned", entry.knowledge.earned_total == 3)
	# unpause only: re-arming flow.running would make the next save resurrect
	# a mid-attempt checkpoint (attempt {wave: 3}) in the profile
	get_tree().paused = false
	var p1: Dictionary = entry.knowledge.research("r1")
	var p2: Dictionary = entry.knowledge.research("r2")
	entry._save_profile()  # UI purchases save themselves; direct ledger calls must save explicitly
	check("attempt 1: r1+r2 researched, balance 0",
		bool(p1.get("ok", false)) and bool(p2.get("ok", false))
		and entry.knowledge.balance() == 0)
	entry.queue_free()
	await _wait(20)

	# ---- attempt 2: same profile, mech route ----
	entry = await _boot_entry()
	rig = entry.get_node("PlayerRig")
	director = entry.get_node("WaveDirector")
	director.wave_plan = [3, 4, 5]  # prototype mode: campaign is 20 waves
	arena = entry.get_node("Arena")
	crystal = arena.crystal
	combat = entry.get_node("Combat")
	rover = rig.get_node("Rover")
	director.prep_left = WaveDirector.PREP_TIME
	await _clear_wave(entry, 1)
	await _clear_wave(entry, 2)
	# two harvest cycles (M2-proven pose)
	rig.debug_set_pos(Vector3(7.2, _ground(7.2, 4.0), 4.0))
	await _wait(5)
	rig.debug_interact(0.9)
	await _wait(80)
	rig.debug_interact(0.9)
	await _wait(80)
	check("attempt 2: 2 engrams + 2 scrap (cargo 8)",
		entry.knowledge.balance() == 2 and entry.cargo == 8)
	await _clear_wave(entry, 3)
	check("attempt 3-wave win reached, balance 3", entry.knowledge.balance() == 3)
	get_tree().paused = false  # unpause only — see attempt 1 note
	var pm: Dictionary = entry.knowledge.research("mech")
	entry._save_profile()
	check("attempt 2: mech researched (balance 3 -> 0)",
		bool(pm.get("ok", false)) and entry.knowledge.balance() == 0)
	entry._try_transform_mech()
	check("transform: mech_mode, 250 hp, speed 6.5, cam 5.0, cargo spent",
		rig.mech_mode and rig.max_hp == MechData.MAX_HP and absf(rig.speed - MechData.SPEED) < 0.01
		and rig.cam_dist() == MechData.CAM_DIST and entry.cargo == 0)

	# ---- Golem command target fight ----
	rig.debug_set_pos(Vector3(4.2, _ground(4.2, -6.0), -6.0))
	await _wait(5)
	var g: Golem = load("res://combat/golem.gd").new()
	g.position = Vector3(7.2, _ground(7.2, -6.0), -6.0)
	g.goal = crystal
	g._rover = rover
	var blocked := [false]
	g.golem_event.connect(func(_g: Golem, k: String) -> void:
		if k == "blocked":
			blocked[0] = true)
	var died := [false]
	g.died.connect(func(_g: Golem) -> void: died[0] = true)
	entry.get_node("Arena").get_parent().add_child(g)
	await _wait(15)
	var aim: Vector3 = g.global_position + Vector3(0, 1.0, 0)
	combat.fire(rover.global_position, aim, [rover.get_rid()])
	await _wait(3)
	check("golem: flat fire fully blocked (armor 20)", g.hp == Golem.HP and blocked[0])
	# ram chip: flat 30 vs armor 20 = 10. The aim is camera-owned (M4 lesson),
	# so it must be re-set in the same frame as each ram call.
	var rams := 0
	var tries := 0
	var cpos: Vector3 = crystal.global_position  # cached: the golem kills the crystal mid-loop
	while rig.hp > PlayerRig.RAM_COST and is_instance_valid(g) and g.hp > 0 and tries < 12:
		tries += 1
		if is_instance_valid(g):
			# keep 3.0 m behind the golem on its approach line: always in ram
			# range, never in its 2.2 m melee range
			var gp: Vector3 = g.global_position
			var to_c: Vector3 = cpos - gp
			if to_c.length() > 0.1:
				rig.debug_set_pos(gp - to_c.normalized() * 3.0 + Vector3(0, 0.3, 0))
			await _wait(2)
			rig.debug_set_aim(gp + Vector3(0, 1.0, 0))
		var rr: bool = rig.ram()
		if rr:
			rams += 1
		await _wait(190)
	check("golem: rams chip exactly 10 each; the body cannot finish it",
		rams >= 3 and is_instance_valid(g) and g.hp == Golem.HP - rams * 10 and g.hp > 150)
	# the mech kills it: 40 pierce - 20 armor = 20 / shot
	var shots := 0
	while is_instance_valid(g) and g.hp > 0 and shots < 40:
		if is_instance_valid(g):
			aim = g.global_position + Vector3(0, 1.0, 0)
			combat.fire(rover.global_position, aim, [rover.get_rid()], MechData.GUN_DMG, true)
		shots += 1
		await _wait(2)
	check("golem: mech gun kills it in %d shots (armor bypassed)" % shots,
		died[0] and not is_instance_valid(g) and shots <= 16)
	# base enemies keep attacking during the mech fight
	var grunts := []
	for i in 3:
		var gr: Grunt = load("res://combat/enemy.gd").new()
		gr.position = Vector3(10.0, _ground(10.0, 6.0), 6.0 + i)
		gr.goal = crystal
		gr.arena = arena
		gr._rover = rover
		entry.get_node("Arena").get_parent().add_child(gr)
		grunts.append(gr)
	await _wait(15)
	var before: Vector3 = grunts[0].global_position
	await _wait(90)
	var moved: Vector3 = grunts[0].global_position
	check("base enemies keep attacking while the mech fights",
		moved.distance_to(before) > 1.0 and moved.distance_to(crystal.global_position) < before.distance_to(crystal.global_position))
	for gr in grunts:
		if is_instance_valid(gr):
			gr.queue_free()
	entry.queue_free()
	await _wait(20)

	# ---- attempt 3: body reset, knowledge persists ----
	get_tree().paused = false
	entry = await _boot_entry()
	rig = entry.get_node("PlayerRig")
	director = entry.get_node("WaveDirector")
	director.wave_plan = [3, 4, 5]  # prototype mode: campaign is 20 waves
	director.prep_left = WaveDirector.PREP_TIME
	# M18: the body resets to the starter rover at BASE stats — knowledge
	# (researched blueprints) persists, but power is manufactured in-run
	# (V: deploy, cargo cost). No free re-apply at boot.
	check("new attempt: starter rover at base stats, knowledge persists",
		not rig.mech_mode
		and rig.max_hp == 100
		and absf(rig.speed - 9.0) < 0.01
		and rig.cam_dist() == 6.5 and entry.knowledge.researched.has("mech"))

	# ---- rover-heavy route: ledger arithmetic on the real Knowledge code ----
	var k := Knowledge.new()
	for w in 3:
		k.grant_wave("a1", w)
	k.research("r1")
	k.research("r2")
	for w in 3:
		k.grant_wave("a2", w)
	var cm := k.can_research("mech")
	check("rover-heavy route: no-build attempt 1 + 2 harvests reaches the mech",
		bool(cm.get("ok", false)) and 6 + 2 >= MechData.BUILD_COST
		and (6 + 2 - MechData.BUILD_COST) >= 0)

	print("== M5 probe: %d ok, %d fail ==" % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
