extends Control

## Chamber of the Codex art: 400×400 crop of each 640×400 endframe (the
## chamber square), in the map hole under the side panels / dialogue strip.

const _CodexChamber := preload("res://src/core/codex_chamber.gd")
const _U4Lzw := preload("res://src/intro/u4_lzw_image.gd")

const SRC_W := 640.0
const SRC_H := 400.0
## Chamber square sits ~x=18..366 on the 640×400 endframes; 320px cut the right.
const CROP_W := 400.0
const PAD := 8.0
## xu4 split: 42ms per pixel of half the map hole (~3.7s on classic 176px view).
const SPLIT_SEC := 3.7

var _dim: ColorRect
var _image: TextureRect
var _atlas: AtlasTexture
var _left: TextureRect
var _right: TextureRect
var _left_atlas: AtlasTexture
var _right_atlas: AtlasTexture
var _open := false
var _stage := 0
var _crop_w := CROP_W
var _crop_h := SRC_H
var _view := Rect2()


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
	_image = _make_tex_rect(_atlas)
	add_child(_image)
	_left_atlas = AtlasTexture.new()
	_right_atlas = AtlasTexture.new()
	_left = _make_tex_rect(_left_atlas)
	_right = _make_tex_rect(_right_atlas)
	_left.visible = false
	_right.visible = false
	_left.stretch_mode = TextureRect.STRETCH_SCALE
	_right.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_left)
	add_child(_right)


func _make_tex_rect(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture = tex
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func is_open() -> bool:
	return _open


func show_stage(stage: int) -> void:
	_ensure_built()
	_hide_split()
	_stage = clampi(stage, 1, _CodexChamber.STAGE_COUNT)
	var revealed := _CodexChamber.revealed_frame(_stage)
	var tex: Texture2D = null
	if revealed > 0:
		tex = _load_frame(revealed)
		if tex == null:
			push_warning("CodexChamberOverlay: missing frame %d" % revealed)
	_crop_w = CROP_W
	_crop_h = SRC_H
	_atlas.atlas = tex
	_atlas.region = Rect2(0, 0, _crop_w, _crop_h)
	_image.visible = tex != null
	_open = true
	visible = true
	if _view.size.x > 0.0:
		layout_in_map_view(_view)


func show_picture(tex: Texture2D) -> void:
	_ensure_built()
	_hide_split()
	if tex == null:
		erase_picture()
		return
	var side := minf(float(tex.get_width()), float(tex.get_height()))
	_crop_w = side
	_crop_h = side
	_atlas.atlas = tex
	_atlas.region = Rect2(0, 0, _crop_w, _crop_h)
	_image.visible = true
	_open = true
	visible = true
	if _view.size.x > 0.0:
		layout_in_map_view(_view)


func erase_picture() -> void:
	_ensure_built()
	_hide_split()
	_atlas.atlas = null
	_image.visible = false
	_open = true
	visible = true


func show_stoncrcl() -> void:
	## xu4 screenDrawImageInMapArea(BKGD_STONCRCL): crop the 176×176 map hole
	## out of the 320×200 full-screen RLE picture (8px border).
	var tex := load_stoncrcl()
	if tex == null:
		erase_picture()
		return
	var scale := float(tex.get_width()) / 320.0
	var inset := 8.0 * scale
	var side := 176.0 * scale
	_crop_w = side
	_crop_h = side
	_atlas.atlas = tex
	_atlas.region = Rect2(inset, inset, side, side)
	_image.visible = true
	_open = true
	visible = true
	_hide_split()
	if _view.size.x > 0.0:
		layout_in_map_view(_view)


func hide_chamber() -> void:
	_open = false
	_stage = 0
	visible = false
	_hide_split()
	if _atlas != null:
		_atlas.atlas = null


func play_split() -> void:
	## xu4 peels the Codex left/right to reveal the map hole (infinity / black).
	_ensure_built()
	if _image == null or not _image.visible or _atlas == null or _atlas.atlas == null:
		erase_picture()
		return
	var half_src := _crop_w * 0.5
	_left_atlas.atlas = _atlas.atlas
	_left_atlas.region = Rect2(0, 0, half_src, _crop_h)
	_right_atlas.atlas = _atlas.atlas
	_right_atlas.region = Rect2(half_src, 0, half_src, _crop_h)
	var half_w := _image.size.x * 0.5
	_left.position = _image.position
	_left.size = Vector2(half_w, _image.size.y)
	_right.position = Vector2(_image.position.x + half_w, _image.position.y)
	_right.size = Vector2(half_w, _image.size.y)
	_left.visible = true
	_right.visible = true
	_image.visible = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_left, "position:x", _left.position.x - half_w, SPLIT_SEC)
	tw.tween_property(_right, "position:x", _right.position.x + half_w, SPLIT_SEC)
	await tw.finished
	_hide_split()
	_atlas.atlas = null


func layout_in_map_view(view: Rect2) -> void:
	_ensure_built()
	_view = view
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
		var aspect := _crop_w / maxf(_crop_h, 1.0)
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


func _hide_split() -> void:
	if _left != null:
		_left.visible = false
	if _right != null:
		_right.visible = false


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


static func load_stoncrcl() -> Texture2D:
	var path := _CodexChamber.stoncrcl_path()
	if path.is_empty():
		push_warning("CodexChamberOverlay: STONCRCL.EGA not found")
		return null
	var img: Image = _U4Lzw.load_ega_rle_path(path, -1)
	if img == null or img.is_empty():
		push_warning("CodexChamberOverlay: failed to decode %s" % path)
		return null
	return ImageTexture.create_from_image(img)
