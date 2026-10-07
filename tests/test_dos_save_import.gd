extends Node

const DosImport := preload("res://src/core/dos_save_import.gd")
const Save := preload("res://src/core/save_game.gd")
const JournalData := preload("res://src/core/journal.gd")


func _ready() -> void:
	var test_dir := "user://dos_import_test"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_dir))
	var bytes := _fixture()
	var file := FileAccess.open(test_dir.path_join("party.sav"), FileAccess.WRITE)
	assert(file != null)
	file.store_buffer(bytes)
	file.close()
	## Invalid optional files must be ignored, not make PARTY.SAV unusable.
	file = FileAccess.open(test_dir.path_join("monsters.sav"), FileAccess.WRITE)
	assert(file != null)
	file.store_8(1)
	file.close()

	var result := DosImport.import_from_data_dir(test_dir)
	assert(bool(result.get("ok", false)))
	var party: Dictionary = result["party"]
	assert(int(party["moves"]) == 12345)
	assert(int(party["gold"]) == 789)
	assert(int(party["runes"]) == 0x03)
	assert(int(party["stones"]) == 0x05)
	var game: Dictionary = result["game"]
	assert(str(game["player_name"]) == "Sol")
	assert(str(game["player_sex"]) == "female")
	assert(int(game["player_class"]) == 2)
	assert((game["party_order"] as Array) == [2])
	var world: Dictionary = result["world"]
	assert(not bool(world["in_dungeon"]))
	assert(int(world["transport"]) == 3)
	assert((world["creatures"] as Array).is_empty())

	## A valid optional table restores the current creature/object tiles.
	file = FileAccess.open(test_dir.path_join("monsters.sav"), FileAccess.WRITE)
	assert(file != null)
	var monsters := PackedByteArray()
	monsters.resize(DosImport.MONSTERS_BYTES)
	monsters.fill(0)
	monsters[0] = 192
	monsters[0x20] = 40
	monsters[0x40] = 41
	monsters[0x60] = 193
	monsters[8] = 24
	monsters[0x20 + 8] = 42
	monsters[0x40 + 8] = 43
	monsters[0x60 + 8] = 24
	file.store_buffer(monsters)
	file.close()
	result = DosImport.import_from_data_dir(test_dir)
	assert(bool(result.get("ok", false)))
	world = result["world"]
	assert(int((world["creatures"] as Array)[0]["t"]) == 192)
	assert(int((world["overlays"] as Array)[0]["t"]) == 24)

	var gs := get_node_or_null("/root/GameState")
	assert(gs != null)
	gs.reset_party()
	gs.apply_save_dict(game, Save.VERSION)
	JournalData.seed_dos_import(gs)
	assert(gs.player_name == "Sol")
	assert(gs.moves == 12345)
	assert(gs.journal_known_virtues & 0x07 == 0x07)
	assert(JournalData.has_entry_id(gs, "britannia.start.runes"))
	assert(JournalData.has_entry_id(gs, "britannia.start.stones"))
	var save := Save.build_save(
		gs.to_save_dict(), world, gs.player_name,
		gs.moves, gs.player_class, {"kind": "britannia"}
	)
	assert(Save.is_loadable(save))
	var roundtrip: Variant = JSON.parse_string(JSON.stringify(save))
	assert(typeof(roundtrip) == TYPE_DICTIONARY)
	assert(Save.is_loadable(roundtrip as Dictionary))
	if "--slot-write" in OS.get_cmdline_user_args():
		## Run this branch with an isolated HOME so no real player slot is touched.
		assert(Save.write_slot(1, save))
		var loaded := Save.read_slot(1)
		assert(Save.is_loadable(loaded))
		assert(str((loaded["game"] as Dictionary)["player_name"]) == "Sol")
		assert(Save.delete_slot(1))

	assert(not bool(DosImport.parse_party(PackedByteArray([1, 2, 3])).get("ok", false)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_dir.path_join("party.sav")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_dir.path_join("monsters.sav")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_dir))
	print("DOS_IMPORT_TEST_OK")
	get_tree().quit()


func _fixture() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(DosImport.PARTY_BYTES)
	out.fill(0)
	_put_u32(out, 4, 12345)
	var p := 8
	_put_u16(out, p, 250)
	_put_u16(out, p + 2, 300)
	_put_u16(out, p + 4, 456)
	_put_u16(out, p + 6, 21)
	_put_u16(out, p + 8, 22)
	_put_u16(out, p + 10, 23)
	_put_u16(out, p + 12, 24)
	_put_u16(out, p + 16, 4)
	_put_u16(out, p + 18, 3)
	var name := "Sol".to_ascii_buffer()
	for i in name.size():
		out[p + 20 + i] = name[i]
	out[p + 36] = 0x0C
	out[p + 37] = 2
	out[p + 38] = 0x47
	_put_u32(out, 0x140, 23456)
	_put_u16(out, 0x144, 789)
	for i in 8:
		_put_u16(out, 0x146 + i * 2, 0 if i == 0 else 50)
	_put_u16(out, 0x156, 7)
	_put_u16(out, 0x158, 8)
	_put_u16(out, 0x15A, 9)
	_put_u16(out, 0x15C, 1)
	_put_u16(out, 0x1D2, 0x0007)
	out[0x1D4] = 86
	out[0x1D5] = 107
	out[0x1D6] = 0x05
	out[0x1D7] = 0x03
	_put_u16(out, 0x1D8, 1)
	_put_u16(out, 0x1DA, 0x18)
	_put_u16(out, 0x1DC, 1)
	_put_u16(out, 0x1DE, 3)
	_put_u16(out, 0x1E0, 4)
	_put_u16(out, 0x1E2, 50)
	_put_u16(out, 0x1E4, 1)
	_put_u16(out, 0x1F2, 0xFFFF)
	_put_u16(out, 0x1F4, 0)
	return out


func _put_u16(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes[offset] = value & 0xFF
	bytes[offset + 1] = (value >> 8) & 0xFF


func _put_u32(bytes: PackedByteArray, offset: int, value: int) -> void:
	_put_u16(bytes, offset, value & 0xFFFF)
	_put_u16(bytes, offset + 2, (value >> 16) & 0xFFFF)
