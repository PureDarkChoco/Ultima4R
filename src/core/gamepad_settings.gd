extends Node

## Face-button confirm/cancel layout. Godot indices stay Xbox-style
## (A = south, B = east); Nintendo swaps which physical button confirms.

signal layout_changed(layout_id: String)

const CONFIG_PATH := "user://input.cfg"
const SECTION := "gamepad"
const KEY_LAYOUT := "ab_layout"
const LAYOUT_XBOX := "xbox"
const LAYOUT_NINTENDO := "nintendo"
const LAYOUT_IDS: Array[String] = [LAYOUT_XBOX, LAYOUT_NINTENDO]
const DEFAULT_LAYOUT := LAYOUT_XBOX

const _GameInput := preload("res://src/core/game_input.gd")

var _layout_id := DEFAULT_LAYOUT


func _init() -> void:
	_load_pref()


func layout_id() -> String:
	return _layout_id


func is_nintendo() -> bool:
	return _layout_id == LAYOUT_NINTENDO


func set_layout_id(value: String, persist: bool = true) -> void:
	if value not in LAYOUT_IDS or value == _layout_id:
		return
	_layout_id = value
	_GameInput.rebind_confirm_cancel()
	if persist:
		_write_pref()
	layout_changed.emit(_layout_id)


func persist_pref() -> void:
	_write_pref()


func restore_pref() -> void:
	var saved := _read_saved_layout()
	if saved == _layout_id:
		return
	_layout_id = saved
	_GameInput.rebind_confirm_cancel()
	layout_changed.emit(_layout_id)


func cycle_layout(delta: int = 1) -> void:
	var index := LAYOUT_IDS.find(_layout_id)
	if index < 0:
		index = 0
	set_layout_id(LAYOUT_IDS[posmod(index + delta, LAYOUT_IDS.size())])


func _load_pref() -> void:
	_layout_id = _read_saved_layout()


func _read_saved_layout() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return DEFAULT_LAYOUT
	var saved := str(cfg.get_value(SECTION, KEY_LAYOUT, DEFAULT_LAYOUT))
	if saved not in LAYOUT_IDS:
		return DEFAULT_LAYOUT
	return saved


func _write_pref() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value(SECTION, KEY_LAYOUT, _layout_id)
	cfg.save(CONFIG_PATH)
