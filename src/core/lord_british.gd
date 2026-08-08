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

const TEXT: Array[String] = [
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

const DEFAULT := "He says: I cannot help thee with that."
const PROMPT := "What else?"
const ASK_OF_ME := "What would thou ask of me?"
const HEAL_WELL := "He says: I am well, thank ye."
const HEAL_ASK := "He asks: Art thou well?"
const HEAL_GOOD := "He says: That is good."
const HEAL_WOUNDS := "He says: Let me heal thy wounds!"
const HEAL_BAD_ANSWER := "That I cannot help thee with."


static func leader_name() -> String:
	var n := GameState.party_member_display_name(0).strip_edges()
	return n if not n.is_empty() else "Avatar"


static func member_name(slot: int) -> String:
	var n := GameState.party_member_display_name(slot).strip_edges()
	return n if not n.is_empty() else "Adventurer"


static func farewell() -> String:
	if GameState.party_size() > 1:
		return "Lord British says: Fare thee well my friends!"
	return "Lord British says: Fare thee well my friend!"


static func revive_leader_if_dead() -> String:
	## xu4 talkAt — LB resurrects a dead party #1 before discourse.
	var mid := GameState.party_member_at(0)
	if mid < 0 or not GameState.is_class_dead(mid):
		return ""
	GameState.healer_heal_member(0, "resurrect")
	GameState.healer_heal_member(0, "fullheal")
	return "%s, Thou shalt live again!" % leader_name()


static func intro_lines() -> Array[String]:
	## Dynamic intro + side effects (lb_intro / level check messages).
	var out: Array[String] = []
	if GameState.lb_intro:
		var n0 := leader_name()
		var n := GameState.party_size()
		if n == 1:
			out.append("Lord British says:  Welcome\n%s!" % n0)
		elif n == 2:
			out.append(
				"Lord British says:  Welcome\n%s and thee also %s!"
				% [n0, member_name(1)]
			)
		else:
			out.append(
				"Lord British says:  Welcome\n%s and thy worthy Adventurers!" % n0
			)
		for line in GameState.lord_british_check_levels():
			out.append(line)
		out.append(ASK_OF_ME)
	else:
		out.append(
			"Lord British rises and says: At long last!\n"
			+ leader_name()
			+ " thou hast come!  We have waited such a long, long time..."
		)
		out.append(
			"Lord British sits and says: A new age is upon Britannia. The great evil Lords are gone "
			+ "but our people lack direction and purpose in their lives...\n\n"
			+ "A champion of virtue is called for. Thou may be this champion, but only time shall "
			+ "tell.  I will aid thee any way that I can!"
		)
		out.append("How may I help thee?")
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

	var body := ""
	if GameState.moves <= 1000:
		body = (
			"To survive in this hostile land thou must first know thyself! Seek ye to master thy "
			+ "weapons and thy magical ability!\n\n"
			+ "Take great care in these thy first travels in Britannia.\n\n"
			+ "Until thou dost well know thyself, travel not far from the safety of the townes!"
		)
	elif GameState.party_size() == 1:
		body = (
			"Travel not the open lands alone. There are many worthy people in the diverse townes "
			+ "whom it would be wise to ask to Join thee!\n\n"
			+ "Build thy party unto eight travellers, for only a true leader can win the Quest!"
		)
	elif GameState.runes == 0:
		body = (
			"Learn ye the paths of virtue. Seek to gain entry unto the eight shrines!\n\n"
			+ "Find ye the Runes, needed for entry into each shrine, and learn each chant or "
			+ "\"Mantra\" used to focus thy meditations.\n\n"
			+ "Within the Shrines thou shalt learn of the deeds which show thy inner virtue or "
			+ "vice!\n\n"
			+ "Choose thy path wisely for all thy deeds of good and evil are remembered and can "
			+ "return to hinder thee!"
		)
	elif not partial_avatar:
		body = (
			"Visit the Seer Hawkwind often and use his wisdom to help thee prove thy virtue.\n\n"
			+ "When thou art ready, Hawkwind will advise thee to seek the Elevation unto partial "
			+ "Avatarhood in a virtue.\n\n"
			+ "Seek ye to become a partial Avatar in all eight virtues, for only then shalt thou "
			+ "be ready to seek the codex!"
		)
	elif GameState.stones == 0:
		body = (
			"Go ye now into the depths of the dungeons. Therein recover the 8 colored stones from "
			+ "the altar pedestals in the halls of the dungeons.\n\n"
			+ "Find the uses of these stones for they can help thee in the Abyss!"
		)
	elif not full_avatar:
		body = (
			"Thou art doing very well indeed on the path to Avatarhood! Strive ye to achieve the "
			+ "Elevation in all eight virtues!"
		)
	elif (
		not GameState.has_item_flag(GameState.ITEM_BELL)
		or not GameState.has_item_flag(GameState.ITEM_BOOK)
		or not GameState.has_item_flag(GameState.ITEM_CANDLE)
	):
		body = (
			"Find ye the Bell, Book and Candle!  With these three things, one may enter the Great "
			+ "Stygian Abyss!"
		)
	elif (
		not GameState.has_item_flag(GameState.ITEM_KEY_C)
		or not GameState.has_item_flag(GameState.ITEM_KEY_L)
		or not GameState.has_item_flag(GameState.ITEM_KEY_T)
	):
		body = (
			"Before thou dost enter the Abyss thou shalt need the Key of Three Parts, and the "
			+ "Word of Passage.\n\n"
			+ "Then might thou enter the Chamber of the Codex of Ultimate Wisdom!"
		)
	else:
		body = (
			"Thou dost now seem ready to make the final journey into the dark Abyss! Go only with "
			+ "a party of eight!\n\n"
			+ "Good Luck, and may the powers of good watch over thee on this thy most perilous "
			+ "endeavor!\n\n"
			+ "The hearts and souls of all Britannia go with thee now. Take care, my friend."
		)
	return "He says: " + body


static func match_keyword(typed: String) -> int:
	## Dialogue::Keyword — 4-letter prefix (or full short keyword).
	var got := typed.strip_edges().to_lower()
	if got.is_empty():
		return -1
	for i in KEYWORDS.size():
		var want: String = KEYWORDS[i]
		var n := mini(4, want.length())
		if got.length() < n:
			continue
		if got.substr(0, n) == want.substr(0, n):
			return i
	return -1


## Reply kinds for the world talk state machine.
## "bye" | "heal" | "text" (empty / bye / plain reply).


static func reply_kind(typed: String) -> String:
	var key := typed.strip_edges().to_lower()
	if key.is_empty() or key.begins_with("bye"):
		return "bye"
	if key.begins_with("heal"):
		return "heal"
	if key.begins_with("help"):
		return "help"
	if match_keyword(typed) >= 0:
		return "text"
	return "text" ## still text; may be DEFAULT


static func reply_text(typed: String) -> String:
	var key := typed.strip_edges().to_lower()
	if key.begins_with("help"):
		return help_text()
	var idx := match_keyword(typed)
	if idx < 0 or idx >= TEXT.size():
		return DEFAULT
	return TEXT[idx]


static func highlight_keywords() -> Array[String]:
	var out: Array[String] = KEYWORDS.duplicate()
	out.append("help")
	out.append("heal")
	out.append("bye")
	return out


static func heal_party() -> void:
	## xu4 FULLHEAL after "Let me heal thy wounds!" — cure + full HP, not resurrect.
	GameState.lord_british_heal_party()
