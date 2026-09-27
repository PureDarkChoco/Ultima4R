class_name UsePanel
extends Control

## Use (U) — pick a owned quest item from a scrollable list.

const _UseItems := preload("res://src/core/use_items.gd")

const COL_TEXT := Color(0.91, 0.9, 0.82, 1)
const COL_ACCENT := Color(0.95, 0.85, 0.45, 1)
const COL_CURSOR := Color(0.22, 0.42, 0.82, 0.55)
const COL_CURSOR_EDGE := Color(0.38, 0.58, 0.82, 0.72)

const FONT_SIZE := 13
const INV_ICON := 20
const INV_ROW_H := 25
const INV_LIST_SEP := 3
const INV_PAD_H := 10
const INV_PAD_V := 6
const PAD_TOP := 14


var _root: VBoxContainer
var _title: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
## Parallel to rows: UseItems.Kind values.
var _kinds: Array[int] = []
var _row_wraps: Array[Control] = []
var _cursor := 0
var _scroll_gen := 0


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


func open_list() -> void:
	## Always start at the top row and scroll home.
	_scroll_gen += 1
	_title.text = Locale.t("cmd_use_which")
	_rebuild_list()
	_cursor = 0
	_sync_cursor()
	_scroll_to_top()
	var gen := _scroll_gen
	call_deferred("_scroll_to_top_gen", gen)
	visible = true


func close_panel() -> void:
	_scroll_gen += 1
	visible = false
	_kinds.clear()
	_row_wraps.clear()
	_clear_list()
	_scroll_to_top()


func is_empty() -> bool:
	return _kinds.is_empty()


func cursor_kind() -> int:
	if _cursor < 0 or _cursor >= _kinds.size():
		return -1
	return int(_kinds[_cursor])


func nudge_cursor(step: int) -> void:
	if _kinds.is_empty() or step == 0:
		return
	var n := _kinds.size()
	var next := clampi(_cursor + step, 0, n - 1)
	if next == _cursor:
		return
	_cursor = next
	_sync_cursor()
	_ensure_cursor_visible()


func _rebuild_list() -> void:
	_clear_list()
	_kinds.clear()
	_row_wraps.clear()
	for kind in _UseItems.owned_kinds():
		_add_row(int(kind))


func _add_row(kind: int) -> void:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, INV_ROW_H)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.clip_contents = true

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_meta("use_bg", true)
	wrap.add_child(bg)

	var edge := UiTheme.make_selection_edge("use_edge")
	wrap.add_child(edge)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(INV_ICON, INV_ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = _keyed_icon(_UseItems.icon_path(kind))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var name_lab := Label.new()
	name_lab.text = _UseItems.display_name(kind)
	name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lab.add_theme_font_size_override("font_size", FONT_SIZE)
	name_lab.add_theme_color_override("font_color", COL_TEXT)
	UiTheme.apply_font(name_lab)
	name_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_lab)

	_list.add_child(wrap)
	_kinds.append(kind)
	_row_wraps.append(wrap)


func _keyed_icon(path: String) -> Texture2D:
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
		var on := i == _cursor
		for c in wrap.get_children():
			if c.has_meta("use_bg"):
				(c as ColorRect).color = COL_CURSOR if on else Color(0, 0, 0, 0)
			elif c.has_meta("use_edge"):
				UiTheme.set_selection_edge_active(c, on, COL_CURSOR_EDGE)


func _ensure_cursor_visible() -> void:
	## Keep the focused row on the middle visible line, like the gamepad menu.
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


func _scroll_to_top() -> void:
	if _scroll != null:
		_scroll.scroll_vertical = 0


func _scroll_to_top_gen(gen: int) -> void:
	if gen != _scroll_gen:
		return
	_scroll_to_top()


func _clear_list() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
