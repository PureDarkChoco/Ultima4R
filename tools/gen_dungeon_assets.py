#!/usr/bin/env python3
"""Generate dungeon wall / floor / room-entrance source tiles.

dungeon_view.gd crops and scales one tile per kind; it does not load
per-depth wall_N / side_N / floor_N / entrance_N sheets.

`floor_plane` writes a full empty-plaza perspective floor (one slab per
cell) sized to the runtime dungeon field. Walls are drawn over it later.
"""

from __future__ import annotations

import math
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "assets" / "dungeon"

VIEW = 176
## Combat field is 11×32; dungeon_view paints into this buffer.
FIELD = 352
RING = (0, 3, 6, 8.5, 10.5, 12.5)
DENOM = 23
MAX_DEPTH = 4


def ring(i: int) -> int:
    return ring_size(VIEW, i)


def ring_size(size: int, i: int) -> int:
    idx = max(0, min(i, len(RING) - 1))
    return int(round(size * RING[idx] / DENOM))


def read_png(path: Path) -> list[list[tuple[int, int, int]]]:
    data = path.read_bytes()
    pos = 8
    w = h = ctype = 0
    raw = b""
    while pos < len(data):
        ln = struct.unpack(">I", data[pos : pos + 4])[0]
        tag = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + ln]
        pos += 12 + ln
        if tag == b"IHDR":
            w, h, _bit, ctype = struct.unpack(">IIBB", chunk[:10])
        elif tag == b"IDAT":
            raw += chunk
        elif tag == b"IEND":
            break
    raw = zlib.decompress(raw)
    ch = {2: 3, 6: 4}[ctype]
    stride = w * ch + 1
    rows: list[list[tuple[int, int, int]]] = []
    for y in range(h):
        row = raw[y * stride + 1 : (y + 1) * stride]
        pix: list[tuple[int, int, int]] = []
        for i in range(0, len(row), ch):
            pix.append((row[i], row[i + 1], row[i + 2]))
        rows.append(pix)
    return rows


def scale_nearest(
    src: list[list[tuple[int, int, int]]], tw: int, th: int
) -> list[list[tuple[int, int, int]]]:
    sh = len(src)
    sw = len(src[0]) if sh else 0
    if sw <= 0 or sh <= 0 or tw <= 0 or th <= 0:
        return blank(max(1, tw), max(1, th), (0, 0, 0))
    out = blank(tw, th, (0, 0, 0))
    for y in range(th):
        sy = min(sh - 1, int(y * sh / th))
        src_row = src[sy]
        for x in range(tw):
            sx = min(sw - 1, int(x * sw / tw))
            out[y][x] = src_row[sx]
    return out


def crop_center(
    src: list[list[tuple[int, int, int]]], scale: float
) -> list[list[tuple[int, int, int]]]:
    sh = len(src)
    sw = len(src[0]) if sh else 0
    if sw <= 0 or sh <= 0:
        return src
    cw = max(1, min(sw, int(round(float(sw) * scale))))
    ch = max(1, min(sh, int(round(float(sh) * scale))))
    x0 = (sw - cw) // 2
    y0 = (sh - ch) // 2
    return [row[x0 : x0 + cw] for row in src[y0 : y0 + ch]]


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


def dither_pair(
    x: int, y: int, a: tuple[int, int, int], b: tuple[int, int, int]
) -> tuple[int, int, int]:
    return a if ((x + y) & 1) == 0 else b


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
    if kind == "ashlar_large":
        return max(12, 40 - depth * 8), max(10, 32 - depth * 6)
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
    "floor_mid": (48, 50, 58),
    "floor_hi": (66, 70, 80),
    "floor_near": (72, 76, 86),
    "floor_gray": (30, 32, 38),
    "floor_line": (32, 34, 40),
    "jamb": (70, 74, 84),
    "void": (8, 8, 12),
}
LG = {
    "base": (148, 148, 152),
    "dark": (80, 80, 84),
    "mid": (168, 168, 172),
    "light": (196, 196, 200),
    "mortar": (16, 16, 18),
    "floor": (160, 160, 164),
    "floor_mid": (112, 112, 116),
    "floor_hi": (130, 130, 134),
    "floor_lo": (150, 150, 154),
    "floor_near": (148, 148, 152),
    "floor_gray": (28, 28, 32),
    "floor_line": (36, 36, 40),
    "jamb": (176, 176, 180),
    "void": (0, 0, 0),
}
BR = {
    "base": (108, 44, 32),
    "dark": (72, 28, 20),
    "mid": (132, 58, 42),
    "light": (168, 92, 68),
    "mortar": (62, 44, 36),
    "floor": (86, 48, 38),
    "floor_mid": (78, 42, 32),
    "floor_hi": (96, 52, 40),
    "floor_near": (128, 70, 54),
    "floor_gray": (56, 28, 22),
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
    "floor_mid": (102, 38, 14),
    "floor_hi": (124, 50, 18),
    "floor_near": (156, 72, 26),
    "floor_gray": (68, 22, 10),
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
FS = {
    "base": (204, 164, 72),
    "dark": (92, 58, 22),
    "mid": (176, 136, 52),
    "light": (236, 208, 118),
    "mortar": (18, 10, 6),
    "floor": (74, 44, 28),
    "floor_mid": (68, 40, 24),
    "floor_hi": (90, 54, 34),
    "floor_near": (112, 74, 46),
    "floor_gray": (28, 16, 10),
    "floor_line": (22, 12, 8),
    "moss": (42, 108, 32),
    "moss_light": (68, 148, 44),
    "jamb": (176, 146, 92),
    "void": (6, 4, 2),
    "trim": (48, 188, 212),
}
MS = {
    "base": (88, 96, 80),
    "dark": (46, 52, 40),
    "mid": (108, 118, 98),
    "light": (142, 152, 128),
    "mortar": (14, 12, 10),
    "moss": (76, 106, 10),
    "moss_light": (118, 168, 28),
    "moss_dark": (40, 64, 16),
    "floor": (72, 78, 64),
    "floor_mid": (66, 72, 58),
    "floor_hi": (88, 96, 76),
    "floor_near": (118, 126, 104),
    "floor_gray": (18, 16, 12),
    "floor_line": (16, 14, 10),
    "jamb": (124, 132, 112),
    "void": (2, 4, 2),
}
TC = {
    "base": (142, 81, 49),
    "dark": (78, 38, 22),
    "mid": (163, 105, 74),
    "light": (204, 156, 124),
    "alt": (171, 115, 84),
    "mortar": (10, 5, 3),
    "moss": (88, 108, 18),
    "moss_light": (130, 156, 68),
    "moss_dark": (62, 78, 10),
    "floor": (92, 73, 12),
    "floor_mid": (86, 68, 10),
    "floor_hi": (110, 90, 28),
    "floor_near": (120, 100, 42),
    "floor_gray": (22, 16, 8),
    "floor_line": (16, 10, 4),
    "slate": (104, 104, 106),
    "jamb": (176, 122, 88),
    "void": (4, 2, 2),
}
SL = {
    "base": (48, 52, 58),
    "dark": (24, 26, 30),
    "mid": (64, 68, 74),
    "light": (108, 114, 122),
    "mortar": (8, 8, 10),
    "floor": (40, 42, 46),
    "floor_mid": (36, 38, 42),
    "floor_hi": (54, 56, 62),
    "floor_near": (76, 80, 86),
    "floor_gray": (12, 12, 14),
    "floor_line": (8, 8, 10),
    "jamb": (88, 92, 100),
    "void": (2, 2, 4),
}
SS = {
    "base": (92, 74, 50),
    "dark": (48, 34, 22),
    "mid": (118, 96, 66),
    "light": (158, 134, 96),
    "alt": (80, 64, 44),
    "mortar": (8, 6, 4),
    "floor": (22, 20, 22),
    "floor_mid": (20, 18, 20),
    "floor_hi": (32, 28, 28),
    "floor_near": (42, 38, 36),
    "floor_gray": (10, 8, 8),
    "floor_line": (6, 4, 4),
    "jamb": (140, 116, 82),
    "void": (2, 2, 2),
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


def fill_ashlar_large(
    px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int
) -> None:
    """Five equal courses, wrap-safe running bond so left/right halves match."""
    h = len(px)
    w = len(px[0])
    rows = 5
    cols = 4
    bh = h // rows
    bw = w // cols
    if bw < 8:
        bw = max(8, w // max(1, w // 16))
        cols = max(1, w // bw)
    inset = 2 if min(bw, bh) >= 14 else 1
    px[:] = blank(w, h, pal["mortar"])
    for row in range(rows):
        y0 = row * bh
        y1 = h if row == rows - 1 else y0 + bh
        shift = (bw // 2) if row % 2 else 0
        for col in range(cols):
            x0 = col * bw - shift
            heavy = hash2(col, row, salt) % 3 == 0
            for yy in range(y0 + inset, y1 - inset):
                for dx in range(inset, bw - inset):
                    xx = (x0 + dx) % w
                    n = hash2(col * 17 + dx, row * 13 + (yy - y0), salt + 5)
                    if n < 14:
                        tone = pal["light"]
                    elif n > 242:
                        tone = pal["dark"]
                    elif heavy:
                        tone = dither_pair(dx, yy, pal["base"], pal["mid"])
                    else:
                        tone = dither_pair(dx, yy, pal["mid"], pal["light"])
                    setp(px, xx, yy, tone)
            for dx in range(inset, bw - inset):
                xx = (x0 + dx) % w
                setp(px, xx, y0 + inset, pal["light"])
                setp(px, xx, y1 - inset - 1, pal["dark"])
            for yy in range(y0 + inset, y1 - inset):
                setp(px, (x0 + inset) % w, yy, pal["light"])
                setp(px, (x0 + bw - inset - 1) % w, yy, pal["dark"])
            if hash2(col, row, salt + 9) % 8 == 0 and bw >= 18 and (y1 - y0) >= 14:
                cx = (x0 + bw // 2) % w
                cy = (y0 + y1) // 2
                for dx, dy in ((0, -2), (0, -1), (0, 0), (0, 1), (-2, 0), (-1, 0), (1, 0)):
                    setp(px, (cx + dx) % w, cy + dy, mix(pal["dark"], pal["mid"], 0.35))


def _irregular_ashlar_rects(
    w: int, h: int, salt: int
) -> list[tuple[int, int, int, int]]:
    """Fixed 4×5 ashlar: missing grout means those cells are one stone."""
    del salt
    cols, rows = 4, 5
    # (col, row, width, height) in grid cells, matching the reference sketch.
    cells = (
        (0, 0, 2, 2),
        (2, 0, 2, 1),
        (2, 1, 1, 2),
        (3, 1, 1, 1),
        (0, 2, 1, 2),
        (1, 2, 1, 1),
        (3, 2, 1, 2),
        (1, 3, 1, 2),
        (2, 3, 1, 1),
        (0, 4, 1, 1),
        (2, 4, 2, 1),
    )
    stones: list[tuple[int, int, int, int]] = []
    for c, r, cw, rh in cells:
        x0 = c * w // cols
        y0 = r * h // rows
        bw = (c + cw) * w // cols - x0
        bh = (r + rh) * h // rows - y0
        stones.append((x0, y0, bw, bh))
    return stones


def fill_irregular_ashlar(
    px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int
) -> None:
    """Irregular ashlar. Stones wrap left/right, but stop at top and bottom."""
    h = len(px)
    w = len(px[0]) if h else 0
    inset = 1
    px[:] = blank(w, h, pal["mortar"])
    col_id = 0

    def stamp_block(
        x0: int, y0: int, bw: int, bh: int, n0: int, in_l: int, in_r: int, jag_t: int, jag_b: int
    ) -> None:
        fx0 = x0 + in_l
        fy0 = y0 + inset + jag_t
        fw = bw - in_l - in_r
        fh = bh - 2 * inset - jag_t - jag_b
        if fw <= 1 or fh <= 1:
            return
        if n0 < 50:
            face = pal["alt"]
        elif n0 < 140:
            face = pal["base"]
        else:
            face = pal["mid"]
        for dy in range(fh):
            yy = fy0 + dy
            if yy < 0 or yy >= h:
                continue
            for dx in range(fw):
                xx = (fx0 + dx) % w
                n = hash2(fx0 + dx, fy0 + dy, salt + 5)
                if n < 12:
                    tone = pal["light"]
                elif n > 244:
                    tone = pal["dark"]
                else:
                    tone = face
                px[yy][xx] = tone
        for dx in range(fw):
            xx = (fx0 + dx) % w
            if 0 <= fy0 < h:
                px[fy0][xx] = pal["light"]
            bottom = fy0 + fh - 1
            if 0 <= bottom < h:
                px[bottom][xx] = pal["dark"]
        for dy in range(fh):
            yy = fy0 + dy
            if yy < 0 or yy >= h:
                continue
            px[yy][fx0 % w] = pal["light"]
            px[yy][(fx0 + fw - 1) % w] = pal["dark"]

    for x0, y0, bw, bh in _irregular_ashlar_rects(w, h, salt):
        n0 = hash2(col_id, y0, salt)
        stamp_block(x0, y0, bw, bh, n0, inset, inset, 0, 0)
        col_id += 1

    for x in range(w):
        px[0][x] = pal["mortar"]
        px[h - 1][x] = pal["mortar"]
    dither_noise(px, salt, max(2, 5 - depth))


def fill_mossy_ashlar(
    px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int
) -> None:
    """Large grey blocks with mottled lime moss, wrap-safe running bond."""
    fill_ashlar_large(px, pal, depth, salt)
    h = len(px)
    w = len(px[0]) if h else 0
    moss = pal["moss"]
    moss_l = pal.get("moss_light", moss)
    moss_d = pal.get("moss_dark", moss)
    blobs = max(10, w * h // 180)
    for i in range(blobs):
        cx = hash2(i, 3, salt + 41) % w
        cy = hash2(i, 4, salt + 43) % h
        rw = 3 + hash2(i, 5, salt) % 8
        rh = 2 + hash2(i, 6, salt) % 6
        for dy in range(-rh, rh + 1):
            yy = cy + dy
            if yy < 0 or yy >= h:
                continue
            jag = hash2(i, yy, salt + 47) % 3
            for dx in range(-rw + jag, rw - jag + 1):
                xx = (cx + dx) % w
                if px[yy][xx] == pal["mortar"]:
                    continue
                n = hash2(xx, yy, salt + 49)
                if n < 70:
                    px[yy][xx] = moss_l
                elif n < 160:
                    px[yy][xx] = moss
                elif n < 200:
                    px[yy][xx] = moss_d
    for y in range(h):
        for x in range(w):
            if px[y][x] != pal["mortar"]:
                continue
            n = hash2(x, y, salt + 53)
            if n % 11 == 0:
                setp(px, (x + 1) % w, y, moss if n % 2 else moss_d)
            if n % 13 == 0:
                setp(px, x, min(h - 1, y + 1), moss_l)


def fill_terracotta_ashlar(
    px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int
) -> None:
    """Large rust blocks, wrap-safe running bond, moss heavy at the floor line."""
    fill_ashlar_large(px, pal, depth, salt)
    h = len(px)
    w = len(px[0]) if h else 0
    moss = pal["moss"]
    moss_l = pal.get("moss_light", moss)
    moss_d = pal.get("moss_dark", moss)
    blobs = max(6, w * h // 260)
    for i in range(blobs):
        cx = hash2(i, 3, salt + 41) % w
        cy = h // 3 + hash2(i, 4, salt + 43) % max(1, (h * 2) // 3)
        rw = 2 + hash2(i, 5, salt) % 6
        rh = 2 + hash2(i, 6, salt) % 4
        for dy in range(-rh, rh + 1):
            yy = cy + dy
            if yy < 0 or yy >= h:
                continue
            jag = hash2(i, yy, salt + 47) % 3
            for dx in range(-rw + jag, rw - jag + 1):
                xx = (cx + dx) % w
                if px[yy][xx] == pal["mortar"]:
                    continue
                n = hash2(xx, yy, salt + 49)
                if n < 80:
                    px[yy][xx] = moss_l
                elif n < 170:
                    px[yy][xx] = moss
                elif n < 210:
                    px[yy][xx] = moss_d
    skirt = max(8, h * 20 // 100)
    for y in range(h - skirt, h):
        t = float(y - (h - skirt)) / float(max(1, skirt - 1))
        for x in range(w):
            n = hash2(x, y, salt + 59)
            if px[y][x] == pal["mortar"]:
                if n < 90 + int(t * 80):
                    setp(px, (x + 1) % w, y, moss if n % 2 else moss_d)
                continue
            if n < 50 + int(t * 170):
                if n % 5 == 0:
                    px[y][x] = moss_l
                elif n % 3 == 0:
                    px[y][x] = moss_d
                else:
                    px[y][x] = moss


def fill_ochre_flag_floor(
    px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int
) -> None:
    fill_mossy_flag_floor(px, pal, depth, salt)
    slate = pal.get("slate")
    if slate is None:
        return
    h = len(px)
    w = len(px[0])
    for y in range(h):
        for x in range(w):
            n = hash2(x, y, salt + 27)
            if n < 18:
                px[y][x] = slate
            elif n < 26:
                px[y][x] = mix(slate, pal["floor"], 0.45)


def _stamp_boulder(
    px: list[list[tuple[int, int, int]]],
    cx: int,
    cy: int,
    rw: int,
    rh: int,
    pal: dict,
    salt: int,
    key: int,
) -> None:
    """Lumpy ochre boulder: volume highlight, dark underside, thin mortar rim."""
    h = len(px)
    w = len(px[0]) if h else 0
    if w <= 0 or rw < 3 or rh < 3:
        return
    phase = (hash2(key, 1, salt) / 255.0) * math.tau
    wobble = 0.16 + (hash2(key, 2, salt) % 10) / 80.0
    for dy in range(-rh - 2, rh + 3):
        yy = cy + dy
        if yy < 0 or yy >= h:
            continue
        for dx in range(-rw - 2, rw + 3):
            nx = dx / float(rw)
            ny = dy / float(rh)
            rad = math.hypot(nx, ny)
            if rad < 1e-6:
                ang = 0.0
            else:
                ang = math.atan2(ny, nx)
            bump = (
                1.0
                + wobble * math.sin(2.0 * ang + phase)
                + 0.09 * math.sin(5.0 * ang - phase * 1.4)
            )
            t = rad / bump
            if t > 1.04:
                continue
            xx = (cx + dx) % w
            n = hash2(cx + dx, cy + dy, salt + 9)
            if t > 0.86:
                if ny > 0.12 or nx > 0.28:
                    px[yy][xx] = pal["mortar"] if t > 0.96 else pal["dark"]
                else:
                    px[yy][xx] = pal["light"]
                continue
            lit = -nx * 0.38 - ny * 0.72
            if lit > 0.34:
                tone = pal["light"] if n > 50 else mix(pal["light"], pal["mid"], 0.4)
            elif lit < -0.20:
                tone = pal["dark"] if n > 90 else mix(pal["dark"], pal["mid"], 0.45)
            elif n < 28:
                tone = pal["base"]
            elif n > 238:
                tone = shade(pal["mid"], -14)
            else:
                tone = pal["mid"]
            px[yy][xx] = tone


def fill_fieldstone(
    px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int
) -> None:
    """Packed irregular ochre boulders — not a grid of identical ovals."""
    h = len(px)
    w = len(px[0])
    px[:] = blank(w, h, pal["mortar"])
    rows = 5
    cols = 4
    bh = max(8, h // rows)
    bw = max(10, w // cols)
    key = 0
    for row in range(rows):
        y_mid = min(h - 1, row * bh + bh // 2)
        shift = (bw // 2) if row % 2 else 0
        for col in range(cols):
            cx = (
                col * bw
                + bw // 2
                - shift
                + (hash2(col, row, salt + 1) % 7)
                - 3
            ) % w
            cy = y_mid + (hash2(col, row, salt + 5) % 7) - 3
            big = hash2(col, row, salt) % 5 == 0
            rw = max(5, bw // 2 - (0 if big else 1) + (hash2(col, row, salt + 2) % 5) - 1)
            rh = max(4, bh // 2 - (0 if big else 1) + (hash2(col, row, salt + 3) % 4) - 1)
            _stamp_boulder(px, cx, cy, rw, rh, pal, salt, key)
            key += 1
    fillers = max(6, rows * cols // 2)
    for i in range(fillers):
        cx = hash2(i, 3, salt + 29) % w
        cy = hash2(i, 4, salt + 31) % h
        if px[cy][cx] != pal["mortar"]:
            continue
        rw = 3 + hash2(i, 5, salt) % 5
        rh = 3 + hash2(i, 6, salt) % 4
        _stamp_boulder(px, cx, cy, rw, rh, pal, salt, key + i)
    dither_noise(px, salt + 4, max(1, 3 - depth))


def fill_mossy_flag_floor(
    px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int
) -> None:
    fill_flag_floor(px, pal, depth, salt)
    moss = pal.get("moss")
    if moss is None:
        return
    moss_light = pal.get("moss_light", moss)
    h = len(px)
    w = len(px[0])
    band = max(3, 8 - depth * 2)
    for y in range(0, h, band):
        for x in range(w):
            n = hash2(x, y, salt + 21)
            if n % 5 != 0:
                continue
            tone = moss_light if n % 2 == 0 else moss
            setp(px, x, y, tone)
            if n % 3 == 0:
                setp(px, x, y + 1, tone)


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


def fill_timber_earth(
    px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int
) -> None:
    """Packed earth from timber wall panels — no posts or beams."""
    h = len(px)
    w = len(px[0])
    px[:] = blank(w, h, pal["earth"])
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


def fill_timber(px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int) -> None:
    fill_timber_earth(px, pal, depth, salt)
    h = len(px)
    w = len(px[0]) if h else 0
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


def fill_dither_floor(
    px: list[list[tuple[int, int, int]]], pal: dict, depth: int, salt: int
) -> None:
    """Checker mix of a few greys — same average, not a flat fill."""
    h = len(px)
    w = len(px[0])
    band = max(3, 8 - depth * 2)
    for y in range(h):
        for x in range(w):
            n = hash2(x, y, salt)
            if n < 14:
                px[y][x] = pal["light"]
            elif n > 242:
                px[y][x] = pal["dark"]
            else:
                px[y][x] = dither_pair(x, y, pal["mid"], pal["light"])
        if y % band == 0:
            for x in range(w):
                px[y][x] = pal["mortar"]


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


def _stroke_entrance_rim(
    px: list[list[tuple[int, int, int]]], pal: dict, width: int = 3
) -> None:
    """Bevelled stone frame on wall pixels around the void; opening size stays the same."""
    h = len(px)
    w = len(px[0]) if h else 0
    void = pal["void"]
    mortar = pal.get("mortar", pal.get("dark", (8, 8, 8)))
    light = pal.get("light", shade(pal.get("jamb", pal.get("mid", mortar)), 28))
    mid = pal.get("jamb", pal.get("mid", light))
    dark = pal.get("dark", shade(mid, -22))
    dist = [[0] * w for _ in range(h)]
    toward: list[list[tuple[int, int]]] = [[(0, 0)] * w for _ in range(h)]
    queue: list[tuple[int, int]] = []
    for y in range(h):
        for x in range(w):
            if px[y][x] != void:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[ny][nx] != void and dist[ny][nx] == 0:
                    dist[ny][nx] = 1
                    toward[ny][nx] = (-dx, -dy)
                    queue.append((nx, ny))
    q = 0
    while q < len(queue):
        x, y = queue[q]
        q += 1
        if dist[y][x] >= width:
            continue
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and px[ny][nx] != void and dist[ny][nx] == 0:
                dist[ny][nx] = dist[y][x] + 1
                toward[ny][nx] = toward[y][x]
                queue.append((nx, ny))
    for y in range(h):
        for x in range(w):
            d = dist[y][x]
            if d < 1 or d > width:
                continue
            vx, vy = toward[y][x]
            if d == 1:
                tone = mortar
            elif d == width:
                tone = dark if (vy > 0 or vx < 0) else mid
            elif vy > 0 or vx < 0:
                tone = mid
            else:
                tone = light
            px[y][x] = tone


def make_entrance(
    wall: list[list[tuple[int, int, int]]], pal: dict, depth: int
) -> list[list[tuple[int, int, int]]]:
    px = [row[:] for row in wall]
    h = len(px)
    w = len(px[0]) if h else 0
    if w < 8 or h < 8:
        return px
    door_w = max(4, w // 2)
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
    _stroke_entrance_rim(px, pal)
    return px


def make_timber_entrance(
    wall: list[list[tuple[int, int, int]]], pal: dict, depth: int
) -> list[list[tuple[int, int, int]]]:
    px = [row[:] for row in wall]
    h = len(px)
    w = len(px[0]) if h else 0
    if w < 8 or h < 8:
        return px
    door_w = max(4, w // 2)
    door_h = max(6, h * 75 // 100)
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
    _stroke_entrance_rim(px, pal)
    return px


THEMES = {
    "grey_stone": {
        "pal": GS,
        "wall": fill_ashlar,
        "floor": fill_flag_floor,
        "mirror_ceiling": True,
        "salt": 11,
    },
    "lightgrey": {
        "pal": LG,
        "wall": fill_ashlar_large,
        "floor": fill_dither_floor,
        "mirror_ceiling": True,
        "salt": 17,
    },
    "brick": {
        "pal": BR,
        "wall": fill_running_brick,
        "floor": fill_brick_floor,
        "mirror_ceiling": True,
        "salt": 31,
    },
    "dirt": {
        "pal": DT,
        "floor_continuous": True,
        "wall": fill_dirt,
        "floor": fill_dirt_floor,
        "salt": 51,
    },
    "timber": {
        "pal": TM,
        "floor_continuous": True,
        "floor_timber_grid": True,
        "floor_plane_fill": fill_timber_earth,
        "wall": fill_timber,
        "floor": fill_timber_earth_floor,
        "mirror_ceiling": True,
        "salt": 91,
    },
    "fieldstone": {
        "pal": FS,
        "wall_src": "fieldstone/wall_ref.png",
        "wall": fill_fieldstone,
        "floor": fill_mossy_flag_floor,
        "salt": 73,
    },
    "mossy": {
        "pal": MS,
        "wall": fill_mossy_ashlar,
        "floor": fill_mossy_flag_floor,
        "mirror_ceiling": True,
        "salt": 61,
    },
    "terracotta": {
        "pal": TC,
        "wall": fill_terracotta_ashlar,
        "floor": fill_ochre_flag_floor,
        "mirror_ceiling": True,
        "ceiling_from_wall": True,
        "ceiling_mid": (163, 105, 74),
        "ceiling_hi": (175, 124, 94),
        "salt": 47,
    },
    "slate": {
        "pal": SL,
        "wall_src": "slate/wall_ref.png",
        "wall_src_ready": True,
        "wall_crop_scale": 0.62,
        "wall_seam_band": 28,
        "wall_sharpen": 1.40,
        "wall": fill_fieldstone,
        "floor": fill_flag_floor,
        "floor_wall_tiles": True,
        "floor_wall": "slate/wall.png",
        "mirror_ceiling": True,
        "salt": 83,
    },
    "sandstone": {
        "pal": SS,
        "wall": fill_irregular_ashlar,
        "floor": fill_flag_floor,
        "mirror_ceiling": True,
        "ceiling_from_wall": True,
        "ceiling_mid": (92, 74, 50),
        "ceiling_hi": (104, 84, 58),
        "salt": 37,
    },
}


def _remove_stone_pits(
    px: list[list[tuple[int, int, int]]], thresh: int = 215, max_size: int = 5
) -> None:
    """Fill tiny isolated dark blobs on stone faces; keep connected grout."""
    h = len(px)
    w = len(px[0]) if h else 0
    seen = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if seen[y][x] or sum(px[y][x]) >= thresh:
                continue
            stack = [(x, y)]
            seen[y][x] = True
            cells: list[tuple[int, int]] = []
            while stack:
                cx, cy = stack.pop()
                cells.append((cx, cy))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx]:
                        if sum(px[ny][nx]) < thresh:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            if not (1 <= len(cells) <= max_size):
                continue
            border: list[tuple[int, int, int]] = []
            for cx, cy in cells:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < w and 0 <= ny < h and sum(px[ny][nx]) >= thresh:
                        border.append(px[ny][nx])
            if not border:
                continue
            avg = (
                sum(p[0] for p in border) // len(border),
                sum(p[1] for p in border) // len(border),
                sum(p[2] for p in border) // len(border),
            )
            for cx, cy in cells:
                px[cy][cx] = avg


def _wrap_h(px: list[list[tuple[int, int, int]]], band: int = 28) -> None:
    """Roll the cut to the center, cover it with interior stone, roll back."""
    h = len(px)
    w = len(px[0]) if h else 0
    if w < band * 3:
        return
    mid = w // 2
    rolled = [row[mid:] + row[:mid] for row in px]
    orig = [row[:] for row in rolled]
    src0 = max(8, w // 8)
    dst0 = mid - band // 2
    fade_w = max(1, band // 5)
    for y in range(h):
        for i in range(band):
            fade = min(i, band - 1 - i) / fade_w
            if fade <= 0.0:
                continue
            if fade > 1.0:
                fade = 1.0
            s = orig[y][src0 + i]
            d = orig[y][dst0 + i]
            rolled[y][dst0 + i] = (
                int(d[0] + (s[0] - d[0]) * fade),
                int(d[1] + (s[1] - d[1]) * fade),
                int(d[2] + (s[2] - d[2]) * fade),
            )
    px[:] = [row[w - mid :] + row[: w - mid] for row in rolled]


def _wrap_v(px: list[list[tuple[int, int, int]]], band: int = 28) -> None:
    """Vertical counterpart of `_wrap_h`, operating through a transpose."""
    h = len(px)
    w = len(px[0]) if h else 0
    if w <= 0 or h <= 0:
        return
    transposed = [[px[y][x] for y in range(h)] for x in range(w)]
    _wrap_h(transposed, band)
    px[:] = [[transposed[x][y] for x in range(w)] for y in range(h)]


def _sharpen_rgb(
    px: list[list[tuple[int, int, int]]], amount: float = 0.65
) -> None:
    """Sharpen stone edges with a seam-safe four-neighbor unsharp mask."""
    h = len(px)
    w = len(px[0]) if h else 0
    if w <= 0 or h <= 0:
        return
    src = [row[:] for row in px]
    for y in range(h):
        for x in range(w):
            c = src[y][x]
            neighbors = (
                src[y][(x - 1) % w],
                src[y][(x + 1) % w],
                src[(y - 1) % h][x],
                src[(y + 1) % h][x],
            )
            out = []
            for channel in range(3):
                avg = sum(p[channel] for p in neighbors) / 4.0
                value = int(round(c[channel] + (c[channel] - avg) * amount))
                out.append(max(0, min(255, value)))
            px[y][x] = (out[0], out[1], out[2])


def _darken_rgb(
    px: list[list[tuple[int, int, int]]], amount: float = 0.80
) -> None:
    for y, row in enumerate(px):
        for x, (r, g, b) in enumerate(row):
            px[y][x] = (int(r * amount), int(g * amount), int(b * amount))


def paint_wall(theme: dict, w: int, h: int, depth: int) -> list[list[tuple[int, int, int]]]:
    src_name = theme.get("wall_src")
    if src_name:
        src_path = ROOT / src_name
        if src_path.is_file():
            px = [row[:] for row in read_png(src_path)]
            if theme.get("wall_src_ready"):
                crop_scale = float(theme.get("wall_crop_scale", 1.0))
                if crop_scale < 1.0:
                    px = crop_center(px, crop_scale)
                    px = scale_nearest(px, w, h)
                    seam_band = int(theme.get("wall_seam_band", 28))
                    _wrap_h(px, seam_band)
                    _wrap_v(px, seam_band)
                    _sharpen_rgb(px, float(theme.get("wall_sharpen", 0.65)))
                    return px
                if len(px) != h or (px and len(px[0]) != w):
                    px = scale_nearest(px, w, h)
                return px
            _remove_stone_pits(px)
            _wrap_h(px, band=36)
            px = scale_nearest(px, w, h)
            _remove_stone_pits(px)
            _darken_rgb(px)
            return px
    px = blank(w, h, theme["pal"]["base"])
    theme["wall"](px, theme["pal"], depth, theme["salt"] + depth * 13)
    return px


def paint_floor(theme: dict, w: int, h: int, depth: int) -> list[list[tuple[int, int, int]]]:
    px = blank(w, h, theme["pal"]["floor"])
    theme["floor"](px, theme["pal"], depth, theme["salt"] + 40 + depth * 7)
    return px


def _floor_plane_bands(size: int) -> list[tuple[int, int, int, float, float, float, float]]:
    """Near/far Y and center-cell X for each visible depth. Matches dungeon_view.gd."""
    horizon = size // 2
    bands: list[tuple[int, int, int, float, float, float, float]] = []
    for depth in range(MAX_DEPTH + 1):
        y_near = size - ring_size(size, depth)
        if depth >= MAX_DEPTH:
            y_far = horizon
            nx0 = nx1 = size * 0.5
        else:
            y_far = size - ring_size(size, depth + 1)
            nx0 = float(ring_size(size, depth + 1))
            nx1 = float(size - ring_size(size, depth + 1))
        x0 = float(ring_size(size, depth))
        x1 = float(size - ring_size(size, depth))
        bands.append((depth, y_near, y_far, x0, x1, nx0, nx1))
    return bands


def _plaza_col_u(
    x: int, y: int, size: int, cell_near: float
) -> tuple[int, float]:
    """Column and u on the vanishing-line grid (cell width = cell_near at y = size)."""
    cx = size * 0.5
    half = float(size - size // 2)
    t = (float(size) - (float(y) + 0.5)) / half
    if t < 0.0:
        t = 0.0
    elif t > 0.999:
        t = 0.999
    span = float(cell_near) * (1.0 - t)
    if span < 1e-6:
        return 0, 0.5
    col_f = ((float(x) + 0.5) - cx * t) / span
    col = int(math.floor(col_f))
    return col, col_f - float(col)


def _floor_plane_cell(
    x: int, y: int, size: int, bands: list, cell_near: float
) -> tuple[int, int, float, float, float, float] | None:
    """Return (col, depth, u, v, cell_w, cell_h) or None above the horizon."""
    horizon = size // 2
    if y < horizon:
        return None
    for depth, y_near, y_far, _x0, _x1, _nx0, _nx1 in bands:
        if y < y_far or y >= y_near:
            continue
        span = float(y_far - y_near)
        if abs(span) < 0.5:
            continue
        t = (float(y) + 0.5 - float(y_near)) / span
        if t < 0.0:
            t = 0.0
        elif t > 1.0:
            t = 1.0
        col, u = _plaza_col_u(x, y, size, cell_near)
        vanish_t = (float(size) - (float(y) + 0.5)) / float(size - size // 2)
        if vanish_t < 0.0:
            vanish_t = 0.0
        elif vanish_t > 0.999:
            vanish_t = 0.999
        cell_w = float(cell_near) * (1.0 - vanish_t)
        return (col, depth, u, t, cell_w, abs(span))
    return None


def _slab_rgb(
    x: int,
    y: int,
    col: int,
    depth: int,
    u: float,
    v: float,
    pal: dict,
    salt: int,
) -> tuple[int, int, int]:
    """One stone tone for every cell — distance dim comes from a later filter."""
    a = pal.get("floor_mid", pal["mid"])
    b = pal.get("floor_hi", pal["light"])
    return dither_pair(x, y, a, b)


def paint_continuous_floor_plane(
    theme: dict, size: int = FIELD
) -> list[list[tuple[int, int, int, int]]]:
    """Continuous soil ground, no cell grout."""
    pal = theme["pal"]
    fill = theme.get("floor_plane_fill", theme["wall"])
    dirt = blank(size, size, pal.get("earth", pal["base"]))
    fill(dirt, pal, 0, theme["salt"])
    transparent = (0, 0, 0, 0)
    horizon = size // 2
    px: list[list[tuple[int, int, int, int]]] = [
        [transparent for _ in range(size)] for _ in range(size)
    ]
    for y in range(horizon, size):
        row = dirt[y]
        for x in range(size):
            r, g, b = row[x]
            px[y][x] = (r, g, b, 255)
    return px


## Depth-0 post on a VIEW wall tile — floor sills use the same ratio.
TIMBER_WALL_PX = VIEW
TIMBER_FRAME_PX = 10


def _timber_beam_rgb(across: float, width_px: int, pal: dict) -> tuple[int, int, int]:
    """Bevel matching `_timber_beam`: light on across=0, dark on across=1."""
    if width_px <= 2:
        return pal["mortar"] if across < 0.35 else pal["mid"]
    t = across * float(width_px)
    if t < 1.0 or t >= float(width_px) - 1.0:
        return pal["mortar"]
    if t < 2.0:
        return pal["light"]
    if t >= float(width_px) - 2.0:
        return pal["dark"]
    return pal["mid"]


def _timber_beam_width(cell_w: float) -> int:
    return max(2, int(round(cell_w * TIMBER_FRAME_PX / TIMBER_WALL_PX)))


def paint_timber_floor_plane(
    theme: dict, size: int = FIELD
) -> list[list[tuple[int, int, int, int]]]:
    """Earth cells with timber sills on the same vanishing grid as the walls.

    The standing cell is only the front half, so skip the near horizontal sill
    (under the player). Vertical posts still run through that half-cell.
    """
    px = paint_continuous_floor_plane(theme, size)
    pal = theme["pal"]
    salt = theme["salt"] + 19
    horizon = size // 2
    cell_near = float(size)
    bands = _floor_plane_bands(size)
    half = float(size - size // 2)
    # Skip the near lip (size-1): that edge sits under the player.
    ring_ys = [horizon]
    for _depth, _y_near, y_far, _x0, _x1, _nx0, _nx1 in bands:
        ring_ys.append(y_far)

    def cell_w_at(y: int) -> float:
        vanish_t = (float(size) - (float(y) + 0.5)) / half
        vanish_t = min(0.999, max(0.0, vanish_t))
        return max(1.0, cell_near * (1.0 - vanish_t))

    # Sills first so the vertical posts remain visible on top at intersections.
    nearest_sill = max(ring_ys)
    for y in range(horizon, size):
        cw = cell_w_at(y)
        beam = _timber_beam_width(cw)
        nearest = min(ring_ys, key=lambda ry: abs(y - ry))
        if nearest == nearest_sill:
            beam = max(2, int(round(beam * 0.80)))
        half_b = beam * 0.5
        if abs(y - nearest) >= half_b:
            continue
        across = (float(y) - (float(nearest) - half_b)) / float(beam)
        rgb = _timber_beam_rgb(across, beam, pal)
        for x in range(size):
            if px[y][x][3] == 0:
                continue
            tone = rgb
            if tone == pal["mid"]:
                n = hash2(x, y, salt + 3)
                if n % 13 == 0:
                    tone = pal["dark"]
                elif n % 17 == 0:
                    tone = pal["light"]
            px[y][x] = (tone[0], tone[1], tone[2], 255)

    # Posts last (vanishing cell edges), so they cross over every sill.
    for y in range(horizon, size):
        cw = cell_w_at(y)
        beam = _timber_beam_width(cw)
        half_b = beam * 0.5
        for x in range(size):
            hit = _floor_plane_cell(x, y, size, bands, cell_near)
            if hit is None:
                continue
            _col, _depth, u, _v, _cw, _ch = hit
            signed = (u * cw) if u < 0.5 else ((u - 1.0) * cw)
            if abs(signed) >= half_b:
                continue
            across = (signed + half_b) / float(beam)
            rgb = _timber_beam_rgb(across, beam, pal)
            if rgb == pal["mid"]:
                n = hash2(x, y, salt)
                if n % 13 == 0:
                    rgb = pal["dark"]
                elif n % 17 == 0:
                    rgb = pal["light"]
            px[y][x] = (rgb[0], rgb[1], rgb[2], 255)
    if theme.get("mirror_ceiling"):
        _mirror_floor_to_ceiling(px)
    return px


def paint_wall_tile_floor_plane(
    theme: dict, size: int = FIELD, theme_id: str = ""
) -> list[list[tuple[int, int, int, int]]]:
    """Perspective cells textured from the wall tile. No extra cell grout."""
    pal = theme["pal"]
    src_name = theme.get("floor_wall") or theme.get("wall_src")
    wall_path = ROOT / src_name if src_name else ROOT / theme_id / "wall.png"
    wall = read_png(wall_path) if wall_path.is_file() else None
    if wall is None:
        wall = blank(VIEW, VIEW, pal.get("mid", pal["base"]))
        theme["wall"](wall, pal, 0, theme["salt"])
    sw = len(wall[0])
    sh = len(wall)
    cell_near = float(size) / 3.0
    col_center = int(size / cell_near) // 2
    horizon = size // 2
    bands = _floor_plane_bands(size)
    transparent = (0, 0, 0, 0)
    px: list[list[tuple[int, int, int, int]]] = [
        [transparent for _ in range(size)] for _ in range(size)
    ]
    for y in range(horizon, size):
        for x in range(size):
            hit = _floor_plane_cell(x, y, size, bands, cell_near)
            if hit is None:
                continue
            col, depth, u, v, _cell_w, _cell_h = hit
            col -= col_center
            ou = (hash2(col, depth, 11) / 255.0) * 0.55
            ov = (hash2(col, depth, 19) / 255.0) * 0.55
            sx = min(sw - 1, max(0, int(((u * 0.45 + ou) % 1.0) * sw)))
            sy = min(sh - 1, max(0, int(((v * 0.45 + ov) % 1.0) * sh)))
            rgb = wall[sy][sx]
            px[y][x] = (rgb[0], rgb[1], rgb[2], 255)
    if theme.get("mirror_ceiling"):
        _mirror_floor_to_ceiling(px)
    return px


def paint_floor_plane(
    theme: dict, size: int = FIELD, theme_id: str = ""
) -> list[list[tuple[int, int, int, int]]]:
    """Empty-plaza floor: perspective grid of large slabs.

    Ceiling is transparent unless `mirror_ceiling` flips the floor over the horizon.
    """
    if theme.get("floor_wall_tiles"):
        return paint_wall_tile_floor_plane(theme, size, theme_id)
    if theme.get("floor_timber_grid"):
        return paint_timber_floor_plane(theme, size)
    if theme.get("floor_continuous"):
        return paint_continuous_floor_plane(theme, size)
    pal = theme["pal"]
    salt = theme["salt"] + 40
    transparent = (0, 0, 0, 0)
    line_near = pal.get("floor_near", pal["light"])
    line_gray = pal.get("floor_gray", pal["base"])
    cell_near = float(size)
    horizon = size // 2
    bands = _floor_plane_bands(size)
    cells: list[list[tuple[int, int, float, float, float, float] | None]] = [
        [None for _ in range(size)] for _ in range(size)
    ]
    for y in range(horizon, size):
        for x in range(size):
            hit = _floor_plane_cell(x, y, size, bands, cell_near)
            if hit is None:
                continue
            cells[y][x] = hit

    ## near = white front lip, far/side = gray. Rank so white wins on a shared pixel.
    rank = {"side": 1, "far": 2, "near": 3}
    grout_at: list[list[str | None]] = [[None] * size for _ in range(size)]

    def stamp(sx: int, sy: int, kind: str) -> None:
        if not (0 <= sx < size and horizon <= sy < size):
            return
        prev = grout_at[sy][sx]
        if prev is None or rank[kind] >= rank[prev]:
            grout_at[sy][sx] = kind

    def hline(sy: int, kind: str) -> None:
        for x in range(size):
            stamp(x, sy, kind)

    ## Front of the standing cell: a 2px white lip.
    hline(size - 1, "near")
    hline(size - 2, "near")
    ## Each ring: gray far edge of this cell, white near edge of the next.
    for _depth, _y_near, y_far, _x0, _x1, _nx0, _nx1 in bands:
        hline(y_far, "far")
        hline(y_far + 1, "far")
        hline(y_far - 1, "near")
        hline(y_far - 2, "near")
    hline(horizon, "far")
    hline(horizon + 1, "far")

    cx = cy = size // 2

    def line(x0: int, y0: int, x1: int, y1: int, kind: str) -> None:
        dx = abs(x1 - x0)
        sx = 1 if x0 < x1 else -1
        dy = -abs(y1 - y0)
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        x, y = x0, y0
        while True:
            stamp(x, y, kind)
            stamp(x + 1, y, kind)
            if x == x1 and y == y1:
                break
            e2 = err * 2
            if e2 >= dy:
                err += dy
                x += sx
            if e2 <= dx:
                err += dx
                y += sy

    col_span = int(math.ceil(size / cell_near)) + 8
    for col in range(-col_span, col_span + 1):
        line(int(round(col * cell_near)), size, cx, cy, "side")

    px: list[list[tuple[int, int, int, int]]] = [
        [transparent for _ in range(size)] for _ in range(size)
    ]
    for y in range(horizon, size):
        for x in range(size):
            cell = cells[y][x]
            if cell is None:
                continue
            col, depth, u, v, _cell_w, _cell_h = cell
            kind = grout_at[y][x]
            if kind == "near":
                rgb = line_near
            elif kind in ("far", "side"):
                rgb = line_gray
            else:
                rgb = _slab_rgb(x, y, col, depth, u, v, pal, salt)
            px[y][x] = (rgb[0], rgb[1], rgb[2], 255)
    moss = pal.get("moss")
    if moss is not None:
        moss_light = pal.get("moss_light", moss)
        for y in range(horizon, size):
            for x in range(size):
                if grout_at[y][x] is None:
                    continue
                n = hash2(x, y, salt + 41)
                if n % 7 != 0:
                    continue
                tone = moss_light if n % 2 == 0 else moss
                px[y][x] = (tone[0], tone[1], tone[2], 255)
                if n % 3 == 0 and y + 1 < size and grout_at[y + 1][x] is None:
                    if px[y + 1][x][3]:
                        px[y + 1][x] = (tone[0], tone[1], tone[2], 255)
    if theme.get("mirror_ceiling"):
        _mirror_floor_to_ceiling(px)
        if theme.get("ceiling_from_wall"):
            _recolor_ceiling_from_wall(px, theme)
    return px


def _mirror_floor_to_ceiling(
    px: list[list[tuple[int, int, int, int]]],
) -> None:
    """Flip the floor over the horizon into the upper half (ceiling)."""
    size = len(px)
    horizon = size // 2
    for y in range(horizon):
        px[y] = [tuple(p) for p in px[size - 1 - y]]


def _recolor_ceiling_from_wall(
    px: list[list[tuple[int, int, int, int]]], theme: dict
) -> None:
    """Paint the mirrored ceiling with wall top-course tones, brighter than the floor."""
    size = len(px)
    horizon = size // 2
    pal = theme["pal"]
    mid = theme.get("ceiling_mid") or pal.get("base", pal["mid"])
    hi = theme.get("ceiling_hi") or pal.get("mid", mid)
    grout = pal.get("mortar", (8, 6, 4))
    for y in range(horizon):
        for x, c in enumerate(px[y]):
            if c[3] == 0:
                continue
            if 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2] < 18:
                px[y][x] = (grout[0], grout[1], grout[2], 255)
                continue
            tone = hi if ((x + y) & 1) else mid
            px[y][x] = (tone[0], tone[1], tone[2], 255)


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
    if "entrance" in selected:
        selected.discard("entrance")
        names = (
            [name for name in THEMES if name in selected]
            if selected
            else list(THEMES)
        )
        for name in names:
            theme = THEMES[name]
            dest = ROOT / name
            wall = read_png(dest / "wall.png")
            entrance = (
                make_timber_entrance(wall, theme["pal"], 0)
                if name == "timber"
                else make_entrance(wall, theme["pal"], 0)
            )
            write_png(dest / "room_entrance.png", entrance)
            print(f"{name}: room_entrance door {len(wall[0]) // 2}px wide")
        return
    plane_only = "floor_plane" in selected
    if plane_only:
        selected.discard("floor_plane")
        names = (
            [name for name in THEMES if name in selected]
            if selected
            else list(THEMES)
        )
        for name in names:
            theme = THEMES[name]
            plane = paint_floor_plane(theme, FIELD, name)
            dest = ROOT / name / "floor_plane.png"
            write_rgba_png(dest, plane)
            print(f"{name}: floor_plane {FIELD}x{FIELD}")
        return
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
        extra = ""
        write_rgba_png(dest / "floor_plane.png", paint_floor_plane(theme, FIELD, name))
        extra = f"  plane {FIELD}x{FIELD}"
        print(f"{name}: wall {fw}x{fh}  floor {flw}x{flh}{extra}")
    ## Custom fountain_0/1 art is hand-authored; only rewrite when asked.
    if "fountain" in selected:
        for frame in range(2):
            write_rgba_png(ROOT / f"fountain_{frame}.png", make_fountain(frame))
        print("fountain: 2 transparent 32x32 frames")


if __name__ == "__main__":
    main()
