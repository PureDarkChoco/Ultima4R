class_name DosSaveImport
extends RefCounted

## Ultima IV DOS PARTY.SAV (+ optional MONSTERS/OUTMONST/DNGMAP) importer.
## The binary layout follows xu4 doc/FileFormats.md and savegame.cpp.

const PARTY_BYTES := 502
const MONSTERS_BYTES := 256
const DNGMAP_BYTES := 8 * 8 * 8
const PLAYER_BYTES := 39
const PLAYER_COUNT := 8

const _DungeonMap := preload("res://src/map/dungeon_map_data.gd")
const _DungeonPortals := preload("res://src/map/dungeon_portals.gd")

const _DUNGEON_IDS: Array[String] = [
	"deceit", "despise", "destard", "wrong",
	"covetous", "shame", "hythloth", "abyss",
]
## DOS dungeon orientation: W, N, E, S. Remake: N, E, S, W.
const _DUNGEON_DIR := [3, 0, 1, 2]


static func import_from_data_dir(dir_path: String) -> Dictionary:
	var party_path := _file_in_dir(dir_path, "PARTY.SAV")
	if party_path.is_empty():
		return {"ok": false, "error": "missing"}
	var bytes := FileAccess.get_file_as_bytes(party_path)
	var party := parse_party(bytes)
	if not bool(party.get("ok", false)):
		return {"ok": false, "error": str(party.get("error", "invalid"))}
	var game := _build_game(party)
	var world := _build_world(party, dir_path)
	return {
		"ok": true,
		"path": party_path,
		"party": party,
		"game": game,
		"world": world,
		"summary": summary(party),
	}


static func parse_party(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() != PARTY_BYTES:
		return {"ok": false, "error": "size"}
	var offset := 0
	var unknown1 := _u32(bytes, offset)
	offset += 4
	var moves := _u32(bytes, offset)
	offset += 4
	var players: Array[Dictionary] = []
	for _i in PLAYER_COUNT:
		var player := _parse_player(bytes, offset)
		if player.is_empty():
			return {"ok": false, "error": "player"}
		players.append(player)
		offset += PLAYER_BYTES
	var food := _s32(bytes, offset)
	offset += 4
	var gold := _s16(bytes, offset)
	offset += 2
	var karma := _read_s16_array(bytes, offset, 8)
	offset += 16
	var torches := _s16(bytes, offset)
	offset += 2
	var gems := _s16(bytes, offset)
	offset += 2
	var keys := _s16(bytes, offset)
	offset += 2
	var sextants := _s16(bytes, offset)
	offset += 2
	var armor := _read_s16_array(bytes, offset, 8)
	offset += 16
	var weapons := _read_s16_array(bytes, offset, 16)
	offset += 32
	var reagents := _read_s16_array(bytes, offset, 8)
	offset += 16
	var mixtures := _read_s16_array(bytes, offset, 26)
	offset += 52
	var items := _u16(bytes, offset)
	offset += 2
	var x := int(bytes[offset])
	var y := int(bytes[offset + 1])
	var stones := int(bytes[offset + 2])
	var runes := int(bytes[offset + 3])
	offset += 4
	var members := _u16(bytes, offset)
	offset += 2
	var transport := _u16(bytes, offset)
	offset += 2
	var balloon_or_torch := _u16(bytes, offset)
	offset += 2
	var trammel := _u16(bytes, offset)
	offset += 2
	var felucca := _u16(bytes, offset)
	offset += 2
	var ship_hull := _u16(bytes, offset)
	offset += 2
	var lb_intro := _u16(bytes, offset)
	offset += 2
	var lastcamp := _u16(bytes, offset)
	offset += 2
	var lastreagent := _u16(bytes, offset)
	offset += 2
	var lastmeditation := _u16(bytes, offset)
	offset += 2
	var lastvirtue := _u16(bytes, offset)
	offset += 2
	var dngx := int(bytes[offset])
	var dngy := int(bytes[offset + 1])
	offset += 2
	var orientation := _u16(bytes, offset)
	offset += 2
	var dnglevel := _u16(bytes, offset)
	offset += 2
	var location := _u16(bytes, offset)

	if members < 1 or members > PLAYER_COUNT:
		return {"ok": false, "error": "members"}
	if location != 0 and (location < 0x11 or location > 0x18):
		return {"ok": false, "error": "location"}
	if location != 0 and (dnglevel > 7 or orientation > 3 or dngx > 7 or dngy > 7):
		return {"ok": false, "error": "dungeon"}
	var active_classes: Dictionary = {}
	for i in members:
		var p: Dictionary = players[i]
		var klass := int(p["class"])
		if klass < 0 or klass >= 8 or active_classes.has(klass):
			return {"ok": false, "error": "class"}
		if int(p["sex"]) not in [0x0B, 0x0C]:
			return {"ok": false, "error": "sex"}
		if int(p["status"]) not in [0x47, 0x50, 0x53, 0x44]:
			return {"ok": false, "error": "status"}
		active_classes[klass] = true

	return {
		"ok": true,
		"unknown1": unknown1,
		"moves": moves,
		"players": players,
		"food": food,
		"gold": gold,
		"karma": karma,
		"torches": torches,
		"gems": gems,
		"keys": keys,
		"sextants": sextants,
		"armor": armor,
		"weapons": weapons,
		"reagents": reagents,
		"mixtures": mixtures,
		"items": items,
		"x": x,
		"y": y,
		"stones": stones,
		"runes": runes,
		"members": members,
		"transport": transport,
		"balloon_or_torch": balloon_or_torch,
		"trammel": trammel,
		"felucca": felucca,
		"ship_hull": ship_hull,
		"lb_intro": lb_intro,
		"lastcamp": lastcamp,
		"lastreagent": lastreagent,
		"lastmeditation": lastmeditation,
		"lastvirtue": lastvirtue,
		"dngx": dngx,
		"dngy": dngy,
		"orientation": orientation,
		"dnglevel": dnglevel,
		"location": location,
	}


static func summary(party: Dictionary) -> Dictionary:
	var leader: Dictionary = (party.get("players", []) as Array)[0]
	return {
		"name": str(leader.get("name", "Avatar")),
		"class": int(leader.get("class", 0)),
		"level": maxi(1, int(leader.get("hp_max", 100)) / 100),
		"gold": maxi(0, int(party.get("gold", 0))),
		"moves": maxi(0, int(party.get("moves", 0))),
	}


static func _parse_player(bytes: PackedByteArray, offset: int) -> Dictionary:
	if offset < 0 or offset + PLAYER_BYTES > bytes.size():
		return {}
	var fields: Array[int] = []
	for i in 10:
		fields.append(_u16(bytes, offset + i * 2))
	var name_bytes := bytes.slice(offset + 20, offset + 36)
	var nul := name_bytes.find(0)
	if nul >= 0:
		name_bytes = name_bytes.slice(0, nul)
	var name := name_bytes.get_string_from_ascii().strip_edges()
	if name.is_empty():
		name = "Avatar"
	return {
		"hp": fields[0],
		"hp_max": fields[1],
		"xp": fields[2],
		"str": fields[3],
		"dex": fields[4],
		"int": fields[5],
		"mp": fields[6],
		"unknown": fields[7],
		"weapon": fields[8],
		"armor": fields[9],
		"name": name,
		"sex": int(bytes[offset + 36]),
		"class": int(bytes[offset + 37]),
		"status": int(bytes[offset + 38]),
	}


static func _build_game(party: Dictionary) -> Dictionary:
	var players: Array = party["players"]
	var members := int(party["members"])
	var leader: Dictionary = players[0]
	var order: Array[int] = []
	var member_weapons := _filled_ints(8, 0)
	var member_armor := _filled_ints(8, 0)
	var member_hp := _filled_ints(8, 100)
	var member_max_hp := _filled_ints(8, 100)
	var member_mp := _filled_ints(8, 0)
	var member_status := _filled_ints(8, 0)
	var member_poisoned: Array[bool] = []
	member_poisoned.resize(8)
	member_poisoned.fill(false)
	var member_str := _filled_ints(8, 15)
	var member_dex := _filled_ints(8, 15)
	var member_int := _filled_ints(8, 15)
	var member_xp := _filled_ints(8, 0)
	var member_auto := _filled_ints(8, 0)
	for i in members:
		var p: Dictionary = players[i]
		var klass := int(p["class"])
		order.append(klass)
		member_weapons[klass] = clampi(int(p["weapon"]), 0, 15)
		member_armor[klass] = clampi(int(p["armor"]), 0, 7)
		member_hp[klass] = maxi(0, int(p["hp"]))
		member_max_hp[klass] = maxi(1, int(p["hp_max"]))
		member_mp[klass] = maxi(0, int(p["mp"]))
		var status := _status_to_remake(int(p["status"]))
		member_status[klass] = status
		member_poisoned[klass] = int(p["status"]) == 0x50
		member_str[klass] = maxi(0, int(p["str"]))
		member_dex[klass] = maxi(0, int(p["dex"]))
		member_int[klass] = maxi(0, int(p["int"]))
		member_xp[klass] = maxi(0, int(p["xp"]))
	var mixtures: Array = party["mixtures"]
	var spell_known: Array[bool] = []
	for count in mixtures:
		spell_known.append(int(count) > 0)
	var in_dungeon := int(party["location"]) >= 0x11
	return {
		"player_name": str(leader["name"]),
		"player_name_ko": str(leader["name"]),
		"player_sex": "female" if int(leader["sex"]) == 0x0C else "male",
		"player_class": int(leader["class"]),
		"party_order": order,
		"start_pos": {"x": int(party["x"]), "y": int(party["y"])},
		"karma": _nonnegative_array(party["karma"]),
		"food": maxi(0, int(party["food"])),
		"moves": maxi(0, int(party["moves"])),
		"lastcamp": int(party["lastcamp"]),
		"lastvirtue": int(party["lastvirtue"]),
		"lastmeditation": int(party["lastmeditation"]),
		"ship_hull": clampi(int(party["ship_hull"]), 0, 50),
		"gems": maxi(0, int(party["gems"])),
		"gold": maxi(0, int(party["gold"])),
		"keys": maxi(0, int(party["keys"])),
		"torches": maxi(0, int(party["torches"])),
		"dungeon_torch_left": int(party["balloon_or_torch"]) if in_dungeon else 0,
		"dungeon_light_is_magic": false,
		"items": int(party["items"]),
		"stones": int(party["stones"]),
		"runes": int(party["runes"]),
		"lb_intro": int(party["lb_intro"]) != 0,
		"lastreagent": int(party["lastreagent"]),
		"has_sextant": int(party["sextants"]) > 0,
		"guild_sextant_listed": int(party["sextants"]) > 0,
		"weapons": _nonnegative_array(party["weapons"]),
		"armor": _nonnegative_array(party["armor"]),
		"reagents": _nonnegative_array(party["reagents"]),
		"mixtures": _nonnegative_array(mixtures),
		"spell_known": spell_known,
		"member_weapons": member_weapons,
		"member_armor": member_armor,
		"member_hp": member_hp,
		"member_max_hp": member_max_hp,
		"member_mp": member_mp,
		"member_status": member_status,
		"member_poisoned": member_poisoned,
		"member_str": member_str,
		"member_dex": member_dex,
		"member_int": member_int,
		"member_xp": member_xp,
		"member_auto_combat": member_auto,
		"trammel_phase": clampi(int(party["trammel"]), 0, 7),
		"felucca_phase": clampi(int(party["felucca"]), 0, 7),
	}


static func _build_world(party: Dictionary, dir_path: String) -> Dictionary:
	var transport_info := _transport_info(int(party["transport"]))
	var x := int(party["x"])
	var y := int(party["y"])
	var location := int(party["location"])
	var in_dungeon := location >= 0x11 and location <= 0x18
	var monster_name := "OUTMONST.SAV" if in_dungeon else "MONSTERS.SAV"
	var map_objects := _read_monster_table(_file_in_dir(dir_path, monster_name))
	var world := {
		"x": x,
		"y": y,
		"transport": int(transport_info["transport"]),
		"transport_tile": int(transport_info["tile"]),
		"horse_gallop": false,
		"balloon_flying": (
			int(transport_info["transport"]) == 3
			and int(party["balloon_or_torch"]) != 0
		),
		"ship_hulls": {},
		"overlays": map_objects["overlays"],
		"creatures": map_objects["creatures"],
		"city_chests": {},
		"in_city": false,
		"in_dungeon": in_dungeon,
	}
	if int(transport_info["transport"]) == 2:
		world["ship_hulls"] = {"%d,%d" % [x, y]: clampi(int(party["ship_hull"]), 0, 50)}
	if in_dungeon:
		var dungeon_index := location - 0x11
		var dungeon_id := _DUNGEON_IDS[dungeon_index]
		var return_pos := Vector2i(x, y)
		if return_pos == Vector2i.ZERO:
			return_pos = _DungeonPortals.world_return_for(dungeon_id)
		world["x"] = return_pos.x
		world["y"] = return_pos.y
		world["dungeon_id"] = dungeon_id
		world["dungeon_x"] = int(party["dngx"])
		world["dungeon_y"] = int(party["dngy"])
		world["dungeon_z"] = clampi(int(party["dnglevel"]), 0, 7)
		world["dungeon_dir"] = int(_DUNGEON_DIR[clampi(int(party["orientation"]), 0, 3)])
		world["dungeon_return_x"] = return_pos.x
		world["dungeon_return_y"] = return_pos.y
		world["dungeon_return_city"] = ""
		world["dungeon_persist"] = _read_dungeon_persist(
			_file_in_dir(dir_path, "DNGMAP.SAV"), dungeon_id
		)
	return world


static func _read_monster_table(path: String) -> Dictionary:
	var out := {"overlays": [], "creatures": []}
	if path.is_empty():
		return out
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() != MONSTERS_BYTES:
		return out
	var overlays: Array = out["overlays"]
	var creatures: Array = out["creatures"]
	for i in 32:
		var current := int(bytes[i])
		var x := int(bytes[0x20 + i])
		var y := int(bytes[0x40 + i])
		var previous := int(bytes[0x60 + i])
		if previous == 0:
			continue
		if i < 8 and current >= 128:
			creatures.append({
				"x": x, "y": y, "t": current,
			})
			continue
		if current in [16, 17, 18, 19, 20, 21, 24, 60]:
			overlays.append({"x": x, "y": y, "t": current})
	return out


static func _read_dungeon_persist(path: String, dungeon_id: String) -> Dictionary:
	var empty := {
		"consumed": [], "secrets": [], "shamino_known": [],
		"annotations": [], "monsters": [],
	}
	if path.is_empty():
		return empty
	var saved := FileAccess.get_file_as_bytes(path)
	if saved.size() != DNGMAP_BYTES:
		return empty
	var fname := _DungeonPortals.fname_for(dungeon_id)
	var base_path := _DungeonMap.resolve_u4_file(fname)
	var base = _DungeonMap.new()
	if base_path.is_empty() or not base.load_from_path(base_path, dungeon_id):
		return empty
	var consumed: Array = empty["consumed"]
	var secrets: Array = empty["secrets"]
	var monsters: Array = empty["monsters"]
	var monster_id := 1
	var level_counts := _filled_ints(8, 0)
	for z in 8:
		for y in 8:
			for x in 8:
				var index := z * 64 + y * 8 + x
				var raw := int(saved[index])
				var tok := raw & 0xF0
				var base_tok := int(base.raw_at(x, y, z)) & 0xF0
				var key := "%d,%d,%d" % [x, y, z]
				if base_tok in [_DungeonMap.TOK_CHEST, _DungeonMap.TOK_ORB] and tok != base_tok:
					consumed.append(key)
				if base_tok == _DungeonMap.TOK_SECRET and tok != _DungeonMap.TOK_SECRET:
					secrets.append(key)
				var nibble := raw & 0x0F
				if (
					nibble > 0
					and tok not in [
						_DungeonMap.TOK_TRAP, _DungeonMap.TOK_FOUNTAIN,
						_DungeonMap.TOK_FIELD, _DungeonMap.TOK_ROOM,
					]
					and int(level_counts[z]) < 4
				):
					monsters.append({
						"id": monster_id,
						"tile": 144 + (nibble - 1) * 4,
						"x": x, "y": y, "prev_x": x, "prev_y": y, "z": z,
					})
					monster_id += 1
					level_counts[z] = int(level_counts[z]) + 1
	return empty


static func _transport_info(raw: int) -> Dictionary:
	if raw >= 0x10 and raw <= 0x13:
		return {"transport": 2, "tile": raw}
	if raw == 0x14 or raw == 0x15:
		return {"transport": 1, "tile": raw}
	if raw == 0x18:
		return {"transport": 3, "tile": 24}
	return {"transport": 0, "tile": -1}


static func _status_to_remake(raw: int) -> int:
	match raw:
		0x50:
			return 1
		0x53:
			return 2
		0x44:
			return 3
		_:
			return 0


static func _file_in_dir(dir_path: String, wanted: String) -> String:
	var root := dir_path.strip_edges()
	if root.is_empty() or not DirAccess.dir_exists_absolute(root):
		return ""
	var dir := DirAccess.open(root)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if not dir.current_is_dir() and name.to_lower() == wanted.to_lower():
			dir.list_dir_end()
			return root.path_join(name)
		name = dir.get_next()
	dir.list_dir_end()
	return ""


static func _filled_ints(size: int, value: int) -> Array[int]:
	var out: Array[int] = []
	out.resize(size)
	out.fill(value)
	return out


static func _nonnegative_array(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for value in raw as Array:
		out.append(maxi(0, int(value)))
	return out


static func _read_s16_array(bytes: PackedByteArray, offset: int, count: int) -> Array[int]:
	var out: Array[int] = []
	for i in count:
		out.append(_s16(bytes, offset + i * 2))
	return out


static func _u16(bytes: PackedByteArray, offset: int) -> int:
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8)


static func _s16(bytes: PackedByteArray, offset: int) -> int:
	var value := _u16(bytes, offset)
	return value - 0x10000 if value >= 0x8000 else value


static func _u32(bytes: PackedByteArray, offset: int) -> int:
	return (
		int(bytes[offset])
		| (int(bytes[offset + 1]) << 8)
		| (int(bytes[offset + 2]) << 16)
		| (int(bytes[offset + 3]) << 24)
	)


static func _s32(bytes: PackedByteArray, offset: int) -> int:
	var value := _u32(bytes, offset)
	return value - 0x100000000 if value >= 0x80000000 else value
