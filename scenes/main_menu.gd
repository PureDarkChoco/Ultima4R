extends Control

## Title intro host: TITLES → MAP → MENU (xu4 IntroController until menu).
## Text layout mirrors TITLE.EXE menu (C_0B45) over options_btm band.

const _SaveSlotPanel := preload("res://src/ui/save_slot_panel.gd")
const _SaveGame := preload("res://src/core/save_game.gd")
const _IntroController := preload("res://src/intro/intro_controller.gd")
const _OptionsPanel := preload("res://src/ui/options_panel.gd")
const _LicensesPanel := preload("res://src/ui/licenses_panel.gd")
const _GameInput := preload("res://src/core/game_input.gd")
const _MenuHoldRepeat := preload("res://src/core/menu_hold_repeat.gd")
const _NAME_GENDER_SCN := preload("res://scenes/intro/name_gender.tscn")

const COLS := 40.0
const ROWS := 25.0
const APP_DISPLAY_VERSION := "0.11.1"

@onready var _tagline: Label = %Tagline
@onready var _options_head: Label = %OptionsHead
@onready var _btn_return: Button = %ReturnView
@onready var _btn_journey: Button = %Journey
@onready var _btn_new: Button = %NewGame
@onready var _btn_options: Button = %Language
@onready var _btn_licenses: Button = %Licenses
@onready var _btn_quit: Button = %Quit
@onready var _copyright: Label = %Copyright
@onready var _hint: Label = %Hint
@onready var _text_block: Control = %TextBlock
@onready var _intro_view: TextureRect = %IntroView

var _intro: Node ## IntroController
var _save_panel # SaveSlotPanel
var _options_panel # OptionsPanel
var _licenses_panel # LicensesPanel
var _name_form: Control ## NameGender scene instance
var _load_open := false
var _create_open := false
var _options_open := false
var _licenses_open := false
## Korean menu: show R)/J)/… prefixes only after keyboard use (hide on gamepad).
var _menu_hotkeys_visible := false
var _menu_hold_repeat = _MenuHoldRepeat.new()


func _ready() -> void:
	UiTheme.apply_root(self)
	$ColorRect.color = Color.BLACK

	UiTheme.style_label(_tagline, 20, UiTheme.TEXT)
	UiTheme.style_label(_options_head, 18, UiTheme.MUTED)
	UiTheme.style_label(_copyright, 14, UiTheme.MUTED)
	_copyright.autowrap_mode = TextServer.AUTOWRAP_OFF
	_copyright.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.style_label(_hint, 13, UiTheme.MUTED)

	for b in [_btn_return, _btn_journey, _btn_new, _btn_options, _btn_licenses, _btn_quit]:
		_style_menu_line(b)
		b.focus_mode = Control.FOCUS_ALL
	_wire_menu_focus_neighbors()

	_btn_return.pressed.connect(_on_return_view)
	_btn_journey.pressed.connect(_on_journey)
	_btn_new.pressed.connect(_on_new)
	_btn_options.pressed.connect(_on_options)
	_btn_licenses.pressed.connect(_on_licenses)
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
		UiTheme.set_menu_cursor(true)
		_apply_pending_focus()
	else:
		_text_block.visible = false
		_hint.visible = false

	GameState.language_changed.connect(func(_l: String) -> void: _refresh_text())
	if not GraphicsSettings.tileset_changed.is_connected(_on_tileset_changed):
		GraphicsSettings.tileset_changed.connect(_on_tileset_changed)
	_ensure_options_panel()
	_ensure_licenses_panel()
	## xu4 introMusic = MUSIC_TOWNS (titles → map → menu).
	AudioSfx.music_play("towne")


func _on_intro_mode(mode: int) -> void:
	var menu_on := mode == _IntroController.Mode.MENU
	## Titles/map intro = no menu yet (ankh); once the command menu (or any
	## sub-panel opened from it) is on screen, the sword shows everywhere.
	UiTheme.set_menu_cursor(menu_on)
	_menu_hold_repeat.reset()
	## Load / create / options forms fill the frame — keep Journey lines hidden.
	_text_block.visible = (
		menu_on and not _load_open and not _create_open
		and not _options_open and not _licenses_open
	)
	## Options head + bottom input hint stay off; actions only inside the map frame.
	_options_head.visible = false
	_hint.visible = false
	if menu_on:
		call_deferred("_layout_u4")
		if not _load_open and not _create_open and not _options_open and not _licenses_open:
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
		"language", "options":
			_btn_options.grab_focus()
		"licenses":
			_btn_licenses.grab_focus()
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


func _wire_menu_focus_neighbors() -> void:
	## Explicit vertical chain so D-pad / stick always walk the Journey list.
	var chain: Array[Button] = [
		_btn_return, _btn_journey, _btn_new, _btn_options, _btn_licenses, _btn_quit
	]
	for i in range(chain.size()):
		var cur := chain[i]
		var prev := chain[(i - 1 + chain.size()) % chain.size()]
		var next := chain[(i + 1) % chain.size()]
		cur.focus_neighbor_top = cur.get_path_to(prev)
		cur.focus_neighbor_bottom = cur.get_path_to(next)
		cur.focus_neighbor_left = cur.get_path_to(cur)
		cur.focus_neighbor_right = cur.get_path_to(cur)
		cur.focus_next = cur.get_path_to(next)
		cur.focus_previous = cur.get_path_to(prev)


func _cell_pos(col: float, row: float) -> Vector2:
	return Vector2(size.x * col / COLS, size.y * row / ROWS)


func _layout_u4() -> void:
	if size.x < 32.0 or size.y < 32.0:
		return
	if _create_open and _name_form != null and is_instance_valid(_name_form):
		_layout_name_form()
		return
	if _load_open and _save_panel != null and is_instance_valid(_save_panel):
		_layout_load_list()
		return
	if _options_open and _options_panel != null and is_instance_valid(_options_panel):
		_layout_options_embed()
		return
	if _licenses_open and _licenses_panel != null and is_instance_valid(_licenses_panel):
		_layout_licenses_embed()
		return
	if (
		_intro != null
		and is_instance_valid(_intro)
		and _intro.mode == _IntroController.Mode.MENU
		and _intro.has_method("map_frame_inner_rect")
	):
		_layout_menu_in_frame()
		return
	## Fallback (intro failed): classic character-grid placement.
	var line_h := maxf(size.y / ROWS, 22.0)
	var wide := size.x * 0.7
	_place(_tagline, 2.0, 14.0, wide, line_h)
	_place(_options_head, 15.0, 16.0, wide, line_h)
	_place(_btn_return, 11.0, 17.0, wide, line_h)
	_place(_btn_journey, 11.0, 18.0, wide, line_h)
	_place(_btn_new, 11.0, 19.0, wide, line_h)
	_place(_btn_options, 11.0, 20.0, wide, line_h)
	_place(_btn_licenses, 11.0, 21.0, wide, line_h)
	_place(_btn_quit, 11.0, 22.0, wide, line_h)
	_place(_copyright, 5.0, 23.0, wide, line_h * 2.0)
	_options_head.visible = false
	_hint.visible = false


## Map-frame inner rect in MainMenu local coords (shared by load / create embeds).
func _frame_content_rect() -> Rect2:
	if _intro == null or not _intro.has_method("map_frame_inner_rect"):
		return Rect2()
	var panel := _logic_rect_to_local(_intro.map_frame_inner_rect() as Rect2i)
	if panel.size.x < 40.0 or panel.size.y < 40.0:
		return Rect2()
	var inset := maxf(panel.size.x, panel.size.y) * 0.02
	inset = clampf(inset, 6.0, 14.0)
	return Rect2(
		panel.position.x + inset,
		panel.position.y + inset,
		panel.size.x - inset * 2.0,
		panel.size.y - inset * 2.0
	)


## Place save-slot list inside the same map frame used by Journey menu.
func _layout_load_list() -> void:
	var r := _frame_content_rect()
	if r.size.x < 40.0:
		return
	if _save_panel.has_method("set_embed_rect"):
		_save_panel.set_embed_rect(r)


func _layout_options_embed() -> void:
	var r := _frame_content_rect()
	if r.size.x < 40.0:
		return
	if _options_panel.has_method("set_embed_rect"):
		_options_panel.set_embed_rect(r)


func _layout_licenses_embed() -> void:
	var r := _frame_content_rect()
	if r.size.x < 40.0:
		return
	if _licenses_panel.has_method("set_embed_rect"):
		_licenses_panel.set_embed_rect(r)


func _layout_name_form() -> void:
	var r := _frame_content_rect()
	if r.size.x < 40.0:
		return
	if _name_form.has_method("set_embed_rect"):
		_name_form.set_embed_rect(r)


## Place menu chrome inside the intro map frame box (centered).
func _layout_menu_in_frame() -> void:
	var panel := _logic_rect_to_local(_intro.map_frame_inner_rect() as Rect2i)
	if panel.size.x < 40.0 or panel.size.y < 40.0:
		return
	## Modest inset so text clears the blue edge (half of earlier inset).
	var inset := maxf(panel.size.x, panel.size.y) * 0.015
	inset = clampf(inset, 4.0, 12.0)
	var x0 := panel.position.x + inset
	var y0 := panel.position.y + inset
	var usable_w := panel.size.x - inset * 2.0
	var usable_h := panel.size.y - inset * 2.0
	if usable_w < 24.0 or usable_h < 24.0:
		return

	## Nudge the whole menu block slightly down inside the frame.
	var menu_shift_y := usable_h * 0.06
	y0 += menu_shift_y
	usable_h = maxf(usable_h - menu_shift_y, 24.0)

	## Tagline + actions share upper block; copyright pinned slightly lower toward the bottom.
	var menu_nodes: Array[Control] = [
		_tagline,
		_btn_return,
		_btn_journey,
		_btn_new,
		_btn_options,
		_btn_licenses,
		_btn_quit,
	]
	_options_head.visible = false
	_hint.visible = false

	var n_menu := menu_nodes.size()
	## Leave space under the last action so two-line copyright can sit lower.
	var menu_block_h := usable_h * 0.76
	var line_h := menu_block_h / float(n_menu)
	var font_main := clampi(int(line_h * 0.62), 12, 28)
	var font_muted := clampi(int(line_h * 0.50), 10, 20)
	for i in n_menu:
		var node := menu_nodes[i]
		node.add_theme_font_size_override("font_size", font_main)
		node.set_anchors_preset(Control.PRESET_TOP_LEFT)
		node.anchor_right = 0.0
		node.anchor_bottom = 0.0
		node.position = Vector2(x0, y0 + line_h * float(i))
		node.size = Vector2(usable_w, line_h)
		node.custom_minimum_size = Vector2(usable_w, line_h)
		if node is Label:
			(node as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if node is Button:
			(node as Button).alignment = HORIZONTAL_ALIGNMENT_CENTER

	var copy_h := maxf(line_h * 1.55, float(font_muted) * 2.4 + 6.0)
	_copyright.add_theme_font_size_override("font_size", font_muted)
	_copyright.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_copyright.anchor_right = 0.0
	_copyright.anchor_bottom = 0.0
	## Sit on the inner bottom edge of the remaining usable area.
	_copyright.position = Vector2(x0, y0 + usable_h - copy_h)
	_copyright.size = Vector2(usable_w, copy_h)
	_copyright.custom_minimum_size = Vector2(usable_w, copy_h)
	_copyright.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_copyright.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


## Convert intro logic (640×400) pixel rect → MainMenu local coords.
func _logic_rect_to_local(r: Rect2i) -> Rect2:
	var lw := float(_IntroController.LOGIC_W)
	var lh := float(_IntroController.LOGIC_H)
	var vs := _intro_view.size
	var s := minf(vs.x / lw, vs.y / lh)
	var cw := lw * s
	var ch := lh * s
	var ox := _intro_view.position.x + (vs.x - cw) * 0.5
	var oy := _intro_view.position.y + (vs.y - ch) * 0.5
	## Snap to whole pixels so embedded UI fonts stay crisp.
	return Rect2(
		Vector2(
			round(ox + float(r.position.x) * s),
			round(oy + float(r.position.y) * s)
		),
		Vector2(
			round(float(r.size.x) * s),
			round(float(r.size.y) * s)
		)
	)


func _place(node: Control, col: float, row: float, w: float, h: float) -> void:
	var p := _cell_pos(col, row)
	node.position = p
	node.size = Vector2(w, h)
	node.custom_minimum_size = Vector2(w, h)


func _process(delta: float) -> void:
	if _create_open:
		return
	var base_menu_open: bool = (
		not _load_open and not _options_open and not _licenses_open
		and _intro != null and _intro.mode == _IntroController.Mode.MENU
	)
	if not base_menu_open and not _load_open and not _options_open and not _licenses_open:
		_menu_hold_repeat.reset()
		return
	var held := Vector2i(
		_GameInput.read_select_step_x() if _options_open else 0,
		_GameInput.read_select_step()
	)
	var nav := _menu_hold_repeat.poll(delta, held)
	if nav == Vector2i.ZERO:
		return
	if base_menu_open:
		_move_main_menu_focus(nav.y)
	elif _load_open and _save_panel:
		_save_panel.nudge_cursor(nav.y)
	elif _options_open and _options_panel:
		if nav.x != 0:
			_options_panel.cycle_current(nav.x)
		else:
			_options_panel.nudge_cursor(nav.y)
	elif _licenses_open and _licenses_panel:
		_licenses_panel.scroll_by(float(nav.y) * 54.0)


func _mark_input_handled() -> void:
	## Loading a slot can detach this menu before _input returns.
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _GameInput.should_block_event(event):
		_mark_input_handled()
		return
	_note_menu_input_device(event)
	if _try_skip_intro(event):
		_mark_input_handled()
		return
	## Cancel/confirm on load/options list — use _input so Esc is not lost to GUI.
	if _load_open:
		if _handle_load_input(event):
			_mark_input_handled()
		return
	if _options_open:
		if _handle_options_input(event):
			_mark_input_handled()
		return
	if _licenses_open:
		if _handle_licenses_input(event):
			_mark_input_handled()
		return
	if _create_open:
		return
	if event is InputEventJoypadMotion:
		if (
			(event as InputEventJoypadMotion).axis == JOY_AXIS_LEFT_X
			or (event as InputEventJoypadMotion).axis == JOY_AXIS_LEFT_Y
		):
			_mark_input_handled()
			return
	if (
		_intro != null
		and _intro.mode == _IntroController.Mode.MENU
		and _GameInput.dir_from_event(event) != Vector2i.ZERO
	):
		## Focus movement is polled so keys, D-pad, and stick repeat identically.
		_mark_input_handled()
		return
	## Main Journey list: A / Enter activate the focused line (do not rely on
	## BaseButton ui_accept alone — gamepad often never fires pressed).
	if (
		_intro != null
		and _intro.mode == _IntroController.Mode.MENU
		and (
			_GameInput.is_select(event)
			or event.is_action_pressed("ui_accept")
			or event.is_action_pressed("confirm")
		)
		and _activate_focused_menu_button()
	):
		_mark_input_handled()


func _activate_focused_menu_button() -> bool:
	var fo := get_viewport().gui_get_focus_owner()
	if fo == null or not (fo is BaseButton):
		return false
	var btn := fo as BaseButton
	if not btn.visible or btn.disabled:
		return false
	## Only our Journey-frame lines — ignore stray focus elsewhere.
	if btn not in [_btn_return, _btn_journey, _btn_new, _btn_options, _btn_licenses, _btn_quit]:
		return false
	btn.pressed.emit()
	return true


func _move_main_menu_focus(step: int) -> void:
	var chain: Array[Button] = [
		_btn_return, _btn_journey, _btn_new, _btn_options, _btn_licenses, _btn_quit
	]
	var current := get_viewport().gui_get_focus_owner()
	var index := chain.find(current)
	if index < 0:
		index = chain.find(_btn_journey)
	var next := clampi(index + signi(step), 0, chain.size() - 1)
	chain[next].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _GameInput.should_block_event(event):
		get_viewport().set_input_as_handled()
		return
	_note_menu_input_device(event)
	if _load_open or _options_open or _licenses_open:
		## Already handled in _input when active.
		return
	if _create_open:
		## Name/gender form owns Esc / accept; mute menu hotkeys.
		return

	if _try_skip_intro(event):
		accept_event()
		return

	var pressed_key: bool = event is InputEventKey and event.pressed and not event.echo
	if pressed_key:
		var k := event as InputEventKey
		var code := k.keycode
		var phys := k.physical_keycode
		if code == KEY_R or phys == KEY_R:
			_on_return_view()
			accept_event()
		elif code == KEY_J or phys == KEY_J:
			_on_journey()
			accept_event()
		elif code == KEY_I or phys == KEY_I:
			_on_new()
			accept_event()
		elif code == KEY_O or phys == KEY_O:
			_on_options()
			accept_event()
		elif code == KEY_A or phys == KEY_A:
			_on_licenses()
			accept_event()
		elif code == KEY_Q or phys == KEY_Q:
			get_tree().quit()
			accept_event()


func _try_skip_intro(event: InputEvent) -> bool:
	if _intro == null:
		return false
	if (
		_intro.mode != _IntroController.Mode.TITLES
		and _intro.mode != _IntroController.Mode.MAP
	):
		return false
	if not event.is_pressed() or event.is_echo():
		return false
	var key_ok := event is InputEventKey
	var click_ok := (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	)
	var joy_ok := (
		event is InputEventJoypadButton
		and (event as InputEventJoypadButton).button_index in [
			JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START
		]
	)
	if not (key_ok or click_ok or joy_ok):
		return false
	_intro.skip_titles_or_advance()
	return true


func _note_menu_input_device(event: InputEvent) -> void:
	## Korean labels: letter prefixes appear with keyboard, hide with gamepad.
	var want := _menu_hotkeys_visible
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		want = true
	elif event is InputEventJoypadButton and event.is_pressed():
		want = false
	elif event is InputEventJoypadMotion:
		var stick := _GameInput.stick_direction_step(event)
		if stick != Vector2i.ZERO:
			want = false
	if want == _menu_hotkeys_visible:
		return
	_menu_hotkeys_visible = want
	if GameState.language == "ko":
		_refresh_menu_button_labels()


func _menu_line(letter: String, key: String) -> String:
	var label := Locale.t(key)
	if GameState.language != "ko" or not _menu_hotkeys_visible or letter.is_empty():
		return label
	return "%s) %s" % [letter, label]


func _refresh_menu_button_labels() -> void:
	_btn_return.text = _menu_line("R", "menu_return")
	_btn_journey.text = _menu_line("J", "menu_journey")
	_btn_new.text = _menu_line("I", "menu_new")
	_btn_options.text = _menu_line("O", "esc_options_title")
	_btn_licenses.text = _menu_line("A", "menu_licenses")
	_btn_quit.text = _menu_line("Q", "menu_quit")


func _refresh_text() -> void:
	_tagline.text = Locale.t("menu_tagline")
	_options_head.text = Locale.t("menu_options")
	_refresh_menu_button_labels()
	_copyright.text = "%s  ·  %s\n%s" % [
		Locale.t("menu_copyright"),
		Locale.t("menu_version", [APP_DISPLAY_VERSION]),
		Locale.t("menu_fan_notice"),
	]
	_hint.text = Locale.t("input_hint_menu") + " · R/J/I/O/A · ⌘F"
	if _save_panel and _save_panel.is_open():
		_save_panel.refresh()
	if _options_panel and _options_panel.is_open():
		_options_panel.refresh()
	if _licenses_panel and _licenses_panel.is_open():
		_licenses_panel.refresh()
	if _name_form and _create_open and _name_form.has_method("refresh_labels"):
		_name_form.refresh_labels()


func _on_tileset_changed(_tileset_id: String) -> void:
	PartyRoster.clear_class_tile_cache()
	if _intro != null and _intro.has_method("reload_tileset_graphics"):
		_intro.reload_tileset_graphics()
	if _save_panel != null and _save_panel.has_method("reload_class_tiles"):
		_save_panel.reload_class_tiles()
	if _options_panel != null and _options_panel.is_open():
		_options_panel.refresh()


func _on_return_view() -> void:
	if _load_open or _create_open or _options_open or _licenses_open:
		return
	if _intro:
		_intro.return_to_map()
	else:
		_btn_return.grab_focus()


func _on_journey() -> void:
	if _create_open or _options_open or _licenses_open:
		return
	if not _SaveGame.any_slot_exists():
		## Frame-area banner when no slots (hint label is normally hidden).
		_tagline.text = Locale.t("load_none")
		_btn_journey.grab_focus()
		return
	_ensure_save_panel()
	_load_open = true
	_menu_hold_repeat.reset()
	## Clear Journey menu chrome; show load list in the same frame box.
	_text_block.visible = false
	_hint.visible = false
	var fo := get_viewport().gui_get_focus_owner()
	if fo:
		fo.release_focus()
	var panel_rect := _frame_content_rect()
	if panel_rect.size.x > 40.0 and panel_rect.size.y > 40.0 and _save_panel.has_method("open_embedded"):
		_save_panel.open_embedded(
			_SaveSlotPanel.Mode.LOAD,
			panel_rect,
			_SaveGame.default_load_cursor()
		)
	else:
		_save_panel.open_panel(
			_SaveSlotPanel.Mode.LOAD,
			_SaveGame.default_load_cursor()
		)


func _on_new() -> void:
	if _licenses_open:
		_close_licenses()
	if _options_open:
		_close_options()
	if _load_open:
		_close_load()
	GameState.reset_party()
	_open_name_form()


func _on_options() -> void:
	if _load_open or _create_open or _licenses_open:
		return
	if _options_open:
		return
	_ensure_options_panel()
	_options_open = true
	_menu_hold_repeat.reset()
	_text_block.visible = false
	_hint.visible = false
	var fo := get_viewport().gui_get_focus_owner()
	if fo:
		fo.release_focus()
	var panel_rect := _frame_content_rect()
	if panel_rect.size.x > 40.0 and panel_rect.size.y > 40.0:
		_options_panel.open_embedded(panel_rect, 0)
	else:
		_options_panel.open_panel(0)


func _on_licenses() -> void:
	if _load_open or _create_open or _options_open or _licenses_open:
		return
	_ensure_licenses_panel()
	_licenses_open = true
	_menu_hold_repeat.reset()
	_text_block.visible = false
	_hint.visible = false
	var fo := get_viewport().gui_get_focus_owner()
	if fo:
		fo.release_focus()
	var panel_rect := _frame_content_rect()
	if panel_rect.size.x > 40.0 and panel_rect.size.y > 40.0:
		_licenses_panel.open_embedded(panel_rect)
	else:
		_licenses_panel.open_panel()


func _ensure_options_panel() -> void:
	if _options_panel != null:
		return
	_options_panel = _OptionsPanel.new()
	_options_panel.name = "OptionsPanel"
	add_child(_options_panel)


func _ensure_licenses_panel() -> void:
	if _licenses_panel != null:
		return
	_licenses_panel = _LicensesPanel.new()
	_licenses_panel.name = "LicensesPanel"
	_licenses_panel.closed.connect(_on_licenses_panel_closed)
	add_child(_licenses_panel)


func _ensure_save_panel() -> void:
	if _save_panel != null:
		return
	_save_panel = _SaveSlotPanel.new()
	_save_panel.name = "SaveSlotPanel"
	if _save_panel.has_signal("slot_activated"):
		_save_panel.slot_activated.connect(_on_save_slot_activated)
	add_child(_save_panel)


func _on_save_slot_activated(slot_index: int) -> void:
	if _load_open:
		_confirm_load(slot_index)


func _open_name_form() -> void:
	_create_open = true
	_text_block.visible = false
	_hint.visible = false
	var fo := get_viewport().gui_get_focus_owner()
	if fo:
		fo.release_focus()
	if _name_form == null or not is_instance_valid(_name_form):
		_name_form = _NAME_GENDER_SCN.instantiate()
		_name_form.name = "NameGenderEmbed"
		_name_form.set("prepare_embedded", true)
		if _name_form.has_signal("cancelled"):
			_name_form.cancelled.connect(_close_name_form)
		add_child(_name_form)
	var panel_rect := _frame_content_rect()
	if panel_rect.size.x < 40.0:
		## Intro frame unavailable — fall back to dedicated scene.
		_create_open = false
		SceneRouter.to_new_game()
		return
	if _name_form.has_method("begin_embedded"):
		_name_form.begin_embedded(panel_rect)
	else:
		_create_open = false
		SceneRouter.to_new_game()


func _close_name_form() -> void:
	_create_open = false
	if _name_form and _name_form.has_method("close_embedded"):
		_name_form.close_embedded()
	elif _name_form:
		_name_form.visible = false
	if _intro != null and _intro.mode == _IntroController.Mode.MENU:
		_text_block.visible = true
		_hint.visible = false
		_layout_menu_in_frame()
		_refresh_text()
		_btn_new.grab_focus()
	else:
		_refresh_text()
		_btn_new.grab_focus()


func _handle_options_input(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		## Shared menu polling handles both axes and held-repeat.
		return true
	if not event.is_pressed() or event.is_echo():
		return false
	if _options_horizontal_nudge(event):
		return true
	if _GameInput.is_cancel(event) or _is_right_click(event):
		if _options_panel != null and _options_panel.has_method("is_picking_file") and _options_panel.is_picking_file():
			return true
		_close_options()
		return true
	if _GameInput.is_select(event) or event.is_action_pressed("confirm") or event.is_action_pressed("ui_accept"):
		if _options_panel:
			_options_panel.cycle_current(1)
		return true
	if event is InputEventKey or event is InputEventJoypadButton:
		## Swallow other keys so menu R/J/I/O/A don't fire under options.
		return true
	return false


func _options_horizontal_nudge(event: InputEvent) -> bool:
	var d: Vector2i = _GameInput.dir_from_event(event)
	return d.x != 0


func _close_options() -> void:
	_options_open = false
	_menu_hold_repeat.reset()
	if _options_panel:
		_options_panel.close_panel()
	if _intro != null and _intro.mode == _IntroController.Mode.MENU:
		_text_block.visible = true
		_hint.visible = false
		_layout_menu_in_frame()
		_refresh_text()
		_btn_options.grab_focus()
	else:
		_refresh_text()
		_btn_options.grab_focus()


func _handle_licenses_input(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if _GameInput.is_cancel(event) or _is_right_click(event):
		_close_licenses()
		return true
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_PAGEUP or k.physical_keycode == KEY_PAGEUP:
			_licenses_panel.scroll_by(-280.0)
			return true
		if k.keycode == KEY_PAGEDOWN or k.physical_keycode == KEY_PAGEDOWN:
			_licenses_panel.scroll_by(280.0)
			return true
		if k.keycode == KEY_HOME or k.physical_keycode == KEY_HOME:
			_licenses_panel.scroll_by(-100000.0)
			return true
		if k.keycode == KEY_END or k.physical_keycode == KEY_END:
			_licenses_panel.scroll_by(100000.0)
			return true
		return true
	if event is InputEventJoypadButton:
		return true
	return false


func _close_licenses() -> void:
	if _licenses_panel:
		_licenses_panel.close_panel()
	else:
		_on_licenses_panel_closed()


func _on_licenses_panel_closed() -> void:
	_licenses_open = false
	_menu_hold_repeat.reset()
	if _intro != null and _intro.mode == _IntroController.Mode.MENU:
		_text_block.visible = true
		_hint.visible = false
		_layout_menu_in_frame()
	_refresh_text()
	_btn_licenses.grab_focus()


func _handle_load_input(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if _GameInput.is_cancel(event) or _is_right_click(event):
		_close_load()
		return true
	if _GameInput.is_select(event):
		_confirm_load(_save_panel.cursor() if _save_panel else 0)
		return true
	if event is InputEventKey:
		var k := event as InputEventKey
		if _is_delete_save_key(k):
			_prompt_delete_load_slot()
			return true
		var dig := _digit_0_to_3(k)
		if dig >= 0:
			if _save_panel:
				_save_panel.set_cursor(dig)
			_confirm_load(dig)
			return true
		## Swallow other keys so menu R/J/I/O/A shortcuts don’t fire under the list.
		return true
	if event is InputEventJoypadButton:
		return true
	return false


func _is_right_click(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mb := event as InputEventMouseButton
	return mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT


func _is_delete_save_key(k: InputEventKey) -> bool:
	## Windows/Linux Del, or Mac keyboard Delete (often KEY_BACKSPACE).
	return (
		k.keycode == KEY_DELETE or k.physical_keycode == KEY_DELETE
		or k.keycode == KEY_BACKSPACE or k.physical_keycode == KEY_BACKSPACE
	)


func _prompt_delete_load_slot() -> void:
	if _save_panel == null or not _save_panel.is_open():
		return
	var slot_index: int = int(_save_panel.cursor())
	var slot_n: int = slot_index + 1
	if not _SaveGame.slot_exists(slot_n):
		return
	QuitConfirm.prompt_delete_save(func() -> void:
		if not _SaveGame.delete_slot(slot_n):
			return
		if not _SaveGame.any_slot_exists():
			_close_load()
			## _close_load refreshes Journey chrome — replace tagline after.
			_tagline.text = Locale.t("load_none")
			return
		if _load_open and _save_panel != null and is_instance_valid(_save_panel):
			_save_panel.refresh()
	)


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
		## Empty slot — stay on list; flash title if present.
		if _save_panel and _save_panel.is_open():
			_save_panel.refresh()
		return
	var data := _SaveGame.read_slot(slot_n)
	if data.is_empty():
		return
	var game: Variant = data.get("game", {})
	var world: Variant = data.get("world", {})
	if typeof(game) != TYPE_DICTIONARY:
		return
	GameState.apply_save_dict(game as Dictionary, _SaveGame.slot_version(data))
	GameState.pending_world_save = world if typeof(world) == TYPE_DICTIONARY else {}
	GameState.session_loaded_slot = slot_n
	GameState.session_did_save = false
	GameState.session_save_overwrite_ok = false
	GameState.is_new_game = false
	_SaveGame.set_last_loaded_slot(slot_n)
	_close_load()
	## Let the current input callback finish before replacing this menu scene.
	SceneRouter.call_deferred("to_world")


func _close_load() -> void:
	_load_open = false
	_menu_hold_repeat.reset()
	if _save_panel:
		_save_panel.close_panel()
	## Restore Journey menu inside the frame.
	if _intro != null and _intro.mode == _IntroController.Mode.MENU:
		_text_block.visible = true
		_hint.visible = false
		_layout_menu_in_frame()
		_refresh_text()
		_btn_journey.grab_focus()
	else:
		_refresh_text()
		_btn_journey.grab_focus()
