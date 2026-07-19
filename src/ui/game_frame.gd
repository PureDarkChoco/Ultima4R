extends Control

## Right-side chrome only (status + message). Map area on the left has no frame.

signal layout_changed(map_rect: Rect2)

const FRAME := 16
const TRIM := 2
## Map takes leftover width after a fixed right panel fraction.
const RIGHT_FRAC := 0.30

@onready var _status: ColorRect = %StatusPanel
@onready var _scroll: ColorRect = %ScrollPanel
@onready var _status_label: Label = %StatusPlaceholder
@onready var _scroll_label: Label = %ScrollPlaceholder
@onready var _status_frame: Control = %StatusFrame
@onready var _scroll_frame: Control = %ScrollFrame

var _map_rect := Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.color = U6FrameStyle.STONE
	_scroll.color = U6FrameStyle.SCROLL_PAPER
	for lab in [_status_label, _scroll_label]:
		lab.add_theme_color_override("font_color", U6FrameStyle.GOLD_DIM)
		lab.add_theme_font_size_override("font_size", 14)
	resized.connect(_on_resized)
	call_deferred("_on_resized")


func get_map_rect() -> Rect2:
	return _map_rect


func get_scroll_rect() -> Rect2:
	return _scroll.get_global_rect()


func get_status_rect() -> Rect2:
	return _status.get_global_rect()


func _on_resized() -> void:
	_layout()
	layout_changed.emit(_map_rect)


func _layout() -> void:
	var vr := size
	if vr.x < 8.0 or vr.y < 8.0:
		return

	var right_w := vr.x * RIGHT_FRAC
	right_w = clampf(right_w, 220.0, vr.x * 0.40)
	var map_w := vr.x - right_w
	_map_rect = Rect2(0, 0, map_w, vr.y)

	var status_h := vr.y * 0.42
	_status.position = Vector2(map_w + FRAME, FRAME)
	_status.size = Vector2(right_w - FRAME * 2, status_h - FRAME * 1.5)
	_scroll.position = Vector2(map_w + FRAME, status_h + FRAME * 0.5)
	_scroll.size = Vector2(right_w - FRAME * 2, vr.y - status_h - FRAME * 1.5)

	_rebuild_side_frames(map_w, right_w, vr.y, status_h)

	_status_label.position = Vector2(12, 10)
	_status_label.size = Vector2(_status.size.x - 24, 28)
	_scroll_label.position = Vector2(12, 10)
	_scroll_label.size = Vector2(_scroll.size.x - 24, 28)
	_status_label.text = "Status"
	_scroll_label.text = "Message"


func _rebuild_side_frames(map_w: float, right_w: float, full_h: float, status_h: float) -> void:
	for node in [_status_frame, _scroll_frame]:
		for c in node.get_children():
			c.queue_free()

	# Outer panel background behind framed controls
	_status_frame.position = Vector2(map_w, 0)
	_status_frame.size = Vector2(right_w, status_h)
	_scroll_frame.position = Vector2(map_w, status_h)
	_scroll_frame.size = Vector2(right_w, full_h - status_h)
	_status_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_paint_wood_border(_status_frame)
	_paint_wood_border(_scroll_frame)


func _paint_wood_border(panel: Control) -> void:
	var w := int(panel.size.x)
	var h := int(panel.size.y)
	var t := FRAME
	if w < t * 2 or h < t * 2:
		return
	# Back fill
	var back := ColorRect.new()
	back.color = U6FrameStyle.WOOD_DARK
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.position = Vector2.ZERO
	back.size = panel.size
	panel.add_child(back)
	panel.move_child(back, 0)

	_add_tex(panel, U6FrameStyle.make_wood_strip(true, w, t), Vector2(0, 0))
	_add_tex(panel, U6FrameStyle.make_wood_strip(true, w, t), Vector2(0, h - t))
	_add_tex(panel, U6FrameStyle.make_wood_strip(false, h - 2 * t, t), Vector2(0, t))
	_add_tex(panel, U6FrameStyle.make_wood_strip(false, h - 2 * t, t), Vector2(w - t, t))
	# Gold inner trim
	var inner_w := w - 2 * t
	var inner_h := h - 2 * t
	_add_tex(panel, U6FrameStyle.make_inner_trim(true, inner_w, TRIM), Vector2(t, t))
	_add_tex(panel, U6FrameStyle.make_inner_trim(true, inner_w, TRIM), Vector2(t, h - t - TRIM))
	_add_tex(panel, U6FrameStyle.make_inner_trim(false, inner_h, TRIM), Vector2(t, t))
	_add_tex(panel, U6FrameStyle.make_inner_trim(false, inner_h, TRIM), Vector2(w - t - TRIM, t))


func _add_tex(parent: Control, tex: Texture2D, pos: Vector2) -> void:
	var r := TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = pos
	r.size = tex.get_size()
	parent.add_child(r)
