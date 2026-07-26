extends Node

## Force OS window to stay exactly 16:9 while the user resizes.
## Logical game size remains 1280×720 (project stretch).

const CONFIG_PATH := "user://display.cfg"
const SECTION := "display"
const ASPECT := 16.0 / 9.0
const MIN_W := 960
const MIN_H := 540

enum WindowModeOption { WINDOWED, BORDERLESS, FULLSCREEN }

var _config := ConfigFile.new()
var _applying := false
var _prev := Vector2i.ZERO
## "w" = follow width, "h" = follow height (locked for the duration of a drag).
var _drag_axis := ""
var _idle_frames := 0


func _ready() -> void:
	_load_config()
	set_process(true)
	call_deferred("_boot")


func _boot() -> void:
	var win := get_window()
	win.min_size = Vector2i(MIN_W, MIN_H)
	if not win.size_changed.is_connected(_on_size_changed):
		win.size_changed.connect(_on_size_changed)
	_apply_startup_window()


func _process(_delta: float) -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		_drag_axis = ""
		return
	# Continuously enforce — macOS often ignores one-shot corrections during drag.
	_enforce(false)
	if _drag_axis != "":
		_idle_frames += 1
		if _idle_frames > 8:
			_drag_axis = ""
			_idle_frames = 0


func _on_size_changed() -> void:
	_idle_frames = 0
	_enforce(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_restore_windowed_size()
		_save_mode(WindowModeOption.WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_save_mode(WindowModeOption.BORDERLESS)


func _apply_startup_window() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
	var saved_mode := int(_config.get_value(SECTION, "mode", WindowModeOption.WINDOWED))
	match saved_mode:
		WindowModeOption.FULLSCREEN, WindowModeOption.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			_restore_windowed_size()


func _restore_windowed_size() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var size := Vector2i(
		int(_config.get_value(SECTION, "width", 1280)),
		int(_config.get_value(SECTION, "height", 720))
	)
	if not _config.has_section_key(SECTION, "width") \
			or size.x < MIN_W or size.y < MIN_H:
		if usable.size.x > 0:
			size = Vector2i(
				maxi(MIN_W, int(usable.size.x * 0.7)),
				maxi(MIN_H, int(usable.size.y * 0.7))
			)
		else:
			size = Vector2i(1280, 720)
	size = _size_from_width(size.x)
	## Oversized saved values are fine — just fit them to the current screen.
	size = _clamp_to_usable(size, usable.size)
	_apply_size(size)
	if usable.size.x > 0:
		DisplayServer.window_set_position(Vector2i(
			usable.position.x + (usable.size.x - size.x) / 2,
			usable.position.y + (usable.size.y - size.y) / 2
		))


func _enforce(from_signal: bool) -> void:
	if _applying:
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return

	var win := get_window()
	var cur: Vector2i = win.size
	if cur.x < 2 or cur.y < 2:
		return

	if _prev == Vector2i.ZERO:
		_prev = cur

	var dw: int = abs(cur.x - _prev.x)
	var dh: int = abs(cur.y - _prev.y)

	# Pick / keep the drag axis for this gesture.
	if from_signal or dw > 0 or dh > 0:
		if _drag_axis == "":
			if dw == 0 and dh == 0:
				pass
			elif dw >= dh:
				_drag_axis = "w"
			else:
				_drag_axis = "h"

	var target: Vector2i
	if _drag_axis == "h":
		target = _size_from_height(cur.y)
	else:
		# Default: width drives height (also covers corner / horizontal).
		target = _size_from_width(cur.x)

	var usable := DisplayServer.screen_get_usable_rect(
		DisplayServer.window_get_current_screen()
	).size
	target = _clamp_to_usable(target, usable)

	if abs(target.x - cur.x) <= 1 and abs(target.y - cur.y) <= 1:
		_prev = cur
		return

	_apply_size(target)


func _size_from_width(w: int) -> Vector2i:
	w = maxi(w, MIN_W)
	var h: int = int(round(float(w) / ASPECT))
	if h < MIN_H:
		h = MIN_H
		w = int(round(float(h) * ASPECT))
	return Vector2i(w, h)


func _size_from_height(h: int) -> Vector2i:
	h = maxi(h, MIN_H)
	var w: int = int(round(float(h) * ASPECT))
	if w < MIN_W:
		w = MIN_W
		h = int(round(float(w) / ASPECT))
	return Vector2i(w, h)


func _clamp_to_usable(size: Vector2i, usable: Vector2i) -> Vector2i:
	if usable.x <= 0 or usable.y <= 0:
		return size
	var out := size
	if out.x > usable.x:
		out = _size_from_width(usable.x)
	if out.y > usable.y:
		out = _size_from_height(usable.y)
	return out


func _apply_size(size: Vector2i) -> void:
	_applying = true
	var win := get_window()
	# Disconnect while applying to avoid re-entrant fights.
	if win.size_changed.is_connected(_on_size_changed):
		win.size_changed.disconnect(_on_size_changed)
	win.size = size
	DisplayServer.window_set_size(size)
	_prev = win.size
	if not win.size_changed.is_connected(_on_size_changed):
		win.size_changed.connect(_on_size_changed)
	_applying = false
	_persist_window_geometry()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_persist_window_geometry()


func _persist_window_geometry() -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var win := get_window()
	if win == null:
		return
	var size: Vector2i = win.size
	if size.x >= MIN_W and size.y >= MIN_H:
		_config.set_value(SECTION, "width", size.x)
		_config.set_value(SECTION, "height", size.y)
		_config.set_value(SECTION, "mode", WindowModeOption.WINDOWED)
		_config.save(CONFIG_PATH)


func _save_mode(mode: int) -> void:
	_config.set_value(SECTION, "mode", mode)
	_config.save(CONFIG_PATH)


func _load_config() -> void:
	_config.load(CONFIG_PATH)
