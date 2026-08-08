extends Control

## Title intro host: TITLES → MAP → MENU (xu4 IntroController until menu).
## Text layout mirrors TITLE.EXE menu (C_0B45) over options_btm band.

const _SaveSlotPanel := preload("res://src/ui/save_slot_panel.gd")
const _SaveGame := preload("res://src/core/save_game.gd")
const _IntroController := preload("res://src/intro/intro_controller.gd")

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
@onready var _text_block: Control = %TextBlock
@onready var _intro_view: TextureRect = %IntroView

var _intro: Node ## IntroController
var _save_panel # SaveSlotPanel
var _load_open := false
var _hold_arm := 0.0
var _move_cd := 0.0
var _held_dir := Vector2i.ZERO
var _move_repeating := false
const HOLD_DELAY := 0.28
const HOLD_INTERVAL := 0.10


func _ready() -> void:
	GameState.restore_menu_language()
	UiTheme.apply_root(self)
	$ColorRect.color = Color.BLACK

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
	_btn_lang.focus_neighbor_left = _btn_lang.get_path()
	_btn_lang.focus_neighbor_right = _btn_lang.get_path()
	_btn_quit.pressed.connect(func() -> void: get_tree().quit())

	resized.connect(_layout_u4)
	_refresh_text()
	call_deferred("_layout_u4")

	_intro = _IntroController.new()
	_intro.name = "IntroController"
	add_child(_intro)
	_intro.mode_changed.connect(_on_intro_mode)
	if not _intro.setup(_intro_view):
		## Fallback: skip titles, show menu on blank canvas.
		_text_block.visible = true
		_apply_pending_focus()
	else:
		_text_block.visible = false
		_hint.visible = false

	GameState.language_changed.connect(func(_l: String) -> void: _refresh_text())


func _on_intro_mode(mode: int) -> void:
	var menu_on := mode == _IntroController.Mode.MENU
	_text_block.visible = menu_on
	_hint.visible = menu_on
	if menu_on:
		call_deferred("_apply_pending_focus")
	else:
		var fo := get_viewport().gui_get_focus_owner()
		if fo:
			fo.release_focus()


func _apply_pending_focus() -> void:
	if _intro and _intro.mode != _IntroController.Mode.MENU:
		return
	match SceneRouter.take_menu_focus():
		"new":
			_btn_new.grab_focus()
		"return":
			_btn_return.grab_focus()
		"language":
			_btn_lang.grab_focus()
		"quit":
			_btn_quit.grab_focus()
		_:
			_btn_journey.grab_focus()


func _style_menu_line(btn: Button) -> void:
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


func _process(delta: float) -> void:
	if not _load_open:
		return
	_move_cd = maxf(0.0, _move_cd - delta)
	_hold_arm = maxf(0.0, _hold_arm - delta)
	var step := 0
	if Input.is_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_UP) or Input.is_action_pressed("ui_up"):
		step = -1
	elif Input.is_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_DOWN) or Input.is_action_pressed("ui_down"):
		step = 1
	if step == 0:
		_held_dir = Vector2i.ZERO
		_move_repeating = false
		_hold_arm = 0.0
		return
	var held := Vector2i(0, step)
	if held != _held_dir:
		_held_dir = held
		_move_repeating = false
		_hold_arm = 0.0
	if _move_cd > 0.0:
		return
	if _move_repeating and _hold_arm > 0.0:
		return
	if _save_panel:
		_save_panel.nudge_cursor(step)
	_move_cd = HOLD_INTERVAL
	if _move_repeating:
		_hold_arm = 0.0
	else:
		_move_repeating = true
		_hold_arm = HOLD_DELAY


func _unhandled_input(event: InputEvent) -> void:
	if _load_open:
		if _handle_load_input(event):
			accept_event()
		return

	var pressed_key: bool = event is InputEventKey and event.pressed and not event.echo
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var joy: bool = event is InputEventJoypadButton and event.pressed

	if _intro == null:
		return

	if _intro.mode == _IntroController.Mode.TITLES or _intro.mode == _IntroController.Mode.MAP:
		if pressed_key or click or (joy and (event as InputEventJoypadButton).button_index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START]):
			_intro.skip_titles_or_advance()
			accept_event()
		return

	if pressed_key:
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
	if _load_open:
		return
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
	if _save_panel and _save_panel.is_open():
		_save_panel.refresh()


func _on_return_view() -> void:
	if _intro:
		_intro.return_to_map()
	else:
		_btn_return.grab_focus()


func _on_journey() -> void:
	if not _SaveGame.any_slot_exists():
		_hint.text = Locale.t("load_none")
		_btn_journey.grab_focus()
		return
	_ensure_save_panel()
	_load_open = true
	_held_dir = Vector2i.ZERO
	_move_repeating = false
	_hold_arm = 0.0
	_move_cd = 0.0
	_save_panel.open_panel(
		_SaveSlotPanel.Mode.LOAD,
		_SaveGame.default_load_cursor()
	)
	if get_viewport().gui_get_focus_owner() != null:
		get_viewport().gui_get_focus_owner().release_focus()


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


func _ensure_save_panel() -> void:
	if _save_panel != null:
		return
	_save_panel = _SaveSlotPanel.new()
	_save_panel.name = "SaveSlotPanel"
	add_child(_save_panel)


func _handle_load_input(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventKey:
		var k := event as InputEventKey
		if (
			k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE
			or k.keycode == KEY_SPACE or k.physical_keycode == KEY_SPACE
		):
			_close_load()
			return true
		if (
			k.keycode == KEY_ENTER or k.physical_keycode == KEY_ENTER
			or k.keycode == KEY_KP_ENTER or k.physical_keycode == KEY_KP_ENTER
		):
			_confirm_load(_save_panel.cursor() if _save_panel else 0)
			return true
		var dig := _digit_0_to_3(k)
		if dig >= 0:
			if _save_panel:
				_save_panel.set_cursor(dig)
			_confirm_load(dig)
			return true
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if jb.button_index == JOY_BUTTON_B:
			_close_load()
			return true
		if jb.button_index == JOY_BUTTON_A:
			_confirm_load(_save_panel.cursor() if _save_panel else 0)
			return true
	return true


func _digit_0_to_3(event: InputEventKey) -> int:
	var code := event.keycode
	var phys := event.physical_keycode
	if code >= KEY_1 and code <= KEY_4:
		return code - KEY_1
	if phys >= KEY_1 and phys <= KEY_4:
		return phys - KEY_1
	if code >= KEY_KP_1 and code <= KEY_KP_4:
		return code - KEY_KP_1
	if phys >= KEY_KP_1 and phys <= KEY_KP_4:
		return phys - KEY_KP_1
	return -1


func _confirm_load(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _SaveGame.SLOT_COUNT:
		return
	var slot_n := slot_index + 1
	if not _SaveGame.slot_exists(slot_n):
		_hint.text = Locale.t("load_empty")
		return
	var data := _SaveGame.read_slot(slot_n)
	if data.is_empty():
		_hint.text = Locale.t("load_empty")
		return
	var game: Variant = data.get("game", {})
	var world: Variant = data.get("world", {})
	if typeof(game) != TYPE_DICTIONARY:
		_hint.text = Locale.t("load_empty")
		return
	GameState.apply_save_dict(game as Dictionary)
	GameState.pending_world_save = world if typeof(world) == TYPE_DICTIONARY else {}
	GameState.session_loaded_slot = slot_n
	GameState.session_did_save = false
	GameState.is_new_game = false
	_SaveGame.set_last_loaded_slot(slot_n)
	_close_load()
	SceneRouter.to_world()


func _close_load() -> void:
	_load_open = false
	if _save_panel:
		_save_panel.close_panel()
	_refresh_text()
	_btn_journey.grab_focus()
