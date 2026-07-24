class_name MapView
extends TextureRect

## Renders Ultima IV explore view by blitting u4graphics shapes.png into an ImageTexture.
## Explore: fixed VIEW_W × VIEW_H grid; STRETCH_SCALE applies mild tall-tile aspect.

## Preload so MapView parses even if global class cache is stale.
const _CombatMapDataScript := preload("res://src/map/combat_map_data.gd")

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
## World terrain ids used by camp margins.
const TILE_SWAMP := 3
const TILE_GRASS := 4
const TILE_BRUSH := 5
const TILE_FOREST := 6
const TILE_HILLS := 7
const TILE_MOUNTAINS := 8
## Mounted party marker (person on horse) — left / right.
const HORSE_RIDER_W_PATH := "res://assets/tiles/horse_rider_w.png"
const HORSE_RIDER_E_PATH := "res://assets/tiles/horse_rider_e.png"
## Camp map / sleeping corpse (shapes index — graphics.b tile_corpse).
const CAMP_W: int = _CombatMapDataScript.WIDTH
const CAMP_H: int = _CombatMapDataScript.HEIGHT
const TILE_CORPSE := 56

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
## Ship grounding jolt — party/ship sprite offset while > 0.
var _shake_left := 0.0
var _shake_dur := 0.0
var _shake_amp := 0.0
## Hole-up camp: 11×11 combat map centered in the wide explore view.
var _camp_map # CombatMapData — preloaded script instance
var _camp_bg: PackedByteArray = PackedByteArray() ## view_w×view_h backdrop (margins)
var _camp_sleepers: Array[Vector2i] = [] ## camp-local coords
var _corpse_slice: Image


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
	_corpse_slice = null
	exit_camp()
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


func is_camping() -> bool:
	return _camp_map != null


func enter_camp(map, sleepers: Array[Vector2i]) -> void:
	## Show CAMP.CON centered; margins from tiles immediately left/right of party.
	_camp_map = map
	_camp_sleepers = sleepers.duplicate()
	_build_camp_background()
	_scroll_frames_left = 0
	_rebuild()


func exit_camp() -> void:
	if _camp_map == null and _camp_sleepers.is_empty() and _camp_bg.is_empty():
		return
	_camp_map = null
	_camp_sleepers.clear()
	_camp_bg = PackedByteArray()
	_rebuild()


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


func shake_ship(duration: float = 0.28, amplitude: float = 2.0) -> void:
	## Brief jolt when Yell-cruise runs aground — subtle ship nudge.
	_shake_dur = maxf(duration, 0.05)
	_shake_left = _shake_dur
	_shake_amp = maxf(amplitude, 0.5)
	_rebuild()


func _shake_offset() -> Vector2i:
	if _shake_left <= 0.0:
		return Vector2i.ZERO
	var fall := clampf(_shake_left / _shake_dur, 0.0, 1.0)
	## Soft decaying nudge — mostly horizontal, 1–2 px feel.
	var ox := int(round(sin(_shake_left * 38.0) * _shake_amp * fall))
	var oy := int(round(cos(_shake_left * 29.0) * _shake_amp * 0.25 * fall))
	return Vector2i(ox, oy)


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

	var shake_changed := false
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		shake_changed = true

	if _scroll_frames_left > 0:
		# Same frame as set_center — keep first pose on screen for one full frame.
		if _scroll_skip_process:
			_scroll_skip_process = false
			if frame_changed or water_changed or shake_changed:
				_rebuild()
			return
		_scroll_frames_left -= 1
		_rebuild()
		return

	if frame_changed or water_changed or shake_changed:
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

	if _camp_map != null:
		_rebuild_camp()
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


func _rebuild_camp() -> void:
	## 11×11 camp map centered; side columns from baked world-side backdrop.
	var max_tid := maxi(atlas_img.get_height() / TILE_SRC - 1, 0)
	var camp_w := CAMP_W
	var camp_h := CAMP_H
	var origin_x := (view_w - camp_w) / 2
	var origin_y := (view_h - camp_h) / 2
	if _camp_bg.size() != view_w * view_h:
		_build_camp_background()

	for dy in view_h:
		for dx in view_w:
			var tid := 4
			var cx := dx - origin_x
			var cy := dy - origin_y
			if cx >= 0 and cy >= 0 and cx < camp_w and cy < camp_h:
				tid = clampi(_camp_map.tile_at(cx, cy), 0, mini(255, max_tid))
			else:
				var bi := dy * view_w + dx
				if bi >= 0 and bi < _camp_bg.size():
					tid = clampi(int(_camp_bg[bi]), 0, mini(255, max_tid))
			var dst := Vector2i(dx * TILE_SRC, dy * TILE_SRC)
			if tid <= WATER_TILE_MAX:
				_blit_water_to_buf(tid, dst)
			else:
				_buf.blit_rect(
					atlas_img,
					Rect2i(0, tid * TILE_SRC, TILE_SRC, TILE_SRC),
					dst
				)

	_paint_camp_sleepers(origin_x, origin_y)
	_tex.set_image(_buf)
	texture = _tex
	queue_redraw()


func _build_camp_background() -> void:
	## Left/right margins from the tile immediately beside the party.
	_camp_bg = PackedByteArray()
	_camp_bg.resize(view_w * view_h)
	_camp_bg.fill(TILE_GRASS)
	var origin_x := (view_w - CAMP_W) / 2
	var right_start := origin_x + CAMP_W
	var left_base := TILE_GRASS
	var right_base := TILE_GRASS
	if world != null and world.loaded:
		left_base = _normalize_camp_margin_tile(int(world.tile_at(center.x - 1, center.y)))
		right_base = _normalize_camp_margin_tile(int(world.tile_at(center.x + 1, center.y)))

	_paint_camp_side_margin(true, origin_x, right_start, left_base)
	_paint_camp_side_margin(false, origin_x, right_start, right_base)

	## Soften the camp | margin seam. Mixed fills keep inlets near camp.
	_blend_camp_edge_into_margins(
		origin_x, right_start,
		_camp_margin_uses_mix(left_base),
		_camp_margin_uses_mix(right_base)
	)
	if _camp_margin_uses_mix(left_base):
		_prune_floating_camp_soft(true, origin_x, right_start, left_base)
	if _camp_margin_uses_mix(right_base):
		_prune_floating_camp_soft(false, origin_x, right_start, right_base)


func _paint_camp_side_margin(
	is_left: bool, origin_x: int, right_start: int, base: int
) -> void:
	if _camp_margin_uses_mix(base):
		_paint_mixed_margin(is_left, origin_x, right_start, base)
	else:
		_paint_land_margin(is_left, origin_x, right_start, base)


func _camp_margin_uses_mix(base: int) -> bool:
	## Water-style irregular soft fingers into a dominant fill.
	return (
		base <= WATER_TILE_MAX
		or base == TILE_SWAMP
		or base == TILE_FOREST
		or base == TILE_HILLS
		or base == TILE_MOUNTAINS
	)


func _blend_camp_edge_into_margins(
	origin_x: int, right_start: int, left_mix: bool, right_mix: bool
) -> void:
	## CAMP.CON corners are brush — extend into the margin.
	## Grass edges bleed outward. Mixed sides keep gaps so fill inlets reach the camp.
	if _camp_map == null:
		return
	for dy in view_h:
		if dy < 0 or dy >= CAMP_H:
			continue
		_extend_camp_edge_row(
			true, origin_x, right_start, dy, int(_camp_map.tile_at(0, dy)), left_mix
		)
		_extend_camp_edge_row(
			false,
			origin_x,
			right_start,
			dy,
			int(_camp_map.tile_at(CAMP_W - 1, dy)),
			right_mix
		)


func _extend_camp_edge_row(
	is_left: bool,
	origin_x: int,
	right_start: int,
	dy: int,
	edge_tid: int,
	mix_side: bool
) -> void:
	var tid := _normalize_camp_margin_tile(edge_tid)
	var depth := 0
	if tid == TILE_BRUSH:
		var near_corner := dy <= 2 or dy >= CAMP_H - 3
		depth = 2 if near_corner else 1
	elif tid == TILE_GRASS:
		depth = 2 + (1 if randf() < 0.55 else 0) ## 2–3 plains bleed
	else:
		return

	for step in depth:
		var dx: int = (origin_x - 1 - step) if is_left else (right_start + step)
		if not _camp_margin_col(dx, is_left, origin_x, right_start):
			break
		## Mixed side: often leave the fill so the seam is not a solid soft wall.
		if mix_side:
			var keep_soft := 0.55 if step == 0 else 0.32
			if tid == TILE_BRUSH and (dy <= 2 or dy >= CAMP_H - 3):
				keep_soft = 0.70 if step == 0 else 0.40 ## corners still connect a bit
			if randf() > keep_soft:
				continue ## leave existing fill
		var out_tid := tid
		if tid == TILE_GRASS and step > 0 and randf() < 0.30:
			out_tid = TILE_BRUSH
		elif tid == TILE_BRUSH and step > 0 and randf() < 0.20:
			out_tid = TILE_GRASS
		_camp_bg[dy * view_w + dx] = out_tid


func _paint_land_margin(is_left: bool, origin_x: int, right_start: int, base: int) -> void:
	## Grass / brush: ~85% neighbour terrain, sprinkle plains / brush.
	for dy in view_h:
		for dx in view_w:
			if not _camp_margin_col(dx, is_left, origin_x, right_start):
				continue
			var tid := base
			if randf() > 0.85:
				tid = TILE_GRASS if randf() < 0.55 else TILE_BRUSH
			_camp_bg[dy * view_w + dx] = tid


func _paint_mixed_margin(
	is_left: bool, origin_x: int, right_start: int, fill_tid: int
) -> void:
	## Mostly dominant fill (~80%), with soft clearings from the camp edge
	## (same irregular shore pattern used for water). Soft stays camp-connected.
	for dy in view_h:
		for dx in view_w:
			if _camp_margin_col(dx, is_left, origin_x, right_start):
				_camp_bg[dy * view_w + dx] = fill_tid

	var left_w := origin_x
	var right_w := view_w - right_start
	var margin_w: int = left_w if is_left else right_w
	if margin_w < 1:
		return

	## Per-row soft fingers with gaps — inner columns can stay fill (inlets to camp).
	for dy in view_h:
		var shore := 0
		if randf() < 0.48:
			shore = 1
		if randf() < 0.28:
			shore = maxi(shore, 2)
		if randf() < 0.10:
			shore = maxi(shore, 3)
		## Many rows keep fill all the way to the camp edge.
		if randf() < 0.34:
			shore = 0
		shore = mini(shore, margin_w)
		for step in shore:
			var dx: int = (origin_x - 1 - step) if is_left else (right_start + step)
			if not _camp_margin_col(dx, is_left, origin_x, right_start):
				break
			## Even inside a finger, leave occasional fill holes.
			if randf() < 0.28:
				continue
			_camp_bg[dy * view_w + dx] = _camp_soft_tid(fill_tid)

	## Mild sideways bleed so neighbouring rows don't form a ruler-straight front.
	for dy in view_h:
		for dx in view_w:
			if not _camp_margin_col(dx, is_left, origin_x, right_start):
				continue
			var i := dy * view_w + dx
			if not _camp_is_fill_tid(int(_camp_bg[i]), fill_tid):
				continue
			if not _camp_margin_has_soft_tile_neighbor(dx, dy, is_left, origin_x, right_start, fill_tid):
				continue
			var outer := _camp_margin_outer(dx, is_left, origin_x, right_start, margin_w)
			var p_grow := 0.16 * (1.0 - outer)
			if randf() < p_grow:
				_camp_bg[i] = _camp_soft_tid(fill_tid)

	_prune_floating_camp_soft(is_left, origin_x, right_start, fill_tid)
	_trim_camp_margin_soft(is_left, origin_x, right_start, fill_tid, margin_w, 0.22)


func _camp_soft_tid(fill_tid: int) -> int:
	## Soft clearings mixed into a dominant fill (camp-side "shore").
	match fill_tid:
		TILE_MOUNTAINS:
			var r := randf()
			if r < 0.28:
				return TILE_HILLS
			return TILE_GRASS if r < 0.65 else TILE_BRUSH
		TILE_HILLS:
			var r2 := randf()
			if r2 < 0.10:
				return TILE_MOUNTAINS
			return TILE_GRASS if r2 < 0.60 else TILE_BRUSH
		TILE_FOREST:
			## Prefer brush next to forest; occasional grass.
			return TILE_BRUSH if randf() < 0.62 else TILE_GRASS
		TILE_SWAMP:
			## Swamp clearings lean grassy; rare shallow water speck.
			var r3 := randf()
			if r3 < 0.08:
				return 2 ## shallow
			return TILE_GRASS if r3 < 0.70 else TILE_BRUSH
		_:
			## Water fill — classic grass / brush shore.
			return TILE_GRASS if randf() < 0.55 else TILE_BRUSH


func _camp_is_fill_tid(tid: int, fill_tid: int) -> bool:
	if fill_tid <= WATER_TILE_MAX:
		return tid <= WATER_TILE_MAX
	return tid == fill_tid


func _camp_is_soft_tid(tid: int, fill_tid: int) -> bool:
	return not _camp_is_fill_tid(tid, fill_tid)


func _camp_margin_col(dx: int, is_left: bool, origin_x: int, right_start: int) -> bool:
	if is_left:
		return dx >= 0 and dx < origin_x
	return dx >= right_start and dx < view_w


func _camp_margin_outer(
	dx: int, is_left: bool, origin_x: int, right_start: int, margin_w: int
) -> float:
	## 1 = outer edge, 0 = against the camp.
	if margin_w <= 1:
		return 0.0
	if is_left:
		return 1.0 - float(dx) / float(margin_w - 1)
	return float(dx - right_start) / float(margin_w - 1)


func _camp_margin_has_soft_tile_neighbor(
	dx: int, dy: int, is_left: bool, origin_x: int, right_start: int, fill_tid: int
) -> bool:
	## Orthogonally next to an actual soft tile in this margin (not the camp block).
	if _camp_margin_col(dx + 1, is_left, origin_x, right_start):
		if _camp_is_soft_tid(int(_camp_bg[dy * view_w + (dx + 1)]), fill_tid):
			return true
	if _camp_margin_col(dx - 1, is_left, origin_x, right_start):
		if _camp_is_soft_tid(int(_camp_bg[dy * view_w + (dx - 1)]), fill_tid):
			return true
	if dy + 1 < view_h and _camp_margin_col(dx, is_left, origin_x, right_start):
		if _camp_is_soft_tid(int(_camp_bg[(dy + 1) * view_w + dx]), fill_tid):
			return true
	if dy - 1 >= 0 and _camp_margin_col(dx, is_left, origin_x, right_start):
		if _camp_is_soft_tid(int(_camp_bg[(dy - 1) * view_w + dx]), fill_tid):
			return true
	return false


func _trim_camp_margin_soft(
	is_left: bool,
	origin_x: int,
	right_start: int,
	fill_tid: int,
	margin_w: int,
	max_soft_frac: float
) -> void:
	## If soft overshoots, carve from the outer edge first, then re-prune floats.
	var cells: Array[Vector2i] = []
	var soft_n := 0
	for dy in view_h:
		for dx in view_w:
			if not _camp_margin_col(dx, is_left, origin_x, right_start):
				continue
			cells.append(Vector2i(dx, dy))
			if _camp_is_soft_tid(int(_camp_bg[dy * view_w + dx]), fill_tid):
				soft_n += 1
	var total := cells.size()
	if total < 1:
		return
	var max_soft := maxi(1, int(round(float(total) * max_soft_frac)))
	if soft_n <= max_soft:
		return
	var soft_cells: Array[Vector2i] = []
	for c in cells:
		if _camp_is_soft_tid(int(_camp_bg[c.y * view_w + c.x]), fill_tid):
			soft_cells.append(c)
	soft_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (
			_camp_margin_outer(a.x, is_left, origin_x, right_start, margin_w)
			> _camp_margin_outer(b.x, is_left, origin_x, right_start, margin_w)
		)
	)
	var remove_n := soft_n - max_soft
	for i in mini(remove_n, soft_cells.size()):
		var c: Vector2i = soft_cells[i]
		_camp_bg[c.y * view_w + c.x] = fill_tid
	_prune_floating_camp_soft(is_left, origin_x, right_start, fill_tid)


func _prune_floating_camp_soft(
	is_left: bool, origin_x: int, right_start: int, fill_tid: int
) -> void:
	## Keep only soft that 4-connects to the camp-adjacent column.
	var seed_dx: int = (origin_x - 1) if is_left else right_start
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = []
	for dy in view_h:
		if not _camp_margin_col(seed_dx, is_left, origin_x, right_start):
			continue
		if _camp_is_soft_tid(int(_camp_bg[dy * view_w + seed_dx]), fill_tid):
			var p := Vector2i(seed_dx, dy)
			queue.append(p)
			seen[_camp_cell_key(p.x, p.y)] = true

	var qi := 0
	while qi < queue.size():
		var cur: Vector2i = queue[qi]
		qi += 1
		var neighbors: Array[Vector2i] = [
			Vector2i(cur.x + 1, cur.y),
			Vector2i(cur.x - 1, cur.y),
			Vector2i(cur.x, cur.y + 1),
			Vector2i(cur.x, cur.y - 1),
		]
		for n in neighbors:
			if n.y < 0 or n.y >= view_h:
				continue
			if not _camp_margin_col(n.x, is_left, origin_x, right_start):
				continue
			var key := _camp_cell_key(n.x, n.y)
			if seen.has(key):
				continue
			if _camp_is_fill_tid(int(_camp_bg[n.y * view_w + n.x]), fill_tid):
				continue
			seen[key] = true
			queue.append(n)

	for dy in view_h:
		for dx in view_w:
			if not _camp_margin_col(dx, is_left, origin_x, right_start):
				continue
			var i := dy * view_w + dx
			if _camp_is_fill_tid(int(_camp_bg[i]), fill_tid):
				continue
			if not seen.has(_camp_cell_key(dx, dy)):
				_camp_bg[i] = fill_tid


func _camp_cell_key(x: int, y: int) -> int:
	return y * 256 + x


func _normalize_camp_margin_tile(tid: int) -> int:
	## Keep water + natural terrain. Settlements / dungeon / props → grass.
	tid = clampi(tid, 0, 255)
	if tid <= WATER_TILE_MAX:
		return tid
	match tid:
		TILE_SWAMP, TILE_GRASS, TILE_BRUSH, TILE_FOREST, TILE_HILLS, TILE_MOUNTAINS:
			return tid
		23, 25, 26: ## bridge / bridge_n / bridge_s
			return TILE_GRASS
		_:
			## dungeon/city/castle/town/LCB and other non-terrain → plains
			return TILE_GRASS


func _blit_water_to_buf(tid: int, dst: Vector2i) -> void:
	var src_y0 := tid * TILE_SRC
	var s := posmod(_water_scroll, TILE_SRC)
	if s == 0:
		_buf.blit_rect(atlas_img, Rect2i(0, src_y0, TILE_SRC, TILE_SRC), dst)
		return
	_buf.blit_rect(
		atlas_img,
		Rect2i(0, src_y0 + s, TILE_SRC, TILE_SRC - s),
		dst
	)
	_buf.blit_rect(
		atlas_img,
		Rect2i(0, src_y0, TILE_SRC, s),
		dst + Vector2i(0, TILE_SRC - s)
	)


func _paint_camp_sleepers(origin_x: int, origin_y: int) -> void:
	if _corpse_slice == null:
		_corpse_slice = _slice_keyed_tile(TILE_CORPSE)
	if _corpse_slice == null:
		return
	for pos in _camp_sleepers:
		var sx := origin_x + pos.x
		var sy := origin_y + pos.y
		if sx < 0 or sy < 0 or sx >= view_w or sy >= view_h:
			continue
		var dst := Vector2i(sx * TILE_SRC, sy * TILE_SRC)
		_buf.blend_rect(_corpse_slice, Rect2i(0, 0, TILE_SRC, TILE_SRC), dst)


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
	dst += _shake_offset()
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
