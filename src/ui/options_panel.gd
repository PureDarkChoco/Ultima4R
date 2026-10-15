class_name OptionsPanel
extends Control

## Shared title/in-game options panel.
## Up/down selects a row, left/right changes its value, and Tab/LB/RB changes tabs.

signal back_requested

enum Tab { LANGUAGE, GRAPHICS, SOUND, GAME, COMMON }
enum Item {
	LANGUAGE,
	HANGUL_KEYBOARD,
	GRAPHICS,
	RESOLUTION,
	FULLSCREEN,
	SFX,
	MUSIC,
	BACKGROUND_AUDIO,
	DOS_PATH,
	APPLE2_PROGRAM_PATH,
	APPLE2_BRITANNIA_PATH,
	COMBAT_STYLE,
	GAMEPAD,
	BACK,
	TAB_BAR,
}

const TAB_COUNT := 5
const ITEM_COUNT := 13
const COL_TEXT := Color(0.91, 0.9, 0.82, 1)
const COL_ACCENT := Color(0.95, 0.85, 0.45, 1)
const COL_CURSOR := Color(0.22, 0.42, 0.82, 0.55)
const COL_CURSOR_EDGE := Color(0.38, 0.58, 0.82, 0.72)
const FONT_SIZE := 14
const ROW_H := 28
const PANEL_W := 610.0

var _backdrop: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _col: VBoxContainer
var _title: Label
var _tabs: HBoxContainer
var _tab_buttons: Array[Button] = []
var _list: VBoxContainer
var _row_labs: Array[Label] = []
var _row_names: Array[Label] = []
var _row_lefts: Array[Label] = []
var _row_rights: Array[Label] = []
var _row_bgs: Array[ColorRect] = []
var _row_edges: Array[TextureRect] = []
var _row_wraps: Array[Control] = []
var _back_wrap: Control
var _back_bg: ColorRect
var _back_edge: TextureRect
var _back_label: Label

var _tab := Tab.LANGUAGE
var _cursor := Item.LANGUAGE
var _tab_cursors: Array[int] = [
	Item.LANGUAGE,
	Item.GRAPHICS,
	Item.SFX,
	Item.COMBAT_STYLE,
	Item.DOS_PATH,
]
var _embedded := false
var _embed_rect := Rect2()
var _row_font_sz := FONT_SIZE

var _dos_dialog: FileDialog
var _program_dialog: FileDialog
var _britannia_dialog: FileDialog
var _picking_file := false
var _path_note := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false
	if not DisplaySettings.fullscreen_changed.is_connected(_on_fullscreen_changed):
		DisplaySettings.fullscreen_changed.connect(_on_fullscreen_changed)


func _on_fullscreen_changed(_active: bool) -> void:
	if visible:
		refresh()


func is_open() -> bool:
	return visible


func is_picking_file() -> bool:
	return _picking_file


func is_embedded() -> bool:
	return _embedded


func cursor() -> int:
	return _cursor


func current_tab() -> int:
	return _tab


func is_back_selected() -> bool:
	return _cursor == Item.BACK


func open_panel(default_cursor: int = 0) -> void:
	_open(false, Rect2(), default_cursor)


func open_embedded(rect: Rect2, default_cursor: int = 0) -> void:
	_open(true, rect, default_cursor)


func _open(embedded: bool, rect: Rect2, default_cursor: int) -> void:
	_embedded = embedded
	_embed_rect = rect
	GameState.refresh_apple2_dsk()
	_path_note.clear()
	_set_tab_for_item(clampi(default_cursor, 0, ITEM_COUNT - 1))
	_cursor = clampi(default_cursor, 0, ITEM_COUNT - 1)
	_remember_cursor()
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


func cycle_tab(delta: int) -> void:
	if delta == 0:
		return
	var keep_tab_cursor := _cursor == Item.TAB_BAR
	if _cursor != Item.BACK and not keep_tab_cursor:
		_remember_cursor()
	_tab = posmod(_tab + (1 if delta > 0 else -1), TAB_COUNT)
	if keep_tab_cursor:
		_cursor = Item.TAB_BAR
	elif _cursor != Item.BACK:
		_cursor = _tab_cursors[_tab]
	_apply_row_visibility()
	_refresh_labels()
	_sync_cursor()


func set_tab(index: int) -> void:
	if index < 0 or index >= TAB_COUNT or index == _tab:
		return
	cycle_tab(index - _tab)
	_tab = index
	if _cursor != Item.BACK and _cursor != Item.TAB_BAR:
		_cursor = _tab_cursors[_tab]
	_apply_row_visibility()
	_refresh_labels()
	_sync_cursor()


func nudge_cursor(delta: int) -> void:
	if delta == 0:
		return
	var choices := _active_items()
	var pos := choices.find(_cursor)
	if pos < 0:
		pos = 0
	_cursor = choices[posmod(pos + (1 if delta > 0 else -1), choices.size())]
	_remember_cursor()
	_sync_cursor()


func set_cursor(index: int) -> void:
	if index == Item.BACK or index == Item.TAB_BAR:
		_cursor = index
	elif index in _tab_items(_tab):
		_cursor = index
		_remember_cursor()
	_sync_cursor()


func activate_current() -> bool:
	if is_back_selected():
		return true
	if _cursor == Item.TAB_BAR:
		return false
	cycle_current(1)
	return false


func refresh() -> void:
	GameState.refresh_apple2_dsk()
	_apply_presentation()
	_refresh_labels()
	_sync_cursor()


func cycle_language(delta: int = 1) -> void:
	var langs := GameState.LANG_IDS
	var i := langs.find(GameState.language)
	if i < 0:
		i = 0
	GameState.language = langs[posmod(i + delta, langs.size())]
	_refresh_labels()
	_sync_cursor()


func cycle_current(delta: int = 1) -> void:
	if _cursor == Item.TAB_BAR:
		cycle_tab(delta)
		return
	match _cursor:
		Item.LANGUAGE:
			cycle_language(delta)
		Item.HANGUL_KEYBOARD:
			HangulInputSettings.cycle_layout(delta)
		Item.GRAPHICS:
			GraphicsSettings.cycle_tileset(delta)
		Item.RESOLUTION:
			DisplaySettings.cycle_window_scale(delta)
		Item.FULLSCREEN:
			DisplaySettings.toggle_fullscreen()
		Item.SFX:
			AudioSfx.set_enabled(not AudioSfx.is_enabled())
		Item.MUSIC:
			_cycle_music(delta)
		Item.BACKGROUND_AUDIO:
			AudioSfx.set_background_music_enabled(
				not AudioSfx.is_background_music_enabled()
			)
		Item.DOS_PATH:
			_open_dos_dialog()
		Item.APPLE2_PROGRAM_PATH:
			_open_program_dialog()
		Item.APPLE2_BRITANNIA_PATH:
			_open_britannia_dialog()
		Item.COMBAT_STYLE:
			GameState.cycle_combat_style()
		Item.GAMEPAD:
			GamepadSettings.cycle_layout(delta)
	_refresh_labels()
	_sync_cursor()


func _cycle_music(delta: int) -> void:
	var on := AudioSfx.music_enabled()
	var pct := AudioSfx.music_volume_percent()
	if not on:
		AudioSfx.music_set_volume_percent(10 if delta > 0 else 100)
		AudioSfx.music_set_enabled(true)
	else:
		var next := pct + delta * 10
		if next < 10:
			AudioSfx.music_set_enabled(false)
		elif next > 100:
			AudioSfx.music_set_enabled(false)
		else:
			AudioSfx.music_set_volume_percent(next)


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

	_tabs = HBoxContainer.new()
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs.add_theme_constant_override("separation", 4)
	_col.add_child(_tabs)
	for i in TAB_COUNT:
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var tab_i := i
		btn.pressed.connect(func() -> void: set_tab(tab_i))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tabs.add_child(btn)
		_tab_buttons.append(btn)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(_list)
	for i in ITEM_COUNT:
		_build_item_row(i)
	_build_back_row()
	_refresh_labels()


func _build_item_row(index: int) -> void:
	var wrap := _make_row_wrap()
	wrap.gui_input.connect(func(event: InputEvent) -> void: _on_row_gui(index, event))
	_list.add_child(wrap)
	var bg := ColorRect.new()
	bg.color = Color.TRANSPARENT
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
	var name_lab := _make_text_label()
	var left := _make_arrow_label("◂")
	left.gui_input.connect(func(event: InputEvent) -> void: _on_arrow_gui(index, -1, event))
	var value_lab := _make_text_label()
	var right := _make_arrow_label("▸")
	right.gui_input.connect(func(event: InputEvent) -> void: _on_arrow_gui(index, 1, event))
	box.add_child(name_lab)
	box.add_child(left)
	box.add_child(value_lab)
	box.add_child(right)
	_row_wraps.append(wrap)
	_row_bgs.append(bg)
	_row_edges.append(edge)
	_row_names.append(name_lab)
	_row_lefts.append(left)
	_row_labs.append(value_lab)
	_row_rights.append(right)


func _build_back_row() -> void:
	_back_wrap = _make_row_wrap()
	_back_wrap.gui_input.connect(_on_back_gui)
	_col.add_child(_back_wrap)
	_back_bg = ColorRect.new()
	_back_bg.color = Color.TRANSPARENT
	_back_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back_wrap.add_child(_back_bg)
	_back_edge = UiTheme.make_selection_edge("", FONT_SIZE)
	_back_wrap.add_child(_back_edge)
	_back_label = _make_text_label()
	_back_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back_wrap.add_child(_back_label)


func _make_row_wrap() -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, ROW_H)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return wrap


func _make_text_label() -> Label:
	var lab := Label.new()
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_override("font", UiTheme.font())
	lab.add_theme_font_size_override("font_size", FONT_SIZE)
	lab.add_theme_color_override("font_color", COL_TEXT)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lab


func _make_arrow_label(text: String) -> Label:
	var lab := _make_text_label()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.custom_minimum_size = Vector2(22, 0)
	lab.add_theme_font_override("font", UiTheme.font_bold())
	lab.add_theme_color_override("font_color", COL_ACCENT)
	lab.mouse_filter = Control.MOUSE_FILTER_STOP
	lab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return lab


func _apply_presentation() -> void:
	if _embedded and _embed_rect.size.x > 8.0 and _embed_rect.size.y > 8.0:
		_backdrop.visible = false
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		anchor_right = 0.0
		anchor_bottom = 0.0
		position = _embed_rect.position
		size = _embed_rect.size
		custom_minimum_size = _embed_rect.size
		_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_panel.custom_minimum_size = _embed_rect.size
		var col_sep := 4
		var list_sep := 1
		_col.add_theme_constant_override("separation", col_sep)
		_list.add_theme_constant_override("separation", list_sep)
		var item_rows := _max_tab_rows()
		var fixed_rows := 3 ## Title + tabs + Back.
		var spacing := float(col_sep * 3 + list_sep * maxi(item_rows - 1, 0))
		var breathing_room := 10.0
		var row_h := clampf(
			(_embed_rect.size.y - spacing - breathing_room)
			/ float(item_rows + fixed_rows),
			16.0,
			34.0
		)
		var font_sz := clampi(int(row_h * 0.5), 11, 18)
		_style_all(font_sz, row_h)
	else:
		_backdrop.visible = true
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		position = Vector2.ZERO
		custom_minimum_size = Vector2.ZERO
		_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_panel.custom_minimum_size = Vector2(PANEL_W, 0)
		_panel.add_theme_stylebox_override("panel", UiTheme.make_panel())
		_col.add_theme_constant_override("separation", 8)
		_list.add_theme_constant_override("separation", 3)
		_style_all(FONT_SIZE, ROW_H)
	_apply_row_visibility()


func _style_all(font_sz: int, row_h: float) -> void:
	_row_font_sz = font_sz
	_title.add_theme_font_size_override("font_size", font_sz + 2)
	_title.custom_minimum_size = Vector2(0, row_h)
	_tabs.custom_minimum_size = Vector2(0, row_h)
	var max_item_rows := _max_tab_rows()
	var list_sep := _list.get_theme_constant("separation")
	_list.custom_minimum_size = Vector2(
		0,
		row_h * float(max_item_rows) + float(list_sep * maxi(max_item_rows - 1, 0))
	)
	for btn in _tab_buttons:
		btn.add_theme_font_override("font", UiTheme.font_bold())
		btn.add_theme_font_size_override("font_size", font_sz)
		btn.custom_minimum_size = Vector2(0, row_h)
	for i in ITEM_COUNT:
		_row_wraps[i].custom_minimum_size = Vector2(0, row_h)
		for lab in [_row_names[i], _row_labs[i], _row_lefts[i], _row_rights[i]]:
			lab.add_theme_font_size_override("font_size", font_sz)
	_back_wrap.custom_minimum_size = Vector2(0, row_h)
	_back_label.add_theme_font_size_override("font_size", font_sz)
	_apply_fixed_columns(font_sz)


func _refresh_labels() -> void:
	_title.text = Locale.t("esc_options_title")
	var tab_keys := [
		"options_tab_language",
		"options_tab_graphics",
		"options_tab_sound",
		"options_tab_game",
		"options_tab_common",
	]
	for i in TAB_COUNT:
		_tab_buttons[i].text = Locale.t(tab_keys[i])
		_apply_tab_style(
			_tab_buttons[i],
			i == _tab,
			i == _tab and _cursor == Item.TAB_BAR
		)
	for i in ITEM_COUNT:
		_row_names[i].text = "%s:" % _item_name_text(i)
		_row_labs[i].text = _item_value_text(i)
	_back_label.text = Locale.t("back")
	_apply_row_visibility()
	_apply_fixed_columns(_row_font_sz)


func _apply_tab_style(button: Button, selected: bool, cursor_on_tab: bool) -> void:
	var normal := _tab_style(selected, false, cursor_on_tab)
	var hover := _tab_style(selected, true, cursor_on_tab)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", _tab_style(true, true, true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var text := Color(1.0, 0.94, 0.62) if selected else COL_TEXT
	button.add_theme_color_override("font_color", text)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _tab_style(selected: bool, hovered: bool, cursor_on_tab: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	if cursor_on_tab:
		box.bg_color = Color(0.28, 0.55, 0.9, 1.0)
		box.border_color = COL_ACCENT
	elif selected:
		box.bg_color = Color(0.18, 0.39, 0.66, 0.95)
		box.border_color = COL_ACCENT
	elif hovered:
		box.bg_color = Color(0.12, 0.24, 0.34, 0.92)
		box.border_color = Color(0.35, 0.55, 0.68, 0.8)
	else:
		box.bg_color = Color(0.025, 0.075, 0.095, 0.9)
	box.border_color = Color.TRANSPARENT
	box.set_border_width_all(0)
	box.anti_aliasing = false
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 2
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	return box


func _item_name_text(index: int) -> String:
	var keys := [
		"menu_language",
		"esc_options_hangul_keyboard",
		"esc_options_graphics",
		"esc_options_resolution",
		"esc_options_fullscreen",
		"esc_options_sfx",
		"esc_options_music",
		"esc_options_background_audio",
		"esc_options_dos_path",
		"esc_options_apple2_program_path",
		"esc_options_apple2_britannia_path",
		"esc_options_combat_style",
		"esc_options_gamepad",
	]
	return Locale.t(keys[index]) if index >= 0 and index < keys.size() else ""


func _item_value_text(index: int) -> String:
	if _path_note.has(index):
		return Locale.t(str(_path_note[index]))
	match index:
		Item.LANGUAGE:
			return Locale.lang_label()
		Item.HANGUL_KEYBOARD:
			return Locale.t("hangul_keyboard_" + HangulInputSettings.layout_id())
		Item.GRAPHICS:
			return _graphics_value_text()
		Item.RESOLUTION:
			var parts: Dictionary = DisplaySettings.resolution_label_parts()
			return Locale.t("esc_options_resolution_windowed", [
				int(parts.get("pct", 80)),
				int(parts.get("width", 1280)),
				int(parts.get("height", 720)),
			])
		Item.FULLSCREEN:
			return _on_off(DisplaySettings.is_fullscreen_active())
		Item.SFX:
			return _on_off(AudioSfx.is_enabled())
		Item.MUSIC:
			return (
				Locale.t("esc_options_music_volume", [AudioSfx.music_volume_percent()])
				if AudioSfx.music_enabled()
				else Locale.t("esc_options_state_off")
			)
		Item.BACKGROUND_AUDIO:
			return _on_off(AudioSfx.is_background_music_enabled())
		Item.DOS_PATH:
			return _committed_path_state(GameState.dos_path_committed(), GameState.u4_data_ok)
		Item.APPLE2_PROGRAM_PATH:
			return _committed_path_state(
				GameState.apple2_program_path_committed(),
				GameState.apple2_program_path_committed()
				and not GameState.apple2_program_path_missing()
			)
		Item.APPLE2_BRITANNIA_PATH:
			return _committed_path_state(
				GameState.apple2_britannia_path_committed(),
				GameState.apple2_britannia_path_committed()
				and not GameState.apple2_britannia_path_missing()
			)
		Item.COMBAT_STYLE:
			return Locale.t("esc_options_combat_" + GameState.get_combat_style())
		Item.GAMEPAD:
			return Locale.t("esc_options_gamepad_" + GamepadSettings.layout_id())
	return ""


func _graphics_value_text() -> String:
	var keys := {
		"new_color": "esc_options_graphics_new_color",
		"apple2_color": "esc_options_graphics_apple2_color",
		"apple2_mono": "esc_options_graphics_apple2_mono",
		"apple2_mono_green": "esc_options_graphics_apple2_mono_green",
	}
	return Locale.t(str(keys.get(
		GraphicsSettings.tileset_id(),
		"esc_options_graphics_new_color"
	)))


func _on_off(on: bool) -> String:
	return Locale.t("esc_options_state_on" if on else "esc_options_state_off")


func _committed_path_state(committed: bool, ready: bool) -> String:
	if ready:
		return Locale.t("esc_options_path_set")
	if committed:
		return Locale.t("esc_options_path_missing")
	return Locale.t("esc_options_path_none")


func _apply_row_visibility() -> void:
	var active := _tab_items(_tab)
	for i in ITEM_COUNT:
		_row_wraps[i].visible = i in active


func _sync_cursor() -> void:
	for i in TAB_COUNT:
		_apply_tab_style(
			_tab_buttons[i],
			i == _tab,
			i == _tab and _cursor == Item.TAB_BAR
		)
	for i in ITEM_COUNT:
		var on := i == _cursor and i in _tab_items(_tab)
		_row_bgs[i].color = COL_CURSOR if on else Color.TRANSPARENT
		UiTheme.set_selection_edge_active(_row_edges[i], on, COL_CURSOR_EDGE)
	var back_on := _cursor == Item.BACK
	_back_bg.color = COL_CURSOR if back_on else Color.TRANSPARENT
	UiTheme.set_selection_edge_active(_back_edge, back_on, COL_CURSOR_EDGE)


func _apply_fixed_columns(font_sz: int) -> void:
	var name_w := 0.0
	var value_w := 0.0
	var font := UiTheme.font()
	for i in ITEM_COUNT:
		for sample in Locale.variants(_item_name_key(i)):
			name_w = maxf(name_w, font.get_string_size("%s:" % sample, 0, -1, font_sz).x)
	for sample in [
		"Apple II Mono White",
		"Classic English",
		"100% (1280×720)",
	]:
		value_w = maxf(value_w, font.get_string_size(sample, 0, -1, font_sz).x)
	name_w = ceilf(name_w) + 4.0
	value_w = ceilf(value_w) + 8.0
	for i in ITEM_COUNT:
		_row_names[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_row_names[i].custom_minimum_size = Vector2(name_w, 0)
		_row_labs[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_row_labs[i].custom_minimum_size = Vector2(value_w, 0)
		_row_labs[i].clip_text = true


func _item_name_key(index: int) -> String:
	var keys := [
		"menu_language", "esc_options_hangul_keyboard", "esc_options_graphics",
		"esc_options_resolution", "esc_options_fullscreen", "esc_options_sfx",
		"esc_options_music", "esc_options_background_audio", "esc_options_dos_path",
		"esc_options_apple2_program_path", "esc_options_apple2_britannia_path",
		"esc_options_combat_style", "esc_options_gamepad",
	]
	return keys[index]


func _active_items() -> Array[int]:
	var out: Array[int] = [Item.TAB_BAR]
	out.append_array(_tab_items(_tab))
	out.append(Item.BACK)
	return out


func _tab_items(tab: int) -> Array[int]:
	match tab:
		Tab.LANGUAGE:
			return [Item.LANGUAGE, Item.HANGUL_KEYBOARD]
		Tab.GRAPHICS:
			return [Item.GRAPHICS, Item.RESOLUTION, Item.FULLSCREEN]
		Tab.SOUND:
			return [Item.SFX, Item.MUSIC, Item.BACKGROUND_AUDIO]
		Tab.GAME:
			return [Item.COMBAT_STYLE, Item.GAMEPAD]
		_:
			return [
				Item.DOS_PATH,
				Item.APPLE2_PROGRAM_PATH,
				Item.APPLE2_BRITANNIA_PATH,
			]


func _max_tab_rows() -> int:
	var rows := 1
	for tab in TAB_COUNT:
		rows = maxi(rows, _tab_items(tab).size())
	return rows


func _set_tab_for_item(item: int) -> void:
	for tab in TAB_COUNT:
		if item in _tab_items(tab):
			_tab = tab
			return
	_tab = Tab.LANGUAGE


func _remember_cursor() -> void:
	if _cursor != Item.BACK and _cursor in _tab_items(_tab):
		_tab_cursors[_tab] = _cursor


func _on_row_gui(index: int, event: InputEvent) -> void:
	if _is_left_click(event):
		set_cursor(index)
		accept_event()


func _on_arrow_gui(index: int, delta: int, event: InputEvent) -> void:
	if _is_left_click(event):
		set_cursor(index)
		cycle_current(delta)
		accept_event()


func _on_back_gui(event: InputEvent) -> void:
	if _is_left_click(event):
		set_cursor(Item.BACK)
		back_requested.emit()
		accept_event()


func _is_left_click(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mb := event as InputEventMouseButton
	return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not mb.double_click


func _use_native_file_dialog() -> bool:
	return OS.get_name() == "macOS" and (OS.is_sandboxed() or not OS.has_feature("editor"))


func _open_dos_dialog() -> void:
	if _dos_dialog == null:
		_dos_dialog = FileDialog.new()
		_dos_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_setup_dialog(_dos_dialog, "esc_options_dos_path")
		_dos_dialog.dir_selected.connect(_on_dos_selected)
		_dos_dialog.canceled.connect(_on_file_canceled)
	_picking_file = true
	_dos_dialog.popup_centered_ratio(0.65)


func _open_program_dialog() -> void:
	if _program_dialog == null:
		_program_dialog = FileDialog.new()
		_program_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_setup_dialog(_program_dialog, "esc_options_apple2_program_path")
		_program_dialog.add_filter("*.dsk", Locale.t("apple2_disk_filter"))
		_program_dialog.file_selected.connect(_on_program_selected)
		_program_dialog.canceled.connect(_on_file_canceled)
	_picking_file = true
	_program_dialog.popup_centered_ratio(0.65)


func _open_britannia_dialog() -> void:
	if _britannia_dialog == null:
		_britannia_dialog = FileDialog.new()
		_britannia_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_setup_dialog(_britannia_dialog, "esc_options_apple2_britannia_path")
		_britannia_dialog.add_filter("*.dsk", Locale.t("apple2_disk_filter"))
		_britannia_dialog.file_selected.connect(_on_britannia_selected)
		_britannia_dialog.canceled.connect(_on_file_canceled)
	_picking_file = true
	_britannia_dialog.popup_centered_ratio(0.65)


func _setup_dialog(dialog: FileDialog, title_key: String) -> void:
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = _use_native_file_dialog()
	dialog.title = Locale.t(title_key)
	dialog.ok_button_text = Locale.t("boot_path_select")
	dialog.cancel_button_text = Locale.t("boot_path_cancel")
	dialog.min_size = Vector2i(760, 480)
	dialog.exclusive = true
	dialog.unresizable = false
	add_child(dialog)


func _on_dos_selected(path: String) -> void:
	_picking_file = false
	GameState.try_set_u4_data_path(path)
	refresh()


func _on_program_selected(path: String) -> void:
	_picking_file = false
	if GameState.try_set_apple2_dsk_path(path):
		_path_note.erase(Item.APPLE2_PROGRAM_PATH)
	else:
		_path_note[Item.APPLE2_PROGRAM_PATH] = "esc_options_disk_invalid"
	refresh()


func _on_britannia_selected(path: String) -> void:
	_picking_file = false
	if GameState.set_apple2_britannia_dsk_path(path):
		_path_note.erase(Item.APPLE2_BRITANNIA_PATH)
	else:
		_path_note[Item.APPLE2_BRITANNIA_PATH] = "esc_options_disk_invalid"
	refresh()


func _on_file_canceled() -> void:
	_picking_file = false
