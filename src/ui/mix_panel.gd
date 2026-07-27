class_name MixPanel
extends Control

## Mix (M) — known-spell remix list + new-mix reagent picker.

const _ReagentIcons := preload("res://src/core/reagent_icons.gd")

const COL_TEXT := Color(0.91, 0.9, 0.82, 1)
const COL_ACCENT := Color(0.95, 0.85, 0.45, 1)
const COL_DIM := Color(0.45, 0.45, 0.48, 1)
const COL_PICKED := Color(0.45, 0.85, 0.45, 1)
const COL_CURSOR := Color(0.22, 0.42, 0.82, 0.55)
const COL_CURSOR_EDGE := Color(0.55, 0.78, 1.0, 0.95)
## Action rows (Mix New / Mix) — yellow (recipe not confirmed yet).
const COL_CURSOR_ACTION := Color(0.95, 0.78, 0.2, 0.42)
const COL_CURSOR_ACTION_EDGE := Color(0.95, 0.85, 0.45, 0.95)
const COL_ACTION_TEXT := Color(0.95, 0.85, 0.45, 1)
## Match Ztats mixtures index / EN cast-letter tint.
const COL_MIX_INDEX := Color(1.0, 0.82, 0.28, 1)

const FONT_SIZE := 13
## Source art is 32×32; match Ztats / Ready / Wear display size.
const INV_ICON := 20
const INV_ROW_H := 25 ## Match Ztats / Ready / Wear list stride.
const INV_LIST_SEP := 3 ## Match Ztats _inv_list separation.
const INV_QTY_W := 28
const INV_QTY_TRAIL := 8 ## Breathing room after qty digits.
const INV_PAD_H := 10
const INV_PAD_V := 4
const PAD_TOP := 14 ## Push list slightly down from panel top.
## Spell list shows 7 rows; reagent pick uses same block: 1 header + 6 rows.
const LIST_VISIBLE_ROWS := 7
const REAGENT_VISIBLE_ROWS := 6
const LIST_VIEW_H := LIST_VISIBLE_ROWS * INV_ROW_H + (LIST_VISIBLE_ROWS - 1) * INV_LIST_SEP
const REAGENT_SCROLL_H := REAGENT_VISIBLE_ROWS * INV_ROW_H + (REAGENT_VISIBLE_ROWS - 1) * INV_LIST_SEP
const STOCK_ICON := 20
const STOCK_QTY_FONT := 11
const COL_STOCK_ZERO := Color(0.55, 0.55, 0.58, 1)
## Known-spell recipe reagents (confirmed) — green.
const COL_STOCK_HI := Color(0.55, 0.92, 0.55, 1)
const COL_STOCK_HI_BG := Color(0.28, 0.62, 0.28, 0.35)
const COL_STOCK_HI_EDGE := Color(0.45, 0.9, 0.45, 0.95)
## Mix New staged reagents — yellow, same family as action selection.
const COL_STOCK_PICK := Color(0.95, 0.85, 0.45, 1)
const COL_STOCK_PICK_BG := Color(0.95, 0.78, 0.2, 0.35)
const COL_STOCK_PICK_EDGE := Color(0.95, 0.85, 0.45, 0.95)
const COL_STOCK_MISS := Color(0.95, 0.38, 0.32, 1)
const COL_STOCK_MISS_BG := Color(0.9, 0.22, 0.16, 0.35)
const COL_STOCK_MISS_EDGE := Color(0.95, 0.42, 0.35, 0.95)

## List row kinds: -1 = Make new, -2 = confirm Mix (reagent mode), else spell/reagent id.
const ROW_MAKE_NEW := -1
const ROW_CONFIRM_MIX := -2

enum Mode { LIST = 0, REAGENTS = 1 }

var _root: VBoxContainer
var _title: Label
var _list_block: VBoxContainer
var _spell_header: MarginContainer
var _spell_header_prefix: Label
var _spell_header_letter: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _stock_row: HBoxContainer
var _stock_icons: Array[TextureRect] = []
var _stock_qtys: Array[Label] = []
var _stock_cells: Array[Control] = []
var _stock_bgs: Array[ColorRect] = []
var _stock_edges: Array[ColorRect] = []

var _mode: int = Mode.LIST
var _cursor := 0
## LIST: parallel to rows — ROW_MAKE_NEW or spell id.
var _list_ids: Array[int] = []
## REAGENTS: selected count per reagent (0/1 for UI toggle).
var _selected: Array[int] = []
var _spell_id := -1 ## Target spell while in reagent mode (-1 none).
var _row_wraps: Array[Control] = []
## Color / grayscale reagent icons (keyed, paper bg stripped).
var _icon_color: Array[Texture2D] = []
var _icon_gray: Array[Texture2D] = []
## Bumps to cancel deferred scroll restores after close / fresh open.
var _scroll_gen := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", 2)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var pad_top := Control.new()
	pad_top.custom_minimum_size = Vector2(0, PAD_TOP)
	pad_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(pad_top)

	var title_wrap := MarginContainer.new()
	title_wrap.add_theme_constant_override("margin_left", INV_PAD_H)
	title_wrap.add_theme_constant_override("margin_right", INV_PAD_H)
	title_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(title_wrap)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", FONT_SIZE + 1)
	_title.add_theme_color_override("font_color", COL_ACCENT)
	UiTheme.apply_font(_title)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_wrap.add_child(_title)

	## Fixed-height block so stock bar stays put across list / reagent modes.
	_list_block = VBoxContainer.new()
	_list_block.custom_minimum_size = Vector2(0, LIST_VIEW_H)
	_list_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_block.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_list_block.add_theme_constant_override("separation", INV_LIST_SEP)
	_list_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_list_block)

	_spell_header = MarginContainer.new()
	_spell_header.custom_minimum_size = Vector2(0, INV_ROW_H)
	_spell_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spell_header.add_theme_constant_override("margin_left", INV_PAD_H)
	_spell_header.add_theme_constant_override("margin_right", INV_PAD_H)
	_spell_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spell_header.visible = false
	_list_block.add_child(_spell_header)

	var spell_row := HBoxContainer.new()
	spell_row.add_theme_constant_override("separation", 0)
	spell_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spell_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spell_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spell_header.add_child(spell_row)

	_spell_header_prefix = Label.new()
	_spell_header_prefix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_spell_header_prefix.add_theme_font_size_override("font_size", FONT_SIZE)
	_spell_header_prefix.add_theme_color_override("font_color", COL_TEXT)
	UiTheme.apply_font(_spell_header_prefix)
	_spell_header_prefix.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spell_row.add_child(_spell_header_prefix)

	_spell_header_letter = Label.new()
	_spell_header_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_spell_header_letter.add_theme_font_size_override("font_size", FONT_SIZE)
	_spell_header_letter.add_theme_color_override("font_color", COL_ACCENT)
	UiTheme.apply_font(_spell_header_letter)
	_spell_header_letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spell_row.add_child(_spell_header_letter)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll.custom_minimum_size = Vector2(0, LIST_VIEW_H)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_block.add_child(_scroll)

	var list_margin := MarginContainer.new()
	list_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_margin.add_theme_constant_override("margin_left", INV_PAD_H)
	list_margin.add_theme_constant_override("margin_right", INV_PAD_H)
	list_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(list_margin)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", INV_LIST_SEP)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_margin.add_child(_list)

	## Absorb leftover panel height so the stock bar sits near the bottom.
	var mid_spacer := Control.new()
	mid_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(mid_spacer)

	_build_stock_bar()
	_ensure_icon_cache()
	_apply_list_layout()


func _build_stock_bar() -> void:
	## Fixed footer — all 8 reagents with qty (0 shown gray).
	var stock_wrap := MarginContainer.new()
	stock_wrap.add_theme_constant_override("margin_left", INV_PAD_H)
	stock_wrap.add_theme_constant_override("margin_right", INV_PAD_H)
	stock_wrap.add_theme_constant_override("margin_top", 1)
	stock_wrap.add_theme_constant_override("margin_bottom", INV_PAD_V)
	stock_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stock_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(stock_wrap)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stock_wrap.add_child(col)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.35)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)

	_stock_row = HBoxContainer.new()
	_stock_row.add_theme_constant_override("separation", 2)
	_stock_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_stock_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_stock_row)

	_stock_icons.clear()
	_stock_qtys.clear()
	_stock_cells.clear()
	_stock_bgs.clear()
	_stock_edges.clear()
	for r in Spells.REAGENT_COUNT:
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(STOCK_ICON + 4, STOCK_ICON + STOCK_QTY_FONT + 4)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stock_row.add_child(cell)
		_stock_cells.append(cell)

		var bg := ColorRect.new()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.color = Color(0, 0, 0, 0)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(bg)
		_stock_bgs.append(bg)

		var edge := ColorRect.new()
		edge.set_anchors_preset(Control.PRESET_FULL_RECT)
		edge.offset_top = 0
		edge.offset_bottom = 0
		edge.offset_left = 0
		edge.offset_right = 0
		edge.color = Color(0, 0, 0, 0)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		## Thin top accent strip — filled in when recipe-needed.
		edge.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		edge.offset_bottom = 2
		cell.add_child(edge)
		_stock_edges.append(edge)

		var inner := VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.add_theme_constant_override("separation", 1)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(inner)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(STOCK_ICON, STOCK_ICON)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icon)
		_stock_icons.append(icon)

		var qty := Label.new()
		qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty.add_theme_font_size_override("font_size", STOCK_QTY_FONT)
		qty.add_theme_color_override("font_color", COL_TEXT)
		UiTheme.apply_font(qty)
		qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(qty)
		_stock_qtys.append(qty)


func open_list() -> void:
	## Fresh open / return to list — always start at the top row.
	_scroll_gen += 1
	_mode = Mode.LIST
	_spell_id = -1
	_selected.clear()
	_rebuild_list_mode()
	_refresh_stock_bar()
	_cursor = 0
	_sync_cursor()
	_restore_scroll(0)
	var gen := _scroll_gen
	call_deferred("_restore_scroll_gen", gen, 0)
	visible = true


func open_reagents(spell_id: int) -> void:
	## New / unknown mix — spell letter only; name stays hidden.
	_scroll_gen += 1
	_mode = Mode.REAGENTS
	_spell_id = spell_id
	_selected.clear()
	_selected.resize(Spells.REAGENT_COUNT)
	for i in Spells.REAGENT_COUNT:
		_selected[i] = 0
	_rebuild_reagent_mode()
	_refresh_stock_bar()
	_cursor = 0
	_sync_cursor()
	_restore_scroll(0)
	visible = true


func close_panel() -> void:
	_scroll_gen += 1
	visible = false
	_mode = Mode.LIST
	_spell_id = -1
	_selected.clear()
	_list_ids.clear()
	_row_wraps.clear()
	_clear_list()
	_restore_scroll(0)


func mode() -> int:
	return _mode


func spell_id() -> int:
	return _spell_id


func cursor() -> int:
	return _cursor


func list_id_at(index: int) -> int:
	if index < 0 or index >= _list_ids.size():
		return -99
	return _list_ids[index]


func cursor_list_id() -> int:
	return list_id_at(_cursor)


func selected_mask() -> int:
	var mask := 0
	for r in mini(_selected.size(), Spells.REAGENT_COUNT):
		if int(_selected[r]) > 0:
			mask |= 1 << r
	return mask


func selected_counts() -> Array[int]:
	var out: Array[int] = []
	out.assign(_selected)
	return out


func nudge_cursor(step: int) -> void:
	if _row_wraps.is_empty() or step == 0:
		return
	var n := _row_wraps.size()
	var next := clampi(_cursor + step, 0, n - 1)
	if next == _cursor:
		return
	_cursor = next
	_sync_cursor()
	_ensure_cursor_visible()
	_refresh_stock_bar()


func set_cursor(index: int) -> void:
	if index < 0 or index >= _row_wraps.size():
		return
	_cursor = index
	_sync_cursor()
	_ensure_cursor_visible()
	_refresh_stock_bar()


func index_of_spell(spell_id: int) -> int:
	for i in _list_ids.size():
		if _list_ids[i] == spell_id:
			return i
	return -1


func refresh_list_quantities() -> void:
	## After a successful remix while staying on the list.
	if _mode != Mode.LIST:
		return
	var keep := _cursor
	var keep_scroll := _scroll.scroll_vertical if _scroll else 0
	var gen := _scroll_gen
	_rebuild_list_mode()
	_refresh_stock_bar()
	_cursor = clampi(keep, 0, maxi(_row_wraps.size() - 1, 0))
	_sync_cursor()
	## Rebuild resets scroll; restore exactly (don't run ensure_cursor_visible).
	_restore_scroll(keep_scroll)
	call_deferred("_restore_scroll_gen", gen, keep_scroll)


func _restore_scroll(y: int) -> void:
	if _scroll == null:
		return
	_scroll.scroll_vertical = y


func _restore_scroll_gen(gen: int, y: int) -> void:
	## Ignore stale deferred restores after close / reopen.
	if gen != _scroll_gen:
		return
	_restore_scroll(y)


func toggle_reagent_at_cursor() -> bool:
	## Returns false if stock empty when selecting. No-op on Mix confirm row.
	if _mode != Mode.REAGENTS:
		return false
	if cursor_is_confirm_mix():
		return true
	if _cursor < 0 or _cursor >= Spells.REAGENT_COUNT:
		return false
	return _toggle_reagent(_cursor)


func cursor_is_confirm_mix() -> bool:
	return _mode == Mode.REAGENTS and cursor_list_id() == ROW_CONFIRM_MIX


func toggle_reagent_by_id(reag_id: int) -> bool:
	if _mode != Mode.REAGENTS:
		return false
	if reag_id < 0 or reag_id >= Spells.REAGENT_COUNT:
		return false
	_cursor = reag_id
	_sync_cursor()
	_ensure_cursor_visible()
	return _toggle_reagent(reag_id)


func revert_selected_reagents() -> void:
	## Put staged reagents back into inventory (cancel).
	for r in _selected.size():
		var n: int = int(_selected[r])
		if n > 0:
			GameState.adjust_reagent(r, n)
			_selected[r] = 0


func _toggle_reagent(reag_id: int) -> bool:
	var cur: int = int(_selected[reag_id])
	if cur > 0:
		## Deselect — return to pack.
		GameState.adjust_reagent(reag_id, cur)
		_selected[reag_id] = 0
		_rebuild_reagent_mode()
		_refresh_stock_bar()
		_sync_cursor()
		return true
	## Select one unit from pack.
	if GameState.reagent_qty(reag_id) < 1:
		return false
	if not GameState.adjust_reagent(reag_id, -1):
		return false
	_selected[reag_id] = 1
	_rebuild_reagent_mode()
	_refresh_stock_bar()
	_sync_cursor()
	return true


func _apply_list_layout() -> void:
	## List mode: full 7-row scroll. Reagent mode: 1-row header + 6-row scroll.
	## Total block height stays LIST_VIEW_H so the stock bar does not jump.
	var reagents := _mode == Mode.REAGENTS
	_spell_header.visible = reagents
	_scroll.custom_minimum_size = Vector2(0, REAGENT_SCROLL_H if reagents else LIST_VIEW_H)


func _rebuild_list_mode() -> void:
	_clear_list()
	_list_ids.clear()
	_row_wraps.clear()
	_title.text = Locale.t("mix_title")
	_spell_header_prefix.text = ""
	_spell_header_letter.text = ""
	_apply_list_layout()
	_add_text_row(ROW_MAKE_NEW, Locale.t("mix_make_new"), "", true)
	var ko := GameState.language == "ko"
	for sid in GameState.known_spell_ids():
		var qty := str(mini(GameState.mixture_qty(sid), 99))
		var can := GameState.can_remix_spell(sid)
		_add_spell_row(sid, Locale.spell_name(sid), qty, can, ko)


func _rebuild_reagent_mode() -> void:
	_clear_list()
	_list_ids.clear()
	_row_wraps.clear()
	_title.text = Locale.t("mix_title")
	## Hide spell name for unknown / new mixes — letter only (no control hints).
	var letter := Spells.letter(_spell_id) if _spell_id >= 0 else "?"
	_spell_header_prefix.text = Locale.t("mix_for_spell")
	_spell_header_letter.text = letter
	_apply_list_layout()
	var keep := _cursor
	for r in Spells.REAGENT_COUNT:
		_add_reagent_row(r)
	_add_text_row(ROW_CONFIRM_MIX, Locale.t("mix_action_mix"), "", true)
	_cursor = clampi(keep, 0, maxi(_row_wraps.size() - 1, 0))


func _add_text_row(row_id: int, name_text: String, qty_text: String, craftable: bool) -> void:
	var wrap := _make_row_shell()
	var row := wrap.get_node("Row") as HBoxContainer
	var col := (
		COL_ACTION_TEXT if row_id == ROW_CONFIRM_MIX or row_id == ROW_MAKE_NEW
		else (COL_TEXT if craftable else COL_DIM)
	)

	var icon_pad := Control.new()
	icon_pad.custom_minimum_size = Vector2(INV_ICON, 1)
	icon_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_pad)

	var name_lab := Label.new()
	name_lab.text = name_text
	name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lab.add_theme_font_size_override("font_size", FONT_SIZE)
	name_lab.add_theme_color_override("font_color", col)
	name_lab.clip_text = true
	UiTheme.apply_font(name_lab)
	name_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_lab)

	_add_qty_trail(row, qty_text, col)

	_list.add_child(wrap)
	_list_ids.append(row_id)
	_row_wraps.append(wrap)


func _add_spell_row(
	spell_id: int, name: String, qty_text: String, craftable: bool, ko: bool
) -> void:
	## Match Ztats mixtures: KO shows A.–Z. index; EN tints the name's first letter.
	var wrap := _make_row_shell()
	var row := wrap.get_node("Row") as HBoxContainer
	var body_col := COL_TEXT if craftable else COL_DIM
	var index_col := COL_MIX_INDEX if craftable else COL_DIM

	var icon_pad := Control.new()
	icon_pad.custom_minimum_size = Vector2(INV_ICON, 1)
	icon_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_pad)

	if ko:
		_add_spell_index(row, Spells.letter(spell_id), index_col)
		_add_spell_name(row, name, body_col)
	elif not name.is_empty():
		_add_spell_name_colored_initial(row, name, index_col, body_col)
	else:
		_add_spell_name(row, name, body_col)

	_add_qty_trail(row, qty_text, body_col)

	_list.add_child(wrap)
	_list_ids.append(spell_id)
	_row_wraps.append(wrap)


func _add_spell_index(row: HBoxContainer, letter: String, col: Color) -> void:
	var lab := Label.new()
	lab.text = "%s." % letter
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_spell_index_style(lab, col)
	row.add_child(lab)


func _add_spell_name(row: HBoxContainer, name: String, col: Color) -> void:
	var nm := Label.new()
	nm.text = name
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", FONT_SIZE)
	nm.add_theme_color_override("font_color", col)
	nm.clip_text = true
	UiTheme.apply_font(nm)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(nm)


func _add_spell_name_colored_initial(
	row: HBoxContainer, name: String, index_col: Color, body_col: Color
) -> void:
	## EN: tint the cast letter (first character) without a gap before the rest.
	var host := HBoxContainer.new()
	host.add_theme_constant_override("separation", 0)
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var initial := Label.new()
	initial.text = name.substr(0, 1)
	initial.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_spell_index_style(initial, index_col)
	host.add_child(initial)

	var rest := name.substr(1)
	if not rest.is_empty():
		var body := Label.new()
		body.text = rest
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		body.clip_text = true
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var settings := LabelSettings.new()
		var f: Font = UiTheme.font()
		if f:
			settings.font = f
		settings.font_size = FONT_SIZE
		settings.font_color = body_col
		body.label_settings = settings
		host.add_child(body)

	row.add_child(host)


func _apply_spell_index_style(lab: Label, col: Color) -> void:
	var settings := LabelSettings.new()
	var f: Font = UiTheme.font()
	if f:
		settings.font = f
	settings.font_size = FONT_SIZE
	settings.font_color = col
	lab.label_settings = settings


func _add_qty_trail(row: HBoxContainer, qty_text: String, col: Color) -> void:
	var qty_lab := Label.new()
	qty_lab.text = qty_text
	qty_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qty_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qty_lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	qty_lab.custom_minimum_size = Vector2(INV_QTY_W, 0)
	qty_lab.add_theme_font_size_override("font_size", FONT_SIZE)
	qty_lab.add_theme_color_override("font_color", col)
	UiTheme.apply_font(qty_lab)
	qty_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(qty_lab)

	var trail := Control.new()
	trail.custom_minimum_size = Vector2(INV_QTY_TRAIL, 1)
	trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(trail)


func _add_reagent_row(reag_id: int) -> void:
	var wrap := _make_row_shell()
	var row := wrap.get_node("Row") as HBoxContainer
	var picked: int = int(_selected[reag_id]) if reag_id < _selected.size() else 0
	var stock := GameState.reagent_qty(reag_id)
	var can_pick := stock > 0 or picked > 0

	## Match qty trail — keep icon clear of the left selection edge.
	var lead := Control.new()
	lead.custom_minimum_size = Vector2(INV_QTY_TRAIL, 1)
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lead)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(INV_ICON, INV_ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = _icon_for(reag_id, can_pick)
	icon.modulate = Color.WHITE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var letter := String.chr(65 + reag_id)
	var mark := "* " if picked > 0 else "  "
	var name_lab := Label.new()
	name_lab.text = "%s%s. %s" % [mark, letter, Locale.reagent_name(reag_id)]
	name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lab.add_theme_font_size_override("font_size", FONT_SIZE)
	name_lab.add_theme_color_override(
		"font_color", COL_STOCK_PICK if picked > 0 else (COL_TEXT if can_pick else COL_DIM)
	)
	name_lab.clip_text = true
	UiTheme.apply_font(name_lab)
	name_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_lab)

	var qty_lab := Label.new()
	qty_lab.text = str(mini(stock, 99))
	qty_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qty_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qty_lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	qty_lab.custom_minimum_size = Vector2(INV_QTY_W, 0)
	qty_lab.add_theme_font_size_override("font_size", FONT_SIZE)
	qty_lab.add_theme_color_override("font_color", COL_TEXT if can_pick else COL_DIM)
	UiTheme.apply_font(qty_lab)
	qty_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(qty_lab)

	var trail := Control.new()
	trail.custom_minimum_size = Vector2(INV_QTY_TRAIL, 1)
	trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(trail)

	_list.add_child(wrap)
	_list_ids.append(reag_id)
	_row_wraps.append(wrap)


func _make_row_shell() -> Control:
	## Same fixed stride as Ztats inventory / mixtures rows.
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, INV_ROW_H)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.clip_contents = true

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_meta("mix_bg", true)
	wrap.add_child(bg)

	var edge := ColorRect.new()
	edge.color = Color(0, 0, 0, 0)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	edge.offset_right = 2
	edge.set_meta("mix_edge", true)
	wrap.add_child(edge)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(row)
	return wrap


func _refresh_stock_bar() -> void:
	_ensure_icon_cache()
	var need_mask := _recipe_highlight_mask()
	for r in mini(_stock_icons.size(), Spells.REAGENT_COUNT):
		var qty := GameState.reagent_qty(r)
		var needed := (need_mask & (1 << r)) != 0
		var missing := needed and qty < 1
		var picked := (
			_mode == Mode.REAGENTS
			and r < _selected.size()
			and int(_selected[r]) > 0
		)
		var icon: TextureRect = _stock_icons[r]
		var lab: Label = _stock_qtys[r]
		## Pack qty already excludes staged picks; still show color icon if staged.
		if qty > 0 or picked:
			icon.texture = _icon_color[r] if r < _icon_color.size() else null
		else:
			icon.texture = _icon_gray[r] if r < _icon_gray.size() else null
		icon.modulate = Color.WHITE
		lab.text = str(mini(qty, 99))
		if picked:
			## Mix New staging — yellow, same as Mix New / Mix action cursor.
			if r < _stock_bgs.size():
				_stock_bgs[r].color = COL_STOCK_PICK_BG
			if r < _stock_edges.size():
				_stock_edges[r].color = COL_STOCK_PICK_EDGE
			lab.add_theme_color_override("font_color", COL_STOCK_PICK)
			icon.modulate = Color(1.15, 1.1, 0.85, 1.0)
		elif missing:
			if r < _stock_bgs.size():
				_stock_bgs[r].color = COL_STOCK_MISS_BG
			if r < _stock_edges.size():
				_stock_edges[r].color = COL_STOCK_MISS_EDGE
			lab.add_theme_color_override("font_color", COL_STOCK_MISS)
			icon.modulate = Color(1.2, 0.75, 0.7, 1.0)
		elif needed:
			## Known recipe — confirmed green.
			if r < _stock_bgs.size():
				_stock_bgs[r].color = COL_STOCK_HI_BG
			if r < _stock_edges.size():
				_stock_edges[r].color = COL_STOCK_HI_EDGE
			lab.add_theme_color_override("font_color", COL_STOCK_HI)
			icon.modulate = Color(1.05, 1.2, 1.05, 1.0)
		else:
			if r < _stock_bgs.size():
				_stock_bgs[r].color = Color(0, 0, 0, 0)
			if r < _stock_edges.size():
				_stock_edges[r].color = Color(0, 0, 0, 0)
			lab.add_theme_color_override(
				"font_color", COL_TEXT if qty > 0 else COL_STOCK_ZERO
			)


func _recipe_highlight_mask() -> int:
	## List cursor on a known spell → show its recipe; Make new / reagents = none.
	if _mode != Mode.LIST:
		return 0
	var sid := cursor_list_id()
	if sid < 0 or sid >= Spells.COUNT:
		return 0
	return Spells.recipe_mask(sid)


func _ensure_icon_cache() -> void:
	if _icon_color.size() == Spells.REAGENT_COUNT:
		return
	_icon_color.clear()
	_icon_gray.clear()
	for r in Spells.REAGENT_COUNT:
		var color_tex := _keyed_icon(r)
		_icon_color.append(color_tex)
		_icon_gray.append(_to_grayscale_tex(color_tex))


func _icon_for(reag_id: int, owned: bool) -> Texture2D:
	_ensure_icon_cache()
	if reag_id < 0 or reag_id >= _icon_color.size():
		return null
	return _icon_color[reag_id] if owned else _icon_gray[reag_id]


func _to_grayscale_tex(src: Texture2D) -> Texture2D:
	if src == null:
		return null
	var img := src.get_image()
	if img == null or img.is_empty():
		return src
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.02:
				continue
			var g := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			img.set_pixel(x, y, Color(g, g, g, c.a))
	return ImageTexture.create_from_image(img)


func _keyed_icon(reag_id: int) -> Texture2D:
	## Near-black bg → transparent (reagent art uses dark backdrops).
	var path := _ReagentIcons.path_for_id(reag_id)
	if path.is_empty():
		return null
	var img := Image.new()
	var fs := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if img.load(fs) != OK and img.load(path) != OK:
		var loaded := load(path) as Texture2D
		if loaded == null:
			return null
		img = loaded.get_image()
		if img == null or img.is_empty():
			return loaded
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.01 and c.r < 0.04 and c.g < 0.04 and c.b < 0.04:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func _sync_cursor() -> void:
	for i in _row_wraps.size():
		var wrap := _row_wraps[i]
		var on := i == _cursor
		var row_id := list_id_at(i)
		var action := row_id == ROW_MAKE_NEW or row_id == ROW_CONFIRM_MIX
		var bg := COL_CURSOR_ACTION if action else COL_CURSOR
		var edge := COL_CURSOR_ACTION_EDGE if action else COL_CURSOR_EDGE
		for c in wrap.get_children():
			if c.has_meta("mix_bg"):
				(c as ColorRect).color = bg if on else Color(0, 0, 0, 0)
			elif c.has_meta("mix_edge"):
				(c as ColorRect).color = edge if on else Color(0, 0, 0, 0)


func _ensure_cursor_visible() -> void:
	if _cursor < 0 or _cursor >= _row_wraps.size() or _scroll == null:
		return
	var row := _row_wraps[_cursor]
	var top := row.position.y
	var bot := top + row.size.y
	var view_top := _scroll.scroll_vertical
	var view_bot := view_top + _scroll.size.y
	if top < view_top:
		_scroll.scroll_vertical = int(top)
	elif bot > view_bot:
		_scroll.scroll_vertical = int(bot - _scroll.size.y)


func _clear_list() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
