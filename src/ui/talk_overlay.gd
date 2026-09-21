class_name TalkOverlay
extends Control

## Town-talk chrome on the map: NPC face + lines, avatar + keyword chips.

signal keyword_clicked(index: int)

const BORDER := Color(0.28, 0.55, 0.98, 1)
const BORDER_W := 3
const FACE_PAD := 2
const KEY_GAP := 18
const FONT_SIZE := 16
const TEXT := Color(0.96, 0.95, 0.88, 1)
const TEXT_DIM := Color(0.86, 0.85, 0.78, 1)
const KW_GOLD := Color("f0c93a")
const SHADOW := Color(0.0, 0.0, 0.0, 0.88)
const FALLBACK_FACE := Vector2(240, 300)
const FACE_SCALE := 0.5
const FACE_LINES := 6

var _safe := Rect2()
var _line_pitch := float(FONT_SIZE + 8)
var _root: Control
var _col: VBoxContainer
var _npc_row: HBoxContainer
var _avatar_row: HBoxContainer
var _npc_frame: Panel
var _npc_face: TextureRect
var _npc_name: Label
var _dialogue: RichTextLabel
var _avatar_frame: Panel
var _avatar_face: TextureRect
var _key_col: VBoxContainer
var _lead_label: Label
var _default_row: HBoxContainer
var _extra_flow: HFlowContainer
var _input_slot: Control
var _input_label: Label
var _input_edit: LineEdit
var _prompt_row: HBoxContainer
var _mode_label: Label
var _spin_cursor: TextureRect
var _chips: Array[Button] = []
var _cursor := 0
var _open := false
var _placeholder := ""
var _face_box := FALLBACK_FACE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	## Tilesets use nearest filtering; keep overlay type crisp and identical.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false
	_build()


func is_open() -> bool:
	return _open


func open() -> void:
	_open = true
	visible = true
	clear_dialogue()
	set_keywords([], 0, {})
	set_input_visible(false)
	move_to_front()


func close() -> void:
	_open = false
	visible = false
	release_input_edit()
	clear_dialogue()
	set_keywords([], 0, {})


func set_safe_rect(rect: Rect2) -> void:
	_safe = rect
	_layout_root()


func set_npc_caption(text: String) -> void:
	if _npc_name == null:
		return
	_npc_name.text = _caption_lines(text)
	_npc_name.visible = not _npc_name.text.is_empty()
	_layout_root()


func set_portraits(npc: Texture2D, avatar: Texture2D) -> void:
	_npc_face.texture = npc
	_npc_frame.visible = npc != null
	_avatar_face.texture = avatar
	_avatar_frame.visible = avatar != null
	_face_box = _shared_face_box(npc, avatar)
	_size_face(_npc_face, npc)
	_size_face(_avatar_face, avatar)
	_layout_root()


func clear_dialogue() -> void:
	if _dialogue != null:
		_dialogue.clear()


func append_dialogue(bbcode: String) -> void:
	if _dialogue == null or bbcode.strip_edges().is_empty():
		return
	if not _dialogue.get_parsed_text().is_empty():
		_dialogue.append_text("\n")
	_dialogue.append_text(bbcode)
	_layout_root()


func set_keywords(items: Array, cursor: int, default_keys: Dictionary) -> void:
	_cursor = cursor
	for chip in _chips:
		if is_instance_valid(chip):
			chip.queue_free()
	_chips.clear()
	for child in _default_row.get_children():
		child.queue_free()
	for child in _extra_flow.get_children():
		child.queue_free()
	for i in items.size():
		var item: Dictionary = items[i]
		var key := str(item.get("key", ""))
		var label := str(item.get("label", key))
		var chip := _make_chip(i, label, i == cursor)
		_chips.append(chip)
		if default_keys.has(key) or default_keys.has(key.to_lower()):
			_default_row.add_child(chip)
		else:
			_extra_flow.add_child(chip)
	_extra_flow.visible = _extra_flow.get_child_count() > 0


func set_player_lead(text: String) -> void:
	if _lead_label == null:
		return
	_lead_label.text = text.strip_edges()
	_lead_label.visible = not _lead_label.text.is_empty()
	_style_overlay_text(_lead_label)
	_lead_label.custom_minimum_size.y = _line_pitch


func set_choices(labels: Array, cursor: int) -> void:
	var items: Array = []
	var defaults := {}
	for i in labels.size():
		var key := "c%d" % i
		items.append({"key": key, "label": str(labels[i])})
		if labels.size() <= 2:
			defaults[key] = true
	set_keywords(items, cursor, defaults)


func set_cursor(index: int) -> void:
	_cursor = index
	for i in _chips.size():
		_style_chip(_chips[i], i == _cursor)


func keyword_rows() -> Array:
	## Chip index rows as painted: default HBox, then each wrapped extra line.
	var rows: Array = []
	var first: Array = []
	if _default_row != null:
		for child in _default_row.get_children():
			if child is Button:
				var idx := _chips.find(child)
				if idx >= 0:
					first.append(idx)
	if not first.is_empty():
		rows.append(first)
	var flow_chips: Array[Control] = []
	if _extra_flow != null and _extra_flow.visible:
		for child in _extra_flow.get_children():
			if child is Control and (child as Control).visible:
				flow_chips.append(child as Control)
	if flow_chips.is_empty():
		return rows
	flow_chips.sort_custom(func(a: Control, b: Control) -> bool:
		if absf(a.position.y - b.position.y) > 4.0:
			return a.position.y < b.position.y
		return a.position.x < b.position.x
	)
	var line: Array = []
	var line_y := -10000.0
	for chip in flow_chips:
		var idx := _chips.find(chip)
		if idx < 0:
			continue
		if line.is_empty() or absf(chip.position.y - line_y) > 4.0:
			if not line.is_empty():
				rows.append(line)
			line = [idx]
			line_y = chip.position.y
		else:
			line.append(idx)
	if not line.is_empty():
		rows.append(line)
	return rows


func chip_center_x(index: int) -> float:
	if index < 0 or index >= _chips.size():
		return 0.0
	var chip := _chips[index]
	if chip == null or not is_instance_valid(chip):
		return 0.0
	return chip.global_position.x + chip.size.x * 0.5


func attach_input_edit(edit: LineEdit) -> void:
	if edit == null or not is_instance_valid(edit):
		return
	if _input_edit == edit and edit.get_parent() == _input_slot:
		return
	release_input_edit()
	_input_edit = edit
	var parent := edit.get_parent()
	if parent != null:
		parent.remove_child(edit)
	_input_slot.add_child(edit)
	_style_input_edit(edit)
	edit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edit.visible = true


func release_input_edit() -> void:
	if _input_edit == null or not is_instance_valid(_input_edit):
		_input_edit = null
		return
	if _input_edit.get_parent() == _input_slot:
		_input_slot.remove_child(_input_edit)
	_input_edit = null


func set_spin_cursor(tex: Texture2D, on: bool) -> void:
	if _spin_cursor == null:
		return
	_spin_cursor.texture = tex
	_spin_cursor.visible = on


func set_mode_marker(text: String) -> void:
	if _mode_label == null:
		return
	_mode_label.text = text.strip_edges()
	_mode_label.visible = _input_slot.visible and not _mode_label.text.is_empty()
	_size_mode_label()


func set_input_visible(on: bool) -> void:
	_input_slot.visible = on
	if _mode_label != null:
		_mode_label.visible = on and not _mode_label.text.is_empty()
	if on and _input_edit != null and is_instance_valid(_input_edit):
		_input_edit.visible = true
		_style_input_edit(_input_edit)
		if _input_label != null:
			_input_label.visible = false
	elif _input_label != null:
		_input_label.visible = on
	_size_input_slot()


func set_input_text(text: String) -> void:
	if _input_label == null:
		return
	if text.is_empty():
		_input_label.text = input_placeholder()
		_input_label.add_theme_color_override("font_color", Color(TEXT, 0.45))
	else:
		_input_label.text = text
		_input_label.add_theme_color_override("font_color", TEXT)
	_size_input_slot()


func set_placeholder(text: String) -> void:
	_placeholder = text
	if _input_edit != null and is_instance_valid(_input_edit):
		_input_edit.placeholder_text = _placeholder


func input_placeholder() -> String:
	return _placeholder


func _build() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.anchor_left = 0
	_root.anchor_top = 0
	_root.anchor_right = 0
	_root.anchor_bottom = 0
	add_child(_root)
	_col = VBoxContainer.new()
	_col.name = "TalkCol"
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_theme_constant_override("separation", 14)
	_col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_col)
	_npc_row = HBoxContainer.new()
	_npc_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_npc_row.add_theme_constant_override("separation", 12)
	_npc_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_npc_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_col.add_child(_npc_row)
	var npc_stack := VBoxContainer.new()
	npc_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	npc_stack.add_theme_constant_override("separation", 4)
	npc_stack.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	npc_stack.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_npc_frame = _make_frame()
	_npc_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_npc_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_npc_face = _make_face()
	_npc_frame.add_child(_npc_face)
	npc_stack.add_child(_npc_frame)
	_npc_name = Label.new()
	_npc_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_npc_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_npc_name.clip_text = false
	_npc_name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_npc_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_overlay_text(_npc_name)
	npc_stack.add_child(_npc_name)
	_npc_row.add_child(npc_stack)
	_dialogue = RichTextLabel.new()
	_dialogue.bbcode_enabled = true
	_dialogue.fit_content = true
	_dialogue.scroll_active = false
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_style_overlay_text(_dialogue)
	_npc_row.add_child(_dialogue)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_col.add_child(spacer)
	_avatar_row = HBoxContainer.new()
	_avatar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar_row.add_theme_constant_override("separation", 12)
	_avatar_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_avatar_row.size_flags_vertical = Control.SIZE_SHRINK_END
	_col.add_child(_avatar_row)
	_avatar_frame = _make_frame()
	_avatar_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_avatar_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_avatar_face = _make_face()
	_avatar_frame.add_child(_avatar_face)
	_avatar_row.add_child(_avatar_frame)
	_key_col = VBoxContainer.new()
	_key_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_key_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_key_col.add_theme_constant_override("separation", 0)
	_avatar_row.add_child(_key_col)
	_lead_label = Label.new()
	_lead_label.visible = false
	_lead_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lead_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lead_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_lead_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_style_overlay_text(_lead_label)
	_key_col.add_child(_lead_label)
	_default_row = _make_key_row()
	_extra_flow = _make_flow()
	_key_col.add_child(_default_row)
	_key_col.add_child(_extra_flow)
	var key_spacer := Control.new()
	key_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_key_col.add_child(key_spacer)
	_prompt_row = HBoxContainer.new()
	_prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_row.add_theme_constant_override("separation", 6)
	_prompt_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt_row.size_flags_vertical = Control.SIZE_SHRINK_END
	_prompt_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_mode_label = Label.new()
	_mode_label.visible = false
	_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_overlay_text(_mode_label)
	_prompt_row.add_child(_mode_label)
	_input_slot = Control.new()
	_input_slot.visible = false
	_input_slot.custom_minimum_size = Vector2(8, float(FONT_SIZE) + 10.0)
	_input_slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_input_slot.mouse_filter = Control.MOUSE_FILTER_STOP
	_input_label = Label.new()
	_input_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_input_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_input_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_overlay_text(_input_label)
	_input_slot.add_child(_input_label)
	_prompt_row.add_child(_input_slot)
	_spin_cursor = TextureRect.new()
	_spin_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spin_cursor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spin_cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_spin_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spin_cursor.custom_minimum_size = Vector2(float(FONT_SIZE) + 4.0, float(FONT_SIZE) + 4.0)
	_spin_cursor.visible = false
	_prompt_row.add_child(_spin_cursor)
	_key_col.add_child(_prompt_row)
	resized.connect(_layout_root)
	call_deferred("_layout_root")


func _make_frame() -> Panel:
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.08, 0.55)
	sb.border_color = BORDER
	sb.set_border_width_all(BORDER_W)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = FACE_PAD
	sb.content_margin_right = FACE_PAD
	sb.content_margin_top = FACE_PAD
	sb.content_margin_bottom = FACE_PAD
	frame.add_theme_stylebox_override("panel", sb)
	return frame


func _make_face() -> TextureRect:
	var face := TextureRect.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return face


func _make_key_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", KEY_GAP)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	return row


func _make_flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_theme_constant_override("h_separation", KEY_GAP)
	flow.add_theme_constant_override("v_separation", 0)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return flow


func _make_chip(index: int, caption: String, selected: bool) -> Button:
	var chip := Button.new()
	chip.text = caption
	chip.focus_mode = Control.FOCUS_NONE
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.flat = true
	chip.pressed.connect(_on_chip_pressed.bind(index))
	_style_chip(chip, selected)
	return chip


func _style_chip(chip: Button, selected: bool) -> void:
	if chip == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	chip.add_theme_stylebox_override("normal", sb)
	chip.add_theme_stylebox_override("hover", sb)
	chip.add_theme_stylebox_override("pressed", sb)
	var color := KW_GOLD if selected else TEXT_DIM
	_style_overlay_text(chip, color)
	chip.custom_minimum_size.y = _line_pitch
	chip.add_theme_color_override("font_hover_color", KW_GOLD)
	chip.add_theme_color_override("font_pressed_color", KW_GOLD)


func _style_input_edit(edit: LineEdit) -> void:
	_style_overlay_text(edit)
	edit.add_theme_color_override("font_uneditable_color", TEXT)
	edit.add_theme_color_override("caret_color", TEXT)
	edit.add_theme_color_override("font_placeholder_color", Color(TEXT, 0.45))
	edit.placeholder_text = input_placeholder()
	var empty := StyleBoxEmpty.new()
	edit.add_theme_stylebox_override("normal", empty)
	edit.add_theme_stylebox_override("focus", empty)
	edit.add_theme_stylebox_override("read_only", empty)


func _apply_text_font(control: Control) -> void:
	_style_overlay_text(control)


func _style_overlay_text(control: Control, color: Color = TEXT) -> void:
	## Same typeface / size / outline for every tileset (New Color and Apple II).
	if control == null:
		return
	UiTheme.apply_font(control)
	control.add_theme_font_size_override("font_size", FONT_SIZE)
	control.add_theme_color_override("font_color", color)
	control.add_theme_color_override("font_shadow_color", SHADOW)
	control.add_theme_constant_override("shadow_offset_x", 1)
	control.add_theme_constant_override("shadow_offset_y", 1)
	control.add_theme_constant_override("shadow_outline_size", 8)
	control.add_theme_color_override("font_outline_color", SHADOW)
	control.add_theme_constant_override("outline_size", 8)
	if control is RichTextLabel:
		var f := UiTheme.font()
		if f != null:
			control.add_theme_font_override("normal_font", f)
			control.add_theme_font_override("bold_font", UiTheme.font_bold() if UiTheme.font_bold() != null else f)
		control.add_theme_color_override("default_color", color)
		control.add_theme_font_size_override("normal_font_size", FONT_SIZE)
		control.add_theme_font_size_override("bold_font_size", FONT_SIZE)
		control.add_theme_font_size_override("italics_font_size", FONT_SIZE)
		control.add_theme_constant_override("line_separation", _dialogue_line_gap())


func _on_chip_pressed(index: int) -> void:
	keyword_clicked.emit(index)


func _layout_root() -> void:
	if _root == null:
		return
	var area := _safe
	if area.size.x < 8.0 or area.size.y < 8.0:
		area = Rect2(Vector2.ZERO, size)
	var frame := _frame_size()
	var col_w := maxf(area.size.x, frame.x + 80.0)
	var col_h := maxf(area.size.y, frame.y * 2.0 + 28.0)
	_root.position = area.position
	_root.size = Vector2(col_w, col_h)
	_npc_frame.custom_minimum_size = frame
	_npc_frame.size = frame
	_avatar_frame.custom_minimum_size = frame
	_avatar_frame.size = frame
	_apply_face_line_metrics(frame.y)
	if _npc_name != null:
		_style_overlay_text(_npc_name)
		_npc_name.custom_minimum_size = Vector2(frame.x, _caption_height(_npc_name.text))
		_npc_name.size.x = frame.x
	_avatar_row.custom_minimum_size = Vector2(0, frame.y)
	var reserve := frame.y + 20.0
	var max_npc := maxf(col_h - reserve, frame.y)
	var text_h := 0.0
	if _dialogue != null:
		_dialogue.size.x = maxf(col_w - frame.x - 12.0, 40.0)
		text_h = float(_dialogue.get_content_height())
	var npc_h := clampf(maxf(frame.y, text_h + 8.0), frame.y, max_npc)
	_npc_row.custom_minimum_size = Vector2(0, npc_h)
	if _dialogue != null:
		_dialogue.custom_minimum_size = Vector2(0, npc_h)
		_dialogue.scroll_active = text_h + 8.0 > max_npc + 1.0
	_size_face(_npc_face, _npc_face.texture)
	_size_face(_avatar_face, _avatar_face.texture)
	_style_overlay_text(_dialogue)
	if _input_edit != null and is_instance_valid(_input_edit):
		_style_input_edit(_input_edit)
	_size_mode_label()
	_size_input_slot()
	if _spin_cursor != null:
		var cur := minf(_line_pitch, float(FONT_SIZE) + 4.0)
		_spin_cursor.custom_minimum_size = Vector2(cur, cur)


func _caption_height(text: String) -> float:
	var lines := 1
	if not text.is_empty():
		lines = text.split("\n").size()
	var font := _npc_name.get_theme_font("font") if _npc_name != null else null
	var line_h := float(FONT_SIZE + 6)
	if font != null:
		line_h = font.get_height(FONT_SIZE) + 4.0
	return line_h * float(maxi(lines, 1))


func _caption_lines(text: String) -> String:
	var t := text.replace("\r", "\n").strip_edges()
	while t.find("\n\n") >= 0:
		t = t.replace("\n\n", "\n")
	if t.find("\n") >= 0:
		var kept: PackedStringArray = PackedStringArray()
		for line in t.split("\n", false):
			var one := line.strip_edges()
			while one.find("  ") >= 0:
				one = one.replace("  ", " ")
			if not one.is_empty():
				kept.append(one)
		return "\n".join(kept)
	while t.find("  ") >= 0:
		t = t.replace("  ", " ")
	if t.is_empty():
		return t
	var parts := t.split(" ", false)
	if parts.size() == 2:
		return "%s\n%s" % [parts[0], parts[1]]
	if parts.size() >= 3:
		var head := " ".join(parts.slice(0, parts.size() - 1))
		return "%s\n%s" % [head, parts[parts.size() - 1]]
	return t


func _shared_face_box(npc: Texture2D, avatar: Texture2D) -> Vector2:
	var a := _display_size(npc)
	var b := _display_size(avatar)
	if a == Vector2.ZERO and b == Vector2.ZERO:
		return FALLBACK_FACE * FACE_SCALE
	if a == Vector2.ZERO:
		return b
	if b == Vector2.ZERO:
		return a
	return Vector2(maxf(a.x, b.x), maxf(a.y, b.y))


func _display_size(tex: Texture2D) -> Vector2:
	if tex == null:
		return Vector2.ZERO
	var sz := tex.get_size()
	if sz.x < 1.0 or sz.y < 1.0:
		return Vector2.ZERO
	return sz * FACE_SCALE


func _size_face(face: TextureRect, _tex: Texture2D) -> void:
	if face == null:
		return
	var inset := float(FACE_PAD + BORDER_W)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.offset_left = inset
	face.offset_top = inset
	face.offset_right = -inset
	face.offset_bottom = -inset


func _frame_size() -> Vector2:
	return _face_box + Vector2(float(FACE_PAD + BORDER_W) * 2.0, float(FACE_PAD + BORDER_W) * 2.0)


func _font_line_height() -> float:
	var font := UiTheme.font()
	if font == null:
		return float(FONT_SIZE)
	return font.get_height(FONT_SIZE)


func _dialogue_line_gap() -> int:
	return maxi(0, int(round(_line_pitch - _font_line_height())))


func _apply_face_line_metrics(frame_h: float) -> void:
	_line_pitch = maxf(frame_h / float(FACE_LINES), float(FONT_SIZE))
	if _key_col != null:
		_key_col.add_theme_constant_override("separation", 0)
		_key_col.custom_minimum_size.y = frame_h
	if _lead_label != null:
		_lead_label.custom_minimum_size.y = _line_pitch
	if _default_row != null:
		_default_row.custom_minimum_size.y = _line_pitch
	if _extra_flow != null:
		_extra_flow.add_theme_constant_override("v_separation", 0)
	if _prompt_row != null:
		_prompt_row.custom_minimum_size.y = _line_pitch
	for chip in _chips:
		if is_instance_valid(chip):
			chip.custom_minimum_size.y = _line_pitch


func _size_mode_label() -> void:
	if _mode_label == null:
		return
	_apply_text_font(_mode_label)
	var t := _mode_label.text
	if t.is_empty():
		_mode_label.custom_minimum_size = Vector2.ZERO
		return
	var font := _mode_label.get_theme_font("font")
	var w := float(FONT_SIZE) * float(t.length()) * 0.7
	if font != null:
		w = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	_mode_label.custom_minimum_size = Vector2(maxf(w, 8.0), _line_pitch)


func _size_input_slot() -> void:
	if _input_slot == null:
		return
	var h := _line_pitch
	if _input_edit != null and is_instance_valid(_input_edit) and _input_edit.visible:
		_input_slot.custom_minimum_size = Vector2(160.0, h)
		return
	var t := ""
	if _input_label != null:
		t = _input_label.text
	var w := 8.0
	if not t.is_empty():
		var font := _input_label.get_theme_font("font") if _input_label != null else null
		if font != null:
			w = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 4.0
		else:
			w = float(FONT_SIZE) * float(t.length()) * 0.55 + 4.0
	_input_slot.custom_minimum_size = Vector2(maxf(w, 8.0), h)
