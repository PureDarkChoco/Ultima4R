class_name ResImage
extends RefCounted

## Load an Image from a res:// (or absolute) path in both editor and export.
## Prefer Texture2D / Image resources — Image.load() only works on loose files.

const IMAGE_PACK := "res://assets/cpu_images.u4pack"
const IMAGE_PACK_MAGIC := "U4IP"
const IMAGE_PACK_VERSION := 1

static var _pack_loaded := false
static var _pack_images: Dictionary = {}


static func load_rgba8(path: String) -> Image:
	if path.is_empty():
		return null
	var img := _from_pack(path)
	if img == null:
		img = _from_resource(path)
	if img == null:
		img = _from_image_file(path)
	return ensure_rgba8(img)


static func ensure_rgba8(img: Image) -> Image:
	if img == null or img.is_empty():
		return null
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


static func list_png_names(dir_path: String) -> PackedStringArray:
	## Exported PCKs often hide imported textures from DirAccess; use ResourceLoader first.
	var out: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	if ResourceLoader.has_method("list_directory"):
		for entry_v in ResourceLoader.list_directory(dir_path):
			var entry := String(entry_v)
			if entry.ends_with("/"):
				continue
			if not entry.ends_with(".png"):
				continue
			if seen.has(entry):
				continue
			seen[entry] = true
			out.append(entry)
	if not out.is_empty():
		return out
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".png") and not seen.has(fname):
			seen[fname] = true
			out.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	return out


static func _from_resource(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var res: Variant = ResourceLoader.load(path)
	if res is Texture2D:
		var tex_img: Image = (res as Texture2D).get_image()
		return tex_img.duplicate() if tex_img != null else null
	if res is Image:
		return (res as Image).duplicate()
	return null


static func _from_pack(path: String) -> Image:
	_ensure_pack_loaded()
	var img: Image = _pack_images.get(path) as Image
	return img.duplicate() if img != null else null


static func _ensure_pack_loaded() -> void:
	if _pack_loaded:
		return
	_pack_loaded = true
	var file := FileAccess.open(IMAGE_PACK, FileAccess.READ)
	if file == null:
		return
	if file.get_buffer(4).get_string_from_ascii() != IMAGE_PACK_MAGIC:
		push_warning("ResImage: bad image pack magic")
		return
	if file.get_32() != IMAGE_PACK_VERSION:
		push_warning("ResImage: unsupported image pack version")
		return
	var entry_count := file.get_32()
	for _entry in entry_count:
		var name_size := file.get_16()
		var data_size := file.get_32()
		if name_size <= 0 or data_size <= 0:
			push_warning("ResImage: invalid image pack entry")
			return
		var path := file.get_buffer(name_size).get_string_from_utf8()
		var png := file.get_buffer(data_size)
		var img := Image.new()
		if img.load_png_from_buffer(png) != OK:
			push_warning("ResImage: failed to decode %s" % path)
			continue
		_pack_images[path] = ensure_rgba8(img)


static func _from_image_file(path: String) -> Image:
	var img := Image.new()
	if img.load(path) == OK:
		return img
	var abs_path := ProjectSettings.globalize_path(path)
	if abs_path != path and FileAccess.file_exists(abs_path):
		return Image.load_from_file(abs_path)
	return null
