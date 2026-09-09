extends Node
## Input probe: every menu must be closable with its own keys, including
## while the tree is paused (the entry subtree is PAUSABLE and input-dead
## while paused — the gates live under the root for exactly this reason).
## Covers: research open/close (G and Esc), pause toggle stability, story
## beat close, restart gate on the end screen, and gate cleanup on exit.

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

func _labels(node: Node, out: Array) -> void:
	if node is Label:
		out.append(node)
	for c in node.get_children():
		_labels(c, out)

func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)

func _wipe() -> void:
	for pth in ["chronolith_v1_profile.json", "chronolith_v1_profile.json.bak", "chronolith_v1_profile.json.tmp"]:
		var gp := ProjectSettings.globalize_path("user://" + pth)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)

func _run() -> void:
	_wipe()
	var es := ResourceLoader.load("res://scenes/v1/entry.tscn") as PackedScene
	var e1 = es.instantiate()
	add_child(e1)
	await _wait(40)
	var d: Node = e1.get_node("WaveDirector")
	d.wave_plan = [3]
	await _wait(6)

	# the opening beat (story enabled) must open on first boot and close on a key
	await _wait(4)
	var open_text := ""
	var ui0: Node = e1.get_node_or_null("BeatUI")
	if ui0 != null:
		var l0: Array = []
		_labels(ui0, l0)
		for lb in l0:
			if (lb as Label).text.contains("VAEL"):
				open_text = (lb as Label).text
	check("opening beat opens on first boot (paused, Vael text)",
		e1.beat_gate.open and get_tree().paused and open_text.contains("VAEL"))
	_key(KEY_E)
	await _wait(3)
	check("opening beat closes with a key (tree restored)", not e1.beat_gate.open and not get_tree().paused)

	# research: G opens, G closes
	_key(KEY_G)
	await _wait(3)
	check("research opens with G (screen + paused tree)",
		e1.research_open and get_tree().paused)
	for f in 4:
		await _wait(1)
	check("research stays open and paused (no self-close)", e1.research_open and get_tree().paused)
	_key(KEY_G)
	await _wait(3)
	check("research closes with G (tree unpaused)", not e1.research_open and not get_tree().paused)

	# research: G opens, Esc closes
	_key(KEY_G)
	await _wait(3)
	check("research reopens with G", e1.research_open and get_tree().paused)
	_key(KEY_ESCAPE)
	await _wait(3)
	check("research closes with Esc (tree unpaused)", not e1.research_open and not get_tree().paused)

	# pause: Esc toggles both ways, repeatedly
	_key(KEY_ESCAPE)
	await _wait(3)
	check("pause opens with Esc (tree + overlay)", get_tree().paused and e1._overlay.visible)
	_key(KEY_ESCAPE)
	await _wait(3)
	check("pause closes with Esc (tree + overlay)", not get_tree().paused and not e1._overlay.visible)
	_key(KEY_ESCAPE)
	await _wait(3)
	check("pause reopens (toggle stability)", get_tree().paused)
	_key(KEY_ESCAPE)
	await _wait(3)
	check("pause closes again (toggle stability)", not get_tree().paused)

	# story beat: opens paused, any key closes it and restores the tree
	e1.call("_show_beat", "TEST BEAT TEXT")
	await _wait(3)
	var beat_open: bool = e1.beat_gate.open
	var ui: Node = e1.get_node_or_null("BeatUI")
	var beat_text := ""
	if ui != null:
		var l1: Array = []
		_labels(ui, l1)
		for lb in l1:
			if (lb as Label).text.contains("TEST BEAT TEXT"):
				beat_text = (lb as Label).text
	check("beat opens paused with its text", beat_open and get_tree().paused and beat_text.contains("TEST BEAT TEXT"))
	_key(KEY_E)
	await _wait(3)
	check("beat closes with any key (tree restored)", not e1.beat_gate.open and not get_tree().paused)

	# end screen: win the 3-wave campaign, then check the restart gate
	d.call("debug_instant_wave", 3)  # wave 1 of a 1-wave plan: grunts only
	await _wait(4)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.damage(99)
	await _wait(10)
	check("end screen shows after the win (paused)", e1._end_overlay.visible and get_tree().paused)
	var rg: Node = e1._restart_gate
	check("restart gate lives under the root (ALWAYS)",
		is_instance_valid(rg) and rg.get_parent() == get_tree().root
		and rg.process_mode == Node.PROCESS_MODE_ALWAYS
		and rg.restart.is_valid())

	e1.queue_free()
	await _wait(10)
	var leftovers := 0
	for c in get_tree().root.get_children():
		if c.name in ["BeatGate", "PauseGate", "ResearchGate"]:
			leftovers += 1
	check("all root gates are freed with the entry", leftovers == 0)

	print("== input probe: %d ok, %d fail ==" % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
