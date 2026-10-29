extends Node
## Registra as ações de entrada em código (teclado/mouse e gamepad).
## As associações ficam numa tabela de dados, para o remapeamento futuro (Marco 5)
## poder lê-la e sobrescrevê-la sem tocar na lógica de jogo.

const STICK_DEADZONE := 0.2

## ação -> {"keys": [Key], "pad_buttons": [JoyButton], "pad_axes": [[JoyAxis, sinal]]}
const BINDINGS := {
	"move_left": {"keys": [KEY_A, KEY_LEFT], "pad_axes": [[JOY_AXIS_LEFT_X, -1.0]]},
	"move_right": {"keys": [KEY_D, KEY_RIGHT], "pad_axes": [[JOY_AXIS_LEFT_X, 1.0]]},
	"move_up": {"keys": [KEY_W, KEY_UP], "pad_axes": [[JOY_AXIS_LEFT_Y, -1.0]]},
	"move_down": {"keys": [KEY_S, KEY_DOWN], "pad_axes": [[JOY_AXIS_LEFT_Y, 1.0]]},
	"dodge": {"keys": [KEY_SPACE, KEY_SHIFT], "pad_buttons": [JOY_BUTTON_B]},
	"attack": {"keys": [KEY_J], "mouse_buttons": [MOUSE_BUTTON_LEFT], "pad_buttons": [JOY_BUTTON_X]},
	"defend": {"keys": [KEY_K], "pad_buttons": [JOY_BUTTON_LEFT_SHOULDER]},
	"camera_yaw_left": {"keys": [KEY_Q], "pad_axes": [[JOY_AXIS_RIGHT_X, -1.0]]},
	"camera_yaw_right": {"keys": [KEY_E], "pad_axes": [[JOY_AXIS_RIGHT_X, 1.0]]},
	"camera_reset": {"keys": [KEY_R], "pad_buttons": [JOY_BUTTON_RIGHT_STICK]},
	"camera_preset_1": {"keys": [KEY_1]},
	"camera_preset_2": {"keys": [KEY_2]},
	"camera_preset_3": {"keys": [KEY_3]},
	"camera_preset_next": {"keys": [KEY_TAB], "pad_buttons": [JOY_BUTTON_DPAD_RIGHT]},
	"camera_preset_prev": {"pad_buttons": [JOY_BUTTON_DPAD_LEFT]},
	"debug_toggle": {"keys": [KEY_F3], "pad_buttons": [JOY_BUTTON_BACK]},
	"quit_game": {"keys": [KEY_ESCAPE]},
}


func _ready() -> void:
	register_all()


func register_all() -> void:
	for action: String in BINDINGS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, STICK_DEADZONE)
		var binding: Dictionary = BINDINGS[action]
		for key: int in binding.get("keys", []):
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
		for mb: int in binding.get("mouse_buttons", []):
			var mev := InputEventMouseButton.new()
			mev.button_index = mb as MouseButton
			InputMap.action_add_event(action, mev)
		for button: int in binding.get("pad_buttons", []):
			var ev := InputEventJoypadButton.new()
			ev.button_index = button as JoyButton
			InputMap.action_add_event(action, ev)
		for axis_def: Array in binding.get("pad_axes", []):
			var ev := InputEventJoypadMotion.new()
			ev.axis = int(axis_def[0]) as JoyAxis
			ev.axis_value = float(axis_def[1])
			InputMap.action_add_event(action, ev)
