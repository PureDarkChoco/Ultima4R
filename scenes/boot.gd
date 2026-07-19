extends Control

@onready var _status: Label = %Status
@onready var _brand: Label = %Brand


func _ready() -> void:
	UiTheme.apply_root(self)
	$ColorRect.color = UiTheme.BG
	UiTheme.style_label(_brand, 42, UiTheme.ACCENT)
	UiTheme.style_label(_status, 18, UiTheme.MUTED)
	_brand.text = Locale.t("app_title")
	_status.text = Locale.t("boot_checking")

	await get_tree().create_timer(0.6).timeout

	if GameState.u4_data_ok:
		_status.text = Locale.t("boot_ok")
		_status.add_theme_color_override("font_color", UiTheme.ACCENT)
	else:
		_status.text = Locale.t("boot_missing")
		_status.add_theme_color_override("font_color", UiTheme.DANGER)

	await get_tree().create_timer(0.8).timeout
	SceneRouter.to_menu()
