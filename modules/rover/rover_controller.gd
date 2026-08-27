extends Node2D
## M1 ROVER — player verbs: drive, harvest, fire, upgrade, rewind beneficiary.
## Door: this file only. Never touches resource counts (Economy owns them).

const RoverBody := preload("res://modules/rover/internal/rover_body.gd")

var stages_data: Array = []
var stage := 0
var base_stats: Dictionary = {}
var hp := 100
var max_hp := 100
var speed := 175.0
var fire_interval := 0.33
var damage := 7
var fire_range := 270.0

var pos := Vector2(960, 780)
var move_vec := Vector2.ZERO
var fire_pressed := false
var fire_cd := 0.0
var destroyed := false
var alive_in_world := true

var map_bounds := Rect2(0, 0, 1920, 1280)
var crystal_pos := Vector2(960, 640)
var nodes: Array = [] # {id, kind, x, y, amount}
var enemies_latest: Array = [] # entries [id,x,y,type,underground]
var scanner_masts: Array = [] # [{x,y,radius,online}]

var bonus_hp_flat := 0
var bonus_harvest_mult := 1.0

var _body: Node2D
var _camera: Camera2D
var _harvest_acc := 0.0
var _harvest_pending := {} # kind -> units owed
var _flush_acc := 0.0
var _moved_acc := 0.0
var _rewind_buffer: Array = []
var _sample_acc := 0.0

func _ready() -> void:
	if Contracts.CONTRACT_VERSION != 1:
		push_warning("[Rover] contract version mismatch")
	var data: Variant = Contracts.load_json("res://modules/rover/data/rover_stages.json")
	if typeof(data) == TYPE_DICTIONARY:
		stages_data = data.get("stages", [])
	_body = RoverBody.new()
	_body.name = "Body"
	add_child(_body)
	_camera = Camera2D.new()
	_camera.name = "Cam"
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	_body.add_child(_camera)
	Bus.run_started.connect(_on_run_started)
	Bus.map_loaded.connect(_on_map_loaded)
	Bus.input_move.connect(_on_input_move)
	Bus.input_fire.connect(_on_input_fire)
	Bus.enemy_positions.connect(_on_enemy_positions)
	Bus.enemy_attack.connect(_on_enemy_attack)
	Bus.purchase_result.connect(_on_purchase_result)
	Bus.rewind_window.connect(_on_rewind_window)
	Bus.meta_bonuses.connect(_on_meta_bonuses)
	Bus.scanner_state.connect(func(p: Dictionary) -> void: scanner_masts = p.get("masts", []))
	Bus.node_depleted.connect(_on_node_depleted)

# ------------------------------------------------------------- lifecycle --
func _on_run_started(_payload: Dictionary) -> void:
	stage = 0
	_apply_stage_stats()
	hp = max_hp
	destroyed = false
	pos = Vector2(960, 780)
	move_vec = Vector2.ZERO
	_rewind_buffer.clear()
	_harvest_pending.clear()
	_body.reset(stage)

func _apply_stage_stats() -> void:
	base_stats = {}
	for s: Dictionary in stages_data:
		if int(s.get("stage", -1)) == stage:
			base_stats = s
			break
	if base_stats.is_empty():
		base_stats = {"max_hp": 100, "speed": 175.0, "fire_interval": 0.33, "damage": 7, "range": 270.0}
	max_hp = int(base_stats.get("max_hp", 100)) + bonus_hp_flat
	speed = float(base_stats.get("speed", 175.0))
	fire_interval = float(base_stats.get("fire_interval", 0.33))
	damage = int(base_stats.get("damage", 7))
	fire_range = float(base_stats.get("range", 270))

func _on_meta_bonuses(payload: Dictionary) -> void:
	bonus_hp_flat = int(payload.get("hp_flat", 0))
	bonus_harvest_mult = float(payload.get("harvest_mult", 1.0))
	var old_max := max_hp
	max_hp = int(base_stats.get("max_hp", 100)) + bonus_hp_flat
	hp += maxi(0, max_hp - old_max) # growing max never hurts current hp below zero

func _on_map_loaded(payload: Dictionary) -> void:
	map_bounds = Rect2(0, 0, float(payload.get("w", 1920)), float(payload.get("h", 1280)))
	crystal_pos = Contracts.vec2_of(payload.get("crystal", {}))
	nodes.clear()
	for n: Dictionary in payload.get("nodes", []):
		nodes.append({
			"id": str(n.get("id", "")), "kind": str(n.get("kind", "")),
			"x": float(n.get("x", 0)), "y": float(n.get("y", 0)),
			"amount": int(n.get("amount", 0)),
		})
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(map_bounds.size.x)
	_camera.limit_bottom = int(map_bounds.size.y)

# ------------------------------------------------------------------ loop --
func _physics_process(delta: float) -> void:
	if not alive_in_world:
		return
	fire_cd = maxf(0.0, fire_cd - delta)
	if not destroyed:
		pos += move_vec * speed * delta
		pos.x = clampf(pos.x, map_bounds.position.x + 24, map_bounds.end.x - 24)
		pos.y = clampf(pos.y, map_bounds.position.y + 24, map_bounds.end.y - 24)
	position = pos
	_body.set_motion(move_vec, speed)
	_body.set_health_frac(float(hp) / float(maxi(1, max_hp)))
	_moved_acc += delta
	if _moved_acc >= 0.1:
		_moved_acc = 0.0
		Bus.rover_moved.emit({"x": pos.x, "y": pos.y, "stage": stage})
	if not destroyed:
		_handle_harvest(delta)
		_handle_firing()
	_sample_rewind(delta)

func _handle_harvest(delta: float) -> void:
	var rate := 6.0 * bonus_harvest_mult
	var best: Dictionary = {}
	var best_d := 54.0 * 54.0
	for n: Dictionary in nodes:
		if int(n["amount"]) <= 0:
			continue
		var d: float = Vector2(n["x"], n["y"]).distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = n
	if best.is_empty():
		return
	_harvest_acc += rate * delta
	while _harvest_acc >= 1.0 and int(best["amount"]) > 0:
		_harvest_acc -= 1.0
		best["amount"] = int(best["amount"]) - 1
		var kind := str(best["kind"])
		_harvest_pending[kind] = int(_harvest_pending.get(kind, 0)) + 1
	_flush_acc += delta
	if _flush_acc >= 0.6 and not _harvest_pending.is_empty():
		_flush_acc = 0.0
		for kind: String in _harvest_pending:
			Bus.rover_harvested.emit({
				"node_id": best["id"], "kind": kind, "amount": int(_harvest_pending[kind]),
			})
		_harvest_pending.clear()

func _is_targetable(entry: Array) -> bool:
	if bool(entry[4]): # underground
		return false
	if str(entry[3]) != "stalker":
		return true
	# reveal rule (Contracts doc): any online mast covers it, or rover proximity
	for m: Dictionary in scanner_masts:
		if bool(m.get("online", false)) and Vector2(m["x"], m["y"]).distance_to(Vector2(entry[1], entry[2])) <= float(m["radius"]):
			return true
	return pos.distance_to(Vector2(entry[1], entry[2])) <= Contracts.REVEAL_RADIUS_ROVER

func _handle_firing() -> void:
	if not fire_pressed or fire_cd > 0.0:
		return
	var aim := get_global_mouse_position()
	var best_id := -1
	var best_pos := aim
	var best_d := fire_range * fire_range
	for entry: Array in enemies_latest:
		if not _is_targetable(entry):
			continue
		var d: float = pos.distance_squared_to(Vector2(entry[1], entry[2]))
		if d < best_d:
			best_d = d
			best_id = int(entry[0])
			best_pos = Vector2(entry[1], entry[2])
	var muzzle := pos + (best_pos - pos).normalized() * 18.0 if best_id != -1 else pos + (aim - pos).normalized() * 18.0
	fire_cd = fire_interval
	_body.add_tracer(muzzle, best_pos, stage == 1)
	Bus.rover_fired.emit({
		"from": Contracts.pack_v2(muzzle),
		"to": Contracts.pack_v2(best_pos),
		"damage": damage,
		"target_id": best_id,
	})

# ---------------------------------------------------------------- events --
func _on_input_move(payload: Dictionary) -> void:
	var v := Contracts.vec2_of(payload.get("vec", {}))
	move_vec = v.limit_length(1.0)

func _on_input_fire(payload: Dictionary) -> void:
	fire_pressed = bool(payload.get("pressed", false))

func _on_enemy_positions(payload: Dictionary) -> void:
	enemies_latest = payload.get("entries", [])

func _on_enemy_attack(payload: Dictionary) -> void:
	if destroyed or str(payload.get("target", "")) != "ROVER":
		return
	apply_damage(int(payload.get("damage", 0)))

func apply_damage(dmg: int) -> void:
	if destroyed:
		return
	hp = maxi(0, hp - dmg)
	_body.hit_flash()
	Bus.rover_damaged.emit({"hp": hp, "max_hp": max_hp})
	if hp <= 0:
		destroyed = true
		_body.wreck()
		Bus.rover_destroyed.emit({})
		Bus.toast.emit({"text": "ROVER TOTALLED — consciousness destabilizing…", "color": "#ff5a4a"})

func _on_purchase_result(payload: Dictionary) -> void:
	if str(payload.get("tag", "")) != "hybrid" or not bool(payload.get("ok", false)):
		return
	stage = 1
	_apply_stage_stats()
	hp = mini(max_hp, hp + 35)
	_body.reset(stage)
	Bus.rover_upgraded_ack.emit({"stage": stage})
	Bus.toast.emit({"text": "ASCENSION I — grey tech converges on the rover chassis", "color": "#59e6ff"})

func request_upgrade() -> void:
	if stage != 0 or destroyed:
		return
	var costs: Variant = Contracts.load_json("res://modules/economy/data/costs.json")
	var cost: Dictionary = costs.get("hybrid_upgrade", {}) if typeof(costs) == TYPE_DICTIONARY else {}
	if cost.is_empty():
		return
	Bus.purchase_request.emit({"req_id": "hybrid_%d" % randi(), "cost": cost, "tag": "hybrid"})

# ---------------------------------------------------------------- rewind --
func _sample_rewind(delta: float) -> void:
	_sample_acc += delta
	if _sample_acc >= 0.1:
		_sample_acc = 0.0
		_rewind_buffer.append([Time.get_ticks_msec() / 1000.0, pos.x, pos.y, hp])
		while _rewind_buffer.size() > 60:
			_rewind_buffer.pop_front()

func _on_rewind_window(payload: Dictionary) -> void:
	var seconds := float(payload.get("seconds", 5.0))
	var now := Time.get_ticks_msec() / 1000.0
	for sample: Array in _rewind_buffer:
		if now - float(sample[0]) >= seconds - 0.15:
			pos = Vector2(float(sample[1]), float(sample[2]))
			position = pos
			if destroyed:
				destroyed = false
				_body.reset(stage)
				Bus.toast.emit({"text": "Chassis restored across the rewind window", "color": "#59e6ff"})
			hp = clampi(int(sample[3]), 25, max_hp)
			Bus.rover_damaged.emit({"hp": hp, "max_hp": max_hp})
			return

func _on_node_depleted(payload: Dictionary) -> void:
	for n: Dictionary in nodes:
		if n["id"] == payload.get("node_id", ""):
			n["amount"] = 0
			return
