class_name DungeonAutomap
extends RefCounted

## 8×8 dungeon floor map for the journal: first-person FOV fog, game tiles.

const _DungeonMap := preload("res://src/map/dungeon_map_data.gd")
const _U4TileBank := preload("res://src/map/u4_tile_bank.gd")

const SIDE := 8
const FLOORS := 8
const MASK_BYTES := SIDE * FLOORS ## 8 bits/row × 8 floors
const MAX_DEPTH := 4
const PEEK_DEPTH := 5
const CELL_PX := 16 ## Half of U4TileBank.TILE_SIZE (32).
const TILE_FLOOR := 62
const TILE_WALL := 57
const TILE_LADDER_UP := 27
const TILE_LADDER_DOWN := 28
const TILE_CHEST := 60
const TILE_ALTAR := 74
const TILE_ORB := 78
const TILE_FOUNTAIN := 75
const TILE_DOOR := 59
const WIND_DIR_PATH := "res://assets/ui/wind"
const WIND_CARDINAL_FILES := ["n", "e", "s", "w"]
const FRAME := Color(0.22, 0.24, 0.22, 1.0)
const SECRET_FRAME := Color(1.0, 0.78, 0.18, 1.0)
const SECRET_GLOW := Color(1.0, 0.72, 0.08, 0.28)


static func empty_mask() -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(MASK_BYTES)
	m.fill(0)
	return m


static func mask_from_save(raw: Variant) -> PackedByteArray:
	var m := empty_mask()
	if typeof(raw) != TYPE_STRING:
		return m
	var s := str(raw).strip_edges()
	if s.is_empty():
		return m
	var decoded := Marshalls.base64_to_raw(s)
	if decoded.size() != MASK_BYTES:
		return m
	return decoded


static func mask_to_save(mask: PackedByteArray) -> String:
	if mask.size() != MASK_BYTES:
		return ""
	return Marshalls.raw_to_base64(mask)


static func masks_from_save(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for id in (raw as Dictionary).keys():
		var key := str(id).strip_edges().to_lower()
		if key.is_empty():
			continue
		var mask := mask_from_save((raw as Dictionary)[id])
		if _mask_has_any(mask):
			out[key] = mask
	return out


static func masks_to_save(masks: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id in masks.keys():
		var key := str(id).strip_edges().to_lower()
		if key.is_empty():
			continue
		var raw: Variant = masks[id]
		if typeof(raw) != TYPE_PACKED_BYTE_ARRAY:
			continue
		var mask: PackedByteArray = raw
		if mask.size() != MASK_BYTES or not _mask_has_any(mask):
			continue
		out[key] = mask_to_save(mask)
	return out


static func _mask_has_any(mask: PackedByteArray) -> bool:
	for b in mask:
		if int(b) != 0:
			return true
	return false


static func is_explored(mask: PackedByteArray, x: int, y: int, z: int) -> bool:
	var i := _bit_index(x, y, z)
	if i < 0 or mask.size() != MASK_BYTES:
		return false
	return (mask[i >> 3] & (1 << (i & 7))) != 0


static func mark_explored(mask: PackedByteArray, x: int, y: int, z: int) -> bool:
	var i := _bit_index(x, y, z)
	if i < 0 or mask.size() != MASK_BYTES:
		return false
	var bit := 1 << (i & 7)
	var b := i >> 3
	if (mask[b] & bit) != 0:
		return false
	mask[b] = mask[b] | bit
	return true


static func mark_cells(mask: PackedByteArray, cells: Array[Vector2i], z: int) -> bool:
	var changed := false
	for cell in cells:
		if mark_explored(mask, cell.x, cell.y, z):
			changed = true
	return changed


static func _bit_index(x: int, y: int, z: int) -> int:
	if x < 0 or y < 0 or x >= SIDE or y >= SIDE:
		return -1
	if z < 0 or z >= FLOORS:
		return -1
	return (z * SIDE * SIDE) + y * SIDE + x


static func visible_cells(
	dmap,
	pos: Vector2i,
	z: int,
	dir: int,
	lit: bool
) -> Array[Vector2i]:
	## Same cells the first-person view paints: ahead + left/right, stop at wall/door.
	var out: Array[Vector2i] = []
	if dmap == null or not lit:
		return out
	var seen: Dictionary = {}
	var reached_far := true
	for depth in range(0, MAX_DEPTH + 1):
		var cell := _ahead(dmap, pos, dir, depth)
		_mark_cell(seen, out, cell)
		if _blocks_view(dmap, cell, z):
			reached_far = false
			break
		_mark_cell(seen, out, _side(dmap, cell, dir, 3))
		_mark_cell(seen, out, _side(dmap, cell, dir, 1))
	if reached_far:
		var peek := _ahead(dmap, pos, dir, PEEK_DEPTH)
		if _is_blocking_wall(dmap, peek, z):
			_mark_cell(seen, out, peek)
	return out


static func _mark_cell(seen: Dictionary, out: Array[Vector2i], cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= SIDE or cell.y >= SIDE:
		return
	var key := cell.x | (cell.y << 8)
	if seen.has(key):
		return
	seen[key] = true
	out.append(cell)


static func _ahead(dmap, pos: Vector2i, dir: int, depth: int) -> Vector2i:
	var p := pos
	for _i in depth:
		p = dmap.neighbor(p.x, p.y, dir)
	return p


static func _side(dmap, pos: Vector2i, dir: int, turn: int) -> Vector2i:
	return dmap.neighbor(pos.x, pos.y, posmod(dir + turn, 4))


static func _is_blocking_wall(dmap, cell: Vector2i, z: int) -> bool:
	var tok: int = dmap.token_at(cell.x, cell.y, z)
	return tok == _DungeonMap.TOK_WALL or tok == _DungeonMap.TOK_SECRET


static func _blocks_view(dmap, cell: Vector2i, z: int) -> bool:
	if _is_blocking_wall(dmap, cell, z):
		return true
	var tok: int = dmap.token_at(cell.x, cell.y, z)
	return tok == _DungeonMap.TOK_ROOM or tok == _DungeonMap.TOK_DOOR


static func tile_for_cell(dmap, x: int, y: int, z: int) -> int:
	if dmap == null:
		return TILE_WALL
	var tok: int = dmap.token_at(x, y, z)
	match tok:
		_DungeonMap.TOK_WALL:
			return TILE_WALL
		_DungeonMap.TOK_SECRET:
			return TILE_WALL
		_DungeonMap.TOK_LADDER_UP, _DungeonMap.TOK_CEILING_HOLE:
			return TILE_LADDER_UP
		_DungeonMap.TOK_LADDER_DOWN, _DungeonMap.TOK_FLOOR_HOLE:
			return TILE_LADDER_DOWN
		_DungeonMap.TOK_LADDER_BOTH:
			return TILE_LADDER_UP
		_DungeonMap.TOK_CHEST:
			if bool(dmap.is_consumed(x, y, z)):
				return TILE_FLOOR
			return TILE_CHEST
		_DungeonMap.TOK_ORB:
			if bool(dmap.is_consumed(x, y, z)):
				return TILE_FLOOR
			return TILE_ORB
		_DungeonMap.TOK_ALTAR:
			return TILE_ALTAR
		_DungeonMap.TOK_FOUNTAIN:
			return TILE_FOUNTAIN
		_DungeonMap.TOK_FIELD:
			return int(dmap.field_world_tile(x, y, z))
		_DungeonMap.TOK_DOOR, _DungeonMap.TOK_ROOM:
			return TILE_DOOR
		_:
			return TILE_FLOOR


static func paint(
	dmap,
	mask: PackedByteArray,
	z: int,
	party_pos: Vector2i,
	party_dir: int = 2
) -> Image:
	var px := CELL_PX
	var img := Image.create(SIDE * px, SIDE * px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	if dmap == null:
		_stroke_frame(img)
		return img
	for y in SIDE:
		for x in SIDE:
			if not is_explored(mask, x, y, z):
				continue
			_blit_tile(img, tile_for_cell(dmap, x, y, z), Vector2i(x * px, y * px), px)
			if (
				dmap.token_at(x, y, z) == _DungeonMap.TOK_SECRET
				and bool(dmap.is_secret_revealed(x, y, z))
			):
				_mark_secret_cell(img, Vector2i(x, y), px)
	if (
		party_pos.x >= 0 and party_pos.y >= 0
		and party_pos.x < SIDE and party_pos.y < SIDE
	):
		_blit_facing_arrow(img, party_pos, px, party_dir)
	_stroke_frame(img)
	return img


static func _blit_tile(dest: Image, tid: int, dst: Vector2i, cell: int) -> void:
	var src: Image
	if tid == TILE_ORB and _U4TileBank.uses_hgr_ntsc():
		src = _U4TileBank.isolated_overlay(tid)
	else:
		src = _U4TileBank.keyed_copy(tid)
	if src == null or src.is_empty():
		src = _U4TileBank.image(tid)
	if src == null or src.is_empty():
		return
	var chip := src
	var apple2 := _U4TileBank.keeps_opaque_black()
	if src.get_width() != cell or src.get_height() != cell:
		if apple2:
			## HGR/mono art is a sparse CRT-ink dither: a single nearest-
			## neighbour sample per output pixel randomly lands on black
			## far more than the pattern's true coverage, crushing the
			## whole chip toward black. Box-average down instead so the
			## resized chip keeps the source's real average brightness.
			chip = _box_downsample(src, cell, cell)
		else:
			chip = src.duplicate()
			chip.resize(cell, cell, Image.INTERPOLATE_NEAREST)
	if apple2:
		chip = chip.duplicate()
		_brighten_apple2_chip(chip)
	dest.blit_rect(chip, Rect2i(0, 0, cell, cell), dst)


static func _box_downsample(src: Image, w: int, h: int) -> Image:
	var sw := src.get_width()
	var sh := src.get_height()
	if w <= 0 or h <= 0 or sw <= 0 or sh <= 0:
		return src.duplicate()
	if sw % w != 0 or sh % h != 0:
		## Non-integer ratio: bilinear still averages neighbours, unlike
		## nearest, so it is a reasonable fallback for odd sizes.
		var fallback := src.duplicate()
		fallback.resize(w, h, Image.INTERPOLATE_BILINEAR)
		return fallback
	var fx := sw / w
	var fy := sh / h
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for oy in h:
		for ox in w:
			var acc := Color(0.0, 0.0, 0.0, 0.0)
			for dy in fy:
				for dx in fx:
					acc += src.get_pixel(ox * fx + dx, oy * fy + dy)
			var n := float(fx * fy)
			out.set_pixel(ox, oy, Color(acc.r / n, acc.g / n, acc.b / n, acc.a / n))
	return out


static func _blit_facing_arrow(img: Image, pos: Vector2i, cell: int, dir: int) -> void:
	## Reuse the cardinal HUD wind art rather than synthesizing another arrow.
	var path := "%s/%s.png" % [
		WIND_DIR_PATH,
		WIND_CARDINAL_FILES[posmod(dir, 4)],
	]
	var icon := Image.new()
	if icon.load(path) != OK or icon.is_empty():
		return
	if icon.get_format() != Image.FORMAT_RGBA8:
		icon.convert(Image.FORMAT_RGBA8)
	for y in icon.get_height():
		for x in icon.get_width():
			var c := icon.get_pixel(x, y)
			if c.r < 0.05 and c.g < 0.05 and c.b < 0.05:
				icon.set_pixel(x, y, Color(0, 0, 0, 0))
	if icon.get_width() != cell or icon.get_height() != cell:
		icon.resize(cell, cell, Image.INTERPOLATE_NEAREST)
	img.blend_rect(
		icon,
		Rect2i(0, 0, cell, cell),
		Vector2i(pos.x * cell, pos.y * cell)
	)


static func _brighten_apple2_chip(img: Image) -> void:
	## HGR/mono art is sparse and loses luminous pixels at 50% scale.
	## Raise non-black phosphor/color pixels while keeping the CRT ink black.
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0 or maxf(c.r, maxf(c.g, c.b)) < 0.04:
				continue
			c.r = clampf(pow(c.r, 0.68) * 1.18, 0.0, 1.0)
			c.g = clampf(pow(c.g, 0.68) * 1.18, 0.0, 1.0)
			c.b = clampf(pow(c.b, 0.68) * 1.18, 0.0, 1.0)
			img.set_pixel(x, y, c)


static func _stroke_cell(img: Image, pos: Vector2i, cell: int, color: Color) -> void:
	var x0 := pos.x * cell
	var y0 := pos.y * cell
	img.fill_rect(Rect2i(x0, y0, cell, 1), color)
	img.fill_rect(Rect2i(x0, y0 + cell - 1, cell, 1), color)
	img.fill_rect(Rect2i(x0, y0, 1, cell), color)
	img.fill_rect(Rect2i(x0 + cell - 1, y0, 1, cell), color)


static func _mark_secret_cell(img: Image, pos: Vector2i, cell: int) -> void:
	var x0 := pos.x * cell
	var y0 := pos.y * cell
	var border := mini(3, cell / 3)
	img.blend_rect(
		_solid_image(cell - border * 2, cell - border * 2, SECRET_GLOW),
		Rect2i(0, 0, cell - border * 2, cell - border * 2),
		Vector2i(x0 + border, y0 + border)
	)
	img.fill_rect(Rect2i(x0, y0, cell, border), SECRET_FRAME)
	img.fill_rect(Rect2i(x0, y0 + cell - border, cell, border), SECRET_FRAME)
	img.fill_rect(Rect2i(x0, y0, border, cell), SECRET_FRAME)
	img.fill_rect(Rect2i(x0 + cell - border, y0, border, cell), SECRET_FRAME)


static func _solid_image(w: int, h: int, color: Color) -> Image:
	var img := Image.create(maxi(1, w), maxi(1, h), false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img


static func _stroke_frame(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	img.fill_rect(Rect2i(0, 0, w, 1), FRAME)
	img.fill_rect(Rect2i(0, h - 1, w, 1), FRAME)
	img.fill_rect(Rect2i(0, 0, 1, h), FRAME)
	img.fill_rect(Rect2i(w - 1, 0, 1, h), FRAME)
