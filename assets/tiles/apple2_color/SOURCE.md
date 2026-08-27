# Apple II Color (runtime HGR → Mariani NTSC)

Optional **Apple II Color** mode is unlocked only when the player supplies a
lawfully obtained Ultima IV **Program** disk (`.dsk`, Side A). This repository
does **not** ship extracted tile banks.

At runtime the game reads `SHP0` / `SHP1` from that disk and writes a cache
under `user://apple2/shapes.u4hgr` (banks + AppleWin/Mariani Color Monitor hue
LUT). Explore/city/combat terrain is composed as a continuous HGR bitfield and
decoded with one NTSC pass.

Raw Program-disk `SHP0` / `SHP1` do not include every in-memory animated shape
(water, magic fields, lava). Those slots may stay blank until a later LC-expand
step.

**Copyright:** Origin Systems / Electronic Arts — tile data belongs to the
rights holders. Do not redistribute the raw `.dsk` or extracted banks.

Developer rebuild (local only, never commit):

```bash
python3 tools/build_a2_u4_hgr_pack.py \
    --bank1 reference/apple2_u4/bank1.bin \
    --bank2 reference/apple2_u4/bank2.bin
```
