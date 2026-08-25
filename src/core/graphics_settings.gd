extends Node

## Map / HUD tile graphics style (New Color vs Apple II Color).

signal tileset_changed(tileset_id: String)

const CONFIG_PATH := "user://settings.cfg"
const SECTION := "prefs"
const KEY_TILESET := "tileset"
const _U4TileBank := preload("res://src/map/u4_tile_bank.gd")

const TILESET_IDS: Array[String] = [
	_U4TileBank.SET_NEW_COLOR,
	_U4TileBank.SET_APPLE2_COLOR,
]
const DEFAULT_TILESET := _U4TileBank.SET_NEW_COLOR

var _tileset_id := DEFAULT_TILESET


func _ready() -> void:
	_load_pref(false)


func tileset_id() -> String:
	return _tileset_id


func set_tileset_id(value: String, persist: bool = true) -> void:
	var next := _U4TileBank.normalize_set_id(value)
	if next == _tileset_id and _U4TileBank.active_set() == next and _U4TileBank.is_ready():
		return
	_tileset_id = next
	if not _U4TileBank.set_active_set(_tileset_id):
		push_error("GraphicsSettings: failed to load tileset %s" % _tileset_id)
	U4Tileset.clear_cache()
	if persist:
		persist_pref()
	tileset_changed.emit(_tileset_id)


func cycle_tileset(delta: int = 1) -> void:
	var index := TILESET_IDS.find(_tileset_id)
	if index < 0:
		index = 0
	set_tileset_id(TILESET_IDS[posmod(index + delta, TILESET_IDS.size())])


func persist_pref() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value(SECTION, KEY_TILESET, _tileset_id)
	cfg.save(CONFIG_PATH)


func restore_pref() -> void:
	_load_pref(true)


func _load_pref(emit_if_changed: bool) -> void:
	var cfg := ConfigFile.new()
	var saved := DEFAULT_TILESET
	if cfg.load(CONFIG_PATH) == OK:
		saved = str(cfg.get_value(SECTION, KEY_TILESET, DEFAULT_TILESET))
	saved = _U4TileBank.normalize_set_id(saved)
	var prev := _tileset_id
	_tileset_id = saved
	_U4TileBank.set_active_set(_tileset_id)
	if emit_if_changed and prev != _tileset_id:
		tileset_changed.emit(_tileset_id)
