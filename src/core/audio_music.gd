extends Node

## C64 Ultima IV loops (Ken Arnold), cut to original sheet-music lengths.
## Files live under res://assets/music/; missing tracks fail softly.

const MUSIC_DIR := "res://assets/music"
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "audio"

const ID_TOWNE := "towne"
const ID_COMBAT := "combat"
const ID_SHRINES := "shrines"
const ID_WANDER := "wander"
const ID_FANFARE := "fanfare"
const ID_DUNGEON := "dungeon"
const ID_CASTLE := "castle"
const ID_SHOPPING := "shopping"
const ID_RULE_BRITANNIA := "rule_britannia"

const FILES := {
	ID_TOWNE: "towne.ogg",
	ID_COMBAT: "combat.ogg",
	ID_SHRINES: "shrines.ogg",
	ID_WANDER: "wander.ogg",
	ID_FANFARE: "fanfare.ogg",
	ID_DUNGEON: "dungeon.ogg",
	ID_CASTLE: "castle.ogg",
	ID_SHOPPING: "shopping.ogg",
	ID_RULE_BRITANNIA: "rule_britannia.ogg",
}

var _streams: Dictionary = {}
var _player: AudioStreamPlayer
var _current := ""
var _pending := ""
var _ready_done := false
var _enabled := true
var _volume_linear := 0.6


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.bus = "Master"
	add_child(_player)
	for id in FILES.keys():
		_load_stream(str(id), str(FILES[id]))
	_load_settings()
	_apply_volume()
	_ready_done = true
	if not _pending.is_empty():
		var queued := _pending
		_pending = ""
		play(queued)


func play(id: String) -> void:
	var key := id.strip_edges()
	if key.is_empty():
		return
	if not _ready_done or _player == null:
		_pending = key
		return
	if key == _current:
		if _enabled and not _player.playing and _player.stream != null:
			_player.play()
		return
	var stream: Variant = _streams.get(key, null)
	if stream == null:
		push_warning("AudioMusic: no stream for %s" % key)
		return
	_current = key
	_player.stream = stream as AudioStream
	if _enabled:
		_player.play()
	else:
		_player.stop()


func stop() -> void:
	_current = ""
	if _player:
		_player.stop()


func current_id() -> String:
	return _current


func toggle() -> bool:
	set_enabled(not _enabled)
	return _enabled


func set_enabled(on: bool) -> void:
	_enabled = on
	_save_settings()
	if _player == null:
		return
	if _enabled:
		if _player.stream != null and not _player.playing:
			_player.play()
	else:
		_player.stop()


func is_enabled() -> bool:
	return _enabled


func set_volume_linear(v: float) -> void:
	_volume_linear = _snap_volume_step(v)
	_apply_volume()
	_save_settings()


func volume_linear() -> float:
	return _volume_linear


func set_volume_percent(pct: int) -> void:
	set_volume_linear(float(clampi(pct, 10, 100)) / 100.0)


func volume_percent() -> int:
	return clampi(int(round(_volume_linear * 10.0)) * 10, 10, 100)


func sync_world(ctx: Dictionary) -> void:
	## xu4/ScummVM: combat → shrine → shop/Hawkwind → LB (Rule Britannia) → castle → town → wander.
	## Fanfare is unused in the Apple II original (SMS uses it for camp).
	if bool(ctx.get("combat", false)):
		play(ID_COMBAT)
	elif bool(ctx.get("shrine", false)):
		play(ID_SHRINES)
	elif bool(ctx.get("shop", false)) or bool(ctx.get("hawkwind", false)):
		play(ID_SHOPPING)
	elif bool(ctx.get("lb_talk", false)):
		play(ID_RULE_BRITANNIA)
	elif bool(ctx.get("castle", false)):
		play(ID_CASTLE)
	elif bool(ctx.get("city", false)):
		play(ID_TOWNE)
	else:
		play(ID_WANDER)


func _load_stream(id: String, filename: String) -> void:
	var path := "%s/%s" % [MUSIC_DIR, filename]
	var res: Variant = null
	if ResourceLoader.exists(path):
		res = load(path)
	if not (res is AudioStream) and FileAccess.file_exists(path):
		res = AudioStreamOggVorbis.load_from_file(path)
	if res is AudioStream:
		if res is AudioStreamOggVorbis:
			(res as AudioStreamOggVorbis).loop = true
		_streams[id] = res
	else:
		push_warning("AudioMusic: failed to load %s" % path)


func _apply_volume() -> void:
	if _player:
		_player.volume_db = linear_to_db(maxf(0.0001, _volume_linear))


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	_enabled = bool(cfg.get_value(SETTINGS_SECTION, "music", true))
	_volume_linear = _snap_volume_step(float(cfg.get_value(SETTINGS_SECTION, "music_volume", _volume_linear)))


func _snap_volume_step(v: float) -> float:
	var pct := clampi(int(round(clampf(v, 0.1, 1.0) * 10.0)) * 10, 10, 100)
	return float(pct) / 100.0


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SETTINGS_SECTION, "music", _enabled)
	cfg.set_value(SETTINGS_SECTION, "music_volume", _volume_linear)
	cfg.save(SETTINGS_PATH)
