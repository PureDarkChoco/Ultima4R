class_name Moongates
extends RefCounted

## xu4 maps.b moongate positions; rise/fall is a bottom-anchored height wipe
## (intro-style: top of the art rises up). Color rotation is separate.

const TILE_OPENING_0 := 64 ## solid stand-in while rising/falling
const TILE_OPENING_1 := 65
const TILE_OPENING_2 := 66
const TILE_OPEN := 67 ## fully open — walkable

## One subphase cycle per Trammel phase: 4s × 4 Hz × 3 Felucca steps = 48 ticks.
const SUBPHASE_CYCLE := 48
## Time budget for full sprout (~0.52s). MapView: 32 tile-px × step sec.
const RISE_TICKS := 3
const FALL_TICKS := 3

## Phase 0..7 → world coordinates (Moonglow … Magincia).
const COORDS: Array[Vector2i] = [
	Vector2i(224, 133), ## 0 Moonglow
	Vector2i(96, 102), ## 1 Britain
	Vector2i(38, 224), ## 2 Jhelom
	Vector2i(50, 37), ## 3 Yew
	Vector2i(166, 19), ## 4 Minoc
	Vector2i(104, 194), ## 5 Trinsic
	Vector2i(23, 126), ## 6 Skara Brae
	Vector2i(187, 167), ## 7 Magincia
]


static func coords(phase: int) -> Vector2i:
	return COORDS[clampi(phase, 0, COORDS.size() - 1)]


static func phase_at(pos: Vector2i) -> int:
	## Moon-phase index of this gate tile, or -1 if not a moongate.
	for i in COORDS.size():
		if COORDS[i] == pos:
			return i
	return -1


static func trammel_subphase(moon_phase: int) -> int:
	## xu4: moonPhase % (MOON_SECONDS_PER_PHASE * 4 * 3)
	return posmod(moon_phase, SUBPHASE_CYCLE)


static func height_frac(sub: int) -> float:
	## Target only: 0 while falling/hidden, 1 while risen/rising.
	## Actual sprouting is 1 source-tile pixel / 0.1s in MapView (not screen pixels).
	var s := posmod(sub, SUBPHASE_CYCLE)
	if s >= SUBPHASE_CYCLE - FALL_TICKS:
		return 0.0
	## From the moment the gate should exist, climb to full tile height in MapView.
	return 1.0


static func tile_for_subphase(sub: int) -> int:
	## Walkable only after the rise time budget (≈32×0.1s); solid while sprouting/falling.
	var s := posmod(sub, SUBPHASE_CYCLE)
	if s >= SUBPHASE_CYCLE - FALL_TICKS:
		return TILE_OPENING_0
	if s < RISE_TICKS:
		return TILE_OPENING_0
	return TILE_OPEN


static func is_moongate_tile(tid: int) -> bool:
	return tid >= TILE_OPENING_0 and tid <= TILE_OPEN


static func try_destination(at: Vector2i, trammel: int, felucca: int) -> Vector2i:
	## If standing on the active Trammel gate, return Felucca destination; else (-1,-1).
	if at != coords(trammel):
		return Vector2i(-1, -1)
	return coords(felucca)
