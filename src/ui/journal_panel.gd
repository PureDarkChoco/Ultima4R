class_name JournalPanel
extends VBoxContainer

## Left-pane travel journal: place headers + dated quest notes.

const _Journal := preload("res://src/core/journal.gd")
const PENDING_ICON := "res://assets/ui/journal/pending.png"
const DONE_ICON := "res://assets/ui/journal/done.png"
const TITLE_SIZE := 15
const PLACE_SIZE := 13
const BODY_SIZE := 14
const META_SIZE := 10
const ICON_PX := 20
const ENTRY_GAP := 8
const CHAIN_ICON_GAP := 2
const CHAIN_LINE_COLOR := Color(0.42, 0.45, 0.43, 1)
const COL_TITLE := Color(0.95, 0.9, 0.72, 1)
const COL_PLACE := Color(0.82, 0.78, 0.55, 1)
## Record body — bright, larger than speaker/time.
const COL_BODY := Color(0.96, 0.95, 0.9, 1)
## Speaker · time — half body size, muted gray.
const COL_META := Color(0.52, 0.55, 0.52, 1)
const COL_EMPTY := Color(0.55, 0.62, 0.58, 1)

var _title: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _empty: Label
var _pending_tex: Texture2D
var _done_tex: Texture2D


class StatusIcon extends Control:
	var texture: Texture2D
	var connect_above := false
	var connect_below := false

	func _ready() -> void:
		custom_minimum_size = Vector2(ICON_PX, ICON_PX)
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.position = Vector2.ZERO
		icon.size = Vector2(ICON_PX, ICON_PX)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.texture = texture
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)

	func _draw() -> void:
		var center_x := ICON_PX * 0.5
		if connect_above:
			draw_line(
				Vector2(center_x, -ENTRY_GAP * 0.5),
				Vector2(center_x, -CHAIN_ICON_GAP),
				CHAIN_LINE_COLOR,
				2.0
			)
		if connect_below:
			draw_line(
				Vector2(center_x, ICON_PX + CHAIN_ICON_GAP),
				Vector2(center_x, size.y + ENTRY_GAP * 0.5),
				CHAIN_LINE_COLOR,
				2.0
			)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	_pending_tex = load(PENDING_ICON) as Texture2D
	_done_tex = load(DONE_ICON) as Texture2D
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", TITLE_SIZE)
	_title.add_theme_color_override("font_color", COL_TITLE)
	UiTheme.apply_font(_title, true)
	add_child(_title)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", ENTRY_GAP)
	_scroll.add_child(_list)
	_empty = Label.new()
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_theme_font_size_override("font_size", BODY_SIZE)
	_empty.add_theme_color_override("font_color", COL_EMPTY)
	UiTheme.apply_font(_empty)
	add_child(_empty)
	if Engine.get_main_loop() != null:
		var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
		if gs != null and gs.has_signal("language_changed"):
			gs.language_changed.connect(func(_l: String) -> void: refresh())
	refresh()


func refresh() -> void:
	if _title == null:
		return
	_title.text = Locale.t("journal_title")
	_empty.text = Locale.t("journal_empty")
	for c in _list.get_children():
		c.queue_free()
	var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState") if Engine.get_main_loop() else null
	var groups := _Journal.grouped_for_ui(gs)
	var lang := "en_us"
	if gs != null:
		lang = str(gs.lang_short()) if gs.has_method("lang_short") else str(gs.language)
	var has_any := not groups.is_empty()
	_empty.visible = not has_any
	_scroll.visible = has_any
	if not has_any:
		return
	for group in groups:
		var place := str(group.get("place", ""))
		var rows: Array = group.get("entries", [])
		if rows.is_empty():
			continue
		_list.add_child(_make_place_header(place))
		for i in rows.size():
			var row: Variant = rows[i]
			if typeof(row) == TYPE_DICTIONARY:
				var d := row as Dictionary
				var chain := _Journal.entry_chain(d)
				var connect_above := (
					not chain.is_empty()
					and i > 0
					and typeof(rows[i - 1]) == TYPE_DICTIONARY
					and _Journal.entry_chain(rows[i - 1] as Dictionary) == chain
				)
				var connect_below := (
					not chain.is_empty()
					and i + 1 < rows.size()
					and typeof(rows[i + 1]) == TYPE_DICTIONARY
					and _Journal.entry_chain(rows[i + 1] as Dictionary) == chain
				)
				_list.add_child(
					_make_entry_row(d, lang, connect_above, connect_below)
				)


func _make_place_header(place_id: String) -> Control:
	var lab := Label.new()
	lab.text = Locale.t("place_%s" % place_id)
	lab.add_theme_font_size_override("font_size", PLACE_SIZE)
	lab.add_theme_color_override("font_color", COL_PLACE)
	UiTheme.apply_font(lab, true)
	return lab


func _make_entry_row(
	row: Dictionary,
	lang: String,
	connect_above: bool,
	connect_below: bool
) -> Control:
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var status := StatusIcon.new()
	status.texture = _done_tex if bool(row.get("done", false)) else _pending_tex
	status.connect_above = connect_above
	status.connect_below = connect_below
	root.add_child(status)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	root.add_child(col)
	var body := Label.new()
	body.text = _Journal.entry_text(row, lang)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", BODY_SIZE)
	body.add_theme_color_override("font_color", COL_BODY)
	UiTheme.apply_font(body, true)
	col.add_child(body)
	var meta := Label.new()
	var speaker := _Journal.entry_speaker(row, lang)
	var when := _Journal.format_time(int(row.get("at", 0)))
	if when.is_empty():
		meta.text = speaker
	else:
		meta.text = "%s · %s" % [speaker, when]
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.add_theme_font_size_override("font_size", META_SIZE)
	meta.add_theme_color_override("font_color", COL_META)
	UiTheme.apply_font(meta)
	col.add_child(meta)
	return root
