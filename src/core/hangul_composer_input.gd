extends RefCounted

## Shared libhangul physical-key composition (same path as talk / shop text).
## HangulInputSettings owns 한/영 mode; keyboard layout is per-session config.

var max_length: int = 16
var buffer: String = ""
var preedit: String = ""

var _composer: RefCounted = null


static func is_available() -> bool:
	return ClassDB.class_exists("HangulComposer")


func ensure() -> bool:
	if _composer != null:
		return true
	if not is_available():
		return false
	_composer = ClassDB.instantiate("HangulComposer") as RefCounted
	if _composer != null:
		_composer.call("set_keyboard", HangulInputSettings.layout_id())
	return _composer != null


func reset_composer() -> void:
	preedit = ""
	if _composer != null:
		_composer.call("reset")
		_composer.call("set_keyboard", HangulInputSettings.layout_id())


func begin(text: String) -> void:
	buffer = text
	reset_composer()
	ensure()


func display_text() -> String:
	return buffer + preedit


func flush_preedit() -> void:
	if _composer == null:
		preedit = ""
		return
	var flushed := str(_composer.call("flush"))
	_append_commit(flushed)
	preedit = ""


func handle_key(k: InputEventKey) -> Dictionary:
	## Returns { handled, submit, cancel } — caller owns focus / field chrome.
	var out := {"handled": false, "submit": false, "cancel": false}
	if not k.pressed or k.echo:
		return out
	if not ensure():
		return out

	if _is_input_mode_toggle(k):
		_toggle_input_mode()
		out.handled = true
		return out

	if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
		reset_composer()
		out.handled = true
		out.cancel = true
		return out

	if (
		k.keycode == KEY_ENTER
		or k.physical_keycode == KEY_ENTER
		or k.keycode == KEY_KP_ENTER
		or k.physical_keycode == KEY_KP_ENTER
	):
		flush_preedit()
		out.handled = true
		out.submit = true
		return out

	if k.keycode == KEY_BACKSPACE or k.physical_keycode == KEY_BACKSPACE:
		var erased: Dictionary = _composer.call("backspace") as Dictionary
		if bool(erased.get("consumed", false)):
			preedit = str(erased.get("preedit", ""))
			out.handled = true
			return out
		preedit = ""
		if not buffer.is_empty():
			buffer = buffer.substr(0, buffer.length() - 1)
		out.handled = true
		return out

	if k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		out.handled = true
		return out

	var ascii := physical_ascii(k)
	if ascii < 0:
		out.handled = true
		return out

	if buffer.length() >= max_length and preedit.is_empty():
		out.handled = true
		return out

	if not HangulInputSettings.is_korean_mode():
		_append_commit(String.chr(ascii))
		out.handled = true
		return out

	var result: Dictionary = _composer.call("process_key", ascii) as Dictionary
	_append_commit(str(result.get("commit", "")))
	preedit = str(result.get("preedit", ""))
	if not bool(result.get("consumed", false)):
		## Space / punctuation finish the syllable but are not libhangul-consumed.
		_append_commit(String.chr(ascii))
	out.handled = true
	return out


func _append_commit(text: String) -> void:
	if text.is_empty():
		return
	var room := max_length - buffer.length()
	if room <= 0:
		return
	buffer += text.substr(0, room)


func _toggle_input_mode() -> void:
	if HangulInputSettings.is_korean_mode():
		flush_preedit()
	else:
		reset_composer()
	HangulInputSettings.toggle_input_mode()


static func physical_ascii(k: InputEventKey) -> int:
	var code := int(k.physical_keycode)
	if code == KEY_NONE:
		code = int(k.keycode)
	if code >= KEY_A and code <= KEY_Z:
		return (65 if k.shift_pressed else 97) + (code - KEY_A)
	if code >= KEY_0 and code <= KEY_9:
		if k.shift_pressed:
			const SHIFT_DIGITS := ")!@#$%^&*("
			return SHIFT_DIGITS.unicode_at(code - KEY_0)
		return 48 + (code - KEY_0)
	if code < 32 or code > 126:
		return -1
	if not k.shift_pressed:
		return code
	const SHIFT_PUNCT := {
		32: 32, 39: 34, 44: 60, 45: 95, 46: 62, 47: 63,
		59: 58, 61: 43, 91: 123, 92: 124, 93: 125, 96: 126,
	}
	return int(SHIFT_PUNCT.get(code, code))


static func _is_input_mode_toggle(k: InputEventKey) -> bool:
	if k.echo:
		return false
	var code := k.keycode
	var physical := k.physical_keycode
	var os_name := OS.get_name()
	if os_name == "macOS" and (code == KEY_CAPSLOCK or physical == KEY_CAPSLOCK):
		return true
	if (
		(k.ctrl_pressed or k.shift_pressed)
		and (code == KEY_SPACE or physical == KEY_SPACE)
	):
		return true
	if os_name == "Windows":
		if (
			(code == KEY_ALT or physical == KEY_ALT)
			and k.location == KEY_LOCATION_RIGHT
		):
			return true
		var key_name := k.as_text_physical_keycode().to_lower()
		if (
			key_name.contains("hangul")
			or key_name.contains("hangeul")
			or key_name.contains("han/yeong")
			or key_name.contains("한/영")
		):
			return true
	return false
