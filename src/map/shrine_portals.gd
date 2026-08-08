class_name ShrinePortals
extends RefCounted

## World-map Enter portals for shrines (xu4 maps.b id 25–32).
## Spirituality has no world tile — both moons full + rune via moongate.
## Key = "x,y" world tile.

const PORTALS := {
	"233,66": {"virtue": 0, "mantra": "ahm", "name": "Honesty"},
	"128,92": {"virtue": 1, "mantra": "mu", "name": "Compassion"},
	"36,229": {"virtue": 2, "mantra": "ra", "name": "Valor"},
	"73,11": {"virtue": 3, "mantra": "beh", "name": "Justice"},
	"205,45": {"virtue": 4, "mantra": "cah", "name": "Sacrifice"},
	"81,207": {"virtue": 5, "mantra": "summ", "name": "Honor"},
	"231,216": {"virtue": 7, "mantra": "lum", "name": "Humility"},
}

## Moongate-only (maps.b id 31) — used after double full moons.
const SPIRITUALITY := {"virtue": 6, "mantra": "om", "name": "Spirituality"}


static func key_at(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]


static func portal_at(pos: Vector2i) -> Dictionary:
	## Empty dict if no shrine Enter portal on this world tile.
	var k := key_at(pos)
	if not PORTALS.has(k):
		return {}
	return (PORTALS[k] as Dictionary).duplicate()


static func spirituality_portal() -> Dictionary:
	return SPIRITUALITY.duplicate()


static func shrine_name(portal: Dictionary) -> String:
	return "Shrine of %s" % str(portal.get("name", "?"))
