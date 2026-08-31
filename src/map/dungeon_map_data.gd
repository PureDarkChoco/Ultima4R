class_name DungeonMapData
extends RefCounted

## Ultima IV .DNG — 8×8×8 corridor maps + 256-byte room records (16 / Abyss 64).
## Prefer preload over bare class_name types (stale global class cache).

const _TileRules := preload("res://src/map/tile_rules.gd")

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

const FOUNTAIN_NORMAL := 0
const FOUNTAIN_HEAL := 1
const FOUNTAIN_ACID := 2
const FOUNTAIN_CURE := 3
const FOUNTAIN_POISON := 4

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
const MONSTER_TILE_FIRST := 144
const MONSTER_TILE_STEP := 4
const MAX_CORRIDOR_MONSTERS_PER_LEVEL := 4
const MONSTER_SPAWN_TRIES := 32
const MONSTER_FIXED_TILES: Array[int] = [172, 176] ## Mimic / Reaper.

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
## Looted corridor chests / spent orbs: "x,y,z" → true.
var consumed: Dictionary = {}
## Shamino sense: secrets entered / traps sprung — no more adjacent warnings.
var shamino_known: Dictionary = {}
## xu4 corridor creatures: {id,tile,x,y,prev_x,prev_y,z}.
var corridor_monsters: Array[Dictionary] = []
var _next_monster_id := 1


func clear() -> void:
	levels.clear()
	rooms.clear()
	annotations.clear()
	revealed_secrets.clear()
	consumed.clear()
	shamino_known.clear()
	corridor_monsters.clear()
	_next_monster_id = 1
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


func mark_shamino_known(x: int, y: int, z: int) -> void:
	shamino_known[cell_key(x, y, z)] = true


func is_shamino_known(x: int, y: int, z: int) -> bool:
	return shamino_known.has(cell_key(x, y, z))


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
	var sub := subtoken(v) & 0x0F
	if is_abyss:
		## xu4: 16 rooms per two floors. Token 0xD* (* == 0–15); levels 1–2
		## use rooms 0–15, 3–4 use 16–31, and so on.
		return (0x10 * int(clampi(z, 0, 7) / 2)) + sub
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
	_apply_xu4_room_fixups()
	_load_monsters_from_levels()
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
			## xu4 DNG room trigger bytes: high nibble X, low nibble Y.
			"x": (b1 >> 4) & 0x0F,
			"y": b1 & 0x0F,
			"cx1": (b2 >> 4) & 0x0F,
			"cy1": b2 & 0x0F,
			"cx2": (b3 >> 4) & 0x0F,
			"cy2": b3 & 0x0F,
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


func _set_room_party_start(
	index: int,
	dir: int,
	xs: Array[int],
	ys: Array[int]
) -> void:
	if index < 0 or index >= rooms.size():
		return
	var room: Dictionary = rooms[index]
	var party: Dictionary = room.get("party", {})
	party[posmod(dir, 4)] = {
		"x": xs.duplicate(),
		"y": ys.duplicate(),
	}
	room["party"] = party
	rooms[index] = room


func _apply_xu4_room_fixups() -> void:
	## xu4 maploader.cpp repairs invalid DOS Hythloth room starts and the
	## connected room geometry they depend on. Then every dungeon fills
	## leftover NULL / wall-stacked party starts so any used door works.
	if dungeon_id == "hythloth":
		_apply_hythloth_room_fixups()
	if is_abyss:
		_apply_abyss_altar_diagonal_walls()
	_repair_invalid_party_starts()


func _apply_abyss_altar_diagonal_walls() -> void:
	## Abyss floor 1 altar rooms: DOS map has a large open floor but the
	## first-person renderer does not merge continuous empties — one diagonal
	## wall exists in data; add the other three so corners read as enclosed.
	const Z_FLOOR_1 := 0
	const DIAG := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	for y in HEIGHT:
		for x in WIDTH:
			if token(raw_at(x, y, Z_FLOOR_1)) != TOK_ALTAR:
				continue
			for d in DIAG:
				var px := wrap_coord(x + d.x)
				var py := wrap_coord(y + d.y)
				var v := raw_at(px, py, Z_FLOOR_1)
				if token(v) == TOK_WALL or token(v) == TOK_ALTAR:
					continue
				set_raw(px, py, Z_FLOOR_1, TOK_WALL)


func _apply_hythloth_room_fixups() -> void:
	_set_room_party_start(
		7,
		DIR_E,
		[8, 8, 9, 9, 9, 10, 10, 10],
		[3, 2, 3, 2, 1, 3, 2, 1]
	)
	_set_room_party_start(
		7,
		DIR_S,
		[3, 2, 3, 2, 1, 3, 2, 1],
		[8, 8, 9, 9, 9, 10, 10, 10]
	)
	_set_room_party_start(
		9,
		DIR_W,
		[2, 2, 1, 1, 1, 0, 0, 0],
		[9, 8, 9, 8, 7, 9, 8, 7]
	)
	if rooms.size() <= 9:
		return
	var room: Dictionary = rooms[9]
	var monsters: Array = room.get("monsters", [])
	var fixed_pos := {
		7: Vector2i(4, 5),
		8: Vector2i(6, 5),
		9: Vector2i(5, 6),
	}
	for i in monsters.size():
		var monster: Dictionary = monsters[i]
		var slot := int(monster.get("slot", -1))
		if not fixed_pos.has(slot):
			continue
		var pos: Vector2i = fixed_pos[slot]
		monster["x"] = pos.x
		monster["y"] = pos.y
		monsters[i] = monster
	room["monsters"] = monsters
	var tiles: PackedByteArray = room.get("tiles", PackedByteArray())
	if tiles.size() >= ROOM_MAP_COUNT:
		var replacements := {
			Vector2i(5, 5): 60, ## chest
			Vector2i(0, 7): 22, ## floor
			Vector2i(1, 7): 22,
			Vector2i(0, 8): 22,
			Vector2i(1, 8): 22,
			Vector2i(0, 9): 22,
		}
		for pos in replacements:
			tiles[pos.y * ROOM_MAP_W + pos.x] = int(replacements[pos])
		room["tiles"] = tiles
	rooms[9] = room


func _room_cell_walkable(tiles: PackedByteArray, pos: Vector2i) -> bool:
	if pos.x < 0 or pos.y < 0 or pos.x >= ROOM_MAP_W or pos.y >= ROOM_MAP_H:
		return false
	if tiles.size() < ROOM_MAP_COUNT:
		return false
	return _TileRules.is_walkable(int(tiles[pos.y * ROOM_MAP_W + pos.x]))


func _party_start_is_invalid(xs: Array, ys: Array, tiles: PackedByteArray) -> bool:
	if xs.size() < AREA_PLAYERS or ys.size() < AREA_PLAYERS:
		return true
	var all_origin := true
	var blocked := 0
	for i in AREA_PLAYERS:
		var pos := Vector2i(int(xs[i]), int(ys[i]))
		if pos != Vector2i.ZERO:
			all_origin = false
		if not _room_cell_walkable(tiles, pos):
			blocked += 1
	return all_origin or blocked >= 6


func _party_start_search_cells(dir: int) -> Array[Vector2i]:
	var across: Array[int] = [5, 4, 6, 3, 7, 2, 8, 1, 9, 0, 10]
	var out: Array[Vector2i] = []
	match posmod(dir, 4):
		DIR_N:
			for y in range(0, 6):
				for x in across:
					out.append(Vector2i(x, y))
		DIR_S:
			for y in range(10, 4, -1):
				for x in across:
					out.append(Vector2i(x, y))
		DIR_E:
			for x in range(10, 4, -1):
				for y in across:
					out.append(Vector2i(x, y))
		_:
			for x in range(0, 6):
				for y in across:
					out.append(Vector2i(x, y))
	return out


func _synthesize_party_start(tiles: PackedByteArray, dir: int) -> Dictionary:
	var xs: Array[int] = []
	var ys: Array[int] = []
	var seen: Dictionary = {}
	for pos in _party_start_search_cells(dir):
		if seen.has(pos) or not _room_cell_walkable(tiles, pos):
			continue
		seen[pos] = true
		xs.append(pos.x)
		ys.append(pos.y)
		if xs.size() >= AREA_PLAYERS:
			break
	if xs.is_empty():
		for i in AREA_PLAYERS:
			xs.append(5)
			ys.append(5)
	while xs.size() < AREA_PLAYERS:
		xs.append(xs[xs.size() - 1])
		ys.append(ys[ys.size() - 1])
	return {"x": xs, "y": ys}


func _used_entry_dir_mask(room_index: int) -> int:
	## Sides from which a corridor (or other non-wall) actually meets this room.
	## Reads `levels` directly — `raw_at` still returns walls until `loaded`.
	var mask := 0
	if levels.size() < LEVELS:
		return 0
	for z in LEVELS:
		var level: PackedByteArray = levels[z]
		if level.size() < LEVEL_BYTES:
			continue
		for y in HEIGHT:
			for x in WIDTH:
				var v := int(level[y * WIDTH + x])
				if token(v) != TOK_ROOM:
					continue
				var idx := subtoken(v) & 0x0F
				if is_abyss:
					idx = (0x10 * int(z / 2)) + idx
				if idx != room_index:
					continue
				for dir in 4:
					var n: Vector2i = neighbor(x, y, dir)
					var nv := int(level[n.y * WIDTH + n.x])
					if token(nv) != TOK_WALL:
						mask |= 1 << dir
	return mask


func _repair_invalid_party_starts() -> void:
	for i in rooms.size():
		var room: Dictionary = rooms[i]
		var tiles: PackedByteArray = room.get("tiles", PackedByteArray())
		var party: Dictionary = room.get("party", {})
		var used := _used_entry_dir_mask(i)
		var changed := false
		for dir in 4:
			if (used & (1 << dir)) == 0:
				continue
			var side: Dictionary = party.get(dir, {})
			var xs: Array = side.get("x", [])
			var ys: Array = side.get("y", [])
			if not _party_start_is_invalid(xs, ys, tiles):
				continue
			party[dir] = _synthesize_party_start(tiles, dir)
			changed = true
		if not changed:
			continue
		room["party"] = party
		rooms[i] = room


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
		var change1 := Vector2i(int(t.get("cx1", 0)), int(t.get("cy1", 0)))
		var change2 := Vector2i(int(t.get("cx2", 0)), int(t.get("cy2", 0)))
		## xu4 treats packed 0x00 as "no target", not room coordinate (0, 0).
		if change1 != Vector2i.ZERO:
			cmap.set_tile(change1.x, change1.y, tid)
			changed = true
		if change2 != Vector2i.ZERO:
			cmap.set_tile(change2.x, change2.y, tid)
			changed = true
	return changed


func _token_uses_monster_nibble(tok: int) -> bool:
	return (
		tok != TOK_TRAP
		and tok != TOK_FOUNTAIN
		and tok != TOK_FIELD
		and tok != TOK_ROOM
	)


func _monster_tile_from_nibble(nibble: int) -> int:
	if nibble <= 0 or nibble > 0x0F:
		return -1
	return MONSTER_TILE_FIRST + (nibble - 1) * MONSTER_TILE_STEP


func _monster_nibble_from_tile(tile_id: int) -> int:
	if tile_id < MONSTER_TILE_FIRST:
		return 0
	return clampi((tile_id - MONSTER_TILE_FIRST) / MONSTER_TILE_STEP + 1, 1, 0x0F)


func _load_monsters_from_levels() -> void:
	corridor_monsters.clear()
	_next_monster_id = 1
	for z in LEVELS:
		var level_count := 0
		for y in HEIGHT:
			for x in WIDTH:
				var raw := raw_at(x, y, z)
				var nibble := subtoken(raw)
				if nibble == 0 or not _token_uses_monster_nibble(token(raw)):
					continue
				if level_count >= MAX_CORRIDOR_MONSTERS_PER_LEVEL:
					continue
				var tile_id := _monster_tile_from_nibble(nibble)
				if tile_id < 0:
					continue
				corridor_monsters.append({
					"id": _next_monster_id,
					"tile": tile_id,
					"x": x,
					"y": y,
					"prev_x": x,
					"prev_y": y,
					"z": z,
				})
				_next_monster_id += 1
				level_count += 1


func monster_index_at(x: int, y: int, z: int) -> int:
	x = wrap_coord(x)
	y = wrap_coord(y)
	for i in corridor_monsters.size():
		var monster: Dictionary = corridor_monsters[i]
		if (
			int(monster.get("x", -1)) == x
			and int(monster.get("y", -1)) == y
			and int(monster.get("z", -1)) == z
		):
			return i
	return -1


func monster_at(x: int, y: int, z: int) -> Dictionary:
	var index := monster_index_at(x, y, z)
	if index < 0:
		return {}
	return corridor_monsters[index].duplicate(true)


func monster_tile_at(x: int, y: int, z: int) -> int:
	var index := monster_index_at(x, y, z)
	if index < 0:
		return -1
	return int(corridor_monsters[index].get("tile", -1))


func _write_monster_nibble(x: int, y: int, z: int, tile_id: int) -> void:
	var raw := raw_at(x, y, z)
	if not _token_uses_monster_nibble(token(raw)):
		return
	set_raw(x, y, z, (raw & 0xF0) | _monster_nibble_from_tile(tile_id))


func _clear_monster_nibble(x: int, y: int, z: int) -> void:
	var raw := raw_at(x, y, z)
	if _token_uses_monster_nibble(token(raw)):
		set_raw(x, y, z, raw & 0xF0)


func take_monster_at(x: int, y: int, z: int) -> Dictionary:
	var index := monster_index_at(x, y, z)
	if index < 0:
		return {}
	var monster: Dictionary = corridor_monsters[index]
	corridor_monsters.remove_at(index)
	_clear_monster_nibble(x, y, z)
	return monster.duplicate(true)


func destroy_all_except_lord_british() -> int:
	## xu4 gameDestroyAllCreatures on a dungeon map — wipe corridor monsters.
	var removed := corridor_monsters.size()
	for i in range(removed - 1, -1, -1):
		var monster: Dictionary = corridor_monsters[i]
		_clear_monster_nibble(
			int(monster.get("x", 0)),
			int(monster.get("y", 0)),
			int(monster.get("z", 0))
		)
	corridor_monsters.clear()
	return removed


func _monster_terrain_walkable(pos: Vector2i, z: int) -> bool:
	var tok := token_at(pos.x, pos.y, z)
	if (
		tok == TOK_WALL
		or tok == TOK_TRAP
		or tok == TOK_FOUNTAIN
		or tok == TOK_FIELD
		or tok == TOK_ROOM
	):
		return false
	if tok == TOK_SECRET and not is_secret_revealed(pos.x, pos.y, z):
		return false
	return true


func _monster_can_occupy(pos: Vector2i, z: int, player: Vector2i) -> bool:
	if pos == player or monster_index_at(pos.x, pos.y, z) >= 0:
		return false
	return _monster_terrain_walkable(pos, z)


func _monster_can_restore(pos: Vector2i, z: int) -> bool:
	if monster_index_at(pos.x, pos.y, z) >= 0:
		return false
	return _token_uses_monster_nibble(token(raw_at(pos.x, pos.y, z)))


func _wrapped_axis_delta(a: int, b: int) -> int:
	var forward := posmod(b - a, WIDTH)
	if forward > WIDTH / 2:
		forward -= WIDTH
	return forward


func wrapped_cardinal_dir(from: Vector2i, to: Vector2i) -> int:
	var dx := _wrapped_axis_delta(from.x, to.x)
	var dy := _wrapped_axis_delta(from.y, to.y)
	if abs(dx) > abs(dy):
		return DIR_E if dx > 0 else DIR_W
	return DIR_S if dy > 0 else DIR_N


func _wrapped_manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(_wrapped_axis_delta(a.x, b.x)) + abs(_wrapped_axis_delta(a.y, b.y))


func _next_monster_step(start: Vector2i, z: int, player: Vector2i) -> Vector2i:
	var best := start
	var best_distance := _wrapped_manhattan(start, player)
	var dirs := DIRS.duplicate()
	dirs.shuffle()
	for delta in dirs:
		var next := Vector2i(wrap_coord(start.x + delta.x), wrap_coord(start.y + delta.y))
		if not _monster_can_occupy(next, z, player):
			continue
		var distance := _wrapped_manhattan(next, player)
		if distance < best_distance:
			best = next
			best_distance = distance
	return best


func advance_monsters(z: int, player: Vector2i) -> Dictionary:
	for monster in corridor_monsters:
		if int(monster.get("z", -1)) != z:
			continue
		var pos := Vector2i(int(monster["x"]), int(monster["y"]))
		if not _monster_terrain_walkable(pos, z):
			continue
		if _wrapped_manhattan(pos, player) <= 1:
			return {"changed": false, "attacker": monster.duplicate(true)}
	var changed := false
	for i in corridor_monsters.size():
		var monster: Dictionary = corridor_monsters[i]
		if int(monster.get("z", -1)) != z:
			continue
		if MONSTER_FIXED_TILES.has(int(monster.get("tile", -1))):
			continue
		var old_pos := Vector2i(int(monster["x"]), int(monster["y"]))
		var next := _next_monster_step(old_pos, z, player)
		if next == old_pos:
			continue
		_clear_monster_nibble(old_pos.x, old_pos.y, z)
		monster["prev_x"] = old_pos.x
		monster["prev_y"] = old_pos.y
		monster["x"] = next.x
		monster["y"] = next.y
		corridor_monsters[i] = monster
		_write_monster_nibble(next.x, next.y, z, int(monster["tile"]))
		changed = true
	return {"changed": changed, "attacker": {}}


func _random_monster_tile_for_level(z: int) -> int:
	var variant_count := 4 if z >= 5 else 3
	var nibble := clampi(z + 1 + (randi() % variant_count), 1, 0x0F)
	if nibble >= 8:
		nibble = mini(nibble + 1, 0x0F) ## xu4 randomForDungeon skips Mimic.
	return _monster_tile_from_nibble(nibble)


func try_spawn_monster(z: int, player: Vector2i) -> bool:
	var count := 0
	for monster in corridor_monsters:
		if int(monster.get("z", -1)) == z:
			count += 1
	if count >= MAX_CORRIDOR_MONSTERS_PER_LEVEL:
		return false
	var divisor := maxi(4, 32 - clampi(z, 0, LEVELS - 1) * 4)
	if (randi() % divisor) != 0:
		return false
	for _try in MONSTER_SPAWN_TRIES:
		var pos := Vector2i(randi() % WIDTH, randi() % HEIGHT)
		if not _monster_can_occupy(pos, z, player):
			continue
		var tile_id := _random_monster_tile_for_level(z)
		corridor_monsters.append({
			"id": _next_monster_id,
			"tile": tile_id,
			"x": pos.x,
			"y": pos.y,
			"prev_x": pos.x,
			"prev_y": pos.y,
			"z": z,
		})
		_next_monster_id += 1
		_write_monster_nibble(pos.x, pos.y, z, tile_id)
		return true
	return false


func consumed_to_save() -> Dictionary:
	return {
		"consumed": consumed.keys(),
		"secrets": revealed_secrets.keys(),
		"shamino_known": shamino_known.keys(),
		"annotations": annotations.duplicate(true),
		"monsters": corridor_monsters.duplicate(true),
	}


func consumed_from_save(d: Dictionary) -> void:
	consumed.clear()
	for k in d.get("consumed", []):
		consumed[str(k)] = true
	revealed_secrets.clear()
	for k in d.get("secrets", []):
		revealed_secrets[str(k)] = true
	shamino_known.clear()
	for k in d.get("shamino_known", []):
		shamino_known[str(k)] = true
	annotations.clear()
	var raw: Variant = d.get("annotations", [])
	if typeof(raw) == TYPE_ARRAY:
		for row in raw:
			if typeof(row) == TYPE_DICTIONARY:
				annotations.append((row as Dictionary).duplicate(true))
	var monsters_raw: Variant = d.get("monsters", null)
	if typeof(monsters_raw) == TYPE_ARRAY:
		for monster in corridor_monsters:
			_clear_monster_nibble(
				int(monster.get("x", 0)),
				int(monster.get("y", 0)),
				int(monster.get("z", 0))
			)
		corridor_monsters.clear()
		_next_monster_id = 1
		var level_counts: Dictionary = {}
		for row in monsters_raw:
			if typeof(row) != TYPE_DICTIONARY:
				continue
			var saved: Dictionary = (row as Dictionary).duplicate(true)
			var z := clampi(int(saved.get("z", 0)), 0, LEVELS - 1)
			var x := wrap_coord(int(saved.get("x", 0)))
			var y := wrap_coord(int(saved.get("y", 0)))
			var tile_id := int(saved.get("tile", -1))
			var level_count := int(level_counts.get(z, 0))
			if (
				tile_id < MONSTER_TILE_FIRST
				or level_count >= MAX_CORRIDOR_MONSTERS_PER_LEVEL
				or not _monster_can_restore(Vector2i(x, y), z)
			):
				continue
			var id := maxi(1, int(saved.get("id", _next_monster_id)))
			saved["id"] = id
			saved["tile"] = tile_id
			saved["x"] = x
			saved["y"] = y
			saved["prev_x"] = wrap_coord(int(saved.get("prev_x", x)))
			saved["prev_y"] = wrap_coord(int(saved.get("prev_y", y)))
			saved["z"] = z
			corridor_monsters.append(saved)
			_write_monster_nibble(x, y, z, tile_id)
			level_counts[z] = level_count + 1
			_next_monster_id = maxi(_next_monster_id, id + 1)


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
