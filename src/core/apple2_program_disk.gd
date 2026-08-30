class_name Apple2ProgramDisk
extends RefCounted

## Ultima IV Apple II Program disk (Side A) — DOS 3.3 SHP0 / SHP1.
## Britannia / Towne / Dungeon sides have no shape banks.

const DSK_SIZE := 143360
const BANK_SIZE := 4096
const TILE_COUNT := 256
const SRC_W := 14
const SRC_H := 16
const MONO_W := 28
const MONO_H := 32
const MONO_DIM := 63 ## Mariani half-scanline: (255 & 0xFC) >> 2
const CACHE_DIR := "user://apple2"
const PACK_PATH := "user://apple2/shapes.u4hgr"
const HUE_PATH := "user://apple2/hue_monitor.bin"
const PACK_MAGIC := "U4HG"
const PACK_VERSION := 1
const HUE_BYTES := 4 * 4096 * 3

const CHROMA_GAIN := 7.438011255
const CHROMA_0 := -0.7318893645
const CHROMA_1 := 1.2336442711
const LUMA_GAIN := 13.71331570
const LUMA_0 := -0.3961075449
const LUMA_1 := 1.1044202472
const SIGNAL_GAIN := 7.614490548
const SIGNAL_0 := -0.2718798058
const SIGNAL_1 := 0.7465656072
const I_TO_R := 0.956
const I_TO_G := -0.272
const I_TO_B := -1.105
const Q_TO_R := 0.621
const Q_TO_G := -0.647
const Q_TO_B := 1.702


static func dsk_file_key(path: String) -> String:
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	return "%s:%d:%d" % [path, _file_len(path), FileAccess.get_modified_time(path)]


static func _file_len(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var n := int(f.get_length())
	f.close()
	return n


static func is_dsk_image(path: String) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	return _file_len(path) == DSK_SIZE


static func catalog_names(path: String) -> PackedStringArray:
	var dsk := _read_dsk(path)
	if dsk.is_empty():
		return PackedStringArray()
	var names := PackedStringArray()
	for row in _catalog_files(dsk):
		names.append(str(row["name"]))
	return names


static func looks_like_program_dsk(path: String) -> bool:
	return not find_shp_ts(path).is_empty()


static func find_shp_ts(path: String) -> Dictionary:
	## { "SHP0": Vector2i(t,s), "SHP1": Vector2i(t,s) } or empty.
	var dsk := _read_dsk(path)
	if dsk.is_empty():
		return {}
	var out := {}
	for row in _catalog_files(dsk):
		var key := _shp_key(str(row["name"]))
		if key.is_empty():
			continue
		out[key] = Vector2i(int(row["t"]), int(row["s"]))
	if out.has("SHP0") and out.has("SHP1"):
		return out
	return {}


static func extract_banks(path: String) -> Array:
	## [shp0, shp1] PackedByteArray, or empty Array on failure.
	var dsk := _read_dsk(path)
	if dsk.is_empty():
		return []
	var loc := {}
	for row in _catalog_files(dsk):
		var key := _shp_key(str(row["name"]))
		if key.is_empty():
			continue
		loc[key] = Vector2i(int(row["t"]), int(row["s"]))
	if not loc.has("SHP0") or not loc.has("SHP1"):
		return []
	var shp0 := _binary_payload(_read_dos33_file(dsk, loc["SHP0"].x, loc["SHP0"].y))
	var shp1 := _binary_payload(_read_dos33_file(dsk, loc["SHP1"].x, loc["SHP1"].y))
	if shp0.size() != BANK_SIZE or shp1.size() != BANK_SIZE:
		return []
	return expand_derived_field_tiles(shp0, shp1)


static func expand_derived_field_tiles(shp0: PackedByteArray, shp1: PackedByteArray) -> Array:
	## Stock SHP0/SHP1 store one field pattern (tile 68) and leave 69–71 blank.
	## Language-card setup copies that pattern into energy/fire/sleep by
	## toggling the HGR high bit (green/purple ↔ orange/blue) and swapping
	## the left/right bytes (complementary color). 4am LC dumps already have
	## all four filled — leave those alone.
	if shp0.size() != BANK_SIZE or shp1.size() != BANK_SIZE:
		return [shp0, shp1]
	if (
		_tile_has_ink(shp0, shp1, 69)
		and _tile_has_ink(shp0, shp1, 70)
		and _tile_has_ink(shp0, shp1, 71)
	):
		return [shp0, shp1]
	var src := -1
	for tid in range(68, 72):
		if _tile_has_ink(shp0, shp1, tid):
			src = tid
			break
	if src < 0:
		return [shp0, shp1]
	for y in SRC_H:
		var i := y * TILE_COUNT + src
		var bl := int(shp0[i]) & 0x7F
		var br := int(shp1[i]) & 0x7F
		var o68 := y * TILE_COUNT + 68
		var o69 := y * TILE_COUNT + 69
		var o70 := y * TILE_COUNT + 70
		var o71 := y * TILE_COUNT + 71
		shp0[o68] = bl
		shp1[o68] = br
		shp0[o69] = br | 0x80
		shp1[o69] = bl | 0x80
		shp0[o70] = bl | 0x80
		shp1[o70] = br | 0x80
		shp0[o71] = br
		shp1[o71] = bl
	return [shp0, shp1]


static func _tile_has_ink(shp0: PackedByteArray, shp1: PackedByteArray, tid: int) -> bool:
	for y in SRC_H:
		var i := y * TILE_COUNT + tid
		if int(shp0[i]) != 0 or int(shp1[i]) != 0:
			return true
	return false


static func pack_is_ready() -> bool:
	return FileAccess.file_exists(PACK_PATH) and _file_len(PACK_PATH) >= 8 + BANK_SIZE * 2 + HUE_BYTES


static func ensure_pack_from_dsk(path: String, cache_key: String = "") -> bool:
	if path.is_empty() or not looks_like_program_dsk(path):
		return false
	var key := cache_key if not cache_key.is_empty() else dsk_file_key(path)
	if pack_is_ready() and _load_cache_key() == key:
		return true
	var banks := extract_banks(path)
	if banks.size() != 2:
		return false
	return write_pack(banks[0], banks[1], key)


static func write_pack(shp0: PackedByteArray, shp1: PackedByteArray, cache_key: String) -> bool:
	if shp0.size() != BANK_SIZE or shp1.size() != BANK_SIZE:
		return false
	var hue := _ensure_hue_lut()
	if hue.size() != HUE_BYTES:
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
	var f := FileAccess.open(PACK_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Apple2ProgramDisk: cannot write %s" % PACK_PATH)
		return false
	f.store_buffer(PACK_MAGIC.to_ascii_buffer())
	f.store_32(PACK_VERSION)
	f.store_buffer(shp0)
	f.store_buffer(shp1)
	f.store_buffer(hue)
	f.close()
	_save_cache_key(cache_key)
	return true


static func clear_pack() -> void:
	if FileAccess.file_exists(PACK_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PACK_PATH))
	var meta := CACHE_DIR.path_join("cache.cfg")
	if FileAccess.file_exists(meta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(meta))


static func render_mono_tile(shp0: PackedByteArray, shp1: PackedByteArray, tile_id: int) -> Image:
	var img := Image.create(MONO_W, MONO_H, false, Image.FORMAT_RGBA8)
	var tid := clampi(tile_id, 0, TILE_COUNT - 1)
	for src_y in SRC_H:
		var bl := int(shp0[src_y * TILE_COUNT + tid])
		var br := int(shp1[src_y * TILE_COUNT + tid])
		for src_x in SRC_W:
			var byte_v := bl if src_x < 7 else br
			var bit := src_x if src_x < 7 else src_x - 7
			var on := (byte_v >> bit) & 1
			var bright := 255 if on else 0
			var dim := MONO_DIM if on else 0
			for dx in 2:
				img.set_pixel(src_x * 2 + dx, src_y * 2, Color8(bright, bright, bright, 255))
				img.set_pixel(src_x * 2 + dx, src_y * 2 + 1, Color8(dim, dim, dim, 255))
	return img


static func _shp_key(name: String) -> String:
	var n := name.strip_edges().to_upper()
	if n == "SHP0" or n.begins_with("SHP0"):
		return "SHP0"
	if n == "SHP1" or n.begins_with("SHP1"):
		return "SHP1"
	return ""


static func _read_dsk(path: String) -> PackedByteArray:
	if not is_dsk_image(path):
		return PackedByteArray()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var dsk := f.get_buffer(DSK_SIZE)
	f.close()
	if dsk.size() != DSK_SIZE:
		return PackedByteArray()
	return dsk


static func _dsk_ts_offset(track: int, sector: int) -> int:
	return track * 16 * 256 + sector * 256


static func _catalog_files(dsk: PackedByteArray) -> Array:
	var files: Array = []
	var track := 17
	var sector := 15
	var seen: Dictionary = {}
	while track != 0:
		var key := track * 16 + sector
		if seen.has(key):
			break
		seen[key] = true
		var off := _dsk_ts_offset(track, sector)
		if off + 256 > dsk.size():
			break
		var next_t := int(dsk[off + 1])
		var next_s := int(dsk[off + 2])
		for i in 7:
			var e := off + 0x0B + i * 35
			var ftype := int(dsk[e + 2])
			if ftype == 0x00 or ftype == 0xFF:
				continue
			var chars := PackedStringArray()
			for j in 30:
				var b := int(dsk[e + 3 + j])
				var c := b & 0x7F
				if j == 1 and c == 0x01:
					continue
				if c >= 32 and c < 127:
					chars.append(String.chr(c))
			var name := "".join(chars).rstrip(" ")
			files.append({
				"name": name,
				"t": int(dsk[e]),
				"s": int(dsk[e + 1]),
			})
		track = next_t
		sector = next_s
	return files


static func _read_dos33_file(dsk: PackedByteArray, start_t: int, start_s: int) -> PackedByteArray:
	var data := PackedByteArray()
	var t := start_t
	var s := start_s
	var seen: Dictionary = {}
	while t != 0:
		var key := t * 16 + s
		if seen.has(key):
			break
		seen[key] = true
		var off := _dsk_ts_offset(t, s)
		if off + 256 > dsk.size():
			break
		var next_t := int(dsk[off + 1])
		var next_s := int(dsk[off + 2])
		var i := 0x0C
		while i < 254:
			var dt := int(dsk[off + i])
			var ds := int(dsk[off + i + 1])
			i += 2
			if dt == 0:
				break
			var data_off := _dsk_ts_offset(dt, ds)
			if data_off + 256 <= dsk.size():
				data.append_array(dsk.slice(data_off, data_off + 256))
		t = next_t
		s = next_s
	return data


static func _binary_payload(raw: PackedByteArray) -> PackedByteArray:
	if raw.size() < 4:
		return PackedByteArray()
	var load := int(raw[0]) | (int(raw[1]) << 8)
	var length := int(raw[2]) | (int(raw[3]) << 8)
	if load == 0xD000 and length == BANK_SIZE and raw.size() >= 4 + BANK_SIZE:
		return raw.slice(4, 4 + BANK_SIZE)
	if raw.size() >= BANK_SIZE:
		return raw.slice(0, BANK_SIZE)
	return PackedByteArray()


static func _load_cache_key() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(CACHE_DIR.path_join("cache.cfg")) != OK:
		return ""
	return str(cfg.get_value("pack", "dsk_key", "")).strip_edges()


static func _save_cache_key(key: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("pack", "dsk_key", key)
	cfg.save(CACHE_DIR.path_join("cache.cfg"))


static func _ensure_hue_lut() -> PackedByteArray:
	if FileAccess.file_exists(HUE_PATH) and _file_len(HUE_PATH) == HUE_BYTES:
		var hf := FileAccess.open(HUE_PATH, FileAccess.READ)
		if hf != null:
			var cached := hf.get_buffer(HUE_BYTES)
			hf.close()
			if cached.size() == HUE_BYTES:
				return cached
	var hue := _build_hue_monitor()
	if hue.size() == HUE_BYTES:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
		var wf := FileAccess.open(HUE_PATH, FileAccess.WRITE)
		if wf != null:
			wf.store_buffer(hue)
			wf.close()
	return hue


static func _build_hue_monitor() -> PackedByteArray:
	## AppleWin Color Monitor hue LUT (same coefficients as tools/build_a2_u4_color_composite.py).
	var out := PackedByteArray()
	out.resize(HUE_BYTES)
	var pi := PI
	var rad_45 := pi * 0.25
	var rad_90 := pi * 0.5
	var cycle_start := deg_to_rad(45.0)
	var i := 0
	var sig := _Biquad.new(SIGNAL_GAIN, SIGNAL_0, SIGNAL_1, false)
	var chroma := _Biquad.new(CHROMA_GAIN, CHROMA_0, CHROMA_1, true)
	var luma := _Biquad.new(LUMA_GAIN, LUMA_0, LUMA_1, false)
	for phase in 4:
		var phi := float(phase) * rad_90 + cycle_start
		for s in 4096:
			var t := s
			var y0 := 0.0
			var ii := 0.0
			var qq := 0.0
			var c := 0.0
			for _n in 12:
				var z := 1.0 if (t & 0x800) != 0 else 0.0
				t = (t << 1) & 0xFFFF
				for _k in 2:
					var zz := sig.step(z)
					c = chroma.step(zz)
					y0 = luma.step(zz)
					c *= 2.0
					ii += (c * cos(phi) - ii) / 8.0
					qq += (c * sin(phi) - qq) / 8.0
					phi += rad_45
			var color := s & 15
			var r32: float
			var g32: float
			var b32: float
			if color == 15:
				r32 = 1.0
				g32 = 1.0
				b32 = 1.0
			elif color == 0:
				r32 = 0.0
				g32 = 0.0
				b32 = 0.0
			else:
				r32 = clampf(y0 + I_TO_R * ii + Q_TO_R * qq, 0.0, 1.0)
				g32 = clampf(y0 + I_TO_G * ii + Q_TO_G * qq, 0.0, 1.0)
				b32 = clampf(y0 + I_TO_B * ii + Q_TO_B * qq, 0.0, 1.0)
			out[i] = int(r32 * 255.0)
			out[i + 1] = int(g32 * 255.0)
			out[i + 2] = int(b32 * 255.0)
			i += 3
	return out


class _Biquad:
	var x0 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y0 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var gain := 1.0
	var a0 := 0.0
	var a1 := 0.0
	var chroma := false

	func _init(p_gain: float, p_a0: float, p_a1: float, p_chroma: bool) -> void:
		gain = p_gain
		a0 = p_a0
		a1 = p_a1
		chroma = p_chroma

	func step(z: float) -> float:
		x0 = x1
		x1 = x2
		x2 = z / gain
		y0 = y1
		y1 = y2
		if chroma:
			y2 = -x0 + x2 + (a0 * y0) + (a1 * y1)
		else:
			y2 = x0 + x2 + (2.0 * x1) + (a0 * y0) + (a1 * y1)
		return y2
