class_name IntroController
extends Node

## Port of xu4/ScummVM IntroController: TITLES → MAP → MENU (map+options only).

signal mode_changed(mode: int)

enum Mode { TITLES, MAP, MENU }

enum AnimType { SIGNATURE, AND, BAR, ORIGIN, PRESENT, TITLE, SUBTITLE, SETTLE, MAP }

const BASE_W := 320
const BASE_H := 200
## Game tiles are 32×32 source; classic intro used 16×16. Present at 2× for sharp art.
const SCALE := 2
const LOGIC_W := BASE_W * SCALE
const LOGIC_H := BASE_H * SCALE
const MAP_W := 19
const MAP_H := 5
const TILE_CLASSIC := 16
const TILE_PX := 32 ## U4TileBank native edge length
## Native Apple II display aspect used by every tileset.
const TILE_ASPECT := 14.0 / 16.0
const TILE_CELL_H := TILE_PX
const MAP_X_BASE := 8 ## Original 320×200 TITLE.EGA transition coordinates
const MAP_Y_BASE := 104 ## BORDER + 6×classic tile
const MAP_HOLE_H := 5 * TILE_CLASSIC * SCALE
const MAP_DRAW_H := MAP_H * TILE_CELL_H
const MAP_Y := MAP_Y_BASE * SCALE + (MAP_HOLE_H - MAP_DRAW_H) / 2
const OPTIONS_BTM_Y := 120 * SCALE
## Thin dialogue-style frame around intro map tiles (not TITLE.EGA ornament).
## Matches stub_world / StatusInfoBar blue edge: Color(0.35, 0.55, 0.95).
const MAP_FRAME_COL := Color(0.35, 0.55, 0.95, 1.0)
const MAP_FRAME_BORDER := 2 ## dialogue-like line thickness (logic px)
const MAP_FRAME_PAD := 4 ## gap between border and tiles / menu content
## User title plate (640×400): Lord British through Quest, above the map bezel.
const TITLE_PLATE_PATH := "res://assets/intro/title_plate.png"
## Plate art: Quest of the Avatar runs through ~y=190; map bezel begins at y=192.
const TITLE_PLATE_H := 192
## Wipe classic TITLE.EGA map hole/bezel from the first bezel row. EGA Quest ended at
## y=93 (base), so 94*SCALE used to work — title_plate Quest extends to ~190, so wipe
## must start at 96*SCALE (= TITLE_PLATE_H) or the subtitle bottom is clipped.
const MAP_CHROME_Y0 := 96 * SCALE
## Shore freckles (same rules/assets as MapView).
const WATER_TILE_MAX := 2
const SHORE_MASK_DIR := "res://assets/tiles/u4graphics/masks"
const SHORE_BIT_N := 1
const SHORE_BIT_E := 2
const SHORE_BIT_S := 4
const SHORE_BIT_W := 8
const SHORE_EDGE_DEPTH := 5
const SHORE_CORNER_DEPTH := 8
const SHORE_COLOR_SCALE := 0.35
const BEAST0_W := 55
const BEAST0_H := 31
const BEAST1_W := 48
const BEAST1_H := 31
const TRANSPARENT_INDEX := 13
const MAP_TICK := 0.10
const WATER_SCROLL_PERIOD := 0.12
## Match MapView creature / multi-frame tile flip cadence.
const TILE_ANIM_PERIOD := 0.20
## xu4 shapes 064–067 — intro script advances phases; open gate (067) swirls like MapView.
const TILE_MOONGATE_0 := 64
const TILE_MOONGATE_OPEN := 67
const MOONGATE_SUCK_FRAMES := 24
const MOONGATE_SUCK_PERIOD := 0.06
## TITLE.EXE intro object base 12 = shape 077 (missile). Match wilderness ship fire art.
const TILE_MISSILE := 77
const CANNONBALL_PATH := "res://assets/tiles/cannonball.png"
const _ResImage := preload("res://src/core/res_image.gd")

const _IntroBinData := preload("res://src/intro/intro_bin_data.gd")
const _U4Lzw := preload("res://src/intro/u4_lzw_image.gd")
const _TileBank := preload("res://src/map/u4_tile_bank.gd")
const _Apple2HgrNtsc := preload("res://src/map/apple2_hgr_ntsc.gd")
const _WorldCreatures := preload("res://src/map/world_creatures.gd")

var mode: int = Mode.TITLES

var _bin: RefCounted ## IntroBinData
var _title_base: Image ## Fixed 320×200 after fixup (title-sequence space)
var _title_img: Image ## LOGIC-scale nearest (map/menu background + frame)
var _title_plate: Image ## 640×400 still: Lord British → Quest of the Avatar
var _options_btm: Image
var _beast0: Array = [] ## 18 Images (display-scale)
var _beast1: Array = []
var _tile_cache: Dictionary = {} ## keyed by paint params → Image
var _shore_cache: Dictionary = {} ## mask name → Image
var _apple2_map_img: Image ## 19×5 continuous HGR map at final intro aspect
var _apple2_map_scroll := -1
var _water_scroll := 0
var _water_cd := WATER_SCROLL_PERIOD
var _tile_anim_frame := 0
var _tile_anim_cd := TILE_ANIM_PERIOD
var _moongate_suck_frames: Array = [] ## Array[Image] full-open swirl cycle
var _moongate_suck_i := 0
var _moongate_suck_cd := MOONGATE_SUCK_PERIOD
var _moongate_col_blue := Color(0.15, 0.4, 1.0, 1.0)
var _moongate_col_white := Color(1, 1, 1, 1)
## Same sprite as MapView flying cannon (`cannonball.png`), not 077_missile red orb.
var _cannonball_img: Image

var _canvas: Image
var _tex: ImageTexture
var _view: TextureRect

var _obj_x: PackedByteArray
var _obj_y: PackedByteArray
var _obj_tile: PackedInt32Array
var _obj_frame: PackedInt32Array
var _obj_active: PackedByteArray

var _scr_pos := 0
var _sleep_cycles := 0
var _map_accum := 0.0
var _beastie1_cycle := 0
var _beastie2_cycle := 0
var _beastie_offset := -32
var _beasties_visible := false
var _skip_titles := false
var _title_fade_started := false
## 0 = EGA construction, 1 = title plate fully revealed (Lord British → Quest).
var _title_plate_t := 0.0

## Title sequence state (coordinates are base 320×200)
var _titles: Array = [] ## Dictionaries
var _title_i := 0
var _accum: Image ## permanent title paints (BASE_W × BASE_H)
var _title_time0_ms := 0
var _title_ready := false
## True once title sequence paints (incl. Lord British) were frozen into `_title_img`.
var _title_bg_baked := false


func setup(view: TextureRect) -> bool:
	_view = view
	_canvas = Image.create(LOGIC_W, LOGIC_H, false, Image.FORMAT_RGBA8)
	_canvas.fill(Color.BLACK)
	_tex = ImageTexture.create_from_image(_canvas)
	_view.texture = _tex
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var data_dir := str(GameState.u4_data_path)
	if data_dir.is_empty():
		data_dir = ProjectSettings.globalize_path("res://data/u4")
	var title_exe := data_dir.path_join("TITLE.EXE")
	var title_ega := data_dir.path_join("TITLE.EGA")
	var animate_ega := data_dir.path_join("ANIMATE.EGA")

	_bin = _IntroBinData.new()
	if not _bin.load_from_path(title_exe):
		push_warning("IntroController: failed TITLE.EXE blobs")
		return false

	_title_base = _U4Lzw.load_ega_path(title_ega, -1)
	var animate_img: Image = _U4Lzw.load_ega_path(animate_ega, 0)
	if _title_base == null or animate_img == null:
		push_warning("IntroController: EGA load failed")
		return false

	## TITLE.EGA stores "PRESENT" at top; xu4 fixupIntro moves it above Ultima IV.
	_fixup_intro_title(_title_base)
	## EGA title is cyan/blue bands; remap to chrome silver (tools/_title_*.png are dumps only).
	_recolor_ultima_title_silver(_title_base)

	## 2× nearest keeps the map frame matching a 19×5 grid of 32² tiles.
	_title_img = _title_base.duplicate()
	_title_img.resize(LOGIC_W, LOGIC_H, Image.INTERPOLATE_NEAREST)
	_title_plate = _ResImage.load_rgba8(TITLE_PLATE_PATH)
	if _title_plate == null or _title_plate.is_empty():
		push_warning("IntroController: title plate missing at %s" % TITLE_PLATE_PATH)
		_title_plate = null
	elif _title_plate.get_width() != LOGIC_W or _title_plate.get_height() != LOGIC_H:
		_title_plate.resize(LOGIC_W, LOGIC_H, Image.INTERPOLATE_BILINEAR)

	var opt320 := _U4Lzw.crop(_title_base, 0, 112, 320, 80)
	_options_btm = opt320.duplicate() if opt320 else null
	if _options_btm:
		_options_btm.resize(LOGIC_W, 80 * SCALE, Image.INTERPOLATE_NEAREST)

	_beast0.clear()
	_beast1.clear()
	for fi in 18:
		var col0 := fi / 6
		var row0 := fi % 6
		var b0 := _U4Lzw.crop(animate_img, col0 * 56, row0 * 32, BEAST0_W, BEAST0_H)
		var b1 := _U4Lzw.crop(animate_img, 176 + (fi / 6) * 48, (fi % 6) * 32, BEAST1_W, BEAST1_H)
		_beast0.append(_scale_nearest(b0, SCALE))
		_beast1.append(_scale_nearest(b1, SCALE))

	_cannonball_img = _load_cannonball_image()

	_TileBank.ensure_loaded()
	_reset_objects()
	_init_titles()
	set_mode(Mode.TITLES)
	set_process(true)
	return true


func _scale_nearest(src: Image, factor: int) -> Image:
	if src == null or src.is_empty():
		return null
	if factor <= 1:
		return src
	var out := src.duplicate()
	out.resize(src.get_width() * factor, src.get_height() * factor, Image.INTERPOLATE_NEAREST)
	return out


func set_mode(m: int) -> void:
	mode = m
	if m == Mode.TITLES:
		_beasties_visible = false
		_beastie_offset = -32
		_title_i = 0
		_skip_titles = false
		_title_fade_started = false
		_title_plate_t = 0.0
		_title_bg_baked = false
		_accum = Image.create(BASE_W, BASE_H, false, Image.FORMAT_RGBA8)
		_accum.fill(Color.BLACK)
		_title_time0_ms = Time.get_ticks_msec()
		if not _titles.is_empty():
			_titles[0]["time_base"] = 0
			_titles[0]["anim_step"] = 0
		_title_ready = true
	elif m == Mode.MAP:
		## Keep Lord British / title paints — raw TITLE.EGA lacks the signature.
		_bake_titles_into_map_bg()
		_beasties_visible = true
		_beastie_offset = -32
		_scr_pos = 0
		_sleep_cycles = 0
		_map_accum = 0.0
		_tile_anim_frame = 0
		_tile_anim_cd = TILE_ANIM_PERIOD
		_reset_objects()
	elif m == Mode.MENU:
		_beasties_visible = true
		if _beastie_offset < 0:
			_beastie_offset = 0
	mode_changed.emit(mode)
	_redraw()


## Freeze the title-sequence framebuffer as the map/menu backdrop.
## Signature ("Lord British") is plotted into `_accum` during TITLES and is not
## present in TITLE.EGA alone — without this, MAP mode would wipe it away.
func _bake_titles_into_map_bg() -> void:
	if _title_bg_baked:
		return
	if _accum == null or _accum.is_empty():
		return
	_title_img = _accum.duplicate()
	_title_img.resize(LOGIC_W, LOGIC_H, Image.INTERPOLATE_NEAREST)
	_apply_title_plate_to(_title_img)
	_title_bg_baked = true


func skip_titles_or_advance() -> void:
	match mode:
		Mode.TITLES:
			var settle_idx := _title_index_of(AnimType.SETTLE)
			var map_idx := _title_index_of(AnimType.MAP)
			## First key: snap to the finished logos (Ultima IV + Quest). Second: map.
			if settle_idx >= 0 and _title_i <= settle_idx:
				_skip_titles = true
				AudioSfx.stop_title_fade()
				var guard := 0
				while _title_i <= settle_idx and _update_titles() and guard < 80:
					guard += 1
				_skip_titles = false
				_title_plate_t = 1.0
				if map_idx >= 0 and _title_i == map_idx:
					_titles[map_idx]["time_base"] = 0
					_titles[map_idx]["anim_step"] = 0
					_titles[map_idx]["time_delay"] = 400
				_redraw()
				return
			_skip_titles = true
			AudioSfx.stop_title_fade()
			_title_plate_t = 1.0
			var rest := 0
			while _update_titles() and rest < 64:
				rest += 1
			set_mode(Mode.MAP)
		Mode.MAP:
			set_mode(Mode.MENU)
		_:
			pass


func return_to_map() -> void:
	if mode == Mode.MENU:
		set_mode(Mode.MAP)


func reload_tileset_graphics() -> void:
	## Options → Graphics: bank already swapped; force a map frame redraw.
	_TileBank.ensure_loaded()
	_tile_cache.clear()
	_moongate_suck_frames.clear()
	_apple2_map_img = null
	_apple2_map_scroll = -1
	_redraw()


func _process(delta: float) -> void:
	if mode == Mode.TITLES:
		if not _update_titles():
			set_mode(Mode.MAP)
			return
		_redraw()
	elif mode == Mode.MAP or mode == Mode.MENU:
		_map_accum += delta
		_water_cd -= delta
		if _water_cd <= 0.0:
			_water_cd = WATER_SCROLL_PERIOD
			_water_scroll = (_water_scroll + 1) % TILE_PX
		_tile_anim_cd -= delta
		if _tile_anim_cd <= 0.0:
			_tile_anim_cd = TILE_ANIM_PERIOD
			_tile_anim_frame += 1
		## Apple II Color/Mono keep their static source tile.
		if _TileBank.uses_moongate_suck():
			_moongate_suck_cd -= delta
			if _moongate_suck_cd <= 0.0:
				_moongate_suck_cd = MOONGATE_SUCK_PERIOD
				_moongate_suck_i = (_moongate_suck_i + 1) % maxi(1, MOONGATE_SUCK_FRAMES)
		while _map_accum >= MAP_TICK:
			_map_accum -= MAP_TICK
			if mode == Mode.MAP or mode == Mode.MENU:
				_tick_map()
			if _beasties_visible:
				if randi() & 1:
					_beastie1_cycle = (_beastie1_cycle + 1) % _IntroBinData.BEASTIE1_FRAMES
				if randi() & 1:
					_beastie2_cycle = (_beastie2_cycle + 1) % _IntroBinData.BEASTIE2_FRAMES
				if _beastie_offset < 0:
					_beastie_offset += 1
		_redraw()


func _reset_objects() -> void:
	var n: int = _IntroBinData.BASE_TILE_COUNT
	_obj_x = PackedByteArray()
	_obj_y = PackedByteArray()
	_obj_tile = PackedInt32Array()
	_obj_frame = PackedInt32Array()
	_obj_active = PackedByteArray()
	_obj_x.resize(n)
	_obj_y.resize(n)
	_obj_tile.resize(n)
	_obj_frame.resize(n)
	_obj_active.resize(n)
	for i in n:
		_obj_x[i] = 0
		_obj_y[i] = 0
		_obj_tile[i] = 0
		_obj_frame[i] = 0
		_obj_active[i] = 0


func _tick_map() -> void:
	if _sleep_cycles > 0:
		_sleep_cycles -= 1
		return
	var script: PackedByteArray = _bin.script_table
	var base_tiles: PackedByteArray = _bin.base_tiles
	var guard := 0
	while guard < 600:
		guard += 1
		if _scr_pos >= script.size():
			_scr_pos = 0
		var cmd: int = script[_scr_pos] >> 4
		match cmd:
			0, 1, 2, 3, 4:
				if _scr_pos + 1 >= script.size():
					_scr_pos = 0
					return
				var idx: int = script[_scr_pos] & 0xf
				var second: int = script[_scr_pos + 1]
				_obj_x[idx] = second & 0x1f
				_obj_y[idx] = cmd
				## Script frame = classic consecutive shape cells (moongate/ship/facing).
				var want_frame: int = second >> 5
				var base_id: int = base_tiles[idx] if idx < base_tiles.size() else 0
				var resolved := _resolve_script_tile_frame(base_id, want_frame)
				_obj_tile[idx] = resolved.x
				_obj_frame[idx] = resolved.y
				_obj_active[idx] = 1
				_scr_pos += 2
			7:
				var di: int = script[_scr_pos] & 0xf
				_obj_active[di] = 0
				_obj_tile[di] = 0
				_scr_pos += 1
			8:
				_sleep_cycles = script[_scr_pos] & 0xf
				_scr_pos += 1
				return
			0xf:
				_scr_pos = 0
			_:
				_scr_pos += 1


func _redraw() -> void:
	if _canvas == null:
		return
	match mode:
		Mode.TITLES:
			## Title sequence is authored in 320×200; present at 2× (nearest) for the view.
			_present_scaled(_accum)
			if _title_plate_t > 0.0:
				_overlay_title_plate(_title_plate_t)
			## MAP curtains would otherwise reveal TITLE.EGA's thick bezel under our frame.
			if _title_map_started():
				_erase_classic_map_chrome()
				_draw_map_window_frame()
				_draw_map_static()
		Mode.MAP, Mode.MENU:
			## Black canvas, then logos/map shifted down so top/bottom empty bands match.
			## Beasties stay on the absolute top corners (no content offset).
			_canvas.fill(Color.BLACK)
			var off := _content_y_offset()
			if _title_img:
				_canvas.blit_rect(
					_title_img,
					Rect2i(0, 0, LOGIC_W, LOGIC_H),
					Vector2i(0, off)
				)
			## Drop TITLE.EGA map ornament; thin dialogue-style frame (tiles or solid menu fill).
			_erase_classic_map_chrome()
			_draw_map_window_frame()
			if mode == Mode.MAP:
				_draw_map_static()
				_draw_map_animated()
			## MENU: keep the same frame; leave panel black so text UI fills it.
			if _beasties_visible:
				_draw_beasties()
	if _tex:
		_tex.update(_canvas)


## Outer blue frame rect in intro logic space (640×400 after SCALE).
func map_frame_outer_rect() -> Rect2i:
	return _map_frame_outer_rect()


## Black panel inside the border (menu content target; excludes the line itself).
func map_frame_inner_rect() -> Rect2i:
	var outer := _map_frame_outer_rect()
	var b := MAP_FRAME_BORDER
	return Rect2i(
		outer.position.x + b,
		outer.position.y + b,
		maxi(0, outer.size.x - b * 2),
		maxi(0, outer.size.y - b * 2)
	)


func _tile_cell_w() -> int:
	## 32px height × 14/16 = native 28px display width.
	return maxi(1, int(round(float(TILE_CELL_H) * _TileBank.display_aspect())))


func _map_x() -> int:
	return (LOGIC_W - MAP_W * _tile_cell_w()) / 2


## Half of leftover empty space under the design (logos + map panel) → equal top/bottom bands.
## Beasts ignore this offset so they stay glued to the screen top corners.
func _content_y_offset() -> int:
	var g := MAP_FRAME_PAD + MAP_FRAME_BORDER
	var design_bottom := MAP_Y + MAP_DRAW_H + g
	return maxi(0, (LOGIC_H - design_bottom) / 2)


func _present_scaled(base: Image) -> void:
	if base == null:
		_canvas.fill(Color.BLACK)
		return
	_canvas.fill(Color.BLACK)
	var up := base.duplicate()
	up.resize(LOGIC_W, LOGIC_H, Image.INTERPOLATE_NEAREST)
	var off := _content_y_offset()
	_canvas.blit_rect(up, Rect2i(0, 0, LOGIC_W, LOGIC_H), Vector2i(0, off))


func _map_content_rect() -> Rect2i:
	var cw := _tile_cell_w()
	return Rect2i(_map_x(), MAP_Y + _content_y_offset(), MAP_W * cw, MAP_DRAW_H)


func _map_frame_outer_rect() -> Rect2i:
	var c := _map_content_rect()
	var g := MAP_FRAME_PAD + MAP_FRAME_BORDER
	return Rect2i(c.position.x - g, c.position.y - g, c.size.x + g * 2, c.size.y + g * 2)


## Wipe the ornate TITLE.EGA map hole + bezel (Quest subtitle above map band stays with logos).
func _erase_classic_map_chrome() -> void:
	if _canvas == null:
		return
	var off := _content_y_offset()
	var y0 := MAP_CHROME_Y0 + off
	var h := LOGIC_H - y0
	if h <= 0:
		return
	_canvas.fill_rect(Rect2i(0, y0, LOGIC_W, h), Color.BLACK)


## Dialogue-panel style: blue line around the tile/menu panel.
func _draw_map_window_frame() -> void:
	if _canvas == null:
		return
	var outer := _map_frame_outer_rect()
	if outer.size.x <= 0 or outer.size.y <= 0:
		return
	_canvas.fill_rect(outer, MAP_FRAME_COL)
	var inner := map_frame_inner_rect()
	if inner.size.x > 0 and inner.size.y > 0:
		_canvas.fill_rect(inner, Color.BLACK)


func _draw_map_static() -> void:
	if _TileBank.uses_hgr_ntsc():
		_draw_apple2_map_static()
		return
	for y in MAP_H:
		for x in MAP_W:
			_paint_intro_cell(x, y)


func _draw_apple2_map_static() -> void:
	## Compose the final 19×5 terrain+object field in one HGR pass, preserving
	## NTSC phase across every tile boundary exactly like MapView's Apple II path.
	if _bin == null or _canvas == null:
		return
	var scroll_y := int(
		posmod(_water_scroll, TILE_PX) * _Apple2HgrNtsc.SRC_H / float(TILE_PX)
	)
	var content := _map_content_rect()
	var ids := PackedInt32Array()
	ids.resize(MAP_W * MAP_H)
	for y in MAP_H:
		for x in MAP_W:
			ids[y * MAP_W + x] = _intro_apple2_ground_tid(_intro_tid(x, y))
	for i in _obj_active.size():
		if _obj_active[i] == 0 or _intro_obj_is_cannon(i):
			continue
		var ox: int = _obj_x[i]
		var oy: int = _obj_y[i]
		if ox < 0 or ox >= MAP_W or oy < 0 or oy >= MAP_H:
			continue
		## TITLE.EXE script already resolved shape id + walk frames via
		## `_resolve_script_tile_frame`. World creature cycling would replace
		## ship facings / intro props with unrelated walk frames.
		ids[oy * MAP_W + ox] = clampi(_obj_tile[i], 0, _TileBank.COUNT - 1)
	## OUT_W×OUT_H is the native 28×32 display cell, so this is both exact
	## 8.75:10 and free of a second scaling pass.
	var composed: Image = _Apple2HgrNtsc.render_grid_scaled(
		ids, MAP_W, MAP_H, _tile_cell_w(), scroll_y, false
	)
	if composed == null or composed.is_empty():
		return
	_apple2_map_img = composed
	_apple2_map_scroll = scroll_y
	_canvas.blit_rect(
		_apple2_map_img,
		Rect2i(0, 0, content.size.x, content.size.y),
		content.position
	)


func _draw_map_animated() -> void:
	for i in _obj_active.size():
		if _obj_active[i] == 0:
			continue
		var ox: int = _obj_x[i]
		var oy: int = _obj_y[i]
		if ox < 0 or ox >= MAP_W or oy < 0 or oy >= MAP_H:
			continue
		var tid: int = _obj_tile[i]
		var fr: int = _obj_frame[i]
		## Apple II raw objects were already stamped into the continuous HGR grid.
		## Only the custom cannonball has no source tile and remains an overlay.
		if _TileBank.uses_hgr_ntsc() and not _intro_obj_is_cannon(i):
			continue
		## Moongates: script selects phase tiles 064–067; open gate (067) swirls continuously.
		if tid >= TILE_MOONGATE_0 and tid <= TILE_MOONGATE_OPEN:
			_paint_intro_cell(ox, oy, tid, fr, true)
			continue
		## Ship shot is TITLE.EXE object 12 / shape 077 — use MapView cannonball art.
		if tid == TILE_MISSILE or _intro_obj_is_cannon(i):
			_paint_intro_cell(ox, oy, TILE_MISSILE, 0, false)
			continue
		## Creatures still flip walk frames like MapView.
		var paint_tid: int = _WorldCreatures.resolve_paint_tile(tid, _tile_anim_frame)
		_paint_intro_cell(ox, oy, paint_tid, fr, false)


## Terrain (+ shore freckles on water) then optional keyed object, MapView aspect.
## `moongate`: use phase tile + open-gate suck when full (see `_moongate_sprite`).
func _paint_intro_cell(
	mx: int, my: int, obj_tid: int = -1, obj_frame: int = 0, moongate: bool = false
) -> void:
	if _bin == null or _canvas == null:
		return
	var dst_rect := _intro_cell_rect(mx, my)
	if dst_rect.size.x <= 0 or dst_rect.size.y <= 0:
		return
	var ground: int = _intro_tid(mx, my)
	var cell := Image.create(TILE_PX, TILE_PX, false, Image.FORMAT_RGBA8)
	cell.fill(Color(0, 0, 0, 0))
	## Apple II terrain was already drawn continuously by `_draw_apple2_map_static`.
	## Animated objects must not redraw an isolated ground tile over that field.
	if not _TileBank.uses_hgr_ntsc():
		if ground <= WATER_TILE_MAX:
			_TileBank.blit_water_to(cell, ground, Vector2i.ZERO, _water_scroll)
			_apply_water_shore_masks(cell, mx, my)
		else:
			## Terrain is fully drawn (black may be ink). Keys only apply to sprites.
			## Town / keep / castle flags share extra frames — same cycle as MapView.
			_TileBank.blit_anim_to(cell, ground, Vector2i.ZERO, _tile_anim_frame)
	if obj_tid >= 0:
		var o_img: Image = null
		if moongate:
			o_img = _moongate_sprite(obj_tid)
		elif obj_tid == TILE_MISSILE:
			o_img = _cannonball_sprite()
		else:
			o_img = _keyed_tile_image(obj_tid, obj_frame)
		if o_img:
			cell.blend_rect(o_img, Rect2i(0, 0, TILE_PX, TILE_PX), Vector2i.ZERO)
	if _TileBank.uses_hgr_ntsc() and obj_tid < 0:
		return
	if cell.get_width() != dst_rect.size.x or cell.get_height() != dst_rect.size.y:
		cell.resize(dst_rect.size.x, dst_rect.size.y, Image.INTERPOLATE_NEAREST)
	_canvas.blend_rect(
		cell,
		Rect2i(0, 0, dst_rect.size.x, dst_rect.size.y),
		dst_rect.position
	)


func _intro_cell_rect(mx: int, my: int) -> Rect2i:
	## Every tileset uses the native 28×32 display cell.
	var content := _map_content_rect()
	var cw := _tile_cell_w()
	return Rect2i(
		content.position.x + mx * cw,
		content.position.y + my * TILE_CELL_H,
		cw,
		TILE_CELL_H
	)


func _intro_tid(mx: int, my: int) -> int:
	if _bin == null or mx < 0 or my < 0 or mx >= MAP_W or my >= MAP_H:
		return 0
	return int(_bin.intro_map[mx + my * MAP_W])


## Apple II HGR grid cell for static intro terrain (water scroll is grid-wide).
func _intro_apple2_ground_tid(raw: int) -> int:
	var tid := clampi(raw, 0, _TileBank.COUNT - 1)
	if tid <= WATER_TILE_MAX:
		return tid
	var n := _TileBank.frame_count(tid)
	if n <= 1:
		return tid
	return tid + posmod(_tile_anim_frame, n)


## Classic shapes store each pose as its own id (1 PNG frame). Walk the bank like
## xu4 does when `tile frames` exceed one strip cell (base+1 … base+N).
func _resolve_script_tile_frame(base_id: int, want_frame: int) -> Vector2i:
	var tile_id := clampi(base_id, 0, _TileBank.COUNT - 1)
	var frame := maxi(0, want_frame)
	for _i in 16:
		var n := maxi(1, _TileBank.frame_count(tile_id))
		if frame < n:
			return Vector2i(tile_id, frame)
		frame -= n
		tile_id += 1
		if tile_id >= _TileBank.COUNT:
			return Vector2i(_TileBank.COUNT - 1, 0)
	return Vector2i(tile_id, 0)


func _moongate_sprite(tid: int) -> Image:
	## Phase tiles 064–066 are still; full gate 067 uses MapView-style inward swirl
	## (skipped on Apple II Color/Mono — art has no blue/white glow to rotate).
	var phase := clampi(tid, TILE_MOONGATE_0, TILE_MOONGATE_OPEN)
	if phase < TILE_MOONGATE_OPEN or not _TileBank.uses_moongate_suck():
		return _keyed_tile_image(phase, 0)
	_ensure_moongate_suck_frames()
	if _moongate_suck_frames.is_empty():
		return _keyed_tile_image(TILE_MOONGATE_OPEN, 0)
	var i := posmod(_moongate_suck_i, _moongate_suck_frames.size())
	return _moongate_suck_frames[i] as Image


func _ensure_moongate_suck_frames() -> void:
	if not _moongate_suck_frames.is_empty() or not _TileBank.uses_moongate_suck():
		return
	var base := _keyed_tile_image(TILE_MOONGATE_OPEN, 0)
	if base == null:
		return
	_moongate_pick_glow_colors(base)
	_moongate_suck_frames.clear()
	for fi in MOONGATE_SUCK_FRAMES:
		var phase := float(fi) / float(MOONGATE_SUCK_FRAMES)
		_moongate_suck_frames.append(_build_moongate_suck_frame(base, phase))


func _moongate_pick_glow_colors(src: Image) -> void:
	var sum_b := Color(0, 0, 0, 0)
	var sum_w := Color(0, 0, 0, 0)
	var nb := 0
	var nw := 0
	for y in src.get_height():
		for x in src.get_width():
			var c: Color = src.get_pixel(x, y)
			if not _moongate_is_glow(c):
				continue
			var lum := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
			if lum > 0.78:
				sum_w += c
				nw += 1
			elif c.b > c.r + 0.1:
				sum_b += c
				nb += 1
	if nb > 0:
		_moongate_col_blue = sum_b / float(nb)
		_moongate_col_blue.a = 1.0
	if nw > 0:
		_moongate_col_white = sum_w / float(nw)
		_moongate_col_white.a = 1.0


func _build_moongate_suck_frame(src: Image, phase: float) -> Image:
	## Same nested-rectangle inward scroll as MapView open moongate.
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.copy_from(src)
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in h:
		for x in w:
			if not _moongate_is_glow(src.get_pixel(x, y)):
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x:
		return out
	var cx := (float(min_x) + float(max_x)) * 0.5
	var cy := (float(min_y) + float(max_y)) * 0.5
	var half_w := maxf((float(max_x) - float(min_x)) * 0.5, 1.0)
	var half_h := maxf((float(max_y) - float(min_y)) * 0.5, 1.0)
	var scroll := fposmod(phase, 1.0)
	for y in h:
		for x in w:
			var base: Color = src.get_pixel(x, y)
			if not _moongate_is_glow(base):
				continue
			var nx := (float(x) - cx) / half_w
			var ny := (float(y) - cy) / half_h
			var d := maxf(absf(nx), absf(ny))
			var ux := 1.0
			var uy := 0.0
			if d > 0.0001:
				ux = nx / d
				uy = ny / d
			var sample_d := fposmod(d + scroll, 1.0)
			var sx := cx + ux * sample_d * half_w
			var sy := cy + uy * sample_d * half_h
			var sampled := _moongate_sample_glow(src, sx, sy, base)
			var ring_t := fposmod(d + scroll, 1.0)
			var white_amt := 0.5 - 0.5 * cos(ring_t * TAU)
			white_amt = smoothstep(0.0, 1.0, white_amt)
			var flowed := _moongate_col_blue.lerp(_moongate_col_white, white_amt)
			var mixed := flowed.lerp(sampled, 0.28)
			mixed.a = base.a
			out.set_pixel(x, y, mixed)
	return out


func _moongate_sample_glow(src: Image, fx: float, fy: float, fallback: Color) -> Color:
	var w := src.get_width()
	var h := src.get_height()
	fx = clampf(fx, 0.0, float(w - 1))
	fy = clampf(fy, 0.0, float(h - 1))
	var x0 := mini(floori(fx), w - 1)
	var y0 := mini(floori(fy), h - 1)
	var x1 := mini(x0 + 1, w - 1)
	var y1 := mini(y0 + 1, h - 1)
	var tx := fx - float(x0)
	var ty := fy - float(y0)
	var c00: Color = src.get_pixel(x0, y0)
	var c10: Color = src.get_pixel(x1, y0)
	var c01: Color = src.get_pixel(x0, y1)
	var c11: Color = src.get_pixel(x1, y1)
	if not _moongate_is_glow(c00):
		c00 = fallback
	if not _moongate_is_glow(c10):
		c10 = fallback
	if not _moongate_is_glow(c01):
		c01 = fallback
	if not _moongate_is_glow(c11):
		c11 = fallback
	var top := c00.lerp(c10, tx)
	var bot := c01.lerp(c11, tx)
	var mixed := top.lerp(bot, ty)
	mixed.a = fallback.a
	return mixed


func _moongate_is_glow(c: Color) -> bool:
	if c.a < 0.15:
		return false
	var lum := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	if lum > 0.72 and c.b > 0.65:
		return true
	if c.b > 0.40 and c.b > c.r + 0.12 and c.b > c.g + 0.08:
		return true
	return false


func _intro_obj_is_cannon(idx: int) -> bool:
	if _bin == null or idx < 0 or idx >= _bin.base_tiles.size():
		return false
	return int(_bin.base_tiles[idx]) == TILE_MISSILE


func _cannonball_sprite() -> Image:
	## Same file and load path as MapView flying ship shot — not 077_missile.
	if _cannonball_img == null or _cannonball_img.is_empty():
		_cannonball_img = _load_cannonball_image()
	return _cannonball_img


func _keyed_tile_image(tile_id: int, frame: int) -> Image:
	if tile_id == TILE_MISSILE:
		return _cannonball_sprite()
	## Apple II Color/Mono: keep opaque black (same as MapView keyed_copy).
	var key_prefix := "a2" if _TileBank.keeps_opaque_black() else "k"
	var key := "%s:%d:%d" % [key_prefix, tile_id, frame]
	if _tile_cache.has(key):
		return _tile_cache[key] as Image
	var src: Image = _TileBank.image(tile_id, frame)
	if src == null:
		return null
	var img := src.duplicate()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	if not _TileBank.keeps_opaque_black():
		for y in img.get_height():
			for x in img.get_width():
				var c: Color = img.get_pixel(x, y)
				if c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
	_tile_cache[key] = img
	return img


func _load_cannonball_image() -> Image:
	## MapView loads this PNG as-is (already a ~10×10 pearl on transparent 32×32).
	var img := _ResImage.load_rgba8(CANNONBALL_PATH)
	if img == null or img.is_empty():
		return null
	if img.get_width() != TILE_PX or img.get_height() != TILE_PX:
		img.resize(TILE_PX, TILE_PX, Image.INTERPOLATE_NEAREST)
	return img


func _is_shore_land_tid(tid: int) -> bool:
	if tid <= WATER_TILE_MAX:
		return false
	## Hills / mountains / dungeon mouth — no sandy shore freckles.
	if tid == 7 or tid == 8 or tid == 9:
		return false
	return true


func _shore_land_bits_at(mx: int, my: int) -> int:
	var bits := 0
	if _is_shore_land_tid(_intro_tid(mx, my - 1)):
		bits |= SHORE_BIT_N
	if _is_shore_land_tid(_intro_tid(mx + 1, my)):
		bits |= SHORE_BIT_E
	if _is_shore_land_tid(_intro_tid(mx, my + 1)):
		bits |= SHORE_BIT_S
	if _is_shore_land_tid(_intro_tid(mx - 1, my)):
		bits |= SHORE_BIT_W
	return bits


func _load_shore_land_ref(ref_name: String) -> Image:
	if _shore_cache.has(ref_name):
		return _shore_cache[ref_name] as Image
	var path := "%s/shore_land_%s.png" % [SHORE_MASK_DIR, ref_name]
	var img: Image = null
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		img = Image.load_from_file(abs_path)
	elif ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			img = (res as Texture2D).get_image()
			if img != null and img.is_compressed():
				img.decompress()
		elif res is Image:
			img = res as Image
	if img == null or img.is_empty():
		_shore_cache[ref_name] = null
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	_shore_cache[ref_name] = img
	return img


func _apply_water_shore_masks(target: Image, mx: int, my: int) -> void:
	if not _TileBank.uses_shore_masks():
		return
	var bits := _shore_land_bits_at(mx, my)
	if bits == 0:
		return
	_fill_shore_edge_blackout(target, bits)
	var freckled := PackedByteArray()
	freckled.resize(TILE_PX * TILE_PX)
	freckled.fill(0)
	if bits == (SHORE_BIT_E | SHORE_BIT_W):
		_stamp_shore_full(target, "dual_ew", freckled)
		return
	if bits == (SHORE_BIT_N | SHORE_BIT_S):
		_stamp_shore_full(target, "dual_ns", freckled)
		return
	if bits == (SHORE_BIT_N | SHORE_BIT_E | SHORE_BIT_S | SHORE_BIT_W):
		_stamp_shore_full(target, "frame", freckled)
		return
	if bits & SHORE_BIT_N:
		_stamp_shore_side(target, "top", SHORE_BIT_N, freckled)
	if bits & SHORE_BIT_E:
		_stamp_shore_side(target, "right", SHORE_BIT_E, freckled)
	if bits & SHORE_BIT_S:
		_stamp_shore_side(target, "bottom", SHORE_BIT_S, freckled)
	if bits & SHORE_BIT_W:
		_stamp_shore_side(target, "left", SHORE_BIT_W, freckled)
	if (bits & (SHORE_BIT_N | SHORE_BIT_W)) == (SHORE_BIT_N | SHORE_BIT_W):
		_stamp_shore_side(target, "corner_nw", SHORE_BIT_N | SHORE_BIT_W | 16, freckled)
	if (bits & (SHORE_BIT_N | SHORE_BIT_E)) == (SHORE_BIT_N | SHORE_BIT_E):
		_stamp_shore_side(target, "corner_ne", SHORE_BIT_N | SHORE_BIT_E | 16, freckled)
	if (bits & (SHORE_BIT_S | SHORE_BIT_W)) == (SHORE_BIT_S | SHORE_BIT_W):
		_stamp_shore_side(target, "corner_sw", SHORE_BIT_S | SHORE_BIT_W | 16, freckled)
	if (bits & (SHORE_BIT_S | SHORE_BIT_E)) == (SHORE_BIT_S | SHORE_BIT_E):
		_stamp_shore_side(target, "corner_se", SHORE_BIT_S | SHORE_BIT_E | 16, freckled)


func _stamp_shore_full(target: Image, ref_name: String, freckled: PackedByteArray) -> void:
	var land := _load_shore_land_ref(ref_name)
	if land:
		_stamp_shore_land(target, land, 0, freckled)


func _stamp_shore_side(
	target: Image, ref_name: String, filter: int, freckled: PackedByteArray
) -> void:
	var land := _load_shore_land_ref(ref_name)
	if land:
		_stamp_shore_land(target, land, filter, freckled)


func _stamp_shore_land(
	target: Image, land: Image, filter: int, freckled: PackedByteArray
) -> void:
	var tw := target.get_width()
	var th := target.get_height()
	var lw := mini(land.get_width(), TILE_PX)
	var lh := mini(land.get_height(), TILE_PX)
	var corner := (filter & 16) != 0
	var sides := filter & 15
	var depth := SHORE_CORNER_DEPTH if corner else SHORE_EDGE_DEPTH
	for y in lh:
		for x in lw:
			if not _shore_filter_keeps(x, y, sides, corner, depth):
				continue
			var c: Color = land.get_pixel(x, y)
			if c.a < 0.5:
				continue
			if x >= tw or y >= th:
				continue
			var s := SHORE_COLOR_SCALE
			target.set_pixel(x, y, Color(c.r * s, c.g * s, c.b * s, c.a))
			freckled[y * TILE_PX + x] = 1


func _fill_shore_edge_blackout(target: Image, bits: int) -> void:
	var black := Color(0, 0, 0, 1)
	var tw := target.get_width()
	var th := target.get_height()
	if bits & SHORE_BIT_N:
		for x in TILE_PX:
			if x < tw and th > 0:
				target.set_pixel(x, 0, black)
	if bits & SHORE_BIT_S:
		var y := TILE_PX - 1
		for x in TILE_PX:
			if x < tw and y < th:
				target.set_pixel(x, y, black)
	if bits & SHORE_BIT_W:
		for y3 in TILE_PX:
			if y3 < th and tw > 0:
				target.set_pixel(0, y3, black)
	if bits & SHORE_BIT_E:
		var x4 := TILE_PX - 1
		for y4 in TILE_PX:
			if x4 < tw and y4 < th:
				target.set_pixel(x4, y4, black)


func _shore_filter_keeps(x: int, y: int, sides: int, corner: bool, depth: int) -> bool:
	if sides == 0:
		return true
	var n := (sides & SHORE_BIT_N) != 0 and y < depth
	var s := (sides & SHORE_BIT_S) != 0 and y >= TILE_PX - depth
	var w := (sides & SHORE_BIT_W) != 0 and x < depth
	var e := (sides & SHORE_BIT_E) != 0 and x >= TILE_PX - depth
	if corner:
		if (sides & (SHORE_BIT_N | SHORE_BIT_W)) == (SHORE_BIT_N | SHORE_BIT_W):
			return n and w
		if (sides & (SHORE_BIT_N | SHORE_BIT_E)) == (SHORE_BIT_N | SHORE_BIT_E):
			return n and e
		if (sides & (SHORE_BIT_S | SHORE_BIT_W)) == (SHORE_BIT_S | SHORE_BIT_W):
			return s and w
		if (sides & (SHORE_BIT_S | SHORE_BIT_E)) == (SHORE_BIT_S | SHORE_BIT_E):
			return s and e
		return false
	return n or s or w or e


func _blit_tile(
	tile_id: int,
	frame: int,
	dx: int,
	dy: int,
	cell_w: int,
	cell_h: int,
	blend: bool = false,
	target: Image = null
) -> void:
	## Classic/title MAP open path (square cells; black keyed → transparent).
	var dst: Image = target if target != null else _canvas
	if dst == null or cell_w <= 0 or cell_h <= 0:
		return
	var keyed := _keyed_tile_image(tile_id, frame)
	var tile_img: Image
	if keyed != null:
		tile_img = keyed.duplicate()
		if tile_img.get_width() != cell_w or tile_img.get_height() != cell_h:
			tile_img.resize(cell_w, cell_h, Image.INTERPOLATE_NEAREST)
	else:
		var src: Image = _TileBank.image(tile_id, frame)
		if src == null:
			return
		tile_img = src.duplicate()
		tile_img.resize(cell_w, cell_h, Image.INTERPOLATE_NEAREST)
	if blend:
		dst.blend_rect(tile_img, Rect2i(0, 0, cell_w, cell_h), Vector2i(dx, dy))
	else:
		dst.blit_rect(tile_img, Rect2i(0, 0, cell_w, cell_h), Vector2i(dx, dy))


func _draw_beasties() -> void:
	var f1: int = 0
	var f2: int = 0
	if _bin and _bin.beastie1_frames.size() > 0:
		f1 = _bin.beastie1_frames[_beastie1_cycle % _bin.beastie1_frames.size()]
	if _bin and _bin.beastie2_frames.size() > 0:
		f2 = _bin.beastie2_frames[_beastie2_cycle % _bin.beastie2_frames.size()]
	f1 = clampi(f1, 0, 17)
	f2 = clampi(f2, 0, 17)
	var y := _beastie_offset * SCALE
	if f1 < _beast0.size() and _beast0[f1] != null:
		var b0: Image = _beast0[f1]
		_canvas.blend_rect(b0, Rect2i(0, 0, b0.get_width(), b0.get_height()), Vector2i(0, y))
	if f2 < _beast1.size() and _beast1[f2] != null:
		var b1: Image = _beast1[f2]
		_canvas.blend_rect(
			b1,
			Rect2i(0, 0, b1.get_width(), b1.get_height()),
			Vector2i(LOGIC_W - b1.get_width(), y)
		)


## -------------------- Titles sequence ---------------------------------------

func _init_titles() -> void:
	_titles.clear()
	## x, y, w, h, method, delay_ms, duration_ms
	_add_title(97, 0, 130, 16, AnimType.SIGNATURE, 1000, 3000)
	## AND crop slightly wider — EGA "and" reaches ~x174 after / before fixup
	_add_title(148, 17, 28, 4, AnimType.AND, 1000, 100)
	_add_title(84, 31, 152, 1, AnimType.BAR, 1000, 500)
	## ORIGIN: trailing glyph column
	_add_title(86, 21, 150, 9, AnimType.ORIGIN, 1000, 100)
	## After fixupIntro: PRESENT lives at (132,33) 56×5 (xu4 dest of copy)
	_add_title(132, 33, 56, 5, AnimType.PRESENT, 0, 400)
	## Pixel scatter of "Ultima IV" — duration matches title_fade_c64.ogg.
	_add_title(59, 33, 202, 46, AnimType.TITLE, 1000, _title_fade_duration_ms())
	## "Quest of the Avatar" writes left → right, then settle the logos, then the map.
	_add_title(40, 80, 240, 13, AnimType.SUBTITLE, 600, 1000)
	_add_title(0, 0, BASE_W, 94, AnimType.SETTLE, 120, 1100)
	_add_title(0, 96, 320, 96, AnimType.MAP, 500, 1)
	_build_title_sources()


## xu4 ImageMgr::fixupIntro — arrange TITLE.EGA elements for the title sequence.
## Raw "PRESENT" is at the top of the EGA; after this it sits under Origin / above Ultima IV.
func _fixup_intro_title(im: Image) -> void:
	if im == null or im.is_empty():
		return
	## "and"
	_blit_self(im, 148, 17, 153, 17, 11, 4)
	_blit_self(im, 159, 17, 165, 18, 1, 4)
	_blit_self(im, 160, 17, 164, 17, 16, 4)
	## "Origin Systems, Inc."
	_blit_self(im, 86, 21, 88, 21, 114, 9)
	_blit_self(im, 199, 21, 202, 21, 6, 9)
	_blit_self(im, 207, 21, 208, 21, 28, 9)
	## "Ultima IV" — must run *before* moving PRESENT
	_blit_self(im, 59, 33, 61, 33, 204, 46)
	## "Quest of the Avatar"
	_blit_self(im, 69, 80, 70, 80, 11, 13)
	_blit_self(im, 82, 80, 84, 80, 27, 13)
	_blit_self(im, 131, 80, 132, 80, 11, 13)
	_blit_self(im, 150, 80, 149, 80, 40, 13)
	_blit_self(im, 166, 80, 165, 80, 11, 13)
	_blit_self(im, 200, 80, 201, 80, 81, 13)
	_blit_self(im, 227, 80, 228, 80, 11, 13)
	## PRESENT: top of file → between Origin and Ultima IV
	_blit_self(im, 132, 33, 135, 0, 56, 5)
	## erase original PRESENT under the signature area
	for y in 5:
		for x in range(135, 135 + 56):
			if x < BASE_W and y < BASE_H:
				im.set_pixel(x, y, Color.BLACK)
	## EGA red bar under Origin (also animated by BAR title step)
	var bar_c := Color8(128, 0, 0)
	for x in range(84, 236):
		if x < BASE_W and 31 < BASE_H:
			im.set_pixel(x, 31, bar_c)


## Recolor Ultima IV + Quest of the Avatar (after fixup). PRESENT / Origin stay as-is.
func _recolor_ultima_title_silver(im: Image) -> void:
	if im == null or im.is_empty():
		return
	_recolor_title_rect_silver(im, 59, 33, 204, 46)
	_recolor_title_rect_silver(im, 40, 80, 240, 13)


func _recolor_title_rect_silver(im: Image, x0: int, y0: int, tw: int, th: int) -> void:
	var w := im.get_width()
	var h := im.get_height()
	for y in range(y0, mini(y0 + th, h)):
		for x in range(x0, mini(x0 + tw, w)):
			im.set_pixel(x, y, _silver_title_pixel(im.get_pixel(x, y)))


func _silver_title_pixel(c: Color) -> Color:
	var r := int(round(c.r * 255.0))
	var g := int(round(c.g * 255.0))
	var b := int(round(c.b * 255.0))
	## EGA bright cyan → bright silver
	if r == 0x55 and g == 0xff and b == 0xff:
		return Color8(0xe6, 0xe8, 0xee)
	## EGA bright blue → mid steel
	if r == 0x55 and g == 0x55 and b == 0xff:
		return Color8(0x9c, 0xa0, 0xa8)
	## EGA cyan → warm bronze reflection
	if r == 0x00 and g == 0xaa and b == 0xaa:
		return Color8(0x7a, 0x6e, 0x5c)
	## EGA blue → dark steel
	if r == 0x00 and g == 0x00 and b == 0xaa:
		return Color8(0x3c, 0x3a, 0x38)
	return c


func _blit_self(im: Image, dx: int, dy: int, sx: int, sy: int, w: int, h: int) -> void:
	## Copy within same image via a temp so overlapping source/dest is safe.
	if im == null or w <= 0 or h <= 0:
		return
	var r := Rect2i(sx, sy, w, h).intersection(Rect2i(0, 0, im.get_width(), im.get_height()))
	if r.size.x <= 0 or r.size.y <= 0:
		return
	var tmp := im.get_region(r)
	im.blit_rect(tmp, Rect2i(0, 0, r.size.x, r.size.y), Vector2i(dx + (r.position.x - sx), dy + (r.position.y - sy)))


func _title_map_started() -> bool:
	var i := _title_index_of(AnimType.MAP)
	if i < 0 or _title_i < i:
		return false
	if _title_i > i:
		return true
	var t: Dictionary = _titles[i]
	if int(t.get("time_base", 0)) == 0:
		return false
	if _skip_titles:
		return true
	var elapsed: int = Time.get_ticks_msec() - int(t["time_base"])
	return elapsed >= int(t.get("time_delay", 0))


func _title_plate_band_h() -> int:
	if _title_plate == null:
		return 0
	return mini(TITLE_PLATE_H, _title_plate.get_height())


func _apply_title_plate_to(img: Image) -> void:
	if img == null or _title_plate == null:
		return
	var h := _title_plate_band_h()
	if h <= 0:
		return
	img.blit_rect(_title_plate, Rect2i(0, 0, LOGIC_W, h), Vector2i(0, 0))


func _overlay_title_plate(amount: float) -> void:
	if _title_plate == null or _canvas == null or amount <= 0.0:
		return
	amount = clampf(amount, 0.0, 1.0)
	var off := _content_y_offset()
	var h := _title_plate_band_h()
	if h <= 0:
		return
	if amount >= 0.999:
		_canvas.blit_rect(_title_plate, Rect2i(0, 0, LOGIC_W, h), Vector2i(0, off))
		return
	## Radial dissolve: new plate fades in from the center, no rim flash.
	var cx := float(LOGIC_W) * 0.5
	var cy := float(h) * 0.5
	var inv_cx := 1.0 / cx
	var inv_cy := 1.0 / maxf(cy, 1.0)
	## Ellipse-norm distance at a corner is √2; expand a bit past that to clear the band.
	var reach := 1.48
	var feather := 0.34
	var radius := amount * (reach + feather)
	var solid_r := maxf(0.0, radius - feather)
	var radius2 := radius * radius
	var solid2 := solid_r * solid_r
	for y in h:
		var dy := (float(y) + 0.5 - cy) * inv_cy
		var dy2 := dy * dy
		if dy2 >= radius2:
			continue
		var dx_outer := cx * sqrt(radius2 - dy2)
		var x_lo := clampi(int(floor(cx - dx_outer)), 0, LOGIC_W)
		var x_hi := clampi(int(ceil(cx + dx_outer)), 0, LOGIC_W)
		var xs0 := x_hi
		var xs1 := x_lo
		if dy2 < solid2:
			var dx_solid := cx * sqrt(solid2 - dy2)
			xs0 = clampi(int(floor(cx - dx_solid)), 0, LOGIC_W)
			xs1 = clampi(int(ceil(cx + dx_solid)), 0, LOGIC_W)
			if xs1 > xs0:
				_canvas.blit_rect(
					_title_plate,
					Rect2i(xs0, y, xs1 - xs0, 1),
					Vector2i(xs0, y + off)
				)
		for x in range(x_lo, xs0):
			_blend_title_plate_rim(x, y, off, cx, cy, inv_cx, inv_cy, radius, feather)
		for x in range(xs1, x_hi):
			_blend_title_plate_rim(x, y, off, cx, cy, inv_cx, inv_cy, radius, feather)


func _blend_title_plate_rim(
	x: int,
	y: int,
	off: int,
	cx: float,
	cy: float,
	inv_cx: float,
	inv_cy: float,
	radius: float,
	feather: float
) -> void:
	var nd := Vector2((float(x) + 0.5 - cx) * inv_cx, (float(y) + 0.5 - cy) * inv_cy).length()
	var a := 1.0 - clampf((nd - (radius - feather)) / feather, 0.0, 1.0)
	if a <= 0.001:
		return
	var src: Color = _title_plate.get_pixel(x, y)
	var dst: Color = _canvas.get_pixel(x, y + off)
	_canvas.set_pixel(x, y + off, dst.lerp(src, a))


func _title_index_of(method: int) -> int:
	for i in _titles.size():
		if int(_titles[i].get("method", -1)) == method:
			return i
	return -1


func _title_fade_duration_ms() -> int:
	var sec := AudioSfx.stream_length(AudioSfx.ID_TITLE_FADE)
	if sec <= 0.0:
		return 5000
	return int(round(sec * 1000.0))


func _add_title(x: int, y: int, w: int, h: int, method: int, delay_ms: int, duration_ms: int) -> void:
	_titles.append({
		"rx": x, "ry": y, "rw": w, "rh": h,
		"method": method,
		"anim_step": 0,
		"anim_step_max": 0,
		"time_base": 0,
		"time_delay": delay_ms,
		"time_duration": duration_ms,
		"src": null,
		"dest": null,
		"plot": [], ## Array of {x,y,r,g,b}
	})


func _build_title_sources() -> void:
	if _title_base == null:
		return
	for i in _titles.size():
		var t: Dictionary = _titles[i]
		var method: int = t["method"]
		if method != AnimType.SIGNATURE and method != AnimType.BAR and method != AnimType.SETTLE:
			t["src"] = _U4Lzw.crop(_title_base, t["rx"], t["ry"], t["rw"], t["rh"])
		if method == AnimType.SETTLE:
			t["dest"] = null
			t["anim_step_max"] = 40
			_titles[i] = t
			continue
		t["dest"] = Image.create(t["rw"] + 2, t["rh"] + 2, false, Image.FORMAT_RGBA8)
		t["dest"].fill(Color(0, 0, 0, 0))
		match method:
			AnimType.SIGNATURE:
				var src: PackedByteArray = _bin.sig_data
				var step := 0
				var plots: Array = []
				while step + 1 < src.size() and src[step] != 0:
					var px := src[step] - 0x4C
					var py := 0xC0 - src[step + 1]
					## EGA signature is cyan (xu4); VGA uses a yellow gradient via blue[].
					plots.append({"x": px, "y": py, "r": 0, "g": 255, "b": 255})
					step += 2
				t["plot"] = plots
				t["anim_step_max"] = plots.size()
			AnimType.BAR:
				t["anim_step_max"] = t["rw"]
			AnimType.AND:
				t["anim_step_max"] = 1
			AnimType.ORIGIN, AnimType.PRESENT:
				t["anim_step_max"] = t["rh"]
			AnimType.TITLE:
				var plots: Array = []
				var src_img: Image = t["src"]
				if src_img:
					for yy in t["rh"]:
						for xx in t["rw"]:
							var c: Color = src_img.get_pixel(xx, yy)
							if c.r > 0.001 or c.g > 0.001 or c.b > 0.001:
								plots.append({
									"x": xx + 1, "y": yy + 1,
									"r": int(c.r * 255.0), "g": int(c.g * 255.0), "b": int(c.b * 255.0),
								})
					## shuffle once (Fisher–Yates)
					for j in plots.size() - 1:
						var k := j + randi() % (plots.size() - j)
						var tmp = plots[j]
						plots[j] = plots[k]
						plots[k] = tmp
				t["plot"] = plots
				t["anim_step_max"] = plots.size()
			AnimType.SUBTITLE:
				## One column per step — left-to-right write.
				t["anim_step_max"] = maxi(1, int(t["rw"]))
			AnimType.MAP:
				t["anim_step_max"] = 20
		_titles[i] = t


func _update_titles() -> bool:
	## true while still playing titles
	if _title_i >= _titles.size():
		return false
	var t: Dictionary = _titles[_title_i]
	var now := Time.get_ticks_msec()
	if int(t["method"]) == AnimType.MAP:
		if int(t["time_base"]) == 0:
			t["time_base"] = now
			_titles[_title_i] = t
		if not _skip_titles and (now - int(t["time_base"])) < int(t["time_delay"]):
			return true
		return false
	if int(t["time_base"]) == 0:
		t["time_base"] = now
		if _title_i == 0:
			_accum.fill(Color.BLACK)

	var elapsed: int = now - int(t["time_base"])
	## Player key-skip: ignore per-element delay (xu4 bSkipTitles).
	if not _skip_titles and elapsed < int(t["time_delay"]):
		_titles[_title_i] = t
		return true

	var pct: float
	if _skip_titles:
		pct = 1.0
	else:
		pct = float(elapsed - int(t["time_delay"])) / float(maxi(1, int(t["time_duration"])))
		if pct > 1.0:
			pct = 1.0
	var target: int = int(float(t["anim_step_max"]) * pct)
	var dest: Image = t["dest"]
	var method: int = t["method"]
	var step: int = t["anim_step"]

	match method:
		AnimType.SIGNATURE:
			var plots: Array = t["plot"]
			while target > step and step < plots.size():
				var p: Dictionary = plots[step]
				var col := Color8(p["r"], p["g"], p["b"])
				## xu4 fillRect(plot.x, plot.y, 2, 1) on dest — no extra +1.
				## draw/blit uses dest subrect (1,1)..(rw,rh); plot y max is 16.
				var px: int = int(p["x"])
				var py: int = int(p["y"])
				if px >= 0 and py >= 0 and px < dest.get_width() and py < dest.get_height():
					dest.set_pixel(px, py, col)
					if px + 1 < dest.get_width():
						dest.set_pixel(px + 1, py, col)
				step += 1
			t["anim_step"] = step
		AnimType.BAR:
			while target > step:
				step += 1
				for xx in step:
					if xx + 1 < dest.get_width() and 1 < dest.get_height():
						dest.set_pixel(xx + 1, 1, Color8(128, 0, 0))
			t["anim_step"] = step
		AnimType.AND:
			if t["src"]:
				dest.blit_rect(t["src"], Rect2i(0, 0, t["rw"], t["rh"]), Vector2i(1, 1))
			t["anim_step"] = t["anim_step_max"]
		AnimType.ORIGIN:
			if t["src"] and target > step:
				step = mini(target, t["anim_step_max"])
				## bottom-up reveal
				var h: int = step
				var y0: int = t["rh"] - h
				if h > 0:
					dest.blit_rect(t["src"], Rect2i(0, 0, t["rw"], h), Vector2i(1, 1 + y0))
			t["anim_step"] = step
		AnimType.PRESENT:
			if t["src"] and target > step:
				step = mini(target, t["anim_step_max"])
				var h: int = step
				var src_y: int = t["rh"] - h
				if h > 0:
					dest.blit_rect(t["src"], Rect2i(0, src_y, t["rw"], h), Vector2i(1, 1))
			t["anim_step"] = step
		AnimType.TITLE:
			if step == 0 and not _skip_titles and not _title_fade_started:
				_title_fade_started = true
				AudioSfx.play_title_fade()
			step = target
			dest.fill(Color(0, 0, 0, 0))
			var plots: Array = t["plot"]
			for i in mini(step, plots.size()):
				var p: Dictionary = plots[i]
				var px: int = p["x"]
				var py: int = p["y"]
				if px >= 0 and py >= 0 and px < dest.get_width() and py < dest.get_height():
					dest.set_pixel(px, py, Color8(p["r"], p["g"], p["b"]))
			## cover present strip so pixelized TITLE does not bury "present"
			## Title at (59,33); PRESENT at (132,33) → relative x ≈ 73-74, y ≈ 0-1
			for yy in range(1, mini(7, dest.get_height())):
				for xx in range(73, mini(73 + 56, dest.get_width())):
					dest.set_pixel(xx, yy, Color(0, 0, 0, 0))
			t["anim_step"] = step
		AnimType.SUBTITLE:
			if t["src"]:
				step = mini(target, t["anim_step_max"])
				dest.fill(Color(0, 0, 0, 0))
				## Left → right, as if the line is being written.
				var w: int = step
				if w > 0:
					dest.blit_rect(t["src"], Rect2i(0, 0, w, t["rh"]), Vector2i(1, 1))
			t["anim_step"] = step
		AnimType.SETTLE:
			step = mini(target, int(t["anim_step_max"]))
			_title_plate_t = 1.0 if _skip_titles else float(step) / float(maxi(1, int(t["anim_step_max"])))
			t["anim_step"] = step
		AnimType.MAP:
			step = mini(target + 1, t["anim_step_max"])
			## Do not blit TITLE.EGA's thick map bezel — thin frame is drawn on the canvas.
			dest.fill(Color(0, 0, 0, 0))
			_draw_map_onto(_accum)
			t["anim_step"] = step

	## composite: dest over accum at rx,ry (only opaque src band)
	if method != AnimType.SETTLE:
		_blit_dest_to_accum(t)
	_titles[_title_i] = t

	if int(t["anim_step"]) >= int(t["anim_step_max"]):
		## freeze completed element into accum permanently
		if method == AnimType.SETTLE:
			_title_plate_t = 1.0
		else:
			_blit_dest_to_accum(t, true)
		_title_i += 1
		if _title_i >= _titles.size():
			return false
		_titles[_title_i]["time_base"] = 0
		_titles[_title_i]["anim_step"] = 0
	return true


func _blit_dest_to_accum(t: Dictionary, permanent: bool = false) -> void:
	var dest: Image = t["dest"]
	if dest == null or _accum == null:
		return
	var rx: int = t["rx"]
	var ry: int = t["ry"]
	var rw: int = t["rw"]
	var rh: int = t["rh"]
	## xu4 drawTitle: subrect from (1,1) size rw×rh → screen (rx, ry).
	var dw := dest.get_width()
	var dh := dest.get_height()
	for y in rh:
		for x in rw:
			var sx := x + 1
			var sy := y + 1
			if sx < 0 or sy < 0 or sx >= dw or sy >= dh:
				continue
			var c: Color = dest.get_pixel(sx, sy)
			if c.a < 0.01:
				continue
			var dx := rx + x
			var dy := ry + y
			if dx >= 0 and dy >= 0 and dx < BASE_W and dy < BASE_H:
				_accum.set_pixel(dx, dy, Color(c.r, c.g, c.b, 1.0))
	if permanent:
		pass


func _draw_map_onto(img: Image) -> void:
	## Static map into the base-space map band (title MAP open; classic 16px).
	if _bin == null or img == null:
		return
	var m: PackedByteArray = _bin.intro_map
	for y in MAP_H:
		for x in MAP_W:
			var tid: int = m[x + y * MAP_W]
			_blit_tile(
				tid,
				0,
				MAP_X_BASE + x * TILE_CLASSIC,
				MAP_Y_BASE + y * TILE_CLASSIC,
				TILE_CLASSIC,
				TILE_CLASSIC,
				false,
				img
			)
