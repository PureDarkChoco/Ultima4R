class_name IntroController
extends Node

## Port of xu4/ScummVM IntroController: TITLES → MAP → MENU (map+options only).

signal mode_changed(mode: int)

enum Mode { TITLES, MAP, MENU }

enum AnimType { SIGNATURE, AND, BAR, ORIGIN, PRESENT, TITLE, SUBTITLE, MAP }

const LOGIC_W := 320
const LOGIC_H := 200
const MAP_W := 19
const MAP_H := 5
const TILE_PX := 16 ## classic intro tile size
const MAP_X := 8
const MAP_Y := 104 ## BORDER + 6*TILE_H
const OPTIONS_BTM_Y := 120
const BEAST0_W := 55
const BEAST0_H := 31
const BEAST1_W := 48
const BEAST1_H := 31
const TRANSPARENT_INDEX := 13
const MAP_TICK := 0.10

const _IntroBinData := preload("res://src/intro/intro_bin_data.gd")
const _U4Lzw := preload("res://src/intro/u4_lzw_image.gd")
const _TileBank := preload("res://src/map/u4_tile_bank.gd")

var mode: int = Mode.TITLES

var _bin: RefCounted ## IntroBinData
var _title_img: Image
var _options_btm: Image
var _beast0: Array = [] ## 18 Images
var _beast1: Array = []
var _tile_cache_16: Dictionary = {} ## int shape_id → Image 16×16 (frame 0 only base)

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

## Title sequence state
var _titles: Array = [] ## Dictionaries
var _title_i := 0
var _accum: Image ## permanent title paints
var _title_time0_ms := 0
var _title_ready := false


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

	## Black is animate transparent; title uses fixup intro (index 13, often unused).
	_title_img = _U4Lzw.load_ega_path(title_ega, -1)
	var animate_img: Image = _U4Lzw.load_ega_path(animate_ega, 0)
	if _title_img == null or animate_img == null:
		push_warning("IntroController: EGA load failed")
		return false

	## TITLE.EGA stores "PRESENT" at top; xu4 fixupIntro moves it above Ultima IV.
	_fixup_intro_title(_title_img)

	_options_btm = _U4Lzw.crop(_title_img, 0, 112, 320, 80)
	_beast0.clear()
	_beast1.clear()
	for fi in 18:
		var col0 := fi / 6
		var row0 := fi % 6
		_beast0.append(_U4Lzw.crop(animate_img, col0 * 56, row0 * 32, BEAST0_W, BEAST0_H))
		var col1 := fi / 6
		var row1 := fi % 6
		## graphics.b: beast1 col0@176, col1@224, col2@272 — stride 48
		_beast1.append(_U4Lzw.crop(animate_img, 176 + col1 * 48, row1 * 32, BEAST1_W, BEAST1_H))

	_TileBank.ensure_loaded()
	_reset_objects()
	_init_titles()
	set_mode(Mode.TITLES)
	set_process(true)
	return true


func set_mode(m: int) -> void:
	mode = m
	if m == Mode.TITLES:
		_beasties_visible = false
		_beastie_offset = -32
		_title_i = 0
		_skip_titles = false
		_accum = Image.create(LOGIC_W, LOGIC_H, false, Image.FORMAT_RGBA8)
		_accum.fill(Color.BLACK)
		_title_time0_ms = Time.get_ticks_msec()
		if not _titles.is_empty():
			_titles[0]["time_base"] = 0
			_titles[0]["anim_step"] = 0
		_title_ready = true
	elif m == Mode.MAP:
		_beasties_visible = true
		_beastie_offset = -32
		_scr_pos = 0
		_sleep_cycles = 0
		_map_accum = 0.0
		_reset_objects()
	elif m == Mode.MENU:
		_beasties_visible = true
		if _beastie_offset < 0:
			_beastie_offset = 0
	mode_changed.emit(mode)
	_redraw()


func skip_titles_or_advance() -> void:
	match mode:
		Mode.TITLES:
			_skip_titles = true
			set_mode(Mode.MAP)
		Mode.MAP:
			set_mode(Mode.MENU)
		_:
			pass


func return_to_map() -> void:
	if mode == Mode.MENU:
		set_mode(Mode.MAP)


func _process(delta: float) -> void:
	if mode == Mode.TITLES:
		if not _update_titles():
			set_mode(Mode.MAP)
			return
		_redraw()
	elif mode == Mode.MAP or mode == Mode.MENU:
		_map_accum += delta
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
				var want_frame: int = second >> 5
				var base_id: int = base_tiles[idx] if idx < base_tiles.size() else 0
				var frames := maxi(1, _TileBank.frame_count(base_id))
				if want_frame >= frames:
					_obj_tile[idx] = base_id + 1
					_obj_frame[idx] = want_frame - frames
				else:
					_obj_tile[idx] = base_id
					_obj_frame[idx] = want_frame
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
			## _accum already has live title sequence; copy to canvas
			_canvas.blit_rect(_accum, Rect2i(0, 0, LOGIC_W, LOGIC_H), Vector2i.ZERO)
		Mode.MAP, Mode.MENU:
			if _title_img:
				_canvas.blit_rect(_title_img, Rect2i(0, 0, LOGIC_W, LOGIC_H), Vector2i.ZERO)
			else:
				_canvas.fill(Color.BLACK)
			_draw_map_static()
			_draw_map_animated()
			if mode == Mode.MENU and _options_btm:
				_canvas.blit_rect(_options_btm, Rect2i(0, 0, _options_btm.get_width(), _options_btm.get_height()), Vector2i(0, OPTIONS_BTM_Y))
			if _beasties_visible:
				_draw_beasties()
	if _tex:
		_tex.update(_canvas)


func _draw_map_static() -> void:
	var m: PackedByteArray = _bin.intro_map
	for y in MAP_H:
		for x in MAP_W:
			var tid: int = m[x + y * MAP_W]
			_blit_tile16(tid, 0, MAP_X + x * TILE_PX, MAP_Y + y * TILE_PX)


func _draw_map_animated() -> void:
	var m: PackedByteArray = _bin.intro_map
	for i in _obj_active.size():
		if _obj_active[i] == 0:
			continue
		var ox: int = _obj_x[i]
		var oy: int = _obj_y[i]
		if ox < 0 or ox >= MAP_W or oy < 0 or oy >= MAP_H:
			continue
		## underdraw ground then object (alpha blend)
		var ground: int = m[ox + oy * MAP_W]
		_blit_tile16(ground, 0, MAP_X + ox * TILE_PX, MAP_Y + oy * TILE_PX)
		_blit_tile16(_obj_tile[i], _obj_frame[i], MAP_X + ox * TILE_PX, MAP_Y + oy * TILE_PX, true)


func _blit_tile16(tile_id: int, frame: int, dx: int, dy: int, blend: bool = false) -> void:
	var src: Image = _TileBank.image(tile_id, frame)
	if src == null:
		return
	var key := "%d:%d" % [tile_id, frame]
	var small: Image
	if _tile_cache_16.has(key):
		small = _tile_cache_16[key]
	else:
		small = src.duplicate()
		small.resize(TILE_PX, TILE_PX, Image.INTERPOLATE_NEAREST)
		_tile_cache_16[key] = small
	if blend:
		_canvas.blend_rect(small, Rect2i(0, 0, TILE_PX, TILE_PX), Vector2i(dx, dy))
	else:
		_canvas.blit_rect(small, Rect2i(0, 0, TILE_PX, TILE_PX), Vector2i(dx, dy))


func _draw_beasties() -> void:
	var f1: int = 0
	var f2: int = 0
	if _bin and _bin.beastie1_frames.size() > 0:
		f1 = _bin.beastie1_frames[_beastie1_cycle % _bin.beastie1_frames.size()]
	if _bin and _bin.beastie2_frames.size() > 0:
		f2 = _bin.beastie2_frames[_beastie2_cycle % _bin.beastie2_frames.size()]
	f1 = clampi(f1, 0, 17)
	f2 = clampi(f2, 0, 17)
	var y := _beastie_offset
	if f1 < _beast0.size() and _beast0[f1] != null:
		_canvas.blend_rect(_beast0[f1], Rect2i(0, 0, BEAST0_W, BEAST0_H), Vector2i(0, y))
	if f2 < _beast1.size() and _beast1[f2] != null:
		_canvas.blend_rect(_beast1[f2], Rect2i(0, 0, BEAST1_W, BEAST1_H), Vector2i(LOGIC_W - BEAST1_W, y))


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
	_add_title(59, 33, 202, 46, AnimType.TITLE, 1000, 5000)
	_add_title(40, 80, 240, 13, AnimType.SUBTITLE, 1000, 100)
	_add_title(0, 96, 320, 96, AnimType.MAP, 1000, 100)
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
			if x < LOGIC_W and y < LOGIC_H:
				im.set_pixel(x, y, Color.BLACK)
	## EGA red bar under Origin (also animated by BAR title step)
	var bar_c := Color8(128, 0, 0)
	for x in range(84, 236):
		if x < LOGIC_W and 31 < LOGIC_H:
			im.set_pixel(x, 31, bar_c)


func _blit_self(im: Image, dx: int, dy: int, sx: int, sy: int, w: int, h: int) -> void:
	## Copy within same image via a temp so overlapping source/dest is safe.
	if im == null or w <= 0 or h <= 0:
		return
	var r := Rect2i(sx, sy, w, h).intersection(Rect2i(0, 0, im.get_width(), im.get_height()))
	if r.size.x <= 0 or r.size.y <= 0:
		return
	var tmp := im.get_region(r)
	im.blit_rect(tmp, Rect2i(0, 0, r.size.x, r.size.y), Vector2i(dx + (r.position.x - sx), dy + (r.position.y - sy)))


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
	if _title_img == null:
		return
	for i in _titles.size():
		var t: Dictionary = _titles[i]
		var method: int = t["method"]
		if method != AnimType.SIGNATURE and method != AnimType.BAR:
			t["src"] = _U4Lzw.crop(_title_img, t["rx"], t["ry"], t["rw"], t["rh"])
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
							var c := src_img.get_pixel(xx, yy)
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
				t["anim_step_max"] = int(t["rh"] / 2) + 1
			AnimType.MAP:
				t["anim_step_max"] = 20
		_titles[i] = t


func _update_titles() -> bool:
	## true while still playing titles
	if _title_i >= _titles.size():
		return false
	var t: Dictionary = _titles[_title_i]
	var now := Time.get_ticks_msec()
	if int(t["time_base"]) == 0:
		t["time_base"] = now
		if _title_i == 0:
			_accum.fill(Color.BLACK)
	if _skip_titles:
		## finish remaining instantly via MAP mode switch outside
		return false

	var elapsed: int = now - int(t["time_base"])
	if elapsed < int(t["time_delay"]):
		_titles[_title_i] = t
		return true

	var pct: float = float(elapsed - int(t["time_delay"])) / float(maxi(1, int(t["time_duration"])))
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
				step = mini(maxi(step + 1, target), t["anim_step_max"])
				dest.fill(Color(0, 0, 0, 0))
				## center-out rows
				var mid: int = int(t["rh"] / 2)
				var y: int = mid - step + 1
				var h: int = 1 + (step - 1) * 2
				if y < 0:
					y = 0
				if y + h > t["rh"]:
					h = t["rh"] - y
				if h > 0 and y >= 0:
					dest.blit_rect(t["src"], Rect2i(0, y, t["rw"], h), Vector2i(1, y + 1))
			t["anim_step"] = step
		AnimType.MAP:
			step = mini(target + 1, t["anim_step_max"])
			dest.fill(Color(0, 0, 0, 0))
			## open curtains of bottom title band + static map under
			if t["src"]:
				var s: int = mini(step, t["anim_step_max"] - 1)
				var strip_w: int = (s + 1) * 8
				## simplified left/right open of full MAP region
				var half := LOGIC_W / 2
				var left_x := half - strip_w
				if left_x < 0:
					left_x = 0
				if strip_w * 2 > 0:
					var ww := mini(strip_w * 2, t["rw"])
					var sx := maxi(0, (t["rw"] - ww) / 2)
					dest.blit_rect(t["src"], Rect2i(sx, 0, ww, t["rh"]), Vector2i(1 + sx, 1))
			## start map tiles under the MAP band
			_draw_map_onto(_accum)
			t["anim_step"] = step

	## composite: dest over accum at rx,ry (only opaque src band)
	_blit_dest_to_accum(t)
	_titles[_title_i] = t

	if int(t["anim_step"]) >= int(t["anim_step_max"]):
		## freeze completed element into accum permanently
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
	## Signature plots sit on those same coordinates (including y==rh when rh is 16).
	var dw := dest.get_width()
	var dh := dest.get_height()
	for y in rh:
		for x in rw:
			var sx := x + 1
			var sy := y + 1
			if sx < 0 or sy < 0 or sx >= dw or sy >= dh:
				continue
			var c := dest.get_pixel(sx, sy)
			if c.a < 0.01:
				continue
			var dx := rx + x
			var dy := ry + y
			if dx >= 0 and dy >= 0 and dx < LOGIC_W and dy < LOGIC_H:
				_accum.set_pixel(dx, dy, Color(c.r, c.g, c.b, 1.0))
	if permanent:
		pass


func _draw_map_onto(img: Image) -> void:
	## Quick static map into map band of an image (for title MAP open).
	if _bin == null or img == null:
		return
	var m: PackedByteArray = _bin.intro_map
	var saved := _canvas
	_canvas = img
	for y in MAP_H:
		for x in MAP_W:
			var tid: int = m[x + y * MAP_W]
			_blit_tile16(tid, 0, MAP_X + x * TILE_PX, MAP_Y + y * TILE_PX)
	_canvas = saved
