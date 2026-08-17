class_name ZtatsPanel
extends Control

## Ztats sheet inside the character panel.
## Four zones with equal flex gaps; sized to fit RightTop without clipping bars.

const _WeaponIcons := preload("res://src/core/weapon_icons.gd")
const _ArmorIcons := preload("res://src/core/armor_icons.gd")
const _ReagentIcons := preload("res://src/core/reagent_icons.gd")
const _RuneIcons := preload("res://src/core/rune_icons.gd")
const _SpecialItemIcons := preload("res://src/core/special_item_icons.gd")
const _Virtues := preload("res://src/core/virtues.gd")
const _Spells := preload("res://src/core/spells.gd")

## xu4 order adapted: Weapons+Armor → Items (+sextant) → Reagents → Mixtures.
## WEAPONS / ARMOR are shop-side peeks (Ztats ←→ cycle stays GEAR…MIXTURES).
enum InvPage {
	NONE = -1,
	GEAR = 0,
	ITEMS = 1,
	REAGENTS = 2,
	MIXTURES = 3,
	WEAPONS = 4,
	ARMOR = 5,
}

const COL_TEXT := Color(0.91, 0.9, 0.82, 1)
const COL_ACCENT := Color(0.95, 0.85, 0.45, 1)
const COL_BAR_TEXT := Color(0.95, 0.95, 0.95, 1)
const COL_TRACK := Color(0.22, 0.22, 0.22, 1)
const COL_HP := Color(0.82, 0.22, 0.2, 1)
const COL_MP := Color(0.3, 0.55, 0.95, 1)
const COL_EXP := Color(0.86, 0.70, 0.16, 1)
const COL_EXP_READY := Color(0.28, 0.80, 0.34, 1)
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
## Minimum face box; actual height is synced to the INT row bottom.
const FACE_SIZE := 84
## Painted portraits are 240×300 (4:5).
const FACE_ASPECT := 240.0 / 300.0
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
## Source art is 32×32; UI displays smaller so list rows stay compact.
const GEAR_ICON := 20
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
## Spell A–Z index beside Korean names — brighter gold than body text.
const COL_MIX_INDEX := Color(1.0, 0.82, 0.28, 1)
## Shop sell cursor (matches Ready / Wear highlight).
const COL_CURSOR := Color(0.22, 0.42, 0.82, 0.55)
const COL_CURSOR_EDGE := Color(0.38, 0.58, 0.82, 0.72)


var _title: Label
var _char_root: Control
var _inv_root: Control
var _inv_title: Label
var _inv_scroll: ScrollContainer
var _inv_list: VBoxContainer
var _inv_page: int = InvPage.NONE
## Per-page scroll while this Ztats session is open (cleared on close).
var _inv_saved_scroll: Dictionary = {}
## When true, next refresh restores saved scroll instead of starting at top.
var _inv_keep_scroll := false
## Weapon/armor shop sell: highlight a letter row for ↑↓ / Enter.
var _shop_pick := false
var _pick_ids: Array[int] = []
var _pick_row_wraps: Array[Control] = []
var _pick_cursor := 0
## Sticky sell-cursor item across Y/N / qty prompts and list rebuilds.
var _pick_retain_id := -1
## One-shot prefer id applied in _finalize_shop_pick after a rebuild.
var _pick_prefer_id := -1
## Invalidates delayed scroll settling from an older inventory rebuild.
var _pick_scroll_gen := 0
## Cancels in-flight face sync awaits when a newer sync is requested.
var _face_sync_gen := 0
var _tile_host: Control
var _tile: TextureRect
var _sleep_zz: Label
var _face: TextureRect
var _face_slot: Control
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
	resized.connect(_sync_face_to_int_row)


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
	## First open: layout isn't ready in the same idle as visible=true.
	_request_face_sync()


func open_inventory(page: int, restore_scroll: bool = true, shop_pick: bool = false) -> void:
	_remember_inv_view()
	## Keep / restore sell cursor across rebuilds and Y/N / qty detours.
	if _shop_pick and not _pick_ids.is_empty():
		if _pick_cursor >= 0 and _pick_cursor < _pick_ids.size():
			_pick_retain_id = int(_pick_ids[_pick_cursor])
	var want_pick := shop_pick and (page == InvPage.WEAPONS or page == InvPage.ARMOR)
	if want_pick and page != _inv_page:
		## Different inventory page — drop retained sell letter.
		_pick_retain_id = -1
	_slot = -1
	_inv_page = page
	_shop_pick = want_pick
	_pick_prefer_id = _pick_retain_id if _shop_pick else -1
	## Sell pick manages scroll via ensure_cursor; inventory peeks still keep scroll.
	_inv_keep_scroll = restore_scroll and not shop_pick and _inv_saved_scroll.has(page)
	_show_char(false)
	_refresh_inventory()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	move_to_front()
	set_process(false)


func has_shop_pick() -> bool:
	return _shop_pick and not _pick_ids.is_empty()


func shop_pick_nudge(delta: int) -> void:
	if not has_shop_pick() or delta == 0:
		return
	var n := _pick_ids.size()
	## No wrap — hold-repeat would otherwise loop the sell list.
	_pick_cursor = clampi(_pick_cursor + delta, 0, n - 1)
	_pick_retain_id = int(_pick_ids[_pick_cursor])
	_sync_shop_pick_hilite()
	_ensure_shop_pick_visible()


func shop_pick_letter() -> String:
	## Letter key for current row (B=1 …) so vendor sell letter paths stay in sync.
	if not has_shop_pick():
		return ""
	var id := int(_pick_ids[_pick_cursor])
	_pick_retain_id = id
	if id < 0 or id > 25:
		return ""
	return String.chr(65 + id).to_lower()


func shop_pick_focus_letter(letter: String) -> void:
	## Remember a typed A–P sell letter so rebuild keeps the same row when still owned.
	if letter.is_empty():
		return
	var ch := letter.substr(0, 1).to_lower()
	var code := ch.unicode_at(0)
	if code < 97 or code > 122:
		return
	var item_id := code - 97
	_pick_retain_id = item_id
	if not has_shop_pick():
		return
	for i in _pick_ids.size():
		if int(_pick_ids[i]) == item_id:
			_pick_cursor = i
			_sync_shop_pick_hilite()
			_ensure_shop_pick_visible()
			return


func scroll_inventory(lines: int) -> void:
	## Scroll the list by whole rows (no cursor, no wrap). lines may be ±1 or ±5.
	if not is_inventory_page() or _inv_scroll == null:
		return
	if _inv_page == InvPage.REAGENTS:
		return ## Fits the panel; no scrollbar.
	if lines == 0:
		return
	var stride := INV_ROW_H + INV_LIST_SEP
	var max_step := _inv_scroll_max_step()
	var cur := (_inv_scroll.scroll_vertical / stride) * stride
	cur = clampi(cur, 0, max_step)
	if cur != _inv_scroll.scroll_vertical:
		_inv_scroll.scroll_vertical = cur
	var next: int
	if lines > 0:
		if cur >= max_step:
			return
		next = mini(cur + lines * stride, max_step)
	else:
		if cur <= 0:
			return
		next = maxi(cur + lines * stride, 0)
	if next == cur:
		return
	_inv_scroll.scroll_vertical = next
	_inv_saved_scroll[_inv_page] = next


func scroll_inventory_home() -> void:
	_scroll_inventory_to(0)


func scroll_inventory_end() -> void:
	_scroll_inventory_to(_inv_scroll_max_step())


func _scroll_inventory_to(y: int) -> void:
	if not is_inventory_page() or _inv_scroll == null:
		return
	if _inv_page == InvPage.REAGENTS:
		return
	var stride := INV_ROW_H + INV_LIST_SEP
	var max_step := _inv_scroll_max_step()
	var next := clampi((y / stride) * stride, 0, max_step)
	if next == _inv_scroll.scroll_vertical:
		return
	_inv_scroll.scroll_vertical = next
	_inv_saved_scroll[_inv_page] = next


func _inv_scroll_max() -> int:
	if _inv_scroll == null:
		return 0
	var host := _inv_scroll.get_child(0) as Control
	var content_h := host.size.y if host else 0.0
	return maxi(0, int(content_h - _inv_scroll.size.y))


func _inv_scroll_max_step() -> int:
	## Largest scroll aligned to a full row — no leftover micro-step at the end.
	var stride := INV_ROW_H + INV_LIST_SEP
	return (_inv_scroll_max() / stride) * stride


func close_panel() -> void:
	_slot = -1
	_inv_page = InvPage.NONE
	_shop_pick = false
	_pick_ids.clear()
	_pick_row_wraps.clear()
	_pick_cursor = 0
	_pick_retain_id = -1
	_pick_prefer_id = -1
	_inv_saved_scroll.clear()
	_inv_keep_scroll = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_show_char(true)


func _remember_inv_view() -> void:
	if _inv_page == InvPage.NONE or _inv_scroll == null:
		return
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
	## Face itself extends down through STR/DEX/INT (see _sync_face_to_int_row).
	_face_slot = Control.new()
	_face_slot.custom_minimum_size = Vector2(FACE_SIZE * FACE_ASPECT, 0)
	_face_slot.size_flags_horizontal = Control.SIZE_SHRINK_END
	_face_slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_face_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face_slot.clip_contents = false
	head.add_child(_face_slot)

	_face = TextureRect.new()
	_face.position = Vector2.ZERO
	_face.size = Vector2(FACE_SIZE * FACE_ASPECT, FACE_SIZE)
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face_slot.add_child(_face)

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
	icon.custom_minimum_size = Vector2(GEAR_ICON, GEAR_ICON)
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
	## Key backdrop: white paper (legacy) or near-black (weapon/armor/reagent art).
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return tex
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var corner := img.get_pixel(0, 0)
	var key_white := corner.a > 0.5 and corner.r > 0.85 and corner.g > 0.85 and corner.b > 0.85
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if key_white:
				if c.r > 0.92 and c.g > 0.92 and c.b > 0.92:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif c.a > 0.01 and c.r < 0.04 and c.g < 0.04 and c.b < 0.04:
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


func _set_gear_icon_id(icon: TextureRect, item_id: int, kind: StringName) -> void:
	if icon == null:
		return
	var path := ""
	if kind == &"weapon":
		path = _WeaponIcons.path_for_id(item_id)
	elif kind == &"armor":
		path = _ArmorIcons.path_for_id(item_id)
	## Hands / No Armour have no art — keep the slot, clear texture.
	icon.texture = _load_keyed_gear_path(path)
	icon.visible = true


func _set_gear_icon(icon: TextureRect, item_name: String, kind: StringName) -> void:
	## Legacy name lookup (inventory rows still use ids via path_for_id).
	if icon == null:
		return
	var path := ""
	if kind == &"weapon":
		path = _WeaponIcons.path_for_name(item_name)
	elif kind == &"armor":
		path = _ArmorIcons.path_for_name(item_name)
	icon.texture = _load_keyed_gear_path(path)
	icon.visible = true


func _load_keyed_gear_path(path: String) -> Texture2D:
	if path.is_empty():
		return null
	var img := Image.new()
	var fs := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if img.load(fs) != OK and img.load(path) != OK:
		var loaded := load(path) as Texture2D
		return _keyed_gear_texture(loaded)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return _keyed_gear_texture(ImageTexture.create_from_image(img))


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
		int(data.get("exp", 0)), int(data.get("exp_next", 0)),
		COL_EXP_READY if bool(data.get("exp_ready", false)) else COL_EXP
	)
	var weapon_id := int(data.get("weapon_id", -1))
	var armor_id := int(data.get("armor_id", -1))
	if _weapon_kind:
		_weapon_kind.text = Locale.t("ztats_weapon_kind")
	if _armor_kind:
		_armor_kind.text = Locale.t("ztats_armor_kind")
	## Prefer localized names from ids (works in ko/en); fall back to legacy string.
	if weapon_id >= 0:
		_weapon.text = Locale.weapon_name(weapon_id)
	else:
		_weapon.text = _localized_item_name(_title_case_words(str(data.get("weapon", "Hands"))))
	if armor_id >= 0:
		_armor.text = Locale.armor_name(armor_id)
	else:
		_armor.text = _localized_item_name(_title_case_words(str(data.get("armor", "No Armour"))))
	_set_gear_icon_id(_weapon_icon, weapon_id, &"weapon")
	_set_gear_icon_id(_armor_icon, armor_id, &"armor")
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


func _request_face_sync() -> void:
	## Wait until after visibility + container sort so INT row Y is real.
	_face_sync_gen += 1
	_face_sync_after_layout(_face_sync_gen)


func _face_sync_after_layout(gen: int) -> void:
	await get_tree().process_frame
	if gen != _face_sync_gen:
		return
	_sync_face_to_int_row()
	## Face width change can reflow the head; settle once more.
	await get_tree().process_frame
	if gen != _face_sync_gen:
		return
	_sync_face_to_int_row()


func _sync_face_to_int_row() -> void:
	## Stretch the portrait so its bottom lines up with the INT attribute row.
	if _face == null or _face_slot == null or _attr_int == null:
		return
	if not is_visible_in_tree() or _char_root == null or not _char_root.visible:
		return
	if _attr_int.size.y < 1.0:
		return
	var face_top := _face_slot.global_position.y
	var int_bottom := _attr_int.global_position.y + _attr_int.size.y
	var h := maxf(float(FACE_SIZE), int_bottom - face_top)
	var w := h * FACE_ASPECT
	_face.size = Vector2(w, h)
	_face_slot.custom_minimum_size = Vector2(w, 0)


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


func _refresh_inventory() -> void:
	if _inv_list == null:
		return
	_pick_ids.clear()
	_pick_row_wraps.clear()
	_pick_cursor = 0
	for c in _inv_list.get_children():
		## Remove now so old and rebuilt rows never share one layout frame.
		_inv_list.remove_child(c)
		c.queue_free()
	_inv_scroll.scroll_vertical = 0
	_inv_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_inv_list.add_theme_constant_override("separation", INV_LIST_SEP)
	match _inv_page:
		InvPage.GEAR:
			_inv_title.text = Locale.t("ztats_page_equipment")
			_fill_gear_page()
		InvPage.WEAPONS:
			_inv_title.text = Locale.t("ztats_page_weapons")
			_fill_weapons_page()
		InvPage.ARMOR:
			_inv_title.text = Locale.t("ztats_page_armor")
			_fill_armor_page()
		InvPage.ITEMS:
			_inv_title.text = Locale.t("ztats_page_items")
			_fill_items_page()
		InvPage.REAGENTS:
			_inv_title.text = Locale.t("ztats_page_reagents")
			_fill_reagents_page()
		InvPage.MIXTURES:
			_inv_title.text = Locale.t("ztats_page_mixtures")
			_fill_mixtures_page()
		_:
			_inv_title.text = "?"
	if _shop_pick:
		_finalize_shop_pick()
	if _inv_keep_scroll and _inv_saved_scroll.has(_inv_page):
		call_deferred("_restore_inv_scroll")
	else:
		_inv_saved_scroll[_inv_page] = 0
	_inv_keep_scroll = false


func _finalize_shop_pick() -> void:
	## After sell: keep preferred item if pack qty remains; else first list row.
	## First open (no prefer): first pack item with qty > 0, else top.
	if _pick_ids.is_empty():
		_pick_prefer_id = -1
		_pick_retain_id = -1
		return
	_pick_cursor = 0
	var prefer := _pick_prefer_id
	_pick_prefer_id = -1
	if prefer >= 0:
		var found := false
		for i in _pick_ids.size():
			if int(_pick_ids[i]) != prefer:
				continue
			found = true
			if _shop_pick_pack_qty(prefer) > 0:
				_pick_cursor = i
			else:
				_pick_cursor = 0
			break
		if not found:
			_pick_cursor = 0
	else:
		for i in _pick_ids.size():
			if _shop_pick_pack_qty(int(_pick_ids[i])) > 0:
				_pick_cursor = i
				break
	_pick_retain_id = int(_pick_ids[_pick_cursor])
	_sync_shop_pick_hilite()
	## Wait for the rebuilt container and scrollbar range to finish layout.
	_pick_scroll_gen += 1
	_settle_shop_pick_scroll(_pick_scroll_gen)


func _settle_shop_pick_scroll(generation: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if generation != _pick_scroll_gen or not has_shop_pick():
		return
	_ensure_shop_pick_visible()


func _shop_pick_pack_qty(item_id: int) -> int:
	if _inv_page == InvPage.WEAPONS:
		return GameState.pack_weapon_qty(item_id)
	if _inv_page == InvPage.ARMOR:
		return GameState.pack_armor_qty(item_id)
	return 0


func _sync_shop_pick_hilite() -> void:
	for i in _pick_row_wraps.size():
		var wrap := _pick_row_wraps[i]
		if wrap == null or not is_instance_valid(wrap):
			continue
		var on := i == _pick_cursor
		for c in wrap.get_children():
			if c is ColorRect and c.has_meta("shop_pick_bg"):
				(c as ColorRect).color = COL_CURSOR if on else Color(0, 0, 0, 0)
			elif c.has_meta("shop_pick_edge"):
				UiTheme.set_selection_edge_active(c, on, COL_CURSOR_EDGE)


func _ensure_shop_pick_visible() -> void:
	## Keep the focused sell row on the middle visible line, like the gamepad menu.
	if not has_shop_pick() or _inv_scroll == null:
		return
	if _pick_cursor < 0 or _pick_cursor >= _pick_row_wraps.size():
		return
	var stride := INV_ROW_H + INV_LIST_SEP
	var view_h := int(_inv_scroll.size.y)
	if view_h <= 0:
		return
	var vis := maxi(1, (view_h + INV_LIST_SEP) / stride)
	var total := _pick_row_wraps.size()
	var next := 0
	if total > vis:
		var center := int(vis / 2)
		next = clampi(_pick_cursor - center, 0, total - vis) * stride
	next = clampi(next, 0, _inv_scroll_max_step())
	_inv_scroll.scroll_vertical = next
	_inv_saved_scroll[_inv_page] = next


func _register_shop_pick_row(wrap: Control, item_id: int) -> void:
	if not _shop_pick or wrap == null:
		return
	_pick_ids.append(item_id)
	_pick_row_wraps.append(wrap)


func _fill_gear_page() -> void:
	## Combined equipment list for normal Ztats.
	_fill_weapons_section(true)
	_fill_armor_section(true)


func _fill_weapons_page() -> void:
	## Shop weapons peek — weapons only, no armor section header.
	_fill_weapons_section(false)


func _fill_armor_page() -> void:
	## Shop armor peek — armor only.
	_fill_armor_section(false)


func _fill_weapons_section(with_section_title: bool) -> void:
	## Letters match xu4 Ready indices (A=Hands even if not listed).
	if with_section_title:
		_add_inv_section(Locale.t("ztats_page_weapons"))
	_add_gear_header(Locale.t("ztats_col_damage"))
	for w in range(1, GameState.weapons.size()): ## skip Hands
		## Once-owned stay listed at qty 0; never-owned stay hidden.
		if not GameState.is_weapon_known(w) and int(GameState.weapons[w]) <= 0:
			continue
		var qty := int(GameState.weapons[w])
		var wname := "%s. %s" % [String.chr(65 + w), Locale.weapon_name(w)]
		var wrap := _add_gear_item_row(
			_load_keyed_gear_path(_WeaponIcons.path_for_id(w)),
			wname,
			_WeaponIcons.damage_of(w),
			qty
		)
		_register_shop_pick_row(wrap, w)


func _fill_armor_section(with_section_title: bool) -> void:
	## Letters match xu4 Wear indices (A=No Armor even if not listed).
	if with_section_title:
		_add_inv_section(Locale.t("ztats_page_armor"))
	_add_gear_header(Locale.t("ztats_col_defense"))
	for a in range(1, GameState.armor.size()): ## skip No Armor
		if not GameState.is_armor_known(a) and int(GameState.armor[a]) <= 0:
			continue
		var qty2 := int(GameState.armor[a])
		var aname := "%s. %s" % [String.chr(65 + a), Locale.armor_name(a)]
		var wrap := _add_gear_item_row(
			_load_keyed_gear_path(_ArmorIcons.path_for_id(a)),
			aname,
			_ArmorIcons.defense_of(a),
			qty2
		)
		_register_shop_pick_row(wrap, a)


func _fill_items_page() -> void:
	## xu4 StatsArea::showItems — stones, runes, quest relics.
	## Torches/gems/keys live on the bottom bar; sextant joins this page.
	var any := false
	if GameState.stones != 0:
		_add_inv_section(Locale.t("ztats_section_stones"))
		for i in 8:
			if (GameState.stones & (1 << i)) == 0:
				continue
			_add_icon_name_row(
				_load_keyed_gear_path(_SpecialItemIcons.stone_path(i)),
				Locale.t(_SpecialItemIcons.stone_name_key(i))
			)
			any = true
	if GameState.runes != 0:
		_add_inv_section(Locale.t("ztats_section_runes"))
		for i in 8:
			if (GameState.runes & (1 << i)) == 0:
				continue
			_add_icon_name_row(
				_load_keyed_gear_path(_RuneIcons.path_for_id(i)),
				_Virtues.name_of(i, GameState.lang_short())
			)
			any = true
	var relics: Array[Dictionary] = []
	if GameState.has_item_flag(GameState.ITEM_BELL):
		relics.append({"path": _SpecialItemIcons.BELL, "key": "ztats_item_bell"})
	if GameState.has_item_flag(GameState.ITEM_BOOK):
		relics.append({"path": _SpecialItemIcons.BOOK, "key": "ztats_item_book"})
	if GameState.has_item_flag(GameState.ITEM_CANDLE):
		relics.append({"path": _SpecialItemIcons.CANDLE, "key": "ztats_item_candle"})
	if GameState.has_item_flag(GameState.ITEM_HORN):
		relics.append({"path": _SpecialItemIcons.HORN, "key": "ztats_item_horn"})
	if GameState.has_item_flag(GameState.ITEM_WHEEL):
		relics.append({"path": _SpecialItemIcons.WHEEL, "key": "ztats_item_wheel"})
	if GameState.has_item_flag(GameState.ITEM_SKULL):
		relics.append({"path": _SpecialItemIcons.SKULL, "key": "ztats_item_skull"})
	if GameState.has_sextant:
		relics.append({"path": _SpecialItemIcons.SEXTANT, "key": "ztats_item_sextant"})
	if not relics.is_empty():
		_add_inv_section(Locale.t("ztats_section_relics"))
		for r in relics:
			_add_icon_name_row(
				_load_keyed_gear_path(str(r.get("path", ""))),
				Locale.t(str(r.get("key", "")))
			)
			any = true
	var keys: Array[Dictionary] = []
	if GameState.has_item_flag(GameState.ITEM_KEY_T):
		keys.append({"path": _SpecialItemIcons.KEY_TRUTH, "key": "ztats_item_key_truth"})
	if GameState.has_item_flag(GameState.ITEM_KEY_L):
		keys.append({"path": _SpecialItemIcons.KEY_LOVE, "key": "ztats_item_key_love"})
	if GameState.has_item_flag(GameState.ITEM_KEY_C):
		keys.append({"path": _SpecialItemIcons.KEY_COURAGE, "key": "ztats_item_key_courage"})
	if not keys.is_empty():
		_add_inv_section(Locale.t("ztats_section_keys"))
		for k in keys:
			_add_icon_name_row(
				_load_keyed_gear_path(str(k.get("path", ""))),
				Locale.t(str(k.get("key", "")))
			)
			any = true
	if not any:
		## Empty party — keep the page readable.
		var hint := Label.new()
		hint.text = Locale.t("ztats_items_none")
		hint.add_theme_font_size_override("font_size", FONT_SIZE)
		hint.add_theme_color_override("font_color", COL_TEXT)
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UiTheme.apply_font(hint)
		var wrap := Control.new()
		wrap.custom_minimum_size = Vector2(0, INV_ROW_H)
		wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		wrap.add_child(hint)
		_inv_list.add_child(wrap)


func _add_icon_name_row(tex: Texture2D, name: String) -> void:
	## Unique quest items — icon + name, no quantity column.
	var inner := _make_inv_inner_row()
	_add_inv_icon(inner, tex)
	_add_inv_name(inner, name)
	_add_inv_static_row(inner)


func _fill_reagents_page() -> void:
	## No item cursor — compact layout sized to never need a scrollbar.
	_inv_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_add_gear_header(Locale.t("ztats_col_qty"), false)
	for r in GameState.reagents.size():
		var letter := "%s. %s" % [String.chr(65 + r), Locale.reagent_name(r)]
		_add_icon_qty_row(
			_load_keyed_gear_path(_ReagentIcons.path_for_id(r)),
			letter,
			int(GameState.reagents[r])
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


func _add_gear_item_row(tex: Texture2D, name: String, stat: int, qty: int) -> Control:
	var inner := _make_inv_inner_row()
	_add_inv_icon(inner, tex)
	_add_inv_name(inner, name)
	_add_inv_num(inner, str(stat), INV_STAT_W)
	_add_inv_num(inner, str(mini(qty, 99)), INV_QTY_W)
	return _add_inv_static_row(inner, _shop_pick)


func _add_icon_qty_row(tex: Texture2D, name: String, qty: int) -> void:
	var inner := _make_inv_inner_row()
	_add_inv_icon(inner, tex)
	_add_inv_name(inner, name)
	_add_inv_num(inner, str(mini(qty, 99)), INV_QTY_W)
	_add_inv_static_row(inner, false)


func _add_inv_static_row(inner: HBoxContainer, with_pick_chrome: bool = false) -> Control:
	## Inventory list row. Shop sell adds Ready-style cursor chrome under the content.
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, INV_ROW_H)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.clip_contents = true
	if with_pick_chrome:
		var bg := ColorRect.new()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.color = Color(0, 0, 0, 0)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_meta("shop_pick_bg", true)
		wrap.add_child(bg)
		var edge := UiTheme.make_selection_edge("shop_pick_edge")
		wrap.add_child(edge)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(inner)
	_inv_list.add_child(wrap)
	return wrap


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
	_add_inv_static_row(inner)


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


func _restore_inv_scroll() -> void:
	if _inv_scroll == null or not _inv_saved_scroll.has(_inv_page):
		return
	var y := int(_inv_saved_scroll[_inv_page])
	## Wait one frame so list min-size is ready, then clamp into range.
	await get_tree().process_frame
	if _inv_scroll == null or _inv_page == InvPage.NONE:
		return
	var stride := INV_ROW_H + INV_LIST_SEP
	var max_step := _inv_scroll_max_step()
	## Snap to row grid so restore never lands on a micro-offset past the last step.
	y = clampi(y, 0, max_step)
	y = (y / stride) * stride
	_inv_scroll.scroll_vertical = y
	_inv_saved_scroll[_inv_page] = y
