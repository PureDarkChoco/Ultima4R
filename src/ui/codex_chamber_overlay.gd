extends Control

## Chamber of the Codex art: 400×400 crop of each 640×400 endframe (the
## chamber square), in the map hole under the side panels / dialogue strip.

const _CodexChamber := preload("res://src/core/codex_chamber.gd")

const SRC_W := 640.0
const SRC_H := 400.0
## Chamber square sits ~x=18..366 on the 640×400 endframes; 320px cut the right.
const CROP_W := 400.0
const PAD := 8.0

var _dim: ColorRect
var _image: TextureRect
var _atlas: AtlasTexture
var _open := false
var _stage := 0


func _ready() -> void:
	_ensure_built()


func _ensure_built() -> void:
	if _dim != null:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 1)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_atlas = AtlasTexture.new()
	_atlas.region = Rect2(0, 0, CROP_W, SRC_H)
	_image = TextureRect.new()
	_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.texture = _atlas
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image)


func is_open() -> bool:
	return _open


func show_stage(stage: int) -> void:
	_ensure_built()
	_stage = clampi(stage, 1, _CodexChamber.STAGE_COUNT)
	var revealed := _CodexChamber.revealed_frame(_stage)
	var tex: Texture2D = null
	if revealed > 0:
		tex = _load_frame(revealed)
		if tex == null:
			push_warning("CodexChamberOverlay: missing frame %d" % revealed)
	_atlas.atlas = tex
	_atlas.region = Rect2(0, 0, CROP_W, SRC_H)
	_image.visible = tex != null
	_open = true
	visible = true


func hide_chamber() -> void:
	_open = false
	_stage = 0
	visible = false
	if _atlas != null:
		_atlas.atlas = null


func layout_in_map_view(view: Rect2) -> void:
	_ensure_built()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _dim != null:
		_dim.position = view.position
		_dim.size = view.size
	if _image != null:
		var inner := Rect2(
			view.position.x + PAD,
			view.position.y + PAD,
			maxf(view.size.x - PAD * 2.0, 8.0),
			maxf(view.size.y - PAD * 2.0, 8.0)
		)
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


func _load_frame(revealed: int) -> Texture2D:
	var path := _CodexChamber.frame_path(revealed)
	if path.is_empty():
		return null
	var tex := load(path) as Texture2D
	if tex != null:
		return tex
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)
