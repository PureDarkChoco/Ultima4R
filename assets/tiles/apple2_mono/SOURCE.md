# Apple II Monochrome (White / Green)

Optional **Apple II Mono White** and **Apple II Mono Green** graphics modes
share pre-rendered white monochrome tile PNGs (`shapes/*.png`, packed as
`shapes.u4pack`).

Source frames are native-display **28×32**: each 14×16 HGR shape bit is
doubled horizontally and each source row receives a 25%-brightness
Mariani-style scanline.
Green is produced at load time by preserving source luminance and mapping full
white to RGB `(128, 253, 165)`, sampled from the supplied green-monitor image.
No duplicate green assets are stored. Both modes are displayed at the native
**8.75:10** aspect.

**Copyright:** Origin Systems / Electronic Arts — derived from a lawfully
obtained Apple II Ultima IV Program disk for this fan project’s optional
graphics mode. Do not redistribute the raw `.dsk`.

Rebuild the native tiles and pack from disk SHP + runtime-expanded animated
banks (water/fields/lava). The builder merges SHP0/SHP1 with bank1/bank2 so
static shapes stay authoritative:

```bash
python3 tools/build_a2_u4_mono_tiles.py
python3 tools/build_shape_pack.py mono
```
