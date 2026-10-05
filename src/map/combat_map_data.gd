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


static func rotate_pos_cw(pos: Vector2i, quarter_turns: int = 1) -> Vector2i:
	var rotated := pos
	for _i in posmod(quarter_turns, 4):
		rotated = Vector2i(WIDTH - 1 - rotated.y, rotated.x)
	return rotated


func rotate_quarter_turns(quarter_turns: int) -> void:
	var turns := posmod(quarter_turns, 4)
	if turns == 0:
		return
	for _turn in turns:
		var rotated := PackedByteArray()
		rotated.resize(TILE_COUNT)
		for y in HEIGHT:
			for x in WIDTH:
				var target := rotate_pos_cw(Vector2i(x, y))
				rotated[target.y * WIDTH + target.x] = tiles[y * WIDTH + x]
		tiles = rotated
		for i in player_start.size():
			player_start[i] = rotate_pos_cw(player_start[i])
		for i in creature_start.size():
			creature_start[i] = rotate_pos_cw(creature_start[i])


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


func load_shrine_from_path(path: String) -> bool:
	## xu4 Map::SHRINE: loadCombatMap skips creature/player starts — tiles at offset 0.
	clear()
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < TILE_COUNT:
		push_warning("CombatMapData: short shrine file %s (%d bytes)" % [path, bytes.size()])
		return false
	source_path = path
	tiles = bytes.slice(0, TILE_COUNT)
	return true


static func resolve_u4_file(fname: String) -> String:
	## Prefer GameState path, then absolute GOG / data stubs. Match any filename case.
	var path := GameState.resolve_u4_file(fname)
	if path.is_empty():
		return ""
	var bytes := FileAccess.get_file_as_bytes(path)
	return path if bytes.size() >= FILE_SIZE else ""
