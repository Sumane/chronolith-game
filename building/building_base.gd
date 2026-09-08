class_name BuildingBase
extends StaticBody3D
## M2 building contract: HP, repair, 1m grid occupancy, damageable group.
## Visual under `Visual` is replaceable (docs/asset-conventions.md).

var max_hp := 60
var hp := 60
var cell := Vector2i.ZERO  # occupied grid cell (1 m cells, arena origin -20,-20)
var repair_rate := 0.0  # M3 Auto-Welder: hp/s self-repair

signal hp_changed(hp: int)
signal destroyed(building: Node)

func _ready() -> void:
	add_to_group("building")

func _physics_process(delta: float) -> void:
	if repair_rate > 0.0 and hp > 0 and hp < max_hp:
		hp = mini(max_hp, hp + repair_rate * delta)

func repair(n: int) -> int:
	var before := hp
	hp = mini(max_hp, hp + n)
	hp_changed.emit(hp)
	return hp - before

func damage(n: int) -> void:
	if hp <= 0:
		return
	hp = maxi(0, hp - n)
	hp_changed.emit(hp)
	if hp <= 0:
		_die()

func _die() -> void:
	remove_from_group("building")
	var v: Node = get_node_or_null("Visual")
	if v != null:
		v.scale = Vector3(0.05, 0.05, 0.05)
	destroyed.emit(self)
	set_deferred("process_physics", false)
	get_tree().create_timer(0.6).timeout.connect(queue_free)
