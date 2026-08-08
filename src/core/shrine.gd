class_name Shrine
extends RefCounted

## xu4 shrine.cpp / shrine.h — constants, mantras, advice text.

const MEDITATION_INTERVAL := 100 ## moves between meditations
const MANTRAS_PER_CYCLE := 16
## xu4 default shrineTime ≈ 4s → ~0.25s per mantra dot (min 50ms).
const DOT_INTERVAL_SEC := 0.25

const MANTRAS: Array[String] = [
	"ahm", "mu", "ra", "beh", "cah", "summ", "om", "lum",
]

## avatar.exe string table (offset 93682) — 3 lines × 8 virtues, cycles 1..3.
const ADVICE: Array[String] = [
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


static func mantra_of(virtue: int) -> String:
	if virtue < 0 or virtue >= MANTRAS.size():
		return ""
	return MANTRAS[virtue]


static func virtue_input_matches(virtue: int, typed: String) -> bool:
	## xu4: strncasecmp(input, getVirtueName(virtue), 6)
	var want := Virtues.name_of(virtue, "en").to_lower()
	var got := typed.strip_edges().to_lower()
	if got.is_empty() or want.is_empty():
		return false
	var n := mini(6, want.length())
	if got.length() < n:
		return false
	return got.substr(0, n) == want.substr(0, n)


static func mantra_matches(virtue: int, typed: String) -> bool:
	return typed.strip_edges().to_lower() == mantra_of(virtue)


static func advice_for(virtue: int, completed_cycles: int) -> String:
	## completed_cycles is 1..3 after a successful cycle.
	var c := clampi(completed_cycles, 1, 3)
	var v := clampi(virtue, 0, 7)
	var i := v * 3 + (c - 1)
	if i < 0 or i >= ADVICE.size():
		return ""
	return ADVICE[i]


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
