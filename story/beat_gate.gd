class_name BeatGate
extends Node
## M7 story-beat input gate. Runs at PROCESS_MODE_ALWAYS so a beat can pause
## the whole tree and still be closed by any key or gamepad button.

signal closed

var open := false

func _unhandled_input(event: InputEvent) -> void:
	if not open:
		return
	var pressed := false
	if event is InputEventKey and event.pressed:
		pressed = true
	elif event is InputEventJoypadButton and event.pressed:
		pressed = true
	if pressed:
		get_viewport().set_input_as_handled()
		skip()

func skip() -> void:
	if not open:
		return
	open = false
	closed.emit()
