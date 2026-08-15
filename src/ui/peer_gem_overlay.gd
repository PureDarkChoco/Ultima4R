class_name PeerGemOverlay
extends Control

## Peer gem map overlay. xu4 Standard is 32×32; we keep an odd vertical
## span and widen to ~16:9 so more terrain shows left/right (party #1 centered).

signal closed

const GEM_PATH := "res://assets/tiles/u4graphics/gem.png"
## Odd so center.x/y land on one middle cell (xu4's 32 is even → off-center).
const GEM_VIEW_H := 33
## ~GEM_VIEW_H × 16/9, forced odd (59/33 ≈ 16:9).
const GEM_VIEW_W := 59
## Explore tiles are slightly tall (MapView.TILE_ASPECT 9:10).
const TILE_ASPECT := 9.0 / 10.0
const GEM_CELL := 8
## Fallback avatar gem id (party #1 class tile preferred when < 128).
const AVATAR_GEM_TILE := 31
const CLASS_TILE_EVEN := [32, 34, 36, 38, 40, 42, 44, 46]
## Gem sheet only has 0–127; ghosts etc. still need a visible person chip.
const TILE_CITIZEN := 82
const TILE_SHIP_WEST := 16
const TILE_PIRATE := 128
const WORLD_W := 256
const WORLD_H := 256
const INNER_PAD := 6
const BORDER_W := 2
## Dim the explore map under the popup so the gem draws the eye.
const MAP_DIM := Color(0.0, 0.0, 0.0, 0.45)
const LOC_COLOR := Color(0.91, 0.9, 0.82, 1)
## Soft plate behind sextant text so gem pixels don't fight the glyphs.
const LOC_BG := Color(0.0, 0.0, 0.0, 0.58)
const LOC_PAD_X := 4
const LOC_PAD_Y := 1

var _dim: ColorRect
var _panel: Panel
var _tex_rect: TextureRect
var _loc_plate: Panel
var _loc_label: Label
var _gem_sheet: Image
var _buf: Image
var _tex: ImageTexture
var _open := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_load_gem_sheet()


func is_open() -> bool:
	return _open


func open_peer(
	world, ## WorldMapData
	center: Vector2i,
	tile_size: Vector2,
	loc_text: String = "",
	map_view = null ## MapView — overlays, moongate, creatures
) -> void:
	if world == null or not world.loaded:
		return
	_ensure_buffers()
	_blit_gem_map(world, center, map_view)
	_layout_panel(tile_size)
	_set_loc_text(loc_text)
	_open = true
	visible = true
	move_to_front()


func open_peer_city(
	city, ## CityMapData
	tile_size: Vector2,
	loc_text: String = "",
	party_pos: Vector2i = Vector2i(-1, -1)
) -> void:
	## Town gem: terrain + residents. Party chip when `party_pos` is set.
	if city == null or not city.loaded:
		return
	_ensure_buffers()
	_blit_gem_city(city, party_pos)
	_layout_panel(tile_size)
	_set_loc_text(loc_text)
	_open = true
	visible = true
	move_to_front()


func close_peer() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.color = MAP_DIM
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_panel = Panel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 1)
	sb.border_color = Color(0.35, 0.55, 0.95, 1)
	sb.border_width_left = BORDER_W
	sb.border_width_top = BORDER_W
	sb.border_width_right = BORDER_W
	sb.border_width_bottom = BORDER_W
	sb.set_corner_radius_all(0)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	_tex_rect = TextureRect.new()
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel.add_child(_tex_rect)

	## Inside the gem frame, bottom-center (not outside on the explore pane).
	_loc_plate = Panel.new()
	_loc_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loc_plate.visible = false
	var loc_sb := StyleBoxFlat.new()
	loc_sb.bg_color = LOC_BG
	loc_sb.set_corner_radius_all(0)
	loc_sb.content_margin_left = LOC_PAD_X
	loc_sb.content_margin_right = LOC_PAD_X
	loc_sb.content_margin_top = LOC_PAD_Y
	loc_sb.content_margin_bottom = LOC_PAD_Y
	_loc_plate.add_theme_stylebox_override("panel", loc_sb)
	_panel.add_child(_loc_plate)

	_loc_label = Label.new()
	_loc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loc_label.add_theme_color_override("font_color", LOC_COLOR)
	_loc_label.add_theme_font_size_override("font_size", 14)
	UiTheme.apply_font(_loc_label)
	_loc_plate.add_child(_loc_label)


func _load_gem_sheet() -> void:
	_gem_sheet = Image.new()
	if _gem_sheet.load(GEM_PATH) != OK:
		var tex := load(GEM_PATH) as Texture2D
		if tex:
			_gem_sheet = tex.get_image()
	if _gem_sheet == null or _gem_sheet.is_empty():
		return
	if _gem_sheet.get_format() != Image.FORMAT_RGBA8:
		_gem_sheet.convert(Image.FORMAT_RGBA8)


func _ensure_buffers() -> void:
	var px_w := GEM_VIEW_W * GEM_CELL
	var px_h := GEM_VIEW_H * GEM_CELL
	if _buf != null and _buf.get_width() == px_w and _buf.get_height() == px_h:
		return
	_buf = Image.create(px_w, px_h, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_buf)
	if _tex_rect:
		_tex_rect.texture = _tex


func _party_gem_tile() -> int:
	## Party #1 walk sprite on the gem sheet when available.
	var klass := GameState.party_leader_class()
	if klass >= 0 and klass < CLASS_TILE_EVEN.size():
		var tid: int = CLASS_TILE_EVEN[klass]
		if tid < 128:
			return tid
	return AVATAR_GEM_TILE


func _blit_gem_map(world: WorldMapData, center: Vector2i, map_view = null) -> void:
	if _buf == null or _gem_sheet == null or _gem_sheet.is_empty():
		return
	_buf.fill(Color(0, 0, 0, 1))
	## Odd spans → half lands on the true center cell for party #1.
	var half_x := GEM_VIEW_W / 2
	var half_y := GEM_VIEW_H / 2
	for gy in GEM_VIEW_H:
		for gx in GEM_VIEW_W:
			var wx := center.x + gx - half_x
			var wy := center.y + gy - half_y
			_blit_gem_cell(gx, gy, world.tile_at(wx, wy))
	if map_view != null:
		if map_view.has_method("get_overlays"):
			for item in map_view.get_overlays():
				_blit_world_object(Vector2i(int(item.x), int(item.y)), int(item.z), center)
		if map_view.has_method("peer_moongate"):
			var gate: Vector3i = map_view.peer_moongate()
			if gate.z >= 0:
				_blit_world_object(Vector2i(gate.x, gate.y), gate.z, center)
		if map_view.has_method("get_creatures"):
			for c in map_view.get_creatures():
				_blit_world_object(Vector2i(int(c.x), int(c.y)), int(c.tid), center)
	_blit_gem_cell(half_x, half_y, _party_gem_tile())
	_tex.update(_buf)


func _blit_gem_city(city, party_pos: Vector2i = Vector2i(-1, -1)) -> void:
	## Center the 32×32 .ULT in the wider gem viewport; void outside is black.
	if _buf == null or _gem_sheet == null or _gem_sheet.is_empty():
		return
	_buf.fill(Color(0, 0, 0, 1))
	var city_w := 32
	var city_h := 32
	var origin_x := int((GEM_VIEW_W - city_w) / 2)
	var origin_y := int((GEM_VIEW_H - city_h) / 2)
	var live: bool = party_pos.x >= 0 and bool(city.has_method("effective_tile_at"))
	for cy in city_h:
		for cx in city_w:
			var tid: int
			if live:
				tid = int(city.effective_tile_at(cx, cy))
			else:
				tid = int(city.tile_at(cx, cy))
			_blit_gem_cell(origin_x + cx, origin_y + cy, tid)
	if city.get("persons") != null:
		for p in city.persons:
			var px := int(p.x)
			var py := int(p.y)
			if px < 0 or py < 0 or px >= city_w or py >= city_h:
				continue
			_blit_gem_actor(origin_x + px, origin_y + py, int(p.z))
	if party_pos.x >= 0 and party_pos.x < city_w and party_pos.y >= 0 and party_pos.y < city_h:
		_blit_gem_actor(origin_x + party_pos.x, origin_y + party_pos.y, _party_gem_tile())
	_tex.update(_buf)


func _wrap_delta(from: Vector2i, to: Vector2i) -> Vector2i:
	var dx := to.x - from.x
	var dy := to.y - from.y
	if dx > WORLD_W / 2:
		dx -= WORLD_W
	elif dx < -WORLD_W / 2:
		dx += WORLD_W
	if dy > WORLD_H / 2:
		dy -= WORLD_H
	elif dy < -WORLD_H / 2:
		dy += WORLD_H
	return Vector2i(dx, dy)


func _blit_world_object(pos: Vector2i, tile_id: int, center: Vector2i) -> void:
	var d := _wrap_delta(center, pos)
	var gx := d.x + GEM_VIEW_W / 2
	var gy := d.y + GEM_VIEW_H / 2
	if gx < 0 or gy < 0 or gx >= GEM_VIEW_W or gy >= GEM_VIEW_H:
		return
	_blit_gem_object(gx, gy, tile_id)


func _blit_gem_object(gx: int, gy: int, tile_id: int) -> void:
	## Wilderness objects: gem chips when possible; else downscale the shape.
	if tile_id < 0:
		return
	if tile_id >= TILE_PIRATE and tile_id < TILE_PIRATE + 4:
		_blit_gem_cell(gx, gy, TILE_SHIP_WEST + (tile_id - TILE_PIRATE))
		return
	if tile_id < 128:
		_blit_gem_cell(gx, gy, tile_id)
		return
	if not U4TileBank.ensure_loaded():
		_blit_gem_cell(gx, gy, TILE_CITIZEN)
		return
	var img := U4TileBank.keyed_copy(tile_id)
	if img == null:
		_blit_gem_cell(gx, gy, TILE_CITIZEN)
		return
	img.resize(GEM_CELL, GEM_CELL, Image.INTERPOLATE_NEAREST)
	_buf.blend_rect(img, Rect2i(0, 0, GEM_CELL, GEM_CELL), Vector2i(gx * GEM_CELL, gy * GEM_CELL))


func _blit_gem_actor(gx: int, gy: int, tile_id: int) -> void:
	var tid := tile_id
	if tid >= 128:
		tid = TILE_CITIZEN
	if tid < 0:
		return
	_blit_gem_cell(gx, gy, tid)


func _blit_gem_cell(gx: int, gy: int, tile_id: int) -> void:
	if tile_id < 0 or tile_id >= 128:
		## xu4: ids ≥ 128 are drawn black on the gem.
		_buf.fill_rect(
			Rect2i(gx * GEM_CELL, gy * GEM_CELL, GEM_CELL, GEM_CELL),
			Color(0, 0, 0, 1)
		)
		return
	var src := Rect2i(0, tile_id * GEM_CELL, GEM_CELL, GEM_CELL)
	_buf.blit_rect(_gem_sheet, src, Vector2i(gx * GEM_CELL, gy * GEM_CELL))


func _set_loc_text(loc_text: String) -> void:
	if _loc_label == null or _loc_plate == null:
		return
	_loc_label.text = loc_text
	var show := not loc_text.is_empty()
	_loc_plate.visible = show
	_loc_label.visible = show
	_layout_loc_label()


func _layout_loc_label() -> void:
	if _loc_plate == null or _loc_label == null or not _loc_plate.visible or _panel == null:
		return
	var font_sz := 14
	_loc_label.add_theme_font_size_override("font_size", font_sz)
	var panel_sz := _panel.size
	var max_w := maxf(panel_sz.x - float(BORDER_W * 2 + INNER_PAD * 2), 40.0)
	var text_w := _loc_label.get_minimum_size().x
	var tw := minf(text_w + float(LOC_PAD_X * 2), max_w)
	var th := float(font_sz) + float(LOC_PAD_Y * 2) + 2.0
	_loc_plate.size = Vector2(tw, th)
	_loc_label.position = Vector2(LOC_PAD_X, LOC_PAD_Y)
	_loc_label.size = Vector2(tw - float(LOC_PAD_X * 2), th - float(LOC_PAD_Y * 2))
	## Bottom-center; drop by half the label height so the name sits off the map.
	_loc_plate.position = Vector2(
		floorf((panel_sz.x - tw) * 0.5),
		floorf(panel_sz.y - float(BORDER_W) - INNER_PAD - th * 0.5 - 2.0)
	)
	_loc_plate.z_index = 1


func _layout_panel(tile_size: Vector2) -> void:
	## Fit in the explore pane (one tile margin). Cell aspect matches play tiles.
	var pane := size
	if pane.x < 8.0 or pane.y < 8.0:
		var p := get_parent() as Control
		if p:
			pane = p.size
	var th := maxf(tile_size.y, 8.0)
	var tw := maxf(tile_size.x, 8.0)
	var cell_aspect := TILE_ASPECT
	if tile_size.x > 0.0 and tile_size.y > 0.0:
		cell_aspect = tile_size.x / tile_size.y
	var map_aspect := (float(GEM_VIEW_W) / float(GEM_VIEW_H)) * cell_aspect
	var max_h := maxf(pane.y - th * 2.0, 64.0)
	var max_w := maxf(pane.x - tw * 2.0, 64.0)
	var panel_h := max_h
	var panel_w := panel_h * map_aspect
	if panel_w > max_w:
		panel_w = max_w
		panel_h = panel_w / map_aspect
	_panel.size = Vector2(panel_w, panel_h)
	_panel.position = Vector2(
		floorf((pane.x - panel_w) * 0.5),
		floorf((pane.y - panel_h) * 0.5)
	)
	var inner_w := panel_w - float(BORDER_W * 2 + INNER_PAD * 2)
	var inner_h := panel_h - float(BORDER_W * 2 + INNER_PAD * 2)
	inner_w = maxf(inner_w, 8.0)
	inner_h = maxf(inner_h, 8.0)
	_tex_rect.position = Vector2(BORDER_W + INNER_PAD, BORDER_W + INNER_PAD)
	_tex_rect.size = Vector2(inner_w, inner_h)
	_layout_loc_label()
