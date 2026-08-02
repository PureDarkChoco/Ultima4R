class_name CombatMaps
extends RefCounted

## xu4 GameController::combatMapForTile — pick a .CON by ground / ship context.
## Prefer preload over bare class_name types (stale global class cache).

const _TileRules := preload("res://src/map/tile_rules.gd")
const _CombatMapData := preload("res://src/map/combat_map_data.gd")

## World shapes tile id → combat map basename (DOS uppercase).
const GROUND_CON := {
	3: "MARSH.CON", ## swamp
	4: "GRASS.CON",
	5: "BRUSH.CON",
	6: "FOREST.CON",
	7: "HILL.CON",
	9: "DUNGEON.CON", ## dungeon entrance
	10: "GRASS.CON", ## town
	11: "GRASS.CON", ## castle/keep
	12: "GRASS.CON", ## village
	13: "GRASS.CON",
	14: "GRASS.CON",
	15: "GRASS.CON",
	20: "GRASS.CON", ## horse
	21: "GRASS.CON",
	23: "BRIDGE.CON",
	24: "GRASS.CON", ## balloon
	25: "BRIDGE.CON",
	26: "BRIDGE.CON",
	30: "GRASS.CON", ## shrine
	60: "GRASS.CON", ## chest
	62: "BRICK.CON", ## brick floor
	64: "GRASS.CON", ## moongate
	65: "GRASS.CON",
	66: "GRASS.CON",
	67: "GRASS.CON",
}


static func con_for_encounter(
	ground_tid: int,
	foe_tid: int,
	party_on_ship: bool,
	foe_on_water: bool
) -> String:
	## Return .CON basename. Ship/shore rules beat ground mapping (xu4).
	## Pirate ship tiles 128–131 (not the party frigate 16–19).
	var to_ship := foe_tid >= 128 and foe_tid <= 131
	if party_on_ship and to_ship:
		return "SHIPSHIP.CON"
	if to_ship:
		return "SHORSHIP.CON"
	if party_on_ship and foe_on_water:
		return "SHIPSEA.CON"
	if foe_on_water:
		return "SHORE.CON"
	if party_on_ship and not foe_on_water:
		return "SHIPSHOR.CON"
	var base := ground_tid
	if GROUND_CON.has(base):
		return str(GROUND_CON[base])
	## Water underfoot while not in ship branch → shore.
	if _TileRules.is_water(base):
		return "SHORE.CON"
	return "BRICK.CON"


static func load_for_encounter(
	ground_tid: int,
	foe_tid: int,
	party_on_ship: bool,
	foe_on_water: bool
):
	## CombatMapData or null.
	var fname := con_for_encounter(ground_tid, foe_tid, party_on_ship, foe_on_water)
	var path := _CombatMapData.resolve_u4_file(fname)
	if path.is_empty():
		path = _CombatMapData.resolve_u4_file("GRASS.CON")
	if path.is_empty():
		return null
	var cmap = _CombatMapData.new()
	if not cmap.load_from_path(path):
		return null
	return cmap
