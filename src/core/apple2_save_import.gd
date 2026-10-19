class_name Apple2SaveImport
extends RefCounted

## Ultima IV Apple II party save on the Britannia disk (PRTY + ROST).
## Layout: xu4 doc/AppleFileFormats.txt. Displayed stats are BCD;
## positions, transport, and location use the same codes as DOS PARTY.SAV.
## LIST is the surface monster table; TLST is its dungeon backup.

const _DosSaveImport := preload("res://src/core/dos_save_import.gd")

const ROST_CHAR := 32
const PRTY_BYTES := 32
const ROST_MIN := 0x15A
## Apple dungeon facing is N,E,S,W. DOS PARTY.SAV stores W,N,E,S.
const _APPLE_TO_DOS_DIR: Array[int] = [1, 2, 3, 0]


static func import_configured() -> Dictionary:
	if not GameState.apple2_britannia_path_committed():
		return {"ok": false, "error": "unset"}
	if GameState.apple2_britannia_path_missing():
		return {"ok": false, "error": "missing"}
	return import_from_path(GameState.apple2_britannia_dsk_path)


static func import_from_path(path: String) -> Dictionary:
	var disk := path.strip_edges()
	if disk.is_empty() or not FileAccess.file_exists(disk):
		return {"ok": false, "error": "missing"}
	if not Apple2ProgramDisk.looks_like_britannia_dsk(disk):
		return {"ok": false, "error": "invalid"}
	var prty := _payload(Apple2ProgramDisk.read_catalog_file(disk, "PRTY"))
	var rost := _payload(Apple2ProgramDisk.read_catalog_file(disk, "ROST"))
	if prty.size() < PRTY_BYTES or rost.size() < ROST_MIN:
		return {"ok": false, "error": "invalid"}
	var party := _party_from_disk(prty, rost)
	if not bool(party.get("ok", false)):
		return {"ok": false, "error": str(party.get("error", "invalid"))}
	var in_dungeon := int(party["location"]) >= 0x11
	var monster_name := "TLST" if in_dungeon else "LIST"
	var monsters := _payload(Apple2ProgramDisk.read_catalog_file(disk, monster_name))
	if monsters.size() != _DosSaveImport.MONSTERS_BYTES:
		monsters = PackedByteArray()
	return {
		"ok": true,
		"path": disk,
		"edition": _DosSaveImport.EDITION_EN,
		"party": party,
		"game": _DosSaveImport.game_from_party(party),
		"world": _DosSaveImport.world_from_party(party, monsters),
		"summary": _DosSaveImport.summary(party),
	}


static func _party_from_disk(prty: PackedByteArray, rost: PackedByteArray) -> Dictionary:
	var members := int(prty[0x0F])
	if members < 1 or members > 8:
		return {"ok": false, "error": "members"}
	var players: Array[Dictionary] = []
	var seen: Dictionary = {}
	for i in members:
		var player := _parse_character(rost, i * ROST_CHAR)
		if player.is_empty():
			return {"ok": false, "error": "player"}
		var klass := int(player["class"])
		if seen.has(klass):
			return {"ok": false, "error": "class"}
		seen[klass] = true
		players.append(player)
	var location := int(prty[0x0A])
	var map_type := int(prty[0x0B])
	var in_dungeon := location >= 0x11 and location <= 0x18
	var x := int(prty[0])
	var y := int(prty[1])
	var last_x := int(prty[0x08])
	var last_y := int(prty[0x09])
	var dngx := 0
	var dngy := 0
	if in_dungeon:
		dngx = clampi(x, 0, 7)
		dngy = clampi(y, 0, 7)
		x = last_x
		y = last_y
	elif map_type == 0x02 and (last_x != 0 or last_y != 0):
		x = last_x
		y = last_y
	var dnglevel := int(prty[0x0C])
	if dnglevel > 7:
		dnglevel = 0
	var transport := int(prty[0x0E])
	var flying := int(prty[0x0D]) != 0 and transport == 0x18
	var balloon_or_torch := int(prty[0x11]) if in_dungeon else (1 if flying else 0)
	var facing := _APPLE_TO_DOS_DIR[clampi(int(prty[0x10]), 0, 3)]
	return {
		"ok": true,
		"edition": _DosSaveImport.EDITION_EN,
		"unknown1": 0,
		"moves": _read_bcd(prty, 0x1C, 4),
		"players": players,
		"food": _read_bcd(rost, 0x110, 3),
		"gold": _read_bcd(rost, 0x113, 2),
		"karma": _bcd_bytes(rost, 0x100, 8),
		"torches": _read_bcd(rost, 0x108, 1),
		"gems": _read_bcd(rost, 0x109, 1),
		"keys": _read_bcd(rost, 0x10A, 1),
		"sextants": _read_bcd(rost, 0x10B, 1),
		"armor": _bcd_bytes(rost, 0x118, 8),
		"weapons": _bcd_bytes(rost, 0x120, 16),
		"reagents": _bcd_bytes(rost, 0x138, 8),
		"mixtures": _bcd_bytes(rost, 0x140, 26),
		"items": _items(rost),
		"x": x,
		"y": y,
		"stones": _reverse_bits(int(rost[0x10C])),
		"runes": _reverse_bits(int(rost[0x10D])),
		"members": members,
		"transport": transport,
		"balloon_or_torch": balloon_or_torch,
		"trammel": int(prty[0x12]),
		"felucca": int(prty[0x13]),
		"ship_hull": _read_bcd(prty, 0x1B, 1),
		"lb_intro": int(prty[0x15]),
		"lastcamp": int(prty[0x16]),
		"lastreagent": int(prty[0x1A]),
		"lastmeditation": int(prty[0x19]),
		"lastvirtue": int(prty[0x17]),
		"dngx": dngx,
		"dngy": dngy,
		"orientation": facing,
		"dnglevel": dnglevel,
		"location": location,
	}


static func _parse_character(rost: PackedByteArray, offset: int) -> Dictionary:
	if offset < 0 or offset + ROST_CHAR > rost.size():
		return {}
	var sex := int(rost[offset + 0x10])
	if sex == 0x5C or sex == 0x0B:
		sex = 0x0B
	elif sex == 0x7B or sex == 0x0C:
		sex = 0x0C
	else:
		return {}
	var klass := int(rost[offset + 0x11])
	if klass < 0 or klass > 7:
		return {}
	var status := int(rost[offset + 0x12]) & 0x7F
	if status not in [0x47, 0x50, 0x53, 0x44]:
		return {}
	var name := _decode_name(rost.slice(offset, offset + 16))
	if name.is_empty():
		return {}
	return {
		"hp": _read_bcd(rost, offset + 0x18, 2),
		"hp_max": maxi(1, _read_bcd(rost, offset + 0x1A, 2)),
		"xp": _read_bcd(rost, offset + 0x1C, 2),
		"str": _read_bcd(rost, offset + 0x13, 1),
		"dex": _read_bcd(rost, offset + 0x14, 1),
		"int": _read_bcd(rost, offset + 0x15, 1),
		"mp": _read_bcd(rost, offset + 0x16, 1),
		"unknown": int(rost[offset + 0x17]),
		"weapon": int(rost[offset + 0x1E]),
		"armor": int(rost[offset + 0x1F]),
		"name": name,
		"sex": sex,
		"class": klass,
		"status": status,
	}


static func _items(rost: PackedByteArray) -> int:
	## Bell / book / candle owned are 0x4 / 0x2 / 0x1; used are 0x40 / 0x20 / 0x10.
	## Three-part key T / L / C is 0x4 / 0x2 / 0x1. Skull is 1, or 0xFF if destroyed.
	var items := 0
	var bbc := int(rost[0x10E])
	if (bbc & 0x01) != 0:
		items |= GameState.ITEM_CANDLE
	if (bbc & 0x02) != 0:
		items |= GameState.ITEM_BOOK
	if (bbc & 0x04) != 0:
		items |= GameState.ITEM_BELL
	if (bbc & 0x10) != 0:
		items |= GameState.ITEM_CANDLE_USED
	if (bbc & 0x20) != 0:
		items |= GameState.ITEM_BOOK_USED
	if (bbc & 0x40) != 0:
		items |= GameState.ITEM_BELL_USED
	var key := int(rost[0x10F])
	if (key & 0x01) != 0:
		items |= GameState.ITEM_KEY_C
	if (key & 0x02) != 0:
		items |= GameState.ITEM_KEY_L
	if (key & 0x04) != 0:
		items |= GameState.ITEM_KEY_T
	if int(rost[0x115]) != 0:
		items |= GameState.ITEM_HORN
	if int(rost[0x116]) != 0:
		items |= GameState.ITEM_WHEEL
	var skull := int(rost[0x117])
	if skull == 0xFF:
		items |= GameState.ITEM_SKULL_DESTROYED
	elif skull != 0:
		items |= GameState.ITEM_SKULL
	return items


static func _decode_name(raw: PackedByteArray) -> String:
	var chars := PackedByteArray()
	for b in raw:
		var c := int(b) & 0x7F
		if c == 0:
			break
		if c < 32:
			continue
		chars.append(c)
	return chars.get_string_from_ascii().strip_edges()


static func _payload(raw: PackedByteArray) -> PackedByteArray:
	if raw.size() < 4:
		return PackedByteArray()
	var length := int(raw[2]) | (int(raw[3]) << 8)
	if length <= 0 or 4 + length > raw.size():
		return PackedByteArray()
	return raw.slice(4, 4 + length)


static func _bcd_bytes(bytes: PackedByteArray, offset: int, count: int) -> Array[int]:
	var out: Array[int] = []
	for i in count:
		out.append(_read_bcd(bytes, offset + i, 1))
	return out


static func _read_bcd(bytes: PackedByteArray, offset: int, count: int) -> int:
	if offset < 0 or offset + count > bytes.size():
		return 0
	var value := 0
	var valid := true
	for i in count:
		var b := int(bytes[offset + i])
		var hi := (b >> 4) & 0x0F
		var lo := b & 0x0F
		if hi > 9 or lo > 9:
			valid = false
			break
		value = value * 100 + hi * 10 + lo
	if valid:
		return value
	var binary := 0
	for i in count:
		binary = (binary << 8) | int(bytes[offset + i])
	return binary


static func _reverse_bits(value: int) -> int:
	## Apple stores blue/honesty in bit 7 and black/humility in bit 0.
	var out := 0
	for i in 8:
		if (value & (1 << i)) != 0:
			out |= 1 << (7 - i)
	return out
