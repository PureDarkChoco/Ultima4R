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
	if not await _check_picker(host, panel, "ready"):
		ok = false
	if not await _check_picker(host, panel, "wear"):
		ok = false
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


func _check_picker(host: Control, ztats: ZtatsPanel, kind: String) -> bool:
	var z_title_y := roundi(ztats._inv_title.global_position.y)
	var z_top := roundi(ztats._inv_scroll.global_position.y)
	var z_h := roundi(ztats._inv_scroll.size.y)
	var picker: Control = ReadyPanel.new() if kind == "ready" else WearPanel.new()
	host.add_child(picker)
	picker.call("open_for", 0, false)
	for i in 4:
		await get_tree().process_frame
	var cur: Control = picker.get("_cur_wrap")
	var scroll: ScrollContainer = picker.get("_scroll")
	var name: Label = picker.get("_member_name")
	var header: Control = picker.get("_header")
	var list: VBoxContainer = picker.get("_list")
	var block_top := roundi(cur.global_position.y)
	var block_h := roundi(scroll.global_position.y + scroll.size.y) - block_top
	var name_lab := _first_label(header)
	var icon := _row_icon(list.get_child(0))
	var name_x := roundi(name_lab.global_position.x) if name_lab != null else -1
	var icon_x := roundi(icon.global_position.x) if icon != null else -2
	var cur_value: Label = (
		picker.get("_cur_atk") as Label
		if kind == "ready"
		else picker.get("_cur_def") as Label
	)
	var cur_stat := cur_value.get_parent() as Control
	var header_row := _direct_hbox(header)
	var item_row := _direct_hbox(list.get_child(0))
	var header_delta := header_row.get_child(1) as Control
	var item_delta := item_row.get_child(2) as Control
	var item_stat := item_row.get_child(3) as Control
	var stat_right := roundi(cur_stat.global_position.x + cur_stat.size.x)
	var item_stat_right := roundi(item_stat.global_position.x + item_stat.size.x)
	var delta_right := roundi(header_delta.global_position.x + header_delta.size.x)
	var item_delta_right := roundi(item_delta.global_position.x + item_delta.size.x)
	print(
		"%s h=%d name_dy=%d block_top_dy=%d block_h=%d z_h=%d rows=%d name_x=%d icon_x=%d stat_dx=%d delta_dx=%d"
		% [
			kind,
			roundi(host.size.y),
			roundi(name.global_position.y) - z_title_y,
			block_top - z_top,
			block_h,
			z_h,
			int(picker.get("_visible_rows")),
			name_x,
			icon_x,
			stat_right - item_stat_right,
			delta_right - item_delta_right,
		]
	)
	var ok: bool = block_h == z_h
	ok = ok and absi(block_top - z_top) <= 1
	ok = ok and absi(roundi(name.global_position.y) - z_title_y) <= 1
	ok = ok and int(picker.get("_visible_rows")) == 7
	ok = ok and name_x == icon_x
	ok = ok and stat_right == item_stat_right
	ok = ok and delta_right == item_delta_right
	picker.queue_free()
	await get_tree().process_frame
	return ok


func _first_label(node: Node) -> Label:
	if node is Label:
		return node
	for child in node.get_children():
		var found := _first_label(child)
		if found != null:
			return found
	return null


func _row_icon(node: Node) -> TextureRect:
	## Ignore selection-edge TextureRects; the item icon is a direct HBox child.
	for child in node.get_children():
		if child is HBoxContainer:
			for cell in child.get_children():
				if cell is TextureRect:
					return cell
	return null


func _direct_hbox(node: Node) -> HBoxContainer:
	for child in node.get_children():
		if child is HBoxContainer:
			return child
	return null


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
