class_name UseItems
extends Object

## Usable quest items (xu4 itemUse shortlist) for the Use (U) command list.
## Not listed: virtue runes, inventory keys/jimmy keys (GameState.keys count).

const _SpecialItemIcons := preload("res://src/core/special_item_icons.gd")

## Row kinds — order matches common inventory presentation.
enum Kind {
	BELL = 0,
	BOOK = 1,
	CANDLE = 2,
	HORN = 3,
	WHEEL = 4,
	SKULL = 5,
	KEY_TRUTH = 6,
	KEY_LOVE = 7,
	KEY_COURAGE = 8,
	STONE_BLUE = 9,
	STONE_YELLOW = 10,
	STONE_RED = 11,
	STONE_GREEN = 12,
	STONE_ORANGE = 13,
	STONE_PURPLE = 14,
	STONE_WHITE = 15,
	STONE_BLACK = 16,
}


static func has_any() -> bool:
	return not owned_kinds().is_empty()


static func owned_kinds() -> Array[int]:
	var out: Array[int] = []
	if GameState.has_item_flag(GameState.ITEM_BELL):
		out.append(Kind.BELL)
	if GameState.has_item_flag(GameState.ITEM_BOOK):
		out.append(Kind.BOOK)
	if GameState.has_item_flag(GameState.ITEM_CANDLE):
		out.append(Kind.CANDLE)
	if GameState.has_item_flag(GameState.ITEM_HORN):
		out.append(Kind.HORN)
	if GameState.has_item_flag(GameState.ITEM_WHEEL):
		out.append(Kind.WHEEL)
	if GameState.has_item_flag(GameState.ITEM_SKULL):
		out.append(Kind.SKULL)
	if GameState.has_item_flag(GameState.ITEM_KEY_T):
		out.append(Kind.KEY_TRUTH)
	if GameState.has_item_flag(GameState.ITEM_KEY_L):
		out.append(Kind.KEY_LOVE)
	if GameState.has_item_flag(GameState.ITEM_KEY_C):
		out.append(Kind.KEY_COURAGE)
	for i in 8:
		if GameState.has_stone(1 << i):
			out.append(Kind.STONE_BLUE + i)
	return out


static func name_key(kind: int) -> String:
	match kind:
		Kind.BELL:
			return "ztats_item_bell"
		Kind.BOOK:
			return "ztats_item_book"
		Kind.CANDLE:
			return "ztats_item_candle"
		Kind.HORN:
			return "ztats_item_horn"
		Kind.WHEEL:
			return "ztats_item_wheel"
		Kind.SKULL:
			return "ztats_item_skull"
		Kind.KEY_TRUTH:
			return "ztats_item_key_truth"
		Kind.KEY_LOVE:
			return "ztats_item_key_love"
		Kind.KEY_COURAGE:
			return "ztats_item_key_courage"
		_:
			if kind >= Kind.STONE_BLUE and kind <= Kind.STONE_BLACK:
				return _SpecialItemIcons.stone_name_key(kind - Kind.STONE_BLUE)
			return ""


static func display_name(kind: int) -> String:
	var key := name_key(kind)
	if key.is_empty():
		return "?"
	return Locale.t(key)


static func icon_path(kind: int) -> String:
	match kind:
		Kind.BELL:
			return _SpecialItemIcons.BELL
		Kind.BOOK:
			return _SpecialItemIcons.BOOK
		Kind.CANDLE:
			return _SpecialItemIcons.CANDLE
		Kind.HORN:
			return _SpecialItemIcons.HORN
		Kind.WHEEL:
			return _SpecialItemIcons.WHEEL
		Kind.SKULL:
			return _SpecialItemIcons.SKULL
		Kind.KEY_TRUTH:
			return _SpecialItemIcons.KEY_TRUTH
		Kind.KEY_LOVE:
			return _SpecialItemIcons.KEY_LOVE
		Kind.KEY_COURAGE:
			return _SpecialItemIcons.KEY_COURAGE
		_:
			if kind >= Kind.STONE_BLUE and kind <= Kind.STONE_BLACK:
				return _SpecialItemIcons.stone_path(kind - Kind.STONE_BLUE)
			return ""
