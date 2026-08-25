#!/usr/bin/env python3
"""Extract Ultima IV Apple II tiles from a Program .dsk → reference PNGs.

Reads DOS 3.3 files SHP0 / SHP1 (4am crack & stock layout) from the Program disk.
Each bank is 4096 bytes loaded at $D000: 16 scanlines × 256 tiles × 1 byte
(7 pixels + high-bit palette select). SHP0 = left half, SHP1 = right half → 14×16.

Writes monochrome and Apple II HGR artifact-color atlases. Output is copyrighted
Origin/EA art — local reference only; do not redistribute or ship in the game.

Example:
  python3 tools/extract_a2_u4_tiles.py \\
    "/Users/hexley/Downloads/Ultima IV (4am crack)/Ultima IV side A - Program.dsk"
"""
from __future__ import annotations

import argparse
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "reference" / "apple2_u4"

TILE_W = 14
TILE_H = 16
NUM_TILES = 256
BANK_SIZE = 4096

# Simplified Apple II HGR artifact palette (common emulator mapping).
PAL0 = {
	0b00: (0x00, 0x00, 0x00),
	0b01: (0x2F, 0xBC, 0x1A),  # green
	0b10: (0xC0, 0x37, 0xCE),  # violet
	0b11: (0xFF, 0xFF, 0xFF),
}
PAL1 = {
	0b00: (0x00, 0x00, 0x00),
	0b01: (0xE6, 0x7E, 0x22),  # orange
	0b10: (0x1B, 0x9A, 0xE7),  # blue
	0b11: (0xFF, 0xFF, 0xFF),
}


def write_png(path: Path, w: int, h: int, rgb: bytes) -> None:
	def chunk(tag: bytes, data: bytes) -> bytes:
		return (
			struct.pack(">I", len(data))
			+ tag
			+ data
			+ struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
		)

	raw = b"".join(b"\x00" + rgb[y * w * 3 : (y + 1) * w * 3] for y in range(h))
	ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
	png = (
		b"\x89PNG\r\n\x1a\n"
		+ chunk(b"IHDR", ihdr)
		+ chunk(b"IDAT", zlib.compress(raw, 9))
		+ chunk(b"IEND", b"")
	)
	path.write_bytes(png)


def dsk_ts_offset(track: int, sector: int) -> int:
	return track * 16 * 256 + sector * 256


def read_dos33_file(dsk: bytes, start_t: int, start_s: int) -> bytes:
	"""Follow a DOS 3.3 T/S list and return concatenated data sectors."""
	data = bytearray()
	t, s = start_t, start_s
	seen: set[tuple[int, int]] = set()
	while t != 0 and (t, s) not in seen:
		seen.add((t, s))
		sector = dsk[dsk_ts_offset(t, s) : dsk_ts_offset(t, s) + 256]
		next_t, next_s = sector[1], sector[2]
		i = 0x0C
		while i < 254:
			dt, ds = sector[i], sector[i + 1]
			i += 2
			if dt == 0:
				break
			off = dsk_ts_offset(dt, ds)
			data.extend(dsk[off : off + 256])
		t, s = next_t, next_s
	return bytes(data)


def catalog_files(dsk: bytes) -> list[tuple[str, int, int, int, int]]:
	"""Return (name, type, tslist_track, tslist_sector, sector_count)."""
	files: list[tuple[str, int, int, int, int]] = []
	track, sector = 17, 15
	seen: set[tuple[int, int]] = set()
	while track != 0 and (track, sector) not in seen:
		seen.add((track, sector))
		cat = dsk[dsk_ts_offset(track, sector) : dsk_ts_offset(track, sector) + 256]
		next_t, next_s = cat[1], cat[2]
		for i in range(7):
			entry = cat[0x0B + i * 35 : 0x0B + (i + 1) * 35]
			ftype = entry[2]
			if ftype in (0x00, 0xFF):
				continue
			# 4am/Passport cracks often clobber the 2nd filename byte with $01.
			chars: list[str] = []
			for j, b in enumerate(entry[3:33]):
				c = b & 0x7F
				if j == 1 and c == 0x01:
					continue
				if 32 <= c < 127:
					chars.append(chr(c))
			name = "".join(chars).rstrip()
			sec_count = entry[33] | (entry[34] << 8)
			files.append((name, ftype & 0x7F, entry[0], entry[1], sec_count))
		track, sector = next_t, next_s
	return files


def binary_payload(raw: bytes) -> bytes:
	"""Strip DOS binary header (load addr + length) when present."""
	if len(raw) < 4:
		raise ValueError("file too short")
	load = raw[0] | (raw[1] << 8)
	length = raw[2] | (raw[3] << 8)
	if load == 0xD000 and length == BANK_SIZE and len(raw) >= 4 + BANK_SIZE:
		return raw[4 : 4 + BANK_SIZE]
	if len(raw) >= BANK_SIZE:
		return raw[:BANK_SIZE]
	raise ValueError(f"unexpected shape size {len(raw)} (load=${load:04X} len=${length:04X})")


def extract_banks(dsk_path: Path) -> tuple[bytes, bytes]:
	dsk = dsk_path.read_bytes()
	if len(dsk) != 143360:
		raise ValueError(f"expected 143360-byte .dsk, got {len(dsk)}")

	files = {name: (t, s) for name, _ft, t, s, _n in catalog_files(dsk)}
	for need in ("SHP0", "SHP1"):
		if need not in files:
			raise FileNotFoundError(
				f"{need} not found in DOS catalog of {dsk_path.name}; "
				f"have: {', '.join(sorted(files))}"
			)

	shp0 = binary_payload(read_dos33_file(dsk, *files["SHP0"]))
	shp1 = binary_payload(read_dos33_file(dsk, *files["SHP1"]))
	if len(shp0) != BANK_SIZE or len(shp1) != BANK_SIZE:
		raise ValueError("shape banks must be 4096 bytes each")
	return shp0, shp1


def bits7(b: int) -> list[int]:
	return [(b >> i) & 1 for i in range(7)]


def tile_rows(bank0: bytes, bank1: bytes, tid: int) -> tuple[list[list[int]], list[tuple[int, int]]]:
	rows: list[list[int]] = []
	highs: list[tuple[int, int]] = []
	for y in range(TILE_H):
		bl = bank0[y * NUM_TILES + tid]
		br = bank1[y * NUM_TILES + tid]
		rows.append(bits7(bl) + bits7(br))
		highs.append(((bl >> 7) & 1, (br >> 7) & 1))
	return rows, highs


def render_atlas(
	bank0: bytes,
	bank1: bytes,
	*,
	mode: str,
	scale: int,
	pad_odd: bool = True,
	cols: int = 16,
) -> tuple[int, int, bytes]:
	rows = (NUM_TILES + cols - 1) // cols
	w = cols * TILE_W * scale
	h = rows * TILE_H * scale
	buf = bytearray(w * h * 3)
	phase0 = 1 if pad_odd else 0

	for tid in range(NUM_TILES):
		bits, highs = tile_rows(bank0, bank1, tid)
		tx, ty = tid % cols, tid // cols
		for y in range(TILE_H):
			hi_l, hi_r = highs[y]
			stream = bits[y]
			for x in range(TILE_W):
				if mode == "mono":
					c = 255 if stream[x] else 0
					color = (c, c, c)
				else:
					abs_x = x + phase0
					if abs_x % 2 == 0:
						pair = (stream[x] << 1) | (stream[x + 1] if x + 1 < TILE_W else 0)
					else:
						left = stream[x - 1] if x - 1 >= 0 else 0
						pair = (left << 1) | stream[x]
					hi = hi_l if x < 7 else hi_r
					color = (PAL1 if hi else PAL0)[pair]
				for dy in range(scale):
					for dx in range(scale):
						px = (tx * TILE_W + x) * scale + dx
						py = (ty * TILE_H + y) * scale + dy
						i = (py * w + px) * 3
						buf[i : i + 3] = bytes(color)
	return w, h, bytes(buf)


def write_tile_pngs(
	out_dir: Path,
	bank0: bytes,
	bank1: bytes,
	*,
	mode: str,
	scale: int,
) -> None:
	sub = out_dir / ("tiles_mono" if mode == "mono" else "tiles_color")
	sub.mkdir(parents=True, exist_ok=True)
	phase0 = 1
	for tid in range(NUM_TILES):
		bits, highs = tile_rows(bank0, bank1, tid)
		tw, th = TILE_W * scale, TILE_H * scale
		buf = bytearray(tw * th * 3)
		for y in range(TILE_H):
			hi_l, hi_r = highs[y]
			stream = bits[y]
			for x in range(TILE_W):
				if mode == "mono":
					c = 255 if stream[x] else 0
					color = (c, c, c)
				else:
					abs_x = x + phase0
					if abs_x % 2 == 0:
						pair = (stream[x] << 1) | (stream[x + 1] if x + 1 < TILE_W else 0)
					else:
						left = stream[x - 1] if x - 1 >= 0 else 0
						pair = (left << 1) | stream[x]
					hi = hi_l if x < 7 else hi_r
					color = (PAL1 if hi else PAL0)[pair]
				for dy in range(scale):
					for dx in range(scale):
						i = ((y * scale + dy) * tw + (x * scale + dx)) * 3
						buf[i : i + 3] = bytes(color)
		write_png(sub / f"{tid:03d}.png", tw, th, bytes(buf))


def main() -> None:
	ap = argparse.ArgumentParser(description=__doc__)
	ap.add_argument(
		"dsk",
		type=Path,
		nargs="?",
		default=Path(
			"/Users/hexley/Downloads/Ultima IV (4am crack)/Ultima IV side A - Program.dsk"
		),
		help="Ultima IV Apple II Program .dsk (side A)",
	)
	ap.add_argument("-o", "--out", type=Path, default=DEFAULT_OUT, help="output directory")
	ap.add_argument("--scale", type=int, default=4, help="atlas pixel scale (default 4)")
	ap.add_argument(
		"--individual",
		action="store_true",
		help="also write per-tile PNGs under tiles_mono/ and tiles_color/",
	)
	args = ap.parse_args()

	bank0, bank1 = extract_banks(args.dsk)
	out: Path = args.out
	out.mkdir(parents=True, exist_ok=True)

	(out / "shp0.bin").write_bytes(bank0)
	(out / "shp1.bin").write_bytes(bank1)

	for mode, name in (("mono", "tiles_mono"), ("color", "tiles_color")):
		w, h, rgb = render_atlas(bank0, bank1, mode=mode, scale=args.scale)
		write_png(out / f"{name}.png", w, h, rgb)
		w1, h1, rgb1 = render_atlas(bank0, bank1, mode=mode, scale=1)
		write_png(out / f"{name}_1x.png", w1, h1, rgb1)

	if args.individual:
		write_tile_pngs(out, bank0, bank1, mode="mono", scale=args.scale)
		write_tile_pngs(out, bank0, bank1, mode="color", scale=args.scale)

	(out / "SOURCE.txt").write_text(
		"Apple II Ultima IV tiles extracted from Program.dsk (SHP0/SHP1).\n"
		"14×16 px × 256 tiles. Mono = raw bits; color = HGR artifact palette.\n"
		"Copyright Origin Systems / Electronic Arts — local reference only.\n"
		f"Source: {args.dsk}\n",
		encoding="utf-8",
	)
	print(f"Wrote atlases to {out}")
	print(f"  tiles_mono.png / tiles_color.png (scale={args.scale})")
	print(f"  tiles_mono_1x.png / tiles_color_1x.png")
	print(f"  shp0.bin / shp1.bin (4096 bytes each)")


if __name__ == "__main__":
	main()
