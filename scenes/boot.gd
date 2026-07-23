extends Control

@onready var _status: Label = %Status
@onready var _brand: Label = %Brand

const CHECK_SEC := 1.4
const RESULT_SEC := 2.2


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
	_status.text = Locale.t("boot_checking")

	await get_tree().create_timer(CHECK_SEC).timeout

	if GameState.u4_data_ok:
		_status.text = Locale.t("boot_ok")
		_status.add_theme_color_override("font_color", UiTheme.ACCENT)
	else:
		_status.text = Locale.t("boot_missing")
		_status.add_theme_color_override("font_color", UiTheme.DANGER)

	await get_tree().create_timer(RESULT_SEC).timeout
	SceneRouter.to_menu()
