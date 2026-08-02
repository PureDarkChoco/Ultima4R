class_name WorldCreatures
extends RefCounted

## xu4 wilderness creature spawn / cleanup / move (`game.cpp`, `map.cpp`, `location.cpp`).
## Spawns just outside the explore viewport so monsters do not pop on-screen.
## Prefer preload over bare class_name types (stale global class cache → black screen).

const _TileRules := preload("res://src/map/tile_rules.gd")
const _WorldMapDataScript := preload("res://src/map/world_map_data.gd")

const MAX_CREATURES_ON_MAP := 4
const MAX_CREATURE_DISTANCE := 16
const SPAWN_DIVISOR_WORLD := 32
const SPAWN_TRIES := 10
## xu4 fireAt / pirate specialAction — cannonball range (tiles).
const CANNON_RANGE := 3

const TILE_PIRATE := 128
const TILE_NIXIE := 132
const TILE_ORC := 192

const MOVE_FIXED := 0
const MOVE_WANDER := 1
const MOVE_ATTACK := 2

const _DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)
]

## (base_tile, frame_count) — consecutive tile ids are animation / pirate facing.
const _CREATURE_BASES: Array[Vector2i] = [
	Vector2i(128, 4), ## pirate WNES
	Vector2i(132, 2), ## nixie
	Vector2i(134, 2), ## giant squid
	Vector2i(136, 2), ## sea serpent
	Vector2i(138, 2), ## seahorse
	Vector2i(140, 2), ## whirlpool
	Vector2i(142, 2), ## twister
	Vector2i(144, 4), ## rat
	Vector2i(148, 4), ## bat
	Vector2i(152, 4), ## spider
	Vector2i(156, 4), ## ghost
	Vector2i(160, 4), ## slime
	Vector2i(164, 4), ## troll
	Vector2i(168, 4), ## gremlin
	Vector2i(172, 4), ## mimic
	Vector2i(176, 4), ## reaper
	Vector2i(180, 4), ## insects
	Vector2i(184, 4), ## gazer
	Vector2i(188, 4), ## phantom
	Vector2i(192, 4), ## orc
	Vector2i(196, 4), ## skeleton
	Vector2i(200, 4), ## rogue
	Vector2i(204, 4), ## python
	Vector2i(208, 4), ## ettin
	Vector2i(212, 4), ## headless
	Vector2i(216, 4), ## cyclops
	Vector2i(220, 4), ## wisp
	Vector2i(224, 4), ## evil mage
	Vector2i(228, 4), ## liche
	Vector2i(232, 4), ## lava lizard
	Vector2i(236, 4), ## zorn
	Vector2i(240, 4), ## daemon
	Vector2i(244, 4), ## hydra
	Vector2i(248, 4), ## dragon
	Vector2i(252, 4), ## balron
]

## Labels for combat engage messages (xu4 creature names, short form).
const _DISPLAY_NAMES := {
	128: "Pirates",
	132: "Nixie",
	134: "Giant Squid",
	136: "Sea Serpent",
	138: "Seahorse",
	140: "Whirlpool",
	142: "Twister",
	144: "Rat",
	148: "Bat",
	152: "Spider",
	156: "Ghost",
	160: "Slime",
	164: "Troll",
	168: "Gremlin",
	172: "Mimic",
	176: "Reaper",
	180: "Insects",
	184: "Gazer",
	188: "Phantom",
	192: "Orc",
	196: "Skeleton",
	200: "Rogue",
	204: "Python",
	208: "Ettin",
	212: "Headless",
	216: "Cyclops",
	220: "Wisp",
	224: "Mage",
	228: "Liche",
	232: "Lava Lizard",
	236: "Zorn",
	240: "Daemon",
	244: "Hydra",
	248: "Dragon",
	252: "Balron",
}

## xu4 config.b basehp by creature base tile (pirate has none → 100).
const _BASE_HP := {
	128: 100,
	132: 64,
	134: 96,
	136: 128,
	138: 128,
	140: 255,
	142: 255,
	144: 48,
	148: 48,
	152: 64,
	156: 80,
	160: 48,
	164: 96,
	168: 48,
	172: 192,
	176: 255,
	180: 48,
	184: 240,
	188: 128,
	192: 80,
	196: 48,
	200: 80,
	204: 48,
	208: 112,
	212: 64,
	216: 128,
	220: 64,
	224: 176,
	228: 192,
	232: 96,
	236: 240,
	240: 112,
	244: 208,
	248: 224,
	252: 255,
}

## Entries: { x, y, tile, facing, movement, hp, max_hp, show_hp }
var creatures: Array[Dictionary] = []


func clear() -> void:
	creatures.clear()


func count() -> int:
	return creatures.size()


func to_save() -> Array:
	var out: Array = []
	for c in creatures:
		out.append({
			"x": int(c.get("x", 0)),
			"y": int(c.get("y", 0)),
			"t": int(c.get("tile", 0)),
			"f": int(c.get("facing", 0)),
			"hp": int(c.get("hp", 0)),
			"mh": int(c.get("max_hp", 0)),
			"sh": bool(c.get("show_hp", false)),
		})
	return out


func from_save(raw: Variant) -> void:
	creatures.clear()
	if typeof(raw) != TYPE_ARRAY:
		return
	for item in raw as Array:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		var tid := int(d.get("t", d.get("tile", -1)))
		if tid < 0:
			continue
		var base := _base_tile(tid)
		var facing := int(d.get("f", d.get("facing", 0)))
		if base == TILE_PIRATE and tid >= TILE_PIRATE and tid < TILE_PIRATE + 4:
			facing = tid - TILE_PIRATE
		var c := _make_creature(int(d.get("x", 0)), int(d.get("y", 0)), base, facing)
		var mh := int(d.get("mh", d.get("max_hp", 0)))
		var hp := int(d.get("hp", 0))
		if mh > 0:
			c["max_hp"] = mh
			c["hp"] = clampi(hp, 0, mh) if hp > 0 else mh
		if d.has("sh") or d.has("show_hp"):
			c["show_hp"] = bool(d.get("sh", d.get("show_hp", false)))
		elif mh > 0 and int(c["hp"]) < mh:
			c["show_hp"] = true
		creatures.append(c)


func as_paint_items() -> Array:
	## { x, y, tid, hp, max_hp } — MapView animates tid and draws HP bars.
	var out: Array = []
	for c in creatures:
		var base := int(c.get("tile", 0))
		var tid := base
		if base == TILE_PIRATE:
			tid = base + clampi(int(c.get("facing", 0)), 0, 3)
		out.append({
			"x": int(c["x"]),
			"y": int(c["y"]),
			"tid": tid,
			"hp": int(c.get("hp", 0)),
			"max_hp": int(c.get("max_hp", 1)),
			"show_hp": bool(c.get("show_hp", false)),
		})
	return out


static func resolve_paint_tile(stored_tid: int, anim_tick: int) -> int:
	## Pirate facing tiles stay fixed; other creatures cycle consecutive tile ids.
	var tid := clampi(stored_tid, 0, 255)
	if tid >= TILE_PIRATE and tid < TILE_PIRATE + 4:
		return tid
	var base := _base_tile(tid)
	var frames := _frame_count(base)
	if frames <= 1:
		return base
	return base + posmod(anim_tick, frames)


func creature_at(tile: Vector2i) -> int:
	## Base tile id at `tile`, or -1.
	for c in creatures:
		if int(c["x"]) == tile.x and int(c["y"]) == tile.y:
			return int(c["tile"])
	return -1


func creature_dict_at(tile: Vector2i) -> Dictionary:
	## Copy of the creature record at `tile`, or {}.
	for c in creatures:
		if int(c["x"]) == tile.x and int(c["y"]) == tile.y:
			return (c as Dictionary).duplicate(true)
	return {}


func take_at(tile: Vector2i) -> Dictionary:
	## Remove and return the creature at `tile` (for combat engage).
	for i in creatures.size():
		var c: Dictionary = creatures[i]
		if int(c["x"]) == tile.x and int(c["y"]) == tile.y:
			creatures.remove_at(i)
			return c.duplicate(true)
	return {}


func remove_at(tile: Vector2i) -> bool:
	for i in creatures.size():
		var c: Dictionary = creatures[i]
		if int(c["x"]) == tile.x and int(c["y"]) == tile.y:
			creatures.remove_at(i)
			return true
	return false


static func display_name(tile_or_base: int) -> String:
	## Short English label for messages (Attacked by …).
	var base := _base_tile(tile_or_base)
	return str(_DISPLAY_NAMES.get(base, "Creature"))


func apply_cannon_damage_at(tile: Vector2i) -> Dictionary:
	## Player cannon hit — ~1/4 max HP per shot so the bar reads ~4 hits to kill.
	for i in creatures.size():
		var c: Dictionary = creatures[i]
		if int(c["x"]) != tile.x or int(c["y"]) != tile.y:
			continue
		var max_hp := maxi(1, int(c.get("max_hp", base_hp_for(int(c.get("tile", 0))))))
		var hp := int(c.get("hp", max_hp))
		var dmg := maxi(1, (max_hp + 3) / 4)
		hp = maxi(0, hp - dmg)
		c["hp"] = hp
		c["max_hp"] = max_hp
		## Stay visible until death or combat clears the wilderness list.
		c["show_hp"] = true
		if hp <= 0:
			creatures.remove_at(i)
			return {"dead": true, "hp": 0, "max_hp": max_hp, "pos": tile}
		creatures[i] = c
		return {"dead": false, "hp": hp, "max_hp": max_hp, "pos": tile}
	return {}


func clear_hp_bars() -> void:
	## Hide bars when combat starts (wilderness creatures leave the explore view).
	for i in creatures.size():
		var c: Dictionary = creatures[i]
		if bool(c.get("show_hp", false)):
			c["show_hp"] = false
			creatures[i] = c


static func base_hp_for(base_tile: int) -> int:
	var base := _base_tile(base_tile)
	return int(_BASE_HP.get(base, 80))


func cleanup(avatar: Vector2i) -> bool:
	## xu4 GameController::creatureCleanup — drop creatures beyond distance 16.
	var before := creatures.size()
	var kept: Array[Dictionary] = []
	for c in creatures:
		var pos := Vector2i(int(c["x"]), int(c["y"]))
		if map_distance(avatar, pos) <= MAX_CREATURE_DISTANCE:
			kept.append(c)
	creatures = kept
	return creatures.size() != before


func move_all(
	world,
	avatar: Vector2i,
	blocked: Callable = Callable(),
	on_pirate_fire: Callable = Callable()
) -> Dictionary:
	## xu4 Map::moveObjects — specialAction then move.
	## Returns { "changed": bool, "attacker": Dictionary } — attacker still on map.
	var out := {"changed": false, "attacker": {}}
	if world == null or not world.loaded:
		return out
	var changed := false
	var attacker: Dictionary = {}
	for i in creatures.size():
		var c: Dictionary = creatures[i]
		var pos := Vector2i(int(c["x"]), int(c["y"]))
		## xu4: orthogonally adjacent attackers become combatant — skip action+move.
		if (
			int(c.get("movement", MOVE_ATTACK)) == MOVE_ATTACK
			and _ortho_adjacent(pos, avatar)
		):
			if attacker.is_empty():
				attacker = c.duplicate(true)
			continue
		if _try_pirate_cannon(i, avatar, on_pirate_fire):
			changed = true
			continue
		if _move_one(i, world, avatar, blocked):
			changed = true
	out["changed"] = changed
	out["attacker"] = attacker
	return out


func _try_pirate_cannon(index: int, avatar: Vector2i, on_fire: Callable) -> bool:
	## xu4 Creature::specialAction PIRATE_ID — broadsides only, range 1..3.
	if index < 0 or index >= creatures.size():
		return false
	var c: Dictionary = creatures[index]
	if int(c.get("tile", 0)) != TILE_PIRATE:
		return false
	var pos := Vector2i(int(c["x"]), int(c["y"]))
	var delta := wrap_delta(pos, avatar)
	var adx := absi(delta.x)
	var ady := absi(delta.y)
	if not ((adx == 0 and ady <= CANNON_RANGE) or (ady == 0 and adx <= CANNON_RANGE)):
		return false
	if adx == 0 and ady == 0:
		return false
	var shot := Vector2i.ZERO
	if adx == 0:
		shot = Vector2i(0, 1 if delta.y > 0 else -1)
	else:
		shot = Vector2i(1 if delta.x > 0 else -1, 0)
	var facing := _facing_to_dir(int(c.get("facing", 0)))
	if not is_broadside_dir(facing, shot):
		return false
	if on_fire.is_valid():
		on_fire.call(pos, shot)
	return true


static func is_broadside_dir(ship_facing: Vector2i, fire_dir: Vector2i) -> bool:
	## xu4 dirGetBroadsidesDirs — port/starboard only (not fore/aft).
	if fire_dir == Vector2i.ZERO:
		return false
	if ship_facing == fire_dir or ship_facing == -fire_dir:
		return false
	## Must be a cardinal orthogonal to facing.
	if ship_facing.x != 0:
		return fire_dir.x == 0 and fire_dir.y != 0
	if ship_facing.y != 0:
		return fire_dir.y == 0 and fire_dir.x != 0
	return false


static func _facing_to_dir(facing: int) -> Vector2i:
	## Pirate frames: W N E S.
	match clampi(facing, 0, 3):
		0:
			return Vector2i(-1, 0)
		1:
			return Vector2i(0, -1)
		2:
			return Vector2i(1, 0)
		_:
			return Vector2i(0, 1)


static func cannon_path(origin: Vector2i, dir: Vector2i, max_range: int = CANNON_RANGE) -> Array[Vector2i]:
	## xu4 gameGetDirectionalActionPath with no blocker — 1..max_range.
	var out: Array[Vector2i] = []
	if dir == Vector2i.ZERO or max_range < 1:
		return out
	var cur := origin
	for _i in max_range:
		cur = Vector2i(
			posmod(cur.x + dir.x, _WorldMapDataScript.WIDTH),
			posmod(cur.y + dir.y, _WorldMapDataScript.HEIGHT)
		)
		out.append(cur)
	return out


func try_random_spawn(
	world,
	avatar: Vector2i,
	view_w: int,
	view_h: int,
	moves: int,
	blocked: Callable = Callable()
) -> bool:
	## xu4 checkRandomCreatures + gameSpawnCreature(NULL) for the world map.
	if world == null or not world.loaded:
		return false
	if creatures.size() >= MAX_CREATURES_ON_MAP:
		return false
	if randi() % SPAWN_DIVISOR_WORLD != 0:
		return false
	return spawn_offscreen(world, avatar, view_w, view_h, moves, blocked)


func spawn_offscreen(
	world,
	avatar: Vector2i,
	view_w: int,
	view_h: int,
	moves: int,
	blocked: Callable = Callable()
) -> bool:
	## xu4 offscreen ring, widened so the explore viewport never sees a pop-in.
	if world == null or not world.loaded:
		return false
	var half_x := maxi(view_w / 2, 0)
	var half_y := maxi(view_h / 2, 0)
	var ring_x := half_x + 1
	var ring_y := half_y + 1
	for _try in SPAWN_TRIES:
		var dx := ring_x
		var dy := randi() % maxi(ring_y, 1)
		if randi() % 2 != 0:
			dx = -dx
		if randi() % 2 != 0:
			dy = -dy
		if randi() % 2 != 0:
			var t := dx
			dx = dy
			dy = t
		var pos := Vector2i(
			posmod(avatar.x + dx, _WorldMapDataScript.WIDTH),
			posmod(avatar.y + dy, _WorldMapDataScript.HEIGHT)
		)
		if pos == avatar:
			continue
		if _in_view_rect(avatar, pos, half_x, half_y):
			continue
		if blocked.is_valid() and bool(blocked.call(pos)):
			continue
		var terrain := int(world.tile_at(pos.x, pos.y))
		var tid := random_for_tile(terrain, moves)
		if tid < 0:
			continue
		if creature_at(pos) >= 0:
			continue
		creatures.append(_make_creature(pos.x, pos.y, tid, 0))
		return true
	return false


static func random_for_tile(tile_id: int, moves: int) -> int:
	## xu4 Creature::randomForTile — returns base tile id, or -1.
	var base := -1
	var rn := 0
	if _TileRules.is_sailable(tile_id):
		base = TILE_PIRATE
		rn = randi() % 7
	elif _TileRules.is_swimable(tile_id):
		base = TILE_NIXIE
		rn = randi() % 5
	elif _TileRules.is_creature_walkable(tile_id):
		var era := 0x0f
		if moves < 10000:
			era = 0x03
		elif moves < 30000:
			era = 0x07
		base = TILE_ORC
		rn = era & (randi() % 0x10) & (randi() % 0x10)
	else:
		return -1
	return _base_tile(base + rn)


static func map_distance(a: Vector2i, b: Vector2i) -> int:
	## Wrap-aware Chebyshev distance (xu4 map_distance intent on the world map).
	var d := wrap_delta(a, b)
	return maxi(absi(d.x), absi(d.y))


static func wrap_delta(from: Vector2i, to: Vector2i) -> Vector2i:
	var dx := to.x - from.x
	var dy := to.y - from.y
	var w := _WorldMapDataScript.WIDTH
	var h := _WorldMapDataScript.HEIGHT
	if dx > w / 2:
		dx -= w
	elif dx < -w / 2:
		dx += w
	if dy > h / 2:
		dy -= h
	elif dy < -h / 2:
		dy += h
	return Vector2i(dx, dy)


func _make_creature(x: int, y: int, base_tile: int, facing: int) -> Dictionary:
	var base := _base_tile(base_tile)
	var max_hp := base_hp_for(base)
	return {
		"x": x,
		"y": y,
		"tile": base,
		"facing": clampi(facing, 0, 3),
		"movement": _default_movement(base),
		"hp": max_hp,
		"max_hp": max_hp,
		"show_hp": false,
	}


func _move_one(
	index: int,
	world,
	avatar: Vector2i,
	blocked: Callable
) -> bool:
	var c: Dictionary = creatures[index]
	var mode := int(c.get("movement", MOVE_ATTACK))
	var pos := Vector2i(int(c["x"]), int(c["y"]))
	var base := int(c["tile"])

	## xu4: orthogonally adjacent attackers hold and become the combatant (later).
	if mode == MOVE_ATTACK and _ortho_adjacent(pos, avatar):
		return false
	if mode == MOVE_FIXED:
		return false

	var valid := _valid_dirs(index, pos, base, world, avatar, blocked)
	if valid.is_empty():
		return false

	var dir := Vector2i.ZERO
	match mode:
		MOVE_WANDER:
			## World wanderers always pick a random valid dir (xu4).
			dir = valid[randi() % valid.size()]
		MOVE_ATTACK:
			dir = _path_to(pos, avatar, valid)
		_:
			return false
	if dir == Vector2i.ZERO:
		return false

	var next := Vector2i(
		posmod(pos.x + dir.x, _WorldMapDataScript.WIDTH),
		posmod(pos.y + dir.y, _WorldMapDataScript.HEIGHT)
	)
	if next == avatar:
		return false
	if blocked.is_valid() and bool(blocked.call(next)):
		return false
	if creature_at(next) >= 0:
		return false

	## xu4 slowedByTile on destination terrain.
	if _TileRules.slowed_by_tile(int(world.tile_at(next.x, next.y))):
		## Still update pirate facing if they "turned".
		if base == TILE_PIRATE:
			var face := _dir_to_facing(dir)
			if int(c.get("facing", 0)) != face:
				c["facing"] = face
				creatures[index] = c
				return true
		return false

	## Pirate ships turn instead of moving when setDirection changes (xu4).
	if base == TILE_PIRATE:
		var face := _dir_to_facing(dir)
		if int(c.get("facing", 0)) != face:
			c["facing"] = face
			creatures[index] = c
			return true

	c["x"] = next.x
	c["y"] = next.y
	creatures[index] = c
	return true


func _valid_dirs(
	self_i: int,
	from: Vector2i,
	base: int,
	world,
	avatar: Vector2i,
	blocked: Callable
) -> Array[Vector2i]:
	## xu4 Map::getValidMoves for wilderness creatures.
	var out: Array[Vector2i] = []
	var from_tid := int(world.tile_at(from.x, from.y))
	var sails := _sails(base)
	var swims := _swims(base)
	var flies := _flies(base)
	var walks := _walks(base)
	var incorp := _incorporeal(base)
	for d in _DIRS:
		var dest := Vector2i(
			posmod(from.x + d.x, _WorldMapDataScript.WIDTH),
			posmod(from.y + d.y, _WorldMapDataScript.HEIGHT)
		)
		if dest == avatar and not _can_move_onto_avatar(base):
			continue
		if _creature_index_at(dest) >= 0 and _creature_index_at(dest) != self_i:
			if not _can_move_onto_creatures(base):
				continue
		if blocked.is_valid() and bool(blocked.call(dest)):
			## Overlays (horse/ship) block unless force-of-nature style.
			if not _can_move_onto_creatures(base):
				continue
		var dest_tid := int(world.tile_at(dest.x, dest.y))
		var ok := false
		if flies:
			## xu4: on world map, flying creatures may step any direction.
			ok = true
		elif sails and _TileRules.is_sailable(dest_tid):
			ok = true
		elif swims and _TileRules.is_swimable(dest_tid):
			ok = true
		elif incorp:
			ok = not _TileRules.is_water(dest_tid)
		elif walks:
			ok = (
				_TileRules.can_walk_on(dest_tid, d)
				and _TileRules.can_walk_off(from_tid, d)
				and _TileRules.is_creature_walkable(dest_tid)
			)
		if ok:
			out.append(d)
	return out


func _path_to(from: Vector2i, to: Vector2i, valid: Array[Vector2i]) -> Vector2i:
	## xu4 map_pathTo with world wrap.
	if valid.is_empty():
		return Vector2i.ZERO
	var delta := wrap_delta(from, to)
	var prefer: Array[Vector2i] = []
	for d in valid:
		var toward := false
		if delta.x > 0 and d.x > 0:
			toward = true
		if delta.x < 0 and d.x < 0:
			toward = true
		if delta.y > 0 and d.y > 0:
			toward = true
		if delta.y < 0 and d.y < 0:
			toward = true
		if toward:
			prefer.append(d)
	var pool: Array[Vector2i] = prefer if not prefer.is_empty() else valid
	return pool[randi() % pool.size()]


func _creature_index_at(tile: Vector2i) -> int:
	for i in creatures.size():
		var c: Dictionary = creatures[i]
		if int(c["x"]) == tile.x and int(c["y"]) == tile.y:
			return i
	return -1


static func _default_movement(base: int) -> int:
	## xu4 Map::addCreature — wanders / stationary / else attack avatar.
	match base:
		172, 176: ## mimic, reaper
			return MOVE_FIXED
		138, 140, 142, 144, 148, 152, 180, 204: ## wanderers
			return MOVE_WANDER
		_:
			return MOVE_ATTACK


static func _sails(base: int) -> bool:
	return base == TILE_PIRATE


static func _swims(base: int) -> bool:
	return base == 132 or base == 134 or base == 136 or base == 138 or base == 140


static func _flies(base: int) -> bool:
	return base == 142 or base == 148 or base == 240 or base == 248 or base == 252


static func _walks(base: int) -> bool:
	return not _sails(base) and not _swims(base) and not _flies(base)


static func _incorporeal(base: int) -> bool:
	return base == 156 or base == 236 ## ghost, zorn


static func _can_move_onto_avatar(base: int) -> bool:
	return base == 140 or base == 142 ## whirlpool, twister


static func _can_move_onto_creatures(base: int) -> bool:
	return base == 140 or base == 142


static func _dir_to_facing(dir: Vector2i) -> int:
	## Pirate frames: W N E S (config.b directions: wnes).
	if dir.x < 0:
		return 0
	if dir.y < 0:
		return 1
	if dir.x > 0:
		return 2
	return 3


static func _ortho_adjacent(a: Vector2i, b: Vector2i) -> bool:
	## xu4 map_movementDistance <= 1 (orthogonal only).
	var d := wrap_delta(a, b)
	return absi(d.x) + absi(d.y) == 1


static func _in_view_rect(center: Vector2i, pos: Vector2i, half_x: int, half_y: int) -> bool:
	var d := wrap_delta(center, pos)
	return absi(d.x) <= half_x and absi(d.y) <= half_y


static func _base_tile(tile_id: int) -> int:
	var tid := clampi(tile_id, 0, 255)
	for entry in _CREATURE_BASES:
		var base := entry.x
		var frames := entry.y
		if tid >= base and tid < base + frames:
			return base
	return tid


static func _frame_count(base: int) -> int:
	for entry in _CREATURE_BASES:
		if entry.x == base:
			return entry.y
	return 1
