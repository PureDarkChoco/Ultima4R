#!/usr/bin/env python3
"""Build Apple II Ultima IV HGR tile pack for runtime Mariani NTSC compose.

Copies the two 4096-byte Apple II tile banks and embeds the AppleWin/Mariani
Color Monitor hue LUT.  The Program disk's raw SHP0/SHP1 are not sufficient for
animated water/field/lava: those shapes are expanded into language-card RAM at
load.  Packing uses disk SHP as the base and overlays only the runtime-expanded
animated tile ids — a raw LC dump can briefly corrupt unrelated shapes
(e.g. spider 152/153 row0).

Output: assets/tiles/apple2_color/shapes.u4hgr
  magic "U4HG" + version + SHP0 + SHP1 + hue_monitor RGB (4×4096×3)

Does not ship the .dsk. Rebuild from language-card bank dumps + disk SHP:

  python3 tools/build_a2_u4_hgr_pack.py \\
      --bank1 reference/apple2_u4/bank1.bin \\
      --bank2 reference/apple2_u4/bank2.bin
"""
from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "tiles" / "apple2_color" / "shapes.u4hgr"
REF = ROOT / "reference" / "apple2_u4"

BANK_SIZE = 4096
MAGIC = b"U4HG"
VERSION = 1

# Import NTSC LUT builder from the composite tool (same AppleWin coefficients).
sys.path.insert(0, str(ROOT / "tools"))
from build_a2_u4_color_composite import build_hue_tables  # noqa: E402
ANIMATED_TILE_IDS = (0, 1, 2, 68, 69, 70, 71, 75, 76)


def validate_runtime_banks(bank1: bytes, bank2: bytes) -> None:
	"""Reject raw disk SHP banks whose runtime-generated fields are still blank."""
	if len(bank1) != BANK_SIZE or len(bank2) != BANK_SIZE:
		raise ValueError("each runtime bank must be exactly 4096 bytes")
	blank: list[int] = []
	for tid in ANIMATED_TILE_IDS:
		lit = 0
		for y in range(16):
			lit |= bank1[y * 256 + tid] & 0x7F
			lit |= bank2[y * 256 + tid] & 0x7F
		if lit == 0:
			blank.append(tid)
	if blank:
		raise ValueError(
			"runtime-generated tile(s) are blank: "
			f"{blank}. Raw Program-disk SHP0/SHP1 cannot be packed directly; "
			"dump LC bank1/bank2 after Ultima IV has expanded its animated shapes."
		)


def merge_disk_and_runtime(
	disk1: bytes, disk2: bytes, run1: bytes, run2: bytes
) -> tuple[bytes, bytes]:
	left = bytearray(disk1)
	right = bytearray(disk2)
	for tid in ANIMATED_TILE_IDS:
		for y in range(16):
			i = y * 256 + tid
			left[i] = run1[i]
			right[i] = run2[i]
	return bytes(left), bytes(right)


def write_pack(path: Path, bank1: bytes, bank2: bytes) -> None:
	validate_runtime_banks(bank1, bank2)
	print("Building Mariani/AppleWin Color Monitor hue LUT…")
	mon, _tv = build_hue_tables()
	hue = bytearray(4 * 4096 * 3)
	for phase in range(4):
		base = phase * 4096 * 3
		for s in range(4096):
			r, g, b = mon[phase][s]
			i = base + s * 3
			hue[i] = r
			hue[i + 1] = g
			hue[i + 2] = b
	path.parent.mkdir(parents=True, exist_ok=True)
	with path.open("wb") as f:
		f.write(MAGIC)
		f.write(struct.pack("<I", VERSION))
		f.write(bank1)
		f.write(bank2)
		f.write(hue)
	print(f"Wrote {path} ({path.stat().st_size} bytes)")


def main() -> int:
	ap = argparse.ArgumentParser(description=__doc__)
	ap.add_argument("--bank1", type=Path, help="Runtime-expanded 4096-byte LC bank 1")
	ap.add_argument("--bank2", type=Path, help="Runtime-expanded 4096-byte LC bank 2")
	ap.add_argument("--shp0", type=Path, default=REF / "shp0.bin")
	ap.add_argument("--shp1", type=Path, default=REF / "shp1.bin")
	ap.add_argument(
		"--runtime-only",
		action="store_true",
		help="Pack bank1/bank2 as-is without disk SHP merge",
	)
	ap.add_argument("-o", "--output", type=Path, default=OUT)
	args = ap.parse_args()

	if args.bank1 and args.bank2:
		run1 = args.bank1.read_bytes()
		run2 = args.bank2.read_bytes()
	elif (REF / "bank1.bin").is_file() and (REF / "bank2.bin").is_file():
		run1 = (REF / "bank1.bin").read_bytes()
		run2 = (REF / "bank2.bin").read_bytes()
		print(f"Using {REF / 'bank1.bin'} + bank2.bin")
	else:
		ap.error(
			"Provide --bank1/--bank2, or place runtime-expanded bank1.bin and "
			"bank2.bin under reference/apple2_u4"
		)
		return 2

	if args.runtime_only:
		bank1, bank2 = run1, run2
	else:
		if not args.shp0.is_file() or not args.shp1.is_file():
			ap.error(f"disk SHP missing: {args.shp0} / {args.shp1}")
			return 2
		disk1 = args.shp0.read_bytes()
		disk2 = args.shp1.read_bytes()
		if len(disk1) != BANK_SIZE or len(disk2) != BANK_SIZE:
			ap.error("disk SHP0/SHP1 must be 4096 bytes each")
			return 2
		bank1, bank2 = merge_disk_and_runtime(disk1, disk2, run1, run2)
		print("Merged disk SHP + runtime animated tiles")

	write_pack(args.output, bank1, bank2)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
