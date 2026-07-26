class_name SaveGame
extends RefCounted

## Ultima4R JSON save slots (remake schema — not binary PARTY.SAV).
## Files: user://saves/slot_1.json … slot_4.json
## Prefs: user://saves/prefs.json — last saved / loaded slot indices.

const VERSION := 1
const SLOT_COUNT := 4
const DIR := "user://saves"
const PREFS_PATH := "user://saves/prefs.json"


static func slot_path(slot: int) -> String:
	## slot is 1..SLOT_COUNT.
	return DIR.path_join("slot_%d.json" % clampi(slot, 1, SLOT_COUNT))


static func ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))


static func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


static func any_slot_exists() -> bool:
	for i in range(1, SLOT_COUNT + 1):
		if slot_exists(i):
			return true
	return false


static func read_meta(slot: int) -> Dictionary:
	## Slot list header. Empty dict if missing/corrupt.
	## Enriches older saves that only stored name/moves/class.
	var data := read_slot(slot)
	if data.is_empty():
		return {}
	var meta_v: Variant = data.get("meta", {})
	if typeof(meta_v) != TYPE_DICTIONARY:
		return {}
	var meta: Dictionary = (meta_v as Dictionary).duplicate()
	if not meta.has("saved_at"):
		meta["saved_at"] = str(data.get("saved_at", ""))
	meta["moves"] = int(meta.get("moves", 0))
	var game_v: Variant = data.get("game", {})
	if typeof(game_v) == TYPE_DICTIONARY:
		var game: Dictionary = game_v
		if not meta.has("player_sex"):
			meta["player_sex"] = str(game.get("player_sex", "male"))
		if not meta.has("party_order"):
			meta["party_order"] = game.get("party_order", [])
		if not meta.has("level"):
			meta["level"] = _level_from_game(game, int(meta.get("class", -1)))
	return meta


static func _level_from_game(game: Dictionary, klass: int) -> int:
	var max_hps: Variant = game.get("member_max_hp", [])
	if typeof(max_hps) == TYPE_ARRAY and klass >= 0 and klass < (max_hps as Array).size():
		return maxi(1, int((max_hps as Array)[klass]) / 100)
	return 1


static func read_slot(slot: int) -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("SaveGame: cannot read %s" % path)
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveGame: bad JSON in %s" % path)
		return {}
	return parsed as Dictionary


static func write_slot(slot: int, data: Dictionary) -> bool:
	ensure_dir()
	var path := slot_path(slot)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveGame: cannot write %s" % path)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	set_last_saved_slot(slot)
	return true


static func build_save(
	game: Dictionary,
	world: Dictionary,
	player_name: String,
	moves: int,
	klass: int
) -> Dictionary:
	var when := Time.get_datetime_string_from_system(false, true)
	var party: Array = []
	var order_v: Variant = game.get("party_order", [])
	if typeof(order_v) == TYPE_ARRAY:
		for v in order_v as Array:
			party.append(int(v))
	var level := _level_from_game(game, klass)
	return {
		"version": VERSION,
		"saved_at": when,
		"meta": {
			"player_name": player_name,
			"player_sex": str(game.get("player_sex", "male")),
			"moves": int(moves),
			"class": int(klass),
			"level": int(level),
			"party_order": party,
			"saved_at": when,
		},
		"game": game,
		"world": world,
	}


static func read_prefs() -> Dictionary:
	if not FileAccess.file_exists(PREFS_PATH):
		return {}
	var f := FileAccess.open(PREFS_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func write_prefs(prefs: Dictionary) -> void:
	ensure_dir()
	var f := FileAccess.open(PREFS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(prefs, "\t"))
	f.close()


static func last_saved_slot() -> int:
	## 1..SLOT_COUNT, or 0 if never saved / missing.
	var n := int(read_prefs().get("last_saved_slot", 0))
	if n < 1 or n > SLOT_COUNT or not slot_exists(n):
		return 0
	return n


static func set_last_saved_slot(slot: int) -> void:
	var prefs := read_prefs()
	prefs["last_saved_slot"] = clampi(slot, 1, SLOT_COUNT)
	write_prefs(prefs)


static func last_loaded_slot() -> int:
	var n := int(read_prefs().get("last_loaded_slot", 0))
	if n < 1 or n > SLOT_COUNT or not slot_exists(n):
		return 0
	return n


static func set_last_loaded_slot(slot: int) -> void:
	var prefs := read_prefs()
	prefs["last_loaded_slot"] = clampi(slot, 1, SLOT_COUNT)
	write_prefs(prefs)


static func first_empty_slot() -> int:
	## 1..SLOT_COUNT, or 0 if every slot is occupied.
	for i in range(1, SLOT_COUNT + 1):
		if not slot_exists(i):
			return i
	return 0


static func first_occupied_slot() -> int:
	for i in range(1, SLOT_COUNT + 1):
		if slot_exists(i):
			return i
	return 0


static func default_load_cursor() -> int:
	## Journey: prefer last save, else first occupied. 0-based index.
	var last := last_saved_slot()
	if last > 0:
		return last - 1
	var occ := first_occupied_slot()
	return maxi(occ - 1, 0)


static func default_save_cursor(session_loaded_slot: int, session_did_save: bool) -> int:
	## Q save default (0-based):
	## - After a save this session → last saved slot
	## - Loaded game, not yet saved → last loaded slot
	## - New game → first empty, else slot 1
	if session_did_save:
		var saved := last_saved_slot()
		if saved > 0:
			return saved - 1
	if session_loaded_slot >= 1 and session_loaded_slot <= SLOT_COUNT:
		return session_loaded_slot - 1
	var empty := first_empty_slot()
	if empty > 0:
		return empty - 1
	return 0
