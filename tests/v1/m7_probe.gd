extends Node
## M7 probe: story, finale and one ending.
## e1 fresh profile: opening beat, warden/golem memory beats, the Vrax
##    mech gate (M13: every non-mech shot ignored, mech full), wave-20 finale —
##    completion recorded in the profile BEFORE the ending beat plays
## e2 with completion: death in the finale is a normal defeat and never
##    erases the recorded completion
## e3 with completion: a second victory skips the already-seen ending

var _ok := 0
var _fail := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _wait(n: int) -> void:
	# process frames fire even while a story beat pauses the tree
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

func _profile() -> Dictionary:
	var gp := ProjectSettings.globalize_path("user://chronolith_v1_profile.json")
	if not FileAccess.file_exists(gp):
		return {}
	var t := FileAccess.get_file_as_string(gp)
	var j: Variant = JSON.parse_string(t)
	return j if j is Dictionary else {}

func _boot() -> Node:
	var es := ResourceLoader.load("res://scenes/v1/entry.tscn") as PackedScene
	var e = es.instantiate()
	add_child(e)
	await _wait(40)
	return e

func _kill_all(entry: Node, with_mech_vrax: bool) -> void:
	for _r in 8:
		var es: Array = get_tree().get_nodes_in_group("enemy")
		if es.is_empty():
			return
		for e in es:
			if e is Vrax:
				e.damage(999, true, with_mech_vrax)
			elif e is Golem:
				e.damage(999, true)
			elif e is Warden:
				e.damage(999, true)
			else:
				e.damage(99)
		await get_tree().process_frame

func _run() -> void:
	_wipe()

	# ------------------------------------------------ e1: fresh, full story
	var e1 = await _boot()
	var d1: Node = e1.get_node("WaveDirector")
	await _wait(10)
	check("e1: opening beat opens on first boot (paused tree)",
		e1._beat_open and get_tree().paused)
	var beat_text := ""
	var bi: Node = e1.get_node_or_null("BeatUI")
	if bi != null:
		for n in bi.find_children("", "Label", true, false):
			beat_text += (n as Label).text
	check("e1: opening text is Vael's upload",
		beat_text.contains("VAEL") and beat_text.contains("Chronolith"))
	e1.beat_gate.skip()
	await _wait(10)
	check("e1: beat skip resumes the tree", not get_tree().paused and not e1._beat_open)
	check("e1: seen_opening persisted", _profile().get("story_flags", {}).get("seen_opening", false))

	# warden memory beat (wave 3 of the full plan spawns a real Warden)
	d1.wave = 3
	d1.call("debug_instant_wave", 1)
	await _wait(4)
	var ward: Node = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Warden and not (e is Vrax):
			ward = e
	check("e1: warden spawned on wave 3", ward != null)
	if ward != null:
		ward.damage(999, true)  # dies synchronously -> beat opens
		check("e1: warden_first memory beat opens", e1._beat_open)
		e1.beat_gate.skip()
		await _wait(10)
		check("e1: warden_first persisted",
			_profile().get("story_flags", {}).get("memories", {}).get("warden_first", false))
	await _kill_all(e1, false)
	await _wait(40)

	# Vrax gate on the full-plan final wave
	d1.wave = 20
	d1.call("debug_instant_wave", 0)  # 0 grunts + Vrax (warden slot) + Golem
	await _wait(4)
	var v: Node = d1.vrax
	check("e1: wave 20 spawns Vrax (a Warden-class boss)", v != null and v is Vrax)
	if v != null:
		v.damage(50, false)
		check("e1: Vrax immune to flat shots (hp 400)", v.hp == Vrax.BOSS_HP)
		v.damage(40, true, false)
		check("e1: non-mech pierce is ignored (mech mandatory)", v.hp == Vrax.BOSS_HP)
		v.damage(40, true, true)
		check("e1: mech heavy round deals full (400 -> 360)", v.hp == Vrax.BOSS_HP - 40)

	# golem memory beat, then the win
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Golem:
			e.damage(999, true)  # synchronous death -> golem_first beat
	check("e1: golem_first memory beat opens", e1._beat_open)
	e1.beat_gate.skip()
	await _wait(10)
	await _kill_all(e1, true)  # Vrax dies from the mech
	await _wait(10)
	check("e1: completion recorded in the profile before the ending",
		_profile().get("story_flags", {}).get("completion", false))
	check("e1: ending beat opens after the win (tree stays paused)",
		e1._beat_open and get_tree().paused)
	var end_text := ""
	var bi2: Node = e1.get_node_or_null("BeatUI")
	if bi2 != null:
		for n in bi2.find_children("", "Label", true, false):
			end_text += (n as Label).text
	check("e1: ending names the seal, the retreat and the NASA answer",
		end_text.contains("re-seals") and end_text.contains("NASA") and end_text.contains("home"))
	e1.beat_gate.skip()
	await _wait(10)
	check("e1: clear label after the ending (still paused)",
		e1._end_label.text.contains("CAMPAIGN CLEAR: 20 WAVES") and get_tree().paused)
	check("e1: ending_seen persisted",
		_profile().get("story_flags", {}).get("ending_seen", false))
	e1.queue_free()
	await _wait(20)

	# ------------------------------------------------ e2: death in the finale
	var e2 = await _boot()
	await _wait(10)
	check("e2: no opening beat on a returning profile", not e2._beat_open)
	var d2: Node = e2.get_node("WaveDirector")
	d2.wave = 20
	d2.call("debug_instant_wave", 0)
	await _wait(4)
	var crystal: Node = e2.get_node("Arena").get_node("Chronolith")
	crystal.damage(9999)
	await _wait(60)
	check("e2: finale defeat is a normal loss (R offered)",
		e2._end_label.text.contains("ATTEMPT LOST") and e2._end_label.text.contains("R"))
	check("e2: recorded completion survives a finale defeat",
		_profile().get("story_flags", {}).get("completion", false))
	check("e2: no ending beat on a defeat", not e2._beat_open)
	e2.queue_free()
	await _wait(20)

	# ------------------------------------------------ e3: ending skipped
	var e3 = await _boot()
	await _wait(10)
	check("e3: no opening beat on a returning profile", not e3._beat_open)
	var d3: Node = e3.get_node("WaveDirector")
	d3.wave = 20
	d3.call("debug_instant_wave", 0)
	await _wait(4)
	await _kill_all(e3, true)
	await _wait(10)
	check("e3: second victory skips the already-seen ending",
		e3._end_label.text.contains("ending skipped") and not e3._beat_open)
	check("e3: completion still recorded",
		_profile().get("story_flags", {}).get("completion", false))
	e3.queue_free()
	await _wait(10)

	print("== M7 probe: %d ok, %d fail ==" % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
