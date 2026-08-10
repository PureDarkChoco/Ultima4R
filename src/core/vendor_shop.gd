class_name VendorShop
extends RefCounted

## xu4 module/Ultima-IV/vendors.b — city vendor state machines.

enum Mode {
	DONE = 0,
	CHOICE = 1,
	NUMBER = 2,
	TEXT = 3,
}

const _Roles := preload("res://src/map/city_npc_roles.gd")
const _VL := preload("res://src/core/vendor_locale.gd")
const _TalkLocale := preload("res://src/core/talk_locale.gd")
const _TalkTlk := preload("res://src/core/talk_tlk.gd")
const ITEM_PICK_MARK := "\u0003"

## World callbacks (relocate / mount horse); shop mutates GameState for gold/items.
var mode: int = Mode.DONE
var choice_keys := ""
var max_digits := 2
var prompt_live := ""
var out_lines: Array[String] = []
var finished := false
var want_horse := false
var relocate_to := Vector2i(-1, -1)
var do_inn_rest := false

var _role := 0
var _locale := ""
var _shop := ""
var _owner := ""
var _phase := ""
var _price := 0
var _unit_price := 0
var _quant := 1
var _item_id := 0
var _item_name := ""
var _list_keys := "" ## stock list keys for current shop
var _desc := ""
var _ales_drunk := 0
var _tip_total := 0
var _topic_key := ""
var _topic_need := 0
var _specialty := ""
var _spec_price := 0
var _topics: Array = [] ## [{name, min_tip, rumor}]
var _prices: Array[int] = [] ## reagents unit prices
var _pindex := 0
var _paying := 0
var _heal_remedy := ""
var _heal_desc := ""
var _heal_slot := 0
var _room: Vector2i = Vector2i(-1, -1)
var _gear_is_weapon := true

const WEAPON_LIST_PRICE := {
	1: 20, 2: 2, 3: 25, 4: 100, 5: 225, 6: 300, 7: 250, 8: 600,
	9: 5, 10: 350, 11: 1500, 12: 2500, 13: 2000, 14: 5000, 15: 7000,
}
const WEAPON_NAME := {
	1: "Staff", 2: "Dagger", 3: "Sling", 4: "Mace", 5: "Axe", 6: "Sword",
	7: "Bow", 8: "Crossbow", 9: "Flaming Oil", 10: "Halberd",
	11: "Magic Axe", 12: "Magic Sword", 13: "Magic Bow", 14: "Magic Wand",
	15: "Mystic Sword",
}
const WEAPON_KEY_TO_ID := {
	"b": 1, "c": 2, "d": 3, "e": 4, "f": 5, "g": 6, "h": 7, "i": 8,
	"j": 9, "k": 10, "l": 11, "m": 12, "n": 13, "o": 14, "p": 15,
}
const ARMOR_LIST_PRICE := {
	1: 50, 2: 200, 3: 600, 4: 2000, 5: 4000, 6: 7000, 7: 9000,
}
const ARMOR_NAME := {
	1: "Cloth", 2: "Leather", 3: "Chain Mail", 4: "Plate Mail",
	5: "Magic Chain", 6: "Magic Plate", 7: "Mystic Robe",
}
const ARMOR_KEY_TO_ID := {
	"b": 1, "c": 2, "d": 3, "e": 4, "f": 5, "g": 6, "h": 7,
}

const WEAPON_DESC := {
	1: "We are the only staff makers in Britannia, yet sell them for only $gp.",
	2: "We sell the most deadly of daggers, a bargain at only $gp each.",
	3: "Our slings are made from only the finest guy and leather, 'Tis yours for $gp.",
	4: "These maces have a hardened shaft and a 5lb head fairly priced at $gp.",
	5: "Notice the fine workmanship on this axe, you'll agree $gp is a good price.",
	6: "The fine work on these swords will be the dread of thy foes, for $gp.",
	7: "Our bows are made of finest yew, and the arrows willow, a steal at $gp.",
	8: "Crossbows made by Iolo the Bard are the finest in the world, your for $gp.",
	9: "Flasks of oil make great weapons and creates a wall of flame too. $gp each.",
	10: "A Halberd is a mighty weapon to attack over obstacles; a must and only $gp.",
	11: "This magical axe can be thrown at thy enemy and will then return all for $gp.",
	12: "Magical swords such as these are rare indeed I will part with one for $gp.",
	13: "A magical bow will keep thy enemies far away or dead! A must for $gp!",
	14: "This magic wand casts mighty blue bolts to strike down thy foes, $gp.",
}
const ARMOR_DESC := {
	1: "Cloth Armour is good for a tight budget, Fairly priced at $gp.",
	2: "Leather Armour is both supple and strong, and costs a mere $gp. A Bargain!",
	3: "Chail Mail is the armour used by more warriors than all others. Ours costs $gp.",
	4: "Full Plate armour is the ultimate in non-magical armour. Get yours for $gp.",
	5: "Magic Armour is rare and expensive. This chain sells for $gp.",
	6: "Magic Plate Armour is the best known protection. Only we have it.  Cost: $gp.",
}

## city -> {shop, owner, stock: [[key, id, price], ...]}
const WEAPON_STOCKS := {
	"Britain": {
		"shop": "Windsor Weaponry", "owner": "Winston",
		"stock": [["b", 1, 20], ["c", 2, 2], ["d", 3, 25], ["g", 6, 300]],
	},
	"Jhelom": {
		"shop": "Willard's Weaponry", "owner": "Willard",
		"stock": [["f", 5, 225], ["g", 6, 300], ["i", 8, 600], ["k", 10, 350]],
	},
	"Minoc": {
		"shop": "The Iron Works", "owner": "Peter",
		"stock": [["e", 4, 100], ["k", 10, 300], ["l", 11, 1500], ["m", 12, 2500]],
	},
	"Trinsic": {
		"shop": "Dueling Weapons", "owner": "Jumar",
		"stock": [["e", 4, 100], ["f", 5, 225], ["g", 6, 300], ["h", 7, 250]],
	},
	"Buccaneers-Den": {
		"shop": "Hook's Arms", "owner": "Hook",
		"stock": [["i", 8, 600], ["j", 9, 5], ["n", 13, 2000], ["o", 14, 5000]],
	},
	"Vesper": {
		"shop": "Village Arms", "owner": "Wendy",
		"stock": [["c", 2, 2], ["d", 3, 25], ["h", 7, 250], ["j", 9, 5]],
	},
}

const ARMOR_STOCKS := {
	"Britain": {
		"shop": "Winsdor Armour", "owner": "Winston",
		"stock": [["b", 1, 50], ["c", 2, 200], ["d", 3, 600]],
	},
	"Jhelom": {
		"shop": "Valiant's Armour", "owner": "Valiant",
		"stock": [["d", 3, 600], ["e", 4, 2000], ["f", 5, 4000], ["g", 6, 7000]],
	},
	"Trinsic": {
		"shop": "Duelling Armour", "owner": "Jean",
		"stock": [["b", 1, 50], ["d", 3, 600], ["f", 5, 4000]],
	},
	"Paws": {
		"shop": "Light Armour", "owner": "Pierre",
		"stock": [["b", 1, 50], ["c", 2, 200]],
	},
	"Buccaneers-Den": {
		"shop": "Basic Armour", "owner": "Limpy",
		"stock": [["b", 1, 50], ["c", 2, 200], ["d", 3, 600]],
	},
}

const FOOD_SHOPS := {
	"Moonglow": {"shop": "The Sage Deli", "owner": "Shaman", "price": 25},
	"Britain": {"shop": "Adventure Food", "owner": "Windrick", "price": 40},
	"Yew": {"shop": "The Dry Goods", "owner": "Donnar", "price": 35},
	"Skara-Brae": {"shop": "Food For Thought", "owner": "Mintol", "price": 20},
	"Paws": {"shop": "The Market", "owner": "Max", "price": 30},
}

const REAGENT_SHOPS := {
	"Moonglow": {"shop": "Magical Herbs", "owner": "Margot", "prices": [2, 5, 6, 3, 6, 9]},
	"Skara-Brae": {"shop": "Herbs and Spice", "owner": "Sasha", "prices": [2, 4, 9, 6, 4, 8]},
	"Paws": {"shop": "The Magics", "owner": "Sheila", "prices": [3, 4, 2, 9, 6, 7]},
	"Buccaneers-Den": {"shop": "Magic Mentar", "owner": "Shannon", "prices": [6, 7, 9, 9, 9, 1]},
}

const HEALER_SHOPS := {
	"Britannia": {"shop": "The Royal Healer", "owner": "Pendragon"},
	"Moonglow": {"shop": "The Healer", "owner": "Harmony"},
	"Britain": {"shop": "Wound Healing", "owner": "Celest"},
	"Jhelom": {"shop": "Heal and Health", "owner": "Triplet"},
	"Yew": {"shop": "Just Healing", "owner": "Justin"},
	"Skara-Brae": {"shop": "The Mystic Heal", "owner": "Spiran"},
	"Lycaeum": {"shop": "The Truth Healer", "owner": "Starfire"},
	"Empath-Abbey": {"shop": "The Love Healer", "owner": "Salle'"},
	"Serpents-Hold": {"shop": "The Courage Healer", "owner": "Windwalker"},
	"Cove": {"shop": "The Healer Shop", "owner": "Quat"},
}


static func locale_from_ult(ult_path: String) -> String:
	var key := ult_path.get_file().to_lower()
	match key:
		"lcb_1.ult", "lcb_2.ult":
			return "Britannia"
		"lycaeum.ult":
			return "Lycaeum"
		"empath.ult":
			return "Empath-Abbey"
		"serpent.ult":
			return "Serpents-Hold"
		"moonglow.ult":
			return "Moonglow"
		"britain.ult":
			return "Britain"
		"jhelom.ult":
			return "Jhelom"
		"yew.ult":
			return "Yew"
		"minoc.ult":
			return "Minoc"
		"trinsic.ult":
			return "Trinsic"
		"skara.ult":
			return "Skara-Brae"
		"paws.ult":
			return "Paws"
		"den.ult":
			return "Buccaneers-Den"
		"vesper.ult":
			return "Vesper"
		"cove.ult":
			return "Cove"
		_:
			return ""


static func is_vendor_role(role: int) -> bool:
	return _Roles.is_vendor(role)


func take_lines() -> Array[String]:
	var lines := out_lines.duplicate()
	out_lines.clear()
	return lines


static func item_line_key(raw: String) -> String:
	if not raw.begins_with(ITEM_PICK_MARK):
		return ""
	var marker_end := raw.find(ITEM_PICK_MARK, ITEM_PICK_MARK.length())
	if marker_end < 0:
		return ""
	return raw.substr(ITEM_PICK_MARK.length(), marker_end - ITEM_PICK_MARK.length())


static func item_line_text(raw: String) -> String:
	if not raw.begins_with(ITEM_PICK_MARK):
		return raw
	var marker_end := raw.find(ITEM_PICK_MARK, ITEM_PICK_MARK.length())
	if marker_end < 0:
		return raw
	return raw.substr(marker_end + ITEM_PICK_MARK.length())


func character_inv_kind() -> String:
	## Inventory page to mirror on the character panel during this shop.
	## "" → keep the party roster. Weapon / armor / reagent vendors only.
	match _role:
		_Roles.Role.VENDOR_WEAPONS:
			## After Buy or Sell — browse/own weapons while trading.
			if _phase == "w_bs" or _phase.is_empty():
				return ""
			return "weapons"
		_Roles.Role.VENDOR_ARMOR:
			if _phase == "a_bs" or _phase.is_empty():
				return ""
			return "armor"
		_Roles.Role.VENDOR_REAGENTS:
			if _phase == "r_need" or _phase.is_empty():
				return ""
			return "reagents"
		_:
			return ""


func is_sell_letter_pick() -> bool:
	## Letter (or ↑↓ / Enter) selection of which pack item to sell.
	return _phase == "w_sell_key" or _phase == "a_sell_key"


func item_list_entries() -> Array[Dictionary]:
	## Buy catalogs that may be navigated with ↑↓ and accepted with Enter / A.
	var entries: Array[Dictionary] = []
	match _phase:
		"w_inv":
			var weapon_data: Dictionary = WEAPON_STOCKS.get(_locale, {})
			for row in weapon_data.get("stock", []):
				entries.append({
					"key": str(row[0]),
					"label": _format_weapon_stock_line(row),
				})
		"a_inv":
			var armor_data: Dictionary = ARMOR_STOCKS.get(_locale, {})
			for row in armor_data.get("stock", []):
				entries.append({
					"key": str(row[0]),
					"label": _format_armor_stock_line(row),
				})
		"r_item":
			for i in 6:
				entries.append({
					"key": String.chr(97 + i),
					"label": "%s-%s" % [
						String.chr(65 + i),
						Locale.reagent_name(i),
					],
				})
	return entries


func begin(role: int, locale: String) -> void:
	_reset()
	_role = role
	_locale = locale
	finished = false
	match role:
		_Roles.Role.VENDOR_WEAPONS:
			_start_weapons()
		_Roles.Role.VENDOR_ARMOR:
			_start_armor()
		_Roles.Role.VENDOR_FOOD:
			_start_food()
		_Roles.Role.VENDOR_TAVERN:
			_start_tavern()
		_Roles.Role.VENDOR_REAGENTS:
			_start_reagents()
		_Roles.Role.VENDOR_HEALER:
			_start_healer()
		_Roles.Role.VENDOR_INN:
			_start_inn()
		_Roles.Role.VENDOR_GUILD:
			_start_guild()
		_Roles.Role.VENDOR_STABLE:
			_start_stable()
		_:
			_say(_L("I have nothing to sell thee."))
			_finish()


func on_escape() -> void:
	if finished:
		return
	## Catalog / letter pick: back to Buy or Sell (do not end talk).
	match _phase:
		"w_inv", "w_sell_key":
			_w_prompt_buy_sell()
			return
		"w_howmany", "w_sell_howmany":
			_w_prompt_buy_sell()
			return
		"a_inv", "a_sell_key":
			_a_prompt_buy_sell()
			return
		"a_howmany", "a_sell_howmany":
			_a_prompt_buy_sell()
			return
		"f_howmany":
			_f_prompt_interest()
			return
		_:
			pass
	## Soft farewell without shop-specific long adieu when aborting mid-flow.
	_say(_L("Bye."))
	_finish(false)


func submit_choice(raw: String) -> void:
	if finished or mode != Mode.CHOICE:
		return
	var ch := raw.strip_edges().to_lower()
	if ch.is_empty():
		return
	var c0 := ch.substr(0, 1)
	if not choice_keys.contains(c0):
		return
	## Inventory pick invalid adieu (any leftover key paths call adieu by omitting).
	match _phase:
		"w_bs":
			_on_w_bs(c0)
		"w_inv":
			_on_w_inv(c0)
		"w_take":
			_on_w_take(c0)
		"w_else":
			_on_w_else(c0)
		"w_sell_key":
			_on_w_sell_key(c0)
		"w_sell_deal":
			_on_w_sell_deal(c0)
		"w_sell_many_deal":
			_on_w_sell_many_deal(c0)
		"a_bs":
			_on_a_bs(c0)
		"a_inv":
			_on_a_inv(c0)
		"a_take":
			_on_a_take(c0)
		"a_else":
			_on_a_else(c0)
		"a_sell_key":
			_on_a_sell_key(c0)
		"a_sell_deal":
			_on_a_sell_deal(c0)
		"a_sell_many_deal":
			_on_a_sell_many_deal(c0)
		"f_interest":
			_on_f_interest(c0)
		"f_else":
			_on_f_else(c0)
		"t_fa":
			_on_t_fa(c0)
		"t_else":
			_on_t_else(c0)
		"r_need":
			_on_r_need(c0)
		"r_item":
			_on_r_item(c0)
		"r_else":
			_on_r_else(c0)
		"h_need":
			_on_h_need(c0)
		"h_svc":
			_on_h_svc(c0)
		"h_pay":
			_on_h_pay(c0)
		"h_more":
			_on_h_more(c0)
		"h_who":
			_on_h_who(c0)
		"h_blood":
			_on_h_blood(c0)
		"i_need":
			_on_i_need(c0)
		"i_take":
			_on_i_take(c0)
		"i_minoc":
			_on_i_minoc(c0)
		"g_need":
			_on_g_need(c0)
		"g_item":
			_on_g_item(c0)
		"g_buy":
			_on_g_buy(c0)
		"g_more":
			_on_g_more(c0)
		"s_need":
			_on_s_need(c0)
		"s_buy":
			_on_s_buy(c0)
		_:
			pass


func submit_number(n: int, empty: bool) -> void:
	if finished or mode != Mode.NUMBER:
		return
	if empty or n <= 0:
		match _phase:
			"w_howmany":
				_w_anything_else()
			"w_sell_howmany":
				_w_you_sell()
			"a_howmany":
				_a_anything_else()
			"a_sell_howmany":
				_a_you_sell()
			"f_howmany":
				_say(_L("Too bad. Maybe next time."))
				_f_adieu()
			"t_plates", "t_ale_pay", "t_tip":
				_t_adieu()
			"r_howmany", "r_pay":
				_r_i_see()
			_:
				_finish()
		return
	match _phase:
		"w_howmany":
			_quant = mini(n, 99)
			_w_buy()
		"w_sell_howmany":
			_quant = mini(n, 99)
			_w_sell_many_offer()
		"a_howmany":
			_quant = mini(n, 99)
			_a_buy()
		"a_sell_howmany":
			_quant = mini(n, 99)
			_a_sell_many_offer()
		"f_howmany":
			_quant = mini(n, 999)
			_f_buy()
		"t_plates":
			_quant = mini(n, 99)
			_t_buy_plates()
		"t_ale_pay":
			_t_ale_buy(mini(n, 99))
		"t_tip":
			_t_more_tip(mini(n, 99))
		"r_howmany":
			_quant = mini(n, 99)
			_r_you_pay()
		"r_pay":
			_paying = mini(n, 9999)
			_r_pay_now()
		_:
			pass


func submit_text(s: String) -> void:
	if finished or mode != Mode.TEXT:
		return
	match _phase:
		"t_topic":
			_t_topic(s)
		_:
			pass


func _reset() -> void:
	mode = Mode.DONE
	choice_keys = ""
	max_digits = 2
	prompt_live = ""
	out_lines.clear()
	finished = false
	want_horse = false
	relocate_to = Vector2i(-1, -1)
	do_inn_rest = false
	_phase = ""
	_price = 0
	_quant = 1
	_item_id = 0
	_item_name = ""
	_list_keys = ""
	_ales_drunk = 0
	_tip_total = 0


func _say(msg: String) -> void:
	if msg.is_empty():
		return
	if not _owner.is_empty():
		msg = msg.replace(_owner, _VL.person_name(_owner))
	out_lines.append(msg)


func _say_item(key: String, msg: String) -> void:
	if key.is_empty() or msg.is_empty():
		return
	out_lines.append(ITEM_PICK_MARK + key + ITEM_PICK_MARK + msg)


func _L(en: String) -> String:
	## KO overlays when language is ko; classic→modern when language is en_us.
	return _TalkTlk.present_script(_VL.line(en))


func _finish(push_done: bool = true) -> void:
	mode = Mode.DONE
	finished = true
	choice_keys = ""
	prompt_live = ""
	if push_done:
		pass


func _want_choice(keys: String, phase: String) -> void:
	mode = Mode.CHOICE
	choice_keys = keys
	_phase = phase
	prompt_live = ""


func _want_number(digits: int, phase: String) -> void:
	mode = Mode.NUMBER
	max_digits = digits
	_phase = phase
	prompt_live = ""


func _want_text(phase: String) -> void:
	mode = Mode.TEXT
	_phase = phase
	prompt_live = ""


func _sub_vars(s: String) -> String:
	return s.replace("@", _shop).replace("%", _owner) \
		.replace("$", str(_price)).replace("#", str(_quant)) \
		.replace("=", _item_name)


# ── Weapons ──────────────────────────────────────────────────────────

func _start_weapons() -> void:
	var data: Variant = WEAPON_STOCKS.get(_locale, null)
	if data == null:
		_say(_L("Closed."))
		_finish()
		return
	_gear_is_weapon = true
	_shop = str(data["shop"])
	_owner = str(data["owner"])
	_build_stock_keys(data["stock"])
	_say(_L("Welcome to\n%s\n\n%s says:\nWelcome friend!\nArt thou here to\nBuy (B) or Sell (S)?") % [_shop, _owner])
	_want_choice("bs", "w_bs")


func _w_prompt_buy_sell() -> void:
	## After Esc from catalog / sell letter — re-ask without replaying welcome.
	_say(_L("%s says:\nArt thou here to\nBuy (B) or Sell (S)?") % _owner)
	_want_choice("bs", "w_bs")


func _build_stock_keys(stock: Array) -> void:
	_list_keys = ""
	for row in stock:
		_list_keys += str(row[0])


func _stock_row(key: String) -> Array:
	var data: Dictionary = WEAPON_STOCKS.get(_locale, {}) if _gear_is_weapon else ARMOR_STOCKS.get(_locale, {})
	for row in data.get("stock", []):
		if str(row[0]) == key:
			return row
	return []


func _on_w_bs(c0: String) -> void:
	if c0 == "b":
		_say(_L("Very Good!"))
		_w_show_inv()
	elif c0 == "s":
		_say(_L("Excellent! Which\nwouldst "))
		_w_you_sell()


func _w_show_inv() -> void:
	## One catalog line per item: "E - Mace / 100G / (eq / inv)".
	_say(_L("We Have:"))
	var data: Dictionary = WEAPON_STOCKS[_locale]
	for row in data["stock"]:
		_say_item(str(row[0]), _format_weapon_stock_line(row))
	_say(_L("Your Interest?"))
	_want_choice(_list_keys, "w_inv")


func _format_weapon_stock_line(row: Array) -> String:
	var k := str(row[0]).to_upper()
	var id := int(row[1])
	var price := int(row[2])
	var name := Locale.weapon_name(id)
	var eq_n := GameState.equipped_weapon_count(id)
	var inv_n := GameState.pack_weapon_qty(id)
	var can_eq := GameState.party_can_equip_new_weapon(id)
	var icon := TalkTlk.mark_weapon_icon(id)
	return _format_gear_stock_line(k, icon, name, price, eq_n, inv_n, can_eq)


func _format_armor_stock_line(row: Array) -> String:
	var k := str(row[0]).to_upper()
	var id := int(row[1])
	var price := int(row[2])
	var name := Locale.armor_name(id)
	var eq_n := GameState.equipped_armor_count(id)
	var inv_n := GameState.pack_armor_qty(id)
	var can_eq := GameState.party_can_equip_new_armor(id)
	var icon := TalkTlk.mark_armor_icon(id)
	return _format_gear_stock_line(k, icon, name, price, eq_n, inv_n, can_eq)


func _format_gear_stock_line(
	letter: String,
	icon_mark: String,
	item_name: String,
	price: int,
	equipped: int,
	inventory: int,
	can_equip: bool
) -> String:
	## "E - [icon]Mace / 100G / (eq / inv)". Red index / red price when applicable.
	var key := letter
	if not can_equip:
		key = "[color=#e74c3c]%s[/color]" % letter
	var price_s := "%dG" % price
	if GameState.gold < price:
		price_s = "[color=#e74c3c]%s[/color]" % price_s
	return "%s - %s%s / %s / (%d / %d)" % [key, icon_mark, item_name, price_s, equipped, inventory]


func _on_w_inv(c0: String) -> void:
	var row := _stock_row(c0)
	if row.is_empty():
		_w_adieu()
		return
	_item_id = int(row[1])
	_price = int(row[2])
	_item_name = Locale.weapon_name(_item_id)
	_quant = 1
	if GameState.gold < _price:
		_say(_L("You have not the funds for even one!"))
		_w_anything_else()
		return
	var desc := _VL.weapon_desc(str(WEAPON_DESC.get(_item_id, ""))).replace("$", str(_price))
	_say(desc)
	if GameState.gold > _price * 2:
		_say(_L("How many would\nyou like?"))
		_want_number(2, "w_howmany")
	else:
		_say(_L("Take it? (Y/N)"))
		_want_choice("yn", "w_take")


func _on_w_take(c0: String) -> void:
	if c0 == "y":
		_quant = 1
		_w_buy()
	else:
		_say(_L("Too bad."))
		_w_anything_else()


func _w_buy() -> void:
	var cost := _price * _quant
	if GameState.gold < cost:
		_say(_L("I fear you have not the funds, perhaps something else."))
		_w_anything_else()
		return
	if not GameState.try_pay_gold(cost):
		_w_anything_else()
		return
	GameState.add_pack_weapons(_item_id, _quant)
	_say(_L("%s says: A fine choice!") % _owner)
	_w_anything_else()


func _w_anything_else() -> void:
	_say(_L("Anything\nelse? (Y/N)"))
	_want_choice("yn", "w_else")


func _on_w_else(c0: String) -> void:
	if c0 == "y":
		_w_show_inv()
	else:
		_w_adieu()


func _w_you_sell() -> void:
	_say(_L("You sell:"))
	_want_choice("bcdefghijklmnop", "w_sell_key")


func _on_w_sell_key(c0: String) -> void:
	if not WEAPON_KEY_TO_ID.has(c0):
		_w_adieu()
		return
	_item_id = int(WEAPON_KEY_TO_ID[c0])
	_unit_price = int(WEAPON_LIST_PRICE[_item_id] / 2)
	_price = _unit_price
	_item_name = Locale.weapon_name(_item_id)
	var own := GameState.pack_weapon_qty(_item_id)
	if own <= 0:
		_say(_L("Thou dost not own that. What else might"))
		_w_you_sell()
	elif own == 1:
		_quant = 1
		_say(_L("I will give you %dgp for that %s.\nDeal? (Y/N)") % [_price, _item_name])
		_want_choice("yn", "w_sell_deal")
	else:
		_say(_L("How many %ss\nwould you wish\nto sell?") % _item_name)
		_want_number(2, "w_sell_howmany")


func _on_w_sell_deal(c0: String) -> void:
	if c0 == "y":
		_w_do_sell(_quant, _unit_price * _quant)
	else:
		_say(_L("Hmmph. What else\nwould "))
		_w_you_sell()


func _w_sell_many_offer() -> void:
	if _quant > GameState.pack_weapon_qty(_item_id):
		_say(_L("You don't have that many swine!"))
		_finish()
		return
	_price = _unit_price * _quant
	_say(_L("I will give you %dgp for them.\nDeal? (Y/N)") % _price)
	_want_choice("yn", "w_sell_many_deal")


func _on_w_sell_many_deal(c0: String) -> void:
	if c0 == "y":
		_w_do_sell(_quant, _price)
	else:
		_w_adieu()


func _w_do_sell(q: int, gold_out: int) -> void:
	if not GameState.remove_pack_weapons(_item_id, q):
		_say(_L("Thou dost not own that. What else might"))
		_w_you_sell()
		return
	GameState.adjust_gold(gold_out)
	_say(_L("Fine! What else?"))
	_w_you_sell()


func _w_adieu() -> void:
	_say(_L("%s says:\nFare thee well!") % _owner)
	_finish()


# ── Armor (mirror weapons) ───────────────────────────────────────────

func _start_armor() -> void:
	var data: Variant = ARMOR_STOCKS.get(_locale, null)
	if data == null:
		_say(_L("Closed."))
		_finish()
		return
	_gear_is_weapon = false
	_shop = str(data["shop"])
	_owner = str(data["owner"])
	_build_stock_keys(data["stock"])
	_say(_L("Welcome to\n%s\n\n%s says:\nWelcome friend!\nWant to Buy (B) or\nSell (S)?") % [_shop, _owner])
	_want_choice("bs", "a_bs")


func _a_prompt_buy_sell() -> void:
	## After Esc from catalog / sell letter — re-ask without replaying welcome.
	_say(_L("%s says:\nWant to Buy (B) or\nSell (S)?") % _owner)
	_want_choice("bs", "a_bs")


func _on_a_bs(c0: String) -> void:
	if c0 == "b":
		_say(_L("Well then,"))
		_a_show_inv()
	elif c0 == "s":
		_say(_L("What will"))
		_a_you_sell()


func _a_show_inv() -> void:
	## One catalog line per item: "C - Leather / 200G / (eq / inv)".
	_say(_L("We've got:"))
	var data: Dictionary = ARMOR_STOCKS[_locale]
	for row in data["stock"]:
		_say_item(str(row[0]), _format_armor_stock_line(row))
	_say(_L("What'll it be?"))
	_want_choice(_list_keys, "a_inv")


func _on_a_inv(c0: String) -> void:
	var row := _stock_row(c0)
	if row.is_empty():
		_a_adieu()
		return
	_item_id = int(row[1])
	_price = int(row[2])
	_item_name = Locale.armor_name(_item_id)
	_quant = 1
	if GameState.gold < _price:
		_say(_L("You have not the funds for even one!"))
		_a_anything_else()
		return
	var desc := _VL.armor_desc(str(ARMOR_DESC.get(_item_id, ""))).replace("$", str(_price))
	_say(desc)
	if GameState.gold > _price * 2:
		_say(_L("How many would\nyou like?"))
		_want_number(2, "a_howmany")
	else:
		_say(_L("Take it? (Y/N)"))
		_want_choice("yn", "a_take")


func _on_a_take(c0: String) -> void:
	if c0 == "y":
		_quant = 1
		_a_buy()
	else:
		_say(_L("Too bad."))
		_a_anything_else()


func _a_buy() -> void:
	var cost := _price * _quant
	if GameState.gold < cost:
		_say(_L("You don't have enough gold. Maybe something cheaper?"))
		_a_anything_else()
		return
	if not GameState.try_pay_gold(cost):
		_a_anything_else()
		return
	GameState.add_pack_armor(_item_id, _quant)
	_say(_L("%s says: Good choice!") % _owner)
	_a_anything_else()


func _a_anything_else() -> void:
	_say(_L("Anything\nelse? (Y/N)"))
	_want_choice("yn", "a_else")


func _on_a_else(c0: String) -> void:
	if c0 == "y":
		_a_show_inv()
	else:
		_a_adieu()


func _a_you_sell() -> void:
	_say(_L("You sell:"))
	_want_choice("bcdefgh", "a_sell_key")


func _on_a_sell_key(c0: String) -> void:
	if not ARMOR_KEY_TO_ID.has(c0):
		_a_adieu()
		return
	_item_id = int(ARMOR_KEY_TO_ID[c0])
	_unit_price = int(ARMOR_LIST_PRICE[_item_id] / 2)
	_price = _unit_price
	_item_name = Locale.armor_name(_item_id)
	var own := GameState.pack_armor_qty(_item_id)
	if own <= 0:
		_say(_L("Come on, you\ndon't own any."))
		_a_you_sell()
	elif own == 1:
		_quant = 1
		_say(_L("I will give you %dgp for that %s.\nDeal? (Y/N)") % [_price, _item_name])
		_want_choice("yn", "a_sell_deal")
	else:
		_say(_L("How many %ss\nwould you wish\nto sell?") % _item_name)
		_want_number(2, "a_sell_howmany")


func _on_a_sell_deal(c0: String) -> void:
	if c0 == "y":
		_a_do_sell(1, _unit_price)
	else:
		_say(_L("Harumph. What else would "))
		_a_you_sell()


func _a_sell_many_offer() -> void:
	if _quant > GameState.pack_armor_qty(_item_id):
		_say(_L("You don't have that many swine!"))
		_finish()
		return
	_price = _unit_price * _quant
	_say(_L("I will give you %dgp for them.\nDeal? (Y/N)") % _price)
	_want_choice("yn", "a_sell_many_deal")


func _on_a_sell_many_deal(c0: String) -> void:
	if c0 == "y":
		_a_do_sell(_quant, _price)
	else:
		_say(_L("Harumph. What else would "))
		_a_you_sell()


func _a_do_sell(q: int, gold_out: int) -> void:
	if not GameState.remove_pack_armor(_item_id, q):
		_say(_L("Come on, you\ndon't own any."))
		_a_you_sell()
		return
	GameState.adjust_gold(gold_out)
	_say(_L("Fine! What else?"))
	_a_you_sell()


func _a_adieu() -> void:
	_say(_L("%s says:\nGood Bye.") % _owner)
	_finish()


# ── Food ─────────────────────────────────────────────────────────────

func _start_food() -> void:
	var data: Variant = FOOD_SHOPS.get(_locale, null)
	if data == null:
		_say(_L("Closed."))
		_finish()
		return
	_shop = str(data["shop"])
	_owner = str(data["owner"])
	_price = int(data["price"])
	_say(_L("Welcome to %s\n\n%s says: Good day, and Welcome friend.") % [_shop, _owner])
	if GameState.gold < _price:
		_say(_L("Come back when you have some money!"))
		_finish()
		return
	_say(_L("May I interest you in some rations? (Y/N)"))
	_want_choice("yn", "f_interest")


func _f_prompt_interest() -> void:
	_say(_L("May I interest you in some rations? (Y/N)"))
	_want_choice("yn", "f_interest")


func _on_f_interest(c0: String) -> void:
	if c0 != "y":
		_f_adieu()
		return
	_say(_L("We have the best adventure rations, 25 for only %dgp.") % _price)
	_say(_L("How many packs of 25 would you like?"))
	_want_number(3, "f_howmany")


func _f_buy() -> void:
	var cost := _price * _quant
	if not GameState.try_pay_gold(cost):
		var can := int(GameState.gold / _price) if _price > 0 else 0
		_say(_L("You can only afford %d packs.") % can)
		_say(_L("How many packs of 25 would you like?"))
		_want_number(3, "f_howmany")
		return
	GameState.add_food_units(25 * _quant)
	_say(_L("Thank you. "))
	if GameState.gold < _price:
		_say(_L("Come again!"))
		_finish()
	else:
		_say(_L("Anything\nelse? (Y/N)"))
		_want_choice("yn", "f_else")


func _on_f_else(c0: String) -> void:
	if c0 == "y":
		_say(_L("How many packs of 25 would you like?"))
		_want_number(3, "f_howmany")
	else:
		_f_adieu()


func _f_adieu() -> void:
	_say(_L("Goodbye. Come again!"))
	_finish()


# ── Tavern ───────────────────────────────────────────────────────────

func _start_tavern() -> void:
	if not _init_tavern_locale():
		_say(_L("Closed."))
		_finish()
		return
	_ales_drunk = 0
	_say(_L("%s says: Welcome to %s") % [_owner, _shop])
	_t_whatll()


func _init_tavern_locale() -> bool:
	match _locale:
		"Britain":
			_shop = "Jolly Spirits"
			_owner = "Sam"
			_specialty = "Lamb Chops"
			_spec_price = 4
			_topics = _topics_from(0)
		"Jhelom":
			_shop = "The Bloody Pub"
			_owner = "Celestial"
			_specialty = "Dragon Tartar"
			_spec_price = 2
			_topics = _topics_from(1)
		"Trinsic":
			_shop = "The Keg Tap"
			_owner = "Terran"
			_specialty = "Brown Beans"
			_spec_price = 3
			_topics = _topics_from(2)
		"Paws":
			_shop = "Folley Tavern"
			_owner = "Greg 'n Rob"
			_specialty = "Folley Filet"
			_spec_price = 2
			_topics = _topics_from(3)
		"Buccaneers-Den":
			_shop = "Captain Black Tavern"
			_owner = "The Cap'n"
			_specialty = "Dog Meat Pie"
			_spec_price = 4
			_topics = _topics_from(4)
		"Vesper":
			_shop = "Axe 'n Ale"
			_owner = "Arron"
			_specialty = "Green Granukit"
			_spec_price = 2
			_topics = _topics_from(5)
		_:
			return false
	return true


func _topics_from(skip_pairs: int) -> Array:
	var all_t := [
		{"name": "black stone", "need": 20, "rumor": "% says: Ah, the Black Stone. Yes I've heard of it. But, the only one who knows where it lies is the wizard Merlin."},
		{"name": "sextant", "need": 30, "rumor": "% says: For navigation a Sextant is vital... Ask for item \"D\" in the Guild shops!"},
		{"name": "white stone", "need": 10, "rumor": "Now let me see... Yes it was the old Hermit... Sloven! He is tough to find, lives near Lock Lake I hear."},
		{"name": "mandrake", "need": 40, "rumor": "% says: The last person I knew that had any Mandrake was an old alchemist named Calumny."},
		{"name": "skull", "need": 99, "rumor": "% says: If thou must know of that evilest of all things... find the beggar Jude. He is very very poor!"},
		{"name": "nightshade", "need": 25, "rumor": "% says: Of Nightshade I know but this... Seek out Virgil or thou shalt miss! Try in Trinsic!"},
	]
	var out: Array = []
	for i in range(skip_pairs, all_t.size()):
		out.append(all_t[i])
	return out


func _t_whatll() -> void:
	_say(_L("%s says: What'll it be, Food (F) or Ale (A)?") % _owner)
	_want_choice("fa", "t_fa")


func _on_t_fa(c0: String) -> void:
	if c0 == "f":
		_say(_L("Our specialty is %s, which costs %dgp.") % [_VL.specialty(_specialty), _spec_price])
		_say(_L("How many plates would you\nlike?"))
		_want_number(2, "t_plates")
	elif c0 == "a":
		_ales_drunk += 1
		if _ales_drunk > 2:
			_say(_L("%s says: Sorry, you seem to have too many. Bye!") % _owner)
			_finish()
			return
		_price = 2
		_tip_total = 0
		_say(_L("Here's a mug of our best.\nThat'll be 2gp.\nHow much will you pay?"))
		_want_number(2, "t_ale_pay")


func _t_buy_plates() -> void:
	var cost := _spec_price * _quant
	if not GameState.try_pay_gold(cost):
		var can := int(GameState.gold / _spec_price) if _spec_price > 0 else 0
		_say(_L("Ya can only afford %d plates.") % can)
		_say(_L("How many plates would you\nlike?"))
		_want_number(2, "t_plates")
		return
	GameState.add_food_units(_quant)
	_say(_L("Here ye arr."))
	_t_something_else()


func _t_something_else() -> void:
	_say(_L("Somethin'\nelse? (Y/N)"))
	_want_choice("yn", "t_else")


func _on_t_else(c0: String) -> void:
	if c0 == "y":
		_t_whatll()
	else:
		_t_adieu()


func _t_ale_buy(offer: int) -> void:
	if offer < _price:
		_say(_L("Won't pay, eh.\nYa scum, be gone\nfore ey call the\nguards!"))
		_finish()
		return
	if not GameState.try_pay_gold(offer):
		_say(_L("It seems that you have not the gold. Good Day!"))
		_t_adieu()
		return
	if offer > _price:
		_tip_total = offer
		_say(_L("What'd ya like to know friend?"))
		_want_text("t_topic")
	else:
		_t_something_else()


func _t_topic(raw: String) -> void:
	var s := _TalkLocale.normalize_interest(raw)
	var hit: Dictionary = {}
	for t in _topics:
		var matched := false
		for alias in _VL.topic_aliases(str(t["name"])):
			var a := _TalkLocale.normalize_interest(str(alias))
			if a.is_empty():
				continue
			if s == a or s.begins_with(a) or a.begins_with(s) or s.contains(a):
				matched = true
				break
		if matched:
			hit = t
			break
	if hit.is_empty():
		_say(_L("'fraid I can't help ya there friend!"))
		_t_something_else()
		return
	_topic_key = str(hit["name"])
	_topic_need = int(hit["need"])
	_price = _topic_need
	_t_foggy()


func _t_foggy() -> void:
	## xu4: pay the offer again after tip? script pays offer once more on foggy...
	## foggy: pay offer 1 after getting enough tip_total. First path already paid tip.
	## Subsequent "give:" tips pay more gold.
	if _tip_total >= _price:
		var rumor := ""
		for t in _topics:
			if str(t["name"]) == _topic_key:
				rumor = _VL.rumor(str(t["rumor"])).replace("%", _owner)
				break
		_say(rumor)
		_t_something_else()
		return
	_say(_L("That subject is a bit foggy, perhaps more gold will refresh my memory. You\ngive:"))
	_want_number(2, "t_tip")


func _t_more_tip(offer: int) -> void:
	if not GameState.try_pay_gold(offer):
		_say(_L("Ye don't have that mate!"))
		_say(_L("Sorry, I could\nnot help ya mate!"))
		_t_something_else()
		return
	_tip_total += offer
	_t_foggy()


func _t_adieu() -> void:
	_say(_L("See ya mate!"))
	_finish()


# ── Reagents (honesty) ───────────────────────────────────────────────

func _start_reagents() -> void:
	var data: Variant = REAGENT_SHOPS.get(_locale, null)
	if data == null:
		_say(_L("Closed."))
		_finish()
		return
	_shop = str(data["shop"])
	_owner = str(data["owner"])
	_prices.clear()
	for p in data["prices"]:
		_prices.append(int(p))
	_say(_L("A blind woman turns to you and says: Welcome to %s\n\nI am %s\nAre you in need of Reagents? (Y/N)") % [_shop, _owner])
	_want_choice("yn", "r_need")


func _on_r_need(c0: String) -> void:
	if c0 == "y":
		_say(_L("Very well,"))
		_r_show()
	else:
		_r_adieu()


func _r_show() -> void:
	var catalog := _L("I have\nA-Sulfurous Ash\nB-Ginseng\nC-Garlic\nD-Spider Silk\nE-Blood Moss\nF-Black Pearl\nYour\nInterest:")
	for line in catalog.split("\n"):
		var text := str(line)
		var key := text.substr(0, 1).to_lower()
		if text.length() >= 2 and text.substr(1, 1) == "-" and "abcdef".contains(key):
			_say_item(key, text)
		else:
			_say(text)
	_want_choice("abcdef", "r_item")


func _on_r_item(c0: String) -> void:
	var map := {
		"a": {"name": "Sulfur Ash", "id": ReagentIcons.Id.SULPHUROUS_ASH, "i": 0},
		"b": {"name": "Ginseng", "id": ReagentIcons.Id.GINSENG, "i": 1},
		"c": {"name": "Garlic", "id": ReagentIcons.Id.GARLIC, "i": 2},
		"d": {"name": "Spider Silk", "id": ReagentIcons.Id.SPIDER_SILK, "i": 3},
		"e": {"name": "Blood Moss", "id": ReagentIcons.Id.BLOOD_MOSS, "i": 4},
		"f": {"name": "Black Pearl", "id": ReagentIcons.Id.BLACK_PEARL, "i": 5},
	}
	if not map.has(c0):
		_r_adieu()
		return
	var info: Dictionary = map[c0]
	_item_name = Locale.reagent_name(int(info["id"]))
	_item_id = int(info["id"])
	_pindex = int(info["i"])
	_price = int(_prices[_pindex])
	_say(_L("Very well, we sell %s for %dgp. How many would you\nlike?") % [_item_name, _price])
	_want_number(2, "r_howmany")


func _r_you_pay() -> void:
	_price = _price * _quant
	_say(_L("Very good, that will be %dgp.  You pay:") % _price)
	_want_number(4, "r_pay")


func _r_pay_now() -> void:
	if not GameState.try_pay_gold(_paying):
		_say(_L("It seems you have not the gold! "))
		_r_anything_else()
		return
	_say(_L("Very good. "))
	GameState.adjust_reagent(_item_id, _quant)
	GameState.adjust_karma_reagent_pay(_paying, _price)
	_r_anything_else()


func _r_i_see() -> void:
	_say(_L("I see, then "))
	_r_anything_else()


func _r_anything_else() -> void:
	_say(_L("Anything\nelse? (Y/N)"))
	_want_choice("yn", "r_else")


func _on_r_else(c0: String) -> void:
	if c0 == "y":
		_r_show()
	else:
		_r_adieu()


func _r_adieu() -> void:
	_say(_L("%s says:\nPerhaps another time then....\nand slowly turns away.") % _owner)
	_finish()


# ── Healer ───────────────────────────────────────────────────────────

func _start_healer() -> void:
	var data: Variant = HEALER_SHOPS.get(_locale, null)
	if data == null:
		## Try map filename already mapped; Castle floors use Britannia etc.
		_say(_L("Closed."))
		_finish()
		return
	_shop = str(data["shop"])
	_owner = str(data["owner"])
	_say(_L("Welcome unto\n%s\n\n%s says:\nPeace and Joy be with you friend.\nAre you in need of help? (Y/N)") % [_shop, _owner])
	_want_choice("yn", "h_need")


func _on_h_need(c0: String) -> void:
	if c0 == "y":
		_h_services()
	else:
		_h_give_blood()


func _h_services() -> void:
	_say(_L("%s says: We can perform:\nA-Curing\nB-Healing\nC-Resurrection\nYour need:") % _owner)
	_want_choice("abc", "h_svc")


func _on_h_svc(c0: String) -> void:
	match c0:
		"a":
			_heal_desc = "A curing"
			_price = 100
			_heal_remedy = "cure"
		"b":
			_heal_desc = "A healing"
			_price = 200
			_heal_remedy = "fullheal"
		"c":
			_heal_desc = "Resurrection"
			_price = 300
			_heal_remedy = "resurrect"
		_:
			_h_give_blood()
			return
	if GameState.party_size() == 1:
		_heal_slot = 0
		_h_will_pay()
	else:
		_say(_L("%s asks:\nWho is in\nneed?") % _owner)
		_want_choice("12345678".substr(0, GameState.party_size()), "h_who")


func _on_h_who(c0: String) -> void:
	_heal_slot = clampi(int(c0) - 1, 0, GameState.party_size() - 1)
	_h_will_pay()


func _h_will_pay() -> void:
	if not GameState.member_needs_healer(_heal_slot, _heal_remedy):
		match _heal_remedy:
			"cure":
				_say(_L("Thou suffers not from Poison!"))
			"fullheal", "heal":
				_say(_L("Thou art already quite healthy!"))
			"resurrect":
				_say(_L("Thou art not dead fool!"))
		_h_more()
		return
	_say(_L("%s will cost thee %dgp.") % [_VL.heal_desc(_heal_desc), _price])
	if GameState.gold < _price:
		_say(_L("I see by thy purse that thou hast not enough gold. I cannot aid thee."))
		_h_more()
		return
	_say(_L("Wilt thou\npay? (Y/N)"))
	_want_choice("yn", "h_pay")


func _on_h_pay(c0: String) -> void:
	if c0 != "y":
		_h_more()
		return
	if not GameState.try_pay_gold(_price):
		_h_more()
		return
	GameState.healer_heal_member(_heal_slot, _heal_remedy)
	_h_more()


func _h_more() -> void:
	_say(_L("%s asks: Do you need more help? (Y/N)") % _owner)
	_want_choice("yn", "h_more")


func _on_h_more(c0: String) -> void:
	if c0 == "y":
		_h_services()
	else:
		_h_give_blood()


func _h_give_blood() -> void:
	if GameState.party_leader_hp() < 400:
		_h_adieu()
		return
	_say(_L("Art thou willing to give 100pts of thy blood to aid others? (Y/N)"))
	_want_choice("yn", "h_blood")


func _on_h_blood(c0: String) -> void:
	if c0 == "y":
		GameState.damage_party_leader(100)
		GameState.adjust_karma_blood_donation(true)
		_say(_L("Thou art a great help. We are in dire need!"))
	else:
		GameState.adjust_karma_blood_donation(false)
	_h_adieu()


func _h_adieu() -> void:
	_say(_L("%s says: May thy life be guarded by the powers of good.") % _owner)
	_finish()


# ── Inn ──────────────────────────────────────────────────────────────

func _start_inn() -> void:
	## Horse check performed by world before begin when possible; double-check via result.
	if not _setup_inn():
		_say(_L("Closed."))
		_finish()
		return
	_say(_L("The Innkeeper says: Welcome to %s\n\nI am %s.\n\nAre you in need of lodging? (Y/N)") % [_shop, _owner])
	_want_choice("yn", "i_need")


func begin_inn_refuse_horse() -> void:
	_reset()
	_say(_L("The Innkeeper says: Get that horse out of here!!!"))
	_finish()


func _setup_inn() -> bool:
	match _locale:
		"Moonglow":
			_shop = "The Honest Inn"
			_owner = "Scatu"
			_price = 20
			_room = Vector2i(28, 6)
			return true
		"Britain":
			_shop = "Britannia Manor"
			_owner = "Jason"
			_price = 15
			_room = Vector2i(29, 6)
			return true
		"Jhelom":
			_shop = "The Inn of Ends"
			_owner = "Smirk"
			_price = 10
			_room = Vector2i(10, 26)
			return true
		"Minoc":
			_shop = "Wayfarer's Inn"
			_owner = "Estro"
			_price = 0
			_room = Vector2i(-1, -1)
			return true
		"Trinsic":
			_shop = "Honorable Inn"
			_owner = "Zajac"
			_price = 15
			_room = Vector2i(29, 2)
			return true
		"Skara-Brae":
			_shop = "The Inn of the Spirits"
			_owner = "Tyrone"
			_price = 5
			_room = Vector2i(28, 11)
			return true
		"Vesper":
			_shop = "The Sleep Shop"
			_owner = "Tymus"
			_price = 1
			_room = Vector2i(25, 23)
			return true
		_:
			return false


func _on_i_need(c0: String) -> void:
	if c0 != "y":
		_say(_L("%s says: Then you have come to the wrong place!\nGood day.") % _owner)
		_finish()
		return
	if _locale == "Minoc":
		_say(_L("We have three rooms available,\na 1, 2 and 3 bed room for 30, 60\nand 90gp each.\n1, 2 or 3\nbeds? (1/2/3)"))
		_want_choice("123", "i_minoc")
		return
	var msg := ""
	match _locale:
		"Moonglow":
			msg = "We have a room with 2 beds that rents for 20gp."
		"Britain":
			msg = "We have a modest sized room with 1 bed for 15 gp."
		"Jhelom":
			msg = "We have a very secure room of modest size and 1 bed for 10gp."
		"Trinsic":
			msg = "We have a single bed room with a back door for 15gp."
		"Skara-Brae":
			msg = "Unfortunately, I have but only a very small room with 1 bed: worse yet, it's haunted! If you do wish to stay it costs 5gp."
		"Vesper":
			msg = "All we have is that cot over there. But it is comfortable, and only 1 gp."
	_say(_L(msg))
	_say(_L("Take it? (Y/N)"))
	_want_choice("yn", "i_take")


func _on_i_minoc(c0: String) -> void:
	match c0:
		"1":
			_price = 30
			_room = Vector2i(2, 6)
		"2":
			_price = 60
			_room = Vector2i(2, 2)
		"3":
			_price = 90
			_room = Vector2i(8, 2)
		_:
			_finish()
			return
	_i_stay()


func _on_i_take(c0: String) -> void:
	if c0 == "y":
		_i_stay()
	else:
		_say(_L("You won't find a better deal in this towne!"))
		_finish()


func _i_stay() -> void:
	if not GameState.try_pay_gold(_price):
		_say(_L("If you can't pay, you can't stay! Good Bye."))
		_finish()
		return
	_say(_L("Very good.  Have\na pleasant night."))
	relocate_to = _room
	if (randi() % 4) == 0:
		_say(_L("Oh, and don't mind the strange noises, it's only rats!"))
	do_inn_rest = true
	_finish()


# ── Guild ────────────────────────────────────────────────────────────

func _start_guild() -> void:
	match _locale:
		"Vesper":
			_shop = "The Guild Shop"
			_owner = "Long John Leary"
		"Buccaneers-Den":
			_shop = "Pirate's Guild"
			_owner = "One Eyed Willey"
		_:
			_say(_L("Closed."))
			_finish()
			return
	_say(_L("Avast ye mate! Shure ye wishes to buy from ol'\n%s?\n\n%s says: Welcome to %s.\nLike to see my goods? (Y/N)") % [_owner, _owner, _shop])
	_want_choice("yn", "g_need")


func _on_g_need(c0: String) -> void:
	if c0 == "y":
		_g_goods()
	else:
		_g_adieu()


func _g_goods() -> void:
	_say(_L("%s says: Good Mate!\nYa see I gots:\nA-Torches\nB-Magic Gems\nC-Magic Keys\nWat'l it be?") % _owner)
	_want_choice("abcd", "g_item")


func _on_g_item(c0: String) -> void:
	match c0:
		"a":
			_price = 50
			_quant = 5
			_item_name = "torch"
			_say(_L("I can give ya 5 long lasting Torches for a mere 50gp."))
		"b":
			_price = 60
			_quant = 5
			_item_name = "gem"
			_say(_L("I've got magical mapping Gems, 5 for only 60gp."))
		"c":
			_price = 60
			_quant = 6
			_item_name = "key"
			_say(_L("Magical Keys, 1 use each, a fair price at 60gp for 6."))
		"d":
			_price = 900
			_quant = 1
			_item_name = "sextant"
			_say(_L("So...Ya want a Sextant...Well I gots one which I might part with fer 900 gold!"))
		_:
			_g_adieu()
			return
	_say(_L("Will ya buy? (Y/N)"))
	_want_choice("yn", "g_buy")


func _on_g_buy(c0: String) -> void:
	if c0 != "y":
		_say(_L("Hmmm...Grmbl..."))
		_g_adieu()
		return
	if not GameState.try_pay_gold(_price):
		_say(_L("What? Can't pay! Buzz off swine!"))
		_finish()
		return
	_say(_L("Fine... fine..."))
	match _item_name:
		"torch":
			GameState.torches = mini(99, GameState.torches + _quant)
		"gem":
			GameState.gems = mini(99, GameState.gems + _quant)
		"key":
			GameState.keys = mini(99, GameState.keys + _quant)
		"sextant":
			GameState.has_sextant = true
	_say(_L("%s says: See\nmore? (Y/N)") % _owner)
	_want_choice("yn", "g_more")


func _on_g_more(c0: String) -> void:
	if c0 == "y":
		_g_goods()
	else:
		_g_adieu()


func _g_adieu() -> void:
	_say(_L("%s says: See ya matie!") % _owner)
	_finish()


# ── Stable ───────────────────────────────────────────────────────────

func _start_stable() -> void:
	_price = GameState.party_size() * 100
	_say(_L("Welcome friend!\nCan I interest thee in\nhorses? (Y/N)"))
	_want_choice("yn", "s_need")


func _on_s_need(c0: String) -> void:
	if c0 != "y":
		_say(_L("A shame, thou looks like thou could use a good horse!"))
		_finish()
		return
	_say(_L("For only %dg.p.\nThou can have the best! Wilt thou buy? (Y/N)") % _price)
	_want_choice("yn", "s_buy")


func _on_s_buy(c0: String) -> void:
	if c0 != "y":
		_say(_L("A shame, thou looks like thou could use a good horse!"))
		_finish()
		return
	if not GameState.try_pay_gold(_price):
		_say(_L("It seems thou hast not gold enough to pay!"))
		_finish()
		return
	want_horse = true
	_say(_L("Here, a better breed thou shalt not find ever!"))
	_finish()
