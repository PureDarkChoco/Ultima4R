class_name GameInput
extends Object

## Shared keyboard + gamepad helpers.
## Actions live in project.godot; this also hardens built-in ui_* so focus navigation
## works with D-pad / left stick even if engine defaults differ.

const STICK_DEADZONE := 0.5
## Match move deadzone so a normal tilt counts; release lower to clear the latch.
const STICK_NAV_PRESS := 0.5
const STICK_NAV_RELEASE := 0.30

static var _stick_nav_latches: Dictionary = {}
static var _select_x_latches: Dictionary = {}
static var _select_y_latches: Dictionary = {}
static var _application_focused := true
static var _using_gamepad := false


static func note_input(event: InputEvent) -> void:
	## Last device wins so HUD hints can switch between (Y) and (Spacebar).
	if should_block_event(event):
		return
	if event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			_using_gamepad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= STICK_DEADZONE:
			_using_gamepad = true
	elif event is InputEventKey:
		if (event as InputEventKey).pressed and not event.is_echo():
			_using_gamepad = false
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			_using_gamepad = false


static func using_gamepad() -> bool:
	return _using_gamepad


static func set_application_focused(focused: bool) -> void:
	if _application_focused == focused:
		return
	_application_focused = focused
	reset_stick_navigation()
	if not focused:
		Input.flush_buffered_events()


static func application_focused() -> bool:
	return _application_focused


static func should_block_event(event: InputEvent) -> bool:
	## Background windows must not react to pad motion/buttons still routed here.
	return not _application_focused and (
		event is InputEventJoypadButton or event is InputEventJoypadMotion
	)


static func _poll_allowed() -> bool:
	return _application_focused


static func ensure_input_map() -> void:
	_ensure_move_actions()
	_ensure_confirm_cancel()
	_ensure_ui_nav()


static func confirm_button() -> JoyButton:
	## Xbox A / Nintendo B — the face button that confirms.
	if GamepadSettings != null and GamepadSettings.is_nintendo():
		return JOY_BUTTON_B
	return JOY_BUTTON_A


static func cancel_button() -> JoyButton:
	## Xbox B / Nintendo A — the face button that cancels.
	if GamepadSettings != null and GamepadSettings.is_nintendo():
		return JOY_BUTTON_A
	return JOY_BUTTON_B


static func rebind_confirm_cancel() -> void:
	## Swap A/B on confirm/cancel after the Options layout changes.
	_bind_face_action("confirm", confirm_button())
	_bind_face_action("cancel", cancel_button())
	_bind_face_action("ui_accept", confirm_button())
	_bind_face_action("ui_cancel", cancel_button())


static func is_cancel(event: InputEvent) -> bool:
	if should_block_event(event):
		return false
	if not event.is_pressed() or event.is_echo():
		return false
	if event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == cancel_button()
	return false


static func is_select(event: InputEvent) -> bool:
	## Confirm face button / Enter — Space is Pass only, never confirm.
	if should_block_event(event):
		return false
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == confirm_button()
	if event is InputEventKey:
		var k := event as InputEventKey
		var code := k.keycode
		var phys := k.physical_keycode
		return (
			code == KEY_ENTER or phys == KEY_ENTER
			or code == KEY_KP_ENTER or phys == KEY_KP_ENTER
		)
	return false


static func is_pass(event: InputEvent) -> bool:
	## West-face (X) is the direct Pass shortcut in explore and combat.
	if should_block_event(event):
		return false
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_X
	return false


static func is_victory_exit(event: InputEvent) -> bool:
	## North-face (Y) opens the post-combat battlefield exit confirmation.
	if should_block_event(event):
		return false
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y
	return false


static func is_foe_roster_next(event: InputEvent) -> bool:
	## Right bumper / > (or .) — cycle down the combat foe list.
	if should_block_event(event):
		return false
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_SHOULDER
	if event is InputEventKey:
		var k := event as InputEventKey
		return (
			k.keycode == KEY_GREATER or k.physical_keycode == KEY_GREATER
			or k.keycode == KEY_PERIOD or k.physical_keycode == KEY_PERIOD
		)
	return false


static func is_foe_roster_prev(event: InputEvent) -> bool:
	## Left bumper / < (or ,) — cycle up the combat foe list.
	if should_block_event(event):
		return false
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_SHOULDER
	if event is InputEventKey:
		var k := event as InputEventKey
		return (
			k.keycode == KEY_LESS or k.physical_keycode == KEY_LESS
			or k.keycode == KEY_COMMA or k.physical_keycode == KEY_COMMA
		)
	return false


static func dir_from_event(event: InputEvent) -> Vector2i:
	## Single-step dir from a pressed key / d-pad / stick threshold.
	## Stick: one step per tilt (must return near-neutral first). Without this,
	## JoypadMotion floods while held and combat / Dir? / aim jump many tiles.
	if should_block_event(event):
		return Vector2i.ZERO
	if event is InputEventJoypadMotion:
		return stick_direction_step(event)
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
	if not _poll_allowed():
		return Vector2i.ZERO
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


static func is_dpad_held() -> bool:
	if not _poll_allowed():
		return false
	for device in Input.get_connected_joypads():
		if (
			Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT)
			or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT)
			or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP)
			or Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN)
		):
			return true
	return false


static func is_move_from_gamepad() -> bool:
	## True when the current held move comes from a pad (not arrow/WASD keys).
	## Matches read_move_dir() priority: keys win, so hybrid keyboard+pad is "keyboard".
	if not _poll_allowed():
		return false
	if (
		Input.is_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_LEFT)
		or Input.is_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_RIGHT)
		or Input.is_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_UP)
		or Input.is_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_DOWN)
	):
		return false
	if is_dpad_held():
		return true
	for device in Input.get_connected_joypads():
		if (
			absf(Input.get_joy_axis(device, JOY_AXIS_LEFT_X)) >= STICK_DEADZONE
			or absf(Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)) >= STICK_DEADZONE
		):
			return true
	return false


static func read_select_step() -> int:
	## -1 up, +1 down, 0 none. Keyboard/D-pad stay immediate; stick uses
	## press/release hysteresis while preserving the caller's hold-repeat timer.
	if not _poll_allowed():
		return 0
	if Input.is_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_UP):
		return -1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_DOWN):
		return 1
	for device in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP):
			return -1
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN):
			return 1
	for device in Input.get_connected_joypads():
		var value := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
		var latched := int(_select_y_latches.get(device, 0))
		if latched != 0:
			if absf(value) <= STICK_NAV_RELEASE:
				_select_y_latches[device] = 0
			elif signf(value) == float(latched):
				return latched
			## Opposite snap-back is ignored until neutral is observed.
			continue
		if absf(value) >= STICK_NAV_PRESS:
			var direction := -1 if value < 0.0 else 1
			_select_y_latches[device] = direction
			return direction
	return 0


static func read_select_step_x() -> int:
	## -1 left, +1 right, 0 none. Same hold-repeat contract as read_select_step().
	if not _poll_allowed():
		return 0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_LEFT):
		return -1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_RIGHT):
		return 1
	for device in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
			return -1
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
			return 1
	for device in Input.get_connected_joypads():
		var value := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
		var latched := int(_select_x_latches.get(device, 0))
		if latched != 0:
			if absf(value) <= STICK_NAV_RELEASE:
				_select_x_latches[device] = 0
			elif signf(value) == float(latched):
				return latched
			## Opposite snap-back is ignored until neutral is observed.
			continue
		if absf(value) >= STICK_NAV_PRESS:
			var direction := -1 if value < 0.0 else 1
			_select_x_latches[device] = direction
			return direction
	return 0


static func stick_axis_step(event: InputEvent, axis: JoyAxis) -> int:
	## One navigation step per deliberate tilt. The axis must return near
	## neutral before either direction can fire again, which filters snap-back.
	if should_block_event(event):
		return 0
	if not (event is InputEventJoypadMotion):
		return 0
	var motion := event as InputEventJoypadMotion
	if motion.axis != axis:
		return 0
	var key := "%d:%d" % [motion.device, int(axis)]
	var latched := int(_stick_nav_latches.get(key, 0))
	var value := motion.axis_value
	if absf(value) <= STICK_NAV_RELEASE:
		_stick_nav_latches[key] = 0
		return 0
	if absf(value) < STICK_NAV_PRESS:
		return 0
	var direction := -1 if value < 0.0 else 1
	if latched != 0:
		## Includes opposite-direction spring-back: neutral must be observed first.
		return 0
	_stick_nav_latches[key] = direction
	return direction


static func stick_direction_step(event: InputEvent) -> Vector2i:
	if not (event is InputEventJoypadMotion):
		return Vector2i.ZERO
	var motion := event as InputEventJoypadMotion
	if motion.axis == JOY_AXIS_LEFT_X:
		var step_x := stick_axis_step(event, JOY_AXIS_LEFT_X)
		if step_x != 0:
			## Diagonal tilts emit X then Y — latch the other axis so combat
			## doesn't spend two party turns on one flick.
			_latch_stick_axis_if_tilted(motion.device, JOY_AXIS_LEFT_Y)
			return Vector2i(step_x, 0)
		return Vector2i.ZERO
	if motion.axis == JOY_AXIS_LEFT_Y:
		var step_y := stick_axis_step(event, JOY_AXIS_LEFT_Y)
		if step_y != 0:
			_latch_stick_axis_if_tilted(motion.device, JOY_AXIS_LEFT_X)
			return Vector2i(0, step_y)
		return Vector2i.ZERO
	return Vector2i.ZERO


static func _latch_stick_axis_if_tilted(device: int, axis: JoyAxis) -> void:
	var key := "%d:%d" % [device, int(axis)]
	var value := Input.get_joy_axis(device, axis)
	if absf(value) > STICK_NAV_RELEASE:
		_stick_nav_latches[key] = -1 if value < 0.0 else 1


static func reset_stick_navigation() -> void:
	## A newly opened menu must not inherit a latch from a previous UI.
	_stick_nav_latches.clear()
	_select_x_latches.clear()
	_select_y_latches.clear()


static func latch_current_stick_navigation() -> void:
	## A menu opened by a stick direction must wait for that same tilt to
	## return to neutral before accepting its first navigation step.
	reset_stick_navigation()
	for device in Input.get_connected_joypads():
		_latch_stick_axis_if_tilted(device, JOY_AXIS_LEFT_X)
		_latch_stick_axis_if_tilted(device, JOY_AXIS_LEFT_Y)


static func stick_clear_if_released(event: InputEvent) -> void:
	## During foe turns / busy frames: clear latch on release only.
	## Do not latch a fresh tilt — that would eat the player's next move.
	if should_block_event(event):
		return
	if not (event is InputEventJoypadMotion):
		return
	var motion := event as InputEventJoypadMotion
	if absf(motion.axis_value) <= STICK_NAV_RELEASE:
		stick_axis_step(event, motion.axis)


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
	_ensure_action("confirm", [_key(KEY_ENTER)])
	_ensure_action("cancel", [_key(KEY_ESCAPE)])
	rebind_confirm_cancel()


static func _ensure_ui_nav() -> void:
	## Keep D-pad on native GUI focus navigation. Raw stick axes are removed:
	## screens consume them through stick_axis_step() with hysteresis instead.
	for action in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		_remove_joy_motion_events(action)
	_ensure_action(
		"ui_up",
		[
			_key(KEY_UP),
			_joy_button(JOY_BUTTON_DPAD_UP),
		]
	)
	_ensure_action(
		"ui_down",
		[
			_key(KEY_DOWN),
			_joy_button(JOY_BUTTON_DPAD_DOWN),
		]
	)
	_ensure_action(
		"ui_left",
		[
			_key(KEY_LEFT),
			_joy_button(JOY_BUTTON_DPAD_LEFT),
		]
	)
	_ensure_action(
		"ui_right",
		[
			_key(KEY_RIGHT),
			_joy_button(JOY_BUTTON_DPAD_RIGHT),
		]
	)
	_ensure_action(
		"ui_accept",
		[
			_key(KEY_ENTER),
			_key(KEY_KP_ENTER),
		]
	)
	_erase_key_from_action("confirm", KEY_SPACE)
	_erase_key_from_action("ui_accept", KEY_SPACE)
	_erase_key_from_action("ui_select", KEY_SPACE)
	_ensure_action("ui_cancel", [_key(KEY_ESCAPE)])
	rebind_confirm_cancel()


static func _bind_face_action(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, STICK_DEADZONE)
	_erase_joy_button_from_action(action, JOY_BUTTON_A)
	_erase_joy_button_from_action(action, JOY_BUTTON_B)
	_ensure_action(action, [_joy_button(button)])


static func _erase_joy_button_from_action(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		return
	var to_erase: Array[InputEvent] = []
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton:
			if (existing as InputEventJoypadButton).button_index == button:
				to_erase.append(existing)
	for existing in to_erase:
		InputMap.action_erase_event(action, existing)


static func _erase_key_from_action(action: String, phys: Key) -> void:
	if not InputMap.has_action(action):
		return
	var to_erase: Array[InputEvent] = []
	for existing in InputMap.action_get_events(action):
		if not (existing is InputEventKey):
			continue
		var a := existing as InputEventKey
		var code := a.physical_keycode if a.physical_keycode != KEY_NONE else a.keycode
		if code == phys:
			to_erase.append(existing)
	for existing in to_erase:
		InputMap.action_erase_event(action, existing)


static func _remove_joy_motion_events(action: String) -> void:
	if not InputMap.has_action(action):
		return
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadMotion:
			InputMap.action_erase_event(action, existing)


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
