extends Node

## Thin SFX bus for exploration footsteps and (later) UX beeps.
## Streams live under res://assets/sfx/; missing files fail softly.

const SFX_DIR := "res://assets/sfx"
const POOL_SIZE := 4

const ID_WALK_OUTDOOR := "walk_outdoor"
const ID_WALK_INDOOR := "walk_indoor"
const ID_WALK_HORSE := "walk_horse"
const ID_DOOR := "door"

## City paved floors → indoor steps; dirt/grass/scrub/forest/hills (and other) → outdoor.
const FOOT_INDOOR_TILES := {
	22: true, ## tile floor
	62: true, ## brick floor
	63: true, ## planks
}

const _AudioMusic := preload("res://src/core/audio_music.gd")
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "audio"

var _streams: Dictionary = {} ## id → AudioStream
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _enabled := true
var _volume_linear := 0.7
var music: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_pool()
	_load_stream(ID_WALK_OUTDOOR, "walk_outdoor.ogg")
	_load_stream(ID_WALK_INDOOR, "walk_indoor.ogg")
	_load_stream(ID_WALK_HORSE, "walk_horse.wav")
	_load_stream(ID_DOOR, "door.ogg")
	music = _AudioMusic.new()
	music.name = "Music"
	add_child(music)
	_load_settings()
	_apply_volume()


func music_play(id: String) -> void:
	if music and music.has_method("play"):
		music.play(id)


func music_stop() -> void:
	if music and music.has_method("stop"):
		music.stop()


func music_toggle() -> bool:
	if music and music.has_method("toggle"):
		return bool(music.toggle())
	return false


func music_enabled() -> bool:
	return music != null and bool(music.is_enabled())


func music_sync_world(ctx: Dictionary) -> void:
	if music and music.has_method("sync_world"):
		music.sync_world(ctx)


func music_set_enabled(on: bool, persist: bool = true) -> void:
	if music and music.has_method("set_enabled"):
		music.set_enabled(on, persist)


func music_set_volume_percent(pct: int, persist: bool = true) -> void:
	if music and music.has_method("set_volume_percent"):
		music.set_volume_percent(pct, persist)


func music_volume_percent() -> int:
	if music and music.has_method("volume_percent"):
		return int(music.volume_percent())
	return 60


func set_enabled(on: bool, persist: bool = true) -> void:
	_enabled = on
	if persist:
		_save_settings()


func persist_pref() -> void:
	_save_settings()
	if music and music.has_method("persist_pref"):
		music.persist_pref()


func restore_pref() -> void:
	_load_settings()
	if music and music.has_method("restore_pref"):
		music.restore_pref()


func is_enabled() -> bool:
	return _enabled


func set_volume_linear(v: float) -> void:
	_volume_linear = clampf(v, 0.0, 1.0)
	_apply_volume()


func volume_linear() -> float:
	return _volume_linear


func play_id(id: String) -> void:
	if not _enabled:
		return
	var stream: Variant = _streams.get(id, null)
	if stream == null:
		return
	var player := _next_player()
	if player == null:
		return
	player.stream = stream as AudioStream
	player.play()


func play_foot_step(terrain_tid: int = -1, in_city: bool = false) -> void:
	## Outdoor soft ground → grass/leaves clip; city tile floors → indoor steps.
	## Other tiles fall back to outdoor (replaces the old single walk_foot).
	if in_city and FOOT_INDOOR_TILES.has(terrain_tid):
		play_id(ID_WALK_INDOOR)
		return
	play_id(ID_WALK_OUTDOOR)


func play_horse_step() -> void:
	play_id(ID_WALK_HORSE)


func play_door() -> void:
	play_id(ID_DOOR)


func _build_pool() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer%d" % i
		p.bus = "Master"
		add_child(p)
		_pool.append(p)


func _next_player() -> AudioStreamPlayer:
	if _pool.is_empty():
		return null
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	return p


func _load_stream(id: String, filename: String) -> void:
	var path := "%s/%s" % [SFX_DIR, filename]
	if not ResourceLoader.exists(path):
		push_warning("AudioSfx: missing %s" % path)
		return
	var res := load(path)
	if res is AudioStream:
		_streams[id] = res
	else:
		push_warning("AudioSfx: not an AudioStream: %s" % path)


func _apply_volume() -> void:
	var db := linear_to_db(maxf(0.0001, _volume_linear))
	for p in _pool:
		p.volume_db = db


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	_enabled = bool(cfg.get_value(SETTINGS_SECTION, "sfx", true))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SETTINGS_SECTION, "sfx", _enabled)
	cfg.save(SETTINGS_PATH)
