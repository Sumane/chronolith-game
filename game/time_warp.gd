class_name TimeWarp
extends Node
## M6 TEMPORAL line: stasis burst. Slows every enemy on the arena (the
## rover and the camera are unaffected). Tier comes from the knowledge
## ledger (x1: 0.7/2.5 s/12 s, x2: 0.5/5 s/10 s); entry decides the tier.
## Mounted as a child of the arena; enemies read factor() every frame.

var _left := 0.0    # remaining slowed time
var _cd := 0.0      # remaining recharge
var _factor := 1.0
var _dur := 0.0
var _cooldown := 12.0

func factor() -> float:
	return _factor if _left > 0.0 else 1.0

func active() -> bool:
	return _left > 0.0

func can_burst() -> bool:
	return _cd <= 0.0

## Returns false while recharging.
func burst(p_factor: float, p_dur: float, p_cooldown: float) -> bool:
	if not can_burst():
		return false
	_factor = p_factor
	_dur = p_dur
	_cooldown = p_cooldown
	_left = p_dur
	_cd = p_cooldown
	return true

func _physics_process(delta: float) -> void:
	if _left > 0.0:
		_left = maxf(0.0, _left - delta)
		if _left == 0.0:
			_factor = 1.0
	_cd = maxf(0.0, _cd - delta)
