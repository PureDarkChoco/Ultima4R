extends Node

## Scene paths for the intro → world flow.

const BOOT := "res://scenes/boot.tscn"
const MAIN_MENU := "res://scenes/main_menu.tscn"
const STORY_SEQUENCE := "res://scenes/intro/story_sequence.tscn"
const VIRTUE_QUESTIONS := "res://scenes/intro/virtue_questions.tscn"
const NAME_GENDER := "res://scenes/intro/name_gender.tscn"
const CLASS_REVEAL := "res://scenes/intro/class_reveal.tscn"
const STUB_WORLD := "res://scenes/world/stub_world.tscn"

## Character-creation blink: out → brief black → in.
const FADE_OUT_SEC := 0.32
const FADE_HOLD_SEC := 0.10
const FADE_IN_SEC := 0.42

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _fading := false


func _ready() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	_fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.visible = false
	_fade_layer.add_child(_fade_rect)


func go(path: String, fade: bool = false) -> void:
	if fade:
		_go_with_fade(path)
	else:
		get_tree().change_scene_to_file(path)


func to_menu() -> void:
	go(MAIN_MENU)


func to_new_game() -> void:
	## xu4 initiateNewGame: name/sex first (no fade from menu), then story.
	go(NAME_GENDER)


func to_story() -> void:
	go(STORY_SEQUENCE, true)


func to_virtue_questions() -> void:
	go(VIRTUE_QUESTIONS, true)


func to_name_gender() -> void:
	go(NAME_GENDER)


func to_class_reveal() -> void:
	go(CLASS_REVEAL, true)


func to_world(fade: bool = false) -> void:
	## fade=false for menu Journey (J); fade=true after class reveal.
	go(STUB_WORLD, fade)


func _go_with_fade(path: String) -> void:
	if _fading:
		return
	_fading = true
	_fade_rect.visible = true
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, FADE_OUT_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_interval(FADE_HOLD_SEC)
	tw.tween_callback(func() -> void:
		get_tree().change_scene_to_file(path)
	)
	tw.tween_property(_fade_rect, "color:a", 0.0, FADE_IN_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_fade_rect.visible = false
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fading = false
	)
