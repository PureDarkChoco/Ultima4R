class_name LicensesPanel
extends Control

signal closed

const PANEL_W := 760.0
const PANEL_H := 560.0
const FONT_SIZE := 15
const SCROLL_STEP := 54.0

var _backdrop: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _title: Label
var _scroll: ScrollContainer
var _body: RichTextLabel
var _embedded := false
var _embed_rect := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false


func is_open() -> bool:
	return visible


func open_panel() -> void:
	_embedded = false
	_embed_rect = Rect2()
	_apply_presentation()
	refresh()
	visible = true
	move_to_front()


func open_embedded(rect: Rect2) -> void:
	_embedded = true
	_embed_rect = rect
	_apply_presentation()
	refresh()
	visible = true
	move_to_front()


func set_embed_rect(rect: Rect2) -> void:
	if not visible or not _embedded:
		return
	_embed_rect = rect
	_apply_presentation()


func close_panel() -> void:
	if not visible:
		return
	visible = false
	_embedded = false
	closed.emit()


func refresh() -> void:
	_title.text = Locale.t("licenses_title")
	_body.text = _text_ko() if str(GameState.language) == "ko" else _text_en()
	_scroll.scroll_vertical = 0


func scroll_by(delta: float) -> void:
	_scroll.scroll_vertical = clampi(
		_scroll.scroll_vertical + int(delta),
		0,
		int(_scroll.get_v_scroll_bar().max_value)
	)


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.72)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	_panel.add_theme_stylebox_override("panel", UiTheme.make_panel())
	_center.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", UiTheme.font_bold())
	_title.add_theme_font_size_override("font_size", FONT_SIZE + 4)
	_title.add_theme_color_override("font_color", UiTheme.ACCENT)
	col.add_child(_title)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, PANEL_H - 48.0)
	col.add_child(_scroll)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = false
	_body.fit_content = true
	_body.scroll_active = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(PANEL_W - 64.0, 0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_override("normal_font", UiTheme.font())
	_body.add_theme_font_override("bold_font", UiTheme.font_bold())
	_body.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_body.add_theme_color_override("default_color", UiTheme.TEXT)
	_scroll.add_child(_body)


func _apply_presentation() -> void:
	if _embedded and _embed_rect.size.x > 40.0 and _embed_rect.size.y > 40.0:
		_backdrop.visible = false
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		anchor_right = 0.0
		anchor_bottom = 0.0
		position = _embed_rect.position
		size = _embed_rect.size
		custom_minimum_size = _embed_rect.size
		_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_panel.custom_minimum_size = _embed_rect.size
		_scroll.custom_minimum_size = Vector2(0, maxf(_embed_rect.size.y - 48.0, 80.0))
		_body.custom_minimum_size = Vector2(maxf(_embed_rect.size.x - 40.0, 80.0), 0)
	else:
		_backdrop.visible = true
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		position = Vector2.ZERO
		custom_minimum_size = Vector2.ZERO
		_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_panel.add_theme_stylebox_override("panel", UiTheme.make_panel())
		_panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
		_scroll.custom_minimum_size = Vector2(0, PANEL_H - 48.0)
		_body.custom_minimum_size = Vector2(PANEL_W - 64.0, 0)


func _text_ko() -> String:
	return """Ultima IV (DOS) 게임 데이터

이 프로젝트를 플레이하려면 사용자가 합법적으로 취득한 Ultima IV DOS 버전의 원본 게임 데이터가 필요합니다. 이 프로젝트는 해당 게임 데이터를 배포하지 않습니다. 원본 데이터는 사용자가 취득한 라이선스 및 배포처의 이용 조건을 따릅니다.

Ultima, Ultima IV, Britannia, Origin Systems 및 관련 명칭과 자산의 권리는 각 권리자에게 있습니다. 이 팬 프로젝트는 Electronic Arts 또는 원 권리자와 제휴하거나 승인받은 제품이 아닙니다.

xu4

게임 규칙, 파일 형식 및 구현을 이해하기 위해 xu4 소스 코드와 문서를 참고했습니다.
https://github.com/xu4-engine/u4

xu4는 GNU General Public License version 3(GPL-3.0)으로 배포됩니다.

libhangul

두벌식, 세벌식 390, 세벌식 최종 한글 조합에 libhangul을 사용합니다.
https://github.com/libhangul/libhangul

libhangul은 GNU Lesser General Public License version 2.1 이상(LGPL-2.1-or-later)으로 배포됩니다.

Godot Engine 및 godot-cpp

이 프로젝트는 MIT 라이선스의 Godot Engine과 GDExtension 바인딩 godot-cpp를 사용합니다.
https://godotengine.org
https://github.com/godotengine/godot-cpp

u4graphics

Ultima IV 타일 그래픽은 jahshuwaa의 u4graphics를 사용합니다.
https://github.com/jahshuwaa/u4graphics

u4graphics는 The Unlicense에 따라 퍼블릭 도메인으로 공개되었습니다.

Raven Fantasy Icons

일부 UI 아이콘은 Clockwork Raven의 Raven Fantasy Icons를 사용합니다.
https://clockworkraven.itch.io/raven-fantasy-icons

해당 에셋은 제작자가 itch.io 상품 페이지에서 제시한 이용 조건에 따라 사용됩니다. 수정 및 프로젝트 내 사용은 허용되지만, 에셋 자체를 별도 상품으로 재배포하거나 판매할 수 없습니다. 표시는 필수가 아니지만 감사의 뜻으로 출처를 기재합니다.

D2Coding

UI 글꼴은 SIL Open Font License(OFL)의 D2Coding을 사용합니다.
https://github.com/naver/d2codingfont

면책

각 외부 프로젝트 및 에셋의 저작권과 상표는 해당 제작자와 권리자에게 있습니다. 위 링크에서 최신 원문 라이선스와 이용 조건을 확인할 수 있습니다.

AI 사용

개발과 대화 번역에는 AI가 사용되었습니다."""


func _text_en() -> String:
	return """Ultima IV (DOS) game data

This project requires original Ultima IV for DOS game data lawfully obtained by the user. No original game data is distributed with this project. That data remains subject to the license and terms under which the user acquired it.

Ultima, Ultima IV, Britannia, Origin Systems, and related names and assets belong to their respective owners. This fan project is not affiliated with or endorsed by Electronic Arts or the original rights holders.

xu4

xu4 source code and documentation were consulted to understand game rules, file formats, and implementation details.
https://github.com/xu4-engine/u4

xu4 is distributed under the GNU General Public License version 3 (GPL-3.0).

libhangul

libhangul provides Dubeolsik, Sebeolsik 390, and Sebeolsik Final composition.
https://github.com/libhangul/libhangul

libhangul is distributed under the GNU Lesser General Public License version 2.1 or later (LGPL-2.1-or-later).

Godot Engine and godot-cpp

This project uses the MIT-licensed Godot Engine and its godot-cpp GDExtension bindings.
https://godotengine.org
https://github.com/godotengine/godot-cpp

u4graphics

Ultima IV tile graphics use jahshuwaa's u4graphics.
https://github.com/jahshuwaa/u4graphics

u4graphics is dedicated to the public domain under The Unlicense.

Raven Fantasy Icons

Some UI icons use Raven Fantasy Icons by Clockwork Raven.
https://clockworkraven.itch.io/raven-fantasy-icons

The assets are used under the terms presented by the creator on the itch.io product page. Modification and use within a project are permitted, but the asset may not be redistributed or sold as a separate product. Attribution is not required, but is included with thanks.

D2Coding

The UI uses the D2Coding font under the SIL Open Font License (OFL).
https://github.com/naver/d2codingfont

Disclaimer

Copyrights and trademarks in third-party projects and assets remain with their respective authors and owners. Follow the links above for the current original license and usage terms.

AI usage

AI was used for development and dialogue translation."""
