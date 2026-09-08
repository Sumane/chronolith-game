extends Node
## M4 probe: wave-3 composition (grunt + Warden), nuke boundedness, Warden
## armor, and the three counter paths — turret pierce (live fire), wall
## deflect (stun + chip), rover ram (pierce + self-cost).

var entry
var rig
var director
var crystal
var arena
var _ok := 0
var _fail := 0
var _frames := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_run()

func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > 12000:
		print("== M4 probe: TIMEOUT ==")
		get_tree().quit(1)

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

func _wardens() -> Array:
	var out: Array = []
	for en in get_tree().get_nodes_in_group("enemy"):
		if en is Warden:
			out.append(en)
	return out

func _kill_all() -> void:
	for en in get_tree().get_nodes_in_group("enemy"):
		en.call("damage", 999)

func _ground(x: float, z: float) -> float:
	return arena.height_at(x, z) + 0.5

func _boot_entry() -> Node:
	var es := ResourceLoader.load("res://scenes/v1/entry.tscn") as PackedScene
	var e = es.instantiate()
	add_child(e)
	await _wait(40)
	return e

func _run() -> void:
	# hermetic: clear any leftover profile
	for pth in ["chronolith_v1_profile.json", "chronolith_v1_profile.json.bak", "chronolith_v1_profile.json.tmp"]:
		var gp := ProjectSettings.globalize_path("user://" + pth)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)

	entry = await _boot_entry()
	rig = entry.get_node("PlayerRig")
	director = entry.get_node("WaveDirector")
	crystal = entry.get_node("Arena").crystal
	arena = entry.get_node("Arena")
	var rover = rig.get_node("Rover")

	# 1 boot
	check("boot: one emergency nuke charge", entry.nuke_charge == 1)

	# 2 wave 1 has no Warden
	director.call("debug_instant_wave", 1)
	await _wait(25)
	check("wave 1 has no warden", _wardens().size() == 0)
	_kill_all()
	await _wait(40)
	check("wave 1 cleared -> prep wave 2", director.state == WaveDirector.State.PREP and director.wave == 2)

	# 3 wave 3 composition: grunts + 1 Warden
	director.wave = 3
	director.state = WaveDirector.State.PREP
	director.call("_start_assault")
	await _wait(300)
	check("wave 3 composition: 5 grunts + 1 warden",
		get_tree().get_nodes_in_group("enemy").size() == 6 and _wardens().size() == 1)
	_kill_all()
	await _wait(40)
	check("wave 3 win: flow ended, final engram granted",
		director.state == WaveDirector.State.WIN and entry.knowledge.balance() == 2)
	# probe re-arm: the overlay path is verified (tree paused under the
	# end overlay); un-pause + re-enable flow so counter tests can tick
	get_tree().paused = false
	entry.flow.running = true

	# 4 nuke: bounded charge, clears the whole field
	director.wave = 2
	director.state = WaveDirector.State.PREP
	director.prep_left = WaveDirector.PREP_TIME
	director.call("debug_instant_wave", 2)
	await _wait(25)
	var w_nuke: Warden = director.call("debug_spawn_warden", Vector3(10.0, _ground(10.0, 4.0), 4.0))
	check("nuke setup: 3 enemies, 1 charge",
		get_tree().get_nodes_in_group("enemy").size() == 3 and entry.nuke_charge == 1)
	entry.debug_nuke()
	await _wait(40)
	check("nuke clears field, spends the charge",
		get_tree().get_nodes_in_group("enemy").size() == 0 and entry.nuke_charge == 0)
	entry.debug_nuke()
	await _wait(10)
	check("second nuke refused (no charges left)", entry.nuke_charge == 0)
	check("nuke test left prep wave 3", director.state == WaveDirector.State.PREP and director.wave == 3)
	if not is_instance_valid(w_nuke):
		w_nuke = null

	# 5 Warden armor
	var w1: Warden = director.call("debug_spawn_warden", Vector3(10.0, _ground(10.0, 4.0), 4.0))
	await _wait(25)
	w1.call("damage", 10)
	check("armor: non-piercing 10 -> 5", w1.hp == 145)
	w1.call("damage", 10, true)
	check("piercing bypasses armor", w1.hp == 135)

	# 6 wall deflect: wall in the charge lane
	director.prep_left = WaveDirector.PREP_TIME
	await _wait(50)  # let the charge tell start
	rig.debug_set_aim(Vector3(5.5, _ground(5.5, 2.5), 2.5))
	entry.build.start_build("wall")
	var wres: Dictionary = entry.build.commit()
	check("wall placed in charge lane", bool(wres.get("ok", false)) and entry.cargo == 4)
	var wallb: Node = wres.get("building")
	await _wait(300)
	check("deflect: wall -40 (20 hp left), warden -40", wallb.get("hp") == 20 and w1.hp == 95)
	check("deflect: warden stunned out of charge", w1._state == "stunned" or w1._state == "seek")
	w1.call("damage", 99, true)
	await _wait(40)

	# 7 turret pierce (live fire): turrets must beat the armor
	director.prep_left = WaveDirector.PREP_TIME
	# M2-proven harvest pose: 1.2 m offset, +0.3 above ground, 80-frame channel
	var i := 0
	while i < 3:
		rig.debug_set_pos(Vector3(7.2, arena.height_at(7.2, 4.0) + 0.3, 4.0))
		rig.debug_interact(0.9)
		await _wait(80)
		i += 1
	while i < 6:
		rig.debug_set_pos(Vector3(-5.8, arena.height_at(-5.8, 7.0) + 0.3, 7.0))
		rig.debug_interact(0.9)
		await _wait(80)
		i += 1
	check("harvest +6 scrap", entry.cargo == 10)
	rig.debug_set_aim(Vector3(5.5, _ground(5.5, 3.5), 3.5))
	entry.build.start_build("turret")
	var tres: Dictionary = entry.build.commit()
	check("turret placed (cargo 10 -> 6)", bool(tres.get("ok", false)) and entry.cargo == 6)
	var w2: Warden = director.call("debug_spawn_warden", Vector3(9.0, _ground(9.0, 1.0), 1.0))
	await _wait(300)
	check("live turret fire pierces armor (<=100 hp after ~5 s)", w2.hp <= 100)
	w2.call("damage", 99, true)
	await _wait(40)

	# 8 rover ram: 30 pierce per ram, 15 rover hp per ram
	director.prep_left = WaveDirector.PREP_TIME
	rig.max_hp = 300
	rig.hp = 300
	# open ground at (10,-6): the wall at (5.5,2.5) swallows ram rays whose
# muzzle starts inside it, and the Warden's path to the crystal stays clear
	# remove the test-7 turret: its fire would end the Warden mid-ram-test
	if tres.get("building") != null and is_instance_valid(tres.get("building")):
		(tres.get("building") as Node).queue_free()
	await _wait(5)
	var w3: Warden = director.call("debug_spawn_warden", Vector3(10.0, _ground(10.0, -6.0), -6.0))
	await _wait(15)  # collision shape sync after spawn
	var ram_ok := true
	var rams_done := 0
	var w3_dead := false
	while rams_done < 5:
		if not is_instance_valid(w3):
			w3_dead = true
			break
		# 3 m offset: the muzzle extends 1.35 m forward — at 2 m the ray would
		# start inside the Warden capsule and never register a hit
		rover.global_position = w3.global_position + Vector3(-3.0, 0.0, 0.0)
		rig.debug_set_aim(w3.global_position + Vector3(0.0, 0.9, 0.0))
		var hw: int = w3.hp
		var hr: int = rig.hp
		var did: bool = rig.ram()
		if not did or w3.hp != hw - 30 or rig.hp != hr - 15:
			ram_ok = false
		rams_done += 1
		if w3.hp <= 0:
			w3_dead = true
			break
		if rams_done < 5:
			await _wait(190)
	check("ram: 5 rams x 30 pierce, 15 hp each", ram_ok and rams_done == 5 and w3_dead)

	print("== M4 probe: %d ok, %d fail ==" % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
