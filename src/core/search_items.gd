class_name SearchItems
extends RefCounted

## xu4 item.cpp Search (S) — location labels + grant handlers.
## Prefer preload over bare class_name at call sites (stale global class cache).

enum Kind {
	REAGENT = 0,
	QUEST_ITEM = 1,
	SKULL = 2,
	STONE = 3,
	RUNE = 4,
	MYSTIC_ARMOR = 5,
	MYSTIC_WEAPON = 6,
	TELESCOPE = 7,
	UNIQUE_WEAPON = 8,
}

const SC_NEWMOONS := 0x01
const SC_FULLAVATAR := 0x02
const SC_REAGENTDELAY := 0x04

## World map labels (xu4 maps.b map id 0). Key "x,y" → label.
const WORLD_LABELS := {
	"182,54": "mandrake1",
	"100,165": "mandrake2",
	"46,149": "nightshade1",
	"205,44": "nightshade2",
	"176,208": "bell",
	"45,173": "horn",
	"96,215": "wheel",
	"197,245": "skull",
	"224,133": "blackstone",
	"64,80": "whitestone",
}

## City .ULT basename (lower) → { "x,y": label }.
const CITY_LABELS := {
	"lcb_1.ult": {"17,8": "spiritualityrune"},
	"lycaeum.ult": {"6,6": "book", "22,3": "telescope"},
	"empath.ult": {"22,4": "mysticarmor"},
	"serpent.ult": {"8,15": "mysticswords"},
	"moonglow.ult": {"8,6": "honestyrune"},
	"britain.ult": {"25,1": "compassionrune"},
	"jhelom.ult": {"30,30": "valorrune", "1,5": "jhelommagicaxe"},
	"yew.ult": {"13,6": "justicerune"},
	"minoc.ult": {"28,30": "sacrificerune"},
	"trinsic.ult": {"2,29": "honorrune"},
	"paws.ult": {"29,29": "humilityrune"},
	"cove.ult": {"22,1": "candle"},
}

## label → { kind, data, conditions, name_key }
const ITEMS := {
	"mandrake1": {
		"kind": Kind.REAGENT,
		"data": 7, ## ReagentIcons.Id.MANDRAKE_ROOT
		"conditions": SC_NEWMOONS | SC_REAGENTDELAY,
		"name_key": "search_item_mandrake",
	},
	"mandrake2": {
		"kind": Kind.REAGENT,
		"data": 7,
		"conditions": SC_NEWMOONS | SC_REAGENTDELAY,
		"name_key": "search_item_mandrake",
	},
	"nightshade1": {
		"kind": Kind.REAGENT,
		"data": 6, ## ReagentIcons.Id.NIGHTSHADE
		"conditions": SC_NEWMOONS | SC_REAGENTDELAY,
		"name_key": "search_item_nightshade",
	},
	"nightshade2": {
		"kind": Kind.REAGENT,
		"data": 6,
		"conditions": SC_NEWMOONS | SC_REAGENTDELAY,
		"name_key": "search_item_nightshade",
	},
	## data bits match GameState ITEM_*/STONE_*/RUNE_* (savegame.h).
	"bell": {"kind": Kind.QUEST_ITEM, "data": 0x10, "conditions": 0, "name_key": "search_item_bell"},
	"book": {"kind": Kind.QUEST_ITEM, "data": 0x08, "conditions": 0, "name_key": "search_item_book"},
	"candle": {"kind": Kind.QUEST_ITEM, "data": 0x04, "conditions": 0, "name_key": "search_item_candle"},
	"horn": {"kind": Kind.QUEST_ITEM, "data": 0x100, "conditions": 0, "name_key": "search_item_horn"},
	"wheel": {"kind": Kind.QUEST_ITEM, "data": 0x200, "conditions": 0, "name_key": "search_item_wheel"},
	"skull": {"kind": Kind.SKULL, "data": 0x01, "conditions": SC_NEWMOONS, "name_key": "search_item_skull"},
	"redstone": {"kind": Kind.STONE, "data": 0x04, "conditions": 0, "name_key": "search_item_stone_red"},
	"orangestone": {"kind": Kind.STONE, "data": 0x10, "conditions": 0, "name_key": "search_item_stone_orange"},
	"yellowstone": {"kind": Kind.STONE, "data": 0x02, "conditions": 0, "name_key": "search_item_stone_yellow"},
	"greenstone": {"kind": Kind.STONE, "data": 0x08, "conditions": 0, "name_key": "search_item_stone_green"},
	"bluestone": {"kind": Kind.STONE, "data": 0x01, "conditions": 0, "name_key": "search_item_stone_blue"},
	"purplestone": {"kind": Kind.STONE, "data": 0x20, "conditions": 0, "name_key": "search_item_stone_purple"},
	"blackstone": {"kind": Kind.STONE, "data": 0x80, "conditions": SC_NEWMOONS, "name_key": "search_item_stone_black"},
	"whitestone": {"kind": Kind.STONE, "data": 0x40, "conditions": 0, "name_key": "search_item_stone_white"},
	"mysticarmor": {
		"kind": Kind.MYSTIC_ARMOR,
		"data": 7, ## ArmorIcons.Id.MYSTIC_ROBE
		"conditions": SC_FULLAVATAR,
		"name_key": "search_item_mystic_armor",
	},
	"mysticswords": {
		"kind": Kind.MYSTIC_WEAPON,
		"data": 15, ## WeaponIcons.Id.MYSTIC_SWORD
		"conditions": SC_FULLAVATAR,
		"name_key": "search_item_mystic_swords",
	},
	"telescope": {"kind": Kind.TELESCOPE, "data": 0, "conditions": 0, "name_key": ""},
	"honestyrune": {"kind": Kind.RUNE, "data": 0x01, "conditions": 0, "name_key": "search_item_rune_honesty"},
	"compassionrune": {"kind": Kind.RUNE, "data": 0x02, "conditions": 0, "name_key": "search_item_rune_compassion"},
	"valorrune": {"kind": Kind.RUNE, "data": 0x04, "conditions": 0, "name_key": "search_item_rune_valor"},
	"justicerune": {"kind": Kind.RUNE, "data": 0x08, "conditions": 0, "name_key": "search_item_rune_justice"},
	"sacrificerune": {"kind": Kind.RUNE, "data": 0x10, "conditions": 0, "name_key": "search_item_rune_sacrifice"},
	"honorrune": {"kind": Kind.RUNE, "data": 0x20, "conditions": 0, "name_key": "search_item_rune_honor"},
	"spiritualityrune": {"kind": Kind.RUNE, "data": 0x40, "conditions": 0, "name_key": "search_item_rune_spirituality"},
	"humilityrune": {"kind": Kind.RUNE, "data": 0x80, "conditions": 0, "name_key": "search_item_rune_humility"},
	"jhelommagicaxe": {
		"kind": Kind.UNIQUE_WEAPON,
		"data": 11, ## WeaponIcons.Id.MAGIC_AXE
		"conditions": 0,
		"name_key": "search_item_magic_axe",
	},
}

## xu4 telescope A–P → city .ULT (maps id 1..16).
const TELESCOPE_CITIES := [
	"lcb_1.ult",
	"lycaeum.ult",
	"empath.ult",
	"serpent.ult",
	"moonglow.ult",
	"britain.ult",
	"jhelom.ult",
	"yew.ult",
	"minoc.ult",
	"trinsic.ult",
	"skara.ult",
	"magincia.ult",
	"paws.ult",
	"den.ult",
	"vesper.ult",
	"cove.ult",
]


static func label_at(city_fname: String, pos: Vector2i) -> String:
	var key := "%d,%d" % [pos.x, pos.y]
	var fname := city_fname.get_file().to_lower()
	if fname.is_empty():
		return str(WORLD_LABELS.get(key, ""))
	var city: Variant = CITY_LABELS.get(fname, {})
	if typeof(city) != TYPE_DICTIONARY:
		return ""
	return str((city as Dictionary).get(key, ""))


static func item_at(city_fname: String, pos: Vector2i) -> Dictionary:
	## xu4 itemAtLocation — label match + conditions. Empty if nothing.
	var label := label_at(city_fname, pos)
	if label.is_empty() or not ITEMS.has(label):
		return {}
	var item: Dictionary = ITEMS[label]
	if not _conditions_met(int(item.get("conditions", 0))):
		return {}
	var out := item.duplicate()
	out["label"] = label
	return out


static func _conditions_met(conditions: int) -> bool:
	if (conditions & SC_NEWMOONS) != 0:
		if GameState.trammel_phase != 0 or GameState.felucca_phase != 0:
			return false
	if (conditions & SC_FULLAVATAR) != 0 and not GameState.is_full_avatar():
		return false
	if (conditions & SC_REAGENTDELAY) != 0 and GameState.reagent_delay_blocks():
		return false
	return true


static func is_owned(item: Dictionary) -> bool:
	## xu4 is*InInventory. Reagents always false (repeatable harvest).
	var kind := int(item.get("kind", -1))
	var data := int(item.get("data", 0))
	match kind:
		Kind.REAGENT, Kind.TELESCOPE:
			return false
		Kind.QUEST_ITEM:
			return GameState.has_item_flag(data)
		Kind.SKULL:
			return GameState.has_item_flag(GameState.ITEM_SKULL | GameState.ITEM_SKULL_DESTROYED)
		Kind.STONE:
			return GameState.has_stone(data)
		Kind.RUNE:
			return GameState.has_rune(data)
		Kind.MYSTIC_ARMOR:
			return GameState.armor.size() > data and int(GameState.armor[data]) > 0
		Kind.MYSTIC_WEAPON:
			return GameState.weapons.size() > data and int(GameState.weapons[data]) > 0
		Kind.UNIQUE_WEAPON:
			return GameState.has_search_taken(str(item.get("label", "")))
		_:
			return false


static func grant(item: Dictionary) -> Dictionary:
	## Apply put*InInventory. Returns { dropped: bool, telescope: bool }.
	var kind := int(item.get("kind", -1))
	var data := int(item.get("data", 0))
	var dropped := false
	match kind:
		Kind.REAGENT:
			dropped = GameState.grant_search_reagent(data)
		Kind.QUEST_ITEM, Kind.SKULL:
			GameState.grant_quest_item(data, 400)
		Kind.STONE:
			GameState.grant_stone(data)
		Kind.RUNE:
			GameState.grant_rune(data)
		Kind.MYSTIC_ARMOR:
			GameState.grant_mystic_armor()
		Kind.MYSTIC_WEAPON:
			GameState.grant_mystic_weapon()
		Kind.TELESCOPE:
			return {"dropped": false, "telescope": true}
		Kind.UNIQUE_WEAPON:
			GameState.grant_unique_search_weapon(data, str(item.get("label", "")))
		_:
			pass
	return {"dropped": dropped, "telescope": false}


static func telescope_city_fname(choice_index: int) -> String:
	## choice_index 0..15 for A..P.
	if choice_index < 0 or choice_index >= TELESCOPE_CITIES.size():
		return ""
	return str(TELESCOPE_CITIES[choice_index])
