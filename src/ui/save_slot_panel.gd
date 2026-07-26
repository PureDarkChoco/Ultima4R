class_name SaveSlotPanel
extends Control

## Modal 4-slot save/load picker — same layout for both modes.
## Row:  N. [face] Lv.N Name          [companions…]
##       moves · saved_at

enum Mode { SAVE = 0, LOAD = 1 }

const SLOT_COUNT := 4
const COL_TEXT := Color(0.91, 0.9, 0.82, 1)
const COL_DIM := Color(0.55, 0.58, 0.55, 1)
const COL_ACCENT := Color(0.95, 0.85, 0.45, 1)
const COL_CURSOR := Color(0.22, 0.42, 0.82, 0.55)
const COL_CURSOR_EDGE := Color(0.55, 0.78, 1.0, 0.95)
const FONT_SIZE := 15
const FONT_SIZE_SUB := 13
const FACE_SZ := 36.0
const COMP_SZ := 28.0
const ROW_H := 64.0
const PANEL_W := 520.0


var _backdrop: ColorRect
var _panel: PanelContainer
var _title: Label
var _rows: Array[Control] = []
var _row_bgs: Array[ColorRect] = []
var _row_edges: Array[ColorRect] = []
var _num_labs: Array[Label] = []
var _face_rects: Array[TextureRect] = []
var _name_labs: Array[Label] = []
var _comp_rows: Array[HBoxContainer] = []
var _sub_labs: Array[Label] = []
var _empty_labs: Array[Label] = []
var _content_cols: Array[Control] = []
var _cursor := 0
var _hint: Label
var _mode: int = Mode.SAVE
var _class_tiles: Array[Texture2D] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cache_class_tiles()
	_build()
	visible = false


func _cache_class_tiles() -> void:
	## Same shapes.png class tiles as PartyRoster / Ztats.
	_class_tiles.clear()
	for i in 8:
		_class_tiles.append(PartyRoster._ztats_class_tile(i))


func is_open() -> bool:
	return visible


func mode() -> int:
	return _mode


func open_panel(p_mode: int = Mode.SAVE, default_cursor: int = 0) -> void:
	_mode = p_mode
	_cursor = clampi(default_cursor, 0, SLOT_COUNT - 1)
	_refresh_rows()
	_sync_cursor()
	visible = true
	move_to_front()


func close_panel() -> void:
	visible = false


func cursor() -> int:
	return _cursor


func nudge_cursor(delta: int) -> void:
	_cursor = posmod(_cursor + delta, SLOT_COUNT)
	_sync_cursor()


func set_cursor(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return
	_cursor = slot_index
	_sync_cursor()


func refresh() -> void:
	_refresh_rows()
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
	_title.text = Locale.t("save_title")
	_title.add_theme_font_override("font", UiTheme.font_bold())
	_title.add_theme_font_size_override("font_size", FONT_SIZE + 2)
	_title.add_theme_color_override("font_color", COL_ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(list)

	_rows.clear()
	_row_bgs.clear()
	_row_edges.clear()
	_num_labs.clear()
	_face_rects.clear()
	_name_labs.clear()
	_comp_rows.clear()
	_sub_labs.clear()
	_empty_labs.clear()
	_content_cols.clear()

	for i in SLOT_COUNT:
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

		var pad := MarginContainer.new()
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pad.add_theme_constant_override("margin_left", 10)
		pad.add_theme_constant_override("margin_right", 8)
		pad.add_theme_constant_override("margin_top", 4)
		pad.add_theme_constant_override("margin_bottom", 4)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(pad)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(row)

		var num := Label.new()
		num.custom_minimum_size = Vector2(22, 0)
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.add_theme_font_override("font", UiTheme.font_bold())
		num.add_theme_font_size_override("font_size", FONT_SIZE)
		num.add_theme_color_override("font_color", COL_ACCENT)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		num.text = "%d." % (i + 1)
		row.add_child(num)

		var empty := Label.new()
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_font_override("font", UiTheme.font())
		empty.add_theme_font_size_override("font_size", FONT_SIZE)
		empty.add_theme_color_override("font_color", COL_DIM)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty.visible = false
		row.add_child(empty)

		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 2)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(content)

		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(top)

		var face := TextureRect.new()
		face.custom_minimum_size = Vector2(FACE_SZ, FACE_SZ)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(face)

		var name_lab := Label.new()
		name_lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_lab.add_theme_font_override("font", UiTheme.font())
		name_lab.add_theme_font_size_override("font_size", FONT_SIZE)
		name_lab.add_theme_color_override("font_color", COL_TEXT)
		name_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(name_lab)

		## Right zone: companion faces, left-aligned within the remaining space.
		var comps_wrap := Control.new()
		comps_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		comps_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(comps_wrap)

		var comps := HBoxContainer.new()
		comps.add_theme_constant_override("separation", 3)
		comps.alignment = BoxContainer.ALIGNMENT_BEGIN
		comps.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		comps.mouse_filter = Control.MOUSE_FILTER_IGNORE
		comps_wrap.add_child(comps)

		var sub := Label.new()
		sub.add_theme_font_override("font", UiTheme.font())
		sub.add_theme_font_size_override("font_size", FONT_SIZE_SUB)
		sub.add_theme_color_override("font_color", COL_DIM)
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(sub)

		_rows.append(wrap)
		_row_bgs.append(bg)
		_row_edges.append(edge)
		_num_labs.append(num)
		_face_rects.append(face)
		_name_labs.append(name_lab)
		_comp_rows.append(comps)
		_sub_labs.append(sub)
		_empty_labs.append(empty)
		_content_cols.append(content)

	_hint = Label.new()
	_hint.text = Locale.t("save_hint")
	_hint.add_theme_font_override("font", UiTheme.font())
	_hint.add_theme_font_size_override("font_size", FONT_SIZE - 2)
	_hint.add_theme_color_override("font_color", COL_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hint)


func _refresh_rows() -> void:
	## Same card layout for save and load — only title/hint differ.
	var title_key := "load_title" if _mode == Mode.LOAD else "save_title"
	var hint_key := "load_hint" if _mode == Mode.LOAD else "save_hint"
	_title.text = Locale.t(title_key)
	_hint.text = Locale.t(hint_key)
	for i in SLOT_COUNT:
		var slot_n := i + 1
		var meta := SaveGame.read_meta(slot_n)
		_fill_slot_row(i, slot_n, meta)


func _fill_slot_row(index: int, slot_n: int, meta: Dictionary) -> void:
	_num_labs[index].text = "%d." % slot_n
	var empty := meta.is_empty()
	_empty_labs[index].visible = empty
	_content_cols[index].visible = not empty
	if empty:
		_empty_labs[index].text = Locale.t("save_slot_empty_short")
		_clear_companions(index)
		return

	var pname := str(meta.get("player_name", "?"))
	if pname.is_empty():
		pname = "Avatar"
	var level := maxi(1, int(meta.get("level", 1)))
	_name_labs[index].text = "Lv.%d %s" % [level, pname]
	_name_labs[index].add_theme_color_override("font_color", COL_TEXT)

	var avatar_klass := clampi(int(meta.get("class", 0)), 0, 7)
	_face_rects[index].texture = _class_tile(avatar_klass)

	_fill_companions(index, meta)

	var moves := int(meta.get("moves", 0))
	var when := str(meta.get("saved_at", ""))
	if when.is_empty():
		_sub_labs[index].text = Locale.t("save_slot_moves", [str(moves)])
	else:
		_sub_labs[index].text = Locale.t("save_slot_moves_when", [str(moves), when])


func _fill_companions(index: int, meta: Dictionary) -> void:
	_clear_companions(index)
	var comps: HBoxContainer = _comp_rows[index]
	var order: Variant = meta.get("party_order", [])
	if typeof(order) != TYPE_ARRAY:
		return
	var avatar_klass := int(meta.get("class", -1))
	for raw in order as Array:
		var mid := int(raw)
		if mid < 0 or mid > 7:
			continue
		if mid == avatar_klass:
			continue ## Avatar class tile is already on the left.
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(COMP_SZ, COMP_SZ)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = _class_tile(mid)
		comps.add_child(icon)


func _clear_companions(index: int) -> void:
	var comps: HBoxContainer = _comp_rows[index]
	while comps.get_child_count() > 0:
		var c := comps.get_child(0)
		comps.remove_child(c)
		c.free()


func _class_tile(klass: int) -> Texture2D:
	if klass < 0 or klass >= _class_tiles.size():
		return null
	return _class_tiles[klass]


func _sync_cursor() -> void:
	for i in SLOT_COUNT:
		var on := i == _cursor
		_row_bgs[i].color = COL_CURSOR if on else Color(0, 0, 0, 0)
		_row_edges[i].color = COL_CURSOR_EDGE if on else Color(0, 0, 0, 0)
