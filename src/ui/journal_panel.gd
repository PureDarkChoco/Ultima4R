class_name JournalPanel
extends VBoxContainer

## Left-pane travel journal: place headers + dated quest notes.

const _Journal := preload("res://src/core/journal.gd")
const _Virtues := preload("res://src/core/virtues.gd")
const _Shrine := preload("res://src/core/shrine.gd")
const _RuneIcons := preload("res://src/core/rune_icons.gd")
const _SpecialItemIcons := preload("res://src/core/special_item_icons.gd")
const _WorldPortals := preload("res://src/map/world_portals.gd")
const MOON_PHASE_PATH := "res://assets/ui/moons/phase_%d.png"
## New / empty moon file index (xu4 MOON_CHAR order).
const MOON_NEW_FILE := 7
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
const COL_BODY_SEL := Color(1.0, 0.98, 0.86, 1)
## Speaker · time — half body size, muted gray.
const COL_META := Color(0.52, 0.55, 0.52, 1)
const COL_EMPTY := Color(0.55, 0.62, 0.58, 1)
const COL_SEL_IDLE := Color(0.95, 0.88, 0.55, 0.14)
const COL_SEL_FOCUS := Color(0.98, 0.9, 0.5, 0.28)
const COL_PLACE_SEL := Color(0.98, 0.92, 0.62, 1)
const COL_PAGE_NEW := Color(0.98, 0.86, 0.28, 1)
const PLACE_PREFIX := "place:"
const SWEEP_SEC := 0.62
const PAGE_COUNT := 2
const CODEX_ICON := 22
const CODEX_CELL_H := 22
const CODEX_NAME_SIZE := 11
const CODEX_HEAD_SIZE := 12
const CODEX_ICON_LABEL_GAP := 6
const CODEX_STONE_KEYS := [
	"journal_codex_stone_blue",
	"journal_codex_stone_yellow",
	"journal_codex_stone_red",
	"journal_codex_stone_green",
	"journal_codex_stone_orange",
	"journal_codex_stone_purple",
	"journal_codex_stone_white",
	"journal_codex_stone_black",
]
const CODEX_DUNGEONS := [
	"deceit", "despise", "destard", "wrong",
	"covetous", "shame", "hythloth", "abyss",
]

var _title: Label
var _page_mark: HBoxContainer
var _page_num_1: Label
var _page_sep: Label
var _page_num_2: Label
var _pages: Control
var _page1: VBoxContainer
var _page2: ScrollContainer
var _codex: VBoxContainer
var _scroll: Control
var _list: VBoxContainer
var _empty: Label
var _pending_tex: Texture2D
var _done_tex: Texture2D
var _browsing := false
var _entry_nodes: Dictionary = {}
var _header_nodes: Dictionary = {}
var _nav_ids: Array[String] = []
var _center_token := 0
var _flash_tween: Tween
var _flash_overlay: Control
var _flash_id := ""


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


class WriteSweep extends Control:
	## Left-to-right ink/light: veil lifts as a bright edge writes the line.
	var progress := 0.0:
		set(value):
			progress = value
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 2.0 or h < 2.0:
			return
		var band := maxf(22.0, w * 0.14)
		var x := lerpf(-band, w + band * 0.35, clampf(progress, 0.0, 1.0))
		## Still-unwritten side stays dark so the line appears as the light passes.
		if x < w:
			draw_rect(Rect2(x, 0.0, w - x + 1.0, h), Color(0.04, 0.05, 0.04, 0.88))
		## Warm wash on the written side.
		if x > 0.0:
			draw_rect(Rect2(0.0, 0.0, mini(x, w), h), Color(1.0, 0.9, 0.42, 0.2))
		## Soft trail behind the leading edge.
		var trail_x := x - band
		if trail_x < w and x > 0.0:
			var trail := Rect2(maxf(trail_x, 0.0), 0.0, minf(band, x), h)
			draw_rect(trail, Color(1.0, 0.88, 0.4, 0.28))
		## Bright writing edge.
		var edge := Rect2(x - 5.0, 0.0, 10.0, h)
		draw_rect(edge, Color(1.0, 0.97, 0.72, 0.95))
		var core := Rect2(x - 2.0, 0.0, 4.0, h)
		draw_rect(core, Color(1.0, 1.0, 0.92, 1.0))


class PlaceHeader extends HBoxContainer:
	var place_id := ""
	var on_toggle: Callable

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton):
			return
		var mb := event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if on_toggle.is_valid():
			on_toggle.call(place_id)
		accept_event()


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
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_font(_title, true)
	add_child(_title)
	_page_mark = HBoxContainer.new()
	_page_mark.alignment = BoxContainer.ALIGNMENT_CENTER
	_page_mark.add_theme_constant_override("separation", 0)
	_page_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_num_1 = _make_page_mark_label("1")
	_page_sep = _make_page_mark_label(" / ")
	_page_num_2 = _make_page_mark_label("2")
	_page_mark.add_child(_page_num_1)
	_page_mark.add_child(_page_sep)
	_page_mark.add_child(_page_num_2)
	add_child(_page_mark)
	_pages = Control.new()
	_pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pages.clip_contents = true
	_pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pages)
	_page1 = VBoxContainer.new()
	_page1.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page1.add_theme_constant_override("separation", 6)
	_page1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pages.add_child(_page1)
	_scroll = Control.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.clip_contents = true
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.resized.connect(_fit_list_width)
	_page1.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_theme_constant_override("separation", ENTRY_GAP)
	_scroll.add_child(_list)
	_empty = Label.new()
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_theme_font_size_override("font_size", BODY_SIZE)
	_empty.add_theme_color_override("font_color", COL_EMPTY)
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_font(_empty)
	_page1.add_child(_empty)
	_page2 = ScrollContainer.new()
	_page2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page2.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_page2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pages.add_child(_page2)
	_codex = VBoxContainer.new()
	_codex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_codex.add_theme_constant_override("separation", 20)
	_page2.add_child(_codex)
	_page2.resized.connect(_fit_codex_width)
	_apply_page()
	if Engine.get_main_loop() != null:
		var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
		if gs != null and gs.has_signal("language_changed"):
			gs.language_changed.connect(
				func(_l: String) -> void: refresh(is_visible_in_tree())
			)
	refresh()


func is_browsing() -> bool:
	return _browsing


func begin_browse(current_place: String) -> void:
	_browsing = true
	_prepare_open_selection(current_place)
	refresh(true)


func prepare_session_selection(current_place: String) -> void:
	## First world load: current city's first note, else the top of the log.
	var gs = _game_state()
	if gs == null:
		return
	_set_page(0)
	_set_unseen_id(gs, "")
	var place := current_place.strip_edges().to_lower()
	var pick := ""
	if not place.is_empty():
		pick = _Journal.first_id_for_place(gs, place)
		if not pick.is_empty():
			_set_place_collapsed(gs, place, false)
	if pick.is_empty():
		pick = _Journal.first_place_key(gs)
	if not pick.is_empty():
		_set_selected_id(pick)


func end_browse() -> void:
	_browsing = false
	_apply_selection_visuals()


func turn_page(dir_x: int) -> bool:
	## Left / right flips between the notes page and the collection page.
	if dir_x == 0:
		return false
	var next := clampi(_current_page() + (1 if dir_x > 0 else -1), 0, PAGE_COUNT - 1)
	if next == _current_page():
		return false
	_set_page(next)
	return true


func move_selection(step: int) -> void:
	if _current_page() != 0:
		_scroll_codex(step)
		return
	if step == 0 or _nav_ids.is_empty():
		return
	var cur := _selected_id()
	var idx := _nav_ids.find(cur)
	if idx < 0:
		idx = 0 if step > 0 else _nav_ids.size() - 1
	else:
		idx = posmod(idx + step, _nav_ids.size())
	_select_nav_index(idx)


func jump_selection_home() -> void:
	if _current_page() != 0:
		_scroll_codex_to_edge(false)
		return
	if _nav_ids.is_empty():
		return
	_select_nav_index(0)


func jump_selection_end() -> void:
	if _current_page() != 0:
		_scroll_codex_to_edge(true)
		return
	if _nav_ids.is_empty():
		return
	_select_nav_index(_nav_ids.size() - 1)


func jump_selection_place(dir: int) -> void:
	## Page Up / Down — previous / next town header.
	if _current_page() != 0:
		_scroll_codex(dir)
		return
	if dir == 0 or _nav_ids.is_empty():
		return
	var places: Array[int] = []
	for i in _nav_ids.size():
		if _is_place_key(str(_nav_ids[i])):
			places.append(i)
	if places.is_empty():
		return
	var idx := _nav_ids.find(_selected_id())
	var slot := 0
	if idx >= 0:
		for i in places.size():
			if places[i] <= idx:
				slot = i
			else:
				break
	## Page Up from a note lands on this town's header first.
	if dir < 0 and idx > places[slot]:
		_select_nav_index(places[slot])
		return
	var next_slot := slot + dir
	if next_slot < 0 or next_slot >= places.size():
		return
	_select_nav_index(places[next_slot])


func _select_nav_index(idx: int) -> void:
	if idx < 0 or idx >= _nav_ids.size():
		return
	_set_selected_id(_nav_ids[idx])
	_apply_selection_visuals()
	_center_selected()
	_schedule_center()


func activate_selection() -> bool:
	## Enter / A on a city header toggles collapse.
	if _current_page() != 0:
		return false
	return _set_selected_place_collapsed(0)


func nudge_selected_place(dir_x: int) -> bool:
	## Left/right now turn journal pages. Header collapse stays on Enter / A.
	return turn_page(dir_x)


func recenter_selection() -> void:
	_schedule_center()


func refresh(journal_visible: bool = false) -> void:
	if _title == null:
		return
	_title.text = Locale.t("journal_title")
	_empty.text = Locale.t("journal_empty")
	_refresh_page_mark()
	_clear_list()
	_kill_flash()
	_flash_id = ""
	_entry_nodes.clear()
	_header_nodes.clear()
	_nav_ids.clear()
	var gs = _game_state()
	if gs != null:
		_Journal.mark_goals_for_inventory(gs)
	var groups := _Journal.grouped_for_ui(gs)
	var lang := "en_us"
	if gs != null:
		lang = str(gs.language)
	var has_any := not groups.is_empty()
	_empty.visible = not has_any
	_scroll.visible = has_any
	if not has_any:
		_rebuild_codex()
		_apply_page()
		return
	var collapsed := _collapsed_map(gs)
	for group in groups:
		var place := str(group.get("place", ""))
		var rows: Array = group.get("entries", [])
		if rows.is_empty():
			continue
		var is_collapsed := bool(collapsed.get(place, false))
		var header := _make_place_header(place, is_collapsed)
		var place_key := _place_key(place)
		_header_nodes[place_key] = header
		_nav_ids.append(place_key)
		_list.add_child(header)
		if is_collapsed:
			continue
		for i in rows.size():
			var row: Variant = rows[i]
			if typeof(row) != TYPE_DICTIONARY:
				continue
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
			var entry := _make_entry_row(d, lang, connect_above, connect_below)
			var id := str(d.get("id", "")).strip_edges()
			if not id.is_empty():
				_entry_nodes[id] = entry
				_nav_ids.append(id)
			_list.add_child(entry)
	_sync_list_min_size()
	_reveal_unseen_if_visible(gs, journal_visible)
	_normalize_selection(gs)
	_rebuild_codex()
	_apply_page()
	_apply_selection_visuals()
	_schedule_center()


func _prepare_open_selection(current_place: String) -> void:
	## Unseen new rows jump once; otherwise keep the last cursor.
	var gs = _game_state()
	if gs == null:
		return
	var unseen := _unseen_id(gs)
	if not unseen.is_empty() and not _Journal.place_for_entry_id(gs, unseen).is_empty():
		_set_page(0)
		_set_selected_id(unseen)
		return
	if not _selected_id().is_empty():
		return
	var place := current_place.strip_edges().to_lower()
	var pick := _Journal.latest_id_for_place(gs, place)
	if pick.is_empty():
		pick = _Journal.last_acquired_id(gs)
	if not pick.is_empty():
		_set_selected_id(pick)


func _reveal_unseen_if_visible(gs: Node, journal_visible: bool) -> void:
	if gs == null or not journal_visible:
		return
	var unseen := _unseen_id(gs)
	if unseen.is_empty():
		return
	if _Journal.place_for_entry_id(gs, unseen).is_empty() and not _nav_ids.has(unseen):
		_set_unseen_id(gs, "")
		return
	_set_page(0)
	_set_selected_id(unseen)
	_flash_id = unseen
	_set_unseen_id(gs, "")


func _normalize_selection(gs: Node) -> void:
	if gs == null or _nav_ids.is_empty():
		return
	var cur := _selected_id()
	if _nav_ids.has(cur):
		return
	if _is_place_key(cur):
		if _browsing:
			_set_selected_id(_nav_ids[0])
		return
	var host := _Journal.place_for_entry_id(gs, cur)
	if not host.is_empty():
		var pk := _place_key(host)
		if _nav_ids.has(pk):
			_set_selected_id(pk)
			return
	if _browsing:
		_set_selected_id(_nav_ids[_nav_ids.size() - 1])


func _on_place_toggled(place_id: String) -> void:
	var gs = _game_state()
	if gs == null or place_id.is_empty():
		return
	var next_collapsed := not bool(_collapsed_map(gs).get(place_id, false))
	_set_place_collapsed(gs, place_id, next_collapsed)
	_set_selected_id(_place_key(place_id))
	refresh(is_visible_in_tree())


func _set_selected_place_collapsed(mode: int) -> bool:
	## mode: 0 toggle, -1 collapse, +1 expand.
	var gs = _game_state()
	var cur := _selected_id()
	if gs == null or not _is_place_key(cur):
		return false
	var place := _place_from_key(cur)
	if place.is_empty():
		return false
	var collapsed := bool(_collapsed_map(gs).get(place, false))
	var next := collapsed
	if mode < 0:
		next = true
	elif mode > 0:
		next = false
	else:
		next = not collapsed
	if next == collapsed:
		return true
	_set_place_collapsed(gs, place, next)
	refresh(is_visible_in_tree())
	return true


func _make_place_header(place_id: String, collapsed: bool) -> Control:
	var wrap := PanelContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := PlaceHeader.new()
	row.place_id = place_id
	row.on_toggle = _on_place_toggled
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	var lab := Label.new()
	lab.text = Locale.place(place_id)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.add_theme_font_size_override("font_size", PLACE_SIZE)
	lab.add_theme_color_override("font_color", COL_PLACE)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_font(lab, true)
	row.add_child(lab)
	var mark := Label.new()
	mark.text = "+" if collapsed else "-"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mark.add_theme_font_size_override("font_size", PLACE_SIZE)
	mark.add_theme_color_override("font_color", COL_PLACE)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_font(mark, true)
	row.add_child(mark)
	wrap.add_child(row)
	return wrap


func _make_entry_row(
	row: Dictionary,
	lang: String,
	connect_above: bool,
	connect_below: bool
) -> Control:
	var root := PanelContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner := HBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 6)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(inner)
	var status := StatusIcon.new()
	status.texture = _done_tex if bool(row.get("done", false)) else _pending_tex
	status.connect_above = connect_above
	status.connect_below = connect_below
	inner.add_child(status)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	inner.add_child(col)
	var body := Label.new()
	body.text = _Journal.entry_text(row, lang, _game_state())
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", BODY_SIZE)
	body.add_theme_color_override("font_color", COL_BODY)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_font(meta)
	col.add_child(meta)
	return root


func _apply_selection_visuals() -> void:
	var cur := _selected_id()
	for id in _entry_nodes.keys():
		var node: Variant = _entry_nodes[id]
		if not (node is PanelContainer) or not is_instance_valid(node):
			continue
		var panel := node as PanelContainer
		var selected := str(id) == cur
		panel.add_theme_stylebox_override("panel", _entry_style(selected))
		_tint_entry_body(panel, selected)
	for key in _header_nodes.keys():
		var hnode: Variant = _header_nodes[key]
		if not (hnode is PanelContainer) or not is_instance_valid(hnode):
			continue
		var header := hnode as PanelContainer
		var selected_h := str(key) == cur
		header.add_theme_stylebox_override("panel", _entry_style(selected_h))
		_tint_place_header(header, selected_h)


func _tint_entry_body(panel: PanelContainer, selected: bool) -> void:
	if panel.get_child_count() < 1:
		return
	var inner := panel.get_child(0)
	if inner.get_child_count() < 2:
		return
	var col := inner.get_child(1)
	if col.get_child_count() < 1:
		return
	var body := col.get_child(0)
	if body is Label:
		(body as Label).add_theme_color_override(
			"font_color",
			COL_BODY_SEL if selected else COL_BODY
		)


func _entry_style(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	if selected:
		box.bg_color = COL_SEL_FOCUS if _browsing else COL_SEL_IDLE
	box.content_margin_left = 2
	box.content_margin_right = 2
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box


func _schedule_center() -> void:
	_center_token += 1
	var token := _center_token
	_center_selected_async(token)


func _center_selected_async(token: int) -> void:
	await get_tree().process_frame
	if token != _center_token or not is_inside_tree():
		return
	await get_tree().process_frame
	if token != _center_token or not is_inside_tree():
		return
	_center_selected()
	if not _flash_id.is_empty():
		var fid := _flash_id
		_flash_id = ""
		_flash_row(fid)


func _center_selected() -> void:
	## Keep the focused note on the middle of the pane, like the gamepad menu.
	if _current_page() != 0:
		return
	if _scroll == null or _list == null:
		return
	var node := _selected_row_node()
	if node == null:
		return
	_sync_list_min_size()
	var view_h := _scroll.size.y
	if view_h < 8.0:
		return
	var row_h := node.get_combined_minimum_size().y
	if row_h < 1.0:
		row_h = node.size.y
	if row_h < 1.0:
		return
	var row_y := _journal_offset_of(node)
	## Center ordinary rows, but pin the list to its top/bottom at either end.
	var target_y := view_h * 0.5 - (row_y + row_h * 0.5)
	var content_h := maxf(_list.custom_minimum_size.y, _list.size.y)
	var bottom_y := minf(0.0, view_h - content_h)
	_list.position = Vector2(0.0, clampf(target_y, bottom_y, 0.0))


func _selected_row_node() -> Control:
	var cur := _selected_id()
	var node: Control = _entry_nodes.get(cur, null) as Control
	if node == null:
		node = _header_nodes.get(cur, null) as Control
	if node == null or not is_instance_valid(node):
		return null
	return node


func _journal_offset_of(node: Control) -> float:
	var y := 0.0
	var sep := float(ENTRY_GAP)
	for i in _list.get_child_count():
		var child := _list.get_child(i) as Control
		if child == null:
			continue
		if child == node:
			return y
		var h := child.get_combined_minimum_size().y
		if h < 1.0:
			h = child.size.y
		y += maxf(h, 1.0) + sep
	return node.position.y


func _pin_wrap_width(node: Control, w: float) -> void:
	if node is Label:
		var lab := node as Label
		if lab.autowrap_mode != TextServer.AUTOWRAP_OFF:
			lab.custom_minimum_size.x = maxf(w, 8.0)
		return
	for child in node.get_children():
		if not (child is Control):
			continue
		var next_w := w
		if node is HBoxContainer and child is VBoxContainer:
			next_w = maxf(w - float(ICON_PX) - 16.0, 8.0)
		_pin_wrap_width(child as Control, next_w)


func _sync_list_min_size() -> void:
	## Autowrap notes only get a real height after the list has a width.
	if _list == null or _scroll == null:
		return
	var w := _scroll.size.x
	if w < 8.0:
		return
	_list.custom_minimum_size.x = w
	for child in _list.get_children():
		if child is Control:
			(child as Control).custom_minimum_size.x = w
			_pin_wrap_width(child as Control, w)
	var h := 0.0
	var sep := float(ENTRY_GAP)
	var kids := _list.get_child_count()
	for i in kids:
		var child := _list.get_child(i) as Control
		if child == null:
			continue
		var ch := child.get_combined_minimum_size().y
		if ch < 1.0:
			ch = child.size.y
		h += maxf(ch, 1.0)
		if i < kids - 1:
			h += sep
	_list.custom_minimum_size.y = h
	_list.size = Vector2(w, h)


func _fit_list_width() -> void:
	_sync_list_min_size()
	if _current_page() == 0:
		_center_selected()


func _fit_codex_width() -> void:
	if _codex == null or _page2 == null:
		return
	var w := _page2.size.x
	if w > 1.0:
		_codex.custom_minimum_size.x = w


func _scroll_codex(step: int) -> void:
	## Page 2 has no fold / cursor — up/down just walks the list.
	if _page2 == null or _codex == null or step == 0:
		return
	var view_h := _page2.size.y
	if view_h < 8.0:
		return
	var max_scroll := maxf(_codex.size.y - view_h, 0.0)
	if max_scroll <= 0.0:
		return
	var jump := maxf(CODEX_CELL_H + 10.0, view_h * 0.28)
	_page2.scroll_vertical = clampi(
		_page2.scroll_vertical + int(round(jump * step)),
		0,
		int(round(max_scroll))
	)


func _scroll_codex_to_edge(to_end: bool) -> void:
	if _page2 == null or _codex == null:
		return
	var view_h := _page2.size.y
	var max_scroll := maxf(_codex.size.y - view_h, 0.0)
	_page2.scroll_vertical = int(round(max_scroll)) if to_end else 0


func _rebuild_codex() -> void:
	if _codex == null:
		return
	for c in _codex.get_children():
		_codex.remove_child(c)
		c.free()
	var gs = _game_state()
	if gs == null:
		return
	var virtues := _Journal.known_virtue_mask(gs)
	var dungeons := _Journal.known_dungeon_mask(gs)
	var mantras := _Journal.known_mantra_mask(gs)
	var runes := int(gs.runes)
	var stones := _Journal.known_stone_mask(gs)
	var city_cols := (
		int(gs.journal_known_cities)
		| int(gs.journal_known_city_moons)
		| dungeons
		| mantras
		| stones
		| runes
	)
	if city_cols != 0:
		_codex_add_section("journal_codex_cities", _codex_city_block(gs, city_cols))
	if virtues != 0:
		_codex_add_section("journal_codex_virtues", _codex_virtue_row(virtues, gs))
	var principles := _Journal.known_principle_mask(gs)
	if principles != 0:
		_codex_add_section("journal_codex_principles", _codex_principle_row(principles))
	if dungeons != 0:
		_codex_add_section("journal_codex_dungeons", _codex_dungeon_row(dungeons))
	if mantras != 0:
		_codex_add_section("journal_codex_mantras", _codex_mantra_row(mantras))
	if stones != 0:
		_codex_add_section("journal_codex_stones", _codex_stone_row(gs, stones))
	if runes != 0:
		_codex_add_section("journal_codex_runes", _codex_rune_row(runes, gs))
	var relic_flags := [gs.ITEM_BELL, gs.ITEM_BOOK, gs.ITEM_CANDLE]
	var relic_paths := [
		_SpecialItemIcons.BELL,
		_SpecialItemIcons.BOOK,
		_SpecialItemIcons.CANDLE,
	]
	var relic_labels := [
		"journal_codex_bell",
		"journal_codex_book",
		"journal_codex_candle",
	]
	var any_relic := false
	for flag in relic_flags:
		if gs.has_item_flag(int(flag)):
			any_relic = true
			break
	if any_relic:
		_codex_add_section(
			"journal_codex_relics",
			_codex_key_row(gs, relic_flags, relic_paths, relic_labels)
		)
	var key_flags := [
		gs.ITEM_KEY_T,
		gs.ITEM_KEY_L,
		gs.ITEM_KEY_C,
	]
	var key_paths := [
		_SpecialItemIcons.KEY_TRUTH,
		_SpecialItemIcons.KEY_LOVE,
		_SpecialItemIcons.KEY_COURAGE,
	]
	var key_labels := [
		"journal_codex_truth",
		"journal_codex_love",
		"journal_codex_courage",
	]
	var any_key := false
	for flag in key_flags:
		if gs.has_item_flag(int(flag)):
			any_key = true
			break
	if any_key:
		_codex_add_section(
			"journal_codex_keys",
			_codex_key_row(gs, key_flags, key_paths, key_labels)
		)
	_fit_codex_width()


func _codex_add_section(title_key: String, body: Control) -> void:
	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_theme_constant_override("separation", 2)
	block.add_child(_codex_header(title_key))
	block.add_child(body)
	_codex.add_child(block)


func _codex_header(key: String) -> Label:
	var lab := Label.new()
	lab.text = Locale.t(key)
	lab.add_theme_font_size_override("font_size", CODEX_HEAD_SIZE)
	lab.add_theme_color_override("font_color", COL_PLACE)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_font(lab, true)
	return lab


func _codex_slot_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2)
	return row


func _codex_empty_cell() -> Control:
	var cell := Control.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.custom_minimum_size = Vector2(0, CODEX_CELL_H)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cell


func _moon_file_index(phase: int) -> int:
	## Same mapping as the sky bar: phase 0 → new-moon art.
	phase = posmod(phase, 8)
	if phase == 0:
		return MOON_NEW_FILE
	return phase - 1


func _codex_city_block(gs: Node, show_mask: int) -> Control:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_theme_constant_override("separation", 2)
	var moons := _codex_slot_row()
	var names := _codex_slot_row()
	var moon_mask := int(gs.journal_known_city_moons)
	for i in 8:
		if (show_mask & (1 << i)) == 0:
			moons.add_child(_codex_empty_cell())
			names.add_child(_codex_empty_cell())
			continue
		var moon_on := (moon_mask & (1 << i)) != 0
		var moon_file := _moon_file_index(i) if moon_on else MOON_NEW_FILE
		moons.add_child(_codex_icon_cell(MOON_PHASE_PATH % moon_file))
		var place := str(_WorldPortals.JOURNAL_TOWNS[i])
		names.add_child(_codex_text_cell(_WorldPortals.town_abbrev(place)))
	wrap.add_child(moons)
	wrap.add_child(names)
	return wrap


func _codex_principle_row(mask: int) -> HBoxContainer:
	var row := _codex_slot_row()
	const KEYS := ["journal_codex_truth", "journal_codex_love", "journal_codex_courage"]
	for i in KEYS.size():
		if (mask & (1 << i)) == 0:
			row.add_child(_codex_empty_cell())
		else:
			row.add_child(_codex_text_cell(Locale.t(str(KEYS[i]))))
	return row


func _codex_virtue_row(mask: int, gs: Node) -> HBoxContainer:
	var row := _codex_slot_row()
	var lang := "en"
	if gs != null:
		lang = gs.lang_short()
	for i in 8:
		if (mask & (1 << i)) == 0:
			row.add_child(_codex_empty_cell())
			continue
		row.add_child(_codex_text_cell(_Virtues.name_of(i, lang)))
	return row


func _codex_dungeon_row(mask: int) -> HBoxContainer:
	var row := _codex_slot_row()
	for i in 8:
		if (mask & (1 << i)) == 0:
			row.add_child(_codex_empty_cell())
			continue
		row.add_child(_codex_text_cell(Locale.place(str(CODEX_DUNGEONS[i]))))
	return row


func _codex_mantra_row(mask: int) -> HBoxContainer:
	var row := _codex_slot_row()
	for i in 8:
		if (mask & (1 << i)) == 0:
			row.add_child(_codex_empty_cell())
			continue
		row.add_child(_codex_text_cell(_Shrine.mantra_of(i).to_upper()))
	return row


func _codex_icon_row(mask: int, is_rune: bool) -> HBoxContainer:
	var row := _codex_slot_row()
	for i in 8:
		if (mask & (1 << i)) == 0:
			row.add_child(_codex_empty_cell())
			continue
		var path := _RuneIcons.path_for_id(i) if is_rune else _SpecialItemIcons.stone_path(i)
		row.add_child(_codex_icon_cell(path))
	return row


func _codex_rune_row(mask: int, gs: Node) -> HBoxContainer:
	var row := _codex_slot_row()
	var lang := "en"
	if gs != null:
		lang = gs.lang_short()
	for i in 8:
		if (mask & (1 << i)) == 0:
			row.add_child(_codex_empty_cell())
			continue
		row.add_child(_codex_labeled_icon_cell(
			_RuneIcons.path_for_id(i),
			_Virtues.name_of(i, lang)
		))
	return row


func _codex_stone_row(gs: Node, mask: int) -> HBoxContainer:
	var row := _codex_slot_row()
	var owned := 0
	if gs != null:
		owned = int(gs.stones)
	for i in 8:
		if (mask & (1 << i)) == 0:
			row.add_child(_codex_empty_cell())
			continue
		var label := Locale.t(str(CODEX_STONE_KEYS[i]))
		var path := ""
		if (owned & (1 << i)) != 0:
			path = _SpecialItemIcons.stone_path(i)
		row.add_child(_codex_labeled_icon_cell(path, label))
	return row


func _codex_key_row(
	gs: Node, flags: Array, paths: Array, labels: Array
) -> HBoxContainer:
	var row := _codex_slot_row()
	for i in flags.size():
		if not gs.has_item_flag(int(flags[i])):
			row.add_child(_codex_empty_cell())
			continue
		row.add_child(_codex_labeled_icon_cell(str(paths[i]), Locale.t(str(labels[i]))))
	return row


func _codex_labeled_icon_cell(path: String, label: String) -> Control:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_constant_override("separation", CODEX_ICON_LABEL_GAP)
	var wrap := CenterContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(_codex_icon_rect(path))
	cell.add_child(wrap)
	var lab := Label.new()
	lab.text = label
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	lab.clip_text = true
	lab.add_theme_font_size_override("font_size", CODEX_NAME_SIZE)
	lab.add_theme_color_override("font_color", COL_BODY)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_font(lab, true)
	cell.add_child(lab)
	return cell


func _codex_text_cell(text: String) -> Control:
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	lab.clip_text = true
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.custom_minimum_size = Vector2(0, CODEX_CELL_H)
	lab.add_theme_font_size_override("font_size", CODEX_NAME_SIZE)
	lab.add_theme_color_override("font_color", COL_BODY)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_font(lab, true)
	return lab


func _codex_icon_cell(path: String) -> Control:
	var cell := CenterContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.custom_minimum_size = Vector2(0, CODEX_CELL_H)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(_codex_icon_rect(path))
	return cell


func _codex_icon_rect(path: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(CODEX_ICON, CODEX_ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not path.is_empty() and ResourceLoader.exists(path):
		icon.texture = load(path) as Texture2D
	return icon


func _clear_list() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.free()


func _current_page() -> int:
	var gs = _game_state()
	if gs == null:
		return 0
	return clampi(int(gs.journal_page), 0, PAGE_COUNT - 1)


func _set_page(page: int) -> void:
	var gs = _game_state()
	var next := clampi(page, 0, PAGE_COUNT - 1)
	if gs != null:
		gs.journal_page = next
		if next == 1:
			_Journal.clear_codex_unseen(gs)
	_apply_page()
	if next == 0:
		_schedule_center()


func _apply_page() -> void:
	var page := _current_page()
	if _page1 != null:
		_page1.visible = page == 0
	if _page2 != null:
		_page2.visible = page == 1
	_refresh_page_mark()


func _make_page_mark_label(text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", META_SIZE)
	lab.add_theme_color_override("font_color", COL_META)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_font(lab)
	return lab


func _refresh_page_mark() -> void:
	if _page_num_1 == null or _page_num_2 == null:
		return
	var gs = _game_state()
	var page := _current_page()
	if page == 1:
		_Journal.clear_codex_unseen(gs)
	var unseen := gs != null and bool(gs.journal_codex_unseen)
	_page_num_1.add_theme_color_override("font_color", COL_TITLE if page == 0 else COL_META)
	_page_sep.add_theme_color_override("font_color", COL_META)
	if unseen and page != 1:
		_page_num_2.add_theme_color_override("font_color", COL_PAGE_NEW)
	else:
		_page_num_2.add_theme_color_override("font_color", COL_TITLE if page == 1 else COL_META)


func _selected_id() -> String:
	var gs = _game_state()
	if gs == null:
		return ""
	return str(gs.journal_selected_id).strip_edges()


func _set_selected_id(id: String) -> void:
	var gs = _game_state()
	if gs == null:
		return
	gs.journal_selected_id = id.strip_edges()


func _unseen_id(gs: Node) -> String:
	if gs == null:
		return ""
	return str(gs.journal_unseen_id).strip_edges()


func _set_unseen_id(gs: Node, id: String) -> void:
	if gs == null:
		return
	gs.journal_unseen_id = id.strip_edges()


func _place_key(place_id: String) -> String:
	return PLACE_PREFIX + place_id.strip_edges().to_lower()


func _is_place_key(key: String) -> bool:
	return key.begins_with(PLACE_PREFIX)


func _place_from_key(key: String) -> String:
	if not _is_place_key(key):
		return ""
	return key.substr(PLACE_PREFIX.length())


func _tint_place_header(panel: PanelContainer, selected: bool) -> void:
	if panel.get_child_count() < 1:
		return
	var row := panel.get_child(0)
	for child in row.get_children():
		if child is Label:
			(child as Label).add_theme_color_override(
				"font_color",
				COL_PLACE_SEL if selected else COL_PLACE
			)


func _kill_flash() -> void:
	if _flash_tween != null and is_instance_valid(_flash_tween):
		_flash_tween.kill()
	_flash_tween = null
	if _flash_overlay != null and is_instance_valid(_flash_overlay):
		_flash_overlay.queue_free()
	_flash_overlay = null


func _flash_row(id: String) -> void:
	var node: Control = _entry_nodes.get(id, null) as Control
	if node == null or not is_instance_valid(node):
		return
	_kill_flash()
	var sweep := WriteSweep.new()
	sweep.progress = 0.0
	node.add_child(sweep)
	_flash_overlay = sweep
	_flash_tween = create_tween()
	_flash_tween.set_trans(Tween.TRANS_CUBIC)
	_flash_tween.set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(sweep, "progress", 1.0, SWEEP_SEC)
	_flash_tween.tween_property(sweep, "modulate:a", 0.0, 0.22)
	_flash_tween.tween_callback(func() -> void:
		if sweep != null and is_instance_valid(sweep):
			sweep.queue_free()
		if _flash_overlay == sweep:
			_flash_overlay = null
	)


func _collapsed_map(gs: Node) -> Dictionary:
	if gs == null:
		return {}
	var raw: Variant = gs.journal_collapsed
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw as Dictionary


func _set_place_collapsed(gs: Node, place_id: String, collapsed: bool) -> void:
	if gs == null or place_id.is_empty():
		return
	var cur: Dictionary = _collapsed_map(gs).duplicate()
	if collapsed:
		cur[place_id] = true
	else:
		cur.erase(place_id)
	gs.journal_collapsed = cur


func _game_state() -> Node:
	if Engine.get_main_loop() == null:
		return null
	return Engine.get_main_loop().root.get_node_or_null("/root/GameState")
