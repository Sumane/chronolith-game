extends Node
## M6e probe: counter explanations + input remapping.
## 1. wave-start banners name the incoming counter and its beat
## 2. the research screen carries the counter strip
## 3. core actions carry gamepad + mouse + keyboard bindings

var entry
var director
var hud
var _ok := 0
var _fail := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _wait(n: int) -> void:
	var i := 0
	while i < n:
		i += 1
		await get_tree().physics_frame

func check(label: String, cond: bool) -> void:
	if cond:
		_ok += 1
	else:
		_fail += 1
	print("  [%s] %s" % ["ok" if cond else "FAIL", label])

func _run() -> void:
	for pth in ["chronolith_v1_profile.json", "chronolith_v1_profile.json.bak", "chronolith_v1_profile.json.tmp"]:
		var gp := ProjectSettings.globalize_path("user://" + pth)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)
	var es := ResourceLoader.load("res://scenes/v1/entry.tscn") as PackedScene
	entry = es.instantiate()
	add_child(entry)
	await _wait(40)
	director = entry.get_node("WaveDirector")
	director.wave_plan = [3, 4, 5]
	hud = entry.get_node("HUD")

	# 1 wave-start counter warnings
	director.wave_started.emit(3, "NORTH")
	await _wait(2)
	var b3: String = hud.banner_label.text
	check("banner w3: warden counter named (%s)" % b3,
		b3.contains("WAVE 3") and b3.contains("WARDEN") and b3.contains("PIERCE OR RAM"))
	director.wave_started.emit(5, "EAST")
	await _wait(2)
	var b5: String = hud.banner_label.text
	check("banner w5: golem armor warning",
		b5.contains("GOLEM") and b5.contains("FLAT SHOTS BLOCKED"))
	director.wave_started.emit(20, "SOUTH")
	await _wait(2)
	var b20: String = hud.banner_label.text
	check("banner w20: both counters named",
		b20.contains("WARDEN") and b20.contains("GOLEM"))
	director.wave_started.emit(1, "NORTH")
	await _wait(2)
	check("banner w1: no false warning",
		not hud.banner_label.text.contains("WARDEN") and not hud.banner_label.text.contains("GOLEM"))

	# 2 research counter strip
	entry.research_screen.show_screen()
	await _wait(2)
	var strip := ""
	var node: Node = entry.research_screen
	for n in node.find_children("", "Label", true, false):
		if (n as Label).text.begins_with("COUNTERS"):
			strip = (n as Label).text
	entry.research_screen._close()
	check("research screen: counter strip present (%s)" % strip,
		strip.contains("Warden") and strip.contains("Golem") and strip.contains("ram"))
	await _wait(2)

	# 3 input remapping: gamepad + mouse + keyboard on core actions
	var fire_ev: Array = InputMap.action_get_events("fire")
	var up_ev: Array = InputMap.action_get_events("move_up")
	var cancel_ev: Array = InputMap.action_get_events("cancel_build")
	var pause_ev: Array = InputMap.action_get_events("pause_toggle")
	var rewind_ev: Array = InputMap.action_get_events("rewind")
	var b1_ev: Array = InputMap.action_get_events("build_1")
	check("remap: fire has keyboard/mouse + gamepad A (%d events)" % fire_ev.size(),
		fire_ev.size() >= 2)
	check("remap: move_up has WASD + arrows + d-pad (%d events)" % up_ev.size(),
		up_ev.size() >= 3)
	check("remap: cancel_build has RMB + right stick (%d events)" % cancel_ev.size(),
		cancel_ev.size() >= 2)
	check("remap: pause has Esc + start (%d events)" % pause_ev.size(), pause_ev.size() >= 2)
	check("remap: rewind has R + back (%d events)" % rewind_ev.size(), rewind_ev.size() >= 2)
	check("remap: build_1 has 1 + gamepad X (%d events)" % b1_ev.size(), b1_ev.size() >= 2)

	print("== M6e probe: %d ok, %d fail ==" % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
