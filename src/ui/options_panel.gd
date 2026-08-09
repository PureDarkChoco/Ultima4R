class_name OptionsPanel
extends Control

## In-game Esc → Options submenu.
## Also embedded in the title map frame (main menu).
## Items: language, Hangul keyboard, window resolution, fullscreen.
## Left/right (or Enter) cycles the selected item; Esc closes.

enum Item {
	LANGUAGE = 0,
	HANGUL_KEYBOARD = 1,
	RESOLUTION = 2,
	FULLSCREEN = 3,
}

const ITEM_COUNT := 4
const COL_TEXT := Color(0.91, 0.9, 0.82, 1)
const COL_ACCENT := Color(0.95, 0.85, 0.45, 1)
const COL_CURSOR := Color(0.22, 0.42, 0.82, 0.55)
const COL_CURSOR_EDGE := Color(0.55, 0.78, 1.0, 0.95)
const FONT_SIZE := 16
const ROW_H := 30
const PANEL_W := 400.0

var _backdrop: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _title: Label
var _list: VBoxContainer
var _row_labs: Array[Label] = []
var _row_bgs: Array[ColorRect] = []
var _row_edges: Array[ColorRect] = []
var _row_wraps: Array[Control] = []
var _cursor := 0
var _embedded := false
var _embed_rect := Rect2()


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


func is_embedded() -> bool:
	return _embedded


func cursor() -> int:
	return _cursor


func open_panel(default_cursor: int = 0) -> void:
	_embedded = false
	_embed_rect = Rect2()
	_cursor = clampi(default_cursor, 0, ITEM_COUNT - 1)
	_apply_presentation()
	_refresh_labels()
	_sync_cursor()
	visible = true
	move_to_front()


## Title map frame — no modal backdrop; same rows as the Esc options panel.
func open_embedded(rect: Rect2, default_cursor: int = 0) -> void:
	_embedded = true
	_embed_rect = rect
	_cursor = clampi(default_cursor, 0, ITEM_COUNT - 1)
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
	if ITEM_COUNT <= 1:
		return
	_cursor = posmod(_cursor + delta, ITEM_COUNT)
	_sync_cursor()


func set_cursor(index: int) -> void:
	if index < 0 or index >= ITEM_COUNT:
		return
	_cursor = index
	_sync_cursor()


func refresh() -> void:
	_refresh_labels()
	_sync_cursor()


func cycle_language(delta: int = 1) -> void:
	## Session + settings.cfg; save slots store language on next Save.
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
	match _cursor:
		Item.LANGUAGE:
			cycle_language(delta)
		Item.HANGUL_KEYBOARD:
			HangulInputSettings.cycle_layout(delta)
			_refresh_labels()
			_sync_cursor()
		Item.RESOLUTION:
			cycle_resolution(delta)
		Item.FULLSCREEN:
			cycle_fullscreen(delta)
		_:
			pass


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

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)

	_title = Label.new()
	_title.add_theme_font_override("font", UiTheme.font_bold())
	_title.add_theme_font_size_override("font_size", FONT_SIZE + 2)
	_title.add_theme_color_override("font_color", COL_ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_list)

	_row_labs.clear()
	_row_bgs.clear()
	_row_edges.clear()
	_row_wraps.clear()
	for i in ITEM_COUNT:
		var wrap := Control.new()
		wrap.custom_minimum_size = Vector2(0, ROW_H)
		wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_list.add_child(wrap)

		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(bg)

		var edge := ColorRect.new()
		edge.color = Color(0, 0, 0, 0)
		edge.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		edge.offset_right = 3
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(edge)

		var lab := Label.new()
		lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lab.offset_left = 12
		lab.offset_right = -8
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.add_theme_font_override("font", UiTheme.font())
		lab.add_theme_font_size_override("font_size", FONT_SIZE)
		lab.add_theme_color_override("font_color", COL_TEXT)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(lab)

		_row_wraps.append(wrap)
		_row_labs.append(lab)
		_row_bgs.append(bg)
		_row_edges.append(edge)

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
		var row_h := clampf(_embed_rect.size.y / 7.0, 24.0, 40.0)
		var font_sz := clampi(int(row_h * 0.55), 14, 24)
		_title.add_theme_font_size_override("font_size", font_sz + 2)
		for i in ITEM_COUNT:
			_row_wraps[i].custom_minimum_size = Vector2(0, row_h)
			_row_labs[i].add_theme_font_size_override("font_size", font_sz)
			_row_labs[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_row_labs[i].offset_left = 8
			_row_labs[i].offset_right = -8
	else:
		_backdrop.visible = true
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		position = Vector2.ZERO
		custom_minimum_size = Vector2.ZERO
		_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_panel.custom_minimum_size = Vector2(PANEL_W, 0)
		_panel.add_theme_stylebox_override("panel", UiTheme.make_panel())
		_title.visible = true
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title.add_theme_font_size_override("font_size", FONT_SIZE + 2)
		for i in ITEM_COUNT:
			_row_wraps[i].custom_minimum_size = Vector2(0, ROW_H)
			_row_labs[i].add_theme_font_size_override("font_size", FONT_SIZE)
			_row_labs[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_row_labs[i].offset_left = 12
			_row_labs[i].offset_right = -8


func _refresh_labels() -> void:
	_title.text = Locale.t("esc_options_title")
	for i in ITEM_COUNT:
		if i == Item.LANGUAGE:
			_row_labs[i].text = "%s: ◂ %s ▸" % [
				Locale.t("menu_language"),
				Locale.lang_label(),
			]
		elif i == Item.HANGUL_KEYBOARD:
			_row_labs[i].text = "%s: ◂ %s ▸" % [
				Locale.t("esc_options_hangul_keyboard"),
				Locale.t("hangul_keyboard_" + HangulInputSettings.layout_id()),
			]
		elif i == Item.RESOLUTION:
			_row_labs[i].text = _resolution_row_text()
		elif i == Item.FULLSCREEN:
			_row_labs[i].text = _fullscreen_row_text()
		_row_labs[i].add_theme_color_override("font_color", COL_TEXT)


func _resolution_row_text() -> String:
	var parts: Dictionary = DisplaySettings.resolution_label_parts()
	var pct := int(parts.get("pct", 80))
	var w := int(parts.get("width", 1280))
	var h := int(parts.get("height", 720))
	return "%s: ◂ %s ▸" % [
		Locale.t("esc_options_resolution"),
		Locale.t("esc_options_resolution_windowed", [pct, w, h]),
	]


func _fullscreen_row_text() -> String:
	var state := (
		Locale.t("esc_options_fullscreen_state_on")
		if DisplaySettings.is_fullscreen_active()
		else Locale.t("esc_options_fullscreen_state_off")
	)
	return "%s: ◂ %s ▸" % [Locale.t("esc_options_fullscreen"), state]


func _sync_cursor() -> void:
	for i in ITEM_COUNT:
		var on := i == _cursor
		_row_bgs[i].color = COL_CURSOR if on else Color(0, 0, 0, 0)
		_row_edges[i].color = COL_CURSOR_EDGE if on else Color(0, 0, 0, 0)
