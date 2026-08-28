extends Node
## M3 WAVES — wave director + all enemy AI. Door: this file only.
## Damage resolution v1: fire events carry target_id + damage; WE resolve HP.
## Enemy attacks go OUT as enemy_attack events; owners resolve their own HP.

const Enemy := preload("res://modules/waves/internal/enemy.gd")

var types: Dictionary = {}
var tables: Dictionary = {}
var next_enemy_id := 1
var sol := 0
var phase_id: int = Contracts.Phase.HUB

var spawn_queue: Array = [] # [{type, at_time}] sorted by time
var wave_clock := 0.0
var wave_total := 0
var wave_active := false

var crystal_pos := Vector2(960, 640)
var bubble := {x = 960.0, y = 640.0, radius = 245.0, slow = 0.55}
var tunnel_holes: Array = []
var map_size := Vector2(1920, 1280)
var layout: Array = [] # buildings [{id,x,y,radius,type,hp,max_hp}]
var scanner_masts: Array = []
var rover_pos := Vector2(960, 780)
var rover_alive := true

var _progress_acc := 0.0

func _ready() -> void:
	if Contracts.CONTRACT_VERSION != 1:
		push_warning("[Waves] contract version mismatch")
	var t: Variant = Contracts.load_json("res://modules/waves/data/enemy_types.json")
	if typeof(t) == TYPE_DICTIONARY:
		types = t
	var w: Variant = Contracts.load_json("res://modules/waves/data/wave_tables.json")
	if typeof(w) == TYPE_DICTIONARY:
		tables = w
	Bus.run_started.connect(_on_run_started)
	Bus.phase_changed.connect(_on_phase_changed)
	Bus.sol_changed.connect(func(p: Dictionary) -> void: sol = int(p.get("sol", sol)))
	Bus.map_loaded.connect(_on_map_loaded)
	Bus.chronolith_field_state.connect(func(p: Dictionary) -> void:
		bubble = {x = float(p.get("x", 960)), y = float(p.get("y", 640)),
			radius = float(p.get("radius", 245)), slow = float(p.get("slow", 0.55))})
	Bus.layout_snapshot.connect(func(p: Dictionary) -> void: layout = p.get("buildings", []))
	Bus.scanner_state.connect(_on_scanner_state)
	Bus.rover_moved.connect(func(p: Dictionary) -> void:
		rover_pos = Vector2(float(p.get("x", 0)), float(p.get("y", 0))))
	Bus.rover_destroyed.connect(func(_p: Dictionary) -> void: rover_alive = false)
	Bus.rover_fired.connect(_on_damage_event)
	Bus.turret_fired.connect(_on_damage_event)
	Bus.rewind_window.connect(_on_rewind_window)

func _on_map_loaded(payload: Dictionary) -> void:
	map_size = Vector2(float(payload.get("w", 1920)), float(payload.get("h", 1280)))
	crystal_pos = Contracts.vec2_of(payload.get("crystal", {}))
	tunnel_holes = payload.get("tunnel_holes", [])

func _on_scanner_state(payload: Dictionary) -> void:
	scanner_masts = payload.get("masts", [])

func _on_run_started(_payload: Dictionary) -> void:
	clear_all()
	sol = 0
	rover_alive = true

func clear_all() -> void:
	for e in get_children():
		e.queue_free()
	spawn_queue.clear()
	wave_active = false
	wave_total = 0
	next_enemy_id = 1

func _on_phase_changed(payload: Dictionary) -> void:
	phase_id = int(payload.get("phase_id", phase_id))
	match phase_id:
		Contracts.Phase.ASSAULT:
			_begin_wave()
		Contracts.Phase.RESET, Contracts.Phase.HUB:
			for e in get_children():
				e.queue_free()
			spawn_queue.clear()
			wave_active = false

func _begin_wave() -> void:
	spawn_queue.clear()
	wave_clock = 0.0
	var table: Dictionary = tables.get(str(sol), {})
	var groups: Array = table.get("groups", [])
	for g: Dictionary in groups:
		var count := int(g.get("count", 0))
		for i in count:
			spawn_queue.append({
				"type": str(g.get("type", "trooper")),
				"at_time": float(g.get("delay", 0.0)) + float(g.get("interval", 1.0)) * float(i),
			})
	wave_total = spawn_queue.size()
	wave_active = wave_total > 0
	if wave_active:
		Bus.wave_started.emit({"sol": sol, "total": wave_total})

# ---------------------------------------------------------------- director --
func _physics_process(delta: float) -> void:
	if not wave_active or phase_id != Contracts.Phase.ASSAULT:
		return
	wave_clock += delta
	while not spawn_queue.is_empty() and float(spawn_queue[0]["at_time"]) <= wave_clock:
		var spec: Dictionary = spawn_queue.pop_front()
		_spawn(str(spec["type"]))
	for e: Enemy in get_children(): # keep per-enemy world refs fresh each tick
		if is_instance_valid(e) and e is Enemy:
			e.layout = layout
	_emit_positions()
	_progress_acc += delta
	if _progress_acc >= 0.5:
		_progress_acc = 0.0
		Bus.wave_progress.emit({"alive": alive_count(), "queued": spawn_queue.size(), "total": wave_total})
	if spawn_queue.is_empty() and alive_count() == 0 and wave_total > 0:
		wave_active = false
		Bus.wave_cleared.emit({"sol": sol})

func alive_count() -> int:
	var n := 0
	for e: Node in get_children():
		if is_instance_valid(e) and e is Enemy and e.alive:
			n += 1
	return n

func _spawn(type: String) -> void:
	var def: Dictionary = types.get(type, {})
	if def.is_empty():
		return
	var edge := randi_range(0, 3)
	var inset := 220.0
	var p := Vector2.ZERO
	match edge:
		0: p = Vector2(randf_range(inset, map_size.x - inset), -30)
		1: p = Vector2(map_size.x + 30, randf_range(inset, map_size.y - inset))
		2: p = Vector2(randf_range(inset, map_size.x - inset), map_size.y + 30)
		3: p = Vector2(-30, randf_range(inset, map_size.y - inset))
	var e := Enemy.new()
	e.setup(next_enemy_id, type, def, p, tunnel_holes)
	e.position = p
	add_child(e)
	Bus.enemy_spawned.emit({"enemy_id": e.eid, "type": type, "x": p.x, "y": p.y})
	next_enemy_id += 1

func _emit_positions() -> void:
	var entries: Array = []
	for e: Enemy in get_children():
		if is_instance_valid(e) and e is Enemy:
			entries.append([e.eid, e.position.x, e.position.y, e.etype, e.state == e.STATE_UNDERGROUND])
	Bus.enemy_positions.emit({"entries": entries})

func debug_list_ids() -> Array:
	var ids: Array = []
	for e: Enemy in get_children():
		if is_instance_valid(e) and e is Enemy and e.alive:
			ids.append(e.eid)
	return ids

# ------------------------------------------------------------ resolution --
func _is_revealed(pos: Vector2) -> bool:
	for m: Dictionary in scanner_masts:
		if bool(m.get("online", false)) and Vector2(m["x"], m["y"]).distance_to(pos) <= float(m["radius"]):
			return true
	return rover_pos.distance_to(pos) <= Contracts.REVEAL_RADIUS_ROVER

func _on_damage_event(payload: Dictionary) -> void:
	var target_id := int(payload.get("target_id", -1))
	if target_id < 0:
		return # cosmetic miss
	if not Contracts.has_keys(payload, ["damage"]):
		return
	for e: Enemy in get_children():
		if is_instance_valid(e) and e is Enemy and e.eid == target_id and e.alive:
			if e.state == e.STATE_UNDERGROUND:
				return # laser splashes harmlessly on regolith
			if e.cloaked and not _is_revealed(e.position):
				return # shots pass through the shimmer
			e.take_damage(int(payload["damage"]))
			if e.hp <= 0:
				_kill(e)
			return

func _kill(e: Enemy) -> void:
	e.die()
	Bus.enemy_killed.emit({
		"enemy_id": e.eid, "type": e.etype, "salvage": types.get(e.etype, {}).get("salvage", {}),
	})

# ---------------------------------------------------------------- rewind --
func _on_rewind_window(payload: Dictionary) -> void:
	var seconds := float(payload.get("seconds", 5.0))
	var now := Time.get_ticks_msec() / 1000.0
	for e: Enemy in get_children():
		if not is_instance_valid(e) or not (e is Enemy):
			continue
		var sample: Array = e.sample_at(now - seconds)
		if sample.is_empty():
			continue
		var restored_hp := int(sample[3])
		if e.alive:
			if restored_hp > 0:
				e.restore(Vector2(float(sample[1]), float(sample[2])), restored_hp)
		elif now - e.died_at <= seconds + 1.0 and restored_hp > 0:
			e.resurrect(Vector2(float(sample[1]), float(sample[2])), restored_hp)
