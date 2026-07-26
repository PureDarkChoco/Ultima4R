class_name PartyRoster
extends VBoxContainer

## Full: portrait | Lv.N | name | HP | MP | Exp
## Compact: portrait | HP/MP ratio bars (no numbers)
## Status: dead → corpse · poison → green · sleep → purple

enum Status { OK, POISONED, SLEEPING, DEAD }

const SHAPES_PATH := "res://assets/tiles/u4graphics/shapes.png"
const TILE_SRC := 32
const CLASS_TILE_EVEN := [32, 34, 36, 38, 40, 42, 44, 46]

const PORTRAIT_PATHS := [
	"res://assets/portraits/classes/00_mage.png",
	"res://assets/portraits/classes/01_bard.png",
	"res://assets/portraits/classes/02_fighter.png",
	"res://assets/portraits/classes/03_druid.png",
	"res://assets/portraits/classes/04_tinker.png",
	"res://assets/portraits/classes/05_paladin.png",
	"res://assets/portraits/classes/06_ranger.png",
	"res://assets/portraits/classes/07_shepherd.png",
]
## Painted companion / Avatar faces for Ztats sheet (class index 0..7).
const ZTATS_COMPANION_PATHS := [
	"res://assets/portraits/companions/00_mariah.png",
	"res://assets/portraits/companions/01_iolo.png",
	"res://assets/portraits/companions/02_geoffrey.png",
	"res://assets/portraits/companions/03_jaana.png",
	"res://assets/portraits/companions/04_julia.png",
	"res://assets/portraits/companions/05_dupre.png",
	"res://assets/portraits/companions/06_shamino.png",
	"res://assets/portraits/companions/07_katrina.png",
]
const ZTATS_AVATAR_MALE := "res://assets/portraits/companions/avatar_male.png"
const ZTATS_AVATAR_FEMALE := "res://assets/portraits/companions/avatar_female.png"
const CORPSE_PATH := "res://assets/portraits/classes/corpse.png"

const COMPANION_NAMES := [
	"Mariah", "Iolo", "Geoffrey", "Jaana",
	"Julia", "Dupre", "Shamino", "Katrina",
]

const STUB_LEVELS := [8, 5, 7, 4, 3, 6, 5, 1]
const STUB_HP := [250, 110, 88, 180, 35, 0, 38, 160]
const STUB_MP := [180, 45, 0, 150, 12, 0, 60, 0]
const STUB_MAX_HP := [250, 220, 300, 180, 200, 275, 190, 160]
const STUB_MAX_MP := [250, 120, 0, 200, 75, 180, 150, 0]
const STUB_EXP := [4200, 800, 2100, 350, 100, 1800, 1500, 0]
const STUB_EXP_TO_NEXT := [8000, 2000, 5000, 1200, 800, 4000, 3000, 100]
const STUB_STATUS := [
	Status.OK, Status.POISONED, Status.SLEEPING, Status.OK,
	Status.POISONED, Status.DEAD, Status.OK, Status.SLEEPING,
]
## Stub attributes / gear until savegame stats are wired (class-indexed).
const STUB_STR := [22, 16, 28, 14, 18, 24, 18, 12]
const STUB_DEX := [16, 22, 18, 16, 20, 16, 22, 14]
const STUB_INT := [24, 16, 10, 22, 14, 14, 16, 12]
const STUB_WEAPON := [
	"Staff", "Sling", "Axe", "Dagger",
	"Mace", "Magic Sword", "Bow", "Halberd",
]
const STUB_ARMOR := [
	"Cloth", "Leather", "Chain", "Magic Chain",
	"Leather", "Plate", "Magic Plate", "Mystic Robe",
]
## Stub attack / defense from equipped gear (until savegame stats).
const STUB_ATK := [4, 4, 8, 3, 6, 12, 8, 11]
const STUB_DEF := [1, 2, 4, 4, 2, 8, 10, 6]

const ICON_SIZE := 28
const ROW_H := 32
const BAR_H := 14
const BAR_H_COMPACT := 5
const BAR_MIN_W_VITAL := 40.0
const BAR_MIN_W_EXP := 44.0
const NAME_BAR_GAP := 6.0
## Compact strip keeps the same portrait/row height; only width/content differs.
const BAR_MIN_W_COMPACT := 10.0
## Open Tab panel is the pad source of truth (stylebox content + margin).
## Compact strip uses the same total vertical inset so characters stay put.
const ROSTER_STYLE_PAD := 4
const ROSTER_MARGIN_PAD := 6
const ROSTER_PAD := ROSTER_STYLE_PAD + ROSTER_MARGIN_PAD
const ROSTER_SEP := 2

const FRAME_MIN := 0.28
const FRAME_MAX := 0.55
const STATUS_PULSE_PERIOD := 1.2
const HP_CRIT_RATIO := 0.30

const COL_TEXT := Color(0.95, 0.9, 0.72, 1)
const COL_TEXT_LOW := Color(1.0, 1.0, 1.0, 1)
const COL_BAR_TEXT := Color(0.95, 0.95, 0.95, 1)
const COL_TRACK := Color(0.22, 0.22, 0.22, 1)
const COL_HP_OK := Color(0.82, 0.22, 0.2, 1)
const COL_MP_OK := Color(0.3, 0.55, 0.95, 1)
const COL_EXP := Color(0.86, 0.70, 0.16, 1)
const COL_POISON := Color(0.35, 0.78, 0.28, 1)
const COL_SLEEP := Color(0.72, 0.4, 0.95, 1)
const COL_DEAD := Color(0.55, 0.52, 0.48, 1)
const COL_SLEEP_ZZ := Color(1.0, 0.92, 0.28, 1)
## New Order cursor / first-pick highlight.
const COL_ORDER_CURSOR := Color(0.22, 0.42, 0.82, 0.55)
const COL_ORDER_CURSOR_EDGE := Color(0.55, 0.78, 1.0, 0.95)
const COL_ORDER_LOCKED := Color(0.72, 0.52, 0.12, 0.4)
const COL_ORDER_LOCKED_EDGE := Color(0.95, 0.78, 0.3, 0.9)

var _icons: Array[TextureRect] = []
var _sleep_zz: Array[Label] = []
var _levels: Array[Label] = []
var _names: Array[Label] = []
var _name_gaps: Array[Control] = []
var _portraits: Array[Control] = []
var _vitals_row: Array[Control] = []
var _vitals_col: Array[Control] = []
var _hp_track: Array[Control] = []
var _hp_fill: Array[ColorRect] = []
var _hp_lab: Array[Label] = []
var _mp_blocks: Array[Control] = []
var _mp_fill: Array[ColorRect] = []
var _mp_lab: Array[Label] = []
var _exp_track: Array[Control] = []
var _exp_fill: Array[ColorRect] = []
var _exp_lab: Array[Label] = []
var _row_panels: Array[PanelContainer] = []
var _portraits_a: Array[Texture2D] = []
var _portraits_b: Array[Texture2D] = []
var _frame_bit: Array[int] = []
var _frame_cd: Array[float] = []
var _corpse: Texture2D
var _anim_t := 0.0
var _compact := false
## New Order: cursor slot (-1 = off), locked first pick (-1 = none).
var _order_cursor := -1
var _order_locked := -1
## Guard against resize ↔ distribute feedback loops.
var _relayouting := false
## Map tile aspect (w/h). Size stays ICON_SIZE-based; only ratio follows tiles.
var _tile_aspect := 9.0 / 10.0
## Open Tab panel outer height — compact rows/gaps are derived from this.
var _open_outer_h := 0.0
## xu4 stats->flashPlayers: brief red flash on damaged slots.
var _flash_mask := 0
var _flash_t := 0.0
const FLASH_SEC := 0.35
const FLASH_COLOR := Color(1.0, 0.35, 0.28, 1)


func flash_players(mask: int) -> void:
	## Bit i set → party slot i took damage (xu4 flashPlayers).
	if mask == 0:
		return
	_flash_mask = mask
	_flash_t = FLASH_SEC


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_load_portraits()
	_build_slots()
	refresh()
	resized.connect(_on_roster_resized)
	call_deferred("_distribute_rows")
	call_deferred("_relayout_bars")


func _process(delta: float) -> void:
	_anim_t += delta
	for i in _frame_cd.size():
		_frame_cd[i] -= delta
		if _frame_cd[i] <= 0.0:
			_frame_bit[i] = 1 - _frame_bit[i]
			_frame_cd[i] = randf_range(FRAME_MIN, FRAME_MAX)
	_apply_portrait_anim()
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - delta)
		_apply_damage_flash()
		if _flash_t <= 0.0:
			_flash_mask = 0
			_clear_damage_flash()


func _apply_damage_flash() -> void:
	## Pulse damaged roster rows while flash timer is active.
	var pulse := 0.55 + 0.45 * absf(sin(_flash_t * TAU * 4.0))
	for i in mini(8, _row_panels.size()):
		if _flash_mask & (1 << i):
			if _row_panels[i]:
				_row_panels[i].modulate = Color(
					lerpf(1.0, FLASH_COLOR.r, pulse),
					lerpf(1.0, FLASH_COLOR.g, pulse),
					lerpf(1.0, FLASH_COLOR.b, pulse),
					1.0
				)


func _clear_damage_flash() -> void:
	for i in mini(8, _row_panels.size()):
		if _row_panels[i]:
			_row_panels[i].modulate = Color.WHITE


func packed_height() -> float:
	return compact_panel_height()


func apply_pad_offsets() -> void:
	_apply_roster_pad_offsets()


func apply_shared_pad_to_margins(margin: MarginContainer) -> void:
	## Open panel: margin only (stylebox carries ROSTER_STYLE_PAD separately).
	if margin == null:
		return
	margin.add_theme_constant_override("margin_left", ROSTER_MARGIN_PAD)
	margin.add_theme_constant_override("margin_top", ROSTER_MARGIN_PAD)
	margin.add_theme_constant_override("margin_right", ROSTER_MARGIN_PAD)
	margin.add_theme_constant_override("margin_bottom", ROSTER_MARGIN_PAD)


func _apply_roster_pad_offsets() -> void:
	## Compact Panel has no stylebox content pad — use combined ROSTER_PAD.
	offset_top = float(ROSTER_PAD)
	offset_bottom = float(-ROSTER_PAD)
	offset_left = float(ROSTER_PAD)
	offset_right = float(-ROSTER_PAD)


func set_tile_size(px: Vector2) -> void:
	## Keep icon pixel size; only sync width/height ratio to map tiles.
	if px.x < 1.0 or px.y < 1.0:
		return
	var a := px.x / px.y
	if is_equal_approx(a, _tile_aspect):
		return
	_tile_aspect = a
	if is_inside_tree():
		relayout()


func set_open_panel_height(outer_h: float) -> void:
	## Open right-top pane height is the vertical reference for compact slots.
	if outer_h < 8.0:
		return
	if is_equal_approx(_open_outer_h, outer_h):
		return
	_open_outer_h = outer_h
	if is_inside_tree():
		relayout()


func _open_content_height() -> float:
	## Roster area inside open panel: minus stylebox + margin pads (both sides).
	if _open_outer_h >= 8.0:
		return maxf(
			_open_outer_h - float(ROSTER_STYLE_PAD * 2 + ROSTER_MARGIN_PAD * 2),
			8.0
		)
	## Fallback when full roster is already laid out.
	return maxf(size.y, 8.0)


func _eight_slot_metrics(content_h: float) -> Dictionary:
	## Same split the open Tab roster uses for 8 equal bands.
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
	var used := row_h * 8.0 + float(sep * 7)
	var leftover := int(floorf(content_h - used))
	return {"row_h": row_h, "sep": sep, "leftover": leftover}


func _icon_for_row(row_h: float) -> Vector2:
	var fit_h := minf(maxf(row_h - 2.0, 12.0), float(ICON_SIZE))
	return Vector2(fit_h * _tile_aspect, fit_h)


func compact_panel_height(member_count: int = -1) -> float:
	## Top n open-panel slots only — same row_h / sep as when Tab is open.
	var n := member_count if member_count >= 0 else GameState.party_size()
	n = clampi(n, 1, 8)
	var m := _eight_slot_metrics(_open_content_height())
	var row_h: float = m["row_h"]
	var sep: int = m["sep"]
	return float(
		ROSTER_PAD
		+ ROSTER_PAD
		+ n * row_h
		+ maxi(n - 1, 0) * sep
	)


func visible_row_count() -> int:
	## Compact: only active members. Full: always 8 bands.
	if _compact:
		return clampi(GameState.party_size(), 1, 8)
	return 8


func set_compact(on: bool) -> void:
	_compact = on
	size_flags_vertical = (
		Control.SIZE_SHRINK_BEGIN if _compact else Control.SIZE_EXPAND_FILL
	)
	_apply_compact_visuals()
	custom_minimum_size = Vector2(0, 0)
	call_deferred("_distribute_rows")
	call_deferred("_relayout_bars")


func is_compact() -> bool:
	return _compact


func relayout() -> void:
	_distribute_rows()
	_relayout_bars()


func _on_roster_resized() -> void:
	if _relayouting:
		return
	_relayouting = true
	_distribute_rows()
	_relayout_bars()
	_relayouting = false


func _distribute_rows() -> void:
	## Open panel defines 8 equal vertical slots. Compact shows the top n of those
	## slots with the same row_h / separation (characters stay vertically aligned).
	if get_child_count() < 8:
		return
	var active := clampi(GameState.party_size(), 1, 8)
	var content_h := _open_content_height() if _compact or _open_outer_h >= 8.0 else maxf(size.y, 8.0)
	if not _compact and size.y >= 8.0:
		content_h = size.y
	var m := _eight_slot_metrics(content_h)
	var row_h: float = m["row_h"]
	var sep: int = m["sep"]
	var leftover: int = m["leftover"]
	var icon := _icon_for_row(row_h)

	if _compact:
		add_theme_constant_override("separation", sep if active > 1 else 0)
		_apply_roster_pad_offsets()
		for i in 8:
			var row := get_child(i) as Control
			if row == null:
				continue
			if i < active:
				var rh := row_h + (1.0 if i < leftover else 0.0)
				row.visible = true
				row.custom_minimum_size = Vector2(0, rh)
				row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
				row.size_flags_stretch_ratio = 0.0
				row.modulate = Color.WHITE
				if i < _portraits.size() and _portraits[i]:
					_portraits[i].custom_minimum_size = icon
				if i < _hp_track.size() and _hp_track[i]:
					_hp_track[i].custom_minimum_size = Vector2(BAR_MIN_W_COMPACT, BAR_H_COMPACT)
					_hp_track[i].visible = true
				if i < _mp_blocks.size() and _mp_blocks[i]:
					_mp_blocks[i].custom_minimum_size = Vector2(BAR_MIN_W_COMPACT, BAR_H_COMPACT)
					_mp_blocks[i].visible = true
			else:
				row.visible = false
				row.custom_minimum_size = Vector2.ZERO
				row.size_flags_stretch_ratio = 0.0
		return

	## Full (Tab) — 8 equal bands; empty bands stay blank.
	add_theme_constant_override("separation", sep)
	for i in 8:
		var row := get_child(i) as Control
		if row == null:
			continue
		row.visible = true
		var rh := row_h + (1.0 if i < leftover else 0.0)
		row.custom_minimum_size = Vector2(0, rh)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.size_flags_stretch_ratio = 1.0
		row.modulate = Color.WHITE
		if i < _portraits.size() and _portraits[i]:
			_portraits[i].custom_minimum_size = icon


func _apply_compact_visuals() -> void:
	## Same portrait / row height as full panel — only hide text & restack HP/MP.
	if _names.is_empty():
		return
	for i in 8:
		var filled := GameState.party_member_at(i) >= 0
		var row := get_child(i) as Control
		if row:
			row.size_flags_vertical = Control.SIZE_EXPAND_FILL
			row.size_flags_stretch_ratio = 1.0
			if row is BoxContainer:
				(row as BoxContainer).alignment = BoxContainer.ALIGNMENT_BEGIN
		if not filled:
			_set_row_contents_visible(i, false)
			continue
		if i < _levels.size() and _levels[i]:
			_levels[i].visible = not _compact
		if i < _names.size() and _names[i]:
			_names[i].visible = not _compact
		if i < _name_gaps.size() and _name_gaps[i]:
			_name_gaps[i].visible = not _compact
		if i < _vitals_row.size() and _vitals_row[i]:
			_vitals_row[i].visible = not _compact
		if i < _vitals_col.size() and _vitals_col[i]:
			_vitals_col[i].visible = _compact
		if i < _hp_lab.size() and _hp_lab[i]:
			_hp_lab[i].visible = not _compact
		if i < _mp_lab.size() and _mp_lab[i]:
			_mp_lab[i].visible = not _compact
		if i < _portraits.size() and _portraits[i]:
			_portraits[i].visible = true
		if i < _icons.size() and _icons[i]:
			_icons[i].visible = true
		if i < _hp_track.size() and _hp_track[i]:
			_hp_track[i].custom_minimum_size = Vector2(
				BAR_MIN_W_COMPACT if _compact else BAR_MIN_W_VITAL,
				BAR_H_COMPACT if _compact else BAR_H
			)
		if i < _mp_blocks.size() and _mp_blocks[i]:
			_mp_blocks[i].custom_minimum_size = Vector2(
				BAR_MIN_W_COMPACT if _compact else BAR_MIN_W_VITAL,
				BAR_H_COMPACT if _compact else BAR_H
			)
		if i < _vitals_col.size() and i < _vitals_row.size():
			var dest: Control = _vitals_col[i] if _compact else _vitals_row[i]
			if _hp_track[i].get_parent() != dest:
				_hp_track[i].reparent(dest)
			if _mp_blocks[i].get_parent() != dest:
				_mp_blocks[i].reparent(dest)
			if not _compact and _exp_track[i].get_parent() != _vitals_row[i]:
				_exp_track[i].reparent(_vitals_row[i])
			_exp_track[i].visible = not _compact
	## Don't call _distribute_rows here — refresh/set_compact own that.


func _build_slots() -> void:
	for c in get_children():
		c.queue_free()
	_icons.clear()
	_sleep_zz.clear()
	_levels.clear()
	_names.clear()
	_name_gaps.clear()
	_portraits.clear()
	_vitals_row.clear()
	_vitals_col.clear()
	_hp_track.clear()
	_hp_fill.clear()
	_hp_lab.clear()
	_mp_blocks.clear()
	_mp_fill.clear()
	_mp_lab.clear()
	_exp_track.clear()
	_exp_fill.clear()
	_exp_lab.clear()
	_row_panels.clear()
	_frame_bit.clear()
	_frame_cd.clear()
	custom_minimum_size = Vector2(0, 0)

	for i in 8:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.size_flags_stretch_ratio = 1.0
		panel.custom_minimum_size = Vector2(0, 12)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", _order_row_style(-1, -1, i))

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
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.add_child(icon)

		var zz := Label.new()
		zz.text = "zZ"
		zz.visible = false
		zz.mouse_filter = Control.MOUSE_FILTER_IGNORE
		## ~2/3 of prior size; top-right of the glyph box stays put.
		zz.add_theme_font_size_override("font_size", 5)
		zz.add_theme_color_override("font_color", COL_SLEEP_ZZ)
		UiTheme.apply_font(zz)
		zz.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		zz.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		zz.anchor_left = 1.0
		zz.anchor_right = 1.0
		zz.anchor_top = 0.0
		zz.anchor_bottom = 0.0
		zz.offset_left = -14.0
		zz.offset_right = -2.0
		zz.offset_top = -1.0
		zz.offset_bottom = 8.0
		portrait.add_child(zz)

		var level := Label.new()
		level.custom_minimum_size = Vector2(32, 0)
		level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		level.size_flags_horizontal = Control.SIZE_SHRINK_END
		level.add_theme_font_size_override("font_size", 12)
		level.add_theme_color_override("font_color", COL_TEXT)
		UiTheme.apply_font(level)
		level.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var name := Label.new()
		name.custom_minimum_size = Vector2(56, 0)
		name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name.add_theme_font_size_override("font_size", 13)
		UiTheme.apply_font(name)
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var name_gap := Control.new()
		name_gap.custom_minimum_size = Vector2(NAME_BAR_GAP, 0)
		name_gap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		name_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var hp := _make_bar(BAR_MIN_W_VITAL, 1.0)
		var mp := _make_bar(BAR_MIN_W_VITAL, 1.0)
		var expb := _make_bar(BAR_MIN_W_EXP, 1.05)

		var vitals_row := HBoxContainer.new()
		vitals_row.add_theme_constant_override("separation", 5)
		vitals_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vitals_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vitals_row.add_child(hp["track"])
		vitals_row.add_child(mp["track"])
		vitals_row.add_child(expb["track"])

		var vitals_col := VBoxContainer.new()
		vitals_col.add_theme_constant_override("separation", 2)
		vitals_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vitals_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vitals_col.visible = false

		row.add_child(portrait)
		row.add_child(level)
		row.add_child(name)
		row.add_child(name_gap)
		row.add_child(vitals_row)
		row.add_child(vitals_col)
		panel.add_child(row)
		add_child(panel)

		_row_panels.append(panel)
		_icons.append(icon)
		_sleep_zz.append(zz)
		_portraits.append(portrait)
		_levels.append(level)
		_names.append(name)
		_name_gaps.append(name_gap)
		_vitals_row.append(vitals_row)
		_vitals_col.append(vitals_col)
		_hp_track.append(hp["track"])
		_hp_fill.append(hp["fill"])
		_hp_lab.append(hp["lab"])
		_mp_blocks.append(mp["track"])
		_mp_fill.append(mp["fill"])
		_mp_lab.append(mp["lab"])
		_exp_track.append(expb["track"])
		_exp_fill.append(expb["fill"])
		_exp_lab.append(expb["lab"])
		_frame_bit.append(randi() & 1)
		_frame_cd.append(randf_range(FRAME_MIN, FRAME_MAX))

	_apply_compact_visuals()
	call_deferred("_distribute_rows")


func set_order_selection(cursor: int, locked: int = -1) -> void:
	## Highlight New Order cursor; `locked` = first pick already chosen.
	_order_cursor = cursor
	_order_locked = locked
	_apply_order_selection()


func clear_order_selection() -> void:
	_order_cursor = -1
	_order_locked = -1
	_apply_order_selection()


static func status_label(st: int) -> String:
	match st:
		Status.POISONED:
			return Locale.t("ztats_status_poisoned")
		Status.SLEEPING:
			return Locale.t("ztats_status_sleeping")
		Status.DEAD:
			return Locale.t("ztats_status_dead")
		_:
			return Locale.t("ztats_status_good")


static func member_ztats(slot: int) -> Dictionary:
	## Snapshot for Ztats sheet. Keys match ZtatsPanel expectations.
	var mid := GameState.party_member_at(slot)
	if mid < 0 or mid > 7:
		return {}
	var player_cls := GameState.player_class
	if player_cls < 0:
		player_cls = GameState.party_leader_class()
	var nm := ""
	if mid == player_cls:
		nm = GameState.player_name if not GameState.player_name.is_empty() else "Avatar"
	else:
		nm = COMPANION_NAMES[mid]
	var sex := "M"
	if mid == player_cls:
		sex = "F" if GameState.player_sex == "female" else "M"
	elif mid in [0, 3, 4, 7]:
		## Classic companions: Mariah/Jaana/Julia/Katrina female.
		sex = "F"
	var st: int = GameState.status_of_class(mid)
	## Class tile: corpse when dead (same as roster). Face: always the painted portrait.
	var tile: Texture2D = _ztats_class_tile(mid)
	if st == Status.DEAD:
		tile = _load_texture_file(CORPSE_PATH)
	var face: Texture2D = _ztats_face_portrait(mid, mid == player_cls)
	var lang := GameState.lang_short()
	var wid := GameState.weapon_of_class(mid)
	var aid := GameState.armor_of_class(mid)
	return {
		"name": nm,
		"sex": sex,
		"class": Virtues.class_name_of(mid, lang),
		"status": status_label(st),
		"status_code": st,
		"mp": GameState.mp_of_class(mid),
		"max_mp": GameState.max_mp_of_class(mid),
		"level": GameState.level_of_class(mid),
		"str": GameState.str_of_class(mid),
		"dex": GameState.dex_of_class(mid),
		"int": GameState.int_of_class(mid),
		"hp": GameState.hp_of_class(mid),
		"max_hp": GameState.max_hp_of_class(mid),
		"exp": GameState.xp_of_class(mid),
		"exp_next": GameState.xp_next_of_class(mid),
		"weapon": Locale.weapon_name(wid),
		"armor": Locale.armor_name(aid),
		"atk": WeaponIcons.damage_of(wid),
		"def": ArmorIcons.defense_of(aid),
		"tile": tile,
		"portrait": face,
	}


static func _ztats_class_tile(klass: int) -> Texture2D:
	## Same class tile used in the party roster strip.
	if klass < 0 or klass >= PORTRAIT_PATHS.size():
		return null
	var atlas := Image.new()
	if atlas.load(SHAPES_PATH) == OK:
		if atlas.get_format() != Image.FORMAT_RGBA8:
			atlas.convert(Image.FORMAT_RGBA8)
		var even: int = CLASS_TILE_EVEN[klass]
		var max_tid := atlas.get_height() / TILE_SRC - 1
		if even >= 0 and even <= max_tid:
			var slice := Image.create(TILE_SRC, TILE_SRC, false, Image.FORMAT_RGBA8)
			slice.blit_rect(atlas, Rect2i(0, even * TILE_SRC, TILE_SRC, TILE_SRC), Vector2i.ZERO)
			_key_black_static(slice)
			return ImageTexture.create_from_image(slice)
	return _load_texture_file(PORTRAIT_PATHS[klass])


static func _ztats_face_portrait(klass: int, is_avatar: bool) -> Texture2D:
	## Avatar → gender face; companions → painted class portrait.
	var path := ""
	if is_avatar:
		path = ZTATS_AVATAR_FEMALE if GameState.player_sex == "female" else ZTATS_AVATAR_MALE
	elif klass >= 0 and klass < ZTATS_COMPANION_PATHS.size():
		path = ZTATS_COMPANION_PATHS[klass]
	if path.is_empty():
		return null
	return _load_texture_file(path)


static func _load_texture_file(path: String) -> Texture2D:
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	var loaded := load(path) as Texture2D
	return loaded


static func _key_black_static(img: Image) -> void:
	## Match roster chroma-key so black tile bg is transparent.
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
				img.set_pixel(x, y, Color(0, 0, 0, 0))


func _order_row_style(cursor: int, locked: int, index: int) -> StyleBoxFlat:
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
	if index == cursor:
		sb.bg_color = COL_ORDER_CURSOR
		sb.border_color = COL_ORDER_CURSOR_EDGE
		sb.border_width_left = 3
	elif index == locked:
		sb.bg_color = COL_ORDER_LOCKED
		sb.border_color = COL_ORDER_LOCKED_EDGE
		sb.border_width_left = 3
	return sb


func _apply_order_selection() -> void:
	for i in _row_panels.size():
		var panel := _row_panels[i]
		if panel == null:
			continue
		panel.add_theme_stylebox_override(
			"panel", _order_row_style(_order_cursor, _order_locked, i)
		)


func _load_portraits() -> void:
	_portraits_a.clear()
	_portraits_b.clear()
	var atlas := _load_shapes_atlas()
	for i in 8:
		var tex_a: Texture2D = null
		var tex_b: Texture2D = null
		if atlas != null:
			var even: int = CLASS_TILE_EVEN[i]
			tex_a = _slice_keyed_tile(atlas, even)
			tex_b = _slice_keyed_tile(atlas, even + 1)
		if tex_a == null:
			tex_a = _load_keyed_portrait(PORTRAIT_PATHS[i])
		if tex_b == null:
			tex_b = tex_a
		_portraits_a.append(tex_a)
		_portraits_b.append(tex_b)
	_corpse = _load_keyed_portrait(CORPSE_PATH)


func _load_shapes_atlas() -> Image:
	var img := Image.new()
	if img.load(SHAPES_PATH) != OK:
		var loaded := load(SHAPES_PATH) as Texture2D
		if loaded == null:
			return null
		img = loaded.get_image()
		if img == null or img.is_empty():
			return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


func _slice_keyed_tile(atlas: Image, tile_id: int) -> Texture2D:
	var max_tid := atlas.get_height() / TILE_SRC - 1
	if tile_id < 0 or tile_id > max_tid:
		return null
	var slice := Image.create(TILE_SRC, TILE_SRC, false, Image.FORMAT_RGBA8)
	slice.blit_rect(atlas, Rect2i(0, tile_id * TILE_SRC, TILE_SRC, TILE_SRC), Vector2i.ZERO)
	_key_black(slice)
	return ImageTexture.create_from_image(slice)


func _load_keyed_portrait(path: String) -> Texture2D:
	var img := Image.new()
	if img.load(path) != OK:
		var loaded := load(path) as Texture2D
		if loaded == null:
			return null
		img = loaded.get_image()
		if img == null or img.is_empty():
			return loaded
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	_key_black(img)
	return ImageTexture.create_from_image(img)


func _key_black(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
				img.set_pixel(x, y, Color(0, 0, 0, 0))



func _make_bar(min_w: float, stretch: float) -> Dictionary:
	## Dark track + colored fill + centered "cur / max" (hidden in compact).
	var track := Control.new()
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_stretch_ratio = stretch
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.custom_minimum_size = Vector2(min_w, BAR_H)
	track.clip_contents = true
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	lab.add_theme_font_size_override("font_size", 9)
	lab.add_theme_color_override("font_color", COL_BAR_TEXT)
	UiTheme.apply_font(lab)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track.add_child(lab)

	track.resized.connect(func() -> void: _apply_fill_width(fill))
	return {"track": track, "fill": fill, "lab": lab}


func refresh() -> void:
	if _names.is_empty():
		return
	var pname := GameState.player_name if GameState.player_name else "Avatar"
	var player_cls := GameState.player_class
	if player_cls < 0:
		player_cls = GameState.party_leader_class()
	var active := GameState.party_size()

	for i in 8:
		var row := get_child(i) as Control
		var mid: int = GameState.party_member_at(i)
		var filled := mid >= 0
		if row:
			row.modulate = Color.WHITE
			## Compact: hide empty member area. Full: keep band, show nothing inside.
			if _compact:
				row.visible = i < active
			else:
				row.visible = true

		if not filled:
			_set_row_contents_visible(i, false)
			if i < _icons.size() and _icons[i]:
				_icons[i].texture = null
			continue

		_set_row_contents_visible(i, true)
		var st: int = GameState.status_of_class(mid)
		var hp: int = GameState.hp_of_class(mid)
		var mp: int = GameState.mp_of_class(mid)
		var mhp: int = GameState.max_hp_of_class(mid)
		var mmp: int = GameState.max_mp_of_class(mid)
		if st == Status.DEAD:
			hp = 0
			mp = 0

		var lv: int = GameState.level_of_class(mid)
		_levels[i].text = "Lv.%d" % lv
		if mid == player_cls:
			_names[i].text = pname
		else:
			_names[i].text = COMPANION_NAMES[mid]

		var name_col := COL_TEXT if lv >= 8 else COL_TEXT_LOW
		match st:
			Status.DEAD:
				name_col = COL_DEAD
			Status.POISONED:
				name_col = COL_POISON
			Status.SLEEPING:
				name_col = COL_SLEEP
		_names[i].add_theme_color_override("font_color", name_col)
		_levels[i].add_theme_color_override("font_color", COL_TEXT if lv >= 8 else COL_TEXT_LOW)

		_set_bar(_hp_fill[i], _hp_lab[i], hp, mhp, &"hp")
		if mmp <= 0:
			_set_bar_empty(_mp_fill[i], _mp_lab[i])
		else:
			_set_bar(_mp_fill[i], _mp_lab[i], mp, mmp, &"mp")
		_set_bar(_exp_fill[i], _exp_lab[i], GameState.xp_of_class(mid), GameState.xp_next_of_class(mid), &"exp")

	_apply_compact_visuals()
	_distribute_rows()
	_apply_portrait_anim()
	_apply_order_selection()
	call_deferred("_relayout_bars")


func _set_row_contents_visible(i: int, on: bool) -> void:
	## Empty Tab slots: nothing drawn (no gray placeholders).
	if i < _portraits.size() and _portraits[i]:
		_portraits[i].visible = on
	if i < _icons.size() and _icons[i]:
		_icons[i].visible = on
	if i < _sleep_zz.size() and _sleep_zz[i] and not on:
		_sleep_zz[i].visible = false
	if i < _levels.size() and _levels[i]:
		_levels[i].visible = on and not _compact
	if i < _names.size() and _names[i]:
		_names[i].visible = on and not _compact
	if i < _name_gaps.size() and _name_gaps[i]:
		_name_gaps[i].visible = on and not _compact
	if i < _vitals_row.size() and _vitals_row[i]:
		_vitals_row[i].visible = on and not _compact
	if i < _vitals_col.size() and _vitals_col[i]:
		_vitals_col[i].visible = on and _compact
	if i < _hp_lab.size() and _hp_lab[i]:
		_hp_lab[i].visible = on and not _compact
	if i < _mp_lab.size() and _mp_lab[i]:
		_mp_lab[i].visible = on and not _compact
	if i < _exp_track.size() and _exp_track[i]:
		_exp_track[i].visible = on and not _compact
	if i < _hp_track.size() and _hp_track[i] and not on:
		_hp_track[i].visible = false
	elif i < _hp_track.size() and _hp_track[i] and on:
		_hp_track[i].visible = true
	if i < _mp_blocks.size() and _mp_blocks[i] and not on:
		_mp_blocks[i].visible = false
	elif i < _mp_blocks.size() and _mp_blocks[i] and on:
		_mp_blocks[i].visible = true


func _apply_portrait_anim() -> void:
	if _icons.is_empty():
		return
	for i in 8:
		var mid: int = GameState.party_member_at(i)
		if mid < 0:
			continue
		var st: int = GameState.status_of_class(mid)
		var icon := _icons[i]
		var mhp: int = GameState.max_hp_of_class(mid)
		var hp: int = GameState.hp_of_class(mid)
		var hp_ratio := 0.0 if mhp <= 0 else float(hp) / float(mhp)
		var hp_critical := hp_ratio <= HP_CRIT_RATIO and st != Status.DEAD

		if st == Status.DEAD:
			icon.texture = _corpse
			icon.modulate = Color(0.75, 0.72, 0.68, 1)
			_hp_fill[i].color = COL_TRACK
			if i < _sleep_zz.size():
				_sleep_zz[i].visible = false
			continue

		var use_b := false
		if st != Status.SLEEPING and i < _frame_bit.size():
			use_b = _frame_bit[i] == 1

		var tex_a: Texture2D = _portraits_a[mid] if mid < _portraits_a.size() else null
		var tex_b: Texture2D = _portraits_b[mid] if mid < _portraits_b.size() else tex_a
		icon.texture = tex_b if use_b and tex_b != null else tex_a
		icon.modulate = Color.WHITE

		if i < _sleep_zz.size():
			_sleep_zz[i].visible = st == Status.SLEEPING

		# Status beats low-HP: poison / sleep before red pulse.
		match st:
			Status.POISONED:
				icon.modulate = _status_tint_pulse(COL_POISON)
			Status.SLEEPING:
				# Static purple filter only — no frame blink, no tint pulse.
				icon.modulate = Color(0.78, 0.55, 0.95, 1)
			_:
				if hp_critical:
					icon.modulate = _status_tint_pulse(COL_HP_OK)
				else:
					icon.modulate = Color(1, 1, 1, 1)

		# HP bar: solid — poison green, otherwise red. No bar blink.
		if st == Status.POISONED:
			_hp_fill[i].color = COL_POISON
		else:
			_hp_fill[i].color = COL_HP_OK


func _status_tint_pulse(tint_color: Color) -> Color:
	## Base → tint; all slots share one clock (poison green & crit red in sync).
	var pulse := 0.5 + 0.5 * sin(_anim_t * TAU / STATUS_PULSE_PERIOD)
	var tint := 0.28 + 0.52 * pulse
	return Color(1, 1, 1, 1).lerp(tint_color, tint)


func _fill_color(_ratio: float, kind: StringName) -> Color:
	if kind == &"exp":
		return COL_EXP
	if kind == &"hp":
		return COL_HP_OK
	# MP: always blue — no warn/crit recolor.
	return COL_MP_OK


func _set_bar(fill: ColorRect, lab: Label, cur: int, mx: int, kind: StringName) -> void:
	lab.text = "%d / %d" % [cur, mx]
	var ratio := 0.0 if mx <= 0 else clampf(float(cur) / float(mx), 0.0, 1.0)
	fill.set_meta("ratio", ratio)
	fill.color = _fill_color(ratio, kind)


func _set_bar_empty(fill: ColorRect, lab: Label) -> void:
	lab.text = "-"
	fill.set_meta("ratio", 0.0)
	fill.color = COL_TRACK


func _relayout_bars() -> void:
	for fill in _hp_fill:
		_apply_fill_width(fill)
	for fill in _mp_fill:
		_apply_fill_width(fill)
	for fill in _exp_fill:
		_apply_fill_width(fill)


func _apply_fill_width(fill: ColorRect) -> void:
	var track := fill.get_parent() as Control
	if track == null:
		return
	var ratio := float(fill.get_meta("ratio", 0.0))
	var bar_h := float(BAR_H_COMPACT if _compact else BAR_H)
	fill.position = Vector2.ZERO
	fill.size = Vector2(
		track.size.x * ratio,
		track.size.y if track.size.y > 0.0 else bar_h
	)
