class_name IntroTextOverlay
extends RefCounted

## Translation overlays for TITLE.EXE intro strings.
## Classic English (en_u4) stays in TITLE.EXE; Modern English / Korean live here.

const PATH := "res://assets/locale/intro_text.json"

var _questions: Dictionary = {} # lang -> Array
var _gypsy: Dictionary = {} # lang -> Array
var _cards_line: Dictionary = {} # lang -> String
var _story: Dictionary = {} # lang -> Array (showStory 0..23)
var loaded: bool = false


func load_overlays() -> bool:
	loaded = false
	if not FileAccess.file_exists(PATH):
		push_warning("IntroTextOverlay: missing %s" % PATH)
		return false
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("IntroTextOverlay: invalid JSON")
		return false
	var root: Dictionary = parsed
	_questions = root.get("questions", {})
	_gypsy = root.get("gypsy", {})
	_cards_line = root.get("cards_line", {})
	_story = root.get("story", {})
	loaded = true
	return true


func has_question(lang: String, idx: int) -> bool:
	var arr: Array = _questions.get(lang, [])
	return idx >= 0 and idx < arr.size() and str(arr[idx]).strip_edges() != ""


func question(lang: String, idx: int) -> String:
	var arr: Array = _questions.get(lang, [])
	if idx < 0 or idx >= arr.size():
		return ""
	return str(arr[idx])


func has_gypsy(lang: String) -> bool:
	var arr: Array = _gypsy.get(lang, [])
	return arr.size() >= 12


func gypsy(lang: String, idx: int) -> String:
	var arr: Array = _gypsy.get(lang, [])
	if idx < 0 or idx >= arr.size():
		return ""
	return str(arr[idx])


func cards_line_fmt(lang: String) -> String:
	return str(_cards_line.get(lang, "%s · %s"))


func has_story(lang: String, idx: int) -> bool:
	var arr: Array = _story.get(lang, [])
	return idx >= 0 and idx < arr.size() and str(arr[idx]).strip_edges() != ""


func story(lang: String, idx: int) -> String:
	var arr: Array = _story.get(lang, [])
	if idx < 0 or idx >= arr.size():
		return ""
	return str(arr[idx])
