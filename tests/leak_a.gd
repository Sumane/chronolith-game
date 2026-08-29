extends Node
## Leak bisect A: probe v2 core + smoke test's steps 4-8 equivalents
## (economy purchase test, spawn-wait loop, combat kill, rewind, chronolith kill).
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
	await get_tree().process_frame
	_mark("probe_start")
	var main: Node = (ResourceLoader.load("res://core/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(10)
	var gs: Node = main.get_node("GameState")
	_mark("game_booted")

	# economy test (smoke step 4): overpriced purchase must be rejected
	var rejected := {"v": false}
	Bus.purchase_result.connect(func(p: Dictionary) -> void: rejected["v"] = bool(p.get("ok", true)) == false, CONNECT_ONE_SHOT)
	Bus.purchase_request.emit({"req_id": "test_too_expensive", "cost": {"SCRAP": 999999}, "tag": "test"})
	await _frames(5)
	_mark("economy_test done rejected=%s" % str(rejected["v"]))

	Bus.grant_resources.emit({"resources": {"REGOLITH": 200, "SCRAP": 200, "RARE": 50}})
	await _frames(3)
	var build_layer: Node = main.get_node("BuildLayer")
	var placed := {"v": false}
	Bus.build_placed.connect(func(_p: Dictionary) -> void: placed["v"] = true, CONNECT_ONE_SHOT)
	build_layer.debug_place("turret", 700, 640)
	await _frames(8)
	_mark("turret_placed v=%s" % str(placed["v"]))

	var sol_saw := {"v": -1}
	Bus.sol_changed.connect(func(p: Dictionary) -> void: sol_saw["v"] = int(p.get("sol", -1)), CONNECT_ONE_SHOT)
	Bus.hub_start_requested.emit({})
	await _frames(5)
	Bus.player_skip_calm.emit({})
	await _frames(5)
	_mark("assault_started sol=%d" % int(sol_saw["v"]))

	var waves: Node = main.get_node("Waves")
	# smoke step 6: spawn-wait loop
	var deadline := 600
	while waves.alive_count() == 0 and deadline > 0:
		deadline -= 1
		await get_tree().physics_frame
	_mark("enemies_alive n=%d" % int(waves.alive_count()))
	# combat kill (smoke step 6b)
	var ids: Array = waves.debug_list_ids()
	if ids.size() > 0:
		var killed := {"id": -1}
		Bus.enemy_killed.connect(func(p: Dictionary) -> void: killed["id"] = int(p["enemy_id"]), CONNECT_ONE_SHOT)
		Bus.rover_fired.emit({"from": {"x": 0, "y": 0}, "to": {"x": 100, "y": 100}, "damage": 9999, "target_id": ids[0]})
		await _frames(5)
		_mark("combat_kill id=%d" % int(killed["id"]))
	# rewind (smoke step 7)
	var rewound := {"v": false}
	Bus.rewind_window.connect(func(_p: Dictionary) -> void: rewound["v"] = true, CONNECT_ONE_SHOT)
	Bus.player_activated_rewind.emit({})
	await _frames(5)
	_mark("rewind fired=%s" % str(rewound["v"]))
	# chronolith kill (smoke step 8)
	var end_reason := {"v": ""}
	Bus.run_ended.connect(func(p: Dictionary) -> void: end_reason["v"] = str(p["reason"]), CONNECT_ONE_SHOT)
	Bus.enemy_attack.emit({"enemy_id": -1, "type": "trooper", "target": "CHRONOLITH", "damage": 99999})
	await _frames(5)
	_mark("run_ended reason=%s" % str(end_reason["v"]))
	var deadline2 := 400
	while gs.current_phase != Contracts.Phase.HUB and deadline2 > 0:
		deadline2 -= 1
		await get_tree().physics_frame
	_mark("back_to_hub phase=%d" % int(gs.current_phase))

	await _frames(60 * 40)
	_mark("idle_40s_done")
	print("== LEAK PROBE A done ==")
	get_tree().quit()
