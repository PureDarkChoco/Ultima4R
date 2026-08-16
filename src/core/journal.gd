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


static func seed_new_game(gs: Node) -> void:
	## Starter Britannia goals for a freshly created party.
	if gs == null:
		return
	ensure_catalog()
	const IDS: Array[String] = [
		"britannia.start.talk",
		"britannia.start.combat",
		"britannia.start.companions",
	]
	for id in IDS:
		var cat := find_catalog_by_id(id)
		if cat.is_empty():
			continue
		_append_catalog_capture(
			gs, cat, "britannia", str(cat.get("npc", "The Quest of the Avatar")), false
		)


static func try_capture(gs: Node, place: String, npc: String, topic: String) -> bool:
	## Add every matching catalog row (e.g. Zorin Yes → three Antos tips). Returns true if any new.
	if gs == null:
		return false
	ensure_catalog()
	var p := place.strip_edges().to_lower()
	var n := npc.strip_edges().to_lower()
	var t := topic.strip_edges().to_upper()
	if p.is_empty() or n.is_empty() or t.is_empty():
		return false
	var matches: Array = []
	for item in _catalog:
		var d: Dictionary = item
		if str(d.get("place", "")).strip_edges().to_lower() != p:
			continue
		if str(d.get("npc", "")).strip_edges().to_lower() != n:
			continue
		if str(d.get("topic", "")).strip_edges().to_upper() != t:
			continue
		matches.append(d)
	if matches.is_empty():
		return false
	var any := false
	for cat_v in matches:
		if _append_catalog_capture(gs, cat_v as Dictionary, place, npc):
			any = true
	return any


static func _append_catalog_capture(
	gs: Node, cat: Dictionary, place: String, npc: String, note_new: bool = true
) -> bool:
	var id := str(cat.get("id", "")).strip_edges()
	if id.is_empty():
		id = "%s.%s.%s" % [
			place.strip_edges().to_lower(),
			npc.strip_edges().to_lower(),
			str(cat.get("topic", "")).strip_edges().to_lower(),
		]
	## Same id + upgrade: expand an existing clue in place (e.g. Tyrone stone → use).
	if bool(cat.get("upgrade", false)):
		return _upgrade_catalog_capture(gs, cat, place, npc, id)
	if has_entry_id(gs, id):
		return false
	if _catalog_skip_if_recorded(gs, cat):
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
	var speakers := _catalog_speakers(cat, place, npc)
	var entry := {
		"id": id,
		"place": place.strip_edges().to_lower(),
		"npc": npc.strip_edges(),
		"speaker_en": speakers[0],
		"speaker_ko": speakers[1],
		"en": str(cat.get("en", "")),
		"ko": str(cat.get("ko", "")),
		"at": int(Time.get_unix_time_from_system()),
		"done": done,
		"goal": goal,
		"chain": str(cat.get("chain", "")).strip_edges(),
		"chain_order": int(cat.get("chain_order", 0)),
		"upgraded": false,
	}
	var rows: Array = gs.journal_entries
	_insert_in_chain_order(rows, entry)
	gs.journal_entries = rows
	_apply_know(gs, cat.get("know", ""))
	if note_new:
		_note_new_entry(gs, id, place)
	return true


static func _upgrade_catalog_capture(
	gs: Node, cat: Dictionary, place: String, npc: String, id: String
) -> bool:
	## Mark an existing row upgraded, or insert already-upgraded if missing.
	var rows: Array = gs.journal_entries
	for i in rows.size():
		var row: Variant = rows[i]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		if str(d.get("id", "")).strip_edges() != id:
			continue
		if bool(d.get("upgraded", false)):
			return false
		d["upgraded"] = true
		d["en"] = str(cat.get("en", d.get("en", "")))
		d["ko"] = str(cat.get("ko", d.get("ko", "")))
		rows[i] = d
		gs.journal_entries = rows
		return true
	## Heard the later tip first — record the expanded clue directly.
	var base := find_catalog_by_id(id)
	var goal := str(cat.get("goal", base.get("goal", ""))).strip_edges()
	var complete_on_goal := str(cat.get("complete_on_goal", base.get("complete_on_goal", ""))).strip_edges()
	var done := (
		goal.is_empty()
		or goal_already_met(gs, goal)
		or (
			not complete_on_goal.is_empty()
			and goal_already_met(gs, complete_on_goal)
		)
		or _catalog_completion_recorded(gs, cat)
		or _catalog_completion_recorded(gs, base)
	)
	var speakers := _catalog_speakers(cat if not cat.is_empty() else base, place, npc)
	var entry := {
		"id": id,
		"place": place.strip_edges().to_lower(),
		"npc": npc.strip_edges(),
		"speaker_en": speakers[0],
		"speaker_ko": speakers[1],
		"en": str(cat.get("en", "")),
		"ko": str(cat.get("ko", "")),
		"at": int(Time.get_unix_time_from_system()),
		"done": done,
		"goal": goal,
		"chain": str(cat.get("chain", base.get("chain", ""))).strip_edges(),
		"chain_order": int(cat.get("chain_order", base.get("chain_order", 0))),
		"upgraded": true,
	}
	_insert_in_chain_order(rows, entry)
	gs.journal_entries = rows
	_note_new_entry(gs, id, place)
	return true


static func _note_new_entry(gs: Node, id: String, place: String) -> void:
	## Remember the new row for the next journal open, and uncollapse its city.
	if gs == null:
		return
	var nid := id.strip_edges()
	if nid.is_empty():
		return
	gs.journal_unseen_id = nid
	gs.journal_page = 0
	var p := place.strip_edges().to_lower()
	if p.is_empty() or typeof(gs.journal_collapsed) != TYPE_DICTIONARY:
		return
	var cur: Dictionary = (gs.journal_collapsed as Dictionary).duplicate()
	if not cur.has(p):
		return
	cur.erase(p)
	gs.journal_collapsed = cur


static func _catalog_speakers(cat: Dictionary, place: String, npc: String) -> Array:
	var speaker_en := str(cat.get("speaker_en", "")).strip_edges()
	var speaker_ko := str(cat.get("speaker_ko", "")).strip_edges()
	if speaker_en.is_empty():
		speaker_en = npc.strip_edges()
	if speaker_ko.is_empty():
		speaker_ko = speaker_en
		_TalkLocale.ensure_city(place.strip_edges().to_lower())
		var translated := _TalkLocale.line(speaker_en)
		if not translated.is_empty() and translated != speaker_en:
			speaker_ko = translated
	return [speaker_en, speaker_ko]


static func _insert_in_chain_order(rows: Array, entry: Dictionary) -> void:
	## A late-discovered earlier clue is inserted before known later clues.
	## Chains are place-local; unheard links are never synthesized.
	var chain := entry_chain(entry)
	if chain.is_empty():
		rows.append(entry)
		return
	var place := str(entry.get("place", "")).strip_edges().to_lower()
	var order := entry_chain_order(entry)
	for i in rows.size():
		var row: Variant = rows[i]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		var row_place := str(d.get("place", "")).strip_edges().to_lower()
		if row_place != place:
			continue
		if entry_chain(d) == chain and entry_chain_order(d) > order:
			rows.insert(i, entry)
			return
	rows.append(entry)


static func _catalog_skip_if_recorded(gs: Node, cat: Dictionary) -> bool:
	## Same fact from another speaker — do not add a second identical row.
	var raw: Variant = cat.get("skip_if_recorded", "")
	if typeof(raw) == TYPE_ARRAY:
		for sid in raw:
			if has_entry_id(gs, str(sid)):
				return true
		return false
	var sid := str(raw).strip_edges()
	return not sid.is_empty() and has_entry_id(gs, sid)


static func _catalog_has_complete_if_recorded(cat: Dictionary) -> bool:
	var raw: Variant = cat.get("complete_if_recorded", "")
	if typeof(raw) == TYPE_ARRAY:
		return not raw.is_empty()
	return not str(raw).strip_edges().is_empty()


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
		var goal := str(d.get("goal", ""))
		var met := not goal.is_empty() and goal_already_met(gs, goal)
		var cat := find_catalog_by_id(str(d.get("id", "")))
		## Catalog now treats this as knowledge (complete on record).
		if not cat.is_empty() and str(cat.get("goal", "")).strip_edges().is_empty():
			met = true
		var complete_on_goal := str(cat.get("complete_on_goal", "")).strip_edges()
		if not complete_on_goal.is_empty() and goal_already_met(gs, complete_on_goal):
			met = true
		if _catalog_completion_recorded(gs, cat):
			met = true
		if met:
			if not bool(d.get("done", false)):
				d["done"] = true
				rows[i] = d
				changed = true
			continue
		if _reconcile_pending_action_goal(gs, d, cat):
			rows[i] = d
			changed = true
	if changed:
		gs.journal_entries = rows
	return changed


static func _reconcile_pending_action_goal(gs: Node, row: Dictionary, cat: Dictionary) -> bool:
	## Search / ask tips must stay pending until the action. Old complete-on-record
	## rows (empty stored goal) are migrated to the catalog goal.
	if cat.is_empty():
		return false
	var catalog_goal := str(cat.get("goal", "")).strip_edges()
	var complete_on_goal := str(cat.get("complete_on_goal", "")).strip_edges()
	var old_goal := str(row.get("goal", "")).strip_edges()
	var changed := false
	if old_goal != catalog_goal:
		row["goal"] = catalog_goal
		changed = true
	var inventory_done := (
		(not catalog_goal.is_empty() and goal_already_met(gs, catalog_goal))
		or (not complete_on_goal.is_empty() and goal_already_met(gs, complete_on_goal))
		or _catalog_completion_recorded(gs, cat)
	)
	if (
		catalog_goal.begins_with("rune:")
		or catalog_goal.begins_with("stone:")
	):
		if bool(row.get("done", false)) != inventory_done:
			row["done"] = inventory_done
			return true
		return changed
	if catalog_goal.begins_with("ask:"):
		if inventory_done and not bool(row.get("done", false)):
			row["done"] = true
			return true
		## Heard-as-complete (no stored goal) → pending until the ask / item.
		if old_goal.is_empty() and bool(row.get("done", false)) and not inventory_done:
			row["done"] = false
			return true
		## Follow-up talk is the real ask. After dropping a rune/item
		## complete_on_goal, reopen until that conversation is recorded.
		if (
			bool(row.get("done", false))
			and not inventory_done
			and complete_on_goal.is_empty()
			and _catalog_has_complete_if_recorded(cat)
		):
			row["done"] = false
			return true
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
	if g == "key:courage":
		## Courage altar stones used → third part of the key.
		return gs.has_item_flag(gs.ITEM_KEY_C)
	if g == "companions:7":
		## Avatar + 7 companions.
		return gs.party_size() >= 8
	if g == "join:jaana":
		## Recruited Jaana. Same-class refusal is marked at the join attempt.
		return gs.is_person_joined("Jaana")
	if g == "item:sextant" or g == "sextant":
		return bool(gs.has_sextant)
	## talk:first-note / combat:first / shrine:* complete only when the event fires.
	## mantra:* is a shrine fallback for ask-tips (complete_on_goal), not a pending knowledge goal.
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


static func latest_id_for_place(gs: Node, place: String) -> String:
	## Most recently acquired row for a settlement (highest `at`, then later in list).
	if gs == null:
		return ""
	var want := place.strip_edges().to_lower()
	if want.is_empty():
		return ""
	var best_id := ""
	var best_at := -1
	for row in gs.journal_entries:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		if str(d.get("place", "")).strip_edges().to_lower() != want:
			continue
		var id := str(d.get("id", "")).strip_edges()
		if id.is_empty():
			continue
		var at := int(d.get("at", 0))
		if at >= best_at:
			best_at = at
			best_id = id
	return best_id


static func last_acquired_id(gs: Node) -> String:
	if gs == null:
		return ""
	var best_id := ""
	var best_at := -1
	for row in gs.journal_entries:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		var id := str(d.get("id", "")).strip_edges()
		if id.is_empty():
			continue
		var at := int(d.get("at", 0))
		if at >= best_at:
			best_at = at
			best_id = id
	return best_id


static func place_for_entry_id(gs: Node, id: String) -> String:
	if gs == null or id.strip_edges().is_empty():
		return ""
	var want := id.strip_edges()
	for row in gs.journal_entries:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		if str(d.get("id", "")).strip_edges() == want:
			return str(d.get("place", "")).strip_edges().to_lower()
	return ""


static func entry_chain(row: Dictionary) -> String:
	## Catalog is authoritative so renamed local chains also update old saves.
	var cat := find_catalog_by_id(str(row.get("id", "")))
	if not cat.is_empty():
		return str(cat.get("chain", "")).strip_edges()
	return str(row.get("chain", "")).strip_edges()


static func entry_chain_order(row: Dictionary) -> int:
	## Catalog is authoritative so reordered local chains also update old saves.
	var cat := find_catalog_by_id(str(row.get("id", "")))
	if not cat.is_empty():
		return int(cat.get("chain_order", 0))
	return int(row.get("chain_order", 0))


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
	## Upgraded rows use *_upgraded keys when present.
	var cat := find_catalog_by_id(str(row.get("id", "")))
	var upgraded := bool(row.get("upgraded", false))
	var keys: Array[String] = []
	if lang == "ko":
		if upgraded:
			keys.append("ko_upgraded")
		keys.append("ko")
	elif lang == "en_u4":
		if upgraded:
			keys.append_array(["en_u4_upgraded", "en_upgraded"])
		keys.append_array(["en_u4", "en"])
	else:
		if upgraded:
			keys.append_array(["en_us_upgraded", "en_upgraded"])
		keys.append_array(["en_us", "en"])
	for k in keys:
		var s := str(cat.get(k, "")).strip_edges()
		if s.is_empty():
			s = str(row.get(k, "")).strip_edges()
		if not s.is_empty():
			return Locale.fill_places(s)
	return Locale.fill_places(str(cat.get("ko", row.get("ko", ""))))


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


static func sync_known(gs: Node) -> void:
	## Backfill collection bits from already-recorded catalog rows.
	if gs == null:
		return
	ensure_catalog()
	for row in gs.journal_entries:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var cat := find_catalog_by_id(str((row as Dictionary).get("id", "")))
		if cat.is_empty():
			continue
		_apply_know(gs, cat.get("know", ""))
	_link_virtue_sets(gs)


static func known_virtue_mask(gs: Node) -> int:
	sync_known(gs)
	if gs == null:
		return 0
	return int(gs.journal_known_virtues)


static func known_mantra_mask(gs: Node) -> int:
	sync_known(gs)
	if gs == null:
		return 0
	return int(gs.journal_known_mantras)


static func known_dungeon_mask(gs: Node) -> int:
	sync_known(gs)
	if gs == null:
		return 0
	return int(gs.journal_known_dungeons)


static func known_stone_mask(gs: Node) -> int:
	sync_known(gs)
	if gs == null:
		return 0
	return int(gs.stones) | int(gs.journal_known_stones)


static func _apply_know(gs: Node, raw: Variant) -> void:
	if gs == null:
		return
	if typeof(raw) == TYPE_ARRAY:
		for item in raw:
			_apply_know_token(gs, str(item))
		return
	_apply_know_token(gs, str(raw))


static func mark_known_virtue(gs: Node, virtue: int) -> void:
	if gs == null or virtue < 0 or virtue > 7:
		return
	gs.journal_known_virtues = int(gs.journal_known_virtues) | (1 << virtue)


static func mark_known_mantra(gs: Node, virtue: int) -> void:
	if gs == null or virtue < 0 or virtue > 7:
		return
	gs.journal_known_mantras = int(gs.journal_known_mantras) | (1 << virtue)
	mark_known_virtue(gs, virtue)


static func mark_known_rune(gs: Node, virtue: int) -> void:
	## Inventory already shows the rune; the matching virtue is learned with it.
	mark_known_virtue(gs, virtue)


static func mark_known_stone(gs: Node, flag: int) -> void:
	## Heard or owned stone; same bit as Virtues.Id so the collection columns line up.
	if gs == null or flag == 0:
		return
	gs.journal_known_stones = int(gs.journal_known_stones) | flag
	for i in 8:
		if (flag & (1 << i)) != 0:
			mark_known_virtue(gs, i)


static func _link_virtue_sets(gs: Node) -> void:
	## A learned mantra or owned rune also reveals its virtue.
	if gs == null:
		return
	gs.journal_known_virtues = (
		int(gs.journal_known_virtues)
		| int(gs.journal_known_mantras)
		| int(gs.runes)
		| int(gs.journal_known_stones)
		| int(gs.stones)
	)


static func _apply_know_token(gs: Node, raw: String) -> void:
	if gs == null:
		return
	var k := raw.strip_edges().to_lower()
	if k.begins_with("virtue:"):
		mark_known_virtue(gs, _virtue_from_token(k.substr(7)))
	elif k.begins_with("mantra:"):
		mark_known_mantra(gs, _virtue_from_token(k.substr(7)))
	elif k.begins_with("dungeon:"):
		var d := _dungeon_from_token(k.substr(8))
		if d >= 0:
			gs.journal_known_dungeons = int(gs.journal_known_dungeons) | (1 << d)
	elif k.begins_with("stone:"):
		var flag := _stone_flag_from_token(k.substr(6))
		if flag != 0:
			mark_known_stone(gs, flag)


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


static func _dungeon_from_token(token: String) -> int:
	## Same index as Virtues.Id / stone color.
	match token.strip_edges().to_lower():
		"deceit", "0":
			return 0
		"despise", "1":
			return 1
		"destard", "2":
			return 2
		"wrong", "3":
			return 3
		"covetous", "4":
			return 4
		"shame", "5":
			return 5
		"hythloth", "6":
			return 6
		"abyss", "7":
			return 7
		_:
			return -1


static func _stone_flag_from_token(token: String) -> int:
	## Matches GameState.STONE_* bitflags.
	match token.strip_edges().to_lower():
		"blue", "honesty":
			return 0x01
		"yellow", "compassion":
			return 0x02
		"red", "valor":
			return 0x04
		"green", "justice":
			return 0x08
		"orange", "sacrifice":
			return 0x10
		"purple", "honor":
			return 0x20
		"white", "spirituality":
			return 0x40
		"black", "humility":
			return 0x80
		_:
			return 0
