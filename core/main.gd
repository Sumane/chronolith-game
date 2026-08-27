extends Node2D
## Core composition root — owns run/phase FLOW only (architecture doc §4, M0).
## Instances all modules (main.tscn), drives the phase machine, advances sols.
## Never reaches into module internals; everything crosses the Bus.

const FINAL_SOL := 3

var run_index := 0
var sol := 0
var calm_total := 75.0
var calm_remaining := 0.0
var resetting := false

@onready var game_state: Node = $GameState

func _enter_tree() -> void:
	InputSetup.setup()

func _ready() -> void:
	var timing: Variant = Contracts.load_json("res://core/data/sol_timing.json")
	if typeof(timing) == TYPE_DICTIONARY:
		calm_total = float(timing.get("calm_duration", 75.0))
	Bus.hub_start_requested.connect(_on_hub_start)
	Bus.sol_changed.connect(_on_sol_changed)
	Bus.wave_cleared.connect(_on_wave_cleared)
	Bus.chronolith_destroyed.connect(_on_chronolith_destroyed)
	Bus.rover_destroyed.connect(_on_rover_destroyed)
	Bus.player_skip_calm.connect(_on_skip_calm)
	# Boot straight into the hub — the crashed vessel interior awaits.
	Bus.phase_changed.emit({"phase": Contracts.phase_name(Contracts.Phase.HUB), "phase_id": Contracts.Phase.HUB})

func _physics_process(delta: float) -> void:
	if game_state.current_phase == Contracts.Phase.CALM and not get_tree().paused:
		calm_remaining = maxf(0.0, calm_remaining - delta)
		Bus.calm_tick.emit({"remaining": calm_remaining, "duration": calm_total})
		if calm_remaining <= 0.0:
			_begin_assault()

func _on_hub_start(_payload: Dictionary) -> void:
	if resetting:
		return
	run_index += 1
	sol = 0
	Bus.run_started.emit({"run_index": run_index})
	Bus.sol_changed.emit({"sol": 1})

func _on_sol_changed(payload: Dictionary) -> void:
	sol = int(payload.get("sol", 1))
	game_state.set_phase(Contracts.Phase.CALM)
	calm_remaining = calm_total

func _begin_assault() -> void:
	if game_state.current_phase != Contracts.Phase.CALM:
		return
	game_state.set_phase(Contracts.Phase.ASSAULT)

func _on_skip_calm(_payload: Dictionary) -> void:
	if game_state.current_phase == Contracts.Phase.CALM and not get_tree().paused:
		calm_remaining = 0.0

func _on_wave_cleared(payload: Dictionary) -> void:
	var s := int(payload.get("sol", sol))
	if s >= FINAL_SOL:
		_end_run("victory")
	else:
		_schedule_next_sol(s + 1)

func _schedule_next_sol(next_sol: int) -> void:
	var t := get_tree().create_timer(2.5, false) # pause-aware
	t.timeout.connect(func() -> void:
		if game_state.current_phase == Contracts.Phase.ASSAULT:
			Bus.sol_changed.emit({"sol": next_sol}))

func _on_chronolith_destroyed(_payload: Dictionary) -> void:
	_end_run("chronolith_lost")

func _on_rover_destroyed(_payload: Dictionary) -> void:
	_end_run("rover_lost")

func _end_run(reason: String) -> void:
	if resetting or not game_state.is_in_gameplay():
		return
	resetting = true
	game_state.set_phase(Contracts.Phase.RESET)
	Bus.run_ended.emit({"reason": reason, "sols_survived": sol})
	var t := get_tree().create_timer(3.0, true)
	t.timeout.connect(func() -> void:
		resetting = false
		game_state.set_phase(Contracts.Phase.HUB))
