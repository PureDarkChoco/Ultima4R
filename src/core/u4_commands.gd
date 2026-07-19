class_name U4Commands
extends Object

## Classic Ultima IV keyboard commands. A–Z are reserved for these — never movement.
## Movement = arrow keys (and gamepad D-pad / stick).

enum Id {
	NONE = 0,
	ATTACK, # A
	BOARD, # B
	CAST, # C
	DESCEND, # D
	ENTER, # E
	FIRE, # F
	GET_CHEST, # G
	HOLE_UP, # H
	IGNITE, # I
	JIMMY, # J
	KLIMB, # K
	LOCATE, # L
	MIX, # M
	NEW_ORDER, # N
	OPEN, # O
	PEER, # P
	QUIT_SAVE, # Q
	READY, # R
	SEARCH, # S
	TALK, # T
	USE, # U
	VOLUME, # V
	WEAR, # W
	XIT, # X
	YELL, # Y
	ZTATS, # Z
	PASS, # Space
}

const BY_LETTER := {
	"A": Id.ATTACK,
	"B": Id.BOARD,
	"C": Id.CAST,
	"D": Id.DESCEND,
	"E": Id.ENTER,
	"F": Id.FIRE,
	"G": Id.GET_CHEST,
	"H": Id.HOLE_UP,
	"I": Id.IGNITE,
	"J": Id.JIMMY,
	"K": Id.KLIMB,
	"L": Id.LOCATE,
	"M": Id.MIX,
	"N": Id.NEW_ORDER,
	"O": Id.OPEN,
	"P": Id.PEER,
	"Q": Id.QUIT_SAVE,
	"R": Id.READY,
	"S": Id.SEARCH,
	"T": Id.TALK,
	"U": Id.USE,
	"V": Id.VOLUME,
	"W": Id.WEAR,
	"X": Id.XIT,
	"Y": Id.YELL,
	"Z": Id.ZTATS,
}

const LABEL_EN := {
	Id.ATTACK: "Attack",
	Id.BOARD: "Board",
	Id.CAST: "Cast",
	Id.DESCEND: "Descend",
	Id.ENTER: "Enter",
	Id.FIRE: "Fire",
	Id.GET_CHEST: "Get chest",
	Id.HOLE_UP: "Hole up",
	Id.IGNITE: "Ignite torch",
	Id.JIMMY: "Jimmy lock",
	Id.KLIMB: "Klimb",
	Id.LOCATE: "Locate",
	Id.MIX: "Mix reagents",
	Id.NEW_ORDER: "New order",
	Id.OPEN: "Open",
	Id.PEER: "Peer",
	Id.QUIT_SAVE: "Quit & Save",
	Id.READY: "Ready weapon",
	Id.SEARCH: "Search",
	Id.TALK: "Talk",
	Id.USE: "Use",
	Id.VOLUME: "Volume",
	Id.WEAR: "Wear armour",
	Id.XIT: "Xit",
	Id.YELL: "Yell",
	Id.ZTATS: "Ztats",
	Id.PASS: "Pass",
}

const LABEL_KO := {
	Id.ATTACK: "공격",
	Id.BOARD: "탑승",
	Id.CAST: "주문",
	Id.DESCEND: "내려가기",
	Id.ENTER: "들어가기",
	Id.FIRE: "함포",
	Id.GET_CHEST: "상자 열기",
	Id.HOLE_UP: "야영",
	Id.IGNITE: "횃불",
	Id.JIMMY: "자물쇠 따기",
	Id.KLIMB: "올라가기",
	Id.LOCATE: "위치 확인",
	Id.MIX: "시약 혼합",
	Id.NEW_ORDER: "대열 변경",
	Id.OPEN: "문 열기",
	Id.PEER: "보석 투시",
	Id.QUIT_SAVE: "저장 후 종료",
	Id.READY: "무기 장착",
	Id.SEARCH: "수색",
	Id.TALK: "대화",
	Id.USE: "사용",
	Id.VOLUME: "음량",
	Id.WEAR: "갑옷 장착",
	Id.XIT: "하차",
	Id.YELL: "외치기",
	Id.ZTATS: "상태",
	Id.PASS: "대기",
}

## Commands that originally need a direction afterward.
const NEEDS_DIRECTION := {
	Id.ATTACK: true,
	Id.FIRE: true,
	Id.JIMMY: true,
	Id.OPEN: true,
	Id.TALK: true,
}


static func from_keycode(keycode: int) -> int:
	if keycode == KEY_SPACE:
		return Id.PASS
	if keycode >= KEY_A and keycode <= KEY_Z:
		var letter := String.chr(keycode)
		return BY_LETTER.get(letter, Id.NONE)
	# Allow lowercase unicode path via physical letters already KEY_A..Z when using keycode.
	return Id.NONE


static func from_event(event: InputEventKey) -> int:
	if event.echo:
		return Id.NONE
	# Prefer physical letter so layout/shift doesn't break commands.
	var code := event.keycode
	if code == KEY_NONE:
		code = event.physical_keycode
	if code >= KEY_A and code <= KEY_Z:
		return from_keycode(code)
	if event.physical_keycode >= KEY_A and event.physical_keycode <= KEY_Z:
		return from_keycode(event.physical_keycode)
	if code == KEY_SPACE or event.physical_keycode == KEY_SPACE:
		return Id.PASS
	return Id.NONE


static func label(cmd: int, lang: String = "en") -> String:
	if lang == "ko":
		return LABEL_KO.get(cmd, "?")
	return LABEL_EN.get(cmd, "?")


static func letter_for(cmd: int) -> String:
	for k in BY_LETTER.keys():
		if BY_LETTER[k] == cmd:
			return k
	if cmd == Id.PASS:
		return "Space"
	return ""
