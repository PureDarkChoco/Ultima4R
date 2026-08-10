class_name Hawkwind
extends RefCounted

## xu4 / ScummVM U4HWDialogueLoader + AVATAR.EXE hawkwind string table.
## Player asks about each virtue (4-letter EN prefix / Korean virtue name); seer gives tiered karma advice.
## Intro awards KA_HAWKWIND Spirituality (+3 on virtueIncreaseTimeout).

## 5 tiers × 8 virtues. Indices match ScummVM `hawkwindText[(level/20)*8 + v]`.
const ADVICE_EN: Array[String] = [
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

const ADVICE_KO: Array[String] = [
	## tier 0 — karma 1..19
	"그대는 도둑이며 악한이오. 결코 아바타가 될 수 없소!",
	"그대는 차갑고 잔인한 흉악한이오. 그 죄로 감옥에 가야 마땅하오!",
	"그대는 겁쟁이요, 위험의 기미만 있어도 달아나는구나!",
	"그대는 불의한 비참한 자요. 지나친 참견꾼이오!",
	"그대는 제 잇속만 챙기는 아첨꾼이오. 도울 자격 없으나 그래도 도우오!",
	"그대는 비열하고 상스러운 자요. 존재 자체가 모욕이오. 달팽이처럼 천하오!",
	"그대의 영혼은 약하고 허약하오. 완벽을 위해 애쓰지 않는구나!",
	"그대는 오만하고 허영에 차 있소. 그대 안의 다른 모든 미덕은 헛것이오!",
	## tier 1 — karma 20..39
	"그대는 정직한 영혼이 아니오. 아바타가 되려면 더 정직하게 살아야 하오!",
	"필요 없이 죽이고 남에게 너무 적게 베푸는구나!",
	"용맹을 거의 보이지 않소. 필요할 때 앞에서 달아나는구나!",
	"그대는 잔인하고 불의하오. 머지않아 죄로 고통받으리!",
	"자신의 삶보다 타인들의 삶을 더 생각해야 하오!",
	"명예가 아니라 악의와 기만으로 싸우는구나!",
	"아바타가 되려면 필수인 내면의 존재에 신경을 쓰지 않는구나!",
	"작은 행위에 너무 자만하오. 겸손은 모든 미덕의 뿌리오!",
	## tier 2 — karma 40..59
	"정직의 길에서 진전이 거의 없소. 그대의 가치를 증명하라!",
	"연민을 잘 보이지 못했소. 남에게 더 친절하시오!",
	"아직 용맹한 전사가 아니오. 악을 무찌르고 자신을 증명하라!",
	"아직 정의로움을 증명하지 못했소. 모든 일에 정의를 행하라!",
	"희생이 작소. 타인이 살 수 있도록 생명의 피를 내어 주라.",
	"더 명예롭게 보여야 하오. 길이 그대 앞에 있소!",
	"내면의 존재를 더 알고 다스리라. 명상이 길을 비추오!",
	"이 길의 진전은 매우 불확실하오. 겸손 없이는 비어 있소!",
	## tier 3 — karma 60..98
	"정직한 영혼으로 보이는구나. 계속된 정직이 상을 주리!",
	"연민을 잘 보이는구나. 계속된 선의가 길잡이가 되리!",
	"위험 앞에서 용맹을 보이고 있소. 더욱 그리 되도록 애쓰시오!",
	"공정하고 정의로워 보이는구나. 정의를 더욱 엄격히 지키라!",
	"여러 면에서 자신을 내어 주고 있소. 이제 더 많은 것을 구하라!",
	"타고난 것처럼 명예로워 보이는구나. 남에게도 명예를 가져오라!",
	"내적 시야의 길을 잘 걷고 있소. 계속하여 내면의 빛을 구하라!",
	"겸손한 영혼으로 보이는구나. 미덕을 세울 튼튼한 돌을 놓고 있소!",
	## tier 4 — karma 99 (before Elevation)
	"참으로 정직한 영혼이오. 이제 승화를 구하라!",
	"연민은 그대가 잘 보인 미덕이오. 이제 승화를 구하라!",
	"참으로 용맹한 전사요. 이제 용맹의 미덕에서 승화를 구하라!",
	"정의롭고 공정하오. 이제 승화를 구하라!",
	"베풀고 선량하오. 자기희생이 크오. 이제 승화를 구하라!",
	"명예로움을 증명했소. 이제 승화를 구하라!",
	"영성이 그대의 본성이오. 이제 승화를 구하라!",
	"그대의 겸손이 존재에 밝게 빛나오. 이제 승화를 구하라!",
]


static func is_korean() -> bool:
	if Engine.get_main_loop() != null:
		var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
		if gs != null:
			return str(gs.language) == "ko"
	return false


static func _t(en: String, ko: String) -> String:
	return ko if is_korean() else en


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
	if not n.is_empty():
		return n
	return _t("Avatar", "아바타")


static func refuse_for_unconscious() -> String:
	var nm := leader_name()
	if is_korean():
		var wagwa := "와"
		if Engine.get_main_loop() != null:
			var loc = Engine.get_main_loop().root.get_node_or_null("/root/Locale")
			if loc != null and loc.has_method("ko_wa_gwa"):
				wagwa = str(loc.ko_wa_gwa(nm))
		return "예언자 말하길: 나는 %s%s만 말하겠소.\n%s가 되살아나면 돌아오시오!" % [nm, wagwa, nm]
	return (
		"The Seer says: I will speak only with "
		+ nm
		+ ".\nReturn when "
		+ nm
		+ " is revived!"
	)


static func intro_lines() -> Array[String]:
	return [
		_t("Welcome, ", "환영하오, ") + leader_name(),
		_t(
			"I am Hawkwind, Seer of Souls. I see that which is within thee and drives "
			+ "thee to deeds of good or evil...",
			"나는 영혼의 예언자 호크윈드요. 그대 안에서 선과 악의 행위에 "
			+ "이끄는 것을 보오..."
		),
		_t(
			"For what path dost thou seek enlightenment?",
			"어떤 길의 깨달음을 구하시오?"
		),
	]


static func default_reply() -> String:
	return _t(
		"He says: That is not a subject for enlightenment.",
		"그가 말하길: 그것은 깨달음의 주제가 아니오."
	)


static func already_avatar() -> String:
	return _t(
		"He says:\nThou hast become a partial Avatar in that attribute. "
		+ "Thou need not my insights.",
		"그가 말하길:\n그대는 그 속성의 부분 아바타가 되었소. "
		+ "내 통찰이 필요 없소."
	)


static func go_to_shrine() -> String:
	return _t(
		"Go to the Shrine and meditate for three Cycles!",
		"사원에 가서 세 주기 동안 명상하라!"
	)


static func again_prompt() -> String:
	return _t(
		"Hawkwind asks: What other path seeks clarity?",
		"호크윈드가 묻노라: 또 어떤 길이 명료함을 구하나?"
	)


static func bye_line() -> String:
	return _t(
		"Hawkwind says: Fare thee well and may thou complete the Quest of the Avatar!",
		"호크윈드 말하길: 평안히 가시오, 아바타의 퀘스트를 완수하기를!"
	)


static func match_virtue(typed: String) -> int:
	## xu4: strnicmp(input, virtueName, 4) for English; full Korean virtue name (NFC/NFD-safe).
	var got := TalkLocale.normalize_interest(typed)
	if got.is_empty():
		return -1
	for v in range(8):
		var en := TalkLocale.normalize_interest(Virtues.name_of(v, "en"))
		var n := mini(4, en.length())
		if n > 0 and got.length() >= n and got.substr(0, n) == en.substr(0, n):
			return v
		var ko := TalkLocale.normalize_interest(Virtues.name_of(v, "ko"))
		if not ko.is_empty() and got.length() >= ko.length() and got.substr(0, ko.length()) == ko:
			return v
	return -1


static func advice_for_virtue(virtue: int) -> String:
	## ScummVM hawkwindGetAdvice — tier by current karma of that virtue.
	if virtue < 0 or virtue >= 8:
		return default_reply()
	var level := 50
	if virtue < GameState.karma.size():
		level = int(GameState.karma[virtue])
	if level == 0:
		return already_avatar()
	var table: Array[String] = ADVICE_KO if is_korean() else ADVICE_EN
	var idx := 0
	if level < 80:
		idx = int(level / 20) * 8 + virtue
	elif level < 99:
		idx = 3 * 8 + virtue
	else:
		## Ready for shrine Elevation.
		idx = 4 * 8 + virtue
		return table[idx] + " " + go_to_shrine()
	if idx < 0 or idx >= table.size():
		return default_reply()
	return table[idx]


static func reply_to_interest(typed: String) -> String:
	var key := TalkLocale.normalize_interest(typed)
	if key.is_empty() or TalkLocale.match_builtin_interest(typed) == "bye":
		return "" ## empty / bye → end session
	var v := match_virtue(typed)
	if v < 0:
		return default_reply()
	return advice_for_virtue(v)


static func highlight_keywords() -> Array[String]:
	var out: Array[String] = []
	for v in range(8):
		var en := Virtues.name_of(v, "en")
		out.append(en)
		if en.length() >= 4:
			out.append(en.substr(0, 4))
		var ko := Virtues.name_of(v, "ko")
		if not ko.is_empty() and not out.has(ko):
			out.append(ko)
	out.append("bye")
	for alias in ["안녕", "작별", "바이"]:
		if not out.has(alias):
			out.append(alias)
	return out


static func grant_visit_karma() -> void:
	## xu4 ResponsePart HAWKWIND → KA_HAWKWIND (same +3 Spirituality as meditation).
	GameState.adjust_karma_meditation()
