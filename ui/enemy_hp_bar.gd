class_name EnemyHpBar
extends Node3D
## M12: floating health bar above an enemy. Hidden while the enemy is at
## full health; shown on damage. Billboards toward the active camera.
## Enemy classes own one and call set_hp() whenever hp changes.

var _fill: MeshInstance3D
var _fill_w := 0.96
var _max_hp := 1

func _ready() -> void:
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.04, 0.04, 0.07, 0.8)
	bg_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bg_mesh := PlaneMesh.new()
	bg_mesh.size = Vector2(1.04, 0.16)
	var bg := MeshInstance3D.new()
	bg.mesh = bg_mesh
	bg.material_override = bg_mat
	add_child(bg)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color(0.95, 0.3, 0.22)
	fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# polygon offset keeps the fill in front of the backing plate (no z-fight)
	fill_mat.polygon_offset_backend_enable = true
	fill_mat.polygon_offset_factor = -1.0
	fill_mat.polygon_offset_units = -1.0
	var fill_mesh := PlaneMesh.new()
	fill_mesh.size = Vector2(_fill_w, 0.1)
	_fill = MeshInstance3D.new()
	_fill.mesh = fill_mesh
	_fill.material_override = fill_mat
	add_child(_fill)
	visible = false

## Show the bar only when damaged; the fill is left-anchored and scales
## with the remaining fraction.
func set_hp(hp: int, max_hp: int) -> void:
	_max_hp = maxi(1, max_hp)
	var r := clampf(float(hp) / float(_max_hp), 0.0, 1.0)
	visible = hp < _max_hp
	if visible:
		_fill.scale.x = r
		_fill.position.x = -_fill_w * (1.0 - r) / 2.0

func _process(_delta: float) -> void:
	if visible:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			look_at(cam.global_position, Vector3.UP)
