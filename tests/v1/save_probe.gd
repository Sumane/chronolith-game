extends Node
## M15 probe: save/resume must round-trip the FULL physical state of an
## attempt — buildings (with hp), deposits (depleted stays depleted), mech,
## nuke charges, endless flag, crystal integrity, cargo, wave — and a
## checkpoint saved with the crystal/rover dead must stay playable.

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
		print("  [FAIL] %s" % label)
	if cond:
		print("  [ok] %s" % label)

func _wipe() -> void:
	for pth in ["chronolith_v1_profile.json", "chronolith_v1_profile.json.bak", "chronolith_v1_profile.json.tmp"]:
		var gp := ProjectSettings.globalize_path("user://" + pth)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)

func _boot() -> Node:
	var es := ResourceLoader.load("res://scenes/v1/entry.tscn") as PackedScene
	var e1 = es.instantiate()
	e1.story_enabled = false
	add_child(e1)
	await _wait(40)
	return e1

## Place a building the same way commit() does, then damage it.
func _place(e1: Node, type: String, x: int, z: int, dmg: int) -> Node:
	var b: Node
	if type == "wall":
		b = load("res://building/wall.gd").new()
	else:
		b = load("res://building/turret.gd").new()
		b.set("combat", e1.build.combat)
	var c := Vector2i(x, z)
	b.position = e1.build.cell_center(c)
	b.set("cell", c)
	e1.build._apply_effects(b)
	e1.build.occupied[c] = b
	e1.arena.get_parent().add_child(b)
	b.call("damage", dmg)
	return b

func _run() -> void:
	_wipe()
	var e1: Node = await _boot()
	var arena1: Node = e1.arena
	var rig1: Node = e1.get_node("PlayerRig")

	# --- mutate the world the way real play does
	_place(e1, "wall", 12, 10, 20)      # 60-hp wall, damaged to 40
	_place(e1, "turret", 30, 30, 15)    # 40-hp turret, damaged to 25
	var dep0: Deposit = arena1.dep_group.get_children()[0]
	for i in 5:
		dep0.take()                      # deplete it (starts at 5)
	rig1.transform_to_mech()
	rig1.hp = 77
	e1.nuke_charge = 3
	arena1.crystal.integrity = 31
	e1.director.endless = true
	e1.director.wave = 7
	e1.director.state = e1.director.State.PREP
	e1.cargo = 42
	var aid: String = e1.attempt_id

	# --- save (the same call the game makes after a wave clear / attempt end)
	e1._save_profile()
	await _wait(2)
	e1.queue_free()
	await _wait(10)

	# --- boot a fresh entry: it must resume from the saved profile
	var e2: Node = await _boot()
	var arena2: Node = e2.arena
	var rig2: Node = e2.get_node("PlayerRig")
	check("resume keeps the attempt id", e2.attempt_id == aid)
	check("resume keeps wave 7", e2.director.wave == 7)
	check("resume keeps endless", e2.director.endless == true)
	check("resume keeps cargo", e2.cargo == 42)
	check("resume keeps nuke charges", e2.nuke_charge == 3)
	check("resume restores mech mode", rig2.mech_mode == true)
	check("resume restores rover hp 77", rig2.hp == 77)
	check("resume restores crystal integrity 31", arena2.crystal.integrity == 31)
	var bs: Array = e2.build.snapshot()
	check("resume restores both buildings", bs.size() == 2)
	var wall_ok := false
	var turret_ok := false
	for it in bs:
		if it["t"] == "wall" and it["c"] == [12, 10] and it["hp"] == 40:
			wall_ok = true
		if it["t"] == "turret" and it["c"] == [30, 30] and it["hp"] == 25:
			turret_ok = true
	check("wall restored at (12,10) with hp 40", wall_ok)
	check("turret restored at (30,30) with hp 25", turret_ok)
	check("build cells registered (no double place)", e2.build.occupied.has(Vector2i(12, 10)))
	check("depleted deposit stays depleted", (arena2.dep_group.get_children()[0] as Deposit).depleted == true)
	check("untouched deposit stays live", (arena2.dep_group.get_children()[1] as Deposit).depleted == false)

	# --- death edge: a checkpoint saved with the crystal/rover dead stays playable
	arena2.crystal.integrity = 0
	arena2.crystal.destroyed = true
	rig2.hp = 0
	e2._save_profile()
	await _wait(2)
	e2.queue_free()
	await _wait(10)

	var e3: Node = await _boot()
	check("dead crystal respawns whole", e3.arena.crystal.integrity == e3.arena.crystal.max_integrity)
	check("dead crystal not flagged destroyed", e3.arena.crystal.destroyed == false)
	check("dead rover respawns with hp", e3.get_node("PlayerRig").hp >= 1)
	check("still resumes wave 7", e3.director.wave == 7)

	e3.queue_free()
	await _wait(5)
	print("== save_probe: %d ok, %d fail ==" % [_ok, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
