extends Control

@onready var _round: Label = %Round
@onready var _lead: Label = %Lead
@onready var _cards: Label = %Cards
@onready var _question: Label = %Question
@onready var _btn_a: Button = %ChoiceA
@onready var _btn_b: Button = %ChoiceB
@onready var _back: Button = %Back
@onready var _hint: Label = %Hint
@onready var _scroll: ScrollContainer = %QuestionScroll

var _tree := VirtueQuestionTree.new()
var _pair := Vector2i.ZERO
var _done: bool = false


func _ready() -> void:
	UiTheme.apply_root(self)
	$ColorRect.color = UiTheme.BG
	%Panel.add_theme_stylebox_override("panel", UiTheme.make_panel())

	UiTheme.style_label(_round, 14, UiTheme.MUTED)
	UiTheme.style_label(_lead, 16, UiTheme.MUTED)
	UiTheme.style_label(_cards, 18, UiTheme.ACCENT)
	UiTheme.style_label(_question, 17, UiTheme.TEXT)
	UiTheme.style_label(_hint, 13, UiTheme.MUTED)
	UiTheme.style_button(_btn_a)
	UiTheme.style_button(_btn_b)
	UiTheme.style_button(_back)

	for b in [_btn_a, _btn_b, _back]:
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_btn_a.focus_neighbor_left = _btn_a.get_path_to(_btn_b)
	_btn_a.focus_neighbor_right = _btn_a.get_path_to(_btn_b)
	_btn_a.focus_neighbor_bottom = _btn_a.get_path_to(_back)
	_btn_b.focus_neighbor_left = _btn_b.get_path_to(_btn_a)
	_btn_b.focus_neighbor_right = _btn_b.get_path_to(_btn_a)
	_btn_b.focus_neighbor_bottom = _btn_b.get_path_to(_back)
	_back.focus_neighbor_top = _back.get_path_to(_btn_a)

	_btn_a.pressed.connect(func() -> void: _choose(0))
	_btn_b.pressed.connect(func() -> void: _choose(1))
	_back.pressed.connect(func() -> void: SceneRouter.to_menu())

	GameState.language_changed.connect(func(_l: String) -> void: _refresh())

	if not GameState.intro_data.loaded:
		_hint.text = "TITLE.EXE not loaded — using stub questions"
		_hint.add_theme_color_override("font_color", UiTheme.DANGER)

	_tree.start()
	_refresh()
	_btn_a.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("cancel"):
		SceneRouter.to_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("choice_a"):
		_choose(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("choice_b"):
		_choose(1)
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if _done:
		return
	_pair = _tree.current_pair()
	_round.text = Locale.t("round_of", [_tree.question_round + 1])
	_lead.text = Locale.gypsy_lead(_tree.question_round)
	_cards.text = Locale.gypsy_cards_line(_pair.x, _pair.y)
	_question.text = "%s\n\n%s" % [
		Locale.t("gypsy_consider"),
		Locale.virtue_question(_pair.x, _pair.y),
	]
	_btn_a.text = Locale.virtue_choice_label("A", _pair.x)
	_btn_b.text = Locale.virtue_choice_label("B", _pair.y)
	_back.text = Locale.t("back")
	if GameState.intro_data.loaded:
		_hint.text = Locale.t("input_hint_virtue")
	# Keep long original text readable.
	_scroll.scroll_vertical = 0


func _choose(which: int) -> void:
	if _done:
		return
	_done = _tree.answer(which)
	if _done:
		GameState.apply_virtue_result(_tree.winning_class(), _tree.selected_virtues())
		SceneRouter.to_class_reveal()
	else:
		_refresh()
		_btn_a.grab_focus()
