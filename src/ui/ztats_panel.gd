class_name ZtatsPanel
extends Control

## Ztats sheet inside the character panel.
## Four zones with equal flex gaps; sized to fit RightTop without clipping bars.

const COL_TEXT := Color(0.91, 0.9, 0.82, 1)
const COL_ACCENT := Color(0.95, 0.85, 0.45, 1)
const COL_BAR_TEXT := Color(0.95, 0.95, 0.95, 1)
const COL_TRACK := Color(0.22, 0.22, 0.22, 1)
const COL_HP := Color(0.82, 0.22, 0.2, 1)
const COL_MP := Color(0.3, 0.55, 0.95, 1)
const COL_EXP := Color(0.92, 0.78, 0.22, 1)
## Match PartyRoster status colors.
const COL_POISON := Color(0.35, 0.78, 0.28, 1)
const COL_SLEEP := Color(0.72, 0.4, 0.95, 1)
const COL_DEAD := Color(0.55, 0.52, 0.48, 1)
const COL_SLEEP_TILE := Color(0.78, 0.55, 0.95, 1)
const COL_DEAD_TILE := Color(0.75, 0.72, 0.68, 1)
const COL_SLEEP_ZZ := Color(1.0, 0.92, 0.28, 1)
const STATUS_PULSE_PERIOD := 1.2
const HP_CRIT_RATIO := 0.30

const TILE_SIZE := 32
const FACE_SIZE := 84
## Top (above name) and bottom (below bars) — keep equal, keep modest so bars fit.
const OUTER_PAD := 4
const IDENT_SEP := 6
const TEXT_INDENT := TILE_SIZE + IDENT_SEP
## Extra space between the four zones is shared equally (collapses if tight).
const SECTION_GAP_MIN := 0
const BAR_H := 13
const BAR_LABEL_W := 34
const BAR_SEP := 4
const FONT_SIZE := 13
const BAR_VALUE_FONT_SIZE := 11
## Longest gear labels (monospace): widths measured at build from these strings.
const GEAR_WEAPON_SAMPLE := "Weapon: Mystic sword"
const GEAR_ARMOR_SAMPLE := "Armor: Magic chain"


var _title: Label
var _tile_host: Control
var _tile: TextureRect
var _sleep_zz: Label
var _face: TextureRect
var _meta: Label
var _status: Label
var _level: Label
var _attr_str: Label
var _attr_dex: Label
var _attr_int: Label
var _weapon: Label
var _armor: Label
var _atk: Label
var _def: Label
var _hp_fill: ColorRect
var _hp_lab: Label
var _mp_fill: ColorRect
var _mp_lab: Label
var _exp_fill: ColorRect
var _exp_lab: Label
var _slot := -1
var _status_code := PartyRoster.Status.OK
var _hp_critical := false
var _anim_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build()


func is_open() -> bool:
	return visible and _slot >= 0


func open_member(slot: int) -> void:
	_slot = slot
	_refresh()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	move_to_front()
	set_process(_needs_status_pulse())


func close_panel() -> void:
	_slot = -1
	_status_code = PartyRoster.Status.OK
	_hp_critical = false
	if _sleep_zz:
		_sleep_zz.visible = false
	set_process(false)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _needs_status_pulse() -> bool:
	if _status_code == PartyRoster.Status.POISONED:
		return true
	return _hp_critical and _status_code == PartyRoster.Status.OK


func _process(delta: float) -> void:
	if not visible or not _needs_status_pulse():
		return
	_anim_t += delta
	if _tile == null:
		return
	if _status_code == PartyRoster.Status.POISONED:
		_tile.modulate = _status_tint_pulse(COL_POISON)
	elif _hp_critical:
		_tile.modulate = _status_tint_pulse(COL_HP)


func _status_tint_pulse(tint_color: Color) -> Color:
	## Same pulse as PartyRoster poison / crit tint.
	var pulse := 0.5 + 0.5 * sin(_anim_t * TAU / STATUS_PULSE_PERIOD)
	var tint := 0.28 + 0.52 * pulse
	return Color(1, 1, 1, 1).lerp(tint_color, tint)


func _apply_status_visuals(st: int, hp_critical: bool) -> void:
	## Tile tint + status text + sleep zZ (match character panel).
	_status_code = st
	_hp_critical = hp_critical
	var status_col := COL_TEXT
	match st:
		PartyRoster.Status.DEAD:
			status_col = COL_DEAD
			_tile.modulate = COL_DEAD_TILE
		PartyRoster.Status.POISONED:
			status_col = COL_POISON
			_tile.modulate = _status_tint_pulse(COL_POISON)
		PartyRoster.Status.SLEEPING:
			status_col = COL_SLEEP
			_tile.modulate = COL_SLEEP_TILE
		_:
			if hp_critical:
				_tile.modulate = _status_tint_pulse(COL_HP)
			else:
				_tile.modulate = Color.WHITE
	_status.add_theme_color_override("font_color", status_col)
	if _sleep_zz:
		_sleep_zz.visible = st == PartyRoster.Status.SLEEPING
	set_process(visible and _needs_status_pulse())


func _add_section_spacer(parent: VBoxContainer) -> void:
	## Equal flex gaps between zones 1-2 / 2-3 / 3-4 (moves only zones 2 & 3).
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, SECTION_GAP_MIN)
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.size_flags_stretch_ratio = 1.0
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(sp)


func _build() -> void:
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", OUTER_PAD)
	pad.add_theme_constant_override("margin_right", OUTER_PAD)
	pad.add_theme_constant_override("margin_top", OUTER_PAD)
	pad.add_theme_constant_override("margin_bottom", OUTER_PAD)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.clip_contents = true
	add_child(pad)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(root)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_title.add_theme_font_size_override("font_size", FONT_SIZE)
	_title.add_theme_color_override("font_color", COL_ACCENT)
	UiTheme.apply_font(_title)
	root.add_child(_title)

	## Fixed ~1-line gap under name.
	var title_gap := Control.new()
	title_gap.custom_minimum_size = Vector2(0, FONT_SIZE)
	title_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_gap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	title_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_gap)

	## Zone 1 (fixed): tile + job / status / level.
	## Face is top-right but in a 0-height slot so it does NOT inflate gap 1-2.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", IDENT_SEP)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(head)

	var ident := HBoxContainer.new()
	ident.add_theme_constant_override("separation", IDENT_SEP)
	ident.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ident.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(ident)

	_tile_host = Control.new()
	_tile_host.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
	_tile_host.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_tile_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tile_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ident.add_child(_tile_host)

	_tile = TextureRect.new()
	_tile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tile_host.add_child(_tile)

	## Same zZ overlay as PartyRoster portrait (font / anchors / offsets).
	_sleep_zz = Label.new()
	_sleep_zz.text = "zZ"
	_sleep_zz.visible = false
	_sleep_zz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sleep_zz.add_theme_font_size_override("font_size", 5)
	_sleep_zz.add_theme_color_override("font_color", COL_SLEEP_ZZ)
	UiTheme.apply_font(_sleep_zz)
	_sleep_zz.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sleep_zz.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_sleep_zz.anchor_left = 1.0
	_sleep_zz.anchor_right = 1.0
	_sleep_zz.anchor_top = 0.0
	_sleep_zz.anchor_bottom = 0.0
	_sleep_zz.offset_left = -14.0
	_sleep_zz.offset_right = -2.0
	_sleep_zz.offset_top = -1.0
	_sleep_zz.offset_bottom = 8.0
	_tile_host.add_child(_sleep_zz)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ident.add_child(info)

	_meta = Label.new()
	_meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meta.add_theme_font_size_override("font_size", FONT_SIZE)
	_meta.add_theme_color_override("font_color", COL_TEXT)
	UiTheme.apply_font(_meta)
	info.add_child(_meta)

	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.add_theme_font_size_override("font_size", FONT_SIZE)
	_status.add_theme_color_override("font_color", COL_TEXT)
	UiTheme.apply_font(_status)
	info.add_child(_status)

	_level = Label.new()
	_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level.add_theme_font_size_override("font_size", FONT_SIZE)
	_level.add_theme_color_override("font_color", COL_TEXT)
	UiTheme.apply_font(_level)
	info.add_child(_level)

	## Width reserved for portrait; height 0 so head height == zone-1 text only.
	var face_slot := Control.new()
	face_slot.custom_minimum_size = Vector2(FACE_SIZE, 0)
	face_slot.size_flags_horizontal = Control.SIZE_SHRINK_END
	face_slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	face_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_slot.clip_contents = false
	head.add_child(face_slot)

	_face = TextureRect.new()
	_face.position = Vector2.ZERO
	_face.size = Vector2(FACE_SIZE, FACE_SIZE)
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_slot.add_child(_face)

	## (1-2) + (2-3) + (3-4) leftover space split equally → only zones 2 & 3 move.
	_add_section_spacer(root)

	## Zone 2: STR / DEX / INT.
	var attrs_align := HBoxContainer.new()
	attrs_align.add_theme_constant_override("separation", IDENT_SEP)
	attrs_align.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attrs_align.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	attrs_align.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(attrs_align)

	var attrs_tile_slot := Control.new()
	attrs_tile_slot.custom_minimum_size = Vector2(TILE_SIZE, 0)
	attrs_tile_slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	attrs_tile_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attrs_align.add_child(attrs_tile_slot)

	var attrs_col := VBoxContainer.new()
	attrs_col.add_theme_constant_override("separation", 4)
	attrs_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attrs_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attrs_align.add_child(attrs_col)

	_attr_str = _make_info_line_label()
	_attr_dex = _make_info_line_label()
	_attr_int = _make_info_line_label()
	attrs_col.add_child(_attr_str)
	attrs_col.add_child(_attr_dex)
	attrs_col.add_child(_attr_int)

	## Gap 2-3.
	_add_section_spacer(root)

	## Zone 3: Weapon / Armor / ATK / DEF.
	var gear_align := HBoxContainer.new()
	gear_align.add_theme_constant_override("separation", IDENT_SEP)
	gear_align.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_align.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	gear_align.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gear_align)

	var gear_tile_slot := Control.new()
	gear_tile_slot.custom_minimum_size = Vector2(TILE_SIZE, 0)
	gear_tile_slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	gear_tile_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear_align.add_child(gear_tile_slot)

	var gear_col := VBoxContainer.new()
	gear_col.add_theme_constant_override("separation", 4)
	gear_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear_align.add_child(gear_col)

	var gear_widths := _measure_gear_columns()
	var weapon_w: float = gear_widths.x
	var armor_w: float = gear_widths.y
	var gear_sep: int = int(gear_widths.z)

	var gear_row := HBoxContainer.new()
	gear_row.add_theme_constant_override("separation", gear_sep)
	gear_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_col.add_child(gear_row)

	_weapon = _make_gear_label(weapon_w)
	_armor = _make_gear_label(armor_w)
	gear_row.add_child(_weapon)
	gear_row.add_child(_armor)

	var combat_row := HBoxContainer.new()
	combat_row.add_theme_constant_override("separation", gear_sep)
	combat_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_col.add_child(combat_row)

	_atk = _make_gear_label(weapon_w)
	_def = _make_gear_label(armor_w)
	combat_row.add_child(_atk)
	combat_row.add_child(_def)

	## Gap 3-4.
	_add_section_spacer(root)

	## Zone 4 (fixed at bottom): HP / MP / Exp bars.
	var vitals := VBoxContainer.new()
	vitals.add_theme_constant_override("separation", BAR_SEP)
	vitals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vitals.size_flags_vertical = Control.SIZE_SHRINK_END
	root.add_child(vitals)

	var hp_row := _make_labeled_bar("HP")
	_hp_fill = hp_row["fill"]
	_hp_lab = hp_row["lab"]
	vitals.add_child(hp_row["row"])

	var mp_row := _make_labeled_bar("MP")
	_mp_fill = mp_row["fill"]
	_mp_lab = mp_row["lab"]
	vitals.add_child(mp_row["row"])

	var exp_row := _make_labeled_bar("Exp")
	_exp_fill = exp_row["fill"]
	_exp_lab = exp_row["lab"]
	vitals.add_child(exp_row["row"])


func _measure_gear_columns() -> Vector3:
	## x = weapon col, y = armor col, z = gap (~2 monospace chars) between columns.
	var probe := Label.new()
	probe.add_theme_font_size_override("font_size", FONT_SIZE)
	UiTheme.apply_font(probe)
	var font: Font = probe.get_theme_font("font")
	var weapon_w := 140.0
	var armor_w := 126.0
	var gap := float(FONT_SIZE)
	if font != null:
		weapon_w = font.get_string_size(
			GEAR_WEAPON_SAMPLE, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE
		).x + 2.0
		armor_w = font.get_string_size(
			GEAR_ARMOR_SAMPLE, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE
		).x + 2.0
		gap = font.get_string_size("MM", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	probe.free()
	return Vector3(weapon_w, armor_w, gap)


func _make_info_line_label() -> Label:
	## Same spacing/style as meta / status / Lv. lines.
	var lab := Label.new()
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lab.add_theme_font_size_override("font_size", FONT_SIZE)
	lab.add_theme_color_override("font_color", COL_TEXT)
	UiTheme.apply_font(lab)
	return lab


func _make_gear_label(col_w: float) -> Label:
	var lab := Label.new()
	lab.custom_minimum_size = Vector2(col_w, 0)
	lab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lab.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	lab.clip_text = false
	lab.add_theme_font_size_override("font_size", FONT_SIZE)
	lab.add_theme_color_override("font_color", COL_TEXT)
	UiTheme.apply_font(lab)
	return lab


func _make_labeled_bar(caption: String) -> Dictionary:
	## HP/MP/Exp caption aligns to Lv. (tile + sep). Bar track/right pad unchanged.
	var wrap := HBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tile_slot := Control.new()
	tile_slot.custom_minimum_size = Vector2(TILE_SIZE, 0)
	tile_slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tile_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(tile_slot)

	var label_gap := Control.new()
	label_gap.custom_minimum_size = Vector2(IDENT_SEP, 0)
	label_gap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(label_gap)

	var name_lab := Label.new()
	name_lab.text = caption
	name_lab.custom_minimum_size = Vector2(BAR_LABEL_W, 0)
	name_lab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_lab.add_theme_font_size_override("font_size", FONT_SIZE)
	name_lab.add_theme_color_override("font_color", COL_TEXT)
	UiTheme.apply_font(name_lab)
	wrap.add_child(name_lab)

	var bar_gap := Control.new()
	bar_gap.custom_minimum_size = Vector2(6, 0)
	bar_gap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(bar_gap)

	var track := Control.new()
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.custom_minimum_size = Vector2(40, BAR_H)
	track.clip_contents = true
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(track)

	var bg := ColorRect.new()
	bg.color = COL_TRACK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.add_child(bg)

	var fill := ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2.ZERO
	track.add_child(fill)

	var lab := Label.new()
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", BAR_VALUE_FONT_SIZE)
	lab.add_theme_color_override("font_color", COL_BAR_TEXT)
	UiTheme.apply_font(lab)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.add_child(lab)

	var indent_r := Control.new()
	indent_r.custom_minimum_size = Vector2(TEXT_INDENT, 0)
	indent_r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	indent_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(indent_r)

	track.resized.connect(func() -> void: _apply_fill_width(fill))
	return {"row": wrap, "fill": fill, "lab": lab}


func _set_bar(fill: ColorRect, lab: Label, cur: int, mx: int, color: Color) -> void:
	if mx <= 0:
		lab.text = "-"
		fill.set_meta("ratio", 0.0)
		fill.color = COL_TRACK
	else:
		lab.text = "%d / %d" % [cur, mx]
		fill.set_meta("ratio", clampf(float(cur) / float(mx), 0.0, 1.0))
		fill.color = color
	_apply_fill_width(fill)


func _apply_fill_width(fill: ColorRect) -> void:
	var track := fill.get_parent() as Control
	if track == null:
		return
	var ratio := float(fill.get_meta("ratio", 0.0))
	fill.position = Vector2.ZERO
	fill.size = Vector2(
		track.size.x * ratio,
		track.size.y if track.size.y > 0.0 else float(BAR_H)
	)


func _refresh() -> void:
	var data := PartyRoster.member_ztats(_slot)
	if data.is_empty():
		_title.text = "?"
		_meta.text = ""
		_status.text = ""
		_level.text = ""
		_attr_str.text = ""
		_attr_dex.text = ""
		_attr_int.text = ""
		_weapon.text = ""
		_armor.text = ""
		_atk.text = ""
		_def.text = ""
		_tile.texture = null
		_face.texture = null
		_tile.modulate = Color.WHITE
		_status_code = PartyRoster.Status.OK
		_hp_critical = false
		if _sleep_zz:
			_sleep_zz.visible = false
		set_process(false)
		_set_bar(_hp_fill, _hp_lab, 0, 0, COL_HP)
		_set_bar(_mp_fill, _mp_lab, 0, 0, COL_MP)
		_set_bar(_exp_fill, _exp_lab, 0, 0, COL_EXP)
		return
	_title.text = str(data.get("name", "?"))
	_meta.text = "%s  %s" % [str(data.get("sex", "?")), str(data.get("class", "?"))]
	_status.text = str(data.get("status", "?"))
	_level.text = "Lv.%d" % int(data.get("level", 1))
	_attr_str.text = "STR: %d" % int(data.get("str", 0))
	_attr_dex.text = "DEX: %d" % int(data.get("dex", 0))
	_attr_int.text = "INT: %d" % int(data.get("int", 0))
	var st: int = int(data.get("status_code", PartyRoster.Status.OK))
	var hp := int(data.get("hp", 0))
	var max_hp := int(data.get("max_hp", 0))
	var hp_ratio := 0.0 if max_hp <= 0 else float(hp) / float(max_hp)
	var hp_critical := hp_ratio <= HP_CRIT_RATIO and st != PartyRoster.Status.DEAD
	var hp_col := COL_HP
	if st == PartyRoster.Status.POISONED:
		hp_col = COL_POISON
	elif st == PartyRoster.Status.DEAD:
		hp_col = COL_TRACK
	_set_bar(_hp_fill, _hp_lab, hp, max_hp, hp_col)
	_set_bar(
		_mp_fill, _mp_lab,
		int(data.get("mp", 0)), int(data.get("max_mp", 0)), COL_MP
	)
	_set_bar(
		_exp_fill, _exp_lab,
		int(data.get("exp", 0)), int(data.get("exp_next", 0)), COL_EXP
	)
	_weapon.text = "Weapon: %s" % str(data.get("weapon", "Hands"))
	_armor.text = "Armor: %s" % str(data.get("armor", "No Armour"))
	_atk.text = "ATK: %d" % int(data.get("atk", 0))
	_def.text = "DEF: %d" % int(data.get("def", 0))
	_tile.texture = data.get("tile") as Texture2D
	_face.texture = data.get("portrait") as Texture2D
	_apply_status_visuals(st, hp_critical)
	call_deferred("_relayout_bars")


func _relayout_bars() -> void:
	_apply_fill_width(_hp_fill)
	_apply_fill_width(_mp_fill)
	_apply_fill_width(_exp_fill)
