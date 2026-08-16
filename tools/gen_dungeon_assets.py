#!/usr/bin/env python3
"""Generate 64×64 nearest-filter dungeon wall / entrance / floor textures."""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "assets" / "dungeon"
SIZE = 64


def write_png(path: Path, pixels: list[list[tuple[int, int, int]]]) -> None:
    raw = b""
    for row in pixels:
        raw += b"\x00"
        for r, g, b in row:
            raw += bytes((r, g, b, 255))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def clamp(v: int) -> int:
    return 0 if v < 0 else 255 if v > 255 else v


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        clamp(int(a[0] + (b[0] - a[0]) * t)),
        clamp(int(a[1] + (b[1] - a[1]) * t)),
        clamp(int(a[2] + (b[2] - a[2]) * t)),
    )


def hash2(x: int, y: int, salt: int = 0) -> int:
    n = (x * 374761393 + y * 668265263 + salt * 1274126177) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return n & 255


def shade(c: tuple[int, int, int], d: int) -> tuple[int, int, int]:
    return (clamp(c[0] + d), clamp(c[1] + d), clamp(c[2] + d))


def blank(c: tuple[int, int, int]) -> list[list[tuple[int, int, int]]]:
    return [[c for _ in range(SIZE)] for _ in range(SIZE)]


def setp(px: list[list[tuple[int, int, int]]], x: int, y: int, c: tuple[int, int, int]) -> None:
    if 0 <= x < SIZE and 0 <= y < SIZE:
        px[y][x] = c


def rect(
    px: list[list[tuple[int, int, int]]],
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    c: tuple[int, int, int],
) -> None:
    for y in range(y0, y1):
        for x in range(x0, x1):
            setp(px, x, y, c)


def dither_noise(px: list[list[tuple[int, int, int]]], salt: int, amp: int = 8) -> None:
    for y in range(SIZE):
        for x in range(SIZE):
            d = (hash2(x, y, salt) % (amp * 2 + 1)) - amp
            px[y][x] = shade(px[y][x], d)


# --- grey ancient stone (Deceit, Abyss) ---
GS_BASE = (58, 62, 72)
GS_DARK = (36, 38, 46)
GS_MID = (78, 84, 96)
GS_LIGHT = (118, 126, 140)
GS_MORTAR = (28, 30, 36)
GS_FLOOR = (48, 50, 58)
GS_FLOOR_LINE = (32, 34, 40)


def grey_wall() -> list[list[tuple[int, int, int]]]:
    px = blank(GS_BASE)
    # large ashlar blocks
    for y in range(0, SIZE, 16):
        shift = 8 if (y // 16) % 2 else 0
        for x in range(-shift, SIZE, 20):
            rect(px, x + 1, y + 1, x + 19, y + 15, mix(GS_MID, GS_BASE, 0.35))
            # bevel
            for i in range(18):
                setp(px, x + 1 + i, y + 1, GS_LIGHT)
                setp(px, x + 1, y + 1 + min(i, 13), GS_LIGHT)
            for i in range(18):
                setp(px, x + 1 + i, y + 14, GS_DARK)
                setp(px, x + 18, y + 1 + min(i, 13), GS_DARK)
            # mortar frame
            for i in range(20):
                setp(px, x + i, y, GS_MORTAR)
                setp(px, x + i, y + 15, GS_MORTAR)
            for i in range(16):
                setp(px, x, y + i, GS_MORTAR)
                setp(px, x + 19, y + i, GS_MORTAR)
            # faint rune
            if hash2(x, y, 9) % 5 == 0:
                cx, cy = x + 10, y + 8
                for dx, dy in ((0, -2), (0, -1), (0, 0), (0, 1), (-2, 0), (-1, 0), (1, 0)):
                    setp(px, cx + dx, cy + dy, mix(GS_DARK, GS_MID, 0.4))
    dither_noise(px, 11, 6)
    return px


def grey_floor() -> list[list[tuple[int, int, int]]]:
    px = blank(GS_FLOOR)
    for y in range(0, SIZE, 16):
        for x in range(0, SIZE, 16):
            inset = 1
            rect(px, x + inset, y + inset, x + 16 - inset, y + 16 - inset, shade(GS_FLOOR, 6))
            for i in range(16):
                setp(px, x + i, y, GS_FLOOR_LINE)
                setp(px, x, y + i, GS_FLOOR_LINE)
            setp(px, x + 1, y + 1, GS_LIGHT)
    dither_noise(px, 21, 5)
    return px


# --- prison brick (Wrong, Hythloth) ---
BR_A = (132, 58, 42)
BR_B = (108, 44, 32)
BR_C = (156, 78, 56)
BR_MORTAR = (62, 44, 36)
BR_FLOOR = (86, 48, 38)
BR_FLOOR_LINE = (48, 28, 22)


def brick_wall() -> list[list[tuple[int, int, int]]]:
    px = blank(BR_MORTAR)
    bh, bw = 8, 16
    for row, y in enumerate(range(0, SIZE, bh)):
        off = (bw // 2) if row % 2 else 0
        for x in range(-off, SIZE, bw):
            tone = BR_A if hash2(x, y, 3) % 2 == 0 else BR_B
            if hash2(x, y, 7) % 7 == 0:
                tone = BR_C
            rect(px, x + 1, y + 1, x + bw - 1, y + bh - 1, tone)
            for i in range(bw - 2):
                setp(px, x + 1 + i, y + 1, shade(tone, 22))
                setp(px, x + 1 + i, y + bh - 2, shade(tone, -18))
            setp(px, x + 1, y + 2, shade(tone, 16))
    dither_noise(px, 31, 7)
    return px


def brick_floor() -> list[list[tuple[int, int, int]]]:
    px = blank(BR_FLOOR)
    for y in range(0, SIZE, 8):
        off = 8 if (y // 8) % 2 else 0
        for x in range(-off, SIZE, 16):
            rect(px, x + 1, y + 1, x + 15, y + 7, shade(BR_FLOOR, 8 if (x + y) % 32 else -4))
            for i in range(16):
                setp(px, x + i, y, BR_FLOOR_LINE)
            for i in range(8):
                setp(px, x, y + i, BR_FLOOR_LINE)
    dither_noise(px, 41, 5)
    return px


# --- dirt cave (Despise, Destard) ---
DT_A = (86, 58, 36)
DT_B = (64, 42, 26)
DT_C = (108, 76, 48)
DT_ROCK = (52, 44, 36)
DT_ROOT = (40, 28, 18)
DT_FLOOR = (72, 50, 32)
DT_FLOOR_D = (48, 34, 22)


def dirt_wall() -> list[list[tuple[int, int, int]]]:
    px = blank(DT_A)
    for y in range(SIZE):
        for x in range(SIZE):
            n = hash2(x, y, 51)
            if n < 40:
                px[y][x] = DT_B
            elif n > 220:
                px[y][x] = DT_C
    # rocks
    for i in range(18):
        cx = hash2(i, 2, 8) % SIZE
        cy = hash2(i, 3, 9) % SIZE
        rw = 3 + hash2(i, 4, 1) % 5
        rh = 2 + hash2(i, 5, 2) % 4
        for y in range(cy, cy + rh):
            for x in range(cx, cx + rw):
                if (x - cx - rw / 2) ** 2 / (rw * rw) + (y - cy - rh / 2) ** 2 / (rh * rh) < 0.35:
                    setp(px, x, y, DT_ROCK)
    # roots
    for i in range(6):
        x = 6 + i * 10
        y = 0
        for _ in range(18):
            setp(px, x, y, DT_ROOT)
            x += (hash2(x, y, 17) % 3) - 1
            y += 1
    dither_noise(px, 61, 8)
    return px


def dirt_floor() -> list[list[tuple[int, int, int]]]:
    px = blank(DT_FLOOR)
    for y in range(SIZE):
        for x in range(SIZE):
            n = hash2(x, y, 71)
            if n < 50:
                px[y][x] = DT_FLOOR_D
            elif n > 230:
                px[y][x] = shade(DT_FLOOR, 16)
            if n % 23 == 0:
                px[y][x] = DT_ROCK
    dither_noise(px, 81, 6)
    return px


# --- timber-reinforced mine (Covetous, Shame) ---
TM_DIRT = (74, 50, 32)
TM_DIRT2 = (56, 38, 24)
TM_BEAM = (92, 62, 32)
TM_BEAM_D = (48, 30, 16)
TM_BEAM_L = (132, 96, 54)
TM_IRON = (36, 36, 38)
TM_FLOOR = (70, 48, 30)
TM_PLANK = (102, 70, 38)
TM_PLANK_D = (58, 38, 20)


def timber_wall() -> list[list[tuple[int, int, int]]]:
    px = blank(TM_DIRT)
    for y in range(SIZE):
        for x in range(SIZE):
            if hash2(x, y, 91) < 70:
                px[y][x] = TM_DIRT2
    # vertical posts
    for x in (6, 30, 54):
        rect(px, x, 0, x + 6, SIZE, TM_BEAM)
        for y in range(SIZE):
            setp(px, x, y, TM_BEAM_D)
            setp(px, x + 5, y, TM_BEAM_L)
            if y % 10 == 0:
                rect(px, x - 1, y, x + 7, y + 2, TM_IRON)
    # horizontal beams
    for y in (8, 28, 48):
        rect(px, 0, y, SIZE, y + 5, TM_BEAM)
        for x in range(SIZE):
            setp(px, x, y, TM_BEAM_L)
            setp(px, x, y + 4, TM_BEAM_D)
    dither_noise(px, 101, 6)
    return px


def timber_floor() -> list[list[tuple[int, int, int]]]:
    px = blank(TM_FLOOR)
    for y in range(0, SIZE, 8):
        tone = TM_PLANK if (y // 8) % 2 == 0 else shade(TM_PLANK, -12)
        rect(px, 0, y, SIZE, y + 8, tone)
        for x in range(SIZE):
            setp(px, x, y, TM_PLANK_D)
            if hash2(x, y, 4) % 17 == 0:
                setp(px, x, y + 3, TM_PLANK_D)
        # nail
        setp(px, 8, y + 3, TM_IRON)
        setp(px, 40, y + 3, TM_IRON)
    dither_noise(px, 111, 5)
    return px


def make_entrance(wall: list[list[tuple[int, int, int]]], jamb: tuple[int, int, int], void: tuple[int, int, int]) -> list[list[tuple[int, int, int]]]:
    px = [row[:] for row in wall]
    # arched doorway
    x0, x1 = 16, 48
    y0, y1 = 10, 64
    for y in range(y0, y1):
        t = (y - y0) / max(1, 18)
        arch = 0
        if y < y0 + 18:
            # semicircle inset
            yy = (y0 + 18 - y) / 18.0
            arch = int((1.0 - (1.0 - yy * yy) ** 0.5) * 10)
        for x in range(x0 + arch, x1 - arch):
            setp(px, x, y, void)
    # jambs
    for y in range(y0 + 4, y1):
        for t in range(3):
            setp(px, x0 + t, y, shade(jamb, 10 - t * 8))
            setp(px, x1 - 1 - t, y, shade(jamb, -6 + t * 4))
    # arch stones
    for x in range(x0, x1):
        for y in range(y0, y0 + 6):
            dx = abs(x - 32) / 16.0
            dy = (y - y0) / 6.0
            if dx * dx + (1.0 - dy) * (1.0 - dy) < 1.05 and dx * dx + (1.0 - dy) * (1.0 - dy) > 0.55:
                setp(px, x, y, jamb)
    return px


THEMES = {
    "grey_stone": (grey_wall, grey_floor, (70, 74, 84), (8, 8, 12)),
    "brick": (brick_wall, brick_floor, (90, 42, 32), (10, 6, 6)),
    "dirt": (dirt_wall, dirt_floor, (48, 32, 20), (12, 8, 6)),
    "timber": (timber_wall, timber_floor, (70, 46, 24), (10, 6, 4)),
}


def main() -> None:
    for name, (wall_fn, floor_fn, jamb, void) in THEMES.items():
        wall = wall_fn()
        floor = floor_fn()
        entrance = make_entrance(wall, jamb, void)
        write_png(ROOT / name / "wall.png", wall)
        write_png(ROOT / name / "floor.png", floor)
        write_png(ROOT / name / "room_entrance.png", entrance)
        print("wrote", name)


if __name__ == "__main__":
    main()
