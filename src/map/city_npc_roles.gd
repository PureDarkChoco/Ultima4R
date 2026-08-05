class_name CityNpcRoles
extends RefCounted

## xu4 PersonNpcType + maps.b city roles (person id is 1-based .ULT slot).

enum Role {
	NONE = 0,
	TALKER = 1,
	BEGGAR = 2,
	GUARD = 3,
	COMPANION = 4,
	VENDOR_WEAPONS = 5,
	VENDOR_ARMOR = 6,
	VENDOR_FOOD = 7,
	VENDOR_TAVERN = 8,
	VENDOR_REAGENTS = 9,
	VENDOR_HEALER = 10,
	VENDOR_INN = 11,
	VENDOR_GUILD = 12,
	VENDOR_STABLE = 13,
	LORD_BRITISH = 14,
	HAWKWIND = 15,
}


static func is_vendor(role: int) -> bool:
	return role >= Role.VENDOR_WEAPONS and role <= Role.VENDOR_STABLE


static func is_shop_like(role: int) -> bool:
	## Vendor scripts / special NPCs that do not use .TLK.
	return is_vendor(role) or role == Role.LORD_BRITISH or role == Role.HAWKWIND


static func role_name_en(role: int) -> String:
	match role:
		Role.VENDOR_WEAPONS:
			return "weapons vendor"
		Role.VENDOR_ARMOR:
			return "armourer"
		Role.VENDOR_FOOD:
			return "food vendor"
		Role.VENDOR_TAVERN:
			return "tavernkeeper"
		Role.VENDOR_REAGENTS:
			return "reagents peddler"
		Role.VENDOR_HEALER:
			return "healer"
		Role.VENDOR_INN:
			return "innkeeper"
		Role.VENDOR_GUILD:
			return "guild broker"
		Role.VENDOR_STABLE:
			return "stablemaster"
		Role.LORD_BRITISH:
			return "Lord British"
		Role.HAWKWIND:
			return "Hawkwind"
		Role.COMPANION:
			return "companion"
		_:
			return "shopkeeper"


## 1-based .ULT person slots → Role (from xu4 maps.b).
static func roles_for_ult(ult_basename: String) -> Dictionary:
	var key := ult_basename.get_file().to_lower()
	match key:
		"lcb_1.ult":
			return {29: Role.VENDOR_HEALER, 30: Role.HAWKWIND}
		"lcb_2.ult":
			return {32: Role.LORD_BRITISH}
		"lycaeum.ult":
			return {23: Role.VENDOR_HEALER}
		"empath.ult":
			return {30: Role.VENDOR_HEALER}
		"serpent.ult":
			return {31: Role.VENDOR_HEALER}
		"moonglow.ult":
			return {
				32: Role.COMPANION,
				26: Role.VENDOR_FOOD,
				24: Role.VENDOR_REAGENTS,
				25: Role.VENDOR_HEALER,
				30: Role.VENDOR_INN,
			}
		"britain.ult":
			return {
				32: Role.COMPANION,
				29: Role.VENDOR_WEAPONS,
				28: Role.VENDOR_ARMOR,
				27: Role.VENDOR_FOOD,
				26: Role.VENDOR_TAVERN,
				31: Role.VENDOR_HEALER,
				25: Role.VENDOR_INN,
			}
		"jhelom.ult":
			return {
				32: Role.COMPANION,
				29: Role.VENDOR_WEAPONS,
				28: Role.VENDOR_ARMOR,
				30: Role.VENDOR_TAVERN,
				25: Role.VENDOR_HEALER,
				26: Role.VENDOR_HEALER,
				27: Role.VENDOR_HEALER,
				31: Role.VENDOR_INN,
			}
		"yew.ult":
			return {
				32: Role.COMPANION,
				27: Role.VENDOR_FOOD,
				26: Role.VENDOR_HEALER,
			}
		"minoc.ult":
			return {
				32: Role.COMPANION,
				30: Role.VENDOR_WEAPONS,
				31: Role.VENDOR_INN,
			}
		"trinsic.ult":
			return {
				32: Role.COMPANION,
				29: Role.VENDOR_WEAPONS,
				28: Role.VENDOR_ARMOR,
				31: Role.VENDOR_TAVERN,
				30: Role.VENDOR_INN,
			}
		"skara.ult":
			return {
				32: Role.COMPANION,
				28: Role.VENDOR_FOOD,
				30: Role.VENDOR_REAGENTS,
				31: Role.VENDOR_HEALER,
				29: Role.VENDOR_INN,
			}
		"magincia.ult":
			return {32: Role.COMPANION}
		"paws.ult":
			return {
				27: Role.VENDOR_ARMOR,
				31: Role.VENDOR_FOOD,
				30: Role.VENDOR_TAVERN,
				29: Role.VENDOR_TAVERN,
				28: Role.VENDOR_REAGENTS,
				18: Role.VENDOR_STABLE,
			}
		"den.ult":
			return {
				28: Role.VENDOR_WEAPONS,
				27: Role.VENDOR_ARMOR,
				26: Role.VENDOR_TAVERN,
				30: Role.VENDOR_REAGENTS,
				29: Role.VENDOR_GUILD,
			}
		"vesper.ult":
			return {
				25: Role.VENDOR_WEAPONS,
				23: Role.VENDOR_TAVERN,
				26: Role.VENDOR_INN,
				24: Role.VENDOR_GUILD,
			}
		"cove.ult":
			return {31: Role.VENDOR_HEALER}
		_:
			return {}
