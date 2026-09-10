class_name BuildService
extends Node
## M2: wall/turret placement. 1 m grid snap, transparent ghost preview
## (green valid / red invalid), atomic spend->place, occupied-footprint
## validation. No double-spend, no duplicate placement.

const COSTS := {"wall": 2, "turret": 4}

var active := false
var current_type := ""
var occupied := {}
var arena
var wallet: Node = null
var combat: Combat = null
var aim_source: Node = null
var knowledge: Knowledge = null
var _ghost: MeshInstance3D

signal build_placed(building: Node, cell: Vector2i)
signal build_cancelled()
signal build_sold(building: Node, refund: int)

## M11: explicit removal. Refunds half the base cost, frees the building,
## frees its cell. Dead buildings are mid-death already and refuse.
func sell(b: Node) -> Dictionary:
	if not b is BuildingBase:
		return {"ok": false, "reason": "not_a_building"}
	var base: BuildingBase = b
	if base.hp <= 0:
		return {"ok": false, "reason": "already_destroyed"}
	var type := "wall" if base is Wall else "turret"
	if not COSTS.has(type):
		return {"ok": false, "reason": "not_a_building"}
	occupied.erase(base.cell)
	var refund: int = int(COSTS[type] / 2)
	if wallet != null:
		wallet.gain(refund)
	build_sold.emit(base, refund)
	base.queue_free()
	return {"ok": true, "refund": refund, "type": type}

func _ready() -> void:
	_ghost = MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.96, 1.0, 0.96)
	_ghost.mesh = m
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 1.0, 0.4, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 1.0, 0.4)
	mat.emission_energy_multiplier = 0.6
	_ghost.material_override = mat
	_ghost.visible = false
	add_child(_ghost)

func start_build(type: String) -> void:
	if not COSTS.has(type):
		return
	current_type = type
	active = true

func cancel() -> void:
	if not active:
		return
	active = false
	current_type = ""
	_ghost.visible = false
	build_cancelled.emit()

func last_type() -> String:
	return current_type

func _physics_process(_delta: float) -> void:
	if not active or aim_source == null or not aim_source.aim_valid():
		_ghost.visible = false
		return
	var pos: Vector3 = aim_source.aim_point()
	var c := cell_of(pos)
	var ctr := cell_center(c)
	var h := 1.8 if current_type == "wall" else 1.2
	_ghost.visible = true
	_ghost.position = ctr + Vector3(0, h / 2.0, 0)
	_ghost.scale = Vector3(1.0, h, 1.0)
	var ok: bool = _snap_ok(c) and wallet.spendable(int(COSTS[current_type]))
	var mat := _ghost.material_override as StandardMaterial3D
	if ok:
		mat.albedo_color = Color(0.3, 1.0, 0.4, 0.35)
		mat.emission = Color(0.3, 1.0, 0.4)
	else:
		mat.albedo_color = Color(1.0, 0.25, 0.2, 0.4)
		mat.emission = Color(1.0, 0.2, 0.2)

func cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x + 20.0)), int(floor(pos.z + 20.0)))

func cell_center(c: Vector2i) -> Vector3:
	var x := float(c.x) - 19.5
	var z := float(c.y) - 19.5
	return Vector3(x, arena.height_at(x, z), z)

func _snap_ok(c: Vector2i) -> bool:
	if c.x < 0 or c.x > 39 or c.y < 0 or c.y > 39:
		return false
	if occupied.has(c):
		return false
	var ctr := cell_center(c)
	for r in arena.rock_list:
		var p := Vector3(float(r["pos"].x), 0.0, float(r["pos"].z))
		if p.distance_to(Vector3(ctr.x, 0.0, ctr.z)) < float(r["r"]) + 0.9:
			return false
	if ctr.distance_to(Vector3(0, 0, 0)) < 2.8:
		return false
	var hs: Array = []
	for dx in [-0.4, 0.4]:
		for dz in [-0.4, 0.4]:
			hs.append(arena.height_at(ctr.x + dx, ctr.z + dz))
	var lo := minf(minf(hs[0], hs[1]), minf(hs[2], hs[3]))
	var hi := maxf(maxf(hs[0], hs[1]), maxf(hs[2], hs[3]))
	return hi - lo <= 0.6

func _apply_effects(b: Node) -> void:
	if knowledge == null:
		return
	var efs: Dictionary = knowledge.applied()
	var wall_max := int(60 + float(efs.get("wall_hp", 0.0)))
	if current_type == "wall":
		b.set("max_hp", wall_max)
		b.set("hp", wall_max)
	else:
		b.set("dmg", int(10 + float(efs.get("turret_damage", 0.0))))
		# turret_split is a multiplier (single node); floor keeps it sane
		var cd_base: float = maxf(0.2, 0.8 - float(efs.get("turret_cooldown", 0.0)))
		b.set("cooldown", maxf(0.2, cd_base * float(efs.get("turret_split", 1.0))))
		b.set("range_m", Turret.RANGE + float(efs.get("turret_range", 0.0)))
	b.set("repair_rate", float(efs.get("wall_repair", 0.0)))

func commit() -> Dictionary:
	if not active:
		return {"ok": false, "reason": "no_build_mode"}
	var c := cell_of(aim_source.aim_point())
	if not _snap_ok(c):
		return {"ok": false, "reason": "invalid_cell"}
	var cost: int = COSTS[current_type]
	if not wallet.spend(cost):
		return {"ok": false, "reason": "insufficient_scrap"}
	var b: Node
	if current_type == "wall":
		b = load("res://building/wall.gd").new()
	else:
		b = load("res://building/turret.gd").new()
		(b as Node).set("combat", combat)
	b.position = cell_center(c)
	(b as Node).set("cell", c)
	_apply_effects(b)
	occupied[c] = true
	arena.get_parent().add_child(b)
	build_placed.emit(b, c)
	return {"ok": true, "building": b, "cell": c}
