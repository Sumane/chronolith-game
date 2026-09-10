extends Node
## M14 probe: enemy melee must reach PlayerRig.damage through the LIVE
## aggro path (enemies target the Rover body node; hp lives on the rig).
## No direct rig.damage() calls — the damage must come from the attacks.
## The rig's hp is reset between phases so leftovers cannot cascade.

var _ok := 0
var _fail := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _wait(n: int) -> void:
	var i := 0
	while i < n:
		i += 1
		await get_tree().process_frame

## Real-time wait: the headless frame rate is not a reliable 60 fps.
func _wait_s(sec: float) -> void:
	await (get_tree().create_timer(sec)).timeout

func check(label: String, cond: bool) -> void:
	if cond:
		_ok += 1
	else:
		_fail += 1
		print("  [FAIL] %s" % label)
	if cond:
		print("  [ok] %s" % label)

func _wipe() -> void:
	for pth in ["chronolith_v1_profile.json", "chronolith_v1_profile.json.bak", "chronolith_v1_profile.json.tmp"]:
		var gp := ProjectSettings.globalize_path("user://" + pth)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)

func _find_type(kind: String, cap_s: float) -> Node:
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < cap_s:
		for e in get_tree().get_nodes_in_group("enemy"):
			if kind == "warden" and e is Warden:
				return e
			if kind == "golem" and e is Golem:
				return e
		await _wait(10)
	return null

func _clear(d: Node) -> void:
	# deaths are harmless once the relay is in PREP (no clear cascade)
	d.state = d.State.PREP
	for e in get_tree().get_nodes_in_group("enemy"):
		e.call("damage", 9999)
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < 5.0 \
			and not get_tree().get_nodes_in_group("enemy").is_empty():
		await _wait(10)

func _run() -> void:
	_wipe()
	var es := ResourceLoader.load("res://scenes/v1/entry.tscn") as PackedScene
	var e1 = es.instantiate()
	e1.story_enabled = false
	add_child(e1)
	await _wait(40)
	var d: Node = e1.director
	var rig: Node = e1.get_node("PlayerRig")
	# the Rover body (the node enemies target) sits 8 m ahead of the rig origin
	var body: Node = e1.get_node("PlayerRig/Rover")
	var hud: Node = e1.hud

	# --- grunt: live wave 1, one grunt teleported into melee range
	d.wave = 1
	d.state = d.State.PREP
	d.early_start()
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < 15.0 \
			and get_tree().get_nodes_in_group("enemy").size() < 3:
		await _wait(10)
	check("live wave 1 spawns 3 grunts", get_tree().get_nodes_in_group("enemy").size() == 3)
	var g: Node = get_tree().get_nodes_in_group("enemy")[0]
	g.global_position = body.global_position + Vector3(1.5, 0.0, 0.0)
	g._cd = 0.0
	await _wait_s(2.5)  # ~3 hits at the 0.7 s cd, 5 dmg each
	var hp0: int = rig.hp
	check("grunt melee damages the rig (100 -> %d)" % hp0, hp0 <= 85)
	check("rover HUD bar follows live damage", hud.rover_bar_fill.size.x < 216.0)
	await _clear(d)

	# --- warden: live wave 3, Warden teleported into melee range
	rig.hp = 100
	d.wave = 3
	d.state = d.State.PREP
	d.early_start()
	var w: Node = await _find_type("warden", 25.0)
	check("live wave 3 includes a Warden", w != null)
	if w != null:
		w._state = "seek"
		w._cd = 0.0
		w.global_position = body.global_position + Vector3(0.0, 0.0, 1.6)
		await _wait_s(0.3)
		var hp1: int = rig.hp
		await _wait_s(3.0)  # ~2 hits at the 1.8 s cd, 12 dmg each
		check("warden melee damages the rig (%d -> %d)" % [hp1, rig.hp], rig.hp <= hp1 - 12)
	await _clear(d)

	# --- golem: direct spawn, teleported into range (regression on the
	# existing parent-hop route)
	rig.hp = 100
	var go: Node = Golem.new()
	e1.arena.add_child(go)
	go.goal = null  # isolate the rover route; no crystal melee interference
	go._rover = body  # the director sets this in _spawn_golem; we spawn directly
	go.position = body.global_position + Vector3(-1.6, 0.0, 0.0)
	await _wait_s(0.3)
	var hp2: int = rig.hp
	await _wait_s(2.5)  # the golem hits for 40
	check("golem melee damages the rig (%d -> %d)" % [hp2, rig.hp], rig.hp <= hp2 - 40)
	check("rig survived the probe with real hp", rig.hp > 0)

	e1.queue_free()
	await _wait(5)
	print("== rover_damage probe: %d ok, %d fail ==" % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
