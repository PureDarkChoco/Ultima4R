extends Node

## Scene paths for the intro → world flow.

const BOOT := "res://scenes/boot.tscn"
const MAIN_MENU := "res://scenes/main_menu.tscn"
const STORY_SEQUENCE := "res://scenes/intro/story_sequence.tscn"
const VIRTUE_QUESTIONS := "res://scenes/intro/virtue_questions.tscn"
const NAME_GENDER := "res://scenes/intro/name_gender.tscn"
const CLASS_REVEAL := "res://scenes/intro/class_reveal.tscn"
const STUB_WORLD := "res://scenes/world/stub_world.tscn"


func go(path: String) -> void:
	get_tree().change_scene_to_file(path)


func to_menu() -> void:
	go(MAIN_MENU)


func to_new_game() -> void:
	## xu4 initiateNewGame: name/sex first, then story + questions.
	go(NAME_GENDER)


func to_story() -> void:
	go(STORY_SEQUENCE)


func to_virtue_questions() -> void:
	go(VIRTUE_QUESTIONS)


func to_name_gender() -> void:
	go(NAME_GENDER)


func to_class_reveal() -> void:
	go(CLASS_REVEAL)


func to_world() -> void:
	go(STUB_WORLD)
