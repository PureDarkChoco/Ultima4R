class_name TitleExeData
extends RefCounted

## Loads intro string tables from Ultima IV TITLE.EXE (xu4 IntroBinData offsets).

const INTRO_TEXT_OFFSET := 17444 # xu4: 17445 - 1
const QUESTION_COUNT := 28
const STORY_COUNT := 24
const GYPSY_COUNT := 15

const GYP_PLACES_FIRST := 0
const GYP_PLACES_TWOMORE := 1
const GYP_PLACES_LAST := 2
const GYP_UPON_TABLE := 3
# Indices 4..11 = virtue card names
const GYP_SEGUE1 := 13
const GYP_SEGUE2 := 14

var questions: Array[String] = []
var story: Array[String] = []
var gypsy: Array[String] = []
var loaded: bool = false
var source_path: String = ""


func load_from_path(path: String) -> bool:
	questions.clear()
	story.clear()
	gypsy.clear()
	loaded = false
	source_path = path

	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_warning("TitleExeData: cannot read %s" % path)
		return false
	if bytes.size() <= INTRO_TEXT_OFFSET:
		push_warning("TitleExeData: file too small (%d)" % bytes.size())
		return false

	var cursor := INTRO_TEXT_OFFSET
	var q_result := _read_string_table(bytes, cursor, QUESTION_COUNT)
	questions = q_result[0]
	cursor = q_result[1]

	var s_result := _read_string_table(bytes, cursor, STORY_COUNT)
	story = s_result[0]
	cursor = s_result[1]

	var g_result := _read_string_table(bytes, cursor, GYPSY_COUNT)
	gypsy = g_result[0]

	for i in gypsy.size():
		gypsy[i] = gypsy[i].rstrip("\n")

	loaded = questions.size() == QUESTION_COUNT and gypsy.size() == GYPSY_COUNT
	if not loaded:
		push_warning("TitleExeData: unexpected string counts q=%d g=%d" % [questions.size(), gypsy.size()])
	return loaded


## Same indexing as xu4 IntroController::getQuestion(v1, v2). Requires v1 < v2.
static func question_index(v1: int, v2: int) -> int:
	if v1 < 0 or v2 <= v1 or v2 > 7:
		return -1
	var i := 0
	var d := 7
	var a := v1
	var b := v2
	while a > 0:
		i += d
		d -= 1
		a -= 1
		b -= 1
	return i + b - 1


func question_for_pair(v1: int, v2: int) -> String:
	if not loaded:
		return ""
	var idx := question_index(v1, v2)
	if idx < 0 or idx >= questions.size():
		return ""
	return questions[idx]


func gypsy_lead_for_round(round_i: int) -> String:
	if not loaded:
		return ""
	var n := GYP_PLACES_FIRST
	if round_i == 6:
		n = GYP_PLACES_LAST
	elif round_i > 0:
		n = GYP_PLACES_TWOMORE
	return "%s %s" % [gypsy[n].strip_edges(), gypsy[GYP_UPON_TABLE].strip_edges()]


func virtue_card_name(virtue: int) -> String:
	if not loaded or virtue < 0 or virtue > 7:
		return Virtues.name_of(virtue)
	return gypsy[virtue + 4]


func gypsy_cards_line(v1: int, v2: int) -> String:
	return "%s and %s.  She says" % [virtue_card_name(v1), virtue_card_name(v2)]


func _read_string_table(bytes: PackedByteArray, start: int, count: int) -> Array:
	var out: Array[String] = []
	var i := start
	for _n in count:
		if i >= bytes.size():
			break
		var end := i
		while end < bytes.size() and bytes[end] != 0:
			end += 1
		# TITLE.EXE strings are ASCII/CP437 Latin text; latin-1 preserves bytes.
		out.append(bytes.slice(i, end).get_string_from_ascii())
		i = end + 1 # skip NUL
	return [out, i]
