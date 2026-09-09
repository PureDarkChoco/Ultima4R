#!/usr/bin/env python3
"""Pack PNGs read as CPU Images so exports never read them back from Metal."""

from pathlib import Path
import struct


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/cpu_images.u4pack"
MAGIC = b"U4IP"
VERSION = 1

EXACT_SOURCES = (
    "assets/tiles/cannonball.png",
    "assets/tiles/horse_rider_w.png",
    "assets/tiles/horse_rider_e.png",
    "assets/tiles/apple2_horse_mount_w.png",
    "assets/tiles/apple2_horse_mount_e.png",
    "assets/tiles/u4graphics/charset.png",
    "assets/ui/weapons/sling_missile.png",
    "assets/ui/weapons/dagger.png",
    "assets/ui/weapons/magic_axe.png",
    "assets/ui/weapons/arrow_missile.png",
    "assets/ui/weapons/magic_arrow_missile.png",
    "assets/ui/combat/target_cursor.png",
    "assets/ui/combat/thrown_rocks.png",
    "assets/ui/special_items/stone_blue.png",
    "assets/ui/special_items/stone_yellow.png",
    "assets/ui/special_items/stone_red.png",
    "assets/ui/special_items/stone_green.png",
    "assets/ui/special_items/stone_orange.png",
    "assets/ui/special_items/stone_purple.png",
    "assets/ui/special_items/stone_white.png",
    "assets/ui/special_items/stone_black.png",
)


def source_files() -> list[Path]:
    files = [ROOT / relative for relative in EXACT_SOURCES]
    files.extend(sorted((ROOT / "assets/tiles/u4graphics/masks").glob("*.png")))
    files.extend(sorted((ROOT / "assets/dungeon").glob("**/*.png")))
    missing = [path for path in files if not path.is_file()]
    if missing:
        names = "\n".join(str(path.relative_to(ROOT)) for path in missing)
        raise SystemExit(f"Missing CPU image sources:\n{names}")
    return sorted(set(files))


def main() -> None:
    files = source_files()
    with OUTPUT.open("wb") as out:
        out.write(MAGIC)
        out.write(struct.pack("<II", VERSION, len(files)))
        for path in files:
            resource_path = f"res://{path.relative_to(ROOT).as_posix()}"
            name = resource_path.encode("utf-8")
            data = path.read_bytes()
            out.write(struct.pack("<HI", len(name), len(data)))
            out.write(name)
            out.write(data)
    print(f"Wrote {OUTPUT.relative_to(ROOT)} ({len(files)} PNGs)")


if __name__ == "__main__":
    main()
