class_name DungeonView
extends RefCounted

## First-person corridor: 9 rings 3:3:2.5:2:2:2:2.5:3:3 (23 units).
## Draw current + 4 cells ahead. Cell +5 is wall/not-wall only.

const _DungeonMap := preload("res://src/map/dungeon_map_data.gd")
const _DungeonPortals := preload("res://src/map/dungeon_portals.gd")
const _U4TileBank := preload("res://src/map/u4_tile_bank.gd")
const _WorldCreatures := preload("res://src/map/world_creatures.gd")
const _ResImage := preload("res://src/core/res_image.gd")
const _SpecialItemIcons := preload("res://src/core/special_item_icons.gd")

const ASSET_ROOT := "res://assets/dungeon"
const MAX_DEPTH := 4
const PEEK_DEPTH := 5
## Widest column still on screen at the farthest row (half-width 1 of 11.5).
const SIDE_REACH := 6
## View grid: one extra column per side and the peek row so every drawn cell's
## inner/outer and far neighbours resolve from the grid.
const GRID_LAT := SIDE_REACH + 1
const GRID_COLS := GRID_LAT * 2 + 1
const GRID_ROWS := PEEK_DEPTH + 1
## Monster / fountain / field frames are cached per animation step; drop them
## past this count so long sessions cannot grow memory without bound.
const ANIM_PIECE_CACHE_MAX := 256
const RING_CUMUL: Array[float] = [0.0, 3.0, 6.0, 8.5, 10.5, 12.5]
const RING_DENOM := 23.0
const OBJ_NSCALE: Array[int] = [12, 8, 5, 3, 1]
const OBJ_VIEW_RATIO := 0.28
const CHEST_VIEW_SCALE := 2.0
const FOUNTAIN_VIEW_SCALE := 2.0
const ALTAR_VIEW_SCALE := 2.0
## Search stone resting on an unclaimed altar (fraction of the altar span).
const ALTAR_STONE_VIEW_SCALE := 0.21
## Sit the stone on the altar's top slab (0 = top of altar box, 1 = floor).
const ALTAR_STONE_TOP_T := 0.46
const ORB_VIEW_SCALE := 2.0
const MONSTER_VIEW_SCALE := 2.0
const OBJ_FLOOR_POSITION := 0.5
## Increment when cached rasterization rules change during a hot reload.
const PIECE_CACHE_REV := 40
## Ring at which fog reaches DIM_FAR: the innermost square (four cells ahead).
const FOG_FULL_RING := 10.5
## Darkest fog brightness, from the innermost square inward (torch).
const DIM_FAR := 0.05
## Light spell reaches a little farther than a torch.
const DIM_FAR_MAGIC := 0.10
const TILE_CHEST := 60
const TILE_ALTAR := 74
const TILE_ORB := 78
const TILE_FOUNTAIN := 75
const TILE_FIELD_POISON := 68
const TILE_FIELD_ENERGY := 69
const TILE_FIELD_FIRE := 70
const TILE_FIELD_SLEEP := 71
const TILE_MONSTER_FIRST := 144
const TILE_MONSTER_LAST := 252
## Per-chunk size when three rocks stack in a triangle.
const FALLING_ROCK_CHUNK_SCALE := 1.53
## Base gap as a fraction of chunk span (randomized per trap).
const FALLING_ROCK_BASE_GAP_MIN := 0.34
const FALLING_ROCK_BASE_GAP_MAX := 0.44
## Apex bottom above floor Y — keep high enough that it rests on the two below.
const FALLING_ROCK_STACK_LIFT_MIN := 0.48
const FALLING_ROCK_STACK_LIFT_MAX := 0.56
const LADDER_UP := 1
const LADDER_DOWN := 2
const VIEW_OBJECT_TILE := 0
const VIEW_OBJECT_LADDER := 1
const VIEW_OBJECT_FLOOR_FIELD := 2

var theme_id: String = "grey_stone"
var _wall: Image
var _floor_plane: Image
var _entrance: Image
var _doorway_frame: Image
var _doorway_open_rect := Rect2i()
var _ladder_half: Image
var _fountain_frames: Array[Image] = []
var _theme_loaded := ""
var _theme_pipeline := -1
var _dim_lut: PackedFloat32Array = PackedFloat32Array()
var _dim_lut_w := 0
var _dim_lut_h := 0
var _dim_lut_inner := -1
var _piece_cache: Dictionary = {}
var _anim_piece_cache: Dictionary = {}
var _piece_cache_w := 0
var _piece_cache_h := 0
var _keyed_monster_cache: Dictionary = {}
var _keyed_stone_cache: Dictionary = {} ## bit_index → keyed Image
var _floor_bg: Image
var _floor_bg_w := 0
var _floor_bg_h := 0
var _floor_bg_pipeline := -1
var _floor_bg_inner := -1
var _floor_bg_far := -1.0
var _dim_lut_far := -1.0
var _scanlines_on := false
## Cells ahead indexed by _view_index(depth, lateral); rebuilt every paint.
var _view_cells: Array[Vector2i] = []
var _view_solid := PackedByteArray()
var _view_seen := PackedByteArray()
## What the last paint() depended on; empty forces the next repaint.
var _last_signature: Array = []
var _last_animated := false
var _last_anim_frame := 0
## Set by the caller each paint: Light spell instead of a torch.
var magic_light := false


func set_theme(id: String) -> void:
	var pipeline := _U4TileBank.render_pipeline()
	_scanlines_on = pipeline != _U4TileBank.RenderPipeline.NEW_COLOR_PNG
	if _ladder_half == null:
		_ladder_half = _load_png("%s/ladder_half.png" % ASSET_ROOT)
	## Reload on dungeon entry/theme setup so replaced source art cannot remain
	## hidden behind frames cached by an earlier DungeonView session.
	_fountain_frames = [
		_load_png("%s/fountain_0.png" % ASSET_ROOT),
		_load_png("%s/fountain_1.png" % ASSET_ROOT),
	]
	_anim_piece_cache.clear()
	_last_signature = []
	if (
		id == _theme_loaded
		and pipeline == _theme_pipeline
		and _wall != null
		and _floor_plane != null
	):
		theme_id = id
		return
	theme_id = id
	_theme_loaded = id
	_theme_pipeline = pipeline
	_piece_cache.clear()
	_clear_floor_bg()
	## One tile per kind — crop/scale by depth instead of swapping patterns.
	_wall = _load_png("%s/%s/wall.png" % [ASSET_ROOT, id])
	_floor_plane = _load_png("%s/%s/floor_plane.png" % [ASSET_ROOT, id])
	_entrance = _load_png("%s/%s/room_entrance.png" % [ASSET_ROOT, id])
	_doorway_frame = null


func invalidate_tile_caches() -> void:
	## U4TileBank tileset swap — monster/object keyed copies must rebuild.
	## Theme PNGs also reload so Apple II grayscale / green filter can change.
	_keyed_monster_cache.clear()
	_keyed_stone_cache.clear()
	_piece_cache.clear()
	_anim_piece_cache.clear()
	_last_signature = []
	_piece_cache_w = 0
	_piece_cache_h = 0
	_theme_loaded = ""
	_theme_pipeline = -1
	_scanlines_on = false
	_wall = null
	_floor_plane = null
	_entrance = null
	_doorway_frame = null
	_ladder_half = null
	_fountain_frames.clear()
	_clear_floor_bg()


func paint(
	buf: Image,
	dmap,
	pos: Vector2i,
	z: int,
	dir: int,
	lit: bool,
	anim_frame: int = 0
) -> void:
	_last_signature = []
	_last_animated = false
	_last_anim_frame = anim_frame
	if buf == null or dmap == null or not dmap.loaded:
		return
	var w := buf.get_width()
	var h := buf.get_height()
	if w < 8 or h < 8:
		return
	if not lit:
		buf.fill(Color(0, 0, 0, 1))
		_last_signature = _scan_view(dmap, pos, z, dir, lit)
		return
	if _wall == null:
		set_theme(theme_id)
	_ensure_dim_lut(w, h)
	_ensure_piece_cache_size(w, h)
	_last_signature = _scan_view(dmap, pos, z, dir, lit)
	_mark_visible_cells(w, h)
	if not _paint_floor_plane_background(buf):
		buf.fill(Color(0, 0, 0, 1))
	var center_stop := _center_block_depth()
	var view_objects: Array[Dictionary] = []
	## Painter's order over the visible grid: farthest row first, and within a
	## row outer columns first, so nearer faces cover farther ones. Cells no
	## screen column can see are skipped entirely.
	if center_stop > MAX_DEPTH:
		_paint_peek_wall(buf, dmap, z, w, h)
	var lateral_order := _lateral_order()
	for depth in range(MAX_DEPTH, -1, -1):
		for lateral in lateral_order:
			if _view_seen[_view_index(depth, lateral)] != 0:
				_paint_grid_cell(buf, dmap, z, dir, depth, lateral, w, h, anim_frame)
	for depth in range(0, center_stop):
		var ahead_cell := _view_cell(depth, 0)
		var left_cell := _view_cell(depth, -1)
		var right_cell := _view_cell(depth, 1)
		var front := _view_cell(depth + 1, 0)
		var tok: int = dmap.token_at(ahead_cell.x, ahead_cell.y, z)
		var monster_tile := int(dmap.monster_tile_at(ahead_cell.x, ahead_cell.y, z))
		if monster_tile >= 0 and not _is_blocking_wall(dmap, ahead_cell, z):
			view_objects.append({
				"kind": VIEW_OBJECT_TILE,
				"depth": depth,
				"tile_id": monster_tile,
			})
		var ladder_mode := _ladder_mode(tok)
		if ladder_mode != 0:
			view_objects.append({
				"kind": VIEW_OBJECT_LADDER,
				"depth": depth,
				"mode": ladder_mode,
			})
		else:
			var tile_id := _cell_object_tile_id(dmap, ahead_cell, z, tok)
			if tile_id >= 0:
				view_objects.append({
					"kind": (
						VIEW_OBJECT_FLOOR_FIELD
						if tile_id in [
							TILE_FIELD_POISON,
							TILE_FIELD_ENERGY,
							TILE_FIELD_FIRE,
							TILE_FIELD_SLEEP,
						]
						else VIEW_OBJECT_TILE
					),
					"depth": depth,
					"tile_id": tile_id,
					"cell_x": ahead_cell.x,
					"cell_y": ahead_cell.y,
					"view_dir": dir,
					"left_surface": (
						dmap.looks_like_wall(left_cell.x, left_cell.y, z)
						or _is_side_entrance(dmap, left_cell, z)
					),
					"right_surface": (
						dmap.looks_like_wall(right_cell.x, right_cell.y, z)
						or _is_side_entrance(dmap, right_cell, z)
					),
					"front_surface": (
						_is_blocking_wall(dmap, front, z)
						or _is_side_entrance(dmap, front, z)
					),
				})
	## Geometry is complete: paint objects back-to-front so no later corridor
	## surface can hide them and nearer objects correctly overlap farther ones.
	for i in range(view_objects.size() - 1, -1, -1):
		var object: Dictionary = view_objects[i]
		if int(object["kind"]) == VIEW_OBJECT_LADDER:
			_paint_ladder_object(
				buf, int(object["mode"]), int(object["depth"]), w, h, 1.0
			)
		elif int(object["kind"]) == VIEW_OBJECT_FLOOR_FIELD:
			_paint_floor_field(
				buf,
				int(object["tile_id"]),
				int(object["depth"]),
				w,
				h,
				anim_frame,
				int(object["view_dir"]),
				bool(object["left_surface"]),
				bool(object["right_surface"]),
				bool(object["front_surface"])
			)
		else:
			_paint_tile_object(
				buf,
				int(object["tile_id"]),
				int(object["depth"]),
				w,
				h,
				anim_frame,
				str(dmap.dungeon_id),
				Vector2i(int(object.get("cell_x", -1)), int(object.get("cell_y", -1))),
				z
			)
	if _is_side_entrance(dmap, pos, z):
		_paint_doorway_frame(buf, w, h)


func needs_repaint(dmap, pos: Vector2i, z: int, dir: int, lit: bool, anim_frame: int) -> bool:
	## False when paint() would reproduce the last image exactly, so timer
	## ticks with nothing animated in view can skip the whole repaint.
	if _last_signature.is_empty():
		return true
	if _last_animated and anim_frame != _last_anim_frame:
		return true
	if dmap == null or not dmap.loaded:
		return true
	return _scan_view(dmap, pos, z, dir, lit) != _last_signature


func _scan_view(dmap, pos: Vector2i, z: int, dir: int, lit: bool) -> Array:
	## Fills the view grid and returns everything that decides what paint() draws.
	var sig: Array = [
		pos, z, dir, lit, magic_light, theme_id, _theme_pipeline,
		str(dmap.dungeon_id), GameState.stones,
	]
	if not lit:
		return sig
	_view_cells.resize(GRID_COLS * GRID_ROWS)
	_view_solid.resize(GRID_COLS * GRID_ROWS)
	var cells := PackedInt32Array()
	var row_start := pos
	for depth in GRID_ROWS:
		if depth > 0:
			row_start = dmap.neighbor(row_start.x, row_start.y, dir)
		var left := row_start
		var right := row_start
		_scan_view_cell(dmap, pos, z, _view_index(depth, 0), row_start, cells)
		for i in range(1, GRID_LAT + 1):
			left = _left_of(dmap, left, dir)
			right = _right_of(dmap, right, dir)
			_scan_view_cell(dmap, pos, z, _view_index(depth, -i), left, cells)
			_scan_view_cell(dmap, pos, z, _view_index(depth, i), right, cells)
	sig.append(cells)
	return sig


func _scan_view_cell(
	dmap, pos: Vector2i, z: int, index: int, cell: Vector2i, cells: PackedInt32Array
) -> void:
	_view_cells[index] = cell
	_view_solid[index] = 1 if _grid_solid(dmap, pos, cell, z) else 0
	cells.append(int(dmap.raw_at(cell.x, cell.y, z)))
	cells.append(int(dmap.annotation_at(cell.x, cell.y, z)))
	cells.append(int(dmap.monster_tile_at(cell.x, cell.y, z)))
	cells.append(int(dmap.is_consumed(cell.x, cell.y, z)))


func _view_index(depth: int, lateral: int) -> int:
	return depth * GRID_COLS + lateral + GRID_LAT


func _view_cell(depth: int, lateral: int) -> Vector2i:
	return _view_cells[_view_index(depth, lateral)]


func _view_is_solid(depth: int, lateral: int) -> bool:
	return _view_solid[_view_index(depth, lateral)] != 0


func _mark_visible_cells(w: int, h: int) -> void:
	## Follow each screen column's line of sight row by row, the way the painted
	## faces occlude it: a column ends at the first solid cell it meets. Columns
	## that cross the same cells are traced together as one span.
	_view_seen.resize(GRID_COLS * GRID_ROWS)
	_view_seen.fill(0)
	var spans: Array[Vector2i] = [Vector2i(0, w)]
	for depth in range(0, MAX_DEPTH + 1):
		var near := _front_rect(depth, w, h)
		var far := _front_rect(depth + 1, w, h)
		var vanish_x := near.position.x + near.size.x / 2
		var next: Array[Vector2i] = []
		for span in spans:
			var x := span.x
			while x < span.y:
				var from_l := _column_cell(x, near)
				var end_x := mini(span.y, near.position.x + (from_l + 1) * near.size.x)
				var to_l: int
				if depth >= MAX_DEPTH:
					## The last row closes at the vanishing point: sight runs outward.
					if x < vanish_x:
						to_l = -GRID_LAT
						end_x = mini(end_x, vanish_x)
					else:
						to_l = GRID_LAT
				else:
					to_l = _column_cell(x, far)
					end_x = mini(end_x, far.position.x + (to_l + 1) * far.size.x)
				if _trace_row(depth, from_l, to_l):
					next.append(Vector2i(x, end_x))
				x = end_x
		spans = next
		if spans.is_empty():
			return


func _column_cell(x: int, plane: Rect2i) -> int:
	return floori(float(x - plane.position.x) / float(plane.size.x))


func _trace_row(depth: int, from_l: int, to_l: int) -> bool:
	## Marks the cells a span crosses in this row; false once a solid cell or
	## the edge of the drawn grid stops it.
	var step := 1 if to_l >= from_l else -1
	var lateral := from_l
	while absi(lateral) <= SIDE_REACH:
		var i := _view_index(depth, lateral)
		_view_seen[i] = 1
		if _view_solid[i] != 0:
			return false
		if lateral == to_l:
			return true
		lateral += step
	return false


func _paint_doorway_frame(buf: Image, w: int, h: int) -> void:
	## Standing in a doorway: the arch opening frames the corridor from one cell ahead.
	var frame := _doorway_frame_image()
	if frame == null:
		return
	var open := _doorway_open_rect
	if open.size.x <= 0 or open.size.y <= 0:
		return
	var inner := _front_rect(1, w, h)
	var sx := float(inner.size.x) / float(open.size.x)
	var sy := float(h - inner.position.y) / float(frame.get_height() - open.position.y)
	var x0 := int(round(float(inner.position.x) - float(open.position.x) * sx))
	var y0 := int(round(float(inner.position.y) - float(open.position.y) * sy))
	var x1 := x0 + int(round(float(frame.get_width()) * sx))
	var y1 := y0 + int(round(float(frame.get_height()) * sy))
	_blit_cached_piece(
		buf,
		"doorway_frame",
		Callable(self, "_blit_scaled").bind(
			frame, x0, y0, x1, y1, 1.0,
			false, 0.0, 1.0, false, false, false, _scanlines_on
		)
	)


func _doorway_frame_image() -> Image:
	## Entrance art with the arch's connected dark interior keyed out.
	if _doorway_frame != null:
		return _doorway_frame
	if _entrance == null:
		return null
	var img: Image = _entrance.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	var iw := img.get_width()
	var ih := img.get_height()
	var seen := PackedByteArray()
	seen.resize(iw * ih)
	var stack: Array[Vector2i] = [Vector2i(iw / 2, ih - 1)]
	var min_p := Vector2i(iw, ih)
	var max_p := Vector2i(-1, -1)
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= iw or p.y >= ih:
			continue
		var idx := p.y * iw + p.x
		if seen[idx] != 0:
			continue
		seen[idx] = 1
		var c := img.get_pixel(p.x, p.y)
		if c.a > 0.08 and maxf(c.r, maxf(c.g, c.b)) > 0.095:
			continue
		img.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
		min_p = Vector2i(mini(min_p.x, p.x), mini(min_p.y, p.y))
		max_p = Vector2i(maxi(max_p.x, p.x), maxi(max_p.y, p.y))
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))
	if max_p.x < min_p.x:
		return null
	_doorway_open_rect = Rect2i(min_p, max_p - min_p + Vector2i.ONE)
	_doorway_frame = img
	return _doorway_frame


func _left_of(dmap, pos: Vector2i, dir: int) -> Vector2i:
	return dmap.neighbor(pos.x, pos.y, posmod(dir + 3, 4))


func _right_of(dmap, pos: Vector2i, dir: int) -> Vector2i:
	return dmap.neighbor(pos.x, pos.y, posmod(dir + 1, 4))


func _is_side_entrance(dmap, cell: Vector2i, z: int) -> bool:
	var tok: int = dmap.token_at(cell.x, cell.y, z)
	return tok == _DungeonMap.TOK_DOOR or tok == _DungeonMap.TOK_ROOM


func _is_blocking_wall(dmap, cell: Vector2i, z: int) -> bool:
	var tok: int = dmap.token_at(cell.x, cell.y, z)
	return tok == _DungeonMap.TOK_WALL or tok == _DungeonMap.TOK_SECRET


func _depth_dim(depth: int) -> float:
	## Ring distance → brightness. 0칸 = 1, innermost square = DIM_FAR.
	var ring := FOG_FULL_RING
	if depth <= 0:
		ring = 0.0
	elif depth < RING_CUMUL.size():
		ring = float(RING_CUMUL[depth])
	return lerpf(1.0, _dim_far(), clampf(ring / FOG_FULL_RING, 0.0, 1.0))


func _dim_far() -> float:
	return DIM_FAR_MAGIC if magic_light else DIM_FAR


func _center_block_depth() -> int:
	for depth in range(1, MAX_DEPTH + 1):
		if _view_is_solid(depth, 0):
			return depth
	return MAX_DEPTH + 1


func _lateral_order() -> Array[int]:
	## Outer columns first. Which of them actually paint is decided by
	## _mark_visible_cells: a side face can reach the screen even when its
	## cell's near face is far off to the side.
	var order: Array[int] = []
	for i in range(SIDE_REACH, 0, -1):
		order.append(-i)
		order.append(i)
	order.append(0)
	return order


func _is_solid_cell(dmap, cell: Vector2i, z: int) -> bool:
	return _is_blocking_wall(dmap, cell, z) or _is_side_entrance(dmap, cell, z)


func _grid_solid(dmap, pos: Vector2i, cell: Vector2i, z: int) -> bool:
	## The viewer's own cell is always open, even when standing in a doorway.
	return cell != pos and _is_solid_cell(dmap, cell, z)


func _paint_grid_cell(
	buf: Image,
	dmap,
	z: int,
	dir: int,
	depth: int,
	lateral: int,
	w: int,
	h: int,
	anim_frame: int
) -> void:
	var cell := _view_cell(depth, lateral)
	if not _view_is_solid(depth, lateral):
		## Center column fields paint with the other center objects.
		if lateral != 0:
			var field_tid := _cell_field_tile_id(dmap, cell, z)
			if field_tid >= 0:
				_paint_floor_field(
					buf, field_tid, depth, w, h, anim_frame, dir,
					_view_is_solid(depth, lateral - 1),
					_view_is_solid(depth, lateral + 1),
					_view_is_solid(depth + 1, lateral),
					lateral
				)
		return
	var entrance := _is_side_entrance(dmap, cell, z)
	var kind := "door" if entrance else "wall"
	var tex := _tex_entrance(depth) if entrance else _tex_front(depth)
	## Face toward the viewer, on this row's near plane.
	if depth >= 1:
		if not _view_is_solid(depth - 1, lateral):
			var near := _front_rect(depth, w, h)
			var rect := Rect2i(
				near.position.x + lateral * near.size.x,
				near.position.y,
				near.size.x,
				near.size.y
			)
			if rect.position.x < w and rect.end.x > 0:
				_blit_cached_piece(
					buf,
					"face:%d:%d:%s" % [depth, lateral, kind],
					Callable(self, "_blit_rect").bind(tex, rect, _depth_dim(depth))
				)
	## Face toward the center line, spanning this row's near to far plane.
	if lateral == 0:
		return
	if _view_is_solid(depth, lateral - signi(lateral)):
		return
	var left := lateral < 0
	_blit_cached_piece(
		buf,
		"side:%d:%d:%s" % [depth, lateral, kind],
		Callable(self, "_blit_side_trap").bind(
			_tex_entrance(depth) if entrance else _tex_side(depth),
			_lateral_geom(w, h, depth, lateral),
			left,
			_depth_dim(depth),
			_depth_dim(depth + 1)
		)
	)


func _cell_geom(w: int, h: int, depth: int, lateral: int) -> Dictionary:
	## Whole cell box, shifted by whole cell widths on its near and far planes.
	var geom := _depth_geom(w, h, depth)
	if lateral == 0:
		return geom
	var near_shift := lateral * (int(geom["x1"]) - int(geom["x0"]))
	var far_shift := lateral * (int(geom["nx1"]) - int(geom["nx0"]))
	geom["x0"] = int(geom["x0"]) + near_shift
	geom["x1"] = int(geom["x1"]) + near_shift
	geom["nx0"] = int(geom["nx0"]) + far_shift
	geom["nx1"] = int(geom["nx1"]) + far_shift
	return geom


func _shift_rect(rect: Rect2i, lateral: int) -> Rect2i:
	return Rect2i(
		rect.position.x + lateral * rect.size.x, rect.position.y, rect.size.x, rect.size.y
	)


func _row_dim(y: int, h: int) -> float:
	## Floor / ceiling brightness: depth follows the row only.
	var ring := float(mini(y, h - 1 - y)) * RING_DENOM / float(h)
	return lerpf(1.0, _dim_far(), clampf(ring / FOG_FULL_RING, 0.0, 1.0))


func _lateral_geom(w: int, h: int, depth: int, lateral: int) -> Dictionary:
	## Shift the center row's edges outward by whole cell widths on each plane.
	var geom := _depth_geom(w, h, depth)
	var steps := absi(lateral) - 1
	if steps <= 0:
		return geom
	var near_w := int(geom["x1"]) - int(geom["x0"])
	var far_w := int(geom["nx1"]) - int(geom["nx0"])
	if lateral < 0:
		geom["x0"] = int(geom["x0"]) - steps * near_w
		geom["nx0"] = int(geom["nx0"]) - steps * far_w
	else:
		geom["x1"] = int(geom["x1"]) + steps * near_w
		geom["nx1"] = int(geom["nx1"]) + steps * far_w
	return geom


func _paint_peek_wall(buf: Image, dmap, z: int, w: int, h: int) -> void:
	## +5: only whether a wall closes the vanishing square.
	var cell := _view_cell(PEEK_DEPTH, 0)
	if not _is_blocking_wall(dmap, cell, z):
		return
	_blit_cached_piece(
		buf,
		"front_wall:%d" % MAX_DEPTH,
		Callable(self, "_blit_rect").bind(
			_tex_front(MAX_DEPTH), _front_rect(MAX_DEPTH, w, h), _depth_dim(PEEK_DEPTH)
		)
	)


func _ring(size: int, i: int) -> int:
	var idx := clampi(i, 0, RING_CUMUL.size() - 1)
	return int(round(float(size) * float(RING_CUMUL[idx]) / float(RING_DENOM)))


func _depth_geom(w: int, h: int, depth: int) -> Dictionary:
	## Trapezoid from this depth's frame to the next.
	var near := _front_rect(depth, w, h)
	var far := _front_rect(depth + 1, w, h)
	if depth >= MAX_DEPTH:
		far = Rect2i(
			near.position.x + near.size.x / 2,
			near.position.y + near.size.y / 2,
			0,
			0
		)
	return {
		"x0": near.position.x,
		"y0": near.position.y,
		"x1": near.position.x + near.size.x,
		"y1": near.position.y + near.size.y,
		"nx0": far.position.x,
		"ny0": far.position.y,
		"nx1": far.position.x + far.size.x,
		"ny1": far.position.y + far.size.y,
		"w": w,
		"h": h,
		"depth": depth,
	}


func _front_rect(depth: int, w: int, h: int) -> Rect2i:
	var d := clampi(depth, 0, RING_CUMUL.size() - 1)
	var x0 := _ring(w, d)
	var y0 := _ring(h, d)
	return Rect2i(x0, y0, maxi(w - 2 * x0, 1), maxi(h - 2 * y0, 1))


func _ladder_rect(depth: int, w: int, h: int) -> Rect2i:
	## Standing on the ladder: keep it flush with the near plane so Klimb/Descend
	## reads as "here". Farther ladders sit a little into the cell — not on the
	## front depth line, but still forward of true mid-tile (0.5 looked too far).
	if depth <= 0:
		return _front_rect(0, w, h)
	var near := _front_rect(depth, w, h)
	var far := _front_rect(mini(depth + 1, MAX_DEPTH), w, h)
	var t := 0.28
	var x0 := int(round(lerpf(float(near.position.x), float(far.position.x), t)))
	var y0 := int(round(lerpf(float(near.position.y), float(far.position.y), t)))
	var x1 := int(round(lerpf(
		float(near.position.x + near.size.x),
		float(far.position.x + far.size.x),
		t
	)))
	var y1 := int(round(lerpf(
		float(near.position.y + near.size.y),
		float(far.position.y + far.size.y),
		t
	)))
	return Rect2i(x0, y0, maxi(x1 - x0, 1), maxi(y1 - y0, 1))


func _ensure_dim_lut(w: int, h: int) -> void:
	var inner := _ring(mini(w, h), MAX_DEPTH)
	if (
		_dim_lut_w == w
		and _dim_lut_h == h
		and _dim_lut_inner == inner
		and _dim_lut_far == _dim_far()
		and _dim_lut.size() == w * h
	):
		return
	_dim_lut_w = w
	_dim_lut_h = h
	_dim_lut_inner = inner
	_dim_lut_far = _dim_far()
	_dim_lut.resize(w * h)
	var inv := 1.0 / float(maxi(inner, 1))
	for y in range(h):
		var dy := mini(y, h - 1 - y)
		var row := y * w
		for x in range(w):
			var dx := mini(x, w - 1 - x)
			var t := clampf(float(mini(dx, dy)) * inv, 0.0, 1.0)
			_dim_lut[row + x] = lerpf(1.0, _dim_lut_far, t)


func _ensure_piece_cache_size(w: int, h: int) -> void:
	if _piece_cache_w == w and _piece_cache_h == h:
		return
	_piece_cache_w = w
	_piece_cache_h = h
	_piece_cache.clear()
	_anim_piece_cache.clear()
	_clear_floor_bg()


func _blit_cached_piece(
	buf: Image,
	key: String,
	painter: Callable,
	animated: bool = false
) -> void:
	var cache := _anim_piece_cache if animated else _piece_cache
	var cache_key := "%d:%s:%d:%d:%s" % [
		PIECE_CACHE_REV, theme_id, _theme_pipeline, int(magic_light), key
	]
	if not cache.has(cache_key):
		if animated and cache.size() >= ANIM_PIECE_CACHE_MAX:
			cache.clear()
		var canvas := Image.create(
			_piece_cache_w, _piece_cache_h, false, Image.FORMAT_RGBA8
		)
		canvas.fill(Color(0, 0, 0, 0))
		painter.call(canvas)
		var used := canvas.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			cache[cache_key] = {}
		else:
			cache[cache_key] = {
				"image": canvas.get_region(used),
				"position": used.position,
			}
	var piece: Dictionary = cache[cache_key]
	if piece.is_empty():
		return
	var image: Image = piece["image"]
	buf.blend_rect(
		image,
		Rect2i(Vector2i.ZERO, image.get_size()),
		Vector2i(piece["position"])
	)


func _tex_front(_depth: int = 0) -> Image:
	return _wall


func _tex_side(_depth: int = 0) -> Image:
	return _wall


func _tex_entrance(_depth: int = 0) -> Image:
	return _entrance


func _clear_floor_bg() -> void:
	_floor_bg = null
	_floor_bg_w = 0
	_floor_bg_h = 0
	_floor_bg_pipeline = -1
	_floor_bg_inner = -1
	_floor_bg_far = -1.0


func _paint_floor_plane_background(buf: Image) -> bool:
	## Fog + scanlines are baked once at field size. Per-frame get/set_pixel
	## over the whole pane is what tanked Apple II dungeon after ceiling lines.
	var w := buf.get_width()
	var h := buf.get_height()
	if (
		_floor_bg == null
		or _floor_bg_w != w
		or _floor_bg_h != h
		or _floor_bg_pipeline != _theme_pipeline
		or _floor_bg_inner != _dim_lut_inner
		or _floor_bg_far != _dim_far()
	):
		if _floor_plane == null:
			return false
		_floor_bg = Image.create(w, h, false, Image.FORMAT_RGBA8)
		_blit_scaled(
			_floor_bg,
			_floor_plane,
			0, 0, w, h, 1.0,
			false, 0.0, 1.0, false, false, false, _scanlines_on
		)
		## Floor and ceiling depth depends only on the row, including side branches.
		for y in range(h):
			var d := _row_dim(y, h)
			for x in range(w):
				var c := _floor_bg.get_pixel(x, y)
				_floor_bg.set_pixel(x, y, Color(c.r * d, c.g * d, c.b * d, 1.0))
		_floor_bg_w = w
		_floor_bg_h = h
		_floor_bg_pipeline = _theme_pipeline
		_floor_bg_inner = _dim_lut_inner
		_floor_bg_far = _dim_far()
	buf.blit_rect(_floor_bg, Rect2i(0, 0, w, h), Vector2i.ZERO)
	return true


func _blit_side_trap(
	buf: Image,
	src: Image,
	geom: Dictionary,
	left: bool,
	dim_near: float,
	dim_far: float
) -> void:
	## Trapezoid silhouette; bricks stay upright (column-wise), only top/bottom edges slope.
	if src == null:
		return
	var x_near := int(geom["x0"] if left else geom["x1"])
	var x_far := int(geom["nx0"] if left else geom["nx1"])
	var y0n := int(geom["y0"])
	var y1n := int(geom["y1"])
	var y0f := int(geom["ny0"])
	var y1f := int(geom["ny1"])
	var x_a := mini(x_near, x_far)
	var x_b := maxi(x_near, x_far)
	if x_b <= x_a:
		return
	var sw := src.get_width()
	var sh := src.get_height()
	var bw := buf.get_width()
	var bh := buf.get_height()
	var x_span := float(x_far - x_near)
	if absf(x_span) < 0.5:
		return
	for x in range(maxi(x_a, 0), mini(x_b, bw)):
		var from_near := clampf(float(x - x_near) / x_span, 0.0, 1.0)
		var y0 := int(lerpf(float(y0n), float(y0f), from_near))
		var y1 := int(lerpf(float(y1n), float(y1f), from_near))
		if y1 <= y0:
			continue
		var u := (1.0 - from_near) if left else from_near
		var sx := clampi(int(u * float(sw - 1)), 0, sw - 1)
		for y in range(y0, y1):
			if y < 0 or y >= bh:
				continue
			var sy := clampi(int(float(y - y0) / float(y1 - y0) * float(sh - 1)), 0, sh - 1)
			var c := src.get_pixel(sx, sy)
			var d := lerpf(dim_near, dim_far, from_near)
			buf.set_pixel(x, y, _scanline_rgb(c.r * d, c.g * d, c.b * d, y))


func _scanline_rgb(r: float, g: float, b: float, y: int) -> Color:
	if not _scanlines_on or (y & 1) == 0:
		return Color(r, g, b, 1.0)
	## Same half-scanline as Apple II Color / Mono: (v & 0xFC) >> 2.
	return Color(
		float((int(r * 255.0) & 0xFC) >> 2) / 255.0,
		float((int(g * 255.0) & 0xFC) >> 2) / 255.0,
		float((int(b * 255.0) & 0xFC) >> 2) / 255.0,
		1.0
	)


func _lut_at(x: int, y: int, w: int, h: int) -> float:
	if _dim_lut.is_empty():
		return 1.0
	var px := clampi(x, 0, w - 1)
	var py := clampi(y, 0, h - 1)
	return _dim_lut[py * w + px]


func _blit_rect(buf: Image, src: Image, r: Rect2i, dim: float, flip_h: bool = false) -> void:
	## Facing wall: one brightness for the whole face, from its cell distance.
	if src == null or r.size.x <= 0 or r.size.y <= 0:
		return
	_blit_scaled(
		buf, src,
		r.position.x, r.position.y,
		r.position.x + r.size.x, r.position.y + r.size.y,
		dim,
		flip_h, 0.0, 1.0, false, false, false, _scanlines_on
	)


func _blit_scaled(
	buf: Image,
	src: Image,
	x0: int,
	y0: int,
	x1: int,
	y1: int,
	dim: float,
	flip_h: bool = false,
	src_u0: float = 0.0,
	src_u1: float = 1.0,
	wrap_u: bool = false,
	apply_fog: bool = true,
	flip_v: bool = false,
	scanlines: bool = false
) -> void:
	if src == null:
		return
	var dw := x1 - x0
	var dh := y1 - y0
	if dw <= 0 or dh <= 0:
		return
	var sw := src.get_width()
	var sh := src.get_height()
	if sw <= 0 or sh <= 0:
		return
	var bw := buf.get_width()
	var bh := buf.get_height()
	var u_span := src_u1 - src_u0
	for y in range(y0, y1):
		if y < 0 or y >= bh:
			continue
		var sy := clampi(int(float(y - y0) / float(dh) * float(sh)), 0, sh - 1)
		if flip_v:
			sy = sh - 1 - sy
		var row := y * bw
		for x in range(x0, x1):
			if x < 0 or x >= bw:
				continue
			var t := float(x - x0) / float(dw)
			if flip_h:
				t = 1.0 - t
			var u := src_u0 + t * u_span
			var sx: int
			if wrap_u:
				sx = posmod(int(floor(u * float(sw))), sw)
			else:
				sx = clampi(int(u * float(sw)), 0, sw - 1)
			var c := src.get_pixel(sx, sy)
			if c.a < 0.05:
				continue
			var d := dim
			if apply_fog:
				d *= _dim_lut[row + x]
			if scanlines and (y & 1) == 1:
				buf.set_pixel(x, y, _scanline_rgb(c.r * d, c.g * d, c.b * d, y))
			else:
				buf.set_pixel(x, y, Color(c.r * d, c.g * d, c.b * d, 1.0))


func _paint_ladder_piece(
	buf: Image,
	fr: Rect2i,
	dim: float,
	mode: int
) -> void:
	if _ladder_half == null:
		return
	var x0 := fr.position.x
	var y0 := fr.position.y
	var x1 := x0 + fr.size.x
	var y1 := y0 + fr.size.y
	var opening_w := maxi(1, int(round(float(fr.size.x) * 0.50)))
	var opening_h := maxi(1, int(round(float(fr.size.y) * 0.12)))
	var opening_far_w := maxi(1, int(round(float(opening_w) * 0.70)))
	var opening_center_x := float(x0) + float(fr.size.x) * 0.5
	var ladder_light := dim * _lut_at(x0, y0, buf.get_width(), buf.get_height())
	if mode & LADDER_UP:
		var light := dim * _lut_at(x0 + fr.size.x / 2, y0, buf.get_width(), buf.get_height())
		_paint_framed_ladder_opening(
			buf,
			opening_center_x, y0, y0 + opening_h,
			opening_w, opening_far_w, fr.size.x, light
		)
	if mode & LADDER_DOWN:
		var light := dim * _lut_at(x0 + fr.size.x / 2, y1 - 1, buf.get_width(), buf.get_height())
		_paint_framed_ladder_opening(
			buf,
			opening_center_x, y1, y1 - opening_h,
			opening_w, opening_far_w, fr.size.x, light
		)
	if mode & LADDER_UP:
		_blit_scaled(
			buf, _ladder_half,
			x0, y0, x1, y1,
			ladder_light, false, 0.0, 1.0, false, false, false
		)
	if mode & LADDER_DOWN:
		_blit_scaled(
			buf, _ladder_half,
			x0, y0, x1, y1,
			ladder_light, false, 0.0, 1.0, false, false, true
		)


func _paint_framed_ladder_opening(
	buf: Image,
	center_x: float,
	y_near: int,
	y_far: int,
	near_w: int,
	far_w: int,
	cell_w: int,
	light: float
) -> void:
	var rim := maxi(1, int(round(float(cell_w) * 0.012)))
	var direction := 1 if y_far > y_near else -1
	var height := absi(y_far - y_near)
	var outer_near_w := near_w + rim * 2
	var outer_far_w := far_w + rim * 2
	_fill_centered_solid_quad(
		buf, center_x, y_near, y_far,
		outer_near_w, outer_far_w,
		Color(0.02, 0.02, 0.02, 1)
	)
	if height <= rim * 2:
		return
	var inset_t := float(rim) / float(height)
	var silver_near_w := maxi(
		1, int(round(lerpf(float(outer_near_w), float(outer_far_w), inset_t))) - rim * 2
	)
	var silver_far_w := maxi(
		1, int(round(lerpf(float(outer_near_w), float(outer_far_w), 1.0 - inset_t))) - rim * 2
	)
	var silver := clampf(0.82 * light, 0.0, 1.0)
	_fill_centered_solid_quad(
		buf, center_x, y_near + direction * rim, y_far - direction * rim,
		silver_near_w, silver_far_w,
		Color(silver, silver, silver, 1)
	)
	var silver_height := height - rim * 2
	if silver_height > rim * 2:
		var inner_t := float(rim) / float(silver_height)
		var inner_near_w := maxi(
			1, int(round(lerpf(float(silver_near_w), float(silver_far_w), inner_t))) - rim * 2
		)
		var inner_far_w := maxi(
			1, int(round(lerpf(float(silver_near_w), float(silver_far_w), 1.0 - inner_t))) - rim * 2
		)
		_fill_centered_solid_quad(
			buf, center_x, y_near + direction * rim * 2, y_far - direction * rim * 2,
			inner_near_w, inner_far_w,
			Color(0, 0, 0, 1)
		)


func _fill_centered_solid_quad(
	buf: Image,
	center_x: float,
	y_near: int,
	y_far: int,
	near_w: int,
	far_w: int,
	color: Color
) -> void:
	_fill_solid_hband_quad(
		buf,
		float(center_x) - float(near_w) * 0.5,
		float(center_x) + float(near_w) * 0.5,
		y_near,
		float(center_x) - float(far_w) * 0.5,
		float(center_x) + float(far_w) * 0.5,
		y_far,
		color
	)


func _fill_solid_hband_quad(
	buf: Image,
	x0: float,
	x1: float,
	y_near: int,
	nx0: float,
	nx1: float,
	y_far: int,
	color: Color
) -> void:
	var y_a := mini(y_near, y_far)
	var y_b := maxi(y_near, y_far)
	var y_span := float(y_far - y_near)
	if y_b <= y_a or absf(y_span) < 0.5:
		return
	for y in range(y_a, y_b):
		if y < 0 or y >= buf.get_height():
			continue
		var t := clampf((float(y) + 0.5 - float(y_near)) / y_span, 0.0, 1.0)
		var xl := clampi(int(round(lerpf(x0, nx0, t))), 0, buf.get_width())
		var xr := clampi(int(round(lerpf(x1, nx1, t))), 0, buf.get_width())
		if xr > xl:
			buf.fill_rect(Rect2i(xl, y, xr - xl, 1), color)


func _ladder_mode(tok: int) -> int:
	match tok:
		_DungeonMap.TOK_LADDER_UP, _DungeonMap.TOK_CEILING_HOLE:
			return LADDER_UP
		_DungeonMap.TOK_LADDER_DOWN, _DungeonMap.TOK_FLOOR_HOLE:
			return LADDER_DOWN
		_DungeonMap.TOK_LADDER_BOTH:
			return LADDER_UP | LADDER_DOWN
	return 0


func _paint_ladder_object(
	buf: Image,
	mode: int,
	depth: int,
	field_w: int,
	field_h: int,
	dim: float
) -> void:
	if mode == 0:
		return
	var fr := _ladder_rect(depth, field_w, field_h)
	_blit_cached_piece(
		buf,
		"ladder:t28:%d:%d" % [mode, depth],
		Callable(self, "_paint_ladder_piece").bind(fr, dim, mode)
	)


func _cell_object_tile_id(
	dmap,
	cell: Vector2i,
	z: int,
	tok: int
) -> int:
	var tid := -1
	match tok:
		_DungeonMap.TOK_CHEST:
			if not dmap.is_consumed(cell.x, cell.y, z):
				tid = TILE_CHEST
		_DungeonMap.TOK_ALTAR:
			tid = TILE_ALTAR
		_DungeonMap.TOK_ORB:
			if not dmap.is_consumed(cell.x, cell.y, z):
				tid = TILE_ORB
		_DungeonMap.TOK_FOUNTAIN:
			tid = TILE_FOUNTAIN
		_DungeonMap.TOK_FIELD:
			tid = dmap.field_world_tile(cell.x, cell.y, z)
	return tid


func _cell_field_tile_id(dmap, cell: Vector2i, z: int) -> int:
	if dmap.token_at(cell.x, cell.y, z) != _DungeonMap.TOK_FIELD:
		return -1
	return int(dmap.field_world_tile(cell.x, cell.y, z))


func _paint_floor_field(
	buf: Image,
	tid: int,
	depth: int,
	field_w: int,
	field_h: int,
	anim_frame: int,
	view_dir: int,
	left_surface: bool,
	right_surface: bool,
	front_surface: bool,
	lateral: int = 0
) -> void:
	var img: Image = _U4TileBank.image(tid)
	if img == null or img.get_width() <= 0 or img.get_height() <= 0:
		return
	_last_animated = true
	var scroll := posmod(anim_frame * 2, img.get_height())
	view_dir = posmod(view_dir, 4)
	_blit_cached_piece(
		buf,
		"field:%d:%d:%d:%d:%d%d%d:%d" % [
			tid, depth, lateral, view_dir,
			int(left_surface), int(right_surface), int(front_surface), scroll,
		],
		Callable(self, "_rasterize_floor_field").bind(
			img, tid, depth, field_w, field_h, scroll, view_dir,
			left_surface, right_surface, front_surface, lateral
		),
		true
	)


func _rasterize_floor_field(
	buf: Image,
	img: Image,
	tid: int,
	depth: int,
	field_w: int,
	field_h: int,
	scroll: int,
	view_dir: int,
	left_surface: bool,
	right_surface: bool,
	front_surface: bool,
	lateral: int
) -> void:
	var geom := _cell_geom(field_w, field_h, depth, lateral)
	var walls_only := tid == TILE_FIELD_ENERGY
	## Off-center cells only show the wall on the far side from the center line.
	var show_left := lateral <= 0
	var show_right := lateral >= 0
	if walls_only or front_surface:
		## Energy always has a far wall. Other fields project onto a blocking
		## wall / entrance at this corridor cell's far boundary.
		_paint_field_front_mask(
			buf, img,
			_shift_rect(_front_rect(depth + 1, field_w, field_h), lateral),
			_depth_dim(depth + 1), scroll
		)
	if not walls_only:
		_paint_field_hband_mask(
			buf, img,
			float(geom["x0"]), float(geom["x1"]), int(geom["y0"]),
			float(geom["nx0"]), float(geom["nx1"]), int(geom["ny0"]),
			1.0, scroll, view_dir
		)
	if show_left and (walls_only or left_surface):
		_paint_field_side_mask(buf, img, geom, true, 1.0, scroll)
	if show_right and (walls_only or right_surface):
		_paint_field_side_mask(buf, img, geom, false, 1.0, scroll)
	if not walls_only:
		_paint_field_hband_mask(
			buf, img,
			float(geom["x0"]), float(geom["x1"]), int(geom["y1"]),
			float(geom["nx0"]), float(geom["nx1"]), int(geom["ny1"]),
			1.0, scroll, view_dir
		)
	if walls_only and (depth >= 1 or lateral == 0):
		_paint_field_front_mask(
			buf, img,
			_shift_rect(_front_rect(depth, field_w, field_h), lateral),
			_depth_dim(depth), scroll
		)


func _paint_field_hband_mask(
	buf: Image,
	img: Image,
	x0: float,
	x1: float,
	y_near: int,
	nx0: float,
	nx1: float,
	y_far: int,
	dim: float,
	scroll: int,
	view_dir: int,
	clip_x0: int = -0x3fffffff,
	clip_x1: int = 0x3fffffff
) -> void:
	var y_a := mini(y_near, y_far)
	var y_b := maxi(y_near, y_far)
	var y_span := float(y_far - y_near)
	if y_b <= y_a or absf(y_span) < 0.5:
		return
	var sw := img.get_width()
	var sh := img.get_height()
	var field_w := buf.get_width()
	var field_h := buf.get_height()
	for y in range(y_a, y_b):
		if y < 0 or y >= field_h:
			continue
		var t := clampf((float(y) + 0.5 - float(y_near)) / y_span, 0.0, 1.0)
		var xl := int(round(lerpf(x0, nx0, t)))
		var xr := int(round(lerpf(x1, nx1, t)))
		if xr <= xl:
			continue
		var span := float(xr - xl)
		for x in range(maxi(xl, clip_x0), mini(xr, clip_x1)):
			if x < 0 or x >= field_w:
				continue
			var u := (float(x - xl) + 0.5) / span
			var near_factor := 1.0 - t
			var world_uv := _field_world_uv(u, near_factor, view_dir)
			var sx := clampi(int(floor(world_uv.x * float(sw))), 0, sw - 1)
			## Positive sampling offset makes the projected pattern travel
			## bottom → top, matching the 2D field tiles.
			var sy := posmod(
				int(floor(world_uv.y * float(sh))) + scroll,
				sh
			)
			var color := img.get_pixel(sx, sy)
			## Original field tiles use black as their transparent backing.
			if color.a <= 0.01 or maxf(color.r, maxf(color.g, color.b)) <= 0.08:
				continue
			var light := dim * _row_dim(y, field_h)
			buf.set_pixel(
				x, y,
				Color(color.r * light, color.g * light, color.b * light, color.a)
			)


func _field_world_uv(screen_u: float, near_factor: float, view_dir: int) -> Vector2:
	## Source U is west → east; source V is north → south.
	match posmod(view_dir, 4):
		_DungeonMap.DIR_N:
			return Vector2(screen_u, near_factor)
		_DungeonMap.DIR_E:
			return Vector2(1.0 - near_factor, screen_u)
		_DungeonMap.DIR_S:
			return Vector2(1.0 - screen_u, 1.0 - near_factor)
		_:
			return Vector2(near_factor, 1.0 - screen_u)


func _paint_field_side_mask(
	buf: Image,
	img: Image,
	geom: Dictionary,
	left: bool,
	dim: float,
	scroll: int
) -> void:
	var x_near := int(geom["x0"] if left else geom["x1"])
	var x_far := int(geom["nx0"] if left else geom["nx1"])
	var x_a := mini(x_near, x_far)
	var x_b := maxi(x_near, x_far)
	var x_span := float(x_far - x_near)
	if x_b <= x_a or absf(x_span) < 0.5:
		return
	var y0n := int(geom["y0"])
	var y1n := int(geom["y1"])
	var y0f := int(geom["ny0"])
	var y1f := int(geom["ny1"])
	var sw := img.get_width()
	var sh := img.get_height()
	var field_w := buf.get_width()
	var field_h := buf.get_height()
	var depth := int(geom["depth"])
	var dim_near := _depth_dim(depth)
	var dim_far := _depth_dim(depth + 1)
	for x in range(maxi(x_a, 0), mini(x_b, field_w)):
		var from_near := clampf(float(x - x_near) / x_span, 0.0, 1.0)
		var y0 := int(round(lerpf(float(y0n), float(y0f), from_near)))
		var y1 := int(round(lerpf(float(y1n), float(y1f), from_near)))
		if y1 <= y0:
			continue
		var wall_light := dim * lerpf(dim_near, dim_far, from_near)
		## Both walls keep the same screen-left → screen-right orientation.
		var u := (float(x - x_a) + 0.5) / float(x_b - x_a)
		var sx := clampi(int(floor(u * float(sw))), 0, sw - 1)
		var wall_h := float(y1 - y0)
		for y in range(y0, y1):
			if y < 0 or y >= field_h:
				continue
			var v := (float(y - y0) + 0.5) / wall_h
			## Match 2D fields: the mask travels from screen bottom to top.
			var sy := posmod(int(floor(v * float(sh))) + scroll, sh)
			var color := img.get_pixel(sx, sy)
			if color.a <= 0.01 or maxf(color.r, maxf(color.g, color.b)) <= 0.08:
				continue
			buf.set_pixel(
				x, y,
				Color(color.r * wall_light, color.g * wall_light, color.b * wall_light, color.a)
			)


func _paint_field_front_mask(
	buf: Image,
	img: Image,
	rect: Rect2i,
	dim: float,
	scroll: int
) -> void:
	var sw := img.get_width()
	var sh := img.get_height()
	var field_w := buf.get_width()
	var field_h := buf.get_height()
	if sw <= 0 or sh <= 0 or rect.size.x <= 0 or rect.size.y <= 0:
		return
	for y in range(rect.position.y, rect.end.y):
		if y < 0 or y >= field_h:
			continue
		var v := (float(y - rect.position.y) + 0.5) / float(rect.size.y)
		## Match side walls and 2D fields: screen bottom to top.
		var sy := posmod(int(floor(v * float(sh))) + scroll, sh)
		for x in range(rect.position.x, rect.end.x):
			if x < 0 or x >= field_w:
				continue
			var u := (float(x - rect.position.x) + 0.5) / float(rect.size.x)
			var sx := clampi(int(floor(u * float(sw))), 0, sw - 1)
			var color := img.get_pixel(sx, sy)
			if color.a <= 0.01 or maxf(color.r, maxf(color.g, color.b)) <= 0.08:
				continue
			buf.set_pixel(
				x, y,
				Color(color.r * dim, color.g * dim, color.b * dim, color.a)
			)


func falling_rock_sprite() -> Image:
	## Dedicated combat/trap rock art — black plate keyed out, then trimmed
	## so the stone pixels sit on the bottom of the draw box (true floor contact).
	var src := _ResImage.load_rgba8("res://assets/ui/combat/thrown_rocks.png")
	if src == null:
		return null
	var tw := src.get_width()
	var th := src.get_height()
	var img := Image.create(tw, th, false, Image.FORMAT_RGBA8)
	img.blit_rect(src, Rect2i(0, 0, tw, th), Vector2i.ZERO)
	for y in th:
		for x in tw:
			var c := img.get_pixel(x, y)
			if c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var used := img.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		img = img.get_region(used)
	return img


func falling_rock_layout(field_w: int, field_h: int) -> Dictionary:
	## Triangle pile: two rocks on the true floor, one stacked above them in Y.
	var nscale: int = OBJ_NSCALE[0]
	var span := maxi(
		8,
		int(round(
			float(nscale) / 12.0
			* float(field_w)
			* OBJ_VIEW_RATIO
			* FALLING_ROCK_CHUNK_SCALE
		))
	)
	var fr := _front_rect(0, field_w, field_h)
	var mid_x := fr.position.x + fr.size.x / 2
	## Base rocks land on the bottom edge of the dungeon field.
	var floor_y := field_h
	## Start near the ceiling so the drop to the floor reads clearly.
	var start_y := clampi(span, span, maxi(span, floor_y - 8))
	var gap := maxi(
		6,
		int(round(float(span) * randf_range(FALLING_ROCK_BASE_GAP_MIN, FALLING_ROCK_BASE_GAP_MAX)))
	)
	## Slight random lean so the pile is not perfectly centered every time.
	var bias := int(round(float(span) * randf_range(-0.06, 0.06)))
	var left_x := mid_x - gap + bias
	var right_x := mid_x + gap + bias
	var base_a := {"mid_x": left_x, "end_y": floor_y}
	var base_b := {"mid_x": right_x, "end_y": floor_y}
	var bases: Array = [base_a, base_b]
	if randf() < 0.5:
		bases = [base_b, base_a]
	## Apex bottom Y is above the base tops so it reads as stacked, not coplanar.
	var stack_lift := maxi(
		maxi(8, span * 2 / 5),
		int(round(float(span) * randf_range(FALLING_ROCK_STACK_LIFT_MIN, FALLING_ROCK_STACK_LIFT_MAX)))
	)
	var stack_y := mini(floor_y - stack_lift, floor_y - maxi(8, span * 2 / 5))
	var apex_x := mid_x + bias
	return {
		"span": span,
		"start_y": start_y,
		"start_x": mid_x + bias,
		## Fall order: one base, other base, then apex (always last / on top).
		"slots": [
			bases[0],
			bases[1],
			{"mid_x": apex_x, "end_y": stack_y, "on_top": true},
		],
	}


func paint_falling_rock(
	buf: Image,
	img: Image,
	mid_x: int,
	bottom_y: int,
	span: int
) -> void:
	if buf == null or img == null or span <= 0:
		return
	## Allow the box bottom on the last field row so rocks sit on the true floor.
	var y1 := clampi(bottom_y, 1, buf.get_height())
	var y0 := y1 - span
	_blit_scaled(
		buf, img,
		mid_x - span / 2, y0, mid_x + span / 2, y1,
		1.0, false, 0.0, 1.0, false, false
	)


func paint_falling_rock_pieces(buf: Image, pieces: Array) -> void:
	## Draw floor rocks first, then any on-top chunk so the apex stays visible.
	var top_piece: Dictionary = {}
	for piece in pieces:
		if typeof(piece) != TYPE_DICTIONARY:
			continue
		if bool(piece.get("on_top", false)):
			top_piece = piece
			continue
		var img: Image = piece.get("img", null) as Image
		paint_falling_rock(
			buf,
			img,
			int(piece.get("mid_x", 0)),
			int(round(float(piece.get("y", 0.0)))),
			int(piece.get("span", 0))
		)
	if not top_piece.is_empty():
		var top_img: Image = top_piece.get("img", null) as Image
		paint_falling_rock(
			buf,
			top_img,
			int(top_piece.get("mid_x", 0)),
			int(round(float(top_piece.get("y", 0.0)))),
			int(top_piece.get("span", 0))
		)


func _paint_tile_object(
	buf: Image,
	tid: int,
	depth: int,
	field_w: int,
	field_h: int,
	anim_frame: int,
	dungeon_id: String = "",
	cell: Vector2i = Vector2i(-1, -1),
	z: int = 0
) -> void:
	if tid < 0:
		return
	var is_monster := tid >= TILE_MONSTER_FIRST and tid <= TILE_MONSTER_LAST
	var paint_tid := tid
	var piece_key := "tile:%d:%d" % [tid, depth]
	if is_monster:
		## Same consecutive-tile cycle as wilderness / combat (rat 144–147, …).
		paint_tid = _WorldCreatures.resolve_paint_tile(tid, anim_frame)
		piece_key = "monster:%d:%d" % [paint_tid, depth]
	var img: Image
	if tid == TILE_FOUNTAIN and not _fountain_frames.is_empty():
		var frame := posmod(anim_frame, _fountain_frames.size())
		img = _fountain_frames[frame]
		piece_key = "fountain:%d:%d" % [frame, depth]
	elif tid == TILE_ORB or tid == TILE_ALTAR or is_monster:
		## Orb / altar / monster PNGs keep an opaque black plate; key it out.
		## Apple II Color orb needs the NTSC right-fringe (34px), not the 32px cut.
		if _keyed_monster_cache.has(paint_tid):
			img = _keyed_monster_cache[paint_tid] as Image
		else:
			if tid == TILE_ORB:
				img = _U4TileBank.isolated_overlay(paint_tid)
			else:
				img = _U4TileBank.keyed_copy(paint_tid)
			_keyed_monster_cache[paint_tid] = img
	else:
		img = _U4TileBank.image(paint_tid)
	if img == null:
		return
	var nscale: int = OBJ_NSCALE[clampi(depth, 0, OBJ_NSCALE.size() - 1)]
	var object_scale := 1.0
	if tid == TILE_CHEST:
		object_scale = CHEST_VIEW_SCALE
	elif tid == TILE_FOUNTAIN:
		object_scale = FOUNTAIN_VIEW_SCALE
	elif tid == TILE_ALTAR:
		object_scale = ALTAR_VIEW_SCALE
	elif tid == TILE_ORB:
		object_scale = ORB_VIEW_SCALE
	elif tid >= TILE_MONSTER_FIRST and tid <= TILE_MONSTER_LAST:
		object_scale = MONSTER_VIEW_SCALE
	var span := maxi(
		6,
		int(round(
			float(nscale) / 12.0
			* float(field_w)
			* OBJ_VIEW_RATIO
			* object_scale
		))
	)
	var fr := _front_rect(depth, field_w, field_h)
	var far_fr := _front_rect(depth + 1, field_w, field_h)
	var mid_x := fr.position.x + fr.size.x / 2
	var near_floor_y := fr.position.y + fr.size.y
	var far_floor_y := far_fr.position.y + far_fr.size.y
	var floor_position := 0.0 if depth == 0 else OBJ_FLOOR_POSITION
	var obj_y1 := clampi(
		int(round(lerpf(
			float(near_floor_y), float(far_floor_y), floor_position
		))),
		1,
		field_h - 1
	)
	var obj_y0 := obj_y1 - span
	var object_light := _lut_at(
		fr.position.x, fr.position.y, buf.get_width(), buf.get_height()
	)
	var animated := is_monster or tid == TILE_FOUNTAIN
	if animated:
		_last_animated = true
	## Tile icons already carry transparent alpha; _blit_scaled skips those pixels.
	_blit_cached_piece(
		buf,
		piece_key,
		Callable(self, "_blit_scaled").bind(
			img, mid_x - span / 2, obj_y0, mid_x + span / 2, obj_y1,
			object_light, false, 0.0, 1.0, false, false
		),
		animated
	)
	if tid == TILE_ALTAR:
		_paint_unclaimed_altar_stone(
			buf, dungeon_id, cell, z, depth, mid_x, obj_y0, span, object_light
		)


func _paint_unclaimed_altar_stone(
	buf: Image,
	dungeon_id: String,
	cell: Vector2i,
	z: int,
	depth: int,
	altar_mid_x: int,
	altar_y0: int,
	altar_span: int,
	light: float
) -> void:
	## Search-on-altar stones remain visible until the party has found them.
	if dungeon_id.is_empty() or cell.x < 0 or cell.y < 0:
		return
	var flag := _DungeonPortals.stone_at(dungeon_id, cell, z)
	if flag == 0 or GameState.has_stone(flag):
		return
	var bit := -1
	for i in 8:
		if flag == (1 << i):
			bit = i
			break
	if bit < 0:
		return
	var stone := _keyed_stone_image(bit)
	if stone == null or stone.is_empty():
		return
	var stone_span := maxi(4, int(round(float(altar_span) * ALTAR_STONE_VIEW_SCALE)))
	var stone_y1 := clampi(
		altar_y0 + int(round(float(altar_span) * ALTAR_STONE_TOP_T)),
		stone_span,
		buf.get_height()
	)
	var stone_y0 := stone_y1 - stone_span
	_blit_cached_piece(
		buf,
		"stone:%d:%d" % [bit, depth],
		Callable(self, "_blit_scaled").bind(
			stone,
			altar_mid_x - stone_span / 2, stone_y0,
			altar_mid_x + stone_span / 2, stone_y1,
			light, false, 0.0, 1.0, false, false
		)
	)


func _keyed_stone_image(bit_index: int) -> Image:
	if _keyed_stone_cache.has(bit_index):
		return _keyed_stone_cache[bit_index] as Image
	var path := _SpecialItemIcons.stone_path(bit_index)
	if path.is_empty():
		return null
	var src := _ResImage.load_rgba8(path)
	if src == null or src.is_empty():
		return null
	var tw := src.get_width()
	var th := src.get_height()
	var img := Image.create(tw, th, false, Image.FORMAT_RGBA8)
	img.blit_rect(src, Rect2i(0, 0, tw, th), Vector2i.ZERO)
	for y in th:
		for x in tw:
			var c := img.get_pixel(x, y)
			if c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var used := img.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		img = img.get_region(used)
	_keyed_stone_cache[bit_index] = img
	return img


func _load_png(path: String) -> Image:
	var img := _ResImage.load_rgba8(path)
	## Apple II Color / Mono: grayscale. Green: grayscale then phosphor LUT.
	_U4TileBank.apply_apple2_hud_palette(img)
	return img
