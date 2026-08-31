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
static var _seeding_referrals := false


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


static func find_catalog_by_id(id: String, upgrade_variant: int = -1) -> Dictionary:
	## upgrade_variant: -1 = first row (unique ids), 0 = base clue, 1 = upgrade clue.
	ensure_catalog()
	var want := id.strip_edges()
	if want.is_empty():
		return {}
	var matches: Array = []
	for item in _catalog:
		var d: Dictionary = item
		if str(d.get("id", "")).strip_edges() != want:
			continue
		matches.append(d)
	if matches.is_empty():
		return {}
	if matches.size() == 1 or upgrade_variant < 0:
		return matches[0] as Dictionary
	for item in matches:
		var d: Dictionary = item
		var is_up := bool(d.get("upgrade", false))
		if upgrade_variant == 1 and is_up:
			return d
		if upgrade_variant == 0 and not is_up:
			return d
	return matches[0] as Dictionary


static func find_catalog_for_row(row: Dictionary) -> Dictionary:
	var id := str(row.get("id", "")).strip_edges()
	if id.is_empty():
		return {}
	var variant := 1 if bool(row.get("upgraded", false)) else 0
	return find_catalog_by_id(id, variant)


static func seed_new_game(gs: Node) -> void:
	## Starter Britannia goals for a freshly created party.
	if gs == null:
		return
	ensure_catalog()
	const IDS: Array[String] = [
		"britannia.start.talk",
		"britannia.start.combat",
	]
	for id in IDS:
		var cat := find_catalog_by_id(id)
		if cat.is_empty():
			continue
		_append_catalog_capture(
			gs, cat, "britannia", str(cat.get("npc", "The Quest of the Avatar")), false
		)


static func ensure_progress_goals(gs: Node, note_new: bool = false) -> bool:
	## Companions / runes / stones appear after the first recruit or find.
	if gs == null:
		return false
	ensure_catalog()
	var changed := false
	var companions := maxi(0, gs.party_size() - 1)
	if companions <= 0:
		if _remove_entry_id(gs, "britannia.start.companions"):
			changed = true
	elif _ensure_catalog_row(gs, "britannia.start.companions", note_new):
		changed = true
	if _mask_count(int(gs.runes)) > 0:
		if _ensure_catalog_row(gs, "britannia.start.runes", note_new):
			changed = true
	if _mask_count(int(gs.stones)) > 0:
		if _ensure_catalog_row(gs, "britannia.start.stones", note_new):
			changed = true
	return changed


static func _ensure_catalog_row(gs: Node, id: String, note_new: bool) -> bool:
	if has_entry_id(gs, id):
		return false
	var cat := find_catalog_by_id(id)
	if cat.is_empty():
		return false
	return _append_catalog_capture(
		gs, cat, "britannia", str(cat.get("npc", "The Quest of the Avatar")), note_new
	)


static func _remove_entry_id(gs: Node, id: String) -> bool:
	if gs == null or id.is_empty():
		return false
	var want := id.strip_edges()
	var rows: Array = gs.journal_entries
	for i in rows.size():
		var row: Variant = rows[i]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if str((row as Dictionary).get("id", "")).strip_edges() != want:
			continue
		rows.remove_at(i)
		gs.journal_entries = rows
		if str(gs.journal_unseen_id) == want:
			gs.journal_unseen_id = ""
		return true
	return false


static func _mask_count(mask: int, bits: int = 8) -> int:
	var n := 0
	for i in bits:
		if (mask & (1 << i)) != 0:
			n += 1
	return n


static func _progress_suffix(row: Dictionary, cat: Dictionary, gs: Node) -> String:
	if gs == null:
		return ""
	var goal := str(row.get("goal", "")).strip_edges().to_lower()
	if goal.is_empty() and not cat.is_empty():
		goal = str(cat.get("goal", "")).strip_edges().to_lower()
	if goal == "companions:7":
		return "%d/7" % clampi(gs.party_size() - 1, 0, 7)
	if goal == "runes:8":
		return "%d/8" % clampi(_mask_count(int(gs.runes)), 0, 8)
	if goal == "stones:8":
		return "%d/8" % clampi(_mask_count(int(gs.stones)), 0, 8)
	return ""


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
	if mark_goals_for_inventory(gs):
		any = true
	if any:
		_prefer_unseen_in_place(gs, p)
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
	## Same id + upgrade: expand an existing clue in place.
	if bool(cat.get("upgrade", false)):
		return _upgrade_catalog_capture(gs, cat, place, npc, id)
	## Collection-page facts only (no travel-log row). Re-hearing still fills gaps.
	if bool(cat.get("codex_only", false)):
		return _capture_know(gs, cat.get("know", ""))
	if has_entry_id(gs, id):
		## Page-1 row already exists — still reveal any new collection facts.
		return _capture_know(gs, cat.get("know", ""))
	if _catalog_skip_if_recorded(gs, cat):
		return false
	if not _catalog_requires_recorded_met(gs, cat):
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
	_capture_know(gs, cat.get("know", ""))
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
	var base := find_catalog_by_id(id, 0)
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


static func _prefer_unseen_in_place(gs: Node, place: String) -> void:
	## Dual-town inserts (source tip + destination ask) must ping the town
	## where the player just heard it, not the seeded destination section.
	if gs == null:
		return
	var id := latest_id_for_place(gs, place)
	if id.is_empty():
		return
	_note_new_entry(gs, id, place)


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


static func _catalog_requires_recorded_met(gs: Node, cat: Dictionary) -> bool:
	## Chain gate: do not record this fact until a prior tip id exists.
	var raw: Variant = cat.get("requires_recorded", "")
	if typeof(raw) == TYPE_ARRAY:
		if raw.is_empty():
			return true
		for sid in raw:
			if not has_entry_id(gs, str(sid)):
				return false
		return true
	var sid := str(raw).strip_edges()
	return sid.is_empty() or has_entry_id(gs, sid)


static func _catalog_seed_ids(cat: Dictionary) -> Array[String]:
	var raw: Variant = cat.get("seed_if_recorded", "")
	var out: Array[String] = []
	if typeof(raw) == TYPE_ARRAY:
		for sid in raw:
			var id := str(sid).strip_edges()
			if not id.is_empty():
				out.append(id)
		return out
	var id := str(raw).strip_edges()
	if not id.is_empty():
		out.append(id)
	return out


static func _catalog_seed_if_recorded_met(gs: Node, cat: Dictionary) -> bool:
	## Destination ask/meet rows unlock when any named source tip exists.
	for sid in _catalog_seed_ids(cat):
		if has_entry_id(gs, sid):
			return true
	return false


static func seed_referral_rows(gs: Node, note_new: bool = false) -> bool:
	## Cross-town "ask X in {town}" tips also leave a nameless ask/meet row
	## on the destination settlement. Completing the talk finishes both.
	if gs == null or _seeding_referrals:
		return false
	ensure_catalog()
	_seeding_referrals = true
	var any := false
	for item in _catalog:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var cat: Dictionary = item
		if _catalog_seed_ids(cat).is_empty():
			continue
		if not _catalog_seed_if_recorded_met(gs, cat):
			continue
		var place := str(cat.get("place", "")).strip_edges()
		var npc := str(cat.get("npc", "")).strip_edges()
		if place.is_empty() or npc.is_empty():
			continue
		if _append_catalog_capture(gs, cat, place, npc, note_new):
			any = true
	_seeding_referrals = false
	return any


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
			var cat := find_catalog_for_row(d)
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


static func try_upgrade_id(gs: Node, id: String) -> bool:
	## Flip an existing row to its *_upgraded catalog text. No insert if missing.
	if gs == null:
		return false
	var want := id.strip_edges()
	if want.is_empty():
		return false
	var rows: Array = gs.journal_entries
	for i in rows.size():
		var row: Variant = rows[i]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		if str(d.get("id", "")).strip_edges() != want:
			continue
		if bool(d.get("upgraded", false)):
			return false
		d["upgraded"] = true
		rows[i] = d
		gs.journal_entries = rows
		return true
	return false


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
	var changed := ensure_progress_goals(gs, false)
	changed = _apply_pending_journal_completions(gs) or changed
	if _migrate_tyrone_stone_use(gs):
		changed = true
	if _migrate_yew_druid_mantra(gs):
		changed = true
	if _migrate_britain_compassion_virtue(gs):
		changed = true
	if _migrate_magincia_nate_rune_first_heard(gs):
		changed = true
	if _migrate_remove_lcb_water_ask_altars(gs):
		changed = true
	if _migrate_lycaeum_fighter_altar_links(gs):
		changed = true
	if seed_referral_rows(gs, false):
		changed = true
	if _reconcile_estro_yew_justice_chain(gs):
		changed = true
	changed = _apply_pending_journal_completions(gs) or changed
	return changed


static func _apply_pending_journal_completions(gs: Node) -> bool:
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
		var cat := find_catalog_for_row(d)
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


static func _reconcile_estro_yew_justice_chain(gs: Node) -> bool:
	## Estro's Yew judge tip recorded after Yew work — backfill the Yew chain as done.
	if gs == null or not has_entry_id(gs, "lycaeum.estro.yew-judge"):
		return false
	var changed := false
	const CHAIN_IDS: Array[String] = [
		"yew.talfourd.meet-judge",
		"yew.talfourd.ask-rune",
		"yew.talfourd.justice-rune",
		"yew.druid.talfourd-rune",
	]
	if (
		goal_already_met(gs, "rune:justice")
		and not has_entry_id(gs, "yew.talfourd.justice-rune")
	):
		var cat := find_catalog_by_id("yew.talfourd.justice-rune")
		if not cat.is_empty():
			if _append_catalog_capture(gs, cat, "yew", "Talfourd", false):
				changed = true
	for goal in ["meet:yew-judge", "ask:talfourd-rune", "rune:justice"]:
		if goal_already_met(gs, goal) and mark_goal(gs, goal):
			changed = true
	for id in CHAIN_IDS:
		if not has_entry_id(gs, id):
			continue
		var cat := find_catalog_by_id(id)
		if cat.is_empty():
			continue
		var rows: Array = gs.journal_entries
		for i in rows.size():
			var row_v: Variant = rows[i]
			if typeof(row_v) != TYPE_DICTIONARY:
				continue
			var d: Dictionary = row_v
			if str(d.get("id", "")).strip_edges() != id:
				continue
			if bool(d.get("done", false)):
				break
			var row_goal := str(d.get("goal", cat.get("goal", ""))).strip_edges()
			var met := not row_goal.is_empty() and goal_already_met(gs, row_goal)
			var complete_on_goal := str(cat.get("complete_on_goal", "")).strip_edges()
			if not complete_on_goal.is_empty() and goal_already_met(gs, complete_on_goal):
				met = true
			if _catalog_completion_recorded(gs, cat):
				met = true
			if met:
				d["done"] = true
				rows[i] = d
				gs.journal_entries = rows
				changed = true
			break
	return changed


static func _migrate_tyrone_stone_use(gs: Node) -> bool:
	## Old Tyrone USE tip upgraded one row; split it into the follow-up chain.
	if gs == null:
		return false
	if has_entry_id(gs, "moonglow.tyrone.honesty-stone-use"):
		return false
	var heard_use := false
	var rows: Array = gs.journal_entries
	for i in rows.size():
		var row: Variant = rows[i]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		if str(d.get("id", "")).strip_edges() != "moonglow.tyrone.honesty-stone":
			continue
		if not bool(d.get("upgraded", false)):
			break
		heard_use = true
		d["upgraded"] = false
		rows[i] = d
		gs.journal_entries = rows
		break
	if not heard_use:
		return false
	var cat := find_catalog_by_id("moonglow.tyrone.honesty-stone-use")
	if cat.is_empty():
		return false
	return _append_catalog_capture(gs, cat, "moonglow", "Tyrone", false)


static func _migrate_yew_druid_mantra(gs: Node) -> bool:
	## Old Druid YES mixed mantra + stone on the rune chain; split the mantra tip.
	if gs == null:
		return false
	if has_entry_id(gs, "yew.druid.learn-mantra"):
		return false
	if not has_entry_id(gs, "yew.druid.green-stone"):
		return false
	var cat := find_catalog_by_id("yew.druid.learn-mantra")
	if cat.is_empty():
		return false
	return _append_catalog_capture(gs, cat, "yew", "Druid", false)


static func _migrate_britain_compassion_virtue(gs: Node) -> bool:
	## Old Britain talks had no page-1 Virtue: Compassion row.
	if gs == null:
		return false
	if (
		has_entry_id(gs, "britain.julio.compassion-virtue")
		or has_entry_id(gs, "britain.pepper.compassion-virtue")
		or has_entry_id(gs, "britain.cricket.compassion-virtue")
		or has_entry_id(gs, "britain.gweno.compassion-virtue")
	):
		return false
	const PAIRS: Array[Array] = [
		["britain.julio.compassion", "britain.julio.compassion-virtue", "Julio"],
		["britain.pepper.compassion-rune", "britain.pepper.compassion-virtue", "Pepper"],
		["britain.cricket.compassion-mantra", "britain.cricket.compassion-virtue", "Cricket"],
	]
	for pair in PAIRS:
		if not has_entry_id(gs, str(pair[0])):
			continue
		var cat := find_catalog_by_id(str(pair[1]))
		if cat.is_empty():
			return false
		return _append_catalog_capture(gs, cat, "britain", str(pair[2]), false)
	return false


static func _migrate_magincia_nate_rune_first_heard(gs: Node) -> bool:
	## Old Magincia saves could keep both Ruskin and Splot rune tips.
	const RUSKIN := "magincia.ruskin.nate-rune"
	const SPLOT := "magincia.splot.nate-rune"
	if gs == null or not has_entry_id(gs, RUSKIN) or not has_entry_id(gs, SPLOT):
		return false
	var drop := SPLOT
	var ruskin_at := -1
	var splot_at := -1
	var rows: Array = gs.journal_entries
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		var id := str(d.get("id", "")).strip_edges()
		if id == RUSKIN:
			ruskin_at = int(d.get("at", 0))
		elif id == SPLOT:
			splot_at = int(d.get("at", 0))
	if splot_at >= 0 and (ruskin_at < 0 or splot_at < ruskin_at):
		drop = RUSKIN
	var kept: Array = []
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY and str(row.get("id", "")).strip_edges() == drop:
			continue
		kept.append(row)
	if kept.size() == rows.size():
		return false
	gs.journal_entries = kept
	return true


static func _migrate_remove_lcb_water_ask_altars(gs: Node) -> bool:
	## Same-city duplicate removed from catalog; drop stale save rows.
	return _remove_entry_id(gs, "lcb.water.ask-altars")


static func _migrate_lycaeum_fighter_altar_links(gs: Node) -> bool:
	## The NO answer is the base clue; YES replaces it with exact room counts.
	## Merge legacy saves that recorded the old answers as separate rows.
	if gs == null:
		return false
	const SHARED := "lycaeum.fighter.altar-links"
	const OLD_YES := "lycaeum.fighter.altar-links-yes"
	const OLD_NO := "lycaeum.fighter.altar-links-no"
	var rows: Array = gs.journal_entries
	var first_index := -1
	var source: Dictionary = {}
	var heard_yes := false
	var found_legacy := false
	for i in rows.size():
		var row: Variant = rows[i]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		var id := str(d.get("id", "")).strip_edges()
		if id not in [SHARED, OLD_YES, OLD_NO]:
			continue
		if first_index < 0:
			first_index = i
		if id == OLD_YES or (id == SHARED and bool(d.get("upgraded", false))):
			heard_yes = true
			source = d.duplicate(true)
		elif source.is_empty():
			source = d.duplicate(true)
		if id == OLD_YES or id == OLD_NO:
			found_legacy = true
	if not found_legacy:
		return false
	var topic := "WOUN_YES" if heard_yes else "WOUN_NO"
	var cat := find_catalog("lycaeum", "a fighter", topic)
	if cat.is_empty():
		return false
	source["id"] = SHARED
	source["en"] = str(cat.get("en", source.get("en", "")))
	source["ko"] = str(cat.get("ko", source.get("ko", "")))
	source["upgraded"] = heard_yes
	var kept: Array = []
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY:
			var id := str((row as Dictionary).get("id", "")).strip_edges()
			if id in [SHARED, OLD_YES, OLD_NO]:
				continue
		kept.append(row)
	kept.insert(clampi(first_index, 0, kept.size()), source)
	gs.journal_entries = kept
	return true


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
		or catalog_goal.begins_with("use:stone:")
		or catalog_goal.begins_with("item:")
		or catalog_goal.begins_with("key:")
	):
		if bool(row.get("done", false)) != inventory_done:
			row["done"] = inventory_done
			return true
		return changed
	if catalog_goal == "use:horn" or catalog_goal.begins_with("use:horn"):
		if old_goal.is_empty() and bool(row.get("done", false)):
			row["done"] = false
			return true
		return changed
	if catalog_goal.begins_with("ask:") or catalog_goal.begins_with("meet:"):
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
	if g.begins_with("use:stone:"):
		return _stone_use_already_met(gs, _stone_flag_from_token(g.substr(10)))
	if g == "key:courage":
		## Courage altar stones used → third part of the key.
		return gs.has_item_flag(gs.ITEM_KEY_C)
	if g == "companions:7":
		## Avatar + 7 companions.
		return gs.party_size() >= 8
	if g == "runes:8":
		return _mask_count(int(gs.runes)) >= 8
	if g == "stones:8":
		return _mask_count(int(gs.stones)) >= 8
	if g == "join:jaana":
		## Recruited Jaana. Same-class refusal is marked at the join attempt.
		return gs.is_person_joined("Jaana")
	if g == "join:dupre":
		return gs.is_person_joined("Dupre")
	if g == "item:sextant" or g == "sextant":
		return bool(gs.has_sextant)
	if g == "item:book" or g == "book":
		return gs.has_item_flag(gs.ITEM_BOOK)
	if g == "item:candle" or g == "candle":
		return gs.has_item_flag(gs.ITEM_CANDLE)
	if g == "item:bell" or g == "bell":
		return gs.has_item_flag(gs.ITEM_BELL)
	if g == "item:horn" or g == "horn":
		return gs.has_item_flag(gs.ITEM_HORN)
	if g == "item:wheel" or g == "wheel":
		return gs.has_item_flag(gs.ITEM_WHEEL)
	if g == "enter:hythloth-castle":
		## Descended into Hythloth from Castle Britannia (secret entrance).
		return bool(gs.journal_hythloth_castle)
	if g == "enter:magincia":
		var mag_i := _WorldPortals.town_moon_index("magincia")
		return mag_i >= 0 and (int(gs.journal_known_cities) & (1 << mag_i)) != 0
	if g == "search:skull":
		return gs.has_item_flag(gs.ITEM_SKULL) or gs.has_item_flag(gs.ITEM_SKULL_DESTROYED)
	if g == "meet:yew-judge":
		return _yew_judge_already_met(gs)
	if g == "ask:talfourd-rune":
		return _talfourd_rune_ask_already_met(gs)
	## talk:first-note / combat:first / shrine:* complete only when the event fires.
	## mantra:* is a shrine fallback for ask-tips (complete_on_goal), not a pending knowledge goal.
	return false


static func _yew_judge_already_met(gs: Node) -> bool:
	## Estro → Yew judge: first Talfourd talk, or any later Yew justice progress.
	if gs == null:
		return false
	if gs.talk_has_heard_word("meet:yew-judge"):
		return true
	if gs.talk_has_heard_word("ask:talfourd-rune"):
		return true
	if has_entry_id(gs, "yew.talfourd.justice-rune"):
		return true
	if goal_already_met(gs, "rune:justice"):
		return true
	var legacy: Variant = gs.talk_known_keywords.get("yew/talfourd", null)
	if typeof(legacy) == TYPE_ARRAY and not (legacy as Array).is_empty():
		return true
	return false


static func _talfourd_rune_ask_already_met(gs: Node) -> bool:
	## Estro or druid → Talfourd rune/crime clue; jail tip completes the ask.
	if gs == null:
		return false
	if has_entry_id(gs, "yew.talfourd.justice-rune"):
		return true
	if gs.talk_has_heard_word("ask:talfourd-rune"):
		return true
	if goal_already_met(gs, "rune:justice"):
		return true
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


static func first_id_for_place(gs: Node, place: String) -> String:
	## First displayed note under a settlement (same order as the travel log).
	if gs == null:
		return ""
	var want := place.strip_edges().to_lower()
	if want.is_empty():
		return ""
	for group in grouped_for_ui(gs):
		if str(group.get("place", "")).strip_edges().to_lower() != want:
			continue
		var rows: Array = group.get("entries", [])
		for row in rows:
			if typeof(row) != TYPE_DICTIONARY:
				continue
			var id := str((row as Dictionary).get("id", "")).strip_edges()
			if not id.is_empty():
				return id
		return ""
	return ""


static func first_place_key(gs: Node) -> String:
	## Top of the travel log (first settlement header that has notes).
	if gs == null:
		return ""
	for group in grouped_for_ui(gs):
		var host := str(group.get("place", "")).strip_edges().to_lower()
		if host.is_empty():
			continue
		return "place:" + host
	return ""


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


static func acquired_at(gs: Node, id: String) -> int:
	if gs == null:
		return -1
	var want := id.strip_edges()
	if want.is_empty():
		return -1
	for row in gs.journal_entries:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = row
		if str(d.get("id", "")).strip_edges() != want:
			continue
		return int(d.get("at", 0))
	return -1


static func place_has_entry_as_recent_as(gs: Node, place: String, other_id: String) -> bool:
	var local := latest_id_for_place(gs, place)
	if local.is_empty():
		return false
	return acquired_at(gs, local) >= acquired_at(gs, other_id)


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
	var cat := find_catalog_for_row(row)
	if not cat.is_empty():
		return str(cat.get("chain", "")).strip_edges()
	return str(row.get("chain", "")).strip_edges()


static func entry_chain_order(row: Dictionary) -> int:
	## Catalog is authoritative so reordered local chains also update old saves.
	var cat := find_catalog_for_row(row)
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


static func entry_text(row: Dictionary, lang: String, gs: Node = null) -> String:
	## Catalog wording is authoritative so corrected clues also update old saves.
	## Upgraded rows use *_upgraded keys when present.
	var cat := find_catalog_for_row(row)
	var entry_id := str(row.get("id", ""))
	if entry_id == "lcb.shawn.magincia-ruins" and not cat.is_empty():
		var text := _shawn_magincia_ruins_text(cat, lang, gs)
		var suffix := _progress_suffix(row, cat, gs)
		if suffix.is_empty():
			return text
		return "%s (%s)" % [text, suffix]
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
	var text := ""
	for k in keys:
		var s := str(cat.get(k, "")).strip_edges()
		if s.is_empty():
			s = str(row.get(k, "")).strip_edges()
		if not s.is_empty():
			text = s
			break
	if text.is_empty():
		text = str(cat.get("ko", row.get("ko", "")))
	text = Locale.fill_places(text)
	var suffix := _progress_suffix(row, cat, gs)
	if suffix.is_empty():
		return text
	return "%s (%s)" % [text, suffix]


static func _shawn_magincia_name_unlocked(gs: Node) -> bool:
	## Collection page 2: humility virtue and Magincia town both revealed.
	if gs == null:
		return false
	if (int(gs.journal_known_virtues) & (1 << _Virtues.Id.HUMILITY)) == 0:
		return false
	var mag_i := _WorldPortals.town_moon_index("magincia")
	if mag_i < 0:
		return false
	return (int(gs.journal_known_cities) & (1 << mag_i)) != 0


static func _shawn_magincia_ruins_text(cat: Dictionary, lang: String, gs: Node) -> String:
	var named := _shawn_magincia_name_unlocked(gs)
	if lang == "ko":
		if named:
			return str(cat.get("ko_upgraded", "마진시아 폐허: 위도 K'J\" 경도 L'L\""))
		return str(cat.get("ko", "자만의 도시 폐허: 위도 K'J\" 경도 L'L\""))
	if lang == "en_u4":
		if named:
			return str(cat.get(
				"en_u4_upgraded",
				"The ruins of Magincia lie on an isle at lat-K'J\" long-L'L\"!"
			))
		return str(cat.get(
			"en_u4",
			"The ruins of a proud city lie on an isle at lat-K'J\" long-L'L\"!"
		))
	if named:
		return str(cat.get("en_us_upgraded", "Magincia ruins: lat-K'J\" long-L'L\"."))
	return str(cat.get("en_us", "Proud city's ruins: lat-K'J\" long-L'L\"."))


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
		var d: Dictionary = row
		mark_known_city(gs, str(d.get("place", "")))
		var cat := find_catalog_for_row(d)
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


static func known_principle_mask(gs: Node) -> int:
	sync_known(gs)
	if gs == null:
		return 0
	return int(gs.journal_known_principles)


static func capture_know(gs: Node, raw: Variant) -> bool:
	## Live talk/loot facts. Marks the collection page unread when something new lands.
	return _capture_know(gs, raw)


static func _capture_know(gs: Node, raw: Variant) -> bool:
	var added := _apply_know(gs, raw)
	if added:
		mark_codex_unseen(gs)
	return added


static func mark_codex_unseen(gs: Node) -> void:
	if gs == null:
		return
	gs.journal_codex_unseen = true


static func clear_codex_unseen(gs: Node) -> void:
	if gs == null:
		return
	gs.journal_codex_unseen = false


static func _apply_know(gs: Node, raw: Variant) -> bool:
	if gs == null:
		return false
	if typeof(raw) == TYPE_ARRAY:
		var any := false
		for item in raw:
			if _apply_know_token(gs, str(item)):
				any = true
		return any
	return _apply_know_token(gs, str(raw))


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


static func mark_known_dungeon(gs: Node, dungeon_id: String) -> bool:
	if gs == null:
		return false
	var i := _dungeon_from_token(dungeon_id)
	if i < 0:
		return false
	var bit := 1 << i
	if (int(gs.journal_known_dungeons) & bit) != 0:
		return false
	gs.journal_known_dungeons = int(gs.journal_known_dungeons) | bit
	return true


static func mark_known_city(gs: Node, place_id: String) -> bool:
	## Entered a virtue town (Moonglow…Magincia). Returns true if newly marked.
	if gs == null:
		return false
	var i := _WorldPortals.town_moon_index(place_id)
	if i < 0:
		return false
	var bit := 1 << i
	if (int(gs.journal_known_cities) & bit) != 0:
		return false
	gs.journal_known_cities = int(gs.journal_known_cities) | bit
	return true


static func mark_known_city_moon(gs: Node, phase: int) -> bool:
	## Moongate arrival: reveal that town's name and its moon phase.
	if gs == null or phase < 0 or phase > 7:
		return false
	var bit := 1 << phase
	var changed := false
	if (int(gs.journal_known_city_moons) & bit) == 0:
		gs.journal_known_city_moons = int(gs.journal_known_city_moons) | bit
		changed = true
	if (int(gs.journal_known_cities) & bit) == 0:
		gs.journal_known_cities = int(gs.journal_known_cities) | bit
		changed = true
	return changed


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


static func _apply_know_token(gs: Node, raw: String) -> bool:
	if gs == null:
		return false
	var k := raw.strip_edges().to_lower()
	if k.begins_with("virtue:"):
		var virtue := _virtue_from_token(k.substr(7))
		if virtue < 0:
			return false
		var bit := 1 << virtue
		if (int(gs.journal_known_virtues) & bit) != 0:
			return false
		mark_known_virtue(gs, virtue)
		return true
	if k.begins_with("mantra:"):
		var virtue := _virtue_from_token(k.substr(7))
		if virtue < 0:
			return false
		var before_m := int(gs.journal_known_mantras)
		var before_v := int(gs.journal_known_virtues)
		mark_known_mantra(gs, virtue)
		return (
			int(gs.journal_known_mantras) != before_m
			or int(gs.journal_known_virtues) != before_v
		)
	if k.begins_with("dungeon:"):
		return mark_known_dungeon(gs, k.substr(8))
	if k.begins_with("stone:"):
		var flag := _stone_flag_from_token(k.substr(6))
		if flag == 0:
			return false
		var before_s := int(gs.journal_known_stones)
		var before_v := int(gs.journal_known_virtues)
		mark_known_stone(gs, flag)
		return (
			int(gs.journal_known_stones) != before_s
			or int(gs.journal_known_virtues) != before_v
		)
	if k.begins_with("principle:"):
		return mark_known_principle(gs, k.substr(10))
	return false


static func mark_known_principle(gs: Node, token: String) -> bool:
	## Truth / Love / Courage — Codex principles (not the three-part keys).
	if gs == null:
		return false
	var bit := 0
	match token.strip_edges().to_lower():
		"truth", "0":
			bit = 1
		"love", "1":
			bit = 2
		"courage", "2":
			bit = 4
		_:
			return false
	if (int(gs.journal_known_principles) & bit) != 0:
		return false
	gs.journal_known_principles = int(gs.journal_known_principles) | bit
	return true


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


static func _stone_use_already_met(gs: Node, flag: int) -> bool:
	## Altar-room use (Truth key for blue) or the matching abyss altar.
	if gs == null or flag == 0:
		return false
	if (int(gs.abyss_stones_used) & flag) != 0:
		return true
	if flag == 0x01:
		return gs.has_item_flag(gs.ITEM_KEY_T)
	return false
