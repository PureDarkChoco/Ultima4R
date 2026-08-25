class_name U4TileBank
extends RefCounted

## Ultima IV shape bank (id 0..255), with four independent pipelines:
## - New Color: packed PNGs, 8.75:10 display stretch, keyed black + shore masks.
## - Apple II Color: runtime HGR/Mariani NTSC, 8.75:10, continuous map decode.
## - Apple II Mono: native 28×32 PNGs, 8.75:10 display, opaque black.
## - Apple II Mono Green: same native PNGs tinted to sampled green phosphor.
##
## PNG pipelines use files under their active shapes dir:
##   `NNN.png` / `NNN_name.png`     → tile NNN, frame 0
##   `NNN_name_1.png` … `_3.png`   → same tile, extra animation frames
##
## Classic even/odd pairs (`032_mage0.png` + `033_mage1.png`) stay separate
## tile ids. Use `_1` / `_2` / `_3` only when one map byte needs multiple frames
## (e.g. white corner tiles 049–052).

const SET_NEW_COLOR := "new_color"
const SET_APPLE2_COLOR := "apple2_color"
const SET_APPLE2_MONO := "apple2_mono"
const SET_APPLE2_MONO_GREEN := "apple2_mono_green"
const SET_IDS: Array[String] = [
	SET_NEW_COLOR,
	SET_APPLE2_COLOR,
	SET_APPLE2_MONO,
	SET_APPLE2_MONO_GREEN,
]
const DEFAULT_SET := SET_NEW_COLOR

## Keep source/renderer policy explicit; callers query capabilities below instead
## of inferring behavior from a set id.
enum RenderPipeline {
	NEW_COLOR_PNG,
	APPLE2_COLOR_HGR,
	APPLE2_MONO_PNG,
	APPLE2_MONO_GREEN_PNG,
}

const SHAPES_PACK_MAGIC := "U4SP"
const SHAPES_PACK_VERSION := 1
const TILE_SIZE := 32
const COUNT := 256
## All displayed tiles use the Apple II 14×16 (8.75:10) cell geometry.
const DISPLAY_ASPECT_STRETCH := 14.0 / 16.0
const MONO_SOURCE_W := 28
const MONO_SOURCE_H := 32
## Representative bright foreground sampled from the supplied green monitor image.
const MONO_GREEN_R := 128
const MONO_GREEN_G := 253
const MONO_GREEN_B := 165
const _ResImage := preload("res://src/core/res_image.gd")
const _Apple2HgrNtsc := preload("res://src/map/apple2_hgr_ntsc.gd")

## Legacy aliases (New Color / u4graphics). Prefer shapes_dir() / shapes_pack().
const SHAPES_DIR := "res://assets/tiles/u4graphics/shapes"
const FALLBACK_ATLAS := "res://assets/tiles/u4graphics/shapes.png"
const SHAPES_PACK := "res://assets/tiles/u4graphics/shapes.u4pack"
## Apple II Color: runtime-expanded LC tile banks + Mariani LUT (not PNGs / raw .dsk).
const APPLE2_HGR_PACK := "res://assets/tiles/apple2_color/shapes.u4hgr"
const APPLE2_MONO_DIR := "res://assets/tiles/apple2_mono/shapes"
const APPLE2_MONO_PACK := "res://assets/tiles/apple2_mono/shapes.u4pack"

## Array[Array] — outer = tile id, inner = frame Images (at least 1 when ready).
static var _frames: Array = []
## Frame-0 path per tile (for debugging / tools).
static var _paths: PackedStringArray = PackedStringArray()
static var _loaded := false
static var _active_set: String = DEFAULT_SET
static var _mono_green_r := PackedByteArray()
static var _mono_green_g := PackedByteArray()
static var _mono_green_b := PackedByteArray()


static func normalize_set_id(id: String) -> String:
	var s := id.strip_edges().to_lower()
	if s in [
		"apple2_mono_green", "mono_green", "green", "green_mono", "a2_mono_green"
	]:
		return SET_APPLE2_MONO_GREEN
	if s in ["apple2_mono", "apple2_mono_white", "mono", "monochrome", "a2_mono"]:
		return SET_APPLE2_MONO
	if s in ["apple2", "apple_ii", "appleii", "a2", SET_APPLE2_COLOR, "apple2_color"]:
		return SET_APPLE2_COLOR
	if s in ["new", "u4graphics", "modern", SET_NEW_COLOR]:
		return SET_NEW_COLOR
	return DEFAULT_SET


static func active_set() -> String:
	return _active_set


static func render_pipeline(set_id: String = "") -> int:
	match normalize_set_id(set_id if not set_id.is_empty() else _active_set):
		SET_APPLE2_COLOR:
			return RenderPipeline.APPLE2_COLOR_HGR
		SET_APPLE2_MONO:
			return RenderPipeline.APPLE2_MONO_PNG
		SET_APPLE2_MONO_GREEN:
			return RenderPipeline.APPLE2_MONO_GREEN_PNG
		_:
			return RenderPipeline.NEW_COLOR_PNG


static func shapes_dir(set_id: String = "") -> String:
	match normalize_set_id(set_id if not set_id.is_empty() else _active_set):
		SET_APPLE2_COLOR:
			return "res://assets/tiles/apple2_color/shapes"
		SET_APPLE2_MONO, SET_APPLE2_MONO_GREEN:
			return APPLE2_MONO_DIR
		_:
			return SHAPES_DIR


static func shapes_pack(set_id: String = "") -> String:
	match normalize_set_id(set_id if not set_id.is_empty() else _active_set):
		SET_APPLE2_COLOR:
			## PNG pack unused for Apple II Color; HGR pack is the runtime source.
			return ""
		SET_APPLE2_MONO, SET_APPLE2_MONO_GREEN:
			return APPLE2_MONO_PACK
		_:
			return SHAPES_PACK


static func hgr_pack(set_id: String = "") -> String:
	match normalize_set_id(set_id if not set_id.is_empty() else _active_set):
		SET_APPLE2_COLOR:
			return APPLE2_HGR_PACK
		_:
			return ""


static func uses_hgr_ntsc() -> bool:
	return render_pipeline() == RenderPipeline.APPLE2_COLOR_HGR


static func display_aspect() -> float:
	return DISPLAY_ASPECT_STRETCH


static func keeps_opaque_black() -> bool:
	## Apple II Color/Mono: black is ink / CRT, not a chroma key.
	return render_pipeline() != RenderPipeline.NEW_COLOR_PNG


static func uses_moongate_suck() -> bool:
	## Procedural blue/white glow belongs only to the New Color artwork.
	return render_pipeline() == RenderPipeline.NEW_COLOR_PNG


static func fallback_atlas(set_id: String = "") -> String:
	match normalize_set_id(set_id if not set_id.is_empty() else _active_set):
		SET_APPLE2_COLOR, SET_APPLE2_MONO, SET_APPLE2_MONO_GREEN:
			return ""
		_:
			return FALLBACK_ATLAS


static func set_active_set(set_id: String) -> bool:
	## Switch tileset and reload. Returns false if the new set failed to load
	## (previous frames are cleared — caller should fall back if needed).
	var next := normalize_set_id(set_id)
	if next == _active_set and is_ready():
		return true
	_active_set = next
	clear_cache()
	return ensure_loaded()


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
	match render_pipeline():
		RenderPipeline.APPLE2_COLOR_HGR:
			if not _load_apple2_hgr():
				_loaded = false
				return false
			_loaded = true
			return true
		RenderPipeline.NEW_COLOR_PNG, \
		RenderPipeline.APPLE2_MONO_PNG, \
		RenderPipeline.APPLE2_MONO_GREEN_PNG:
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
			push_error("U4TileBank: missing tile %d (%s)" % [i, _active_set])
			_loaded = false
			return false
	return true


static func _load_apple2_hgr() -> bool:
	## Decode expanded LC banks via Mariani NTSC into 32×32 frames for UI / overlays.
	## Explore terrain uses continuous compose in MapView (Apple2HgrNtsc.render_grid).
	_Apple2HgrNtsc.clear_cache()
	if not _Apple2HgrNtsc.ensure_loaded():
		push_error("U4TileBank: Apple II HGR pack failed to load")
		return false
	var ids := PackedInt32Array()
	ids.resize(COUNT)
	for i in COUNT:
		ids[i] = i
	## 16×16 atlas of isolated tiles (correct phase pad per cell).
	var atlas: Image = _Apple2HgrNtsc.render_grid(ids, 16, 16, 0, true)
	if atlas == null or atlas.is_empty():
		push_error("U4TileBank: Apple II atlas decode failed")
		return false
	var cw: int = _Apple2HgrNtsc.OUT_W
	var ch: int = _Apple2HgrNtsc.OUT_H
	for i in COUNT:
		var tx := i % 16
		var ty := i / 16
		var slice := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
		slice.blit_rect(atlas, Rect2i(tx * cw, ty * ch, cw, ch), Vector2i.ZERO)
		if cw != TILE_SIZE or ch != TILE_SIZE:
			slice.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
		_frames[i] = [slice]
		_paths[i] = "%s#%03d" % [APPLE2_HGR_PACK, i]
	return true


static func clear_cache() -> void:
	## Call after replacing files on disk or switching tileset.
	_frames.clear()
	_paths = PackedStringArray()
	_loaded = false
	## Also release a previous Color pipeline when switching away from it.
	_Apple2HgrNtsc.clear_cache()


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
	## New Color: border-connected black → transparent so overlays show underdraw.
	## Apple II Color/Mono: keep opaque black (CRT / scanline ink).
	var src := image(tile_id, frame)
	if src == null:
		return null
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.blit_rect(src, Rect2i(0, 0, TILE_SIZE, TILE_SIZE), Vector2i.ZERO)
	if keeps_opaque_black():
		return img
	var queued := PackedByteArray()
	queued.resize(TILE_SIZE * TILE_SIZE)
	var pending: Array[Vector2i] = []
	for x in TILE_SIZE:
		_queue_border_black(img, Vector2i(x, 0), queued, pending)
		_queue_border_black(img, Vector2i(x, TILE_SIZE - 1), queued, pending)
	for y in range(1, TILE_SIZE - 1):
		_queue_border_black(img, Vector2i(0, y), queued, pending)
		_queue_border_black(img, Vector2i(TILE_SIZE - 1, y), queued, pending)
	while not pending.is_empty():
		var p: Vector2i = pending.pop_back()
		img.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			_queue_border_black(img, p + step, queued, pending)
	return img


static func uses_shore_masks() -> bool:
	## Shore freckles are an explicit New Color compositing feature.
	return render_pipeline() == RenderPipeline.NEW_COLOR_PNG


static func _queue_border_black(
	img: Image, p: Vector2i, queued: PackedByteArray, pending: Array[Vector2i]
) -> void:
	if p.x < 0 or p.y < 0 or p.x >= TILE_SIZE or p.y >= TILE_SIZE:
		return
	var i := p.x + p.y * TILE_SIZE
	if queued[i] != 0:
		return
	queued[i] = 1
	var c := img.get_pixel(p.x, p.y)
	if c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
		pending.append(p)


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
	var dir_path := shapes_dir()
	var names := _ResImage.list_png_names(dir_path)
	if names.is_empty():
		push_warning("U4TileBank: no PNGs under %s" % dir_path)
		return
	for fname in names:
		var parsed := _parse_filename(fname)
		var id: int = parsed.x
		var frame: int = parsed.y
		if id >= 0 and id < COUNT and frame >= 0:
			var full := "%s/%s" % [dir_path, fname]
			var slot: Dictionary = found[id]
			if not slot.has(frame) or fname.length() > String(slot[frame]).get_file().length():
				slot[frame] = full
	_commit_found(found)


static func _scan_pack(found: Array) -> bool:
	var pack_path := shapes_pack()
	var file := FileAccess.open(pack_path, FileAccess.READ)
	if file == null:
		return false
	if file.get_buffer(4).get_string_from_ascii() != SHAPES_PACK_MAGIC:
		push_warning("U4TileBank: bad shape pack magic (%s)" % pack_path)
		return false
	if file.get_32() != SHAPES_PACK_VERSION:
		push_warning("U4TileBank: unsupported shape pack version (%s)" % pack_path)
		return false
	var entry_count := file.get_32()
	var dir_path := shapes_dir()
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
				"path": "%s/%s" % [dir_path, fname],
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
	var img: Image = null
	if value is Dictionary:
		img = value.get("image") as Image
	else:
		img = _load_path(str(value))
	_apply_pipeline_palette(img)
	_normalize_runtime_tile(img)
	return img


static func _apply_pipeline_palette(img: Image) -> void:
	if img == null or img.is_empty():
		return
	if render_pipeline() != RenderPipeline.APPLE2_MONO_GREEN_PNG:
		return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	_ensure_mono_green_lut()
	var data := img.get_data()
	var i := 0
	while i < data.size():
		## Source is grayscale. Preserve its baked scanline luminance while
		## replacing white with the sampled green phosphor color.
		var lum := int(data[i])
		data[i] = _mono_green_r[lum]
		data[i + 1] = _mono_green_g[lum]
		data[i + 2] = _mono_green_b[lum]
		i += 4
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)


static func _ensure_mono_green_lut() -> void:
	if _mono_green_r.size() == 256:
		return
	_mono_green_r.resize(256)
	_mono_green_g.resize(256)
	_mono_green_b.resize(256)
	for lum in 256:
		_mono_green_r[lum] = int(round(float(lum * MONO_GREEN_R) / 255.0))
		_mono_green_g[lum] = int(round(float(lum * MONO_GREEN_G) / 255.0))
		_mono_green_b[lum] = int(round(float(lum * MONO_GREEN_B) / 255.0))


static func _normalize_runtime_tile(img: Image) -> void:
	if img == null or img.is_empty():
		return
	var pipeline := render_pipeline()
	if pipeline not in [
		RenderPipeline.APPLE2_MONO_PNG,
		RenderPipeline.APPLE2_MONO_GREEN_PNG,
	]:
		return
	if img.get_width() != MONO_SOURCE_W or img.get_height() != MONO_SOURCE_H:
		push_warning(
			"U4TileBank: expected mono source %dx%d, got %dx%d"
			% [MONO_SOURCE_W, MONO_SOURCE_H, img.get_width(), img.get_height()]
		)
	## MapView's shared compositor is 32×32 internally; the final 8.75:10 pane
	## mapping restores the native 28×32 display geometry for all layers.
	img.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)


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
	var atlas_path := fallback_atlas()
	if atlas_path.is_empty():
		return
	var atlas := _load_path(atlas_path)
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
