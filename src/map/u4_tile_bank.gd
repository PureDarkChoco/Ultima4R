class_name U4TileBank
extends RefCounted

## Per-tile PNG bank for Ultima IV shapes (id 0..255).
##
## Files under SHAPES_DIR:
##   `NNN.png` / `NNN_name.png`     → tile NNN, frame 0
##   `NNN_name_1.png` … `_3.png`   → same tile, extra animation frames
##
## Classic even/odd pairs (`032_mage0.png` + `033_mage1.png`) stay separate
## tile ids. Use `_1` / `_2` / `_3` only when one map byte needs multiple frames
## (e.g. white corner tiles 049–052).

const SHAPES_DIR := "res://assets/tiles/u4graphics/shapes"
const FALLBACK_ATLAS := "res://assets/tiles/u4graphics/shapes.png"
const SHAPES_PACK := "res://assets/tiles/u4graphics/shapes.u4pack"
const SHAPES_PACK_MAGIC := "U4SP"
const SHAPES_PACK_VERSION := 1
const TILE_SIZE := 32
const COUNT := 256
const _ResImage := preload("res://src/core/res_image.gd")

## Array[Array] — outer = tile id, inner = frame Images (at least 1 when ready).
static var _frames: Array = []
## Frame-0 path per tile (for debugging / tools).
static var _paths: PackedStringArray = PackedStringArray()
static var _loaded := false


static func is_ready() -> bool:
	return _loaded and _frames.size() == COUNT


static func ensure_loaded() -> bool:
	if is_ready():
		return true
	_paths.resize(COUNT)
	_frames.clear()
	_frames.resize(COUNT)
	for i in COUNT:
		_paths[i] = ""
		_frames[i] = []
	_scan_dir()
	var missing := 0
	for i in COUNT:
		if (_frames[i] as Array).is_empty():
			missing += 1
	if missing > 0:
		_fill_missing_from_atlas()
	_loaded = true
	for i in COUNT:
		var arr: Array = _frames[i]
		if arr.is_empty() or arr[0] == null or (arr[0] as Image).is_empty():
			push_error("U4TileBank: missing tile %d" % i)
			_loaded = false
			return false
	return true


static func clear_cache() -> void:
	## Call after replacing files on disk if you need a hot reload.
	_frames.clear()
	_paths = PackedStringArray()
	_loaded = false


static func path_for(tile_id: int) -> String:
	ensure_loaded()
	if tile_id < 0 or tile_id >= COUNT:
		return ""
	return _paths[tile_id]


static func frame_count(tile_id: int) -> int:
	if not ensure_loaded():
		return 0
	if tile_id < 0 or tile_id >= COUNT:
		return 0
	return (_frames[tile_id] as Array).size()


static func image(tile_id: int, frame: int = 0) -> Image:
	if not ensure_loaded():
		return null
	if tile_id < 0 or tile_id >= COUNT:
		return null
	var arr: Array = _frames[tile_id]
	if arr.is_empty():
		return null
	var f := posmod(frame, arr.size())
	return arr[f] as Image


static func blit_to(dst: Image, tile_id: int, dst_pos: Vector2i, frame: int = 0) -> void:
	var src := image(tile_id, frame)
	if src == null or dst == null:
		return
	dst.blit_rect(src, Rect2i(0, 0, TILE_SIZE, TILE_SIZE), dst_pos)


static func blend_to(dst: Image, tile_id: int, dst_pos: Vector2i, frame: int = 0) -> void:
	## Alpha-aware copy (transparent margins show underdraw below).
	var src := image(tile_id, frame)
	if src == null or dst == null:
		return
	dst.blend_rect(src, Rect2i(0, 0, TILE_SIZE, TILE_SIZE), dst_pos)


static func blit_anim_to(dst: Image, tile_id: int, dst_pos: Vector2i, anim_tick: int) -> void:
	## Cycle multi-frame tiles; single-frame tiles ignore the tick.
	var n := frame_count(tile_id)
	var f := 0 if n <= 1 else posmod(anim_tick, n)
	blit_to(dst, tile_id, dst_pos, f)


static func blit_water_to(dst: Image, tile_id: int, dst_pos: Vector2i, scroll_px: int) -> void:
	## xu4 ATYPE_SCROLL: shift tile rows down by scroll_px with wrap (Y-axis).
	var src := image(tile_id, 0)
	if src == null or dst == null:
		return
	_blit_scroll_y(dst, src, dst_pos, scroll_px)


static func blit_water_edge_to(dst: Image, tile_id: int, dst_pos: Vector2i, scroll_px: int) -> void:
	## Shallow-water Y-scroll (tile 2), then stamp this tile's white/stone pixels on top.
	var src := image(tile_id, 0)
	var water := image(2, 0)
	if src == null or water == null or dst == null:
		return
	_blit_scroll_y(dst, water, dst_pos, scroll_px)
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			var c := src.get_pixel(x, y)
			if _is_fixed_stone_pixel(c):
				dst.set_pixel(dst_pos.x + x, dst_pos.y + y, c)


static func _blit_scroll_y(dst: Image, src: Image, dst_pos: Vector2i, scroll_px: int) -> void:
	var s := posmod(scroll_px, TILE_SIZE)
	if s == 0:
		dst.blit_rect(src, Rect2i(0, 0, TILE_SIZE, TILE_SIZE), dst_pos)
		return
	## Lower band of source → top of destination (water flows downward).
	dst.blit_rect(src, Rect2i(0, s, TILE_SIZE, TILE_SIZE - s), dst_pos)
	dst.blit_rect(src, Rect2i(0, 0, TILE_SIZE, s), dst_pos + Vector2i(0, TILE_SIZE - s))


static func _is_fixed_stone_pixel(c: Color) -> bool:
	## White / light-gray stone (not the dark blue water dither).
	return c.r > 0.70 and c.g > 0.70 and c.b > 0.70


static func keyed_copy(tile_id: int, frame: int = 0) -> Image:
	## Opaque black → transparent (sprites over terrain).
	var src := image(tile_id, frame)
	if src == null:
		return null
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.blit_rect(src, Rect2i(0, 0, TILE_SIZE, TILE_SIZE), Vector2i.ZERO)
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			var c := img.get_pixel(x, y)
			if c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return img


static func stacked_atlas() -> Image:
	## Rebuild a vertical strip for TileSet / tools that still want one texture.
	if not ensure_loaded():
		return null
	var atlas := Image.create(TILE_SIZE, TILE_SIZE * COUNT, false, Image.FORMAT_RGBA8)
	for i in COUNT:
		blit_to(atlas, i, Vector2i(0, i * TILE_SIZE), 0)
	return atlas


static func _scan_dir() -> void:
	## id → Dictionary frame_index → path (best name wins)
	var found: Array = []
	found.resize(COUNT)
	for i in COUNT:
		found[i] = {}
	if _scan_pack(found):
		_commit_found(found)
		return
	var names := _ResImage.list_png_names(SHAPES_DIR)
	if names.is_empty():
		push_warning("U4TileBank: no PNGs under %s" % SHAPES_DIR)
		return
	for fname in names:
		var parsed := _parse_filename(fname)
		var id: int = parsed.x
		var frame: int = parsed.y
		if id >= 0 and id < COUNT and frame >= 0:
			var full := "%s/%s" % [SHAPES_DIR, fname]
			var slot: Dictionary = found[id]
			if not slot.has(frame) or fname.length() > String(slot[frame]).get_file().length():
				slot[frame] = full
	_commit_found(found)


static func _scan_pack(found: Array) -> bool:
	var file := FileAccess.open(SHAPES_PACK, FileAccess.READ)
	if file == null:
		return false
	if file.get_buffer(4).get_string_from_ascii() != SHAPES_PACK_MAGIC:
		push_warning("U4TileBank: bad shape pack magic")
		return false
	if file.get_32() != SHAPES_PACK_VERSION:
		push_warning("U4TileBank: unsupported shape pack version")
		return false
	var entry_count := file.get_32()
	for _entry in entry_count:
		var name_size := file.get_16()
		var data_size := file.get_32()
		if name_size <= 0 or data_size <= 0:
			return false
		var fname := file.get_buffer(name_size).get_string_from_utf8()
		var png := file.get_buffer(data_size)
		var parsed := _parse_filename(fname)
		var id: int = parsed.x
		var frame: int = parsed.y
		if id < 0 or id >= COUNT or frame < 0:
			continue
		var img := Image.new()
		if img.load_png_from_buffer(png) != OK:
			push_warning("U4TileBank: bad packed PNG %s" % fname)
			return false
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		var slot: Dictionary = found[id]
		if not slot.has(frame) or fname.length() > str(slot[frame]["path"]).get_file().length():
			slot[frame] = {
				"image": img,
				"path": "%s/%s" % [SHAPES_DIR, fname],
			}
	return true


static func _commit_found(found: Array) -> void:
	for i in COUNT:
		var slot: Dictionary = found[i]
		if slot.is_empty():
			continue
		var max_f := 0
		for k in slot.keys():
			max_f = maxi(max_f, int(k))
		var arr: Array = []
		arr.resize(max_f + 1)
		var ok := true
		for f in max_f + 1:
			if not slot.has(f):
				## Sparse frames — require contiguous 0..n
				ok = false
				break
			var img := _image_from_found(slot[f])
			if img == null:
				ok = false
				break
			arr[f] = img
		if not ok:
			## Fall back to frame 0 only if present.
			if slot.has(0):
				var img0 := _image_from_found(slot[0])
				if img0 != null:
					_frames[i] = [img0]
					_paths[i] = _path_from_found(slot[0])
			continue
		_frames[i] = arr
		_paths[i] = _path_from_found(slot[0])


static func _image_from_found(value: Variant) -> Image:
	if value is Dictionary:
		return value.get("image") as Image
	return _load_path(str(value))


static func _path_from_found(value: Variant) -> String:
	if value is Dictionary:
		return str(value.get("path", ""))
	return str(value)


static func _parse_filename(fname: String) -> Vector2i:
	## Returns (tile_id, frame) or (-1, -1).
	## `049_white_sw_1.png` → (49, 1); `032_mage0.png` → (32, 0).
	if not fname.ends_with(".png") or fname.length() < 7:
		return Vector2i(-1, -1)
	var stem := fname.substr(0, fname.length() - 4)
	var prefix := stem.substr(0, 3)
	if not prefix.is_valid_int():
		return Vector2i(-1, -1)
	var id := prefix.to_int()
	if stem.length() == 3:
		return Vector2i(id, 0)
	if stem[3] != "_":
		return Vector2i(-1, -1)
	var rest := stem.substr(4)
	## Trailing `_N` = animation frame (N >= 1). Bare name / `mage0` = frame 0.
	var us := rest.rfind("_")
	if us >= 0:
		var tail := rest.substr(us + 1)
		if tail.is_valid_int() and tail.to_int() >= 1:
			return Vector2i(id, tail.to_int())
	return Vector2i(id, 0)


static func _fill_missing_from_atlas() -> void:
	var atlas := _load_path(FALLBACK_ATLAS)
	if atlas == null or atlas.is_empty():
		return
	if atlas.get_height() < TILE_SIZE * COUNT:
		push_warning("U4TileBank: fallback atlas too short")
		return
	for i in COUNT:
		var arr: Array = _frames[i]
		if not arr.is_empty():
			continue
		var slice := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
		slice.blit_rect(atlas, Rect2i(0, i * TILE_SIZE, TILE_SIZE, TILE_SIZE), Vector2i.ZERO)
		_frames[i] = [slice]
		_paths[i] = "%s/%03d.png" % [SHAPES_DIR, i]


static func _load_path(path: String) -> Image:
	return _ResImage.load_rgba8(path)
