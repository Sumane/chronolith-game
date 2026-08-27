extends Node2D
## M4 CHRONOLITH — integrity (lose condition), Dilation Bubble passive,
## Rewind active with shared cooldown. Emits field state for Waves/Build.

const Crystal := preload("res://modules/chronolith/internal/crystal.gd")

var cfg: Dictionary = {}
var integrity := 500
var max_integrity := 500
var destroyed := false
var rewind_ready := true
var cooldown_left := 0.0
var pos := Vector2.ZERO

var _crystal: Node2D
var _field_timer := 0.0
var _sample_acc := 0.0
var _integrity_buffer: Array = [] # ring of [t, integrity]
var _phase_id: int = Contracts.Phase.HUB

func _ready() -> void:
	if Contracts.CONTRACT_VERSION != 1:
		push_warning("[Chronolith] contract version mismatch")
	cfg = Contracts.load_json("res://modules/chronolith/data/chronolith.json")
	max_integrity = int(cfg.get("integrity", 500))
	integrity = max_integrity
	_crystal = Crystal.new()
	_crystal.name = "Crystal"
	add_child(_crystal)
	Bus.run_started.connect(_on_run_started)
	Bus.phase_changed.connect(_on_phase_changed)
	Bus.enemy_attack.connect(_on_enemy_attack)
	Bus.player_activated_rewind.connect(_on_rewind_requested)

func _on_run_started(payload: Dictionary) -> void:
	integrity = max_integrity
	destroyed = false
	rewind_ready = true
	cooldown_left = 0.0
	_integrity_buffer.clear()
	pos = Vector2(960, 640) # map center; matches environment data crystal
	position = pos
	_crystal.reset()
	_broadcast_field(true)
	Bus.rewind_state.emit({"remaining": 0.0, "duration": float(cfg.get("rewind_cooldown", 40)), "ready": true})
	if int(payload.get("run_index", 0)) > 0:
		pass # first-run flavor handled by UI toasts

func _on_phase_changed(payload: Dictionary) -> void:
	_phase_id = int(payload.get("phase_id", _phase_id))

func _physics_process(delta: float) -> void:
	if destroyed:
		return
	# cooldown
	if not rewind_ready:
		cooldown_left = maxf(0.0, cooldown_left - delta)
		if cooldown_left <= 0.0:
			rewind_ready = true
			Bus.rewind_state.emit({"remaining": 0.0, "duration": float(cfg.get("rewind_cooldown", 40)), "ready": true})
		elif fmod(cooldown_left, 1.0) < delta:
			_emit_cooldown()
	# field broadcast on interval
	_field_timer -= delta
	if _field_timer <= 0.0:
		_field_timer = 0.5
		_broadcast_field(false)
	# rewind history sampling
	_sample_acc += delta
	var hz := float(cfg.get("buffer_hz", 10.0))
	var window := float(cfg.get("rewind_duration", 5.0)) + 1.0
	if hz > 0.0 and _sample_acc >= 1.0 / hz:
		_sample_acc = 0.0
		_integrity_buffer.append([Time.get_ticks_msec() / 1000.0, integrity])
		while _integrity_buffer.size() > int(window * hz):
			_integrity_buffer.pop_front()

func _broadcast_field(force: bool) -> void:
	if not force and _phase_id != Contracts.Phase.ASSAULT and _phase_id != Contracts.Phase.CALM:
		return
	Bus.chronolith_field_state.emit({
		"x": pos.x, "y": pos.y,
		"radius": float(cfg.get("bubble_radius", 245)),
		"slow": float(cfg.get("slow_factor", 0.55)),
	})

func _emit_cooldown() -> void:
	Bus.rewind_state.emit({
		"remaining": cooldown_left,
		"duration": float(cfg.get("rewind_cooldown", 40)),
		"ready": false,
	})

func _on_enemy_attack(payload: Dictionary) -> void:
	if str(payload.get("target", "")) != "CHRONOLITH":
		return
	if not Contracts.has_keys(payload, ["damage"]):
		push_warning("[Chronolith] dropped malformed enemy_attack")
		return
	apply_damage(int(payload["damage"]))

func apply_damage(damage: int) -> void:
	if destroyed:
		return
	integrity = maxi(0, integrity - damage)
	_crystal.hit_flash()
	Bus.chronolith_damaged.emit({"integrity": integrity, "max_integrity": max_integrity})
	if integrity <= 0:
		destroyed = true
		Bus.chronolith_destroyed.emit({})

func _on_rewind_requested(_payload: Dictionary) -> void:
	if destroyed or not rewind_ready or _phase_id != Contracts.Phase.ASSAULT:
		return
	rewind_ready = false
	cooldown_left = float(cfg.get("rewind_cooldown", 40))
	_emit_cooldown()
	Bus.chronolith_active_triggered.emit({"active": "rewind"})
	var seconds := float(cfg.get("rewind_duration", 5.0))
	# restore own integrity from ~N seconds ago
	var now := Time.get_ticks_msec() / 1000.0
	for sample: Array in _integrity_buffer:
		if now - float(sample[0]) >= seconds - 0.15:
			integrity = clampi(int(sample[1]), 1, max_integrity)
			break
	Bus.chronolith_damaged.emit({"integrity": integrity, "max_integrity": max_integrity})
	Bus.rewind_window.emit({"seconds": seconds})
	Bus.toast.emit({"text": "TEMPORAL REWIND — the last %.0fs un-happened" % seconds, "color": "#59e6ff"})
