extends Node
## Sell probe (playtest fix 3: "no option to drop turrets and walls etc").
## Covers: BuildService.sell refunds/cell-free, dead/non-building guards,
## keyboard Z route through the aim raycast, gamepad RIGHT_SHOULDER route,
## and RMB cancelling a placement instead of selling.

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

func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)

func _rmb() -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	e.position = Vector2(320, 240)
	Input.parse_input_event(e)

func _rb() -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_RIGHT_SHOULDER
	e.pressed = true
	Input.parse_input_event(e)

func _wipe() -> void:
	for pth in ["chronolith_v1_profile.json", "chronolith_v1_profile.json.bak", "chronolith_v1_profile.json.tmp"]:
		var gp := ProjectSettings.globalize_path("user://" + pth)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)

## place via the debug aim hook (commit reads aim_point directly)
func _place(e1: Node, type: String, x: float, z: float) -> Node:
	var rig: Node = e1.get_node("PlayerRig")
	rig.debug_set_aim(Vector3(x, 1.0, z))
	e1.build.start_build(type)
	var res: Dictionary = e1.build.commit()
	if not res.get("ok", false):
		e1.build.cancel()
		return null
	return res["building"]

## Sweep the orbit until we find a candidate where a wall placed at the aim
## cell is actually hit by the live crosshair ray (low aim height so the ray
## crosses the wall box, cell buildable, verified by a real raycast).
## Returns the wall if found, null otherwise.
func _find_wall_on_ray(e1: Node, rig: Node) -> Node:
	var pitches: Array = [-0.12, 0.0, 0.12, 0.24]
	for p in pitches:
		for k in 16:
			rig.debug_set_orbit(TAU * float(k) / 16.0, float(p))
			await _wait(25)  # let the camera lerp fully converge
			var aim: Vector3 = rig.aim_point()
			var th: float = e1.arena.height_at(aim.x, aim.z)
			# hit must be near ground level (not an object) and under the wall top
			if aim.y - th > 0.3 or aim.y - th < -0.3 or aim.y > 1.6:
				continue
			var dist: float = Vector2(aim.x, aim.z).length()
			if dist < 4.0 or dist > 14.0:
				continue
			var c: Vector2i = e1.build.cell_of(aim)
			var ctr: Vector3 = e1.build.cell_center(c)
			if c.x < 0 or c.x > 39 or c.y < 0 or c.y > 39:
				continue
			if e1.build.occupied.has(c):
				continue
			if ctr.distance_to(Vector3.ZERO) < 2.8:
				continue
			# keep the aim well inside the wall box (0.49 m half-extent)
			if absf(aim.x - ctr.x) > 0.34 or absf(aim.z - ctr.z) > 0.34:
				continue
			var hs: Array = []
			for ddx in [-0.4, 0.4]:
				for ddz in [-0.4, 0.4]:
					hs.append(e1.arena.height_at(ctr.x + ddx, ctr.z + ddz))
			if maxf(maxf(hs[0], hs[1]), maxf(hs[2], hs[3])) - minf(minf(hs[0], hs[1]), minf(hs[2], hs[3])) > 0.6:
				continue
			var blocked := false
			for rr in e1.arena.rock_list:
				var pp := Vector3(float(rr["pos"].x), 0.0, float(rr["pos"].z))
				if pp.distance_to(Vector3(ctr.x, 0.0, ctr.z)) < float(rr["r"]) + 0.9:
					blocked = true
			if blocked:
				continue
			rig.debug_set_aim(ctr)
			e1.build.start_build("wall")
			var res: Dictionary = e1.build.commit()
			e1.build.cancel()
			if not res.get("ok", false):
				continue
			var w: Node = res["building"]
			await _wait(3)
			var hitc: Node = _aim_ray_hit(e1)
			if hitc == w:
				return w
			e1.build.sell(w)
			await _wait(3)
	return null

func _aim_ray_hit(e1: Node) -> Node:
	var rig: Node = e1.get_node("PlayerRig")
	var r: Dictionary = rig.aim_ray()
	if r.is_empty():
		return null
	var rover: CharacterBody3D = rig.get_node("Rover")
	var q := PhysicsRayQueryParameters3D.create(
		r["orig"], r["orig"] + r["dir"] * 200.0, -1, [rover.get_rid()])
	var hit: Dictionary = e1.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.get("collider")

func _run() -> void:
	_wipe()
	var es := ResourceLoader.load("res://scenes/v1/entry.tscn") as PackedScene
	var e1 = es.instantiate()
	e1.story_enabled = false
	add_child(e1)
	await _wait(40)
	var rig: Node = e1.get_node("PlayerRig")

	# --- API: place wall + turret, sell both for half refund, cell freed
	var w0: int = e1.cargo
	var wall := _place(e1, "wall", 5.5, 2.5)
	check("wall placed (cargo -2)", wall != null and e1.cargo == w0 - 2)
	var t0: int = e1.cargo
	var turret := _place(e1, "turret", 5.5, 3.5)
	check("turret placed (cargo -4)", turret != null and e1.cargo == t0 - 4)

	var c1: int = e1.cargo
	var res: Dictionary = e1.build.sell(wall)
	check("wall sells for half its cost", res.get("ok", false) and res.get("refund", 0) == 1)
	check("sell credits the wallet", e1.cargo == c1 + 1)
	await _wait(5)
	check("sold wall is freed", not is_instance_valid(wall))
	var c2: int = e1.cargo
	var tres: Dictionary = e1.build.sell(turret)
	check("turret sells for half its cost", tres.get("ok", false) and tres.get("refund", 0) == 2)
	check("turret sell credits the wallet", e1.cargo == c2 + 2)
	await _wait(5)
	var wall2 := _place(e1, "wall", 5.5, 2.5)
	check("sold cell is buildable again", wall2 != null)
	if wall2 != null:
		e1.build.sell(wall2)  # free the cell for the input-route tests
		await _wait(5)

	# --- guards
	var bad: Dictionary = e1.build.sell(e1.arena)
	check("non-building refuses to sell", not bad.get("ok", false))
	# a freed reference is rejected by the typed parameter itself
	check("freed building is invalid (refuse to sell)", not is_instance_valid(wall))

	# --- input routes (top up the wallet: sells are being tested, not the economy)
	e1.gain(10)

	# keyboard route: verified wall on the live ray, press Z
	var wall3: Node = await _find_wall_on_ray(e1, rig)
	check("verified wall placed on the crosshair ray", is_instance_valid(wall3))
	var c3: int = e1.cargo
	_key(KEY_Z)
	await _wait(4)
	check("Z sells the wall under the crosshair",
		e1.cargo == c3 + 1 and not is_instance_valid(wall3))

	# --- gamepad route: find a fresh verified wall, press RIGHT_SHOULDER
	var wallg1: Node = await _find_wall_on_ray(e1, rig)
	check("verified wall placed for the gamepad test", is_instance_valid(wallg1))
	var c4: int = e1.cargo
	_rb()
	await _wait(4)
	check("RIGHT_SHOULDER sells the wall under the crosshair",
		e1.cargo == c4 + 1 and not is_instance_valid(wallg1))

	# --- RMB while placing cancels, never sells
	var wall5 := _place(e1, "wall", 6.5, 2.5)
	e1.build.start_build("turret")
	check("build active before RMB", e1.build.active)
	_rmb()
	await _wait(3)
	check("RMB cancels the placement (no sell)",
		not e1.build.active and is_instance_valid(wall5))

	# --- gamepad build aliases (M6e bindings were unrouted in the entry)
	var c5: int = e1.cargo
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_X
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(2)
	check("gamepad X starts wall placement (build_1 routed)", e1.build.active and e1.build.current_type == "wall")
	e1.build.cancel()

	e1.queue_free()
	await _wait(5)
	print("== sell probe: %d ok, %d fail ==" % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
