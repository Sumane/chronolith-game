extends CanvasLayer
## M7 UI/HUD — stateless display + input capture → input_* events.
## Holds zero game state: everything rendered is the latest event payload.
## If this module dies, the game keeps running headless (architecture §4).

const Hud := preload("res://modules/ui/internal/hud.gd")
const BuildMenu := preload("res://modules/ui/internal/build_menu.gd")
const InputForwarder := preload("res://modules/ui/internal/input_forwarder.gd")

var hud: Control
var build_menu: Control
var forwarder: Node

func _ready() -> void:
	if Contracts.CONTRACT_VERSION != 1:
		push_warning("[UI] contract version mismatch")
	process_mode = Node.PROCESS_MODE_ALWAYS # pause menu must work while paused
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	build_menu = BuildMenu.new()
	build_menu.name = "BuildMenu"
	add_child(build_menu)
	forwarder = InputForwarder.new()
	forwarder.name = "InputForwarder"
	add_child(forwarder)
	# wire display
	Bus.resource_changed.connect(func(p: Dictionary) -> void: hud.update_ledger(p.get("ledger", {})); build_menu.set_affordability(p.get("ledger", {})))
	Bus.chronolith_damaged.connect(func(p: Dictionary) -> void: hud.update_integrity(p))
	Bus.rover_damaged.connect(func(p: Dictionary) -> void: hud.update_rover_hp(p))
	Bus.rewind_state.connect(func(p: Dictionary) -> void: hud.update_rewind(p))
	Bus.power_state_changed.connect(func(p: Dictionary) -> void: hud.update_power(p))
	Bus.phase_changed.connect(_on_phase_changed)
	Bus.sol_changed.connect(func(p: Dictionary) -> void: hud.update_sol(int(p.get("sol", 0))))
	Bus.calm_tick.connect(func(p: Dictionary) -> void: hud.update_calm(p))
	Bus.wave_started.connect(func(p: Dictionary) -> void: hud.update_wave_started(p))
	Bus.wave_progress.connect(func(p: Dictionary) -> void: hud.update_wave_progress(p))
	Bus.wave_cleared.connect(func(p: Dictionary) -> void: hud.update_wave_cleared())
	Bus.environment_state.connect(func(p: Dictionary) -> void: hud.update_environment(p))
	Bus.run_ended.connect(func(p: Dictionary) -> void: hud.flash_run_end(str(p.get("reason", ""))))
	Bus.toast.connect(func(p: Dictionary) -> void: hud.add_toast(str(p.get("text", "")), str(p.get("color", "#ffffff"))))
	Bus.build_selected.connect(func(p: Dictionary) -> void: build_menu.set_selected(str(p.get("building_id", ""))))
	Bus.rover_upgraded_ack.connect(func(_p: Dictionary) -> void:
		hud.add_toast("Rover stage upgraded — HYBRID chassis online", "#59e6ff"))
	# build menu defs (read-only render of data files)
	var defs: Variant = Contracts.load_json("res://modules/build/data/buildings.json")
	if typeof(defs) == TYPE_DICTIONARY:
		build_menu.build_cards(defs)
	# first-run guidance toasts
	_intro_toasts()

func _intro_toasts() -> void:
	await get_tree().create_timer(1.2).timeout
	hud.add_toast("WASD drive · MOUSE aim · LMB fire · hold E near nodes to harvest", "#9adfff", 6.0)
	await get_tree().create_timer(2.2).timeout
	hud.add_toast("Keys 1-4 select structures · click to place · RMB/X cancel", "#9adfff", 6.0)

func _on_phase_changed(payload: Dictionary) -> void:
	hud.update_phase(payload)
	match int(payload.get("phase_id", -1)):
		Contracts.Phase.CALM:
			hud.add_toast("CALM PHASE — scavenge, build, repair. Night is coming.", "#ffd98a")
			_earth_transmission()
		Contracts.Phase.ASSAULT:
			hud.add_toast("ASSAULT — the Reptilian armada has arrived", "#ff8a5a")

var _tx_index := 0
const EARTH_TX := [
	"> JPL uplink: 'Curiosity, confirm sample B7.' …no response recorded.",
	"> JPL uplink: 'Curiosity, you are drifting off route. Repeat, off route.'",
	"> JPL uplink: '…are those… structures we don't have on file?'",
]
func _earth_transmission() -> void:
	hud.add_toast(EARTH_TX[_tx_index % EARTH_TX.size()], "#8fa8b8", 5.0)
	_tx_index += 1

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_toggle"):
		var tree := get_tree()
		tree.paused = not tree.paused
		hud.set_paused(tree.paused)
	elif event.is_action_pressed("toggle_help"):
		hud.toggle_help()
