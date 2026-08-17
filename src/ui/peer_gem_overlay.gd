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
## xu4's dungeon_gem layout is a 22×22 character map.
const DUNGEON_VIEW_W := 22
const DUNGEON_VIEW_H := 22
const DNG_LADDER_UP := 0x10
const DNG_LADDER_DOWN := 0x20
const DNG_LADDER_BOTH := 0x30
const DNG_CHEST := 0x40
const DNG_CEILING_HOLE := 0x50
const DNG_FLOOR_HOLE := 0x60
const DNG_ORB := 0x70
const DNG_FOUNTAIN := 0x90
const DNG_FIELD := 0xA0
const DNG_ALTAR := 0xB0
const DNG_DOOR := 0xC0
const DNG_ROOM := 0xD0
const DNG_SECRET := 0xE0
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
var _view_w := GEM_VIEW_W
var _view_h := GEM_VIEW_H


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
	_ensure_buffers(GEM_VIEW_W, GEM_VIEW_H)
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
	_ensure_buffers(GEM_VIEW_W, GEM_VIEW_H)
	_blit_gem_city(city, party_pos)
	_layout_panel(tile_size)
	_set_loc_text(loc_text)
	_open = true
	visible = true
	move_to_front()


func open_peer_dungeon(
	dungeon, ## DungeonMapData
	center: Vector2i,
	level: int,
	tile_size: Vector2
) -> void:
	## xu4 reveals only the connected 8-way region around the party. Opaque
	## walls are drawn at its edge, but the search never continues through them.
	if dungeon == null or not dungeon.loaded:
		return
	_ensure_buffers(DUNGEON_VIEW_W, DUNGEON_VIEW_H)
	_blit_gem_dungeon(dungeon, center, level)
	_layout_panel(tile_size)
	_set_loc_text("")
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


func _ensure_buffers(view_w: int, view_h: int) -> void:
	_view_w = view_w
	_view_h = view_h
	var px_w := view_w * GEM_CELL
	var px_h := view_h * GEM_CELL
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


func _blit_gem_dungeon(dungeon, center: Vector2i, level: int) -> void:
	if _buf == null:
		return
	_buf.fill(Color(0, 0, 0, 1))
	var center_x := DUNGEON_VIEW_W / 2 - 1
	var center_y := DUNGEON_VIEW_H / 2 - 1
	var pending: Array[Vector2i] = [Vector2i(center_x, center_y)]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var screen_pos: Vector2i = pending.pop_back()
		if (
			screen_pos.x < 0
			or screen_pos.y < 0
			or screen_pos.x >= DUNGEON_VIEW_W
			or screen_pos.y >= DUNGEON_VIEW_H
			or visited.has(screen_pos)
		):
			continue
		visited[screen_pos] = true
		var map_x := center.x + screen_pos.x - center_x
		var map_y := center.y + screen_pos.y - center_y
		var is_avatar := screen_pos == Vector2i(center_x, center_y)
		_blit_dungeon_cell(
			screen_pos.x, screen_pos.y, dungeon, map_x, map_y, level, is_avatar
		)
		if not is_avatar and dungeon.looks_like_wall(map_x, map_y, level):
			continue
		## xu4 deliberately traverses all eight neighbors, including diagonals.
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx != 0 or dy != 0:
					pending.append(screen_pos + Vector2i(dx, dy))
	_tex.update(_buf)


func _blit_dungeon_cell(
	gx: int,
	gy: int,
	dungeon,
	map_x: int,
	map_y: int,
	level: int,
	is_avatar: bool
) -> void:
	var origin := Vector2i(gx * GEM_CELL, gy * GEM_CELL)
	var tok: int = dungeon.token_at(map_x, map_y, level)
	var consumed: bool = dungeon.is_consumed(map_x, map_y, level)
	if dungeon.looks_like_wall(map_x, map_y, level):
		_draw_dungeon_wall(origin)
	elif tok == DNG_LADDER_UP:
		_draw_dungeon_arrow(origin, true, false)
	elif tok == DNG_LADDER_DOWN:
		_draw_dungeon_arrow(origin, false, true)
	elif tok == DNG_LADDER_BOTH:
		_draw_dungeon_arrow(origin, true, true)
	elif tok == DNG_CHEST and not consumed:
		_draw_dungeon_chest(origin)
	elif tok in [DNG_CEILING_HOLE, DNG_FLOOR_HOLE]:
		_draw_dungeon_hole(origin)
	elif tok == DNG_ORB and not consumed:
		_draw_dungeon_orb(origin)
	elif tok == DNG_FOUNTAIN:
		_draw_dungeon_fountain(origin)
	elif tok == DNG_FIELD:
		_draw_dungeon_field(origin, dungeon.field_subtype(map_x, map_y, level))
	elif tok == DNG_ALTAR:
		_draw_dungeon_altar(origin)
	elif tok in [DNG_DOOR, DNG_ROOM]:
		_draw_dungeon_door(origin)
	elif tok == DNG_SECRET:
		_draw_dungeon_secret(origin)
	else:
		_draw_dungeon_floor(origin)
	if is_avatar:
		_draw_dungeon_avatar(origin)


func _draw_dungeon_floor(origin: Vector2i) -> void:
	_buf.fill_rect(Rect2i(origin + Vector2i(3, 3), Vector2i(2, 2)), Color(0.18, 0.22, 0.28, 1))


func _draw_dungeon_wall(origin: Vector2i) -> void:
	_buf.fill_rect(Rect2i(origin, Vector2i(8, 8)), Color(0.16, 0.18, 0.22, 1))
	_buf.fill_rect(Rect2i(origin + Vector2i(1, 1), Vector2i(6, 6)), Color(0.48, 0.5, 0.54, 1))
	_buf.fill_rect(Rect2i(origin + Vector2i(1, 1), Vector2i(6, 1)), Color(0.7, 0.72, 0.76, 1))


func _draw_dungeon_arrow(origin: Vector2i, up: bool, down: bool) -> void:
	var c := Color(0.72, 0.9, 1.0, 1)
	if up:
		_buf.set_pixelv(origin + Vector2i(3, 1), c)
		_buf.set_pixelv(origin + Vector2i(4, 1), c)
		_buf.fill_rect(Rect2i(origin + Vector2i(2, 2), Vector2i(4, 1)), c)
		_buf.fill_rect(Rect2i(origin + Vector2i(3, 3), Vector2i(2, 2)), c)
	if down:
		_buf.fill_rect(Rect2i(origin + Vector2i(3, 3 if up else 2), Vector2i(2, 2)), c)
		_buf.fill_rect(Rect2i(origin + Vector2i(2, 5), Vector2i(4, 1)), c)
		_buf.set_pixelv(origin + Vector2i(3, 6), c)
		_buf.set_pixelv(origin + Vector2i(4, 6), c)


func _draw_dungeon_chest(origin: Vector2i) -> void:
	var c := Color(0.92, 0.66, 0.18, 1)
	_buf.fill_rect(Rect2i(origin + Vector2i(1, 3), Vector2i(6, 4)), c)
	_buf.fill_rect(Rect2i(origin + Vector2i(2, 1), Vector2i(4, 2)), c)
	_buf.fill_rect(Rect2i(origin + Vector2i(3, 4), Vector2i(2, 2)), Color(0.18, 0.12, 0.05, 1))


func _draw_dungeon_hole(origin: Vector2i) -> void:
	var c := Color(0.66, 0.48, 0.82, 1)
	_buf.fill_rect(Rect2i(origin + Vector2i(1, 2), Vector2i(6, 1)), c)
	_buf.fill_rect(Rect2i(origin + Vector2i(3, 3), Vector2i(2, 4)), c)


func _draw_dungeon_orb(origin: Vector2i) -> void:
	var c := Color(0.66, 0.94, 1.0, 1)
	_buf.fill_rect(Rect2i(origin + Vector2i(2, 1), Vector2i(4, 6)), c)
	_buf.fill_rect(Rect2i(origin + Vector2i(1, 2), Vector2i(6, 4)), c)
	_buf.fill_rect(Rect2i(origin + Vector2i(3, 2), Vector2i(2, 2)), Color.WHITE)


func _draw_dungeon_fountain(origin: Vector2i) -> void:
	var stone := Color(0.62, 0.64, 0.66, 1)
	var water := Color(0.15, 0.82, 0.95, 1)
	_buf.fill_rect(Rect2i(origin + Vector2i(1, 5), Vector2i(6, 2)), stone)
	_buf.fill_rect(Rect2i(origin + Vector2i(3, 2), Vector2i(2, 4)), stone)
	_buf.set_pixelv(origin + Vector2i(2, 2), water)
	_buf.set_pixelv(origin + Vector2i(5, 2), water)
	_buf.fill_rect(Rect2i(origin + Vector2i(2, 4), Vector2i(4, 1)), water)


func _draw_dungeon_field(origin: Vector2i, subtype: int) -> void:
	var colors: Array[Color] = [
		Color(0.25, 0.85, 0.2, 1),
		Color(0.35, 0.75, 1.0, 1),
		Color(1.0, 0.36, 0.08, 1),
		Color(0.65, 0.45, 0.9, 1),
	]
	var c: Color = colors[clampi(subtype, 0, colors.size() - 1)]
	for x in range(1, 7):
		var y := 5 - absi(x - 3)
		_buf.set_pixelv(origin + Vector2i(x, y), c)
		_buf.set_pixelv(origin + Vector2i(x, y + 1), c)


func _draw_dungeon_altar(origin: Vector2i) -> void:
	var c := Color(0.92, 0.9, 0.72, 1)
	_buf.fill_rect(Rect2i(origin + Vector2i(3, 1), Vector2i(2, 6)), c)
	_buf.fill_rect(Rect2i(origin + Vector2i(1, 3), Vector2i(6, 2)), c)


func _draw_dungeon_door(origin: Vector2i) -> void:
	var c := Color(0.68, 0.4, 0.2, 1)
	_buf.fill_rect(Rect2i(origin + Vector2i(1, 1), Vector2i(6, 1)), c)
	_buf.fill_rect(Rect2i(origin + Vector2i(1, 2), Vector2i(1, 6)), c)
	_buf.fill_rect(Rect2i(origin + Vector2i(6, 2), Vector2i(1, 6)), c)


func _draw_dungeon_secret(origin: Vector2i) -> void:
	var c := Color(0.75, 0.5, 0.78, 1)
	for y in range(1, 7, 2):
		_buf.set_pixelv(origin + Vector2i(1, y), c)
		_buf.set_pixelv(origin + Vector2i(6, y), c)
	_buf.fill_rect(Rect2i(origin + Vector2i(2, 1), Vector2i(4, 1)), c)


func _draw_dungeon_avatar(origin: Vector2i) -> void:
	var c := Color(1.0, 0.16, 0.12, 1)
	_buf.fill_rect(Rect2i(origin + Vector2i(2, 2), Vector2i(4, 4)), c)
	_buf.fill_rect(Rect2i(origin + Vector2i(3, 1), Vector2i(2, 6)), Color(1.0, 0.42, 0.26, 1))


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
	var map_aspect := (float(_view_w) / float(_view_h)) * cell_aspect
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
