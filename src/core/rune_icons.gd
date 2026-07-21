class_name RuneIcons
extends Object

## Virtue rune icons (same order as Virtues.Id / xu4).
## Art lives in `res://assets/ui/runes/`.

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

const DIR := "res://assets/ui/runes/"

const PATHS := {
	Id.HONESTY: DIR + "honesty.png",
	Id.COMPASSION: DIR + "compassion.png",
	Id.VALOR: DIR + "valor.png",
	Id.JUSTICE: DIR + "justice.png",
	Id.SACRIFICE: DIR + "sacrifice.png",
	Id.HONOR: DIR + "honor.png",
	Id.SPIRITUALITY: DIR + "spirituality.png",
	Id.HUMILITY: DIR + "humility.png",
}

const NAME_TO_ID := {
	"honesty": Id.HONESTY,
	"compassion": Id.COMPASSION,
	"valor": Id.VALOR,
	"justice": Id.JUSTICE,
	"sacrifice": Id.SACRIFICE,
	"honor": Id.HONOR,
	"spirituality": Id.SPIRITUALITY,
	"humility": Id.HUMILITY,
}


static func path_for_id(rune_id: int) -> String:
	return str(PATHS.get(rune_id, ""))


static func path_for_name(rune_name: String) -> String:
	var key := rune_name.strip_edges().to_lower()
	if not NAME_TO_ID.has(key):
		return ""
	return path_for_id(int(NAME_TO_ID[key]))


static func texture_for_id(rune_id: int) -> Texture2D:
	var path := path_for_id(rune_id)
	if path.is_empty():
		return null
	return load(path) as Texture2D


static func texture_for_name(rune_name: String) -> Texture2D:
	var path := path_for_name(rune_name)
	if path.is_empty():
		return null
	return load(path) as Texture2D


static func texture_for_virtue(virtue_id: int) -> Texture2D:
	## Same index as Virtues.Id.
	return texture_for_id(virtue_id)
