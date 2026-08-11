extends Node

## Thin SFX bus for exploration footsteps and (later) UX beeps.
## Streams live under res://assets/sfx/; missing files fail softly.

const SFX_DIR := "res://assets/sfx"
const POOL_SIZE := 4

const ID_WALK_FOOT := "walk_foot"
const ID_WALK_HORSE := "walk_horse"

var _streams: Dictionary = {} ## id → AudioStream
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _enabled := true
var _volume_linear := 0.7


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_pool()
	_load_stream(ID_WALK_FOOT, "walk_foot.wav")
	_load_stream(ID_WALK_HORSE, "walk_horse.wav")
	_apply_volume()


func set_enabled(on: bool) -> void:
	_enabled = on


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


func play_foot_step() -> void:
	play_id(ID_WALK_FOOT)


func play_horse_step() -> void:
	play_id(ID_WALK_HORSE)


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
