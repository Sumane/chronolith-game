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

	# the terrain mesh (121 x 121 vertices, fix 4) carries the 640 px grid
	# texture and IS the whole ground surface
	var tmi: MeshInstance3D = null
	var plane_count := 0
	for c in arena.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is ArrayMesh:
			tmi = c
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is PlaneMesh:
			plane_count += 1
	var has_grid := false
	var field_wide := false
	if tmi != null:
		var tex: Texture2D = (tmi.material_override as StandardMaterial3D).albedo_texture
		has_grid = tex is ImageTexture and (tex as ImageTexture).get_image().get_size() == Vector2i(640, 640)
		field_wide = (tmi.mesh as ArrayMesh).get_aabb().size.x >= 100.0
	check("terrain carries a 640 px grid texture (16 px per metre tile)", has_grid)
	check("the ground is one wide field (>= 100 m), not a 40 m slab", field_wide)
	check("no second floor: no PlaneMesh plain under the terrain", plane_count == 0)

	# the collision heightmap covers the whole field (4.7: map centred on
	# the body origin, one world unit per sample)
	var col_ok := false
	for c in arena.get_children():
		if c is StaticBody3D:
			for cc in (c as StaticBody3D).get_children():
				if cc is CollisionShape3D and (cc as CollisionShape3D).shape is HeightMapShape3D:
					var hm: HeightMapShape3D = (cc as CollisionShape3D).shape
					col_ok = hm.map_data.size() >= 121 * 121
	check("collision heightmap covers the 120 m field (>= 121x121 samples)", col_ok)

	# fog dense enough to fade the field edge into the horizon
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
