class_name CityMapData
extends RefCounted

## Ultima IV city / castle / village map (.ULT).
## Bytes 0..1023: 32×32 terrain. Bytes 1024..1279: 32 NPC records (xu4 layout).
## Prefer preload over bare class_name types (stale global class cache).

const WIDTH := 32
const HEIGHT := 32
const TILE_COUNT := WIDTH * HEIGHT
const TERRAIN_BYTES := 1024
const NPC_MAX := 32
const NPC_BLOCK := 8 * NPC_MAX ## 256 — tile/x/y/prev + pad + move/conv
const FILE_MIN := TERRAIN_BYTES
const FILE_FULL := TERRAIN_BYTES + NPC_BLOCK

## xu4 PersonDataOffset (column-major arrays of 32).
const PD_TILE := 0
const PD_X := NPC_MAX
const PD_Y := 2 * NPC_MAX
const PD_PREV_TILE := 3 * NPC_MAX
const PD_MOVE := 6 * NPC_MAX
const PD_CONV := 7 * NPC_MAX


## Terrain ids, row-major.
var tiles: PackedByteArray = PackedByteArray()
## Visible townsfolk: Vector3i(x, y, tile_id). tile_id 0 entries are skipped.
var persons: Array[Vector3i] = []
## Animation partner tile per person (same index as persons); -1 if none.
var person_prev: Array[int] = []
var loaded: bool = false
var source_path: String = ""


func clear() -> void:
	tiles = PackedByteArray()
	tiles.resize(TILE_COUNT)
	tiles.fill(4) ## grass
	persons.clear()
	person_prev.clear()
	loaded = false
	source_path = ""


func tile_at(x: int, y: int) -> int:
	## Out-of-bounds is handled by MapView's outside ring (portal neighbours).
	## Keep grass here as a safe fallback for gameplay queries.
	if not loaded or x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT:
		return 4
	return int(tiles[y * WIDTH + x])


func person_tile_at(x: int, y: int) -> int:
	## First NPC tile on this cell, or -1.
	for p in persons:
		if int(p.x) == x and int(p.y) == y:
			return int(p.z)
	return -1


func load_from_path(path: String) -> bool:
	clear()
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < TERRAIN_BYTES:
		push_warning("CityMapData: short file %s (%d bytes)" % [path, bytes.size()])
		return false
	source_path = path
	tiles = bytes.slice(0, TERRAIN_BYTES)
	_load_persons(bytes)
	loaded = true
	return true


func _load_persons(bytes: PackedByteArray) -> void:
	## xu4 loadCityMap person block after terrain.
	persons.clear()
	person_prev.clear()
	if bytes.size() < FILE_FULL:
		return
	var pd := bytes.slice(TERRAIN_BYTES, FILE_FULL)
	for i in NPC_MAX:
		var tid := int(pd[PD_TILE + i])
		if tid == 0:
			continue
		var x := int(pd[PD_X + i])
		var y := int(pd[PD_Y + i])
		if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT:
			continue
		persons.append(Vector3i(x, y, tid))
		var prev := int(pd[PD_PREV_TILE + i])
		person_prev.append(prev if prev != 0 else -1)


static func resolve_u4_file(fname: String) -> String:
	## Prefer GameState path; try exact + upper/lower case names.
	var base := fname.get_file()
	var names: Array[String] = [base, base.to_upper(), base.to_lower()]
	var candidates: Array[String] = []
	for n in names:
		if not GameState.u4_data_path.is_empty():
			candidates.append(GameState.u4_data_path.path_join(n))
		candidates.append(GameState.U4_DATA_RES.path_join(n))
		candidates.append(GameState.U4_DATA_ABS.path_join(n))
	for p in candidates:
		if FileAccess.file_exists(p):
			var bytes := FileAccess.get_file_as_bytes(p)
			if bytes.size() >= FILE_MIN:
				return p
	return ""
