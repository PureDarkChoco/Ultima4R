class_name CombatEncounter
extends RefCounted

## xu4 CombatController::fillCreatureTable / initialNumberOfCreatures.
## Prefer preload over bare class_name types (stale global class cache).

const _WorldCreaturesScript := preload("res://src/map/world_creatures.gd")

const AREA_CREATURES := 16
const PIRATE_TILE := 128
const ROGUE_TILE := 200

## base world tile → {id, encounter_size, leader_id, tile}
## leader_id 0 / self means no leader upgrade (xu4 leader defaults to own id).
const _CREATURES := {
	128: {"id": 18, "size": 1, "leader": 18, "tile": 128}, ## Pirate → Rogue in fill
	132: {"id": 19, "size": 12, "leader": 22, "tile": 132},
	134: {"id": 20, "size": 4, "leader": 21, "tile": 134},
	136: {"id": 21, "size": 4, "leader": 20, "tile": 136},
	138: {"id": 22, "size": 8, "leader": 19, "tile": 138},
	140: {"id": 23, "size": 1, "leader": 23, "tile": 140},
	142: {"id": 24, "size": 1, "leader": 24, "tile": 142},
	144: {"id": 25, "size": 12, "leader": 38, "tile": 144},
	148: {"id": 26, "size": 12, "leader": 47, "tile": 148},
	152: {"id": 27, "size": 6, "leader": 25, "tile": 152},
	156: {"id": 28, "size": 4, "leader": 46, "tile": 156},
	160: {"id": 29, "size": 15, "leader": 29, "tile": 160},
	164: {"id": 30, "size": 6, "leader": 41, "tile": 164},
	168: {"id": 31, "size": 15, "leader": 31, "tile": 168},
	172: {"id": 32, "size": 1, "leader": 32, "tile": 172},
	176: {"id": 33, "size": 1, "leader": 33, "tile": 176},
	180: {"id": 34, "size": 15, "leader": 25, "tile": 180},
	184: {"id": 35, "size": 4, "leader": 36, "tile": 184},
	188: {"id": 36, "size": 8, "leader": 28, "tile": 188},
	192: {"id": 37, "size": 10, "leader": 30, "tile": 192},
	196: {"id": 38, "size": 12, "leader": 45, "tile": 196},
	200: {"id": 39, "size": 10, "leader": 39, "tile": 200},
	204: {"id": 40, "size": 12, "leader": 25, "tile": 204},
	208: {"id": 41, "size": 6, "leader": 49, "tile": 208},
	212: {"id": 42, "size": 8, "leader": 35, "tile": 212},
	216: {"id": 43, "size": 6, "leader": 48, "tile": 216},
	220: {"id": 44, "size": 12, "leader": 36, "tile": 220},
	224: {"id": 45, "size": 6, "leader": 49, "tile": 224},
	228: {"id": 46, "size": 4, "leader": 49, "tile": 228},
	232: {"id": 47, "size": 8, "leader": 50, "tile": 232},
	236: {"id": 48, "size": 4, "leader": 35, "tile": 236},
	240: {"id": 49, "size": 6, "leader": 52, "tile": 240},
	244: {"id": 50, "size": 4, "leader": 51, "tile": 244},
	248: {"id": 51, "size": 4, "leader": 52, "tile": 248},
	252: {"id": 52, "size": 1, "leader": 52, "tile": 252},
}

## Creature id → base tile (for leader lookups).
static var _id_to_tile: Dictionary = {}

## xu4 config.b ambushes: true — Creature::randomAmbushing pool.
const _AMBUSHING_TILES: Array[int] = [
	160, ## Slime
	164, ## Troll
	180, ## Insect Swarm
	192, ## Orc
	196, ## Skeleton
	200, ## Rogue
	204, ## Python
	220, ## Wisp
]


static func random_ambushing_tile() -> int:
	## xu4 Creature::randomAmbushing — uniform pick among ambusher types.
	if _AMBUSHING_TILES.is_empty():
		return 200
	return _AMBUSHING_TILES[randi() % _AMBUSHING_TILES.size()]


static func _ensure_id_index() -> void:
	if not _id_to_tile.is_empty():
		return
	for tid in _CREATURES.keys():
		var d: Dictionary = _CREATURES[tid]
		_id_to_tile[int(d["id"])] = int(d["tile"])


static func base_tile_of(tile_id: int) -> int:
	## Collapse animation / pirate facing to the creature base tile.
	if tile_id >= 128 and tile_id <= 131:
		return PIRATE_TILE
	if _CREATURES.has(tile_id):
		return tile_id
	## 2-frame (even base) or 4-frame groups.
	for base in _CREATURES.keys():
		var b := int(base)
		if b >= 144:
			if tile_id >= b and tile_id < b + 4:
				return b
		elif b >= 132:
			if tile_id >= b and tile_id < b + 2:
				return b
	return tile_id


static func _info_for_tile(tile_id: int) -> Dictionary:
	var base := base_tile_of(tile_id)
	if _CREATURES.has(base):
		return (_CREATURES[base] as Dictionary).duplicate()
	return {"id": 0, "size": 8, "leader": 0, "tile": base}


static func _tile_for_creature_id(cid: int) -> int:
	_ensure_id_index()
	return int(_id_to_tile.get(cid, 0))


static func initial_number_of_creatures(base_tile: int, party_size: int) -> int:
	## xu4 CombatController::initialNumberOfCreatures (world / dungeon path).
	var info := _info_for_tile(base_tile)
	var ncreatures := (randi() % 8) + 1
	if ncreatures == 1:
		var group_size := int(info.get("size", 0))
		if group_size > 0:
			ncreatures = (randi() % group_size) + group_size + 1
		else:
			ncreatures = 8
	var members := maxi(1, party_size)
	while ncreatures > 2 * members:
		ncreatures = (randi() % 16) + 1
	return clampi(ncreatures, 1, AREA_CREATURES)


static func fill_creature_table(base_tile: int, party_size: int) -> Array[int]:
	## xu4 fillCreatureTable — returns AREA_CREATURES tile ids (−1 = empty slot).
	var table: Array[int] = []
	table.resize(AREA_CREATURES)
	for i in AREA_CREATURES:
		table[i] = -1

	var base := base_tile_of(base_tile)
	## Pirate ships fight as Rogues in combat.
	if base == PIRATE_TILE:
		base = ROGUE_TILE

	var info := _info_for_tile(base)
	var base_id := int(info.get("id", 0))
	var leader_id := int(info.get("leader", base_id))
	if leader_id == 0:
		leader_id = base_id
	var grand_leader_id := leader_id
	var leader_tile := _tile_for_creature_id(leader_id)
	if leader_tile > 0:
		var linfo := _info_for_tile(leader_tile)
		grand_leader_id = int(linfo.get("leader", leader_id))
		if grand_leader_id == 0:
			grand_leader_id = leader_id
	var grand_tile := _tile_for_creature_id(grand_leader_id)
	if grand_tile <= 0:
		grand_tile = leader_tile if leader_tile > 0 else base
	if leader_tile <= 0:
		leader_tile = base

	var num := initial_number_of_creatures(base, party_size)
	var base_is_leader := leader_id == base_id

	for i in num:
		var current := base
		## Must keep at least one of the encountered type (last slot never upgrades).
		if not base_is_leader and i != (num - 1):
			if (randi() % 32) == 0:
				current = grand_tile
			elif (randi() % 8) == 0:
				current = leader_tile
		## Random free slot.
		var j := randi() % AREA_CREATURES
		var guard := 0
		while table[j] >= 0 and guard < AREA_CREATURES * 2:
			j = randi() % AREA_CREATURES
			guard += 1
		if table[j] >= 0:
			## Table full — stop early.
			break
		table[j] = current
	return table


static func initial_hp_for(tile_id: int) -> Dictionary:
	## xu4 Creature::setInitialHp(-1) — hp = random(basehp)|(basehp/2), min 24.
	var basehp := _WorldCreaturesScript.base_hp_for(tile_id)
	basehp = maxi(1, basehp)
	var hp := (randi() % basehp) | (basehp / 2)
	if hp < 24:
		hp = 24
	## Cap so the bar never starts over 100%.
	hp = mini(hp, basehp)
	return {"hp": hp, "max_hp": basehp}


static func place_foes_from_table(
	table: Array[int],
	creature_starts: Array
) -> Array:
	## Build foe unit dicts for MapView.enter_combat from filled table + .CON starts.
	## Ordered by creatureTable slot (xu4 placeCreatures / moveCreatures order).
	var foes: Array = []
	var nstarts := creature_starts.size()
	for i in mini(table.size(), nstarts):
		var tid := int(table[i])
		if tid < 0:
			continue
		var start: Vector2i = creature_starts[i]
		var vitals := initial_hp_for(tid)
		foes.append({
			"x": start.x,
			"y": start.y,
			"tile": tid,
			"hp": int(vitals["hp"]),
			"max_hp": int(vitals["max_hp"]),
			"slot": i,
			"priority": i,
			"show_hp": false,
		})
	return foes
