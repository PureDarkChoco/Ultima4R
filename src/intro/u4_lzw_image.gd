class_name U4LzwImage
extends RefCounted

## Ultima IV LZW (fixed 12-bit codes + hash dictionary) and EGA 4bpp → Image.

const EGA_W := 320
const EGA_H := 200
const EGA_RAW := EGA_W * EGA_H / 2 ## 32000 packed nibble bytes

## Standard EGA 16-color palette (xu4 / PC).
const EGA_RGB: Array[Color] = [
	Color8(0x00, 0x00, 0x00), Color8(0x00, 0x00, 0xaa),
	Color8(0x00, 0xaa, 0x00), Color8(0x00, 0xaa, 0xaa),
	Color8(0xaa, 0x00, 0x00), Color8(0xaa, 0x00, 0xaa),
	Color8(0xaa, 0x55, 0x00), Color8(0xaa, 0xaa, 0xaa),
	Color8(0x55, 0x55, 0x55), Color8(0x55, 0x55, 0xff),
	Color8(0x55, 0xff, 0x55), Color8(0x55, 0xff, 0xff),
	Color8(0xff, 0x55, 0x55), Color8(0xff, 0x55, 0xff),
	Color8(0xff, 0xff, 0x55), Color8(0xff, 0xff, 0xff),
]


static func load_ega_path(path: String, transparent_index: int = -1) -> Image:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_warning("U4LzwImage: cannot read %s" % path)
		return null
	return load_ega_bytes(bytes, transparent_index)


static func load_ega_bytes(compressed: PackedByteArray, transparent_index: int = -1) -> Image:
	var raw := decompress(compressed)
	if raw.is_empty():
		push_warning("U4LzwImage: bad decompress (%d bytes)" % raw.size())
		return null
	return _ega_raw_to_image(raw, transparent_index)


static func load_ega_rle_path(path: String, transparent_index: int = -1) -> Image:
	## AVATAR.EXE pictures (STONCRCL, KEY7, virtue frames) are RLE, not LZW.
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_warning("U4LzwImage: cannot read %s" % path)
		return null
	return load_ega_rle_bytes(bytes, transparent_index)


static func load_ega_rle_bytes(compressed: PackedByteArray, transparent_index: int = -1) -> Image:
	var raw := rle_decompress(compressed)
	if raw.is_empty():
		push_warning("U4LzwImage: bad RLE decompress (%d bytes)" % raw.size())
		return null
	return _ega_raw_to_image(raw, transparent_index)


static func rle_decompress(compressed: PackedByteArray) -> PackedByteArray:
	## xu4 rleDecompress — 0x02, count, value; a literal 0x02 must be a run.
	const RUN := 2
	var out := PackedByteArray()
	var i := 0
	var n := compressed.size()
	while i < n:
		var ch := compressed[i]
		i += 1
		if ch == RUN:
			if i + 1 >= n:
				break
			var count := compressed[i]
			var val := compressed[i + 1]
			i += 2
			for _j in count:
				out.append(val)
		else:
			out.append(ch)
	return out


static func _ega_raw_to_image(raw: PackedByteArray, transparent_index: int) -> Image:
	var w := EGA_W
	var h := EGA_H
	if raw.size() >= 640 * 400 / 2:
		w = 640
		h = 400
	elif raw.size() < EGA_RAW:
		push_warning("U4LzwImage: bad raw size (%d bytes)" % raw.size())
		return null
	return ega4_to_image(raw, w, h, transparent_index)


static func ega4_to_image(raw: PackedByteArray, w: int, h: int, transparent_index: int = -1) -> Image:
	## Packed 4bpp: high nibble = left pixel.
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var need := w * h / 2
	var n := mini(raw.size(), need)
	var pi := 0
	for i in n:
		var b := raw[i]
		var hi := b >> 4
		var lo := b & 0xf
		_set_idx(img, pi % w, pi / w, hi, transparent_index)
		pi += 1
		_set_idx(img, pi % w, pi / w, lo, transparent_index)
		pi += 1
	return img


static func crop(src: Image, x: int, y: int, w: int, h: int) -> Image:
	if src == null or src.is_empty():
		return null
	var r := Rect2i(x, y, w, h)
	r = r.intersection(Rect2i(0, 0, src.get_width(), src.get_height()))
	if r.size.x <= 0 or r.size.y <= 0:
		return null
	return src.get_region(r)


static func _set_idx(img: Image, x: int, y: int, idx: int, transparent_index: int) -> void:
	var c: Color = EGA_RGB[idx & 0xf]
	if transparent_index >= 0 and idx == transparent_index:
		c.a = 0.0
	img.set_pixel(x, y, c)


## --- U4 LZW (port of ScummVM ultima4/core/lzw) ---------------------------------

class _DictEntry:
	var root: int = 0
	var codeword: int = 0
	var occupied: bool = false


static func decompress(compressed: PackedByteArray) -> PackedByteArray:
	if compressed.is_empty():
		return PackedByteArray()
	const MAX_DICT_ENTRIES := 0xccc
	const DICT_SIZE := 0x1000
	var dictionary: Array = []
	dictionary.resize(DICT_SIZE)
	for i in DICT_SIZE:
		dictionary[i] = _DictEntry.new()
	for i in 0x100:
		(dictionary[i] as _DictEntry).occupied = true

	var stack: Array[int] = []
	var bits_read: int = 0
	var out := PackedByteArray()
	var codewords_in_dict := 0
	var compressed_bits := compressed.size() * 8

	if bits_read + 12 > compressed_bits:
		return out

	var pair := _next_code(compressed, bits_read)
	var old_code: int = pair[0]
	bits_read = pair[1]
	var character: int = old_code & 0xff
	out.append(character)

	while bits_read + 12 <= compressed_bits:
		pair = _next_code(compressed, bits_read)
		var new_code: int = pair[0]
		bits_read = pair[1]
		stack.clear()
		var unknown := false
		if (dictionary[new_code] as _DictEntry).occupied:
			_get_string(new_code, dictionary, stack)
		else:
			unknown = true
			stack.append(character)
			_get_string(old_code, dictionary, stack)
		character = stack[stack.size() - 1]
		while not stack.is_empty():
			out.append(stack.pop_back())
		var newpos := _new_hash(character, old_code, dictionary)
		var ne: _DictEntry = dictionary[newpos]
		ne.root = character
		ne.codeword = old_code
		ne.occupied = true
		codewords_in_dict += 1
		if unknown and newpos != new_code:
			return PackedByteArray()
		if codewords_in_dict > MAX_DICT_ENTRIES:
			codewords_in_dict = 0
			for i in DICT_SIZE:
				var e: _DictEntry = dictionary[i]
				e.root = 0
				e.codeword = 0
				e.occupied = i < 0x100
			if bits_read + 12 <= compressed_bits:
				pair = _next_code(compressed, bits_read)
				new_code = pair[0]
				bits_read = pair[1]
				character = new_code & 0xff
				out.append(character)
			else:
				return out
		old_code = new_code
	return out


static func _next_code(mem: PackedByteArray, bits_read: int) -> Array:
	var bi := bits_read / 8
	if bi + 1 >= mem.size():
		return [0, bits_read + 12]
	var codeword := (mem[bi] << 8) + mem[bi + 1]
	codeword = codeword >> (4 - (bits_read % 8))
	codeword = codeword & 0xfff
	return [codeword, bits_read + 12]


static func _get_string(codeword: int, dictionary: Array, stack: Array[int]) -> void:
	var current := codeword
	var guard := 0
	while current > 0xff:
		var e: _DictEntry = dictionary[current]
		stack.append(e.root)
		current = e.codeword
		guard += 1
		if guard > 0x1000:
			break
	stack.append(current)


static func _new_hash(root: int, codeword: int, dictionary: Array) -> int:
	var h := _probe1(root, codeword)
	if _hash_found(h, root, codeword, dictionary):
		return h
	h = _probe2(root, codeword)
	if _hash_found(h, root, codeword, dictionary):
		return h
	while true:
		h = _probe3(h)
		if _hash_found(h, root, codeword, dictionary):
			return h
	return 0


static func _hash_found(hash_code: int, root: int, codeword: int, dictionary: Array) -> bool:
	if hash_code <= 0xff:
		return false
	var e: _DictEntry = dictionary[hash_code]
	if e.occupied:
		return e.root == root and e.codeword == codeword
	return true


static func _probe1(root: int, codeword: int) -> int:
	return ((root << 4) ^ codeword) & 0xfff


static func _probe2(root: int, codeword: int) -> int:
	## Simulated 8086 mul + double rcl (ScummVM hash.cpp).
	var ax: int = ((root << 1) + codeword) | 0x800
	var temp: int = (ax & 0xff) * (ax & 0xff)
	temp += 2 * (ax & 0xff) * (ax >> 8) * 0x100
	var dx: int = (temp >> 16) + (ax >> 8) * (ax >> 8)
	ax = temp & 0xffff
	var carry: int = 0 if dx == 0 else 1
	var regs: Array[int] = [ax, dx]
	for _i in 2:
		for j in 2:
			var old_carry := carry
			carry = (regs[j] >> 15) & 1
			regs[j] = ((regs[j] << 1) | old_carry) & 0xffff
	return ((regs[0] >> 8) | (regs[1] << 8)) & 0xfff


static func _probe3(hash_code: int) -> int:
	return (hash_code + 0x1fd) & 0xfff
