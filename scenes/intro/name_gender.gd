extends Control

## xu4 initiateNewGame: name + sex before story / virtue questions.
## Full-screen scene, or embedded in main-menu map frame via begin_embedded().

signal cancelled ## Embedded mode: return to Journey menu (not a scene change).

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
@onready var _panel: PanelContainer = %Panel
@onready var _bg: ColorRect = $ColorRect
@onready var _center: CenterContainer = $Center

var _sex_group := ButtonGroup.new()
var _name_editing := false
var _embedded := false
## Set true before add_child when hosting in MainMenu (avoids one-frame full-screen flash).
var prepare_embedded := false


func _ready() -> void:
	if prepare_embedded:
		_embedded = true
	UiTheme.apply_root(self)
	if _bg:
		_bg.color = UiTheme.BG
		if _embedded:
			_bg.visible = false
	if _panel:
		if _embedded:
			_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		else:
			_panel.add_theme_stylebox_override("panel", UiTheme.make_panel())

	UiTheme.style_label(_prompt, 18, UiTheme.MUTED)
	UiTheme.style_label(_sex_prompt, 18, UiTheme.MUTED)
	UiTheme.style_label(_class_line, 16, UiTheme.ACCENT)
	UiTheme.style_label(_hint, 13, UiTheme.MUTED)
	if _hint:
		_hint.visible = false
	UiTheme.style_button(_continue)
	UiTheme.style_button(_back)

	if _portrait:
		_portrait.visible = false
		_portrait.texture = null
		_portrait.custom_minimum_size = Vector2.ZERO

	_style_name_field()
	_name.focus_mode = Control.FOCUS_ALL
	_name.placeholder_text = "Avatar"
	_name.text = GameState.player_name
	_name.editable = false
	_name.gui_input.connect(_on_name_gui_input)
	_name.focus_exited.connect(_end_name_edit)
	_name.text_submitted.connect(_on_name_submitted)
	_name.focus_entered.connect(_apply_name_text_colors)
	_name.text_changed.connect(func(_t: String) -> void: _apply_name_text_colors())

	for btn in [_male, _female]:
		btn.toggle_mode = true
		btn.button_group = _sex_group
		btn.focus_mode = Control.FOCUS_ALL
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_wire_focus_neighbors()

	_male.pressed.connect(func() -> void: _set_sex("male"))
	_female.pressed.connect(func() -> void: _set_sex("female"))
	## Arrow / focus move selects immediately — no Enter needed.
	_male.focus_entered.connect(func() -> void: _set_sex("male"))
	_female.focus_entered.connect(func() -> void: _set_sex("female"))
	_continue.pressed.connect(_on_continue)
	_back.pressed.connect(_on_back)

	GameState.language_changed.connect(func(_l: String) -> void: _refresh())
	if not _embedded:
		_set_sex(GameState.player_sex if GameState.player_sex in ["male", "female"] else "male")
		_refresh()
		_name.grab_focus()


func is_embedded() -> bool:
	return _embedded and visible


func begin_embedded(frame_rect: Rect2) -> void:
	## Mount into main-menu map frame (no full-screen chrome / scene change).
	_embedded = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _bg:
		_bg.visible = false
	if _hint:
		_hint.visible = false
	if _panel:
		_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_panel.custom_minimum_size = Vector2(minf(frame_rect.size.x * 0.92, 480.0), 0)
	set_embed_rect(frame_rect)
	_name.text = GameState.player_name
	_name_editing = false
	_name.editable = false
	_apply_name_text_colors()
	_set_sex(GameState.player_sex if GameState.player_sex in ["male", "female"] else "male")
	_refresh()
	call_deferred("_focus_name")


func set_embed_rect(frame_rect: Rect2) -> void:
	if not _embedded:
		return
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	anchor_right = 0.0
	anchor_bottom = 0.0
	position = frame_rect.position
	size = frame_rect.size
	custom_minimum_size = frame_rect.size
	if _center:
		_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _panel:
		_panel.custom_minimum_size = Vector2(minf(frame_rect.size.x * 0.92, 480.0), 0)


func close_embedded() -> void:
	visible = false
	_embedded = false
	_name_editing = false
	if _name:
		_name.editable = false


func _focus_name() -> void:
	if is_instance_valid(_name):
		_name.grab_focus()


func _style_name_field() -> void:
	## Underline-only field; text stays white in all edit/focus states.
	_name.add_theme_font_size_override("font_size", 20)
	UiTheme.apply_font(_name)
	var line := _make_name_underline()
	var line_focus := _make_name_underline(true)
	for style_name in ["normal", "read_only", "focus"]:
		_name.add_theme_stylebox_override(style_name, line_focus if style_name == "focus" else line)
	_apply_name_text_colors()


func _make_name_underline(focused: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_width_left = 0
	sb.border_width_top = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 2
	sb.border_color = UiTheme.ACCENT if focused else UiTheme.TEXT
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	return sb


func _apply_name_text_colors() -> void:
	if _name == null:
		return
	var white := UiTheme.TEXT
	_name.add_theme_color_override("font_color", white)
	_name.add_theme_color_override("font_uneditable_color", white)
	_name.add_theme_color_override("font_selected_color", white)
	_name.add_theme_color_override("font_placeholder_color", Color(white.r, white.g, white.b, 0.45))
	_name.add_theme_color_override("caret_color", white)
	_name.add_theme_color_override("selection_color", Color(UiTheme.ACCENT.r, UiTheme.ACCENT.g, UiTheme.ACCENT.b, 0.35))


func _wire_focus_neighbors() -> void:
	## Character-create navigation does not wrap (no loops).
	_name.focus_neighbor_top = _name.get_path_to(_name)
	_name.focus_neighbor_left = _name.get_path_to(_name)
	_name.focus_neighbor_right = _name.get_path_to(_name)
	## bottom → selected sex (see _sync_sex_focus_neighbors)

	## Sex: left ends at Male, right ends at Female (no wrap).
	_male.focus_neighbor_left = _male.get_path_to(_male)
	_male.focus_neighbor_right = _male.get_path_to(_female)
	_male.focus_neighbor_top = _male.get_path_to(_name)
	_male.focus_neighbor_bottom = _male.get_path_to(_continue)

	_female.focus_neighbor_left = _female.get_path_to(_male)
	_female.focus_neighbor_right = _female.get_path_to(_female)
	_female.focus_neighbor_top = _female.get_path_to(_name)
	_female.focus_neighbor_bottom = _female.get_path_to(_continue)

	## Actions: left ends at Back, right ends at Continue; no wrap below.
	_back.focus_neighbor_left = _back.get_path_to(_back)
	_back.focus_neighbor_right = _back.get_path_to(_continue)
	_back.focus_neighbor_bottom = _back.get_path_to(_back)

	_continue.focus_neighbor_left = _continue.get_path_to(_back)
	_continue.focus_neighbor_right = _continue.get_path_to(_continue)
	_continue.focus_neighbor_bottom = _continue.get_path_to(_continue)

	_sync_sex_focus_neighbors()


func _sync_sex_focus_neighbors() -> void:
	var sex_btn: Button = _female if GameState.player_sex == "female" else _male
	_name.focus_neighbor_bottom = _name.get_path_to(sex_btn)
	_continue.focus_neighbor_top = _continue.get_path_to(sex_btn)
	_back.focus_neighbor_top = _back.get_path_to(sex_btn)


func _selected_sex_button() -> Button:
	return _female if GameState.player_sex == "female" else _male


func _unhandled_input(event: InputEvent) -> void:
	if _embedded and not visible:
		return
	## Only name/gender may leave character creation via Esc (→ main menu).
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
		if _name_editing:
			_end_name_edit()
			_name.grab_focus()
		else:
			_on_back()
		get_viewport().set_input_as_handled()
		return

	if _name.has_focus() and not _name_editing:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("confirm"):
			_begin_name_edit()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
			_selected_sex_button().grab_focus()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
			## Top of form — no wrap to Continue/Back.
			get_viewport().set_input_as_handled()
			return

	## Sex: no left/right wrap past Male / Female.
	if _male.has_focus() and (
		event.is_action_pressed("ui_left") or event.is_action_pressed("move_left")
	):
		get_viewport().set_input_as_handled()
		return
	if _female.has_focus() and (
		event.is_action_pressed("ui_right") or event.is_action_pressed("move_right")
	):
		get_viewport().set_input_as_handled()
		return

	## From sex row, down always lands on Continue (Back is left on the same line).
	if (_male.has_focus() or _female.has_focus()) and (
		event.is_action_pressed("ui_down") or event.is_action_pressed("move_down")
	):
		_continue.grab_focus()
		get_viewport().set_input_as_handled()
		return

	## From action row, up returns to the *selected* sex (preserve female/male).
	if (_continue.has_focus() or _back.has_focus()) and (
		event.is_action_pressed("ui_up") or event.is_action_pressed("move_up")
	):
		_selected_sex_button().grab_focus()
		get_viewport().set_input_as_handled()
		return

	## Bottom of form — no wrap back to name.
	if (_continue.has_focus() or _back.has_focus()) and (
		event.is_action_pressed("ui_down") or event.is_action_pressed("move_down")
	):
		get_viewport().set_input_as_handled()
		return

	## Actions: no left/right wrap past Back / Continue.
	if _back.has_focus() and (
		event.is_action_pressed("ui_left") or event.is_action_pressed("move_left")
	):
		get_viewport().set_input_as_handled()
		return
	if _continue.has_focus() and (
		event.is_action_pressed("ui_right") or event.is_action_pressed("move_right")
	):
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
	_apply_name_text_colors()
	_name.grab_focus()
	_name.caret_column = _name.text.length()


func _end_name_edit() -> void:
	if not _name_editing and not _name.editable:
		return
	_name_editing = false
	_name.editable = false
	_apply_name_text_colors()


func _on_name_submitted(_t: String) -> void:
	_end_name_edit()
	## Keep current sex — never force Male when leaving the name field.
	_selected_sex_button().grab_focus()


func _set_sex(sex: String) -> void:
	GameState.player_sex = sex
	_male.disabled = false
	_female.disabled = false
	_male.set_pressed_no_signal(sex == "male")
	_female.set_pressed_no_signal(sex == "female")
	_apply_sex_visuals()
	_sync_sex_focus_neighbors()


func refresh_labels() -> void:
	_refresh()


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
	if _hint:
		_hint.visible = false
	_apply_sex_visuals()
	_sync_sex_focus_neighbors()


func _apply_sex_visuals() -> void:
	var male_on := GameState.player_sex == "male"
	_male.text = "♂  %s" % Locale.t("sex_male")
	_female.text = "♀  %s" % Locale.t("sex_female")
	UiTheme.style_choice_button(_male, male_on)
	UiTheme.style_choice_button(_female, not male_on)


func _on_back() -> void:
	if _embedded:
		cancelled.emit()
	else:
		SceneRouter.to_menu("new")


func _on_continue() -> void:
	var n := _name.text.strip_edges()
	if n.is_empty():
		n = "Avatar"
	GameState.player_name = n
	SceneRouter.to_story()
