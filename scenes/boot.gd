extends Control

@onready var _status: Label = %Status
@onready var _brand: Label = %Brand
@onready var _vbox: VBoxContainer = %VBox

const RESULT_SEC := 0.35
const BODY_W := 620.0
const SECTION_GAP := 18.0
const START_GAP := 20.0

var _dos_lab: Label
var _apple2_lab: Label
var _choose_btn: Button
var _apple2_choose_btn: Button
var _continue_btn: Button
var _file_dialog: FileDialog
var _apple2_dialog: FileDialog
var _waiting_quit_key := false
var _picking_folder := false
var _picking_apple2 := false
var _setup_open := false


func _ready() -> void:
	UiTheme.apply_root(self)
	## Data-path setup is a choice screen (folder/disk pickers, Continue).
	UiTheme.set_menu_cursor(true)
	$ColorRect.color = UiTheme.BG
	UiTheme.style_label(_brand, 42, UiTheme.ACCENT)
	UiTheme.style_label(_status, 18, UiTheme.MUTED)
	_brand.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brand.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_status.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_brand.text = Locale.t("app_title")

	if GameState.u4_data_ok and GameState.u4_data_pref_set and GameState.apple2_dsk_prompted:
		SceneRouter.to_menu.call_deferred()
		return

	_show_setup()


func _show_setup() -> void:
	_setup_open = true
	_status.custom_minimum_size = Vector2(BODY_W, 0)
	_status.add_theme_color_override("font_color", UiTheme.MUTED)
	_status.text = Locale.t("boot_setup_intro")
	_ensure_folder_ui()
	_ensure_apple2_ui()
	_refresh_setup_copy()


func _refresh_setup_copy() -> void:
	if _dos_lab:
		if GameState.u4_data_ok:
			_dos_lab.add_theme_color_override("font_color", UiTheme.ACCENT)
			_dos_lab.text = Locale.t("boot_path_ready")
		elif GameState.u4_data_needs_macos_permission:
			_dos_lab.add_theme_color_override("font_color", UiTheme.DANGER)
			_dos_lab.text = Locale.t("boot_path_macos_permission")
		elif GameState.u4_data_pref_set:
			_dos_lab.add_theme_color_override("font_color", UiTheme.DANGER)
			_dos_lab.text = Locale.t("boot_path_reselect")
		else:
			_dos_lab.add_theme_color_override("font_color", UiTheme.MUTED)
			_dos_lab.text = Locale.t("boot_path_prompt")

	if _apple2_lab:
		if GameState.apple2_dsk_ok:
			_apple2_lab.add_theme_color_override("font_color", UiTheme.ACCENT)
			_apple2_lab.text = Locale.t("boot_apple2_ready")
		elif GameState.apple2_dsk_needs_macos_permission:
			_apple2_lab.add_theme_color_override("font_color", UiTheme.DANGER)
			_apple2_lab.text = Locale.t("boot_apple2_prompt") + "\n" + Locale.t("boot_path_macos_permission")
		else:
			_apple2_lab.add_theme_color_override("font_color", UiTheme.MUTED)
			_apple2_lab.text = Locale.t("boot_apple2_prompt") + "\n" + Locale.t("boot_apple2_hint")

	if _continue_btn:
		_continue_btn.visible = true
		_continue_btn.disabled = not GameState.u4_data_ok
		_continue_btn.modulate = Color.WHITE if GameState.u4_data_ok else Color(1, 1, 1, 0.45)


func _style_body(lab: Label) -> void:
	UiTheme.style_label(lab, 16, UiTheme.MUTED)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lab.custom_minimum_size = Vector2(BODY_W, 0)


func _add_gap(height: float) -> void:
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size = Vector2(0, height)
	_vbox.add_child(gap)


func _ensure_folder_ui() -> void:
	if _dos_lab == null:
		_dos_lab = Label.new()
		_style_body(_dos_lab)
		_vbox.add_child(_dos_lab)

	if _choose_btn == null:
		_choose_btn = Button.new()
		_choose_btn.text = Locale.t("boot_path_choose")
		UiTheme.style_button(_choose_btn)
		_choose_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_choose_btn.pressed.connect(_open_folder_dialog)
		_vbox.add_child(_choose_btn)
		_add_gap(SECTION_GAP)

	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.use_native_dialog = _use_native_folder_dialog()
		_file_dialog.title = Locale.t("boot_path_prompt")
		_file_dialog.ok_button_text = Locale.t("boot_path_select")
		_file_dialog.cancel_button_text = Locale.t("boot_path_cancel")
		_file_dialog.min_size = Vector2i(760, 480)
		_file_dialog.exclusive = true
		_file_dialog.unresizable = false
		_file_dialog.dir_selected.connect(_on_dir_selected)
		_file_dialog.canceled.connect(_on_folder_canceled)
		add_child(_file_dialog)

	_dos_lab.visible = true
	_choose_btn.visible = true


func _ensure_apple2_ui() -> void:
	if _apple2_lab == null:
		_apple2_lab = Label.new()
		_style_body(_apple2_lab)
		_vbox.add_child(_apple2_lab)

	if _apple2_choose_btn == null:
		_apple2_choose_btn = Button.new()
		_apple2_choose_btn.text = Locale.t("boot_apple2_choose")
		UiTheme.style_button(_apple2_choose_btn)
		_apple2_choose_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_apple2_choose_btn.pressed.connect(_open_apple2_dialog)
		_vbox.add_child(_apple2_choose_btn)
		_add_gap(START_GAP)

	if _continue_btn == null:
		_continue_btn = Button.new()
		_continue_btn.text = Locale.t("boot_continue")
		UiTheme.style_button(_continue_btn)
		_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_continue_btn.pressed.connect(_continue_to_menu)
		_vbox.add_child(_continue_btn)

	if _apple2_dialog == null:
		_apple2_dialog = FileDialog.new()
		_apple2_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_apple2_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_apple2_dialog.use_native_dialog = _use_native_folder_dialog()
		_apple2_dialog.title = Locale.t("boot_apple2_prompt")
		_apple2_dialog.ok_button_text = Locale.t("boot_apple2_select")
		_apple2_dialog.cancel_button_text = Locale.t("boot_path_cancel")
		_apple2_dialog.min_size = Vector2i(760, 480)
		_apple2_dialog.exclusive = true
		_apple2_dialog.unresizable = false
		_apple2_dialog.add_filter("*.dsk", "Apple II disk")
		_apple2_dialog.file_selected.connect(_on_apple2_file_selected)
		_apple2_dialog.canceled.connect(_on_apple2_canceled)
		add_child(_apple2_dialog)

	_apple2_lab.visible = true
	_apple2_choose_btn.visible = true
	_continue_btn.visible = true


func _use_native_folder_dialog() -> bool:
	if OS.get_name() != "macOS":
		return false
	return OS.is_sandboxed() or not OS.has_feature("editor")


func _open_folder_dialog() -> void:
	if _file_dialog == null:
		return
	_picking_folder = true
	var start := GameState.u4_data_path
	if start.begins_with("res://") or start.is_empty() or not DirAccess.dir_exists_absolute(start):
		start = ""
		if OS.get_name() == "Windows":
			for gog in GameState._windows_gog_u4_dirs():
				if DirAccess.dir_exists_absolute(gog):
					start = gog
					break
			if start.is_empty() and DirAccess.dir_exists_absolute("C:/GOG Games"):
				start = "C:/GOG Games"
		elif OS.get_name() == "macOS":
			for gog in GameState._macos_gog_u4_dirs():
				var app := gog.path_join("..").path_join("..").path_join("..").simplify_path()
				if DirAccess.dir_exists_absolute(app):
					start = app
					break
			if start.is_empty() and DirAccess.dir_exists_absolute("/Applications"):
				start = "/Applications"
		if start.is_empty():
			start = OS.get_environment("HOME")
		if start.is_empty():
			start = OS.get_environment("USERPROFILE")
	if not start.is_empty() and not _file_dialog.use_native_dialog:
		_file_dialog.current_dir = start
	_file_dialog.popup_centered_ratio(0.65)


func _open_apple2_dialog() -> void:
	if _apple2_dialog == null:
		_ensure_apple2_ui()
	_picking_apple2 = true
	var start := GameState.apple2_picker_start_dir()
	if not start.is_empty() and not _apple2_dialog.use_native_dialog:
		_apple2_dialog.current_dir = start
	_apple2_dialog.popup_centered_ratio(0.65)


func _on_dir_selected(dir: String) -> void:
	_picking_folder = false
	if GameState.try_set_u4_data_path(dir):
		GameState.u4_data_needs_macos_permission = false
		_refresh_setup_copy()
		return
	if _dos_lab:
		_dos_lab.add_theme_color_override("font_color", UiTheme.DANGER)
		_dos_lab.text = Locale.t("boot_path_invalid") + "\n" + Locale.t("boot_path_hint")
	if _continue_btn:
		_continue_btn.disabled = true
		_continue_btn.modulate = Color(1, 1, 1, 0.45)


func _on_apple2_file_selected(path: String) -> void:
	_picking_apple2 = false
	if _apple2_lab:
		_apple2_lab.add_theme_color_override("font_color", UiTheme.MUTED)
		_apple2_lab.text = Locale.t("boot_apple2_building")
	await get_tree().process_frame
	if GameState.try_set_apple2_dsk_path(path):
		_refresh_setup_copy()
		return
	if _apple2_lab:
		_apple2_lab.add_theme_color_override("font_color", UiTheme.DANGER)
		_apple2_lab.text = Locale.t("boot_apple2_invalid") + "\n" + Locale.t("boot_apple2_hint")


func _on_apple2_canceled() -> void:
	if not _picking_apple2:
		return
	_picking_apple2 = false


func _continue_to_menu() -> void:
	if not GameState.u4_data_ok:
		return
	GameState.skip_apple2_dsk_prompt()
	_setup_open = false
	_status.text = Locale.t("boot_ok")
	_status.add_theme_color_override("font_color", UiTheme.ACCENT)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.custom_minimum_size = Vector2.ZERO
	if _dos_lab:
		_dos_lab.visible = false
	if _apple2_lab:
		_apple2_lab.visible = false
	if _choose_btn:
		_choose_btn.visible = false
	if _apple2_choose_btn:
		_apple2_choose_btn.visible = false
	if _continue_btn:
		_continue_btn.visible = false
	await get_tree().create_timer(RESULT_SEC).timeout
	SceneRouter.to_menu()


func _on_folder_canceled() -> void:
	if not _picking_folder:
		return
	_picking_folder = false


func _show_required_and_quit() -> void:
	_setup_open = false
	if _dos_lab:
		_dos_lab.visible = false
	if _apple2_lab:
		_apple2_lab.visible = false
	if _choose_btn:
		_choose_btn.visible = false
	if _apple2_choose_btn:
		_apple2_choose_btn.visible = false
	if _continue_btn:
		_continue_btn.visible = false
	_status.text = Locale.t("boot_required")
	_status.add_theme_color_override("font_color", UiTheme.DANGER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(520, 0)
	_waiting_quit_key = true


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_quit_key:
		if event is InputEventKey and event.pressed and not event.echo:
			get_tree().quit()
			return
		if event is InputEventMouseButton and event.pressed:
			get_tree().quit()
			return
		if event is InputEventJoypadButton and event.pressed:
			get_tree().quit()
		return

	if not _setup_open or _picking_folder or _picking_apple2:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		if GameState.u4_data_ok:
			_continue_to_menu()
		else:
			_show_required_and_quit()
