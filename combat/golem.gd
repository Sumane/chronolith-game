class_name Golem
extends CharacterBody3D
## M5 command target: a siege tank that always advances on the crystal,
## whatever else is on the field. 300 hp, armor 20 (flat damage fully
## blocked — only piercing shots get through: the mech gun, 20 net/shot).
## Rover rams are 30 flat: they chip 10 each while the body pays 15 hp,
## so the body cannot finish it. Base enemies keep attacking while the
## mech fights (the golem ignores the rover unless they cross paths).

const HP := 300
const ARMOR := 20
const SPEED := 1.2
const CRYSHP_RANGE := 2.8
const MELEE_RANGE := 2.8
const ROVER_RANGE := 2.2
const MELEE := 40
const MELEE_CD := 1.5

var hp := HP
var goal: Node3D = null
var arena
var _rover: Node3D = null
var _cd := 0.0
var _dead := false

signal died(golem: Golem)
signal golem_event(g: Golem, kind: String)  # blocked | counter

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("damageable")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.0
	cap.height = 2.6
	col.shape = cap
	col.position = Vector3(0, 1.1, 0)
	add_child(col)
	# Visual: replaceable blockout (docs/asset-conventions.md)
	var vis := Node3D.new()
	vis.name = "Visual"
	var body := BoxMesh.new()
	body.size = Vector3(2.2, 1.8, 2.4)
	var mi := MeshInstance3D.new()
	mi.mesh = body
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.16, 0.14)
	m.roughness = 0.7
	m.emission_enabled = true
	m.emission = Color(1.0, 0.35, 0.1)
	m.emission_energy_multiplier = 0.7
	mi.material_override = m
	mi.position = Vector3(0, 1.3, 0)
	vis.add_child(mi)
	add_child(vis)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_cd = maxf(0.0, _cd - delta)
	var p := global_position
	if goal != null and is_instance_valid(goal):
		var d := (goal.global_position + Vector3(0, 0.6, 0)) - p
		d.y = 0.0
		if d.length() > CRYSHP_RANGE:
			velocity = d.normalized() * SPEED * _time_factor()
			look_at(p + d.normalized(), Vector3.UP)
		elif _cd <= 0.0:
			goal.call("damage", MELEE)
			_cd = MELEE_CD
			golem_event.emit(self, "hit")
		else:
			velocity = Vector3.ZERO
	else:
		velocity = Vector3.ZERO
	# buildings in the way
	for b in get_tree().get_nodes_in_group("building"):
		if b is BuildingBase and is_instance_valid(b) \
				and global_position.distance_to(b.global_position) < MELEE_RANGE and _cd <= 0.0:
			b.call("damage", MELEE)
			_cd = MELEE_CD
	# the rover, if it gets close (the Rover body has no damage(); its parent
	# rig owns hp — same gap the grunt's has_method guard hides)
	if _rover != null and is_instance_valid(_rover) \
			and global_position.distance_to(_rover.global_position) < ROVER_RANGE and _cd <= 0.0:
		var t: Node = _rover
		if not t.has_method("damage") and t.get_parent() != null:
			t = t.get_parent()
		if t.has_method("damage"):
			t.call("damage", MELEE)
			_cd = MELEE_CD
	move_and_slide()

func damage(n: int, piercing: bool = false) -> void:
	if _dead:
		return
	if not piercing:
		var left := maxi(0, n - ARMOR)
		if left == 0:
			golem_event.emit(self, "blocked")
			return
		n = left
	hp = maxi(0, hp - n)
	if hp <= 0:
		_dead = true
		died.emit(self)
		queue_free()

## M6 TEMPORAL: stasis burst — the TimeWarp node on the arena slows all
## enemies; the rover and camera are unaffected.
func _time_factor() -> float:
	if arena != null and arena.has_node("TimeWarp"):
		return float(arena.get_node("TimeWarp").call("factor"))
	return 1.0
