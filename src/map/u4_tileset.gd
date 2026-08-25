class_name U4Tileset
extends RefCounted

## Builds a Godot TileSet from individual shapes/*.png tiles (32×32 × 256).

const _U4TileBankScript := preload("res://src/map/u4_tile_bank.gd")
const TILE_SIZE := 32
const TILE_COUNT := 256

static var _cached: TileSet


static func get_tileset() -> TileSet:
	if _cached != null:
		return _cached
	_cached = build()
	return _cached


static func clear_cache() -> void:
	_cached = null


static func build() -> TileSet:
	var atlas_img: Image = _U4TileBankScript.stacked_atlas()
	if atlas_img == null or atlas_img.is_empty():
		push_error("U4Tileset: could not build atlas from shapes/")
		return TileSet.new()

	var tex := ImageTexture.create_from_image(atlas_img)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	for y in TILE_COUNT:
		var atlas_coords := Vector2i(0, y)
		if not atlas.has_tile(atlas_coords):
			atlas.create_tile(atlas_coords)

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tileset.add_source(atlas, 0)
	return tileset


## WORLD.MAP / SHAPES tile id → atlas coords on source 0.
static func atlas_coords_for_tile_id(tile_id: int) -> Vector2i:
	return Vector2i(0, clampi(tile_id, 0, TILE_COUNT - 1))
