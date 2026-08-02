class_name CityMapData
extends RefCounted

## Ultima IV city / castle / village map (.ULT).
## Bytes 0..1023: 32×32 terrain. Bytes 1024..1279: 32 NPC records (xu4 layout).
## Prefer preload over bare class_name types (stale global class cache).

const _TileRules := preload("res://src/map/tile_rules.gd")

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

## xu4 ObjectMovement (object.h) — values match .ULT PD_MOVE bytes.
const MOVE_FIXED := 0
const MOVE_WANDER := 1
const MOVE_FOLLOW := 0x80
const MOVE_ATTACK := 0xFF
## Internal: one-turn pause after talk (xu4 MOVEMENT_FOLLOW_PAUSE).
const MOVE_FOLLOW_PAUSE := 2

const _DIRS: Array[Vector2i] = [
	Vector2i(-1, 0), ## W
	Vector2i(0, -1), ## N
	Vector2i(1, 0), ## E
	Vector2i(0, 1), ## S
]


## Terrain ids, row-major.
var tiles: PackedByteArray = PackedByteArray()
## Visible townsfolk: Vector3i(x, y, tile_id). tile_id 0 entries are skipped.
var persons: Array[Vector3i] = []
## Animation partner tile per person (same index as persons); -1 if none.
var person_prev: Array[int] = []
## xu4 movement mode per person (MOVE_*).
var person_move: Array[int] = []
var loaded: bool = false
var source_path: String = ""
## xu4 Map::annotations — temporary overlays (open doors, etc.).
## Each: { "x": int, "y": int, "tid": int, "ttl": int }  ttl -1 = permanent.
var annotations: Array[Dictionary] = []
## Ultima4R open chests (city only). Key `"x,y"` →
## { "x", "y", "icon_shown", "icon_total" }.
## Open flips the art + gold icon + trap. Get rolls gold and steals karma.
var opened_chests: Dictionary = {}


func clear() -> void:
	tiles = PackedByteArray()
	tiles.resize(TILE_COUNT)
	tiles.fill(4) ## grass
	persons.clear()
	person_prev.clear()
	person_move.clear()
	annotations.clear()
	opened_chests.clear()
	loaded = false
	source_path = ""


func tile_at(x: int, y: int) -> int:
	## Raw .ULT terrain (WITHOUT annotations).
	## Out-of-bounds is handled by MapView's outside ring (portal neighbours).
	## Keep grass here as a safe fallback for gameplay queries.
	if not loaded or x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT:
		return 4
	return int(tiles[y * WIDTH + x])


func effective_tile_at(x: int, y: int) -> int:
	## xu4 Map::tileTypeAt — non-visual annotations override base terrain.
	var ann_tid := annotation_tile_at(x, y)
	if ann_tid >= 0:
		return ann_tid
	return tile_at(x, y)


func annotation_tile_at(x: int, y: int) -> int:
	## First non-expired annotation tile id, or -1.
	for a in annotations:
		if int(a.get("x", -1)) == x and int(a.get("y", -1)) == y:
			return int(a.get("tid", -1))
	return -1


func add_annotation(x: int, y: int, tid: int, ttl: int = -1) -> void:
	## xu4 AnnotationList::add — newer annotations sit in front (stack; do not erase).
	## Open door (ttl 4) stacks over a Jimmy unlock (ttl -1) so the unlock remains after close.
	annotations.insert(0, {
		"x": x,
		"y": y,
		"tid": clampi(tid, 0, 255),
		"ttl": ttl,
	})


func remove_annotations_at(x: int, y: int) -> void:
	for i in range(annotations.size() - 1, -1, -1):
		var a: Dictionary = annotations[i]
		if int(a.get("x", -1)) == x and int(a.get("y", -1)) == y:
			annotations.remove_at(i)


func pass_annotation_turns() -> bool:
	## xu4 AnnotationList::passTurn — returns true if any annotation changed/removed.
	var changed := false
	var i := 0
	while i < annotations.size():
		var a: Dictionary = annotations[i]
		var ttl := int(a.get("ttl", -1))
		if ttl == 0:
			annotations.remove_at(i)
			changed = true
			continue
		if ttl > 0:
			a["ttl"] = ttl - 1
			annotations[i] = a
			changed = true
		i += 1
	return changed


static func chest_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


func is_chest_open(x: int, y: int) -> bool:
	return opened_chests.has(chest_key(x, y))


func open_chest_at(x: int, y: int, with_loot: bool = true) -> Dictionary:
	## Open the lid. with_loot=false → empty open art (already looted this game).
	## Trap is resolved by the caller on Open.
	var key := chest_key(x, y)
	if opened_chests.has(key):
		return opened_chests[key] as Dictionary
	var data := {
		"x": x,
		"y": y,
		"icon_total": 1,
		"icon_shown": 1 if with_loot else 0,
	}
	opened_chests[key] = data
	return data


func chest_has_loot(x: int, y: int) -> bool:
	var key := chest_key(x, y)
	if not opened_chests.has(key):
		return false
	return int((opened_chests[key] as Dictionary).get("icon_shown", 0)) > 0


func take_chest_loot(x: int, y: int) -> bool:
	## Clear the gold icon after a successful Get.
	var key := chest_key(x, y)
	if not opened_chests.has(key):
		return false
	var d: Dictionary = opened_chests[key]
	if int(d.get("icon_shown", 0)) <= 0:
		return false
	d["icon_shown"] = 0
	opened_chests[key] = d
	return true


func chest_icon_shown(x: int, y: int) -> int:
	var key := chest_key(x, y)
	if not opened_chests.has(key):
		return 0
	return int((opened_chests[key] as Dictionary).get("icon_shown", 0))


func is_chest_empty(x: int, y: int) -> bool:
	## Opened this visit and already looted (no gold icon left).
	return is_chest_open(x, y) and not chest_has_loot(x, y)


func emptied_chest_keys() -> Array[String]:
	## Coordinates looted during this visit (for cross-visit memory / save).
	var keys: Array[String] = []
	for k in opened_chests.keys():
		var d: Dictionary = opened_chests[k]
		if int(d.get("icon_shown", 0)) <= 0:
			keys.append(str(k))
	return keys


func person_tile_at(x: int, y: int) -> int:
	## First NPC tile on this cell, or -1.
	for p in persons:
		if int(p.x) == x and int(p.y) == y:
			return int(p.z)
	return -1


func person_index_at(x: int, y: int) -> int:
	for i in persons.size():
		var p: Vector3i = persons[i]
		if int(p.x) == x and int(p.y) == y:
			return i
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


func move_persons(avatar: Vector2i) -> bool:
	## xu4 Map::moveObjects — one attempt per person after the party turn.
	## Returns true if any coordinate changed (caller should rebuild the view).
	if not loaded or persons.is_empty():
		return false
	var any := false
	for i in persons.size():
		if _move_one(i, avatar):
			any = true
	return any


func pause_follow(person_i: int) -> void:
	## xu4 talk: FOLLOW → FOLLOW_PAUSE for one turn.
	if person_i < 0 or person_i >= person_move.size():
		return
	if person_move[person_i] == MOVE_FOLLOW:
		person_move[person_i] = MOVE_FOLLOW_PAUSE


func _load_persons(bytes: PackedByteArray) -> void:
	## xu4 loadCityMap person block after terrain.
	persons.clear()
	person_prev.clear()
	person_move.clear()
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
		person_move.append(_move_behavior(int(pd[PD_MOVE + i])))


static func _move_behavior(ult_value: int) -> int:
	## xu4 maploader.cpp moveBehavior.
	match ult_value:
		0:
			return MOVE_FIXED
		1:
			return MOVE_WANDER
		0x80:
			return MOVE_FOLLOW
		0xFF:
			return MOVE_ATTACK
		_:
			return MOVE_FIXED


func _move_one(i: int, avatar: Vector2i) -> bool:
	## xu4 location.cpp moveObject (city / walking townsfolk).
	var mode: int = person_move[i] if i < person_move.size() else MOVE_FIXED
	match mode:
		MOVE_FIXED:
			return false
		MOVE_FOLLOW_PAUSE:
			## Resume following next turn.
			person_move[i] = MOVE_FOLLOW
			return false
		MOVE_WANDER:
			## Town: 50% stay put (world map always moves — not used here).
			if (randi() % 2) != 0:
				return false
		MOVE_FOLLOW:
			## Town: 50% skip entire follow attempt.
			if (randi() % 2) != 0:
				return false
		MOVE_ATTACK:
			## Adjacent attacker stays put (combat hook later).
			if _manhattan(persons[i], avatar) <= 1:
				return false
		_:
			return false

	var pos := Vector2i(int(persons[i].x), int(persons[i].y))
	var valid := _valid_dirs(pos, i, avatar)
	if valid.is_empty():
		return false

	var dir := Vector2i.ZERO
	match mode:
		MOVE_WANDER:
			dir = valid[randi() % valid.size()]
		MOVE_FOLLOW, MOVE_ATTACK:
			dir = _path_to(pos, avatar, valid)
		_:
			return false
	if dir == Vector2i.ZERO:
		return false

	var next := pos + dir
	## City borderbehavior: exit — no wrap; OOB keeps old coords.
	if next.x < 0 or next.y < 0 or next.x >= WIDTH or next.y >= HEIGHT:
		return false
	## xu4 slowedByTile on destination (annotations count — same as tileTypeAt).
	if _TileRules.slowed_by_tile(effective_tile_at(next.x, next.y)):
		return false

	persons[i] = Vector3i(next.x, next.y, int(persons[i].z))
	return true


func _valid_dirs(from: Vector2i, self_i: int, avatar: Vector2i) -> Array[Vector2i]:
	## xu4 Map::getValidMoves for walking creatures (walks + creatureWalkable).
	var out: Array[Vector2i] = []
	var from_tid := effective_tile_at(from.x, from.y)
	for d in _DIRS:
		var dest := from + d
		if dest.x < 0 or dest.y < 0 or dest.x >= WIDTH or dest.y >= HEIGHT:
			## xu4 adds OOB to the mask but never commits the coord — skip.
			continue
		if dest == avatar:
			continue
		if _person_blocks(dest.x, dest.y, self_i):
			continue
		var dest_tid := effective_tile_at(dest.x, dest.y)
		if not _TileRules.can_walk_on(dest_tid, d):
			continue
		if not _TileRules.can_walk_off(from_tid, d):
			continue
		if not _TileRules.is_creature_walkable(dest_tid):
			continue
		out.append(d)
	return out


func _person_blocks(x: int, y: int, ignore_i: int) -> bool:
	for j in persons.size():
		if j == ignore_i:
			continue
		var p: Vector3i = persons[j]
		if int(p.x) == x and int(p.y) == y:
			return true
	return false


func _path_to(from: Vector2i, to: Vector2i, valid: Array[Vector2i]) -> Vector2i:
	## xu4 map_pathTo — prefer relative dirs toward target, else any valid.
	if valid.is_empty():
		return Vector2i.ZERO
	var prefer: Array[Vector2i] = []
	var dx := from.x - to.x
	var dy := from.y - to.y
	## Relative from `from` toward `to` (xu4 map_getRelativeDirection).
	for d in valid:
		var toward := false
		if dx < 0 and d.x > 0:
			toward = true
		if dx > 0 and d.x < 0:
			toward = true
		if dy < 0 and d.y > 0:
			toward = true
		if dy > 0 and d.y < 0:
			toward = true
		if toward:
			prefer.append(d)
	var pool: Array[Vector2i] = prefer if not prefer.is_empty() else valid
	return pool[randi() % pool.size()]


static func _manhattan(a: Vector3i, b: Vector2i) -> int:
	return absi(int(a.x) - b.x) + absi(int(a.y) - b.y)


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
