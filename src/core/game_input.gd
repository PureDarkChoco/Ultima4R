class_name GameInput
extends Object

## Shared keyboard + gamepad helpers.
## Actions live in project.godot; this also hardens built-in ui_* so focus navigation
## works with D-pad / left stick even if engine defaults differ.

const STICK_DEADZONE := 0.5


static func ensure_input_map() -> void:
	_ensure_move_actions()
	_ensure_confirm_cancel()
	_ensure_ui_nav()


static func is_cancel(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_B
	return false


static func is_select(event: InputEvent) -> bool:
	## South-face (A) / Enter — not Space (Space often cancels Dir? or Passes).
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_A
	if event is InputEventKey:
		var k := event as InputEventKey
		var code := k.keycode
		var phys := k.physical_keycode
		return (
			code == KEY_ENTER or phys == KEY_ENTER
			or code == KEY_KP_ENTER or phys == KEY_KP_ENTER
		)
	return false


static func dir_from_event(event: InputEvent) -> Vector2i:
	## Single-step dir from a pressed key / d-pad / stick threshold.
	if not event.is_pressed() or event.is_echo():
		return Vector2i.ZERO
	if (
		event.is_action_pressed("move_left")
		or event.is_action_pressed("ui_left")
	):
		return Vector2i(-1, 0)
	if (
		event.is_action_pressed("move_right")
		or event.is_action_pressed("ui_right")
	):
		return Vector2i(1, 0)
	if (
		event.is_action_pressed("move_up")
		or event.is_action_pressed("ui_up")
	):
		return Vector2i(0, -1)
	if (
		event.is_action_pressed("move_down")
		or event.is_action_pressed("ui_down")
	):
		return Vector2i(0, 1)
	if event is InputEventKey:
		var k := event as InputEventKey
		var code := k.keycode
		var phys := k.physical_keycode
		if code == KEY_LEFT or phys == KEY_LEFT:
			return Vector2i(-1, 0)
		if code == KEY_RIGHT or phys == KEY_RIGHT:
			return Vector2i(1, 0)
		if code == KEY_UP or phys == KEY_UP:
			return Vector2i(0, -1)
		if code == KEY_DOWN or phys == KEY_DOWN:
			return Vector2i(0, 1)
	return Vector2i.ZERO


static func read_move_dir() -> Vector2i:
	## Held direction for world/menu poll (keys, D-pad, left stick).
	if Input.is_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_LEFT):
		return Vector2i(-1, 0)
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_RIGHT):
		return Vector2i(1, 0)
	if Input.is_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_UP):
		return Vector2i(0, -1)
	if Input.is_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_DOWN):
		return Vector2i(0, 1)
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("ui_left"):
		return Vector2i(-1, 0)
	if Input.is_action_pressed("move_right") or Input.is_action_pressed("ui_right"):
		return Vector2i(1, 0)
	if Input.is_action_pressed("move_up") or Input.is_action_pressed("ui_up"):
		return Vector2i(0, -1)
	if Input.is_action_pressed("move_down") or Input.is_action_pressed("ui_down"):
		return Vector2i(0, 1)
	return Vector2i.ZERO


static func read_select_step() -> int:
	## -1 up, +1 down, 0 none.
	if Input.is_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_UP):
		return -1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_DOWN):
		return 1
	if Input.is_action_pressed("move_up") or Input.is_action_pressed("ui_up"):
		return -1
	if Input.is_action_pressed("move_down") or Input.is_action_pressed("ui_down"):
		return 1
	return 0


static func _ensure_move_actions() -> void:
	_ensure_action(
		"move_up",
		[
			_key(KEY_UP),
			_joy_button(JOY_BUTTON_DPAD_UP),
			_joy_axis(JOY_AXIS_LEFT_Y, -1.0),
		]
	)
	_ensure_action(
		"move_down",
		[
			_key(KEY_DOWN),
			_joy_button(JOY_BUTTON_DPAD_DOWN),
			_joy_axis(JOY_AXIS_LEFT_Y, 1.0),
		]
	)
	_ensure_action(
		"move_left",
		[
			_key(KEY_LEFT),
			_joy_button(JOY_BUTTON_DPAD_LEFT),
			_joy_axis(JOY_AXIS_LEFT_X, -1.0),
		]
	)
	_ensure_action(
		"move_right",
		[
			_key(KEY_RIGHT),
			_joy_button(JOY_BUTTON_DPAD_RIGHT),
			_joy_axis(JOY_AXIS_LEFT_X, 1.0),
		]
	)


static func _ensure_confirm_cancel() -> void:
	_ensure_action(
		"confirm",
		[
			_key(KEY_ENTER),
			_key(KEY_SPACE),
			_joy_button(JOY_BUTTON_A),
		]
	)
	_ensure_action(
		"cancel",
		[
			_key(KEY_ESCAPE),
			_joy_button(JOY_BUTTON_B),
		]
	)


static func _ensure_ui_nav() -> void:
	## Godot GUI focus / Button activation.
	_ensure_action(
		"ui_up",
		[
			_key(KEY_UP),
			_joy_button(JOY_BUTTON_DPAD_UP),
			_joy_axis(JOY_AXIS_LEFT_Y, -1.0),
		]
	)
	_ensure_action(
		"ui_down",
		[
			_key(KEY_DOWN),
			_joy_button(JOY_BUTTON_DPAD_DOWN),
			_joy_axis(JOY_AXIS_LEFT_Y, 1.0),
		]
	)
	_ensure_action(
		"ui_left",
		[
			_key(KEY_LEFT),
			_joy_button(JOY_BUTTON_DPAD_LEFT),
			_joy_axis(JOY_AXIS_LEFT_X, -1.0),
		]
	)
	_ensure_action(
		"ui_right",
		[
			_key(KEY_RIGHT),
			_joy_button(JOY_BUTTON_DPAD_RIGHT),
			_joy_axis(JOY_AXIS_LEFT_X, 1.0),
		]
	)
	_ensure_action(
		"ui_accept",
		[
			_key(KEY_ENTER),
			_key(KEY_KP_ENTER),
			_key(KEY_SPACE),
			_joy_button(JOY_BUTTON_A),
		]
	)
	_ensure_action(
		"ui_cancel",
		[
			_key(KEY_ESCAPE),
			_joy_button(JOY_BUTTON_B),
		]
	)


static func _ensure_action(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, STICK_DEADZONE)
	else:
		InputMap.action_set_deadzone(action, STICK_DEADZONE)
	for candidate in events:
		if candidate == null:
			continue
		if not _action_has_similar(action, candidate as InputEvent):
			InputMap.action_add_event(action, candidate)


static func _action_has_similar(action: String, event: InputEvent) -> bool:
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and event is InputEventKey:
			var a := existing as InputEventKey
			var b := event as InputEventKey
			var a_code := a.physical_keycode if a.physical_keycode != KEY_NONE else a.keycode
			var b_code := b.physical_keycode if b.physical_keycode != KEY_NONE else b.keycode
			if a_code == b_code and a_code != KEY_NONE:
				return true
		elif existing is InputEventJoypadButton and event is InputEventJoypadButton:
			if (existing as InputEventJoypadButton).button_index == (event as InputEventJoypadButton).button_index:
				return true
		elif existing is InputEventJoypadMotion and event is InputEventJoypadMotion:
			var am := existing as InputEventJoypadMotion
			var bm := event as InputEventJoypadMotion
			if am.axis == bm.axis and signf(am.axis_value) == signf(bm.axis_value):
				return true
	return false


static func _key(phys: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = phys
	return e


static func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e


static func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e
