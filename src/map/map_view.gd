class_name MapView
extends TextureRect

## Renders Ultima IV explore view by blitting per-tile PNGs (U4TileBank) into an ImageTexture.
## Explore: fixed VIEW_W × VIEW_H grid; STRETCH_SCALE applies mild tall-tile aspect.

## Preload so MapView parses even if global class cache is stale.
const _CombatMapDataScript := preload("res://src/map/combat_map_data.gd")
const _U4TileBankScript := preload("res://src/map/u4_tile_bank.gd")
const _LineOfSightScript := preload("res://src/map/line_of_sight.gd")
const _WorldCreaturesScript := preload("res://src/map/world_creatures.gd")
const _WeaponIconsScript := preload("res://src/core/weapon_icons.gd")
const _ArmorIconsScript := preload("res://src/core/armor_icons.gd")
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
const TILE_CHEST := 60 ## closed chest; open art is frame 1 (`060_chest_1.png`)
const TILE_BRICK_FLOOR := 62 ## underlay for city map chest tiles
const TILE_LAVA := 76
const TILE_MISS_FLASH := 77 ## xu4 missFlash / missile (cannon ball)
const TILE_HIT_FLASH := 79 ## xu4 hitFlash / attack_flash
## Seconds per tile of cannon travel (matches prior per-tile miss flash).
const CANNON_SEC_PER_TILE := 0.10
## Magic bow / magic axe fly 1.5× faster than the default missile.
const MAGIC_MISSILE_SPEED := 1.5
## Multi-frame terrain flip period (spit, etc.).
const TILE_ANIM_PERIOD := 0.20
## Open chest cavity in `060_chest_1.png` is 18×2 (x=7..24, y=14..15);
## outer chest ~22×23. Icon sized to cavity width (16) and centered on that mouth.
const CHEST_LOOT_ICON_SIZE := 16
const CHEST_CAVITY_CENTER := Vector2i(16, 19) ## open mouth + 4px down
const GOLD_HUD_PATH := "res://assets/ui/hud/gold.png"
const FOOD_HUD_PATH := "res://assets/ui/hud/food.png"
const TORCH_HUD_PATH := "res://assets/ui/hud/torch.png"
const KEY_HUD_PATH := "res://assets/ui/hud/key.png"
const GEM_HUD_PATH := "res://assets/ui/hud/gem.png"
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
## Cannonball: black_pearl ~12×12, centered on transparent 32×32.
const CANNONBALL_PATH := "res://assets/tiles/cannonball.png"
## Sling stone — source art scaled to 1/4 (8×8 from 32×32).
const SLING_MISSILE_PATH := "res://assets/ui/weapons/sling_missile.png"
## Thrown dagger — inventory icon flies, rotated to flight direction.
const DAGGER_MISSILE_PATH := "res://assets/ui/weapons/dagger.png"
## Source art points tip toward top-right (image +x, −y) ≈ −45°.
const DAGGER_BASE_ANGLE := -PI * 0.25
## Drawn size for the flying dagger (24→12 = half).
const DAGGER_MISSILE_DRAW := 12
## Thrown magic axe — inventory icon, spins out then returns.
const MAGIC_AXE_MISSILE_PATH := "res://assets/ui/weapons/magic_axe.png"
const MAGIC_AXE_MISSILE_DRAW := 12
## Spin while flying (radians per tile of travel).
const MAGIC_AXE_SPIN_PER_TILE := TAU * 1.25
## Bow / crossbow arrow (pixel stick; tip up; bow-string browns).
const ARROW_MISSILE_PATH := "res://assets/ui/weapons/arrow_missile.png"
## Magic bow arrow — same shape, blue from magic_bow / magic_sword.
const MAGIC_ARROW_MISSILE_PATH := "res://assets/ui/weapons/magic_arrow_missile.png"
## Source art points tip up (image −y).
const ARROW_BASE_ANGLE := -PI * 0.5
const MISSILE_ANGLE_BUCKETS := 32
## Magic arrow afterimage: ghost copies behind the head.
const MAGIC_ARROW_TRAIL_LEN := 4
const MAGIC_ARROW_TRAIL_SPACE := 0.14 ## min tile spacing between samples
## Per-sample alpha (oldest → newest); head is always 1.
const MAGIC_ARROW_TRAIL_ALPHA := [0.18, 0.28, 0.40, 0.55]
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
## Wilderness monsters: { x, y, tid, hp, max_hp }. Drawn with tile animation + HP bar.
var _creatures: Array = []
## Brief world-tile FX: { x, y, tid, left }.
var _tile_flashes: Array[Dictionary] = []
## Flying cannonball in unwrapped tile-space (center): { x, y } or empty.
var _cannon_proj: Dictionary = {}
var _cannonball_img: Image
var _sling_missile_img: Image
## Keyed + scaled dagger; rotated per throw into _combat_proj["img"].
var _dagger_missile_img: Image
## Keyed + scaled magic axe (spin base; frames via _magic_axe_rot_cache).
var _magic_axe_missile_img: Image
## Arrow stick for bow / crossbow / magic bow.
var _arrow_missile_img: Image
var _magic_arrow_missile_img: Image
## Rotation blit caches: angle_bucket → Image.
var _dagger_rot_cache: Dictionary = {}
var _arrow_rot_cache: Dictionary = {}
var _magic_arrow_rot_cache: Dictionary = {}
var _magic_axe_rot_cache: Dictionary = {}

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
var _gold_loot_icon: Image
var _loot_icon_cache: Dictionary = {} ## path → scaled Image
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
## Combat arena — same 11×11 centered layout as camp; units painted on top.
var _combat_map # CombatMapData
## Each: { "x", "y", "klass", "party_slot"? } — living party members.
var _combat_party: Array[Dictionary] = []
## Each: { "x", "y", "tile" } — foes on the arena.
var _combat_foes: Array[Dictionary] = []
## Living foe count at combat start (for 1/N chest drop).
var _combat_foe_spawn_count := 0
## Combat loot chests: key "x,y" → { open, stack, ... }.
var _combat_chests: Dictionary = {}
## Index into `_combat_party` for xu4 TileView::drawFocus (blinking white box).
var _combat_focus := -1
## Index into `_combat_foes` while that creature acts (−1 = party phase).
var _combat_foe_focus := -1
var _combat_focus_on := true
var _combat_focus_cd := 0.0
const COMBAT_FOCUS_BLINK_SEC := 0.25
const COMBAT_FOCUS_EDGE := 2
## try_move_combat_focus results (xu4 MoveResult subset).
const COMBAT_MOVE_OK := 0
const COMBAT_MOVE_BLOCKED := 1
const COMBAT_MOVE_SLOWED := 2
const COMBAT_MOVE_FLED := 3
const _DIRS_COMBAT: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
]
## Last unit removed by fleeing off the .CON edge (for karma).
var _combat_last_fled: Dictionary = {}
## U5-style attack aim cursor (combat-local tile), or (−1,−1) when off.
var _combat_aim_pos := Vector2i(-1, -1)
var _combat_aim_cursor: Image
const COMBAT_AIM_CURSOR_PATH := "res://assets/ui/combat/target_cursor.png"
## Combat-local tile flashes: { x, y, tid, left } in .CON coords.
var _combat_tile_flashes: Array[Dictionary] = []
## Ranged weapon missile in combat-local float tile space (tile centers).
var _combat_proj: Dictionary = {}
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
	_cannonball_img = _load_image_path(CANNONBALL_PATH)
	_sling_missile_img = _load_image_path(SLING_MISSILE_PATH)
	_dagger_missile_img = _prepare_dagger_missile(_load_image_path(DAGGER_MISSILE_PATH))
	_magic_axe_missile_img = _prepare_sized_missile(
		_load_image_path(MAGIC_AXE_MISSILE_PATH), MAGIC_AXE_MISSILE_DRAW
	)
	_arrow_missile_img = _load_image_path(ARROW_MISSILE_PATH)
	_magic_arrow_missile_img = _load_image_path(MAGIC_ARROW_MISSILE_PATH)
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
	exit_combat()
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


func is_in_combat() -> bool:
	return _combat_map != null


func combat_tile_at(pos: Vector2i) -> int:
	## Terrain id on the active .CON map, or -1 if not in combat / OOB.
	if _combat_map == null:
		return -1
	if pos.x < 0 or pos.y < 0 or pos.x >= CAMP_W or pos.y >= CAMP_H:
		return -1
	return int(_combat_map.tile_at(pos.x, pos.y))


func open_combat_door(pos: Vector2i) -> bool:
	## Replace a door tile with brick floor for the rest of combat.
	if _combat_map == null:
		return false
	if not _TileRulesCamp.is_door(int(_combat_map.tile_at(pos.x, pos.y))):
		return false
	_combat_map.set_tile(pos.x, pos.y, 62) ## brick floor
	_rebuild()
	return true


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
	exit_combat()
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
	exit_combat()
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


func enter_combat(map, party_units: Array, foe_units: Array) -> void:
	## Show a .CON arena centered in the explore view (xu4 CombatMap).
	## `party_units` / `foe_units`: {x,y,klass?} / {x,y,tile}.
	## Keep the city map under combat so exit returns with alerted guards etc.
	exit_camp()
	_combat_map = map
	_combat_party.clear()
	for u in party_units:
		if typeof(u) == TYPE_DICTIONARY:
			_combat_party.append((u as Dictionary).duplicate(true))
	_combat_foes.clear()
	_combat_chests.clear()
	for u in foe_units:
		if typeof(u) == TYPE_DICTIONARY:
			_combat_foes.append((u as Dictionary).duplicate(true))
	_combat_foe_spawn_count = _combat_foes.size()
	## xu4 beginCombat — focus first placeable party member.
	_combat_focus = 0 if not _combat_party.is_empty() else -1
	_combat_foe_focus = -1
	_combat_last_fled = {}
	_combat_aim_pos = Vector2i(-1, -1)
	_combat_tile_flashes.clear()
	_combat_proj.clear()
	_ensure_combat_aim_cursor()
	_combat_focus_on = true
	_combat_focus_cd = COMBAT_FOCUS_BLINK_SEC
	_build_camp_background()
	_scroll_frames_left = 0
	_rebuild()


func exit_combat() -> void:
	if _combat_map == null and _combat_party.is_empty() and _combat_foes.is_empty():
		return
	_combat_map = null
	_combat_party.clear()
	_combat_foes.clear()
	_combat_chests.clear()
	_combat_foe_spawn_count = 0
	_combat_focus = -1
	_combat_foe_focus = -1
	_combat_last_fled = {}
	_combat_aim_pos = Vector2i(-1, -1)
	_combat_tile_flashes.clear()
	_combat_proj.clear()
	_rebuild()


func set_combat_focus(index: int) -> void:
	## Active party combatant index in `_combat_party` (−1 clears).
	var next := index
	if next >= _combat_party.size():
		next = -1
	var had_foe := _combat_foe_focus >= 0
	_combat_foe_focus = -1
	if next == _combat_focus and not had_foe:
		return
	_combat_focus = next
	_combat_focus_on = true
	_combat_focus_cd = COMBAT_FOCUS_BLINK_SEC
	if _combat_map != null:
		_rebuild()


func refresh_combat_view() -> void:
	## Re-blit after status change (wake corpse → class tile).
	if _combat_map != null:
		_rebuild()


func set_combat_foe_focus(index: int) -> void:
	## Active foe while creatures act one-by-one (xu4 moveCreatures loop).
	var next := index
	if next < 0 or next >= _combat_foes.size():
		next = -1
	elif int(_combat_foes[next].get("hp", 1)) <= 0:
		next = -1
	_combat_focus = -1
	_combat_foe_focus = next
	_combat_focus_on = true
	_combat_focus_cd = COMBAT_FOCUS_BLINK_SEC
	if _combat_map != null:
		_rebuild()


func clear_combat_foe_focus() -> void:
	if _combat_foe_focus < 0:
		return
	_combat_foe_focus = -1
	if _combat_map != null:
		_rebuild()


func get_combat_focus() -> int:
	return _combat_focus


func get_combat_foe_focus() -> int:
	return _combat_foe_focus


func get_combat_focus_party_slot() -> int:
	## Party-order slot for the focused combat unit, or −1.
	if _combat_focus < 0 or _combat_focus >= _combat_party.size():
		return -1
	return int(_combat_party[_combat_focus].get("party_slot", -1))


func living_combat_foe_indices() -> Array[int]:
	## Foe turn order = creatureTable / placement order (xu4 getCreatures index).
	var out: Array[int] = []
	for i in _combat_foes.size():
		if int(_combat_foes[i].get("hp", 1)) > 0:
			out.append(i)
	return out


func combat_party_count() -> int:
	return _combat_party.size()


func is_combat_lost() -> bool:
	## xu4 CombatController::isLost — no party members left on the arena.
	return _combat_map != null and _combat_party.is_empty()


func get_combat_last_fled() -> Dictionary:
	return _combat_last_fled.duplicate(true)


func get_combat_foes() -> Array:
	## Living combat foes for the left-panel roster (caller sorts by priority).
	var out: Array = []
	for u in _combat_foes:
		if typeof(u) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = u
		if int(d.get("hp", 1)) <= 0:
			continue
		out.append(d.duplicate(true))
	return out


func get_combat_focus_pos() -> Vector2i:
	if _combat_focus < 0 or _combat_focus >= _combat_party.size():
		return Vector2i(-1, -1)
	var u: Dictionary = _combat_party[_combat_focus]
	return Vector2i(int(u.get("x", 0)), int(u.get("y", 0)))


func get_combat_focus_klass() -> int:
	if _combat_focus < 0 or _combat_focus >= _combat_party.size():
		return -1
	return int(_combat_party[_combat_focus].get("klass", -1))


func is_combat_won() -> bool:
	## xu4 CombatController::isWon — no living foes remain.
	if _combat_map == null:
		return false
	for u in _combat_foes:
		if int(u.get("hp", 1)) > 0:
			return false
	return true


func destroy_combat_foes_except_lord_british() -> int:
	## xu4 gameDestroyAllCreatures (CTX_COMBAT) — skull wipe; keep LB.
	var n := 0
	for i in _combat_foes.size():
		var f: Dictionary = _combat_foes[i]
		if int(f.get("hp", 0)) <= 0:
			continue
		if _WorldCreaturesScript.is_lord_british(int(f.get("tile", 0))):
			continue
		f["hp"] = 0
		_combat_foes[i] = f
		n += 1
	if n > 0 and _combat_map != null:
		_rebuild()
	return n


func set_combat_aim_cursor(pos: Vector2i) -> void:
	## Show U5 L-bracket aim cursor at combat-local tile (−1,−1 clears).
	if pos == _combat_aim_pos:
		return
	_combat_aim_pos = pos
	## Same blink cadence as unit focus — restart visible on place/move.
	if pos.x >= 0:
		_combat_focus_on = true
		_combat_focus_cd = COMBAT_FOCUS_BLINK_SEC
	if _combat_map != null:
		_rebuild()


func clear_combat_aim_cursor() -> void:
	set_combat_aim_cursor(Vector2i(-1, -1))


func get_combat_aim_cursor() -> Vector2i:
	return _combat_aim_pos


func combat_can_strike(weapon_id: int, from: Vector2i, to: Vector2i) -> bool:
	## In-range cells are always aimable (incl. walls / future secret tiles).
	## Obstacles only stop the traveling projectile — they do not shade or forbid aim.
	return _WeaponIconsScript.aim_strike_allows(weapon_id, from, to)


func combat_shot_reaches(from: Vector2i, to: Vector2i, weapon_id: int = -1) -> bool:
	## True if the shot lands on `to`.
	## Halberd (attackthroughobjects): ignore intermediate walls.
	## Secret doors are attackable; normal obstacles stop one tile short.
	if _combat_map == null or from == to:
		return true
	if _WeaponIconsScript.attacks_through_objects(weapon_id):
		return true
	var cells: Array[Vector2i] = _TileRulesCamp.cells_on_line(from, to)
	for i in range(1, cells.size()):
		var c: Vector2i = cells[i]
		var tid := int(_combat_map.tile_at(c.x, c.y))
		if not _TileRulesCamp.blocks_weapon_shot(tid):
			continue
		if c == to and _TileRulesCamp.is_secret_door(tid):
			return true
		## Normal obstacle (or anything past a blocker) — does not reach `to`.
		return false
	return true


func combat_projectile_end(from: Vector2i, to: Vector2i, weapon_id: int = -1) -> Vector2i:
	## Secret door: land on that tile. Other blockers: stop on the tile before them.
	## Halberd flies through solids to the aimed cell.
	if _combat_map == null or from == to:
		return to
	if _WeaponIconsScript.attacks_through_objects(weapon_id):
		return to
	var cells: Array[Vector2i] = _TileRulesCamp.cells_on_line(from, to)
	for i in range(1, cells.size()):
		var c: Vector2i = cells[i]
		var tid := int(_combat_map.tile_at(c.x, c.y))
		if not _TileRulesCamp.blocks_weapon_shot(tid):
			continue
		if _TileRulesCamp.is_secret_door(tid):
			return c
		## Normal obstacle — stop on the previous cell (in front of the wall).
		return cells[i - 1]
	return to


func combat_leave_field(pos: Vector2i, field_tid: int = TILE_FIELD_FIRE) -> bool:
	## xu4 weapon leaveTile (e.g. flaming oil → fire_field) when ground is walkable.
	if _combat_map == null or not _combat_in_bounds(pos):
		return false
	var ground := int(_combat_map.tile_at(pos.x, pos.y))
	if not _TileRulesCamp.is_creature_walkable(ground):
		return false
	_combat_map.set_tile(pos.x, pos.y, field_tid)
	_rebuild()
	return true


func combat_foe_index_at(pos: Vector2i) -> int:
	for i in _combat_foes.size():
		var f: Dictionary = _combat_foes[i]
		if int(f.get("hp", 1)) <= 0:
			continue
		if int(f.get("x", -99)) == pos.x and int(f.get("y", -99)) == pos.y:
			return i
	return -1


func combat_party_index_at(pos: Vector2i) -> int:
	## Living party unit at combat tile (includes the focused attacker).
	for i in _combat_party.size():
		var u: Dictionary = _combat_party[i]
		if int(u.get("x", -99)) == pos.x and int(u.get("y", -99)) == pos.y:
			return i
	return -1


func get_combat_party_unit(index: int) -> Dictionary:
	if index < 0 or index >= _combat_party.size():
		return {}
	return (_combat_party[index] as Dictionary).duplicate(true)


func remove_combat_party_at(index: int) -> Dictionary:
	## Remove a fallen / fled party unit. Returns the removed dict.
	if index < 0 or index >= _combat_party.size():
		return {}
	var removed: Dictionary = _combat_party[index]
	_combat_party.remove_at(index)
	if _combat_focus == index:
		_combat_focus = mini(index, _combat_party.size() - 1)
	elif _combat_focus > index:
		_combat_focus -= 1
	if _combat_map != null:
		_rebuild()
	return removed.duplicate(true)


func combat_foe_index_by_slot(slot: int) -> int:
	## Living foe with creatureTable `slot`, or −1.
	if slot < 0:
		return -1
	for i in _combat_foes.size():
		var f: Dictionary = _combat_foes[i]
		if int(f.get("slot", -1)) != slot:
			continue
		if int(f.get("hp", 1)) <= 0:
			return -1
		return i
	return -1


func get_combat_foe_at(index: int) -> Dictionary:
	if index < 0 or index >= _combat_foes.size():
		return {}
	return (_combat_foes[index] as Dictionary).duplicate(true)


func damage_combat_foe(index: int, damage: int) -> Dictionary:
	## Apply damage. Returns { hit, killed, hp, max_hp, tile, xp, dealt, chest }.
	var out := {
		"hit": false,
		"killed": false,
		"hp": 0,
		"max_hp": 0,
		"tile": 0,
		"xp": 0,
		"dealt": 0,
		"chest": false,
	}
	if index < 0 or index >= _combat_foes.size():
		return out
	var f: Dictionary = _combat_foes[index]
	var hp := int(f.get("hp", 0))
	if hp <= 0:
		return out
	var before := hp
	hp = maxi(0, hp - maxi(0, damage))
	f["hp"] = hp
	## Same as wilderness cannon hits — bar under feet until death.
	f["show_hp"] = true
	_combat_foes[index] = f
	out["hit"] = true
	out["dealt"] = before - hp
	out["hp"] = hp
	out["max_hp"] = int(f.get("max_hp", hp))
	out["tile"] = int(f.get("tile", 0))
	## xu4 creature exp ≈ basehp / 16 (config.b exp column roughly).
	out["xp"] = maxi(1, int(f.get("max_hp", 64)) / 16)
	if hp <= 0:
		out["killed"] = true
		## xu4 awardLoot was 100% once per fight; split as 1/N per kill on death tile.
		var at := Vector2i(int(f.get("x", 0)), int(f.get("y", 0)))
		out["chest"] = try_spawn_combat_chest(at, int(f.get("tile", 0)))
	if _combat_map != null:
		_rebuild()
	return out


func try_spawn_combat_chest(pos: Vector2i, foe_tile: int) -> bool:
	## leavesChest types only; p = 1 / spawn count. Overlays (does not alter ground).
	if not _combat_in_bounds(pos):
		return false
	if not _WorldCreaturesScript.leaves_chest(foe_tile):
		return false
	if _combat_map != null:
		var ground := int(_combat_map.tile_at(pos.x, pos.y))
		## xu4 awardLoot: need creature-walkable ground under the body.
		if not _TileRulesCamp.is_creature_walkable(ground):
			return false
	var n := maxi(1, _combat_foe_spawn_count)
	if (randi() % n) != 0:
		return false
	var key := _combat_chest_key(pos.x, pos.y)
	if _combat_chests.has(key):
		return false
	var humanoid := _WorldCreaturesScript.is_humanoid(foe_tile)
	var spider := _WorldCreaturesScript.is_spider(foe_tile)
	var mage := _WorldCreaturesScript.is_mage(foe_tile)
	var key_source := _WorldCreaturesScript.drops_chest_keys(foe_tile)
	var stack: Array = GameState.roll_combat_chest_loot(humanoid, spider, mage, key_source)
	_combat_chests[key] = {
		"x": pos.x,
		"y": pos.y,
		"open": false,
		"stack": stack,
		"from_spider": spider,
		"from_mage": mage,
	}
	return true


static func _combat_chest_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


func has_combat_chest_at(pos: Vector2i) -> bool:
	return _combat_chests.has(_combat_chest_key(pos.x, pos.y))


func combat_chest_is_open(pos: Vector2i) -> bool:
	var d: Variant = _combat_chests.get(_combat_chest_key(pos.x, pos.y), null)
	if typeof(d) != TYPE_DICTIONARY:
		return false
	return bool((d as Dictionary).get("open", false))


func combat_chest_stack_size(pos: Vector2i) -> int:
	var d: Variant = _combat_chests.get(_combat_chest_key(pos.x, pos.y), null)
	if typeof(d) != TYPE_DICTIONARY:
		return 0
	var stack: Variant = (d as Dictionary).get("stack", [])
	if typeof(stack) != TYPE_ARRAY:
		return 0
	return (stack as Array).size()


func combat_chest_has_loot(pos: Vector2i) -> bool:
	var d: Variant = _combat_chests.get(_combat_chest_key(pos.x, pos.y), null)
	if typeof(d) != TYPE_DICTIONARY:
		return false
	var chest: Dictionary = d
	if not bool(chest.get("open", false)):
		return false
	return combat_chest_stack_size(pos) > 0


func combat_chest_is_empty(pos: Vector2i) -> bool:
	## Opened and fully looted.
	var d: Variant = _combat_chests.get(_combat_chest_key(pos.x, pos.y), null)
	if typeof(d) != TYPE_DICTIONARY:
		return false
	var chest: Dictionary = d
	return bool(chest.get("open", false)) and combat_chest_stack_size(pos) <= 0


func open_combat_chest_at(pos: Vector2i) -> bool:
	## Open lid; stack remains for Get. Returns false if missing/already open.
	var key := _combat_chest_key(pos.x, pos.y)
	if not _combat_chests.has(key):
		return false
	var chest: Dictionary = _combat_chests[key]
	if bool(chest.get("open", false)):
		return false
	chest["open"] = true
	_combat_chests[key] = chest
	if _combat_map != null:
		_rebuild()
	return true


func take_combat_chest_loot(pos: Vector2i) -> Dictionary:
	## Pop top stack entry (index 0). Empty dict if nothing left.
	var key := _combat_chest_key(pos.x, pos.y)
	if not _combat_chests.has(key):
		return {}
	var chest: Dictionary = _combat_chests[key]
	if not bool(chest.get("open", false)):
		return {}
	var stack: Array = []
	var raw: Variant = chest.get("stack", [])
	if typeof(raw) == TYPE_ARRAY:
		stack = (raw as Array).duplicate(true)
	if stack.is_empty():
		return {}
	var entry: Variant = stack.pop_front()
	chest["stack"] = stack
	_combat_chests[key] = chest
	if _combat_map != null:
		_rebuild()
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	return (entry as Dictionary).duplicate(true)


func flash_combat_tile(pos: Vector2i, tile_id: int, duration: float = 0.12) -> void:
	_combat_tile_flashes.append({
		"x": pos.x,
		"y": pos.y,
		"tid": tile_id,
		"left": maxf(duration, 0.04),
	})
	if _combat_map != null:
		_rebuild()


func await_flash_combat_tile(pos: Vector2i, tile_id: int, duration: float = 0.12) -> void:
	var dur := maxf(duration, 0.04)
	flash_combat_tile(pos, tile_id, dur)
	var tree := get_tree()
	if tree != null:
		await tree.create_timer(dur).timeout


func await_combat_projectile(from: Vector2i, to: Vector2i, weapon_id: int = -1) -> void:
	## Cannon-style flight in combat-local coords (straight line, any angle).
	## Stops on the first wall/mast unless weapon attacks through objects (Halberd).
	## `weapon_id` selects a custom missile sprite (sling / dagger / arrow / magic axe).
	## Magic axe: outbound only — caller resolves hit VFX, then `await_combat_projectile_return`.
	if from == to:
		return
	var end := combat_projectile_end(from, to, weapon_id)
	var delta := end - from
	var steps := maxi(absi(delta.x), absi(delta.y))
	if steps <= 0:
		return
	var duration := float(steps) * CANNON_SEC_PER_TILE
	if (
		weapon_id == _WeaponIconsScript.Id.MAGIC_BOW
		or weapon_id == _WeaponIconsScript.Id.MAGIC_AXE
	):
		duration /= MAGIC_MISSILE_SPEED
	var start := Vector2(from) + Vector2(0.5, 0.5)
	var finish := Vector2(end) + Vector2(0.5, 0.5)
	var custom_img: Image = null
	var flight := atan2(finish.y - start.y, finish.x - start.x)
	var spinning := false
	if weapon_id == _WeaponIconsScript.Id.DAGGER:
		custom_img = _oriented_missile(
			_dagger_missile_img, flight, DAGGER_BASE_ANGLE, _dagger_rot_cache
		)
	elif (
		weapon_id == _WeaponIconsScript.Id.BOW
		or weapon_id == _WeaponIconsScript.Id.CROSSBOW
	):
		custom_img = _oriented_missile(
			_arrow_missile_img, flight, ARROW_BASE_ANGLE, _arrow_rot_cache
		)
	elif weapon_id == _WeaponIconsScript.Id.MAGIC_BOW:
		custom_img = _oriented_missile(
			_magic_arrow_missile_img, flight, ARROW_BASE_ANGLE, _magic_arrow_rot_cache
		)
	elif weapon_id == _WeaponIconsScript.Id.MAGIC_AXE:
		spinning = (
			_magic_axe_missile_img != null and not _magic_axe_missile_img.is_empty()
		)
		if spinning:
			custom_img = _spin_missile_frame(_magic_axe_missile_img, 0.0, _magic_axe_rot_cache)
	var trail_on := weapon_id == _WeaponIconsScript.Id.MAGIC_BOW and custom_img != null
	var returning := weapon_id == _WeaponIconsScript.Id.MAGIC_AXE
	_combat_proj = {
		"x": start.x,
		"y": start.y,
		"wid": weapon_id,
		"img": custom_img,
		"trail": [] as Array,
		"trail_on": trail_on,
		"trail_last": start if trail_on else Vector2.ZERO,
		"spin": spinning,
		"spin_base": _magic_axe_missile_img if spinning else null,
		"spin_cache": _magic_axe_rot_cache if spinning else {},
		"spin_traveled": 0.0,
		"spin_last": start,
		"return_pending": false,
		"return_to": start,
		"return_duration": duration,
	}
	_rebuild()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.tween_method(_set_combat_proj_pos, start, finish, duration)
	await tween.finished
	if returning and not _combat_proj.is_empty():
		## Stay at impact so hit flash can play while the axe is still there.
		_combat_proj["return_pending"] = true
		_combat_proj["x"] = finish.x
		_combat_proj["y"] = finish.y
		_rebuild()
		return
	_combat_proj.clear()
	_rebuild()


func await_combat_projectile_return() -> void:
	## Second leg of a returning weapon (magic axe). No-op otherwise.
	if _combat_proj.is_empty() or not bool(_combat_proj.get("return_pending", false)):
		return
	var home: Vector2 = _combat_proj.get("return_to", Vector2.ZERO) as Vector2
	var duration := maxf(0.02, float(_combat_proj.get("return_duration", CANNON_SEC_PER_TILE)))
	var apex := Vector2(
		float(_combat_proj.get("x", home.x)),
		float(_combat_proj.get("y", home.y))
	)
	_combat_proj["return_pending"] = false
	_combat_proj["spin_last"] = apex
	var back := create_tween()
	back.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	back.tween_method(_set_combat_proj_pos, apex, home, duration)
	await back.finished
	_combat_proj.clear()
	_rebuild()


func _set_combat_proj_pos(pos: Vector2) -> void:
	if _combat_proj.is_empty():
		return
	if bool(_combat_proj.get("spin", false)):
		var prev: Vector2 = _combat_proj.get("spin_last", pos) as Vector2
		var traveled := float(_combat_proj.get("spin_traveled", 0.0)) + prev.distance_to(pos)
		_combat_proj["spin_traveled"] = traveled
		_combat_proj["spin_last"] = pos
		var base: Image = _combat_proj.get("spin_base", null) as Image
		var cache: Dictionary = _combat_proj.get("spin_cache", {}) as Dictionary
		_combat_proj["img"] = _spin_missile_frame(
			base, traveled * MAGIC_AXE_SPIN_PER_TILE, cache
		)
	if bool(_combat_proj.get("trail_on", false)):
		var last: Vector2 = _combat_proj.get("trail_last", pos) as Vector2
		if last.distance_to(pos) >= MAGIC_ARROW_TRAIL_SPACE:
			## Leave a ghost at the previous sample (behind the tip).
			var trail: Array = _combat_proj.get("trail", []) as Array
			trail.append({"x": last.x, "y": last.y})
			while trail.size() > MAGIC_ARROW_TRAIL_LEN:
				trail.pop_front()
			_combat_proj["trail"] = trail
			_combat_proj["trail_last"] = pos
	_combat_proj["x"] = pos.x
	_combat_proj["y"] = pos.y
	_rebuild()


func try_move_combat_focus(dir: Vector2i) -> int:
	## Move the focused party unit one orthogonal step (xu4 movePartyMember).
	## OOB → flee (remove unit). Occupied / unwalkable → BLOCKED. Slowed → SLOWED.
	_combat_last_fled = {}
	if _combat_map == null or _combat_focus < 0 or _combat_focus >= _combat_party.size():
		return COMBAT_MOVE_BLOCKED
	if dir == Vector2i.ZERO or (dir.x != 0 and dir.y != 0):
		return COMBAT_MOVE_BLOCKED
	var u: Dictionary = _combat_party[_combat_focus]
	var from := Vector2i(int(u.get("x", 0)), int(u.get("y", 0)))
	var dest := from + dir
	if not _combat_in_bounds(dest):
		## xu4 MAP_IS_OOB — leave combat map (flee).
		_combat_last_fled = u.duplicate(true)
		_combat_party.remove_at(_combat_focus)
		## Index now points at the next member (or past end = round over).
		if _combat_focus >= _combat_party.size():
			_combat_focus = _combat_party.size()
		_rebuild()
		return COMBAT_MOVE_FLED
	if not _combat_can_walk(from, dest, dir):
		return COMBAT_MOVE_BLOCKED
	if _combat_occupied(dest, _combat_focus, -1):
		return COMBAT_MOVE_BLOCKED
	var dest_tid := int(_combat_map.tile_at(dest.x, dest.y))
	if _TileRulesCamp.slowed_by_tile(dest_tid):
		return COMBAT_MOVE_SLOWED
	u["x"] = dest.x
	u["y"] = dest.y
	_combat_party[_combat_focus] = u
	_rebuild()
	return COMBAT_MOVE_OK


func advance_combat_focus() -> bool:
	## Next party unit. false = party round done (caller runs foe phase, then focus 0).
	if _combat_party.is_empty():
		_combat_focus = -1
		return false
	var next := _combat_focus + 1
	if next >= _combat_party.size():
		return false
	set_combat_focus(next)
	return true


func refocus_after_flee() -> bool:
	## After OOB flee removed focus unit: same index is next, or round over.
	if _combat_party.is_empty():
		_combat_focus = -1
		return false
	if _combat_focus >= _combat_party.size():
		return false
	set_combat_focus(_combat_focus)
	return true


func remove_combat_foe_at(index: int) -> Dictionary:
	## Flee / death — mark foe dead so living_* / is_combat_won ignore it.
	if index < 0 or index >= _combat_foes.size():
		return {}
	var f: Dictionary = _combat_foes[index]
	f["hp"] = 0
	_combat_foes[index] = f
	if _combat_map != null:
		_rebuild()
	return f.duplicate(true)


func act_combat_creature_at(index: int) -> Dictionary:
	## xu4 Creature::act — decide + apply movement. Melee/ranged need FX then resolve.
	## Returns { action, index, from, to, party_i, klass, tile, base_hp, effect }.
	var out := {
		"action": "none",
		"index": index,
		"from": Vector2i.ZERO,
		"to": Vector2i.ZERO,
		"party_i": -1,
		"klass": -1,
		"tile": 0,
		"base_hp": 0,
		"effect": "damage",
	}
	if _combat_map == null or _combat_party.is_empty():
		return out
	if index < 0 or index >= _combat_foes.size():
		return out
	var foe: Dictionary = _combat_foes[index]
	var hp := int(foe.get("hp", 1))
	if hp <= 0:
		return out
	var from := Vector2i(int(foe.get("x", 0)), int(foe.get("y", 0)))
	var tid := int(foe.get("tile", 0))
	var base_hp := maxi(1, int(foe.get("max_hp", _WorldCreaturesScript.base_hp_for(tid))))
	out["from"] = from
	out["tile"] = tid
	out["base_hp"] = base_hp
	## Free-aim ranged: on row/col/exact-diagonal → always shoot if LOF.
	## Off-axis free aim → 40% shoot, 60% advance (keeps melee party in play).
	if _WorldCreaturesScript.is_ranged(tid):
		var ranged := _combat_pick_ranged_target(from)
		if ranged.party_i >= 0:
			var aligned := _combat_is_axis_or_diagonal(from, ranged.pos)
			if aligned or (randi() % 100) < 40:
				out["action"] = "ranged"
				out["to"] = ranged.pos
				out["party_i"] = ranged.party_i
				out["klass"] = ranged.klass
				out["effect"] = _WorldCreaturesScript.ranged_effect(tid)
				return out
			## 60% off-axis: skip the shot and fall through to advance.
	## 1/4: cast sleep (Reaper / Balron) when not ranging.
	if _WorldCreaturesScript.casts_sleep(tid) and (randi() % 4) == 0:
		out["action"] = "cast_sleep"
		return out
	## Low HP — flee toward map edge (xu4 MSTAT_FLEEING, all species).
	if _WorldCreaturesScript.is_fleeing_hp(hp):
		var away := _nearest_combat_party(from)
		if away.x < 0:
			return out
		return _combat_apply_flee_step(index, from, away, out)
	## Default: melee at Chebyshev 1 (8-adjacent, same as party), else advance.
	var near := _nearest_combat_party_info(from, true)
	if near.party_i < 0:
		return out
	if _WeaponIconsScript.chebyshev(from, near.pos) == 1:
		out["action"] = "melee"
		out["to"] = near.pos
		out["party_i"] = near.party_i
		out["klass"] = near.klass
		return out
	if _combat_apply_advance_step(index, from, near.pos):
		out["action"] = "advance"
		out["to"] = Vector2i(int(_combat_foes[index].get("x", from.x)), int(_combat_foes[index].get("y", from.y)))
	return out


func move_combat_creature_at(index: int) -> bool:
	## Advance-only step (prefer act_combat_creature_at for full AI).
	if index < 0 or index >= _combat_foes.size() or _combat_party.is_empty():
		return false
	var foe: Dictionary = _combat_foes[index]
	if int(foe.get("hp", 1)) <= 0:
		return false
	var from := Vector2i(int(foe.get("x", 0)), int(foe.get("y", 0)))
	var near := _nearest_combat_party_info(from, true)
	if near.party_i < 0:
		return false
	return _combat_apply_advance_step(index, from, near.pos)


func _combat_pick_ranged_target(from: Vector2i) -> Dictionary:
	## Player-style free aim: any living party in range with clear LOF; prefer nearest.
	var best := {"party_i": -1, "klass": -1, "pos": Vector2i(-1, -1), "dist": 1_000_000}
	for i in _combat_party.size():
		var p: Dictionary = _combat_party[i]
		var klass := int(p.get("klass", -1))
		if klass >= 0 and GameState.is_class_dead(klass):
			continue
		var pos := Vector2i(int(p.get("x", 0)), int(p.get("y", 0)))
		if pos == from:
			continue
		var dist := _WeaponIconsScript.aim_distance(from, pos)
		if dist < 1 or dist > _WorldCreaturesScript.COMBAT_RANGED_RANGE:
			continue
		## Prefer targets the missile can actually reach (no intermediate wall).
		if not combat_shot_reaches(from, pos):
			continue
		var better := dist < int(best.dist)
		if dist == int(best.dist) and (randi() % 2) == 0:
			better = true
		if better:
			best = {"party_i": i, "klass": klass, "pos": pos, "dist": dist}
	return best


func _combat_is_axis_or_diagonal(from: Vector2i, to: Vector2i) -> bool:
	## Classic U4 LOS axes: straight N/S/E/W or exact 45° diagonal.
	var dx := absi(to.x - from.x)
	var dy := absi(to.y - from.y)
	if dx == 0 and dy == 0:
		return false
	if dx == 0 or dy == 0:
		return true
	return dx == dy


func _combat_apply_advance_step(index: int, from: Vector2i, target: Vector2i) -> bool:
	## One ortho step toward the target. Prefer BFS around walkability / other
	## units so walls and props do not hard-stop a greedy distance shrink.
	## Fallback: xu4 map_pathTo — prefer relative dirs, else any valid step.
	var valid: Array[Vector2i] = _combat_valid_advance_dirs(from, index)
	if valid.is_empty():
		return false
	var step := _combat_bfs_step_toward(from, target, index, valid)
	if step == Vector2i.ZERO:
		step = _combat_path_to(from, target, valid)
	if step == Vector2i.ZERO:
		return false
	var dest2 := from + step
	var foe: Dictionary = _combat_foes[index]
	foe["x"] = dest2.x
	foe["y"] = dest2.y
	_combat_foes[index] = foe
	_rebuild()
	return true


func _combat_valid_advance_dirs(from: Vector2i, skip_foe: int) -> Array[Vector2i]:
	## Walkable ortho steps (no map exit, no stack, skip slowed terrain).
	var out: Array[Vector2i] = []
	for d in _combat_advance_dirs(from):
		var dest := from + d
		if not _combat_in_bounds(dest):
			continue
		if not _combat_can_walk(from, dest, d):
			continue
		if _combat_occupied(dest, -1, skip_foe):
			continue
		var dest_tid := int(_combat_map.tile_at(dest.x, dest.y))
		if _TileRulesCamp.slowed_by_tile(dest_tid):
			continue
		out.append(d)
	return out


func _combat_path_to(from: Vector2i, to: Vector2i, valid: Array[Vector2i]) -> Vector2i:
	## xu4 map_pathTo: directions toward the target, else any valid.
	if valid.is_empty():
		return Vector2i.ZERO
	var dx := from.x - to.x
	var dy := from.y - to.y
	var prefer: Array[Vector2i] = []
	for d in valid:
		var toward := false
		if dx < 0 and d.x > 0:
			toward = true
		if dx > 0 and d.x < 0:
			toward = true
		if dy < 0 and d.y > 0:
			toward = true
		if dy > 0 and d.y < 0:
			toward = true
		if toward:
			prefer.append(d)
	var pool: Array[Vector2i] = prefer if not prefer.is_empty() else valid
	return pool[randi() % pool.size()]


func _combat_bfs_step_toward(
	from: Vector2i, target: Vector2i, skip_foe: int, valid: Array[Vector2i]
) -> Vector2i:
	## Shortest walk around obstacles: BFS from the party tile (goal), then
	## take a neighboring step on the geodesic. Guarantees detours when a
	## wall sits on the straight line.
	if _combat_map == null:
		return Vector2i.ZERO
	var dist := PackedInt32Array()
	dist.resize(CAMP_W * CAMP_H)
	dist.fill(9999)
	if not _combat_in_bounds(target):
		return Vector2i.ZERO
	var q: Array[Vector2i] = [target]
	dist[target.y * CAMP_W + target.x] = 0
	var qi := 0
	while qi < q.size():
		var cur: Vector2i = q[qi]
		qi += 1
		var cd: int = dist[cur.y * CAMP_W + cur.x]
		for d in _DIRS_COMBAT:
			var n: Vector2i = cur + d
			if not _combat_in_bounds(n):
				continue
			var ni := n.y * CAMP_W + n.x
			if dist[ni] <= cd + 1:
				continue
			## Undirected terrain graph (like flee BFS). Directed walk checks
			## apply on the actual step via `valid`. Allow seed + mover tile.
			if n != target and n != from:
				if _combat_occupied(n, -1, skip_foe):
					continue
				var n_tid := int(_combat_map.tile_at(n.x, n.y))
				if not _TileRulesCamp.is_creature_walkable(n_tid):
					continue
				if _TileRulesCamp.slowed_by_tile(n_tid):
					continue
			dist[ni] = cd + 1
			q.append(n)
	var from_i := from.y * CAMP_W + from.x
	if dist[from_i] >= 9999:
		return Vector2i.ZERO
	## Choose a valid ortho step that strictly decreases path distance.
	var best_d := dist[from_i]
	var candidates: Array[Vector2i] = []
	for d in valid:
		var dest := from + d
		if not _combat_in_bounds(dest):
			continue
		var dd: int = dist[dest.y * CAMP_W + dest.x]
		if dd < best_d:
			best_d = dd
			candidates = [d]
		elif dd == best_d and dd < dist[from_i]:
			candidates.append(d)
	if candidates.is_empty():
		return Vector2i.ZERO
	return candidates[randi() % candidates.size()]


func _combat_is_land_tile(tid: int) -> bool:
	## Shore land in ship/shore .CON maps (not plank deck, not water/hull).
	match tid:
		3, 4, 5, 6, 7, 8, 55: ## swamp, grass, scrub, forest, hill, mountain, rocks
			return true
		_:
			return false


func _combat_flee_cell_walkable(pos: Vector2i) -> bool:
	## Static walkability for BFS (creature-walkable terrain).
	if _combat_map == null or not _combat_in_bounds(pos):
		return false
	var tid := int(_combat_map.tile_at(pos.x, pos.y))
	return _TileRulesCamp.is_creature_walkable(tid)


func _combat_flee_cell_passable(pos: Vector2i, skip_foe: int) -> bool:
	## Walkable and not occupied (self `skip_foe` ignored).
	return _combat_flee_cell_walkable(pos) and not _combat_occupied(pos, -1, skip_foe)


func _combat_land_path_dists(skip_foe: int) -> PackedInt32Array:
	## BFS distance to nearest shore-land tile, routing around other units.
	var dist := PackedInt32Array()
	dist.resize(CAMP_W * CAMP_H)
	dist.fill(9999)
	if _combat_map == null:
		return dist
	var q: Array[Vector2i] = []
	for y in CAMP_H:
		for x in CAMP_W:
			var p := Vector2i(x, y)
			if not _combat_is_land_tile(int(_combat_map.tile_at(x, y))):
				continue
			## Land goals may be occupied — still a valid "reached land" target
			## for deck pathing; mover steps onto free land beside blockers.
			var i := y * CAMP_W + x
			dist[i] = 0
			q.append(p)
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		var cd := int(dist[c.y * CAMP_W + c.x])
		for d in _DIRS_COMBAT:
			var n := c + d
			if not _combat_flee_cell_passable(n, skip_foe):
				continue
			var ni := n.y * CAMP_W + n.x
			if int(dist[ni]) <= cd + 1:
				continue
			dist[ni] = cd + 1
			q.append(n)
	return dist


func _combat_map_has_shore_land() -> bool:
	if _combat_map == null:
		return false
	for y in CAMP_H:
		for x in CAMP_W:
			if _combat_is_land_tile(int(_combat_map.tile_at(x, y))):
				return true
	return false


func _combat_exit_path_dists(land_only: bool, skip_foe: int) -> PackedInt32Array:
	## BFS distance to a cell that can step off the arena (OOB flee).
	## Routes around party/foes; `land_only` never paths back onto the ship.
	var dist := PackedInt32Array()
	dist.resize(CAMP_W * CAMP_H)
	dist.fill(9999)
	if _combat_map == null:
		return dist
	var q: Array[Vector2i] = []
	for y in CAMP_H:
		for x in CAMP_W:
			var p := Vector2i(x, y)
			if not _combat_flee_cell_passable(p, skip_foe):
				continue
			var tid := int(_combat_map.tile_at(x, y))
			if land_only and not _combat_is_land_tile(tid):
				continue
			var at_edge := false
			for d in _DIRS_COMBAT:
				if not _combat_in_bounds(p + d):
					at_edge = true
					break
			if not at_edge:
				continue
			var i := y * CAMP_W + x
			dist[i] = 0
			q.append(p)
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		var cd := int(dist[c.y * CAMP_W + c.x])
		for d in _DIRS_COMBAT:
			var n := c + d
			if not _combat_flee_cell_passable(n, skip_foe):
				continue
			if land_only and not _combat_is_land_tile(int(_combat_map.tile_at(n.x, n.y))):
				continue
			var ni := n.y * CAMP_W + n.x
			if int(dist[ni]) <= cd + 1:
				continue
			dist[ni] = cd + 1
			q.append(n)
	return dist


func _combat_pick_flee_progress(
	index: int,
	from: Vector2i,
	goal_dist: PackedInt32Array,
	from_score: int,
	land_only: bool,
	allow_oob: bool
) -> Dictionary:
	## One step that strictly lowers `goal_dist` (or leaves via OOB when score==0).
	## Returns {dest, leaves}; dest==from if stuck.
	var best_score := from_score
	var opts: Array[Dictionary] = []
	for d in _DIRS_COMBAT:
		var dest := from + d
		var is_oob := not _combat_in_bounds(dest)
		if is_oob:
			## Rim cell (goal score 0) — step off the arena.
			if allow_oob and from_score <= 0:
				var oob_score := -1
				if oob_score < best_score:
					best_score = oob_score
					opts = [{"dest": dest, "leaves": true, "score": oob_score}]
				elif oob_score == best_score:
					opts.append({"dest": dest, "leaves": true, "score": oob_score})
			continue
		if not _combat_can_walk(from, dest, d):
			continue
		if _combat_occupied(dest, -1, index):
			continue
		var dest_tid := int(_combat_map.tile_at(dest.x, dest.y))
		if land_only and not _combat_is_land_tile(dest_tid):
			continue
		var score := int(goal_dist[dest.y * CAMP_W + dest.x])
		if score < best_score:
			best_score = score
			opts = [{"dest": dest, "leaves": false, "score": score}]
		elif score == best_score and score < from_score:
			opts.append({"dest": dest, "leaves": false, "score": score})
	if opts.is_empty():
		return {"dest": from, "leaves": false}
	return opts[randi() % opts.size()]


func _combat_apply_flee_step(
	index: int, from: Vector2i, away_from: Vector2i, out: Dictionary
) -> Dictionary:
	## Shore-ship flee (SHORSHIP etc.):
	## 1) On deck → BFS down the gangplank onto land (around blockers).
	## 2) On land → BFS to nearest map-edge exit; never re-board the ship.
	## 3) Other maps → BFS to nearest OOB edge.
	var from_tid := int(_combat_map.tile_at(from.x, from.y)) if _combat_map != null else 4
	var on_land := _combat_is_land_tile(from_tid)
	var shore := _combat_map_has_shore_land()
	var land_dist := _combat_land_path_dists(index)
	var from_land_d := (
		int(land_dist[from.y * CAMP_W + from.x]) if _combat_in_bounds(from) else 9999
	)
	## Reachable land via plank (occupation-aware). Unreachable → treat as open flee.
	var on_deck := shore and not on_land and from_land_d < 9999

	var pick: Dictionary
	if on_deck:
		pick = _combat_pick_flee_progress(
			index, from, land_dist, from_land_d, false, false
		)
	else:
		var land_only := shore and on_land
		var exit_dist := _combat_exit_path_dists(land_only, index)
		var from_exit := (
			int(exit_dist[from.y * CAMP_W + from.x]) if _combat_in_bounds(from) else 0
		)
		pick = _combat_pick_flee_progress(
			index, from, exit_dist, from_exit, land_only, true
		)
		## Rim fallback if BFS score missing but an OOB step exists.
		if bool(pick.get("leaves", false)) == false and Vector2i(pick.get("dest", from)) == from:
			for d in _DIRS_COMBAT:
				var dest := from + d
				if _combat_in_bounds(dest):
					continue
				if land_only or not shore:
					pick = {"dest": dest, "leaves": true}
					break

	var best_dest: Vector2i = pick.get("dest", from)
	var leaves := bool(pick.get("leaves", false))
	## Last resort: any free step that increases separation (or OOB).
	if best_dest == from and not leaves:
		var land_only2 := shore and on_land
		var cur_sep := _combat_manhattan(from, away_from)
		var nudge: Array[Vector2i] = []
		for d in _DIRS_COMBAT:
			var dest := from + d
			if not _combat_in_bounds(dest):
				if land_only2 or not shore or not on_deck:
					best_dest = dest
					leaves = true
					nudge.clear()
					break
				continue
			if not _combat_can_walk(from, dest, d):
				continue
			if _combat_occupied(dest, -1, index):
				continue
			if land_only2 and not _combat_is_land_tile(int(_combat_map.tile_at(dest.x, dest.y))):
				continue
			if on_deck:
				## Still try to get closer to land even if BFS was tied.
				var ld := int(land_dist[dest.y * CAMP_W + dest.x])
				if ld <= from_land_d:
					nudge.append(dest)
			elif _combat_manhattan(dest, away_from) >= cur_sep:
				nudge.append(dest)
		if not leaves and not nudge.is_empty():
			best_dest = nudge[randi() % nudge.size()]

	if best_dest == from:
		out["action"] = "flee"
		out["to"] = from
		return out
	out["to"] = best_dest
	if leaves:
		out["action"] = "fled"
		remove_combat_foe_at(index)
		return out
	var foe: Dictionary = _combat_foes[index]
	foe["x"] = best_dest.x
	foe["y"] = best_dest.y
	_combat_foes[index] = foe
	_rebuild()
	out["action"] = "flee"
	return out


func _nearest_combat_party_info(from: Vector2i, use_chebyshev: bool) -> Dictionary:
	## Nearest living party by Chebyshev (8-way melee) or Manhattan.
	var best := {
		"party_i": -1, "klass": -1, "pos": Vector2i(-1, -1), "dist": 1_000_000
	}
	for i in _combat_party.size():
		var p: Dictionary = _combat_party[i]
		var klass := int(p.get("klass", -1))
		if klass >= 0 and GameState.is_class_dead(klass):
			continue
		var pos := Vector2i(int(p.get("x", 0)), int(p.get("y", 0)))
		var d := (
			_WeaponIconsScript.chebyshev(from, pos)
			if use_chebyshev
			else _combat_manhattan(from, pos)
		)
		var better := d < int(best.dist)
		if d == int(best.dist) and (randi() % 2) == 0:
			better = true
		if better:
			best = {"party_i": i, "klass": klass, "pos": pos, "dist": d}
	return best


func _combat_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < CAMP_W and pos.y < CAMP_H


func _combat_can_walk(from: Vector2i, dest: Vector2i, dir: Vector2i) -> bool:
	## xu4 walking creature / combat party: walkon + walkoff + creatureWalkable.
	if _combat_map == null:
		return false
	var from_tid := int(_combat_map.tile_at(from.x, from.y))
	var dest_tid := int(_combat_map.tile_at(dest.x, dest.y))
	if not _TileRulesCamp.can_walk_on(dest_tid, dir):
		return false
	if not _TileRulesCamp.can_walk_off(from_tid, dir):
		return false
	if not _TileRulesCamp.is_creature_walkable(dest_tid):
		return false
	return true


func _combat_occupied(pos: Vector2i, skip_party: int, skip_foe: int) -> bool:
	for i in _combat_party.size():
		if i == skip_party:
			continue
		var p: Dictionary = _combat_party[i]
		if int(p.get("x", -1)) == pos.x and int(p.get("y", -1)) == pos.y:
			return true
	for i in _combat_foes.size():
		if i == skip_foe:
			continue
		var f: Dictionary = _combat_foes[i]
		if int(f.get("hp", 1)) <= 0:
			continue
		if int(f.get("x", -1)) == pos.x and int(f.get("y", -1)) == pos.y:
			return true
	return false


func _nearest_combat_party(from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1_000_000
	for p in _combat_party:
		var pos := Vector2i(int(p.get("x", 0)), int(p.get("y", 0)))
		var d := _combat_manhattan(from, pos)
		if d < best_d:
			best_d = d
			best = pos
	return best


func _combat_manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _combat_advance_dirs(from: Vector2i) -> Array[Vector2i]:
	## Orthogonal dirs that do not step off the .CON edge (xu4 CA_ADVANCE mask).
	var out: Array[Vector2i] = []
	if from.y > 0:
		out.append(Vector2i(0, -1))
	if from.y < CAMP_H - 1:
		out.append(Vector2i(0, 1))
	if from.x > 0:
		out.append(Vector2i(-1, 0))
	if from.x < CAMP_W - 1:
		out.append(Vector2i(1, 0))
	return out


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


func begin_chest_loot_reveal() -> void:
	## After Open: redraw open lid + full-tile gold overlay (Get handles gold/karma).
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


func set_creatures(items: Array) -> void:
	## Wilderness monsters (world map only). Empty while exploring a city.
	_creatures = items.duplicate(true)
	_rebuild()


func get_creatures() -> Array:
	return _creatures.duplicate(true)


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


func flash_world_tile(pos: Vector2i, tile_id: int, duration: float = 0.10) -> void:
	## xu4 GameController::flashTile — brief overlay blit at a world cell.
	_tile_flashes.append({
		"x": pos.x,
		"y": pos.y,
		"tid": tile_id,
		"left": maxf(duration, 0.04),
	})
	_rebuild()


func await_flash_world_tile(pos: Vector2i, tile_id: int, duration: float = 0.10) -> void:
	## flashTile + wait so the target does not move under the FX.
	var dur := maxf(duration, 0.04)
	flash_world_tile(pos, tile_id, dur)
	var tree := get_tree()
	if tree != null:
		await tree.create_timer(dur).timeout


func await_cannonball(from_tile: Vector2i, to_tile: Vector2i, dir: Vector2i) -> void:
	## Pixel-smooth flight; duration = tile distance × CANNON_SEC_PER_TILE.
	if dir == Vector2i.ZERO:
		return
	var delta := _cannon_unwrap_delta(from_tile, to_tile)
	var steps := maxi(absi(delta.x), absi(delta.y))
	if steps <= 0:
		return
	var duration := float(steps) * CANNON_SEC_PER_TILE
	var start := Vector2(from_tile) + Vector2(0.5, 0.5)
	var finish := start + Vector2(dir) * float(steps)
	_cannon_proj = {"x": start.x, "y": start.y}
	_rebuild()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.tween_method(_set_cannon_proj_pos, start, finish, duration)
	await tween.finished
	_cannon_proj.clear()
	_rebuild()


func _set_cannon_proj_pos(pos: Vector2) -> void:
	if _cannon_proj.is_empty():
		return
	_cannon_proj["x"] = pos.x
	_cannon_proj["y"] = pos.y
	_rebuild()


func _cannon_unwrap_delta(from_tile: Vector2i, to_tile: Vector2i) -> Vector2i:
	var d := to_tile - from_tile
	if is_in_city():
		return d
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

	var combat_focus_changed := false
	if _combat_map != null and (
		_combat_focus >= 0 or _combat_foe_focus >= 0 or _combat_aim_pos.x >= 0
	):
		_combat_focus_cd -= delta
		if _combat_focus_cd <= 0.0:
			_combat_focus_cd = COMBAT_FOCUS_BLINK_SEC
			_combat_focus_on = not _combat_focus_on
			combat_focus_changed = true

	var shake_changed := false
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		shake_changed = true

	var flash_changed := false
	if not _tile_flashes.is_empty():
		var kept: Array[Dictionary] = []
		for f in _tile_flashes:
			var left := float(f.get("left", 0.0)) - delta
			if left > 0.0:
				f["left"] = left
				kept.append(f)
			else:
				flash_changed = true
		if kept.size() != _tile_flashes.size():
			flash_changed = true
		_tile_flashes = kept

	if not _combat_tile_flashes.is_empty():
		var ckept: Array[Dictionary] = []
		for f in _combat_tile_flashes:
			var cleft := float(f.get("left", 0.0)) - delta
			if cleft > 0.0:
				f["left"] = cleft
				ckept.append(f)
			else:
				flash_changed = true
		if ckept.size() != _combat_tile_flashes.size():
			flash_changed = true
		_combat_tile_flashes = ckept

	if _spell_flash_left > 0.0:
		_spell_flash_left = maxf(0.0, _spell_flash_left - delta)
		queue_redraw()

	if _scroll_frames_left > 0:
		# Same frame as set_center — keep first pose on screen for one full frame.
		if _scroll_skip_process:
			_scroll_skip_process = false
			if (
				frame_changed or water_changed or tile_anim_changed or npc_changed
				or combat_focus_changed
				or shake_changed or moongate_changed or flash_changed
				or not _tile_flashes.is_empty()
				or not _cannon_proj.is_empty()
				or not _combat_proj.is_empty()
			):
				_rebuild()
			return
		_scroll_frames_left -= 1
		_rebuild()
		return

	if (
		frame_changed or water_changed or tile_anim_changed or npc_changed
		or combat_focus_changed
		or shake_changed or moongate_changed or flash_changed
		or not _tile_flashes.is_empty()
		or not _combat_tile_flashes.is_empty()
		or not _cannon_proj.is_empty()
		or not _combat_proj.is_empty()
	):
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

	if _combat_map != null:
		_rebuild_combat()
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
	_paint_creatures(cam)
	_paint_party_marker()
	_paint_bridge_near_rails(cam)
	## Cannon ball + hit FX above party (xu4 flashTile over the avatar).
	_paint_cannon_proj(cam)
	_paint_tile_flashes(cam)

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
			if tid == TILE_CHEST:
				var open: bool = (
					_city_map != null
					and _city_map.has_method("is_chest_open")
					and _city_map.is_chest_open(mx, my)
				)
				_blit_chest_tile(_stage, dst, 1 if open else 0, true)
			else:
				_blit_terrain_to(_stage, tid, dst)

	_refresh_los()
	_apply_los_blackout_stage(base)

	_buf.blit_rect(
		_stage,
		Rect2i(off.x, off.y, view_w * TILE_SRC, view_h * TILE_SRC),
		Vector2i.ZERO
	)
	## Objects under people: chest loot before townsfolk / party.
	_paint_chest_loot(cam)
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


func _paint_chest_loot(cam: Vector2) -> void:
	## Gold sized to open-chest cavity width, centered on the mouth (Get clears it).
	if _city_map == null or not tiles_ready:
		return
	if not _city_map.has_method("is_chest_open"):
		return
	var opened: Dictionary = _city_map.opened_chests
	if opened.is_empty():
		return
	var icon := _ensure_gold_loot_icon()
	if icon == null or icon.is_empty():
		return
	var half_x := view_w / 2
	var half_y := view_h / 2
	var iw := icon.get_width()
	var ih := icon.get_height()
	var ox := CHEST_CAVITY_CENTER.x - iw / 2
	var oy := CHEST_CAVITY_CENTER.y - ih / 2
	for v in opened.values():
		var d: Dictionary = v
		var n := int(d.get("icon_shown", 0))
		if n <= 0:
			continue
		var wx := int(d.get("x", -1))
		var wy := int(d.get("y", -1))
		if not is_tile_visible(wx, wy):
			continue
		var screen := Vector2(wx, wy) - cam + Vector2(half_x, half_y)
		var base_px := int(round(screen.x * float(TILE_SRC))) + ox
		var base_py := int(round(screen.y * float(TILE_SRC))) + oy
		if base_px <= -iw or base_py <= -ih:
			continue
		if base_px >= view_w * TILE_SRC or base_py >= view_h * TILE_SRC:
			continue
		## Stack with a 2px nudge so piles read as layered.
		for i in n:
			var px := base_px + i * 2
			var py := base_py - i * 2
			_buf.blend_rect(icon, Rect2i(0, 0, iw, ih), Vector2i(px, py))


func _ensure_gold_loot_icon() -> Image:
	return _scaled_loot_icon(GOLD_HUD_PATH)


func _loot_icon_for_entry(entry: Dictionary) -> Image:
	var kind := str(entry.get("kind", GameState.CHEST_LOOT_GOLD))
	match kind:
		GameState.CHEST_LOOT_FOOD:
			return _scaled_loot_icon(FOOD_HUD_PATH)
		GameState.CHEST_LOOT_TORCH:
			return _scaled_loot_icon(TORCH_HUD_PATH)
		GameState.CHEST_LOOT_KEY:
			return _scaled_loot_icon(KEY_HUD_PATH)
		GameState.CHEST_LOOT_GEM:
			return _scaled_loot_icon(GEM_HUD_PATH)
		GameState.CHEST_LOOT_SILK:
			return _scaled_loot_icon(ReagentIcons.path_for_id(ReagentIcons.Id.SPIDER_SILK))
		GameState.CHEST_LOOT_REAGENT:
			var rpath := ReagentIcons.path_for_id(int(entry.get("id", 0)))
			if not rpath.is_empty():
				return _scaled_loot_icon(rpath)
			return _scaled_loot_icon(GOLD_HUD_PATH)
		GameState.CHEST_LOOT_WEAPON:
			var wpath := _WeaponIconsScript.path_for_id(int(entry.get("id", 0)))
			if not wpath.is_empty():
				return _scaled_loot_icon(wpath)
			return _scaled_loot_icon(GOLD_HUD_PATH)
		GameState.CHEST_LOOT_ARMOR:
			var apath := _ArmorIconsScript.path_for_id(int(entry.get("id", 0)))
			if not apath.is_empty():
				return _scaled_loot_icon(apath)
			return _scaled_loot_icon(GOLD_HUD_PATH)
		_:
			return _scaled_loot_icon(GOLD_HUD_PATH)


func _scaled_loot_icon(path: String) -> Image:
	if path.is_empty():
		return null
	if _loot_icon_cache.has(path):
		var cached: Variant = _loot_icon_cache[path]
		if cached is Image and not (cached as Image).is_empty():
			return cached as Image
	if not ResourceLoader.exists(path):
		return null
	var src := Image.new()
	if src.load(path) != OK:
		return null
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	## Key near-black so the open chest shows through.
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.r < 0.04 and c.g < 0.04 and c.b < 0.04:
				src.set_pixel(x, y, Color(0, 0, 0, 0))
	src.resize(CHEST_LOOT_ICON_SIZE, CHEST_LOOT_ICON_SIZE, Image.INTERPOLATE_NEAREST)
	_loot_icon_cache[path] = src
	if path == GOLD_HUD_PATH:
		_gold_loot_icon = src
	return src


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


func _rebuild_combat() -> void:
	## 11×11 combat .CON centered (same margins as camp).
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
				tid = clampi(_combat_map.tile_at(cx, cy), 0, TILE_ID_MAX)
			else:
				var bi := dy * view_w + dx
				if bi >= 0 and bi < _camp_bg.size():
					tid = clampi(int(_camp_bg[bi]), 0, TILE_ID_MAX)
			var dst := Vector2i(dx * TILE_SRC, dy * TILE_SRC)
			_blit_terrain_to(_buf, tid, dst)

	_paint_combat_chests(origin_x, origin_y)
	_paint_combat_foes(origin_x, origin_y)
	_paint_combat_party(origin_x, origin_y)
	_paint_combat_focus(origin_x, origin_y)
	_paint_combat_tile_flashes(origin_x, origin_y)
	_paint_combat_projectile(origin_x, origin_y)
	_paint_combat_aim_cursor(origin_x, origin_y)
	_tex.set_image(_buf)
	texture = _tex
	queue_redraw()


func _paint_combat_chests(origin_x: int, origin_y: int) -> void:
	## Dropped loot chests (under units). Open frame + stacked top-of-pile icon.
	if _combat_chests.is_empty() or not tiles_ready:
		return
	for v in _combat_chests.values():
		if typeof(v) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = v
		var pos := Vector2i(int(d.get("x", -1)), int(d.get("y", -1)))
		var sx := origin_x + pos.x
		var sy := origin_y + pos.y
		if sx < 0 or sy < 0 or sx >= view_w or sy >= view_h:
			continue
		var dst := Vector2i(sx * TILE_SRC, sy * TILE_SRC)
		var is_open := bool(d.get("open", false))
		## Terrain already drawn under — blend keyed chest so grass shows through.
		_U4TileBankScript.blend_to(_buf, TILE_CHEST, dst, 1 if is_open else 0)
		if not is_open:
			continue
		var stack: Array = []
		var raw: Variant = d.get("stack", [])
		if typeof(raw) == TYPE_ARRAY:
			stack = raw as Array
		if stack.is_empty():
			continue
		var top: Dictionary = stack[0] if typeof(stack[0]) == TYPE_DICTIONARY else {}
		var icon := _loot_icon_for_entry(top)
		if icon == null or icon.is_empty():
			continue
		var iw := icon.get_width()
		var ih := icon.get_height()
		var base_ox := CHEST_CAVITY_CENTER.x - iw / 2
		var base_oy := CHEST_CAVITY_CENTER.y - ih / 2
		## Layered copies = remaining pile depth (top icon only).
		var layers := mini(stack.size(), 5)
		for i in layers:
			var li := layers - 1 - i
			_buf.blend_rect(
				icon,
				Rect2i(0, 0, iw, ih),
				Vector2i(dst.x + base_ox + li * 2, dst.y + base_oy - li * 2)
			)


func _paint_combat_party(origin_x: int, origin_y: int) -> void:
	## xu4 PartyMember::putToSleep / getTile — asleep & dead use corpse icon.
	for u in _combat_party:
		var klass := int(u.get("klass", -1))
		var pos := Vector2i(int(u.get("x", 0)), int(u.get("y", 0)))
		var sx := origin_x + pos.x
		var sy := origin_y + pos.y
		if sx < 0 or sy < 0 or sx >= view_w or sy >= view_h:
			continue
		var img: Image = null
		var show_corpse := (
			klass >= 0
			and (
				GameState.is_member_disabled(klass)
				or GameState.is_class_dead(klass)
			)
		)
		if show_corpse:
			if _corpse_slice == null:
				_corpse_slice = _slice_keyed_tile(TILE_CORPSE)
			img = _corpse_slice
		elif klass >= 0 and klass < CLASS_TILE_EVEN.size():
			var even: int = CLASS_TILE_EVEN[klass]
			var tid := even + (1 if _avatar_frame == 1 else 0)
			img = _slice_keyed_tile(tid)
			if img == null:
				img = _slice_keyed_tile(even)
		if img == null or img.is_empty():
			continue
		var dst := Vector2i(sx * TILE_SRC, sy * TILE_SRC)
		_buf.blend_rect(img, Rect2i(0, 0, TILE_SRC, TILE_SRC), dst)


func _paint_combat_foes(origin_x: int, origin_y: int) -> void:
	for u in _combat_foes:
		if int(u.get("hp", 1)) <= 0:
			continue
		var tid := int(u.get("tile", 0))
		var pos := Vector2i(int(u.get("x", 0)), int(u.get("y", 0)))
		var sx := origin_x + pos.x
		var sy := origin_y + pos.y
		if sx < 0 or sy < 0 or sx >= view_w or sy >= view_h:
			continue
		## 2-frame flip for non-pirate wilderness tiles (pirate keeps facing).
		if tid >= 132 and (_avatar_frame % 2) == 1:
			tid += 1
		var img := _slice_keyed_tile(tid)
		if img == null or img.is_empty():
			continue
		var dst := Vector2i(sx * TILE_SRC, sy * TILE_SRC)
		_buf.blend_rect(img, Rect2i(0, 0, TILE_SRC, TILE_SRC), dst)
		if bool(u.get("show_hp", false)):
			_paint_creature_hp_bar(
				dst.x, dst.y, int(u.get("hp", 0)), int(u.get("max_hp", 0))
			)


func _paint_combat_focus(origin_x: int, origin_y: int) -> void:
	## xu4 TileView::drawFocus — blinking white rectangle around the active unit.
	## Hidden while the U5 aim cursor is up so the two do not stack.
	if _combat_aim_pos.x >= 0:
		return
	if not _combat_focus_on:
		return
	var pos := Vector2i(-1, -1)
	if _combat_foe_focus >= 0 and _combat_foe_focus < _combat_foes.size():
		var f: Dictionary = _combat_foes[_combat_foe_focus]
		if int(f.get("hp", 1)) > 0:
			pos = Vector2i(int(f.get("x", 0)), int(f.get("y", 0)))
	elif _combat_focus >= 0 and _combat_focus < _combat_party.size():
		var u: Dictionary = _combat_party[_combat_focus]
		pos = Vector2i(int(u.get("x", 0)), int(u.get("y", 0)))
	if pos.x < 0:
		return
	var sx := origin_x + pos.x
	var sy := origin_y + pos.y
	if sx < 0 or sy < 0 or sx >= view_w or sy >= view_h:
		return
	var px := sx * TILE_SRC
	var py := sy * TILE_SRC
	var e := COMBAT_FOCUS_EDGE
	var white := Color(1, 1, 1, 1)
	## left / top / right / bottom
	_buf.fill_rect(Rect2i(px, py, e, TILE_SRC), white)
	_buf.fill_rect(Rect2i(px, py, TILE_SRC, e), white)
	_buf.fill_rect(Rect2i(px + TILE_SRC - e, py, e, TILE_SRC), white)
	_buf.fill_rect(Rect2i(px, py + TILE_SRC - e, TILE_SRC, e), white)


func _ensure_combat_aim_cursor() -> void:
	if _combat_aim_cursor != null and not _combat_aim_cursor.is_empty():
		return
	_combat_aim_cursor = _load_image_path(COMBAT_AIM_CURSOR_PATH)


func _paint_combat_aim_cursor(origin_x: int, origin_y: int) -> void:
	## Ultima V: four L brackets framing the aimed tile (blinks with focus cadence).
	if _combat_aim_pos.x < 0 or _combat_aim_pos.y < 0:
		return
	if not _combat_focus_on:
		return
	_ensure_combat_aim_cursor()
	var sx := origin_x + _combat_aim_pos.x
	var sy := origin_y + _combat_aim_pos.y
	if sx < 0 or sy < 0 or sx >= view_w or sy >= view_h:
		return
	var dst := Vector2i(sx * TILE_SRC, sy * TILE_SRC)
	if _combat_aim_cursor != null and not _combat_aim_cursor.is_empty():
		_buf.blend_rect(
			_combat_aim_cursor,
			Rect2i(0, 0, _combat_aim_cursor.get_width(), _combat_aim_cursor.get_height()),
			dst
		)
		return
	## Procedural fallback if the PNG failed to load.
	var px := dst.x
	var py := dst.y
	var arm := 8
	var t := 2
	var col := Color(1.0, 0.925, 0.47, 1.0)
	_buf.fill_rect(Rect2i(px + 1, py + 1, arm, t), col)
	_buf.fill_rect(Rect2i(px + 1, py + 1, t, arm), col)
	_buf.fill_rect(Rect2i(px + TILE_SRC - 1 - arm, py + 1, arm, t), col)
	_buf.fill_rect(Rect2i(px + TILE_SRC - 1 - t, py + 1, t, arm), col)
	_buf.fill_rect(Rect2i(px + 1, py + TILE_SRC - 1 - t, arm, t), col)
	_buf.fill_rect(Rect2i(px + 1, py + TILE_SRC - 1 - arm, t, arm), col)
	_buf.fill_rect(Rect2i(px + TILE_SRC - 1 - arm, py + TILE_SRC - 1 - t, arm, t), col)
	_buf.fill_rect(Rect2i(px + TILE_SRC - 1 - t, py + TILE_SRC - 1 - arm, t, arm), col)


func _paint_combat_tile_flashes(origin_x: int, origin_y: int) -> void:
	if _combat_tile_flashes.is_empty() or not tiles_ready:
		return
	for f in _combat_tile_flashes:
		var cx := int(f.get("x", 0))
		var cy := int(f.get("y", 0))
		var sx := origin_x + cx
		var sy := origin_y + cy
		if sx < 0 or sy < 0 or sx >= view_w or sy >= view_h:
			continue
		var tid := int(f.get("tid", TILE_MISS_FLASH))
		var slice := _overlay_slice(tid)
		if slice == null:
			continue
		var dst := Vector2i(sx * TILE_SRC, sy * TILE_SRC)
		_buf.blend_rect(slice, Rect2i(0, 0, TILE_SRC, TILE_SRC), dst)


func _paint_combat_projectile(origin_x: int, origin_y: int) -> void:
	## Missile flying in combat-local float space (dagger / arrow / sling / flash).
	if _combat_proj.is_empty() or not tiles_ready:
		return
	var cx := float(_combat_proj.get("x", 0.0))
	var cy := float(_combat_proj.get("y", 0.0))
	var wid := int(_combat_proj.get("wid", -1))
	var custom: Image = _combat_proj.get("img", null) as Image
	if custom != null and not custom.is_empty():
		## Magic bow: faint copies along the recent path, then the solid tip.
		if bool(_combat_proj.get("trail_on", false)):
			var trail: Array = _combat_proj.get("trail", []) as Array
			var n := trail.size()
			for i in n:
				var g: Dictionary = trail[i]
				var ai := i - (n - MAGIC_ARROW_TRAIL_ALPHA.size())
				var a := 0.15
				if ai >= 0 and ai < MAGIC_ARROW_TRAIL_ALPHA.size():
					a = float(MAGIC_ARROW_TRAIL_ALPHA[ai])
				elif n > 0:
					a = float(MAGIC_ARROW_TRAIL_ALPHA[0]) * float(i + 1) / float(n)
				_paint_projectile_image(
					custom, origin_x, origin_y, float(g.get("x", 0.0)), float(g.get("y", 0.0)), a
				)
		_paint_projectile_image(custom, origin_x, origin_y, cx, cy, 1.0)
		return
	if (
		wid == _WeaponIconsScript.Id.SLING
		and _sling_missile_img != null
		and not _sling_missile_img.is_empty()
	):
		_paint_projectile_image(_sling_missile_img, origin_x, origin_y, cx, cy, 1.0)
		return
	var slice := _overlay_slice(TILE_MISS_FLASH)
	if slice == null:
		return
	var px2 := int(round((float(origin_x) + cx - 0.5) * float(TILE_SRC)))
	var py2 := int(round((float(origin_y) + cy - 0.5) * float(TILE_SRC)))
	if px2 <= -TILE_SRC or py2 <= -TILE_SRC:
		return
	if px2 >= view_w * TILE_SRC or py2 >= view_h * TILE_SRC:
		return
	_buf.blend_rect(slice, Rect2i(0, 0, TILE_SRC, TILE_SRC), Vector2i(px2, py2))


func _paint_projectile_image(
	img: Image, origin_x: int, origin_y: int, cx: float, cy: float, alpha: float = 1.0
) -> void:
	var iw := img.get_width()
	var ih := img.get_height()
	var px := int(round((float(origin_x) + cx) * float(TILE_SRC) - float(iw) * 0.5))
	var py := int(round((float(origin_y) + cy) * float(TILE_SRC) - float(ih) * 0.5))
	if px <= -iw or py <= -ih:
		return
	if px >= view_w * TILE_SRC or py >= view_h * TILE_SRC:
		return
	if alpha >= 0.999:
		_buf.blend_rect(img, Rect2i(0, 0, iw, ih), Vector2i(px, py))
		return
	## Soft afterimage — scale source alpha and composite onto the combat buffer.
	var a_mul := clampf(alpha, 0.0, 1.0)
	var bw := _buf.get_width()
	var bh := _buf.get_height()
	for y in ih:
		var dy := py + y
		if dy < 0 or dy >= bh:
			continue
		for x in iw:
			var dx := px + x
			if dx < 0 or dx >= bw:
				continue
			var sc := img.get_pixel(x, y)
			if sc.a * a_mul < 0.02:
				continue
			var sa := sc.a * a_mul
			var bc := _buf.get_pixel(dx, dy)
			var out_a := sa + bc.a * (1.0 - sa)
			if out_a < 0.001:
				continue
			_buf.set_pixel(
				dx,
				dy,
				Color(
					(sc.r * sa + bc.r * bc.a * (1.0 - sa)) / out_a,
					(sc.g * sa + bc.g * bc.a * (1.0 - sa)) / out_a,
					(sc.b * sa + bc.b * bc.a * (1.0 - sa)) / out_a,
					out_a
				)
			)


func _prepare_dagger_missile(src: Image) -> Image:
	return _prepare_sized_missile(src, DAGGER_MISSILE_DRAW)


func _prepare_sized_missile(src: Image, draw_size: int) -> Image:
	## Key near-black inventory backdrop, nearest-scale for projectile size.
	if src == null or src.is_empty():
		return null
	var img := Image.new()
	img.copy_from(src)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.01 and c.r < 0.04 and c.g < 0.04 and c.b < 0.04:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	if img.get_width() != draw_size or img.get_height() != draw_size:
		img.resize(draw_size, draw_size, Image.INTERPOLATE_NEAREST)
	return img


func _spin_missile_frame(src: Image, angle: float, cache: Dictionary) -> Image:
	## Bucketed absolute rotation for continuous spin (magic axe).
	if src == null or src.is_empty():
		return null
	var two_pi := TAU
	var norm := fposmod(angle, two_pi)
	var bucket := int(round(norm / two_pi * float(MISSILE_ANGLE_BUCKETS))) % MISSILE_ANGLE_BUCKETS
	if cache.has(bucket):
		return cache[bucket] as Image
	var ang := float(bucket) / float(MISSILE_ANGLE_BUCKETS) * two_pi
	var rotated := _rotate_image_nearest(src, ang)
	cache[bucket] = rotated
	return rotated


func _oriented_missile(
	src: Image, flight_angle: float, base_angle: float, cache: Dictionary
) -> Image:
	## Rotate so the art tip points along flight (tile space: +x right, +y down).
	if src == null or src.is_empty():
		return null
	var turn := flight_angle - base_angle
	var two_pi := TAU
	var norm := fposmod(turn, two_pi)
	var bucket := int(round(norm / two_pi * float(MISSILE_ANGLE_BUCKETS))) % MISSILE_ANGLE_BUCKETS
	if cache.has(bucket):
		return cache[bucket] as Image
	var ang := float(bucket) / float(MISSILE_ANGLE_BUCKETS) * two_pi
	var rotated := _rotate_image_nearest(src, ang)
	cache[bucket] = rotated
	return rotated


func _rotate_image_nearest(src: Image, angle: float) -> Image:
	## Nearest-neighbor rotate about center (pixel-art safe).
	var w := src.get_width()
	var h := src.get_height()
	var cos_a := cos(angle)
	var sin_a := sin(angle)
	var nw := maxi(1, int(ceili(absf(float(w) * cos_a) + absf(float(h) * sin_a))))
	var nh := maxi(1, int(ceili(absf(float(w) * sin_a) + absf(float(h) * cos_a))))
	var out := Image.create(nw, nh, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var cx := (float(w) - 1.0) * 0.5
	var cy := (float(h) - 1.0) * 0.5
	var ncx := (float(nw) - 1.0) * 0.5
	var ncy := (float(nh) - 1.0) * 0.5
	var icos := cos(-angle)
	var isin := sin(-angle)
	for y in nh:
		for x in nw:
			var dx := float(x) - ncx
			var dy := float(y) - ncy
			var sx := int(round(dx * icos - dy * isin + cx))
			var sy := int(round(dx * isin + dy * icos + cy))
			if sx < 0 or sy < 0 or sx >= w or sy >= h:
				continue
			var c := src.get_pixel(sx, sy)
			if c.a > 0.01:
				out.set_pixel(x, y, c)
	return out


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
	elif tid == TILE_SPIT:
		## Spit: `075_spit.png` ↔ `075_spit_1.png` (camp, city, world — same path).
		_U4TileBankScript.blit_anim_to(target, tid, dst, _tile_anim_frame)
	elif tid == TILE_CHEST:
		## xu4 chest uses replacement floor under transparent margins.
		_blit_chest_tile(target, dst, 0, _city_map != null)
	elif _U4TileBankScript.frame_count(tid) > 1:
		_U4TileBankScript.blit_anim_to(target, tid, dst, _tile_anim_frame)
	else:
		_U4TileBankScript.blit_to(target, tid, dst)


func _blit_chest_tile(target: Image, dst: Vector2i, frame: int, city_floor: bool) -> void:
	## Floor underlay + alpha-blended chest (PNG margins are transparent).
	var under := TILE_BRICK_FLOOR if city_floor else TILE_GRASS
	_U4TileBankScript.blit_to(target, under, dst, 0)
	_U4TileBankScript.blend_to(target, TILE_CHEST, dst, frame)


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


func _paint_creatures(cam: Vector2) -> void:
	## Wilderness monsters — animate tiles; HP bar under feet when damaged.
	if _creatures.is_empty() or not tiles_ready:
		return
	if is_in_city():
		return
	var half_x := view_w / 2
	var half_y := view_h / 2
	for item in _creatures:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		var wx := int(d.get("x", 0))
		var wy := int(d.get("y", 0))
		if not is_tile_visible(wx, wy):
			continue
		var tid: int = _WorldCreaturesScript.resolve_paint_tile(
			int(d.get("tid", d.get("z", 0))),
			_tile_anim_frame
		)
		var screen := Vector2(wx, wy) - cam + Vector2(half_x, half_y)
		var px := int(round(screen.x * float(TILE_SRC)))
		var py := int(round(screen.y * float(TILE_SRC)))
		if px <= -TILE_SRC or py <= -TILE_SRC:
			continue
		if px >= view_w * TILE_SRC or py >= view_h * TILE_SRC:
			continue
		var slice := _overlay_slice(tid)
		if slice == null:
			continue
		_buf.blend_rect(slice, Rect2i(0, 0, TILE_SRC, TILE_SRC), Vector2i(px, py))
		if bool(d.get("show_hp", false)):
			_paint_creature_hp_bar(px, py, int(d.get("hp", 0)), int(d.get("max_hp", 0)))


func _paint_creature_hp_bar(tile_px: int, tile_py: int, hp: int, max_hp: int) -> void:
	## Red bar under the sprite — after a cannon hit, until death / combat.
	if max_hp <= 0 or hp < 0:
		return
	const BAR_W := 28
	const BAR_H := 2
	var bx := tile_px + (TILE_SRC - BAR_W) / 2
	var by := tile_py + TILE_SRC - BAR_H - 1
	if bx + BAR_W <= 0 or by + BAR_H <= 0:
		return
	if bx >= view_w * TILE_SRC or by >= view_h * TILE_SRC:
		return
	## Match PartyRoster HP bar: COL_TRACK / COL_HP_OK.
	const COL_TRACK := Color(0.22, 0.22, 0.22, 1)
	const COL_HP := Color(0.82, 0.22, 0.2, 1)
	_buf.fill_rect(Rect2i(bx, by, BAR_W, BAR_H), COL_TRACK)
	var fill_w := int(round(float(BAR_W) * float(clampi(hp, 0, max_hp)) / float(max_hp)))
	if fill_w > 0:
		_buf.fill_rect(Rect2i(bx, by, fill_w, BAR_H), COL_HP)


func _paint_tile_flashes(cam: Vector2) -> void:
	if _tile_flashes.is_empty() or not tiles_ready:
		return
	var half_x := view_w / 2
	var half_y := view_h / 2
	for f in _tile_flashes:
		var wx := int(f.get("x", 0))
		var wy := int(f.get("y", 0))
		if not is_tile_visible(wx, wy):
			continue
		var tid := int(f.get("tid", TILE_MISS_FLASH))
		var screen := Vector2(wx, wy) - cam + Vector2(half_x, half_y)
		var px := int(round(screen.x * float(TILE_SRC)))
		var py := int(round(screen.y * float(TILE_SRC)))
		if px <= -TILE_SRC or py <= -TILE_SRC:
			continue
		if px >= view_w * TILE_SRC or py >= view_h * TILE_SRC:
			continue
		var slice := _overlay_slice(tid)
		if slice == null:
			continue
		_buf.blend_rect(slice, Rect2i(0, 0, TILE_SRC, TILE_SRC), Vector2i(px, py))


func _paint_cannon_proj(cam: Vector2) -> void:
	if _cannon_proj.is_empty() or not tiles_ready:
		return
	if _cannonball_img == null or _cannonball_img.is_empty():
		return
	var wx := float(_cannon_proj.get("x", 0.0))
	var wy := float(_cannon_proj.get("y", 0.0))
	var p := _cannon_screen_top_left(Vector2(wx, wy), cam)
	var px := p.x
	var py := p.y
	if px <= -TILE_SRC or py <= -TILE_SRC:
		return
	if px >= view_w * TILE_SRC or py >= view_h * TILE_SRC:
		return
	_buf.blend_rect(
		_cannonball_img,
		Rect2i(0, 0, TILE_SRC, TILE_SRC),
		Vector2i(px, py)
	)


func _cannon_screen_top_left(world_center: Vector2, cam: Vector2) -> Vector2i:
	## Tile-center → 32×32 top-left; same half_x/half_y as creatures (int view/2).
	var d := world_center - cam
	if not is_in_city():
		var w := float(WorldMapData.WIDTH)
		var h := float(WorldMapData.HEIGHT)
		if d.x > w * 0.5:
			d.x -= w
		elif d.x < -w * 0.5:
			d.x += w
		if d.y > h * 0.5:
			d.y -= h
		elif d.y < -h * 0.5:
			d.y += h
	var half_x := view_w / 2
	var half_y := view_h / 2
	## Equivalent to creature paint at (center - 0.5): keeps ball on tile midlines.
	var tl := d - Vector2(0.5, 0.5) + Vector2(half_x, half_y)
	return Vector2i(
		int(round(tl.x * float(TILE_SRC))),
		int(round(tl.y * float(TILE_SRC)))
	)


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
