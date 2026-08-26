extends Control

signal choice_requested(index: int)

const _UiTheme := preload("res://src/core/ui_theme.gd")
const COUNT := 8

var _selected := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE
	queue_redraw()


func set_selected(index: int) -> void:
	var next := clampi(index, 0, COUNT - 1)
	if next == _selected:
		return
	_selected = next
	queue_redraw()


func _draw() -> void:
	var cell_w := size.x / float(COUNT)
	if cell_w <= 0.0 or size.y <= 0.0:
		return
	var font := _UiTheme.font()
	var font_size := clampi(int(floorf(size.y)) - 4, 8, 11)
	for i in COUNT:
		var rect := Rect2(float(i) * cell_w, 0.0, cell_w, size.y)
		var active := i == _selected
		draw_rect(
			rect,
			Color("1a3548") if active else _UiTheme.BG_PANEL,
			true
		)
		draw_rect(
			rect.grow(-0.5),
			_UiTheme.SELECT if active else _UiTheme.BORDER,
			false,
			1.0
		)
		if font == null:
			continue
		var text := str(i + 1)
		var text_size := font.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		)
		var text_pos := Vector2(
			rect.position.x + (rect.size.x - text_size.x) * 0.5,
			rect.position.y + (rect.size.y + text_size.y) * 0.5 - 1.0
		)
		draw_string(
			font,
			text_pos,
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			_UiTheme.SELECT if active else _UiTheme.TEXT
		)


func _gui_input(event: InputEvent) -> void:
	if not (
		event is InputEventMouseButton
		and event.pressed
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	):
		return
	var cell_w := size.x / float(COUNT)
	if cell_w <= 0.0:
		return
	var index := clampi(
		int(floorf((event as InputEventMouseButton).position.x / cell_w)),
		0,
		COUNT - 1
	)
	_selected = index
	queue_redraw()
	choice_requested.emit(index)
	accept_event()
