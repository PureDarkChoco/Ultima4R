class_name ZtatsPanel
extends Control

## Ztats sheet inside the character panel.
## Four zones with equal flex gaps; sized to fit RightTop without clipping bars.

const _WeaponIcons := preload("res://src/core/weapon_icons.gd")
const _ArmorIcons := preload("res://src/core/armor_icons.gd")
const _ReagentIcons := preload("res://src/core/reagent_icons.gd")
const _Spells := preload("res://src/core/spells.gd")

enum InvPage { NONE = -1, GEAR = 0, REAGENTS = 1, MIXTURES = 2 }

const COL_TEXT := Color(0.91, 0.9, 0.82, 1)
const COL_ACCENT := Color(0.95, 0.85, 0.45, 1)
const COL_BAR_TEXT := Color(0.95, 0.95, 0.95, 1)
const COL_TRACK := Color(0.22, 0.22, 0.22, 1)
const COL_HP := Color(0.82, 0.22, 0.2, 1)
const COL_MP := Color(0.3, 0.55, 0.95, 1)
const COL_EXP := Color(0.86, 0.70, 0.16, 1)
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
## D2Coding includes these Unicode sex signs (drawn slightly larger to match Latin optically).
const SEX_MALE := "♂"
const SEX_FEMALE := "♀"
const SEX_FONT_SIZE := FONT_SIZE + 2
const GEAR_ICON_H := 16
const GEAR_ICON_W := 26
const GEAR_ICON_SEP := 3
const GEAR_KIND_WEAPON := "Weapon: "
const GEAR_KIND_ARMOR := "Armor: "
## Longest item names used to size the name columns (EN + KO samples).
const GEAR_WEAPON_NAME_SAMPLE := "Mystic Sword"
const GEAR_ARMOR_NAME_SAMPLE := "Magic Chain"
const GEAR_WEAPON_NAME_SAMPLE_KO := "신비의 검"
const GEAR_ARMOR_NAME_SAMPLE_KO := "마법 판금"
const ATTR_LABEL_SAMPLES := ["STR: ", "DEX: ", "INT: ", "힘: ", "민첩: ", "지능: "]
const COMBAT_LABEL_SAMPLES := ["ATK: ", "DEF: ", "공격: ", "방어: "]
const STAT_VALUE_SAMPLE := "99"
const INV_ICON := 20
const INV_ROW_H := 25
const INV_LIST_SEP := 3
const INV_STAT_W := 52
const INV_MANA_W := 40
const INV_DMG_W := 56
const INV_QTY_W := 32
## Wider side gutters so equipment / reagents / mixtures sit more centered.
const INV_PAD_H := 22
const INV_PAD_V := 6
const INV_SCROLLBAR_GAP := 10
const INV_SCROLL_EDGE_PAD := 1
const COL_INV_CURSOR := Color(0.28, 0.32, 0.22, 1)
## Spell A–Z index beside Korean names — brighter gold than body text.
const COL_MIX_INDEX := Color(1.0, 0.82, 0.28, 1)


var _title: Label
var _char_root: Control
var _inv_root: Control
var _inv_title: Label
var _inv_scroll: ScrollContainer
var _inv_list: VBoxContainer
var _inv_page: int = InvPage.NONE
var _inv_selectable: Array[Control] = []
var _inv_cursor := 0
## Per-page cursor / scroll while this Ztats session is open (cleared on close).
var _inv_saved_cursor: Dictionary = {}
var _inv_saved_scroll: Dictionary = {}
## When true, next cursor apply restores saved scroll instead of recentering.
var _inv_keep_scroll := false
## When true (↑↓ only), scroll to keep the cursor centered.
var _inv_do_center := false
var _tile_host: Control
var _tile: TextureRect
var _sleep_zz: Label
var _face: TextureRect
var _sex: Label
var _meta: Label
var _status: Label
var _level: Label
var _attr_str_kind: Label
var _attr_dex_kind: Label
var _attr_int_kind: Label
var _attr_str: Label
var _attr_dex: Label
var _attr_int: Label
var _weapon_kind: Label
var _armor_kind: Label
var _weapon_icon: TextureRect
var _armor_icon: TextureRect
var _weapon: Label
var _armor: Label
var _atk_kind: Label
var _def_kind: Label
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
	_build_inv()


func is_open() -> bool:
	return visible and (_slot >= 0 or _inv_page != InvPage.NONE)


func is_inventory_page() -> bool:
	return visible and _inv_page != InvPage.NONE


func open_member(slot: int) -> void:
	_remember_inv_view()
	_slot = slot
	_inv_page = InvPage.NONE
	_show_char(true)
	_refresh()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	move_to_front()
	set_process(_needs_status_pulse())


func open_inventory(page: int, restore_cursor: bool = true) -> void:
	_remember_inv_view()
	_slot = -1
	_inv_page = page
	var want := 0
	_inv_keep_scroll = false
	_inv_do_center = false
	if restore_cursor and _inv_saved_cursor.has(page):
		want = int(_inv_saved_cursor[page])
		_inv_keep_scroll = _inv_saved_scroll.has(page)
	_show_char(false)
	_refresh_inventory(want)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	move_to_front()
	set_process(false)


func scroll_inventory(delta: int) -> void:
	## Compatibility alias — ↑↓ moves the item cursor (skips titles).
	move_inventory_cursor(delta)


func move_inventory_cursor(delta: int) -> void:
	if not is_inventory_page() or _inv_selectable.is_empty():
		return
	## Gear / mixtures wrap; reagents have no cursor.
	var n := _inv_selectable.size()
	if _inv_page == InvPage.GEAR or _inv_page == InvPage.MIXTURES:
		_inv_cursor = posmod(_inv_cursor + delta, n)
	else:
		_inv_cursor = clampi(_inv_cursor + delta, 0, n - 1)
	_inv_keep_scroll = false
	_inv_do_center = true
	_inv_saved_cursor[_inv_page] = _inv_cursor
	_apply_inv_cursor()


func close_panel() -> void:
	_slot = -1
	_inv_page = InvPage.NONE
	_inv_cursor = 0
	_inv_saved_cursor.clear()
	_inv_saved_scroll.clear()
	_inv_keep_scroll = false
	_inv_do_center = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_show_char(true)


func _remember_inv_view() -> void:
	if _inv_page == InvPage.NONE:
		return
	if not _inv_selectable.is_empty():
		_inv_saved_cursor[_inv_page] = _inv_cursor
	if _inv_scroll:
		_inv_saved_scroll[_inv_page] = _inv_scroll.scroll_vertical


func _show_char(on: bool) -> void:
	if _char_root:
		_char_root.visible = on
	if _inv_root:
		_inv_root.visible = not on


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
	_char_root = pad

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

	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 4)
	meta_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(meta_row)

	_sex = Label.new()
	_sex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sex.add_theme_font_size_override("font_size", SEX_FONT_SIZE)
	_sex.add_theme_color_override("font_color", COL_TEXT)
	UiTheme.apply_font(_sex)
	meta_row.add_child(_sex)

	_meta = Label.new()
	_meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_meta.add_theme_font_size_override("font_size", FONT_SIZE)
	_meta.add_theme_color_override("font_color", COL_TEXT)
	UiTheme.apply_font(_meta)
	meta_row.add_child(_meta)

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

	## Zone 2: STR / DEX / INT (label column + value column).
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

	var attr_widths := _measure_stat_columns(ATTR_LABEL_SAMPLES)
	var attr_label_w: float = attr_widths.label_w
	var attr_value_w: float = attr_widths.value_w

	var str_row := _make_stat_pair_row(attr_label_w, attr_value_w)
	_attr_str_kind = str_row["kind"]
	_attr_str = str_row["value"]
	attrs_col.add_child(str_row["row"])

	var dex_row := _make_stat_pair_row(attr_label_w, attr_value_w)
	_attr_dex_kind = dex_row["kind"]
	_attr_dex = dex_row["value"]
	attrs_col.add_child(dex_row["row"])

	var int_row := _make_stat_pair_row(attr_label_w, attr_value_w)
	_attr_int_kind = int_row["kind"]
	_attr_int = int_row["value"]
	attrs_col.add_child(int_row["row"])

	## Gap 2-3.
	_add_section_spacer(root)

	## Zone 3: Weapon+ATK / Armor+DEF (one pair per row).
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
	var kind_w: float = gear_widths.kind_w
	var name_w: float = gear_widths.name_w
	var combat_label_w: float = gear_widths.combat_label_w
	var combat_value_w: float = gear_widths.combat_value_w
	var gear_sep: int = int(gear_widths.gap)
	var right_pad: float = gear_widths.right_pad

	var weapon_row := _make_gear_stat_row(
		Locale.t("ztats_weapon_kind"), kind_w, name_w,
		combat_label_w, combat_value_w, gear_sep, right_pad
	)
	_weapon_kind = weapon_row["kind"]
	_weapon_icon = weapon_row["icon"]
	_weapon = weapon_row["name"]
	_atk_kind = weapon_row["stat_kind"]
	_atk = weapon_row["stat"]
	gear_col.add_child(weapon_row["row"])

	var armor_row := _make_gear_stat_row(
		Locale.t("ztats_armor_kind"), kind_w, name_w,
		combat_label_w, combat_value_w, gear_sep, right_pad
	)
	_armor_kind = armor_row["kind"]
	_armor_icon = armor_row["icon"]
	_armor = armor_row["name"]
	_def_kind = armor_row["stat_kind"]
	_def = armor_row["stat"]
	gear_col.add_child(armor_row["row"])

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


func _measure_stat_columns(label_samples: Array) -> Dictionary:
	## Shared label width + value width so numbers line up across languages.
	var probe := Label.new()
	probe.add_theme_font_size_override("font_size", FONT_SIZE)
	UiTheme.apply_font(probe)
	var font: Font = probe.get_theme_font("font")
	var label_w := 48.0
	var value_w := 24.0
	if font != null:
		label_w = 0.0
		for sample in label_samples:
			label_w = maxf(
				label_w,
				font.get_string_size(
					str(sample), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE
				).x
			)
		label_w += 2.0
		value_w = font.get_string_size(
			STAT_VALUE_SAMPLE, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE
		).x + 2.0
	probe.free()
	return {"label_w": label_w, "value_w": value_w}


func _measure_gear_columns() -> Dictionary:
	## Shared kind width left-aligns item icons; right_pad pulls ATK/DEF in ~4 chars.
	var probe := Label.new()
	probe.add_theme_font_size_override("font_size", FONT_SIZE)
	UiTheme.apply_font(probe)
	var font: Font = probe.get_theme_font("font")
	var kind_w := 72.0
	var name_w := 120.0
	var combat_label_w := 48.0
	var combat_value_w := 24.0
	var gap := float(FONT_SIZE)
	var right_pad := float(FONT_SIZE) * 4.0
	if font != null:
		kind_w = maxf(
			font.get_string_size(
				Locale.t("ztats_weapon_kind"), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE
			).x,
			font.get_string_size(
				Locale.t("ztats_armor_kind"), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE
			).x
		) + 2.0
		name_w = maxf(
			font.get_string_size(
				GEAR_WEAPON_NAME_SAMPLE, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE
			).x,
			font.get_string_size(
				GEAR_ARMOR_NAME_SAMPLE, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE
			).x
		)
		name_w = maxf(
			name_w,
			font.get_string_size(
				GEAR_WEAPON_NAME_SAMPLE_KO, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE
			).x
		)
		name_w = maxf(
			name_w,
			font.get_string_size(
				GEAR_ARMOR_NAME_SAMPLE_KO, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE
			).x
		) + 2.0
		var combat_cols := _measure_stat_columns(COMBAT_LABEL_SAMPLES)
		combat_label_w = combat_cols.label_w
		combat_value_w = combat_cols.value_w
		gap = font.get_string_size("MM", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		right_pad = font.get_string_size("MMMM", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	probe.free()
	return {
		"kind_w": kind_w,
		"name_w": name_w,
		"combat_label_w": combat_label_w,
		"combat_value_w": combat_value_w,
		"gap": gap,
		"right_pad": right_pad,
	}


func _make_stat_pair_row(label_w: float, value_w: float) -> Dictionary:
	## Fixed label column + fixed value column (numbers share the same x).
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var kind := Label.new()
	kind.custom_minimum_size = Vector2(label_w, 0)
	kind.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	kind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	kind.add_theme_font_size_override("font_size", FONT_SIZE)
	kind.add_theme_color_override("font_color", COL_TEXT)
	UiTheme.apply_font(kind)
	row.add_child(kind)

	var value := Label.new()
	value.custom_minimum_size = Vector2(value_w, 0)
	value.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.add_theme_font_size_override("font_size", FONT_SIZE)
	value.add_theme_color_override("font_color", COL_TEXT)
	UiTheme.apply_font(value)
	row.add_child(value)

	return {"row": row, "kind": kind, "value": value}


func _make_gear_stat_row(
	kind_text: String,
	kind_w: float,
	name_w: float,
	combat_label_w: float,
	combat_value_w: float,
	gap: int,
	right_pad: float
) -> Dictionary:
	## "Weapon: " [icon] name …… ATK:  n / "Armor: " [icon] name …… DEF:  n
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GEAR_ICON_SEP)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var kind := Label.new()
	kind.text = kind_text
	kind.custom_minimum_size = Vector2(kind_w, 0)
	kind.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	kind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	kind.add_theme_font_size_override("font_size", FONT_SIZE)
	kind.add_theme_color_override("font_color", COL_TEXT)
	UiTheme.apply_font(kind)
	row.add_child(kind)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(GEAR_ICON_W, GEAR_ICON_H)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var name_lab := _make_gear_label(name_w)
	row.add_child(name_lab)

	var mid_gap := Control.new()
	mid_gap.custom_minimum_size = Vector2(gap, 0)
	mid_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mid_gap)

	var combat := _make_stat_pair_row(combat_label_w, combat_value_w)
	combat["row"].size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(combat["row"])

	## Pull ATK/DEF ~4 monospace chars in from the right edge.
	var trail := Control.new()
	trail.custom_minimum_size = Vector2(right_pad, 0)
	trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(trail)

	return {
		"row": row,
		"kind": kind,
		"icon": icon,
		"name": name_lab,
		"stat_kind": combat["kind"],
		"stat": combat["value"],
	}


func _keyed_gear_texture(tex: Texture2D) -> Texture2D:
	## White paper bg → transparent so icons sit on the dark panel.
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return tex
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r > 0.92 and c.g > 0.92 and c.b > 0.92:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func _title_case_words(s: String) -> String:
	## "Magic sword" / "magic chain" → "Magic Sword" / "Magic Chain".
	var parts := s.strip_edges().split(" ", false)
	for i in parts.size():
		var w := parts[i]
		if w.is_empty():
			continue
		parts[i] = w.substr(0, 1).to_upper() + w.substr(1).to_lower()
	return " ".join(parts)


func _localized_item_name(english_name: String) -> String:
	## Look up Locale item_* keys; fall back to title-cased English.
	var key := "item_%s" % english_name.strip_edges().to_lower().replace(" ", "_")
	var translated := Locale.t(key)
	if translated == key:
		return _title_case_words(english_name)
	return translated


func _set_gear_icon(icon: TextureRect, item_name: String, kind: StringName) -> void:
	if icon == null:
		return
	var path := ""
	if kind == &"weapon":
		path = _WeaponIcons.path_for_name(item_name)
	elif kind == &"armor":
		path = _ArmorIcons.path_for_name(item_name)
	## Keep the slot sized even when missing art (ATK/DEF stay aligned).
	icon.texture = _load_keyed_gear_path(path)
	icon.visible = true


func _load_keyed_gear_path(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var img := Image.new()
	if img.load(path) != OK:
		var loaded := load(path) as Texture2D
		return _keyed_gear_texture(loaded)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r > 0.92 and c.g > 0.92 and c.b > 0.92:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


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
		if _sex:
			_sex.text = ""
		_status.text = ""
		_level.text = ""
		_attr_str.text = ""
		_attr_dex.text = ""
		_attr_int.text = ""
		if _attr_str_kind:
			_attr_str_kind.text = ""
		if _attr_dex_kind:
			_attr_dex_kind.text = ""
		if _attr_int_kind:
			_attr_int_kind.text = ""
		_weapon.text = ""
		_armor.text = ""
		if _weapon_icon:
			_weapon_icon.texture = null
		if _armor_icon:
			_armor_icon.texture = null
		_atk.text = ""
		_def.text = ""
		if _atk_kind:
			_atk_kind.text = ""
		if _def_kind:
			_def_kind.text = ""
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
	_meta.text = str(data.get("class", "?"))
	var sex := str(data.get("sex", "M")).to_upper()
	if _sex:
		_sex.text = SEX_FEMALE if sex == "F" or sex == "FEMALE" else SEX_MALE
	_status.text = str(data.get("status", "?"))
	_level.text = "Lv.%d" % int(data.get("level", 1))
	_attr_str_kind.text = Locale.t("ztats_str")
	_attr_dex_kind.text = Locale.t("ztats_dex")
	_attr_int_kind.text = Locale.t("ztats_int")
	_attr_str.text = str(int(data.get("str", 0)))
	_attr_dex.text = str(int(data.get("dex", 0)))
	_attr_int.text = str(int(data.get("int", 0)))
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
	var weapon_key := _title_case_words(str(data.get("weapon", "Hands")))
	var armor_key := _title_case_words(str(data.get("armor", "No Armour")))
	if _weapon_kind:
		_weapon_kind.text = Locale.t("ztats_weapon_kind")
	if _armor_kind:
		_armor_kind.text = Locale.t("ztats_armor_kind")
	_weapon.text = _localized_item_name(weapon_key)
	_armor.text = _localized_item_name(armor_key)
	_set_gear_icon(_weapon_icon, weapon_key, &"weapon")
	_set_gear_icon(_armor_icon, armor_key, &"armor")
	_atk_kind.text = Locale.t("ztats_atk")
	_def_kind.text = Locale.t("ztats_def")
	_atk.text = str(int(data.get("atk", 0)))
	_def.text = str(int(data.get("def", 0)))
	_tile.texture = data.get("tile") as Texture2D
	_face.texture = data.get("portrait") as Texture2D
	_apply_status_visuals(st, hp_critical)
	call_deferred("_relayout_bars")


func _relayout_bars() -> void:
	_apply_fill_width(_hp_fill)
	_apply_fill_width(_mp_fill)
	_apply_fill_width(_exp_fill)


func _build_inv() -> void:
	_inv_root = MarginContainer.new()
	_inv_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inv_root.add_theme_constant_override("margin_left", INV_PAD_H)
	_inv_root.add_theme_constant_override("margin_right", INV_PAD_H)
	_inv_root.add_theme_constant_override("margin_top", INV_PAD_V)
	_inv_root.add_theme_constant_override("margin_bottom", INV_PAD_V)
	_inv_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inv_root.visible = false
	add_child(_inv_root)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inv_root.add_child(root)

	_inv_title = Label.new()
	_inv_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inv_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_title.add_theme_font_size_override("font_size", FONT_SIZE + 1)
	_inv_title.add_theme_color_override("font_color", COL_ACCENT)
	UiTheme.apply_font(_inv_title)
	root.add_child(_inv_title)

	_inv_scroll = ScrollContainer.new()
	_inv_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inv_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inv_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_inv_scroll)

	## Gap between list content and the scrollbar track.
	var list_pad := MarginContainer.new()
	list_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_pad.add_theme_constant_override("margin_right", INV_SCROLLBAR_GAP)
	list_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inv_scroll.add_child(list_pad)

	_inv_list = VBoxContainer.new()
	_inv_list.add_theme_constant_override("separation", INV_LIST_SEP)
	_inv_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_pad.add_child(_inv_list)


func _refresh_inventory(want_cursor: int = 0) -> void:
	if _inv_list == null:
		return
	for c in _inv_list.get_children():
		c.queue_free()
	_inv_selectable.clear()
	_inv_cursor = maxi(0, want_cursor)
	_inv_scroll.scroll_vertical = 0
	_inv_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_inv_list.add_theme_constant_override("separation", INV_LIST_SEP)
	match _inv_page:
		InvPage.GEAR:
			_inv_title.text = Locale.t("ztats_page_equipment")
			_fill_gear_page()
		InvPage.REAGENTS:
			_inv_title.text = Locale.t("ztats_page_reagents")
			_fill_reagents_page()
		InvPage.MIXTURES:
			_inv_title.text = Locale.t("ztats_page_mixtures")
			_fill_mixtures_page()
		_:
			_inv_title.text = "?"
	if not _inv_selectable.is_empty():
		_inv_cursor = clampi(_inv_cursor, 0, _inv_selectable.size() - 1)
		_inv_saved_cursor[_inv_page] = _inv_cursor
		call_deferred("_apply_inv_cursor")
	elif _inv_keep_scroll and _inv_saved_scroll.has(_inv_page):
		## Reagents (no cursor) — still restore last scroll if any.
		call_deferred("_restore_inv_scroll")


func _fill_gear_page() -> void:
	_add_inv_section(Locale.t("ztats_page_weapons"))
	_add_gear_header(Locale.t("ztats_col_damage"))
	for w in range(1, GameState.weapons.size()): ## skip Hands
		var qty := int(GameState.weapons[w])
		if qty <= 0:
			continue
		_add_gear_item_row(
			_load_keyed_gear_path(_WeaponIcons.path_for_id(w)),
			Locale.weapon_name(w),
			_WeaponIcons.damage_of(w),
			qty
		)
	_add_inv_section(Locale.t("ztats_page_armor"))
	_add_gear_header(Locale.t("ztats_col_defense"))
	for a in range(1, GameState.armor.size()): ## skip No Armor
		var qty2 := int(GameState.armor[a])
		if qty2 <= 0:
			continue
		_add_gear_item_row(
			_load_keyed_gear_path(_ArmorIcons.path_for_id(a)),
			Locale.armor_name(a),
			_ArmorIcons.defense_of(a),
			qty2
		)


func _fill_reagents_page() -> void:
	## No item cursor — compact layout sized to never need a scrollbar.
	_inv_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_add_gear_header(Locale.t("ztats_col_qty"), false)
	for r in GameState.reagents.size():
		var letter := "%s. %s" % [String.chr(65 + r), Locale.reagent_name(r)]
		_add_icon_qty_row(
			_load_keyed_gear_path(_ReagentIcons.path_for_id(r)),
			letter,
			int(GameState.reagents[r]),
			false
		)
	call_deferred("_fit_reagents_layout")


func _fit_reagents_layout() -> void:
	## Compact rows/gaps unique to reagents — always fit inside the viewport (no scrollbar).
	if _inv_page != InvPage.REAGENTS or _inv_list == null or _inv_scroll == null:
		return
	var kids := _inv_list.get_children()
	var count := kids.size()
	if count < 1:
		return
	var view_h := _inv_scroll.size.y
	if view_h < 1.0:
		return
	var gaps := maxi(count - 1, 0)
	## Tighter than gear/mix — exact fit so SCROLL_MODE_DISABLED never clips.
	var sep := 2.0
	var row_h := (view_h - sep * float(gaps)) / float(count)
	if row_h > 24.0:
		row_h = 24.0
		if gaps > 0:
			sep = maxf(1.0, (view_h - row_h * float(count)) / float(gaps))
	elif row_h < float(INV_ICON):
		## Prefer fitting icons; collapse gaps before shrinking below icon size.
		row_h = mini(float(INV_ICON), view_h / float(count))
		if gaps > 0:
			sep = maxf(0.0, (view_h - row_h * float(count)) / float(gaps))
	_inv_list.add_theme_constant_override("separation", int(round(sep)))
	for i in count:
		var c := kids[i] as Control
		if c == null:
			continue
		var h := maxf(row_h - 2.0, 14.0) if i == 0 else row_h
		c.custom_minimum_size = Vector2(0, h)
		c.size.y = h


func _fill_mixtures_page() -> void:
	## Mixed spells only. Columns: Name · Mana · Qty · Damage (range when known).
	## KO: A.–Z. index in accent color. EN: first letter of the name in accent color.
	_add_mix_header()
	var ko := GameState.language == "ko"
	for s in _Spells.COUNT:
		var qty := 0
		if s < GameState.mixtures.size():
			qty = int(GameState.mixtures[s])
		if qty <= 0:
			continue
		_add_mix_item_row(
			Locale.spell_name(s),
			_Spells.mp_cost(s),
			qty,
			_Spells.damage_text(s),
			_Spells.letter(s) if ko else "",
			not ko
		)


func _add_inv_section(title: String) -> void:
	## Fixed stride matching item rows (clip so font metrics can't add 1–2px).
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, INV_ROW_H)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.clip_contents = true
	wrap.set_meta("inv_skip", true)

	var lab := Label.new()
	lab.text = title
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", FONT_SIZE)
	lab.add_theme_color_override("font_color", COL_ACCENT)
	UiTheme.apply_font(lab)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(lab)
	_inv_list.add_child(wrap)


func _add_gear_header(stat_label: String, show_stat: bool = true) -> void:
	## Column titles — fixed height matching item rows.
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, INV_ROW_H)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.clip_contents = true
	wrap.set_meta("inv_skip", true)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon_pad := Control.new()
	icon_pad.custom_minimum_size = Vector2(INV_ICON, 1)
	icon_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_pad)

	var nm := Label.new()
	nm.text = Locale.t("ztats_col_name")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", FONT_SIZE - 1)
	nm.add_theme_color_override("font_color", COL_ACCENT)
	UiTheme.apply_font(nm)
	row.add_child(nm)

	if show_stat:
		var st := Label.new()
		st.text = stat_label
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		st.custom_minimum_size = Vector2(INV_STAT_W, 0)
		st.add_theme_font_size_override("font_size", FONT_SIZE - 1)
		st.add_theme_color_override("font_color", COL_ACCENT)
		UiTheme.apply_font(st)
		row.add_child(st)

	var q := Label.new()
	q.text = Locale.t("ztats_col_qty")
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	q.custom_minimum_size = Vector2(INV_QTY_W, 0)
	q.add_theme_font_size_override("font_size", FONT_SIZE - 1)
	q.add_theme_color_override("font_color", COL_ACCENT)
	UiTheme.apply_font(q)
	row.add_child(q)

	wrap.add_child(row)
	_inv_list.add_child(wrap)


func _add_gear_item_row(tex: Texture2D, name: String, stat: int, qty: int) -> void:
	var inner := _make_inv_inner_row()
	_add_inv_icon(inner, tex)
	_add_inv_name(inner, name)
	_add_inv_num(inner, str(stat), INV_STAT_W)
	_add_inv_num(inner, str(mini(qty, 99)), INV_QTY_W)
	_register_inv_row(inner)


func _add_icon_qty_row(tex: Texture2D, name: String, qty: int, selectable: bool = true) -> void:
	var inner := _make_inv_inner_row()
	_add_inv_icon(inner, tex)
	_add_inv_name(inner, name)
	_add_inv_num(inner, str(mini(qty, 99)), INV_QTY_W)
	if selectable:
		_register_inv_row(inner)
	else:
		_add_inv_static_row(inner)


func _add_inv_static_row(inner: HBoxContainer) -> void:
	## Non-selectable row (reagents — no cursor highlight).
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, INV_ROW_H)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.clip_contents = true
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(inner)
	_inv_list.add_child(wrap)


func _add_mix_header() -> void:
	## Name · Mana · Qty · Damage — fixed height matching item rows.
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, INV_ROW_H)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.clip_contents = true
	wrap.set_meta("inv_skip", true)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var nm := Label.new()
	nm.text = Locale.t("ztats_col_name")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", FONT_SIZE - 1)
	nm.add_theme_color_override("font_color", COL_ACCENT)
	UiTheme.apply_font(nm)
	row.add_child(nm)

	for pair in [
		[Locale.t("ztats_col_mana"), INV_MANA_W],
		[Locale.t("ztats_col_qty"), INV_QTY_W],
		[Locale.t("ztats_col_damage"), INV_DMG_W],
	]:
		var lab := Label.new()
		lab.text = str(pair[0])
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lab.custom_minimum_size = Vector2(float(pair[1]), 0)
		lab.add_theme_font_size_override("font_size", FONT_SIZE - 1)
		lab.add_theme_color_override("font_color", COL_ACCENT)
		UiTheme.apply_font(lab)
		row.add_child(lab)

	wrap.add_child(row)
	_inv_list.add_child(wrap)


func _add_mix_item_row(
	name: String,
	mana: int,
	qty: int,
	dmg: String,
	index_letter: String = "",
	color_first_letter: bool = false
) -> void:
	var inner := _make_inv_inner_row()
	if not index_letter.is_empty():
		_add_mix_index(inner, index_letter)
		_add_inv_name(inner, name)
	elif color_first_letter and not name.is_empty():
		_add_mix_name_colored_initial(inner, name)
	else:
		_add_inv_name(inner, name)
	_add_inv_num(inner, str(mana), INV_MANA_W)
	_add_inv_num(inner, str(mini(qty, 99)), INV_QTY_W)
	_add_inv_num(inner, dmg, INV_DMG_W)
	_register_inv_row(inner)


func _add_mix_index(row: HBoxContainer, letter: String) -> void:
	var lab := Label.new()
	lab.text = "%s." % letter
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_mix_index_style(lab)
	row.add_child(lab)


func _add_mix_name_colored_initial(row: HBoxContainer, name: String) -> void:
	## EN: tint the cast letter (first character) without a gap before the rest.
	var host := HBoxContainer.new()
	host.add_theme_constant_override("separation", 0)
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var initial := Label.new()
	initial.text = name.substr(0, 1)
	initial.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_mix_index_style(initial)
	host.add_child(initial)

	var rest := name.substr(1)
	if not rest.is_empty():
		var body := Label.new()
		body.text = rest
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		body.clip_text = true
		var settings := LabelSettings.new()
		var f: Font = UiTheme.font()
		if f:
			settings.font = f
		settings.font_size = FONT_SIZE
		settings.font_color = COL_TEXT
		body.label_settings = settings
		host.add_child(body)

	row.add_child(host)


func _apply_mix_index_style(lab: Label) -> void:
	## LabelSettings wins over theme defaults so the index stays distinct from the name.
	var settings := LabelSettings.new()
	var f: Font = UiTheme.font()
	if f:
		settings.font = f
	settings.font_size = FONT_SIZE
	settings.font_color = COL_MIX_INDEX
	lab.label_settings = settings


func _make_inv_inner_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


func _add_inv_icon(row: HBoxContainer, tex: Texture2D) -> void:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(INV_ICON, INV_ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = tex
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)


func _add_inv_name(row: HBoxContainer, name: String) -> void:
	var nm := Label.new()
	nm.text = name
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", FONT_SIZE)
	nm.add_theme_color_override("font_color", COL_TEXT)
	nm.clip_text = true
	UiTheme.apply_font(nm)
	row.add_child(nm)


func _add_inv_num(row: HBoxContainer, text: String, width: float) -> void:
	var q := Label.new()
	q.text = text
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	q.custom_minimum_size = Vector2(width, 0)
	q.add_theme_font_size_override("font_size", FONT_SIZE)
	q.add_theme_color_override("font_color", COL_TEXT)
	UiTheme.apply_font(q)
	row.add_child(q)


func _register_inv_row(inner: HBoxContainer) -> void:
	## Wrapper so cursor highlight can sit behind the row without breaking HBox layout.
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, INV_ROW_H)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.clip_contents = true
	wrap.set_meta("inv_selectable", true)

	var bg := ColorRect.new()
	bg.name = "CursorBg"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = COL_INV_CURSOR
	bg.visible = false
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(bg)

	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(inner)

	_inv_list.add_child(wrap)
	_inv_selectable.append(wrap)


func _apply_inv_cursor() -> void:
	if _inv_selectable.is_empty():
		return
	_inv_cursor = clampi(_inv_cursor, 0, _inv_selectable.size() - 1)
	for i in _inv_selectable.size():
		var row := _inv_selectable[i]
		if row == null or not is_instance_valid(row):
			continue
		var bg := row.get_node_or_null("CursorBg") as ColorRect
		if bg:
			bg.visible = i == _inv_cursor
	## ←→ return: restore scroll. ↑↓: center. First open: stay at top (titles visible).
	if _inv_keep_scroll and _inv_saved_scroll.has(_inv_page):
		_restore_inv_scroll()
	elif _inv_do_center:
		var row2 := _inv_selectable[_inv_cursor]
		if row2 and is_instance_valid(row2):
			call_deferred("_scroll_cursor_centered", row2)
	else:
		## First visit this session — show headers/titles at the top.
		if _inv_scroll:
			_inv_scroll.scroll_vertical = 0
		_inv_saved_scroll[_inv_page] = 0
	_inv_keep_scroll = false
	_inv_do_center = false


func _restore_inv_scroll() -> void:
	if _inv_scroll == null or not _inv_saved_scroll.has(_inv_page):
		return
	var y := int(_inv_saved_scroll[_inv_page])
	## Wait one frame so list min-size is ready, then clamp into range.
	await get_tree().process_frame
	if _inv_scroll == null or _inv_page == InvPage.NONE:
		return
	var host := _inv_scroll.get_child(0) as Control
	var content_h := host.size.y if host else 0.0
	var max_scroll := maxi(0, int(content_h - _inv_scroll.size.y))
	_inv_scroll.scroll_vertical = clampi(y, 0, max_scroll)
	_inv_saved_scroll[_inv_page] = _inv_scroll.scroll_vertical


func _scroll_cursor_centered(row: Control) -> void:
	## Keep the selected row near the vertical middle until list ends.
	## Always keep the full selected row (plus a small pad) inside the view
	## so glyphs are never clipped by the ScrollContainer edge.
	if _inv_scroll == null or row == null or not is_instance_valid(row):
		return
	if _inv_list == null:
		return
	var view_h := _inv_scroll.size.y
	if view_h < 1.0:
		return
	## Scroll child is the padded list host — use its height for max scroll.
	var host := _inv_scroll.get_child(0) as Control
	var content_h := host.size.y if host else _inv_list.size.y
	content_h = maxf(content_h, _inv_list.get_combined_minimum_size().y)
	var row_top := row.position.y
	var row_h := maxf(row.size.y, float(INV_ROW_H))
	content_h = maxf(content_h, row_top + row_h)
	var max_scroll := maxf(0.0, content_h - view_h)
	var pad := float(INV_SCROLL_EDGE_PAD)
	var ideal := row_top + row_h * 0.5 - view_h * 0.5
	var scroll := clampf(ideal, 0.0, max_scroll)
	## Nudge so the selected row is never cut at top/bottom.
	var min_scroll := row_top + row_h + pad - view_h
	var max_keep := row_top - pad
	if min_scroll <= max_keep:
		scroll = clampf(scroll, min_scroll, max_keep)
	scroll = clampf(scroll, 0.0, max_scroll)
	_inv_scroll.scroll_vertical = int(round(scroll))
	if _inv_page != InvPage.NONE:
		_inv_saved_scroll[_inv_page] = _inv_scroll.scroll_vertical
