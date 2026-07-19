extends Control

## Left: square map (no frame). Right: Status + Message (Ultima blue frames).

@onready var _map_pane: Control = $RootRow/MapPane
@onready var _map: MapView = $RootRow/MapPane/MapView
@onready var _roster: PartyRoster = %PartyRoster
@onready var _cmd_line: Label = $RootRow/RightPane/MessageFrame/MessageMargin/MessageVBox/CmdLine
@onready var _hint: Label = $RootRow/RightPane/MessageFrame/MessageMargin/MessageVBox/Hint

## First step is immediate. While held: wait MOVE_HOLD_DELAY, then
## MOVE_HOLD_INTERVAL between steps. Taps also honor MOVE_HOLD_INTERVAL
## (cooldown is not cleared on key-up). Tune anytime.
const MOVE_HOLD_DELAY := 0.5
const MOVE_HOLD_INTERVAL := 0.1
const MAP_GAP := 8.0
const RIGHT_MIN := 360.0
const MSG_MAX_LINES := 10

var _world := WorldMapData.new()
var _tile_pos := Vector2i(83, 105)
var _move_cd := 0.0
var _hold_arm := 0.0
var _move_repeating := false
var _held_dir := Vector2i.ZERO
var _pending_cmd: int = U4Commands.Id.NONE
var _load_error: String = ""
var _esc_held := false
var _msg_lines: PackedStringArray = PackedStringArray()


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_fit_square_map)
	_style_right_panels()

	var atlas := _load_atlas()
	var path := _resolve_world_map_path()

	if atlas == null:
		_load_error = "shapes.png 로드 실패"
	elif not _world.load_from_path(path):
		_load_error = "WORLD.MAP 로드 실패\n%s" % path
	else:
		_tile_pos = GameState.start_pos if GameState.start_pos != Vector2i.ZERO else Vector2i(83, 105)
		_map.setup(_world, atlas)
		_map.set_view_tiles(11, 11)
		_map.set_center(_tile_pos)

	call_deferred("_fit_square_map")
	call_deferred("grab_focus")
	_hint.text = Locale.t("input_hint_world")
	if not _load_error.is_empty():
		_push_message(_load_error)
		push_error(_load_error)
	else:
		_refresh_party()
		_push_location_message()


func _load_atlas() -> Texture2D:
	var atlas_path := "res://assets/tiles/u4graphics/shapes.png"
	var tex := load(atlas_path) as Texture2D
	if tex != null:
		return tex
	var img := Image.new()
	if img.load(atlas_path) == OK:
		return ImageTexture.create_from_image(img)
	return null


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


func _fit_square_map() -> void:
	# Square map panel = viewport height (clamped so right panel still fits).
	var avail := size
	if avail.x < 32.0 or avail.y < 32.0:
		return
	var side := floorf(avail.y)
	var max_map_w := floorf(avail.x - RIGHT_MIN - MAP_GAP)
	side = minf(side, max_map_w)
	side = maxf(side, 256.0)
	_map_pane.custom_minimum_size = Vector2(side, side)
	_map_pane.size = Vector2(side, side)


func _style_right_panels() -> void:
	var status := get_node_or_null("RootRow/RightPane/StatusFrame") as PanelContainer
	if status:
		status.add_theme_stylebox_override("panel", _make_blue_panel(6))

	var msg := get_node_or_null("RootRow/RightPane/MessageFrame") as PanelContainer
	if msg:
		msg.add_theme_stylebox_override("panel", _make_blue_panel(4))


func _make_blue_panel(content_margin: int) -> StyleBoxFlat:
	## Same Ultima-blue chrome as StatusInfoBar.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.06, 0.28, 1)
	sb.border_color = Color(0.35, 0.55, 0.95, 1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(1)
	sb.content_margin_left = content_margin
	sb.content_margin_right = content_margin
	sb.content_margin_top = content_margin
	sb.content_margin_bottom = content_margin
	return sb


func _process(delta: float) -> void:
	_move_cd = maxf(0.0, _move_cd - delta)
	_hold_arm = maxf(0.0, _hold_arm - delta)

	var esc := Input.is_key_pressed(KEY_ESCAPE) or Input.is_physical_key_pressed(KEY_ESCAPE)
	if esc and not _esc_held:
		_on_escape()
	_esc_held = esc

	if not _load_error.is_empty():
		return

	var dir := _read_move_dir()
	if dir == Vector2i.ZERO:
		# Key up: cancel hold-arm, but keep _move_cd so taps can't beat INTERVAL.
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
	# Unbroken hold: wait MOVE_HOLD_DELAY before the 2nd+ auto-step.
	if _move_repeating and _hold_arm > 0.0:
		return
	# Mid-scroll: snap finish so continuous taps aren't eaten.
	if _map != null and _map.is_scrolling():
		_map.finish_scroll()

	if _pending_cmd != U4Commands.Id.NONE:
		_finish_directed_command(dir)
		_move_cd = MOVE_HOLD_INTERVAL
		_move_repeating = false
		_hold_arm = 0.0
		return

	_tile_pos = Vector2i(
		posmod(_tile_pos.x + dir.x, WorldMapData.WIDTH),
		posmod(_tile_pos.y + dir.y, WorldMapData.HEIGHT)
	)
	_map.set_center(_tile_pos)
	_push_location_message()
	_move_cd = MOVE_HOLD_INTERVAL
	if _move_repeating:
		_hold_arm = 0.0
	else:
		# First step of this press — longer gate before hold auto-repeats.
		_move_repeating = true
		_hold_arm = MOVE_HOLD_DELAY


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


func _on_escape() -> void:
	if _pending_cmd != U4Commands.Id.NONE:
		_pending_cmd = U4Commands.Id.NONE
		_push_message(Locale.t("cmd_cancelled"))
	else:
		SceneRouter.to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_on_escape()
			get_viewport().set_input_as_handled()
			return
		var cmd := U4Commands.from_event(event)
		if cmd != U4Commands.Id.NONE:
			_handle_command(cmd)
			get_viewport().set_input_as_handled()


func _handle_command(cmd: int) -> void:
	var lang := GameState.lang_short()
	var letter := U4Commands.letter_for(cmd)
	var name := U4Commands.label(cmd, lang)
	if U4Commands.NEEDS_DIRECTION.get(cmd, false):
		_pending_cmd = cmd
		_push_message(Locale.t("cmd_need_dir", [letter, name]))
		return
	_pending_cmd = U4Commands.Id.NONE
	if cmd == U4Commands.Id.PASS:
		_push_message(Locale.t("cmd_fired", [letter, name]))
	else:
		_push_message(Locale.t("cmd_stub", [letter, name]))


func _finish_directed_command(dir: Vector2i) -> void:
	var cmd := _pending_cmd
	_pending_cmd = U4Commands.Id.NONE
	var lang := GameState.lang_short()
	var d := "North"
	if dir.y > 0:
		d = "South"
	elif dir.x < 0:
		d = "West"
	elif dir.x > 0:
		d = "East"
	if GameState.language == "ko":
		d = {"North": "북쪽", "South": "남쪽", "West": "서쪽", "East": "동쪽"}[d]
	_push_message(Locale.t("cmd_directed_stub", [
		U4Commands.letter_for(cmd),
		U4Commands.label(cmd, lang),
		d,
	]))


func _refresh_party() -> void:
	if _roster:
		_roster.refresh()


func _push_location_message() -> void:
	if not _load_error.is_empty():
		return
	var tid := _world.tile_at(_tile_pos.x, _tile_pos.y)
	_push_message("(%d, %d)  tile %d" % [_tile_pos.x, _tile_pos.y, tid])


func _push_message(line: String) -> void:
	_msg_lines.append(line)
	while _msg_lines.size() > MSG_MAX_LINES:
		_msg_lines.remove_at(0)
	_cmd_line.text = "\n".join(_msg_lines)
