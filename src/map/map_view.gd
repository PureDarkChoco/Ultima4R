class_name MapView
extends TextureRect

## Renders Ultima IV explore view by blitting per-tile PNGs (U4TileBank) into an ImageTexture.
## Explore: fixed VIEW_W × VIEW_H grid; STRETCH_SCALE fills pane at display_aspect().
## Every mode presents the Apple II 14×16 cell geometry → 8.75:10.

## Preload so MapView parses even if global class cache is stale.
const _CombatMapDataScript := preload("res://src/map/combat_map_data.gd")
const _U4TileBankScript := preload("res://src/map/u4_tile_bank.gd")
const _LineOfSightScript := preload("res://src/map/line_of_sight.gd")
const _WorldCreaturesScript := preload("res://src/map/world_creatures.gd")
const _WeaponIconsScript := preload("res://src/core/weapon_icons.gd")
const _ArmorIconsScript := preload("res://src/core/armor_icons.gd")
const _DungeonViewScript := preload("res://src/map/dungeon_view.gd")
const _DungeonPortalsScript := preload("res://src/map/dungeon_portals.gd")
const _Apple2HgrNtscScript := preload("res://src/map/apple2_hgr_ntsc.gd")
const _Apple2ProgramDiskScript := preload("res://src/core/apple2_program_disk.gd")
const _TorchFlickerShader := preload("res://assets/shaders/torch_flicker.gdshader")
const _CloudShadowShader := preload("res://assets/shaders/cloud_shadow.gdshader")
const _Weather := preload("res://src/core/weather.gd")
const _CityIndoor := preload("res://src/map/city_indoor.gd")
## xu4 invisible cells → solid black (not dimmed fog).
const _LOS_BLACK := Color(0, 0, 0, 1)
const VIEW_H := 11
const VIEW_W := 25 ## Tuned between CRT 5:6 (~27) and square 1:1 (~23).
const VIEW_W_MIN := VIEW_W
## Default stretched aspect (Apple II 14×16). Prefer display_aspect() for live layout.
const TILE_ASPECT := 14.0 / 16.0
## Legacy atlas path kept for docs / external refs; runtime uses shapes/*.png.
const TILE_SRC := 32


static func display_aspect() -> float:
	return _U4TileBankScript.display_aspect()


static func explore_map_height_for_width(width: float) -> float:
	## Pane height so 25×11 cells display at the active tileset aspect.
	if width < 1.0:
		return 0.0
	return width * float(VIEW_H) / float(VIEW_W) / display_aspect()


static func explore_tile_size_for_pane(pane: Vector2) -> Vector2:
	## Preferred on-screen tile size for a map pane (width-driven, aspect-locked).
	if pane.x < 1.0:
		return Vector2.ZERO
	var tw := pane.x / float(VIEW_W)
	return Vector2(tw, tw / display_aspect())


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
## Combat party / foes — same stagger idea so 16 guards don't march together.
const COMBAT_FRAME_MIN := 0.22
const COMBAT_FRAME_MAX := 0.85
## Classic U4 water (deep / medium / shallow) — vertical pixel scroll wrap.
const WATER_TILE_MAX := 2 # ids 0..2
## Shore masks: land freckles stamped where a water cell touches non-water.
const SHORE_MASK_DIR := "res://assets/tiles/u4graphics/masks"
## Cardinal land-neighbour bits (N E S W).
const SHORE_BIT_N := 1
const SHORE_BIT_E := 2
const SHORE_BIT_S := 4
const SHORE_BIT_W := 8
## Max pixel depth from a tile edge when filtering directed shore masks.
const SHORE_EDGE_DEPTH := 5
## Outer corners may extend slightly past the edge for a rounder turn.
const SHORE_CORNER_DEPTH := 8
## Shore freckle RGB scale (1.0 = raw mask art; lower = softer).
const SHORE_COLOR_SCALE := 0.35
## Directed `shore_land_*` masks (no ref_ prefix) per side / corner / dual.
const SHORE_REF_N := "top"
const SHORE_REF_E := "right"
const SHORE_REF_S := "bottom"
const SHORE_REF_W := "left"
const SHORE_REF_NW := "corner_nw"
const SHORE_REF_NE := "corner_ne"
const SHORE_REF_SW := "corner_sw"
const SHORE_REF_SE := "corner_se"
const SHORE_REF_EW := "dual_ew" ## vertical river banks
const SHORE_REF_NS := "dual_ns" ## horizontal channel
const SHORE_REF_FRAME := "frame" ## land on all sides
## Sentinel: no map cell for shore neighbour lookup.
const SHORE_NO_CELL := 0x7fffffff
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
const TILE_WISP := 220 ## xu4 wisp flash (Dispel / Cure / Awaken)
const TILE_MISS_FLASH := 77 ## xu4 missFlash / red projectile
const TILE_MAGIC_FLASH := 78 ## xu4 magicFlash (intro mage bolt / wand)
const TILE_HIT_FLASH := 79 ## xu4 hitFlash / attack_flash
const TILE_WHIRLPOOL := 140 ## xu4 Kill missile (`spellMagicAttack("whirlpool")`)
## Seconds per tile of cannon travel (matches prior per-tile miss flash).
const CANNON_SEC_PER_TILE := 0.085
## Magic bow / magic axe fly 1.5× faster than the default missile.
const MAGIC_MISSILE_SPEED := 1.5
## Multi-frame terrain flip period (spit, etc.).
const TILE_ANIM_PERIOD := 0.20
## Horse frames: 0 = walk A (`NNN.png`), 1 = stand (`_1`), 2 = walk B (`_2`).
const HORSE_WALK_FRAME_A := 0
const HORSE_STAND_FRAME := 1
const HORSE_WALK_FRAME_B := 2
const HORSE_IDLE_STAND_SEC := 0.5
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
const TILE_BALLOON := 24
## Bridge tiles — near (south) white railing redrawn over sprites for depth.
const TILE_BRIDGE := 23
const TILE_BRIDGE_N := 25
const TILE_BRIDGE_S := 26
## Stone wall (no shore freckles beside masonry).
const TILE_STONE_WALL := 57
## Ship deck plank flooring (ship combat maps).
const TILE_PLANKS := 63
## White solid hull / rail used heavily on ship .CON maps.
const TILE_WHITE_SOLID := 72
## Ship mast / wheel (combat ship interior).
const TILE_SHIP_MAST := 53
const TILE_SHIP_WHEEL := 54
## Pirate ship hull facings (xu4 tiles 128–131).
const TILE_PIRATE_SHIP_W := 128
const TILE_PIRATE_SHIP_S := 131
## Medium water preferred for void beside ship hulls in combat margins.
const TILE_MEDIUM_WATER := 1
## First source row of the near railing on bridge / bridge_s (32×32 art).
const BRIDGE_NEAR_RAIL_Y := 19
## World terrain ids used by camp margins.
const TILE_SWAMP := 3
const TILE_GRASS := 4
const TILE_BRUSH := 5
const TILE_FOREST := 6
const TILE_HILLS := 7
const TILE_MOUNTAINS := 8
const TILE_DUNGEON := 9 ## World dungeon entrance
## City shop letter signs A–Z + space (xu4 signs).
const TILE_SIGN_A := 96
const TILE_SIGN_SPACE := 122
## Brick wall (city masonry).
const TILE_BRICK_WALL := 127
## Mounted party marker (person on horse) — left / right.
const HORSE_RIDER_W_PATH := "res://assets/tiles/horse_rider_w.png"
const HORSE_RIDER_E_PATH := "res://assets/tiles/horse_rider_e.png"
## Apple II: fixed rider silhouette (class-independent). SHP 20/21 are riderless.
const APPLE2_HORSE_MOUNT_W_PATH := "res://assets/tiles/apple2_horse_mount_w.png"
const APPLE2_HORSE_MOUNT_E_PATH := "res://assets/tiles/apple2_horse_mount_e.png"
## Class-painted mounts: `020_horse_west_{slug}.png` / `021_horse_east_{slug}.png`.
const HORSE_RIDER_SHAPE_DIR := "res://assets/tiles/u4graphics/shapes/"
const HORSE_RIDER_CLASS_SLUG := [
	"mage", "bard", "fighter", "druid", "tinker", "paladin", "ranger", "shepherd",
]
## Cannonball: black_pearl ~12×12, centered on transparent 32×32.
const CANNONBALL_PATH := "res://assets/tiles/cannonball.png"
const _ResImage := preload("res://src/core/res_image.gd")
## Sling stone — source art scaled to 1/4 (8×8 from 32×32).
const SLING_MISSILE_PATH := "res://assets/ui/weapons/sling_missile.png"
## Ettin / Cyclops / dungeon falling-rock trap — grey stones, black keyed out.
const THROWN_ROCKS_PATH := "res://assets/ui/combat/thrown_rocks.png"
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
const MAGIC_AXE_SPIN_PER_TILE := TAU * 0.45
## Kill whirlpool — slow spin so the spiral stays readable in flight.
const WHIRLPOOL_SPIN_PER_TILE := TAU * 0.45
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
## Tile-cell wipe explore → combat over 0.8s (diagonal front from top-left).
const COMBAT_ENTER_TRANS_SEC := 0.8

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
## Viewport LOS mask relative to `center` (0/1). Sized view+2×view+2 so scroll
## fringe (±1 beyond visible) uses real opacity blackout (no terrain pop).
var _los: PackedByteArray = PackedByteArray()
var _los_w: int = 0
var _los_h: int = 0
## Extra LOS cells beyond view so peel-in stage columns have fog answers.
const LOS_PAD := 1
## Temporary world overlays: Vector3i(x, y, tile_id) — horse/ship stubs, etc.
var _overlays: Array[Vector3i] = []
## Session-only terrain swaps (Abyss fire → dungeon). Not saved.
var _session_tiles: Dictionary = {}
var _overlay_slices: Dictionary = {} ## tile_id → keyed Image
var _flying_slices: Dictionary = {} ## tile_id → black-keyed flying overlay
## 3-wide HGR overlay used while the party stays screen-fixed during scroll.
var _apple2_scroll_party: Image
var _apple2_scroll_party_key := Vector4i(-1, -1, -1, -1)
## Wilderness monsters: { x, y, tid, hp, max_hp }. Drawn with tile animation + HP bar.
var _creatures: Array = []
## Brief world-tile FX: { x, y, tid, left }.
var _tile_flashes: Array[Dictionary] = []
## Flying cannonball in unwrapped tile-space (center): { x, y } or empty.
var _cannon_proj: Dictionary = {}
var _cannonball_img: Image
var _sling_missile_img: Image
## Keyed Ettin/Cyclops rock (also dungeon falling-rock trap).
var _thrown_rocks_img: Image
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
var _whirlpool_rot_cache: Dictionary = {}

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
var _horse_rider_w_frames: Array = []
var _horse_rider_e_frames: Array = []
var _horse_rider_class := -999
## Fallback Avatar-on-horse art from disk.
var _horse_rider_w_asset: Image
var _horse_rider_e_asset: Image
## Mounted gait: stand on `_1` until a move, then A/`_2` per move; stand again after idle.
var _horse_standing := true
## Last walk frame: true = `_2`. Start true so the first step of a session is frame A.
var _horse_walk_on_b := true
## Gallop issues two set_center calls in one move — only flip gait once per frame.
var _horse_step_process_frame := -1
var _horse_idle_left := 0.0

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
## shore_land_* cache: mask name → Image (RGBA freckles).
var _shore_land_cache: Dictionary = {}
var _gold_loot_icon: Image
var _loot_icon_cache: Dictionary = {} ## path → scaled Image
## Ship grounding jolt — party/ship sprite offset while > 0.
var _shake_left := 0.0
var _shake_dur := 0.0
var _shake_amp := 0.0
## Tremor: irregular horizontal bursts with still gaps (not a sine).
var _shake_quake := false
var _quake_ox := 0
var _quake_jolt_cd := 0.0
var _quake_bursts: Array = [] ## [{start, end}, ...] elapsed seconds
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
## Shrine enter/exit walker on the .CON (camp paint path). Off-map = (-1,-1).
var _shrine_walker := Vector2i(-1, -1)
## xu4 enhancedSequence: kneel at the altar as the beggar (praying) tile.
var _shrine_walker_kneel := false
const TILE_BEGGAR := 88
## Spirituality (moongate): side voids force grass, not moongate/world neighbours.
var _shrine_plain_margins := false
## Cached BRIDGE.CON for camp/combat side margins (not the active arena).
var _bridge_con_map
## Combat arena — same 11×11 centered layout as camp; units painted on top.
var _combat_map # CombatMapData
## Each: { "x", "y", "klass", "party_slot"? } — living party members.
var _combat_party: Array[Dictionary] = []
## Per-party walk frame (0/1) and countdown — independent of `_avatar_frame`.
var _combat_party_frame_bit: Array[int] = []
var _combat_party_frame_cd: Array[float] = []
## Each: { "x", "y", "tile" } — foes on the arena.
var _combat_foes: Array[Dictionary] = []
## Per-foe animation tick (for resolve_paint_tile) and countdown.
var _combat_foe_anim_tick: Array[int] = []
var _combat_foe_anim_cd: Array[float] = []
## Living foe count at combat start (for 1/N chest drop).
var _combat_foe_spawn_count := 0
## Combat loot chests: key "x,y" → { open, stack, ... }.
var _combat_chests: Dictionary = {}
## xu4 InnController::awardLoot empty — inn night fights drop nothing.
## Dungeon rooms also suppress (xu4 winOrLose false).
var suppress_combat_chests := false
## Closed / open chest with keyed black so combat underdraw (CON floor) shows.
var _keyed_chest_frames: Array = []
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
## Out-of-range overlay while Attack aim is open (50% black).
const COMBAT_RANGE_SHADE := Color(0, 0, 0, 0.5)
var _combat_range_shade := false
var _combat_range_from := Vector2i.ZERO
var _combat_range_weapon := 0
var _combat_range_shade_img: Image
## City-outside ring: 50% black so the exit tiles read as leaving town.
const CITY_EXIT_SHADE := Color(0, 0, 0, 0.50)
var _city_exit_shade_img: Image
## Combat-local tile flashes: { x, y, tid, left } in .CON coords.
var _combat_tile_flashes: Array[Dictionary] = []
## Ranged weapon missile in combat-local float tile space (tile centers).
var _combat_proj: Dictionary = {}
## True while the enter-combat tile wipe paints the buffer.
var _scene_trans_busy := false
## First-person dungeon corridor (persists through combat).
var _dungeon_map
var _dungeon_view
var _dungeon_field: Image
var _dungeon_z := 0
var _dungeon_dir := 2
var _dungeon_lit := false
var _torch_flicker_mat: ShaderMaterial
var _cloud_mat: ShaderMaterial
var _cloud_overlay: TextureRect
var _weather_cam_hold := Vector2.ZERO
var _weather_party_hold := Vector2.ZERO
var _weather_cam_held := false
var _indoor_tex: ImageTexture
var _indoor_key := ""
var _indoor_bits: PackedByteArray = PackedByteArray()
var _hide_img: Image
## Falling-rock trap overlay: keyed sprite chunks in dungeon-field pixels.
var _dungeon_rock_fx: Dictionary = {}
var _dungeon_rock_img: Image
const DUNGEON_ROCK_FALL_SEC := 0.2
## Start the next chunk before the previous finishes so they overlap.
const DUNGEON_ROCK_STAGGER_SEC := 0.08
const DUNGEON_ROCK_LINGER_SEC := 0.5
const DUNGEON_ROCK_COUNT := 3
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
## Reusable Apple II continuous NTSC tile-id grid.
var _apple2_ids := PackedInt32Array()

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
	_thrown_rocks_img = _key_black_plate(_load_image_path(THROWN_ROCKS_PATH))
	_dagger_missile_img = _prepare_dagger_missile(_load_image_path(DAGGER_MISSILE_PATH))
	_magic_axe_missile_img = _prepare_sized_missile(
		_load_image_path(MAGIC_AXE_MISSILE_PATH), MAGIC_AXE_MISSILE_DRAW
	)
	_arrow_missile_img = _load_image_path(ARROW_MISSILE_PATH)
	_magic_arrow_missile_img = _load_image_path(MAGIC_ARROW_MISSILE_PATH)
	texture = _tex
	material = null
	_ensure_cloud_overlay()


func setup(p_world: WorldMapData, _p_atlas: Texture2D = null) -> void:
	## `_p_atlas` kept for call-site compatibility; tiles load from shapes/*.png.
	world = p_world
	tiles_ready = false
	_avatar_a = null
	_avatar_b = null
	_horse_rider_class = -999
	_corpse_slice = null
	_overlay_slices.clear()
	_flying_slices.clear()
	_apple2_scroll_party = null
	_apple2_scroll_party_key = Vector4i(-1, -1, -1, -1)
	_keyed_chest_frames.clear()
	_loot_icon_cache.clear()
	_gold_loot_icon = null
	_session_tiles.clear()
	_moongate_suck_by_tid.clear()
	exit_combat()
	exit_camp()
	exit_city()
	exit_dungeon()
	tiles_ready = _U4TileBankScript.ensure_loaded()
	if tiles_ready:
		_cache_avatar_icons()
	_scroll_frames_left = 0
	_avatar_frame = 0
	_roll_frame_cd()
	_rebuild()


func reload_tileset_graphics() -> void:
	## After GraphicsSettings switches U4TileBank — drop keyed caches and redraw.
	_avatar_a = null
	_avatar_b = null
	_horse_rider_class = -999
	_horse_rider_w = null
	_horse_rider_e = null
	_horse_rider_w_frames.clear()
	_horse_rider_e_frames.clear()
	_corpse_slice = null
	_overlay_slices.clear()
	_flying_slices.clear()
	_apple2_scroll_party = null
	_apple2_scroll_party_key = Vector4i(-1, -1, -1, -1)
	_keyed_chest_frames.clear()
	_loot_icon_cache.clear()
	_gold_loot_icon = null
	_moongate_suck_by_tid.clear()
	tiles_ready = _U4TileBankScript.ensure_loaded()
	if tiles_ready:
		_cache_avatar_icons()
	if _dungeon_view != null and _dungeon_view.has_method("invalidate_tile_caches"):
		_dungeon_view.invalidate_tile_caches()
	material = null
	if _dungeon_map != null:
		_rebuild_dungeon()
	else:
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


func player_local_center() -> Vector2:
	## Center of the walking avatar (explore) or combat focus, in local pixels.
	var ts := displayed_tile_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return size * 0.5
	var tile := Vector2i(view_w / 2, view_h / 2)
	if is_in_combat():
		var pos := get_combat_focus_pos()
		if pos.x >= 0:
			tile = Vector2i((view_w - CAMP_W) / 2, (view_h - CAMP_H) / 2) + pos
	return Vector2((float(tile.x) + 0.5) * ts.x, (float(tile.y) + 0.5) * ts.y)


func view_tile_at_local(local: Vector2) -> Vector2i:
	## Grid cell under a MapView-local pixel. (-1,-1) if outside the view.
	var ts: Vector2 = displayed_tile_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return Vector2i(-1, -1)
	var col: int = floori(local.x / ts.x)
	var row: int = floori(local.y / ts.y)
	if col < 0 or row < 0 or col >= view_w or row >= view_h:
		return Vector2i(-1, -1)
	return Vector2i(col, row)


func combat_tile_at_local(local: Vector2) -> Vector2i:
	## Combat-local 11×11 cell under a MapView-local pixel.
	if not is_in_combat():
		return Vector2i(-1, -1)
	var view_tile := view_tile_at_local(local)
	if view_tile.x < 0:
		return Vector2i(-1, -1)
	var origin := Vector2i((view_w - CAMP_W) / 2, (view_h - CAMP_H) / 2)
	var combat_tile := view_tile - origin
	if (
		combat_tile.x < 0
		or combat_tile.y < 0
		or combat_tile.x >= CAMP_W
		or combat_tile.y >= CAMP_H
	):
		return Vector2i(-1, -1)
	return combat_tile


func cols_for_pane(_pane: Vector2) -> int:
	## Explore width is fixed (VIEW_W); pane stretch sets the tile aspect.
	return VIEW_W


func is_scrolling() -> bool:
	return SMOOTH_SCROLL and _scroll_frames_left > 0


func is_camping() -> bool:
	return _camp_map != null


func is_in_combat() -> bool:
	return _combat_map != null


func apply_dungeon_room_trigger(dmap, index: int, pos: Vector2i) -> bool:
	if _combat_map == null or dmap == null:
		return false
	if not dmap.apply_room_trigger_at(index, pos, _combat_map):
		return false
	_rebuild()
	return true


func set_combat_tile(pos: Vector2i, tid: int) -> bool:
	if _combat_map == null or not _combat_in_bounds(pos):
		return false
	_combat_map.set_tile(pos.x, pos.y, tid)
	_rebuild()
	return true


func camp_tile_at(pos: Vector2i) -> int:
	if _camp_map == null:
		return -1
	if pos.x < 0 or pos.y < 0 or pos.x >= CAMP_W or pos.y >= CAMP_H:
		return -1
	return int(_camp_map.tile_at(pos.x, pos.y))


func set_camp_tile(pos: Vector2i, tid: int) -> bool:
	if _camp_map == null:
		return false
	if pos.x < 0 or pos.y < 0 or pos.x >= CAMP_W or pos.y >= CAMP_H:
		return false
	_camp_map.set_tile(pos.x, pos.y, tid)
	_rebuild()
	return true


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
	var tid := int(_combat_map.tile_at(pos.x, pos.y))
	if not (_TileRulesCamp.is_door(tid) or _TileRulesCamp.is_locked_door(tid)):
		return false
	_combat_map.set_tile(pos.x, pos.y, 62) ## brick floor
	_rebuild()
	return true


func is_in_dungeon() -> bool:
	return _dungeon_map != null and bool(_dungeon_map.loaded)


func enter_dungeon(dmap, pos: Vector2i, z: int, dir: int, lit: bool) -> void:
	exit_combat()
	exit_camp()
	exit_city()
	_dungeon_map = dmap
	_dungeon_z = z
	_dungeon_dir = dir
	_dungeon_lit = lit
	if _dungeon_view == null:
		_dungeon_view = _DungeonViewScript.new()
	_dungeon_view.set_theme(_DungeonPortalsScript.theme_for(str(dmap.dungeon_id)))
	center = pos
	_scroll_frames_left = 0
	_rebuild()


func set_dungeon_pose(pos: Vector2i, z: int, dir: int, lit: bool) -> void:
	if _dungeon_map == null:
		return
	_dungeon_z = z
	_dungeon_dir = dir
	_dungeon_lit = lit
	center = pos
	_scroll_frames_left = 0
	_rebuild()


func exit_dungeon() -> void:
	if _dungeon_map == null:
		return
	_dungeon_map = null
	_dungeon_z = 0
	_dungeon_dir = 2
	_dungeon_lit = false
	_dungeon_rock_fx.clear()
	_scroll_frames_left = 0
	_rebuild()


func await_dungeon_falling_rocks_fall() -> void:
	## Drop three pre-rotated rock chunks into a triangle stack (overlap stagger).
	if not is_in_dungeon():
		return
	if _dungeon_view == null:
		_dungeon_view = _DungeonViewScript.new()
		_dungeon_view.set_theme(_DungeonPortalsScript.theme_for(str(_dungeon_map.dungeon_id)))
	_dungeon_rock_img = _dungeon_view.falling_rock_sprite()
	if _dungeon_rock_img == null or _dungeon_rock_img.is_empty():
		return
	var field_w := CAMP_W * TILE_SRC
	var field_h := CAMP_H * TILE_SRC
	var layout: Dictionary = _dungeon_view.falling_rock_layout(field_w, field_h)
	var span := int(layout.get("span", 24))
	var start_y := float(layout.get("start_y", 0))
	var start_x := float(layout.get("start_x", field_w / 2))
	var slots: Array = layout.get("slots", []) as Array
	var pieces: Array = []
	for i in mini(DUNGEON_ROCK_COUNT, slots.size()):
		var slot: Dictionary = slots[i] as Dictionary
		var angle := randf() * TAU
		var rotated := _rotate_image_nearest(_dungeon_rock_img, angle)
		if rotated == null or rotated.is_empty():
			rotated = _dungeon_rock_img
		var end_y := float(slot.get("end_y", field_h))
		## Guarantee downward travel even if layout clamp squeezes the path.
		if end_y <= start_y + 1.0:
			end_y = start_y + float(maxi(span, 48))
		pieces.append({
			"img": rotated,
			"mid_x": start_x,
			"start_x": start_x,
			"end_x": float(slot.get("mid_x", start_x)),
			"span": span,
			"y": start_y,
			"start_y": start_y,
			"end_y": end_y,
			"on_top": bool(slot.get("on_top", false)),
		})
	if pieces.is_empty():
		return
	_dungeon_rock_fx = {"pieces": pieces}
	_rebuild_dungeon()
	## Drive all chunks from one progress clock — avoids parallel tween bind quirks.
	var total_sec := (
		DUNGEON_ROCK_FALL_SEC
		+ float(maxi(pieces.size() - 1, 0)) * DUNGEON_ROCK_STAGGER_SEC
	)
	var tw := create_tween()
	tw.tween_method(_tick_dungeon_rock_fall, 0.0, total_sec, total_sec)
	await tw.finished
	## Snap every chunk to its floor slot before damage resolves.
	for i in pieces.size():
		var piece: Dictionary = (_dungeon_rock_fx.get("pieces", []) as Array)[i]
		piece["y"] = float(piece.get("end_y", field_h))
		piece["mid_x"] = int(round(float(piece.get("end_x", piece.get("mid_x", 0)))))
		(_dungeon_rock_fx["pieces"] as Array)[i] = piece
	_rebuild_dungeon()


func await_dungeon_falling_rocks_settle() -> void:
	## Hold the stacked rocks briefly, then clear the overlay.
	if _dungeon_rock_fx.is_empty():
		return
	var tree := get_tree()
	if tree != null:
		await tree.create_timer(DUNGEON_ROCK_LINGER_SEC).timeout
	_dungeon_rock_fx.clear()
	if is_in_dungeon():
		_rebuild_dungeon()


func _tick_dungeon_rock_fall(elapsed: float) -> void:
	if _dungeon_rock_fx.is_empty():
		return
	var pieces: Array = _dungeon_rock_fx.get("pieces", []) as Array
	var dirty := false
	for i in pieces.size():
		var piece: Dictionary = pieces[i] as Dictionary
		var local_t := clampf(
			(elapsed - float(i) * DUNGEON_ROCK_STAGGER_SEC) / DUNGEON_ROCK_FALL_SEC,
			0.0,
			1.0
		)
		## Ease-in fall; spread sideways into the triangle as each chunk drops.
		var eased := local_t * local_t
		var y0 := float(piece.get("start_y", 0.0))
		var y1 := float(piece.get("end_y", y0))
		var x0 := float(piece.get("start_x", piece.get("mid_x", 0.0)))
		var x1 := float(piece.get("end_x", x0))
		var y := lerpf(y0, y1, eased)
		var x := lerpf(x0, x1, eased)
		var prev_y := float(piece.get("y", y0))
		var prev_x := float(piece.get("mid_x", x0))
		if not is_equal_approx(prev_y, y) or not is_equal_approx(prev_x, x):
			piece["y"] = y
			piece["mid_x"] = int(round(x))
			pieces[i] = piece
			dirty = true
	if dirty:
		_dungeon_rock_fx["pieces"] = pieces
		if is_in_dungeon():
			_rebuild_dungeon()


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
	exit_dungeon()
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
	_indoor_key = ""
	_indoor_bits = PackedByteArray()
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


func enter_shrine(map, plain_margins: bool = false) -> void:
	## xu4 VIEW_CUTSCENE_MAP — SHRINE.CON; baked avatar at (5,6) cleared for walk-in.
	## `plain_margins`: Spirituality gate — fill L/R voids with grass (no moongate terrain).
	exit_combat()
	exit_city()
	_camp_map = map
	_camp_sleepers.clear()
	_camp_guard_class = -1
	_camp_guard_pos = Vector2i(-1, -1)
	_camp_guard_cd = 0.0
	_camp_guard_a = null
	_camp_guard_b = null
	_shrine_walker = Vector2i(-1, -1)
	_shrine_walker_kneel = false
	_shrine_plain_margins = plain_margins
	## xu4 enhancedSequence annotations: static Avatar tile → grass.
	if _camp_map != null:
		var stand := int(_camp_map.tile_at(5, 6))
		if stand == AVATAR_TILE_A or stand == AVATAR_TILE_B:
			_camp_map.set_tile(5, 6, TILE_GRASS)
	_build_camp_background()
	_scroll_frames_left = 0
	_rebuild()


func set_shrine_walker(pos: Vector2i) -> void:
	## Camp-local coord for entrance approach / exit. Use (-1,-1) to hide.
	if _shrine_walker == pos:
		return
	_shrine_walker = pos
	if _camp_map != null:
		_rebuild()


func set_shrine_kneel(kneel: bool) -> void:
	## Avatar walk sprite ↔ beggar (praying) while at the altar.
	if _shrine_walker_kneel == kneel:
		return
	_shrine_walker_kneel = kneel
	if _camp_map != null:
		_rebuild()


func clear_shrine_walker() -> void:
	_shrine_walker_kneel = false
	set_shrine_walker(Vector2i(-1, -1))


func exit_shrine() -> void:
	## Same teardown as camp view (shared _camp_map).
	_shrine_walker = Vector2i(-1, -1)
	_shrine_walker_kneel = false
	_shrine_plain_margins = false
	exit_camp()


func exit_camp() -> void:
	if (
		_camp_map == null
		and _camp_sleepers.is_empty()
		and _camp_bg.is_empty()
		and _camp_guard_class < 0
		and _shrine_walker.x < 0
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
	_shrine_walker = Vector2i(-1, -1)
	_shrine_walker_kneel = false
	_shrine_plain_margins = false
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
	suppress_combat_chests = false
	for u in foe_units:
		if typeof(u) == TYPE_DICTIONARY:
			_combat_foes.append((u as Dictionary).duplicate(true))
	_combat_foe_spawn_count = _combat_foes.size()
	## xu4 beginCombat — focus first placeable party member.
	_combat_focus = 0 if not _combat_party.is_empty() else -1
	_combat_foe_focus = -1
	_combat_last_fled = {}
	_combat_aim_pos = Vector2i(-1, -1)
	_combat_range_shade = false
	_combat_tile_flashes.clear()
	_combat_proj.clear()
	_init_combat_anim_frames()
	_ensure_combat_aim_cursor()
	_combat_focus_on = true
	_combat_focus_cd = COMBAT_FOCUS_BLINK_SEC
	if is_in_dungeon():
		_camp_bg = PackedByteArray()
	else:
		_build_camp_background()
	_scroll_frames_left = 0
	_rebuild()


func snapshot_frame() -> Image:
	## Copy of the current map buffer for scene transitions.
	_hold_weather_cam()
	if _buf == null:
		return null
	return _buf.duplicate()


func await_enter_wipe(from: Image, duration: float = COMBAT_ENTER_TRANS_SEC) -> void:
	## Diagonal tile wipe for scene entry (combat, city, dungeon).
	await await_combat_enter_wipe(from, duration)


func await_combat_enter_wipe(from: Image, duration: float = COMBAT_ENTER_TRANS_SEC) -> void:
	## Reveal combat one tile at a time, anti-diagonals first: cells with equal
	## (cx + cy) flip together as a band that grows from top-left → bottom-right.
	if from == null or _buf == null or duration <= 0.0:
		_release_weather_cam()
		return
	var to: Image = _buf.duplicate()
	var w: int = to.get_width()
	var h: int = to.get_height()
	if w < 1 or h < 1:
		return
	if from.get_width() != w or from.get_height() != h:
		from = from.duplicate()
		from.resize(w, h, Image.INTERPOLATE_NEAREST)
	_scene_trans_busy = true
	## Hold explore until the first combat tile lands.
	_buf.blit_rect(from, Rect2i(0, 0, w, h), Vector2i.ZERO)
	_upload_buffer()
	queue_redraw()
	var cell: int = TILE_SRC
	var gw: int = int(ceili(float(w) / float(cell)))
	var gh: int = int(ceili(float(h) / float(cell)))
	## Diagonals d = 0 .. (gw + gh - 2); d=0 is top-left tile only.
	var d_max: int = maxi(0, gw + gh - 2)
	var last_d: int = -1
	var t0: float = Time.get_ticks_msec() / 1000.0
	while true:
		var elapsed: float = Time.get_ticks_msec() / 1000.0 - t0
		var t: float = clampf(elapsed / duration, 0.0, 1.0)
		## t=0 → no bands; t=1 → every diagonal including d_max.
		var d_now: int = int(floor(t * float(d_max + 1) + 1e-6)) - 1
		if t >= 1.0:
			d_now = d_max
		while last_d < d_now:
			last_d += 1
			_blit_wipe_diagonal(to, last_d, gw, gh, cell, w, h)
			_upload_buffer()
		queue_redraw()
		if t >= 1.0:
			break
		await get_tree().process_frame
	_buf.blit_rect(to, Rect2i(0, 0, w, h), Vector2i.ZERO)
	_upload_buffer()
	_scene_trans_busy = false
	_release_weather_cam()
	queue_redraw()


func _blit_wipe_diagonal(
	src: Image,
	d: int,
	gw: int,
	gh: int,
	cell: int,
	w: int,
	h: int
) -> void:
	## All tiles on the anti-diagonal cx + cy == d (from top-left outward).
	if src == null or _buf == null or d < 0 or cell < 1:
		return
	## cx from max(0, d-(gh-1)) to min(gw-1, d)
	var cx0: int = maxi(0, d - (gh - 1))
	var cx1: int = mini(gw - 1, d)
	for cx in range(cx0, cx1 + 1):
		var cy: int = d - cx
		_blit_wipe_cell(src, cx, cy, cell, w, h)


func _blit_wipe_cell(src: Image, cx: int, cy: int, cell: int, w: int, h: int) -> void:
	## Copy one hard combat tile into `_buf` (clipped at the right/bottom edge).
	if src == null or _buf == null or cell < 1:
		return
	var x: int = cx * cell
	var y: int = cy * cell
	if x >= w or y >= h:
		return
	var bw: int = mini(cell, w - x)
	var bh: int = mini(cell, h - y)
	if bw < 1 or bh < 1:
		return
	_buf.blit_rect(src, Rect2i(x, y, bw, bh), Vector2i(x, y))


func exit_combat() -> void:
	if _combat_map == null and _combat_party.is_empty() and _combat_foes.is_empty():
		return
	_combat_map = null
	_combat_party.clear()
	_combat_foes.clear()
	_combat_chests.clear()
	_combat_foe_spawn_count = 0
	suppress_combat_chests = false
	_combat_focus = -1
	_combat_foe_focus = -1
	_combat_last_fled = {}
	_combat_aim_pos = Vector2i(-1, -1)
	_combat_range_shade = false
	_combat_tile_flashes.clear()
	_combat_proj.clear()
	_clear_combat_anim_frames()
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


func find_combat_party_index_for_slot(party_slot: int) -> int:
	## Combat-party index for a party order slot, or −1 if not on the arena.
	if party_slot < 0:
		return -1
	for i in _combat_party.size():
		if int(_combat_party[i].get("party_slot", -1)) == party_slot:
			return i
	return -1


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


func set_combat_range_shade(from: Vector2i, weapon_id: int) -> void:
	## Dim tiles the current weapon cannot reach. weapon_id < 0 clears (spell aim).
	if weapon_id < 0:
		clear_combat_range_shade()
		return
	_combat_range_shade = true
	_combat_range_from = from
	_combat_range_weapon = weapon_id
	if _combat_map != null:
		_rebuild()


func clear_combat_range_shade() -> void:
	if not _combat_range_shade:
		return
	_combat_range_shade = false
	if _combat_map != null:
		_rebuild()


func combat_can_aim_tile(pos: Vector2i) -> bool:
	## Confirm-attack cells: floor / water, or any tile a unit already occupies.
	## Empty walls, rocks, columns, and doors cannot be struck (no corporeal
	## monster can stand there). Cursor movement may still pass through.
	if _combat_map == null or not _combat_in_bounds(pos):
		return false
	if combat_foe_index_at(pos) >= 0 or combat_party_index_at(pos) >= 0:
		return true
	var tid := int(_combat_map.tile_at(pos.x, pos.y))
	return (
		_TileRulesCamp.is_walkable(tid)
		or _TileRulesCamp.is_swimable(tid)
		or _TileRulesCamp.is_sailable(tid)
	)


func combat_can_strike(weapon_id: int, from: Vector2i, to: Vector2i) -> bool:
	## Range check only. Terrain blocking is combat_can_aim_tile / projectile stop.
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
	## Focus unit: same index accounting as OOB flee (next member, or round over).
	if index < 0 or index >= _combat_party.size():
		return {}
	var removed: Dictionary = _combat_party[index]
	var was_focus := _combat_focus == index
	_combat_party.remove_at(index)
	_drop_combat_party_anim_at(index)
	if was_focus:
		if _combat_focus >= _combat_party.size():
			_combat_focus = _combat_party.size()
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


func set_combat_foe_asleep(index: int, asleep: bool) -> void:
	if index < 0 or index >= _combat_foes.size():
		return
	var f: Dictionary = _combat_foes[index]
	f["asleep"] = asleep
	_combat_foes[index] = f
	if _combat_map != null:
		_rebuild()


func is_combat_foe_asleep(index: int) -> bool:
	if index < 0 or index >= _combat_foes.size():
		return false
	return bool(_combat_foes[index].get("asleep", false))


func set_combat_foe_poisoned(index: int, poisoned: bool) -> void:
	if index < 0 or index >= _combat_foes.size():
		return
	var f: Dictionary = _combat_foes[index]
	f["poisoned"] = poisoned
	_combat_foes[index] = f


func is_combat_foe_poisoned(index: int) -> bool:
	if index < 0 or index >= _combat_foes.size():
		return false
	return bool(_combat_foes[index].get("poisoned", false))


func set_combat_foe_turned(index: int, turned: bool) -> void:
	## Remake Undead: flee-as-if-low-HP until combat ends. No HP change, no HUD.
	if index < 0 or index >= _combat_foes.size():
		return
	var f: Dictionary = _combat_foes[index]
	f["turned"] = turned
	_combat_foes[index] = f


func is_combat_foe_turned(index: int) -> bool:
	if index < 0 or index >= _combat_foes.size():
		return false
	return bool(_combat_foes[index].get("turned", false))


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
	## xu4 exp ≈ config basehp / 16 — not the rolled spawn HP used by the bar.
	out["xp"] = maxi(1, _WorldCreaturesScript.base_hp_for(int(f.get("tile", 0))) / 16)
	if hp <= 0:
		out["killed"] = true
		## xu4 awardLoot was 100% once per fight; split as 1/N per kill on death tile.
		var at := Vector2i(int(f.get("x", 0)), int(f.get("y", 0)))
		out["chest"] = try_spawn_combat_chest(at, int(f.get("tile", 0)))
	if _combat_map != null:
		_rebuild()
	return out


func try_spawn_combat_chest(pos: Vector2i, foe_tile: int) -> bool:
	## leavesChest types only; p = 1 / spawn count. Same-tile drops stack LIFO.
	if suppress_combat_chests:
		return false
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
	var humanoid := _WorldCreaturesScript.is_humanoid(foe_tile)
	var spider := _WorldCreaturesScript.is_spider(foe_tile)
	var mage := _WorldCreaturesScript.is_mage(foe_tile)
	var key_source := _WorldCreaturesScript.drops_chest_keys(foe_tile)
	var stack: Array = GameState.roll_combat_chest_loot(humanoid, spider, mage, key_source)
	var chest := {
		"x": pos.x,
		"y": pos.y,
		"open": false,
		"stack": stack,
		"from_spider": spider,
		"from_mage": mage,
	}
	var pile: Array = _combat_chest_pile_at(pos)
	pile.append(chest)
	_combat_chests[key] = pile
	return true


static func _combat_chest_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


func _combat_chest_pile_at(pos: Vector2i) -> Array:
	var raw: Variant = _combat_chests.get(_combat_chest_key(pos.x, pos.y), [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	return (raw as Array).duplicate(true)


func _top_combat_chest_at(pos: Vector2i) -> Dictionary:
	var pile := _combat_chest_pile_at(pos)
	if pile.is_empty():
		return {}
	var raw: Variant = pile.back()
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return (raw as Dictionary).duplicate(true)


func _combat_map_has_chest_tile(pos: Vector2i) -> bool:
	## Dungeon-room chests are TILE_CHEST on the .CON grid, not slain-foe overlays.
	if _combat_map == null or not _combat_in_bounds(pos):
		return false
	return _TileRulesCamp.is_chest(int(_combat_map.tile_at(pos.x, pos.y)))


func _ensure_map_tile_combat_chest(pos: Vector2i) -> bool:
	## Lift a room chest tile into the overlay pile so Open/Get share slain-foe loot.
	if not _combat_chest_pile_at(pos).is_empty():
		return true
	if not _combat_map_has_chest_tile(pos):
		return false
	_combat_map.set_tile(pos.x, pos.y, TILE_BRICK_FLOOR)
	var stack: Array = [{
		"kind": GameState.CHEST_LOOT_GOLD,
		"amount": GameState.roll_chest_gold_amount(),
		"id": 0,
	}]
	_combat_chests[_combat_chest_key(pos.x, pos.y)] = [{
		"x": pos.x,
		"y": pos.y,
		"open": false,
		"stack": stack,
		"from_spider": false,
		"from_mage": false,
		"room_tile": true,
	}]
	return true


func has_combat_chest_at(pos: Vector2i) -> bool:
	return not _combat_chest_pile_at(pos).is_empty() or _combat_map_has_chest_tile(pos)


func has_closed_combat_chest() -> bool:
	for raw_pile in _combat_chests.values():
		if typeof(raw_pile) != TYPE_ARRAY:
			continue
		for raw_chest in raw_pile as Array:
			if typeof(raw_chest) == TYPE_DICTIONARY and not bool(
				(raw_chest as Dictionary).get("open", false)
			):
				return true
	if _combat_map != null:
		for y in CAMP_H:
			for x in CAMP_W:
				if _TileRulesCamp.is_chest(int(_combat_map.tile_at(x, y))):
					return true
	return false


func combat_chest_is_open(pos: Vector2i) -> bool:
	return bool(_top_combat_chest_at(pos).get("open", false))


func combat_chest_stack_size(pos: Vector2i) -> int:
	var chest := _top_combat_chest_at(pos)
	var stack: Variant = chest.get("stack", [])
	if typeof(stack) != TYPE_ARRAY:
		return 0
	return (stack as Array).size()


func combat_chest_has_loot(pos: Vector2i) -> bool:
	var chest := _top_combat_chest_at(pos)
	if chest.is_empty():
		return false
	if not bool(chest.get("open", false)):
		return false
	return combat_chest_stack_size(pos) > 0


func open_combat_chest_at(pos: Vector2i) -> bool:
	## Open the newest (top) chest; each same-tile chest remains independent.
	if not _ensure_map_tile_combat_chest(pos):
		return false
	var key := _combat_chest_key(pos.x, pos.y)
	var pile := _combat_chest_pile_at(pos)
	if pile.is_empty():
		return false
	var top_i := pile.size() - 1
	var raw: Variant = pile[top_i]
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var chest: Dictionary = (raw as Dictionary).duplicate(true)
	if bool(chest.get("open", false)):
		return false
	chest["open"] = true
	pile[top_i] = chest
	_combat_chests[key] = pile
	if _combat_map != null:
		_rebuild()
	return true


func take_combat_chest_loot(pos: Vector2i) -> Dictionary:
	## Pop the top chest's next item. Remove that chest with its final item.
	var key := _combat_chest_key(pos.x, pos.y)
	var pile := _combat_chest_pile_at(pos)
	if pile.is_empty():
		return {}
	var top_i := pile.size() - 1
	var chest_raw: Variant = pile[top_i]
	if typeof(chest_raw) != TYPE_DICTIONARY:
		return {}
	var chest: Dictionary = (chest_raw as Dictionary).duplicate(true)
	if not bool(chest.get("open", false)):
		return {}
	var stack: Array = []
	var raw: Variant = chest.get("stack", [])
	if typeof(raw) == TYPE_ARRAY:
		stack = (raw as Array).duplicate(true)
	if stack.is_empty():
		return {}
	var entry: Variant = stack.pop_front()
	if stack.is_empty():
		pile.pop_back()
		if pile.is_empty():
			_combat_chests.erase(key)
		else:
			_combat_chests[key] = pile
	else:
		chest["stack"] = stack
		pile[top_i] = chest
		_combat_chests[key] = pile
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


func await_combat_projectile(
	from: Vector2i, to: Vector2i, weapon_id: int = -1, missile_tid: int = -1
) -> void:
	## Cannon-style flight in combat-local coords (straight line, any angle).
	## Stops on the first wall/mast unless weapon attacks through objects (Halberd).
	## `weapon_id` selects a custom missile sprite (sling / dagger / arrow / magic axe).
	## `missile_tid` — creature/ranged shape override (fields, rocks, magic sphere…).
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
	## Apple II tilesets: classic shape tiles (77 red orb / 78 magic sphere).
	## New Color keeps the unique weapon PNGs.
	if not GraphicsSettings.is_apple2_tileset(GraphicsSettings.tileset_id()):
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
				custom_img = _spin_missile_frame(
					_magic_axe_missile_img, 0.0, _magic_axe_rot_cache
				)
	var fly_tid := missile_tid
	if fly_tid < 0:
		if weapon_id == _WeaponIconsScript.Id.MAGIC_WAND:
			fly_tid = TILE_MAGIC_FLASH
		else:
			fly_tid = TILE_MISS_FLASH
	var spin_per_tile := MAGIC_AXE_SPIN_PER_TILE
	var spin_base: Image = _magic_axe_missile_img if spinning else null
	var spin_cache: Dictionary = _magic_axe_rot_cache if spinning else {}
	if not spinning and fly_tid == TILE_WHIRLPOOL:
		var whirl := _overlay_slice(TILE_WHIRLPOOL)
		if _U4TileBankScript.uses_hgr_ntsc():
			whirl = _key_black_plate(whirl)
		if whirl != null and not whirl.is_empty():
			spinning = true
			spin_base = whirl
			spin_cache = _whirlpool_rot_cache
			spin_per_tile = WHIRLPOOL_SPIN_PER_TILE
			custom_img = _spin_missile_frame(whirl, 0.0, _whirlpool_rot_cache)
	var trail_on := weapon_id == _WeaponIconsScript.Id.MAGIC_BOW and custom_img != null
	var returning := weapon_id == _WeaponIconsScript.Id.MAGIC_AXE
	_combat_proj = {
		"x": start.x,
		"y": start.y,
		"wid": weapon_id,
		"img": custom_img,
		"miss_tid": fly_tid,
		"trail": [] as Array,
		"trail_on": trail_on,
		"trail_last": start if trail_on else Vector2.ZERO,
		"spin": spinning,
		"spin_base": spin_base,
		"spin_cache": spin_cache,
		"spin_per_tile": spin_per_tile,
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
			base,
			traveled * float(_combat_proj.get("spin_per_tile", MAGIC_AXE_SPIN_PER_TILE)),
			cache
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


func combat_focus_would_flee(dir: Vector2i) -> bool:
	## True if this step would leave the arena (OOB flee), without moving.
	if _combat_map == null or _combat_focus < 0 or _combat_focus >= _combat_party.size():
		return false
	if dir == Vector2i.ZERO or (dir.x != 0 and dir.y != 0):
		return false
	var u: Dictionary = _combat_party[_combat_focus]
	var dest := Vector2i(int(u.get("x", 0)), int(u.get("y", 0))) + dir
	return not _combat_in_bounds(dest)


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
		_drop_combat_party_anim_at(_combat_focus)
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


func combat_focus_can_step(dir: Vector2i) -> bool:
	## Auto-combat peek: ortho step that stays on the arena (never flee).
	if _combat_map == null or _combat_focus < 0 or _combat_focus >= _combat_party.size():
		return false
	if dir == Vector2i.ZERO or (dir.x != 0 and dir.y != 0):
		return false
	var u: Dictionary = _combat_party[_combat_focus]
	var from := Vector2i(int(u.get("x", 0)), int(u.get("y", 0)))
	var dest := from + dir
	if not _combat_in_bounds(dest):
		return false
	if not _combat_can_walk(from, dest, dir):
		return false
	if _combat_occupied(dest, _combat_focus, -1):
		return false
	var dest_tid := int(_combat_map.tile_at(dest.x, dest.y))
	if _TileRulesCamp.slowed_by_tile(dest_tid):
		return false
	return true


func combat_auto_step_dir(target: Vector2i) -> Vector2i:
	## One NESW step along the shortest open route toward `target`.
	## The foe occupies the target tile, so route to any adjacent strike tile.
	if _combat_map == null or _combat_focus < 0 or _combat_focus >= _combat_party.size():
		return Vector2i.ZERO
	var u: Dictionary = _combat_party[_combat_focus]
	var from := Vector2i(int(u.get("x", 0)), int(u.get("y", 0)))
	if not _combat_in_bounds(target) or from == target:
		return Vector2i.ZERO
	var visited := PackedByteArray()
	visited.resize(CAMP_W * CAMP_H)
	var q: Array[Vector2i] = [from]
	var first_steps: Array[Vector2i] = [Vector2i.ZERO]
	visited[from.y * CAMP_W + from.x] = 1
	var qi := 0
	while qi < q.size():
		var cur: Vector2i = q[qi]
		var first: Vector2i = first_steps[qi]
		qi += 1
		if cur != from and maxi(absi(cur.x - target.x), absi(cur.y - target.y)) <= 1:
			return first
		for d in _combat_auto_route_dirs(cur, target):
			var dest := cur + d
			if not _combat_in_bounds(dest):
				continue
			var di := dest.y * CAMP_W + dest.x
			if visited[di] != 0:
				continue
			if not _combat_can_walk(cur, dest, d):
				continue
			if cur == from:
				## This turn's actual step must be empty.
				if _combat_occupied(dest, _combat_focus, -1):
					continue
			elif combat_foe_index_at(dest) >= 0:
				## Party members farther along the route are mobile. Treating
				## them as permanent walls stops units from following a column.
				continue
			visited[di] = 1
			q.append(dest)
			first_steps.append(d if cur == from else first)
	return Vector2i.ZERO


func _combat_auto_route_dirs(from: Vector2i, target: Vector2i) -> Array[Vector2i]:
	## Preserve direct-looking movement among equally short BFS routes.
	var out: Array[Vector2i] = []
	var dx := target.x - from.x
	var dy := target.y - from.y
	var horiz := Vector2i(signi(dx), 0) if dx != 0 else Vector2i.ZERO
	var vert := Vector2i(0, signi(dy)) if dy != 0 else Vector2i.ZERO
	if absi(dx) >= absi(dy):
		if horiz != Vector2i.ZERO:
			out.append(horiz)
		if vert != Vector2i.ZERO:
			out.append(vert)
	else:
		if vert != Vector2i.ZERO:
			out.append(vert)
		if horiz != Vector2i.ZERO:
			out.append(horiz)
	for d in _DIRS_COMBAT:
		if not out.has(d):
			out.append(d)
	return out


func has_combat_foe_adjacent_to_focus() -> bool:
	## Context-command palette: Attack appears only for a living foe one step away.
	if _combat_focus < 0 or _combat_focus >= _combat_party.size():
		return false
	var unit: Dictionary = _combat_party[_combat_focus]
	var from := Vector2i(int(unit.get("x", 0)), int(unit.get("y", 0)))
	for foe in _combat_foes:
		var f: Dictionary = foe
		if int(f.get("hp", 0)) <= 0:
			continue
		var pos := Vector2i(int(f.get("x", 0)), int(f.get("y", 0)))
		if abs(pos.x - from.x) + abs(pos.y - from.y) == 1:
			return true
	return false


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
		"foe_i": -1,
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
	var base_hp := maxi(1, _WorldCreaturesScript.base_hp_for(tid))
	out["from"] = from
	out["tile"] = tid
	out["base_hp"] = base_hp
	## xu4: Zorn refreshes Negate (2 turns) and still takes its action.
	if _WorldCreaturesScript.negates(tid):
		GameState.set_aura(GameState.AuraType.NEGATE, _WorldCreaturesScript.ZORN_NEGATE_TURNS)
	## xu4: creatures who teleport do so 1/8 of the time (before ranged / sleep).
	if _WorldCreaturesScript.teleports(tid) and (randi() % 8) == 0:
		var dest := _combat_try_teleport(index, from)
		if dest != from:
			out["action"] = "teleport"
			out["to"] = dest
			return out
	## Free-aim ranged: on row/col/exact-diagonal → always shoot if LOF.
	## Off-axis free aim → 40% shoot, 60% advance (keeps melee party in play).
	if _WorldCreaturesScript.is_ranged(tid):
		var ranged := _combat_pick_ranged_target(from, index)
		if int(ranged.get("party_i", -1)) >= 0 or int(ranged.get("foe_i", -1)) >= 0:
			var aligned := _combat_is_axis_or_diagonal(from, ranged.pos)
			if aligned or (randi() % 100) < 40:
				var shot := _WorldCreaturesScript.resolve_ranged_shot(tid)
				## DOS: magic-sphere bolts (TIL_4E) are skipped while Negate lasts.
				var magic_bolt := (
					int(shot.get("miss_tid", -1)) == _WorldCreaturesScript.TILE_MAGIC_FLASH
				)
				if not (GameState.is_aura_negate() and magic_bolt):
					out["action"] = "ranged"
					out["to"] = ranged.pos
					out["party_i"] = ranged.party_i
					out["foe_i"] = int(ranged.get("foe_i", -1))
					out["klass"] = ranged.klass
					out["effect"] = str(shot.get("effect", "damage"))
					out["miss_tid"] = int(shot.get("miss_tid", _WorldCreaturesScript.TILE_MISS_FLASH))
					out["hit_tid"] = int(shot.get("hit_tid", _WorldCreaturesScript.TILE_HIT_FLASH))
					out["leave_tid"] = int(shot.get("leave_tid", -1))
					return out
			## 60% off-axis: skip the shot and fall through to advance.
	## 1/4: cast sleep (Reaper / Balron) when not ranging. Negate blocks this.
	if (
		_WorldCreaturesScript.casts_sleep(tid)
		and not GameState.is_aura_negate()
		and (randi() % 4) == 0
	):
		out["action"] = "cast_sleep"
		return out
	## Low HP — flee toward map edge (xu4 MSTAT_FLEEING, all species).
	## Remake Undead: turned undead flee the same way without an HP drop.
	## xu4 moveCombatObject: fixed objects cannot move (or flee).
	if (
		not _WorldCreaturesScript.is_stationary(tid)
		and (_WorldCreaturesScript.is_fleeing_hp(hp) or is_combat_foe_turned(index))
	):
		var away := _nearest_combat_opponent_info(from, index, false)
		if int(away.get("dist", 1_000_000)) >= 1_000_000:
			return out
		return _combat_apply_flee_step(index, from, away.pos, out)
	## Default: melee at Chebyshev 1 (8-adjacent, same as party), else advance.
	var near := _nearest_combat_opponent_info(from, index, true)
	if int(near.get("party_i", -1)) < 0 and int(near.get("foe_i", -1)) < 0:
		return out
	if _WeaponIconsScript.chebyshev(from, near.pos) == 1:
		out["action"] = "melee"
		out["to"] = near.pos
		out["party_i"] = near.party_i
		out["foe_i"] = int(near.get("foe_i", -1))
		out["klass"] = near.klass
		return out
	if _WorldCreaturesScript.is_stationary(tid):
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
	if _WorldCreaturesScript.is_stationary(int(foe.get("tile", 0))):
		return false
	var from := Vector2i(int(foe.get("x", 0)), int(foe.get("y", 0)))
	var near := _nearest_combat_opponent_info(from, index, true)
	if int(near.get("party_i", -1)) < 0 and int(near.get("foe_i", -1)) < 0:
		return false
	return _combat_apply_advance_step(index, from, near.pos)


func _combat_pick_ranged_target(from: Vector2i, skip_foe: int = -1) -> Dictionary:
	## Player-style free aim: living party (and other foes under Jinx) with LOF.
	var best := {
		"party_i": -1, "foe_i": -1, "klass": -1, "pos": Vector2i(-1, -1), "dist": 1_000_000
	}
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
			best = {"party_i": i, "foe_i": -1, "klass": klass, "pos": pos, "dist": dist}
	if GameState.is_aura_jinx():
		for i in _combat_foes.size():
			if i == skip_foe:
				continue
			var f: Dictionary = _combat_foes[i]
			if int(f.get("hp", 1)) <= 0:
				continue
			var pos := Vector2i(int(f.get("x", 0)), int(f.get("y", 0)))
			if pos == from:
				continue
			var dist := _WeaponIconsScript.aim_distance(from, pos)
			if dist < 1 or dist > _WorldCreaturesScript.COMBAT_RANGED_RANGE:
				continue
			if not combat_shot_reaches(from, pos):
				continue
			var better_foe := dist < int(best.dist)
			if dist == int(best.dist) and (randi() % 2) == 0:
				better_foe = true
			if better_foe:
				best = {"party_i": -1, "foe_i": i, "klass": -1, "pos": pos, "dist": dist}
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
	var mover_tile := _combat_foe_tile(skip_foe)
	var out: Array[Vector2i] = []
	for d in _combat_advance_dirs(from):
		var dest := from + d
		if not _combat_in_bounds(dest):
			continue
		if not _combat_can_walk(from, dest, d, mover_tile):
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
	var mover_tile := _combat_foe_tile(skip_foe)
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
				if not _combat_terrain_ok_for_mover(n_tid, mover_tile):
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


func _combat_flee_cell_walkable(pos: Vector2i, mover_tile: int = -1) -> bool:
	## Static walkability for BFS (mobility matches species: land / swim / sail / fly).
	if _combat_map == null or not _combat_in_bounds(pos):
		return false
	var tid := int(_combat_map.tile_at(pos.x, pos.y))
	return _combat_terrain_ok_for_mover(tid, mover_tile)


func _combat_flee_cell_passable(pos: Vector2i, skip_foe: int) -> bool:
	## Walkable and not occupied (self `skip_foe` ignored).
	var mover_tile := _combat_foe_tile(skip_foe)
	return (
		_combat_flee_cell_walkable(pos, mover_tile)
		and not _combat_occupied(pos, -1, skip_foe)
	)


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
	var mover_tile := _combat_foe_tile(index)
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
		if not _combat_can_walk(from, dest, d, mover_tile):
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
		var mover_tile := _combat_foe_tile(index)
		for d in _DIRS_COMBAT:
			var dest := from + d
			if not _combat_in_bounds(dest):
				if land_only2 or not shore or not on_deck:
					best_dest = dest
					leaves = true
					nudge.clear()
					break
				continue
			if not _combat_can_walk(from, dest, d, mover_tile):
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


func _nearest_combat_opponent_info(from: Vector2i, skip_foe: int, use_chebyshev: bool) -> Dictionary:
	## xu4 Creature::nearestOpponent. Party is always valid; under Jinx, so are other foes.
	var best := {
		"party_i": -1, "foe_i": -1, "klass": -1, "pos": Vector2i(-1, -1), "dist": 1_000_000
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
			best = {"party_i": i, "foe_i": -1, "klass": klass, "pos": pos, "dist": d}
	if GameState.is_aura_jinx():
		for i in _combat_foes.size():
			if i == skip_foe:
				continue
			var f: Dictionary = _combat_foes[i]
			if int(f.get("hp", 1)) <= 0:
				continue
			var pos := Vector2i(int(f.get("x", 0)), int(f.get("y", 0)))
			var d := (
				_WeaponIconsScript.chebyshev(from, pos)
				if use_chebyshev
				else _combat_manhattan(from, pos)
			)
			var better_foe := d < int(best.dist)
			if d == int(best.dist) and (randi() % 2) == 0:
				better_foe = true
			if better_foe:
				best = {"party_i": -1, "foe_i": i, "klass": -1, "pos": pos, "dist": d}
	return best


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


func _combat_foe_tile(index: int) -> int:
	if index < 0 or index >= _combat_foes.size():
		return -1
	return int(_combat_foes[index].get("tile", 0))


func _combat_try_teleport(index: int, from: Vector2i) -> Vector2i:
	## xu4 CA_TELEPORT — random creature-walkable cell; skip a slow tile once.
	if _combat_map == null or index < 0 or index >= _combat_foes.size():
		return from
	var first_try := true
	var guard := CAMP_W * CAMP_H * 3
	while guard > 0:
		guard -= 1
		var dest := Vector2i(randi() % CAMP_W, randi() % CAMP_H)
		if dest == from or _combat_occupied(dest, -1, index):
			continue
		var dest_tid := int(_combat_map.tile_at(dest.x, dest.y))
		if not _TileRulesCamp.is_creature_walkable(dest_tid):
			continue
		if first_try and _TileRulesCamp.speed_of(dest_tid) != _TileRulesCamp.Speed.FAST:
			first_try = false
			continue
		var foe: Dictionary = _combat_foes[index]
		foe["x"] = dest.x
		foe["y"] = dest.y
		_combat_foes[index] = foe
		_rebuild()
		return dest
	return from


func _combat_flyer_can_enter(dest_tid: int) -> bool:
	## xu4 combat/town flyers: flyable and (walkable or water). World map is open.
	if not _TileRulesCamp.is_flyable(dest_tid):
		return false
	return (
		_TileRulesCamp.is_walkable(dest_tid)
		or _TileRulesCamp.is_swimable(dest_tid)
		or _TileRulesCamp.is_sailable(dest_tid)
	)


func _combat_terrain_ok_for_mover(dest_tid: int, mover_tile: int) -> bool:
	## Wilderness-style mobility on combat tiles (xu4 Map::getValidMoves).
	if mover_tile < 0:
		return _TileRulesCamp.is_creature_walkable(dest_tid)
	if _WorldCreaturesScript.is_flyer(mover_tile):
		return _combat_flyer_can_enter(dest_tid)
	if _WorldCreaturesScript.is_sailor(mover_tile):
		return _TileRulesCamp.is_sailable(dest_tid)
	if _WorldCreaturesScript.is_swimmer(mover_tile):
		return _TileRulesCamp.is_swimable(dest_tid)
	if _WorldCreaturesScript.is_incorporeal(mover_tile):
		return not _TileRulesCamp.is_water(dest_tid)
	return _TileRulesCamp.is_creature_walkable(dest_tid)


func _combat_can_walk(
	from: Vector2i, dest: Vector2i, dir: Vector2i, mover_tile: int = -1
) -> bool:
	## Party (default) uses walkon + walkoff + creatureWalkable.
	## Foes pass their tile: swim / sail / fly / incorporeal match wilderness.
	if _combat_map == null:
		return false
	var from_tid := int(_combat_map.tile_at(from.x, from.y))
	var dest_tid := int(_combat_map.tile_at(dest.x, dest.y))
	if mover_tile >= 0:
		if _WorldCreaturesScript.is_flyer(mover_tile):
			return _combat_flyer_can_enter(dest_tid)
		if _WorldCreaturesScript.is_sailor(mover_tile):
			return _TileRulesCamp.is_sailable(dest_tid)
		if _WorldCreaturesScript.is_swimmer(mover_tile):
			return _TileRulesCamp.is_swimable(dest_tid)
		if _WorldCreaturesScript.is_incorporeal(mover_tile):
			return not _TileRulesCamp.is_water(dest_tid)
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
	## Orthogonal or diagonal neighbor (8-way step) — balloon diagonal wind drift.
	var cheby := maxi(absi(step.x), absi(step.y))
	var can_scroll := (
		SMOOTH_SCROLL
		and animate
		and cheby == 1
		and (is_in_city() or (world != null and world.loaded))
		## Apple II Color NTSC decodes the +1 scroll fringe in the same HGR row,
		## so dest walls leak before the offset (and a city pops when leaving).
		and not GraphicsSettings.is_apple2_tileset(GraphicsSettings.tileset_id())
	)
	if animate and cheby == 1:
		_note_horse_step()
	if can_scroll:
		_scroll_from = center
		_scroll_dir = step
		_scroll_frames_left = _scroll_step_count()
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
	if _los.is_empty() or _los_w < 1 or _los_h < 1:
		return true
	var half_x := _los_w / 2
	var half_y := _los_h / 2
	var vx := wx - center.x + half_x
	var vy := wy - center.y + half_y
	if vx < 0 or vy < 0 or vx >= _los_w or vy >= _los_h:
		return false
	return _los[vy * _los_w + vx] != 0


func _los_grid_size() -> Vector2i:
	## Pad viewport by LOS_PAD so scroll stage (view+1) fringe has LOS coverage.
	return Vector2i(view_w + LOS_PAD * 2, view_h + LOS_PAD * 2)


func session_tile_at(tile: Vector2i) -> int:
	if not _session_tiles.has(tile):
		return -1
	return int(_session_tiles[tile])


func set_session_tile(tile: Vector2i, tile_id: int) -> void:
	_session_tiles[tile] = tile_id
	_rebuild()


func clear_session_tiles() -> void:
	if _session_tiles.is_empty():
		return
	_session_tiles.clear()
	_rebuild()


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


func peer_moongate() -> Vector3i:
	## Visible moongate as (x, y, tid). z = -1 if none or fully sunk.
	if _moongate_tid < 0:
		return Vector3i(0, 0, -1)
	if _moongate_height_px <= 0 and _moongate_height_px_target <= 0:
		return Vector3i(0, 0, -1)
	return Vector3i(_moongate_pos.x, _moongate_pos.y, _moongate_tid)


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
	var was_horse := is_horse_tile(_transport_tile)
	_transport_tile = tile_id
	if is_horse_tile(tile_id) and not was_horse:
		_reset_horse_stand()
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
	_shake_quake = false
	_quake_ox = 0
	_quake_bursts.clear()
	_shake_dur = maxf(duration, 0.05)
	_shake_left = _shake_dur
	_shake_amp = maxf(amplitude, 0.5)
	_rebuild()


func shake_quake(amplitude: float = 16.0) -> float:
	## 2–3 irregular left/right jolts, half-tile max, short still gaps between.
	AudioSfx.play_rumble()
	_shake_quake = true
	_shake_amp = clampf(amplitude, 4.0, float(TILE_SRC) * 0.5)
	_quake_ox = 0
	_quake_jolt_cd = 0.0
	_quake_bursts.clear()
	var n := 2 + (randi() % 2)
	var gap := 0.14 + randf() * 0.10
	var t := 0.0
	for i in n:
		var blen := 0.26 + randf() * 0.22
		_quake_bursts.append({ "start": t, "end": t + blen })
		t += blen
		if i < n - 1:
			t += gap
	_shake_dur = t
	_shake_left = t
	_rebuild()
	return t


func _quake_in_burst() -> bool:
	if _quake_bursts.is_empty() or _shake_dur <= 0.0:
		return false
	var elapsed := _shake_dur - _shake_left
	for b in _quake_bursts:
		if elapsed >= float(b.start) and elapsed < float(b.end):
			return true
	return false


func _tick_quake_jolt(delta: float) -> void:
	if not _quake_in_burst():
		_quake_ox = 0
		_quake_jolt_cd = 0.0
		return
	_quake_jolt_cd -= delta
	if _quake_jolt_cd > 0.0:
		return
	_quake_jolt_cd = 0.04 + randf() * 0.07
	var span := maxi(1, int(round(_shake_amp)))
	var mag := randi() % (span + 1)
	var dir := -1 if (randi() % 2) == 0 else 1
	if _quake_ox != 0 and (randi() % 3) != 0:
		dir = -1 if _quake_ox > 0 else 1
	_quake_ox = dir * mag


func _shake_offset() -> Vector2i:
	if _shake_left <= 0.0:
		return Vector2i.ZERO
	if _shake_quake:
		return Vector2i(_quake_ox, 0)
	var fall := clampf(_shake_left / _shake_dur, 0.0, 1.0)
	## Soft decaying nudge — mostly horizontal, 1–2 px feel.
	var ox := int(round(sin(_shake_left * 38.0) * _shake_amp * fall))
	var oy := int(round(cos(_shake_left * 29.0) * _shake_amp * 0.25 * fall))
	return Vector2i(ox, oy)


func _apply_view_shake() -> void:
	## Shift the finished explore/dungeon frame so terrain and sprites quake together.
	var shake := _shake_offset()
	if shake.x == 0 and shake.y == 0:
		return
	var w := _buf.get_width()
	var h := _buf.get_height()
	var copy := _buf.duplicate()
	_buf.fill(Color(0, 0, 0, 1))
	_buf.blit_rect(copy, Rect2i(0, 0, w, h), shake)


func _tile_px(sx: int, sy: int) -> Vector2i:
	return Vector2i(sx * TILE_SRC, sy * TILE_SRC) + _shake_offset()


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


static func is_balloon_tile(tile_id: int) -> bool:
	return tile_id == TILE_BALLOON


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


func _cloud_shadow_wanted() -> bool:
	## Outdoor explore / town. Stay up during a wipe into those views.
	## Dungeon, camp, and combat stay clear (including their enter wipe).
	if not tiles_ready:
		return false
	if _combat_map != null or _camp_map != null or is_in_dungeon():
		return false
	return is_in_city() or (world != null and world.loaded) or _weather_cam_held


func _hold_weather_cam() -> void:
	## Freeze clouds, rain, and the hide mask for the whole enter wipe.
	## Otherwise apply() rebuilds city indoor/LOS and the overlay goes clear
	## (bright, no rain) until the destination map finishes wiping in.
	_weather_cam_hold = _cam_tile()
	_weather_party_hold = Vector2(center)
	_weather_cam_held = true


func _release_weather_cam() -> void:
	_weather_cam_held = false
	_refresh_weather_hide_mask()


func _weather_sample_cam() -> Vector2:
	if _weather_cam_held:
		return _weather_cam_hold
	## Current map tile (world or city-local). A frozen town world-pos makes
	## clouds sit in screen space and follow the avatar.
	return _cam_tile()


func _weather_cover_cam() -> Vector2:
	## Storm wash uses the Britannia tile the town sits on, so the city stays
	## as dark as the world outside. Discrete clouds still follow `_cam_tile()`.
	if _weather_cam_held:
		return _weather_cam_hold
	if is_in_city() and _city_world_pos.x >= 0:
		return Vector2(_city_world_pos)
	return _cam_tile()


func _ensure_hide_tex(w: int, h: int) -> void:
	if _hide_img == null or _hide_img.get_width() != w or _hide_img.get_height() != h:
		_hide_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
		_hide_img.fill(Color(0, 0, 0, 1))
		_indoor_tex = ImageTexture.create_from_image(_hide_img)
		if _cloud_overlay != null:
			_cloud_overlay.texture = _indoor_tex
	elif _indoor_tex == null:
		_indoor_tex = ImageTexture.create_from_image(_hide_img)


func _sync_indoor_bits() -> void:
	if not is_in_city():
		if _indoor_key != "":
			_indoor_key = ""
			_indoor_bits = PackedByteArray()
		return
	var key := str(_city_map.source_path)
	if key == _indoor_key:
		return
	_indoor_key = key
	_indoor_bits = _CityIndoor.mask_for(key)


func _refresh_weather_hide_mask() -> void:
	if _weather_cam_held:
		return
	var dim := _los_grid_size()
	var w: int = _los_w if _los_w > 0 else dim.x
	var h: int = _los_h if _los_h > 0 else dim.y
	_ensure_hide_tex(w, h)
	_sync_indoor_bits()
	var half_x := w / 2
	var half_y := h / 2
	var los_ok := los_enabled and _los.size() == w * h
	var indoor_ok := is_in_city() and _indoor_bits.size() >= _CityIndoor.TILE_COUNT
	var hide_c := Color(1, 1, 1, 1)
	var show_c := Color(0, 0, 0, 1)
	for vy in h:
		for vx in w:
			var hide := false
			if los_ok and _los[vy * w + vx] == 0:
				hide = true
			elif indoor_ok:
				var mx := center.x - half_x + vx
				var my := center.y - half_y + vy
				if mx >= 0 and my >= 0 and mx < _CityIndoor.WIDTH and my < _CityIndoor.HEIGHT:
					hide = _indoor_bits[my * _CityIndoor.WIDTH + mx] != 0
			_hide_img.set_pixel(vx, vy, hide_c if hide else show_c)
	_indoor_tex.update(_hide_img)


func _ensure_cloud_overlay() -> void:
	if _cloud_overlay != null:
		return
	_cloud_mat = ShaderMaterial.new()
	_cloud_mat.shader = _CloudShadowShader
	var dim := _los_grid_size()
	_ensure_hide_tex(dim.x, dim.y)
	_cloud_overlay = TextureRect.new()
	_cloud_overlay.name = "CloudShadow"
	_cloud_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cloud_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cloud_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cloud_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	_cloud_overlay.texture = _indoor_tex
	_cloud_overlay.material = _cloud_mat
	_cloud_overlay.modulate = Color.WHITE
	_cloud_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_cloud_overlay)


func _sync_cloud_shadow() -> void:
	_ensure_cloud_overlay()
	var wanted := _cloud_shadow_wanted()
	_cloud_overlay.visible = wanted
	if not wanted or _cloud_mat == null:
		return
	_cloud_mat.set_shader_parameter("cam_tile", _weather_sample_cam())
	_cloud_mat.set_shader_parameter("cover_cam", _weather_cover_cam())
	_cloud_mat.set_shader_parameter("view_tiles", Vector2(float(view_w), float(view_h)))
	_cloud_mat.set_shader_parameter("cloud_period", _Weather.PERIOD)
	var blobs: Array = _Weather.shader_blobs(GameState)
	var shapes: Array = _Weather.shader_shapes(GameState)
	var packed_a := PackedVector4Array()
	var packed_b := PackedVector4Array()
	var count := 0
	for i in blobs.size():
		var blob: Vector4 = blobs[i]
		packed_a.append(blob)
		packed_b.append(shapes[i] if i < shapes.size() else Vector4.ZERO)
		if blob.w > 0.001:
			count += 1
	_cloud_mat.set_shader_parameter("clouds_a", packed_a)
	_cloud_mat.set_shader_parameter("clouds_b", packed_b)
	_cloud_mat.set_shader_parameter("cloud_count", count)
	_cloud_mat.set_shader_parameter("overcast", GameState.rain_overcast)
	_cloud_mat.set_shader_parameter("dim", GameState.rain_dim)
	var wind: Vector2 = GameState.cloud_vel
	if wind.length_squared() < 0.0001:
		wind = Vector2(0.0, 1.0)
	_cloud_mat.set_shader_parameter("rain_wind", Vector2(wind.normalized().x * 0.38, 1.0))
	_cloud_mat.set_shader_parameter("rain_amt", GameState.rain_amt)
	var rain_col := Color(0.86, 0.90, 0.96)
	if GraphicsSettings.tileset_id() == _U4TileBankScript.SET_APPLE2_MONO_GREEN:
		rain_col = Color(
			float(_U4TileBankScript.MONO_GREEN_R) / 255.0,
			float(_U4TileBankScript.MONO_GREEN_G) / 255.0,
			float(_U4TileBankScript.MONO_GREEN_B) / 255.0
		)
	_cloud_mat.set_shader_parameter("rain_col", Vector3(rain_col.r, rain_col.g, rain_col.b))
	var weather_cam := _weather_sample_cam()
	_cloud_mat.set_shader_parameter("rain_cam", weather_cam)
	if _weather_cam_held:
		_cloud_mat.set_shader_parameter("party_tile", _weather_party_hold)
	else:
		_cloud_mat.set_shader_parameter("party_tile", Vector2(center))
		_refresh_weather_hide_mask()
	_cloud_mat.set_shader_parameter("hide_edge", 1.0 if los_enabled else 0.0)


func _process(delta: float) -> void:
	_sync_cloud_shadow()
	## Freeze animation rebuilds during the enter-combat wipe.
	if _scene_trans_busy:
		return
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

	var horse_changed := _tick_horse_idle(delta)

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
		## Apple II Color/Mono keep their static source tile.
		if _moongate_height_px > 0 and _U4TileBankScript.uses_moongate_suck():
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

	var combat_anim_changed := false
	if _combat_map != null:
		combat_anim_changed = _tick_combat_anim_frames(delta)

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
		if _shake_quake:
			_tick_quake_jolt(delta)
		if _shake_left <= 0.0:
			_quake_ox = 0
			_shake_quake = false
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
				or combat_anim_changed
				or combat_focus_changed
				or shake_changed or moongate_changed or flash_changed
				or horse_changed
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
		or combat_anim_changed
		or combat_focus_changed
		or shake_changed or moongate_changed or flash_changed
		or horse_changed
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


func _clear_combat_anim_frames() -> void:
	_combat_party_frame_bit.clear()
	_combat_party_frame_cd.clear()
	_combat_foe_anim_tick.clear()
	_combat_foe_anim_cd.clear()


func _init_combat_anim_frames() -> void:
	## Independent timers per combatant — guards no longer flip in lockstep.
	_clear_combat_anim_frames()
	for _i in _combat_party.size():
		_combat_party_frame_bit.append(randi() & 1)
		_combat_party_frame_cd.append(randf_range(0.0, COMBAT_FRAME_MAX))
	for _j in _combat_foes.size():
		_combat_foe_anim_tick.append(randi() & 3)
		_combat_foe_anim_cd.append(randf_range(0.0, COMBAT_FRAME_MAX))


func _drop_combat_party_anim_at(index: int) -> void:
	if index < 0 or index >= _combat_party_frame_cd.size():
		return
	_combat_party_frame_bit.remove_at(index)
	_combat_party_frame_cd.remove_at(index)


func _combat_party_frame_bit_at(index: int) -> int:
	if index < 0 or index >= _combat_party_frame_bit.size():
		return _avatar_frame
	return int(_combat_party_frame_bit[index])


func _combat_foe_anim_tick_at(index: int) -> int:
	if index < 0 or index >= _combat_foe_anim_tick.size():
		return _tile_anim_frame
	return int(_combat_foe_anim_tick[index])


func _tick_combat_anim_frames(delta: float) -> bool:
	var changed := false
	for i in _combat_party_frame_cd.size():
		_combat_party_frame_cd[i] -= delta
		if _combat_party_frame_cd[i] > 0.0:
			continue
		_combat_party_frame_bit[i] = 1 - _combat_party_frame_bit[i]
		_combat_party_frame_cd[i] = randf_range(COMBAT_FRAME_MIN, COMBAT_FRAME_MAX)
		changed = true
	for j in _combat_foe_anim_cd.size():
		_combat_foe_anim_cd[j] -= delta
		if _combat_foe_anim_cd[j] > 0.0:
			continue
		_combat_foe_anim_tick[j] = int(_combat_foe_anim_tick[j]) + 1
		_combat_foe_anim_cd[j] = randf_range(COMBAT_FRAME_MIN, COMBAT_FRAME_MAX)
		if j >= _combat_foes.size():
			continue
		var f: Dictionary = _combat_foes[j]
		if int(f.get("hp", 1)) <= 0 or bool(f.get("asleep", false)):
			continue
		changed = true
	return changed


func _load_image_path(path: String) -> Image:
	return _ResImage.load_rgba8(path)


func _key_black_plate(src: Image) -> Image:
	## Opaque black margins → transparent (thrown rocks, keyed sprites).
	if src == null or src.is_empty():
		return null
	var tw := src.get_width()
	var th := src.get_height()
	var img := Image.create(tw, th, false, Image.FORMAT_RGBA8)
	img.blit_rect(src, Rect2i(0, 0, tw, th), Vector2i.ZERO)
	for y in th:
		for x in tw:
			var c := img.get_pixel(x, y)
			if c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
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
	## New Color: class mount PNGs. Apple II: original horse + fixed rider stamp.
	var cls := GameState.party_leader_class()
	if (
		_horse_rider_w != null
		and _horse_rider_e != null
		and cls == _horse_rider_class
		and not _horse_rider_w_frames.is_empty()
		and not _horse_rider_e_frames.is_empty()
	):
		return
	_horse_rider_class = cls
	if GraphicsSettings.is_apple2_tileset(GraphicsSettings.tileset_id()):
		_horse_rider_w_frames = _apple2_fixed_horse_frames(TILE_HORSE_W)
		_horse_rider_e_frames = _apple2_fixed_horse_frames(TILE_HORSE_E)
	else:
		var class_w := _load_class_horse_rider_frames(true, cls)
		var class_e := _load_class_horse_rider_frames(false, cls)
		if not class_w.is_empty() and not class_e.is_empty():
			_horse_rider_w_frames = class_w
			_horse_rider_e_frames = class_e
		else:
			_horse_rider_w_frames = _compose_horse_rider_frames(TILE_HORSE_W, _horse_rider_w_asset)
			_horse_rider_e_frames = _compose_horse_rider_frames(TILE_HORSE_E, _horse_rider_e_asset)
	_horse_rider_w = _horse_rider_frame_or(_horse_rider_w_frames, HORSE_STAND_FRAME, _horse_rider_w_asset)
	_horse_rider_e = _horse_rider_frame_or(_horse_rider_e_frames, HORSE_STAND_FRAME, _horse_rider_e_asset)


func _apple2_fixed_horse_frames(horse_id: int) -> Array:
	## Original SHP horse + fixed rider stamp. Last row sits on the back.
	var img := _apple2_compose_mount(horse_id)
	if img == null or img.is_empty():
		return [_U4TileBankScript.keyed_copy(horse_id, 0)]
	return [img]


func _apple2_compose_mount(horse_id: int) -> Image:
	## Color keeps the two delayed NTSC fringe columns; mono is a fixed 32px cell.
	var horse := (
		_Apple2HgrNtscScript.render_flying_tile(horse_id)
		if _U4TileBankScript.uses_hgr_ntsc()
		else _U4TileBankScript.keyed_copy(horse_id, 0)
	)
	if horse == null or horse.is_empty():
		return null
	var west := horse_id == TILE_HORSE_W
	var ref := _load_image_path(
		APPLE2_HORSE_MOUNT_W_PATH if west else APPLE2_HORSE_MOUNT_E_PATH
	)
	if ref == null or ref.is_empty():
		return horse
	var cells := _apple2_rider_stamp(west)
	var out := horse.duplicate()
	var mono := not _U4TileBankScript.uses_hgr_ntsc()
	var body := _apple2_horse_ink_color(horse) if mono else Color(1, 1, 1, 1)
	var dim := float(_Apple2ProgramDiskScript.MONO_DIM) / 255.0
	for p in cells:
		var ink := body if mono else ref.get_pixel(p.x, p.y)
		var dx := p.x * 2
		## One native Apple II pixel upward (one 16px source row = two output rows).
		var dy := p.y * 2 - 2
		## Keep the seated row at its old bottom edge so no gap opens above the horse.
		var draw_h := 4 if p.y == 5 else 2
		for py in draw_h:
			for px in 2:
				var x := dx + px
				var y := dy + py
				if x < 0 or y < 0 or x >= out.get_width() or y >= out.get_height():
					continue
				var c := ink
				if (y & 1) == 1:
					c = Color(c.r * dim, c.g * dim, c.b * dim, c.a)
				out.set_pixel(x, y, c)
	## Arm is inside the extended seated row, so apply it last:
	## left-facing purple at (7,6), right-facing green at (8,6).
	var arm := Vector2i(7, 6) if west else Vector2i(8, 6)
	var arm_ink := Color(0, 0, 0, 1) if mono else ref.get_pixel(arm.x, arm.y)
	var arm_dx := arm.x * 2
	var arm_dy := arm.y * 2 - 2
	for py in 2:
		for px in 2:
			var x := arm_dx + px
			var y := arm_dy + py
			if x < 0 or y < 0 or x >= out.get_width() or y >= out.get_height():
				continue
			var c := arm_ink
			if (y & 1) == 1:
				c = Color(c.r * dim, c.g * dim, c.b * dim, c.a)
			out.set_pixel(x, y, c)
	return out


func _apple2_rider_stamp(west: bool) -> Array[Vector2i]:
	## Exact person-only pixels from the supplied 16×16 W/E references.
	## The broad last row is the seated torso where it meets the original horse.
	var out: Array[Vector2i] = []
	if west:
		out.append_array([
			Vector2i(8, 1), Vector2i(9, 1),
			Vector2i(8, 2), Vector2i(9, 2),
			Vector2i(9, 3),
			Vector2i(8, 4), Vector2i(9, 4), Vector2i(10, 4),
			Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5),
			Vector2i(9, 5), Vector2i(10, 5),
		])
	else:
		out.append_array([
			Vector2i(6, 1), Vector2i(7, 1),
			Vector2i(6, 2), Vector2i(7, 2),
			Vector2i(6, 3),
			Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4),
			Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5),
			Vector2i(8, 5), Vector2i(9, 5),
		])
	return out


func _apple2_horse_ink_color(horse: Image) -> Color:
	## Brightest horse pixel so the rider matches white / green phosphor.
	var best := Color(1, 1, 1, 1)
	var best_l := -1.0
	for y in TILE_SRC:
		for x in TILE_SRC:
			var c := horse.get_pixel(x, y)
			if not _apple2_pixel_is_ink(c):
				continue
			var lum := c.r + c.g + c.b
			if lum > best_l:
				best_l = lum
				best = c
	return best


func _apple2_pixel_is_ink(c: Color) -> bool:
	return c.a > 0.5 and maxf(c.r, maxf(c.g, c.b)) > 0.12


func _horse_rider_class_path(west: bool, cls: int, frame: int) -> String:
	if cls < 0 or cls >= HORSE_RIDER_CLASS_SLUG.size():
		return ""
	var slug: String = HORSE_RIDER_CLASS_SLUG[cls]
	var side := "020_horse_west_" if west else "021_horse_east_"
	var suf := "" if frame <= 0 else ("_%d" % frame)
	return HORSE_RIDER_SHAPE_DIR + side + slug + suf + ".png"


func _load_class_horse_rider_frames(west: bool, cls: int) -> Array:
	## New Color only — Apple II uses the fixed mount silhouettes.
	if GraphicsSettings.is_apple2_tileset(GraphicsSettings.tileset_id()):
		return []
	var out: Array = []
	for i in 3:
		var path := _horse_rider_class_path(west, cls, i)
		if path.is_empty():
			return []
		var img := _load_image_path(path)
		if img == null or img.is_empty():
			return []
		if not _U4TileBankScript.keeps_opaque_black():
			img = _U4TileBankScript.key_border_black(img)
			if img == null or img.is_empty():
				return []
		out.append(img)
	return out


func _compose_horse_rider_frames(horse_id: int, fallback: Image) -> Array:
	var n := _U4TileBankScript.frame_count(horse_id)
	if n < 1:
		n = 1
	var out: Array = []
	for i in n:
		var img := _compose_horse_rider(horse_id, i)
		out.append(img if img != null else fallback)
	return out


func _compose_horse_rider(horse_id: int, frame: int = 0) -> Image:
	## Horse base + rider torso from the current party walker sprite.
	if not tiles_ready or _avatar_a == null or _avatar_a.is_empty():
		return null
	var horse := _U4TileBankScript.keyed_copy(horse_id, frame)
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


func _reset_horse_stand() -> void:
	_horse_standing = true
	_horse_idle_left = 0.0


func _note_horse_step() -> void:
	if not is_horse_tile(_transport_tile):
		return
	_horse_standing = false
	_horse_idle_left = HORSE_IDLE_STAND_SEC
	## Y-gallop walks two tiles in one keypress; keep A/B alternating per move.
	var f := Engine.get_process_frames()
	if _horse_step_process_frame == f:
		return
	_horse_step_process_frame = f
	_horse_walk_on_b = not _horse_walk_on_b


func _tick_horse_idle(delta: float) -> bool:
	if _horse_standing or not is_horse_tile(_transport_tile):
		return false
	if _scroll_frames_left > 0:
		return false
	_horse_idle_left -= delta
	if _horse_idle_left > 0.0:
		return false
	_reset_horse_stand()
	return true


func _horse_stand_frame_id(tile_id: int) -> int:
	var n := _U4TileBankScript.frame_count(tile_id)
	return HORSE_STAND_FRAME if n > HORSE_STAND_FRAME else 0


func _horse_pose_frame() -> int:
	var tid := _transport_tile if is_horse_tile(_transport_tile) else TILE_HORSE_W
	var n := _U4TileBankScript.frame_count(tid)
	if n <= 1:
		return 0
	var f := HORSE_STAND_FRAME
	if not _horse_standing:
		f = HORSE_WALK_FRAME_B if _horse_walk_on_b else HORSE_WALK_FRAME_A
	if f >= n:
		return 0
	return f


func _horse_rider_frame_or(frames: Array, frame: int, fallback: Image) -> Image:
	if frames.is_empty():
		return fallback
	var i := frame if frame >= 0 and frame < frames.size() else 0
	var img: Image = frames[i]
	return img if img != null else fallback


func _horse_rider_for_transport() -> Image:
	_ensure_horse_riders()
	var frames: Array = (
		_horse_rider_e_frames if _transport_tile == TILE_HORSE_E
		else _horse_rider_w_frames
	)
	var fallback := _horse_rider_e if _transport_tile == TILE_HORSE_E else _horse_rider_w
	return _horse_rider_frame_or(frames, _horse_pose_frame(), fallback)


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


func _upload_buffer() -> void:
	## Preserve the RenderingDevice texture RID after its first upload. Replacing
	## an in-use ImageTexture with set_image() can race Metal frame submission
	## during scene changes; update() only uploads pixels into the existing RID.
	if _tex == null or _tex.get_width() != _buf.get_width() or _tex.get_height() != _buf.get_height():
		_tex = ImageTexture.create_from_image(_buf)
	else:
		_tex.update(_buf)
	texture = _tex


func _cam_tile() -> Vector2:
	if _scroll_frames_left <= 0:
		return Vector2(center)
	## progress 0 at scroll start (frames==SCROLL_STEPS) … 1 after last step.
	## Stage always includes a +1 fringe so the entering edge is already painted.
	var n := float(_scroll_step_count())
	var progress := (n - float(_scroll_frames_left)) / n
	return Vector2(_scroll_from) + Vector2(_scroll_dir) * progress


func _scroll_step_count() -> int:
	## Apple II Color bakes scanlines; 3-step scroll lands on an odd pixel and
	## flips bright/dim rows. 8 steps stay on even offsets (4px).
	if GraphicsSettings.is_apple2_tileset(GraphicsSettings.tileset_id()):
		return 8
	return SCROLL_STEPS


func _torch_flicker_wanted() -> bool:
	## Physical torch only — Light (L) stays a steady glow.
	return (
		is_in_dungeon()
		and _combat_map == null
		and _camp_map == null
		and _dungeon_lit
		and not GameState.dungeon_light_is_magic
	)


func _sync_torch_flicker() -> void:
	if not _torch_flicker_wanted():
		if material != null:
			material = null
		return
	if _torch_flicker_mat == null:
		_torch_flicker_mat = ShaderMaterial.new()
		_torch_flicker_mat.shader = _TorchFlickerShader
	var buf_w := maxi(view_w * TILE_SRC, 1)
	var buf_h := maxi(view_h * TILE_SRC, 1)
	var ox := ((view_w - CAMP_W) / 2) * TILE_SRC
	var oy := ((view_h - CAMP_H) / 2) * TILE_SRC
	_torch_flicker_mat.set_shader_parameter(
		"field_uv",
		Vector4(
			float(ox) / float(buf_w),
			float(oy) / float(buf_h),
			float(CAMP_W * TILE_SRC) / float(buf_w),
			float(CAMP_H * TILE_SRC) / float(buf_h)
		)
	)
	if material != _torch_flicker_mat:
		material = _torch_flicker_mat


func _rebuild() -> void:
	if _scene_trans_busy:
		return
	_sync_torch_flicker()
	_ensure_buffers()
	_buf.fill(Color(0.05, 0.08, 0.07, 1))

	if not tiles_ready:
		_upload_buffer()
		queue_redraw()
		return

	if _combat_map != null:
		_rebuild_combat()
		return

	if _camp_map != null:
		_rebuild_camp()
		return

	if is_in_dungeon():
		_rebuild_dungeon()
		return

	if is_in_city():
		_rebuild_city()
		return

	if world == null or not world.loaded:
		_upload_buffer()
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
	if _U4TileBankScript.uses_hgr_ntsc():
		_apple2_fill_stage_world(base, half_x, half_y)
	else:
		for dy in view_h + 1:
			for dx in view_w + 1:
				var mx := base.x - half_x + dx
				var my := base.y - half_y + dy
				var tid := _world_display_tid(mx, my)
				var dst := Vector2i(dx * TILE_SRC, dy * TILE_SRC)
				_blit_terrain_to(_stage, tid, dst, mx, my)

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
	_apply_view_shake()

	_upload_buffer()
	queue_redraw()


func _rebuild_dungeon() -> void:
	## xu4 map window: paint only the center 11×11. No left/right margin work.
	_sync_torch_flicker()
	_buf.fill(Color(0, 0, 0, 1))
	if _dungeon_view == null:
		_dungeon_view = _DungeonViewScript.new()
		_dungeon_view.set_theme(_DungeonPortalsScript.theme_for(str(_dungeon_map.dungeon_id)))
	var field_w := CAMP_W * TILE_SRC
	var field_h := CAMP_H * TILE_SRC
	if (
		_dungeon_field == null
		or _dungeon_field.get_width() != field_w
		or _dungeon_field.get_height() != field_h
	):
		_dungeon_field = Image.create(field_w, field_h, false, Image.FORMAT_RGBA8)
	_dungeon_view.magic_light = GameState.dungeon_light_is_magic
	_dungeon_view.paint(
		_dungeon_field,
		_dungeon_map,
		Vector2i(int(center.x), int(center.y)),
		_dungeon_z,
		_dungeon_dir,
		_dungeon_lit,
		_tile_anim_frame
	)
	if not _dungeon_rock_fx.is_empty():
		var pieces: Array = _dungeon_rock_fx.get("pieces", []) as Array
		if not pieces.is_empty():
			_dungeon_view.paint_falling_rock_pieces(_dungeon_field, pieces)
		else:
			## Legacy single-rock shape (should not appear after the stack rewrite).
			var rock_img: Image = _dungeon_rock_fx.get("img", null) as Image
			_dungeon_view.paint_falling_rock(
				_dungeon_field,
				rock_img,
				int(_dungeon_rock_fx.get("mid_x", field_w / 2)),
				int(round(float(_dungeon_rock_fx.get("y", 0.0)))),
				int(_dungeon_rock_fx.get("span", 24))
			)
	var origin := Vector2i(
		((view_w - CAMP_W) / 2) * TILE_SRC,
		((view_h - CAMP_H) / 2) * TILE_SRC
	)
	_buf.blit_rect(_dungeon_field, Rect2i(0, 0, field_w, field_h), origin)
	_apply_view_shake()
	_upload_buffer()
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
	if _U4TileBankScript.uses_hgr_ntsc():
		_apple2_fill_stage_city(base, half_x, half_y)
	else:
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
					_blit_terrain_to(_stage, tid, dst, mx, my)

	_refresh_los()
	_apply_los_blackout_stage(base)
	_apply_city_exit_shade_stage(base)

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
	_paint_tile_flashes(cam)
	_apply_view_shake()
	_upload_buffer()
	queue_redraw()


func _paint_city_persons(cam: Vector2) -> void:
	## Draw .ULT townsfolk with 2-frame walk cycles (tile ↔ prev / even↔odd).
	## Apple II Color townsfolk are inserted into the HGR grid before the single
	## Mariani pass so color phase and delayed edge bits continue into neighbours.
	if _U4TileBankScript.uses_hgr_ntsc():
		return
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
	var cache_key := "%s#%s" % [path, _U4TileBankScript.active_set()]
	if _loot_icon_cache.has(cache_key):
		var cached: Variant = _loot_icon_cache[cache_key]
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
	_U4TileBankScript.apply_apple2_hud_palette(src)
	_loot_icon_cache[cache_key] = src
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


func _ensure_city_exit_shade_img() -> void:
	if (
		_city_exit_shade_img != null
		and not _city_exit_shade_img.is_empty()
		and _city_exit_shade_img.get_pixel(0, 0).is_equal_approx(CITY_EXIT_SHADE)
	):
		return
	_city_exit_shade_img = Image.create(TILE_SRC, TILE_SRC, false, Image.FORMAT_RGBA8)
	_city_exit_shade_img.fill(CITY_EXIT_SHADE)


func _apply_city_exit_shade_stage(base: Vector2i) -> void:
	## 50% black on tiles outside the 32×32 city — stepping there leaves town.
	if _city_map == null or _stage == null or _stage.is_empty():
		return
	_ensure_city_exit_shade_img()
	if _city_exit_shade_img == null:
		return
	var half_x := view_w / 2
	var half_y := view_h / 2
	for dy in view_h + 1:
		for dx in view_w + 1:
			var mx := base.x - half_x + dx
			var my := base.y - half_y + dy
			if mx >= 0 and my >= 0 and mx < _CITY_W and my < _CITY_H:
				continue
			_stage.blend_rect(
				_city_exit_shade_img,
				Rect2i(0, 0, TILE_SRC, TILE_SRC),
				Vector2i(dx * TILE_SRC, dy * TILE_SRC)
			)


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

	if _U4TileBankScript.uses_hgr_ntsc():
		_apple2_fill_buf_grid(
			func(dx: int, dy: int) -> int:
				var cx := dx - origin_x
				var cy := dy - origin_y
				if cx >= 0 and cy >= 0 and cx < camp_w and cy < camp_h:
					var occ := _apple2_camp_occupant_tid(cx, cy)
					if occ >= 0:
						return occ
					return clampi(_camp_map.tile_at(cx, cy), 0, TILE_ID_MAX)
				var bi := dy * view_w + dx
				if bi >= 0 and bi < _camp_bg.size():
					return clampi(int(_camp_bg[bi]), 0, TILE_ID_MAX)
				return 4,
			view_w,
			view_h
		)
	else:
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
				## View-space for shore masks (bridge side margins + camp water).
				_blit_terrain_to(_buf, tid, dst, dx, dy)

	_paint_camp_sleepers(origin_x, origin_y)
	_paint_camp_guard(origin_x, origin_y)
	_paint_shrine_walker(origin_x, origin_y)
	_paint_combat_tile_flashes(origin_x, origin_y)
	_upload_buffer()
	queue_redraw()


func _rebuild_combat() -> void:
	## 11×11 combat .CON centered (same margins as camp).
	var camp_w := CAMP_W
	var camp_h := CAMP_H
	var origin_x := (view_w - camp_w) / 2
	var origin_y := (view_h - camp_h) / 2
	if _U4TileBankScript.uses_hgr_ntsc():
		if is_in_dungeon():
			_buf.fill(Color(0, 0, 0, 1))
			var ids := PackedInt32Array()
			ids.resize(camp_w * camp_h)
			for cy in camp_h:
				for cx in camp_w:
					var occ := _apple2_combat_occupant_tid(cx, cy)
					ids[cy * camp_w + cx] = (
						occ if occ >= 0
						else clampi(_combat_map.tile_at(cx, cy), 0, TILE_ID_MAX)
					)
			var composed: Image = _Apple2HgrNtscScript.render_grid_scaled(
				ids, camp_w, camp_h, TILE_SRC, _apple2_water_scroll_src()
			)
			if composed != null and not composed.is_empty():
				_buf.blit_rect(
					composed,
					Rect2i(0, 0, composed.get_width(), composed.get_height()),
					_tile_px(origin_x, origin_y)
				)
		else:
			if _camp_bg.size() != view_w * view_h:
				_build_camp_background()
			_apple2_fill_buf_grid(
				func(dx: int, dy: int) -> int:
					var cx := dx - origin_x
					var cy := dy - origin_y
					if cx >= 0 and cy >= 0 and cx < camp_w and cy < camp_h:
						var occ := _apple2_combat_occupant_tid(cx, cy)
						if occ >= 0:
							return occ
						return clampi(_combat_map.tile_at(cx, cy), 0, TILE_ID_MAX)
					var bi := dy * view_w + dx
					if bi >= 0 and bi < _camp_bg.size():
						return clampi(int(_camp_bg[bi]), 0, TILE_ID_MAX)
					return 4,
				view_w,
				view_h
			)
	elif is_in_dungeon():
		## xu4 dungeon fight: center arena only — no world/side-strip backdrop.
		_buf.fill(Color(0, 0, 0, 1))
		for cy in camp_h:
			for cx in camp_w:
				var tid := clampi(_combat_map.tile_at(cx, cy), 0, TILE_ID_MAX)
				var dx := origin_x + cx
				var dy := origin_y + cy
				_blit_terrain_to(_buf, tid, _tile_px(dx, dy), dx, dy)
	else:
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
				var dst := _tile_px(dx, dy)
				## View-space coords so left/right beach margins get shore freckles too.
				_blit_terrain_to(_buf, tid, dst, dx, dy)

	_paint_combat_chests(origin_x, origin_y)
	_paint_combat_foes(origin_x, origin_y)
	_paint_combat_party(origin_x, origin_y)
	_paint_combat_range_shade(origin_x, origin_y)
	_paint_combat_focus(origin_x, origin_y)
	_paint_combat_tile_flashes(origin_x, origin_y)
	_paint_combat_projectile(origin_x, origin_y)
	_paint_combat_aim_cursor(origin_x, origin_y)
	_upload_buffer()
	queue_redraw()


func _paint_combat_chests(origin_x: int, origin_y: int) -> void:
	## Draw only the LIFO top chest at each tile; lower chests appear as each
	## fully looted top chest is removed.
	## Apple II Color: tile 60 is already in the HGR row. Loot icons are
	## grayscale (green-tinted on the green phosphor set).
	if _combat_chests.is_empty() or not tiles_ready:
		return
	if GraphicsSettings.is_apple2_tileset(GraphicsSettings.tileset_id()):
		if not _U4TileBankScript.uses_hgr_ntsc():
			_paint_combat_chests_apple2_overlay(origin_x, origin_y)
		_paint_combat_chest_loot(origin_x, origin_y)
		return
	for v in _combat_chests.values():
		if typeof(v) != TYPE_ARRAY:
			continue
		var pile: Array = v
		if pile.is_empty():
			continue
		var top_raw: Variant = pile.back()
		if typeof(top_raw) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = top_raw
		var pos := Vector2i(int(d.get("x", -1)), int(d.get("y", -1)))
		var sx := origin_x + pos.x
		var sy := origin_y + pos.y
		if sx < 0 or sy < 0 or sx >= view_w or sy >= view_h:
			continue
		var dst := _tile_px(sx, sy)
		var is_open := bool(d.get("open", false))
		## Terrain already drawn — keyed chest keeps the .CON / room floor.
		var chest_img := _keyed_chest_image(1 if is_open else 0)
		if chest_img != null:
			_buf.blend_rect(
				chest_img,
				Rect2i(0, 0, chest_img.get_width(), chest_img.get_height()),
				dst
			)
		if is_open:
			_blit_combat_chest_loot(d, dst)


func _paint_combat_chest_loot(origin_x: int, origin_y: int) -> void:
	for v in _combat_chests.values():
		if typeof(v) != TYPE_ARRAY:
			continue
		var pile: Array = v
		if pile.is_empty():
			continue
		var top_raw: Variant = pile.back()
		if typeof(top_raw) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = top_raw
		if not bool(d.get("open", false)):
			continue
		var pos := Vector2i(int(d.get("x", -1)), int(d.get("y", -1)))
		var sx := origin_x + pos.x
		var sy := origin_y + pos.y
		if sx < 0 or sy < 0 or sx >= view_w or sy >= view_h:
			continue
		_blit_combat_chest_loot(d, _tile_px(sx, sy))


func _blit_combat_chest_loot(d: Dictionary, dst: Vector2i) -> void:
	var stack: Array = []
	var raw: Variant = d.get("stack", [])
	if typeof(raw) == TYPE_ARRAY:
		stack = raw as Array
	if stack.is_empty():
		return
	var top: Dictionary = stack[0] if typeof(stack[0]) == TYPE_DICTIONARY else {}
	var icon := _loot_icon_for_entry(top)
	if icon == null or icon.is_empty():
		return
	var iw := icon.get_width()
	var ih := icon.get_height()
	var base_ox := CHEST_CAVITY_CENTER.x - iw / 2
	var base_oy := CHEST_CAVITY_CENTER.y - ih / 2
	var layers := mini(stack.size(), 5)
	for i in layers:
		var li := layers - 1 - i
		_buf.blend_rect(
			icon,
			Rect2i(0, 0, iw, ih),
			Vector2i(dst.x + base_ox + li * 2, dst.y + base_oy - li * 2)
		)


func _paint_combat_chests_apple2_overlay(origin_x: int, origin_y: int) -> void:
	## Mono / green: same SHP chest for closed and open. Loot is a later pass.
	var chest_img := _keyed_chest_image(0)
	if chest_img == null or chest_img.is_empty():
		return
	for v in _combat_chests.values():
		if typeof(v) != TYPE_ARRAY:
			continue
		var pile: Array = v
		if pile.is_empty():
			continue
		var top_raw: Variant = pile.back()
		if typeof(top_raw) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = top_raw
		var pos := Vector2i(int(d.get("x", -1)), int(d.get("y", -1)))
		var sx := origin_x + pos.x
		var sy := origin_y + pos.y
		if sx < 0 or sy < 0 or sx >= view_w or sy >= view_h:
			continue
		var dst := _tile_px(sx, sy)
		_buf.blend_rect(
			chest_img,
			Rect2i(0, 0, chest_img.get_width(), chest_img.get_height()),
			dst
		)


func _paint_combat_party(origin_x: int, origin_y: int) -> void:
	## xu4 PartyMember::putToSleep / getTile — asleep & dead use corpse icon.
	## Apple II Color: occupants are already in the HGR row (correct right-edge bits).
	if _U4TileBankScript.uses_hgr_ntsc():
		return
	for i in _combat_party.size():
		var u: Dictionary = _combat_party[i]
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
			var bit := _combat_party_frame_bit_at(i)
			var tid := even + (1 if bit == 1 else 0)
			img = _slice_keyed_tile(tid)
			if img == null:
				img = _slice_keyed_tile(even)
		if img == null or img.is_empty():
			continue
		var dst := _tile_px(sx, sy)
		_buf.blend_rect(img, Rect2i(0, 0, TILE_SRC, TILE_SRC), dst)


func _paint_combat_foes(origin_x: int, origin_y: int) -> void:
	var hgr := _U4TileBankScript.uses_hgr_ntsc()
	for i in _combat_foes.size():
		var u: Dictionary = _combat_foes[i]
		if int(u.get("hp", 1)) <= 0:
			continue
		var base_tid := int(u.get("tile", 0))
		var pos := Vector2i(int(u.get("x", 0)), int(u.get("y", 0)))
		var sx := origin_x + pos.x
		var sy := origin_y + pos.y
		if sx < 0 or sy < 0 or sx >= view_w or sy >= view_h:
			continue
		var dst := _tile_px(sx, sy)
		if not hgr:
			## xu4 sleeping creatures use the corpse / lying-down tile.
			var img: Image = null
			if bool(u.get("asleep", false)):
				if _corpse_slice == null:
					_corpse_slice = _slice_keyed_tile(TILE_CORPSE)
				img = _corpse_slice
			else:
				## Per-foe tick — not the global `_tile_anim_frame`.
				var tid: int = _WorldCreaturesScript.resolve_paint_tile(
					base_tid, _combat_foe_anim_tick_at(i)
				)
				img = _slice_keyed_tile(tid)
			if img == null or img.is_empty():
				continue
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
	var dst := _tile_px(sx, sy)
	var px := dst.x
	var py := dst.y
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


func _ensure_combat_range_shade_img() -> void:
	if _combat_range_shade_img != null and not _combat_range_shade_img.is_empty():
		return
	_combat_range_shade_img = Image.create(TILE_SRC, TILE_SRC, false, Image.FORMAT_RGBA8)
	_combat_range_shade_img.fill(COMBAT_RANGE_SHADE)


func _paint_combat_range_shade(origin_x: int, origin_y: int) -> void:
	## 50% black on combat tiles outside this weapon's cursor range.
	if not _combat_range_shade:
		return
	_ensure_combat_range_shade_img()
	if _combat_range_shade_img == null:
		return
	for cy in CAMP_H:
		for cx in CAMP_W:
			var cell := Vector2i(cx, cy)
			if _WeaponIconsScript.aim_cursor_allows(
				_combat_range_weapon, _combat_range_from, cell
			):
				continue
			var sx := origin_x + cx
			var sy := origin_y + cy
			if sx < 0 or sy < 0 or sx >= view_w or sy >= view_h:
				continue
			_buf.blend_rect(
				_combat_range_shade_img,
				Rect2i(0, 0, TILE_SRC, TILE_SRC),
				_tile_px(sx, sy)
			)


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
	var dst := _tile_px(sx, sy)
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
		var dst := _tile_px(sx, sy)
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
		and not GraphicsSettings.is_apple2_tileset(GraphicsSettings.tileset_id())
		and _sling_missile_img != null
		and not _sling_missile_img.is_empty()
	):
		_paint_projectile_image(_sling_missile_img, origin_x, origin_y, cx, cy, 1.0)
		return
	var miss_tid := int(_combat_proj.get("miss_tid", TILE_MISS_FLASH))
	var slice := _flying_tile_slice(miss_tid)
	if slice == null or slice.is_empty():
		return
	_paint_projectile_image(slice, origin_x, origin_y, cx, cy, 1.0)


func _flying_tile_slice(tile_id: int) -> Image:
	## Sub-tile flight: border-key black so the orb overlaps neighbours
	## without erasing dark NTSC fringe on the right edge.
	if _flying_slices.has(tile_id):
		return _flying_slices[tile_id] as Image
	var img: Image
	if _U4TileBankScript.uses_hgr_ntsc():
		img = _Apple2HgrNtscScript.render_flying_tile(tile_id)
		img = _U4TileBankScript.key_border_black(img)
	elif GraphicsSettings.is_apple2_tileset(GraphicsSettings.tileset_id()):
		img = _U4TileBankScript.keyed_copy(tile_id, 0, true)
	else:
		img = _overlay_slice(tile_id)
	_flying_slices[tile_id] = img
	return img


func _paint_projectile_image(
	img: Image, origin_x: int, origin_y: int, cx: float, cy: float, alpha: float = 1.0
) -> void:
	var iw := img.get_width()
	var ih := img.get_height()
	var shake := _shake_offset()
	## Flying HGR orbs are 32 + right-fringe; keep the 32×32 body centered.
	var hx := float(TILE_SRC) * 0.5 if iw > TILE_SRC else float(iw) * 0.5
	var hy := float(TILE_SRC) * 0.5 if ih > TILE_SRC else float(ih) * 0.5
	var px := int(round((float(origin_x) + cx) * float(TILE_SRC) - hx)) + shake.x
	var py := int(round((float(origin_y) + cy) * float(TILE_SRC) - hy)) + shake.y
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
	if is_in_dungeon():
		_camp_bg = PackedByteArray()
		return
	_camp_bg = PackedByteArray()
	_camp_bg.resize(view_w * view_h)
	_camp_bg.fill(TILE_GRASS)
	var origin_x := (view_w - CAMP_W) / 2
	var right_start := origin_x + CAMP_W
	## Spirituality shrine: leave margins as grass fill only (no world sides).
	if _shrine_plain_margins and not is_in_combat():
		_paint_camp_side_margin(true, origin_x, right_start, TILE_GRASS)
		_paint_camp_side_margin(false, origin_x, right_start, TILE_GRASS)
		return
	## Ship combat: match water/land rows to the .CON, not world-neighbour grass.
	if is_in_combat() and _is_ship_combat_map():
		_paint_ship_combat_margins(origin_x, right_start)
		return
	## Bridge .CON fight: extend the battlefield sideways (not world grass).
	if is_in_combat() and _is_bridge_combat_map():
		_paint_bridge_battlefield_margin(true, origin_x, right_start)
		_paint_bridge_battlefield_margin(false, origin_x, right_start)
		return
	## City combat: world neighbours are outside the walls (often water) —
	## pave both voids with brick floor like the settlement interior.
	if is_in_combat() and is_in_city():
		_paint_camp_side_margin(true, origin_x, right_start, TILE_BRICK_FLOOR)
		_paint_camp_side_margin(false, origin_x, right_start, TILE_BRICK_FLOOR)
		return

	var left_raw := TILE_GRASS
	var right_raw := TILE_GRASS
	if world != null and world.loaded:
		left_raw = clampi(int(world.tile_at(center.x - 1, center.y)), 0, 255)
		right_raw = clampi(int(world.tile_at(center.x + 1, center.y)), 0, 255)

	## Hole-up beside a bridge: sample BRIDGE.CON on that side (not flat grass).
	var left_bridge := _is_bridge_tile(left_raw)
	var right_bridge := _is_bridge_tile(right_raw)
	if left_bridge:
		_paint_bridge_battlefield_margin(true, origin_x, right_start)
	else:
		_paint_camp_side_margin(
			true, origin_x, right_start, _normalize_camp_margin_tile(left_raw)
		)
	if right_bridge:
		_paint_bridge_battlefield_margin(false, origin_x, right_start)
	else:
		_paint_camp_side_margin(
			false, origin_x, right_start, _normalize_camp_margin_tile(right_raw)
		)

	var left_base := _normalize_camp_margin_tile(left_raw)
	var right_base := _normalize_camp_margin_tile(right_raw)
	## Soften the camp | margin seam. Mixed fills keep inlets near camp.
	## Skip blend into bridge sides so BRIDGE.CON structure is not flattened.
	_blend_camp_edge_into_margins(
		origin_x,
		right_start,
		(not left_bridge) and _camp_margin_uses_mix(left_base),
		(not right_bridge) and _camp_margin_uses_mix(right_base),
		not left_bridge,
		not right_bridge
	)
	if (not left_bridge) and _camp_margin_uses_mix(left_base):
		_prune_floating_camp_soft(true, origin_x, right_start, left_base)
	if (not right_bridge) and _camp_margin_uses_mix(right_base):
		_prune_floating_camp_soft(false, origin_x, right_start, right_base)


func _is_ship_combat_map() -> bool:
	## Ship .CON boards use plank / white hull / mast tiles heavily.
	if _combat_map == null:
		return false
	var n := 0
	for y in CAMP_H:
		for x in CAMP_W:
			if _is_ship_or_deck_tile(int(_combat_map.tile_at(x, y))):
				n += 1
				if n >= 8:
					return true
	return false


func _is_bridge_combat_map() -> bool:
	## BRIDGE.CON (and siblings) have bridge_n/s + plank deck across mid rows.
	if _combat_map == null:
		return false
	var n := 0
	for y in CAMP_H:
		for x in CAMP_W:
			var tid := int(_combat_map.tile_at(x, y))
			if _is_bridge_tile(tid) or tid == TILE_PLANKS:
				n += 1
				if n >= 10:
					return true
	return false


func _get_bridge_con_map():
	## Cached BRIDGE.CON for side margins beside a bridge (camp / combat).
	if _bridge_con_map != null:
		return _bridge_con_map
	var path := _CombatMapDataScript.resolve_u4_file("BRIDGE.CON")
	if path.is_empty():
		return null
	var loaded = _CombatMapDataScript.new()
	if not loaded.load_from_path(path):
		return null
	_bridge_con_map = loaded
	return _bridge_con_map


func _paint_bridge_battlefield_margin(
	is_left: bool, origin_x: int, right_start: int
) -> void:
	## Project BRIDGE.CON columns into the side strip (xu4 bridge battlefield layout).
	## Camp: enter from east bank (col 0…) when bridge is on the right; reverse for left.
	var bmap = _get_bridge_con_map()
	if bmap == null:
		## Soft fallback — river feel, not flat plains.
		_paint_camp_side_margin(is_left, origin_x, right_start, 2)
		return
	var origin_y := (view_h - CAMP_H) / 2
	for dy in view_h:
		var map_y: int
		if dy < origin_y:
			map_y = 0
		elif dy >= origin_y + CAMP_H:
			map_y = CAMP_H - 1
		else:
			map_y = dy - origin_y
		for dx in view_w:
			if not _camp_margin_col(dx, is_left, origin_x, right_start):
				continue
			## 0 = cell immediately beside the 11×11 arena.
			var dist: int = (origin_x - 1 - dx) if is_left else (dx - right_start)
			if dist < 0:
				continue
			var con_x: int = (
				clampi(CAMP_W - 1 - dist, 0, CAMP_W - 1)
				if is_left
				else clampi(dist, 0, CAMP_W - 1)
			)
			_camp_bg[dy * view_w + dx] = clampi(int(bmap.tile_at(con_x, map_y)), 0, 255)


func _paint_ship_combat_margins(origin_x: int, right_start: int) -> void:
	## Left/right margins follow each .CON edge row: water depth falls off with
	## distance from the hull (shallow → medium → deep); land rows blend terrain.
	if _combat_map == null:
		return
	var origin_y := (view_h - CAMP_H) / 2
	for dy in view_h:
		var map_y: int
		if dy < origin_y:
			map_y = 0
		elif dy >= origin_y + CAMP_H:
			map_y = CAMP_H - 1
		else:
			map_y = dy - origin_y
		var left_base := _ship_margin_tid_from_edge(int(_combat_map.tile_at(0, map_y)))
		var right_base := _ship_margin_tid_from_edge(int(_combat_map.tile_at(CAMP_W - 1, map_y)))
		for dx in view_w:
			if dx < origin_x:
				## 0 = cell flush with the arena (nearest the ship).
				var dist_l := origin_x - 1 - dx
				_camp_bg[dy * view_w + dx] = _ship_margin_cell_tid(left_base, dist_l)
			elif dx >= right_start:
				var dist_r := dx - right_start
				_camp_bg[dy * view_w + dx] = _ship_margin_cell_tid(right_base, dist_r)


func _ship_margin_tid_from_edge(edge_tid: int) -> int:
	## Water stays water; ship hull/deck flush into open sea; shore land continues.
	if edge_tid <= WATER_TILE_MAX or _TileRulesCamp.is_water(edge_tid):
		return clampi(edge_tid, 0, WATER_TILE_MAX)
	if _is_ship_or_deck_tile(edge_tid):
		return TILE_MEDIUM_WATER
	return _normalize_camp_margin_tile(edge_tid)


func _ship_sea_depth_for_dist(edge_water: int, dist: int) -> int:
	## Open-sea side strip by distance from the hull (SHIPSEA shallow belt etc.).
	## Near ship: keep edge depth; a short medium band; open ocean = deep.
	## dist 0 = column beside the 11×11 .CON.
	var d := maxi(0, dist)
	var edge := clampi(edge_water, 0, WATER_TILE_MAX)
	match edge:
		2: ## shallow band at the hull waterline
			if d <= 0:
				return 2
			if d <= 2:
				return TILE_MEDIUM_WATER
			return 0 ## deep
		1: ## medium (open water or hull flush)
			if d <= 1:
				return TILE_MEDIUM_WATER
			return 0
		_:
			return 0


func _ship_margin_cell_tid(base: int, dist: int = 0) -> int:
	## Keep water rows as a depth gradient. On land rows, blend plains / scrub / trees.
	if base <= WATER_TILE_MAX:
		return _ship_sea_depth_for_dist(base, dist)
	## Light mix; favour grass/brush with occasional forest (or swamp near marsh edges).
	var r := randf()
	if base == TILE_SWAMP:
		if r < 0.70:
			return TILE_SWAMP
		if r < 0.88:
			return TILE_GRASS
		return TILE_BRUSH
	if r < 0.55:
		return TILE_GRASS
	if r < 0.82:
		return TILE_BRUSH
	return TILE_FOREST


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
	origin_x: int,
	right_start: int,
	left_mix: bool,
	right_mix: bool,
	extend_left: bool = true,
	extend_right: bool = true
) -> void:
	## CAMP.CON corners are brush — extend into the margin.
	## Grass edges bleed outward. Mixed sides keep gaps so fill inlets reach the camp.
	if _camp_map == null:
		return
	for dy in view_h:
		if dy < 0 or dy >= CAMP_H:
			continue
		if extend_left:
			_extend_camp_edge_row(
				true, origin_x, right_start, dy, int(_camp_map.tile_at(0, dy)), left_mix
			)
		if extend_right:
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


func _apple2_water_scroll_src() -> int:
	## Map 32px water scroll clock onto 16 HGR scanlines.
	return int(posmod(_water_scroll, TILE_SRC) * _Apple2HgrNtscScript.SRC_H / float(TILE_SRC))


func _apple2_compose_tid(tid: int, _mx: int, _my: int) -> int:
	## Tile id stamped into the HGR grid (opaque Apple II art — no keyed underlay).
	return clampi(tid, 0, TILE_ID_MAX)


func _apple2_fill_stage_from_ids(ids: PackedInt32Array, cols: int, rows: int) -> void:
	var composed: Image = _Apple2HgrNtscScript.render_grid_scaled(
		ids, cols, rows, TILE_SRC, _apple2_water_scroll_src()
	)
	if composed == null or composed.is_empty():
		_stage.fill(Color(0, 0, 0, 1))
		return
	## Always restore the clean composed stage before LOS blackouts. The decoder
	## itself caches unchanged ids/scroll at 0ms; caching `_stage` here would also
	## cache the previous frame's destructive LOS mask.
	_stage.blit_rect(
		composed,
		Rect2i(0, 0, composed.get_width(), composed.get_height()),
		Vector2i.ZERO
	)


func _apple2_fill_stage_world(base: Vector2i, half_x: int, half_y: int) -> void:
	var cols := view_w + 1
	var rows := view_h + 1
	var n := cols * rows
	if _apple2_ids.size() != n:
		_apple2_ids.resize(n)
	for dy in rows:
		for dx in cols:
			var mx := base.x - half_x + dx
			var my := base.y - half_y + dy
			var tid := _world_display_tid(mx, my)
			var creat := _apple2_world_creature_tid(mx, my)
			if creat >= 0:
				tid = creat
			var party_tid := _apple2_party_grid_tid(mx, my)
			if party_tid >= 0:
				tid = party_tid
			_apple2_ids[dy * cols + dx] = _apple2_compose_tid(tid, mx, my)
	_apple2_fill_stage_from_ids(_apple2_ids, cols, rows)


func _apple2_fill_stage_city(base: Vector2i, half_x: int, half_y: int) -> void:
	var cols := view_w + 1
	var rows := view_h + 1
	var n := cols * rows
	if _apple2_ids.size() != n:
		_apple2_ids.resize(n)
	for dy in rows:
		for dx in cols:
			var mx := base.x - half_x + dx
			var my := base.y - half_y + dy
			var tid := _apple2_city_display_tid(mx, my)
			_apple2_ids[dy * cols + dx] = tid
	_apple2_fill_stage_from_ids(_apple2_ids, cols, rows)


func _apple2_city_display_tid(mx: int, my: int) -> int:
	## Build the final opaque Apple II HGR cell before NTSC decoding. Unlike the
	## PNG pipelines, drawing a person afterward as an isolated tile resets the
	## signal/phase at both edges, visibly shortening guard tile 80's right arm.
	var tid := clampi(_city_tile_or_outside(mx, my), 0, TILE_ID_MAX)
	if _city_map != null:
		for i in _city_map.persons.size():
			var p: Vector3i = _city_map.persons[i]
			if p.x != mx or p.y != my:
				continue
			var prev := -1
			if i < _city_map.person_prev.size():
				prev = int(_city_map.person_prev[i])
			tid = _npc_frame_tile(int(p.z), prev, i)
			break
	var party_tid := _apple2_party_grid_tid(mx, my)
	if party_tid >= 0:
		tid = party_tid
	return _apple2_compose_tid(tid, mx, my)


func _apple2_party_grid_tid(mx: int, my: int) -> int:
	## While the camera is between cells the party remains a fixed screen-space
	## overlay. Once settled, include raw HGR art in the row for correct borders.
	if _scroll_frames_left > 0 or mx != center.x or my != center.y:
		return -1
	return _apple2_party_sprite_tid()


func _apple2_party_sprite_tid() -> int:
	if _transport_tile >= 0:
		## Mounted art is the fixed rider overlay, not riderless SHP 20/21.
		if is_horse_tile(_transport_tile):
			return -1
		return clampi(_transport_tile, 0, TILE_ID_MAX)
	var pair := _avatar_tile_pair()
	return pair.y if _avatar_frame == 1 else pair.x


func _apple2_ground_tid(mx: int, my: int) -> int:
	if is_in_city():
		return _apple2_city_display_tid(mx, my)
	var tid := _world_display_tid(mx, my)
	var creat := _apple2_world_creature_tid(mx, my)
	if creat >= 0:
		tid = creat
	return _apple2_compose_tid(tid, mx, my)


func _apple2_party_scroll_slice() -> Image:
	## 3-wide continuous decode (left / party / right). Cheap, and does not
	## touch the explore-view NTSC cache. Party stays screen-fixed.
	var party_tid := _apple2_party_sprite_tid()
	if party_tid < 0:
		return null
	var cam := _cam_tile()
	var mx := floori(cam.x)
	var my := floori(cam.y)
	var left := _apple2_ground_tid(mx - 1, my)
	var right := _apple2_ground_tid(mx + 1, my)
	var key := Vector4i(left, party_tid, right, _apple2_water_scroll_src())
	if _apple2_scroll_party != null and key == _apple2_scroll_party_key:
		return _apple2_scroll_party
	var ids := PackedInt32Array()
	ids.resize(3)
	ids[0] = left
	ids[1] = party_tid
	ids[2] = right
	var strip: Image = _Apple2HgrNtscScript.render_uncached(
		ids, 3, 1, _apple2_water_scroll_src()
	)
	if strip == null or strip.is_empty():
		return null
	var img := Image.create(TILE_SRC, TILE_SRC, false, Image.FORMAT_RGBA8)
	img.blit_rect(strip, Rect2i(TILE_SRC, 0, TILE_SRC, TILE_SRC), Vector2i.ZERO)
	_apple2_scroll_party = img
	_apple2_scroll_party_key = key
	return img


func _apple2_party_is_grid_composed() -> bool:
	## Settled walker/ship/balloon stay in the HGR row. Horse uses the mount overlay.
	return (
		_U4TileBankScript.uses_hgr_ntsc()
		and _scroll_frames_left <= 0
		and (_transport_tile < 0 or not is_horse_tile(_transport_tile))
	)


func _apple2_class_walk_tid(klass: int, frame_bit: int = -1) -> int:
	if klass < 0 or klass >= CLASS_TILE_EVEN.size():
		return -1
	var even: int = CLASS_TILE_EVEN[klass]
	var bit := _avatar_frame if frame_bit < 0 else frame_bit
	return even + (1 if bit == 1 else 0)


func _apple2_combat_occupant_tid(cx: int, cy: int) -> int:
	## Party on top of foes so the focused fighter is not buried.
	## Same cell may hold both; party wins the HGR cell (PNG path blends both).
	for i in _combat_party.size():
		var u: Dictionary = _combat_party[i]
		if int(u.get("x", -1)) != cx or int(u.get("y", -1)) != cy:
			continue
		var klass := int(u.get("klass", -1))
		if (
			klass >= 0
			and (
				GameState.is_member_disabled(klass)
				or GameState.is_class_dead(klass)
			)
		):
			return TILE_CORPSE
		return _apple2_class_walk_tid(klass, _combat_party_frame_bit_at(i))
	for j in _combat_foes.size():
		var f: Dictionary = _combat_foes[j]
		if int(f.get("hp", 1)) <= 0:
			continue
		if int(f.get("x", -1)) != cx or int(f.get("y", -1)) != cy:
			continue
		if bool(f.get("asleep", false)):
			return TILE_CORPSE
		return _WorldCreaturesScript.resolve_paint_tile(
			int(f.get("tile", 0)), _combat_foe_anim_tick_at(j)
		)
	## Overlay piles only — room TILE_CHEST terrain already occupies the cell.
	if not _combat_chest_pile_at(Vector2i(cx, cy)).is_empty():
		return TILE_CHEST
	return -1


func _apple2_camp_occupant_tid(cx: int, cy: int) -> int:
	if _shrine_walker.x == cx and _shrine_walker.y == cy:
		if _shrine_walker_kneel:
			return TILE_BEGGAR
		var pair := _avatar_tile_pair()
		return pair.y if _avatar_frame == 1 else pair.x
	if _camp_guard_pos.x == cx and _camp_guard_pos.y == cy and _camp_guard_class >= 0:
		return _apple2_class_walk_tid(_camp_guard_class)
	for pos in _camp_sleepers:
		if pos.x == cx and pos.y == cy:
			return TILE_CORPSE
	return -1


func _apple2_world_creature_tid(mx: int, my: int) -> int:
	if _creatures.is_empty():
		return -1
	var wx := posmod(mx, WorldMapData.WIDTH)
	var wy := posmod(my, WorldMapData.HEIGHT)
	for item in _creatures:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		if posmod(int(d.get("x", 0)), WorldMapData.WIDTH) != wx:
			continue
		if posmod(int(d.get("y", 0)), WorldMapData.HEIGHT) != wy:
			continue
		return _WorldCreaturesScript.resolve_paint_tile(
			int(d.get("tid", d.get("z", 0))),
			_tile_anim_frame
		)
	return -1


func _apple2_fill_buf_grid(get_tid: Callable, cols: int, rows: int) -> void:
	## Combat / camp: fill `_buf` directly (no scroll stage).
	var ids := PackedInt32Array()
	ids.resize(cols * rows)
	for dy in rows:
		for dx in cols:
			ids[dy * cols + dx] = _apple2_compose_tid(int(get_tid.call(dx, dy)), dx, dy)
	var composed: Image = _Apple2HgrNtscScript.render_grid_scaled(
		ids, cols, rows, TILE_SRC, _apple2_water_scroll_src()
	)
	if composed == null or composed.is_empty():
		_buf.fill(Color(0, 0, 0, 1))
		return
	_buf.blit_rect(
		composed,
		Rect2i(0, 0, mini(composed.get_width(), _buf.get_width()), mini(composed.get_height(), _buf.get_height())),
		Vector2i.ZERO
	)


func _blit_terrain_to(
	target: Image, tid: int, dst: Vector2i, map_x: int = SHORE_NO_CELL, map_y: int = SHORE_NO_CELL
) -> void:
	## Water, fields, lava, and white-corner edges share the same Y-scroll clock.
	if tid <= WATER_TILE_MAX or _is_y_scroll_tile(tid):
		_U4TileBankScript.blit_water_to(target, tid, dst, _water_scroll)
		## Classic water (0..2): stamp land freckles where neighbours are not water.
		if tid <= WATER_TILE_MAX and map_x != SHORE_NO_CELL and map_y != SHORE_NO_CELL:
			_apply_water_shore_masks(target, dst, map_x, map_y)
	elif tid >= TILE_WHITE_SW and tid <= TILE_WHITE_NE:
		_U4TileBankScript.blit_water_edge_to(target, tid, dst, _water_scroll)
	elif tid == TILE_SPIT:
		## Spit: `075_spit.png` ↔ `075_spit_1.png` (camp, city, world — same path).
		_U4TileBankScript.blit_anim_to(target, tid, dst, _tile_anim_frame)
	elif tid == TILE_CHEST:
		## xu4 chest uses replacement floor under transparent margins.
		_blit_chest_tile(target, dst, 0, _city_map != null)
	elif tid == TILE_CORPSE:
		## Some city maps place the lying-down person directly in the terrain
		## layer. Draw its floor first so the keyed background is transparent.
		_blit_corpse_tile(target, dst, _city_map != null)
	elif is_horse_tile(tid):
		## Parked / terrain horses stay on the standing frame.
		_U4TileBankScript.blit_to(target, tid, dst, _horse_stand_frame_id(tid))
	elif _U4TileBankScript.frame_count(tid) > 1:
		_U4TileBankScript.blit_anim_to(target, tid, dst, _tile_anim_frame)
	else:
		_U4TileBankScript.blit_to(target, tid, dst)


func _is_shore_land_tid(tid: int) -> bool:
	## Non-water land that should receive shore freckles on adjacent water.
	if _TileRulesCamp.is_water(tid):
		return false
	## Bridges never mint a shore mask (world or combat).
	if _is_bridge_tile(tid):
		return false
	## Stone / brick walls and brick floor — no muddy freckles against masonry.
	if tid == TILE_STONE_WALL or tid == TILE_BRICK_WALL or tid == TILE_BRICK_FLOOR:
		return false
	## Hills / mountains / dungeon mouth — rocky base, not a sandy shore.
	if tid == TILE_HILLS or tid == TILE_MOUNTAINS or tid == TILE_DUNGEON:
		return false
	## Magic fields (poison/energy/fire/sleep) are hovering overlays — not shore land.
	if tid >= TILE_FIELD_POISON and tid <= TILE_FIELD_SLEEP:
		return false
	## City shop sign letters / space.
	if tid >= TILE_SIGN_A and tid <= TILE_SIGN_SPACE:
		return false
	## Ship hull / deck / white rail — no muddy shore freckles against the vessel.
	if _is_ship_or_deck_tile(tid):
		return false
	return true


func _is_bridge_tile(tid: int) -> bool:
	return tid == TILE_BRIDGE or tid == TILE_BRIDGE_N or tid == TILE_BRIDGE_S


func _is_ship_or_deck_tile(tid: int) -> bool:
	## Frigate facings, pirate hulls, plank deck, white hull rails, mast/wheel,
	## and the white corner stones used on ship .CON boards.
	if tid >= TILE_SHIP_W and tid <= TILE_SHIP_S:
		return true
	if tid >= TILE_PIRATE_SHIP_W and tid <= TILE_PIRATE_SHIP_S:
		return true
	if tid == TILE_PLANKS or tid == TILE_WHITE_SOLID:
		return true
	if tid == TILE_SHIP_MAST or tid == TILE_SHIP_WHEEL:
		return true
	## column + waterside whites 48–52 (ship rail/end caps in combat maps).
	if tid >= 48 and tid <= TILE_WHITE_NE:
		return true
	return false


func _render_tid_at(mx: int, my: int) -> int:
	## Map cell for shore neighbour tests (same source as the cell being drawn).
	## Combat uses *view* cell coords so left/right margin beaches participate.
	if is_in_combat():
		return _combat_view_tid_at(mx, my)
	if _camp_map != null and not is_in_combat():
		if mx >= 0 and my >= 0 and mx < CAMP_W and my < CAMP_H:
			return clampi(int(_camp_map.tile_at(mx, my)), 0, TILE_ID_MAX)
		return TILE_GRASS
	if is_in_city():
		return clampi(_city_tile_or_outside(mx, my), 0, TILE_ID_MAX)
	if world != null and world.loaded:
		return _world_display_tid(mx, my)
	return TILE_GRASS


func _world_display_tid(mx: int, my: int) -> int:
	var pos := Vector2i(posmod(mx, WorldMapData.WIDTH), posmod(my, WorldMapData.HEIGHT))
	var st := session_tile_at(pos)
	if st >= 0:
		return clampi(st, 0, TILE_ID_MAX)
	if world == null or not world.loaded:
		return TILE_GRASS
	return clampi(world.tile_at(pos.x, pos.y), 0, TILE_ID_MAX)


func _combat_view_tid_at(vx: int, vy: int) -> int:
	## Tile under a combat explore-view cell (arena + left/right camp margins).
	if vx < 0 or vy < 0 or vx >= view_w or vy >= view_h:
		return TILE_GRASS
	var origin_x := (view_w - CAMP_W) / 2
	var origin_y := (view_h - CAMP_H) / 2
	var cx := vx - origin_x
	var cy := vy - origin_y
	if cx >= 0 and cy >= 0 and cx < CAMP_W and cy < CAMP_H:
		if is_in_combat() and _combat_map != null:
			return clampi(int(_combat_map.tile_at(cx, cy)), 0, TILE_ID_MAX)
		if is_camping() and _camp_map != null:
			return clampi(int(_camp_map.tile_at(cx, cy)), 0, TILE_ID_MAX)
	var bi := vy * view_w + vx
	if bi >= 0 and bi < _camp_bg.size():
		return clampi(int(_camp_bg[bi]), 0, TILE_ID_MAX)
	return TILE_GRASS


func _shore_neighbour_is_land(nb_x: int, nb_y: int) -> bool:
	## Screen-exterior sides never mint a shore (but combat/camp margin beaches do).
	if is_in_combat() or is_camping():
		if nb_x < 0 or nb_y < 0 or nb_x >= view_w or nb_y >= view_h:
			return false
		return _is_shore_land_tid(_combat_view_tid_at(nb_x, nb_y))
	return _is_shore_land_tid(_render_tid_at(nb_x, nb_y))


func _shore_land_bits_at(mx: int, my: int) -> int:
	var bits := 0
	if _shore_neighbour_is_land(mx, my - 1):
		bits |= SHORE_BIT_N
	if _shore_neighbour_is_land(mx + 1, my):
		bits |= SHORE_BIT_E
	if _shore_neighbour_is_land(mx, my + 1):
		bits |= SHORE_BIT_S
	if _shore_neighbour_is_land(mx - 1, my):
		bits |= SHORE_BIT_W
	return bits


func _load_shore_land_ref(ref_name: String) -> Image:
	if _shore_land_cache.has(ref_name):
		return _shore_land_cache[ref_name] as Image
	var path := "%s/shore_land_%s.png" % [SHORE_MASK_DIR, ref_name]
	var img := _ResImage.load_rgba8(path)
	if img == null or img.is_empty():
		push_warning("MapView: missing shore land %s" % path)
		_shore_land_cache[ref_name] = null
		return null
	_shore_land_cache[ref_name] = img
	return img


func _apply_water_shore_masks(target: Image, dst: Vector2i, mx: int, my: int) -> void:
	## Overlay directional `shore_land_*` freckles where N/E/S/W neighbours are land.
	if not _U4TileBankScript.uses_shore_masks():
		return
	var bits := _shore_land_bits_at(mx, my)
	if bits == 0:
		return
	## Solid 1px black rim against land first (no water leaks), then sparse freckles.
	_fill_shore_edge_blackout(target, dst, bits)
	var freckled := PackedByteArray()
	freckled.resize(TILE_SRC * TILE_SRC)
	freckled.fill(0)
	## Full-ref specials for open channels / fully enclosed bays.
	if bits == (SHORE_BIT_E | SHORE_BIT_W):
		_blend_shore_land_full(target, dst, SHORE_REF_EW, freckled)
		return
	if bits == (SHORE_BIT_N | SHORE_BIT_S):
		_blend_shore_land_full(target, dst, SHORE_REF_NS, freckled)
		return
	if bits == (SHORE_BIT_N | SHORE_BIT_E | SHORE_BIT_S | SHORE_BIT_W):
		_blend_shore_land_full(target, dst, SHORE_REF_FRAME, freckled)
		return
	## Directed edges + outer corners (only pixels near the matching edge/corner).
	if bits & SHORE_BIT_N:
		_blend_shore_land_side(target, dst, SHORE_REF_N, SHORE_BIT_N, freckled)
	if bits & SHORE_BIT_E:
		_blend_shore_land_side(target, dst, SHORE_REF_E, SHORE_BIT_E, freckled)
	if bits & SHORE_BIT_S:
		_blend_shore_land_side(target, dst, SHORE_REF_S, SHORE_BIT_S, freckled)
	if bits & SHORE_BIT_W:
		_blend_shore_land_side(target, dst, SHORE_REF_W, SHORE_BIT_W, freckled)
	if (bits & (SHORE_BIT_N | SHORE_BIT_W)) == (SHORE_BIT_N | SHORE_BIT_W):
		_blend_shore_land_corner(target, dst, SHORE_REF_NW, SHORE_BIT_N | SHORE_BIT_W, freckled)
	if (bits & (SHORE_BIT_N | SHORE_BIT_E)) == (SHORE_BIT_N | SHORE_BIT_E):
		_blend_shore_land_corner(target, dst, SHORE_REF_NE, SHORE_BIT_N | SHORE_BIT_E, freckled)
	if (bits & (SHORE_BIT_S | SHORE_BIT_W)) == (SHORE_BIT_S | SHORE_BIT_W):
		_blend_shore_land_corner(target, dst, SHORE_REF_SW, SHORE_BIT_S | SHORE_BIT_W, freckled)
	if (bits & (SHORE_BIT_S | SHORE_BIT_E)) == (SHORE_BIT_S | SHORE_BIT_E):
		_blend_shore_land_corner(target, dst, SHORE_REF_SE, SHORE_BIT_S | SHORE_BIT_E, freckled)


func _blend_shore_land_full(
	target: Image, dst: Vector2i, ref_name: String, freckled: PackedByteArray
) -> void:
	var land := _load_shore_land_ref(ref_name)
	if land == null:
		return
	_stamp_shore_land(target, dst, land, 0, freckled)


func _blend_shore_land_side(
	target: Image, dst: Vector2i, ref_name: String, side: int, freckled: PackedByteArray
) -> void:
	var land := _load_shore_land_ref(ref_name)
	if land == null:
		return
	_stamp_shore_land(target, dst, land, side, freckled)


func _blend_shore_land_corner(
	target: Image, dst: Vector2i, ref_name: String, corner_bits: int, freckled: PackedByteArray
) -> void:
	var land := _load_shore_land_ref(ref_name)
	if land == null:
		return
	## High bit marks "require both axes of the corner pair".
	_stamp_shore_land(target, dst, land, corner_bits | 16, freckled)


func _stamp_shore_land(
	target: Image, dst: Vector2i, land: Image, filter: int, freckled: PackedByteArray
) -> void:
	## filter 0 = full. Bits 1/2/4/8 = edge bands. filter|16 = outer corner (both axes).
	var tw := target.get_width()
	var th := target.get_height()
	var lw := mini(land.get_width(), TILE_SRC)
	var lh := mini(land.get_height(), TILE_SRC)
	var corner := (filter & 16) != 0
	var sides := filter & 15
	## Straight edges ≤6px; rounded outer-corner stamps may reach slightly further.
	var depth := SHORE_CORNER_DEPTH if corner else SHORE_EDGE_DEPTH
	for y in lh:
		for x in lw:
			if not _shore_filter_keeps(x, y, sides, corner, depth):
				continue
			var c := land.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var tx := dst.x + x
			var ty := dst.y + y
			if tx < 0 or ty < 0 or tx >= tw or ty >= th:
				continue
			## Soften mask chroma so freckles do not overpower the water tile.
			var s := SHORE_COLOR_SCALE
			target.set_pixel(tx, ty, Color(c.r * s, c.g * s, c.b * s, c.a))
			freckled[y * TILE_SRC + x] = 1


func _fill_shore_edge_blackout(target: Image, dst: Vector2i, bits: int) -> void:
	## Full 1px rim against land — solid black so water never shows through.
	var black := Color(0, 0, 0, 1)
	var tw := target.get_width()
	var th := target.get_height()
	if bits & SHORE_BIT_N:
		for x in TILE_SRC:
			var tx := dst.x + x
			var ty := dst.y
			if tx >= 0 and ty >= 0 and tx < tw and ty < th:
				target.set_pixel(tx, ty, black)
	if bits & SHORE_BIT_S:
		var y := TILE_SRC - 1
		for x in TILE_SRC:
			var tx2 := dst.x + x
			var ty2 := dst.y + y
			if tx2 >= 0 and ty2 >= 0 and tx2 < tw and ty2 < th:
				target.set_pixel(tx2, ty2, black)
	if bits & SHORE_BIT_W:
		for y3 in TILE_SRC:
			var tx3 := dst.x
			var ty3 := dst.y + y3
			if tx3 >= 0 and ty3 >= 0 and tx3 < tw and ty3 < th:
				target.set_pixel(tx3, ty3, black)
	if bits & SHORE_BIT_E:
		var x4 := TILE_SRC - 1
		for y4 in TILE_SRC:
			var tx4 := dst.x + x4
			var ty4 := dst.y + y4
			if tx4 >= 0 and ty4 >= 0 and tx4 < tw and ty4 < th:
				target.set_pixel(tx4, ty4, black)


func _shore_filter_keeps(x: int, y: int, sides: int, corner: bool, depth: int) -> bool:
	if sides == 0:
		return true
	var n := (sides & SHORE_BIT_N) != 0 and y < depth
	var s := (sides & SHORE_BIT_S) != 0 and y >= TILE_SRC - depth
	var w := (sides & SHORE_BIT_W) != 0 and x < depth
	var e := (sides & SHORE_BIT_E) != 0 and x >= TILE_SRC - depth
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


func _keyed_chest_image(frame: int) -> Image:
	var f := 1 if frame != 0 else 0
	## Apple II SHP bank has one chest tile — no open-lid PNG.
	if GraphicsSettings.is_apple2_tileset(GraphicsSettings.tileset_id()):
		f = 0
	if _keyed_chest_frames.size() < 2:
		_keyed_chest_frames = [null, null]
	var cached: Variant = _keyed_chest_frames[f]
	if cached is Image and not (cached as Image).is_empty():
		return cached as Image
	var img: Image = _U4TileBankScript.keyed_copy(TILE_CHEST, f)
	_keyed_chest_frames[f] = img
	return img


func _blit_chest_tile(target: Image, dst: Vector2i, frame: int, city_floor: bool) -> void:
	## Floor underlay + keyed chest. Dungeon / city use brick, wilderness grass.
	var under := TILE_GRASS
	if city_floor or is_in_dungeon():
		under = TILE_BRICK_FLOOR
	_U4TileBankScript.blit_to(target, under, dst, 0)
	var chest_img := _keyed_chest_image(frame)
	if chest_img != null:
		target.blend_rect(
			chest_img,
			Rect2i(0, 0, chest_img.get_width(), chest_img.get_height()),
			dst
		)


func _blit_corpse_tile(target: Image, dst: Vector2i, city_floor: bool) -> void:
	## Floor underlay + border-keyed lying person.
	var under := TILE_GRASS
	if city_floor or is_in_dungeon():
		under = TILE_BRICK_FLOOR
	_U4TileBankScript.blit_to(target, under, dst, 0)
	if _corpse_slice == null:
		_corpse_slice = _slice_keyed_tile(TILE_CORPSE)
	if _corpse_slice != null:
		target.blend_rect(
			_corpse_slice,
			Rect2i(0, 0, _corpse_slice.get_width(), _corpse_slice.get_height()),
			dst
		)


func _refresh_los() -> void:
	## xu4 screenFindLineOfSight — blocking from front terrain around party `center`.
	## Grid is view+2×view+2 so one-tile scroll fringe still blackouts opacity-hidden cells.
	var dim := _los_grid_size()
	_los_w = dim.x
	_los_h = dim.y
	if not los_enabled:
		_los = _LineOfSightScript.all_visible(_los_w, _los_h)
		_refresh_weather_hide_mask()
		return
	var half_x := _los_w / 2
	var half_y := _los_h / 2
	var blocking := PackedByteArray()
	blocking.resize(_los_w * _los_h)
	for dy in _los_h:
		for dx in _los_w:
			var tid := _terrain_tid_at(center.x - half_x + dx, center.y - half_y + dy)
			## Balloon aloft (`los_opacity` false): nothing blocks.
			var opaque := los_opacity and _TileRulesCamp.is_opaque(tid)
			blocking[dy * _los_w + dx] = 1 if opaque else 0
	_los = _LineOfSightScript.compute_dos(blocking, _los_w, _los_h)
	## Ultima4R: standing in forest (opaque underfoot) still shows the 8 neighbors.
	if los_opacity and _TileRulesCamp.is_opaque(_terrain_tid_at(center.x, center.y)):
		_reveal_center_moore_neighbors()
	_refresh_weather_hide_mask()


func _reveal_center_moore_neighbors() -> void:
	## Force-visible Moore neighborhood around the party (DOS alone blacks it all out).
	if _los.is_empty() or _los_w < 1 or _los_h < 1:
		return
	var half_x := _los_w / 2
	var half_y := _los_h / 2
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var vx := half_x + dx
			var vy := half_y + dy
			if vx < 0 or vy < 0 or vx >= _los_w or vy >= _los_h:
				continue
			_los[vy * _los_w + vx] = 1


func _terrain_tid_at(wx: int, wy: int) -> int:
	if is_in_city():
		return clampi(_city_tile_or_outside(wx, wy), 0, TILE_ID_MAX)
	if world != null and world.loaded:
		return clampi(world.tile_at(wx, wy), 0, TILE_ID_MAX)
	return TILE_GRASS


func _apply_los_blackout_stage(base: Vector2i) -> void:
	## Replace hidden stage cells with black (xu4 draws tile_black).
	## Scroll paints a view+1 stage; LOS is view+2 so the peel-in fringe is in-range
	## and opacity-hidden cells stay black (no “show then vanish” behind mountains).
	if not los_enabled:
		return
	if _los.is_empty() or _los_w < 1 or _los_h < 1:
		return
	var half_view_x := view_w / 2
	var half_view_y := view_h / 2
	var half_los_x := _los_w / 2
	var half_los_y := _los_h / 2
	for dy in view_h + 1:
		for dx in view_w + 1:
			var mx := base.x - half_view_x + dx
			var my := base.y - half_view_y + dy
			var vx := mx - center.x + half_los_x
			var vy := my - center.y + half_los_y
			if vx < 0 or vy < 0 or vx >= _los_w or vy >= _los_h:
				## Beyond even padded LOS — treat as fog (safe for rare cam base).
				_stage.fill_rect(
					Rect2i(dx * TILE_SRC, dy * TILE_SRC, TILE_SRC, TILE_SRC),
					_LOS_BLACK
				)
				continue
			if _los[vy * _los_w + vx] != 0:
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
	if _U4TileBankScript.uses_hgr_ntsc():
		return
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
	if _U4TileBankScript.uses_hgr_ntsc():
		return
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


func _paint_shrine_walker(origin_x: int, origin_y: int) -> void:
	## Approach / kneel / leave — leader class sprite over the shrine .CON.
	if _U4TileBankScript.uses_hgr_ntsc():
		return
	if _shrine_walker.x < 0 or _shrine_walker.y < 0:
		return
	var sx := origin_x + _shrine_walker.x
	var sy := origin_y + _shrine_walker.y
	if sx < 0 or sy < 0 or sx >= view_w or sy >= view_h:
		return
	var dst := Vector2i(sx * TILE_SRC, sy * TILE_SRC)
	if _shrine_walker_kneel:
		var n := _U4TileBankScript.frame_count(TILE_BEGGAR)
		var f := 0 if n <= 1 else posmod(_tile_anim_frame, n)
		var kneel := _U4TileBankScript.keyed_copy(TILE_BEGGAR, f)
		if kneel != null and not kneel.is_empty():
			_buf.blend_rect(kneel, Rect2i(0, 0, TILE_SRC, TILE_SRC), dst)
		return
	if _avatar_a == null or _cached_leader_class != GameState.party_leader_class():
		_cache_avatar_icons()
	var img := _avatar_b if _avatar_frame == 1 and _avatar_b != null else _avatar_a
	if img == null or img.is_empty():
		return
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
	## Apple II Color/Mono: static open gate — art has no EGA glow to rotate.
	if not _U4TileBankScript.uses_moongate_suck():
		return _overlay_slice(TILE_MOONGATE_OPEN)
	var frames := _ensure_moongate_suck_frames_for(TILE_MOONGATE_OPEN)
	if not frames.is_empty():
		return frames[_moongate_suck_i % frames.size()]
	return _overlay_slice(TILE_MOONGATE_OPEN)


func _ensure_moongate_suck_frames_for(tid: int) -> Array[Image]:
	if not _U4TileBankScript.uses_moongate_suck():
		return []
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
		if not _U4TileBankScript.uses_hgr_ntsc():
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
	## Ettin / Cyclops rocks use dedicated art (not shapes/055 with floor speckles).
	if tile_id == _WorldCreaturesScript.TILE_ROCKS:
		if _thrown_rocks_img != null and not _thrown_rocks_img.is_empty():
			return _thrown_rocks_img
	if is_horse_tile(tile_id):
		return _U4TileBankScript.keyed_copy(tile_id, _horse_stand_frame_id(tile_id))
	if _overlay_slices.has(tile_id):
		return _overlay_slices[tile_id] as Image
	var img := _slice_keyed_tile(tile_id)
	_overlay_slices[tile_id] = img
	return img


func _paint_party_marker() -> void:
	## Center tile: transport sprite, or class/Avatar 2-frame walk cycle.
	## Explore quakes shift the whole buffer in `_apply_view_shake`.
	if _apple2_party_is_grid_composed():
		return
	var dst := Vector2i((view_w / 2) * TILE_SRC, (view_h / 2) * TILE_SRC)
	if (
		_U4TileBankScript.uses_hgr_ntsc()
		and (_transport_tile < 0 or not is_horse_tile(_transport_tile))
	):
		var composed := _apple2_party_scroll_slice()
		if composed != null and not composed.is_empty():
			_buf.blend_rect(composed, Rect2i(0, 0, TILE_SRC, TILE_SRC), dst)
			return
	if _transport_tile >= 0:
		var ride: Image = null
		if is_horse_tile(_transport_tile):
			## Mounted: person-on-horse art (W/E), not the empty horse object tile.
			ride = _horse_rider_for_transport()
		else:
			ride = _overlay_slice(_transport_tile)
		if ride != null and not ride.is_empty():
			## Apple II Color mount is 34px wide: preserve delayed right-edge fringe.
			var rw := mini(ride.get_width(), _buf.get_width() - dst.x)
			var rh := mini(ride.get_height(), TILE_SRC)
			_buf.blend_rect(ride, Rect2i(0, 0, rw, rh), dst)
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
