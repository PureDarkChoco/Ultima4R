class_name WorldMapData
extends RefCounted

## Loads Ultima IV WORLD.MAP (256×256, 64 chunks of 32×32).
## Chunk file order matches xu4: row-major (x varies fastest across chunks).

const WIDTH := 256
const HEIGHT := 256
const CHUNK := 32
const CHUNK_COLS := 8
const CHUNK_ROWS := 8

## Row-major tile ids, index = x + y * WIDTH
var tiles: PackedByteArray = PackedByteArray()
var loaded: bool = false
var source_path: String = ""


func load_from_path(path: String) -> bool:
	var chunked := FileAccess.get_file_as_bytes(path)
	source_path = path
	if chunked.size() != WIDTH * HEIGHT:
		push_warning("WorldMapData: expected %d bytes, got %d from %s" % [
			WIDTH * HEIGHT, chunked.size(), path
		])
		tiles.clear()
		loaded = false
		return false
	tiles = _unchunk(chunked)
	loaded = true
	return true


func tile_at(x: int, y: int) -> int:
	if not loaded:
		return 0
	x = posmod(x, WIDTH)
	y = posmod(y, HEIGHT)
	return tiles[x + y * WIDTH]


func _unchunk(chunked: PackedByteArray) -> PackedByteArray:
	var flat := PackedByteArray()
	flat.resize(WIDTH * HEIGHT)
	for ych in CHUNK_ROWS:
		for xch in CHUNK_COLS:
			var src0 := (ych * CHUNK_COLS + xch) * (CHUNK * CHUNK)
			for ly in CHUNK:
				for lx in CHUNK:
					var wx := xch * CHUNK + lx
					var wy := ych * CHUNK + ly
					flat[wx + wy * WIDTH] = chunked[src0 + lx + ly * CHUNK]
	return flat
