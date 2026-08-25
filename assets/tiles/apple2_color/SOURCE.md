# Apple II Color (runtime HGR → Mariani NTSC)

In-game **Apple II Color** mode does **not** use per-tile PNG atlases.
It loads `shapes.u4hgr` — only the two 4096-byte Ultima IV Apple II
language-card tile banks plus an embedded AppleWin/Mariani Color Monitor hue
LUT.

The banks are dumped after the original game has loaded and expanded its
animated shapes. Raw Program-disk `SHP0` / `SHP1` are not sufficient by
themselves: water, magic fields, spit and lava are generated or transformed in
memory, and several raw field slots are blank.

At runtime the explore/city/combat terrain grid is composed as a continuous HGR
bitfield and decoded with one NTSC pass (so wall/water seams keep correct
artifact color). HUD / roster / overlays use the same banks decoded per tile.

**Copyright:** Origin Systems / Electronic Arts — tile data extracted from a
lawfully obtained Apple II Ultima IV Program disk for this fan project’s
optional graphics mode. Do not redistribute the raw `.dsk`.

Rebuild the pack from runtime-expanded language-card bank dumps:

```bash
python3 tools/build_a2_u4_hgr_pack.py \
    --bank1 reference/apple2_u4/bank1.bin \
    --bank2 reference/apple2_u4/bank2.bin
```

Runtime: `assets/tiles/apple2_color/shapes.u4hgr`  
Loader: `Apple2HgrNtsc` + `U4TileBank` when Graphics → Apple II Color is selected.
