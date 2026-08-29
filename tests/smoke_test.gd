extends Node
## Headless smoke test:
##   godot --headless --path . res://tests/smoke_test.tscn
## Boots the real composition root and drives the Bus like a player would.
## Exit code 0 = pass, 1 = fail.

var fails: Array = []
var checks := 0

const EnemyScript := preload("res://modules/waves/internal/enemy.gd")

func _ready() -> void:
	_run()

func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  ok    %s" % label)
	else:
		fails.append(label)
		printerr("  FAIL  %s" % label)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _run() -> void:
	await get_tree().process_frame
	print("== CHRONOLITH smoke ==")

	# ---- 1. every script compiles
	var script_paths := [
		"res://core/contracts.gd", "res://core/event_bus.gd", "res://core/game_state.gd",
		"res://core/bus_logger.gd", "res://core/input_map_setup.gd", "res://core/main.gd",
		"res://modules/environment/environment_controller.gd", "res://modules/environment/internal/mars_map.gd",
		"res://modules/economy/economy_controller.gd",
		"res://modules/chronolith/chronolith_controller.gd", "res://modules/chronolith/internal/crystal.gd",
		"res://modules/build/build_controller.gd", "res://modules/build/internal/building.gd", "res://modules/build/internal/ghost.gd",
		"res://modules/waves/waves_controller.gd", "res://modules/waves/internal/enemy.gd",
		"res://modules/rover/rover_controller.gd", "res://modules/rover/internal/rover_body.gd",
		"res://modules/meta/meta_controller.gd", "res://modules/meta/internal/save_store.gd", "res://modules/meta/internal/hub_screen.gd",
		"res://modules/ui/ui_controller.gd", "res://modules/ui/internal/hud.gd",
		"res://modules/ui/internal/build_menu.gd", "res://modules/ui/internal/input_forwarder.gd",
		"res://modules/audio/audio_controller.gd",
	]
	for p: String in script_paths:
		check(ResourceLoader.load(p) != null, "compiles: %s" % p)

	# ---- data files parse
	for jp in [
		"res://core/data/sol_timing.json",
		"res://modules/environment/data/maps.json", "res://modules/environment/data/storm_tables.json",
		"res://modules/economy/data/starting_resources.json", "res://modules/economy/data/costs.json",
		"res://modules/chronolith/data/chronolith.json",
		"res://modules/build/data/buildings.json", "res://modules/build/data/grid_rules.json",
		"res://modules/waves/data/enemy_types.json", "res://modules/waves/data/wave_tables.json",
		"res://modules/rover/data/rover_stages.json", "res://modules/rover/data/weapons.json",
		"res://modules/meta/data/unlocks.json", "res://modules/meta/data/memory_fragments.json",
		"res://modules/audio/data/sound_map.json",
	]:
		check(typeof(Contracts.load_json(jp)) == TYPE_DICTIONARY, "json ok: %s" % String(jp).get_file())

	# ---- 2. boot the game
	var main: Node = (ResourceLoader.load("res://core/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await frames(10)
	var gs: Node = main.get_node("GameState")
	check(gs.current_phase == Contracts.Phase.HUB, "boots into HUB")

	# ---- 3. economy ledger discipline
	var got_result := {"ok": null}
	Bus.purchase_result.connect(func(p: Dictionary) -> void:
		if str(p.get("req_id", "")) == "test_too_expensive":
			got_result["ok"] = bool(p["ok"]))
	Bus.purchase_request.emit({"req_id": "test_too_expensive", "cost": {"SCRAP": 999999}, "tag": "test"})
	await frames(5)
	check(got_result["ok"] == false, "insufficient purchase rejected")
	Bus.grant_resources.emit({"resources": {"REGOLITH": 200, "SCRAP": 200, "RARE": 50}})
	await frames(3)

	# ---- 4. building placement via the real purchase path
	var placed := {"id": -1}
	Bus.build_placed.connect(func(p: Dictionary) -> void: placed["id"] = int(p["building_id"]), CONNECT_ONE_SHOT)
	var build_layer: Node = main.get_node("BuildLayer")
	check(build_layer.debug_place("turret", 700, 640), "placement request accepted (valid site)")
	await frames(8)
	check(int(placed["id"]) > 0, "turret placed via economy purchase")

	# ---- 5. start a run → CALM → skip to ASSAULT
	var saw_sol := {"v": 0}
	Bus.sol_changed.connect(func(p: Dictionary) -> void: saw_sol["v"] = int(p["sol"]))
	Bus.hub_start_requested.emit({})
	await frames(5)
	check(saw_sol["v"] == 1, "sol 1 began")
	check(gs.current_phase == Contracts.Phase.CALM, "phase CALM after run start")
	Bus.player_skip_calm.emit({})
	await frames(5)
	check(gs.current_phase == Contracts.Phase.ASSAULT, "skip calm → ASSAULT")

	# ---- 6. enemies spawn; laser damage resolves a kill
	var waves: Node = main.get_node("Waves")
	var deadline := 600
	while waves.alive_count() == 0 and deadline > 0:
		deadline -= 1
		await get_tree().physics_frame
	check(waves.alive_count() > 0, "enemies spawned during assault")
	var ids: Array = waves.debug_list_ids()
	if ids.size() > 0:
		var killed := {"id": -1}
		Bus.enemy_killed.connect(func(p: Dictionary) -> void: killed["id"] = int(p["enemy_id"]), CONNECT_ONE_SHOT)
		Bus.rover_fired.emit({"from": {"x": 0, "y": 0}, "to": {"x": 100, "y": 100}, "damage": 9999, "target_id": ids[0]})
		await frames(5)
		check(int(killed["id"]) == int(ids[0]), "fire event resolves kill + salvage")
	else:
		check(false, "had an enemy to shoot")

	# ---- 7. rewind active fires window
	var rewound := {"v": false}
	Bus.rewind_window.connect(func(_p: Dictionary) -> void: rewound["v"] = true, CONNECT_ONE_SHOT)
	Bus.player_activated_rewind.emit({})
	await frames(5)
	check(bool(rewound["v"]), "rewind_window emitted on activation")

	# ---- 8. chronolith death ends the run → RESET → HUB
	var end_reason := {"v": ""}
	Bus.run_ended.connect(func(p: Dictionary) -> void: end_reason["v"] = str(p["reason"]), CONNECT_ONE_SHOT)
	Bus.enemy_attack.emit({"enemy_id": -1, "type": "trooper", "target": "CHRONOLITH", "damage": 99999})
	await frames(5)
	check(end_reason["v"] == "chronolith_lost", "chronolith destruction ends run")
	deadline = 400
	while gs.current_phase != Contracts.Phase.HUB and deadline > 0:
		deadline -= 1
		await get_tree().physics_frame
	check(gs.current_phase == Contracts.Phase.HUB, "returns to HUB after reset")

	# ---- 9. hub unlock purchase with banked shards
	Bus.grant_resources.emit({"resources": {"SHARDS": 50}})
	await frames(3)
	var unlocked := {"v": ""}
	Bus.unlock_purchased.connect(func(p: Dictionary) -> void: unlocked["v"] = str(p["id"]), CONNECT_ONE_SHOT)
	main.get_node("Meta")._request_unlock("plating1")
	await frames(8)
	check(unlocked["v"] == "plating1", "hub unlock purchased permanently")
	check(FileAccess.file_exists("user://chronolith_save.json"), "save file persisted")

	# ---- 10. memory fragment dialog pauses & resolves cleanly
	main.get_node("Meta").debug_trigger_memory()
	await frames(3)
	check(get_tree().paused, "memory dialog pauses timeline")
	Bus.memory_resolved.emit({"choice": "purge"})
	await frames(3)
	check(not get_tree().paused, "memory resolve unpauses timeline")

	# ---- 11. second run: meta currency persists, in-run resources reset
	var ledger_now := {}
	Bus.resource_changed.connect(func(p: Dictionary) -> void: ledger_now = p.get("ledger", {}))
	await frames(2)
	var shard_before := int(ledger_now.get("SHARDS", 0))
	Bus.hub_start_requested.emit({})
	await frames(5)
	check(int(ledger_now.get("SHARDS", -1)) == shard_before, "banked shards survive run start (%d)" % shard_before)
	check(int(ledger_now.get("REGOLITH", -1)) == 40 and int(ledger_now.get("SCRAP", -1)) == 25, "in-run resources reset on run start")

	# ---- 12. meta_loaded handler seeds the ledger (boot path)
	var econ: Node = main.get_node("Economy")
	econ._on_meta_loaded({"SHARDS": 99})
	await frames(2)
	check(int(econ.ledger.get("SHARDS", -1)) == 99, "meta_loaded seeds banked shards into ledger")

	# ---- 13. rover upgrade via the U-key signal (was dead)
	Bus.grant_resources.emit({"resources": {"SCRAP": 200, "RARE": 50}})
	await frames(3)
	var rover: Node = main.get_node("Rover")
	Bus.player_requested_upgrade.emit({})
	await frames(6)
	check(int(rover.stage) == 1, "player_requested_upgrade resolves to stage 1")

	# ---- 14. repair via held E (was dead: result never resolved)
	var bid_new := {"id": -1}
	Bus.build_placed.connect(func(p: Dictionary) -> void: bid_new["id"] = int(p["building_id"]), CONNECT_ONE_SHOT)
	check(build_layer.debug_place("turret", 700, 640), "turret placement accepted (repair test)")
	await frames(8)
	var bid := int(bid_new["id"])
	var bld: Node = null
	for b: Node in build_layer.buildings:
		if is_instance_valid(b) and int(b.bid) == bid:
			bld = b
	check(bld != null, "turret exists for repair test")
	if bld != null:
		Bus.enemy_attack.emit({"enemy_id": -1, "type": "trooper", "target": "B%d" % bid, "damage": 40})
		await frames(3)
		var hp_after_damage := int(bld.hp)
		check(hp_after_damage == 50, "building took 40 damage (hp %d)" % hp_after_damage)
		Bus.rover_moved.emit({"x": 700, "y": 640, "stage": 1})
		Bus.input_interact.emit({"pressed": true})
		await frames(70) # ~1.2s -> at least two 0.4s repair ticks
		Bus.input_interact.emit({"pressed": false})
		var hp_after_repair := int(bld.hp)
		check(hp_after_repair > hp_after_damage, "held E repairs damaged building (hp %d -> %d)" % [hp_after_damage, hp_after_repair])

	# ---- 15. troopers block on walls (layout now injected into enemies)
	Bus.player_skip_calm.emit({})
	await frames(5)
	var cand: Node = null
	var deadline2 := 600
	while cand == null and deadline2 > 0:
		deadline2 -= 1
		for e: Node in waves.get_children():
			if is_instance_valid(e) and e.has_method("setup") and str(e.etype) != "stalker" and bool(e.alive):
				cand = e
				break
		await get_tree().physics_frame
	check(cand != null, "trooper alive for wall-block test")
	if cand != null and bld != null:
		await frames(2) # let the controller inject its layout ref
		cand.position = bld.position + Vector2(0, 24)
		var blk: Dictionary = cand._blocking_building()
		check(not blk.is_empty() and int(blk.get("id", -1)) == bid, "trooper detects adjacent wall and chews it")

	# ---- 16. burrowers target the map's tunnel holes (setup param path)
	check(waves.tunnel_holes.size() > 0, "map tunnel holes loaded from map data")
	var bur := EnemyScript.new()
	bur.setup(9001, "burrower", waves.types.get("burrower", {}), Vector2(100, 100), waves.tunnel_holes)
	check(bur.state == bur.STATE_UNDERGROUND, "burrower starts underground")
	var matched_hole := false
	for hh: Dictionary in waves.tunnel_holes:
		if bur.target_hole == Contracts.vec2_of(hh):
			matched_hole = true
	check(matched_hole, "burrower targets an actual map tunnel hole")
	bur.queue_free()

	# ---- 17. corrupt save is quarantined and recovers to defaults
	var sf := FileAccess.open("user://chronolith_save.json", FileAccess.WRITE)
	sf.store_string("{ definitely not json ]]")
	sf.close()
	var meta_node: Node = main.get_node("Meta")
	meta_node.store.load_save()
	check(int(meta_node.store.data.get("version", -1)) == 1, "corrupt save quarantined -> fresh defaults")
	meta_node.store.save() # leave a valid save behind for the next boot

	# ---- verdict
	print("== %d checks, %d failures ==" % [checks, fails.size()])
	for f: String in fails:
		printerr("FAILED: " + f)
	get_tree().quit(0 if fails.is_empty() else 1)
