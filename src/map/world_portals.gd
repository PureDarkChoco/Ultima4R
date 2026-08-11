class_name WorldPortals
extends RefCounted

## World-map Enter portals for cities/castles/villages (xu4 maps.b id 1–16).
## Key = "x,y" world tile. Values used by stub Enter (E).

enum CityKind { CASTLE = 0, TOWNE = 1, VILLAGE = 2, RUINS = 3 }

## fname is the .ULT basename (case resolved at load time).
const PORTALS := {
	"86,107": {"fname": "lcb_1.ult", "name": "Britannia", "kind": CityKind.CASTLE, "sx": 15, "sy": 30},
	"218,107": {"fname": "lycaeum.ult", "name": "Lycaeum", "kind": CityKind.CASTLE, "sx": 15, "sy": 30},
	"28,50": {"fname": "empath.ult", "name": "Empath Abbey", "kind": CityKind.CASTLE, "sx": 15, "sy": 30},
	"146,241": {"fname": "serpent.ult", "name": "Serpents Hold", "kind": CityKind.CASTLE, "sx": 15, "sy": 30},
	"232,135": {"fname": "moonglow.ult", "name": "Moonglow", "kind": CityKind.TOWNE, "sx": 1, "sy": 15},
	"82,106": {"fname": "britain.ult", "name": "Britain", "kind": CityKind.TOWNE, "sx": 1, "sy": 15},
	"36,222": {"fname": "jhelom.ult", "name": "Jhelom", "kind": CityKind.TOWNE, "sx": 1, "sy": 15},
	"58,43": {"fname": "yew.ult", "name": "Yew", "kind": CityKind.TOWNE, "sx": 1, "sy": 15},
	"159,20": {"fname": "minoc.ult", "name": "Minoc", "kind": CityKind.TOWNE, "sx": 1, "sy": 15},
	"106,184": {"fname": "trinsic.ult", "name": "Trinsic", "kind": CityKind.TOWNE, "sx": 1, "sy": 15},
	"22,128": {"fname": "skara.ult", "name": "Skara Brae", "kind": CityKind.TOWNE, "sx": 1, "sy": 15},
	"187,169": {"fname": "magincia.ult", "name": "Magincia", "kind": CityKind.RUINS, "sx": 1, "sy": 15},
	"98,145": {"fname": "paws.ult", "name": "Paws", "kind": CityKind.VILLAGE, "sx": 1, "sy": 15},
	"136,158": {"fname": "den.ult", "name": "Buccaneers Den", "kind": CityKind.VILLAGE, "sx": 1, "sy": 15},
	"201,59": {"fname": "vesper.ult", "name": "Vesper", "kind": CityKind.VILLAGE, "sx": 1, "sy": 15},
	"136,90": {"fname": "cove.ult", "name": "Cove", "kind": CityKind.VILLAGE, "sx": 1, "sy": 15},
}


static func key_at(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]


static func portal_at(pos: Vector2i) -> Dictionary:
	## Empty dict if no Enter portal on this world tile.
	var k := key_at(pos)
	if not PORTALS.has(k):
		return {}
	return PORTALS[k] as Dictionary


static func portal_for_fname(fname: String) -> Dictionary:
	## First portal whose .ULT basename matches (case-insensitive). Empty if none.
	## LCB upper floor (lcb_2) shares the world Enter tile with lcb_1.
	var want := fname.get_file().to_lower()
	if want.is_empty():
		return {}
	if want.begins_with("lcb"):
		want = "lcb_1.ult"
	for k in PORTALS.keys():
		var p: Dictionary = PORTALS[k]
		if str(p.get("fname", "")).get_file().to_lower() == want:
			var out := p.duplicate()
			var parts := str(k).split(",")
			if parts.size() == 2:
				out["wx"] = int(parts[0])
				out["wy"] = int(parts[1])
			return out
	return {}


static func place_id_for_portal(portal: Dictionary) -> String:
	## Stable id for locale / save meta (lcb, britain, shame, …).
	var fname := str(portal.get("fname", "")).get_file().to_lower()
	if fname.is_empty():
		return ""
	if fname.begins_with("lcb"):
		return "lcb"
	return fname.get_basename()


static func is_lcb_portal(portal: Dictionary) -> bool:
	return place_id_for_portal(portal) == "lcb"


static func all_portal_entries() -> Array[Dictionary]:
	## Each entry: portal fields + wx, wy world coords.
	var out: Array[Dictionary] = []
	for k in PORTALS.keys():
		var p: Dictionary = (PORTALS[k] as Dictionary).duplicate()
		var parts := str(k).split(",")
		if parts.size() != 2:
			continue
		p["wx"] = int(parts[0])
		p["wy"] = int(parts[1])
		out.append(p)
	return out


static func kind_locale_key(kind: int) -> String:
	match kind:
		CityKind.CASTLE:
			return "city_kind_castle"
		CityKind.TOWNE:
			return "city_kind_towne"
		CityKind.VILLAGE:
			return "city_kind_village"
		CityKind.RUINS:
			return "city_kind_ruins"
		_:
			return "city_kind_towne"


## Journal / 여행 기록 place order: castles (code), 8 virtue towns, villages (code).
const JOURNAL_CASTLES: Array[String] = ["lcb", "lycaeum", "empath", "serpent"]
const JOURNAL_TOWNS: Array[String] = [
	"moonglow", "britain", "jhelom", "yew",
	"minoc", "trinsic", "skara", "magincia",
]
const JOURNAL_VILLAGES: Array[String] = ["paws", "den", "vesper", "cove"]


static func journal_place_order() -> Array[String]:
	var out: Array[String] = []
	out.append_array(JOURNAL_CASTLES)
	out.append_array(JOURNAL_TOWNS)
	out.append_array(JOURNAL_VILLAGES)
	return out
