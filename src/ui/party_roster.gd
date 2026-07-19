class_name PartyRoster
extends VBoxContainer

## portrait | Lv.N | name | HP | MP | Exp
## Status: dead → corpse · poison → green · sleep → purple
## HP red (portrait blink ≤30%) / MP blue · Exp gold/amber
## Portraits: SHAPES even/odd 2-frame idle + status modulate

enum Status { OK, POISONED, SLEEPING, DEAD }

const SHAPES_PATH := "res://assets/tiles/u4graphics/shapes.png"
const TILE_SRC := 32
## Class sprite even tiles (odd = even + 1).
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
const CORPSE_PATH := "res://assets/portraits/classes/corpse.png"

const COMPANION_NAMES := [
	"Mariah", "Iolo", "Geoffrey", "Jaana",
	"Julia", "Dupre", "Shamino", "Katrina",
]

## Sample levels (shown as Lv.N before the name).
const STUB_LEVELS := [8, 5, 7, 4, 3, 6, 5, 1]

## Sample vitals (3-digit ready) — ratios exercise color bands.
const STUB_HP := [250, 110, 88, 180, 35, 0, 38, 160]
const STUB_MP := [180, 45, 0, 150, 12, 0, 60, 0]
const STUB_MAX_HP := [250, 220, 300, 180, 200, 275, 190, 160]
## Fighter / Shepherd: no mana (0).
const STUB_MAX_MP := [250, 120, 0, 200, 75, 180, 150, 0]

## Exp toward next level: current / needed (within this level).
const STUB_EXP := [4200, 800, 2100, 350, 100, 1800, 1500, 0]
const STUB_EXP_TO_NEXT := [8000, 2000, 5000, 1200, 800, 4000, 3000, 100]

const STUB_STATUS := [
	Status.OK, # Mariah
	Status.POISONED, # Iolo
	Status.SLEEPING, # Geoffrey
	Status.OK, # Jaana
	Status.POISONED, # Julia (critical HP — poison wins over red)
	Status.DEAD, # Dupre
	Status.OK, # Shamino (critical HP — red portrait pulse)
	Status.SLEEPING, # Katrina
]

const ICON_SIZE := 36
const ROW_H := 40
const BAR_H := 18
const BAR_MIN_W_VITAL := 46.0 # HP / MP
const BAR_MIN_W_EXP := 50.0
const NAME_BAR_GAP := 10.0 # space between name and first bar

## Idle frame dwell — randomized each flip (min…max), never stuck long.
const FRAME_MIN := 0.28
const FRAME_MAX := 0.55
## Shared period for poison green / critical-HP red pulse (portrait + HP bar).
const STATUS_PULSE_PERIOD := 1.2
## HP at or below this → red pulse on portrait & HP bar.
const HP_CRIT_RATIO := 0.30

const COL_TEXT := Color(0.95, 0.9, 0.72, 1) # Lv.8+ name / level
const COL_TEXT_LOW := Color(1.0, 1.0, 1.0, 1) # Lv.1–7
const COL_BAR_TEXT := Color(0.95, 0.95, 0.95, 1)
const COL_TRACK := Color(0.22, 0.22, 0.22, 1)
const COL_HP_OK := Color(0.82, 0.22, 0.2, 1) # red health
const COL_MP_OK := Color(0.3, 0.55, 0.95, 1) # blue
const COL_EXP := Color(0.92, 0.78, 0.22, 1) # gold / amber — common XP bar color
const COL_POISON := Color(0.35, 0.78, 0.28, 1)
const COL_SLEEP := Color(0.72, 0.4, 0.95, 1)
const COL_DEAD := Color(0.55, 0.52, 0.48, 1)
const COL_SLEEP_ZZ := Color(1.0, 0.92, 0.28, 1) # tiny zZ marker

var _icons: Array[TextureRect] = []
var _sleep_zz: Array[Label] = []
var _levels: Array[Label] = []
var _names: Array[Label] = []
var _hp_fill: Array[ColorRect] = []
var _hp_lab: Array[Label] = []
var _mp_blocks: Array[Control] = []
var _mp_fill: Array[ColorRect] = []
var _mp_lab: Array[Label] = []
var _exp_fill: Array[ColorRect] = []
var _exp_lab: Array[Label] = []
var _portraits_a: Array[Texture2D] = []
var _portraits_b: Array[Texture2D] = []
var _frame_bit: Array[int] = []
var _frame_cd: Array[float] = []
var _corpse: Texture2D
var _anim_t := 0.0


func _ready() -> void:
	add_theme_constant_override("separation", 1)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_load_portraits()
	_build_slots()
	refresh()
	resized.connect(_relayout_bars)
	call_deferred("_relayout_bars")


func _process(delta: float) -> void:
	_anim_t += delta
	for i in _frame_cd.size():
		_frame_cd[i] -= delta
		if _frame_cd[i] <= 0.0:
			_frame_bit[i] = 1 - _frame_bit[i]
			_frame_cd[i] = randf_range(FRAME_MIN, FRAME_MAX)
	_apply_portrait_anim()


func packed_height() -> float:
	return float(8 * ROW_H + 7 * 1)


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


func _build_slots() -> void:
	for c in get_children():
		c.queue_free()
	_icons.clear()
	_sleep_zz.clear()
	_levels.clear()
	_names.clear()
	_hp_fill.clear()
	_hp_lab.clear()
	_mp_blocks.clear()
	_mp_fill.clear()
	_mp_lab.clear()
	_exp_fill.clear()
	_exp_lab.clear()
	_frame_bit.clear()
	_frame_cd.clear()
	custom_minimum_size = Vector2(0, packed_height())

	for i in 8:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0, ROW_H)
		row.alignment = BoxContainer.ALIGNMENT_CENTER

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
		zz.add_theme_font_size_override("font_size", 8)
		zz.add_theme_color_override("font_color", COL_SLEEP_ZZ)
		zz.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		zz.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		zz.anchor_left = 1.0
		zz.anchor_right = 1.0
		zz.anchor_top = 0.0
		zz.anchor_bottom = 0.0
		zz.offset_left = -20.0
		zz.offset_right = -2.0
		zz.offset_top = -1.0
		zz.offset_bottom = 12.0
		portrait.add_child(zz)

		var level := Label.new()
		level.custom_minimum_size = Vector2(40, 0)
		level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		level.size_flags_horizontal = Control.SIZE_SHRINK_END
		level.add_theme_font_size_override("font_size", 14)
		level.add_theme_color_override("font_color", COL_TEXT)
		level.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var name := Label.new()
		name.custom_minimum_size = Vector2(70, 0)
		name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name.add_theme_font_size_override("font_size", 16)
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var name_gap := Control.new()
		name_gap.custom_minimum_size = Vector2(NAME_BAR_GAP, 0)
		name_gap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		name_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var hp := _make_bar(BAR_MIN_W_VITAL, 1.0)
		var mp := _make_bar(BAR_MIN_W_VITAL, 1.0)
		var expb := _make_bar(BAR_MIN_W_EXP, 1.05)

		row.add_child(portrait)
		row.add_child(level)
		row.add_child(name)
		row.add_child(name_gap)
		row.add_child(hp["track"])
		row.add_child(mp["track"])
		row.add_child(expb["track"])
		add_child(row)

		_icons.append(icon)
		_sleep_zz.append(zz)
		_levels.append(level)
		_names.append(name)
		_hp_fill.append(hp["fill"])
		_hp_lab.append(hp["lab"])
		_mp_blocks.append(mp["track"])
		_mp_fill.append(mp["fill"])
		_mp_lab.append(mp["lab"])
		_exp_fill.append(expb["fill"])
		_exp_lab.append(expb["lab"])
		_frame_bit.append(randi() & 1)
		_frame_cd.append(randf_range(FRAME_MIN, FRAME_MAX))


func _make_bar(min_w: float, stretch: float) -> Dictionary:
	## Dark track + colored fill + centered "cur / max".
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
	lab.add_theme_font_size_override("font_size", 11)
	lab.add_theme_color_override("font_color", COL_BAR_TEXT)
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

	for i in 8:
		var mid: int = GameState.party_member_at(i)
		var st: int = STUB_STATUS[mid]
		var hp: int = STUB_HP[mid]
		var mp: int = STUB_MP[mid]
		var mhp: int = STUB_MAX_HP[mid]
		var mmp: int = STUB_MAX_MP[mid]
		if st == Status.DEAD:
			hp = 0
			mp = 0

		var lv: int = STUB_LEVELS[mid]
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
		# Level uses the same Lv.8 gold / white rule (status does not recolor it).
		_levels[i].add_theme_color_override("font_color", COL_TEXT if lv >= 8 else COL_TEXT_LOW)

		_set_bar(_hp_fill[i], _hp_lab[i], hp, mhp, &"hp")
		_mp_blocks[i].visible = true
		if mmp <= 0:
			_set_bar_empty(_mp_fill[i], _mp_lab[i])
		else:
			_set_bar(_mp_fill[i], _mp_lab[i], mp, mmp, &"mp")
		_set_bar(_exp_fill[i], _exp_lab[i], STUB_EXP[mid], STUB_EXP_TO_NEXT[mid], &"exp")

	_apply_portrait_anim()
	call_deferred("_relayout_bars")


func _apply_portrait_anim() -> void:
	if _icons.is_empty():
		return
	for i in 8:
		var mid: int = GameState.party_member_at(i)
		var st: int = STUB_STATUS[mid]
		var icon := _icons[i]
		var mhp: int = STUB_MAX_HP[mid]
		var hp: int = 0 if st == Status.DEAD else STUB_HP[mid]
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
	fill.position = Vector2.ZERO
	fill.size = Vector2(
		track.size.x * ratio,
		track.size.y if track.size.y > 0.0 else float(BAR_H)
	)
