extends Node

## Fixed windowed size — user resize always disabled.
## Logical design resolution 1280×720 (16:9).
## Fullscreen (macOS): borderless cover of the display once, then re-lock resize.
## Content scale uses the real window size (so content must grow with the surface).
## ⌘F / Ctrl+F is polled in _process (reliable on macOS; event path alone is not).

const CONFIG_PATH := "user://display.cfg"
const SECTION := "display"
const ASPECT := 16.0 / 9.0
const MIN_W := 960
const MIN_H := 540
const DEFAULT_W := 1280
const DEFAULT_H := 720
const SAVE_DEBOUNCE_SEC := 0.35
## Windowed sizes as % of usable screen (Options → Resolution).
const SCALE_PCTS: Array[int] = [90, 80, 70, 60, 50]
const DEFAULT_SCALE_PCT := 80
const _GameInput := preload("res://src/core/game_input.gd")

## Emitted when windowed ⇄ fullscreen changes (⌘F, Options, title bar, F11).
signal fullscreen_changed(active: bool)

enum WindowModeOption { WINDOWED, BORDERLESS, FULLSCREEN }

var _config := ConfigFile.new()
var _booting := true
var _save_timer := 0.0
var _save_pending := false
var _is_fullscreen := false
var _restoring_windowed := false
var _fs_chord_frame := -1
var _last_fs_toggle_msec := -1000
var _cmd_f_held := false
var _f11_held := false
var _window_scale_pct := DEFAULT_SCALE_PCT
var _windowed_size := Vector2i(DEFAULT_W, DEFAULT_H)
var _windowed_position := Vector2i(-1, -1)
var _persist_display := true


func _ready() -> void:
	_load_config()
	_ensure_input_map()
	_GameInput.ensure_input_map()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)
	call_deferred("_boot")


func _boot() -> void:
	_booting = true
	_apply_app_identity()
	_lock_resize()
	_apply_startup_window()
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_content_scale()
	_lock_resize()
	_booting = false


func _ensure_input_map() -> void:
	if not InputMap.has_action("toggle_fullscreen"):
		InputMap.add_action("toggle_fullscreen")
	## Cross-platform ⌘/Ctrl+F via command_or_control_autoremap (ctrl flag → ⌘ on macOS).
	var has_cmd_f := false
	for already in InputMap.action_get_events("toggle_fullscreen"):
		if already is InputEventKey:
			var ek := already as InputEventKey
			if (ek.physical_keycode == KEY_F or ek.keycode == KEY_F) \
					and (ek.ctrl_pressed or ek.meta_pressed):
				has_cmd_f = true
				break
	if not has_cmd_f:
		var chord := InputEventKey.new()
		chord.physical_keycode = KEY_F
		chord.keycode = KEY_F
		chord.ctrl_pressed = true
		chord.command_or_control_autoremap = true
		InputMap.action_add_event("toggle_fullscreen", chord)


func _apply_app_identity() -> void:
	var title := str(ProjectSettings.get_setting("application/config/name", "Ultima IV++")).strip_edges()
	if title.is_empty():
		title = "Ultima IV++"
	var root := _root_window()
	if root:
		root.title = title
	DisplayServer.window_set_title(title, 0)


func _process(delta: float) -> void:
	if _save_pending:
		_save_timer -= delta
		if _save_timer <= 0.0:
			_save_pending = false
			_flush_config()
	if _booting:
		return
	_sample_windowed_geometry()
	_poll_fullscreen_hotkeys()
	_sync_titlebar_mode()


## Keep the last normal window geometry in memory before macOS changes mode.
func _sample_windowed_geometry() -> void:
	if _is_fullscreen or _restoring_windowed:
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS):
		return
	var win := _root_window()
	if win == null:
		return
	if win.size.x >= MIN_W and win.size.y >= MIN_H:
		if _windowed_position == win.position:
			return
		_windowed_position = win.position
		_config.set_value(SECTION, "pos_x", win.position.x)
		_config.set_value(SECTION, "pos_y", win.position.y)
		_schedule_save()


## Route the macOS title-bar green button through the same path as Cmd+F.
func _sync_titlebar_mode() -> void:
	if OS.get_name() != "macOS" or _is_fullscreen or _restoring_windowed:
		return
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_MAXIMIZED \
			or mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		_enter_fullscreen(false)


## Polling survives scenes that swallow key events; key to ⌘F on macOS.
func _poll_fullscreen_hotkeys() -> void:
	## Prefer physical keys — more reliable with macOS layout / IME.
	var cmd_down := (
		Input.is_key_pressed(KEY_META) or Input.is_physical_key_pressed(KEY_META)
		or Input.is_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_CTRL)
	)
	var f_down := Input.is_key_pressed(KEY_F) or Input.is_physical_key_pressed(KEY_F)
	var chord := cmd_down and f_down \
			and not Input.is_key_pressed(KEY_ALT) and not Input.is_key_pressed(KEY_SHIFT)
	if chord and not _cmd_f_held:
		toggle_fullscreen()
	_cmd_f_held = chord

	var f11 := Input.is_key_pressed(KEY_F11) or Input.is_physical_key_pressed(KEY_F11)
	if f11 and not _f11_held and not chord:
		toggle_fullscreen()
	_f11_held = f11


func _input(event: InputEvent) -> void:
	if is_toggle_fullscreen_event(event):
		## Prevent the process-level poll from firing again while this chord
		## remains physically held.
		if event is InputEventKey:
			var k := event as InputEventKey
			if k.keycode == KEY_F or k.physical_keycode == KEY_F or k.key_label == KEY_F:
				_cmd_f_held = true
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if is_toggle_fullscreen_event(event):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func is_toggle_fullscreen_event(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return false
	if event.is_action_pressed("toggle_fullscreen"):
		return true
	## Same pattern as ⌘S quick-save in stub_world.
	if k.alt_pressed or k.shift_pressed:
		return false
	if not (k.ctrl_pressed or k.meta_pressed or k.is_command_or_control_pressed()):
		return false
	return k.keycode == KEY_F or k.physical_keycode == KEY_F or k.key_label == KEY_F


func toggle_fullscreen() -> void:
	var frame := Engine.get_process_frames()
	if frame == _fs_chord_frame:
		return
	var now := Time.get_ticks_msec()
	## _input and physical-key polling may observe the same press on adjacent
	## frames. Treat them as one toggle.
	if now - _last_fs_toggle_msec < 400:
		return
	_fs_chord_frame = frame
	_last_fs_toggle_msec = now
	if _is_fullscreen:
		_leave_fullscreen()
	else:
		_enter_fullscreen()


func is_fullscreen_active() -> bool:
	return _is_fullscreen


func window_scale_percent() -> int:
	return _window_scale_pct


func windowed_position() -> Vector2i:
	return _windowed_position


func set_windowed_position(pos: Vector2i, persist: bool = true) -> void:
	## Restore a saved windowed origin. Ignored while fullscreen (kept for later).
	if pos.x < 0 or pos.y < 0:
		return
	_windowed_position = pos
	if _is_fullscreen or _booting:
		if persist:
			_config.set_value(SECTION, "pos_x", pos.x)
			_config.set_value(SECTION, "pos_y", pos.y)
			_schedule_save()
		return
	_reapply_windowed_position()
	if persist:
		_remember_windowed(_windowed_size, _windowed_position)
		_flush_config()


func size_for_scale_percent(pct: int = -1) -> Vector2i:
	if pct < 0:
		pct = _window_scale_pct
	pct = _nearest_scale_pct(pct)
	var usable := _usable_size()
	if usable.x < 2 or usable.y < 2:
		return Vector2i(DEFAULT_W, DEFAULT_H)
	var w := maxi(MIN_W, int(round(float(usable.x) * float(pct) / 100.0)))
	return _clamp_to_usable(_size_from_width(w), usable)


func cycle_window_scale(delta: int) -> void:
	var idx := SCALE_PCTS.find(_window_scale_pct)
	if idx < 0:
		idx = SCALE_PCTS.find(DEFAULT_SCALE_PCT)
		if idx < 0:
			idx = 0
	set_window_scale_percent(SCALE_PCTS[posmod(idx + delta, SCALE_PCTS.size())])


func set_window_scale_percent(pct: int, persist: bool = true) -> void:
	_window_scale_pct = _nearest_scale_pct(pct)
	if persist:
		_config.set_value(SECTION, "scale_pct", _window_scale_pct)
	_windowed_size = size_for_scale_percent(_window_scale_pct)
	## Center after a scale change so the new frame sits cleanly.
	_windowed_position = Vector2i(-1, -1)
	if _is_fullscreen or _booting:
		if persist:
			_schedule_save()
		return
	_restoring_windowed = true
	_unlock_resize_briefly()
	_restore_windowed_geometry()
	_lock_resize()
	_restoring_windowed = false
	_apply_content_scale()
	if persist:
		_remember_windowed(_windowed_size, _windowed_position)
		_flush_config()


func set_fullscreen_active(on: bool, persist: bool = true) -> void:
	if on == _is_fullscreen:
		return
	_persist_display = persist
	if on:
		_enter_fullscreen()
	else:
		_leave_fullscreen()


func persist_pref() -> void:
	_config.set_value(SECTION, "scale_pct", _window_scale_pct)
	if _is_fullscreen:
		_set_saved_mode(WindowModeOption.FULLSCREEN)
	else:
		_set_saved_mode(WindowModeOption.WINDOWED)
		_remember_windowed(_windowed_size, _windowed_position)
	_flush_config()


func restore_pref() -> void:
	_load_config()
	var saved_mode := int(_config.get_value(SECTION, "mode", WindowModeOption.WINDOWED))
	var want_fs := saved_mode == WindowModeOption.FULLSCREEN \
			or saved_mode == WindowModeOption.BORDERLESS
	set_window_scale_percent(_window_scale_pct, false)
	set_fullscreen_active(want_fs, false)


func resolution_label_parts() -> Dictionary:
	## { "fullscreen": bool, "pct": int, "width": int, "height": int }
	var sz := size_for_scale_percent(_window_scale_pct)
	return {
		"fullscreen": _is_fullscreen,
		"pct": _window_scale_pct,
		"width": sz.x,
		"height": sz.y,
	}


func _nearest_scale_pct(pct: int) -> int:
	var best := DEFAULT_SCALE_PCT
	var best_d := 999
	for p in SCALE_PCTS:
		var d := absi(p - pct)
		if d < best_d:
			best_d = d
			best = p
	return best


func _enter_fullscreen(capture_windowed: bool = true) -> void:
	if capture_windowed:
		_capture_windowed_state()
	_is_fullscreen = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

	if OS.get_name() == "macOS":
		## Native Spaces fullscreen keeps the old client size on many macOS
		## setups. Cover the display with a borderless window instead so
		## content_scale sees a real full-display surface.
		_unlock_resize_briefly()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		_apply_fullscreen_surface()
		_lock_resize()
	else:
		_unlock_resize_briefly()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_lock_resize()

	_apply_content_scale()
	if _persist_display:
		_set_saved_mode(WindowModeOption.FULLSCREEN)
		_flush_config()
	fullscreen_changed.emit(true)
	call_deferred("_after_mode_change")


func _leave_fullscreen() -> void:
	_is_fullscreen = false
	_restoring_windowed = true
	## Always center when returning from fullscreen. A saved fullscreen-origin
	## position (often 0,0 on macOS) is never useful for a windowed restore.
	## Re-derive size from the Options scale percent (not a stale Retina rect).
	_windowed_size = size_for_scale_percent(_window_scale_pct)
	_windowed_position = Vector2i(-1, -1)
	_unlock_resize_briefly()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_restore_windowed_geometry()
	_lock_resize()
	if _persist_display:
		_set_saved_mode(WindowModeOption.WINDOWED)
		_flush_config()
	fullscreen_changed.emit(false)
	call_deferred("_after_mode_change")


func _after_mode_change() -> void:
	## macOS may finish rebuilding window chrome well after several frames.
	## Retry on real-time intervals so the final write happens after Cocoa's
	## fullscreen/borderless transition has completely settled.
	for delay in [0.0, 0.05, 0.15, 0.30, 0.50]:
		if delay > 0.0:
			await get_tree().create_timer(delay, true, false, true).timeout
		else:
			await get_tree().process_frame
		if _is_fullscreen and OS.get_name() == "macOS":
			_unlock_resize_briefly()
			_apply_fullscreen_surface()
			_lock_resize()
		elif not _is_fullscreen:
			_reapply_windowed_position()
		_apply_content_scale()
		_lock_resize()
	if not _is_fullscreen:
		_restoring_windowed = false
		if _persist_display:
			_remember_windowed(_windowed_size, _windowed_position)
			_flush_config()
	_persist_display = true


func _apply_startup_window() -> void:
	_lock_resize()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	var saved_mode := int(_config.get_value(SECTION, "mode", WindowModeOption.WINDOWED))
	_load_windowed_metrics()
	match saved_mode:
		WindowModeOption.FULLSCREEN, WindowModeOption.BORDERLESS:
			_is_fullscreen = true
			if OS.get_name() == "macOS":
				_unlock_resize_briefly()
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
				_apply_fullscreen_surface()
				_lock_resize()
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			_apply_content_scale()
		_:
			_is_fullscreen = false
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			_restore_windowed_geometry()


func _root_window() -> Window:
	return get_tree().root as Window


func _lock_resize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)


func _unlock_resize_briefly() -> void:
	## Programmatic set_size only — user still cannot drag if we re-lock after.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
	var win := _root_window()
	if win:
		win.min_size = Vector2i(0, 0)
		win.max_size = Vector2i(0, 0)


func _fix_window_size(size: Vector2i) -> void:
	var win := _root_window()
	if win == null:
		return
	## macOS applies a mode transition asynchronously. Fixed min/max constraints
	## keep Cocoa from restoring the old fullscreen-sized client afterward.
	win.min_size = size
	win.max_size = size
	win.size = size
	DisplayServer.window_set_size(size)


## Full-display client rect so content scale has a real large surface.
func _apply_fullscreen_surface() -> void:
	if not _is_fullscreen:
		return
	var screen := DisplayServer.window_get_current_screen()
	var rect := Rect2i(
		DisplayServer.screen_get_position(screen),
		DisplayServer.screen_get_size(screen)
	)
	if rect.size.x < 2 or rect.size.y < 2:
		return
	var win := _root_window()
	if win == null:
		return
	win.position = rect.position
	win.size = rect.size
	DisplayServer.window_set_position(rect.position)
	DisplayServer.window_set_size(rect.size)


## Design size 1280×720 → fit into the actual window (letterbox with KEEP).
## canvas_items draws at the window/Retina pixel size so fonts stay sharp;
## viewport stretch would rasterize 720p then upscale (blurry text).
func _apply_content_scale() -> void:
	var win := _root_window()
	if win == null:
		return
	win.content_scale_size = Vector2i(DEFAULT_W, DEFAULT_H)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL

	var surface := win.size
	if _is_fullscreen:
		var scr := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
		if scr.x * scr.y > surface.x * surface.y:
			surface = scr

	var want := _scale_to_fit(surface)
	var auto := _scale_to_fit(Vector2i(maxi(win.size.x, 1), maxi(win.size.y, 1)))
	if auto < 0.01:
		auto = 1.0
	if want < 0.01:
		want = 1.0
	## If the OS left the client stuck, boost factor so design-res still fills the screen.
	win.content_scale_factor = want / auto


func _load_windowed_metrics() -> void:
	if _config.has_section_key(SECTION, "scale_pct"):
		_window_scale_pct = _nearest_scale_pct(int(_config.get_value(SECTION, "scale_pct", DEFAULT_SCALE_PCT)))
	elif _config.has_section_key(SECTION, "width"):
		## Legacy: infer % from saved width vs usable area.
		var usable := _usable_size()
		var w := int(_config.get_value(SECTION, "width", DEFAULT_W))
		if usable.x > 1:
			_window_scale_pct = _nearest_scale_pct(int(round(float(w) / float(usable.x) * 100.0)))
		else:
			_window_scale_pct = DEFAULT_SCALE_PCT
	else:
		_window_scale_pct = DEFAULT_SCALE_PCT
	_windowed_size = size_for_scale_percent(_window_scale_pct)
	var px := int(_config.get_value(SECTION, "pos_x", -1))
	var py := int(_config.get_value(SECTION, "pos_y", -1))
	if px >= 0 and py >= 0:
		_windowed_position = Vector2i(px, py)
	else:
		_windowed_position = Vector2i(-1, -1)


func _scale_to_fit(size: Vector2i) -> float:
	if size.x < 1 or size.y < 1:
		return 1.0
	return minf(float(size.x) / float(DEFAULT_W), float(size.y) / float(DEFAULT_H))


func _usable_size() -> Vector2i:
	var usable := DisplayServer.screen_get_usable_rect(
		DisplayServer.window_get_current_screen()
	).size
	if usable.x < 2 or usable.y < 2:
		usable = DisplayServer.screen_get_size(
			DisplayServer.window_get_current_screen()
		)
	return usable


func _restore_windowed_geometry() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable_rect := DisplayServer.screen_get_usable_rect(screen)
	var usable := usable_rect.size
	if usable.x < 2 or usable.y < 2:
		usable = DisplayServer.screen_get_size(screen)

	var size := size_for_scale_percent(_window_scale_pct)
	_windowed_size = size

	## Do not persist yet: while leaving fullscreen, the current position is
	## still macOS's fullscreen origin. Persist only after centering below.
	_apply_size(size, false)
	if usable.x > 0 and usable.y > 0:
		var pos := _windowed_position
		var origin := usable_rect.position
		if usable_rect.size.x < 2:
			origin = Vector2i.ZERO
		if pos.x < 0 or pos.y < 0:
			pos = Vector2i(
				origin.x + (usable.x - size.x) / 2,
				origin.y + (usable.y - size.y) / 2
			)
		else:
			pos = Vector2i(
				clampi(pos.x, origin.x, origin.x + maxi(0, usable.x - size.x)),
				clampi(pos.y, origin.y, origin.y + maxi(0, usable.y - size.y))
			)
		DisplayServer.window_set_position(pos)
		var win := _root_window()
		if win:
			win.position = pos
		_windowed_position = pos
		_remember_windowed(size, pos)
	_lock_resize()


func _reapply_windowed_position() -> void:
	if _is_fullscreen:
		return
	var win := _root_window()
	if win == null:
		return
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x < 2 or usable.size.y < 2:
		return
	## During the first frames after leaving macOS fullscreen, win.size may
	## still report the full display. Restore the Options scale size first.
	var target_size := size_for_scale_percent(_window_scale_pct)
	_windowed_size = target_size
	_unlock_resize_briefly()
	_fix_window_size(target_size)
	var pos := _windowed_position
	if pos.x < 0 or pos.y < 0:
		pos = Vector2i(
			usable.position.x + (usable.size.x - target_size.x) / 2,
			usable.position.y + (usable.size.y - target_size.y) / 2
		)
	pos = Vector2i(
		clampi(pos.x, usable.position.x, usable.position.x + maxi(0, usable.size.x - target_size.x)),
		clampi(pos.y, usable.position.y, usable.position.y + maxi(0, usable.size.y - target_size.y))
	)
	win.position = pos
	DisplayServer.window_set_position(pos)
	_windowed_position = pos
	_lock_resize()


func _capture_windowed_state() -> void:
	if _is_fullscreen or _restoring_windowed:
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS):
		return
	var win := _root_window()
	if win == null:
		return
	## Resize is disabled — geometry is driven by scale_pct, not free drag.
	_windowed_size = size_for_scale_percent(_window_scale_pct)
	_config.set_value(SECTION, "scale_pct", _window_scale_pct)
	_config.set_value(SECTION, "width", _windowed_size.x)
	_config.set_value(SECTION, "height", _windowed_size.y)
	var pos: Vector2i = win.position
	_windowed_position = pos
	_config.set_value(SECTION, "pos_x", pos.x)
	_config.set_value(SECTION, "pos_y", pos.y)


func _size_from_width(w: int) -> Vector2i:
	w = maxi(w, MIN_W)
	var h: int = int(round(float(w) / ASPECT))
	if h < MIN_H:
		h = MIN_H
		w = int(round(float(h) * ASPECT))
	return Vector2i(w, h)


func _clamp_to_usable(size: Vector2i, usable: Vector2i) -> Vector2i:
	if usable.x <= 0 or usable.y <= 0:
		return size
	var out := size
	if out.x > usable.x:
		out = _size_from_width(usable.x)
	if out.y > usable.y:
		var h := usable.y
		var w: int = int(round(float(h) * ASPECT))
		if w > usable.x:
			out = _size_from_width(usable.x)
		else:
			out = Vector2i(maxi(w, MIN_W), maxi(h, MIN_H))
			if out.x > usable.x or out.y > usable.y:
				out = _size_from_width(mini(usable.x, int(float(usable.y) * ASPECT)))
	return out


func _apply_size(size: Vector2i, persist: bool = true) -> void:
	var win := _root_window()
	if win == null:
		return
	_unlock_resize_briefly()
	_fix_window_size(size)
	_lock_resize()
	_apply_content_scale()
	if persist and not _booting:
		_remember_windowed(size, win.position)
		_schedule_save()


func _remember_windowed(size: Vector2i, pos: Vector2i) -> void:
	if _is_fullscreen:
		return
	if size.x < MIN_W or size.y < MIN_H:
		return
	_windowed_size = size
	_windowed_position = pos
	_config.set_value(SECTION, "scale_pct", _window_scale_pct)
	_config.set_value(SECTION, "width", size.x)
	_config.set_value(SECTION, "height", size.y)
	_config.set_value(SECTION, "pos_x", pos.x)
	_config.set_value(SECTION, "pos_y", pos.y)
	if not _is_fullscreen:
		_config.set_value(SECTION, "mode", WindowModeOption.WINDOWED)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_closing()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if not _booting and not _is_fullscreen and not _restoring_windowed:
			_capture_windowed_state()
			_schedule_save()
	elif what == NOTIFICATION_WM_SIZE_CHANGED:
		if not _booting:
			_apply_content_scale()
			_lock_resize()


func _on_closing() -> void:
	if not _is_fullscreen:
		_capture_windowed_state()
	if _is_fullscreen:
		_set_saved_mode(WindowModeOption.FULLSCREEN)
	else:
		_set_saved_mode(WindowModeOption.WINDOWED)
	_flush_config()


func _set_saved_mode(mode: int) -> void:
	_config.set_value(SECTION, "mode", mode)


func _schedule_save() -> void:
	_save_pending = true
	_save_timer = SAVE_DEBOUNCE_SEC


func _flush_config() -> void:
	_config.save(CONFIG_PATH)


func _load_config() -> void:
	_config.load(CONFIG_PATH)
	_load_windowed_metrics()
