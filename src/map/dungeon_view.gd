class_name DungeonView
extends RefCounted

## First-person corridor: 9 rings 3:3:2.5:2:2:2:2.5:3:3 (23 units).
## Draw current + 4 cells ahead. Cell +5 is wall/not-wall only.

const _DungeonMap := preload("res://src/map/dungeon_map_data.gd")
const _U4TileBank := preload("res://src/map/u4_tile_bank.gd")

const ASSET_ROOT := "res://assets/dungeon"
const MAX_DEPTH := 4
const PEEK_DEPTH := 5
const RING_CUMUL: Array[float] = [0.0, 3.0, 6.0, 8.5, 10.5, 12.5]
const RING_DENOM := 23.0
const OBJ_NSCALE: Array[int] = [12, 8, 5, 3, 1]
const OBJ_VIEW_RATIO := 0.28
const CHEST_VIEW_SCALE := 2.0
const FOUNTAIN_VIEW_SCALE := 2.0
const OBJ_FLOOR_POSITION := 0.5
## Increment when cached rasterization rules change during a hot reload.
const PIECE_CACHE_REV := 23
## Brightness at the innermost square (five cells ahead).
const DIM_FAR := 0.05
const TILE_CHEST := 60
const TILE_ALTAR := 74
const TILE_ORB := 78
const TILE_FOUNTAIN := 75
const LADDER_UP := 1
const LADDER_DOWN := 2
const VIEW_OBJECT_TILE := 0
const VIEW_OBJECT_LADDER := 1

var theme_id: String = "grey_stone"
var _wall: Image
var _floor: Image
var _entrance: Image
var _ladder_half: Image
var _fountain_frames: Array[Image] = []
var _theme_loaded := ""
var _dim_lut: PackedFloat32Array = PackedFloat32Array()
var _dim_lut_w := 0
var _dim_lut_h := 0
var _dim_lut_inner := -1
var _piece_cache: Dictionary = {}
var _piece_cache_w := 0
var _piece_cache_h := 0


func set_theme(id: String) -> void:
	if _ladder_half == null:
		_ladder_half = _load_png("%s/ladder_half.png" % ASSET_ROOT)
	if _fountain_frames.is_empty():
		_fountain_frames = [
			_load_png("%s/fountain_0.png" % ASSET_ROOT),
			_load_png("%s/fountain_1.png" % ASSET_ROOT),
		]
	if id == _theme_loaded and _wall != null:
		theme_id = id
		return
	theme_id = id
	_theme_loaded = id
	_piece_cache.clear()
	## One tile per kind — crop/scale by depth instead of swapping patterns.
	_wall = _load_png("%s/%s/wall.png" % [ASSET_ROOT, id])
	_floor = _load_png("%s/%s/floor.png" % [ASSET_ROOT, id])
	_entrance = _load_png("%s/%s/room_entrance.png" % [ASSET_ROOT, id])


func paint(
	buf: Image,
	dmap,
	pos: Vector2i,
	z: int,
	dir: int,
	lit: bool,
	anim_frame: int = 0
) -> void:
	if buf == null or dmap == null or not dmap.loaded:
		return
	var w := buf.get_width()
	var h := buf.get_height()
	if w < 8 or h < 8:
		return
	if not lit:
		buf.fill(Color(0, 0, 0, 1))
		return
	if _wall == null:
		set_theme(theme_id)
	_ensure_dim_lut(w, h)
	_ensure_piece_cache_size(w, h)
	buf.fill(Color(0, 0, 0, 1))
	var reached_far := true
	var view_objects: Array[Dictionary] = []
	for depth in range(0, MAX_DEPTH + 1):
		var cell := _ahead(dmap, pos, dir, depth)
		var left := _left_of(dmap, cell, dir)
		var right := _right_of(dmap, cell, dir)
		var dim := 1.0
		var tok: int = dmap.token_at(cell.x, cell.y, z)
		var geom := _depth_geom(w, h, depth)
		if _is_blocking_wall(dmap, cell, z):
			_blit_cached_piece(
				buf,
				"front_wall:%d" % depth,
				Callable(self, "_blit_rect").bind(
					_tex_front(depth), _front_rect(depth, w, h), dim
				)
			)
			reached_far = false
			break
		if tok == _DungeonMap.TOK_ROOM or tok == _DungeonMap.TOK_DOOR:
			_blit_cached_piece(
				buf,
				"front_entrance:%d" % depth,
				Callable(self, "_blit_rect").bind(
					_tex_entrance(depth), _front_rect(depth, w, h), dim
				)
			)
			reached_far = false
			break
		var ladder_mode := _ladder_mode(tok)
		if ladder_mode != 0:
			view_objects.append({
				"kind": VIEW_OBJECT_LADDER,
				"depth": depth,
				"mode": ladder_mode,
			})
		else:
			var tile_id := _cell_object_tile_id(dmap, cell, z, tok)
			if tile_id >= 0:
				view_objects.append({
					"kind": VIEW_OBJECT_TILE,
					"depth": depth,
					"tile_id": tile_id,
				})
		_blit_cached_piece(
			buf,
			"floor:%d" % depth,
			Callable(self, "_paint_floor_slab").bind(geom, dim, depth)
		)
		_blit_cached_piece(
			buf,
			"ceiling:%d" % depth,
			Callable(self, "_paint_ceiling_slab").bind(geom, dim, depth)
		)
		if dmap.looks_like_wall(left.x, left.y, z):
			_blit_cached_piece(
				buf,
				"side_wall:left:%d" % depth,
				Callable(self, "_blit_side_trap").bind(
					_tex_side(depth), geom, true, dim
				)
			)
		elif _is_side_entrance(dmap, left, z):
			_blit_cached_piece(
				buf,
				"side_entrance:left:%d" % depth,
				Callable(self, "_blit_side_trap").bind(
					_tex_entrance(depth), geom, true, dim
				)
			)
		else:
			_blit_cached_piece(
				buf,
				"side_open:left:%d" % depth,
				Callable(self, "_blit_side_open_rect").bind(geom, true, dim, depth)
			)
		if dmap.looks_like_wall(right.x, right.y, z):
			_blit_cached_piece(
				buf,
				"side_wall:right:%d" % depth,
				Callable(self, "_blit_side_trap").bind(
					_tex_side(depth), geom, false, dim
				)
			)
		elif _is_side_entrance(dmap, right, z):
			_blit_cached_piece(
				buf,
				"side_entrance:right:%d" % depth,
				Callable(self, "_blit_side_trap").bind(
					_tex_entrance(depth), geom, false, dim
				)
			)
		else:
			_blit_cached_piece(
				buf,
				"side_open:right:%d" % depth,
				Callable(self, "_blit_side_open_rect").bind(geom, false, dim, depth)
			)
	if reached_far:
		_paint_peek_wall(buf, dmap, pos, z, dir, w, h)
	## Geometry is complete: paint objects back-to-front so no later corridor
	## surface can hide them and nearer objects correctly overlap farther ones.
	for i in range(view_objects.size() - 1, -1, -1):
		var object: Dictionary = view_objects[i]
		if int(object["kind"]) == VIEW_OBJECT_LADDER:
			_paint_ladder_object(
				buf, int(object["mode"]), int(object["depth"]), w, h, 1.0
			)
		else:
			_paint_tile_object(
				buf, int(object["tile_id"]), int(object["depth"]), w, h, 1.0, anim_frame
			)


func _ahead(dmap, pos: Vector2i, dir: int, depth: int) -> Vector2i:
	var p := pos
	for _i in depth:
		p = dmap.neighbor(p.x, p.y, dir)
	return p


func _left_of(dmap, pos: Vector2i, dir: int) -> Vector2i:
	return dmap.neighbor(pos.x, pos.y, posmod(dir + 3, 4))


func _right_of(dmap, pos: Vector2i, dir: int) -> Vector2i:
	return dmap.neighbor(pos.x, pos.y, posmod(dir + 1, 4))


func _is_side_entrance(dmap, cell: Vector2i, z: int) -> bool:
	var tok: int = dmap.token_at(cell.x, cell.y, z)
	if tok == _DungeonMap.TOK_DOOR or tok == _DungeonMap.TOK_ROOM:
		return true
	if tok == _DungeonMap.TOK_SECRET and bool(dmap.is_secret_revealed(cell.x, cell.y, z)):
		return true
	return false


func _is_blocking_wall(dmap, cell: Vector2i, z: int) -> bool:
	var tok: int = dmap.token_at(cell.x, cell.y, z)
	if tok == _DungeonMap.TOK_WALL:
		return true
	if tok == _DungeonMap.TOK_SECRET and not bool(dmap.is_secret_revealed(cell.x, cell.y, z)):
		return true
	return false


func _paint_peek_wall(buf: Image, dmap, pos: Vector2i, z: int, dir: int, w: int, h: int) -> void:
	## +5: only whether a wall closes the vanishing square.
	var cell := _ahead(dmap, pos, dir, PEEK_DEPTH)
	if not _is_blocking_wall(dmap, cell, z):
		return
	_blit_cached_piece(
		buf,
		"front_wall:%d" % MAX_DEPTH,
		Callable(self, "_blit_rect").bind(
			_tex_front(MAX_DEPTH), _front_rect(MAX_DEPTH, w, h), 1.0
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


func _ensure_dim_lut(w: int, h: int) -> void:
	var inner := _ring(mini(w, h), MAX_DEPTH)
	if (
		_dim_lut_w == w
		and _dim_lut_h == h
		and _dim_lut_inner == inner
		and _dim_lut.size() == w * h
	):
		return
	_dim_lut_w = w
	_dim_lut_h = h
	_dim_lut_inner = inner
	_dim_lut.resize(w * h)
	var inv := 1.0 / float(maxi(inner, 1))
	for y in range(h):
		var dy := mini(y, h - 1 - y)
		var row := y * w
		for x in range(w):
			var dx := mini(x, w - 1 - x)
			var t := clampf(float(mini(dx, dy)) * inv, 0.0, 1.0)
			_dim_lut[row + x] = lerpf(1.0, DIM_FAR, t)


func _ensure_piece_cache_size(w: int, h: int) -> void:
	if _piece_cache_w == w and _piece_cache_h == h:
		return
	_piece_cache_w = w
	_piece_cache_h = h
	_piece_cache.clear()


func _blit_cached_piece(buf: Image, key: String, painter: Callable) -> void:
	var cache_key := "%d:%s:%s" % [PIECE_CACHE_REV, theme_id, key]
	if not _piece_cache.has(cache_key):
		var canvas := Image.create(
			_piece_cache_w, _piece_cache_h, false, Image.FORMAT_RGBA8
		)
		canvas.fill(Color(0, 0, 0, 0))
		painter.call(canvas)
		var used := canvas.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			_piece_cache[cache_key] = {}
		else:
			_piece_cache[cache_key] = {
				"image": canvas.get_region(used),
				"position": used.position,
			}
	var piece: Dictionary = _piece_cache[cache_key]
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


func _tex_floor(_depth: int = 0) -> Image:
	return _floor


func _tex_entrance(_depth: int = 0) -> Image:
	return _entrance


func _paint_floor_slab(buf: Image, geom: Dictionary, dim: float, depth: int) -> void:
	## Horizontal bands only — scanlines stay level, left/right edges are the diagonals.
	if theme_id == "dirt":
		## Earthen caves have no visible floor beyond the torch-lit walls.
		return
	var src := _tex_floor(depth)
	var floor_dim := dim
	var flip_v := false
	if theme_id == "brick" or theme_id == "grey_stone":
		## Masonry floors use the same material as the ceiling.
		src = _tex_front(depth)
		flip_v = true
	_blit_hband_quad(
		buf, src,
		float(geom["x0"]), float(geom["x1"]), int(geom["y1"]),
		float(geom["nx0"]), float(geom["nx1"]), int(geom["ny1"]),
		floor_dim, flip_v
	)


func _paint_ceiling_slab(buf: Image, geom: Dictionary, dim: float, depth: int) -> void:
	_blit_hband_quad(
		buf, _tex_front(depth),
		float(geom["x0"]), float(geom["x1"]), int(geom["y0"]),
		float(geom["nx0"]), float(geom["nx1"]), int(geom["ny0"]),
		dim, true
	)


func _blit_hband_quad(
	buf: Image,
	src: Image,
	x0: float,
	x1: float,
	y_near: int,
	nx0: float,
	nx1: float,
	y_far: int,
	dim: float,
	flip_v: bool,
	clip_x0: int = -0x3fffffff,
	clip_x1: int = 0x3fffffff
) -> void:
	if src == null:
		return
	var y_a := mini(y_near, y_far)
	var y_b := maxi(y_near, y_far)
	var y_span := float(y_far - y_near)
	if y_b <= y_a or absf(y_span) < 0.5:
		return
	var sw := src.get_width()
	var sh := src.get_height()
	var bw := buf.get_width()
	var bh := buf.get_height()
	for y in range(y_a, y_b):
		if y < 0 or y >= bh:
			continue
		## Sample at pixel centers so top and bottom quads are exact mirrors.
		var t := clampf((float(y) + 0.5 - float(y_near)) / y_span, 0.0, 1.0)
		var xl := int(round(lerpf(x0, nx0, t)))
		var xr := int(round(lerpf(x1, nx1, t)))
		if xr <= xl:
			continue
		var v := (1.0 - t) if flip_v else t
		var sy := clampi(int(v * float(sh - 1)), 0, sh - 1)
		var row := y * bw
		var dw := float(xr - xl)
		var x_draw0 := maxi(xl, clip_x0)
		var x_draw1 := mini(xr, clip_x1)
		for x in range(x_draw0, x_draw1):
			if x < 0 or x >= bw:
				continue
			## u from the full quad so a cropped parallelogram keeps its tile corners.
			var sx := clampi(
				int((float(x - xl) + 0.5) / dw * float(sw - 1)), 0, sw - 1
			)
			var c := src.get_pixel(sx, sy)
			var d := dim * _dim_lut[row + x]
			buf.set_pixel(x, y, Color(c.r * d, c.g * d, c.b * d, 1.0))


func _open_side_src_span(geom: Dictionary, dest_x0: int, dest_x1: int) -> float:
	## Visible alcove width / one cell at the far plane (same scale as that front wall).
	var far_w := int(geom["nx1"]) - int(geom["nx0"])
	var dest_w := dest_x1 - dest_x0
	if far_w <= 0 or dest_w <= 0:
		return 1.0
	return float(dest_w) / float(far_w)


func _paint_open_side_ceiling(buf: Image, geom: Dictionary, left: bool, dim: float, depth: int) -> void:
	## Side-cell ceiling parallelogram. Full width at the far plane is one corridor cell
	## (same as the facing wall there). Visible alcove / that width is the crop ratio;
	## outer edge stays parallel so the tile is a cut rhombus matching the wall below.
	var y_near := int(geom["y0"])
	var y_far := int(geom["ny0"])
	var far_w := float(int(geom["nx1"]) - int(geom["nx0"]))
	if far_w < 0.5:
		return
	if left:
		var x_far_inner := float(geom["nx0"])
		var x_near_inner := float(geom["x0"])
		var x_far_outer := x_far_inner - far_w
		var x_near_outer := x_near_inner - far_w
		_blit_hband_quad(
			buf, _tex_front(depth),
			x_near_outer, x_near_inner, y_near,
			x_far_outer, x_far_inner, y_far,
			dim, true,
			int(geom["x0"]), int(geom["nx0"])
		)
	else:
		var x_far_inner := float(geom["nx1"])
		var x_near_inner := float(geom["x1"])
		var x_far_outer := x_far_inner + far_w
		var x_near_outer := x_near_inner + far_w
		_blit_hband_quad(
			buf, _tex_front(depth),
			x_near_inner, x_near_outer, y_near,
			x_far_inner, x_far_outer, y_far,
			dim, true,
			int(geom["nx1"]), int(geom["x1"])
		)


func _paint_open_side_floor(buf: Image, geom: Dictionary, left: bool, dim: float, depth: int) -> void:
	## Mirror the open-side ceiling below the facing rect. Dirt remains unlit black.
	if theme_id == "dirt":
		return
	var src := _tex_floor(depth)
	var floor_dim := dim
	var flip_v := false
	if theme_id == "brick" or theme_id == "grey_stone":
		src = _tex_front(depth)
		flip_v = true
	var y_near := int(geom["y1"])
	var y_far := int(geom["ny1"])
	var far_w := float(int(geom["nx1"]) - int(geom["nx0"]))
	if far_w < 0.5:
		return
	if left:
		var x_far_inner := float(geom["nx0"])
		var x_near_inner := float(geom["x0"])
		var x_far_outer := x_far_inner - far_w
		var x_near_outer := x_near_inner - far_w
		_blit_hband_quad(
			buf, src,
			x_near_outer, x_near_inner, y_near,
			x_far_outer, x_far_inner, y_far,
			floor_dim, flip_v,
			int(geom["x0"]), int(geom["nx0"])
		)
	else:
		var x_far_inner := float(geom["nx1"])
		var x_near_inner := float(geom["x1"])
		var x_far_outer := x_far_inner + far_w
		var x_near_outer := x_near_inner + far_w
		_blit_hband_quad(
			buf, src,
			x_near_inner, x_near_outer, y_near,
			x_far_inner, x_far_outer, y_far,
			floor_dim, flip_v,
			int(geom["nx1"]), int(geom["x1"])
		)


func _blit_side_open_rect(buf: Image, geom: Dictionary, left: bool, dim: float, depth: int) -> void:
	## Open alcove: facing rect flush with the next cell, flat fog.
	_paint_open_side_ceiling(buf, geom, left, dim, depth)
	_paint_open_side_floor(buf, geom, left, dim, depth)
	var x0 := int(geom["x0"] if left else geom["nx1"])
	var x1 := int(geom["nx0"] if left else geom["x1"])
	var y0 := int(geom["ny0"])
	var y1 := int(geom["ny1"])
	if x1 <= x0 or y1 <= y0:
		return
	var span := _open_side_src_span(geom, x0, x1)
	var u0 := (1.0 - span) if left else 0.0
	var u1 := 1.0 if left else span
	var bw := buf.get_width()
	var bh := buf.get_height()
	var fog := _lut_at(int(geom["nx0"]), y0, bw, bh)
	_blit_scaled(
		buf,
		_tex_front(mini(depth + 1, MAX_DEPTH)),
		x0, y0, x1, y1,
		dim * fog, false, u0, u1, true, false
	)


func _blit_side_trap(buf: Image, src: Image, geom: Dictionary, left: bool, dim: float) -> void:
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
	for x in range(x_a, x_b):
		if x < 0 or x >= bw:
			continue
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
			var d := dim * _dim_lut[y * bw + x]
			buf.set_pixel(x, y, Color(c.r * d, c.g * d, c.b * d, 1.0))


func _lut_at(x: int, y: int, w: int, h: int) -> float:
	if _dim_lut.is_empty():
		return 1.0
	var px := clampi(x, 0, w - 1)
	var py := clampi(y, 0, h - 1)
	return _dim_lut[py * w + px]


func _blit_rect(buf: Image, src: Image, r: Rect2i, dim: float, flip_h: bool = false) -> void:
	## Facing wall: flat brightness from the rect's outer edge, no inner gradient.
	if src == null or r.size.x <= 0 or r.size.y <= 0:
		return
	var bw := buf.get_width()
	var bh := buf.get_height()
	_blit_scaled(
		buf, src,
		r.position.x, r.position.y,
		r.position.x + r.size.x, r.position.y + r.size.y,
		dim * _lut_at(r.position.x, r.position.y, bw, bh),
		flip_h, 0.0, 1.0, false, false
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
	flip_v: bool = false
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
	var fr := _front_rect(depth, field_w, field_h)
	_blit_cached_piece(
		buf,
		"ladder:%d:%d" % [mode, depth],
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
		_DungeonMap.TOK_TRAP:
			tid = 77
	return tid


func _paint_tile_object(
	buf: Image,
	tid: int,
	depth: int,
	field_w: int,
	field_h: int,
	dim: float,
	anim_frame: int
) -> void:
	if tid < 0:
		return
	var img: Image
	if tid == TILE_FOUNTAIN and not _fountain_frames.is_empty():
		img = _fountain_frames[posmod(anim_frame, _fountain_frames.size())]
	else:
		img = _U4TileBank.image(tid)
	if img == null:
		return
	var nscale: int = OBJ_NSCALE[clampi(depth, 0, OBJ_NSCALE.size() - 1)]
	var object_scale := 1.0
	if tid == TILE_CHEST:
		object_scale = CHEST_VIEW_SCALE
	elif tid == TILE_FOUNTAIN:
		object_scale = FOUNTAIN_VIEW_SCALE
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
	var object_light := dim * _lut_at(
		fr.position.x, fr.position.y, buf.get_width(), buf.get_height()
	)
	## Tile icons already carry transparent alpha; _blit_scaled skips those pixels.
	_blit_scaled(
		buf, img,
		mid_x - span / 2, obj_y0, mid_x + span / 2, obj_y1,
		object_light, false, 0.0, 1.0, false, false
	)


func _load_png(path: String) -> Image:
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return img
