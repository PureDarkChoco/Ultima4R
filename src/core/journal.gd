class_name Journal
extends RefCounted

## Catalog-driven travel journal. Runtime rows live on GameState.journal_entries.

const CATALOG_PATH := "res://assets/locale/journal/entries.json"
const _TalkLocale := preload("res://src/core/talk_locale.gd")
const _TalkTlk := preload("res://src/core/talk_tlk.gd")
const _WorldPortals := preload("res://src/map/world_portals.gd")
const _Virtues := preload("res://src/core/virtues.gd")

static var _catalog: Array = []
static var _loaded := false


static func ensure_catalog() -> void:
	if _loaded:
		return
	_loaded = true
	_catalog.clear()
	if not FileAccess.file_exists(CATALOG_PATH):
		return
	var raw := FileAccess.get_file_as_string(CATALOG_PATH)
	if raw.is_empty():
		return
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Journal: bad catalog JSON")
		return
	var items: Variant = (data as Dictionary).get("entries", [])
	if typeof(items) != TYPE_ARRAY:
		return
	for item in items:
		if typeof(item) == TYPE_DICTIONARY:
			_catalog.append(item)


static func reload_catalog() -> void:
	_loaded = false
	ensure_catalog()


static func has_entry_id(gs: Node, id: String) -> bool:
	if gs == null or id.is_empty():
		return false
	for row in gs.journal_entries:
		if typeof(row) == TYPE_DICTIONARY and str(row.get("id", "")) == id:
			return true
	return false


static func find_catalog(place: String, npc: String, topic: String) -> Dictionary:
	ensure_catalog()
	var p := place.strip_edges().to_lower()
	var n := npc.strip_edges().to_lower()
	var t := topic.strip_edges().to_upper()
	if p.is_empty() or n.is_empty() or t.is_empty():
		return {}
	for item in _catalog:
		var d: Dictionary = item
		if str(d.get("place", "")).strip_edges().to_lower() != p:
			continue
		if str(d.get("npc", "")).strip_edges().to_lower() != n:
			continue
		if str(d.get("topic", "")).strip_edges().to_upper() != t:
			continue
		return d
	return {}


static func find_catalog_by_id(id: String) -> Dictionary:
	ensure_catalog()
	var want := id.strip_edges()
	if want.is_empty():
		return {}
	for item in _catalog:
		var d: Dictionary = item
		if str(d.get("id", "")).strip_edges() == want:
			return d
	return {}


static func try_capture(gs: Node, place: String, npc: String, topic: String) -> bool:
	## Add a catalog hit to GameState if not already recorded. Returns true when new.
	if gs == null:
		return false
	var cat := find_catalog(place, npc, topic)
	if cat.is_empty():
		return false
	var id := str(cat.get("id", "")).strip_edges()
	if id.is_empty():
		id = "%s.%s.%s" % [
			place.strip_edges().to_lower(),
			npc.strip_edges().to_lower(),
			topic.strip_edges().to_lower(),
		]
	var rows: Array = gs.journal_entries
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY and str(row.get("id", "")) == id:
			return false
	var goal := str(cat.get("goal", "")).strip_edges()
	var complete_on_goal := str(cat.get("complete_on_goal", "")).strip_edges()
	var done := (
		goal.is_empty()
		or goal_already_met(gs, goal)
		or (
			not complete_on_goal.is_empty()
			and goal_already_met(gs, complete_on_goal)
		)
		or _catalog_completion_recorded(gs, cat)
	)
	var speaker_en := npc.strip_edges()
	var speaker_ko := speaker_en
	## Prefer city pack name translation when Korean talk data is loaded.
	_TalkLocale.ensure_city(place.strip_edges().to_lower())
	var translated := _TalkLocale.line(speaker_en)
	if not translated.is_empty() and translated != speaker_en:
		speaker_ko = translated
	var entry := {
		"id": id,
		"place": place.strip_edges().to_lower(),
		"npc": npc.strip_edges(),
		"speaker_en": speaker_en,
		"speaker_ko": speaker_ko,
		"en": str(cat.get("en", "")),
		"ko": str(cat.get("ko", "")),
		"at": int(Time.get_unix_time_from_system()),
		"done": done,
		"goal": goal,
		"chain": str(cat.get("chain", "")).strip_edges(),
		"chain_order": int(cat.get("chain_order", 0)),
	}
	_insert_in_chain_order(rows, entry)
	gs.journal_entries = rows
	return true


static func _insert_in_chain_order(rows: Array, entry: Dictionary) -> void:
	## A late-discovered earlier clue is inserted before known later clues.
	## Unheard links are never synthesized.
	var chain := str(entry.get("chain", "")).strip_edges()
	if chain.is_empty():
		rows.append(entry)
		return
	var order := int(entry.get("chain_order", 0))
	for i in rows.size():
		var row: Variant = rows[i]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		var row_chain := str(d.get("chain", "")).strip_edges()
		var row_order := int(d.get("chain_order", 0))
		## Older saves may not contain chain metadata; recover it from catalog.
		if row_chain.is_empty():
			var old_cat := find_catalog_by_id(str(d.get("id", "")))
			row_chain = str(old_cat.get("chain", "")).strip_edges()
			row_order = int(old_cat.get("chain_order", 0))
		if row_chain == chain and row_order > order:
			rows.insert(i, entry)
			return
	rows.append(entry)


static func _catalog_completion_recorded(gs: Node, cat: Dictionary) -> bool:
	var raw: Variant = cat.get("complete_if_recorded", "")
	if typeof(raw) == TYPE_ARRAY:
		for id in raw:
			if has_entry_id(gs, str(id)):
				return true
		return false
	var id := str(raw).strip_edges()
	return not id.is_empty() and has_entry_id(gs, id)


static func mark_goal(gs: Node, goal: String) -> bool:
	if gs == null:
		return false
	var g := goal.strip_edges()
	if g.is_empty():
		return false
	var changed := false
	var rows: Array = gs.journal_entries
	for i in rows.size():
		var row: Variant = rows[i]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		var completes_on := str(d.get("complete_on_goal", "")).strip_edges()
		if completes_on.is_empty():
			var cat := find_catalog_by_id(str(d.get("id", "")))
			completes_on = str(cat.get("complete_on_goal", "")).strip_edges()
		if str(d.get("goal", "")) != g and completes_on != g:
			continue
		if bool(d.get("done", false)):
			continue
		d["done"] = true
		rows[i] = d
		changed = true
	if changed:
		gs.journal_entries = rows
	return changed


static func mark_id(gs: Node, id: String) -> bool:
	## Complete a journal row by catalog id (talk-chain advances).
	if gs == null:
		return false
	var want := id.strip_edges()
	if want.is_empty():
		return false
	var changed := false
	var rows: Array = gs.journal_entries
	for i in rows.size():
		var row: Variant = rows[i]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		if str(d.get("id", "")) != want:
			continue
		if bool(d.get("done", false)):
			return false
		d["done"] = true
		rows[i] = d
		changed = true
		break
	if changed:
		gs.journal_entries = rows
	return changed


static func mark_goals_for_inventory(gs: Node) -> bool:
	## After load / loot: complete any pending goals already satisfied.
	if gs == null:
		return false
	var changed := false
	var rows: Array = gs.journal_entries
	for i in rows.size():
		var row: Variant = rows[i]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		if bool(d.get("done", false)):
			continue
		var goal := str(d.get("goal", ""))
		var met := not goal.is_empty() and goal_already_met(gs, goal)
		var cat := find_catalog_by_id(str(d.get("id", "")))
		var complete_on_goal := str(cat.get("complete_on_goal", "")).strip_edges()
		if not complete_on_goal.is_empty() and goal_already_met(gs, complete_on_goal):
			met = true
		if _catalog_completion_recorded(gs, cat):
			met = true
		if not met:
			continue
		d["done"] = true
		rows[i] = d
		changed = true
	if changed:
		gs.journal_entries = rows
	return changed


static func goal_already_met(gs: Node, goal: String) -> bool:
	var g := goal.strip_edges().to_lower()
	if g.is_empty() or gs == null:
		return false
	if g.begins_with("rune:"):
		var v := _virtue_from_token(g.substr(5))
		return v >= 0 and gs.has_rune(1 << v)
	if g.begins_with("stone:"):
		var flag := _stone_flag_from_token(g.substr(6))
		return flag != 0 and gs.has_stone(flag)
	## mantra:* is only completed by shrine success (not inventory).
	return false


static func topic_for_reply_kind(entry: Variant, kind: int) -> String:
	## Map TalkTlk reply kind → catalog topic stem.
	if entry == null:
		return ""
	match kind:
		_TalkTlk.REPLY_TOPIC1:
			return str(entry.topic1).strip_edges().to_upper()
		_TalkTlk.REPLY_TOPIC2:
			return str(entry.topic2).strip_edges().to_upper()
		_TalkTlk.REPLY_JOB:
			return "JOB"
		_TalkTlk.REPLY_HEALTH:
			return "HEAL"
		_:
			return ""


static func place_order() -> Array[String]:
	return _WorldPortals.journal_place_order()


static func grouped_for_ui(gs: Node) -> Array[Dictionary]:
	## [{ "place": id, "entries": [row,…] }, …] — connected chains stay together.
	var out: Array[Dictionary] = []
	if gs == null:
		return out
	var by_place: Dictionary = {}
	for row in gs.journal_entries:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		var place := str(d.get("place", ""))
		if place.is_empty():
			continue
		if not by_place.has(place):
			by_place[place] = []
		(by_place[place] as Array).append(d)
	for place in place_order():
		if not by_place.has(place):
			continue
		out.append({
			"place": place,
			"entries": _rows_with_chains_grouped(by_place[place] as Array),
		})
	## Any unexpected place ids last (still chronological within).
	for place in by_place.keys():
		var known := false
		for p in place_order():
			if p == place:
				known = true
				break
		if known:
			continue
		out.append({
			"place": str(place),
			"entries": _rows_with_chains_grouped(by_place[place] as Array),
		})
	return out


static func entry_chain(row: Dictionary) -> String:
	var chain := str(row.get("chain", "")).strip_edges()
	if not chain.is_empty():
		return chain
	var cat := find_catalog_by_id(str(row.get("id", "")))
	return str(cat.get("chain", "")).strip_edges()


static func entry_chain_order(row: Dictionary) -> int:
	if row.has("chain_order"):
		return int(row.get("chain_order", 0))
	var cat := find_catalog_by_id(str(row.get("id", "")))
	return int(cat.get("chain_order", 0))


static func _rows_with_chains_grouped(rows: Array) -> Array:
	## Put every known link next to the first recorded link. Missing links remain absent.
	var chains: Dictionary = {}
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		var chain := entry_chain(d)
		if chain.is_empty():
			continue
		if not chains.has(chain):
			chains[chain] = []
		(chains[chain] as Array).append(d)
	for chain in chains:
		(chains[chain] as Array).sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return entry_chain_order(a) < entry_chain_order(b)
		)
	var out: Array = []
	var emitted: Dictionary = {}
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		var chain := entry_chain(d)
		if chain.is_empty():
			out.append(d)
			continue
		if emitted.has(chain):
			continue
		out.append_array(chains[chain] as Array)
		emitted[chain] = true
	return out


static func entry_text(row: Dictionary, lang: String) -> String:
	## Catalog wording is authoritative so corrected clues also update old saves.
	var cat := find_catalog_by_id(str(row.get("id", "")))
	if lang == "ko":
		var ko := str(cat.get("ko", row.get("ko", ""))).strip_edges()
		if not ko.is_empty():
			return ko
	var en := str(cat.get("en", row.get("en", ""))).strip_edges()
	if not en.is_empty():
		return en
	return str(cat.get("ko", row.get("ko", "")))


static func entry_speaker(row: Dictionary, lang: String) -> String:
	if lang == "ko":
		var ko := str(row.get("speaker_ko", "")).strip_edges()
		if not ko.is_empty():
			return ko
	return str(row.get("speaker_en", row.get("npc", "")))


static func format_time(unix_at: int) -> String:
	if unix_at <= 0:
		return ""
	var dt := Time.get_datetime_dict_from_unix_time(unix_at)
	return "%04d-%02d-%02d %02d:%02d" % [
		int(dt.get("year", 0)),
		int(dt.get("month", 0)),
		int(dt.get("day", 0)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0)),
	]


static func _virtue_from_token(token: String) -> int:
	var t := token.strip_edges().to_lower()
	match t:
		"honesty", "0":
			return _Virtues.Id.HONESTY
		"compassion", "1":
			return _Virtues.Id.COMPASSION
		"valor", "2":
			return _Virtues.Id.VALOR
		"justice", "3":
			return _Virtues.Id.JUSTICE
		"sacrifice", "4":
			return _Virtues.Id.SACRIFICE
		"honor", "5":
			return _Virtues.Id.HONOR
		"spirituality", "6":
			return _Virtues.Id.SPIRITUALITY
		"humility", "7":
			return _Virtues.Id.HUMILITY
		_:
			return -1


static func _stone_flag_from_token(token: String) -> int:
	## Matches GameState.STONE_* bitflags.
	match token.strip_edges().to_lower():
		"blue":
			return 0x01
		"yellow":
			return 0x02
		"red":
			return 0x04
		"green":
			return 0x08
		"orange":
			return 0x10
		"purple":
			return 0x20
		"white":
			return 0x40
		"black":
			return 0x80
		_:
			return 0
