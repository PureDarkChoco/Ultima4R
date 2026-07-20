extends Control

## Explore: top/bottom status bars + fixed 25×11 map.
## Message terminal: fixed 15-line grid (even pitch). Tab opens all 15;
## closed clips to the bottom 5 at the same pitch. Last line is always
## Ultima-style prompt + blue charset @ cursor animation (bottom-aligned history).

@onready var _top_bar: Control = %TopBar
@onready var _bottom_bar: Control = %BottomBar
@onready var _map_pane: Control = $RootCol/MapPane
@onready var _map: MapView = $RootCol/MapPane/MapView
@onready var _left_pane: Control = %LeftPane
@onready var _right_top: Control = %RightTopPane
@onready var _right_bottom: Control = %RightBottomPane
@onready var _compact_pane: Control = %CompactPane
@onready var _roster: PartyRoster = %PartyRoster
@onready var _compact_roster: PartyRoster = %CompactRoster
@onready var _msg_block: Control = %MsgBlock

var _peer_overlay: PeerGemOverlay

const MOVE_HOLD_DELAY := 0.5
const MOVE_HOLD_INTERVAL := 0.1
const MSG_PROMPT := "► "
const MSG_KEEP := 64
const MSG_OPEN_LINES := 15
const MSG_CLOSED_LINES := 5
const MSG_INSET_X := 8
const MSG_INSET_Y := 6
const MSG_FONT_SIZE := 14
const MSG_COLOR := Color(0.91, 0.9, 0.82, 1)
const CHARSET_PATH := "res://assets/tiles/u4graphics/charset.png"
const CHARSET_GLYPH := 16
## charset.png: blue spinning @ frames (after moon glyphs 20..27).
const CURSOR_CHAR0 := 28
const CURSOR_FRAME_COUNT := 4
const CURSOR_FRAME_SEC := 0.34
## Slight lift on the charset blue @ so it reads better on the navy panel.
const CURSOR_BRIGHTEN := 1.45
const CURSOR_BRIGHTEN_ADD := 0.12
const LAYOUT_UNITS := 13.0
const BAR_UNITS := 0.5
const SIDE_TWEEN_SEC := 0.18
const RIGHT_TOP_TILES := 5
const COMPACT_RIGHT_TILES := 2

var _world := WorldMapData.new()
var _tile_pos := Vector2i(83, 105)
var _move_cd := 0.0
var _hold_arm := 0.0
var _move_repeating := false
var _held_dir := Vector2i.ZERO
var _pending_cmd: int = U4Commands.Id.NONE
## Label shown while waiting on the same line: "Attack: Dir?" (xu4 style).
var _pending_cmd_name: String = ""
## After a directed command fires, ignore held direction until all dir keys up.
var _block_dir_until_keyup := false
var _load_error: String = ""
var _esc_held := false
var _msg_lines: PackedStringArray = PackedStringArray()
var _sides_open := false
var _side_tween: Tween
## Locked message panel geometry (visible size — grows on Tab).
var _msg_h := 0.0
var _msg_full_h := 0.0
var _msg_rw := 0.0
var _msg_open_x := 0.0
var _msg_pitch := 0.0
var _msg_open_content_h := 0.0
var _msg_rows: Array[Label] = []
var _msg_prompt_row: Control
var _msg_prompt_label: Label
var _msg_cursor: TextureRect
var _cursor_frames: Array[Texture2D] = []
var _cursor_frame := 0
var _cursor_t := 0.0
var _msg_ui_ready := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_fit_explore_map)
	_style_bars()
	_style_side_panels()
	_sides_open = false
	_ensure_msg_terminal()
	_ensure_peer_overlay()
	if _compact_roster:
		_compact_roster.set_compact(true)
	if _roster:
		_roster.set_compact(false)
	## Stub: party of 4 for layout checks.
	GameState.refresh_party_order()
	if GameState.party_order.size() > 4:
		GameState.party_order.resize(4)

	var atlas := _load_atlas()
	var path := _resolve_world_map_path()

	if atlas == null:
		_load_error = "shapes.png 로드 실패"
	elif not _world.load_from_path(path):
		_load_error = "WORLD.MAP 로드 실패\n%s" % path
	else:
		_tile_pos = GameState.start_pos if GameState.start_pos != Vector2i.ZERO else Vector2i(83, 105)
		_map.setup(_world, atlas)
		_map.set_center(_tile_pos)

	call_deferred("_fit_explore_map")
	call_deferred("grab_focus")
	if not _load_error.is_empty():
		_push_message(_load_error)
		push_error(_load_error)
	else:
		_refresh_party()


func _load_atlas() -> Texture2D:
	var atlas_path := "res://assets/tiles/u4graphics/shapes.png"
	var tex := load(atlas_path) as Texture2D
	if tex != null:
		return tex
	var img := Image.new()
	if img.load(atlas_path) == OK:
		return ImageTexture.create_from_image(img)
	return null


func _resolve_world_map_path() -> String:
	var candidates: Array[String] = [
		GameState.u4_data_path.path_join("WORLD.MAP"),
		GameState.U4_DATA_ABS.path_join("WORLD.MAP"),
		"/Applications/Ultima IV™.app/Contents/Resources/game/WORLD.MAP",
	]
	for path in candidates:
		if FileAccess.file_exists(path):
			var bytes := FileAccess.get_file_as_bytes(path)
			if bytes.size() == WorldMapData.WIDTH * WorldMapData.HEIGHT:
				return path
	return candidates[0]


func _fit_explore_map() -> void:
	var avail := size
	if avail.x < 32.0 or avail.y < 32.0:
		return
	var unit := avail.y / LAYOUT_UNITS
	var bar_h := maxf(floorf(unit * BAR_UNITS), 16.0)
	var map_h := maxf(floorf(avail.y - bar_h * 2.0), 200.0)
	if _top_bar:
		_top_bar.custom_minimum_size = Vector2(0, bar_h)
		_top_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if _bottom_bar:
		_bottom_bar.custom_minimum_size = Vector2(0, bar_h)
		_bottom_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_map_pane.custom_minimum_size = Vector2(0, map_h)
	call_deferred("_fit_map_tiles_and_sides")


func _fit_map_tiles_and_sides() -> void:
	if _map == null or _map_pane == null:
		return
	var map_sz := _map_pane.size
	if map_sz.x < 32.0 or map_sz.y < 32.0:
		return
	_map.set_view_tiles(MapView.VIEW_W, MapView.VIEW_H)
	_layout_side_panels(false)
	_refresh_message_view()


func _style_bars() -> void:
	pass


func _style_side_panels() -> void:
	if _left_pane is PanelContainer:
		(_left_pane as PanelContainer).add_theme_stylebox_override(
			"panel", _make_edge_panel(4, 0, 0, 2, 0)
		)
	if _right_top is PanelContainer:
		## Open panel chrome (reference): style pad + MarginContainer pad.
		(_right_top as PanelContainer).add_theme_stylebox_override(
			"panel", _make_edge_panel(PartyRoster.ROSTER_STYLE_PAD, 2, 0, 0, 0)
		)
	if _right_bottom is Panel:
		(_right_bottom as Panel).add_theme_stylebox_override(
			"panel", _make_edge_panel(0, 2, 2, 0, 0)
		)
	if _compact_pane is Panel:
		## No style content pad — compact roster offsets use full ROSTER_PAD.
		(_compact_pane as Panel).add_theme_stylebox_override(
			"panel", _make_edge_panel(0, 2, 0, 0, 0)
		)
	var top_margin := get_node_or_null("RootCol/MapPane/RightTopPane/RightTopMargin") as MarginContainer
	if _roster and top_margin:
		_roster.apply_shared_pad_to_margins(top_margin)
	if _compact_roster:
		_compact_roster.apply_pad_offsets()


func _make_edge_panel(
	content_margin: int,
	border_l: int,
	border_t: int,
	border_r: int,
	border_b: int
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.06, 0.28, 1)
	sb.border_color = Color(0.35, 0.55, 0.95, 1)
	sb.border_width_left = border_l
	sb.border_width_top = border_t
	sb.border_width_right = border_r
	sb.border_width_bottom = border_b
	sb.set_corner_radius_all(0)
	sb.content_margin_left = content_margin
	sb.content_margin_right = content_margin
	sb.content_margin_top = content_margin
	sb.content_margin_bottom = content_margin
	return sb


func _side_geom() -> Dictionary:
	var pane_sz := _map_pane.size
	if pane_sz.x < 1.0 or pane_sz.y < 1.0:
		pane_sz = _map_pane.get_rect().size
	var tile_w := 0.0
	var tile_size := Vector2.ZERO
	if _map:
		tile_size = _map.displayed_tile_size()
		tile_w = tile_size.x
	if tile_w < 1.0:
		tile_w = pane_sz.x / float(MapView.VIEW_W)
		tile_size = Vector2(tile_w, pane_sz.y / float(MapView.VIEW_H))
	if _compact_roster:
		_compact_roster.set_tile_size(tile_size)
	if _roster:
		_roster.set_tile_size(tile_size)
	var tile_h := tile_size.y
	var center_w := float(MapView.VIEW_H) * tile_w
	var overflow := maxf(pane_sz.x - center_w, 0.0)
	var left_w := floorf(overflow * 0.5)
	var right_w := overflow - left_w
	var compact_w := float(ceili(float(COMPACT_RIGHT_TILES) * tile_w))
	## Floor tile multiples so y + h never exceeds pane (avoids MapPane clip).
	var top_h := floorf(float(RIGHT_TOP_TILES) * tile_h)
	var bottom_open_h := pane_sz.y - top_h
	## Closed height = bottom 5/15 of the open content at the same line pitch.
	var open_content := maxf(bottom_open_h - float(MSG_INSET_Y * 2), float(MSG_OPEN_LINES))
	var pitch := open_content / float(MSG_OPEN_LINES)
	var bottom_closed_h := floorf(float(MSG_INSET_Y * 2) + pitch * float(MSG_CLOSED_LINES))
	bottom_closed_h = clampf(bottom_closed_h, 24.0, bottom_open_h)
	var bottom_closed_y := pane_sz.y - bottom_closed_h
	## Compact height = top n slots of the open panel's 8-slot vertical grid.
	if _compact_roster:
		_compact_roster.set_open_panel_height(top_h)
	if _roster:
		_roster.set_open_panel_height(top_h)
	var party_n := clampi(GameState.party_size(), 1, 8)
	var compact_h := top_h
	if _compact_roster:
		compact_h = _compact_roster.compact_panel_height(party_n)
	if party_n >= 8:
		compact_h = top_h
	return {
		"pane_w": pane_sz.x,
		"pane_h": pane_sz.y,
		"tile_h": tile_h,
		"left_w": left_w,
		"right_w": right_w,
		"compact_w": compact_w,
		"compact_h": compact_h,
		"compact_x": pane_sz.x - compact_w,
		"top_h": top_h,
		"bottom_closed_h": bottom_closed_h,
		"bottom_open_h": bottom_open_h,
		"left_open_x": 0.0,
		"left_closed_x": -left_w,
		"right_open_x": pane_sz.x - right_w,
		"right_closed_x": pane_sz.x,
		"bottom_open_y": top_h,
		"bottom_closed_y": bottom_closed_y,
	}


func _pin_right_bottom(pos: Vector2, sz: Vector2) -> void:
	_pin_msg_panel(sz.y)


func _pin_msg_panel(visible_h: float) -> void:
	if _right_bottom == null or _map_pane == null:
		return
	var g := _side_geom()
	_msg_full_h = floorf(g["bottom_open_h"])
	_msg_rw = floorf(g["right_w"])
	_msg_open_x = floorf(g["right_open_x"])
	_msg_h = clampf(floorf(visible_h), 8.0, _msg_full_h)
	_apply_msg_geometry()
	_refresh_message_view()


func _ensure_msg_terminal() -> void:
	if _msg_ui_ready:
		return
	if _msg_block == null:
		return
	_msg_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_block.clip_contents = false
	_load_cursor_frames()
	## History rows (14) + prompt row (1) = 15 equal slots.
	for i in range(MSG_OPEN_LINES - 1):
		var lb := _make_msg_label()
		_msg_block.add_child(lb)
		_msg_rows.append(lb)
	_msg_prompt_row = Control.new()
	_msg_prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_block.add_child(_msg_prompt_row)
	_msg_prompt_label = _make_msg_label()
	_msg_prompt_label.text = MSG_PROMPT
	_msg_prompt_row.add_child(_msg_prompt_label)
	_msg_cursor = TextureRect.new()
	_msg_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_cursor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_msg_cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_msg_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not _cursor_frames.is_empty():
		_msg_cursor.texture = _cursor_frames[0]
	_msg_prompt_row.add_child(_msg_cursor)
	_msg_ui_ready = true
	_refresh_message_view()


func _load_cursor_frames() -> void:
	_cursor_frames.clear()
	var img := Image.new()
	if img.load(CHARSET_PATH) != OK:
		var tex := load(CHARSET_PATH) as Texture2D
		if tex:
			img = tex.get_image()
	if img == null or img.is_empty():
		return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	for frame in CURSOR_FRAME_COUNT:
		var cy := (CURSOR_CHAR0 + frame) * CHARSET_GLYPH
		var glyph := Image.create(CHARSET_GLYPH, CHARSET_GLYPH, false, Image.FORMAT_RGBA8)
		glyph.blit_rect(img, Rect2i(0, cy, CHARSET_GLYPH, CHARSET_GLYPH), Vector2i.ZERO)
		for y in CHARSET_GLYPH:
			for x in CHARSET_GLYPH:
				var c := glyph.get_pixel(x, y)
				if c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
					glyph.set_pixel(x, y, Color(0, 0, 0, 0))
				else:
					glyph.set_pixel(x, y, Color(
						minf(c.r * CURSOR_BRIGHTEN + CURSOR_BRIGHTEN_ADD, 1.0),
						minf(c.g * CURSOR_BRIGHTEN + CURSOR_BRIGHTEN_ADD, 1.0),
						minf(c.b * CURSOR_BRIGHTEN + CURSOR_BRIGHTEN_ADD * 0.5, 1.0),
						c.a
					))
		_cursor_frames.append(ImageTexture.create_from_image(glyph))


func _make_msg_label() -> Label:
	var lb := Label.new()
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.clip_text = true
	lb.autowrap_mode = TextServer.AUTOWRAP_OFF
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_color_override("font_color", MSG_COLOR)
	lb.add_theme_font_size_override("font_size", MSG_FONT_SIZE)
	UiTheme.apply_font(lb)
	lb.custom_minimum_size = Vector2.ZERO
	return lb


func _apply_msg_geometry() -> void:
	## Panel height = visible strip. 15-line block stays full open height and
	## is bottom-pinned so closed mode clips to the last 5 lines.
	if _right_bottom == null or _map_pane == null:
		return
	if _msg_full_h < 8.0 or _msg_rw < 8.0:
		return
	_ensure_msg_terminal()
	var pane_h := floorf(_map_pane.size.y)
	var h := clampf(floorf(_msg_h), 8.0, _msg_full_h)
	var x := floorf(_msg_open_x)
	if x < 0.0:
		x = floorf(_map_pane.size.x - _msg_rw)
	_right_bottom.custom_minimum_size = Vector2(_msg_rw, h)
	_right_bottom.size = Vector2(_msg_rw, h)
	_right_bottom.position = Vector2(x, pane_h - h)
	_right_bottom.visible = true
	_place_msg_block(h)


func _place_msg_block(panel_h: float) -> void:
	if not _msg_ui_ready or _msg_block == null:
		return
	_msg_open_content_h = maxf(_msg_full_h - float(MSG_INSET_Y * 2), float(MSG_OPEN_LINES))
	_msg_pitch = _msg_open_content_h / float(MSG_OPEN_LINES)
	var w := maxf(_msg_rw - float(MSG_INSET_X * 2), 8.0)
	var font_sz := clampi(int(floorf(_msg_pitch)) - 2, 10, MSG_FONT_SIZE)
	_msg_block.custom_minimum_size = Vector2.ZERO
	_msg_block.size = Vector2(w, _msg_open_content_h)
	## Bottom-align the full 15-line grid inside the (possibly shorter) panel.
	_msg_block.position = Vector2(MSG_INSET_X, panel_h - float(MSG_INSET_Y) - _msg_open_content_h)

	for i in range(_msg_rows.size()):
		var lb := _msg_rows[i]
		lb.add_theme_font_size_override("font_size", font_sz)
		lb.position = Vector2(0.0, float(i) * _msg_pitch)
		lb.size = Vector2(w, _msg_pitch)
		lb.custom_minimum_size = Vector2.ZERO

	if _msg_prompt_row:
		_msg_prompt_row.position = Vector2(0.0, float(MSG_OPEN_LINES - 1) * _msg_pitch)
		_msg_prompt_row.size = Vector2(w, _msg_pitch)
		_msg_prompt_row.custom_minimum_size = Vector2.ZERO
	_layout_prompt_row(font_sz)


func _prompt_row_text() -> String:
	## xu4: "Attack: Dir?" waits on the same line as the command (after ►).
	if _pending_cmd != U4Commands.Id.NONE and not _pending_cmd_name.is_empty():
		return MSG_PROMPT + Locale.t("cmd_need_dir", [_pending_cmd_name])
	return MSG_PROMPT


func _layout_prompt_row(font_sz: int = -1) -> void:
	if _msg_prompt_label == null:
		return
	if font_sz < 0:
		font_sz = clampi(int(floorf(_msg_pitch)) - 2, 10, MSG_FONT_SIZE)
	var text := _prompt_row_text()
	_msg_prompt_label.add_theme_font_size_override("font_size", font_sz)
	_msg_prompt_label.text = text
	var prompt_w := float(font_sz) * float(maxi(text.length(), 2)) * 0.55
	var font := _msg_prompt_label.get_theme_font("font")
	if font:
		prompt_w = font.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz
		).x
	_msg_prompt_label.position = Vector2.ZERO
	_msg_prompt_label.size = Vector2(maxf(prompt_w, 8.0), _msg_pitch)
	_msg_prompt_label.custom_minimum_size = Vector2.ZERO
	_msg_prompt_label.visible = true
	if _msg_cursor:
		## Charset @ sits inset in the 16×16 cell, so draw a bit larger than
		## font_sz to match the perceived size of the ► prompt glyph.
		var side := float(font_sz) * 1.2
		side = minf(side, _msg_pitch)
		_msg_cursor.size = Vector2(side, side)
		_msg_cursor.custom_minimum_size = Vector2.ZERO
		_msg_cursor.position = Vector2(prompt_w, (_msg_pitch - side) * 0.5)
		_apply_cursor_frame()


func _layout_side_panels(animate: bool) -> void:
	if _left_pane == null or _right_top == null or _right_bottom == null or _map_pane == null:
		return
	var g := _side_geom()
	var lw: float = g["left_w"]
	var rw: float = g["right_w"]
	var cw: float = g["compact_w"]
	var ch: float = g["compact_h"]
	var ph: float = g["pane_h"]
	var top_h: float = g["top_h"]
	var bot_closed_h: float = floorf(g["bottom_closed_h"])
	var bot_open_h: float = floorf(g["bottom_open_h"])
	if ph < 1.0 or rw < 1.0:
		return

	_left_pane.custom_minimum_size = Vector2(lw, ph)
	_left_pane.size = Vector2(lw, ph)

	var left_x: float = g["left_open_x"] if _sides_open else g["left_closed_x"]
	var right_open_x: float = floorf(g["right_open_x"])
	var right_closed_x: float = g["right_closed_x"]
	var compact_x: float = g["compact_x"]

	if _compact_pane:
		_compact_pane.custom_minimum_size = Vector2(cw, ch)
		_compact_pane.size = Vector2(cw, ch)
		_compact_pane.position = Vector2(compact_x, 0.0)
		if _compact_roster:
			_compact_roster.relayout()

	_msg_full_h = bot_open_h
	_msg_rw = floorf(rw)
	_msg_open_x = right_open_x

	if animate and is_inside_tree():
		if _side_tween:
			_side_tween.kill()
		_side_tween = create_tween()
		_side_tween.set_parallel(true)
		var msg_from := clampf(floorf(_right_bottom.size.y), bot_closed_h, bot_open_h)
		if _sides_open:
			_set_open_panels_visible(true)
			if _compact_pane:
				_compact_pane.visible = true
				_compact_pane.modulate.a = 1.0
			_right_top.position = Vector2(right_closed_x, 0.0)
			_right_top.size = Vector2(rw, top_h)
			_right_top.custom_minimum_size = Vector2(rw, top_h)
			_left_pane.position = Vector2(g["left_closed_x"], 0.0)
			## Grow message panel upward from the closed strip.
			_msg_h = bot_closed_h
			_apply_msg_geometry()

			_side_tween.tween_property(_left_pane, "position", Vector2(left_x, 0.0), SIDE_TWEEN_SEC) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_side_tween.tween_property(_right_top, "position", Vector2(right_open_x, 0.0), SIDE_TWEEN_SEC) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_side_tween.tween_method(_tween_msg_height, bot_closed_h, bot_open_h, SIDE_TWEEN_SEC) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			if _compact_pane:
				_side_tween.tween_property(_compact_pane, "modulate:a", 0.0, SIDE_TWEEN_SEC * 0.35)
			_side_tween.chain().tween_callback(_on_sides_opened)
		else:
			_set_open_panels_visible(true)
			if _compact_pane:
				_compact_pane.visible = true
				_compact_pane.modulate.a = 0.0
				_side_tween.tween_property(_compact_pane, "modulate:a", 1.0, SIDE_TWEEN_SEC)
			_side_tween.tween_property(_left_pane, "position", Vector2(left_x, 0.0), SIDE_TWEEN_SEC) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_side_tween.tween_property(_right_top, "position", Vector2(right_closed_x, 0.0), SIDE_TWEEN_SEC) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			## Shrink Label with panel each frame so min-size can't trap tall open height.
			_side_tween.tween_method(_tween_msg_height, msg_from, bot_closed_h, SIDE_TWEEN_SEC) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_side_tween.chain().tween_callback(_on_sides_closed)
	else:
		if _side_tween:
			_side_tween.kill()
			_side_tween = null
		_left_pane.position = Vector2(left_x, 0.0)
		_right_top.size = Vector2(rw, top_h)
		_right_top.custom_minimum_size = Vector2(rw, top_h)
		_right_top.position = Vector2(right_open_x if _sides_open else right_closed_x, 0.0)
		_msg_h = bot_open_h if _sides_open else bot_closed_h
		_apply_msg_geometry()
		_refresh_message_view()
		_set_open_panels_visible(_sides_open)
		if _compact_pane:
			_compact_pane.visible = not _sides_open
			_compact_pane.modulate.a = 1.0


func _tween_msg_height(h: float) -> void:
	## Keep panel bottom-pinned while height animates; refresh lines for visible area.
	_msg_h = h
	_apply_msg_geometry()
	_refresh_message_view()


func _set_open_panels_visible(on: bool) -> void:
	if _left_pane:
		_left_pane.visible = on
	if _right_top:
		_right_top.visible = on


func _on_sides_closed() -> void:
	if not _sides_open:
		if _left_pane:
			_left_pane.visible = false
		if _right_top:
			_right_top.visible = false
		if _compact_pane:
			_compact_pane.visible = true
			_compact_pane.modulate.a = 1.0
		_msg_h = floorf(_side_geom()["bottom_closed_h"])
		_apply_msg_geometry()
		_refresh_message_view()


func _on_sides_opened() -> void:
	if _sides_open and _compact_pane:
		_compact_pane.visible = false
	_msg_h = _msg_full_h
	_apply_msg_geometry()
	_refresh_message_view()


func _toggle_side_panels() -> void:
	_sides_open = not _sides_open
	if _sides_open:
		_refresh_party()
	_layout_side_panels(true)


func _process(delta: float) -> void:
	_tick_cursor(delta)

	_move_cd = maxf(0.0, _move_cd - delta)
	_hold_arm = maxf(0.0, _hold_arm - delta)

	var esc := Input.is_key_pressed(KEY_ESCAPE) or Input.is_physical_key_pressed(KEY_ESCAPE)
	## Esc→menu is handled in _unhandled_input only. Polling Esc here after
	## Peer closes would open the menu on the same keypress.
	_esc_held = esc

	if not _load_error.is_empty():
		return
	if _peer_overlay != null and _peer_overlay.is_open():
		return

	var dir := _read_move_dir()
	if dir == Vector2i.ZERO:
		_block_dir_until_keyup = false
		_move_repeating = false
		_hold_arm = 0.0
		_held_dir = Vector2i.ZERO
		return
	if _block_dir_until_keyup:
		## Direction was used for A/F/G/J/O/T — wait for key-up before move/repeat.
		_move_repeating = false
		_hold_arm = 0.0
		_held_dir = dir
		return
	if dir != _held_dir:
		_held_dir = dir
		_move_repeating = false
		_hold_arm = 0.0
	if _move_cd > 0.0:
		return
	if _move_repeating and _hold_arm > 0.0:
		return
	if _map != null and _map.is_scrolling():
		_map.finish_scroll()

	if _pending_cmd != U4Commands.Id.NONE:
		_finish_directed_command(dir)
		_block_dir_until_keyup = true
		_move_cd = 0.0
		_move_repeating = false
		_hold_arm = 0.0
		return

	_tile_pos = Vector2i(
		posmod(_tile_pos.x + dir.x, WorldMapData.WIDTH),
		posmod(_tile_pos.y + dir.y, WorldMapData.HEIGHT)
	)
	_map.set_center(_tile_pos)
	_push_move_message(dir)
	_move_cd = MOVE_HOLD_INTERVAL
	if _move_repeating:
		_hold_arm = 0.0
	else:
		_move_repeating = true
		_hold_arm = MOVE_HOLD_DELAY


func _read_move_dir() -> Vector2i:
	if Input.is_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_LEFT):
		return Vector2i(-1, 0)
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_RIGHT):
		return Vector2i(1, 0)
	if Input.is_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_UP):
		return Vector2i(0, -1)
	if Input.is_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_DOWN):
		return Vector2i(0, 1)
	if Input.is_action_pressed("move_left"):
		return Vector2i(-1, 0)
	if Input.is_action_pressed("move_right"):
		return Vector2i(1, 0)
	if Input.is_action_pressed("move_up"):
		return Vector2i(0, -1)
	if Input.is_action_pressed("move_down"):
		return Vector2i(0, 1)
	return Vector2i.ZERO


func _clear_pending_dir() -> void:
	_pending_cmd = U4Commands.Id.NONE
	_pending_cmd_name = ""
	_block_dir_until_keyup = false
	_layout_prompt_row()


func _on_escape() -> void:
	if _peer_overlay != null and _peer_overlay.is_open():
		_close_peer_overlay()
		return
	if _sides_open:
		_sides_open = false
		_layout_side_panels(true)
		return
	if _pending_cmd != U4Commands.Id.NONE:
		## xu4 ReadDir: Esc clears "Dir?" on the same line — no extra message.
		_clear_pending_dir()
	else:
		SceneRouter.to_menu()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		## Peer gem: only Esc / Space / Enter dismiss; swallow everything else.
		if _peer_overlay != null and _peer_overlay.is_open():
			if _is_peer_dismiss_key(k):
				_close_peer_overlay()
			get_viewport().set_input_as_handled()
			return
		if k.keycode == KEY_TAB or k.physical_keycode == KEY_TAB:
			_toggle_side_panels()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _peer_overlay != null and _peer_overlay.is_open():
			if _is_peer_dismiss_key(event):
				_close_peer_overlay()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_on_escape()
			get_viewport().set_input_as_handled()
			return
		## Waiting for a direction (A/G/J/O/T) — same line as "Attack: Dir?".
		if _pending_cmd != U4Commands.Id.NONE:
			if _is_direction_key(event):
				return
			## xu4: Space / Enter cancel Dir? without a message.
			if _is_dir_cancel_key(event):
				_clear_pending_dir()
				get_viewport().set_input_as_handled()
				return
			## Any other key → classic grey "What?" (no prompt), abort Dir?.
			_clear_pending_dir()
			_push_message(Locale.t("cmd_what"), false)
			get_viewport().set_input_as_handled()
			return
		var cmd := U4Commands.from_event(event)
		if cmd != U4Commands.Id.NONE:
			_handle_command(cmd)
			get_viewport().set_input_as_handled()


func _is_peer_dismiss_key(event: InputEventKey) -> bool:
	## xu4 peer(): readChoice("\\015 \\033") — Enter, Space, Esc.
	var code := event.keycode
	var phys := event.physical_keycode
	return (
		code == KEY_ESCAPE or phys == KEY_ESCAPE
		or code == KEY_SPACE or phys == KEY_SPACE
		or code == KEY_ENTER or phys == KEY_ENTER
		or code == KEY_KP_ENTER or phys == KEY_KP_ENTER
	)


func _is_direction_key(event: InputEventKey) -> bool:
	var code := event.keycode
	var phys := event.physical_keycode
	return (
		code == KEY_LEFT or code == KEY_RIGHT or code == KEY_UP or code == KEY_DOWN
		or phys == KEY_LEFT or phys == KEY_RIGHT or phys == KEY_UP or phys == KEY_DOWN
	)


func _is_dir_cancel_key(event: InputEventKey) -> bool:
	var code := event.keycode
	var phys := event.physical_keycode
	return (
		code == KEY_SPACE or phys == KEY_SPACE
		or code == KEY_ENTER or phys == KEY_ENTER
		or code == KEY_KP_ENTER or phys == KEY_KP_ENTER
	)


func _handle_command(cmd: int) -> void:
	var lang := GameState.lang_short()
	var letter := U4Commands.letter_for(cmd)
	var name := U4Commands.label(cmd, lang)
	## xu4 fire(): not on a ship → "Fire What?" (no Dir?).
	if cmd == U4Commands.Id.FIRE:
		_clear_pending_dir()
		_push_message(Locale.t("cmd_fire_what"), false)
		return
	if U4Commands.NEEDS_DIRECTION.get(cmd, false):
		## xu4: print "Attack: " then "Dir?" on the *same* line and wait.
		_pending_cmd = cmd
		_pending_cmd_name = name
		_layout_prompt_row()
		return
	_clear_pending_dir()
	if cmd == U4Commands.Id.PEER:
		_do_peer()
	elif cmd == U4Commands.Id.LOCATE:
		_push_message(Locale.t("cmd_locate", [
			letter,
			name,
			_format_u4_sextant(_tile_pos.x),
			_format_u4_sextant(_tile_pos.y),
		]))
	elif cmd == U4Commands.Id.PASS:
		_push_message(Locale.t("cmd_fired", [letter, name]))
	else:
		_push_message(Locale.t("cmd_stub", [letter, name]))


func _ensure_peer_overlay() -> void:
	if _peer_overlay != null or _map_pane == null:
		return
	_peer_overlay = PeerGemOverlay.new()
	_peer_overlay.name = "PeerGemOverlay"
	_map_pane.add_child(_peer_overlay)


func _do_peer() -> void:
	## Peer: spend a gem, show ~16:9 gem map until Space/Enter/Esc.
	if GameState.gems <= 0:
		_push_message(Locale.t("cmd_peer_what"), false)
		return
	GameState.gems -= 1
	_refresh_inventory_bars()
	_push_message(Locale.t("cmd_peer_gem"), false)
	_ensure_peer_overlay()
	if _peer_overlay == null or _map == null:
		return
	var tile_sz := _map.displayed_tile_size()
	var loc := "%s %s" % [
		_format_u4_sextant(_tile_pos.x),
		_format_u4_sextant(_tile_pos.y),
	]
	_peer_overlay.open_peer(_world, _tile_pos, tile_sz, loc)


func _close_peer_overlay() -> void:
	if _peer_overlay:
		_peer_overlay.close_peer()


func _refresh_inventory_bars() -> void:
	if _bottom_bar and _bottom_bar.has_method("refresh"):
		_bottom_bar.refresh()
	if _top_bar and _top_bar.has_method("refresh"):
		_top_bar.refresh()


func _finish_directed_command(dir: Vector2i) -> void:
	var cmd := _pending_cmd
	var cmd_name := _pending_cmd_name
	_clear_pending_dir()
	## xu4 erases "Dir?" on the same line and writes the direction name.
	var dir_name := _direction_label(dir)
	if not cmd_name.is_empty() and not dir_name.is_empty():
		_push_message(Locale.t("cmd_dir_done", [cmd_name, dir_name]))
	var result := _directed_result_message(cmd)
	if not result.is_empty():
		_push_message(result, false)


func _directed_result_message(cmd: int) -> String:
	## Stub outcomes match xu4 when the action finds nothing useful.
	match cmd:
		U4Commands.Id.ATTACK:
			return Locale.t("cmd_nothing_to_attack")
		U4Commands.Id.JIMMY:
			return Locale.t("cmd_jimmy_what")
		U4Commands.Id.OPEN, U4Commands.Id.GET_CHEST:
			return Locale.t("cmd_not_here")
		U4Commands.Id.TALK:
			return Locale.t("cmd_no_response")
		_:
			return ""


func _refresh_party() -> void:
	if _roster:
		_roster.refresh()
	if _compact_roster:
		_compact_roster.refresh()


func _push_move_message(dir: Vector2i) -> void:
	if not _load_error.is_empty():
		return
	_push_message(_direction_label(dir, true))


func _direction_label(dir: Vector2i, for_move: bool = false) -> String:
	if dir.y < 0:
		return Locale.t("dir_move_north" if for_move else "dir_north")
	if dir.y > 0:
		return Locale.t("dir_move_south" if for_move else "dir_south")
	if dir.x > 0:
		return Locale.t("dir_move_east" if for_move else "dir_east")
	if dir.x < 0:
		return Locale.t("dir_move_west" if for_move else "dir_west")
	return ""


func _format_u4_sextant(n: int) -> String:
	## Ultima IV A–P nibbles (A=0 … P=15). Value 0..255 → e.g. BA = 16 → B'A"
	n = posmod(n, 256)
	const DIGITS := "ABCDEFGHIJKLMNOP"
	var hi := DIGITS[n >> 4]
	var lo := DIGITS[n & 0xF]
	return "%s'%s\"" % [hi, lo]


func _push_message(line: String, with_prompt: bool = true) -> void:
	if line.is_empty():
		return
	if with_prompt and not line.begins_with(MSG_PROMPT):
		line = MSG_PROMPT + line
	_msg_lines.append(line)
	while _msg_lines.size() > MSG_KEEP:
		_msg_lines.remove_at(0)
	_refresh_message_view()


func _tick_cursor(delta: float) -> void:
	if _msg_cursor == null or _cursor_frames.is_empty():
		return
	_cursor_t += delta
	if _cursor_t < CURSOR_FRAME_SEC:
		return
	_cursor_t = 0.0
	_cursor_frame = (_cursor_frame + 1) % _cursor_frames.size()
	_apply_cursor_frame()


func _apply_cursor_frame() -> void:
	if _msg_cursor == null or _cursor_frames.is_empty():
		return
	_msg_cursor.texture = _cursor_frames[_cursor_frame]
	_msg_cursor.visible = true


func _refresh_message_view() -> void:
	## Bottom-aligned history in the 14 slots above the prompt row.
	## Prompt row is either "► @" or "► Attack: Dir?" while waiting (xu4).
	_ensure_msg_terminal()
	if not _msg_ui_ready:
		return
	var hist_slots := MSG_OPEN_LINES - 1
	for i in range(_msg_rows.size()):
		_msg_rows[i].text = ""
	var n := _msg_lines.size()
	var take := mini(n, hist_slots)
	var first_row := hist_slots - take
	var start := n - take
	for j in range(take):
		_msg_rows[first_row + j].text = _msg_lines[start + j]
	_layout_prompt_row()
