extends Node
## Leak bisect B: probe v2 boot + smoke test's steps 9-17 verbatim
## (hub unlock, memory dialog pause, second run, meta seed, upgrade,
## held-E repair, wall-block, burrower setup, corrupt save quarantine).
const EnemyScript := preload("res://modules/waves/internal/enemy.gd")

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
	_mark("game_booted phase=%d" % int(gs.current_phase))

	var build_layer: Node = main.get_node("BuildLayer")

	# ---- 9. hub unlock purchase with banked shards
	Bus.grant_resources.emit({"resources": {"SHARDS": 50}})
	await _frames(3)
	var unlocked := {"v": ""}
	Bus.unlock_purchased.connect(func(p: Dictionary) -> void: unlocked["v"] = str(p["id"]), CONNECT_ONE_SHOT)
	main.get_node("Meta")._request_unlock("plating1")
	await _frames(8)
	_mark("step9 unlock=%s" % str(unlocked["v"]))
	_mark("step9 save_exists=%s" % str(FileAccess.file_exists("user://chronolith_save.json")))

	# ---- 10. memory fragment dialog pauses & resolves cleanly
	main.get_node("Meta").debug_trigger_memory()
	await _frames(3)
	_mark("step10 paused=%s" % str(get_tree().paused))
	Bus.memory_resolved.emit({"choice": "purge"})
	await _frames(3)
	_mark("step10 unpaused=%s" % str(not get_tree().paused))

	# ---- 11. second run: meta currency persists, in-run resources reset
	var ledger_now := {}
	Bus.resource_changed.connect(func(p: Dictionary) -> void: ledger_now = p.get("ledger", {}))
	await _frames(2)
	var shard_before := int(ledger_now.get("SHARDS", 0))
	Bus.hub_start_requested.emit({})
	await _frames(5)
	_mark("step11 shards=%d reg=%d scrap=%d" % [int(ledger_now.get("SHARDS", -1)), int(ledger_now.get("REGOLITH", -1)), int(ledger_now.get("SCRAP", -1))])

	# ---- 12. meta_loaded handler seeds the ledger
	var econ: Node = main.get_node("Economy")
	econ._on_meta_loaded({"SHARDS": 99})
	await _frames(2)
	_mark("step12 ledger_shards=%d" % int(econ.ledger.get("SHARDS", -1)))

	# ---- 13. rover upgrade via U-key signal
	Bus.grant_resources.emit({"resources": {"SCRAP": 200, "RARE": 50}})
	await _frames(3)
	var rover: Node = main.get_node("Rover")
	Bus.player_requested_upgrade.emit({})
	await _frames(6)
	_mark("step13 rover_stage=%d" % int(rover.stage))

	# ---- 14. repair via held E
	var bid_new := {"id": -1}
	Bus.build_placed.connect(func(p: Dictionary) -> void: bid_new["id"] = int(p["building_id"]), CONNECT_ONE_SHOT)
	build_layer.debug_place("turret", 700, 640)
	await _frames(8)
	var bid := int(bid_new["id"])
	var bld: Node = null
	for b: Node in build_layer.buildings:
		if is_instance_valid(b) and int(b.bid) == bid:
			bld = b
	_mark("step14 building_found=%s" % str(bld != null))
	if bld != null:
		Bus.enemy_attack.emit({"enemy_id": -1, "type": "trooper", "target": "B%d" % bid, "damage": 40})
		await _frames(3)
		var hp_after_damage := int(bld.hp)
		_mark("step14 hp_after_damage=%d" % hp_after_damage)
		Bus.rover_moved.emit({"x": 700, "y": 640, "stage": 1})
		Bus.input_interact.emit({"pressed": true})
		await _frames(70)
		Bus.input_interact.emit({"pressed": false})
		_mark("step14 hp_after_repair=%d" % int(bld.hp))

	# ---- 15. troopers block on walls
	var waves: Node = main.get_node("Waves")
	Bus.player_skip_calm.emit({})
	await _frames(5)
	var cand: Node = null
	var deadline2 := 600
	while cand == null and deadline2 > 0:
		deadline2 -= 1
		for e: Node in waves.get_children():
			if is_instance_valid(e) and e.has_method("setup") and str(e.etype) != "stalker" and bool(e.alive):
				cand = e
				break
		await get_tree().physics_frame
	_mark("step15 trooper_found=%s" % str(cand != null))
	if cand != null and bld != null:
		await _frames(2)
		cand.position = bld.position + Vector2(0, 24)
		var blk: Dictionary = cand._blocking_building()
		_mark("step15 block_id=%d (expect %d)" % [int(blk.get("id", -1)), bid])

	# ---- 16. burrower targets tunnel holes
	_mark("step16 holes=%d" % int(waves.tunnel_holes.size()))
	var bur := EnemyScript.new()
	bur.setup(9001, "burrower", waves.types.get("burrower", {}), Vector2(100, 100), waves.tunnel_holes)
	_mark("step16 burrower_underground=%s" % str(bur.state == bur.STATE_UNDERGROUND))
	bur.queue_free()

	# ---- 17. corrupt save quarantined
	var sf := FileAccess.open("user://chronolith_save.json", FileAccess.WRITE)
	sf.store_string("{ definitely not json ]]")
	sf.close()
	var meta_node: Node = main.get_node("Meta")
	meta_node.store.load_save()
	_mark("step17 save_version=%d" % int(meta_node.store.data.get("version", -1)))
	meta_node.store.save()

	await _frames(60 * 20)
	_mark("idle_20s_done phase=%d" % int(gs.current_phase))
	print("== LEAK PROBE B done ==")
	get_tree().quit()
