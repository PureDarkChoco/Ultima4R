class_name LocateMapOverlay
extends Control

## Locate (L): stylized Britannia chart derived 1:1 from WORLD.MAP (incl. Abyss).

signal closed

const MAP_PATH := "res://assets/ui/locate/britannia_world.png"
const MAP_BASE_PATH := "res://assets/ui/locate/britannia_world_base.png"
const MAP_ABYSS_PATH := "res://assets/ui/locate/britannia_world_base_abyss.png"
const WORLD_W := 256
const WORLD_H := 256
const _LocateChart := preload("res://src/map/locate_chart.gd")
## Full texture = full world (no decorative letterboxing).
const WORLD_UV := Rect2(0.0, 0.0, 1.0, 1.0)
const MAP_DIM := Color(0.0, 0.0, 0.0, 0.5)
const BORDER_W := 2
const PANEL_PAD := 4
const MAX_FRAC := 0.92
const MARK_COLOR := Color(0.95, 0.22, 0.18, 1.0)
const MARK_RING := Color(1.0, 0.95, 0.75, 0.95)
const MARK_RADIUS := 7.0
const COORD_INSET := Vector2(10, 10)
const COORD_FONT_SIZE := 15
const COORD_COLOR := Color(0.95, 0.93, 0.82, 1.0)
const COORD_SHADOW := Color(0.0, 0.0, 0.0, 0.75)
## Extra lift when ship pin overlaps the SW coord readout.
const COORD_SHIP_LIFT := 28.0

var _dim: ColorRect
var _panel: Panel
var _tex_rect: TextureRect
var _specials: Control
var _mark: Control
var _coord_label: Label
var _open := false
var _world_pos := Vector2i.ZERO
var _sextant_text := ""
var _lift_coords_if_overlap := false
var _detail_img: Image
var _base_img: Image
var _abyss_img: Image
var _chart_tex: ImageTexture
var _special_marks: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func is_open() -> bool:
	return _open


func open_locate(
	world_pos: Vector2i,
	sextant_text: String = "",
	lift_coords_if_overlap: bool = false,
	world = null
) -> void:
	_world_pos = Vector2i(
		clampi(world_pos.x, 0, WORLD_W - 1),
		clampi(world_pos.y, 0, WORLD_H - 1)
	)
	_sextant_text = sextant_text.strip_edges()
	_lift_coords_if_overlap = lift_coords_if_overlap
	_rebuild_chart(world)
	_open = true
	visible = true
	move_to_front()
	_layout_panel()
	_place_specials()
	_place_mark()
	_place_coords()


func close_locate() -> void:
	if not _open:
		return
	_open = false
	visible = false
	if _coord_label != null:
		_coord_label.visible = false
	closed.emit()


func _build() -> void:
	_dim = ColorRect.new()
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.color = MAP_DIM
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_panel = Panel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.05, 1)
	sb.border_color = UiTheme.FOCUS_BORDER
	sb.border_width_left = BORDER_W
	sb.border_width_top = BORDER_W
	sb.border_width_right = BORDER_W
	sb.border_width_bottom = BORDER_W
	sb.set_corner_radius_all(0)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	_tex_rect = TextureRect.new()
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex := load(MAP_PATH) as Texture2D
	if tex != null:
		_tex_rect.texture = tex
	_panel.add_child(_tex_rect)

	_specials = Control.new()
	_specials.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_specials.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_specials.draw.connect(_draw_specials)
	_panel.add_child(_specials)

	_mark = Control.new()
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.draw.connect(_draw_mark)
	_panel.add_child(_mark)

	_coord_label = Label.new()
	_coord_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coord_label.visible = false
	_coord_label.add_theme_font_size_override("font_size", COORD_FONT_SIZE)
	_coord_label.add_theme_color_override("font_color", COORD_COLOR)
	_coord_label.add_theme_color_override("font_shadow_color", COORD_SHADOW)
	_coord_label.add_theme_constant_override("shadow_offset_x", 1)
	_coord_label.add_theme_constant_override("shadow_offset_y", 1)
	UiTheme.apply_font(_coord_label)
	_panel.add_child(_coord_label)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _open:
		_layout_panel()
		_place_specials()
		_place_mark()
		_place_coords()


func _layout_panel() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var side := minf(size.x, size.y) * MAX_FRAC
	side = floorf(side)
	var px := floorf((size.x - side) * 0.5)
	var py := floorf((size.y - side) * 0.5)
	_panel.position = Vector2(px, py)
	_panel.size = Vector2(side, side)
	var inner := side - float(BORDER_W) * 2.0 - float(PANEL_PAD) * 2.0
	_tex_rect.position = Vector2(BORDER_W + PANEL_PAD, BORDER_W + PANEL_PAD)
	_tex_rect.size = Vector2(inner, inner)


func _map_draw_rect() -> Rect2:
	var tr := _tex_rect
	if tr == null or tr.texture == null:
		return Rect2()
	var tw := float(tr.texture.get_width())
	var th := float(tr.texture.get_height())
	if tw < 1.0 or th < 1.0 or tr.size.x < 1.0 or tr.size.y < 1.0:
		return Rect2()
	var scale := minf(tr.size.x / tw, tr.size.y / th)
	var dw := tw * scale
	var dh := th * scale
	var ox := tr.position.x + (tr.size.x - dw) * 0.5
	var oy := tr.position.y + (tr.size.y - dh) * 0.5
	return Rect2(ox, oy, dw, dh)


func _ensure_source_images() -> void:
	if _detail_img == null:
		var dtex := load(MAP_PATH) as Texture2D
		if dtex != null:
			_detail_img = dtex.get_image()
	if _base_img == null:
		var btex := load(MAP_BASE_PATH) as Texture2D
		if btex != null:
			_base_img = btex.get_image()
	if _abyss_img == null:
		var atex := load(MAP_ABYSS_PATH) as Texture2D
		if atex != null:
			_abyss_img = atex.get_image()


func _rebuild_chart(world) -> void:
	_ensure_source_images()
	if _detail_img == null or _base_img == null:
		return
	if _chart_tex != null and not GameState.locate_chart_dirty:
		if _tex_rect != null:
			_tex_rect.texture = _chart_tex
		_collect_specials(world)
		return
	var w := _detail_img.get_width()
	var h := _detail_img.get_height()
	if _base_img.get_width() != w or _base_img.get_height() != h:
		_base_img.resize(w, h, Image.INTERPOLATE_NEAREST)
	var scale := maxi(1, w / WORLD_W)
	var out := _base_img.duplicate()
	if world != null and bool(world.loaded):
		_LocateChart.ensure_secret_masks(world)
	var found_abyss := GameState.locate_found_abyss
	var found_skull := GameState.locate_found_skull
	var found_bell := GameState.locate_found_bell
	if found_abyss and _abyss_img != null:
		if _abyss_img.get_width() != w or _abyss_img.get_height() != h:
			_abyss_img.resize(w, h, Image.INTERPOLATE_NEAREST)
		var box := _LocateChart.abyss_outline_rect()
		if box.size.x > 0 and box.size.y > 0:
			var pr := Rect2i(box.position * scale, box.size * scale)
			out.blit_rect(_abyss_img, pr, pr.position)
	var land_fill := Color8(148, 144, 132)
	for y in WORLD_H:
		for x in WORLD_W:
			var secret := _LocateChart.is_secret_hidden(
				x, y, found_abyss, found_skull, found_bell
			)
			if secret:
				continue
			var r := Rect2i(x * scale, y * scale, scale, scale)
			if _LocateChart.is_explored(GameState.locate_explored, x, y):
				out.blit_rect(_detail_img, r, r.position)
				continue
			if world == null or not bool(world.loaded):
				continue
			if int(world.tile_at(x, y)) <= 2:
				continue
			## Skull / bell shoals: land outline only after find (Abyss uses the layer above).
			if _LocateChart.is_secret_skull(x, y) or _LocateChart.is_secret_bell(x, y):
				out.fill_rect(r, land_fill)
	if _chart_tex == null:
		_chart_tex = ImageTexture.create_from_image(out)
	else:
		_chart_tex.update(out)
	if _tex_rect != null:
		_tex_rect.texture = _chart_tex
	GameState.locate_chart_dirty = false
	_collect_specials(world)


func _collect_specials(world) -> void:
	_special_marks.clear()
	if world == null or not bool(world.loaded):
		return
	_LocateChart.ensure_secret_masks(world)
	if GameState.locate_found_skull:
		_special_marks.append({"pos": _LocateChart.SKULL, "kind": "skull"})
	if GameState.locate_found_bell:
		_special_marks.append({"pos": _LocateChart.BELL, "kind": "bell"})
	for y in WORLD_H:
		for x in WORLD_W:
			if not _LocateChart.is_explored(GameState.locate_explored, x, y):
				continue
			if _LocateChart.is_secret_hidden(
				x, y,
				GameState.locate_found_abyss,
				GameState.locate_found_skull,
				GameState.locate_found_bell
			):
				continue
			var pos := Vector2i(x, y)
			var tid := int(world.tile_at(x, y))
			if _LocateChart.is_dungeon_entrance(tid, pos):
				_special_marks.append({"pos": pos, "kind": "dungeon"})
			elif _LocateChart.is_shrine_entrance(tid, pos):
				_special_marks.append({"pos": pos, "kind": "shrine"})


func _place_specials() -> void:
	if _specials == null:
		return
	_specials.position = Vector2.ZERO
	_specials.size = _panel.size
	_specials.queue_redraw()
	_specials.move_to_front()


func _draw_specials() -> void:
	if _specials == null:
		return
	for rec in _special_marks:
		var p: Vector2i = rec.get("pos", Vector2i.ZERO)
		var kind := str(rec.get("kind", ""))
		var c := _world_to_panel(p)
		match kind:
			"dungeon":
				_specials.draw_circle(c, 4.5, Color(0.12, 0.08, 0.1, 1))
				_specials.draw_circle(c, 2.2, Color(0.35, 0.12, 0.18, 1))
			"shrine":
				_specials.draw_circle(c, 4.2, Color(0.55, 0.42, 0.18, 1))
				_specials.draw_circle(c, 2.4, Color(0.95, 0.9, 0.7, 1))
			"skull":
				_specials.draw_circle(c, 5.0, Color(0.15, 0.12, 0.12, 1))
				_specials.draw_circle(c, 2.4, Color(0.75, 0.72, 0.68, 1))
			"bell":
				_specials.draw_circle(c, 4.5, Color(0.45, 0.32, 0.1, 1))
				_specials.draw_circle(c, 2.4, Color(0.92, 0.78, 0.28, 1))


func _world_to_panel(pos: Vector2i) -> Vector2:
	var draw := _map_draw_rect()
	if draw.size.x < 1.0:
		return Vector2.ZERO
	var u := (float(pos.x) + 0.5) / float(WORLD_W)
	var v := (float(pos.y) + 0.5) / float(WORLD_H)
	return Vector2(
		draw.position.x + (WORLD_UV.position.x + WORLD_UV.size.x * u) * draw.size.x,
		draw.position.y + (WORLD_UV.position.y + WORLD_UV.size.y * v) * draw.size.y
	)


func _place_mark() -> void:
	if _mark == null:
		return
	var c := _world_to_panel(_world_pos)
	var span := MARK_RADIUS * 2.0 + 4.0
	_mark.position = c - Vector2(span * 0.5, span * 0.5)
	_mark.size = Vector2(span, span)
	_mark.queue_redraw()
	_mark.move_to_front()


func _place_coords() -> void:
	if _coord_label == null:
		return
	if _sextant_text.is_empty():
		_coord_label.visible = false
		return
	_coord_label.text = _sextant_text
	_coord_label.visible = true
	_coord_label.reset_size()
	var draw := _map_draw_rect()
	if draw.size.x < 1.0:
		draw = Rect2(
			_tex_rect.position,
			_tex_rect.size
		)
	var text_sz := _coord_label.get_minimum_size()
	var pos := Vector2(
		draw.position.x + COORD_INSET.x,
		draw.position.y + draw.size.y - text_sz.y - COORD_INSET.y
	)
	if _lift_coords_if_overlap and _mark != null:
		var coord_rect := Rect2(pos, text_sz).grow(4.0)
		var mark_rect := Rect2(_mark.position, _mark.size).grow(2.0)
		if coord_rect.intersects(mark_rect):
			pos.y = mark_rect.position.y - text_sz.y - 8.0
			## Keep inside the map draw area.
			pos.y = maxf(draw.position.y + COORD_INSET.y, pos.y)
	_coord_label.position = pos
	_coord_label.move_to_front()


func _draw_mark() -> void:
	if _mark == null:
		return
	var c := _mark.size * 0.5
	_mark.draw_circle(c, MARK_RADIUS + 1.5, MARK_RING)
	_mark.draw_circle(c, MARK_RADIUS, MARK_COLOR)
	_mark.draw_circle(c, 2.0, Color(1, 1, 1, 0.95))
