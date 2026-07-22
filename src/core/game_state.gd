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
## Party inventory counts (xu4 SaveGame arrays).
var weapons: Array[int] = [] ## 16 — WEAP_HANDS..MYSTIC_SWORD
var armor: Array[int] = [] ## 8 — ARMR_NONE..MYSTIC_ROBE
var reagents: Array[int] = [] ## 8
var mixtures: Array[int] = [] ## 26 — spells A..Z
var is_new_game: bool = false
var u4_data_ok: bool = false
var intro_data := TitleExeData.new()
var intro_overlay := IntroTextOverlay.new()


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
	_reset_inventory_stubs()
	refresh_party_order()


func _reset_inventory_stubs() -> void:
	## Full demo stock so Ztats pages can review every name translation.
	weapons.clear()
	weapons.resize(16)
	weapons[0] = 0 ## Hands — not listed
	for i in range(1, 16):
		weapons[i] = 1

	armor.clear()
	armor.resize(8)
	armor[0] = 0 ## No Armor — not listed
	for i in range(1, 8):
		armor[i] = 1

	reagents.clear()
	reagents.resize(8)
	for i in 8:
		reagents[i] = 8 - i

	mixtures.clear()
	mixtures.resize(26)
	for i in 26:
		mixtures[i] = 1


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
