extends Control

@onready var _status: Label = %Status
@onready var _brand: Label = %Brand
@onready var _vbox: VBoxContainer = %VBox

## Only used when we need a visible "found / missing" beat — not on warm starts.
const RESULT_SEC := 0.35

var _choose_btn: Button
var _file_dialog: FileDialog
var _waiting_quit_key := false
var _picking_folder := false


func _ready() -> void:
	UiTheme.apply_root(self)
	$ColorRect.color = UiTheme.BG
	UiTheme.style_label(_brand, 42, UiTheme.ACCENT)
	UiTheme.style_label(_status, 18, UiTheme.MUTED)
	## style_label enables word-wrap; in a centered VBox that collapses
	## width to ~1 glyph and stacks the title vertically.
	_brand.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brand.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_status.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_brand.text = Locale.t("app_title")

	## Path probe already ran in GameState._ready — no theatrical "searching" wait.
	if GameState.u4_data_ok:
		## Warm start (path already in settings): skip splash delays entirely.
		if GameState.u4_data_pref_set:
			## Deferred — change_scene during _ready can fail (parent busy).
			SceneRouter.to_menu.call_deferred()
			return
		## First-time auto-discover: brief OK flash, then menu.
		_status.text = Locale.t("boot_ok")
		_status.add_theme_color_override("font_color", UiTheme.ACCENT)
		await get_tree().create_timer(RESULT_SEC).timeout
		SceneRouter.to_menu()
		return

	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(560, 0)
	_status.add_theme_color_override("font_color", UiTheme.DANGER)
	if GameState.u4_data_pref_set:
		_status.text = Locale.t("boot_path_reselect")
	else:
		_status.text = Locale.t("boot_path_prompt")

	_ensure_folder_ui()
	## After the window finishes its first layout — popup during _ready can be 0-size.
	call_deferred("_open_folder_dialog")


func _proceed_ok() -> void:
	_status.text = Locale.t("boot_ok")
	_status.add_theme_color_override("font_color", UiTheme.ACCENT)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.custom_minimum_size = Vector2.ZERO
	if _choose_btn:
		_choose_btn.visible = false
	await get_tree().create_timer(RESULT_SEC).timeout
	SceneRouter.to_menu()


func _ensure_folder_ui() -> void:
	if _choose_btn == null:
		_choose_btn = Button.new()
		_choose_btn.text = Locale.t("boot_path_choose")
		UiTheme.style_button(_choose_btn)
		_choose_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_choose_btn.pressed.connect(_open_folder_dialog)
		_vbox.add_child(_choose_btn)

	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		## Exported macOS native panels often fail silently (not TCC). In-game picker.
		_file_dialog.use_native_dialog = false
		_file_dialog.title = Locale.t("boot_path_prompt")
		_file_dialog.ok_button_text = Locale.t("boot_path_select")
		_file_dialog.cancel_button_text = Locale.t("boot_path_cancel")
		_file_dialog.min_size = Vector2i(760, 480)
		_file_dialog.exclusive = true
		_file_dialog.unresizable = false
		_file_dialog.dir_selected.connect(_on_dir_selected)
		_file_dialog.canceled.connect(_on_folder_canceled)
		add_child(_file_dialog)

	_choose_btn.visible = true


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
		if start.is_empty():
			start = OS.get_environment("HOME")
		if start.is_empty():
			start = OS.get_environment("USERPROFILE")
	if not start.is_empty():
		_file_dialog.current_dir = start
	_file_dialog.popup_centered_ratio(0.65)


func _on_dir_selected(dir: String) -> void:
	_picking_folder = false
	if GameState.try_set_u4_data_path(dir):
		await _proceed_ok()
		return
	## Wrong / empty folder — ask again via the folder picker.
	_status.text = Locale.t("boot_path_invalid") + "\n" + Locale.t("boot_path_hint")
	_status.add_theme_color_override("font_color", UiTheme.DANGER)
	if _choose_btn:
		_choose_btn.visible = true


func _on_folder_canceled() -> void:
	## Folder dialog closed without a selection.
	if not _picking_folder:
		return
	_picking_folder = false
	_show_required_and_quit()


func _show_required_and_quit() -> void:
	if _choose_btn:
		_choose_btn.visible = false
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

	## Esc while waiting on the choose-folder button → quit path.
	if _choose_btn != null and _choose_btn.visible and not _picking_folder:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
			get_viewport().set_input_as_handled()
			_show_required_and_quit()
