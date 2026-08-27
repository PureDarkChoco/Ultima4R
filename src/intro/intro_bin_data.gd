class_name IntroBinData
extends RefCounted

## Binary intro blobs from Ultima IV TITLE.EXE (xu4 / ScummVM offsets).
## Some retail builds (e.g. GOG) relocate the sig/map/script/beastie block by +0x200c
## while keeping base_tiles and the string table at the classic offsets.

const MAP_W := 19
const MAP_H := 5
const MAP_SIZE := MAP_W * MAP_H ## 95
const SCRIPT_SIZE := 548
const BASE_TILE_COUNT := 15
const BEASTIE1_FRAMES := 0x80
const BEASTIE2_FRAMES := 0x40
const SIG_SIZE := 533

const OFF_BEASTIE1 := 0x7380
const OFF_BEASTIE2 := 0x73f8
const OFF_SIG := 0x746e
const OFF_MAP := 0x7683
const OFF_SCRIPT := 0x76e2
const OFF_BASE_TILE := 0x40c8
## GOG / some PC repacks shift only the animated intro blobs.
const BLOB_RELOC_DELTA := 0x200c

var sig_data: PackedByteArray = PackedByteArray()
var intro_map: PackedByteArray = PackedByteArray() ## MAP_SIZE tile index bytes
var script_table: PackedByteArray = PackedByteArray()
var base_tiles: PackedByteArray = PackedByteArray() ## BASE_TILE_COUNT shape ids
var beastie1_frames: PackedByteArray = PackedByteArray()
var beastie2_frames: PackedByteArray = PackedByteArray()
var loaded: bool = false
var source_path: String = ""


func load_from_path(path: String) -> bool:
	loaded = false
	source_path = path
	sig_data = PackedByteArray()
	intro_map = PackedByteArray()
	script_table = PackedByteArray()
	base_tiles = PackedByteArray()
	beastie1_frames = PackedByteArray()
	beastie2_frames = PackedByteArray()

	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_warning("IntroBinData: cannot read %s" % path)
		return false
	var need := OFF_SCRIPT + BLOB_RELOC_DELTA + SCRIPT_SIZE
	if bytes.size() < need:
		push_warning("IntroBinData: TITLE.EXE too small (%d < %d)" % [bytes.size(), need])
		return false

	base_tiles = bytes.slice(OFF_BASE_TILE, OFF_BASE_TILE + BASE_TILE_COUNT)
	if not _base_tiles_valid(base_tiles):
		push_warning("IntroBinData: base tile ids look invalid in %s" % path)

	for delta in [0, BLOB_RELOC_DELTA]:
		if _try_load_blobs(bytes, delta):
			loaded = true
			return true

	push_warning("IntroBinData: could not locate intro map/signature blobs in %s" % path)
	return false


func _try_load_blobs(bytes: PackedByteArray, delta: int) -> bool:
	var sig_off := OFF_SIG + delta
	var map_off := OFF_MAP + delta
	var script_off := OFF_SCRIPT + delta
	var b1_off := OFF_BEASTIE1 + delta
	var b2_off := OFF_BEASTIE2 + delta
	var end := script_off + SCRIPT_SIZE
	if end > bytes.size():
		return false

	var sig := bytes.slice(sig_off, sig_off + SIG_SIZE)
	var intro := bytes.slice(map_off, map_off + MAP_SIZE)
	var script := bytes.slice(script_off, script_off + SCRIPT_SIZE)
	var b1 := bytes.slice(b1_off, b1_off + BEASTIE1_FRAMES)
	var b2 := bytes.slice(b2_off, b2_off + BEASTIE2_FRAMES)
	if (
		sig.size() != SIG_SIZE
		or intro.size() != MAP_SIZE
		or script.size() != SCRIPT_SIZE
		or b1.size() != BEASTIE1_FRAMES
		or b2.size() != BEASTIE2_FRAMES
	):
		return false
	if not _sig_data_valid(sig):
		return false
	if not _intro_map_valid(intro, bytes, map_off):
		return false
	if not _script_valid(script):
		return false
	if not _beastie_frames_valid(b1) or not _beastie_frames_valid(b2):
		return false

	sig_data = sig
	intro_map = intro
	script_table = script
	beastie1_frames = b1
	beastie2_frames = b2
	return true


static func _sig_data_valid(sig: PackedByteArray) -> bool:
	var ok := 0
	var bad := 0
	var step := 0
	while step + 1 < sig.size() and sig[step] != 0:
		var px := int(sig[step]) - 0x4C
		var py := 0xC0 - int(sig[step + 1])
		if px >= 0 and px < 130 and py >= 0 and py < 20:
			ok += 1
		else:
			bad += 1
		step += 2
	return ok >= 150 and bad <= 30


static func _intro_map_valid(intro: PackedByteArray, bytes: PackedByteArray, map_off: int) -> bool:
	if map_off <= 0 or map_off >= bytes.size():
		return false
	if bytes[map_off - 1] != 0:
		return false
	var low := 0
	for b in intro:
		if b <= 20:
			low += 1
	return low >= 12


static func _script_valid(script: PackedByteArray) -> bool:
	var score := 0
	var i := 0
	while i < script.size():
		var cmd := int(script[i]) >> 4
		match cmd:
			0, 1, 2, 3, 4:
				if i + 1 >= script.size():
					break
				score += 2
				i += 2
			7, 8:
				score += 1
				i += 1
			0xF:
				score += 1
				i += 1
			_:
				score -= 1
				i += 1
	return score >= 400


static func _beastie_frames_valid(frames: PackedByteArray) -> bool:
	if frames.is_empty():
		return false
	var mx := 0
	for b in frames:
		mx = maxi(mx, int(b))
	return mx <= 17


static func _base_tiles_valid(base: PackedByteArray) -> bool:
	if base.size() != BASE_TILE_COUNT:
		return false
	for b in base:
		if int(b) > 255:
			return false
	return true
