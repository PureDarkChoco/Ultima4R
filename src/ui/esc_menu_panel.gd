class_name EscMenuPanel
extends Control

## In-game Esc pause menu — ↑↓ + Enter; Esc closes (handled by world).

enum Item {
	SAVE = 0,
	LOAD = 1,
	RETURN_MENU = 2,
	OPTION = 3,
	QUIT = 4,
}

const ITEM_COUNT := 5
const COL_TEXT := Color(0.91, 0.9, 0.82, 1)
const COL_DIM := Color(0.55, 0.58, 0.55, 1)
const COL_ACCENT := Color(0.95, 0.85, 0.45, 1)
const COL_CURSOR := Color(0.22, 0.42, 0.82, 0.55)
const COL_CURSOR_EDGE := Color(0.55, 0.78, 1.0, 0.95)
const FONT_SIZE := 16
const ROW_H := 30
const PANEL_W := 320.0

const ITEM_KEYS := [
	"esc_menu_save",
	"esc_menu_load",
	"esc_menu_return",
	"esc_menu_option",
	"esc_menu_quit",
]

var _backdrop: ColorRect
var _panel: PanelContainer
var _title: Label
var _status: Label
var _hint: Label
var _row_labs: Array[Label] = []
var _row_bgs: Array[ColorRect] = []
var _row_edges: Array[ColorRect] = []
var _cursor := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false


func is_open() -> bool:
	return visible


func cursor() -> int:
	return _cursor


func open_panel(default_cursor: int = 0) -> void:
	_cursor = clampi(default_cursor, 0, ITEM_COUNT - 1)
	_status.text = ""
	_refresh_labels()
	_sync_cursor()
	visible = true
	move_to_front()


func close_panel() -> void:
	visible = false
	_status.text = ""


func set_status(text: String) -> void:
	_status.text = text


func nudge_cursor(delta: int) -> void:
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


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.55)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	_panel.add_theme_stylebox_override("panel", UiTheme.make_panel())
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_panel)

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

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(list)

	_row_labs.clear()
	_row_bgs.clear()
	_row_edges.clear()
	for i in ITEM_COUNT:
		var wrap := Control.new()
		wrap.custom_minimum_size = Vector2(0, ROW_H)
		wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list.add_child(wrap)

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

		_row_labs.append(lab)
		_row_bgs.append(bg)
		_row_edges.append(edge)

	_status = Label.new()
	_status.add_theme_font_override("font", UiTheme.font())
	_status.add_theme_font_size_override("font_size", FONT_SIZE - 2)
	_status.add_theme_color_override("font_color", COL_ACCENT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)

	_hint = Label.new()
	_hint.add_theme_font_override("font", UiTheme.font())
	_hint.add_theme_font_size_override("font_size", FONT_SIZE - 2)
	_hint.add_theme_color_override("font_color", COL_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hint)

	_refresh_labels()


func _refresh_labels() -> void:
	_title.text = Locale.t("esc_menu_title")
	_hint.text = Locale.t("esc_menu_hint")
	for i in ITEM_COUNT:
		_row_labs[i].text = Locale.t(ITEM_KEYS[i])
		## Option is listed but inactive — dim it.
		var col := COL_DIM if i == Item.OPTION else COL_TEXT
		_row_labs[i].add_theme_color_override("font_color", col)


func _sync_cursor() -> void:
	for i in ITEM_COUNT:
		var on := i == _cursor
		_row_bgs[i].color = COL_CURSOR if on else Color(0, 0, 0, 0)
		_row_edges[i].color = COL_CURSOR_EDGE if on else Color(0, 0, 0, 0)
