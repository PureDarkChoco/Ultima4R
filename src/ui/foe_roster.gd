class_name FoeRoster
extends VBoxContainer

## Combat left panel: foes in xu4 creatureTable slot order (priority 0 first).
## Row: creature tile | name | HP bar (gray until first hit, then cur / max).

const _U4TileBankScript := preload("res://src/map/u4_tile_bank.gd")
const _WorldCreaturesScript := preload("res://src/map/world_creatures.gd")

const MAX_FOES := 16
const ICON_SIZE := 28
const BAR_H := 14
const BAR_MIN_W := 40.0
const NAME_BAR_GAP := 6.0
const ROSTER_STYLE_PAD := 4
const ROSTER_MARGIN_PAD := 6

const COL_TEXT := Color(0.95, 0.9, 0.72, 1)
const COL_BAR_TEXT := Color(0.95, 0.95, 0.95, 1)
const COL_TRACK := Color(0.22, 0.22, 0.22, 1)
const COL_HP := Color(0.82, 0.22, 0.2, 1)
## Attack-aim hover (party order cursor, but red).
const COL_AIM_CURSOR := Color(0.72, 0.18, 0.16, 0.55)
const COL_AIM_CURSOR_EDGE := Color(1.0, 0.42, 0.35, 0.95)

var _icons: Array[TextureRect] = []
var _names: Array[Label] = []
var _hp_track: Array[Control] = []
var _hp_fill: Array[ColorRect] = []
var _hp_lab: Array[Label] = []
var _row_panels: Array[PanelContainer] = []
var _rows: Array[Control] = []
var _foes: Array[Dictionary] = []
var _anim_tick: int = 0
var _anim_cd: float = 0.0
var _tile_aspect: float = 1.0
var _open_outer_h: float = 0.0
var _relayouting: bool = false
## creatureTable slot under the aim cursor (−1 = none).
var _aim_slot := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 2)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_slots()
	resized.connect(_on_resized)
	set_process(true)
	clear()


func _process(delta: float) -> void:
	if not visible or _foes.is_empty():
		return
	_anim_cd -= delta
	if _anim_cd > 0.0:
		return
	_anim_cd = 0.25
	_anim_tick += 1
	_refresh_icons()


func apply_shared_pad_to_margins(margin: MarginContainer) -> void:
	if margin == null:
		return
	margin.add_theme_constant_override("margin_left", ROSTER_MARGIN_PAD)
	margin.add_theme_constant_override("margin_top", ROSTER_MARGIN_PAD)
	margin.add_theme_constant_override("margin_right", ROSTER_MARGIN_PAD)
	margin.add_theme_constant_override("margin_bottom", ROSTER_MARGIN_PAD)


func set_tile_size(px: Vector2) -> void:
	if px.x < 1.0 or px.y < 1.0:
		return
	var a := px.x / px.y
	if is_equal_approx(a, _tile_aspect):
		return
	_tile_aspect = a
	if is_inside_tree():
		relayout()


func set_open_panel_height(outer_h: float) -> void:
	## Match party roster band height so row pitch aligns across the map.
	if outer_h < 8.0:
		return
	if is_equal_approx(_open_outer_h, outer_h):
		return
	_open_outer_h = outer_h
	if is_inside_tree():
		relayout()


func clear() -> void:
	_foes.clear()
	_aim_slot = -1
	_apply_foes_to_rows()
	_apply_aim_highlight()
	visible = false


func get_ordered_foes() -> Array[Dictionary]:
	## Living foes in left-panel order (priority, then top-left).
	var out: Array[Dictionary] = []
	for d in _foes:
		out.append(d.duplicate(true))
	return out


func set_aim_highlight_slot(slot: int) -> void:
	## Highlight the roster row for this creatureTable slot (red aim cursor).
	if _aim_slot == slot:
		return
	_aim_slot = slot
	_apply_aim_highlight()


func clear_aim_highlight() -> void:
	if _aim_slot < 0:
		return
	_aim_slot = -1
	_apply_aim_highlight()


func set_foes(foes: Array) -> void:
	## Expect [{tile, hp, max_hp, priority/slot, show_hp, ...}]. Sorted by priority (asc).
	_foes.clear()
	var tmp: Array[Dictionary] = []
	for u in foes:
		if typeof(u) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = (u as Dictionary).duplicate(true)
		if int(d.get("tile", -1)) < 0:
			continue
		if int(d.get("hp", 1)) <= 0:
			continue
		tmp.append(d)
	tmp.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := int(a.get("priority", a.get("slot", 99)))
		var pb := int(b.get("priority", b.get("slot", 99)))
		if pa != pb:
			return pa < pb
		## Tie-break: top-left on the arena.
		var ya := int(a.get("y", 0))
		var yb := int(b.get("y", 0))
		if ya != yb:
			return ya < yb
		return int(a.get("x", 0)) < int(b.get("x", 0))
	)
	for d in tmp:
		_foes.append(d)
		if _foes.size() >= MAX_FOES:
			break
	_apply_foes_to_rows()
	visible = not _foes.is_empty()
	relayout()
	_apply_aim_highlight()


func refresh() -> void:
	_apply_foes_to_rows()
	relayout()
	_apply_aim_highlight()


func relayout() -> void:
	_distribute_rows()
	call_deferred("_relayout_bars")


func _on_resized() -> void:
	if _relayouting:
		return
	_relayouting = true
	_distribute_rows()
	_relayout_bars()
	_relayouting = false


func _build_slots() -> void:
	for c in get_children():
		c.queue_free()
	_icons.clear()
	_names.clear()
	_hp_track.clear()
	_hp_fill.clear()
	_hp_lab.clear()
	_row_panels.clear()
	_rows.clear()

	for i in MAX_FOES:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.visible = false
		panel.add_theme_stylebox_override("panel", _aim_row_style(-1, i))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var portrait := Control.new()
		portrait.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var icon := TextureRect.new()
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		## Fill host sized to map tile aspect (8.75:10) — not source 1:1.
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.add_child(icon)

		var name := Label.new()
		name.custom_minimum_size = Vector2(52, 0)
		name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		name.add_theme_font_size_override("font_size", 12)
		name.add_theme_color_override("font_color", COL_TEXT)
		UiTheme.apply_font(name)
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var name_gap := Control.new()
		name_gap.custom_minimum_size = Vector2(NAME_BAR_GAP, 0)
		name_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var bar := _make_bar()

		row.add_child(portrait)
		row.add_child(name)
		row.add_child(name_gap)
		row.add_child(bar["track"])
		panel.add_child(row)
		add_child(panel)

		_row_panels.append(panel)
		_rows.append(panel)
		_icons.append(icon)
		_names.append(name)
		_hp_track.append(bar["track"])
		_hp_fill.append(bar["fill"])
		_hp_lab.append(bar["lab"])


func _make_bar() -> Dictionary:
	var track := Control.new()
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.custom_minimum_size = Vector2(BAR_MIN_W, BAR_H)
	track.clip_contents = true
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = COL_TRACK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.add_child(bg)

	var fill := ColorRect.new()
	fill.color = COL_HP
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2.ZERO
	track.add_child(fill)

	var lab := Label.new()
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 9)
	lab.add_theme_color_override("font_color", COL_BAR_TEXT)
	UiTheme.apply_font(lab)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.add_child(lab)

	track.resized.connect(func() -> void: _apply_fill_width(fill))
	return {"track": track, "fill": fill, "lab": lab}


func _apply_foes_to_rows() -> void:
	if _names.is_empty():
		return
	for i in MAX_FOES:
		var filled := i < _foes.size()
		if i < _rows.size() and _rows[i]:
			_rows[i].visible = filled
		if not filled:
			if i < _icons.size() and _icons[i]:
				_icons[i].texture = null
			continue
		var d: Dictionary = _foes[i]
		var tid := int(d.get("tile", 0))
		_names[i].text = _WorldCreaturesScript.display_name(tid)
		_names[i].add_theme_color_override("font_color", COL_TEXT)
		var hp := int(d.get("hp", 0))
		var mhp := maxi(1, int(d.get("max_hp", hp)))
		## Hidden until first successful hit (`show_hp` set by MapView.damage_combat_foe).
		var revealed := bool(d.get("show_hp", false))
		_set_bar(_hp_fill[i], _hp_lab[i], hp, mhp, revealed)
	_refresh_icons()


func _refresh_icons() -> void:
	if not _U4TileBankScript.ensure_loaded():
		return
	for i in mini(_foes.size(), MAX_FOES):
		var tid := int(_foes[i].get("tile", 0))
		var paint := _WorldCreaturesScript.resolve_paint_tile(tid, _anim_tick)
		var slice: Image = _U4TileBankScript.keyed_copy(paint)
		if slice == null or slice.is_empty():
			continue
		_icons[i].texture = ImageTexture.create_from_image(slice)


func _set_bar(fill: ColorRect, lab: Label, cur: int, mx: int, revealed: bool = true) -> void:
	if not revealed:
		## Gray track only — no fill and no numbers until the foe is hit.
		lab.text = ""
		fill.set_meta("ratio", 0.0)
		fill.color = COL_HP
		_apply_fill_width(fill)
		return
	lab.text = "%d / %d" % [cur, mx]
	var ratio := 0.0 if mx <= 0 else clampf(float(cur) / float(mx), 0.0, 1.0)
	fill.set_meta("ratio", ratio)
	fill.color = COL_HP
	_apply_fill_width(fill)


func _apply_fill_width(fill: ColorRect) -> void:
	if fill == null or fill.get_parent() == null:
		return
	var track := fill.get_parent() as Control
	var ratio := float(fill.get_meta("ratio", 0.0))
	fill.size = Vector2(track.size.x * ratio, track.size.y)


func _relayout_bars() -> void:
	for fill in _hp_fill:
		_apply_fill_width(fill)


func _distribute_rows() -> void:
	if _rows.is_empty():
		return
	var n := clampi(_foes.size(), 0, MAX_FOES)
	var content_h := maxf(size.y, 8.0)
	var row_h := 18.0
	var sep := 2
	if _open_outer_h >= 8.0:
		## Same pitch as the 8-slot party panel when few foes; shrink to fit if many.
		var party_band := maxf(
			_open_outer_h - float(ROSTER_STYLE_PAD * 2 + ROSTER_MARGIN_PAD * 2),
			8.0
		)
		var m := _eight_slot_metrics(party_band)
		row_h = float(m["row_h"])
		sep = int(m["sep"])
	if n > 1:
		var need := row_h * float(n) + float(sep * (n - 1))
		if need > content_h + 0.5:
			sep = 1 if n > 8 else sep
			var inner := content_h - float(sep * (n - 1))
			row_h = maxf(floorf(inner / float(n)), 12.0)
	add_theme_constant_override("separation", sep if n > 1 else 0)
	var icon := _icon_for_row(row_h)
	for i in MAX_FOES:
		var row := _rows[i]
		if row == null:
			continue
		if i < n:
			row.visible = true
			row.custom_minimum_size = Vector2(0, row_h)
			if i < _icons.size() and _icons[i] and _icons[i].get_parent():
				(_icons[i].get_parent() as Control).custom_minimum_size = icon
		else:
			row.visible = false
			row.custom_minimum_size = Vector2.ZERO


func _eight_slot_metrics(content_h: float) -> Dictionary:
	var sep := 2
	var inner := content_h - float(sep * 7)
	var row_h := floorf(inner / 8.0)
	if row_h < 14.0:
		sep = 1
		inner = content_h - float(sep * 7)
		row_h = floorf(inner / 8.0)
	if row_h < 12.0:
		sep = 0
		inner = content_h
		row_h = floorf(inner / 8.0)
	return {"row_h": row_h, "sep": sep}


func _icon_for_row(row_h: float) -> Vector2:
	var fit_h := minf(maxf(row_h - 2.0, 12.0), float(ICON_SIZE))
	return Vector2(fit_h * _tile_aspect, fit_h)


func _aim_row_style(highlight_i: int, index: int) -> StyleBoxFlat:
	## Same shape as party New Order cursor; red fill / edge for aim hover.
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 4
	sb.content_margin_right = 2
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	sb.border_width_left = 0
	sb.border_width_top = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 0
	sb.bg_color = Color(0, 0, 0, 0)
	if index == highlight_i:
		sb.bg_color = COL_AIM_CURSOR
		sb.border_color = COL_AIM_CURSOR_EDGE
		sb.border_width_right = 3
	return sb


func _apply_aim_highlight() -> void:
	var highlight_i := -1
	if _aim_slot >= 0:
		for i in _foes.size():
			var d: Dictionary = _foes[i]
			var slot := int(d.get("slot", d.get("priority", -1)))
			if slot == _aim_slot:
				highlight_i = i
				break
	for i in _row_panels.size():
		var panel := _row_panels[i]
		if panel == null:
			continue
		panel.add_theme_stylebox_override("panel", _aim_row_style(highlight_i, i))
