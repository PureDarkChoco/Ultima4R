extends Control

## Explore: top/bottom status bars + fixed 25×11 map.
## Message terminal: fixed 15-line grid (even pitch). Tab opens all 15;
## closed clips to the bottom 5 at the same pitch. Last line is always
## Ultima-style prompt + blue charset @ cursor animation (bottom-aligned history).

## Preload so world scene parses even if global class cache is stale.
const _TileRules := preload("res://src/map/tile_rules.gd")
const _MixPanel := preload("res://src/ui/mix_panel.gd")
const _CombatMapData := preload("res://src/map/combat_map_data.gd")
const _SaveSlotPanel := preload("res://src/ui/save_slot_panel.gd")
const _SaveGame := preload("res://src/core/save_game.gd")
const _EscMenuPanel := preload("res://src/ui/esc_menu_panel.gd")
const _CityMapData := preload("res://src/map/city_map_data.gd")
const _WorldPortals := preload("res://src/map/world_portals.gd")
const _CityFloorPortals := preload("res://src/map/city_floor_portals.gd")
const _U4TileBankScript := preload("res://src/map/u4_tile_bank.gd")
const _Moongates := preload("res://src/map/moongates.gd")

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
var _mix_panel # MixPanel — preloaded script instance
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
## Improved Mix: 0 = idle, 1 = known list, 2 = reagent pick, 3 = wait spell letter (Make new).
var _mix_stage := 0
## Hole up & Camp: 0 = idle, 1 = resting, 2 = set watch? Y/N, 3 = pick guard.
var _camp_stage := 0
var _camp_rest_left := 0.0
var _camp_map # CombatMapData
var _camp_guard_klass := -1
var _camp_guard_cursor := 0
## City chest Open: 0 = idle, 1 = Who opens? (digit / list Enter).
var _chest_open_stage := 0
var _chest_open_target := Vector2i(-1, -1)
var _chest_open_cursor := 0
## True while xu4 immobilized (all asleep) auto-turns are queued.
var _immobilized_pending := false
## xu4 settings campTime default (Resting… animation seconds).
const CAMP_REST_SEC := 10.0
## xu4 finishTurn Zzzzzz pause (~4 frames @ 24fps).
const IMMOBILIZED_SLEEP_SEC := 0.166
## Quit & Save / Esc Load: 0 = idle, 1 = save picker, 2 = load picker.
var _save_stage := 0
var _save_panel # SaveSlotPanel
## True when the slot picker was opened from the Esc menu (return there after).
var _slot_from_esc := false
var _esc_menu # EscMenuPanel
## City / castle visit (Enter). World position restored on leave.
var _city_map # CityMapData
var _city_return_pos := Vector2i.ZERO
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
		return clampi(h, 0, GameState.SHIP_HULL_MAX)
	return GameState.SHIP_HULL_MAX


func _store_ship_hull_at(tile: Vector2i, hull: int) -> void:
	_ship_hulls[_ship_hull_key(tile)] = clampi(hull, 0, GameState.SHIP_HULL_MAX)


func _damage_ship_from_grounding(dir: Vector2i) -> void:
	## Y-cruise grounding: headwind 0, else -5.
	var dmg := GameState.ship_grounding_damage(dir)
	if dmg > 0:
		GameState.ship_hull = clampi(
			GameState.ship_hull - dmg,
			0,
			GameState.SHIP_HULL_MAX
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
	if _mix_stage == 1:
		return MSG_PROMPT + Locale.t("mix_title")
	if _mix_stage == 2:
		return MSG_PROMPT + Locale.t("mix_title")
	if _mix_stage == 3:
		return MSG_PROMPT + Locale.t("mix_for_spell")
	if _ztats_stage == 1:
		return MSG_PROMPT + Locale.t("cmd_ztats_for")
	if _camp_stage == 2:
		return MSG_PROMPT + Locale.t("cmd_camp_set_watch")
	if _camp_stage == 3:
		return MSG_PROMPT + Locale.t("cmd_camp_who_guards")
	if _chest_open_stage == 1:
		return MSG_PROMPT + Locale.t("cmd_chest_who_opens")
	if _save_stage == 1:
		return MSG_PROMPT + Locale.t("save_title")
	if _save_stage == 2:
		return MSG_PROMPT + Locale.t("load_title")
	if _esc_menu_is_open():
		return MSG_PROMPT + Locale.t("esc_menu_title")
	if _order_stage == 1:
		return MSG_PROMPT + Locale.t("cmd_exchange")
	if _order_stage == 2:
		return MSG_PROMPT + Locale.t("cmd_with")
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
	## xu4 GameController::timerFired — real-time clock even while menus/peer open.
	_tick_world_clock(delta)
	if _moongate_busy:
		return
	## xu4 force pass if no commands within last 20 seconds.
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
	## All asleep: Zzzzzz auto-turns own the clock — no player move/cruise.
	if _is_party_asleep_locked():
		return
	## Z/N/R/W/M pick lists: same hold timing as world move; wrap at ends.
	if _ztats_stage == 1 or _order_stage != 0 or _ready_stage == 1 or _wear_stage == 1 or _mix_stage == 1 or _mix_stage == 2 or _camp_stage == 3 or _chest_open_stage == 1 or _save_stage == 1 or _save_stage == 2 or _esc_menu_is_open():
		_tick_select_cursor()
		return
	if _ready_stage == 2:
		_tick_ready_weapon_cursor()
		return
	if _wear_stage == 2:
		_tick_wear_armor_cursor()
		return
	if _camp_stage == 1:
		_tick_camp_rest(delta)
		return
	if _ztats_stage != 0 or _mix_stage != 0 or _camp_stage != 0 or _chest_open_stage != 0 or _save_stage != 0 or _esc_menu_is_open():
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
	elif _camp_stage == 3:
		_nudge_camp_guard_cursor(step)
	elif _chest_open_stage == 1:
		_nudge_chest_open_cursor(step)
	elif _save_stage == 1 or _save_stage == 2:
		_nudge_save_cursor(step)
	elif _esc_menu_is_open():
		_nudge_esc_menu_cursor(step)
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
		return
	if _esc_menu_is_open():
		_close_esc_menu()
		return
	_open_esc_menu()


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
			## Ztats / Ready / Wear / Mix / camp pick open: don't collapse/expand side panels.
			## Camp rest allows Tab so inventory panels stay reachable.
			if (
				_ztats_stage != 0
				or _ready_stage != 0
				or _wear_stage != 0
				or _mix_stage != 0
				or _camp_stage == 2
				or _camp_stage == 3
				or _chest_open_stage != 0
				or _save_stage != 0
				or _esc_menu_is_open()
			):
				get_viewport().set_input_as_handled()
				return
			_toggle_side_panels()
			get_viewport().set_input_as_handled()
			return


func _unhandled_input(event: InputEvent) -> void:
	## Ztats / Ready / Wear / Mix / Camp / Chest Open / Save / Load / Esc menu / New Order.
	if _moongate_busy:
		get_viewport().set_input_as_handled()
		return
	if _save_stage != 0:
		if _handle_save_input(event):
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
	## xu4 fire(): not on a ship → "Fire What?" (no Dir?).
	if cmd == U4Commands.Id.FIRE:
		_clear_pending_dir()
		_clear_pending_order()
		_close_ztats(false)
		_close_ready(false)
		_close_wear(false)
		_close_mix(false)
		_close_camp(false)
		_cancel_chest_open(false)
		_close_save(false)
		_push_message(Locale.t("cmd_fire_what"), false)
		return
	if U4Commands.NEEDS_DIRECTION.get(cmd, false):
		## xu4: print "Attack: " then "Dir?" on the *same* line and wait.
		_clear_pending_order()
		_close_ztats(false)
		_close_ready(false)
		_close_wear(false)
		_close_mix(false)
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
	_close_camp(false)
	_cancel_chest_open(false)
	_close_save(false)
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
	elif cmd == U4Commands.Id.MIX:
		_do_mix()
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
		var hull := clampi(GameState.ship_hull, 0, GameState.SHIP_HULL_MAX)
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


func _esc_menu_is_open() -> bool:
	return _esc_menu != null and _esc_menu.is_open()


func _open_esc_menu() -> void:
	_ensure_esc_menu()
	_reset_hold_state()
	_esc_menu.open_panel(0)
	_layout_prompt_row()


func _close_esc_menu() -> void:
	if _esc_menu:
		_esc_menu.close_panel()
	_layout_prompt_row()


func _nudge_esc_menu_cursor(delta: int) -> void:
	if _esc_menu:
		_esc_menu.nudge_cursor(delta)


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
			_close_esc_menu()
			SceneRouter.to_menu()
		_EscMenuPanel.Item.OPTION:
			if _esc_menu:
				_esc_menu.set_status(Locale.t("esc_menu_option_soon"))
		_EscMenuPanel.Item.QUIT:
			get_tree().quit()


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
	elif _order_opened_roster and _order_stage == 0 and _ready_stage == 0 and _wear_stage == 0 and _mix_stage == 0:
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
	elif _order_opened_roster and _order_stage == 0 and _ztats_stage == 0 and _wear_stage == 0 and _mix_stage == 0:
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


func _do_hole_up() -> void:
	## U5-style Hole up: ask for a watch, then CAMP.CON rest.
	_push_message(Locale.t("cmd_hole_up"), false)
	var deny := _hole_up_deny_message()
	if not deny.is_empty():
		_push_message(deny, false)
		return
	_camp_guard_klass = -1
	_camp_guard_cursor = 0
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
	_city_map = null
	_tile_pos = _city_return_pos
	if _map != null:
		_map.exit_city()
		_map.set_center(_tile_pos, false)
		_map.set_transport_tile(_transport_tile if _transport != Transport.FOOT else -1)
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
	## xu4 CampController after Resting… — 1/8 ambush, else heal + exit.
	## U5 watch: guard is always excluded from heal.
	if (randi() % 8) == 0:
		## Combat not wired yet — interrupt rest without heal (xu4 starts fight).
		_push_message(Locale.t("cmd_camp_ambushed"), false)
		_end_camp_session(false)
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


func _end_camp_session(_healed: bool) -> void:
	GameState.wake_party()
	_refresh_party()
	if _map:
		_map.exit_camp()
	_camp_map = null
	_camp_stage = 0
	_camp_rest_left = 0.0
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
	_run_party_turn_once(in_combat)
	if in_combat:
		return
	_maybe_continue_immobilized()


func _run_party_turn_once(in_combat: bool = false) -> void:
	var result: Dictionary = GameState.end_party_turn(true, in_combat)
	## xu4: after endTurn, applyEffect from tile underfoot (skipped while flying / combat).
	var ground_flash := 0 if in_combat else _apply_ground_tile_effect()
	## xu4 Map::moveObjects — town NPCs roam after the party acts.
	if not in_combat:
		_move_city_persons()
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
	if GameState.is_party_dead():
		_immobilized_pending = false
		## Death sequence not wired yet — stop the sleep loop.
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
	if GameState.is_party_dead() or not GameState.is_party_immobilized():
		_refresh_party()
		return
	_run_party_turn_once(false)
	_maybe_continue_immobilized()


func _move_city_persons() -> void:
	## xu4 finishTurn → location->map->moveObjects(avatar).
	if not _is_in_city() or _city_map == null or not _city_map.loaded:
		return
	if not _city_map.move_persons(_tile_pos):
		return
	if _map != null and _map.has_method("refresh"):
		_map.refresh()


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
	if _ztats_stage != 0 or _order_stage != 0 or _ready_stage != 0 or _wear_stage != 0 or _mix_stage != 0 or _camp_stage != 0 or _chest_open_stage != 0 or _save_stage != 0 or _esc_menu_is_open():
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
		U4Commands.Id.OPEN:
			result = _do_open(dir)
		U4Commands.Id.JIMMY:
			result = _do_jimmy(dir)
		U4Commands.Id.GET_CHEST:
			result = _do_get_chest(dir)
		_:
			result = _directed_result_message(cmd)
	if not result.is_empty():
		_push_message(result, false)
	## Chest Open waits on "Who opens?" — turn finishes after the pick.
	if _chest_open_stage != 0:
		return
	## xu4: directed actions consume a turn (Attack/Jimmy/Open/…).
	_finish_party_turn()


func _do_open(dir: Vector2i) -> String:
	## xu4 opendoor / openAt — unlocked door → brick floor annotation, ttl 4.
	## Ultima4R: city chests ask Who opens? then trap; Get only loots.
	const TILE_BRICK_FLOOR := 62
	const DOOR_OPEN_TTL := 4
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
			_finish_party_turn()
		return
	if _city_map.is_chest_empty(target.x, target.y):
		_push_message(Locale.t("cmd_chest_empty"), false)
		if finish_turn:
			_finish_party_turn()
		return
	if _city_map.is_chest_open(target.x, target.y):
		_push_message(Locale.t("cmd_chest_already_open"), false)
		if finish_turn:
			_finish_party_turn()
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
		_finish_party_turn()


func _cancel_chest_open(show_none: bool) -> void:
	var was := _chest_open_stage
	_clear_chest_open_ui()
	if show_none and was != 0:
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
	_msg_lines.append(line)
	while _msg_lines.size() > MSG_KEEP:
		_msg_lines.remove_at(0)
	_refresh_message_view()


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
