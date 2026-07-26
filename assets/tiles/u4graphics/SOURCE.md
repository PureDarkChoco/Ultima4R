# u4graphics (32×32)

Source: local copy of `u4graphics-master` (Ultima IV fan tile graphics)  
License: Unlicense (public domain) — see `LICENSE`

| Path | Use |
|------|-----|
| `shapes/` | **Primary** — 256 individual 32×32 PNGs (`000_deep_water.png` … `255.png`). Replace any file to swap that tile id. |
| `shapes.png` | Legacy vertical atlas (32×8192); fallback only if a `shapes/` file is missing |
| `charset.png` | UI font glyphs / moons |
| `gem.png` | Peer gem tiles, 8×8 × 128 (from u4graphics) |

Tile index `0..255` matches Ultima IV `SHAPES` / `WORLD.MAP` bytes.

Runtime loader: `src/map/u4_tile_bank.gd` (`U4TileBank`).

## Animation

**Water (ids 0–2):** Y-axis pixel scroll with wrap (`blit_water_to`), same clock for the whole map.

**White corners (ids 49–52):** blit scrolled shallow water (tile 2), then stamp this tile’s white/stone pixels as a mask.

**Fields / lava (68–71, 76):** same Y-scroll as water on the tile itself (`field_poison` … `field_sleep`, `lava`).

**Same-id frame files** (optional, discrete cycles):

```
049_name.png       ← frame 0
049_name_1.png     ← frame 1 …
```

Classic walk cycles still use consecutive tile ids (`032_mage0` + `033_mage1`).
