extends Control

## xu4 showStory() then startQuestions() on one screen.
## Picture full-width top; letterbox text below. After story → abacus + cards + A/B.

const DIR := "res://assets/intro/story"
const TREE_FILE := "145-tree.png"
const ABACUS_FILE := "14b-abacus.png"
const PIC_H := 144
## vutne/145-tree.png subimages (xu4 U4-Upgrade graphics.b).
const MOONGATE := Rect2i(0, 152, 20, 24)
const ITEMS := Rect2i(24, 152, 20, 24)
const GATE_POS := Vector2i(84, 53)
const GATE_FRAME_SEC := 0.042
## vutne abacus + cards (graphics.b).
const CARD_POS := Vector2i(22, 16)
const CARD_GAP_W := 196
const CARD_SIZE := Vector2i(80, 112)
const CARD_RECTS: Array[Rect2i] = [
	Rect2i(0, 0, 80, 112), Rect2i(80, 0, 80, 112),
	Rect2i(160, 0, 80, 112), Rect2i(240, 0, 80, 112),
]
const WHITE_BEAD := Rect2i(12, 181, 7, 11)
const BLACK_BEAD := Rect2i(23, 181, 7, 11)
const BEAD_POS := Vector2i(128, 18)
const BEAD_CELL := Vector2i(8, 16)
const STORY_COUNT := 24
const TEXT_PAD_L := 12
const TEXT_PAD_R := 4
## Top pad slightly larger than bottom so the block sits nearer the letterbox middle.
const TEXT_PAD_TOP := 22
const TEXT_PAD_BOTTOM := 10
## Extra pixels between wrapped lines (Label default is typically 3).
const TEXT_LINE_SPACING := 6
const TEXT_LINE_SPACING_KO := 9
const TEXT_COLOR := Color(0.91, 0.9, 0.82, 1)
const TEXT_FONT_MIN := 14
const TEXT_FONT_MAX := 64
const CARD_BORDER_COLOR := Color(0.95, 0.85, 0.45, 1.0)
const CARD_BORDER_WIDTH := 3
## Auto-fit is sized to the longest story; nudge down so letterbox has headroom.
const EN_FONT_SCALE := 0.88
## Korean glyphs are wider; scale further.
const KO_FONT_SCALE := 0.80
const ASK_MAX_LINES := 4
const BLINK_OUT_SEC := 0.32
const BLINK_HOLD_SEC := 0.10
const BLINK_IN_SEC := 0.42

const BG_AT := {
	0: "145-tree.png",
	6: "146-portal.png",
	11: "145-tree.png",
	15: "147-outside.png",
	17: "148-inside.png",
	20: "149-wagon.png",
	21: "14a-gypsy.png",
	23: "14b-abacus.png",
}

enum GatePhase { NONE, OPENING, OPEN, CLOSING, IDLE }
enum Mode { STORY, QUESTIONS }
## xu4: lead+cards then waitAnyKey, then question + readChoice("ab").
enum QPhase { INTRO, ASK }

const _GameInput := preload("res://src/core/game_input.gd")

var _bg: ColorRect
var _view: TextureRect
var _text: Label
var _card_a: TextureRect
var _card_b: TextureRect
var _card_border_a: Panel
var _card_border_b: Panel
var _card_cursor := -1
var _story_ind := 0
var _cache: Dictionary = {}
var _tree_full: Image
var _tree_base: Image
var _tree_frame: Image
var _tree_tex: ImageTexture
var _gate_phase: int = GatePhase.NONE
var _gate_h := 0
var _gate_t := 0.0
var _current_bg: String = ""
var _mode: int = Mode.STORY
var _q_phase: int = QPhase.INTRO
var _q_tree := VirtueQuestionTree.new()
var _q_pair := Vector2i.ZERO
var _cards1: Image
var _cards2: Image
var _card_tex: Array[ImageTexture] = [] ## 8 virtue cards
var _abacus_full: Image
var _abacus_base: Image
var _abacus_frame: Image
var _abacus_tex: ImageTexture
var _fade: ColorRect
var _busy_fade := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_bg = ColorRect.new()
	_bg.color = Color.BLACK
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_view = TextureRect.new()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)

	_card_a = _make_card_rect()
	_card_b = _make_card_rect()
	add_child(_card_a)
	add_child(_card_b)
	_card_border_a = _make_card_border()
	_card_border_b = _make_card_border()
	add_child(_card_border_a)
	add_child(_card_border_b)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.clip_text = false
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.add_theme_color_override("font_color", TEXT_COLOR)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply_font(_text)
	add_child(_text)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.z_index = 20
	add_child(_fade)

	resized.connect(_layout)
	GameState.language_changed.connect(func(_l: String) -> void: _on_language_changed())
	_present_story(0)
	call_deferred("grab_focus")


func _make_card_rect() -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.visible = false
	return t


func _make_card_border() -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = CARD_BORDER_COLOR
	style.set_border_width_all(CARD_BORDER_WIDTH)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _process(delta: float) -> void:
	if _gate_phase != GatePhase.OPENING and _gate_phase != GatePhase.CLOSING:
		return
	_gate_t += delta
	while _gate_t >= GATE_FRAME_SEC:
		_gate_t -= GATE_FRAME_SEC
		if not _step_gate():
			break


func _gui_input(event: InputEvent) -> void:
	## Mouse clicks land here (MOUSE_FILTER_STOP), not only in _unhandled_input.
	if (
		_mode == Mode.QUESTIONS
		and _q_phase == QPhase.ASK
		and event is InputEventMouseMotion
	):
		_set_card_cursor(_card_pick_at(get_local_mouse_position()))
		accept_event()
		return
	if _handle_story_input(event):
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _busy_fade:
		get_viewport().set_input_as_handled()
		return
	## Esc only leaves character creation on the name/gender screen.
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel") or (
		event is InputEventKey and event.pressed and not event.echo
		and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE)
	):
		get_viewport().set_input_as_handled()
		return
	if _handle_story_input(event):
		get_viewport().set_input_as_handled()


func _handle_story_input(event: InputEvent) -> bool:
	## True if the event was consumed (advance or A/B choice).
	if _busy_fade:
		return true
	## Neutral motion must reach the hysteresis filter, so process left-stick X
	## before the generic pressed check.
	if (
		_mode == Mode.QUESTIONS
		and event is InputEventJoypadMotion
		and (event as InputEventJoypadMotion).axis == JOY_AXIS_LEFT_X
	):
		var step := _GameInput.stick_axis_step(event, JOY_AXIS_LEFT_X)
		if _q_phase == QPhase.ASK and step != 0:
			_set_card_cursor(0 if step < 0 else 1)
		return true
	if not event.is_pressed() or event.is_echo():
		return false
	if _mode == Mode.QUESTIONS:
		return _handle_question_input(event)
	if _is_advance_input(event):
		_advance()
		return true
	return false


func _handle_question_input(event: InputEvent) -> bool:
	if _q_phase == QPhase.INTRO:
		if _is_advance_input(event):
			_show_question_ask()
			return true
		return false
	## Direct keyboard A/B remains available without moving the cursor.
	if _is_letter(event, KEY_A):
		_answer_question(0)
		return true
	if _is_letter(event, KEY_B):
		_answer_question(1)
		return true
	## Keyboard arrows and gamepad D-pad move an initially-empty cursor.
	var nav := _card_nav_delta(event)
	if nav != 0:
		_set_card_cursor(0 if nav < 0 else 1)
		return true
	## Enter/Space and gamepad A only confirm after explicit navigation.
	if _is_keyboard_card_confirm(event) or _GameInput.is_select(event):
		if _card_cursor >= 0:
			_answer_question(_card_cursor)
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var pick := _card_pick_at(get_local_mouse_position())
		if pick >= 0:
			_set_card_cursor(pick)
			_answer_question(pick)
			return true
	return false


func _card_nav_delta(event: InputEvent) -> int:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.keycode == KEY_LEFT or key.physical_keycode == KEY_LEFT:
			return -1
		if key.keycode == KEY_RIGHT or key.physical_keycode == KEY_RIGHT:
			return 1
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if button.button_index == JOY_BUTTON_DPAD_LEFT:
			return -1
		if button.button_index == JOY_BUTTON_DPAD_RIGHT:
			return 1
	return 0


func _is_keyboard_card_confirm(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	return (
		key.keycode == KEY_ENTER or key.physical_keycode == KEY_ENTER
		or key.keycode == KEY_KP_ENTER or key.physical_keycode == KEY_KP_ENTER
	)


func _card_pick_at(local_pos: Vector2) -> int:
	## 0 = A (left card), 1 = B (right), -1 = miss.
	if _card_a != null and _card_a.visible and _card_a.get_rect().has_point(local_pos):
		return 0
	if _card_b != null and _card_b.visible and _card_b.get_rect().has_point(local_pos):
		return 1
	return -1


func _is_letter(event: InputEvent, key: int) -> bool:
	if event is InputEventKey:
		var k := event as InputEventKey
		return k.keycode == key or k.physical_keycode == key
	return false


func _is_advance_input(event: InputEvent) -> bool:
	## Any "next page" control: key, confirm/ui_accept, mouse LMB, gamepad A.
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("confirm"):
		return true
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventJoypadButton:
		return event.button_index == JOY_BUTTON_A
	if event is InputEventKey:
		var k := event as InputEventKey
		var code := k.keycode
		var phys := k.physical_keycode
		return (
			code == KEY_ENTER or phys == KEY_ENTER
			or code == KEY_KP_ENTER or phys == KEY_KP_ENTER
		)
	return false


func _advance() -> void:
	if _busy_fade:
		return
	if _gate_phase == GatePhase.OPENING:
		_gate_h = MOONGATE.size.y
		_compose_gate(false)
		_gate_phase = GatePhase.OPEN
		set_process(false)
		return
	if _gate_phase == GatePhase.CLOSING:
		_gate_h = 0
		_compose_gate(true)
		_gate_phase = GatePhase.IDLE
		set_process(false)
		return
	if _story_ind >= STORY_COUNT - 1:
		## Abacus/cards: no blink — picture already on the card backdrop.
		_start_questions()
		return
	var next_i := _story_ind + 1
	if _story_bg_file(_story_ind) != _story_bg_file(next_i):
		_blink_then(func() -> void: _present_story(next_i))
	else:
		## Same picture — text only, no blink.
		_present_story(next_i)


func _story_bg_file(ind: int) -> String:
	## Effective background for this story index (carry forward until BG_AT updates).
	var file := TREE_FILE
	var keys: Array = BG_AT.keys()
	keys.sort()
	for k in keys:
		if int(k) > ind:
			break
		file = str(BG_AT[k])
	return file


func _blink_then(after_black: Callable) -> void:
	## Brief black blink between story beats (and into the abacus).
	if _busy_fade or _fade == null:
		after_black.call()
		return
	_busy_fade = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade.color = Color(0, 0, 0, 0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, BLINK_OUT_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_interval(BLINK_HOLD_SEC)
	tw.tween_callback(after_black)
	tw.tween_property(_fade, "color:a", 0.0, BLINK_IN_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_busy_fade = false
	)


func _present_story(ind: int) -> void:
	_mode = Mode.STORY
	_set_cards_visible(false)
	_story_ind = clampi(ind, 0, STORY_COUNT - 1)
	_apply_background_for_story(_story_ind)
	_set_story_text(_story_line(_story_ind))
	if _story_ind == 3:
		_start_gate_open()
	elif _story_ind == 5:
		_start_gate_close()
	_layout()


func _start_questions() -> void:
	## xu4 startQuestions() after showStory.
	_mode = Mode.QUESTIONS
	_gate_phase = GatePhase.NONE
	set_process(false)
	_ensure_card_textures()
	_q_tree.start()
	_show_abacus_bg()
	_show_question_intro()


func _show_abacus_bg() -> void:
	_current_bg = ABACUS_FILE
	_prepare_abacus()
	if _abacus_frame != null and _abacus_base != null:
		_abacus_frame.copy_from(_abacus_base)
		if _abacus_tex == null:
			_abacus_tex = ImageTexture.create_from_image(_abacus_frame)
		else:
			_abacus_tex.update(_abacus_frame)
		_view.texture = _abacus_tex
	else:
		_view.texture = _texture_for("%s/%s" % [DIR, ABACUS_FILE])


func _prepare_abacus() -> void:
	if _abacus_full != null:
		return
	var img := _load_rgba("%s/%s" % [DIR, ABACUS_FILE])
	if img == null:
		return
	_abacus_full = img
	_abacus_base = _picture_band(img)
	if _abacus_base.get_format() != Image.FORMAT_RGBA8:
		_abacus_base.convert(Image.FORMAT_RGBA8)
	_abacus_frame = _abacus_base.duplicate()
	_abacus_tex = ImageTexture.create_from_image(_abacus_frame)


func _draw_abacus_beads(row: int, selected: int, rejected: int) -> void:
	## xu4 drawAbacusBeads — white = chosen, black = rejected.
	if _abacus_full == null or _abacus_frame == null:
		_prepare_abacus()
	if _abacus_full == null or _abacus_frame == null:
		return
	var y := BEAD_POS.y + row * BEAD_CELL.y
	var wx := BEAD_POS.x + selected * BEAD_CELL.x
	var bx := BEAD_POS.x + rejected * BEAD_CELL.x
	_abacus_frame.blend_rect(_abacus_full, WHITE_BEAD, Vector2i(wx, y))
	_abacus_frame.blend_rect(_abacus_full, BLACK_BEAD, Vector2i(bx, y))
	if _abacus_tex == null:
		_abacus_tex = ImageTexture.create_from_image(_abacus_frame)
	else:
		_abacus_tex.update(_abacus_frame)
	_view.texture = _abacus_tex
	_fit_view()


func _show_question_intro() -> void:
	## Exactly 3 lines (xu4 lead / cards / consider) — same font as story.
	_q_phase = QPhase.INTRO
	_set_card_cursor(-1)
	_q_pair = _q_tree.current_pair()
	_place_cards(_q_pair.x, _q_pair.y)
	var body := "%s\n%s\n%s" % [
		Locale.gypsy_lead(_q_tree.question_round),
		Locale.gypsy_cards_line(_q_pair.x, _q_pair.y),
		Locale.t("gypsy_consider"),
	]
	_set_story_text(body)
	_layout()


func _show_question_ask() -> void:
	## Full dilemma; A)/B) already in the question text.
	_q_phase = QPhase.ASK
	_set_card_cursor(-1)
	_q_pair = _q_tree.current_pair()
	var q := Locale.virtue_question(_q_pair.x, _q_pair.y)
	_set_story_text(_format_question(q))
	_layout()


func _answer_question(which: int) -> void:
	## xu4 doQuestion: place beads then advance.
	var pair := _q_tree.current_pair()
	var row := _q_tree.question_round
	var selected: int = pair.x if which == 0 else pair.y
	var rejected: int = pair.y if which == 0 else pair.x
	var done := _q_tree.answer(which)
	_draw_abacus_beads(row, selected, rejected)
	if done:
		GameState.apply_virtue_result(_q_tree.winning_class(), _q_tree.selected_virtues())
		SceneRouter.to_class_reveal()
		return
	_show_question_intro()


func _ensure_card_textures() -> void:
	if _card_tex.size() == 8:
		return
	_card_tex.clear()
	_cards1 = _load_rgba("%s/cards1.png" % DIR)
	_cards2 = _load_rgba("%s/cards2.png" % DIR)
	for v in 8:
		var sheet := _cards1 if v < 4 else _cards2
		var rect: Rect2i = CARD_RECTS[v % 4]
		var piece := sheet.get_region(rect) if sheet else Image.create(1, 1, false, Image.FORMAT_RGBA8)
		_card_tex.append(ImageTexture.create_from_image(piece))


func _load_rgba(path: String) -> Image:
	var img := Image.new()
	if img.load(path) != OK:
		push_error("story_sequence: failed to load %s" % path)
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


func _place_cards(v1: int, v2: int) -> void:
	_ensure_card_textures()
	if v1 >= 0 and v1 < _card_tex.size():
		_card_a.texture = _card_tex[v1]
	if v2 >= 0 and v2 < _card_tex.size():
		_card_b.texture = _card_tex[v2]
	_set_cards_visible(true)
	_layout_cards()


func _set_cards_visible(on: bool) -> void:
	if _card_a:
		_card_a.visible = on
	if _card_b:
		_card_b.visible = on
	if not on:
		_set_card_cursor(-1)


func _set_card_cursor(index: int) -> void:
	_card_cursor = index if index in [0, 1] else -1
	if _card_border_a:
		_card_border_a.visible = _card_a.visible and _card_cursor == 0
	if _card_border_b:
		_card_border_b.visible = _card_b.visible and _card_cursor == 1


func _layout_cards() -> void:
	## Scale card sprites with the 320-wide picture band.
	if _view == null or not _card_a.visible:
		return
	var scale := _view.size.x / 320.0
	var origin := _view.position
	_card_a.position = origin + Vector2(CARD_POS) * scale
	_card_a.size = Vector2(CARD_SIZE) * scale
	_card_b.position = origin + Vector2(CARD_POS.x + CARD_GAP_W, CARD_POS.y) * scale
	_card_b.size = Vector2(CARD_SIZE) * scale
	var border_pad := maxf(float(CARD_BORDER_WIDTH), round(2.0 * scale))
	_card_border_a.position = _card_a.position - Vector2.ONE * border_pad
	_card_border_a.size = _card_a.size + Vector2.ONE * border_pad * 2.0
	_card_border_b.position = _card_b.position - Vector2.ONE * border_pad
	_card_border_b.size = _card_b.size + Vector2.ONE * border_pad * 2.0
	_card_a.move_to_front()
	_card_b.move_to_front()
	_card_border_a.move_to_front()
	_card_border_b.move_to_front()
	if _text:
		_text.move_to_front()


func _story_line(ind: int) -> String:
	var lang := GameState.language
	if lang != "en_u4" and GameState.intro_overlay.has_story(lang, ind):
		return _unwrap_story(GameState.intro_overlay.story(lang, ind))
	var lines: Array = GameState.intro_data.story
	if ind < 0 or ind >= lines.size():
		return "(story text missing — is TITLE.EXE loaded?)"
	return _unwrap_story(str(lines[ind]))


func _unwrap_story(raw: String) -> String:
	var lines := raw.replace("\r\n", "\n").replace("\r", "\n").split("\n", true)
	var paragraphs: PackedStringArray = []
	var buf := ""
	for line in lines:
		var t := str(line).strip_edges()
		if t.is_empty():
			if not buf.is_empty():
				paragraphs.append(buf)
				buf = ""
			continue
		if buf.is_empty():
			buf = t
		else:
			buf += " " + t
	if not buf.is_empty():
		paragraphs.append(buf)
	return "\n\n".join(paragraphs)


func _format_question(raw: String) -> String:
	## Keep A)/B) readable: flow setup into one block, break before B).
	var lines := raw.replace("\r\n", "\n").replace("\r", "\n").split("\n", false)
	var before_b: PackedStringArray = []
	var b_line := ""
	for line in lines:
		var t := str(line).strip_edges()
		if t.is_empty():
			continue
		if b_line.is_empty() and (t.begins_with("B)") or t.begins_with("B）")):
			b_line = t
		else:
			before_b.append(t)
	if before_b.is_empty():
		return b_line if not b_line.is_empty() else _unwrap_story(raw)
	var head := " ".join(before_b)
	if b_line.is_empty():
		return head
	return "%s\n%s" % [head, b_line]


func _set_story_text(s: String) -> void:
	if _text:
		_text.text = s


func _on_language_changed() -> void:
	if _mode == Mode.QUESTIONS:
		if _q_phase == QPhase.ASK:
			_show_question_ask()
		else:
			_show_question_intro()
	else:
		_refresh_story_text()


func _refresh_story_text() -> void:
	_set_story_text(_story_line(_story_ind))
	_fit_text()


func _apply_background_for_story(ind: int) -> void:
	if BG_AT.has(ind):
		var file: String = BG_AT[ind]
		_current_bg = file
		if file == TREE_FILE and ind == 0:
			_prepare_tree_anim()
			_gate_h = 0
			_compose_gate(false)
			_gate_phase = GatePhase.NONE
		elif file == TREE_FILE and ind == 11:
			_gate_phase = GatePhase.NONE
			_view.texture = _texture_for("%s/%s" % [DIR, file])
		else:
			_gate_phase = GatePhase.NONE
			set_process(false)
			_view.texture = _texture_for("%s/%s" % [DIR, file])


func _layout() -> void:
	_fit_view()
	_fit_text()
	_layout_cards()


func _fit_view() -> void:
	if _view == null or _view.texture == null:
		return
	var tw := float(_view.texture.get_width())
	var th := float(_view.texture.get_height())
	if tw < 1.0 or th < 1.0 or size.x < 1.0:
		return
	var scale := size.x / tw
	_view.size = Vector2(size.x, th * scale)
	_view.position = Vector2.ZERO


func _fit_text() -> void:
	if _text == null:
		return
	var top := 0.0
	if _view:
		top = _view.size.y
	var area_w := maxf(size.x - float(TEXT_PAD_L + TEXT_PAD_R), 64.0)
	var area_h := maxf(size.y - top - float(TEXT_PAD_TOP + TEXT_PAD_BOTTOM), 48.0)
	_text.position = Vector2(TEXT_PAD_L, top + TEXT_PAD_TOP)
	_text.size = Vector2(area_w, area_h)
	## Top-aligned inside the padded band (band itself sits a bit below picture).
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.add_theme_constant_override("line_spacing", _line_spacing())

	var font: Font = _text.get_theme_font("font")
	if font == null:
		font = UiTheme.font()
	var best := TEXT_FONT_MIN
	## Story + question screens share one size so the letterbox doesn't jump.
	for sz in range(TEXT_FONT_MAX, TEXT_FONT_MIN - 1, -1):
		if _all_stories_fit(font, sz, area_w, area_h):
			best = sz
			break
	if GameState.language == "ko":
		best = maxi(TEXT_FONT_MIN, int(round(float(best) * KO_FONT_SCALE)))
	else:
		best = maxi(TEXT_FONT_MIN, int(round(float(best) * EN_FONT_SCALE)))
	if _mode == Mode.QUESTIONS and _q_phase == QPhase.ASK:
		## Long dilemmas may still need a slight shrink to stay ≤ 4 lines.
		best = _clamp_font_to_max_lines(font, _text.text, area_w, area_h, best, ASK_MAX_LINES)
	## Keep a little headroom so Label line spacing doesn't clip the last line.
	if not _text_fits(font, _text.text, area_w, area_h * 0.96, best, 0):
		best = _clamp_font_to_max_lines(font, _text.text, area_w, area_h * 0.96, best, 0)
	_text.add_theme_font_size_override("font_size", best)


func _line_spacing() -> int:
	return TEXT_LINE_SPACING_KO if GameState.language == "ko" else TEXT_LINE_SPACING


func _clamp_font_to_max_lines(
	font: Font, s: String, area_w: float, area_h: float, start_sz: int, max_lines: int
) -> int:
	var sz := start_sz
	while sz > TEXT_FONT_MIN and not _text_fits(font, s, area_w, area_h, sz, max_lines):
		sz -= 1
	return sz


func _text_fits(
	font: Font, s: String, area_w: float, area_h: float, font_sz: int, max_lines: int
) -> bool:
	var h := _text_block_height(font, s, area_w, font_sz)
	if h > area_h + 0.5:
		return false
	if max_lines > 0:
		var lines := _text_line_count(font, s, area_w, font_sz)
		if lines > max_lines:
			return false
	return true


func _text_line_count(font: Font, s: String, area_w: float, font_sz: int) -> int:
	var m := font.get_multiline_string_size(
		s, HORIZONTAL_ALIGNMENT_LEFT, int(area_w), font_sz
	)
	var line_h := font.get_height(font_sz)
	if line_h < 1.0:
		return 1
	return maxi(1, int(ceil(m.y / line_h - 0.05)))


func _text_block_height(font: Font, s: String, area_w: float, font_sz: int) -> float:
	## Font metrics + Label line_spacing between lines.
	var m := font.get_multiline_string_size(
		s, HORIZONTAL_ALIGNMENT_LEFT, int(area_w), font_sz
	)
	var lines := _text_line_count(font, s, area_w, font_sz)
	return m.y + float(maxi(0, lines - 1) * _line_spacing())


func _all_stories_fit(font: Font, font_sz: int, area_w: float, area_h: float) -> bool:
	for i in STORY_COUNT:
		var s := _story_line(i)
		if s.is_empty() or s.begins_with("(story text missing"):
			continue
		if _text_block_height(font, s, area_w, font_sz) > area_h + 0.5:
			return false
	return true


func _texture_for(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path] as Texture2D
	var img := Image.new()
	if img.load(path) != OK:
		push_error("story_sequence: failed to load %s" % path)
		var empty := ImageTexture.new()
		_cache[path] = empty
		return empty
	var band := _picture_band(img)
	var tex := ImageTexture.create_from_image(band)
	_cache[path] = tex
	return tex


func _picture_band(src: Image) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var band_h := mini(PIC_H, h)
	return src.get_region(Rect2i(0, 0, w, band_h))


func _prepare_tree_anim() -> void:
	if _tree_full != null:
		_view.texture = _tree_tex
		return
	var path := "%s/%s" % [DIR, TREE_FILE]
	var img := Image.new()
	if img.load(path) != OK:
		push_error("story_sequence: failed to load tree for moongate")
		return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	_tree_full = img
	_tree_base = _picture_band(img)
	if _tree_base.get_format() != Image.FORMAT_RGBA8:
		_tree_base.convert(Image.FORMAT_RGBA8)
	_tree_frame = _tree_base.duplicate()
	_tree_tex = ImageTexture.create_from_image(_tree_frame)
	_view.texture = _tree_tex


func _start_gate_open() -> void:
	if _tree_full == null:
		_prepare_tree_anim()
	if _tree_full == null:
		_gate_phase = GatePhase.IDLE
		return
	_gate_phase = GatePhase.OPENING
	_gate_h = 1
	_gate_t = 0.0
	_compose_gate(false)
	set_process(true)


func _start_gate_close() -> void:
	if _tree_full == null:
		_gate_phase = GatePhase.IDLE
		return
	_gate_phase = GatePhase.CLOSING
	_gate_h = maxi(MOONGATE.size.y - 1, 0)
	_gate_t = 0.0
	_compose_gate(true)
	set_process(true)


func _step_gate() -> bool:
	if _gate_phase == GatePhase.OPENING:
		_gate_h += 1
		if _gate_h >= MOONGATE.size.y:
			_gate_h = MOONGATE.size.y
			_compose_gate(false)
			_gate_phase = GatePhase.OPEN
			set_process(false)
			return false
		_compose_gate(false)
		return true
	if _gate_phase == GatePhase.CLOSING:
		_gate_h -= 1
		if _gate_h <= 0:
			_gate_h = 0
			_compose_gate(true)
			_gate_phase = GatePhase.IDLE
			set_process(false)
			return false
		_compose_gate(true)
		return true
	return false


func _compose_gate(draw_items: bool) -> void:
	if _tree_base == null or _tree_full == null or _tree_frame == null:
		return
	_tree_frame.copy_from(_tree_base)
	var gh := clampi(_gate_h, 0, MOONGATE.size.y)
	if draw_items:
		_tree_frame.blit_rect(_tree_full, ITEMS, GATE_POS)
	if gh > 0:
		var src := Rect2i(MOONGATE.position, Vector2i(MOONGATE.size.x, gh))
		var dst := Vector2i(GATE_POS.x, GATE_POS.y + MOONGATE.size.y - gh)
		_tree_frame.blit_rect(_tree_full, src, dst)
	if _tree_tex == null:
		_tree_tex = ImageTexture.create_from_image(_tree_frame)
	else:
		_tree_tex.update(_tree_frame)
	_view.texture = _tree_tex
	_fit_view()
	_fit_text()
