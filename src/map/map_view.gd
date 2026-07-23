class_name MapView
extends TextureRect

## Renders Ultima IV explore view by blitting u4graphics shapes.png into an ImageTexture.
## Explore: fixed VIEW_W × VIEW_H grid; STRETCH_SCALE applies mild tall-tile aspect.

const VIEW_H := 11
const VIEW_W := 25 ## Tuned between CRT 5:6 (~27) and square 1:1 (~23).
const VIEW_W_MIN := VIEW_W
## Implied tile width/height when VIEW_W×VIEW_H fills the map pane (~9:10).
const TILE_ASPECT := 9.0 / 10.0
const U4_ATLAS := "res://assets/tiles/u4graphics/shapes.png"
const TILE_SRC := 32
## Fallback Avatar tiles (when class unknown): 31 ↔ 30.
const AVATAR_TILE_A := 31
const AVATAR_TILE_B := 30
## Class walk sprites (same pairs as party roster portraits).
const CLASS_TILE_EVEN := [32, 34, 36, 38, 40, 42, 44, 46]
## Even/odd dwell — randomized each flip, hard-capped so neither frame sticks.
const AVATAR_FRAME_MIN := 0.28
const AVATAR_FRAME_MAX := 0.55
## Classic U4 water (deep / medium / shallow) — vertical pixel scroll wrap.
const WATER_TILE_MAX := 2 # ids 0..2
## Seconds per 1px scroll step (xu4-like flow). Tune anytime.
const WATER_SCROLL_PERIOD := 0.12
## Temporary transport sprites (shapes.png indices).
const TILE_SHIP_W := 16
const TILE_SHIP_N := 17
const TILE_SHIP_E := 18
const TILE_SHIP_S := 19
const TILE_HORSE_W := 20
const TILE_HORSE_E := 21
## Mounted party marker (person on horse) — left / right.
const HORSE_RIDER_W_PATH := "res://assets/tiles/horse_rider_w.png"
const HORSE_RIDER_E_PATH := "res://assets/tiles/horse_rider_e.png"

## Trial: smooth one-tile camera scroll. Set false to snap instantly again.
## Three-frame scroll: 1/3 → 2/3 → arrive (chunky, easy to revert).
const SMOOTH_SCROLL := true
const SCROLL_STEPS := 3

var world: WorldMapData
var atlas_img: Image
var center := Vector2i(83, 105)
## Visible tile grid (odd so the party sits on a true center tile).
var view_w: int = VIEW_W
var view_h: int = VIEW_H

var _buf: Image
var _stage: Image ## (view+1) staging buffer for sub-tile scroll
var _tex: ImageTexture
var _avatar_a: Image
var _avatar_b: Image
## Temporary world overlays: Vector3i(x, y, tile_id) — horse/ship stubs, etc.
var _overlays: Array[Vector3i] = []
var _overlay_slices: Dictionary = {} ## tile_id → keyed Image
## When >= 0, party marker draws this transport tile instead of the walker.
var _transport_tile := -1
## Cached mounted sprites (horse + rider); rebuilt when party leader class changes.
var _horse_rider_w: Image
var _horse_rider_e: Image
var _horse_rider_class := -999
## Fallback Avatar-on-horse art from disk.
var _horse_rider_w_asset: Image
var _horse_rider_e_asset: Image

var _scroll_from := Vector2i.ZERO
var _scroll_dir := Vector2i.ZERO
## Frames left in the stepwise scroll (SCROLL_STEPS … 1). 0 = settled.
var _scroll_frames_left := 0
var _scroll_skip_process := false
var _avatar_frame := 0
var _frame_cd := 0.0
var _cached_leader_class := -2
var _water_scroll := 0
var _water_cd := WATER_SCROLL_PERIOD


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	## Non-uniform fill: square source tiles → VIEW_W×VIEW_H aspect on screen.
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_buffers()
	_load_horse_rider_assets()
	texture = _tex


func setup(p_world: WorldMapData, p_atlas: Texture2D) -> void:
	world = p_world
	atlas_img = null
	_avatar_a = null
	_avatar_b = null
	_horse_rider_class = -999
	if p_atlas != null:
		atlas_img = p_atlas.get_image()
		if atlas_img == null or atlas_img.is_empty():
			var path := p_atlas.resource_path
			if path.is_empty():
				path = U4_ATLAS
			var img := Image.new()
			if img.load(path) == OK:
				atlas_img = img
	if atlas_img == null or atlas_img.is_empty():
		atlas_img = _load_image_path(U4_ATLAS)
	if atlas_img != null and not atlas_img.is_empty():
		if atlas_img.get_format() != Image.FORMAT_RGBA8:
			atlas_img.convert(Image.FORMAT_RGBA8)
		_cache_avatar_icons()
	_scroll_frames_left = 0
	_avatar_frame = 0
	_roll_frame_cd()
	_rebuild()


func set_view_tiles(cols: int, rows: int = VIEW_H) -> void:
	## Resize the visible tile grid (cols fill/clip map width; rows default 11).
	var nw := maxi(cols, 1)
	var nh := maxi(rows, 1)
	# Prefer odd sizes so the party marker sits on a true center cell.
	if nw % 2 == 0:
		nw += 1
	if nh % 2 == 0:
		nh += 1
	if nw == view_w and nh == view_h:
		return
	view_w = nw
	view_h = nh
	_buf = null
	_stage = null
	_rebuild()


func displayed_tile_size() -> Vector2:
	## On-screen tile size with STRETCH_SCALE filling the pane.
	var psz := size
	if psz.x < 1.0 or psz.y < 1.0 or view_w < 1 or view_h < 1:
		return Vector2.ZERO
	return Vector2(psz.x / float(view_w), psz.y / float(view_h))


func displayed_tile_px() -> float:
	## Horizontal on-screen tile size (for side-panel width).
	return displayed_tile_size().x


func cols_for_pane(_pane: Vector2) -> int:
	## Explore width is fixed (VIEW_W); pane stretch sets the tile aspect.
	return VIEW_W


func is_scrolling() -> bool:
	return SMOOTH_SCROLL and _scroll_frames_left > 0


func finish_scroll() -> void:
	## Snap to logical center so the next step can start immediately.
	if _scroll_frames_left == 0:
		return
	_scroll_frames_left = 0
	_scroll_skip_process = false
	_rebuild()


func set_center(tile: Vector2i, animate: bool = true) -> void:
	if tile == center and _scroll_frames_left == 0:
		return
	var step := _unwrap_step(center, tile)
	if (
		SMOOTH_SCROLL
		and animate
		and absi(step.x) + absi(step.y) == 1
		and world != null
		and world.loaded
	):
		_scroll_from = center
		_scroll_dir = step
		_scroll_frames_left = SCROLL_STEPS
		_scroll_skip_process = true
		center = tile
		_rebuild()
	else:
		center = tile
		_scroll_frames_left = 0
		_scroll_dir = Vector2i.ZERO
		_rebuild()


func set_overlays(items: Array[Vector3i]) -> void:
	## World-space transport / object stubs drawn over terrain (under party).
	_overlays = items.duplicate()
	_overlay_slices.clear()
	_rebuild()


func get_overlays() -> Array[Vector3i]:
	return _overlays.duplicate()


func overlay_at(tile: Vector2i) -> int:
	## Tile id of an overlay at `tile`, or -1 if none.
	for item in _overlays:
		if int(item.x) == tile.x and int(item.y) == tile.y:
			return int(item.z)
	return -1


func remove_overlay_at(tile: Vector2i) -> int:
	## Removes and returns the overlay tile id at `tile`, or -1.
	for i in _overlays.size():
		var item: Vector3i = _overlays[i]
		if int(item.x) == tile.x and int(item.y) == tile.y:
			_overlays.remove_at(i)
			_rebuild()
			return int(item.z)
	return -1


func add_overlay(tile: Vector2i, tile_id: int) -> void:
	## Replace any existing overlay on this cell, then add.
	for i in range(_overlays.size() - 1, -1, -1):
		var item: Vector3i = _overlays[i]
		if int(item.x) == tile.x and int(item.y) == tile.y:
			_overlays.remove_at(i)
	_overlays.append(Vector3i(tile.x, tile.y, tile_id))
	_rebuild()


func set_transport_tile(tile_id: int) -> void:
	## -1 = walk on foot (class sprite); else horse/ship tile under the party.
	if _transport_tile == tile_id:
		return
	_transport_tile = tile_id
	_rebuild()


func transport_tile() -> int:
	return _transport_tile


static func is_ship_tile(tile_id: int) -> bool:
	return tile_id >= TILE_SHIP_W and tile_id <= TILE_SHIP_S


static func is_horse_tile(tile_id: int) -> bool:
	return tile_id == TILE_HORSE_W or tile_id == TILE_HORSE_E


static func ship_tile_for_dir(dir: Vector2i) -> int:
	if dir.y < 0:
		return TILE_SHIP_N
	if dir.y > 0:
		return TILE_SHIP_S
	if dir.x > 0:
		return TILE_SHIP_E
	return TILE_SHIP_W


static func horse_tile_for_dir(dir: Vector2i) -> int:
	## Only E/W art exists — north/south keep last east/west facing via caller.
	if dir.x > 0:
		return TILE_HORSE_E
	if dir.x < 0:
		return TILE_HORSE_W
	return -1


static func dir_for_ship_tile(tile_id: int) -> Vector2i:
	match tile_id:
		TILE_SHIP_N:
			return Vector2i(0, -1)
		TILE_SHIP_S:
			return Vector2i(0, 1)
		TILE_SHIP_E:
			return Vector2i(1, 0)
		TILE_SHIP_W:
			return Vector2i(-1, 0)
		_:
			return Vector2i(-1, 0)


func _unwrap_step(from: Vector2i, to: Vector2i) -> Vector2i:
	var d := to - from
	var w := WorldMapData.WIDTH
	var h := WorldMapData.HEIGHT
	if d.x > w / 2:
		d.x -= w
	elif d.x < -w / 2:
		d.x += w
	if d.y > h / 2:
		d.y -= h
	elif d.y < -h / 2:
		d.y += h
	return d


func _process(delta: float) -> void:
	# Party #1 may change via reorder — refresh walker sprite.
	var lead := GameState.party_leader_class()
	if lead != _cached_leader_class and atlas_img != null:
		_cache_avatar_icons()
		_rebuild()

	_frame_cd -= delta
	var frame_changed := false
	if _frame_cd <= 0.0:
		_avatar_frame = 1 - _avatar_frame
		_roll_frame_cd()
		frame_changed = true

	_water_cd -= delta
	var water_changed := false
	if _water_cd <= 0.0:
		_water_cd = WATER_SCROLL_PERIOD
		_water_scroll = (_water_scroll + 1) % TILE_SRC
		water_changed = true

	if _scroll_frames_left > 0:
		# Same frame as set_center — keep first pose on screen for one full frame.
		if _scroll_skip_process:
			_scroll_skip_process = false
			if frame_changed or water_changed:
				_rebuild()
			return
		_scroll_frames_left -= 1
		_rebuild()
		return

	if frame_changed or water_changed:
		_rebuild()


func _roll_frame_cd() -> void:
	_frame_cd = randf_range(AVATAR_FRAME_MIN, AVATAR_FRAME_MAX)


func _load_image_path(path: String) -> Image:
	var img := Image.new()
	if img.load(path) != OK:
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


func _avatar_tile_pair() -> Vector2i:
	## Map walker is always party #1 (formation order).
	var cls := GameState.party_leader_class()
	if cls >= 0 and cls < CLASS_TILE_EVEN.size():
		var even: int = CLASS_TILE_EVEN[cls]
		return Vector2i(even, even + 1)
	return Vector2i(AVATAR_TILE_A, AVATAR_TILE_B)


func _cache_avatar_icons() -> void:
	_avatar_a = null
	_avatar_b = null
	if atlas_img == null or atlas_img.is_empty():
		return
	var pair := _avatar_tile_pair()
	_avatar_a = _slice_keyed_tile(pair.x)
	_avatar_b = _slice_keyed_tile(pair.y)
	if _avatar_b == null:
		_avatar_b = _avatar_a
	_cached_leader_class = GameState.party_leader_class()
	## Remount art must match the new walker class.
	_horse_rider_class = -999


func _load_horse_rider_assets() -> void:
	_horse_rider_w_asset = _load_image_path(HORSE_RIDER_W_PATH)
	_horse_rider_e_asset = _load_image_path(HORSE_RIDER_E_PATH)
	if _horse_rider_w == null:
		_horse_rider_w = _horse_rider_w_asset
	if _horse_rider_e == null:
		_horse_rider_e = _horse_rider_e_asset


func _ensure_horse_riders() -> void:
	## Live-composite horse + party #1 upper body when possible; else PNG assets.
	var cls := GameState.party_leader_class()
	if _horse_rider_w != null and _horse_rider_e != null and cls == _horse_rider_class:
		return
	_horse_rider_class = cls
	var composed_w := _compose_horse_rider(TILE_HORSE_W)
	var composed_e := _compose_horse_rider(TILE_HORSE_E)
	_horse_rider_w = composed_w if composed_w != null else _horse_rider_w_asset
	_horse_rider_e = composed_e if composed_e != null else _horse_rider_e_asset


func _compose_horse_rider(horse_id: int) -> Image:
	## Horse base + rider torso from the current party walker sprite.
	if atlas_img == null or _avatar_a == null or _avatar_a.is_empty():
		return null
	var horse := _slice_keyed_tile(horse_id)
	if horse == null or horse.is_empty():
		return null
	var rider := _avatar_a
	var hx0 := TILE_SRC
	var hy0 := TILE_SRC
	var hx1 := -1
	var hy1 := -1
	var px0 := TILE_SRC
	var py0 := TILE_SRC
	var px1 := -1
	var py1 := -1
	for y in TILE_SRC:
		for x in TILE_SRC:
			if horse.get_pixel(x, y).a > 0.5:
				hx0 = mini(hx0, x)
				hy0 = mini(hy0, y)
				hx1 = maxi(hx1, x)
				hy1 = maxi(hy1, y)
			if rider.get_pixel(x, y).a > 0.5:
				px0 = mini(px0, x)
				py0 = mini(py0, y)
				px1 = maxi(px1, x)
				py1 = maxi(py1, y)
	if hx1 < hx0 or py1 < py0:
		return null
	## Keep head + torso; drop legs so they don't hang through the horse.
	var cut_y := py0 + int(float(py1 - py0) * 0.58)
	var seat_x := (hx0 + hx1) / 2
	var seat_y := hy0 + int(float(hy1 - hy0) * 0.22)
	var person_cx := (px0 + px1) / 2
	var ox := seat_x - person_cx
	## Shift rider slightly toward the rump.
	if horse_id == TILE_HORSE_W:
		ox += 3
	else:
		ox -= 3
	var oy := seat_y - cut_y + 1
	var out := horse.duplicate()
	for y in range(py0, cut_y + 1):
		for x in range(px0, px1 + 1):
			var c := rider.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var dx := x + ox
			var dy := y + oy
			if dx < 0 or dy < 0 or dx >= TILE_SRC or dy >= TILE_SRC:
				continue
			out.set_pixel(dx, dy, c)
	return out


func _horse_rider_for_transport() -> Image:
	_ensure_horse_riders()
	if _transport_tile == TILE_HORSE_E:
		return _horse_rider_e
	return _horse_rider_w


func _slice_keyed_tile(tile_id: int) -> Image:
	var max_tid := atlas_img.get_height() / TILE_SRC - 1
	if tile_id < 0 or tile_id > max_tid:
		return null
	var img := Image.create(TILE_SRC, TILE_SRC, false, Image.FORMAT_RGBA8)
	img.blit_rect(atlas_img, Rect2i(0, tile_id * TILE_SRC, TILE_SRC, TILE_SRC), Vector2i.ZERO)
	for y in TILE_SRC:
		for x in TILE_SRC:
			var c := img.get_pixel(x, y)
			if c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return img


func _ensure_buffers() -> void:
	var bw := view_w * TILE_SRC
	var bh := view_h * TILE_SRC
	var sw := (view_w + 1) * TILE_SRC
	var sh := (view_h + 1) * TILE_SRC
	if _buf == null or _buf.get_width() != bw or _buf.get_height() != bh:
		_buf = Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	if _stage == null or _stage.get_width() != sw or _stage.get_height() != sh:
		_stage = Image.create(sw, sh, false, Image.FORMAT_RGBA8)
	if _tex == null:
		_tex = ImageTexture.new()


func _cam_tile() -> Vector2:
	if _scroll_frames_left <= 0:
		return Vector2(center)
	# SCROLL_STEPS → 1/N · … · 1 → arrive
	var n := float(SCROLL_STEPS)
	var done := n - float(_scroll_frames_left) + 1.0
	return Vector2(_scroll_from) + Vector2(_scroll_dir) * (done / n)


func _rebuild() -> void:
	_ensure_buffers()
	_buf.fill(Color(0.05, 0.08, 0.07, 1))

	if atlas_img == null or atlas_img.is_empty():
		_tex.set_image(_buf)
		texture = _tex
		queue_redraw()
		return
	if world == null or not world.loaded:
		_tex.set_image(_buf)
		texture = _tex
		queue_redraw()
		return

	var cam := _cam_tile()
	var base := Vector2i(floori(cam.x), floori(cam.y))
	var frac := cam - Vector2(base)
	var off := Vector2i(
		clampi(int(frac.x * float(TILE_SRC)), 0, TILE_SRC - 1),
		clampi(int(frac.y * float(TILE_SRC)), 0, TILE_SRC - 1)
	)

	var max_tid := maxi(atlas_img.get_height() / TILE_SRC - 1, 0)
	var half_x := view_w / 2
	var half_y := view_h / 2
	# Stage (view+1) so fractional scroll has a strip to reveal.
	for dy in view_h + 1:
		for dx in view_w + 1:
			var tid := clampi(
				world.tile_at(base.x - half_x + dx, base.y - half_y + dy),
				0,
				mini(255, max_tid)
			)
			var dst := Vector2i(dx * TILE_SRC, dy * TILE_SRC)
			if tid <= WATER_TILE_MAX:
				_blit_water_tile(tid, dst)
			else:
				_stage.blit_rect(
					atlas_img,
					Rect2i(0, tid * TILE_SRC, TILE_SRC, TILE_SRC),
					dst
				)

	_buf.blit_rect(
		_stage,
		Rect2i(off.x, off.y, view_w * TILE_SRC, view_h * TILE_SRC),
		Vector2i.ZERO
	)
	_paint_overlays(cam)
	_paint_party_marker()

	_tex.set_image(_buf)
	texture = _tex
	queue_redraw()


func _blit_water_tile(tid: int, dst: Vector2i) -> void:
	## xu4 ATYPE_SCROLL: shift tile rows down by `_water_scroll` px with wrap.
	var src_y0 := tid * TILE_SRC
	var s := posmod(_water_scroll, TILE_SRC)
	if s == 0:
		_stage.blit_rect(atlas_img, Rect2i(0, src_y0, TILE_SRC, TILE_SRC), dst)
		return
	# Lower band of the source tile → top of destination.
	_stage.blit_rect(
		atlas_img,
		Rect2i(0, src_y0 + s, TILE_SRC, TILE_SRC - s),
		dst
	)
	# Upper band → bottom of destination.
	_stage.blit_rect(
		atlas_img,
		Rect2i(0, src_y0, TILE_SRC, s),
		dst + Vector2i(0, TILE_SRC - s)
	)


func _paint_overlays(cam: Vector2) -> void:
	## Draw temporary horse/ship stubs in world space (scroll with terrain).
	if _overlays.is_empty() or atlas_img == null:
		return
	var half_x := view_w / 2
	var half_y := view_h / 2
	for item in _overlays:
		var wx := int(item.x)
		var wy := int(item.y)
		var tid := int(item.z)
		var screen := Vector2(wx, wy) - cam + Vector2(half_x, half_y)
		var px := int(round(screen.x * float(TILE_SRC)))
		var py := int(round(screen.y * float(TILE_SRC)))
		## Cull if fully off the view buffer.
		if px <= -TILE_SRC or py <= -TILE_SRC:
			continue
		if px >= view_w * TILE_SRC or py >= view_h * TILE_SRC:
			continue
		var slice := _overlay_slice(tid)
		if slice == null:
			continue
		_buf.blend_rect(slice, Rect2i(0, 0, TILE_SRC, TILE_SRC), Vector2i(px, py))


func _overlay_slice(tile_id: int) -> Image:
	if _overlay_slices.has(tile_id):
		return _overlay_slices[tile_id] as Image
	var img := _slice_keyed_tile(tile_id)
	_overlay_slices[tile_id] = img
	return img


func _paint_party_marker() -> void:
	## Center tile: transport sprite, or class/Avatar 2-frame walk cycle.
	var dst := Vector2i((view_w / 2) * TILE_SRC, (view_h / 2) * TILE_SRC)
	if _transport_tile >= 0:
		var ride: Image = null
		if is_horse_tile(_transport_tile):
			## Mounted: person-on-horse art (W/E), not the empty horse object tile.
			ride = _horse_rider_for_transport()
		else:
			ride = _overlay_slice(_transport_tile)
		if ride != null and not ride.is_empty():
			_buf.blend_rect(ride, Rect2i(0, 0, TILE_SRC, TILE_SRC), dst)
			return
	var img := _avatar_b if _avatar_frame == 1 and _avatar_b != null else _avatar_a
	if img != null and not img.is_empty():
		_buf.blend_rect(img, Rect2i(0, 0, TILE_SRC, TILE_SRC), dst)
		return
	# Fallback triangle if atlas slice missing.
	var mid := dst + Vector2i(TILE_SRC / 2, TILE_SRC / 2)
	var s := maxi(TILE_SRC / 3, 4)
	var yellow := Color(1.0, 0.85, 0.2, 1)
	for y in range(-s, s + 1):
		for x in range(-s, s + 1):
			var ny := float(y) / float(s)
			var nx := float(x) / float(s)
			if ny < -0.15 and absf(nx) < (-ny * 0.85 + 0.05):
				var px := mid.x + x
				var py := mid.y + y
				if px >= 0 and py >= 0 and px < _buf.get_width() and py < _buf.get_height():
					_buf.set_pixel(px, py, yellow)
