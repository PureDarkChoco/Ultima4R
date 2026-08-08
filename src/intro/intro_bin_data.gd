class_name IntroBinData
extends RefCounted

## Binary intro blobs from Ultima IV TITLE.EXE (xu4 / ScummVM offsets).

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
	var need := OFF_SCRIPT + SCRIPT_SIZE
	if bytes.size() < need:
		push_warning("IntroBinData: TITLE.EXE too small (%d < %d)" % [bytes.size(), need])
		return false

	beastie1_frames = bytes.slice(OFF_BEASTIE1, OFF_BEASTIE1 + BEASTIE1_FRAMES)
	beastie2_frames = bytes.slice(OFF_BEASTIE2, OFF_BEASTIE2 + BEASTIE2_FRAMES)
	sig_data = bytes.slice(OFF_SIG, OFF_SIG + SIG_SIZE)
	intro_map = bytes.slice(OFF_MAP, OFF_MAP + MAP_SIZE)
	script_table = bytes.slice(OFF_SCRIPT, OFF_SCRIPT + SCRIPT_SIZE)
	base_tiles = bytes.slice(OFF_BASE_TILE, OFF_BASE_TILE + BASE_TILE_COUNT)

	## Classic U4 DOS tile indices are already 0..255 shape ids used by U4TileBank.
	loaded = (
		beastie1_frames.size() == BEASTIE1_FRAMES
		and beastie2_frames.size() == BEASTIE2_FRAMES
		and sig_data.size() == SIG_SIZE
		and intro_map.size() == MAP_SIZE
		and script_table.size() == SCRIPT_SIZE
		and base_tiles.size() == BASE_TILE_COUNT
	)
	if not loaded:
		push_warning("IntroBinData: incomplete blob load from %s" % path)
	return loaded
