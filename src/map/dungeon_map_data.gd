class_name DungeonMapData
extends RefCounted

## Ultima IV .DNG — 8×8×8 corridor maps + 256-byte room records (16 / Abyss 64).
## Prefer preload over bare class_name types (stale global class cache).

const WIDTH := 8
const HEIGHT := 8
const LEVELS := 8
const LEVEL_BYTES := WIDTH * HEIGHT
const MAP_BYTES := LEVEL_BYTES * LEVELS
const ROOM_BYTES := 256
const ROOM_MAP_W := 11
const ROOM_MAP_H := 11
const ROOM_MAP_COUNT := ROOM_MAP_W * ROOM_MAP_H
const TRIGGERS := 4
const AREA_CREATURES := 16
const AREA_PLAYERS := 8
const REGULAR_ROOMS := 16
const ABYSS_ROOMS := 64
const FILE_REGULAR := MAP_BYTES + REGULAR_ROOMS * ROOM_BYTES
const FILE_ABYSS := MAP_BYTES + ABYSS_ROOMS * ROOM_BYTES

## High nibble tokens (xu4 DungeonToken).
const TOK_CORRIDOR := 0x00
const TOK_LADDER_UP := 0x10
const TOK_LADDER_DOWN := 0x20
const TOK_LADDER_BOTH := 0x30
const TOK_CHEST := 0x40
const TOK_CEILING_HOLE := 0x50
const TOK_FLOOR_HOLE := 0x60
const TOK_ORB := 0x70
const TOK_TRAP := 0x80
const TOK_FOUNTAIN := 0x90
const TOK_FIELD := 0xA0
const TOK_ALTAR := 0xB0
const TOK_DOOR := 0xC0
const TOK_ROOM := 0xD0
const TOK_SECRET := 0xE0
const TOK_WALL := 0xF0

const TRAP_WINDS := 0
const TRAP_ROCKS := 1
const TRAP_PIT := 2

const FOUNTAIN_POISON := 0
const FOUNTAIN_HEAL := 1
const FOUNTAIN_ACID := 2
const FOUNTAIN_CURE := 3
const FOUNTAIN_HEAL_ALT := 4

const FIELD_POISON := 0
const FIELD_ENERGY := 1
const FIELD_FIRE := 2
const FIELD_SLEEP := 3

const DIR_N := 0
const DIR_E := 1
const DIR_S := 2
const DIR_W := 3

const DIRS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

## World / city field tile ids matching dungeon field subtypes.
const FIELD_TILES: Array[int] = [68, 69, 70, 71]

var levels: Array[PackedByteArray] = []
var rooms: Array[Dictionary] = []
var loaded: bool = false
var source_path: String = ""
var dungeon_id: String = ""
var is_abyss: bool = false
## xu4-style annotations: {x,y,z,tid,ttl}. ttl -1 = permanent.
var annotations: Array[Dictionary] = []
## Revealed secret doors: "x,y,z" → true.
var revealed_secrets: Dictionary = {}
## Looted corridor chests / spent orbs / drunk fountains: "x,y,z" → true.
var consumed: Dictionary = {}


func clear() -> void:
	levels.clear()
	rooms.clear()
	annotations.clear()
	revealed_secrets.clear()
	consumed.clear()
	loaded = false
	source_path = ""
	dungeon_id = ""
	is_abyss = false
	for _i in LEVELS:
		var row := PackedByteArray()
		row.resize(LEVEL_BYTES)
		row.fill(TOK_WALL)
		levels.append(row)


func token(byte_v: int) -> int:
	return byte_v & 0xF0


func subtoken(byte_v: int) -> int:
	return byte_v & 0x0F


func wrap_coord(v: int) -> int:
	## Not named `wrap` — that shadows Godot's global wrap(value, min, max).
	return posmod(v, WIDTH)


func raw_at(x: int, y: int, z: int) -> int:
	if not loaded or z < 0 or z >= LEVELS or levels.size() < LEVELS:
		return TOK_WALL
	x = wrap_coord(x)
	y = wrap_coord(y)
	return int(levels[z][y * WIDTH + x])


func set_raw(x: int, y: int, z: int, byte_v: int) -> void:
	if not loaded or z < 0 or z >= LEVELS:
		return
	x = wrap_coord(x)
	y = wrap_coord(y)
	levels[z][y * WIDTH + x] = byte_v & 0xFF


func annotation_at(x: int, y: int, z: int) -> int:
	x = wrap_coord(x)
	y = wrap_coord(y)
	for a in annotations:
		if int(a.get("x", -1)) == x and int(a.get("y", -1)) == y and int(a.get("z", -1)) == z:
			return int(a.get("tid", -1))
	return -1


func add_annotation(x: int, y: int, z: int, tid: int, ttl: int = -1) -> void:
	annotations.insert(0, {
		"x": wrap_coord(x), "y": wrap_coord(y), "z": z, "tid": tid & 0xFF, "ttl": ttl,
	})


func remove_dispel_annotation_at(x: int, y: int, z: int) -> bool:
	x = wrap_coord(x)
	y = wrap_coord(y)
	for i in annotations.size():
		var a: Dictionary = annotations[i]
		if int(a.get("x", -1)) != x or int(a.get("y", -1)) != y or int(a.get("z", -1)) != z:
			continue
		var tid := int(a.get("tid", -1))
		if tid >= 68 and tid <= 71:
			annotations.remove_at(i)
			return true
	return false


func pass_annotations() -> void:
	var i := 0
	while i < annotations.size():
		var a: Dictionary = annotations[i]
		var ttl := int(a.get("ttl", -1))
		if ttl < 0:
			i += 1
			continue
		ttl -= 1
		if ttl <= 0:
			annotations.remove_at(i)
			continue
		a["ttl"] = ttl
		annotations[i] = a
		i += 1


func cell_key(x: int, y: int, z: int) -> String:
	return "%d,%d,%d" % [wrap_coord(x), wrap_coord(y), z]


func is_consumed(x: int, y: int, z: int) -> bool:
	return consumed.has(cell_key(x, y, z))


func mark_consumed(x: int, y: int, z: int) -> void:
	consumed[cell_key(x, y, z)] = true


func reveal_secret(x: int, y: int, z: int) -> bool:
	var k := cell_key(x, y, z)
	if revealed_secrets.has(k):
		return false
	if token(raw_at(x, y, z)) != TOK_SECRET:
		return false
	revealed_secrets[k] = true
	return true


func is_secret_revealed(x: int, y: int, z: int) -> bool:
	return revealed_secrets.has(cell_key(x, y, z))


func effective_at(x: int, y: int, z: int) -> int:
	var ann := annotation_at(x, y, z)
	if ann >= 0:
		return ann
	return raw_at(x, y, z)


func token_at(x: int, y: int, z: int) -> int:
	## Dungeon bytes and world tile ids share the same numeric range:
	## raw 0x40 is a chest, while annotation tile 68 is a poison field.
	## Only annotations use world tile ids; raw map bytes always use dungeon tokens.
	var ann := annotation_at(x, y, z)
	if ann >= FIELD_TILES[0] and ann <= FIELD_TILES[FIELD_TILES.size() - 1]:
		return TOK_FIELD
	if ann >= 0:
		return token(ann)
	return token(raw_at(x, y, z))


func looks_like_wall(x: int, y: int, z: int) -> bool:
	var tok := token_at(x, y, z)
	if tok == TOK_WALL:
		return true
	if tok == TOK_SECRET and not is_secret_revealed(x, y, z):
		return true
	return false


func is_solid_wall(x: int, y: int, z: int) -> bool:
	return token_at(x, y, z) == TOK_WALL


func can_walk(x: int, y: int, z: int) -> bool:
	var tok := token_at(x, y, z)
	if tok == TOK_WALL:
		return false
	if tok == TOK_FIELD:
		var sub := field_subtype(x, y, z)
		if sub == FIELD_ENERGY:
			return false
	return true


func field_subtype(x: int, y: int, z: int) -> int:
	var ann := annotation_at(x, y, z)
	if ann >= FIELD_TILES[0] and ann <= FIELD_TILES[FIELD_TILES.size() - 1]:
		return ann - FIELD_TILES[0]
	if ann >= 0:
		return FIELD_POISON
	var v := raw_at(x, y, z)
	if token(v) == TOK_FIELD:
		return subtoken(v)
	return FIELD_POISON


func field_world_tile(x: int, y: int, z: int) -> int:
	return FIELD_TILES[clampi(field_subtype(x, y, z), 0, 3)]


func room_index_at(x: int, y: int, z: int) -> int:
	var v := raw_at(x, y, z)
	if token(v) != TOK_ROOM:
		return -1
	var sub := subtoken(v)
	if is_abyss:
		## 8 rooms per level: even floors use 0–7, odd floors 8–15.
		return clampi(z, 0, 7) * 8 + (sub & 7)
	return sub


func neighbor(x: int, y: int, dir: int) -> Vector2i:
	var d: Vector2i = DIRS[posmod(dir, 4)]
	return Vector2i(wrap_coord(x + d.x), wrap_coord(y + d.y))


func load_from_path(path: String, id: String = "") -> bool:
	clear()
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < MAP_BYTES:
		push_warning("DungeonMapData: short file %s (%d bytes)" % [path, bytes.size()])
		return false
	source_path = path
	dungeon_id = id if not id.is_empty() else path.get_file().get_basename().to_lower()
	is_abyss = dungeon_id == "abyss" or bytes.size() >= FILE_ABYSS
	for z in LEVELS:
		levels[z] = bytes.slice(z * LEVEL_BYTES, (z + 1) * LEVEL_BYTES)
	var nrooms := ABYSS_ROOMS if is_abyss else REGULAR_ROOMS
	var have := (bytes.size() - MAP_BYTES) / ROOM_BYTES
	nrooms = mini(nrooms, have)
	for i in nrooms:
		var off := MAP_BYTES + i * ROOM_BYTES
		rooms.append(_parse_room(bytes.slice(off, off + ROOM_BYTES), i))
	loaded = true
	return true


func _parse_room(block: PackedByteArray, index: int) -> Dictionary:
	var triggers: Array[Dictionary] = []
	for t in TRIGGERS:
		var b0 := int(block[t * 4])
		var b1 := int(block[t * 4 + 1])
		var b2 := int(block[t * 4 + 2])
		var b3 := int(block[t * 4 + 3])
		if b0 == 0 and b1 == 0 and b2 == 0 and b3 == 0:
			continue
		triggers.append({
			"tile": b0,
			"x": b1 & 0x0F,
			"y": (b1 >> 4) & 0x0F,
			"cx1": b2 & 0x0F,
			"cy1": (b2 >> 4) & 0x0F,
			"cx2": b3 & 0x0F,
			"cy2": (b3 >> 4) & 0x0F,
		})
	var monsters: Array[Dictionary] = []
	for i in AREA_CREATURES:
		var mt := int(block[0x10 + i])
		if mt == 0:
			continue
		monsters.append({
			"tile": mt,
			"x": int(block[0x20 + i]),
			"y": int(block[0x30 + i]),
			"slot": i,
		})
	var party: Dictionary = {}
	for d in 4:
		var xs: Array[int] = []
		var ys: Array[int] = []
		var base := 0x40 + d * 16
		for i in AREA_PLAYERS:
			xs.append(int(block[base + i]))
			ys.append(int(block[base + 8 + i]))
		party[d] = {"x": xs, "y": ys}
	var tiles := block.slice(0x80, 0x80 + ROOM_MAP_COUNT)
	return {
		"index": index,
		"triggers": triggers,
		"monsters": monsters,
		"party": party,
		"tiles": tiles,
		"is_altar": _room_has_tile(tiles, 74),
	}


func _room_has_tile(tiles: PackedByteArray, tid: int) -> bool:
	for v in tiles:
		if int(v) == tid:
			return true
	return false


func room_at(index: int) -> Dictionary:
	if index < 0 or index >= rooms.size():
		return {}
	return rooms[index]


func to_combat_map(index: int, entry_dir: int):
	## Build a CombatMapData-shaped object from a dungeon room.
	var room := room_at(index)
	if room.is_empty():
		return null
	var cmap = load("res://src/map/combat_map_data.gd").new()
	cmap.clear()
	var tiles: PackedByteArray = room.get("tiles", PackedByteArray())
	if tiles.size() >= ROOM_MAP_COUNT:
		cmap.tiles = tiles.slice(0, ROOM_MAP_COUNT)
	var party: Dictionary = room.get("party", {})
	var side: Dictionary = party.get(posmod(entry_dir, 4), {})
	var xs: Array = side.get("x", [])
	var ys: Array = side.get("y", [])
	cmap.player_start.clear()
	for i in AREA_PLAYERS:
		var px := int(xs[i]) if i < xs.size() else 5
		var py := int(ys[i]) if i < ys.size() else 5
		cmap.player_start.append(Vector2i(px, py))
	cmap.creature_start.clear()
	var monsters: Array = room.get("monsters", [])
	for i in AREA_CREATURES:
		if i < monsters.size():
			var m: Dictionary = monsters[i]
			cmap.creature_start.append(Vector2i(int(m.get("x", 0)), int(m.get("y", 0))))
		else:
			cmap.creature_start.append(Vector2i.ZERO)
	cmap.source_path = "%s#room%d" % [source_path, index]
	return cmap


func apply_room_trigger_at(index: int, pos: Vector2i, cmap) -> bool:
	var room := room_at(index)
	if room.is_empty() or cmap == null:
		return false
	var changed := false
	for trig in room.get("triggers", []):
		var t: Dictionary = trig
		if int(t.get("x", -1)) != pos.x or int(t.get("y", -1)) != pos.y:
			continue
		var tid := int(t.get("tile", 0))
		if tid <= 0:
			continue
		cmap.set_tile(int(t.get("cx1", 0)), int(t.get("cy1", 0)), tid)
		cmap.set_tile(int(t.get("cx2", 0)), int(t.get("cy2", 0)), tid)
		changed = true
	return changed


func consumed_to_save() -> Dictionary:
	return {
		"consumed": consumed.keys(),
		"secrets": revealed_secrets.keys(),
		"annotations": annotations.duplicate(true),
	}


func consumed_from_save(d: Dictionary) -> void:
	consumed.clear()
	for k in d.get("consumed", []):
		consumed[str(k)] = true
	revealed_secrets.clear()
	for k in d.get("secrets", []):
		revealed_secrets[str(k)] = true
	annotations.clear()
	var raw: Variant = d.get("annotations", [])
	if typeof(raw) == TYPE_ARRAY:
		for row in raw:
			if typeof(row) == TYPE_DICTIONARY:
				annotations.append((row as Dictionary).duplicate(true))


static func resolve_u4_file(fname: String) -> String:
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
			if bytes.size() >= MAP_BYTES:
				return p
	return ""
