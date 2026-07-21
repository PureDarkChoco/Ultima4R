class_name ReagentIcons
extends Object

## Ultima IV magic reagent icon registry (xu4 REAG_* indices).
## Art lives in `res://assets/ui/reagents/`.

enum Id {
	SULPHUROUS_ASH = 0,
	GINSENG = 1,
	GARLIC = 2,
	SPIDER_SILK = 3,
	BLOOD_MOSS = 4,
	BLACK_PEARL = 5,
	NIGHTSHADE = 6,
	MANDRAKE_ROOT = 7,
}

const DIR := "res://assets/ui/reagents/"

const PATHS := {
	Id.SULPHUROUS_ASH: DIR + "sulphurous_ash.png",
	Id.GINSENG: DIR + "ginseng.png",
	Id.GARLIC: DIR + "garlic.png",
	Id.SPIDER_SILK: DIR + "spider_silk.png",
	Id.BLOOD_MOSS: DIR + "blood_moss.png",
	Id.BLACK_PEARL: DIR + "black_pearl.png",
	Id.NIGHTSHADE: DIR + "nightshade.png",
	Id.MANDRAKE_ROOT: DIR + "mandrake_root.png",
}

const NAME_TO_ID := {
	"sulphurous ash": Id.SULPHUROUS_ASH,
	"sulfurous ash": Id.SULPHUROUS_ASH,
	"ash": Id.SULPHUROUS_ASH,
	"ginseng": Id.GINSENG,
	"garlic": Id.GARLIC,
	"spider silk": Id.SPIDER_SILK,
	"silk": Id.SPIDER_SILK,
	"blood moss": Id.BLOOD_MOSS,
	"moss": Id.BLOOD_MOSS,
	"black pearl": Id.BLACK_PEARL,
	"pearl": Id.BLACK_PEARL,
	"nightshade": Id.NIGHTSHADE,
	"mandrake root": Id.MANDRAKE_ROOT,
	"mandrake": Id.MANDRAKE_ROOT,
}


static func path_for_id(reagent_id: int) -> String:
	return str(PATHS.get(reagent_id, ""))


static func path_for_name(reagent_name: String) -> String:
	var key := reagent_name.strip_edges().to_lower()
	if not NAME_TO_ID.has(key):
		return ""
	return path_for_id(int(NAME_TO_ID[key]))


static func texture_for_id(reagent_id: int) -> Texture2D:
	var path := path_for_id(reagent_id)
	if path.is_empty():
		return null
	return load(path) as Texture2D


static func texture_for_name(reagent_name: String) -> Texture2D:
	var path := path_for_name(reagent_name)
	if path.is_empty():
		return null
	return load(path) as Texture2D
