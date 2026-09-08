class_name PlayerRig
extends Node3D
## M1 PlayerRig: owns rover movement, chase camera (mouse orbit), aiming and
## fire command. Input contexts: PLAY vs PAUSE — the rig reads no gameplay
## input while paused (menu-only context lives in the pause gate).
## PC: WASD + mouse orbit/aim, LMB fire, Esc pause.
## Gamepad: left stick move, right stick camera, A fire, Start pause.

var speed := 9.0
const CAM_DIST := 6.5
const CAM_MIN := 1.4
const FIRE_CD := 0.25

enum Ctx { PLAY, PAUSE }

signal fired(from: Vector3, to: Vector3)
signal pause_toggled(paused: bool)

var ctx := Ctx.PLAY
var _rover: CharacterBody3D
var _chassis: Node3D
var _turret: Node3D
var _muzzle: Node3D
var _cam_rig: Node3D
var _cam: Camera3D
var _aim_marker: MeshInstance3D
var _yaw := 0.0
var _pitch := 0.34
var _fire_cd := 0.0
var _aim_pos := Vector3.ZERO
var _aim_valid := false
var _dbg_move := Vector2.ZERO
var _dbg_t := 0.0
# M2 state
var hp := 100
var max_hp := 100
var can_fire := true
var build_locked := false
var _dbg_interact := 0.0
var _channel := 0.0
var _channel_target: Node = null

signal hp_changed(hp: int)
signal harvest_done(deposit: Node)
signal repair_done(building: Node)

func _ready() -> void:
	_build_rover()
	_build_camera()
	_build_aim_marker()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if ctx != Ctx.PLAY:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_orbit(event.relative.x, event.relative.y)
	elif event.is_action_pressed("pause_toggle") and not build_locked:
		_toggle_pause()

func _physics_process(delta: float) -> void:
	if ctx != Ctx.PLAY:
		return
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_ram_cd = maxf(0.0, _ram_cd - delta)
	var move := _read_move_input()
	if _dbg_t > 0.0:
		_dbg_t -= delta
		move = _dbg_move
	var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if rs.length() > 0.2:
		_orbit(rs.x * 120.0 * delta, rs.y * 120.0 * delta)
	_update_camera(delta)
	_drive(delta, move)
	_update_aim()
	_update_interact(delta)
	if _dbg_interact > 0.0:
		_dbg_interact -= delta
	if _fire_pressed() and can_fire and _fire_cd <= 0.0 and _aim_valid:
		_fire_cd = FIRE_CD
		fired.emit(_muzzle.global_position, _aim_pos)

func _read_move_input() -> Vector2:
	var v := Vector2(
		Input.get_axis("move_left", "move_right"),
		-Input.get_axis("move_up", "move_down"),
	)
	var joy := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), -Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if joy.length() > 0.25:
		v = joy
	return v.limit_length(1.0)

func _fire_pressed() -> bool:
	return Input.is_action_pressed("fire") or Input.is_joy_button_pressed(0, JOY_BUTTON_A)

func _orbit(dx: float, dy: float) -> void:
	_yaw -= dx * 0.0026
	_pitch = clampf(_pitch + dy * 0.0026, -0.12, 1.25)

func _drive(delta: float, move: Vector2) -> void:
	var fwd := Vector3(0, 0, -1)
	if _cam_rig.is_inside_tree():
		var dirv := _rover.global_position - _cam_rig.global_position
		dirv.y = 0.0
		if dirv.length() > 0.1:
			fwd = dirv.normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var wish := (fwd * move.y + right * move.x) * speed
	_rover.velocity = _rover.velocity.lerp(wish, 1.0 - exp(-6.0 * delta))
	if not _rover.is_on_floor():
		_rover.velocity += Vector3(0, -25.0, 0) * delta
	_rover.move_and_slide()
	var p := _rover.global_position
	p.x = clampf(p.x, -19.0, 19.0)
	p.z = clampf(p.z, -19.0, 19.0)
	if p != _rover.global_position:
		_rover.global_position = p
	if move.length() > 0.3:
		var want := (fwd * move.y + right * move.x).normalized()
		var want_yaw := atan2(-want.x, -want.z)
		_chassis.rotation.y = lerp_angle(_chassis.rotation.y, want_yaw, 1.0 - exp(-5.0 * delta))

func _update_camera(delta: float) -> void:
	var target := _rover.global_position + Vector3(0, 1.3, 0)
	var to_cam := Vector3(sin(_yaw), 0.0, cos(_yaw)) * cos(_pitch)
	var desired := target + (to_cam * CAM_DIST) + Vector3(0, sin(_pitch), 0) * CAM_DIST
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(target, desired, -1, [_rover.get_rid()])
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty():
		var d := (Vector3(hit.get("position", desired)) - target).length()
		desired = target + (desired - target).normalized() * maxf(CAM_MIN, d - 0.3)
	_cam_rig.global_position = _cam_rig.global_position.lerp(desired, 1.0 - exp(-14.0 * delta))
	_cam.look_at(target + Vector3(0, 0.5, 0), Vector3.UP)

func _update_aim() -> void:
	var vp := _cam.get_viewport()
	if vp == null:
		return
	var centre := Vector2(vp.get_visible_rect().size) / 2.0
	var orig := _cam.project_ray_origin(centre)
	var norm := _cam.project_ray_normal(centre)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(orig, orig + norm * 200.0, -1, [_rover.get_rid()])
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		_aim_valid = false
		_aim_marker.visible = false
		return
	_aim_pos = Vector3(hit.get("position", orig + norm * 10.0))
	_aim_valid = true
	_aim_marker.visible = true
	_aim_marker.global_position = _aim_pos + Vector3(0, 0.04, 0)
	if is_instance_valid(_turret) and _turret.is_inside_tree():
		_turret.look_at(_aim_pos, Vector3.UP)

func _toggle_pause() -> void:
	ctx = Ctx.PAUSE if ctx == Ctx.PLAY else Ctx.PLAY
	get_tree().paused = ctx != Ctx.PLAY
	if ctx == Ctx.PLAY:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	pause_toggled.emit(get_tree().paused)

# ------------------------------------------------------------- M2 contracts --

func damage(n: int) -> void:
	if hp <= 0:
		return
	hp = maxi(0, hp - n)
	hp_changed.emit(hp)

const RAM_CD := 3.0
const RAM_COST := 15
var _ram_cd := 0.0

func ram() -> bool:
	if _ram_cd > 0.0 or hp <= RAM_COST:
		return false
	var from := _muzzle.global_position
	var dirv := _aim_pos - from
	if dirv.length() < 0.1:
		return false
	dirv = dirv.normalized()
	var q := PhysicsRayQueryParameters3D.create(from, from + dirv * 4.5, -1, [rover_rid()])
	var h: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty():
		return false
	var c: Object = h.get("collider")
	if c is Node and not (c as Node).is_in_group("enemy"):
		return false
	if c is Warden:
		c.call("damage", 30, true)
	else:
		(c as Node).call("damage", 30)
	hp -= RAM_COST
	hp_changed.emit(hp)
	_ram_cd = RAM_CD
	return true

func debug_ram() -> bool:
	return ram()

func apply_research(efs: Dictionary) -> void:
	max_hp += int(efs.get("rover_hp", 0.0))
	hp = max_hp
	speed += float(efs.get("rover_speed", 0.0))

func aim_point() -> Vector3:
	return _aim_pos

func aim_valid() -> bool:
	return _aim_valid

func _update_interact(delta: float) -> void:
	var want: Node = null
	if Input.is_action_pressed("interact") or _dbg_interact > 0.0:
		var p := _rover.global_position
		for d in get_tree().get_nodes_in_group("deposit"):
			if d is Node3D and p.distance_to(d.global_position) < 2.6:
				want = d
				break
		if want == null:
			for b in get_tree().get_nodes_in_group("building"):
				if b is BuildingBase and p.distance_to(b.global_position) < 2.6 and b.hp < b.max_hp:
					want = b
					break
	if want != _channel_target:
		_channel_target = want
		_channel = 0.0
	if want == null:
		return
	_channel += delta
	if want is Deposit and _channel >= 0.5:
		_channel = 0.0
		harvest_done.emit(want)
	elif want is BuildingBase and _channel >= 0.4:
		_channel = 0.0
		repair_done.emit(want)

# debug / test hooks (typed calls)
func debug_set_aim(p: Vector3) -> void:
	_aim_pos = p
	_aim_valid = true

func debug_set_pos(p: Vector3) -> void:
	_rover.global_position = p

func debug_interact(seconds: float) -> void:
	_dbg_interact = seconds

func debug_drive(dirv: Vector2, seconds: float) -> void:
	_dbg_move = dirv.limit_length(1.0)
	_dbg_t = seconds

func debug_pause() -> void:
	_toggle_pause()

func rover_rid() -> RID:
	return _rover.get_rid()

# ------------------------------------------------------------- construction --

func _mat(c: Color, emissive: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emissive
		m.emission_energy_multiplier = energy
	return m

func _build_rover() -> void:
	_rover = CharacterBody3D.new()
	_rover.name = "Rover"
	_rover.position = Vector3(0.0, 0.6, 8.0)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.5, 2.1)
	col.shape = box
	_rover.add_child(col)
	# Visual: replaceable blockout (docs/asset-conventions.md)
	_chassis = Node3D.new()
	_chassis.name = "Visual"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.6, 0.7, 2.2)
	var body_mi := MeshInstance3D.new()
	body_mi.mesh = body_mesh
	body_mi.material_override = _mat(Color(0.72, 0.62, 0.45))
	body_mi.position = Vector3(0, 0.35, 0)
	_chassis.add_child(body_mi)
	_turret = Node3D.new()
	_turret.name = "Turret"
	_turret.position = Vector3(0, 0.85, -0.2)
	var turret_mesh := BoxMesh.new()
	turret_mesh.size = Vector3(0.6, 0.5, 1.1)
	var turret_mi := MeshInstance3D.new()
	turret_mi.mesh = turret_mesh
	turret_mi.material_override = _mat(Color(0.5, 0.45, 0.4))
	_turret.add_child(turret_mi)
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.09
	barrel.bottom_radius = 0.09
	barrel.height = 0.9
	var barrel_mi := MeshInstance3D.new()
	barrel_mi.mesh = barrel
	barrel_mi.material_override = _mat(Color(0.25, 0.25, 0.3))
	barrel_mi.position = Vector3(0, 0, -0.9)
	barrel_mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_turret.add_child(barrel_mi)
	_muzzle = Node3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = Vector3(0, 0, -1.35)
	_turret.add_child(_muzzle)
	_chassis.add_child(_turret)
	for side in [-1.0, 1.0]:
		for fore in [-1.0, 1.0]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.35
			wheel.bottom_radius = 0.35
			wheel.height = 0.25
			var wi := MeshInstance3D.new()
			wi.mesh = wheel
			wi.material_override = _mat(Color(0.15, 0.14, 0.13))
			wi.position = Vector3(0.85 * side, -0.3, 0.8 * fore)
			wi.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			_chassis.add_child(wi)
	_rover.add_child(_chassis)
	add_child(_rover)

func _build_camera() -> void:
	_cam_rig = Node3D.new()
	_cam_rig.name = "CamRig"
	_cam_rig.position = _rover.position + Vector3(0, 1.6, 8.0)
	_cam = Camera3D.new()
	_cam.name = "Camera"
	_cam.current = true
	_cam_rig.add_child(_cam)
	add_child(_cam_rig)

func _build_aim_marker() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.16
	torus.outer_radius = 0.26
	torus.rings = 8
	torus.ring_segments = 24
	_aim_marker = MeshInstance3D.new()
	_aim_marker.name = "AimMarker"
	_aim_marker.mesh = torus
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.95, 0.85)
	m.emission_enabled = true
	m.emission = Color(0.3, 0.95, 0.85)
	m.emission_energy_multiplier = 1.5
	_aim_marker.material_override = m
	_aim_marker.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	add_child(_aim_marker)
