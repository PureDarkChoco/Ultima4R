extends Node

## Global run state for Ultima4R (autoload: GameState).

signal language_changed(lang: String)

enum Language { EN_U4, EN_US, KO }

const LANG_IDS := ["en_us", "en_u4", "ko"]
## App-wide prefs (menu language etc.) — separate from per-slot save JSON.
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "prefs"

## External Ultima IV DOS data (never committed).
const U4_DATA_RES := "res://data/u4"
const U4_DATA_ABS := "/Applications/Ultima IV™.app/Contents/Resources/game"

var u4_data_path: String = U4_DATA_RES

var _language: String = "en_us"
var language: String:
	get:
		return _language
	set(value):
		## Menu / explicit UI changes — also writes settings.cfg.
		_set_language(value, true)


func _set_language(value: String, persist_pref: bool) -> void:
	var next := normalize_language(value)
	if _language == next:
		return
	_language = next
	if persist_pref:
		_persist_language_pref()
	language_changed.emit(_language)


func apply_session_language(lang: String) -> void:
	## In-game only (e.g. Load slot) — does not touch settings.cfg.
	_set_language(lang, false)


func restore_menu_language() -> void:
	## Back to title: use settings.cfg again (default en_us if missing).
	_load_language_pref()

var player_name: String = ""
var player_sex: String = "male" # "male" | "female"
var player_class: int = -1
## Party formation order (class indices 0..7). Index 0 = #1 on map & roster top.
var party_order: Array[int] = []
var start_pos: Vector2i = Vector2i.ZERO
var karma: Array[int] = []
## Inventory stubs until savegame is wired.
var gems: int = 0
var gold: int = 200 ## xu4 SaveGame.gold
var keys: int = 0
var torches: int = 2
var skull: int = 0 ## HUD/legacy; kept in sync with ITEM_SKULL bit
## Sextant required for Locate (L / Ctrl+L). xu4 starts with 0.
var has_sextant: bool = false
## xu4 SaveGame.shiphull — 0..50; shown while aboard a frigate.
var ship_hull: int = 50
const SHIP_HULL_MAX := 50
## xu4 SaveGame.food — centi-units (HUD shows food / 100). Cap 9999 displayed.
var food: int = 30000 ## display 300 (xu4 finishInitiateGame)
const FOOD_MAX := 999900
## xu4 SaveGame.moves — party turns since character creation (world/dungeon).
## Combat does not advance this counter in Ultima4R (xu4 does; we keep combat separate).
var moves: int = 0
## xu4 SaveGame.lastcamp — (moves / CAMP_HEAL_INTERVAL) & 0xffff after a non-ambush rest.
var lastcamp: int = 0
## xu4 SaveGame.lastreagent — (moves & 0xF0) after finding reagents / unique search loot.
var lastreagent: int = 0
## xu4 SaveGame.items / stones / runes bitfields (Search / Use).
var items: int = 0
var stones: int = 0
var runes: int = 0
## xu4 camp.h — heal only when the moves/100 bucket differs from lastcamp.
const CAMP_HEAL_INTERVAL := 100
## Sleeping corpse tile (shapes index — graphics.b tile_corpse).
const TILE_CORPSE := 56

## xu4 savegame.h Item / Stone / Rune enums.
const ITEM_SKULL := 0x01
const ITEM_SKULL_DESTROYED := 0x02
const ITEM_CANDLE := 0x04
const ITEM_BOOK := 0x08
const ITEM_BELL := 0x10
const ITEM_KEY_C := 0x20
const ITEM_KEY_L := 0x40
const ITEM_KEY_T := 0x80
const ITEM_HORN := 0x100
const ITEM_WHEEL := 0x200
const ITEM_CANDLE_USED := 0x400
const ITEM_BOOK_USED := 0x800
const ITEM_BELL_USED := 0x1000

const STONE_BLUE := 0x01
const STONE_YELLOW := 0x02
const STONE_RED := 0x04
const STONE_GREEN := 0x08
const STONE_ORANGE := 0x10
const STONE_PURPLE := 0x20
const STONE_WHITE := 0x40
const STONE_BLACK := 0x80

const RUNE_HONESTY := 0x01
const RUNE_COMPASSION := 0x02
const RUNE_VALOR := 0x04
const RUNE_JUSTICE := 0x08
const RUNE_SACRIFICE := 0x10
const RUNE_HONOR := 0x20
const RUNE_SPIRITUALITY := 0x40
const RUNE_HUMILITY := 0x80

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
const DIR_N := Vector2i(0, -1)
const DIR_E := Vector2i(1, 0)
const DIR_S := Vector2i(0, 1)
const DIR_W := Vector2i(-1, 0)

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
## Spells successfully mixed at least once (kept even if qty returns to 0).
var spell_known: Array[bool] = []
## Weapons / armor owned at least once (list at qty 0; never-owned stay hidden).
var weapon_known: Array[bool] = [] ## 16 — index 0 Hands unused
var armor_known: Array[bool] = [] ## 8 — index 0 No Armor unused
## Equipped gear by class id 0..7 (xu4 SaveGamePlayerRecord weapon/armor).
var member_weapons: Array[int] = []
var member_armor: Array[int] = []
## Class-indexed vitals (xu4 SaveGamePlayerRecord).
var member_hp: Array[int] = []
var member_max_hp: Array[int] = []
var member_mp: Array[int] = []
var member_status: Array[int] = [] ## PartyRoster.Status (dead / sleep / poison / ok)
## xu4 StatPoisoned bit — survives under sleep (camp); cleared by sleep *field*.
var member_poisoned: Array[bool] = []
var member_str: Array[int] = []
var member_dex: Array[int] = []
var member_int: Array[int] = []
var member_xp: Array[int] = []
## xu4 starving / poison: 2 HP each turn while afflicted.
const STARVE_DAMAGE := 2
const POISON_DAMAGE := 2
const MP_MAX_CAP := 99
var is_new_game: bool = false
var u4_data_ok: bool = false
## True when settings.cfg already had u4_data_path (even if that folder is now empty/missing).
var u4_data_pref_set: bool = false
## Session save/load cursor hints (not written into slot JSON).
var session_loaded_slot: int = 0 ## 1..4 if Journey loaded a slot this run
var session_did_save: bool = false
## Applied once by stub_world after Journey load.
var pending_world_save: Dictionary = {}
var intro_data := TitleExeData.new()
var intro_overlay := IntroTextOverlay.new()

## xu4 IntroController::initValuesForClass — weapon / armor / level / xp.
const CLASS_START_WEAPON := [1, 3, 5, 2, 4, 6, 6, 1] ## Staff..Sword
const CLASS_START_ARMOR := [1, 1, 2, 1, 2, 3, 2, 1] ## Cloth / Leather / Chain
const CLASS_START_LEVEL := [2, 3, 3, 2, 2, 3, 2, 1]
const CLASS_START_XP := [125, 240, 205, 175, 110, 325, 150, 5]
## xu4 initValuesForNpcClass — companions waiting off-party.
const COMPANION_STR := [9, 16, 20, 17, 15, 17, 16, 11]
const COMPANION_DEX := [12, 19, 15, 16, 16, 14, 15, 12]
const COMPANION_INT := [20, 13, 11, 13, 12, 17, 15, 10]
## Kept as aliases for older call sites.
const DEFAULT_WEAPON := CLASS_START_WEAPON
const DEFAULT_ARMOR := CLASS_START_ARMOR

enum EquipError {
	SUCCEEDED = 0,
	NONE_LEFT = 1,
	CLASS_RESTRICTED = 2,
}


func _ready() -> void:
	_load_language_pref()
	reset_party()
	u4_data_ok = _probe_u4_data()
	## Defer heavier intro I/O so the first frame / menu can appear sooner.
	call_deferred("_boot_load_intro_assets")


func _boot_load_intro_assets() -> void:
	intro_overlay.load_overlays()
	if u4_data_ok:
		_load_intro_from_u4()


func normalize_language(lang: String) -> String:
	## Only LANG_IDS are valid; unknown → en_us.
	if LANG_IDS.has(lang):
		return lang
	return "en_us"


func _load_language_pref() -> void:
	## Boot / return-to-menu: restore app language from settings.cfg.
	## Missing file → keep English (en_us).
	var cfg := ConfigFile.new()
	var saved := "en_us"
	if cfg.load(SETTINGS_PATH) == OK:
		saved = str(cfg.get_value(SETTINGS_SECTION, "language", "en_us"))
	_set_language(saved, false)


func _persist_language_pref() -> void:
	## Survives restart — independent of slot JSON saves.
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH) ## keep other keys if any
	cfg.set_value(SETTINGS_SECTION, "language", normalize_language(_language))
	cfg.save(SETTINGS_PATH)


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
	session_loaded_slot = 0
	session_did_save = false
	pending_world_save.clear()
	moon_phase = 0
	trammel_phase = 0
	felucca_phase = 0
	wind_dir = 0
	wind_counter = 0
	wind_lock = false
	## xu4 finishInitiateGame defaults (also used as clean slate).
	food = 30000
	moves = 0
	lastcamp = 0
	gems = 0
	gold = 200
	keys = 0
	torches = 2
	skull = 0
	has_sextant = false
	ship_hull = 50
	lastreagent = 0
	items = 0
	stones = 0
	runes = 0
	_reset_inventory_empty()
	_reset_member_arrays_blank()


func _reset_inventory_empty() -> void:
	## xu4 SaveGame::init — empty packs; finishInitiateGame then sets reagents/torches.
	weapons.clear()
	weapons.resize(16)
	for i in 16:
		weapons[i] = 0
	armor.clear()
	armor.resize(8)
	for i in 8:
		armor[i] = 0
	reagents.clear()
	reagents.resize(8)
	for i in 8:
		reagents[i] = 0
	reagents[1] = 3 ## ginseng
	reagents[2] = 4 ## garlic
	mixtures.clear()
	mixtures.resize(26)
	for i in 26:
		mixtures[i] = 0
	_seed_spell_known_from_mixtures()
	_reset_gear_known_empty()


func _reset_gear_known_empty() -> void:
	weapon_known.clear()
	weapon_known.resize(16)
	for i in 16:
		weapon_known[i] = false
	armor_known.clear()
	armor_known.resize(8)
	for i in 8:
		armor_known[i] = false


func _reset_member_arrays_blank() -> void:
	member_weapons.clear()
	member_armor.clear()
	member_hp.clear()
	member_max_hp.clear()
	member_mp.clear()
	member_status.clear()
	member_poisoned.clear()
	member_str.clear()
	member_dex.clear()
	member_int.clear()
	member_xp.clear()
	member_weapons.resize(8)
	member_armor.resize(8)
	member_hp.resize(8)
	member_max_hp.resize(8)
	member_mp.resize(8)
	member_status.resize(8)
	member_poisoned.resize(8)
	member_str.resize(8)
	member_dex.resize(8)
	member_int.resize(8)
	member_xp.resize(8)
	for i in 8:
		member_weapons[i] = 0
		member_armor[i] = 0
		member_hp[i] = 100
		member_max_hp[i] = 100
		member_mp[i] = 0
		member_status[i] = PartyRoster.Status.OK
		member_poisoned[i] = false
		member_str[i] = 15
		member_dex[i] = 15
		member_int[i] = 15
		member_xp[i] = 0


func _seed_spell_known_from_mixtures() -> void:
	spell_known.clear()
	spell_known.resize(Spells.COUNT)
	for i in Spells.COUNT:
		spell_known[i] = i < mixtures.size() and int(mixtures[i]) > 0


func is_spell_known(spell_id: int) -> bool:
	if spell_id < 0 or spell_id >= spell_known.size():
		return false
	return bool(spell_known[spell_id])


func mark_spell_known(spell_id: int) -> void:
	if spell_id < 0 or spell_id >= Spells.COUNT:
		return
	if spell_known.size() < Spells.COUNT:
		_seed_spell_known_from_mixtures()
	spell_known[spell_id] = true


func is_weapon_known(weapon_id: int) -> bool:
	if weapon_id <= 0 or weapon_id >= weapon_known.size():
		return false
	return bool(weapon_known[weapon_id])


func is_armor_known(armor_id: int) -> bool:
	if armor_id <= 0 or armor_id >= armor_known.size():
		return false
	return bool(armor_known[armor_id])


func mark_weapon_known(weapon_id: int) -> void:
	if weapon_id <= 0:
		return
	if weapon_known.size() < 16:
		_reset_gear_known_empty()
	if weapon_id < weapon_known.size():
		weapon_known[weapon_id] = true


func mark_armor_known(armor_id: int) -> void:
	if armor_id <= 0:
		return
	if armor_known.size() < 8:
		_reset_gear_known_empty()
	if armor_id < armor_known.size():
		armor_known[armor_id] = true


func _mark_gear_known_from_stock_and_party() -> void:
	## Pack qty > 0 or equipped on a current party member → known.
	if weapon_known.size() < 16 or armor_known.size() < 8:
		_reset_gear_known_empty()
	for w in range(1, weapons.size()):
		if int(weapons[w]) > 0:
			weapon_known[w] = true
	for a in range(1, armor.size()):
		if int(armor[a]) > 0:
			armor_known[a] = true
	for slot in party_order.size():
		var klass := party_member_at(slot)
		if klass < 0:
			continue
		mark_weapon_known(weapon_of_class(klass))
		mark_armor_known(armor_of_class(klass))


func known_spell_ids() -> Array[int]:
	var out: Array[int] = []
	for i in Spells.COUNT:
		if is_spell_known(i):
			out.append(i)
	return out


func mixture_qty(spell_id: int) -> int:
	if spell_id < 0 or spell_id >= mixtures.size():
		return 0
	return int(mixtures[spell_id])


func reagent_qty(reag_id: int) -> int:
	if reag_id < 0 or reag_id >= reagents.size():
		return 0
	return int(reagents[reag_id])


func adjust_reagent(reag_id: int, delta: int) -> bool:
	## xu4 Party::adjustReagent. False if would go below 0.
	if reag_id < 0 or reag_id >= reagents.size():
		return false
	var next: int = int(reagents[reag_id]) + delta
	if next < 0:
		return false
	reagents[reag_id] = next
	return true


func has_any_reagents() -> bool:
	for r in reagents:
		if int(r) > 0:
			return true
	return false


func can_remix_spell(spell_id: int) -> bool:
	## Known recipe reagents all present (≥1 each) and mixture not capped.
	if not is_spell_known(spell_id):
		return false
	if mixture_qty(spell_id) >= Spells.MIXTURE_MAX:
		return false
	for r in Spells.reagents_for_recipe(spell_id):
		if reagent_qty(r) < 1:
			return false
	return true


func remix_spell(spell_id: int) -> bool:
	## Auto-consume recipe reagents and add one mixture. False if unavailable.
	if not can_remix_spell(spell_id):
		return false
	for r in Spells.reagents_for_recipe(spell_id):
		if not adjust_reagent(r, -1):
			return false
	mixtures[spell_id] = mixture_qty(spell_id) + 1
	mark_spell_known(spell_id)
	return true


func commit_new_mix(spell_id: int, selected_mask: int) -> bool:
	## xu4 spellMix after reagents already deducted into the selection.
	## On success: +1 mixture and mark known. On failure: reagents stay spent.
	if spell_id < 0 or spell_id >= Spells.COUNT:
		return false
	if mixture_qty(spell_id) >= Spells.MIXTURE_MAX:
		return false
	if not Spells.recipe_matches(spell_id, selected_mask):
		return false
	mixtures[spell_id] = mixture_qty(spell_id) + 1
	mark_spell_known(spell_id)
	return true


func _reset_member_vitals() -> void:
	## Legacy hook — new games use apply_virtue_result / _init_party_from_xu4.
	_reset_member_arrays_blank()


func _reset_member_gear() -> void:
	## Equip class start gear on each class slot (xu4 player record; not inventory).
	if member_weapons.size() < 8:
		_reset_member_arrays_blank()
	for c in 8:
		member_weapons[c] = CLASS_START_WEAPON[c]
		member_armor[c] = CLASS_START_ARMOR[c]


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
		mark_weapon_known(old)
	if weapon_id != 0:
		weapons[weapon_id] -= 1
		mark_weapon_known(weapon_id)
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
		mark_armor_known(old)
	if armor_id != 0:
		armor[armor_id] -= 1
		mark_armor_known(armor_id)
	member_armor[klass] = armor_id
	return EquipError.SUCCEEDED


func apply_virtue_result(klass: int, selected_virtues: Array[int]) -> void:
	## xu4 IntroController::initPlayers + finishInitiateGame party setup.
	klass = clampi(klass, 0, 7)
	player_class = klass
	start_pos = Virtues.CLASS_START[klass]
	is_new_game = true
	session_loaded_slot = 0
	session_did_save = false
	pending_world_save.clear()
	## Inventory / party supplies (finishInitiateGame).
	_reset_inventory_empty()
	food = 30000
	gold = 200
	torches = 2
	gems = 0
	keys = 0
	skull = 0
	items = 0
	stones = 0
	runes = 0
	lastreagent = 0
	has_sextant = false
	moves = 0
	lastcamp = 0
	ship_hull = 50
	_init_party_from_xu4(klass, selected_virtues)
	party_order.clear()
	party_order.append(klass)


func _init_party_from_xu4(avatar_klass: int, selected_virtues: Array[int]) -> void:
	## Port of xu4 IntroController::initPlayers.
	_reset_member_arrays_blank()
	for i in 8:
		karma[i] = 50
	var astr := 15
	var adex := 15
	var aint := 15
	for v in selected_virtues:
		var vi := clampi(int(v), 0, 7)
		karma[vi] = int(karma[vi]) + 5
		match vi:
			Virtues.Id.HONESTY:
				aint += 3
			Virtues.Id.COMPASSION:
				adex += 3
			Virtues.Id.VALOR:
				astr += 3
			Virtues.Id.JUSTICE:
				aint += 1
				adex += 1
			Virtues.Id.SACRIFICE:
				adex += 1
				astr += 1
			Virtues.Id.HONOR:
				aint += 1
				astr += 1
			Virtues.Id.SPIRITUALITY:
				aint += 1
				adex += 1
				astr += 1
			Virtues.Id.HUMILITY:
				pass
	## Avatar record.
	member_str[avatar_klass] = astr
	member_dex[avatar_klass] = adex
	member_int[avatar_klass] = aint
	member_xp[avatar_klass] = CLASS_START_XP[avatar_klass]
	member_weapons[avatar_klass] = CLASS_START_WEAPON[avatar_klass]
	member_armor[avatar_klass] = CLASS_START_ARMOR[avatar_klass]
	member_status[avatar_klass] = PartyRoster.Status.OK
	member_poisoned[avatar_klass] = false
	var a_level := max_level_for_xp(member_xp[avatar_klass])
	member_max_hp[avatar_klass] = a_level * 100
	member_hp[avatar_klass] = member_max_hp[avatar_klass]
	member_mp[avatar_klass] = max_mp_for_stats(avatar_klass, aint)
	## Off-party companions (xu4 still writes their SaveGame slots).
	for i in 8:
		if i == avatar_klass:
			continue
		member_str[i] = COMPANION_STR[i]
		member_dex[i] = COMPANION_DEX[i]
		member_int[i] = COMPANION_INT[i]
		member_xp[i] = CLASS_START_XP[i]
		member_weapons[i] = CLASS_START_WEAPON[i]
		member_armor[i] = CLASS_START_ARMOR[i]
		member_status[i] = PartyRoster.Status.OK
		member_poisoned[i] = false
		member_max_hp[i] = CLASS_START_LEVEL[i] * 100
		member_hp[i] = member_max_hp[i]
		member_mp[i] = max_mp_for_stats(i, member_int[i])
	## Starter gear counts as once-owned (pack qty is 0 while equipped).
	mark_weapon_known(CLASS_START_WEAPON[avatar_klass])
	mark_armor_known(CLASS_START_ARMOR[avatar_klass])


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
	mark_weapon_known(weapon_of_class(klass))
	mark_armor_known(armor_of_class(klass))
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
	## Solo avatar by default (xu4 members = 1). Do not invent companions.
	var lead := player_class if player_class >= 0 else 0
	if party_order.is_empty():
		party_order.append(lead)
		return
	## Keep existing roster; ensure avatar class leads if present.
	if player_class >= 0 and party_order.has(player_class) and party_order[0] != player_class:
		party_order.erase(player_class)
		party_order.insert(0, player_class)


func lang_short() -> String:
	return "ko" if language == "ko" else "en"


func food_display() -> int:
	## xu4 stats.cpp: food / 100 on the HUD.
	return int(food / 100)


func wind_into_cardinals(w: int = -1) -> Array[Vector2i]:
	## Sailing these headings is against the wind (harder).
	## Diagonal winds affect both adjacent cardinals.
	if w < 0:
		w = wind_dir
	var out: Array[Vector2i] = []
	match posmod(w, 8):
		0:
			out.assign([DIR_N])
		1:
			out.assign([DIR_N, DIR_E])
		2:
			out.assign([DIR_E])
		3:
			out.assign([DIR_S, DIR_E])
		4:
			out.assign([DIR_S])
		5:
			out.assign([DIR_S, DIR_W])
		6:
			out.assign([DIR_W])
		7:
			out.assign([DIR_N, DIR_W])
	return out


func wind_with_cardinals(w: int = -1) -> Array[Vector2i]:
	## Sailing these headings is with the wind (easier) — reverse of into.
	if w < 0:
		w = wind_dir
	var out: Array[Vector2i] = []
	match posmod(w, 8):
		0:
			out.assign([DIR_S])
		1:
			out.assign([DIR_S, DIR_W])
		2:
			out.assign([DIR_W])
		3:
			out.assign([DIR_N, DIR_W])
		4:
			out.assign([DIR_N])
		5:
			out.assign([DIR_N, DIR_E])
		6:
			out.assign([DIR_E])
		7:
			out.assign([DIR_S, DIR_E])
	return out


func ship_slowed_by_wind(move_dir: Vector2i) -> bool:
	## Into wind: 25% sail / 75% slow. With wind: 75% sail / 25% slow.
	## (xu4 used moves%4 patterns with the same expected rates.)
	var d := Vector2i(clampi(move_dir.x, -1, 1), clampi(move_dir.y, -1, 1))
	if d == Vector2i.ZERO:
		return false
	for v in wind_into_cardinals():
		if v == d:
			return (randi() % 4) != 0 ## 3/4 slowed
	for v in wind_with_cardinals():
		if v == d:
			return (randi() % 4) == 0 ## 1/4 slowed
	return false


func ship_grounding_damage(move_dir: Vector2i) -> int:
	## Y-cruise grounding: headwind 0, otherwise flat -5 (no tailwind penalty).
	var d := Vector2i(clampi(move_dir.x, -1, 1), clampi(move_dir.y, -1, 1))
	if d == Vector2i.ZERO:
		return 5
	for v in wind_into_cardinals():
		if v == d:
			return 0
	return 5


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
	## xu4 Creature::getStatus — dead > sleeping > poisoned > good.
	if klass < 0 or klass >= member_status.size():
		return PartyRoster.Status.OK
	var st := int(member_status[klass])
	if st == PartyRoster.Status.DEAD:
		return PartyRoster.Status.DEAD
	if st == PartyRoster.Status.SLEEPING:
		return PartyRoster.Status.SLEEPING
	if st == PartyRoster.Status.POISONED or is_member_poisoned(klass):
		return PartyRoster.Status.POISONED
	return PartyRoster.Status.OK


func is_member_poisoned(klass: int) -> bool:
	## xu4 StatPoisoned bit (may be set while sleeping).
	if klass < 0 or klass >= member_poisoned.size():
		return false
	return bool(member_poisoned[klass])


func is_party_immobilized() -> bool:
	## xu4 Party::isImmobilized — every member disabled (sleeping or dead).
	var n := party_size()
	if n <= 0:
		return true
	for i in n:
		var mid := party_member_at(i)
		if mid >= 0 and not is_member_disabled(mid):
			return false
	return true


func is_party_dead() -> bool:
	## xu4 Party::isDead — every living slot is dead.
	var n := party_size()
	if n <= 0:
		return true
	for i in n:
		var mid := party_member_at(i)
		if mid >= 0 and not is_class_dead(mid):
			return false
	return true


func mp_of_class(klass: int) -> int:
	if klass < 0 or klass >= member_mp.size():
		return 0
	return int(member_mp[klass])


func max_mp_of_class(klass: int) -> int:
	return max_mp_for_stats(klass, int_of_class(klass))


func max_mp_for_stats(klass: int, intel: int) -> int:
	## xu4 PartyMember::getMaxMp — INT × class factor, capped at 99.
	var max_mp := 0
	match klass:
		0: ## Mage: 200% INT
			max_mp = intel * 2
		3: ## Druid: 150% INT
			max_mp = int(intel * 3 / 2)
		1, 5, 6: ## Bard / Paladin / Ranger: 100% INT
			max_mp = intel
		4: ## Tinker: 50% INT
			max_mp = int(intel / 2)
		2, 7: ## Fighter / Shepherd: none
			max_mp = 0
		_:
			max_mp = 0
	return mini(max_mp, MP_MAX_CAP)


func max_level_for_xp(xp: int) -> int:
	## xu4 PartyMember::getMaxLevel.
	var level := 1
	var next := 100
	while xp >= next and level < 8:
		level += 1
		next <<= 1
	return level


func level_of_class(klass: int) -> int:
	## xu4 getRealLevel — hpMax / 100.
	return maxi(1, int(max_hp_of_class(klass) / 100))


func xp_of_class(klass: int) -> int:
	if klass < 0 or klass >= member_xp.size():
		return 0
	return int(member_xp[klass])


func xp_next_of_class(klass: int) -> int:
	## Absolute XP threshold for the next level (or level-8 gate).
	var xp := xp_of_class(klass)
	var level := 1
	var next := 100
	while xp >= next and level < 8:
		level += 1
		next <<= 1
	if level >= 8:
		return 6400
	return next


func str_of_class(klass: int) -> int:
	if klass < 0 or klass >= member_str.size():
		return 0
	return int(member_str[klass])


func dex_of_class(klass: int) -> int:
	if klass < 0 or klass >= member_dex.size():
		return 0
	return int(member_dex[klass])


func int_of_class(klass: int) -> int:
	if klass < 0 or klass >= member_int.size():
		return 0
	return int(member_int[klass])


func _max_mp_for_class(klass: int) -> int:
	return max_mp_of_class(klass)


func is_member_disabled(klass: int) -> bool:
	## xu4 Creature::isDisabled — sleeping or dead (poisoned can still act/regen).
	var st := status_of_class(klass)
	return (
		st == PartyRoster.Status.DEAD
		or st == PartyRoster.Status.SLEEPING
	)


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
	## xu4 PartyMember::wakeUp — clears sleep only; poison bit may remain.
	if klass < 0 or klass >= member_status.size():
		return false
	if member_status[klass] != PartyRoster.Status.SLEEPING:
		return false
	if is_member_poisoned(klass):
		member_status[klass] = PartyRoster.Status.POISONED
	else:
		member_status[klass] = PartyRoster.Status.OK
	return true


func put_member_to_sleep(klass: int, clear_poison: bool = false) -> bool:
	## xu4 PartyMember::putToSleep — living members only.
	## Sleep *field* clears poison first; Hole up / camp does not.
	if klass < 0 or klass >= member_status.size():
		return false
	if member_status[klass] == PartyRoster.Status.DEAD:
		return false
	if clear_poison:
		_set_poisoned(klass, false)
	elif member_status[klass] == PartyRoster.Status.POISONED:
		## Preserve poison under camp sleep (single status → sleeping).
		_set_poisoned(klass, true)
	member_status[klass] = PartyRoster.Status.SLEEPING
	return true


func put_party_to_sleep(except_klass: int = -1) -> void:
	## Camp rest — do not cure poison (xu4 Hole up).
	for i in party_size():
		var mid := party_member_at(i)
		if mid >= 0 and mid != except_klass:
			put_member_to_sleep(mid, false)


func wake_party() -> void:
	for i in party_size():
		var mid := party_member_at(i)
		if mid >= 0:
			wake_member(mid)


func _set_poisoned(klass: int, on: bool) -> void:
	if klass < 0:
		return
	while member_poisoned.size() < 8:
		member_poisoned.append(false)
	if klass >= member_poisoned.size():
		return
	member_poisoned[klass] = on


func _sync_poison_flags_from_status() -> void:
	## After load without poison bits: derive from awake POISONED status.
	while member_poisoned.size() < 8:
		member_poisoned.append(false)
	for i in mini(8, member_status.size()):
		var st := int(member_status[i])
		if st == PartyRoster.Status.POISONED:
			member_poisoned[i] = true
		elif st == PartyRoster.Status.OK or st == PartyRoster.Status.DEAD:
			member_poisoned[i] = false
		## SLEEPING: keep bit from save (or false if missing).


func camp_move_bucket() -> int:
	## xu4: moves / CAMP_HEAL_INTERVAL (C integer division).
	return int(moves / CAMP_HEAL_INTERVAL)


func camp_heal_available() -> bool:
	## xu4 CampController — heal when bucket != lastcamp (or bucket overflowed 16-bit).
	var bucket := camp_move_bucket()
	if bucket >= 0x10000:
		return true
	return (bucket & 0xffff) != (lastcamp & 0xffff)


func mark_camp_used() -> void:
	## xu4: always written after a completed (non-ambush) camp rest.
	lastcamp = camp_move_bucket() & 0xffff


func apply_camp_rest(exclude_klass: int = -1) -> bool:
	## xu4 Party::applyRest(HT_CAMPHEAL) — full MP; HP += 99 + (rand & 0x77).
	## Poison is not cured. Returns true if any living member gained HP.
	## U5 watch: exclude_klass (guard) never restores HP/MP.
	var healed := false
	for i in party_size():
		var mid := party_member_at(i)
		if mid < 0 or is_class_dead(mid):
			continue
		if mid == exclude_klass:
			continue
		member_mp[mid] = max_mp_of_class(mid)
		var hp: int = int(member_hp[mid])
		var mx: int = max_hp_of_class(mid)
		if hp >= mx:
			continue
		hp += 99 + (randi() & 0x77)
		member_hp[mid] = mini(hp, mx)
		healed = true
	return healed


func adjust_gold(delta: int) -> int:
	## xu4 Party::adjustGold — gold clamped to 0..9999. Returns amount actually applied.
	var before := gold
	gold = clampi(gold + delta, 0, 9999)
	return gold - before


func take_chest_gold() -> int:
	## xu4 Party::getChest — roll + add gold; return amount rolled (for the message).
	var amount := (randi() % 50) + (randi() % 8) + 10
	adjust_gold(amount)
	return amount


func adjust_karma_virtue(virtue: int, delta: int) -> void:
	## xu4 Party::adjustVirtues for one virtue index.
	if virtue < 0 or virtue >= karma.size() or delta == 0:
		return
	var level := int(karma[virtue])
	if delta > 0:
		if level == 0:
			return ## enlightened — no further gain
		level = mini(99, level + delta)
	else:
		if level == 0:
			level = 99 ## lost eighth
		level = maxi(1, level + delta)
	karma[virtue] = level


func adjust_karma_stole_chest() -> void:
	## xu4 KA_STOLE_CHEST — Honesty / Justice / Honor −1 (city map tile chests).
	adjust_karma_virtue(Virtues.Id.HONESTY, -1)
	adjust_karma_virtue(Virtues.Id.JUSTICE, -1)
	adjust_karma_virtue(Virtues.Id.HONOR, -1)


func adjust_karma_found_item() -> void:
	## xu4 KA_FOUND_ITEM — Honor +5.
	adjust_karma_virtue(Virtues.Id.HONOR, 5)


func award_xp_leader(amount: int) -> void:
	## xu4 PartyMember::awardXp on party member 0 (leader). Cap 9999.
	if amount <= 0:
		return
	var klass := party_leader_class()
	if klass < 0 or klass >= member_xp.size():
		return
	member_xp[klass] = mini(9999, int(member_xp[klass]) + amount)


func mark_lastreagent() -> void:
	## xu4: lastreagent = moves & 0xF0 after Search loot / reagent harvest.
	lastreagent = moves & 0xF0


func has_item_flag(flag: int) -> bool:
	return (items & flag) != 0


func has_stone(flag: int) -> bool:
	return (stones & flag) != 0


func has_rune(flag: int) -> bool:
	return (runes & flag) != 0


func grant_quest_item(flag: int, xp: int) -> void:
	## Bell / Book / Candle / Horn / Wheel / Skull (and key bits later).
	award_xp_leader(xp)
	adjust_karma_found_item()
	items |= flag
	if (flag & ITEM_SKULL) != 0:
		skull = 1
	mark_lastreagent()


func grant_stone(flag: int) -> void:
	award_xp_leader(200)
	adjust_karma_found_item()
	stones |= flag
	mark_lastreagent()


func grant_rune(flag: int) -> void:
	award_xp_leader(100)
	adjust_karma_found_item()
	runes |= flag
	mark_lastreagent()


func grant_mystic_weapon() -> void:
	## xu4 putMysticInInventory — +8 mystic swords.
	award_xp_leader(400)
	adjust_karma_found_item()
	if weapons.size() > WeaponIcons.Id.MYSTIC_SWORD:
		weapons[WeaponIcons.Id.MYSTIC_SWORD] = int(weapons[WeaponIcons.Id.MYSTIC_SWORD]) + 8
		mark_weapon_known(WeaponIcons.Id.MYSTIC_SWORD)
	mark_lastreagent()


func grant_mystic_armor() -> void:
	## xu4 putMysticInInventory — +8 mystic robes.
	award_xp_leader(400)
	adjust_karma_found_item()
	if armor.size() > ArmorIcons.Id.MYSTIC_ROBE:
		armor[ArmorIcons.Id.MYSTIC_ROBE] = int(armor[ArmorIcons.Id.MYSTIC_ROBE]) + 8
		mark_armor_known(ArmorIcons.Id.MYSTIC_ROBE)
	mark_lastreagent()


func grant_search_reagent(reag_id: int) -> bool:
	## xu4 putReagentInInventory. Returns true if capped (Dropped some!).
	adjust_karma_found_item()
	var qty := reagent_qty(reag_id) + (randi() % 8) + 2
	var dropped := false
	if qty > 99:
		qty = 99
		dropped = true
	if reag_id >= 0 and reag_id < reagents.size():
		reagents[reag_id] = qty
	mark_lastreagent()
	return dropped


func is_full_avatar() -> bool:
	## xu4 SC_FULLAVATAR — every karma virtue is 0 (partial Avatarhood).
	for i in karma.size():
		if int(karma[i]) != 0:
			return false
	return karma.size() >= 8


func reagent_delay_blocks() -> bool:
	## xu4 SC_REAGENTDELAY — same moves&0xF0 bucket as lastreagent.
	return (moves & 0xF0) == lastreagent


func roll_chest_trap_u4dos() -> Dictionary:
	## xu4 getChestTrapHandler rolls (u4dos path); Ultima4R springs this on Open.
	## Returns { sprung, trap_type }. Trap type only meaningful when sprung.
	var rand_num := randi() % 4
	## u4dos: only even randNum passes → acid(0) or poison(2) as the seed pair.
	if (rand_num & 1) != 0:
		return {"sprung": false, "trap_type": TileRules.Effect.NONE}
	var pick := rand_num & (randi() % 4)
	var trap_type := TileRules.Effect.FIRE
	match pick:
		0:
			trap_type = TileRules.Effect.FIRE ## acid
		1:
			trap_type = TileRules.Effect.SLEEP
		2:
			trap_type = TileRules.Effect.POISON
		3:
			trap_type = TileRules.Effect.LAVA ## bomb
		_:
			trap_type = TileRules.Effect.FIRE
	return {"sprung": true, "trap_type": trap_type}


func chest_trap_evaded(opener_klass: int) -> bool:
	## xu4: evade when NOT (dex + 25 < random(100)).
	var dex := dex_of_class(opener_klass)
	return not (dex + 25 < (randi() % 100))


func apply_tile_effect(effect: int) -> int:
	## xu4 Party::applyEffect(ALL_PLAYERS) — returns flash mask (party slots).
	return apply_effect(effect, -1)


func apply_effect(effect: int, party_slot: int = -1) -> int:
	## xu4 Party::applyEffect. party_slot < 0 → ALL_PLAYERS (50%/20% rolls).
	## party_slot >= 0 → that member only (always applies when eligible).
	var always := party_slot >= 0
	match effect:
		TileRules.Effect.POISON, TileRules.Effect.POISONFIELD:
			return _apply_poison_effect(party_slot, always)
		TileRules.Effect.SLEEP:
			return _apply_sleep_effect(party_slot, always)
		TileRules.Effect.FIRE, TileRules.Effect.LAVA:
			return _apply_fire_effect(party_slot, always)
		_:
			return 0


func _effect_slot_range(party_slot: int) -> Vector2i:
	## Inclusive start, exclusive end over party slots.
	if party_slot < 0:
		return Vector2i(0, party_size())
	return Vector2i(party_slot, party_slot + 1)


func _apply_poison_effect(party_slot: int, always: bool) -> int:
	## xu4 EFFECT_POISON: skip dead / status==POISONED; always or 1/5.
	var flash_mask := 0
	var r := _effect_slot_range(party_slot)
	for i in range(r.x, r.y):
		var mid := party_member_at(i)
		if mid < 0 or is_class_dead(mid):
			continue
		if status_of_class(mid) == PartyRoster.Status.POISONED:
			continue
		if not always and (randi() % 5) != 0:
			continue
		_set_poisoned(mid, true)
		if member_status[mid] != PartyRoster.Status.SLEEPING:
			member_status[mid] = PartyRoster.Status.POISONED
		flash_mask |= 1 << i
	return flash_mask


func _apply_sleep_effect(party_slot: int, always: bool) -> int:
	## xu4 EFFECT_SLEEP: skip disabled; always or 50%; clears poison.
	var flash_mask := 0
	var r := _effect_slot_range(party_slot)
	for i in range(r.x, r.y):
		var mid := party_member_at(i)
		if mid < 0 or is_member_disabled(mid):
			continue
		if not always and (randi() % 2) != 0:
			continue
		if put_member_to_sleep(mid, true):
			flash_mask |= 1 << i
	return flash_mask


func _apply_fire_effect(party_slot: int, always: bool) -> int:
	## xu4 EFFECT_FIRE / EFFECT_LAVA: 16+random(32); always or 50%.
	var flash_mask := 0
	var r := _effect_slot_range(party_slot)
	for i in range(r.x, r.y):
		var mid := party_member_at(i)
		if mid < 0 or is_class_dead(mid):
			continue
		if not always and (randi() % 2) != 0:
			continue
		var dmg := 16 + (randi() % 32)
		if apply_member_damage(mid, dmg):
			flash_mask |= 1 << i
	return flash_mask


func heal_ship(pts: int = 1) -> bool:
	## xu4 Party::healShip — hull capped at 50.
	if pts <= 0 or ship_hull >= SHIP_HULL_MAX:
		return false
	var before := ship_hull
	ship_hull = mini(SHIP_HULL_MAX, ship_hull + pts)
	return ship_hull != before


func damage_ship(pts: int) -> bool:
	## xu4 Party::damageShip. True if the hull sinks (pts > remaining).
	if pts <= 0:
		return false
	if pts > ship_hull:
		ship_hull = 0
		return true
	ship_hull -= pts
	return false


func damage_party_cannon(min_damage: int = 10, max_damage: int = 25) -> int:
	## xu4 gameDamageParty — each living member 50% chance of min..max damage.
	## Returns roster flash mask (party slot bits).
	var flash_mask := 0
	var span := maxi(0, max_damage - min_damage)
	for i in party_size():
		var mid := party_member_at(i)
		if mid < 0 or is_class_dead(mid):
			continue
		if (randi() % 2) != 0:
			continue
		var dmg := min_damage
		if span > 0:
			dmg = min_damage + (randi() % (span + 1))
		elif max_damage >= 0:
			dmg = max_damage
		if apply_member_damage(mid, dmg):
			flash_mask |= 1 << i
	return flash_mask


func kill_party() -> void:
	## xu4 gameKillParty — all members HP 0 / DEAD (death sequence later).
	for i in party_size():
		var mid := party_member_at(i)
		if mid < 0:
			continue
		if mid < member_hp.size():
			member_hp[mid] = 0
		if mid < member_status.size():
			member_status[mid] = PartyRoster.Status.DEAD


func living_party_count() -> int:
	## xu4: dead members do not eat; poisoned/sleeping still do.
	var n := 0
	for i in party_size():
		if not is_party_member_dead(i):
			n += 1
	return n


func end_party_turn(on_world_map: bool = true, in_combat: bool = false) -> Dictionary:
	## xu4 Party::endTurn.
	## - World/dungeon: moves++ then food / sleep wake / poison / starve / MP / hull.
	## - Combat (xu4): still moves++, but no food/status. Ultima4R skips moves in combat
	##   so camp heal / virtue timers only advance outside battle.
	if not in_combat:
		moves += 1

	var old_disp := food_display()
	var damaged_mask := 0
	var poisoned_mask := 0
	var vitals_changed := false
	var ship_hull_changed := false

	if in_combat:
		return {
			"food_changed": false,
			"starving": food == 0,
			"vitals_changed": false,
			"damaged_mask": 0,
			"poisoned_mask": 0,
			"ship_hull_changed": false,
		}

	var eat := living_party_count()
	if eat > 0:
		food = maxi(0, food - eat)

	for i in party_size():
		var mid := party_member_at(i)
		if mid < 0 or is_class_dead(mid):
			continue
		var st := status_of_class(mid)
		match st:
			PartyRoster.Status.SLEEPING:
				## xu4: xu4_random(5) == 0 → 20% wake per turn.
				## Poison under sleep does not deal damage (getStatus == SLEEPING).
				if (randi() % 5) == 0 and wake_member(mid):
					vitals_changed = true
			PartyRoster.Status.POISONED:
				## xu4: 2 HP / turn; poison does not wear off on its own.
				if apply_member_damage(mid, POISON_DAMAGE):
					damaged_mask |= 1 << i
					poisoned_mask |= 1 << i
					vitals_changed = true
		## xu4: MP +1 each turn if not disabled and below max (same turn as wake).
		if not is_member_disabled(mid):
			var mx := max_mp_of_class(mid)
			if mx > 0 and mid < member_mp.size() and int(member_mp[mid]) < mx:
				member_mp[mid] = int(member_mp[mid]) + 1
				vitals_changed = true

	## Starving after per-member status (xu4 emits STARVING after the loop).
	if food == 0:
		for i in party_size():
			var mid2 := party_member_at(i)
			if apply_member_damage(mid2, STARVE_DAMAGE):
				damaged_mask |= 1 << i
				vitals_changed = true

	## World-map hull regen at half xu4 pace (12.5% / turn vs 25%).
	if on_world_map and ship_hull < SHIP_HULL_MAX and (randi() % 8) == 0:
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


func to_save_dict() -> Dictionary:
	## Snapshot of xu4-aligned party / inventory / clock fields for SaveGame JSON.
	return {
		"player_name": player_name,
		"player_sex": player_sex,
		"player_class": player_class,
		"party_order": party_order.duplicate(),
		"start_pos": {"x": start_pos.x, "y": start_pos.y},
		"karma": karma.duplicate(),
		"food": food,
		"moves": moves,
		"lastcamp": lastcamp,
		"ship_hull": ship_hull,
		"gems": gems,
		"gold": gold,
		"keys": keys,
		"torches": torches,
		"skull": skull,
		"items": items,
		"stones": stones,
		"runes": runes,
		"lastreagent": lastreagent,
		"has_sextant": has_sextant,
		"weapons": weapons.duplicate(),
		"armor": armor.duplicate(),
		"reagents": reagents.duplicate(),
		"mixtures": mixtures.duplicate(),
		"spell_known": spell_known.duplicate(),
		"weapon_known": weapon_known.duplicate(),
		"armor_known": armor_known.duplicate(),
		"member_weapons": member_weapons.duplicate(),
		"member_armor": member_armor.duplicate(),
		"member_hp": member_hp.duplicate(),
		"member_max_hp": member_max_hp.duplicate(),
		"member_mp": member_mp.duplicate(),
		"member_status": member_status.duplicate(),
		"member_poisoned": member_poisoned.duplicate(),
		"member_str": member_str.duplicate(),
		"member_dex": member_dex.duplicate(),
		"member_int": member_int.duplicate(),
		"member_xp": member_xp.duplicate(),
		"moon_phase": moon_phase,
		"trammel_phase": trammel_phase,
		"felucca_phase": felucca_phase,
		"wind_dir": wind_dir,
		"wind_counter": wind_counter,
		"wind_lock": wind_lock,
		"language": language,
	}


func apply_save_dict(d: Dictionary) -> void:
	## Restore from SaveGame JSON `game` object.
	if d.is_empty():
		return
	player_name = str(d.get("player_name", player_name))
	player_sex = str(d.get("player_sex", player_sex))
	player_class = int(d.get("player_class", player_class))
	_apply_int_array(party_order, d.get("party_order", []), 0)
	var sp: Variant = d.get("start_pos", {})
	if typeof(sp) == TYPE_DICTIONARY:
		start_pos = Vector2i(int(sp.get("x", 0)), int(sp.get("y", 0)))
	_apply_int_array(karma, d.get("karma", []), 8)
	## Missing keys must use schema defaults (0/false), never the previous session —
	## older slots omit items/stones/runes/lastreagent and would otherwise leak loot.
	food = int(d.get("food", 0))
	moves = int(d.get("moves", 0))
	lastcamp = int(d.get("lastcamp", 0))
	ship_hull = clampi(int(d.get("ship_hull", 0)), 0, SHIP_HULL_MAX)
	gems = maxi(0, int(d.get("gems", 0)))
	gold = maxi(0, int(d.get("gold", 0)))
	keys = maxi(0, int(d.get("keys", 0)))
	torches = maxi(0, int(d.get("torches", 0)))
	skull = maxi(0, int(d.get("skull", 0)))
	items = maxi(0, int(d.get("items", 0)))
	stones = maxi(0, int(d.get("stones", 0)))
	runes = maxi(0, int(d.get("runes", 0)))
	lastreagent = maxi(0, int(d.get("lastreagent", 0)))
	## Legacy saves stored only `skull` count — promote into the items bitfield.
	if skull > 0 and (items & ITEM_SKULL) == 0 and (items & ITEM_SKULL_DESTROYED) == 0:
		items |= ITEM_SKULL
	skull = 1 if (items & ITEM_SKULL) != 0 else 0
	has_sextant = bool(d.get("has_sextant", false))
	_apply_int_array(weapons, d.get("weapons", []), 16)
	_apply_int_array(armor, d.get("armor", []), 8)
	_apply_int_array(reagents, d.get("reagents", []), 8)
	_apply_int_array(mixtures, d.get("mixtures", []), 26)
	_apply_bool_array(spell_known, d.get("spell_known", []), Spells.COUNT)
	if d.has("weapon_known") or d.has("armor_known"):
		_apply_bool_array(weapon_known, d.get("weapon_known", []), 16)
		_apply_bool_array(armor_known, d.get("armor_known", []), 8)
	else:
		## Older saves: infer after member arrays are restored.
		_reset_gear_known_empty()
	_apply_int_array(member_weapons, d.get("member_weapons", []), 8)
	_apply_int_array(member_armor, d.get("member_armor", []), 8)
	_apply_int_array(member_hp, d.get("member_hp", []), 8)
	_apply_int_array(member_max_hp, d.get("member_max_hp", []), 8)
	_apply_int_array(member_mp, d.get("member_mp", []), 8)
	_apply_int_array(member_status, d.get("member_status", []), 8)
	if d.has("member_poisoned"):
		_apply_bool_array(member_poisoned, d.get("member_poisoned", []), 8)
	else:
		member_poisoned.clear()
		_sync_poison_flags_from_status()
	_apply_int_array(member_str, d.get("member_str", []), 8)
	_apply_int_array(member_dex, d.get("member_dex", []), 8)
	_apply_int_array(member_int, d.get("member_int", []), 8)
	_apply_int_array(member_xp, d.get("member_xp", []), 8)
	## Older saves without attrs: seed companion/avatar defaults from class tables.
	if not d.has("member_str"):
		_seed_stats_from_class_defaults()
	moon_phase = int(d.get("moon_phase", moon_phase))
	trammel_phase = clampi(int(d.get("trammel_phase", trammel_phase)), 0, 7)
	felucca_phase = clampi(int(d.get("felucca_phase", felucca_phase)), 0, 7)
	wind_dir = posmod(int(d.get("wind_dir", wind_dir)), 8)
	wind_counter = int(d.get("wind_counter", wind_counter))
	wind_lock = bool(d.get("wind_lock", wind_lock))
	if d.has("language"):
		## Slot language for this play session only — menu prefs stay separate.
		apply_session_language(str(d.get("language")))
	is_new_game = false
	if party_order.is_empty():
		refresh_party_order()
	## Ensure pack / equipped gear are marked (also migrates pre-known saves).
	_mark_gear_known_from_stock_and_party()


func _seed_stats_from_class_defaults() -> void:
	## Best-effort for pre-stat saves: companions table + avatar from XP/HP.
	if member_str.size() < 8:
		_reset_member_arrays_blank()
	for i in 8:
		if i == player_class:
			member_str[i] = 15
			member_dex[i] = 15
			member_int[i] = 15
		else:
			member_str[i] = COMPANION_STR[i]
			member_dex[i] = COMPANION_DEX[i]
			member_int[i] = COMPANION_INT[i]
		if member_xp[i] <= 0:
			member_xp[i] = CLASS_START_XP[i]


func _apply_int_array(dest: Array, src: Variant, min_size: int) -> void:
	dest.clear()
	if typeof(src) == TYPE_ARRAY:
		for v in src:
			dest.append(int(v))
	while dest.size() < min_size:
		dest.append(0)


func _apply_bool_array(dest: Array, src: Variant, min_size: int) -> void:
	dest.clear()
	if typeof(src) == TYPE_ARRAY:
		for v in src:
			dest.append(bool(v))
	while dest.size() < min_size:
		dest.append(false)


func _load_intro_from_u4() -> void:
	var title_path := u4_data_path.path_join("TITLE.EXE")
	if not intro_data.load_from_path(title_path):
		push_warning("GameState: TITLE.EXE intro strings not loaded from %s" % title_path)


func try_set_u4_data_path(path: String) -> bool:
	## Validate a user-supplied Ultima IV DOS folder, persist to settings.cfg.
	var resolved := resolve_u4_data_dir(path)
	if not is_valid_u4_data_dir(resolved):
		return false
	u4_data_path = resolved
	u4_data_ok = true
	_persist_u4_data_path()
	_load_intro_from_u4()
	return true


func resolve_u4_data_dir(path: String) -> String:
	## Accept a folder, .app bundle, or parent that contains /game.
	var p := path.strip_edges()
	if p.begins_with("\"") and p.ends_with("\"") and p.length() >= 2:
		p = p.substr(1, p.length() - 2).strip_edges()
	if p.begins_with("'") and p.ends_with("'") and p.length() >= 2:
		p = p.substr(1, p.length() - 2).strip_edges()
	if p.begins_with("~"):
		var home := OS.get_environment("HOME")
		if home.is_empty():
			home = OS.get_environment("USERPROFILE")
		p = home.path_join(p.substr(1).lstrip("/\\"))
	p = p.replace("\\", "/")
	if p.is_empty():
		return ""
	## Prefer the first candidate that actually contains WORLD.MAP.
	var candidates: Array[String] = [p]
	if p.ends_with(".app") or p.ends_with(".app/"):
		candidates.append(p.path_join("Contents/Resources/game"))
	candidates.append(p.path_join("Contents/Resources/game"))
	candidates.append(p.path_join("game"))
	for cand in candidates:
		var norm := cand.rstrip("/").simplify_path()
		if is_valid_u4_data_dir(norm):
			return norm
	return p.rstrip("/").simplify_path()


func is_valid_u4_data_dir(path: String) -> bool:
	## Existence + readable size only — do not slurp WORLD.MAP into memory.
	if path.is_empty():
		return false
	var world_path := path.path_join("WORLD.MAP")
	if not FileAccess.file_exists(world_path):
		world_path = path.path_join("world.map")
		if not FileAccess.file_exists(world_path):
			return false
	var f := FileAccess.open(world_path, FileAccess.READ)
	if f == null:
		return false
	var sz := f.get_length()
	f.close()
	return sz > 0


func _load_u4_data_path_pref() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return ""
	return str(cfg.get_value(SETTINGS_SECTION, "u4_data_path", "")).strip_edges()


func _persist_u4_data_path() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH) ## keep language etc.
	cfg.set_value(SETTINGS_SECTION, "u4_data_path", u4_data_path)
	cfg.save(SETTINGS_PATH)


func _probe_u4_data() -> bool:
	## If settings already has a path: only verify that location (no hunting).
	## First run (no key): search known install spots once, then persist or fail.
	var saved := _load_u4_data_path_pref()
	if not saved.is_empty():
		u4_data_pref_set = true
		var resolved := resolve_u4_data_dir(saved)
		if is_valid_u4_data_dir(saved):
			u4_data_path = saved
			return true
		if not resolved.is_empty() and resolved != saved and is_valid_u4_data_dir(resolved):
			u4_data_path = resolved
			_persist_u4_data_path()
			return true
		u4_data_path = saved
		return false

	u4_data_pref_set = false
	var candidates: Array[String] = [
		U4_DATA_RES,
		U4_DATA_ABS,
		resolve_u4_data_dir("/Applications/Ultima IV™.app"),
	]
	var seen: Dictionary = {}
	for path in candidates:
		if path.is_empty() or seen.has(path):
			continue
		seen[path] = true
		if is_valid_u4_data_dir(path):
			u4_data_path = path
			_persist_u4_data_path()
			return true
	return false
