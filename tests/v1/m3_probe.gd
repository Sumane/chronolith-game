extends Node
## M3 probe: engram-once, pause snapshot, purchase + effect, refund on save
## failure, checkpoint identity (no re-grant), nested-menu guard, backup
## recovery, prerequisite invariant.
var entry
var e2
var e3
var _ok := 0
var _fail := 0
var _frames := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_run()

func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > 6000:
		print("== M3 probe: TIMEOUT ==")
		get_tree().quit(1)

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

func _boot_entry() -> Node:
	var es := ResourceLoader.load("res://scenes/v1/entry.tscn") as PackedScene
	var e = es.instantiate()
	e.story_enabled = false  # story beats off: probe drives the flow itself
	add_child(e)
	await _wait(40)
	return e

func _kill_enemies(_e) -> void:
	# direct damage: probe tests wave/engram flow, not lines of sight
	for en in get_tree().get_nodes_in_group("enemy"):
		en.call("damage", 99)

func _run() -> void:
	# clean slate
	for pth in ["chronolith_v1_profile.json", "chronolith_v1_profile.json.bak", "chronolith_v1_profile.json.tmp"]:
		var gp := ProjectSettings.globalize_path("user://" + pth)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)

	entry = await _boot_entry()
	var rig = entry.get_node("PlayerRig")
	var director = entry.get_node("WaveDirector")
	var crystal = entry.get_node("Arena").crystal
	var knowledge = entry.knowledge
	var screen = entry.research_screen
	var attempt_id: String = entry.attempt_id

	check("boot: fresh profile, new attempt identity", attempt_id != "" and knowledge.balance() == 0 and entry.profile_recovered == false)

	# wave 1 -> engram, idempotent
	director.call("debug_instant_wave", 1)
	await _wait(30)
	_kill_enemies(entry)
	await _wait(40)
	check("wave clear: +1 engram, receipt blocks second grant",
		knowledge.balance() == 1 and knowledge.grant_wave(attempt_id, 1) == false)

	# long planning pause: simulation must not drift
	var s_pre := [director.prep_left, entry.cargo, crystal.integrity, rig.get_node("Rover").global_position.x]
	entry._open_research()
	check("research opens only in prep, pauses tree", entry.research_open and get_tree().paused and entry._pause_gate.disabled)
	await _wait(240)
	screen._on_buy("f1")
	check("research purchase: balance 1->0, f1 learned", knowledge.balance() == 0 and knowledge.researched.has("f1"))
	screen._close()
	var s_post := [director.prep_left, entry.cargo, crystal.integrity, rig.get_node("Rover").global_position.x]
	check("no drift across 4 s planning pause", s_pre == s_post and not get_tree().paused and not entry._pause_gate.disabled)

	# researched wall spawns with the +30 hp effect
	entry.build.start_build("wall")
	rig.debug_set_aim(Vector3(10.0, entry.get_node("Arena").height_at(10.0, 10.0), 10.0))
	var wres: Dictionary = entry.build.commit()
	check("researched wall spawns with +30 hp", wres.get("ok", false) and (wres["building"] as Node).get("max_hp") == 90 and entry.cargo == 4)

	# refund invariant: save failure must roll the purchase back
	director.call("debug_instant_wave", 1)
	await _wait(30)
	_kill_enemies(entry)
	await _wait(40)
	check("wave 2 cleared: balance back to 1", knowledge.balance() == 1)
	entry._open_research()
	entry.profile.path = "user://m3_probe_bad/sub/x.json"
	screen._on_buy("t1")
	check("save failure refunds purchase", knowledge.balance() == 1 and not knowledge.researched.has("t1"))
	entry.profile.path = "user://chronolith_v1_profile.json"
	screen._close()

	# checkpoint save, then a fresh entry must resume the SAME attempt identity
	entry._save_profile()
	var cargo_saved: int = entry.cargo
	var wave_saved: int = director.wave
	e2 = await _boot_entry()
	var d2 = e2.get_node("WaveDirector")
	var k2 = e2.knowledge
	check("checkpoint load: same attempt id, wave, cargo, knowledge",
		e2.attempt_id == attempt_id and d2.wave == wave_saved and e2.cargo == cargo_saved and k2.balance() == 1 and k2.researched.has("f1"))

	# re-clearing an already-cleared wave must not grant another engram
	d2.wave = 1
	d2.call("debug_instant_wave", 1)
	await _wait(30)
	_kill_enemies(e2)
	await _wait(40)
	check("reloaded wave-clear state does not re-grant engram", k2.balance() == 1)

	# nested menus cannot unpause combat
	e2._open_research()
	var guard: bool = e2.research_open and get_tree().paused and e2._pause_gate.disabled
	e2.research_screen._close()
	check("nested menu cannot unpause combat", guard and not get_tree().paused and not e2._pause_gate.disabled)

	# backup recovery: corrupt the main save, next boot must recover from .bak
	var gp := ProjectSettings.globalize_path("user://chronolith_v1_profile.json")
	var f := FileAccess.open(gp, FileAccess.WRITE)
	f.store_string("NOT JSON{{")
	f.close()
	e3 = await _boot_entry()
	check("corrupt save recovers from backup", e3.profile_recovered and e3.knowledge.balance() >= 1)

	# prerequisite invariant: t2 requires t1
	check("prerequisite: t2 blocked until t1", e3.knowledge.can_research("t2").get("reason", "") == "requires")

	print(String("== M3 probe: %d ok, %d fail ==") % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
