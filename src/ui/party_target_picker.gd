extends RefCounted

## Shared cursor/input state for every right-side party roster target prompt.

const RESULT_NONE := 0
const RESULT_ACCEPT := 1
const RESULT_CANCEL := 2
const RESULT_INVALID := 3

var active := false
var cursor := 0

var _count := 0
var _skip_unavailable := false
var _is_available: Callable


func begin(
	count: int,
	initial_slot: int,
	skip_unavailable: bool = false,
	is_available: Callable = Callable()
) -> void:
	_count = maxi(count, 0)
	_skip_unavailable = skip_unavailable
	_is_available = is_available
	active = _count > 0
	cursor = clampi(initial_slot, 0, maxi(_count - 1, 0))
	if active and _skip_unavailable and not _slot_available(cursor):
		_move_to_available(1)


func stop() -> void:
	active = false
	cursor = 0
	_count = 0
	_skip_unavailable = false
	_is_available = Callable()


func nudge(delta: int) -> bool:
	if not active or delta == 0 or _count <= 1:
		return false
	var before := cursor
	if _skip_unavailable:
		_move_to_available(delta)
	else:
		cursor = posmod(cursor + delta, _count)
	return cursor != before


func handle_input(event: InputEvent) -> int:
	if not active or not event.is_pressed() or event.is_echo():
		return RESULT_NONE
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE:
			return RESULT_CANCEL
		if _is_confirm_key(key):
			return RESULT_ACCEPT
		var digit := _digit_slot(key)
		if digit >= 0:
			if digit >= _count:
				return RESULT_INVALID
			cursor = digit
			return RESULT_ACCEPT
		if _is_digit_key(key):
			return RESULT_INVALID
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if button.button_index == GameInput.cancel_button():
			return RESULT_CANCEL
		if button.button_index == GameInput.confirm_button():
			return RESULT_ACCEPT
	return RESULT_NONE


func _move_to_available(delta: int) -> void:
	var slot := cursor
	for _i in _count:
		slot = posmod(slot + delta, _count)
		if _slot_available(slot):
			cursor = slot
			return


func _slot_available(slot: int) -> bool:
	return not _is_available.is_valid() or bool(_is_available.call(slot))


func _is_confirm_key(key: InputEventKey) -> bool:
	return (
		key.keycode == KEY_ENTER or key.physical_keycode == KEY_ENTER
		or key.keycode == KEY_KP_ENTER or key.physical_keycode == KEY_KP_ENTER
	)


func _digit_slot(key: InputEventKey) -> int:
	for code in [key.keycode, key.physical_keycode]:
		if code >= KEY_1 and code <= KEY_8:
			return code - KEY_1
		if code >= KEY_KP_1 and code <= KEY_KP_8:
			return code - KEY_KP_1
	return -1


func _is_digit_key(key: InputEventKey) -> bool:
	for code in [key.keycode, key.physical_keycode]:
		if code >= KEY_0 and code <= KEY_9:
			return true
		if code >= KEY_KP_0 and code <= KEY_KP_9:
			return true
	return false
