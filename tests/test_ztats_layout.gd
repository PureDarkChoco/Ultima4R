extends Node

## Measures Ztats inventory pages so every list uses one row grid and bottom line.

const PAGES := [
	ZtatsPanel.InvPage.GEAR,
	ZtatsPanel.InvPage.REAGENTS,
	ZtatsPanel.InvPage.ITEMS,
	ZtatsPanel.InvPage.REAGENTS,
	ZtatsPanel.InvPage.MIXTURES,
	ZtatsPanel.InvPage.REAGENTS,
]


func _ready() -> void:
	_fill_inventory()
	var ok := true
	for h in [340, 300, 280, 260, 240]:
		if not await _check_height(h):
			ok = false
	print("ZTATS_LAYOUT_" + ("OK" if ok else "MISMATCH"))
	get_tree().quit(0 if ok else 1)


func _check_height(h: int) -> bool:
	var host := MarginContainer.new()
	host.position = Vector2.ZERO
	host.size = Vector2(430, h)
	add_child(host)
	var panel := ZtatsPanel.new()
	host.add_child(panel)
	await get_tree().process_frame
	var reference := {}
	var ok := true
	var page_i := 0
	for page in PAGES:
		panel.open_inventory(page, false)
		var first_row := panel._inv_list.get_child(0) as Control
		var initial_h := roundi(first_row.custom_minimum_size.y)
		for i in 6:
			await get_tree().process_frame
		var m := _measure(panel)
		m["panel_h"] = roundi(panel.size.y)
		m["initial_row_h"] = initial_h
		print("h=%d page=%d %s" % [h, page, JSON.stringify(m)])
		if reference.is_empty():
			reference = m
		elif m["grid"] != reference["grid"]:
			ok = false
		if m["panel_h"] != h or m["root_h"] != h:
			ok = false
		## Skip the very first open: the panel has no size until the first layout.
		if page_i > 0 and initial_h != int(m["row_h"]):
			ok = false
		page_i += 1
	host.queue_free()
	await get_tree().process_frame
	return ok


func _fill_inventory() -> void:
	for i in GameState.reagents.size():
		GameState.reagents[i] = 99
	for i in range(1, GameState.weapons.size()):
		GameState.weapons[i] = 99
	for i in range(1, GameState.armor.size()):
		GameState.armor[i] = 99
	for i in GameState.mixtures.size():
		GameState.mixtures[i] = 9
	GameState.stones = 0xFF
	GameState.runes = 0xFF


func _measure(panel: ZtatsPanel) -> Dictionary:
	var scroll: ScrollContainer = panel._inv_scroll
	var rows := panel._inv_list.get_children()
	var first := rows[0] as Control
	var ninth := rows[mini(8, rows.size() - 1)] as Control
	var top := scroll.global_position.y
	var grid := [
		roundi(first.global_position.y - top),
		roundi(first.size.y),
		roundi(ninth.global_position.y - top),
		roundi(scroll.size.y),
		roundi(top),
	]
	return {
		"grid": grid,
		"root_h": roundi(panel._inv_root.size.y),
		"title_h": roundi(panel._inv_title.size.y),
		"tail_h": roundi(panel._inv_tail.size.y),
		"row_h": panel._inv_row_h,
		"sep": panel._inv_row_sep,
		"rows": rows.size(),
	}
