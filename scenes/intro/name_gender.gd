extends Control

## xu4 initiateNewGame: name + sex before story / virtue questions.
## Full-screen scene, or embedded in main-menu map frame via begin_embedded().
## English defaults to Avatar; Korean defaults to 아바타.

signal cancelled ## Embedded mode: return to Journey menu (not a scene change).
signal completed ## DOS import mode: edited identity is ready to be saved.

const _HangulComposerInput := preload("res://src/core/hangul_composer_input.gd")
const _GameInput := preload("res://src/core/game_input.gd")
const DEFAULT_NAME_EN := "Avatar"
const DEFAULT_NAME_KO := "아바타"

@onready var _name_en_prompt: Label = %NameEnPrompt
@onready var _name_ko_prompt: Label = %NameKoPrompt
@onready var _sex_prompt: Label = %SexPrompt
@onready var _class_line: Label = %ClassLine
@onready var _portrait: TextureRect = %Portrait
@onready var _name_en: LineEdit = %NameEnEdit
@onready var _name_ko: LineEdit = %NameKoEdit
@onready var _male: Button = %Male
@onready var _female: Button = %Female
@onready var _continue: Button = %Continue
@onready var _back: Button = %Back
@onready var _hint: Label = %Hint
@onready var _panel: PanelContainer = %Panel
@onready var _margin: MarginContainer = %Margin
@onready var _vbox: VBoxContainer = %VBox
@onready var _bg: ColorRect = $ColorRect
@onready var _center: CenterContainer = $Center

var _sex_group := ButtonGroup.new()
var _editing: LineEdit = null
var _embedded := false
var _import_mode := false
var _name_caret: TextureRect
var _name_cursor_frames: Array[Texture2D] = []
var _name_cursor_frame := 0
var _name_cursor_time := 0.0
## Set true before add_child when hosting in MainMenu (avoids one-frame full-screen flash).
var prepare_embedded := false
## libhangul path matching talk/shop text entry.
var _hangul := _HangulComposerInput.new()


func _ready() -> void:
	if prepare_embedded:
		_embedded = true
	_hangul.max_length = 16
	set_process_input(true)
	set_process(false)
	UiTheme.apply_root(self)
	## Name/sex picker is a choice form — sword regardless of pointer position.
	UiTheme.set_menu_cursor(true)
	if _bg:
		_bg.color = UiTheme.BG
		if _embedded:
			_bg.visible = false
	if _panel:
		if _embedded:
			_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		else:
			_panel.add_theme_stylebox_override("panel", UiTheme.make_panel())

	_apply_compact_chrome()

	if _portrait:
		_portrait.visible = false
		_portrait.texture = null
		_portrait.custom_minimum_size = Vector2.ZERO

	_wire_name_field(_name_en, DEFAULT_NAME_EN)
	_wire_name_field(_name_ko, DEFAULT_NAME_KO)
	_load_names_into_fields()

	for btn in [_male, _female]:
		btn.toggle_mode = true
		btn.button_group = _sex_group
		btn.focus_mode = Control.FOCUS_ALL
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_wire_focus_neighbors()

	_male.pressed.connect(func() -> void: _set_sex("male"))
	_female.pressed.connect(func() -> void: _set_sex("female"))
	_continue.pressed.connect(_on_continue)
	_back.pressed.connect(_on_back)

	GameState.language_changed.connect(func(_l: String) -> void: _refresh())
	if not _embedded:
		_set_sex(GameState.player_sex if GameState.player_sex in ["male", "female"] else "male")
		_refresh()
		_name_en.grab_focus()


const _BTN_W := 148.0
const _BTN_H := 40.0
## Top pad, between major blocks, and bottom pad share this rhythm.
const _SECTION_GAP := 20


func _apply_compact_chrome() -> void:
	## Comfortable section gaps; fonts slightly smaller only when embedded.
	var prompt_sz := 16 if _embedded else 17
	UiTheme.style_label(_name_en_prompt, prompt_sz, UiTheme.MUTED)
	UiTheme.style_label(_name_ko_prompt, prompt_sz, UiTheme.MUTED)
	UiTheme.style_label(_sex_prompt, prompt_sz, UiTheme.MUTED)
	if _class_line:
		_class_line.visible = false
	UiTheme.style_label(_hint, 13, UiTheme.MUTED)
	if _hint:
		_hint.visible = false
	UiTheme.style_button(_continue)
	UiTheme.style_button(_back)
	_match_action_button_sizes()
	_apply_even_section_gaps()


func _apply_even_section_gaps() -> void:
	## Top / inter-section / bottom use the same spacing. No scroll area.
	var g := _SECTION_GAP
	if _margin:
		_margin.add_theme_constant_override("margin_left", g)
		_margin.add_theme_constant_override("margin_right", g)
		_margin.add_theme_constant_override("margin_top", g)
		_margin.add_theme_constant_override("margin_bottom", g)
	if _vbox:
		_vbox.add_theme_constant_override("separation", g)
	## Name fields stay tighter than section gaps.
	var name_block := _vbox.get_node_or_null("NameBlock") as VBoxContainer if _vbox else null
	if name_block:
		name_block.add_theme_constant_override("separation", maxi(int(g * 0.5), 10))


func _match_action_button_sizes() -> void:
	## Sex choices and Back/Continue share the same width × height.
	var sz := Vector2(_BTN_W, _BTN_H)
	for btn in [_male, _female, _back, _continue]:
		if btn == null:
			continue
		btn.custom_minimum_size = sz


func _apply_mode_font_sizes() -> void:
	var field_size := 18 if _embedded else 19
	for field in [_name_en, _name_ko]:
		field.add_theme_font_size_override("font_size", field_size)
	var button_size := 18
	for btn in [_male, _female, _back, _continue]:
		btn.add_theme_font_size_override("font_size", button_size)


func _wire_name_field(field: LineEdit, placeholder: String) -> void:
	_style_name_field(field)
	field.focus_mode = Control.FOCUS_ALL
	field.placeholder_text = placeholder
	field.editable = false
	field.gui_input.connect(func(ev: InputEvent) -> void: _on_name_gui_input(field, ev))
	field.focus_exited.connect(func() -> void: _end_name_edit(field))
	field.text_submitted.connect(func(_t: String) -> void: _on_name_submitted(field))
	field.focus_entered.connect(func() -> void: _apply_name_text_colors(field))
	field.text_changed.connect(func(_t: String) -> void: _apply_name_text_colors(field))


func _load_names_into_fields() -> void:
	_hangul.reset_composer()
	_name_en.text = GameState.player_name
	_name_ko.text = GameState.player_name_ko
	_editing = null
	_name_en.editable = false
	_name_ko.editable = false
	_apply_name_text_colors(_name_en)
	_apply_name_text_colors(_name_ko)
	_refresh_name_prompts()


func is_embedded() -> bool:
	return _embedded and visible


func _korean_name_uses_composer() -> bool:
	return _HangulComposerInput.is_available() and _hangul.ensure()


func _set_window_ime(active: bool) -> void:
	var window := get_window()
	if window != null:
		window.set_ime_active(active)


const _ResImage := preload("res://src/core/res_image.gd")
const _NAME_CURSOR_CHARSET := "res://assets/tiles/u4graphics/charset.png"
const _NAME_CURSOR_GLYPH := 16
const _NAME_CURSOR_CHAR0 := 28
const _NAME_CURSOR_FRAMES := 4
const _NAME_CURSOR_SEC := 0.34


func _process(delta: float) -> void:
	if _editing == null:
		_hide_name_caret()
		return
	_name_cursor_time += delta
	if _name_cursor_time >= _NAME_CURSOR_SEC:
		_name_cursor_time = 0.0
		if not _name_cursor_frames.is_empty():
			_name_cursor_frame = (
				_name_cursor_frame - 1 + _name_cursor_frames.size()
			) % _name_cursor_frames.size()
			_name_caret.texture = _name_cursor_frames[_name_cursor_frame]
	_sync_name_caret()


func _show_name_caret(field: LineEdit) -> void:
	if field == null:
		return
	_ensure_name_cursor_frames()
	if _name_caret == null or not is_instance_valid(_name_caret):
		_name_caret = TextureRect.new()
		_name_caret.name = "NameCaret"
		_name_caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_name_caret.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_name_caret.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_name_caret.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not _name_cursor_frames.is_empty():
		_name_caret.texture = _name_cursor_frames[_name_cursor_frame]
	if _name_caret.get_parent() != field:
		if _name_caret.get_parent() != null:
			_name_caret.get_parent().remove_child(_name_caret)
		field.add_child(_name_caret)
	_name_cursor_time = 0.0
	set_process(true)
	_sync_name_caret()


func _hide_name_caret() -> void:
	set_process(false)
	if _name_caret != null and is_instance_valid(_name_caret):
		_name_caret.visible = false


func _ensure_name_cursor_frames() -> void:
	if not _name_cursor_frames.is_empty():
		return
	var img := _ResImage.load_rgba8(_NAME_CURSOR_CHARSET)
	if img == null or img.is_empty():
		return
	for frame in _NAME_CURSOR_FRAMES:
		var tex := _name_cursor_glyph(img, _NAME_CURSOR_CHAR0 + frame)
		if tex != null:
			_name_cursor_frames.append(tex)


func _name_cursor_glyph(sheet: Image, char_index: int) -> Texture2D:
	var cy := char_index * _NAME_CURSOR_GLYPH
	if cy + _NAME_CURSOR_GLYPH > sheet.get_height():
		return null
	var glyph := Image.create(_NAME_CURSOR_GLYPH, _NAME_CURSOR_GLYPH, false, Image.FORMAT_RGBA8)
	glyph.blit_rect(
		sheet, Rect2i(0, cy, _NAME_CURSOR_GLYPH, _NAME_CURSOR_GLYPH), Vector2i.ZERO
	)
	for y in _NAME_CURSOR_GLYPH:
		for x in _NAME_CURSOR_GLYPH:
			var c := glyph.get_pixel(x, y)
			if c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
				glyph.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				glyph.set_pixel(x, y, Color(
					minf(c.r * 1.45 + 0.12, 1.0),
					minf(c.g * 1.45 + 0.12, 1.0),
					minf(c.b * 1.45 + 0.06, 1.0),
					c.a
				))
	return ImageTexture.create_from_image(glyph)


func _sync_name_caret() -> void:
	if _name_caret == null or _editing == null or not is_instance_valid(_editing):
		_hide_name_caret()
		return
	var field := _editing
	var font := field.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size := field.get_theme_font_size("font_size")
	var text_size := font.get_string_size(field.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var line_h := font.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).y
	var box := field.get_theme_stylebox("read_only")
	var left := box.content_margin_left if box else 0.0
	var right := box.content_margin_right if box else 0.0
	var top := box.content_margin_top if box else 0.0
	var bottom := box.content_margin_bottom if box else 0.0
	var inner_w := maxf(field.size.x - left - right, 0.0)
	var inner_h := maxf(field.size.y - top - bottom, 0.0)
	var x := left + text_size.x
	if field.alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x = left + maxf(inner_w - text_size.x, 0.0) * 0.5 + text_size.x
	elif field.alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x = left + maxf(inner_w - text_size.x, 0.0) + text_size.x
	var side := line_h if inner_h <= 0.0 else minf(line_h, inner_h)
	var y := top + maxf(inner_h - side, 0.0) * 0.5
	_name_caret.position = Vector2(round(x), round(y))
	_name_caret.size = Vector2(round(side), round(side))
	_name_caret.visible = true


func _apply_hangul_to_field() -> void:
	if _editing == null:
		return
	_editing.text = _hangul.display_text()
	_editing.caret_column = _editing.text.length()
	_apply_name_text_colors(_editing)
	_sync_name_caret()


func _refresh_name_prompts() -> void:
	var mode := ""
	if _editing == _name_ko and _korean_name_uses_composer():
		mode = "[한] " if HangulInputSettings.is_korean_mode() else "[A] "
	if _name_en_prompt:
		_name_en_prompt.text = Locale.t("name_prompt_en")
	if _name_ko_prompt:
		_name_ko_prompt.text = (
			mode + Locale.t("name_prompt_ko") if _editing == _name_ko else Locale.t("name_prompt_ko")
		)


func begin_embedded(frame_rect: Rect2) -> void:
	## Mount into main-menu map frame (no full-screen chrome / scene change).
	_import_mode = false
	_embedded = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _bg:
		_bg.visible = false
	if _hint:
		_hint.visible = false
	if _panel:
		_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_apply_compact_chrome()
	set_embed_rect(frame_rect)
	_load_names_into_fields()
	_set_sex(GameState.player_sex if GameState.player_sex in ["male", "female"] else "male")
	_refresh()
	call_deferred("_focus_name")


func begin_import_embedded(frame_rect: Rect2) -> void:
	## DOS import keeps class/stats fixed; only names and sex remain editable.
	_import_mode = true
	_embedded = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _bg:
		_bg.visible = false
	if _hint:
		_hint.visible = false
	if _panel:
		_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_apply_compact_chrome()
	set_embed_rect(frame_rect)
	_load_names_into_fields()
	_set_sex(GameState.player_sex if GameState.player_sex in ["male", "female"] else "male")
	_refresh()
	call_deferred("_focus_name")


func set_embed_rect(frame_rect: Rect2) -> void:
	if not _embedded:
		return
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	anchor_right = 0.0
	anchor_bottom = 0.0
	position = frame_rect.position
	size = frame_rect.size
	custom_minimum_size = frame_rect.size
	## Frame fills; panel sizes to content and is centered (no scroll bar).
	if _center:
		_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _panel:
		var pad := 4.0
		var max_w := maxf(frame_rect.size.x - pad * 2.0, 200.0)
		_panel.custom_minimum_size = Vector2(minf(max_w, 420.0), 0)
		_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_even_section_gaps()


func close_embedded() -> void:
	visible = false
	_embedded = false
	_import_mode = false
	if _editing != null:
		_end_name_edit(_editing)
	_hangul.reset_composer()
	_editing = null
	if _name_en:
		_name_en.editable = false
	if _name_ko:
		_name_ko.editable = false


func _focus_name() -> void:
	if is_instance_valid(_name_en):
		_name_en.grab_focus()


func _style_name_field(field: LineEdit) -> void:
	## Underline-only field; text stays white in all edit/focus states.
	field.add_theme_font_size_override("font_size", 18 if _embedded else 19)
	UiTheme.apply_font(field)
	var line := _make_name_underline()
	var line_focus := _make_name_underline(true)
	for style_name in ["normal", "read_only", "focus"]:
		field.add_theme_stylebox_override(style_name, line_focus if style_name == "focus" else line)
	_apply_name_text_colors(field)


func _make_name_underline(focused: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_width_left = 0
	sb.border_width_top = 0
	sb.border_width_right = 0
	sb.border_width_bottom = 2
	sb.border_color = UiTheme.ACCENT if focused else UiTheme.TEXT
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 3
	sb.content_margin_bottom = 5
	return sb


func _apply_name_text_colors(field: LineEdit) -> void:
	if field == null:
		return
	var white := UiTheme.TEXT
	field.add_theme_color_override("font_color", white)
	field.add_theme_color_override("font_uneditable_color", white)
	field.add_theme_color_override("font_selected_color", white)
	field.add_theme_color_override("font_placeholder_color", Color(white.r, white.g, white.b, 0.45))
	field.add_theme_color_override("caret_color", white)
	field.add_theme_color_override("selection_color", Color(UiTheme.ACCENT.r, UiTheme.ACCENT.g, UiTheme.ACCENT.b, 0.35))


func _wire_focus_neighbors() -> void:
	## Character-create navigation does not wrap (no loops).
	_name_en.focus_neighbor_top = _name_en.get_path_to(_name_en)
	_name_en.focus_neighbor_left = _name_en.get_path_to(_name_en)
	_name_en.focus_neighbor_right = _name_en.get_path_to(_name_en)
	_name_en.focus_neighbor_bottom = _name_en.get_path_to(_name_ko)

	_name_ko.focus_neighbor_top = _name_ko.get_path_to(_name_en)
	_name_ko.focus_neighbor_left = _name_ko.get_path_to(_name_ko)
	_name_ko.focus_neighbor_right = _name_ko.get_path_to(_name_ko)
	## bottom → selected sex (see _sync_sex_focus_neighbors)

	## Sex: left ends at Male, right ends at Female (no wrap).
	_male.focus_neighbor_left = _male.get_path_to(_male)
	_male.focus_neighbor_right = _male.get_path_to(_female)
	_male.focus_neighbor_top = _male.get_path_to(_name_ko)
	_male.focus_neighbor_bottom = _male.get_path_to(_continue)

	_female.focus_neighbor_left = _female.get_path_to(_male)
	_female.focus_neighbor_right = _female.get_path_to(_female)
	_female.focus_neighbor_top = _female.get_path_to(_name_ko)
	_female.focus_neighbor_bottom = _female.get_path_to(_continue)

	## Actions: left ends at Back, right ends at Continue; no wrap below.
	_back.focus_neighbor_left = _back.get_path_to(_back)
	_back.focus_neighbor_right = _back.get_path_to(_continue)
	_back.focus_neighbor_bottom = _back.get_path_to(_back)

	_continue.focus_neighbor_left = _continue.get_path_to(_back)
	_continue.focus_neighbor_right = _continue.get_path_to(_continue)
	_continue.focus_neighbor_bottom = _continue.get_path_to(_continue)

	_sync_sex_focus_neighbors()


func _sync_sex_focus_neighbors() -> void:
	var sex_btn: Button = _female if GameState.player_sex == "female" else _male
	_name_ko.focus_neighbor_bottom = _name_ko.get_path_to(sex_btn)
	_continue.focus_neighbor_top = _continue.get_path_to(sex_btn)
	_back.focus_neighbor_top = _back.get_path_to(sex_btn)


func _selected_sex_button() -> Button:
	return _female if GameState.player_sex == "female" else _male


func _focused_name_field() -> LineEdit:
	if _name_en.has_focus():
		return _name_en
	if _name_ko.has_focus():
		return _name_ko
	return null


func _unhandled_input(event: InputEvent) -> void:
	if _embedded and not visible:
		return
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_LEFT_X or motion.axis == JOY_AXIS_LEFT_Y:
			var stick_dir: Vector2i = _GameInput.stick_direction_step(event)
			if _editing == null and stick_dir != Vector2i.ZERO:
				_move_focus_from_stick(stick_dir)
			## Consume every left-stick axis event, including neutral/release,
			## so move_* cannot cascade through multiple form rows.
			get_viewport().set_input_as_handled()
			return
	## English names stay on a Latin keyboard. The OS input method stays off.
	if _editing == _name_en and event is InputEventKey:
		_handle_english_name_key(event as InputEventKey)
		get_viewport().set_input_as_handled()
		return
	## Match world dialogue exactly: a read-only display field leaves physical
	## key events for this stage, where libhangul handles 한/영 and composition.
	if _editing == _name_ko and _korean_name_uses_composer() and event is InputEventKey:
		var res: Dictionary = _hangul.handle_key(event as InputEventKey)
		if bool(res.get("handled", false)):
			_apply_hangul_to_field()
			_refresh_name_prompts()
			if bool(res.get("submit", false)):
				var field := _editing
				_end_name_edit(field)
				_after_name_submitted(field)
			elif bool(res.get("cancel", false)):
				var was := _editing
				_end_name_edit(was)
				if was:
					was.grab_focus()
			get_viewport().set_input_as_handled()
		return
	## Only name/gender may leave character creation via Esc (→ main menu).
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
		if _editing != null:
			var was := _editing
			_end_name_edit(was)
			was.grab_focus()
		else:
			_on_back()
		get_viewport().set_input_as_handled()
		return

	var name_field := _focused_name_field()
	if name_field != null and _editing != name_field:
		if (
			_GameInput.is_select(event)
			or event.is_action_pressed("ui_accept")
			or event.is_action_pressed("confirm")
		):
			_begin_name_edit(name_field)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
			if name_field == _name_en:
				_name_ko.grab_focus()
			else:
				_selected_sex_button().grab_focus()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
			if name_field == _name_ko:
				_name_en.grab_focus()
			## English name is top — no wrap.
			get_viewport().set_input_as_handled()
			return

	## Sex: no left/right wrap past Male / Female.
	if _male.has_focus() and (
		event.is_action_pressed("ui_left") or event.is_action_pressed("move_left")
	):
		get_viewport().set_input_as_handled()
		return
	if _female.has_focus() and (
		event.is_action_pressed("ui_right") or event.is_action_pressed("move_right")
	):
		get_viewport().set_input_as_handled()
		return

	## From sex row, down always lands on Continue (Back is left on the same line).
	if (_male.has_focus() or _female.has_focus()) and (
		event.is_action_pressed("ui_down") or event.is_action_pressed("move_down")
	):
		_continue.grab_focus()
		get_viewport().set_input_as_handled()
		return

	## From sex row up → Korean name field.
	if (_male.has_focus() or _female.has_focus()) and (
		event.is_action_pressed("ui_up") or event.is_action_pressed("move_up")
	):
		_name_ko.grab_focus()
		get_viewport().set_input_as_handled()
		return

	## From action row, up returns to the *selected* sex (preserve female/male).
	if (_continue.has_focus() or _back.has_focus()) and (
		event.is_action_pressed("ui_up") or event.is_action_pressed("move_up")
	):
		_selected_sex_button().grab_focus()
		get_viewport().set_input_as_handled()
		return

	## Bottom of form — no wrap back to name.
	if (_continue.has_focus() or _back.has_focus()) and (
		event.is_action_pressed("ui_down") or event.is_action_pressed("move_down")
	):
		get_viewport().set_input_as_handled()
		return

	## Actions: no left/right wrap past Back / Continue.
	if _back.has_focus() and (
		event.is_action_pressed("ui_left") or event.is_action_pressed("move_left")
	):
		get_viewport().set_input_as_handled()
		return
	if _continue.has_focus() and (
		event.is_action_pressed("ui_right") or event.is_action_pressed("move_right")
	):
		get_viewport().set_input_as_handled()
		return

	if _editing != null and _editing.has_focus():
		return

	if _GameInput.is_select(event) or event.is_action_pressed("confirm"):
		var focus := get_viewport().gui_get_focus_owner()
		if focus == _continue or focus == null:
			_on_continue()
		elif focus == _back:
			_on_back()
		elif focus == _male:
			_set_sex("male")
		elif focus == _female:
			_set_sex("female")
		get_viewport().set_input_as_handled()


func _move_focus_from_stick(dir: Vector2i) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null:
		_name_en.grab_focus()
		return
	if dir.y < 0:
		if focus == _name_ko:
			_name_en.grab_focus()
		elif focus == _male or focus == _female:
			_name_ko.grab_focus()
		elif focus == _back or focus == _continue:
			_selected_sex_button().grab_focus()
		return
	if dir.y > 0:
		if focus == _name_en:
			_name_ko.grab_focus()
		elif focus == _name_ko:
			_selected_sex_button().grab_focus()
		elif focus == _male or focus == _female:
			_continue.grab_focus()
		return
	if dir.x < 0:
		if focus == _female:
			_male.grab_focus()
		elif focus == _continue:
			_back.grab_focus()
		return
	if dir.x > 0:
		if focus == _male:
			_female.grab_focus()
		elif focus == _back:
			_continue.grab_focus()


func _on_name_gui_input(field: LineEdit, event: InputEvent) -> void:
	if _editing == field:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_begin_name_edit(field)
		field.accept_event()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("confirm"):
		_begin_name_edit(field)
		field.accept_event()


func _begin_name_edit(field: LineEdit) -> void:
	if field == null or _editing == field:
		return
	if _editing != null and _editing != field:
		_end_name_edit(_editing)
	_editing = field
	if field == _name_en:
		_set_window_ime(false)
		field.editable = false
		field.virtual_keyboard_enabled = false
		_apply_name_text_colors(field)
		field.caret_column = field.text.length()
	elif _korean_name_uses_composer():
		## Talk-style: LineEdit displays buffer/preedit but does not invoke OS IME.
		## Opening this field always starts in Korean mode.
		HangulInputSettings.set_korean_mode(true)
		_set_window_ime(false)
		_hangul.max_length = maxi(field.max_length, 1)
		_hangul.begin(field.text)
		field.editable = false
		field.virtual_keyboard_enabled = false
		_apply_hangul_to_field()
	else:
		_set_window_ime(true)
		field.editable = true
		field.virtual_keyboard_enabled = true
		_apply_name_text_colors(field)
		field.caret_column = field.text.length()
	field.grab_focus()
	_refresh_name_prompts()
	_show_name_caret(field)


func _end_name_edit(field: LineEdit) -> void:
	if field == null or _editing != field:
		return
	if field == _name_ko and _korean_name_uses_composer():
		_hangul.flush_preedit()
		field.text = _hangul.buffer
		_hangul.reset_composer()
	_set_window_ime(false)
	_editing = null
	field.editable = false
	field.virtual_keyboard_enabled = false
	_hide_name_caret()
	_apply_name_text_colors(field)
	_refresh_name_prompts()


func _handle_english_name_key(k: InputEventKey) -> void:
	if not k.pressed or k.echo or _name_en == null:
		return
	var code := k.keycode
	var physical := k.physical_keycode
	if code == KEY_ESCAPE or physical == KEY_ESCAPE:
		var was := _editing
		_end_name_edit(was)
		if was:
			was.grab_focus()
		return
	if code in [KEY_ENTER, KEY_KP_ENTER] or physical in [KEY_ENTER, KEY_KP_ENTER]:
		var field := _editing
		_end_name_edit(field)
		_after_name_submitted(field)
		return
	if code == KEY_BACKSPACE or physical == KEY_BACKSPACE:
		if not _name_en.text.is_empty():
			_name_en.text = _name_en.text.substr(0, _name_en.text.length() - 1)
			_name_en.caret_column = _name_en.text.length()
			_sync_name_caret()
		return
	if k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return
	var ch := _english_name_char(k)
	if ch.is_empty() or _name_en.text.length() >= _name_en.max_length:
		return
	_name_en.text += ch
	_name_en.caret_column = _name_en.text.length()
	_sync_name_caret()


func _english_name_char(k: InputEventKey) -> String:
	var ascii := _HangulComposerInput.physical_ascii(k)
	if ascii < 0:
		return ""
	var latin := (
		(ascii >= 65 and ascii <= 90)
		or (ascii >= 97 and ascii <= 122)
		or ascii == 32
		or ascii == 39
		or ascii == 45
	)
	return String.chr(ascii) if latin else ""


func _on_name_submitted(field: LineEdit) -> void:
	## OS LineEdit path (English UI / no libhangul).
	_end_name_edit(field)
	_after_name_submitted(field)


func _after_name_submitted(field: LineEdit) -> void:
	if field == _name_en:
		_name_ko.grab_focus()
	else:
		## Keep current sex — never force Male when leaving the name field.
		_selected_sex_button().grab_focus()


func _set_sex(sex: String) -> void:
	GameState.player_sex = sex
	_male.disabled = false
	_female.disabled = false
	_male.set_pressed_no_signal(sex == "male")
	_female.set_pressed_no_signal(sex == "female")
	_apply_sex_visuals()
	_sync_sex_focus_neighbors()


func refresh_labels() -> void:
	_refresh()


func _refresh() -> void:
	_refresh_name_prompts()
	_sex_prompt.text = Locale.t("sex_prompt")
	## Class is chosen later, and a DOS import keeps it off this form too.
	if _class_line:
		_class_line.visible = false
		_class_line.text = ""
	_continue.text = Locale.t("dos_import_complete" if _import_mode else "continue")
	_back.text = Locale.t("back")
	if _hint:
		_hint.visible = false
	_apply_sex_visuals()
	_apply_mode_font_sizes()
	_sync_sex_focus_neighbors()


func _apply_sex_visuals() -> void:
	var male_on := GameState.player_sex == "male"
	_male.text = "♂  %s" % Locale.t("sex_male")
	_female.text = "♀  %s" % Locale.t("sex_female")
	UiTheme.style_choice_button(_male, male_on)
	UiTheme.style_choice_button(_female, not male_on)
	_apply_mode_font_sizes()
	_lock_sex_button_metrics(_male)
	_lock_sex_button_metrics(_female)


func _lock_sex_button_metrics(btn: Button) -> void:
	## Selection and focus use a thicker border than the idle style.
	## Keep every state on the same box so clicking does not resize the button.
	if btn == null:
		return
	var margin_x := 16
	var margin_y := 10
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var raw := btn.get_theme_stylebox(state)
		if not (raw is StyleBoxFlat):
			continue
		var flat := (raw as StyleBoxFlat).duplicate() as StyleBoxFlat
		flat.set_border_width_all(2)
		flat.content_margin_left = margin_x
		flat.content_margin_right = margin_x
		flat.content_margin_top = margin_y
		flat.content_margin_bottom = margin_y
		btn.add_theme_stylebox_override(state, flat)


func _on_back() -> void:
	if _editing != null:
		_end_name_edit(_editing)
	if _embedded:
		cancelled.emit()
	else:
		SceneRouter.to_menu("new")


func _on_continue() -> void:
	if _editing != null:
		_end_name_edit(_editing)
	var en := _name_en.text.strip_edges()
	if en.is_empty():
		en = DEFAULT_NAME_EN
	var ko := _name_ko.text.strip_edges()
	if ko.is_empty():
		ko = DEFAULT_NAME_KO
	GameState.player_name = en
	GameState.player_name_ko = ko
	if _import_mode:
		completed.emit()
	else:
		SceneRouter.to_story()
