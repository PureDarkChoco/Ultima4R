class_name Spells
extends Object

## Ultima IV spells A–Z (xu4 spell.cpp). Index 0 = A … 25 = Z.

const COUNT := 26

## MP cost by spell index (xu4 spells[].mp).
const MP_COST: Array[int] = [
	5, 15, 5, 20, 10, 15, 40, 10, 20, 30, 25, 5, 5, 20, 5, 15, 20, 45, 15, 30, 15, 15, 10, 15, 10, 5,
]

## English classic names (xu4).
const NAMES_EN: Array[String] = [
	"Awaken", "Blink", "Cure", "Dispell", "Energy Field", "Fireball", "Gate", "Heal",
	"Iceball", "Jinx", "Kill", "Light", "Magic Missile", "Negate", "Open", "Protection",
	"Quickness", "Resurrect", "Sleep", "Tremor", "Undead", "View", "Winds", "X-it", "Y-up", "Z-down",
]

const NAMES_KO: Array[String] = [
	"깨우기", "순간이동", "해독", "해제", "에너지장", "화염구", "차원문", "치유",
	"얼어붙은 구슬", "교란", "죽음", "빛", "마법 화살", "마법 무효화", "열기", "보호",
	"신속", "부활", "수면", "지진", "언데드", "투시", "바람", "탈출", "상승", "하강",
]

## Offensive damage (xu4 spellMagicAttack). -1 = none. Equal min/max = fixed.
## Magic Missile: classic 16–64 (xu4 call args were swapped).
const DAMAGE_MIN: Array[int] = [
	-1, -1, -1, -1, -1, 24, -1, -1,
	32, -1, 232, -1, 16, -1, -1, -1,
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
]
const DAMAGE_MAX: Array[int] = [
	-1, -1, -1, -1, -1, 128, -1, -1,
	224, -1, 232, -1, 64, -1, -1, -1,
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
]


static func letter(spell_id: int) -> String:
	if spell_id < 0 or spell_id >= COUNT:
		return "?"
	return String.chr(65 + spell_id) ## 'A' + id


static func mp_cost(spell_id: int) -> int:
	if spell_id < 0 or spell_id >= COUNT:
		return 0
	return MP_COST[spell_id]


static func name_of(spell_id: int, lang: String = "en") -> String:
	if spell_id < 0 or spell_id >= COUNT:
		return "?"
	return NAMES_KO[spell_id] if lang == "ko" else NAMES_EN[spell_id]


static func damage_text(spell_id: int) -> String:
	if spell_id < 0 or spell_id >= COUNT:
		return ""
	var lo := DAMAGE_MIN[spell_id]
	var hi := DAMAGE_MAX[spell_id]
	if lo < 0 or hi < 0:
		return ""
	if lo == hi:
		return str(lo)
	return "%d-%d" % [lo, hi]
