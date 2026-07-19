class_name UiTheme
extends RefCounted

## Compact Ultima-flavored palette — deep teal night, amber accent (not purple/cream defaults).

const BG := Color("0b1c24")
const BG_PANEL := Color("122a33")
const BORDER := Color("3d6b5a")
const TEXT := Color("e8f0e9")
const MUTED := Color("8aa39a")
const ACCENT := Color("d4a84b")
const ACCENT_DIM := Color("8a6a2e")
const DANGER := Color("c45c4a")


static func apply_root(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func make_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_PANEL
	sb.border_color = BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb


static func make_button_normal() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1a3842")
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func make_button_hover() -> StyleBoxFlat:
	var sb := make_button_normal()
	sb.bg_color = Color("244852")
	sb.border_color = ACCENT
	return sb


static func make_button_focus() -> StyleBoxFlat:
	var sb := make_button_hover()
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = ACCENT
	return sb


static func make_button_selected() -> StyleBoxFlat:
	var sb := make_button_normal()
	sb.bg_color = Color("2a4a38")
	sb.border_color = ACCENT
	sb.set_border_width_all(2)
	return sb


static func style_button(btn: Button) -> void:
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.add_theme_stylebox_override("normal", make_button_normal())
	btn.add_theme_stylebox_override("hover", make_button_hover())
	btn.add_theme_stylebox_override("pressed", make_button_selected())
	btn.add_theme_stylebox_override("focus", make_button_focus())
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", ACCENT)
	btn.add_theme_color_override("font_focus_color", ACCENT)
	btn.add_theme_color_override("font_pressed_color", ACCENT)
	btn.add_theme_font_size_override("font_size", 18)


static func style_choice_button(btn: Button, selected: bool) -> void:
	style_button(btn)
	if selected:
		btn.add_theme_stylebox_override("normal", make_button_selected())
		btn.add_theme_color_override("font_color", ACCENT)



static func style_label(label: Label, size: int = 18, color: Color = TEXT) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
