extends Control

## Chamber of the Codex art: left half of each 640×400 endframe, centered
## in the explore map (not the dialogue strip).

const _CodexChamber := preload("res://src/core/codex_chamber.gd")

const SRC_W := 640.0
const SRC_H := 400.0
const CROP_W := 320.0
const PAD := 12.0

var _dim: ColorRect
var _image: TextureRect
var _atlas: AtlasTexture
var _open := false
var _stage := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	clip_contents = true
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 1)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_atlas = AtlasTexture.new()
	_atlas.region = Rect2(0, 0, CROP_W, SRC_H)
	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.texture = _atlas
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image)


func is_open() -> bool:
	return _open


func show_stage(stage: int) -> void:
	_stage = clampi(stage, 1, _CodexChamber.STAGE_COUNT)
	var path := _CodexChamber.frame_path(_stage)
	var tex := load(path) as Texture2D
	if tex == null:
		hide_chamber()
		return
	_atlas.atlas = tex
	_atlas.region = Rect2(0, 0, CROP_W, SRC_H)
	_open = true
	visible = true


func hide_chamber() -> void:
	_open = false
	_stage = 0
	visible = false
	if _atlas != null:
		_atlas.atlas = null


func layout_in_map_view(view: Rect2) -> void:
	position = view.position
	size = view.size
	custom_minimum_size = Vector2.ZERO
	if _dim != null:
		_dim.position = Vector2.ZERO
		_dim.size = size
	if _image != null:
		var inner := Rect2(PAD, PAD, maxf(size.x - PAD * 2.0, 8.0), maxf(size.y - PAD * 2.0, 8.0))
		var aspect := CROP_W / SRC_H
		var fit_w := inner.size.x
		var fit_h := fit_w / aspect
		if fit_h > inner.size.y:
			fit_h = inner.size.y
			fit_w = fit_h * aspect
		_image.size = Vector2(fit_w, fit_h)
		_image.position = Vector2(
			inner.position.x + (inner.size.x - fit_w) * 0.5,
			inner.position.y + (inner.size.y - fit_h) * 0.5
		)
