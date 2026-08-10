class_name LordBritish
extends RefCounted

## xu4 / ScummVM U4LBDialogueLoader + AVATAR.EXE `lb_keywords` / `lb_text`.
## help = quest-progress dynamic; heal = art-thou-well confirm + party heal;
## return visits run ADVANCELEVELS (XP→max HP/stats).

const KEYWORDS: Array[String] = [
	"name", "look", "job", "truth", "love", "courage", "honesty", "compassion",
	"valor", "justice", "sacrifice", "honor", "spirituality", "humility",
	"pride", "avatar", "quest", "britannia", "ankh", "abyss", "mondain",
	"minax", "exodus", "virtue",
]

## Korean (and extra) stems parallel to KEYWORDS — NFC matched via TalkLocale.
const KEYWORDS_KO: Array = [
	["이름", "성명", "성함"],
	["모습", "외모"],
	["직업"],
	["진리"],
	["사랑"],
	["용기"],
	["정직"],
	["연민"],
	["용맹"],
	["정의"],
	["희생"],
	["명예"],
	["영성"],
	["겸손"],
	["자만", "오만"],
	["아바타"],
	["퀘스트", "임무"],
	["브리타니아"],
	["앙크"],
	["심연", "어비스"],
	["몬데인"],
	["미낙스"],
	["엑소더스"],
	["미덕"],
]

const TEXT_EN: Array[String] = [
	"He says: My name is Lord British, Sovereign of all Britannia!",
	"Thou see the King with the Royal Sceptre.",
	"He says: I rule all Britannia, and shall do my best to help thee!",
	"He says: Many truths can be learned at the Lycaeum. It lies on the northwestern shore of Verity Isle!",
	"He says: Look for the meaning of Love at Empath Abbey. The Abbey sits on the western edge of the Deep Forest!",
	"He says: Serpent's Castle on the Isle of Deeds is where Courage should be sought!",
	"He says: The fair towne of Moonglow on Verity Isle is where the virtue of Honesty thrives!",
	"He says: The bards in the towne of Britain are well versed in the virtue of Compassion!",
	"He says: Many valiant fighters come from Jhelom in the Valarian Isles!",
	"He says: In the city of Yew, in the Deep Forest, Justice is served!",
	"He says: Minoc, towne of self-sacrifice, lies on the eastern shores of Lost Hope Bay!",
	"He says: The Paladins who strive for Honor are oft seen in Trinsic, north of the Cape of Heroes!",
	"He says: In Skara Brae the Spiritual path is taught. Find it on an isle near Spiritwood!",
	(
		"He says: Humility is the foundation of Virtue! The ruins of proud Magincia are a testimony "
		+ "unto the Virtue of Humility! Find the Ruins of Magincia far off the shores of Britannia, "
		+ "on a small isle in the vast Ocean!"
	),
	(
		"He says: Of the eight combinations of Truth, Love and Courage, that which contains neither "
		+ "Truth, Love nor Courage is Pride. Pride being not a Virtue must be shunned in favor of "
		+ "Humility, the Virtue which is the antithesis of Pride!"
	),
	(
		"Lord British says: To be an Avatar is to be the embodiment of the Eight Virtues. "
		+ "It is to live a life constantly and forever in the Quest to better thyself and the "
		+ "world in which we live."
	),
	(
		"Lord British says: The Quest of the Avatar is to know and become the embodiment of the "
		+ "Eight Virtues of Goodness! It is known that all who take on this Quest must prove "
		+ "themselves by conquering the Abyss and Viewing the Codex of Ultimate Wisdom!"
	),
	(
		"He says: Even though the Great Evil Lords have been routed evil yet remains in Britannia. "
		+ "If but one soul could complete the Quest of the Avatar, our people would have a new "
		+ "hope, a new goal for life. There would be a shining example that there is more to life "
		+ "than the endless struggle for possessions and gold!"
	),
	(
		"He says: The Ankh is the symbol of one who strives for Virtue. Keep it with thee at all "
		+ "times for by this mark thou shalt be known!"
	),
	(
		"He says: The Great Stygian Abyss is the darkest pocket of evil remaining in Britannia! "
		+ "It is said that in the deepest recesses of the Abyss is the Chamber of the Codex! "
		+ "It is also said that only one of highest Virtue may enter this Chamber, one such as an Avatar!!!"
	),
	"He says: Mondain is dead!",
	"He says: Minax is dead!",
	"He says: Exodus is dead!",
	(
		"He says: The Eight Virtues of the Avatar are: Honesty, Compassion, Valor, Justice, "
		+ "Sacrifice, Honor, Spirituality, and Humility!"
	),
]

const TEXT_KO: Array[String] = [
	"그가 말하길: 내 이름은 로드 브리티시, 온 브리타니아의 주권자요!",
	"왕홀을 든 왕을 본다.",
	"그가 말하길: 나는 온 브리타니아를 다스리며, 그대를 돕기 위해 최선을 다하리!",
	"그가 말하길: 많은 진리를 리케이엄에서 배울 수 있소. 베리티 섬 북서쪽 해안에 있소!",
	"그가 말하길: 사랑의 뜻을 공감 대수도원에서 찾으시오. 수도원은 깊은 숲 서쪽 끝에 있소!",
	"그가 말하길: 업적의 섬에 있는 뱀성에서 용기를 구해야 하오!",
	"그가 말하길: 베리티 섬의 고운 마을 문글로우에서 정직의 미덕이 번성하오!",
	"그가 말하길: 브리튼 마을의 음유시인들은 연민의 미덕에 정통하오!",
	"그가 말하길: 많은 용맹한 전사들이 발라리안 제도의 젤롬에서 오오!",
	"그가 말하길: 깊은 숲의 도시 유에서 정의가 행해지오!",
	"그가 말하길: 자기희생의 마을 미녹은 잃어버린 희망 만 동쪽 해안에 있소!",
	"그가 말하길: 명예를 기리는 성기사들은 영웅의 곶 북쪽 트린식에서 자주 보이오!",
	"그가 말하길: 스카라 브레에서는 영성의 길을 가르치오. 영혼의 숲 근처 섬에서 찾으시오!",
	(
		"그가 말하길: 겸손은 미덕의 기초요! 자만의 마진시아 폐허는 겸손의 미덕에 대한 "
		+ "증언이오! 마진시아 폐허는 브리타니아 해안에서 멀리, 광대한 대양의 "
		+ "작은 섬에 있소!"
	),
	(
		"그가 말하길: 진리·사랑·용기의 여덟 가지 조합 중, 진리도 사랑도 용기도 없는 "
		+ "것이 자만이오. 자만은 미덕이 아니니 피하고, 자만의 반대인 겸손을 "
		+ "택해야 하오!"
	),
	(
		"로드 브리티시 말하길: 아바타가 된다는 것은 여덟 미덕의 구현이 되는 것이오. "
		+ "끊임없이, 영원히 자신과 우리가 사는 세상을 더 낫게 하려는 퀘스트 속에서 "
		+ "살아가는 것이오."
	),
	(
		"로드 브리티시 말하길: 아바타의 퀘스트는 선함의 여덟 미덕을 알고 그 구현이 되는 "
		+ "것이오! 이 퀘스트에 나선 모든 이는 심연을 정복하고 궁극의 지혜의 "
		+ "코덱스를 봄으로써 자신을 증명해야 함이 알려져 있소!"
	),
	(
		"그가 말하길: 위대한 악의 군주들이 물리쳐졌어도 악은 아직 브리타니아에 남았소. "
		+ "단 한 영혼이라도 아바타의 퀘스트를 완수한다면, 우리 백성에게 새로운 희망과 "
		+ "삶의 목표가 생길 것이오. 소유와 금을 위한 끝없는 투쟁 그 너머에 "
		+ "삶이 있음을 비추는 빛나는 본보기가 되리!"
	),
	(
		"그가 말하길: 앙크는 미덕을 기리는 이의 상징이오. 항상 지니시오—그 표로 "
		+ "그대가 알려지리!"
	),
	(
		"그가 말하길: 위대한 스티지안 심연은 브리타니아에 남은 가장 어두운 악의 소굴이오! "
		+ "심연 가장 깊은 곳에 코덱스의 방이 있다고 전해지오! 가장 높은 미덕을 지닌 이, "
		+ "곧 아바타 같은 이만이 그 방에 들 수 있다고도 하오!!!"
	),
	"그가 말하길: 몬데인은 죽었소!",
	"그가 말하길: 미낙스는 죽었소!",
	"그가 말하길: 엑소더스는 죽었소!",
	(
		"그가 말하길: 아바타의 여덟 미덕은 정직, 연민, 용맹, 정의, "
		+ "희생, 명예, 영성, 겸손이오!"
	),
]


static func is_korean() -> bool:
	if Engine.get_main_loop() != null:
		var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
		if gs != null:
			return str(gs.language) == "ko"
	return false


static func _t(en: String, ko: String) -> String:
	return ko if is_korean() else en


static func leader_name() -> String:
	var n := GameState.party_member_display_name(0).strip_edges()
	if not n.is_empty():
		return n
	return _t("Avatar", "아바타")


static func member_name(slot: int) -> String:
	var n := GameState.party_member_display_name(slot).strip_edges()
	if not n.is_empty():
		return n
	return _t("Adventurer", "모험가")


static func farewell() -> String:
	if GameState.party_size() > 1:
		return _t(
			"Lord British says: Fare thee well my friends!",
			"로드 브리티시 말하길: 친구들이여, 평안히 가시오!"
		)
	return _t(
		"Lord British says: Fare thee well my friend!",
		"로드 브리티시 말하길: 친구여, 평안히 가시오!"
	)


static func revive_leader_if_dead() -> String:
	## xu4 talkAt — LB resurrects a dead party #1 before discourse.
	var mid := GameState.party_member_at(0)
	if mid < 0 or not GameState.is_class_dead(mid):
		return ""
	GameState.healer_heal_member(0, "resurrect")
	GameState.healer_heal_member(0, "fullheal")
	return _t(
		"%s, Thou shalt live again!" % leader_name(),
		"%s, 그대는 다시 살리라!" % leader_name()
	)


static func ask_of_me() -> String:
	return _t("What would thou ask of me?", "내게 무엇을 묻겠소?")


static func prompt() -> String:
	return _t("What else?", "또 무엇이오?")


static func default_reply() -> String:
	return _t(
		"He says: I cannot help thee with that.",
		"그가 말하길: 그것으로는 도울 수 없소."
	)


static func heal_well() -> String:
	return _t(
		"He says: I am well, thank ye.",
		"그가 말하길: 나는 건강하오, 고맙소."
	)


static func heal_ask() -> String:
	return _t("He asks: Art thou well?", "그가 묻노라: 그대는 건강하오?")


static func heal_good() -> String:
	return _t("He says: That is good.", "그가 말하길: 좋소.")


static func heal_wounds() -> String:
	return _t(
		"He says: Let me heal thy wounds!",
		"그가 말하길: 그대의 상처를 치유해 주겠소!"
	)


static func heal_bad_answer() -> String:
	return _t(
		"That I cannot help thee with.",
		"그것으로는 도울 수 없소."
	)


static func intro_lines() -> Array[String]:
	## Dynamic intro + side effects (lb_intro / level check messages).
	var out: Array[String] = []
	var n0 := leader_name()
	if GameState.lb_intro:
		var n := GameState.party_size()
		if n == 1:
			out.append(
				_t(
					"Lord British says:  Welcome\n%s!" % n0,
					"로드 브리티시 말하길:  환영하오\n%s!" % n0
				)
			)
		elif n == 2:
			out.append(
				_t(
					"Lord British says:  Welcome\n%s and thee also %s!"
					% [n0, member_name(1)],
					"로드 브리티시 말하길:  환영하오\n%s, 그리고 너도 %s!"
					% [n0, member_name(1)]
				)
			)
		else:
			var wagwa := "와"
			if is_korean() and Engine.get_main_loop() != null:
				var loc = Engine.get_main_loop().root.get_node_or_null("/root/Locale")
				if loc != null and loc.has_method("ko_wa_gwa"):
					wagwa = str(loc.ko_wa_gwa(n0))
			out.append(
				_t(
					"Lord British says:  Welcome\n%s and thy worthy Adventurers!" % n0,
					"로드 브리티시 말하길:  환영하오\n%s%s 그대의 훌륭한 모험가들이여!" % [n0, wagwa]
				)
			)
		for line in GameState.lord_british_check_levels():
			out.append(line)
		out.append(ask_of_me())
	else:
		out.append(
			_t(
				"Lord British rises and says: At long last!\n"
				+ n0
				+ " thou hast come!  We have waited such a long, long time...",
				"로드 브리티시가 일어나 말하길: 마침내!\n"
				+ n0
				+ " 그대가 왔소!  우리는 그토록 오래, 오래 기다렸소..."
			)
		)
		out.append(
			_t(
				"Lord British sits and says: A new age is upon Britannia. The great evil Lords are gone "
				+ "but our people lack direction and purpose in their lives...\n\n"
				+ "A champion of virtue is called for. Thou may be this champion, but only time shall "
				+ "tell.  I will aid thee any way that I can!",
				"로드 브리티시가 앉아 말하길: 브리타니아에 새 시대가 왔소. 위대한 악의 군주들은 "
				+ "사라졌으나 우리 백성은 삶의 방향과 목적이 부족하오...\n\n"
				+ "미덕의 챔피언이 필요하오. 그대가 그 챔피언일지 모르나, 오직 시간만이 "
				+ "알려 주리.  내가 할 수 있는 모든 방법으로 돕겠소!"
			)
		)
		out.append(_t("How may I help thee?", "어찌 도와 드릴까?"))
		GameState.lb_intro = true
	return out


static func help_text() -> String:
	## ScummVM lordBritishGetHelp — first matching quest gate wins.
	var full_avatar := true
	var partial_avatar := false
	for v in 8:
		var k := 50
		if v < GameState.karma.size():
			k = int(GameState.karma[v])
		if k == 0:
			partial_avatar = true
		else:
			full_avatar = false

	var body_en := ""
	var body_ko := ""
	if GameState.moves <= 1000:
		body_en = (
			"To survive in this hostile land thou must first know thyself! Seek ye to master thy "
			+ "weapons and thy magical ability!\n\n"
			+ "Take great care in these thy first travels in Britannia.\n\n"
			+ "Until thou dost well know thyself, travel not far from the safety of the townes!"
		)
		body_ko = (
			"이 적대적인 땅에서 살아남으려면 먼저 자신을 알아야 하오! 무기와 마법 능력을 "
			+ "익히도록 애쓰시오!\n\n"
			+ "브리타니아에서의 이 첫 여행에서 각별히 조심하시오.\n\n"
			+ "자신을 잘 알기 전에는 마을들의 안전에서 멀리 가지 마시오!"
		)
	elif GameState.party_size() == 1:
		body_en = (
			"Travel not the open lands alone. There are many worthy people in the diverse townes "
			+ "whom it would be wise to ask to Join thee!\n\n"
			+ "Build thy party unto eight travellers, for only a true leader can win the Quest!"
		)
		body_ko = (
			"드넓은 땅을 혼자 여행하지 마시오. 여러 마을에는 그대와 함께하기를 "
			+ "청할 만한 훌륭한 이들이 많소!\n\n"
			+ "일행을 여덟 여행자로 꾸리시오—참된 지도자만이 퀘스트를 이길 수 있소!"
		)
	elif GameState.runes == 0:
		body_en = (
			"Learn ye the paths of virtue. Seek to gain entry unto the eight shrines!\n\n"
			+ "Find ye the Runes, needed for entry into each shrine, and learn each chant or "
			+ "\"Mantra\" used to focus thy meditations.\n\n"
			+ "Within the Shrines thou shalt learn of the deeds which show thy inner virtue or "
			+ "vice!\n\n"
			+ "Choose thy path wisely for all thy deeds of good and evil are remembered and can "
			+ "return to hinder thee!"
		)
		body_ko = (
			"미덕의 길을 배우시오. 여덟 신전에 들 수 있도록 애쓰시오!\n\n"
			+ "각 신전에 들려면 필요한 룬을 찾고, 명상을 모을 때 쓰는 진언, 곧 "
			+ "「만트라」를 배우시오.\n\n"
			+ "신전 안에서 내면의 미덕이나 악덕을 드러내는 행위를 배우게 되리!\n\n"
			+ "길을 현명히 택하시오—모든 선과 악의 행위는 기억되어 다시 그대를 "
			+ "가로막을 수 있소!"
		)
	elif not partial_avatar:
		body_en = (
			"Visit the Seer Hawkwind often and use his wisdom to help thee prove thy virtue.\n\n"
			+ "When thou art ready, Hawkwind will advise thee to seek the Elevation unto partial "
			+ "Avatarhood in a virtue.\n\n"
			+ "Seek ye to become a partial Avatar in all eight virtues, for only then shalt thou "
			+ "be ready to seek the codex!"
		)
		body_ko = (
			"예언자 호크윈드를 자주 찾아 그 지혜로 미덕을 증명하시오.\n\n"
			+ "준비되면 호크윈드가 어떤 미덕에서 부분 아바타로의 승화를 구하라 하리.\n\n"
			+ "여덟 미덕 모두에서 부분 아바타가 되라—그래야만 코덱스를 구할 준비가 "
			+ "되오!"
		)
	elif GameState.stones == 0:
		body_en = (
			"Go ye now into the depths of the dungeons. Therein recover the 8 colored stones from "
			+ "the altar pedestals in the halls of the dungeons.\n\n"
			+ "Find the uses of these stones for they can help thee in the Abyss!"
		)
		body_ko = (
			"이제 던전 깊숙이 들어가시오. 거기서 던전 회랑의 제단 받침대에서 "
			+ "여덟 색 돌을 회수하시오.\n\n"
			+ "그 돌들의 쓰임을 찾으시오—심연에서 도움되리!"
		)
	elif not full_avatar:
		body_en = (
			"Thou art doing very well indeed on the path to Avatarhood! Strive ye to achieve the "
			+ "Elevation in all eight virtues!"
		)
		body_ko = (
			"아바타의 길에서 참으로 잘하고 있소! 여덟 미덕 모두에서 승화를 "
			+ "이루도록 애쓰시오!"
		)
	elif (
		not GameState.has_item_flag(GameState.ITEM_BELL)
		or not GameState.has_item_flag(GameState.ITEM_BOOK)
		or not GameState.has_item_flag(GameState.ITEM_CANDLE)
	):
		body_en = (
			"Find ye the Bell, Book and Candle!  With these three things, one may enter the Great "
			+ "Stygian Abyss!"
		)
		body_ko = (
			"종·책·초를 찾으시오!  이 세 가지로 위대한 스티지안 "
			+ "심연에 들 수 있소!"
		)
	elif (
		not GameState.has_item_flag(GameState.ITEM_KEY_C)
		or not GameState.has_item_flag(GameState.ITEM_KEY_L)
		or not GameState.has_item_flag(GameState.ITEM_KEY_T)
	):
		body_en = (
			"Before thou dost enter the Abyss thou shalt need the Key of Three Parts, and the "
			+ "Word of Passage.\n\n"
			+ "Then might thou enter the Chamber of the Codex of Ultimate Wisdom!"
		)
		body_ko = (
			"심연에 들기 전에 세 조각의 열쇠와 통행의 말이 "
			+ "필요하오.\n\n"
			+ "그래야 궁극의 지혜의 코덱스의 방에 들 수 있으리!"
		)
	else:
		body_en = (
			"Thou dost now seem ready to make the final journey into the dark Abyss! Go only with "
			+ "a party of eight!\n\n"
			+ "Good Luck, and may the powers of good watch over thee on this thy most perilous "
			+ "endeavor!\n\n"
			+ "The hearts and souls of all Britannia go with thee now. Take care, my friend."
		)
		body_ko = (
			"이제 어두운 심연으로의 마지막 여정을 떠날 준비가 된 듯하오! "
			+ "반드시 여덟의 일행과 함께 가시오!\n\n"
			+ "행운을 빌며, 이 가장 위험한 시도에서 선의 힘이 그대를 지켜 주기를!\n\n"
			+ "온 브리타니아의 마음과 영혼이 이제 그대와 함께하오. 조심하시오, 친구여."
		)
	if is_korean():
		return "그가 말하길: " + body_ko
	return "He says: " + body_en


static func match_keyword(typed: String) -> int:
	## Dialogue::Keyword — 4-letter EN prefix (or full short keyword) + Korean stems.
	var got := TalkLocale.normalize_interest(typed)
	if got.is_empty():
		return -1
	for i in KEYWORDS.size():
		var want := TalkLocale.normalize_interest(KEYWORDS[i])
		var n := mini(4, want.length())
		if n > 0 and got.length() >= n and got.substr(0, n) == want.substr(0, n):
			return i
		if i < KEYWORDS_KO.size():
			for stem in KEYWORDS_KO[i]:
				var ks := TalkLocale.normalize_interest(str(stem))
				if ks.is_empty():
					continue
				if got.length() >= ks.length() and got.substr(0, ks.length()) == ks:
					return i
	return -1


## Reply kinds for the world talk state machine.
## "bye" | "heal" | "help" | "text"


static func reply_kind(typed: String) -> String:
	var key := TalkLocale.normalize_interest(typed)
	if key.is_empty() or TalkLocale.match_builtin_interest(typed) == "bye":
		return "bye"
	## Classic LB keyword is "heal" (not all health synonyms).
	if key.begins_with("heal") or TalkLocale.interest_matches_any(typed, ["치유", "힐", "회복"]):
		return "heal"
	if key.begins_with("help") or TalkLocale.interest_matches_any(typed, ["도움", "도움말", "헬프"]):
		return "help"
	if match_keyword(typed) >= 0:
		return "text"
	return "text" ## still text; may be DEFAULT


static func reply_text(typed: String) -> String:
	var key := TalkLocale.normalize_interest(typed)
	if key.begins_with("help") or TalkLocale.interest_matches_any(typed, ["도움", "도움말", "헬프"]):
		return help_text()
	var idx := match_keyword(typed)
	var table: Array[String] = TEXT_KO if is_korean() else TEXT_EN
	if idx < 0 or idx >= table.size():
		return default_reply()
	return table[idx]


static func highlight_keywords() -> Array[String]:
	var out: Array[String] = KEYWORDS.duplicate()
	for group in KEYWORDS_KO:
		for stem in group:
			var s := str(stem)
			if not s.is_empty() and not out.has(s):
				out.append(s)
	out.append("help")
	out.append("heal")
	out.append("bye")
	for alias in ["도움", "치유", "힐", "회복", "안녕", "작별", "바이"]:
		if not out.has(alias):
			out.append(alias)
	return out


static func heal_party() -> void:
	## xu4 FULLHEAL after "Let me heal thy wounds!" — cure + full HP, not resurrect.
	GameState.lord_british_heal_party()
