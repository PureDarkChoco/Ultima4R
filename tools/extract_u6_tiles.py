#!/usr/bin/env python3
"""Extract Ultima VI VGA tiles → PNG for Ultima4R (run locally; do not commit GOG output).

Reads from: /Applications/Ultima VI.app/.../game
Writes to:  assets/tiles/u6/  and  assets/ui/u6/
"""
from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

U6 = Path("/Applications/Ultima VI™.app/Contents/Resources/game")
OUT_TILES = Path("/Users/hexley/Documents/Ultima4R/assets/tiles/u6")
OUT_UI = Path("/Users/hexley/Documents/Ultima4R/assets/ui/u6")

TILE_W = TILE_H = 16
NUM_TILES = 0x800
MAP_TILES = 0x200
MAP_RAW_SIZE = 117408  # after LZW


class U6Lzw:
	@staticmethod
	def decompress(src: bytes) -> bytes:
		if len(src) < 6:
			raise ValueError("too short")
		out_len = src[0] | (src[1] << 8) | (src[2] << 16) | (src[3] << 24)
		if out_len == 0:
			return src[4:]
		data = src[4:]
		dest = bytearray(out_len)
		bits_read = 0
		bytes_written = 0
		codeword_size = 9
		next_free = 0x102
		dict_size = 0x200
		dictionary: dict[int, tuple[int, int]] = {}  # code -> (root, prefix)
		end = False
		pW = 0

		def get_code() -> int:
			nonlocal bits_read
			i = bits_read // 8
			b0 = data[i] if i < len(data) else 0
			b1 = data[i + 1] if i + 1 < len(data) else 0
			b2 = data[i + 2] if codeword_size + (bits_read % 8) > 16 and i + 2 < len(data) else 0
			code = (b2 << 16) | (b1 << 8) | b0
			code >>= bits_read % 8
			mask = (1 << codeword_size) - 1
			bits_read += codeword_size
			return code & mask

		def get_string(cw: int) -> list[int]:
			stack: list[int] = []
			cur = cw
			while cur > 0xFF:
				root, cur = dictionary[cur]
				stack.append(root)
			stack.append(cur)
			return stack  # top is last element

		while not end and bytes_written < out_len:
			cW = get_code()
			if cW == 0x100:
				codeword_size = 9
				next_free = 0x102
				dict_size = 0x200
				dictionary.clear()
				cW = get_code()
				dest[bytes_written] = cW & 0xFF
				bytes_written += 1
				pW = cW
				continue
			if cW == 0x101:
				end = True
				break
			if cW < next_free:
				stack = get_string(cW)
				C = stack[-1]
				for ch in reversed(stack):
					dest[bytes_written] = ch & 0xFF
					bytes_written += 1
				dictionary[next_free] = (C, pW)
				next_free += 1
			else:
				stack = get_string(pW)
				C = stack[-1]
				for ch in reversed(stack):
					dest[bytes_written] = ch & 0xFF
					bytes_written += 1
				dest[bytes_written] = C & 0xFF
				bytes_written += 1
				if cW != next_free:
					raise ValueError(f"LZW desync cW={cW} next={next_free}")
				dictionary[next_free] = (C, pW)
				next_free += 1
			if next_free >= dict_size and codeword_size < 12:
				codeword_size += 1
				dict_size *= 2
			pW = cW
		return bytes(dest[:out_len])


def load_pal() -> list[tuple[int, int, int, int]]:
	raw = (U6 / "U6PAL").read_bytes()
	pal = []
	for i in range(256):
		r, g, b = raw[i * 3], raw[i * 3 + 1], raw[i * 3 + 2]
		# 0..63 → 0..255
		pal.append((min(255, r * 4), min(255, g * 4), min(255, b * 4), 255))
	return pal


def decode_tile(blob: bytes, offset: int, mask: int) -> bytearray:
	"""Return 256 palette indices (255 = transparent). Matches nuvie decodePixelBlockTile."""
	out = bytearray([255] * 256)
	if mask == 0:  # opaque
		out[:] = blob[offset : offset + 256]
		return out
	if mask == 5:  # transparent plain
		out[:] = blob[offset : offset + 256]
		return out
	if mask == 0x0A:  # pixel blocks (compressed spans)
		ptr = offset + 1
		data_ptr = 0
		while True:
			if ptr + 3 > len(blob):
				break
			disp = blob[ptr] | (blob[ptr + 1] << 8)
			length = blob[ptr + 2]
			ptr += 3
			if length == 0:
				break
			x = disp % 160 + (160 if disp >= 1760 else 0)
			data_ptr += x
			for _i in range(length):
				if 0 <= data_ptr < 256 and ptr < len(blob):
					out[data_ptr] = blob[ptr]
				data_ptr += 1
				ptr += 1
		return out
	out[:] = blob[offset : offset + 256]
	return out


def indices_to_rgba(indices: bytearray, pal: list, transparent_255: bool) -> bytes:
	rgba = bytearray(256 * 4)
	for i, idx in enumerate(indices):
		if transparent_255 and idx == 255:
			rgba[i * 4 : i * 4 + 4] = b"\x00\x00\x00\x00"
		else:
			r, g, b, a = pal[idx]
			rgba[i * 4 : i * 4 + 4] = bytes((r, g, b, a))
	return bytes(rgba)


def write_png(path: Path, rgba: bytes, w: int, h: int) -> None:
	# Minimal PNG writer
	import struct as st

	def chunk(tag: bytes, data: bytes) -> bytes:
		return st.pack(">I", len(data)) + tag + data + st.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

	raw = b""
	stride = w * 4
	for y in range(h):
		raw += b"\x00" + rgba[y * stride : (y + 1) * stride]
	ihdr = st.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
	path.write_bytes(
		b"\x89PNG\r\n\x1a\n"
		+ chunk(b"IHDR", ihdr)
		+ chunk(b"IDAT", zlib.compress(raw, 9))
		+ chunk(b"IEND", b"")
	)


def main() -> None:
	OUT_TILES.mkdir(parents=True, exist_ok=True)
	OUT_UI.mkdir(parents=True, exist_ok=True)

	pal = load_pal()
	map_raw = U6Lzw.decompress((U6 / "MAPTILES.VGA").read_bytes())
	print("maptiles decompressed", len(map_raw), "expected", MAP_RAW_SIZE)
	obj_raw = (U6 / "OBJTILES.VGA").read_bytes()
	print("objtiles", len(obj_raw))
	all_tiles = map_raw + obj_raw

	mask_raw = U6Lzw.decompress((U6 / "MASKTYPE.VGA").read_bytes())
	masks = mask_raw[:NUM_TILES]
	print("masktype", len(mask_raw), "sample", list(masks[:16]))

	indx = struct.unpack("<" + "H" * NUM_TILES, (U6 / "TILEINDX.VGA").read_bytes())
	basetile = struct.unpack("<" + "H" * 1024, (U6 / "BASETILE").read_bytes())

	# Decode all tiles → vertical strip 16 x (16*2048)
	strip_h = TILE_H * NUM_TILES
	strip = bytearray(TILE_W * strip_h * 4)
	ok = 0
	for t in range(NUM_TILES):
		off = indx[t] * 16
		mask = masks[t]
		# offsets into contiguous map+obj
		if off >= len(all_tiles):
			continue
		try:
			indices = decode_tile(all_tiles, off, mask)
			trans = mask in (5, 0x0A)
			rgba = indices_to_rgba(indices, pal, trans)
			y0 = t * TILE_H
			for y in range(TILE_H):
				src = y * TILE_W * 4
				dst = ((y0 + y) * TILE_W) * 4
				strip[dst : dst + TILE_W * 4] = rgba[src : src + TILE_W * 4]
			ok += 1
		except Exception as e:
			print("tile", t, "fail", e)

	# Bake ANIMDATA first frames (water 8–15 etc. are empty placeholders).
	anim = (U6 / "ANIMDATA").read_bytes()
	n_anim = struct.unpack_from("<H", anim, 0)[0]
	anim_tiles = struct.unpack_from("<" + "H" * 0x20, anim, 2)
	anim_srcs = struct.unpack_from("<" + "H" * 0x20, anim, 2 + 0x40)
	baked = 0
	for i in range(n_anim):
		dst_t = anim_tiles[i]
		src_t = anim_srcs[i]
		if dst_t >= NUM_TILES or src_t >= NUM_TILES:
			continue
		src0 = src_t * TILE_H * TILE_W * 4
		dst0 = dst_t * TILE_H * TILE_W * 4
		nbytes = TILE_H * TILE_W * 4
		strip[dst0 : dst0 + nbytes] = strip[src0 : src0 + nbytes]
		baked += 1
	print("baked anim first frames", baked)

	# Vertical strip exceeds many GPU max-texture heights (16384); use a grid.
	# 16×128 tiles → 256×2048 px (safe). Also keep legacy strips for tooling.
	cols = 16
	rows = NUM_TILES // cols
	grid_w = TILE_W * cols
	grid_h = TILE_H * rows
	grid = bytearray(grid_w * grid_h * 4)
	for t in range(NUM_TILES):
		tx = t % cols
		ty = t // cols
		for y in range(TILE_H):
			src = ((t * TILE_H + y) * TILE_W) * 4
			dst = ((ty * TILE_H + y) * grid_w + tx * TILE_W) * 4
			grid[dst : dst + TILE_W * 4] = strip[src : src + TILE_W * 4]
	write_png(OUT_TILES / "all_tiles.png", bytes(grid), grid_w, grid_h)
	# Map-only strip (512 tiles → height 8192, under 16384 limit)
	map_h = TILE_H * MAP_TILES
	write_png(OUT_TILES / "map_tiles.png", bytes(strip[: TILE_W * map_h * 4]), TILE_W, map_h)
	(OUT_TILES / "atlas_meta.json").write_text(
		'{"tile":16,"cols":16,"rows":128,"count":2048,"layout":"row-major"}\n'
	)
	print("decoded", ok, "/", NUM_TILES, "grid", grid_w, "x", grid_h)

	# UI icons from object types → basetile
	icons = {
		"gold": 88,  # gold coin
		"gold_nugget": 89,
		"food_bread": 128,
		"food_meat": 129,
		"food_grapes": 95,
		"food_grain": 166,
		"corpse": 339,  # dead body
		"arrow": 55,
		"moongate": 85,
		"moonstone": 73,
		"orb_moons": 87,
		"sleeping": 146,  # person sleeping
	}
	for name, oid in icons.items():
		tid = basetile[oid]
		y0 = tid * TILE_H
		rgba = bytes(strip[y0 * TILE_W * 4 : (y0 + TILE_H) * TILE_W * 4])
		write_png(OUT_UI / f"{name}.png", rgba, TILE_W, TILE_H)
		print(f"icon {name}: obj {oid} -> tile {tid}")

	# Primary food icon (bread).
	bread = OUT_UI / "food_bread.png"
	if bread.exists():
		(OUT_UI / "food.png").write_bytes(bread.read_bytes())

	# Moon phases: lit discs tinted for status bar (U6-colored, geometric phases).
	_write_moon_phases(OUT_UI)

	(OUT_TILES / "SOURCE.md").write_text(
		"# Ultima VI tiles (local extract)\n\n"
		"Source: GOG Ultima VI `MAPTILES.VGA` / `OBJTILES.VGA` / `U6PAL`.\n"
		"**Do not commit** these PNGs (GOG data).\n\n"
		"Regenerate: `python3 tools/extract_u6_tiles.py`\n\n"
		"Used by: MapView (`all_tiles.png` grid 16×128 + `../u4_to_u6.json` remap), "
		"StatusInfoBar / corpse (`assets/ui/u6/`).\n"
		"U4→U6 map is semantic (LOOK.LZD + ANIMDATA), not index 1:1.\n"
		"World landmarks (town/castle/village/shrine/…) keep U4 `shapes.png` icons.\n"
		"Class portraits remain U4 `u4graphics`.\n"
	)
	print("done →", OUT_TILES, OUT_UI)


def _write_moon_phases(out_ui: Path) -> None:
	"""8 phase discs for Trammel/Felucca (readable on the blue info bar)."""
	fill = (200, 190, 120, 255)
	edge = (150, 140, 80, 255)
	r = 6.2
	cx = cy = 7.5
	for phase in range(8):
		rgba = bytearray([0] * (TILE_W * TILE_H * 4))
		ang = (phase / 8.0) * 2 * math.pi
		for y in range(TILE_H):
			for x in range(TILE_W):
				dx = x - cx
				dy = y - cy
				if dx * dx + dy * dy > r * r:
					continue
				nx = dx / r
				ny = dy / r
				nz2 = 1.0 - nx * nx - ny * ny
				if nz2 < 0:
					continue
				lx = math.sin(ang)
				lz = -math.cos(ang)
				nz = math.sqrt(nz2)
				if nx * lx + nz * lz <= 0.02 and phase != 0:
					continue
				if phase == 0:
					# New moon: faint ring only.
					dist = math.sqrt(dx * dx + dy * dy)
					if not (5.4 <= dist <= 6.4):
						continue
					col = (edge[0] // 2, edge[1] // 2, edge[2] // 2, 200)
				else:
					dist = math.sqrt(nx * nx + ny * ny)
					col = edge if dist > 0.85 else fill
				i = (y * TILE_W + x) * 4
				rgba[i : i + 4] = bytes(col)
		write_png(out_ui / f"moon_phase_{phase}.png", bytes(rgba), TILE_W, TILE_H)
	print("icon moon_phase_0..7")


if __name__ == "__main__":
	main()
