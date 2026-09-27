class_name OptionsPanel
extends Control

## In-game Esc → Options submenu.
## Also embedded in the title map frame (main menu).
## Items: language pair, graphics, resolution pair, audio pair, then gamepad.
## Left/right (or Enter) cycles the selected item; Esc closes.

enum Item {
	LANGUAGE = 0,
	HANGUL_KEYBOARD = 1,
	GRAPHICS = 2,
	APPLE2_DISK = 3,
	RESOLUTION = 4,
	FULLSCREEN = 5,
	SFX = 6,
	MUSIC = 7,
	GAMEPAD = 8,
}

const ITEM_COUNT := 9
const GROUP_AFTER: Array[int] = [
	Item.HANGUL_KEYBOARD,
	Item.FULLSCREEN,
	Item.MUSIC,
]
const COL_TEXT := Color(0.91, 0.9, 0.82, 1)
const COL_ACCENT := Color(0.95, 0.85, 0.45, 1)
const COL_CURSOR := Color(0.22, 0.42, 0.82, 0.55)
const COL_CURSOR_EDGE := Color(0.38, 0.58, 0.82, 0.72)
const FONT_SIZE := 14
const ROW_H := 26
const GROUP_GAP := 10
const PANEL_W := 440.0

var _backdrop: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _title: Label
var _col: VBoxContainer
var _list: VBoxContainer
var _row_labs: Array[Label] = []
var _row_names: Array[Label] = []
var _row_lefts: Array[Label] = []
var _row_rights: Array[Label] = []
var _row_boxes: Array[HBoxContainer] = []
var _row_bgs: Array[ColorRect] = []
var _row_edges: Array[TextureRect] = []
var _row_wraps: Array[Control] = []
var _group_gaps: Array[Control] = []
var _cursor := 0
var _embedded := false
var _embed_rect := Rect2()
var _apple2_dialog: FileDialog
var _picking_apple2 := false
var _row_font_sz := FONT_SIZE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false
	if not DisplaySettings.fullscreen_changed.is_connected(_on_fullscreen_changed):
		DisplaySettings.fullscreen_changed.connect(_on_fullscreen_changed)


func _on_fullscreen_changed(_active: bool) -> void:
	## ⌘F / F11 / title bar can change mode while this panel is open.
	if visible:
		refresh()


func is_open() -> bool:
	return visible


func is_picking_file() -> bool:
	return _picking_apple2


func is_embedded() -> bool:
	return _embedded


func cursor() -> int:
	return _cursor


func open_panel(default_cursor: int = 0) -> void:
	_embedded = false
	_embed_rect = Rect2()
	GameState.refresh_apple2_dsk()
	_cursor = clampi(default_cursor, 0, ITEM_COUNT - 1)
	_ensure_cursor_on_visible_item()
	_apply_presentation()
	_refresh_labels()
	_sync_cursor()
	visible = true
	move_to_front()


## Title map frame — no modal backdrop; same rows as the Esc options panel.
func open_embedded(rect: Rect2, default_cursor: int = 0) -> void:
	_embedded = true
	_embed_rect = rect
	GameState.refresh_apple2_dsk()
	_cursor = clampi(default_cursor, 0, ITEM_COUNT - 1)
	_ensure_cursor_on_visible_item()
	_apply_presentation()
	_refresh_labels()
	_sync_cursor()
	visible = true
	move_to_front()


func set_embed_rect(rect: Rect2) -> void:
	if not visible or not _embedded:
		return
	_embed_rect = rect
	_apply_presentation()


func close_panel() -> void:
	visible = false
	_embedded = false


func nudge_cursor(delta: int) -> void:
	var vis := _visible_item_count()
	if vis <= 1:
		return
	var step := 1 if delta >= 0 else -1
	var next := _cursor
	for _i in ITEM_COUNT:
		next = posmod(next + step, ITEM_COUNT)
		if _item_visible(next):
			_cursor = next
			break
	_sync_cursor()


func set_cursor(index: int) -> void:
	if index < 0 or index >= ITEM_COUNT:
		return
	if not _item_visible(index):
		return
	_cursor = index
	_sync_cursor()


func refresh() -> void:
	GameState.refresh_apple2_dsk()
	_ensure_cursor_on_visible_item()
	_apply_presentation()
	_refresh_labels()
	_sync_cursor()


func cycle_language(delta: int = 1) -> void:
	## Writes app prefs immediately. The next Save also snapshots all Options.
	var langs := GameState.LANG_IDS
	var i := langs.find(GameState.language)
	if i < 0:
		i = 0
	GameState.language = langs[posmod(i + delta, langs.size())]
	_refresh_labels()
	_sync_cursor()


func cycle_resolution(delta: int = 1) -> void:
	DisplaySettings.cycle_window_scale(delta)
	_refresh_labels()
	_sync_cursor()


func cycle_fullscreen(_delta: int = 1) -> void:
	## Same code path as ⌘F / Ctrl+F.
	DisplaySettings.toggle_fullscreen()
	_refresh_labels()
	_sync_cursor()


func cycle_current(delta: int = 1) -> void:
	if not _item_visible(_cursor):
		_ensure_cursor_on_visible_item()
		_sync_cursor()
		return
	match _cursor:
		Item.LANGUAGE:
			cycle_language(delta)
		Item.HANGUL_KEYBOARD:
			HangulInputSettings.cycle_layout(delta)
			_refresh_labels()
			_sync_cursor()
		Item.GRAPHICS:
			cycle_graphics(delta)
		Item.APPLE2_DISK:
			cycle_apple2_disk(delta)
		Item.GAMEPAD:
			GamepadSettings.cycle_layout(delta)
			_refresh_labels()
			_sync_cursor()
		Item.RESOLUTION:
			cycle_resolution(delta)
		Item.FULLSCREEN:
			cycle_fullscreen(delta)
		Item.SFX:
			cycle_sfx(delta)
		Item.MUSIC:
			cycle_music(delta)
		_:
			pass


func cycle_graphics(delta: int = 1) -> void:
	GraphicsSettings.cycle_tileset(delta)
	_refresh_labels()
	_sync_cursor()


func cycle_apple2_disk(_delta: int = 1) -> void:
	if not _item_visible(Item.APPLE2_DISK):
		return
	_open_apple2_dialog()


func _open_apple2_dialog() -> void:
	_ensure_apple2_dialog()
	_picking_apple2 = true
	var start := GameState.apple2_picker_start_dir()
	if not start.is_empty() and not _apple2_dialog.use_native_dialog:
		_apple2_dialog.current_dir = start
	_apple2_dialog.popup_centered_ratio(0.65)


func _ensure_apple2_dialog() -> void:
	if _apple2_dialog != null:
		return
	_apple2_dialog = FileDialog.new()
	_apple2_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_apple2_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_apple2_dialog.use_native_dialog = _use_native_file_dialog()
	_apple2_dialog.title = Locale.t("boot_apple2_prompt")
	_apple2_dialog.ok_button_text = Locale.t("boot_apple2_select")
	_apple2_dialog.cancel_button_text = Locale.t("boot_path_cancel")
	_apple2_dialog.min_size = Vector2i(760, 480)
	_apple2_dialog.exclusive = true
	_apple2_dialog.unresizable = false
	_apple2_dialog.add_filter("*.dsk", "Apple II disk")
	_apple2_dialog.file_selected.connect(_on_apple2_file_selected)
	_apple2_dialog.canceled.connect(_on_apple2_canceled)
	add_child(_apple2_dialog)


func _use_native_file_dialog() -> bool:
	if OS.get_name() != "macOS":
		return false
	return OS.is_sandboxed() or not OS.has_feature("editor")


func _on_apple2_file_selected(path: String) -> void:
	_picking_apple2 = false
	GameState.try_set_apple2_dsk_path(path)
	_ensure_cursor_on_visible_item()
	_apply_presentation()
	_refresh_labels()
	_sync_cursor()


func _on_apple2_canceled() -> void:
	_picking_apple2 = false


func cycle_sfx(_delta: int = 1) -> void:
	AudioSfx.set_enabled(not AudioSfx.is_enabled())
	_refresh_labels()
	_sync_cursor()


func cycle_music(delta: int = 1) -> void:
	var on := AudioSfx.music_enabled()
	var pct := AudioSfx.music_volume_percent()
	if not on:
		if delta > 0:
			AudioSfx.music_set_enabled(true)
	else:
		var next := pct + delta * 10
		if next < 10:
			AudioSfx.music_set_enabled(false)
		else:
			AudioSfx.music_set_volume_percent(mini(next, 100))
	_refresh_labels()
	_sync_cursor()


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.55)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	_panel.add_theme_stylebox_override("panel", UiTheme.make_panel())
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_center.add_child(_panel)

	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 8)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_col)

	_title = Label.new()
	_title.add_theme_font_override("font", UiTheme.font_bold())
	_title.add_theme_font_size_override("font_size", FONT_SIZE + 2)
	_title.add_theme_color_override("font_color", COL_ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(_title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(_list)

	_row_labs.clear()
	_row_names.clear()
	_row_lefts.clear()
	_row_rights.clear()
	_row_boxes.clear()
	_row_bgs.clear()
	_row_edges.clear()
	_row_wraps.clear()
	_group_gaps.clear()
	for i in ITEM_COUNT:
		var wrap := Control.new()
		wrap.custom_minimum_size = Vector2(0, ROW_H)
		wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrap.mouse_filter = Control.MOUSE_FILTER_STOP
		wrap.mouse_default_cursor_shape = Control.CURSOR_ARROW
		var item_i := i
		wrap.gui_input.connect(func(event: InputEvent) -> void: _on_row_gui(item_i, event))
		_list.add_child(wrap)

		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(bg)

		var edge := UiTheme.make_selection_edge("", FONT_SIZE)
		wrap.add_child(edge)

		var box := HBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 8
		box.offset_right = -8
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 8)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(box)

		var name_lab := _make_row_text_label()
		var left_lab := _make_row_arrow_label("◂")
		left_lab.gui_input.connect(func(event: InputEvent) -> void: _on_arrow_gui(item_i, -1, event))
		var lab := _make_row_text_label()
		var right_lab := _make_row_arrow_label("▸")
		right_lab.gui_input.connect(func(event: InputEvent) -> void: _on_arrow_gui(item_i, 1, event))
		box.add_child(name_lab)
		box.add_child(left_lab)
		box.add_child(lab)
		box.add_child(right_lab)

		_row_wraps.append(wrap)
		_row_boxes.append(box)
		_row_names.append(name_lab)
		_row_lefts.append(left_lab)
		_row_labs.append(lab)
		_row_rights.append(right_lab)
		_row_bgs.append(bg)
		_row_edges.append(edge)
		if i in GROUP_AFTER:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, GROUP_GAP)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_list.add_child(gap)
			_group_gaps.append(gap)

	_refresh_labels()


func _apply_presentation() -> void:
	if _backdrop == null or _panel == null or _center == null:
		return
	if _embedded and _embed_rect.size.x > 8.0 and _embed_rect.size.y > 8.0:
		_backdrop.visible = false
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		anchor_right = 0.0
		anchor_bottom = 0.0
		position = _embed_rect.position
		size = _embed_rect.size
		custom_minimum_size = _embed_rect.size
		_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		## Full-bleed rows inside the map frame (same item text as Esc options).
		var bare := StyleBoxEmpty.new()
		_panel.add_theme_stylebox_override("panel", bare)
		_panel.custom_minimum_size = Vector2(_embed_rect.size.x, 0)
		_title.visible = true
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var col_sep := 4
		var list_sep := 1
		var group_gap := 6
		if _col != null:
			_col.add_theme_constant_override("separation", col_sep)
		_list.add_theme_constant_override("separation", list_sep)
		var vis := _visible_item_count()
		var list_children := float(vis + _group_gaps.size())
		var overhead := (
			float(col_sep)
			+ float(list_sep) * maxf(0.0, list_children - 1.0)
			+ float(group_gap) * float(_group_gaps.size())
		)
		var avail := maxf(48.0, _embed_rect.size.y - overhead)
		var row_h := clampf(avail / float(vis + 1), 15.0, 36.0)
		var font_sz := clampi(int(row_h * 0.52), 11, 20)
		_title.add_theme_font_size_override("font_size", font_sz + 1)
		_title.custom_minimum_size = Vector2(0, row_h)
		for i in ITEM_COUNT:
			_style_row_labels(i, font_sz)
			_apply_row_slot(i, row_h)
		_apply_fixed_columns(font_sz)
		for gap in _group_gaps:
			gap.custom_minimum_size = Vector2(0, group_gap)
	else:
		_backdrop.visible = true
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		position = Vector2.ZERO
		custom_minimum_size = Vector2.ZERO
		_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_panel.custom_minimum_size = Vector2(PANEL_W, 0)
		_panel.add_theme_stylebox_override("panel", UiTheme.make_panel())
		if _col != null:
			_col.add_theme_constant_override("separation", 8)
		_list.add_theme_constant_override("separation", 3)
		_title.visible = true
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title.add_theme_font_size_override("font_size", FONT_SIZE + 2)
		_title.custom_minimum_size = Vector2.ZERO
		for i in ITEM_COUNT:
			_style_row_labels(i, FONT_SIZE)
			_apply_row_slot(i, ROW_H)
		_apply_fixed_columns(FONT_SIZE)
		for gap in _group_gaps:
			gap.custom_minimum_size = Vector2(0, GROUP_GAP)


func _refresh_labels() -> void:
	_title.text = Locale.t("esc_options_title")
	for i in ITEM_COUNT:
		if i < _row_names.size():
			_row_names[i].text = "%s:" % _item_name_text(i)
		if i < _row_labs.size():
			_row_labs[i].text = _item_value_text(i)
			_row_labs[i].add_theme_color_override("font_color", COL_TEXT)
	_apply_row_visibility()
	_apply_fixed_columns(_row_font_sz)


func _make_row_text_label() -> Label:
	var lab := Label.new()
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_override("font", UiTheme.font())
	lab.add_theme_font_size_override("font_size", FONT_SIZE)
	lab.add_theme_color_override("font_color", COL_TEXT)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lab


func _make_row_arrow_label(text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.custom_minimum_size = Vector2(22, 0)
	lab.add_theme_font_override("font", UiTheme.font_bold())
	lab.add_theme_font_size_override("font_size", FONT_SIZE)
	lab.add_theme_color_override("font_color", COL_ACCENT)
	lab.mouse_filter = Control.MOUSE_FILTER_STOP
	lab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return lab


func _on_row_gui(index: int, event: InputEvent) -> void:
	if not _is_left_click(event):
		return
	set_cursor(index)
	accept_event()


func _on_arrow_gui(index: int, delta: int, event: InputEvent) -> void:
	if not _is_left_click(event):
		return
	set_cursor(index)
	cycle_current(delta)
	accept_event()


func _is_left_click(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mb := event as InputEventMouseButton
	return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not mb.double_click


func _style_row_labels(index: int, font_sz: int) -> void:
	_row_font_sz = font_sz
	for lab in [_row_names[index], _row_labs[index], _row_lefts[index], _row_rights[index]]:
		lab.add_theme_font_size_override("font_size", font_sz)
	if index < _row_boxes.size():
		_row_boxes[index].offset_left = 8
		_row_boxes[index].offset_right = -8


func _apply_fixed_columns(font_sz: int) -> void:
	if _row_names.is_empty() or _row_labs.is_empty():
		return
	var name_font := UiTheme.font()
	var value_font := UiTheme.font()
	var name_w := 0.0
	for key in _item_name_keys():
		for sample in Locale.variants(key):
			name_w = maxf(name_w, _text_width(name_font, font_sz, "%s:" % sample))
	var value_w := _text_width(value_font, font_sz, "Apple II Mono White")
	for sample in _value_width_samples():
		value_w = maxf(value_w, _text_width(value_font, font_sz, sample))
	name_w = ceilf(name_w) + 2.0
	value_w = ceilf(value_w) + 4.0
	var arrow_w := maxf(22.0, float(font_sz) * 1.35)
	for i in ITEM_COUNT:
		_row_names[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_row_names[i].custom_minimum_size = Vector2(name_w, 0)
		_row_names[i].size_flags_horizontal = Control.SIZE_SHRINK_END
		_row_labs[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_row_labs[i].custom_minimum_size = Vector2(value_w, 0)
		_row_labs[i].size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_row_labs[i].clip_text = true
		_row_lefts[i].custom_minimum_size = Vector2(arrow_w, 0)
		_row_rights[i].custom_minimum_size = Vector2(arrow_w, 0)


func _text_width(font: Font, font_sz: int, text: String) -> float:
	if font == null or text.is_empty():
		return 0.0
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz).x


func _value_width_samples() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for key in [
		"lang_en_us",
		"lang_en_u4",
		"lang_ko",
		"hangul_keyboard_2",
		"hangul_keyboard_39",
		"hangul_keyboard_3f",
		"esc_options_graphics_new_color",
		"esc_options_graphics_apple2_color",
		"esc_options_graphics_apple2_mono",
		"esc_options_graphics_apple2_mono_green",
		"esc_options_apple2_disk_none",
		"esc_options_apple2_disk_set",
		"esc_options_fullscreen_state_on",
		"esc_options_fullscreen_state_off",
		"esc_options_state_on",
		"esc_options_state_off",
		"esc_options_gamepad_xbox",
		"esc_options_gamepad_nintendo",
	]:
		out.append_array(Locale.variants(key))
	out.append_array(Locale.variants("esc_options_music_volume", [100]))
	for pct in DisplaySettings.SCALE_PCTS:
		var sz := DisplaySettings.size_for_scale_percent(int(pct))
		out.append_array(Locale.variants(
			"esc_options_resolution_windowed",
			[int(pct), sz.x, sz.y]
		))
	return out


func _item_name_keys() -> PackedStringArray:
	return PackedStringArray([
		"menu_language",
		"esc_options_hangul_keyboard",
		"esc_options_graphics",
		"esc_options_apple2_disk",
		"esc_options_resolution",
		"esc_options_fullscreen",
		"esc_options_sfx",
		"esc_options_music",
		"esc_options_gamepad",
	])


func _item_name_text(index: int) -> String:
	var keys := _item_name_keys()
	if index < 0 or index >= keys.size():
		return ""
	return Locale.t(keys[index])


func _item_value_text(index: int) -> String:
	match index:
		Item.LANGUAGE:
			return Locale.lang_label()
		Item.HANGUL_KEYBOARD:
			return Locale.t("hangul_keyboard_" + HangulInputSettings.layout_id())
		Item.GRAPHICS:
			return _graphics_value_text()
		Item.APPLE2_DISK:
			return (
				Locale.t("esc_options_apple2_disk_set")
				if GameState.apple2_dsk_ok
				else Locale.t("esc_options_apple2_disk_none")
			)
		Item.RESOLUTION:
			return _resolution_value_text()
		Item.FULLSCREEN:
			return (
				Locale.t("esc_options_fullscreen_state_on")
				if DisplaySettings.is_fullscreen_active()
				else Locale.t("esc_options_fullscreen_state_off")
			)
		Item.SFX:
			return _on_off_state(AudioSfx.is_enabled())
		Item.MUSIC:
			return (
				Locale.t("esc_options_music_volume", [AudioSfx.music_volume_percent()])
				if AudioSfx.music_enabled()
				else Locale.t("esc_options_state_off")
			)
		Item.GAMEPAD:
			return Locale.t("esc_options_gamepad_" + GamepadSettings.layout_id())
		_:
			return ""


func _item_visible(index: int) -> bool:
	if index == Item.APPLE2_DISK:
		return not GameState.apple2_dsk_ok
	return index >= 0 and index < ITEM_COUNT


func _visible_item_count() -> int:
	var n := 0
	for i in ITEM_COUNT:
		if _item_visible(i):
			n += 1
	return n


func _ensure_cursor_on_visible_item() -> void:
	if _item_visible(_cursor):
		return
	for i in ITEM_COUNT:
		var idx := posmod(_cursor + i, ITEM_COUNT)
		if _item_visible(idx):
			_cursor = idx
			return
	_cursor = 0


func _apply_row_slot(index: int, row_h: float) -> void:
	if index < 0 or index >= _row_wraps.size():
		return
	if _item_visible(index):
		_row_wraps[index].visible = true
		_row_wraps[index].custom_minimum_size = Vector2(0, row_h)
	else:
		_row_wraps[index].visible = false
		_row_wraps[index].custom_minimum_size = Vector2.ZERO


func _apply_row_visibility() -> void:
	for i in ITEM_COUNT:
		if _item_visible(i):
			_row_wraps[i].visible = true
			if _row_wraps[i].custom_minimum_size.y <= 0.0:
				_row_wraps[i].custom_minimum_size = Vector2(0, ROW_H)
		else:
			_row_wraps[i].visible = false
			_row_wraps[i].custom_minimum_size = Vector2.ZERO


func _graphics_value_text() -> String:
	var tid := GraphicsSettings.tileset_id()
	var key := "esc_options_graphics_new_color"
	if tid == "apple2_color":
		key = "esc_options_graphics_apple2_color"
	elif tid == "apple2_mono":
		key = "esc_options_graphics_apple2_mono"
	elif tid == "apple2_mono_green":
		key = "esc_options_graphics_apple2_mono_green"
	return Locale.t(key)


func _resolution_value_text() -> String:
	var parts: Dictionary = DisplaySettings.resolution_label_parts()
	var pct := int(parts.get("pct", 80))
	var w := int(parts.get("width", 1280))
	var h := int(parts.get("height", 720))
	return Locale.t("esc_options_resolution_windowed", [pct, w, h])


func _on_off_state(on: bool) -> String:
	return Locale.t("esc_options_state_on" if on else "esc_options_state_off")


func _sync_cursor() -> void:
	for i in ITEM_COUNT:
		var on := i == _cursor and _item_visible(i)
		_row_bgs[i].color = COL_CURSOR if on else Color(0, 0, 0, 0)
		UiTheme.set_selection_edge_active(_row_edges[i], on, COL_CURSOR_EDGE)
