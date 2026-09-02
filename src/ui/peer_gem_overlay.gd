class_name PeerGemOverlay
extends Control

## Peer gem map overlay. xu4 Standard is 32×32; we keep an odd vertical
## span and widen to ~16:9 so more terrain shows left/right (party #1 centered).
## New Color terrain uses classic gem.png; Apple II Color/Mono downscale the
## active U4TileBank so Peer matches the current graphics mode.

signal closed

const GEM_PATH := "res://assets/tiles/u4graphics/gem.png"
const _U4TileBankScript := preload("res://src/map/u4_tile_bank.gd")
const _Apple2HgrNtsc := preload("res://src/map/apple2_hgr_ntsc.gd")
## Odd so center.x/y land on one middle cell (xu4's 32 is even → off-center).
const GEM_VIEW_H := 33
## ~GEM_VIEW_H × 16/9, forced odd (59/33 ≈ 16:9).
const GEM_VIEW_W := 59
## Explore tiles follow MapView.display_aspect() (8.75:10).
const TILE_ASPECT := 14.0 / 16.0
## Native gem.png / dungeon glyph cell.
const GEM_CHIP := 8
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
## Fallback avatar id (party #1 class tile preferred).
const AVATAR_GEM_TILE := 31
const CLASS_TILE_EVEN := [32, 34, 36, 38, 40, 42, 44, 46]
## Bank miss + id ≥ 128: gem sheet only has 0–127.
const TILE_CITIZEN := 82
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
## Party cell flash so the gem is easy to read in a crowd.
const BLINK_HALF_SEC := 0.32
const MARKER_ON := Color(1.0, 0.92, 0.22, 0.62)
const MARKER_OFF := Color(1.0, 0.92, 0.22, 0.0)

var _dim: ColorRect
var _panel: Panel
var _tex_rect: TextureRect
var _party_marker: ColorRect
var _loc_plate: Panel
var _loc_label: Label
var _gem_sheet: Image
var _buf: Image
var _tex: ImageTexture
var _open := false
var _view_w := GEM_VIEW_W
var _view_h := GEM_VIEW_H
## Buffer pixels per map cell (game tile aspect; window/Retina density).
var _cell_w := GEM_CHIP
var _cell_h := GEM_CHIP
var _scaled_chips: Array = []
var _scaled_chip_size := Vector2i.ZERO
## Downscaled U4TileBank chips for Apple II / live tileset mode.
var _bank_chips: Array = []
var _bank_chip_size := Vector2i.ZERO
var _bank_chip_set := ""
var _party_cell := Vector2i(-1, -1)
var _blink_accum := 0.0
var _blink_show := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(false)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_load_gem_sheet()


func is_open() -> bool:
	return _open


func invalidate_tileset() -> void:
	## Options → Graphics: drop cached chips so the next Peer uses the active set.
	_scaled_chips.clear()
	_scaled_chip_size = Vector2i.ZERO
	_bank_chips.clear()
	_bank_chip_size = Vector2i.ZERO
	_bank_chip_set = ""


func _uses_classic_gem_sheet() -> bool:
	## DOS gem.png matches New Color only. Apple II Color/Mono use live bank art.
	return _U4TileBankScript.render_pipeline() == _U4TileBankScript.RenderPipeline.NEW_COLOR_PNG


func open_peer(
	world, ## WorldMapData
	center: Vector2i,
	tile_size: Vector2,
	loc_text: String = "",
	map_view = null ## MapView — overlays, moongate, creatures
) -> void:
	if world == null or not world.loaded:
		return
	_begin_view(GEM_VIEW_W, GEM_VIEW_H, tile_size)
	_blit_gem_map(world, center, map_view)
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
	_begin_view(GEM_VIEW_W, GEM_VIEW_H, tile_size)
	_blit_gem_city(city, party_pos)
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
	_begin_view(DUNGEON_VIEW_W, DUNGEON_VIEW_H, tile_size)
	_blit_gem_dungeon(dungeon, center, level)
	_set_loc_text("")
	_open = true
	visible = true
	move_to_front()


func close_peer() -> void:
	if not _open:
		return
	_open = false
	_stop_party_blink()
	visible = false
	closed.emit()


func _process(delta: float) -> void:
	if not _open:
		_stop_party_blink()
		return
	_blink_accum += delta
	if _blink_accum < BLINK_HALF_SEC:
		return
	_blink_accum -= BLINK_HALF_SEC
	_blink_show = not _blink_show
	_sync_party_marker()


func _start_party_blink(gx: int, gy: int) -> void:
	if gx < 0 or gy < 0 or gx >= _view_w or gy >= _view_h:
		_stop_party_blink()
		return
	_party_cell = Vector2i(gx, gy)
	_blink_accum = 0.0
	_blink_show = true
	_layout_party_marker()
	_sync_party_marker()
	set_process(true)


func _stop_party_blink() -> void:
	set_process(false)
	_party_cell = Vector2i(-1, -1)
	_blink_accum = 0.0
	_blink_show = true
	if _party_marker:
		_party_marker.visible = false


func _layout_party_marker() -> void:
	if _party_marker == null or _tex_rect == null:
		return
	if _party_cell.x < 0 or _party_cell.y < 0:
		_party_marker.visible = false
		return
	var cell := Vector2(
		_tex_rect.size.x / float(maxi(_view_w, 1)),
		_tex_rect.size.y / float(maxi(_view_h, 1))
	)
	_party_marker.size = cell
	_party_marker.position = _tex_rect.position + Vector2(
		float(_party_cell.x) * cell.x,
		float(_party_cell.y) * cell.y
	)


func _sync_party_marker() -> void:
	if _party_marker == null:
		return
	_party_marker.visible = _party_cell.x >= 0
	_party_marker.color = MARKER_ON if _blink_show else MARKER_OFF


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
	sb.border_color = UiTheme.FOCUS_BORDER
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

	_party_marker = ColorRect.new()
	_party_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party_marker.visible = false
	_party_marker.color = MARKER_ON
	_panel.add_child(_party_marker)

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


func _begin_view(view_w: int, view_h: int, tile_size: Vector2) -> void:
	_stop_party_blink()
	_view_w = view_w
	_view_h = view_h
	_layout_panel(tile_size)
	_ensure_buffers(view_w, view_h)


func _ensure_buffers(view_w: int, view_h: int) -> void:
	_view_w = view_w
	_view_h = view_h
	var px_w := view_w * _cell_w
	var px_h := view_h * _cell_h
	if _buf != null and _buf.get_width() == px_w and _buf.get_height() == px_h:
		return
	_buf = Image.create(px_w, px_h, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_buf)
	if _tex_rect:
		_tex_rect.texture = _tex


func _party_gem_tile() -> int:
	## Party #1 walk sprite (in-game shape, downscaled onto the gem).
	var klass := GameState.party_leader_class()
	if klass >= 0 and klass < CLASS_TILE_EVEN.size():
		var tid: int = CLASS_TILE_EVEN[klass]
		if tid < 128:
			return tid
	return AVATAR_GEM_TILE


func _blit_gem_map(world: WorldMapData, center: Vector2i, map_view = null) -> void:
	if _buf == null:
		return
	if _uses_classic_gem_sheet() and (_gem_sheet == null or _gem_sheet.is_empty()):
		return
	_buf.fill(Color(0, 0, 0, 1))
	## Odd spans → half lands on the true center cell for party #1.
	var half_x := GEM_VIEW_W / 2
	var half_y := GEM_VIEW_H / 2
	if _U4TileBankScript.uses_hgr_ntsc():
		var ids := PackedInt32Array()
		ids.resize(GEM_VIEW_W * GEM_VIEW_H)
		for gy in GEM_VIEW_H:
			for gx in GEM_VIEW_W:
				var wx := center.x + gx - half_x
				var wy := center.y + gy - half_y
				ids[gy * GEM_VIEW_W + gx] = world.tile_at(wx, wy)
		if map_view != null:
			if map_view.has_method("get_overlays"):
				for item in map_view.get_overlays():
					_set_apple2_world_object(ids, center, item)
			if map_view.has_method("peer_moongate"):
				var gate: Vector3i = map_view.peer_moongate()
				if gate.z >= 0:
					_set_apple2_world_object(ids, center, gate)
			if map_view.has_method("get_creatures"):
				for creature in map_view.get_creatures():
					_set_apple2_world_object(
						ids,
						center,
						Vector3i(int(creature.x), int(creature.y), int(creature.tid))
					)
		ids[half_y * GEM_VIEW_W + half_x] = _party_gem_tile()
		_blit_apple2_grid(ids, GEM_VIEW_W, GEM_VIEW_H, Vector2i.ZERO)
		_tex.update(_buf)
		_start_party_blink(half_x, half_y)
		return
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
	_blit_gem_actor(half_x, half_y, _party_gem_tile())
	_tex.update(_buf)
	_start_party_blink(half_x, half_y)


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
	_start_party_blink(center_x, center_y)


func _blit_dungeon_cell(
	gx: int,
	gy: int,
	dungeon,
	map_x: int,
	map_y: int,
	level: int,
	is_avatar: bool
) -> void:
	var origin := Vector2i(gx * _cell_w, gy * _cell_h)
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


func _dsx(n: int) -> int:
	return (n * _cell_w) / GEM_CHIP


func _dsy(n: int) -> int:
	return (n * _cell_h) / GEM_CHIP


func _dpt(origin: Vector2i, x: int, y: int) -> Vector2i:
	return origin + Vector2i(_dsx(x), _dsy(y))


func _drect(origin: Vector2i, x: int, y: int, w: int, h: int) -> Rect2i:
	return Rect2i(_dpt(origin, x, y), Vector2i(_dsx(w), _dsy(h)))


func _dset(origin: Vector2i, x: int, y: int, c: Color) -> void:
	_buf.fill_rect(_drect(origin, x, y, 1, 1), c)


func _draw_dungeon_floor(origin: Vector2i) -> void:
	_buf.fill_rect(_drect(origin, 3, 3, 2, 2), Color(0.18, 0.22, 0.28, 1))


func _draw_dungeon_wall(origin: Vector2i) -> void:
	_buf.fill_rect(_drect(origin, 0, 0, 8, 8), Color(0.16, 0.18, 0.22, 1))
	_buf.fill_rect(_drect(origin, 1, 1, 6, 6), Color(0.48, 0.5, 0.54, 1))
	_buf.fill_rect(_drect(origin, 1, 1, 6, 1), Color(0.7, 0.72, 0.76, 1))


func _draw_dungeon_arrow(origin: Vector2i, up: bool, down: bool) -> void:
	var c := Color(0.72, 0.9, 1.0, 1)
	if up:
		_dset(origin, 3, 1, c)
		_dset(origin, 4, 1, c)
		_buf.fill_rect(_drect(origin, 2, 2, 4, 1), c)
		_buf.fill_rect(_drect(origin, 3, 3, 2, 2), c)
	if down:
		_buf.fill_rect(_drect(origin, 3, 3 if up else 2, 2, 2), c)
		_buf.fill_rect(_drect(origin, 2, 5, 4, 1), c)
		_dset(origin, 3, 6, c)
		_dset(origin, 4, 6, c)


func _draw_dungeon_chest(origin: Vector2i) -> void:
	var c := Color(0.92, 0.66, 0.18, 1)
	_buf.fill_rect(_drect(origin, 1, 3, 6, 4), c)
	_buf.fill_rect(_drect(origin, 2, 1, 4, 2), c)
	_buf.fill_rect(_drect(origin, 3, 4, 2, 2), Color(0.18, 0.12, 0.05, 1))


func _draw_dungeon_hole(origin: Vector2i) -> void:
	var c := Color(0.66, 0.48, 0.82, 1)
	_buf.fill_rect(_drect(origin, 1, 2, 6, 1), c)
	_buf.fill_rect(_drect(origin, 3, 3, 2, 4), c)


func _draw_dungeon_orb(origin: Vector2i) -> void:
	var c := Color(0.66, 0.94, 1.0, 1)
	_buf.fill_rect(_drect(origin, 2, 1, 4, 6), c)
	_buf.fill_rect(_drect(origin, 1, 2, 6, 4), c)
	_buf.fill_rect(_drect(origin, 3, 2, 2, 2), Color.WHITE)


func _draw_dungeon_fountain(origin: Vector2i) -> void:
	var stone := Color(0.62, 0.64, 0.66, 1)
	var water := Color(0.15, 0.82, 0.95, 1)
	_buf.fill_rect(_drect(origin, 1, 5, 6, 2), stone)
	_buf.fill_rect(_drect(origin, 3, 2, 2, 4), stone)
	_dset(origin, 2, 2, water)
	_dset(origin, 5, 2, water)
	_buf.fill_rect(_drect(origin, 2, 4, 4, 1), water)


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
		_dset(origin, x, y, c)
		_dset(origin, x, y + 1, c)


func _draw_dungeon_altar(origin: Vector2i) -> void:
	var c := Color(0.92, 0.9, 0.72, 1)
	_buf.fill_rect(_drect(origin, 3, 1, 2, 6), c)
	_buf.fill_rect(_drect(origin, 1, 3, 6, 2), c)


func _draw_dungeon_door(origin: Vector2i) -> void:
	var c := Color(0.68, 0.4, 0.2, 1)
	_buf.fill_rect(_drect(origin, 1, 1, 6, 1), c)
	_buf.fill_rect(_drect(origin, 1, 2, 1, 6), c)
	_buf.fill_rect(_drect(origin, 6, 2, 1, 6), c)


func _draw_dungeon_secret(origin: Vector2i) -> void:
	var c := Color(0.75, 0.5, 0.78, 1)
	for y in range(1, 7, 2):
		_dset(origin, 1, y, c)
		_dset(origin, 6, y, c)
	_buf.fill_rect(_drect(origin, 2, 1, 4, 1), c)


func _draw_dungeon_avatar(origin: Vector2i) -> void:
	var c := Color(1.0, 0.16, 0.12, 1)
	_buf.fill_rect(_drect(origin, 2, 2, 4, 4), c)
	_buf.fill_rect(_drect(origin, 3, 1, 2, 6), Color(1.0, 0.42, 0.26, 1))


func _blit_gem_city(city, party_pos: Vector2i = Vector2i(-1, -1)) -> void:
	## Center the 32×32 .ULT in the wider gem viewport; void outside is black.
	if _buf == null:
		return
	if _uses_classic_gem_sheet() and (_gem_sheet == null or _gem_sheet.is_empty()):
		return
	_buf.fill(Color(0, 0, 0, 1))
	var city_w := 32
	var city_h := 32
	var origin_x := int((GEM_VIEW_W - city_w) / 2)
	var origin_y := int((GEM_VIEW_H - city_h) / 2)
	var live: bool = party_pos.x >= 0 and bool(city.has_method("effective_tile_at"))
	if _U4TileBankScript.uses_hgr_ntsc():
		var ids := PackedInt32Array()
		ids.resize(city_w * city_h)
		for cy in city_h:
			for cx in city_w:
				if live:
					ids[cy * city_w + cx] = int(city.effective_tile_at(cx, cy))
				else:
					ids[cy * city_w + cx] = int(city.tile_at(cx, cy))
		if city.get("persons") != null:
			for p in city.persons:
				var px := int(p.x)
				var py := int(p.y)
				if px >= 0 and py >= 0 and px < city_w and py < city_h:
					ids[py * city_w + px] = int(p.z)
		if (
			party_pos.x >= 0
			and party_pos.x < city_w
			and party_pos.y >= 0
			and party_pos.y < city_h
		):
			ids[party_pos.y * city_w + party_pos.x] = _party_gem_tile()
		_blit_apple2_grid(
			ids,
			city_w,
			city_h,
			Vector2i(origin_x * _cell_w, origin_y * _cell_h)
		)
		_tex.update(_buf)
		if (
			party_pos.x >= 0
			and party_pos.x < city_w
			and party_pos.y >= 0
			and party_pos.y < city_h
		):
			_start_party_blink(origin_x + party_pos.x, origin_y + party_pos.y)
		return
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
		_start_party_blink(origin_x + party_pos.x, origin_y + party_pos.y)
		return
	_tex.update(_buf)


func _set_apple2_world_object(
	ids: PackedInt32Array, center: Vector2i, item: Vector3i
) -> void:
	var d := _wrap_delta(center, Vector2i(item.x, item.y))
	var gx := d.x + GEM_VIEW_W / 2
	var gy := d.y + GEM_VIEW_H / 2
	if gx < 0 or gy < 0 or gx >= GEM_VIEW_W or gy >= GEM_VIEW_H:
		return
	ids[gy * GEM_VIEW_W + gx] = clampi(item.z, 0, _U4TileBankScript.COUNT - 1)


func _blit_apple2_grid(
	ids: PackedInt32Array, cols: int, rows: int, dest: Vector2i
) -> void:
	## Decode the final terrain+actor field in one pass so NTSC state continues
	## through every tile boundary, matching the explore and title maps.
	var composed: Image = _Apple2HgrNtsc.render_grid(ids, cols, rows, 0, false)
	if composed == null or composed.is_empty():
		return
	var want := Vector2i(cols * _cell_w, rows * _cell_h)
	if composed.get_size() != want:
		composed.resize(want.x, want.y, Image.INTERPOLATE_NEAREST)
	_buf.blit_rect(composed, Rect2i(Vector2i.ZERO, want), dest)


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
	## Wilderness overlays and creatures: same shapes as the explore map.
	_blit_gem_actor(gx, gy, tile_id)


func _blit_bank_chip(gx: int, gy: int, tile_id: int, blend: bool = true) -> bool:
	var chip := _scaled_bank_chip(tile_id)
	if chip == null:
		return false
	var dest := Vector2i(gx * _cell_w, gy * _cell_h)
	var src := Rect2i(0, 0, _cell_w, _cell_h)
	if blend:
		_buf.blend_rect(chip, src, dest)
	else:
		_buf.blit_rect(chip, src, dest)
	return true


func _blit_gem_actor(gx: int, gy: int, tile_id: int) -> void:
	## People and party: always the active tileset (downscaled), not DOS gem.png.
	if tile_id < 0:
		return
	if _blit_bank_chip(gx, gy, tile_id, true):
		return
	var tid := tile_id
	if tid >= 128:
		tid = TILE_CITIZEN
	_blit_gem_cell(gx, gy, tid)


func _blit_gem_cell(gx: int, gy: int, tile_id: int) -> void:
	var dest := Vector2i(gx * _cell_w, gy * _cell_h)
	if not _uses_classic_gem_sheet():
		## Apple II Color / Mono: terrain matches the explore map tileset.
		if tile_id < 0:
			_buf.fill_rect(Rect2i(dest, Vector2i(_cell_w, _cell_h)), Color(0, 0, 0, 1))
			return
		if _blit_bank_chip(gx, gy, tile_id, false):
			return
		_buf.fill_rect(Rect2i(dest, Vector2i(_cell_w, _cell_h)), Color(0, 0, 0, 1))
		return
	if tile_id < 0 or tile_id >= 128:
		## xu4: ids ≥ 128 are drawn black on the gem.
		_buf.fill_rect(Rect2i(dest, Vector2i(_cell_w, _cell_h)), Color(0, 0, 0, 1))
		return
	var chip := _scaled_gem_chip(tile_id)
	if chip == null:
		return
	_buf.blit_rect(chip, Rect2i(0, 0, _cell_w, _cell_h), dest)


func _scaled_bank_chip(tile_id: int) -> Image:
	if tile_id < 0 or not _U4TileBankScript.ensure_loaded():
		return null
	var want := Vector2i(_cell_w, _cell_h)
	var set_id := _U4TileBankScript.active_set()
	if (
		_bank_chip_size != want
		or _bank_chip_set != set_id
		or _bank_chips.size() != _U4TileBankScript.COUNT
	):
		_bank_chips.clear()
		_bank_chips.resize(_U4TileBankScript.COUNT)
		_bank_chip_size = want
		_bank_chip_set = set_id
	if tile_id >= _bank_chips.size():
		return null
	if _bank_chips[tile_id] != null:
		return _bank_chips[tile_id]
	## keyed_copy: New Color keys border black; Apple II keeps opaque CRT ink.
	var img := _U4TileBankScript.keyed_copy(tile_id)
	if img == null or img.is_empty():
		return null
	var chip := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	chip.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i.ZERO)
	if chip.get_width() != want.x or chip.get_height() != want.y:
		chip.resize(want.x, want.y, Image.INTERPOLATE_NEAREST)
	_bank_chips[tile_id] = chip
	return chip


func _scaled_gem_chip(tile_id: int) -> Image:
	if _gem_sheet == null or _gem_sheet.is_empty():
		return null
	var want := Vector2i(_cell_w, _cell_h)
	if _scaled_chip_size != want or _scaled_chips.size() != 128:
		_scaled_chips.clear()
		_scaled_chips.resize(128)
		_scaled_chip_size = want
	if _scaled_chips[tile_id] != null:
		return _scaled_chips[tile_id]
	var src := Rect2i(0, tile_id * GEM_CHIP, GEM_CHIP, GEM_CHIP)
	var chip := Image.create(GEM_CHIP, GEM_CHIP, false, Image.FORMAT_RGBA8)
	chip.blit_rect(_gem_sheet, src, Vector2i.ZERO)
	if want.x != GEM_CHIP or want.y != GEM_CHIP:
		chip.resize(want.x, want.y, Image.INTERPOLATE_NEAREST)
	_scaled_chips[tile_id] = chip
	return chip


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


func _pixel_scale() -> Vector2:
	## Canvas → screen pixels. UI layout stays 1280×720; the gem buffer uses
	## the window / Retina density so it is not a 720p bitmap stretched up.
	var sx := 1.0
	var sy := 1.0
	var vp := get_viewport()
	if vp:
		var xf := vp.get_screen_transform()
		sx = absf(xf.x.x)
		sy = absf(xf.y.y)
	var win := get_window()
	if win and (sx < 1.05 and sy < 1.05):
		var dw := float(maxi(win.content_scale_size.x, 1))
		var dh := float(maxi(win.content_scale_size.y, 1))
		sx = maxf(sx, float(maxi(win.size.x, 1)) / dw)
		sy = maxf(sy, float(maxi(win.size.y, 1)) / dh)
	return Vector2(maxf(sx, 1.0), maxf(sy, 1.0))


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
	var px := _pixel_scale()
	_cell_w = maxi(1, int(round((inner_w / float(_view_w)) * px.x)))
	_cell_h = maxi(1, int(round((inner_h / float(_view_h)) * px.y)))
	_layout_loc_label()
	_layout_party_marker()
