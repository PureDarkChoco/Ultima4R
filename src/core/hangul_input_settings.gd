extends Node

## Physical-key Hangul layout used by the bundled libhangul composer.
## libhangul keyboard IDs: 2 = Dubeolsik, 39 = Sebeolsik 390, 3f = Sebeolsik Final.
## Korean/Latin mode is session state, toggled from platform 한/영 shortcuts.

signal layout_changed(layout_id: String)
signal input_mode_changed(korean: bool)

const CONFIG_PATH := "user://input.cfg"
const SECTION := "hangul"
const KEY_LAYOUT := "keyboard"
const LAYOUT_IDS: Array[String] = ["2", "39", "3f"]
const DEFAULT_LAYOUT := "2"

var _layout_id := DEFAULT_LAYOUT
var _korean_mode := true


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		var saved := str(cfg.get_value(SECTION, KEY_LAYOUT, DEFAULT_LAYOUT))
		if saved in LAYOUT_IDS:
			_layout_id = saved


func layout_id() -> String:
	return _layout_id


func set_layout_id(value: String, persist: bool = true) -> void:
	if value not in LAYOUT_IDS or value == _layout_id:
		return
	_layout_id = value
	if persist:
		var cfg := ConfigFile.new()
		cfg.load(CONFIG_PATH)
		cfg.set_value(SECTION, KEY_LAYOUT, _layout_id)
		cfg.save(CONFIG_PATH)
	layout_changed.emit(_layout_id)


func persist_pref() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value(SECTION, KEY_LAYOUT, _layout_id)
	cfg.save(CONFIG_PATH)


func restore_pref() -> void:
	var cfg := ConfigFile.new()
	var saved := DEFAULT_LAYOUT
	if cfg.load(CONFIG_PATH) == OK:
		saved = str(cfg.get_value(SECTION, KEY_LAYOUT, DEFAULT_LAYOUT))
	if saved not in LAYOUT_IDS:
		saved = DEFAULT_LAYOUT
	if saved == _layout_id:
		return
	_layout_id = saved
	layout_changed.emit(_layout_id)


func cycle_layout(delta: int = 1) -> void:
	var index := LAYOUT_IDS.find(_layout_id)
	if index < 0:
		index = 0
	set_layout_id(LAYOUT_IDS[posmod(index + delta, LAYOUT_IDS.size())])


func is_korean_mode() -> bool:
	return _korean_mode


func set_korean_mode(active: bool) -> void:
	if active == _korean_mode:
		return
	_korean_mode = active
	input_mode_changed.emit(_korean_mode)


func toggle_input_mode() -> void:
	set_korean_mode(not _korean_mode)
