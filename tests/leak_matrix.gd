extends Node
## Leak mini-matrix arm: boot + run + skip calm, then ONE candidate mechanic.
## ARM env: spawnwait | kill | rewind | killhub
var _t0: int = 0

func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	_probe()

func _mark(label: String) -> void:
	print("MARK t=%d %s" % [Time.get_ticks_msec() - _t0, label])

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _probe() -> void:
	var arm := OS.get_environment("LEAK_ARM")
	await get_tree().process_frame
	_mark("start arm=%s" % arm)
	var main: Node = (ResourceLoader.load("res://core/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(10)
	var gs: Node = main.get_node("GameState")
	var waves: Node = main.get_node("Waves")
	Bus.grant_resources.emit({"resources": {"REGOLITH": 200, "SCRAP": 200, "RARE": 50}})
	await _frames(3)
	var build_layer: Node = main.get_node("BuildLayer")
	build_layer.debug_place("turret", 700, 640)
	await _frames(8)
	Bus.hub_start_requested.emit({})
	await _frames(5)
	Bus.player_skip_calm.emit({})
	await _frames(5)
	_mark("assault")

	match arm:
		"spawnwait":
			var d := 600
			while waves.alive_count() == 0 and d > 0:
				d -= 1
				await get_tree().physics_frame
			_mark("spawnwait done n=%d" % int(waves.alive_count()))
		"kill":
			await _frames(120)
			var ids: Array = waves.debug_list_ids()
			if ids.size() > 0:
				Bus.rover_fired.emit({"from": {"x": 0, "y": 0}, "to": {"x": 100, "y": 100}, "damage": 9999, "target_id": ids[0]})
				await _frames(5)
				_mark("kill done")
		"rewind":
			await _frames(120)
			Bus.player_activated_rewind.emit({})
			await _frames(5)
			_mark("rewind done")
		"toasts":
			await _frames(120)
			for i in 6:
				Bus.toast.emit({"text": "TOAST %d — padding the stack" % i, "color": "#ffffff"})
				await get_tree().process_frame
			_mark("six toasts emitted")
		"killhub":
			await _frames(120)
			Bus.enemy_attack.emit({"enemy_id": -1, "type": "trooper", "target": "CHRONOLITH", "damage": 99999})
			await _frames(5)
			_mark("kill done, entering hub wait")
			var d2 := 400
			while gs.current_phase != Contracts.Phase.HUB and d2 > 0:
				d2 -= 1
				await get_tree().physics_frame
			_mark("hub reached phase=%d" % int(gs.current_phase))
		_:
			_mark("unknown arm")

	await _frames(60 * 25)
	_mark("idle_done phase=%d" % int(gs.current_phase))
	print("== LEAK MATRIX done ==")
	get_tree().quit()
