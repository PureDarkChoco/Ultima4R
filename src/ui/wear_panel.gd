class_name WearPanel
extends Control

## Wear (W) armor picker — current equip on top, owned armor below.

const _ArmorIcons := preload("res://src/core/armor_icons.gd")

const COL_TEXT := Color(0.91, 0.9, 0.82, 1)
const COL_ACCENT := Color(0.95, 0.85, 0.45, 1)
const COL_DIM := Color(0.45, 0.45, 0.48, 1)
const COL_DELTA_UP := Color(0.35, 0.55, 1.0, 1)
const COL_DELTA_DOWN := Color(0.92, 0.28, 0.28, 1)
const COL_CURSOR := Color(0.22, 0.42, 0.82, 0.55)
const COL_CURSOR_EDGE := Color(0.55, 0.78, 1.0, 0.95)

const FONT_SIZE := 13
const INV_ICON := 20
const INV_ROW_H := 25
const INV_LIST_SEP := 3
const INV_DELTA_W := 44
const INV_STAT_W := 40
const INV_QTY_W := 28
const INV_PAD_H := 10
const INV_PAD_V := 6
const CUR_ICON_H := 18
const CUR_ICON_W := 28


var _root: VBoxContainer
var _cur_icon: TextureRect
var _cur_name: Label
var _cur_def: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _slot := -1
var _klass := -1
var _current_id := 0
var _current_def := 0
## Parallel to selectable rows: armor ids in list order (including grayed).
var _ids: Array[int] = []
var _usable: Array[bool] = []
var _row_wraps: Array[Control] = []
var _cursor := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", 6)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var pad_top := Control.new()
	pad_top.custom_minimum_size = Vector2(0, INV_PAD_V)
	pad_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(pad_top)

	var cur_wrap := MarginContainer.new()
	cur_wrap.add_theme_constant_override("margin_left", INV_PAD_H)
	cur_wrap.add_theme_constant_override("margin_right", INV_PAD_H)
	cur_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cur_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(cur_wrap)

	var cur_row := HBoxContainer.new()
	cur_row.add_theme_constant_override("separation", 6)
	cur_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cur_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cur_wrap.add_child(cur_row)

	_cur_icon = TextureRect.new()
	_cur_icon.custom_minimum_size = Vector2(CUR_ICON_W, CUR_ICON_H)
	_cur_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cur_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cur_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cur_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cur_row.add_child(_cur_icon)

	_cur_name = Label.new()
	_cur_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cur_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cur_name.add_theme_font_size_override("font_size", FONT_SIZE)
	_cur_name.add_theme_color_override("font_color", COL_TEXT)
	UiTheme.apply_font(_cur_name)
	_cur_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cur_row.add_child(_cur_name)

	var def_kind := Label.new()
	def_kind.text = Locale.t("ztats_def")
	def_kind.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	def_kind.add_theme_font_size_override("font_size", FONT_SIZE)
	def_kind.add_theme_color_override("font_color", COL_ACCENT)
	UiTheme.apply_font(def_kind)
	def_kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cur_row.add_child(def_kind)

	_cur_def = Label.new()
	_cur_def.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cur_def.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cur_def.custom_minimum_size = Vector2(INV_STAT_W, 0)
	_cur_def.add_theme_font_size_override("font_size", FONT_SIZE)
	_cur_def.add_theme_color_override("font_color", COL_TEXT)
	UiTheme.apply_font(_cur_def)
	_cur_def.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cur_row.add_child(_cur_def)

	var hdr_wrap := MarginContainer.new()
	hdr_wrap.add_theme_constant_override("margin_left", INV_PAD_H)
	hdr_wrap.add_theme_constant_override("margin_right", INV_PAD_H)
	hdr_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hdr_wrap)
	hdr_wrap.add_child(_make_header_row())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func open_for(slot: int) -> void:
	_slot = slot
	_klass = GameState.party_member_at(slot)
	_current_id = GameState.armor_of_slot(slot)
	_current_def = _ArmorIcons.defense_of(_current_id)
	_refresh_current()
	_rebuild_list()
	_cursor = _first_usable_index()
	_sync_cursor()
	visible = true


func close_panel() -> void:
	visible = false
	_slot = -1
	_klass = -1
	_ids.clear()
	_usable.clear()
	_row_wraps.clear()
	_clear_list()


func slot() -> int:
	return _slot


func cursor_armor_id() -> int:
	if _cursor < 0 or _cursor >= _ids.size():
		return -1
	if not _usable[_cursor]:
		return -1
	return _ids[_cursor]


func nudge_cursor(step: int) -> void:
	## Skip class-restricted rows; no wrap.
	if _ids.is_empty() or step == 0:
		return
	var i := _cursor
	var n := _ids.size()
	while true:
		i += step
		if i < 0 or i >= n:
			return
		if _usable[i]:
			_cursor = i
			_sync_cursor()
			_ensure_cursor_visible()
			return


func _refresh_current() -> void:
	_cur_icon.texture = _keyed_icon(_current_id)
	_cur_name.text = Locale.armor_name(_current_id)
	_cur_def.text = str(_current_def)


func _rebuild_list() -> void:
	_clear_list()
	_ids.clear()
	_usable.clear()
	_row_wraps.clear()
	## No Armour always; owned stock only (equipped is not in inventory).
	_add_armor_row(0, true)
	for a in range(1, GameState.armor.size()):
		if int(GameState.armor[a]) <= 0:
			continue
		_add_armor_row(a, false)


func _add_armor_row(armor_id: int, is_none: bool) -> void:
	var ok := _ArmorIcons.can_wear(armor_id, _klass)
	var defense := _ArmorIcons.defense_of(armor_id)
	var delta := defense - _current_def
	var letter := String.chr(65 + armor_id)
	var nm := "%s. %s" % [letter, Locale.armor_name(armor_id)]
	var qty := 0 if is_none else int(GameState.armor[armor_id])

	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, INV_ROW_H)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.clip_contents = true

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_meta("wear_bg", true)
	wrap.add_child(bg)

	var edge := ColorRect.new()
	edge.color = Color(0, 0, 0, 0)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	edge.offset_right = 2
	edge.set_meta("wear_edge", true)
	wrap.add_child(edge)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(row)

	var tex := _keyed_icon(armor_id)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(INV_ICON, INV_ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = tex
	icon.modulate = Color.WHITE if ok else COL_DIM
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var name_lab := Label.new()
	name_lab.text = nm
	name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lab.add_theme_font_size_override("font_size", FONT_SIZE)
	name_lab.add_theme_color_override("font_color", COL_TEXT if ok else COL_DIM)
	UiTheme.apply_font(name_lab)
	name_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_lab)

	var delta_lab := Label.new()
	delta_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	delta_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	delta_lab.custom_minimum_size = Vector2(INV_DELTA_W, 0)
	delta_lab.add_theme_font_size_override("font_size", FONT_SIZE)
	if not ok or delta == 0:
		delta_lab.text = ""
		delta_lab.add_theme_color_override("font_color", COL_DIM)
	elif delta > 0:
		delta_lab.text = "+%d" % delta
		delta_lab.add_theme_color_override("font_color", COL_DELTA_UP)
	else:
		delta_lab.text = "%d" % delta
		delta_lab.add_theme_color_override("font_color", COL_DELTA_DOWN)
	UiTheme.apply_font(delta_lab)
	delta_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(delta_lab)

	var def_lab := Label.new()
	def_lab.text = str(defense)
	def_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	def_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	def_lab.custom_minimum_size = Vector2(INV_STAT_W, 0)
	def_lab.add_theme_font_size_override("font_size", FONT_SIZE)
	def_lab.add_theme_color_override("font_color", COL_TEXT if ok else COL_DIM)
	UiTheme.apply_font(def_lab)
	def_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(def_lab)

	var qty_lab := Label.new()
	qty_lab.text = "" if is_none else str(mini(qty, 99))
	qty_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qty_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qty_lab.custom_minimum_size = Vector2(INV_QTY_W, 0)
	qty_lab.add_theme_font_size_override("font_size", FONT_SIZE)
	qty_lab.add_theme_color_override("font_color", COL_TEXT if ok else COL_DIM)
	UiTheme.apply_font(qty_lab)
	qty_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(qty_lab)

	_list.add_child(wrap)
	_ids.append(armor_id)
	_usable.append(ok)
	_row_wraps.append(wrap)


func _make_header_row() -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, INV_ROW_H)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(row)

	var icon_pad := Control.new()
	icon_pad.custom_minimum_size = Vector2(INV_ICON, 1)
	icon_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_pad)

	var nm := Label.new()
	nm.text = Locale.t("ztats_col_name")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", FONT_SIZE - 1)
	nm.add_theme_color_override("font_color", COL_ACCENT)
	UiTheme.apply_font(nm)
	row.add_child(nm)

	var delta := Label.new()
	delta.text = Locale.t("ready_col_delta")
	delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	delta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	delta.custom_minimum_size = Vector2(INV_DELTA_W, 0)
	delta.add_theme_font_size_override("font_size", FONT_SIZE - 1)
	delta.add_theme_color_override("font_color", COL_ACCENT)
	UiTheme.apply_font(delta)
	row.add_child(delta)

	var st := Label.new()
	st.text = Locale.t("ztats_col_defense")
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	st.custom_minimum_size = Vector2(INV_STAT_W, 0)
	st.add_theme_font_size_override("font_size", FONT_SIZE - 1)
	st.add_theme_color_override("font_color", COL_ACCENT)
	UiTheme.apply_font(st)
	row.add_child(st)

	var q := Label.new()
	q.text = Locale.t("ztats_col_qty")
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.custom_minimum_size = Vector2(INV_QTY_W, 0)
	q.add_theme_font_size_override("font_size", FONT_SIZE - 1)
	q.add_theme_color_override("font_color", COL_ACCENT)
	UiTheme.apply_font(q)
	row.add_child(q)
	return wrap


func _first_usable_index() -> int:
	for i in _usable.size():
		if _usable[i]:
			return i
	return 0


func _keyed_icon(armor_id: int) -> Texture2D:
	## White paper bg → transparent (same as Ztats gear icons).
	var path := _ArmorIcons.path_for_id(armor_id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded := load(path) as Texture2D
	if loaded == null:
		return null
	var img := loaded.get_image()
	if img == null or img.is_empty():
		return loaded
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r > 0.92 and c.g > 0.92 and c.b > 0.92:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func _sync_cursor() -> void:
	for i in _row_wraps.size():
		var wrap := _row_wraps[i]
		var on := i == _cursor and _usable[i]
		for c in wrap.get_children():
			if c.has_meta("wear_bg"):
				(c as ColorRect).color = COL_CURSOR if on else Color(0, 0, 0, 0)
			elif c.has_meta("wear_edge"):
				(c as ColorRect).color = COL_CURSOR_EDGE if on else Color(0, 0, 0, 0)


func _ensure_cursor_visible() -> void:
	if _cursor < 0 or _cursor >= _row_wraps.size() or _scroll == null:
		return
	var row := _row_wraps[_cursor]
	var top := row.position.y
	var bot := top + row.size.y
	var view_top := _scroll.scroll_vertical
	var view_bot := view_top + _scroll.size.y
	if top < view_top:
		_scroll.scroll_vertical = int(top)
	elif bot > view_bot:
		_scroll.scroll_vertical = int(bot - _scroll.size.y)


func _clear_list() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
