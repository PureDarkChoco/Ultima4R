#!/usr/bin/env python3
"""Parse Ultima IV .DNG files and check sizes / room counts against the remake loader."""

from __future__ import annotations

import pathlib
import sys

MAP_BYTES = 512
ROOM_BYTES = 256
REGULAR_ROOMS = 16
ABYSS_ROOMS = 64
LEVELS = 8

IDS = [
    "DECEIT.DNG",
    "DESPISE.DNG",
    "DESTARD.DNG",
    "WRONG.DNG",
    "COVETOUS.DNG",
    "SHAME.DNG",
    "HYTHLOTH.DNG",
    "ABYSS.DNG",
]


def find_data() -> pathlib.Path | None:
    roots = [
        pathlib.Path("data/u4"),
        pathlib.Path("/Applications/Ultima IV™.app/Contents/Resources/game"),
    ]
    for root in roots:
        if (root / "DECEIT.DNG").is_file():
            return root
    return None


def main() -> int:
    root = find_data()
    if root is None:
        print("no Ultima IV data found")
        return 1
    ok = True
    for name in IDS:
        path = root / name
        if not path.is_file():
            print(f"MISSING {name}")
            ok = False
            continue
        data = path.read_bytes()
        expect_rooms = ABYSS_ROOMS if name == "ABYSS.DNG" else REGULAR_ROOMS
        expect = MAP_BYTES + expect_rooms * ROOM_BYTES
        rooms = max(0, (len(data) - MAP_BYTES) // ROOM_BYTES)
        tokens = {b & 0xF0 for b in data[:MAP_BYTES]}
        print(
            f"{name}: {len(data)} bytes (expect {expect}), "
            f"rooms={rooms} (expect {expect_rooms}), tokens={sorted(tokens)}"
        )
        if rooms < expect_rooms:
            ok = False
        if len(data) < MAP_BYTES:
            ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
