class_name TargetDummy
extends StaticBody3D
## M1 damageable 3D target (blockout). In the "damageable" group.
## Visual is code-built and replaceable; identity/HP never depends on meshes.

var max_hp := 20
var hp := 20
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("damageable")
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 1.6, 0.8)
	col.shape = box
	col.position = Vector3(0, 0.8, 0)
	add_child(col)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.9, 0.75, 0.2)
	_mat.roughness = 0.6
	_mat.emission_enabled = true
	_mat.emission = Color(0.9, 0.6, 0.1)
	_mat.emission_energy_multiplier = 0.4
	_mesh = MeshInstance3D.new()
	_mesh.mesh = BoxMesh.new()
	(_mesh.mesh as BoxMesh).size = Vector3(0.8, 1.6, 0.8)
	_mesh.material_override = _mat
	_mesh.position = Vector3(0, 0.8, 0)
	add_child(_mesh)

func damage(n: int) -> void:
	if hp <= 0:
		return
	hp = max(0, hp - n)
	_flash()
	if hp <= 0:
		_sink()

func _flash() -> void:
	_mat.emission_energy_multiplier = 2.5
	var t := get_tree().create_timer(0.12)
	t.timeout.connect(func() -> void:
		if is_instance_valid(_mat):
			_mat.emission_energy_multiplier = 0.4
	)

func _sink() -> void:
	_mesh.visible = false
	set_deferred("disabled", true)
	var t := get_tree().create_timer(5.0)
	t.timeout.connect(_respawn)

func _respawn() -> void:
	hp = max_hp
	set_deferred("disabled", false)
	_mesh.visible = true
