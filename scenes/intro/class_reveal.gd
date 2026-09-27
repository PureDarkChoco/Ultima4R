extends Control

## Black interstitial after virtue questions: show chosen class, wait for a key.

const CLASS_PORTRAITS: Array[String] = [
	"res://assets/portraits/classes/00_mage.png",
	"res://assets/portraits/classes/01_bard.png",
	"res://assets/portraits/classes/02_fighter.png",
	"res://assets/portraits/classes/03_druid.png",
	"res://assets/portraits/classes/04_tinker.png",
	"res://assets/portraits/classes/05_paladin.png",
	"res://assets/portraits/classes/06_ranger.png",
	"res://assets/portraits/classes/07_shepherd.png",
]
const PORTRAIT_PX := 192.0

@onready var _portrait: TextureRect = %Portrait
@onready var _class_line: Label = %ClassLine
@onready var _hint: Label = %Hint


func _ready() -> void:
	UiTheme.apply_root(self)
	## Narrative interstitial — no menu, wait for any key. Ankh, not sword.
	UiTheme.set_menu_cursor(false)
	$ColorRect.color = Color.BLACK
	$ColorRect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_STOP

	UiTheme.style_label(_class_line, 28, UiTheme.TEXT)
	UiTheme.style_label(_hint, 14, UiTheme.MUTED)
	_class_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_class_line.autowrap_mode = TextServer.AUTOWRAP_OFF

	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.custom_minimum_size = Vector2(PORTRAIT_PX, PORTRAIT_PX)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_class_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE

	GameState.language_changed.connect(func(_l: String) -> void: _refresh())
	_refresh()
	call_deferred("grab_focus")


func _refresh() -> void:
	var klass := GameState.player_class
	if klass < 0 or klass > 7:
		klass = 0
	_portrait.texture = load(CLASS_PORTRAITS[klass]) as Texture2D
	var name := Virtues.class_name_of(klass, GameState.lang_short())
	_class_line.text = Locale.t("you_are", [name])
	_hint.text = Locale.t("press_any_key")


func _gui_input(event: InputEvent) -> void:
	## Mouse clicks hit this Control first (full-rect stop filter).
	if _try_continue(event):
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	## Esc only leaves character creation on the name/gender screen.
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		return
	if _try_continue(event):
		get_viewport().set_input_as_handled()


func _try_continue(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
		return false
	if (
		event.is_action_pressed("ui_accept")
		or event.is_action_pressed("confirm")
		or event is InputEventKey
		or event is InputEventJoypadButton
		or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
	):
		SceneRouter.to_world(true)
		return true
	return false
