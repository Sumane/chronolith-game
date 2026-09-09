class_name InputSetup
extends RefCounted
## Runtime InputMap registration (keeps project.godot free of serialized events).

const ACTIONS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"fire": [KEY_SPACE],
	"interact": [KEY_E],
	"rewind": [KEY_R],
	"upgrade_rover": [KEY_U],
	"skip_calm": [KEY_N],
	"toggle_help": [KEY_H],
	"pause_toggle": [KEY_ESCAPE],
	"build_1": [KEY_1],
	"build_2": [KEY_2],
	"build_3": [KEY_3],
	"build_4": [KEY_4],
	"cancel_build": [KEY_X],
}

const MOUSE_BINDINGS := {
	"fire": MOUSE_BUTTON_LEFT,
	"cancel_build": MOUSE_BUTTON_RIGHT,
}

# M6e: default gamepad bindings (Xbox layout). Right-stick camera aim and
# stick movement stay keyboard/mouse for now (M8 polish).
const GAMEPAD_BINDINGS := {
	"fire": [JOY_BUTTON_A],
	"interact": [JOY_BUTTON_B],
	"build_1": [JOY_BUTTON_X],
	"build_2": [JOY_BUTTON_Y],
	"cancel_build": [JOY_BUTTON_RIGHT_STICK],
	"pause_toggle": [JOY_BUTTON_START],
	"rewind": [JOY_BUTTON_BACK],
	"move_up": [JOY_BUTTON_DPAD_UP],
	"move_down": [JOY_BUTTON_DPAD_DOWN],
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
}

static var _done := false

static func setup() -> void:
	if _done:
		return
	_done = true
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action: String in MOUSE_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BINDINGS[action]
		InputMap.action_add_event(action, mb)
	for action: String in GAMEPAD_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for btn: int in GAMEPAD_BINDINGS[action]:
			var je := InputEventJoypadButton.new()
			je.button_index = btn
			InputMap.action_add_event(action, je)
