class_name CombatMapData
extends RefCounted

## Ultima IV combat / camp map (.CON / CAMP.DNG) — 192-byte layout (FileFormats.md).
## Prefer preload over bare class_name types (stale global class cache → black screen).

const WIDTH := 11
const HEIGHT := 11
const TILE_COUNT := WIDTH * HEIGHT
const AREA_CREATURES := 16
const AREA_PLAYERS := 8
const FILE_SIZE := 192

var tiles: PackedByteArray = PackedByteArray()
var player_start: Array[Vector2i] = []
var creature_start: Array[Vector2i] = []
var source_path: String = ""


func clear() -> void:
	tiles = PackedByteArray()
	tiles.resize(TILE_COUNT)
	tiles.fill(4) ## grass
	player_start.clear()
	creature_start.clear()
	source_path = ""
	for i in AREA_PLAYERS:
		player_start.append(Vector2i(WIDTH / 2, HEIGHT / 2))
	for i in AREA_CREATURES:
		creature_start.append(Vector2i.ZERO)


func tile_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT or tiles.size() < TILE_COUNT:
		return 4
	return int(tiles[y * WIDTH + x])


func set_tile(x: int, y: int, tid: int) -> void:
	if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT or tiles.size() < TILE_COUNT:
		return
	tiles[y * WIDTH + x] = clampi(tid, 0, 255) & 0xFF


func load_from_path(path: String) -> bool:
	clear()
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < FILE_SIZE:
		push_warning("CombatMapData: short file %s (%d bytes)" % [path, bytes.size()])
		return false
	source_path = path

	creature_start.clear()
	for i in AREA_CREATURES:
		creature_start.append(Vector2i(int(bytes[i]), int(bytes[0x10 + i])))

	player_start.clear()
	for i in AREA_PLAYERS:
		player_start.append(Vector2i(int(bytes[0x20 + i]), int(bytes[0x28 + i])))

	tiles = bytes.slice(0x40, 0x40 + TILE_COUNT)
	return true


static func resolve_u4_file(fname: String) -> String:
	## Prefer GameState path, then absolute GOG / data stubs.
	var name := fname.get_file()
	var candidates: Array[String] = []
	if not GameState.u4_data_path.is_empty():
		candidates.append(GameState.u4_data_path.path_join(name))
	candidates.append(GameState.U4_DATA_RES.path_join(name))
	candidates.append(GameState.U4_DATA_ABS.path_join(name))
	for p in candidates:
		if FileAccess.file_exists(p):
			var bytes := FileAccess.get_file_as_bytes(p)
			if bytes.size() >= FILE_SIZE:
				return p
	return ""
