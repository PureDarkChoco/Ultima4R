class_name LocateChart
extends RefCounted

## World Locate (L) exploration: wide-view LOS reveal, persisted in the save.

const _LineOfSight := preload("res://src/map/line_of_sight.gd")
const _TileRules := preload("res://src/map/tile_rules.gd")
const _DungeonPortals := preload("res://src/map/dungeon_portals.gd")
const _ShrinePortals := preload("res://src/map/shrine_portals.gd")

const WORLD := 256
const MASK_BYTES := WORLD * WORLD / 8
const SKULL := Vector2i(197, 245)
const BELL := Vector2i(176, 208)
const TILE_DUNGEON := 9
const TILE_SHRINE := 30
const TILE_MOUNTAIN := 8
## Hide surrounding sea (Chebyshev) so the chart does not outline the secret.
const ABYSS_WATER_RADIUS := 10
const SKULL_REGION_RADIUS := 12
const BELL_REGION_RADIUS := 6

## Cities / keeps always drawn on the silhouette chart.
const ALWAYS_SETTLEMENT := {
	10: true, 11: true, 12: true, 14: true, 29: true,
}


static var _abyss_land: PackedByteArray = PackedByteArray()
static var _abyss_region: PackedByteArray = PackedByteArray()
static var _skull_region: PackedByteArray = PackedByteArray()
static var _bell_region: PackedByteArray = PackedByteArray()
## Tile rect covering the island plus 1 for rounded-coast blit.
static var _abyss_outline_rect := Rect2i()


static func empty_mask() -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(MASK_BYTES)
	m.fill(0)
	return m


static func mask_from_save(raw: Variant) -> PackedByteArray:
	var m := empty_mask()
	if typeof(raw) != TYPE_STRING:
		return m
	var s := str(raw).strip_edges()
	if s.is_empty():
		return m
	var decoded := Marshalls.base64_to_raw(s)
	if decoded.size() != MASK_BYTES:
		return m
	return decoded


static func mask_to_save(mask: PackedByteArray) -> String:
	if mask.size() != MASK_BYTES:
		return ""
	return Marshalls.raw_to_base64(mask)


static func is_explored(mask: PackedByteArray, x: int, y: int) -> bool:
	if mask.size() != MASK_BYTES:
		return false
	x = posmod(x, WORLD)
	y = posmod(y, WORLD)
	var i := x + y * WORLD
	return (mask[i >> 3] & (1 << (i & 7))) != 0


static func mark_explored(mask: PackedByteArray, x: int, y: int) -> bool:
	if mask.size() != MASK_BYTES:
		return false
	x = posmod(x, WORLD)
	y = posmod(y, WORLD)
	var i := x + y * WORLD
	var bit := 1 << (i & 7)
	var b := i >> 3
	if (mask[b] & bit) != 0:
		return false
	mask[b] |= bit
	return true


static func ensure_abyss_mask(world) -> void:
	ensure_secret_masks(world)


static func ensure_secret_masks(world) -> void:
	if world == null or not bool(world.loaded):
		return
	if _abyss_region.size() == MASK_BYTES:
		return
	_abyss_land = empty_mask()
	_abyss_region = empty_mask()
	_skull_region = empty_mask()
	_bell_region = empty_mask()
	_flood_abyss_land(world)
	_dilate_water(_abyss_land, _abyss_region, world, ABYSS_WATER_RADIUS)
	_abyss_outline_rect = _mask_bbox(_abyss_region).grow(1)
	_abyss_outline_rect = _abyss_outline_rect.intersection(Rect2i(0, 0, WORLD, WORLD))
	_mark_disk(_skull_region, SKULL, SKULL_REGION_RADIUS)
	_mark_disk(_bell_region, BELL, BELL_REGION_RADIUS)


static func _flood_abyss_land(world) -> void:
	var start: Vector2i = _DungeonPortals.ABYSS_ENTRANCE
	if int(world.tile_at(start.x, start.y)) <= 2:
		return
	var q: Array[Vector2i] = [start]
	mark_explored(_abyss_land, start.x, start.y)
	var head := 0
	while head < q.size():
		var p: Vector2i = q[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = p.x + d.x
			var ny: int = p.y + d.y
			if nx < 0 or ny < 0 or nx >= WORLD or ny >= WORLD:
				continue
			if is_explored(_abyss_land, nx, ny):
				continue
			if int(world.tile_at(nx, ny)) <= 2:
				continue
			mark_explored(_abyss_land, nx, ny)
			q.append(Vector2i(nx, ny))


static func _dilate_water(land: PackedByteArray, dest: PackedByteArray, world, radius: int) -> void:
	for y in WORLD:
		for x in WORLD:
			if not is_explored(land, x, y):
				continue
			mark_explored(dest, x, y)
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if maxi(absi(dx), absi(dy)) > radius:
						continue
					var nx: int = x + dx
					var ny: int = y + dy
					if nx < 0 or ny < 0 or nx >= WORLD or ny >= WORLD:
						continue
					if _in_disk(nx, ny, SKULL, SKULL_REGION_RADIUS):
						continue
					if _in_disk(nx, ny, BELL, BELL_REGION_RADIUS):
						continue
					if int(world.tile_at(nx, ny)) <= 2:
						mark_explored(dest, nx, ny)


static func _in_disk(x: int, y: int, center: Vector2i, radius: int) -> bool:
	return maxi(absi(x - center.x), absi(y - center.y)) <= radius


static func _mark_disk(dest: PackedByteArray, center: Vector2i, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if maxi(absi(dx), absi(dy)) > radius:
				continue
			var nx: int = center.x + dx
			var ny: int = center.y + dy
			if nx < 0 or ny < 0 or nx >= WORLD or ny >= WORLD:
				continue
			mark_explored(dest, nx, ny)


static func _mask_bbox(mask: PackedByteArray) -> Rect2i:
	var min_x := WORLD
	var min_y := WORLD
	var max_x := -1
	var max_y := -1
	for y in WORLD:
		for x in WORLD:
			if not is_explored(mask, x, y):
				continue
			if x < min_x:
				min_x = x
			if y < min_y:
				min_y = y
			if x > max_x:
				max_x = x
			if y > max_y:
				max_y = y
	if max_x < 0:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


static func abyss_outline_rect() -> Rect2i:
	return _abyss_outline_rect


static func is_abyss_island(x: int, y: int) -> bool:
	return is_explored(_abyss_land, x, y)


static func is_secret_abyss(x: int, y: int) -> bool:
	return is_explored(_abyss_region, x, y)


static func is_secret_skull(x: int, y: int) -> bool:
	return is_explored(_skull_region, x, y)


static func is_secret_bell(x: int, y: int) -> bool:
	return is_explored(_bell_region, x, y)


static func is_secret_hidden(x: int, y: int, found_abyss: bool, found_skull: bool, found_bell: bool) -> bool:
	if is_secret_abyss(x, y) and not found_abyss:
		return true
	if is_secret_skull(x, y) and not found_skull:
		return true
	if is_secret_bell(x, y) and not found_bell:
		return true
	return false


static func is_always_settlement(tid: int) -> bool:
	return ALWAYS_SETTLEMENT.get(tid, false)


static func is_dungeon_entrance(tid: int, pos: Vector2i) -> bool:
	if tid == TILE_DUNGEON:
		return true
	return not _DungeonPortals.WORLD.get("%d,%d" % [pos.x, pos.y], {}).is_empty()


static func is_shrine_entrance(tid: int, pos: Vector2i) -> bool:
	if tid == TILE_SHRINE:
		return true
	return not _ShrinePortals.portal_at(pos).is_empty()


## Reveal the current wide explore view. Mountains (and other opaque tiles)
## block recording past themselves — same LOS the player sees.
static func reveal_view(gs, world, center: Vector2i, view_w: int, view_h: int) -> bool:
	if gs == null or world == null or not bool(world.loaded):
		return false
	if gs.locate_explored.size() != MASK_BYTES:
		gs.locate_explored = empty_mask()
	ensure_abyss_mask(world)
	var w := maxi(1, view_w)
	var h := maxi(1, view_h)
	if (w & 1) == 0:
		w += 1
	if (h & 1) == 0:
		h += 1
	var blocking := PackedByteArray()
	blocking.resize(w * h)
	blocking.fill(0)
	var half_x := w / 2
	var half_y := h / 2
	for ly in h:
		for lx in w:
			var wx := posmod(center.x + lx - half_x, WORLD)
			var wy := posmod(center.y + ly - half_y, WORLD)
			var tid := int(world.tile_at(wx, wy))
			## Record only what mountains hide: opaque tiles block past themselves.
			if tid == TILE_MOUNTAIN or _TileRules.is_opaque(tid):
				blocking[ly * w + lx] = 1
	var vis := _LineOfSight.compute_dos(blocking, w, h)
	var changed := false
	for ly in h:
		for lx in w:
			if vis[ly * w + lx] == 0:
				continue
			var wx := posmod(center.x + lx - half_x, WORLD)
			var wy := posmod(center.y + ly - half_y, WORLD)
			if mark_explored(gs.locate_explored, wx, wy):
				changed = true
			if is_abyss_island(wx, wy) and not gs.locate_found_abyss:
				gs.locate_found_abyss = true
				changed = true
			if is_secret_skull(wx, wy) and not gs.locate_found_skull:
				gs.locate_found_skull = true
				changed = true
			if is_secret_bell(wx, wy) and not gs.locate_found_bell:
				gs.locate_found_bell = true
				changed = true
	if changed:
		gs.locate_chart_dirty = true
	return changed


static func reveal_rect(gs, world, center: Vector2i, view_w: int, view_h: int) -> bool:
	## Peer gem: the whole rectangle is visible (no mountain LOS).
	if gs == null or world == null or not bool(world.loaded):
		return false
	if gs.locate_explored.size() != MASK_BYTES:
		gs.locate_explored = empty_mask()
	ensure_abyss_mask(world)
	var w := maxi(1, view_w)
	var h := maxi(1, view_h)
	if (w & 1) == 0:
		w += 1
	if (h & 1) == 0:
		h += 1
	var half_x := w / 2
	var half_y := h / 2
	var changed := false
	for ly in h:
		for lx in w:
			var wx := posmod(center.x + lx - half_x, WORLD)
			var wy := posmod(center.y + ly - half_y, WORLD)
			if mark_explored(gs.locate_explored, wx, wy):
				changed = true
			if is_abyss_island(wx, wy) and not gs.locate_found_abyss:
				gs.locate_found_abyss = true
				changed = true
			if is_secret_skull(wx, wy) and not gs.locate_found_skull:
				gs.locate_found_skull = true
				changed = true
			if is_secret_bell(wx, wy) and not gs.locate_found_bell:
				gs.locate_found_bell = true
				changed = true
	if changed:
		gs.locate_chart_dirty = true
	return changed
