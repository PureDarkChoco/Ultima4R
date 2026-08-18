#!/usr/bin/env python3
"""Pack U4 tile PNGs for CPU-only loading in exported builds."""

from pathlib import Path
import struct


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/tiles/u4graphics/shapes"
OUTPUT = ROOT / "assets/tiles/u4graphics/shapes.u4pack"
MAGIC = b"U4SP"
VERSION = 1


def main() -> None:
    files = sorted(SOURCE.glob("*.png"))
    if not files:
        raise SystemExit(f"No PNG files found under {SOURCE}")

    with OUTPUT.open("wb") as out:
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

    print(f"Wrote {OUTPUT.relative_to(ROOT)} ({len(files)} PNGs)")


if __name__ == "__main__":
    main()
