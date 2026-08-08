class_name SaveSlotPanel
extends Control

## 4-slot save/load picker.
## Modal (centered + dim backdrop) by default; optional frame-embedded layout for main menu.

enum Mode { SAVE = 0, LOAD = 1 }

const SLOT_COUNT := 4
const COL_TEXT := Color(0.91, 0.9, 0.82, 1)
const COL_DIM := Color(0.55, 0.58, 0.55, 1)
const COL_ACCENT := Color(0.95, 0.85, 0.45, 1)
const COL_CURSOR := Color(0.22, 0.42, 0.82, 0.55)
const COL_CURSOR_EDGE := Color(0.55, 0.78, 1.0, 0.95)
const FONT_SIZE := 16
const FONT_SIZE_SUB := 13
const FACE_SZ := 40.0
const COMP_SZ := 32.0
const ROW_H := 72.0
const PANEL_W := 560.0
const MODAL_ROW_SEP := 10
## Embedded (main-menu frame): 8-party width, nearly full frame height, centered.
const EMBED_FONT := 16
const EMBED_FONT_SUB := 13
const EMBED_FACE_BASE := 40.0
const EMBED_COMP_BASE := 32.0
const EMBED_NUM_W := 26.0
const EMBED_NAME_W_BASE := 168.0
const EMBED_PAD_L := 12.0
const EMBED_PAD_R := 10.0
const EMBED_ROW_SEP := 12.0
const EMBED_COMP_SEP := 3.0
const EMBED_COL_SEP := 10.0
const EMBED_MAX_PARTY := 8 ## avatar + companions
const EMBED_HEIGHT_FRAC := 0.96 ## 4 slots nearly fill frame height


var _backdrop: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _title: Label
var _list: VBoxContainer
var _col: VBoxContainer
var _rows: Array[Control] = []
var _row_bgs: Array[ColorRect] = []
var _row_edges: Array[ColorRect] = []
var _num_labs: Array[Label] = []
var _face_rects: Array[TextureRect] = []
var _name_labs: Array[Label] = []
var _comp_rows: Array[HBoxContainer] = []
var _comp_wraps: Array[Control] = []
var _sub_labs: Array[Label] = []
var _empty_labs: Array[Label] = []
var _content_cols: Array[Control] = []
var _cursor := 0
var _mode: int = Mode.SAVE
var _class_tiles: Array[Texture2D] = []
var _embedded := false
var _embed_rect := Rect2()
## Live embed metrics (scaled so 4 slots fill frame height).
var _e_face := EMBED_FACE_BASE
var _e_comp := EMBED_COMP_BASE
var _e_name_w := EMBED_NAME_W_BASE
var _e_font := EMBED_FONT
var _e_font_sub := EMBED_FONT_SUB


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false


func _cache_class_tiles() -> void:
	## Lazy + shared with PartyRoster cache (do not reload class tiles 8× on boot).
	if _class_tiles.size() == 8:
		return
	_class_tiles.clear()
	for i in 8:
		_class_tiles.append(PartyRoster._ztats_class_tile(i))


func is_open() -> bool:
	return visible


func is_embedded() -> bool:
	return _embedded and visible


func mode() -> int:
	return _mode


func open_panel(p_mode: int = Mode.SAVE, default_cursor: int = 0) -> void:
	_cache_class_tiles()
	_mode = p_mode
	_embedded = false
	_embed_rect = Rect2()
	_cursor = clampi(default_cursor, 0, SLOT_COUNT - 1)
	_apply_presentation()
	_refresh_rows()
	_sync_cursor()
	visible = true
	move_to_front()


## Show the slot list inside `rect` (main-menu map frame) — no modal backdrop.
func open_embedded(p_mode: int, rect: Rect2, default_cursor: int = 0) -> void:
	_cache_class_tiles()
	_mode = p_mode
	_embedded = true
	_embed_rect = rect
	_cursor = clampi(default_cursor, 0, SLOT_COUNT - 1)
	_apply_presentation()
	_refresh_rows()
	_sync_cursor()
	visible = true
	move_to_front()


func set_embed_rect(rect: Rect2) -> void:
	## Resize while open (window resize).
	if not visible or not _embedded:
		return
	_embed_rect = rect
	_apply_presentation()


func close_panel() -> void:
	visible = false
	_embedded = false


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
		## Host = map frame; content is party-sized and center-aligned.
		_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if _panel.get_parent() != _center:
			if _panel.get_parent() != null:
				_panel.get_parent().remove_child(_panel)
			_center.add_child(_panel)
		_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_panel.anchor_right = 0.0
		_panel.anchor_bottom = 0.0
		_panel.offset_left = 0.0
		_panel.offset_top = 0.0
		_panel.offset_right = 0.0
		_panel.offset_bottom = 0.0
		var bare := StyleBoxEmpty.new()
		_panel.add_theme_stylebox_override("panel", bare)
		_title.visible = false
		var content := _embed_content_size()
		_scale_metrics(true)
		_panel.custom_minimum_size = content
		_panel.size = content
	else:
		_backdrop.visible = true
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		position = Vector2.ZERO
		custom_minimum_size = Vector2.ZERO
		_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if _panel.get_parent() != _center:
			if _panel.get_parent() != null:
				_panel.get_parent().remove_child(_panel)
			_center.add_child(_panel)
		_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_panel.anchor_right = 0.0
		_panel.anchor_bottom = 0.0
		_panel.offset_left = 0.0
		_panel.offset_top = 0.0
		_panel.offset_right = 0.0
		_panel.offset_bottom = 0.0
		_panel.custom_minimum_size = Vector2(PANEL_W, 0)
		_panel.add_theme_stylebox_override("panel", UiTheme.make_panel())
		_title.visible = true
		_scale_metrics(false)


## Width = 8-party row; height ≈ frame height so 4 slots nearly fill it.
func _embed_content_size() -> Vector2:
	var frame_w := maxf(_embed_rect.size.x, 80.0)
	var frame_h := maxf(_embed_rect.size.y, 80.0)
	var h := frame_h * EMBED_HEIGHT_FRAC
	var sep := EMBED_ROW_SEP
	var row_h := (h - float(SLOT_COUNT - 1) * sep) / float(SLOT_COUNT)
	## Grow faces with row height (larger slots).
	_e_face = clampf(row_h * 0.52, 36.0, 56.0)
	_e_comp = clampf(_e_face * 0.8, 28.0, 46.0)
	_e_name_w = clampf(EMBED_NAME_W_BASE * (_e_face / EMBED_FACE_BASE), 150.0, 200.0)
	_e_font = clampi(int(round(EMBED_FONT * (_e_face / EMBED_FACE_BASE))), 14, 18)
	_e_font_sub = maxi(_e_font - 3, 11)

	var max_comps := EMBED_MAX_PARTY - 1
	var comps_w := float(max_comps) * _e_comp + float(maxi(0, max_comps - 1)) * EMBED_COMP_SEP
	var w := (
		EMBED_PAD_L
		+ EMBED_NUM_W
		+ EMBED_COL_SEP
		+ _e_face
		+ EMBED_COL_SEP
		+ _e_name_w
		+ EMBED_COL_SEP
		+ comps_w
		+ EMBED_PAD_R
	)
	## Width only: stay inside frame; height nearly fills (center laterally).
	var max_w := maxf(frame_w - 8.0, 80.0)
	if w > max_w:
		var s := max_w / w
		w = max_w
		_e_face *= s
		_e_comp *= s
		_e_name_w *= s
	return Vector2(w, h)


func _scale_metrics(embed: bool) -> void:
	var face := _e_face if embed else FACE_SZ
	var row_h := ROW_H if not embed else 0.0
	var font := _e_font if embed else FONT_SIZE
	var font_sub := _e_font_sub if embed else FONT_SIZE_SUB
	var comp := _e_comp if embed else COMP_SZ
	var max_comps := EMBED_MAX_PARTY - 1
	var comp_sep := EMBED_COMP_SEP if embed else 3.0
	var comps_w := float(max_comps) * comp + float(maxi(0, max_comps - 1)) * comp_sep
	_title.add_theme_font_size_override("font_size", font + 2)
	if _col:
		_col.add_theme_constant_override("separation", 0 if embed else 10)
	if _list:
		_list.add_theme_constant_override("separation", int(EMBED_ROW_SEP) if embed else MODAL_ROW_SEP)
		_list.size_flags_vertical = Control.SIZE_EXPAND_FILL if embed else Control.SIZE_SHRINK_BEGIN
	for i in _rows.size():
		if embed:
			_rows[i].custom_minimum_size = Vector2(0, 0)
			_rows[i].size_flags_vertical = Control.SIZE_EXPAND_FILL
		else:
			_rows[i].custom_minimum_size = Vector2(0, row_h)
			_rows[i].size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_face_rects[i].custom_minimum_size = Vector2(face, face)
		_num_labs[i].custom_minimum_size = Vector2(EMBED_NUM_W if embed else 24.0, 0)
		_num_labs[i].add_theme_font_size_override("font_size", font)
		_name_labs[i].add_theme_font_size_override("font_size", font)
		_empty_labs[i].add_theme_font_size_override("font_size", font)
		_sub_labs[i].add_theme_font_size_override("font_size", font_sub)
		_comp_rows[i].add_theme_constant_override("separation", int(comp_sep))
		if embed:
			_name_labs[i].custom_minimum_size = Vector2(_e_name_w, 0)
			_name_labs[i].size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			_comp_wraps[i].custom_minimum_size = Vector2(comps_w, 0)
			_comp_wraps[i].size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		else:
			_name_labs[i].custom_minimum_size = Vector2.ZERO
			_name_labs[i].size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			_comp_wraps[i].custom_minimum_size = Vector2.ZERO
			_comp_wraps[i].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for ch in _comp_rows[i].get_children():
			if ch is TextureRect:
				(ch as TextureRect).custom_minimum_size = Vector2(comp, comp)


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
	_col.add_theme_constant_override("separation", 10)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_col)

	_title = Label.new()
	_title.text = Locale.t("save_title")
	_title.add_theme_font_override("font", UiTheme.font_bold())
	_title.add_theme_font_size_override("font_size", FONT_SIZE + 2)
	_title.add_theme_color_override("font_color", COL_ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(_title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_col.add_child(_list)

	_rows.clear()
	_row_bgs.clear()
	_row_edges.clear()
	_num_labs.clear()
	_face_rects.clear()
	_name_labs.clear()
	_comp_rows.clear()
	_comp_wraps.clear()
	_sub_labs.clear()
	_empty_labs.clear()
	_content_cols.clear()

	for i in SLOT_COUNT:
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

		## Right zone: companion faces (up to 7 = full 8-party with avatar face).
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
		_comp_wraps.append(comps_wrap)
		_sub_labs.append(sub)
		_empty_labs.append(empty)
		_content_cols.append(content)

	## No instructional hint under the list (any mode).


func _refresh_rows() -> void:
	var title_key := "load_title" if _mode == Mode.LOAD else "save_title"
	_title.text = Locale.t(title_key)
	_title.visible = not _embedded
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
	var when := SaveGame.format_saved_at_display(str(meta.get("saved_at", "")))
	var loc := SaveGame.format_location(meta.get("location", {}))
	if when.is_empty() and loc.is_empty():
		_sub_labs[index].text = Locale.t("save_slot_moves", [str(moves)])
	elif loc.is_empty():
		_sub_labs[index].text = Locale.t("save_slot_moves_when_noloc", [str(moves), when])
	else:
		_sub_labs[index].text = Locale.t("save_slot_moves_when", [str(moves), loc, when])


func _fill_companions(index: int, meta: Dictionary) -> void:
	_clear_companions(index)
	var comps: HBoxContainer = _comp_rows[index]
	var order: Variant = meta.get("party_order", [])
	if typeof(order) != TYPE_ARRAY:
		return
	var avatar_klass := int(meta.get("class", -1))
	var comp_sz := _e_comp if _embedded else COMP_SZ
	for raw in order as Array:
		var mid := int(raw)
		if mid < 0 or mid > 7:
			continue
		if mid == avatar_klass:
			continue ## Avatar class tile is already on the left.
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(comp_sz, comp_sz)
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
