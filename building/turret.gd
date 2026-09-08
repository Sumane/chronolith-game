extends BuildingBase
## M2 automated turret: 1x1 footprint, range 8 m, 0.8 s cooldown, 10 dmg.
## Targets nearest enemy with clear line of sight; fires through Combat.

const RANGE := 8.0
const COOLDOWN := 0.8
const SCAN := 0.25

var combat: Combat
var _head: Node3D
var _muzzle: Node3D
var _cd := 0.0
var _scan_t := 0.0
var _target: Node = null

func _init() -> void:
	max_hp = 40
	hp = 40

func _ready() -> void:
	super._ready()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.98, 1.2, 0.98)
	col.shape = box
	col.position = Vector3(0, 0.6, 0)
	add_child(col)
	var v := Node3D.new()
	v.name = "Visual"
	var ped_mesh := CylinderMesh.new()
	ped_mesh.top_radius = 0.3
	ped_mesh.bottom_radius = 0.4
	ped_mesh.height = 0.7
	var ped_mi := MeshInstance3D.new()
	ped_mi.mesh = ped_mesh
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.45, 0.4, 0.35)
	ped_mi.material_override = pm
	ped_mi.position = Vector3(0, 0.35, 0)
	v.add_child(ped_mi)
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 0.9, 0)
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.55, 0.4, 0.8)
	var head_mi := MeshInstance3D.new()
	head_mi.mesh = head_mesh
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.6, 0.5, 0.3)
	head_mi.material_override = hm
	_head.add_child(head_mi)
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.06
	barrel.bottom_radius = 0.06
	barrel.height = 0.7
	var barrel_mi := MeshInstance3D.new()
	barrel_mi.mesh = barrel
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.25, 0.25, 0.3)
	barrel_mi.material_override = bm
	barrel_mi.position = Vector3(0, 0, -0.6)
	barrel_mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_head.add_child(barrel_mi)
	_muzzle = Node3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = Vector3(0, 0, -0.95)
	_head.add_child(_muzzle)
	v.add_child(_head)
	add_child(v)

func _physics_process(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	_scan_t -= delta
	if _scan_t > 0.0:
		return
	_scan_t = SCAN
	_pick_target()
	if _target == null or not is_instance_valid(_target):
		return
	var tp: Vector3 = _target.global_position + Vector3(0, 0.6, 0)
	_head.look_at(tp, Vector3.UP)
	if _cd <= 0.0 and _has_los(tp):
		_cd = COOLDOWN
		combat.fire(_muzzle.global_position, tp, [get_rid()])

func _pick_target() -> void:
	var best: Node = null
	var best_d := RANGE
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node3D:
			var d: float = global_position.distance_to((e as Node3D).global_position)
			if d < best_d:
				best_d = d
				best = e
	_target = best

func _has_los(to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(_muzzle.global_position, to, -1, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return true
	var c: Object = hit.get("collider")
	return c == _target or c is Grunt
