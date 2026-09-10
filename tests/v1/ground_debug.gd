extends Node
## Ground rendering debug (playtest fix 3 follow-up). Minimal: loads the
## arena alone (no entry, no profile, no game) in the real renderer and
## saves three shots to user://:
##   gd_player.png — low player-style view over the arena
##   gd_top.png    — ortho straight down (the 1 m grid, visible or not)
##   gd_edge.png   — from the arena edge out over the plain to the horizon
## Run WITHOUT --headless:  godot --path . tests/v1/ground_debug.tscn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _wait(n: int) -> void:
	var i := 0
	while i < n:
		i += 1
		await get_tree().process_frame

func _shot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	var cam := get_viewport().get_camera_3d()
	print("SHOT %s size=%s camera=%s" % [path, str(img.get_size()), str(cam.name if cam != null else "null")])

func _cam(pos: Vector3, target: Vector3, fov: float, ortho_size: float) -> Camera3D:
	var c := Camera3D.new()
	c.name = "DbgCam"
	c.position = pos
	c.fov = fov
	if ortho_size > 0.0:
		c.projection = Camera3D.PROJECTION_ORTHOGONAL
		c.size = ortho_size
	add_child(c)
	c.look_at_from_position(pos, target, Vector3.UP)
	c.current = true
	await _wait(15)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return c

func _run() -> void:
	var es := ResourceLoader.load("res://scenes/v1/arena.tscn") as PackedScene
	var arena = es.instantiate()
	add_child(arena)
	await _wait(30)

	# Mesh/texture diagnostics on the live terrain
	for c in arena.get_children():
		if c is MeshInstance3D and c.mesh is ArrayMesh:
			var am := c.mesh as ArrayMesh
			print("MESH_DEBUG name=%s verts=%d" % [
				c.name, am.surface_get_array_len(0)])

	# 1: player-style low view
	var cam1 := await _cam(Vector3(0.0, 2.5, 9.0), Vector3(0.0, 0.5, -4.0), 70.0, 0.0)
	_shot("user://gd_player.png")
	cam1.queue_free()
	await _wait(5)

	# 2: ortho straight down over the arena centre
	var cam2 := await _cam(Vector3(0.01, 60.0, 0.01), Vector3.ZERO, 40.0, 55.0)
	_shot("user://gd_top.png")
	cam2.queue_free()
	await _wait(5)

	# 3: from the SE arena edge, out over the plain to the horizon
	var h: float = arena.height_at(15.0, 15.0)
	var cam3 := await _cam(Vector3(15.0, h + 3.0, 15.0), Vector3(30.0, 0.0, 30.0), 70.0, 0.0)
	_shot("user://gd_edge.png")
	cam3.queue_free()
	await _wait(5)

	print("== ground debug: done ==")
	arena.queue_free()
	await _wait(5)
	get_tree().quit(0)
