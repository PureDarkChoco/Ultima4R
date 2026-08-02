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

## Per tile id 0..255: PackedInt32Array of (walk_on | walk_off<<8 | flags<<16 | speed<<24)
static var _table: PackedInt32Array = PackedInt32Array()
## xu4 TileEffect per tile id (separate from speed packing).
static var _effects: PackedByteArray = PackedByteArray()

## xu4 TileSpeed (types.h) — destination tile can stall a foot/horse step.
enum Speed { FAST = 0, SLOW = 1, VSLOW = 2, VVSLOW = 3 }

## xu4 TileEffect (types.h) — ground underfoot after each turn.
enum Effect { NONE = 0, POISON = 1, POISONFIELD = 2, FIRE = 3, SLEEP = 4, LAVA = 5 }


static func _ensure() -> void:
	if _table.size() == 256:
		return
	_table.resize(256)
	_effects.resize(256)
	_effects.fill(Effect.NONE)
	## Default rule: walkable all ways.
	for i in 256:
		_table[i] = _pack(WALK_ALL, WALK_ALL, 0)
	_fill_named()


static func _pack(walk_on: int, walk_off: int, flags: int, speed: int = Speed.FAST) -> int:
	return (
		(walk_on & 0xFF)
		| ((walk_off & 0xFF) << 8)
		| ((flags & 0xFF) << 16)
		| ((speed & 0xFF) << 24)
	)


static func _set_range(
	from_id: int, count: int, walk_on: int, walk_off: int, flags: int, speed: int = Speed.FAST
) -> void:
	var v := _pack(walk_on, walk_off, flags, speed)
	for i in count:
		var id := from_id + i
		if id >= 0 and id < 256:
			_table[id] = v


static func _blocked(from_id: int, count: int, flags: int = 0) -> void:
	## cantwalkon: all — walk off still allowed (leave tile toward walkable dest).
	_set_range(from_id, count, 0, WALK_ALL, flags)


static func _set_speed(from_id: int, count: int, speed: int) -> void:
	for i in count:
		var id := from_id + i
		if id < 0 or id >= 256:
			continue
		var v: int = _table[id]
		_table[id] = (v & 0x00FFFFFF) | ((speed & 0xFF) << 24)


static func _set_effect(from_id: int, count: int, effect: int) -> void:
	for i in count:
		var id := from_id + i
		if id < 0 or id >= 256:
			continue
		_effects[id] = effect


static func _fill_named() -> void:
	## Indices match xu4 `u4-save-ids` expansion (256 bytes).
	## sea / water: swim + sail
	_set_range(0, 2, 0, WALK_ALL, F_SAIL | F_SWIM)
	## shallows: swim only (ships blocked)
	_set_range(2, 1, 0, WALK_ALL, F_SWIM)
	## swamp / grass / brush / forest / hills
	_set_speed(3, 1, Speed.SLOW) ## swamp — 1/8 stall
	_set_effect(3, 1, Effect.POISON) ## swamp — 1/5 poison / member / turn
	_set_speed(5, 1, Speed.VSLOW) ## brush — 1/4 stall
	_set_speed(6, 1, Speed.VSLOW) ## forest uses brush rule — 1/4 stall
	_set_speed(7, 1, Speed.VVSLOW) ## hills — 1/2 stall
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
	## Mark door tiles (ids from u4-save-ids / shapes).
	## 58 locked_door, 59 door — walk already blocked above.
	## chest — walkable
	## ankh — solid
	_blocked(61, 1)
	## floors 62–63 — default
	## moongate opening — solid; open moongate walkable
	_blocked(64, 3)
	## fields: poison/fire/sleep walkable; energy blocked
	_set_effect(68, 1, Effect.POISONFIELD) ## poison_field — same 1/5 as swamp
	_blocked(69, 1, F_CREATURE_BLOCK) ## energy
	_set_speed(70, 1, Speed.VVSLOW) ## fire_field — 1/2 stall
	_set_effect(70, 1, Effect.FIRE)
	_set_effect(71, 1, Effect.SLEEP)
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


static func speed_of(tile_id: int) -> int:
	_ensure()
	tile_id = clampi(tile_id, 0, 255)
	return (_table[tile_id] >> 24) & 0xFF


static func effect_of(tile_id: int) -> int:
	_ensure()
	tile_id = clampi(tile_id, 0, 255)
	return int(_effects[tile_id])


static func slowed_by_tile(tile_id: int) -> bool:
	## xu4 location.cpp slowedByTile — independent roll per step into the tile.
	match speed_of(tile_id):
		Speed.SLOW:
			return (randi() % 8) == 0 ## 12.5%
		Speed.VSLOW:
			return (randi() % 4) == 0 ## 25%
		Speed.VVSLOW:
			return (randi() % 2) == 0 ## 50%
		_:
			return false


static func is_sailable(tile_id: int) -> bool:
	return (flags(tile_id) & F_SAIL) != 0


static func is_swimable(tile_id: int) -> bool:
	return (flags(tile_id) & F_SWIM) != 0


static func is_water(tile_id: int) -> bool:
	return is_sailable(tile_id) or is_swimable(tile_id)


static func is_opaque(tile_id: int) -> bool:
	## xu4 Tile::isOpaque — config.b `opaque: square|round` (blocks LOS past the tile).
	## forest/mountains round; secret_door/brick_wall square. stone_wall is NOT opaque.
	match clampi(tile_id, 0, 255):
		6, 8, 73, 127: ## forest, mountains, secret_door, brick_wall
			return true
		_:
			return false


static func blocks_weapon_shot(tile_id: int) -> bool:
	## Combat aim LOF: walls and ship pillars stop projectiles past them.
	## column 48, shipmast 53, stone_wall 57, brick_wall 127.
	match clampi(tile_id, 0, 255):
		48, 53, 57, 127:
			return true
		_:
			return false


static func cells_on_line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	## Straight grid line (orthogonal / diagonal), including both endpoints.
	var cells: Array[Vector2i] = []
	var dx := b.x - a.x
	var dy := b.y - a.y
	var steps := maxi(absi(dx), absi(dy))
	if steps <= 0:
		cells.append(a)
		return cells
	for i in steps + 1:
		var t := float(i) / float(steps)
		var p := Vector2i(
			int(round(float(a.x) + float(dx) * t)),
			int(round(float(a.y) + float(dy) * t))
		)
		if cells.is_empty() or cells[cells.size() - 1] != p:
			cells.append(p)
	return cells


static func is_door(tile_id: int) -> bool:
	## xu4 Tile::isDoor — unlocked door (id 59).
	return clampi(tile_id, 0, 255) == 59


static func is_locked_door(tile_id: int) -> bool:
	## xu4 Tile::isLockedDoor — id 58.
	return clampi(tile_id, 0, 255) == 58


static func is_chest(tile_id: int) -> bool:
	## xu4 Tile::isChest — id 60.
	return clampi(tile_id, 0, 255) == 60


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
