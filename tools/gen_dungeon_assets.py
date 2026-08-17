#!/usr/bin/env python3
"""Generate dungeon wall / floor / room-entrance source tiles.

dungeon_view.gd crops and scales one tile per kind; it does not load
per-depth wall_N / side_N / floor_N / entrance_N sheets.
"""

from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "assets" / "dungeon"

VIEW = 176
RING = (0, 3, 6, 8.5, 10.5, 12.5)
DENOM = 23


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


def write_rgba_png(
    path: Path, pixels: list[list[tuple[int, int, int, int]]]
) -> None:
    h = len(pixels)
    w = len(pixels[0]) if h else 0
    raw = b"".join(
        b"\x00" + bytes(channel for pixel in row for channel in pixel)
        for row in pixels
    )

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
    "base": (166, 68, 14),
    "dark": (92, 30, 8),
    "mid": (196, 82, 16),
    "light": (232, 132, 30),
    "mortar": (46, 15, 7),
    "floor": (156, 58, 11),
    "floor_line": (61, 18, 7),
    "jamb": (188, 76, 14),
    "void": (8, 4, 3),
    "plank": (184, 73, 13),
    "red": (132, 38, 8),
    "earth": (142, 67, 29),
    "earth_mid": (174, 83, 31),
    "earth_light": (204, 112, 43),
    "earth_dark": (91, 38, 20),
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
    px[:] = blank(w, h, pal["earth"])

    # Packed earth infill: broad irregular patches and cracks, never regular boards.
    for y in range(h):
        for x in range(w):
            fine = hash2(x, y, salt + 11)
            if fine < 18:
                px[y][x] = pal["earth_dark"]
            elif fine > 237:
                px[y][x] = pal["earth_light"]
            elif fine % 17 == 0:
                px[y][x] = pal["earth_mid"]

    patch_count = max(3, w * h // max(80, 260 - depth * 35))
    for patch_index in range(patch_count):
        x0 = hash2(patch_index, depth, salt + 29) % max(1, w)
        y0 = hash2(patch_index, depth, salt + 31) % max(1, h)
        patch_w = 2 + hash2(patch_index, depth, salt + 33) % max(2, 10 - depth * 2)
        patch_h = 2 + hash2(patch_index, depth, salt + 35) % max(2, 7 - depth)
        tone = pal["earth_mid"] if patch_index % 3 else pal["earth_dark"]
        for yy in range(y0, min(h, y0 + patch_h)):
            jag = hash2(patch_index, yy, salt + 37) % 3
            for xx in range(x0 + jag, min(w, x0 + patch_w - (2 - jag))):
                setp(px, xx, yy, tone)
            if yy == y0:
                for xx in range(x0 + jag, min(w, x0 + patch_w - (2 - jag))):
                    if xx % 2 == 0:
                        setp(px, xx, yy, pal["earth_light"])

    crack_count = max(1, min(7, w // max(5, 22 - depth * 3)))
    for crack in range(crack_count):
        x = hash2(crack, depth, salt + 17) % max(1, w)
        y = hash2(crack, depth, salt + 19) % max(1, max(1, h // 3))
        length = max(3, min(h - y, 9 + hash2(crack, depth, salt + 21) % max(4, 23 - depth * 3)))
        for step in range(length):
            if step and step % max(3, 6 - depth) == 0:
                x += (hash2(crack, step, salt + 23) % 3) - 1
            setp(px, x, y + step, pal["earth_dark"])
            if step % 5 == 1:
                setp(px, x + 1, y + step, pal["earth_light"])

    frame = max(2, min(10 - depth, max(2, min(w, h) // 16)))
    _timber_beam(px, 0, 0, frame, h, pal)
    _timber_beam(px, max(0, w - frame), 0, w, h, pal)
    _timber_beam(px, 0, 0, w, frame, pal)

    # Full front panels get one uninterrupted crossbeam over both side posts.
    if w >= h // 2 and w >= 28 and h >= 28:
        cross_y = max(frame + 2, h * 28 // 100)
        _timber_beam(px, 0, cross_y, w, cross_y + frame, pal)


def _timber_beam(
    px: list[list[tuple[int, int, int]]],
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    pal: dict,
) -> None:
    if x1 <= x0 or y1 <= y0:
        return
    rect(px, x0, y0, x1, y1, pal["mortar"])
    inset = 1 if min(x1 - x0, y1 - y0) >= 3 else 0
    rect(px, x0 + inset, y0 + inset, x1 - inset, y1 - inset, pal["mid"])
    if inset:
        for x in range(x0 + 1, x1 - 1):
            setp(px, x, y0 + 1, pal["light"])
            setp(px, x, y1 - 2, pal["dark"])
        for y in range(y0 + 1, y1 - 1):
            setp(px, x0 + 1, y, pal["light"])
            setp(px, x1 - 2, y, pal["dark"])


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


def fill_timber_earth_floor(
    px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int
) -> None:
    h = len(px)
    w = len(px[0])
    px[:] = blank(w, h, pal["earth"])
    for y in range(h):
        for x in range(w):
            fine = hash2(x, y, salt + 7)
            if fine < 20:
                px[y][x] = pal["earth_dark"]
            elif fine > 237:
                px[y][x] = pal["earth_light"]
            elif fine % 19 == 0:
                px[y][x] = pal["earth_mid"]
    streaks = max(3, w // max(5, 13 - depth * 2))
    for i in range(streaks):
        x0 = hash2(i, depth, salt + 13) % max(1, w)
        y = hash2(i, depth, salt + 15) % max(1, h)
        length = 3 + hash2(i, depth, salt + 17) % max(2, 10 - depth)
        tone = pal["earth_dark"] if i % 2 else pal["earth_mid"]
        for yy in range(y, min(h, y + max(1, 3 - depth // 2))):
            inset = hash2(i, yy, salt + 19) % 2
            for x in range(x0 + inset, min(w, x0 + length - inset)):
                setp(px, x, yy, tone)
        for x in range(x0, min(w, x0 + length)):
            if x % 2 == 0:
                setp(px, x, y, pal["earth_light"])


def fill_plank_floor(px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int) -> None:
    h = len(px)
    w = len(px[0])
    ph = max(3, 10 - depth * 2)
    px[:] = blank(w, h, pal["floor"])
    for y in range(0, h, ph):
        tone = pal.get("plank", pal["mid"]) if (y // ph) % 2 == 0 else pal["base"]
        rect(px, 0, y, w, min(h, y + ph), tone)
        for x in range(w):
            setp(px, x, y, pal["floor_line"])
            if y + 1 < h:
                setp(px, x, y + 1, pal["light"])
        grain_y = min(h - 1, y + max(2, ph // 2))
        for x in range(w):
            if hash2(x, y, salt) % 23 == 0:
                length = 2 + hash2(x, y, salt + 8) % max(2, 7 - depth)
                for xx in range(x, min(w, x + length)):
                    setp(px, xx, grain_y, pal["red"] if x % 2 else pal["dark"])


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


def make_timber_entrance(
    wall: list[list[tuple[int, int, int]]], pal: dict, depth: int
) -> list[list[tuple[int, int, int]]]:
    px = [row[:] for row in wall]
    h = len(px)
    w = len(px[0]) if h else 0
    if w < 8 or h < 8:
        return px
    door_w = max(4, w * 36 // 100)
    door_h = max(6, h * 62 // 100)
    x0 = (w - door_w) // 2
    x1 = x0 + door_w
    y0 = h - door_h
    frame = max(1, min(7 - depth, max(1, w // 28)))
    rect(px, x0, y0, x1, h, pal["void"])
    _timber_beam(px, max(0, x0 - frame), y0, x0 + frame, h, pal)
    _timber_beam(px, x1 - frame, y0, min(w, x1 + frame), h, pal)
    _timber_beam(
        px,
        max(0, x0 - frame),
        max(0, y0 - frame),
        min(w, x1 + frame),
        y0 + frame,
        pal,
    )
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
        "floor": fill_timber_earth_floor,
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


def make_fountain(frame: int) -> list[list[tuple[int, int, int, int]]]:
    """32px transparent VGA-style pedestal fountain with animated cyan water."""
    size = 96
    transparent = (0, 0, 0, 0)
    outline = (12, 15, 18, 255)
    stone_dark = (99, 104, 107, 255)
    stone_mid = (163, 168, 171, 255)
    stone = (221, 224, 225, 255)
    highlight = (255, 255, 255, 255)
    water_dark = (0, 135, 202, 255)
    water = (7, 199, 230, 255)
    water_light = (75, 239, 242, 255)
    px = [[transparent for _ in range(size)] for _ in range(size)]

    def dot(x: int, y: int, color: tuple[int, int, int, int], radius: int = 0) -> None:
        for yy in range(y - radius, y + radius + 1):
            for xx in range(x - radius, x + radius + 1):
                if 0 <= xx < size and 0 <= yy < size:
                    px[yy][xx] = color

    def line(
        x0: int, y0: int, x1: int, y1: int,
        color: tuple[int, int, int, int], radius: int = 0
    ) -> None:
        dx = abs(x1 - x0)
        sx = 1 if x0 < x1 else -1
        dy = -abs(y1 - y0)
        sy = 1 if y0 < y1 else -1
        error = dx + dy
        while True:
            dot(x0, y0, color, radius)
            if x0 == x1 and y0 == y1:
                break
            twice = error * 2
            if twice >= dy:
                error += dy
                x0 += sx
            if twice <= dx:
                error += dx
                y0 += sy

    def span(y: int, x0: int, x1: int, color: tuple[int, int, int, int]) -> None:
        for x in range(x0, x1 + 1):
            dot(x, y, color)

    def centered_span(
        y: int, half_width: int, color: tuple[int, int, int, int], center: int = 48
    ) -> None:
        span(y, center - half_width, center + half_width, color)

    # Broad stone pedestal, hidden behind the basin at its top.
    for y in range(57, 95):
        if y < 66:
            outer_half = 18 - (y - 57)
        elif y < 85:
            outer_half = 9
        else:
            outer_half = 9 + (y - 84)
        centered_span(y, outer_half, outline)
        inner_half = max(1, outer_half - 3)
        centered_span(y, inner_half, stone_mid)
        if inner_half > 4:
            span(y, 48 - inner_half + 2, 48 - inner_half + 4, highlight)
            span(y, 48 + inner_half - 3, 48 + inner_half - 1, stone_dark)
    centered_span(94, 21, outline)
    centered_span(92, 18, highlight)

    # Deep, concave bowl: a recessed water surface above a tall shaded front.
    outer_bowl = (
        (38, 27, 69), (39, 19, 77), (40, 13, 83), (41, 9, 87),
        (42, 7, 89), (43, 6, 90), (44, 6, 90), (45, 7, 89),
        (46, 8, 88), (47, 9, 87), (48, 10, 86), (49, 11, 85),
        (50, 12, 84), (51, 14, 82), (52, 16, 80), (53, 18, 78),
        (54, 20, 76), (55, 23, 73), (56, 26, 70), (57, 30, 66),
        (58, 32, 64), (59, 34, 62), (60, 36, 60), (61, 38, 58),
        (62, 40, 56), (63, 42, 54), (64, 44, 52),
    )
    for y, x0, x1 in outer_bowl:
        span(y, x0, x1, outline)
    inner_bowl = (
        (41, 20, 76), (42, 14, 82), (43, 11, 85), (44, 10, 86),
        (45, 11, 85), (46, 12, 84), (47, 13, 83), (48, 14, 82),
        (49, 15, 81), (50, 17, 79), (51, 19, 77), (52, 21, 75),
        (53, 23, 73), (54, 25, 71), (55, 27, 69), (56, 29, 67),
        (57, 32, 64), (58, 35, 61), (59, 38, 58), (60, 41, 55),
    )
    for y, x0, x1 in inner_bowl:
        span(y, x0, x1, stone_dark if y >= 57 else stone_mid if y >= 49 else stone)
    for y, x0, x1 in (
        (42, 24, 72), (43, 20, 76), (44, 19, 77), (45, 22, 74),
        (46, 28, 68),
    ):
        span(y, x0, x1, water_dark)
    for y, x0, x1 in ((42, 30, 66), (43, 25, 71), (44, 26, 70), (45, 31, 65)):
        span(y, x0, x1, water)
    span(40, 22, 74, highlight)
    span(41, 16, 35, highlight)
    span(43, 24, 39, water_light)
    span(46, 14, 30, highlight)
    span(47, 18, 37, highlight)
    span(50, 22, 35, stone)
    span(54, 27, 69, stone)
    span(55, 31, 65, highlight)

    # Slender, low-pressure jets. The two frames gently shift their arcs.
    bob = frame & 1
    jets = (
        [(46, 42), (43, 29), (39, 21 - bob), (35, 18), (31, 21), (29, 30), (29, 39)],
        [(50, 42), (53, 29), (57, 20 + bob), (61, 18), (65, 22), (67, 31), (67, 39)],
    )
    for points in jets:
        for start, end in zip(points, points[1:]):
            line(*start, *end, outline, 1)
        for start, end in zip(points, points[1:]):
            line(*start, *end, water_light)
        for start, end in zip(points[1:], points[2:]):
            line(*start, *end, water)

    # A modest central spout anchors the animation without overpowering the bowl.
    center_top = 22 + bob * 2
    line(48, 43, 48, center_top, outline, 1)
    line(48, 43, 48, center_top, water)
    dot(48, center_top - 1, water_light)
    droplets = (
        ((27, 25), (37, 19), (59, 20), (69, 28))
        if frame == 0 else
        ((28, 29), (38, 22), (58, 18), (68, 31))
    )
    for x, y in droplets:
        dot(x, y, outline, 1)
        dot(x, y, water_light)
    # Author at 3× for readable geometry, then reduce to the same native 32×32
    # resolution as every other U4 tile. Opaque-only voting preserves thin jets.
    reduced = [[transparent for _ in range(32)] for _ in range(32)]
    for tile_y in range(32):
        for tile_x in range(32):
            counts: dict[tuple[int, int, int, int], int] = {}
            for source_y in range(tile_y * 3, tile_y * 3 + 3):
                for source_x in range(tile_x * 3, tile_x * 3 + 3):
                    color = px[source_y][source_x]
                    if color[3] == 0:
                        continue
                    counts[color] = counts.get(color, 0) + 1
            if counts:
                water_colors = [
                    color for color in (water_dark, water, water_light) if color in counts
                ]
                if water_colors and tile_y < 13:
                    reduced[tile_y][tile_x] = max(
                        water_colors, key=lambda color: counts[color]
                    )
                else:
                    reduced[tile_y][tile_x] = max(counts, key=counts.get)
    return reduced


def main() -> None:
    selected = set(sys.argv[1:])
    for name, theme in THEMES.items():
        if selected and name not in selected:
            continue
        dest = ROOT / name
        fw, fh = front_wh(0)
        flw, flh = floor_wh(0)
        wall = paint_wall(theme, fw, fh, 0)
        floor = paint_floor(theme, flw, flh, 0)
        entrance = (
            make_timber_entrance(wall, theme["pal"], 0)
            if name == "timber"
            else make_entrance(wall, theme["pal"], 0)
        )
        write_png(dest / "wall.png", wall)
        write_png(dest / "floor.png", floor)
        write_png(dest / "room_entrance.png", entrance)
        print(f"{name}: wall {fw}x{fh}  floor {flw}x{flh}")
    ## Custom fountain_0/1 art is hand-authored; only rewrite when asked.
    if "fountain" in selected:
        for frame in range(2):
            write_rgba_png(ROOT / f"fountain_{frame}.png", make_fountain(frame))
        print("fountain: 2 transparent 32x32 frames")


if __name__ == "__main__":
    main()
