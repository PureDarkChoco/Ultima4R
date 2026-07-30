class_name LineOfSight
extends RefCounted

## xu4 `screenFindLineOfSightDOS` — viewport-centered visibility from opaque blockers.
## Invisible cells are drawn black (no dimming / remembered fog).
## Works for any odd W×H with the viewer at (W/2, H/2).


static func compute_dos(blocking: PackedByteArray, w: int, h: int) -> PackedByteArray:
	## `blocking[y * w + x]` non-zero = opaque tile (blocks sight past itself).
	## Returns packed 0/1 visibility; walls themselves may still be visible.
	var los := PackedByteArray()
	var n := w * h
	los.resize(n)
	los.fill(0)
	if w < 1 or h < 1 or blocking.size() < n:
		return los

	var half_w := w / 2
	var half_h := h / 2
	_los_set(los, w, half_w, half_h, 1)

	for x in range(half_w - 1, -1, -1):
		if _los_get(los, w, x + 1, half_h) and not _blocked(blocking, w, x + 1, half_h):
			_los_set(los, w, x, half_h, 1)

	for x in range(half_w + 1, w):
		if _los_get(los, w, x - 1, half_h) and not _blocked(blocking, w, x - 1, half_h):
			_los_set(los, w, x, half_h, 1)

	for y in range(half_h - 1, -1, -1):
		if _los_get(los, w, half_w, y + 1) and not _blocked(blocking, w, half_w, y + 1):
			_los_set(los, w, half_w, y, 1)

	for y in range(half_h + 1, h):
		if _los_get(los, w, half_w, y - 1) and not _blocked(blocking, w, half_w, y - 1):
			_los_set(los, w, half_w, y, 1)

	for y in range(half_h - 1, -1, -1):
		for x in range(half_w - 1, -1, -1):
			if _los_get(los, w, x, y + 1) and not _blocked(blocking, w, x, y + 1):
				_los_set(los, w, x, y, 1)
			elif _los_get(los, w, x + 1, y) and not _blocked(blocking, w, x + 1, y):
				_los_set(los, w, x, y, 1)
			elif _los_get(los, w, x + 1, y + 1) and not _blocked(blocking, w, x + 1, y + 1):
				_los_set(los, w, x, y, 1)

		for x in range(half_w + 1, w):
			if _los_get(los, w, x, y + 1) and not _blocked(blocking, w, x, y + 1):
				_los_set(los, w, x, y, 1)
			elif _los_get(los, w, x - 1, y) and not _blocked(blocking, w, x - 1, y):
				_los_set(los, w, x, y, 1)
			elif _los_get(los, w, x - 1, y + 1) and not _blocked(blocking, w, x - 1, y + 1):
				_los_set(los, w, x, y, 1)

	for y in range(half_h + 1, h):
		for x in range(half_w - 1, -1, -1):
			if _los_get(los, w, x, y - 1) and not _blocked(blocking, w, x, y - 1):
				_los_set(los, w, x, y, 1)
			elif _los_get(los, w, x + 1, y) and not _blocked(blocking, w, x + 1, y):
				_los_set(los, w, x, y, 1)
			elif _los_get(los, w, x + 1, y - 1) and not _blocked(blocking, w, x + 1, y - 1):
				_los_set(los, w, x, y, 1)

		for x in range(half_w + 1, w):
			if _los_get(los, w, x, y - 1) and not _blocked(blocking, w, x, y - 1):
				_los_set(los, w, x, y, 1)
			elif _los_get(los, w, x - 1, y) and not _blocked(blocking, w, x - 1, y):
				_los_set(los, w, x, y, 1)
			elif _los_get(los, w, x - 1, y - 1) and not _blocked(blocking, w, x - 1, y - 1):
				_los_set(los, w, x, y, 1)

	return los


static func all_visible(w: int, h: int) -> PackedByteArray:
	var los := PackedByteArray()
	los.resize(maxi(0, w * h))
	los.fill(1)
	return los


static func _blocked(blocking: PackedByteArray, w: int, x: int, y: int) -> bool:
	return blocking[y * w + x] != 0


static func _los_get(los: PackedByteArray, w: int, x: int, y: int) -> bool:
	return los[y * w + x] != 0


static func _los_set(los: PackedByteArray, w: int, x: int, y: int, v: int) -> void:
	los[y * w + x] = v
