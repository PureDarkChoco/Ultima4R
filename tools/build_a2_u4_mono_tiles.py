#!/usr/bin/env python3
"""Build native-aspect Apple II U4 monochrome tiles (28×32).

Each source shape is 14×16 HGR pixels. Apple II display geometry doubles each
horizontal bit to 28 pixels; Mariani-style scanlines double height to 32, with
the inserted row at 25% brightness.

Banks: start from disk SHP0/SHP1, then overlay runtime-expanded animated
tiles (water/fields/lava). A raw language-card dump can briefly corrupt
unrelated shapes (spider 152/153 row0 was once ff/ff); disk SHP is authoritative
for non-animated tiles.
"""

from __future__ import annotations

import argparse
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / "reference" / "apple2_u4"
DEFAULT_OUT = ROOT / "assets" / "tiles" / "apple2_mono" / "shapes"
BANK_SIZE = 4096
TILE_COUNT = 256
SRC_W = 14
SRC_H = 16
OUT_W = 28
OUT_H = 32
DIM = 63  # Mariani/AppleWin half-scanline: (255 & 0xFC) >> 2
## Same set as build_a2_u4_hgr_pack.py — only these need LC expansion.
ANIMATED_TILE_IDS = (0, 1, 2, 68, 69, 70, 71, 75, 76)


def write_png(path: Path, width: int, height: int, rgb: bytes) -> None:
	def chunk(tag: bytes, data: bytes) -> bytes:
		return (
			struct.pack(">I", len(data))
			+ tag
			+ data
			+ struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
		)

	raw = b"".join(
		b"\x00" + rgb[y * width * 3 : (y + 1) * width * 3]
		for y in range(height)
	)
	ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
	path.write_bytes(
		b"\x89PNG\r\n\x1a\n"
		+ chunk(b"IHDR", ihdr)
		+ chunk(b"IDAT", zlib.compress(raw, 9))
		+ chunk(b"IEND", b"")
	)


def bits7(value: int) -> list[int]:
	return [(value >> bit) & 1 for bit in range(7)]


def validate_banks(left: bytes, right: bytes, label: str) -> None:
	if len(left) != BANK_SIZE or len(right) != BANK_SIZE:
		raise SystemExit(
			f"{label} must be {BANK_SIZE} bytes each "
			f"(got {len(left)} and {len(right)})"
		)


def validate_runtime_animated(left: bytes, right: bytes) -> None:
	# Runtime-expanded field slots must not all be blank.
	for tile_id in ANIMATED_TILE_IDS:
		if not any(
			(left[y * TILE_COUNT + tile_id] | right[y * TILE_COUNT + tile_id]) & 0x7F
			for y in range(SRC_H)
		):
			raise SystemExit(
				f"tile {tile_id} is blank; use runtime-expanded bank1.bin/bank2.bin"
			)


def merge_disk_and_runtime(
	disk_left: bytes,
	disk_right: bytes,
	run_left: bytes,
	run_right: bytes,
) -> tuple[bytes, bytes]:
	"""Disk SHP for static art; LC dump only for animated expansions."""
	left = bytearray(disk_left)
	right = bytearray(disk_right)
	for tile_id in ANIMATED_TILE_IDS:
		for y in range(SRC_H):
			i = y * TILE_COUNT + tile_id
			left[i] = run_left[i]
			right[i] = run_right[i]
	return bytes(left), bytes(right)


def render_tile(left: bytes, right: bytes, tile_id: int) -> bytes:
	out = bytearray(OUT_W * OUT_H * 3)
	for src_y in range(SRC_H):
		row = (
			bits7(left[src_y * TILE_COUNT + tile_id])
			+ bits7(right[src_y * TILE_COUNT + tile_id])
		)
		for src_x in range(SRC_W):
			on = row[src_x] != 0
			bright = 255 if on else 0
			dim = DIM if on else 0
			for dst_x in (src_x * 2, src_x * 2 + 1):
				for dst_y, level in ((src_y * 2, bright), (src_y * 2 + 1, dim)):
					offset = (dst_y * OUT_W + dst_x) * 3
					out[offset : offset + 3] = bytes((level, level, level))
	return bytes(out)


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--bank1", type=Path, default=REF / "bank1.bin")
	parser.add_argument("--bank2", type=Path, default=REF / "bank2.bin")
	parser.add_argument("--shp0", type=Path, default=REF / "shp0.bin")
	parser.add_argument("--shp1", type=Path, default=REF / "shp1.bin")
	parser.add_argument(
		"--runtime-only",
		action="store_true",
		help="Use bank1/bank2 as-is (skip disk merge; not recommended)",
	)
	parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
	args = parser.parse_args()

	run_left = args.bank1.read_bytes()
	run_right = args.bank2.read_bytes()
	validate_banks(run_left, run_right, "runtime banks")
	validate_runtime_animated(run_left, run_right)
	if args.runtime_only:
		left, right = run_left, run_right
	else:
		disk_left = args.shp0.read_bytes()
		disk_right = args.shp1.read_bytes()
		validate_banks(disk_left, disk_right, "disk SHP")
		left, right = merge_disk_and_runtime(
			disk_left, disk_right, run_left, run_right
		)
	args.out.mkdir(parents=True, exist_ok=True)
	for old in args.out.glob("*.png"):
		old.unlink()
	for tile_id in range(TILE_COUNT):
		write_png(
			args.out / f"{tile_id:03d}.png",
			OUT_W,
			OUT_H,
			render_tile(left, right, tile_id),
		)
	print(f"Wrote {TILE_COUNT} native-aspect mono tiles ({OUT_W}×{OUT_H}) to {args.out}")


if __name__ == "__main__":
	main()
