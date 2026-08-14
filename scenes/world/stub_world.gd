extends Control

## Explore: top/bottom status bars + fixed 25×11 map.
## Message terminal: fixed 15-line grid (even pitch). Tab opens all 15;
## closed clips to the bottom 5 at the same pitch. Last line is always
## Ultima-style charset prompt glyph + spinning @ cursor (bottom-aligned history).

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
const _TalkTlk := preload("res://src/core/talk_tlk.gd")
const _TalkLocale := preload("res://src/core/talk_locale.gd")
const _CityNpcRoles := preload("res://src/map/city_npc_roles.gd")
const _VendorShop := preload("res://src/core/vendor_shop.gd")
const _CombatMaps := preload("res://src/map/combat_maps.gd")
const _CombatEncounter := preload("res://src/map/combat_encounter.gd")
const _ShrinePortals := preload("res://src/map/shrine_portals.gd")
const _Shrine := preload("res://src/core/shrine.gd")
const _Hawkwind := preload("res://src/core/hawkwind.gd")
const _LordBritish := preload("res://src/core/lord_british.gd")
const _GameInput := preload("res://src/core/game_input.gd")
## Preload — bare class_name can miss the global class cache (black screen).
const _FoeRosterScript := preload("res://src/ui/foe_roster.gd")
const _JournalScript := preload("res://src/core/journal.gd")

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
@onready var _journal_panel: VBoxContainer = %JournalPanel
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
const MSG_KEEP := 64
const MSG_OPEN_LINES := 15
const MSG_CLOSED_LINES := 5
const MSG_INSET_X := 8
const MSG_INSET_Y := 6
const MSG_FONT_SIZE := 14
const MSG_COLOR := Color(0.91, 0.9, 0.82, 1)
## Talk keyword menu: not-yet-spoken NPC topics (still selectable for debugging).
const MSG_COLOR_LATENT := Color(0.48, 0.5, 0.52, 1)
const CHARSET_PATH := "res://assets/tiles/u4graphics/charset.png"
const CHARSET_GLYPH := 16
## xu4 CHARSET_PROMPT ('\020' = index 16) — blue right-triangle from charset.png.
const PROMPT_CHAR := 16
## charset.png: blue spinning @ frames (after moon glyphs 20..27).
const CURSOR_CHAR0 := 28
const CURSOR_FRAME_COUNT := 4
const CURSOR_FRAME_SEC := 0.34
## Slight lift on the charset blue glyphs so they read better on the navy panel.
const CURSOR_BRIGHTEN := 1.45
const CURSOR_BRIGHTEN_ADD := 0.12
## History-line marker: rendered as charset prompt image, never shown as "►" text.
const MSG_PROMPT_MARK := "\u0001"
const LAYOUT_UNITS := 13.0
const BAR_UNITS := 0.5
const SIDE_TWEEN_SEC := 0.18
const RIGHT_TOP_TILES := 5
const COMPACT_RIGHT_TILES := 2
## Locate HUD (Ctrl/⌘+L) — X from open-map right edge; Y on top bar. Tweak inset.
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
## xu4 transportContext stub: foot / horse / ship / balloon.
enum Transport { FOOT, HORSE, SHIP, BALLOON }
var _transport: int = Transport.FOOT
var _transport_tile := -1
## xu4 saveGame.balloonstate — 1 while Klimb altitude (aloft).
var _balloon_flying := false
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
var _left_trigger_held := false
var _right_trigger_held := false
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
## Victory B/Esc confirmation; No keeps the arena open for chest looting.
var _combat_exit_prompt := false
## xu4 InnController::awardLoot empty — no combat chests after inn ambush.
var _combat_suppress_chests := false
## Victory solo control: party_order slot (0..7), or −1 = sequential party mode.
var _victory_solo_party_slot := -1
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
var _pending_world_ranged: Array[Dictionary] = []
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
## Mix opened from gamepad command menu → full A–Z list (no Mix New + letter).
var _mix_gamepad_requested := false
var _mix_pad_full_list := false
## Use (U): 0 = idle, 1 = pick item from list.
var _use_stage := 0
## Hole up & Camp: 0 = idle, 1 = resting, 2 = set watch? Y/N, 3 = pick guard.
var _camp_stage := 0
var _camp_rest_left := 0.0
## xu4 Shrine::enter — 0 approach, 1 virtue, 2 cycles, 3 dots, 4 mantra, 5 key, 6 exit walk.
var _shrine_stage := 0
var _shrine_virtue: int = 0
var _shrine_cycles: int = 0
var _shrine_completed: int = 0
var _shrine_buffer: String = ""
var _shrine_busy := false
## Prevent re-entrant eject while walk-out runs.
var _shrine_ejecting := false
## From map load until walk-out finishes — lock Tab / keep panels restored.
var _shrine_session := false
var _shrine_saved_sides_open := false
const SHRINE_WALK_STEP_SEC := 0.40
const SHRINE_WALK_START := Vector2i(5, 10) ## xu4 enhancedSequence south edge
const SHRINE_WALK_ALTAR := Vector2i(5, 6)
## xu4 InnController — rest in city after paying the innkeeper.
## 0 = idle, 1 = sleeping (corpse tile + timer).
var _inn_stage := 0
var _inn_rest_left := 0.0
var _inn_prev_transport_tile := -1
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
## xu4 settings innTime default (InnController wait before Morning!).
const INN_REST_SEC := 8.0
## xu4 finishTurn Zzzzzz pause (~4 frames @ 24fps).
const IMMOBILIZED_SLEEP_SEC := 0.166
## xu4 death.cpp — deathStart(delay) + DeathController tick + revive.
## Pre-message (xu4 ~10s): delay 5s + controller 5s → remake: 5 + 3 hold + 2 fade.
const DEATH_PAUSE_SEC := 5.0 ## seconds between death dialogue lines (controller tick)
const DEATH_CONTROLLER_HOLD_SEC := 3.0 ## hold on map before first-line fade
const DEATH_FADE_OUT_SEC := 2.0 ## last part of first DeathController beat (fade to black)
const DEATH_FADE_IN_SEC := 2.0 ## fade in after revive at Lord British throne
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
## Gamepad walk-on enter prompt: 0 = idle, 1 = Yes/No on message strip.
var _enter_prompt_stage := 0
var _enter_prompt_choice := 0 ## selected button index in the dialogue choice row
## After No, suppress while still on this portal tile; cleared when you leave.
var _enter_prompt_declined := Vector2i(-99999, -99999)
var _enter_btn_row: HBoxContainer
var _choice_btns: Array[Button] = []
## Prevent one A press from accepting both the current and immediately rebuilt prompt.
var _choice_resolved_frame := -1
## xu4 anger forgotten next visit; within one stay (incl. LCB floor changes), keep
## guards/LB on MOVE_ATTACK after alertGuards until the player leaves the place.
var _city_guards_alerted := false
## Per-.ULT emptied chests only (not open lids). Key = lowercase basename →
## { "x,y": true }. Leave/floor change closes lids; memory/save keep emptied spots.
var _city_chest_memory: Dictionary = {}
var _load_error: String = ""
var _esc_held := false
var _msg_lines: PackedStringArray = PackedStringArray()
## History rows support BBCode (talk keyword tint).
var _msg_rows: Array[RichTextLabel] = []
var _msg_prompt_row: Control
var _shop_item_highlight: ColorRect
var _shop_item_highlight_edge: TextureRect
var _msg_prompt_icon: TextureRect ## xu4 CHARSET_PROMPT glyph (not a Unicode ►)
var _msg_prompt_label: Label
var _msg_cursor: TextureRect
var _msg_ui_ready := false
var _prompt_tex: Texture2D
var _cursor_frames: Array[Texture2D] = []
var _cursor_frame := 0
var _cursor_t := 0.0
var _msg_h := 0.0
var _msg_full_h := 0.0
var _msg_rw := 0.0
var _msg_open_x := 0.0
var _msg_open_content_h := 0.0
var _msg_pitch := 0.0
## Gamepad B command palette. Independent MapPane overlay; dialogue owns its own height.
var _command_menu_open := false
var _command_menu_cursor := 0
var _command_menu_last_cmd := U4Commands.Id.NONE
var _command_menu_items: Array[int] = []
var _command_menu_layer: Control
var _command_menu_backdrop: ColorRect
var _command_menu_frame: Panel
var _command_menu_separator: ColorRect
var _command_menu_scroll_track: ColorRect
var _command_menu_scroll_thumb: ColorRect
var _command_menu_scroll_up: Label
var _command_menu_scroll_down: Label
var _command_menu_rows: Array[ColorRect] = []
## LOCAL CHEAT (⌘/Ctrl+P) — city warp list. Do not commit.
var _city_warp_open := false
## Cmd/Ctrl+J: browse the left-pane journal; Esc restores prior side-panel state.
var _journal_focus_active := false
var _journal_saved_sides_open := false
## Journal opened the left pane without the right roster (sides were closed).
var _journal_opened_left_only := false
var _city_warp_cursor := 0
var _city_warp_scroll := 0
var _city_warp_items: Array[Dictionary] = []
## Gamepad-started conversations reuse the command palette chrome for keywords.
## Each item stores a stable dedupe key plus the displayed/submitted word.
var _talk_gamepad_requested := false
var _talk_keyword_menu_active := false
var _talk_keyword_menu_cursor := 0
var _talk_keyword_menu_scroll := 0
## After T:Dir opens the menu, ignore the still-held tilt until neutral.
var _talk_keyword_menu_await_neutral := false
var _talk_keyword_menu_items: Array[Dictionary] = []
var _talk_keyword_menu_seen: Dictionary = {}
## Talk session (city .TLK discourse). 0 = idle.
## 1 Interest / 2 wait-any-key before YN / 3 Y-N answer / 4 give gold.
## 10 vendor shop (xu4 vendors.b) / 11 Hawkwind seer counsel / 12 Lord British /
## 13 LB heal confirm (Art thou well?).
var _talk_stage := 0
var _talk_person_i := -1
var _talk_entry: RefCounted = null ## _TalkTlk.Entry
var _talk_buffer := ""
## Focused LineEdit used as an OS IME proxy while the terminal keeps its custom look.
var _talk_edit: LineEdit
var _talk_edit_syncing := false
## Native libhangul composer. When the extension is unavailable, _talk_edit
## remains the OS-IME fallback so editor runs never lose text input.
var _talk_hangul: RefCounted
var _talk_hangul_preedit := ""
var _talk_keywords: Array = []
var _talk_turn_away := 0
var _talk_pending_ask := false
var _talk_is_hawkwind := false
var _talk_is_lb := false
var _shop = null ## _VendorShop session
var _shop_item_menu_cursor := 0
var _shop_item_menu_items: Array[Dictionary] = []
var _shop_item_menu_line_indices: Array[int] = []
var _shop_item_line_by_key: Dictionary = {}
## Talk expands message strip + character roster (not left inventory unless Tab already open).
## Shop peeks: weapon/armor/reagent Ztats lists replace the roster while trading.
var _talk_msg_open := false
var _talk_msg_tween: Tween
var _shop_inv_kind := "" ## "weapons" | "armor" | "reagents" | ""
var _sides_open := false
## N (New Order): temporarily show only the character roster panel.
var _order_opened_roster := false
## Bump to cancel a pending delayed roster slide-away.
var _order_close_token := 0
const ORDER_ROSTER_HOLD_SEC := 1.1
var _side_tween: Tween


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
		_sync_moongate(true)

	call_deferred("_fit_explore_map")
	call_deferred("grab_focus")
	if not GameState.language_changed.is_connected(_on_language_changed):
		GameState.language_changed.connect(_on_language_changed)
	_JournalScript.ensure_catalog()
	_sync_left_panel_mode()
	if not _load_error.is_empty():
		_push_message(_load_error)
		push_error(_load_error)
	else:
		_refresh_party()
		_refresh_ship_hull_hud()
		_refresh_journal_panel()


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
	_balloon_flying = bool(w.get("balloon_flying", false))
	if _transport != Transport.BALLOON:
		_balloon_flying = false
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
		_sync_balloon_view()
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
	_apply_remembered_city_chests(cmap)
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
	_sync_balloon_view()
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
	elif MapView.is_balloon_tile(tid):
		_push_message(Locale.t("cmd_board_balloon"), false)
		_transport = Transport.BALLOON
		_balloon_flying = false
	else:
		_push_message(Locale.t("cmd_board_what"), false)
		_finish_party_turn()
		return
	_map.remove_overlay_at(_tile_pos)
	_transport_tile = tid
	_map.set_transport_tile(_transport_tile)
	_sync_balloon_view()
	_refresh_ship_hull_hud()
	_finish_party_turn()


func _do_xit() -> void:
	## xu4 exitTransport(): leave horse/ship/balloon as a map object underfoot.
	## Cannot X-it while balloon is aloft.
	if _transport == Transport.FOOT or _map == null or _is_balloon_flying():
		_push_message(Locale.t("cmd_xit_what"), false)
		_finish_party_turn()
		return
	## Leave empty horse/ship facing as last ridden; gallop resets.
	var leave_tid := _transport_tile
	if leave_tid < 0:
		if _transport == Transport.SHIP:
			leave_tid = MapView.TILE_SHIP_W
		elif _transport == Transport.BALLOON:
			leave_tid = MapView.TILE_BALLOON
		else:
			leave_tid = MapView.TILE_HORSE_W
	if _transport == Transport.SHIP:
		## Persist hull on this world cell so the same ship keeps its damage.
		_store_ship_hull_at(_tile_pos, GameState.ship_hull)
		_parked_ship_tile = _tile_pos
	_map.add_overlay(_tile_pos, leave_tid)
	_transport = Transport.FOOT
	_transport_tile = -1
	_horse_gallop = false
	_balloon_flying = false
	_stop_ship_cruise()
	_map.set_transport_tile(-1)
	_sync_balloon_view()
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
	## xu4 terrain rules via TileRules (walk / sail / horse creature-walk / balloon).
	## Aloft balloon: collision override (timer drift only; keys never call this).
	if _is_balloon_flying():
		return true
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
			c_dest, c_from, cdir, false, _transport == Transport.HORSE, false
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
		if MapView.is_ship_tile(over) or MapView.is_horse_tile(over) or MapView.is_balloon_tile(over):
			## Ship/horse/balloon tiles are walkable; still need walk-off from previous terrain.
			return _TileRules.can_walk_off(from_id, dir)

	return _TileRules.can_avatar_enter(
		dest_id,
		from_id,
		dir,
		_transport == Transport.SHIP,
		_transport == Transport.HORSE,
		_transport == Transport.BALLOON
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
	## Balloon has a single tile; facing is visual only.


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
			"panel", _make_edge_panel(
				_FoeRosterScript.ROSTER_STYLE_PAD, 0, 0, 2, 0, Color(0.0, 0.0, 0.0, 0.8)
			)
		)
	if _right_top is PanelContainer:
		## Open panel chrome (reference): style pad + MarginContainer pad.
		(_right_top as PanelContainer).add_theme_stylebox_override(
			"panel", _make_edge_panel(PartyRoster.ROSTER_STYLE_PAD, 2, 0, 0, 0)
		)
	if _right_bottom is Panel:
		## Message strip: dark semi-transparent so map tiles faintly show (~90% cover).
		(_right_bottom as Panel).add_theme_stylebox_override(
			"panel", _make_edge_panel(0, 2, 2, 0, 0, Color(0.0, 0.0, 0.0, 0.9))
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
	border_b: int,
	bg: Color = Color(0.0, 0.0, 0.0, 1.0)
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
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
		## Script hot-reload does not rerun _ready or rebuild dynamic children.
		## Recover/create the IME editor so an already-running game does not keep
		## a stale terminal after this feature changes.
		if _talk_edit == null or not is_instance_valid(_talk_edit):
			var existing := _msg_prompt_row.get_node_or_null("TalkImeEdit") as LineEdit
			if existing != null:
				_talk_edit = existing
			else:
				_talk_edit = _make_talk_ime_edit()
				_msg_prompt_row.add_child(_talk_edit)
		_ensure_enter_prompt_buttons()
		_ensure_command_menu_layer()
		_ensure_shop_item_message_highlight()
		return
	if _msg_block == null:
		return
	_msg_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_block.clip_contents = false
	_load_msg_charset_glyphs()
	_ensure_shop_item_message_highlight()
	## History rows (14) + prompt row (1) = 15 equal slots.
	for i in range(MSG_OPEN_LINES - 1):
		var row := _make_msg_history_row()
		_msg_block.add_child(row)
		_msg_rows.append(row)
	_msg_prompt_row = Control.new()
	_msg_prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_block.add_child(_msg_prompt_row)
	_msg_prompt_icon = TextureRect.new()
	_msg_prompt_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_prompt_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_msg_prompt_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_msg_prompt_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _prompt_tex != null:
		_msg_prompt_icon.texture = _prompt_tex
	_msg_prompt_row.add_child(_msg_prompt_icon)
	_msg_prompt_label = _make_msg_prompt_label()
	_msg_prompt_label.text = ""
	_msg_prompt_row.add_child(_msg_prompt_label)
	_talk_edit = _make_talk_ime_edit()
	_talk_edit.name = "TalkImeEdit"
	_msg_prompt_row.add_child(_talk_edit)
	_msg_cursor = TextureRect.new()
	_msg_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_cursor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_msg_cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_msg_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not _cursor_frames.is_empty():
		_msg_cursor.texture = _cursor_frames[0]
	_msg_prompt_row.add_child(_msg_cursor)
	_ensure_enter_prompt_buttons()
	_ensure_command_menu_layer()
	_msg_ui_ready = true
	_refresh_message_view()


func _ensure_shop_item_message_highlight() -> void:
	if _msg_block == null:
		return
	if _shop_item_highlight != null and is_instance_valid(_shop_item_highlight):
		return
	var existing := _msg_block.get_node_or_null("ShopItemHighlight") as ColorRect
	if existing != null:
		_shop_item_highlight = existing
		var old_edge := existing.get_node_or_null("SelectionEdge")
		if old_edge is TextureRect:
			_shop_item_highlight_edge = old_edge as TextureRect
		else:
			if old_edge != null:
				existing.remove_child(old_edge)
				old_edge.queue_free()
			_shop_item_highlight_edge = UiTheme.make_selection_edge("", MSG_FONT_SIZE)
			existing.add_child(_shop_item_highlight_edge)
		return
	_shop_item_highlight = ColorRect.new()
	_shop_item_highlight.name = "ShopItemHighlight"
	_shop_item_highlight.visible = false
	_shop_item_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_item_highlight.color = Color(0.22, 0.42, 0.82, 0.65)
	_msg_block.add_child(_shop_item_highlight)
	_msg_block.move_child(_shop_item_highlight, 0)
	_shop_item_highlight_edge = UiTheme.make_selection_edge("", MSG_FONT_SIZE)
	_shop_item_highlight.add_child(_shop_item_highlight_edge)


func _ensure_enter_prompt_buttons() -> void:
	## Choice button row in the dialogue prompt slot (town enter / shop / talk).
	if _msg_prompt_row == null:
		return
	if _enter_btn_row != null and is_instance_valid(_enter_btn_row):
		return
	_enter_btn_row = HBoxContainer.new()
	_enter_btn_row.visible = false
	_enter_btn_row.mouse_filter = Control.MOUSE_FILTER_STOP
	_enter_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_enter_btn_row.add_theme_constant_override("separation", 12)
	_msg_prompt_row.add_child(_enter_btn_row)


func _rebuild_choice_buttons(count: int) -> void:
	_ensure_enter_prompt_buttons()
	if _enter_btn_row == null:
		return
	while _choice_btns.size() > count:
		var old := _choice_btns.pop_back() as Button
		if old != null and is_instance_valid(old):
			if old.get_parent() != null:
				old.get_parent().remove_child(old)
			old.queue_free()
	while _choice_btns.size() < count:
		var i := _choice_btns.size()
		var btn := Button.new()
		## Controller/keyboard input is handled once by _unhandled_input.
		## Keeping GUI focus off prevents the same A press from also firing the
		## newly rebuilt next prompt through ui_accept.
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.custom_minimum_size = Vector2(48, 0)
		var pick := i
		btn.pressed.connect(func() -> void: _resolve_prompt_choice_index(pick))
		btn.focus_entered.connect(func() -> void: _set_enter_prompt_choice(pick))
		_enter_btn_row.add_child(btn)
		_choice_btns.append(btn)
	## No left/right wrap — ends stay on the first / last choice.
	for i in _choice_btns.size():
		var btn2 := _choice_btns[i]
		var left_i := maxi(i - 1, 0)
		var right_i := mini(i + 1, _choice_btns.size() - 1)
		btn2.focus_neighbor_left = btn2.get_path_to(_choice_btns[left_i])
		btn2.focus_neighbor_right = btn2.get_path_to(_choice_btns[right_i])
		btn2.focus_neighbor_top = btn2.get_path_to(btn2)
		btn2.focus_neighbor_bottom = btn2.get_path_to(btn2)


func _ensure_command_menu_layer() -> void:
	if _map_pane == null:
		return
	if _command_menu_layer != null and is_instance_valid(_command_menu_layer):
		if _command_menu_layer.get_parent() != _map_pane:
			_command_menu_layer.reparent(_map_pane)
		_ensure_command_menu_scroll_nodes()
		return
	_command_menu_layer = Control.new()
	_command_menu_layer.name = "CommandMenuLayer"
	_command_menu_layer.visible = false
	_command_menu_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_command_menu_layer.clip_contents = true
	_map_pane.add_child(_command_menu_layer)
	_command_menu_backdrop = ColorRect.new()
	_command_menu_backdrop.color = Color(0.025, 0.055, 0.07, 1.0)
	_command_menu_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_command_menu_layer.add_child(_command_menu_backdrop)
	_command_menu_frame = Panel.new()
	_command_menu_frame.name = "MenuFrame"
	_command_menu_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0, 0, 0, 0)
	frame_style.border_color = UiTheme.ACCENT
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(0)
	_command_menu_frame.add_theme_stylebox_override("panel", frame_style)
	_command_menu_layer.add_child(_command_menu_frame)
	_command_menu_separator = ColorRect.new()
	_command_menu_separator.name = "BottomSeparator"
	_command_menu_separator.color = UiTheme.ACCENT
	_command_menu_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_command_menu_layer.add_child(_command_menu_separator)
	_ensure_command_menu_scroll_nodes()
	_command_menu_layer.move_to_front()


func _ensure_command_menu_scroll_nodes() -> void:
	if _command_menu_layer == null:
		return
	if _command_menu_scroll_track == null or not is_instance_valid(_command_menu_scroll_track):
		_command_menu_scroll_track = ColorRect.new()
		_command_menu_scroll_track.name = "ScrollTrack"
		_command_menu_scroll_track.color = Color(UiTheme.ACCENT, 0.28)
		_command_menu_scroll_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_command_menu_scroll_track.visible = false
		_command_menu_layer.add_child(_command_menu_scroll_track)
	if _command_menu_scroll_thumb == null or not is_instance_valid(_command_menu_scroll_thumb):
		_command_menu_scroll_thumb = ColorRect.new()
		_command_menu_scroll_thumb.name = "ScrollThumb"
		_command_menu_scroll_thumb.color = UiTheme.ACCENT
		_command_menu_scroll_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_command_menu_scroll_thumb.visible = false
		_command_menu_layer.add_child(_command_menu_scroll_thumb)
	if _command_menu_scroll_up == null or not is_instance_valid(_command_menu_scroll_up):
		_command_menu_scroll_up = Label.new()
		_command_menu_scroll_up.name = "ScrollMoreUp"
		_command_menu_scroll_up.text = "▲"
		_command_menu_scroll_up.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_command_menu_scroll_up.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_command_menu_scroll_up.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_command_menu_scroll_up.visible = false
		_command_menu_scroll_up.add_theme_color_override("font_color", UiTheme.ACCENT)
		UiTheme.apply_font(_command_menu_scroll_up)
		_command_menu_layer.add_child(_command_menu_scroll_up)
	if _command_menu_scroll_down == null or not is_instance_valid(_command_menu_scroll_down):
		_command_menu_scroll_down = Label.new()
		_command_menu_scroll_down.name = "ScrollMoreDown"
		_command_menu_scroll_down.text = "▼"
		_command_menu_scroll_down.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_command_menu_scroll_down.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_command_menu_scroll_down.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_command_menu_scroll_down.visible = false
		_command_menu_scroll_down.add_theme_color_override("font_color", UiTheme.ACCENT)
		UiTheme.apply_font(_command_menu_scroll_down)
		_command_menu_layer.add_child(_command_menu_scroll_down)


func _command_menu_scroll_metrics() -> Dictionary:
	## Shared by keyword / city-warp lists that window into MSG_OPEN_LINES.
	var total := 0
	var scroll := 0
	var vis := 0
	if _city_warp_open:
		total = _city_warp_items.size()
		scroll = _city_warp_scroll
		vis = _city_warp_visible_count()
	elif _talk_keyword_menu_active:
		total = _talk_keyword_menu_items.size()
		scroll = _talk_keyword_menu_scroll
		vis = _talk_keyword_visible_count()
	return {
		"active": total > vis and vis > 0,
		"total": total,
		"scroll": scroll,
		"vis": vis,
		"can_up": scroll > 0,
		"can_down": scroll + vis < total,
	}


func _rebuild_command_menu_rows() -> void:
	_ensure_command_menu_layer()
	if _command_menu_layer == null:
		return
	for row in _command_menu_rows:
		if row != null and is_instance_valid(row):
			if row.get_parent() != null:
				row.get_parent().remove_child(row)
			row.queue_free()
	_command_menu_rows.clear()
	var lang := GameState.lang_short()
	var row_texts: Array[String] = []
	if _city_warp_open:
		var vis := _city_warp_visible_count()
		for i in vis:
			var abs_i := _city_warp_scroll + i
			if abs_i < 0 or abs_i >= _city_warp_items.size():
				continue
			row_texts.append(str(_city_warp_items[abs_i].get("label", "")))
	elif _talk_keyword_menu_active:
		var vis := _talk_keyword_visible_count()
		for i in vis:
			var abs_i := _talk_keyword_menu_scroll + i
			if abs_i < 0 or abs_i >= _talk_keyword_menu_items.size():
				continue
			var item: Dictionary = _talk_keyword_menu_items[abs_i]
			var lab := str(item.get("label", ""))
			if not bool(item.get("revealed", true)):
				lab = "[color=#%s]%s[/color]" % [
					MSG_COLOR_LATENT.to_html(false),
					lab,
				]
			row_texts.append(lab)
	else:
		for cmd in _command_menu_items:
			var letter := U4Commands.letter_for(cmd)
			var command_name := U4Commands.label(cmd, lang)
			if cmd == U4Commands.Id.PASS:
				row_texts.append("[color=#%s]%s[/color] - %s" % [
					UiTheme.ACCENT.to_html(false),
					letter,
					command_name,
				])
				continue
			if lang == "ko":
				row_texts.append("[color=#%s]%s[/color] - %s" % [
					UiTheme.ACCENT.to_html(false),
					letter,
					command_name,
				])
			else:
				## English command names already begin with their command key:
				## [A]ttack, [B]oard, [C]ast, …
				var rest := command_name.substr(1) if command_name.length() > 1 else ""
				row_texts.append("[color=#%s]%s[/color]%s" % [
					UiTheme.ACCENT.to_html(false),
					letter,
					rest,
				])
	for row_text in row_texts:
		var row := ColorRect.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := RichTextLabel.new()
		label.name = "Label"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.bbcode_enabled = true
		label.fit_content = false
		label.scroll_active = false
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text = row_text
		label.add_theme_color_override("default_color", MSG_COLOR)
		label.add_theme_font_size_override("normal_font_size", MSG_FONT_SIZE)
		UiTheme.apply_font(label)
		row.add_child(label)
		var edge := UiTheme.make_selection_edge("", MSG_FONT_SIZE)
		row.add_child(edge)
		_command_menu_layer.add_child(row)
		_command_menu_rows.append(row)
	_command_menu_layer.move_to_front()
	_layout_command_menu_layer()


func _layout_command_menu_layer() -> void:
	if _command_menu_layer == null or _map_pane == null:
		return
	var g := _side_geom()
	var pane_size := _map_pane.size
	var panel_w := float(g["pane_w"]) - float(g["right_open_x"])
	var panel_h := float(g["bottom_open_h"])
	var count := _command_menu_rows.size()
	var content_h := maxf(
		panel_h - float(MSG_INSET_Y * 2),
		float(MSG_OPEN_LINES)
	)
	var pitch := content_h / float(MSG_OPEN_LINES)
	## Match MsgBlock's inner 15-line grid for row pitch; width stays half the
	## dialogue panel. Sit immediately left of the message pane — menu top-right
	## to dialogue top-left — so keywords never cover talk text.
	var menu_margin := float(MSG_INSET_Y)
	var gap := float(MSG_INSET_X)
	var inner_w := maxf(panel_w - menu_margin * 2.0, 8.0)
	var menu_w := maxf(floorf(inner_w * 0.5), 8.0)
	var menu_h := minf(content_h, float(count) * pitch)
	## Always dock to the open dialogue corner so Talk keywords and the
	## right-click command palette share one stable spot.
	var dialogue_x := float(g["right_open_x"])
	var dialogue_y := float(g["bottom_open_y"])
	var menu_x := dialogue_x - gap - menu_w
	menu_x = clampf(menu_x, menu_margin, maxf(pane_size.x - menu_w, 0.0))
	_command_menu_layer.position = Vector2(menu_x, dialogue_y)
	_command_menu_layer.size = Vector2(menu_w, menu_h)
	_command_menu_layer.custom_minimum_size = Vector2.ZERO
	if _command_menu_backdrop != null:
		_command_menu_backdrop.position = Vector2.ZERO
		_command_menu_backdrop.size = _command_menu_layer.size
	if _command_menu_frame != null:
		_command_menu_frame.position = Vector2.ZERO
		_command_menu_frame.size = _command_menu_layer.size
		_command_menu_frame.move_to_front()
	if _command_menu_separator != null:
		_command_menu_separator.visible = count > 0 and count < MSG_OPEN_LINES
		_command_menu_separator.position = Vector2(0, maxf(menu_h - 1.0, 0.0))
		_command_menu_separator.size = Vector2(menu_w, 1)
		_command_menu_separator.move_to_front()
	var scroll_info := _command_menu_scroll_metrics()
	var scroll_active := bool(scroll_info.get("active", false))
	var scroll_gutter := 10.0 if scroll_active else 0.0
	if count <= 0:
		if _command_menu_scroll_track != null:
			_command_menu_scroll_track.visible = false
		if _command_menu_scroll_thumb != null:
			_command_menu_scroll_thumb.visible = false
		if _command_menu_scroll_up != null:
			_command_menu_scroll_up.visible = false
		if _command_menu_scroll_down != null:
			_command_menu_scroll_down.visible = false
		return
	var font_sz := clampi(int(floorf(pitch)) - 2, 10, MSG_FONT_SIZE)
	var row_w := menu_w
	var selected_cursor := _command_menu_cursor
	if _city_warp_open:
		selected_cursor = _city_warp_cursor - _city_warp_scroll
	elif _talk_keyword_menu_active:
		selected_cursor = _talk_keyword_menu_cursor - _talk_keyword_menu_scroll
	for i in count:
		var row := _command_menu_rows[i]
		row.position = Vector2(0, float(i) * pitch)
		row.size = Vector2(row_w, pitch)
		row.custom_minimum_size = Vector2.ZERO
		row.color = (
			Color(0.22, 0.42, 0.82, 0.55)
			if i == selected_cursor
			else Color(0, 0, 0, 0)
		)
		var label := row.get_node_or_null("Label") as RichTextLabel
		if label != null:
			label.position = Vector2(8, 0)
			label.size = Vector2(maxf(row_w - 14.0 - scroll_gutter, 4.0), pitch)
			label.add_theme_font_size_override("normal_font_size", font_sz)
			label.add_theme_color_override("default_color", MSG_COLOR)
		var edge := row.get_node_or_null("SelectionEdge") as Control
		if edge != null:
			UiTheme.layout_selection_edge(edge, row_w, pitch, font_sz)
			UiTheme.set_selection_edge_active(edge, i == selected_cursor)
	_layout_command_menu_scroll_chrome(menu_w, menu_h, pitch, font_sz, scroll_info)


func _layout_command_menu_scroll_chrome(
	menu_w: float,
	menu_h: float,
	pitch: float,
	font_sz: int,
	scroll_info: Dictionary
) -> void:
	## Thin right-edge scrollbar + ▲/▼ when a keyword/warp list overflows.
	if (
		_command_menu_scroll_track == null
		or _command_menu_scroll_thumb == null
		or _command_menu_scroll_up == null
		or _command_menu_scroll_down == null
	):
		return
	var active := bool(scroll_info.get("active", false))
	_command_menu_scroll_track.visible = active
	_command_menu_scroll_thumb.visible = active
	if not active:
		_command_menu_scroll_up.visible = false
		_command_menu_scroll_down.visible = false
		return
	var total := maxi(int(scroll_info.get("total", 0)), 1)
	var scroll := clampi(int(scroll_info.get("scroll", 0)), 0, total)
	var vis := clampi(int(scroll_info.get("vis", 1)), 1, total)
	var track_w := 3.0
	var track_pad := 3.0
	var track_x := menu_w - track_pad - track_w
	var track_top := 4.0
	var track_h := maxf(menu_h - track_top * 2.0, 8.0)
	_command_menu_scroll_track.position = Vector2(track_x, track_top)
	_command_menu_scroll_track.size = Vector2(track_w, track_h)
	var thumb_h := maxf(track_h * (float(vis) / float(total)), 10.0)
	var travel := maxf(track_h - thumb_h, 0.0)
	var thumb_t := 0.0
	if total > vis:
		thumb_t = travel * (float(scroll) / float(total - vis))
	_command_menu_scroll_thumb.position = Vector2(track_x, track_top + thumb_t)
	_command_menu_scroll_thumb.size = Vector2(track_w, thumb_h)
	var mark_sz := maxf(float(font_sz) - 2.0, 9.0)
	var mark_w := 10.0
	_command_menu_scroll_up.visible = bool(scroll_info.get("can_up", false))
	_command_menu_scroll_down.visible = bool(scroll_info.get("can_down", false))
	_command_menu_scroll_up.add_theme_font_size_override("font_size", int(mark_sz))
	_command_menu_scroll_down.add_theme_font_size_override("font_size", int(mark_sz))
	_command_menu_scroll_up.size = Vector2(mark_w, pitch)
	_command_menu_scroll_down.size = Vector2(mark_w, pitch)
	_command_menu_scroll_up.position = Vector2(menu_w - mark_w - 1.0, 0.0)
	_command_menu_scroll_down.position = Vector2(
		menu_w - mark_w - 1.0,
		maxf(menu_h - pitch, 0.0)
	)
	_command_menu_scroll_track.move_to_front()
	_command_menu_scroll_thumb.move_to_front()
	_command_menu_scroll_up.move_to_front()
	_command_menu_scroll_down.move_to_front()
	if _command_menu_frame != null:
		_command_menu_frame.move_to_front()


func _load_msg_charset_glyphs() -> void:
	## Extract xu4 CHARSET_PROMPT and spinning-cursor frames from charset.png.
	_cursor_frames.clear()
	_prompt_tex = null
	var img := Image.new()
	if img.load(CHARSET_PATH) != OK:
		var tex := load(CHARSET_PATH) as Texture2D
		if tex:
			img = tex.get_image()
	if img == null or img.is_empty():
		return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	_prompt_tex = _charset_glyph_tex(img, PROMPT_CHAR, true)
	for frame in CURSOR_FRAME_COUNT:
		_cursor_frames.append(_charset_glyph_tex(img, CURSOR_CHAR0 + frame, true))


func _charset_glyph_tex(sheet: Image, char_index: int, brighten: bool) -> Texture2D:
	var cy := char_index * CHARSET_GLYPH
	if cy + CHARSET_GLYPH > sheet.get_height():
		return null
	var glyph := Image.create(CHARSET_GLYPH, CHARSET_GLYPH, false, Image.FORMAT_RGBA8)
	glyph.blit_rect(sheet, Rect2i(0, cy, CHARSET_GLYPH, CHARSET_GLYPH), Vector2i.ZERO)
	for y in CHARSET_GLYPH:
		for x in CHARSET_GLYPH:
			var c := glyph.get_pixel(x, y)
			if c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
				glyph.set_pixel(x, y, Color(0, 0, 0, 0))
			elif brighten:
				glyph.set_pixel(x, y, Color(
					minf(c.r * CURSOR_BRIGHTEN + CURSOR_BRIGHTEN_ADD, 1.0),
					minf(c.g * CURSOR_BRIGHTEN + CURSOR_BRIGHTEN_ADD, 1.0),
					minf(c.b * CURSOR_BRIGHTEN + CURSOR_BRIGHTEN_ADD * 0.5, 1.0),
					c.a
				))
	return ImageTexture.create_from_image(glyph)


func _make_msg_history_row() -> RichTextLabel:
	## BBCode-capable history line (talk keyword tint).
	var lb := RichTextLabel.new()
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.bbcode_enabled = true
	lb.scroll_active = false
	lb.fit_content = false
	lb.autowrap_mode = TextServer.AUTOWRAP_OFF
	lb.clip_contents = true
	## No theme stylebox padding — wrap width must match painted glyph width.
	var empty := StyleBoxEmpty.new()
	lb.add_theme_stylebox_override("normal", empty)
	lb.add_theme_stylebox_override("focus", empty)
	lb.add_theme_constant_override("margin_left", 0)
	lb.add_theme_constant_override("margin_right", 0)
	lb.add_theme_color_override("default_color", MSG_COLOR)
	lb.add_theme_font_size_override("normal_font_size", MSG_FONT_SIZE)
	var f := UiTheme.font()
	if f:
		lb.add_theme_font_override("normal_font", f)
	lb.custom_minimum_size = Vector2.ZERO
	return lb


func _make_msg_prompt_label() -> Label:
	## Live input text after the charset prompt glyph (Dir? / buffers / titles).
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


func _make_talk_ime_edit() -> LineEdit:
	## Real focused editor: the platform IME owns layout-specific composition
	## (2-set/3-set Hangul), preedit display, and composition backspace.
	var edit := LineEdit.new()
	edit.name = "TalkImeEdit"
	edit.visible = false
	edit.mouse_filter = Control.MOUSE_FILTER_STOP
	edit.focus_mode = Control.FOCUS_ALL
	edit.context_menu_enabled = false
	edit.virtual_keyboard_enabled = true
	edit.keep_editing_on_text_submit = true
	edit.select_all_on_focus = false
	edit.add_theme_color_override("font_color", MSG_COLOR)
	edit.add_theme_color_override("font_uneditable_color", MSG_COLOR)
	edit.add_theme_color_override("caret_color", MSG_COLOR)
	edit.add_theme_color_override("selection_color", Color(MSG_COLOR, 0.35))
	edit.add_theme_font_size_override("font_size", MSG_FONT_SIZE)
	UiTheme.apply_font(edit)
	var empty := StyleBoxEmpty.new()
	edit.add_theme_stylebox_override("normal", empty)
	edit.add_theme_stylebox_override("focus", empty)
	edit.add_theme_stylebox_override("read_only", empty)
	edit.add_theme_constant_override("minimum_character_width", 0)
	edit.text_changed.connect(_on_talk_ime_text_changed)
	edit.text_submitted.connect(_on_talk_ime_text_submitted)
	return edit


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
	_layout_command_menu_layer()


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
		lb.add_theme_font_size_override("normal_font_size", font_sz)
		lb.position = Vector2(0.0, float(i) * _msg_pitch)
		lb.size = Vector2(w, _msg_pitch)
		lb.custom_minimum_size = Vector2.ZERO
		lb.scroll_active = false

	if _msg_prompt_row:
		_msg_prompt_row.position = Vector2(0.0, float(MSG_OPEN_LINES - 1) * _msg_pitch)
		_msg_prompt_row.size = Vector2(w, _msg_pitch)
		_msg_prompt_row.custom_minimum_size = Vector2.ZERO
	_layout_prompt_row(font_sz)


func _prompt_row_text() -> String:
	## Body only — CHARSET_PROMPT glyph is drawn as TextureRect when applicable.
	## xu4: "Attack: Dir?" waits on the same line as the prompt glyph + cursor.
	if _ready_stage == 1:
		return Locale.t("cmd_ready_for")
	if _ready_stage == 2:
		return Locale.t("cmd_ready_weapon")
	if _wear_stage == 1:
		return Locale.t("cmd_wear_for")
	if _wear_stage == 2:
		return Locale.t("cmd_wear_armor")
	if _mix_stage == 1:
		return Locale.t("mix_title")
	if _mix_stage == 2:
		return Locale.t("mix_title")
	if _mix_stage == 3:
		return Locale.t("mix_for_spell")
	if _use_stage == 1:
		return Locale.t("cmd_use_which")
	if _ztats_stage == 1:
		return Locale.t("cmd_ztats_for")
	if _camp_stage == 2:
		return Locale.t("cmd_camp_set_watch")
	if _camp_stage == 3:
		return Locale.t("cmd_camp_who_guards")
	if _shrine_stage == 1:
		return _shrine_buffer
	if _shrine_stage == 2:
		return ""
	if _shrine_stage == 4:
		return _shrine_buffer
	if _shrine_stage == 5:
		return ""
	if _chest_open_stage == 1:
		return Locale.t("cmd_chest_who_opens")
	if _telescope_stage == 1:
		return Locale.t("cmd_telescope_select")
	if _save_stage == 1:
		return Locale.t("save_title")
	if _save_stage == 2:
		return Locale.t("load_title")
	if _options_panel_is_open():
		return Locale.t("esc_options_title")
	if _esc_menu_is_open():
		return Locale.t("esc_menu_title")
	if _order_stage == 1:
		return Locale.t("cmd_exchange")
	if _order_stage == 2:
		return Locale.t("cmd_with")
	if _combat_aiming:
		return Locale.t("cmd_attack_aim")
	## Talk: xu4 has no CHARSET_PROMPT on dialogue input — only the live cursor.
	if _talk_stage == 1:
		return (
			_talk_input_mode_marker() + _talk_buffer + _talk_hangul_preedit
			if _talk_native_hangul_active() else ""
		)
	if _talk_stage == 2:
		return "" ## wait any key before yes/no question
	if _talk_stage == 3:
		var say_pfx := "당신은 말한다: " if str(GameState.language) == "ko" else "You say: "
		return say_pfx + (
			_talk_input_mode_marker() + _talk_buffer + _talk_hangul_preedit
			if _talk_native_hangul_active() else ""
		)
	if _talk_stage == 4:
		## "How much?" already written to history; live row is the amount only.
		return _talk_buffer
	if _talk_stage == 11:
		return (
			_talk_input_mode_marker() + _talk_buffer + _talk_hangul_preedit
			if _talk_native_hangul_active() else ""
		)
	if _talk_stage == 12:
		return (
			_talk_input_mode_marker() + _talk_buffer + _talk_hangul_preedit
			if _talk_native_hangul_active() else ""
		)
	if _talk_stage == 13:
		var say_pfx2 := "당신은 말한다: " if str(GameState.language) == "ko" else "You say: "
		return say_pfx2 + (
			_talk_input_mode_marker() + _talk_buffer + _talk_hangul_preedit
			if _talk_native_hangul_active() else ""
		)
	if _talk_stage == 10 and _shop != null:
		if int(_shop.mode) == _VendorShop.Mode.TEXT and _talk_native_hangul_active():
			return _talk_input_mode_marker() + _talk_buffer + _talk_hangul_preedit
		return _talk_buffer
	if _pending_cmd != U4Commands.Id.NONE and not _pending_cmd_name.is_empty():
		return Locale.need_dir_prompt(_pending_cmd_name)
	if _ship_yell_await_dir:
		return Locale.need_dir_prompt(
			U4Commands.label(U4Commands.Id.YELL, GameState.lang_short())
		)
	return ""


func _prompt_row_wants_glyph() -> bool:
	## xu4 screenPrompt — world command wait shows CHARSET_PROMPT; talk input does not.
	return _talk_stage == 0


func _msg_prompt_glyph_side(font_sz: int) -> float:
	var side := float(font_sz) * 1.05
	if _msg_pitch > 0.0:
		side = minf(side, _msg_pitch)
	return maxf(side, 10.0)


func _layout_prompt_row(font_sz: int = -1) -> void:
	_sync_talk_keyword_menu_visibility()
	if _msg_prompt_label == null:
		return
	if font_sz < 0:
		font_sz = clampi(int(floorf(_msg_pitch)) - 2, 10, MSG_FONT_SIZE)
	if _binary_prompt_active():
		_layout_enter_prompt_row(font_sz)
		return
	if _enter_btn_row != null:
		_enter_btn_row.visible = false
	if _msg_prompt_row != null:
		_msg_prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := _prompt_row_text()
	var wants_glyph := _prompt_row_wants_glyph()
	var x := 0.0
	var side := _msg_prompt_glyph_side(font_sz)
	if _msg_prompt_icon != null:
		if wants_glyph and _prompt_tex != null:
			_msg_prompt_icon.visible = true
			_msg_prompt_icon.texture = _prompt_tex
			_msg_prompt_icon.size = Vector2(side, side)
			_msg_prompt_icon.custom_minimum_size = Vector2.ZERO
			_msg_prompt_icon.position = Vector2(0.0, (_msg_pitch - side) * 0.5)
			x = side + 2.0
		else:
			_msg_prompt_icon.visible = false
	_msg_prompt_label.add_theme_font_size_override("font_size", font_sz)
	_msg_prompt_label.text = text
	_msg_prompt_label.add_theme_color_override("font_color", MSG_COLOR)
	var text_w := 0.0
	if not text.is_empty():
		var font := _msg_prompt_label.get_theme_font("font")
		if font:
			text_w = font.get_string_size(
				text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz
			).x
		else:
			text_w = float(font_sz) * float(text.length()) * 0.55
		_msg_prompt_label.visible = true
		_msg_prompt_label.position = Vector2(x, 0.0)
		_msg_prompt_label.size = Vector2(maxf(text_w, 8.0), _msg_pitch)
		_msg_prompt_label.custom_minimum_size = Vector2.ZERO
		x += text_w
	else:
		_msg_prompt_label.visible = false
	var ime_active := _talk_ime_stage_active()
	if _talk_edit != null:
		_talk_edit.visible = ime_active
		if ime_active:
			_talk_edit.add_theme_font_size_override("font_size", font_sz)
			_talk_edit.position = Vector2(x, 0.0)
			_talk_edit.size = Vector2(maxf(_msg_prompt_row.size.x - x, 8.0), _msg_pitch)
			_talk_edit.custom_minimum_size = Vector2.ZERO
			_sync_talk_ime_edit()
		elif _talk_edit.has_focus():
			_talk_edit.release_focus()
	if _msg_cursor:
		_msg_cursor.visible = not ime_active
		## Charset @ sits inset in the 16×16 cell; scale slightly past font_sz.
		var cside := float(font_sz) * 1.2
		cside = minf(cside, _msg_pitch) if _msg_pitch > 0.0 else cside
		_msg_cursor.size = Vector2(cside, cside)
		_msg_cursor.custom_minimum_size = Vector2.ZERO
		_msg_cursor.position = Vector2(x, (_msg_pitch - cside) * 0.5)
		_apply_cursor_frame()


func _layout_enter_prompt_row(font_sz: int) -> void:
	## Bottom dialogue row: multi-choice buttons, left–right + A.
	var keys := _prompt_choice_keys()
	if keys.is_empty():
		return
	_rebuild_choice_buttons(keys.length())
	if _msg_prompt_icon != null:
		_msg_prompt_icon.visible = false
	if _msg_prompt_label != null:
		_msg_prompt_label.visible = false
	if _talk_edit != null:
		_talk_edit.visible = false
		if _talk_edit.has_focus():
			_talk_edit.release_focus()
	if _msg_cursor != null:
		_msg_cursor.visible = false
	if _msg_prompt_row != null:
		_msg_prompt_row.mouse_filter = Control.MOUSE_FILTER_STOP
	if _enter_btn_row == null:
		return
	_enter_btn_row.visible = true
	_enter_btn_row.position = Vector2.ZERO
	_enter_btn_row.size = Vector2(maxf(_msg_prompt_row.size.x, 8.0), maxf(_msg_pitch, 14.0))
	_enter_btn_row.custom_minimum_size = Vector2.ZERO
	var btn_h := maxf(_msg_pitch - 2.0, 14.0)
	var min_w := 48.0 if keys.length() >= 3 else 58.0
	if keys == "abc":
		min_w = 72.0
	_enter_prompt_choice = clampi(_enter_prompt_choice, 0, maxi(keys.length() - 1, 0))
	for i in _choice_btns.size():
		var btn := _choice_btns[i]
		if btn == null:
			continue
		btn.visible = i < keys.length()
		if i >= keys.length():
			continue
		btn.custom_minimum_size = Vector2(min_w, btn_h)
		btn.text = _prompt_choice_label(keys.substr(i, 1))
	_sync_enter_prompt_style()
	_sync_enter_prompt_style()


func _set_enter_prompt_choice(index: int) -> void:
	var n := maxi(_prompt_choice_keys().length(), 1)
	_enter_prompt_choice = clampi(index, 0, n - 1)
	_sync_enter_prompt_style()


func _shop_choice_keys() -> String:
	## Vendor prompts that use the shared dialogue choice-button row.
	if _talk_stage != 10 or _shop == null:
		return ""
	if int(_shop.mode) != _VendorShop.Mode.CHOICE:
		return ""
	if bool(_shop.is_sell_letter_pick()):
		return ""
	var keys := str(_shop.choice_keys).to_lower().strip_edges()
	if keys == "ny":
		return "yn"
	if keys == "sb":
		return "bs"
	## Yes/No, Buy/Sell, Minoc inn beds 1/2/3, healer A/B/C services.
	if keys == "yn" or keys == "bs" or keys == "123" or keys == "abc":
		return keys
	## Healer "Who is in need?" — one digit per living party member.
	if keys.length() >= 1 and keys.length() <= 8:
		var all_digits := true
		for i in keys.length():
			var ch := keys.unicode_at(i)
			if ch < 49 or ch > 56: ## '1'..'8'
				all_digits = false
				break
		if all_digits:
			return keys
	return ""


func _talk_gamepad_yes_no_active() -> bool:
	## NPC follow-up Y/N (gamepad keyword talks) + Lord British "Art thou well?".
	if _talk_stage == 13:
		return true
	return _talk_keyword_menu_active and _talk_stage == 3


func _prompt_choice_keys() -> String:
	if _combat_exit_prompt:
		return "yn"
	if _enter_prompt_stage == 1:
		return "yn"
	if _talk_gamepad_yes_no_active():
		return "yn"
	return _shop_choice_keys()


func _binary_prompt_active() -> bool:
	return not _prompt_choice_keys().is_empty()


func _prompt_choice_label(key: String) -> String:
	## Healer service row (A/B/C) — not Buy/Sell letter keys.
	if _shop_choice_keys() == "abc":
		match key:
			"a":
				return Locale.t("shop_heal_cure")
			"b":
				return Locale.t("shop_heal_heal")
			"c":
				return Locale.t("shop_heal_resurrect")
	match key:
		"y":
			return Locale.t("cmd_yes")
		"n":
			return Locale.t("cmd_no")
		"b":
			return Locale.t("cmd_buy")
		"s":
			return Locale.t("cmd_sell")
		_:
			return key.to_upper()


func _resolve_prompt_choice_index(index: int) -> void:
	var keys := _prompt_choice_keys()
	if keys.is_empty():
		return
	var frame := Engine.get_process_frames()
	if _choice_resolved_frame == frame:
		return
	_choice_resolved_frame = frame
	index = clampi(index, 0, keys.length() - 1)
	var ch := keys.substr(index, 1)
	if _combat_exit_prompt:
		_resolve_combat_exit_prompt(ch == "y")
		return
	if _enter_prompt_stage == 1:
		_resolve_enter_prompt(ch == "y")
		return
	if _talk_stage == 13:
		var lb_answer := Locale.t("cmd_yes" if ch == "y" else "cmd_no")
		_talk_buffer = ""
		_reset_talk_hangul()
		_push_talk_player_input(lb_answer)
		_talk_answer_lb_heal_yn(ch == "y")
		return
	if _talk_gamepad_yes_no_active():
		var answer := Locale.t("cmd_yes" if ch == "y" else "cmd_no")
		_talk_buffer = ""
		_reset_talk_hangul()
		_push_talk_player_input(answer)
		_talk_answer_yn(ch == "y")
		return
	if _shop == null or _shop_choice_keys().is_empty():
		return
	_talk_buffer = ""
	_reset_talk_hangul()
	_push_talk_player_input(_prompt_choice_label(ch))
	_shop.submit_choice(ch)
	_flush_shop_output()


func _resolve_visible_yes_no_choice(left: bool) -> void:
	## Compatibility: left button ≈ first key (Yes / Buy).
	_resolve_prompt_choice_index(0 if left else 1)


func _sync_enter_prompt_style() -> void:
	var keys := _prompt_choice_keys()
	var n := keys.length()
	for i in _choice_btns.size():
		var btn := _choice_btns[i]
		if btn == null:
			continue
		var active := i < n and i == _enter_prompt_choice
		UiTheme.style_choice_button(btn, active)
		## Global menu buttons have 10 px vertical padding and an 18 px font.
		## The terminal prompt is only one text row tall, so use compact copies.
		btn.add_theme_font_size_override("font_size", 11)
		for style_name in ["normal", "hover", "pressed", "focus"]:
			var style := btn.get_theme_stylebox(style_name).duplicate() as StyleBoxFlat
			if style == null:
				continue
			style.content_margin_left = 8
			style.content_margin_right = 8
			style.content_margin_top = 1
			style.content_margin_bottom = 1
			btn.add_theme_stylebox_override(style_name, style)


func _talk_ime_stage_active() -> bool:
	## OS IME is retained only as a development fallback when the native
	## libhangul extension is missing (or for non-Korean UI languages).
	return _talk_text_stage_active() and not _talk_native_hangul_active()


func _talk_text_stage_active() -> bool:
	if _talk_stage == 10 and _shop != null:
		## Tavern topic after an ale tip is free text inside the vendor session.
		return int(_shop.mode) == _VendorShop.Mode.TEXT
	return _talk_stage in [1, 3, 11, 12, 13]


func _ensure_talk_hangul() -> void:
	if _talk_hangul != null or not ClassDB.class_exists("HangulComposer"):
		return
	_talk_hangul = ClassDB.instantiate("HangulComposer") as RefCounted
	if _talk_hangul != null:
		_talk_hangul.call("set_keyboard", HangulInputSettings.layout_id())


func _talk_native_hangul_active() -> bool:
	if str(GameState.language) != "ko" or not _talk_text_stage_active():
		return false
	_ensure_talk_hangul()
	return _talk_hangul != null


func _reset_talk_hangul() -> void:
	_talk_hangul_preedit = ""
	if _talk_hangul != null:
		_talk_hangul.call("reset")
		_talk_hangul.call("set_keyboard", HangulInputSettings.layout_id())


func _talk_input_mode_marker() -> String:
	return "[한] " if HangulInputSettings.is_korean_mode() else "[A] "


func _talk_ime_max_length() -> int:
	if (
		_talk_stage == 10
		and _shop != null
		and int(_shop.mode) == _VendorShop.Mode.TEXT
	):
		return 16
	match _talk_stage:
		3, 13:
			return 8
		_:
			return 24 if str(GameState.language) == "ko" else 16


func _sync_talk_ime_edit() -> void:
	if _talk_edit == null:
		return
	if not _talk_ime_stage_active():
		if _talk_edit.has_focus():
			_talk_edit.release_focus()
		return
	_talk_edit.max_length = _talk_ime_max_length()
	if _talk_edit.text != _talk_buffer:
		_talk_edit_syncing = true
		_talk_edit.text = _talk_buffer
		_talk_edit.caret_column = _talk_edit.text.length()
		_talk_edit_syncing = false
	if not _talk_edit.has_focus():
		_talk_edit.grab_focus()
	if not _talk_edit.is_editing():
		_talk_edit.edit()


func _on_talk_ime_text_changed(text: String) -> void:
	if _talk_edit_syncing or not _talk_ime_stage_active():
		return
	_talk_buffer = text
	## LineEdit draws text, preedit underline and caret itself. Do not relayout
	## or rewrite it during composition; that can restart the platform IME.


func _on_talk_ime_text_submitted(text: String) -> void:
	if not _talk_ime_stage_active():
		return
	_talk_buffer = text
	## Reuse the existing stage handlers so history and dialogue behavior remain
	## exactly the same; the focused LineEdit has already consumed the real Enter.
	var enter := InputEventKey.new()
	enter.pressed = true
	enter.keycode = KEY_ENTER
	_handle_talk_input(enter)

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
			## Talk keeps the tall message strip even when inventory sides close.
			var msg_to: float = bot_open_h if _talk_msg_open else bot_closed_h
			_side_tween.tween_method(_tween_msg_height, msg_from, msg_to, SIDE_TWEEN_SEC) \
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
		## Talk grows the message strip; character roster uses order-peek if sides closed.
		_msg_h = bot_open_h if (_sides_open or _talk_msg_open) else bot_closed_h
		_apply_msg_geometry()
		_refresh_message_view()
		if _compact_pane:
			_compact_pane.visible = not roster_open
			_compact_pane.modulate.a = 1.0
	if _ztats_stage == 2 or not _shop_inv_kind.is_empty():
		if _right_top:
			_right_top.visible = true
		if _compact_pane:
			_compact_pane.visible = false
		if _roster:
			_roster.visible = false
		if _ztats_panel and (_ztats_stage == 2 or not _shop_inv_kind.is_empty()):
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
		## Keep tall message log while Talk owns the strip.
		if _talk_msg_open:
			_msg_h = _msg_full_h if _msg_full_h > 8.0 else floorf(_side_geom()["bottom_open_h"])
		else:
			_msg_h = floorf(_side_geom()["bottom_closed_h"])
		_apply_msg_geometry()
		_refresh_message_view()


func _on_sides_opened() -> void:
	if _sides_open and _compact_pane:
		_compact_pane.visible = false
	_msg_h = _msg_full_h
	_apply_msg_geometry()
	_refresh_message_view()
	if _journal_focus_active and _journal_panel != null and _journal_panel.has_method("recenter_selection"):
		_journal_panel.recenter_selection()


func _await_side_tween() -> void:
	## Wait out an in-flight side-panel open/close tween (if any).
	if _side_tween != null and is_instance_valid(_side_tween) and _side_tween.is_running():
		await _side_tween.finished


func _open_sides_for_combat(await_done: bool = true) -> void:
	## Open left/right panels for combat. Optionally wait out the tween.
	## Enter-combat path starts this in parallel with the map wipe (no await).
	_combat_saved_sides_open = _sides_open
	_order_opened_roster = false
	var need_anim := not _sides_open
	_sides_open = true
	if need_anim:
		_refresh_party()
		_layout_side_panels(true)
		if await_done:
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


func _toggle_left_panel_during_talk() -> void:
	## Talk keeps the character roster + tall message. Tab only shows/hides inventory.
	## `_sides_open` still records the post-talk panel preference.
	if _left_pane == null:
		return
	_cancel_order_roster_close()
	if not _sides_open:
		_sides_open = true
		_order_opened_roster = false
		_refresh_party()
		_animate_left_panel_only(true)
	else:
		_sides_open = false
		## Inventory out; keep talk character panel + log while dialogue continues.
		if not _order_opened_roster:
			_order_opened_roster = true
		if not _talk_msg_open:
			_talk_msg_open = true
		_refresh_party()
		_animate_left_panel_only(false)
		if _right_top:
			_right_top.visible = true
		if _compact_pane:
			_compact_pane.visible = false
		if _roster:
			_roster.visible = true
		## Don't collapse the tall log when the left side leaves.
		if _msg_full_h > 8.0:
			_msg_h = _msg_full_h
			_apply_msg_geometry()
			_refresh_message_view()


func _animate_left_panel_only(open: bool, restore_compact: bool = false) -> void:
	if _left_pane == null or _map_pane == null:
		return
	var g := _side_geom()
	var lw: float = g["left_w"]
	var ph: float = g["pane_h"]
	var target_x: float = g["left_open_x"] if open else g["left_closed_x"]
	_left_pane.custom_minimum_size = Vector2(lw, ph)
	_left_pane.size = Vector2(lw, ph)
	_left_pane.visible = true
	if open and _compact_pane:
		_compact_pane.visible = false
	if not is_inside_tree():
		_left_pane.position = Vector2(target_x, 0.0)
		if not open:
			_left_pane.visible = false
			if restore_compact and _compact_pane and not _sides_open and not _order_opened_roster:
				_compact_pane.visible = true
				_compact_pane.modulate.a = 1.0
		return
	if _side_tween != null and is_instance_valid(_side_tween):
		_side_tween.kill()
	_side_tween = create_tween()
	_side_tween.tween_property(_left_pane, "position", Vector2(target_x, 0.0), SIDE_TWEEN_SEC) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not open:
		_side_tween.chain().tween_callback(func() -> void:
			if not _sides_open and _left_pane:
				_left_pane.visible = false
			if restore_compact and _compact_pane and not _sides_open and not _order_opened_roster:
				_compact_pane.visible = true
				_compact_pane.modulate.a = 1.0
		)


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
	if _moongate_busy or _cannon_busy or _search_busy or _death_busy or _shrine_busy:
		return
	## Combat arena: no world cruise / auto-pass.
	## Aim + victory free-roam poll held dirs (walk cadence). Turn move stays
	## one-step-per-tilt so holding a stick doesn't burn the whole party.
	if _combat_active:
		_move_cd = maxf(0.0, _move_cd - delta)
		_hold_arm = maxf(0.0, _hold_arm - delta)
		if _ztats_stage == 1 or _ready_stage == 1 or _chest_open_stage == 1:
			_tick_select_cursor()
		elif _ready_stage == 2:
			_tick_ready_weapon_cursor()
		elif _combat_aiming:
			_tick_combat_aim_move()
		elif _combat_victory_aftermath and not _combat_exit_prompt:
			_tick_combat_victory_move()
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
	if _shrine_stage != 0:
		return
	## xu4 InnController — sleep timer while avatar shows corpse/lying tile.
	if _inn_stage == 1:
		_tick_inn_rest(delta)
		return
	## All asleep: Zzzzzz auto-turns own the clock — no player move/cruise.
	if _is_party_asleep_locked():
		return
	## Z/N/R/W/M pick lists: same hold timing as world move; wrap at ends.
	if _journal_focus_active:
		_tick_journal_browse_nav()
		return
	if _ztats_stage == 1 or _order_stage != 0 or _ready_stage == 1 or _wear_stage == 1 or _mix_stage == 1 or _mix_stage == 2 or _use_stage == 1 or _camp_stage == 3 or _chest_open_stage == 1 or _save_stage == 1 or _save_stage == 2 or _esc_menu_is_open() or _options_panel_is_open():
		_tick_select_cursor()
		return
	## Shop lists / inn 1–3 / Y/N / B/S: hold-repeat like Ztats (polled, not echo).
	if _dialogue_choice_hold_active():
		_tick_dialogue_choice_nav()
		return
	if _talk_stage != 0:
		return
	if _ready_stage == 2:
		_tick_ready_weapon_cursor()
		return
	if _wear_stage == 2:
		_tick_wear_armor_cursor()
		return
	if _ztats_stage != 0 or _mix_stage != 0 or _use_stage != 0 or _camp_stage != 0 or _shrine_stage != 0 or _inn_stage != 0 or _chest_open_stage != 0 or _telescope_stage != 0 or _save_stage != 0 or _talk_stage != 0 or _enter_prompt_stage != 0 or _command_menu_open or _city_warp_open or _journal_focus_active or _esc_menu_is_open() or _options_panel_is_open():
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

	## xu4 balloon: keys always "Drift Only!" (real movement is wind while aloft).
	if _transport == Transport.BALLOON:
		_push_message(Locale.t("cmd_drift_only"), false)
		_finish_party_turn()
		_arm_hold_after_step(true)
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
	_maybe_offer_enter_prompt()


func _terrain_tid_at(pos: Vector2i) -> int:
	## Destination terrain for slowedByTile (annotations count like xu4 tileTypeAt).
	if _is_in_city() and _city_map != null and _city_map.loaded:
		return int(_city_map.effective_tile_at(pos.x, pos.y))
	return _effective_world_tid(pos)


func _apply_world_step(next: Vector2i, dir: Vector2i, with_message: bool = true) -> void:
	_tile_pos = next
	_clear_enter_prompt_decline_if_left()
	_update_transport_facing(dir)
	if _map != null:
		_map.set_center(_tile_pos)
	_refresh_locate_hud()
	_play_transport_step_sfx()
	if with_message:
		_push_move_message(dir)
	## xu4: south toward Shrine of Humility — daemons unless Horn aura active.
	if not _is_in_city() and _world_creatures != null:
		if _world_creatures.try_humility_daemon_ambush(dir, _tile_pos) > 0:
			_sync_creatures_to_map()


func _play_transport_step_sfx() -> void:
	## One clip per successful tile step (gallop plays twice on a 2-tile move).
	match _transport:
		Transport.FOOT:
			AudioSfx.play_foot_step(_terrain_tid_at(_tile_pos), _is_in_city())
		Transport.HORSE:
			AudioSfx.play_horse_step()
		_:
			pass


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


func _dialogue_choice_hold_active() -> bool:
	## Talk keyword list, shop rows, sell letter pick, or horizontal choice buttons.
	if _talk_keyword_menu_can_select():
		return true
	if _talk_stage == 10 and _shop != null:
		if not _shop_item_menu_items.is_empty():
			return true
		if (
			bool(_shop.is_sell_letter_pick())
			and _ztats_panel != null
			and _ztats_panel.has_shop_pick()
		):
			return true
	## Enter / shop Y/N·B/S·1–3 / talk gamepad Y/N (combat exit stays one-shot).
	if _combat_exit_prompt:
		return false
	return _binary_prompt_active()


func _tick_dialogue_choice_nav() -> void:
	## Hold-repeat for dialogue choice UIs (same cadence as Ztats / Ready lists).
	var step_x := 0
	var step_y := 0
	var vertical := false
	if _talk_keyword_menu_can_select():
		step_y = _read_select_step()
		vertical = true
		if _talk_keyword_menu_await_neutral:
			if step_y == 0:
				_talk_keyword_menu_await_neutral = false
			else:
				_reset_hold_state()
				return
	elif _talk_stage == 10 and _shop != null and not _shop_item_menu_items.is_empty():
		step_y = _read_select_step()
		vertical = true
	elif (
		_talk_stage == 10
		and _shop != null
		and bool(_shop.is_sell_letter_pick())
		and _ztats_panel != null
		and _ztats_panel.has_shop_pick()
	):
		step_y = _read_select_step()
		vertical = true
	else:
		step_x = _GameInput.read_select_step_x()
	var step := step_y if vertical else step_x
	if step == 0:
		_reset_hold_state()
		return
	var held := Vector2i(step_x, step_y)
	if held != _held_dir:
		_held_dir = held
		_move_repeating = false
		_hold_arm = 0.0
	if _move_cd > 0.0:
		return
	if _move_repeating and _hold_arm > 0.0:
		return
	if vertical:
		if _talk_keyword_menu_can_select():
			_move_talk_keyword_menu_cursor(step)
		elif not _shop_item_menu_items.is_empty():
			_move_shop_item_menu_cursor(step)
		elif _ztats_panel != null:
			_ztats_panel.shop_pick_nudge(step)
	else:
		_set_enter_prompt_choice(_enter_prompt_choice + step)
	_arm_hold_after_step()


func _read_select_step() -> int:
	## -1 = up, +1 = down, 0 = none (vertical only).
	return _GameInput.read_select_step()


func _read_move_dir() -> Vector2i:
	return _GameInput.read_move_dir()


func _is_cancel_event(event: InputEvent) -> bool:
	return _GameInput.is_cancel(event)


func _clear_pending_dir(allow_move: bool = true) -> void:
	if _pending_cmd == U4Commands.Id.TALK:
		_talk_gamepad_requested = false
	_pending_cmd = U4Commands.Id.NONE
	_pending_cmd_name = ""
	## Cancel → allow move. Successful Dir? keeps the press blocked in finish.
	if allow_move:
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


func _command_menu_cardinal_dirs() -> Array[Vector2i]:
	return [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
	]


func _command_menu_has_adjacent_world_enemy() -> bool:
	if _world_creatures == null:
		return false
	for dir in _command_menu_cardinal_dirs():
		var pos := Vector2i(
			posmod(_tile_pos.x + dir.x, WorldMapData.WIDTH),
			posmod(_tile_pos.y + dir.y, WorldMapData.HEIGHT)
		)
		if _world_creatures.creature_at(pos) >= 0:
			return true
	return false


func _command_menu_has_adjacent_city_person(allow_talk_over: bool = false) -> bool:
	## When allow_talk_over is true, match _do_talk reach: vendors one step
	## past a shop-counter letter tile (xu4 canTalkOver) also count.
	if not _is_in_city() or _city_map == null or not _city_map.loaded:
		return false
	var max_dist := 2 if allow_talk_over else 1
	for dir in _command_menu_cardinal_dirs():
		for dist in range(1, max_dist + 1):
			var pos := Vector2i(_tile_pos.x + dir.x * dist, _tile_pos.y + dir.y * dist)
			if (
				pos.x < 0 or pos.y < 0
				or pos.x >= _CityMapData.WIDTH
				or pos.y >= _CityMapData.HEIGHT
			):
				break
			var pi: int = int(_city_map.person_index_at(pos.x, pos.y))
			if pi >= 0 and (not allow_talk_over or _talk_can_address(pi, dist)):
				return true
			if not allow_talk_over:
				break
			## After this cell: only continue past talk-over counter tiles.
			var cell_tid: int
			if pi >= 0:
				cell_tid = int(_city_map.persons[pi].z)
			else:
				cell_tid = int(_city_map.effective_tile_at(pos.x, pos.y))
			if not _TileRules.can_talk_over(cell_tid):
				break
	return false


func _command_menu_has_adjacent_city_tile(kind: String) -> bool:
	if not _is_in_city() or _city_map == null:
		return false
	for dir in _command_menu_cardinal_dirs():
		var pos := _tile_pos + dir
		if (
			pos.x < 0 or pos.y < 0
			or pos.x >= _CityMapData.WIDTH or pos.y >= _CityMapData.HEIGHT
		):
			continue
		var tid := int(_city_map.effective_tile_at(pos.x, pos.y))
		if kind == "chest" and _TileRules.is_chest(tid):
			return true
		if kind == "locked_door" and _TileRules.is_locked_door(tid):
			return true
		if kind == "door" and _TileRules.is_door(tid):
			return true
	return false


func _command_menu_has_adjacent_city_chest(opened: bool) -> bool:
	if not _is_in_city() or _city_map == null:
		return false
	for dir in _command_menu_cardinal_dirs():
		var pos := _tile_pos + dir
		if (
			pos.x < 0 or pos.y < 0
			or pos.x >= _CityMapData.WIDTH or pos.y >= _CityMapData.HEIGHT
		):
			continue
		## A person visually/physically owns the cell; do not expose the
		## chest underneath until that NPC moves away.
		if _city_map.person_index_at(pos.x, pos.y) >= 0:
			continue
		var tid := int(_city_map.effective_tile_at(pos.x, pos.y))
		if not _TileRules.is_chest(tid):
			continue
		var is_open := bool(_city_map.is_chest_open(pos.x, pos.y))
		if is_open != opened:
			continue
		if opened and not bool(_city_map.chest_has_loot(pos.x, pos.y)):
			continue
		return true
	return false


func _command_menu_has_adjacent_combat_chest(opened: bool) -> bool:
	## Victory aftermath / arena — chests around the focused party unit.
	if _map == null or not _map.is_in_combat():
		return false
	var from := _map.get_combat_focus_pos()
	if from.x < 0:
		return false
	for dir in _command_menu_cardinal_dirs():
		var pos := from + dir
		if (
			pos.x < 0 or pos.y < 0
			or pos.x >= _CombatMapData.WIDTH or pos.y >= _CombatMapData.HEIGHT
		):
			continue
		if not _map.has_combat_chest_at(pos):
			continue
		var is_open := bool(_map.combat_chest_is_open(pos))
		if is_open != opened:
			continue
		if opened and not bool(_map.combat_chest_has_loot(pos)):
			continue
		return true
	return false


func _command_menu_on_city_portal(action: int) -> bool:
	if not _is_in_city() or _city_map == null or not _city_map.loaded:
		return false
	var fname := str(_city_map.source_path).get_file()
	return not _CityFloorPortals.portal_at(fname, _tile_pos, action).is_empty()


func _command_menu_can_show(cmd: int) -> bool:
	var in_combat := _combat_active
	var in_city := _is_in_city() and not in_combat
	var outdoors := not in_city and not in_combat
	var noncombat := not in_combat
	if _combat_victory_aftermath:
		return cmd in [
			U4Commands.Id.CAST,
			U4Commands.Id.GET_CHEST,
			U4Commands.Id.OPEN,
			U4Commands.Id.READY,
			U4Commands.Id.USE,
			U4Commands.Id.ZTATS,
		]
	## Keep the gamepad palette aligned with commands accepted by combat input.
	## Volume remains hidden while it is only a stub.
	if in_combat:
		return U4Commands.allowed_in_combat(cmd) and cmd != U4Commands.Id.VOLUME
	match cmd:
		U4Commands.Id.ATTACK:
			if in_city:
				return _city_guards_alerted and _command_menu_has_adjacent_city_person()
			return _command_menu_has_adjacent_world_enemy()
		U4Commands.Id.BOARD:
			if not outdoors or _transport != Transport.FOOT or _map == null:
				return false
			var board_tid := _map.overlay_at(_tile_pos)
			return (
				MapView.is_ship_tile(board_tid)
				or MapView.is_horse_tile(board_tid)
				or MapView.is_balloon_tile(board_tid)
			)
		U4Commands.Id.CAST, U4Commands.Id.READY, U4Commands.Id.USE, U4Commands.Id.ZTATS:
			return true
		U4Commands.Id.DESCEND:
			return noncombat and _command_menu_on_city_portal(_CityFloorPortals.Action.DESCEND)
		U4Commands.Id.ENTER:
			if not outdoors or _transport in [Transport.SHIP, Transport.BALLOON]:
				return false
			return (
				not _WorldPortals.portal_at(_tile_pos).is_empty()
				or not _ShrinePortals.portal_at(_tile_pos).is_empty()
			)
		U4Commands.Id.FIRE:
			return outdoors and _transport == Transport.SHIP
		U4Commands.Id.GET_CHEST:
			return noncombat and _command_menu_has_adjacent_city_chest(true)
		U4Commands.Id.HOLE_UP:
			return outdoors and _hole_up_deny_message().is_empty()
		U4Commands.Id.IGNITE:
			return false ## Dungeon controller is not implemented yet.
		U4Commands.Id.JIMMY:
			return noncombat and _command_menu_has_adjacent_city_tile("locked_door")
		U4Commands.Id.KLIMB:
			return noncombat and _command_menu_on_city_portal(_CityFloorPortals.Action.CLIMB)
		U4Commands.Id.LOCATE:
			return outdoors and GameState.has_sextant
		U4Commands.Id.MIX:
			return noncombat and GameState.has_any_reagents()
		U4Commands.Id.NEW_ORDER, U4Commands.Id.QUIT_SAVE, U4Commands.Id.SEARCH, U4Commands.Id.WEAR:
			return noncombat
		U4Commands.Id.OPEN:
			return (
				noncombat
				and (
					_command_menu_has_adjacent_city_tile("door")
					or _command_menu_has_adjacent_city_chest(false)
				)
			)
		U4Commands.Id.PEER:
			return outdoors and GameState.gems > 0
		U4Commands.Id.TALK:
			return noncombat and _command_menu_has_adjacent_city_person(true)
		U4Commands.Id.VOLUME:
			return false ## V remains intentionally unimplemented.
		U4Commands.Id.XIT:
			return (
				noncombat and _transport != Transport.FOOT
				and not (_transport == Transport.BALLOON and _balloon_flying)
			)
		U4Commands.Id.YELL:
			return noncombat and _transport in [Transport.SHIP, Transport.HORSE]
		_:
			return false


func _build_command_menu_items() -> Array[int]:
	var items: Array[int] = []
	for cmd in range(U4Commands.Id.ATTACK, U4Commands.Id.ZTATS + 1):
		if _command_menu_can_show(cmd):
			items.append(cmd)
	return items


func _command_menu_has_world_enemy_on_screen() -> bool:
	if _is_in_city() or _combat_active or _world_creatures == null:
		return false
	var half_x := MapView.VIEW_W / 2
	var half_y := MapView.VIEW_H / 2
	for creature in _world_creatures.creatures:
		var pos := Vector2i(
			int(creature.get("x", -99999)),
			int(creature.get("y", -99999))
		)
		var delta: Vector2i = _WorldCreaturesScript.wrap_delta(_tile_pos, pos)
		if absi(delta.x) <= half_x and absi(delta.y) <= half_y:
			return true
	return false


func _command_menu_ship_touches_land() -> bool:
	if (
		_transport != Transport.SHIP or _is_in_city() or _combat_active
		or _world == null or not _world.loaded
	):
		return false
	for dir in _command_menu_cardinal_dirs():
		var pos := Vector2i(
			posmod(_tile_pos.x + dir.x, WorldMapData.WIDTH),
			posmod(_tile_pos.y + dir.y, WorldMapData.HEIGHT)
		)
		if not _TileRules.is_sailable(_effective_world_tid(pos)):
			return true
	return false


func _command_menu_default_cmd(items: Array[int]) -> int:
	if items.is_empty():
		return U4Commands.Id.NONE
	if _combat_active:
		## After Victory!: prefer Open (closed) / Get (open+loot) beside the unit.
		if _combat_victory_aftermath:
			if (
				items.has(U4Commands.Id.OPEN)
				and _command_menu_has_adjacent_combat_chest(false)
			):
				return U4Commands.Id.OPEN
			if (
				items.has(U4Commands.Id.GET_CHEST)
				and _command_menu_has_adjacent_combat_chest(true)
			):
				return U4Commands.Id.GET_CHEST
			if items.has(_command_menu_last_cmd):
				return _command_menu_last_cmd
			return items[0]
		## Attack is the common combat action; ranged attacks must remain available
		## even without an adjacent foe.
		if items.has(U4Commands.Id.ATTACK):
			return U4Commands.Id.ATTACK
		return items[0]
	## Context priority is intentionally ordered to match the gamepad UX spec.
	var priority: Array[int] = []
	if _command_menu_can_show(U4Commands.Id.TALK):
		priority.append(U4Commands.Id.TALK)
	if _command_menu_can_show(U4Commands.Id.OPEN):
		priority.append(U4Commands.Id.OPEN)
	if _command_menu_can_show(U4Commands.Id.GET_CHEST):
		priority.append(U4Commands.Id.GET_CHEST)
	if _command_menu_can_show(U4Commands.Id.JIMMY):
		priority.append(U4Commands.Id.JIMMY)
	if _command_menu_can_show(U4Commands.Id.ATTACK):
		priority.append(U4Commands.Id.ATTACK)
	if _command_menu_can_show(U4Commands.Id.BOARD):
		priority.append(U4Commands.Id.BOARD)
	if _command_menu_can_show(U4Commands.Id.DESCEND):
		priority.append(U4Commands.Id.DESCEND)
	if _command_menu_can_show(U4Commands.Id.KLIMB):
		priority.append(U4Commands.Id.KLIMB)
	if _command_menu_can_show(U4Commands.Id.ENTER):
		priority.append(U4Commands.Id.ENTER)
	if (
		items.has(U4Commands.Id.XIT)
		and _command_menu_ship_touches_land()
	):
		priority.append(U4Commands.Id.XIT)
	var enemy_on_screen := _command_menu_has_world_enemy_on_screen()
	if (
		items.has(U4Commands.Id.YELL)
		and _transport == Transport.SHIP
		and _TileRules.is_sailable(_effective_world_tid(_tile_pos))
		and not enemy_on_screen
	):
		priority.append(U4Commands.Id.YELL)
	if items.has(U4Commands.Id.FIRE) and enemy_on_screen:
		priority.append(U4Commands.Id.FIRE)
	if items.has(U4Commands.Id.XIT) and _transport == Transport.HORSE:
		priority.append(U4Commands.Id.XIT)
	for cmd in priority:
		if items.has(cmd):
			return cmd
	if items.has(_command_menu_last_cmd):
		return _command_menu_last_cmd
	return items[0]


func _can_open_command_menu() -> bool:
	if _command_menu_open or _city_warp_open or _journal_focus_active or _enter_prompt_stage != 0:
		return false
	if (
		_death_busy or _moongate_busy or _cannon_busy or _search_busy
		or _shrine_busy or _shrine_stage != 0 or _inn_stage != 0
	):
		return false
	if (
		_talk_stage != 0 or _mix_stage != 0 or _save_stage != 0
		or _camp_stage != 0 or _chest_open_stage != 0 or _telescope_stage != 0
		or _ready_stage != 0 or _wear_stage != 0 or _use_stage != 0
		or _ztats_stage != 0 or _order_stage != 0
		or _pending_cmd != U4Commands.Id.NONE or _ship_yell_await_dir
		or _esc_menu_is_open() or _options_panel_is_open()
	):
		return false
	if _peer_overlay != null and _peer_overlay.is_open():
		return false
	if _combat_active and (_combat_resolving or _combat_aiming or _combat_exit_prompt):
		return false
	return true


func _open_command_menu() -> void:
	if not _can_open_command_menu():
		return
	_command_menu_items = _build_command_menu_items()
	if _command_menu_items.is_empty():
		return
	_command_menu_open = true
	var default_cmd := _command_menu_default_cmd(_command_menu_items)
	_command_menu_cursor = _command_menu_items.find(default_cmd)
	if _command_menu_cursor < 0:
		_command_menu_cursor = 0
	_GameInput.reset_stick_navigation()
	_reset_hold_state()
	_block_dir_until_keyup = true
	_rebuild_command_menu_rows()
	if _command_menu_layer != null:
		_command_menu_layer.visible = true
		_command_menu_layer.move_to_front()
	_layout_command_menu_layer()


func _close_command_menu() -> void:
	if not _command_menu_open:
		return
	if (
		not _command_menu_items.is_empty()
		and _command_menu_cursor >= 0
		and _command_menu_cursor < _command_menu_items.size()
	):
		_command_menu_last_cmd = _command_menu_items[_command_menu_cursor]
	_command_menu_open = false
	if _command_menu_layer != null:
		_command_menu_layer.visible = false
	_command_menu_items.clear()
	_command_menu_cursor = 0
	_reset_hold_state()
	_block_dir_until_keyup = true
	grab_focus()


func _move_command_menu_cursor(step: int) -> void:
	if _command_menu_items.is_empty() or step == 0:
		return
	_command_menu_cursor = posmod(
		_command_menu_cursor + step,
		_command_menu_items.size()
	)
	_layout_command_menu_layer()


func _choose_command_menu_item(from_gamepad: bool = false) -> void:
	if (
		not _command_menu_open or _command_menu_items.is_empty()
		or _command_menu_cursor < 0
		or _command_menu_cursor >= _command_menu_items.size()
	):
		return
	var cmd := _command_menu_items[_command_menu_cursor]
	_talk_gamepad_requested = cmd == U4Commands.Id.TALK and from_gamepad
	_mix_gamepad_requested = cmd == U4Commands.Id.MIX and from_gamepad
	var needs_dir := bool(U4Commands.NEEDS_DIRECTION.get(cmd, false))
	_close_command_menu()
	if needs_dir:
		## Do not reuse the D-pad direction that moved the menu cursor.
		_block_dir_until_keyup = true
	if _combat_active:
		if _combat_victory_aftermath:
			_handle_combat_victory_command(cmd)
		else:
			_handle_combat_command(cmd)
	else:
		_handle_command(cmd)


func _handle_command_menu_input(event: InputEvent) -> bool:
	if not _command_menu_open:
		return false
	if event is InputEventJoypadMotion:
		## Neutral motion must reach the hysteresis helper so it can re-arm.
		## Consume all other stick axes while the palette owns input.
		var stick_step := _GameInput.stick_axis_step(event, JOY_AXIS_LEFT_Y)
		if stick_step != 0:
			_move_command_menu_cursor(stick_step)
		return true
	if not event.is_pressed() or event.is_echo():
		return false
	if _is_cancel_event(event):
		_close_command_menu()
		return true
	if event is InputEventKey:
		var keyed_cmd := U4Commands.from_event(event as InputEventKey)
		var keyed_index := _command_menu_items.find(keyed_cmd)
		if keyed_index >= 0:
			_command_menu_cursor = keyed_index
			_choose_command_menu_item(false)
			return true
	if _GameInput.is_select(event) or event.is_action_pressed("confirm"):
		_choose_command_menu_item(event is InputEventJoypadButton)
		return true
	var step := 0
	var dir := _GameInput.dir_from_event(event)
	if dir.y != 0:
		step = dir.y
	if step != 0:
		_move_command_menu_cursor(step)
	return true


func _talk_keyword_stable_key(word: String) -> String:
	var builtin := _TalkLocale.match_builtin_interest(word)
	if not builtin.is_empty():
		return builtin
	return _TalkLocale.normalize_interest(word)


func _hawkwind_keyword_menu_items() -> Array[Dictionary]:
	## Seer counsel is virtue-only; expose all eight paths immediately
	## (keyboard can always type them — the gamepad menu should match).
	var korean := GameState.lang_short() == "ko"
	var lang := "ko" if korean else "en"
	var items: Array[Dictionary] = []
	for v in range(8):
		var word := Virtues.name_of(v, lang)
		items.append({
			"key": "virtue_%d" % v,
			"label": word,
			"input": word,
			"revealed": true,
		})
	if korean:
		items.append({"key": "bye", "label": "안녕", "input": "안녕", "revealed": true})
	else:
		items.append({"key": "bye", "label": "Bye", "input": "bye", "revealed": true})
	return items


func _lord_british_keyword_menu_items() -> Array[Dictionary]:
	## LB has no beggar Give; heal is the classic HEAL keyword (not town Health).
	if GameState.lang_short() == "ko":
		return [
			{"key": "look", "label": "모습", "input": "모습", "revealed": true},
			{"key": "name", "label": "이름", "input": "이름", "revealed": true},
			{"key": "job", "label": "직업", "input": "직업", "revealed": true},
			{"key": "heal", "label": "치유", "input": "치유", "revealed": true},
			{"key": "help", "label": "도움", "input": "도움", "revealed": true},
			{"key": "bye", "label": "안녕", "input": "안녕", "revealed": true},
		]
	return [
		{"key": "look", "label": "Look", "input": "look", "revealed": true},
		{"key": "name", "label": "Name", "input": "name", "revealed": true},
		{"key": "job", "label": "Job", "input": "job", "revealed": true},
		{"key": "heal", "label": "Heal", "input": "heal", "revealed": true},
		{"key": "help", "label": "Help", "input": "help", "revealed": true},
		{"key": "bye", "label": "Bye", "input": "bye", "revealed": true},
	]


func _talk_keyword_menu_initial_items() -> Array[Dictionary]:
	if _talk_is_hawkwind:
		return _hawkwind_keyword_menu_items()
	if _talk_is_lb:
		return _lord_british_keyword_menu_items()
	if GameState.lang_short() == "ko":
		return [
			{"key": "look", "label": "모습", "input": "모습", "revealed": true},
			{"key": "name", "label": "이름", "input": "이름", "revealed": true},
			{"key": "job", "label": "직업", "input": "직업", "revealed": true},
			{"key": "heal", "label": "건강", "input": "건강", "revealed": true},
			{"key": "give", "label": "기부", "input": "기부", "revealed": true},
			{"key": "bye", "label": "안녕", "input": "안녕", "revealed": true},
		]
	return [
		{"key": "look", "label": "Look", "input": "look", "revealed": true},
		{"key": "name", "label": "Name", "input": "name", "revealed": true},
		{"key": "job", "label": "Job", "input": "job", "revealed": true},
		{"key": "heal", "label": "Health", "input": "health", "revealed": true},
		{"key": "give", "label": "Donate", "input": "give", "revealed": true},
		{"key": "bye", "label": "Bye", "input": "bye", "revealed": true},
	]


func _talk_keyword_visible_count() -> int:
	return mini(MSG_OPEN_LINES, _talk_keyword_menu_items.size())


func _sync_talk_keyword_menu_scroll() -> void:
	## Prefer the focused keyword on the middle row (8 of 15). Near the start
	## the window stays pinned to the top; near the end it pins to the bottom.
	## Wrapping past the last item returns to the first row and scroll 0.
	var total := _talk_keyword_menu_items.size()
	var vis := _talk_keyword_visible_count()
	if vis <= 0 or total <= 0:
		_talk_keyword_menu_scroll = 0
		return
	_talk_keyword_menu_cursor = clampi(_talk_keyword_menu_cursor, 0, total - 1)
	if total <= vis:
		_talk_keyword_menu_scroll = 0
		return
	var center := int(vis / 2) ## 15 → 7 (0-based) = 8번째 줄
	_talk_keyword_menu_scroll = clampi(
		_talk_keyword_menu_cursor - center,
		0,
		total - vis
	)


func _begin_talk_keyword_menu_if_requested() -> void:
	if not _talk_gamepad_requested:
		return
	_talk_gamepad_requested = false
	_talk_keyword_menu_active = true
	_talk_keyword_menu_items = _talk_keyword_menu_initial_items()
	## Start on Job rather than Name — most first interests ask about work.
	## Hawkwind opens on the first virtue instead.
	_talk_keyword_menu_cursor = 0
	_talk_keyword_menu_scroll = 0
	if not _talk_is_hawkwind:
		for i in _talk_keyword_menu_items.size():
			if str(_talk_keyword_menu_items[i].get("key", "")) == "job":
				_talk_keyword_menu_cursor = i
				break
	_talk_keyword_menu_seen.clear()
	for item in _talk_keyword_menu_items:
		_remember_talk_keyword_menu_word(str(item.get("key", "")))
		_remember_talk_keyword_menu_word(str(item.get("input", "")))
	if _talk_is_lb:
		## LB lines say 치유/heal after counsel — do not spawn a second Heal row.
		for alias in [
			"heal", "health", "치유", "힐", "회복", "건강",
			"help", "도움", "도움말", "헬프",
		]:
			_remember_talk_keyword_menu_word(alias)
	_sync_talk_keyword_menu_scroll()
	## T:Dir? may have opened this menu while the direction stick/key is still held.
	## Wait for neutral before the first hold-repeat step.
	_talk_keyword_menu_await_neutral = true
	_reset_hold_state()
	_GameInput.latch_current_stick_navigation()
	_seed_talk_latent_keywords()
	_restore_talk_known_keywords()
	_rebuild_command_menu_rows()
	_sync_talk_keyword_menu_visibility()


func _talk_keyword_menu_health_index() -> int:
	for i in _talk_keyword_menu_items.size():
		if str(_talk_keyword_menu_items[i].get("key", "")) == "heal":
			return i
	return _talk_keyword_menu_items.size()


func _reveal_talk_keyword_if_latent(key: String) -> int:
	## 0 = missing, 1 = already revealed, 2 = flipped gray → white.
	if key.is_empty():
		return 0
	for i in _talk_keyword_menu_items.size():
		var item: Dictionary = _talk_keyword_menu_items[i]
		if not _talk_stored_key_matches(key, str(item.get("key", ""))):
			continue
		if bool(item.get("revealed", true)):
			return 1
		item["revealed"] = true
		_talk_keyword_menu_items[i] = item
		_persist_talk_known_word(str(item.get("input", item.get("key", ""))))
		return 2
	return 0


func _insert_talk_keyword_menu_item(
	key: String, label: String, input: String, revealed: bool
) -> void:
	## Insert before Health (same slot as discovered / journal-directed topics).
	var health_index := _talk_keyword_menu_health_index()
	_talk_keyword_menu_items.insert(health_index, {
		"key": key,
		"label": label,
		"input": input,
		"revealed": revealed,
	})
	_remember_talk_keyword_menu_word(key)
	_remember_talk_keyword_menu_word(input)
	if revealed:
		_persist_talk_known_word(input if not input.is_empty() else key)


func _seed_talk_latent_keywords() -> void:
	## Every NPC interest starts on the list. Look/Name/Job/Health/Give/Bye
	## are already white. Join and unspoken topics are gray. Iolo's compassion
	## flips white immediately if anyone else in town already said 연민.
	if not _talk_keyword_menu_active or _talk_is_hawkwind:
		return
	var korean := GameState.lang_short() == "ko"
	for word in _TalkLocale.latent_menu_words(_talk_keywords):
		var key := _talk_keyword_stable_key(word)
		if key.is_empty() or _talk_keyword_menu_seen.has(key):
			continue
		if _talk_is_white_builtin_key(key):
			continue
		var revealed := (
			_talk_npc_is_iolo()
			and _talk_word_is_compassion(word)
			and _talk_has_heard_interest(word)
		)
		var label := word if korean else word.capitalize()
		_insert_talk_keyword_menu_item(key, label, word, revealed)


func _talk_has_heard_interest(word: String) -> bool:
	if GameState.talk_has_heard_word(_talk_keyword_stable_key(word)):
		return true
	if GameState.talk_has_heard_word(word):
		return true
	for extra in _talk_keywords:
		var other := str(extra).strip_edges()
		if other.is_empty() or other == word:
			continue
		if not _talk_words_are_same_topic(word, other):
			continue
		if GameState.talk_has_heard_word(_talk_keyword_stable_key(other)):
			return true
		if GameState.talk_has_heard_word(other):
			return true
	return false


func _talk_npc_is_iolo() -> bool:
	if _talk_entry == null:
		return false
	return str(_talk_entry.name).strip_edges().to_lower() == "iolo"


func _talk_word_is_compassion(word: String) -> bool:
	var key := _talk_keyword_stable_key(word)
	if key.is_empty():
		return false
	for stem in ["연민", "compassion", "comp"]:
		if _talk_stored_key_matches(key, _talk_keyword_stable_key(stem)):
			return true
	return false


func _remember_talk_keyword_menu_word(word: String) -> void:
	var raw := word.strip_edges()
	if raw.is_empty():
		return
	_talk_keyword_menu_seen[raw] = true
	var sk := _talk_keyword_stable_key(raw)
	if not sk.is_empty():
		_talk_keyword_menu_seen[sk] = true
	var nk := _TalkLocale.normalize_interest(raw)
	if not nk.is_empty():
		_talk_keyword_menu_seen[nk] = true


func _end_talk_keyword_menu() -> void:
	_talk_gamepad_requested = false
	_talk_keyword_menu_active = false
	_talk_keyword_menu_cursor = 0
	_talk_keyword_menu_scroll = 0
	_talk_keyword_menu_await_neutral = false
	_talk_keyword_menu_items.clear()
	_talk_keyword_menu_seen.clear()
	_reset_hold_state()
	if _command_menu_layer != null and not _command_menu_open:
		_command_menu_layer.visible = false


func _talk_keyword_menu_can_select() -> bool:
	return _talk_keyword_menu_active and _talk_stage in [1, 11, 12]


func _sync_talk_keyword_menu_visibility() -> void:
	if not _talk_keyword_menu_active:
		return
	_ensure_command_menu_layer()
	if _command_menu_layer == null:
		return
	_command_menu_layer.visible = _talk_keyword_menu_can_select()
	if _command_menu_layer.visible:
		_command_menu_layer.move_to_front()
		_layout_command_menu_layer()


func _discover_talk_keywords(text: String) -> void:
	## Hawkwind already seeds the eight virtues; do not re-insert from replies.
	if text.is_empty() or _talk_is_hawkwind:
		return
	var discoveries: Array[Dictionary] = []
	var source_order := 0
	for raw_keyword in _talk_keywords:
		var word := str(raw_keyword).strip_edges()
		if word.is_empty():
			continue
		var key := _talk_keyword_stable_key(word)
		if key.is_empty() or key == _TalkLocale.normalize_interest("관심사"):
			continue
		## Reuse the dialogue highlighter's exact whole-word/stem rules so only
		## words actually exposed to the player become selectable / turn white.
		var text_index := _TalkTlk.keyword_first_index(text, word)
		if text_index < 0:
			continue
		var label := word if GameState.lang_short() == "ko" else word.capitalize()
		discoveries.append({
			"key": key,
			"label": label,
			"input": word,
			"text_index": text_index,
			"source_order": source_order,
		})
		source_order += 1
	discoveries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var ai := int(a.get("text_index", 0))
			var bi := int(b.get("text_index", 0))
			if ai == bi:
				return int(a.get("source_order", 0)) < int(b.get("source_order", 0))
			return ai < bi
	)
	## Drop short stems that only hit because a longer form sits at the same
	## spot (fort inside fortune, 점 inside 점술가). Keep the longer label.
	var trimmed: Array[Dictionary] = []
	for i in discoveries.size():
		var a: Dictionary = discoveries[i]
		var a_in := str(a.get("input", "")).to_lower()
		var a_idx := int(a.get("text_index", -1))
		var dominated := false
		for j in discoveries.size():
			if i == j:
				continue
			var b: Dictionary = discoveries[j]
			if int(b.get("text_index", -1)) != a_idx:
				continue
			var b_in := str(b.get("input", "")).to_lower()
			if b_in.length() > a_in.length() and b_in.begins_with(a_in):
				dominated = true
				break
		if not dominated:
			trimmed.append(a)
	discoveries = trimmed
	var changed := false
	for discovery in discoveries:
		var key := str(discovery.get("key", ""))
		if key.is_empty():
			continue
		_persist_talk_known_word(str(discovery.get("input", key)))
		if not _talk_keyword_menu_active:
			continue
		var reveal_status := _reveal_talk_keyword_if_latent(key)
		if reveal_status == 1:
			continue
		if reveal_status == 2:
			changed = true
			continue
		if _talk_keyword_menu_seen.has(key):
			continue
		_insert_talk_keyword_menu_item(
			key,
			str(discovery.get("label", "")),
			str(discovery.get("input", "")),
			true
		)
		changed = true
	if changed:
		_sync_talk_keyword_menu_scroll()
		_rebuild_command_menu_rows()
		_sync_talk_keyword_menu_visibility()


func _offer_talk_join_keyword() -> void:
	## Some natural Korean translations say "함께하다" instead of the literal
	## "합류", so expose Join after the source TLK explicitly offers to join.
	var korean := GameState.lang_short() == "ko"
	_offer_talk_keyword_item(
		"join",
		"합류" if korean else "Join",
		"합류" if korean else "join"
	)


func _offer_talk_keyword_item(key: String, label: String, input: String) -> void:
	## Insert a selectable interest before Health (same order as discovered topics).
	## Latent (gray) rows flip white when journal / dialogue unlocks them.
	if key.is_empty():
		return
	_persist_talk_known_word(input if not input.is_empty() else key)
	if not _talk_keyword_menu_active:
		return
	var reveal_status := _reveal_talk_keyword_if_latent(key)
	if reveal_status == 1:
		return
	if reveal_status == 2:
		_sync_talk_keyword_menu_scroll()
		_rebuild_command_menu_rows()
		_sync_talk_keyword_menu_visibility()
		return
	if _talk_keyword_menu_seen.has(key):
		return
	_insert_talk_keyword_menu_item(key, label, input, true)
	_sync_talk_keyword_menu_scroll()
	_rebuild_command_menu_rows()
	_sync_talk_keyword_menu_visibility()


func _maybe_offer_azure_sacrifice_keyword() -> void:
	## After Azure: "Which rune?" — inject Sacrifice if the player already
	## learned the virtue from Shentis (journal). Dialogue text alone does not
	## always contain the word (esp. English "Ask my sister, Mischief.").
	if not _talk_keyword_menu_active or _talk_entry == null:
		return
	if str(_talk_entry.name).strip_edges().to_lower() != "azure":
		return
	if not GameState.journal_has_id("minoc.shentis.sacrifice"):
		return
	var korean := GameState.lang_short() == "ko"
	var key := _talk_keyword_stable_key("희생" if korean else "sacrifice")
	_offer_talk_keyword_item(
		key,
		"희생" if korean else "Sacrifice",
		"희생" if korean else "sacrifice"
	)


func _maybe_offer_azure_rune_keyword() -> void:
	## Gimble's tip names Azure and the rune — unlock Rune after Azure is named.
	if not _talk_keyword_menu_active or _talk_entry == null:
		return
	if str(_talk_entry.name).strip_edges().to_lower() != "azure":
		return
	if not GameState.journal_has_id("minoc.gimble.azure-rune"):
		return
	var korean := GameState.lang_short() == "ko"
	var key := _talk_keyword_stable_key("룬" if korean else "rune")
	_offer_talk_keyword_item(
		key,
		"룬" if korean else "rune",
		"룬" if korean else "rune"
	)


func _maybe_offer_mischief_rune_keyword() -> void:
	## After Azure pointed to Mischief for the sacrifice rune, open with Rune.
	if not _talk_keyword_menu_active or _talk_entry == null:
		return
	if str(_talk_entry.name).strip_edges().to_lower() != "mischief":
		return
	if (
		not GameState.journal_has_id("minoc.azure.mischief-rune")
		and not GameState.journal_has_id("minoc.mischief.forge-rune")
	):
		return
	var korean := GameState.lang_short() == "ko"
	var key := _talk_keyword_stable_key("룬" if korean else "rune")
	_offer_talk_keyword_item(
		key,
		"룬" if korean else "rune",
		"룬" if korean else "rune"
	)


func _maybe_offer_alkerion_stone_keyword() -> void:
	if not _talk_keyword_menu_active or _talk_entry == null:
		return
	if str(_talk_entry.name).strip_edges().to_lower() != "alkerion":
		return
	if not GameState.journal_has_id("minoc.mischief.alkerion-stone"):
		return
	var korean := GameState.lang_short() == "ko"
	var key := _talk_keyword_stable_key("돌" if korean else "stone")
	_offer_talk_keyword_item(
		key,
		"돌" if korean else "Stone",
		"돌" if korean else "stone"
	)


func _maybe_offer_sacrifice_mantra_chain_keyword() -> void:
	if not _talk_keyword_menu_active or _talk_entry == null:
		return
	var npc := str(_talk_entry.name).strip_edges().to_lower()
	var korean := GameState.lang_short() == "ko"
	if (
		npc == "damon"
		and GameState.journal_has_id("minoc.merida.damon-mantra")
	):
		var mantra_key := _talk_keyword_stable_key(
			"만트라" if korean else "mantra"
		)
		_offer_talk_keyword_item(
			mantra_key,
			"만트라" if korean else "Mantra",
			"만트라" if korean else "mantra"
		)
	elif (
		npc == "singsong"
		and GameState.journal_has_id("minoc.damon.bard-song")
	):
		## Damon points at the verse/lyrics — unlock SONG without a second "노래".
		var verse_key := _talk_keyword_stable_key(
			"가사" if korean else "song"
		)
		_offer_talk_keyword_item(
			verse_key,
			"가사" if korean else "Song",
			"가사" if korean else "song"
		)


func _journal_has_any_zorin_antos_tip() -> bool:
	## Zorin names all three relics; any tip (or legacy row) unlocks the set.
	return (
		GameState.journal_has_id("lcb.zorin.antos-book")
		or GameState.journal_has_id("lcb.zorin.antos-candle")
		or GameState.journal_has_id("lcb.zorin.antos-bell")
		or GameState.journal_has_id("lcb.zorin.antos-relics")
	)


func _maybe_offer_antos_relic_keyword() -> void:
	## Player knows the three relics, not which Antos answers which — offer all.
	if not _talk_keyword_menu_active or _talk_entry == null:
		return
	var npc := str(_talk_entry.name).strip_edges().to_lower()
	if npc not in ["father antos", "brother antos", "sister antos"]:
		return
	if not _journal_has_any_zorin_antos_tip():
		return
	var korean := GameState.lang_short() == "ko"
	## Same order as Zorin's line: bell, book, candle / 종·책·촛대.
	var words: Array[String] = (
		["종", "책", "촛대"] if korean else ["bell", "book", "candle"]
	)
	for word in words:
		var key := _talk_keyword_stable_key(word)
		_offer_talk_keyword_item(
			key, word.capitalize() if not korean else word, word
		)


func _maybe_offer_zircon_mystic_keyword() -> void:
	## Seesha: seek the smith named Zircon in Minoc for the mystic arms.
	if not _talk_keyword_menu_active or _talk_entry == null:
		return
	if str(_talk_entry.name).strip_edges().to_lower() != "zircon":
		return
	if not GameState.journal_has_id("lcb.seesha.zircon-mystics"):
		return
	var korean := GameState.lang_short() == "ko"
	var word := "신비" if korean else "mystic"
	var key := _talk_keyword_stable_key(word)
	_offer_talk_keyword_item(
		key,
		word.capitalize() if not korean else word,
		word
	)


func _maybe_offer_britain_chain_keyword() -> void:
	## Britain name-directed tips: Pepper / Cricket / Julio.
	if not _talk_keyword_menu_active or _talk_entry == null:
		return
	var npc := str(_talk_entry.name).strip_edges().to_lower()
	var korean := GameState.lang_short() == "ko"
	if (
		npc == "pepper"
		and GameState.journal_has_id("britain.sprite.pepper-rune")
	):
		var rune_key := _talk_keyword_stable_key("룬" if korean else "rune")
		_offer_talk_keyword_item(
			rune_key,
			"룬" if korean else "Rune",
			"룬" if korean else "rune"
		)
	elif (
		npc == "cricket"
		and GameState.journal_has_id("britain.child.cricket-mantra")
	):
		var mantra_key := _talk_keyword_stable_key(
			"만트라" if korean else "mantra"
		)
		_offer_talk_keyword_item(
			mantra_key,
			"만트라" if korean else "Mantra",
			"만트라" if korean else "mantra"
		)
	elif (
		npc == "julio"
		and GameState.journal_has_id("britain.shapero.julio-compassion")
	):
		var comp_key := _talk_keyword_stable_key(
			"연민" if korean else "compassion"
		)
		_offer_talk_keyword_item(
			comp_key,
			"연민" if korean else "Compassion",
			"연민" if korean else "compassion"
		)


func _maybe_offer_moonglow_chain_keyword() -> void:
	## Christen points to William for the honesty rune.
	if not _talk_keyword_menu_active or _talk_entry == null:
		return
	if str(_talk_entry.name).strip_edges().to_lower() != "william":
		return
	if not GameState.journal_has_id("moonglow.christen.william-rune"):
		return
	var korean := GameState.lang_short() == "ko"
	var key := _talk_keyword_stable_key("룬" if korean else "rune")
	_offer_talk_keyword_item(
		key,
		"룬" if korean else "Rune",
		"룬" if korean else "rune"
	)


func _maybe_offer_jhelom_chain_keyword() -> void:
	## Jhelom name-directed tips: Nostro (rune) / Aesop (mantra).
	if not _talk_keyword_menu_active or _talk_entry == null:
		return
	var npc := str(_talk_entry.name).strip_edges().to_lower()
	var korean := GameState.lang_short() == "ko"
	if (
		npc == "nostro"
		and GameState.journal_has_id("jhelom.robert.nostro-rune")
	):
		var rune_key := _talk_keyword_stable_key("룬" if korean else "rune")
		_offer_talk_keyword_item(
			rune_key,
			"룬" if korean else "Rune",
			"룬" if korean else "rune"
		)
	elif (
		npc == "aesop"
		and GameState.journal_has_id("jhelom.hrothgar.aesop-mantra")
	):
		var mantra_key := _talk_keyword_stable_key(
			"만트라" if korean else "mantra"
		)
		_offer_talk_keyword_item(
			mantra_key,
			"만트라" if korean else "Mantra",
			"만트라" if korean else "mantra"
		)


func _maybe_offer_yew_chain_keyword() -> void:
	## Yew name-directed tips: Talfourd (rune) / Silent (mantra via job).
	if not _talk_keyword_menu_active or _talk_entry == null:
		return
	var npc := str(_talk_entry.name).strip_edges().to_lower()
	var korean := GameState.lang_short() == "ko"
	if (
		npc == "talfourd"
		and GameState.journal_has_id("yew.druid.talfourd-rune")
	):
		var rune_key := _talk_keyword_stable_key("룬" if korean else "rune")
		_offer_talk_keyword_item(
			rune_key,
			"룬" if korean else "Rune",
			"룬" if korean else "rune"
		)
	elif (
		npc == "silent"
		and GameState.journal_has_id("yew.pinrod.druids-mantra")
	):
		## Silent reveals BEH on Job; keep Job selectable after the tip.
		var job_key := _talk_keyword_stable_key("직업" if korean else "job")
		_offer_talk_keyword_item(
			job_key,
			"직업" if korean else "Job",
			"직업" if korean else "job"
		)


func _maybe_offer_trinsic_chain_keyword() -> void:
	## Trinsic honor-rune chain: Winthrop → Terrin.
	if not _talk_keyword_menu_active or _talk_entry == null:
		return
	var npc := str(_talk_entry.name).strip_edges().to_lower()
	var korean := GameState.lang_short() == "ko"
	if (
		npc == "winthrop"
		and GameState.journal_has_id("trinsic.kline.winthrop-rune")
	):
		var rune_key := _talk_keyword_stable_key("룬" if korean else "rune")
		_offer_talk_keyword_item(
			rune_key,
			"룬" if korean else "Rune",
			"룬" if korean else "rune"
		)
	elif (
		npc == "terrin"
		and GameState.journal_has_id("trinsic.winthrop.terrin-rune")
	):
		var rune_key := _talk_keyword_stable_key("룬" if korean else "rune")
		_offer_talk_keyword_item(
			rune_key,
			"룬" if korean else "Rune",
			"룬" if korean else "rune"
		)


func _talk_npc_is_skara_ankh(npc_name: String) -> bool:
	return (
		npc_name.strip_edges().to_lower().replace("\n", " ")
		== "the ankh of spirituality"
	)


func _maybe_offer_skara_chain_keyword() -> void:
	## Skara: Ambule/Barren mantra chain; Ankh rune (Rune then Om).
	if not _talk_keyword_menu_active or _talk_entry == null:
		return
	var npc := str(_talk_entry.name).strip_edges().to_lower()
	var korean := GameState.lang_short() == "ko"
	if (
		npc == "ambule"
		and GameState.journal_has_id("skara.granted.ambule-mantra")
	):
		var mantra_key := _talk_keyword_stable_key(
			"만트라" if korean else "mantra"
		)
		_offer_talk_keyword_item(
			mantra_key,
			"만트라" if korean else "Mantra",
			"만트라" if korean else "mantra"
		)
	elif (
		npc == "barren"
		and GameState.journal_has_id("skara.ambule.barren-mantra")
	):
		var mantra_key := _talk_keyword_stable_key(
			"만트라" if korean else "mantra"
		)
		_offer_talk_keyword_item(
			mantra_key,
			"만트라" if korean else "Mantra",
			"만트라" if korean else "mantra"
		)
	elif _talk_npc_is_skara_ankh(str(_talk_entry.name)):
		if GameState.journal_has_id("skara.barren.spirituality-mantra"):
			var om_key := _talk_keyword_stable_key("옴" if korean else "om")
			_offer_talk_keyword_item(
				om_key,
				"옴" if korean else "Om",
				"옴" if korean else "om"
			)
		if GameState.journal_has_id("skara.granted.ankh-rune"):
			var rune_key := _talk_keyword_stable_key("룬" if korean else "rune")
			_offer_talk_keyword_item(
				rune_key,
				"룬" if korean else "Rune",
				"룬" if korean else "rune"
			)


func _maybe_offer_magincia_chain_keyword() -> void:
	## Magincia: Heywood/Faultless mantra, Wierdrum shrine, Demitry horn, Nate rune.
	if not _talk_keyword_menu_active or _talk_entry == null:
		return
	var npc := str(_talk_entry.name).strip_edges().to_lower()
	var korean := GameState.lang_short() == "ko"
	if (
		npc == "heywood"
		and GameState.journal_has_id("magincia.casperin.heywood-mantra")
	):
		var mantra_key := _talk_keyword_stable_key(
			"만트라" if korean else "mantra"
		)
		_offer_talk_keyword_item(
			mantra_key,
			"만트라" if korean else "Mantra",
			"만트라" if korean else "mantra"
		)
	elif (
		npc == "faultless"
		and GameState.journal_has_id("magincia.heywood.faultless-mantra")
	):
		var mantra_key := _talk_keyword_stable_key(
			"만트라" if korean else "mantra"
		)
		_offer_talk_keyword_item(
			mantra_key,
			"만트라" if korean else "Mantra",
			"만트라" if korean else "mantra"
		)
	elif (
		npc == "wierdrum"
		and GameState.journal_has_id("magincia.banter.wierdrum-shrine")
	):
		var shrine_key := _talk_keyword_stable_key(
			"사원" if korean else "shrine"
		)
		_offer_talk_keyword_item(
			shrine_key,
			"사원" if korean else "Shrine",
			"사원" if korean else "shrine"
		)
	elif (
		npc == "demitry"
		and GameState.journal_has_id("magincia.banter.demitry-horn")
	):
		var horn_key := _talk_keyword_stable_key("뿔" if korean else "horn")
		_offer_talk_keyword_item(
			horn_key,
			"뿔" if korean else "Horn",
			"뿔" if korean else "horn"
		)
	elif (
		npc == "nate"
		and (
			GameState.journal_has_id("magincia.ruskin.nate-rune")
			or GameState.journal_has_id("magincia.splot.nate-rune")
		)
	):
		var rune_key := _talk_keyword_stable_key("룬" if korean else "rune")
		_offer_talk_keyword_item(
			rune_key,
			"룬" if korean else "Rune",
			"룬" if korean else "rune"
		)


func _talk_city_id() -> String:
	if _city_map == null:
		return ""
	return _TalkLocale.city_id_from_path(str(_city_map.source_path))


func _talk_discourse_index() -> int:
	## .TLK slot for the current speaker. Shared by clones of the same script.
	if _city_map == null:
		return -1
	if _talk_person_i >= 0 and _talk_person_i < _city_map.person_conv.size():
		return int(_city_map.person_conv[_talk_person_i])
	if _talk_entry == null:
		return -1
	for i in _city_map.discourses.size():
		if _city_map.discourses[i] == _talk_entry:
			return i
	return -1


func _talk_memory_npc_id() -> String:
	## Persist by discourse slot, not display name — "a child" / "a guard"
	## can be several different scripts in one town.
	if _talk_is_hawkwind or _talk_is_lb or _talk_entry == null:
		return ""
	var city := _talk_city_id()
	if city.is_empty():
		return ""
	var di := _talk_discourse_index()
	if di >= 0:
		return "%s/d%d" % [city, di]
	if _talk_person_i < 0:
		return ""
	return "%s/#%d" % [city, _talk_person_i]


func _talk_memory_legacy_npc_id() -> String:
	## Older saves keyed by English TLK name (`britain/a child`).
	if _talk_is_hawkwind or _talk_is_lb or _talk_entry == null:
		return ""
	var city := _talk_city_id()
	var npc := str(_talk_entry.name).strip_edges().to_lower()
	if city.is_empty() or npc.is_empty():
		return ""
	return "%s/%s" % [city, npc]


func _talk_is_white_builtin_key(key: String) -> bool:
	## Already on the opening row as white. Join is a builtin but stays gray.
	return key in ["look", "name", "job", "heal", "give", "bye"]


func _talk_is_menu_builtin_key(key: String) -> bool:
	return _talk_is_white_builtin_key(key) or key in ["join", "help"]


func _talk_should_persist_key(key: String) -> bool:
	if key.is_empty() or _talk_is_menu_builtin_key(key):
		return false
	return true


func _talk_stored_key_matches(stored: String, item_key: String) -> bool:
	if stored.is_empty() or item_key.is_empty():
		return false
	if stored == item_key:
		return true
	if _TalkLocale.normalize_interest(stored) == _TalkLocale.normalize_interest(item_key):
		return true
	var npc := str(_talk_entry.name).strip_edges() if _talk_entry != null else ""
	var city := _talk_city_id()
	return (
		_TalkLocale.match_topic_alias(stored, item_key, npc, city)
		or _TalkLocale.match_topic_alias(item_key, stored, npc, city)
	)


func _talk_words_are_same_topic(a: String, b: String) -> bool:
	return _talk_stored_key_matches(
		_talk_keyword_stable_key(a),
		_talk_keyword_stable_key(b)
	)


func _persist_talk_known_word(word: String) -> void:
	var npc_id := _talk_memory_npc_id()
	if npc_id.is_empty():
		return
	var raw := word.strip_edges()
	if raw.is_empty():
		return
	var seen: Dictionary = {}
	_persist_talk_known_one(npc_id, raw, seen)
	_persist_talk_heard_word(raw)
	for extra in _talk_keywords:
		var other := str(extra).strip_edges()
		if other.is_empty() or other == raw:
			continue
		if _talk_words_are_same_topic(raw, other):
			_persist_talk_known_one(npc_id, other, seen)
			_persist_talk_heard_word(other)


func _persist_talk_heard_word(word: String) -> void:
	var key := _talk_keyword_stable_key(word)
	if key.is_empty() or not _talk_should_persist_key(key):
		return
	GameState.talk_remember_heard_word(key)


func _persist_talk_known_one(npc_id: String, word: String, seen: Dictionary) -> void:
	var key := _talk_keyword_stable_key(word)
	if key.is_empty() or seen.has(key) or not _talk_should_persist_key(key):
		return
	seen[key] = true
	GameState.talk_remember_keyword(npc_id, key)


func _talk_label_for_stored_key(stored: String) -> String:
	var korean := GameState.lang_short() == "ko"
	var hangul := ""
	var latin := ""
	for raw in _talk_keywords:
		var word := str(raw).strip_edges()
		if word.is_empty():
			continue
		if not _talk_stored_key_matches(stored, _talk_keyword_stable_key(word)):
			continue
		if _TalkLocale.word_has_hangul(word):
			if hangul.is_empty():
				hangul = word
		elif latin.is_empty():
			latin = word
	if korean and not hangul.is_empty():
		return hangul
	if not latin.is_empty():
		return latin
	if not hangul.is_empty():
		return hangul
	return stored


func _talk_stored_key_belongs_here(stored: String) -> bool:
	if stored.is_empty():
		return false
	for raw in _talk_keywords:
		var word := str(raw).strip_edges()
		if word.is_empty():
			continue
		if _talk_stored_key_matches(stored, _talk_keyword_stable_key(word)):
			return true
	return false


func _restore_talk_known_keywords() -> void:
	if not _talk_keyword_menu_active:
		return
	var npc_id := _talk_memory_npc_id()
	if npc_id.is_empty():
		return
	var stored_keys: Array[String] = GameState.talk_known_keys(npc_id)
	var legacy_id := _talk_memory_legacy_npc_id()
	if not legacy_id.is_empty() and legacy_id != npc_id:
		for stored in GameState.talk_known_keys(legacy_id):
			if stored_keys.has(stored):
				continue
			## Same display name can be several scripts; keep only this script's words.
			if _talk_stored_key_belongs_here(stored):
				stored_keys.append(stored)
				GameState.talk_remember_keyword(npc_id, stored)
	var korean := GameState.lang_short() == "ko"
	for stored in stored_keys:
		if _reveal_talk_keyword_if_latent(stored) != 0:
			continue
		if _talk_keyword_menu_seen.has(stored):
			continue
		var word := _talk_label_for_stored_key(stored)
		if word.is_empty():
			word = stored
		var label := word if korean else word.capitalize()
		_insert_talk_keyword_menu_item(stored, label, word, true)


func _maybe_offer_paws_chain_keyword() -> void:
	## Paws: Barren humility rune; Simon/Tessa mystic locations.
	## Barren also exists in Skara Brae — scope by city.
	if not _talk_keyword_menu_active or _talk_entry == null:
		return
	if _talk_city_id() != "paws":
		return
	var npc := str(_talk_entry.name).strip_edges().to_lower()
	var korean := GameState.lang_short() == "ko"
	if (
		npc == "barren"
		and GameState.journal_has_id("magincia.nate.barren-rune")
	):
		var rune_key := _talk_keyword_stable_key("룬" if korean else "rune")
		_offer_talk_keyword_item(
			rune_key,
			"룬" if korean else "Rune",
			"룬" if korean else "rune"
		)
	elif (
		(
			npc == "sir simon"
			or npc == "lady tessa"
		)
		and GameState.journal_has_id("minoc.zircon.mystic-arms")
	):
		var mystic_key := _talk_keyword_stable_key(
			"신비" if korean else "mystic"
		)
		_offer_talk_keyword_item(
			mystic_key,
			"신비" if korean else "Mystic",
			"신비" if korean else "mystic"
		)


func _offer_named_npc_journal_keywords() -> void:
	## Directed journal clues become selectable only after this NPC's name
	## has actually been spoken in the current conversation.
	_maybe_offer_azure_rune_keyword()
	_maybe_offer_mischief_rune_keyword()
	_maybe_offer_alkerion_stone_keyword()
	_maybe_offer_sacrifice_mantra_chain_keyword()
	_maybe_offer_antos_relic_keyword()
	_maybe_offer_zircon_mystic_keyword()
	_maybe_offer_britain_chain_keyword()
	_maybe_offer_moonglow_chain_keyword()
	_maybe_offer_jhelom_chain_keyword()
	_maybe_offer_yew_chain_keyword()
	_maybe_offer_trinsic_chain_keyword()
	_maybe_offer_skara_chain_keyword()
	_maybe_offer_magincia_chain_keyword()
	_maybe_offer_paws_chain_keyword()
	_maybe_offer_cove_chain_keyword()
	_maybe_offer_keep_chain_keyword()


func _talk_npc_is_cove_ankh(npc_name: String) -> bool:
	return npc_name.strip_edges().to_lower() == "the ankh"


func _maybe_offer_cove_chain_keyword() -> void:
	## Cove: Blissful (abyss) / the ankh (codex chamber) / Merlin (gate).
	if not _talk_keyword_menu_active or _talk_entry == null:
		return
	if _talk_city_id() != "cove":
		return
	var npc := str(_talk_entry.name).strip_edges().to_lower()
	var korean := GameState.lang_short() == "ko"
	if (
		npc == "blissful"
		and GameState.journal_has_id("cove.allen.blissful-abyss")
	):
		var abyss_key := _talk_keyword_stable_key(
			"심연" if korean else "abyss"
		)
		_offer_talk_keyword_item(
			abyss_key,
			"심연" if korean else "Abyss",
			"심연" if korean else "abyss"
		)
	elif (
		_talk_npc_is_cove_ankh(str(_talk_entry.name))
		and GameState.journal_has_id("cove.blissful.ankh-chamber")
	):
		var chamber_key := _talk_keyword_stable_key("방" if korean else "chamber")
		_offer_talk_keyword_item(
			chamber_key,
			"방" if korean else "Chamber",
			"방" if korean else "chamber"
		)
	elif (
		npc == "merlin"
		and GameState.journal_has_id("cove.merlin.black-stone")
	):
		var gate_key := _talk_keyword_stable_key("달문" if korean else "gate")
		_offer_talk_keyword_item(
			gate_key,
			"달문" if korean else "Gate",
			"달문" if korean else "gate"
		)


func _talk_npc_key_flat(npc_name: String) -> String:
	## TLK names may embed newlines (e.g. Jeremy James / Scirlock).
	return npc_name.strip_edges().to_lower().replace("\n", " ").replace("\r", " ")


func _maybe_offer_den_prompt_keywords() -> void:
	## Buccaneer's Den: after Yes, Ragnar asks "On what?" / Scirlock "Which?".
	if not _talk_keyword_menu_active or _talk_entry == null:
		return
	if _talk_city_id() != "den":
		return
	var npc := _talk_npc_key_flat(str(_talk_entry.name))
	var korean := GameState.lang_short() == "ko"
	if npc == "ragnar":
		var skull_key := _talk_keyword_stable_key("해골" if korean else "skull")
		_offer_talk_keyword_item(
			skull_key,
			"해골" if korean else "Skull",
			"해골" if korean else "skull"
		)
	elif npc.contains("scirlock"):
		var hyth_name := Locale.place("hythloth")
		var hyth_key := _talk_keyword_stable_key(
			hyth_name if korean else "hythloth"
		)
		_offer_talk_keyword_item(
			hyth_key,
			hyth_name,
			hyth_name if korean else "hythloth"
		)


func _maybe_offer_keep_chain_keyword() -> void:
	## Empath Abbey / Lycaeum / Serpent's Hold follow-up keywords.
	if not _talk_keyword_menu_active or _talk_entry == null:
		return
	var place := _talk_city_id()
	if place not in ["empath", "lycaeum", "serpent"]:
		return
	var npc := _talk_npc_key_flat(str(_talk_entry.name))
	var korean := GameState.lang_short() == "ko"
	if (
		place == "empath"
		and npc == "malchor"
		and GameState.journal_has_id("empath.suzanna.malchor-horn")
	):
		var horn_key := _talk_keyword_stable_key("뿔" if korean else "horn")
		_offer_talk_keyword_item(
			horn_key,
			"뿔" if korean else "Horn",
			"뿔" if korean else "horn"
		)
	elif (
		place == "empath"
		and npc == "suzanna"
		and GameState.journal_has_id("magincia.demitry.suzanna-horn")
	):
		var horn_key := _talk_keyword_stable_key("뿔" if korean else "horn")
		_offer_talk_keyword_item(
			horn_key,
			"뿔" if korean else "Horn",
			"뿔" if korean else "horn"
		)
	elif (
		place == "empath"
		and npc == "derek the bard"
		and GameState.journal_has_id("empath.life.derek-candle")
	):
		var candle_key := _talk_keyword_stable_key(
			"촛대" if korean else "candle"
		)
		_offer_talk_keyword_item(
			candle_key,
			"촛대" if korean else "Candle",
			"촛대" if korean else "candle"
		)
	elif (
		place == "lycaeum"
		and npc == "lord terence"
		and GameState.journal_has_id("lycaeum.father-antos.book")
	):
		var truth_key := _talk_keyword_stable_key(
			"진리" if korean else "truth"
		)
		_offer_talk_keyword_item(
			truth_key,
			"진리" if korean else "Truth",
			"진리" if korean else "truth"
		)
	elif (
		place == "serpent"
		and npc == "garam"
		and GameState.journal_has_id("serpent.sister-antos.garam-bell")
	):
		var bell_key := _talk_keyword_stable_key("종" if korean else "bell")
		_offer_talk_keyword_item(
			bell_key,
			"종" if korean else "Bell",
			"종" if korean else "bell"
		)
	elif (
		place == "serpent"
		and npc == "lassorn"
		and GameState.journal_has_id("serpent.noxum.lassorn-wheel")
	):
		var wheel_key := _talk_keyword_stable_key(
			"타륜" if korean else "wheel"
		)
		_offer_talk_keyword_item(
			wheel_key,
			"타륜" if korean else "Wheel",
			"타륜" if korean else "wheel"
		)
	elif (
		place == "serpent"
		and npc == "shyra"
		and GameState.journal_has_id("serpent.ranger.shrya-rooms")
	):
		var room_key := _talk_keyword_stable_key("방" if korean else "room")
		_offer_talk_keyword_item(
			room_key,
			"방" if korean else "Room",
			"방" if korean else "room"
		)
	elif (
		place == "serpent"
		and npc == "durham"
		and GameState.journal_has_id("serpent.treasure-guard.durham")
	):
		var dung_key := _talk_keyword_stable_key(
			"던전" if korean else "dungeon"
		)
		_offer_talk_keyword_item(
			dung_key,
			"던전" if korean else "Dungeon",
			"던전" if korean else "dungeon"
		)
	elif (
		place == "serpent"
		and npc == "roderick"
		and GameState.journal_has_id("britain.thevel.roderick-orbs")
	):
		var orb_key := _talk_keyword_stable_key("오브" if korean else "orbs")
		_offer_talk_keyword_item(
			orb_key,
			"오브" if korean else "Orbs",
			"오브" if korean else "orbs"
		)


func _talk_answer_unlocks_join(e, yes: bool) -> bool:
	## Four companions explicitly say "join" in their Yes reply. The others
	## reveal Join after the virtue-aligned answer from their original dialogue.
	if yes and str(e.yes).to_lower().contains("join"):
		return true
	match str(e.name).to_lower():
		"jaana", "dupre":
			return yes
		"katrina":
			return not yes
		_:
			return false


func _talk_typed_draft() -> String:
	## Keyboard/IME text waiting to submit (menu Enter must not override this).
	if _talk_ime_stage_active() and _talk_edit != null:
		return _talk_edit.text.strip_edges()
	return (_talk_buffer + _talk_hangul_preedit).strip_edges()


func _clear_talk_typed_draft() -> void:
	## Discard partial typing so the next Enter selects the highlighted menu row.
	_reset_talk_hangul()
	_talk_buffer = ""
	if _talk_edit != null and _talk_ime_stage_active():
		_talk_edit_syncing = true
		_talk_edit.text = ""
		_talk_edit.caret_column = 0
		_talk_edit_syncing = false
	_layout_prompt_row()


func _move_talk_keyword_menu_cursor(step: int) -> void:
	if _talk_keyword_menu_items.is_empty() or step == 0:
		return
	## Navigating the list abandons typed draft; Enter then picks the row again.
	if not _talk_typed_draft().is_empty():
		_clear_talk_typed_draft()
	_talk_keyword_menu_cursor = posmod(
		_talk_keyword_menu_cursor + step,
		_talk_keyword_menu_items.size()
	)
	_sync_talk_keyword_menu_scroll()
	_rebuild_command_menu_rows()
	_layout_command_menu_layer()


func _choose_talk_keyword_menu_item() -> void:
	if (
		not _talk_keyword_menu_can_select()
		or _talk_keyword_menu_items.is_empty()
		or _talk_keyword_menu_cursor < 0
		or _talk_keyword_menu_cursor >= _talk_keyword_menu_items.size()
	):
		return
	var item := _talk_keyword_menu_items[_talk_keyword_menu_cursor]
	var selected_key := str(item.get("key", ""))
	## A gamepad choice replaces any partially typed keyboard/IME text.
	_reset_talk_hangul()
	_talk_buffer = str(item.get("input", ""))
	if _talk_edit != null and _talk_ime_stage_active():
		_talk_edit_syncing = true
		_talk_edit.text = _talk_buffer
		_talk_edit.caret_column = _talk_edit.text.length()
		_talk_edit_syncing = false
	_layout_prompt_row()
	var enter := InputEventKey.new()
	enter.pressed = true
	enter.keycode = KEY_ENTER
	_handle_talk_input(enter)
	## The reply can insert newly discovered keywords before Health. Find the
	## submitted item again so focus advances to its actual next row.
	if _talk_keyword_menu_active and not _talk_keyword_menu_items.is_empty():
		var selected_index := -1
		for i in _talk_keyword_menu_items.size():
			if str(_talk_keyword_menu_items[i].get("key", "")) == selected_key:
				selected_index = i
				break
		if selected_index >= 0:
			var next_index := mini(
				selected_index + 1,
				_talk_keyword_menu_items.size() - 1
			)
			## Donate remains selectable manually, but automatic progression
			## skips it and lands directly on Bye.
			if (
				next_index < _talk_keyword_menu_items.size() - 1
				and str(_talk_keyword_menu_items[next_index].get("key", "")) == "give"
			):
				next_index += 1
			_talk_keyword_menu_cursor = next_index
			_sync_talk_keyword_menu_scroll()
			_rebuild_command_menu_rows()
			_layout_command_menu_layer()


func _handle_talk_keyword_menu_input(event: InputEvent) -> bool:
	## ↑↓ hold-repeat is polled in _tick_dialogue_choice_nav.
	if not _talk_keyword_menu_can_select():
		return false
	if event is InputEventJoypadMotion:
		return true
	if not event.is_pressed():
		return false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if (
			key_event.keycode == KEY_UP or key_event.physical_keycode == KEY_UP
			or key_event.keycode == KEY_DOWN or key_event.physical_keycode == KEY_DOWN
		):
			return true
		var key_dir := _GameInput.dir_from_event(key_event)
		if key_dir.y != 0:
			return true
		if not key_event.echo and (
			_is_talk_enter(key_event)
			or key_event.is_action_pressed("confirm")
		):
			## Typed keyword + Enter submits the draft; empty Enter picks the row.
			if not _talk_typed_draft().is_empty():
				return false
			_choose_talk_keyword_menu_item()
			return true
		return false
	if event is InputEventJoypadButton:
		if event.is_echo():
			return false
		if _GameInput.is_select(event) or event.is_action_pressed("confirm"):
			_choose_talk_keyword_menu_item()
			return true
		var pad_dir := _GameInput.dir_from_event(event)
		if pad_dir.y != 0:
			return true
	return false


func _on_escape(allow_menu_open: bool = true) -> void:
	if _journal_focus_active:
		_close_journal_focus()
		return
	if _city_warp_open:
		_close_city_warp()
		return
	if _command_menu_open:
		_close_command_menu()
		return
	if _peer_overlay != null and _peer_overlay.is_open():
		_close_peer_overlay()
		return
	## Conversation owns Esc: farewell (Bye), never open the options menu.
	if _talk_stage != 0:
		_end_talk(true)
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
	if _inn_stage == 1:
		## Inn sleep — Esc does nothing until Morning!
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
	if allow_menu_open:
		_open_esc_menu()


func _input(event: InputEvent) -> void:
	## L2 opens journal browse (left pane only if sides are closed).
	## R2 mirrors Tab — open/close the side panels.
	## Axis events repeat while held, so fire once after crossing the
	## threshold and re-arm on release.
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_TRIGGER_LEFT:
			var down := motion.axis_value > 0.5
			if down and not _left_trigger_held:
				_left_trigger_held = true
				_open_journal_focus()
			elif not down:
				_left_trigger_held = false
			get_viewport().set_input_as_handled()
			return
		if motion.axis == JOY_AXIS_TRIGGER_RIGHT:
			var down_r := motion.axis_value > 0.5
			if down_r and not _right_trigger_held:
				_right_trigger_held = true
				_handle_panel_toggle()
			elif not down_r:
				_right_trigger_held = false
			get_viewport().set_input_as_handled()
			return
	if _death_busy:
		get_viewport().set_input_as_handled()
		return
	if (
		_command_menu_open
		and event is InputEventKey
		and event.pressed
		and not event.echo
	):
		var menu_key := event as InputEventKey
		if menu_key.keycode == KEY_TAB or menu_key.physical_keycode == KEY_TAB:
			_handle_panel_toggle()
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
			_handle_panel_toggle()
			get_viewport().set_input_as_handled()
			return


func _handle_panel_toggle() -> void:
	## Ztats / Ready / Wear / Mix / camp pick open: don't collapse/expand side panels.
	## Camp rest allows Tab so inventory panels stay reachable.
	## Shrine session: panels stay forced open; Tab/left trigger locked.
	## Talk: only toggle the left inventory panel; state persists after Bye.
	if _journal_focus_active:
		return
	if _death_busy or (_combat_active and not _command_menu_open):
		return
	if _command_menu_open:
		## The palette is an independent MapPane overlay. Tab may change the
		## regular side/dialogue panels without moving or resizing the palette.
		_toggle_side_panels()
		return
	if (
		_ztats_stage != 0
		or _ready_stage != 0
		or _wear_stage != 0
		or _mix_stage != 0
		or _use_stage != 0
		or _shrine_session
		or _shrine_stage != 0
		or _shrine_busy
		or _shrine_ejecting
		or _camp_stage == 2
		or _camp_stage == 3
		or _chest_open_stage != 0
		or _telescope_stage != 0
		or _save_stage != 0
		or _esc_menu_is_open()
		or _options_panel_is_open()
	):
		return
	if _talk_stage != 0:
		_toggle_left_panel_during_talk()
		return
	_toggle_side_panels()


func _unhandled_input(event: InputEvent) -> void:
	## Ztats / Ready / Wear / Mix / Camp / Chest Open / Telescope / Save / Load / Esc menu / Options / New Order.
	if _moongate_busy or _cannon_busy or _search_busy or _death_busy or _shrine_busy:
		get_viewport().set_input_as_handled()
		return
	if _city_warp_open:
		if _handle_city_warp_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if _journal_focus_active:
		if _handle_journal_focus_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed() or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()
		return
	if _command_menu_open:
		if _handle_command_menu_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if _combat_exit_prompt:
		if _handle_enter_prompt_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if _enter_prompt_stage == 1:
		if _handle_enter_prompt_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if _shrine_stage != 0:
		if _handle_shrine_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if _talk_stage != 0:
		if (
			_talk_stage == 2
			and (
				(
					event is InputEventMouseButton
					and event.pressed
					and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
				)
				or (
					event is InputEventJoypadButton
					and event.pressed
					and not event.is_echo()
					and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A
				)
			)
		):
			## Mouse left click or the gamepad confirm button (A) advances
			## the "Press any key" pause to its follow-up question.
			_talk_ask_question()
			get_viewport().set_input_as_handled()
			return
		if _binary_prompt_active() and _enter_prompt_stage != 1:
			if _handle_enter_prompt_input(event):
				get_viewport().set_input_as_handled()
			elif event.is_pressed():
				get_viewport().set_input_as_handled()
			return
		if _handle_shop_number_input(event):
			get_viewport().set_input_as_handled()
			return
		if _handle_talk_give_number_input(event):
			get_viewport().set_input_as_handled()
			return
		if _handle_shop_sell_pick_input(event):
			get_viewport().set_input_as_handled()
			return
		if _handle_shop_item_menu_input(event):
			get_viewport().set_input_as_handled()
			return
		if _handle_talk_keyword_menu_input(event):
			get_viewport().set_input_as_handled()
			return
		if _talk_native_hangul_active() and event is InputEventKey:
			if _handle_talk_native_hangul(event as InputEventKey):
				get_viewport().set_input_as_handled()
			return
		## GUI input already updated the focused LineEdit. Do not also send the
		## same key through the legacy terminal path (double type/backspace).
		## Escape remains a dialogue-level command.
		if _talk_ime_stage_active() and _talk_edit != null and _talk_edit.has_focus():
			if event is InputEventKey:
				var ime_key := event as InputEventKey
				if (
					ime_key.pressed and not ime_key.echo
					and (ime_key.keycode == KEY_ESCAPE or ime_key.physical_keycode == KEY_ESCAPE)
				):
					_handle_talk_input(ime_key)
				get_viewport().set_input_as_handled()
			elif _is_cancel_event(event):
				if _talk_stage == 10 and _shop != null:
					_shop.on_escape()
					_flush_shop_output()
				else:
					_end_talk(true)
				get_viewport().set_input_as_handled()
			return
		if _is_cancel_event(event):
			if _talk_stage == 10 and _shop != null:
				_shop.on_escape()
				_flush_shop_output()
			else:
				_end_talk(true)
			get_viewport().set_input_as_handled()
			return
		if _handle_talk_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
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
			## JoypadMotion must pass when released (clears stick latch / Dir?).
			if (
				(event is InputEventJoypadMotion or (event.is_pressed() and not event.is_echo()))
				and _handle_combat_pending_dir_event(event)
			):
				get_viewport().set_input_as_handled()
			elif event.is_pressed() or event is InputEventJoypadMotion:
				get_viewport().set_input_as_handled()
			return
		if _is_cancel_event(event) and _can_open_command_menu():
			_open_command_menu()
			get_viewport().set_input_as_handled()
			return
		if _handle_combat_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed() or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()
		return
	if _save_stage != 0:
		if _handle_save_input(event):
			get_viewport().set_input_as_handled()
		elif event.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if _options_panel_is_open():
		if event is InputEventKey and event.pressed and not event.echo and _is_fullscreen_key(event as InputEventKey):
			## Mode is toggled by DisplaySettings (input/poll); refresh label now.
			if _options_panel != null:
				_options_panel.refresh()
			get_viewport().set_input_as_handled()
			return
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
	if _inn_stage == 1:
		## xu4 InnController wait — swallow input while sleeping.
		if event.is_pressed():
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
		## ⌘F / Ctrl+F — toggle fullscreen (before F=Fire). Match ⌘S detection style.
		if _is_fullscreen_key(event):
			DisplaySettings.toggle_fullscreen()
			if _options_panel_is_open() and _options_panel != null:
				_options_panel.refresh()
			get_viewport().set_input_as_handled()
			return
		## xu4 immobilized (all asleep): no commands until someone wakes.
		if _is_party_asleep_locked():
			get_viewport().set_input_as_handled()
			return
		## Ctrl/⌘+J: open the left pane and browse the journal.
		if _is_mod_chord_key(event) and _is_journal_key(event):
			_open_journal_focus()
			get_viewport().set_input_as_handled()
			return
		## Ctrl/⌘+L: toggle persistent Locate HUD (sextant required).
		if _is_mod_chord_key(event) and _is_locate_key(event):
			_toggle_locate_hud()
			get_viewport().set_input_as_handled()
			return
		## Ctrl/⌘+K: dump current virtue karma to the message log.
		if _is_mod_chord_key(event) and _is_karma_key(event):
			_do_show_karma()
			get_viewport().set_input_as_handled()
			return
		## LOCAL CHEAT: Ctrl/⌘+P — warp to a city entrance on the world map.
		if _is_mod_chord_key(event) and _is_city_warp_key(event):
			_open_city_warp()
			get_viewport().set_input_as_handled()
			return
		## Waiting for a direction (A/G/J/O/T or ship Yell) — same line as "Attack: Dir?".
		if _pending_cmd != U4Commands.Id.NONE or _ship_yell_await_dir:
			if _is_direction_key(event):
				return
			## Space is Pass only — ignore it while Dir? is waiting.
			if _is_space_key(event):
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
		return
	## Gamepad while idle: X passes, B opens the contextual A–Z palette,
	## and Start opens/closes the system menu.
	if event.is_pressed() and not event.is_echo():
		if _peer_overlay != null and _peer_overlay.is_open():
			if _is_cancel_event(event) or _GameInput.is_select(event):
				_close_peer_overlay()
				get_viewport().set_input_as_handled()
			return
		if (
			event is InputEventJoypadButton
			and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START
		):
			_on_escape(true)
			get_viewport().set_input_as_handled()
			return
		if _is_cancel_event(event):
			if _can_open_command_menu():
				_open_command_menu()
			else:
				_on_escape(false)
			get_viewport().set_input_as_handled()
			return
		if _pending_cmd != U4Commands.Id.NONE or _ship_yell_await_dir:
			if _GameInput.dir_from_event(event) != Vector2i.ZERO:
				## Direction applied in _process hold path.
				return
			if _GameInput.is_select(event) or event.is_action_pressed("confirm"):
				_clear_pending_dir()
				_clear_ship_yell_await()
				get_viewport().set_input_as_handled()
				return
			if event is InputEventJoypadButton:
				_clear_pending_dir()
				_clear_ship_yell_await()
				_push_message(Locale.t("cmd_what"), false)
				get_viewport().set_input_as_handled()
			return
		if _GameInput.is_pass(event):
			## Idle X mirrors the keyboard Space/Pass command.
			if not _is_party_asleep_locked():
				_handle_command(U4Commands.Id.PASS)
			get_viewport().set_input_as_handled()
			return


func _is_peer_dismiss_key(event: InputEventKey) -> bool:
	## xu4 peer(): readChoice("\\015 \\033") — Enter, Esc.
	var code := event.keycode
	var phys := event.physical_keycode
	return (
		code == KEY_ESCAPE or phys == KEY_ESCAPE
		or code == KEY_ENTER or phys == KEY_ENTER
		or code == KEY_KP_ENTER or phys == KEY_KP_ENTER
	)


func _is_space_key(event: InputEventKey) -> bool:
	return event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE


func _is_direction_key(event: InputEventKey) -> bool:
	var code := event.keycode
	var phys := event.physical_keycode
	return (
		code == KEY_LEFT or code == KEY_RIGHT or code == KEY_UP or code == KEY_DOWN
		or phys == KEY_LEFT or phys == KEY_RIGHT or phys == KEY_UP or phys == KEY_DOWN
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


func _is_mod_chord_key(event: InputEventKey) -> bool:
	## Ctrl (Windows/Linux) or ⌘ (macOS), not Alt/Shift.
	if event.alt_pressed or event.shift_pressed:
		return false
	return event.ctrl_pressed or event.meta_pressed


func _is_journal_key(event: InputEventKey) -> bool:
	return event.keycode == KEY_J or event.physical_keycode == KEY_J


func _is_locate_key(event: InputEventKey) -> bool:
	return event.keycode == KEY_L or event.physical_keycode == KEY_L


func _is_karma_key(event: InputEventKey) -> bool:
	return event.keycode == KEY_K or event.physical_keycode == KEY_K


func _is_city_warp_key(event: InputEventKey) -> bool:
	## LOCAL CHEAT — do not commit.
	return event.keycode == KEY_P or event.physical_keycode == KEY_P


func _city_warp_visible_count() -> int:
	return mini(MSG_OPEN_LINES, _city_warp_items.size())


func _build_city_warp_items() -> Array[Dictionary]:
	var by_id: Dictionary = {}
	for portal in _WorldPortals.all_portal_entries():
		var pid := _WorldPortals.place_id_for_portal(portal)
		if pid.is_empty() or by_id.has(pid):
			continue
		by_id[pid] = portal
	var out: Array[Dictionary] = []
	for pid in _WorldPortals.journal_place_order():
		if not by_id.has(pid):
			continue
		var p: Dictionary = by_id[pid]
		var label := Locale.t("place_%s" % pid)
		if label == ("place_%s" % pid):
			label = str(p.get("name", pid))
		out.append({
			"place_id": pid,
			"label": label,
			"wx": int(p.get("wx", 0)),
			"wy": int(p.get("wy", 0)),
		})
	return out


func _can_open_city_warp() -> bool:
	if _city_warp_open or _command_menu_open or _journal_focus_active or _enter_prompt_stage != 0:
		return false
	if (
		_death_busy or _moongate_busy or _cannon_busy or _search_busy
		or _shrine_busy or _shrine_stage != 0 or _shrine_session or _inn_stage != 0
	):
		return false
	if (
		_talk_stage != 0 or _mix_stage != 0 or _save_stage != 0
		or _camp_stage != 0 or _chest_open_stage != 0 or _telescope_stage != 0
		or _ready_stage != 0 or _wear_stage != 0 or _use_stage != 0
		or _ztats_stage != 0 or _order_stage != 0
		or _pending_cmd != U4Commands.Id.NONE or _ship_yell_await_dir
		or _esc_menu_is_open() or _options_panel_is_open()
		or _combat_active
	):
		return false
	if _peer_overlay != null and _peer_overlay.is_open():
		return false
	return true


func _open_city_warp() -> void:
	## LOCAL CHEAT — do not commit.
	if not _can_open_city_warp():
		_push_message("City warp: not now.", false)
		return
	_city_warp_items = _build_city_warp_items()
	if _city_warp_items.is_empty():
		_push_message("City warp: no portals.", false)
		return
	_city_warp_open = true
	_city_warp_cursor = 0
	_city_warp_scroll = 0
	_GameInput.reset_stick_navigation()
	_reset_hold_state()
	_block_dir_until_keyup = true
	_rebuild_command_menu_rows()
	if _command_menu_layer != null:
		_command_menu_layer.visible = true
		_command_menu_layer.move_to_front()
	_layout_command_menu_layer()


func _close_city_warp() -> void:
	if not _city_warp_open:
		return
	_city_warp_open = false
	_city_warp_cursor = 0
	_city_warp_scroll = 0
	_city_warp_items.clear()
	if _command_menu_layer != null and not _command_menu_open and not _talk_keyword_menu_active:
		_command_menu_layer.visible = false
	_reset_hold_state()
	_block_dir_until_keyup = true
	grab_focus()


func _move_city_warp_cursor(step: int) -> void:
	if _city_warp_items.is_empty() or step == 0:
		return
	_city_warp_cursor = posmod(_city_warp_cursor + step, _city_warp_items.size())
	var vis := _city_warp_visible_count()
	if _city_warp_cursor < _city_warp_scroll:
		_city_warp_scroll = _city_warp_cursor
	elif _city_warp_cursor >= _city_warp_scroll + vis:
		_city_warp_scroll = _city_warp_cursor - vis + 1
	_city_warp_scroll = clampi(
		_city_warp_scroll,
		0,
		maxi(_city_warp_items.size() - vis, 0)
	)
	_rebuild_command_menu_rows()
	_layout_command_menu_layer()


func _choose_city_warp_item() -> void:
	if (
		not _city_warp_open
		or _city_warp_items.is_empty()
		or _city_warp_cursor < 0
		or _city_warp_cursor >= _city_warp_items.size()
	):
		return
	var item := _city_warp_items[_city_warp_cursor]
	_close_city_warp()
	_apply_city_warp(item)


func _apply_city_warp(item: Dictionary) -> void:
	## LOCAL CHEAT — stand on the outdoor Enter tile for that settlement.
	if item.is_empty():
		return
	if _combat_active or _shrine_session or _shrine_stage != 0:
		_push_message("City warp: not now.", false)
		return
	if _is_in_city():
		_exit_city()
	var dest := Vector2i(int(item.get("wx", 0)), int(item.get("wy", 0)))
	_tile_pos = dest
	if _map != null:
		_map.set_center(_tile_pos, false)
		_map.set_transport_tile(_transport_tile if _transport != Transport.FOOT else -1)
	_sync_creatures_to_map()
	_sync_moongate(true)
	_refresh_locate_hud()
	_push_message("Warp: %s" % str(item.get("label", "")), false)


func _handle_city_warp_input(event: InputEvent) -> bool:
	if not _city_warp_open:
		return false
	if event is InputEventJoypadMotion:
		var stick_step := _GameInput.stick_axis_step(event, JOY_AXIS_LEFT_Y)
		if stick_step != 0:
			_move_city_warp_cursor(stick_step)
		return true
	if not event.is_pressed() or event.is_echo():
		return false
	if _is_cancel_event(event):
		_close_city_warp()
		return true
	if event is InputEventKey and _is_mod_chord_key(event as InputEventKey) \
			and _is_city_warp_key(event as InputEventKey):
		_close_city_warp()
		return true
	if _GameInput.is_select(event) or event.is_action_pressed("confirm"):
		_choose_city_warp_item()
		return true
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ENTER or k.physical_keycode == KEY_ENTER \
				or k.keycode == KEY_KP_ENTER or k.physical_keycode == KEY_KP_ENTER:
			_choose_city_warp_item()
			return true
	var dir := _GameInput.dir_from_event(event)
	if dir.y != 0:
		_move_city_warp_cursor(dir.y)
		return true
	return true


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
	_refresh_journal_panel()
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
	_apply_remembered_city_chests(cmap)
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
	if not _is_mod_chord_key(event):
		return false
	var code := event.keycode
	var phys := event.physical_keycode
	return code == KEY_S or phys == KEY_S


func _is_fullscreen_key(event: InputEventKey) -> bool:
	## ⌘F (macOS) or Ctrl+F (Windows/Linux) — same modifier check as quick-save.
	if not _is_mod_chord_key(event):
		return false
	var code := event.keycode
	var phys := event.physical_keycode
	return code == KEY_F or phys == KEY_F or event.key_label == KEY_F


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
		## Same session slot we Journey-loaded or last wrote (not prefs last_saved alone).
		cursor = _SaveGame.default_load_cursor(GameState.session_loaded_slot)
	else:
		cursor = _SaveGame.default_save_cursor(
			GameState.session_loaded_slot,
			GameState.session_did_save,
			GameState.is_new_game
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
	_refresh_journal_panel()
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
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_LEFT_X:
			var stick_step := _GameInput.stick_axis_step(event, JOY_AXIS_LEFT_X)
			if stick_step != 0:
				_cycle_options_cursor_value(stick_step)
			return true
	if not event.is_pressed() or event.is_echo():
		return false
	if _options_horizontal_nudge(event):
		var dir := _options_language_delta(event)
		if dir != 0:
			_cycle_options_cursor_value(dir)
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


func _cycle_options_cursor_value(delta: int) -> void:
	_ensure_options_panel()
	if _options_panel == null:
		return
	var item: int = int(_options_panel.cursor())
	match item:
		_OptionsPanel.Item.LANGUAGE:
			_options_panel.cycle_language(delta)
			_layout_prompt_row()
		_OptionsPanel.Item.HANGUL_KEYBOARD:
			_options_panel.cycle_current(delta)
		_OptionsPanel.Item.RESOLUTION:
			_options_panel.cycle_resolution(delta)
		_OptionsPanel.Item.FULLSCREEN:
			_options_panel.cycle_fullscreen(delta)
		_:
			pass


func _cycle_options_language(delta: int) -> void:
	_ensure_options_panel()
	if _options_panel == null:
		return
	_options_panel.cycle_language(delta)
	_layout_prompt_row()


func _confirm_options_item(index: int) -> void:
	match index:
		_OptionsPanel.Item.LANGUAGE:
			_cycle_options_cursor_value(1)
		_OptionsPanel.Item.HANGUL_KEYBOARD:
			_cycle_options_cursor_value(1)
		_OptionsPanel.Item.RESOLUTION:
			_cycle_options_cursor_value(1)
		_OptionsPanel.Item.FULLSCREEN:
			_cycle_options_cursor_value(1)
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
		if _save_stage == 2 and _is_delete_save_key(k):
			_prompt_delete_load_slot()
			return true
		## Enter confirms the highlighted slot (load and save). Space is Pass, not confirm.
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


func _is_delete_save_key(k: InputEventKey) -> bool:
	## Windows/Linux Del, or Mac keyboard Delete (often KEY_BACKSPACE).
	return (
		k.keycode == KEY_DELETE or k.physical_keycode == KEY_DELETE
		or k.keycode == KEY_BACKSPACE or k.physical_keycode == KEY_BACKSPACE
	)


func _prompt_delete_load_slot() -> void:
	if _save_stage != 2 or _save_panel == null or not _save_panel.is_open():
		return
	var slot_index: int = int(_save_panel.cursor())
	var slot_n: int = slot_index + 1
	if not _SaveGame.slot_exists(slot_n):
		return
	QuitConfirm.prompt_delete_save(func() -> void:
		if not _SaveGame.delete_slot(slot_n):
			return
		if GameState.session_loaded_slot == slot_n:
			GameState.session_loaded_slot = 0
			GameState.session_did_save = false
		if _save_stage == 2 and _save_panel != null and is_instance_valid(_save_panel) and _save_panel.is_open():
			_save_panel.refresh()
		if not _SaveGame.any_slot_exists():
			var from_esc := _slot_from_esc
			_close_save(false)
			_push_message(Locale.t("load_deleted"), false)
			if from_esc:
				_open_esc_menu()
			else:
				_finish_party_turn()
		else:
			_push_message(Locale.t("load_deleted"), false)
	)


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
		"sides_open": _journal_saved_sides_open if _journal_focus_active else _sides_open,
		"transport": _transport,
		"transport_tile": _transport_tile,
		"horse_gallop": _horse_gallop,
		"balloon_flying": _balloon_flying,
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


func _on_world_ranged_fire(from: Vector2i, dir: Vector2i) -> void:
	## xu4 sea serpent / lava lizard / hydra / dragon specialAction.
	_pending_world_ranged.append({"from": from, "dir": dir})


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


func _world_ranged_along_async(origin: Vector2i, dir: Vector2i) -> void:
	## xu4 creatureRangeAttack along gameGetDirectionalActionPath(1..3).
	## Flashes each cell; hits party (hitPartyAtRange) or one-shots map objects.
	var path: Array[Vector2i] = _WorldCreaturesScript.cannon_path(
		origin, dir, _WorldCreaturesScript.WORLD_RANGED_RANGE
	)
	if path.is_empty():
		return
	const MISS_SEC := 0.10
	const HIT_SEC := 0.36
	_cannon_busy = true
	for pos in path:
		if pos == _tile_pos:
			if _map != null:
				await _map.await_flash_world_tile(pos, MapView.TILE_HIT_FLASH, HIT_SEC)
			_apply_cannon_hit_on_party()
			break
		var creature_tid := -1
		if _world_creatures != null:
			creature_tid = _world_creatures.creature_at(pos)
		if creature_tid >= 0:
			if _world_creatures != null:
				_world_creatures.take_at(pos)
				_sync_creatures_to_map()
			if _map != null:
				await _map.await_flash_world_tile(pos, MapView.TILE_HIT_FLASH, HIT_SEC)
			break
		var overlay_tid := -1
		if _map != null:
			overlay_tid = _map.overlay_at(pos)
		if overlay_tid >= 0:
			## xu4 UNKNOWN objects: destroy (ships one-shot here, not progressive).
			if MapView.is_ship_tile(overlay_tid):
				var key := _ship_hull_key(pos)
				_ship_hulls.erase(key)
			if _map != null:
				_map.remove_overlay_at(pos)
				await _map.await_flash_world_tile(pos, MapView.TILE_HIT_FLASH, HIT_SEC)
			break
		## Empty tile: miss flash still advances along the path (xu4 flashTile 1).
		if _map != null:
			await _map.await_flash_world_tile(pos, MapView.TILE_HIT_FLASH, MISS_SEC)
	_cannon_busy = false


func _party_wiped_or_dying() -> bool:
	## Party is fully dead, or the death cutscene already owns the screen.
	return _death_busy or GameState.is_party_dead()


func _update_world_creatures() -> void:
	## xu4 finishTurn: moveObjects → creatureCleanup → checkRandomCreatures
	## → checkBridgeTrolls.
	## Creatures act sequentially; after a lethal pirate shot, stop further AI / combat.
	## xu4: no spawn/move/attack while balloon is aloft (isFlying).
	if _combat_active or _is_in_city() or _world == null or not _world.loaded:
		return
	if _is_balloon_flying():
		return
	if _world_creatures == null:
		return
	if _party_wiped_or_dying():
		return
	_pending_pirate_shots.clear()
	_pending_world_ranged.clear()
	var moved: Dictionary = _world_creatures.move_all(
		_world,
		_tile_pos,
		_creature_spawn_blocked,
		_on_pirate_cannon_fire,
		_on_world_ranged_fire
	)
	var changed := bool(moved.get("changed", false))
	## Fire each broadside in order; abort if the party is wiped mid-queue.
	for shot in _pending_pirate_shots:
		if _party_wiped_or_dying():
			return
		await _fire_cannon_along_async(shot["from"], shot["dir"], false)
		if _party_wiped_or_dying():
			return
	## Sea serpent / lava lizard / hydra / dragon world ranged after pirate AI.
	for shot in _pending_world_ranged:
		if _party_wiped_or_dying():
			return
		await _world_ranged_along_async(shot["from"], shot["dir"])
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
	## xu4 checkBridgeTrolls after random spawn (same finishTurn pass).
	if _party_wiped_or_dying() or _combat_active:
		return
	await _check_bridge_trolls()


func _check_bridge_trolls() -> void:
	## xu4 GameController::checkBridgeTrolls:
	## world map + underfoot tile name == bridge + 1/8 → "Bridge Trolls!" on BRIDGE.CON.
	## Note: only tile 23 (bridge), not bridge_n / bridge_s (xu4 Tile::sym.bridge).
	if _combat_active or _is_in_city() or _world == null or not _world.loaded:
		return
	if _party_wiped_or_dying():
		return
	var ground := int(_world.tile_at(_tile_pos.x, _tile_pos.y))
	if ground != MapView.TILE_BRIDGE:
		return
	if (randi() % 8) != 0:
		return
	_push_message(Locale.t("cmd_bridge_trolls"), false)
	## MAP_BRIDGE_CON = bridge.con (force map; not combatMapForTile).
	var cmap = null
	var path := _CombatMapData.resolve_u4_file("BRIDGE.CON")
	if not path.is_empty():
		var loaded: _CombatMapData = _CombatMapData.new()
		if loaded.load_from_path(path):
			cmap = loaded
	if cmap == null:
		cmap = _CombatMaps.load_for_encounter(
			MapView.TILE_BRIDGE, 164, false, false
		)
	if cmap == null:
		return
	## TROLL_ID 30 → tile 164; skip second "Attacked by…" (xu4 only prints Bridge Trolls!).
	var foe := {
		"tile": 164,
		"x": _tile_pos.x,
		"y": _tile_pos.y,
		"facing": 0,
		"skip_attacked_by": true,
	}
	await _begin_combat(foe, false, cmap, false)


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
	if _ztats_stage == 2 and event is InputEventJoypadMotion:
		## Analog page/scroll navigation uses one deliberate tilt per step.
		## Neutral events must reach the helper so the axis can re-arm.
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_LEFT_X:
			var page_step := _GameInput.stick_axis_step(event, JOY_AXIS_LEFT_X)
			if page_step != 0:
				_nudge_ztats_view(page_step)
			return true
		if motion.axis == JOY_AXIS_LEFT_Y:
			var scroll_step := _GameInput.stick_axis_step(event, JOY_AXIS_LEFT_Y)
			if scroll_step != 0 and _ztats_panel and _ztats_panel.is_inventory_page():
				_ztats_panel.scroll_inventory(scroll_step)
			return true
		return true
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
	## Viewing sheet: Esc / Enter close; Z returns to pick list.
	if _ztats_stage == 2:
		if _is_cancel_event(event):
			_close_ztats(false)
			return true
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
	## Esc / Enter close the sheet. Space is Pass, not dismiss.
	if event is InputEventKey:
		var k := event as InputEventKey
		var code := k.keycode
		var phys := k.physical_keycode
		return (
			code == KEY_ESCAPE or phys == KEY_ESCAPE
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
	var entering_view := _ztats_stage != 2
	_ztats_stage = 2
	if entering_view:
		_GameInput.reset_stick_navigation()
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
	var entering_view := _ztats_stage != 2
	_ztats_stage = 2
	if entering_view:
		_GameInput.reset_stick_navigation()
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
	## Gamepad entry lists A–Z so unmixed spells can be chosen without A–Z keys.
	_clear_pending_order()
	_close_ztats(false)
	_close_ready(false)
	_close_wear(false)
	_close_use(false)
	_mix_pad_full_list = _mix_gamepad_requested
	_mix_gamepad_requested = false
	if not GameState.has_any_reagents():
		_mix_pad_full_list = false
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
		_mix_panel.open_list(_mix_pad_full_list)
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
		_mix_panel.open_list(_mix_pad_full_list)
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
		_mix_panel.open_list(_mix_pad_full_list)
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
		## Open full A–Z list (unknown gray). Letter-only wait had no panel change.
		_mix_pad_full_list = true
		_mix_stage = 1
		_mix_panel.open_list(true)
		_cursor_to_first_unknown_mix()
		_layout_prompt_row()
		return
	if row_id >= 0:
		if GameState.is_spell_known(row_id):
			_try_remix_spell(row_id)
		else:
			## Full A–Z list: pick unmixed spell → reagent picker.
			_begin_new_mix(row_id)


func _cursor_to_first_unknown_mix() -> void:
	## Prefer first never-mixed spell when opening A–Z from Mix New.
	if _mix_panel == null:
		return
	for sid in Spells.COUNT:
		if not GameState.is_spell_known(sid):
			var idx: int = int(_mix_panel.index_of_spell(sid))
			if idx >= 0:
				_mix_panel.set_cursor(idx)
			return


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
			_mix_panel.open_list(_mix_pad_full_list)
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
		_mix_panel.open_list(_mix_pad_full_list)
		var idx: int = int(_mix_panel.index_of_spell(spell_id))
		if idx >= 0:
			_mix_panel.set_cursor(idx)
		_layout_prompt_row()
		return
	## Failure — reagents stay spent; leave Mix.
	_mix_panel.close_panel()
	_push_message(Locale.t("mix_failed"), false)
	_mix_stage = 0
	_mix_pad_full_list = false
	_mix_gamepad_requested = false
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
		_mix_pad_full_list = false
		_mix_gamepad_requested = false
		return
	if was == 2 and _mix_panel:
		_mix_panel.revert_selected_reagents()
	_mix_stage = 0
	_mix_pad_full_list = false
	_mix_gamepad_requested = false
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
	## xu4 'e' → usePortalAt(ACTION_ENTER). Cities + shrines.
	if _is_in_city():
		_push_message(Locale.t("cmd_enter_what"), false)
		return
	if _shrine_stage != 0:
		return
	if _transport == Transport.SHIP or _transport == Transport.BALLOON:
		_push_message(Locale.t("cmd_only_on_foot"), false)
		return
	var shrine_p := _ShrinePortals.portal_at(_tile_pos)
	if not shrine_p.is_empty():
		_try_enter_shrine(shrine_p)
		return
	var portal := _WorldPortals.portal_at(_tile_pos)
	if portal.is_empty():
		_push_message(Locale.t("cmd_enter_what"), false)
		return
	_enter_city_from_portal(portal)


func _localized_portal_name(portal: Dictionary) -> String:
	var place_id := _WorldPortals.place_id_for_portal(portal)
	var name_s := str(portal.get("name", "?"))
	if not place_id.is_empty():
		var labeled := Locale.place(place_id)
		if not labeled.is_empty() and labeled != "place_%s" % place_id:
			name_s = labeled
	return name_s


func _enter_confirm_place_phrase(portal: Dictionary) -> String:
	## e.g. "Britain" / "브리튼 마을" for the walk-on prompt.
	var name_s := _localized_portal_name(portal)
	var kind := int(portal.get("kind", _WorldPortals.CityKind.TOWNE))
	## Castle/place labels often already include the kind (e.g. Britannia Castle).
	if kind == _WorldPortals.CityKind.CASTLE:
		return name_s
	var kind_name := Locale.t(_WorldPortals.kind_locale_key(kind))
	if str(GameState.language) == "ko":
		return "%s %s" % [name_s, kind_name]
	return name_s


func _clear_enter_prompt_decline_if_left() -> void:
	if _enter_prompt_declined.x <= -99990:
		return
	if _tile_pos != _enter_prompt_declined:
		_enter_prompt_declined = Vector2i(-99999, -99999)


func _maybe_offer_enter_prompt() -> void:
	## Gamepad only: standing on a world city/castle portal offers Yes/No enter.
	if _enter_prompt_stage != 0:
		return
	if _is_in_city() or _combat_active or _talk_stage != 0:
		return
	if _transport == Transport.SHIP or _transport == Transport.BALLOON:
		return
	if not _GameInput.is_move_from_gamepad():
		return
	_clear_enter_prompt_decline_if_left()
	if _tile_pos == _enter_prompt_declined:
		return
	var portal := _WorldPortals.portal_at(_tile_pos)
	if portal.is_empty():
		return
	_open_enter_prompt(portal)


func _open_enter_prompt(portal: Dictionary) -> void:
	_enter_prompt_stage = 1
	_enter_prompt_choice = 0
	_GameInput.reset_stick_navigation()
	_reset_hold_state()
	_block_dir_until_keyup = true
	_push_message(Locale.t("cmd_enter_confirm", [_enter_confirm_place_phrase(portal)]), false)
	_rebuild_choice_buttons(2)
	_layout_prompt_row()
	_sync_enter_prompt_style()


func _close_enter_prompt_ui() -> void:
	_enter_prompt_stage = 0
	if _enter_btn_row != null:
		_enter_btn_row.visible = false
	for btn in _choice_btns:
		if btn != null and btn.has_focus():
			btn.release_focus()
	if _msg_prompt_row != null:
		_msg_prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout_prompt_row()
	grab_focus()


func _resolve_enter_prompt(yes: bool) -> void:
	if _enter_prompt_stage != 1:
		return
	_push_message(Locale.t("cmd_yes" if yes else "cmd_no"), false)
	_close_enter_prompt_ui()
	if yes:
		_enter_prompt_declined = Vector2i(-99999, -99999)
		_do_enter()
	else:
		## Stay on the tile; only re-prompt after leaving and returning.
		_enter_prompt_declined = _tile_pos


func _handle_enter_prompt_input(event: InputEvent) -> bool:
	## Explore/shop choices: left/right hold-repeat is polled in
	## _tick_dialogue_choice_nav. Combat exit Y/N still steps per event.
	var poll_nav := _dialogue_choice_hold_active()
	if event is InputEventJoypadMotion:
		if not poll_nav:
			var stick_step := _GameInput.stick_axis_step(event, JOY_AXIS_LEFT_X)
			if stick_step != 0 and not _prompt_choice_keys().is_empty():
				_set_enter_prompt_choice(_enter_prompt_choice + stick_step)
		return true
	if not event.is_pressed():
		return false
	var keys := _prompt_choice_keys()
	if keys.is_empty():
		return false
	if event.is_echo():
		## Polled UIs swallow echo dirs; combat exit ignores them.
		if poll_nav and event is InputEventKey:
			var ek := event as InputEventKey
			if (
				ek.keycode == KEY_LEFT or ek.physical_keycode == KEY_LEFT
				or ek.keycode == KEY_RIGHT or ek.physical_keycode == KEY_RIGHT
			):
				return true
		return false
	var dir := _GameInput.dir_from_event(event)
	if dir.x != 0:
		if not poll_nav:
			_set_enter_prompt_choice(_enter_prompt_choice + dir.x)
		return true
	if event is InputEventKey:
		var k := event as InputEventKey
		var ch := _key_latin_command_char(k)
		if ch.is_empty():
			## Digits for Minoc inn beds.
			var dig := _key_digit_char(k)
			if not dig.is_empty():
				ch = dig
		if not ch.is_empty():
			var idx := keys.find(ch)
			if idx >= 0:
				_resolve_prompt_choice_index(idx)
				return true
	if _GameInput.is_select(event) or event.is_action_pressed("confirm") or event.is_action_pressed("ui_accept"):
		_resolve_prompt_choice_index(_enter_prompt_choice)
		return true
	if _is_cancel_event(event):
		## Buy/Sell / room pick: B/Esc soft-cancels shop; Y/N uses No.
		if keys == "bs" or keys == "123":
			if _talk_stage == 10 and _shop != null:
				_shop.on_escape()
				_flush_shop_output()
				return true
		var no_i := keys.find("n")
		if no_i >= 0:
			_resolve_prompt_choice_index(no_i)
			return true
		if _talk_stage == 10 and _shop != null:
			_shop.on_escape()
			_flush_shop_output()
			return true
		return true
	return true


func _enter_city_from_portal(portal: Dictionary) -> void:
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
	var city_name := _localized_portal_name(portal)
	## xu4: "Enter towne!\n\n" then centered city name — we push both lines.
	_push_message(Locale.t("cmd_enter_type", [kind_name]), false)
	_push_message(city_name, false)
	_city_return_pos = _tile_pos
	## Fresh enter from world — anger reset (xu4 forgets next visit).
	_city_guards_alerted = false
	_city_map = cmap
	_apply_remembered_city_chests(cmap)
	var start := Vector2i(int(portal.get("sx", 1)), int(portal.get("sy", 15)))
	_tile_pos = start
	if _map != null:
		_map.enter_city(cmap, start, _city_return_pos)
		## Re-apply mount sprite immediately (enter used to wipe MapView transport).
		_map.set_transport_tile(_transport_tile if _transport != Transport.FOOT else -1)
		_map.clear_moongate()
	_maybe_capture_manual_zorin_tip(fname)
	## xu4 endTurn = 0 on successful enter — do not finish party turn.


func _maybe_capture_manual_zorin_tip(fname: String) -> void:
	## Way of the Avatar: seek Zorin in Castle Britannia (first LCB enter).
	var f := fname.strip_edges().to_lower()
	if f != "lcb_1.ult" and f != "lcb_2.ult":
		return
	if not GameState.journal_try_capture("lcb", "The Way of the Avatar", "ENTER"):
		return
	_refresh_journal_panel()


func _maybe_complete_manual_zorin_tip() -> bool:
	## Talking to Zorin fulfills the manual hint.
	var changed := false
	if GameState.journal_mark_id("lcb.manual.zorin"):
		changed = true
	if GameState.journal_mark_goal("ask:zorin"):
		changed = true
	return changed


func _open_sides_for_shrine() -> void:
	## Force both side panels + tall message strip open for the shrine script.
	_shrine_saved_sides_open = _sides_open
	## Talk-only tall strip is obsolete while inventory sides are forced open.
	if _talk_msg_open:
		_talk_msg_open = false
	_order_opened_roster = false
	var need_anim := not _sides_open
	_sides_open = true
	_refresh_party()
	if need_anim:
		_layout_side_panels(true)
		await _await_side_tween()
	else:
		_layout_side_panels(false)


func _restore_sides_after_shrine() -> void:
	## Return left/right/message layout to the pre-enter state.
	_order_opened_roster = false
	if _shrine_saved_sides_open:
		_sides_open = true
		_layout_side_panels(false)
	else:
		_sides_open = false
		_layout_side_panels(true)
		await _await_side_tween()


func _try_enter_shrine(portal: Dictionary) -> void:
	## xu4 shrineCanEnter + setMap(shrine) + Shrine::enter (walk-in sequence).
	var virtue := int(portal.get("virtue", -1))
	if not _Shrine.can_enter_with_rune(virtue):
		_push_message(Locale.t("cmd_shrine_no_rune"), false)
		_finish_party_turn()
		return
	var path := _CombatMapData.resolve_u4_file("shrine.con")
	var smap = _CombatMapData.new()
	if path.is_empty() or not smap.load_shrine_from_path(path):
		_push_message(Locale.t("cmd_enter_fail"), false)
		return
	_push_message(Locale.t("cmd_enter_shrine"), false)
	_push_message(_ShrinePortals.shrine_name(portal), false)
	if _map != null:
		## Spirituality has no world shrine tile — moongate stands on gate terrain;
		## force L/R voids to grass so the cutscene is not framed by water/gate.
		var plain := virtue == Virtues.Id.SPIRITUALITY
		_map.enter_shrine(smap, plain)
		_map.set_transport_tile(-1)
		_map.clear_moongate()
	_shrine_virtue = virtue
	_shrine_cycles = 0
	_shrine_completed = 0
	_shrine_buffer = ""
	_shrine_ejecting = false
	_shrine_session = true
	_stamp_command_time()
	_shrine_enter_async()


func _shrine_enter_async() -> void:
	await _open_sides_for_shrine()
	if not _shrine_session or _shrine_ejecting:
		return
	_shrine_approach_async()


func _shrine_approach_async() -> void:
	## xu4 enhancedSequence: spawn south, step north to altar, then kneel prompts.
	_shrine_stage = 0
	_shrine_busy = true
	_layout_prompt_row()
	_push_message(Locale.t("cmd_shrine_approach"), false)
	if _map != null:
		_map.set_shrine_walker(SHRINE_WALK_START)
	await get_tree().create_timer(SHRINE_WALK_STEP_SEC).timeout
	## Four north steps: (5,10) → (5,6)
	for step in 4:
		if _shrine_stage != 0 or _shrine_ejecting:
			_shrine_busy = false
			return
		var y := SHRINE_WALK_START.y - (step + 1)
		if _map != null:
			_map.set_shrine_walker(Vector2i(SHRINE_WALK_START.x, y))
		await get_tree().create_timer(SHRINE_WALK_STEP_SEC).timeout
	if _shrine_ejecting:
		_shrine_busy = false
		return
	await get_tree().create_timer(SHRINE_WALK_STEP_SEC * 2.0).timeout
	if _shrine_ejecting:
		_shrine_busy = false
		return
	_push_message(Locale.t("cmd_shrine_kneel"), false)
	await get_tree().create_timer(SHRINE_WALK_STEP_SEC).timeout
	if _shrine_ejecting:
		_shrine_busy = false
		return
	_push_message(Locale.t("cmd_shrine_virtue_ask"), false)
	_shrine_busy = false
	_shrine_stage = 1
	_shrine_buffer = ""
	_stamp_command_time()
	_layout_prompt_row()


func _handle_shrine_input(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if _shrine_busy or _shrine_ejecting or _shrine_stage == 0 or _shrine_stage == 6:
		return true
	if _shrine_stage == 1:
		return _handle_shrine_virtue_input(event)
	if _shrine_stage == 2:
		return _handle_shrine_cycles_input(event)
	if _shrine_stage == 4:
		return _handle_shrine_mantra_input(event)
	if _shrine_stage == 5:
		return _handle_shrine_vision_key(event)
	return true


func _handle_shrine_virtue_input(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return true
	var k := event as InputEventKey
	if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
		_shrine_buffer = ""
		_shrine_on_unfocused()
		return true
	if _is_order_confirm_key(k):
		var typed := _shrine_buffer
		_shrine_buffer = ""
		_layout_prompt_row()
		if typed.strip_edges().is_empty():
			_shrine_on_unfocused()
			return true
		_push_message(typed.strip_edges(), false)
		if not _Shrine.virtue_input_matches(_shrine_virtue, typed):
			_shrine_on_unfocused()
			return true
		_push_message(Locale.t("cmd_shrine_cycles_ask"), false)
		_shrine_stage = 2
		_layout_prompt_row()
		return true
	if k.keycode == KEY_BACKSPACE or k.physical_keycode == KEY_BACKSPACE:
		if not _shrine_buffer.is_empty():
			_shrine_buffer = _shrine_buffer.substr(0, _shrine_buffer.length() - 1)
			_layout_prompt_row()
		return true
	var ch := _shrine_char_from_key(k)
	if ch.is_empty():
		return true
	if _shrine_buffer.length() >= 32:
		return true
	_shrine_buffer += ch
	_layout_prompt_row()
	return true


func _handle_shrine_cycles_input(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return true
	var k := event as InputEventKey
	if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
		_shrine_on_unfocused()
		return true
	if k.keycode == KEY_ENTER or k.physical_keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		## xu4 Enter → cycles = 0 → unfocused.
		_shrine_on_unfocused()
		return true
	var dig := -1
	for code in [k.keycode, k.physical_keycode]:
		if code >= KEY_0 and code <= KEY_3:
			dig = int(code - KEY_0)
			break
		if code >= KEY_KP_0 and code <= KEY_KP_3:
			dig = int(code - KEY_KP_0)
			break
	if dig < 0 and k.unicode >= 48 and k.unicode <= 51:
		dig = int(k.unicode - 48)
	if dig < 0:
		return true
	_shrine_cycles = dig
	_push_message(str(dig), false)
	if dig == 0:
		_shrine_on_unfocused()
		return true
	if not _Shrine.meditation_fatigue_ok():
		_push_message(Locale.t("cmd_shrine_weary"), false)
		_shrine_eject()
		return true
	_shrine_completed = 0
	_shrine_begin_meditation_async()
	return true


func _handle_shrine_mantra_input(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return true
	var k := event as InputEventKey
	if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
		## xu4 Escape still submits empty → bad mantra.
		_shrine_buffer = ""
		_shrine_submit_mantra("")
		return true
	if _is_order_confirm_key(k):
		var typed := _shrine_buffer
		_shrine_buffer = ""
		_layout_prompt_row()
		_shrine_submit_mantra(typed)
		return true
	if k.keycode == KEY_BACKSPACE or k.physical_keycode == KEY_BACKSPACE:
		if not _shrine_buffer.is_empty():
			_shrine_buffer = _shrine_buffer.substr(0, _shrine_buffer.length() - 1)
			_layout_prompt_row()
		return true
	var ch := _shrine_char_from_key(k)
	if ch.is_empty():
		return true
	if _shrine_buffer.length() >= 4:
		return true
	_shrine_buffer += ch
	_layout_prompt_row()
	return true


func _handle_shrine_vision_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return true
	var k := event as InputEventKey
	## xu4 waitAnyKey after vision / advice. Space is Pass, not advance.
	if (
		k.keycode == KEY_ESCAPE
		or k.physical_keycode == KEY_ESCAPE
		or _is_order_confirm_key(k)
	):
		_shrine_eject()
		return true
	## Any printable key advances, except space.
	if (k.unicode > 32) or (k.keycode >= KEY_A and k.keycode <= KEY_Z):
		_shrine_eject()
		return true
	return true


func _shrine_char_from_key(k: InputEventKey) -> String:
	if k.unicode >= 32 and k.unicode < 127:
		return String.chr(k.unicode)
	for code in [k.keycode, k.physical_keycode]:
		if code >= KEY_A and code <= KEY_Z:
			var base := int(code - KEY_A)
			return String.chr(65 + base) if k.shift_pressed else String.chr(97 + base)
	return ""


func _shrine_on_unfocused() -> void:
	_push_message(Locale.t("cmd_shrine_unfocused"), false)
	_shrine_eject()


func _shrine_begin_meditation_async() -> void:
	_shrine_stage = 3
	_shrine_busy = true
	_layout_prompt_row()
	_push_message(Locale.t("cmd_shrine_begin"), false)
	_Shrine.mark_meditation_done()
	var acc := ""
	for _i in _Shrine.MANTRAS_PER_CYCLE:
		await get_tree().create_timer(_Shrine.DOT_INTERVAL_SEC).timeout
		if _shrine_stage != 3:
			_shrine_busy = false
			return
		acc += "."
		_shrine_replace_or_push_dots(acc)
	_shrine_busy = false
	_push_message(Locale.t("cmd_shrine_mantra"), false)
	_shrine_stage = 4
	_shrine_buffer = ""
	_layout_prompt_row()


func _shrine_replace_or_push_dots(acc: String) -> void:
	if not _msg_lines.is_empty() and str(_msg_lines[-1]).begins_with("."):
		_msg_lines[_msg_lines.size() - 1] = acc
	else:
		_msg_lines.append(acc)
	while _msg_lines.size() > MSG_KEEP:
		_msg_lines.remove_at(0)
	_refresh_message_view()


func _shrine_submit_mantra(typed: String) -> void:
	var shown := typed.strip_edges()
	if not shown.is_empty():
		_push_message(shown, false)
	if not _Shrine.mantra_matches(_shrine_virtue, typed):
		GameState.adjust_karma_bad_mantra()
		_push_message(Locale.t("cmd_shrine_bad_mantra"), false)
		_shrine_eject()
		return
	_shrine_cycles -= 1
	_shrine_completed += 1
	GameState.adjust_karma_meditation()
	if GameState.journal_mark_mantra(_shrine_virtue):
		_refresh_journal_panel()
	_refresh_party()
	if _shrine_cycles > 0:
		_shrine_begin_meditation_async()
		return
	## Final cycle complete — elevate or advice vision.
	var elevated := _shrine_completed == 3 and GameState.attempt_elevation(_shrine_virtue)
	if elevated:
		_push_message(
			Locale.t("cmd_shrine_partial", [Virtues.name_of(_shrine_virtue, GameState.lang_short())]),
			false
		)
		if _map != null:
			_map.play_spell_flash()
		_push_message(Locale.t("cmd_shrine_vision_elevated"), false)
	else:
		_push_message(Locale.t("cmd_shrine_vision"), false)
		var adv := _Shrine.advice_for(_shrine_virtue, _shrine_completed)
		if not adv.is_empty():
			_push_message(adv, false)
	_shrine_stage = 5
	_layout_prompt_row()


func _shrine_eject() -> void:
	## xu4 Shrine::eject — walk out south, then parent map + finishTurn.
	if _shrine_ejecting:
		return
	_shrine_eject_async()


func _shrine_eject_async() -> void:
	_shrine_ejecting = true
	_shrine_busy = true
	_shrine_buffer = ""
	_layout_prompt_row()
	## Walk south from altar (or current walker) to south edge, then off-map.
	var start_y := SHRINE_WALK_ALTAR.y
	if _map != null:
		## Ensure walker is visible at altar before reverse walk.
		_map.set_shrine_walker(SHRINE_WALK_ALTAR)
	for step in range(start_y + 1, SHRINE_WALK_START.y + 1):
		if _map != null:
			_map.set_shrine_walker(Vector2i(SHRINE_WALK_START.x, step))
		await get_tree().create_timer(SHRINE_WALK_STEP_SEC).timeout
	if _map != null:
		## One step south of the map so the sprite vanishes before cut.
		_map.set_shrine_walker(Vector2i(SHRINE_WALK_START.x, SHRINE_WALK_START.y + 1))
	await get_tree().create_timer(SHRINE_WALK_STEP_SEC * 0.5).timeout
	_shrine_stage = 0
	_shrine_cycles = 0
	_shrine_completed = 0
	_shrine_busy = false
	_shrine_ejecting = false
	if _map != null:
		_map.exit_shrine()
		_map.set_center(_tile_pos, false)
		_map.set_transport_tile(_transport_tile if _transport != Transport.FOOT else -1)
	_sync_moongate(true)
	await _restore_sides_after_shrine()
	_shrine_session = false
	_layout_prompt_row()
	_refresh_party()
	_finish_party_turn()


func _do_klimb() -> void:
	## xu4 'k' → usePortalAt(ACTION_KLIMB); else balloon Klimb altitude.
	if _try_city_floor_portal(_CityFloorPortals.Action.CLIMB):
		return
	if _transport == Transport.BALLOON:
		_balloon_flying = true
		_sync_balloon_view()
		_push_message(Locale.t("cmd_klimb_altitude"), false)
		_finish_party_turn()
		return
	_push_message(Locale.t("cmd_klimb_what"), false)
	_finish_party_turn()


func _do_descend() -> void:
	## xu4 'd' → usePortalAt(ACTION_DESCEND); else Land Balloon.
	if _try_city_floor_portal(_CityFloorPortals.Action.DESCEND):
		return
	if _transport == Transport.BALLOON:
		_push_message(Locale.t("cmd_land_balloon"), false)
		if not _balloon_flying:
			_push_message(Locale.t("cmd_already_landed"), false)
		elif _TileRules.can_land_balloon(_terrain_tid_at(_tile_pos)):
			_balloon_flying = false
			_sync_balloon_view()
		else:
			_push_message(Locale.t("cmd_not_here"), false)
		_finish_party_turn()
		return
	_push_message(Locale.t("cmd_descend_what"), false)
	_finish_party_turn()


func _try_city_floor_portal(action: int) -> bool:
	## True if a city floor ladder was used (success or foot-only fail after city hit).
	## Mirror xu4: portal attempt only when an ACTION_* portal exists; balloon handles miss.
	if not _is_in_city() or _city_map == null or not _city_map.loaded:
		return false
	var fname := str(_city_map.source_path).get_file()
	var portal := _CityFloorPortals.portal_at(fname, _tile_pos, action)
	if portal.is_empty():
		return false
	## Portal exists — take the same path as before (including "Only on foot!").
	_use_city_floor_portal(action)
	return true


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
	_apply_remembered_city_chests(cmap)
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


func _apply_remembered_city_chests(cmap) -> void:
	if cmap == null or not cmap.loaded or not cmap.has_method("remove_remembered_chests"):
		return
	var fname := _city_map_fname(cmap)
	if fname.is_empty():
		return
	var bucket: Variant = _city_chest_memory.get(fname, {})
	if typeof(bucket) != TYPE_DICTIONARY:
		return
	var keys: Array = []
	for key in (bucket as Dictionary).keys():
		if bool((bucket as Dictionary)[key]):
			keys.append(str(key))
	cmap.remove_remembered_chests(keys)


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
	if _talk_stage != 0:
		_end_talk_keyword_menu()
		_talk_stage = 0
		_talk_person_i = -1
		_talk_entry = null
		_talk_buffer = ""
		_reset_talk_hangul()
		_talk_keywords.clear()
		_talk_pending_ask = false
		_talk_is_hawkwind = false
		_talk_is_lb = false
		_talk_msg_open = false
		_shop = null
		if _talk_msg_tween != null and is_instance_valid(_talk_msg_tween):
			_talk_msg_tween.kill()
			_talk_msg_tween = null
		_clear_shop_character_inv()
		## Drop talk-only character peek before leaving city.
		if not _sides_open and _order_opened_roster:
			_order_opened_roster = false
			_layout_side_panels(false)
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
	## U5: Set a watch? — Y / N (A=Yes, B/Esc=cancel→None).
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
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
	## Digits / ↑↓+Enter / gamepad D-pad+A. Esc / B cancel. Space is Pass, ignored here.
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
	## Confirm: Enter or gamepad A.
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
	## Relocate under blackout, then fade into the throne room.
	_death_revive()
	if not is_inside_tree() or not _death_busy:
		_abort_death_sequence()
		return
	await _death_fade_from_black(DEATH_FADE_IN_SEC)
	if not is_inside_tree() or not _death_busy:
		_abort_death_sequence()
		return
	_death_busy = false
	if _msg_cursor:
		_msg_cursor.visible = true
	_layout_prompt_row()


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


func _death_fade_from_black(duration: float) -> void:
	## Soft fade-in after revive at Lord British (map already relocated under black).
	if _map_pane == null or _map == null:
		_set_death_blackout(false)
		return
	_ensure_death_blackout()
	_kill_death_fade_tween()
	_death_blackout.visible = true
	_death_blackout.color = Color.BLACK
	_death_blackout.modulate = Color(1, 1, 1, 1)
	if duration <= 0.0:
		_set_death_blackout(false)
		return
	_death_fade_tween = create_tween()
	_death_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_death_fade_tween.tween_property(
		_death_blackout, "modulate:a", 0.0, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _death_fade_tween.finished
	_death_fade_tween = null
	if _death_blackout != null and is_instance_valid(_death_blackout):
		_death_blackout.visible = false
		_death_blackout.modulate = Color(1, 1, 1, 1)


func _set_death_blackout(on: bool) -> void:
	## Hard snap blackout on/off (abort path). Revive uses fade-in instead.
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
	if _journal_focus_active:
		_close_journal_focus(false)
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
	_combat_exit_prompt = false
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
	## Stay blacked out; caller fades in once the throne room is ready.
	_set_death_blackout(true)
	## Leave combat / city / camp without printing exit chatter.
	if _map != null and _map.is_in_combat():
		_map.exit_combat()
	_combat_active = false
	_combat_resolving = false
	_combat_victory_aftermath = false
	_victory_solo_party_slot = -1
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
		_apply_remembered_city_chests(cmap)
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
	## Skipped while balloon is flying (party not "standing" on the tile).
	if _is_balloon_flying():
		return 0
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
	if _ztats_stage != 0 or _order_stage != 0 or _ready_stage != 0 or _wear_stage != 0 or _mix_stage != 0 or _use_stage != 0 or _camp_stage != 0 or _shrine_session or _shrine_stage != 0 or _shrine_busy or _inn_stage != 0 or _chest_open_stage != 0 or _telescope_stage != 0 or _save_stage != 0 or _talk_stage != 0 or _enter_prompt_stage != 0 or _command_menu_open or _city_warp_open or _journal_focus_active or _esc_menu_is_open() or _options_panel_is_open():
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
	var preserve_gamepad_talk := (
		cmd == U4Commands.Id.TALK and _talk_gamepad_requested
	)
	## Keep this press from also walking / free-roaming after Open/Get/etc.
	_clear_pending_dir(false)
	_block_dir_until_keyup = true
	_reset_hold_state()
	if preserve_gamepad_talk:
		_talk_gamepad_requested = true
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
		U4Commands.Id.TALK:
			var talked := _do_talk(dir)
			if talked:
				## Conversation owns the input loop; turn ends on Bye.
				return
			result = Locale.t("cmd_no_response")
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


func _do_talk(dir: Vector2i) -> bool:
	## xu4 talk() path: 1–2 steps; only continue past a cell that is talk-over
	## (shop letter counters). Ordinary townsfolk must be adjacent (1 step).
	if not _is_in_city() or _city_map == null or not _city_map.loaded:
		_talk_gamepad_requested = false
		return false
	for dist in range(1, 3):
		var target := Vector2i(_tile_pos.x + dir.x * dist, _tile_pos.y + dir.y * dist)
		if (
			target.x < 0 or target.y < 0
			or target.x >= _CityMapData.WIDTH
			or target.y >= _CityMapData.HEIGHT
		):
			break
		var pi: int = int(_city_map.person_index_at(target.x, target.y))
		if pi >= 0 and _talk_can_address(pi, dist):
			## LB / Hawkwind / vendors: maps.b role wins, even if .ULT still has a
			## .TLK conv id (e.g. Lord British occupying Joshua's discourse slot).
			var role: int = int(_city_map.role_at(pi))
			if _CityNpcRoles.is_shop_like(role):
				_begin_special_npc_talk(pi, role)
				return true
			var entry: Variant = _city_map.discourse_at(pi)
			if entry != null:
				_begin_talk(pi, entry)
				return true
		## After this cell: stop unless it is a talk-over tile (xu4 canTalkOver).
		var cell_tid: int
		if pi >= 0:
			## Person object occupies the cell — not talk-over; cannot reach past them.
			cell_tid = int(_city_map.persons[pi].z)
		else:
			cell_tid = int(_city_map.effective_tile_at(target.x, target.y))
		if not _TileRules.can_talk_over(cell_tid):
			break
	_talk_gamepad_requested = false
	return false


func _begin_special_npc_talk(person_i: int, role: int) -> void:
	_city_map.pause_follow(person_i)
	_open_talk_message_panel()
	match role:
		_CityNpcRoles.Role.LORD_BRITISH:
			_begin_lord_british_talk(person_i)
		_CityNpcRoles.Role.HAWKWIND:
			_begin_hawkwind_talk(person_i)
		_:
			## Vendor conversations use their own contextual choices, not keywords.
			_end_talk_keyword_menu()
			_begin_vendor_shop(person_i, role)


func _begin_lord_british_talk(person_i: int) -> void:
	## xu4 Lord British audience — intro, keyword help, heal, level advance.
	_talk_person_i = person_i
	_talk_entry = null
	_talk_buffer = ""
	_reset_talk_hangul()
	_talk_turn_away = 0
	_talk_pending_ask = false
	_talk_is_hawkwind = false
	_talk_is_lb = true
	_talk_keywords = _LordBritish.highlight_keywords()
	_shop = null
	_begin_talk_keyword_menu_if_requested()
	var revive := _LordBritish.revive_leader_if_dead()
	if not revive.is_empty():
		_push_talk_script(revive)
	_talk_stage = 12
	for line in _LordBritish.intro_lines():
		_push_talk_script(line)
	_layout_prompt_row()
	_refresh_party()


func _begin_hawkwind_talk(person_i: int) -> void:
	## xu4 Hawkwind seer — virtue counsel + KA_HAWKWIND on a living intro.
	_talk_person_i = person_i
	_talk_entry = null
	_talk_buffer = ""
	_reset_talk_hangul()
	_talk_turn_away = 0
	_talk_pending_ask = false
	_talk_is_hawkwind = true
	_talk_is_lb = false
	_talk_keywords = _Hawkwind.highlight_keywords()
	_shop = null
	_begin_talk_keyword_menu_if_requested()
	if not _Hawkwind.party_leader_can_speak():
		_end_talk_keyword_menu()
		_talk_stage = 0
		_push_talk_script(_Hawkwind.refuse_for_unconscious())
		_talk_person_i = -1
		_talk_is_hawkwind = false
		_talk_keywords.clear()
		_close_talk_message_panel()
		_layout_prompt_row()
		_finish_party_turn()
		return
	_talk_stage = 11
	_Hawkwind.grant_visit_karma()
	for line in _Hawkwind.intro_lines():
		_push_talk_script(line)
	_layout_prompt_row()


func _begin_vendor_shop(person_i: int, role: int) -> void:
	## xu4 discourse_run(vendorDisc) — full vendors.b state machine.
	_shop_item_menu_items.clear()
	_shop_item_menu_line_indices.clear()
	_shop_item_line_by_key.clear()
	_shop_item_menu_cursor = 0
	_talk_person_i = person_i
	_talk_stage = 10
	_talk_buffer = ""
	_reset_talk_hangul()
	_talk_entry = null
	_talk_keywords.clear()
	_shop = _VendorShop.new()
	var locale := _VendorShop.locale_from_ult(str(_city_map.source_path) if _city_map else "")
	if role == _CityNpcRoles.Role.VENDOR_INN and _transport == Transport.HORSE:
		_shop.begin_inn_refuse_horse()
	else:
		_shop.begin(role, locale)
	_flush_shop_output()


func _flush_shop_output() -> void:
	if _shop == null:
		return
	_shop_item_line_by_key.clear()
	var item_line_offsets: Dictionary = {}
	var flushed_line_count := 0
	for line in _shop.take_lines():
		var raw := str(line)
		var item_key := str(_VendorShop.item_line_key(raw))
		var text := str(_VendorShop.item_line_text(raw))
		var presented := _TalkTlk.present_script(text)
		var wrapped_count := _wrap_msg_text(_reflow_talk_hard_breaks(presented)).size()
		if not item_key.is_empty():
			item_line_offsets[item_key] = flushed_line_count
		_push_talk_script(text)
		flushed_line_count += wrapped_count
	var flush_start := maxi(_msg_lines.size() - flushed_line_count, 0)
	for item_key in item_line_offsets:
		_shop_item_line_by_key[item_key] = flush_start + int(item_line_offsets[item_key])
	if bool(_shop.finished):
		_end_shop()
		return
	_talk_buffer = ""
	_sync_shop_item_menu()
	if int(_shop.mode) == _VendorShop.Mode.NUMBER:
		_talk_buffer = "0"
		_GameInput.reset_stick_navigation()
	if not _shop_choice_keys().is_empty():
		_enter_prompt_choice = 0
		_GameInput.reset_stick_navigation()
		_reset_hold_state()
	_layout_prompt_row()
	_refresh_inventory_bars()
	_refresh_party()
	_sync_shop_character_inv()


func _sync_shop_item_menu() -> void:
	if _command_menu_layer != null and not _command_menu_open and not _talk_keyword_menu_active:
		_command_menu_layer.visible = false
	var entries: Array[Dictionary] = []
	if (
		_talk_stage == 10 and _shop != null
		and int(_shop.mode) == _VendorShop.Mode.CHOICE
	):
		entries = _shop.item_list_entries()
	var previous_key := ""
	if (
		not _shop_item_menu_items.is_empty()
		and _shop_item_menu_cursor >= 0
		and _shop_item_menu_cursor < _shop_item_menu_items.size()
	):
		previous_key = str(_shop_item_menu_items[_shop_item_menu_cursor].get("key", ""))
	_shop_item_menu_items = entries
	if entries.is_empty():
		_shop_item_menu_cursor = 0
		_shop_item_menu_line_indices.clear()
		_refresh_message_view()
		return
	_shop_item_menu_cursor = 0
	if not previous_key.is_empty():
		for i in entries.size():
			if str(entries[i].get("key", "")) == previous_key:
				_shop_item_menu_cursor = i
				break
	_shop_item_menu_line_indices.clear()
	for item in entries:
		var item_key := str(item.get("key", ""))
		_shop_item_menu_line_indices.append(
			int(_shop_item_line_by_key.get(item_key, -1))
		)
	_GameInput.reset_stick_navigation()
	_reset_hold_state()
	_refresh_message_view()


func _move_shop_item_menu_cursor(step: int) -> void:
	if _shop_item_menu_items.is_empty() or step == 0:
		return
	## No wrap — hold-repeat would otherwise loop the whole catalog.
	_shop_item_menu_cursor = clampi(
		_shop_item_menu_cursor + step,
		0,
		_shop_item_menu_items.size() - 1
	)
	_refresh_message_view()


func _choose_shop_item_menu_item() -> void:
	if (
		_shop == null or _shop_item_menu_items.is_empty()
		or _shop_item_menu_cursor < 0
		or _shop_item_menu_cursor >= _shop_item_menu_items.size()
	):
		return
	var key := str(_shop_item_menu_items[_shop_item_menu_cursor].get("key", ""))
	if key.is_empty() or not str(_shop.choice_keys).to_lower().contains(key):
		return
	_push_talk_player_input(key)
	_shop.submit_choice(key)
	_flush_shop_output()


func _handle_shop_item_menu_input(event: InputEvent) -> bool:
	if _shop_item_menu_items.is_empty() or _talk_stage != 10 or _shop == null:
		return false
	if event is InputEventJoypadMotion:
		## ↑↓ hold-repeat is polled in _tick_dialogue_choice_nav.
		return true
	if not event.is_pressed():
		return false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if (
			key_event.keycode == KEY_UP or key_event.physical_keycode == KEY_UP
			or key_event.keycode == KEY_DOWN or key_event.physical_keycode == KEY_DOWN
		):
			return true
		var key_dir := _GameInput.dir_from_event(key_event)
		if key_dir.y != 0:
			return true
		if not key_event.echo and _is_talk_enter(key_event):
			_choose_shop_item_menu_item()
			return true
		return false
	if event is InputEventJoypadButton:
		if event.is_echo():
			return false
		if _GameInput.is_select(event) or event.is_action_pressed("confirm"):
			_choose_shop_item_menu_item()
			return true
		var pad_dir := _GameInput.dir_from_event(event)
		if pad_dir.y != 0:
			return true
	return false


func _choose_shop_sell_pick() -> bool:
	## Accept the highlighted weapon/armor inventory letter during sell pick.
	if (
		_shop == null
		or not bool(_shop.is_sell_letter_pick())
		or _ztats_panel == null
		or not _ztats_panel.has_shop_pick()
	):
		return false
	var letter := _ztats_panel.shop_pick_letter()
	if letter.is_empty():
		return true
	_push_talk_player_input(letter)
	_shop.submit_choice(letter)
	_flush_shop_output()
	return true


func _handle_shop_sell_pick_input(event: InputEvent) -> bool:
	## Weapon/armor sell list lives on the character panel (not dialogue rows).
	## ↑↓ hold-repeat is polled in _tick_dialogue_choice_nav.
	if (
		_talk_stage != 10
		or _shop == null
		or not bool(_shop.is_sell_letter_pick())
		or _ztats_panel == null
		or not _ztats_panel.has_shop_pick()
	):
		return false
	if event is InputEventJoypadMotion:
		return true
	if not event.is_pressed():
		return false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if _is_shop_sell_nudge_key(key_event):
			return true
		var key_dir := _GameInput.dir_from_event(key_event)
		if key_dir.y != 0:
			return true
		if not key_event.echo and _is_talk_enter(key_event):
			return _choose_shop_sell_pick()
		return false
	if event is InputEventJoypadButton:
		if event.is_echo():
			return false
		if _GameInput.is_select(event) or event.is_action_pressed("confirm"):
			return _choose_shop_sell_pick()
		var pad_dir := _GameInput.dir_from_event(event)
		if pad_dir.y != 0:
			return true
	return false


func _shop_number_adjust(delta: int) -> void:
	if _shop == null or delta == 0:
		return
	var current := int(_talk_buffer) if _talk_buffer.is_valid_int() else 0
	var max_value := 1
	for _i in int(_shop.max_digits):
		max_value *= 10
	max_value -= 1
	_talk_buffer = str(clampi(current + delta, 0, max_value))
	_layout_prompt_row()


func _talk_give_number_adjust(delta: int) -> void:
	## Beggar Give amount — xu4 readInt(2), so 0..99.
	if _talk_stage != 4 or delta == 0:
		return
	var current := int(_talk_buffer) if _talk_buffer.is_valid_int() else 0
	_talk_buffer = str(clampi(current + delta, 0, 99))
	_layout_prompt_row()


func _submit_talk_give_number() -> void:
	if _talk_stage != 4:
		return
	var submitted := _talk_buffer.strip_edges()
	_talk_buffer = ""
	_layout_prompt_row()
	if not submitted.is_empty():
		_push_talk_player_input(submitted)
	var gold_amt := int(submitted) if submitted.is_valid_int() else 0
	_talk_finish_give(gold_amt)


func _handle_talk_give_number_input(event: InputEvent) -> bool:
	## Same D-pad / stick / arrow affordances as vendor qty (↑↓ ±1, ←→ ±10).
	if _talk_stage != 4:
		return false
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var delta := 0
		if motion.axis == JOY_AXIS_LEFT_X:
			delta = _GameInput.stick_axis_step(event, JOY_AXIS_LEFT_X) * 10
		elif motion.axis == JOY_AXIS_LEFT_Y:
			delta = -_GameInput.stick_axis_step(event, JOY_AXIS_LEFT_Y)
		if delta != 0:
			_talk_give_number_adjust(delta)
		return true
	if not event.is_pressed():
		return false
	if event is InputEventJoypadButton:
		if event.is_echo():
			return false
		if _GameInput.is_select(event) or event.is_action_pressed("confirm"):
			_submit_talk_give_number()
			return true
		var pad_dir := _GameInput.dir_from_event(event)
		if pad_dir.x != 0:
			_talk_give_number_adjust(pad_dir.x * 10)
			return true
		if pad_dir.y != 0:
			_talk_give_number_adjust(-pad_dir.y)
			return true
		return false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var key_dir := _GameInput.dir_from_event(key_event)
		if key_dir.x != 0:
			_talk_give_number_adjust(key_dir.x * 10)
			return true
		if key_dir.y != 0:
			_talk_give_number_adjust(-key_dir.y)
			return true
	return false


func _submit_shop_number() -> void:
	if _shop == null or int(_shop.mode) != _VendorShop.Mode.NUMBER:
		return
	var submitted := _talk_buffer.strip_edges()
	_talk_buffer = ""
	_layout_prompt_row()
	if not submitted.is_empty():
		_push_talk_player_input(submitted)
	var empty := submitted.is_empty()
	var number := int(submitted) if submitted.is_valid_int() else 0
	_shop.submit_number(number, empty or number <= 0)
	_flush_shop_output()


func _handle_shop_number_input(event: InputEvent) -> bool:
	if (
		_talk_stage != 10 or _shop == null
		or int(_shop.mode) != _VendorShop.Mode.NUMBER
	):
		return false
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var delta := 0
		if motion.axis == JOY_AXIS_LEFT_X:
			delta = _GameInput.stick_axis_step(event, JOY_AXIS_LEFT_X) * 10
		elif motion.axis == JOY_AXIS_LEFT_Y:
			delta = -_GameInput.stick_axis_step(event, JOY_AXIS_LEFT_Y)
		if delta != 0:
			_shop_number_adjust(delta)
		return true
	if not event.is_pressed():
		return false
	if event is InputEventJoypadButton:
		if event.is_echo():
			return false
		if _GameInput.is_select(event) or event.is_action_pressed("confirm"):
			_submit_shop_number()
			return true
		var pad_dir := _GameInput.dir_from_event(event)
		if pad_dir.x != 0:
			_shop_number_adjust(pad_dir.x * 10)
			return true
		if pad_dir.y != 0:
			_shop_number_adjust(-pad_dir.y)
			return true
		return false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var key_dir := _GameInput.dir_from_event(key_event)
		if key_dir.x != 0:
			_shop_number_adjust(key_dir.x * 10)
			return true
		if key_dir.y != 0:
			_shop_number_adjust(-key_dir.y)
			return true
	return false


func _end_shop() -> void:
	if _shop == null and _talk_stage != 10:
		return
	## Apply deferred world effects before clearing session.
	var horse := false
	var rel := Vector2i(-1, -1)
	var inn := false
	if _shop != null:
		horse = bool(_shop.want_horse)
		rel = _shop.relocate_to
		inn = bool(_shop.do_inn_rest)
	_shop_item_menu_items.clear()
	_shop_item_menu_line_indices.clear()
	_shop_item_line_by_key.clear()
	_shop_item_menu_cursor = 0
	_shop = null
	_talk_stage = 0
	_talk_buffer = ""
	var pi := _talk_person_i
	_talk_person_i = -1
	if pi >= 0 and _city_map != null:
		_city_map.pause_follow(pi)
	if rel.x >= 0 and rel.y >= 0:
		_tile_pos = rel
		if _map != null:
			_map.set_center(_tile_pos, false)
			if _map.has_method("refresh"):
				_map.refresh()
	if horse:
		_transport = Transport.HORSE
		_transport_tile = MapView.TILE_HORSE_E
		_horse_gallop = false
		if _map != null:
			_map.set_transport_tile(_transport_tile)
	_clear_shop_character_inv()
	_close_talk_message_panel()
	_layout_prompt_row()
	_refresh_inventory_bars()
	_refresh_party()
	if inn:
		## xu4 inn-sleep / InnController — do not end the turn until Morning!
		_begin_inn_rest()
		return
	_finish_party_turn()


func _shop_inv_page_for_kind(kind: String) -> int:
	match kind:
		"weapons":
			return ZtatsPanel.InvPage.WEAPONS
		"armor":
			return ZtatsPanel.InvPage.ARMOR
		"reagents":
			return ZtatsPanel.InvPage.REAGENTS
		_:
			return ZtatsPanel.InvPage.NONE


func _sync_shop_character_inv() -> void:
	## During weapon / armor / reagent shops, mirror the matching stock list in the character panel.
	if _talk_stage != 10 or _shop == null:
		_clear_shop_character_inv()
		return
	var kind := str(_shop.character_inv_kind())
	if kind.is_empty():
		_clear_shop_character_inv()
		return
	var page := _shop_inv_page_for_kind(kind)
	if page == ZtatsPanel.InvPage.NONE:
		_clear_shop_character_inv()
		return
	_ensure_ztats_panel()
	if not _sides_open and not _order_opened_roster:
		_open_order_roster()
	if _right_top:
		_right_top.visible = true
	if _compact_pane:
		_compact_pane.visible = false
	if _roster:
		_roster.visible = false
	var keep_scroll: bool = (
		_shop_inv_kind == kind
		and _ztats_panel != null
		and _ztats_panel.is_inventory_page()
	)
	_shop_inv_kind = kind
	var sell_pick := bool(_shop.is_sell_letter_pick())
	if _ztats_panel:
		## Sell letter prompt: cursor on list + A–P keys still work.
		## restore_scroll is ignored while sell-picking (cursor drives scroll).
		_ztats_panel.open_inventory(page, keep_scroll, sell_pick)


func _clear_shop_character_inv() -> void:
	## Drop shop inventory peek; restore party roster if the character panel stays open for talk.
	_shop_inv_kind = ""
	## Real Ztats session owns the panel — leave it alone.
	if _ztats_stage != 0:
		return
	if _ztats_panel != null and _ztats_panel.is_open():
		_ztats_panel.close_panel()
	if _talk_stage != 0 and (_sides_open or _order_opened_roster or _talk_msg_open):
		if _roster:
			_roster.visible = true
		if _right_top:
			_right_top.visible = true
		if _compact_pane and (_sides_open or _order_opened_roster):
			_compact_pane.visible = false


func _begin_inn_rest() -> void:
	## xu4 InnController::beginCombat sleep phase:
	## setTransport(corpse) → wait innTime (default 8s) → restore → HT_INNHEAL → "Morning!"
	_inn_prev_transport_tile = _transport_tile
	if _map != null:
		## Corpse / lying-down tile for the sleeping party marker.
		_map.set_transport_tile(MapView.TILE_CORPSE)
	## Sleep status: purple roster + matches putToSleep feel (not camp map).
	GameState.put_party_to_sleep(-1)
	_refresh_party()
	if _map != null and _map.has_method("refresh"):
		_map.refresh()
	_inn_stage = 1
	_inn_rest_left = INN_REST_SEC
	_layout_prompt_row()


func _tick_inn_rest(delta: float) -> void:
	if _inn_stage != 1:
		return
	_inn_rest_left -= delta
	if _inn_rest_left > 0.0:
		return
	_inn_stage = 0
	_inn_rest_left = 0.0
	## Async: ambush may open combat.
	_finish_inn_rest()


func _finish_inn_rest() -> void:
	## xu4 InnController post-sleep: restore, HT_INNHEAL, Isaac / ambush, "Morning!"
	## Restore walking / transport sprite.
	if _transport == Transport.FOOT:
		_transport_tile = -1
		if _map != null:
			_map.set_transport_tile(-1)
	elif _inn_prev_transport_tile >= 0:
		_transport_tile = _inn_prev_transport_tile
		if _map != null:
			_map.set_transport_tile(_transport_tile)
	else:
		_transport_tile = -1
		if _map != null:
			_map.set_transport_tile(-1)
	_inn_prev_transport_tile = -1
	GameState.wake_party()
	GameState.apply_inn_rest_heal()
	_refresh_party()
	_refresh_inventory_bars()
	if _map != null and _map.has_method("refresh"):
		_map.refresh()
	## Night event (after heal) — xu4 party.cpp / camp.cpp branch.
	var leader_dead := GameState.is_party_member_dead(0)
	if leader_dead:
		_inn_maybe_meet_isaac()
	elif (randi() % 8) != 0:
		_inn_maybe_meet_isaac()
	else:
		await _inn_maybe_ambush()
	_push_message(Locale.t("cmd_inn_morning"), false)
	_layout_prompt_row()
	if _combat_active:
		## Combat owns the session; turn ends with combat exit.
		return
	_finish_party_turn()


func _inn_maybe_meet_isaac() -> void:
	## xu4 InnController::maybeMeetIsaac — Skara Brae only, 1/4, ghost at inn.
	if _city_map == null or not _city_map.loaded:
		return
	if not _city_map.is_skara_brae():
		return
	if (randi() % 4) != 0:
		return
	## GHOST base tile 156; y = 10..12 near inn.
	var y := 10 + (randi() % 3)
	if _city_map.spawn_or_relocate_named("Isaac", 27, y, 156, _CityMapData.MOVE_WANDER):
		if _map != null and _map.has_method("refresh"):
			_map.refresh()


func _inn_maybe_ambush() -> void:
	## xu4 InnController::maybeAmbush — further 1/8 to actually fight.
	if (randi() % 8) != 0:
		return
	if _party_wiped_or_dying() or _combat_active:
		return
	var rats := (randi() % 4) == 0
	var foe_tid := 144 if rats else 200 ## rat / rogue bases
	var con_name := "BRICK.CON" if rats else "INN.CON"
	if not rats:
		_push_message(Locale.t("cmd_inn_ambush_stroll"), false)
	var path := _CombatMapData.resolve_u4_file(con_name)
	if path.is_empty():
		path = _CombatMapData.resolve_u4_file("BRICK.CON")
	var cmap = _CombatMapData.new()
	if path.is_empty() or not cmap.load_from_path(path):
		return
	var foe := {
		"tile": foe_tid,
		"x": _tile_pos.x,
		"y": _tile_pos.y,
		"facing": 0,
		## forceStandardEncounterSize + awardLoot empty
		"force_standard_encounters": true,
		"no_chest_loot": true,
		## xu4 showMessage false for rogue stroll ambush
		"skip_attacked_by": not rats,
	}
	await _begin_combat(foe, false, cmap, false)


func _talk_can_address(person_i: int, dist: int) -> bool:
	if person_i < 0 or person_i >= _city_map.persons.size():
		return false
	var tid := int(_city_map.persons[person_i].z)
	## Undead: no counter talk (Magincia ghosts).
	if _TalkTlk.is_undead_tile(tid) and dist > 1:
		return false
	## Alerted guards ignore talk (except Python).
	if person_i < _city_map.person_move.size():
		if int(_city_map.person_move[person_i]) == _CityMapData.MOVE_ATTACK:
			if not _TalkTlk.is_python_tile(tid):
				return false
	return true


func _begin_talk(person_i: int, entry: Variant) -> void:
	_talk_stage = 1
	_talk_person_i = person_i
	_talk_entry = entry
	_talk_buffer = ""
	_reset_talk_hangul()
	_talk_turn_away = int(entry.turn_away)
	_talk_pending_ask = false
	_talk_keywords = entry.highlight_keywords(_talk_city_id())
	_begin_talk_keyword_menu_if_requested()
	_city_map.pause_follow(person_i)
	## Message + character panels (left inventory stays closed unless already Tab-open).
	_open_talk_message_panel()
	## "You meet %s"
	_push_talk_script("You meet %s" % str(entry.look))
	## 50% self-introduction.
	var introduced_name := (randi() % 2) != 0
	if introduced_name:
		_talk_say_name()
	## If the NPC already gave their name, continue naturally with Job.
	## Otherwise leave Name selected so the player can ask who they are.
	if _talk_keyword_menu_active:
		var default_key := "job" if introduced_name else "name"
		## Only a named NPC may expose journal-directed topic shortcuts.
		if introduced_name:
			if (
				str(entry.name).strip_edges().to_lower() == "azure"
				and GameState.journal_has_id("minoc.gimble.azure-rune")
			):
				default_key = _talk_keyword_stable_key(
					"룬" if GameState.lang_short() == "ko" else "rune"
				)
			elif str(entry.name).strip_edges().to_lower() == "mischief":
				if (
					GameState.journal_has_id("minoc.azure.mischief-rune")
					or GameState.journal_has_id("minoc.mischief.forge-rune")
				):
					default_key = _talk_keyword_stable_key(
						"룬" if GameState.lang_short() == "ko" else "rune"
					)
			elif (
				str(entry.name).strip_edges().to_lower() == "alkerion"
				and GameState.journal_has_id("minoc.mischief.alkerion-stone")
			):
				default_key = _talk_keyword_stable_key(
					"돌" if GameState.lang_short() == "ko" else "stone"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "damon"
				and GameState.journal_has_id("minoc.merida.damon-mantra")
			):
				default_key = _talk_keyword_stable_key(
					"만트라" if GameState.lang_short() == "ko" else "mantra"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "singsong"
				and GameState.journal_has_id("minoc.damon.bard-song")
			):
				default_key = _talk_keyword_stable_key(
					"가사" if GameState.lang_short() == "ko" else "song"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "zircon"
				and GameState.journal_has_id("lcb.seesha.zircon-mystics")
			):
				default_key = _talk_keyword_stable_key(
					"신비" if GameState.lang_short() == "ko" else "mystic"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "pepper"
				and GameState.journal_has_id("britain.sprite.pepper-rune")
			):
				default_key = _talk_keyword_stable_key(
					"룬" if GameState.lang_short() == "ko" else "rune"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "cricket"
				and GameState.journal_has_id("britain.child.cricket-mantra")
			):
				default_key = _talk_keyword_stable_key(
					"만트라" if GameState.lang_short() == "ko" else "mantra"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "julio"
				and GameState.journal_has_id("britain.shapero.julio-compassion")
			):
				default_key = _talk_keyword_stable_key(
					"연민" if GameState.lang_short() == "ko" else "compassion"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "william"
				and GameState.journal_has_id("moonglow.christen.william-rune")
			):
				default_key = _talk_keyword_stable_key(
					"룬" if GameState.lang_short() == "ko" else "rune"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "nostro"
				and GameState.journal_has_id("jhelom.robert.nostro-rune")
			):
				default_key = _talk_keyword_stable_key(
					"룬" if GameState.lang_short() == "ko" else "rune"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "aesop"
				and GameState.journal_has_id("jhelom.hrothgar.aesop-mantra")
			):
				default_key = _talk_keyword_stable_key(
					"만트라" if GameState.lang_short() == "ko" else "mantra"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "talfourd"
				and GameState.journal_has_id("yew.druid.talfourd-rune")
			):
				default_key = _talk_keyword_stable_key(
					"룬" if GameState.lang_short() == "ko" else "rune"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "silent"
				and GameState.journal_has_id("yew.pinrod.druids-mantra")
			):
				default_key = _talk_keyword_stable_key(
					"직업" if GameState.lang_short() == "ko" else "job"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "winthrop"
				and GameState.journal_has_id("trinsic.kline.winthrop-rune")
			):
				default_key = _talk_keyword_stable_key(
					"룬" if GameState.lang_short() == "ko" else "rune"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "terrin"
				and GameState.journal_has_id("trinsic.winthrop.terrin-rune")
			):
				default_key = _talk_keyword_stable_key(
					"룬" if GameState.lang_short() == "ko" else "rune"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "ambule"
				and GameState.journal_has_id("skara.granted.ambule-mantra")
			):
				default_key = _talk_keyword_stable_key(
					"만트라" if GameState.lang_short() == "ko" else "mantra"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "barren"
				and GameState.journal_has_id("skara.ambule.barren-mantra")
			):
				default_key = _talk_keyword_stable_key(
					"만트라" if GameState.lang_short() == "ko" else "mantra"
				)
			elif _talk_npc_is_skara_ankh(str(entry.name)):
				if GameState.journal_has_id("skara.barren.spirituality-mantra"):
					default_key = _talk_keyword_stable_key(
						"옴" if GameState.lang_short() == "ko" else "om"
					)
				elif GameState.journal_has_id("skara.granted.ankh-rune"):
					default_key = _talk_keyword_stable_key(
						"룬" if GameState.lang_short() == "ko" else "rune"
					)
			elif (
				str(entry.name).strip_edges().to_lower() == "heywood"
				and GameState.journal_has_id("magincia.casperin.heywood-mantra")
			):
				default_key = _talk_keyword_stable_key(
					"만트라" if GameState.lang_short() == "ko" else "mantra"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "faultless"
				and GameState.journal_has_id("magincia.heywood.faultless-mantra")
			):
				default_key = _talk_keyword_stable_key(
					"만트라" if GameState.lang_short() == "ko" else "mantra"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "wierdrum"
				and GameState.journal_has_id("magincia.banter.wierdrum-shrine")
			):
				default_key = _talk_keyword_stable_key(
					"사원" if GameState.lang_short() == "ko" else "shrine"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "demitry"
				and GameState.journal_has_id("magincia.banter.demitry-horn")
			):
				default_key = _talk_keyword_stable_key(
					"뿔" if GameState.lang_short() == "ko" else "horn"
				)
			elif (
				str(entry.name).strip_edges().to_lower() == "nate"
				and (
					GameState.journal_has_id("magincia.ruskin.nate-rune")
					or GameState.journal_has_id("magincia.splot.nate-rune")
				)
			):
				default_key = _talk_keyword_stable_key(
					"룬" if GameState.lang_short() == "ko" else "rune"
				)
			elif (
				_talk_city_id() == "paws"
				and str(entry.name).strip_edges().to_lower() == "barren"
				and GameState.journal_has_id("magincia.nate.barren-rune")
			):
				default_key = _talk_keyword_stable_key(
					"룬" if GameState.lang_short() == "ko" else "rune"
				)
			elif (
				_talk_city_id() == "paws"
				and str(entry.name).strip_edges().to_lower()
				in ["sir simon", "lady tessa"]
				and GameState.journal_has_id("minoc.zircon.mystic-arms")
			):
				default_key = _talk_keyword_stable_key(
					"신비" if GameState.lang_short() == "ko" else "mystic"
				)
			elif (
				_talk_city_id() == "cove"
				and str(entry.name).strip_edges().to_lower() == "blissful"
				and GameState.journal_has_id("cove.allen.blissful-abyss")
			):
				default_key = _talk_keyword_stable_key(
					"심연" if GameState.lang_short() == "ko" else "abyss"
				)
			elif (
				_talk_city_id() == "cove"
				and _talk_npc_is_cove_ankh(str(entry.name))
				and GameState.journal_has_id("cove.blissful.ankh-chamber")
			):
				default_key = _talk_keyword_stable_key(
					"방" if GameState.lang_short() == "ko" else "chamber"
				)
			elif (
				_talk_city_id() == "cove"
				and str(entry.name).strip_edges().to_lower() == "merlin"
				and GameState.journal_has_id("cove.merlin.black-stone")
			):
				default_key = _talk_keyword_stable_key(
					"달문" if GameState.lang_short() == "ko" else "gate"
				)
			elif (
				_talk_city_id() == "empath"
				and str(entry.name).strip_edges().to_lower() == "malchor"
				and GameState.journal_has_id("empath.suzanna.malchor-horn")
			):
				default_key = _talk_keyword_stable_key(
					"뿔" if GameState.lang_short() == "ko" else "horn"
				)
			elif (
				_talk_city_id() == "empath"
				and str(entry.name).strip_edges().to_lower() == "suzanna"
				and GameState.journal_has_id("magincia.demitry.suzanna-horn")
			):
				default_key = _talk_keyword_stable_key(
					"뿔" if GameState.lang_short() == "ko" else "horn"
				)
			elif (
				_talk_city_id() == "empath"
				and str(entry.name).strip_edges().to_lower() == "derek the bard"
				and GameState.journal_has_id("empath.life.derek-candle")
			):
				default_key = _talk_keyword_stable_key(
					"촛대" if GameState.lang_short() == "ko" else "candle"
				)
			elif (
				_talk_city_id() == "lycaeum"
				and str(entry.name).strip_edges().to_lower() == "lord terence"
				and GameState.journal_has_id("lycaeum.father-antos.book")
			):
				default_key = _talk_keyword_stable_key(
					"진리" if GameState.lang_short() == "ko" else "truth"
				)
			elif (
				_talk_city_id() == "serpent"
				and str(entry.name).strip_edges().to_lower() == "garam"
				and GameState.journal_has_id("serpent.sister-antos.garam-bell")
			):
				default_key = _talk_keyword_stable_key(
					"종" if GameState.lang_short() == "ko" else "bell"
				)
			elif (
				_talk_city_id() == "serpent"
				and str(entry.name).strip_edges().to_lower() == "lassorn"
				and GameState.journal_has_id("serpent.noxum.lassorn-wheel")
			):
				default_key = _talk_keyword_stable_key(
					"타륜" if GameState.lang_short() == "ko" else "wheel"
				)
			elif (
				_talk_city_id() == "serpent"
				and str(entry.name).strip_edges().to_lower() == "shyra"
				and GameState.journal_has_id("serpent.ranger.shrya-rooms")
			):
				default_key = _talk_keyword_stable_key(
					"방" if GameState.lang_short() == "ko" else "room"
				)
			elif (
				_talk_city_id() == "serpent"
				and str(entry.name).strip_edges().to_lower() == "durham"
				and GameState.journal_has_id("serpent.treasure-guard.durham")
			):
				default_key = _talk_keyword_stable_key(
					"던전" if GameState.lang_short() == "ko" else "dungeon"
				)
			elif (
				_talk_city_id() == "serpent"
				and str(entry.name).strip_edges().to_lower() == "roderick"
				and GameState.journal_has_id("britain.thevel.roderick-orbs")
			):
				default_key = _talk_keyword_stable_key(
					"오브" if GameState.lang_short() == "ko" else "orbs"
				)
		for i in _talk_keyword_menu_items.size():
			if str(_talk_keyword_menu_items[i].get("key", "")) == default_key:
				_talk_keyword_menu_cursor = i
				break
		_layout_command_menu_layer()
	_push_talk_script("Your Interest:")
	_layout_prompt_row()
	_sync_talk_ime_edit()


func _open_talk_message_panel() -> void:
	## Message strip + character roster (same as New Order peek). Left inventory stays closed
	## unless Tab sides are already open (then both sides already cover talk UI).
	if not _sides_open:
		_open_order_roster()
	if _sides_open:
		_talk_msg_open = false
		## Still refresh geometry so wrap width uses the full open strip.
		if _map_pane != null:
			var g0 := _side_geom()
			_msg_full_h = g0["bottom_open_h"]
			_msg_open_x = g0["right_open_x"]
			_msg_rw = g0["pane_w"] - _msg_open_x
			_apply_msg_geometry()
		return
	_talk_msg_open = true
	var g := _side_geom()
	var bot_closed_h: float = g["bottom_closed_h"]
	var bot_open_h: float = g["bottom_open_h"]
	_msg_full_h = bot_open_h
	_msg_open_x = g["right_open_x"]
	_msg_rw = g["pane_w"] - _msg_open_x
	## Apply width immediately so dialogue wrap uses the full strip before text.
	var from_h := clampf(_msg_h if _msg_h > 8.0 else bot_closed_h, bot_closed_h, bot_open_h)
	_msg_h = from_h
	_apply_msg_geometry()
	if absf(from_h - bot_open_h) < 0.5:
		_msg_h = bot_open_h
		_apply_msg_geometry()
		_refresh_message_view()
		return
	if not is_inside_tree():
		_msg_h = bot_open_h
		_apply_msg_geometry()
		_refresh_message_view()
		return
	if _talk_msg_tween != null and is_instance_valid(_talk_msg_tween):
		_talk_msg_tween.kill()
	_talk_msg_tween = create_tween()
	_talk_msg_tween.tween_method(_tween_msg_height, from_h, bot_open_h, SIDE_TWEEN_SEC) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _close_talk_message_panel() -> void:
	## Collapse talk UI: character peek + message strip.
	## If the player opened left inventory (Tab / `_sides_open`) during talk, keep
	## full sides open after Bye.
	if _sides_open:
		_talk_msg_open = false
		_order_opened_roster = false
		_layout_side_panels(false)
		return
	if _order_opened_roster:
		_close_order_roster()
	if not _talk_msg_open:
		return
	_talk_msg_open = false
	var g := _side_geom()
	var bot_closed_h: float = g["bottom_closed_h"]
	var bot_open_h: float = g["bottom_open_h"]
	var from_h := clampf(_msg_h if _msg_h > 8.0 else bot_open_h, bot_closed_h, bot_open_h)
	if absf(from_h - bot_closed_h) < 0.5:
		_msg_h = bot_closed_h
		_apply_msg_geometry()
		_refresh_message_view()
		return
	if not is_inside_tree():
		_msg_h = bot_closed_h
		_apply_msg_geometry()
		_refresh_message_view()
		return
	if _talk_msg_tween != null and is_instance_valid(_talk_msg_tween):
		_talk_msg_tween.kill()
	_talk_msg_tween = create_tween()
	_talk_msg_tween.tween_method(_tween_msg_height, from_h, bot_closed_h, SIDE_TWEEN_SEC) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _talk_say_name() -> void:
	var e := _talk_entry
	if e == null:
		return
	_push_talk_script("%s says: I am %s" % [str(e.pronoun), str(e.name)])
	_offer_named_npc_journal_keywords()
	if str(e.name).strip_edges().to_lower() == "zorin":
		if _maybe_complete_manual_zorin_tip():
			_refresh_journal_panel()


func _push_talk_script(raw: String, match_keywords: bool = true) -> void:
	## NPC / talk script lines. Classic .TLK is modernized when lang is en_us.
	## DOS .tlk embeds hard breaks for the tiny classic text window — reflow to
	## the modern message strip, then soft-wrap to full content width.
	## xu4 screenMessage: dialogue text has NO charset prompt glyph on each line.
	## The spinning cursor lives only on the live prompt row.
	if raw.is_empty():
		return
	var script := _TalkTlk.present_script(raw)
	var flat := _reflow_talk_hard_breaks(script)
	if flat.is_empty():
		return
	if match_keywords:
		_discover_talk_keywords(flat)
	## Ensure geometry before measuring wrap width (first line of a talk).
	if _msg_rw < 8.0 or (_msg_block != null and _msg_block.size.x < 8.0):
		if _map_pane != null:
			var g := _side_geom()
			_msg_full_h = g["bottom_open_h"]
			_msg_open_x = g["right_open_x"]
			_msg_rw = float(g["pane_w"]) - _msg_open_x
			if _msg_h < 8.0:
				_msg_h = float(g["bottom_closed_h"] if not (_sides_open or _talk_msg_open) else g["bottom_open_h"])
			_apply_msg_geometry()
	for part in _wrap_msg_text(flat):
		if _talk_stage == 10:
			## Vendor: gold Buy/Sell + cyan A-/B- catalog letters.
			_msg_lines.append(_TalkTlk.colorize_shop_dialogue(part))
		else:
			var keys: Array = _talk_keywords if match_keywords else []
			_msg_lines.append(_TalkTlk.colorize_keywords(part, keys))
	while _msg_lines.size() > MSG_KEEP:
		_msg_lines.remove_at(0)
	_refresh_message_view()


func _push_talk_learned_reagent_mix() -> void:
	## One-line system notice after dialogue teaches a previously unknown recipe.
	var line := Locale.t("talk_learned_reagent_mix").strip_edges()
	if line.is_empty():
		return
	_msg_lines.append("[color=#7ec8ff]%s[/color]" % line)
	while _msg_lines.size() > MSG_KEEP:
		_msg_lines.remove_at(0)
	_refresh_message_view()
	_layout_prompt_row()


func _reflow_talk_hard_breaks(text: String) -> String:
	## Collapse classic DOS soft-layout newlines so text fills the panel width.
	var s := text.replace("\r\n", "\n").replace("\r", "\n")
	var joined := ""
	for line in s.split("\n"):
		var t := String(line).strip_edges()
		if t.is_empty():
			continue
		if not joined.is_empty():
			joined += " "
		joined += t
	## Collapse runs of spaces left over from tlk padding.
	while joined.contains("  "):
		joined = joined.replace("  ", " ")
	return joined


func _handle_talk_native_hangul(k: InputEventKey) -> bool:
	if not k.pressed:
		return false
	if _is_talk_input_mode_toggle(k):
		_toggle_talk_input_mode()
		return true
	if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
		_reset_talk_hangul()
		return _handle_talk_input(k)
	if _is_talk_enter(k):
		var flushed := str(_talk_hangul.call("flush"))
		_talk_append_native_commit(flushed)
		_talk_hangul_preedit = ""
		return _handle_talk_input(k)
	if k.keycode == KEY_BACKSPACE or k.physical_keycode == KEY_BACKSPACE:
		var erased: Dictionary = _talk_hangul.call("backspace") as Dictionary
		if bool(erased.get("consumed", false)):
			_talk_hangul_preedit = str(erased.get("preedit", ""))
			_layout_prompt_row()
			return true
		_talk_hangul_preedit = ""
		return _handle_talk_input(k)
	if k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return true
	var ascii := _talk_physical_ascii(k)
	if ascii < 0:
		return true
	if (
		_talk_buffer.length() >= _talk_ime_max_length()
		and _talk_hangul_preedit.is_empty()
	):
		return true
	if not HangulInputSettings.is_korean_mode():
		_talk_append_native_commit(String.chr(ascii))
		_layout_prompt_row()
		return true
	var result: Dictionary = _talk_hangul.call("process_key", ascii) as Dictionary
	_talk_append_native_commit(str(result.get("commit", "")))
	_talk_hangul_preedit = str(result.get("preedit", ""))
	if not bool(result.get("consumed", false)):
		## Space and punctuation finish the current syllable but are not consumed
		## by libhangul. Append their physical US-key character directly.
		_talk_append_native_commit(String.chr(ascii))
	_layout_prompt_row()
	return true


func _is_talk_input_mode_toggle(k: InputEventKey) -> bool:
	if k.echo:
		return false
	var code := k.keycode
	var physical := k.physical_keycode
	var os_name := OS.get_name()
	if os_name == "macOS" and (code == KEY_CAPSLOCK or physical == KEY_CAPSLOCK):
		return true
	## Ctrl+Space and Shift+Space serve as portable fallbacks. Shift+Space is
	## handled by the app before it can become an ordinary space character.
	if (
		(k.ctrl_pressed or k.shift_pressed)
		and (code == KEY_SPACE or physical == KEY_SPACE)
	):
		return true
	if os_name == "Windows":
		if (
			(code == KEY_ALT or physical == KEY_ALT)
			and k.location == KEY_LOCATION_RIGHT
		):
			return true
		## Dedicated 한/영 keys are exposed inconsistently by Windows keyboard
		## drivers. Accept Godot's localized physical-key description as well.
		var key_name := k.as_text_physical_keycode().to_lower()
		if (
			key_name.contains("hangul") or key_name.contains("hangeul")
			or key_name.contains("han/yeong") or key_name.contains("한/영")
		):
			return true
	return false


func _toggle_talk_input_mode() -> void:
	if HangulInputSettings.is_korean_mode():
		_talk_append_native_commit(str(_talk_hangul.call("flush")))
		_talk_hangul_preedit = ""
	else:
		_talk_hangul.call("reset")
	HangulInputSettings.toggle_input_mode()
	_layout_prompt_row()


func _talk_append_native_commit(text: String) -> void:
	if text.is_empty():
		return
	var room := _talk_ime_max_length() - _talk_buffer.length()
	if room <= 0:
		return
	_talk_buffer += text.substr(0, room)


func _talk_physical_ascii(k: InputEventKey) -> int:
	var code := int(k.physical_keycode)
	if code == KEY_NONE:
		code = int(k.keycode)
	if code >= KEY_A and code <= KEY_Z:
		return (65 if k.shift_pressed else 97) + (code - KEY_A)
	if code >= KEY_0 and code <= KEY_9:
		if k.shift_pressed:
			const SHIFT_DIGITS := ")!@#$%^&*("
			return SHIFT_DIGITS.unicode_at(code - KEY_0)
		return 48 + (code - KEY_0)
	if code < 32 or code > 126:
		return -1
	if not k.shift_pressed:
		return code
	const SHIFT_PUNCT := {
		32: 32, 39: 34, 44: 60, 45: 95, 46: 62, 47: 63,
		59: 58, 61: 43, 91: 123, 92: 124, 93: 125, 96: 126,
	}
	return int(SHIFT_PUNCT.get(code, code))


func _handle_talk_input(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed):
		return false
	var k := event as InputEventKey
	## Shop sell list: allow key-repeat for ↑↓; block other echoes.
	if k.echo:
		if (
			_talk_stage == 10
			and _shop != null
			and int(_shop.mode) == _VendorShop.Mode.CHOICE
			and bool(_shop.is_sell_letter_pick())
			and _is_shop_sell_nudge_key(k)
		):
			return _handle_shop_sell_pick_input(k)
		return false
	## Esc always farewell — never open the options menu while talking,
	## including Yes/No and gold prompts.
	if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
		if _talk_stage == 10 and _shop != null:
			_shop.on_escape()
			_flush_shop_output()
			return true
		_end_talk(true)
		return true
	match _talk_stage:
		1:
			return _talk_input_interest(k)
		2:
			## xu4 EventHandler::waitAnyKey before the follow-up question.
			_talk_ask_question()
			return true
		3:
			return _talk_input_yn(k)
		4:
			return _talk_input_give(k)
		10:
			return _talk_input_shop(k)
		11:
			return _talk_input_hawkwind(k)
		12:
			return _talk_input_lord_british(k)
		13:
			return _talk_input_lb_heal_yn(k)
		_:
			return false


func _talk_input_lord_british(k: InputEventKey) -> bool:
	## Keyword interest — 4-letter match like xu4 Dialogue::Keyword.
	if _is_talk_enter(k):
		var submitted := _talk_buffer.strip_edges()
		var match_input := _TalkLocale.normalize_interest(submitted)
		_talk_buffer = ""
		_layout_prompt_row()
		_push_talk_player_input(submitted)
		var kind := _LordBritish.reply_kind(match_input)
		if kind == "bye":
			_end_talk(true)
			return true
		if kind == "heal":
			_push_talk_script(_LordBritish.heal_well())
			_push_talk_script(_LordBritish.heal_ask())
			_talk_stage = 13
			_talk_buffer = ""
			_reset_talk_hangul()
			_enter_prompt_choice = 0
			_GameInput.reset_stick_navigation()
			_layout_prompt_row()
			return true
		_push_talk_script(_LordBritish.reply_text(match_input))
		_push_talk_script(_LordBritish.prompt())
		_layout_prompt_row()
		return true
	if k.keycode == KEY_BACKSPACE or k.physical_keycode == KEY_BACKSPACE:
		if not _talk_buffer.is_empty():
			_talk_buffer_backspace()
			_layout_prompt_row()
		return true
	var ch := _key_printable_char(k)
	if ch.is_empty():
		return false
	if _talk_buffer.length() >= 16:
		return true
	_talk_append_char(ch)
	_layout_prompt_row()
	return true


func _talk_answer_lb_heal_yn(yes: bool) -> void:
	## xu4: Yes = already well; No = heal the party.
	if yes:
		_push_talk_script(_LordBritish.heal_good())
	else:
		_push_talk_script(_LordBritish.heal_wounds())
		_LordBritish.heal_party()
		_refresh_party()
	_talk_stage = 12
	_talk_buffer = ""
	_reset_talk_hangul()
	_push_talk_script(_LordBritish.prompt())
	_layout_prompt_row()


func _talk_input_lb_heal_yn(k: InputEventKey) -> bool:
	## xu4 CONFIRMATION — "Art thou well?" Y / N / 예 / 아니 (+ on-screen buttons).
	if _is_talk_enter(k):
		var s := _talk_buffer.strip_edges()
		_talk_buffer = ""
		if s.is_empty():
			_layout_prompt_row()
			return true
		_push_talk_player_input(s)
		var yn := _talk_parse_yn(s)
		if yn == 1:
			_talk_answer_lb_heal_yn(true)
			return true
		if yn == 0:
			_talk_answer_lb_heal_yn(false)
			return true
		_push_talk_script(_LordBritish.heal_bad_answer())
		_talk_stage = 12
		_push_talk_script(_LordBritish.prompt())
		_layout_prompt_row()
		return true
	if k.keycode == KEY_BACKSPACE or k.physical_keycode == KEY_BACKSPACE:
		if not _talk_buffer.is_empty():
			_talk_buffer_backspace()
			_layout_prompt_row()
		return true
	var ch := _key_printable_char(k)
	if ch.is_empty():
		return false
	if _talk_buffer.length() >= 8:
		return true
	_talk_append_char(ch)
	_layout_prompt_row()
	return true


func _talk_parse_yn(s: String) -> int:
	## 1 = yes, 0 = no, -1 = invalid.
	## Use the same Hangul NFC/NFD normalization as interest keywords.
	var low := _TalkLocale.normalize_interest(s)
	if low.is_empty():
		return -1
	if (
		low == _TalkLocale.normalize_interest("y")
		or low == _TalkLocale.normalize_interest("yes")
		or low.begins_with(_TalkLocale.normalize_interest("예"))
		or low.begins_with(_TalkLocale.normalize_interest("네"))
	):
		return 1
	if (
		low == _TalkLocale.normalize_interest("n")
		or low == _TalkLocale.normalize_interest("no")
		or low.begins_with(_TalkLocale.normalize_interest("아니"))
		or low.begins_with(_TalkLocale.normalize_interest("아뇨"))
	):
		return 0
	return -1


func _talk_input_hawkwind(k: InputEventKey) -> bool:
	## Same typing as interest; keywords are the eight virtues (4-letter match).
	if _is_talk_enter(k):
		var submitted := _talk_buffer.strip_edges()
		var match_input := _TalkLocale.normalize_interest(submitted)
		_talk_buffer = ""
		_layout_prompt_row()
		_push_talk_player_input(submitted)
		var reply := _Hawkwind.reply_to_interest(match_input)
		if reply.is_empty():
			_end_talk(true)
			return true
		_push_talk_script(reply)
		_push_talk_script(_Hawkwind.again_prompt())
		_layout_prompt_row()
		return true
	if k.keycode == KEY_BACKSPACE or k.physical_keycode == KEY_BACKSPACE:
		if not _talk_buffer.is_empty():
			_talk_buffer_backspace()
			_layout_prompt_row()
		return true
	var ch := _key_printable_char(k)
	if ch.is_empty():
		return false
	if _talk_buffer.length() >= 16:
		return true
	_talk_append_char(ch)
	_layout_prompt_row()
	return true


func _talk_input_shop(k: InputEventKey) -> bool:
	if _shop == null:
		_end_shop()
		return true
	var mode := int(_shop.mode)
	if mode == _VendorShop.Mode.CHOICE:
		## Weapon/armor sell: ↑↓ moves the character-panel cursor; Enter accepts.
		if bool(_shop.is_sell_letter_pick()) and _handle_shop_sell_pick_input(k):
			return true
		## Buy/Sell (bs), stock letters (b–p), reagents, etc.: only keys listed in
		## choice_keys. Esc is handled above. Everything else is swallowed.
		var ch := _key_latin_command_char(k)
		if ch.is_empty():
			return true
		var keys := str(_shop.choice_keys).to_lower()
		if keys.is_empty() or not keys.contains(ch):
			return true
		if bool(_shop.is_sell_letter_pick()) and _ztats_panel != null:
			_ztats_panel.shop_pick_focus_letter(ch)
		_push_talk_player_input(ch)
		_shop.submit_choice(ch)
		_flush_shop_output()
		return true
	if mode == _VendorShop.Mode.NUMBER:
		## Qty / price / tip: digits only. Letters swallowed. Esc cancels above.
		if _is_talk_enter(k):
			var s := _talk_buffer.strip_edges()
			_talk_buffer = ""
			_layout_prompt_row()
			if not s.is_empty():
				_push_talk_player_input(s)
			var empty := s.is_empty()
			var n := int(s) if s.is_valid_int() else 0
			_shop.submit_number(n, empty or n <= 0)
			_flush_shop_output()
			return true
		if k.keycode == KEY_BACKSPACE or k.physical_keycode == KEY_BACKSPACE:
			if not _talk_buffer.is_empty():
				_talk_buffer_backspace()
				_layout_prompt_row()
			return true
		var dig := _key_digit_char(k)
		if dig.is_empty():
			return true
		if _talk_buffer == "0":
			_talk_buffer = dig
			_layout_prompt_row()
			return true
		if _talk_buffer.length() >= int(_shop.max_digits):
			return true
		_talk_append_char(dig)
		_layout_prompt_row()
		return true
	if mode == _VendorShop.Mode.TEXT:
		if _is_talk_enter(k):
			var s2 := _talk_buffer.strip_edges()
			var match_text := _TalkLocale.normalize_interest(s2)
			_talk_buffer = ""
			_layout_prompt_row()
			if not s2.is_empty():
				_push_talk_player_input(s2)
			_shop.submit_text(match_text)
			_flush_shop_output()
			return true
		if k.keycode == KEY_BACKSPACE or k.physical_keycode == KEY_BACKSPACE:
			if not _talk_buffer.is_empty():
				_talk_buffer_backspace()
				_layout_prompt_row()
			return true
		var tch := _key_printable_char(k)
		if tch.is_empty():
			return true
		if _talk_buffer.length() >= 16:
			return true
		_talk_append_char(tch)
		_layout_prompt_row()
		return true
	return false


func _is_shop_sell_nudge_key(k: InputEventKey) -> bool:
	var code := k.keycode
	var phys := k.physical_keycode
	return (
		code == KEY_UP or phys == KEY_UP
		or code == KEY_DOWN or phys == KEY_DOWN
		or k.is_action_pressed("move_up")
		or k.is_action_pressed("move_down")
	)


func _push_talk_player_input(typed: String) -> void:
	## xu4: words typed after "Your Interest:" / "You say:" stay in the log.
	## Plain history — no keyword gold, no classic modernization, no prompt glyph.
	var s := typed.strip_edges()
	if s.is_empty():
		return
	for part in _wrap_msg_text(s):
		_msg_lines.append(part)
	while _msg_lines.size() > MSG_KEEP:
		_msg_lines.remove_at(0)
	_refresh_message_view()


func _talk_input_interest(k: InputEventKey) -> bool:
	if _is_talk_enter(k):
		var submitted := _talk_buffer.strip_edges()
		_talk_buffer = ""
		_layout_prompt_row()
		_push_talk_player_input(submitted)
		_talk_process_keyword(submitted)
		return true
	if k.keycode == KEY_BACKSPACE or k.physical_keycode == KEY_BACKSPACE:
		if not _talk_buffer.is_empty():
			_talk_buffer_backspace()
			_layout_prompt_row()
		return true
	var ch := _key_printable_char(k)
	if ch.is_empty():
		return false
	var lim := 24 if str(GameState.language) == "ko" else 16
	if _talk_buffer.length() >= lim:
		return true
	_talk_append_char(ch)
	_layout_prompt_row()
	return true


func _talk_input_yn(k: InputEventKey) -> bool:
	if _is_talk_enter(k):
		var s := _talk_buffer.strip_edges()
		_talk_buffer = ""
		if s.is_empty():
			_layout_prompt_row()
			return true
		_push_talk_player_input(s)
		var yn := _talk_parse_yn(s)
		if yn >= 0:
			_talk_answer_yn(yn == 1)
			return true
		_push_talk_script("Yes or no!")
		_layout_prompt_row()
		return true
	if k.keycode == KEY_BACKSPACE or k.physical_keycode == KEY_BACKSPACE:
		if not _talk_buffer.is_empty():
			_talk_buffer_backspace()
			_layout_prompt_row()
		return true
	var ch := _key_printable_char(k)
	if ch.is_empty():
		return false
	if _talk_buffer.length() >= 8:
		return true
	_talk_append_char(ch)
	_layout_prompt_row()
	return true


func _talk_input_give(k: InputEventKey) -> bool:
	## Gold amount for Give — digits only; Esc ends talk above.
	if _is_talk_enter(k):
		var s := _talk_buffer.strip_edges()
		_talk_buffer = ""
		_layout_prompt_row()
		if not s.is_empty():
			_push_talk_player_input(s)
		var gold_amt := int(s) if s.is_valid_int() else 0
		_talk_finish_give(gold_amt)
		return true
	if k.keycode == KEY_BACKSPACE or k.physical_keycode == KEY_BACKSPACE:
		if not _talk_buffer.is_empty():
			_talk_buffer_backspace()
			_layout_prompt_row()
		return true
	var ch := _key_digit_char(k)
	if ch.is_empty():
		return true
	if _talk_buffer.length() >= 2:
		return true
	_talk_append_char(ch)
	_layout_prompt_row()
	return true


func _is_talk_enter(k: InputEventKey) -> bool:
	return (
		k.keycode == KEY_ENTER or k.physical_keycode == KEY_ENTER
		or k.keycode == KEY_KP_ENTER or k.physical_keycode == KEY_KP_ENTER
		or k.unicode == 10 or k.unicode == 13
	)


func _is_talk_submit(k: InputEventKey) -> bool:
	return _is_talk_enter(k)


func _talk_append_char(ch: String) -> void:
	## Non-IME fallback for shop letters and numeric fields only.
	_talk_buffer += ch


func _talk_buffer_backspace() -> void:
	if not _talk_buffer.is_empty():
		_talk_buffer = _talk_buffer.substr(0, _talk_buffer.length() - 1)


func _key_digit_char(k: InputEventKey) -> String:
	## Qty / gold / tip / price typing: only 0–9 from physical / keypad keys.
	## Letters, Hangul jamo, and other unicode are ignored.
	if k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return ""
	var phys := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
	if phys >= KEY_0 and phys <= KEY_9:
		return String.chr(48 + (phys - KEY_0))
	if phys >= KEY_KP_0 and phys <= KEY_KP_9:
		return String.chr(48 + (phys - KEY_KP_0))
	## Fallback when only unicode is filled (rare layouts).
	var u := k.unicode
	if u >= 48 and u <= 57:
		return String.chr(u)
	return ""


func _key_latin_command_char(k: InputEventKey) -> String:
	## Single-letter / digit commands (shop Buy/Sell, etc.).
	## Always physical US key → ASCII so Hangul [한] / OS Sebeolsik jamo
	## never replace menu letters (B must stay "b", not ㅠ).
	if k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return ""
	var phys := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
	if phys >= KEY_A and phys <= KEY_Z:
		return String.chr(97 + (phys - KEY_A))
	if phys >= KEY_0 and phys <= KEY_9:
		return String.chr(48 + (phys - KEY_0))
	if phys >= KEY_KP_0 and phys <= KEY_KP_9:
		return String.chr(48 + (phys - KEY_KP_0))
	return ""


func _key_printable_char(k: InputEventKey) -> String:
	if k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return ""
	var u := k.unicode
	if u >= 32 and u < 127:
		return String.chr(u)
	## Hangul syllables when the OS delivers them on the key event.
	if (
		(u >= 0x1100 and u <= 0x11FF)
		or (u >= 0x3130 and u <= 0x318F)
		or (u >= 0xA960 and u <= 0xA97F)
		or (u >= 0xAC00 and u <= 0xD7A3)
		or (u >= 0xD7B0 and u <= 0xD7FF)
	):
		return String.chr(u)
	## Fallback letters when unicode is 0 (some layouts / Hangul IME keydown).
	var code := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
	if code >= KEY_A and code <= KEY_Z:
		var base := code - KEY_A
		var ch := String.chr(97 + base) ## always lower for match
		if k.shift_pressed:
			ch = ch.to_upper()
		return ch
	if code >= KEY_0 and code <= KEY_9:
		return String.chr(48 + (code - KEY_0))
	return ""


func _talk_process_keyword(input: String) -> void:
	var e := _talk_entry
	if e == null:
		_end_talk(false)
		return
	## Preserve raw input in history, but all matching uses one normalized key.
	var in_s := _TalkLocale.normalize_interest(input)
	var bi := _TalkLocale.match_builtin_interest(in_s)
	if in_s.is_empty() or _talk_prefix(in_s, "bye", 3) or bi == "bye":
		## Empty Enter or "bye" — same farewell as Esc / every other end.
		_end_talk(false)
		return
	## Turn-away / attack chance.
	if _talk_turn_away > 0:
		var prob := randi() % 256
		if prob < _talk_turn_away:
			if _talk_turn_away - prob < 0x40:
				_push_talk_script("%s turns away!" % str(e.pronoun), false)
			else:
				_push_talk_script("%s says: On guard! Fool!" % str(e.pronoun), false)
				if _talk_person_i >= 0 and _talk_person_i < _city_map.person_move.size():
					_city_map.person_move[_talk_person_i] = _CityMapData.MOVE_ATTACK
			_end_talk(false)
			return
	var hit: Dictionary = _TalkTlk.match_keyword(e, in_s)
	if not hit.is_empty():
		var kind := int(hit.get("kind", 0))
		var reply := str(hit.get("text", ""))
		_push_talk_script(reply)
		if _TalkTlk.apply_keyword_rewards(e, kind):
			_push_talk_learned_reagent_mix()
		_try_journal_talk_capture(e, kind)
		if (
			str(e.name).to_lower() == "shamino"
			and kind == _TalkTlk.REPLY_TOPIC2
			and GameState.can_person_join_name(str(e.name))
		):
			_offer_talk_join_keyword()
		if _TalkTlk.should_ask_after(e, kind):
			_talk_stage = 2
			_talk_pending_ask = true
			_layout_prompt_row()
			return
		_talk_prompt_interest()
		return
	## Built-ins (look / name / give / join) — Hangul via TalkLocale.match_builtin_interest.
	if _talk_prefix(in_s, "look", 4) or bi == "look":
		_push_talk_script("You see %s" % str(e.look))
		_talk_prompt_interest()
		return
	if _talk_prefix(in_s, "name", 4) or bi == "name":
		_talk_say_name()
		_talk_prompt_interest()
		return
	if _talk_prefix(in_s, "give", 4) or bi == "give":
		_talk_start_give()
		return
	if _talk_prefix(in_s, "join", 4) or bi == "join":
		_talk_do_join()
		return
	if _talk_prefix(in_s, "ojna", 4):
		_push_talk_script("Hi Banjo Bob!\nYour secret\nnumber is\n4F4A4E0A")
		_talk_prompt_interest()
		return
	if _talk_person_is_child():
		_push_talk_script("I know not of that!")
	else:
		_push_talk_script("That I cannot\nhelp thee with.")
	_talk_prompt_interest()


func _talk_prefix(input: String, key: String, n: int) -> bool:
	var a := input.to_lower()
	var b := key.to_lower()
	if a.length() < n or b.length() < n:
		return a.begins_with(b) if not b.is_empty() else false
	return a.substr(0, n) == b.substr(0, n)


func _talk_prompt_interest() -> void:
	_talk_stage = 1
	_talk_buffer = ""
	_reset_talk_hangul()
	_talk_pending_ask = false
	_push_talk_script("Your Interest:")
	_layout_prompt_row()
	_sync_talk_ime_edit()


func _talk_ask_question() -> void:
	var e := _talk_entry
	if e == null:
		_end_talk(false)
		return
	_push_talk_script(str(e.question))
	_talk_stage = 3
	_talk_buffer = ""
	_reset_talk_hangul()
	_talk_pending_ask = false
	if _talk_keyword_menu_active:
		_enter_prompt_choice = 0
		_GameInput.reset_stick_navigation()
	_layout_prompt_row()


func _talk_answer_yn(yes: bool) -> void:
	var e := _talk_entry
	if e == null:
		_end_talk(false)
		return
	if bool(e.question_humility):
		if yes:
			GameState.adjust_karma_bragged()
		else:
			GameState.adjust_karma_humble()
	var reply := str(e.yes if yes else e.no)
	_push_talk_script(reply)
	if (
		_talk_answer_unlocks_join(e, yes)
		and GameState.can_person_join_name(str(e.name))
	):
		_offer_talk_join_keyword()
	if yes:
		_maybe_offer_azure_sacrifice_keyword()
		_maybe_offer_den_prompt_keywords()
	if _TalkTlk.apply_yesno_rewards(e, yes):
		_push_talk_learned_reagent_mix()
	var npc_key := str(e.name).strip_edges().to_lower()
	var journal_changed := false
	## Gimble's gold question: Yes points the party to Azure and the rune.
	if yes and npc_key == "gimble":
		if GameState.journal_try_capture("minoc", "Gimble", "GOLD_YES"):
			journal_changed = true
	## Mischief's Rune question: confirming possession advances the chain
	## to Alkerion's information about the sacrifice stone.
	if yes and npc_key == "mischief":
		if GameState.journal_mark_id("minoc.mischief.return-with-rune"):
			journal_changed = true
		if GameState.journal_mark_goal("confirm:mischief-rune"):
			journal_changed = true
		if GameState.journal_try_capture("minoc", "Mischief", "RUNE_YES"):
			journal_changed = true
	## Zorin (LCB): Yes names Antos and the bell / book / candle.
	if yes and npc_key == "zorin":
		if GameState.journal_try_capture("lcb", "Zorin", "CAST_YES"):
			journal_changed = true
	## Seesha (LCB): Yes names Zircon in Minoc and the mystic arms.
	if yes and npc_key == "seesha":
		if GameState.journal_try_capture("lcb", "Seesha", "COUN_YES"):
			journal_changed = true
	## Sprite (Britain): Yes points to Pepper and the compassion rune.
	if yes and npc_key == "sprite":
		if GameState.journal_try_capture("britain", "Sprite", "HELP_YES"):
			journal_changed = true
	## Thevel (Britain): No after the one-handed beggar points to Serpent's Hold.
	if not yes and npc_key == "thevel":
		if GameState.journal_try_capture("britain", "Thevel", "ORBS_NO"):
			journal_changed = true
	## Shazom (Moonglow): Yes/No after Nigel points to the Lycaeum teacher.
	if npc_key == "shazom":
		var shazom_topic := "NIGE_YES" if yes else "NIGE_NO"
		if GameState.journal_try_capture("moonglow", "Shazom", shazom_topic):
			journal_changed = true
	## Learning child (Britain): No on the mantra points to Cricket.
	if (
		not yes
		and npc_key == "a child"
		and str(e.topic2).strip_edges().to_upper() == "COMP"
	):
		if GameState.journal_try_capture("britain", "a child", "COMP_NO"):
			journal_changed = true
	## Lord Robert (Jhelom): Yes after Job points to Nostro and the valor rune.
	if yes and npc_key == "lord robert":
		if GameState.journal_try_capture("jhelom", "Lord Robert", "JOB_YES"):
			journal_changed = true
	## Senora (Jhelom): Yes after Crime points to the barkeep and sextant.
	if yes and npc_key == "senora":
		if GameState.journal_try_capture("jhelom", "Senora", "CRIM_YES"):
			journal_changed = true
	## Gravnor (Jhelom): No after "Dost thou have it?" names Destard and the red stone.
	if not yes and npc_key == "gravnor":
		if GameState.journal_try_capture("jhelom", "Gravnor", "STON_NO"):
			journal_changed = true
	## Druid (Yew): No after Shrine points to Talfourd and the justice rune.
	if (
		not yes
		and npc_key == "druid"
		and str(e.topic2).strip_edges().to_upper() == "SHRI"
	):
		if GameState.journal_try_capture("yew", "Druid", "SHRI_NO"):
			journal_changed = true
	## Talfourd (Yew): No after Rune reveals the jail-cell search.
	if (
		not yes
		and npc_key == "talfourd"
		and str(e.topic2).strip_edges().to_upper() == "RUNE"
	):
		if GameState.journal_try_capture("yew", "Talfourd", "RUNE_NO"):
			journal_changed = true
		if GameState.journal_mark_id("yew.druid.talfourd-rune"):
			journal_changed = true
		if GameState.journal_mark_goal("ask:talfourd-rune"):
			journal_changed = true
	## Pinrod (Yew): Yes after Council points to the chanting druids' mantra.
	if yes and npc_key == "pinrod":
		if GameState.journal_try_capture("yew", "Pinrod", "COUN_YES"):
			journal_changed = true
	## Winthrop (Trinsic): Yes/No after Rune both point to Terrin.
	if (
		npc_key == "winthrop"
		and str(e.topic2).strip_edges().to_upper() == "RUNE"
	):
		if GameState.journal_try_capture("trinsic", "Winthrop", "RUNE"):
			journal_changed = true
		if GameState.journal_mark_id("trinsic.kline.winthrop-rune"):
			journal_changed = true
		if GameState.journal_mark_goal("ask:winthrop-rune"):
			journal_changed = true
	## Granted (Skara): Yes after Money points to the Ankh (rune) and Ambule (mantra).
	if yes and npc_key == "granted":
		if GameState.journal_try_capture("skara", "Granted", "MONE_YES"):
			journal_changed = true
	## Banter (Magincia): Yes after Shrine points to Demitry and the silver horn.
	if (
		yes
		and npc_key == "banter"
		and str(e.topic2).strip_edges().to_upper() == "SHRI"
	):
		if GameState.journal_try_capture("magincia", "Banter", "SHRI_YES"):
			journal_changed = true
	## Splot (Magincia): Yes after Humility points to Nate (the snake).
	if (
		yes
		and npc_key == "splot"
		and str(e.topic2).strip_edges().to_upper() == "HUMB"
	):
		if GameState.journal_try_capture("magincia", "Splot", "HUMB_YES"):
			journal_changed = true
	## Sir Simon / Lady Tessa (Paws): Yes after Mystic reveals armour / weapons.
	if (
		yes
		and npc_key == "sir simon"
		and str(e.topic2).strip_edges().to_upper() == "MYST"
	):
		if GameState.journal_try_capture("paws", "Sir Simon", "MYST_YES"):
			journal_changed = true
	if (
		yes
		and npc_key == "lady tessa"
		and str(e.topic2).strip_edges().to_upper() == "MYST"
	):
		if GameState.journal_try_capture("paws", "Lady Tessa", "MYST_YES"):
			journal_changed = true
	## Gem (Vesper): Yes/No after Mantra both teach reversing Pride's mantra.
	if (
		npc_key == "gem"
		and str(e.topic2).strip_edges().to_upper() == "MANT"
	):
		if GameState.journal_try_capture("vesper", "Gem", "MANT"):
			journal_changed = true
	## Simple (Vesper): No after Humility names the isle's bearing.
	if (
		not yes
		and npc_key == "simple"
		and str(e.topic2).strip_edges().to_upper() == "HUMI"
	):
		if GameState.journal_try_capture("vesper", "Simple", "HUMI_NO"):
			journal_changed = true
	## Servile (Vesper): Yes/No after Help both warn that the skull is evil.
	if npc_key == "servile":
		if GameState.journal_try_capture("vesper", "Servile", "SKUL"):
			journal_changed = true
	## Allen (Cove): Yes/No after Ship both point to Blissful and the abyss.
	if (
		npc_key == "allen"
		and str(e.topic2).strip_edges().to_upper() == "SHIP"
	):
		if GameState.journal_try_capture("cove", "Allen", "SHIP_YES"):
			journal_changed = true
	## Sebastian (Britain): Yes after Mondain points to Cap'n / skull.
	if (
		yes
		and npc_key == "sebastian"
		and str(e.topic2).strip_edges().to_upper() == "MOND"
	):
		if GameState.journal_try_capture("britain", "Sebastian", "MOND_YES"):
			journal_changed = true
	## Sniflet (Den): Yes after Something reveals the balloon near Hythloth.
	if (
		yes
		and npc_key == "sniflet"
		and str(e.topic2).strip_edges().to_upper() == "SOME"
	):
		if GameState.journal_try_capture("den", "Sniflet", "SOME_YES"):
			journal_changed = true
	## Empath / Lycaeum / Serpent Yes-No journal tips.
	var place_id := _talk_city_id()
	var topic2 := str(e.topic2).strip_edges().to_upper()
	if (
		yes
		and place_id == "empath"
		and npc_key == "lord robert"
		and topic2 == "WORD"
	):
		if GameState.journal_try_capture("empath", "Lord Robert", "WORD_YES"):
			journal_changed = true
	if (
		not yes
		and place_id == "empath"
		and npc_key == "life."
		and topic2 == "LOVE"
	):
		if GameState.journal_try_capture("empath", "Life.", "LOVE_NO"):
			journal_changed = true
	if (
		not yes
		and place_id == "empath"
		and npc_key == "the pass guard"
		and topic2 == "DANG"
	):
		if GameState.journal_try_capture(
			"empath", "the pass guard", "DANG_NO"
		):
			journal_changed = true
	if (
		yes
		and place_id == "lycaeum"
		and npc_key == "robert frasier"
		and topic2 == "WORD"
	):
		if GameState.journal_try_capture(
			"lycaeum", "Robert Frasier", "WORD_YES"
		):
			journal_changed = true
	if (
		yes
		and place_id == "lycaeum"
		and npc_key == "scatu"
		and topic2 == "ARMO"
	):
		if GameState.journal_try_capture("lycaeum", "Scatu", "ARMO_YES"):
			journal_changed = true
	if (
		place_id == "lycaeum"
		and npc_key == "a fighter"
		and topic2 == "WOUN"
	):
		var fighter_topic := "WOUN_YES" if yes else "WOUN_NO"
		if GameState.journal_try_capture(
			"lycaeum", "a fighter", fighter_topic
		):
			journal_changed = true
	if (
		not yes
		and place_id == "lycaeum"
		and npc_key == "estro"
		and topic2 == "JUST"
	):
		if GameState.journal_try_capture("lycaeum", "Estro", "JUST_NO"):
			journal_changed = true
	if (
		not yes
		and place_id == "serpent"
		and npc_key == "sentri"
		and topic2 == "WORD"
	):
		if GameState.journal_try_capture("serpent", "Sentri", "WORD_NO"):
			journal_changed = true
	if (
		not yes
		and place_id == "serpent"
		and npc_key == "sister antos"
		and topic2 == "BELL"
	):
		if GameState.journal_try_capture(
			"serpent", "Sister Antos", "BELL_NO"
		):
			journal_changed = true
	if (
		yes
		and place_id == "serpent"
		and npc_key == "noxum"
		and topic2 == "SHIP"
	):
		if GameState.journal_try_capture("serpent", "Noxum", "SHIP_YES"):
			journal_changed = true
	if (
		yes
		and place_id == "serpent"
		and npc_key == "a ranger."
		and topic2 == "DUNG"
	):
		if GameState.journal_try_capture("serpent", "a ranger.", "DUNG_YES"):
			journal_changed = true
	if journal_changed:
		_refresh_journal_panel()
	_talk_prompt_interest()


func _talk_person_is_child() -> bool:
	if _city_map == null or _talk_person_i < 0 or _talk_person_i >= _city_map.persons.size():
		return false
	return _TalkTlk.is_child_tile(int(_city_map.persons[_talk_person_i].z))


func _talk_start_give() -> void:
	var e := _talk_entry
	if e == null:
		_end_talk(false)
		return
	var tid := -1
	if _talk_person_i >= 0 and _talk_person_i < _city_map.persons.size():
		tid = int(_city_map.persons[_talk_person_i].z)
	var is_beggar := _TalkTlk.is_beggar_tile(tid)
	if not is_beggar and _talk_person_i >= 0:
		is_beggar = int(_city_map.role_at(_talk_person_i)) == _CityNpcRoles.Role.BEGGAR
	if is_beggar:
		## xu4: message("How much? "); then readInt(2) — amount drives gold + karma.
		_push_talk_script("How much?")
		_talk_stage = 4
		_talk_buffer = ""
		_GameInput.reset_stick_navigation()
		_layout_prompt_row()
		return
	if _talk_person_is_child():
		_push_talk_script("%s says: I need no gold! Keep it!" % str(e.pronoun))
	else:
		_push_talk_script("%s says: I do not need thy gold.  Keep it!" % str(e.pronoun))
	_talk_prompt_interest()


func _talk_finish_give(gold_amt: int) -> void:
	var e := _talk_entry
	if e == null:
		_end_talk(false)
		return
	## xu4: only donate when gold > 0; 0 / cancel just returns to Interest.
	if gold_amt > 0:
		if GameState.donate_gold(gold_amt):
			## donate_gold: −gold, Compassion +2 (all-gold same in U4DOS).
			_push_talk_script(
				"%s says: Oh Thank thee! I shall never forget thy kindness!" % str(e.pronoun)
			)
			_refresh_inventory_bars()
		else:
			_push_talk_script("Thou hast not that much gold!")
	_talk_prompt_interest()


func _talk_do_join() -> void:
	var e := _talk_entry
	if e == null:
		_end_talk(false)
		return
	var name := str(e.name)
	if GameState.can_person_join_name(name):
		var err := GameState.try_join_companion(name)
		match err:
			GameState.JoinError.SUCCEEDED:
				_push_talk_script("I am honored to join thee!")
				if _talk_person_i >= 0:
					_city_map.take_person_at_index(_talk_person_i)
					_talk_person_i = -1
					if _map != null and _map.has_method("refresh"):
						_map.refresh()
				_refresh_party()
				_end_talk(false)
				return
			GameState.JoinError.NOT_VIRTUOUS:
				var virt := GameState.companion_class_by_name(name)
				_push_talk_script(
					"Thou art not %s enough for me to join thee."
					% GameState.virtue_adjective_en(virt)
				)
			_:
				_push_talk_script(
					"Thou art not experienced enough for me to join thee."
				)
	else:
		if _talk_person_is_child():
			_push_talk_script("%s says: I cannot go with thee." % str(e.pronoun))
		else:
			_push_talk_script("%s says: I cannot join thee." % str(e.pronoun))
	_talk_prompt_interest()


func _end_talk(_aborted: bool) -> void:
	## Single exit for talk: always print Bye so the player sees the end.
	## Esc / empty Enter / bye / Y-N cancel / join / turn-away all land here.
	if _talk_stage == 10:
		if _shop != null:
			_shop.on_escape()
			_flush_shop_output()
		else:
			_end_shop()
		return
	if _talk_stage == 0:
		return
	_end_talk_keyword_menu()
	## Mark closed before farewell so Esc cannot re-enter or open the menu
	## mid-cleanup. Bye like xu4 screenMessage — no leading command prompt.
	var farewell := "Bye."
	if _talk_is_hawkwind:
		farewell = _Hawkwind.bye_line()
	elif _talk_is_lb:
		farewell = _LordBritish.farewell()
	elif str(GameState.language) == "ko":
		farewell = _TalkTlk.present_script(farewell)
	_talk_stage = 0
	_talk_buffer = ""
	_reset_talk_hangul()
	_push_message(farewell, false)
	var pi := _talk_person_i
	_talk_person_i = -1
	_talk_entry = null
	_talk_keywords.clear()
	_talk_turn_away = 0
	_talk_pending_ask = false
	_talk_is_hawkwind = false
	_talk_is_lb = false
	_shop = null
	if pi >= 0 and _city_map != null:
		_city_map.pause_follow(pi)
	_close_talk_message_panel()
	_layout_prompt_row()
	_finish_party_turn()


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
	var force_standard := bool(foe.get("force_standard_encounters", false))
	var town_encounter: bool = (
		not force_standard
		and (
			bool(foe.get("city_person", false))
			or (_is_in_city() and _city_map != null and _city_map.loaded)
		)
	)
	var cmap = force_map
	if cmap == null:
		var ground_tid := 4
		var foe_ground := 4
		if town_encounter and _city_map != null and _city_map.loaded:
			ground_tid = int(_city_map.effective_tile_at(_tile_pos.x, _tile_pos.y))
			foe_ground = int(_city_map.effective_tile_at(foe_pos.x, foe_pos.y))
		elif _is_in_city() and _city_map != null and _city_map.loaded and force_standard:
			ground_tid = int(_city_map.effective_tile_at(_tile_pos.x, _tile_pos.y))
			foe_ground = ground_tid
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
	## Lock input; open panels while the map wipes explore → combat (0.6s tile diagonals).
	_combat_active = true
	_GameInput.reset_stick_navigation()
	_combat_resolving = true
	_combat_victory_aftermath = false
	_combat_exit_prompt = false
	_victory_solo_party_slot = -1
	_combat_suppress_chests = bool(foe.get("no_chest_loot", false))
	## Camp ambush: no sleep→wake rolls until the first creature phase ends.
	## Normal engage: party may need the 1/8 roll before any creature acts.
	_combat_allow_sleep_wake = not foes_first
	## Start side open tween without waiting — runs alongside the wipe.
	_open_sides_for_combat(false)
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
	## xu4 fillCreatureTable — town size for city; standard groups in wilderness
	## (inn ambush: forceStandardEncounterSize → not town).
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
		var from_img: Image = _map.snapshot_frame()
		_map.enter_combat(cmap, party_units, foe_units)
		_map.suppress_combat_chests = _combat_suppress_chests
		## First living party member has the turn (xu4 beginCombat focus).
		_map.set_combat_focus(0 if not party_units.is_empty() else -1)
		await _map.await_combat_enter_wipe(from_img, MapView.COMBAT_ENTER_TRANS_SEC)
	await _await_side_tween()
	## Camp ambush already printed "Ambushed!" — skip "Attacked by…".
	## Inn rogue stroll line also skips it (xu4 showMessage false).
	if (
		not initiated_by_party
		and not foes_first
		and not bool(foe.get("skip_attacked_by", false))
	):
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
	_combat_exit_prompt = false
	## Always free combat input after Victory (even if a turn-gap coroutine still runs).
	_combat_victory_aftermath = true
	_victory_solo_party_slot = -1
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
	_combat_exit_prompt = false
	_combat_resolving = true
	_combat_victory_aftermath = false
	_victory_solo_party_slot = -1
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
	_combat_suppress_chests = false
	## Held D-pad/stick from the arena must not walk the first field tile.
	_block_dir_until_keyup = true
	_reset_hold_state()
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


func _open_combat_exit_prompt() -> void:
	if (
		not _combat_active or not _combat_victory_aftermath
		or _combat_resolving or _combat_exit_prompt
	):
		return
	## With no unopened chest left, Y exits immediately without confirmation.
	if _map == null or not _map.has_closed_combat_chest():
		_combat_victory_esc_exit_all()
		return
	_combat_exit_prompt = true
	_enter_prompt_choice = 1 ## Default No so an accidental A does not leave.
	_GameInput.reset_stick_navigation()
	_push_message(Locale.t("cmd_leave_battle_confirm"), false)
	_layout_prompt_row()


func _resolve_combat_exit_prompt(leave: bool) -> void:
	if not _combat_exit_prompt:
		return
	_combat_exit_prompt = false
	if _enter_btn_row != null:
		_enter_btn_row.visible = false
	if _msg_prompt_row != null:
		_msg_prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout_prompt_row()
	grab_focus()
	if leave:
		_combat_victory_esc_exit_all()


func _place_captured_pirate_ship(pos: Vector2i, facing: int) -> void:
	## xu4 CombatController::awardLoot — pirate ship becomes a boardable frigate.
	if _map == null or _is_in_city():
		return
	## Pirate / ship frames share WNES order (0=W … 3=S).
	var ship_tid := MapView.TILE_SHIP_W + clampi(facing, 0, 3)
	_map.add_overlay(pos, ship_tid)
	_store_ship_hull_at(pos, GameState.SHIP_HULL_MAX)


func _tick_combat_aim_move() -> void:
	## Held arrows / stick / D-pad — same delay + interval as world foot walk.
	if not _combat_aiming:
		return
	var dir := _read_move_dir()
	if dir == Vector2i.ZERO:
		_move_repeating = false
		_hold_arm = 0.0
		_held_dir = Vector2i.ZERO
		return
	if dir != _held_dir:
		_held_dir = dir
		_move_repeating = false
		_hold_arm = 0.0
	if _move_cd > 0.0:
		return
	if _move_repeating and _hold_arm > 0.0:
		return
	_combat_move_aim(dir)
	_arm_hold_after_step(true)


func _tick_combat_victory_move() -> void:
	## Victory free-roam: keys + pad held at world walk cadence (no event double-step).
	if (
		not _combat_victory_aftermath
		or _command_menu_open
		or _pending_cmd != U4Commands.Id.NONE
		or _ztats_stage != 0
		or _ready_stage != 0
		or _use_stage != 0
		or _chest_open_stage != 0
		or _combat_exit_prompt
		or _enter_prompt_stage != 0
		or _esc_menu_is_open()
		or _options_panel_is_open()
	):
		return
	var dir := _read_move_dir()
	if dir == Vector2i.ZERO:
		_block_dir_until_keyup = false
		_move_repeating = false
		_hold_arm = 0.0
		_held_dir = Vector2i.ZERO
		return
	## Open/Get Dir? used this press — wait for release before roaming.
	if _block_dir_until_keyup:
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
	_combat_try_move(dir)
	_arm_hold_after_step(true)


func _handle_combat_input(event: InputEvent) -> bool:
	## Combat: move / Pass / Attack + xu4 letter commands; banned → "Not here!".
	## No idle auto-pass. Esc only cancels aim (or victory leave after win).
	## Stick: one step per tilt (must return near-neutral). Motion is handled
	## even when not "pressed" so the latch can clear on release.
	if event is InputEventJoypadMotion:
		if _combat_victory_aftermath:
			## Free roam is polled; clear latch on release only.
			_GameInput.stick_clear_if_released(event)
			return true
		if _combat_aiming:
			return _handle_combat_aim_input_event(event)
		if _combat_resolving:
			## Don't latch a tilt while foes act — that would eat the next move.
			_GameInput.stick_clear_if_released(event)
			return true
		## Some pads also emit axes for the D-pad — ignore while D-pad is held
		## so one press is not button-step + axis-step.
		if _GameInput.is_dpad_held():
			_GameInput.stick_clear_if_released(event)
			return true
		var stick_dir := _GameInput.stick_direction_step(event)
		if stick_dir != Vector2i.ZERO:
			var focus_klass := _map.get_combat_focus_klass() if _map != null else -1
			if focus_klass >= 0 and GameState.is_member_disabled(focus_klass):
				_combat_finish_member_turn()
			else:
				_combat_try_move(stick_dir)
		return true
	if not event.is_pressed() or event.is_echo():
		return false
	## After Victory!: free roam / Open / Get / ESC leave — never swallow on resolving.
	if _combat_victory_aftermath:
		return _handle_combat_victory_input_event(event)
	## Swallow other keys while foe turns / gaps / strike FX play out.
	if _combat_resolving and not _combat_aiming:
		return true
	if _combat_aiming:
		return _handle_combat_aim_input_event(event)
	if _combat_resolving:
		return true
	## Sleeping / dead focus — auto-pass (wake checked when focus lands).
	var focus_klass := _map.get_combat_focus_klass() if _map != null else -1
	if focus_klass >= 0 and GameState.is_member_disabled(focus_klass):
		_combat_finish_member_turn()
		return true
	if _GameInput.is_pass(event):
		_push_message(Locale.t("cmd_pass"), false)
		_combat_finish_member_turn()
		return true
	## Gamepad A is the direct Attack shortcut, identical to keyboard A.
	## While already aiming, A was handled above as aim confirmation.
	if _GameInput.is_select(event):
		_handle_combat_command(U4Commands.Id.ATTACK)
		return true
	## D-pad / keys — one event = one step.
	var dir := _GameInput.dir_from_event(event)
	if dir != Vector2i.ZERO:
		_combat_try_move(dir)
		return true
	if not (event is InputEventKey):
		return false
	var k := event as InputEventKey
	if k.keycode == KEY_SPACE or k.physical_keycode == KEY_SPACE:
		_push_message(Locale.t("cmd_pass"), false)
		_combat_finish_member_turn()
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
	return _handle_combat_victory_input_event(k)


func _handle_combat_victory_input_event(event: InputEvent) -> bool:
	## Free movement and loot commands; Y asks to leave — no turn clock.
	_combat_resolving = false
	if event is InputEventJoypadMotion:
		## Stick roam is polled; clear latch on release for Dir? / aim later.
		_GameInput.stick_clear_if_released(event)
		return true
	if (
		_GameInput.is_victory_exit(event)
		or (event is InputEventKey and _is_cancel_event(event))
	):
		_open_combat_exit_prompt()
		return true
	if event is InputEventKey:
		var k := event as InputEventKey
		## 0 = party rotation, 1–8 = solo control of that party slot (xu4 active player).
		var digit := _victory_digit_from_key(k)
		if digit >= 0:
			_victory_set_active_player(digit - 1) ## 0 key → -1 (none)
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
	## Keep solo character focused (in case focus drifted).
	_victory_ensure_solo_focus()
	## Movement is polled in _tick_combat_victory_move (avoids D-pad double-step).
	return true


func _handle_combat_victory_command(cmd: int) -> void:
	## Gamepad B palette actions after victory. Keep the arena open for looting.
	var lang := GameState.lang_short()
	match cmd:
		U4Commands.Id.OPEN, U4Commands.Id.GET_CHEST:
			_pending_cmd = cmd
			_pending_cmd_name = U4Commands.label(cmd, lang)
			_layout_prompt_row()
		U4Commands.Id.ZTATS:
			_do_ztats()
		U4Commands.Id.CAST:
			## Cast UI not ported yet — same stub as explore/combat turn / keyboard C.
			_push_message(Locale.t("cmd_stub", [
				U4Commands.letter_for(cmd),
				U4Commands.label(cmd, lang),
			]), false)
		U4Commands.Id.READY:
			_do_ready()
		U4Commands.Id.USE:
			_do_use()


func _handle_combat_pending_dir(k: InputEventKey) -> bool:
	return _handle_combat_pending_dir_event(k)


func _handle_combat_pending_dir_event(event: InputEvent) -> bool:
	## Open / Get Dir? while combat is active (no _process move).
	## Esc / Space / Enter / B cancel without spending the member turn.
	if _pending_cmd == U4Commands.Id.NONE:
		return false
	## Stick must update latch on release (is_pressed is false near neutral).
	if event is InputEventJoypadMotion:
		## D-pad often also emits axes — button path owns the Dir? answer.
		if _GameInput.is_dpad_held():
			_GameInput.stick_clear_if_released(event)
			return true
		var stick_dir := _GameInput.stick_direction_step(event)
		if stick_dir != Vector2i.ZERO:
			_finish_directed_command(stick_dir)
		return true
	if _is_cancel_event(event):
		_clear_pending_dir(true)
		_push_message(Locale.t("cmd_cancelled"), false)
		_layout_prompt_row()
		return true
	if event is InputEventKey and _is_space_key(event as InputEventKey):
		return true
	var dir := _GameInput.dir_from_event(event)
	if dir == Vector2i.ZERO:
		## Any non-dir → "What?" and abort Dir? (no turn until a real action).
		if event is InputEventKey or event is InputEventJoypadButton:
			_clear_pending_dir(true)
			_push_message(Locale.t("cmd_what"), false)
			_layout_prompt_row()
			return true
		return false
	_finish_directed_command(dir)
	return true


func _handle_combat_aim_input(k: InputEventKey) -> bool:
	return _handle_combat_aim_input_event(k)


func _handle_combat_aim_input_event(event: InputEvent) -> bool:
	## Cursor move is polled in _tick_combat_aim_move (hold = walk speed).
	## Events only confirm / cancel; dirs are swallowed so they don't double-step.
	if event is InputEventJoypadMotion:
		_GameInput.stick_clear_if_released(event)
		return true
	if _is_cancel_event(event):
		_combat_cancel_aim()
		return true
	if _GameInput.is_select(event) or (
		event is InputEventKey
		and (
			_is_key(event as InputEventKey, KEY_A)
			or _is_key(event as InputEventKey, KEY_ENTER)
			or _is_key(event as InputEventKey, KEY_KP_ENTER)
		)
	):
		_combat_confirm_aim()
		return true
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
		U4Commands.Id.PASS:
			_push_message(Locale.t("cmd_pass"), false)
			_combat_finish_member_turn()
		U4Commands.Id.VOLUME:
			## xu4 V toggles music; no turn cost.
			_push_message(Locale.t("cmd_stub", [letter, name]), false)
		_:
			_push_message(Locale.t("cmd_not_here"), false)
			_combat_finish_member_turn()


func _victory_digit_from_key(k: InputEventKey) -> int:
	## Returns 0–8 for top-row / keypad digits, or −1.
	for code in [k.keycode, k.physical_keycode]:
		if code >= KEY_0 and code <= KEY_8:
			return int(code - KEY_0)
		if code >= KEY_KP_0 and code <= KEY_KP_8:
			return int(code - KEY_KP_0)
	return -1


func _victory_set_active_player(party_slot: int) -> void:
	## party_slot −1 = clear solo (party rotation). 0–7 = roster slot #1–#8.
	if party_slot < -1 or party_slot > 7:
		_push_message(Locale.t("cmd_who"), false)
		return
	if party_slot < 0:
		_victory_solo_party_slot = -1
		_push_message(Locale.t("cmd_set_active_none"), false)
		_sync_combat_focus_roster()
		return
	## Number beyond current party size or empty slot.
	if party_slot >= GameState.party_size():
		_push_message(Locale.t("cmd_who"), false)
		return
	var nm := GameState.party_member_display_name(party_slot)
	if nm.is_empty():
		_push_message(Locale.t("cmd_who"), false)
		return
	_push_message(Locale.t("cmd_set_active_player", [nm]), false)
	var mid := GameState.party_member_at(party_slot)
	if mid < 0 or GameState.is_member_disabled(mid):
		_push_message(Locale.t("cmd_set_active_disabled"), false)
		return
	if _map == null:
		return
	var combat_i := _map.find_combat_party_index_for_slot(party_slot)
	if combat_i < 0:
		## Member exists but already left the arena.
		_push_message(Locale.t("cmd_who"), false)
		return
	_victory_solo_party_slot = party_slot
	_map.set_combat_focus(combat_i)
	_sync_combat_focus_roster()
	_refresh_party()


func _victory_ensure_solo_focus() -> void:
	if not _combat_victory_aftermath or _victory_solo_party_slot < 0 or _map == null:
		return
	var combat_i := _map.find_combat_party_index_for_slot(_victory_solo_party_slot)
	if combat_i < 0:
		## Solo unit already off-map — drop back to party rotation.
		_victory_solo_party_slot = -1
		if _map.combat_party_count() > 0 and (
			_map.get_combat_focus() < 0 or _map.get_combat_focus() >= _map.combat_party_count()
		):
			_map.set_combat_focus(0)
		_sync_combat_focus_roster()
		return
	if _map.get_combat_focus() != combat_i:
		_map.set_combat_focus(combat_i)
		_sync_combat_focus_roster()


func _victory_advance_party_focus() -> void:
	## Party mode after Victory: cycle focus through remaining units.
	if _map == null or _victory_solo_party_slot >= 0:
		return
	var n := _map.combat_party_count()
	if n <= 1:
		return
	var cur := _map.get_combat_focus()
	if cur < 0:
		_map.set_combat_focus(0)
	else:
		_map.set_combat_focus((cur + 1) % n)
	_sync_combat_focus_roster()


func _is_key(k: InputEventKey, code: int) -> bool:
	return k.keycode == code or k.physical_keycode == code


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
	_reset_hold_state()
	_GameInput.reset_stick_navigation()
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
	_reset_hold_state()
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
	_reset_hold_state()
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
			## Solo character left the map → drop to party rotation / next order.
			if _victory_solo_party_slot >= 0:
				if _map.find_combat_party_index_for_slot(_victory_solo_party_slot) < 0:
					_victory_solo_party_slot = -1
			_map.refocus_after_flee()
			_sync_combat_focus_roster()
			_refresh_party()
		elif _victory_solo_party_slot < 0:
			## Party mode: after a successful step, pass focus to the next unit.
			if (
				result == MapView.COMBAT_MOVE_OK
				or result == MapView.COMBAT_MOVE_SLOWED
			):
				_victory_advance_party_focus()
			else:
				_sync_combat_focus_roster()
		else:
			_victory_ensure_solo_focus()
			_sync_combat_focus_roster()
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
	var miss_tid := int(plan.get("miss_tid", MapView.TILE_MISS_FLASH))
	var hit_tid := int(plan.get("hit_tid", MapView.TILE_HIT_FLASH))
	var leave_tid := int(plan.get("leave_tid", -1))
	if party_i < 0 or klass < 0:
		return
	var unit := _map.get_combat_party_unit(party_i)
	if unit.is_empty():
		return
	klass = int(unit.get("klass", klass))
	to = Vector2i(int(unit.get("x", to.x)), int(unit.get("y", to.y)))
	await _map.await_combat_projectile(from, to, -1, miss_tid)
	if not _map.combat_shot_reaches(from, to):
		## Blocked / empty path end — xu4 leaveTile (lava lizard lava) when walkable.
		if leave_tid >= 0:
			var land := _map.combat_projectile_end(from, to)
			_map.combat_leave_field(land, leave_tid)
		return
	## Impact flash uses creature hittile (magic sphere, field, rocks, lava…).
	await _map.await_flash_combat_tile(to, hit_tid, COMBAT_HIT_FLASH_SEC)
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
	_victory_solo_party_slot = -1
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
	_combat_suppress_chests = false
	_block_dir_until_keyup = true
	_reset_hold_state()
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
				AudioSfx.play_door()
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
		AudioSfx.play_door()
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
	_sync_left_panel_mode()
	if _foe_roster == null:
		return
	if not _combat_active or _map == null or not _map.is_in_combat():
		_foe_roster.clear()
		return
	_foe_roster.set_foes(_map.get_combat_foes())
	_sync_combat_aim_foe_roster()


func _sync_left_panel_mode() -> void:
	## Combat → foe list; explore → Journal / 여행 기록.
	var in_combat := _combat_active and _map != null and _map.is_in_combat()
	if _foe_roster:
		_foe_roster.visible = in_combat
	if _journal_panel:
		_journal_panel.visible = not in_combat
		if not in_combat:
			_refresh_journal_panel()


func _refresh_journal_panel() -> void:
	if _journal_panel == null or not _journal_panel.has_method("refresh"):
		return
	var visible := (
		(_sides_open or _journal_focus_active or _journal_opened_left_only)
		and _journal_panel.visible
		and not (_combat_active and _map != null and _map.is_in_combat())
	)
	_journal_panel.refresh(visible)


func _can_open_journal_focus() -> bool:
	if _journal_focus_active or _command_menu_open or _city_warp_open or _enter_prompt_stage != 0:
		return false
	if (
		_death_busy or _moongate_busy or _cannon_busy or _search_busy
		or _shrine_busy or _shrine_stage != 0 or _shrine_session or _inn_stage != 0
	):
		return false
	if (
		_talk_stage != 0 or _mix_stage != 0 or _save_stage != 0
		or _camp_stage != 0 or _chest_open_stage != 0 or _telescope_stage != 0
		or _ready_stage != 0 or _wear_stage != 0 or _use_stage != 0
		or _ztats_stage != 0 or _order_stage != 0
		or _pending_cmd != U4Commands.Id.NONE or _ship_yell_await_dir
		or _esc_menu_is_open() or _options_panel_is_open()
		or _combat_active
	):
		return false
	if _peer_overlay != null and _peer_overlay.is_open():
		return false
	return true


func _open_journal_focus() -> void:
	if _journal_focus_active:
		_close_journal_focus()
		return
	if not _can_open_journal_focus():
		return
	_journal_saved_sides_open = _sides_open
	_journal_opened_left_only = false
	_journal_focus_active = true
	_GameInput.reset_stick_navigation()
	_reset_hold_state()
	_block_dir_until_keyup = true
	if not _sides_open:
		## Keep the right roster closed — only the journal pane slides in.
		_journal_opened_left_only = true
		_cancel_order_roster_close()
		_animate_left_panel_only(true)
		if _side_tween != null and is_instance_valid(_side_tween):
			_side_tween.chain().tween_callback(func() -> void:
				if _journal_focus_active and _journal_panel != null \
						and _journal_panel.has_method("recenter_selection"):
					_journal_panel.recenter_selection()
			)
	var place := _talk_city_id() if _is_in_city() else ""
	if _journal_panel != null and _journal_panel.has_method("begin_browse"):
		_journal_panel.begin_browse(place)


func _close_journal_focus(restore_sides: bool = true) -> void:
	if not _journal_focus_active:
		return
	var left_only := _journal_opened_left_only
	_journal_focus_active = false
	_journal_opened_left_only = false
	if _journal_panel != null and _journal_panel.has_method("end_browse"):
		_journal_panel.end_browse()
	_reset_hold_state()
	_block_dir_until_keyup = true
	if restore_sides and left_only:
		_animate_left_panel_only(false, true)
	elif restore_sides and _sides_open != _journal_saved_sides_open:
		_sides_open = _journal_saved_sides_open
		_cancel_order_roster_close()
		_order_opened_roster = false
		if _sides_open:
			_refresh_party()
		_layout_side_panels(true)
	grab_focus()


func _tick_journal_browse_nav() -> void:
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
	if _journal_panel != null and _journal_panel.has_method("move_selection"):
		_journal_panel.move_selection(step)
	_arm_hold_after_step()


func _handle_journal_focus_input(event: InputEvent) -> bool:
	## ↑↓ hold-repeat is polled in _tick_journal_browse_nav.
	if not _journal_focus_active:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if _is_quick_save_key(key):
			_do_quick_save()
			return true
		if _is_fullscreen_key(key):
			DisplaySettings.toggle_fullscreen()
			if _options_panel_is_open() and _options_panel != null:
				_options_panel.refresh()
			return true
		if _is_mod_chord_key(key) and _is_journal_key(key):
			_close_journal_focus()
			return true
	if event is InputEventJoypadMotion:
		var stick_x := _GameInput.stick_axis_step(event, JOY_AXIS_LEFT_X)
		if stick_x != 0 and _journal_panel != null and _journal_panel.has_method("nudge_selected_place"):
			_journal_panel.nudge_selected_place(stick_x)
		return true
	if not event.is_pressed() or event.is_echo():
		return false
	if _is_cancel_event(event):
		_close_journal_focus()
		return true
	if _GameInput.is_select(event) or event.is_action_pressed("confirm"):
		if _journal_panel != null and _journal_panel.has_method("activate_selection"):
			_journal_panel.activate_selection()
		return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if (
			key_event.keycode == KEY_UP or key_event.physical_keycode == KEY_UP
			or key_event.keycode == KEY_DOWN or key_event.physical_keycode == KEY_DOWN
		):
			return true
		var key_dir := _GameInput.dir_from_event(key_event)
		if key_dir.y != 0:
			return true
		if key_dir.x != 0:
			if _journal_panel != null and _journal_panel.has_method("nudge_selected_place"):
				_journal_panel.nudge_selected_place(key_dir.x)
			return true
		if (
			key_event.keycode == KEY_ENTER or key_event.physical_keycode == KEY_ENTER
			or key_event.keycode == KEY_KP_ENTER or key_event.physical_keycode == KEY_KP_ENTER
		):
			if _journal_panel != null and _journal_panel.has_method("activate_selection"):
				_journal_panel.activate_selection()
			return true
		return true
	if event is InputEventJoypadButton:
		var pad_dir := _GameInput.dir_from_event(event)
		if pad_dir.y != 0:
			return true
		if pad_dir.x != 0:
			if _journal_panel != null and _journal_panel.has_method("nudge_selected_place"):
				_journal_panel.nudge_selected_place(pad_dir.x)
			return true
		return true
	return true


func _try_journal_talk_capture(entry: Variant, kind: int) -> void:
	if entry == null or _city_map == null:
		return
	var place := _TalkLocale.city_id_from_path(str(_city_map.source_path))
	var topic := _JournalScript.topic_for_reply_kind(entry, kind)
	if place.is_empty() or topic.is_empty():
		return
	var npc := str(entry.name)
	var refresh := false
	if GameState.journal_try_capture(place, npc, topic):
		refresh = true
	var npc_key := npc.strip_edges().to_lower()
	## Manual → Zorin: any talk with Zorin completes the Way of the Avatar tip.
	if place == "lcb" and npc_key == "zorin":
		if _maybe_complete_manual_zorin_tip():
			refresh = true
	## Gimble → Azure: asking Azure about the rune completes Gimble's tip.
	if place == "minoc" and npc_key == "azure" and topic in ["RUNE", "SACR"]:
		if GameState.journal_mark_id("minoc.gimble.azure-rune"):
			refresh = true
		if GameState.journal_mark_goal("ask:azure-rune"):
			refresh = true
	## Azure → Mischief: asking Mischief about the rune completes the prior tip.
	if (
		place == "minoc"
		and npc_key == "mischief"
		and topic == "RUNE"
	):
		if GameState.journal_mark_id("minoc.azure.mischief-rune"):
			refresh = true
		if GameState.journal_mark_goal("ask:mischief-rune"):
			refresh = true
	## Alkerion's Stone answer completes Mischief's direction.
	if (
		place == "minoc"
		and npc_key == "alkerion"
		and topic == "STON"
	):
		if GameState.journal_mark_id("minoc.mischief.alkerion-stone"):
			refresh = true
		if GameState.journal_mark_goal("ask:alkerion-stone"):
			refresh = true
	## Merida → Damon: asking the hidden shepherd completes Merida's direction.
	if place == "minoc" and npc_key == "damon" and topic == "MANT":
		if GameState.journal_mark_id("minoc.merida.damon-mantra"):
			refresh = true
		if GameState.journal_mark_goal("ask:damon-mantra"):
			refresh = true
	## Damon → Singsong: asking about the verse/lyrics completes Damon's direction.
	if place == "minoc" and npc_key == "singsong" and topic == "SONG":
		if GameState.journal_mark_id("minoc.damon.bard-song"):
			refresh = true
		if GameState.journal_mark_goal("ask:singsong-verse"):
			refresh = true
	## Zorin → Antos: asking each Antos about their relic completes that tip.
	if place == "lycaeum" and npc_key == "father antos" and topic == "BOOK":
		if GameState.journal_mark_id("lcb.zorin.antos-book"):
			refresh = true
		if GameState.journal_mark_id("lcb.zorin.antos-relics"):
			refresh = true
		if GameState.journal_mark_goal("ask:antos-book"):
			refresh = true
		if GameState.journal_mark_goal("ask:antos-relics"):
			refresh = true
	elif place == "empath" and npc_key == "brother antos" and topic == "CAND":
		if GameState.journal_mark_id("lcb.zorin.antos-candle"):
			refresh = true
		if GameState.journal_mark_id("lcb.zorin.antos-relics"):
			refresh = true
		if GameState.journal_mark_goal("ask:antos-candle"):
			refresh = true
		if GameState.journal_mark_goal("ask:antos-relics"):
			refresh = true
	elif place == "serpent" and npc_key == "sister antos" and topic == "BELL":
		if GameState.journal_mark_id("lcb.zorin.antos-bell"):
			refresh = true
		if GameState.journal_mark_id("lcb.zorin.antos-relics"):
			refresh = true
		if GameState.journal_mark_goal("ask:antos-bell"):
			refresh = true
		if GameState.journal_mark_goal("ask:antos-relics"):
			refresh = true
	## Seesha → Zircon: asking about mystic arms completes Seesha's tip.
	if place == "minoc" and npc_key == "zircon" and topic == "MYST":
		if GameState.journal_mark_id("lcb.seesha.zircon-mystics"):
			refresh = true
		if GameState.journal_mark_goal("ask:zircon-mystics"):
			refresh = true
	## Britain: Pepper / Cricket / Julio complete prior name-directed tips.
	if place == "britain" and npc_key == "pepper" and topic == "RUNE":
		if GameState.journal_mark_id("britain.sprite.pepper-rune"):
			refresh = true
		if GameState.journal_mark_goal("ask:pepper-rune"):
			refresh = true
	if place == "britain" and npc_key == "cricket" and topic == "MANT":
		if GameState.journal_mark_id("britain.child.cricket-mantra"):
			refresh = true
		if GameState.journal_mark_goal("ask:cricket-mantra"):
			refresh = true
	if place == "britain" and npc_key == "julio" and topic == "COMP":
		if GameState.journal_mark_id("britain.shapero.julio-compassion"):
			refresh = true
		if GameState.journal_mark_goal("ask:julio-compassion"):
			refresh = true
	if place == "serpent" and npc_key == "roderick" and topic == "ORBS":
		if GameState.journal_mark_id("britain.thevel.roderick-orbs"):
			refresh = true
		if GameState.journal_mark_goal("ask:roderick-orbs"):
			refresh = true
	## Moonglow: William completes Christen's tip.
	if place == "moonglow" and npc_key == "william" and topic == "RUNE":
		if GameState.journal_mark_id("moonglow.christen.william-rune"):
			refresh = true
		if GameState.journal_mark_goal("ask:william-rune"):
			refresh = true
	## Lycaeum: Nigel's Recall/Resurrection reagents complete Shazom's tip.
	if (
		place == "lycaeum"
		and topic == "RECA"
		and npc_key.replace("\n", " ").replace("\r", " ").begins_with("nigel")
	):
		if GameState.journal_mark_id("moonglow.shazom.nigel-recall"):
			refresh = true
		if GameState.journal_mark_goal("ask:nigel-recall"):
			refresh = true
	## Jhelom: Nostro / Aesop complete prior name-directed tips.
	if place == "jhelom" and npc_key == "nostro" and topic == "RUNE":
		if GameState.journal_mark_id("jhelom.robert.nostro-rune"):
			refresh = true
		if GameState.journal_mark_goal("ask:nostro-rune"):
			refresh = true
	if place == "jhelom" and npc_key == "aesop" and topic == "MANT":
		if GameState.journal_mark_id("jhelom.hrothgar.aesop-mantra"):
			refresh = true
		if GameState.journal_mark_goal("ask:aesop-mantra"):
			refresh = true
	## Yew: Silent's Job/Beh chant completes Pinrod's mantra tip.
	## Catalog key is JOB; Beh.* replies also reveal the same mantra.
	if (
		place == "yew"
		and npc_key == "silent"
		and topic in ["JOB", "HEAL", "BEH", "BEH."]
	):
		if GameState.journal_try_capture("yew", "Silent", "JOB"):
			refresh = true
		if GameState.journal_mark_id("yew.pinrod.druids-mantra"):
			refresh = true
		if GameState.journal_mark_goal("ask:silent-mantra"):
			refresh = true
	## Trinsic: Winthrop / Terrin complete prior honor-rune tips.
	if place == "trinsic" and npc_key == "winthrop" and topic == "RUNE":
		if GameState.journal_mark_id("trinsic.kline.winthrop-rune"):
			refresh = true
		if GameState.journal_mark_goal("ask:winthrop-rune"):
			refresh = true
	if place == "trinsic" and npc_key == "terrin" and topic == "RUNE":
		if GameState.journal_mark_id("trinsic.winthrop.terrin-rune"):
			refresh = true
		if GameState.journal_mark_goal("ask:terrin-rune"):
			refresh = true
	## Skara: Ambule / Barren / Ankh complete prior spirituality tips.
	if place == "skara" and npc_key == "ambule" and topic == "MANT":
		if GameState.journal_mark_id("skara.granted.ambule-mantra"):
			refresh = true
		if GameState.journal_mark_goal("ask:ambule-mantra"):
			refresh = true
	if place == "skara" and npc_key == "barren" and topic == "MANT":
		if GameState.journal_mark_id("skara.ambule.barren-mantra"):
			refresh = true
		if GameState.journal_mark_goal("ask:barren-mantra"):
			refresh = true
	if (
		place == "skara"
		and _talk_npc_is_skara_ankh(npc)
		and topic in ["RUNE", "OM"]
	):
		if GameState.journal_mark_id("skara.granted.ankh-rune"):
			refresh = true
		if GameState.journal_mark_goal("ask:ankh-rune"):
			refresh = true
	## Magincia: Heywood / Faultless / Wierdrum / Demitry / Nate complete tips.
	if place == "magincia" and npc_key == "heywood" and topic == "MANT":
		if GameState.journal_mark_id("magincia.casperin.heywood-mantra"):
			refresh = true
		if GameState.journal_mark_goal("ask:heywood-mantra"):
			refresh = true
	if place == "magincia" and npc_key == "faultless" and topic == "MANT":
		if GameState.journal_mark_id("magincia.heywood.faultless-mantra"):
			refresh = true
		if GameState.journal_mark_goal("ask:faultless-mantra"):
			refresh = true
	if place == "magincia" and npc_key == "wierdrum" and topic == "SHRI":
		if GameState.journal_mark_id("magincia.banter.wierdrum-shrine"):
			refresh = true
		if GameState.journal_mark_goal("ask:wierdrum-shrine"):
			refresh = true
	if place == "magincia" and npc_key == "demitry" and topic == "HORN":
		if GameState.journal_mark_id("magincia.banter.demitry-horn"):
			refresh = true
		if GameState.journal_mark_goal("ask:demitry-horn"):
			refresh = true
	if place == "magincia" and npc_key == "nate" and topic in ["RUNE", "STON"]:
		if GameState.journal_mark_id("magincia.ruskin.nate-rune"):
			refresh = true
		if GameState.journal_mark_id("magincia.splot.nate-rune"):
			refresh = true
		if GameState.journal_mark_goal("ask:nate-rune"):
			refresh = true
	## Nate (Magincia): Rune reply points to Barren in Paws.
	if place == "magincia" and npc_key == "nate" and topic == "RUNE":
		if GameState.journal_try_capture("magincia", "Nate", "RUNE"):
			refresh = true
	## Paws: Barren completes Nate's tip; Wheatpin is a parallel humility-rune tip.
	if place == "paws" and npc_key == "barren" and topic == "RUNE":
		if GameState.journal_mark_id("magincia.nate.barren-rune"):
			refresh = true
		if GameState.journal_mark_goal("ask:barren-rune"):
			refresh = true
	## Cove: Blissful / ankh / Merlin complete prior tips.
	if place == "cove" and npc_key == "blissful" and topic == "ABYS":
		if GameState.journal_mark_id("cove.allen.blissful-abyss"):
			refresh = true
		if GameState.journal_mark_goal("ask:blissful-abyss"):
			refresh = true
	if (
		place == "cove"
		and _talk_npc_is_cove_ankh(npc)
		and topic in ["CODE", "CHAM"]
	):
		if GameState.journal_mark_id("cove.blissful.ankh-chamber"):
			refresh = true
		if GameState.journal_mark_goal("ask:ankh-chamber"):
			refresh = true
	if place == "cove" and npc_key == "merlin" and topic == "GATE":
		if GameState.journal_mark_id("cove.merlin.black-stone"):
			refresh = true
		if GameState.journal_mark_goal("ask:merlin-gate"):
			refresh = true
	## Empath / Serpent local follow-ups.
	if place == "empath" and npc_key == "suzanna" and topic == "HORN":
		if GameState.journal_mark_id("magincia.demitry.suzanna-horn"):
			refresh = true
		if GameState.journal_mark_goal("ask:suzanna-horn"):
			refresh = true
	if place == "empath" and npc_key == "malchor" and topic == "HORN":
		if GameState.journal_mark_id("empath.suzanna.malchor-horn"):
			refresh = true
		if GameState.journal_mark_goal("ask:malchor-horn"):
			refresh = true
	if (
		place == "empath"
		and npc_key == "derek the bard"
		and topic == "CAND"
	):
		if GameState.journal_mark_id("empath.life.derek-candle"):
			refresh = true
		if GameState.journal_mark_goal("ask:derek-candle"):
			refresh = true
	if place == "serpent" and npc_key == "garam" and topic == "BELL":
		if GameState.journal_mark_id("serpent.sister-antos.garam-bell"):
			refresh = true
		if GameState.journal_mark_goal("ask:garam-bell"):
			refresh = true
	if place == "serpent" and npc_key == "lassorn" and topic == "WHEE":
		if GameState.journal_mark_id("serpent.noxum.lassorn-wheel"):
			refresh = true
		if GameState.journal_mark_goal("ask:lassorn-wheel"):
			refresh = true
	if place == "serpent" and npc_key == "shyra" and topic == "ROOM":
		if GameState.journal_mark_id("serpent.ranger.shrya-rooms"):
			refresh = true
		if GameState.journal_mark_goal("ask:shyra-rooms"):
			refresh = true
	if place == "serpent" and npc_key == "durham" and topic == "DUNG":
		if GameState.journal_mark_id("serpent.treasure-guard.durham"):
			refresh = true
		if GameState.journal_mark_goal("ask:durham-dungeon"):
			refresh = true
	if refresh:
		_refresh_journal_panel()


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
	## Victory solo: gold "locked" row = active player; blue cursor = current focus.
	if _roster == null or _map == null or not _combat_active:
		return
	var slot := _map.get_combat_focus_party_slot()
	if slot < 0:
		_roster.clear_order_selection()
		return
	var solo := -1
	if _combat_victory_aftermath and _victory_solo_party_slot >= 0:
		solo = _victory_solo_party_slot
	_roster.set_order_selection(slot, solo)
	if _compact_roster != null:
		_compact_roster.set_order_selection(slot, solo)


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
	## Labels are single-line — wrap like xu4 screenMessage (panel width).
	## Prompt is a charset image mark on the first wrap line only (not Unicode ►).
	## Classic U4 stock lines (shrine advice, inn, etc.): en_us modernizes; ko packs via TalkLocale.
	var body := _TalkTlk.present_script(line)
	if with_prompt and body.begins_with(MSG_PROMPT_MARK):
		body = body.substr(MSG_PROMPT_MARK.length())
	var parts := _wrap_msg_text(body)
	if parts.is_empty():
		return
	if with_prompt:
		parts[0] = MSG_PROMPT_MARK + parts[0]
	for part in parts:
		_msg_lines.append(part)
	while _msg_lines.size() > MSG_KEEP:
		_msg_lines.remove_at(0)
	_refresh_message_view()


func _msg_line_max_width() -> float:
	## Content width of MsgBlock (= right strip − horizontal insets).
	## Geom is source of truth so wrap matches layout even if Control.size lags.
	var content := 0.0
	if _map_pane != null:
		var g := _side_geom()
		var pw: float = float(g.get("pane_w", 0.0))
		var rx: float = float(g.get("right_open_x", 0.0))
		if pw > rx + 8.0:
			content = pw - rx - float(MSG_INSET_X) * 2.0
	if content < 8.0 and _msg_rw > 8.0:
		content = _msg_rw - float(MSG_INSET_X) * 2.0
	if content < 8.0 and _msg_block != null and _msg_block.size.x > 8.0:
		content = _msg_block.size.x
	if content < 8.0 and not _msg_rows.is_empty() and is_instance_valid(_msg_rows[0]):
		content = maxf(content, _msg_rows[0].size.x)
	## Tiny safety pad (panel left/top border is outside MsgBlock already).
	return maxf(content - 2.0, 48.0)


func _msg_font_size() -> int:
	return clampi(int(floorf(_msg_pitch)) - 2, 10, MSG_FONT_SIZE) if _msg_pitch > 0.0 else MSG_FONT_SIZE


func _msg_text_width(text: String, font: Font, font_sz: int) -> float:
	var plain := _TalkTlk.strip_bbcode(text)
	var glyph_w := 0.0
	if plain.begins_with(MSG_PROMPT_MARK):
		plain = plain.substr(MSG_PROMPT_MARK.length())
		glyph_w = _msg_prompt_glyph_side(font_sz) + 2.0
	## Inline gear icons (shop catalog) occupy a square beside the name.
	var icon_n := _TalkTlk.count_icon_marks(text)
	if icon_n > 0:
		var side := float(_msg_gear_icon_side(font_sz))
		glyph_w += icon_n * (side + 2.0)
	if font == null:
		## D2Coding mono-ish fallback.
		return glyph_w + float(plain.length()) * float(font_sz) * 0.6
	return glyph_w + font.get_string_size(
		plain, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz
	).x


func _msg_gear_icon_side(font_sz: int) -> int:
	## Slightly taller than text so sprites stay readable in the log.
	return clampi(font_sz + 4, 14, 22)


func _wrap_msg_text(text: String) -> PackedStringArray:
	## Soft-wrap to the full message pane width (prefer spaces).
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
		## xu4: balloon drifts ~4/sec while aloft (non-user move — no finishTurn).
		_tick_balloon_drift()
	if sky_changed and _top_bar != null and _top_bar.has_method("refresh"):
		_top_bar.refresh()


func _is_balloon_flying() -> bool:
	return _transport == Transport.BALLOON and _balloon_flying


func _sync_balloon_view() -> void:
	## xu4 c->opacity: false while aloft → LOS ignores opaque tiles.
	if _map != null and _map.has_method("set_los_opacity"):
		_map.set_los_opacity(not _is_balloon_flying())


func _tick_balloon_drift() -> void:
	## xu4 GameController::timerFired → location->move(dirReverse(wind), false).
	if not _is_balloon_flying():
		return
	if _combat_active or _death_busy or _moongate_busy or _is_in_city():
		return
	if _world == null or not _world.loaded:
		return
	var dir := GameState.balloon_drift_dir()
	if dir == Vector2i.ZERO:
		return
	var next := Vector2i(
		posmod(_tile_pos.x + dir.x, WorldMapData.WIDTH),
		posmod(_tile_pos.y + dir.y, WorldMapData.HEIGHT)
	)
	## Aloft: collision override (can pass mountains/water/creatures).
	_tile_pos = next
	if _map != null:
		if _map.is_scrolling():
			_map.finish_scroll()
		_map.set_center(_tile_pos, true)
	_refresh_locate_hud()


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
	## xu4 checkMoongates — both moons full + Spirituality rune → shrine.
	if (
		GameState.trammel_phase == 4
		and GameState.felucca_phase == 4
		and _Shrine.can_enter_with_rune(Virtues.Id.SPIRITUALITY)
	):
		_moongate_busy = false
		_try_enter_shrine(_ShrinePortals.spirituality_portal())
		return
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
	_msg_cursor.visible = not _talk_ime_stage_active()


func _refresh_message_view() -> void:
	## Bottom-aligned history in the 14 slots above the prompt row.
	## Prompt row: charset triangle glyph + optional status text + spinning @.
	_ensure_msg_terminal()
	if not _msg_ui_ready:
		return
	var hist_slots := MSG_OPEN_LINES - 1
	for i in range(_msg_rows.size()):
		_set_msg_row_text(_msg_rows[i], "")
	var n := _msg_lines.size()
	var take := mini(n, hist_slots)
	var first_row := hist_slots - take
	var start := n - take
	for j in range(take):
		_set_msg_row_text(_msg_rows[first_row + j], _msg_lines[start + j])
	_sync_shop_item_message_highlight(start, first_row, take)
	_layout_prompt_row()


func _sync_shop_item_message_highlight(start: int, first_row: int, take: int) -> void:
	for row in _msg_rows:
		var empty := StyleBoxEmpty.new()
		row.add_theme_stylebox_override("normal", empty)
	_ensure_shop_item_message_highlight()
	if _shop_item_highlight != null:
		_shop_item_highlight.visible = false
	if (
		_shop_item_menu_items.is_empty()
		or _shop_item_menu_cursor < 0
		or _shop_item_menu_cursor >= _shop_item_menu_line_indices.size()
	):
		return
	var line_index := _shop_item_menu_line_indices[_shop_item_menu_cursor]
	if line_index < start or line_index >= start + take:
		return
	var row_index := first_row + line_index - start
	if row_index < 0 or row_index >= _msg_rows.size():
		return
	if _shop_item_highlight == null:
		return
	_shop_item_highlight.position = Vector2(0.0, float(row_index) * _msg_pitch)
	_shop_item_highlight.size = Vector2(_msg_block.size.x, _msg_pitch)
	_shop_item_highlight.visible = true
	if _shop_item_highlight_edge != null:
		UiTheme.layout_selection_edge(
			_shop_item_highlight_edge,
			_shop_item_highlight.size.x,
			_msg_pitch,
			MSG_FONT_SIZE
		)
		UiTheme.set_selection_edge_active(_shop_item_highlight_edge, true)


func _set_msg_row_text(row: RichTextLabel, line: String) -> void:
	## Prefer append_text so BBCode (keyword tint) always parses.
	## Leading MSG_PROMPT_MARK → xu4 charset prompt image (CHARSET_PROMPT).
	## TalkTlk gear icon marks (weapon/armor/reagent) → inline sprites before item names.
	if row == null:
		return
	row.clear()
	if line.is_empty():
		return
	var body := line
	if body.begins_with(MSG_PROMPT_MARK):
		body = body.substr(MSG_PROMPT_MARK.length())
		if _prompt_tex != null:
			var font_sz := _msg_font_size()
			var side := int(round(_msg_prompt_glyph_side(font_sz)))
			row.add_image(
				_prompt_tex,
				side,
				side,
				Color.WHITE,
				INLINE_ALIGNMENT_CENTER
			)
			if not body.is_empty():
				row.add_text(" ")
	if body.is_empty():
		return
	_append_msg_body_with_icons(row, body)


func _append_msg_body_with_icons(row: RichTextLabel, body: String) -> void:
	## Stream BBCode text + TalkTlk weapon/armor/reagent icon marks as inline images.
	if not body.contains(_TalkTlk.MSG_ICON_BEGIN):
		row.append_text(body)
		return
	var font_sz := _msg_font_size()
	var side := _msg_gear_icon_side(font_sz)
	var i := 0
	while i < body.length():
		if body.unicode_at(i) == 0x02:
			var end := body.find(_TalkTlk.MSG_ICON_END, i + 1)
			if end < 0:
				row.append_text(body.substr(i))
				return
			var payload := body.substr(i + 1, end - i - 1)
			var tex: Texture2D = _msg_gear_texture_from_mark(payload)
			if tex != null:
				row.add_image(tex, side, side, Color.WHITE, INLINE_ALIGNMENT_CENTER)
				row.add_text(" ")
			i = end + 1
			continue
		var next := body.find(_TalkTlk.MSG_ICON_BEGIN, i)
		if next < 0:
			row.append_text(body.substr(i))
			return
		if next > i:
			row.append_text(body.substr(i, next - i))
		i = next


func _msg_gear_texture_from_mark(payload: String) -> Texture2D:
	## "w12" → weapon 12, "a3" → armor 3, "r1" → reagent 1.
	if payload.length() < 2:
		return null
	var kind := payload[0]
	var id := int(payload.substr(1))
	if kind == "w":
		return WeaponIcons.texture_for_id(id)
	if kind == "a":
		return ArmorIcons.texture_for_id(id)
	if kind == "r":
		return ReagentIcons.texture_for_id(id)
	return null
