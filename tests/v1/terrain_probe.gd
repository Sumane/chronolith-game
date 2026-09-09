extends Node
## Terrain-visibility probe (playtest fix 2): the arena surface must carry a
## readable tiled grid texture, and the world must extend to a fog-shrouded
## horizon instead of ending at the 40 m edge.

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

func _run() -> void:
	_wipe()
	var es := ResourceLoader.load("res://scenes/v1/entry.tscn") as PackedScene
	var e1 = es.instantiate()
	e1.story_enabled = false
	add_child(e1)
	await _wait(30)
	var arena: Node = e1.get_node("Arena")

	# the terrain mesh (41 x 41 vertices) carries a 64 px tiled grid texture
	var tmi: MeshInstance3D = null
	for c in arena.get_children():
		# the terrain is the only arena child with an ArrayMesh (rocks use
		# SphereMesh, the plain a PlaneMesh)
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is ArrayMesh:
			tmi = c
	var has_grid := false
	if tmi != null and tmi.material_override is StandardMaterial3D:
		var tex: Texture2D = (tmi.material_override as StandardMaterial3D).albedo_texture
		has_grid = tex is ImageTexture and (tex as ImageTexture).get_image().get_size() == Vector2i(640, 640)
	check("terrain carries a 640 px grid texture (16 px per metre tile)", has_grid)

	# a wide plain under the heightmap extends the horizon
	var plain_ok := false
	for c in arena.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is PlaneMesh \
			and ((c as MeshInstance3D).mesh as PlaneMesh).size.x >= 200.0:
			plain_ok = true
	check("500 m plain extends the horizon past the arena edge", plain_ok)

	# fog dense enough to fade the 40 m edge into the plain
	var we: WorldEnvironment = null
	for c in arena.get_children():
		if c is WorldEnvironment:
			we = c
	check("fog raised so the arena edge fades (density >= 0.02)",
		we != null and we.environment.fog_enabled and we.environment.fog_density >= 0.02)

	e1.queue_free()
	await _wait(5)
	print("== terrain probe: %d ok, %d fail ==" % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
