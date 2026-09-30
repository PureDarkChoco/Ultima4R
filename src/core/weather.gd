extends Object

## Discrete outdoor cloud shadows in world-tile space.
## Size is covered tile *area* (union of puffs), not width or height.

enum Size { SMALL, MID }

const DRIFT_TILES_PER_SEC := 0.28
const WIND_EASE_SEC := 4.5
## Repeat cell close to the 25×11 view so neighboring tiles stay populated.
const PERIOD := Vector2(30.0, 16.0)
const MAX_CLOUDS := 8
const SIZE_COUNT := 2
const SHAPE_COUNT := 5
## Small 3–4, mid 3–4. Never a empty band of sky.
const WANT_LO := [3, 3]
const WANT_HI := [4, 4]

## Covered tiles (all puffs added together). Small 14–20, mid 22–28.
const AREA_MIN := [14.0, 22.0]
const AREA_MAX := [20.0, 28.0]
## world_area ≈ SHAPE_AREA_K * radius² for the cartoon lobe union.
const SHAPE_AREA_K := 1.85
const TILE_PX := 32.0
const EXTRA_PX_MIN := 2.0
const EXTRA_PX_MAX := 4.0
const LIVE_MIN := [22.0, 34.0]
const LIVE_MAX := [42.0, 64.0]
const FADE_MIN := [5.5, 7.0]
const FADE_MAX := [8.5, 11.0]
const WANT_HOLD_MIN := 18.0
const WANT_HOLD_MAX := 40.0
const ALPHA := [0.52, 0.56]
## Dry spells, including the first after start/load: 15–25 minutes.
const FIRST_DRY_MIN := 900.0
const FIRST_DRY_MAX := 1500.0
const DRY_MIN := 900.0
const DRY_MAX := 1500.0
## Storm length 3–6 minutes.
const RAIN_MIN := 180.0
const RAIN_MAX := 360.0
## Fade in/out stays in seconds so a long hold does not delay the first drops.
const RAIN_OVER_IN := 21.0
const RAIN_OVER_OUT := 21.0
const RAIN_DIM_IN0 := 7.5
const RAIN_DIM_IN1 := 30.0
const RAIN_DIM_OUT0 := 30.0
const RAIN_DIM_OUT1 := 6.0
const RAIN_BODY_IN0 := 15.0
const RAIN_BODY_IN1 := 36.0
const RAIN_BODY_OUT0 := 45.0
const RAIN_BODY_OUT1 := 18.0
const RAIN_HEAVY_IN0 := 42.0
const RAIN_HEAVY_IN1 := 63.0
const RAIN_HEAVY_OUT0 := 75.0
const RAIN_HEAVY_OUT1 := 48.0


static func reset_weather(gs: Node) -> void:
	gs.cloud_vel = Vector2.ZERO
	gs.cloud_want = [3, 3]
	gs.cloud_want_hold = [0.0, 0.0]
	gs.clouds = []
	for size in SIZE_COUNT:
		_roll_want(gs, size)
		var n: int = int(gs.cloud_want[size])
		for _i in n:
			_spawn_cloud(gs, size, true)
	_reset_rain(gs, true)


static func tick_weather(gs: Node, delta: float, wind_to: Vector2) -> void:
	if delta <= 0.0:
		return
	var heading := wind_to
	if heading.length_squared() < 0.01:
		heading = Vector2(0, 1)
	var target := heading.normalized() * DRIFT_TILES_PER_SEC
	var ease := 1.0 - exp(-delta / WIND_EASE_SEC)
	gs.cloud_vel = gs.cloud_vel.lerp(target, ease)
	var vel: Vector2 = gs.cloud_vel

	var next: Array = []
	for raw in gs.clouds:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var cloud: Dictionary = raw
		if int(cloud.get("size", 0)) >= SIZE_COUNT:
			continue
		var pos: Vector2 = cloud["pos"] + vel * delta
		cloud["pos"] = Vector2(fposmod(pos.x, PERIOD.x), fposmod(pos.y, PERIOD.y))
		var fade: float = float(cloud["fade"])
		var fade_vel: float = float(cloud["fade_vel"])
		var fade_sec: float = maxf(float(cloud["fade_sec"]), 0.15)
		fade = clampf(fade + fade_vel * delta / fade_sec, 0.0, 1.0)
		cloud["fade"] = fade
		if fade_vel > 0.0 and fade >= 1.0:
			cloud["fade_vel"] = 0.0
			cloud["life"] = _live_for(int(cloud["size"]))
		elif fade_vel < 0.0 and fade <= 0.0:
			continue
		else:
			if fade_vel == 0.0:
				cloud["life"] = float(cloud["life"]) - delta
				if float(cloud["life"]) <= 0.0:
					cloud["fade_vel"] = -1.0
					cloud["fade_sec"] = _fade_for(int(cloud["size"]))
		next.append(cloud)
	gs.clouds = next

	if gs.cloud_want.size() < SIZE_COUNT:
		gs.cloud_want = [3, 3]
	if gs.cloud_want_hold.size() < SIZE_COUNT:
		gs.cloud_want_hold = [0.0, 0.0]
	for size in SIZE_COUNT:
		var holds: Array = gs.cloud_want_hold
		holds[size] = maxf(0.0, float(holds[size]) - delta)
		if int(gs.cloud_want[size]) < int(WANT_LO[size]) or float(holds[size]) <= 0.0:
			_roll_want(gs, size)
		_reconcile_size(gs, size)
	_tick_rain(gs, delta)


static func shader_blobs(gs: Node) -> Array:
	## vec4(x, y, radius, alpha) for the overlay shader, padded to MAX_CLOUDS.
	var out: Array = []
	for raw in gs.clouds:
		if out.size() >= MAX_CLOUDS:
			break
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var cloud: Dictionary = raw
		var fade := clampf(float(cloud.get("fade", 0.0)), 0.0, 1.0)
		if fade <= 0.001:
			continue
		var size := clampi(int(cloud.get("size", 0)), 0, SIZE_COUNT - 1)
		var pos: Vector2 = cloud.get("pos", Vector2.ZERO)
		var radius := _radius_of(cloud)
		var alpha := float(ALPHA[size]) * fade
		out.append(Vector4(pos.x, pos.y, radius, alpha))
	while out.size() < MAX_CLOUDS:
		out.append(Vector4.ZERO)
	return out


static func shader_shapes(gs: Node) -> Array:
	## vec4(stretch, seed, wobble, 0) matching shader_blobs order.
	var out: Array = []
	for raw in gs.clouds:
		if out.size() >= MAX_CLOUDS:
			break
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var cloud: Dictionary = raw
		if clampf(float(cloud.get("fade", 0.0)), 0.0, 1.0) <= 0.001:
			continue
		out.append(
			Vector4(
				float(cloud.get("stretch", 1.12)),
				float(cloud.get("seed", 0.0)),
				float(cloud.get("wobble", 0.12)),
				float(cloud.get("style", 0.0))
			)
		)
	while out.size() < MAX_CLOUDS:
		out.append(Vector4.ZERO)
	return out


static func to_save(gs: Node) -> Dictionary:
	var vel: Vector2 = gs.cloud_vel
	var rows: Array = []
	for raw in gs.clouds:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var cloud: Dictionary = raw
		var pos: Vector2 = cloud.get("pos", Vector2.ZERO)
		rows.append({
			"size": int(cloud.get("size", 0)),
			"x": pos.x,
			"y": pos.y,
			"fade": float(cloud.get("fade", 0.0)),
			"fade_vel": float(cloud.get("fade_vel", 0.0)),
			"fade_sec": float(cloud.get("fade_sec", 8.0)),
			"life": float(cloud.get("life", 0.0)),
			"area": float(cloud.get("area", _area_for(int(cloud.get("size", 0))))),
			"stretch": float(cloud.get("stretch", 1.12)),
			"seed": float(cloud.get("seed", 0.0)),
			"wobble": float(cloud.get("wobble", 0.12)),
			"style": int(cloud.get("style", 0)),
		})
	return {
		"clouds": rows,
		"cloud_vel": {"x": vel.x, "y": vel.y},
		"cloud_want": (gs.cloud_want as Array).duplicate(),
		"cloud_want_hold": (gs.cloud_want_hold as Array).duplicate(),
		"rain_dry_left": float(gs.rain_dry_left),
		"rain_active": bool(gs.rain_active),
		"rain_age": float(gs.rain_age),
		"rain_dur": float(gs.rain_dur),
	}


static func apply_save(gs: Node, d: Dictionary) -> void:
	if d.is_empty() or not d.has("clouds"):
		reset_weather(gs)
		return
	var vel_v: Variant = d.get("cloud_vel", {})
	if typeof(vel_v) == TYPE_DICTIONARY:
		var vd: Dictionary = vel_v
		gs.cloud_vel = Vector2(float(vd.get("x", 0.0)), float(vd.get("y", 0.0)))
	else:
		gs.cloud_vel = Vector2.ZERO
	gs.cloud_want = [3, 3]
	gs.cloud_want_hold = [20.0, 20.0]
	var want_v: Variant = d.get("cloud_want", [])
	if typeof(want_v) == TYPE_ARRAY:
		var wa: Array = want_v
		for i in mini(SIZE_COUNT, wa.size()):
			gs.cloud_want[i] = clampi(int(wa[i]), int(WANT_LO[i]), int(WANT_HI[i]))
	var hold_v: Variant = d.get("cloud_want_hold", [])
	if typeof(hold_v) == TYPE_ARRAY:
		var ha: Array = hold_v
		for i in mini(SIZE_COUNT, ha.size()):
			gs.cloud_want_hold[i] = maxf(0.0, float(ha[i]))
	gs.clouds = []
	var rows_v: Variant = d.get("clouds", [])
	if typeof(rows_v) == TYPE_ARRAY:
		for raw in rows_v:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = raw
			var size := clampi(int(row.get("size", 0)), 0, SIZE_COUNT - 1)
			gs.clouds.append({
				"size": size,
				"pos": Vector2(
					fposmod(float(row.get("x", 0.0)), PERIOD.x),
					fposmod(float(row.get("y", 0.0)), PERIOD.y)
				),
				"fade": clampf(float(row.get("fade", 1.0)), 0.0, 1.0),
				"fade_vel": float(row.get("fade_vel", 0.0)),
				"fade_sec": maxf(float(row.get("fade_sec", 8.0)), 0.15),
				"life": maxf(float(row.get("life", 20.0)), 0.0),
				"area": _clamp_area(size, float(row.get("area", _area_for(size)))),
				"stretch": clampf(float(row.get("stretch", 1.12)), 1.04, 1.22),
				"seed": float(row.get("seed", 0.0)),
				"wobble": clampf(float(row.get("wobble", 0.12)), 0.06, 0.18),
				"style": clampi(int(row.get("style", 0)), 0, SHAPE_COUNT - 1),
			})
	if gs.clouds.is_empty():
		reset_weather(gs)
		return
	for size in SIZE_COUNT:
		_reconcile_size(gs, size)
	if d.has("rain_dur"):
		gs.rain_dry_left = maxf(0.0, float(d.get("rain_dry_left", gs.rain_dry_left)))
		gs.rain_active = bool(d.get("rain_active", false))
		gs.rain_age = maxf(0.0, float(d.get("rain_age", 0.0)))
		gs.rain_dur = clampf(float(d.get("rain_dur", RAIN_MIN)), RAIN_MIN, RAIN_MAX)
		if gs.rain_active and float(gs.rain_age) < float(gs.rain_dur):
			gs.rain_started_once = true
			_apply_rain_look(gs)
		else:
			_reset_rain(gs, true)
	else:
		_reset_rain(gs, true)


static func _roll_want(gs: Node, size: int) -> void:
	var lo: int = int(WANT_LO[size])
	var hi: int = int(WANT_HI[size])
	gs.cloud_want[size] = lo + (randi() % (hi - lo + 1))
	gs.cloud_want_hold[size] = lerpf(WANT_HOLD_MIN, WANT_HOLD_MAX, randf())


static func _alive_of(gs: Node, size: int) -> int:
	var n := 0
	for raw in gs.clouds:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var cloud: Dictionary = raw
		if int(cloud.get("size", -1)) != size:
			continue
		if float(cloud.get("fade_vel", 0.0)) < 0.0:
			continue
		n += 1
	return n


static func _reconcile_size(gs: Node, size: int) -> void:
	var want: int = clampi(int(gs.cloud_want[size]), int(WANT_LO[size]), int(WANT_HI[size]))
	var have := _alive_of(gs, size)
	while have < want and gs.clouds.size() < MAX_CLOUDS:
		_spawn_cloud(gs, size, false)
		have += 1
	while have > want:
		if not _begin_fade_out(gs, size):
			break
		have -= 1


static func _begin_fade_out(gs: Node, size: int) -> bool:
	var best := -1
	var best_life := INF
	for i in gs.clouds.size():
		var raw: Variant = gs.clouds[i]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var cloud: Dictionary = raw
		if int(cloud.get("size", -1)) != size:
			continue
		if float(cloud.get("fade_vel", 0.0)) < 0.0:
			continue
		var life := float(cloud.get("life", 0.0))
		if life < best_life:
			best_life = life
			best = i
	if best < 0:
		return false
	var pick: Dictionary = gs.clouds[best]
	pick["fade_vel"] = -1.0
	pick["fade_sec"] = _fade_for(size)
	gs.clouds[best] = pick
	return true


static func _spawn_cloud(gs: Node, size: int, instant: bool) -> void:
	var pos := _spawn_pos(gs, size)
	gs.clouds.append({
		"size": size,
		"pos": pos,
		"fade": 1.0 if instant else 0.0,
		"fade_vel": 0.0 if instant else 1.0,
		"fade_sec": _fade_for(size),
		"life": _live_for(size),
		"area": _area_for(size),
		"stretch": lerpf(1.06, 1.18, randf()),
		"seed": randf() * 64.0,
		"wobble": lerpf(0.08, 0.16, randf()),
		"style": randi() % SHAPE_COUNT,
	})


static func _spawn_pos(gs: Node, size: int) -> Vector2:
	var min_d := sqrt(float(AREA_MIN[size]) / SHAPE_AREA_K) * 1.6
	for _try in 10:
		var pos := Vector2(randf() * PERIOD.x, randf() * PERIOD.y)
		if _clear_of_others(gs, pos, min_d):
			return pos
	return Vector2(randf() * PERIOD.x, randf() * PERIOD.y)


static func _clear_of_others(gs: Node, pos: Vector2, min_d: float) -> bool:
	for raw in gs.clouds:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var other: Vector2 = raw.get("pos", Vector2.ZERO)
		var d := pos - other
		d.x -= PERIOD.x * floorf(d.x / PERIOD.x + 0.5)
		d.y -= PERIOD.y * floorf(d.y / PERIOD.y + 0.5)
		if d.length() < min_d:
			return false
	return true


static func _live_for(size: int) -> float:
	return lerpf(float(LIVE_MIN[size]), float(LIVE_MAX[size]), randf())


static func _fade_for(size: int) -> float:
	return lerpf(float(FADE_MIN[size]), float(FADE_MAX[size]), randf())


static func _area_for(size: int) -> float:
	return lerpf(float(AREA_MIN[size]), float(AREA_MAX[size]), randf())


static func _clamp_area(size: int, area: float) -> float:
	return clampf(area, float(AREA_MIN[size]), float(AREA_MAX[size]))


static func _reset_rain(gs: Node, soon: bool) -> void:
	gs.rain_active = false
	gs.rain_age = 0.0
	gs.rain_dur = lerpf(RAIN_MIN, RAIN_MAX, randf())
	if soon:
		gs.rain_dry_left = lerpf(FIRST_DRY_MIN, FIRST_DRY_MAX, randf())
		gs.rain_started_once = false
	else:
		gs.rain_dry_left = lerpf(DRY_MIN, DRY_MAX, randf())
	_apply_rain_look(gs)


static func _tick_rain(gs: Node, delta: float) -> void:
	if float(gs.rain_dur) < RAIN_MIN * 0.5:
		_reset_rain(gs, true)
	if bool(gs.rain_active):
		gs.rain_age = float(gs.rain_age) + delta
		if float(gs.rain_age) >= float(gs.rain_dur):
			gs.rain_started_once = true
			_reset_rain(gs, false)
			return
	else:
		gs.rain_dry_left = maxf(0.0, float(gs.rain_dry_left) - delta)
		if float(gs.rain_dry_left) <= 0.0:
			gs.rain_active = true
			gs.rain_started_once = true
			gs.rain_age = 0.0
			gs.rain_dur = lerpf(RAIN_MIN, RAIN_MAX, randf())
	_apply_rain_look(gs)


static func _apply_rain_look(gs: Node) -> void:
	if not bool(gs.rain_active):
		gs.rain_overcast = 0.0
		gs.rain_dim = 0.0
		gs.rain_amt = 0.0
		return
	var dur := maxf(float(gs.rain_dur), 1.0)
	var age := clampf(float(gs.rain_age), 0.0, dur)
	## Clouds fill first and linger last.
	var over := smoothstep(0.0, RAIN_OVER_IN, age) * (
		1.0 - smoothstep(dur - RAIN_OVER_OUT, dur, age)
	)
	## Dim after the cover, lift before the last clouds leave.
	var dim := smoothstep(RAIN_DIM_IN0, RAIN_DIM_IN1, age) * (
		1.0 - smoothstep(dur - RAIN_DIM_OUT0, dur - RAIN_DIM_OUT1, age)
	)
	## Light rain → heavier mid-storm → light again.
	var body := smoothstep(RAIN_BODY_IN0, RAIN_BODY_IN1, age) * (
		1.0 - smoothstep(dur - RAIN_BODY_OUT0, dur - RAIN_BODY_OUT1, age)
	)
	var heavy := smoothstep(RAIN_HEAVY_IN0, RAIN_HEAVY_IN1, age) * (
		1.0 - smoothstep(dur - RAIN_HEAVY_OUT0, dur - RAIN_HEAVY_OUT1, age)
	)
	gs.rain_overcast = over
	gs.rain_dim = dim
	gs.rain_amt = body * (0.32 + 0.68 * heavy)


static func _radius_of(cloud: Dictionary) -> float:
	var size := clampi(int(cloud.get("size", 0)), 0, SIZE_COUNT - 1)
	var area := _clamp_area(size, float(cloud.get("area", _area_for(size))))
	## Invert the lobe-union so painted tiles ≈ area, not a bounding box.
	var t := fposmod(absf(float(cloud.get("seed", 0.0))) * 0.137, 1.0)
	var extra := lerpf(EXTRA_PX_MIN, EXTRA_PX_MAX, t) / TILE_PX
	return sqrt(area / SHAPE_AREA_K) + extra
