extends Node
## Headless memory probe v2 (diagnostic): boots the real game, runs one
## assault, kills the chronolith mid-run, then returns to HUB. Prints
## timestamped MARKers; the wrapper samples RSS externally every 2s.
## Correlating markers with RSS steps answers: does growth stop when the
## run ends, and when does it start?

var _t0: int = 0

func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	_probe()

func _mark(label: String) -> void:
	print("MARK t=%d %s" % [Time.get_ticks_msec() - _t0, label])

func _probe() -> void:
	await get_tree().process_frame
	_mark("probe_start")
	var main: Node = (ResourceLoader.load("res://core/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(10)
	var gs: Node = main.get_node("GameState")
	_mark("game_booted phase=%d" % int(gs.current_phase))

	Bus.grant_resources.emit({"resources": {"REGOLITH": 200, "SCRAP": 200, "RARE": 50}})
	await _frames(3)
	var build_layer: Node = main.get_node("BuildLayer")
	build_layer.debug_place("turret", 700, 640)
	await _frames(8)
	_mark("turret_placed")

	Bus.hub_start_requested.emit({})
	await _frames(5)
	Bus.player_skip_calm.emit({})
	await _frames(5)
	_mark("assault_started phase=%d" % int(gs.current_phase))

	# ride the assault for ~45s (troopers keep spawning/attacking)
	await _frames(60 * 45)
	var waves: Node = main.get_node("Waves")
	var n_alive := 0
	if waves != null:
		n_alive = waves.alive_count()
	_mark("mid_run phase=%d enemies_alive=%d" % [int(gs.current_phase), n_alive])

	Bus.enemy_attack.emit({"target": "CHRONOLITH", "damage": 99999})
	await _frames(10)
	_mark("chronolith_killed")

	# ride out RESET → HUB, idle in HUB for 30s
	for i in 30:
		await _frames(60)
		if gs.current_phase == Contracts.Phase.HUB:
			_mark("hub_reached after %ds" % (i + 1))
			break
	await _frames(60 * 30)
	_mark("hub_idle_30s_done")
	print("== MEM PROBE v2 done ==")
	get_tree().quit()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
