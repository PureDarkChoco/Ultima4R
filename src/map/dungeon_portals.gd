class_name DungeonPortals
extends RefCounted

## World / LCB / Abyss dungeon portals and altar-room connections (xu4 maps.b).

const _DungeonMap := preload("res://src/map/dungeon_map_data.gd")

const ID_DECEIT := "deceit"
const ID_DESPISE := "despise"
const ID_DESTARD := "destard"
const ID_WRONG := "wrong"
const ID_COVETOUS := "covetous"
const ID_SHAME := "shame"
const ID_HYTHLOTH := "hythloth"
const ID_ABYSS := "abyss"

const THEME_GREY := "grey_stone"
const THEME_BRICK := "brick"
const THEME_DIRT := "dirt"
const THEME_TIMBER := "timber"

const ALTAR_TRUTH := 0
const ALTAR_LOVE := 1
const ALTAR_COURAGE := 2

const ABYSS_ENTRANCE := Vector2i(233, 233)
const ALTAR_ROOM_INDEX := 15
const START := Vector2i(1, 1)
const START_DIR := _DungeonMap.DIR_S

## World tile "x,y" → dungeon portal.
const WORLD := {
	"240,73": {"id": ID_DECEIT, "fname": "DECEIT.DNG"},
	"91,67": {"id": ID_DESPISE, "fname": "DESPISE.DNG"},
	"72,168": {"id": ID_DESTARD, "fname": "DESTARD.DNG"},
	"58,102": {"id": ID_WRONG, "fname": "WRONG.DNG"},
	"156,27": {"id": ID_COVETOUS, "fname": "COVETOUS.DNG"},
	"126,20": {"id": ID_SHAME, "fname": "SHAME.DNG"},
	"239,240": {"id": ID_HYTHLOTH, "fname": "HYTHLOTH.DNG"},
}

## In-city descend/enter (Hythloth from Castle Britannia).
const CITY := {
	"lcb_1.ult": [
		{
			"x": 7, "y": 2, "action": 4, ## CityFloorPortals.Action.DESCEND
			"id": ID_HYTHLOTH, "fname": "HYTHLOTH.DNG",
		},
	],
}

const THEME_OF := {
	ID_DECEIT: THEME_GREY,
	ID_ABYSS: THEME_GREY,
	ID_DESPISE: THEME_DIRT,
	ID_DESTARD: THEME_DIRT,
	ID_COVETOUS: THEME_TIMBER,
	ID_SHAME: THEME_TIMBER,
	ID_WRONG: THEME_BRICK,
	ID_HYTHLOTH: THEME_BRICK,
}

const FNAME_OF := {
	ID_DECEIT: "DECEIT.DNG",
	ID_DESPISE: "DESPISE.DNG",
	ID_DESTARD: "DESTARD.DNG",
	ID_WRONG: "WRONG.DNG",
	ID_COVETOUS: "COVETOUS.DNG",
	ID_SHAME: "SHAME.DNG",
	ID_HYTHLOTH: "HYTHLOTH.DNG",
	ID_ABYSS: "ABYSS.DNG",
}

const INDEX_OF := {
	ID_DECEIT: 0,
	ID_DESPISE: 1,
	ID_DESTARD: 2,
	ID_WRONG: 3,
	ID_COVETOUS: 4,
	ID_SHAME: 5,
	ID_HYTHLOTH: 6,
	ID_ABYSS: 7,
}

const IDS: Array[String] = [
	ID_DECEIT, ID_DESPISE, ID_DESTARD, ID_WRONG,
	ID_COVETOUS, ID_SHAME, ID_HYTHLOTH, ID_ABYSS,
]

## Search-on-altar corridor stones (level is 0-based).
const STONE_AT := {
	ID_DECEIT: {"x": 1, "y": 7, "z": 6, "flag": 0x01}, ## blue
	ID_DESPISE: {"x": 3, "y": 5, "z": 4, "flag": 0x02}, ## yellow
	ID_DESTARD: {"x": 3, "y": 7, "z": 6, "flag": 0x04}, ## red
	ID_WRONG: {"x": 6, "y": 3, "z": 7, "flag": 0x08}, ## green
	ID_COVETOUS: {"x": 7, "y": 1, "z": 6, "flag": 0x10}, ## orange
	ID_SHAME: {"x": 7, "y": 7, "z": 1, "flag": 0x20}, ## purple
	ID_HYTHLOTH: {"x": 1, "y": 5, "z": 0, "flag": 0x40}, ## white
}

## Orb stat raised (bit 0 INT, 1 DEX, 2 STR) — xu4 FileFormats.
const ORB_STATS := {
	ID_DECEIT: 1,
	ID_DESPISE: 2,
	ID_DESTARD: 4,
	ID_WRONG: 3,
	ID_COVETOUS: 6,
	ID_SHAME: 5,
	ID_HYTHLOTH: 7,
	ID_ABYSS: 7,
}

const ORB_DAMAGE := 200

## Room 15 altar kind per dungeon.
const ALTAR_KIND := {
	ID_DECEIT: ALTAR_TRUTH,
	ID_WRONG: ALTAR_TRUTH,
	ID_SHAME: ALTAR_TRUTH,
	ID_HYTHLOTH: ALTAR_TRUTH,
	ID_DESPISE: ALTAR_LOVE,
	ID_COVETOUS: ALTAR_LOVE,
	ID_DESTARD: ALTAR_COURAGE,
}

## Stones required at each altar room (four connecting virtues).
const ALTAR_STONES := {
	ALTAR_TRUTH: 0x01 | 0x08 | 0x20 | 0x40, ## blue green purple white
	ALTAR_LOVE: 0x02 | 0x10 | 0x08 | 0x40, ## yellow orange green white
	ALTAR_COURAGE: 0x04 | 0x20 | 0x10 | 0x40, ## red purple orange white
}

const ALTAR_KEY := {
	ALTAR_TRUTH: 0x80, ## ITEM_KEY_T
	ALTAR_LOVE: 0x40, ## ITEM_KEY_L
	ALTAR_COURAGE: 0x20, ## ITEM_KEY_C
}

## Leave altar room in dir → destination dungeon (level 8, start cell).
const ALTAR_EXITS := {
	ALTAR_TRUTH: [ID_DECEIT, ID_WRONG, ID_SHAME, ID_HYTHLOTH],
	ALTAR_LOVE: [ID_DESPISE, ID_COVETOUS, ID_WRONG, ID_HYTHLOTH],
	ALTAR_COURAGE: [ID_DESTARD, ID_SHAME, ID_COVETOUS, ID_HYTHLOTH],
}

## Abyss corridor altars: use matching stone. Level → stone flag.
const ABYSS_STONE_LEVEL := [
	0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80,
]


static func key_at(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]


static func world_portal_at(pos: Vector2i) -> Dictionary:
	var k := key_at(pos)
	if not WORLD.has(k):
		return {}
	var p: Dictionary = (WORLD[k] as Dictionary).duplicate()
	p["wx"] = pos.x
	p["wy"] = pos.y
	p["sx"] = START.x
	p["sy"] = START.y
	p["sz"] = 0
	p["dir"] = START_DIR
	return p


static func abyss_portal() -> Dictionary:
	return {
		"id": ID_ABYSS,
		"fname": "ABYSS.DNG",
		"wx": ABYSS_ENTRANCE.x,
		"wy": ABYSS_ENTRANCE.y,
		"sx": START.x,
		"sy": START.y,
		"sz": 0,
		"dir": START_DIR,
		"abyss": true,
	}


static func city_portal_at(fname: String, pos: Vector2i, action: int) -> Dictionary:
	var key := fname.get_file().to_lower()
	if not CITY.has(key):
		return {}
	for row in CITY[key]:
		var d: Dictionary = row
		if int(d.get("x", -1)) != pos.x or int(d.get("y", -1)) != pos.y:
			continue
		if int(d.get("action", 0)) != action:
			continue
		var out := d.duplicate()
		out["city_fname"] = key
		out["sx"] = START.x
		out["sy"] = START.y
		out["sz"] = 0
		out["dir"] = START_DIR
		return out
	return {}


static func theme_for(id: String) -> String:
	return str(THEME_OF.get(id, THEME_GREY))


static func fname_for(id: String) -> String:
	return str(FNAME_OF.get(id, ""))


static func index_for(id: String) -> int:
	return int(INDEX_OF.get(id, -1))


static func con_for_token(tok: int) -> String:
	## DNG0–DNG6 describe the current corridor cell, not the dungeon identity.
	match tok:
		_DungeonMap.TOK_LADDER_UP:
			return "DNG1.CON"
		_DungeonMap.TOK_LADDER_DOWN:
			return "DNG2.CON"
		_DungeonMap.TOK_LADDER_BOTH:
			return "DNG3.CON"
		_DungeonMap.TOK_CHEST:
			return "DNG4.CON"
		_DungeonMap.TOK_DOOR:
			return "DNG5.CON"
		_DungeonMap.TOK_SECRET:
			return "DNG6.CON"
		_:
			return "DNG0.CON"


static func world_return_for(id: String) -> Vector2i:
	if id == ID_ABYSS:
		return ABYSS_ENTRANCE
	for k in WORLD.keys():
		var p: Dictionary = WORLD[k]
		if str(p.get("id", "")) == id:
			var parts := str(k).split(",")
			if parts.size() == 2:
				return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i.ZERO


static func stone_at(id: String, pos: Vector2i, z: int) -> int:
	if not STONE_AT.has(id):
		return 0
	var s: Dictionary = STONE_AT[id]
	if int(s.get("x", -1)) != pos.x or int(s.get("y", -1)) != pos.y or int(s.get("z", -1)) != z:
		return 0
	return int(s.get("flag", 0))


static func orb_stat_mask(id: String) -> int:
	return int(ORB_STATS.get(id, 0))


static func altar_kind_for(id: String) -> int:
	return int(ALTAR_KIND.get(id, -1))


static func altar_exit_dungeon(kind: int, dir: int) -> String:
	if not ALTAR_EXITS.has(kind):
		return ""
	var ids: Array = ALTAR_EXITS[kind]
	var i := posmod(dir, 4)
	if i < 0 or i >= ids.size():
		return ""
	return str(ids[i])


static func abyss_stone_for_level(z: int) -> int:
	if z < 0 or z >= ABYSS_STONE_LEVEL.size():
		return 0
	return int(ABYSS_STONE_LEVEL[z])


static func bbc_ready() -> bool:
	return (
		GameState.has_item_flag(GameState.ITEM_BELL_USED)
		and GameState.has_item_flag(GameState.ITEM_BOOK_USED)
		and GameState.has_item_flag(GameState.ITEM_CANDLE_USED)
	)


static func has_three_keys() -> bool:
	return (
		GameState.has_item_flag(GameState.ITEM_KEY_T)
		and GameState.has_item_flag(GameState.ITEM_KEY_L)
		and GameState.has_item_flag(GameState.ITEM_KEY_C)
	)


static func stone_name_key(flag: int) -> String:
	match flag:
		0x01:
			return "ztats_item_stone_blue"
		0x02:
			return "ztats_item_stone_yellow"
		0x04:
			return "ztats_item_stone_red"
		0x08:
			return "ztats_item_stone_green"
		0x10:
			return "ztats_item_stone_orange"
		0x20:
			return "ztats_item_stone_purple"
		0x40:
			return "ztats_item_stone_white"
		0x80:
			return "ztats_item_stone_black"
		_:
			return "ztats_item_stone_blue"


static func key_name_key(flag: int) -> String:
	match flag:
		0x80:
			return "cmd_principle_truth"
		0x40:
			return "cmd_principle_love"
		0x20:
			return "cmd_principle_courage"
		_:
			return "cmd_principle_truth"


static func dir_from_vec(dir: Vector2i) -> int:
	if dir.y < 0:
		return _DungeonMap.DIR_N
	if dir.x > 0:
		return _DungeonMap.DIR_E
	if dir.y > 0:
		return _DungeonMap.DIR_S
	if dir.x < 0:
		return _DungeonMap.DIR_W
	return _DungeonMap.DIR_S


static func vec_from_dir(d: int) -> Vector2i:
	return _DungeonMap.DIRS[posmod(d, 4)]


static func all_world_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in WORLD.keys():
		var p: Dictionary = (WORLD[k] as Dictionary).duplicate()
		var parts := str(k).split(",")
		if parts.size() != 2:
			continue
		p["wx"] = int(parts[0])
		p["wy"] = int(parts[1])
		out.append(p)
	return out
