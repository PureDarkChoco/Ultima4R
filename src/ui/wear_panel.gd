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
const COL_CURSOR_EDGE := Color(0.38, 0.58, 0.82, 0.72)

const FONT_SIZE := 13
## Source art is 32×32; match Ztats / Ready / Mix display size.
const INV_ICON := 20
const INV_ROW_H := 25
const INV_LIST_SEP := 3
const INV_DELTA_W := 44
## Wide enough for "Damage" / "Defense" titles at FONT_SIZE-1 (fixed-width slot).
const INV_STAT_W := 56
const INV_QTY_W := 28
const INV_PAD_H := 10
const INV_PAD_TOP := 6
const INV_ROOT_SEP := 6
const CUR_ICON := 20


var _root: VBoxContainer
var _pad_top: Control
var _name_left: Label
var _member_name: Label
var _name_right: Label
var _cur_icon: TextureRect
var _cur_name: Label
var _cur_def: Label
var _switchable := false
var _scroll: ScrollContainer
var _list: VBoxContainer
## Absorbs leftover panel pixels so the list viewport is an exact N-row height.
var _tail: Control
var _visible_rows := 1
var _slot := -1
var _klass := -1
var _current_id := 0
var _current_def := 0
## Parallel to selectable rows: armor ids in list order (including grayed).
var _ids: Array[int] = []
var _usable: Array[bool] = []
var _row_wraps: Array[Control] = []
var _cursor := 0
## Bumps to cancel deferred scroll restores after close / reopen.
var _scroll_gen := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", INV_ROOT_SEP)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_pad_top = Control.new()
	_pad_top.custom_minimum_size = Vector2(0, INV_PAD_TOP)
	_pad_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_pad_top)

	var name_wrap := MarginContainer.new()
	name_wrap.add_theme_constant_override("margin_left", INV_PAD_H)
	name_wrap.add_theme_constant_override("margin_right", INV_PAD_H)
	name_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(name_wrap)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_wrap.add_child(name_row)

	_name_left = Label.new()
	_name_left.text = "◀"
	_name_left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_left.add_theme_font_size_override("font_size", FONT_SIZE)
	_name_left.add_theme_color_override("font_color", COL_ACCENT)
	UiTheme.apply_font(_name_left)
	_name_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_left.visible = false
	name_row.add_child(_name_left)

	_member_name = Label.new()
	_member_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_member_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_member_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_member_name.add_theme_font_size_override("font_size", FONT_SIZE + 1)
	_member_name.add_theme_color_override("font_color", COL_ACCENT)
	UiTheme.apply_font(_member_name)
	_member_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(_member_name)

	_name_right = Label.new()
	_name_right.text = "▶"
	_name_right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_right.add_theme_font_size_override("font_size", FONT_SIZE)
	_name_right.add_theme_color_override("font_color", COL_ACCENT)
	UiTheme.apply_font(_name_right)
	_name_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_right.visible = false
	name_row.add_child(_name_right)

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
	_cur_icon.custom_minimum_size = Vector2(CUR_ICON, CUR_ICON)
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

	## Match list columns: Δ | DEF | Qty (kind sits in the Δ slot).
	cur_row.add_child(_fixed_col(
		Locale.t("ztats_def"), INV_DELTA_W, FONT_SIZE, COL_ACCENT
	))
	var def_slot := Control.new()
	def_slot.custom_minimum_size = Vector2(INV_STAT_W, 0)
	def_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	def_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	def_slot.clip_contents = true
	_cur_def = Label.new()
	_cur_def.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cur_def.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cur_def.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cur_def.clip_text = true
	_cur_def.add_theme_font_size_override("font_size", FONT_SIZE)
	_cur_def.add_theme_color_override("font_color", COL_TEXT)
	UiTheme.apply_font(_cur_def)
	_cur_def.mouse_filter = Control.MOUSE_FILTER_IGNORE
	def_slot.add_child(_cur_def)
	cur_row.add_child(def_slot)
	cur_row.add_child(_fixed_col("", INV_QTY_W, FONT_SIZE, COL_TEXT))

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
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll.clip_contents = true
	_root.add_child(_scroll)

	var list_margin := MarginContainer.new()
	list_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_margin.add_theme_constant_override("margin_left", INV_PAD_H)
	list_margin.add_theme_constant_override("margin_right", INV_PAD_H)
	## No bottom pad — content height is an exact multiple of the row stride.
	list_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(list_margin)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", INV_LIST_SEP)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_margin.add_child(_list)

	_tail = Control.new()
	_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tail.custom_minimum_size = Vector2.ZERO
	_tail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_root.add_child(_tail)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		call_deferred("_fit_list_viewport_gen", _scroll_gen)


func open_for(slot: int, switchable: bool = false) -> void:
	## Always start at the top usable row and scroll home.
	_scroll_gen += 1
	_slot = slot
	_switchable = switchable
	_klass = GameState.party_member_at(slot)
	_current_id = GameState.armor_of_slot(slot)
	_current_def = _ArmorIcons.defense_of(_current_id)
	_refresh_member_name()
	_refresh_current()
	_rebuild_list()
	_cursor = _first_usable_index()
	_sync_cursor()
	_scroll_to_top()
	visible = true
	var gen := _scroll_gen
	call_deferred("_fit_list_viewport_gen", gen)


func reload_equipped() -> void:
	## After a successful wear: rebuild stats/qty, keep the cursor on the same row.
	if _slot < 0:
		return
	var keep_id := -1
	if _cursor >= 0 and _cursor < _ids.size():
		keep_id = int(_ids[_cursor])
	_klass = GameState.party_member_at(_slot)
	_current_id = GameState.armor_of_slot(_slot)
	_current_def = _ArmorIcons.defense_of(_current_id)
	_refresh_member_name()
	_refresh_current()
	_rebuild_list()
	var keep := _index_of_id(keep_id)
	if keep >= 0 and keep < _usable.size() and _usable[keep]:
		_cursor = keep
	else:
		_cursor = _first_usable_index()
	_sync_cursor()
	_ensure_cursor_visible()


func close_panel() -> void:
	_scroll_gen += 1
	visible = false
	_slot = -1
	_klass = -1
	_switchable = false
	_ids.clear()
	_usable.clear()
	_row_wraps.clear()
	_clear_list()
	_scroll_to_top()


func slot() -> int:
	return _slot


func cursor_armor_id() -> int:
	if _cursor < 0 or _cursor >= _ids.size():
		return -1
	if not _usable[_cursor]:
		return -1
	return _ids[_cursor]


func row_index_at_global(pos: Vector2) -> int:
	if not visible:
		return -1
	for i in _row_wraps.size():
		var row := _row_wraps[i]
		if row == null or not row.is_visible_in_tree():
			continue
		if row.get_global_rect().has_point(pos):
			return i
	return -1


func hover_row(index: int) -> void:
	if index < 0 or index >= _row_wraps.size() or index == _cursor:
		return
	_cursor = index
	_sync_cursor()


func member_switch_dir_at_global(pos: Vector2) -> int:
	## ◀ / ▶ next to the member name: -1 left, +1 right, else 0.
	if not visible or not _switchable:
		return 0
	if _name_left != null and _name_left.visible and _name_left.get_global_rect().has_point(pos):
		return -1
	if _name_right != null and _name_right.visible and _name_right.get_global_rect().has_point(pos):
		return 1
	return 0


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


func _refresh_member_name() -> void:
	if _member_name == null:
		return
	if _slot >= 0:
		_member_name.text = GameState.party_member_display_name(_slot)
	else:
		_member_name.text = ""
	if _name_left:
		_name_left.visible = _switchable
	if _name_right:
		_name_right.visible = _switchable


func _index_of_id(item_id: int) -> int:
	if item_id < 0:
		return -1
	for i in _ids.size():
		if int(_ids[i]) == item_id:
			return i
	return -1


func _refresh_current() -> void:
	_cur_icon.texture = _keyed_icon(_current_id)
	_cur_name.text = Locale.armor_name(_current_id)
	_cur_name.add_theme_color_override("font_color", COL_TEXT)
	_cur_def.text = str(_current_def)


func _rebuild_list() -> void:
	_clear_list()
	_ids.clear()
	_usable.clear()
	_row_wraps.clear()
	## No Armour always; once-owned armor (qty 0 while worn still listed).
	_add_armor_row(0, true)
	for a in range(1, GameState.armor.size()):
		if not GameState.is_armor_known(a) and int(GameState.armor[a]) <= 0:
			continue
		_add_armor_row(a, false)


func can_select_armor(armor_id: int) -> bool:
	## Qty 0 (except No Armor) and class-restricted rows are not selectable.
	for i in _ids.size():
		if int(_ids[i]) == armor_id:
			return bool(_usable[i])
	return false


func _add_armor_row(armor_id: int, is_none: bool) -> void:
	var defense := _ArmorIcons.defense_of(armor_id)
	var delta := defense - _current_def
	var letter := String.chr(65 + armor_id)
	var nm := "%s. %s" % [letter, Locale.armor_name(armor_id)]
	var qty := 0 if is_none else int(GameState.armor[armor_id])
	## Selectable with stock (No Armor always). Qty 0 stays visible; equipped last piece stays choosable.
	var class_ok := _ArmorIcons.can_wear(armor_id, _klass)
	var equipped := armor_id == _current_id
	var ok := class_ok and (is_none or qty > 0 or equipped)
	var name_col := COL_TEXT if (ok or equipped) else COL_DIM

	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, INV_ROW_H)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Fixed row height — clip so font metrics can't add 1–2px and jiggle scroll.
	wrap.clip_contents = true

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_meta("wear_bg", true)
	wrap.add_child(bg)

	var edge := UiTheme.make_selection_edge("wear_edge")
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
	icon.modulate = Color.WHITE if (ok or equipped) else COL_DIM
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var name_lab := Label.new()
	name_lab.text = nm
	name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lab.add_theme_font_size_override("font_size", FONT_SIZE)
	name_lab.add_theme_color_override("font_color", name_col)
	UiTheme.apply_font(name_lab)
	name_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_lab)

	var delta_txt := ""
	var delta_col := COL_DIM
	if ok and delta > 0:
		delta_txt = "+%d" % delta
		delta_col = COL_DELTA_UP
	elif ok and delta < 0:
		delta_txt = "%d" % delta
		delta_col = COL_DELTA_DOWN
	row.add_child(_fixed_col(delta_txt, INV_DELTA_W, FONT_SIZE, delta_col))
	row.add_child(_fixed_col(
		str(defense), INV_STAT_W, FONT_SIZE, COL_TEXT if ok else COL_DIM
	))
	row.add_child(_fixed_col(
		"" if is_none else str(mini(qty, 99)),
		INV_QTY_W,
		FONT_SIZE,
		COL_TEXT if ok else COL_DIM
	))

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

	## Fixed-width slots so long titles (Defense / 방어력) cannot shift Δ vs numbers.
	row.add_child(_fixed_col(
		Locale.t("ready_col_delta"), INV_DELTA_W, FONT_SIZE - 1, COL_ACCENT
	))
	row.add_child(_fixed_col(
		Locale.t("ztats_col_defense"), INV_STAT_W, FONT_SIZE - 1, COL_ACCENT
	))
	row.add_child(_fixed_col(
		Locale.t("ztats_col_qty"), INV_QTY_W, FONT_SIZE - 1, COL_ACCENT
	))
	return wrap


## Non-Container slot of exact width — Label text cannot widen the column.
func _fixed_col(
	text: String,
	width: float,
	font_size: int,
	color: Color
) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(width, 0)
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.clip_contents = true
	var lab := Label.new()
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.clip_text = true
	lab.add_theme_font_size_override("font_size", font_size)
	lab.add_theme_color_override("font_color", color)
	UiTheme.apply_font(lab)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(lab)
	return slot



func _first_usable_index() -> int:
	for i in _usable.size():
		if _usable[i]:
			return i
	return 0


func _keyed_icon(armor_id: int) -> Texture2D:
	## Near-black bg → transparent (armor art uses dark backdrops).
	var path := _ArmorIcons.path_for_id(armor_id)
	if path.is_empty():
		return null
	var img := Image.new()
	var fs := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if img.load(fs) != OK and img.load(path) != OK:
		var loaded := load(path) as Texture2D
		if loaded == null:
			return null
		img = loaded.get_image()
		if img == null or img.is_empty():
			return loaded
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.01 and c.r < 0.04 and c.g < 0.04 and c.b < 0.04:
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
				UiTheme.set_selection_edge_active(c, on, COL_CURSOR_EDGE)


func _ensure_cursor_visible() -> void:
	## Keep the focused row on the middle visible line, like the gamepad menu.
	if _cursor < 0 or _cursor >= _row_wraps.size() or _scroll == null:
		return
	var stride := INV_ROW_H + INV_LIST_SEP
	var total := _row_wraps.size()
	var vis := maxi(1, _visible_rows)
	var next := 0
	if total > vis:
		var center := int(vis / 2)
		next = clampi(_cursor - center, 0, total - vis) * stride
	next = clampi(next, 0, _scroll_max())
	if next != int(_scroll.scroll_vertical):
		_scroll.scroll_vertical = next


func _list_viewport_height(rows: int) -> int:
	if rows <= 0:
		return 0
	return rows * INV_ROW_H + (rows - 1) * INV_LIST_SEP


func _scroll_content_height() -> int:
	var n := _row_wraps.size()
	if n <= 0:
		return 0
	return n * INV_ROW_H + (n - 1) * INV_LIST_SEP


func _scroll_max() -> int:
	## content (n rows) − viewport (v rows) = (n − v) · stride
	var stride := INV_ROW_H + INV_LIST_SEP
	var n := _row_wraps.size()
	var v := maxi(1, _visible_rows)
	return maxi(0, (n - v) * stride)


func _fit_list_viewport_gen(gen: int) -> void:
	if gen != _scroll_gen:
		return
	## Let expand layout settle, then snap to an exact N-row height.
	_tail.custom_minimum_size = Vector2.ZERO
	_tail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll.custom_minimum_size = Vector2.ZERO
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _pad_top:
		_pad_top.custom_minimum_size.y = INV_PAD_TOP
	call_deferred("_fit_list_viewport_apply", gen)


func _fit_list_viewport_apply(gen: int) -> void:
	if gen != _scroll_gen:
		return
	_fit_list_viewport()
	_scroll_to_top()


func _fit_list_viewport() -> void:
	## Make scroll area height an exact multiple of list rows (no half-row clip).
	if _scroll == null or _tail == null or _root == null:
		return
	## Available height is the expanded scroll area (or formula if not yet laid out).
	var avail := int(_scroll.size.y)
	if avail < INV_ROW_H:
		var chrome := 0
		var before := 0
		for c in _root.get_children():
			if c == _scroll:
				break
			var ch := int(c.size.y)
			if ch < 1:
				ch = int(c.get_combined_minimum_size().y)
			chrome += ch
			before += 1
		chrome += INV_ROOT_SEP * before
		avail = int(size.y) - chrome - INV_ROOT_SEP
	if avail < INV_ROW_H:
		avail = INV_ROW_H
	var stride := INV_ROW_H + INV_LIST_SEP
	## Prefer one more full row by shaving top pad (list grows "up") when it fits.
	var pad_budget := INV_PAD_TOP
	var n_vis := maxi(1, (avail + INV_LIST_SEP) / stride)
	var residual := avail - _list_viewport_height(n_vis)
	var need_for_extra := stride - residual
	if residual > 0 and residual < stride and need_for_extra > 0 and need_for_extra <= pad_budget:
		if _pad_top:
			_pad_top.custom_minimum_size.y = INV_PAD_TOP - need_for_extra
		avail += need_for_extra
		n_vis += 1
	elif _pad_top:
		_pad_top.custom_minimum_size.y = INV_PAD_TOP
	var exact := _list_viewport_height(n_vis)
	residual = maxi(0, avail - exact)
	_visible_rows = n_vis
	_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll.custom_minimum_size = Vector2(0, exact)
	_tail.custom_minimum_size = Vector2(0, residual)
	_tail.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _scroll_to_top() -> void:
	if _scroll != null:
		_scroll.scroll_vertical = 0


func _clear_list() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
