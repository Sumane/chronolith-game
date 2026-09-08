extends BuildingBase
## M2 energy wall: 1x1x1.8 m, translucent cyan panel (blockout).

func _init() -> void:
	max_hp = 60
	hp = 60

func _ready() -> void:
	super._ready()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.98, 1.8, 0.98)
	col.shape = box
	col.position = Vector3(0, 0.9, 0)
	add_child(col)
	var v := MeshInstance3D.new()
	v.name = "Visual"
	var m := BoxMesh.new()
	m.size = Vector3(0.96, 1.78, 0.96)
	v.mesh = m
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.25, 0.9, 0.8, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.9, 0.85)
	mat.emission_energy_multiplier = 0.8
	v.material_override = mat
	v.position = Vector3(0, 0.9, 0)
	add_child(v)
