class_name Grunt
extends CharacterBody3D
## M2 Corsair grunt: seeks the crystal, melees it (or the rover if close),
## attacks obstructing walls, steers around rocks. Real collision steering —
## a grid navmesh is a later upgrade.

const SPEED := 3.2
const CRYSHP_RANGE := 3.4
const ROVER_AGGRO := 6.0
const ATTACK_CD := 0.7

var hp := 20
var max_hp := 20
var hp_bar: EnemyHpBar
var goal: Node3D = null
var arena
var _rover: Node3D = null
var _cd := 0.0
var _bias := 1.0
var _stuck_t := 0.0
var _dead := false

signal died(grunt: Grunt)

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("damageable")
	var col := CollisionShape3D.new()
	var s := CapsuleShape3D.new()
	s.radius = 0.4
	s.height = 1.4
	col.shape = s
	col.position = Vector3(0, 0.7, 0)
	add_child(col)
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.4
	body_mesh.height = 1.4
	var mi := MeshInstance3D.new()
	mi.mesh = body_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.2, 0.25)
	mat.roughness = 0.7
	mi.material_override = mat
	mi.position = Vector3(0, 0.7, 0)
	mi.name = "Visual"
	add_child(mi)
	var eye := SphereMesh.new()
	eye.radius = 0.1
	eye.height = 0.2
	var ei := MeshInstance3D.new()
	ei.mesh = eye
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(1, 0.9, 0.3)
	em.emission_enabled = true
	em.emission = Color(1, 0.9, 0.2)
	em.emission_energy_multiplier = 1.5
	ei.material_override = em
	ei.position = Vector3(0, 1.25, -0.35)
	add_child(ei)
	hp_bar = EnemyHpBar.new()
	hp_bar.name = "HpBar"
	hp_bar.position = Vector3(0, 1.55, 0)
	add_child(hp_bar)
	hp_bar.set_hp(hp, max_hp)

func _physics_process(delta: float) -> void:
	if _dead or goal == null or not is_instance_valid(goal):
		return
	_cd = maxf(0.0, _cd - delta)
	var pos := global_position
	var target := goal
	if _rover != null and is_instance_valid(_rover):
		if pos.distance_to(_rover.global_position) < ROVER_AGGRO:
			target = _rover
	var to := target.global_position + Vector3(0, 0.6, 0)
	var dist := pos.distance_to(to)
	var los_q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.8, 0), to, -1, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(los_q)
	var blocker: Object = hit.get("collider") if not hit.is_empty() else null
	var in_range := (target == goal and dist < CRYSHP_RANGE) or (target != goal and dist < 1.9)
	if blocker is BuildingBase and blocker is Node3D and (blocker as Node3D).global_position.distance_to(pos) < 7.0:
		_attack(blocker)
	elif in_range or blocker == null or blocker == target or blocker is Grunt:
		if in_range:
			_attack(target)
		else:
			_move_to(to, delta)
	elif blocker is Grunt:
		_move_to(to, delta)
	else:
		_move_to(to, delta)

func _attack(t: Node) -> void:
	look_at((t as Node3D).global_position + Vector3(0, 0.7, 0), Vector3.UP)
	if _cd > 0.0:
		return
	_cd = ATTACK_CD
	var owner := _damage_owner(t)
	if owner != null and owner.has_method("damage"):
		if t == goal:
			owner.call("damage", 6)
		elif t is BuildingBase:
			owner.call("damage", 4)
		else:
			owner.call("damage", 5)

## The node that owns hp. The Rover body is a collider child; its rig
## parent owns damage(). Buildings and the crystal own their hp directly.
func _damage_owner(t: Node) -> Node:
	if t.has_method("damage"):
		return t
	if t.get_parent() != null and t.get_parent().has_method("damage"):
		return t.get_parent()
	return null

func _move_to(to: Vector3, delta: float) -> void:
	var dir := (to - global_position)
	dir.y = 0.0
	if dir.length() < 0.1:
		return
	dir = dir.normalized()
	# forward probe: steer around static blockers (rocks, terrain edges)
	var probe := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.8, 0),
		global_position + Vector3(0, 0.8, 0) + dir * 1.7, -1, [get_rid()])
	var h: Dictionary = get_world_3d().direct_space_state.intersect_ray(probe)
	if not h.is_empty():
		var c: Object = h.get("collider")
		if not (c is BuildingBase) and c != goal and not (c is CharacterBody3D and c == _rover):
			var side := Vector3(-dir.z * _bias, 0.0, dir.x * _bias)
			dir = (dir * 0.7 + side).normalized()
	var wish := dir * SPEED * _time_factor()
	velocity = velocity.lerp(wish, 1.0 - exp(-4.0 * delta))
	if not is_on_floor():
		velocity += Vector3(0, -25.0, 0) * delta
	move_and_slide()
	# ground snap to heightmap keeps grunts glued on slopes
	if arena != null and arena.has_method("height_at"):
		var gy: float = arena.height_at(global_position.x, global_position.z)
		if is_on_floor() and absf(global_position.y - gy) > 0.25:
			global_position.y = gy
	# stuck breaker: keep acting, never idle (enclosed base must not freeze)
	if velocity.length() < 0.4:
		_stuck_t += delta
		if _stuck_t > 2.5:
			_stuck_t = 0.0
			_bias = -_bias
			velocity += Vector3(-dir.z, 0.0, dir.x) * 2.0
	else:
		_stuck_t = maxf(0.0, _stuck_t - delta)

func damage(n: int) -> void:
	if _dead:
		return
	hp -= n
	if hp_bar != null:
		hp_bar.set_hp(hp, max_hp)
	if hp <= 0:
		_dead = true
		remove_from_group("enemy")
		var v: Node = get_node_or_null("Visual")
		if v != null:
			v.scale = Vector3(0.1, 0.1, 0.1)
		died.emit(self)
		set_deferred("process_physics", false)
		var t := get_tree().create_timer(0.6)
		t.timeout.connect(queue_free)

## M6 TEMPORAL: stasis burst — the TimeWarp node on the arena slows all
## enemies; the rover and camera are unaffected.
func _time_factor() -> float:
	if arena != null and arena.has_node("TimeWarp"):
		return float(arena.get_node("TimeWarp").call("factor"))
	return 1.0
