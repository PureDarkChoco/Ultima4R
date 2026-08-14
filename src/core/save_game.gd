class_name SaveGame
extends RefCounted

## Ultima4R JSON save slots (remake schema — not binary PARTY.SAV).
## Files: user://saves/slot_1.json … slot_4.json
## Prefs: user://saves/prefs.json — last saved / loaded slot indices.

const VERSION := 1
const SLOT_COUNT := 4
const DIR := "user://saves"
const PREFS_PATH := "user://saves/prefs.json"
const _WorldPortals := preload("res://src/map/world_portals.gd")


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
	## Older city saves: synthesize a minimal location from world block.
	if not meta.has("location"):
		var world_v: Variant = data.get("world", {})
		if typeof(world_v) == TYPE_DICTIONARY:
			var loc := location_from_world_fallback(world_v as Dictionary)
			if not loc.is_empty():
				meta["location"] = loc
	return meta


static func _level_from_game(game: Dictionary, klass: int) -> int:
	var max_hps: Variant = game.get("member_max_hp", [])
	if typeof(max_hps) == TYPE_ARRAY and klass >= 0 and klass < (max_hps as Array).size():
		return maxi(1, int((max_hps as Array)[klass]) / 100)
	return 1


static func format_saved_at_now() -> String:
	## Local datetime without seconds: YYYY-MM-DD HH:MM
	var dt := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d" % [
		int(dt.get("year", 0)),
		int(dt.get("month", 0)),
		int(dt.get("day", 0)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0)),
	]


static func format_saved_at_display(when: String) -> String:
	## Strip seconds from ISO / spaced timestamps for the slot list.
	var s := when.strip_edges()
	if s.is_empty():
		return ""
	## 2026-07-26T17:15:30 → 2026-07-26 17:15
	s = s.replace("T", " ")
	var parts := s.split(" ")
	if parts.size() >= 2:
		var clock := parts[1]
		var hm := clock.split(":")
		if hm.size() >= 2:
			return "%s %s:%s" % [parts[0], hm[0], hm[1]]
	return s


static func location_from_world_fallback(world: Dictionary) -> Dictionary:
	## Best-effort for pre-location saves that already have in_city / city_fname.
	if not bool(world.get("in_city", false)):
		return {}
	var fname := str(world.get("city_fname", ""))
	var place := ""
	if not fname.is_empty():
		place = _WorldPortals.place_id_for_portal({"fname": fname})
	if place.is_empty():
		return {}
	return {"kind": "in", "place": place}


static func format_location(loc: Variant) -> String:
	## Render save meta.location for the current language.
	if typeof(loc) != TYPE_DICTIONARY:
		return ""
	var d: Dictionary = loc
	var kind := str(d.get("kind", ""))
	match kind:
		"in":
			return Locale.t("save_loc_in", [_place_display_name(str(d.get("place", "")))])
		"near":
			return Locale.t("save_loc_near", [_place_display_name(str(d.get("place", "")))])
		"dungeon":
			return Locale.t("save_loc_dungeon", [
				_place_display_name(str(d.get("place", ""))),
				str(maxi(1, int(d.get("level", 1)))),
			])
		"sea":
			return Locale.t("save_loc_sea")
		"britannia", "land":
			return Locale.t("save_loc_britannia")
		_:
			return ""


static func _place_display_name(place_id: String) -> String:
	if place_id.is_empty():
		return "?"
	var labeled := Locale.place(place_id)
	## Locale.t returns the key itself when missing — fall back to title case id.
	if labeled.is_empty() or labeled == "place_%s" % place_id:
		return place_id.capitalize()
	return labeled


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


static func delete_slot(slot: int) -> bool:
	## Remove slot_N.json. Clears prefs pointers if they pointed at this slot.
	if slot < 1 or slot > SLOT_COUNT:
		return false
	if not slot_exists(slot):
		return false
	var path := slot_path(slot)
	var abs_path := ProjectSettings.globalize_path(path)
	var err := DirAccess.remove_absolute(abs_path)
	if err != OK:
		push_warning("SaveGame: cannot delete %s (err %d)" % [path, err])
		return false
	var prefs := read_prefs()
	var dirty := false
	if int(prefs.get("last_saved_slot", 0)) == slot:
		prefs["last_saved_slot"] = 0
		dirty = true
	if int(prefs.get("last_loaded_slot", 0)) == slot:
		prefs["last_loaded_slot"] = 0
		dirty = true
	if dirty:
		write_prefs(prefs)
	return true


static func build_save(
	game: Dictionary,
	world: Dictionary,
	player_name: String,
	moves: int,
	klass: int,
	location: Dictionary = {}
) -> Dictionary:
	var when := format_saved_at_now()
	var party: Array = []
	var order_v: Variant = game.get("party_order", [])
	if typeof(order_v) == TYPE_ARRAY:
		for v in order_v as Array:
			party.append(int(v))
	var level := _level_from_game(game, klass)
	var meta := {
		"player_name": player_name,
		"player_name_ko": str(game.get("player_name_ko", "")),
		"player_sex": str(game.get("player_sex", "male")),
		"moves": int(moves),
		"class": int(klass),
		"level": int(level),
		"party_order": party,
		"saved_at": when,
		"language": str(game.get("language", "en_us")),
	}
	if not location.is_empty():
		meta["location"] = location.duplicate()
	return {
		"version": VERSION,
		"saved_at": when,
		"meta": meta,
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


static func default_load_cursor(session_loaded_slot: int = 0) -> int:
	## 0-based index. In-game Load: prefer the slot this session was loaded from
	## (or last saved into). Journey / no session: last save, else first occupied.
	if session_loaded_slot >= 1 and session_loaded_slot <= SLOT_COUNT:
		if slot_exists(session_loaded_slot):
			return session_loaded_slot - 1
	var last := last_saved_slot()
	if last > 0:
		return last - 1
	var occ := first_occupied_slot()
	return maxi(occ - 1, 0)


static func default_save_cursor(
	session_loaded_slot: int,
	session_did_save: bool,
	is_new_game: bool = false
) -> int:
	## Q save default (0-based):
	## - New game, not yet saved this run → first empty slot; if full → top (0)
	## - After a save this session → bound session slot (then prefs last-saved)
	## - Loaded game, not yet saved → last loaded slot
	if is_new_game and not session_did_save:
		var empty_new := first_empty_slot()
		if empty_new > 0:
			return empty_new - 1
		return 0
	if session_did_save:
		if session_loaded_slot >= 1 and session_loaded_slot <= SLOT_COUNT:
			return session_loaded_slot - 1
		var saved := last_saved_slot()
		if saved > 0:
			return saved - 1
	if session_loaded_slot >= 1 and session_loaded_slot <= SLOT_COUNT:
		return session_loaded_slot - 1
	var empty := first_empty_slot()
	if empty > 0:
		return empty - 1
	return 0
