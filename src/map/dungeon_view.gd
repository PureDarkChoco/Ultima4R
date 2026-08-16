class_name DungeonView
extends RefCounted

## First-person corridor renderer. Shared geometry; theme textures swap per dungeon.

const _DungeonMap := preload("res://src/map/dungeon_map_data.gd")
const _U4TileBank := preload("res://src/map/u4_tile_bank.gd")

const ASSET_ROOT := "res://assets/dungeon"
const MAX_DEPTH := 3
const TILE_CHEST := 60
const TILE_LADDER_UP := 27
const TILE_LADDER_DOWN := 28
const TILE_ALTAR := 74
const TILE_ORB := 78
const TILE_FOUNTAIN := 75

var theme_id: String = "grey_stone"
var _wall: Image
var _floor: Image
var _entrance: Image
var _theme_loaded := ""


func set_theme(id: String) -> void:
	if id == _theme_loaded and _wall != null:
		theme_id = id
		return
	theme_id = id
	_theme_loaded = id
	_wall = _load_png("%s/%s/wall.png" % [ASSET_ROOT, id])
	_floor = _load_png("%s/%s/floor.png" % [ASSET_ROOT, id])
	_entrance = _load_png("%s/%s/room_entrance.png" % [ASSET_ROOT, id])


func paint(
	buf: Image,
	dmap,
	pos: Vector2i,
	z: int,
	dir: int,
	lit: bool
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
	buf.fill(_shade_color(Color(0.04, 0.03, 0.03, 1), 0.15))
	_paint_floor_ceiling(buf, w, h)
	for depth in range(MAX_DEPTH, -1, -1):
		var cell := _ahead(dmap, pos, dir, depth)
		var left := _left_of(dmap, cell, dir)
		var right := _right_of(dmap, cell, dir)
		var geom := _depth_geom(w, h, depth)
		if dmap.looks_like_wall(left.x, left.y, z):
			_blit_side(buf, _wall, geom, true, _falloff(depth))
		if dmap.looks_like_wall(right.x, right.y, z):
			_blit_side(buf, _wall, geom, false, _falloff(depth))
		var tok: int = dmap.token_at(cell.x, cell.y, z)
		if tok == _DungeonMap.TOK_WALL or (
			tok == _DungeonMap.TOK_SECRET and not dmap.is_secret_revealed(cell.x, cell.y, z)
		):
			_blit_front(buf, _wall, geom, _falloff(depth))
			continue
		if tok == _DungeonMap.TOK_ROOM or tok == _DungeonMap.TOK_DOOR:
			_blit_front(buf, _entrance, geom, _falloff(depth))
		elif tok == _DungeonMap.TOK_SECRET:
			_blit_front(buf, _entrance, geom, _falloff(depth) * 0.85)
		_paint_cell_object(buf, dmap, cell, z, geom, _falloff(depth))


func _ahead(dmap, pos: Vector2i, dir: int, depth: int) -> Vector2i:
	var p := pos
	for _i in depth:
		p = dmap.neighbor(p.x, p.y, dir)
	return p


func _left_of(dmap, pos: Vector2i, dir: int) -> Vector2i:
	return dmap.neighbor(pos.x, pos.y, posmod(dir + 3, 4))


func _right_of(dmap, pos: Vector2i, dir: int) -> Vector2i:
	return dmap.neighbor(pos.x, pos.y, posmod(dir + 1, 4))


func _depth_geom(w: int, h: int, depth: int) -> Dictionary:
	var t := float(depth) / float(MAX_DEPTH + 1)
	var t2 := float(depth + 1) / float(MAX_DEPTH + 1)
	var inset0 := int(w * (0.04 + t * 0.32))
	var inset1 := int(w * (0.04 + t2 * 0.32))
	var top0 := int(h * (0.06 + t * 0.22))
	var top1 := int(h * (0.06 + t2 * 0.22))
	var bot0 := h - int(h * (0.08 + t * 0.20))
	var bot1 := h - int(h * (0.08 + t2 * 0.20))
	return {
		"x0": inset0, "x1": w - inset0, "y0": top0, "y1": bot0,
		"nx0": inset1, "nx1": w - inset1, "ny0": top1, "ny1": bot1,
		"w": w, "h": h, "depth": depth,
	}


func _falloff(depth: int) -> float:
	return clampf(1.0 - float(depth) * 0.22, 0.28, 1.0)


func _paint_floor_ceiling(buf: Image, w: int, h: int) -> void:
	var horizon := int(h * 0.42)
	if _floor != null:
		for y in range(horizon, h):
			var u := float(y - horizon) / float(maxi(h - horizon, 1))
			var inset := int(w * (0.36 * (1.0 - u)))
			var src_y := clampi(int(u * float(_floor.get_height() - 1)), 0, _floor.get_height() - 1)
			var dim := 0.35 + u * 0.55
			for x in range(inset, w - inset):
				var src_x := int(float(x - inset) / float(maxi(w - inset * 2, 1)) * float(_floor.get_width() - 1))
				var c := _floor.get_pixel(src_x, src_y)
				buf.set_pixel(x, y, _shade_color(c, dim))
	if _wall != null:
		for y in range(0, horizon):
			var u := 1.0 - float(y) / float(maxi(horizon, 1))
			var inset := int(w * (0.36 * (1.0 - u)))
			var src_y := clampi(int((1.0 - u) * float(_wall.get_height() - 1)), 0, _wall.get_height() - 1)
			var dim := 0.18 + u * 0.22
			for x in range(inset, w - inset):
				var src_x := int(float(x - inset) / float(maxi(w - inset * 2, 1)) * float(_wall.get_width() - 1))
				var c := _wall.get_pixel(src_x, src_y)
				buf.set_pixel(x, y, _shade_color(c, dim))


func _blit_front(buf: Image, src: Image, geom: Dictionary, dim: float) -> void:
	if src == null:
		return
	var x0 := int(geom["nx0"])
	var x1 := int(geom["nx1"])
	var y0 := int(geom["ny0"])
	var y1 := int(geom["ny1"])
	_blit_scaled(buf, src, x0, y0, x1, y1, dim)


func _blit_side(buf: Image, src: Image, geom: Dictionary, left: bool, dim: float) -> void:
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
	for x in range(x_a, x_b):
		var t := float(x - x_a) / float(x_b - x_a)
		if left:
			t = 1.0 - t
		var y0 := int(lerpf(float(y0n), float(y0f), 1.0 - t if left else t))
		var y1 := int(lerpf(float(y1n), float(y1f), 1.0 - t if left else t))
		if y1 <= y0:
			continue
		var sx := clampi(int(t * float(sw - 1)), 0, sw - 1)
		for y in range(y0, y1):
			var sy := clampi(int(float(y - y0) / float(y1 - y0) * float(sh - 1)), 0, sh - 1)
			var c := src.get_pixel(sx, sy)
			buf.set_pixel(x, y, _shade_color(c, dim * (0.72 if left else 0.58)))


func _blit_scaled(buf: Image, src: Image, x0: int, y0: int, x1: int, y1: int, dim: float) -> void:
	var dw := x1 - x0
	var dh := y1 - y0
	if dw <= 0 or dh <= 0:
		return
	var sw := src.get_width()
	var sh := src.get_height()
	var bw := buf.get_width()
	var bh := buf.get_height()
	for y in range(y0, y1):
		if y < 0 or y >= bh:
			continue
		var sy := clampi(int(float(y - y0) / float(dh) * float(sh)), 0, sh - 1)
		for x in range(x0, x1):
			if x < 0 or x >= bw:
				continue
			var sx := clampi(int(float(x - x0) / float(dw) * float(sw)), 0, sw - 1)
			var c := src.get_pixel(sx, sy)
			if c.a < 0.05:
				continue
			buf.set_pixel(x, y, _shade_color(c, dim))


func _paint_cell_object(buf: Image, dmap, cell: Vector2i, z: int, geom: Dictionary, dim: float) -> void:
	var tok: int = dmap.token_at(cell.x, cell.y, z)
	var tid := -1
	match tok:
		_DungeonMap.TOK_CHEST:
			if not dmap.is_consumed(cell.x, cell.y, z):
				tid = TILE_CHEST
		_DungeonMap.TOK_LADDER_UP, _DungeonMap.TOK_CEILING_HOLE:
			tid = TILE_LADDER_UP
		_DungeonMap.TOK_LADDER_DOWN, _DungeonMap.TOK_FLOOR_HOLE:
			tid = TILE_LADDER_DOWN
		_DungeonMap.TOK_LADDER_BOTH:
			tid = TILE_LADDER_UP
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
	if tid < 0:
		return
	var img: Image = _U4TileBank.image(tid)
	if img == null:
		return
	var x0 := int(geom["nx0"])
	var x1 := int(geom["nx1"])
	var y0 := int(geom["ny0"])
	var y1 := int(geom["ny1"])
	var mid_x := (x0 + x1) / 2
	var span := maxi((x1 - x0) / 3, 12)
	var obj_y1 := y1 - 2
	var obj_y0 := obj_y1 - span
	_blit_scaled(buf, img, mid_x - span / 2, obj_y0, mid_x + span / 2, obj_y1, dim)


func _shade_color(c: Color, dim: float) -> Color:
	return Color(c.r * dim, c.g * dim, c.b * dim, 1.0)


func _load_png(path: String) -> Image:
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return img
