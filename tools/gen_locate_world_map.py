#!/usr/bin/env python3
"""Generate a stylized Britannia locate-map PNG from Ultima IV WORLD.MAP.

Output is a strict 256×256 world projection (scaled up) so Locate pins map 1:1.
"""

from __future__ import annotations

import argparse
import math
import os
import struct
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
except ImportError:
    print("Pillow required: python3 -m pip install pillow", file=sys.stderr)
    sys.exit(1)

WORLD = 256
CHUNK = 32

# Cloth-map inspired palette (RGB).
PALETTE = {
    0: (18, 55, 130),  # deep water
    1: (36, 88, 160),  # medium water
    2: (70, 130, 185),  # shallow
    3: (70, 105, 55),  # swamp
    4: (95, 145, 65),  # grass
    5: (75, 125, 50),  # scrub
    6: (35, 95, 40),  # forest
    7: (150, 105, 60),  # hills
    8: (130, 75, 50),  # mountains
    76: (190, 70, 35),  # lava (Abyss)
    100: (148, 144, 132),  # unexplored land (gray, not shallow-blue)
}

TILE_BRIDGE = 23
BRIDGE_FILL = (168, 120, 70)
BRIDGE_EDGE = (95, 60, 30)

# Settlements / keeps / dungeons on the world map.
# LCB is tiles 13–15 side-by-side; only the center keep (14) gets a marker.
SETTLEMENT = {
    9, 10, 11, 12, 13, 14, 15,  # towns / castles / villages / ruins variants
    29, 30,  # dungeon / shrine-ish
    61, 70,  # misc landmarks
}
## Cities / keeps always visible. Dungeon (9) / shrine (30) appear only after explore.
SETTLEMENT_MARK = {10, 11, 12, 14, 29}

SETTLEMENT_FILL = (235, 220, 175)
SETTLEMENT_EDGE = (90, 55, 30)


def default_world_paths() -> list[Path]:
    home = Path.home()
    return [
        Path("/Applications/Ultima™ 4 Quest of the Avatar.app/Contents/Resources/game/WORLD.MAP"),
        Path("data/u4/WORLD.MAP"),
        home / "Documents/Ultima4R/data/u4/WORLD.MAP",
    ]


def load_world(path: Path) -> bytes:
    raw = path.read_bytes()
    if len(raw) != WORLD * WORLD:
        raise SystemExit(f"Expected {WORLD * WORLD} bytes, got {len(raw)} from {path}")
    flat = bytearray(WORLD * WORLD)
    for ych in range(8):
        for xch in range(8):
            src0 = (ych * 8 + xch) * (CHUNK * CHUNK)
            for ly in range(CHUNK):
                for lx in range(CHUNK):
                    wx = xch * CHUNK + lx
                    wy = ych * CHUNK + ly
                    flat[wx + wy * WORLD] = raw[src0 + lx + ly * CHUNK]
    return bytes(flat)


def color_for(tile: int) -> tuple[int, int, int]:
    if tile in PALETTE:
        return PALETTE[tile]
    if tile in SETTLEMENT:
        return SETTLEMENT_FILL
    # Fallback: treat unknown as grass/scrub blend
    if tile < 20:
        return (110, 130, 70)
    return (90, 110, 60)


# Paint order for rounded terrain blobs (later layers win).
TERRAIN_LAYERS: list[tuple[int, tuple[int, int, int]]] = [
    (0, PALETTE[0]),
    (1, PALETTE[1]),
    (2, PALETTE[2]),
    (3, PALETTE[3]),
    (4, PALETTE[4]),
    (5, PALETTE[5]),
    (6, PALETTE[6]),
    (7, PALETTE[7]),
    (8, PALETTE[8]),
    (76, PALETTE[76]),
    (100, PALETTE[100]),
]


def terrain_id(tile: int) -> int:
    """Map WORLD.MAP byte → stylized terrain class (settlements → grass under dots)."""
    if tile == TILE_BRIDGE:
        # Keep river continuity under the bridge; plank drawn as overlay later.
        return 2
    if tile in PALETTE:
        return tile
    if tile in SETTLEMENT:
        return 4
    if tile < 20:
        return 4
    return 5


def paint_base(tiles: bytes) -> Image.Image:
    img = Image.new("RGB", (WORLD, WORLD))
    px = img.load()
    for y in range(WORLD):
        for x in range(WORLD):
            px[x, y] = color_for(tiles[x + y * WORLD])
    return img


def round_class_mask(tiles: bytes, class_id: int, scale: int, radius: float) -> Image.Image:
    """Blur → threshold: rounded silhouette for one terrain class, hard edge."""
    mask = Image.new("L", (WORLD, WORLD))
    mp = mask.load()
    for y in range(WORLD):
        for x in range(WORLD):
            mp[x, y] = 255 if terrain_id(tiles[x + y * WORLD]) == class_id else 0
    w = WORLD * scale
    big = mask.resize((w, w), Image.NEAREST)
    soft = big.filter(ImageFilter.GaussianBlur(radius=radius))
    return soft.point(lambda p: 255 if p >= 128 else 0)


def paint_soft_settlements(img: Image.Image, tiles: bytes, scale: int) -> None:
    """Crisp parchment dots for towns (LCB: center keep only)."""
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    r = max(2.0, scale * 0.42)
    for y in range(WORLD):
        for x in range(WORLD):
            if tiles[x + y * WORLD] not in SETTLEMENT_MARK:
                continue
            cx = (x + 0.5) * scale
            cy = (y + 0.5) * scale
            box = [cx - r - 0.5, cy - r - 0.5, cx + r + 0.5, cy + r + 0.5]
            draw.ellipse(box, fill=(*SETTLEMENT_EDGE, 200))
            box2 = [cx - r * 0.65, cy - r * 0.65, cx + r * 0.65, cy + r * 0.65]
            draw.ellipse(box2, fill=(*SETTLEMENT_FILL, 245))
    base = img.convert("RGBA")
    composed = Image.alpha_composite(base, overlay)
    img.paste(composed.convert("RGB"))


def _bridge_axis(tiles: bytes, x: int, y: int) -> str:
    """Return 'ew' if the river runs N/S (planks east-west), else 'ns'."""
    def tid(xx: int, yy: int) -> int:
        if 0 <= xx < WORLD and 0 <= yy < WORLD:
            return tiles[xx + yy * WORLD]
        return 0

    water = {0, 1, 2}
    ns = sum(1 for dy in (-1, 1) if tid(x, y + dy) in water)
    ew = sum(1 for dx in (-1, 1) if tid(x + dx, y) in water)
    return "ew" if ns >= ew else "ns"


def paint_bridges(img: Image.Image, tiles: bytes, scale: int) -> None:
    """Draw plank bridges over inland water so they stay visible after rounding."""
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for y in range(WORLD):
        for x in range(WORLD):
            if tiles[x + y * WORLD] != TILE_BRIDGE:
                continue
            cx = (x + 0.5) * scale
            cy = (y + 0.5) * scale
            axis = _bridge_axis(tiles, x, y)
            # Slightly longer than one tile so the span reads across the river.
            if axis == "ew":
                hw, hh = scale * 0.72, scale * 0.28
            else:
                hw, hh = scale * 0.28, scale * 0.72
            box = [cx - hw, cy - hh, cx + hw, cy + hh]
            draw.rounded_rectangle(box, radius=max(1, scale * 0.12), fill=(*BRIDGE_EDGE, 230))
            inset = max(0.6, scale * 0.08)
            box2 = [cx - hw + inset, cy - hh + inset, cx + hw - inset, cy + hh - inset]
            draw.rounded_rectangle(box2, radius=max(1, scale * 0.1), fill=(*BRIDGE_FILL, 245))
    base = img.convert("RGBA")
    composed = Image.alpha_composite(base, overlay)
    img.paste(composed.convert("RGB"))


def upscale_stylize(_img: Image.Image, tiles: bytes, scale: int) -> Image.Image:
    """Round ALL terrain borders via per-class blur → argmax (crisp, not foggy)."""
    import numpy as np

    class_ids = [cid for cid, _ in TERRAIN_LAYERS]
    colors = np.array([rgb for _, rgb in TERRAIN_LAYERS], dtype=np.uint8)
    w = WORLD * scale
    radius = max(1.8, scale * 0.7)

    labels = np.frombuffer(bytes(terrain_id(t) for t in tiles), dtype=np.uint8)
    labels = labels.reshape(WORLD, WORLD)
    # Nearest upscale labels.
    lab_big = np.repeat(np.repeat(labels, scale, axis=0), scale, axis=1)

    soft_stack = []
    for cid in class_ids:
        mask = Image.fromarray(((lab_big == cid).astype(np.uint8) * 255), mode="L")
        soft = mask.filter(ImageFilter.GaussianBlur(radius=radius))
        soft_stack.append(np.asarray(soft, dtype=np.float32))
    stack = np.stack(soft_stack, axis=0)  # (C, H, W)
    winner = np.argmax(stack, axis=0)
    out = colors[winner]
    return Image.fromarray(out, mode="RGB")


def quantize_to_palette(img: Image.Image) -> Image.Image:
    """Snap every pixel back to exact terrain colors (keeps edges crisp)."""
    import numpy as np

    palette = np.array([rgb for _, rgb in TERRAIN_LAYERS], dtype=np.int16)
    arr = np.asarray(img.convert("RGB"), dtype=np.int16)
    h, w, _ = arr.shape
    flat = arr.reshape(-1, 3)
    # Nearest palette color by L2.
    dists = ((flat[:, None, :] - palette[None, :, :]) ** 2).sum(axis=2)
    idx = np.argmin(dists, axis=1)
    out = palette[idx].astype(np.uint8).reshape(h, w, 3)
    return Image.fromarray(out, mode="RGB")


def add_cloth_grain(img: Image.Image, amount: float = 0.03) -> Image.Image:
    w, h = img.size
    cell = 4
    small = Image.new("RGB", ((w + cell - 1) // cell, (h + cell - 1) // cell))
    spx = small.load()
    sw, sh = small.size
    for y in range(sh):
        for x in range(sw):
            n = ((x * 374761393 + y * 668265263) ^ (x * y * 97)) & 255
            v = 120 + (n - 128) // 4
            spx[x, y] = (v, v, v)
    noise = small.resize((w, h), Image.BILINEAR)
    return Image.blend(img, noise, amount)


def draw_frame(img: Image.Image) -> Image.Image:
    """Thin parchment rim — no decorative monsters, full map kept."""
    out = img.copy()
    draw = ImageDraw.Draw(out)
    w, h = out.size
    inset = max(2, w // 256)
    draw.rectangle(
        [inset, inset, w - inset - 1, h - inset - 1],
        outline=(210, 195, 150),
        width=max(1, scale_stroke(w)),
    )
    return out


def scale_stroke(w: int) -> int:
    return max(1, w // 512)


ABYSS_SEED = (233, 233)
SKULL_POS = (197, 245)
BELL_POS = (176, 208)
ABYSS_WATER_RADIUS = 10
SKULL_REGION_RADIUS = 12
BELL_REGION_RADIUS = 6
TILE_SILHOUETTE_LAND = 100


def abyss_island(tiles: bytes) -> set[tuple[int, int]]:
    """4-connected land component containing the Abyss entrance (no wrap)."""
    sx, sy = ABYSS_SEED
    if tiles[sx + sy * WORLD] <= 2:
        return set()
    seen = {(sx, sy)}
    q = [(sx, sy)]
    while q:
        x, y = q.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if nx < 0 or ny < 0 or nx >= WORLD or ny >= WORLD:
                continue
            if (nx, ny) in seen:
                continue
            if tiles[nx + ny * WORLD] <= 2:
                continue
            seen.add((nx, ny))
            q.append((nx, ny))
    return seen


def _chebyshev_disk(cx: int, cy: int, radius: int) -> set[tuple[int, int]]:
    out: set[tuple[int, int]] = set()
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            if max(abs(dx), abs(dy)) > radius:
                continue
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < WORLD and 0 <= ny < WORLD:
                out.add((nx, ny))
    return out


def abyss_secret_region(tiles: bytes) -> set[tuple[int, int]]:
    """Abyss island plus nearby sea — never the skull / bell shoals."""
    land = abyss_island(tiles)
    blocked = _chebyshev_disk(*SKULL_POS, SKULL_REGION_RADIUS)
    blocked |= _chebyshev_disk(*BELL_POS, BELL_REGION_RADIUS)
    hide = set(land)
    for x, y in land:
        for dy in range(-ABYSS_WATER_RADIUS, ABYSS_WATER_RADIUS + 1):
            for dx in range(-ABYSS_WATER_RADIUS, ABYSS_WATER_RADIUS + 1):
                if max(abs(dx), abs(dy)) > ABYSS_WATER_RADIUS:
                    continue
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= WORLD or ny >= WORLD:
                    continue
                if (nx, ny) in blocked:
                    continue
                if tiles[nx + ny * WORLD] <= 2:
                    hide.add((nx, ny))
    return hide


def secret_hide_tiles(tiles: bytes) -> set[tuple[int, int]]:
    hide = abyss_secret_region(tiles)
    hide |= _chebyshev_disk(*SKULL_POS, SKULL_REGION_RADIUS)
    hide |= _chebyshev_disk(*BELL_POS, BELL_REGION_RADIUS)
    return hide


def silhouette_tiles(tiles: bytes, reveal_abyss: bool = False) -> bytes:
    """Continent outline only: land vs water. Secret seas look like open ocean."""
    hide = secret_hide_tiles(tiles)
    if reveal_abyss:
        ## Island land + surrounding depths; skull / bell stay hidden.
        hide -= abyss_secret_region(tiles)
    out = bytearray(WORLD * WORLD)
    for y in range(WORLD):
        for x in range(WORLD):
            if (x, y) in hide:
                out[x + y * WORLD] = 0
                continue
            t = tiles[x + y * WORLD]
            if t <= 2:
                out[x + y * WORLD] = t
            else:
                out[x + y * WORLD] = TILE_SILHOUETTE_LAND
    return bytes(out)


def generate(
    world_path: Path,
    out_path: Path,
    scale: int = 4,
    silhouette: bool = False,
    reveal_abyss: bool = False,
) -> None:
    tiles = load_world(world_path)
    if silhouette:
        src = silhouette_tiles(tiles, reveal_abyss=reveal_abyss)
    else:
        src = tiles
    base = paint_base(src)
    stylized = upscale_stylize(base, src, scale)
    stylized = quantize_to_palette(stylized)
    if not silhouette:
        paint_bridges(stylized, tiles, scale)
    paint_soft_settlements(stylized, tiles, scale)
    stylized = draw_frame(stylized)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    stylized.save(out_path, optimize=True)
    kind = "silhouette" if silhouette else "detail"
    if reveal_abyss:
        kind += "+abyss"
    print(f"Wrote {out_path} {kind} ({stylized.size[0]}×{stylized.size[1]}) from {world_path}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--world", type=Path, help="Path to WORLD.MAP")
    ap.add_argument(
        "--out",
        type=Path,
        default=Path("assets/ui/locate/britannia_world.png"),
        help="Output PNG path",
    )
    ap.add_argument(
        "--base-out",
        type=Path,
        default=Path("assets/ui/locate/britannia_world_base.png"),
        help="Silhouette PNG (continent + cities only)",
    )
    ap.add_argument(
        "--abyss-out",
        type=Path,
        default=Path("assets/ui/locate/britannia_world_base_abyss.png"),
        help="Silhouette PNG with Abyss island outline revealed",
    )
    ap.add_argument("--scale", type=int, default=4, help="Pixels per world tile")
    args = ap.parse_args()

    world = args.world
    if world is None:
        for cand in default_world_paths():
            if cand.is_file():
                world = cand
                break
    if world is None or not world.is_file():
        raise SystemExit("WORLD.MAP not found. Pass --world /path/to/WORLD.MAP")

    generate(world, args.out, scale=max(1, args.scale), silhouette=False)
    generate(world, args.base_out, scale=max(1, args.scale), silhouette=True)
    generate(
        world,
        args.abyss_out,
        scale=max(1, args.scale),
        silhouette=True,
        reveal_abyss=True,
    )


if __name__ == "__main__":
    main()
