extends Control

## Text layout mirrors Ultima IV TITLE.EXE menu (C_0B45):
##   row 14 col 2  — "In another world, in a time to come."
##   row 16 col 15 — "Options:"
##   row 17–19 col 11 — Return / Journey / Initiate
##   row 22 col 5  — copyright
## Language / Quit are remake extras on the same option column.

const COLS := 40.0
const ROWS := 25.0

@onready var _tagline: Label = %Tagline
@onready var _options_head: Label = %OptionsHead
@onready var _btn_return: Button = %ReturnView
@onready var _btn_journey: Button = %Journey
@onready var _btn_new: Button = %NewGame
@onready var _btn_lang: Button = %Language
@onready var _btn_quit: Button = %Quit
@onready var _copyright: Label = %Copyright
@onready var _hint: Label = %Hint


func _ready() -> void:
	UiTheme.apply_root(self)
	$ColorRect.color = UiTheme.BG

	UiTheme.style_label(_tagline, 20, UiTheme.TEXT)
	UiTheme.style_label(_options_head, 18, UiTheme.MUTED)
	UiTheme.style_label(_copyright, 14, UiTheme.MUTED)
	UiTheme.style_label(_hint, 13, UiTheme.MUTED)

	for b in [_btn_return, _btn_journey, _btn_new, _btn_lang, _btn_quit]:
		_style_menu_line(b)
		b.focus_mode = Control.FOCUS_ALL

	_btn_return.pressed.connect(_on_return_view)
	_btn_journey.pressed.connect(_on_journey)
	_btn_new.pressed.connect(_on_new)
	_btn_lang.pressed.connect(func() -> void: _cycle_language(1))
	_btn_lang.gui_input.connect(_on_lang_gui_input)
	## Keep ←→ on Language for cycling (don't jump to other menu rows).
	_btn_lang.focus_neighbor_left = _btn_lang.get_path()
	_btn_lang.focus_neighbor_right = _btn_lang.get_path()
	_btn_quit.pressed.connect(func() -> void: get_tree().quit())

	resized.connect(_layout_u4)
	_refresh_text()
	call_deferred("_layout_u4")
	_btn_journey.grab_focus()
	GameState.language_changed.connect(func(_l: String) -> void: _refresh_text())


func _style_menu_line(btn: Button) -> void:
	## Flat line like original character menu — no chrome panel.
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("focus", empty)
	btn.add_theme_color_override("font_color", UiTheme.TEXT)
	btn.add_theme_color_override("font_hover_color", UiTheme.ACCENT)
	btn.add_theme_color_override("font_focus_color", UiTheme.ACCENT)
	btn.add_theme_color_override("font_pressed_color", UiTheme.ACCENT)
	btn.add_theme_font_size_override("font_size", 18)
	UiTheme.apply_font(btn)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.flat = true


func _cell_pos(col: float, row: float) -> Vector2:
	return Vector2(size.x * col / COLS, size.y * row / ROWS)


func _layout_u4() -> void:
	if size.x < 32.0 or size.y < 32.0:
		return
	var line_h := maxf(size.y / ROWS, 22.0)
	var wide := size.x * 0.7

	_place(_tagline, 2.0, 14.0, wide, line_h)
	_place(_options_head, 15.0, 16.0, wide, line_h)
	_place(_btn_return, 11.0, 17.0, wide, line_h)
	_place(_btn_journey, 11.0, 18.0, wide, line_h)
	_place(_btn_new, 11.0, 19.0, wide, line_h)
	_place(_btn_lang, 11.0, 20.0, wide, line_h)
	_place(_btn_quit, 11.0, 21.0, wide, line_h)
	_place(_copyright, 5.0, 22.5, wide, line_h)


func _place(node: Control, col: float, row: float, w: float, h: float) -> void:
	var p := _cell_pos(col, row)
	node.position = p
	node.size = Vector2(w, h)
	node.custom_minimum_size = Vector2(w, h)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_on_return_view()
				accept_event()
			KEY_J:
				_on_journey()
				accept_event()
			KEY_I:
				_on_new()
				accept_event()
			KEY_L:
				_cycle_language(1)
				accept_event()
			KEY_Q:
				get_tree().quit()
				accept_event()


func _on_lang_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k := event as InputEventKey
	var code := k.keycode
	var phys := k.physical_keycode
	if code == KEY_LEFT or phys == KEY_LEFT or event.is_action_pressed("ui_left"):
		_cycle_language(-1)
		_btn_lang.accept_event()
	elif code == KEY_RIGHT or phys == KEY_RIGHT or event.is_action_pressed("ui_right"):
		_cycle_language(1)
		_btn_lang.accept_event()


func _refresh_text() -> void:
	_tagline.text = Locale.t("menu_tagline")
	_options_head.text = Locale.t("menu_options")
	_btn_return.text = Locale.t("menu_return")
	_btn_journey.text = Locale.t("menu_journey")
	_btn_new.text = Locale.t("menu_new")
	_btn_lang.text = "%s: ◂ %s ▸" % [Locale.t("menu_language"), Locale.lang_label()]
	_btn_quit.text = Locale.t("menu_quit")
	_copyright.text = Locale.t("menu_copyright")
	_hint.text = Locale.t("input_hint_menu") + " · R/J/I · F11"


func _on_return_view() -> void:
	## Title map animation not wired yet — keep focus on the classic option.
	_btn_return.grab_focus()


func _on_journey() -> void:
	# Dev shortcut: skip intro questionnaire and jump to the overworld.
	if GameState.player_class < 0:
		GameState.player_name = "Avatar"
		GameState.player_sex = "male"
		GameState.player_class = 0 # Mage
		GameState.start_pos = Virtues.CLASS_START[0]
	GameState.refresh_party_order()
	SceneRouter.to_world()


func _on_new() -> void:
	GameState.reset_party()
	SceneRouter.to_new_game()


func _cycle_language(delta: int = 1) -> void:
	var langs := GameState.LANG_IDS
	var i := langs.find(GameState.language)
	if i < 0:
		i = 0
	GameState.language = langs[posmod(i + delta, langs.size())]
	_btn_lang.grab_focus()
