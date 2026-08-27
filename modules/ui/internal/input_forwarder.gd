extends Node
## INTERNAL (ui) — polls raw input each physics tick and emits input_* events.
## PAUSABLE: goes silent while the tree is paused (memory dialogs, pause).

var phase_id: int = Contracts.Phase.HUB
var current_selection := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Bus.phase_changed.connect(func(p: Dictionary) -> void:
		phase_id = int(p.get("phase_id", phase_id)))
	Bus.build_selected.connect(func(p: Dictionary) -> void:
		current_selection = str(p.get("building_id", "")))

func _physics_process(_delta: float) -> void:
	if phase_id != Contracts.Phase.CALM and phase_id != Contracts.Phase.ASSAULT:
		return
	var v := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up"))
	Bus.input_move.emit({"vec": {"x": v.x, "y": v.y}})
	Bus.input_fire.emit({"pressed": Input.is_action_pressed("fire")})
	Bus.input_interact.emit({"pressed": Input.is_action_pressed("interact")})
	if Input.is_action_just_pressed("rewind"):
		Bus.player_activated_rewind.emit({})
	if Input.is_action_just_pressed("upgrade_rover"):
		Bus.player_requested_upgrade.emit({})
	if Input.is_action_just_pressed("skip_calm"):
		Bus.player_skip_calm.emit({})
	if current_selection != "" and Input.is_action_just_pressed("fire"):
		Bus.build_place_clicked.emit({})
	for i in 4:
		if Input.is_action_just_pressed("build_%d" % (i + 1)):
			var ids := ["wall", "turret", "solar", "scanner"]
			var new_sel: String = ids[i] if current_selection != ids[i] else ""
			Bus.build_selected.emit({"building_id": new_sel})
			if new_sel != "":
				Bus.toast.emit({"text": "Placing: %s — click a valid site" % ids[i], "color": "#9adfff", "life": 2.0})
	if Input.is_action_just_pressed("cancel_build") and current_selection != "":
		Bus.build_selected.emit({"building_id": ""})
