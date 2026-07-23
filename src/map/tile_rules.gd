class_name TileRules
extends RefCounted

## Ultima IV terrain passability (xu4 tile-rules + u4-save-ids → WORLD.MAP bytes).
## Walk bits: W=1 N=2 E=4 S=8.
## xu4: `cantwalkon` clears walk-*on* only; walk-*off* stays ALL unless `cantwalkoff`.

const WALK_W := 1
const WALK_N := 2
const WALK_E := 4
const WALK_S := 8
const WALK_ALL := 15

const F_SAIL := 1
const F_SWIM := 2
const F_CREATURE_BLOCK := 4 ## xu4 creatureunwalkable — horses cannot enter

## Per tile id 0..255: PackedInt32Array of (walk_on | walk_off<<8 | flags<<16)
static var _table: PackedInt32Array = PackedInt32Array()


static func _ensure() -> void:
	if _table.size() == 256:
		return
	_table.resize(256)
	## Default rule: walkable all ways.
	for i in 256:
		_table[i] = _pack(WALK_ALL, WALK_ALL, 0)
	_fill_named()


static func _pack(walk_on: int, walk_off: int, flags: int) -> int:
	return (walk_on & 0xFF) | ((walk_off & 0xFF) << 8) | ((flags & 0xFF) << 16)


static func _set_range(from_id: int, count: int, walk_on: int, walk_off: int, flags: int) -> void:
	var v := _pack(walk_on, walk_off, flags)
	for i in count:
		var id := from_id + i
		if id >= 0 and id < 256:
			_table[id] = v


static func _blocked(from_id: int, count: int, flags: int = 0) -> void:
	## cantwalkon: all — walk off still allowed (leave tile toward walkable dest).
	_set_range(from_id, count, 0, WALK_ALL, flags)


static func _fill_named() -> void:
	## Indices match xu4 `u4-save-ids` expansion (256 bytes).
	## sea / water: swim + sail
	_set_range(0, 2, 0, WALK_ALL, F_SAIL | F_SWIM)
	## shallows: swim only (ships blocked)
	_set_range(2, 1, 0, WALK_ALL, F_SWIM)
	## swamp, grass, brush, forest, hills — default walkable (already set)
	## mountains
	_blocked(8, 1, F_CREATURE_BLOCK)
	## 9–12 dungeon/city/castle/town — default
	## LCB wings
	_blocked(13, 1, F_CREATURE_BLOCK) ## lcb_west
	## lcb_entrance: cantwalkon south, cantwalkoff north
	_set_range(14, 1, WALK_ALL & ~WALK_S, WALK_ALL & ~WALK_N, F_CREATURE_BLOCK)
	_blocked(15, 1, F_CREATURE_BLOCK) ## lcb_east
	## ship / horse terrain graphics — walkable, creature-blocked
	_set_range(16, 4, WALK_ALL, WALK_ALL, F_CREATURE_BLOCK)
	_set_range(20, 2, WALK_ALL, WALK_ALL, F_CREATURE_BLOCK)
	## dungeon_floor, bridge, balloon, bridge_n/s, ladders, ruins, shrine
	## balloon: creatureunwalkable
	_set_range(24, 1, WALK_ALL, WALK_ALL, F_CREATURE_BLOCK)
	## avatar + class sprites
	_blocked(31, 17, F_CREATURE_BLOCK)
	## column, watersides, mast, wheel, rocks, corpse
	_blocked(48, 9)
	## stone wall / locked door / door
	_blocked(57, 3)
	## chest — walkable
	## ankh — solid
	_blocked(61, 1)
	## floors 62–63 — default
	## moongate opening — solid; open moongate walkable
	_blocked(64, 3)
	## fields: poison/fire/sleep walkable; energy blocked
	_blocked(69, 1, F_CREATURE_BLOCK) ## energy
	_blocked(72, 1) ## solid
	## secret_door: cantwalkon retreat only → NESW ok (default)
	## altar — default walkable; campfire solid
	_blocked(75, 1)
	## lava — walkable (damage later)
	## people 80–95
	_blocked(80, 16, F_CREATURE_BLOCK)
	## signs / spacers / brick wall 96–127
	_blocked(96, 32)
	## pirate ships + sea monsters
	_blocked(128, 12, F_CREATURE_BLOCK)
	## whirlpool — water rule
	_set_range(140, 2, 0, WALK_ALL, F_SAIL | F_SWIM)
	## twister — default walkable (no rule in xu4)
	## land monsters 144–255
	_blocked(144, 112, F_CREATURE_BLOCK)


static func dir_mask(dir: Vector2i) -> int:
	if dir.y < 0:
		return WALK_N
	if dir.y > 0:
		return WALK_S
	if dir.x < 0:
		return WALK_W
	if dir.x > 0:
		return WALK_E
	return 0


static func walk_on(tile_id: int) -> int:
	_ensure()
	tile_id = clampi(tile_id, 0, 255)
	return _table[tile_id] & 0xFF


static func walk_off(tile_id: int) -> int:
	_ensure()
	tile_id = clampi(tile_id, 0, 255)
	return (_table[tile_id] >> 8) & 0xFF


static func flags(tile_id: int) -> int:
	_ensure()
	tile_id = clampi(tile_id, 0, 255)
	return (_table[tile_id] >> 16) & 0xFF


static func is_sailable(tile_id: int) -> bool:
	return (flags(tile_id) & F_SAIL) != 0


static func is_swimable(tile_id: int) -> bool:
	return (flags(tile_id) & F_SWIM) != 0


static func is_water(tile_id: int) -> bool:
	return is_sailable(tile_id) or is_swimable(tile_id)


static func can_walk_on(tile_id: int, dir: Vector2i) -> bool:
	var bit := dir_mask(dir)
	return bit != 0 and (walk_on(tile_id) & bit) != 0


static func can_walk_off(tile_id: int, dir: Vector2i) -> bool:
	var bit := dir_mask(dir)
	return bit != 0 and (walk_off(tile_id) & bit) != 0


static func is_creature_walkable(tile_id: int) -> bool:
	## xu4: walkonDirs > 0 and not creatureunwalkable.
	return walk_on(tile_id) != 0 and (flags(tile_id) & F_CREATURE_BLOCK) == 0


static func can_avatar_enter(
	dest_id: int,
	from_id: int,
	dir: Vector2i,
	on_ship: bool,
	on_horse: bool
) -> bool:
	## xu4 Map::getValidMoves — avatar / horse / ship branches.
	if on_ship:
		return is_sailable(dest_id)
	if not can_walk_on(dest_id, dir):
		return false
	if not can_walk_off(from_id, dir):
		return false
	if on_horse and not is_creature_walkable(dest_id):
		return false
	return true
