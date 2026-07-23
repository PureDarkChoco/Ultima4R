extends Node

## Global run state for Ultima4R (autoload: GameState).

signal language_changed(lang: String)

enum Language { EN_U4, EN_US, KO }

const LANG_IDS := ["en_us", "en_u4", "ko"]

## External Ultima IV DOS data (never committed).
const U4_DATA_RES := "res://data/u4"
const U4_DATA_ABS := "/Applications/Ultima IV™.app/Contents/Resources/game"

var u4_data_path: String = U4_DATA_RES

var language: String = "en_us":
	set(value):
		if language == value:
			return
		language = value
		language_changed.emit(language)

var player_name: String = ""
var player_sex: String = "male" # "male" | "female"
var player_class: int = -1
## Party formation order (class indices 0..7). Index 0 = #1 on map & roster top.
var party_order: Array[int] = []
var start_pos: Vector2i = Vector2i.ZERO
var karma: Array[int] = []
## Inventory stubs until savegame is wired.
var gems: int = 99
## Sextant required for Locate (L / Ctrl+L). Stub-owned for now.
var has_sextant: bool = true
## xu4 SaveGame.shiphull — 0..50; shown while aboard a frigate.
var ship_hull: int = 50
const SHIP_HULL_MAX := 50
## xu4 SaveGame.food — centi-units (HUD shows food / 100). Cap 9999 displayed.
var food: int = 1000 ## display 10 (xu4 centi-units)
const FOOD_MAX := 999900
var moves: int = 0

## xu4 world clock (GameController::timerFired / updateMoons).
## Real-time 4 Hz ticks — not tied to party moves.
const MOON_PHASES := 24
const MOON_SECONDS_PER_PHASE := 4
const GAME_CYCLES_PER_SECOND := 4
## Ticks per Felucca phase / wind check (= 16 ≈ 4 seconds).
const PHASE_TICKS := MOON_SECONDS_PER_PHASE * GAME_CYCLES_PER_SECOND
const WORLD_TICK_SEC := 1.0 / float(GAME_CYCLES_PER_SECOND)
## StatusInfoBar wind indices: 0 N … 7 NW (8-way; xu4 was cardinals only).
const WIND_DIRS := [0, 1, 2, 3, 4, 5, 6, 7]

var moon_phase: int = 0 ## runtime sub-tick 0..383 (not saved in classic)
var trammel_phase: int = 0 ## 0..7
var felucca_phase: int = 0 ## 0..7
var wind_dir: int = 0 ## N — xu4 starts DIR_NORTH
var wind_counter: int = 0
var wind_lock: bool = false
## Party inventory counts (xu4 SaveGame arrays).
var weapons: Array[int] = [] ## 16 — WEAP_HANDS..MYSTIC_SWORD
var armor: Array[int] = [] ## 8 — ARMR_NONE..MYSTIC_ROBE
var reagents: Array[int] = [] ## 8
var mixtures: Array[int] = [] ## 26 — spells A..Z
## Equipped gear by class id 0..7 (xu4 SaveGamePlayerRecord weapon/armor).
var member_weapons: Array[int] = []
var member_armor: Array[int] = []
## Class-indexed vitals (xu4 SaveGamePlayerRecord hp / status).
var member_hp: Array[int] = []
var member_max_hp: Array[int] = []
var member_status: Array[int] = [] ## PartyRoster.Status
## xu4 starving / poison: 2 HP each turn while afflicted.
const STARVE_DAMAGE := 2
const POISON_DAMAGE := 2
var is_new_game: bool = false
var u4_data_ok: bool = false
var intro_data := TitleExeData.new()
var intro_overlay := IntroTextOverlay.new()

## Match PartyRoster.STUB_WEAPON / STUB_ARMOR class defaults.
const DEFAULT_WEAPON := [1, 3, 5, 2, 4, 12, 7, 10]
const DEFAULT_ARMOR := [1, 2, 3, 5, 2, 4, 6, 7]

enum EquipError {
	SUCCEEDED = 0,
	NONE_LEFT = 1,
	CLASS_RESTRICTED = 2,
}


func _ready() -> void:
	reset_party()
	intro_overlay.load_overlays()
	u4_data_ok = _probe_u4_data()
	if u4_data_ok:
		var title_path := u4_data_path.path_join("TITLE.EXE")
		if not intro_data.load_from_path(title_path):
			push_warning("GameState: TITLE.EXE intro strings not loaded from %s" % title_path)


func reset_party() -> void:
	player_name = ""
	player_sex = "male"
	player_class = -1
	party_order.clear()
	start_pos = Vector2i.ZERO
	karma.clear()
	karma.resize(8)
	for i in 8:
		karma[i] = 50
	is_new_game = false
	moon_phase = 0
	trammel_phase = 0
	felucca_phase = 0
	wind_dir = 0
	wind_counter = 0
	wind_lock = false
	food = 1000
	moves = 0
	_reset_inventory_stubs()
	refresh_party_order()


func _reset_inventory_stubs() -> void:
	## Partial demo stock (translation review done — not every item mixed).
	weapons.clear()
	weapons.resize(16)
	for i in 16:
		weapons[i] = 0
	weapons[2] = 3 ## Dagger (C)
	weapons[4] = 1 ## Mace (E)
	weapons[6] = 2 ## Sword (G)
	weapons[7] = 1 ## Bow (H)
	weapons[10] = 1 ## Halberd (K)
	weapons[12] = 1 ## Magic Sword (M)
	weapons[14] = 1 ## Magic Wand (O)

	armor.clear()
	armor.resize(8)
	for i in 8:
		armor[i] = 0
	armor[1] = 2 ## Cloth (B)
	armor[3] = 1 ## Chain (D)
	armor[5] = 1 ## Magic Chain (F)
	armor[7] = 1 ## Mystic Robe (H)

	## Always show all eight reagents; some may be zero.
	reagents.clear()
	reagents.resize(8)
	reagents[0] = 12
	reagents[1] = 0
	reagents[2] = 8
	reagents[3] = 6
	reagents[4] = 0
	reagents[5] = 4
	reagents[6] = 2
	reagents[7] = 0

	mixtures.clear()
	mixtures.resize(26)
	for i in 26:
		mixtures[i] = 0
	mixtures[0] = 4 ## Awaken
	mixtures[2] = 3 ## Cure
	mixtures[5] = 12 ## Fireball
	mixtures[7] = 5 ## Heal
	mixtures[11] = 2 ## Light
	mixtures[12] = 6 ## Magic Missile
	mixtures[15] = 2 ## Protection
	mixtures[18] = 1 ## Sleep
	mixtures[23] = 2 ## X-it
	mixtures[25] = 3 ## Z-down
	_reset_member_gear()
	_reset_member_vitals()


func _reset_member_vitals() -> void:
	## Seed from PartyRoster stub tables until savegame load is wired.
	member_hp.clear()
	member_max_hp.clear()
	member_status.clear()
	for i in 8:
		var st: int = PartyRoster.STUB_STATUS[i]
		var hp: int = PartyRoster.STUB_HP[i]
		if st == PartyRoster.Status.DEAD:
			hp = 0
		member_status.append(st)
		member_hp.append(hp)
		member_max_hp.append(PartyRoster.STUB_MAX_HP[i])


func _reset_member_gear() -> void:
	## Equip stub defaults and pull those items out of party stock (xu4 style).
	member_weapons.clear()
	member_weapons.resize(8)
	member_armor.clear()
	member_armor.resize(8)
	for c in 8:
		var w: int = DEFAULT_WEAPON[c]
		var a: int = DEFAULT_ARMOR[c]
		member_weapons[c] = w
		member_armor[c] = a
		if w > 0 and w < weapons.size() and weapons[w] > 0:
			weapons[w] -= 1
		if a > 0 and a < armor.size() and armor[a] > 0:
			armor[a] -= 1


func weapon_of_class(klass: int) -> int:
	if klass < 0 or klass >= member_weapons.size():
		return 0
	return int(member_weapons[klass])


func weapon_of_slot(slot: int) -> int:
	return weapon_of_class(party_member_at(slot))


func armor_of_class(klass: int) -> int:
	if klass < 0 or klass >= member_armor.size():
		return 0
	return int(member_armor[klass])


func armor_of_slot(slot: int) -> int:
	return armor_of_class(party_member_at(slot))


func ready_weapon(slot: int, weapon_id: int) -> int:
	## xu4 PartyMember::setWeapon — swap inventory ↔ equipped.
	var klass := party_member_at(slot)
	if klass < 0:
		return EquipError.NONE_LEFT
	if weapon_id < 0 or weapon_id >= weapons.size():
		return EquipError.NONE_LEFT
	var old := weapon_of_class(klass)
	if old == weapon_id:
		return EquipError.SUCCEEDED
	if weapon_id != 0 and weapons[weapon_id] < 1:
		return EquipError.NONE_LEFT
	if not WeaponIcons.can_ready(weapon_id, klass):
		return EquipError.CLASS_RESTRICTED
	if old != 0 and old < weapons.size():
		weapons[old] += 1
	if weapon_id != 0:
		weapons[weapon_id] -= 1
	member_weapons[klass] = weapon_id
	return EquipError.SUCCEEDED


func wear_armor(slot: int, armor_id: int) -> int:
	## xu4 PartyMember::setArmor — swap inventory ↔ equipped.
	var klass := party_member_at(slot)
	if klass < 0:
		return EquipError.NONE_LEFT
	if armor_id < 0 or armor_id >= armor.size():
		return EquipError.NONE_LEFT
	var old := armor_of_class(klass)
	if old == armor_id:
		return EquipError.SUCCEEDED
	if armor_id != 0 and armor[armor_id] < 1:
		return EquipError.NONE_LEFT
	if not ArmorIcons.can_wear(armor_id, klass):
		return EquipError.CLASS_RESTRICTED
	if old != 0 and old < armor.size():
		armor[old] += 1
	if armor_id != 0:
		armor[armor_id] -= 1
	member_armor[klass] = armor_id
	return EquipError.SUCCEEDED


func apply_virtue_result(klass: int, selected_virtues: Array[int]) -> void:
	player_class = klass
	start_pos = Virtues.CLASS_START[klass]
	for i in 8:
		karma[i] = 50
	for v in selected_virtues:
		karma[v] = mini(100, karma[v] + 5)
	is_new_game = true
	refresh_party_order()


func party_leader_class() -> int:
	## Class of party #1 — the sprite walked on the world map.
	if party_order.is_empty():
		refresh_party_order()
	return party_order[0]


func party_size() -> int:
	if party_order.is_empty():
		refresh_party_order()
	return party_order.size()


func party_member_at(slot: int) -> int:
	## Class id standing in roster row `slot` (0 = party #1). -1 if empty.
	if party_order.is_empty():
		refresh_party_order()
	if slot < 0 or slot >= party_order.size():
		return -1
	return party_order[slot]


func add_party_member(klass: int) -> bool:
	## Recruit a companion (class 0..7). No-op if already in the party.
	if klass < 0 or klass > 7:
		return false
	if party_order.is_empty():
		refresh_party_order()
	if party_order.has(klass):
		return false
	if party_order.size() >= 8:
		return false
	party_order.append(klass)
	return true


func swap_party_members(a: int, b: int) -> bool:
	## xu4 Party::swapPlayers — exchange two roster slots (0-based).
	if party_order.is_empty():
		refresh_party_order()
	var n := party_order.size()
	if a < 0 or b < 0 or a >= n or b >= n or a == b:
		return false
	var tmp: int = party_order[a]
	party_order[a] = party_order[b]
	party_order[b] = tmp
	return true


func party_member_display_name(slot: int) -> String:
	## Roster / New Order name for the member in `slot` (0 = party #1).
	var mid := party_member_at(slot)
	if mid < 0:
		return ""
	var player_cls := player_class
	if player_cls < 0:
		player_cls = party_leader_class()
	if mid == player_cls:
		return player_name if not player_name.is_empty() else "Avatar"
	if mid >= 0 and mid < PartyRoster.COMPANION_NAMES.size():
		return PartyRoster.COMPANION_NAMES[mid]
	return Virtues.class_name_of(mid, lang_short())


func refresh_party_order() -> void:
	## Player leads; remaining classes follow in virtue index order.
	party_order.clear()
	var lead := player_class if player_class >= 0 else 0
	party_order.append(lead)
	for i in 8:
		if i != lead:
			party_order.append(i)


func lang_short() -> String:
	return "ko" if language == "ko" else "en"


func food_display() -> int:
	## xu4 stats.cpp: food / 100 on the HUD.
	return int(food / 100)


func adjust_food(delta: int) -> bool:
	## xu4 Party::adjustFood — returns true when the displayed value changes.
	var old_disp := food_display()
	food = clampi(food + delta, 0, FOOD_MAX)
	return food_display() != old_disp


func is_party_member_dead(slot: int) -> bool:
	var mid := party_member_at(slot)
	return is_class_dead(mid)


func is_class_dead(klass: int) -> bool:
	if klass < 0 or klass >= member_status.size():
		return false
	return member_status[klass] == PartyRoster.Status.DEAD


func hp_of_class(klass: int) -> int:
	if klass < 0 or klass >= member_hp.size():
		return 0
	return int(member_hp[klass])


func max_hp_of_class(klass: int) -> int:
	if klass < 0 or klass >= member_max_hp.size():
		return 0
	return int(member_max_hp[klass])


func status_of_class(klass: int) -> int:
	if klass < 0 or klass >= member_status.size():
		return PartyRoster.Status.OK
	return int(member_status[klass])


func apply_member_damage(klass: int, damage: int) -> bool:
	## xu4 PartyMember::applyDamage (non-combat). True if the hit landed (flash).
	## Death at HP <= 0 (xu4 used < 0, leaving a one-turn 0-HP lag — we don't).
	if klass < 0 or klass >= member_hp.size():
		return false
	if member_status[klass] == PartyRoster.Status.DEAD:
		return false
	var new_hp: int = int(member_hp[klass]) - damage
	if new_hp <= 0:
		member_status[klass] = PartyRoster.Status.DEAD
		new_hp = 0
	member_hp[klass] = new_hp
	return true


func wake_member(klass: int) -> bool:
	## xu4 PartyMember::wakeUp — clears sleep only.
	if klass < 0 or klass >= member_status.size():
		return false
	if member_status[klass] != PartyRoster.Status.SLEEPING:
		return false
	member_status[klass] = PartyRoster.Status.OK
	return true


func heal_ship(pts: int = 1) -> bool:
	## xu4 Party::healShip — hull capped at 50.
	if pts <= 0 or ship_hull >= SHIP_HULL_MAX:
		return false
	var before := ship_hull
	ship_hull = mini(SHIP_HULL_MAX, ship_hull + pts)
	return ship_hull != before


func living_party_count() -> int:
	## xu4: dead members do not eat; poisoned/sleeping still do.
	var n := 0
	for i in party_size():
		if not is_party_member_dead(i):
			n += 1
	return n


func end_party_turn(on_world_map: bool = true) -> Dictionary:
	## xu4 Party::endTurn (food, sleep, poison, starve, ship heal).
	moves += 1
	var old_disp := food_display()
	var eat := living_party_count()
	if eat > 0:
		food = maxi(0, food - eat)

	var damaged_mask := 0
	var poisoned_mask := 0
	var vitals_changed := false
	var ship_hull_changed := false

	for i in party_size():
		var mid := party_member_at(i)
		if mid < 0 or is_class_dead(mid):
			continue
		var st := status_of_class(mid)
		match st:
			PartyRoster.Status.SLEEPING:
				## xu4: xu4_random(5) == 0 → 20% wake per turn.
				if (randi() % 5) == 0 and wake_member(mid):
					vitals_changed = true
			PartyRoster.Status.POISONED:
				## xu4: 2 HP / turn; poison does not wear off on its own.
				if apply_member_damage(mid, POISON_DAMAGE):
					damaged_mask |= 1 << i
					poisoned_mask |= 1 << i
					vitals_changed = true

	## Starving after per-member status (xu4 emits STARVING after the loop).
	if food == 0:
		for i in party_size():
			var mid2 := party_member_at(i)
			if apply_member_damage(mid2, STARVE_DAMAGE):
				damaged_mask |= 1 << i
				vitals_changed = true

	## xu4: 25% chance to repair 1 hull on the world map while hull < 50.
	if on_world_map and ship_hull < SHIP_HULL_MAX and (randi() % 4) == 0:
		if heal_ship(1):
			ship_hull_changed = true

	return {
		"food_changed": food_display() != old_disp,
		"starving": food == 0,
		"vitals_changed": vitals_changed,
		"damaged_mask": damaged_mask,
		"poisoned_mask": poisoned_mask,
		"ship_hull_changed": ship_hull_changed,
	}


func tick_world_clock(on_world_map: bool = true) -> bool:
	## xu4 GameController::timerFired + updateMoons (one 0.25s game cycle).
	## Returns true when HUD moons/wind should refresh.
	var changed := false
	wind_counter += 1
	if wind_counter >= PHASE_TICKS:
		## 25% chance to pick a new direction (xu4_random(4) == 1 cadence).
		if not wind_lock and (randi() % 4) == 1:
			var next_wind: int = WIND_DIRS[randi() % WIND_DIRS.size()]
			if next_wind != wind_dir:
				wind_dir = next_wind
				changed = true
		wind_counter = 0

	if not on_world_map:
		return changed

	var old_tram := trammel_phase
	var old_fel := felucca_phase
	moon_phase += 1
	if moon_phase >= MOON_PHASES * PHASE_TICKS:
		moon_phase = 0
	var real_moon: int = int(moon_phase / float(PHASE_TICKS))
	felucca_phase = real_moon % 8
	trammel_phase = mini(int(real_moon / 3.0), 7)
	if trammel_phase != old_tram or felucca_phase != old_fel:
		changed = true
	return changed


func _probe_u4_data() -> bool:
	for path in [U4_DATA_RES, U4_DATA_ABS]:
		var world_path: String = path.path_join("WORLD.MAP")
		if FileAccess.file_exists(world_path):
			# Prefer readable path — res:// symlinks can fail FileAccess.get_file_as_bytes on some setups.
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(world_path)
			if bytes.size() > 0:
				u4_data_path = path
				return true
			# Exists but unreadable via this path — keep trying.
	# Last resort: absolute even if exists check was odd.
	if FileAccess.file_exists(U4_DATA_ABS.path_join("WORLD.MAP")):
		u4_data_path = U4_DATA_ABS
		return true
	return false
