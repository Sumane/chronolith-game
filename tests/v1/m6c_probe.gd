extends Node
## M6c probe: the recognisable campaign map.
## 1. map shape: 17 rocks (16 + blocker), 5 deposits on a 7/10/13/17/21 m
##    distance ladder, all approach edges intact
## 2. navigation: grunts spawned on four opposite edges make real progress
##    toward the crystal (the cover clusters flank, not wall)
## 3. the blocker rock still occludes the north-centre lane to the crystal

var entry
var arena
var director
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

func _run() -> void:
	for pth in ["chronolith_v1_profile.json", "chronolith_v1_profile.json.bak", "chronolith_v1_profile.json.tmp"]:
		var gp := ProjectSettings.globalize_path("user://" + pth)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)
	var es := ResourceLoader.load("res://scenes/v1/entry.tscn") as PackedScene
	entry = es.instantiate()
	add_child(entry)
	# story beats off: this probe drives the flow itself
	entry.story_enabled = false
	await _wait(40)
	arena = entry.get_node("Arena")
	director = entry.get_node("WaveDirector")
	director.wave_plan = [3, 4, 5]  # this probe never wins; keep it cheap

	# 1 map shape
	var dep_dists: Array = []
	var deps: Node = arena.get_node("Deposits")
	for d in deps.get_children():
		dep_dists.append(Vector2((d as Node3D).position.x, (d as Node3D).position.z).length())
	dep_dists.sort()
	var ladder_ok := true
	var ladders := [7.2, 9.9, 12.5, 17.2, 21.2]
	for i in dep_dists.size():
		if absf(float(dep_dists[i]) - float(ladders[i])) > 0.4:
			ladder_ok = false
	check("map: 5 deposits on the 7/10/13/17/21 m ladder (sorted %s)" % str(dep_dists),
		dep_dists.size() == 5 and ladder_ok)
	check("map: 17 rocks + blocker = 18 colliders", arena.rock_list.size() == 18)
	check("map: 8 approach edges intact", director.EDGES.size() == 8)

	# 2 navigation: four opposite edges, 90 physics frames each
	var nav_ok := true
	var detail := ""
	for ei in [0, 2, 4, 6]:
		var e: Vector3 = director.EDGES[ei]
		var g: Grunt = load("res://combat/enemy.gd").new()
		g.position = Vector3(e.x, arena.height_at(e.x, e.z) + 0.5, e.z)
		g.goal = arena.crystal
		g.arena = arena
		g._rover = entry.get_node("PlayerRig").get_node("Rover")
		arena.get_parent().add_child(g)
		var d0: float = g.global_position.distance_to(arena.crystal.global_position)
		for _f in 90:
			await get_tree().physics_frame
		var d1: float = g.global_position.distance_to(arena.crystal.global_position)
		var prog := d0 - d1
		detail += "E%d:%.1fm " % [ei, prog]
		if prog < 3.0 or not is_instance_valid(g):
			nav_ok = false
		g.damage(99)
	check("map: grunts route to the crystal from N/NW/SE/SW (%s)" % detail, nav_ok)
	await _wait(20)

	# 3 the blocker rock flanks the north-centre lane
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(0.0, arena.height_at(0.0, -16.0) + 0.8, -16.0),
		Vector3(0.0, arena.crystal.global_position.y + 0.6, 0.0), -1)
	var hit: Dictionary = arena.get_world_3d().direct_space_state.intersect_ray(q)
	check("map: north-centre lane is occluded (a rock forces the flank)",
		not hit.is_empty())

	print("== M6c probe: %d ok, %d fail ==" % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
