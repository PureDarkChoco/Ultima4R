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
	"boot_path_prompt": {
		"en_u4": "Choose your Ultima IV (DOS) game folder:",
		"en_us": "Choose your Ultima IV (DOS) game folder:",
		"ko": "울티마 IV (DOS) 게임 폴더를 선택하세요:",
	},
	"boot_path_hint": {
		"en_u4": "Folder with WORLD.MAP · or the Ultima IV.app bundle",
		"en_us": "Folder containing WORLD.MAP, or the Ultima IV.app bundle",
		"ko": "WORLD.MAP 이 있는 폴더, 또는 Ultima IV.app 번들",
	},
	"boot_path_reselect": {
		"en_u4": "The configured path no longer hath the game files.\nPlease choose the Ultima IV (DOS) folder again.",
		"en_us": "The configured path is missing game files.\nPlease choose the Ultima IV (DOS) folder again.",
		"ko": "설정된 경로에 게임 파일이 없습니다.\n울티마 IV (DOS) 폴더를 다시 지정해 주세요.",
	},
	"boot_path_choose": {
		"en_u4": "Choose Folder…",
		"en_us": "Choose Folder…",
		"ko": "폴더 선택…",
	},
	"boot_path_select": {
		"en_u4": "Select",
		"en_us": "Select",
		"ko": "선택",
	},
	"boot_path_cancel": {
		"en_u4": "Cancel",
		"en_us": "Cancel",
		"ko": "취소",
	},
	"boot_path_invalid": {
		"en_u4": "That folder hath no WORLD.MAP.",
		"en_us": "WORLD.MAP not found in that folder.",
		"ko": "선택한 폴더에서 WORLD.MAP 을 찾지 못했습니다.",
	},
	"boot_required": {
		"en_u4": "Ultima IV (DOS) is required to play.\nPress any key to quit.",
		"en_us": "Ultima IV (DOS) is required to play.\nPress any key to quit.",
		"ko": "울티마 IV DOS 버전이 필요합니다.\n아무 키나 누르면 종료합니다.",
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
	"esc_options_hangul_keyboard": {
		"en_u4": "Korean Keyboard",
		"en_us": "Korean Keyboard",
		"ko": "한글 자판",
	},
	"hangul_keyboard_2": {
		"en_u4": "Dubeolsik",
		"en_us": "Dubeolsik",
		"ko": "두벌식",
	},
	"hangul_keyboard_39": {
		"en_u4": "Sebeolsik 390",
		"en_us": "Sebeolsik 390",
		"ko": "세벌식 390",
	},
	"hangul_keyboard_3f": {
		"en_u4": "Sebeolsik Final",
		"en_us": "Sebeolsik Final",
		"ko": "세벌식 최종",
	},
	"esc_options_gamepad": {
		"en_u4": "Gamepad",
		"en_us": "Gamepad",
		"ko": "게임패드",
	},
	"esc_options_gamepad_xbox": {
		"en_u4": "XBOX (A / B)",
		"en_us": "XBOX (A / B)",
		"ko": "XBOX (A / B)",
	},
	"esc_options_gamepad_nintendo": {
		"en_u4": "NINTENDO (B / A)",
		"en_us": "NINTENDO (B / A)",
		"ko": "NINTENDO (B / A)",
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
	"menu_licenses": {
		"en_u4": "About",
		"en_us": "About",
		"ko": "정보",
	},
	"licenses_title": {
		"en_u4": "About",
		"en_us": "About",
		"ko": "정보",
	},
	"licenses_close": {
		"en_u4": "Return",
		"en_us": "Return",
		"ko": "돌아가기",
	},
	"quit_confirm": {
		"en_u4": "Really quit?",
		"en_us": "Really quit?",
		"ko": "정말 종료하시겠습니까?",
	},
	"return_menu_confirm": {
		"en_u4": "Return to the title menu?",
		"en_us": "Return to the title menu?",
		"ko": "시작 메뉴로 돌아갈까요?",
	},
	"menu_copyright": {
		"en_u4": "© Copyright 1987 Lord British",
		"en_us": "© Copyright 1987 Lord British",
		"ko": "© Copyright 1987 Lord British",
	},
	"menu_fan_notice": {
		"en_u4": "A fan project 2026",
		"en_us": "A fan project 2026",
		"ko": "팬 프로젝트 2026",
	},
	"menu_version": {
		"en_u4": "ver %s",
		"en_us": "ver %s",
		"ko": "ver %s",
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
	"name_prompt_en": {
		"en_u4": "English name",
		"en_us": "English name",
		"ko": "영어 이름",
	},
	"name_prompt_ko": {
		"en_u4": "Korean name",
		"en_us": "Korean name",
		"ko": "한국어 이름",
	},
	"sex_prompt": {
		"en_u4": "Sex",
		"en_us": "Sex",
		"ko": "성별",
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
		"en_u4": "Name: Enter/click to type · Sex: move then Enter/click · Pad: D-pad + A",
		"en_us": "Name: Enter or click to type · Sex: move then Enter/click · Gamepad D-pad + A",
		"ko": "이름: Enter/클릭으로 입력 · 성별: 이동 후 Enter/클릭 · 패드 D-패드+A",
	},
	"input_hint_menu": {
		"en_u4": "Mouse: click · Keys: ↑↓ Enter · Pad: D-pad + A",
		"en_us": "Mouse click · Arrows/Enter · Gamepad D-pad + A",
		"ko": "마우스 클릭 · 방향키/Enter · 패드 D-패드+A",
	},
	"input_hint_virtue": {
		"en_u4": "Mouse: hover + click · Keys: A/B or ←→ then Enter/Space · Pad: ←→ + A",
		"en_us": "Mouse hover + click · A/B or arrows then Enter/Space · Gamepad left/right + A",
		"ko": "마우스 오버+클릭 · A/B 또는 좌우 이동 후 Enter/Space · 패드 좌우+A",
	},
	"input_hint_world": {
		"en_u4": "Arrows move · A–Z commands · Esc menu · ⌘F fullscreen",
		"en_us": "Arrow keys move · A–Z = commands (not WASD) · Esc menu · ⌘F fullscreen",
		"ko": "방향키 이동 · A–Z 명령키 · Esc 메뉴 · ⌘F 전체화면",
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
	## xu4 combat.cpp beginCombat / gameCreatureAttack
	"cmd_combat": {
		"en_u4": "**** COMBAT ****",
		"en_us": "**** COMBAT ****",
		"ko": "**** 전투 ****",
	},
	"cmd_attacked_by": {
		"en_u4": "Attacked by %s!",
		"en_us": "Attacked by %s!",
		"ko": "%s의 습격!",
	},
	## xu4 combat.cpp keyPressed Space
	"cmd_pass": {
		"en_u4": "Pass",
		"en_us": "Pass",
		"ko": "패스",
	},
	## xu4 CombatController::endCombat — all party fled / wiped from arena
	"cmd_battle_lost": {
		"en_u4": "Battle is lost!",
		"en_us": "Battle is lost!",
		"ko": "전투에서 패배했다!",
	},
	## xu4 CombatController::endCombat — all foes slain
	"cmd_victory": {
		"en_u4": "Victory!",
		"en_us": "Victory!",
		"ko": "승리!",
	},
	## Victory aftermath: Esc exits the whole party at once (not edge-flee).
	"cmd_escape": {
		"en_u4": "Escape",
		"en_us": "Escape",
		"ko": "탈출",
	},
	"cmd_leave_battle_confirm": {
		"en_u4": "Leave the battlefield?",
		"en_us": "Leave the battlefield?",
		"ko": "전장에서 나가겠습니까?",
	},
	## xu4 combat attack miss / kill
	"cmd_missed": {
		"en_u4": "Missed!",
		"en_us": "Missed!",
		"ko": "빗나갔다!",
	},
	"cmd_killed": {
		"en_u4": "%s killed!",
		"en_us": "%s killed!",
		"ko": "%s 처치!",
	},
	"cmd_foe_flees": {
		"en_u4": "%s Flees!",
		"en_us": "%s Flees!",
		"ko": "%s 도망친다!",
	},
	"cmd_combat_sleep": {
		"en_u4": "Sleep!",
		"en_us": "Sleep!",
		"ko": "수면!",
	},
	"cmd_poisoned": {
		"en_u4": "Poisoned!",
		"en_us": "Poisoned!",
		"ko": "중독!",
	},
	"cmd_attack_aim": {
		"en_u4": "Aim: ",
		"en_us": "Aim: ",
		"ko": "조준: ",
	},
	"cmd_cannot_attack": {
		"en_u4": "Cannot!",
		"en_us": "Cannot!",
		"ko": "공격 불가!",
	},
	"cmd_last_one": {
		"en_u4": "Last One!",
		"en_us": "Last One!",
		"ko": "마지막 하나!",
	},
	"cmd_attack_with": {
		"en_u4": "%s with %s",
		"en_us": "%s with %s",
		"ko": "%s — %s",
	},
	"cmd_jimmy_what": {
		"en_u4": "Jimmy what?",
		"en_us": "Jimmy what?",
		"ko": "무엇의 자물쇠를?",
	},
	"cmd_unlocked": {
		"en_u4": "Unlocked!",
		"en_us": "Unlocked!",
		"ko": "잠금이 풀렸다!",
	},
	"cmd_no_keys": {
		"en_u4": "No keys left!",
		"en_us": "No keys left!",
		"ko": "열쇠가 없다!",
	},
	"cmd_not_here": {
		"en_u4": "Not here!",
		"en_us": "Not here!",
		"ko": "여기서는 안 된다!",
	},
	"cmd_only_on_foot": {
		"en_u4": "Only on foot!",
		"en_us": "Only on foot!",
		"ko": "도보로만 가능하다!",
	},
	"cmd_klimb_what": {
		"en_u4": "Klimb what?",
		"en_us": "Klimb what?",
		"ko": "어디로 올라가?",
	},
	"cmd_descend_what": {
		"en_u4": "Descend what?",
		"en_us": "Descend what?",
		"ko": "어디로 내려가?",
	},
	## xu4 balloon Klimb / Land Balloon (Descend).
	"cmd_klimb_altitude": {
		"en_u4": "Klimb altitude",
		"en_us": "Klimb altitude",
		"ko": "고도를 올린다",
	},
	"cmd_land_balloon": {
		"en_u4": "Land Balloon",
		"en_us": "Land Balloon",
		"ko": "열기구 착륙",
	},
	"cmd_already_landed": {
		"en_u4": "Already Landed!",
		"en_us": "Already Landed!",
		"ko": "이미 착륙했다!",
	},
	"cmd_drift_only": {
		"en_u4": "Drift Only!",
		"en_us": "Drift Only!",
		"ko": "표류만 가능!",
	},
	"cmd_klimb_lcb2": {
		"en_u4": "Klimb to second floor!",
		"en_us": "Klimb to second floor!",
		"ko": "2층으로 올라간다!",
	},
	"cmd_descend_lcb1": {
		"en_u4": "Descend to first floor!",
		"en_us": "Descend to first floor!",
		"ko": "1층으로 내려간다!",
	},
	"cmd_enter_what": {
		"en_u4": "Enter what?",
		"en_us": "Enter what?",
		"ko": "어디에 들어가나?",
	},
	"cmd_enter_confirm": {
		"en_u4": "Enter %s?",
		"en_us": "Enter %s?",
		"ko": "%s로 들어가겠습니까?",
	},
	"cmd_enter_type": {
		"en_u4": "Enter %s!",
		"en_us": "Enter %s!",
		"ko": "%s에 들어간다!",
	},
	"cmd_enter_fail": {
		"en_u4": "Enter failed!",
		"en_us": "Could not load that map.",
		"ko": "지도를 열 수 없다!",
	},
	"cmd_exit_city": {
		"en_u4": "Leaving...",
		"en_us": "Leaving...",
		"ko": "떠난다...",
	},
	"city_kind_castle": {
		"en_u4": "castle",
		"en_us": "castle",
		"ko": "성",
	},
	"city_kind_towne": {
		"en_u4": "towne",
		"en_us": "town",
		"ko": "마을",
	},
	"city_kind_village": {
		"en_u4": "village",
		"en_us": "village",
		"ko": "촌락",
	},
	"city_kind_ruins": {
		"en_u4": "ruins",
		"en_us": "ruins",
		"ko": "폐허",
	},
	"city_kind_dungeon": {
		"en_u4": "dungeon",
		"en_us": "dungeon",
		"ko": "던전",
	},
	"cmd_enter_shrine": {
		"en_u4": "Enter shrine!",
		"en_us": "Enter shrine!",
		"ko": "사원에 들어간다!",
	},
	"cmd_shrine_no_rune": {
		"en_u4": "Thou dost not bear the rune of entry!  A strange force keeps you out!",
		"en_us": "You don't have the rune of entry! A strange force keeps you out!",
		"ko": "입장의 룬을 지니지 않았다! 이상한 힘이 막는다!",
	},
	"cmd_shrine_sit": {
		"en_u4": "You enter the ancient shrine and sit before the altar...",
		"en_us": "You enter the ancient shrine and sit before the altar...",
		"ko": "고대 사원에 들어가 제단 앞에 앉는다...",
	},
	"cmd_shrine_approach": {
		"en_u4": "You approach the ancient shrine...",
		"en_us": "You approach the ancient shrine...",
		"ko": "고대 사원에 다가간다...",
	},
	"cmd_shrine_kneel": {
		"en_u4": "...and kneel before the altar.",
		"en_us": "...and kneel before the altar.",
		"ko": "...그리고 제단 앞에 무릎을 꿇는다.",
	},
	"cmd_shrine_virtue_ask": {
		"en_u4": "Upon which virtue dost thou meditate?",
		"en_us": "Upon which virtue do you meditate?",
		"ko": "어느 미덕에 명상하겠는가?",
	},
	"cmd_shrine_cycles_ask": {
		"en_u4": "For how many Cycles (0-3)?",
		"en_us": "For how many Cycles (0-3)?",
		"ko": "몇 주기 명상할까 (0-3)?",
	},
	"cmd_shrine_unfocused": {
		"en_u4": "Thou art unable to focus thy thoughts on this subject!",
		"en_us": "You cannot focus your thoughts on this subject!",
		"ko": "이 주제에 생각을 모을 수가 없다!",
	},
	"cmd_shrine_weary": {
		"en_u4": "Thy mind is still weary from thy last Meditation!",
		"en_us": "Your mind is still weary from your last meditation!",
		"ko": "지난 명상의 피로가 아직 남아 있다!",
	},
	"cmd_shrine_begin": {
		"en_u4": "Begin Meditation",
		"en_us": "Begin Meditation",
		"ko": "명상을 시작한다",
	},
	"cmd_shrine_mantra": {
		"en_u4": "Mantra:",
		"en_us": "Mantra:",
		"ko": "만트라:",
	},
	"cmd_shrine_bad_mantra": {
		"en_u4": "Thou art not able to focus thy thoughts with that Mantra!",
		"en_us": "You cannot focus your thoughts with that mantra!",
		"ko": "그 만트라로는 생각을 모을 수 없다!",
	},
	"cmd_shrine_partial": {
		"en_u4": "Thou hast achieved partial Avatarhood in the Virtue of %s",
		"en_us": "You have achieved partial Avatarhood in the Virtue of %s",
		"ko": "%s의 미덕에서 부분 아바타가 되었다",
	},
	"cmd_shrine_vision": {
		"en_u4": "Thy thoughts are pure. Thou art granted a vision!",
		"en_us": "Your thoughts are pure. You are granted a vision!",
		"ko": "생각이 맑다. 환영이 주어진다!",
	},
	"cmd_shrine_vision_elevated": {
		"en_u4": "Thou art granted a vision!",
		"en_us": "You are granted a vision!",
		"ko": "환영이 주어진다!",
	},
	"cmd_inn_morning": {
		"en_u4": "Morning!",
		"en_us": "Morning!",
		"ko": "아침이 밝았다!",
	},
	"cmd_inn_ambush_stroll": {
		"en_u4": "In the middle of the night while out on a stroll...",
		"en_us": "In the middle of the night while out on a stroll...",
		"ko": "한밤중, 산책을 나선 사이에...",
	},
	"cmd_hole_up": {
		"en_u4": "Hole up & Camp!",
		"en_us": "Hole up & Camp!",
		"ko": "야영한다!",
	},
	"cmd_camp_resting": {
		"en_u4": "Resting...",
		"en_us": "Resting...",
		"ko": "휴식 중...",
	},
	"cmd_camp_healed": {
		"en_u4": "Party Healed!",
		"en_us": "Party Healed!",
		"ko": "파티가 회복했다!",
	},
	"cmd_camp_no_effect": {
		"en_u4": "No effect.",
		"en_us": "No effect.",
		"ko": "효과가 없다.",
	},
	"cmd_camp_ambushed": {
		"en_u4": "Ambushed!",
		"en_us": "Ambushed!",
		"ko": "기습당했다!",
	},
	"cmd_bridge_trolls": {
		"en_u4": "Bridge Trolls!",
		"en_us": "Bridge Trolls!",
		"ko": "다리 트롤이다!",
	},
	"cmd_camp_set_watch": {
		"en_u4": "Set a watch?",
		"en_us": "Set a watch?",
		"ko": "경비를 세울까?",
	},
	"cmd_camp_who_guards": {
		"en_u4": "Who will guard?",
		"en_us": "Who will guard?",
		"ko": "누가 경비할까?",
	},
	"cmd_camp_guard_named": {
		"en_u4": "%s guards.",
		"en_us": "%s stands watch.",
		"ko": "%s이(가) 경비한다.",
	},
	"cmd_set_active_none": {
		"en_u4": "Set Active Player: None!",
		"en_us": "Set Active Player: None!",
		"ko": "단독 조작: 해제!",
	},
	"cmd_set_active_player": {
		"en_u4": "Set Active Player: %s!",
		"en_us": "Set Active Player: %s!",
		"ko": "단독 조작: %s!",
	},
	"cmd_set_active_disabled": {
		"en_u4": "Disabled!",
		"en_us": "Disabled!",
		"ko": "행동 불가!",
	},
	"cmd_who": {
		"en_u4": "Who?",
		"en_us": "Who?",
		"ko": "누구?",
	},
	"cmd_cant": {
		"en_u4": "Can't!",
		"en_us": "Can't!",
		"ko": "불가!",
	},
	"cmd_quit_save": {
		"en_u4": "Quit & Save...",
		"en_us": "Quit & Save...",
		"ko": "저장 후 종료...",
	},
	"cmd_quit_moves": {
		"en_u4": "%s moves",
		"en_us": "%s moves",
		"ko": "%s 턴",
	},
	"cmd_quit_not_saved": {
		"en_u4": "Not saved yet.",
		"en_us": "Save not wired yet.",
		"ko": "아직 저장되지 않았다.",
	},
	"cmd_saved": {
		"en_u4": "Saved.",
		"en_us": "Game saved.",
		"ko": "저장했다.",
	},
	"cmd_quick_saved": {
		"en_u4": "Saved to slot %d.",
		"en_us": "Saved to slot %d.",
		"ko": "%d번 슬롯에 저장 했다.",
	},
	"cmd_save_failed": {
		"en_u4": "Save failed!",
		"en_us": "Save failed!",
		"ko": "저장 실패!",
	},
	"save_title": {
		"en_u4": "Save Game",
		"en_us": "Save Game",
		"ko": "게임 저장",
	},
	"save_hint": {
		"en_u4": "↑↓ + Enter, or 1–4. Esc cancels.",
		"en_us": "↑↓ + Enter, or 1–4. Esc cancels.",
		"ko": "↑↓ + Enter, 또는 1–4. Esc 취소.",
	},
	"load_title": {
		"en_u4": "Load Game",
		"en_us": "Load Game",
		"ko": "게임 불러오기",
	},
	"load_hint": {
		"en_u4": "↑↓ + Enter, or 1–4. Del deletes. Esc cancels.",
		"en_us": "↑↓ + Enter, or 1–4. Del deletes. Esc cancels.",
		"ko": "↑↓ + Enter, 또는 1–4. Del 삭제. Esc 취소.",
	},
	"load_empty": {
		"en_u4": "Empty!",
		"en_us": "That slot is empty.",
		"ko": "빈 슬롯이다!",
	},
	"load_none": {
		"en_u4": "No saved games.",
		"en_us": "No saved games.",
		"ko": "저장된 게임이 없다.",
	},
	"load_delete_confirm": {
		"en_u4": "Delete this saved game?\nA deleted game cannot be restored.",
		"en_us": "Delete this saved game?\nDeleted games cannot be recovered.",
		"ko": "저장된 게임을 삭제하겠습니까?\n삭제한 게임은 복구할 수 없습니다.",
	},
	"load_deleted": {
		"en_u4": "Save deleted.",
		"en_us": "Save deleted.",
		"ko": "저장을 삭제했다.",
	},
	"esc_menu_title": {
		"en_u4": "Menu",
		"en_us": "Menu",
		"ko": "메뉴",
	},
	"esc_menu_hint": {
		"en_u4": "↑↓ + Enter. Esc closes.",
		"en_us": "↑↓ + Enter. Esc closes.",
		"ko": "↑↓ + Enter. Esc 닫기.",
	},
	"esc_menu_save": {
		"en_u4": "Save Game",
		"en_us": "Save Game",
		"ko": "게임 저장",
	},
	"esc_menu_load": {
		"en_u4": "Load Game",
		"en_us": "Load Game",
		"ko": "게임 불러오기",
	},
	"esc_menu_return": {
		"en_u4": "Return to Menu",
		"en_us": "Return to Menu",
		"ko": "시작 메뉴로",
	},
	"esc_menu_option": {
		"en_u4": "Option",
		"en_us": "Options",
		"ko": "옵션",
	},
	"esc_menu_quit": {
		"en_u4": "Quit",
		"en_us": "Quit",
		"ko": "종료",
	},
	"esc_options_title": {
		"en_u4": "Options",
		"en_us": "Options",
		"ko": "옵션",
	},
	"esc_options_resolution": {
		"en_u4": "Resolution",
		"en_us": "Resolution",
		"ko": "해상도",
	},
	"esc_options_resolution_windowed": {
		"en_u4": "%d%% · %d×%d",
		"en_us": "%d%% · %d×%d",
		"ko": "%d%% · %d×%d",
	},
	"esc_options_resolution_set": {
		"en_u4": "Window: %d%% (%d×%d)",
		"en_us": "Window: %d%% (%d×%d)",
		"ko": "창 모드: %d%% (%d×%d)",
	},
	"esc_options_fullscreen": {
		"en_u4": "Fullscreen",
		"en_us": "Fullscreen",
		"ko": "전체화면",
	},
	"esc_options_fullscreen_state_on": {
		"en_u4": "On (⌘F)",
		"en_us": "On (⌘F)",
		"ko": "켜짐 (⌘F)",
	},
	"esc_options_fullscreen_state_off": {
		"en_u4": "Off (⌘F)",
		"en_us": "Off (⌘F)",
		"ko": "꺼짐 (⌘F)",
	},
	"esc_options_fullscreen_on": {
		"en_u4": "Fullscreen on",
		"en_us": "Fullscreen on",
		"ko": "전체화면 켜짐",
	},
	"esc_options_fullscreen_off": {
		"en_u4": "Fullscreen off",
		"en_us": "Fullscreen off",
		"ko": "전체화면 꺼짐",
	},
	"esc_options_sfx": {
		"en_u4": "Sound",
		"en_us": "Sound Effects",
		"ko": "효과음",
	},
	"esc_options_music": {
		"en_u4": "Music",
		"en_us": "Background Music",
		"ko": "배경음악",
	},
	"esc_options_music_volume": {
		"en_u4": "%d%%",
		"en_us": "%d%%",
		"ko": "%d%%",
	},
	"esc_options_state_on": {
		"en_u4": "On",
		"en_us": "On",
		"ko": "켬",
	},
	"esc_options_state_off": {
		"en_u4": "Off",
		"en_us": "Off",
		"ko": "끔",
	},
	"esc_menu_language_set": {
		"en_u4": "Language: %s",
		"en_us": "Language: %s",
		"ko": "언어: %s",
	},
	"save_slot_empty": {
		"en_u4": "%s: (Empty)",
		"en_us": "%s: (Empty)",
		"ko": "%s: (비어 있음)",
	},
	"save_slot_empty_short": {
		"en_u4": "(Empty)",
		"en_us": "(Empty)",
		"ko": "(비어 있음)",
	},
	"save_slot_used": {
		"en_u4": "%s: %s — %s moves",
		"en_us": "%s: %s — %s moves",
		"ko": "%s: %s — %s 턴",
	},
	"save_slot_moves": {
		"en_u4": "%s moves",
		"en_us": "%s moves",
		"ko": "%s 턴",
	},
	"save_slot_moves_when": {
		"en_u4": "%s moves  ·  %s  ·  %s",
		"en_us": "%s moves  ·  %s  ·  %s",
		"ko": "%s 턴  ·  %s  ·  %s",
	},
	"save_slot_moves_when_noloc": {
		"en_u4": "%s moves  ·  %s",
		"en_us": "%s moves  ·  %s",
		"ko": "%s 턴  ·  %s",
	},
	"save_loc_near": {
		"en_u4": "Near %s",
		"en_us": "Near %s",
		"ko": "%s 근처",
	},
	"save_loc_in": {
		"en_u4": "In %s",
		"en_us": "In %s",
		"ko": "%s",
	},
	"save_loc_dungeon": {
		"en_u4": "In %s Lv.%s",
		"en_us": "In %s Lv.%s",
		"ko": "%s %s층",
	},
	"save_loc_sea": {
		"en_u4": "On the Sea",
		"en_us": "On the Sea",
		"ko": "바다 위",
	},
	"save_loc_britannia": {
		"en_u4": "On the Britannia",
		"en_us": "On the Britannia",
		"ko": "브리타니아",
	},
	"journal_title": {
		"en_u4": "Journal",
		"en_us": "Journal",
		"ko": "여행 기록",
	},
	"journal_empty": {
		"en_u4": "No notes yet.",
		"en_us": "No notes yet.",
		"ko": "아직 기록이 없다.",
	},
	"journal_hide_done": {
		"en_u4": "Hide done",
		"en_us": "Hide completed",
		"ko": "완료 숨김",
	},
	"journal_page_mark": {
		"en_u4": "%d / %d",
		"en_us": "%d / %d",
		"ko": "%d / %d",
	},
	"journal_codex_cities": {
		"en_u4": "Cities",
		"en_us": "Cities",
		"ko": "도시",
	},
	"journal_codex_virtues": {
		"en_u4": "Virtues",
		"en_us": "Virtues",
		"ko": "미덕",
	},
	"journal_codex_principles": {
		"en_u4": "Principles",
		"en_us": "Principles",
		"ko": "원리",
	},
	"journal_codex_dungeons": {
		"en_u4": "Dungeons",
		"en_us": "Dungeons",
		"ko": "던전",
	},
	"journal_codex_mantras": {
		"en_u4": "Mantras",
		"en_us": "Mantras",
		"ko": "만트라",
	},
	"journal_codex_runes": {
		"en_u4": "Runes",
		"en_us": "Runes",
		"ko": "룬",
	},
	"journal_codex_stones": {
		"en_u4": "Stones",
		"en_us": "Stones",
		"ko": "돌",
	},
	"journal_codex_keys": {
		"en_u4": "Keys",
		"en_us": "Keys",
		"ko": "열쇠",
	},
	"journal_codex_relics": {
		"en_u4": "Relics",
		"en_us": "Relics",
		"ko": "유물",
	},
	"journal_codex_bell": {
		"en_u4": "Bell",
		"en_us": "Bell",
		"ko": "종",
	},
	"journal_codex_book": {
		"en_u4": "Book",
		"en_us": "Book",
		"ko": "책",
	},
	"journal_codex_candle": {
		"en_u4": "Candle",
		"en_us": "Candle",
		"ko": "촛대",
	},
	"journal_codex_stone_blue": {
		"en_u4": "Blue",
		"en_us": "Blue",
		"ko": "파란",
	},
	"journal_codex_stone_yellow": {
		"en_u4": "Yellow",
		"en_us": "Yellow",
		"ko": "노란",
	},
	"journal_codex_stone_red": {
		"en_u4": "Red",
		"en_us": "Red",
		"ko": "빨간",
	},
	"journal_codex_stone_green": {
		"en_u4": "Green",
		"en_us": "Green",
		"ko": "초록",
	},
	"journal_codex_stone_orange": {
		"en_u4": "Orange",
		"en_us": "Orange",
		"ko": "주황",
	},
	"journal_codex_stone_purple": {
		"en_u4": "Purple",
		"en_us": "Purple",
		"ko": "보라",
	},
	"journal_codex_stone_white": {
		"en_u4": "White",
		"en_us": "White",
		"ko": "하얀",
	},
	"journal_codex_stone_black": {
		"en_u4": "Black",
		"en_us": "Black",
		"ko": "검은",
	},
	"journal_codex_truth": {
		"en_u4": "Truth",
		"en_us": "Truth",
		"ko": "진리",
	},
	"journal_codex_love": {
		"en_u4": "Love",
		"en_us": "Love",
		"ko": "사랑",
	},
	"journal_codex_courage": {
		"en_u4": "Courage",
		"en_us": "Courage",
		"ko": "용기",
	},
	## Official names. Prose uses {lcb} / {britain} / … via fill_places(); land "Britannia" is not a token.
	"place_britannia": {
		"en_u4": "Britannia",
		"en_us": "Britannia",
		"ko": "브리타니아",
	},
	"place_lcb": {
		"en_u4": "Britannia Castle",
		"en_us": "Britannia Castle",
		"ko": "브리타니아 성",
	},
	"place_britain": {
		"en_u4": "Britain",
		"en_us": "Britain",
		"ko": "브리튼",
	},
	"place_yew": {
		"en_u4": "Yew",
		"en_us": "Yew",
		"ko": "유",
	},
	"place_paws": {
		"en_u4": "Paws",
		"en_us": "Paws",
		"ko": "포우즈",
	},
	"place_trinsic": {
		"en_u4": "Trinsic",
		"en_us": "Trinsic",
		"ko": "트린식",
	},
	"place_moonglow": {
		"en_u4": "Moonglow",
		"en_us": "Moonglow",
		"ko": "문글로우",
	},
	"place_jhelom": {
		"en_u4": "Jhelom",
		"en_us": "Jhelom",
		"ko": "젤롬",
	},
	"place_minoc": {
		"en_u4": "Minoc",
		"en_us": "Minoc",
		"ko": "미녹",
	},
	"place_skara": {
		"en_u4": "Skara Brae",
		"en_us": "Skara Brae",
		"ko": "스카라 브레이",
	},
	"place_magincia": {
		"en_u4": "Magincia",
		"en_us": "Magincia",
		"ko": "마진시아",
	},
	"place_den": {
		"en_u4": "Buccaneers Den",
		"en_us": "Buccaneers Den",
		"ko": "해적굴",
	},
	"place_vesper": {
		"en_u4": "Vesper",
		"en_us": "Vesper",
		"ko": "베스퍼",
	},
	"place_cove": {
		"en_u4": "Cove",
		"en_us": "Cove",
		"ko": "코브",
	},
	"place_lycaeum": {
		"en_u4": "Lycaeum",
		"en_us": "Lycaeum",
		"ko": "라이시엄",
	},
	"place_empath": {
		"en_u4": "Empath Abbey",
		"en_us": "Empath Abbey",
		"ko": "엠패스 수도원",
	},
	"place_serpent": {
		"en_u4": "Serpents Hold",
		"en_us": "Serpents Hold",
		"ko": "서펀츠 홀드",
	},
	"place_shame": {
		"en_u4": "Shame",
		"en_us": "Shame",
		"ko": "수치",
	},
	"place_wrong": {
		"en_u4": "Wrong",
		"en_us": "Wrong",
		"ko": "부정",
	},
	"place_deceit": {
		"en_u4": "Deceit",
		"en_us": "Deceit",
		"ko": "기만",
	},
	"place_despise": {
		"en_u4": "Despise",
		"en_us": "Despise",
		"ko": "경멸",
	},
	"place_destard": {
		"en_u4": "Destard",
		"en_us": "Destard",
		"ko": "데스타드",
	},
	"place_covetous": {
		"en_u4": "Covetous",
		"en_us": "Covetous",
		"ko": "탐욕",
	},
	"place_hythloth": {
		"en_u4": "Hythloth",
		"en_us": "Hythloth",
		"ko": "히슬로스",
	},
	"place_abyss": {
		"en_u4": "the Abyss",
		"en_us": "the Abyss",
		"ko": "심연",
	},
	"cmd_yes": {
		"en_u4": "Yes",
		"en_us": "Yes",
		"ko": "예",
	},
	"cmd_no": {
		"en_u4": "No",
		"en_us": "No",
		"ko": "아니오",
	},
	"cmd_buy": {
		"en_u4": "Buy",
		"en_us": "Buy",
		"ko": "구매",
	},
	"cmd_sell": {
		"en_u4": "Sell",
		"en_us": "Sell",
		"ko": "판매",
	},
	"shop_heal_cure": {
		"en_u4": "Curing",
		"en_us": "Curing",
		"ko": "해독",
	},
	"shop_heal_heal": {
		"en_u4": "Healing",
		"en_us": "Healing",
		"ko": "치유",
	},
	"shop_heal_resurrect": {
		"en_u4": "Resurrection",
		"en_us": "Resurrection",
		"ko": "부활",
	},
	"shop_tavern_food": {
		"en_u4": "Food",
		"en_us": "Food",
		"ko": "음식",
	},
	"shop_tavern_ale": {
		"en_u4": "Ale",
		"en_us": "Ale",
		"ko": "에일",
	},
	"shop_guild_heard_d": {
		"en_u4": "I heard tell of an item D.",
		"en_us": "I heard there is an item D.",
		"ko": "D 물건이 있다고 들었습니다",
	},
	"cmd_nothing_to_open": {
		"en_u4": "Not Here!",
		"en_us": "Not Here!",
		"ko": "열 것이 없다!",
	},
	"cmd_opened": {
		"en_u4": "Opened!",
		"en_us": "Opened!",
		"ko": "열렸다!",
	},
	"cmd_chest_already_open": {
		"en_u4": "Already open!",
		"en_us": "Already opened.",
		"ko": "이미 열렸습니다.",
	},
	"cmd_chest_empty": {
		"en_u4": "The chest is empty!",
		"en_us": "The chest is empty.",
		"ko": "상자가 비어 있다.",
	},
	## xu4 getChest — "Who opens?"
	"cmd_chest_who_opens": {
		"en_u4": "Who opens?",
		"en_us": "Who opens?",
		"ko": "누가 열까?",
	},
	## xu4 getChest / getChestTrapHandler
	"cmd_chest_holds": {
		"en_u4": "The Chest Holds: %d Gold",
		"en_us": "The chest holds: %d gold.",
		"ko": "상자 속: 골드 %d",
	},
	"cmd_chest_holds_food": {
		"en_u4": "The Chest Holds: Food %d",
		"en_us": "The chest holds: %d food.",
		"ko": "상자 속: 식량 %d",
	},
	"cmd_chest_holds_weapon": {
		"en_u4": "The Chest Holds: %s",
		"en_us": "The chest holds: %s.",
		"ko": "상자 속: %s",
	},
	"cmd_chest_holds_armor": {
		"en_u4": "The Chest Holds: %s",
		"en_us": "The chest holds: %s.",
		"ko": "상자 속: %s",
	},
	"cmd_chest_holds_torch": {
		"en_u4": "The Chest Holds: Torch x%d",
		"en_us": "The chest holds: torch x%d.",
		"ko": "상자 속: 횃불 x%d",
	},
	"cmd_chest_holds_key": {
		"en_u4": "The Chest Holds: Key x%d",
		"en_us": "The chest holds: key x%d.",
		"ko": "상자 속: 열쇠 x%d",
	},
	"cmd_chest_holds_gem": {
		"en_u4": "The Chest Holds: Gem x%d",
		"en_us": "The chest holds: gem x%d.",
		"ko": "상자 속: 보석 x%d",
	},
	"cmd_get_silk": {
		"en_u4": "Spider Silk x%d",
		"en_us": "Spider silk x%d.",
		"ko": "거미줄 x%d",
	},
	"cmd_chest_holds_silk": {
		"en_u4": "The Chest Holds: Spider Silk x%d",
		"en_us": "The chest holds: spider silk x%d.",
		"ko": "상자 속: 거미줄 x%d",
	},
	"cmd_chest_holds_reagent": {
		"en_u4": "The Chest Holds: %s x%d",
		"en_us": "The chest holds: %s x%d.",
		"ko": "상자 속: %s x%d",
	},
	"cmd_chest_trap_acid": {
		"en_u4": "Acid Trap!",
		"en_us": "Acid trap!",
		"ko": "산성 함정!",
	},
	"cmd_chest_trap_poison": {
		"en_u4": "Poison Trap!",
		"en_us": "Poison trap!",
		"ko": "독 함정!",
	},
	"cmd_chest_trap_sleep": {
		"en_u4": "Sleep Trap!",
		"en_us": "Sleep trap!",
		"ko": "수면 함정!",
	},
	"cmd_chest_trap_bomb": {
		"en_u4": "Bomb Trap!",
		"en_us": "Bomb trap!",
		"ko": "폭탄 함정!",
	},
	"cmd_chest_trap_evaded": {
		"en_u4": "Evaded!",
		"en_us": "Evaded!",
		"ko": "피했다!",
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
	## xu4 fire() — printed before "Dir: Dir?"
	"cmd_fire_cannon": {
		"en_u4": "Fire Cannon!",
		"en_us": "Fire Cannon!",
		"ko": "함포 발사!",
	},
	## Prompt label so need_dir_prompt → "Dir: Dir?" (xu4 fire).
	"cmd_fire_dir": {
		"en_u4": "Dir",
		"en_us": "Dir",
		"ko": "방향",
	},
	"cmd_broadsides_only": {
		"en_u4": "Broadsides Only!",
		"en_us": "Broadsides Only!",
		"ko": "좌우현만 가능!",
	},
	"cmd_ship_sinks": {
		"en_u4": "Thy ship sinks!",
		"en_us": "Your ship sinks!",
		"ko": "배가 가라앉는다!",
	},
	## xu4 death.cpp — party wipe sequence (DeathController).
	"death_all_is_dark": {
		"en_u4": "All is Dark...",
		"en_us": "All is Dark...",
		"ko": "모든 것이 어둡다...",
	},
	"death_but_wait": {
		"en_u4": "But wait...",
		"en_us": "But wait...",
		"ko": "그런데...",
	},
	"death_where_am_i": {
		"en_u4": "Where am I?...",
		"en_us": "Where am I?...",
		"ko": "여긴 어디지?...",
	},
	"death_am_i_dead": {
		"en_u4": "Am I dead?...",
		"en_us": "Am I dead?...",
		"ko": "내가 죽은 건가?...",
	},
	"death_afterlife": {
		"en_u4": "Afterlife?...",
		"en_us": "Afterlife?...",
		"ko": "저승인가?...",
	},
	"death_you_hear": {
		"en_u4": "You hear:",
		"en_us": "You hear:",
		"ko": "목소리가 들린다:",
	},
	"death_i_feel_motion": {
		"en_u4": "I feel motion...",
		"en_us": "I feel motion...",
		"ko": "움직임이 느껴진다...",
	},
	"death_lord_british": {
		"en_u4": "Lord British says: I have pulled thy spirit and some possessions from the void.  Be more careful in the future!",
		"en_us": "Lord British says: I have pulled your spirit and some possessions from the void.  Be more careful in the future!",
		"ko": "로드 브리티시가 말한다: 허공에서 그대의 영혼과 일부 소지품을 끌어냈다. 앞으로는 더 조심하라!",
	},
	## xu4 Search (S) — game.cpp / item.cpp
	"cmd_searching": {
		"en_u4": "Searching...",
		"en_us": "Searching...",
		"ko": "수색 중...",
	},
	"cmd_search_nothing": {
		"en_u4": "Nothing Here!",
		"en_us": "Nothing Here!",
		"ko": "아무것도 없다!",
	},
	"cmd_search_find": {
		"en_u4": "You find...",
		"en_us": "You find...",
		"ko": "발견했다...",
	},
	"cmd_search_find_name": {
		"en_u4": "%s!",
		"en_us": "%s!",
		"ko": "%s!",
	},
	"cmd_search_dropped": {
		"en_u4": "Dropped some!",
		"en_us": "Dropped some!",
		"ko": "일부를 버렸다!",
	},
	"cmd_search_drift": {
		"en_u4": "Drift only!",
		"en_us": "Drift only!",
		"ko": "표류만 가능!",
	},
	"cmd_telescope_knob1": {
		"en_u4": "You see a knob",
		"en_us": "You see a knob",
		"ko": "손잡이가 보인다",
	},
	"cmd_telescope_knob2": {
		"en_u4": "on the telescope",
		"en_us": "on the telescope",
		"ko": "망원경 위에",
	},
	"cmd_telescope_knob3": {
		"en_u4": "marked A-P",
		"en_us": "marked A-P",
		"ko": "A-P라고 적혀 있다",
	},
	"cmd_telescope_select": {
		"en_u4": "You Select:",
		"en_us": "You Select:",
		"ko": "선택:",
	},
	"search_item_mandrake": {
		"en_u4": "Mandrake Root",
		"en_us": "Mandrake Root",
		"ko": "맨드레이크 뿌리",
	},
	"search_item_nightshade": {
		"en_u4": "Nightshade",
		"en_us": "Nightshade",
		"ko": "밤그늘풀",
	},
	"search_item_bell": {
		"en_u4": "the Bell of Courage",
		"en_us": "the Bell of Courage",
		"ko": "용기의 종",
	},
	"search_item_book": {
		"en_u4": "the Book of Truth",
		"en_us": "the Book of Truth",
		"ko": "진리의 책",
	},
	"search_item_candle": {
		"en_u4": "the Candle of Love",
		"en_us": "the Candle of Love",
		"ko": "사랑의 촛대",
	},
	"search_item_horn": {
		"en_u4": "A Silver Horn",
		"en_us": "A Silver Horn",
		"ko": "은빛 뿔피리",
	},
	"search_item_wheel": {
		"en_u4": "the Wheel from the H.M.S. Cape",
		"en_us": "the Wheel from the H.M.S. Cape",
		"ko": "H.M.S. 케이프의 키",
	},
	"search_item_skull": {
		"en_u4": "the Skull of Modain the Wizard",
		"en_us": "the Skull of Modain the Wizard",
		"ko": "마법사 모데인의 해골",
	},
	"search_item_stone_red": {
		"en_u4": "the Red Stone",
		"en_us": "the Red Stone",
		"ko": "빨간 돌",
	},
	"search_item_stone_orange": {
		"en_u4": "the Orange Stone",
		"en_us": "the Orange Stone",
		"ko": "주황 돌",
	},
	"search_item_stone_yellow": {
		"en_u4": "the Yellow Stone",
		"en_us": "the Yellow Stone",
		"ko": "노란 돌",
	},
	"search_item_stone_green": {
		"en_u4": "the Green Stone",
		"en_us": "the Green Stone",
		"ko": "초록 돌",
	},
	"search_item_stone_blue": {
		"en_u4": "the Blue Stone",
		"en_us": "the Blue Stone",
		"ko": "파란 돌",
	},
	"search_item_stone_purple": {
		"en_u4": "the Purple Stone",
		"en_us": "the Purple Stone",
		"ko": "보라 돌",
	},
	"search_item_stone_black": {
		"en_u4": "the Black Stone",
		"en_us": "the Black Stone",
		"ko": "검은 돌",
	},
	"search_item_stone_white": {
		"en_u4": "the White Stone",
		"en_us": "the White Stone",
		"ko": "하얀 돌",
	},
	"search_item_mystic_armor": {
		"en_u4": "Mystic Armor",
		"en_us": "Mystic Armor",
		"ko": "신비의 갑옷",
	},
	"search_item_mystic_swords": {
		"en_u4": "Mystic Swords",
		"en_us": "Mystic Swords",
		"ko": "신비의 검",
	},
	"search_item_rune_honesty": {
		"en_u4": "the rune of Honesty",
		"en_us": "the rune of Honesty",
		"ko": "정직의 룬",
	},
	"search_item_rune_compassion": {
		"en_u4": "the rune of Compassion",
		"en_us": "the rune of Compassion",
		"ko": "연민의 룬",
	},
	"search_item_rune_valor": {
		"en_u4": "the rune of Valor",
		"en_us": "the rune of Valor",
		"ko": "용맹의 룬",
	},
	"search_item_rune_justice": {
		"en_u4": "the rune of Justice",
		"en_us": "the rune of Justice",
		"ko": "정의의 룬",
	},
	"search_item_rune_sacrifice": {
		"en_u4": "the rune of Sacrifice",
		"en_us": "the rune of Sacrifice",
		"ko": "희생의 룬",
	},
	"search_item_rune_honor": {
		"en_u4": "the rune of Honor",
		"en_us": "the rune of Honor",
		"ko": "명예의 룬",
	},
	"search_item_rune_spirituality": {
		"en_u4": "the rune of Spirituality",
		"en_us": "the rune of Spirituality",
		"ko": "영성의 룬",
	},
	"search_item_rune_humility": {
		"en_u4": "the rune of Humility",
		"en_us": "the rune of Humility",
		"ko": "겸손의 룬",
	},
	"search_item_magic_axe": {
		"en_u4": "a Magic Axe",
		"en_us": "a Magic Axe",
		"ko": "마법 도끼",
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
	"cmd_board_balloon": {
		"en_u4": "Board Balloon!",
		"en_us": "Board Balloon!",
		"ko": "열기구에 탄다!",
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
	"cmd_zzzzzz": {
		"en_u4": "Zzzzzz",
		"en_us": "Zzzzzz",
		"ko": "쿨쿨…",
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
		"ko": "%s, 당신이 앞장서야 됩니다!",
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
		"en_u4": "▲",
		"en_us": "▲",
		"ko": "▲",
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
	## Use (U) — list of quest items (remake); empty inventory aborts.
	"cmd_use_which": {
		"en_u4": "Use which item:",
		"en_us": "Use which item:",
		"ko": "사용할 아이템:",
	},
	"cmd_use_none": {
		"en_u4": "You have no items.",
		"en_us": "You have no items.",
		"ko": "가지고 있는 아이템이 없습니다.",
	},
	"cmd_use_no_effect": {
		"en_u4": "Hmm...No effect!",
		"en_us": "Hmm...No effect!",
		"ko": "흠... 아무 일도 없다!",
	},
	"cmd_use_no_place": {
		"en_u4": "No place to Use them!",
		"en_us": "No place to Use them!",
		"ko": "사용할 곳이 없다!",
	},
	"cmd_use_none_owned": {
		"en_u4": "None owned!",
		"en_us": "None owned!",
		"ko": "가진 것이 없다!",
	},
	"cmd_use_bell": {
		"en_u4": "The Bell rings on and on!",
		"en_us": "The Bell rings on and on!",
		"ko": "종이 끊임없이 울린다!",
	},
	"cmd_use_book": {
		"en_u4": "The words resonate with the ringing!",
		"en_us": "The words resonate with the ringing!",
		"ko": "글이 종의 울림과 공명한다!",
	},
	"cmd_use_candle": {
		"en_u4": "As you light the Candle the Earth Trembles!",
		"en_us": "As you light the Candle the Earth Trembles!",
		"ko": "촛대를 밝히자 대지가 흔들린다!",
	},
	"cmd_use_bbc_abyss_open": {
		"en_u4": "The way into the Abyss is opened!",
		"en_us": "The path to the Abyss has opened.",
		"ko": "심연으로 가는 길이 열렸다!",
	},
	"cmd_use_skull_aloft": {
		"en_u4": "You hold the evil Skull of Mondain the Wizard aloft...",
		"en_us": "You hold the evil Skull of Mondain the Wizard aloft...",
		"ko": "모드인의 사악한 해골을 높이 들어올린다...",
	},
	"cmd_use_skull_abyss": {
		"en_u4": "You cast the Skull of Mondain into the Abyss!",
		"en_us": "You cast the Skull of Mondain into the Abyss!",
		"ko": "모드인의 해골을 심연에 던진다!",
	},
	"cmd_use_wheel_mounted": {
		"en_u4": "Once mounted, the Wheel glows with a blue light!",
		"en_us": "Once mounted, the Wheel glows with a blue light!",
		"ko": "바퀴를 장착하자 파란빛으로 빛난다!",
	},
	"cmd_use_horn": {
		"en_u4": "The Horn sounds an eerie tone!",
		"en_us": "The Horn sounds an eerie tone!",
		"ko": "은 뿔나팔이 섬뜩한 소리를 낸다!",
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
	"cmd_volume_on": {
		"en_u4": "Volume On!",
		"en_us": "Volume On!",
		"ko": "음악 켬!",
	},
	"cmd_volume_off": {
		"en_u4": "Volume Off!",
		"en_us": "Volume Off!",
		"ko": "음악 끔!",
	},
	"mix_title": {
		"en_u4": "Mix reagents",
		"en_us": "Mix reagents",
		"ko": "시약 조합",
	},
	"mix_make_new": {
		"en_u4": "Mix New…",
		"en_us": "Mix New…",
		"ko": "새 조합…",
	},
	"mix_spell_unknown": {
		"en_u4": "Unknown",
		"en_us": "Unknown",
		"ko": "불명",
	},
	"mix_hint_list": {
		"en_u4": "Enter/A-Z mix · Esc/Space quit",
		"en_us": "Enter/A-Z mix · Esc/Space quit",
		"ko": "Enter/A-Z 조합 · Esc/Space 종료",
	},
	"mix_hint_reag": {
		"en_u4": "Enter select · Mix/M mix · Esc/Space quit",
		"en_us": "Enter select · Mix/M mix · Esc/Space quit",
		"ko": "Enter 선택 · Mix/M 조합 · Esc/Space 종료",
	},
	"mix_action_mix": {
		"en_u4": "Mix",
		"en_us": "Mix",
		"ko": "조합",
	},
	"mix_for_spell": {
		"en_u4": "For Spell: ",
		"en_us": "For Spell: ",
		"ko": "마법: ",
	},
	"mix_for_spell_letter": {
		"en_u4": "For Spell: %s",
		"en_us": "For Spell: %s",
		"ko": "마법: %s",
	},
	"mix_success": {
		"en_u4": "Success! Mixed %s.",
		"en_us": "Success! Mixed %s.",
		"ko": "%s 마법 조합에 성공했다!",
	},
	"mix_failed": {
		"en_u4": "It Fizzles!",
		"en_us": "It Fizzles!",
		"ko": "실패했다! 시약이 소모되었다.",
	},
	"mix_need_reag": {
		"en_u4": "You don't have enough reagents!",
		"en_us": "You don't have enough reagents!",
		"ko": "시약이 부족하다!",
	},
	"mix_none_left": {
		"en_u4": "None Left!",
		"en_us": "None Left!",
		"ko": "시약이 없다!",
	},
	"mix_full": {
		"en_u4": "You cannot mix any more of that spell!",
		"en_us": "You cannot mix any more of that spell!",
		"ko": "그 마법은 더 이상 조합할 수 없다!",
	},
	"mix_reag_none": {
		"en_u4": "None Left!",
		"en_us": "None Left!",
		"ko": "남은 시약이 없다!",
	},
	"cast_title": {
		"en_u4": "Cast Spell!",
		"en_us": "Cast Spell!",
		"ko": "마법 시전!",
	},
	"cast_spell": {
		"en_u4": "Spell: ",
		"en_us": "Spell: ",
		"ko": "마법: ",
	},
	"cast_named": {
		"en_u4": "%s!",
		"en_us": "%s!",
		"ko": "%s!",
	},
	"cast_none_mixed": {
		"en_u4": "None Mixed!",
		"en_us": "None Mixed!",
		"ko": "조합한 마법이 없다!",
	},
	"cast_combat_only": {
		"en_u4": "Combat only!",
		"en_us": "Combat only!",
		"ko": "전투에서만 된다!",
	},
	"cast_dungeon_only": {
		"en_u4": "Dungeon only!",
		"en_us": "Dungeon only!",
		"ko": "던전에서만 된다!",
	},
	"cast_outdoors_only": {
		"en_u4": "Outdoors only!",
		"en_us": "Outdoors only!",
		"ko": "야외에서만 된다!",
	},
	"cast_failed": {
		"en_u4": "Failed!",
		"en_us": "Failed!",
		"ko": "실패했다!",
	},
	"cast_mp_too_low": {
		"en_u4": "Not Enough MP!",
		"en_us": "Not Enough MP!",
		"ko": "마나가 부족하다!",
	},
	"cast_player": {
		"en_u4": "Player: ",
		"en_us": "Player: ",
		"ko": "시전자: ",
	},
	"cast_who": {
		"en_u4": "Who: ",
		"en_us": "Who: ",
		"ko": "누구: ",
	},
	"cast_dir": {
		"en_u4": "Dir: ",
		"en_us": "Dir: ",
		"ko": "방향: ",
	},
	"cast_from_dir": {
		"en_u4": "From Dir: ",
		"en_us": "From Dir: ",
		"ko": "불어오는 쪽: ",
	},
	"cast_aim": {
		"en_u4": "Aim: ",
		"en_us": "Aim: ",
		"ko": "조준: ",
	},
	"cast_energy_type": {
		"en_u4": "Energy type? ",
		"en_us": "Energy type? ",
		"ko": "에너지 종류? ",
	},
	"cast_phase": {
		"en_u4": "To Phase: ",
		"en_us": "To Phase: ",
		"ko": "위상: ",
	},
	"cast_field_poison": {
		"en_u4": "Poison",
		"en_us": "Poison",
		"ko": "독",
	},
	"cast_field_lightning": {
		"en_u4": "Lightning",
		"en_us": "Lightning",
		"ko": "번개",
	},
	"cast_field_fire": {
		"en_u4": "Fire",
		"en_us": "Fire",
		"ko": "불",
	},
	"cast_field_sleep": {
		"en_u4": "Sleep",
		"en_us": "Sleep",
		"ko": "수면",
	},
	"cast_not_yet": {
		"en_u4": "Not yet implemented.",
		"en_us": "Not yet implemented.",
		"ko": "아직 시전할 수 없다.",
	},
	"talk_learned_reagent_mix": {
		"en_u4": "Thou hast learned a new reagent mixture.",
		"en_us": "You have learned a new reagent mixture.",
		"ko": "새로운 시약 조합법을 익혔습니다.",
	},
	"talk_learned_all_reagent_mix": {
		"en_u4": "Thou hast learned every reagent mixture.",
		"en_us": "You have learned every reagent mixture.",
		"ko": "모든 마법 시약 조합을 익혔습니다.",
	},
	"cmd_locate": {
		"en_u4": "%s  %s %s",
		"en_us": "%s  %s %s",
		"ko": "%s  %s %s",
	},
	"cmd_locate_what": {
		"en_u4": "Locate with What?",
		"en_us": "Locate with What?",
		"ko": "무엇으로 위치를 재나?",
	},
	"locate_on": {
		"en_u4": "Locate: On",
		"en_us": "Locate: On",
		"ko": "위치 확인: 켜짐",
	},
	"locate_off": {
		"en_u4": "Locate: Off",
		"en_us": "Locate: Off",
		"ko": "위치 확인: 꺼짐",
	},
	"hud_dungeon_level": {
		"en_u4": "L%d",
		"en_us": "L%d",
		"ko": "L%d",
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
	"ztats_page_items": {
		"en_u4": "Items",
		"en_us": "Items",
		"ko": "아이템",
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
	"ztats_section_stones": {
		"en_u4": "Stones",
		"en_us": "Stones",
		"ko": "돌",
	},
	"ztats_section_runes": {
		"en_u4": "Runes",
		"en_us": "Runes",
		"ko": "룬",
	},
	"ztats_section_relics": {
		"en_u4": "Relics",
		"en_us": "Relics",
		"ko": "유물",
	},
	"ztats_section_keys": {
		"en_u4": "Keys",
		"en_us": "Keys",
		"ko": "열쇠",
	},
	"ztats_items_none": {
		"en_u4": "None",
		"en_us": "None",
		"ko": "없음",
	},
	"ztats_item_sextant": {
		"en_u4": "Sextant",
		"en_us": "Sextant",
		"ko": "육분의",
	},
	"ztats_item_bell": {
		"en_u4": "Bell",
		"en_us": "Bell",
		"ko": "종",
	},
	"ztats_item_book": {
		"en_u4": "Book",
		"en_us": "Book",
		"ko": "책",
	},
	"ztats_item_candle": {
		"en_u4": "Candle",
		"en_us": "Candle",
		"ko": "촛대",
	},
	"ztats_item_horn": {
		"en_u4": "Horn",
		"en_us": "Horn",
		"ko": "뿔피리",
	},
	"ztats_item_wheel": {
		"en_u4": "Wheel",
		"en_us": "Wheel",
		"ko": "키",
	},
	"ztats_item_skull": {
		"en_u4": "Skull",
		"en_us": "Skull",
		"ko": "해골",
	},
	"ztats_item_key_truth": {
		"en_u4": "Truth",
		"en_us": "Truth",
		"ko": "진리",
	},
	"ztats_item_key_love": {
		"en_u4": "Love",
		"en_us": "Love",
		"ko": "사랑",
	},
	"ztats_item_key_courage": {
		"en_u4": "Courage",
		"en_us": "Courage",
		"ko": "용기",
	},
	"ztats_item_stone_blue": {
		"en_u4": "Blue",
		"en_us": "Blue",
		"ko": "파란 돌",
	},
	"ztats_item_stone_yellow": {
		"en_u4": "Yellow",
		"en_us": "Yellow",
		"ko": "노란 돌",
	},
	"ztats_item_stone_red": {
		"en_u4": "Red",
		"en_us": "Red",
		"ko": "빨간 돌",
	},
	"ztats_item_stone_green": {
		"en_u4": "Green",
		"en_us": "Green",
		"ko": "초록 돌",
	},
	"ztats_item_stone_orange": {
		"en_u4": "Orange",
		"en_us": "Orange",
		"ko": "주황 돌",
	},
	"ztats_item_stone_purple": {
		"en_u4": "Purple",
		"en_us": "Purple",
		"ko": "보라 돌",
	},
	"ztats_item_stone_white": {
		"en_u4": "White",
		"en_us": "White",
		"ko": "하얀 돌",
	},
	"ztats_item_stone_black": {
		"en_u4": "Black",
		"en_us": "Black",
		"ko": "검은 돌",
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
	"cmd_ignite_torch": {
		"en_u4": "Ignite torch!",
		"en_us": "You light a torch!",
		"ko": "횃불을 켠다!",
	},
	"cmd_ignite_none": {
		"en_u4": "None left!",
		"en_us": "You have no torches left!",
		"ko": "횃불이 없다!",
	},
	"cmd_ignite_already": {
		"en_u4": "A torch is already burning.",
		"en_us": "A torch is already burning.",
		"ko": "이미 횃불이 타오르고 있다.",
	},
	"cmd_dungeon_torch_out": {
		"en_u4": "Thy torch is extinguished!",
		"en_us": "Your torch goes out!",
		"ko": "횃불이 꺼진다!",
	},
	"cmd_dungeon_dark": {
		"en_u4": "It's too dark to see!",
		"en_us": "It's too dark to see!",
		"ko": "너무 어두워 보이지 않는다!",
	},
	"cmd_dungeon_leave": {
		"en_u4": "Leaving...",
		"en_us": "Leaving...",
		"ko": "떠난다...",
	},
	"cmd_dungeon_turn": {
		"en_u4": "Turn %s!",
		"en_us": "Turn %s!",
		"ko": "%s으로 돈다!",
	},
	"cmd_dungeon_secret": {
		"en_u4": "You find a hidden door!",
		"en_us": "You find a hidden door!",
		"ko": "숨겨진 문을 찾았다!",
	},
	"cmd_dungeon_fountain_found": {
		"en_u4": "You find a Fountain.",
		"en_us": "You find a fountain.",
		"ko": "샘물을 발견했다.",
	},
	"cmd_dungeon_fountain_who": {
		"en_u4": "Who drinks?",
		"en_us": "Who drinks?",
		"ko": "누가 마실까?",
	},
	"cmd_disabled": {
		"en_u4": "Disabled!",
		"en_us": "Disabled!",
		"ko": "행동 불가!",
	},
	"cmd_dungeon_fountain_no_effect": {
		"en_u4": "Hmmm--No Effect!",
		"en_us": "Hmm... No effect!",
		"ko": "음... 아무 효과도 없다!",
	},
	"cmd_dungeon_fountain_poison": {
		"en_u4": "Argh-Choke-Gasp!",
		"en_us": "Argh... Choke... Gasp!",
		"ko": "으윽... 숨이 막힌다!",
	},
	"cmd_dungeon_fountain_heal": {
		"en_u4": "Ahh-Refreshing!",
		"en_us": "Ahh, refreshing!",
		"ko": "아, 상쾌하다!",
	},
	"cmd_dungeon_fountain_acid": {
		"en_u4": "Bleck--Nasty!",
		"en_us": "Blech... Nasty!",
		"ko": "우웩... 지독하다!",
	},
	"cmd_dungeon_fountain_cure": {
		"en_u4": "Hmmm--Delicious!",
		"en_us": "Hmm... Delicious!",
		"ko": "음... 맛있다!",
	},
	"cmd_dungeon_fountain_empty": {
		"en_u4": "The fountain is dry.",
		"en_us": "The fountain is dry.",
		"ko": "샘이 말라 있다.",
	},
	"cmd_dungeon_orb": {
		"en_u4": "You find a Magical Ball...",
		"en_us": "You find a magical orb...",
		"ko": "마법의 구를 발견했다...",
	},
	"cmd_dungeon_orb_who": {
		"en_u4": "Who touches?",
		"en_us": "Who touches?",
		"ko": "누가 만질까?",
	},
	"cmd_dungeon_orb_str": {
		"en_u4": "Strength + 5",
		"en_us": "Strength + 5",
		"ko": "힘 + 5",
	},
	"cmd_dungeon_orb_dex": {
		"en_u4": "Dexterity + 5",
		"en_us": "Dexterity + 5",
		"ko": "민첩 + 5",
	},
	"cmd_dungeon_orb_int": {
		"en_u4": "Intelligence + 5",
		"en_us": "Intelligence + 5",
		"ko": "지성 + 5",
	},
	"cmd_dungeon_orb_spent": {
		"en_u4": "The Magical Ball is spent.",
		"en_us": "The magical orb is spent.",
		"ko": "마법의 구는 이미 힘을 잃었다.",
	},
	"cmd_dungeon_trap_winds": {
		"en_u4": "Winds!",
		"en_us": "Winds!",
		"ko": "돌풍!",
	},
	"cmd_dungeon_trap_rocks": {
		"en_u4": "Falling rocks!",
		"en_us": "Falling rocks!",
		"ko": "낙석!",
	},
	"cmd_dungeon_trap_pit": {
		"en_u4": "A pit!",
		"en_us": "A pit!",
		"ko": "구덩이!",
	},
	"cmd_dungeon_klimb": {
		"en_u4": "Klimb",
		"en_us": "Climb",
		"ko": "오른다",
	},
	"cmd_dungeon_descend": {
		"en_u4": "Descend",
		"en_us": "Descend",
		"ko": "내려간다",
	},
	"cmd_dungeon_light": {
		"en_u4": "Light!",
		"en_us": "Light!",
		"ko": "빛!",
	},
	"cmd_dungeon_xit": {
		"en_u4": "X-it!",
		"en_us": "You leave the dungeon!",
		"ko": "던전을 빠져나간다!",
	},
	"cmd_dungeon_yup": {
		"en_u4": "Y-up!",
		"en_us": "You rise a level!",
		"ko": "한 층 오른다!",
	},
	"cmd_dungeon_zdown": {
		"en_u4": "Z-down!",
		"en_us": "You descend a level!",
		"ko": "한 층 내려간다!",
	},
	"cmd_dungeon_no_level": {
		"en_u4": "Not here!",
		"en_us": "Not here!",
		"ko": "여기선 안 된다!",
	},
	"cmd_dungeon_stone": {
		"en_u4": "You find a %s stone!",
		"en_us": "You find a %s stone!",
		"ko": "%s 돌을 찾았다!",
	},
	"cmd_dungeon_stone_already": {
		"en_u4": "Nothing here.",
		"en_us": "Nothing here.",
		"ko": "여기엔 아무것도 없다.",
	},
	"cmd_use_altar_stones": {
		"en_u4": "The stones shine upon the altar!",
		"en_us": "The stones shine upon the altar!",
		"ko": "제단 위에서 돌들이 빛난다!",
	},
	"cmd_use_altar_key": {
		"en_u4": "Thou dost receive the Key of %s!",
		"en_us": "You receive the Key of %s!",
		"ko": "%s의 열쇠를 받는다!",
	},
	"cmd_use_altar_have_key": {
		"en_u4": "The altar is silent.",
		"en_us": "The altar is silent.",
		"ko": "제단은 고요하다.",
	},
	"cmd_use_stones_generic": {
		"en_u4": "Stones",
		"en_us": "Stones",
		"ko": "돌",
	},
	"cmd_use_abyss_virtue_question": {
		"en_u4": "As thou dost approach, a voice rings out:\nWhat virtue doth stem from %s?",
		"en_us": "As you approach, a voice rings out:\nWhat virtue stems from %s?",
		"ko": "다가서자 음성이 울려 퍼진다:\n%s에서 비롯되는 미덕은 무엇인가?",
	},
	"cmd_use_abyss_virtue_independent": {
		"en_u4": "A voice rings out:\nWhat virtue exists independently of Truth, Love, and Courage?",
		"en_us": "A voice rings out:\nWhat virtue exists independently of Truth, Love, and Courage?",
		"ko": "음성이 울려 퍼진다:\n진리, 사랑, 용기와 독립적으로 존재하는 미덕은 무엇인가?",
	},
	"cmd_use_abyss_stone_prompt": {
		"en_u4": "The Voice says: Use thy Stone.\nColor:",
		"en_us": "The Voice says: Use your Stone.\nColor:",
		"ko": "음성이 말한다: 그대의 돌을 사용하라.\n색상:",
	},
	"cmd_use_abyss_stone": {
		"en_u4": "The altar changes before thine eyes!",
		"en_us": "The altar changes before your eyes!",
		"ko": "눈앞에서 제단이 변한다!",
	},
	"cmd_use_abyss_stone_wrong": {
		"en_u4": "That stone doth not belong here.",
		"en_us": "That stone does not belong here.",
		"ko": "그 돌은 여기 놓을 것이 아니다.",
	},
	"cmd_use_abyss_keys": {
		"en_u4": "The three keys open the way to the Codex!",
		"en_us": "The three keys open the way to the Codex!",
		"ko": "세 열쇠가 코덱스로 가는 길을 연다!",
	},
	"cmd_abyss_need_bbc": {
		"en_u4": "A strange force keeps you out!",
		"en_us": "A strange force keeps you out!",
		"ko": "이상한 힘이 막는다!",
	},
	"cmd_abyss_need_keys": {
		"en_u4": "Thou hast not the three keys!",
		"en_us": "You do not have the three keys!",
		"ko": "세 열쇠가 없다!",
	},
	"cmd_codex_voice": {
		"en_u4": "A voice rings out:",
		"en_us": "A voice rings out:",
		"ko": "목소리가 울려 퍼진다:",
	},
	"cmd_codex_q_honesty": {
		"en_u4": "What dost thou possess if all may rely upon thy every word?",
		"en_us": "What do you possess if all may rely upon your every word?",
		"ko": "모든 이가 그대의 말마다 기댈 수 있다면, 그대가 지닌 것은?",
	},
	"cmd_codex_q_compassion": {
		"en_u4": "What quality compels one to share in the journeys of others?",
		"en_us": "What quality compels one to share in the journeys of others?",
		"ko": "남의 여정에 함께하게 하는 덕목은?",
	},
	"cmd_codex_q_valor": {
		"en_u4": "What answers when great deeds are called for?",
		"en_us": "What answers when great deeds are called for?",
		"ko": "큰 위업이 요구될 때 응답하는 것은?",
	},
	"cmd_codex_q_justice": {
		"en_u4": "What should be the same for Lord and Serf alike?",
		"en_us": "What should be the same for lord and serf alike?",
		"ko": "영주와 농노에게 마땅히 같아야 하는 것은?",
	},
	"cmd_codex_q_sacrifice": {
		"en_u4": "What is loath to place the self above aught else?",
		"en_us": "What is loath to place the self above all else?",
		"ko": "자신을 무엇보다 앞에 두기를 꺼리는 것은?",
	},
	"cmd_codex_q_honor": {
		"en_u4": "What shirks no duty?",
		"en_us": "What shirks no duty?",
		"ko": "어떤 의무도 피하지 않는 것은?",
	},
	"cmd_codex_q_spirituality": {
		"en_u4": "What, in knowing the true self, knows all?",
		"en_us": "What, in knowing the true self, knows all?",
		"ko": "참된 자신을 앎으로써 모든 것을 아는 것은?",
	},
	"cmd_codex_q_humility": {
		"en_u4": "What is that which Serfs are born with, but Nobles must strive to obtain?",
		"en_us": "What is that which serfs are born with, but nobles must strive to obtain?",
		"ko": "농노는 타고나되 귀족은 애써 얻어야 하는 것은?",
	},
	"cmd_codex_q_truth": {
		"en_u4": "If all else is imaginary, this is real...",
		"en_us": "If all else is imaginary, this is real...",
		"ko": "다른 모든 것이 허상이라면, 이것만은 실재다...",
	},
	"cmd_codex_q_love": {
		"en_u4": "What plunges to the depths, while soaring on the heights?",
		"en_us": "What plunges to the depths, while soaring on the heights?",
		"ko": "높은 곳에 오르면서도 깊은 곳으로 가라앉는 것은?",
	},
	"cmd_codex_q_courage": {
		"en_u4": "What turns not away from any peril?",
		"en_us": "What turns not away from any peril?",
		"ko": "어떤 위험도 외면하지 않는 것은?",
	},
	"cmd_codex_q_infinity": {
		"en_u4": "If all eight virtues of the Avatar combine into and are derived from the three principles of Truth, Love and Courage, then what is the one thing which encompasses and is the whole of all undeniable Truth, unending Love, and unyielding Courage?",
		"en_us": "If all eight virtues of the Avatar combine into and are derived from the three principles of Truth, Love and Courage, then what is the one thing which encompasses and is the whole of all undeniable Truth, unending Love, and unyielding Courage?",
		"ko": "아바타의 여덟 미덕이 진리·사랑·용기 세 원리에서 나와 하나로 합쳐진다면, 부정할 수 없는 진리와 끝없는 사랑과 꺾이지 않는 용기 전체를 아우르는 그 하나는?",
	},
	"cmd_codex_wrong": {
		"en_u4": "Passage is not granted.",
		"en_us": "Passage is not granted.",
		"ko": "통과가 허락되지 않는다.",
	},
	"cmd_codex_end": {
		"en_u4": "The boundless knowledge of the Codex of Ultimate Wisdom is revealed unto thee.",
		"en_us": "The boundless knowledge of the Codex of Ultimate Wisdom is revealed to you.",
		"ko": "궁극의 지혜의 코덱스가 지닌 한없는 지식이 그대에게 드러난다.",
	},
	"cmd_codex_end_voice": {
		"en_u4": "The voice says: Thou hast proven thyself to be truly good in nature.",
		"en_us": "The voice says: You have proven yourself to be truly good in nature.",
		"ko": "목소리가 말한다: 그대는 참으로 선한 본성을 증명하였다.",
	},
	"cmd_codex_end_quest": {
		"en_u4": "Thou must know that thy quest to become an Avatar is the endless quest of a lifetime.",
		"en_us": "Know that the quest to become an Avatar is the endless quest of a lifetime.",
		"ko": "아바타가 되는 길은 평생에 걸친 끝없는 여정임을 알아야 한다.",
	},
	"cmd_codex_end_gift": {
		"en_u4": "Avatarhood is a living gift. It must always and forever be nurtured to flourish.",
		"en_us": "Avatarhood is a living gift. It must always and forever be nurtured to flourish.",
		"ko": "아바타의 지위는 살아 있는 선물이다. 언제나, 영원히 가꾸어야 피어난다.",
	},
	"cmd_codex_end_stray": {
		"en_u4": "For if thou dost stray from the paths of virtue, thy way may be lost forever.",
		"en_us": "For if you stray from the paths of virtue, your way may be lost forever.",
		"ko": "미덕의 길에서 벗어난다면, 그 길은 영원히 잃을 수도 있다.",
	},
	"cmd_codex_end_return": {
		"en_u4": "Return now unto thine own world. Live there as an example to thy people, as our memory of thy gallant deeds serves us.",
		"en_us": "Return now to your own world. Live there as an example to your people, as our memory of your gallant deeds serves us.",
		"ko": "이제 그대의 세계로 돌아가라. 그대의 용맹한 업적이 우리에게 기억되듯, 그곳에서 사람들의 본보기가 되어라.",
	},
	"cmd_codex_end_vertigo": {
		"en_u4": "As the sound of the voice trails off, darkness seems to rise around you. There is a moment of intense, wrenching vertigo.",
		"en_us": "As the sound of the voice trails off, darkness seems to rise around you. There is a moment of intense, wrenching vertigo.",
		"ko": "목소리가 잦아들자 어둠이 주위를 차오른다. 몸이 뒤틀리는 듯한 강렬한 현기증이 일었다.",
	},
	"cmd_codex_end_stones": {
		"en_u4": "You open your eyes to a familiar circle of stones. You wonder of your recent adventures.",
		"en_us": "You open your eyes to a familiar circle of stones. You wonder about your recent adventures.",
		"ko": "눈을 뜨니 낯익은 돌무리가 있다. 방금의 모험이 떠오른다.",
	},
	"cmd_codex_end_ankh": {
		"en_u4": "It seems a time and place very distant. You wonder if it really happened. Then you realize that in your hand you hold The Ankh.",
		"en_us": "It seems a time and place very distant. You wonder if it really happened. Then you realize that in your hand you hold The Ankh.",
		"ko": "아주 멀고 먼 때와 장소처럼 느껴진다. 정말 일어난 일인지 의문이 들다가, 손안에 앙크가 들려 있음을 깨닫는다.",
	},
	"cmd_codex_end_walk": {
		"en_u4": "You walk away from the circle, knowing that you can always return from whence you came, since you now know the secret of the gates.",
		"en_us": "You walk away from the circle, knowing that you can always return from whence you came, since you now know the secret of the gates.",
		"ko": "이제 문의 비밀을 알았으니 언제든 왔던 곳으로 돌아갈 수 있음을 알고, 돌무리를 떠나 걷는다.",
	},
	"cmd_codex_end_congrats": {
		"en_u4": "CONGRATULATIONS!\nThou hast completed ULTIMA IV Quest of the Avatar in %s turns!\nReport thy feat unto Lord British at Origin Systems!",
		"en_us": "CONGRATULATIONS!\nYou have completed ULTIMA IV Quest of the Avatar in %s turns!",
		"ko": "축하한다!\n그대는 울티마 IV 아바타의 퀘스트를 %s턴 만에 완수하였다!",
	},
	"cmd_principle_truth": {
		"en_u4": "Truth",
		"en_us": "Truth",
		"ko": "진리",
	},
	"cmd_principle_love": {
		"en_u4": "Love",
		"en_us": "Love",
		"ko": "사랑",
	},
	"cmd_principle_courage": {
		"en_u4": "Courage",
		"en_us": "Courage",
		"ko": "용기",
	},
	"cmd_principle_truth_love": {
		"en_u4": "Truth and Love",
		"en_us": "Truth and Love",
		"ko": "진리와 사랑",
	},
	"cmd_principle_love_courage": {
		"en_u4": "Love and Courage",
		"en_us": "Love and Courage",
		"ko": "사랑과 용기",
	},
	"cmd_principle_truth_courage": {
		"en_u4": "Truth and Courage",
		"en_us": "Truth and Courage",
		"ko": "진리와 용기",
	},
	"cmd_principle_all": {
		"en_u4": "Truth, Love, and Courage",
		"en_us": "Truth, Love, and Courage",
		"ko": "진리, 사랑, 용기",
	},
}

## Official settlement / dungeon ids for `{paws}` tokens in journal, talk, and LB copy.
## Display via fill_places() so a rename in place_* updates every language at once.
const PLACE_IDS: Array[String] = [
	"lcb", "britain", "yew", "paws", "trinsic", "moonglow", "jhelom",
	"minoc", "skara", "magincia", "den", "vesper", "cove",
	"lycaeum", "empath", "serpent",
	"shame", "wrong", "deceit", "despise", "destard", "covetous",
	"hythloth", "abyss",
]


func place(place_id: String) -> String:
	var id := place_id.strip_edges().to_lower()
	if id.is_empty():
		return ""
	return t("place_%s" % id)


func fill_places(text: String) -> String:
	## Replace `{skara}` with the current-language official name. Particles stay
	## outside the token: `{paws}의 바렌`. `{abyss}` is already "the Abyss" in English.
	if text.is_empty() or text.find("{") < 0:
		return text
	var out := text
	for id in PLACE_IDS:
		var token := "{%s}" % id
		if out.find(token) >= 0:
			out = out.replace(token, place(id))
	return out


func t(key: String, args: Array = []) -> String:
	var pack: Dictionary = _T.get(key, {})
	var s: String = str(pack.get(GameState.language, pack.get("en_us", key)))
	if args.is_empty():
		return s
	## Keep numeric types so `%d` / `%03d` format correctly (do not stringify first).
	if args.size() == 1:
		return s % args[0]
	return s % args


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
