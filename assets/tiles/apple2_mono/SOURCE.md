# Apple II Monochrome (White / Green)

Optional **Apple II Mono White** and **Apple II Mono Green** modes use the same
Program-disk `SHP0` / `SHP1` banks as Color. This repository does **not** ship
pre-rendered PNG tiles or `shapes.u4pack`.

When a Program `.dsk` is set, tiles are built at load time as native-display
**28×32** frames: each 14×16 HGR bit is doubled horizontally and each source
row receives a 25%-brightness Mariani-style scanline. Green remaps luminance to
RGB `(128, 253, 165)` at load. Both modes use the **8.75:10** aspect.

**Copyright:** Origin Systems / Electronic Arts — tile data belongs to the
rights holders. Do not redistribute the raw `.dsk` or extracted tiles.

Developer rebuild (local only, never commit):

```bash
python3 tools/build_a2_u4_mono_tiles.py
python3 tools/build_shape_pack.py mono
```
