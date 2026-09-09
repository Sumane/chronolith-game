extends Node
## M1 headless verification. Proves: boot, camera-relative driving, manual
## shot hitting 3D targets, rock occlusion, pause freeze + resume.
## Feel (camera/controls) is still Marc's review — headless can't prove it.

var _pass := 0
var _fail := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("ok   " + label)
	else:
		_fail += 1
		print("FAIL " + label)

func _run() -> void:
	var entry_res: PackedScene = ResourceLoader.load("res://scenes/v1/entry.tscn")
	var entry := entry_res.instantiate()
	add_child(entry)
	# story beats off: this probe drives the flow itself
	entry.story_enabled = false
	await _frames(30)
	var rig: PlayerRig = entry.get_node("PlayerRig")
	var combat: Combat = entry.get_node("Combat")
	var rover: CharacterBody3D = rig.get_node("Rover")
	_check(is_instance_valid(rover) and is_instance_valid(combat), "entry boots: rig + combat + rover present")

	# 1. camera-relative forward drive moves the rover (spawn faces -Z)
	var p0 := rover.global_position
	rig.debug_drive(Vector2(0, 1), 0.8)
	await _frames(55)
	var p1 := rover.global_position
	_check(p1.distance_to(p0) > 1.0, "forward drive moves rover %.2f m" % p1.distance_to(p0))
	_check(p1.z < p0.z, "drive is camera-relative (moved toward -Z: %.2f)" % (p1.z - p0.z))

	# 2. manual shot hits the unobstructed target
	var t2: Node = entry.get_node("Arena/Target2")
	var before2: int = t2.hp
	combat.fire(rover.global_position + Vector3(0, 1.0, 0), t2.global_position + Vector3(0, 0.8, 0), [rover.get_rid()])
	await _frames(2)
	_check(t2.hp == before2 - 10, "manual shot hits Target2 (hp %d -> %d)" % [before2, t2.hp])

	# 3. shot along the spawn line is occluded by the blocker rock
	var t1: Node = entry.get_node("Arena/Target1")
	var before1: int = t1.hp
	combat.fire(rover.global_position + Vector3(0, 1.0, 0), t1.global_position + Vector3(0, 0.8, 0), [rover.get_rid()])
	await _frames(2)
	_check(t1.hp == before1, "blocker rock occludes shot to Target1 (hp stays %d)" % t1.hp)

	# 4. pause freezes the simulation; resume works
	var q0 := rover.global_position
	rig.debug_pause()
	_check(get_tree().paused, "tree is paused after toggle")
	await _frames(45)
	var q1 := rover.global_position
	_check(q1 == q0, "rover frozen while paused")
	rig.debug_pause()
	_check(not get_tree().paused, "tree resumes after toggle")
	await _frames(2)

	print(String("== M1 probe: %d ok, %d fail ==") % [_pass, _fail])
	get_tree().quit(_fail)
