class_name CityMapData
extends RefCounted

## Ultima IV city / castle / village map (.ULT).
## Bytes 0..1023: 32×32 terrain. Bytes 1024..1279: 32 NPC records (xu4 layout).
## Prefer preload over bare class_name types (stale global class cache).

const _TileRules := preload("res://src/map/tile_rules.gd")
const _TalkTlk := preload("res://src/core/talk_tlk.gd")
const _TalkLocale := preload("res://src/core/talk_locale.gd")
const _CityNpcRoles := preload("res://src/map/city_npc_roles.gd")
const _WorldCreatures := preload("res://src/map/world_creatures.gd")

const WIDTH := 32
const HEIGHT := 32
const TILE_COUNT := WIDTH * HEIGHT
const TERRAIN_BYTES := 1024
const NPC_MAX := 32
const NPC_BLOCK := 8 * NPC_MAX ## 256 — tile/x/y/prev + pad + move/conv
const FILE_MIN := TERRAIN_BYTES
const FILE_FULL := TERRAIN_BYTES + NPC_BLOCK
const TILE_FOREST := 6
const TILE_CHEST := 60
const TILE_BRICK_FLOOR := 62
## Ultima4R terrain overrides after .ULT load. Key = basename lower, then "x,y" → tile id.
const TERRAIN_PATCHES := {
	"jhelom.ult": {"1,5": TILE_FOREST}, ## magic-axe Search hint (scrub → forest)
}

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
## Wander leash from default ULT tile (Manhattan; walls ignored).
const WANDER_LEASH := 6

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
## Default spawn tile (leash origin) per person.
var person_home: Array[Vector2i] = []
## Animation partner tile per person (same index as persons); -1 if none.
var person_prev: Array[int] = []
## xu4 movement mode per person (MOVE_*).
var person_move: Array[int] = []
## .TLK discourse index per person (0..15), or -1 if none (xu4 convId).
var person_conv: Array[int] = []
## Original .ULT person slot 0..31 (for maps.b roles, 1-based id = slot+1).
var person_file_slot: Array[int] = []
## CityNpcRoles.Role per person.
var person_role: Array[int] = []
## Loaded .TLK entries for this city (TalkTlk.Entry), index = discourse id.
var discourses: Array = []
var loaded: bool = false
var source_path: String = ""
## xu4 Map::annotations — temporary overlays (open doors, etc.).
## Each: { "x": int, "y": int, "tid": int, "ttl": int }  ttl -1 = permanent.
var annotations: Array[Dictionary] = []
## Ultima4R open chests (city only). Key `"x,y"` →
## { "x", "y", "icon_shown", "icon_total" }.
## Open flips the art + gold icon + trap. Get rolls gold and steals karma.
var opened_chests: Dictionary = {}
## Chests looted on an earlier visit. Their original .ULT tile is treated as floor.
var removed_chests: Dictionary = {}
## Shamino sense: secret doors approached or entered — no more adjacent warnings.
var shamino_known: Dictionary = {}


func clear() -> void:
	tiles = PackedByteArray()
	tiles.resize(TILE_COUNT)
	tiles.fill(4) ## grass
	persons.clear()
	person_home.clear()
	person_prev.clear()
	person_move.clear()
	person_conv.clear()
	person_file_slot.clear()
	person_role.clear()
	discourses.clear()
	annotations.clear()
	opened_chests.clear()
	removed_chests.clear()
	shamino_known.clear()
	loaded = false
	source_path = ""


func set_tile(x: int, y: int, tid: int) -> void:
	if not loaded or x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT or tiles.size() < TILE_COUNT:
		return
	tiles[y * WIDTH + x] = clampi(tid, 0, 255) & 0xFF


func remove_dispel_annotation_at(x: int, y: int) -> bool:
	## xu4 spellDispel — drop the first field annotation at this cell.
	for i in annotations.size():
		var a: Dictionary = annotations[i]
		if int(a.get("x", -1)) != x or int(a.get("y", -1)) != y:
			continue
		if _TileRules.can_dispel(int(a.get("tid", -1))):
			annotations.remove_at(i)
			return true
	return false


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
	var tid := tile_at(x, y)
	if tid == TILE_CHEST and removed_chests.has(chest_key(x, y)):
		return TILE_BRICK_FLOOR
	return tid


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


func mark_shamino_known(x: int, y: int) -> void:
	shamino_known[chest_key(x, y)] = true


func is_shamino_known(x: int, y: int) -> bool:
	return shamino_known.has(chest_key(x, y))


func remove_remembered_chests(keys: Array) -> void:
	for key in keys:
		removed_chests[str(key)] = true


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


func nudge_persons_off_avatar(avatar: Vector2i) -> bool:
	## Load can place the party on a townsfolk's default ULT tile.
	var moved := false
	for i in persons.size():
		var p: Vector3i = persons[i]
		if int(p.x) != avatar.x or int(p.y) != avatar.y:
			continue
		var dest := _nudge_stand_tile(i, avatar)
		if dest.x < 0:
			continue
		persons[i] = Vector3i(dest.x, dest.y, int(p.z))
		moved = true
	return moved


func _nudge_stand_tile(self_i: int, avatar: Vector2i) -> Vector2i:
	## Prefer adjacent W/E/N/S; if those are blocked, the nearest walkable tile.
	const SIDE_DIRS: Array[Vector2i] = [
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(0, -1),
		Vector2i(0, 1),
	]
	for d in SIDE_DIRS:
		var dest := avatar + d
		if _person_can_stand_at(dest.x, dest.y, self_i, avatar, d):
			return dest
	var seen: Dictionary = {}
	seen[avatar] = true
	var q: Array[Vector2i] = [avatar]
	var qi := 0
	while qi < q.size():
		var cur: Vector2i = q[qi]
		qi += 1
		if absi(cur.x - avatar.x) + absi(cur.y - avatar.y) >= 8:
			continue
		for d in _DIRS:
			var nxt := cur + d
			if seen.has(nxt):
				continue
			if not _person_terrain_walkable(nxt.x, nxt.y, d, self_i):
				continue
			seen[nxt] = true
			if _person_can_stand_at(nxt.x, nxt.y, self_i, avatar, d):
				return nxt
			q.append(nxt)
	return Vector2i(-1, -1)


func _person_terrain_walkable(x: int, y: int, dir: Vector2i, self_i: int = -1) -> bool:
	if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT:
		return false
	var dest_tid := effective_tile_at(x, y)
	var step := dir if dir != Vector2i.ZERO else Vector2i(1, 0)
	var mover := 0
	if self_i >= 0 and self_i < persons.size():
		mover = int(persons[self_i].z)
	if _WorldCreatures.is_swimmer(mover):
		return _TileRules.is_swimable(dest_tid)
	if _WorldCreatures.is_incorporeal(mover):
		return not _TileRules.is_water(dest_tid)
	if not _TileRules.can_walk_on(dest_tid, step):
		return false
	return _TileRules.is_creature_walkable(dest_tid)


func _person_can_stand_at(
	x: int, y: int, ignore_i: int, avatar: Vector2i, dir: Vector2i
) -> bool:
	if Vector2i(x, y) == avatar:
		return false
	if _person_blocks(x, y, ignore_i):
		return false
	return _person_terrain_walkable(x, y, dir, ignore_i)


func take_person_at(x: int, y: int) -> Dictionary:
	## Remove and return person for combat engage (xu4 removeObject endCombat).
	var i := person_index_at(x, y)
	if i < 0:
		return {}
	return take_person_at_index(i)


func take_person_at_index(i: int) -> Dictionary:
	if i < 0 or i >= persons.size():
		return {}
	var p: Vector3i = persons[i]
	var prev := -1
	if i < person_prev.size():
		prev = int(person_prev[i])
	var move := MOVE_FIXED
	if i < person_move.size():
		move = int(person_move[i])
	var conv := -1
	if i < person_conv.size():
		conv = int(person_conv[i])
	var slot := -1
	if i < person_file_slot.size():
		slot = int(person_file_slot[i])
	var role := _CityNpcRoles.Role.NONE
	if i < person_role.size():
		role = int(person_role[i])
	var home := Vector2i(int(p.x), int(p.y))
	if i < person_home.size():
		home = person_home[i]
	persons.remove_at(i)
	if i < person_home.size():
		person_home.remove_at(i)
	if i < person_prev.size():
		person_prev.remove_at(i)
	if i < person_move.size():
		person_move.remove_at(i)
	if i < person_conv.size():
		person_conv.remove_at(i)
	if i < person_file_slot.size():
		person_file_slot.remove_at(i)
	if i < person_role.size():
		person_role.remove_at(i)
	return {
		"x": int(p.x),
		"y": int(p.y),
		"tile": int(p.z),
		"prev": prev,
		"movement": move,
		"conv": conv,
		"file_slot": slot,
		"role": role,
		"city_person": true,
		"home_x": int(home.x),
		"home_y": int(home.y),
	}


func restore_person(foe: Dictionary) -> void:
	## Put a person back if combat arena failed to load.
	if foe.is_empty() or not bool(foe.get("city_person", false)):
		return
	var x := int(foe.get("x", 0))
	var y := int(foe.get("y", 0))
	if person_index_at(x, y) >= 0:
		return
	persons.append(Vector3i(x, y, int(foe.get("tile", 0))))
	var home := Vector2i(
		int(foe.get("home_x", x)),
		int(foe.get("home_y", y))
	)
	person_home.append(home)
	person_prev.append(int(foe.get("prev", -1)))
	person_move.append(int(foe.get("movement", MOVE_FIXED)))
	person_conv.append(int(foe.get("conv", -1)))
	person_file_slot.append(int(foe.get("file_slot", -1)))
	person_role.append(int(foe.get("role", _CityNpcRoles.Role.NONE)))


func alert_guards() -> void:
	## xu4 Map::alertGuards — Guard + Lord British → MOVEMENT_ATTACK_AVATAR.
	for i in persons.size():
		if i >= person_move.size():
			break
		var tid := int(persons[i].z)
		var base := tid
		## 2-frame animation pairs (even base).
		if (tid >= 32 and tid <= 47) or (tid >= 80 and tid <= 95):
			base = tid & ~1
		if base == 80 or base == 94: ## guard / lord_british
			person_move[i] = MOVE_ATTACK


func take_adjacent_attacker(avatar: Vector2i) -> Dictionary:
	## First orthogonal MOVE_ATTACK person already next to the party.
	## Call only for foes flagged before this turn's move (xu4 moveObjects).
	for i in persons.size():
		if i >= person_move.size():
			continue
		if int(person_move[i]) != MOVE_ATTACK:
			continue
		if _manhattan(persons[i], avatar) > 1:
			continue
		return take_person_at_index(i)
	return {}


func destroy_all_except_lord_british() -> int:
	## xu4 gameDestroyAllCreatures — wipe Persons except Lord British (tile 94).
	var removed := 0
	for i in range(persons.size() - 1, -1, -1):
		var tid := int(persons[i].z)
		var base := tid
		if (tid >= 32 and tid <= 47) or (tid >= 80 and tid <= 95):
			base = tid & ~1
		if base == 94: ## lord_british
			continue
		persons.remove_at(i)
		if i < person_home.size():
			person_home.remove_at(i)
		if i < person_prev.size():
			person_prev.remove_at(i)
		if i < person_move.size():
			person_move.remove_at(i)
		if i < person_conv.size():
			person_conv.remove_at(i)
		if i < person_file_slot.size():
			person_file_slot.remove_at(i)
		if i < person_role.size():
			person_role.remove_at(i)
		removed += 1
	return removed


func discourse_at(person_i: int) -> Variant:
	## TalkTlk.Entry for person index, or null.
	if person_i < 0 or person_i >= person_conv.size():
		return null
	var cid := int(person_conv[person_i])
	if cid < 0 or cid >= discourses.size():
		return null
	return discourses[cid]


func discourse_index_by_name(npc_name: String) -> int:
	## 0-based discourse id, or -1. Case-insensitive match.
	var want := npc_name.strip_edges().to_lower()
	if want.is_empty():
		return -1
	for i in discourses.size():
		var e = discourses[i]
		if e == null:
			continue
		if str(e.name).strip_edges().to_lower() == want:
			return i
	return -1


func person_index_by_discourse_name(npc_name: String) -> int:
	var di := discourse_index_by_name(npc_name)
	if di < 0:
		return -1
	for i in person_conv.size():
		if int(person_conv[i]) == di:
			return i
	return -1


func spawn_or_relocate_named(
	npc_name: String,
	x: int,
	y: int,
	tile_id: int,
	movement: int = MOVE_WANDER
) -> bool:
	## xu4 InnController::maybeMeetIsaac — place named TLK NPC at (x,y).
	var di := discourse_index_by_name(npc_name)
	if di < 0:
		return false
	x = clampi(x, 0, WIDTH - 1)
	y = clampi(y, 0, HEIGHT - 1)
	var existing := person_index_by_discourse_name(npc_name)
	if existing >= 0:
		var prev_tid := int(persons[existing].z)
		persons[existing] = Vector3i(x, y, tile_id if tile_id > 0 else prev_tid)
		if existing < person_home.size():
			person_home[existing] = Vector2i(x, y)
		else:
			person_home.append(Vector2i(x, y))
		if existing < person_move.size():
			person_move[existing] = movement
		return true
	persons.append(Vector3i(x, y, tile_id))
	person_home.append(Vector2i(x, y))
	person_prev.append(-1)
	person_move.append(movement)
	person_conv.append(di)
	person_file_slot.append(-1)
	person_role.append(_CityNpcRoles.Role.NONE)
	return true


func is_skara_brae() -> bool:
	## xu4 map id 11 — skara.ult.
	return source_path.get_file().to_lower() == "skara.ult"


func role_at(person_i: int) -> int:
	if person_i < 0 or person_i >= person_role.size():
		return _CityNpcRoles.Role.NONE
	return int(person_role[person_i])


func is_vendor_at(person_i: int) -> bool:
	return _CityNpcRoles.is_vendor(role_at(person_i))


func is_shop_like_at(person_i: int) -> bool:
	return _CityNpcRoles.is_shop_like(role_at(person_i))


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
	_apply_terrain_patches(path)
	_load_persons(bytes)
	_apply_file_roles(path)
	_load_tlk(path)
	_apply_person_conv_patches(path)
	_append_extra_people(path)
	## xu4 City::addPeople — omit companions already in the party.
	strip_joined_companions()
	loaded = true
	return true


func strip_joined_companions() -> void:
	## xu4 City::addPeople — omit NPC_TALKER_COMPANION who is already in the party
	## (not merely same class as the Avatar leading the party).
	if persons.is_empty():
		return
	for i in range(persons.size() - 1, -1, -1):
		var nm := _person_talk_name(i)
		if nm.is_empty():
			continue
		if not GameState.is_person_joined(nm):
			continue
		take_person_at_index(i)


func _person_talk_name(person_i: int) -> String:
	## .TLK name for discourse / companion id, or empty.
	var entry: Variant = discourse_at(person_i)
	if entry == null:
		return ""
	return str(entry.name).strip_edges()


func _apply_terrain_patches(ult_path: String) -> void:
	var fname := ult_path.get_file().to_lower()
	var patch: Variant = TERRAIN_PATCHES.get(fname, {})
	if typeof(patch) != TYPE_DICTIONARY or tiles.size() < TILE_COUNT:
		return
	for key in (patch as Dictionary).keys():
		var parts := str(key).split(",")
		if parts.size() != 2:
			continue
		var x := int(parts[0])
		var y := int(parts[1])
		if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT:
			continue
		tiles[y * WIDTH + x] = clampi(int((patch as Dictionary)[key]), 0, 255) & 0xFF


func _apply_person_conv_patches(ult_path: String) -> void:
	## Classic SERPENT.ULT: south gate guards (0-based columns 28–29) reuse
	## Sentri's discourse (0). Nobody points at "the gate guard." (1). Remap.
	var fname := ult_path.get_file().to_lower()
	if fname != "serpent.ult":
		return
	var gate_di := discourse_index_by_name("the gate guard.")
	if gate_di < 0:
		return
	const GATE_FILE_SLOTS := [28, 29]
	for i in person_file_slot.size():
		if int(person_file_slot[i]) not in GATE_FILE_SLOTS:
			continue
		if i < person_conv.size():
			person_conv[i] = gate_di


func _apply_file_roles(ult_path: String) -> void:
	## xu4 maps.b roles: person id is 1-based .ULT column index.
	var roles: Dictionary = _CityNpcRoles.roles_for_ult(ult_path)
	if not roles.is_empty() and not person_file_slot.is_empty():
		for i in person_file_slot.size():
			var slot_1 := int(person_file_slot[i]) + 1
			if roles.has(slot_1):
				person_role[i] = int(roles[slot_1])
	## xu4 Person::initNpcType — beggar/guard tiles when no explicit maps.b role.
	for i in persons.size():
		if i < person_role.size() and int(person_role[i]) != _CityNpcRoles.Role.NONE:
			continue
		var tid := int(persons[i].z)
		if _TalkTlk.is_beggar_tile(tid):
			if i < person_role.size():
				person_role[i] = _CityNpcRoles.Role.BEGGAR
		elif _TalkTlk.is_guard_tile(tid):
			if i < person_role.size():
				person_role[i] = _CityNpcRoles.Role.GUARD

func move_persons(avatar: Vector2i) -> Dictionary:
	## xu4 Map::moveObjects — one attempt per person after the party turn.
	## Attacker is whoever was already adjacent *before* moving (still on map).
	## A foe that steps adjacent this turn engages on the next party turn.
	var out := {"changed": false, "attacker_index": -1}
	if not loaded or persons.is_empty():
		return out
	for i in persons.size():
		if i < person_move.size() and int(person_move[i]) == MOVE_ATTACK:
			if _manhattan(persons[i], avatar) <= 1:
				if int(out["attacker_index"]) < 0:
					out["attacker_index"] = i
		if _move_one(i, avatar):
			out["changed"] = true
	return out


func pause_follow(person_i: int) -> void:
	## xu4 talk: FOLLOW → FOLLOW_PAUSE for one turn.
	if person_i < 0 or person_i >= person_move.size():
		return
	if person_move[person_i] == MOVE_FOLLOW:
		person_move[person_i] = MOVE_FOLLOW_PAUSE


func _append_extra_people(ult_path: String) -> void:
	## Locale-pack NPCs beyond the classic 16 .TLK slots.
	for spec_v in _TalkLocale.extra_npcs_for_map(ult_path):
		if typeof(spec_v) != TYPE_DICTIONARY:
			continue
		var spec: Dictionary = spec_v
		var nm := str(spec.get("name", "")).strip_edges()
		if nm.is_empty() or discourse_index_by_name(nm) >= 0:
			continue
		var x := clampi(int(spec.get("x", 0)), 0, WIDTH - 1)
		var y := clampi(int(spec.get("y", 0)), 0, HEIGHT - 1)
		if person_index_at(x, y) >= 0:
			continue
		var tile_id := int(spec.get("tile", 32))
		if tile_id <= 0:
			tile_id = 32
		var movement := int(spec.get("movement", MOVE_FIXED))
		var di := discourses.size()
		discourses.append(_TalkTlk.entry_from_dict(spec))
		persons.append(Vector3i(x, y, tile_id))
		person_home.append(Vector2i(x, y))
		person_prev.append(-1)
		person_move.append(movement)
		person_conv.append(di)
		person_file_slot.append(-1)
		person_role.append(_CityNpcRoles.Role.NONE)


func _load_tlk(ult_path: String) -> void:
	## xu4 discourse_load city .TLK beside the .ULT.
	discourses.clear()
	var tlk_path: String = _TalkTlk.resolve_tlk_path(ult_path)
	if tlk_path.is_empty():
		return
	## Always load discourse first — locale overlay must never block .TLK.
	discourses = _TalkTlk.load_file(tlk_path)
	_TalkLocale.ensure_city_for_path(ult_path)


func _load_persons(bytes: PackedByteArray) -> void:
	## xu4 loadCityMap person block after terrain.
	persons.clear()
	person_home.clear()
	person_prev.clear()
	person_move.clear()
	person_conv.clear()
	person_file_slot.clear()
	person_role.clear()
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
		person_home.append(Vector2i(x, y))
		var prev := int(pd[PD_PREV_TILE + i])
		person_prev.append(prev if prev != 0 else -1)
		person_move.append(_move_behavior(int(pd[PD_MOVE + i])))
		## xu4: conv_idx[j] == discourse+1 → setDiscourseId(discourse).
		var conv_byte := int(pd[PD_CONV + i])
		person_conv.append(conv_byte - 1 if conv_byte > 0 else -1)
		person_file_slot.append(i)
		person_role.append(_CityNpcRoles.Role.NONE)


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
			## Stay put after the party steps into talk reach (not while beside).
			if _shopkeeper_holds_for_avatar(i, avatar):
				return false
			## Town: 50% stay put (world map always moves — not used here).
			if (randi() % 2) != 0:
				return false
		MOVE_FOLLOW:
			## Inns / healers often FOLLOW; do not sidestep off the facing cell.
			if _shopkeeper_holds_for_avatar(i, avatar):
				return false
			## Town: 50% skip entire follow attempt.
			if (randi() % 2) != 0:
				return false
		MOVE_ATTACK:
			## Already adjacent: hold. Combat uses the pre-move attacker_index.
			if _manhattan(persons[i], avatar) <= 1:
				return false
		_:
			return false

	var pos := Vector2i(int(persons[i].x), int(persons[i].y))
	var valid := _valid_dirs(pos, i, avatar)
	if mode == MOVE_WANDER:
		valid = _filter_wander_leash(i, valid)
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


func _shopkeeper_holds_for_avatar(i: int, avatar: Vector2i) -> bool:
	## Hold only on the facing cell. NPCs move after the party, so sliding
	## from one tile beside into talk reach freezes them that turn; standing
	## beside does not.
	return _is_shop_npc(i) and _shop_talk_reach(i, avatar)


func _is_shop_npc(i: int) -> bool:
	## maps.b vendors / LB / Hawkwind, or anyone on/beside a letter counter.
	if i < 0 or i >= persons.size():
		return false
	if is_shop_like_at(i):
		return true
	var pos := Vector2i(int(persons[i].x), int(persons[i].y))
	if _TileRules.can_talk_over(effective_tile_at(pos.x, pos.y)):
		return true
	for d in _DIRS:
		var n := pos + d
		if n.x < 0 or n.y < 0 or n.x >= WIDTH or n.y >= HEIGHT:
			continue
		if _TileRules.can_talk_over(effective_tile_at(n.x, n.y)):
			return true
	return false


func _shop_talk_reach(i: int, avatar: Vector2i) -> bool:
	## Same reach as Talk: adjacent, or one step past a letter-counter tile.
	if i < 0 or i >= persons.size():
		return false
	var pos := Vector2i(int(persons[i].x), int(persons[i].y))
	var dx := pos.x - avatar.x
	var dy := pos.y - avatar.y
	if dx != 0 and dy != 0:
		return false
	var dist := absi(dx) + absi(dy)
	if dist == 1:
		return true
	if dist != 2:
		return false
	var mid := avatar + Vector2i(signi(dx), signi(dy))
	return _TileRules.can_talk_over(effective_tile_at(mid.x, mid.y))


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
		var mover := 0
		if self_i >= 0 and self_i < persons.size():
			mover = int(persons[self_i].z)
		if _WorldCreatures.is_swimmer(mover):
			if not _TileRules.is_swimable(dest_tid):
				continue
		elif _WorldCreatures.is_incorporeal(mover):
			## Ghost / zorn: walk through walls, not water (xu4 MATTR_INCORPOREAL).
			if _TileRules.is_water(dest_tid):
				continue
		else:
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


func _filter_wander_leash(self_i: int, dirs: Array[Vector2i]) -> Array[Vector2i]:
	## Keep only steps whose orthogonal tile count from home is <= WANDER_LEASH.
	if self_i < 0 or self_i >= persons.size() or self_i >= person_home.size():
		return dirs
	var home: Vector2i = person_home[self_i]
	var pos := Vector2i(int(persons[self_i].x), int(persons[self_i].y))
	var out: Array[Vector2i] = []
	for d in dirs:
		var dest := pos + d
		if absi(dest.x - home.x) + absi(dest.y - home.y) <= WANDER_LEASH:
			out.append(d)
	return out


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
