class_name ArmorIcons
extends Object

## Ultima IV armor icon registry (xu4 ARMR_* indices).
## Art lives in `res://assets/ui/armor/`.

enum Id {
	NONE = 0,
	CLOTH = 1,
	LEATHER = 2,
	CHAIN = 3,
	PLATE = 4,
	MAGIC_CHAIN = 5,
	MAGIC_PLATE = 6,
	MYSTIC_ROBE = 7,
}

const DIR := "res://assets/ui/armor/"

## Icon path by armor id.
const PATHS := {
	Id.CLOTH: DIR + "cloth.png",
	Id.LEATHER: DIR + "leather.png",
	Id.CHAIN: DIR + "chain.png",
	Id.PLATE: DIR + "plate.png",
	Id.MAGIC_CHAIN: DIR + "magic_chain.png",
	Id.MAGIC_PLATE: DIR + "magic_plate.png",
	Id.MYSTIC_ROBE: DIR + "mystic_robe.png",
}

const NAME_TO_ID := {
	"none": Id.NONE,
	"no armour": Id.NONE,
	"no armor": Id.NONE,
	"cloth": Id.CLOTH,
	"leather": Id.LEATHER,
	"chain": Id.CHAIN,
	"chain mail": Id.CHAIN,
	"plate": Id.PLATE,
	"plate mail": Id.PLATE,
	"magic chain": Id.MAGIC_CHAIN,
	"magical chain": Id.MAGIC_CHAIN,
	"magic plate": Id.MAGIC_PLATE,
	"magical plate": Id.MAGIC_PLATE,
	"mystic robe": Id.MYSTIC_ROBE,
}

## xu4 config.b armor defense by id (Skin/No Armour = 96).
const DEFENSE: Array[int] = [
	96, 128, 144, 160, 176, 192, 208, 248,
]

## xu4 config.b canuse bitmask per ClassId (bit N = class N may wear).
const CANUSE: Array[int] = [
	0xFF, ## Skin / No Armour — all
	0xFF, ## Cloth — all
	0xFE, ## Leather — not mage
	0x34, ## Chain — fighter/tinker/paladin
	0x34, ## Plate — fighter/tinker/paladin
	0x24, ## Magic Chain — fighter/paladin
	0x20, ## Magic Plate — paladin
	0xFF, ## Mystic Robe — all
]


static func defense_of(armor_id: int) -> int:
	if armor_id < 0 or armor_id >= DEFENSE.size():
		return 0
	return DEFENSE[armor_id]


static func can_wear(armor_id: int, klass: int) -> bool:
	## xu4 Armor::canWear — class bit set in canuse.
	if armor_id < 0 or armor_id >= CANUSE.size():
		return false
	if klass < 0 or klass > 7:
		return false
	return (CANUSE[armor_id] & (1 << klass)) != 0


static func path_for_id(armor_id: int) -> String:
	return str(PATHS.get(armor_id, ""))


static func path_for_name(armor_name: String) -> String:
	var key := armor_name.strip_edges().to_lower()
	if not NAME_TO_ID.has(key):
		return ""
	return path_for_id(int(NAME_TO_ID[key]))


static func texture_for_id(armor_id: int) -> Texture2D:
	var path := path_for_id(armor_id)
	if path.is_empty():
		return null
	return load(path) as Texture2D


static func texture_for_name(armor_name: String) -> Texture2D:
	var path := path_for_name(armor_name)
	if path.is_empty():
		return null
	return load(path) as Texture2D
