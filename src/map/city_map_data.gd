class_name CityMapData
extends RefCounted

## Ultima IV city / castle / village map (.ULT) — first 1024 bytes are 32×32 tiles.
## Prefer preload over bare class_name types (stale global class cache).

const WIDTH := 32
const HEIGHT := 32
const TILE_COUNT := WIDTH * HEIGHT
const TERRAIN_BYTES := 1024
const FILE_MIN := 1024 ## NPC block follows; terrain alone is enough to draw.


var tiles: PackedByteArray = PackedByteArray()
var loaded: bool = false
var source_path: String = ""


func clear() -> void:
	tiles = PackedByteArray()
	tiles.resize(TILE_COUNT)
	tiles.fill(4) ## grass
	loaded = false
	source_path = ""


func tile_at(x: int, y: int) -> int:
	## Out-of-bounds is handled by MapView's outside ring (portal neighbours).
	## Keep grass here as a safe fallback for gameplay queries.
	if not loaded or x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT:
		return 4
	return int(tiles[y * WIDTH + x])


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
	loaded = true
	return true


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
