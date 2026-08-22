extends Node

## xu4 Ultima-IV module SFX (Sound enum order in xu4 sound.h / config.b).
## Streams live under res://assets/sfx/; missing files fail softly.

const SFX_DIR := "res://assets/sfx"
const POOL_SIZE := 8

## xu4 Sound ids (string keys for play_id).
const ID_TITLE_FADE := "title_fade"
const ID_WALK_NORMAL := "walk_normal"
const ID_WALK_SLOWED := "walk_slowed"
const ID_WALK_COMBAT := "walk_combat"
const ID_BLOCKED := "blocked"
const ID_ERROR := "error"
const ID_PC_ATTACK := "pc_attack"
const ID_PC_STRUCK := "pc_struck"
const ID_NPC_ATTACK := "npc_attack"
const ID_NPC_STRUCK := "npc_struck"
const ID_ACID := "acid"
const ID_SLEEP := "sleep"
const ID_POISON_EFFECT := "poison_effect"
const ID_POISON_DAMAGE := "poison_damage"
const ID_EVADE := "evade"
const ID_FLEE := "flee"
const ID_ITEM_STOLEN := "item_stolen"
const ID_LBHEAL := "lbheal"
const ID_LEVELUP := "levelup"
const ID_ELEVATE := "elevate"
const ID_MOONGATE := "moongate"
const ID_CANNON := "cannon"
const ID_PARTY_STRUCK := "party_struck"
const ID_RUMBLE := "rumble"
const ID_PREMAGIC := "premagic"
const ID_MAGIC := "magic"
const ID_WHIRLPOOL := "whirlpool"
const ID_STORM := "storm"
const ID_GATE_OPEN := "gate_open"
const ID_STONE_FALLING := "stone_falling"
const ID_WIND_GUST := "wind_gust"
const ID_UI_CLICK := "ui_click"
const ID_UI_TICK := "ui_tick"
const ID_FIZZLE := "fizzle"
const ID_IGNITE := "ignite"
const ID_FIRE_FIELD := "fire_field"
const ID_FIRE_WALKING := "fire_walking"
const ID_DOOR := "door"
const ID_JIMMY := "jimmy"

## Filename map matching xu4 module/Ultima-IV/config.b `sound:` (plus extras).
const FILES := {
	ID_TITLE_FADE: "title_fade_c64.ogg",
	ID_WALK_NORMAL: "walk_normal_c64.wav",
	ID_WALK_SLOWED: "walk_slowed_c64.wav",
	ID_WALK_COMBAT: "walk_combat_c64.wav",
	ID_BLOCKED: "blocked_dos.ogg",
	ID_ERROR: "error_dos.ogg",
	ID_PC_ATTACK: "pc_attack_dos.ogg",
	ID_PC_STRUCK: "pc_struck_dos.ogg",
	ID_NPC_ATTACK: "npc_attack_dos.ogg",
	ID_NPC_STRUCK: "npc_struck_dos.ogg",
	ID_ACID: "enemy_magic_proj_hit.ogg",
	ID_SLEEP: "enemy_magic_proj_hit.ogg",
	ID_POISON_EFFECT: "poison_effect.ogg",
	ID_POISON_DAMAGE: "poison_damage_dos.ogg",
	ID_EVADE: "evade_dos.ogg",
	ID_FLEE: "evade_dos.ogg",
	ID_ITEM_STOLEN: "evade_dos.ogg",
	ID_LBHEAL: "magic.ogg",
	ID_LEVELUP: "reaper_sleeper.ogg",
	ID_ELEVATE: "elevate.ogg",
	ID_MOONGATE: "moongate_dos.ogg",
	ID_CANNON: "cannon.wav",
	ID_PARTY_STRUCK: "party_struck.wav",
	ID_RUMBLE: "fx_tremor.ogg",
	ID_PREMAGIC: "spell_precast_dos.ogg",
	ID_MAGIC: "spell_flash_dos.ogg",
	ID_WHIRLPOOL: "whirlpool.wav",
	ID_STORM: "cyclone.wav",
	ID_GATE_OPEN: "gate_open.ogg",
	ID_STONE_FALLING: "stone_falling.ogg",
	ID_WIND_GUST: "wind_gust.ogg",
	ID_UI_CLICK: "ui_click.wav",
	ID_UI_TICK: "ui_tick.wav",
	ID_FIZZLE: "fizzle.wav",
	ID_IGNITE: "ignite.wav",
	ID_FIRE_FIELD: "poison_damage_dos.ogg",
	ID_FIRE_WALKING: "fire_field_walking.ogg",
	ID_DOOR: "door.ogg",
	ID_JIMMY: "jimmy.ogg",
}

const _AudioMusic := preload("res://src/core/audio_music.gd")
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "audio"

var _streams: Dictionary = {} ## id → AudioStream
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _title_player: AudioStreamPlayer
var _enabled := true
## Music volume minus 5% so SFX sits slightly under BGM (still audible at 10%).
var _volume_linear := 0.55
var music: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_pool()
	_title_player = AudioStreamPlayer.new()
	_title_player.name = "TitleFadePlayer"
	_title_player.bus = "Master"
	_title_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_title_player)
	for id in FILES:
		_load_stream(str(id), str(FILES[id]))
	## Extra DOS cannon take (config.b uses the rFX conversion as SOUND_CANNON).
	_load_stream("cannon_dos", "cannon_dos.ogg")
	music = _AudioMusic.new()
	music.name = "Music"
	add_child(music)
	_load_settings()
	_sync_volume_from_music()
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
	_sync_volume_from_music()
	_apply_volume()


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
	_sync_volume_from_music()
	_apply_volume()


func is_enabled() -> bool:
	return _enabled


func set_volume_linear(v: float) -> void:
	_volume_linear = clampf(v, 0.0, 1.0)
	_apply_volume()


func volume_linear() -> float:
	return _volume_linear


func play_title_fade() -> void:
	## Dedicated player so the rotating SFX pool cannot steal the title fade.
	if not _enabled:
		return
	if not _streams.has(ID_TITLE_FADE):
		_load_stream(ID_TITLE_FADE, str(FILES.get(ID_TITLE_FADE, "title_fade_c64.ogg")))
	var stream: Variant = _streams.get(ID_TITLE_FADE, null)
	if stream == null or _title_player == null:
		return
	_title_player.stop()
	_title_player.stream = stream as AudioStream
	_title_player.play()


func stop_title_fade() -> void:
	if _title_player != null and _title_player.playing:
		_title_player.stop()
	stop_id(ID_TITLE_FADE)


func stop_id(id: String) -> void:
	var stream: Variant = _streams.get(id, null)
	if stream == null:
		return
	for p in _pool:
		if p.stream == stream and p.playing:
			p.stop()
	if id == ID_TITLE_FADE:
		if _title_player != null and _title_player.playing:
			_title_player.stop()


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


func play_id_wait(id: String) -> void:
	## Play a clip and wait until it finishes (or skip if SFX are off).
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
	await player.finished


func play_id_wait_cap(id: String, max_sec: float) -> void:
	## Play a clip, stop it after `max_sec`, then return.
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
	var cap := minf(maxf(0.0, max_sec), stream_length(id))
	if cap <= 0.0:
		player.stop()
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		player.stop()
		return
	await tree.create_timer(cap).timeout
	if player.stream == stream and player.playing:
		player.stop()


func stream_length(id: String) -> float:
	var stream: Variant = _streams.get(id, null)
	if stream is AudioStream:
		return maxf(0.0, (stream as AudioStream).get_length())
	return 0.0


func play_foot_step(_terrain_tid: int = -1, _in_city: bool = false) -> void:
	## xu4 SOUND_WALK_NORMAL for foot (city and wilderness).
	play_id(ID_WALK_NORMAL)


func play_horse_step() -> void:
	## xu4 uses the same walk clip on horseback.
	play_id(ID_WALK_NORMAL)


func play_walk_slowed() -> void:
	play_id(ID_WALK_SLOWED)


func play_walk_combat() -> void:
	play_id(ID_WALK_COMBAT)


func play_blocked() -> void:
	play_id(ID_BLOCKED)


func play_error() -> void:
	play_id(ID_ERROR)


func play_door() -> void:
	play_id(ID_DOOR)


func play_jimmy() -> void:
	play_id(ID_JIMMY)


func play_pc_attack() -> void:
	play_id(ID_PC_ATTACK)


func play_pc_struck() -> void:
	play_id(ID_PC_STRUCK)


func play_npc_attack() -> void:
	play_id(ID_NPC_ATTACK)


func play_npc_struck() -> void:
	play_id(ID_NPC_STRUCK)


func play_party_struck() -> void:
	play_id(ID_PARTY_STRUCK)


func play_cannon() -> void:
	play_id(ID_CANNON)


func play_magic() -> void:
	play_id(ID_MAGIC)


func play_premagic() -> void:
	play_id(ID_PREMAGIC)


func play_cast_wait() -> void:
	## Default: magic flash only. Prefer `_play_cast_sfx` with the spell id.
	if not _enabled:
		return
	await play_id_wait(ID_MAGIC)


func play_moongate() -> void:
	play_id(ID_MOONGATE)


func play_rumble() -> void:
	play_id(ID_RUMBLE)


func play_whirlpool() -> void:
	play_id(ID_WHIRLPOOL)


func play_storm() -> void:
	play_id(ID_STORM)


func play_elevate() -> void:
	play_id(ID_ELEVATE)


func play_fizzle() -> void:
	play_id(ID_FIZZLE)


func play_ignite() -> void:
	play_id(ID_IGNITE)


func play_fire_field() -> void:
	play_id(ID_FIRE_FIELD)


func play_fire_walking() -> void:
	play_id(ID_FIRE_WALKING)


func play_evade() -> void:
	play_id(ID_EVADE)


func play_flee() -> void:
	play_id(ID_FLEE)


func play_poison_effect() -> void:
	play_id(ID_POISON_EFFECT)


func play_poison_damage() -> void:
	play_id(ID_POISON_DAMAGE)


func play_acid() -> void:
	play_id(ID_ACID)


func play_sleep() -> void:
	play_id(ID_SLEEP)


func play_gate_open() -> void:
	play_id(ID_GATE_OPEN)


func play_stone_falling() -> void:
	play_id(ID_STONE_FALLING)


func play_wind_gust() -> void:
	play_id(ID_WIND_GUST)


func play_lbheal() -> void:
	play_id(ID_LBHEAL)


func play_levelup() -> void:
	play_id(ID_LEVELUP)


func play_ui_click() -> void:
	play_id(ID_UI_CLICK)


func play_ui_tick() -> void:
	play_id(ID_UI_TICK)


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
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		push_warning("AudioSfx: missing %s" % path)
		return
	var res := load(path)
	if res is AudioStream:
		_streams[id] = res
	else:
		push_warning("AudioSfx: not an AudioStream: %s" % path)


func _sync_volume_from_music() -> void:
	if music and music.has_method("volume_linear"):
		_volume_linear = maxf(0.0, float(music.volume_linear()) - 0.04)


func _title_fade_linear() -> float:
	## Title fade sits 15 percentage points above BGM (10% → 25%, 20% → 35%).
	var music_lin := 0.6
	if music and music.has_method("volume_linear"):
		music_lin = float(music.volume_linear())
	return clampf(music_lin + 0.15, 0.0, 1.0)


func _apply_volume() -> void:
	var db := linear_to_db(maxf(0.0001, _volume_linear))
	for p in _pool:
		p.volume_db = db
	if _title_player != null:
		_title_player.volume_db = linear_to_db(maxf(0.0001, _title_fade_linear()))


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
