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
var _ztats_panel: ZtatsPanel
var _ready_panel: ReadyPanel
var _wear_panel: WearPanel
var _locate_label: Label
var _locate_on := false

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
## Locate HUD (Ctrl+L) — X from open-map right edge; Y on top bar. Tweak inset.
const LOCATE_HUD_INSET := Vector2(6, 0)
const LOCATE_HUD_FONT_SIZE := 13
const LOCATE_HUD_COLOR := Color(0.91, 0.9, 0.82, 1)

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
## xu4 newOrder(): 0 = idle, 1 = Exchange #, 2 = with #.
var _order_stage := 0
var _order_slot_a := -1
## Arrow-key cursor while New Order is open (0-based).
var _order_cursor := 0
## xu4 ztatsFor(): 0 = idle, 1 = pick member, 2 = viewing sheet.
var _ztats_stage := 0
var _ztats_cursor := 0
## Flat page index while viewing: 0..party-1 = chars, then gear/reagents/mixtures.
var _ztats_flat := 0
## xu4 readyWeapon(): 0 = idle, 1 = pick member, 2 = pick weapon.
var _ready_stage := 0
var _ready_cursor := 0
var _ready_slot := -1
## xu4 wearArmor(): 0 = idle, 1 = pick member, 2 = pick armor.
var _wear_stage := 0
var _wear_cursor := 0
var _wear_slot := -1
var _load_error: String = ""
var _esc_held := false
var _msg_lines: PackedStringArray = PackedStringArray()
var _sides_open := false
## N (New Order): temporarily show only the character roster panel.
var _order_opened_roster := false
## Bump to cancel a pending delayed roster slide-away.
var _order_close_token := 0
const ORDER_ROSTER_HOLD_SEC := 0.6
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
	## New character: start with side panels open (not full-tile).
	## TODO: restore open/closed from save when savegame is wired.
	_sides_open = GameState.is_new_game
	_ensure_msg_terminal()
	_ensure_peer_overlay()
	_ensure_ztats_panel()
	_ensure_locate_hud()
	if _compact_roster:
		_compact_roster.set_compact(true)
	if _roster:
		_roster.set_compact(false)
	## Stub: party of 4 for layout checks.
	GameState.refresh_party_order()
	## Full party of 8 for stub testing (all class companions).

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
	_layout_locate_hud()
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
	sb.bg_color = Color(0.0, 0.0, 0.0, 1)
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
	if _ready_stage == 1:
		return MSG_PROMPT + Locale.t("cmd_ready_for")
	if _ready_stage == 2:
		return MSG_PROMPT + Locale.t("cmd_ready_weapon")
	if _wear_stage == 1:
		return MSG_PROMPT + Locale.t("cmd_wear_for")
	if _wear_stage == 2:
		return MSG_PROMPT + Locale.t("cmd_wear_armor")
	if _ztats_stage == 1:
		return MSG_PROMPT + Locale.t("cmd_ztats_for")
	if _order_stage == 1:
		return MSG_PROMPT + Locale.t("cmd_exchange")
	if _order_stage == 2:
		return MSG_PROMPT + Locale.t("cmd_with")
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

	## Full Tab open, or New Order peek (character panel only).
	var roster_open := _sides_open or _order_opened_roster

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
			_order_opened_roster = false
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
		_left_pane.visible = _sides_open
		_right_top.size = Vector2(rw, top_h)
		_right_top.custom_minimum_size = Vector2(rw, top_h)
		_right_top.position = Vector2(right_open_x if roster_open else right_closed_x, 0.0)
		_right_top.visible = roster_open
		_msg_h = bot_open_h if _sides_open else bot_closed_h
		_apply_msg_geometry()
		_refresh_message_view()
		if _compact_pane:
			_compact_pane.visible = not roster_open
			_compact_pane.modulate.a = 1.0
	if _ztats_stage == 2:
		if _right_top:
			_right_top.visible = true
		if _compact_pane:
			_compact_pane.visible = false
		if _roster:
			_roster.visible = false
		if _ztats_panel:
			_ztats_panel.visible = true
			_ztats_panel.move_to_front()
	_layout_locate_hud()


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
	if not _sides_open and not _order_opened_roster:
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
	_cancel_order_roster_close()
	_order_opened_roster = false
	_sides_open = not _sides_open
	if _sides_open:
		_refresh_party()
	_layout_side_panels(true)


func _open_order_roster() -> void:
	## Slide out only the character panel for New Order (not left / message).
	_cancel_order_roster_close()
	if _sides_open or _order_opened_roster:
		_refresh_party()
		return
	if _right_top == null:
		return
	_order_opened_roster = true
	_refresh_party()
	var g := _side_geom()
	var rw: float = g["right_w"]
	var top_h: float = g["top_h"]
	var right_open_x: float = floorf(g["right_open_x"])
	var right_closed_x: float = g["right_closed_x"]
	_right_top.visible = true
	_right_top.size = Vector2(rw, top_h)
	_right_top.custom_minimum_size = Vector2(rw, top_h)
	_right_top.position = Vector2(right_closed_x, 0.0)
	if _compact_pane:
		_compact_pane.visible = true
		_compact_pane.modulate.a = 1.0
	if not is_inside_tree():
		_right_top.position = Vector2(right_open_x, 0.0)
		if _compact_pane:
			_compact_pane.visible = false
		return
	if _side_tween:
		_side_tween.kill()
	_side_tween = create_tween()
	_side_tween.set_parallel(true)
	_side_tween.tween_property(_right_top, "position", Vector2(right_open_x, 0.0), SIDE_TWEEN_SEC) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _compact_pane:
		_side_tween.tween_property(_compact_pane, "modulate:a", 0.0, SIDE_TWEEN_SEC * 0.35)
	_side_tween.chain().tween_callback(_on_order_roster_opened)


func _close_order_roster() -> void:
	## Put the character panel away after New Order cancel/complete.
	_cancel_order_roster_close()
	if not _order_opened_roster:
		return
	_order_opened_roster = false
	if _sides_open:
		return
	if _right_top == null:
		return
	var g := _side_geom()
	var right_closed_x: float = g["right_closed_x"]
	if _compact_pane:
		_compact_pane.visible = true
		_compact_pane.modulate.a = 0.0
	if not is_inside_tree():
		_right_top.visible = false
		_right_top.position = Vector2(right_closed_x, 0.0)
		if _compact_pane:
			_compact_pane.modulate.a = 1.0
		return
	if _side_tween:
		_side_tween.kill()
	_side_tween = create_tween()
	_side_tween.set_parallel(true)
	_side_tween.tween_property(_right_top, "position", Vector2(right_closed_x, 0.0), SIDE_TWEEN_SEC) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _compact_pane:
		_side_tween.tween_property(_compact_pane, "modulate:a", 1.0, SIDE_TWEEN_SEC)
	_side_tween.chain().tween_callback(_on_order_roster_closed)


func _cancel_order_roster_close() -> void:
	_order_close_token += 1


func _schedule_order_roster_close(delay_sec: float = ORDER_ROSTER_HOLD_SEC) -> void:
	## Keep panel open briefly so the new order is readable; gameplay stays unlocked.
	if not _order_opened_roster or _sides_open:
		return
	_order_close_token += 1
	var tok := _order_close_token
	get_tree().create_timer(delay_sec).timeout.connect(
		func() -> void:
			if tok != _order_close_token:
				return
			if _order_stage != 0 or _sides_open:
				return
			_close_order_roster()
	)


func _on_order_roster_opened() -> void:
	if _order_opened_roster and _compact_pane:
		_compact_pane.visible = false


func _on_order_roster_closed() -> void:
	if _sides_open or _order_opened_roster:
		return
	if _right_top:
		_right_top.visible = false
	if _compact_pane:
		_compact_pane.visible = true
		_compact_pane.modulate.a = 1.0


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
	## Z/N/R/W pick lists: same hold timing as world move; wrap at ends.
	if _ztats_stage == 1 or _order_stage != 0 or _ready_stage == 1 or _wear_stage == 1:
		_tick_select_cursor()
		return
	if _ready_stage == 2:
		_tick_ready_weapon_cursor()
		return
	if _wear_stage == 2:
		_tick_wear_armor_cursor()
		return
	if _ztats_stage != 0:
		return

	var dir := _read_move_dir()
	if dir == Vector2i.ZERO:
		_block_dir_until_keyup = false
		_reset_hold_state()
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
	_refresh_locate_hud()
	_push_move_message(dir)
	_arm_hold_after_step()


func _reset_hold_state() -> void:
	_move_repeating = false
	_hold_arm = 0.0
	_move_cd = 0.0
	_held_dir = Vector2i.ZERO


func _arm_hold_after_step() -> void:
	_move_cd = MOVE_HOLD_INTERVAL
	if _move_repeating:
		_hold_arm = 0.0
	else:
		_move_repeating = true
		_hold_arm = MOVE_HOLD_DELAY


func _tick_select_cursor() -> void:
	## ↑↓ while picking a party member (Ztats / New Order).
	var step := _read_select_step()
	if step == 0:
		_reset_hold_state()
		return
	var held := Vector2i(0, step)
	if held != _held_dir:
		_held_dir = held
		_move_repeating = false
		_hold_arm = 0.0
	if _move_cd > 0.0:
		return
	if _move_repeating and _hold_arm > 0.0:
		return
	if _ztats_stage == 1:
		_nudge_ztats_cursor(step)
	elif _ready_stage == 1:
		_nudge_ready_cursor(step)
	elif _wear_stage == 1:
		_nudge_wear_cursor(step)
	elif _order_stage != 0:
		_nudge_order_cursor(step)
	_arm_hold_after_step()


func _read_select_step() -> int:
	## -1 = up, +1 = down, 0 = none (vertical only).
	if Input.is_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_UP):
		return -1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_DOWN):
		return 1
	if Input.is_action_pressed("move_up"):
		return -1
	if Input.is_action_pressed("move_down"):
		return 1
	return 0


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


func _clear_pending_order(show_none: bool = false) -> void:
	_order_stage = 0
	_order_slot_a = -1
	_order_cursor = 0
	_clear_order_selection()
	if show_none:
		_push_message(Locale.t("cmd_none"), false)
	_layout_prompt_row()
	_close_order_roster()


func _on_escape() -> void:
	if _peer_overlay != null and _peer_overlay.is_open():
		_close_peer_overlay()
		return
	if _ready_stage != 0:
		_close_ready(true)
		return
	if _wear_stage != 0:
		_close_wear(true)
		return
	if _ztats_stage != 0:
		_close_ztats(true)
		return
	if _order_stage != 0:
		## xu4 choosePlayer cancel → "None"; slide roster away.
		_clear_pending_order(true)
		return
	## Tab panel stays open until Tab is pressed again — Esc does not collapse it.
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
			## Ztats / Ready / Wear open: don't collapse/expand side panels.
			if _ztats_stage != 0 or _ready_stage != 0 or _wear_stage != 0:
				get_viewport().set_input_as_handled()
				return
			_toggle_side_panels()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	## Ztats / Ready / Wear / New Order accept keyboard + gamepad.
	if _ready_stage != 0:
		if _handle_ready_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if _wear_stage != 0:
		if _handle_wear_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if _ztats_stage != 0:
		if _handle_ztats_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if _order_stage != 0:
		if _handle_order_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			## Swallow other pads/keys so explore move/commands don't leak through.
			get_viewport().set_input_as_handled()
		return
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
		## Ctrl+L: toggle persistent Locate HUD (sextant required).
		if event.ctrl_pressed and _is_locate_key(event):
			_toggle_locate_hud()
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
		_clear_pending_order()
		_close_ztats(false)
		_close_ready(false)
		_close_wear(false)
		_push_message(Locale.t("cmd_fire_what"), false)
		return
	if U4Commands.NEEDS_DIRECTION.get(cmd, false):
		## xu4: print "Attack: " then "Dir?" on the *same* line and wait.
		_clear_pending_order()
		_close_ztats(false)
		_close_ready(false)
		_close_wear(false)
		_pending_cmd = cmd
		_pending_cmd_name = name
		_layout_prompt_row()
		return
	_clear_pending_dir()
	_clear_pending_order()
	_close_ztats(false)
	_close_ready(false)
	_close_wear(false)
	if cmd == U4Commands.Id.PEER:
		_do_peer()
	elif cmd == U4Commands.Id.NEW_ORDER:
		_do_new_order()
	elif cmd == U4Commands.Id.ZTATS:
		_do_ztats()
	elif cmd == U4Commands.Id.READY:
		_do_ready()
	elif cmd == U4Commands.Id.WEAR:
		_do_wear()
	elif cmd == U4Commands.Id.LOCATE:
		if not GameState.has_sextant:
			_push_message(Locale.t("cmd_locate_what"), false)
		else:
			_push_message(Locale.t("cmd_locate", [
				name,
				_format_u4_sextant(_tile_pos.x),
				_format_u4_sextant(_tile_pos.y),
			]))
	elif cmd == U4Commands.Id.PASS:
		_push_message(Locale.t("cmd_fired", [name]))
	else:
		_push_message(Locale.t("cmd_stub", [letter, name]))


func _ensure_peer_overlay() -> void:
	if _peer_overlay != null or _map_pane == null:
		return
	_peer_overlay = PeerGemOverlay.new()
	_peer_overlay.name = "PeerGemOverlay"
	_map_pane.add_child(_peer_overlay)


func _is_locate_key(event: InputEventKey) -> bool:
	return event.keycode == KEY_L or event.physical_keycode == KEY_L


func _ensure_locate_hud() -> void:
	## Label only (no plate). Parent = StubWorld so Y can sit on the top bar
	## without MapPane clip; X still uses open-map right edge.
	if _locate_label != null:
		return
	_locate_label = Label.new()
	_locate_label.name = "LocateHud"
	_locate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_locate_label.visible = false
	_locate_label.add_theme_font_size_override("font_size", LOCATE_HUD_FONT_SIZE)
	_locate_label.add_theme_color_override("font_color", LOCATE_HUD_COLOR)
	UiTheme.apply_font(_locate_label)
	add_child(_locate_label)
	_refresh_locate_hud()
	_layout_locate_hud()


func _toggle_locate_hud() -> void:
	if not GameState.has_sextant:
		_push_message(Locale.t("cmd_locate_what"), false)
		return
	_locate_on = not _locate_on
	_ensure_locate_hud()
	if _locate_label:
		_locate_label.visible = _locate_on
	if _locate_on:
		_refresh_locate_hud()
		_layout_locate_hud()
		_push_message(Locale.t("locate_on"), false)
	else:
		_push_message(Locale.t("locate_off"), false)


func _refresh_locate_hud() -> void:
	if _locate_label == null:
		return
	_locate_label.text = "%s %s" % [
		_format_u4_sextant(_tile_pos.x),
		_format_u4_sextant(_tile_pos.y),
	]
	if _locate_on:
		_layout_locate_hud()


func _layout_locate_hud() -> void:
	## Same X as before (open-map right). Y centered on the top bar.
	if _locate_label == null or _map_pane == null or _top_bar == null:
		return
	if not _locate_on:
		return
	var g := _side_geom()
	var map_right: float = floorf(g["right_open_x"])
	_locate_label.reset_size()
	var text_sz := _locate_label.get_minimum_size()
	_locate_label.size = text_sz
	## MapPane is full-width under RootCol — same X space as the first version.
	var map_origin := _map_pane.global_position - global_position
	var top_origin := _top_bar.global_position - global_position
	var bar_h := _top_bar.size.y
	if bar_h < 1.0:
		bar_h = _top_bar.custom_minimum_size.y
	_locate_label.position = Vector2(
		map_origin.x + map_right - text_sz.x - LOCATE_HUD_INSET.x,
		top_origin.y + floorf((bar_h - text_sz.y) * 0.5) + LOCATE_HUD_INSET.y
	)
	_locate_label.move_to_front()


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
	var loc := ""
	if GameState.has_sextant:
		loc = "%s %s" % [
			_format_u4_sextant(_tile_pos.x),
			_format_u4_sextant(_tile_pos.y),
		]
	_peer_overlay.open_peer(_world, _tile_pos, tile_sz, loc)


func _close_peer_overlay() -> void:
	if _peer_overlay:
		_peer_overlay.close_peer()


func _do_new_order() -> void:
	## xu4 newOrder(): "New Order!" → Exchange # → with # → swapPlayers.
	## Ultima4R: digits still work; ↑↓ + Enter also pick slots.
	_close_ztats(false)
	_close_ready(false)
	_close_wear(false)
	_push_message(Locale.t("cmd_new_order"), false)
	if GameState.party_size() <= 1:
		## Nobody to exchange with.
		_push_message(Locale.t("cmd_what"), false)
		return
	_open_order_roster()
	_order_stage = 1
	_order_slot_a = -1
	_order_cursor = 0
	_reset_hold_state()
	_sync_order_selection()
	_layout_prompt_row()


func _ensure_ztats_panel() -> void:
	if _ztats_panel != null:
		return
	var host := get_node_or_null("RootCol/MapPane/RightTopPane/RightTopMargin") as Control
	if host == null:
		return
	_ztats_panel = ZtatsPanel.new()
	_ztats_panel.name = "ZtatsPanel"
	_ztats_panel.visible = false
	_ztats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(_ztats_panel)


func _do_ztats() -> void:
	## xu4 ztatsFor(): "Ztats for: " → pick member → character sheet.
	_clear_pending_order()
	_close_ready(false)
	_close_wear(false)
	if GameState.party_size() <= 0:
		_push_message(Locale.t("cmd_none"), false)
		return
	_open_order_roster()
	_ztats_stage = 1
	_ztats_cursor = 0
	_reset_hold_state()
	if _roster:
		_roster.visible = true
	if _ztats_panel:
		_ztats_panel.close_panel()
	_sync_ztats_selection()
	_layout_prompt_row()


func _handle_ztats_input(event: InputEvent) -> bool:
	if not event.is_pressed():
		return false
	## Key-repeat for inventory ↑↓ / PageUp/PageDown; ignore echo otherwise.
	if event.is_echo():
		if _ztats_stage == 2 and _ztats_panel and _ztats_panel.is_inventory_page():
			return _try_ztats_inv_scroll(event)
		return false
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
			_on_escape()
			return true
	## Viewing sheet: Esc / Space / Enter cancel; Z returns to pick list.
	if _ztats_stage == 2:
		if event is InputEventKey:
			var kz := event as InputEventKey
			if kz.keycode == KEY_Z or kz.physical_keycode == KEY_Z:
				_return_ztats_to_pick()
				return true
		if _is_ztats_dismiss(event):
			_close_ztats(false)
			return true
		## ↑↓ scroll inventory lists; ←→ cycle pages (chars → gear → reagents → mixtures).
		if _ztats_panel and _ztats_panel.is_inventory_page():
			if _try_ztats_inv_scroll(event):
				return true
		if event.is_action_pressed("move_left"):
			_nudge_ztats_view(-1)
			return true
		if event.is_action_pressed("move_right"):
			_nudge_ztats_view(1)
			return true
		if event is InputEventKey:
			var kview := event as InputEventKey
			if kview.keycode == KEY_LEFT or kview.physical_keycode == KEY_LEFT:
				_nudge_ztats_view(-1)
				return true
			if kview.keycode == KEY_RIGHT or kview.physical_keycode == KEY_RIGHT:
				_nudge_ztats_view(1)
				return true
			## 0 → equipment page (xu4).
			if _is_ztats_equipment_key(kview):
				_show_ztats_inventory(ZtatsPanel.InvPage.GEAR)
				return true
			var slot := _player_slot_from_key(kview)
			if slot >= 0:
				_show_ztats_member(slot)
				return true
		return true
	## Pick stage — same affordances as New Order cursor.
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		_close_ztats(true)
		return true
	if event.is_action_pressed("cancel") and event is InputEventJoypadButton:
		_close_ztats(true)
		return true
	if event is InputEventKey and _is_order_cancel_key(event as InputEventKey):
		_close_ztats(true)
		return true
	if event is InputEventKey and _is_order_confirm_key(event as InputEventKey):
		_accept_ztats_slot(_ztats_cursor)
		return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
		_accept_ztats_slot(_ztats_cursor)
		return true
	## ↑↓ are polled in _tick_select_cursor (hold-repeat like world move).
	if event is InputEventKey:
		var ke := event as InputEventKey
		## 0 → jump straight to equipment.
		if _is_ztats_equipment_key(ke):
			_show_ztats_inventory(ZtatsPanel.InvPage.GEAR)
			return true
		var pick := _player_slot_from_key(ke)
		if pick < 0:
			if _is_digit_key(ke):
				_close_ztats(true)
				return true
			return false
		_ztats_cursor = pick
		_accept_ztats_slot(pick)
		return true
	return false


func _is_ztats_dismiss(event: InputEvent) -> bool:
	## Only Esc / Space / Enter fully cancel Ztats.
	if event is InputEventKey:
		var k := event as InputEventKey
		var code := k.keycode
		var phys := k.physical_keycode
		return (
			code == KEY_ESCAPE or phys == KEY_ESCAPE
			or code == KEY_SPACE or phys == KEY_SPACE
			or code == KEY_ENTER or phys == KEY_ENTER
			or code == KEY_KP_ENTER or phys == KEY_KP_ENTER
		)
	return false


func _return_ztats_to_pick() -> void:
	## Z while viewing → back to character select list.
	_ztats_stage = 1
	_reset_hold_state()
	if _ztats_panel:
		_ztats_panel.close_panel()
	if _roster:
		_roster.visible = true
	if _right_top:
		_right_top.visible = true
	if _compact_pane:
		_compact_pane.visible = false
	_order_opened_roster = true
	_sync_ztats_selection()
	_layout_prompt_row()


func _nudge_ztats_view(delta: int) -> void:
	var n := _ztats_flat_count()
	if n <= 0:
		return
	_ztats_flat = posmod(_ztats_flat + delta, n)
	_show_ztats_flat(_ztats_flat)


func _ztats_flat_count() -> int:
	## Party character sheets + Equipment + Reagents + Mixtures.
	return maxi(GameState.party_size(), 1) + 3


func _show_ztats_flat(flat: int) -> void:
	var party_n := maxi(GameState.party_size(), 1)
	if flat < party_n:
		_show_ztats_member(flat)
		return
	var inv := flat - party_n
	match inv:
		0:
			_show_ztats_inventory(ZtatsPanel.InvPage.GEAR)
		1:
			_show_ztats_inventory(ZtatsPanel.InvPage.REAGENTS)
		_:
			_show_ztats_inventory(ZtatsPanel.InvPage.MIXTURES)


func _nudge_ztats_cursor(delta: int) -> void:
	var n := maxi(GameState.party_size(), 1)
	_ztats_cursor = posmod(_ztats_cursor + delta, n)
	_sync_ztats_selection()


func _sync_ztats_selection() -> void:
	if _roster:
		_roster.set_order_selection(_ztats_cursor, -1)


func _accept_ztats_slot(slot: int) -> void:
	if slot < 0 or slot >= GameState.party_size():
		_close_ztats(true)
		return
	var name := GameState.party_member_display_name(slot)
	_push_message(Locale.t("cmd_ztats_for_done", [name]), false)
	_show_ztats_member(slot)


func _show_ztats_member(slot: int) -> void:
	_ensure_ztats_panel()
	_ztats_stage = 2
	_ztats_cursor = slot
	_ztats_flat = slot
	_clear_order_selection()
	_layout_prompt_row()
	## Reuse the open character panel chrome — swap roster for sheet content.
	if _right_top:
		_right_top.visible = true
	if _compact_pane:
		_compact_pane.visible = false
	if _roster:
		_roster.visible = false
	_order_opened_roster = true
	if _ztats_panel:
		_ztats_panel.open_member(slot)


func _try_ztats_inv_scroll(event: InputEvent) -> bool:
	## Keyboard scroll for gear/mixtures: ↑↓, PageUp/Down (×5), Home/End.
	if _ztats_panel == null or not _ztats_panel.is_inventory_page():
		return false
	const PAGE_LINES := 5
	## allow_echo=true so held keys keep scrolling.
	if event.is_action_pressed("move_up", true):
		_ztats_panel.scroll_inventory(-1)
		return true
	if event.is_action_pressed("move_down", true):
		_ztats_panel.scroll_inventory(1)
		return true
	if event is InputEventKey:
		var k := event as InputEventKey
		var code := k.keycode
		var phys := k.physical_keycode
		if code == KEY_UP or phys == KEY_UP:
			_ztats_panel.scroll_inventory(-1)
			return true
		if code == KEY_DOWN or phys == KEY_DOWN:
			_ztats_panel.scroll_inventory(1)
			return true
		if code == KEY_PAGEUP or phys == KEY_PAGEUP:
			_ztats_panel.scroll_inventory(-PAGE_LINES)
			return true
		if code == KEY_PAGEDOWN or phys == KEY_PAGEDOWN:
			_ztats_panel.scroll_inventory(PAGE_LINES)
			return true
		if code == KEY_HOME or phys == KEY_HOME:
			_ztats_panel.scroll_inventory_home()
			return true
		if code == KEY_END or phys == KEY_END:
			_ztats_panel.scroll_inventory_end()
			return true
	return false


func _show_ztats_inventory(page: int) -> void:
	_ensure_ztats_panel()
	_ztats_stage = 2
	var party_n := maxi(GameState.party_size(), 1)
	match page:
		ZtatsPanel.InvPage.GEAR:
			_ztats_flat = party_n
		ZtatsPanel.InvPage.REAGENTS:
			_ztats_flat = party_n + 1
		_:
			_ztats_flat = party_n + 2
	_clear_order_selection()
	_layout_prompt_row()
	if _right_top:
		_right_top.visible = true
	if _compact_pane:
		_compact_pane.visible = false
	if _roster:
		_roster.visible = false
	_order_opened_roster = true
	if _ztats_panel:
		_ztats_panel.open_inventory(page)


func _close_ztats(show_none: bool) -> void:
	var was := _ztats_stage
	_ztats_stage = 0
	_ztats_cursor = 0
	_ztats_flat = 0
	_clear_order_selection()
	if _ztats_panel:
		_ztats_panel.close_panel()
	if _roster:
		_roster.visible = true
	if was != 0:
		_close_order_roster()
	elif _order_opened_roster and _order_stage == 0 and _ready_stage == 0 and _wear_stage == 0:
		_close_order_roster()
	_layout_prompt_row()
	if show_none and was == 1:
		_push_message(Locale.t("cmd_none"), false)


func _ensure_ready_panel() -> void:
	if _ready_panel != null:
		return
	var host := get_node_or_null("RootCol/MapPane/RightTopPane/RightTopMargin") as Control
	if host == null:
		return
	_ready_panel = ReadyPanel.new()
	_ready_panel.name = "ReadyPanel"
	_ready_panel.visible = false
	_ready_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(_ready_panel)


func _do_ready() -> void:
	## xu4 readyWeapon(): "Ready a weapon for: " → pick member → weapon list.
	_clear_pending_order()
	_close_ztats(false)
	_close_wear(false)
	if GameState.party_size() <= 0:
		_push_message(Locale.t("cmd_none"), false)
		return
	_open_order_roster()
	_ready_stage = 1
	_ready_cursor = 0
	_ready_slot = -1
	_reset_hold_state()
	if _roster:
		_roster.visible = true
	if _ready_panel:
		_ready_panel.close_panel()
	_sync_ready_selection()
	_layout_prompt_row()


func _handle_ready_input(event: InputEvent) -> bool:
	if not event.is_pressed():
		return false
	if event.is_echo():
		return false
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
			_on_escape()
			return true
	if _ready_stage == 2:
		return _handle_ready_weapon_input(event)
	## Pick member — same affordances as Ztats / New Order.
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		_close_ready(true)
		return true
	if event.is_action_pressed("cancel") and event is InputEventJoypadButton:
		_close_ready(true)
		return true
	if event is InputEventKey and _is_order_cancel_key(event as InputEventKey):
		_close_ready(true)
		return true
	if event is InputEventKey and _is_order_confirm_key(event as InputEventKey):
		_accept_ready_slot(_ready_cursor)
		return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
		_accept_ready_slot(_ready_cursor)
		return true
	if event is InputEventKey:
		var ke := event as InputEventKey
		var pick := _player_slot_from_key(ke)
		if pick < 0:
			if _is_digit_key(ke):
				_close_ready(true)
			return true
		_accept_ready_slot(pick)
		return true
	return true


func _handle_ready_weapon_input(event: InputEvent) -> bool:
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		_close_ready(true)
		return true
	if event.is_action_pressed("cancel") and event is InputEventJoypadButton:
		_close_ready(true)
		return true
	if event is InputEventKey and _is_order_cancel_key(event as InputEventKey):
		_close_ready(true)
		return true
	if event is InputEventKey and _is_order_confirm_key(event as InputEventKey):
		_confirm_ready_cursor()
		return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
		_confirm_ready_cursor()
		return true
	## Letter A–P selects that weapon index (xu4 readAlphaAction).
	if event is InputEventKey:
		var k := event as InputEventKey
		var letter := _ready_letter_from_key(k)
		if letter >= 0:
			_try_ready_weapon(letter)
			return true
		## R while picking weapon → back to member pick (like Ztats Z).
		if k.keycode == KEY_R or k.physical_keycode == KEY_R:
			_return_ready_to_pick()
			return true
	return true


func _ready_letter_from_key(k: InputEventKey) -> int:
	## Returns weapon id 0..15 for A–P, else -1.
	for code in [k.keycode, k.physical_keycode, k.unicode]:
		if code >= KEY_A and code <= KEY_P:
			return code - KEY_A
		if code >= 65 and code <= 80: ## 'A'..'P'
			return code - 65
		if code >= 97 and code <= 112: ## 'a'..'p'
			return code - 97
	return -1


func _tick_ready_weapon_cursor() -> void:
	var step := _read_select_step()
	if step == 0:
		_reset_hold_state()
		return
	var held := Vector2i(0, step)
	if held != _held_dir:
		_held_dir = held
		_move_repeating = false
		_hold_arm = 0.0
	if _move_cd > 0.0:
		return
	if _move_repeating and _hold_arm > 0.0:
		return
	if _ready_panel:
		_ready_panel.nudge_cursor(step)
	_arm_hold_after_step()


func _nudge_ready_cursor(delta: int) -> void:
	var n := maxi(GameState.party_size(), 1)
	_ready_cursor = posmod(_ready_cursor + delta, n)
	_sync_ready_selection()


func _sync_ready_selection() -> void:
	if _roster:
		_roster.set_order_selection(_ready_cursor, -1)


func _accept_ready_slot(slot: int) -> void:
	var n := GameState.party_size()
	if slot < 0 or slot >= n:
		_close_ready(true)
		return
	_ready_slot = slot
	var pname := GameState.party_member_display_name(slot)
	_push_message(Locale.t("cmd_ready_for_done", [pname]), false)
	_show_ready_weapons(slot)


func _show_ready_weapons(slot: int) -> void:
	_ensure_ready_panel()
	_ready_stage = 2
	_reset_hold_state()
	_clear_order_selection()
	if _roster:
		_roster.visible = false
	if _right_top:
		_right_top.visible = true
	if _compact_pane:
		_compact_pane.visible = false
	_order_opened_roster = true
	if _ready_panel:
		_ready_panel.open_for(slot)
	_layout_prompt_row()


func _return_ready_to_pick() -> void:
	_ready_stage = 1
	_ready_slot = -1
	_reset_hold_state()
	if _ready_panel:
		_ready_panel.close_panel()
	if _roster:
		_roster.visible = true
	if _right_top:
		_right_top.visible = true
	if _compact_pane:
		_compact_pane.visible = false
	_order_opened_roster = true
	_sync_ready_selection()
	_layout_prompt_row()


func _confirm_ready_cursor() -> void:
	if _ready_panel == null:
		return
	var wid := _ready_panel.cursor_weapon_id()
	if wid < 0:
		return
	_try_ready_weapon(wid)


func _try_ready_weapon(weapon_id: int) -> void:
	if _ready_slot < 0:
		return
	var err := GameState.ready_weapon(_ready_slot, weapon_id)
	match err:
		GameState.EquipError.NONE_LEFT:
			_push_message(Locale.t("cmd_ready_none"), false)
		GameState.EquipError.CLASS_RESTRICTED:
			_push_message(_ready_restricted_message(_ready_slot, weapon_id), false)
		_:
			_push_message(Locale.t("cmd_ready_done", [Locale.weapon_name(weapon_id)]), false)
			_close_ready(false)


func _ready_restricted_message(slot: int, weapon_id: int) -> String:
	var klass := GameState.party_member_at(slot)
	var cname := Virtues.class_name_of(klass, GameState.lang_short())
	var wname := Locale.weapon_name(weapon_id)
	if GameState.language == "ko":
		return Locale.t("cmd_ready_restricted", [cname, wname])
	var article := "an" if _weapon_starts_vowel(wname) else "a"
	return Locale.t("cmd_ready_restricted", [cname, article, wname])


func _weapon_starts_vowel(name: String) -> bool:
	if name.is_empty():
		return false
	var ch := name.substr(0, 1).to_lower()
	return ch in ["a", "e", "i", "o", "u", "y"]


func _close_ready(show_none: bool) -> void:
	var was := _ready_stage
	_ready_stage = 0
	_ready_cursor = 0
	_ready_slot = -1
	_clear_order_selection()
	if _ready_panel:
		_ready_panel.close_panel()
	if _roster:
		_roster.visible = true
	if was != 0:
		_close_order_roster()
	elif _order_opened_roster and _order_stage == 0 and _ztats_stage == 0 and _wear_stage == 0:
		_close_order_roster()
	_layout_prompt_row()
	if show_none and was == 1:
		_push_message(Locale.t("cmd_none"), false)


func _ensure_wear_panel() -> void:
	if _wear_panel != null:
		return
	var host := get_node_or_null("RootCol/MapPane/RightTopPane/RightTopMargin") as Control
	if host == null:
		return
	_wear_panel = WearPanel.new()
	_wear_panel.name = "WearPanel"
	_wear_panel.visible = false
	_wear_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(_wear_panel)


func _do_wear() -> void:
	## xu4 wearArmor(): "Wear Armour for: " → pick member → armor list.
	_clear_pending_order()
	_close_ztats(false)
	_close_ready(false)
	if GameState.party_size() <= 0:
		_push_message(Locale.t("cmd_none"), false)
		return
	_open_order_roster()
	_wear_stage = 1
	_wear_cursor = 0
	_wear_slot = -1
	_reset_hold_state()
	if _roster:
		_roster.visible = true
	if _wear_panel:
		_wear_panel.close_panel()
	_sync_wear_selection()
	_layout_prompt_row()


func _handle_wear_input(event: InputEvent) -> bool:
	if not event.is_pressed():
		return false
	if event.is_echo():
		return false
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
			_on_escape()
			return true
	if _wear_stage == 2:
		return _handle_wear_armor_input(event)
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		_close_wear(true)
		return true
	if event.is_action_pressed("cancel") and event is InputEventJoypadButton:
		_close_wear(true)
		return true
	if event is InputEventKey and _is_order_cancel_key(event as InputEventKey):
		_close_wear(true)
		return true
	if event is InputEventKey and _is_order_confirm_key(event as InputEventKey):
		_accept_wear_slot(_wear_cursor)
		return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
		_accept_wear_slot(_wear_cursor)
		return true
	if event is InputEventKey:
		var ke := event as InputEventKey
		var pick := _player_slot_from_key(ke)
		if pick < 0:
			if _is_digit_key(ke):
				_close_wear(true)
			return true
		_accept_wear_slot(pick)
		return true
	return true


func _handle_wear_armor_input(event: InputEvent) -> bool:
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		_close_wear(true)
		return true
	if event.is_action_pressed("cancel") and event is InputEventJoypadButton:
		_close_wear(true)
		return true
	if event is InputEventKey and _is_order_cancel_key(event as InputEventKey):
		_close_wear(true)
		return true
	if event is InputEventKey and _is_order_confirm_key(event as InputEventKey):
		_confirm_wear_cursor()
		return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
		_confirm_wear_cursor()
		return true
	## Letter A–H selects that armor index (xu4 readAlphaAction).
	if event is InputEventKey:
		var k := event as InputEventKey
		var letter := _wear_letter_from_key(k)
		if letter >= 0:
			_try_wear_armor(letter)
			return true
		## W while picking armor → back to member pick.
		if k.keycode == KEY_W or k.physical_keycode == KEY_W:
			_return_wear_to_pick()
			return true
	return true


func _wear_letter_from_key(k: InputEventKey) -> int:
	## Returns armor id 0..7 for A–H, else -1.
	for code in [k.keycode, k.physical_keycode, k.unicode]:
		if code >= KEY_A and code <= KEY_H:
			return code - KEY_A
		if code >= 65 and code <= 72: ## 'A'..'H'
			return code - 65
		if code >= 97 and code <= 104: ## 'a'..'h'
			return code - 97
	return -1


func _tick_wear_armor_cursor() -> void:
	var step := _read_select_step()
	if step == 0:
		_reset_hold_state()
		return
	var held := Vector2i(0, step)
	if held != _held_dir:
		_held_dir = held
		_move_repeating = false
		_hold_arm = 0.0
	if _move_cd > 0.0:
		return
	if _move_repeating and _hold_arm > 0.0:
		return
	if _wear_panel:
		_wear_panel.nudge_cursor(step)
	_arm_hold_after_step()


func _nudge_wear_cursor(delta: int) -> void:
	var n := maxi(GameState.party_size(), 1)
	_wear_cursor = posmod(_wear_cursor + delta, n)
	_sync_wear_selection()


func _sync_wear_selection() -> void:
	if _roster:
		_roster.set_order_selection(_wear_cursor, -1)


func _accept_wear_slot(slot: int) -> void:
	var n := GameState.party_size()
	if slot < 0 or slot >= n:
		_close_wear(true)
		return
	_wear_slot = slot
	var pname := GameState.party_member_display_name(slot)
	_push_message(Locale.t("cmd_wear_for_done", [pname]), false)
	_show_wear_armor(slot)


func _show_wear_armor(slot: int) -> void:
	_ensure_wear_panel()
	_wear_stage = 2
	_reset_hold_state()
	_clear_order_selection()
	if _roster:
		_roster.visible = false
	if _right_top:
		_right_top.visible = true
	if _compact_pane:
		_compact_pane.visible = false
	_order_opened_roster = true
	if _wear_panel:
		_wear_panel.open_for(slot)
	_layout_prompt_row()


func _return_wear_to_pick() -> void:
	_wear_stage = 1
	_wear_slot = -1
	_reset_hold_state()
	if _wear_panel:
		_wear_panel.close_panel()
	if _roster:
		_roster.visible = true
	if _right_top:
		_right_top.visible = true
	if _compact_pane:
		_compact_pane.visible = false
	_order_opened_roster = true
	_sync_wear_selection()
	_layout_prompt_row()


func _confirm_wear_cursor() -> void:
	if _wear_panel == null:
		return
	var aid: int = _wear_panel.cursor_armor_id()
	if aid < 0:
		return
	_try_wear_armor(aid)


func _try_wear_armor(armor_id: int) -> void:
	if _wear_slot < 0:
		return
	var err := GameState.wear_armor(_wear_slot, armor_id)
	match err:
		GameState.EquipError.NONE_LEFT:
			_push_message(Locale.t("cmd_wear_none"), false)
		GameState.EquipError.CLASS_RESTRICTED:
			_push_message(_wear_restricted_message(_wear_slot, armor_id), false)
		_:
			_push_message(Locale.t("cmd_wear_done", [Locale.armor_name(armor_id)]), false)
			_close_wear(false)


func _wear_restricted_message(slot: int, armor_id: int) -> String:
	var klass := GameState.party_member_at(slot)
	var cname := Virtues.class_name_of(klass, GameState.lang_short())
	var aname := Locale.armor_name(armor_id)
	return Locale.t("cmd_wear_restricted", [cname, aname])


func _close_wear(show_none: bool) -> void:
	var was := _wear_stage
	_wear_stage = 0
	_wear_cursor = 0
	_wear_slot = -1
	_clear_order_selection()
	if _wear_panel:
		_wear_panel.close_panel()
	if _roster:
		_roster.visible = true
	if was != 0:
		_close_order_roster()
	elif _order_opened_roster and _order_stage == 0 and _ztats_stage == 0 and _ready_stage == 0:
		_close_order_roster()
	_layout_prompt_row()
	if show_none and was == 1:
		_push_message(Locale.t("cmd_none"), false)


func _handle_order_input(event: InputEvent) -> bool:
	## Digits / ↑↓+Enter / gamepad D-pad+A. Space/B/Esc cancel.
	## Returns true if the event was consumed.
	if event.is_echo() or not event.is_pressed():
		return false
	## Esc → full cancel via _on_escape path.
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
			_on_escape()
			return true
	## B / cancel action (not keyboard Space — handled below).
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		_clear_pending_order(true)
		return true
	if event.is_action_pressed("cancel") and event is InputEventJoypadButton:
		_clear_pending_order(true)
		return true
	## Keyboard Space cancels (Enter / pad A confirms).
	if event is InputEventKey and _is_order_cancel_key(event as InputEventKey):
		_clear_pending_order(true)
		return true
	## Confirm: Enter or gamepad A (JOY_BUTTON_A = 0). Avoid `confirm` action — it includes Space.
	if event is InputEventKey and _is_order_confirm_key(event as InputEventKey):
		_accept_order_slot(_order_cursor)
		return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
		_accept_order_slot(_order_cursor)
		return true
	## ↑↓ are polled in _tick_select_cursor (hold-repeat like world move).
	if event is InputEventKey:
		var slot := _player_slot_from_key(event as InputEventKey)
		if slot < 0:
			if _is_digit_key(event as InputEventKey):
				_clear_pending_order(true)
				return true
			return false
		_order_cursor = slot
		_accept_order_slot(slot)
		return true
	return false


func _is_order_cancel_key(event: InputEventKey) -> bool:
	## Space cancels (Enter confirms via cursor). Esc handled separately.
	var code := event.keycode
	var phys := event.physical_keycode
	return code == KEY_SPACE or phys == KEY_SPACE


func _is_order_confirm_key(event: InputEventKey) -> bool:
	var code := event.keycode
	var phys := event.physical_keycode
	return (
		code == KEY_ENTER or phys == KEY_ENTER
		or code == KEY_KP_ENTER or phys == KEY_KP_ENTER
	)


func _nudge_order_cursor(delta: int) -> void:
	var n := maxi(GameState.party_size(), 1)
	_order_cursor = posmod(_order_cursor + delta, n)
	_sync_order_selection()


func _sync_order_selection() -> void:
	if _roster == null:
		return
	var locked := _order_slot_a if _order_stage == 2 else -1
	_roster.set_order_selection(_order_cursor, locked)


func _clear_order_selection() -> void:
	if _roster:
		_roster.clear_order_selection()


func _is_digit_key(event: InputEventKey) -> bool:
	var code := event.keycode
	var phys := event.physical_keycode
	return (
		(code >= KEY_0 and code <= KEY_9)
		or (phys >= KEY_0 and phys <= KEY_9)
		or (code >= KEY_KP_0 and code <= KEY_KP_9)
		or (phys >= KEY_KP_0 and phys <= KEY_KP_9)
	)


func _is_ztats_equipment_key(event: InputEventKey) -> bool:
	## xu4: 0 opens Weapons / equipment list.
	var code := event.keycode
	var phys := event.physical_keycode
	return (
		code == KEY_0 or phys == KEY_0
		or code == KEY_KP_0 or phys == KEY_KP_0
	)


func _player_slot_from_key(event: InputEventKey) -> int:
	## 1..party_size → 0-based slot; else -1 (xu4 None).
	var n := -1
	var code := event.keycode
	var phys := event.physical_keycode
	if code >= KEY_1 and code <= KEY_8:
		n = code - KEY_1
	elif phys >= KEY_1 and phys <= KEY_8:
		n = phys - KEY_1
	elif code >= KEY_KP_1 and code <= KEY_KP_8:
		n = code - KEY_KP_1
	elif phys >= KEY_KP_1 and phys <= KEY_KP_8:
		n = phys - KEY_KP_1
	if n < 0 or n >= GameState.party_size():
		return -1
	return n


func _accept_order_slot(slot: int) -> void:
	var name := GameState.party_member_display_name(slot)
	if _order_stage == 1:
		_push_message(Locale.t("cmd_exchange_done", [name]), false)
		_order_slot_a = slot
		_order_stage = 2
		_order_cursor = slot
		_sync_order_selection()
		_layout_prompt_row()
		return
	## Stage 2 — picking the second member.
	if slot == _order_slot_a:
		## Re-selecting the first pick clears it (stay in New Order).
		_order_stage = 1
		_order_slot_a = -1
		_order_cursor = slot
		_sync_order_selection()
		_layout_prompt_row()
		return
	_push_message(Locale.t("cmd_with_done", [name]), false)
	var a := _order_slot_a
	_order_stage = 0
	_order_slot_a = -1
	_clear_order_selection()
	_layout_prompt_row()
	if not GameState.swap_party_members(a, slot):
		_push_message(Locale.t("cmd_what"), false)
		_close_order_roster()
		return
	_refresh_party()
	## Hold the roster briefly so the new order is visible; input stays free.
	_schedule_order_roster_close()


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
