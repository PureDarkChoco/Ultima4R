class_name Hawkwind
extends RefCounted

## xu4 / ScummVM U4HWDialogueLoader + AVATAR.EXE hawkwind string table.
## Player asks about each virtue (4-letter prefix); seer gives tiered karma advice.
## Intro awards KA_HAWKWIND Spirituality (+3 on virtueIncreaseTimeout).

## 5 tiers × 8 virtues. Indices match ScummVM `hawkwindText[(level/20)*8 + v]`.
const ADVICE: Array[String] = [
	## tier 0 — karma 1..19
	"Thou art a thief and a scoundrel. Thou may not ever become an Avatar!",
	"Thou art a cold and cruel brute.  Thou shouldst go to prison for thy crimes!",
	"Thou art a coward, thou dost flee from the hint of danger!",
	"Thou art an unjust wretch. Thou are a fulsome meddler!",
	"Thou art a self-serving Tufthunter. Thou deservest not my help, yet I grant it!",
	"Thou art a cad and a bounder. Thy presence is an affront. Thou art low as a slug!",
	"Thy spirit is weak and feeble. Thou dost not strive for Perfection!",
	"Thou art proud and vain. All other virtue in thee is a loss!",
	## tier 1 — karma 20..39
	"Thou art not an honest soul. Thou must live a more honest life to be an Avatar!",
	"Thou dost kill where there is no need and give too little unto others!",
	"Thou dost not display a great deal of Valor. Thou dost flee before the need!",
	"Thou art cruel and unjust. In time thou will suffer for thy crimes!",
	"Thou dost need to think more of the life of others and less of thy own!",
	"Thou dost not fight with honor but with malice and deceit!",
	"Thou dost not take time to care about thy inner being, a must to be an Avatar!",
	"Thou art too proud of thy little deeds. Humility is the root of all Virtue!",
	## tier 2 — karma 40..59
	"Thou hast made little progress on the paths of Honesty. Strive to prove thy worth!",
	"Thou hast not shown thy compassion well. Be more kind unto others!",
	"Thou art not yet a valiant warrior.  Fight to defeat evil and prove thyself!",
	"Thou hast not proven thyself to be just. Strive to do justice unto all things!",
	"Thy sacrifice is small. Give of thy life's blood so that others may live.",
	"Thou dost need to show thyself to be more honorable.  The path lies before thee!",
	"Strive to know and master more of thine inner being. Meditation lights the path!",
	"Thy progress on this path is most uncertain. Without Humility thou art empty!",
	## tier 3 — karma 60..98
	"Thou dost seem to be an honest soul.  Continued honesty will reward thee!",
	"Thou dost show thy compassion well.  Continued goodwill should be thy guide!",
	"Thou art showing Valor in the face of danger. Strive to become yet more so!",
	"Thou dost seem fair and just. Strive to uphold Justice even more sternly!",
	"Thou art giving of thyself in some ways. Seek ye now to find yet more!",
	"Thou dost seem to be Honorable in nature.  Seek to bring Honor upon others as well!",
	"Thou art doing well on the path to inner sight continue to seek the inner light!",
	"Thou dost seem a humble soul.  Thou art setting strong stones to build virtues upon!",
	## tier 4 — karma 99 (before Elevation)
	"Thou art truly an honest soul. Seek ye now to reach Elevation!",
	"Compassion is a virtue that thou hast shown well.  Seek ye now Elevation!",
	"Thou art a truly valiant warrior. Seek ye now Elevation in the virtue of valor!",
	"Thou art just and fair.  Seek ye now the Elevation!",
	"Thou art giving and good.  Thy self-sacrifice is great.  Seek now Elevation!",
	"Thou hast proven thyself to be Honorable. Seek ye now for the Elevation!",
	"Spirituality is in thy nature. Seek ye now the Elevation!",
	"Thy Humility shines bright upon thy being. Seek ye now for Elevation!",
]

const SPEAK_ONLY_WITH := "The Seer says: I will speak only with "
const RETURN_WHEN := ".\nReturn when "
const IS_REVIVED := " is revived!"
const WELCOME := "Welcome, "
const GREETING := (
	"I am Hawkwind, Seer of Souls. I see that which is within thee and drives "
	+ "thee to deeds of good or evil..."
)
const FIRST_PROMPT := "For what path dost thou seek enlightenment?"
const AGAIN_PROMPT := "Hawkwind asks: What other path seeks clarity?"
const DEFAULT := "He says: That is not a subject for enlightenment."
const ALREADY_AVATAR := (
	"He says:\nThou hast become a partial Avatar in that attribute. "
	+ "Thou need not my insights."
)
const GO_TO_SHRINE := "Go to the Shrine and meditate for three Cycles!"
const BYE := "Hawkwind says: Fare thee well and may thou complete the Quest of the Avatar!"


static func party_leader_can_speak() -> bool:
	## xu4: Hawkwind speaks only with living, awakened party member #1.
	var mid := GameState.party_member_at(0)
	if mid < 0:
		return false
	if GameState.is_class_dead(mid):
		return false
	return GameState.status_of_class(mid) != PartyRoster.Status.SLEEPING


static func leader_name() -> String:
	var n := GameState.party_member_display_name(0).strip_edges()
	return n if not n.is_empty() else "Avatar"


static func refuse_for_unconscious() -> String:
	var nm := leader_name()
	return SPEAK_ONLY_WITH + nm + RETURN_WHEN + nm + IS_REVIVED


static func intro_lines() -> Array[String]:
	return [
		WELCOME + leader_name(),
		GREETING,
		FIRST_PROMPT,
	]


static func match_virtue(typed: String) -> int:
	## xu4: strnicmp(input, virtueName, 4).
	var got := typed.strip_edges().to_lower()
	if got.is_empty():
		return -1
	for v in range(8):
		var want := Virtues.name_of(v, "en").to_lower()
		var n := mini(4, want.length())
		if got.length() < n:
			continue
		if got.substr(0, n) == want.substr(0, n):
			return v
	return -1


static func advice_for_virtue(virtue: int) -> String:
	## ScummVM hawkwindGetAdvice — tier by current karma of that virtue.
	if virtue < 0 or virtue >= 8:
		return DEFAULT
	var level := 50
	if virtue < GameState.karma.size():
		level = int(GameState.karma[virtue])
	if level == 0:
		return ALREADY_AVATAR
	var idx := 0
	if level < 80:
		idx = int(level / 20) * 8 + virtue
	elif level < 99:
		idx = 3 * 8 + virtue
	else:
		## Ready for shrine Elevation.
		idx = 4 * 8 + virtue
		return ADVICE[idx] + " " + GO_TO_SHRINE
	if idx < 0 or idx >= ADVICE.size():
		return DEFAULT
	return ADVICE[idx]


static func reply_to_interest(typed: String) -> String:
	var key := typed.strip_edges().to_lower()
	if key.is_empty() or key == "bye":
		return "" ## empty / bye → end session
	var v := match_virtue(typed)
	if v < 0:
		return DEFAULT
	return advice_for_virtue(v)


static func highlight_keywords() -> Array[String]:
	var out: Array[String] = []
	for v in range(8):
		var nm := Virtues.name_of(v, "en")
		out.append(nm)
		if nm.length() >= 4:
			out.append(nm.substr(0, 4))
	out.append("bye")
	return out


static func grant_visit_karma() -> void:
	## xu4 ResponsePart HAWKWIND → KA_HAWKWIND (same +3 Spirituality as meditation).
	GameState.adjust_karma_meditation()
