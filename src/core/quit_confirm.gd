extends Node

## Intercept OS quit (macOS ⌘Q, Windows Alt+F4, window close) and ask Yes/No.
## Also used by the Esc menu for Quit / Return to Menu.

const LAYER_Z := 128

enum Kind {
	QUIT = 0,
	RETURN_MENU = 1,
	DELETE_SAVE = 2,
}

var _layer: CanvasLayer
var _root: Control
var _title: Label
var _btn_yes: Button
var _btn_no: Button
var _open := false
var _kind: int = Kind.QUIT
var _prev_focus: Control
var _on_yes: Callable = Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	_build()
	GameState.language_changed.connect(func(_l: String) -> void: _refresh_text())
	_refresh_text()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		prompt(Kind.QUIT)


func is_open() -> bool:
	return _open


func prompt(kind: int = Kind.QUIT) -> void:
	## Show (or retarget) confirmation. Safe while already open.
	_kind = kind
	if kind != Kind.DELETE_SAVE:
		_on_yes = Callable()
	if _open:
		_refresh_text()
		_btn_no.grab_focus()
		_sync_choice_style()
		return
	_open = true
	_prev_focus = get_viewport().gui_get_focus_owner() as Control
	## Stop world polling (Input.is_*_pressed) so arrows only move Yes/No.
	get_tree().paused = true
	_refresh_text()
	_root.visible = true
	_layer.visible = true
	_btn_no.grab_focus()
	_sync_choice_style()


func prompt_delete_save(on_yes: Callable) -> void:
	## Load-list Del/Backspace: Yes runs `on_yes` after the dialog closes.
	_on_yes = on_yes
	prompt(Kind.DELETE_SAVE)


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER_Z
	_layer.visible = false
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.make_panel())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(380, 0)
	UiTheme.style_label(_title, 18, UiTheme.TEXT)
	col.add_child(_title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)

	_btn_yes = Button.new()
	_btn_no = Button.new()
	for btn in [_btn_yes, _btn_no]:
		btn.custom_minimum_size = Vector2(100, 0)
		UiTheme.style_button(btn)
		btn.focus_mode = Control.FOCUS_ALL
		row.add_child(btn)

	_btn_yes.focus_neighbor_left = _btn_yes.get_path_to(_btn_no)
	_btn_yes.focus_neighbor_right = _btn_yes.get_path_to(_btn_no)
	_btn_no.focus_neighbor_left = _btn_no.get_path_to(_btn_yes)
	_btn_no.focus_neighbor_right = _btn_no.get_path_to(_btn_yes)

	_btn_yes.pressed.connect(_accept)
	_btn_no.pressed.connect(_cancel)
	_btn_yes.focus_entered.connect(_sync_choice_style)
	_btn_no.focus_entered.connect(_sync_choice_style)


func _refresh_text() -> void:
	if _title == null:
		return
	match _kind:
		Kind.RETURN_MENU:
			_title.text = Locale.t("return_menu_confirm")
		Kind.DELETE_SAVE:
			_title.text = Locale.t("load_delete_confirm")
		_:
			_title.text = Locale.t("quit_confirm")
	_btn_yes.text = Locale.t("cmd_yes")
	_btn_no.text = Locale.t("cmd_no")


func _sync_choice_style() -> void:
	var yes_on := get_viewport().gui_get_focus_owner() == _btn_yes
	UiTheme.style_choice_button(_btn_yes, yes_on)
	UiTheme.style_choice_button(_btn_no, not yes_on)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
		_cancel()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("choice_a"):
		_btn_yes.grab_focus()
		_sync_choice_style()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("choice_b"):
		_btn_no.grab_focus()
		_sync_choice_style()
		get_viewport().set_input_as_handled()
		return
	## Y / N confirm immediately (physical so layout doesn't matter).
	if event is InputEventKey and event.pressed and not event.echo:
		var code: Key = event.physical_keycode
		if code == KEY_NONE:
			code = event.keycode
		if code == KEY_Y:
			_accept()
			get_viewport().set_input_as_handled()
			return
		if code == KEY_N:
			_cancel()
			get_viewport().set_input_as_handled()
			return
	## Arrows / stick: move between Yes and No (don't rely on default ui_* only).
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left") \
			or event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		if get_viewport().gui_get_focus_owner() == _btn_yes:
			_btn_no.grab_focus()
		else:
			_btn_yes.grab_focus()
		_sync_choice_style()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("confirm"):
		## Space is bound to confirm — treat focused choice as the answer.
		if get_viewport().gui_get_focus_owner() == _btn_yes:
			_accept()
		else:
			_cancel()
		get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	## After GUI focus nav, swallow leftover keys so the game never sees them.
	if not _open:
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()


func _accept() -> void:
	if not _open:
		return
	var kind := _kind
	var on_yes := _on_yes
	_dismiss_ui(false)
	match kind:
		Kind.RETURN_MENU:
			SceneRouter.to_menu()
		Kind.DELETE_SAVE:
			if on_yes.is_valid():
				on_yes.call()
		_:
			get_tree().quit()


func _cancel() -> void:
	if not _open:
		return
	_dismiss_ui(true)


func _dismiss_ui(restore_focus: bool) -> void:
	_open = false
	get_tree().paused = false
	_root.visible = false
	_layer.visible = false
	if restore_focus and is_instance_valid(_prev_focus):
		_prev_focus.grab_focus()
	_prev_focus = null
	_kind = Kind.QUIT
	_on_yes = Callable()
