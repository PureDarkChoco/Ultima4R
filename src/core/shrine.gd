class_name Shrine
extends RefCounted

## xu4 shrine.cpp / shrine.h — constants, mantras, advice text.
## Mantras stay Latin (ahm, mu, …) in every language.

const MEDITATION_INTERVAL := 100 ## moves between meditations
const MANTRAS_PER_CYCLE := 16
## xu4 default shrineTime ≈ 4s → ~0.25s per mantra dot (min 50ms).
const DOT_INTERVAL_SEC := 0.25

const MANTRAS: Array[String] = [
	"ahm", "mu", "ra", "beh", "cah", "summ", "om", "lum",
]

## avatar.exe string table (offset 93682) — 3 lines × 8 virtues, cycles 1..3.
const ADVICE_EN: Array[String] = [
	"Take not the gold of others found in towns and castles for yours it is not!",
	"Cheat not the merchants and peddlers for tis an evil thing to do!",
	"Second, read the Book of Truth at the entrance to the Great Stygian Abyss!",
	"Kill not the non-evil beasts of the land, and do not attack the fair people!",
	"Give of thy purse to those who beg and thy deed shall not be forgotten!",
	"Third, light the Candle of Love at the entrance to the Great Stygian Abyss!",
	"Victories scored over evil creatures help to build a valorous soul!",
	"To flee from battle with less than grievous wounds often shows a coward!",
	"First, ring the Bell of Courage at the entrance to the Great Stygian Abyss!",
	"To take the gold of others is injustice not soon forgotten. Take only thy due!",
	"Attack not a peaceful citizen for that action deserves strict punishment!",
	"Kill not a non-evil beast for they deserve not death, even if in hunger they attack thee!",
	"To give thy last gold piece unto the needy shows good measure of self-sacrifice!",
	"For thee to flee and leave thy companions is a self-serving action to be avoided!",
	"To give of thy life's blood so that others may live is a virtue of great praise!",
	"Take not the gold of others for this shall bring dishonor upon thee!",
	"To strike first a non-evil being is by no means an honorable deed!",
	"Seek ye to solve the many Quests before thee, and honor shall be a reward!",
	"Seek ye to know thyself.  Visit the seer often for he can see into thy inner being!",
	"Meditation leads to enlightenment Seek ye all Wisdom and Knowledge!",
	"If thou dost seek the White Stone, search ye not under the ground, but in Serpent's Spine!",
	"Claim not to be that which thou art not.  Humble actions speak well of thee!",
	"Strive not to wield the Great Force of Evil for its power will overcome thee!",
	"If thou dost seek the Black Stone, search ye at the Time and Place of the Gate on the darkest of all nights!",
]

const ADVICE_KO: Array[String] = [
	"마을과 성에서 발견한 남의 골드는 취하지 말라! 그것은 그대의 것이 아니다!",
	"상인과 행상을 속이지 말라. 그것은 악한 일이다!",
	"둘째, 위대한 스티지안 심연 입구에서 진리의 책을 읽으라!",
	"대지의 악하지 않은 짐승을 죽이지 말고, 공정한 사람들을 공격하지 말라!",
	"구걸하는 이에게 지갑을 나누어 주라. 그 행위는 잊히지 않으리!",
	"셋째, 위대한 스티지안 심연 입구에서 사랑의 촛대를 밝히라!",
	"악한 생물을 이긴 승리는 용맹한 영혼을 기른다!",
	"큰 상처가 아닌데도 전투에서 달아나는 것은 종종 겁쟁이의 표다!",
	"첫째, 위대한 스티지안 심연 입구에서 용기의 종을 울리라!",
	"남의 골드를 취하는 것은 오래 기억되는 불의이다. 그대의 정당한 몫만 취하라!",
	"평화로운 시민을 공격하지 말라. 그 행위에겐 엄한 벌이 마땅하다!",
	"악하지 않은 짐승은 죽이지 말라. 굶주려 덤벼들더라도 죽음은 값지 않다!",
	"가진 마지막 금화까지 궁핍한 이에게 주는 것은 자기희생의 본보기다!",
	"동료를 남기고 도주하는 것은 피해야 할 이기적인 행위다!",
	"타인이 살 수 있도록 생명의 피를 내어 주는 것은 크게 칭송받을 미덕이다!",
	"남의 골드를 취하지 말라. 그것은 그대에게 불명예를 가져온다!",
	"악하지 않은 존재를 먼저 치는 것은 결코 명예로운 일이 아니다!",
	"앞에 놓인 많은 퀘스트를 풀라. 명예가 상이 되리!",
	"자신을 알라. 예언자를 자주 찾으라. 그는 그대 내면을 볼 수 있다!",
	"명상은 깨달음으로 이끈다. 모든 지혜와 지식을 구하라!",
	"흰 돌을 구한다면 땅 밑이 아니라 뱀의 척추에서 찾으라!",
	"자신이 아닌 척하지 말라. 겸손한 행동이 그대를 말한다!",
	"악의 거대한 힘을 휘두르려 애쓰지 말라. 그 힘이 그대를 집어삼킬 것이다!",
	"검은 돌을 구한다면 가장 어두운 밤에 문의 때와 장소에서 찾으라!",
]


static func is_korean() -> bool:
	if Engine.get_main_loop() != null:
		var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
		if gs != null:
			return str(gs.language) == "ko"
	return false


static func mantra_of(virtue: int) -> String:
	if virtue < 0 or virtue >= MANTRAS.size():
		return ""
	return MANTRAS[virtue]


static func virtue_input_matches(virtue: int, typed: String) -> bool:
	## xu4: strncasecmp(input, getVirtueName(virtue), 6) — also Korean virtue names.
	var got := TalkLocale.normalize_interest(typed)
	if got.is_empty():
		return false
	var en := TalkLocale.normalize_interest(Virtues.name_of(virtue, "en"))
	if not en.is_empty():
		var n := mini(6, en.length())
		if got.length() >= n and got.substr(0, n) == en.substr(0, n):
			return true
	var ko := TalkLocale.normalize_interest(Virtues.name_of(virtue, "ko"))
	if not ko.is_empty() and got.length() >= ko.length() and got.substr(0, ko.length()) == ko:
		return true
	return false


static func mantra_matches(virtue: int, typed: String) -> bool:
	## Mantra is always Latin string (never localized).
	return typed.strip_edges().to_lower() == mantra_of(virtue)


static func advice_for(virtue: int, completed_cycles: int) -> String:
	## completed_cycles is 1..3 after a successful cycle.
	var c := clampi(completed_cycles, 1, 3)
	var v := clampi(virtue, 0, 7)
	var i := v * 3 + (c - 1)
	var table: Array[String] = ADVICE_KO if is_korean() else ADVICE_EN
	if i < 0 or i >= table.size():
		return ""
	return table[i]


static func can_enter_with_rune(virtue: int) -> bool:
	## xu4 Party::canEnterShrine — rune bit for virtue.
	if virtue < 0 or virtue > 7:
		return false
	return GameState.has_rune(1 << virtue)


static func meditation_fatigue_ok() -> bool:
	## xu4: (moves/INTERVAL) bucket differs from lastmeditation (or overflow).
	var bucket := int(GameState.moves / MEDITATION_INTERVAL)
	if bucket >= 0x10000:
		return true
	return (bucket & 0xFFFF) != (GameState.lastmeditation & 0xFFFF)


static func mark_meditation_done() -> void:
	GameState.lastmeditation = int(GameState.moves / MEDITATION_INTERVAL) & 0xFFFF
