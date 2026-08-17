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
## xu4 creatureRangeAttack path for lava lizard / sea serpent / hydra / dragon.
const WORLD_RANGED_RANGE := 3

const TILE_PIRATE := 128
const TILE_NIXIE := 132
const TILE_SEA_SERPENT := 136
const TILE_WHIRLPOOL := 140
const TILE_TWISTER := 142
const TILE_ORC := 192
const TILE_LAVA_LIZARD := 232
const TILE_HYDRA := 244
const TILE_DRAGON := 248

## xu4 Creature::specialAction — world-map ranged (not combat free-aim).
const _WORLD_RANGED_SPECIAL := {
	TILE_SEA_SERPENT: true,
	TILE_LAVA_LIZARD: true,
	TILE_HYDRA: true,
	TILE_DRAGON: true,
}

const MOVE_FIXED := 0
const MOVE_WANDER := 1
const MOVE_ATTACK := 2

const _DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)
]

## (base_tile, frame_count) — consecutive tile ids are animation / pirate facing.
const _CREATURE_BASES: Array[Vector2i] = [
	## Townsfolk / class portraits (city combat).
	Vector2i(32, 2), ## mage
	Vector2i(34, 2), ## bard
	Vector2i(36, 2), ## fighter
	Vector2i(38, 2), ## druid
	Vector2i(40, 2), ## tinker
	Vector2i(42, 2), ## paladin
	Vector2i(44, 2), ## ranger
	Vector2i(46, 2), ## shepherd
	Vector2i(80, 2), ## guard
	Vector2i(82, 2), ## villager / merchant
	Vector2i(84, 2), ## bard_singing
	Vector2i(86, 2), ## jester
	Vector2i(88, 2), ## beggar
	Vector2i(90, 2), ## child
	Vector2i(92, 2), ## bull
	Vector2i(94, 2), ## lord british
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

const TILE_GUARD := 80
const TILE_LORD_BRITISH := 94
const TILE_ETTIN := 208

## Labels for combat engage messages (xu4 creature names, short form).
const _DISPLAY_NAMES := {
	32: "Mage",
	34: "Bard",
	36: "Fighter",
	38: "Druid",
	40: "Tinker",
	42: "Paladin",
	44: "Ranger",
	46: "Shepherd",
	80: "Guard",
	82: "Merchant",
	84: "Bard",
	86: "Jester",
	88: "Beggar",
	90: "Child",
	92: "Bull",
	94: "Lord British",
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
	## Townsfolk / class (xu4 ids 2–17).
	32: 112, ## Mage
	34: 48, ## Bard
	36: 96, ## Fighter
	38: 64, ## Druid
	40: 96, ## Tinker
	42: 128, ## Paladin
	44: 144, ## Ranger
	46: 48, ## Shepherd
	80: 128, ## Guard
	82: 48, ## Merchant
	84: 48, ## Bard (singing)
	86: 48, ## Jester
	88: 32, ## Beggar
	90: 32, ## Child
	92: 128, ## Bull
	94: 255, ## Lord British
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
	## Ettin: skip base tile 208 (reads as a single head); cycle 209–211 only.
	if base == TILE_ETTIN and frames >= 2:
		return base + 1 + posmod(anim_tick, frames - 1)
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


func destroy_all_except_lord_british() -> int:
	## xu4 gameDestroyAllCreatures (world) — keep Lord British if present.
	var kept: Array[Dictionary] = []
	var removed := 0
	for c in creatures:
		if is_lord_british(int(c.get("tile", 0))):
			kept.append(c)
		else:
			removed += 1
	creatures = kept
	return removed


static func display_name(tile_or_base: int) -> String:
	## Short English label for messages (Attacked by …).
	var base := _base_tile(tile_or_base)
	return str(_DISPLAY_NAMES.get(base, "Creature"))


## xu4 config.b `good: true` (townsfolk + some wilderness; else evil for karma).
const _GOOD_TILES := {
	32: true, 34: true, 36: true, 38: true, 40: true, 42: true, 44: true, 46: true,
	80: true, 82: true, 84: true, 86: true, 88: true, 90: true, 92: true, 94: true,
	138: true, ## Seahorse
	144: true, ## Rat
	148: true, ## Bat
	152: true, ## Spider
	180: true, ## Insect Swarm
	204: true, ## Python
}


static func is_good(tile_or_base: int) -> bool:
	## xu4 Creature::isGood — config `good` flag.
	return bool(_GOOD_TILES.get(_base_tile(tile_or_base), false))


static func is_guard(tile_or_base: int) -> bool:
	## xu4 GUARD_ID (tile guard) — city combat group size uses members×2.
	return _base_tile(tile_or_base) == TILE_GUARD


static func is_lord_british(tile_or_base: int) -> bool:
	## xu4 LORDBRITISH_ID — alertGuards also sets LB to attack.
	return _base_tile(tile_or_base) == TILE_LORD_BRITISH


static func is_townsfolk(tile_or_base: int) -> bool:
	## City person tiles: class sprites or civic NPCs.
	var base := _base_tile(tile_or_base)
	return (base >= 32 and base <= 46) or (base >= 80 and base <= 94)


static func is_evil(tile_or_base: int) -> bool:
	## xu4 Creature::isEvil — not good (engaged wilderness foes).
	return not is_good(tile_or_base)


static func is_pirate_ship(tile_or_base: int) -> bool:
	## Wilderness pirate frigate (base 128 / facing 128–131).
	return _base_tile(tile_or_base) == TILE_PIRATE


## xu4 config.b `nochest: true` — Bat, Slime, Insect Swarm, Wisp.
const _NOCHEST_TILES := {
	148: true, ## Bat
	160: true, ## Slime
	180: true, ## Insect Swarm
	220: true, ## Wisp
}


static func leaves_chest(tile_or_base: int) -> bool:
	## xu4 Creature::leavesChest — not aquatic (swims/sails) and not nochest.
	var base := _base_tile(tile_or_base)
	if _sails(base) or _swims(base):
		return false
	if bool(_NOCHEST_TILES.get(base, false)):
		return false
	return true


## Roughly biped / humanoid combatants — extra food / gear drops.
const _HUMANOID_TILES := {
	156: true, ## Ghost
	164: true, ## Troll
	168: true, ## Gremlin
	188: true, ## Phantom
	192: true, ## Orc
	196: true, ## Skeleton
	200: true, ## Rogue
	208: true, ## Ettin
	212: true, ## Headless
	216: true, ## Cyclops
	224: true, ## Evil Mage
	228: true, ## Liche
	236: true, ## Zorn
	240: true, ## Daemon
	252: true, ## Balron
}


static func is_humanoid(tile_or_base: int) -> bool:
	return bool(_HUMANOID_TILES.get(_base_tile(tile_or_base), false))


const TILE_SPIDER := 152


static func is_spider(tile_or_base: int) -> bool:
	return _base_tile(tile_or_base) == TILE_SPIDER


## Combat key loot 1% — Rogue only (pirates still leave no chest).
const TILE_ROGUE := 200


static func is_rogue(tile_or_base: int) -> bool:
	return _base_tile(tile_or_base) == TILE_ROGUE


static func drops_chest_keys(tile_or_base: int) -> bool:
	return is_rogue(tile_or_base)


## Spellcasting humanoids (reagent bonus bags) — Evil Mage, Liche.
const _MAGE_TILES := {
	224: true, ## Evil Mage
	228: true, ## Liche
}


static func is_mage(tile_or_base: int) -> bool:
	return bool(_MAGE_TILES.get(_base_tile(tile_or_base), false))


## xu4 config.b `ranged: true` wilderness / town creatures (combat free-aim).
const _RANGED_TILES := {
	32: true, ## Town Mage
	94: true, ## Lord British
	132: true, ## Nixie
	134: true, ## Giant Squid
	136: true, ## Sea Serpent
	138: true, ## Seahorse
	152: true, ## Spider
	164: true, ## Troll
	172: true, ## Mimic
	176: true, ## Reaper
	184: true, ## Gazer
	204: true, ## Python
	208: true, ## Ettin
	216: true, ## Cyclops
	224: true, ## Evil Mage
	228: true, ## Liche
	232: true, ## Lava Lizard
	240: true, ## Daemon
	244: true, ## Hydra
	248: true, ## Dragon
	252: true, ## Balron
}

## Projectile / flash tiles (shapes ids — same as MapView constants).
const TILE_ROCKS := 55
const TILE_FIELD_POISON := 68
const TILE_FIELD_ENERGY := 69
const TILE_FIELD_FIRE := 70
const TILE_FIELD_SLEEP := 71
const TILE_LAVA := 76
const TILE_MISS_FLASH := 77 ## red missile (default miss)
const TILE_MAGIC_FLASH := 78 ## intro magic sphere / mage bolts
const TILE_HIT_FLASH := 79

## xu4 rangedmisstile (default miss_flash when omitted).
const _RANGED_MISS_TILE := {
	32: TILE_MAGIC_FLASH,
	94: TILE_MAGIC_FLASH,
	134: TILE_FIELD_ENERGY, ## Squid
	136: TILE_HIT_FLASH, ## Sea Serpent
	138: TILE_MAGIC_FLASH, ## Seahorse
	152: TILE_FIELD_POISON, ## Spider
	172: TILE_FIELD_POISON, ## Mimic
	184: TILE_FIELD_SLEEP, ## Gazer
	204: TILE_FIELD_POISON, ## Python
	208: TILE_ROCKS, ## Ettin
	216: TILE_ROCKS, ## Cyclops
	224: TILE_MAGIC_FLASH, ## Evil Mage
	228: TILE_MAGIC_FLASH, ## Liche
	232: TILE_LAVA, ## Lava Lizard
	240: TILE_MAGIC_FLASH, ## Daemon
	244: TILE_HIT_FLASH, ## Hydra
	248: TILE_HIT_FLASH, ## Dragon
}

## xu4 rangedhittile (default hit_flash when omitted).
const _RANGED_HIT_TILE := {
	32: TILE_MAGIC_FLASH,
	94: TILE_MAGIC_FLASH,
	134: TILE_FIELD_ENERGY,
	136: TILE_HIT_FLASH,
	138: TILE_MAGIC_FLASH,
	152: TILE_FIELD_POISON,
	172: TILE_FIELD_POISON,
	184: TILE_FIELD_SLEEP,
	204: TILE_FIELD_POISON,
	208: TILE_ROCKS,
	216: TILE_ROCKS,
	224: TILE_MAGIC_FLASH,
	228: TILE_MAGIC_FLASH,
	232: TILE_LAVA,
	240: TILE_MAGIC_FLASH,
	244: TILE_HIT_FLASH,
	248: TILE_HIT_FLASH,
}

## xu4 hasRandomRanged — re-roll miss/hit to a random field each shot.
const _RANDOM_RANGED := {
	176: true, ## Reaper
	252: true, ## Balron
}

## xu4 leavestile — leave hittile on the last path cell when the shot misses everyone.
const _LEAVES_TILE_ON_MISS := {
	232: true, ## Lava Lizard → lava
}

## Ranged hit status: damage | poison | sleep | energy.
## Field/random use hit-tile effects; override only for status-only bullets.
const _RANGED_EFFECT := {
	134: "energy", ## Squid — energy field damage
	152: "poison", ## Spider
	172: "poison", ## Mimic
	184: "sleep", ## Gazer
	204: "poison", ## Python
}

const _STEALS_GOLD := {200: true} ## Rogue
const _STEALS_FOOD := {168: true} ## Gremlin
const _CASTS_SLEEP := {176: true, 252: true} ## Reaper, Balron
const _TELEPORTS := {220: true} ## Wisp
const _NEGATES := {236: true} ## Zorn
## xu4 Creature::act — Zorn refreshes Negate for this many turns, then still acts.
const ZORN_NEGATE_TURNS := 2

## xu4 Creature::getState — flee when current HP drops below this.
const FLEE_HP := 24
## Combat free-aim range (covers 11×11 .CON; player-style aim_distance).
const COMBAT_RANGED_RANGE := 11
## xu4 Creature::getDefense — all monsters use a flat 128 (~50% melee connect).
const CREATURE_DEFENSE := 128


static func is_ranged(tile_or_base: int) -> bool:
	return bool(_RANGED_TILES.get(_base_tile(tile_or_base), false))


static func has_random_ranged(tile_or_base: int) -> bool:
	return bool(_RANDOM_RANGED.get(_base_tile(tile_or_base), false))


static func leaves_tile_on_miss(tile_or_base: int) -> bool:
	return bool(_LEAVES_TILE_ON_MISS.get(_base_tile(tile_or_base), false))


static func resolve_ranged_shot(tile_or_base: int) -> Dictionary:
	## xu4 CA_RANGED + setRandomRanged — one miss/hit pair for this shot.
	## miss_tid: flying projectile · hit_tid: impact flash · effect · leave_tid on full miss.
	var base := _base_tile(tile_or_base)
	var miss_tid := TILE_MISS_FLASH
	var hit_tid := TILE_HIT_FLASH
	if has_random_ranged(base):
		## Fields 0..3 — poison, energy, fire, sleep.
		var field := TILE_FIELD_POISON + (randi() % 4)
		miss_tid = field
		hit_tid = field
	else:
		miss_tid = int(_RANGED_MISS_TILE.get(base, TILE_MISS_FLASH))
		hit_tid = int(_RANGED_HIT_TILE.get(base, TILE_HIT_FLASH))
	var effect := str(_RANGED_EFFECT.get(base, ""))
	if effect.is_empty():
		effect = _effect_for_hit_tile(hit_tid)
	var leave_tid := -1
	if leaves_tile_on_miss(base):
		leave_tid = hit_tid
	return {
		"miss_tid": miss_tid,
		"hit_tid": hit_tid,
		"effect": effect,
		"leave_tid": leave_tid,
	}


static func _effect_for_hit_tile(hit_tid: int) -> String:
	match hit_tid:
		TILE_FIELD_POISON:
			return "poison"
		TILE_FIELD_SLEEP:
			return "sleep"
		TILE_FIELD_ENERGY:
			return "energy"
		TILE_FIELD_FIRE, TILE_LAVA:
			return "damage"
		_:
			return "damage"


static func ranged_effect(tile_or_base: int) -> String:
	## damage (default), poison, sleep, energy. Prefer resolve_ranged_shot for random.
	var base := _base_tile(tile_or_base)
	if has_random_ranged(base):
		return "damage"
	if bool(_RANGED_EFFECT.has(base)):
		return str(_RANGED_EFFECT[base])
	var hit_tid := int(_RANGED_HIT_TILE.get(base, TILE_HIT_FLASH))
	return _effect_for_hit_tile(hit_tid)


static func ranged_miss_tile(tile_or_base: int) -> int:
	return int(resolve_ranged_shot(tile_or_base).get("miss_tid", TILE_MISS_FLASH))


static func steals_gold(tile_or_base: int) -> bool:
	return bool(_STEALS_GOLD.get(_base_tile(tile_or_base), false))


static func steals_food(tile_or_base: int) -> bool:
	return bool(_STEALS_FOOD.get(_base_tile(tile_or_base), false))


static func casts_sleep(tile_or_base: int) -> bool:
	return bool(_CASTS_SLEEP.get(_base_tile(tile_or_base), false))


static func teleports(tile_or_base: int) -> bool:
	## xu4 `teleports: true` — Wisp, 1/8 of combat turns.
	return bool(_TELEPORTS.get(_base_tile(tile_or_base), false))


static func negates(tile_or_base: int) -> bool:
	## xu4 `casts: negate` — Zorn.
	return bool(_NEGATES.get(_base_tile(tile_or_base), false))


static func is_stationary(tile_or_base: int) -> bool:
	## xu4 `movement: none` — Mimic / Reaper. World and combat both stay put.
	return _default_movement(_base_tile(tile_or_base)) == MOVE_FIXED


static func is_undead(tile_or_base: int) -> bool:
	## DOS C_636D / xu4 MATTR_UNDEAD — ghost, phantom, skeleton, liche.
	var base := _base_tile(tile_or_base)
	return base == 156 or base == 188 or base == 196 or base == 228


static func resists_sleep(tile_or_base: int) -> bool:
	## DOS C_636D undead + TIL_FC Balron. xu4 getResists() == EFFECT_SLEEP.
	var base := _base_tile(tile_or_base)
	return (
		base == 156 ## Ghost
		or base == 188 ## Phantom
		or base == 196 ## Skeleton
		or base == 228 ## Liche
		or base == 252 ## Balron
	)


static func resists_fire(tile_or_base: int) -> bool:
	## xu4 `resists: fire` — lava lizard, daemon, hydra, dragon, balron.
	var base := _base_tile(tile_or_base)
	return (
		base == 232
		or base == 240
		or base == 244
		or base == 248
		or base == 252
	)


static func is_fleeing_hp(hp: int) -> bool:
	## xu4 MSTAT_FLEEING — all creatures (not humanoid-only).
	return hp > 0 and hp < FLEE_HP


static func is_swimmer(tile_or_base: int) -> bool:
	return _swims(_base_tile(tile_or_base))


static func is_sailor(tile_or_base: int) -> bool:
	return _sails(_base_tile(tile_or_base))


static func is_flyer(tile_or_base: int) -> bool:
	return _flies(_base_tile(tile_or_base))


static func is_incorporeal(tile_or_base: int) -> bool:
	return _incorporeal(_base_tile(tile_or_base))


static func creature_attack_damage(base_hp: int) -> int:
	## xu4 Creature::getDamage — random(basehp/4) → tens*10 + ones.
	var bh := maxi(1, base_hp)
	var x := randi() % maxi(1, bh >> 2)
	return (x >> 4) * 10 + (x % 10)


static func creature_attack_hits(defense: int) -> bool:
	## xu4 attackHit — creature attackBonus 0 vs party armor / creature defense.
	return (randi() % 0x100) > defense


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
	on_pirate_fire: Callable = Callable(),
	on_world_ranged: Callable = Callable(),
	on_nature: Callable = Callable()
) -> Dictionary:
	## xu4 Map::moveObjects — specialEffect, specialAction, then move + specialEffect.
	## Returns { "changed": bool, "attacker": Dictionary } — attacker still on map.
	var out := {"changed": false, "attacker": {}}
	if world == null or not world.loaded:
		return out
	var changed := false
	var attacker: Dictionary = {}
	var i := 0
	while i < creatures.size():
		var c: Dictionary = creatures[i]
		var pos := Vector2i(int(c["x"]), int(c["y"]))
		## xu4: orthogonally adjacent attackers become combatant — skip action+move.
		if (
			int(c.get("movement", MOVE_ATTACK)) == MOVE_ATTACK
			and _ortho_adjacent(pos, avatar)
		):
			if attacker.is_empty():
				attacker = c.duplicate(true)
			i += 1
			continue
		## xu4: storms eat objects / hit the party before the creature steps.
		var before_n := creatures.size()
		i = _apply_twister_effect(i, avatar, on_nature)
		if creatures.size() != before_n:
			changed = true
		if i < 0 or i >= creatures.size():
			break
		## Pirate cannon consumes turn (useAction true). World ranged does not.
		if _try_pirate_cannon(i, avatar, on_pirate_fire):
			changed = true
			i += 1
			continue
		if _try_world_ranged(i, avatar, on_world_ranged):
			changed = true
		if _move_one(i, world, avatar, blocked):
			changed = true
			before_n = creatures.size()
			i = _apply_twister_effect(i, avatar, on_nature)
			if creatures.size() != before_n:
				changed = true
		i += 1
	out["changed"] = changed
	out["attacker"] = attacker
	return out


func _try_pirate_cannon(index: int, avatar: Vector2i, on_fire: Callable) -> bool:
	## xu4 Creature::specialAction PIRATE_ID — broadsides only, range 1..3.
	if index < 0 or index >= creatures.size():
		return false
	var c: Dictionary = creatures[index]
	if _base_tile(int(c.get("tile", 0))) != TILE_PIRATE:
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


func _try_world_ranged(index: int, avatar: Vector2i, on_fire: Callable) -> bool:
	## xu4 specialAction lava lizard / sea serpent / hydra / dragon.
	## 50% when Chebyshev dist ≤ 3; fires then still moves (useAction false).
	if index < 0 or index >= creatures.size():
		return false
	var c: Dictionary = creatures[index]
	var base := _base_tile(int(c.get("tile", 0)))
	if not bool(_WORLD_RANGED_SPECIAL.get(base, false)):
		return false
	var pos := Vector2i(int(c["x"]), int(c["y"]))
	if map_distance(pos, avatar) > WORLD_RANGED_RANGE:
		return false
	if (randi() % 2) != 0:
		return false
	var delta := wrap_delta(pos, avatar)
	var shot := Vector2i(
		0 if delta.x == 0 else (1 if delta.x > 0 else -1),
		0 if delta.y == 0 else (1 if delta.y > 0 else -1)
	)
	if shot == Vector2i.ZERO:
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


func try_humility_daemon_ambush(dir: Vector2i, avatar: Vector2i) -> int:
	## xu4 gameCheck mixed trigger: walking south near Shrine of Humility.
	## Spawns 8 daemons unless Silver Horn aura is active.
	if dir != Vector2i(0, 1):
		return 0
	if avatar.x < 229 or avatar.x >= 234:
		return 0
	if avatar.y < 212 or avatar.y >= 217:
		return 0
	if GameState.is_aura_horn():
		return 0
	var y := avatar.y + 1
	var n := 0
	for _i in 8:
		creatures.append(_make_creature(231, y, 240, 0))
		n += 1
	return n


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


## xu4 modular TileId order (one species per step). In SHAPES/0–255 each
## species occupies N animation frames, so offsets must step by species —
## not raw tile+rn (that stacks 4 pirate facings as 4 separate rolls).
const _SEA_FROM_PIRATE: Array[int] = [
	128, 132, 134, 136, 138, 140, 142,
] ## pirate … twister (sailable, rn 0..6)
const _SEA_FROM_NIXIE: Array[int] = [
	132, 134, 136, 138, 140,
] ## nixie … whirlpool (swimable shallows, rn 0..4)


static func random_for_tile(tile_id: int, moves: int) -> int:
	## xu4 Creature::randomForTile — returns base tile id, or -1.
	## Deep/medium water is sailable (checked first) → 7-way sea table.
	## Shallows are swim-only → 5-way (no pirate ships).
	if _TileRules.is_sailable(tile_id):
		return _SEA_FROM_PIRATE[randi() % _SEA_FROM_PIRATE.size()]
	if _TileRules.is_swimable(tile_id):
		return _SEA_FROM_NIXIE[randi() % _SEA_FROM_NIXIE.size()]
	if _TileRules.is_creature_walkable(tile_id):
		var era := 0x0f
		if moves < 10000:
			era = 0x03 ## Easy: orc – python
		elif moves < 30000:
			era = 0x07 ## Medium: orc – wisp
		## Hard: orc – balron. Double roll AND biases low rn (weaker).
		var rn: int = era & (randi() % 0x10) & (randi() % 0x10)
		## Species index → first frame of that monster (4 tiles each on land).
		return _base_tile(TILE_ORC + rn * 4)
	return -1


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
	var species := _base_tile(base)
	if next == avatar and not _can_move_onto_avatar(species):
		return false
	if blocked.is_valid() and bool(blocked.call(next)):
		if not _can_move_onto_creatures(species):
			return false
	if creature_at(next) >= 0 and not _can_move_onto_creatures(species):
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


func _apply_twister_effect(keep_i: int, avatar: Vector2i, on_nature: Callable) -> int:
	## xu4 Creature::specialEffect STORM_ID. Returns the (possibly shifted) index.
	if keep_i < 0 or keep_i >= creatures.size():
		return keep_i
	var c: Dictionary = creatures[keep_i]
	if _base_tile(int(c.get("tile", 0))) != TILE_TWISTER:
		return keep_i
	var pos := Vector2i(int(c["x"]), int(c["y"]))
	## On the party: damage only (xu4 returns before the object sweep).
	if pos == avatar:
		if on_nature.is_valid():
			on_nature.call({"pos": pos, "on_party": true, "ate": false})
		return keep_i
	var ate := false
	var j := creatures.size() - 1
	while j >= 0:
		if j != keep_i:
			var other: Dictionary = creatures[j]
			if int(other["x"]) == pos.x and int(other["y"]) == pos.y:
				creatures.remove_at(j)
				ate = true
				if j < keep_i:
					keep_i -= 1
		j -= 1
	if on_nature.is_valid():
		on_nature.call({"pos": pos, "on_party": false, "ate": ate})
	return keep_i


static func _can_move_onto_avatar(base: int) -> bool:
	var species := _base_tile(base)
	return species == TILE_WHIRLPOOL or species == TILE_TWISTER


static func _can_move_onto_creatures(base: int) -> bool:
	var species := _base_tile(base)
	return species == TILE_WHIRLPOOL or species == TILE_TWISTER


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
