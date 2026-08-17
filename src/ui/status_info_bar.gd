class_name StatusInfoBar
extends PanelContainer

## SKY: moons centered on the bar; wind sits just to their right
## INVENTORY: gold / food / keys / torches / gems (bottom bar, centered)
## FULL: classic left moons + right inventory (archive / side layouts)

enum BarKind { FULL, SKY, INVENTORY }

@export var bar_kind: BarKind = BarKind.FULL

## Wind icons (8-way art in assets/ui/wind/{n,ne,e,se,s,sw,w,nw}.png).
const WIND_DIR_PATH := "res://assets/ui/wind"
## Index 0–7 = tip bearing N…NW. refresh() maps GameState.wind_dir (FROM) → tip TO via +4.
const WIND_FILES := ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const HUD_GOLD_PATH := "res://assets/ui/hud/gold.png"
const HUD_FOOD_PATH := "res://assets/ui/hud/food.png"
const HUD_KEY_PATH := "res://assets/ui/hud/key.png"
const HUD_TORCH_PATH := "res://assets/ui/hud/torch.png"
const HUD_GEM_PATH := "res://assets/ui/hud/gem.png"
## DOS Ultima IV CHARSET.EGA moon glyphs (chars 20..27), extracted 8×8.
const MOON_DIR := "res://assets/ui/moons"

## Wind: 0 N, 1 NE, 2 E, 3 SE, 4 S, 5 SW, 6 W, 7 NW
## On screen tip = blow TO / balloon drift (opposite of GameState.wind_dir FROM).
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
var _wind_tex: Array[Texture2D] = [] ## 8 tip-TO icons (display index after +4 flip)
var _tram: TextureRect
var _fel: TextureRect
var _wind: TextureRect
var _world_sky_balance: Control
var _world_moons: HBoxContainer
var _dungeon_level_lab: Label
var _dungeon_active := false
var _dungeon_level := 1
var _dungeon_dir := 0
var _gold_lab: Label
var _food_lab: Label
var _keys_lab: Label
var _torches_lab: Label
var _gems_lab: Label
var _last_drawn_wind: int = -1
var _aura_lab: Label
var _aura_host: Control
var _last_aura_hud := ""
## Global X of the battlefield's left edge (11-tile field). −1 = unset.
var _aura_field_global_x := -1.0


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
	## Keep sky icons live even if a caller forgets to refresh after clock ticks.
	if bar_kind == BarKind.SKY or bar_kind == BarKind.FULL:
		set_process(true)
	else:
		set_process(false)


func _process(_delta: float) -> void:
	if bar_kind != BarKind.SKY and bar_kind != BarKind.FULL:
		return
	if (
		wind_dir != GameState.wind_dir
		or trammel_phase != GameState.trammel_phase
		or felucca_phase != GameState.felucca_phase
		or _last_aura_hud != GameState.spell_aura_hud_text()
	):
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
	## Load n/ne/e/se/s/sw/w/nw art (tip = that bearing as shown after FROM→TO flip).
	_wind_tex.clear()
	var side := int(ICON_SZ)
	for name in WIND_FILES:
		var path := "%s/%s.png" % [WIND_DIR_PATH, name]
		var img := Image.new()
		if img.load(path) != OK:
			var loaded := load(path) as Texture2D
			if loaded != null:
				img = loaded.get_image()
		if img == null or img.is_empty():
			push_warning("StatusInfoBar: missing wind icon %s" % path)
			_wind_tex.append(null)
			continue
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		## Near-black plate → transparent (art is on black).
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.r < 0.05 and c.g < 0.05 and c.b < 0.05:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
		if img.get_width() != side or img.get_height() != side:
			img.resize(side, side, Image.INTERPOLATE_NEAREST)
		_wind_tex.append(ImageTexture.create_from_image(img))


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
	_aura_host = Control.new()
	_aura_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aura_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_aura_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_h_spacer())
	row.add_child(_make_sky_cluster())
	row.add_child(_h_spacer())
	_aura_host.add_child(row)
	_aura_host.add_child(_make_aura_label())
	add_child(_aura_host)


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


func _make_aura_label() -> Label:
	## Overlay: "J" / "N" / "P" / "Q" / "W". World aligns X to the open battlefield's left edge.
	_aura_lab = Label.new()
	_aura_lab.add_theme_font_size_override("font_size", 11)
	_aura_lab.add_theme_color_override("font_color", Color(0.95, 0.9, 0.55, 1))
	UiTheme.apply_font(_aura_lab)
	_aura_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_aura_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_aura_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return _aura_lab


func set_aura_field_global_x(global_x: float) -> void:
	## Left edge of the 11-tile field (side-panel seam when those panels are open).
	_aura_field_global_x = global_x
	_place_aura_overlay()


func _place_aura_overlay() -> void:
	if _aura_lab == null:
		return
	_aura_lab.reset_size()
	var sz := _aura_lab.get_minimum_size()
	_aura_lab.size = sz
	var local_x := 0.0
	if _aura_field_global_x >= 0.0:
		var parent_ctl := _aura_lab.get_parent() as Control
		var origin := parent_ctl.global_position.x if parent_ctl != null else global_position.x
		local_x = _aura_field_global_x - origin
	var host_h := _aura_host.size.y if _aura_host != null else size.y
	_aura_lab.position = Vector2(
		maxf(local_x, 0.0),
		floorf((host_h - sz.y) * 0.5)
	)


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

	_world_moons = HBoxContainer.new()
	_world_moons.add_theme_constant_override("separation", 2)
	_world_moons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tram = _moon_icon()
	_fel = _moon_icon()
	_world_moons.add_child(_tram)
	_world_moons.add_child(_fel)

	_wind = TextureRect.new()
	_wind.custom_minimum_size = Vector2(ICON_SZ, ICON_SZ)
	_wind.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wind.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_wind.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	## Pre-rotated textures — no Control.rotation (container layout can hide it).
	_wind.rotation_degrees = 0.0
	_wind.pivot_offset = Vector2.ZERO

	_world_sky_balance = Control.new()
	_world_sky_balance.custom_minimum_size = _wind.custom_minimum_size
	_world_sky_balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_sky_balance.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	cluster.add_child(_world_sky_balance)
	cluster.add_child(_world_moons)
	_dungeon_level_lab = _sky_text_label(30.0)
	cluster.add_child(_dungeon_level_lab)
	cluster.add_child(_wind)
	return cluster


func _sky_text_label(width: float) -> Label:
	var lab := Label.new()
	lab.custom_minimum_size = Vector2(width, ICON_SZ)
	lab.add_theme_font_size_override("font_size", 11)
	lab.add_theme_color_override("font_color", Color(0.95, 0.9, 0.55, 1))
	UiTheme.apply_font(lab)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lab


func set_dungeon_status(active: bool, level: int = 1, direction: int = 0) -> void:
	_dungeon_active = active
	_dungeon_level = clampi(level, 1, 8)
	_dungeon_dir = posmod(direction, 4)
	refresh()


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
	## Display reverse of GameState.wind_dir (FROM → TO) so tip matches balloon_drift_dir.
	var wd := posmod(wind_dir + 4, 8)
	if _dungeon_active:
		## Dungeon headings directly use the cardinal N/E/S/W arrow textures.
		wd = _dungeon_dir * 2
	if _wind != null and _wind_tex.size() >= 8:
		var tex: Texture2D = _wind_tex[wd]
		if tex != null and (wd != _last_drawn_wind or _wind.texture != tex):
			_wind.texture = tex
			_wind.rotation_degrees = 0.0
			_last_drawn_wind = wd
	if _world_sky_balance != null:
		_world_sky_balance.visible = not _dungeon_active
	if _world_moons != null:
		_world_moons.visible = not _dungeon_active
	if _wind != null:
		_wind.visible = true
	if _dungeon_level_lab != null:
		_dungeon_level_lab.visible = _dungeon_active
		_dungeon_level_lab.text = Locale.t("hud_dungeon_level", [_dungeon_level])
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
	_last_aura_hud = GameState.spell_aura_hud_text()
	if _aura_lab != null:
		_aura_lab.text = _last_aura_hud
		_aura_lab.visible = not _last_aura_hud.is_empty()
		_place_aura_overlay()


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
