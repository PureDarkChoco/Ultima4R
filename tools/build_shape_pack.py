#!/usr/bin/env python3
"""Pack U4 tile PNGs for CPU-only loading in exported builds.

Examples:
  python3 tools/build_shape_pack.py
  python3 tools/build_shape_pack.py apple2
  python3 tools/build_shape_pack.py mono
  python3 tools/build_shape_pack.py all
"""

from pathlib import Path
import struct
import sys


ROOT = Path(__file__).resolve().parents[1]
SETS = {
	"new": (
		ROOT / "assets/tiles/u4graphics/shapes",
		ROOT / "assets/tiles/u4graphics/shapes.u4pack",
	),
	"apple2": (
		ROOT / "assets/tiles/apple2_color/shapes",
		ROOT / "assets/tiles/apple2_color/shapes.u4pack",
	),
	"mono": (
		ROOT / "assets/tiles/apple2_mono/shapes",
		ROOT / "assets/tiles/apple2_mono/shapes.u4pack",
	),
}
MAGIC = b"U4SP"
VERSION = 1


def pack_set(source: Path, output: Path) -> None:
	files = sorted(source.glob("*.png"))
	if not files:
		raise SystemExit(f"No PNG files found under {source}")

	with output.open("wb") as out:
		out.write(MAGIC)
		out.write(struct.pack("<II", VERSION, len(files)))
		for path in files:
			name = path.name.encode("utf-8")
			data = path.read_bytes()
			if len(name) > 0xFFFF:
				raise SystemExit(f"File name is too long: {path.name}")
			out.write(struct.pack("<HI", len(name), len(data)))
			out.write(name)
			out.write(data)

	print(f"Wrote {output.relative_to(ROOT)} ({len(files)} PNGs)")


def main() -> None:
	which = (sys.argv[1] if len(sys.argv) > 1 else "new").strip().lower()
	if which in ("all", "both"):
		for key in ("new", "apple2", "mono"):
			pack_set(*SETS[key])
		return
	if which in ("apple2", "apple", "a2", "apple2_color"):
		pack_set(*SETS["apple2"])
		return
	if which in ("mono", "apple2_mono", "monochrome", "apple2_mono_white"):
		pack_set(*SETS["mono"])
		return
	pack_set(*SETS["new"])


if __name__ == "__main__":
	main()
