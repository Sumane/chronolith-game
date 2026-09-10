extends Node3D
## M2 composition root: arena + combat + rig + waves + build + flow + HUD.
## Wallet (scrap cargo) lives here for M2; a proper Economy owner comes later.

const START_CARGO := 6

# M7 story beats — short, skippable, paused. The GDD fixes the outcome:
# one ending, no victory reset, temporal builds keep their abilities.
const STORY_OPENING := "VAEL — LAST ARCHIVIST
 Crash site. The shard bridges into the machine: a NASA rover, cold and waiting.
 Under the base, the Chronolith holds Sorrak the Undying — and his descendants have found us.
 Vael: 'Right. A scholar in a rover, fighting a war of ghosts. I can work with that.'
 Every defeat resets the world. The knowledge stays."
const STORY_WARDEN := "The first Warden falls.
 Vael: 'It charges like the old fortifications. Piercing rounds ignore that armor —
 or put a wall in its lane and let it break itself.'"
const STORY_GOLEM := "The Golem breaks on the piercing round.
 Vael: 'Armor like a tomb door. The Archivist records. The Archivist adjusts.'"
const STORY_MECH := "The chassis reshapes around the shard.
 Vael: 'There you are. I had forgotten what the rest of me felt like.'
 The warrior mech is online."
const STORY_TAUNT := "High above the dust, the command ship rises.
 Vrax: 'Every attempt, Archivist. I have watched you rebuild the same mistakes.
 The seal was always a formality.'"
const STORY_FINALE := "The last wave gathers around the crystal.
 Vael: 'Sorrak stirs beneath it. Finish this. End the loop.'"
const STORY_ENDING := "The mech stands over Vrax's broken command ship. The seal-key turns —
 the Chronolith re-seals, and the loop ends.
 The Corsairs withdraw into the dust. Sorrak stays where he has always been.
 Far away, a NASA probe finally gets an answer:
 'This is CHRONOLITH-1. I'm home. — V.'

 COMPLETION RECORDED — the victory may continue beyond wave 20."

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
# M16: a nuke bypasses the wave instead of clearing it — no engram for it
var _nuked_this_wave := false
var _sealed_wave := 0
var _sealed_need := 0
var _last_win_was_full := false
var _warden_event_t := 0.0
var profile_recovered := false
var _saved_attempt_id := ""
var _saved_wave := 0
var _saved_cargo := 0
# M15: the full attempt state (buildings, deposits, mech, nukes, endless...)
var _saved_attempt := {}
var hud: HudLayer
var _overlay: CanvasLayer
var _end_overlay: CanvasLayer
var _end_label: Label
var _pause_gate: PauseGate
var _research_gate: ResearchGate = null
var _restart_gate: RestartGate = null
var _root_gates: Array = []
var _banner_t := 0.0
var _banner := ""
var _hud_t := 0.0

# M7 story state (persisted in the profile under story_flags)
var story_enabled := true
var _story := {}
var beat_gate: BeatGate
var _beat_ui: CanvasLayer = null
var _beat_open := false
var _beat_paused_before := false

func _ready() -> void:
	# explicit pause semantics: this subtree must honor tree.paused even when
	# embedded under an ALWAYS parent (headless probes)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# v1 actions first: InputSetup.setup() creates the gamepad-bound actions
	# (sell_build, build_1, ...) and would make _add_key's has_action guard
	# skip the keyboard keys for them
	_register_actions()
	InputSetup.setup()
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
	director.golem_event.connect(_on_golem_event)
	director.warden_died.connect(_on_warden_died)
	director.golem_died.connect(_on_golem_died)
	beat_gate = BeatGate.new()
	beat_gate.name = "BeatGate"
	beat_gate.process_mode = Node.PROCESS_MODE_ALWAYS
	beat_gate.closed.connect(_close_beat)
	# Gates live under the root: while the tree is paused, this entry's
	# PAUSABLE subtree is input-dead, so any gate inside it could never close
	# what it guards. The root always processes input.
	_add_root_gate(beat_gate)
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
	director.knowledge = knowledge  # M16: barrier schedule is enforced live
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
	call_deferred("_maybe_opening")

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
	director.sealed.connect(_on_sealed)
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
	if event.is_action_pressed("build_wall") or event.is_action_pressed("build_1"):
		_start_build("wall")
	elif event.is_action_pressed("build_turret") or event.is_action_pressed("build_2"):
		_start_build("turret")
	elif event.is_action_pressed("cancel_build"):
		build.cancel()
		rig.build_locked = false
	elif event.is_action_pressed("early_start"):
		director.early_start()
	# research_toggle is owned by the root-level ResearchGate (it must stay
	# live while the tree is paused)
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
		if not flow.running and _last_win_was_full:
			_start_endless()
		else:
			_try_time_burst()
	elif event.is_action_pressed("restart_attempt"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("sell_build") or \
			(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and not build.active):
		_try_sell()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and build.active:
		var res: Dictionary = build.commit()
		if not res.get("ok", false):
			_set_banner("CANNOT PLACE: " + str(res.get("reason", "")))
	elif event.is_action_pressed("pause_toggle") and build.active:
		build.cancel()
		rig.build_locked = false

## M11: sell the building under the crosshair. RMB routes here only when no
## build is active (RMB while placing cancels the placement above).
func _try_sell() -> void:
	if build.active:
		return
	var r: Dictionary = rig.aim_ray()
	if r.is_empty():
		return
	var rover: CharacterBody3D = rig.get_node("Rover")
	var q := PhysicsRayQueryParameters3D.create(
		r["orig"], r["orig"] + r["dir"] * 200.0, -1, [rover.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var col: Node = hit.get("collider")
	if col is BuildingBase and (col as BuildingBase).hp > 0:
		var res: Dictionary = build.sell(col)
		if res.get("ok", false):
			_set_banner("SOLD " + str(res["type"]).to_upper() + " (+" + str(res["refund"]) + " scrap)")
		else:
			_set_banner("CANNOT SELL: " + str(res.get("reason", "")))

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
	_add_key("sell_build", KEY_Z)

# keycodes already added per action (InputMap has no event enumeration API;
# survives scene reloads within one process)
static var _key_actions: Dictionary = {}

func _add_key(action: String, keycode: Key) -> void:
	# the action may pre-exist (gamepad bindings); make sure this key is in
	# it, without duplicating on scene reloads
	var added: Array = _key_actions.get(action, [])
	if added.has(keycode):
		return
	added.append(keycode)
	_key_actions[action] = added
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var k := InputEventKey.new()
	k.keycode = keycode
	InputMap.action_add_event(action, k)

# ------------------------------------------------------------- callbacks -----

func _on_fired(from: Vector3, to: Vector3) -> void:
	if rig.mech_mode:
		combat.fire(from, to, [rig.rover_rid()], MechData.GUN_DMG, true, true)
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

func _on_sealed(wave: int, need: int) -> void:
	_sealed_wave = wave
	_sealed_need = need
	flow.on_sealed()

func _on_wave_started(wave: int, direction: String) -> void:
	_nuked_this_wave = false
	if int(director.wave_plan.size()) == 20:
		if wave == 15:
			_memory("vrax_taunt", STORY_TAUNT)
		elif wave == 20:
			_memory("finale", STORY_FINALE)
	# M6e: counter warning — say what is coming and what beats it
	var warn := ""
	if WaveDirector.WARDEN_WAVES.has(wave):
		warn = " — WARDEN: PIERCE OR RAM"
	if WaveDirector.GOLEM_WAVES.has(wave):
		warn += " — GOLEM: FLAT SHOTS BLOCKED (PIERCE OR RAM)"
	_set_banner("WAVE %d INBOUND FROM THE %s — HOLD THE CRYSTAL%s" % [wave, direction, warn])

func _on_wave_cleared(wave: int) -> void:
	if _nuked_this_wave:
		# GDD nuke rule (now live, M16): a nuked wave is bypassed, not
		# cleared — no engram, no receipt.
		_nuked_this_wave = false
		_set_banner("WAVE %d BYPASSED BY NUKE — NO ENGRAM" % wave)
		return
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
		knowledge.grant_wave(attempt_id, int(director.wave_plan.size()))
		var n := int(director.wave_plan.size())
		var full: bool = n == 20
		_last_win_was_full = full
		# M7: campaign completion is recorded BEFORE the ending plays, and
		# never erased by a later endless defeat (M8 continues from here).
		if full and not _story.get("completion", false):
			_story["completion"] = true
		if full:
			_save_profile()
		if full and not _story.get("ending_seen", false):
			_story["ending_seen"] = true
			_save_profile()
			_end_label.text = "CAMPAIGN CLEAR: %d WAVES" % n
			_end_overlay.visible = true
			_show_beat(STORY_ENDING)
			return
		if full:
			_end_label.text = "CAMPAIGN CLEAR: %d WAVES\n(completion already recorded — ending skipped)\n(R — new attempt)" % n
		else:
			_end_label.text = "CAMPAIGN CLEAR: %d WAVES\n(R — new attempt)" % n
	elif result == "sealed":
		# M16: the GDD barrier schedule — a knowledge gap, not a death
		_end_label.text = "WAVE %d SEALED — THE CRYSTAL HOLDS AT %d LIFETIME ENGRAM\n(you carry %d — R — NEW ATTEMPT)" % [_sealed_wave, _sealed_need, knowledge.earned_total]
	else:
		var reason := "the crystal was destroyed" if result == "lost_crystal" else "the rover was destroyed"
		if director.endless:
			# M8: endless failure is separated from the campaign — completion
			# and knowledge stay recorded, the finale never replays. C does not
			# restart endless from a loss screen; R starts a fresh attempt.
			_last_win_was_full = false
			_end_label.text = "ENDLESS RUN ENDED AT WAVE %d — THE CAMPAIGN REMAINS COMPLETE\n(R — new attempt)" % director.wave
		else:
			_end_label.text = "ATTEMPT LOST — " + reason + "\n(R — new attempt)"
	_save_profile()
	_end_overlay.visible = true

## M8: continue the victorious physical state into wave 21+ (non-canonical).
## C on the win screen; the time-burst key is free while the flow is over.
func _start_endless() -> void:
	if flow.running or not _last_win_was_full:
		return
	director.begin_endless()
	flow.running = true
	flow.last_result = ""
	_end_overlay.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_set_banner("ENDLESS DEFENCE — WAVE %d (non-canonical: the campaign is complete)" % director.wave)
	_refresh_hud()

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
	var sf: Dictionary = data.get("story_flags", {})
	_story = sf if sf is Dictionary else {}
	var att: Dictionary = data.get("attempt", {})
	if att.size() > 0:
		_saved_attempt = att
		_saved_attempt_id = str(att.get("id", ""))
		_saved_wave = int(att.get("wave", 0))
		_saved_cargo = int(att.get("cargo", 0))

func _resume_checkpoint() -> void:
	if _saved_attempt_id != "" and _saved_wave > 0:
		attempt_id = _saved_attempt_id
		cargo = _saved_cargo
		director.wave = _saved_wave
		director.endless = bool(_saved_attempt.get("endless", false))
		director.state = WaveDirector.State.PREP
		director.prep_left = WaveDirector.PREP_TIME
		nuke_charge = int(_saved_attempt.get("nuke", nuke_charge))
		# M15: restore the physical state of the run. The mech is restored
		# first (transform_to_mech sets max_hp and a full hp); the saved rover
		# hp is applied on top of that. A run that ended by death (hp or
		# crystal integrity <= 0) respawns whole so the checkpoint is playable.
		if bool(_saved_attempt.get("mech", false)):
			rig.transform_to_mech()
		var rhp := int(_saved_attempt.get("rover_hp", 0))
		if rhp <= 0:
			rhp = rig.max_hp
		rig.hp = clampi(rhp, 1, rig.max_hp)
		var cinteg := int(_saved_attempt.get("crystal", arena.crystal.integrity))
		if cinteg <= 0:
			arena.crystal.integrity = arena.crystal.max_integrity
			arena.crystal.destroyed = false
		else:
			arena.crystal.integrity = cinteg
		var flags: Array = _saved_attempt.get("deposits", [])
		var kids: Array = arena.dep_group.get_children()
		for i in int(flags.size()):
			if i < kids.size() and bool(flags[i]):
				(kids[i] as Deposit).depleted = true
				kids[i]._refresh()
		build.restore(_saved_attempt.get("buildings", []))
		_set_banner("CHECKPOINT RESTORED: WAVE %d OF %d" % [_saved_wave, int(director.wave_plan.size())])
	else:
		attempt_id = _new_attempt_id()

func _new_attempt_id() -> String:
	return str(Time.get_ticks_msec()) + "-" + str(randi() % 100000)

func _profile_data() -> Dictionary:
	var d := {
		"schema_version": ProfileStore.SCHEMA_VERSION,
		"knowledge": knowledge.snapshot(),
		"story_flags": _story,
	}
	if flow.running:
		# M15: the whole physical state of the run — not just id/wave/scrap.
		d["attempt"] = {
			"id": attempt_id,
			"wave": director.wave,
			"cargo": cargo,
			"crystal": int(arena.crystal.integrity),
			"rover_hp": int(rig.hp),
			"mech": bool(rig.mech_mode),
			"nuke": int(nuke_charge),
			"endless": bool(director.endless),
			"deposits": _deposit_flags(),
			"buildings": build.snapshot(),
		}
	else:
		d["attempt"] = {}
	return d

func _deposit_flags() -> Array:
	var out: Array = []
	for k in arena.dep_group.get_children():
		out.append(bool((k as Deposit).depleted))
	return out

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
	_nuked_this_wave = true
	for en in get_tree().get_nodes_in_group("enemy"):
		# M8: the boss is out of scope — the mech is required to defeat Vrax
		if en is Vrax:
			continue
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
	_memory("mech", STORY_MECH)
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
	var total: int = -1 if director.endless else int(director.wave_plan.size())
	hud.set_wave(state, director.wave, total, info)
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

# ------------------------------------------------------------- M7 story -----

func _maybe_opening() -> void:
	if _story.get("seen_opening", false):
		return
	_story["seen_opening"] = true
	_save_profile()
	_show_beat(STORY_OPENING)

## One-shot memory beat; the flag persists in the profile.
func _memory(key: String, text: String) -> void:
	var mem: Dictionary = _story.get("memories", {})
	if mem.has(key):
		return
	mem[key] = true
	_story["memories"] = mem
	_save_profile()
	_show_beat(text)

func _on_warden_died(_w: Warden) -> void:
	_memory("warden_first", STORY_WARDEN)

func _on_golem_died(_g: Golem) -> void:
	_memory("golem_first", STORY_GOLEM)

## Pausable, skippable story overlay. A beat may open while the tree is
## already paused (the ending) — it restores whatever pause state preceded it.
func _show_beat(text: String) -> void:
	if not story_enabled or _beat_open:
		return
	_beat_open = true
	_beat_paused_before = get_tree().paused
	beat_gate.open = true
	_beat_ui = CanvasLayer.new()
	_beat_ui.name = "BeatUI"
	_beat_ui.layer = 20
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.04, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_beat_ui.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 300)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	box.add_child(label)
	var hint := Label.new()
	hint.text = "— press any key —"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	box.add_child(hint)
	panel.add_child(box)
	center.add_child(panel)
	_beat_ui.add_child(center)
	add_child(_beat_ui)
	if not get_tree().paused:
		get_tree().paused = true

func _close_beat() -> void:
	if not _beat_open:
		return
	_beat_open = false
	if _beat_ui != null:
		_beat_ui.queue_free()
		_beat_ui = null
	if not _beat_paused_before:
		get_tree().paused = false

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
	gate.beat_ref = beat_gate
	gate.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_gate = gate
	_add_root_gate(gate)
	var rgate := ResearchGate.new()
	rgate.name = "ResearchGate"
	rgate.entry_ref = self
	rgate.process_mode = Node.PROCESS_MODE_ALWAYS
	_research_gate = rgate
	_add_root_gate(rgate)

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
	gate.process_mode = Node.PROCESS_MODE_ALWAYS
	_restart_gate = gate
	_add_root_gate(gate)

func _restart_attempt() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

## Root-level gates must be attached deferred: during scene setup the root is
## busy adding its own children, so an immediate add_child is refused. The
## lambda re-checks validity in case this entry is freed first.
func _add_root_gate(g: Node) -> void:
	_root_gates.append(g)
	var root := get_tree().root
	var attach := func() -> void:
		if is_instance_valid(g) and is_instance_valid(root) and g.get_parent() == null:
			root.add_child(g)
	attach.call_deferred()

func _exit_tree() -> void:
	for g in _root_gates:
		if is_instance_valid(g):
			g.queue_free()
	_root_gates.clear()

class PauseGate:
	extends Node
	var rig_ref: Node
	var beat_ref: Node = null
	var disabled := false
	func _unhandled_input(event: InputEvent) -> void:
		# A story beat also pauses the tree; its gate owns the close key.
		# While research is open (disabled), ResearchGate owns ESC too.
		if is_instance_valid(beat_ref) and beat_ref.open:
			return
		if disabled or not is_instance_valid(rig_ref):
			return
		if event.is_action_pressed("pause_toggle") or \
			(event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START and event.pressed):
			get_viewport().set_input_as_handled()
			rig_ref._toggle_pause()

class ResearchGate:
	extends Node
	## Owns the research screen's open/close keys. Lives under the root so it
	## stays live while the tree is paused, and consumes the event so the
	## (mid-event) unpausing cannot make the entry's subtree re-process it.
	var entry_ref: Node
	func _unhandled_input(event: InputEvent) -> void:
		if not is_instance_valid(entry_ref):
			return
		var sc: Node = entry_ref.research_screen
		if not is_instance_valid(sc):
			return
		if sc.visible_now:
			if event.is_action_pressed("research_toggle") or event.is_action_pressed("pause_toggle"):
				get_viewport().set_input_as_handled()
				sc._close()
		elif event.is_action_pressed("research_toggle"):
			get_viewport().set_input_as_handled()
			entry_ref._open_research()

class RestartGate:
	extends Node
	var restart: Callable
	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("restart_attempt") or \
			(event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START and event.pressed):
			restart.call()
