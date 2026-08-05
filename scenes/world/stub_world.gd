extends Control

## Explore: top/bottom status bars + fixed 25×11 map.
## Message terminal: fixed 15-line grid (even pitch). Tab opens all 15;
## closed clips to the bottom 5 at the same pitch. Last line is always
## Ultima-style prompt + blue charset @ cursor animation (bottom-aligned history).

## Preload so world scene parses even if global class cache is stale.
const _TileRules := preload("res://src/map/tile_rules.gd")
const _MixPanel := preload("res://src/ui/mix_panel.gd")
const _UsePanel := preload("res://src/ui/use_panel.gd")
const _UseItems := preload("res://src/core/use_items.gd")
const _CombatMapData := preload("res://src/map/combat_map_data.gd")
const _SaveSlotPanel := preload("res://src/ui/save_slot_panel.gd")
const _SaveGame := preload("res://src/core/save_game.gd")
const _EscMenuPanel := preload("res://src/ui/esc_menu_panel.gd")
const _OptionsPanel := preload("res://src/ui/options_panel.gd")
const _CityMapData := preload("res://src/map/city_map_data.gd")
const _WorldPortals := preload("res://src/map/world_portals.gd")
const _CityFloorPortals := preload("res://src/map/city_floor_portals.gd")
const _U4TileBankScript := preload("res://src/map/u4_tile_bank.gd")
const _Moongates := preload("res://src/map/moongates.gd")
const _WorldCreaturesScript := preload("res://src/map/world_creatures.gd")
const _SearchItems := preload("res://src/core/search_items.gd")
const _CombatMaps := preload("res://src/map/combat_maps.gd")
const _CombatEncounter := preload("res://src/map/combat_encounter.gd")
## Preload — bare class_name can miss the global class cache (black screen).
const _FoeRosterScript := preload("res://src/ui/foe_roster.gd")

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
@onready var _foe_roster: VBoxContainer = %FoeRoster
@onready var _msg_block: Control = %MsgBlock

var _peer_overlay: PeerGemOverlay
var _ztats_panel: ZtatsPanel
var _ready_panel: ReadyPanel
var _wear_panel: WearPanel
var _mix_panel # MixPanel — preloaded script instance
var _use_panel # UsePanel — preloaded script instance
var _locate_label: Label
var _locate_on := false
var _ship_hull_hud: HBoxContainer
var _ship_hull_icon: TextureRect
var _ship_hull_lab: Label

const MOVE_HOLD_DELAY := 0.5
## World move repeat cadence (lower = faster). Horse matches foot unless galloping.
const MOVE_HOLD_INTERVAL_FOOT := 0.15
const MOVE_HOLD_INTERVAL_SHIP := 0.15
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
## Ship hull HUD — same X as Locate; Y on bottom bar while aboard.
const SHIP_HULL_HUD_INSET := Vector2(6, 0)
const SHIP_HULL_HUD_FONT_SIZE := 13
const SHIP_HULL_HUD_COLOR := Color(0.95, 0.9, 0.55, 1)
const SHIP_HULL_HUD_COLOR_LOW := Color(0.92, 0.28, 0.28, 1)
const SHIP_HULL_LOW_THRESHOLD := 20
const SHIP_HULL_ICON_SZ := 14.0

var _world := WorldMapData.new()
var _world_creatures = _WorldCreaturesScript.new()
var _tile_pos := Vector2i(83, 105)
## xu4 transportContext stub: foot / horse / ship.
enum Transport { FOOT, HORSE, SHIP }
var _transport: int = Transport.FOOT
var _transport_tile := -1
## xu4 horseSpeed: Yell toggles gallop (double-step). Cleared on X-it.
var _horse_gallop := false
## Ultima V-style ship cruise: Yell → Dir → keep sailing until Yell or land.
var _ship_cruise_dir := Vector2i.ZERO
## xu4 EventHandler interval: 1000/gameCyclesPerSecond (default 250ms).
var _world_clock_accum := 0.0
## xu4 gameTimeSinceLastCommand — auto Pass after > 20s idle (TurnController).
const AUTO_PASS_SEC := 20.0
var _idle_since_command := 0.0
var _ship_yell_await_dir := false
## Hull left with each frigate overlay (key "x,y") so re-boarding keeps damage.
var _ship_hulls: Dictionary = {}
## Last frigate left on the world map (for xu4-style hull regen while ashore).
var _parked_ship_tile := Vector2i(-1, -1)
var _move_cd := 0.0
var _hold_arm := 0.0
var _move_repeating := false
var _held_dir := Vector2i.ZERO
var _pending_cmd: int = U4Commands.Id.NONE
## Label shown while waiting on the same line: "Attack: Dir?" (xu4 style).
var _pending_cmd_name: String = ""
## After a directed command fires, ignore held direction until all dir keys up.
var _block_dir_until_keyup := false
## True while moongate travel flash is playing (blocks move/commands).
var _moongate_busy := false
## True while a cannonball is in flight (blocks move/commands).
var _cannon_busy := false
## True while Search is pausing on "Searching..." (blocks move/commands).
var _search_busy := false
## True while xu4 death sequence runs (blocks move/commands).
var _death_busy := false
## Map-pane blackout during death cutscene (xu4 VIEW_CUTSCENE / eraseMapArea).
var _death_blackout: ColorRect
var _death_fade_tween: Tween
## Combat arena session (battlefield open; turn loop later).
var _combat_active := false
## Victory announced; free leave via ESC / map-edge (no extra karma).
var _combat_victory_aftermath := false
## True while pacing delays / foe turns run — blocks combat input.
var _combat_resolving := false
## xu4 combat sleep wake (1/8) allowed. Camp ambush keeps this false until
## the first creature phase finishes so foes truly act first.
var _combat_allow_sleep_wake := true
## Gap after each unit acts (xu4 screenWait≈42ms is snappy; keep readable).
const COMBAT_TURN_GAP := 0.28
const COMBAT_HIT_FLASH_SEC := 0.14
## Victory ESC: cascade leave order 1→8 with a short beat between units.
const COMBAT_VICTORY_EXIT_GAP := 0.2
var _combat_saved_sides_open := false
var _combat_foe: Dictionary = {} ## wilderness creature pulled into the fight
## U5-style Attack aim: A → move cursor → A/Enter strike; Esc cancels.
var _combat_aiming := false
var _combat_aim_pos := Vector2i.ZERO
var _combat_aim_from := Vector2i.ZERO
var _combat_aim_weapon := 0
## party_slot → last attacked foe creatureTable slot (−1 / missing = none).
var _combat_last_aim_foe: Dictionary = {}
## foe_index → { klass: damage_dealt } for combat XP assist shares.
var _combat_foe_dmg: Dictionary = {}
## Pirate shots queued during moveObjects (animated after AI step).
var _pending_pirate_shots: Array[Dictionary] = []
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
## Combat R / xu4 readyWeapon(focus): fixed party slot, skip member pick.
var _ready_self_only := false
## xu4 wearArmor(): 0 = idle, 1 = pick member, 2 = pick armor.
var _wear_stage := 0
var _wear_cursor := 0
var _wear_slot := -1
## Improved Mix: 0 = idle, 1 = known list, 2 = reagent pick, 3 = wait spell letter (Make new).
var _mix_stage := 0
## Use (U): 0 = idle, 1 = pick item from list.
var _use_stage := 0
## Hole up & Camp: 0 = idle, 1 = resting, 2 = set watch? Y/N, 3 = pick guard.
var _camp_stage := 0
var _camp_rest_left := 0.0
## True if this rest will end as an ambush (rolled at camp start, not at timer end).
var _camp_ambush_pending := false
var _camp_map # CombatMapData
var _camp_guard_klass := -1
var _camp_guard_cursor := 0
## City chest Open: 0 = idle, 1 = Who opens? (digit / list Enter).
var _chest_open_stage := 0
var _chest_open_target := Vector2i(-1, -1)
var _chest_open_cursor := 0
## xu4 telescope Use via Search — wait for A–P city choice.
var _telescope_stage := 0
## True while xu4 immobilized (all asleep) auto-turns are queued.
var _immobilized_pending := false
## xu4 settings campTime default (Resting… animation seconds).
const CAMP_REST_SEC := 10.0
## Ambush fires after this many seconds at earliest (random in [min, full rest]).
const CAMP_AMBUSH_MIN_SEC := 3.0
## xu4 finishTurn Zzzzzz pause (~4 frames @ 24fps).
const IMMOBILIZED_SLEEP_SEC := 0.166
## xu4 death.cpp — deathStart(delay) + DeathController tick + revive.
## Pre-message (xu4 ~10s): delay 5s + controller 5s → remake: 5 + 3 hold + 2 fade.
const DEATH_PAUSE_SEC := 5.0 ## seconds between death dialogue lines (controller tick)
const DEATH_CONTROLLER_HOLD_SEC := 3.0 ## hold on map before first-line fade
const DEATH_FADE_OUT_SEC := 2.0 ## last part of first DeathController beat (fade to black)
const DEATH_NAME_WIDTH := 16 ## xu4 TEXT_AREA_W for centered avatar name
const DEATH_REVIVE_CASTLE := Vector2i(19, 8) ## lcb_2 throne room
const DEATH_LCB_WORLD := Vector2i(86, 107)
## Remake QoL: brief pause after "Searching..." so S can't be mashed.
## xu4 has no Search-specific delay (only finishTurn screenWait(1)).
const SEARCH_PAUSE_SEC := 0.45
## Quit & Save / Esc Load: 0 = idle, 1 = save picker, 2 = load picker.
var _save_stage := 0
var _save_panel # SaveSlotPanel
## True when the slot picker was opened from the Esc menu (return there after).
var _slot_from_esc := false
var _esc_menu # EscMenuPanel
var _options_panel # OptionsPanel
## City / castle visit (Enter). World position restored on leave.
var _city_map # CityMapData
var _city_return_pos := Vector2i.ZERO
## xu4 anger forgotten next visit; within one stay (incl. LCB floor changes), keep
## guards/LB on MOVE_ATTACK after alertGuards until the player leaves the place.
var _city_guards_alerted := false
## Per-.ULT emptied chests only (not open lids). Key = lowercase basename →
## { "x,y": true }. Leave/floor change closes lids; memory/save keep emptied spots.
var _city_chest_memory: Dictionary = {}
var _load_error: String = ""
var _esc_held := false
var _msg_lines: PackedStringArray = PackedStringArray()
var _sides_open := false
## N (New Order): temporarily show only the character roster panel.
var _order_opened_roster := false
## Bump to cancel a pending delayed roster slide-away.
var _order_close_token := 0
const ORDER_ROSTER_HOLD_SEC := 1.1
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
	## Saved games restore `_sides_open` from the slot.
	_sides_open = GameState.is_new_game
	_ensure_msg_terminal()
	_ensure_peer_overlay()
	_ensure_ztats_panel()
	_ensure_save_panel()
	_ensure_esc_menu()
	_ensure_options_panel()
	_ensure_locate_hud()
	if _compact_roster:
		_compact_roster.set_compact(true)
	if _roster:
		_roster.set_compact(false)
	## Keep saved / created party as-is (xu4: new game is solo).
	if GameState.party_order.is_empty():
		GameState.refresh_party_order()

	var path := _resolve_world_map_path()
	var loading_save := not GameState.pending_world_save.is_empty()

	if not _U4TileBankScript.ensure_loaded():
		_load_error = "shapes/ 타일 로드 실패"
	elif not _world.load_from_path(path):
		_load_error = "WORLD.MAP 로드 실패\n%s" % path
	else:
		_tile_pos = GameState.start_pos if GameState.start_pos != Vector2i.ZERO else Vector2i(83, 105)
		_map.setup(_world)
		if loading_save:
			_apply_world_save(GameState.pending_world_save)
			GameState.pending_world_save.clear()
		else:
			## Snap — animate would fire if start is 1 tile from MapView's default center.
			_map.set_center(_tile_pos, false)
			_place_temp_transports()
		_sync_moongate(true)

	call_deferred("_fit_explore_map")
	call_deferred("grab_focus")
	if not GameState.language_changed.is_connected(_on_language_changed):
		GameState.language_changed.connect(_on_language_changed)
	if not _load_error.is_empty():
		_push_message(_load_error)
		push_error(_load_error)
	else:
		_refresh_party()
		_refresh_ship_hull_hud()


func _place_temp_transports() -> void:
	## Stub: horse on nearby land + ship on nearby water for boarding tests.
	if _map == null or _world == null or not _world.loaded:
		return
	var horse := _find_nearby_tile(_tile_pos, false)
	var ship := _find_nearby_tile(_tile_pos, true)
	var items: Array[Vector3i] = []
	if horse != Vector2i(-1, -1):
		items.append(Vector3i(horse.x, horse.y, MapView.TILE_HORSE_W))
	if ship != Vector2i(-1, -1):
		items.append(Vector3i(ship.x, ship.y, MapView.TILE_SHIP_W))
	_map.set_overlays(items)


func _apply_world_save(w: Dictionary) -> void:
	## Restore position / transport / Tab panels / ship hulls / map overlays.
	## City saves store world portal as x,y plus city_fname + city_x/y.
	if w.is_empty() or _map == null:
		return
	_load_city_chest_memory(w.get("city_chests", {}))
	_tile_pos = Vector2i(int(w.get("x", _tile_pos.x)), int(w.get("y", _tile_pos.y)))
	_sides_open = bool(w.get("sides_open", _sides_open))
	_transport = int(w.get("transport", Transport.FOOT))
	_transport_tile = int(w.get("transport_tile", -1))
	_horse_gallop = bool(w.get("horse_gallop", false))
	_parked_ship_tile = Vector2i(
		int(w.get("parked_ship_x", -1)),
		int(w.get("parked_ship_y", -1))
	)
	_ship_hulls.clear()
	var hulls: Variant = w.get("ship_hulls", {})
	if typeof(hulls) == TYPE_DICTIONARY:
		for k in (hulls as Dictionary).keys():
			_ship_hulls[str(k)] = int((hulls as Dictionary)[k])
	## Prefer explicit overlay list (horses + ships on the map). Older saves
	## without `overlays` fall back to reconstructing ships from hull keys.
	if w.has("overlays"):
		_map.set_overlays(_overlays_from_save(w.get("overlays", [])))
	else:
		_map.set_overlays(_overlays_from_hull_fallback())
	if _world_creatures != null:
		_world_creatures.from_save(w.get("creatures", []))
		_sync_creatures_to_map()

	if bool(w.get("in_city", false)):
		_restore_city_from_save(w)
	else:
		_city_map = null
		## Load must snap: MapView defaults to (83,105) next to Britain, so a
		## nearby save is a 1-tile step and SMOOTH_SCROLL would animate once.
		_map.set_center(_tile_pos, false)
		if _transport != Transport.FOOT and _transport_tile >= 0:
			_map.set_transport_tile(_transport_tile)
		else:
			_map.set_transport_tile(-1)
		_sync_moongate(true)


func _restore_city_from_save(w: Dictionary) -> void:
	## Re-enter the saved .ULT at city-local coords; x,y are the world portal.
	var fname := str(w.get("city_fname", ""))
	var return_pos := Vector2i(
		int(w.get("city_return_x", w.get("x", _tile_pos.x))),
		int(w.get("city_return_y", w.get("y", _tile_pos.y)))
	)
	if fname.is_empty():
		var portal := _WorldPortals.portal_at(return_pos)
		fname = str(portal.get("fname", ""))
	if fname.is_empty():
		## Corrupt / old city save — fall back to world portal tile.
		_tile_pos = return_pos
		_map.set_center(_tile_pos, false)
		if _transport != Transport.FOOT and _transport_tile >= 0:
			_map.set_transport_tile(_transport_tile)
		else:
			_map.set_transport_tile(-1)
		return
	## If return coords drifted, recover portal world tile from fname.
	if _WorldPortals.portal_at(return_pos).is_empty():
		var by_name := _WorldPortals.portal_for_fname(fname)
		if not by_name.is_empty() and by_name.has("wx"):
			return_pos = Vector2i(int(by_name["wx"]), int(by_name["wy"]))
	var path := _CityMapData.resolve_u4_file(fname)
	var cmap = _CityMapData.new()
	if path.is_empty() or not cmap.load_from_path(path):
		_tile_pos = return_pos
		_map.set_center(_tile_pos, false)
		if _transport != Transport.FOOT and _transport_tile >= 0:
			_map.set_transport_tile(_transport_tile)
		else:
			_map.set_transport_tile(-1)
		return
	_city_return_pos = return_pos
	_city_map = cmap
	var local := Vector2i(
		clampi(int(w.get("city_x", 15)), 0, _CityMapData.WIDTH - 1),
		clampi(int(w.get("city_y", 15)), 0, _CityMapData.HEIGHT - 1)
	)
	_tile_pos = local
	## Outside rim plains follow the Enter gate, not the saved mid-city tile.
	var portal := _WorldPortals.portal_at(return_pos)
	if portal.is_empty():
		portal = _WorldPortals.portal_for_fname(fname)
	var spawn := Vector2i(
		int(portal.get("sx", local.x)),
		int(portal.get("sy", local.y))
	)
	_map.enter_city(cmap, local, _city_return_pos, spawn)
	_map.set_transport_tile(_transport_tile if _transport != Transport.FOOT else -1)
	_map.clear_moongate()
	_sync_creatures_to_map()


func _overlays_from_save(raw: Variant) -> Array[Vector3i]:
	var items: Array[Vector3i] = []
	if typeof(raw) != TYPE_ARRAY:
		return items
	for entry in raw as Array:
		if typeof(entry) == TYPE_DICTIONARY:
			var d: Dictionary = entry
			items.append(Vector3i(int(d.get("x", 0)), int(d.get("y", 0)), int(d.get("t", 0))))
		elif typeof(entry) == TYPE_ARRAY:
			var a: Array = entry
			if a.size() >= 3:
				items.append(Vector3i(int(a[0]), int(a[1]), int(a[2])))
	return items


func _overlays_from_hull_fallback() -> Array[Vector3i]:
	## Legacy saves: only had ship hull keys / parked ship, no horse overlays.
	var items: Array[Vector3i] = []
	for key in _ship_hulls.keys():
		var parts := str(key).split(",")
		if parts.size() != 2:
			continue
		var sx := int(parts[0])
		var sy := int(parts[1])
		if _transport == Transport.SHIP and sx == _tile_pos.x and sy == _tile_pos.y:
			continue
		items.append(Vector3i(sx, sy, MapView.TILE_SHIP_W))
	if (
		_transport != Transport.SHIP
		and _parked_ship_tile.x >= 0
		and _parked_ship_tile.y >= 0
	):
		var already := false
		for it in items:
			if it.x == _parked_ship_tile.x and it.y == _parked_ship_tile.y:
				already = true
				break
		if not already:
			items.append(Vector3i(_parked_ship_tile.x, _parked_ship_tile.y, MapView.TILE_SHIP_W))
	return items


func _find_nearby_tile(origin: Vector2i, want_water: bool) -> Vector2i:
	## Spiral search (skip origin): sailable water vs walkable land.
	for radius in range(1, 8):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var p := Vector2i(
					posmod(origin.x + dx, WorldMapData.WIDTH),
					posmod(origin.y + dy, WorldMapData.HEIGHT)
				)
				var tid := _world.tile_at(p.x, p.y)
				if want_water:
					if _TileRules.is_sailable(tid):
						return p
				elif _TileRules.walk_on(tid) != 0 and not _TileRules.is_water(tid):
					return p
	return Vector2i(-1, -1)


func _do_board() -> void:
	## xu4 board(): must be on foot; object underfoot must be horse/ship/balloon.
	if _transport != Transport.FOOT:
		_push_message(Locale.t("cmd_board_cant"), false)
		_finish_party_turn()
		return
	if _map == null:
		_push_message(Locale.t("cmd_board_what"), false)
		_finish_party_turn()
		return
	var tid := _map.overlay_at(_tile_pos)
	if tid < 0:
		_push_message(Locale.t("cmd_board_what"), false)
		_finish_party_turn()
		return
	if MapView.is_ship_tile(tid):
		_push_message(Locale.t("cmd_board_ship"), false)
		_transport = Transport.SHIP
		## Restore this frigate's stored hull (default full if first board).
		GameState.ship_hull = _take_ship_hull_at(_tile_pos)
		_parked_ship_tile = Vector2i(-1, -1)
	elif MapView.is_horse_tile(tid):
		_push_message(Locale.t("cmd_board_horse"), false)
		_transport = Transport.HORSE
		_horse_gallop = false
	else:
		_push_message(Locale.t("cmd_board_what"), false)
		_finish_party_turn()
		return
	_map.remove_overlay_at(_tile_pos)
	_transport_tile = tid
	_map.set_transport_tile(_transport_tile)
	_refresh_ship_hull_hud()
	_finish_party_turn()


func _do_xit() -> void:
	## xu4 exitTransport(): leave horse/ship as a map object underfoot.
	if _transport == Transport.FOOT or _map == null:
		_push_message(Locale.t("cmd_xit_what"), false)
		_finish_party_turn()
		return
	## Leave empty horse/ship facing as last ridden; gallop resets.
	var leave_tid := _transport_tile
	if leave_tid < 0:
		leave_tid = (
			MapView.TILE_SHIP_W if _transport == Transport.SHIP else MapView.TILE_HORSE_W
		)
	if _transport == Transport.SHIP:
		## Persist hull on this world cell so the same ship keeps its damage.
		_store_ship_hull_at(_tile_pos, GameState.ship_hull)
		_parked_ship_tile = _tile_pos
	_map.add_overlay(_tile_pos, leave_tid)
	_transport = Transport.FOOT
	_transport_tile = -1
	_horse_gallop = false
	_stop_ship_cruise()
	_map.set_transport_tile(-1)
	_push_message(Locale.t("cmd_xit"), false)
	_refresh_ship_hull_hud()
	_finish_party_turn()


func _do_yell() -> void:
	## Horse: xu4 Giddyup/Whoa. Ship: U5-style cruise (Yell → Dir → auto-sail).
	if _transport == Transport.HORSE:
		_horse_gallop = not _horse_gallop
		if _horse_gallop:
			_push_message(Locale.t("cmd_yell_giddyup"), false)
		else:
			_push_message(Locale.t("cmd_yell_whoa"), false)
		_finish_party_turn()
		return
	if _transport == Transport.SHIP:
		if _ship_cruise_dir != Vector2i.ZERO:
			_stop_ship_cruise()
			## Ship cruise halt — not horse "Whoa".
			_push_message(Locale.t("cmd_yell_ship_stop"), false)
			_finish_party_turn()
			return
		if _ship_yell_await_dir:
			_clear_ship_yell_await()
			return
		_clear_pending_dir()
		_ship_yell_await_dir = true
		_layout_prompt_row()
		return
	_push_message(Locale.t("cmd_yell_what"), false)
	_finish_party_turn()


func _clear_ship_yell_await() -> void:
	_ship_yell_await_dir = false
	_layout_prompt_row()


func _stop_ship_cruise() -> void:
	_ship_cruise_dir = Vector2i.ZERO
	_ship_yell_await_dir = false
	_layout_prompt_row()


func _start_ship_cruise(dir: Vector2i) -> void:
	_ship_yell_await_dir = false
	_ship_cruise_dir = dir
	_update_transport_facing(dir)
	_layout_prompt_row()
	_push_message(Locale.t("cmd_sail", [_direction_label(dir, false)]), false)
	## First beat sails immediately (facing already set — no separate turn turn).
	_move_cd = 0.0
	_try_ship_cruise_step()


func _try_ship_cruise_step() -> void:
	if _ship_cruise_dir == Vector2i.ZERO or _transport != Transport.SHIP:
		_stop_ship_cruise()
		return
	if _map != null and _map.is_scrolling():
		_map.finish_scroll()
	var dir := _ship_cruise_dir
	## Stay facing the cruise heading.
	if dir != _ship_facing_dir():
		_update_transport_facing(dir)
	var next := Vector2i(
		posmod(_tile_pos.x + dir.x, WorldMapData.WIDTH),
		posmod(_tile_pos.y + dir.y, WorldMapData.HEIGHT)
	)
	if not _can_move_to(next):
		_stop_ship_cruise()
		_damage_ship_from_grounding(dir)
		_push_message(Locale.t("cmd_yell_land"), false)
		_finish_party_turn()
		_arm_hold_after_step(true)
		return
	## xu4 wind: same Slow progress rules as manual sail (incl. 8-way diagonals).
	if GameState.ship_slowed_by_wind(dir):
		_push_message(Locale.t("cmd_slow_progress"), false)
		_finish_party_turn()
		_move_cd = _move_hold_interval()
		return
	## Quiet successful cruise steps — avoid spamming Sail messages.
	_apply_world_step(next, dir, false)
	_finish_party_turn()
	_move_cd = _move_hold_interval()


func _ship_hull_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]


func _take_ship_hull_at(tile: Vector2i) -> int:
	## Pop stored hull for this overlay cell (full if never damaged).
	var key := _ship_hull_key(tile)
	if _ship_hulls.has(key):
		var h: int = int(_ship_hulls[key])
		_ship_hulls.erase(key)
		return clampi(h, 0, GameState.SHIP_HULL_WHEEL)
	return GameState.SHIP_HULL_MAX


func _store_ship_hull_at(tile: Vector2i, hull: int) -> void:
	_ship_hulls[_ship_hull_key(tile)] = clampi(hull, 0, GameState.SHIP_HULL_WHEEL)


func _damage_ship_from_grounding(dir: Vector2i) -> void:
	## Y-cruise grounding: headwind 0, else -5.
	var dmg := GameState.ship_grounding_damage(dir)
	if dmg > 0:
		GameState.ship_hull = clampi(
			GameState.ship_hull - dmg,
			0,
			GameState.SHIP_HULL_WHEEL
		)
		_refresh_ship_hull_hud()
	if _map != null:
		_map.shake_ship()


func _can_move_to(dest: Vector2i) -> bool:
	## xu4 terrain rules via TileRules (walk / sail / horse creature-walk).
	if _is_in_city():
		if _city_map == null or not _city_map.loaded:
			return false
		## xu4: cannot walk through townsfolk.
		if _city_map.person_tile_at(dest.x, dest.y) >= 0:
			return false
		var c_dest: int = int(_city_map.effective_tile_at(dest.x, dest.y))
		var c_from: int = int(_city_map.effective_tile_at(_tile_pos.x, _tile_pos.y))
		var cdir := Vector2i(
			clampi(dest.x - _tile_pos.x, -1, 1),
			clampi(dest.y - _tile_pos.y, -1, 1)
		)
		return _TileRules.can_avatar_enter(
			c_dest, c_from, cdir, false, _transport == Transport.HORSE
		)
	if _world == null or not _world.loaded:
		return true
	## Do not step onto (or through) wilderness monsters — combat engages later.
	if _world_creatures != null and _world_creatures.creature_at(dest) >= 0:
		return false
	var dest_id := _effective_world_tid(dest)
	var from_id := _effective_world_tid(_tile_pos)
	var dir := Vector2i(
		dest.x - _tile_pos.x,
		dest.y - _tile_pos.y
	)
	## Wrap-aware direction (shortest step on toroidal world).
	if dir.x > WorldMapData.WIDTH / 2:
		dir.x -= WorldMapData.WIDTH
	elif dir.x < -WorldMapData.WIDTH / 2:
		dir.x += WorldMapData.WIDTH
	if dir.y > WorldMapData.HEIGHT / 2:
		dir.y -= WorldMapData.HEIGHT
	elif dir.y < -WorldMapData.HEIGHT / 2:
		dir.y += WorldMapData.HEIGHT
	dir = Vector2i(clampi(dir.x, -1, 1), clampi(dir.y, -1, 1))

	## xu4 WITH_OBJECTS: standing on / entering ship|horse uses that tile's walk rule.
	if _transport == Transport.FOOT and _map != null:
		var over := _map.overlay_at(dest)
		if MapView.is_ship_tile(over) or MapView.is_horse_tile(over):
			## Ship/horse tiles are walkable; still need walk-off from previous terrain.
			return _TileRules.can_walk_off(from_id, dir)

	return _TileRules.can_avatar_enter(
		dest_id,
		from_id,
		dir,
		_transport == Transport.SHIP,
		_transport == Transport.HORSE
	)


func _effective_world_tid(pos: Vector2i) -> int:
	## xu4 tileTypeAt — moongate annotation overrides base WORLD.MAP terrain.
	if _map != null:
		var gate := _map.moongate_tile_at(pos)
		if gate >= 0:
			return gate
	if _world != null and _world.loaded:
		return int(_world.tile_at(pos.x, pos.y))
	return 4


func _update_transport_facing(dir: Vector2i) -> void:
	if _map == null or _transport == Transport.FOOT:
		return
	if _transport == Transport.SHIP:
		_transport_tile = MapView.ship_tile_for_dir(dir)
		_map.set_transport_tile(_transport_tile)
	elif _transport == Transport.HORSE:
		var facing := MapView.horse_tile_for_dir(dir)
		if facing >= 0:
			_transport_tile = facing
			_map.set_transport_tile(_transport_tile)


func _ship_facing_dir() -> Vector2i:
	return MapView.dir_for_ship_tile(_transport_tile)


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
	_layout_ship_hull_hud()
	_refresh_message_view()


func _style_bars() -> void:
	pass


func _style_side_panels() -> void:
	if _left_pane is PanelContainer:
		(_left_pane as PanelContainer).add_theme_stylebox_override(
			"panel", _make_edge_panel(_FoeRosterScript.ROSTER_STYLE_PAD, 0, 0, 2, 0)
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
	var left_margin := get_node_or_null("RootCol/MapPane/LeftPane/LeftTopMargin") as MarginContainer
	if _foe_roster and left_margin:
		_foe_roster.apply_shared_pad_to_margins(left_margin)
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
	if _foe_roster:
		_foe_roster.set_tile_size(tile_size)
	var tile_h := tile_size.y
	var center_w := float(MapView.VIEW_H) * tile_w
	var overflow := maxf(pane_sz.x - center_w, 0.0)
	var left_w := floorf(overflow * 0.5)
	var right_w := overflow - left_w
	## Snap right strip so x + w lands exactly on the pane's right edge (no 1px tile peek).
	var right_open_x := floorf(pane_sz.x - right_w)
	right_w = pane_sz.x - right_open_x
	var compact_w := float(ceili(float(COMPACT_RIGHT_TILES) * tile_w))
	var compact_x := pane_sz.x - compact_w
	## Ceil the roster band so the 5th tile row is fully covered.
	var top_h := minf(
		float(ceili(float(RIGHT_TOP_TILES) * tile_h)),
		maxf(pane_sz.y - 24.0, 1.0)
	)
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
	if _foe_roster:
		_foe_roster.set_open_panel_height(top_h)
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
		"compact_x": compact_x,
		"top_h": top_h,
		"bottom_closed_h": bottom_closed_h,
		"bottom_open_h": bottom_open_h,
		"left_open_x": 0.0,
		"left_closed_x": -left_w,
		"right_open_x": right_open_x,
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
	_msg_full_h = g["bottom_open_h"]
	_msg_open_x = g["right_open_x"]
	_msg_rw = g["pane_w"] - _msg_open_x
	_msg_h = clampf(visible_h, 8.0, _msg_full_h)
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
	var pane_w := _map_pane.size.x
	var pane_h := _map_pane.size.y
	var h := clampf(_msg_h, 8.0, _msg_full_h)
	var x := _msg_open_x
	if x < 0.0:
		x = pane_w - _msg_rw
	## Width always reaches the pane's right edge.
	var w := pane_w - x
	_msg_rw = w
	_right_bottom.custom_minimum_size = Vector2(w, h)
	_right_bottom.size = Vector2(w, h)
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
	if _mix_stage == 1:
		return MSG_PROMPT + Locale.t("mix_title")
	if _mix_stage == 2:
		return MSG_PROMPT + Locale.t("mix_title")
	if _mix_stage == 3:
		return MSG_PROMPT + Locale.t("mix_for_spell")
	if _use_stage == 1:
		return MSG_PROMPT + Locale.t("cmd_use_which")
	if _ztats_stage == 1:
		return MSG_PROMPT + Locale.t("cmd_ztats_for")
	if _camp_stage == 2:
		return MSG_PROMPT + Locale.t("cmd_camp_set_watch")
	if _camp_stage == 3:
		return MSG_PROMPT + Locale.t("cmd_camp_who_guards")
	if _chest_open_stage == 1:
		return MSG_PROMPT + Locale.t("cmd_chest_who_opens")
	if _telescope_stage == 1:
		return MSG_PROMPT + Locale.t("cmd_telescope_select")
	if _save_stage == 1:
		return MSG_PROMPT + Locale.t("save_title")
	if _save_stage == 2:
		return MSG_PROMPT + Locale.t("load_title")
	if _options_panel_is_open():
		return MSG_PROMPT + Locale.t("esc_options_title")
	if _esc_menu_is_open():
		return MSG_PROMPT + Locale.t("esc_menu_title")
	if _order_stage == 1:
		return MSG_PROMPT + Locale.t("cmd_exchange")
	if _order_stage == 2:
		return MSG_PROMPT + Locale.t("cmd_with")
	if _combat_aiming:
		return MSG_PROMPT + Locale.t("cmd_attack_aim")
	if _pending_cmd != U4Commands.Id.NONE and not _pending_cmd_name.is_empty():
		return MSG_PROMPT + Locale.need_dir_prompt(_pending_cmd_name)
	if _ship_yell_await_dir:
		return MSG_PROMPT + Locale.need_dir_prompt(
			U4Commands.label(U4Commands.Id.YELL, GameState.lang_short())
		)
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
	var cw: float = g["compact_w"]
	var ch: float = g["compact_h"]
	var ph: float = g["pane_h"]
	var pw: float = g["pane_w"]
	var top_h: float = g["top_h"]
	var bot_closed_h: float = g["bottom_closed_h"]
	var bot_open_h: float = g["bottom_open_h"]
	var right_open_x: float = g["right_open_x"]
	var rw: float = pw - right_open_x
	if ph < 1.0 or rw < 1.0:
		return

	## Full Tab open, or New Order peek (character panel only).
	var roster_open := _sides_open or _order_opened_roster

	_left_pane.custom_minimum_size = Vector2(lw, ph)
	_left_pane.size = Vector2(lw, ph)

	var left_x: float = g["left_open_x"] if _sides_open else g["left_closed_x"]
	var right_closed_x: float = g["right_closed_x"]
	var compact_x: float = g["compact_x"]

	if _compact_pane:
		_compact_pane.custom_minimum_size = Vector2(cw, ch)
		_compact_pane.size = Vector2(cw, ch)
		_compact_pane.position = Vector2(compact_x, 0.0)
		if _compact_roster:
			_compact_roster.relayout()

	_msg_full_h = bot_open_h
	_msg_rw = rw
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
	_layout_ship_hull_hud()


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


func _await_side_tween() -> void:
	## Wait out an in-flight side-panel open/close tween (if any).
	if _side_tween != null and is_instance_valid(_side_tween) and _side_tween.is_running():
		await _side_tween.finished


func _open_sides_for_combat() -> void:
	## If panels were closed, animate open before the arena appears.
	_combat_saved_sides_open = _sides_open
	_order_opened_roster = false
	var need_anim := not _sides_open
	_sides_open = true
	if need_anim:
		_refresh_party()
		_layout_side_panels(true)
		await _await_side_tween()
	else:
		_layout_side_panels(false)


func _restore_sides_after_combat() -> void:
	## After the world map is back: snap open, or animate closed if that was the prior state.
	_order_opened_roster = false
	if _combat_saved_sides_open:
		_sides_open = true
		_layout_side_panels(false)
	else:
		_sides_open = false
		_layout_side_panels(true)
		await _await_side_tween()


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
	var right_open_x: float = g["right_open_x"]
	var rw: float = g["pane_w"] - right_open_x
	var top_h: float = g["top_h"]
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
	## xu4 GameController::timerFired — real-time clock even while menus/peer open.
	_tick_world_clock(delta)
	if _moongate_busy or _cannon_busy or _search_busy or _death_busy:
		return
	## Combat arena: turn input is key-driven (no world cruise / no auto-pass),
	## but Ready / Ztats / chest pick still need the same cursor repeat ticks.
	if _combat_active:
		if _ztats_stage == 1 or _ready_stage == 1 or _chest_open_stage == 1:
			_tick_select_cursor()
		elif _ready_stage == 2:
			_tick_ready_weapon_cursor()
		elif (
			not _combat_resolving
			and not _combat_victory_aftermath
			and not _combat_aiming
			and _map != null
			and _map.is_in_combat()
		):
			## Sleeping/dead focus — auto-skip without waiting for a key (xu4).
			var fk := _map.get_combat_focus_klass()
			if fk >= 0 and GameState.is_member_disabled(fk):
				_combat_finish_member_turn()
		return
	## xu4 force pass if no commands within last 20 seconds (explore only).
	_tick_auto_pass(delta)

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
	## Hole-up Resting… must tick even though put_party_to_sleep immobilizes
	## the party (solo / no-watch). Otherwise the timer never expires.
	if _camp_stage == 1:
		_tick_camp_rest(delta)
		return
	## All asleep: Zzzzzz auto-turns own the clock — no player move/cruise.
	if _is_party_asleep_locked():
		return
	## Z/N/R/W/M pick lists: same hold timing as world move; wrap at ends.
	if _ztats_stage == 1 or _order_stage != 0 or _ready_stage == 1 or _wear_stage == 1 or _mix_stage == 1 or _mix_stage == 2 or _use_stage == 1 or _camp_stage == 3 or _chest_open_stage == 1 or _save_stage == 1 or _save_stage == 2 or _esc_menu_is_open() or _options_panel_is_open():
		_tick_select_cursor()
		return
	if _ready_stage == 2:
		_tick_ready_weapon_cursor()
		return
	if _wear_stage == 2:
		_tick_wear_armor_cursor()
		return
	if _ztats_stage != 0 or _mix_stage != 0 or _use_stage != 0 or _camp_stage != 0 or _chest_open_stage != 0 or _telescope_stage != 0 or _save_stage != 0 or _esc_menu_is_open() or _options_panel_is_open():
		return

	## U5-style ship cruise: keep sailing without holding a key.
	if _ship_cruise_dir != Vector2i.ZERO:
		if _transport != Transport.SHIP:
			_stop_ship_cruise()
			return
		var steer := _read_move_dir()
		if steer != Vector2i.ZERO and not _block_dir_until_keyup:
			if steer == -_ship_cruise_dir:
				## Reverse key: stop only — keep current facing, no turn.
				_stop_ship_cruise()
				_push_message(Locale.t("cmd_yell_ship_stop"), false)
				_finish_party_turn()
				_block_dir_until_keyup = true
				_move_repeating = false
				_hold_arm = 0.0
				_held_dir = steer
				return
			elif steer != _ship_cruise_dir:
				## Other arrows: change cruise heading (and face that way).
				_ship_cruise_dir = steer
				_update_transport_facing(steer)
				_push_message(Locale.t("cmd_sail", [_direction_label(steer, false)]), false)
				_block_dir_until_keyup = true
				_move_repeating = false
				_hold_arm = 0.0
				_held_dir = steer
				_move_cd = 0.0
		elif steer == Vector2i.ZERO:
			_block_dir_until_keyup = false
		if _move_cd > 0.0:
			return
		_try_ship_cruise_step()
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

	## Ship Yell: waiting for a cruise heading.
	if _ship_yell_await_dir:
		_start_ship_cruise(dir)
		_block_dir_until_keyup = true
		_move_repeating = false
		_hold_arm = 0.0
		return

	## xu4 ship: must face the direction before sailing (turn costs the step).
	if not _is_in_city() and _transport == Transport.SHIP and dir != _ship_facing_dir():
		_update_transport_facing(dir)
		_push_message(Locale.t("cmd_turn", [_direction_label(dir, false)]), false)
		_finish_party_turn()
		_arm_hold_after_step(true)
		return

	var next: Vector2i
	if _is_in_city():
		next = Vector2i(_tile_pos.x + dir.x, _tile_pos.y + dir.y)
		## xu4 borderbehavior: exit — leave city when stepping off the map.
		if (
			next.x < 0 or next.y < 0
			or next.x >= _CityMapData.WIDTH
			or next.y >= _CityMapData.HEIGHT
		):
			_exit_city()
			_finish_party_turn()
			_arm_hold_after_step(true)
			return
	else:
		next = Vector2i(
			posmod(_tile_pos.x + dir.x, WorldMapData.WIDTH),
			posmod(_tile_pos.y + dir.y, WorldMapData.HEIGHT)
		)
	if not _can_move_to(next):
		_push_message(Locale.t("cmd_blocked"), false)
		_finish_party_turn()
		_arm_hold_after_step(true)
		return
	## xu4 ship: slowedByWind before the hull moves (into / with wind).
	if not _is_in_city() and _transport == Transport.SHIP and GameState.ship_slowed_by_wind(dir):
		_push_message(Locale.t("cmd_slow_progress"), false)
		_finish_party_turn()
		_arm_hold_after_step(true)
		return
	## xu4 foot/horse: slowedByTile on the destination (forest/hills/…) — world and city.
	if (
		(_transport == Transport.FOOT or _transport == Transport.HORSE)
		and _TileRules.slowed_by_tile(_terrain_tid_at(next))
	):
		_push_message(Locale.t("cmd_slow_progress"), false)
		_finish_party_turn()
		_arm_hold_after_step(true)
		return
	_apply_world_step(next, dir)
	## xu4 checkMoongates after foot/horse step (before gallop second step).
	if _try_moongate_travel():
		_finish_party_turn()
		_arm_hold_after_step(true)
		return
	## xu4 horse gallop: second step after a short beat (same keypress).
	if not _is_in_city() and _transport == Transport.HORSE and _horse_gallop:
		var next2 := Vector2i(
			posmod(_tile_pos.x + dir.x, WorldMapData.WIDTH),
			posmod(_tile_pos.y + dir.y, WorldMapData.HEIGHT)
		)
		if _can_move_to(next2):
			var slow2 := _TileRules.slowed_by_tile(_terrain_tid_at(next2))
			if slow2:
				## Second gallop step stalls — stay put, turn already continues below.
				_push_message(Locale.t("cmd_slow_progress"), false)
			else:
				_apply_world_step(next2, dir, false)
				if _try_moongate_travel():
					_finish_party_turn()
					_arm_hold_after_step(true)
					return
		elif _map != null:
			## Only one tile cleared — soft bump like ship grounding (FX only).
			_map.shake_ship()
	## Gallop still ends one party turn (xu4 finishTurn once per key).
	_finish_party_turn()
	_arm_hold_after_step(true)


func _terrain_tid_at(pos: Vector2i) -> int:
	## Destination terrain for slowedByTile (annotations count like xu4 tileTypeAt).
	if _is_in_city() and _city_map != null and _city_map.loaded:
		return int(_city_map.effective_tile_at(pos.x, pos.y))
	return _effective_world_tid(pos)


func _apply_world_step(next: Vector2i, dir: Vector2i, with_message: bool = true) -> void:
	_tile_pos = next
	_update_transport_facing(dir)
	if _map != null:
		_map.set_center(_tile_pos)
	_refresh_locate_hud()
	if with_message:
		_push_move_message(dir)
	## xu4: south toward Shrine of Humility — daemons unless Horn aura active.
	if not _is_in_city() and _world_creatures != null:
		if _world_creatures.try_humility_daemon_ambush(dir, _tile_pos) > 0:
			_sync_creatures_to_map()


func _reset_hold_state() -> void:
	_move_repeating = false
	_hold_arm = 0.0
	_move_cd = 0.0
	_held_dir = Vector2i.ZERO


func _move_hold_delay() -> float:
	return MOVE_HOLD_DELAY


func _move_hold_interval() -> float:
	## Horse (incl. gallop) and ship use the same key-repeat as foot;
	## gallop speed comes from the extra step, not a shorter interval.
	if _transport == Transport.SHIP:
		return MOVE_HOLD_INTERVAL_SHIP
	return MOVE_HOLD_INTERVAL_FOOT


func _arm_hold_after_step(world_move: bool = false) -> void:
	## UI lists keep a steady cadence; world walk/ride uses transport speed.
	if world_move:
		_move_cd = _move_hold_interval()
		if _move_repeating:
			_hold_arm = 0.0
		else:
			_move_repeating = true
			_hold_arm = _move_hold_delay()
		return
	_move_cd = MOVE_HOLD_INTERVAL_FOOT
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
	elif _mix_stage == 1 or _mix_stage == 2:
		_nudge_mix_cursor(step)
	elif _use_stage == 1:
		_nudge_use_cursor(step)
	elif _camp_stage == 3:
		_nudge_camp_guard_cursor(step)
	elif _chest_open_stage == 1:
		_nudge_chest_open_cursor(step)
	elif _save_stage == 1 or _save_stage == 2:
		_nudge_save_cursor(step)
	elif _esc_menu_is_open():
		_nudge_esc_menu_cursor(step)
	elif _options_panel_is_open():
		_nudge_options_cursor(step)
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
	if _mix_stage != 0:
		_close_mix(true)
		return
	if _save_stage != 0:
		_cancel_save(true)
		return
	if _camp_stage == 1:
		## Resting… — Esc does nothing (Tab alone may toggle panels).
		return
	if _camp_stage == 2 or _camp_stage == 3:
		_cancel_camp(true)
		return
	if _chest_open_stage != 0:
		_cancel_chest_open(true)
		return
	if _telescope_stage != 0:
		_cancel_telescope(true)
		return
	if _ready_stage != 0:
		_close_ready(true)
		return
	if _wear_stage != 0:
		_close_wear(true)
		return
	if _use_stage != 0:
		_close_use(true)
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
		return
	if _options_panel_is_open():
		_close_options_panel(true)
		return
	if _esc_menu_is_open():
		_close_esc_menu()
		return
	_open_esc_menu()


func _input(event: InputEvent) -> void:
	if _death_busy:
		get_viewport().set_input_as_handled()
		return
	if _combat_active:
		## Combat keys handled in _unhandled_input; block Tab panel toggle.
		if event is InputEventKey and event.pressed and not event.echo:
			var ck := event as InputEventKey
			if ck.keycode == KEY_TAB or ck.physical_keycode == KEY_TAB:
				get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		## Peer gem: only Esc / Space / Enter dismiss; swallow everything else.
		if _peer_overlay != null and _peer_overlay.is_open():
			if _is_peer_dismiss_key(k):
				_close_peer_overlay()
			get_viewport().set_input_as_handled()
			return
		if k.keycode == KEY_TAB or k.physical_keycode == KEY_TAB:
			## Ztats / Ready / Wear / Mix / camp pick open: don't collapse/expand side panels.
			## Camp rest allows Tab so inventory panels stay reachable.
			if (
				_ztats_stage != 0
				or _ready_stage != 0
				or _wear_stage != 0
				or _mix_stage != 0
				or _use_stage != 0
				or _camp_stage == 2
				or _camp_stage == 3
				or _chest_open_stage != 0
				or _telescope_stage != 0
				or _save_stage != 0
				or _esc_menu_is_open()
				or _options_panel_is_open()
			):
				get_viewport().set_input_as_handled()
				return
			_toggle_side_panels()
			get_viewport().set_input_as_handled()
			return


func _unhandled_input(event: InputEvent) -> void:
	## Ztats / Ready / Wear / Mix / Camp / Chest Open / Telescope / Save / Load / Esc menu / Options / New Order.
	if _moongate_busy or _cannon_busy or _search_busy or _death_busy:
		get_viewport().set_input_as_handled()
		return
	if _combat_active:
		## Nested UIs opened from combat (Ready / Use / Ztats / Open Who) before arena keys.
		if _ready_stage != 0:
			if _handle_ready_input(event):
				get_viewport().set_input_as_handled()
			elif event.is_pressed():
				get_viewport().set_input_as_handled()
			return
		if _use_stage != 0:
			if _handle_use_input(event):
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
		if _chest_open_stage != 0:
			if _handle_chest_open_input(event):
				get_viewport().set_input_as_handled()
			elif event.is_pressed():
				get_viewport().set_input_as_handled()
			return
		if _pending_cmd != U4Commands.Id.NONE:
			if event is InputEventKey and event.pressed and not event.echo:
				if _handle_combat_pending_dir(event as InputEventKey):
					get_viewport().set_input_as_handled()
			elif event.is_pressed():
				get_viewport().set_input_as_handled()
			return
		if _handle_combat_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if _save_stage != 0:
		if _handle_save_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if _options_panel_is_open():
		if _handle_options_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if _esc_menu_is_open():
		if _handle_esc_menu_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if _camp_stage != 0:
		if _handle_camp_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if _telescope_stage != 0:
		if _handle_telescope_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if _chest_open_stage != 0:
		if _handle_chest_open_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if _mix_stage != 0:
		if _handle_mix_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if _use_stage != 0:
		if _handle_use_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
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
		## ⌘S / Ctrl+S — quick save to loaded/last slot (or open picker on new game).
		if _is_quick_save_key(event):
			_do_quick_save()
			get_viewport().set_input_as_handled()
			return
		## xu4 immobilized (all asleep): no commands until someone wakes.
		if _is_party_asleep_locked():
			get_viewport().set_input_as_handled()
			return
		## Ctrl+L: toggle persistent Locate HUD (sextant required).
		if event.ctrl_pressed and _is_locate_key(event):
			_toggle_locate_hud()
			get_viewport().set_input_as_handled()
			return
		## Ctrl+K: dump current virtue karma to the message log.
		if event.ctrl_pressed and _is_karma_key(event):
			_do_show_karma()
			get_viewport().set_input_as_handled()
			return
		## Waiting for a direction (A/G/J/O/T or ship Yell) — same line as "Attack: Dir?".
		if _pending_cmd != U4Commands.Id.NONE or _ship_yell_await_dir:
			if _is_direction_key(event):
				return
			## xu4: Space / Enter cancel Dir? without a message.
			if _is_dir_cancel_key(event):
				_clear_pending_dir()
				_clear_ship_yell_await()
				get_viewport().set_input_as_handled()
				return
			## Any other key → classic grey "What?" (no prompt), abort Dir?.
			_clear_pending_dir()
			_clear_ship_yell_await()
			_push_message(Locale.t("cmd_what"), false)
			get_viewport().set_input_as_handled()
			return
		var cmd := U4Commands.from_event(event)
		if cmd != U4Commands.Id.NONE:
			## Starting another command cancels an in-progress ship cruise await.
			if cmd != U4Commands.Id.YELL and _ship_yell_await_dir:
				_clear_ship_yell_await()
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
	## xu4 fire(): not on a ship → "Fire What?"; else "Fire Cannon!" + Dir?
	if cmd == U4Commands.Id.FIRE:
		_clear_pending_dir()
		_clear_pending_order()
		_close_ztats(false)
		_close_ready(false)
		_close_wear(false)
		_close_mix(false)
		_close_use(false)
		_close_camp(false)
		_cancel_chest_open(false)
		_close_save(false)
		if _transport != Transport.SHIP or _is_in_city():
			_push_message(Locale.t("cmd_fire_what"), false)
			_finish_party_turn()
			return
		_push_message(Locale.t("cmd_fire_cannon"), false)
		_pending_cmd = cmd
		_pending_cmd_name = Locale.t("cmd_fire_dir")
		_layout_prompt_row()
		return
	if U4Commands.NEEDS_DIRECTION.get(cmd, false):
		## xu4: print "Attack: " then "Dir?" on the *same* line and wait.
		_clear_pending_order()
		_close_ztats(false)
		_close_ready(false)
		_close_wear(false)
		_close_mix(false)
		_close_use(false)
		_close_camp(false)
		_cancel_chest_open(false)
		_close_save(false)
		_pending_cmd = cmd
		_pending_cmd_name = name
		_layout_prompt_row()
		return
	_clear_pending_dir()
	_clear_pending_order()
	_close_ztats(false)
	_close_ready(false)
	_close_wear(false)
	_close_mix(false)
	_close_use(false)
	_close_camp(false)
	_cancel_chest_open(false)
	_cancel_telescope(false)
	_close_save(false)
	if cmd == U4Commands.Id.SEARCH:
		_do_search()
	elif cmd == U4Commands.Id.PEER:
		_do_peer()
	elif cmd == U4Commands.Id.NEW_ORDER:
		_do_new_order()
	elif cmd == U4Commands.Id.ZTATS:
		_do_ztats()
	elif cmd == U4Commands.Id.READY:
		_do_ready()
	elif cmd == U4Commands.Id.WEAR:
		_do_wear()
	elif cmd == U4Commands.Id.MIX:
		_do_mix()
	elif cmd == U4Commands.Id.USE:
		_do_use()
	elif cmd == U4Commands.Id.HOLE_UP:
		_do_hole_up()
	elif cmd == U4Commands.Id.ENTER:
		_do_enter()
	elif cmd == U4Commands.Id.KLIMB:
		_do_klimb()
	elif cmd == U4Commands.Id.DESCEND:
		_do_descend()
	elif cmd == U4Commands.Id.BOARD:
		_do_board()
	elif cmd == U4Commands.Id.XIT:
		_do_xit()
	elif cmd == U4Commands.Id.YELL:
		_do_yell()
	elif cmd == U4Commands.Id.LOCATE:
		if not GameState.has_sextant:
			_push_message(Locale.t("cmd_locate_what"), false)
		else:
			_push_message(Locale.t("cmd_locate", [
				name,
				_format_u4_sextant(_tile_pos.x),
				_format_u4_sextant(_tile_pos.y),
			]))
		_finish_party_turn()
	elif cmd == U4Commands.Id.QUIT_SAVE:
		_do_quit_save()
	elif cmd == U4Commands.Id.PASS:
		_push_message(Locale.t("cmd_fired", [name]))
		_finish_party_turn()
	else:
		_push_message(Locale.t("cmd_stub", [letter, name]))
		_finish_party_turn()


func _ensure_peer_overlay() -> void:
	if _peer_overlay != null or _map_pane == null:
		return
	_peer_overlay = PeerGemOverlay.new()
	_peer_overlay.name = "PeerGemOverlay"
	_map_pane.add_child(_peer_overlay)


func _is_locate_key(event: InputEventKey) -> bool:
	return event.keycode == KEY_L or event.physical_keycode == KEY_L


func _is_karma_key(event: InputEventKey) -> bool:
	return event.keycode == KEY_K or event.physical_keycode == KEY_K


func _do_show_karma() -> void:
	## Remake QoL: e.g. H55 C50 V50 J55 S50 H50 S50 H50 (first letter; 0→00).
	var parts: PackedStringArray = PackedStringArray()
	for i in 8:
		var raw := 0
		if i < GameState.karma.size():
			raw = int(GameState.karma[i])
		var name := Virtues.name_of(i, "en")
		var letter := name.substr(0, 1).to_upper() if not name.is_empty() else "?"
		parts.append("%s%02d" % [letter, clampi(raw, 0, 99)])
	_push_message(" ".join(parts), false)


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


func _ensure_ship_hull_hud() -> void:
	## Icon + hull value on the bottom bar (right of gems / Locate column).
	if _ship_hull_hud != null:
		return
	_ship_hull_hud = HBoxContainer.new()
	_ship_hull_hud.name = "ShipHullHud"
	_ship_hull_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ship_hull_hud.add_theme_constant_override("separation", 3)
	_ship_hull_hud.visible = false
	_ship_hull_icon = TextureRect.new()
	_ship_hull_icon.custom_minimum_size = Vector2(SHIP_HULL_ICON_SZ, SHIP_HULL_ICON_SZ)
	_ship_hull_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ship_hull_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ship_hull_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ship_hull_icon.texture = _make_ship_hull_icon()
	_ship_hull_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ship_hull_hud.add_child(_ship_hull_icon)
	_ship_hull_lab = Label.new()
	_ship_hull_lab.add_theme_font_size_override("font_size", SHIP_HULL_HUD_FONT_SIZE)
	_ship_hull_lab.add_theme_color_override("font_color", SHIP_HULL_HUD_COLOR)
	_ship_hull_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiTheme.apply_font(_ship_hull_lab)
	_ship_hull_hud.add_child(_ship_hull_lab)
	add_child(_ship_hull_hud)


func _make_ship_hull_icon() -> Texture2D:
	## Keyed west-facing frigate from shapes tile 16.
	if not _U4TileBankScript.ensure_loaded():
		return null
	var slice: Image = _U4TileBankScript.keyed_copy(MapView.TILE_SHIP_W)
	if slice == null or slice.is_empty():
		return null
	var s := MapView.TILE_SRC
	## Crop to content so the 14px icon reads larger.
	var x0 := s
	var y0 := s
	var x1 := -1
	var y1 := -1
	for y in s:
		for x in s:
			if slice.get_pixel(x, y).a > 0.5:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < x0:
		return ImageTexture.create_from_image(slice)
	var cw := x1 - x0 + 1
	var ch := y1 - y0 + 1
	var cropped := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	cropped.blit_rect(slice, Rect2i(x0, y0, cw, ch), Vector2i.ZERO)
	return ImageTexture.create_from_image(cropped)


func _refresh_ship_hull_hud() -> void:
	_ensure_ship_hull_hud()
	var aboard := _transport == Transport.SHIP
	if _ship_hull_hud:
		_ship_hull_hud.visible = aboard
	if aboard and _ship_hull_lab:
		var hull := clampi(GameState.ship_hull, 0, GameState.SHIP_HULL_WHEEL)
		_ship_hull_lab.text = "%02d" % hull
		_ship_hull_lab.add_theme_color_override(
			"font_color",
			SHIP_HULL_HUD_COLOR_LOW if hull <= SHIP_HULL_LOW_THRESHOLD else SHIP_HULL_HUD_COLOR
		)
	_layout_ship_hull_hud()


func _layout_ship_hull_hud() -> void:
	## Match Locate's open-map right X; center vertically on the bottom bar.
	if _ship_hull_hud == null or not _ship_hull_hud.visible:
		return
	if _map_pane == null or _bottom_bar == null:
		return
	var g := _side_geom()
	var map_right: float = floorf(g["right_open_x"])
	_ship_hull_hud.reset_size()
	var hud_sz := _ship_hull_hud.get_combined_minimum_size()
	_ship_hull_hud.size = hud_sz
	var map_origin := _map_pane.global_position - global_position
	var bot_origin := _bottom_bar.global_position - global_position
	var bar_h := _bottom_bar.size.y
	if bar_h < 1.0:
		bar_h = _bottom_bar.custom_minimum_size.y
	_ship_hull_hud.position = Vector2(
		map_origin.x + map_right - hud_sz.x - SHIP_HULL_HUD_INSET.x,
		bot_origin.y + floorf((bar_h - hud_sz.y) * 0.5) + SHIP_HULL_HUD_INSET.y
	)
	_ship_hull_hud.move_to_front()


func _do_search() -> void:
	## xu4 game.cpp case 's' (world/city). Dungeon Search is separate.
	if _search_busy:
		return
	_search_busy = true
	_push_message(Locale.t("cmd_searching"), false)
	## Beat so "Searching..." reads, and S can't be mashed into another turn.
	await get_tree().create_timer(SEARCH_PAUSE_SEC).timeout
	if not is_inside_tree():
		_search_busy = false
		return
	var city_fname := ""
	if _is_in_city() and _city_map != null:
		city_fname = str(_city_map.source_path).get_file()
	var item: Dictionary = _SearchItems.item_at(city_fname, _tile_pos)
	if item.is_empty() or _SearchItems.is_owned(item):
		_push_message(Locale.t("cmd_search_nothing"), false)
		_search_busy = false
		_finish_party_turn()
		return
	var name_key := str(item.get("name_key", ""))
	if not name_key.is_empty():
		_push_message(Locale.t("cmd_search_find"), false)
		_push_message(Locale.t("cmd_search_find_name", [Locale.t(name_key)]), false)
	var result: Dictionary = _SearchItems.grant(item)
	if bool(result.get("dropped", false)):
		_push_message(Locale.t("cmd_search_dropped"), false)
	if bool(result.get("telescope", false)):
		_search_busy = false
		_begin_telescope()
		return
	_refresh_inventory_bars()
	_refresh_party()
	_search_busy = false
	_finish_party_turn()


func _begin_telescope() -> void:
	## xu4 useTelescope — knob prompt then A–P city peer.
	_push_message(Locale.t("cmd_telescope_knob1"), false)
	_push_message(Locale.t("cmd_telescope_knob2"), false)
	_push_message(Locale.t("cmd_telescope_knob3"), false)
	_telescope_stage = 1
	_layout_prompt_row()


func _cancel_telescope(show_none: bool = false) -> void:
	if _telescope_stage == 0:
		return
	_telescope_stage = 0
	_layout_prompt_row()
	if show_none:
		_push_message(Locale.t("cmd_none"), false)
		_finish_party_turn()


func _handle_telescope_input(event: InputEvent) -> bool:
	if _telescope_stage != 1:
		return false
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var k := event as InputEventKey
	if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
		_cancel_telescope(true)
		return true
	var code := k.keycode
	if code < KEY_A or code > KEY_P:
		code = k.physical_keycode
	if code < KEY_A or code > KEY_P:
		return true ## swallow other keys while selecting
	var idx := int(code - KEY_A)
	_telescope_stage = 0
	_layout_prompt_row()
	_open_telescope_city(idx)
	return true


func _open_telescope_city(choice_index: int) -> void:
	## xu4 gamePeerCity(choice) — gem view of city map id choice+1.
	var fname := _SearchItems.telescope_city_fname(choice_index)
	if fname.is_empty():
		_finish_party_turn()
		return
	var path := _CityMapData.resolve_u4_file(fname)
	var cmap = _CityMapData.new()
	if path.is_empty() or not cmap.load_from_path(path):
		_finish_party_turn()
		return
	_ensure_peer_overlay()
	if _peer_overlay == null or _map == null:
		_finish_party_turn()
		return
	var tile_sz := _map.displayed_tile_size()
	var portal := _WorldPortals.portal_for_fname(fname)
	var loc := str(portal.get("name", fname.get_basename()))
	_peer_overlay.open_peer_city(cmap, tile_sz, loc)
	## Turn ends when the gem view is dismissed (_close_peer_overlay).


func _do_peer() -> void:
	## Peer: spend a gem, show ~16:9 gem map until Space/Enter/Esc.
	## xu4: even "Peer at What?" still ends the turn.
	if GameState.gems <= 0:
		_push_message(Locale.t("cmd_peer_what"), false)
		_finish_party_turn()
		return
	GameState.gems -= 1
	_refresh_inventory_bars()
	_push_message(Locale.t("cmd_peer_gem"), false)
	_ensure_peer_overlay()
	if _peer_overlay == null or _map == null:
		_finish_party_turn()
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
	## Dismiss gem view — consumes the party turn (xu4 peer → finishTurn).
	if _peer_overlay == null or not _peer_overlay.is_open():
		return
	_peer_overlay.close_peer()
	_finish_party_turn()


func _do_quit_save() -> void:
	## Q → slot picker popup; pick 1–4 / ↑↓+Enter to write JSON save.
	_push_message(Locale.t("cmd_quit_save"), false)
	_push_message(Locale.t("cmd_quit_moves", [GameState.moves]), false)
	_open_slot_picker(_SaveSlotPanel.Mode.SAVE, false)


func _is_quick_save_key(event: InputEventKey) -> bool:
	## ⌘S (macOS) or Ctrl+S (Windows/Linux).
	if event.alt_pressed or event.shift_pressed:
		return false
	if not (event.ctrl_pressed or event.meta_pressed):
		return false
	var code := event.keycode
	var phys := event.physical_keycode
	return code == KEY_S or phys == KEY_S


func _do_quick_save() -> void:
	## Cmd/Ctrl+S: overwrite the session slot, or open the picker if never saved/loaded.
	if _save_stage != 0:
		return
	if _esc_menu_is_open():
		_close_esc_menu()
	var slot_n := GameState.session_loaded_slot
	if slot_n < 1 or slot_n > _SaveGame.SLOT_COUNT:
		## New game — no slot yet → same picker as Q (without quit copy).
		_push_message(Locale.t("save_title"), false)
		_open_slot_picker(_SaveSlotPanel.Mode.SAVE, false)
		return
	var data := _SaveGame.build_save(
		GameState.to_save_dict(),
		_world_save_dict(),
		GameState.player_name,
		GameState.moves,
		GameState.player_class,
		_save_location_dict()
	)
	if not _SaveGame.write_slot(slot_n, data):
		_push_message(Locale.t("cmd_save_failed"), false)
		return
	GameState.session_did_save = true
	GameState.session_loaded_slot = slot_n
	## Quick save: moves line, then "N번 슬롯에 저장했다."
	_push_message(Locale.t("cmd_quit_moves", [GameState.moves]), false)
	_push_message(Locale.t("cmd_quick_saved", [slot_n]), false)


func _open_slot_picker(mode: int, from_esc: bool) -> void:
	_ensure_save_panel()
	if _save_panel == null:
		_push_message(Locale.t("cmd_save_failed"), false)
		if from_esc:
			_open_esc_menu()
		elif mode == _SaveSlotPanel.Mode.SAVE:
			_finish_party_turn()
		return
	_slot_from_esc = from_esc
	_save_stage = 2 if mode == _SaveSlotPanel.Mode.LOAD else 1
	_reset_hold_state()
	var cursor := 0
	if mode == _SaveSlotPanel.Mode.LOAD:
		cursor = _SaveGame.default_load_cursor()
	else:
		cursor = _SaveGame.default_save_cursor(
			GameState.session_loaded_slot, GameState.session_did_save
		)
	_save_panel.open_panel(mode, cursor)
	_layout_prompt_row()


func _ensure_save_panel() -> void:
	if _save_panel != null:
		return
	_save_panel = _SaveSlotPanel.new()
	_save_panel.name = "SaveSlotPanel"
	add_child(_save_panel)


func _ensure_esc_menu() -> void:
	if _esc_menu != null:
		return
	_esc_menu = _EscMenuPanel.new()
	_esc_menu.name = "EscMenuPanel"
	add_child(_esc_menu)


func _ensure_options_panel() -> void:
	if _options_panel != null:
		return
	_options_panel = _OptionsPanel.new()
	_options_panel.name = "OptionsPanel"
	add_child(_options_panel)


func _esc_menu_is_open() -> bool:
	return _esc_menu != null and _esc_menu.is_open()


func _options_panel_is_open() -> bool:
	return _options_panel != null and _options_panel.is_open()


func _open_esc_menu() -> void:
	_ensure_esc_menu()
	_reset_hold_state()
	if _options_panel:
		_options_panel.close_panel()
	_esc_menu.open_panel(0)
	_layout_prompt_row()


func _close_esc_menu() -> void:
	if _esc_menu:
		_esc_menu.close_panel()
	if _options_panel:
		_options_panel.close_panel()
	_layout_prompt_row()


func _open_options_panel() -> void:
	_ensure_options_panel()
	_reset_hold_state()
	## Cover Esc menu; Esc from options returns to it.
	if _esc_menu:
		_esc_menu.close_panel()
	_options_panel.open_panel(0)
	_layout_prompt_row()


func _close_options_panel(return_to_esc: bool) -> void:
	if _options_panel:
		_options_panel.close_panel()
	if return_to_esc:
		_ensure_esc_menu()
		_esc_menu.open_panel(_EscMenuPanel.Item.OPTION)
	_layout_prompt_row()


func _nudge_esc_menu_cursor(delta: int) -> void:
	if _esc_menu:
		_esc_menu.nudge_cursor(delta)


func _nudge_options_cursor(delta: int) -> void:
	if _options_panel:
		_options_panel.nudge_cursor(delta)


func _on_language_changed(_lang: String) -> void:
	## Live HUD / menus after Options language change or slot-load language.
	if _esc_menu != null and _esc_menu.is_open():
		_esc_menu.refresh()
	if _options_panel != null and _options_panel.is_open():
		_options_panel.refresh()
	if _save_panel != null and _save_panel.is_open():
		_save_panel.refresh()
	if _ztats_panel != null and _ztats_stage != 0:
		## Ztats labels (gear/item names) live in private refresh helpers.
		_ztats_panel._refresh()
		if _ztats_panel.is_inventory_page():
			_ztats_panel._refresh_inventory()
	_refresh_party()
	_refresh_locate_hud()
	_layout_prompt_row()


func _handle_esc_menu_input(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
			_close_esc_menu()
			return true
		if _is_order_confirm_key(k):
			_confirm_esc_menu(_esc_menu.cursor() if _esc_menu else 0)
			return true
		## Optional letter shortcuts.
		var letter := _esc_menu_letter_index(k)
		if letter >= 0:
			if _esc_menu:
				_esc_menu.set_cursor(letter)
			_confirm_esc_menu(letter)
			return true
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if jb.button_index == JOY_BUTTON_B:
			_close_esc_menu()
			return true
		if jb.button_index == JOY_BUTTON_A:
			_confirm_esc_menu(_esc_menu.cursor() if _esc_menu else 0)
			return true
	return true


func _handle_options_input(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if _options_horizontal_nudge(event):
		var dir := _options_language_delta(event)
		if dir != 0:
			_cycle_options_language(dir)
			return true
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
			_close_options_panel(true)
			return true
		if _is_order_confirm_key(k):
			_confirm_options_item(_options_panel.cursor() if _options_panel else 0)
			return true
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if jb.button_index == JOY_BUTTON_B:
			_close_options_panel(true)
			return true
		if jb.button_index == JOY_BUTTON_A:
			_confirm_options_item(_options_panel.cursor() if _options_panel else 0)
			return true
	return true


func _options_horizontal_nudge(event: InputEvent) -> bool:
	return (
		event.is_action_pressed("ui_left")
		or event.is_action_pressed("ui_right")
		or event.is_action_pressed("move_left")
		or event.is_action_pressed("move_right")
		or (
			event is InputEventKey
			and (
				event.keycode == KEY_LEFT
				or event.physical_keycode == KEY_LEFT
				or event.keycode == KEY_RIGHT
				or event.physical_keycode == KEY_RIGHT
			)
		)
	)


func _options_language_delta(event: InputEvent) -> int:
	if (
		event.is_action_pressed("ui_left")
		or event.is_action_pressed("move_left")
		or (event is InputEventKey and (event.keycode == KEY_LEFT or event.physical_keycode == KEY_LEFT))
	):
		return -1
	if (
		event.is_action_pressed("ui_right")
		or event.is_action_pressed("move_right")
		or (event is InputEventKey and (event.keycode == KEY_RIGHT or event.physical_keycode == KEY_RIGHT))
	):
		return 1
	return 0


func _cycle_options_language(delta: int) -> void:
	_ensure_options_panel()
	if _options_panel == null:
		return
	_options_panel.cycle_language(delta)
	_layout_prompt_row()


func _confirm_options_item(index: int) -> void:
	match index:
		_OptionsPanel.Item.LANGUAGE:
			_cycle_options_language(1)
		_:
			pass


func _esc_menu_letter_index(k: InputEventKey) -> int:
	var code := k.keycode
	var phys := k.physical_keycode
	if code == KEY_S or phys == KEY_S:
		return _EscMenuPanel.Item.SAVE
	if code == KEY_L or phys == KEY_L:
		return _EscMenuPanel.Item.LOAD
	if code == KEY_R or phys == KEY_R:
		return _EscMenuPanel.Item.RETURN_MENU
	if code == KEY_O or phys == KEY_O:
		return _EscMenuPanel.Item.OPTION
	if code == KEY_Q or phys == KEY_Q:
		return _EscMenuPanel.Item.QUIT
	return -1


func _confirm_esc_menu(index: int) -> void:
	match index:
		_EscMenuPanel.Item.SAVE:
			_close_esc_menu()
			_open_slot_picker(_SaveSlotPanel.Mode.SAVE, true)
		_EscMenuPanel.Item.LOAD:
			if not _SaveGame.any_slot_exists():
				if _esc_menu:
					_esc_menu.set_status(Locale.t("load_none"))
				return
			_close_esc_menu()
			_open_slot_picker(_SaveSlotPanel.Mode.LOAD, true)
		_EscMenuPanel.Item.RETURN_MENU:
			## Same Yes/No prompt as ⌘Q (different message / destination).
			QuitConfirm.prompt(QuitConfirm.Kind.RETURN_MENU)
		_EscMenuPanel.Item.OPTION:
			_open_options_panel()
		_EscMenuPanel.Item.QUIT:
			QuitConfirm.prompt(QuitConfirm.Kind.QUIT)


func _nudge_save_cursor(delta: int) -> void:
	if _save_panel:
		_save_panel.nudge_cursor(delta)


func _handle_save_input(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
			_cancel_save(true)
			return true
		if _is_order_cancel_key(k):
			_cancel_save(true)
			return true
		if _is_order_confirm_key(k):
			_confirm_slot_pick(_save_panel.cursor() if _save_panel else 0)
			return true
		var dig := _player_digit_index_from_key(k)
		if dig >= 0 and dig < _SaveGame.SLOT_COUNT:
			if _save_panel:
				_save_panel.set_cursor(dig)
			_confirm_slot_pick(dig)
			return true
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if jb.button_index == JOY_BUTTON_B:
			_cancel_save(true)
			return true
		if jb.button_index == JOY_BUTTON_A:
			_confirm_slot_pick(_save_panel.cursor() if _save_panel else 0)
			return true
	if event.is_action_pressed("cancel") and event is InputEventJoypadButton:
		_cancel_save(true)
		return true
	return true


func _confirm_slot_pick(slot_index: int) -> void:
	if _save_stage == 2:
		_confirm_load_slot(slot_index)
	else:
		_confirm_save_slot(slot_index)


func _confirm_save_slot(slot_index: int) -> void:
	## slot_index is 0-based; files are slot_1..4.
	if slot_index < 0 or slot_index >= _SaveGame.SLOT_COUNT:
		return
	var slot_n := slot_index + 1
	var data := _SaveGame.build_save(
		GameState.to_save_dict(),
		_world_save_dict(),
		GameState.player_name,
		GameState.moves,
		GameState.player_class,
		_save_location_dict()
	)
	if not _SaveGame.write_slot(slot_n, data):
		_push_message(Locale.t("cmd_save_failed"), false)
		var from_esc_fail := _slot_from_esc
		_close_save(false)
		if from_esc_fail:
			_open_esc_menu()
		else:
			_finish_party_turn()
		return
	GameState.session_did_save = true
	GameState.session_loaded_slot = slot_n
	var from_esc := _slot_from_esc
	_close_save(false)
	_push_message(Locale.t("cmd_saved"), false)
	if from_esc:
		_open_esc_menu()
	else:
		_finish_party_turn()


func _confirm_load_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _SaveGame.SLOT_COUNT:
		return
	var slot_n := slot_index + 1
	if not _SaveGame.slot_exists(slot_n):
		_push_message(Locale.t("load_empty"), false)
		return
	var data := _SaveGame.read_slot(slot_n)
	if data.is_empty():
		_push_message(Locale.t("load_empty"), false)
		return
	var game: Variant = data.get("game", {})
	var world: Variant = data.get("world", {})
	if typeof(game) != TYPE_DICTIONARY:
		_push_message(Locale.t("load_empty"), false)
		return
	GameState.apply_save_dict(game as Dictionary)
	GameState.pending_world_save = world if typeof(world) == TYPE_DICTIONARY else {}
	GameState.session_loaded_slot = slot_n
	GameState.session_did_save = false
	GameState.is_new_game = false
	_SaveGame.set_last_loaded_slot(slot_n)
	_close_save(false)
	_slot_from_esc = false
	SceneRouter.to_world()


func _world_save_dict() -> Dictionary:
	## World / UI bits not stored in GameState (xu4 x,y,transport + Tab panels).
	## Inside a city: x,y = world portal (exit tile); city_* = .ULT local pos.
	var hulls := {}
	for k in _ship_hulls.keys():
		hulls[str(k)] = int(_ship_hulls[k])
	var d := {
		"x": _tile_pos.x,
		"y": _tile_pos.y,
		"sides_open": _sides_open,
		"transport": _transport,
		"transport_tile": _transport_tile,
		"horse_gallop": _horse_gallop,
		"ship_hulls": hulls,
		"parked_ship_x": _parked_ship_tile.x,
		"parked_ship_y": _parked_ship_tile.y,
		"overlays": _overlays_to_save(),
		"creatures": _creatures_to_save(),
		"city_chests": _city_chests_to_save(),
		"in_city": false,
	}
	if _is_in_city():
		var fname := ""
		## Prefer the floor currently loaded (lcb_2 vs lcb_1), not only world Enter.
		if _city_map != null and not str(_city_map.source_path).is_empty():
			fname = str(_city_map.source_path).get_file()
		if fname.is_empty():
			var portal := _WorldPortals.portal_at(_city_return_pos)
			if not portal.is_empty():
				fname = str(portal.get("fname", ""))
		d["in_city"] = true
		d["x"] = _city_return_pos.x
		d["y"] = _city_return_pos.y
		d["city_return_x"] = _city_return_pos.x
		d["city_return_y"] = _city_return_pos.y
		d["city_x"] = _tile_pos.x
		d["city_y"] = _tile_pos.y
		d["city_fname"] = fname
	return d


func _save_location_dict() -> Dictionary:
	## Slot subtitle: In / Near place, On the Sea, On the Britannia (dungeon later).
	if _is_in_city():
		var portal := _WorldPortals.portal_at(_city_return_pos)
		if portal.is_empty():
			var fname := ""
			## Prefer fname already known from an open city map source path.
			if _city_map != null:
				fname = str(_city_map.source_path).get_file()
			if not fname.is_empty():
				portal = _WorldPortals.portal_for_fname(fname)
		var place := _WorldPortals.place_id_for_portal(portal)
		if place.is_empty():
			place = "britain"
		return {"kind": "in", "place": place}

	## Future: dungeon → {"kind":"dungeon","place":"shame","level":2}

	var world_pos := _tile_pos
	if _world != null and _world.loaded:
		var tid := _world.tile_at(world_pos.x, world_pos.y)
		if _TileRules.is_water(tid):
			return {"kind": "sea"}

	var near := _nearest_visible_settlement(world_pos)
	if not near.is_empty():
		return {"kind": "near", "place": near}
	return {"kind": "britannia"}


func _nearest_visible_settlement(origin: Vector2i) -> String:
	## Among portals inside the explore view, pick closest; LCB wins ties.
	var half_x := MapView.VIEW_W / 2
	var half_y := MapView.VIEW_H / 2
	var best_place := ""
	var best_dist := 1 << 30
	var best_lcb := false
	for portal in _WorldPortals.all_portal_entries():
		var px := int(portal.get("wx", 0))
		var py := int(portal.get("wy", 0))
		var delta := _world_wrap_delta(origin, Vector2i(px, py))
		if absi(delta.x) > half_x or absi(delta.y) > half_y:
			continue
		var dist := delta.x * delta.x + delta.y * delta.y
		var is_lcb := _WorldPortals.is_lcb_portal(portal)
		var place := _WorldPortals.place_id_for_portal(portal)
		if place.is_empty():
			continue
		var better := false
		if dist < best_dist:
			better = true
		elif dist == best_dist:
			## Same distance → Britannia Castle first; else keep current.
			if is_lcb and not best_lcb:
				better = true
		if better:
			best_dist = dist
			best_place = place
			best_lcb = is_lcb
	return best_place


func _world_wrap_delta(from: Vector2i, to: Vector2i) -> Vector2i:
	## Shortest signed delta on the wrapping world map.
	var dx := to.x - from.x
	var dy := to.y - from.y
	var w := WorldMapData.WIDTH
	var h := WorldMapData.HEIGHT
	if dx > w / 2:
		dx -= w
	elif dx < -w / 2:
		dx += w
	if dy > h / 2:
		dy -= h
	elif dy < -h / 2:
		dy += h
	return Vector2i(dx, dy)


func _overlays_to_save() -> Array:
	## Map-visible horses/ships (and any other transport overlays).
	var out: Array = []
	if _map == null:
		return out
	for item in _map.get_overlays():
		out.append({"x": int(item.x), "y": int(item.y), "t": int(item.z)})
	return out


func _creatures_to_save() -> Array:
	if _world_creatures == null:
		return []
	return _world_creatures.to_save()


func _sync_creatures_to_map() -> void:
	if _map == null or _world_creatures == null:
		return
	if _is_in_city():
		_map.set_creatures([])
		return
	_map.set_creatures(_world_creatures.as_paint_items())


func _creature_spawn_blocked(pos: Vector2i) -> bool:
	## Do not stack on parked horses/ships or an existing creature.
	if _world_creatures != null and _world_creatures.creature_at(pos) >= 0:
		return true
	if _map != null and _map.overlay_at(pos) >= 0:
		return true
	return false


func _on_pirate_cannon_fire(from: Vector2i, dir: Vector2i) -> void:
	## Queued during moveObjects; animated after the AI pass.
	_pending_pirate_shots.append({"from": from, "dir": dir})


func _do_fire_cannon(dir: Vector2i) -> String:
	## Sync probe for broadsides-only; flight is awaited in _finish_directed_command.
	if _transport != Transport.SHIP or _is_in_city():
		return Locale.t("cmd_fire_what")
	var facing := _ship_facing_dir()
	if not _WorldCreaturesScript.is_broadside_dir(facing, dir):
		return Locale.t("cmd_broadsides_only")
	return ""


func _fire_cannon_along_async(origin: Vector2i, dir: Vector2i, from_avatar: bool) -> void:
	## Pixel-smooth ball, then resolve xu4 fireAt at the impact tile.
	var path: Array[Vector2i] = _WorldCreaturesScript.cannon_path(
		origin, dir, _WorldCreaturesScript.CANNON_RANGE
	)
	if path.is_empty():
		return
	var impact_pos := path[path.size() - 1]
	var impact: Dictionary = {}
	for pos in path:
		var info := _cannon_probe(pos, from_avatar)
		if bool(info.get("valid", false)):
			impact_pos = pos
			impact = info
			break
	_cannon_busy = true
	if _map != null:
		await _map.await_cannonball(origin, impact_pos, dir)
	if not impact.is_empty():
		await _cannon_apply_impact(impact)
	_cannon_busy = false


func _cannon_probe(pos: Vector2i, from_avatar: bool) -> Dictionary:
	## Classify target at `pos` without FX (xu4 fireAt validity).
	const TILE_BALLOON := 24
	var hits_avatar := pos == _tile_pos
	var creature_tid := -1
	if not _is_in_city() and _world_creatures != null:
		creature_tid = _world_creatures.creature_at(pos)
	var overlay_tid := -1
	if _map != null:
		overlay_tid = _map.overlay_at(pos)
	var valid := false
	if creature_tid >= 0:
		valid = true
	elif overlay_tid >= 0 and not (from_avatar and overlay_tid == TILE_BALLOON):
		valid = true
	if hits_avatar:
		valid = true
	if not valid:
		return {}
	var kind := "stop"
	if hits_avatar:
		kind = "avatar"
	elif creature_tid < 0 and overlay_tid >= 0:
		kind = "overlay"
	elif from_avatar and creature_tid >= 0:
		kind = "creature"
	return {
		"valid": true,
		"pos": pos,
		"kind": kind,
		"from_avatar": from_avatar,
	}


func _cannon_apply_impact(info: Dictionary) -> void:
	## Await hit FX so the target tile stays put until the flash ends (then AI moves).
	var pos: Vector2i = info.get("pos", Vector2i.ZERO)
	var kind := str(info.get("kind", ""))
	const HIT_SEC := 0.36
	match kind:
		"avatar":
			if _map != null:
				await _map.await_flash_world_tile(pos, MapView.TILE_HIT_FLASH, HIT_SEC)
			_apply_cannon_hit_on_party()
		"overlay":
			if _map != null:
				await _map.await_flash_world_tile(pos, MapView.TILE_HIT_FLASH, HIT_SEC)
				var otid := _map.overlay_at(pos)
				if MapView.is_ship_tile(otid):
					## Parked / captured frigates: hull damage (10/hit), not one-shot.
					_damage_map_ship_overlay(pos)
				else:
					_map.remove_overlay_at(pos)
		"creature":
			if _world_creatures != null:
				## Progressive HP (bar under sprite) — ~4 cannon hits to sink.
				_world_creatures.apply_cannon_damage_at(pos)
				_sync_creatures_to_map()
			if _map != null:
				await _map.await_flash_world_tile(pos, MapView.TILE_HIT_FLASH, HIT_SEC)
		_:
			pass


func _damage_map_ship_overlay(pos: Vector2i) -> void:
	## Empty world-map ships (incl. captured pirate frigates): 10 hull/shot → sink.
	var key := _ship_hull_key(pos)
	var hull := int(_ship_hulls.get(key, GameState.SHIP_HULL_MAX))
	hull = maxi(0, hull - 10)
	if hull <= 0:
		_ship_hulls.erase(key)
		if _map != null:
			_map.remove_overlay_at(pos)
	else:
		_store_ship_hull_at(pos, hull)


func _apply_cannon_hit_on_party() -> void:
	## xu4 hitPartyAtRange — ship hull 10, else party 10–25 (50% each).
	if _map != null:
		_map.shake_ship()
	if _transport == Transport.SHIP:
		var sunk := GameState.damage_ship(10)
		_refresh_ship_hull_hud()
		if _roster and _roster.has_method("flash_players"):
			_roster.flash_players(-1)
		if _compact_roster and _compact_roster.has_method("flash_players"):
			_compact_roster.flash_players(-1)
		if sunk:
			_push_message(Locale.t("cmd_ship_sinks"), false)
			GameState.kill_party()
			_refresh_party()
			## xu4 gameKillParty → deathStart(5).
			_start_death_sequence(DEATH_PAUSE_SEC)
		return
	var flash := GameState.damage_party_cannon(10, 25)
	_refresh_party()
	_flash_party_damage(flash)
	## Foot: if the volley wiped the party, death starts now — not after more AI.
	if GameState.is_party_dead():
		_start_death_sequence(0.0)


func _party_wiped_or_dying() -> bool:
	## Party is fully dead, or the death cutscene already owns the screen.
	return _death_busy or GameState.is_party_dead()


func _update_world_creatures() -> void:
	## xu4 finishTurn: moveObjects → creatureCleanup → checkRandomCreatures.
	## Creatures act sequentially; after a lethal pirate shot, stop further AI / combat.
	if _combat_active or _is_in_city() or _world == null or not _world.loaded:
		return
	if _world_creatures == null:
		return
	if _party_wiped_or_dying():
		return
	_pending_pirate_shots.clear()
	var moved: Dictionary = _world_creatures.move_all(
		_world,
		_tile_pos,
		_creature_spawn_blocked,
		_on_pirate_cannon_fire
	)
	var changed := bool(moved.get("changed", false))
	## Fire each broadside in order; abort if the party is wiped mid-queue.
	for shot in _pending_pirate_shots:
		if _party_wiped_or_dying():
			return
		await _fire_cannon_along_async(shot["from"], shot["dir"], false)
		if _party_wiped_or_dying():
			return
	## Adjacent engage only if the party still stands after all world AI.
	if _party_wiped_or_dying():
		return
	var attacker: Dictionary = moved.get("attacker", {})
	if typeof(attacker) == TYPE_DICTIONARY and not (attacker as Dictionary).is_empty():
		var apos := Vector2i(int(attacker.get("x", 0)), int(attacker.get("y", 0)))
		var foe := _world_creatures.take_at(apos)
		if foe.is_empty():
			foe = attacker
		_sync_creatures_to_map()
		await _begin_combat(foe, false)
		return
	if _world_creatures.cleanup(_tile_pos):
		changed = true
	if _world_creatures.try_random_spawn(
		_world,
		_tile_pos,
		MapView.VIEW_W,
		MapView.VIEW_H,
		GameState.moves,
		_creature_spawn_blocked
	):
		changed = true
	if changed:
		_sync_creatures_to_map()


func _cancel_save(show_none: bool) -> void:
	if _save_stage == 0:
		return
	var from_esc := _slot_from_esc
	_close_save(false)
	if from_esc:
		_open_esc_menu()
		return
	if show_none:
		_push_message(Locale.t("cmd_none"), false)
	_finish_party_turn()


func _close_save(_show_none: bool) -> void:
	if _save_stage == 0 and (_save_panel == null or not _save_panel.is_open()):
		return
	_save_stage = 0
	_slot_from_esc = false
	if _save_panel:
		_save_panel.close_panel()
	_layout_prompt_row()


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
		## ↑↓ scroll inventory lists; ←→ cycle pages (chars → gear → items → reagents → mixtures).
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
	## Party character sheets + Equipment + Items + Reagents + Mixtures.
	return maxi(GameState.party_size(), 1) + 4


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
			_show_ztats_inventory(ZtatsPanel.InvPage.ITEMS)
		2:
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
		ZtatsPanel.InvPage.ITEMS:
			_ztats_flat = party_n + 1
		ZtatsPanel.InvPage.REAGENTS:
			_ztats_flat = party_n + 2
		_:
			_ztats_flat = party_n + 3
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
	elif _order_opened_roster and _order_stage == 0 and _ready_stage == 0 and _wear_stage == 0 and _mix_stage == 0:
		_close_order_roster()
	_layout_prompt_row()
	if show_none and was == 1:
		_push_message(Locale.t("cmd_none"), false)
	## Combat Ztats is free (view only) — does not spend the member turn.


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
	## xu4 readyWeapon(): explore asks who; combat passes focus → Weapon only.
	_clear_pending_order()
	_close_ztats(false)
	_close_wear(false)
	_close_use(false)
	if GameState.party_size() <= 0:
		_push_message(Locale.t("cmd_none"), false)
		if _combat_active and not _combat_resolving:
			_combat_finish_member_turn()
		return
	if _combat_active:
		_do_ready_combat_self()
		return
	_ready_self_only = false
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


func _do_ready_combat_self() -> void:
	## xu4 combat: readyWeapon(getFocus()) — current member only.
	if _map == null or not _map.is_in_combat():
		_push_message(Locale.t("cmd_none"), false)
		return
	var slot := _map.get_combat_focus_party_slot()
	if slot < 0 or slot >= GameState.party_size():
		_push_message(Locale.t("cmd_none"), false)
		if not _combat_resolving:
			_combat_finish_member_turn()
		return
	var klass := GameState.party_member_at(slot)
	if klass < 0 or GameState.is_member_disabled(klass):
		_push_message(Locale.t("cmd_cant"), false)
		if not _combat_resolving:
			_combat_finish_member_turn()
		return
	_ready_self_only = true
	_ready_slot = slot
	_ready_cursor = slot
	## Announce combatant then open weapon list (no "for:" party pick).
	var pname := GameState.party_member_display_name(slot)
	_push_message(Locale.t("cmd_ready_for_done", [pname]), false)
	_show_ready_weapons(slot)


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
	## Stage 1: pick member (explore only — combat starts at stage 2).
	if _ready_self_only:
		_close_ready(true)
		return true
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
		## R while picking weapon → explore: back to member; combat: cancel Ready.
		if k.keycode == KEY_R or k.physical_keycode == KEY_R:
			if _ready_self_only:
				_close_ready(true)
			else:
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
	if _ready_self_only:
		return
	var n := maxi(GameState.party_size(), 1)
	_ready_cursor = posmod(_ready_cursor + delta, n)
	_sync_ready_selection()


func _sync_ready_selection() -> void:
	if _roster:
		_roster.set_order_selection(_ready_cursor, -1)


func _accept_ready_slot(slot: int) -> void:
	if _ready_self_only:
		return
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
	_ready_slot = slot
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
	if _ready_self_only:
		_close_ready(true)
		return
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
	## Combat: only the focused party slot may change gear.
	if _ready_self_only and _combat_active and _map != null:
		var focus_slot := _map.get_combat_focus_party_slot()
		if _ready_slot != focus_slot:
			return
	## Qty 0 / restricted — ignore letter keys (no "None left!" spam).
	if _ready_panel and not _ready_panel.can_select_weapon(weapon_id):
		return
	var err := GameState.ready_weapon(_ready_slot, weapon_id)
	match err:
		GameState.EquipError.NONE_LEFT:
			_push_message(Locale.t("cmd_ready_none"), false)
		GameState.EquipError.CLASS_RESTRICTED:
			_push_message(_ready_restricted_message(_ready_slot, weapon_id), false)
		_:
			_push_message(Locale.t("cmd_ready_done", [Locale.weapon_name(weapon_id)]), false)
			_refresh_party()
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
	var self_only := _ready_self_only
	_ready_stage = 0
	_ready_cursor = 0
	_ready_slot = -1
	_ready_self_only = false
	_clear_order_selection()
	if _ready_panel:
		_ready_panel.close_panel()
	if _roster:
		_roster.visible = true
	if was != 0:
		_close_order_roster()
	elif _order_opened_roster and _order_stage == 0 and _ztats_stage == 0 and _wear_stage == 0 and _mix_stage == 0:
		_close_order_roster()
	_layout_prompt_row()
	if show_none and was != 0:
		if _combat_active:
			## Esc / cancel mid-Ready: no turn spent.
			_push_message(Locale.t("cmd_cancelled"), false)
		elif was == 1 and not self_only:
			_push_message(Locale.t("cmd_none"), false)
	## Combat Ready spends a turn only when a weapon is confirmed (show_none=false).
	elif _combat_active and was != 0 and not _combat_resolving:
		_combat_finish_member_turn()


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
	_close_use(false)
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
	## Qty 0 / restricted — ignore letter keys (no "None left!" spam).
	if _wear_panel and not _wear_panel.can_select_armor(armor_id):
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
	elif _order_opened_roster and _order_stage == 0 and _ztats_stage == 0 and _ready_stage == 0 and _mix_stage == 0:
		_close_order_roster()
	_layout_prompt_row()
	if show_none and was == 1:
		_push_message(Locale.t("cmd_none"), false)


func _ensure_mix_panel() -> void:
	if _mix_panel != null:
		return
	var host := get_node_or_null("RootCol/MapPane/RightTopPane/RightTopMargin") as Control
	if host == null:
		return
	_mix_panel = _MixPanel.new()
	_mix_panel.name = "MixPanel"
	_mix_panel.visible = false
	_mix_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(_mix_panel)


func _do_mix() -> void:
	## Improved Mix: known recipes remixed from a list; unknown via reagent pick.
	_clear_pending_order()
	_close_ztats(false)
	_close_ready(false)
	_close_wear(false)
	_close_use(false)
	if not GameState.has_any_reagents():
		_push_message(Locale.t("mix_none_left"), false)
		_finish_party_turn()
		return
	_push_message(Locale.t("mix_title"), false)
	_ensure_mix_panel()
	_open_order_roster()
	if _roster:
		_roster.visible = false
	if _ztats_panel:
		_ztats_panel.close_panel()
	_mix_stage = 1
	_reset_hold_state()
	if _mix_panel:
		_mix_panel.open_list()
	_layout_prompt_row()


func _nudge_mix_cursor(step: int) -> void:
	if _mix_panel == null:
		return
	_mix_panel.nudge_cursor(step)


func _handle_mix_input(event: InputEvent) -> bool:
	if not event.is_pressed():
		return false
	if event.is_echo():
		return false
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
			_on_escape()
			return true
		## Space cancels the whole Mix session (list / letter / reagents).
		if k.keycode == KEY_SPACE or k.physical_keycode == KEY_SPACE:
			_close_mix(true)
			return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		_close_mix(true)
		return true
	if event.is_action_pressed("cancel") and event is InputEventJoypadButton:
		_close_mix(true)
		return true

	if _mix_stage == 3:
		return _handle_mix_spell_letter(event)
	if _mix_stage == 2:
		return _handle_mix_reagent_input(event)
	return _handle_mix_list_input(event)


func _handle_mix_list_input(event: InputEvent) -> bool:
	if event is InputEventKey and _is_order_confirm_key(event as InputEventKey):
		_accept_mix_list_cursor()
		return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
		_accept_mix_list_cursor()
		return true
	if event is InputEventKey:
		var ke := event as InputEventKey
		var spell := _spell_id_from_key(ke)
		if spell >= 0:
			_mix_spell_shortcut(spell)
			return true
		if _is_direction_key(ke):
			return true
	return true


func _handle_mix_spell_letter(event: InputEvent) -> bool:
	## Mix New — wait for A–Z. Known spells remix from the list; unknown → reagents.
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.keycode == KEY_BACKSPACE or ke.physical_keycode == KEY_BACKSPACE:
			_return_mix_to_list()
			return true
		var spell := _spell_id_from_key(ke)
		if spell >= 0:
			if GameState.is_spell_known(spell):
				_return_to_list_and_remix(spell)
			else:
				_begin_new_mix(spell)
			return true
	return true


func _return_to_list_and_remix(spell_id: int) -> void:
	## Make new + already-known letter → jump back to list and auto-mix.
	_mix_stage = 1
	if _mix_panel:
		_mix_panel.open_list()
		var idx: int = int(_mix_panel.index_of_spell(spell_id))
		if idx >= 0:
			_mix_panel.set_cursor(idx)
	_layout_prompt_row()
	_try_remix_spell(spell_id)


func _handle_mix_reagent_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		var ke := event as InputEventKey
		## Backspace → cancel reagent pick, return selected stock, show spell list.
		if ke.keycode == KEY_BACKSPACE or ke.physical_keycode == KEY_BACKSPACE:
			_return_mix_to_list()
			return true
		## M confirms the mixture (Mix again while in reagent mode).
		if ke.keycode == KEY_M or ke.physical_keycode == KEY_M:
			_confirm_new_mix()
			return true
		var reag := _reagent_id_from_key(ke)
		if reag >= 0:
			if _mix_panel and not _mix_panel.toggle_reagent_by_id(reag):
				_push_message(Locale.t("mix_reag_none"), false)
			return true
		if _is_order_confirm_key(ke):
			_accept_mix_reagent_cursor()
			return true
		if _is_direction_key(ke):
			return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
		_accept_mix_reagent_cursor()
		return true
	return true


func _return_mix_to_list() -> void:
	## Leave reagent pick without ending the Mix session.
	if _mix_panel and int(_mix_panel.mode()) == _MixPanel.Mode.REAGENTS:
		_mix_panel.revert_selected_reagents()
	_mix_stage = 1
	if _mix_panel:
		_mix_panel.open_list()
	_layout_prompt_row()


func _accept_mix_reagent_cursor() -> void:
	## Enter on Mix row → combine; otherwise toggle reagent under cursor.
	if _mix_panel and _mix_panel.cursor_is_confirm_mix():
		_confirm_new_mix()
		return
	if _mix_panel and not _mix_panel.toggle_reagent_at_cursor():
		_push_message(Locale.t("mix_reag_none"), false)


func _spell_id_from_key(ke: InputEventKey) -> int:
	var code := ke.keycode
	if code < KEY_A or code > KEY_Z:
		code = ke.physical_keycode
	if code < KEY_A or code > KEY_Z:
		return -1
	return code - KEY_A


func _reagent_id_from_key(ke: InputEventKey) -> int:
	var code := ke.keycode
	if code < KEY_A or code > KEY_H:
		code = ke.physical_keycode
	if code < KEY_A or code > KEY_H:
		return -1
	return code - KEY_A


func _accept_mix_list_cursor() -> void:
	if _mix_panel == null:
		return
	var row_id: int = int(_mix_panel.cursor_list_id())
	if row_id == _MixPanel.ROW_MAKE_NEW:
		_mix_stage = 3
		_layout_prompt_row()
		return
	if row_id >= 0:
		_try_remix_spell(row_id)


func _mix_spell_shortcut(spell_id: int) -> void:
	if GameState.is_spell_known(spell_id):
		if _mix_panel:
			var idx: int = int(_mix_panel.index_of_spell(spell_id))
			if idx >= 0:
				_mix_panel.set_cursor(idx)
		_try_remix_spell(spell_id)
	else:
		_begin_new_mix(spell_id)


func _try_remix_spell(spell_id: int) -> void:
	if GameState.mixture_qty(spell_id) >= Spells.MIXTURE_MAX:
		_push_message(Locale.t("mix_full"), false)
		return
	if not GameState.can_remix_spell(spell_id):
		_push_message(Locale.t("mix_need_reag"), false)
		return
	if not GameState.remix_spell(spell_id):
		_push_message(Locale.t("mix_need_reag"), false)
		return
	_push_message(Locale.t("mix_success", [Locale.spell_name(spell_id)]), false)
	if _mix_panel:
		_mix_panel.refresh_list_quantities()
	_layout_prompt_row()


func _begin_new_mix(spell_id: int) -> void:
	if GameState.mixture_qty(spell_id) >= Spells.MIXTURE_MAX:
		_push_message(Locale.t("mix_full"), false)
		_mix_stage = 1
		if _mix_panel:
			_mix_panel.open_list()
		_layout_prompt_row()
		return
	_mix_stage = 2
	if _mix_panel:
		_mix_panel.open_reagents(spell_id)
	_layout_prompt_row()


func _confirm_new_mix() -> void:
	if _mix_panel == null or int(_mix_panel.mode()) != _MixPanel.Mode.REAGENTS:
		return
	var spell_id: int = int(_mix_panel.spell_id())
	var mask: int = int(_mix_panel.selected_mask())
	## Selected reagents already deducted from inventory.
	if GameState.commit_new_mix(spell_id, mask):
		## Clear selection counts without reverting (already consumed).
		_mix_panel.close_panel()
		_push_message(Locale.t("mix_success", [Locale.spell_name(spell_id)]), false)
		_mix_stage = 1
		_mix_panel.open_list()
		var idx: int = int(_mix_panel.index_of_spell(spell_id))
		if idx >= 0:
			_mix_panel.set_cursor(idx)
		_layout_prompt_row()
		return
	## Failure — reagents stay spent; leave Mix.
	_mix_panel.close_panel()
	_push_message(Locale.t("mix_failed"), false)
	_mix_stage = 0
	if _roster:
		_roster.visible = true
	_close_order_roster()
	_layout_prompt_row()
	_finish_party_turn()


func _close_mix(show_none: bool) -> void:
	var was := _mix_stage
	if was == 0:
		if _mix_panel:
			_mix_panel.close_panel()
		return
	if was == 2 and _mix_panel:
		_mix_panel.revert_selected_reagents()
	_mix_stage = 0
	if _mix_panel:
		_mix_panel.close_panel()
	if _roster:
		_roster.visible = true
	_close_order_roster()
	_layout_prompt_row()
	if show_none:
		_push_message(Locale.t("cmd_none"), false)
	_finish_party_turn()


func _ensure_use_panel() -> void:
	if _use_panel != null:
		return
	var host := get_node_or_null("RootCol/MapPane/RightTopPane/RightTopMargin") as Control
	if host == null:
		return
	_use_panel = _UsePanel.new()
	_use_panel.name = "UsePanel"
	_use_panel.visible = false
	_use_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(_use_panel)


func _do_use() -> void:
	## List-based Use. No owned quest items → message and end (remake).
	_clear_pending_order()
	_close_ztats(false)
	_close_ready(false)
	_close_wear(false)
	_close_mix(false)
	if not _UseItems.has_any():
		_push_message(Locale.t("cmd_use_none"), false)
		if _combat_active and not _combat_resolving:
			_combat_finish_member_turn()
		else:
			_finish_party_turn()
		return
	_push_message(Locale.t("cmd_use_which"), false)
	_ensure_use_panel()
	_open_order_roster()
	if _roster:
		_roster.visible = false
	if _ztats_panel:
		_ztats_panel.close_panel()
	_use_stage = 1
	_reset_hold_state()
	if _use_panel:
		_use_panel.open_list()
	_layout_prompt_row()


func _nudge_use_cursor(step: int) -> void:
	if _use_panel == null:
		return
	_use_panel.nudge_cursor(step)


func _handle_use_input(event: InputEvent) -> bool:
	if not event.is_pressed():
		return false
	if event.is_echo():
		return false
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
			_on_escape()
			return true
		if k.keycode == KEY_SPACE or k.physical_keycode == KEY_SPACE:
			_close_use(true)
			return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		_close_use(true)
		return true
	if event.is_action_pressed("cancel") and event is InputEventJoypadButton:
		_close_use(true)
		return true
	if event is InputEventKey and _is_order_confirm_key(event as InputEventKey):
		_confirm_use_cursor()
		return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
		_confirm_use_cursor()
		return true
	if event is InputEventKey and _is_direction_key(event as InputEventKey):
		return true
	return true


func _confirm_use_cursor() -> void:
	if _use_panel == null:
		return
	var kind: int = int(_use_panel.cursor_kind())
	if kind < 0:
		return
	var item_name := _UseItems.display_name(kind)
	_close_use(false)
	_push_message(item_name, false)
	## Run async use effects without turning the key handler into a coroutine.
	_run_use_item.call_deferred(kind)


func _run_use_item(kind: int) -> void:
	await _apply_use_item(kind)


func _apply_use_item(kind: int) -> void:
	## xu4 itemUse handlers. Runes / inventory keys (jimmy) are never listed.
	match kind:
		_UseItems.Kind.SKULL:
			await _use_skull()
			return
		_UseItems.Kind.WHEEL:
			await _use_wheel()
			return
		_UseItems.Kind.BELL, _UseItems.Kind.BOOK, _UseItems.Kind.CANDLE:
			await _use_bbc(kind)
			return
		_UseItems.Kind.HORN:
			await _use_horn()
			return
		_UseItems.Kind.KEY_TRUTH, _UseItems.Kind.KEY_LOVE, _UseItems.Kind.KEY_COURAGE:
			## xu4 useKey — always "No place to Use them!" (Codex key thirds).
			_push_message(Locale.t("cmd_use_no_place"), false)
			await _finish_use_command()
			return
		_:
			if kind >= _UseItems.Kind.STONE_BLUE and kind <= _UseItems.Kind.STONE_BLACK:
				## Full altar / Abyss stone flow deferred with dungeons.
				## Wrong place for now → xu4 "No place to Use them!".
				_push_message(Locale.t("cmd_use_no_place"), false)
				await _finish_use_command()
				return
			## Remaining unported use kinds.
			_push_message(Locale.t("cmd_use_no_effect"), false)
			await _finish_use_command()


func _finish_use_command() -> void:
	if _combat_active and not _combat_resolving:
		_combat_finish_member_turn()
	else:
		await _finish_party_turn()


func _use_horn() -> void:
	## xu4 useHorn — always succeeds: message + Aura::HORN for 10 turns.
	## Only material effect elsewhere is blocking humility-shrine daemon ambush.
	_push_message(Locale.t("cmd_use_horn"), false)
	GameState.set_aura(GameState.AuraType.HORN, 10)
	await _finish_use_command()


func _use_bbc(kind: int) -> void:
	## xu4 useBBC — Abyss entrance (233,233) only, Bell → Book → Candle order.
	const ABYSS_ENTRANCE := Vector2i(233, 233)
	var at_abyss := (
		not _combat_active
		and not _is_in_city()
		and _tile_pos == ABYSS_ENTRANCE
	)
	if at_abyss:
		if kind == _UseItems.Kind.BELL:
			_push_message(Locale.t("cmd_use_bell"), false)
			GameState.add_item_flag(GameState.ITEM_BELL_USED)
			await _finish_use_command()
			return
		if kind == _UseItems.Kind.BOOK and GameState.has_item_flag(GameState.ITEM_BELL_USED):
			_push_message(Locale.t("cmd_use_book"), false)
			GameState.add_item_flag(GameState.ITEM_BOOK_USED)
			await _finish_use_command()
			return
		if kind == _UseItems.Kind.CANDLE and GameState.has_item_flag(GameState.ITEM_BOOK_USED):
			_push_message(Locale.t("cmd_use_candle"), false)
			GameState.add_item_flag(GameState.ITEM_CANDLE_USED)
			await _finish_use_command()
			return
	## Wrong place, wrong order, or not on Abyss gate.
	_push_message(Locale.t("cmd_use_no_effect"), false)
	await _finish_use_command()


func _use_wheel() -> void:
	## xu4 useWheel — aboard ship with undamaged hull (exactly 50) → hull becomes 99.
	## Same rules in combat and field (transport context is not cleared for combat).
	if _transport == Transport.SHIP and GameState.try_mount_wheel():
		_push_message(Locale.t("cmd_use_wheel_mounted"), false)
		_refresh_ship_hull_hud()
	else:
		_push_message(Locale.t("cmd_use_no_effect"), false)
	await _finish_use_command()


func _use_skull() -> void:
	## xu4 useSkull — Abyss gate destroys it; elsewhere kill all creatures + bad karma.
	if GameState.has_item_flag(GameState.ITEM_SKULL_DESTROYED):
		_push_message(Locale.t("cmd_use_none_owned"), false)
		await _finish_use_command()
		return
	if not GameState.has_item_flag(GameState.ITEM_SKULL):
		_push_message(Locale.t("cmd_use_none_owned"), false)
		await _finish_use_command()
		return
	## Abyss entrance world tile (0xe9, 0xe9).
	const ABYSS_ENTRANCE := Vector2i(233, 233)
	if not _combat_active and not _is_in_city() and _tile_pos == ABYSS_ENTRANCE:
		_push_message(Locale.t("cmd_use_skull_abyss"), false)
		GameState.destroy_skull()
		GameState.adjust_karma_destroyed_skull()
		_refresh_inventory_bars()
		if _map != null:
			await _map.await_spell_flash()
		await _finish_use_command()
		return
	_push_message(Locale.t("cmd_use_skull_aloft"), false)
	GameState.adjust_karma_used_skull()
	if _map != null:
		await _map.await_spell_flash()
	## Destroy creatures (combat foes / wilderness / town Persons); spare LB.
	if _combat_active and _map != null and _map.is_in_combat():
		_map.destroy_combat_foes_except_lord_british()
		_refresh_foe_roster()
		if _is_in_city() and _city_map != null and _city_map.has_method("alert_guards"):
			_city_map.alert_guards()
			_city_guards_alerted = true
		if _map.is_combat_won() and not _combat_victory_aftermath:
			await _begin_combat_victory_aftermath()
		elif not _combat_resolving:
			_combat_finish_member_turn()
		return
	if _is_in_city() and _city_map != null:
		if _city_map.has_method("destroy_all_except_lord_british"):
			_city_map.destroy_all_except_lord_british()
		if _city_map.has_method("alert_guards"):
			_city_map.alert_guards()
			_city_guards_alerted = true
		if _map != null and _map.has_method("refresh"):
			_map.refresh()
	elif _world_creatures != null:
		_world_creatures.destroy_all_except_lord_british()
		_sync_creatures_to_map()
	await _finish_use_command()


func _close_use(show_none: bool) -> void:
	var was := _use_stage
	if was == 0:
		if _use_panel:
			_use_panel.close_panel()
		return
	_use_stage = 0
	if _use_panel:
		_use_panel.close_panel()
	if _roster:
		_roster.visible = true
	_close_order_roster()
	_layout_prompt_row()
	if show_none:
		_push_message(Locale.t("cmd_none"), false)
		if not _combat_active:
			_finish_party_turn()


func _do_hole_up() -> void:
	## U5-style Hole up: ask for a watch, then CAMP.CON rest.
	## Solo party — no one left to watch; skip the prompt and rest.
	_push_message(Locale.t("cmd_hole_up"), false)
	var deny := _hole_up_deny_message()
	if not deny.is_empty():
		_push_message(deny, false)
		return
	_camp_guard_klass = -1
	_camp_guard_cursor = 0
	if GameState.party_size() <= 1:
		_begin_camp_rest(-1)
		return
	_camp_stage = 2
	_layout_prompt_row()


func _do_enter() -> void:
	## xu4 'e' → usePortalAt(ACTION_ENTER). Cities/castles/villages for now.
	if _is_in_city():
		_push_message(Locale.t("cmd_enter_what"), false)
		return
	if _transport == Transport.SHIP:
		_push_message(Locale.t("cmd_only_on_foot"), false)
		return
	var portal := _WorldPortals.portal_at(_tile_pos)
	if portal.is_empty():
		_push_message(Locale.t("cmd_enter_what"), false)
		return
	var fname := str(portal.get("fname", ""))
	var path := _CityMapData.resolve_u4_file(fname)
	if path.is_empty():
		_push_message(Locale.t("cmd_enter_fail"), false)
		return
	var cmap = _CityMapData.new()
	if not cmap.load_from_path(path):
		_push_message(Locale.t("cmd_enter_fail"), false)
		return
	var kind := int(portal.get("kind", _WorldPortals.CityKind.TOWNE))
	var kind_name := Locale.t(_WorldPortals.kind_locale_key(kind))
	var city_name := str(portal.get("name", "?"))
	## xu4: "Enter towne!\n\n" then centered city name — we push both lines.
	_push_message(Locale.t("cmd_enter_type", [kind_name]), false)
	_push_message(city_name, false)
	_city_return_pos = _tile_pos
	## Fresh enter from world — anger reset (xu4 forgets next visit).
	_city_guards_alerted = false
	_city_map = cmap
	var start := Vector2i(int(portal.get("sx", 1)), int(portal.get("sy", 15)))
	_tile_pos = start
	if _map != null:
		_map.enter_city(cmap, start, _city_return_pos)
		## Re-apply mount sprite immediately (enter used to wipe MapView transport).
		_map.set_transport_tile(_transport_tile if _transport != Transport.FOOT else -1)
		_map.clear_moongate()
	## xu4 endTurn = 0 on successful enter — do not finish party turn.


func _do_klimb() -> void:
	## xu4 'k' → usePortalAt(ACTION_KLIMB). Castle floors first; dungeon later.
	_use_city_floor_portal(_CityFloorPortals.Action.CLIMB)


func _do_descend() -> void:
	## xu4 'd' → usePortalAt(ACTION_DESCEND). LCB 2→1 for now (abyss later).
	_use_city_floor_portal(_CityFloorPortals.Action.DESCEND)


func _use_city_floor_portal(action: int) -> void:
	## xu4 portal.cpp usePortalAt for city floor ladders (foot only).
	var fail_key := (
		"cmd_klimb_what" if action == _CityFloorPortals.Action.CLIMB
		else "cmd_descend_what"
	)
	if not _is_in_city() or _city_map == null or not _city_map.loaded:
		_push_message(Locale.t(fail_key), false)
		_finish_party_turn()
		return
	## xu4: Klimb/Descend require TRANSPORT_FOOT (horse blocked).
	if _transport != Transport.FOOT:
		if action == _CityFloorPortals.Action.CLIMB:
			## xu4 prints "Klimb\n" before "Only on foot!" (Descend omits the verb).
			_push_message(U4Commands.label(U4Commands.Id.KLIMB, GameState.lang_short()), false)
		_push_message(Locale.t("cmd_only_on_foot"), false)
		_finish_party_turn()
		return
	var fname := str(_city_map.source_path).get_file()
	var portal := _CityFloorPortals.portal_at(fname, _tile_pos, action)
	if portal.is_empty():
		_push_message(Locale.t(fail_key), false)
		_finish_party_turn()
		return
	var dest_fname := str(portal.get("dest_fname", ""))
	var path := _CityMapData.resolve_u4_file(dest_fname)
	var cmap = _CityMapData.new()
	if path.is_empty() or not cmap.load_from_path(path):
		_push_message(Locale.t("cmd_enter_fail"), false)
		_finish_party_turn()
		return
	var start := Vector2i(
		clampi(int(portal.get("dx", _tile_pos.x)), 0, _CityMapData.WIDTH - 1),
		clampi(int(portal.get("dy", _tile_pos.y)), 0, _CityMapData.HEIGHT - 1)
	)
	var msg_key := str(portal.get("msg", ""))
	if not msg_key.is_empty():
		_push_message(Locale.t(msg_key), false)
	_stash_emptied_city_chests()
	_city_map = cmap
	## Same stay (e.g. LCB 1↔2): re-apply alertGuards to newly loaded NPCs.
	_apply_city_guards_alerted()
	_tile_pos = start
	## Keep world exit tile; rim plains still from original Enter spawn.
	var world_portal := _WorldPortals.portal_at(_city_return_pos)
	if world_portal.is_empty():
		world_portal = _WorldPortals.portal_for_fname(dest_fname)
	var spawn := Vector2i(
		int(world_portal.get("sx", 15)),
		int(world_portal.get("sy", 30))
	)
	if _map != null:
		_map.enter_city(cmap, start, _city_return_pos, spawn)
		_map.set_transport_tile(-1)
		_map.clear_moongate()
	_finish_party_turn()


func _apply_city_guards_alerted() -> void:
	## After floor load / restore while still in the same castle visit.
	if not _city_guards_alerted or _city_map == null or not _city_map.loaded:
		return
	if _city_map.has_method("alert_guards"):
		_city_map.alert_guards()


func _is_in_city() -> bool:
	return _city_map != null and _city_map.loaded


func _city_map_fname(cmap = null) -> String:
	var m = cmap if cmap != null else _city_map
	if m == null:
		return ""
	return str(m.source_path).get_file().to_lower()


func _stash_emptied_city_chests() -> void:
	## Remember only looted spots; open lids are discarded on leave/floor change.
	if _city_map == null or not _city_map.loaded:
		return
	if not _city_map.has_method("emptied_chest_keys"):
		return
	var fname := _city_map_fname()
	if fname.is_empty():
		return
	var bucket: Dictionary = _city_chest_memory.get(fname, {})
	if typeof(bucket) != TYPE_DICTIONARY:
		bucket = {}
	for key in _city_map.emptied_chest_keys():
		bucket[str(key)] = true
	_city_chest_memory[fname] = bucket


func _mark_city_chest_emptied(x: int, y: int) -> void:
	var fname := _city_map_fname()
	if fname.is_empty():
		return
	var bucket: Dictionary = _city_chest_memory.get(fname, {})
	if typeof(bucket) != TYPE_DICTIONARY:
		bucket = {}
	bucket[_CityMapData.chest_key(x, y)] = true
	_city_chest_memory[fname] = bucket


func _is_remembered_empty_chest(x: int, y: int) -> bool:
	var fname := _city_map_fname()
	if fname.is_empty() or not _city_chest_memory.has(fname):
		return false
	var bucket: Variant = _city_chest_memory[fname]
	if typeof(bucket) != TYPE_DICTIONARY:
		return false
	return bool((bucket as Dictionary).get(_CityMapData.chest_key(x, y), false))


func _city_chests_to_save() -> Dictionary:
	_stash_emptied_city_chests()
	var out := {}
	for fname in _city_chest_memory.keys():
		var chests: Variant = _city_chest_memory[fname]
		if typeof(chests) != TYPE_DICTIONARY:
			continue
		var copy := {}
		for ck in (chests as Dictionary).keys():
			if bool((chests as Dictionary)[ck]):
				copy[str(ck)] = true
		if not copy.is_empty():
			out[str(fname)] = copy
	return out


func _load_city_chest_memory(raw: Variant) -> void:
	## Accept new `{ "x,y": true }` and older open-state dicts (icon_shown == 0 only).
	_city_chest_memory.clear()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for fname in (raw as Dictionary).keys():
		var chests: Variant = (raw as Dictionary)[fname]
		if typeof(chests) != TYPE_DICTIONARY:
			continue
		var copy := {}
		for ck in (chests as Dictionary).keys():
			var d: Variant = (chests as Dictionary)[ck]
			var emptied := false
			if typeof(d) == TYPE_BOOL:
				emptied = bool(d)
			elif typeof(d) == TYPE_DICTIONARY:
				emptied = int((d as Dictionary).get("icon_shown", 0)) <= 0
			if emptied:
				copy[str(ck)] = true
		if not copy.is_empty():
			_city_chest_memory[str(fname).to_lower()] = copy


func _exit_city() -> void:
	## Leave city back to the world tile we Entered from.
	if not _is_in_city():
		return
	_stash_emptied_city_chests()
	## Leaving the place forgets anger (xu4 City::addPerson next visit).
	_city_guards_alerted = false
	_city_map = null
	_tile_pos = _city_return_pos
	if _map != null:
		_map.exit_city()
		_map.set_center(_tile_pos, false)
		_map.set_transport_tile(_transport_tile if _transport != Transport.FOOT else -1)
	_sync_creatures_to_map()
	_sync_moongate(true)
	_refresh_locate_hud()
	_push_message(Locale.t("cmd_exit_city"), false)


func _hole_up_deny_message() -> String:
	## xu4 holeUp():
	## - !(WORLDMAP|DUNGEON) → "Not here!" (inside towns/castles)
	## - transport != FOOT → "Only on foot!" (horse / ship / balloon)
	## On the world map we also reject water and settlement portal tiles
	## (dungeon/city/castle/town/LCB) — same "Not here!" spirit.
	if _is_in_city():
		return Locale.t("cmd_not_here")
	if _transport != Transport.FOOT:
		return Locale.t("cmd_only_on_foot")
	if _world != null and _world.loaded:
		var tid := _world.tile_at(_tile_pos.x, _tile_pos.y)
		if _TileRules.is_water(tid) or _is_settlement_portal_tile(tid):
			return Locale.t("cmd_not_here")
	return ""


func _is_settlement_portal_tile(tid: int) -> bool:
	## shapes indices 9–15: dungeon / city / castle / town / LCB wings.
	return tid >= 9 and tid <= 15


func _handle_camp_input(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if _camp_stage == 2:
		return _handle_camp_watch_yn(event)
	if _camp_stage == 3:
		return _handle_camp_guard_pick(event)
	## Resting… — swallow all input except Tab (handled in _input).
	return true


func _handle_camp_watch_yn(event: InputEvent) -> bool:
	## U5: Set a watch? — Y / N (A=Yes, B/Esc/Space=cancel→None).
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
			_cancel_camp(true)
			return true
		if _is_order_cancel_key(k):
			_cancel_camp(true)
			return true
		if k.keycode == KEY_Y or k.physical_keycode == KEY_Y:
			_accept_camp_set_watch(true)
			return true
		if k.keycode == KEY_N or k.physical_keycode == KEY_N:
			_accept_camp_set_watch(false)
			return true
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if jb.button_index == JOY_BUTTON_A:
			_accept_camp_set_watch(true)
			return true
		if jb.button_index == JOY_BUTTON_B:
			_cancel_camp(true)
			return true
	if event.is_action_pressed("cancel") and event is InputEventJoypadButton:
		_cancel_camp(true)
		return true
	return true


func _accept_camp_set_watch(yes: bool) -> void:
	_push_message(Locale.t("cmd_yes" if yes else "cmd_no"), false)
	if not yes:
		_begin_camp_rest(-1)
		return
	## Need at least one living member to stand watch.
	if _living_party_slot_count() < 1:
		_begin_camp_rest(-1)
		return
	_camp_stage = 3
	_camp_guard_cursor = _first_living_party_slot()
	_open_order_roster()
	_reset_hold_state()
	if _roster:
		_roster.visible = true
	_sync_camp_guard_selection()
	_layout_prompt_row()


func _handle_camp_guard_pick(event: InputEvent) -> bool:
	## Who will guard? — list cursor + digits both work; bad picks stay on prompt.
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
			_cancel_camp(true)
			return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		_cancel_camp(true)
		return true
	if event.is_action_pressed("cancel") and event is InputEventJoypadButton:
		_cancel_camp(true)
		return true
	if event is InputEventKey and _is_order_cancel_key(event as InputEventKey):
		_cancel_camp(true)
		return true
	if event is InputEventKey and _is_order_confirm_key(event as InputEventKey):
		_accept_camp_guard_slot(_camp_guard_cursor)
		return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
		_accept_camp_guard_slot(_camp_guard_cursor)
		return true
	if event is InputEventKey:
		var ke := event as InputEventKey
		var dig := _player_digit_index_from_key(ke)
		if dig >= 0:
			## Keys 1–8: in-range → try accept; out of party → Who? and re-prompt.
			if dig >= GameState.party_size():
				_push_message(Locale.t("cmd_who"), false)
				_layout_prompt_row()
				return true
			_camp_guard_cursor = dig
			_sync_camp_guard_selection()
			_accept_camp_guard_slot(dig)
			return true
		if _is_digit_key(ke):
			## 0 / 9 / etc. — not a party number.
			_push_message(Locale.t("cmd_who"), false)
			_layout_prompt_row()
			return true
	return true


func _nudge_camp_guard_cursor(delta: int) -> void:
	var n := maxi(GameState.party_size(), 1)
	var slot := _camp_guard_cursor
	for _i in n:
		slot = posmod(slot + delta, n)
		if _camp_guard_slot_eligible(slot):
			_camp_guard_cursor = slot
			_sync_camp_guard_selection()
			return


func _sync_camp_guard_selection() -> void:
	if _roster:
		_roster.set_order_selection(_camp_guard_cursor, -1)


func _camp_guard_slot_eligible(slot: int) -> bool:
	## Awake, living party members only (xu4 isDisabled → dead / sleeping).
	if slot < 0 or slot >= GameState.party_size():
		return false
	var mid := GameState.party_member_at(slot)
	if mid < 0:
		return false
	return not GameState.is_member_disabled(mid)


func _accept_camp_guard_slot(slot: int) -> void:
	## List Enter and digit keys share this path — reject stays on Who will guard?
	var n := GameState.party_size()
	if slot < 0 or slot >= n:
		_push_message(Locale.t("cmd_who"), false)
		_layout_prompt_row()
		return
	if not _camp_guard_slot_eligible(slot):
		_push_message(Locale.t("cmd_cant"), false)
		_layout_prompt_row()
		return
	var mid := GameState.party_member_at(slot)
	var pname := GameState.party_member_display_name(slot)
	_push_message(Locale.t("cmd_camp_guard_named", [pname]), false)
	_clear_order_selection()
	if not _sides_open:
		_close_order_roster()
	_begin_camp_rest(mid)


func _living_party_slot_count() -> int:
	var n := 0
	for i in GameState.party_size():
		if _camp_guard_slot_eligible(i):
			n += 1
	return n


func _first_living_party_slot() -> int:
	for i in GameState.party_size():
		if _camp_guard_slot_eligible(i):
			return i
	return 0


func _begin_camp_rest(guard_klass: int) -> void:
	var path := _CombatMapData.resolve_u4_file("CAMP.CON")
	var cmap = _CombatMapData.new()
	if path.is_empty() or not cmap.load_from_path(path):
		_push_message(Locale.t("cmd_not_here"), false)
		_camp_stage = 0
		_camp_guard_klass = -1
		_layout_prompt_row()
		return

	_camp_guard_klass = guard_klass
	var sleepers: Array[Vector2i] = []
	var guard_pos := Vector2i(5, 5)
	for i in GameState.party_size():
		var mid := GameState.party_member_at(i)
		if mid < 0 or GameState.is_class_dead(mid):
			continue
		var start: Vector2i = (
			cmap.player_start[i] if i < cmap.player_start.size() else Vector2i(5, 5)
		)
		if mid == guard_klass:
			guard_pos = start
			continue
		sleepers.append(start)

	_camp_map = cmap
	GameState.put_party_to_sleep(guard_klass)
	_refresh_party()
	if _map:
		_map.enter_camp(cmap, sleepers, guard_klass, guard_pos)

	_push_message(Locale.t("cmd_camp_resting"), false)
	_camp_stage = 1
	## Roll ambush once at rest start (xu4 1/8). If yes, interrupt early:
	## random time in [CAMP_AMBUSH_MIN_SEC, CAMP_REST_SEC] — never wait the full
	## rest solely to check. Safe rest always uses full CAMP_REST_SEC.
	_camp_ambush_pending = (randi() % 8) == 0
	if _camp_ambush_pending:
		var lo := CAMP_AMBUSH_MIN_SEC
		var hi := CAMP_REST_SEC
		if hi < lo:
			hi = lo
		_camp_rest_left = randf_range(lo, hi)
	else:
		_camp_rest_left = CAMP_REST_SEC
	_layout_prompt_row()


func _tick_camp_rest(delta: float) -> void:
	if _camp_stage != 1:
		return
	if _map:
		_map.tick_camp_guard(delta)
	_camp_rest_left -= delta
	if _camp_rest_left > 0.0:
		return
	_finish_camp_rest()


func _finish_camp_rest() -> void:
	## Outcome was decided at rest start (_camp_ambush_pending).
	## U5 watch: guard is always excluded from heal.
	if _camp_ambush_pending:
		_camp_ambush_pending = false
		_push_message(Locale.t("cmd_camp_ambushed"), false)
		## Async handoff: camp → combat on CAMP.CON (panels may open).
		_begin_camp_ambush_combat()
		return

	var healed := false
	if GameState.camp_heal_available():
		healed = GameState.apply_camp_rest(_camp_guard_klass)
	GameState.mark_camp_used()
	_push_message(
		Locale.t("cmd_camp_healed" if healed else "cmd_camp_no_effect"),
		false
	)
	_end_camp_session(true)


func _begin_camp_ambush_combat() -> void:
	## xu4 CampController ambush: place ambushers on CAMP.CON, foes act first.
	## U5 watch: wake the whole party immediately; without watch stay asleep (xu4).
	if _combat_active or _party_wiped_or_dying():
		_end_camp_session(false)
		return
	var cmap = _camp_map
	if cmap == null:
		var path := _CombatMapData.resolve_u4_file("CAMP.CON")
		var fresh = _CombatMapData.new()
		if not path.is_empty() and fresh.load_from_path(path):
			cmap = fresh
	if cmap == null:
		_end_camp_session(false)
		return

	var had_watch := _camp_guard_klass >= 0
	if had_watch:
		GameState.wake_party()
		_refresh_party()
	else:
		## Re-assert sleep — avoid any edge case that cleared status during rest.
		GameState.put_party_to_sleep(-1)
		_refresh_party()

	## Drop camp UI without ending the world turn (combat owns the session).
	_camp_stage = 0
	_camp_rest_left = 0.0
	_camp_ambush_pending = false
	_camp_guard_klass = -1
	_camp_map = null
	_layout_prompt_row()

	var ambush_tid := _CombatEncounter.random_ambushing_tile()
	var foe := {
		"tile": ambush_tid,
		"x": _tile_pos.x,
		"y": _tile_pos.y,
		"facing": 0,
	}
	## force CAMP.CON + skip "Attacked by…" (already Ambushed!) + creatures first.
	await _begin_combat(foe, false, cmap, true)


func _end_camp_session(_healed: bool) -> void:
	GameState.wake_party()
	_refresh_party()
	if _map:
		_map.exit_camp()
	_camp_map = null
	_camp_stage = 0
	_camp_rest_left = 0.0
	_camp_ambush_pending = false
	_camp_guard_klass = -1
	_layout_prompt_row()
	_finish_party_turn()


func _cancel_camp(show_none: bool) -> void:
	## Abort watch prompt / Resting… without heal.
	if _camp_stage == 0:
		return
	var was := _camp_stage
	if was == 1:
		GameState.wake_party()
		_refresh_party()
		if _map:
			_map.exit_camp()
	elif was == 3:
		_clear_order_selection()
		if not _sides_open:
			_close_order_roster()
	_camp_map = null
	_camp_stage = 0
	_camp_rest_left = 0.0
	_camp_ambush_pending = false
	_camp_guard_klass = -1
	_layout_prompt_row()
	if show_none:
		_push_message(Locale.t("cmd_none"), false)
	_finish_party_turn()


func _close_camp(_show_none: bool) -> void:
	## Silent abort when another command preempts camp.
	if _camp_stage == 0:
		return
	var was := _camp_stage
	if was == 1:
		GameState.wake_party()
		_refresh_party()
		if _map:
			_map.exit_camp()
	elif was == 3:
		_clear_order_selection()
		if not _sides_open:
			_close_order_roster()
	_camp_map = null
	_camp_stage = 0
	_camp_rest_left = 0.0
	_camp_ambush_pending = false
	_camp_guard_klass = -1
	_layout_prompt_row()
	_finish_party_turn()


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


func _player_digit_index_from_key(event: InputEventKey) -> int:
	## Keys 1–8 → 0..7. Not a 1–8 digit → -1 (caller may treat 0/9 as Who?).
	var code := event.keycode
	var phys := event.physical_keycode
	if code >= KEY_1 and code <= KEY_8:
		return code - KEY_1
	if phys >= KEY_1 and phys <= KEY_8:
		return phys - KEY_1
	if code >= KEY_KP_1 and code <= KEY_KP_8:
		return code - KEY_KP_1
	if phys >= KEY_KP_1 and phys <= KEY_KP_8:
		return phys - KEY_KP_1
	return -1


func _player_slot_from_key(event: InputEventKey) -> int:
	## 1..party_size → 0-based slot; else -1 (xu4 None).
	var n := _player_digit_index_from_key(event)
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


func _finish_party_turn(in_combat: bool = false) -> void:
	## xu4 GameController::finishTurn → Party::endTurn (food / status / starve / hull).
	## Combat turns pass in_combat=true so moves (camp heal clock) do not advance.
	## While the whole party is asleep, loops with "Zzzzzz" until someone wakes.
	_stamp_command_time()
	await _run_party_turn_once(in_combat)
	if in_combat:
		return
	_maybe_continue_immobilized()


func _run_party_turn_once(in_combat: bool = false) -> void:
	var result: Dictionary = GameState.end_party_turn(true, in_combat)
	## xu4 finishTurn: aura.passTurn after Party::endTurn (world turns).
	if not in_combat:
		GameState.pass_aura_turn()
	## xu4: after endTurn, applyEffect from tile underfoot (skipped while flying / combat).
	var ground_flash := 0 if in_combat else _apply_ground_tile_effect()
	## xu4 Map::moveObjects — town NPCs roam after the party acts.
	if not in_combat:
		await _move_city_persons()
	## xu4 creatureCleanup → checkRandomCreatures (world; offscreen of explore view).
	if not in_combat:
		await _update_world_creatures()
	## Death after world AI (ship sink / cannon wipe) — skip leftover turn bookkeeping FX noise.
	if not in_combat and _party_wiped_or_dying():
		return
	## xu4 annotations.passTurn — open doors close after ttl.
	if not in_combat:
		_pass_map_annotations()
	if result.get("food_changed", false):
		_refresh_inventory_bars()
	if result.get("starving", false):
		_push_message(Locale.t("cmd_starving"), false)
	if result.get("ship_hull_changed", false):
		## xu4 regenerates saveGame.shiphull on the world map even ashore.
		if _transport != Transport.SHIP and _parked_ship_tile.x >= 0:
			_store_ship_hull_at(_parked_ship_tile, GameState.ship_hull)
		_refresh_ship_hull_hud()
	var mask: int = int(result.get("damaged_mask", 0)) | ground_flash
	if result.get("vitals_changed", false) or ground_flash != 0:
		_refresh_party()
		if mask != 0:
			if _roster and _roster.has_method("flash_players"):
				_roster.flash_players(mask)
			if _compact_roster and _compact_roster.has_method("flash_players"):
				_compact_roster.flash_players(mask)


func _maybe_continue_immobilized() -> void:
	## xu4: while isImmobilized && !isDead → "Zzzzzz" then another finishTurn.
	## xu4 finishTurn: isDead → deathStart(0).
	if GameState.is_party_dead():
		_immobilized_pending = false
		_start_death_sequence(0.0)
		return
	if not GameState.is_party_immobilized():
		_immobilized_pending = false
		return
	_push_message(Locale.t("cmd_zzzzzz"), false)
	if _immobilized_pending:
		return
	_immobilized_pending = true
	var tree := get_tree()
	if tree == null:
		_immobilized_pending = false
		return
	tree.create_timer(IMMOBILIZED_SLEEP_SEC).timeout.connect(
		_on_immobilized_timer,
		CONNECT_ONE_SHOT
	)


func _on_immobilized_timer() -> void:
	_immobilized_pending = false
	if not is_inside_tree():
		return
	if _death_busy:
		return
	if GameState.is_party_dead():
		_start_death_sequence(0.0)
		return
	if not GameState.is_party_immobilized():
		_refresh_party()
		return
	await _run_party_turn_once(false)
	_maybe_continue_immobilized()


func _start_death_sequence(delay_sec: float = 0.0) -> void:
	## xu4 deathStart — fade music (n/a), hide cursor, optional delay, messages, revive.
	if _death_busy or not GameState.is_party_dead():
		return
	_death_busy = true
	_immobilized_pending = false
	_reset_hold_state()
	_clear_pending_dir()
	_clear_ship_yell_await()
	_stop_ship_cruise()
	_run_death_sequence_async(delay_sec)


func _run_death_sequence_async(delay_sec: float) -> void:
	## xu4 deathStart(delay) then DeathController (PAUSE_SEC per line).
	## First controller beat ≈ 5s: 3s hold + 2s map fade (same total as xu4's 5s).
	_close_ui_for_death()
	if _msg_cursor:
		_msg_cursor.visible = false
	## Keep the message panel open so lines stay readable during the cutscene.
	if not _sides_open:
		_toggle_side_panels()
	## deathStart(5) wait — combat/map still visible.
	if delay_sec > 0.0:
		await _death_wait(delay_sec)
	if not is_inside_tree() or not _death_busy:
		_abort_death_sequence()
		return
	## First DeathController beat before msg 0 (xu4 PAUSE_SEC=5, split hold+fade).
	await _death_wait(DEATH_CONTROLLER_HOLD_SEC)
	if not is_inside_tree() or not _death_busy:
		_abort_death_sequence()
		return
	await _death_fade_to_black(DEATH_FADE_OUT_SEC)
	if not is_inside_tree() or not _death_busy:
		_abort_death_sequence()
		return
	_push_death_blank_lines(3)
	_push_message(Locale.t("death_all_is_dark"), false)

	var steps: Array = [
		{"blanks": 1, "key": "death_but_wait"},
		{"blanks": 0, "key": "death_where_am_i"},
		{"blanks": 0, "key": "death_am_i_dead"},
		{"blanks": 0, "key": "death_afterlife"},
		{"blanks": 0, "key": "death_you_hear", "name": true},
		{"blanks": 0, "key": "death_i_feel_motion"},
		{"blanks": 1, "key": "death_lord_british", "prompt": true},
	]
	for step in steps:
		await _death_wait(DEATH_PAUSE_SEC)
		if not is_inside_tree() or not _death_busy:
			_abort_death_sequence()
			return
		var blanks := int(step.get("blanks", 0))
		if blanks > 0:
			_push_death_blank_lines(blanks)
		_push_message(Locale.t(str(step.get("key", ""))), false)
		if bool(step.get("name", false)):
			_push_message(_death_centered_name(), false)
		if bool(step.get("prompt", false)):
			## xu4 ends the LB line with CHARSET_PROMPT.
			_layout_prompt_row()
			if _msg_cursor:
				_msg_cursor.visible = true
	_death_revive()


func _death_wait(sec: float) -> void:
	## Always-process timer so a paused tree / busy _process cannot stall death.
	if sec <= 0.0:
		return
	var tree := get_tree()
	if tree == null:
		return
	var t := tree.create_timer(sec, true, false, true)
	await t.timeout


func _abort_death_sequence() -> void:
	## Never leave the player on a permanent black map pane.
	_kill_death_fade_tween()
	_set_death_blackout(false)
	_death_busy = false
	if _msg_cursor:
		_msg_cursor.visible = true
	_layout_prompt_row()


func _push_death_blank_lines(count: int) -> void:
	for _i in count:
		## `_push_message` rejects empty strings — space keeps a blank row.
		_msg_lines.append(" ")
	while _msg_lines.size() > MSG_KEEP:
		_msg_lines.remove_at(0)
	_refresh_message_view()


func _death_centered_name() -> String:
	## xu4: pad avatar name to TEXT_AREA_W (16) centered.
	var name := GameState.party_member_display_name(0)
	if name.length() >= DEATH_NAME_WIDTH:
		return name
	var spaces := int((DEATH_NAME_WIDTH - name.length()) / 2)
	var pad := ""
	for _i in spaces:
		pad += " "
	return pad + name


func _kill_death_fade_tween() -> void:
	if _death_fade_tween != null and is_instance_valid(_death_fade_tween):
		_death_fade_tween.kill()
	_death_fade_tween = null


func _ensure_death_blackout() -> void:
	## Map-area black veil (under message / roster panes).
	if _map_pane == null or _map == null:
		return
	if _death_blackout == null or not is_instance_valid(_death_blackout):
		_death_blackout = ColorRect.new()
		_death_blackout.name = "DeathBlackout"
		_death_blackout.color = Color.BLACK
		_death_blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_death_blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_map_pane.add_child(_death_blackout)
	## Sit immediately above MapView; Left/Right panes stay later → on top.
	var idx := _map.get_index() + 1
	_map_pane.move_child(_death_blackout, clampi(idx, 0, _map_pane.get_child_count() - 1))


func _death_fade_to_black(duration: float) -> void:
	## Soft fade-out into the death cutscene (combat wipe or other total death).
	if _map_pane == null or _map == null:
		return
	_ensure_death_blackout()
	_kill_death_fade_tween()
	_death_blackout.visible = true
	_death_blackout.color = Color.BLACK
	if duration <= 0.0:
		_death_blackout.modulate = Color(1, 1, 1, 1)
		return
	_death_blackout.modulate = Color(1, 1, 1, 0)
	_death_fade_tween = create_tween()
	## Keep fading even if the scene tree is paused.
	_death_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_death_fade_tween.tween_property(
		_death_blackout, "modulate:a", 1.0, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _death_fade_tween.finished
	_death_fade_tween = null
	if _death_blackout != null and is_instance_valid(_death_blackout):
		_death_blackout.modulate = Color(1, 1, 1, 1)


func _set_death_blackout(on: bool) -> void:
	## Hard snap blackout on/off (abort / after revive). Prefer fade for cut-in.
	_kill_death_fade_tween()
	if _map_pane == null or _map == null:
		return
	if on:
		_ensure_death_blackout()
		_death_blackout.modulate = Color(1, 1, 1, 1)
		_death_blackout.visible = true
	elif _death_blackout != null and is_instance_valid(_death_blackout):
		_death_blackout.visible = false
		_death_blackout.modulate = Color(1, 1, 1, 1)


func _close_ui_for_death() -> void:
	## Drop modal UIs so the message log owns the sequence.
	## Avoid helpers that call `_finish_party_turn` (would re-enter death).
	if _peer_overlay != null and _peer_overlay.is_open():
		_peer_overlay.close_peer()
	_close_ztats(false)
	_close_ready(false)
	_close_wear(false)
	_mix_stage = 0
	if _mix_panel:
		_mix_panel.close_panel()
	_use_stage = 0
	if _use_panel:
		_use_panel.close_panel()
	if _save_stage != 0:
		_close_save(false)
	if _esc_menu_is_open():
		_close_esc_menu()
	_camp_stage = 0
	_camp_guard_klass = -1
	_camp_rest_left = 0.0
	_camp_map = null
	if _map != null and _map.is_camping():
		_map.exit_camp()
	## Wipe-from-combat: clear arena widgets; map stays until blackout/revive.
	_combat_clear_aim_state()
	if _foe_roster:
		_foe_roster.clear()
	_chest_open_stage = 0
	_telescope_stage = 0
	_order_stage = 0
	_ready_stage = 0
	_wear_stage = 0
	if _roster:
		_roster.visible = true
	_layout_prompt_row()


func _death_revive() -> void:
	## xu4 deathRevive — unwind to world, enter LCB-2 at throne, reviveParty.
	## Always clear blackout/busy even if a later step fails.
	_set_death_blackout(false)
	## Leave combat / city / camp without printing exit chatter.
	if _map != null and _map.is_in_combat():
		_map.exit_combat()
	_combat_active = false
	_combat_resolving = false
	_combat_victory_aftermath = false
	_combat_foe = {}
	if _map != null and _map.is_camping():
		_map.exit_camp()
	_camp_stage = 0
	_camp_map = null
	if _is_in_city():
		_stash_emptied_city_chests()
		_city_guards_alerted = false
		_city_map = null
		if _map != null:
			_map.exit_city()
	var portal := _WorldPortals.portal_for_fname("lcb_1.ult")
	var world_pos := DEATH_LCB_WORLD
	if not portal.is_empty() and portal.has("wx"):
		world_pos = Vector2i(int(portal["wx"]), int(portal["wy"]))
	_city_return_pos = world_pos
	_tile_pos = world_pos
	if _map != null:
		_map.set_center(_tile_pos, false)
		_map.clear_moongate()
	## xu4 setTransport(avatar) — always on foot after revive.
	_transport = Transport.FOOT
	_transport_tile = -1
	_horse_gallop = false
	_ship_cruise_dir = Vector2i.ZERO
	if _map != null:
		_map.set_transport_tile(-1)
	var path := _CityMapData.resolve_u4_file("lcb_2.ult")
	var cmap = _CityMapData.new()
	var entered := false
	if not path.is_empty() and cmap.load_from_path(path):
		_city_guards_alerted = false
		_city_map = cmap
		var start := DEATH_REVIVE_CASTLE
		_tile_pos = start
		var spawn := Vector2i(
			int(portal.get("sx", 15)),
			int(portal.get("sy", 30))
		)
		if _map != null:
			_map.enter_city(cmap, start, world_pos, spawn)
			_map.set_transport_tile(-1)
			_map.clear_moongate()
		entered = true
	else:
		push_warning("death revive: cannot load lcb_2.ult — staying at world LCB gate")
	GameState.revive_party()
	_refresh_party()
	_refresh_inventory_bars()
	_refresh_ship_hull_hud()
	_sync_creatures_to_map()
	_refresh_locate_hud()
	_stamp_command_time()
	_death_busy = false
	if _msg_cursor:
		_msg_cursor.visible = true
	_layout_prompt_row()
	if not entered and _map != null:
		_map.set_center(_tile_pos, false)


func _move_city_persons() -> void:
	## xu4 finishTurn → location->map->moveObjects(avatar).
	## Adjacent MOVE_ATTACK persons then engage combat (like wilderness attackers).
	if _combat_active or not _is_in_city() or _city_map == null or not _city_map.loaded:
		return
	if _city_map.move_persons(_tile_pos):
		if _map != null and _map.has_method("refresh"):
			_map.refresh()
	if _combat_active or _party_wiped_or_dying():
		return
	if not _city_map.has_method("take_adjacent_attacker"):
		return
	var foe: Dictionary = _city_map.take_adjacent_attacker(_tile_pos)
	if foe.is_empty():
		return
	if _map != null and _map.has_method("refresh"):
		_map.refresh()
	await _begin_combat(foe, false)


func _pass_map_annotations() -> void:
	## xu4 AnnotationList::passTurn after creature moves.
	if not _is_in_city() or _city_map == null or not _city_map.loaded:
		return
	if not _city_map.pass_annotation_turns():
		return
	if _map != null and _map.has_method("refresh"):
		_map.refresh()


func _apply_ground_tile_effect() -> int:
	## xu4 finishTurn: map->tileTypeAt(coords)->getEffect() → Party::applyEffect.
	if _is_in_city():
		if _city_map == null or not _city_map.loaded:
			return 0
		var ctid := int(_city_map.effective_tile_at(_tile_pos.x, _tile_pos.y))
		return GameState.apply_tile_effect(_TileRules.effect_of(ctid))
	if _world == null:
		return 0
	var tid := _world.tile_at(_tile_pos.x, _tile_pos.y)
	return GameState.apply_tile_effect(_TileRules.effect_of(tid))


func _stamp_command_time() -> void:
	## xu4 gameStampCommandTime() — restart idle Pass timer.
	_idle_since_command = 0.0


func _can_auto_pass() -> bool:
	## Only while free world TurnController would be active in xu4.
	if not _load_error.is_empty():
		return false
	if _is_party_asleep_locked():
		return false
	if _peer_overlay != null and _peer_overlay.is_open():
		return false
	if _ztats_stage != 0 or _order_stage != 0 or _ready_stage != 0 or _wear_stage != 0 or _mix_stage != 0 or _use_stage != 0 or _camp_stage != 0 or _chest_open_stage != 0 or _telescope_stage != 0 or _save_stage != 0 or _esc_menu_is_open() or _options_panel_is_open():
		return false
	if _moongate_busy or _cannon_busy or _search_busy or _death_busy or _combat_active:
		return false
	if _pending_cmd != U4Commands.Id.NONE:
		return false
	if _ship_yell_await_dir:
		return false
	if _ship_cruise_dir != Vector2i.ZERO:
		return false
	return true


func _is_party_asleep_locked() -> bool:
	## xu4 immobilized party — waiting on Zzzzzz turn pump.
	## All-dead also immobilizes; death sequence owns that state via `_death_busy`.
	if _death_busy:
		return true
	return _immobilized_pending or GameState.is_party_immobilized()


func _tick_auto_pass(delta: float) -> void:
	## xu4 timerFired: if gameTimeSinceLastCommand() > 20 → Space (Space).
	if not _can_auto_pass():
		return
	_idle_since_command += delta
	if _idle_since_command > AUTO_PASS_SEC:
		_do_auto_pass()


func _do_auto_pass() -> void:
	var name := U4Commands.label(U4Commands.Id.PASS, GameState.lang_short())
	_push_message(Locale.t("cmd_fired", [name]))
	_finish_party_turn()


func _finish_directed_command(dir: Vector2i) -> void:
	var cmd := _pending_cmd
	var cmd_name := _pending_cmd_name
	_clear_pending_dir()
	## xu4 erases "Dir?" on the same line and writes the direction name.
	var dir_name := _direction_label(dir)
	if not cmd_name.is_empty() and not dir_name.is_empty():
		_push_message(Locale.t("cmd_dir_done", [cmd_name, dir_name]))
	var result := ""
	match cmd:
		U4Commands.Id.ATTACK:
			result = await _do_attack(dir)
			## Engaging combat replaces finishTurn (xu4 CombatController push).
			if _combat_active:
				if not result.is_empty():
					_push_message(result, false)
				return
		U4Commands.Id.OPEN:
			result = _do_open(dir)
		U4Commands.Id.JIMMY:
			result = _do_jimmy(dir)
		U4Commands.Id.GET_CHEST:
			result = _do_get_chest(dir)
		U4Commands.Id.FIRE:
			result = _do_fire_cannon(dir)
			if result.is_empty():
				await _fire_cannon_along_async(_tile_pos, dir, true)
		_:
			result = _directed_result_message(cmd)
	if not result.is_empty():
		_push_message(result, false)
	## Chest Open waits on "Who opens?" — turn finishes after the pick.
	if _chest_open_stage != 0:
		return
	## Victory aftermath: free map — directed Open/Get must not start turn coroutines.
	if _combat_active and _combat_victory_aftermath:
		return
	## Combat arena: directed action spends the current member (not party clock).
	if _combat_active:
		await _combat_finish_member_turn()
		return
	## xu4: directed actions consume a turn (Attack/Jimmy/Open/…).
	await _finish_party_turn()


func _do_attack(dir: Vector2i) -> String:
	## xu4 attackAt — adjacent wilderness creature or townsfolk → engage combat.
	if _combat_active:
		return Locale.t("cmd_nothing_to_attack")
	if _map != null and _map.is_camping():
		return Locale.t("cmd_nothing_to_attack")
	if _is_in_city():
		return await _do_city_attack(dir)
	if _world_creatures == null or _world == null or not _world.loaded:
		return Locale.t("cmd_nothing_to_attack")
	## Cardinal / diagonal 1-step (remake dirs); wrap on world torus.
	var target := Vector2i(
		posmod(_tile_pos.x + dir.x, WorldMapData.WIDTH),
		posmod(_tile_pos.y + dir.y, WorldMapData.HEIGHT)
	)
	if _world_creatures.creature_at(target) < 0:
		return Locale.t("cmd_nothing_to_attack")
	var foe := _world_creatures.take_at(target)
	if foe.is_empty():
		return Locale.t("cmd_nothing_to_attack")
	_sync_creatures_to_map()
	await _begin_combat(foe, true)
	return ""


func _do_city_attack(dir: Vector2i) -> String:
	## xu4 attackAt on city object — alert guards + KA_ATTACKED_GOOD + engage.
	if _city_map == null or not _city_map.loaded:
		return Locale.t("cmd_nothing_to_attack")
	var target := Vector2i(_tile_pos.x + dir.x, _tile_pos.y + dir.y)
	if (
		target.x < 0 or target.y < 0
		or target.x >= _CityMapData.WIDTH
		or target.y >= _CityMapData.HEIGHT
	):
		return Locale.t("cmd_nothing_to_attack")
	var idx: int = int(_city_map.person_index_at(target.x, target.y))
	if idx < 0:
		return Locale.t("cmd_nothing_to_attack")
	var movement: int = _CityMapData.MOVE_FIXED
	if idx < _city_map.person_move.size():
		movement = int(_city_map.person_move[idx])
	var was_hostile: bool = movement == _CityMapData.MOVE_ATTACK
	var tid: int = int(_city_map.persons[idx].z)
	## You're attacking a townsperson! Alert the guards!
	if not was_hostile:
		_city_map.alert_guards()
		## Persist across LCB floor changes until Leave castle / exit map.
		_city_guards_alerted = true
	## Attacking good creatures or a docile person is bad karma.
	if (
		_WorldCreaturesScript.is_good(tid)
		or not was_hostile
	):
		GameState.adjust_karma_attacked_good()
	var foe: Dictionary = _city_map.take_person_at_index(idx)
	if foe.is_empty():
		return Locale.t("cmd_nothing_to_attack")
	if _map != null and _map.has_method("refresh"):
		_map.refresh()
	await _begin_combat(foe, true)
	return ""


func _begin_combat(
	foe: Dictionary,
	initiated_by_party: bool,
	force_map = null,
	foes_first: bool = false
) -> void:
	## Open the .CON battlefield. Optional force_map (camp ambush uses CAMP.CON).
	## foes_first: xu4 camp ambush — placeCreatures then finishTurn (creatures act).
	if _combat_active or foe.is_empty():
		return
	## Never open the arena on a wiped party (pirate broadsides / death cutscene).
	if _party_wiped_or_dying():
		return
	_reset_hold_state()
	_clear_pending_dir()
	_stop_ship_cruise()
	_combat_foe_dmg.clear()
	if _world_creatures != null:
		_world_creatures.clear_hp_bars()
	_combat_foe = foe.duplicate(true)
	var foe_tid := int(foe.get("tile", 0))
	var foe_pos := Vector2i(int(foe.get("x", _tile_pos.x)), int(foe.get("y", _tile_pos.y)))
	var town_encounter: bool = (
		bool(foe.get("city_person", false))
		or (_is_in_city() and _city_map != null and _city_map.loaded)
	)
	var cmap = force_map
	if cmap == null:
		var ground_tid := 4
		var foe_ground := 4
		if town_encounter and _city_map != null and _city_map.loaded:
			ground_tid = int(_city_map.effective_tile_at(_tile_pos.x, _tile_pos.y))
			foe_ground = int(_city_map.effective_tile_at(foe_pos.x, foe_pos.y))
		elif _world != null and _world.loaded:
			ground_tid = int(_world.tile_at(_tile_pos.x, _tile_pos.y))
			foe_ground = int(_world.tile_at(foe_pos.x, foe_pos.y))
		cmap = _CombatMaps.load_for_encounter(
			ground_tid,
			foe_tid,
			_transport == Transport.SHIP,
			_TileRules.is_water(foe_ground)
		)
	if cmap == null:
		## Put the foe back if the arena failed to load.
		if bool(foe.get("city_person", false)) and _city_map != null:
			_city_map.restore_person(foe)
			if _map != null and _map.has_method("refresh"):
				_map.refresh()
		elif _world_creatures != null and not foes_first:
			_world_creatures.creatures.append(foe)
			_sync_creatures_to_map()
		_push_message(Locale.t("cmd_nothing_to_attack"), false)
		return
	## Lock input; open side panels first when they were closed, then swap the map.
	_combat_active = true
	_combat_resolving = true
	_combat_victory_aftermath = false
	## Camp ambush: no sleep→wake rolls until the first creature phase ends.
	## Normal engage: party may need the 1/8 roll before any creature acts.
	_combat_allow_sleep_wake = not foes_first
	await _open_sides_for_combat()
	## Place living party on .CON player_start slots.
	var party_units: Array = []
	for i in GameState.party_size():
		var mid := GameState.party_member_at(i)
		if mid < 0 or GameState.is_class_dead(mid):
			continue
		var start: Vector2i = (
			cmap.player_start[i] if i < cmap.player_start.size()
			else Vector2i(5, 5)
		)
		party_units.append({
			"x": start.x,
			"y": start.y,
			"klass": mid,
			"party_slot": i,
		})
	## xu4 fillCreatureTable — town size for city; standard groups in wilderness.
	var table: Array[int] = _CombatEncounter.fill_creature_table(
		foe_tid, GameState.party_size(), town_encounter
	)
	var foe_units: Array = _CombatEncounter.place_foes_from_table(
		table, cmap.creature_start
	)
	if foe_units.is_empty():
		## Safety: at least the engaged creature.
		var foe_start: Vector2i = (
			cmap.creature_start[0] if cmap.creature_start.size() > 0
			else Vector2i(5, 2)
		)
		var vitals: Dictionary = _CombatEncounter.initial_hp_for(foe_tid)
		foe_units.append({
			"x": foe_start.x,
			"y": foe_start.y,
			"tile": foe_tid,
			"hp": int(vitals["hp"]),
			"max_hp": int(vitals["max_hp"]),
			"slot": 0,
			"priority": 0,
		})
	if _map != null:
		_map.enter_combat(cmap, party_units, foe_units)
		## First living party member has the turn (xu4 beginCombat focus).
		_map.set_combat_focus(0 if not party_units.is_empty() else -1)
	## Camp ambush already printed "Ambushed!" — skip "Attacked by…".
	if not initiated_by_party and not foes_first:
		var nm := _WorldCreaturesScript.display_name(foe_tid)
		_push_message(Locale.t("cmd_attacked_by", [nm]), false)
	_push_message(Locale.t("cmd_combat"), false)
	_refresh_party()
	_refresh_foe_roster()
	_sync_combat_focus_roster()
	_stamp_command_time()
	if foes_first:
		## xu4 CampController comment: creatures go first.
		## (Strict: full foe phase before any sleep wake rolls.)
		await _combat_run_foe_phase()
		if not _combat_active or _map == null or not _map.is_in_combat():
			_combat_resolving = false
			return
		if _map.is_combat_won():
			await _begin_combat_victory_aftermath()
			_combat_resolving = false
			return
		if _map.is_combat_lost():
			await _end_combat_lost()
			return
		_map.set_combat_focus(0)
		if not await _combat_skip_to_able_focus():
			_combat_resolving = false
			return
	_combat_resolving = false


func _end_combat_stub() -> void:
	## Temporary leave — restores explore UI; full victory/flee later.
	## xu4 CombatController::endCombat — world creature is always removed
	## (win, flee/loss, or party wipe); never put back on the map.
	if not _combat_active:
		return
	if _combat_victory_aftermath:
		## After Victory!, cascade everyone off then return to field.
		await _combat_victory_esc_exit_all()
		return
	_combat_clear_aim_state()
	_combat_resolving = true
	_combat_victory_aftermath = false
	if _map != null:
		_map.exit_combat()
	_combat_foe = {}
	if _foe_roster:
		_foe_roster.clear()
	if _roster:
		_roster.clear_order_selection()
	_sync_creatures_to_map()
	_refresh_locate_hud()
	_push_message(Locale.t("cmd_combat_stub_leave"), false)
	await _restore_sides_after_combat()
	_combat_active = false
	_combat_resolving = false
	_stamp_command_time()


func _combat_clear_aim_state() -> void:
	## End of combat — wipe aim UI and sticky targets.
	_combat_aiming = false
	_combat_aim_weapon = 0
	_combat_aim_pos = Vector2i.ZERO
	_combat_aim_from = Vector2i.ZERO
	_combat_last_aim_foe.clear()
	_combat_foe_dmg.clear()
	if _map:
		_map.clear_combat_aim_cursor()
	_sync_combat_aim_foe_roster()


func _begin_combat_victory_aftermath() -> void:
	## Enemies wiped — show Victory! + karma/loot once, stay on the .CON map.
	## Leave later via ESC (party_slot order) or walking everyone off the edge.
	if not _combat_active or _combat_victory_aftermath:
		return
	_combat_clear_aim_state()
	_clear_pending_dir()
	## Always free combat input after Victory (even if a turn-gap coroutine still runs).
	_combat_victory_aftermath = true
	_combat_resolving = false
	_combat_aiming = false
	## xu4 CampController::endCombat — wake sleepers after the fight.
	GameState.wake_party()
	var engaged_tid := int(_combat_foe.get("tile", 0))
	var foe_pos := Vector2i(
		int(_combat_foe.get("x", _tile_pos.x)),
		int(_combat_foe.get("y", _tile_pos.y))
	)
	var foe_facing := int(_combat_foe.get("facing", 0))
	## Loot / karma at the Victory! moment (not when stepping off the arena).
	_push_message(Locale.t("cmd_victory"), false)
	if _WorldCreaturesScript.is_pirate_ship(engaged_tid):
		_place_captured_pirate_ship(foe_pos, foe_facing)
	if _WorldCreaturesScript.is_evil(engaged_tid):
		GameState.adjust_karma_killed_evil()
	## World foe already taken off the map at combat start — keep it gone.
	if _foe_roster:
		_foe_roster.clear()
	if _roster:
		_roster.clear_order_selection()
	if _map != null:
		_map.clear_combat_foe_focus()
		if _map.combat_party_count() > 0:
			_map.set_combat_focus(0)
	_refresh_party()
	_refresh_foe_roster()
	_sync_combat_focus_roster()
	_layout_prompt_row()
	_stamp_command_time()
	## Already empty (edge case) — leave immediately.
	if _map == null or _map.combat_party_count() <= 0:
		await _finish_combat_victory_exit()


func _finish_combat_victory_exit() -> void:
	## Return to the field after Victory! aftermath — no further karma.
	if not _combat_active:
		return
	_combat_clear_aim_state()
	_combat_resolving = true
	_combat_victory_aftermath = false
	if _map != null:
		_map.exit_combat()
	_combat_foe = {}
	if _foe_roster:
		_foe_roster.clear()
	if _roster:
		_roster.clear_order_selection()
	_sync_creatures_to_map()
	_refresh_locate_hud()
	_refresh_party()
	await _restore_sides_after_combat()
	_combat_active = false
	_combat_resolving = false
	_stamp_command_time()


func _combat_victory_esc_exit_all() -> void:
	## ESC after Victory!: peel party_slot 0…7 with a short gap, then field map.
	if not _combat_active or not _combat_victory_aftermath or _map == null:
		return
	if _combat_resolving:
		return
	_combat_resolving = true
	## Only for Esc bulk exit — walking off the edge stays quiet.
	_push_message(Locale.t("cmd_escape"), false)
	while _map != null and _map.combat_party_count() > 0:
		var best_i := -1
		var best_slot := 999
		for i in _map.combat_party_count():
			var u: Dictionary = _map.get_combat_party_unit(i)
			var slot := int(u.get("party_slot", 99))
			if slot < best_slot:
				best_slot = slot
				best_i = i
		if best_i < 0:
			break
		_map.remove_combat_party_at(best_i)
		_refresh_party()
		_sync_combat_focus_roster()
		if _map.combat_party_count() <= 0:
			break
		await get_tree().create_timer(COMBAT_VICTORY_EXIT_GAP).timeout
		if not _combat_active or not _combat_victory_aftermath or _map == null:
			_combat_resolving = false
			return
	await _finish_combat_victory_exit()


func _place_captured_pirate_ship(pos: Vector2i, facing: int) -> void:
	## xu4 CombatController::awardLoot — pirate ship becomes a boardable frigate.
	if _map == null or _is_in_city():
		return
	## Pirate / ship frames share WNES order (0=W … 3=S).
	var ship_tid := MapView.TILE_SHIP_W + clampi(facing, 0, 3)
	_map.add_overlay(pos, ship_tid)
	_store_ship_hull_at(pos, GameState.SHIP_HULL_MAX)


func _handle_combat_input(event: InputEvent) -> bool:
	## Combat: move / Pass / Attack + xu4 letter commands; banned → "Not here!".
	## Esc leaves (stub) or cancels aim. No idle auto-pass.
	if not event.is_pressed() or event.is_echo():
		return false
	if not (event is InputEventKey):
		return false
	var k := event as InputEventKey
	## After Victory!: free roam / Open / Get / ESC leave — never swallow on resolving.
	if _combat_victory_aftermath:
		return _handle_combat_victory_input(k)
	## Swallow other keys while foe turns / gaps / strike FX play out.
	if _combat_resolving and not _combat_aiming:
		return true
	if _combat_aiming:
		return _handle_combat_aim_input(k)
	if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
		_end_combat_stub()
		return true
	if _combat_resolving:
		return true
	## Sleeping / dead focus — auto-pass (wake checked when focus lands).
	var focus_klass := _map.get_combat_focus_klass() if _map != null else -1
	if focus_klass >= 0 and GameState.is_member_disabled(focus_klass):
		_combat_finish_member_turn()
		return true
	if k.keycode == KEY_SPACE or k.physical_keycode == KEY_SPACE:
		_push_message(Locale.t("cmd_pass"), false)
		_combat_finish_member_turn()
		return true
	var dir := _combat_dir_from_key(k)
	if dir != Vector2i.ZERO:
		_combat_try_move(dir)
		return true
	var cmd := U4Commands.from_event(k)
	if cmd == U4Commands.Id.NONE:
		return false
	if cmd == U4Commands.Id.PASS:
		_push_message(Locale.t("cmd_pass"), false)
		_combat_finish_member_turn()
		return true
	if not U4Commands.allowed_in_combat(cmd):
		## xu4: Not here! still ends the member's turn.
		_push_message(Locale.t("cmd_not_here"), false)
		_combat_finish_member_turn()
		return true
	_handle_combat_command(cmd)
	return true


func _handle_combat_victory_input(k: InputEventKey) -> bool:
	## Free movement, Open/Get/Cast, ESC cascade exit — no turn clock.
	_combat_resolving = false
	if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
		_combat_victory_esc_exit_all()
		return true
	var dir := _combat_dir_from_key(k)
	if dir != Vector2i.ZERO:
		_combat_try_move(dir)
		return true
	var cmd := U4Commands.from_event(k)
	var lang := GameState.lang_short()
	match cmd:
		U4Commands.Id.OPEN, U4Commands.Id.GET_CHEST:
			## Loot chests left on the arena (no turn cost after Victory!).
			_pending_cmd = cmd
			_pending_cmd_name = U4Commands.label(cmd, lang)
			_layout_prompt_row()
		U4Commands.Id.ZTATS:
			_do_ztats()
		U4Commands.Id.CAST:
			## Cast UI not ported yet — same stub as explore/combat turn.
			_push_message(Locale.t("cmd_stub", [
				U4Commands.letter_for(cmd),
				U4Commands.label(cmd, lang),
			]), false)
		U4Commands.Id.READY:
			_do_ready()
		U4Commands.Id.USE:
			_do_use()
		_:
			pass ## ignore other letters (no Not here! spam)
	return true


func _handle_combat_pending_dir(k: InputEventKey) -> bool:
	## Open / Get Dir? while combat is active (no _process move).
	## Esc / Space / Enter cancel without spending the member turn.
	if _pending_cmd == U4Commands.Id.NONE:
		return false
	if (
		k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE
		or _is_dir_cancel_key(k)
	):
		_clear_pending_dir()
		_push_message(Locale.t("cmd_cancelled"), false)
		_layout_prompt_row()
		return true
	var dir := _combat_dir_from_key(k)
	if dir == Vector2i.ZERO:
		## Any non-dir → "What?" and abort Dir? (no turn until a real action).
		_clear_pending_dir()
		_push_message(Locale.t("cmd_what"), false)
		_layout_prompt_row()
		return true
	_finish_directed_command(dir)
	return true


func _handle_combat_command(cmd: int) -> void:
	## Letter commands allowed in combat (after Not-here filter).
	var lang := GameState.lang_short()
	var name := U4Commands.label(cmd, lang)
	var letter := U4Commands.letter_for(cmd)
	match cmd:
		U4Commands.Id.ATTACK:
			_combat_begin_aim()
		U4Commands.Id.OPEN, U4Commands.Id.GET_CHEST:
			## Dir? prompts (Open is remake-allowed; Get matches classic).
			_pending_cmd = cmd
			_pending_cmd_name = name
			_layout_prompt_row()
		U4Commands.Id.READY:
			_do_ready()
		U4Commands.Id.ZTATS:
			_do_ztats()
		U4Commands.Id.CAST:
			## Cast not fully ported yet — consume the turn like a valid command start.
			_push_message(Locale.t("cmd_stub", [letter, name]), false)
			_combat_finish_member_turn()
		U4Commands.Id.USE:
			_do_use()
		U4Commands.Id.VOLUME:
			## xu4 V toggles music; no turn cost.
			_push_message(Locale.t("cmd_stub", [letter, name]), false)
		_:
			_push_message(Locale.t("cmd_not_here"), false)
			_combat_finish_member_turn()


func _is_key(k: InputEventKey, code: int) -> bool:
	return k.keycode == code or k.physical_keycode == code


func _handle_combat_aim_input(k: InputEventKey) -> bool:
	if _is_key(k, KEY_ESCAPE):
		_combat_cancel_aim()
		return true
	if _is_key(k, KEY_A) or _is_key(k, KEY_ENTER) or _is_key(k, KEY_KP_ENTER):
		_combat_confirm_aim()
		return true
	var dir := _combat_dir_from_key(k)
	if dir == Vector2i.ZERO:
		return true ## swallow other keys while aiming
	_combat_move_aim(dir)
	return true


func _combat_begin_aim() -> void:
	if _map == null or not _map.is_in_combat() or _combat_resolving:
		return
	var from := _map.get_combat_focus_pos()
	if from.x < 0:
		return
	var klass := _map.get_combat_focus_klass()
	var party_slot := _map.get_combat_focus_party_slot()
	var wid := GameState.weapon_of_class(klass)
	_combat_aiming = true
	_combat_aim_from = from
	_combat_aim_weapon = wid
	## Sticky last target: same foe while alive and still in this weapon's range.
	_combat_aim_pos = _combat_sticky_aim_pos(from, wid, party_slot)
	var pname := GameState.party_member_display_name(party_slot) if party_slot >= 0 else ""
	if pname.is_empty():
		pname = U4Commands.label(U4Commands.Id.ATTACK, GameState.lang_short())
	_push_message(
		Locale.t("cmd_attack_with", [pname, Locale.weapon_name(wid)]),
		false
	)
	if _map:
		_map.set_combat_aim_cursor(_combat_aim_pos)
	_sync_combat_aim_foe_roster()
	_layout_prompt_row()


func _combat_sticky_aim_pos(from: Vector2i, wid: int, party_slot: int) -> Vector2i:
	## Resume last attacked foe, else attacker tile. Clears sticky if dead / OOR.
	if party_slot < 0 or _map == null:
		return from
	if not _combat_last_aim_foe.has(party_slot):
		return from
	var foe_slot := int(_combat_last_aim_foe[party_slot])
	var foe_i := _map.combat_foe_index_by_slot(foe_slot)
	if foe_i < 0:
		_combat_last_aim_foe.erase(party_slot)
		return from
	var foe := _map.get_combat_foe_at(foe_i)
	var pos := Vector2i(int(foe.get("x", from.x)), int(foe.get("y", from.y)))
	if _map == null or not _map.combat_can_strike(wid, from, pos):
		_combat_last_aim_foe.erase(party_slot)
		return from
	return pos


func _combat_remember_aim_target(_klass: int, foe_i: int) -> void:
	## Sticky aim follows the creatureTable slot of the foe just struck at.
	if _map == null or foe_i < 0:
		return
	var party_slot := _map.get_combat_focus_party_slot()
	if party_slot < 0:
		return
	var foe := _map.get_combat_foe_at(foe_i)
	var foe_slot := int(foe.get("slot", -1))
	if foe_slot < 0:
		return
	_combat_last_aim_foe[party_slot] = foe_slot


func _combat_clear_sticky_aim() -> void:
	## Clear this member's sticky aim (intentional empty-tile attack).
	if _map == null:
		return
	var party_slot := _map.get_combat_focus_party_slot()
	if party_slot < 0:
		return
	_combat_last_aim_foe.erase(party_slot)


func _combat_forget_aim_foe_index(foe_i: int) -> void:
	## Drop sticky aims pointing at a slain foe (all party members).
	if _map == null or foe_i < 0:
		return
	var foe := _map.get_combat_foe_at(foe_i)
	var foe_slot := int(foe.get("slot", -1))
	if foe_slot < 0:
		return
	var drop: Array = []
	for k in _combat_last_aim_foe.keys():
		if int(_combat_last_aim_foe[k]) == foe_slot:
			drop.append(k)
	for k in drop:
		_combat_last_aim_foe.erase(k)


func _combat_cancel_aim() -> void:
	## Esc cancels aim UI only — keeps sticky target from a prior attack.
	## Never-attacked members have no sticky entry, so nothing is retained.
	_combat_aiming = false
	_combat_aim_weapon = 0
	if _map:
		_map.clear_combat_aim_cursor()
	_sync_combat_aim_foe_roster()
	_push_message(Locale.t("cmd_cancelled"), false)
	_layout_prompt_row()


func _combat_move_aim(dir: Vector2i) -> void:
	if _map == null or not _combat_aiming:
		return
	var next := _combat_aim_pos + dir
	if next.x < 0 or next.y < 0 or next.x >= _CombatMapData.WIDTH or next.y >= _CombatMapData.HEIGHT:
		return
	if not WeaponIcons.aim_cursor_allows(_combat_aim_weapon, _combat_aim_from, next):
		return
	_combat_aim_pos = next
	_map.set_combat_aim_cursor(_combat_aim_pos)
	_sync_combat_aim_foe_roster()


func _combat_confirm_aim() -> void:
	## Strike the aimed tile, then end the member's turn (xu4 attack already spent).
	## Self-tile confirm: reject and keep aiming.
	if not _combat_aiming or _map == null:
		return
	var target := _combat_aim_pos
	var from := _combat_aim_from
	if target == from:
		_push_message(Locale.t("cmd_cannot_attack"), false)
		_layout_prompt_row()
		return
	var wid := _combat_aim_weapon
	var klass := _map.get_combat_focus_klass()
	_combat_aiming = false
	if _map:
		_map.clear_combat_aim_cursor()
	_sync_combat_aim_foe_roster()
	_layout_prompt_row()
	_combat_resolve_attack(klass, wid, from, target)


func _combat_resolve_attack(klass: int, wid: int, from: Vector2i, target: Vector2i) -> void:
	_combat_resolving = true
	_stamp_command_time()
	## xu4 path distance: each 8-way step counts as 1 (Chebyshev, not aim_distance).
	var steps := WeaponIcons.chebyshev(from, target)
	var valid_cell := _map.combat_can_strike(wid, from, target)
	## Self tile: unstrikeable. Allies and foes are valid targets.
	## Intermediate walls stop the missile — no hit past the obstacle (except Halberd).
	var aim_foe_i := -1
	var aim_ally_i := -1
	if valid_cell:
		aim_foe_i = _map.combat_foe_index_at(target)
		if aim_foe_i < 0:
			aim_ally_i = _map.combat_party_index_at(target)
	## Projectiles for non-melee strikes beyond adjacent 8-way, or absolute-range weapons.
	## Returning weapons (magic axe) always show a throw even at range 1.
	var use_proj := (
		not WeaponIcons.is_melee(wid)
		and from != target
		and (
			WeaponIcons.is_absolute_range(wid)
			or steps > 1
			or WeaponIcons.returns_to_thrower(wid)
		)
	)
	if use_proj and not _map.combat_shot_reaches(from, target, wid):
		## Wall/mast in the way — fly until the obstacle, no unit damage beyond.
		aim_foe_i = -1
		aim_ally_i = -1
	var found_foe := aim_foe_i >= 0
	var found_ally := aim_ally_i >= 0
	var found_target := found_foe or found_ally
	if found_foe:
		_combat_remember_aim_target(klass, aim_foe_i)
	elif not found_ally and target != from:
		## Aimed empty space (not scatter, not self) — drop sticky.
		_combat_clear_sticky_aim()

	if use_proj:
		await _combat_resolve_ranged_attack(klass, wid, from, target, aim_foe_i, aim_ally_i)
	else:
		await _combat_resolve_melee_attack(klass, target, aim_foe_i, aim_ally_i, found_target)

	## xu4: lose when used (oil). Dagger loseWhenRanged: adjacent 8-way hit keeps;
	## thrown (steps > 1) or no target → consume.
	var spent := WeaponIcons.loses_when_used(wid) or (
		WeaponIcons.loses_when_ranged(wid) and (not found_target or steps > 1)
	)
	if spent and klass >= 0:
		var kept := GameState.lose_ready_weapon(klass)
		_refresh_party()
		if not kept:
			_push_message(Locale.t("cmd_last_one"), false)

	## xu4 leaveTile (flaming oil → fire_field on walkable impact cell).
	if WeaponIcons.leaves_field(wid) and _map != null:
		var leave_at := target
		if use_proj:
			leave_at = _map.combat_projectile_end(from, target, wid)
		_map.combat_leave_field(leave_at, MapView.TILE_FIELD_FIRE)

	if not _combat_active or _map == null or not _map.is_in_combat():
		_combat_resolving = false
		return
	if _map.is_combat_won():
		await _begin_combat_victory_aftermath()
		_combat_resolving = false
		return
	## Finish turn without the usual entry guard (we already set resolving).
	await get_tree().create_timer(COMBAT_TURN_GAP).timeout
	if not _combat_active or _map == null or not _map.is_in_combat():
		_combat_resolving = false
		return
	if _map.is_combat_lost():
		await _end_combat_lost()
		return
	var still_party := _map.advance_combat_focus()
	if still_party:
		_sync_combat_focus_roster()
		_refresh_party()
		_combat_resolving = false
		return
	await _combat_run_foe_phase()
	if not _combat_active or _map == null or not _map.is_in_combat():
		_combat_resolving = false
		return
	if _map.is_combat_lost():
		await _end_combat_lost()
		return
	if _map.is_combat_won():
		await _begin_combat_victory_aftermath()
		_combat_resolving = false
		return
	_map.set_combat_focus(0)
	_refresh_foe_roster()
	_sync_combat_focus_roster()
	_refresh_party()
	_combat_resolving = false


func _combat_resolve_melee_attack(
	klass: int,
	target: Vector2i,
	foe_i: int,
	ally_i: int,
	found_target: bool
) -> void:
	if not found_target:
		_push_message(Locale.t("cmd_missed"), false)
		return
	if foe_i >= 0:
		if not GameState.party_attack_hits(klass):
			_push_message(Locale.t("cmd_missed"), false)
			return
		await _combat_apply_foe_hit(klass, foe_i, target)
		return
	## Friendly fire — vs party armor defense.
	var ally := _map.get_combat_party_unit(ally_i)
	var def_klass := int(ally.get("klass", -1))
	var defense := GameState.party_member_defense(def_klass)
	if not GameState.party_attack_hits_defense(klass, defense):
		_push_message(Locale.t("cmd_missed"), false)
		return
	await _combat_apply_ally_hit(klass, ally_i, target)


func _combat_resolve_ranged_attack(
	klass: int,
	wid: int,
	from: Vector2i,
	target: Vector2i,
	aim_foe_i: int,
	aim_ally_i: int
) -> void:
	## xu4 hit roll first. On miss: projectile still flies; no miss-flash VFX.
	## Returning weapons (magic axe): fly out → hit VFX/damage → fly home.
	const SCATTER_HIT_CHANCE := 0.5
	if aim_foe_i < 0 and aim_ally_i < 0:
		await _map.await_combat_projectile(from, target, wid)
		_push_message(Locale.t("cmd_missed"), false)
		await _map.await_combat_projectile_return()
		return

	var hits := false
	if aim_foe_i >= 0:
		hits = GameState.party_attack_hits(klass)
	else:
		var ally0 := _map.get_combat_party_unit(aim_ally_i)
		var def0 := int(ally0.get("klass", -1))
		hits = GameState.party_attack_hits_defense(klass, GameState.party_member_defense(def0))

	if hits:
		await _map.await_combat_projectile(from, target, wid)
		if aim_foe_i >= 0:
			await _combat_apply_foe_hit(klass, aim_foe_i, target)
		else:
			await _combat_apply_ally_hit(klass, aim_ally_i, target)
		await _map.await_combat_projectile_return()
		return

	var scatter_miss := randf() < GameState.miss_scatter_chance(klass)
	if scatter_miss:
		## Never scatter onto the shooter (common when foe is adjacent).
		var scatter := _combat_pick_scatter_tile(target, from)
		if scatter.x < 0:
			scatter = target
		await _map.await_combat_projectile(from, scatter, wid)
		var scatter_foe := _map.combat_foe_index_at(scatter)
		var scatter_ally := _map.combat_party_index_at(scatter) if scatter_foe < 0 else -1
		## Defensive: ignore self even if somehow selected.
		if scatter_ally >= 0:
			var ally_u := _map.get_combat_party_unit(scatter_ally)
			if int(ally_u.get("klass", -1)) == klass or scatter == from:
				scatter_ally = -1
		if scatter_foe >= 0 or scatter_ally >= 0:
			if randf() < SCATTER_HIT_CHANCE:
				if scatter_foe >= 0:
					await _combat_apply_foe_hit(klass, scatter_foe, scatter)
					_combat_remember_aim_target(klass, scatter_foe)
				else:
					await _combat_apply_ally_hit(klass, scatter_ally, scatter)
			else:
				_push_message(Locale.t("cmd_missed"), false)
		else:
			_push_message(Locale.t("cmd_missed"), false)
		await _map.await_combat_projectile_return()
		return

	## 명중 미스 — shot reaches the tile; text only (no miss flash).
	await _map.await_combat_projectile(from, target, wid)
	_push_message(Locale.t("cmd_missed"), false)
	await _map.await_combat_projectile_return()


func _combat_pick_scatter_tile(center: Vector2i, exclude: Vector2i = Vector2i(-999, -999)) -> Vector2i:
	## One of the 8 neighbors (in-bounds), never `exclude` (usually the shooter).
	var opts: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var p := Vector2i(center.x + dx, center.y + dy)
			if p.x < 0 or p.y < 0 or p.x >= _CombatMapData.WIDTH or p.y >= _CombatMapData.HEIGHT:
				continue
			if p == exclude:
				continue
			opts.append(p)
	if opts.is_empty():
		return Vector2i(-1, -1)
	return opts[randi() % opts.size()]


func _combat_record_foe_damage(foe_i: int, klass: int, dealt: int) -> void:
	## Accumulate applied HP damage per party class for XP assist shares.
	if foe_i < 0 or klass < 0 or dealt <= 0:
		return
	var by: Dictionary = _combat_foe_dmg.get(foe_i, {})
	by[klass] = int(by.get(klass, 0)) + dealt
	_combat_foe_dmg[foe_i] = by


func _combat_apply_foe_hit(klass: int, foe_i: int, at: Vector2i) -> void:
	if _map == null or foe_i < 0:
		return
	var dmg := GameState.party_attack_damage(klass)
	var result := _map.damage_combat_foe(foe_i, dmg)
	var killed := bool(result.get("killed", false))
	var foe_tile := int(result.get("tile", 0))
	var xp := int(result.get("xp", 0))
	var dealt := int(result.get("dealt", 0))
	_combat_record_foe_damage(foe_i, klass, dealt)
	await _map.await_flash_combat_tile(at, MapView.TILE_HIT_FLASH, COMBAT_HIT_FLASH_SEC)
	if killed:
		var nm := _WorldCreaturesScript.display_name(foe_tile)
		_push_message(Locale.t("cmd_killed", [nm]), false)
		if xp > 0:
			var contrib: Dictionary = _combat_foe_dmg.get(foe_i, {})
			GameState.award_combat_kill_xp(klass, contrib, xp)
		_combat_foe_dmg.erase(foe_i)
		_combat_forget_aim_foe_index(foe_i)
	_refresh_foe_roster()


func _combat_apply_ally_hit(attacker_klass: int, ally_i: int, at: Vector2i) -> void:
	## Friendly fire — damage a party member on the arena.
	if _map == null or ally_i < 0:
		return
	var ally := _map.get_combat_party_unit(ally_i)
	var def_klass := int(ally.get("klass", -1))
	if def_klass < 0:
		return
	var dmg := GameState.party_attack_damage(attacker_klass)
	GameState.apply_member_damage(def_klass, dmg)
	await _map.await_flash_combat_tile(at, MapView.TILE_HIT_FLASH, COMBAT_HIT_FLASH_SEC)
	if GameState.status_of_class(def_klass) == PartyRoster.Status.DEAD:
		var slot := int(ally.get("party_slot", -1))
		var nm := GameState.party_member_display_name(slot) if slot >= 0 else Virtues.class_name_of(
			def_klass, GameState.lang_short()
		)
		_push_message(Locale.t("cmd_killed", [nm]), false)
		_map.remove_combat_party_at(ally_i)
	_refresh_party()
	_sync_combat_focus_roster()


func _combat_dir_from_key(k: InputEventKey) -> Vector2i:
	## Orthogonal only (xu4 combat arrows). Aim mode also uses these for U5 cursor.
	var code := k.keycode
	var phys := k.physical_keycode
	if code == KEY_UP or phys == KEY_UP:
		return Vector2i(0, -1)
	if code == KEY_DOWN or phys == KEY_DOWN:
		return Vector2i(0, 1)
	if code == KEY_LEFT or phys == KEY_LEFT:
		return Vector2i(-1, 0)
	if code == KEY_RIGHT or phys == KEY_RIGHT:
		return Vector2i(1, 0)
	return Vector2i.ZERO


func _combat_try_move(dir: Vector2i) -> void:
	if _map == null or not _map.is_in_combat():
		return
	if _combat_resolving and not _combat_victory_aftermath:
		return
	if _combat_victory_aftermath:
		## Keep a valid focus for free roam after party members leave.
		if _map.get_combat_focus() < 0 or _map.get_combat_focus() >= _map.combat_party_count():
			if _map.combat_party_count() > 0:
				_map.set_combat_focus(0)
			else:
				_finish_combat_victory_exit()
				return
	var result := _map.try_move_combat_focus(dir)
	var after_flee := false
	match result:
		MapView.COMBAT_MOVE_OK:
			_push_message(_direction_label(dir, true), false)
		MapView.COMBAT_MOVE_SLOWED:
			_push_message(Locale.t("cmd_slow_progress"), false)
		MapView.COMBAT_MOVE_FLED:
			## xu4: direction message + SOUND_FLEE; unit already off the arena.
			_push_message(_direction_label(dir, true), false)
			## No healthy-flee karma after Victory! (already awarded on announce).
			if not _combat_victory_aftermath:
				_combat_apply_healthy_fled_karma(_map.get_combat_last_fled())
			after_flee = true
		_:
			_push_message(Locale.t("cmd_blocked"), false)
	if _combat_victory_aftermath:
		## Free roam after Victory! — no turn clock; leave when empty.
		if after_flee and (_map == null or _map.combat_party_count() <= 0):
			_finish_combat_victory_exit()
		elif after_flee:
			_map.refocus_after_flee()
			_sync_combat_focus_roster()
			_refresh_party()
		return
	## xu4: move (incl. blocked/slowed/flee) ends the active member's turn.
	_combat_finish_member_turn(after_flee)


func _combat_apply_healthy_fled_karma(fled: Dictionary) -> void:
	## xu4 movePartyMember — full-HP flee from evil → KA_HEALTHY_FLED_EVIL.
	if fled.is_empty():
		return
	var engaged_tid := int(_combat_foe.get("tile", 0))
	if not _WorldCreaturesScript.is_evil(engaged_tid):
		return
	var klass := int(fled.get("klass", -1))
	if klass < 0:
		return
	if GameState.hp_of_class(klass) != GameState.max_hp_of_class(klass):
		return
	GameState.adjust_karma_healthy_fled_evil()


func _combat_finish_member_turn(after_flee: bool = false) -> void:
	## xu4 finishTurn — pace, next party member; after last, foes act one-by-one.
	## Fleeing the last member → isLost → endCombat (Battle is lost + karma).
	## Sleeping/dead members auto-skip with no player wait (xu4 do-while).
	if _map == null or not _map.is_in_combat() or _combat_resolving:
		return
	## Victory aftermath never runs the foe phase or defeat path.
	if _combat_victory_aftermath:
		if after_flee and _map.combat_party_count() <= 0:
			_finish_combat_victory_exit()
		return
	_combat_resolving = true
	_stamp_command_time()
	## Delay only after a real (able) action or flee — not for sleeper auto-pass.
	var focus_klass := _map.get_combat_focus_klass()
	var was_able := (
		focus_klass >= 0 and not GameState.is_member_disabled(focus_klass)
	)
	if was_able or after_flee:
		await get_tree().create_timer(COMBAT_TURN_GAP).timeout
	if not _combat_active or _map == null or not _map.is_in_combat():
		_combat_resolving = false
		return
	if _map.is_combat_won() and not _combat_victory_aftermath:
		await _begin_combat_victory_aftermath()
		_combat_resolving = false
		return
	if _map.is_combat_lost():
		await _end_combat_lost()
		return
	## Able unit / flee: move focus first. Sleeper auto-pass stays and rolls wake.
	if was_able or after_flee:
		var still_party := (
			_map.refocus_after_flee() if after_flee else _map.advance_combat_focus()
		)
		if not still_party:
			## Party round done — creatures (xu4 wrap → endTurn / aura / moveCreatures).
			GameState.pass_aura_turn()
			await get_tree().create_timer(0.05).timeout
			await _combat_run_foe_phase()
			if not _combat_active or _map == null or not _map.is_in_combat():
				_combat_resolving = false
				return
			if _map.is_combat_won():
				await _begin_combat_victory_aftermath()
				_combat_resolving = false
				return
			if _map.is_combat_lost():
				await _end_combat_lost()
				return
			_map.set_combat_focus(0)
	if not await _combat_skip_to_able_focus():
		_combat_resolving = false
		return
	_combat_resolving = false


func _combat_skip_to_able_focus() -> bool:
	## xu4 finishTurn skip loop: wake 1/8 on sleepers, instant-skip disabled;
	## when the whole party is asleep, run foe phase and retry until someone acts.
	## true = focus is ready for input; false = combat ended or no party left.
	if _map == null or not _map.is_in_combat():
		return false
	var guard := 128
	while guard > 0:
		guard -= 1
		if not _combat_active or _map == null or not _map.is_in_combat():
			return false
		if _map.is_combat_won() and not _combat_victory_aftermath:
			await _begin_combat_victory_aftermath()
			return false
		if _map.is_combat_lost():
			await _end_combat_lost()
			return false
		var klass := _map.get_combat_focus_klass()
		if klass < 0:
			return false
		if GameState.status_of_class(klass) == PartyRoster.Status.SLEEPING:
			## Camp ambush: block wake until the first foe phase has run.
			if (
				_combat_allow_sleep_wake
				and (randi() % 8) == 0
				and GameState.wake_member(klass)
			):
				_refresh_party()
				_map.refresh_combat_view()
		if not GameState.is_member_disabled(klass):
			_sync_combat_focus_roster()
			_refresh_party()
			_refresh_foe_roster()
			return true
		## Sleeping / dead — advance focus with no turn-gap delay.
		if not _map.advance_combat_focus():
			## Full pass of sleepers: xu4 ~50ms then creatures act.
			await get_tree().create_timer(0.05).timeout
			await _combat_run_foe_phase()
			if not _combat_active or _map == null or not _map.is_in_combat():
				return false
			if _map.is_combat_won():
				await _begin_combat_victory_aftermath()
				return false
			if _map.is_combat_lost():
				await _end_combat_lost()
				return false
			_map.set_combat_focus(0)
	return false


func _combat_run_foe_phase() -> void:
	## Each living foe: show focus → act (melee/ranged/flee/advance) → gap.
	if _map == null:
		return
	var indices: Array[int] = _map.living_combat_foe_indices()
	for i in indices:
		if not _combat_active or _map == null:
			return
		if await _combat_maybe_end_after_foes():
			return
		_map.set_combat_foe_focus(i)
		if _roster:
			_roster.clear_order_selection()
		await get_tree().create_timer(COMBAT_TURN_GAP * 0.55).timeout
		if not _combat_active or _map == null:
			return
		var plan: Dictionary = _map.act_combat_creature_at(i)
		await _combat_resolve_foe_act(plan)
		_refresh_foe_roster()
		_refresh_party()
		if not _combat_active or _map == null:
			return
		if await _combat_maybe_end_after_foes():
			return
		await get_tree().create_timer(COMBAT_TURN_GAP).timeout
	if _map != null:
		_map.clear_combat_foe_focus()
	## First (or any) creature pass done — sleepers may now roll 1/8 wake.
	_combat_allow_sleep_wake = true


func _combat_maybe_end_after_foes() -> bool:
	## True if win/loss was handled (caller should stop the foe loop).
	if _map == null:
		return true
	if GameState.is_party_dead() or _map.is_combat_lost():
		await _end_combat_lost()
		return true
	if _map.is_combat_won():
		await _begin_combat_victory_aftermath()
		## Parent turn coroutine may still have been "resolving" — force free input.
		_combat_resolving = false
		return true
	return false


func _combat_resolve_foe_act(plan: Dictionary) -> void:
	## Animate / apply results from MapView.act_combat_creature_at.
	if _map == null or plan.is_empty():
		return
	var action := str(plan.get("action", "none"))
	match action:
		"melee":
			await _combat_resolve_foe_melee(plan)
		"ranged":
			await _combat_resolve_foe_ranged(plan)
		"cast_sleep":
			await _combat_resolve_foe_cast_sleep()
		"fled":
			_combat_resolve_foe_fled(plan)
		_:
			pass


func _combat_resolve_foe_melee(plan: Dictionary) -> void:
	var party_i := int(plan.get("party_i", -1))
	var klass := int(plan.get("klass", -1))
	var at: Vector2i = plan.get("to", Vector2i.ZERO)
	var tid := int(plan.get("tile", 0))
	var base_hp := int(plan.get("base_hp", 64))
	if party_i < 0 or klass < 0:
		return
	## Re-resolve in case the unit fled/died earlier this phase.
	var unit := _map.get_combat_party_unit(party_i)
	if unit.is_empty():
		return
	klass = int(unit.get("klass", klass))
	at = Vector2i(int(unit.get("x", at.x)), int(unit.get("y", at.y)))
	var defense := GameState.party_member_defense(klass)
	var hits := _WorldCreaturesScript.creature_attack_hits(defense)
	if hits:
		var dmg := _WorldCreaturesScript.creature_attack_damage(base_hp)
		GameState.apply_member_damage(klass, dmg)
		await _map.await_flash_combat_tile(at, MapView.TILE_HIT_FLASH, COMBAT_HIT_FLASH_SEC)
		if _WorldCreaturesScript.steals_gold(tid) and (randi() % 4) == 0:
			GameState.adjust_gold(-(randi() % 0x3f))
		if _WorldCreaturesScript.steals_food(tid):
			GameState.adjust_food(-2500)
		if GameState.status_of_class(klass) == PartyRoster.Status.DEAD:
			var slot := int(unit.get("party_slot", -1))
			var nm := (
				GameState.party_member_display_name(slot)
				if slot >= 0
				else Virtues.class_name_of(klass, GameState.lang_short())
			)
			_push_message(Locale.t("cmd_killed", [nm]), false)
			_map.remove_combat_party_at(party_i)
	else:
		_push_message(Locale.t("cmd_missed"), false)
	_refresh_party()
	_sync_combat_focus_roster()


func _combat_resolve_foe_ranged(plan: Dictionary) -> void:
	## Free-aim shot; xu4 monsters never miss when the missile reaches the tile.
	## xu4 EFFECT_POISON / EFFECT_SLEEP: status only, no dealDamage (even if asleep).
	var from: Vector2i = plan.get("from", Vector2i.ZERO)
	var to: Vector2i = plan.get("to", Vector2i.ZERO)
	var party_i := int(plan.get("party_i", -1))
	var klass := int(plan.get("klass", -1))
	var base_hp := int(plan.get("base_hp", 64))
	var effect := str(plan.get("effect", "damage"))
	if party_i < 0 or klass < 0:
		return
	var unit := _map.get_combat_party_unit(party_i)
	if unit.is_empty():
		return
	klass = int(unit.get("klass", klass))
	to = Vector2i(int(unit.get("x", to.x)), int(unit.get("y", to.y)))
	await _map.await_combat_projectile(from, to)
	if not _map.combat_shot_reaches(from, to):
		## Stopped on an intermediate obstacle — no effect.
		return
	await _map.await_flash_combat_tile(to, MapView.TILE_HIT_FLASH, COMBAT_HIT_FLASH_SEC)
	match effect:
		"poison":
			## xu4: STAT_GOOD + 50% only; sleepers get neither damage nor poison.
			if GameState.try_poison_class(klass):
				_push_message(Locale.t("cmd_poisoned"), false)
		"sleep":
			## xu4: STAT_GOOD + 50%; already sleeping → no effect / no HP.
			if GameState.try_sleep_class(klass):
				_push_message(Locale.t("cmd_combat_sleep"), false)
		_:
			## damage / energy — always connect (xu4 rangedAttack).
			var dmg := _WorldCreaturesScript.creature_attack_damage(base_hp)
			GameState.apply_member_damage(klass, dmg)
			if GameState.status_of_class(klass) == PartyRoster.Status.DEAD:
				var slot := int(unit.get("party_slot", -1))
				var nm := (
					GameState.party_member_display_name(slot)
					if slot >= 0
					else Virtues.class_name_of(klass, GameState.lang_short())
				)
				_push_message(Locale.t("cmd_killed", [nm]), false)
				_map.remove_combat_party_at(party_i)
	_refresh_party()
	_sync_combat_focus_roster()


func _combat_resolve_foe_cast_sleep() -> void:
	## xu4 CA_CAST_SLEEP — 50% each living non-disabled member (poisoned immune).
	_push_message(Locale.t("cmd_combat_sleep"), false)
	if _map == null:
		return
	var n := _map.combat_party_count()
	for i in range(n - 1, -1, -1):
		var unit := _map.get_combat_party_unit(i)
		var klass := int(unit.get("klass", -1))
		if klass < 0:
			continue
		if GameState.is_member_disabled(klass):
			continue
		if GameState.status_of_class(klass) == PartyRoster.Status.POISONED:
			continue
		GameState.try_sleep_class(klass)
	_refresh_party()
	_sync_combat_focus_roster()
	await get_tree().create_timer(COMBAT_HIT_FLASH_SEC).timeout


func _combat_resolve_foe_fled(plan: Dictionary) -> void:
	var tid := int(plan.get("tile", 0))
	var nm := _WorldCreaturesScript.display_name(tid)
	_push_message(Locale.t("cmd_foe_flees", [nm]), false)
	if _WorldCreaturesScript.is_good(tid):
		GameState.adjust_karma_spared_good()
	_refresh_party()


func _end_combat_lost() -> void:
	## xu4 endCombat when !isWon.
	## • Party wiped → deathStart (stay on combat screen into cutscene).
	## • Else fled / empty arena with living members → Battle is lost + flee karma.
	if not _combat_active:
		return
	## Not a victory exit path.
	_combat_victory_aftermath = false
	_combat_clear_aim_state()
	_combat_resolving = true
	var engaged_tid := int(_combat_foe.get("tile", 0))
	var wiped := GameState.is_party_dead()
	_combat_foe = {}
	if _foe_roster:
		_foe_roster.clear()
	if _roster:
		_roster.clear_order_selection()
	if wiped:
		## xu4: isDead → deathStart(5); no "Battle is lost!" / flee karma.
		## Keep combat map underfoot until blackout/revive (messages on open sides).
		_combat_victory_aftermath = false
		_refresh_party()
		_combat_active = false
		_combat_resolving = false
		_stamp_command_time()
		_start_death_sequence(DEATH_PAUSE_SEC)
		return
	var evil := _WorldCreaturesScript.is_evil(engaged_tid)
	var good := _WorldCreaturesScript.is_good(engaged_tid)
	if _map != null:
		_map.exit_combat()
	## xu4 CampController::endCombat — wake sleepers after flee / loss.
	GameState.wake_party()
	_sync_creatures_to_map()
	_refresh_locate_hud()
	if evil:
		_push_message(Locale.t("cmd_battle_lost"), false)
		GameState.adjust_karma_fled_evil()
	elif good:
		GameState.adjust_karma_fled_good()
	_refresh_party()
	await _restore_sides_after_combat()
	_combat_active = false
	_combat_resolving = false
	_stamp_command_time()


func _is_in_combat() -> bool:
	return _combat_active or (_map != null and _map.is_in_combat())


func _do_open(dir: Vector2i) -> String:
	## xu4 opendoor / openAt — unlocked door → brick floor annotation, ttl 4.
	## Ultima4R: city chests ask Who opens? then trap; Get only loots.
	const TILE_BRICK_FLOOR := 62
	const DOOR_OPEN_TTL := 4
	## Combat map: door under the active member (adjacent tile).
	if _is_in_combat() and _map != null and _map.is_in_combat():
		var from := _map.get_combat_focus_pos()
		if from.x < 0:
			return Locale.t("cmd_nothing_to_open")
		var ctarget := from + dir
		if (
			ctarget.x < 0 or ctarget.y < 0
			or ctarget.x >= _CombatMapData.WIDTH
			or ctarget.y >= _CombatMapData.HEIGHT
		):
			return Locale.t("cmd_nothing_to_open")
		var ctid := _map.combat_tile_at(ctarget)
		if ctid < 0:
			return Locale.t("cmd_nothing_to_open")
		if _map.has_combat_chest_at(ctarget):
			if _map.combat_chest_is_empty(ctarget):
				return Locale.t("cmd_chest_empty")
			if _map.combat_chest_is_open(ctarget):
				return Locale.t("cmd_chest_already_open")
			if not _map.open_combat_chest_at(ctarget):
				return Locale.t("cmd_nothing_to_open")
			## Combat: active member opens (xu4 getChest(focus)); trap then Get for gold.
			var slot := _map.get_combat_focus_party_slot()
			var opener_klass := _map.get_combat_focus_klass()
			if slot < 0:
				slot = _first_living_party_slot()
			if opener_klass < 0:
				opener_klass = GameState.party_member_at(slot)
			_push_message(Locale.t("cmd_opened"), false)
			_resolve_chest_trap(slot, opener_klass)
			return ""
		if _TileRules.is_locked_door(ctid):
			return Locale.t("cmd_cant")
		if _TileRules.is_door(ctid):
			if _map.open_combat_door(ctarget):
				return Locale.t("cmd_opened")
			return Locale.t("cmd_nothing_to_open")
		return Locale.t("cmd_nothing_to_open")
	var target := Vector2i(_tile_pos.x + dir.x, _tile_pos.y + dir.y)
	if _is_in_city():
		if _city_map == null or not _city_map.loaded:
			return Locale.t("cmd_nothing_to_open")
		if (
			target.x < 0 or target.y < 0
			or target.x >= _CityMapData.WIDTH
			or target.y >= _CityMapData.HEIGHT
		):
			return Locale.t("cmd_nothing_to_open")
		var tid := int(_city_map.effective_tile_at(target.x, target.y))
		if _TileRules.is_chest(tid):
			## Still open this visit: no second trap. Empty → empty msg; else already open.
			if _city_map.is_chest_empty(target.x, target.y):
				return Locale.t("cmd_chest_empty")
			if _city_map.is_chest_open(target.x, target.y):
				return Locale.t("cmd_chest_already_open")
			## Closed lid (incl. remembered-empty after leave): Who opens? + trap again.
			if _living_party_slot_count() < 1:
				return Locale.t("cmd_cant")
			_begin_chest_open_who(target)
			return ""
		if _TileRules.is_locked_door(tid):
			return Locale.t("cmd_cant")
		if not _TileRules.is_door(tid):
			return Locale.t("cmd_nothing_to_open")
		_city_map.add_annotation(target.x, target.y, TILE_BRICK_FLOOR, DOOR_OPEN_TTL)
		if _map != null and _map.has_method("refresh"):
			_map.refresh()
		return Locale.t("cmd_opened")
	## World map: doors are rare; chests only open in cities.
	if _world == null or not _world.loaded:
		return Locale.t("cmd_nothing_to_open")
	var wtid := int(_world.tile_at(
		posmod(target.x, WorldMapData.WIDTH),
		posmod(target.y, WorldMapData.HEIGHT)
	))
	if _TileRules.is_locked_door(wtid):
		return Locale.t("cmd_cant")
	if _TileRules.is_door(wtid):
		## No world annotation system yet — treat as not here outdoors.
		return Locale.t("cmd_nothing_to_open")
	return Locale.t("cmd_nothing_to_open")


func _begin_chest_open_who(target: Vector2i) -> void:
	## Solo party: skip "Who opens?" and open immediately.
	_chest_open_target = target
	if GameState.party_size() <= 1:
		_complete_chest_open(_first_living_party_slot(), false)
		return
	## Roster + digits, same affordances as camp "Who will guard?".
	_chest_open_cursor = _first_living_party_slot()
	_chest_open_stage = 1
	_open_order_roster()
	_reset_hold_state()
	if _roster:
		_roster.visible = true
	_sync_chest_open_selection()
	_layout_prompt_row()


func _handle_chest_open_input(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
			_cancel_chest_open(true)
			return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B:
		_cancel_chest_open(true)
		return true
	if event.is_action_pressed("cancel") and event is InputEventJoypadButton:
		_cancel_chest_open(true)
		return true
	if event is InputEventKey and _is_order_cancel_key(event as InputEventKey):
		_cancel_chest_open(true)
		return true
	if event is InputEventKey and _is_order_confirm_key(event as InputEventKey):
		_accept_chest_open_slot(_chest_open_cursor)
		return true
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
		_accept_chest_open_slot(_chest_open_cursor)
		return true
	if event is InputEventKey:
		var ke := event as InputEventKey
		var dig := _player_digit_index_from_key(ke)
		if dig >= 0:
			if dig >= GameState.party_size():
				_push_message(Locale.t("cmd_who"), false)
				_layout_prompt_row()
				return true
			_chest_open_cursor = dig
			_sync_chest_open_selection()
			_accept_chest_open_slot(dig)
			return true
		if _is_digit_key(ke):
			_push_message(Locale.t("cmd_who"), false)
			_layout_prompt_row()
			return true
	return true


func _nudge_chest_open_cursor(delta: int) -> void:
	var n := maxi(GameState.party_size(), 1)
	var slot := _chest_open_cursor
	for _i in n:
		slot = posmod(slot + delta, n)
		if _camp_guard_slot_eligible(slot):
			_chest_open_cursor = slot
			_sync_chest_open_selection()
			return


func _sync_chest_open_selection() -> void:
	if _roster:
		_roster.set_order_selection(_chest_open_cursor, -1)


func _accept_chest_open_slot(slot: int) -> void:
	## Number key or list Enter — dead/sleeping rejected like xu4 gameGetPlayer(false).
	var n := GameState.party_size()
	if slot < 0 or slot >= n:
		_push_message(Locale.t("cmd_who"), false)
		_layout_prompt_row()
		return
	if not _camp_guard_slot_eligible(slot):
		_push_message(Locale.t("cmd_cant"), false)
		_layout_prompt_row()
		return
	_push_message(GameState.party_member_display_name(slot), false)
	_complete_chest_open(slot, true)


func _complete_chest_open(slot: int, finish_turn: bool) -> void:
	## Shared by Who-pick and solo auto-open. Solo leaves turn to _finish_directed_command.
	var target := _chest_open_target
	var opener_klass := GameState.party_member_at(slot)
	_clear_chest_open_ui()
	if _city_map == null or not _city_map.loaded:
		if finish_turn:
			_finish_action_turn()
		return
	if _city_map.is_chest_empty(target.x, target.y):
		_push_message(Locale.t("cmd_chest_empty"), false)
		if finish_turn:
			_finish_action_turn()
		return
	if _city_map.is_chest_open(target.x, target.y):
		_push_message(Locale.t("cmd_chest_already_open"), false)
		if finish_turn:
			_finish_action_turn()
		return
	var already_looted := _is_remembered_empty_chest(target.x, target.y)
	_city_map.open_chest_at(target.x, target.y, not already_looted)
	if already_looted:
		_mark_city_chest_emptied(target.x, target.y)
	if _map != null and _map.has_method("begin_chest_loot_reveal"):
		_map.begin_chest_loot_reveal()
	elif _map != null and _map.has_method("refresh"):
		_map.refresh()
	_push_message(Locale.t("cmd_opened"), false)
	_resolve_chest_trap(slot, opener_klass)
	if already_looted:
		_push_message(Locale.t("cmd_chest_empty"), false)
	if finish_turn:
		_finish_action_turn()


func _finish_action_turn() -> void:
	## Party-clock outside combat; combat spends the focused member.
	if _combat_active and _combat_victory_aftermath:
		return
	if _combat_active:
		_combat_finish_member_turn()
	else:
		_finish_party_turn()


func _cancel_chest_open(show_none: bool) -> void:
	var was := _chest_open_stage
	_clear_chest_open_ui()
	if show_none and was != 0:
		if _combat_active:
			## Esc mid "Who opens?" — command cancelled, turn kept.
			_push_message(Locale.t("cmd_cancelled"), false)
		else:
			_push_message(Locale.t("cmd_none"), false)


func _clear_chest_open_ui() -> void:
	_chest_open_stage = 0
	_chest_open_target = Vector2i(-1, -1)
	_chest_open_cursor = 0
	_clear_order_selection()
	if not _sides_open:
		_close_order_roster()
	_layout_prompt_row()


func _do_get_chest(dir: Vector2i) -> String:
	## Ultima4R: Get after Open — gold + KA_STOLE_CHEST (trap already resolved on Open).
	## Combat: object chests from slain foes (no city karma steal).
	if _is_in_combat() and _map != null and _map.is_in_combat():
		var from := _map.get_combat_focus_pos()
		if from.x < 0:
			return Locale.t("cmd_not_here")
		var ctarget := from + dir
		if not _map.has_combat_chest_at(ctarget):
			return Locale.t("cmd_not_here")
		if not _map.combat_chest_is_open(ctarget):
			return Locale.t("cmd_not_here")
		if not _map.combat_chest_has_loot(ctarget):
			return Locale.t("cmd_chest_empty")
		var entry := _map.take_combat_chest_loot(ctarget)
		var msg := GameState.apply_chest_loot_entry(entry)
		_refresh_inventory_bars()
		_push_message(msg, false)
		return ""
	if not _is_in_city() or _city_map == null or not _city_map.loaded:
		return Locale.t("cmd_not_here")
	var target := Vector2i(_tile_pos.x + dir.x, _tile_pos.y + dir.y)
	if (
		target.x < 0 or target.y < 0
		or target.x >= _CityMapData.WIDTH
		or target.y >= _CityMapData.HEIGHT
	):
		return Locale.t("cmd_not_here")
	var tid := int(_city_map.effective_tile_at(target.x, target.y))
	if not _TileRules.is_chest(tid):
		return Locale.t("cmd_not_here")
	if not _city_map.is_chest_open(target.x, target.y):
		return Locale.t("cmd_not_here")
	if not _city_map.chest_has_loot(target.x, target.y):
		return Locale.t("cmd_chest_empty")

	var gold := GameState.take_chest_gold()
	GameState.adjust_karma_stole_chest()
	_city_map.take_chest_loot(target.x, target.y)
	_mark_city_chest_emptied(target.x, target.y)
	if _map != null and _map.has_method("refresh"):
		_map.refresh()
	_refresh_inventory_bars()
	_push_message(Locale.t("cmd_chest_holds", [gold]), false)
	return ""


func _resolve_chest_trap(opener_slot: int, opener_klass: int) -> void:
	## Trap on Open. Acid/poison/sleep: opener DEX evade, else hit opener only.
	## Bomb: no party-wide evade — each living member rolls their own DEX evade.
	var roll: Dictionary = GameState.roll_chest_trap_u4dos()
	if not bool(roll.get("sprung", false)):
		return
	var trap_type := int(roll.get("trap_type", TileRules.Effect.NONE))
	match trap_type:
		TileRules.Effect.FIRE:
			_push_message(Locale.t("cmd_chest_trap_acid"), false)
		TileRules.Effect.POISON:
			_push_message(Locale.t("cmd_chest_trap_poison"), false)
		TileRules.Effect.SLEEP:
			_push_message(Locale.t("cmd_chest_trap_sleep"), false)
		TileRules.Effect.LAVA:
			_push_message(Locale.t("cmd_chest_trap_bomb"), false)
			_apply_chest_bomb_per_member()
			return
		_:
			return
	if GameState.chest_trap_evaded(opener_klass):
		_push_message(Locale.t("cmd_chest_trap_evaded"), false)
		return
	var flash := GameState.apply_effect(trap_type, opener_slot)
	_refresh_party()
	_flash_party_damage(flash)


func _apply_chest_bomb_per_member() -> void:
	## Ultima4R: bomb blast — each member evades with their own DEX or takes damage.
	var flash := 0
	var any_hit := false
	for i in GameState.party_size():
		var mid := GameState.party_member_at(i)
		if mid < 0 or GameState.is_class_dead(mid):
			continue
		if GameState.chest_trap_evaded(mid):
			continue
		any_hit = true
		flash |= GameState.apply_effect(TileRules.Effect.LAVA, i)
	if not any_hit:
		_push_message(Locale.t("cmd_chest_trap_evaded"), false)
		return
	_refresh_party()
	_flash_party_damage(flash)


func _flash_party_damage(flash: int) -> void:
	if flash == 0:
		return
	if _roster and _roster.has_method("flash_players"):
		_roster.flash_players(flash)
	if _compact_roster and _compact_roster.has_method("flash_players"):
		_compact_roster.flash_players(flash)


func _do_jimmy(dir: Vector2i) -> String:
	## xu4 jimmyAt — locked door + key → permanent unlocked-door annotation.
	## No failure roll in xu4: key always works; one key consumed.
	## Annotations clear when the .ULT is reloaded (exit/re-enter or floor change).
	const TILE_DOOR := 59
	var target := Vector2i(_tile_pos.x + dir.x, _tile_pos.y + dir.y)
	if not _is_in_city() or _city_map == null or not _city_map.loaded:
		return Locale.t("cmd_jimmy_what")
	if (
		target.x < 0 or target.y < 0
		or target.x >= _CityMapData.WIDTH
		or target.y >= _CityMapData.HEIGHT
	):
		return Locale.t("cmd_jimmy_what")
	var tid := int(_city_map.effective_tile_at(target.x, target.y))
	if not _TileRules.is_locked_door(tid):
		return Locale.t("cmd_jimmy_what")
	if GameState.keys <= 0:
		return Locale.t("cmd_no_keys")
	GameState.keys -= 1
	_city_map.add_annotation(target.x, target.y, TILE_DOOR, -1)
	_refresh_inventory_bars()
	if _map != null and _map.has_method("refresh"):
		_map.refresh()
	return Locale.t("cmd_unlocked")


func _directed_result_message(cmd: int) -> String:
	## Stub outcomes match xu4 when the action finds nothing useful.
	match cmd:
		U4Commands.Id.ATTACK:
			return Locale.t("cmd_nothing_to_attack")
		U4Commands.Id.JIMMY:
			return Locale.t("cmd_jimmy_what")
		U4Commands.Id.OPEN:
			return Locale.t("cmd_nothing_to_open")
		U4Commands.Id.GET_CHEST:
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
	_refresh_foe_roster()


func _refresh_foe_roster() -> void:
	if _foe_roster == null:
		return
	if not _combat_active or _map == null or not _map.is_in_combat():
		_foe_roster.clear()
		return
	_foe_roster.set_foes(_map.get_combat_foes())
	_sync_combat_aim_foe_roster()


func _sync_combat_aim_foe_roster() -> void:
	## While aiming: red-highlight the left-panel foe under the aim cursor.
	if _foe_roster == null:
		return
	if not _combat_aiming or _map == null or not _map.is_in_combat():
		_foe_roster.clear_aim_highlight()
		return
	var foe_i := _map.combat_foe_index_at(_combat_aim_pos)
	if foe_i < 0:
		_foe_roster.clear_aim_highlight()
		return
	var foe := _map.get_combat_foe_at(foe_i)
	var slot := int(foe.get("slot", -1))
	if slot < 0:
		_foe_roster.clear_aim_highlight()
	else:
		_foe_roster.set_aim_highlight_slot(slot)


func _sync_combat_focus_roster() -> void:
	## Mirror map focus onto the right-hand party list.
	if _roster == null or _map == null or not _combat_active:
		return
	var slot := _map.get_combat_focus_party_slot()
	if slot < 0:
		_roster.clear_order_selection()
	else:
		_roster.set_order_selection(slot, -1)


func _push_move_message(dir: Vector2i) -> void:
	if not _load_error.is_empty():
		return
	## xu4 avatarMoved: foot/horse = direction name; ship = "Sail …!".
	if _transport == Transport.SHIP:
		_push_message(Locale.t("cmd_sail", [_direction_label(dir, false)]), false)
	else:
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
	## Labels are single-line + clip_text — wrap like xu4 screenMessage (panel width).
	for part in _wrap_msg_text(line):
		_msg_lines.append(part)
	while _msg_lines.size() > MSG_KEEP:
		_msg_lines.remove_at(0)
	_refresh_message_view()


func _msg_line_max_width() -> float:
	## Usable width of a history Label inside the message block.
	if _msg_block != null and _msg_block.size.x > 1.0:
		return maxf(_msg_block.size.x - 2.0, 8.0)
	if _msg_rw > 1.0:
		return maxf(_msg_rw - float(MSG_INSET_X) * 2.0, 8.0)
	return 220.0


func _msg_font_size() -> int:
	return clampi(int(floorf(_msg_pitch)) - 2, 10, MSG_FONT_SIZE) if _msg_pitch > 0.0 else MSG_FONT_SIZE


func _msg_text_width(text: String, font: Font, font_sz: int) -> float:
	if font == null:
		return float(text.length()) * float(font_sz) * 0.55
	return font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz
	).x


func _wrap_msg_text(text: String) -> PackedStringArray:
	## Soft-wrap to the message pane (prefer spaces; else break mid-token / CJK).
	var out: PackedStringArray = PackedStringArray()
	if text.is_empty():
		return out
	var max_w := _msg_line_max_width()
	var font := UiTheme.font()
	var font_sz := _msg_font_size()
	if _msg_text_width(text, font, font_sz) <= max_w:
		out.append(text)
		return out
	var remaining := text
	while not remaining.is_empty():
		if _msg_text_width(remaining, font, font_sz) <= max_w:
			out.append(remaining)
			break
		var fit := 0
		for i in remaining.length():
			if _msg_text_width(remaining.substr(0, i + 1), font, font_sz) > max_w:
				break
			fit = i + 1
		if fit <= 0:
			fit = 1
		var chunk := remaining.substr(0, fit)
		## Prefer last space so English wraps on words (xu4 screenMessage).
		var sp := chunk.rfind(" ")
		if sp > 0:
			chunk = remaining.substr(0, sp)
			remaining = remaining.substr(sp + 1)
		else:
			remaining = remaining.substr(fit)
		if not chunk.is_empty():
			out.append(chunk)
	return out


func _tick_world_clock(delta: float) -> void:
	## xu4 timerFired at gameCyclesPerSecond (default 4 Hz).
	if not _load_error.is_empty():
		return
	_world_clock_accum += delta
	var sky_changed := false
	var on_world := not _is_in_city()
	while _world_clock_accum >= GameState.WORLD_TICK_SEC:
		_world_clock_accum -= GameState.WORLD_TICK_SEC
		## xu4 updateMoons only on the world map (cities freeze moon advance).
		var old_tram := GameState.trammel_phase
		if GameState.tick_world_clock(on_world):
			sky_changed = true
		if on_world:
			_sync_moongate(false, old_tram)
	if sky_changed and _top_bar != null and _top_bar.has_method("refresh"):
		_top_bar.refresh()


func _sync_moongate(_force: bool = false, _old_tram: int = -1) -> void:
	## xu4 GameController::updateMoons(showmoongates=true) — annotation frames.
	if _map == null:
		return
	if _is_in_city() or _world == null or not _world.loaded:
		_map.clear_moongate()
		return
	var tram := GameState.trammel_phase
	var sub := _Moongates.trammel_subphase(GameState.moon_phase)
	var hf := _Moongates.height_frac(sub)
	var tid := _Moongates.tile_for_subphase(sub)
	var gate: Vector2i = _Moongates.coords(tram)
	## Load / city exit (`force`): already-open gates appear fully risen, no sprout.
	_map.set_moongate(gate, tid, hf, _force)


func _try_moongate_travel() -> bool:
	## xu4 checkMoongates — foot/horse only; teleport Trammel → Felucca.
	if _moongate_busy or _is_in_city():
		return false
	if _transport != Transport.FOOT and _transport != Transport.HORSE:
		return false
	var dest: Vector2i = _Moongates.try_destination(
		_tile_pos, GameState.trammel_phase, GameState.felucca_phase
	)
	if dest.x < 0:
		return false
	_moongate_busy = true
	_reset_hold_state()
	_moongate_travel_async(dest)
	return true


func _moongate_travel_async(dest: Vector2i) -> void:
	## xu4 gameSpellEffect(SOUND_MOONGATE) before and after the hop — held longer here.
	var flash_sec := MapView.MOONGATE_FLASH_SEC
	var gap_sec := MapView.MOONGATE_TRAVEL_GAP_SEC
	if _map != null:
		await _map.await_spell_flash(flash_sec)
	if dest != _tile_pos:
		if gap_sec > 0.0:
			await get_tree().create_timer(gap_sec).timeout
		_tile_pos = dest
		if _map != null:
			_map.set_center(_tile_pos, false)
		_refresh_locate_hud()
		if _map != null:
			await _map.await_spell_flash(flash_sec)
	## Spirituality shrine (both moons full) not wired yet — stay at Felucca gate.
	_moongate_busy = false


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
