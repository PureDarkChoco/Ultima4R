class_name StatusInfoBar
extends PanelContainer

## SKY: moons + wind (top bar, centered)
## INVENTORY: gold / food / keys / skull / torches / gems (bottom bar, centered)
## FULL: classic left moons + right inventory (archive / side layouts)

enum BarKind { FULL, SKY, INVENTORY }

@export var bar_kind: BarKind = BarKind.FULL

const CHARSET_PATH := "res://assets/tiles/u4graphics/charset.png"
const WIND_DIR_PATHS := [
	"res://assets/ui/wind/n.png",
	"res://assets/ui/wind/ne.png",
	"res://assets/ui/wind/e.png",
	"res://assets/ui/wind/se.png",
	"res://assets/ui/wind/s.png",
	"res://assets/ui/wind/sw.png",
	"res://assets/ui/wind/w.png",
	"res://assets/ui/wind/nw.png",
]
const MOON_CHAR0 := 20 # xu4 MOON_CHAR; phases 0..7
const GLYPH := 16

## Wind: 0 N, 1 NE, 2 E, 3 SE, 4 S, 5 SW, 6 W, 7 NW
enum Wind { N, NE, E, SE, S, SW, W, NW }

const GOLD_FOOD_MAX := 9999
const ITEM_MAX := 99 # keys / skull / torches / gems
const STAT_NUM_W := 34.0 # "9999"
const ITEM_NUM_W := 20.0 # "99"
const ICON_SZ := 14.0

## Stub world state until savegame is wired.
var trammel_phase: int = 2
var felucca_phase: int = 6
var wind_dir: int = Wind.E
var gold: int = 1234
var food: int = 567
var keys: int = 3
var skull: int = 1
var torches: int = 12

var _moon_tex: Array[Texture2D] = []
var _wind_tex: Array[Texture2D] = []
var _tram: TextureRect
var _fel: TextureRect
var _wind: TextureRect
var _gold_lab: Label
var _food_lab: Label
var _keys_lab: Label
var _skull_lab: Label
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


func _load_wind_icons() -> void:
	_wind_tex.clear()
	for path in WIND_DIR_PATHS:
		_wind_tex.append(_load_tex(path))


func _load_moons() -> void:
	_moon_tex.clear()
	var img := Image.new()
	if img.load(CHARSET_PATH) != OK:
		var tex := load(CHARSET_PATH) as Texture2D
		if tex:
			img = tex.get_image()
	if img == null or img.is_empty():
		return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	for phase in 8:
		var cy := (MOON_CHAR0 + phase) * GLYPH
		var glyph := Image.create(GLYPH, GLYPH, false, Image.FORMAT_RGBA8)
		glyph.blit_rect(img, Rect2i(0, cy, GLYPH, GLYPH), Vector2i.ZERO)
		for y in GLYPH:
			for x in GLYPH:
				var c := glyph.get_pixel(x, y)
				if c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
					glyph.set_pixel(x, y, Color(0, 0, 0, 0))
		_moon_tex.append(ImageTexture.create_from_image(glyph))


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
	cluster.add_child(moons)

	_wind = TextureRect.new()
	_wind.custom_minimum_size = Vector2(16, 16)
	_wind.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wind.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_wind.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	_skull_lab = _add_stat(cluster, _skull_icon(), ITEM_NUM_W)
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
	t.custom_minimum_size = Vector2(16, 16)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	if _tram != null and _moon_tex.size() >= 8:
		_tram.texture = _moon_tex[_phase_char_index(trammel_phase)]
		_fel.texture = _moon_tex[_phase_char_index(felucca_phase)]
	var wd := posmod(wind_dir, 8)
	if _wind != null and _wind_tex.size() >= 8 and _wind_tex[wd] != null:
		_wind.texture = _wind_tex[wd]
	if _gold_lab:
		_gold_lab.text = "%d" % mini(gold, GOLD_FOOD_MAX)
	if _food_lab:
		_food_lab.text = "%d" % mini(food, GOLD_FOOD_MAX)
	if _keys_lab:
		_keys_lab.text = "%d" % mini(keys, ITEM_MAX)
	if _skull_lab:
		_skull_lab.text = "%d" % mini(skull, ITEM_MAX)
	if _torches_lab:
		_torches_lab.text = "%d" % mini(torches, ITEM_MAX)
	if _gems_lab:
		_gems_lab.text = "%d" % mini(GameState.gems, ITEM_MAX)


func _coin_icon() -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var gold_c := Color(0.95, 0.78, 0.15, 1)
	var dark := Color(0.55, 0.4, 0.05, 1)
	for y in 16:
		for x in 16:
			var dx := x - 7.5
			var dy := y - 7.5
			var r2 := dx * dx + dy * dy
			if r2 <= 36.0:
				img.set_pixel(x, y, gold_c if r2 <= 25.0 else dark)
	img.set_pixel(7, 6, dark)
	img.set_pixel(8, 6, dark)
	img.set_pixel(7, 7, dark)
	img.set_pixel(7, 8, dark)
	img.set_pixel(8, 8, dark)
	return ImageTexture.create_from_image(img)


func _food_icon() -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var crust := Color(0.72, 0.48, 0.18, 1)
	var crumb := Color(0.92, 0.78, 0.45, 1)
	for y in range(4, 12):
		for x in range(3, 13):
			img.set_pixel(x, y, crust if y == 4 or y == 11 or x == 3 or x == 12 else crumb)
	return ImageTexture.create_from_image(img)


func _key_icon() -> Texture2D:
	## Simple classic key silhouette.
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var metal := Color(0.85, 0.82, 0.55, 1)
	var dark := Color(0.45, 0.42, 0.22, 1)
	# bow (ring)
	for y in range(2, 8):
		for x in range(2, 8):
			var dx := x - 4.5
			var dy := y - 4.5
			var r2 := dx * dx + dy * dy
			if r2 <= 9.0 and r2 >= 3.5:
				img.set_pixel(x, y, metal if r2 <= 7.5 else dark)
	# shaft
	for x in range(7, 14):
		img.set_pixel(x, 4, metal)
		img.set_pixel(x, 5, dark)
	# bit
	img.set_pixel(12, 6, metal)
	img.set_pixel(13, 6, metal)
	img.set_pixel(13, 7, metal)
	return ImageTexture.create_from_image(img)


func _skull_icon() -> Texture2D:
	## Compact skull (Skull of Mondain).
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bone := Color(0.92, 0.9, 0.82, 1)
	var shade := Color(0.55, 0.52, 0.45, 1)
	var hole := Color(0.08, 0.08, 0.1, 1)
	# cranium
	for y in range(2, 11):
		for x in range(3, 13):
			var dx := x - 7.5
			var dy := y - 6.0
			if dx * dx / 22.0 + dy * dy / 16.0 <= 1.0:
				img.set_pixel(x, y, bone if dy < 2.5 else shade)
	# eye sockets
	for y in range(5, 8):
		for x in range(4, 7):
			if (x - 5) * (x - 5) + (y - 6) * (y - 6) <= 2:
				img.set_pixel(x, y, hole)
		for x in range(9, 12):
			if (x - 10) * (x - 10) + (y - 6) * (y - 6) <= 2:
				img.set_pixel(x, y, hole)
	# nose
	img.set_pixel(7, 8, hole)
	img.set_pixel(8, 8, hole)
	img.set_pixel(7, 9, hole)
	# jaw / teeth
	for x in range(5, 11):
		img.set_pixel(x, 11, bone)
		img.set_pixel(x, 12, shade)
	img.set_pixel(6, 12, hole)
	img.set_pixel(8, 12, hole)
	img.set_pixel(10, 12, hole)
	return ImageTexture.create_from_image(img)


func _torch_icon() -> Texture2D:
	## Stick + flame.
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wood := Color(0.55, 0.32, 0.12, 1)
	var wood_d := Color(0.35, 0.18, 0.06, 1)
	var flame := Color(1.0, 0.72, 0.15, 1)
	var flame_c := Color(1.0, 0.35, 0.08, 1)
	# shaft
	for y in range(7, 15):
		img.set_pixel(7, y, wood)
		img.set_pixel(8, y, wood_d)
	# flame
	for y in range(1, 8):
		for x in range(5, 11):
			var dx := absf(x - 7.5)
			var dy := float(7 - y)
			if dx <= 2.2 - dy * 0.15 and dy >= 0:
				img.set_pixel(x, y, flame if dx < 1.2 else flame_c)
	img.set_pixel(7, 2, Color(1.0, 0.95, 0.55, 1))
	return ImageTexture.create_from_image(img)


func _gem_icon() -> Texture2D:
	## Faceted diamond / gem.
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var gem := Color(0.35, 0.85, 0.95, 1)
	var gem_d := Color(0.15, 0.45, 0.75, 1)
	var gem_h := Color(0.85, 0.98, 1.0, 1)
	# diamond outline roughly |◇|
	for y in range(2, 14):
		for x in range(3, 13):
			var dx := absf(x - 7.5)
			var dy := absf(y - 7.5)
			if dx + dy <= 5.5:
				var c := gem
				if dx + dy > 4.2:
					c = gem_d
				elif dx < 1.2 and y < 7:
					c = gem_h
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
