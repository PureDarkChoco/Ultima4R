#!/usr/bin/env python3
"""Generate dungeon wall / side / floor / entrance textures.

Rings 3:3:3:2:2:2:3:3:3 (24 units) in dungeon_view.gd. These PNGs are source tiles.
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "assets" / "dungeon"

VIEW = 176
RING = (0, 3, 6, 9, 11, 13)
DENOM = 24
MAX_DRAW = 4


def ring(i: int) -> int:
    idx = max(0, min(i, len(RING) - 1))
    return int(round(VIEW * RING[idx] / DENOM))


def write_png(path: Path, pixels: list[list[tuple[int, int, int]]]) -> None:
    h = len(pixels)
    w = len(pixels[0]) if h else 0
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

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
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


def blank(w: int, h: int, c: tuple[int, int, int]) -> list[list[tuple[int, int, int]]]:
    return [[c for _ in range(w)] for _ in range(h)]


def setp(px: list[list[tuple[int, int, int]]], x: int, y: int, c: tuple[int, int, int]) -> None:
    if 0 <= y < len(px) and 0 <= x < len(px[0]):
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
    h = len(px)
    w = len(px[0]) if h else 0
    for y in range(h):
        for x in range(w):
            d = (hash2(x, y, salt) % (amp * 2 + 1)) - amp
            px[y][x] = shade(px[y][x], d)


def side_wh(depth: int) -> tuple[int, int]:
    w = max(1, ring(depth + 1) - ring(depth))
    h = max(1, VIEW - 2 * ring(depth))
    return w, h


def front_wh(depth: int) -> tuple[int, int]:
    s = max(1, VIEW - 2 * ring(depth))
    return s, s


def floor_wh(depth: int) -> tuple[int, int]:
    inner = max(8, VIEW - 2 * ring(depth + 1))
    band = max(8, ring(depth + 1) - ring(depth))
    return inner, band


def brick_size(depth: int, kind: str) -> tuple[int, int]:
    if kind == "ashlar":
        return max(6, 20 - depth * 5), max(5, 16 - depth * 4)
    if kind == "brick":
        return max(5, 16 - depth * 3), max(3, 8 - depth * 2)
    if kind == "plank":
        return 0, max(3, 8 - depth * 2)
    return max(6, 16 - depth * 4), max(4, 10 - depth * 2)


# --- palettes ---
GS = {
    "base": (58, 62, 72),
    "dark": (36, 38, 46),
    "mid": (78, 84, 96),
    "light": (118, 126, 140),
    "mortar": (28, 30, 36),
    "floor": (48, 50, 58),
    "floor_line": (32, 34, 40),
    "jamb": (70, 74, 84),
    "void": (8, 8, 12),
}
BR = {
    "base": (108, 44, 32),
    "dark": (72, 28, 20),
    "mid": (132, 58, 42),
    "light": (168, 92, 68),
    "mortar": (62, 44, 36),
    "floor": (86, 48, 38),
    "floor_line": (48, 28, 22),
    "jamb": (90, 42, 32),
    "void": (10, 6, 6),
    "alt": (156, 78, 56),
}
DT = {
    "base": (86, 58, 36),
    "dark": (52, 44, 36),
    "mid": (64, 42, 26),
    "light": (108, 76, 48),
    "mortar": (40, 28, 18),
    "floor": (72, 50, 32),
    "floor_line": (48, 34, 22),
    "jamb": (48, 32, 20),
    "void": (12, 8, 6),
}
TM = {
    "base": (74, 50, 32),
    "dark": (56, 38, 24),
    "mid": (92, 62, 32),
    "light": (132, 96, 54),
    "mortar": (36, 36, 38),
    "floor": (70, 48, 30),
    "floor_line": (58, 38, 20),
    "jamb": (70, 46, 24),
    "void": (10, 6, 4),
    "plank": (102, 70, 38),
}


def fill_ashlar(px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int) -> None:
    h = len(px)
    w = len(px[0])
    bw, bh = brick_size(depth, "ashlar")
    px[:] = blank(w, h, pal["mortar"])
    for row, y in enumerate(range(0, h, bh)):
        shift = (bw // 2) if row % 2 else 0
        for x in range(-shift, w, bw):
            tone = mix(pal["mid"], pal["base"], 0.35 if hash2(x, y, salt) % 2 else 0.1)
            rect(px, x + 1, y + 1, x + bw - 1, y + bh - 1, tone)
            for i in range(max(0, bw - 2)):
                setp(px, x + 1 + i, y + 1, pal["light"])
                setp(px, x + 1 + i, y + bh - 2, pal["dark"])
            for i in range(max(0, bh - 2)):
                setp(px, x + 1, y + 1 + i, pal["light"])
                setp(px, x + bw - 2, y + 1 + i, pal["dark"])
            if hash2(x, y, salt + 9) % 5 == 0 and bw >= 10 and bh >= 8:
                cx, cy = x + bw // 2, y + bh // 2
                for dx, dy in ((0, -2), (0, -1), (0, 0), (0, 1), (-2, 0), (-1, 0), (1, 0)):
                    setp(px, cx + dx, cy + dy, mix(pal["dark"], pal["mid"], 0.4))
    dither_noise(px, salt, max(3, 6 - depth))


def fill_running_brick(px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int) -> None:
    h = len(px)
    w = len(px[0])
    bw, bh = brick_size(depth, "brick")
    px[:] = blank(w, h, pal["mortar"])
    for row, y in enumerate(range(0, h, bh)):
        off = (bw // 2) if row % 2 else 0
        for x in range(-off, w, bw):
            tone = pal["mid"] if hash2(x, y, salt) % 2 == 0 else pal["base"]
            if hash2(x, y, salt + 7) % 7 == 0:
                tone = pal.get("alt", pal["light"])
            rect(px, x + 1, y + 1, x + bw - 1, y + bh - 1, tone)
            for i in range(max(0, bw - 2)):
                setp(px, x + 1 + i, y + 1, shade(tone, 22))
                setp(px, x + 1 + i, y + bh - 2, shade(tone, -18))
            setp(px, x + 1, y + 2, shade(tone, 16))
    dither_noise(px, salt, max(3, 7 - depth))


def fill_dirt(px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int) -> None:
    h = len(px)
    w = len(px[0])
    for y in range(h):
        for x in range(w):
            n = hash2(x, y, salt)
            if n < 40:
                px[y][x] = pal["mid"]
            elif n > 220:
                px[y][x] = pal["light"]
            else:
                px[y][x] = pal["base"]
    rocks = max(4, 18 - depth * 4)
    for i in range(rocks):
        cx = hash2(i, 2, salt) % max(1, w)
        cy = hash2(i, 3, salt + 1) % max(1, h)
        rw = 2 + hash2(i, 4, 1) % max(2, 5 - depth)
        rh = 2 + hash2(i, 5, 2) % max(2, 4 - depth)
        for y in range(cy, cy + rh):
            for x in range(cx, cx + rw):
                if (x - cx - rw / 2) ** 2 / max(1, rw * rw) + (y - cy - rh / 2) ** 2 / max(
                    1, rh * rh
                ) < 0.35:
                    setp(px, x, y, pal["dark"])
    if w >= 8:
        roots = max(2, 6 - depth)
        for i in range(roots):
            x = 2 + i * max(3, w // max(1, roots))
            y = 0
            for _ in range(min(h, 10 + (h // 8))):
                setp(px, x, y, pal["mortar"])
                x += (hash2(x, y, salt + 17) % 3) - 1
                y += 1
    dither_noise(px, salt + 10, max(4, 8 - depth))


def fill_timber(px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int) -> None:
    h = len(px)
    w = len(px[0])
    fill_dirt(px, pal, depth, salt)
    post_w = max(2, 6 - depth)
    beam_h = max(2, 5 - depth)
    gap = max(8, 24 - depth * 6)
    posts: list[int] = []
    if w <= post_w + 2:
        posts = [max(0, (w - post_w) // 2)]
    else:
        x = max(0, 2 - depth)
        while x < w:
            posts.append(x)
            x += gap
    for x in posts:
        rect(px, x, 0, x + post_w, h, pal["mid"])
        for y in range(h):
            setp(px, x, y, pal["dark"])
            setp(px, x + post_w - 1, y, pal["light"])
            if y % max(6, 10 - depth) == 0:
                rect(px, max(0, x - 1), y, min(w, x + post_w + 1), y + max(1, 2 - depth), pal["mortar"])
    y = max(1, 4 - depth)
    while y < h:
        rect(px, 0, y, w, y + beam_h, pal["mid"])
        for x in range(w):
            setp(px, x, y, pal["light"])
            setp(px, x, y + beam_h - 1, pal["dark"])
        y += gap
    dither_noise(px, salt + 20, max(3, 6 - depth))


def fill_flag_floor(px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int) -> None:
    """Horizontal bands + dither. No vertical grout (that becomes a vanishing grid)."""
    h = len(px)
    w = len(px[0])
    band = max(3, 8 - depth * 2)
    px[:] = blank(w, h, pal["floor"])
    for y in range(h):
        tone = shade(pal["floor"], 8 if (y // band) % 2 == 0 else -6)
        for x in range(w):
            px[y][x] = tone
        if y % band == 0:
            for x in range(w):
                px[y][x] = pal["floor_line"]
    dither_noise(px, salt, max(3, 5 - depth))


def fill_brick_floor(px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int) -> None:
    fill_flag_floor(px, pal, depth, salt)


def fill_dirt_floor(px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int) -> None:
    h = len(px)
    w = len(px[0])
    px[:] = blank(w, h, pal["floor"])
    for y in range(h):
        for x in range(w):
            n = hash2(x, y, salt)
            if n < 50:
                px[y][x] = pal["floor_line"]
            elif n > 230:
                px[y][x] = shade(pal["floor"], 16)
            if n % 23 == 0:
                px[y][x] = pal["dark"]
    dither_noise(px, salt, max(3, 6 - depth))


def fill_plank_floor(px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int) -> None:
    h = len(px)
    w = len(px[0])
    ph = max(3, 8 - depth * 2)
    px[:] = blank(w, h, pal["floor"])
    for y in range(0, h, ph):
        tone = pal.get("plank", pal["mid"]) if (y // ph) % 2 == 0 else shade(pal.get("plank", pal["mid"]), -12)
        rect(px, 0, y, w, min(h, y + ph), tone)
        for x in range(w):
            setp(px, x, y, pal["floor_line"])
            if hash2(x, y, salt) % 17 == 0 and y + ph // 2 < h:
                setp(px, x, y + ph // 2, pal["floor_line"])
    dither_noise(px, salt, max(3, 5 - depth))


def make_entrance(
    wall: list[list[tuple[int, int, int]]], pal: dict, depth: int
) -> list[list[tuple[int, int, int]]]:
    px = [row[:] for row in wall]
    h = len(px)
    w = len(px[0]) if h else 0
    if w < 8 or h < 8:
        return px
    door_w = max(4, w * 20 // 64)
    door_h = max(6, h * 54 // 64)
    x0 = (w - door_w) // 2
    x1 = x0 + door_w
    y1 = h
    y0 = max(1, h - door_h)
    arch_h = max(3, door_w // 2)
    for y in range(y0, y1):
        arch = 0
        if y < y0 + arch_h:
            yy = (y0 + arch_h - y) / float(arch_h)
            arch = int((1.0 - (1.0 - min(1.0, yy * yy)) ** 0.5) * (door_w * 0.32))
        for x in range(x0 + arch, x1 - arch):
            setp(px, x, y, pal["void"])
    jamb = max(1, 3 - depth)
    for y in range(y0 + max(1, arch_h // 3), y1):
        for t in range(jamb):
            setp(px, x0 + t, y, shade(pal["jamb"], 10 - t * 8))
            setp(px, x1 - 1 - t, y, shade(pal["jamb"], -6 + t * 4))
    return px


THEMES = {
    "grey_stone": {
        "pal": GS,
        "wall": fill_ashlar,
        "floor": fill_flag_floor,
        "salt": 11,
    },
    "brick": {
        "pal": BR,
        "wall": fill_running_brick,
        "floor": fill_brick_floor,
        "salt": 31,
    },
    "dirt": {
        "pal": DT,
        "wall": fill_dirt,
        "floor": fill_dirt_floor,
        "salt": 51,
    },
    "timber": {
        "pal": TM,
        "wall": fill_timber,
        "floor": fill_plank_floor,
        "salt": 91,
    },
}


def paint_wall(theme: dict, w: int, h: int, depth: int) -> list[list[tuple[int, int, int]]]:
    px = blank(w, h, theme["pal"]["base"])
    theme["wall"](px, theme["pal"], depth, theme["salt"] + depth * 13)
    return px


def paint_floor(theme: dict, w: int, h: int, depth: int) -> list[list[tuple[int, int, int]]]:
    px = blank(w, h, theme["pal"]["floor"])
    theme["floor"](px, theme["pal"], depth, theme["salt"] + 40 + depth * 7)
    return px


def main() -> None:
    for name, theme in THEMES.items():
        dest = ROOT / name
        for depth in range(MAX_DRAW + 1):
            fw, fh = front_wh(depth)
            sw, sh = side_wh(depth)
            flw, flh = floor_wh(depth)
            wall = paint_wall(theme, fw, fh, depth)
            side = paint_wall(theme, sw, sh, depth)
            floor = paint_floor(theme, flw, flh, depth)
            entrance = make_entrance(wall, theme["pal"], depth)
            write_png(dest / f"wall_{depth}.png", wall)
            write_png(dest / f"side_{depth}.png", side)
            write_png(dest / f"floor_{depth}.png", floor)
            write_png(dest / f"entrance_{depth}.png", entrance)
            if depth == 0:
                write_png(dest / "wall.png", wall)
                write_png(dest / "floor.png", floor)
                write_png(dest / "room_entrance.png", entrance)
            print(
                f"{name} d{depth}: front {fw}x{fh}  side {sw}x{sh}  floor {flw}x{flh}"
            )


if __name__ == "__main__":
    main()
