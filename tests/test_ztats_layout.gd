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
	if not await _check_cast(host, panel):
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
	var usable: Array = picker.get("_usable")
	var owned_indices: Array[int] = []
	for i in usable.size():
		usable[i] = i % 2 == 0
		if usable[i]:
			owned_indices.append(i)
	picker.set("_cursor", owned_indices[0])
	picker.call("page_cursor", 1)
	var paged := int(picker.get("_cursor"))
	var expected_page := owned_indices[mini(7, owned_indices.size() - 1)]
	picker.call("page_cursor", -1)
	var paged_back := int(picker.get("_cursor"))
	picker.call("cursor_end")
	var ended := int(picker.get("_cursor"))
	picker.call("cursor_home")
	var homed := int(picker.get("_cursor"))
	ok = ok and paged == expected_page
	ok = ok and paged_back == owned_indices[0]
	ok = ok and ended == owned_indices[-1]
	ok = ok and homed == owned_indices[0]
	var middle := owned_indices[int(owned_indices.size() / 2)]
	picker.set("_cursor", middle)
	picker.call("_ensure_cursor_visible")
	var stride := int(picker.call("_row_stride"))
	var visible_rows := int(picker.get("_visible_rows"))
	var expected_top := clampi(
		middle - int(visible_rows / 2),
		0,
		maxi(0, usable.size() - visible_rows)
	)
	ok = ok and int(scroll.scroll_vertical) == expected_top * stride
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


func _check_cast(host: Control, ztats: ZtatsPanel) -> bool:
	var z_title_y := roundi(ztats._inv_title.global_position.y)
	var z_top := roundi(ztats._inv_scroll.global_position.y)
	var z_h := roundi(ztats._inv_scroll.size.y)
	var panel := CastPanel.new()
	host.add_child(panel)
	panel.open_list(true, -1, -1)
	for i in 4:
		await get_tree().process_frame
	var header_wrap: Control = panel._header_wrap
	var scroll: ScrollContainer = panel._scroll
	var header_row := _direct_hbox(header_wrap)
	var item_row := _direct_hbox(panel._list.get_child(0))
	var header_name := _first_label(header_row)
	var first_content := item_row.get_child(0) as Control
	var header_mana := header_row.get_child(header_row.get_child_count() - 3) as Control
	var item_mana := item_row.get_child(item_row.get_child_count() - 3) as Control
	var header_qty := header_row.get_child(header_row.get_child_count() - 2) as Control
	var item_qty := item_row.get_child(item_row.get_child_count() - 2) as Control
	var block_top := roundi(header_wrap.global_position.y)
	var block_h := roundi(scroll.global_position.y + scroll.size.y) - block_top
	var ok := roundi(panel._title.global_position.y) == z_title_y
	ok = ok and block_top == z_top
	ok = ok and block_h == z_h
	ok = ok and panel._visible_rows == 8
	ok = ok and roundi(header_name.global_position.x) == roundi(first_content.global_position.x)
	ok = ok and _right_edge(header_mana) == _right_edge(item_mana)
	ok = ok and _right_edge(header_qty) == _right_edge(item_qty)
	var usable: Array = panel._usable
	var mixed_indices: Array[int] = []
	for i in usable.size():
		usable[i] = i % 2 == 0
		if usable[i]:
			mixed_indices.append(i)
	panel._cursor = mixed_indices[0]
	panel.page_cursor(1)
	ok = ok and panel._cursor == mixed_indices[mini(8, mixed_indices.size() - 1)]
	panel.page_cursor(-1)
	ok = ok and panel._cursor == mixed_indices[0]
	panel.cursor_end()
	ok = ok and panel._cursor == mixed_indices[-1]
	panel.cursor_home()
	ok = ok and panel._cursor == mixed_indices[0]
	panel.set_cursor(10)
	var center := int((panel._visible_rows - 1) / 2)
	ok = ok and int(scroll.scroll_vertical) == (10 - center) * panel._row_stride()
	panel.queue_free()
	await get_tree().process_frame
	return ok


func _right_edge(control: Control) -> int:
	return roundi(control.global_position.x + control.size.x)


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
