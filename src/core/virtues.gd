class_name Virtues
extends Object

## Ultima IV virtue / class indices (same order as xu4 / original).

enum Id {
	HONESTY = 0,
	COMPASSION = 1,
	VALOR = 2,
	JUSTICE = 3,
	SACRIFICE = 4,
	HONOR = 5,
	SPIRITUALITY = 6,
	HUMILITY = 7,
}

enum ClassId {
	MAGE = 0,
	BARD = 1,
	FIGHTER = 2,
	DRUID = 3,
	TINKER = 4,
	PALADIN = 5,
	RANGER = 6,
	SHEPHERD = 7,
}

const NAMES_EN := [
	"Honesty", "Compassion", "Valor", "Justice",
	"Sacrifice", "Honor", "Spirituality", "Humility",
]

const NAMES_KO := [
	"정직", "연민", "용맹", "정의",
	"희생", "명예", "영성", "겸손",
]

const CLASS_NAMES_EN := [
	"Mage", "Bard", "Fighter", "Druid",
	"Tinker", "Paladin", "Ranger", "Shepherd",
]

const CLASS_NAMES_KO := [
	"마법사", "음유시인", "전사", "드루이드",
	"땜장이", "성기사", "레인저", "양치기",
]

## Starting world coords per class (xu4 initValuesForClass).
const CLASS_START := [
	Vector2i(231, 136), # Mage — Moonglow
	Vector2i(83, 105),  # Bard — Britain
	Vector2i(35, 221),  # Fighter — Jhelom
	Vector2i(59, 44),   # Druid — Yew
	Vector2i(158, 21),  # Tinker — Minoc
	Vector2i(105, 183), # Paladin — Trinsic
	Vector2i(23, 129),  # Ranger — Skara Brae
	Vector2i(186, 171), # Shepherd — Magincia
]


static func name_of(virtue: int, lang: String = "en") -> String:
	if virtue < 0 or virtue > 7:
		return "?"
	return NAMES_KO[virtue] if lang == "ko" else NAMES_EN[virtue]


static func class_name_of(klass: int, lang: String = "en") -> String:
	if klass < 0 or klass > 7:
		return "?"
	return CLASS_NAMES_KO[klass] if lang == "ko" else CLASS_NAMES_EN[klass]
