class_name Spells
extends Object

## Ultima IV spells A–Z (xu4 spell.cpp). Index 0 = A … 25 = Z.

const COUNT := 26
const REAGENT_COUNT := 8
const MIXTURE_MAX := 99
## Spell letter indices (0 = A … 25 = Z).
const AWAKEN := 0 ## A
const BLINK := 1 ## B
const CURE := 2 ## C
const DISPEL := 3 ## D
const ENERGY_FIELD := 4 ## E
const FIREBALL := 5 ## F
const GATE := 6 ## G
const HEAL := 7 ## H
const ICEBALL := 8 ## I
const JINX := 9 ## J
const KILL := 10 ## K
const MAGIC_MISSILE := 12 ## M
const NEGATE := 13 ## N
const OPEN := 14 ## O
const PROTECTION := 15 ## P
const QUICKNESS := 16 ## Q
const RESURRECT := 17 ## R
const SLEEP := 18 ## S
const TREMOR := 19 ## T
const UNDEAD := 20 ## U
const VIEW := 21 ## V
const WINDS := 22 ## W

## xu4 Spell::ParamType
const PARAM_NONE := 0
const PARAM_PLAYER := 1
const PARAM_DIR := 2
const PARAM_TYPEDIR := 3
const PARAM_PHASE := 4
## Remake: combat free-aim instead of xu4 PARAM_DIR (Fireball / Iceball / Kill / Magic Missile).
const PARAM_AIM := 5

## xu4 spells[].paramType
const PARAM_TYPE: Array[int] = [
	PARAM_PLAYER, ## A Awaken
	PARAM_DIR, ## B Blink
	PARAM_PLAYER, ## C Cure
	PARAM_DIR, ## D Dispell
	PARAM_TYPEDIR, ## E Energy Field
	PARAM_AIM, ## F Fireball (remake free-aim; xu4 was PARAM_DIR)
	PARAM_PHASE, ## G Gate
	PARAM_PLAYER, ## H Heal
	PARAM_AIM, ## I Iceball (remake free-aim; xu4 was PARAM_DIR)
	PARAM_NONE, ## J Jinx
	PARAM_AIM, ## K Kill (remake free-aim; xu4 was PARAM_DIR)
	PARAM_NONE, ## L Light
	PARAM_AIM, ## M Magic Missile (remake free-aim; xu4 was PARAM_DIR)
	PARAM_NONE, ## N Negate
	PARAM_NONE, ## O Open
	PARAM_NONE, ## P Protection
	PARAM_NONE, ## Q Quickness
	PARAM_PLAYER, ## R Resurrect
	PARAM_NONE, ## S Sleep
	PARAM_NONE, ## T Tremor
	PARAM_NONE, ## U Undead (xu4 PARAM_NONE; remake: turn-undead flag)
	PARAM_NONE, ## V View
	PARAM_DIR, ## W Winds
	PARAM_NONE, ## X X-it
	PARAM_NONE, ## Y Y-up
	PARAM_NONE, ## Z Z-down
]

## xu4 Reagent bit masks (spell.cpp).
const ASH := 1 << 0
const GINSENG := 1 << 1
const GARLIC := 1 << 2
const SILK := 1 << 3
const MOSS := 1 << 4
const PEARL := 1 << 5
const NIGHTSHADE := 1 << 6
const MANDRAKE := 1 << 7

## Exact recipe bitmasks (xu4 spells[].components).
const RECIPE_MASK: Array[int] = [
	GINSENG | GARLIC, ## A Awaken
	SILK | MOSS, ## B Blink
	GINSENG | GARLIC, ## C Cure
	ASH | GARLIC | PEARL, ## D Dispell
	ASH | SILK | PEARL, ## E Energy Field
	ASH | PEARL, ## F Fireball
	ASH | PEARL | MANDRAKE, ## G Gate
	GINSENG | SILK, ## H Heal
	PEARL | MANDRAKE, ## I Iceball
	PEARL | NIGHTSHADE | MANDRAKE, ## J Jinx
	PEARL | NIGHTSHADE, ## K Kill
	ASH, ## L Light
	ASH | PEARL, ## M Magic Missile
	ASH | GARLIC | MANDRAKE, ## N Negate
	ASH | MOSS, ## O Open
	ASH | GINSENG | GARLIC, ## P Protection
	ASH | GINSENG | MOSS, ## Q Quickness
	ASH | GINSENG | GARLIC | SILK | MOSS | MANDRAKE, ## R Resurrect
	SILK | GINSENG, ## S Sleep
	ASH | MOSS | MANDRAKE, ## T Tremor
	ASH | GARLIC, ## U Undead
	NIGHTSHADE | MANDRAKE, ## V View
	ASH | MOSS, ## W Winds
	ASH | SILK | MOSS, ## X X-it
	SILK | MOSS, ## Y Y-up
	SILK | MOSS, ## Z Z-down
]

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

## xu4 LocationContext bits (location.h).
const CTX_WORLDMAP := 0x0001
const CTX_COMBAT := 0x0002
const CTX_CITY := 0x0004
const CTX_DUNGEON := 0x0008
const CTX_ALTAR_ROOM := 0x0010
const CTX_SHRINE := 0x0020
const CTX_ANY := 0xffff
const CTX_NON_COMBAT := CTX_ANY & ~CTX_COMBAT

## xu4 spells[].context
const CONTEXT: Array[int] = [
	CTX_ANY, ## A Awaken
	CTX_WORLDMAP, ## B Blink
	CTX_ANY, ## C Cure
	CTX_ANY, ## D Dispell
	CTX_COMBAT | CTX_DUNGEON, ## E Energy Field
	CTX_COMBAT, ## F Fireball
	CTX_WORLDMAP, ## G Gate
	CTX_ANY, ## H Heal
	CTX_COMBAT, ## I Iceball
	CTX_ANY, ## J Jinx
	CTX_COMBAT, ## K Kill
	CTX_DUNGEON, ## L Light
	CTX_COMBAT, ## M Magic Missile
	CTX_ANY, ## N Negate
	CTX_ANY, ## O Open
	CTX_ANY, ## P Protection
	CTX_ANY, ## Q Quickness
	CTX_NON_COMBAT, ## R Resurrect
	CTX_COMBAT, ## S Sleep
	CTX_COMBAT, ## T Tremor
	CTX_COMBAT, ## U Undead
	CTX_NON_COMBAT, ## V View
	CTX_WORLDMAP, ## W Winds
	CTX_DUNGEON, ## X X-it
	CTX_DUNGEON, ## Y Y-up
	CTX_DUNGEON, ## Z Z-down
]

const CASTERR_NOERROR := 0
const CASTERR_NOMIX := 1
const CASTERR_MPTOOLOW := 2
const CASTERR_FAILED := 3
const CASTERR_WRONGCONTEXT := 4
const CASTERR_COMBATONLY := 5
const CASTERR_DUNGEONONLY := 6
const CASTERR_WORLDMAPONLY := 7

## Offensive damage (xu4 spellMagicAttack). -1 = none. Equal min/max = fixed.
## Magic Missile: classic 16–64 (xu4 call args were swapped).
## Hit chance: xu4 spellMagicAttackAt has no attackHit roll — 100% if a
## creature is on the tile the projectile reaches.
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


static func roll_damage(spell_id: int) -> int:
	## xu4 spellMagicAttack: random((max+1)-min)+min, else maxDamage.
	if spell_id < 0 or spell_id >= COUNT:
		return 0
	var lo := DAMAGE_MIN[spell_id]
	var hi := DAMAGE_MAX[spell_id]
	if lo >= 0 and lo < hi:
		return (randi() % ((hi + 1) - lo)) + lo
	if hi >= 0:
		return hi
	return 0


static func uses_free_aim(spell_id: int) -> bool:
	return param_type(spell_id) == PARAM_AIM


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


static func context_of(spell_id: int) -> int:
	if spell_id < 0 or spell_id >= COUNT:
		return 0
	return CONTEXT[spell_id]


static func context_ok(spell_id: int, loc_ctx: int) -> bool:
	## xu4 spellCheckPrerequisites — (location.context & spell.context) != 0
	return (loc_ctx & context_of(spell_id)) != 0


static func blink_distance(axis_coord: int, toward_positive: bool) -> int:
	## xu4 spellBlink — not a fixed range. Axis coord % 16, then maybe +16.
	var distance := posmod(axis_coord, 16)
	if toward_positive:
		distance = 16 - distance
	var diff := 16 - distance
	if diff > 0 and (randi() % (diff * diff)) > distance:
		distance += 16
	return distance


static func param_type(spell_id: int) -> int:
	if spell_id < 0 or spell_id >= COUNT:
		return PARAM_NONE
	return PARAM_TYPE[spell_id]


static func context_error(spell_id: int) -> int:
	## xu4 spellGetErrorMessage — refine WRONGCONTEXT by the spell's own mask.
	match context_of(spell_id):
		CTX_COMBAT:
			return CASTERR_COMBATONLY
		CTX_DUNGEON:
			return CASTERR_DUNGEONONLY
		CTX_WORLDMAP:
			return CASTERR_WORLDMAPONLY
		_:
			return CASTERR_WRONGCONTEXT


static func recipe_mask(spell_id: int) -> int:
	if spell_id < 0 or spell_id >= COUNT:
		return 0
	return RECIPE_MASK[spell_id]


static func recipe_matches(spell_id: int, selected_mask: int) -> bool:
	## xu4 spellMix — exact component bitmask match.
	return recipe_mask(spell_id) == selected_mask


static func reagents_for_recipe(spell_id: int) -> Array[int]:
	## Reagent indices required by the known recipe (one each).
	var out: Array[int] = []
	var mask := recipe_mask(spell_id)
	for r in REAGENT_COUNT:
		if mask & (1 << r):
			out.append(r)
	return out
