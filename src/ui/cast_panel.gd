class_name CastPanel
extends Control

## Cast (C) — pick a mixed spell from a list, or A–Z from the keyboard.

const COL_TEXT := Color(0.91, 0.9, 0.82, 1)
const COL_ACCENT := Color(0.95, 0.85, 0.45, 1)
const COL_DIM := Color(0.45, 0.45, 0.48, 1)
const COL_CURSOR := Color(0.22, 0.42, 0.82, 0.55)
const COL_CURSOR_EDGE := Color(0.38, 0.58, 0.82, 0.72)
const COL_MIX_INDEX := Color(1.0, 0.82, 0.28, 1)
const COL_MP_SHORT := Color(0.92, 0.28, 0.28, 1)

const FONT_SIZE := 13
const INV_ROW_H := 25
const INV_LIST_SEP := 3
const INV_PAD_H := 10
const INV_PAD_V := 6
const PAD_TOP := 14
const INV_MANA_W := 36
const INV_QTY_W := 28
const INV_QTY_TRAIL := 8
const INV_ICON := 20


var _root: VBoxContainer
var _title: Label
var _header_name: Label
var _header_mana: Label
var _header_qty: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _spell_ids: Array[int] = []
var _usable: Array[bool] = []
var _row_wraps: Array[Control] = []
var _cursor := 0
var _scroll_gen := 0
var _show_all := false
var _last_spell_id := -1
var _caster_mp := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", 4)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var pad_top := Control.new()
	pad_top.custom_minimum_size = Vector2(0, PAD_TOP)
	pad_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(pad_top)

	var title_wrap := MarginContainer.new()
	title_wrap.add_theme_constant_override("margin_left", INV_PAD_H)
	title_wrap.add_theme_constant_override("margin_right", INV_PAD_H)
	title_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(title_wrap)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", FONT_SIZE + 1)
	_title.add_theme_color_override("font_color", COL_ACCENT)
	UiTheme.apply_font(_title)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_wrap.add_child(_title)

	var header_wrap := MarginContainer.new()
	header_wrap.add_theme_constant_override("margin_left", INV_PAD_H)
	header_wrap.add_theme_constant_override("margin_right", INV_PAD_H)
	header_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(header_wrap)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_wrap.add_child(header)

	var header_icon := Control.new()
	header_icon.custom_minimum_size = Vector2(INV_ICON, 1)
	header_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(header_icon)

	_header_name = _make_header_label(true)
	header.add_child(_header_name)
	_header_mana = _make_header_label(false, INV_MANA_W)
	header.add_child(_header_mana)
	_header_qty = _make_header_label(false, INV_QTY_W)
	header.add_child(_header_qty)
	var header_trail := Control.new()
	header_trail.custom_minimum_size = Vector2(INV_QTY_TRAIL, 1)
	header_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(header_trail)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_scroll)

	var list_margin := MarginContainer.new()
	list_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_margin.add_theme_constant_override("margin_left", INV_PAD_H)
	list_margin.add_theme_constant_override("margin_right", INV_PAD_H)
	list_margin.add_theme_constant_override("margin_bottom", INV_PAD_V)
	list_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(list_margin)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", INV_LIST_SEP)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_margin.add_child(_list)


func open_list(
	show_all: bool = false, focus_spell_id: int = -1, caster_klass: int = -1
) -> void:
	_scroll_gen += 1
	_show_all = show_all
	_caster_mp = GameState.mp_of_class(caster_klass) if caster_klass >= 0 else -1
	_title.text = Locale.t("cast_title")
	_refresh_header()
	_rebuild_list()
	var want := focus_spell_id if focus_spell_id >= 0 else _last_spell_id
	_cursor = _first_usable_index()
	if want >= 0 and GameState.mixture_qty(want) > 0:
		var idx := index_of_spell(want)
		if idx >= 0:
			_cursor = idx
	_sync_cursor()
	_ensure_cursor_visible()
	var gen := _scroll_gen
	call_deferred("_ensure_cursor_visible_gen", gen)
	visible = true


func close_panel() -> void:
	_scroll_gen += 1
	visible = false
	_spell_ids.clear()
	_usable.clear()
	_row_wraps.clear()
	_clear_list()
	if _scroll != null:
		_scroll.scroll_vertical = 0


func is_empty() -> bool:
	return _spell_ids.is_empty()


func cursor_spell_id() -> int:
	if _cursor < 0 or _cursor >= _spell_ids.size():
		return -1
	if _cursor >= _usable.size() or not _usable[_cursor]:
		return -1
	return int(_spell_ids[_cursor])


func can_select_spell(spell_id: int) -> bool:
	## Qty 0 rows stay visible when showing all, but cannot be chosen (Ready/Wear).
	return GameState.mixture_qty(spell_id) > 0


func remember_spell(spell_id: int) -> void:
	if spell_id >= 0 and spell_id < Spells.COUNT:
		_last_spell_id = spell_id


func _first_usable_index() -> int:
	for i in _usable.size():
		if _usable[i]:
			return i
	return 0


func index_of_spell(spell_id: int) -> int:
	return _spell_ids.find(spell_id)


func set_cursor(idx: int) -> void:
	if _spell_ids.is_empty():
		return
	_cursor = clampi(idx, 0, _spell_ids.size() - 1)
	_sync_cursor()
	_ensure_cursor_visible()


func nudge_cursor(step: int) -> void:
	## Skip unmixed rows; no wrap (Ready/Wear).
	if _spell_ids.is_empty() or step == 0:
		return
	var i := _cursor
	var n := _spell_ids.size()
	while true:
		i += step
		if i < 0 or i >= n:
			return
		if i < _usable.size() and _usable[i]:
			_cursor = i
			_sync_cursor()
			_ensure_cursor_visible()
			return


func _rebuild_list() -> void:
	_clear_list()
	_spell_ids.clear()
	_usable.clear()
	_row_wraps.clear()
	var ko := GameState.language == "ko"
	for sid in Spells.COUNT:
		var qty := GameState.mixture_qty(sid)
		if not _show_all and qty <= 0:
			continue
		_add_spell_row(sid, Locale.spell_name(sid), str(mini(qty, 99)), qty > 0, ko)


func _make_header_label(expand: bool, width: float = 0.0) -> Label:
	var lab := Label.new()
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_SHRINK_CENTER
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if expand else HORIZONTAL_ALIGNMENT_RIGHT
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if width > 0.0:
		lab.custom_minimum_size = Vector2(width, 0)
	lab.add_theme_font_size_override("font_size", FONT_SIZE - 1)
	lab.add_theme_color_override("font_color", COL_ACCENT)
	UiTheme.apply_font(lab)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lab


func _refresh_header() -> void:
	if _header_name:
		_header_name.text = Locale.t("ztats_col_name")
	if _header_mana:
		_header_mana.text = Locale.t("ztats_col_mana")
	if _header_qty:
		_header_qty.text = Locale.t("ztats_col_qty")


func _add_spell_row(
	spell_id: int, name: String, qty_text: String, mixed: bool, ko: bool
) -> void:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, INV_ROW_H)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.clip_contents = true

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_meta("cast_bg", true)
	wrap.add_child(bg)

	var edge := UiTheme.make_selection_edge("cast_edge")
	wrap.add_child(edge)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(row)

	var icon_pad := Control.new()
	icon_pad.custom_minimum_size = Vector2(INV_ICON, 1)
	icon_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_pad)

	var body_col := COL_TEXT if mixed else COL_DIM
	var index_col := COL_MIX_INDEX if mixed else COL_DIM
	if ko:
		_add_index(row, Spells.letter(spell_id), index_col)
		_add_name(row, name, body_col)
	elif not name.is_empty():
		_add_name_colored_initial(row, name, index_col, body_col)
	else:
		_add_name(row, name, body_col)
	var cost := Spells.mp_cost(spell_id)
	var mana_col := body_col
	if mixed and _caster_mp >= 0 and _caster_mp < cost:
		mana_col = COL_MP_SHORT
	_add_num(row, str(cost), INV_MANA_W, mana_col)
	_add_qty(row, qty_text, body_col)

	_list.add_child(wrap)
	_spell_ids.append(spell_id)
	_usable.append(mixed)
	_row_wraps.append(wrap)


func _add_index(row: HBoxContainer, letter: String, col: Color) -> void:
	var lab := Label.new()
	lab.text = "%s." % letter
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_index_style(lab, col)
	row.add_child(lab)


func _add_name(row: HBoxContainer, name: String, col: Color) -> void:
	var lab := Label.new()
	lab.text = name
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", FONT_SIZE)
	lab.add_theme_color_override("font_color", col)
	lab.clip_text = true
	UiTheme.apply_font(lab)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lab)


func _add_name_colored_initial(
	row: HBoxContainer, name: String, index_col: Color, body_col: Color
) -> void:
	var host := HBoxContainer.new()
	host.add_theme_constant_override("separation", 0)
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var initial := Label.new()
	initial.text = name.substr(0, 1)
	initial.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_index_style(initial, index_col)
	host.add_child(initial)

	var rest := name.substr(1)
	if not rest.is_empty():
		var body := Label.new()
		body.text = rest
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		body.clip_text = true
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var settings := LabelSettings.new()
		var f: Font = UiTheme.font()
		if f:
			settings.font = f
		settings.font_size = FONT_SIZE
		settings.font_color = body_col
		body.label_settings = settings
		host.add_child(body)
	row.add_child(host)


func _apply_index_style(lab: Label, col: Color) -> void:
	var settings := LabelSettings.new()
	var f: Font = UiTheme.font()
	if f:
		settings.font = f
	settings.font_size = FONT_SIZE
	settings.font_color = col
	lab.label_settings = settings


func _add_num(row: HBoxContainer, text: String, width: float, col: Color) -> void:
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lab.custom_minimum_size = Vector2(width, 0)
	lab.add_theme_font_size_override("font_size", FONT_SIZE)
	lab.add_theme_color_override("font_color", col)
	UiTheme.apply_font(lab)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lab)


func _add_qty(row: HBoxContainer, qty_text: String, col: Color) -> void:
	_add_num(row, qty_text, INV_QTY_W, col)

	var trail := Control.new()
	trail.custom_minimum_size = Vector2(INV_QTY_TRAIL, 1)
	trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(trail)


func _sync_cursor() -> void:
	for i in _row_wraps.size():
		var wrap := _row_wraps[i]
		var on := i == _cursor and i < _usable.size() and _usable[i]
		for c in wrap.get_children():
			if c.has_meta("cast_bg"):
				(c as ColorRect).color = COL_CURSOR if on else Color(0, 0, 0, 0)
			elif c.has_meta("cast_edge"):
				UiTheme.set_selection_edge_active(c, on, COL_CURSOR_EDGE)


func _ensure_cursor_visible() -> void:
	if _cursor < 0 or _cursor >= _row_wraps.size() or _scroll == null:
		return
	var stride := INV_ROW_H + INV_LIST_SEP
	var view_h := int(_scroll.size.y)
	if view_h <= 0:
		return
	var vis := maxi(1, (view_h + INV_LIST_SEP) / stride)
	var total := _row_wraps.size()
	var next := 0
	if total > vis:
		var center := int(vis / 2)
		next = clampi(_cursor - center, 0, total - vis) * stride
	_scroll.scroll_vertical = clampi(next, 0, maxi(0, (total - vis) * stride))


func _ensure_cursor_visible_gen(gen: int) -> void:
	if gen != _scroll_gen:
		return
	_ensure_cursor_visible()


func _clear_list() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
