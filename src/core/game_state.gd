extends Node

## Global run state for Ultima4R (autoload: GameState).

const _Journal := preload("res://src/core/journal.gd")

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

## English name (required). Display & save key for English UI.
var player_name: String = ""
## Optional Korean name. Empty → fall back to English when language is ko.
var player_name_ko: String = ""
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
## xu4 SaveGame.shiphull — normally 0..50; Wheel mounts to 99 (setShipHull).
var ship_hull: int = 50
const SHIP_HULL_MAX := 50
## Absolute hull after Wheel; also storage clamp (xu4 setShipHull adjusts to 0..99).
const SHIP_HULL_WHEEL := 99
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
## xu4 SaveGame.lastvirtue — (moves / 16) & 0xffff when a timed +karma last applied.
var lastvirtue: int = 0
## xu4 SaveGame.lastmeditation — (moves / 100) & 0xffff when shrine meditation began.
var lastmeditation: int = 0
## xu4 SaveGame.items / stones / runes bitfields (Search / Use).
var items: int = 0
var stones: int = 0
var runes: int = 0
## xu4 SaveGame.lbIntro — first throne-room audience speech delivered.
var lb_intro: bool = false
## Journal / 여행 기록 — catalog hits in acquisition order (see Journal / entries.json).
var journal_entries: Array = []
## Place id → true when that settlement's journal group is collapsed.
var journal_collapsed: Dictionary = {}
## Catalog id or `place:<id>` of the highlighted journal row (browse cursor / save restore).
var journal_selected_id: String = ""
## New catalog id not yet shown in journal browse; next open jumps here once.
var journal_unseen_id: String = ""
## 0 = notes (page 1), 1 = collection page. New entries always return to page 1.
var journal_page: int = 0
## Bitmasks (1 << Virtues.Id) of virtues / mantras learned from talk or shrine.
var journal_known_virtues: int = 0
var journal_known_mantras: int = 0
var journal_known_dungeons: int = 0
## Spoken NPC interests: "city/d{discourse}" → Array of stable keyword keys.
## Legacy saves may still use "city/npc-name".
var talk_known_keywords: Dictionary = {}
## Interest words actually heard in any spoken line (any NPC). Used to surface
## another speaker's hidden topic (e.g. Iolo + compassion) from the first prompt.
var talk_heard_words: Array = []
## xu4 camp.h — heal only when the moves/100 bucket differs from lastcamp.
const CAMP_HEAL_INTERVAL := 100
## Sleeping corpse tile (shapes index — graphics.b tile_corpse).
const TILE_CORPSE := 56

## Party-wide timed effects. Jinx / Protection / Quickness stack (one of each);
## a caster may sustain only one of those three. Negate clears those three and
## blocks magic for its duration. Horn / Winds are independent.
## Not saved.
enum AuraType {
	NONE = 0,
	HORN = 1,
	JINX = 2,
	NEGATE = 3,
	PROTECTION = 4,
	QUICKNESS = 5,
	WINDS = 6,
}
## type → remaining turns
var _aura_duration: Dictionary = {}
## type → class index who cast (Jinx / Protection / Quickness only)
var _aura_caster: Dictionary = {}
## Skip the next pass_aura_turn (cast/use already spent that party turn).
var _aura_grace: Dictionary = {}
## xu4 spellJinx / spellNegate / spellProtection / spellQuickness / useHorn.
const AURA_SPELL_TURNS := 10
## Remake: hold Winds for two–three 4s wind checks (real time, not party turns).
const WIND_SPELL_SEC := 10.0
const SPELL_AURA_TYPES: Array[int] = [AuraType.JINX, AuraType.PROTECTION, AuraType.QUICKNESS]
## Remaining Winds lock in seconds. Not saved. Ticked by the 4 Hz world clock.
var _wind_spell_left := 0.0

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


func player_display_name() -> String:
	## UI language picks English vs Korean; missing Korean uses English.
	var en := player_name.strip_edges()
	if language == "ko":
		var ko := player_name_ko.strip_edges()
		if not ko.is_empty():
			return ko
		if not en.is_empty():
			return en
		return "아바타"
	if not en.is_empty():
		return en
	return "Avatar"


func reset_party() -> void:
	player_name = ""
	player_name_ko = ""
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
	_wind_spell_left = 0.0
	## xu4 finishInitiateGame defaults (also used as clean slate).
	food = 30000
	moves = 0
	lastcamp = 0
	lastvirtue = 0
	lastmeditation = 0
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
	lb_intro = false
	journal_entries.clear()
	journal_collapsed.clear()
	journal_selected_id = ""
	journal_unseen_id = ""
	journal_page = 0
	journal_known_virtues = 0
	journal_known_mantras = 0
	journal_known_dungeons = 0
	talk_known_keywords.clear()
	talk_heard_words.clear()
	clear_aura()
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


func mark_spell_known(spell_id: int) -> bool:
	## True only when the recipe was unknown and is newly recorded.
	if spell_id < 0 or spell_id >= Spells.COUNT:
		return false
	if spell_known.size() < Spells.COUNT:
		_seed_spell_known_from_mixtures()
	if bool(spell_known[spell_id]):
		return false
	spell_known[spell_id] = true
	return true


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


func consume_mixture(spell_id: int) -> bool:
	## xu4 spellCast — spend one mixture even when the cast later fails.
	var qty := mixture_qty(spell_id)
	if qty <= 0:
		return false
	mixtures[spell_id] = qty - 1
	return true


func spell_prereq_error(spell_id: int, caster_klass: int, loc_ctx: int) -> int:
	## xu4 spellCheckPrerequisites — mix, location, then MP. Transport skipped (any).
	if mixture_qty(spell_id) <= 0:
		return Spells.CASTERR_NOMIX
	if not Spells.context_ok(spell_id, loc_ctx):
		return Spells.CASTERR_WRONGCONTEXT
	if mp_of_class(caster_klass) < Spells.mp_cost(spell_id):
		return Spells.CASTERR_MPTOOLOW
	return Spells.CASTERR_NOERROR


func adjust_mp(klass: int, delta: int) -> int:
	## xu4 PartyMember::adjustMp — clamp 0..max MP.
	if klass < 0 or klass >= member_mp.size():
		return 0
	var mx := max_mp_of_class(klass)
	var next: int = int(member_mp[klass]) + delta
	if next < 0:
		next = 0
	if next > mx:
		next = mx
	member_mp[klass] = next
	return next


func has_any_mixtures() -> bool:
	for q in mixtures:
		if int(q) > 0:
			return true
	return false


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
	## Flaming Oil stays in the inventory count while readied (consumable stack).
	var klass := party_member_at(slot)
	if klass < 0:
		return EquipError.NONE_LEFT
	if weapon_id < 0 or weapon_id >= weapons.size():
		return EquipError.NONE_LEFT
	var old := weapon_of_class(klass)
	if old == weapon_id:
		return EquipError.SUCCEEDED
	var oil := WeaponIcons.Id.FLAMING_OIL
	if weapon_id == oil:
		## Need a free flask in the party pool (qty > members already wielding oil).
		if int(weapons[oil]) <= _party_wielding_weapon_count(oil):
			return EquipError.NONE_LEFT
	elif weapon_id != 0 and weapons[weapon_id] < 1:
		return EquipError.NONE_LEFT
	if not WeaponIcons.can_ready(weapon_id, klass):
		return EquipError.CLASS_RESTRICTED
	if old != 0 and old < weapons.size() and old != oil:
		weapons[old] += 1
		mark_weapon_known(old)
	if weapon_id != 0 and weapon_id != oil:
		weapons[weapon_id] -= 1
		mark_weapon_known(weapon_id)
	elif weapon_id == oil:
		mark_weapon_known(oil)
	member_weapons[klass] = weapon_id
	return EquipError.SUCCEEDED


func _party_wielding_weapon_count(weapon_id: int) -> int:
	var n := 0
	for slot in party_order.size():
		var mid := party_member_at(slot)
		if mid >= 0 and weapon_of_class(mid) == weapon_id:
			n += 1
	return n


func flaming_oil_can_ready() -> bool:
	## True if a free flask remains for another party member to ready.
	var oil := WeaponIcons.Id.FLAMING_OIL
	if oil >= weapons.size():
		return false
	return int(weapons[oil]) > _party_wielding_weapon_count(oil)


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
	lb_intro = false
	lastreagent = 0
	has_sextant = false
	moves = 0
	lastcamp = 0
	lastvirtue = 0
	lastmeditation = 0
	ship_hull = 50
	_init_party_from_xu4(klass, selected_virtues)
	party_order.clear()
	party_order.append(klass)
	clear_aura()
	journal_entries.clear()
	journal_collapsed.clear()
	journal_selected_id = ""
	journal_unseen_id = ""
	journal_page = 0
	journal_known_virtues = 0
	journal_known_mantras = 0
	journal_known_dungeons = 0
	_Journal.seed_new_game(self)


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
	_scale_companion_to_party(klass)
	party_order.append(klass)
	mark_weapon_known(weapon_of_class(klass))
	mark_armor_known(armor_of_class(klass))
	if party_order.size() >= 8:
		journal_mark_goal("companions:7")
	if companion_class_by_name("Jaana") == klass:
		journal_mark_goal("join:jaana")
	return true


## xu4 CannotJoinError.
enum JoinError {
	SUCCEEDED = 0,
	NOT_EXPERIENCED = 1,
	NOT_VIRTUOUS = 2,
	CANNOT_JOIN = 3,
}


func companion_class_by_name(name: String) -> int:
	## Match off-party companion name (Iolo, Mariah, …). -1 if not a joinable NPC.
	var n := name.strip_edges()
	if n.is_empty():
		return -1
	var n_lower := n.to_lower()
	for i in PartyRoster.COMPANION_NAMES.size():
		if str(PartyRoster.COMPANION_NAMES[i]).to_lower() == n_lower:
			return i
	for i in PartyRoster.COMPANION_NAMES_KO.size():
		if str(PartyRoster.COMPANION_NAMES_KO[i]) == n:
			return i
	return -1


func can_person_join_name(name: String) -> bool:
	## xu4 Party::canPersonJoin — joinable only if not the Avatar's own class
	## and not already a recruited companion (xu4 slots 1..7 / roster past leader).
	var klass := companion_class_by_name(name)
	if klass < 0:
		return false
	if party_order.is_empty():
		refresh_party_order()
	var avatar_cls := player_class if player_class >= 0 else party_leader_class()
	if klass == avatar_cls:
		return false
	if is_person_joined(name):
		return false
	return true


func is_person_joined(name: String) -> bool:
	## xu4 Party::isPersonJoined — true only if already a *party member past the avatar*.
	## Skip slot 0: an Avatar of the same class must NOT hide that town companion.
	## Join still fails via try_join (klass already in party_order as the avatar).
	var klass := companion_class_by_name(name)
	if klass < 0:
		return false
	if party_order.is_empty():
		refresh_party_order()
	for slot in range(1, party_order.size()):
		if int(party_order[slot]) == klass:
			return true
	return false


func try_join_companion(name: String) -> int:
	## xu4 Party::join — returns JoinError.
	var klass := companion_class_by_name(name)
	if klass < 0:
		return JoinError.CANNOT_JOIN
	if party_order.is_empty():
		refresh_party_order()
	if party_order.has(klass):
		return JoinError.CANNOT_JOIN ## already with the party (inventory slot reused)
	## Avatar max HP / 100 must be ≥ new party size.
	var avatar_cls := player_class if player_class >= 0 else party_leader_class()
	var hp_max := 100
	if avatar_cls >= 0 and avatar_cls < member_max_hp.size():
		hp_max = maxi(100, int(member_max_hp[avatar_cls]))
	if party_order.size() + 1 > int(hp_max / 100):
		return JoinError.NOT_EXPERIENCED
	## Virtue of companion's class must be 0 (avatar) or ≥ 40.
	var virt := klass ## class index == virtue index
	if virt >= 0 and virt < karma.size():
		var k := int(karma[virt])
		if k > 0 and k < 40:
			return JoinError.NOT_VIRTUOUS
	if add_party_member(klass):
		return JoinError.SUCCEEDED
	return JoinError.CANNOT_JOIN


func virtue_adjective_en(virtue: int) -> String:
	const ADJ := [
		"honest", "compassionate", "valiant", "just",
		"sacrificial", "honorable", "spiritual", "humble",
	]
	if virtue < 0 or virtue >= ADJ.size():
		return "virtuous"
	return ADJ[virtue]


func virtue_increase_timeout() -> bool:
	## xu4 Party::virtueIncreaseTimeout — at most one timed +karma per moves/16 bucket.
	## Shared by give (Compassion), humble (Humility), meditation/Hawkwind (Spirituality).
	var bucket := int(moves / 16)
	if bucket >= 0x10000 or (bucket & 0xFFFF) != (lastvirtue & 0xFFFF):
		lastvirtue = bucket & 0xFFFF
		return true
	return false


func donate_gold(quantity: int) -> bool:
	## xu4 Party::donate — true if gold was paid (gold always leaves; karma may not).
	if quantity <= 0:
		return false
	if gold < quantity:
		return false
	adjust_gold(-quantity)
	if gold > 0:
		adjust_karma_gave_to_beggar()
	else:
		adjust_karma_gave_all_to_beggar()
	return true


func adjust_karma_gave_to_beggar() -> void:
	## xu4 KA_GAVE_TO_BEGGAR — Compassion +2 if virtueIncreaseTimeout allows.
	if virtue_increase_timeout():
		adjust_karma_virtue(Virtues.Id.COMPASSION, 2)


func adjust_karma_gave_all_to_beggar() -> void:
	## xu4 KA_GAVE_ALL_TO_BEGGAR — same +2 compassion in U4DOS (also timed).
	if virtue_increase_timeout():
		adjust_karma_virtue(Virtues.Id.COMPASSION, 2)


func adjust_karma_reagent_pay(paying: int, list_total: int) -> void:
	## xu4 vendors.b reagents you_pay — Honesty / Justice / Honor together.
	## paying >= list: +2 each; shortfall d < 12: -4; else −floor(d/3).
	if list_total <= 0:
		return
	var delta := 2
	if paying < list_total:
		var d := list_total - paying
		if d < 12:
			delta = -4
		else:
			delta = -int(d / 3)
	adjust_karma_virtue(Virtues.Id.HONESTY, delta)
	adjust_karma_virtue(Virtues.Id.JUSTICE, delta)
	adjust_karma_virtue(Virtues.Id.HONOR, delta)


func adjust_karma_blood_donation(donated: bool) -> void:
	## xu4 healer give_blood — Sacrifice ±5.
	adjust_karma_virtue(Virtues.Id.SACRIFICE, 5 if donated else -5)


func pack_weapon_qty(weapon_id: int) -> int:
	if weapon_id <= 0 or weapon_id >= weapons.size():
		return 0
	return int(weapons[weapon_id])


func pack_armor_qty(armor_id: int) -> int:
	if armor_id <= 0 or armor_id >= armor.size():
		return 0
	return int(armor[armor_id])


func equipped_weapon_count(weapon_id: int) -> int:
	## Living party members currently readying this weapon id.
	if weapon_id <= 0:
		return 0
	return _party_wielding_weapon_count(weapon_id)


func equipped_armor_count(armor_id: int) -> int:
	if armor_id <= 0:
		return 0
	var n := 0
	for slot in party_order.size():
		var mid := party_member_at(slot)
		if mid < 0 or is_class_dead(mid):
			continue
		if armor_of_class(mid) == armor_id:
			n += 1
	return n


func party_can_equip_new_weapon(weapon_id: int) -> bool:
	## True if some living member can ready this weapon and is not already wielding it.
	if weapon_id <= 0:
		return false
	for slot in party_order.size():
		var mid := party_member_at(slot)
		if mid < 0 or is_class_dead(mid):
			continue
		if weapon_of_class(mid) == weapon_id:
			continue
		if WeaponIcons.can_ready(weapon_id, mid):
			return true
	return false


func party_can_equip_new_armor(armor_id: int) -> bool:
	## True if some living member can wear this armor and is not already wearing it.
	if armor_id <= 0:
		return false
	for slot in party_order.size():
		var mid := party_member_at(slot)
		if mid < 0 or is_class_dead(mid):
			continue
		if armor_of_class(mid) == armor_id:
			continue
		if ArmorIcons.can_wear(armor_id, mid):
			return true
	return false


func add_pack_weapons(weapon_id: int, amount: int) -> void:
	if weapon_id <= 0 or weapon_id >= weapons.size() or amount <= 0:
		return
	weapons[weapon_id] = mini(99, int(weapons[weapon_id]) + amount)
	mark_weapon_known(weapon_id)


func remove_pack_weapons(weapon_id: int, amount: int) -> bool:
	if weapon_id <= 0 or weapon_id >= weapons.size() or amount <= 0:
		return false
	if int(weapons[weapon_id]) < amount:
		return false
	weapons[weapon_id] = int(weapons[weapon_id]) - amount
	return true


func add_pack_armor(armor_id: int, amount: int) -> void:
	if armor_id <= 0 or armor_id >= armor.size() or amount <= 0:
		return
	armor[armor_id] = mini(99, int(armor[armor_id]) + amount)
	mark_armor_known(armor_id)


func remove_pack_armor(armor_id: int, amount: int) -> bool:
	if armor_id <= 0 or armor_id >= armor.size() or amount <= 0:
		return false
	if int(armor[armor_id]) < amount:
		return false
	armor[armor_id] = int(armor[armor_id]) - amount
	return true


func party_leader_hp() -> int:
	## xu4 pc-attr 1 hp — party roster slot 0.
	return hp_of_class(party_member_at(0))


func damage_party_leader(amount: int) -> bool:
	return apply_member_damage(party_member_at(0), amount)


func member_needs_healer(slot: int, remedy: String) -> bool:
	## xu4 pc-needs? — slot is 0-based party order.
	var mid := party_member_at(slot)
	if mid < 0:
		return false
	match remedy:
		"cure":
			return status_of_class(mid) == PartyRoster.Status.POISONED or is_member_poisoned(mid)
		"fullheal", "heal":
			if is_class_dead(mid):
				return false
			return hp_of_class(mid) < max_hp_of_class(mid)
		"resurrect":
			return is_class_dead(mid)
		_:
			return false


func healer_heal_member(slot: int, remedy: String) -> bool:
	## xu4 pc-heal /magic path without VFX — HT_CURE / FULLHEAL / RESURRECT.
	var mid := party_member_at(slot)
	if mid < 0:
		return false
	match remedy:
		"cure":
			if not member_needs_healer(slot, "cure"):
				return false
			_set_poisoned(mid, false)
			if member_status[mid] == PartyRoster.Status.POISONED:
				member_status[mid] = PartyRoster.Status.OK
			return true
		"fullheal", "heal":
			if not member_needs_healer(slot, "fullheal"):
				return false
			member_hp[mid] = max_hp_of_class(mid)
			return true
		"resurrect":
			if not is_class_dead(mid):
				return false
			member_status[mid] = PartyRoster.Status.OK
			_set_poisoned(mid, false)
			if int(member_hp[mid]) <= 0:
				member_hp[mid] = 1
			return true
		_:
			return false


func apply_inn_rest_heal() -> void:
	## xu4 HT_INNHEAL — hp += 100 + (rand 0..49)*2 for living non-full members; full MP not required in DOS inn (applyRest only HP).
	for i in party_size():
		var mid := party_member_at(i)
		if mid < 0 or is_class_dead(mid):
			continue
		var hp: int = int(member_hp[mid])
		var mx: int = max_hp_of_class(mid)
		if hp >= mx:
			continue
		hp += 100 + (randi() % 50) * 2
		member_hp[mid] = mini(hp, mx)


func add_food_units(display_units: int) -> void:
	## xu4 add-items food — centi units (×100).
	if display_units <= 0:
		return
	adjust_food(display_units * 100)


func try_pay_gold(cost: int) -> bool:
	## xu4 pay primitive — false if broke (no deduct).
	if cost < 0 or gold < cost:
		return false
	adjust_gold(-cost)
	return true


func adjust_karma_bragged() -> void:
	## xu4 KA_BRAGGED — Humility −5 (not timed).
	adjust_karma_virtue(Virtues.Id.HUMILITY, -5)


func adjust_karma_humble() -> void:
	## xu4 KA_HUMBLE — Humility +10 if virtueIncreaseTimeout allows.
	if virtue_increase_timeout():
		adjust_karma_virtue(Virtues.Id.HUMILITY, 10)


func adjust_karma_meditation() -> void:
	## xu4 KA_MEDITATION / KA_HAWKWIND — Spirituality +3 if timeout allows.
	if virtue_increase_timeout():
		adjust_karma_virtue(Virtues.Id.SPIRITUALITY, 3)


func adjust_karma_bad_mantra() -> void:
	## xu4 KA_BAD_MANTRA — Spirituality −3 (not timed).
	adjust_karma_virtue(Virtues.Id.SPIRITUALITY, -3)


func attempt_elevation(virtue: int) -> bool:
	## xu4 Party::attemptElevation — karma 99 → partial Avatar (0).
	if virtue < 0 or virtue >= karma.size():
		return false
	if int(karma[virtue]) != 99:
		return false
	karma[virtue] = 0
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
		return player_display_name()
	if mid >= 0 and mid < PartyRoster.COMPANION_NAMES.size():
		return PartyRoster.companion_display_name(mid)
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


func wind_from_vec(w: int = -1) -> Vector2i:
	## Where the wind comes from (8-way). Matching top-bar Wind label.
	## 0=N 1=NE 2=E 3=SE 4=S 5=SW 6=W 7=NW
	if w < 0:
		w = wind_dir
	match posmod(w, 8):
		0:
			return Vector2i(0, -1) ## N
		1:
			return Vector2i(1, -1) ## NE
		2:
			return Vector2i(1, 0) ## E
		3:
			return Vector2i(1, 1) ## SE
		4:
			return Vector2i(0, 1) ## S
		5:
			return Vector2i(-1, 1) ## SW
		6:
			return Vector2i(-1, 0) ## W
		7:
			return Vector2i(-1, -1) ## NW
		_:
			return Vector2i(0, -1)


func balloon_drift_dir(w: int = -1) -> Vector2i:
	## xu4: move(dirReverse(windDirection)) while aloft.
	## Remake wind is 8-way (xu4 was cardinals only) — NE wind drifts SW, etc.
	## Return a full tile step including diagonal components (never collapses to one axis).
	if w < 0:
		w = wind_dir
	match posmod(w, 8):
		0:
			return Vector2i(0, 1) ## from N → drift S
		1:
			return Vector2i(-1, 1) ## from NE → drift SW
		2:
			return Vector2i(-1, 0) ## from E → drift W
		3:
			return Vector2i(-1, -1) ## from SE → drift NW
		4:
			return Vector2i(0, -1) ## from S → drift N
		5:
			return Vector2i(1, -1) ## from SW → drift NE
		6:
			return Vector2i(1, 0) ## from W → drift E
		7:
			return Vector2i(1, 1) ## from NW → drift SE
		_:
			return Vector2i(0, 1)


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


func can_advance_level(klass: int) -> bool:
	## Enough XP to gain a level at Lord British (real level lags max for XP).
	return level_of_class(klass) < max_level_for_xp(xp_of_class(klass))


func xp_min_for_level(level: int) -> int:
	## Lowest XP that counts as this real level (1 = 0, 2 = 100, then doubles).
	var lv := clampi(level, 1, 8)
	if lv <= 1:
		return 0
	return 100 << (lv - 2)


func _lowest_party_level() -> int:
	var lo := 8
	var found := false
	for i in party_order.size():
		var mid := int(party_order[i])
		if mid < 0:
			continue
		found = true
		lo = mini(lo, level_of_class(mid))
	return lo if found else 1


func _scale_companion_to_party(klass: int) -> void:
	## Join at (lowest current party level − 1), never below CLASS_START_LEVEL.
	## XP becomes the minimum for that level when raised.
	if klass < 0 or klass >= CLASS_START_LEVEL.size():
		return
	var start_lv := clampi(int(CLASS_START_LEVEL[klass]), 1, 8)
	var target := clampi(maxi(start_lv, _lowest_party_level() - 1), 1, 8)
	if target <= level_of_class(klass):
		return
	if klass < member_xp.size():
		member_xp[klass] = xp_min_for_level(target)
	if klass < member_max_hp.size():
		member_max_hp[klass] = target * 100
		member_hp[klass] = int(member_max_hp[klass])


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


func regenerate_mp() -> bool:
	## xu4 Party::endTurn MP tick — +1 if not disabled and below max.
	## Combat and explore both use this; food / poison stay explore-only.
	var changed := false
	for i in party_size():
		var mid := party_member_at(i)
		if mid < 0 or is_member_disabled(mid):
			continue
		var mx := max_mp_of_class(mid)
		if mx > 0 and mid < member_mp.size() and int(member_mp[mid]) < mx:
			member_mp[mid] = int(member_mp[mid]) + 1
			changed = true
	return changed


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


func spell_cure_member(klass: int) -> bool:
	## xu4 HT_CURE — only if getStatus() == POISONED (sleep/dead fail).
	if klass < 0 or klass >= member_status.size():
		return false
	if status_of_class(klass) != PartyRoster.Status.POISONED:
		return false
	_set_poisoned(klass, false)
	if member_status[klass] == PartyRoster.Status.POISONED:
		member_status[klass] = PartyRoster.Status.OK
	return true


func spell_heal_member(klass: int) -> bool:
	## xu4 spellHeal — always succeeds. HT_HEAL no-ops if dead or already max HP.
	## Amount: 75 + (0..255 % 25) = 75–99, then clamp to max.
	if klass < 0 or klass >= member_hp.size():
		return true
	if is_class_dead(klass):
		return true
	var hp := hp_of_class(klass)
	var mx := max_hp_of_class(klass)
	if hp >= mx:
		return true
	hp += 75 + ((randi() % 0x100) % 0x19)
	if hp > mx:
		hp = mx
	member_hp[klass] = hp
	return true


func spell_resurrect_member(klass: int) -> bool:
	## xu4 HT_RESURRECT — dead only; HP left as-is (often 0).
	if klass < 0 or klass >= member_status.size():
		return false
	if not is_class_dead(klass):
		return false
	member_status[klass] = PartyRoster.Status.OK
	_set_poisoned(klass, false)
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
	var amount := roll_chest_gold_amount()
	adjust_gold(amount)
	return amount


func roll_chest_gold_amount() -> int:
	## xu4 Party::getChest gold formula only (no apply). City / camp chests.
	## Range 10–66; E ≈ 38.
	return (randi() % 50) + (randi() % 8) + 10


func roll_combat_chest_gold_amount() -> int:
	## Per-kill combat drop (E[#chests] ≈ 1 via 1/N spawn). Mean is ~1.2× city
	## roll (≈46) so fight total tracks ~120% classic awardLoot gold; max is lower
	## than 66 so multi-chest wins do not balloon as hard. Range 32–58.
	return (randi() % 22) + (randi() % 6) + 32


## Combat chest stack kinds (Get peels from the top).
const CHEST_LOOT_GOLD := "gold"
const CHEST_LOOT_FOOD := "food"
const CHEST_LOOT_WEAPON := "weapon"
const CHEST_LOOT_ARMOR := "armor"
const CHEST_LOOT_TORCH := "torch"
const CHEST_LOOT_KEY := "key"
const CHEST_LOOT_GEM := "gem"
const CHEST_LOOT_SILK := "silk"
const CHEST_LOOT_REAGENT := "reagent"
## Staff..Halberd (exclude Hands, Magic*, Mystic).
const _CHEST_NORMAL_WEAPONS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
## Cloth..Plate (exclude Magic*, Mystic).
const _CHEST_NORMAL_ARMORS: Array[int] = [1, 2, 3, 4]
## Ash..Pearl — no Nightshade / Mandrake (mage-chest pool).
const _CHEST_MAGE_REAGENTS: Array[int] = [
	ReagentIcons.Id.SULPHUROUS_ASH,
	ReagentIcons.Id.GINSENG,
	ReagentIcons.Id.GARLIC,
	ReagentIcons.Id.SPIDER_SILK,
	ReagentIcons.Id.BLOOD_MOSS,
	ReagentIcons.Id.BLACK_PEARL,
]


func roll_combat_chest_loot(
	humanoid: bool,
	spider: bool = false,
	mage: bool = false,
	key_source: bool = false
) -> Array:
	## Always gold. Spiders: 5% silk (1–3). Mages: 5% common reagents.
	## Humanoids: food/weapons/armor/misc. Keys only from Rogue (`key_source`).
	## Stack top-first on Get.
	var pool: Array = []
	pool.append({
		"kind": CHEST_LOOT_GOLD,
		"amount": roll_combat_chest_gold_amount(),
		"id": 0,
	})
	if spider and (randi() % 100) < 5:
		pool.append({
			"kind": CHEST_LOOT_SILK,
			"amount": (randi() % 3) + 1, ## 1..3
			"id": 0,
		})
	if mage and (randi() % 100) < 5:
		for entry in _roll_mage_chest_reagents():
			pool.append(entry)
	if humanoid:
		if (randi() % 100) < 15:
			pool.append({
				"kind": CHEST_LOOT_FOOD,
				"amount": (randi() % 8) + 3, ## display food units 3..10
				"id": 0,
			})
		if (randi() % 100) < 5:
			var n_weap := 1 if (randi() % 100) < 80 else 2
			for _i in n_weap:
				var wid: int
				if mage:
					wid = WeaponIcons.Id.STAFF
				else:
					wid = _CHEST_NORMAL_WEAPONS[randi() % _CHEST_NORMAL_WEAPONS.size()]
				pool.append({"kind": CHEST_LOOT_WEAPON, "amount": 1, "id": wid})
		if (randi() % 100) < 5:
			var aid: int
			if mage:
				aid = ArmorIcons.Id.CLOTH
			else:
				aid = _CHEST_NORMAL_ARMORS[randi() % _CHEST_NORMAL_ARMORS.size()]
			pool.append({"kind": CHEST_LOOT_ARMOR, "amount": 1, "id": aid})
		if (randi() % 100) < 1:
			pool.append({"kind": CHEST_LOOT_TORCH, "amount": 1, "id": 0})
		if key_source and (randi() % 100) < 1:
			pool.append({"kind": CHEST_LOOT_KEY, "amount": 1, "id": 0})
		if (randi() % 100) < 1:
			pool.append({"kind": CHEST_LOOT_GEM, "amount": 1, "id": 0})
	## Fisher–Yates shuffle → random presentation order.
	for i in range(pool.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool


func _roll_mage_chest_reagents() -> Array:
	## 90% one kind / 10% two; each kind 75%×1 / 25%×2. Types distinct.
	var pool: Array[int] = _CHEST_MAGE_REAGENTS.duplicate()
	var n_kinds := 1 if (randi() % 100) < 90 else 2
	n_kinds = mini(n_kinds, pool.size())
	var out: Array = []
	for _i in n_kinds:
		var pick := randi() % pool.size()
		var rid := int(pool[pick])
		pool.remove_at(pick)
		var qty := 1 if (randi() % 100) < 75 else 2
		out.append({"kind": CHEST_LOOT_REAGENT, "amount": qty, "id": rid})
	return out


func apply_chest_loot_entry(entry: Dictionary) -> String:
	## Grant one stack entry; returns the player-facing Get message.
	if entry.is_empty():
		return Locale.t("cmd_chest_empty")
	var kind := str(entry.get("kind", ""))
	var amount := int(entry.get("amount", 0))
	var item_id := int(entry.get("id", 0))
	match kind:
		CHEST_LOOT_GOLD:
			var got := adjust_gold(maxi(0, amount))
			return Locale.t("cmd_chest_holds", [got if got > 0 else amount])
		CHEST_LOOT_FOOD:
			## food_display units → centi-units in Party storage.
			adjust_food(maxi(0, amount) * 100)
			return Locale.t("cmd_chest_holds_food", [amount])
		CHEST_LOOT_WEAPON:
			if item_id > 0 and item_id < weapons.size():
				weapons[item_id] = int(weapons[item_id]) + 1
				mark_weapon_known(item_id)
			return Locale.t("cmd_chest_holds_weapon", [Locale.weapon_name(item_id)])
		CHEST_LOOT_ARMOR:
			if item_id > 0 and item_id < armor.size():
				armor[item_id] = int(armor[item_id]) + 1
				mark_armor_known(item_id)
			return Locale.t("cmd_chest_holds_armor", [Locale.armor_name(item_id)])
		CHEST_LOOT_TORCH:
			torches = clampi(torches + maxi(1, amount), 0, 99)
			return Locale.t("cmd_chest_holds_torch", [amount])
		CHEST_LOOT_KEY:
			keys = clampi(keys + maxi(1, amount), 0, 99)
			return Locale.t("cmd_chest_holds_key", [amount])
		CHEST_LOOT_GEM:
			gems = clampi(gems + maxi(1, amount), 0, 99)
			return Locale.t("cmd_chest_holds_gem", [amount])
		CHEST_LOOT_SILK:
			## Spider chest bonus (gold always rolls separately).
			var n := maxi(1, amount)
			adjust_reagent(ReagentIcons.Id.SPIDER_SILK, n)
			return Locale.t("cmd_chest_holds_silk", [n])
		CHEST_LOOT_REAGENT:
			var n_r := maxi(1, amount)
			adjust_reagent(item_id, n_r)
			return Locale.t("cmd_chest_holds_reagent", [Locale.reagent_name(item_id), n_r])
		_:
			return Locale.t("cmd_chest_empty")


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


func adjust_karma_fled_evil() -> void:
	## xu4 KA_FLED_EVIL — Valor −2 (battle lost vs evil).
	adjust_karma_virtue(Virtues.Id.VALOR, -2)


func adjust_karma_healthy_fled_evil() -> void:
	## xu4 KA_HEALTHY_FLED_EVIL — Valor & Sacrifice −2 (full-HP member flees evil).
	adjust_karma_virtue(Virtues.Id.VALOR, -2)
	adjust_karma_virtue(Virtues.Id.SACRIFICE, -2)


func adjust_karma_fled_good() -> void:
	## xu4 KA_FLED_GOOD — Compassion & Justice +2 (battle lost vs good).
	adjust_karma_virtue(Virtues.Id.COMPASSION, 2)
	adjust_karma_virtue(Virtues.Id.JUSTICE, 2)


func adjust_karma_spared_good() -> void:
	## xu4 KA_SPARED_GOOD — good creature flees the arena.
	adjust_karma_virtue(Virtues.Id.COMPASSION, 2)
	adjust_karma_virtue(Virtues.Id.JUSTICE, 2)


func adjust_karma_attacked_good() -> void:
	## xu4 KA_ATTACKED_GOOD — Compassion / Justice / Honor −5 each.
	adjust_karma_virtue(Virtues.Id.COMPASSION, -5)
	adjust_karma_virtue(Virtues.Id.JUSTICE, -5)
	adjust_karma_virtue(Virtues.Id.HONOR, -5)


func adjust_karma_used_skull() -> void:
	## xu4 KA_USED_SKULL — all eight virtues −5.
	for v in range(8):
		adjust_karma_virtue(v, -5)


func adjust_karma_destroyed_skull() -> void:
	## xu4 KA_DESTROYED_SKULL — all eight virtues +10.
	for v in range(8):
		adjust_karma_virtue(v, 10)


func destroy_skull() -> void:
	## Toss into Abyss entrance — remove from inventory permanently.
	items = (items & ~ITEM_SKULL) | ITEM_SKULL_DESTROYED
	skull = 0


func try_poison_class(klass: int) -> bool:
	## Combat ranged poison field — 50% if currently healthy.
	if klass < 0 or is_class_dead(klass):
		return false
	if status_of_class(klass) == PartyRoster.Status.POISONED:
		return false
	if status_of_class(klass) == PartyRoster.Status.SLEEPING:
		return false
	if (randi() % 2) != 0:
		return false
	_set_poisoned(klass, true)
	member_status[klass] = PartyRoster.Status.POISONED
	return true


func try_sleep_class(klass: int) -> bool:
	## Combat ranged sleep / cast sleep — 50%; clears poison (field-style).
	if klass < 0 or is_member_disabled(klass):
		return false
	if (randi() % 2) != 0:
		return false
	return put_member_to_sleep(klass, true)


func lord_british_heal_party() -> void:
	## xu4 FULLHEAL under LB — HT_CURE then HT_FULLHEAL for each living member.
	for i in party_size():
		healer_heal_member(i, "cure")
		healer_heal_member(i, "fullheal")


func lord_british_check_levels() -> Array[String]:
	## xu4 gameLordBritishCheckLevels — advance any member with spare XP.
	var lines: Array[String] = []
	for i in party_size():
		var mid := party_member_at(i)
		if mid < 0:
			continue
		if level_of_class(mid) >= max_level_for_xp(xp_of_class(mid)):
			continue
		var nm := party_member_display_name(i).strip_edges()
		if nm.is_empty():
			nm = "아바타" if language == "ko" else "Adventurer"
		var new_lv := advance_level_for_class(mid)
		if new_lv > 0:
			if language == "ko":
				lines.append("%s\n이제 %d 레벨이오" % [nm, new_lv])
			elif language == "en_u4":
				lines.append("%s\nThou art now Level %d" % [nm, new_lv])
			else:
				lines.append("%s\nYou are now Level %d" % [nm, new_lv])
	return lines


func advance_level_for_class(klass: int) -> int:
	## Jump real level to max for current XP. Remake: +1..8 STR/DEX/INT
	## once per level gained (xu4 applied the bonus only once). Cap 50.
	## Returns new level, or 0 if no advance.
	if klass < 0 or klass >= member_max_hp.size():
		return 0
	var real_lv := level_of_class(klass)
	var max_lv := max_level_for_xp(xp_of_class(klass))
	if real_lv >= max_lv:
		return 0
	member_status[klass] = PartyRoster.Status.OK
	_set_poisoned(klass, false)
	member_max_hp[klass] = max_lv * 100
	member_hp[klass] = int(member_max_hp[klass])
	var steps := max_lv - real_lv
	for _i in steps:
		if klass < member_str.size():
			member_str[klass] = mini(50, int(member_str[klass]) + (randi() % 8) + 1)
		if klass < member_dex.size():
			member_dex[klass] = mini(50, int(member_dex[klass]) + (randi() % 8) + 1)
		if klass < member_int.size():
			member_int[klass] = mini(50, int(member_int[klass]) + (randi() % 8) + 1)
	if klass < member_int.size():
		## MP pool may rise with INT for caster classes.
		var mmax := max_mp_for_stats(klass, int(member_int[klass]))
		if klass < member_mp.size() and int(member_mp[klass]) > mmax:
			member_mp[klass] = mmax
	return max_lv


func award_xp_leader(amount: int) -> void:
	## xu4 PartyMember::awardXp on party member 0 (leader). Cap 9999.
	if amount <= 0:
		return
	var klass := party_leader_class()
	award_xp_class(klass, amount)


func award_xp_class(klass: int, amount: int) -> void:
	## xu4 PartyMember::awardXp for a class-indexed member. Cap 9999.
	if amount <= 0:
		return
	if klass < 0 or klass >= member_xp.size():
		return
	member_xp[klass] = mini(9999, int(member_xp[klass]) + amount)


func award_combat_kill_xp(killer_klass: int, dmg_by_klass: Dictionary, total_xp: int) -> void:
	## Killer 70%; remaining 30% split equally among all who damaged the foe
	## (killer included). Integer shares only; leftover 1s go to random members
	## so the party total never exceeds `total_xp`.
	if total_xp <= 0:
		return
	var killer_xp := (total_xp * 70) / 100
	var assist_pool := total_xp - killer_xp
	var attackers: Array[int] = []
	for k in dmg_by_klass.keys():
		var klass := int(k)
		if klass < 0 or int(dmg_by_klass[k]) <= 0:
			continue
		if not attackers.has(klass):
			attackers.append(klass)
	if killer_klass >= 0 and not attackers.has(killer_klass):
		attackers.append(killer_klass)
	var awards: Dictionary = {}
	if killer_klass >= 0 and killer_xp > 0:
		awards[killer_klass] = killer_xp
	if assist_pool > 0 and not attackers.is_empty():
		var n := attackers.size()
		var base := assist_pool / n
		var rem := assist_pool % n
		for klass in attackers:
			if base > 0:
				awards[klass] = int(awards.get(klass, 0)) + base
		if rem > 0:
			## Equal fractions (0.5 / 0.33 / 0.25…): pick rem members at random for +1.
			var picks: Array[int] = attackers.duplicate()
			for i in range(picks.size() - 1, 0, -1):
				var j := randi() % (i + 1)
				var tmp: int = picks[i]
				picks[i] = picks[j]
				picks[j] = tmp
			for i in rem:
				var klass: int = picks[i]
				awards[klass] = int(awards.get(klass, 0)) + 1
	for k in awards.keys():
		award_xp_class(int(k), int(awards[k]))


func lose_ready_weapon(klass: int) -> bool:
	## Consume a thrown/spent ready weapon.
	## Flaming Oil: qty is the inventory stack — keep oil ready while qty remains
	## after the throw; at 0 auto-switch to Hands.
	## Other lose-weapons (dagger): xu4 — spend a spare from inventory, else Hands.
	if klass < 0 or klass >= member_weapons.size():
		return false
	var wid := int(member_weapons[klass])
	if wid <= 0 or wid >= weapons.size():
		return false
	if wid == WeaponIcons.Id.FLAMING_OIL:
		if int(weapons[wid]) > 0:
			weapons[wid] = int(weapons[wid]) - 1
		if int(weapons[wid]) > 0:
			member_weapons[klass] = wid ## keep oil
			return true
		member_weapons[klass] = 0 ## Hands — flasks depleted
		return false
	if int(weapons[wid]) > 0:
		weapons[wid] = int(weapons[wid]) - 1
		return true
	member_weapons[klass] = 0 ## Hands
	return false


func adjust_karma_killed_evil() -> void:
	## xu4 KA_KILLED_EVIL — Valor +1 half the time.
	if (randi() % 2) != 0:
		adjust_karma_virtue(Virtues.Id.VALOR, 1)


func party_attack_damage(klass: int) -> int:
	## xu4 PartyMember::getDamage — random(weapon.damage + str), capped 255.
	var wid := weapon_of_class(klass)
	var max_dmg := WeaponIcons.damage_of(wid) + str_of_class(klass)
	max_dmg = mini(255, max_dmg)
	if max_dmg <= 0:
		return 0
	return randi() % max_dmg


func party_attack_roll(klass: int) -> int:
	## xu4 attackValue = random(0x100) + attackBonus (dex, or 255 if always-hit).
	var dex := dex_of_class(klass)
	var bonus := 255 if dex >= 40 else dex
	return (randi() % 0x100) + bonus


func party_attack_hits(klass: int) -> bool:
	## xu4 CombatController::attackHit vs creature defense 128.
	return party_attack_hits_defense(klass, 128)


func party_attack_hits_defense(klass: int, defense: int) -> bool:
	## xu4 attackHit with an arbitrary defense (armor for party, 128 for foes).
	return party_attack_roll(klass) > defense


func party_member_defense(klass: int) -> int:
	## xu4 PartyMember::getDefense — equipped armor defense.
	return ArmorIcons.defense_of(armor_of_class(klass))


func miss_scatter_chance(klass: int) -> float:
	## Among xu4 misses: chance the shot scatters to an adjacent tile.
	## Level 1 → 50%, level 6+ → 0% (linear); from 6 only aim-miss remains.
	var level := clampi(level_of_class(klass), 1, 8)
	if level >= 6:
		return 0.0
	return 0.5 * float(6 - level) / 5.0


func mark_lastreagent() -> void:
	## xu4: lastreagent = moves & 0xF0 after Search loot / reagent harvest.
	lastreagent = moves & 0xF0


func has_item_flag(flag: int) -> bool:
	return (items & flag) != 0


func add_item_flag(flag: int) -> void:
	## Mark used-BBC bits etc. without Search loot side effects.
	items |= flag


func set_aura(t: int, duration: int, caster: int = -1) -> void:
	## Horn stacks beside spell auras. J/P/Q: one of each type; one per caster.
	## Negate drops J/P/Q and then lasts on its own (Horn stays).
	if t == AuraType.NONE:
		clear_aura()
		return
	if duration <= 0:
		_clear_aura_type(t)
		return
	if t == AuraType.NEGATE:
		for spell_t in SPELL_AURA_TYPES:
			_clear_aura_type(spell_t)
		_aura_duration[t] = duration
		_aura_caster.erase(t)
		_aura_grace[t] = true
		return
	if _is_spell_aura(t):
		if is_aura_negate():
			return
		if caster >= 0:
			_clear_caster_spell_auras(caster)
		_aura_duration[t] = duration
		_aura_caster[t] = caster
		_aura_grace[t] = true
		return
	_aura_duration[t] = duration
	_aura_caster.erase(t)
	_aura_grace[t] = true


func clear_aura() -> void:
	_aura_duration.clear()
	_aura_caster.clear()
	_aura_grace.clear()


func is_aura(t: int) -> bool:
	return int(_aura_duration.get(t, 0)) > 0


func aura_duration_of(t: int) -> int:
	return int(_aura_duration.get(t, 0))


func aura_caster_of(t: int) -> int:
	## Class index that cast this spell aura, or −1 (Horn / expired / unknown).
	if not is_aura(t):
		return -1
	return int(_aura_caster.get(t, -1))


func is_aura_horn() -> bool:
	## Blocks humility-shrine daemon ambush while HORN lasts.
	return is_aura(AuraType.HORN)


func is_aura_negate() -> bool:
	## DOS spell_sta == 'N' — no new spells; no magic-sphere shots / sleep casts.
	return is_aura(AuraType.NEGATE)


func is_aura_jinx() -> bool:
	## Creatures may target any other creature (party or foe), not just the party.
	return is_aura(AuraType.JINX)


func is_aura_protection() -> bool:
	return is_aura(AuraType.PROTECTION)


func is_aura_quickness() -> bool:
	return is_aura(AuraType.QUICKNESS)


func is_aura_winds() -> bool:
	## Real-time lock from set_wind_from_dir — not a party-turn aura.
	return _wind_spell_left > 0.0


func set_wind_from_dir(from: Vector2i) -> bool:
	## DOS "From Dir:" — store FROM. Cardinals only (xu4 WindDir).
	var idx := -1
	if from == DIR_N:
		idx = 0
	elif from == DIR_E:
		idx = 2
	elif from == DIR_S:
		idx = 4
	elif from == DIR_W:
		idx = 6
	if idx < 0:
		return false
	wind_dir = idx
	_wind_spell_left = WIND_SPELL_SEC
	return true


func creature_hits_party_member(klass: int) -> bool:
	## DOS C_9BE5: Protection 50% force-miss, else armor vs rand(256).
	if is_aura_protection() and (randi() % 2) != 0:
		return false
	return (randi() % 0x100) > party_member_defense(klass)


func spell_aura_hud_text() -> String:
	## Sky-bar chips: "J" / "N" / "W" / "J  P  Q". Letter only — no remaining turns.
	var parts: PackedStringArray = []
	if is_aura(AuraType.JINX):
		parts.append("J")
	if is_aura(AuraType.NEGATE):
		parts.append("N")
	if is_aura(AuraType.PROTECTION):
		parts.append("P")
	if is_aura(AuraType.QUICKNESS):
		parts.append("Q")
	if is_aura_winds():
		parts.append("W")
	return "  ".join(parts)


func pass_aura_turn() -> void:
	## Once per world turn / combat party round — each active aura ticks independently.
	## Auras applied this same turn keep their full duration (10 walks / 10 rounds).
	var types: Array = _aura_duration.keys()
	for t in types:
		var kind := int(t)
		if bool(_aura_grace.get(kind, false)):
			_aura_grace.erase(kind)
			continue
		var d := int(_aura_duration[kind]) - 1
		if d <= 0:
			_clear_aura_type(kind)
		else:
			_aura_duration[kind] = d


func _is_spell_aura(t: int) -> bool:
	return t == AuraType.JINX or t == AuraType.PROTECTION or t == AuraType.QUICKNESS


func _clear_aura_type(t: int) -> void:
	_aura_duration.erase(t)
	_aura_caster.erase(t)
	_aura_grace.erase(t)


func _clear_caster_spell_auras(caster: int) -> void:
	for t in SPELL_AURA_TYPES:
		if int(_aura_caster.get(t, -1)) == caster:
			_clear_aura_type(t)


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
	_journal_mark_stone_flag(flag)


func grant_rune(flag: int) -> void:
	award_xp_leader(100)
	adjust_karma_found_item()
	runes |= flag
	mark_lastreagent()
	_journal_mark_rune_flag(flag)
	## Only players who already heard Mischief's forge clue are reminded
	## to return after finding the sacrifice rune.
	if (
		flag == RUNE_SACRIFICE
		and journal_has_id("minoc.mischief.forge-rune")
	):
		journal_try_capture("minoc", "Mischief", "RETURN")


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
	## xu4 Party::healShip — hull capped at 50 (Wheel-boosted hull is not regenerated upward).
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


func set_ship_hull(str_val: int) -> void:
	## xu4 Party::setShipHull — clamp 0..99.
	ship_hull = clampi(str_val, 0, SHIP_HULL_WHEEL)


func try_mount_wheel() -> bool:
	## xu4 useWheel: only when undamaged (exactly 50); becomes 99.
	if ship_hull != SHIP_HULL_MAX:
		return false
	set_ship_hull(SHIP_HULL_WHEEL)
	return true


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
	## xu4 gameKillParty — all members HP 0 / DEAD (death sequence follows).
	for i in party_size():
		var mid := party_member_at(i)
		if mid < 0:
			continue
		if mid < member_hp.size():
			member_hp[mid] = 0
		if mid < member_status.size():
			member_status[mid] = PartyRoster.Status.DEAD
		_set_poisoned(mid, false)


func revive_party() -> void:
	## xu4 Party::reviveParty — after death sequence at Lord British.
	## Full HP / Good; pack weapons & armor wiped; food 200.99; gold 200.
	## Equipped gear, karma, reagents, mixtures, quest items stay.
	for i in party_size():
		var mid := party_member_at(i)
		if mid < 0:
			continue
		_set_poisoned(mid, false)
		if mid < member_status.size():
			member_status[mid] = PartyRoster.Status.OK
		if mid < member_hp.size() and mid < member_max_hp.size():
			member_hp[mid] = int(member_max_hp[mid])
	for w in range(1, weapons.size()):
		weapons[w] = 0
	for a in range(1, armor.size()):
		armor[a] = 0
	food = 20099
	gold = 200
	clear_aura()


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
	## - Combat (xu4): still moves++, but no food/status. MP still ticks on wrap.
	##   Ultima4R skips moves in combat so camp heal / virtue timers stay outdoors;
	##   combat MP regen is GameState.regenerate_mp() at the party-round wrap.
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
	if regenerate_mp():
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
	var winds_was := is_aura_winds()
	if _wind_spell_left > 0.0:
		_wind_spell_left = maxf(0.0, _wind_spell_left - WORLD_TICK_SEC)
	if winds_was and not is_aura_winds():
		changed = true
	var old_wind := wind_dir
	wind_counter += 1
	if wind_counter >= PHASE_TICKS:
		wind_counter = 0
		## xu4: 25% chance to re-roll wind direction (may land on the same heading).
		if not wind_lock and not is_aura_winds() and (randi() % 4) == 1:
			wind_dir = posmod(randi(), 8)
	if wind_dir != old_wind:
		changed = true

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
		"player_name_ko": player_name_ko,
		"player_sex": player_sex,
		"player_class": player_class,
		"party_order": party_order.duplicate(),
		"start_pos": {"x": start_pos.x, "y": start_pos.y},
		"karma": karma.duplicate(),
		"food": food,
		"moves": moves,
		"lastcamp": lastcamp,
		"lastvirtue": lastvirtue,
		"lastmeditation": lastmeditation,
		"ship_hull": ship_hull,
		"gems": gems,
		"gold": gold,
		"keys": keys,
		"torches": torches,
		"skull": skull,
		"items": items,
		"stones": stones,
		"runes": runes,
		"lb_intro": lb_intro,
		"journal": journal_entries.duplicate(true),
		"journal_collapsed": journal_collapsed.duplicate(true),
		"journal_selected_id": journal_selected_id,
		"journal_unseen_id": journal_unseen_id,
		"journal_page": journal_page,
		"journal_known_virtues": journal_known_virtues,
		"journal_known_mantras": journal_known_mantras,
		"journal_known_dungeons": journal_known_dungeons,
		"talk_known_keywords": talk_known_keywords.duplicate(true),
		"talk_heard_words": talk_heard_words.duplicate(),
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
	## Legacy single-name saves: `player_name` is English; Korean left empty.
	player_name = str(d.get("player_name", player_name))
	player_name_ko = str(d.get("player_name_ko", ""))
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
	lastvirtue = int(d.get("lastvirtue", 0)) & 0xFFFF
	lastmeditation = int(d.get("lastmeditation", 0)) & 0xFFFF
	ship_hull = clampi(int(d.get("ship_hull", 0)), 0, SHIP_HULL_WHEEL)
	gems = maxi(0, int(d.get("gems", 0)))
	gold = maxi(0, int(d.get("gold", 0)))
	keys = maxi(0, int(d.get("keys", 0)))
	torches = maxi(0, int(d.get("torches", 0)))
	skull = maxi(0, int(d.get("skull", 0)))
	items = maxi(0, int(d.get("items", 0)))
	stones = maxi(0, int(d.get("stones", 0)))
	runes = maxi(0, int(d.get("runes", 0)))
	lb_intro = bool(d.get("lb_intro", false))
	journal_entries.clear()
	var journal_raw: Variant = d.get("journal", [])
	if typeof(journal_raw) == TYPE_ARRAY:
		for row in journal_raw:
			if typeof(row) == TYPE_DICTIONARY:
				journal_entries.append((row as Dictionary).duplicate(true))
	journal_collapsed.clear()
	var collapsed_raw: Variant = d.get("journal_collapsed", {})
	if typeof(collapsed_raw) == TYPE_DICTIONARY:
		for place in (collapsed_raw as Dictionary).keys():
			if bool((collapsed_raw as Dictionary)[place]):
				journal_collapsed[str(place)] = true
	elif typeof(collapsed_raw) == TYPE_ARRAY:
		for place in collapsed_raw:
			var pid := str(place).strip_edges()
			if not pid.is_empty():
				journal_collapsed[pid] = true
	journal_selected_id = str(d.get("journal_selected_id", "")).strip_edges()
	journal_unseen_id = str(d.get("journal_unseen_id", "")).strip_edges()
	journal_page = clampi(int(d.get("journal_page", 0)), 0, 1)
	journal_known_virtues = int(d.get("journal_known_virtues", 0))
	journal_known_mantras = int(d.get("journal_known_mantras", 0))
	journal_known_dungeons = int(d.get("journal_known_dungeons", 0))
	_Journal.sync_known(self)
	talk_known_keywords.clear()
	var talk_raw: Variant = d.get("talk_known_keywords", {})
	if typeof(talk_raw) == TYPE_DICTIONARY:
		for npc_id in (talk_raw as Dictionary).keys():
			var keys_v: Variant = (talk_raw as Dictionary)[npc_id]
			if typeof(keys_v) != TYPE_ARRAY:
				continue
			var keys: Array = []
			for v in keys_v:
				var s := str(v).strip_edges()
				if s.is_empty() or keys.has(s):
					continue
				keys.append(s)
			if not keys.is_empty():
				talk_known_keywords[str(npc_id)] = keys
	talk_heard_words.clear()
	var heard_raw: Variant = d.get("talk_heard_words", [])
	if typeof(heard_raw) == TYPE_ARRAY:
		for v in heard_raw:
			var hs := str(v).strip_edges()
			if hs.is_empty() or talk_heard_words.has(hs):
				continue
			talk_heard_words.append(hs)
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
	wind_counter = maxi(0, int(d.get("wind_counter", wind_counter)))
	## Coerce lock strictly — non-falsey JSON quirks must not freeze wind forever.
	wind_lock = d.get("wind_lock", false) == true
	if d.has("language"):
		## Slot language for this play session only — menu prefs stay separate.
		apply_session_language(str(d.get("language")))
	is_new_game = false
	if party_order.is_empty():
		refresh_party_order()
	## Ensure pack / equipped gear are marked (also migrates pre-known saves).
	_mark_gear_known_from_stock_and_party()
	_Journal.mark_goals_for_inventory(self)


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


func journal_try_capture(place: String, npc: String, topic: String) -> bool:
	return _Journal.try_capture(self, place, npc, topic)


func journal_try_capture_talk(place: String, npc: String, topic: String) -> bool:
	## Dialogue-only: first new note completes the Britannia talk starter.
	if not journal_try_capture(place, npc, topic):
		return false
	journal_mark_goal("talk:first-note")
	return true


func journal_has_id(id: String) -> bool:
	return _Journal.has_entry_id(self, id)


func talk_remember_keyword(npc_id: String, key: String) -> void:
	var id := npc_id.strip_edges().to_lower()
	var k := key.strip_edges()
	if id.is_empty() or k.is_empty():
		return
	var cur: Array = talk_known_keywords.get(id, [])
	if typeof(cur) != TYPE_ARRAY:
		cur = []
	if cur.has(k):
		return
	cur.append(k)
	talk_known_keywords[id] = cur


func talk_remember_heard_word(word: String) -> void:
	var k := word.strip_edges()
	if k.is_empty() or talk_heard_words.has(k):
		return
	talk_heard_words.append(k)


func talk_has_heard_word(word: String) -> bool:
	var want := word.strip_edges()
	if want.is_empty():
		return false
	if talk_heard_words.has(want):
		return true
	var low := want.to_lower()
	for raw in talk_heard_words:
		if str(raw).strip_edges().to_lower() == low:
			return true
	return false


func talk_known_keys(npc_id: String) -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = talk_known_keywords.get(npc_id.strip_edges().to_lower(), [])
	if typeof(raw) != TYPE_ARRAY:
		return out
	for v in raw:
		var s := str(v).strip_edges()
		if s.is_empty() or out.has(s):
			continue
		out.append(s)
	return out


func journal_mark_goal(goal: String) -> bool:
	return _Journal.mark_goal(self, goal)


func journal_mark_id(id: String) -> bool:
	return _Journal.mark_id(self, id)


func journal_mark_mantra(virtue: int) -> bool:
	if virtue < 0 or virtue > 7:
		return false
	_Journal.mark_known_mantra(self, virtue)
	return journal_mark_goal("mantra:%s" % Virtues.NAMES_EN[virtue].to_lower())


func _journal_mark_rune_flag(flag: int) -> void:
	for v in 8:
		if flag == (1 << v):
			_Journal.mark_known_rune(self, v)
			journal_mark_goal("rune:%s" % Virtues.NAMES_EN[v].to_lower())
			return


func _journal_mark_stone_flag(flag: int) -> void:
	const NAMES := [
		"blue", "yellow", "red", "green", "orange", "purple", "white", "black",
	]
	for i in NAMES.size():
		if flag == (1 << i):
			journal_mark_goal("stone:%s" % NAMES[i])
			return
