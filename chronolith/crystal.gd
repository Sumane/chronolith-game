class_name ChronolithCrystal
extends Node3D
## M2 fixed Chronolith: 50 integrity, damageable, glow + light.
## Death ends the attempt (GameFlow listens).

var integrity := 50
var max_integrity := 50
var destroyed := false

signal damaged(integrity: int)
signal destroyed_signal()

func _ready() -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.8
	col.shape = s
	col.position = Vector3(0, 1.8, 0)
	body.add_child(col)
	add_child(body)
	var ped := CylinderMesh.new()
	ped.top_radius = 1.4
	ped.bottom_radius = 1.7
	ped.height = 0.5
	var ped_mi := MeshInstance3D.new()
	ped_mi.mesh = ped
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.35, 0.3, 0.28)
	pm.roughness = 1.0
	ped_mi.material_override = pm
	ped_mi.position = Vector3(0, 0.25, 0)
	add_child(ped_mi)
	var cm := PrismMesh.new()
	cm.size = Vector3(1.5, 3.0, 1.5)
	var crystal := MeshInstance3D.new()
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.2, 0.85, 0.75)
	cmat.emission_enabled = true
	cmat.emission = Color(0.2, 0.95, 0.85)
	cmat.emission_energy_multiplier = 1.5
	crystal.material_override = cmat
	crystal.position = Vector3(0, 2.1, 0)
	crystal.name = "Visual"
	add_child(crystal)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 2.4, 0)
	glow.light_color = Color(0.3, 0.95, 0.85)
	glow.light_energy = 2.5
	glow.omni_range = 10.0
	add_child(glow)

func damage(n: int) -> void:
	if destroyed:
		return
	integrity = maxi(0, integrity - n)
	damaged.emit(integrity)
	if integrity <= 0:
		destroyed = true
		var c: Node = get_node_or_null("Visual")
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
		destroyed_signal.emit()
