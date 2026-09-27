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
## Keyboard/command focus on a side panel or the Peer gem map.
const FOCUS_BORDER := Color("f2d43d")
## Selected choice (not keyboard focus) — cool blue so it differs from ACCENT focus.
const SELECT := Color("4aa3d4")
const DANGER := Color("c45c4a")

const FONT_PATH := "res://assets/fonts/d2coding/D2Coding.ttf"
const FONT_BOLD_PATH := "res://assets/fonts/d2coding/D2CodingBold.ttf"
## Custom mouse cursors: ankh (non-menu pages / background loading)
## + sword (menu selection — shown regardless of pointer position).
## Both bitmaps are native 32x32 pixel art.
const CURSOR_ANKH_PATH := "res://assets/ui/cursors/cursor_ankh.png"
const CURSOR_SWORD_PATH := "res://assets/ui/cursors/cursor_sword.png"
const CURSOR_ARROW_UP_PATH := "res://assets/ui/cursors/arrow_up.png"
const CURSOR_ARROW_DOWN_PATH := "res://assets/ui/cursors/arrow_down.png"
const CURSOR_ARROW_LEFT_PATH := "res://assets/ui/cursors/arrow_left.png"
const CURSOR_ARROW_RIGHT_PATH := "res://assets/ui/cursors/arrow_right.png"
const CURSOR_BUBBLE_PATH := "res://assets/ui/cursors/cursor_bubble.png"
const CURSOR_KEY_PATH := "res://assets/ui/cursors/cursor_key.png"
const CURSOR_HAND_PATH := "res://assets/ui/cursors/cursor_hand.png"
const CURSOR_SEARCH_PATH := "res://assets/ui/cursors/cursor_search.png"
const CURSOR_ANKH_HOTSPOT := Vector2(16, 1)
const CURSOR_SWORD_HOTSPOT := Vector2(4, 0)
const CURSOR_ARROW_UP_HOTSPOT := Vector2(16, 1)
const CURSOR_ARROW_DOWN_HOTSPOT := Vector2(16, 31)
const CURSOR_ARROW_LEFT_HOTSPOT := Vector2(1, 16)
const CURSOR_ARROW_RIGHT_HOTSPOT := Vector2(31, 16)
## Tail sits at the lower-left of the 32×32 plate.
const CURSOR_BUBBLE_HOTSPOT := Vector2(2, 30)
## Bit of the key points upper-left after 180° rotation.
const CURSOR_KEY_HOTSPOT := Vector2(10, 4)
## Pinch point of the grab hand (opening at mid-left).
const CURSOR_HAND_HOTSPOT := Vector2(7, 14)
## Center of the search lens (upper-left circle).
const CURSOR_SEARCH_HOTSPOT := Vector2(12, 11)

## True while a menu (title/options/load/esc/ztats/…) is the active screen —
## sword shows for every cursor shape so it never depends on hover position.
static var _menu_cursor_active := false
## Explore/combat walk hint: cardinally split from the player (X diagonals).
static var _play_dir := Vector2i.ZERO
## City talk: pointer is over a person `_do_talk` can actually address.
static var _talk_cursor_active := false
## Adjacent locked door: Jimmy (J) target under the pointer.
static var _jimmy_cursor_active := false
## Open / Get / Board / Klimb / Descend target under the pointer.
static var _hand_cursor_active := false
## Adjacent field foe: Attack (A) — same sword art as menus, hover-only.
static var _attack_cursor_active := false
## Right-panel party row: Ztats (Z) — search glass, even while a pick menu is open.
static var _search_cursor_active := false
## D2Coding is monospace — good for command/message columns.

static var _font: Font
static var _font_bold: Font


static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) as Font
	return _font


static func font_bold() -> Font:
	if _font_bold == null:
		_font_bold = load(FONT_BOLD_PATH) as Font
	return _font_bold


static func apply_root(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	apply_cursors()


static func apply_cursors() -> void:
	_refresh_cursor_textures()


## Call whenever a screen switches between "showing a menu to pick from"
## (title menu, options, load, esc menu, ztats/ready/wear/cast/use/mix, …)
## and "no menu" (free map exploration, narrative-only screens, loading).
## Sword is shown for every hovered shape while a menu is active, so it
## never flickers back to the ankh just because the pointer sits over a
## non-interactive part of the same menu.
static func set_menu_cursor(active: bool) -> void:
	if active == _menu_cursor_active:
		return
	_menu_cursor_active = active
	_refresh_cursor_textures()


static func set_play_dir_cursor(dir: Vector2i) -> void:
	if dir == _play_dir:
		return
	_play_dir = dir
	if (
		_menu_cursor_active
		or _talk_cursor_active
		or _jimmy_cursor_active
		or _hand_cursor_active
		or _attack_cursor_active
		or _search_cursor_active
	):
		return
	_refresh_cursor_textures()


static func set_talk_cursor(active: bool) -> void:
	if active == _talk_cursor_active:
		return
	_talk_cursor_active = active
	if _menu_cursor_active:
		return
	_refresh_cursor_textures()


static func set_jimmy_cursor(active: bool) -> void:
	if active == _jimmy_cursor_active:
		return
	_jimmy_cursor_active = active
	if _menu_cursor_active or _talk_cursor_active:
		return
	_refresh_cursor_textures()


static func set_hand_cursor(active: bool) -> void:
	if active == _hand_cursor_active:
		return
	_hand_cursor_active = active
	if _menu_cursor_active or _talk_cursor_active or _jimmy_cursor_active:
		return
	_refresh_cursor_textures()


static func set_attack_cursor(active: bool) -> void:
	if active == _attack_cursor_active:
		return
	_attack_cursor_active = active
	if _menu_cursor_active or _talk_cursor_active or _jimmy_cursor_active or _hand_cursor_active:
		return
	_refresh_cursor_textures()


static func set_search_cursor(active: bool) -> void:
	if active == _search_cursor_active:
		return
	_search_cursor_active = active
	_refresh_cursor_textures()


static func _refresh_cursor_textures() -> void:
	var path := CURSOR_ANKH_PATH
	var hotspot := CURSOR_ANKH_HOTSPOT
	if _search_cursor_active:
		path = CURSOR_SEARCH_PATH
		hotspot = CURSOR_SEARCH_HOTSPOT
	elif _menu_cursor_active:
		path = CURSOR_SWORD_PATH
		hotspot = CURSOR_SWORD_HOTSPOT
	elif _talk_cursor_active:
		path = CURSOR_BUBBLE_PATH
		hotspot = CURSOR_BUBBLE_HOTSPOT
	elif _jimmy_cursor_active:
		path = CURSOR_KEY_PATH
		hotspot = CURSOR_KEY_HOTSPOT
	elif _hand_cursor_active:
		path = CURSOR_HAND_PATH
		hotspot = CURSOR_HAND_HOTSPOT
	elif _attack_cursor_active:
		path = CURSOR_SWORD_PATH
		hotspot = CURSOR_SWORD_HOTSPOT
	elif _play_dir.y < 0:
		path = CURSOR_ARROW_UP_PATH
		hotspot = CURSOR_ARROW_UP_HOTSPOT
	elif _play_dir.y > 0:
		path = CURSOR_ARROW_DOWN_PATH
		hotspot = CURSOR_ARROW_DOWN_HOTSPOT
	elif _play_dir.x < 0:
		path = CURSOR_ARROW_LEFT_PATH
		hotspot = CURSOR_ARROW_LEFT_HOTSPOT
	elif _play_dir.x > 0:
		path = CURSOR_ARROW_RIGHT_PATH
		hotspot = CURSOR_ARROW_RIGHT_HOTSPOT
	var tex := load(path) as Texture2D
	if tex == null:
		return
	## Bind every shape our UI ever requests to the same texture so the
	## icon depends only on context, not on which Control is hovered.
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, hotspot)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_POINTING_HAND, hotspot)


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
	## Committed selection (gender, Y/N, …) — blue border, not ACCENT focus gold.
	var sb := make_button_normal()
	sb.bg_color = Color("1a3548")
	sb.border_color = SELECT
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
	apply_font(btn)


static func style_choice_button(btn: Button, selected: bool) -> void:
	style_button(btn)
	if selected:
		var sel := make_button_selected()
		btn.add_theme_stylebox_override("normal", sel)
		btn.add_theme_stylebox_override("hover", sel)
		btn.add_theme_stylebox_override("pressed", sel)
		## Focus stays gold so keyboard cursor is never mistaken for the selection.
		btn.add_theme_stylebox_override("focus", make_button_focus())
		btn.add_theme_color_override("font_color", SELECT)
		btn.add_theme_color_override("font_hover_color", SELECT)
		btn.add_theme_color_override("font_pressed_color", SELECT)
		btn.add_theme_color_override("font_focus_color", ACCENT)



static func style_label(label: Label, size: int = 18, color: Color = TEXT) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	apply_font(label)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


static func apply_font(control: Control, bold: bool = false) -> void:
	var f := font_bold() if bold else font()
	if f == null:
		return
	control.add_theme_font_override("font", f)


## Cool blue used by list selection edges (bright stop of the gradient).
const CURSOR_EDGE := Color(0.38, 0.58, 0.82, 0.72)
## Horizontal gradient for selected rows: left transparent → right bright.
static var _selection_edge_tex: ImageTexture


static func selection_edge_width(font_size: int = 14) -> float:
	## Roughly four monospaced Latin glyphs.
	return maxf(float(font_size) * 2.4, 24.0)


static func selection_edge_texture() -> Texture2D:
	if _selection_edge_tex != null:
		return _selection_edge_tex
	var w := 48
	var img := Image.create(w, 1, false, Image.FORMAT_RGBA8)
	var last := maxi(w - 1, 1)
	for x in w:
		## White alpha ramp; tint via TextureRect.modulate.
		var t := float(x) / float(last)
		img.set_pixel(x, 0, Color(1.0, 1.0, 1.0, t))
	_selection_edge_tex = ImageTexture.create_from_image(img)
	return _selection_edge_tex


static func make_selection_edge(
	meta_key: String = "",
	font_size: int = 14,
	edge_name: String = "SelectionEdge"
) -> TextureRect:
	## Right-anchored gradient strip (~2 Latin chars wide). Start hidden.
	var edge := TextureRect.new()
	edge.name = edge_name
	edge.texture = selection_edge_texture()
	edge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	edge.stretch_mode = TextureRect.STRETCH_SCALE
	edge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.modulate = Color(1, 1, 1, 0)
	edge.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	var w := selection_edge_width(font_size)
	edge.offset_left = -w
	edge.offset_right = 0
	edge.offset_top = 0
	edge.offset_bottom = 0
	if not meta_key.is_empty():
		edge.set_meta(meta_key, true)
	return edge


static func set_selection_edge_active(
	edge: CanvasItem,
	on: bool,
	tint: Color = CURSOR_EDGE
) -> void:
	if edge == null:
		return
	if on:
		edge.modulate = tint
	else:
		edge.modulate = Color(tint.r, tint.g, tint.b, 0.0)


static func layout_selection_edge(
	edge: Control,
	row_w: float,
	row_h: float,
	font_size: int = 14
) -> void:
	if edge == null:
		return
	var w := selection_edge_width(font_size)
	edge.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	edge.position = Vector2(maxf(row_w - w, 0.0), 0.0)
	edge.size = Vector2(w, row_h)
