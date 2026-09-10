extends Node
## M12 probe: enemy overhead health bars + rover (top-left) and crystal
## (bottom-center) HUD bars.

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

func check(label: String, cond: bool) -> void:
	if cond:
		_ok += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["ok" if cond else "FAIL", label])

func _wipe() -> void:
	for pth in ["chronolith_v1_profile.json", "chronolith_v1_profile.json.bak", "chronolith_v1_profile.json.tmp"]:
		var gp := ProjectSettings.globalize_path("user://" + pth)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)

func _run() -> void:
	_wipe()
	var es := ResourceLoader.load("res://scenes/v1/entry.tscn") as PackedScene
	var e1 = es.instantiate()
	e1.story_enabled = false
	add_child(e1)
	await _wait(40)
	var rig: Node = e1.get_node("PlayerRig")
	var d: Node = e1.director
	var hud: Node = e1.hud
	var arena: Node = e1.arena

	# --- grunts: hidden at full hp, partial after damage
	d.wave_plan = [4]
	d.call("debug_instant_wave", 4)
	await _wait(10)
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	check("4 grunts spawned", enemies.size() == 4)
	var full_hidden := true
	for e in enemies:
		if e.hp_bar == null or e.hp_bar.visible:
			full_hidden = false
	check("bars exist and are hidden at full hp", full_hidden)
	var g0: Node = enemies[0]
	var bar0: Node = g0.hp_bar
	g0.damage(8)
	await _wait(2)
	check("damaged grunt shows its bar", bar0.visible)
	check("bar fill matches remaining fraction",
		is_instance_valid(bar0._fill) and absf(bar0._fill.scale.x - 0.6) < 0.02)

	# --- warden: same wiring, armor-aware fraction
	var wp: Vector3 = Vector3(6.0, arena.height_at(6.0, 6.0) + 0.5, 6.0)
	var w: Node = d.debug_spawn_warden(wp)
	await _wait(6)
	w.damage(50)  # armor 5 -> 45 off 150 -> 105/150 = 0.7
	await _wait(2)
	check("warden bar appears on damage", w.hp_bar.visible)
	check("warden bar fraction is armor-aware",
		absf(w.hp_bar._fill.scale.x - 0.7) < 0.02)

	# --- golem: minimal direct spawn, same wiring
	var g: Node = Golem.new()
	arena.add_child(g)
	g.position = Vector3(-6.0, arena.height_at(-6.0, 6.0) + 0.5, 6.0)
	await _wait(4)
	check("golem bar hidden at full hp", g.hp_bar != null and not g.hp_bar.visible)
	g.damage(120)
	await _wait(2)
	check("golem bar appears and is partial", g.hp_bar.visible and g.hp_bar._fill.scale.x < 1.0)

	# --- rover HUD bar: full at boot, shrinks on damage
	check("rover bar starts full",
		absf(hud.rover_bar_fill.size.x - 216.0) < 1.0)
	rig.damage(30)
	await _wait(2)
	check("rover bar shrinks on damage (70/100)",
		absf(hud.rover_bar_fill.size.x - 216.0 * 0.7) < 1.5)

	# --- crystal HUD bar: bottom-center, shrinks on damage
	check("crystal bar starts full",
		absf(hud.crystal_bar_fill.size.x - 256.0) < 1.0)
	arena.crystal.damage(15)
	await _wait(2)
	check("crystal bar shrinks on damage (35/50)",
		absf(hud.crystal_bar_fill.size.x - 256.0 * 0.7) < 1.5)

	# --- death: bar freed with the enemy
	g0.damage(999)
	await _wait(110)  # death animation timer (0.6 s) + frame slack
	check("killed grunt (and its bar) is freed", not is_instance_valid(g0))

	e1.queue_free()
	await _wait(5)
	print("== hpbar probe: %d ok, %d fail ==" % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
