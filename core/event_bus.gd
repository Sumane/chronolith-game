extends Node
## Bus — the ONLY cross-module channel (architecture doc §3).
## One signal = one Dictionary payload; shapes documented in core/contracts.gd.

signal phase_changed(payload: Dictionary)
signal run_started(payload: Dictionary)
signal run_ended(payload: Dictionary)
signal sol_changed(payload: Dictionary)
signal calm_tick(payload: Dictionary)

signal map_loaded(payload: Dictionary)
signal environment_state(payload: Dictionary)
signal node_depleted(payload: Dictionary)

signal resource_changed(payload: Dictionary)
signal grant_resources(payload: Dictionary)
signal purchase_request(payload: Dictionary)
signal purchase_result(payload: Dictionary)

signal build_selected(payload: Dictionary)
signal build_place_clicked(payload: Dictionary)
signal build_placed(payload: Dictionary)
signal build_destroyed(payload: Dictionary)
signal build_rejected(payload: Dictionary)
signal layout_snapshot(payload: Dictionary)
signal scanner_state(payload: Dictionary)
signal power_state_changed(payload: Dictionary)
signal turret_fired(payload: Dictionary)

signal rover_moved(payload: Dictionary)
signal rover_harvested(payload: Dictionary)
signal rover_fired(payload: Dictionary)
signal rover_damaged(payload: Dictionary)
signal rover_destroyed(payload: Dictionary)
signal rover_upgraded_ack(payload: Dictionary)

signal enemy_spawned(payload: Dictionary)
signal enemy_positions(payload: Dictionary)
signal enemy_killed(payload: Dictionary)
signal enemy_attack(payload: Dictionary)
signal wave_started(payload: Dictionary)
signal wave_progress(payload: Dictionary)
signal wave_cleared(payload: Dictionary)

signal chronolith_damaged(payload: Dictionary)
signal chronolith_destroyed(payload: Dictionary)
signal chronolith_field_state(payload: Dictionary)
signal rewind_state(payload: Dictionary)
signal chronolith_active_triggered(payload: Dictionary)
signal rewind_window(payload: Dictionary)

signal input_move(payload: Dictionary)
signal input_fire(payload: Dictionary)
signal input_interact(payload: Dictionary)
signal player_activated_rewind(payload: Dictionary)
signal player_requested_upgrade(payload: Dictionary)
signal player_skip_calm(payload: Dictionary)

signal memory_event(payload: Dictionary)
signal memory_resolved(payload: Dictionary)
signal unlocks_loaded(payload: Dictionary)
signal unlock_purchased(payload: Dictionary)
signal meta_loaded(payload: Dictionary)
signal meta_bonuses(payload: Dictionary)
signal hub_start_requested(payload: Dictionary)

signal toast(payload: Dictionary)


func _ready() -> void:
	if Contracts.CONTRACT_VERSION != 1:
		push_warning("[Bus] unexpected CONTRACT_VERSION %d" % Contracts.CONTRACT_VERSION)
