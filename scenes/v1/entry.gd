extends Node3D
## M1 composition root: arena + combat + player rig + pause overlay.
## Pause = tree pause + distinct input context: while paused only the pause
## gate (PROCESS_MODE_ALWAYS) reads input; the rig reads none.

var rig: PlayerRig
var combat: Combat
var _overlay: CanvasLayer

func _ready() -> void:
	var arena_res: PackedScene = ResourceLoader.load("res://scenes/v1/arena.tscn")
	add_child(arena_res.instantiate())
	combat = Combat.new()
	combat.name = "Combat"
	add_child(combat)
	var rig_res: PackedScene = ResourceLoader.load("res://player/player_rig.tscn")
	rig = rig_res.instantiate() as PlayerRig
	rig.name = "PlayerRig"
	add_child(rig)
	rig.fired.connect(_on_fired)
	_build_pause_overlay()
	print("M1_ENTRY_READY")

func _on_fired(from: Vector3, to: Vector3) -> void:
	combat.fire(from, to, [rig.rover_rid()])

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
	add_child(gate)
	rig.pause_toggled.connect(_on_pause_toggled)

func _on_pause_toggled(paused: bool) -> void:
	_overlay.visible = paused

class PauseGate:
	extends Node
	var rig_ref: Node
	func _unhandled_input(event: InputEvent) -> void:
		if not get_tree().paused or not is_instance_valid(rig_ref):
			return
		if event.is_action_pressed("pause_toggle") or \
			(event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START and event.pressed):
			rig_ref._toggle_pause()
