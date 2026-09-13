extends Object

## Combat-turn planner for Ztats auto-combat modes.
## Returns a plan the world scene executes (attack / cast / move / pass).
## Preloaded from stub_world — no class_name (global cache can be stale).

const _WeaponIcons := preload("res://src/core/weapon_icons.gd")
const _Spells := preload("res://src/core/spells.gd")

const HEAL_HP_RATIO := 0.50
const MAGIC_ATTACKS: Array[int] = [
	_Spells.KILL,
	_Spells.ICEBALL,
	_Spells.FIREBALL,
	_Spells.MAGIC_MISSILE,
]


static func decide(
	mode: int,
	map,
	klass: int,
	_party_slot: int,
	loc_ctx: int
) -> Dictionary:
	if map == null or klass < 0:
		return {"action": "pass"}
	match mode:
		GameState.AutoCombat.WAIT:
			return {"action": "pass"}
		GameState.AutoCombat.ATTACK:
			return _decide_attack(map, klass)
		GameState.AutoCombat.MAGIC:
			return _decide_magic(map, klass, loc_ctx)
		GameState.AutoCombat.PROTECT:
			return _decide_protect(map, klass, loc_ctx)
		_:
			return {"action": "pass"}


static func _decide_attack(map, klass: int) -> Dictionary:
	var hit := _best_weapon_hit(map, klass)
	if not hit.is_empty():
		return hit
	return _move_or_pass(map)


static func _decide_magic(map, klass: int, loc_ctx: int) -> Dictionary:
	var shot := _best_magic_attack(map, klass, loc_ctx)
	if not shot.is_empty():
		return shot
	var hit := _best_weapon_hit(map, klass)
	if not hit.is_empty():
		return hit
	## Melee: stand and recover MP. Ranged with no clear shot: step or pass.
	if _WeaponIcons.is_melee(GameState.weapon_of_class(klass)):
		return {"action": "pass"}
	return _move_or_pass(map)


static func _decide_protect(map, klass: int, loc_ctx: int) -> Dictionary:
	var support := _best_protect_cast(klass, loc_ctx)
	if not support.is_empty():
		return support
	var wid := GameState.weapon_of_class(klass)
	if _WeaponIcons.is_melee(wid):
		return {"action": "pass"}
	var hit := _best_weapon_hit(map, klass)
	if not hit.is_empty():
		return hit
	return _move_or_pass(map)


static func _can_cast(spell_id: int, klass: int, loc_ctx: int) -> bool:
	if GameState.is_aura_negate():
		return false
	return GameState.spell_prereq_error(spell_id, klass, loc_ctx) == _Spells.CASTERR_NOERROR


static func _best_magic_attack(map, klass: int, loc_ctx: int) -> Dictionary:
	var from: Vector2i = map.get_combat_focus_pos()
	if from.x < 0:
		return {}
	var spell_id := -1
	for sid in MAGIC_ATTACKS:
		if _can_cast(sid, klass, loc_ctx):
			spell_id = sid
			break
	if spell_id < 0:
		return {}
	var foe := _best_magic_target(map, from)
	if foe.is_empty():
		return {}
	return {
		"action": "cast_aim",
		"spell": spell_id,
		"from": from,
		"target": foe.pos,
	}


static func _best_protect_cast(klass: int, loc_ctx: int) -> Dictionary:
	var poison_slot := _first_poisoned_slot()
	if poison_slot >= 0 and _can_cast(_Spells.CURE, klass, loc_ctx):
		return {"action": "cast_player", "spell": _Spells.CURE, "target_slot": poison_slot}
	var sleep_slot := _first_sleeping_slot()
	if sleep_slot >= 0 and _can_cast(_Spells.AWAKEN, klass, loc_ctx):
		return {"action": "cast_player", "spell": _Spells.AWAKEN, "target_slot": sleep_slot}
	var heal_slot := _lowest_wounded_slot()
	if heal_slot >= 0 and _can_cast(_Spells.HEAL, klass, loc_ctx):
		return {"action": "cast_player", "spell": _Spells.HEAL, "target_slot": heal_slot}
	if (
		not GameState.is_aura_protection()
		and _can_cast(_Spells.PROTECTION, klass, loc_ctx)
	):
		return {"action": "cast_none", "spell": _Spells.PROTECTION}
	return {}


static func _first_poisoned_slot() -> int:
	for slot in GameState.party_size():
		var mid := GameState.party_member_at(slot)
		if mid < 0 or GameState.is_class_dead(mid):
			continue
		if (
			GameState.status_of_class(mid) == PartyRoster.Status.POISONED
			or GameState.is_member_poisoned(mid)
		):
			return slot
	return -1


static func _first_sleeping_slot() -> int:
	for slot in GameState.party_size():
		var mid := GameState.party_member_at(slot)
		if mid < 0:
			continue
		if GameState.status_of_class(mid) == PartyRoster.Status.SLEEPING:
			return slot
	return -1


static func _lowest_wounded_slot() -> int:
	var best_slot := -1
	var best_ratio := 2.0
	for slot in GameState.party_size():
		var mid := GameState.party_member_at(slot)
		if mid < 0 or GameState.is_class_dead(mid):
			continue
		var mx := GameState.max_hp_of_class(mid)
		if mx <= 0:
			continue
		var ratio := float(GameState.hp_of_class(mid)) / float(mx)
		if ratio > HEAL_HP_RATIO:
			continue
		if ratio < best_ratio:
			best_ratio = ratio
			best_slot = slot
	return best_slot


static func _best_weapon_hit(map, klass: int) -> Dictionary:
	var from: Vector2i = map.get_combat_focus_pos()
	if from.x < 0:
		return {}
	var wid := GameState.weapon_of_class(klass)
	var best := {}
	var best_tier := 99
	var best_dist := 1_000_000
	for i in map.living_combat_foe_indices():
		var foe: Dictionary = map.get_combat_foe_at(i)
		if foe.is_empty():
			continue
		var pos := Vector2i(int(foe.get("x", from.x)), int(foe.get("y", from.y)))
		if not _can_land_weapon_hit(map, wid, from, pos):
			continue
		var tier := _weapon_hit_tier(wid)
		var dist := _WeaponIcons.chebyshev(from, pos)
		if tier < best_tier or (tier == best_tier and dist < best_dist):
			best_tier = tier
			best_dist = dist
			best = {
				"action": "attack",
				"from": from,
				"target": pos,
				"weapon": wid,
			}
	return best


static func _can_land_weapon_hit(map, wid: int, from: Vector2i, to: Vector2i) -> bool:
	## Range + a shot that actually lands on the foe — never fire into a wall.
	if not map.combat_can_strike(wid, from, to):
		return false
	if not map.combat_can_aim_tile(to):
		return false
	if _WeaponIcons.is_melee(wid):
		return true
	if not map.combat_shot_reaches(from, to, wid):
		return false
	var land: Vector2i = map.combat_projectile_end(from, to, wid)
	return land == to


static func _can_land_magic_hit(map, from: Vector2i, to: Vector2i) -> bool:
	if to == from or not map.combat_can_aim_tile(to):
		return false
	if not map.combat_shot_reaches(from, to):
		return false
	var land: Vector2i = map.combat_projectile_end(from, to)
	return land == to


static func _weapon_hit_tier(wid: int) -> int:
	## Magic-ranged first, then mundane ranged, then melee.
	if _WeaponIcons.is_unlimited_range(wid):
		return 0
	if not _WeaponIcons.is_melee(wid):
		return 1
	return 2


static func _best_magic_target(map, from: Vector2i) -> Dictionary:
	var best := {}
	var best_dist := 1_000_000
	for i in map.living_combat_foe_indices():
		var foe: Dictionary = map.get_combat_foe_at(i)
		if foe.is_empty():
			continue
		var pos := Vector2i(int(foe.get("x", from.x)), int(foe.get("y", from.y)))
		if pos == from:
			continue
		if not _can_land_magic_hit(map, from, pos):
			continue
		var dist := _WeaponIcons.chebyshev(from, pos)
		if dist < best_dist:
			best_dist = dist
			best = {"pos": pos}
	return best


static func _nearest_foe_pos(map) -> Vector2i:
	var from: Vector2i = map.get_combat_focus_pos()
	var best := Vector2i(-1, -1)
	var best_dist := 1_000_000
	for i in map.living_combat_foe_indices():
		var foe: Dictionary = map.get_combat_foe_at(i)
		if foe.is_empty():
			continue
		var pos := Vector2i(int(foe.get("x", from.x)), int(foe.get("y", from.y)))
		var dist := _WeaponIcons.chebyshev(from, pos)
		if dist < best_dist:
			best_dist = dist
			best = pos
	return best


static func _move_or_pass(map) -> Dictionary:
	var target := _nearest_foe_pos(map)
	if target.x < 0:
		return {"action": "pass"}
	var dir: Vector2i = map.combat_auto_step_dir(target)
	if dir == Vector2i.ZERO:
		return {"action": "pass"}
	return {"action": "move", "dir": dir}
