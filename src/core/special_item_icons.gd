class_name SpecialItemIcons
extends Object

## Quest / special item icons under `res://assets/ui/special_items/`.
## Stone bit order matches xu4 Stone enum / getStoneName (Blue…Black).

const DIR := "res://assets/ui/special_items/"

## Index 0..7 ↔ STONE_BLUE..STONE_BLACK (1 << i).
const STONE_PATHS := [
	DIR + "stone_blue.png",
	DIR + "stone_yellow.png",
	DIR + "stone_red.png",
	DIR + "stone_green.png",
	DIR + "stone_orange.png",
	DIR + "stone_purple.png",
	DIR + "stone_white.png",
	DIR + "stone_black.png",
]

const STONE_NAME_KEYS := [
	"ztats_item_stone_blue",
	"ztats_item_stone_yellow",
	"ztats_item_stone_red",
	"ztats_item_stone_green",
	"ztats_item_stone_orange",
	"ztats_item_stone_purple",
	"ztats_item_stone_white",
	"ztats_item_stone_black",
]

const BELL := DIR + "bell.png"
const BOOK := DIR + "book.png"
const CANDLE := DIR + "candle.png"
const HORN := DIR + "horn.png"
const WHEEL := DIR + "wheel.png"
const SKULL := DIR + "skull.png"
const SEXTANT := DIR + "sextant.png"
const KEY_TRUTH := DIR + "key_truth.png"
const KEY_LOVE := DIR + "key_love.png"
const KEY_COURAGE := DIR + "key_courage.png"


static func stone_path(bit_index: int) -> String:
	if bit_index < 0 or bit_index >= STONE_PATHS.size():
		return ""
	return str(STONE_PATHS[bit_index])


static func stone_name_key(bit_index: int) -> String:
	if bit_index < 0 or bit_index >= STONE_NAME_KEYS.size():
		return ""
	return str(STONE_NAME_KEYS[bit_index])
