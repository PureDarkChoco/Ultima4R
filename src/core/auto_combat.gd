extends Object

## Combat-turn planner for Ztats auto-combat modes.
## Returns a plan the world scene executes (attack / cast / move / pass).
## Preloaded from stub_world — no class_name (global cache can be stale).

const _WeaponIcons := preload("res://src/core/weapon_icons.gd")
const _Spells := preload("res://src/core/spells.gd")
const _WorldCreatures := preload("res://src/map/world_creatures.gd")

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
	loc_ctx: int,
	preferred_foe_slot: int = -1
) -> Dictionary:
	if map == null or klass < 0:
		return {"action": "pass"}
	match mode:
		GameState.AutoCombat.WAIT:
			return {"action": "pass"}
		GameState.AutoCombat.ATTACK:
			return _decide_attack(map, klass, preferred_foe_slot)
		GameState.AutoCombat.MAGIC:
			return _decide_magic(map, klass, loc_ctx, preferred_foe_slot)
		GameState.AutoCombat.PROTECT:
			return _decide_protect(map, klass, loc_ctx, preferred_foe_slot)
		_:
			return {"action": "pass"}


static func _decide_attack(map, klass: int, preferred_foe_slot: int) -> Dictionary:
	var hit := _best_weapon_hit(map, klass, preferred_foe_slot)
	if not hit.is_empty():
		return hit
	return _move_or_pass(map, preferred_foe_slot)


static func _decide_magic(
	map, klass: int, loc_ctx: int, preferred_foe_slot: int
) -> Dictionary:
	var shot := _best_magic_attack(map, klass, loc_ctx, preferred_foe_slot)
	if not shot.is_empty():
		return shot
	var hit := _best_weapon_hit(map, klass, preferred_foe_slot)
	if not hit.is_empty():
		return hit
	## Melee: stand and recover MP. Ranged with no clear shot: step or pass.
	if _WeaponIcons.is_melee(GameState.weapon_of_class(klass)):
		return {"action": "pass"}
	return _move_or_pass(map, preferred_foe_slot)


static func _decide_protect(
	map, klass: int, loc_ctx: int, preferred_foe_slot: int
) -> Dictionary:
	var support := _best_protect_cast(klass, loc_ctx)
	if not support.is_empty():
		return support
	var wid := GameState.weapon_of_class(klass)
	if _WeaponIcons.is_melee(wid):
		return {"action": "pass"}
	var hit := _best_weapon_hit(map, klass, preferred_foe_slot)
	if not hit.is_empty():
		return hit
	return _move_or_pass(map, preferred_foe_slot)


static func _can_cast(spell_id: int, klass: int, loc_ctx: int) -> bool:
	if GameState.is_aura_negate():
		return false
	return GameState.spell_prereq_error(spell_id, klass, loc_ctx) == _Spells.CASTERR_NOERROR


static func _best_magic_attack(
	map, klass: int, loc_ctx: int, preferred_foe_slot: int
) -> Dictionary:
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
	var foe := _best_magic_target(map, from, preferred_foe_slot)
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


static func _best_weapon_hit(
	map, klass: int, preferred_foe_slot: int
) -> Dictionary:
	var from: Vector2i = map.get_combat_focus_pos()
	if from.x < 0:
		return {}
	var wid := GameState.weapon_of_class(klass)
	var best := {}
	var best_rank: Array[int] = []
	for i in map.living_combat_foe_indices():
		var foe: Dictionary = map.get_combat_foe_at(i)
		if foe.is_empty():
			continue
		var pos := Vector2i(int(foe.get("x", from.x)), int(foe.get("y", from.y)))
		if not _can_land_weapon_hit(map, wid, from, pos):
			continue
		var dist := _WeaponIcons.chebyshev(from, pos)
		var rank := _foe_target_rank(foe, preferred_foe_slot, dist)
		if best_rank.is_empty() or _rank_before(rank, best_rank):
			best_rank = rank
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


static func _best_magic_target(
	map, from: Vector2i, preferred_foe_slot: int
) -> Dictionary:
	var best := {}
	var best_rank: Array[int] = []
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
		var rank := _foe_target_rank(foe, preferred_foe_slot, dist)
		if best_rank.is_empty() or _rank_before(rank, best_rank):
			best_rank = rank
			best = {"pos": pos}
	return best


static func _foe_target_rank(
	foe: Dictionary, preferred_foe_slot: int, dist: int
) -> Array[int]:
	## Lower tuple wins: own sticky target; untouched foe; high threat; near; slot.
	var slot := int(foe.get("slot", foe.get("priority", 99)))
	var preferred := slot == preferred_foe_slot
	var hp := maxi(0, int(foe.get("hp", 0)))
	var max_hp := maxi(hp, int(foe.get("max_hp", hp)))
	var touched := hp < max_hp
	var attack := _WorldCreatures.base_hp_for(int(foe.get("tile", 0)))
	var threat := attack + max_hp
	return [
		0 if preferred else 1,
		0 if (preferred or not touched) else 1,
		-threat,
		dist,
		slot,
	]


static func _rank_before(a: Array[int], b: Array[int]) -> bool:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return a[i] < b[i]
	return a.size() < b.size()


static func _move_or_pass(map, preferred_foe_slot: int) -> Dictionary:
	## Try foes in combat priority order; an unreachable preferred foe must not
	## make the member pass while another living foe has an open route.
	var candidates: Array[Dictionary] = []
	var from: Vector2i = map.get_combat_focus_pos()
	for i in map.living_combat_foe_indices():
		var foe: Dictionary = map.get_combat_foe_at(i)
		if foe.is_empty():
			continue
		var pos := Vector2i(int(foe.get("x", from.x)), int(foe.get("y", from.y)))
		var rank := _foe_target_rank(
			foe, preferred_foe_slot, _WeaponIcons.chebyshev(from, pos)
		)
		var insert_at := candidates.size()
		for j in candidates.size():
			if _rank_before(rank, candidates[j].rank as Array[int]):
				insert_at = j
				break
		candidates.insert(insert_at, {"pos": pos, "rank": rank})
	for candidate in candidates:
		var dir: Vector2i = map.combat_auto_step_dir(candidate.pos as Vector2i)
		if dir != Vector2i.ZERO:
			return {"action": "move", "dir": dir}
	return {"action": "pass"}
