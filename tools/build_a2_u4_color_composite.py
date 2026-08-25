#!/usr/bin/env python3
"""Apple II HGR → composite NTSC color (AppleWin-style), then 32×32 scanline tiles.

Ports the chroma LUT + HGR half-pixel path from AppleWin source/NTSC.cpp
(William S Simms / Michael Pohoreski) — Color TV table (composite).

U4 tiles: leading 0x00 HGR byte (odd-column start), then SHP0 + SHP1.
"""
from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REF = ROOT / "reference" / "apple2_u4"
OUT = REF / "tiles_color_32_scan"

SRC_H = 16
DST = 32
NUM = 256
HALF_PER_BYTE = 14
# pad + left + right → keep only left+right half-pixels
TILE_HALF = HALF_PER_BYTE * 2  # 28

PI = math.pi
RAD_45 = PI * 0.25
RAD_90 = PI * 0.5
CYCLESTART = math.radians(45)

CHROMA_GAIN = 7.438011255
CHROMA_0 = -0.7318893645
CHROMA_1 = 1.2336442711
LUMA_GAIN = 13.71331570
LUMA_0 = -0.3961075449
LUMA_1 = 1.1044202472
SIGNAL_GAIN = 7.614490548
SIGNAL_0 = -0.2718798058
SIGNAL_1 = 0.7465656072

I_TO_R, I_TO_G, I_TO_B = 0.956, -0.272, -1.105
Q_TO_R, Q_TO_G, Q_TO_B = 0.621, -0.647, 1.702


def clamp01(x: float) -> float:
	return 0.0 if x < 0.0 else 1.0 if x > 1.0 else x


class Biquad:
	"""AppleWin NTSC IIR: luma/signal use x0+x2+2*x1; chroma uses -x0+x2 (no 2*x1)."""

	__slots__ = ("x", "y", "gain", "a0", "a1", "mode")

	def __init__(self, gain: float, a0: float, a1: float, mode: str = "luma") -> None:
		self.x = [0.0, 0.0, 0.0]
		self.y = [0.0, 0.0, 0.0]
		self.gain = gain
		self.a0 = a0
		self.a1 = a1
		self.mode = mode  # "luma" | "signal" | "chroma"

	def step(self, z: float) -> float:
		self.x[0] = self.x[1]
		self.x[1] = self.x[2]
		self.x[2] = z / self.gain
		self.y[0] = self.y[1]
		self.y[1] = self.y[2]
		if self.mode == "chroma":
			self.y[2] = -self.x[0] + self.x[2] + (self.a0 * self.y[0]) + (self.a1 * self.y[1])
		else:
			self.y[2] = (
				self.x[0]
				+ self.x[2]
				+ (2.0 * self.x[1])
				+ (self.a0 * self.y[0])
				+ (self.a1 * self.y[1])
			)
		return self.y[2]


def build_hue_tables() -> tuple[list[list[tuple[int, int, int]]], list[list[tuple[int, int, int]]]]:
	"""Return (HueMonitor, HueColorTV) — AppleWin g_aHueMonitor / g_aHueColorTV."""
	filt_sig = Biquad(SIGNAL_GAIN, SIGNAL_0, SIGNAL_1, "signal")
	filt_chroma = Biquad(CHROMA_GAIN, CHROMA_0, CHROMA_1, "chroma")
	filt_luma0 = Biquad(LUMA_GAIN, LUMA_0, LUMA_1, "luma")
	filt_luma1 = Biquad(LUMA_GAIN, LUMA_0, LUMA_1, "luma")

	monitor: list[list[tuple[int, int, int]]] = [[(0, 0, 0)] * 4096 for _ in range(4)]
	tv: list[list[tuple[int, int, int]]] = [[(0, 0, 0)] * 4096 for _ in range(4)]

	for phase in range(4):
		phi = phase * RAD_90 + CYCLESTART
		for s in range(4096):
			t = s
			y0 = y1 = c = i = q = 0.0
			for _n in range(12):
				z = 1.0 if (t & 0x800) else 0.0
				t = (t << 1) & 0xFFFF
				for _k in range(2):
					zz = filt_sig.step(z)
					c = filt_chroma.step(zz)
					y0 = filt_luma0.step(zz)
					y1 = filt_luma1.step(zz - c)
					c = c * 2.0
					i = i + (c * math.cos(phi) - i) / 8.0
					q = q + (c * math.sin(phi) - q) / 8.0
					phi += RAD_45

			def to_rgb(y: float) -> tuple[int, int, int]:
				r64 = y + (I_TO_R * i) + (Q_TO_R * q)
				g64 = y + (I_TO_G * i) + (Q_TO_G * q)
				b64 = y + (I_TO_B * i) + (Q_TO_B * q)
				r32, g32, b32 = clamp01(r64), clamp01(g64), clamp01(b64)
				color = s & 15
				if color == 15:
					r32 = g32 = b32 = 1.0
				if color == 0:
					r32 = g32 = b32 = 0.0
				return (int(r32 * 255), int(g32 * 255), int(b32 * 255))

			monitor[phase][s] = to_rgb(y0)
			tv[phase][s] = to_rgb(y1)
	return monitor, tv


def build_hue_color_tv() -> list[list[tuple[int, int, int]]]:
	_mon, tv = build_hue_tables()
	return tv


def pixel_double_mask() -> list[int]:
	masks = [0] * 128
	for byte in range(0x80):
		m = 0
		for bit in range(7):
			if byte & (1 << bit):
				m |= 3 << (bit * 2)
		masks[byte] = m
	return masks


def write_png(path: Path, w: int, h: int, rgb: bytes) -> None:
	def chunk(tag: bytes, data: bytes) -> bytes:
		return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

	raw = b"".join(b"\x00" + rgb[y * w * 3 : (y + 1) * w * 3] for y in range(h))
	ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
	path.write_bytes(
		b"\x89PNG\r\n\x1a\n"
		+ chunk(b"IHDR", ihdr)
		+ chunk(b"IDAT", zlib.compress(raw, 9))
		+ chunk(b"IEND", b"")
	)


class HgrComposite:
	def __init__(self, hue_tv: list[list[tuple[int, int, int]]], masks: list[int]) -> None:
		self.hue = hue_tv
		self.masks = masks
		self.signal = 0
		self.phase = 0
		self.last_col = 0

	def reset(self) -> None:
		self.signal = 0
		self.phase = 0
		self.last_col = 0

	def process_byte(self, m: int) -> list[tuple[int, int, int]]:
		bits = self.masks[m & 0x7F]
		if m & 0x80:
			bits = (bits << 1) | self.last_col
		out: list[tuple[int, int, int]] = []
		for i in range(HALF_PER_BYTE):
			bit = bits & 1
			if i < HALF_PER_BYTE - 1:
				bits >>= 1
			self.signal = ((self.signal << 1) | bit) & 0xFFF
			out.append(self.hue[self.phase][self.signal])
			self.phase = (self.phase + 1) & 3
		self.last_col = bits & 1
		return out


def decode_tile_row(dec: HgrComposite, bl: int, br: int) -> list[tuple[int, int, int]]:
	"""NTSC-decode one 14-wide tile row into 28 half-pixels.

	Apple II hi-bit delays the byte by half a pixel and spills the last bit into
	the next HGR byte. For isolated remaster tiles that looks like a left gutter
	+ clipped right edge — undo that geometric delay while keeping NTSC color.
	"""
	dec.reset()
	dec.process_byte(0x00)  # odd-column phase (discarded)
	body = dec.process_byte(bl) + dec.process_byte(br)
	tail = dec.process_byte(0x00)
	if (bl | br) & 0x80:
		# Drop the inserted dark half-pixel; recover the bit that spilled into tail.
		return body[1:] + tail[:1]
	return body


def scale_row_nn(row: list[tuple[int, int, int]], dst_w: int) -> list[tuple[int, int, int]]:
	"""Nearest-neighbor scale with both endpoints preserved (no left-heavy bias)."""
	n = len(row)
	if n <= 0:
		return [(0, 0, 0)] * dst_w
	if n == 1:
		return [row[0]] * dst_w
	# floor(x*n/dst) over-represents low indices (widens left gutters). Spread
	# so src[0]→dst[0] and src[n-1]→dst[dst_w-1] with even column weight.
	return [row[round(x * (n - 1) / (dst_w - 1))] for x in range(dst_w)]


def blur_row_h(row: list[tuple[int, int, int]], radius: int = 1) -> list[tuple[int, int, int]]:
	"""Light horizontal box blur — approximates CRT chroma bandwidth on a still PNG."""
	if radius <= 0:
		return row
	n = len(row)
	out: list[tuple[int, int, int]] = []
	for i in range(n):
		rs = gs = bs = cnt = 0
		for d in range(-radius, radius + 1):
			j = i + d
			if 0 <= j < n:
				r, g, b = row[j]
				rs += r
				gs += g
				bs += b
				cnt += 1
		out.append((rs // cnt, gs // cnt, bs // cnt))
	return out


def average_half_pixels(samples: list[tuple[int, int, int]]) -> list[tuple[int, int, int]]:
	"""28 half-pixels → 14 HGR pixels (match mono geometry)."""
	out: list[tuple[int, int, int]] = []
	for i in range(0, len(samples), 2):
		a, b = samples[i], samples[i + 1]
		out.append(((a[0] + b[0]) // 2, (a[1] + b[1]) // 2, (a[2] + b[2]) // 2))
	return out


def bits7(b: int) -> list[int]:
	return [(b >> i) & 1 for i in range(7)]


def wall_hgr_fill_window(bank0: bytes, bank1: bytes, wall_id: int = 57) -> tuple[int, int]:
	"""Horizontal HGR columns where the wall tile is 'solid' enough to define fill.

	Uses columns lit in at least half of the wall's densest column count.
	Returns inclusive [left, right] in 0..13.
	"""
	counts = [0] * 14
	for y in range(SRC_H):
		row = bits7(bank0[y * NUM + wall_id]) + bits7(bank1[y * NUM + wall_id])
		for x, on in enumerate(row):
			if on:
				counts[x] += 1
	thr = max(1, max(counts) // 2)
	cols = [i for i, c in enumerate(counts) if c >= thr]
	if not cols:
		return 0, 13
	return cols[0], cols[-1]


# Terrain that tiles horizontally: Apple II leaves col0 empty for color phase,
# which becomes a black seam in discrete 32×32 cells. Crop those tiles only.
DEFAULT_SEAM_TILE_IDS = frozenset({57, 62, 127})  # stone wall, brick floor, brick wall


def crop_scale_row(
	row: list[tuple[int, int, int]], left: int, right: int, dst_w: int
) -> list[tuple[int, int, int]]:
	"""Crop inclusive [left, right] then nearest-neighbor scale to dst_w."""
	cropped = row[left : right + 1]
	return scale_row_nn(cropped, dst_w)


def edge_fill_tile_rgb(buf: bytearray, size: int = DST, thr: int = 36) -> bytearray:
	"""Stretch lit content to the tile edges — removes HGR color-phase gutters.

	Uses luminance on every row for left/right, and even (bright scan) rows for
	top/bottom so dim scanlines do not shrink the vertical span.
	"""
	pix = [
		[
			(buf[(y * size + x) * 3], buf[(y * size + x) * 3 + 1], buf[(y * size + x) * 3 + 2])
			for x in range(size)
		]
		for y in range(size)
	]
	left, right, top, bottom = size, -1, size, -1
	for y in range(size):
		for x in range(size):
			if sum(pix[y][x]) > thr:
				left = min(left, x)
				right = max(right, x)
				if y % 2 == 0:
					top = min(top, y)
					bottom = max(bottom, y)
	if right < left or bottom < top:
		return buf
	# Include the dim scanline under the last lit row when present.
	if bottom + 1 < size and bottom % 2 == 0:
		bottom += 1
	cw = right - left + 1
	ch = bottom - top + 1
	if cw >= size and ch >= size:
		return buf
	out = bytearray(size * size * 3)
	for y in range(size):
		sy = top if ch <= 1 else top + round(y * (ch - 1) / (size - 1))
		for x in range(size):
			sx = left if cw <= 1 else left + round(x * (cw - 1) / (size - 1))
			c = pix[sy][sx]
			i = (y * size + x) * 3
			out[i] = c[0]
			out[i + 1] = c[1]
			out[i + 2] = c[2]
	return out


def parse_id_set(text: str) -> set[int]:
	out: set[int] = set()
	for part in text.split(","):
		part = part.strip()
		if not part:
			continue
		out.add(int(part, 0))
	return out


def idealized_hgr_row(bl: int, br: int, phase0: int = 1) -> list[tuple[int, int, int]]:
	"""Sharp Apple II artifact colors: each even/odd bit-pair → one solid palette color.

	No NTSC IIR — crisp remaster look. phase0=1 matches U4 odd-column start.
	"""
	PAL0 = {
		0b00: (0, 0, 0),
		0b01: (0x2F, 0xBC, 0x1A),
		0b10: (0xC0, 0x37, 0xCE),
		0b11: (0xFF, 0xFF, 0xFF),
	}
	PAL1 = {
		0b00: (0, 0, 0),
		0b01: (0xE6, 0x7E, 0x22),
		0b10: (0x1B, 0x9A, 0xE7),
		0b11: (0xFF, 0xFF, 0xFF),
	}
	bits = bits7(bl) + bits7(br)
	hi = [((bl >> 7) & 1)] * 7 + [((br >> 7) & 1)] * 7
	out: list[tuple[int, int, int] | None] = [None] * 14
	for x in range(14):
		abs_x = x + phase0
		if abs_x % 2 == 1:
			continue
		b0 = bits[x]
		b1 = bits[x + 1] if x + 1 < 14 else 0
		color = (PAL1 if hi[x] else PAL0)[(b0 << 1) | b1]
		out[x] = color
		if x + 1 < 14:
			out[x + 1] = color
	for x in range(14):
		if out[x] is not None:
			continue
		left = bits[x - 1] if x - 1 >= 0 else 0
		even_x = x - 1 if x - 1 >= 0 else 0
		out[x] = (PAL1 if hi[even_x] else PAL0)[(left << 1) | bits[x]]
	return [c if c is not None else (0, 0, 0) for c in out]  # type: ignore


def main() -> None:
	import argparse
	import shutil

	ap = argparse.ArgumentParser(description=__doc__)
	ap.add_argument(
		"--mode",
		choices=("idealized", "monitor", "tv"),
		default="monitor",
		help="idealized=sharp 6-color; monitor=Mariani Composite Monitor (default); tv=Color TV",
	)
	ap.add_argument(
		"--blur",
		type=int,
		default=0,
		help="extra horizontal box-blur radius after NTSC (default 0)",
	)
	ap.add_argument(
		"--wall-fill",
		action="store_true",
		help="crop ALL tiles to wall solid columns (clips sprites — prefer default seam-tiles)",
	)
	ap.add_argument(
		"--wall-id",
		type=int,
		default=57,
		help="tile id used to measure seam/fill window (default 57)",
	)
	ap.add_argument(
		"--seam-tiles",
		default=",".join(str(i) for i in sorted(DEFAULT_SEAM_TILE_IDS)),
		help="tile ids that crop to wall fill window for seamless tiling (default 57,62,127)",
	)
	ap.add_argument(
		"--no-seam-fill",
		action="store_true",
		help="disable per-tile seam crop (keep full 0..13 for every tile)",
	)
	ap.add_argument(
		"--no-edge-fill",
		action="store_true",
		help="keep native gutters (default stretches lit content to 32×32 edges)",
	)
	args = ap.parse_args()

	bank0 = (REF / "shp0.bin").read_bytes()
	bank1 = (REF / "shp1.bin").read_bytes()
	if len(bank0) != 4096 or len(bank1) != 4096:
		raise SystemExit("missing shp0.bin/shp1.bin — run extract_a2_u4_tiles.py first")

	for junk in (
		REF / "tiles_color_32_composite",
		REF / "tiles_color_32_composite.png",
	):
		if junk.is_dir():
			shutil.rmtree(junk)
		elif junk.exists():
			junk.unlink()

	seam_left, seam_right = wall_hgr_fill_window(bank0, bank1, args.wall_id)
	seam_ids: set[int] = set()
	if args.wall_fill:
		seam_ids = set(range(NUM))
	elif not args.no_seam_fill:
		seam_ids = parse_id_set(args.seam_tiles)
	print(
		f"seam HGR [{seam_left}..{seam_right}] on "
		f"{'ALL' if args.wall_fill else sorted(seam_ids) or 'none'}; "
		f"others [0..13] → {DST}"
	)
	print(f"mode={args.mode} blur={args.blur} (NTSC half-pixels + hi-bit align)")
	edge_fill = not args.no_edge_fill
	print(f"edge_fill={'on' if edge_fill else 'off'}")

	dec = None
	if args.mode != "idealized":
		print("Building AppleWin/Mariani NTSC chroma LUT…")
		mon, tv = build_hue_tables()
		hue = mon if args.mode == "monitor" else tv
		dec = HgrComposite(hue, pixel_double_mask())

	out_dir = REF / "tiles_color_32_scan"
	out_dir.mkdir(parents=True, exist_ok=True)
	aw = 16 * DST
	atlas = bytearray(aw * aw * 3)

	def dim25(c: tuple[int, int, int]) -> tuple[int, int, int]:
		# Mariani/AppleWin VS_HALF_SCANLINES: (color & 0x00fcfcfc) >> 2 ≈ 25%
		return ((c[0] & 0xFC) >> 2, (c[1] & 0xFC) >> 2, (c[2] & 0xFC) >> 2)

	def window_for(tid: int) -> tuple[int, int]:
		if tid in seam_ids:
			return seam_left, seam_right
		return 0, 13

	for tid in range(NUM):
		left, right = window_for(tid)
		buf = bytearray(DST * DST * 3)
		for sy in range(SRC_H):
			bl = bank0[sy * NUM + tid]
			br = bank1[sy * NUM + tid]
			if args.mode == "idealized":
				hgr = idealized_hgr_row(bl, br)
				scaled = crop_scale_row(hgr, left, right, DST)
			else:
				assert dec is not None
				samples = decode_tile_row(dec, bl, br)
				samples = blur_row_h(samples, args.blur)
				scaled = crop_scale_row(samples, left * 2, right * 2 + 1, DST)
			y0 = sy * 2
			for x in range(DST):
				buf[(y0 * DST + x) * 3 : (y0 * DST + x) * 3 + 3] = bytes(scaled[x])
			# 50% scanlines like Mariani Composite Monitor (dim, not black)
			for x in range(DST):
				d = dim25(scaled[x])
				buf[((y0 + 1) * DST + x) * 3 : ((y0 + 1) * DST + x) * 3 + 3] = bytes(d)

		if edge_fill:
			buf = edge_fill_tile_rgb(buf)
		write_png(out_dir / f"{tid:03d}.png", DST, DST, bytes(buf))
		tx, ty = tid % 16, tid // 16
		for y in range(DST):
			for x in range(DST):
				si = (y * DST + x) * 3
				di = ((ty * DST + y) * aw + (tx * DST + x)) * 3
				atlas[di : di + 3] = buf[si : si + 3]

	write_png(REF / "tiles_color_32_scan.png", aw, aw, bytes(atlas))
	(out_dir / "SOURCE.txt").write_text(
		f"32×32 Apple II color via Mariani/AppleWin NTSC (mode={args.mode}, blur={args.blur}).\n"
		f"Source: AppleWin-Mariani NTSC.cpp VT_COLOR_MONITOR_NTSC → g_aHueMonitor.\n"
		f"NTSC half-pixel decode with hi-bit unshift; endpoint-preserving scale.\n"
		f"edge_fill={'on' if edge_fill else 'off'} (stretch lit content to tile edges).\n"
		f"Seam tiles {sorted(seam_ids) if not args.wall_fill else 'ALL'} use HGR "
		f"[{seam_left}..{seam_right}]; others [0..13]. Scanlines = 25% dim.\n"
		"python3 tools/build_a2_u4_color_composite.py --mode monitor\n",
		encoding="utf-8",
	)
	print(f"Wrote {out_dir}")

	# Monochrome must retain native 14×16 geometry (28×32 with scanlines);
	# do not reuse this color remaster's 32×32 crop/stretch path.
	print("Mono tiles: run tools/build_a2_u4_mono_tiles.py (native 28×32)")

	legacy = REF / "tiles_mono_32scan"
	if legacy.is_dir():
		shutil.rmtree(legacy)
	legacy_atlas = REF / "tiles_mono_32scan_atlas.png"
	if legacy_atlas.exists():
		legacy_atlas.unlink()


if __name__ == "__main__":
	main()
