class_name MapView
extends TextureRect

## Renders Ultima IV explore view by blitting per-tile PNGs (U4TileBank) into an ImageTexture.
## Explore: fixed VIEW_W × VIEW_H grid; STRETCH_SCALE applies mild tall-tile aspect.

## Preload so MapView parses even if global class cache is stale.
const _CombatMapDataScript := preload("res://src/map/combat_map_data.gd")
const _U4TileBankScript := preload("res://src/map/u4_tile_bank.gd")
const _LineOfSightScript := preload("res://src/map/line_of_sight.gd")
## xu4 invisible cells → solid black (not dimmed fog).
const _LOS_BLACK := Color(0, 0, 0, 1)

const VIEW_H := 11
const VIEW_W := 25 ## Tuned between CRT 5:6 (~27) and square 1:1 (~23).
const VIEW_W_MIN := VIEW_W
## Implied tile width/height when VIEW_W×VIEW_H fills the map pane (~9:10).
const TILE_ASPECT := 9.0 / 10.0
## Legacy atlas path kept for docs / external refs; runtime uses shapes/*.png.
const U4_ATLAS := "res://assets/tiles/u4graphics/shapes.png"
const TILE_SRC := 32
const TILE_ID_MAX := 255
## Fallback Avatar tiles (when class unknown): 31 ↔ 30.
const AVATAR_TILE_A := 31
const AVATAR_TILE_B := 30
## Class walk sprites (same pairs as party roster portraits).
const CLASS_TILE_EVEN := [32, 34, 36, 38, 40, 42, 44, 46]
## Even/odd dwell — randomized each flip, hard-capped so neither frame sticks.
const AVATAR_FRAME_MIN := 0.28
const AVATAR_FRAME_MAX := 0.55
## Townsfolk walk cycles — wider spread so they don't flip in lockstep.
const NPC_FRAME_MIN := 0.22
const NPC_FRAME_MAX := 0.85
## Classic U4 water (deep / medium / shallow) — vertical pixel scroll wrap.
const WATER_TILE_MAX := 2 # ids 0..2
## Seconds per 1px scroll step (xu4-like flow). Tune anytime.
const WATER_SCROLL_PERIOD := 0.12
## White stone corner tiles — shallow water under white mask.
const TILE_WHITE_SW := 49
const TILE_WHITE_SE := 50
const TILE_WHITE_NW := 51
const TILE_WHITE_NE := 52
## Y-scroll fields / lava (same clock as water).
const TILE_FIELD_POISON := 68
const TILE_FIELD_ENERGY := 69
const TILE_FIELD_FIRE := 70
const TILE_FIELD_SLEEP := 71
const TILE_SPIT := 75 ## campfire spit — 2-frame fire flicker (`075_spit_1.png`)
const TILE_LAVA := 76
## Multi-frame terrain flip period (spit, etc.).
const TILE_ANIM_PERIOD := 0.20
## Temporary transport sprites (shapes tile indices).
const TILE_SHIP_W := 16
const TILE_SHIP_N := 17
const TILE_SHIP_E := 18
const TILE_SHIP_S := 19
const TILE_HORSE_W := 20
const TILE_HORSE_E := 21
## Bridge tiles — near (south) white railing redrawn over sprites for depth.
const TILE_BRIDGE := 23
const TILE_BRIDGE_N := 25
const TILE_BRIDGE_S := 26
## First source row of the near railing on bridge / bridge_s (32×32 art).
const BRIDGE_NEAR_RAIL_Y := 19
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
## xu4 moongate annotation tiles (shapes 064–067).
const TILE_MOONGATE_0 := 64
const TILE_MOONGATE_OPEN := 67
## Spell / moongate screen invert duration (xu4 mapArea.highlight).
## Moongate travel uses a longer flash via await_spell_flash(MOONGATE_FLASH_SEC).
const SPELL_FLASH_SEC := 0.45
const MOONGATE_FLASH_SEC := 0.85
## Beat between departure flash and arrival flash.
const MOONGATE_TRAVEL_GAP_SEC := 0.35
## Open-gate glow: rectangular rings scroll inward (smooth blue↔white).
const MOONGATE_SUCK_FRAMES := 24
const MOONGATE_SUCK_PERIOD := 0.06

## Trial: smooth one-tile camera scroll. Set false to snap instantly again.
## Three-frame scroll: 1/3 → 2/3 → arrive (chunky, easy to revert).
const SMOOTH_SCROLL := true
const SCROLL_STEPS := 3

var world: WorldMapData
## True once U4TileBank has all 256 individual tile images.
var tiles_ready: bool = false
var center := Vector2i(83, 105)
## Visible tile grid (odd so the party sits on a true center tile).
var view_w: int = VIEW_W
var view_h: int = VIEW_H
## xu4 line-of-sight (DOS). Off for combat/camp (`nolineofsight`).
var los_enabled: bool = true
## xu4 `c->opacity`: when false (balloon aloft), opaque tiles do not block.
var los_opacity: bool = true

var _buf: Image
var _stage: Image ## (view+1) staging buffer for sub-tile scroll
var _tex: ImageTexture
var _avatar_a: Image
var _avatar_b: Image
## Viewport LOS mask relative to `center` (view_w × view_h, 0/1).
var _los: PackedByteArray = PackedByteArray()
## Temporary world overlays: Vector3i(x, y, tile_id) — horse/ship stubs, etc.
var _overlays: Array[Vector3i] = []
var _overlay_slices: Dictionary = {} ## tile_id → keyed Image
## Active Trammel moongate annotation (world map only).
var _moongate_pos := Vector2i(-1, -1)
var _moongate_tid := -1
## Display height in *source tile* pixels (0..TILE_SRC), not screen pixels.
## Advances exactly 1 tile-pixel every MOONGATE_PX_STEP_SEC.
var _moongate_height_px := 0
var _moongate_height_px_target := 0
var _moongate_px_cd := 0.0
## One shapes-tile pixel per step; 32px × (0.52/32)s = 0.52s full rise/fall.
const MOONGATE_PX_STEP_SEC := 0.52 / 32.0
## Procedural inward-suck frames for the open gate art (tile 67).
var _moongate_suck_by_tid: Dictionary = {} ## tid → Array[Image]
var _moongate_suck_i := 0
var _moongate_suck_cd := 0.0
var _moongate_col_blue := Color(0.15, 0.4, 1.0, 1.0)
var _moongate_col_white := Color(1, 1, 1, 1)
## xu4 gameSpellEffect invert — white flash over the explore view.
var _spell_flash_left := 0.0
var _spell_flash_dur := SPELL_FLASH_SEC
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
var _tile_anim_frame := 0
var _tile_anim_cd := TILE_ANIM_PERIOD
## Ship grounding jolt — party/ship sprite offset while > 0.
var _shake_left := 0.0
var _shake_dur := 0.0
var _shake_amp := 0.0
## Hole-up camp: 11×11 combat map centered in the wide explore view.
var _camp_map # CombatMapData — preloaded script instance
var _camp_bg: PackedByteArray = PackedByteArray() ## view_w×view_h backdrop (margins)
var _camp_sleepers: Array[Vector2i] = [] ## camp-local coords
var _camp_guard_pos := Vector2i(-1, -1)
var _camp_guard_class := -1
var _camp_guard_cd := 0.0
var _camp_guard_a: Image
var _camp_guard_b: Image
var _corpse_slice: Image
## City / castle / village (.ULT) — replaces world tiles while set.
var _city_map # CityMapData
## Outside the .ULT grid: baked from the 8 world tiles around the portal (camp-style).
var _city_out: PackedByteArray = PackedByteArray()
var _city_out_pad := 0
var _city_out_stride := 0
var _city_world_pos := Vector2i.ZERO
## 8 neighbours of the portal, normalized (NW N NE W E SW S SE).
var _city_nb: Array[int] = []
## City-edge of the Enter spawn: 0=N 1=E 2=S 3=W — that outside strip is plains.
var _city_enter_side := 2
## Per-person walk frame (independent phase / dwell).
var _npc_frame_bit: Array[int] = []
var _npc_frame_cd: Array[float] = []
var _npc_anim_dirty := false
var _npc_rebuild_cd := 0.0
const NPC_REBUILD_PERIOD := 0.08 ## Cap map redraws from NPC flips (~12 Hz).

const _TileRulesCamp := preload("res://src/map/tile_rules.gd")
## Seconds between random guard steps while Resting…
const CAMP_GUARD_STEP_MIN := 0.35
const CAMP_GUARD_STEP_MAX := 0.75
const _CITY_W := 32
const _CITY_H := 32
## Enough pad so a party on the city rim never sees past the baked ring.
const _CITY_OUT_PAD := 14


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	## Non-uniform fill: square source tiles → VIEW_W×VIEW_H aspect on screen.
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_buffers()
	_load_horse_rider_assets()
	texture = _tex


func setup(p_world: WorldMapData, _p_atlas: Texture2D = null) -> void:
	## `_p_atlas` kept for call-site compatibility; tiles load from shapes/*.png.
	world = p_world
	tiles_ready = false
	_avatar_a = null
	_avatar_b = null
	_horse_rider_class = -999
	_corpse_slice = null
	_overlay_slices.clear()
	_moongate_suck_by_tid.clear()
	exit_camp()
	exit_city()
	tiles_ready = _U4TileBankScript.ensure_loaded()
	if tiles_ready:
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


func is_in_city() -> bool:
	return _city_map != null and _city_map.loaded


func enter_city(
	map,
	start: Vector2i,
	world_pos: Vector2i = Vector2i(-1, -1),
	entrance_spawn: Vector2i = Vector2i(-1, -1)
) -> void:
	## Show .ULT city terrain with party at `start` (city-local coords).
	## `world_pos` = portal tile on WORLD.MAP — used to paint outside margins.
	## `entrance_spawn` = Enter gate cell (portal sx/sy). Rim plains use this, not
	## `start` — load may place the party mid-city far from the gate.
	## Keep world horse/ship overlays (same persistence as save); city view ignores them.
	## Keep mounted transport sprite (horse) — do not reset to foot.
	exit_camp()
	_city_map = map
	_city_world_pos = world_pos
	var rim := start
	if entrance_spawn.x >= 0 and entrance_spawn.y >= 0:
		rim = entrance_spawn
	_city_enter_side = _city_entrance_side(rim)
	_scroll_frames_left = 0
	center = start
	_init_npc_frames()
	_build_city_outside()
	_rebuild()


func exit_city() -> void:
	if _city_map == null and _city_out.is_empty():
		return
	_city_map = null
	_city_out = PackedByteArray()
	_city_out_pad = 0
	_city_out_stride = 0
	_city_nb.clear()
	_city_enter_side = 2
	_npc_frame_bit.clear()
	_npc_frame_cd.clear()
	_npc_anim_dirty = false
	_npc_rebuild_cd = 0.0
	_scroll_frames_left = 0
	_rebuild()


func enter_camp(
	map,
	sleepers: Array[Vector2i],
	guard_class: int = -1,
	guard_pos: Vector2i = Vector2i(-1, -1)
) -> void:
	## Show CAMP.CON centered; margins from tiles immediately left/right of party.
	## U5 watch: optional awake guard who patrols the camp map.
	exit_city()
	_camp_map = map
	_camp_sleepers = sleepers.duplicate()
	_camp_guard_class = guard_class
	_camp_guard_pos = guard_pos
	_camp_guard_cd = CAMP_GUARD_STEP_MIN
	_camp_guard_a = null
	_camp_guard_b = null
	if guard_class >= 0:
		_cache_camp_guard_icons()
		if _camp_guard_pos.x < 0 or _camp_guard_pos.y < 0:
			_camp_guard_pos = Vector2i(CAMP_W / 2, CAMP_H / 2)
	_build_camp_background()
	_scroll_frames_left = 0
	_rebuild()


func exit_camp() -> void:
	if (
		_camp_map == null
		and _camp_sleepers.is_empty()
		and _camp_bg.is_empty()
		and _camp_guard_class < 0
	):
		return
	_camp_map = null
	_camp_sleepers.clear()
	_camp_bg = PackedByteArray()
	_camp_guard_pos = Vector2i(-1, -1)
	_camp_guard_class = -1
	_camp_guard_cd = 0.0
	_camp_guard_a = null
	_camp_guard_b = null
	_rebuild()


func tick_camp_guard(delta: float) -> void:
	## Random orthogonal patrol inside CAMP.CON while resting.
	if _camp_map == null or _camp_guard_class < 0:
		return
	_camp_guard_cd -= delta
	if _camp_guard_cd > 0.0:
		return
	_camp_guard_cd = randf_range(CAMP_GUARD_STEP_MIN, CAMP_GUARD_STEP_MAX)
	_step_camp_guard()
	_rebuild()


func finish_scroll() -> void:
	## Snap to logical center so the next step can start immediately.
	if _scroll_frames_left == 0:
		return
	_scroll_frames_left = 0
	_scroll_skip_process = false
	_rebuild()


func refresh() -> void:
	## Force a redraw (e.g. after city NPCs move on a party turn).
	_rebuild()


func set_center(tile: Vector2i, animate: bool = true) -> void:
	if tile == center and _scroll_frames_left == 0:
		return
	var step := _unwrap_step(center, tile)
	var can_scroll := (
		SMOOTH_SCROLL
		and animate
		and absi(step.x) + absi(step.y) == 1
		and (is_in_city() or (world != null and world.loaded))
	)
	if can_scroll:
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
	_moongate_suck_by_tid.clear()
	_rebuild()


func get_overlays() -> Array[Vector3i]:
	return _overlays.duplicate()


func set_los_enabled(on: bool) -> void:
	## Combat / camp maps set this false (xu4 `NO_LINE_OF_SIGHT`).
	if los_enabled == on:
		return
	los_enabled = on
	_rebuild()


func set_los_opacity(on: bool) -> void:
	## Balloon aloft: `on == false` → see through forests/walls (xu4 opacity).
	if los_opacity == on:
		return
	los_opacity = on
	_rebuild()


func is_tile_visible(wx: int, wy: int) -> bool:
	## World/city tile visibility from the party (`center`).
	if not los_enabled:
		return true
	var half_x := view_w / 2
	var half_y := view_h / 2
	var vx := wx - center.x + half_x
	var vy := wy - center.y + half_y
	if vx < 0 or vy < 0 or vx >= view_w or vy >= view_h:
		return false
	if _los.is_empty():
		return true
	return _los[vy * view_w + vx] != 0


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


func set_moongate(
	tile: Vector2i,
	tile_id: int,
	height_frac: float = 1.0,
	snap: bool = false
) -> void:
	## `height_frac` → target in source-tile pixels (32 = full gate art).
	## `snap`: show at target immediately (load / city exit) — no rise/fall tween.
	var hf := clampf(height_frac, 0.0, 1.0)
	var target_px := clampi(int(round(float(TILE_SRC) * hf)), 0, TILE_SRC)
	var same := (
		_moongate_pos == tile
		and _moongate_tid == tile_id
		and _moongate_height_px_target == target_px
		and (not snap or _moongate_height_px == target_px)
	)
	_moongate_pos = tile
	_moongate_tid = tile_id
	_moongate_height_px_target = target_px
	if snap:
		_moongate_height_px = target_px
		_moongate_px_cd = 0.0
	if same:
		return
	_rebuild()


func clear_moongate() -> void:
	if _moongate_tid < 0 and _moongate_pos.x < 0 and _moongate_height_px <= 0:
		return
	_moongate_pos = Vector2i(-1, -1)
	_moongate_tid = -1
	_moongate_height_px = 0
	_moongate_height_px_target = 0
	_moongate_px_cd = 0.0
	_rebuild()


func moongate_tile_at(tile: Vector2i) -> int:
	## Active moongate tile id at `tile`, or -1.
	if _moongate_tid < 0:
		return -1
	if tile.x != _moongate_pos.x or tile.y != _moongate_pos.y:
		return -1
	return _moongate_tid


func play_spell_flash(duration: float = SPELL_FLASH_SEC) -> void:
	## xu4 mapArea.highlight — brief invert/white flash (non-blocking).
	_spell_flash_dur = maxf(duration, 0.05)
	_spell_flash_left = _spell_flash_dur
	queue_redraw()


func await_spell_flash(duration: float = SPELL_FLASH_SEC) -> void:
	play_spell_flash(duration)
	await get_tree().create_timer(duration).timeout


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


func _draw() -> void:
	## xu4 mapArea.highlight — bright flash over the explore view.
	if _spell_flash_left <= 0.0:
		return
	var t := clampf(_spell_flash_left / _spell_flash_dur, 0.0, 1.0)
	## Soft pulse so a longer flash still reads as lightning, not a static white wash.
	var pulse := 0.55 + 0.45 * absf(sin((1.0 - t) * TAU * 2.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, (0.28 + 0.52 * t) * pulse))


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
	if lead != _cached_leader_class and tiles_ready:
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

	_tile_anim_cd -= delta
	var tile_anim_changed := false
	if _tile_anim_cd <= 0.0:
		_tile_anim_cd = TILE_ANIM_PERIOD
		_tile_anim_frame += 1
		tile_anim_changed = true

	var moongate_changed := false
	if _moongate_tid >= 0 and not is_in_city():
		## Rise/fall in source-tile pixels only (1 of 32 per step — not screen px).
		if _moongate_height_px != _moongate_height_px_target:
			_moongate_px_cd -= delta
			if _moongate_px_cd <= 0.0:
				_moongate_px_cd = MOONGATE_PX_STEP_SEC
				if _moongate_height_px < _moongate_height_px_target:
					_moongate_height_px += 1
				else:
					_moongate_height_px -= 1
				moongate_changed = true
		else:
			_moongate_px_cd = 0.0
		## Color rotation while any part of the gate is visible.
		if _moongate_height_px > 0:
			_moongate_suck_cd -= delta
			if _moongate_suck_cd <= 0.0:
				_moongate_suck_cd = MOONGATE_SUCK_PERIOD
				_moongate_suck_i = (_moongate_suck_i + 1) % MOONGATE_SUCK_FRAMES
				moongate_changed = true

	var npc_changed := false
	if is_in_city() and not _npc_frame_cd.is_empty():
		if _tick_npc_frames(delta):
			_npc_anim_dirty = true
		_npc_rebuild_cd = maxf(0.0, _npc_rebuild_cd - delta)
		if _npc_anim_dirty and _npc_rebuild_cd <= 0.0:
			_npc_anim_dirty = false
			_npc_rebuild_cd = NPC_REBUILD_PERIOD
			npc_changed = true

	var shake_changed := false
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		shake_changed = true

	if _spell_flash_left > 0.0:
		_spell_flash_left = maxf(0.0, _spell_flash_left - delta)
		queue_redraw()

	if _scroll_frames_left > 0:
		# Same frame as set_center — keep first pose on screen for one full frame.
		if _scroll_skip_process:
			_scroll_skip_process = false
			if frame_changed or water_changed or tile_anim_changed or npc_changed or shake_changed or moongate_changed:
				_rebuild()
			return
		_scroll_frames_left -= 1
		_rebuild()
		return

	if frame_changed or water_changed or tile_anim_changed or npc_changed or shake_changed or moongate_changed:
		_rebuild()


func _roll_frame_cd() -> void:
	_frame_cd = randf_range(AVATAR_FRAME_MIN, AVATAR_FRAME_MAX)


func _init_npc_frames() -> void:
	_npc_frame_bit.clear()
	_npc_frame_cd.clear()
	if _city_map == null:
		return
	for _i in _city_map.persons.size():
		_npc_frame_bit.append(randi() & 1)
		## Stagger first flip so the crowd doesn't start in sync.
		_npc_frame_cd.append(randf_range(0.0, NPC_FRAME_MAX))


func _tick_npc_frames(delta: float) -> bool:
	var changed := false
	for i in _npc_frame_cd.size():
		_npc_frame_cd[i] -= delta
		if _npc_frame_cd[i] > 0.0:
			continue
		_npc_frame_bit[i] = 1 - _npc_frame_bit[i]
		_npc_frame_cd[i] = randf_range(NPC_FRAME_MIN, NPC_FRAME_MAX)
		changed = true
	return changed


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
	if not tiles_ready:
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
	if not tiles_ready or _avatar_a == null or _avatar_a.is_empty():
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
	if not tiles_ready or tile_id < 0 or tile_id > TILE_ID_MAX:
		return null
	return _U4TileBankScript.keyed_copy(tile_id)


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

	if not tiles_ready:
		_tex.set_image(_buf)
		texture = _tex
		queue_redraw()
		return

	if _camp_map != null:
		_rebuild_camp()
		return

	if is_in_city():
		_rebuild_city()
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

	var half_x := view_w / 2
	var half_y := view_h / 2
	# Stage (view+1) so fractional scroll has a strip to reveal.
	for dy in view_h + 1:
		for dx in view_w + 1:
			var tid := clampi(
				world.tile_at(base.x - half_x + dx, base.y - half_y + dy),
				0,
				TILE_ID_MAX
			)
			var dst := Vector2i(dx * TILE_SRC, dy * TILE_SRC)
			_blit_terrain_to(_stage, tid, dst)

	_refresh_los()
	_apply_los_blackout_stage(base)

	_buf.blit_rect(
		_stage,
		Rect2i(off.x, off.y, view_w * TILE_SRC, view_h * TILE_SRC),
		Vector2i.ZERO
	)
	_paint_moongate(cam)
	_paint_overlays(cam)
	_paint_party_marker()
	_paint_bridge_near_rails(cam)

	_tex.set_image(_buf)
	texture = _tex
	queue_redraw()


func _rebuild_city() -> void:
	## Same camera blit as world explore, reading from the .ULT tile grid.
	## Out-of-bounds cells use the camp-style outside ring (8 portal neighbours).
	if _city_out.is_empty():
		_build_city_outside()
	var cam := _cam_tile()
	var base := Vector2i(floori(cam.x), floori(cam.y))
	var frac := cam - Vector2(base)
	var off := Vector2i(
		clampi(int(frac.x * float(TILE_SRC)), 0, TILE_SRC - 1),
		clampi(int(frac.y * float(TILE_SRC)), 0, TILE_SRC - 1)
	)
	var half_x := view_w / 2
	var half_y := view_h / 2
	for dy in view_h + 1:
		for dx in view_w + 1:
			var mx := base.x - half_x + dx
			var my := base.y - half_y + dy
			var tid := clampi(_city_tile_or_outside(mx, my), 0, TILE_ID_MAX)
			var dst := Vector2i(dx * TILE_SRC, dy * TILE_SRC)
			_blit_terrain_to(_stage, tid, dst)

	_refresh_los()
	_apply_los_blackout_stage(base)

	_buf.blit_rect(
		_stage,
		Rect2i(off.x, off.y, view_w * TILE_SRC, view_h * TILE_SRC),
		Vector2i.ZERO
	)
	_paint_city_persons(cam)
	_paint_party_marker()
	_paint_bridge_near_rails(cam)
	_tex.set_image(_buf)
	texture = _tex
	queue_redraw()


func _paint_city_persons(cam: Vector2) -> void:
	## Draw .ULT townsfolk with 2-frame walk cycles (tile ↔ prev / even↔odd).
	if _city_map == null or not tiles_ready:
		return
	if _city_map.persons.is_empty():
		return
	var half_x := view_w / 2
	var half_y := view_h / 2
	for i in _city_map.persons.size():
		var p: Vector3i = _city_map.persons[i]
		if not is_tile_visible(int(p.x), int(p.y)):
			continue
		var screen := Vector2(p.x, p.y) - cam + Vector2(half_x, half_y)
		var px := int(round(screen.x * float(TILE_SRC)))
		var py := int(round(screen.y * float(TILE_SRC)))
		if px <= -TILE_SRC or py <= -TILE_SRC:
			continue
		if px >= view_w * TILE_SRC or py >= view_h * TILE_SRC:
			continue
		var prev := -1
		if i < _city_map.person_prev.size():
			prev = int(_city_map.person_prev[i])
		var draw_tid := _npc_frame_tile(int(p.z), prev, i)
		var slice := _overlay_slice(draw_tid)
		if slice == null:
			continue
		_buf.blend_rect(slice, Rect2i(0, 0, TILE_SRC, TILE_SRC), Vector2i(px, py))


func _npc_frame_tile(tid: int, prev: int, person_i: int) -> int:
	## Townsfolk / class sprites: flip between the two walk frames.
	## Prefer .ULT prev↔tile pair; else even/odd for known ranges.
	var a := tid
	var b := tid
	if prev >= 0 and prev <= TILE_ID_MAX and prev != tid:
		a = mini(tid, prev)
		b = maxi(tid, prev)
	elif (tid >= 32 and tid <= 47) or (tid >= 80 and tid <= 95):
		a = tid & ~1
		b = a + 1
	else:
		return tid
	if a == b:
		return a
	var bit := 0
	if person_i >= 0 and person_i < _npc_frame_bit.size():
		bit = _npc_frame_bit[person_i]
	return b if bit == 1 else a


func _city_tile_or_outside(x: int, y: int) -> int:
	if _city_map != null and x >= 0 and y >= 0 and x < _CITY_W and y < _CITY_H:
		## Prefer annotated terrain (open doors → brick floor, etc.).
		if _city_map.has_method("effective_tile_at"):
			return clampi(int(_city_map.effective_tile_at(x, y)), 0, TILE_ID_MAX)
		return clampi(int(_city_map.tile_at(x, y)), 0, TILE_ID_MAX)
	return _city_outside_at(x, y)


func _city_outside_at(x: int, y: int) -> int:
	## City-local coords outside [0..32); read baked ring (fallback grass).
	if _city_out.is_empty() or _city_out_stride < 1:
		return TILE_GRASS
	var bx := x + _city_out_pad
	var by := y + _city_out_pad
	if bx < 0 or by < 0 or bx >= _city_out_stride or by >= _city_out_stride:
		## Past the ring: keep extending the nearest zone base.
		return _city_outside_base_for(x, y)
	return int(_city_out[by * _city_out_stride + bx])


func _build_city_outside() -> void:
	## Bake a pad around the 32×32 city from the 8 world tiles beside the portal.
	## Same land / mixed-shore rules as Hole-up camp margins.
	_sample_city_neighbours()
	_city_out_pad = _CITY_OUT_PAD
	_city_out_stride = _CITY_W + _city_out_pad * 2
	_city_out = PackedByteArray()
	_city_out.resize(_city_out_stride * _city_out_stride)
	_city_out.fill(TILE_GRASS)

	## Cardinal strips first, then corner blocks (overwrites corner cells).
	_paint_city_outside_strip(true, false, false, false, _city_nb_at(3)) ## W
	_paint_city_outside_strip(false, true, false, false, _city_nb_at(4)) ## E
	_paint_city_outside_strip(false, false, true, false, _city_nb_at(1)) ## N
	_paint_city_outside_strip(false, false, false, true, _city_nb_at(6)) ## S
	_paint_city_outside_strip(true, false, true, false, _city_nb_at(0)) ## NW
	_paint_city_outside_strip(false, true, true, false, _city_nb_at(2)) ## NE
	_paint_city_outside_strip(true, false, false, true, _city_nb_at(5)) ## SW
	_paint_city_outside_strip(false, true, false, true, _city_nb_at(7)) ## SE

	## Soften seams along the city rim (grass/brush bleed + mixed shores).
	_blend_city_rim_into_outside()


func _sample_city_neighbours() -> void:
	## Eight cells around the world portal (skip the portal itself).
	_city_nb.clear()
	_city_nb.resize(8)
	var offsets: Array[Vector2i] = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
	]
	for i in 8:
		var tid := TILE_GRASS
		if world != null and world.loaded and _city_world_pos.x >= 0:
			var p := Vector2i(
				posmod(_city_world_pos.x + offsets[i].x, WorldMapData.WIDTH),
				posmod(_city_world_pos.y + offsets[i].y, WorldMapData.HEIGHT)
			)
			tid = _normalize_camp_margin_tile(int(world.tile_at(p.x, p.y)))
		_city_nb[i] = tid
	## Gate / Enter side always reads as plains (road approach), not world terrain.
	_force_entrance_side_plains()


func _city_entrance_side(start: Vector2i) -> int:
	## Which rim the spawn hugs: 0=N 1=E 2=S 3=W.
	var d_n := start.y
	var d_s := (_CITY_H - 1) - start.y
	var d_w := start.x
	var d_e := (_CITY_W - 1) - start.x
	var best := mini(mini(d_n, d_s), mini(d_w, d_e))
	if best == d_w:
		return 3
	if best == d_e:
		return 1
	if best == d_n:
		return 0
	return 2


func _force_entrance_side_plains() -> void:
	## Cardinal + both corners on the Enter edge → grass (camp land style).
	## nb indices: 0 NW, 1 N, 2 NE, 3 W, 4 E, 5 SW, 6 S, 7 SE
	if _city_nb.size() < 8:
		return
	match _city_enter_side:
		0: ## N
			_city_nb[1] = TILE_GRASS
			_city_nb[0] = TILE_GRASS
			_city_nb[2] = TILE_GRASS
		1: ## E
			_city_nb[4] = TILE_GRASS
			_city_nb[2] = TILE_GRASS
			_city_nb[7] = TILE_GRASS
		3: ## W
			_city_nb[3] = TILE_GRASS
			_city_nb[0] = TILE_GRASS
			_city_nb[5] = TILE_GRASS
		_: ## S (castles etc.)
			_city_nb[6] = TILE_GRASS
			_city_nb[5] = TILE_GRASS
			_city_nb[7] = TILE_GRASS


func _city_nb_at(i: int) -> int:
	if i < 0 or i >= _city_nb.size():
		return TILE_GRASS
	return int(_city_nb[i])


func _city_outside_base_for(cx: int, cy: int) -> int:
	var left := cx < 0
	var right := cx >= _CITY_W
	var top := cy < 0
	var bottom := cy >= _CITY_H
	if left and top:
		return _city_nb_at(0)
	if right and top:
		return _city_nb_at(2)
	if left and bottom:
		return _city_nb_at(5)
	if right and bottom:
		return _city_nb_at(7)
	if left:
		return _city_nb_at(3)
	if right:
		return _city_nb_at(4)
	if top:
		return _city_nb_at(1)
	if bottom:
		return _city_nb_at(6)
	return TILE_GRASS


func _paint_city_outside_strip(
	left: bool, right: bool, top: bool, bottom: bool, fill_tid: int
) -> void:
	## Fill one outside zone (cardinal strip or corner) with camp-style terrain.
	var cells: Array[Vector2i] = []
	for by in _city_out_stride:
		for bx in _city_out_stride:
			var cx := bx - _city_out_pad
			var cy := by - _city_out_pad
			if cx >= 0 and cy >= 0 and cx < _CITY_W and cy < _CITY_H:
				continue
			var is_l := cx < 0
			var is_r := cx >= _CITY_W
			var is_t := cy < 0
			var is_b := cy >= _CITY_H
			## Exact zone match: corners need both flags; cardinals need only one axis.
			var want_corner := (left and top) or (right and top) or (left and bottom) or (right and bottom)
			var in_zone := false
			if want_corner:
				in_zone = (is_l == left) and (is_r == right) and (is_t == top) and (is_b == bottom)
			else:
				## Cardinal: on that side, not in a corner.
				if left and is_l and not is_t and not is_b:
					in_zone = true
				elif right and is_r and not is_t and not is_b:
					in_zone = true
				elif top and is_t and not is_l and not is_r:
					in_zone = true
				elif bottom and is_b and not is_l and not is_r:
					in_zone = true
			if in_zone:
				cells.append(Vector2i(bx, by))

	if cells.is_empty():
		return

	if _camp_margin_uses_mix(fill_tid):
		_paint_city_mixed_cells(cells, fill_tid, left, right, top, bottom)
	else:
		_paint_city_land_cells(cells, fill_tid)


func _paint_city_land_cells(cells: Array[Vector2i], base: int) -> void:
	## Grass / brush: ~85% neighbour terrain, sprinkle plains / brush (camp land).
	for c in cells:
		var tid := base
		if randf() > 0.85:
			tid = TILE_GRASS if randf() < 0.55 else TILE_BRUSH
		_city_out[c.y * _city_out_stride + c.x] = tid


func _paint_city_mixed_cells(
	cells: Array[Vector2i],
	fill_tid: int,
	left: bool,
	right: bool,
	top: bool,
	bottom: bool
) -> void:
	## Dominant fill + soft fingers growing from the city rim (camp mixed shore).
	for c in cells:
		_city_out[c.y * _city_out_stride + c.x] = fill_tid

	## Soft clearings near the city edge — depth like camp side margins.
	for c in cells:
		var cx := c.x - _city_out_pad
		var cy := c.y - _city_out_pad
		var dist := _city_outside_rim_dist(cx, cy, left, right, top, bottom)
		if dist < 0:
			continue
		var shore := 0
		if randf() < 0.48:
			shore = 1
		if randf() < 0.28:
			shore = maxi(shore, 2)
		if randf() < 0.10:
			shore = maxi(shore, 3)
		if randf() < 0.34:
			shore = 0
		if dist < shore and randf() >= 0.28:
			_city_out[c.y * _city_out_stride + c.x] = _camp_soft_tid(fill_tid)

	## Mild bleed between soft neighbours.
	for c in cells:
		var i := c.y * _city_out_stride + c.x
		if not _camp_is_fill_tid(int(_city_out[i]), fill_tid):
			continue
		if not _city_out_has_soft_neighbor(c.x, c.y, fill_tid, cells):
			continue
		var cx := c.x - _city_out_pad
		var cy := c.y - _city_out_pad
		var dist := _city_outside_rim_dist(cx, cy, left, right, top, bottom)
		var p_grow := 0.16 * (1.0 / (1.0 + float(maxi(dist, 0))))
		if randf() < p_grow:
			_city_out[i] = _camp_soft_tid(fill_tid)

	_prune_floating_city_soft(cells, fill_tid, left, right, top, bottom)


func _city_outside_rim_dist(
	cx: int, cy: int, left: bool, right: bool, top: bool, bottom: bool
) -> int:
	## 0 = adjacent to the city block; larger = farther out.
	if left and right == false and top == false and bottom == false:
		return -1 - cx
	if right and left == false and top == false and bottom == false:
		return cx - _CITY_W
	if top and left == false and right == false and bottom == false:
		return -1 - cy
	if bottom and left == false and right == false and top == false:
		return cy - _CITY_H
	## Corner: chebyshev distance past the corner of the city.
	var dx := 0
	var dy := 0
	if left:
		dx = -1 - cx
	elif right:
		dx = cx - _CITY_W
	if top:
		dy = -1 - cy
	elif bottom:
		dy = cy - _CITY_H
	return maxi(dx, dy)


func _city_out_has_soft_neighbor(
	bx: int, by: int, fill_tid: int, cells: Array[Vector2i]
) -> bool:
	var cell_set: Dictionary = {}
	for c in cells:
		cell_set[_camp_cell_key(c.x, c.y)] = true
	var neighbors: Array[Vector2i] = [
		Vector2i(bx + 1, by), Vector2i(bx - 1, by),
		Vector2i(bx, by + 1), Vector2i(bx, by - 1),
	]
	for n in neighbors:
		if not cell_set.has(_camp_cell_key(n.x, n.y)):
			continue
		if _camp_is_soft_tid(int(_city_out[n.y * _city_out_stride + n.x]), fill_tid):
			return true
	return false


func _prune_floating_city_soft(
	cells: Array[Vector2i],
	fill_tid: int,
	left: bool,
	right: bool,
	top: bool,
	bottom: bool
) -> void:
	## Keep only soft that 4-connects to the city-adjacent rim (camp prune).
	var cell_set: Dictionary = {}
	for c in cells:
		cell_set[_camp_cell_key(c.x, c.y)] = true
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = []
	for c in cells:
		var cx := c.x - _city_out_pad
		var cy := c.y - _city_out_pad
		if _city_outside_rim_dist(cx, cy, left, right, top, bottom) != 0:
			continue
		if _camp_is_soft_tid(int(_city_out[c.y * _city_out_stride + c.x]), fill_tid):
			queue.append(c)
			seen[_camp_cell_key(c.x, c.y)] = true

	var qi := 0
	while qi < queue.size():
		var cur: Vector2i = queue[qi]
		qi += 1
		var neighbors: Array[Vector2i] = [
			Vector2i(cur.x + 1, cur.y), Vector2i(cur.x - 1, cur.y),
			Vector2i(cur.x, cur.y + 1), Vector2i(cur.x, cur.y - 1),
		]
		for n in neighbors:
			var key := _camp_cell_key(n.x, n.y)
			if not cell_set.has(key) or seen.has(key):
				continue
			if _camp_is_fill_tid(int(_city_out[n.y * _city_out_stride + n.x]), fill_tid):
				continue
			seen[key] = true
			queue.append(n)

	for c in cells:
		var i := c.y * _city_out_stride + c.x
		if _camp_is_fill_tid(int(_city_out[i]), fill_tid):
			continue
		if not seen.has(_camp_cell_key(c.x, c.y)):
			_city_out[i] = fill_tid


func _blend_city_rim_into_outside() -> void:
	## City-edge grass/brush bleeds a few tiles into the outside (camp edge blend).
	if _city_map == null:
		return
	## West / east columns of the city.
	for y in _CITY_H:
		_extend_city_rim_cell(-1, y, int(_city_map.tile_at(0, y)), true)
		_extend_city_rim_cell(_CITY_W, y, int(_city_map.tile_at(_CITY_W - 1, y)), true)
	## North / south rows.
	for x in _CITY_W:
		_extend_city_rim_cell(x, -1, int(_city_map.tile_at(x, 0)), false)
		_extend_city_rim_cell(x, _CITY_H, int(_city_map.tile_at(x, _CITY_H - 1)), false)


func _extend_city_rim_cell(cx: int, cy: int, edge_tid: int, horizontal: bool) -> void:
	var tid := _normalize_camp_margin_tile(edge_tid)
	var depth := 0
	if tid == TILE_BRUSH:
		depth = 1
	elif tid == TILE_GRASS:
		depth = 2 + (1 if randf() < 0.55 else 0)
	else:
		return
	for step in depth:
		var ox := cx
		var oy := cy
		if horizontal:
			ox = cx + (step if cx >= _CITY_W else -step)
		else:
			oy = cy + (step if cy >= _CITY_H else -step)
		var bx := ox + _city_out_pad
		var by := oy + _city_out_pad
		if bx < 0 or by < 0 or bx >= _city_out_stride or by >= _city_out_stride:
			break
		var base := _city_outside_base_for(ox, oy)
		## Mixed outside: sometimes leave the fill so the seam is not a solid wall.
		if _camp_margin_uses_mix(base):
			var keep_soft := 0.55 if step == 0 else 0.32
			if randf() > keep_soft:
				continue
		var out_tid := tid
		if tid == TILE_GRASS and step > 0 and randf() < 0.30:
			out_tid = TILE_BRUSH
		elif tid == TILE_BRUSH and step > 0 and randf() < 0.20:
			out_tid = TILE_GRASS
		_city_out[by * _city_out_stride + bx] = out_tid


func _rebuild_camp() -> void:
	## 11×11 camp map centered; side columns from baked world-side backdrop.
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
				tid = clampi(_camp_map.tile_at(cx, cy), 0, TILE_ID_MAX)
			else:
				var bi := dy * view_w + dx
				if bi >= 0 and bi < _camp_bg.size():
					tid = clampi(int(_camp_bg[bi]), 0, TILE_ID_MAX)
			var dst := Vector2i(dx * TILE_SRC, dy * TILE_SRC)
			_blit_terrain_to(_buf, tid, dst)

	_paint_camp_sleepers(origin_x, origin_y)
	_paint_camp_guard(origin_x, origin_y)
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
		TILE_BRIDGE, TILE_BRIDGE_N, TILE_BRIDGE_S:
			return TILE_GRASS
		_:
			## dungeon/city/castle/town/LCB and other non-terrain → plains
			return TILE_GRASS


func _blit_terrain_to(target: Image, tid: int, dst: Vector2i) -> void:
	## Water, fields, lava, and white-corner edges share the same Y-scroll clock.
	if tid <= WATER_TILE_MAX or _is_y_scroll_tile(tid):
		_U4TileBankScript.blit_water_to(target, tid, dst, _water_scroll)
	elif tid >= TILE_WHITE_SW and tid <= TILE_WHITE_NE:
		_U4TileBankScript.blit_water_edge_to(target, tid, dst, _water_scroll)
	elif tid == TILE_SPIT or _U4TileBankScript.frame_count(tid) > 1:
		## Spit: `075_spit.png` ↔ `075_spit_1.png` (camp, city, world — same path).
		_U4TileBankScript.blit_anim_to(target, tid, dst, _tile_anim_frame)
	else:
		_U4TileBankScript.blit_to(target, tid, dst)


func _refresh_los() -> void:
	## xu4 screenFindLineOfSight — blocking from front terrain around party `center`.
	if not los_enabled:
		_los = _LineOfSightScript.all_visible(view_w, view_h)
		return
	var half_x := view_w / 2
	var half_y := view_h / 2
	var blocking := PackedByteArray()
	blocking.resize(view_w * view_h)
	for dy in view_h:
		for dx in view_w:
			var tid := _terrain_tid_at(center.x - half_x + dx, center.y - half_y + dy)
			## Balloon aloft (`los_opacity` false): nothing blocks.
			var opaque := los_opacity and _TileRulesCamp.is_opaque(tid)
			blocking[dy * view_w + dx] = 1 if opaque else 0
	_los = _LineOfSightScript.compute_dos(blocking, view_w, view_h)
	## Ultima4R: standing in forest (opaque underfoot) still shows the 8 neighbors.
	if los_opacity and _TileRulesCamp.is_opaque(_terrain_tid_at(center.x, center.y)):
		_reveal_center_moore_neighbors()


func _reveal_center_moore_neighbors() -> void:
	## Force-visible Moore neighborhood around the party (DOS alone blacks it all out).
	var half_x := view_w / 2
	var half_y := view_h / 2
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var vx := half_x + dx
			var vy := half_y + dy
			if vx < 0 or vy < 0 or vx >= view_w or vy >= view_h:
				continue
			_los[vy * view_w + vx] = 1


func _terrain_tid_at(wx: int, wy: int) -> int:
	if is_in_city():
		return clampi(_city_tile_or_outside(wx, wy), 0, TILE_ID_MAX)
	if world != null and world.loaded:
		return clampi(world.tile_at(wx, wy), 0, TILE_ID_MAX)
	return TILE_GRASS


func _apply_los_blackout_stage(base: Vector2i) -> void:
	## Replace hidden stage cells with black (xu4 draws tile_black).
	if not los_enabled:
		return
	var half_x := view_w / 2
	var half_y := view_h / 2
	for dy in view_h + 1:
		for dx in view_w + 1:
			var mx := base.x - half_x + dx
			var my := base.y - half_y + dy
			if is_tile_visible(mx, my):
				continue
			_stage.fill_rect(
				Rect2i(dx * TILE_SRC, dy * TILE_SRC, TILE_SRC, TILE_SRC),
				_LOS_BLACK
			)


func _is_y_scroll_tile(tid: int) -> bool:
	match tid:
		TILE_FIELD_POISON, TILE_FIELD_ENERGY, TILE_FIELD_FIRE, TILE_FIELD_SLEEP, TILE_LAVA:
			return true
		_:
			return false


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


func _cache_camp_guard_icons() -> void:
	_camp_guard_a = null
	_camp_guard_b = null
	if _camp_guard_class < 0 or _camp_guard_class >= CLASS_TILE_EVEN.size():
		return
	var even: int = CLASS_TILE_EVEN[_camp_guard_class]
	_camp_guard_a = _slice_keyed_tile(even)
	_camp_guard_b = _slice_keyed_tile(even + 1)
	if _camp_guard_b == null:
		_camp_guard_b = _camp_guard_a


func _paint_camp_guard(origin_x: int, origin_y: int) -> void:
	if _camp_guard_class < 0:
		return
	if _camp_guard_a == null:
		_cache_camp_guard_icons()
	var img := _camp_guard_b if _avatar_frame == 1 and _camp_guard_b != null else _camp_guard_a
	if img == null or img.is_empty():
		return
	var sx := origin_x + _camp_guard_pos.x
	var sy := origin_y + _camp_guard_pos.y
	if sx < 0 or sy < 0 or sx >= view_w or sy >= view_h:
		return
	var dst := Vector2i(sx * TILE_SRC, sy * TILE_SRC)
	_buf.blend_rect(img, Rect2i(0, 0, TILE_SRC, TILE_SRC), dst)


func _step_camp_guard() -> void:
	if _camp_map == null:
		return
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]
	## Shuffle-ish: try a few random dirs.
	for _try in 4:
		var d: Vector2i = dirs[randi() % dirs.size()]
		var next := _camp_guard_pos + d
		if not _camp_guard_can_enter(next):
			continue
		_camp_guard_pos = next
		return


func _camp_guard_can_enter(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.y < 0 or pos.x >= CAMP_W or pos.y >= CAMP_H:
		return false
	if _camp_map == null:
		return false
	var tid := int(_camp_map.tile_at(pos.x, pos.y))
	if _TileRulesCamp.walk_on(tid) == 0:
		return false
	if _TileRulesCamp.is_water(tid):
		return false
	for s in _camp_sleepers:
		if s == pos:
			return false
	return true


func _paint_moongate(cam: Vector2) -> void:
	## Sprout like the intro gate: top of the art rises; bottom of the cell stays planted.
	if _moongate_tid < 0 or not tiles_ready:
		return
	if is_in_city():
		return
	if not is_tile_visible(_moongate_pos.x, _moongate_pos.y):
		return
	var gh := clampi(_moongate_height_px, 0, TILE_SRC)
	if gh <= 0:
		return
	var half_x := view_w / 2
	var half_y := view_h / 2
	var screen := Vector2(_moongate_pos) - cam + Vector2(half_x, half_y)
	var px := int(round(screen.x * float(TILE_SRC)))
	var py := int(round(screen.y * float(TILE_SRC)))
	if px <= -TILE_SRC or py <= -TILE_SRC:
		return
	if px >= view_w * TILE_SRC or py >= view_h * TILE_SRC:
		return
	## Always paint from open-gate art + color rotation; height wipe does the rise/fall.
	var slice := _moongate_draw_slice()
	if slice == null:
		return
	## Source = top `gh` rows (gate crown leads); dest bottom-aligned in the tile.
	var src := Rect2i(0, 0, TILE_SRC, gh)
	var dst := Vector2i(px, py + TILE_SRC - gh)
	_buf.blend_rect(slice, src, dst)


func _moongate_draw_slice() -> Image:
	## Full open-gate tile with blue↔white inward rotation (cropped by height when painting).
	var frames := _ensure_moongate_suck_frames_for(TILE_MOONGATE_OPEN)
	if not frames.is_empty():
		return frames[_moongate_suck_i % frames.size()]
	return _overlay_slice(TILE_MOONGATE_OPEN)


func _ensure_moongate_suck_frames_for(tid: int) -> Array[Image]:
	if _moongate_suck_by_tid.has(tid):
		var cached: Array[Image] = _moongate_suck_by_tid[tid]
		return cached
	var base := _overlay_slice(tid)
	var frames: Array[Image] = []
	if base == null:
		_moongate_suck_by_tid[tid] = frames
		return frames
	_moongate_pick_glow_colors(base)
	for i in MOONGATE_SUCK_FRAMES:
		var phase := float(i) / float(MOONGATE_SUCK_FRAMES)
		frames.append(_build_moongate_suck_frame(base, phase))
	_moongate_suck_by_tid[tid] = frames
	return frames


func _moongate_pick_glow_colors(src: Image) -> void:
	## Average the tile's own blue rim / white core so the wash matches the art.
	var sum_b := Color(0, 0, 0, 0)
	var sum_w := Color(0, 0, 0, 0)
	var nb := 0
	var nw := 0
	var w := src.get_width()
	var h := src.get_height()
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
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
	## Nested rectangles collapse inward at equal aspect ratio.
	## Color eases blue → white → blue (no hard jump) as rings flow in.
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
			var base := src.get_pixel(x, y)
			if not _moongate_is_glow(base):
				continue
			var nx := (float(x) - cx) / half_w
			var ny := (float(y) - cy) / half_h
			var d := maxf(absf(nx), absf(ny))
			var ux := 0.0
			var uy := 0.0
			if d > 0.0001:
				ux = nx / d
				uy = ny / d
			else:
				ux = 1.0
				uy = 0.0
			var sample_d := fposmod(d + scroll, 1.0)
			var sx := cx + ux * sample_d * half_w
			var sy := cy + uy * sample_d * half_h
			var sampled := _moongate_sample_glow(src, sx, sy, base)
			## Smooth cycle along the flowing ring: blue → white → blue.
			var ring_t := fposmod(d + scroll, 1.0)
			var white_amt := 0.5 - 0.5 * cos(ring_t * TAU)
			## Ease ends a bit more so blue lingers, white blooms in the middle.
			white_amt = smoothstep(0.0, 1.0, white_amt)
			var flowed := _moongate_col_blue.lerp(_moongate_col_white, white_amt)
			## Mostly the soft wash; keep a hint of warped source for depth.
			var mixed := flowed.lerp(sampled, 0.28)
			mixed.a = base.a
			out.set_pixel(x, y, mixed)
	return out


func _moongate_sample_glow(src: Image, fx: float, fy: float, fallback: Color) -> Color:
	## Bilinear sample; if a corner isn't glow, fall back so grass doesn't leak in.
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
	var c00 := src.get_pixel(x0, y0)
	var c10 := src.get_pixel(x1, y0)
	var c01 := src.get_pixel(x0, y1)
	var c11 := src.get_pixel(x1, y1)
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
	## Keep speckled grass/stars; only scroll blue/white portal pixels.
	if c.a < 0.15:
		return false
	var lum := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	if lum > 0.72 and c.b > 0.65:
		return true ## white / pale core
	if c.b > 0.40 and c.b > c.r + 0.12 and c.b > c.g + 0.08:
		return true ## blue rim
	return false


func _paint_overlays(cam: Vector2) -> void:
	## Draw temporary horse/ship stubs in world space (scroll with terrain).
	if _overlays.is_empty() or not tiles_ready:
		return
	var half_x := view_w / 2
	var half_y := view_h / 2
	for item in _overlays:
		var wx := int(item.x)
		var wy := int(item.y)
		if not is_tile_visible(wx, wy):
			continue
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


func _paint_bridge_near_rails(cam: Vector2) -> void:
	## Redraw south/near white railing over party & NPCs (not in xu4 — enhancement).
	## Far railing on bridge_n stays under sprites; only bridge / bridge_s need this.
	if not tiles_ready:
		return
	var half_x := view_w / 2
	var half_y := view_h / 2
	var base := Vector2i(floori(cam.x), floori(cam.y))
	var rail_h := TILE_SRC - BRIDGE_NEAR_RAIL_Y
	var src := Rect2i(0, BRIDGE_NEAR_RAIL_Y, TILE_SRC, rail_h)
	for dy in view_h + 1:
		for dx in view_w + 1:
			var mx := base.x - half_x + dx
			var my := base.y - half_y + dy
			var tid: int
			if is_in_city():
				tid = clampi(_city_tile_or_outside(mx, my), 0, TILE_ID_MAX)
			elif world != null and world.loaded:
				tid = clampi(world.tile_at(mx, my), 0, TILE_ID_MAX)
			else:
				continue
			if tid != TILE_BRIDGE and tid != TILE_BRIDGE_S:
				continue
			if not is_tile_visible(mx, my):
				continue
			var screen := Vector2(mx, my) - cam + Vector2(half_x, half_y)
			var px := int(round(screen.x * float(TILE_SRC)))
			var py := int(round(screen.y * float(TILE_SRC))) + BRIDGE_NEAR_RAIL_Y
			if px <= -TILE_SRC or py <= -rail_h:
				continue
			if px >= view_w * TILE_SRC or py >= view_h * TILE_SRC:
				continue
			var slice := _overlay_slice(tid)
			if slice == null or slice.is_empty():
				continue
			_buf.blend_rect(slice, src, Vector2i(px, py))


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
