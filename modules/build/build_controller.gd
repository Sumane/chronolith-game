extends Node2D
## M2 BUILD SYSTEM — placement grid + validity, building lifecycle, turrets,
## power network, repair. Door: this file only. Never mutates resources.

const Building := preload("res://modules/build/internal/building.gd")
const Ghost := preload("res://modules/build/internal/ghost.gd")

var defs: Dictionary = {}
var rules: Dictionary = {}
var selected_type := ""
var buildings: Array = [] # Building nodes, placement order = power priority
var next_building_id := 1

# external world state carried in via events
var crystal_pos := Vector2(960, 640)
var vessel_pos := Vector2(340, 300)
var node_points: Array = []
var map_size := Vector2(1920, 1280)
var enemies_latest: Array = []
var scanner_masts: Array = []
var rover_pos := Vector2(960, 780)
var interact_held := false
var phase_id: int = Contracts.Phase.HUB
var solar_mult := 1.0

var _pending: Dictionary = {} # req_id -> {type,x,y}
var _repair_pending: Dictionary = {} # req_id -> building_id (results only echo req_id)
var _repair_cost: Dictionary = {"SCRAP": 2}
var _repair_req_counter := 0
var _repair_cd := 0.0
var _ghost: Node2D
var BASE_POWER := 4
var NIGHT_GEN_MULT := 0.5

func _ready() -> void:
	if Contracts.CONTRACT_VERSION != 1:
		push_warning("[Build] contract version mismatch")
	var d: Variant = Contracts.load_json("res://modules/build/data/buildings.json")
	if typeof(d) == TYPE_DICTIONARY:
		defs = d
	var r: Variant = Contracts.load_json("res://modules/build/data/grid_rules.json")
	if typeof(r) == TYPE_DICTIONARY:
		rules = r
	var c: Variant = Contracts.load_json("res://modules/economy/data/costs.json") # Economy owns cost data (architecture §4)
	_repair_cost = c.get("repair_tick", {"SCRAP": 2}) if typeof(c) == TYPE_DICTIONARY else {"SCRAP": 2}
	_ghost = Ghost.new()
	_ghost.name = "Ghost"
	_ghost.z_index = 30
	add_child(_ghost)
	Bus.run_started.connect(_on_run_started)
	Bus.map_loaded.connect(_on_map_loaded)
	Bus.build_selected.connect(_on_build_selected)
	Bus.build_place_clicked.connect(_on_place_clicked)
	Bus.purchase_result.connect(_on_purchase_result)
	Bus.enemy_positions.connect(func(p: Dictionary) -> void: enemies_latest = p.get("entries", []))
	Bus.enemy_attack.connect(_on_enemy_attack)
	Bus.phase_changed.connect(_on_phase_changed)
	Bus.environment_state.connect(_on_environment_state)
	Bus.scanner_state.connect(func(p: Dictionary) -> void:
		if p.get("self_report", false):
			return # ignore our own echoes
		scanner_masts = p.get("masts", []))
	Bus.input_interact.connect(func(p: Dictionary) -> void: interact_held = bool(p.get("pressed", false)))
	Bus.rover_moved.connect(func(p: Dictionary) -> void:
		rover_pos = Vector2(float(p.get("x", 0)), float(p.get("y", 0))))

func _on_run_started(_payload: Dictionary) -> void:
	for b in buildings:
		b.queue_free()
	buildings.clear()
	next_building_id = 1
	selected_type = ""
	_pending.clear()
	_emit_layout()
	_emit_scanner()
	_recalc_power()

func _on_map_loaded(payload: Dictionary) -> void:
	map_size = Vector2(float(payload.get("w", 1920)), float(payload.get("h", 1280)))
	crystal_pos = Contracts.vec2_of(payload.get("crystal", {}))
	vessel_pos = Contracts.vec2_of(payload.get("vessel", {}))
	node_points.clear()
	for n: Dictionary in payload.get("nodes", []):
		node_points.append(Vector2(float(n.get("x", 0)), float(n.get("y", 0))))

func _on_phase_changed(payload: Dictionary) -> void:
	phase_id = int(payload.get("phase_id", phase_id))
	_recalc_power()

func _on_environment_state(payload: Dictionary) -> void:
	solar_mult = float(payload.get("solar_mult", 1.0))
	_recalc_power()

# ------------------------------------------------------------- placement --
func _on_build_selected(payload: Dictionary) -> void:
	var id := str(payload.get("building_id", ""))
	selected_type = "" if not defs.has(id) else id

func _snap(v: float) -> float:
	var cell := int(rules.get("cell_snap", 32))
	return floorf(v / cell) * cell + cell * 0.5

func _placement_valid(x: float, y: float, type: String) -> bool:
	var def: Dictionary = defs.get(type, {})
	var r := float(def.get("radius", 20))
	if x < rules.get("map_margin", 28) or y < rules.get("map_margin", 28):
		return false
	if x > map_size.x - rules.get("map_margin", 28) or y > map_size.y - rules.get("map_margin", 28):
		return false
	if Vector2(x, y).distance_to(crystal_pos) < rules.get("min_crystal_dist", 120):
		return false
	if Vector2(x, y).distance_to(vessel_pos) < rules.get("vessel_clearance", 175):
		return false
	for np: Vector2 in node_points:
		if Vector2(x, y).distance_to(np) < rules.get("node_clearance", 50):
			return false
	for b: Building in buildings:
		if is_instance_valid(b) and Vector2(x, y).distance_to(b.position) < r + b.radius + float(rules.get("overlap_pad", 12)):
			return false
	return true

func _on_place_clicked(_payload: Dictionary) -> void:
	if selected_type == "" or phase_id == Contracts.Phase.HUB or phase_id == Contracts.Phase.RESET:
		return
	var x := _snap(get_global_mouse_position().x)
	var y := _snap(get_global_mouse_position().y)
	if not _placement_valid(x, y, selected_type):
		Bus.build_rejected.emit({"reason": "Invalid site"})
		return
	var def: Dictionary = defs[selected_type]
	var req_id := "build_%d" % next_building_id
	_pending[req_id] = {"type": selected_type, "x": x, "y": y}
	Bus.purchase_request.emit({"req_id": req_id, "cost": def.get("cost", {}), "tag": "build"})

func _on_purchase_result(payload: Dictionary) -> void:
	var req_id := str(payload.get("req_id", ""))
	var tag := str(payload.get("tag", ""))
	match tag:
		"build":
			if not _pending.has(req_id):
				return
			var data: Dictionary = _pending[req_id]
			_pending.erase(req_id)
			if bool(payload.get("ok", false)):
				_spawn_building(str(data["type"]), float(data["x"]), float(data["y"]))
			else:
				Bus.toast.emit({"text": "Insufficient resources", "color": "#ff8a5a"})
		"repair":
			if not bool(payload.get("ok", false)):
				return
			var bid := int(_repair_pending.get(req_id, -1))
			_repair_pending.erase(req_id)
			if bid < 0:
				return
			for b: Building in buildings:
				if is_instance_valid(b) and b.bid == bid:
					b.heal(20)
					break

func _spawn_building(type: String, x: float, y: float) -> void:
	var def: Dictionary = defs.get(type, {})
	if def.is_empty():
		return
	var b := Building.new()
	b.setup(next_building_id, type, def)
	b.position = Vector2(x, y)
	b.z_index = 1
	add_child(b)
	buildings.append(b)
	Bus.build_placed.emit({"building_id": b.bid, "type": type, "x": x, "y": y, "hp": b.hp})
	next_building_id += 1
	_recalc_power()
	_emit_layout()
	_emit_scanner()

func debug_place(type: String, x: float, y: float) -> bool:
	# Test hook: same economy path as a click, minus mouse position.
	if not defs.has(type) or not _placement_valid(x, y, type):
		return false
	var req_id := "build_%d" % next_building_id
	_pending[req_id] = {"type": type, "x": x, "y": y}
	Bus.purchase_request.emit({"req_id": req_id, "cost": defs[type].get("cost", {}), "tag": "build"})
	return true

# ------------------------------------------------------------------ power --
func _capacity() -> int:
	var gen := 0
	var night := phase_id == Contracts.Phase.ASSAULT
	for b: Building in buildings:
		if is_instance_valid(b) and b.powered and b.power_gen > 0:
			gen += int(round(float(b.power_gen) * solar_mult * (NIGHT_GEN_MULT if night else 1.0)))
	return BASE_POWER + gen

func _recalc_power() -> void:
	var capacity := _capacity()
	var used := 0
	var unpowered_ids: Array = []
	for b: Building in buildings:
		if not is_instance_valid(b):
			continue
		if b.power_draw <= 0:
			b.set_powered(true)
			continue
		if used + b.power_draw <= capacity:
			b.set_powered(true)
			used += b.power_draw
		else:
			b.set_powered(false)
			unpowered_ids.append(b.bid)
	Bus.power_state_changed.emit({"capacity": capacity, "draw": used, "unpowered_ids": unpowered_ids})

func _emit_layout() -> void:
	var arr: Array = []
	for b: Building in buildings:
		if is_instance_valid(b):
			arr.append({"id": b.bid, "x": b.position.x, "y": b.position.y, "radius": b.radius, "type": b.btype, "hp": b.hp, "max_hp": b.max_hp})
	Bus.layout_snapshot.emit({"buildings": arr})

func _emit_scanner() -> void:
	var masts: Array = []
	for b: Building in buildings:
		if is_instance_valid(b) and b.btype == "scanner":
			masts.append({"x": b.position.x, "y": b.position.y, "radius": b.scan_radius, "online": b.powered})
	scanner_masts = masts
	Bus.scanner_state.emit({"masts": masts, "self_report": true})

# ----------------------------------------------------------------- combat --
func _is_targetable(entry: Array) -> bool:
	if bool(entry[4]):
		return false
	if str(entry[3]) != "stalker":
		return true
	for m: Dictionary in scanner_masts:
		if bool(m.get("online", false)) and Vector2(m["x"], m["y"]).distance_to(Vector2(entry[1], entry[2])) <= float(m["radius"]):
			return true
	return rover_pos.distance_to(Vector2(entry[1], entry[2])) <= Contracts.REVEAL_RADIUS_ROVER

func _physics_process(delta: float) -> void:
	_update_turrets(delta)
	_update_repair(delta)
	_update_ghost()

func _update_turrets(delta: float) -> void:
	if phase_id == Contracts.Phase.HUB:
		return
	for b: Building in buildings:
		if not is_instance_valid(b) or b.btype != "turret" or not b.powered or b.hp <= 0:
			continue
		b.fire_cd -= delta
		if b.fire_cd > 0.0:
			continue
		var best_entry: Array = []
		var best_d: float = b.range * b.range
		for entry: Array in enemies_latest:
			if not _is_targetable(entry):
				continue
			var d: float = b.position.distance_squared_to(Vector2(entry[1], entry[2]))
			if d < best_d:
				best_d = d
				best_entry = entry
		if best_entry.is_empty():
			continue
		b.fire_cd = b.fire_interval
		var target_pos := Vector2(best_entry[1], best_entry[2])
		b.aim_at(target_pos)
		b.add_tracer(target_pos)
		Bus.turret_fired.emit({
			"building_id": b.bid,
			"from": Contracts.pack_v2(b.position),
			"to": Contracts.pack_v2(target_pos),
			"damage": b.damage,
			"target_id": int(best_entry[0]),
		})

func _update_repair(delta: float) -> void:
	_repair_cd -= delta
	if not interact_held or _repair_cd > 0.0:
		return
	var best: Building = null
	var best_d := 64.0 * 64.0
	for b: Building in buildings:
		if is_instance_valid(b) and b.hp > 0 and b.hp < b.max_hp:
			var d: float = b.position.distance_squared_to(rover_pos)
			if d < best_d:
				best_d = d
				best = b
	if best == null:
		return
	_repair_cd = 0.4
	_repair_req_counter += 1
	var req_id := "repair_%d" % _repair_req_counter
	_repair_pending[req_id] = best.bid
	Bus.purchase_request.emit({"req_id": req_id, "cost": _repair_cost, "tag": "repair"})

func _on_enemy_attack(payload: Dictionary) -> void:
	var target := str(payload.get("target", ""))
	if not target.begins_with("B"):
		return
	var bid := int(target.substr(1))
	for b: Building in buildings:
		if is_instance_valid(b) and b.bid == bid:
			b.take_damage(int(payload.get("damage", 0)))
			if b.hp <= 0:
				buildings.erase(b)
				Bus.build_destroyed.emit({"building_id": b.bid, "type": b.btype})
				b.die()
				_recalc_power()
				_emit_layout()
				_emit_scanner()
			else:
				_emit_layout()
			return

# ------------------------------------------------------------------ ghost --
func _update_ghost() -> void:
	if selected_type == "" or phase_id == Contracts.Phase.HUB:
		if _ghost.visible:
			_ghost.visible = false
		return
	_ghost.visible = true
	var mpos := get_global_mouse_position()
	var snapped := Vector2(_snap(mpos.x), _snap(mpos.y))
	_ghost.position = snapped
	var valid := _placement_valid(snapped.x, snapped.y, selected_type)
	_ghost.queue_redraw_with(selected_type, defs.get(selected_type, {}), valid, float(defs.get(selected_type, {}).get("range", 0)), float(defs.get(selected_type, {}).get("scan_radius", 0)))
