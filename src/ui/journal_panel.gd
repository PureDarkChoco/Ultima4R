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
const COL_BODY_SEL := Color(1.0, 0.98, 0.86, 1)
## Speaker · time — half body size, muted gray.
const COL_META := Color(0.52, 0.55, 0.52, 1)
const COL_EMPTY := Color(0.55, 0.62, 0.58, 1)
const COL_SEL_IDLE := Color(0.95, 0.88, 0.55, 0.14)
const COL_SEL_FOCUS := Color(0.98, 0.9, 0.5, 0.28)
const COL_PLACE_SEL := Color(0.98, 0.92, 0.62, 1)
const PLACE_PREFIX := "place:"
const SWEEP_SEC := 0.62

var _title: Label
var _scroll: ScrollContainer
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
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.resized.connect(_fit_list_width)
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	add_child(_empty)
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


func end_browse() -> void:
	_browsing = false
	_apply_selection_visuals()


func move_selection(step: int) -> void:
	if step == 0 or _nav_ids.is_empty():
		return
	var cur := _selected_id()
	var idx := _nav_ids.find(cur)
	if idx < 0:
		idx = 0 if step > 0 else _nav_ids.size() - 1
	else:
		idx = posmod(idx + step, _nav_ids.size())
	_set_selected_id(_nav_ids[idx])
	_apply_selection_visuals()
	_schedule_center()


func activate_selection() -> bool:
	## Enter / A on a city header toggles collapse.
	return _set_selected_place_collapsed(0)


func nudge_selected_place(dir_x: int) -> bool:
	## Left collapses a focused city header; right expands it.
	if dir_x == 0:
		return false
	return _set_selected_place_collapsed(-1 if dir_x < 0 else 1)


func recenter_selection() -> void:
	_schedule_center()


func refresh(journal_visible: bool = false) -> void:
	if _title == null:
		return
	_title.text = Locale.t("journal_title")
	_empty.text = Locale.t("journal_empty")
	_clear_list()
	_kill_flash()
	_flash_id = ""
	_entry_nodes.clear()
	_header_nodes.clear()
	_nav_ids.clear()
	var gs = _game_state()
	var groups := _Journal.grouped_for_ui(gs)
	var lang := "en_us"
	if gs != null:
		lang = str(gs.language)
	var has_any := not groups.is_empty()
	_empty.visible = not has_any
	_scroll.visible = has_any
	if not has_any:
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
	_fit_list_width()
	_reveal_unseen_if_visible(gs, journal_visible)
	_normalize_selection(gs)
	_apply_selection_visuals()
	_schedule_center()


func _prepare_open_selection(current_place: String) -> void:
	## Unseen new rows jump once; otherwise keep the last cursor.
	var gs = _game_state()
	if gs == null:
		return
	var unseen := _unseen_id(gs)
	if not unseen.is_empty() and not _Journal.place_for_entry_id(gs, unseen).is_empty():
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
	body.text = _Journal.entry_text(row, lang)
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
	if _scroll == null or _list == null:
		return
	var cur := _selected_id()
	var node: Control = _entry_nodes.get(cur, null) as Control
	if node == null:
		node = _header_nodes.get(cur, null) as Control
	if node == null or not is_instance_valid(node):
		return
	var view_h := _scroll.size.y
	if view_h < 8.0:
		return
	var row_y := node.position.y
	var row_h := node.size.y
	var target := row_y + row_h * 0.5 - view_h * 0.5
	var max_scroll := maxf(_list.size.y - view_h, 0.0)
	_scroll.scroll_vertical = clampi(int(round(target)), 0, int(round(max_scroll)))


func _fit_list_width() -> void:
	if _list == null or _scroll == null:
		return
	var w := _scroll.size.x
	if w > 1.0:
		_list.custom_minimum_size.x = w


func _clear_list() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.free()


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
