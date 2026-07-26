class_name CityFloorPortals
extends RefCounted

## In-city Klimb / Descend portals (xu4 maps.b).
## Dungeon / abyss portals are omitted for now.

enum Action { CLIMB = 2, DESCEND = 4 }

## Key = .ULT basename (lower). Each portal:
##   x,y on this map; action; dest_fname; dx,dy; msg_key (Locale).
const PORTALS := {
	"lcb_1.ult": [
		{
			"x": 3, "y": 3, "action": Action.CLIMB,
			"dest_fname": "lcb_2.ult", "dx": 3, "dy": 3,
			"msg": "cmd_klimb_lcb2",
		},
		{
			"x": 27, "y": 3, "action": Action.CLIMB,
			"dest_fname": "lcb_2.ult", "dx": 27, "dy": 3,
			"msg": "cmd_klimb_lcb2",
		},
	],
	"lcb_2.ult": [
		{
			"x": 3, "y": 3, "action": Action.DESCEND,
			"dest_fname": "lcb_1.ult", "dx": 3, "dy": 3,
			"msg": "cmd_descend_lcb1",
		},
		{
			"x": 27, "y": 3, "action": Action.DESCEND,
			"dest_fname": "lcb_1.ult", "dx": 27, "dy": 3,
			"msg": "cmd_descend_lcb1",
		},
	],
}


static func normalize_fname(fname: String) -> String:
	return fname.get_file().to_lower()


static func portal_at(fname: String, pos: Vector2i, action: int) -> Dictionary:
	## Empty if no matching floor portal at this cell for K or D.
	var key := normalize_fname(fname)
	if not PORTALS.has(key):
		return {}
	for p in PORTALS[key]:
		var d: Dictionary = p
		if int(d.get("x", -1)) != pos.x or int(d.get("y", -1)) != pos.y:
			continue
		if int(d.get("action", 0)) != action:
			continue
		return d.duplicate()
	return {}
