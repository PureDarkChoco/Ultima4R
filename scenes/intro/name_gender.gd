extends Control

## xu4 initiateNewGame: name + sex before story / virtue questions.

const PORTRAIT_MALE := "res://assets/portraits/companions/avatar_male.png"
const PORTRAIT_FEMALE := "res://assets/portraits/companions/avatar_female.png"
const PORTRAIT_H := 160.0

@onready var _prompt: Label = %Prompt
@onready var _sex_prompt: Label = %SexPrompt
@onready var _class_line: Label = %ClassLine
@onready var _portrait: TextureRect = %Portrait
@onready var _name: LineEdit = %NameEdit
@onready var _male: Button = %Male
@onready var _female: Button = %Female
@onready var _continue: Button = %Continue
@onready var _back: Button = %Back
@onready var _hint: Label = %Hint

var _sex_group := ButtonGroup.new()
var _name_editing := false
var _tex_male: Texture2D
var _tex_female: Texture2D


func _ready() -> void:
	UiTheme.apply_root(self)
	$ColorRect.color = UiTheme.BG
	%Panel.add_theme_stylebox_override("panel", UiTheme.make_panel())

	UiTheme.style_label(_prompt, 18, UiTheme.MUTED)
	UiTheme.style_label(_sex_prompt, 18, UiTheme.MUTED)
	UiTheme.style_label(_class_line, 16, UiTheme.ACCENT)
	UiTheme.style_label(_hint, 13, UiTheme.MUTED)
	UiTheme.style_button(_continue)
	UiTheme.style_button(_back)

	_tex_male = load(PORTRAIT_MALE) as Texture2D
	_tex_female = load(PORTRAIT_FEMALE) as Texture2D
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_portrait.custom_minimum_size = Vector2(PORTRAIT_H * 0.85, PORTRAIT_H)

	_name.add_theme_font_size_override("font_size", 20)
	UiTheme.apply_font(_name)
	_name.focus_mode = Control.FOCUS_ALL
	_name.placeholder_text = "Avatar"
	_name.text = GameState.player_name
	_name.editable = false
	_name.gui_input.connect(_on_name_gui_input)
	_name.focus_exited.connect(_end_name_edit)
	_name.text_submitted.connect(_on_name_submitted)

	for btn in [_male, _female]:
		btn.toggle_mode = true
		btn.button_group = _sex_group
		btn.focus_mode = Control.FOCUS_ALL
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_wire_focus_neighbors()

	_male.pressed.connect(func() -> void: _set_sex("male"))
	_female.pressed.connect(func() -> void: _set_sex("female"))
	_continue.pressed.connect(_on_continue)
	_back.pressed.connect(func() -> void: SceneRouter.to_menu())

	GameState.language_changed.connect(func(_l: String) -> void: _refresh())
	_set_sex(GameState.player_sex if GameState.player_sex in ["male", "female"] else "male")
	_refresh()
	_name.grab_focus()


func _wire_focus_neighbors() -> void:
	_name.focus_neighbor_bottom = _name.get_path_to(_male)
	_name.focus_neighbor_top = _name.get_path_to(_back)

	_male.focus_neighbor_left = _male.get_path_to(_female)
	_male.focus_neighbor_right = _male.get_path_to(_female)
	_male.focus_neighbor_top = _male.get_path_to(_name)
	_male.focus_neighbor_bottom = _male.get_path_to(_continue)

	_female.focus_neighbor_left = _female.get_path_to(_male)
	_female.focus_neighbor_right = _female.get_path_to(_male)
	_female.focus_neighbor_top = _female.get_path_to(_name)
	_female.focus_neighbor_bottom = _female.get_path_to(_continue)

	_continue.focus_neighbor_top = _continue.get_path_to(_male)
	_continue.focus_neighbor_bottom = _continue.get_path_to(_back)
	_back.focus_neighbor_top = _back.get_path_to(_continue)
	_back.focus_neighbor_bottom = _back.get_path_to(_name)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
		if _name_editing:
			_end_name_edit()
			_name.grab_focus()
		else:
			SceneRouter.to_menu()
		get_viewport().set_input_as_handled()
		return

	if _name.has_focus() and not _name_editing:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("confirm"):
			_begin_name_edit()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
			_male.grab_focus()
			get_viewport().set_input_as_handled()
			return

	if _name_editing and _name.has_focus():
		return

	if event.is_action_pressed("choice_a"):
		_set_sex("male")
		_male.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("choice_b"):
		_set_sex("female")
		_female.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm") and get_viewport().gui_get_focus_owner() == null:
		_on_continue()
		get_viewport().set_input_as_handled()


func _on_name_gui_input(event: InputEvent) -> void:
	if _name_editing:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_begin_name_edit()
		_name.accept_event()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("confirm"):
		_begin_name_edit()
		_name.accept_event()


func _begin_name_edit() -> void:
	if _name_editing:
		return
	_name_editing = true
	_name.editable = true
	_name.grab_focus()
	_name.caret_column = _name.text.length()


func _end_name_edit() -> void:
	if not _name_editing and not _name.editable:
		return
	_name_editing = false
	_name.editable = false


func _on_name_submitted(_t: String) -> void:
	_end_name_edit()
	_male.grab_focus()


func _set_sex(sex: String) -> void:
	GameState.player_sex = sex
	_male.disabled = false
	_female.disabled = false
	_male.set_pressed_no_signal(sex == "male")
	_female.set_pressed_no_signal(sex == "female")
	_apply_sex_visuals()


func _refresh() -> void:
	_prompt.text = Locale.t("name_prompt")
	_sex_prompt.text = Locale.t("sex_prompt")
	## Class is unknown until after virtue questions — hide here.
	if GameState.player_class >= 0:
		_class_line.visible = true
		var klass := Virtues.class_name_of(GameState.player_class, GameState.lang_short())
		_class_line.text = Locale.t("you_are", [klass])
	else:
		_class_line.visible = false
		_class_line.text = ""
	_continue.text = Locale.t("continue")
	_back.text = Locale.t("back")
	_hint.text = Locale.t("input_hint_form")
	_apply_sex_visuals()


func _apply_sex_visuals() -> void:
	var male_on := GameState.player_sex == "male"
	_male.text = ("◀ %s ▶" if male_on else "%s") % Locale.t("sex_male")
	_female.text = ("◀ %s ▶" if not male_on else "%s") % Locale.t("sex_female")
	UiTheme.style_choice_button(_male, male_on)
	UiTheme.style_choice_button(_female, not male_on)
	if _portrait:
		_portrait.texture = _tex_male if male_on else _tex_female


func _on_continue() -> void:
	var n := _name.text.strip_edges()
	if n.is_empty():
		n = "Avatar"
	GameState.player_name = n
	SceneRouter.to_story()
