class_name Deposit
extends Node3D
## M2 scrap deposit: stand near, hold E (interact) to channel.
## Emits taken(amount); depletes to zero then dims.

var amount := 5
var depleted := false

signal taken(deposit: Deposit, amount: int)

func _ready() -> void:
	add_to_group("deposit")
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.0, 1.2)
	col.shape = box
	col.position = Vector3(0, 0.5, 0)
	body.add_child(col)
	add_child(body)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.5, 0.42)
	mat.roughness = 0.4
	mat.metallic = 0.8
	for i in 5:
		var b := BoxMesh.new()
		b.size = Vector3(0.35, 0.3, 0.3)
		var mi := MeshInstance3D.new()
		mi.mesh = b
		mi.material_override = mat
		mi.position = Vector3(randf_range(-0.35, 0.35), 0.15 + i * 0.12, randf_range(-0.35, 0.35))
		add_child(mi)
	_refresh()

func take() -> int:
	if depleted:
		return 0
	amount -= 1
	_refresh()
	if amount <= 0:
		depleted = true
		remove_from_group("deposit")
	taken.emit(self, 1)
	return 1

func _refresh() -> void:
	for c in get_children():
		if c is MeshInstance3D:
			c.visible = c.get_index() < amount
