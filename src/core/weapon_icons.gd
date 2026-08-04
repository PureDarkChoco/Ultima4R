class_name WeaponIcons
extends Object

## Ultima IV weapon icon registry (xu4 WEAP_* indices).
## Art lives in `res://assets/ui/weapons/`.

enum Id {
	HANDS = 0,
	STAFF = 1,
	DAGGER = 2,
	SLING = 3,
	MACE = 4,
	AXE = 5,
	SWORD = 6,
	BOW = 7,
	CROSSBOW = 8,
	FLAMING_OIL = 9,
	HALBERD = 10,
	MAGIC_AXE = 11,
	MAGIC_SWORD = 12,
	MAGIC_BOW = 13,
	MAGIC_WAND = 14,
	MYSTIC_SWORD = 15,
}

const DIR := "res://assets/ui/weapons/"

## Icon path by weapon id. Hands (0) has no dedicated art.
const PATHS := {
	Id.STAFF: DIR + "staff.png",
	Id.DAGGER: DIR + "dagger.png",
	Id.SLING: DIR + "sling.png",
	Id.MACE: DIR + "mace.png",
	Id.AXE: DIR + "axe.png",
	Id.SWORD: DIR + "sword.png",
	Id.BOW: DIR + "bow.png",
	Id.CROSSBOW: DIR + "crossbow.png",
	Id.FLAMING_OIL: DIR + "flaming_oil.png",
	Id.HALBERD: DIR + "halberd.png",
	Id.MAGIC_AXE: DIR + "magic_axe.png",
	Id.MAGIC_SWORD: DIR + "magic_sword.png",
	Id.MAGIC_BOW: DIR + "magic_bow.png",
	Id.MAGIC_WAND: DIR + "magic_wand.png",
	Id.MYSTIC_SWORD: DIR + "mystic_sword.png",
}

## Display name → weapon id (case-insensitive lookup helpers below).
const NAME_TO_ID := {
	"hands": Id.HANDS,
	"staff": Id.STAFF,
	"dagger": Id.DAGGER,
	"sling": Id.SLING,
	"mace": Id.MACE,
	"axe": Id.AXE,
	"sword": Id.SWORD,
	"bow": Id.BOW,
	"crossbow": Id.CROSSBOW,
	"flaming oil": Id.FLAMING_OIL,
	"oil": Id.FLAMING_OIL,
	"halberd": Id.HALBERD,
	"magic axe": Id.MAGIC_AXE,
	"magical axe": Id.MAGIC_AXE,
	"magic sword": Id.MAGIC_SWORD,
	"magical sword": Id.MAGIC_SWORD,
	"magic bow": Id.MAGIC_BOW,
	"magical bow": Id.MAGIC_BOW,
	"magic wand": Id.MAGIC_WAND,
	"magical wand": Id.MAGIC_WAND,
	"wand": Id.MAGIC_WAND,
	"mystic sword": Id.MYSTIC_SWORD,
}

## xu4 config.b weapon damage by id.
const DAMAGE: Array[int] = [
	8, 16, 24, 32, 40, 48, 64, 40, 56, 64, 96, 96, 128, 80, 160, 255,
]

## Combat aim range by id (−1 = unlimited magic ranged).
## Dagger is not listed independently — always oil range + 1 (see range_of).
## Sling 8, Oil 6, Bow 7, Crossbow 8; Magic Axe/Bow/Wand unlimited.
const RANGE: Array[int] = [
	1, 1, 0, 8, 1, 1, 1, 7, 8, 6, 2, -1, 1, -1, -1, 1,
]

## xu4 WEAP_ABSOLUTERANGE — only hits at exact distance (Halberd).
const ABSOLUTE_RANGE: Array[bool] = [
	false, false, false, false, false, false, false, false, false, false,
	true, false, false, false, false, false,
]

## xu4 WEAP_ATTACKTHROUGHOBJECTS — Halberd ignores solid blockers.
const ATTACK_THROUGH: Array[bool] = [
	false, false, false, false, false, false, false, false, false, false,
	true, false, false, false, false, false,
]

## Magic ranged — no max distance on the combat map.
const UNLIMITED_RANGE: Array[bool] = [
	false, false, false, false, false, false, false, false, false, false,
	false, true, false, true, true, false,
]

## xu4 WEAP_LOSEWHENRANGED — consumed when used beyond melee (Dagger).
const LOSE_WHEN_RANGED: Array[bool] = [
	false, false, true, false, false, false, false, false, false, false,
	false, false, false, false, false, false,
]

## xu4 WEAP_LOSE — always consumed on use (Flaming Oil).
const LOSE_WHEN_USED: Array[bool] = [
	false, false, false, false, false, false, false, false, false, true,
	false, false, false, false, false, false,
]

## xu4 config.b canuse bitmask per ClassId (bit N = class N may ready).
## Derived from not/only lists in module/Ultima-IV/config.b.
const CANUSE: Array[int] = [
	0xFF, ## Hands — all
	0xFF, ## Staff — all
	0xFF, ## Dagger — all
	0xFF, ## Sling — all
	0xFE, ## Mace — not mage
	0xF6, ## Axe — not mage/druid
	0xF6, ## Sword — not mage/druid
	0x7E, ## Bow — not mage/shepherd
	0x7E, ## Crossbow — not mage/shepherd
	0xFF, ## Flaming Oil — all
	0x34, ## Halberd — fighter/tinker/paladin
	0x30, ## Magic Axe — tinker/paladin
	0x74, ## Magic Sword — fighter/tinker/paladin/ranger
	0x7A, ## Magic Bow — not mage/fighter/shepherd
	0x0B, ## Magic Wand — mage/bard/druid
	0xFF, ## Mystic Sword — all
]


static func damage_of(weapon_id: int) -> int:
	if weapon_id < 0 or weapon_id >= DAMAGE.size():
		return 0
	return DAMAGE[weapon_id]


static func range_of(weapon_id: int) -> int:
	## Max aim distance; huge sentinel for unlimited magic ranged.
	## Dagger: xu4 10 = oil 9 + 1 — derived here so oil changes stay in sync.
	if is_unlimited_range(weapon_id):
		return 99
	if weapon_id == Id.DAGGER:
		return maxi(1, range_of(Id.FLAMING_OIL) + 1)
	if weapon_id < 0 or weapon_id >= RANGE.size():
		return 1
	return maxi(1, RANGE[weapon_id])


static func is_unlimited_range(weapon_id: int) -> bool:
	if weapon_id < 0 or weapon_id >= UNLIMITED_RANGE.size():
		return false
	return UNLIMITED_RANGE[weapon_id]


static func is_melee(weapon_id: int) -> bool:
	## Range-1 non-absolute weapons: U5-style 8-direction adjacent aim.
	## Must use range_of (not RANGE[]): Dagger stores 0 in RANGE and
	## derives oil+1 there — RANGE[dagger] <= 1 wrongly forced melee.
	if is_absolute_range(weapon_id):
		return false
	return range_of(weapon_id) <= 1


static func is_absolute_range(weapon_id: int) -> bool:
	if weapon_id < 0 or weapon_id >= ABSOLUTE_RANGE.size():
		return false
	return ABSOLUTE_RANGE[weapon_id]


static func attacks_through_objects(weapon_id: int) -> bool:
	if weapon_id < 0 or weapon_id >= ATTACK_THROUGH.size():
		return false
	return ATTACK_THROUGH[weapon_id]


static func loses_when_ranged(weapon_id: int) -> bool:
	if weapon_id < 0 or weapon_id >= LOSE_WHEN_RANGED.size():
		return false
	return LOSE_WHEN_RANGED[weapon_id]


static func loses_when_used(weapon_id: int) -> bool:
	if weapon_id < 0 or weapon_id >= LOSE_WHEN_USED.size():
		return false
	return LOSE_WHEN_USED[weapon_id]


static func leaves_field(weapon_id: int) -> bool:
	## xu4 leaveTile (flaming oil → fire_field).
	return weapon_id == Id.FLAMING_OIL


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func aim_distance(a: Vector2i, b: Vector2i) -> int:
	## Orthogonal = 1, diagonal = 1.5, then round to nearest int.
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	var raw := float(maxi(dx, dy)) + 0.5 * float(mini(dx, dy))
	return int(round(raw))


static func aim_cursor_allows(weapon_id: int, from: Vector2i, to: Vector2i) -> bool:
	## Where the U5 aim cursor may sit (self allowed as a hub / cancel rest).
	if to == from:
		return true
	if is_melee(weapon_id):
		return chebyshev(from, to) == 1
	if is_unlimited_range(weapon_id):
		return true
	var dist := aim_distance(from, to)
	var rng := range_of(weapon_id)
	if is_absolute_range(weapon_id):
		## Cursor may travel through tiles up to the absolute ring.
		return dist <= rng
	return dist <= rng


static func aim_strike_allows(weapon_id: int, from: Vector2i, to: Vector2i) -> bool:
	## Confirm-attack cell validity (self never strikes).
	if to == from:
		return false
	if is_melee(weapon_id):
		return chebyshev(from, to) == 1
	if is_unlimited_range(weapon_id):
		return true
	var dist := aim_distance(from, to)
	var rng := range_of(weapon_id)
	if is_absolute_range(weapon_id):
		return dist == rng
	return dist >= 1 and dist <= rng


static func can_ready(weapon_id: int, klass: int) -> bool:
	## xu4 Weapon::canReady — class bit set in canuse.
	if weapon_id < 0 or weapon_id >= CANUSE.size():
		return false
	if klass < 0 or klass > 7:
		return false
	return (CANUSE[weapon_id] & (1 << klass)) != 0


static func path_for_id(weapon_id: int) -> String:
	return str(PATHS.get(weapon_id, ""))


static func path_for_name(weapon_name: String) -> String:
	var key := weapon_name.strip_edges().to_lower()
	if not NAME_TO_ID.has(key):
		return ""
	return path_for_id(int(NAME_TO_ID[key]))


static func texture_for_id(weapon_id: int) -> Texture2D:
	var path := path_for_id(weapon_id)
	if path.is_empty():
		return null
	return load(path) as Texture2D


static func texture_for_name(weapon_name: String) -> Texture2D:
	var path := path_for_name(weapon_name)
	if path.is_empty():
		return null
	return load(path) as Texture2D
