extends Node
## HeightMapShape3D convention probe (headless, physics only).
## The arena builds its collision from the same 41x41 `height_at` heights as
## its visual mesh, but with the shape's default map_origin/map_size the
## Godot shape spans a 1200x1200 m area (30 m per sample) — the collision
## surface then does NOT match the visible mesh (the rover floats above or
## below it as it drives). This probe drops test bodies at known points and
## compares their resting height against height_at, for several
## map_origin/map_size / data-normalisation configurations.

const GRID := 41
const SIZE := 40.0

func height_at(x: float, z: float) -> float:
	var h := 0.7 * sin(x * 0.22) * cos(z * 0.19) \
		+ 0.45 * sin(x * 0.09 + 1.7) * sin(z * 0.11 + 0.4) \
		+ 0.3 * cos((x + z) * 0.05)
	h += maxf(0.0, -x - 8.0) * 0.22
	var d := Vector2(x, z).length()
	var pad := clampf((d - 6.0) / 6.0, 0.0, 1.0)
	return h * pad * pad

var heights := PackedFloat32Array()
var min_h := 0.0
var max_h := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _wait_frames(n: int) -> void:
	var i := 0
	while i < n:
		i += 1
		await get_tree().process_frame

func _body_for(cfg: Dictionary, pts: Array, rb_list: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := HeightMapShape3D.new()
	shape.map_width = GRID
	shape.map_depth = GRID
	shape.map_data = heights
	col.shape = shape
	body.add_child(col)
	# 4.7: no map_origin/map_size — the map is anchored at the body origin,
	# one world unit per sample. The body offset is the origin.
	if cfg.has("offset"):
		body.position = cfg["offset"]
	add_child(body)
	# one probe body per point (siblings of the static body — ancestor
	# collisions are not what we are testing)
	for p in pts:
		var rb := RigidBody3D.new()
		var c := CollisionShape3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.3
		c.shape = s
		rb.add_child(c)
		rb.position = Vector3(float(p[0]), 4.0, float(p[1]))
		rb.add_to_group("hm_rb")
		add_child(rb)
		rb_list.append(rb)
	return body

func _run() -> void:
	heights.resize(GRID * GRID)
	min_h = INF
	max_h = -INF
	for iz in GRID:
		for ix in GRID:
			var h := height_at(-SIZE / 2.0 + float(ix), -SIZE / 2.0 + float(iz))
			heights[iz * GRID + ix] = h
			min_h = minf(min_h, h)
			max_h = maxf(max_h, h)
	print("HM heights min=%.3f max=%.3f" % [min_h, max_h])

	var pts: Array = [[0.0, 0.0], [-15.0, 0.0], [10.0, -10.0], [0.0, 12.0]]
	var cfgs: Array = [
		{"name": "default (body at 0,0,0)"},
		{"name": "offset (-20,0,-20)", "offset": Vector3(-20.0, 0.0, -20.0)},
		{"name": "offset (-20,0, 20)", "offset": Vector3(-20.0, 0.0, 20.0)},
		{"name": "offset ( 20,0,-20)", "offset": Vector3(20.0, 0.0, -20.0)},
	]
	for cfg in cfgs:
		var rb_list: Array = []
		var body := await _body_for(cfg, pts, rb_list)
		await _wait_frames(300)
		var line := "HM_CFG %s ::" % cfg["name"]
		for i in pts.size():
			var p: Array = pts[i]
			var rb: RigidBody3D = rb_list[i]
			var rest_y: float = rb.position.y - 0.3
			var truth := height_at(float(p[0]), float(p[1]))
			line += " (%+.0f,%+.0f) y=%.2f v=%.2f truth=%.2f d=%+.2f" % [
				p[0], p[1], rest_y, rb.get_linear_velocity().length(), truth, rest_y - truth]
		print(line)
		body.queue_free()
		for rb in get_tree().get_nodes_in_group("hm_rb"):
			rb.queue_free()
		await _wait_frames(5)
	print("== heightmap probe: done ==")
	get_tree().quit(0)
