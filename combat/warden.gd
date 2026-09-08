class_name Warden
extends CharacterBody3D
## M4 protected enemy: 150 hp, armor 5 (flat per hit), slow, charges.
## Three counter paths (all verifiable in the probe):
##  1 TURRET  — turret rounds are piercing (ignore armor).
##  2 ROVER   — ram: 30 piercing damage, costs 15 rover hp.
##  3 WALL    — a wall in the charge lane deflects it: wall -40, Warden
##              stunned 5 s and takes 40 (stunned = no armor).

const SPEED := 1.5
const ARMOR := 5
const CRYSHP_RANGE := 2.6
const ROVER_AGGRO := 6.0
const MELEE_CD := 1.8
const AGGRO := 6.0
const CHARGE_START := 6.0
const CHARGE_TELEGRAPH := 1.2
const CHARGE_SPEED := 3.5
const CHARGE_DUR := 1.6
const CHARGE_HIT := 25
const DEFLECT_STUN := 5.0
const DEFLECT_DMG := 40
const WALL_MELEE := 20

var hp := 150
var goal: Node3D = null
var arena
var _rover: Node3D = null
var _cd := 0.0
var _bias := 1.0
var _stuck_t := 0.0
var _dead := false
var _state := "seek"  # seek | tell | charge | stunned
var _t := 0.0
var _charge_dir := Vector3.ZERO

signal died(warden: Warden)
signal warden_event(w: Warden, kind: String)  # armor | counter | charge | deflect

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("damageable")
	var col := CollisionShape3D.new()
	var s := CapsuleShape3D.new()
	s.radius = 0.7
	s.height = 1.8
	col.shape = s
	col.position = Vector3(0, 0.9, 0)
	add_child(col)
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.7
	body_mesh.height = 1.8
	var mi := MeshInstance3D.new()
	mi.mesh = body_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.3, 0.45)
	mat.roughness = 0.4
	mi.material_override = mat
	mi.position = Vector3(0, 0.9, 0)
	mi.name = "Visual"
	add_child(mi)
	var crest := BoxMesh.new()
	crest.size = Vector3(0.5, 0.5, 1.4)
	var ci := MeshInstance3D.new()
	ci.mesh = crest
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.9, 0.25, 0.2)
	cm.emission_enabled = true
	cm.emission = Color(0.8, 0.2, 0.15)
	cm.emission_energy_multiplier = 1.2
	ci.material_override = cm
	ci.position = Vector3(0, 1.9, -0.2)
	add_child(ci)

func _physics_process(delta: float) -> void:
	if _dead or goal == null or not is_instance_valid(goal):
		return
	_cd = maxf(0.0, _cd - delta)
	match _state:
		"stunned":
			_t -= delta
			if _t <= 0.0:
				_state = "seek"
			return
		"tell":
			_t -= delta
			if _t <= 0.0:
				_state = "charge"
				_t = CHARGE_DUR
			return
		"charge":
			_t -= delta
			velocity = _charge_dir * CHARGE_SPEED
			if not is_on_floor():
				velocity += Vector3(0, -25.0, 0) * delta
			move_and_slide()
			_charge_hit_check()
			if _t <= 0.0:
				_state = "seek"
				_cd = MELEE_CD * 0.5
			return
	_seek(delta)

func _seek(delta: float) -> void:
	var pos := global_position
	var target := goal
	if _rover != null and is_instance_valid(_rover):
		if pos.distance_to(_rover.global_position) < ROVER_AGGRO:
			target = _rover
	var to := target.global_position + Vector3(0, 0.6, 0)
	var dist := pos.distance_to(to)
	var los_q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.9, 0), to, -1, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(los_q)
	var blocker: Object = hit.get("collider") if not hit.is_empty() else null
	var in_range := (target == goal and dist < CRYSHP_RANGE) or (target != goal and dist < 2.0)
	if blocker is BuildingBase and blocker is Node3D and (blocker as Node3D).global_position.distance_to(pos) < 7.0:
		_attack(blocker)
	elif in_range:
		_attack(target)
	elif blocker == null or _is_target_node(blocker):
		if dist > CHARGE_START and target == goal:
			_start_charge(target)
		else:
			_move_to(to, delta)
	else:
		_move_to(to, delta)

## The crystal's collider is a child StaticBody3D, so a ray can hit the
## child, not the goal node itself.
func _is_target_node(c: Object) -> bool:
	if c == goal:
		return true
	if c is Node:
		return (c as Node).get_parent() == goal
	return false

func _start_charge(t: Node3D) -> void:
	var d := t.global_position - global_position
	d.y = 0.0
	if d.length() < 0.1:
		return
	_charge_dir = d.normalized()
	_state = "tell"
	_t = CHARGE_TELEGRAPH
	warden_event.emit(self, "charge")

func _charge_hit_check() -> void:
	var from := global_position + Vector3(0, 0.9, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + _charge_dir * 1.5, -1, [get_rid()])
	var h: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty():
		return
	var c: Object = h.get("collider")
	if c is BuildingBase:
		_deflect()
	elif _is_target_node(c) or (c is Node3D and c == _rover):
		_charge_hit(c)

func _deflect() -> void:
	var from := global_position + Vector3(0, 0.9, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + _charge_dir * 2.5, -1, [get_rid()])
	var h: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty():
		var c: Object = h.get("collider")
		if c is BuildingBase and c.has_method("damage"):
			c.call("damage", DEFLECT_DMG)
	_state = "stunned"
	_t = DEFLECT_STUN
	velocity = Vector3.ZERO
	hp -= DEFLECT_DMG
	warden_event.emit(self, "deflect")
	if hp <= 0:
		_die()

func _charge_hit(c: Object) -> void:
	if c.has_method("damage"):
		c.call("damage", CHARGE_HIT)
	_state = "seek"
	_cd = MELEE_CD

func _attack(t: Node) -> void:
	look_at((t as Node3D).global_position + Vector3(0, 0.7, 0), Vector3.UP)
	if _cd > 0.0:
		return
	_cd = MELEE_CD
	if t.has_method("damage"):
		if t is BuildingBase:
			t.call("damage", WALL_MELEE)
		elif t == goal:
			t.call("damage", 15)
		else:
			t.call("damage", 12)

func _move_to(to: Vector3, delta: float) -> void:
	var dir := to - global_position
	dir.y = 0.0
	if dir.length() < 0.1:
		return
	dir = dir.normalized()
	var probe := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.9, 0),
		global_position + Vector3(0, 0.9, 0) + dir * 1.7, -1, [get_rid()])
	var h: Dictionary = get_world_3d().direct_space_state.intersect_ray(probe)
	if not h.is_empty():
		var c: Object = h.get("collider")
		if not (c is BuildingBase) and c != goal and not (c is CharacterBody3D and c == _rover):
			var side := Vector3(-dir.z * _bias, 0.0, dir.x * _bias)
			dir = (dir * 0.7 + side).normalized()
	var wish := dir * SPEED
	velocity = velocity.lerp(wish, 1.0 - exp(-3.0 * delta))
	if not is_on_floor():
		velocity += Vector3(0, -25.0, 0) * delta
	move_and_slide()
	if arena != null and arena.has_method("height_at"):
		var gy: float = arena.height_at(global_position.x, global_position.z)
		if is_on_floor() and absf(global_position.y - gy) > 0.25:
			global_position.y = gy
	if velocity.length() < 0.4:
		_stuck_t += delta
		if _stuck_t > 2.5:
			_stuck_t = 0.0
			_bias = -_bias
			velocity += Vector3(-dir.z, 0.0, dir.x) * 2.0
	else:
		_stuck_t = maxf(0.0, _stuck_t - delta)

func damage(n: int, piercing: bool = false) -> void:
	if _dead:
		return
	var dmg := n
	if not piercing and _state != "stunned":
		dmg = maxi(1, n - ARMOR)
		warden_event.emit(self, "armor")
	else:
		warden_event.emit(self, "counter")
	hp -= dmg
	if hp <= 0:
		_die()

func _die() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("enemy")
	var v: Node = get_node_or_null("Visual")
	if v != null:
		v.scale = Vector3(0.1, 0.1, 0.1)
	died.emit(self)
	set_deferred("process_physics", false)
	var t := get_tree().create_timer(0.6)
	t.timeout.connect(queue_free)
