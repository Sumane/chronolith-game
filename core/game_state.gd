extends Node
## Phase state machine: HUB → CALM → ASSAULT → (…repeat) → RESET → HUB.
## Owned by Core; transitions requested via main.gd only.

var current_phase: int = Contracts.Phase.HUB

func set_phase(phase: int) -> void:
	if current_phase == phase:
		return
	current_phase = phase
	Bus.phase_changed.emit({
		"phase": Contracts.phase_name(phase),
		"phase_id": phase,
	})

func is_in_gameplay() -> bool:
	return current_phase == Contracts.Phase.CALM or current_phase == Contracts.Phase.ASSAULT
