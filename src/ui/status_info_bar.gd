class_name StatusInfoBar
extends PanelContainer

## SKY: moons centered on the bar; wind sits just to their right
## INVENTORY: gold / food / keys / torches / gems (bottom bar, centered)
## FULL: classic left moons + right inventory (archive / side layouts)

enum BarKind { FULL, SKY, INVENTORY }

@export var bar_kind: BarKind = BarKind.FULL

## Filenames do not match tip direction (e.g. n.png points south).
## Use the east-pointing sprite and rotate so tip == wind_dir compass.
const WIND_EAST_PATH := "res://assets/ui/wind/w.png" ## visual tip = East
const HUD_GOLD_PATH := "res://assets/ui/hud/gold.png"
const HUD_FOOD_PATH := "res://assets/ui/hud/food.png"
const HUD_KEY_PATH := "res://assets/ui/hud/key.png"
const HUD_TORCH_PATH := "res://assets/ui/hud/torch.png"
const HUD_GEM_PATH := "res://assets/ui/hud/gem.png"
## DOS Ultima IV CHARSET.EGA moon glyphs (chars 20..27), extracted 8×8.
const MOON_DIR := "res://assets/ui/moons"

## Wind: 0 N, 1 NE, 2 E, 3 SE, 4 S, 5 SW, 6 W, 7 NW
## Arrow tip = wind FROM / headwind direction (xu4 windDirection).
enum Wind { N, NE, E, SE, S, SW, W, NW }

const GOLD_FOOD_MAX := 9999
const ITEM_MAX := 99 # keys / torches / gems
const STAT_NUM_W := 34.0 # "9999"
const ITEM_NUM_W := 20.0 # "99"
const ICON_SZ := 16.0

## Moons / wind come from GameState world clock (xu4 timerFired).
var trammel_phase: int = 0
var felucca_phase: int = 0
var wind_dir: int = Wind.N
var gold: int = 1234
var food: int = 567 ## mirrored from GameState.food_display() on refresh
var keys: int = 3
var torches: int = 12

var _moon_tex: Array[Texture2D] = []
var _wind_east_tex: Texture2D
var _tram: TextureRect
var _fel: TextureRect
var _wind: TextureRect
var _gold_lab: Label
var _food_lab: Label
var _keys_lab: Label
var _torches_lab: Label
var _gems_lab: Label


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	custom_minimum_size = Vector2(0, 0)
	_apply_blue_frame()
	if bar_kind != BarKind.INVENTORY:
		_load_moons()
		_load_wind_icons()
	_build()
	refresh()


func _apply_blue_frame() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.06, 0.28, 1)
	sb.border_color = Color(0.35, 0.55, 0.95, 1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	match bar_kind:
		BarKind.SKY:
			sb.border_width_left = 0
			sb.border_width_top = 0
			sb.border_width_right = 0
			sb.border_width_bottom = 2
		BarKind.INVENTORY:
			sb.border_width_left = 0
			sb.border_width_top = 2
			sb.border_width_right = 0
			sb.border_width_bottom = 0
		_:
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(1)
			sb.content_margin_top = 3
			sb.content_margin_bottom = 3
	add_theme_stylebox_override("panel", sb)


func _load_tex(path: String) -> Texture2D:
	var img := Image.new()
	if img.load(path) == OK:
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		return ImageTexture.create_from_image(img)
	return load(path) as Texture2D


func _load_hud_icon(path: String) -> Texture2D:
	## Near-black bg → transparent so icons sit on the inventory bar.
	var img := Image.new()
	if img.load(path) != OK:
		var loaded := load(path) as Texture2D
		if loaded == null:
			return null
		img = loaded.get_image()
	if img == null or img.is_empty():
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r < 0.04 and c.g < 0.04 and c.b < 0.04:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func _load_wind_icons() -> void:
	## Single east-facing arrow; refresh() rotates tip to match wind_dir.
	_wind_east_tex = _load_tex(WIND_EAST_PATH)


func _load_moons() -> void:
	## 16×16 phase art in assets/ui/moons (xu4 MOON_CHAR order via _phase_char_index).
	_moon_tex.clear()
	for phase in 8:
		var path := "%s/phase_%d.png" % [MOON_DIR, phase]
		var img := Image.new()
		if img.load(path) != OK:
			var loaded := load(path) as Texture2D
			if loaded == null:
				push_warning("StatusInfoBar: missing moon %s" % path)
				_moon_tex.append(null)
				continue
			img = loaded.get_image()
		if img == null or img.is_empty():
			_moon_tex.append(null)
			continue
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		## Safety: key leftover paper-white if a source still has it.
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.r > 0.94 and c.g > 0.94 and c.b > 0.94:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
		var side := int(ICON_SZ)
		if img.get_width() != side or img.get_height() != side:
			img.resize(side, side, Image.INTERPOLATE_NEAREST)
		_moon_tex.append(ImageTexture.create_from_image(img))


func _build() -> void:
	match bar_kind:
		BarKind.SKY:
			_build_sky_centered()
		BarKind.INVENTORY:
			_build_inventory_centered()
		_:
			_build_full()


func _build_sky_centered() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_h_spacer())
	row.add_child(_make_sky_cluster())
	row.add_child(_h_spacer())
	add_child(row)


func _build_inventory_centered() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_h_spacer())
	row.add_child(_make_inventory_cluster())
	row.add_child(_h_spacer())
	add_child(row)


func _build_full() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_make_sky_cluster())
	row.add_child(_h_spacer())
	row.add_child(_make_inventory_cluster())
	add_child(row)


func _h_spacer() -> Control:
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.custom_minimum_size = Vector2(8, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _make_sky_cluster() -> HBoxContainer:
	## Moons sit on the true centerline; wind sits just to their right.
	## A same-width left spacer balances the wind so the moon pair stays centered.
	var cluster := HBoxContainer.new()
	cluster.add_theme_constant_override("separation", 16)
	cluster.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cluster.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var moons := HBoxContainer.new()
	moons.add_theme_constant_override("separation", 2)
	moons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tram = _moon_icon()
	_fel = _moon_icon()
	moons.add_child(_tram)
	moons.add_child(_fel)

	_wind = TextureRect.new()
	_wind.custom_minimum_size = Vector2(16, 16)
	_wind.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wind.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_wind.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	## Rotate around center so tip tracks wind_dir (0=N … 7=NW).
	_wind.pivot_offset = Vector2(8, 8)

	var wind_balance := Control.new()
	wind_balance.custom_minimum_size = _wind.custom_minimum_size
	wind_balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wind_balance.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	cluster.add_child(wind_balance)
	cluster.add_child(moons)
	cluster.add_child(_wind)
	return cluster


func _make_inventory_cluster() -> HBoxContainer:
	var cluster := HBoxContainer.new()
	cluster.add_theme_constant_override("separation", 16)
	cluster.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cluster.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gold_lab = _add_stat(cluster, _coin_icon(), STAT_NUM_W)
	_food_lab = _add_stat(cluster, _food_icon(), STAT_NUM_W)
	_keys_lab = _add_stat(cluster, _key_icon(), ITEM_NUM_W)
	_torches_lab = _add_stat(cluster, _torch_icon(), ITEM_NUM_W)
	_gems_lab = _add_stat(cluster, _gem_icon(), ITEM_NUM_W)
	return cluster


func _add_stat(parent: HBoxContainer, icon: Texture2D, num_w: float) -> Label:
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 2)
	pair.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pair.add_child(_make_icon(icon))
	var lab := _stat_label(num_w)
	pair.add_child(lab)
	parent.add_child(pair)
	return lab


func _moon_icon() -> TextureRect:
	var t := TextureRect.new()
	## Fixed square — never let the sky HBox stretch a phase into an oval.
	t.custom_minimum_size = Vector2(ICON_SZ, ICON_SZ)
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _make_icon(tex: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(ICON_SZ, ICON_SZ)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.texture = tex
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


func _stat_label(width: float) -> Label:
	var lab := Label.new()
	lab.custom_minimum_size = Vector2(width, 0)
	lab.add_theme_font_size_override("font_size", 11)
	lab.add_theme_color_override("font_color", Color(0.95, 0.9, 0.55, 1))
	UiTheme.apply_font(lab)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.size_flags_horizontal = Control.SIZE_SHRINK_END
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lab.clip_text = true
	return lab


func _phase_char_index(phase: int) -> int:
	phase = posmod(phase, 8)
	if phase == 0:
		return 7
	return phase - 1


func refresh() -> void:
	if bar_kind == BarKind.SKY or bar_kind == BarKind.FULL:
		trammel_phase = GameState.trammel_phase
		felucca_phase = GameState.felucca_phase
		wind_dir = GameState.wind_dir
	if bar_kind == BarKind.INVENTORY or bar_kind == BarKind.FULL:
		food = GameState.food_display()
		gold = GameState.gold
		keys = GameState.keys
		torches = GameState.torches
	if _tram != null and _moon_tex.size() >= 8:
		_tram.texture = _moon_tex[_phase_char_index(trammel_phase)]
		_fel.texture = _moon_tex[_phase_char_index(felucca_phase)]
	var wd := posmod(wind_dir, 8)
	if _wind != null and _wind_east_tex != null:
		_wind.texture = _wind_east_tex
		## w.png tip faces East at 0°; wind_dir 0 (N) → -90°.
		_wind.rotation_degrees = float(wd) * 45.0 - 90.0
		_wind.pivot_offset = _wind.size * 0.5
	if _gold_lab:
		_gold_lab.text = "%d" % mini(gold, GOLD_FOOD_MAX)
	if _food_lab:
		_food_lab.text = "%d" % mini(food, GOLD_FOOD_MAX)
	if _keys_lab:
		_keys_lab.text = "%d" % mini(keys, ITEM_MAX)
	if _torches_lab:
		_torches_lab.text = "%d" % mini(torches, ITEM_MAX)
	if _gems_lab:
		_gems_lab.text = "%d" % mini(GameState.gems, ITEM_MAX)


func _coin_icon() -> Texture2D:
	return _load_hud_icon(HUD_GOLD_PATH)


func _food_icon() -> Texture2D:
	return _load_hud_icon(HUD_FOOD_PATH)


func _key_icon() -> Texture2D:
	return _load_hud_icon(HUD_KEY_PATH)


func _torch_icon() -> Texture2D:
	return _load_hud_icon(HUD_TORCH_PATH)


func _gem_icon() -> Texture2D:
	return _load_hud_icon(HUD_GEM_PATH)
