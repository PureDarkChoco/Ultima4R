extends Node

## Tiny string table for intro UI. Real TLK / TITLE.EXE text comes later.

const _T := {
	"app_title": {
		"en_u4": "Ultima IV Reloaded",
		"en_us": "Ultima IV Reloaded",
		"ko": "울티마 IV Reloaded",
	},
	"boot_checking": {
		"en_u4": "Seeking the realms of Britannia...",
		"en_us": "Looking for Ultima IV data...",
		"ko": "울티마 IV 데이터를 찾는 중...",
	},
	"boot_ok": {
		"en_u4": "The land awaits.",
		"en_us": "Data found. Ready.",
		"ko": "데이터 확인됨.",
	},
	"boot_missing": {
		"en_u4": "The scrolls are missing. Place Ultima IV data in data/u4.",
		"en_us": "Ultima IV data not found. Link GOG files to data/u4.",
		"ko": "울티마 IV 데이터가 없습니다. data/u4 에 GOG 파일을 연결하세요.",
	},
	"menu_tagline": {
		"en_u4": "In another world, in a time to come.",
		"en_us": "In another world, in a time to come.",
		"ko": "다른 세계에서, 다가올 어느 때에.",
	},
	"menu_options": {
		"en_u4": "Options:",
		"en_us": "Options:",
		"ko": "선택:",
	},
	"menu_return": {
		"en_u4": "Return to the view",
		"en_us": "Return to the view",
		"ko": "광경으로 돌아가기",
	},
	"menu_journey": {
		"en_u4": "Journey Onward",
		"en_us": "Journey Onward",
		"ko": "여정을 이어가다",
	},
	"menu_new": {
		"en_u4": "Initiate New Game",
		"en_us": "Initiate New Game",
		"ko": "새 게임 시작",
	},
	"menu_language": {
		"en_u4": "Language",
		"en_us": "Language",
		"ko": "언어",
	},
	"menu_quit": {
		"en_u4": "Quit",
		"en_us": "Quit",
		"ko": "종료",
	},
	"menu_copyright": {
		"en_u4": "© Copyright 1987 Lord British",
		"en_us": "© Copyright 1987 Lord British",
		"ko": "© Copyright 1987 Lord British",
	},
	"journey_stub": {
		"en_u4": "No saved quest yet.",
		"en_us": "No save file yet — start a new game.",
		"ko": "저장 파일이 없습니다. 새 게임을 시작하세요.",
	},
	"gypsy_lead": {
		"en_u4": "The gypsy places two cards upon the table:",
		"en_us": "The gypsy lays two cards on the table:",
		"ko": "집시가 탁자 위에 카드 두 장을 내려놓습니다:",
	},
	"gypsy_consider": {
		"en_u4": "Consider this:",
		"en_us": "Think carefully:",
		"ko": "잘 생각해 보세요:",
	},
	"round_of": {
		"en_u4": "Question %d of 7",
		"en_us": "Question %d / 7",
		"ko": "질문 %d / 7",
	},
	"name_prompt": {
		"en_u4": "What is thy name?",
		"en_us": "What's your name?",
		"ko": "이름이 무엇인가요?",
	},
	"sex_prompt": {
		"en_u4": "Art thou Male or Female?",
		"en_us": "Are you male or female?",
		"ko": "성별을 고르세요.",
	},
	"sex_male": {
		"en_u4": "Male",
		"en_us": "Male",
		"ko": "남성",
	},
	"sex_female": {
		"en_u4": "Female",
		"en_us": "Female",
		"ko": "여성",
	},
	"continue": {
		"en_u4": "Continue",
		"en_us": "Continue",
		"ko": "계속",
	},
	"back": {
		"en_u4": "Back",
		"en_us": "Back",
		"ko": "뒤로",
	},
	"you_are": {
		"en_u4": "Thou art a %s.",
		"en_us": "You're a %s.",
		"ko": "당신은 %s입니다.",
	},
	"enter_britannia": {
		"en_u4": "Enter Britannia",
		"en_us": "Enter Britannia",
		"ko": "브리타니아로",
	},
	"stub_world": {
		"en_u4": "The world map will rise here.\n%s the %s\nStarting near (%d, %d)",
		"en_us": "World map stub.\n%s the %s\nStart tile (%d, %d)",
		"ko": "월드 맵 (임시).\n%s — %s\n시작 좌표 (%d, %d)",
	},
	"press_menu": {
		"en_u4": "Press Cancel to return to the menu.",
		"en_us": "Cancel / B — back to menu.",
		"ko": "취소(B) — 메뉴로",
	},
	"input_hint_form": {
		"en_u4": "Name: Enter/click to type · Keys: ↑↓←→ · Pad: D-pad + A · A/B = Male/Female",
		"en_us": "Name: Enter or click to type · Arrows · Gamepad D-pad + A · A/B = Male/Female",
		"ko": "이름: Enter/클릭으로 입력 · 방향키 · 패드 D-패드+A · A/B = 남/여",
	},
	"input_hint_menu": {
		"en_u4": "Mouse: click · Keys: ↑↓ Enter · Pad: D-pad + A",
		"en_us": "Mouse click · Arrows/Enter · Gamepad D-pad + A",
		"ko": "마우스 클릭 · 방향키/Enter · 패드 D-패드+A",
	},
	"input_hint_virtue": {
		"en_u4": "Mouse: click a path · Keys: A/B or ←→ Enter · Pad: X/Y or D-pad + A",
		"en_us": "Click a path · A/B or arrows+Enter · Pad: X/Y or D-pad + A",
		"ko": "클릭으로 선택 · A/B 또는 방향키+Enter · 패드 X/Y 또는 D-패드+A",
	},
	"input_hint_world": {
		"en_u4": "Arrows move · A–Z commands · Esc menu · F11 fullscreen",
		"en_us": "Arrow keys move · A–Z = commands (not WASD) · Esc menu · F11 fullscreen",
		"ko": "방향키 이동 · A–Z 명령키 · Esc 메뉴 · F11 전체화면",
	},
	"cmd_need_dir": {
		"en_u4": "%s: Dir?",
		"en_us": "%s: Dir?",
		"ko": "%s: Dir?",
	},
	"cmd_dir_done": {
		"en_u4": "%s: %s",
		"en_us": "%s: %s",
		"ko": "%s: %s",
	},
	"cmd_cancelled": {
		"en_u4": "Cancelled.",
		"en_us": "Cancelled.",
		"ko": "취소됨.",
	},
	"cmd_what": {
		"en_u4": "What?",
		"en_us": "What?",
		"ko": "What?",
	},
	"cmd_nothing_to_attack": {
		"en_u4": "Nothing to Attack!",
		"en_us": "Nothing to Attack!",
		"ko": "Nothing to Attack!",
	},
	"cmd_jimmy_what": {
		"en_u4": "Jimmy what?",
		"en_us": "Jimmy what?",
		"ko": "Jimmy what?",
	},
	"cmd_not_here": {
		"en_u4": "Not Here!",
		"en_us": "Not Here!",
		"ko": "Not Here!",
	},
	"cmd_no_response": {
		"en_u4": "Funny, no response!",
		"en_us": "Funny, no response!",
		"ko": "Funny, no response!",
	},
	"cmd_fire_what": {
		"en_u4": "Fire What?",
		"en_us": "Fire What?",
		"ko": "Fire What?",
	},
	"cmd_peer_gem": {
		"en_u4": "Peer at a Gem!",
		"en_us": "Peer at a Gem!",
		"ko": "Peer at a Gem!",
	},
	"cmd_peer_what": {
		"en_u4": "Peer at What?",
		"en_us": "Peer at What?",
		"ko": "Peer at What?",
	},
	## xu4 newOrder()
	"cmd_new_order": {
		"en_u4": "New Order!",
		"en_us": "New Order!",
		"ko": "New Order!",
	},
	"cmd_exchange": {
		"en_u4": "Exchange # ",
		"en_us": "Exchange # ",
		"ko": "Exchange # ",
	},
	"cmd_exchange_done": {
		"en_u4": "Exchange # %s",
		"en_us": "Exchange # %s",
		"ko": "Exchange # %s",
	},
	"cmd_with": {
		"en_u4": "    with # ",
		"en_us": "    with # ",
		"ko": "    with # ",
	},
	"cmd_with_done": {
		"en_u4": "    with # %s",
		"en_us": "    with # %s",
		"ko": "    with # %s",
	},
	"cmd_none": {
		"en_u4": "None",
		"en_us": "None",
		"ko": "None",
	},
	"cmd_must_lead": {
		"en_u4": "%s, You must lead!",
		"en_us": "%s, You must lead!",
		"ko": "%s, You must lead!",
	},
	## xu4 ztatsFor()
	"cmd_ztats_for": {
		"en_u4": "Ztats for: ",
		"en_us": "Ztats for: ",
		"ko": "Ztats for: ",
	},
	"cmd_ztats_for_done": {
		"en_u4": "Ztats for: %s",
		"en_us": "Ztats for: %s",
		"ko": "Ztats for: %s",
	},
	"cmd_fired": {
		"en_u4": "%s) %s",
		"en_us": "%s) %s",
		"ko": "%s) %s",
	},
	"cmd_stub": {
		"en_u4": "%s) %s — (not yet implemented)",
		"en_us": "%s) %s — stub (coming soon)",
		"ko": "%s) %s — 아직 미구현",
	},
	"cmd_locate": {
		"en_u4": "%s) %s  %s %s",
		"en_us": "%s) %s  %s %s",
		"ko": "%s) %s  %s %s",
	},
	"dir_north": {
		"en_u4": "North",
		"en_us": "North",
		"ko": "북쪽",
	},
	"dir_south": {
		"en_u4": "South",
		"en_us": "South",
		"ko": "남쪽",
	},
	"dir_east": {
		"en_u4": "East",
		"en_us": "East",
		"ko": "동쪽",
	},
	"dir_west": {
		"en_u4": "West",
		"en_us": "West",
		"ko": "서쪽",
	},
	## Move log only — Korean drops 쪽 (동서남북).
	"dir_move_north": {
		"en_u4": "North",
		"en_us": "North",
		"ko": "북",
	},
	"dir_move_south": {
		"en_u4": "South",
		"en_us": "South",
		"ko": "남",
	},
	"dir_move_east": {
		"en_u4": "East",
		"en_us": "East",
		"ko": "동",
	},
	"dir_move_west": {
		"en_u4": "West",
		"en_us": "West",
		"ko": "서",
	},
	## Ztats sheet
	"ztats_status_good": {
		"en_u4": "Good",
		"en_us": "Good",
		"ko": "양호",
	},
	"ztats_status_poisoned": {
		"en_u4": "Poisoned",
		"en_us": "Poisoned",
		"ko": "중독",
	},
	"ztats_status_sleeping": {
		"en_u4": "Sleeping",
		"en_us": "Sleeping",
		"ko": "수면",
	},
	"ztats_status_dead": {
		"en_u4": "Dead",
		"en_us": "Dead",
		"ko": "사망",
	},
	"ztats_str": {
		"en_u4": "STR: ",
		"en_us": "STR: ",
		"ko": "힘: ",
	},
	"ztats_dex": {
		"en_u4": "DEX: ",
		"en_us": "DEX: ",
		"ko": "민첩: ",
	},
	"ztats_int": {
		"en_u4": "INT: ",
		"en_us": "INT: ",
		"ko": "지능: ",
	},
	"ztats_weapon_kind": {
		"en_u4": "Weapon: ",
		"en_us": "Weapon: ",
		"ko": "무기: ",
	},
	"ztats_armor_kind": {
		"en_u4": "Armor: ",
		"en_us": "Armor: ",
		"ko": "갑옷: ",
	},
	"ztats_atk": {
		"en_u4": "ATK: ",
		"en_us": "ATK: ",
		"ko": "공격: ",
	},
	"ztats_def": {
		"en_u4": "DEF: ",
		"en_us": "DEF: ",
		"ko": "방어: ",
	},
	"item_dagger": {
		"en_u4": "Dagger",
		"en_us": "Dagger",
		"ko": "단검",
	},
	"item_sword": {
		"en_u4": "Sword",
		"en_us": "Sword",
		"ko": "장검",
	},
	"item_axe": {
		"en_u4": "Axe",
		"en_us": "Axe",
		"ko": "도끼",
	},
	"item_magic_sword": {
		"en_u4": "Magic Sword",
		"en_us": "Magic Sword",
		"ko": "마법검",
	},
	"item_bow": {
		"en_u4": "Bow",
		"en_us": "Bow",
		"ko": "활",
	},
	"item_magic_axe": {
		"en_u4": "Magic Axe",
		"en_us": "Magic Axe",
		"ko": "마법도끼",
	},
	"item_mystic_sword": {
		"en_u4": "Mystic Sword",
		"en_us": "Mystic Sword",
		"ko": "신비의 검",
	},
	"item_staff": {
		"en_u4": "Staff",
		"en_us": "Staff",
		"ko": "지팡이",
	},
	"item_sling": {
		"en_u4": "Sling",
		"en_us": "Sling",
		"ko": "새총",
	},
	"item_mace": {
		"en_u4": "Mace",
		"en_us": "Mace",
		"ko": "철퇴",
	},
	"item_crossbow": {
		"en_u4": "Crossbow",
		"en_us": "Crossbow",
		"ko": "석궁",
	},
	"item_flaming_oil": {
		"en_u4": "Flaming Oil",
		"en_us": "Flaming Oil",
		"ko": "화염병",
	},
	"item_halberd": {
		"en_u4": "Halberd",
		"en_us": "Halberd",
		"ko": "미늘창",
	},
	"item_magic_bow": {
		"en_u4": "Magic Bow",
		"en_us": "Magic Bow",
		"ko": "마법 활",
	},
	"item_magic_wand": {
		"en_u4": "Magic Wand",
		"en_us": "Magic Wand",
		"ko": "마법 지팡이",
	},
	"item_wand": {
		"en_u4": "Wand",
		"en_us": "Wand",
		"ko": "마법 지팡이",
	},
	"item_hands": {
		"en_u4": "Hands",
		"en_us": "Hands",
		"ko": "맨손",
	},
	"item_cloth": {
		"en_u4": "Cloth",
		"en_us": "Cloth",
		"ko": "천",
	},
	"item_leather": {
		"en_u4": "Leather",
		"en_us": "Leather",
		"ko": "가죽",
	},
	"item_chain": {
		"en_u4": "Chain",
		"en_us": "Chain",
		"ko": "체인",
	},
	"item_plate": {
		"en_u4": "Plate",
		"en_us": "Plate",
		"ko": "판금",
	},
	"item_magic_plate": {
		"en_u4": "Magic Plate",
		"en_us": "Magic Plate",
		"ko": "마법 판금",
	},
	"item_magic_chain": {
		"en_u4": "Magic Chain",
		"en_us": "Magic Chain",
		"ko": "마법 체인",
	},
	"item_mystic_robe": {
		"en_u4": "Mystic Robe",
		"en_us": "Mystic Robe",
		"ko": "신비의 로브",
	},
	"item_no_armour": {
		"en_u4": "No Armour",
		"en_us": "No Armour",
		"ko": "없음",
	},
	"item_no_armor": {
		"en_u4": "No Armor",
		"en_us": "No Armor",
		"ko": "없음",
	},
}


func t(key: String, args: Array = []) -> String:
	var pack: Dictionary = _T.get(key, {})
	var s: String = pack.get(GameState.language, pack.get("en_us", key))
	if args.is_empty():
		return s
	return s % args


## Virtue dilemma.
## en_u4 → TITLE.EXE original · en_us/ko → overlay (fallback to TITLE.EXE / stub).
func virtue_question(v_low: int, v_high: int) -> String:
	var idx := TitleExeData.question_index(v_low, v_high)
	var lang := GameState.language
	if lang != "en_u4" and GameState.intro_overlay.has_question(lang, idx):
		return GameState.intro_overlay.question(lang, idx)

	if GameState.intro_data.loaded:
		var original := GameState.intro_data.question_for_pair(v_low, v_high)
		if not original.is_empty():
			return original

	var a := Virtues.name_of(v_low, GameState.lang_short())
	var b := Virtues.name_of(v_high, GameState.lang_short())
	match lang:
		"ko":
			return "삶이 그대를 시험할 때, 그대는 [%s]을(를) 따르겠습니까, 아니면 [%s]을(를) 따르겠습니까?" % [a, b]
		"en_u4":
			return "In the face of life's trials, wilt thou follow the path of %s, or the path of %s?" % [a, b]
		_:
			return "When life puts you to the test, do you follow %s — or %s?" % [a, b]


func gypsy_lead(round_i: int) -> String:
	var lang := GameState.language
	if lang != "en_u4" and GameState.intro_overlay.has_gypsy(lang):
		var n := TitleExeData.GYP_PLACES_FIRST
		if round_i == 6:
			n = TitleExeData.GYP_PLACES_LAST
		elif round_i > 0:
			n = TitleExeData.GYP_PLACES_TWOMORE
		return "%s\n%s" % [
			GameState.intro_overlay.gypsy(lang, n),
			GameState.intro_overlay.gypsy(lang, TitleExeData.GYP_UPON_TABLE),
		]
	if GameState.intro_data.loaded:
		return GameState.intro_data.gypsy_lead_for_round(round_i)
	return t("gypsy_lead")


func gypsy_cards_line(v1: int, v2: int) -> String:
	var lang := GameState.language
	var n1 := virtue_card_name(v1)
	var n2 := virtue_card_name(v2)
	if lang != "en_u4" and GameState.intro_overlay.loaded:
		return GameState.intro_overlay.cards_line_fmt(lang) % [n1, n2]
	if GameState.intro_data.loaded:
		return GameState.intro_data.gypsy_cards_line(v1, v2)
	return "%s · %s" % [n1, n2]


func virtue_card_name(virtue: int) -> String:
	var lang := GameState.language
	if lang != "en_u4" and GameState.intro_overlay.has_gypsy(lang):
		var name := GameState.intro_overlay.gypsy(lang, virtue + 4)
		if not name.is_empty():
			return name
		return Virtues.name_of(virtue, GameState.lang_short())
	if GameState.intro_data.loaded:
		return GameState.intro_data.virtue_card_name(virtue)
	return Virtues.name_of(virtue, GameState.lang_short())


func virtue_choice_label(letter: String, virtue: int) -> String:
	return "%s — %s" % [letter, virtue_card_name(virtue)]
