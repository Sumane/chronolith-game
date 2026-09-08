extends Node3D
## M2 composition root: arena + combat + rig + waves + build + flow + HUD.
## Wallet (scrap cargo) lives here for M2; a proper Economy owner comes later.

const START_CARGO := 6

var cargo := START_CARGO
var rig: PlayerRig
var combat: Combat
var arena
var time: TimeWarp
var flow: GameFlow
var director: WaveDirector
var build: BuildService
var knowledge: Knowledge
var profile: ProfileStore
var attempt_id := ""
var research_screen: ResearchScreen
var research_open := false
var nuke_charge := 1
var _warden_event_t := 0.0
var profile_recovered := false
var _saved_attempt_id := ""
var _saved_wave := 0
var _saved_cargo := 0
var hud: HudLayer
var _overlay: CanvasLayer
var _end_overlay: CanvasLayer
var _end_label: Label
var _pause_gate: PauseGate
var _banner_t := 0.0
var _banner := ""
var _hud_t := 0.0

func _ready() -> void:
	# explicit pause semantics: this subtree must honor tree.paused even when
	# embedded under an ALWAYS parent (headless probes)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	InputSetup.setup()
	_register_actions()
	arena = (ResourceLoader.load("res://scenes/v1/arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	# M6 TEMPORAL: stasis burst state lives on the arena (enemies hold arena refs)
	time = TimeWarp.new()
	time.name = "TimeWarp"
	arena.add_child(time)
	flow = GameFlow.new()
	flow.name = "Flow"
	add_child(flow)
	combat = Combat.new()
	combat.name = "Combat"
	add_child(combat)
	rig = (ResourceLoader.load("res://player/player_rig.tscn") as PackedScene).instantiate()
	rig.name = "PlayerRig"
	add_child(rig)
	director = WaveDirector.new()
	director.name = "WaveDirector"
	director.arena = arena
	director.crystal = arena.crystal
	director.rover = rig.get_node("Rover")
	add_child(director)
	build = BuildService.new()
	build.name = "BuildService"
	build.arena = arena
	build.wallet = self
	build.combat = combat
	build.aim_source = rig
	add_child(build)
	knowledge = Knowledge.new()
	profile = ProfileStore.new()
	_load_profile()
	var efs0: Dictionary = knowledge.applied()
	rig.apply_research(efs0)
	# M6 f3: Aegis Membrane — the next attempt's crystal starts shielded
	var shield: int = int(efs0.get("crystal_shield", 0.0))
	if shield > 0:
		arena.crystal.max_integrity += shield
		arena.crystal.integrity += shield
	build.knowledge = knowledge
	research_screen = ResearchScreen.new()
	research_screen.name = "ResearchScreen"
	research_screen.knowledge = knowledge
	research_screen.on_purchase = _research_save
	research_screen.on_close = _research_closed
	add_child(research_screen)
	hud = (ResourceLoader.load("res://ui/hud.tscn") as PackedScene).instantiate() as HudLayer
	hud.name = "HUD"
	add_child(hud)
	_build_pause_overlay()
	_build_end_overlay()
	_wire()
	_resume_checkpoint()
	_refresh_hud()
	print("M2_ENTRY_READY")

func _wire() -> void:
	rig.fired.connect(_on_fired)
	rig.pause_toggled.connect(_on_pause_toggled)
	rig.hp_changed.connect(_on_rover_hp)
	rig.harvest_done.connect(_on_harvest)
	rig.repair_done.connect(_on_repair)
	arena.crystal.damaged.connect(func(hp: int) -> void: _refresh_hud())
	arena.crystal.destroyed_signal.connect(func() -> void: flow.on_crystal_lost())
	director.wave_started.connect(_on_wave_started)
	director.wave_cleared.connect(_on_wave_cleared)
	director.warden_event.connect(_on_warden_event)
	director.attempt_won.connect(func() -> void: flow.on_won())
	flow.ended.connect(_on_ended)
	build.build_placed.connect(func(_b: Node, _c: Vector2i) -> void:
		_refresh_hud()
		_set_banner("PLACED " + build.last_type().to_upper() + " (repair: E near it)")
	)

# ------------------------------------------------------------- wallet --------

func spend(n: int) -> bool:
	if cargo < n:
		return false
	cargo -= n
	_refresh_hud()
	return true

func gain(n: int) -> void:
	cargo += n
	_refresh_hud()

func spendable(n: int) -> bool:
	return cargo >= n

# ------------------------------------------------------------- input ---------

func _unhandled_input(event: InputEvent) -> void:
	if not flow.running:
		return
	if event.is_action_pressed("build_wall"):
		_start_build("wall")
	elif event.is_action_pressed("build_turret"):
		_start_build("turret")
	elif event.is_action_pressed("cancel_build"):
		build.cancel()
		rig.build_locked = false
	elif event.is_action_pressed("early_start"):
		director.early_start()
	elif event.is_action_pressed("research_toggle"):
		_open_research()
	elif event.is_action_pressed("ram"):
		if rig.ram():
			_set_banner("RAM! (-%d rover hp)" % PlayerRig.RAM_COST)
	elif event.is_action_pressed("nuke"):
		_fire_nuke()
	elif event.is_action_pressed("mech_transform"):
		_try_transform_mech()
	elif event.is_action_pressed("debug_golem"):
		_spawn_golem()
	elif event.is_action_pressed("time_burst"):
		_try_time_burst()
	elif event.is_action_pressed("restart_attempt"):
		get_tree().reload_current_scene()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and build.active:
		var res: Dictionary = build.commit()
		if not res.get("ok", false):
			_set_banner("CANNOT PLACE: " + str(res.get("reason", "")))
	elif event.is_action_pressed("pause_toggle") and build.active:
		build.cancel()
		rig.build_locked = false

func _start_build(type: String) -> void:
	build.start_build(type)
	rig.build_locked = true
	_set_banner("PLACING " + type.to_upper() + " (LMB place / X or Esc cancel) — " + str(BuildService.COSTS[type]) + " scrap")

func _register_actions() -> void:
	# InputSetup.setup() already provides move_*, fire (Space/LMB), interact (E),
	# pause_toggle (Esc), cancel_build (X/RMB). v1-specific additions:
	_add_key("restart_attempt", KEY_R)
	_add_key("build_wall", KEY_1)
	_add_key("build_turret", KEY_2)
	_add_key("early_start", KEY_N)
	_add_key("research_toggle", KEY_G)
	_add_key("ram", KEY_SHIFT)
	_add_key("nuke", KEY_F)
	_add_key("mech_transform", KEY_T)
	_add_key("debug_golem", KEY_B)
	_add_key("time_burst", KEY_C)

func _add_key(action: String, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var k := InputEventKey.new()
	k.keycode = keycode
	InputMap.action_add_event(action, k)

# ------------------------------------------------------------- callbacks -----

func _on_fired(from: Vector3, to: Vector3) -> void:
	if rig.mech_mode:
		combat.fire(from, to, [rig.rover_rid()], MechData.GUN_DMG, true)
	else:
		combat.fire(from, to, [rig.rover_rid()])

func _on_rover_hp(hp: int) -> void:
	_refresh_hud()
	if hp <= 0 and flow.running:
		flow.on_rover_lost()

func _on_harvest(d: Node) -> void:
	if d is Deposit and d.take() > 0:
		gain(1)
		_set_banner("+1 SCRAP (hold E to keep harvesting)")

func _on_repair(b: Node) -> void:
	if b is BuildingBase and cargo >= 1 and b.hp < b.max_hp:
		spend(1)
		b.repair(10)
		_set_banner("REPAIRED +10 (1 scrap)")

func _on_wave_started(wave: int, direction: String) -> void:
	_set_banner("WAVE %d INBOUND FROM THE %s — HOLD THE CRYSTAL" % [wave, direction])

func _on_wave_cleared(wave: int) -> void:
	var got := knowledge.grant_wave(attempt_id, wave)
	if got:
		_set_banner("WAVE %d CLEARED — +1 ENGRAM (G: RESEARCH)" % wave)
		_save_profile()
	else:
		_set_banner("WAVE %d CLEARED (ENGRAM ALREADY RECORDED)" % wave)

func _on_ended(result: String) -> void:
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_pause_gate.disabled = true
	if result == "win":
		knowledge.grant_wave(attempt_id, WaveDirector.WAVE_SIZES.size())
	_save_profile()
	if result == "win":
		_end_label.text = "PROTOTYPE RESULT: THREE-WAVE WIN\n(R — new attempt)"
	else:
		var reason := "the crystal was destroyed" if result == "lost_crystal" else "the rover was destroyed"
		_end_label.text = "ATTEMPT LOST — " + reason + "\n(R — new attempt)"
	_end_overlay.visible = true

func _on_pause_toggled(paused: bool) -> void:
	_overlay.visible = paused

# ------------------------------------------------------------- M3 knowledge --

func _load_profile() -> void:
	var loaded: Dictionary = profile.load()
	if not loaded.get("ok", false):
		return
	profile_recovered = bool(loaded.get("recovered", false))
	var data: Dictionary = loaded["data"]
	knowledge.restore(data.get("knowledge", {}))
	var att: Dictionary = data.get("attempt", {})
	if att.size() > 0:
		_saved_attempt_id = str(att.get("id", ""))
		_saved_wave = int(att.get("wave", 0))
		_saved_cargo = int(att.get("cargo", 0))

func _resume_checkpoint() -> void:
	if _saved_attempt_id != "" and _saved_wave > 0:
		attempt_id = _saved_attempt_id
		cargo = _saved_cargo
		director.wave = _saved_wave
		director.state = WaveDirector.State.PREP
		director.prep_left = WaveDirector.PREP_TIME
		_set_banner("CHECKPOINT RESTORED: WAVE %d OF 3" % _saved_wave)
	else:
		attempt_id = _new_attempt_id()

func _new_attempt_id() -> String:
	return str(Time.get_ticks_msec()) + "-" + str(randi() % 100000)

func _profile_data() -> Dictionary:
	var d := {
		"schema_version": ProfileStore.SCHEMA_VERSION,
		"knowledge": knowledge.snapshot(),
		"story_flags": {},
	}
	if flow.running:
		d["attempt"] = {"id": attempt_id, "wave": director.wave, "cargo": cargo}
	else:
		d["attempt"] = {}
	return d

func _save_profile() -> Dictionary:
	return profile.save(_profile_data())

func _research_save(_id: String) -> Dictionary:
	var d := _save_profile()
	if d.get("ok", false):
		_set_banner("RESEARCHED — ENGRAM SPENT (SAVED)")
	return d

func _fire_nuke() -> void:
	if not flow.running:
		return
	if nuke_charge <= 0:
		_set_banner("NO NUKE CHARGES LEFT")
		return
	nuke_charge -= 1
	for en in get_tree().get_nodes_in_group("enemy"):
		if en is Warden:
			en.call("damage", 9999, true)
		else:
			en.call("damage", 9999)
	_set_banner("EMERGENCY NUKE — FIELD CLEARED (charges left: %d)" % nuke_charge)
	_refresh_hud()

func debug_nuke() -> void:
	_fire_nuke()

func _try_transform_mech() -> void:
	if rig.mech_mode:
		_set_banner("ALREADY IN THE MECH")
		return
	if not knowledge.researched.has("mech"):
		_set_banner("RESEARCH THE HYBRID CHASSIS FIRST (G)")
		return
	if cargo < MechData.BUILD_COST:
		_set_banner("MECH NEEDS %d SCRAP (HAVE %d)" % [MechData.BUILD_COST, cargo])
		return
	spend(MechData.BUILD_COST)
	rig.transform_to_mech()
	_set_banner("HYBRID MECH ONLINE — HEAVY PIERCING GUN (T: no de-transform in M5)")
	_refresh_hud()

func _spawn_golem() -> void:
	if not flow.running:
		return
	var rover = rig.get_node("Rover")
	var g: Golem = load("res://combat/golem.gd").new()
	var p: Vector3 = rover.global_position + Vector3(0, 0.5, -10.0)
	if arena != null and arena.has_method("height_at"):
		p.y = arena.height_at(p.x, p.z) + 0.5
	g.position = p
	g.goal = arena.crystal
	g.arena = arena
	g._rover = rover
	g.golem_event.connect(_on_golem_event)
	arena.get_parent().add_child(g)
	_set_banner("COMMAND TARGET SPAWNED — ARMOR 20: ONLY PIERCING BREAKS IT")

func _try_time_burst() -> void:
	if not knowledge.researched.has("x1"):
		return
	var efs: Dictionary = knowledge.applied()
	var f := float(efs.get("time_factor", 1.0))
	var dur := 2.5
	var cd := 12.0
	if knowledge.researched.has("x2"):
		dur = 5.0
		cd = 10.0
	if time.burst(f, dur, cd):
		_set_banner("STASIS — ENEMIES SLOWED")
	else:
		_set_banner("STASIS RECHARGING")

func _on_golem_event(_g: Golem, kind: String) -> void:
	if kind == "blocked":
		_set_banner("GOLEM ARMOR BLOCKED THE HIT (PIERCE OR RAM)")
	elif kind == "counter":
		_set_banner("GOLEM TOOK PIERCING DAMAGE")

func _on_warden_event(_w: Warden, kind: String) -> void:
	var now := float(Time.get_ticks_msec())
	if _warden_event_t + 900.0 > now:
		return
	_warden_event_t = now
	match kind:
		"armor":
			_set_banner("WARDEN ARMOR — reduced damage (turret pierce / ram / wall deflect)")
		"counter":
			_set_banner("COUNTER! armor bypassed")
		"charge":
			_set_banner("WARDEN CHARGING — put a wall in its lane!")
		"deflect":
			_set_banner("DEFLECTED — WARDEN STUNNED (-40 hp)")

func _open_research() -> void:
	if research_open or not flow.running:
		return
	if director.state != WaveDirector.State.PREP:
		_set_banner("RESEARCH BETWEEN WAVES ONLY (PREP PHASE)")
		return
	research_open = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_pause_gate.disabled = true
	research_screen.show_screen()

func _research_closed() -> void:
	research_open = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_pause_gate.disabled = false

# ------------------------------------------------------------- HUD -----------

func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0:
			hud.set_banner("")
	_hud_t -= delta
	if _hud_t <= 0.0:
		_hud_t = 0.15
		_refresh_hud()

func _refresh_hud() -> void:
	if hud == null:
		return
	hud.set_scrap(cargo, BuildService.COSTS["wall"], BuildService.COSTS["turret"], nuke_charge)
	var state := "PREP"
	var info := "%ds (N early start)" % int(ceilf(director.prep_left))
	if director.state == WaveDirector.State.ASSAULT:
		state = "ASSAULT"
		info = "ENEMIES: %d" % director.alive
	elif director.state == WaveDirector.State.WIN:
		state = "WIN"
		info = ""
	if not flow.running:
		state = "ENDED"
		info = flow.last_result
	hud.set_wave(state, director.wave, WaveDirector.WAVE_SIZES.size(), info)
	hud.set_rover(rig.hp, rig.max_hp, "MECH" if rig.mech_mode else "ROVER")
	hud.set_crystal(arena.crystal.integrity, arena.crystal.max_integrity)
	if build.active:
		hud.set_hint("1 WALL  2 TURRET  LMB PLACE  X/Esc CANCEL  E HARVEST/REPAIR")
	else:
		hud.set_hint("WASD drive · mouse aim · LMB fire · E harvest/repair · N early start · Esc pause")

func _set_banner(text: String) -> void:
	_banner = text
	_banner_t = 3.0
	hud.set_banner(_banner)

# ------------------------------------------------------------- overlays ------

func _build_pause_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.text = "CHRONOLITH"
	title.add_theme_font_size_override("font_size", 34)
	var sub := Label.new()
	sub.text = "PAUSED — Esc / Start to resume"
	sub.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	box.add_child(sub)
	panel.add_child(box)
	center.add_child(panel)
	dim.add_child(center)
	_overlay.add_child(dim)
	_overlay.visible = false
	add_child(_overlay)
	var gate := PauseGate.new()
	gate.name = "PauseGate"
	gate.rig_ref = rig
	_pause_gate = gate
	add_child(gate)

func _build_end_overlay() -> void:
	_end_overlay = CanvasLayer.new()
	_end_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_end_overlay.layer = 10
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_label = Label.new()
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.add_theme_font_size_override("font_size", 30)
	_end_label.text = ""
	center.add_child(_end_label)
	dim.add_child(center)
	_end_overlay.add_child(dim)
	_end_overlay.visible = false
	add_child(_end_overlay)
	var gate := RestartGate.new()
	gate.restart = _restart_attempt
	_end_overlay.add_child(gate)

func _restart_attempt() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

class PauseGate:
	extends Node
	var rig_ref: Node
	var disabled := false
	func _unhandled_input(event: InputEvent) -> void:
		if disabled or not get_tree().paused or not is_instance_valid(rig_ref):
			return
		if event.is_action_pressed("pause_toggle") or \
			(event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START and event.pressed):
			rig_ref._toggle_pause()

class RestartGate:
	extends Node
	var restart: Callable
	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("restart_attempt") or \
			(event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START and event.pressed):
			restart.call()
