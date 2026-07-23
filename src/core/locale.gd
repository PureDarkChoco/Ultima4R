extends Node

## Tiny string table for intro UI. Real TLK / TITLE.EXE text comes later.

const _Spells := preload("res://src/core/spells.gd")

const _T := {
	"app_title": {
		"en_u4": "Ultima IV++",
		"en_us": "Ultima IV++",
		"ko": "울티마 IV++",
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
	## Clear language option labels (not raw ids like en_u4).
	"lang_en_us": {
		"en_u4": "English",
		"en_us": "English",
		"ko": "영어",
	},
	"lang_en_u4": {
		"en_u4": "Classic English",
		"en_us": "Classic English",
		"ko": "원작 영어",
	},
	"lang_ko": {
		"en_u4": "Korean",
		"en_us": "Korean",
		"ko": "한국어",
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
	"press_any_key": {
		"en_u4": "Press any key to continue.",
		"en_us": "Press any key to continue.",
		"ko": "아무 키나 누르세요.",
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
		"en_u4": "%s: %s",
		"en_us": "%s: %s",
		"ko": "%s: %s",
	},
	## Second half of direction prompts ("Attack: Dir?").
	"cmd_dir_ask": {
		"en_u4": "Dir?",
		"en_us": "Dir?",
		"ko": "방향?",
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
		"ko": "응?",
	},
	"cmd_nothing_to_attack": {
		"en_u4": "Nothing to Attack!",
		"en_us": "Nothing to Attack!",
		"ko": "공격할 대상이 없다!",
	},
	"cmd_jimmy_what": {
		"en_u4": "Jimmy what?",
		"en_us": "Jimmy what?",
		"ko": "무엇의 자물쇠를?",
	},
	"cmd_not_here": {
		"en_u4": "Not Here!",
		"en_us": "Not Here!",
		"ko": "여기엔 없다!",
	},
	"cmd_nothing_to_open": {
		"en_u4": "Not Here!",
		"en_us": "Not Here!",
		"ko": "열 것이 없다!",
	},
	"cmd_no_response": {
		"en_u4": "Funny, no response!",
		"en_us": "Funny, no response!",
		"ko": "이상하다, 대답이 없다!",
	},
	"cmd_fire_what": {
		"en_u4": "Fire What?",
		"en_us": "Fire What?",
		"ko": "무엇을 쏘나?",
	},
	## xu4 board() / exitTransport()
	"cmd_board_what": {
		"en_u4": "Board What?",
		"en_us": "Board What?",
		"ko": "무엇에 타나?",
	},
	"cmd_board_cant": {
		"en_u4": "Board: Can't!",
		"en_us": "Board: Can't!",
		"ko": "탑승: 불가!",
	},
	"cmd_board_ship": {
		"en_u4": "Board Frigate!",
		"en_us": "Board Frigate!",
		"ko": "프리깃에 승선!",
	},
	"cmd_board_horse": {
		"en_u4": "Mount Horse!",
		"en_us": "Mount Horse!",
		"ko": "말에 오른다!",
	},
	"cmd_xit": {
		"en_u4": "X-it",
		"en_us": "X-it",
		"ko": "하차",
	},
	"cmd_xit_what": {
		"en_u4": "X-it What?",
		"en_us": "X-it What?",
		"ko": "무엇에서 내리나?",
	},
	"cmd_blocked": {
		"en_u4": "Blocked!",
		"en_us": "Blocked!",
		"ko": "막혔다!",
	},
	## xu4 Yell (Y) — horse gallop.
	"cmd_yell_giddyup": {
		"en_u4": "Yell Giddyup!",
		"en_us": "Yell Giddyup!",
		"ko": "외침: 이랴!",
	},
	"cmd_yell_whoa": {
		"en_u4": "Yell Whoa!",
		"en_us": "Yell Whoa!",
		"ko": "외침: 워워!",
	},
	"cmd_yell_what": {
		"en_u4": "Yell What?",
		"en_us": "Yell What?",
		"ko": "무엇에 외치나?",
	},
	## Ship cruise stop (U5-style) — not horse Whoa.
	"cmd_yell_ship_stop": {
		"en_u4": "Stopped!",
		"en_us": "Stopped!",
		"ko": "정지!",
	},
	## Ship cruise stopped by land / shallow / blocked water.
	"cmd_yell_land": {
		"en_u4": "Land!",
		"en_us": "Land!",
		"ko": "육지!",
	},
	## xu4 ship movement feedback.
	"cmd_turn": {
		"en_u4": "Turn %s!",
		"en_us": "Turn %s!",
		"ko": "%s으로 선회!",
	},
	"cmd_sail": {
		"en_u4": "Sail %s!",
		"en_us": "Sail %s!",
		"ko": "%s으로 항해!",
	},
	"cmd_slow_progress": {
		"en_u4": "Slow progress!",
		"en_us": "Slow progress!",
		"ko": "더디게 나아간다!",
	},
	"cmd_peer_gem": {
		"en_u4": "Peer at a Gem!",
		"en_us": "Peer at a Gem!",
		"ko": "보석을 들여다본다!",
	},
	"cmd_peer_what": {
		"en_u4": "Peer at What?",
		"en_us": "Peer at What?",
		"ko": "무엇으로 들여다보나?",
	},
	## xu4 newOrder()
	"cmd_new_order": {
		"en_u4": "New Order!",
		"en_us": "New Order!",
		"ko": "대열 변경!",
	},
	"cmd_exchange": {
		"en_u4": "Exchange # ",
		"en_us": "Exchange # ",
		"ko": "대열 변경 # ",
	},
	"cmd_exchange_done": {
		"en_u4": "Exchange # %s",
		"en_us": "Exchange # %s",
		"ko": "대열 변경 # %s",
	},
	"cmd_with": {
		"en_u4": "    with # ",
		"en_us": "    with # ",
		"ko": "    와 # ",
	},
	"cmd_with_done": {
		"en_u4": "    with # %s",
		"en_us": "    with # %s",
		"ko": "    와 # %s",
	},
	"cmd_none": {
		"en_u4": "None",
		"en_us": "None",
		"ko": "없음",
	},
	"cmd_must_lead": {
		"en_u4": "%s, You must lead!",
		"en_us": "%s, You must lead!",
		"ko": "%s, 네가 앞장서라!",
	},
	## xu4 ztatsFor()
	"cmd_ztats_for": {
		"en_u4": "Ztats for: ",
		"en_us": "Ztats for: ",
		"ko": "상태 보기: ",
	},
	"cmd_ztats_for_done": {
		"en_u4": "Ztats for: %s",
		"en_us": "Ztats for: %s",
		"ko": "상태 보기: %s",
	},
	## xu4 readyWeapon()
	"cmd_ready_for": {
		"en_u4": "Ready a weapon for: ",
		"en_us": "Ready a weapon for: ",
		"ko": "무기를 장착할 대상: ",
	},
	"cmd_ready_for_done": {
		"en_u4": "Ready a weapon for: %s",
		"en_us": "Ready a weapon for: %s",
		"ko": "무기를 장착할 대상: %s",
	},
	"cmd_ready_weapon": {
		"en_u4": "Weapon: ",
		"en_us": "Weapon: ",
		"ko": "무기: ",
	},
	"cmd_ready_done": {
		"en_u4": "%s",
		"en_us": "%s",
		"ko": "%s",
	},
	"cmd_ready_none": {
		"en_u4": "None left!",
		"en_us": "None left!",
		"ko": "남은 무기가 없다!",
	},
	"cmd_ready_restricted": {
		"en_u4": "A %s may NOT use %s %s",
		"en_us": "A %s may NOT use %s %s",
		"ko": "%s은(는) %s을(를) 쓸 수 없다",
	},
	"ready_col_delta": {
		"en_u4": "Δ",
		"en_us": "Δ",
		"ko": "Δ",
	},
	## xu4 wearArmor()
	"cmd_wear_for": {
		"en_u4": "Wear Armour for: ",
		"en_us": "Wear Armour for: ",
		"ko": "갑옷을 장착할 대상: ",
	},
	"cmd_wear_for_done": {
		"en_u4": "Wear Armour for: %s",
		"en_us": "Wear Armour for: %s",
		"ko": "갑옷을 장착할 대상: %s",
	},
	"cmd_wear_armor": {
		"en_u4": "Armour: ",
		"en_us": "Armour: ",
		"ko": "갑옷: ",
	},
	"cmd_wear_done": {
		"en_u4": "%s",
		"en_us": "%s",
		"ko": "%s",
	},
	"cmd_wear_none": {
		"en_u4": "None left!",
		"en_us": "None left!",
		"ko": "남은 갑옷이 없다!",
	},
	"cmd_wear_restricted": {
		"en_u4": "A %s may NOT use %s",
		"en_us": "A %s may NOT use %s",
		"ko": "%s은(는) %s을(를) 쓸 수 없다",
	},
	"cmd_fired": {
		"en_u4": "%s",
		"en_us": "%s",
		"ko": "%s",
	},
	"cmd_starving": {
		"en_u4": "Starving!!!",
		"en_us": "Starving!!!",
		"ko": "굶주린다!!!",
	},
	"cmd_stub": {
		"en_u4": "%s) %s — (not yet implemented)",
		"en_us": "%s) %s — stub (coming soon)",
		"ko": "%s) %s — 아직 미구현",
	},
	"cmd_locate": {
		"en_u4": "%s  %s %s",
		"en_us": "%s  %s %s",
		"ko": "%s  %s %s",
	},
	"cmd_locate_what": {
		"en_u4": "Locate with What?",
		"en_us": "Locate with What?",
		"ko": "Locate with What?",
	},
	"locate_on": {
		"en_u4": "Locate: On",
		"en_us": "Locate: On",
		"ko": "Locate: On",
	},
	"locate_off": {
		"en_u4": "Locate: Off",
		"en_us": "Locate: Off",
		"ko": "Locate: Off",
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
		"ko": "마법 검",
	},
	"item_bow": {
		"en_u4": "Bow",
		"en_us": "Bow",
		"ko": "활",
	},
	"item_magic_axe": {
		"en_u4": "Magic Axe",
		"en_us": "Magic Axe",
		"ko": "마법 도끼",
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
		"ko": "마법봉",
	},
	"item_wand": {
		"en_u4": "Wand",
		"en_us": "Wand",
		"ko": "마법봉",
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
	"ztats_page_equipment": {
		"en_u4": "Equipment",
		"en_us": "Equipment",
		"ko": "장비",
	},
	"ztats_page_weapons": {
		"en_u4": "Weapons",
		"en_us": "Weapons",
		"ko": "무기",
	},
	"ztats_page_armor": {
		"en_u4": "Armour",
		"en_us": "Armor",
		"ko": "갑옷",
	},
	"ztats_page_reagents": {
		"en_u4": "Reagents",
		"en_us": "Reagents",
		"ko": "시약",
	},
	"ztats_page_mixtures": {
		"en_u4": "Mixtures",
		"en_us": "Mixtures",
		"ko": "마법",
	},
	"ztats_col_name": {
		"en_u4": "Name",
		"en_us": "Name",
		"ko": "이름",
	},
	"ztats_col_damage": {
		"en_u4": "Damage",
		"en_us": "Damage",
		"ko": "공격력",
	},
	"ztats_col_defense": {
		"en_u4": "Defense",
		"en_us": "Defense",
		"ko": "방어력",
	},
	"ztats_col_mana": {
		"en_u4": "Mana",
		"en_us": "Mana",
		"ko": "마나",
	},
	"ztats_col_qty": {
		"en_u4": "Qty",
		"en_us": "Qty",
		"ko": "수량",
	},
	"reag_ash": {
		"en_u4": "Sulphurous Ash",
		"en_us": "Sulphurous Ash",
		"ko": "유황재",
	},
	"reag_ginseng": {
		"en_u4": "Ginseng",
		"en_us": "Ginseng",
		"ko": "인삼",
	},
	"reag_garlic": {
		"en_u4": "Garlic",
		"en_us": "Garlic",
		"ko": "마늘",
	},
	"reag_silk": {
		"en_u4": "Spider Silk",
		"en_us": "Spider Silk",
		"ko": "거미줄",
	},
	"reag_moss": {
		"en_u4": "Blood Moss",
		"en_us": "Blood Moss",
		"ko": "피이끼",
	},
	"reag_pearl": {
		"en_u4": "Black Pearl",
		"en_us": "Black Pearl",
		"ko": "흑진주",
	},
	"reag_nightshade": {
		"en_u4": "Nightshade",
		"en_us": "Nightshade",
		"ko": "밤그늘풀",
	},
	"reag_mandrake": {
		"en_u4": "Mandrake Root",
		"en_us": "Mandrake Root",
		"ko": "맨드레이크 뿌리",
	},
}


func t(key: String, args: Array = []) -> String:
	var pack: Dictionary = _T.get(key, {})
	var s: String = str(pack.get(GameState.language, pack.get("en_us", key)))
	if args.is_empty():
		return s
	## Prefer scalar `%` for a single arg — clearer than Array packing.
	if args.size() == 1:
		return s % str(args[0])
	var parts: Array = []
	for a in args:
		parts.append(str(a))
	return s % parts


func need_dir_prompt(cmd_name: String) -> String:
	## "Attack: Dir?" / "공격: 방향?"
	return t("cmd_need_dir", [cmd_name, t("cmd_dir_ask")])


func lang_label(lang_id: String = "") -> String:
	## Human-readable name for a language id (defaults to current).
	var id := lang_id if not lang_id.is_empty() else GameState.language
	match id:
		"en_us":
			return t("lang_en_us")
		"en_u4":
			return t("lang_en_u4")
		"ko":
			return t("lang_ko")
		_:
			return id


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
	## One line: places + upon-table (story screen uses 3-line intro).
	var lang := GameState.language
	if lang != "en_u4" and GameState.intro_overlay.has_gypsy(lang):
		var n := TitleExeData.GYP_PLACES_FIRST
		if round_i == 6:
			n = TitleExeData.GYP_PLACES_LAST
		elif round_i > 0:
			n = TitleExeData.GYP_PLACES_TWOMORE
		return "%s %s" % [
			GameState.intro_overlay.gypsy(lang, n).strip_edges(),
			GameState.intro_overlay.gypsy(lang, TitleExeData.GYP_UPON_TABLE).strip_edges(),
		]
	if GameState.intro_data.loaded:
		return GameState.intro_data.gypsy_lead_for_round(round_i)
	return t("gypsy_lead")


func gypsy_cards_line(v1: int, v2: int) -> String:
	var lang := GameState.language
	var n1 := virtue_card_name(v1)
	var n2 := virtue_card_name(v2)
	if lang == "ko":
		## "%s%s %s — 그녀가 말합니다:" with 와/과 by batchim.
		var fmt := GameState.intro_overlay.cards_line_fmt("ko") if GameState.intro_overlay.loaded else "%s%s %s — 그녀가 말합니다:"
		return fmt % [n1, ko_wa_gwa(n1), n2]
	if lang != "en_u4" and GameState.intro_overlay.loaded:
		return GameState.intro_overlay.cards_line_fmt(lang) % [n1, n2]
	if GameState.intro_data.loaded:
		return GameState.intro_data.gypsy_cards_line(v1, v2)
	return "%s · %s" % [n1, n2]


## Korean particle 와/과 after a noun (batchim → 과, else 와).
func ko_wa_gwa(word: String) -> String:
	var s := word.strip_edges()
	if s.is_empty():
		return "와"
	var ch := s.unicode_at(s.length() - 1)
	## Hangul syllables AC00–D7A3; jongseong index 0 = no batchim.
	if ch < 0xAC00 or ch > 0xD7A3:
		return "와"
	var jong := (ch - 0xAC00) % 28
	return "과" if jong > 0 else "와"


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


const _WEAPON_KEYS := [
	"item_hands", "item_staff", "item_dagger", "item_sling", "item_mace", "item_axe",
	"item_sword", "item_bow", "item_crossbow", "item_flaming_oil", "item_halberd",
	"item_magic_axe", "item_magic_sword", "item_magic_bow", "item_magic_wand", "item_mystic_sword",
]
const _ARMOR_KEYS := [
	"item_no_armor", "item_cloth", "item_leather", "item_chain", "item_plate",
	"item_magic_chain", "item_magic_plate", "item_mystic_robe",
]
const _REAG_KEYS := [
	"reag_ash", "reag_ginseng", "reag_garlic", "reag_silk",
	"reag_moss", "reag_pearl", "reag_nightshade", "reag_mandrake",
]


func weapon_name(weapon_id: int) -> String:
	if weapon_id < 0 or weapon_id >= _WEAPON_KEYS.size():
		return "?"
	return t(_WEAPON_KEYS[weapon_id])


func armor_name(armor_id: int) -> String:
	if armor_id < 0 or armor_id >= _ARMOR_KEYS.size():
		return "?"
	return t(_ARMOR_KEYS[armor_id])


func reagent_name(reag_id: int) -> String:
	if reag_id < 0 or reag_id >= _REAG_KEYS.size():
		return "?"
	return t(_REAG_KEYS[reag_id])


func spell_name(spell_id: int) -> String:
	return _Spells.name_of(spell_id, GameState.lang_short())
