class_name SpellIcons
extends Object

## Ultima IV spell icon registry (xu4 spell indices A=0 … Z=25).
## Art lives in `res://assets/ui/spells/`. Missing ids return "".

const DIR := "res://assets/ui/spells/"

const PATHS := {
	Spells.AWAKEN: DIR + "awaken.png",
	Spells.BLINK: DIR + "blink.png",
	Spells.CURE: DIR + "cure.png",
	Spells.DISPEL: DIR + "dispell.png",
	Spells.ENERGY_FIELD: DIR + "energy_field.png",
	Spells.FIREBALL: DIR + "fireball.png",
	Spells.GATE: DIR + "gate.png",
	Spells.HEAL: DIR + "heal.png",
	Spells.ICEBALL: DIR + "iceball.png",
	Spells.JINX: DIR + "jinx.png",
	Spells.KILL: DIR + "kill.png",
	Spells.LIGHT: DIR + "light.png",
	Spells.MAGIC_MISSILE: DIR + "magic_missile.png",
	Spells.NEGATE: DIR + "negate.png",
	Spells.OPEN: DIR + "open.png",
	Spells.PROTECTION: DIR + "protection.png",
	Spells.QUICKNESS: DIR + "quickness.png",
	Spells.RESURRECT: DIR + "resurrect.png",
	Spells.SLEEP: DIR + "sleep.png",
	Spells.TREMOR: DIR + "tremor.png",
	Spells.UNDEAD: DIR + "undead.png",
	Spells.VIEW: DIR + "view.png",
	Spells.WINDS: DIR + "winds.png",
	Spells.XIT: DIR + "x_it.png",
	Spells.Y_UP: DIR + "y_up.png",
	Spells.Z_DOWN: DIR + "z_down.png",
}

const NAME_TO_ID := {
	"awaken": Spells.AWAKEN,
	"깨우기": Spells.AWAKEN,
	"blink": Spells.BLINK,
	"순간이동": Spells.BLINK,
	"cure": Spells.CURE,
	"해독": Spells.CURE,
	"dispell": Spells.DISPEL,
	"dispel": Spells.DISPEL,
	"해제": Spells.DISPEL,
	"energy field": Spells.ENERGY_FIELD,
	"에너지장": Spells.ENERGY_FIELD,
	"fireball": Spells.FIREBALL,
	"화염구": Spells.FIREBALL,
	"gate": Spells.GATE,
	"차원문": Spells.GATE,
	"heal": Spells.HEAL,
	"치유": Spells.HEAL,
	"iceball": Spells.ICEBALL,
	"얼어붙은 구슬": Spells.ICEBALL,
	"jinx": Spells.JINX,
	"교란": Spells.JINX,
	"magic missile": Spells.MAGIC_MISSILE,
	"마법 화살": Spells.MAGIC_MISSILE,
	"negate": Spells.NEGATE,
	"마법 무효화": Spells.NEGATE,
	"light": Spells.LIGHT,
	"빛": Spells.LIGHT,
	"open": Spells.OPEN,
	"열기": Spells.OPEN,
	"protection": Spells.PROTECTION,
	"보호": Spells.PROTECTION,
	"quickness": Spells.QUICKNESS,
	"신속": Spells.QUICKNESS,
	"resurrect": Spells.RESURRECT,
	"부활": Spells.RESURRECT,
	"sleep": Spells.SLEEP,
	"수면": Spells.SLEEP,
	"tremor": Spells.TREMOR,
	"지진": Spells.TREMOR,
	"undead": Spells.UNDEAD,
	"언데드": Spells.UNDEAD,
	"view": Spells.VIEW,
	"투시": Spells.VIEW,
	"winds": Spells.WINDS,
	"바람": Spells.WINDS,
	"x-it": Spells.XIT,
	"x it": Spells.XIT,
	"xit": Spells.XIT,
	"탈출": Spells.XIT,
	"kill": Spells.KILL,
	"죽음": Spells.KILL,
	"y-up": Spells.Y_UP,
	"y up": Spells.Y_UP,
	"yup": Spells.Y_UP,
	"상승": Spells.Y_UP,
	"z-down": Spells.Z_DOWN,
	"z down": Spells.Z_DOWN,
	"zdown": Spells.Z_DOWN,
	"하강": Spells.Z_DOWN,
}


static func path_for_id(spell_id: int) -> String:
	return str(PATHS.get(spell_id, ""))


static func path_for_name(spell_name: String) -> String:
	var key := spell_name.strip_edges().to_lower()
	if not NAME_TO_ID.has(key):
		return ""
	return path_for_id(int(NAME_TO_ID[key]))


static func texture_for_id(spell_id: int) -> Texture2D:
	var path := path_for_id(spell_id)
	if path.is_empty():
		return null
	return load(path) as Texture2D


static func texture_for_name(spell_name: String) -> Texture2D:
	var path := path_for_name(spell_name)
	if path.is_empty():
		return null
	return load(path) as Texture2D
