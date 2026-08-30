class_name Apple2HgrNtsc
extends RefCounted

## Runtime Mariani / AppleWin Color-Monitor NTSC for Apple II Ultima IV tiles.
## Loads SHP0/SHP1 (+ hue LUT) from a user:// pack built from the Program .dsk.
## Explore/city terrain: compose a continuous HGR bitfield, then one NTSC pass.

const _Apple2ProgramDisk := preload("res://src/core/apple2_program_disk.gd")
const PACK_PATH := "user://apple2/shapes.u4hgr"
const MAGIC := "U4HG"
const VERSION := 1
const BANK_SIZE := 4096
const TILE_COUNT := 256
const SRC_H := 16
const HALF_PER_BYTE := 14
const OUT_W := 28
const OUT_H := 32
const HUE_BYTES := 4 * 4096 * 3
## Mild analog bandwidth after NTSC. No extra chroma (LUT already fringes).
const SMEAR_TAP1 := 1
const SMEAR_TAP2 := 2
const SMEAR_WC := 192
const SMEAR_W1 := 27
const SMEAR_W2 := 5

static var _loaded := false
static var _shp0 := PackedByteArray()
static var _shp1 := PackedByteArray()
static var _hue := PackedInt32Array()
static var _masks := PackedInt32Array()
static var _xmap32 := PackedInt32Array()

static var _scratch_rgba := PackedByteArray()
static var _cache_img: Image
static var _cache_ids := PackedInt32Array()
static var _cache_cols := 0
static var _cache_rows := 0
static var _cache_dst := 0
static var _cache_scroll := -1
static var _cache_isolated := false


static func is_ready() -> bool:
	return _loaded and _shp0.size() == BANK_SIZE and _shp1.size() == BANK_SIZE


static func shp0() -> PackedByteArray:
	return _shp0


static func shp1() -> PackedByteArray:
	return _shp1


static func ensure_loaded() -> bool:
	if is_ready():
		return true
	return _load_pack()


static func clear_cache() -> void:
	_loaded = false
	_shp0 = PackedByteArray()
	_shp1 = PackedByteArray()
	_hue = PackedInt32Array()
	_masks = PackedInt32Array()
	_cache_img = null
	_cache_ids = PackedInt32Array()
	_cache_cols = 0
	_cache_rows = 0
	_cache_dst = 0
	_cache_scroll = -1


static func _load_pack() -> bool:
	clear_cache()
	if not _Apple2ProgramDisk.pack_is_ready():
		push_error("Apple2HgrNtsc: missing Program-disk tile cache")
		return false
	var f := FileAccess.open(PACK_PATH, FileAccess.READ)
	if f == null:
		push_error("Apple2HgrNtsc: missing %s" % PACK_PATH)
		return false
	var mag := f.get_buffer(4).get_string_from_ascii()
	if mag != MAGIC:
		push_error("Apple2HgrNtsc: bad magic")
		return false
	if f.get_32() != VERSION:
		push_error("Apple2HgrNtsc: bad version")
		return false
	_shp0 = f.get_buffer(BANK_SIZE)
	_shp1 = f.get_buffer(BANK_SIZE)
	var hue_raw := f.get_buffer(HUE_BYTES)
	if _shp0.size() != BANK_SIZE or _shp1.size() != BANK_SIZE or hue_raw.size() != HUE_BYTES:
		push_error("Apple2HgrNtsc: truncated pack")
		clear_cache()
		return false
	## Stock Program SHP leaves energy/fire/sleep blank; LC RAM fills them
	## from the poison pattern (palette bit + L/R swap). Apply that here so
	## an already-cached pack still gets the four HGR field colors.
	var fields: Array = _Apple2ProgramDisk.expand_derived_field_tiles(_shp0, _shp1)
	_shp0 = fields[0]
	_shp1 = fields[1]
	_hue.resize(4 * 4096)
	for i in range(4 * 4096):
		var o := i * 3
		_hue[i] = (int(hue_raw[o]) << 16) | (int(hue_raw[o + 1]) << 8) | int(hue_raw[o + 2])
	_masks.resize(128)
	for byte_i in range(128):
		var m := 0
		for bit in range(7):
			if byte_i & (1 << bit):
				m |= 3 << (bit * 2)
		_masks[byte_i] = m
	_xmap32.resize(32)
	for x in range(32):
		_xmap32[x] = int(round(float(x) * 27.0 / 31.0))
	_loaded = true
	return true


static func bank_byte(left: bool, scan_y: int, tile_id: int) -> int:
	var tid := clampi(tile_id, 0, TILE_COUNT - 1)
	var y := posmod(scan_y, SRC_H)
	var i := y * TILE_COUNT + tid
	if left:
		return int(_shp0[i])
	return int(_shp1[i])


static func render_flying_tile(tile_id: int) -> Image:
	## Isolated missile with 2 extra dest columns so delayed NTSC bits stay visible.
	if not ensure_loaded():
		return null
	var tid := clampi(tile_id, 0, TILE_COUNT - 1)
	var fringe := 2
	var out_w := 32 + fringe
	var row_half := PackedInt32Array()
	row_half.resize(OUT_W + HALF_PER_BYTE)
	var bright := PackedByteArray()
	bright.resize(out_w * SRC_H * 4)
	var row_bytes := out_w * 4
	var ids := PackedInt32Array()
	ids.append(tid)
	var st := PackedInt32Array([0, 0, 0])
	for sy in range(SRC_H):
		_decode_isolated_row(ids, 1, 0, sy, 0, row_half, st)
		var base := sy * row_bytes
		for x in range(32):
			var src_i := int(_xmap32[x])
			_write_half_pixel(bright, base + x * 4, int(row_half[src_i]), false)
		for f in range(fringe):
			var src_i := OUT_W + f
			if src_i >= row_half.size():
				src_i = OUT_W - 1
			_write_half_pixel(bright, base + (32 + f) * 4, int(row_half[src_i]), false)
	var data := PackedByteArray()
	data.resize(out_w * 32 * 4)
	var stride := out_w * 4
	for sy2 in range(SRC_H):
		var src_off := sy2 * stride
		var d0 := (sy2 * 2) * stride
		var d1 := d0 + stride
		for i in stride:
			data[d0 + i] = bright[src_off + i]
			if (i & 3) == 3:
				data[d1 + i] = bright[src_off + i]
			else:
				data[d1 + i] = (int(bright[src_off + i]) & 0xFC) >> 2
	return Image.create_from_data(out_w, 32, false, Image.FORMAT_RGBA8, data)


static func _write_half_pixel(rgba: PackedByteArray, d: int, c: int, dim: bool) -> void:
	var r := (c >> 16) & 0xFF
	var g := (c >> 8) & 0xFF
	var b := c & 0xFF
	if dim:
		r = (r & 0xFC) >> 2
		g = (g & 0xFC) >> 2
		b = (b & 0xFC) >> 2
	rgba[d] = r
	rgba[d + 1] = g
	rgba[d + 2] = b
	rgba[d + 3] = 255


static func render_tile_isolated(tile_id: int, scroll_y: int = 0) -> Image:
	if not ensure_loaded():
		return null
	var ids := PackedInt32Array()
	ids.append(clampi(tile_id, 0, TILE_COUNT - 1))
	return render_grid(ids, 1, 1, scroll_y, true)


static func render_grid(
	tile_ids: PackedInt32Array,
	cols: int,
	rows: int,
	scroll_y: int = 0,
	isolated_tiles: bool = false
) -> Image:
	return _render_cells(tile_ids, cols, rows, OUT_W, OUT_H, scroll_y, isolated_tiles, false)


static func render_grid_scaled(
	tile_ids: PackedInt32Array,
	cols: int,
	rows: int,
	dst_cell: int,
	scroll_y: int = 0,
	isolated_tiles: bool = false
) -> Image:
	## Fast MapView path: NTSC at 28×16 (no scanline double), then native resize
	## to dst_cell and Mariani-dim odd rows. Cuts pixel writes ~2× vs inline 32×32.
	if dst_cell == 32 and not isolated_tiles:
		return _render_fast_scaled(tile_ids, cols, rows, scroll_y)
	if dst_cell == 32:
		return _render_cells(tile_ids, cols, rows, 32, 32, scroll_y, isolated_tiles, true)
	if dst_cell == OUT_W:
		return render_grid(tile_ids, cols, rows, scroll_y, isolated_tiles)
	var native := render_grid(tile_ids, cols, rows, scroll_y, isolated_tiles)
	if native == null:
		return null
	native.resize(cols * dst_cell, rows * dst_cell, Image.INTERPOLATE_NEAREST)
	return native


static func _render_fast_scaled(
	tile_ids: PackedInt32Array, cols: int, rows: int, scroll_y: int
) -> Image:
	if not ensure_loaded() or cols < 1 or rows < 1:
		return null
	if tile_ids.size() < cols * rows:
		return null
	var out_w := cols * 32
	var out_h := rows * 32
	if (
		_cache_img != null
		and not _cache_img.is_empty()
		and _cache_cols == cols
		and _cache_rows == rows
		and _cache_dst == 32
		and _cache_scroll == scroll_y
		and _cache_isolated == false
		and _cache_img.get_width() == out_w
		and _cache_img.get_height() == out_h
		and _ids_equal(tile_ids, _cache_ids)
	):
		return _cache_img

	var scroll_only := (
		_cache_img != null
		and not _cache_img.is_empty()
		and _cache_cols == cols
		and _cache_rows == rows
		and _cache_dst == 32
		and _cache_isolated == false
		and _cache_scroll != scroll_y
		and _cache_img.get_width() == out_w
		and _cache_img.get_height() == out_h
		and _ids_equal(tile_ids, _cache_ids)
	)

	var dirty := PackedInt32Array()
	if scroll_only:
		for ty in range(rows):
			if _row_has_y_scroll(tile_ids, cols, ty):
				dirty.append(ty)
		if dirty.is_empty():
			_cache_scroll = scroll_y
			return _cache_img
	else:
		dirty.resize(rows)
		for ty in range(rows):
			dirty[ty] = ty
		if (
			_cache_img == null
			or _cache_img.get_width() != out_w
			or _cache_img.get_height() != out_h
		):
			_cache_img = Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)

	## Decode dirty tile-rows (optionally in parallel).
	var strips: Array = []
	strips.resize(rows)
	var use_threads := dirty.size() >= 4 and OS.get_processor_count() > 2
	if use_threads:
		var tasks := PackedInt32Array()
		for di in dirty.size():
			var ty: int = dirty[di]
			tasks.append(
				WorkerThreadPool.add_task(
					_fill_fast_strip.bind(tile_ids, cols, ty, scroll_y, strips)
				)
			)
		for i in tasks.size():
			WorkerThreadPool.wait_for_task_completion(int(tasks[i]))
	else:
		for di in dirty.size():
			var ty2: int = dirty[di]
			_fill_fast_strip(tile_ids, cols, ty2, scroll_y, strips)

	for di in dirty.size():
		var ty3: int = dirty[di]
		var strip: Image = strips[ty3]
		if strip == null or strip.is_empty():
			continue
		_cache_img.blit_rect(strip, Rect2i(0, 0, out_w, 32), Vector2i(0, ty3 * 32))

	if not _ids_equal(tile_ids, _cache_ids):
		_cache_ids = tile_ids.duplicate()
	_cache_cols = cols
	_cache_rows = rows
	_cache_dst = 32
	_cache_scroll = scroll_y
	_cache_isolated = false
	return _cache_img


static func render_uncached(
	tile_ids: PackedInt32Array, cols: int, rows: int, scroll_y: int = 0
) -> Image:
	## Small continuous strip that must not touch the explore-view cache.
	if not ensure_loaded() or cols < 1 or rows < 1:
		return null
	if tile_ids.size() < cols * rows:
		return null
	var out_w := cols * 32
	var out_h := rows * 32
	var img := Image.create(out_w, out_h, false, Image.FORMAT_RGBA8)
	var strips: Array = []
	strips.resize(rows)
	for ty in rows:
		_fill_fast_strip(tile_ids, cols, ty, scroll_y, strips)
		var strip: Image = strips[ty]
		if strip == null or strip.is_empty():
			continue
		img.blit_rect(strip, Rect2i(0, 0, out_w, 32), Vector2i(0, ty * 32))
	return img


static func _fill_fast_strip(
	tile_ids: PackedInt32Array, cols: int, ty: int, scroll_y: int, strips: Array
) -> void:
	var src_w := cols * OUT_W
	var out_w := cols * 32
	var row_half := PackedInt32Array()
	row_half.resize(src_w + OUT_W)
	var st := PackedInt32Array([0, 0, 0])
	var bright := PackedByteArray()
	bright.resize(out_w * SRC_H * 4)
	var row_bytes := out_w * 4
	for sy in range(SRC_H):
		_decode_continuous_row(tile_ids, cols, ty, sy, scroll_y, row_half, st)
		_blit_half_row(bright, row_bytes, sy, src_w, out_w, true, false, row_half)
	var data := PackedByteArray()
	data.resize(out_w * 32 * 4)
	var stride := out_w * 4
	for sy2 in range(SRC_H):
		var src_off := sy2 * stride
		var d0 := (sy2 * 2) * stride
		var d1 := d0 + stride
		for i in stride:
			data[d0 + i] = bright[src_off + i]
			if (i & 3) == 3:
				data[d1 + i] = bright[src_off + i]
			else:
				data[d1 + i] = (int(bright[src_off + i]) & 0xFC) >> 2
	strips[ty] = Image.create_from_data(out_w, 32, false, Image.FORMAT_RGBA8, data)


static func _render_cells(
	tile_ids: PackedInt32Array,
	cols: int,
	rows: int,
	cell_w: int,
	cell_h: int,
	scroll_y: int,
	isolated_tiles: bool,
	use_xmap32: bool
) -> Image:
	if not ensure_loaded() or cols < 1 or rows < 1 or cell_w < 1 or cell_h < 1:
		return null
	if tile_ids.size() < cols * rows:
		return null

	var out_w := cols * cell_w
	var out_h := rows * cell_h
	if (
		_cache_img != null
		and not _cache_img.is_empty()
		and _cache_cols == cols
		and _cache_rows == rows
		and _cache_dst == cell_w
		and _cache_scroll == scroll_y
		and _cache_isolated == isolated_tiles
		and _cache_img.get_width() == out_w
		and _cache_img.get_height() == out_h
		and _ids_equal(tile_ids, _cache_ids)
	):
		return _cache_img

	var scroll_only := (
		not isolated_tiles
		and _cache_img != null
		and not _cache_img.is_empty()
		and _cache_cols == cols
		and _cache_rows == rows
		and _cache_dst == cell_w
		and _cache_isolated == isolated_tiles
		and _cache_scroll != scroll_y
		and _cache_img.get_width() == out_w
		and _cache_img.get_height() == out_h
		and _ids_equal(tile_ids, _cache_ids)
	)

	var need := out_w * out_h * 4
	if _scratch_rgba.size() != need:
		_scratch_rgba.resize(need)
	if scroll_only:
		_scratch_rgba = _cache_img.get_data()
		if _scratch_rgba.size() != need:
			scroll_only = false
			_scratch_rgba.resize(need)

	var dirty := PackedInt32Array()
	if scroll_only:
		for ty in range(rows):
			if _row_has_y_scroll(tile_ids, cols, ty):
				dirty.append(ty)
		if dirty.is_empty():
			_cache_scroll = scroll_y
			return _cache_img
	else:
		dirty.resize(rows)
		for ty in range(rows):
			dirty[ty] = ty

	## Single-threaded fast path: no Array returns in the NTSC inner loop.
	var half_w := cols * OUT_W
	var row_half := PackedInt32Array()
	row_half.resize(half_w + OUT_W)
	## Mutable NTSC state: [sig, phase, last_col]
	var st := PackedInt32Array([0, 0, 0])
	var row_bytes := out_w * 4

	for di in dirty.size():
		var ty: int = dirty[di]
		for sy in range(SRC_H):
			if isolated_tiles:
				_decode_isolated_row(tile_ids, cols, ty, sy, scroll_y, row_half, st)
			else:
				_decode_continuous_row(tile_ids, cols, ty, sy, scroll_y, row_half, st)
			var y0 := ty * cell_h + sy * 2
			_blit_half_row(
				_scratch_rgba, row_bytes, y0, half_w, out_w, use_xmap32, false, row_half
			)
			if y0 + 1 < out_h:
				_blit_half_row(
					_scratch_rgba, row_bytes, y0 + 1, half_w, out_w, use_xmap32, true, row_half
				)
		if isolated_tiles:
			_smear_rgba_cells(_scratch_rgba, out_w, ty * cell_h, cell_h, cell_w)

	if (
		_cache_img == null
		or _cache_img.get_width() != out_w
		or _cache_img.get_height() != out_h
	):
		_cache_img = Image.create_from_data(out_w, out_h, false, Image.FORMAT_RGBA8, _scratch_rgba)
	else:
		_cache_img.set_data(out_w, out_h, false, Image.FORMAT_RGBA8, _scratch_rgba)

	if not _ids_equal(tile_ids, _cache_ids):
		_cache_ids = tile_ids.duplicate()
	_cache_cols = cols
	_cache_rows = rows
	_cache_dst = cell_w
	_cache_scroll = scroll_y
	_cache_isolated = isolated_tiles
	return _cache_img


static func _decode_continuous_row(
	tile_ids: PackedInt32Array,
	cols: int,
	ty: int,
	sy: int,
	scroll_y: int,
	row_half: PackedInt32Array,
	st: PackedInt32Array
) -> void:
	st[0] = 0
	st[1] = 0
	st[2] = 0
	_ntsc_step(0x00, st, row_half, -1)
	var ox := 0
	var row_base := ty * cols
	for tx in range(cols):
		var tid: int = tile_ids[row_base + tx]
		var src_y := _src_y_for_tile(tid, sy, scroll_y)
		var idx := src_y * TILE_COUNT + tid
		_ntsc_step(int(_shp0[idx]), st, row_half, ox)
		ox += HALF_PER_BYTE
		_ntsc_step(int(_shp1[idx]), st, row_half, ox)
		ox += HALF_PER_BYTE
	## Delayed NTSC bits after the last tile — otherwise the row's right edge dies.
	_ntsc_step(0x00, st, row_half, ox)


static func _decode_isolated_row(
	tile_ids: PackedInt32Array,
	cols: int,
	ty: int,
	sy: int,
	scroll_y: int,
	row_half: PackedInt32Array,
	st: PackedInt32Array
) -> void:
	var ox := 0
	var row_base := ty * cols
	for tx in range(cols):
		var tid: int = tile_ids[row_base + tx]
		var src_y := _src_y_for_tile(tid, sy, scroll_y)
		var idx := src_y * TILE_COUNT + tid
		var bl := int(_shp0[idx])
		var br := int(_shp1[idx])
		st[0] = 0
		st[1] = 0
		st[2] = 0
		_ntsc_step(0x00, st, row_half, -1)
		_ntsc_step(bl, st, row_half, ox)
		_ntsc_step(br, st, row_half, ox + HALF_PER_BYTE)
		_ntsc_step(0x00, st, row_half, ox + OUT_W)
		if (bl | br) & 0x80:
			for i in range(OUT_W - 1):
				row_half[ox + i] = row_half[ox + i + 1]
			row_half[ox + OUT_W - 1] = row_half[ox + OUT_W]
		ox += OUT_W


static func _ntsc_step(
	m: int, st: PackedInt32Array, row_half: PackedInt32Array, ox: int
) -> void:
	var bits: int = int(_masks[m & 0x7F])
	if m & 0x80:
		bits = (bits << 1) | int(st[2])
	var ns_sig: int = st[0]
	var ns_phase: int = st[1]
	for i in range(HALF_PER_BYTE):
		var bit := bits & 1
		if i < HALF_PER_BYTE - 1:
			bits >>= 1
		ns_sig = ((ns_sig << 1) | bit) & 0xFFF
		if ox >= 0:
			row_half[ox + i] = int(_hue[ns_phase * 4096 + ns_sig])
		ns_phase = (ns_phase + 1) & 3
	st[0] = ns_sig
	st[1] = ns_phase
	st[2] = bits & 1


static func _blit_half_row(
	rgba: PackedByteArray,
	row_bytes: int,
	y: int,
	half_w: int,
	out_w: int,
	use_xmap32: bool,
	dim_scanline: bool,
	row_half: PackedInt32Array
) -> void:
	var base := y * row_bytes
	if use_xmap32:
		var tiles := out_w >> 5
		for t in range(tiles):
			var half_base := t * OUT_W
			var dst_base := base + t * 32 * 4
			for x in range(32):
				var src_i := int(_xmap32[x])
				## Last dest column of the last tile: keep the delayed NTSC bit.
				if t == tiles - 1 and x == 31 and half_base + 28 < row_half.size():
					src_i = 28
				var c: int = int(row_half[half_base + src_i])
				var r := (c >> 16) & 0xFF
				var g := (c >> 8) & 0xFF
				var b := c & 0xFF
				if dim_scanline:
					r = (r & 0xFC) >> 2
					g = (g & 0xFC) >> 2
					b = (b & 0xFC) >> 2
				var d := dst_base + x * 4
				rgba[d] = r
				rgba[d + 1] = g
				rgba[d + 2] = b
				rgba[d + 3] = 255
	else:
		var n := mini(half_w, out_w)
		for x in range(n):
			var c: int = int(row_half[x])
			var r := (c >> 16) & 0xFF
			var g := (c >> 8) & 0xFF
			var b := c & 0xFF
			if dim_scanline:
				r = (r & 0xFC) >> 2
				g = (g & 0xFC) >> 2
				b = (b & 0xFC) >> 2
			var d := base + x * 4
			rgba[d] = r
			rgba[d + 1] = g
			rgba[d + 2] = b
			rgba[d + 3] = 255


static func _row_has_y_scroll(tile_ids: PackedInt32Array, cols: int, ty: int) -> bool:
	var base := ty * cols
	for tx in range(cols):
		if _tile_y_scrolls(int(tile_ids[base + tx])):
			return true
	return false


static func _smear_rgba_cells(
	data: PackedByteArray, w: int, y0: int, rows: int, cell_w: int
) -> void:
	## Isolated tiles only. Local row buffer — never shared across worker threads.
	if data.is_empty() or w < 1 or rows < 1 or cell_w < 1:
		return
	var stride := w * 4
	var smear_row := PackedByteArray()
	smear_row.resize(stride)
	var y := y0
	var y_end := y0 + rows
	while y < y_end:
		var row := y * stride
		if row + stride > data.size():
			break
		for i in stride:
			smear_row[i] = data[row + i]
		var x := 0
		while x < w:
			var c0 := (x / cell_w) * cell_w
			var c1 := mini(c0 + cell_w, w) - 1
			var i := x * 4
			var il1 := clampi(x - SMEAR_TAP1, c0, c1) * 4
			var ir1 := clampi(x + SMEAR_TAP1, c0, c1) * 4
			var il2 := clampi(x - SMEAR_TAP2, c0, c1) * 4
			var ir2 := clampi(x + SMEAR_TAP2, c0, c1) * 4
			data[row + i] = (
				int(smear_row[i]) * SMEAR_WC
				+ (int(smear_row[il1]) + int(smear_row[ir1])) * SMEAR_W1
				+ (int(smear_row[il2]) + int(smear_row[ir2])) * SMEAR_W2
			) >> 8
			data[row + i + 1] = (
				int(smear_row[i + 1]) * SMEAR_WC
				+ (int(smear_row[il1 + 1]) + int(smear_row[ir1 + 1])) * SMEAR_W1
				+ (int(smear_row[il2 + 1]) + int(smear_row[ir2 + 1])) * SMEAR_W2
			) >> 8
			data[row + i + 2] = (
				int(smear_row[i + 2]) * SMEAR_WC
				+ (int(smear_row[il1 + 2]) + int(smear_row[ir1 + 2])) * SMEAR_W1
				+ (int(smear_row[il2 + 2]) + int(smear_row[ir2 + 2])) * SMEAR_W2
			) >> 8
			x += 1
		y += 1


static func _ids_equal(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	var n := a.size()
	if n != b.size():
		return false
	for i in range(n):
		if a[i] != b[i]:
			return false
	return true


static func _tile_y_scrolls(tid: int) -> bool:
	if tid >= 0 and tid <= 2:
		return true
	if tid >= 68 and tid <= 71:
		return true
	return tid == 76


static func _src_y_for_tile(tid: int, sy: int, scroll_y: int) -> int:
	if scroll_y == 0 or not _tile_y_scrolls(tid):
		return sy
	return posmod(sy - scroll_y, SRC_H)
