class_name Moongates
extends RefCounted

## xu4 maps.b moongate positions + updateMoons tile sequence (tiles 64–67).

const TILE_OPENING_0 := 64 ## moongate0 — solid
const TILE_OPENING_1 := 65
const TILE_OPENING_2 := 66
const TILE_OPEN := 67 ## fully open — walkable

## One subphase cycle per Trammel phase: 4s × 4 Hz × 3 Felucca steps = 48 ticks.
const SUBPHASE_CYCLE := 48 ## MOON_SECONDS_PER_PHASE * GAME_CYCLES * 3

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


static func trammel_subphase(moon_phase: int) -> int:
	## xu4: moonPhase % (MOON_SECONDS_PER_PHASE * 4 * 3)
	return posmod(moon_phase, SUBPHASE_CYCLE)


static func tile_for_subphase(sub: int) -> int:
	## Visual annotation tile for the active Trammel gate.
	var s := posmod(sub, SUBPHASE_CYCLE)
	if s == 0:
		return TILE_OPENING_0
	if s == 1:
		return TILE_OPENING_1
	if s == 2:
		return TILE_OPENING_2
	if s == 3:
		return TILE_OPEN
	if s < SUBPHASE_CYCLE - 3:
		return TILE_OPEN
	if s == SUBPHASE_CYCLE - 3:
		return TILE_OPENING_2
	if s == SUBPHASE_CYCLE - 2:
		return TILE_OPENING_1
	return TILE_OPENING_0


static func is_moongate_tile(tid: int) -> bool:
	return tid >= TILE_OPENING_0 and tid <= TILE_OPEN


static func try_destination(at: Vector2i, trammel: int, felucca: int) -> Vector2i:
	## If standing on the active Trammel gate, return Felucca destination; else (-1,-1).
	## xu4 activeMoongateAt — position only (open/closed frames use walk rules separately).
	if at != coords(trammel):
		return Vector2i(-1, -1)
	return coords(felucca)
