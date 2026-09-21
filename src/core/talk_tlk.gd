class_name TalkTlk
extends RefCounted

## Ultima IV city conversation (.TLK) — 288-byte records, max 16 NPCs.
## English script strings as stored in the original data (no localisation).

const _TalkLocale := preload("res://src/core/talk_locale.gd")

const RECORD_SIZE := 288
const MAX_NPCS := 16
const STR_COUNT := 12 ## name … topic2

## Question trigger after a keyword reply (file byte 0).
const QT_NONE := 0
const QT_JOB := 3
const QT_HEALTH := 4
const QT_KEYWORD1 := 5
const QT_KEYWORD2 := 6

## Dialogue reply kinds from keyword lookup.
const REPLY_NONE := 0
const REPLY_TOPIC1 := 1
const REPLY_TOPIC2 := 2
const REPLY_JOB := 3
const REPLY_HEALTH := 4

## Keyword highlight in NPC dialogue (not player input).
const KW_BBCODE := "[color=#f0c93a]"
const KW_BBCODE_END := "[/color]"
## Shop list letter keys: A-Sulfurous, B-Staff… (slightly cooler than keyword gold).
const SHOP_INDEX_BBCODE := "[color=#7ec8ff]"
const SHOP_INDEX_BBCODE_END := "[/color]"
## Shop catalog letter when no party member can equip a new one of that item.
const SHOP_INDEX_BAD_BBCODE := "[color=#e74c3c]"
const SHOP_INDEX_BAD_BBCODE_END := "[/color]"
## Shop verb emphasis (Buy / Sell).
const SHOP_ACTION_KEYS: Array[String] = ["Buy", "Sell"]
## Inline inventory icon in message log: BEGIN + 'w'|'a'|'r' + id + END.
const MSG_ICON_BEGIN := "\u0002"
const MSG_ICON_END := "\u0003"

## Phrase rewrites for en_us (classic U4 → modern English). Longest first.
## Nested Array of [from, to] string pairs (const-compatible in GDScript).
const _MODERN_PHRASES: Array = [
	["fare thee well", "farewell"],
	["never forget thy", "never forget your"],
	["i shall never", "I will never"],
	["oh thank thee", "oh thank you"],
	["thank thee", "thank you"],
	["thou hast not", "you do not have"],
	["thou dost not", "you do not"],
	["dost not", "do not"],
	["search ye not", "do not search"],
	["hast thou not", "have you not"],
	["dost thou not", "do you not"],
	["wilt thou not", "will you not"],
	["art thou not", "are you not"],
	["would thou", "would you"],
	["wouldst thou", "would you"],
	["shouldst thou", "should you"],
	["couldst thou", "could you"],
	["know ye the", "do you know the"],
	["know ye of", "do you know of"],
	["know ye", "do you know"],
	["seek ye to", "try to"],
	["seek ye now to", "now try to"],
	["seek ye now", "now seek"],
	["seek ye", "seek"],
	["interest thee in", "interest you in"],
	["cost thee", "cost you"],
	["aid thee", "aid you"],
	["thy spirit", "your spirit"],
	["thy purse", "your purse"],
	["thy blood", "your blood"],
	["thy life", "your life"],
	["thy ship", "your ship"],
	["own\na ship!", "own\na ship?"],
	["dost thou", "do you"],
	["hast thou", "have you"],
	["wilt thou", "will you"],
	["art thou", "are you"],
	["canst thou", "can you"],
	["mayest thou", "may you"],
	["mayst thou", "may you"],
	["shalt thou", "shall you"],
	["didst thou", "did you"],
	["thou hast", "you have"],
	["thou wilt", "you will"],
	["thou wouldst", "you would"],
	["thou shouldst", "you should"],
	["thou couldst", "you could"],
	["thou canst", "you can"],
	["thou mayest", "you may"],
	["thou mayst", "you may"],
	["thou shalt", "you shall"],
	["thou didst", "you did"],
	["thou looks", "you look"],
	["thou suffers", "you suffer"],
	["thou dost", "you"],
	["thou art", "you are"],
	["thou cannot", "you cannot"],
	["join thee", "join you"],
	["tell thee", "tell you"],
	["help thee", "help you"],
	["sell thee", "sell you"],
	["for thee", "for you"],
	["to thee", "to you"],
	["with thee", "with you"],
	["of thee", "of you"],
	["unto thee", "to you"],
	["upon thee", "upon you"],
	["on thee", "on you"],
	["from thee", "from you"],
	["about thee", "about you"],
	["care for thyself", "care for yourself"],
	["for thyself", "for yourself"],
	["of thyself", "of yourself"],
	["thine inner", "your inner"],
	["'twas", "it was"],
	["'tis", "it is"],
	["'twill", "it will"],
	["i hath", "I have"],
	["here ye arr", "here you are"],
	["ye arr", "you are"],
	["ye don't", "you don't"],
	["ye ", "you "],
]


static func strip_speaker_lead(text: String) -> String:
	## Overlay speech: drop "He says:" / "그 말하길:" so only the line remains.
	var t := text.strip_edges()
	if t.is_empty():
		return t
	var en := t.findn(" says:")
	if en >= 0:
		var head := t.substr(0, en)
		if not head.contains("\n") and head.length() <= 48:
			return t.substr(en + " says:".length()).strip_edges()
	var ko := t.find("말하길:")
	if ko >= 0:
		var head_ko := t.substr(0, ko)
		if not head_ko.contains("\n") and head_ko.length() <= 48:
			return t.substr(ko + "말하길:".length()).strip_edges()
	return t


static func present_script(text: String) -> String:
	## Original TLK is classic English. en_us modernizes; en_u4 keeps as-is;
	## ko uses city talk packs (TalkLocale) with classic keys from .TLK.
	if text.is_empty():
		return text
	if _TalkLocale.is_korean():
		return _TalkLocale.line(text)
	if not _wants_modern_en():
		return text
	return modernize_en(text)


static func _wants_modern_en() -> bool:
	## Prefer autoload when the game is running.
	if Engine.get_main_loop() != null:
		var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
		if gs != null:
			return str(gs.language) == "en_us"
	return true ## default project language is modern English


static func modernize_en(text: String) -> String:
	## Best-effort archaic → modern rewrite for spoken U4 lines.
	var s := text
	## Preserve newlines; work lowercase for match, re-apply casing loosely.
	for pair in _MODERN_PHRASES:
		s = _replace_ci(s, str(pair[0]), str(pair[1]))
	## Single-token rewrites (word-ish).
	s = _replace_word_ci(s, "thyself", "yourself")
	s = _replace_word_ci(s, "thine", "your")
	s = _replace_word_ci(s, "thy", "your")
	s = _replace_word_ci(s, "thee", "you")
	s = _replace_word_ci(s, "thou", "you")
	s = _replace_word_ci(s, "hath", "has")
	s = _replace_word_ci(s, "doth", "does")
	s = _replace_word_ci(s, "dost", "do")
	s = _replace_word_ci(s, "wilt", "will")
	s = _replace_word_ci(s, "shalt", "shall")
	s = _replace_word_ci(s, "art", "are") ## after "thou art" already handled
	s = _replace_word_ci(s, "canst", "can")
	s = _replace_word_ci(s, "mayest", "may")
	s = _replace_word_ci(s, "mayst", "may")
	s = _replace_word_ci(s, "didst", "did")
	s = _replace_word_ci(s, "wouldst", "would")
	s = _replace_word_ci(s, "shouldst", "should")
	s = _replace_word_ci(s, "couldst", "could")
	s = _replace_word_ci(s, "unto", "to")
	s = _replace_word_ci(s, "yea", "yes")
	s = _replace_word_ci(s, "nay", "no")
	s = _replace_word_ci(s, "ye", "you")
	s = _replace_word_ci(s, "wouldst", "would")
	s = _replace_word_ci(s, "shouldst", "should")
	s = _replace_word_ci(s, "couldst", "could")
	## Clean doubled "you you" from "thou dost" → "you" + leftover (rare).
	s = _replace_ci(s, "you you ", "you ")
	s = _replace_ci(s, "You you ", "You ")
	## Residual agreement after thou→you on 3rd-person verbs in classic stock lines.
	s = _replace_ci(s, "you looks ", "you look ")
	s = _replace_ci(s, "You looks ", "You look ")
	s = _replace_ci(s, "you suffers ", "you suffer ")
	s = _replace_ci(s, "You suffers ", "You suffer ")
	return s


static func _replace_ci(hay: String, needle: String, repl: String) -> String:
	if needle.is_empty() or hay.is_empty():
		return hay
	var out := ""
	var i := 0
	var lower := hay.to_lower()
	var n := needle.to_lower()
	var nlen := n.length()
	while i < hay.length():
		if i + nlen <= hay.length() and lower.substr(i, nlen) == n:
			## Preserve capitalisation of the first char of the match.
			var piece := repl
			if hay.unicode_at(i) >= 65 and hay.unicode_at(i) <= 90 and not piece.is_empty():
				piece = piece.substr(0, 1).to_upper() + piece.substr(1)
			out += piece
			i += nlen
		else:
			out += hay[i]
			i += 1
	return out


static func _replace_word_ci(hay: String, word: String, repl: String) -> String:
	## Match word with non-letter on both sides (or string edges).
	if word.is_empty() or hay.is_empty():
		return hay
	var out := ""
	var i := 0
	var lower := hay.to_lower()
	var w := word.to_lower()
	var wlen := w.length()
	while i < hay.length():
		if i + wlen <= hay.length() and lower.substr(i, wlen) == w:
			var before_ok := i == 0 or not _is_word_char(hay.unicode_at(i - 1))
			var after_i := i + wlen
			var after_ok := after_i >= hay.length() or not _is_word_char(hay.unicode_at(after_i))
			if before_ok and after_ok:
				var piece := repl
				if hay.unicode_at(i) >= 65 and hay.unicode_at(i) <= 90 and not piece.is_empty():
					piece = piece.substr(0, 1).to_upper() + piece.substr(1)
				out += piece
				i += wlen
				continue
		out += hay[i]
		i += 1
	return out


## One NPC conversation block after loading.
class Entry:
	var ask_after: int = 0
	var question_humility: bool = false
	var turn_away: int = 0
	var name: String = ""
	var pronoun: String = ""
	var look: String = ""
	var job: String = ""
	var health: String = ""
	var response1: String = ""
	var response2: String = ""
	var question: String = ""
	var yes: String = ""
	var no: String = ""
	var topic1: String = ""
	var topic2: String = ""

	func highlight_keywords(city_id: String = "") -> Array[String]:
		## Words tinted in NPC speech when they appear (player interest keywords).
		## Topics are often 4-letter stems (PLAY/COMP); expand a few common full forms.
		var out: Array[String] = []
		var seen: Dictionary = {}
		for t: String in [topic1, topic2]:
			if _TalkLocale.topic_omitted(t, name, city_id):
				continue
			_add_kw(out, seen, t)
			var tl := t.strip_edges().to_lower()
			if tl == "comp":
				_add_kw(out, seen, "compassion")
				_add_kw(out, seen, "compassionate")
			elif tl == "play":
				_add_kw(out, seen, "playing")
			elif tl == "heal":
				_add_kw(out, seen, "health")
				_add_kw(out, seen, "healing")
			elif tl == "danc":
				_add_kw(out, seen, "dance")
				_add_kw(out, seen, "dancing")
			elif tl == "begg":
				_add_kw(out, seen, "beggar")
				_add_kw(out, seen, "beggars")
			elif tl == "fort":
				_add_kw(out, seen, "fortune")
				_add_kw(out, seen, "fortunes")
			elif tl == "palm":
				_add_kw(out, seen, "palms")
		## Join can be learned from speech. Look/Name/Job/Health/Give are
		## already white menu builtins — tinting them hits idioms ("in the name of").
		for t: String in ["join"]:
			_add_kw(out, seen, t)
		for extra in _TalkLocale.highlight_extras(topic1, topic2, name, city_id):
			_add_kw(out, seen, str(extra))
		for extra in _TalkLocale.highlight_omitted_tint(topic1, topic2, name, city_id):
			_add_kw(out, seen, str(extra))
		return out

	func _add_kw(out: Array[String], seen: Dictionary, s: String) -> void:
		var k: String = s.strip_edges()
		if k.is_empty() or k.to_upper() == "A":
			return
		var key := k.to_lower()
		if seen.has(key):
			return
		seen[key] = true
		out.append(k)


static func resolve_tlk_path(ult_basename: String) -> String:
	## Map .ULT basename → sibling .TLK in the U4 data folder.
	var base := ult_basename.get_file().to_lower()
	if base.is_empty():
		return ""
	var tlk := _ult_to_tlk(base)
	if tlk.is_empty():
		return ""
	return _resolve_data_file(tlk)


static func _ult_to_tlk(ult_file: String) -> String:
	match ult_file:
		"lcb_1.ult", "lcb_2.ult":
			return "lcb.tlk"
		"lycaeum.ult":
			return "lycaeum.tlk"
		"empath.ult":
			return "empath.tlk"
		"serpent.ult":
			return "serpent.tlk"
		"moonglow.ult":
			return "moonglow.tlk"
		"britain.ult":
			return "britain.tlk"
		"jhelom.ult":
			return "jhelom.tlk"
		"yew.ult":
			return "yew.tlk"
		"minoc.ult":
			return "minoc.tlk"
		"trinsic.ult":
			return "trinsic.tlk"
		"skara.ult":
			return "skara.tlk"
		"magincia.ult":
			return "magincia.tlk"
		"paws.ult":
			return "paws.tlk"
		"den.ult":
			return "den.tlk"
		"vesper.ult":
			return "vesper.tlk"
		"cove.ult":
			return "cove.tlk"
		_:
			## Fallback: same stem .tlk (custom maps).
			return ult_file.get_basename() + ".tlk"


static func _resolve_data_file(fname: String) -> String:
	var base := fname.get_file()
	var names: Array[String] = [base, base.to_upper(), base.to_lower()]
	var roots: Array[String] = []
	## Avoid binding autoload at parse/load time for tools; prefer GameState path when live.
	if Engine.get_main_loop() != null:
		var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
		if gs != null and not str(gs.u4_data_path).is_empty():
			roots.append(str(gs.u4_data_path))
	roots.append("res://data/u4")
	for gog in GameState._macos_gog_u4_dirs():
		roots.append(gog)
	var candidates: Array[String] = []
	for r in roots:
		for n in names:
			candidates.append(r.path_join(n))
	for p in candidates:
		if FileAccess.file_exists(p):
			return p
	return ""


static func load_file(path: String) -> Array:
	## Array of Entry (length 0..16). Empty if missing/invalid.
	var out: Array = []
	if path.is_empty() or not FileAccess.file_exists(path):
		return out
	var bytes := FileAccess.get_file_as_bytes(path)
	var n := int(bytes.size() / RECORD_SIZE)
	n = mini(n, MAX_NPCS)
	for i in n:
		var rec := bytes.slice(i * RECORD_SIZE, (i + 1) * RECORD_SIZE)
		var e := _parse_record(rec)
		if e != null:
			out.append(e)
	var city := _TalkLocale.city_id_from_path(path)
	_TalkLocale.ensure_city(city)
	for e2 in out:
		apply_pack_fill(e2, city)
	return out


static func _unused_talk_text(s: String) -> bool:
	var t := s.strip_edges()
	return t.is_empty() or t.to_upper() == "A"


static func apply_pack_fill(entry: Entry, city_id: String) -> void:
	## Classic TLK leaves unused strings as "" / "A". Packs may fill those
	## slots (Smith the stallion, etc.) without rewriting living lines.
	if entry == null:
		return
	var spec: Dictionary = _TalkLocale.pack_spec(str(entry.name), city_id)
	if spec.is_empty():
		return
	if _unused_talk_text(entry.response1) and not _unused_talk_text(str(spec.get("response1", ""))):
		entry.response1 = _TalkLocale.unescape_pack(str(spec.get("response1", "")))
	elif bool(spec.get("replace_response1", false)) and not _unused_talk_text(str(spec.get("response1", ""))):
		entry.response1 = _TalkLocale.unescape_pack(str(spec.get("response1", "")))
	if _unused_talk_text(entry.response2) and not _unused_talk_text(str(spec.get("response2", ""))):
		entry.response2 = _TalkLocale.unescape_pack(str(spec.get("response2", "")))
	elif bool(spec.get("replace_response2", false)) and not _unused_talk_text(str(spec.get("response2", ""))):
		entry.response2 = _TalkLocale.unescape_pack(str(spec.get("response2", "")))
	if bool(spec.get("replace_look", false)) and not _unused_talk_text(str(spec.get("look", ""))):
		entry.look = _TalkLocale.unescape_pack(str(spec.get("look", "")))
	if _unused_talk_text(entry.question) and not _unused_talk_text(str(spec.get("question", ""))):
		entry.question = _TalkLocale.unescape_pack(str(spec.get("question", "")))
	if _unused_talk_text(entry.yes) and not _unused_talk_text(str(spec.get("yes", ""))):
		entry.yes = _TalkLocale.unescape_pack(str(spec.get("yes", "")))
	if _unused_talk_text(entry.no) and not _unused_talk_text(str(spec.get("no", ""))):
		entry.no = _TalkLocale.unescape_pack(str(spec.get("no", "")))
	if _trim_keyword(entry.topic1).is_empty():
		var t1 := _trim_keyword(str(spec.get("topic1", "")))
		if not t1.is_empty():
			entry.topic1 = t1
	if _trim_keyword(entry.topic2).is_empty():
		var t2 := _trim_keyword(str(spec.get("topic2", "")))
		if not t2.is_empty():
			entry.topic2 = t2
	if int(entry.ask_after) == QT_NONE and spec.has("ask_after"):
		var ask := int(spec.get("ask_after", QT_NONE))
		if ask != QT_NONE:
			entry.ask_after = ask


static func entry_from_dict(d: Dictionary) -> Entry:
	## Extra city NPCs not stored in the 16-slot .TLK.
	var e := Entry.new()
	e.ask_after = int(d.get("ask_after", QT_NONE))
	e.question_humility = bool(d.get("question_humility", false))
	e.turn_away = int(d.get("turn_away", 0))
	e.name = str(d.get("name", ""))
	e.pronoun = str(d.get("pronoun", "He"))
	e.look = str(d.get("look", ""))
	e.job = str(d.get("job", ""))
	e.health = str(d.get("health", ""))
	e.response1 = str(d.get("response1", ""))
	e.response2 = str(d.get("response2", ""))
	e.question = str(d.get("question", ""))
	e.yes = str(d.get("yes", ""))
	e.no = str(d.get("no", ""))
	e.topic1 = _trim_keyword(str(d.get("topic1", "")))
	e.topic2 = _trim_keyword(str(d.get("topic2", "")))
	return e


static func _parse_record(buf: PackedByteArray) -> Entry:
	if buf.size() < RECORD_SIZE:
		return null
	var e := Entry.new()
	e.ask_after = int(buf[0])
	e.question_humility = int(buf[1]) != 0
	e.turn_away = int(buf[2])
	var strings := _read_nul_strings(buf, 3, STR_COUNT)
	while strings.size() < STR_COUNT:
		strings.append("")
	e.name = strings[0]
	e.pronoun = strings[1]
	e.look = _fix_look(strings[2], e.name)
	e.job = strings[3]
	e.health = strings[4]
	e.response1 = strings[5]
	e.response2 = strings[6]
	e.question = strings[7]
	e.yes = strings[8]
	e.no = strings[9]
	e.topic1 = _trim_keyword(strings[10])
	e.topic2 = _trim_keyword(strings[11])
	return e


static func _read_nul_strings(buf: PackedByteArray, start: int, count: int) -> Array[String]:
	var out: Array[String] = []
	var i := start
	for _n in count:
		if i >= buf.size():
			out.append("")
			continue
		var s := ""
		while i < buf.size() and buf[i] != 0:
			s += String.chr(int(buf[i]))
			i += 1
		if i < buf.size() and buf[i] == 0:
			i += 1
		out.append(s)
	return out


static func _trim_keyword(raw: String) -> String:
	## xu4 trimKeyword — "A   " marks unused topics.
	var s := raw
	while s.ends_with(" "):
		s = s.substr(0, s.length() - 1)
	if s == "A" or s.is_empty():
		return ""
	## Original Yew Silent stores "BEH." in the 4-letter slot.
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1).strip_edges()
		if s.is_empty() or s == "A":
			return ""
	return s


static func _fix_look(desc: String, name: String) -> String:
	## xu4 U4Talk_load description polish (lower first char, spaces for newlines, period).
	if desc.is_empty():
		return desc
	var s := desc.replace("\n", " ").replace("\r", " ")
	var chars := s.to_utf8_buffer()
	if chars.size() > 0:
		var c0 := chars[0]
		if c0 >= 65 and c0 <= 90:
			chars[0] = c0 + 32
			s = chars.get_string_from_utf8()
	var edit_period := true
	if not s.is_empty():
		var last := s.unicode_at(s.length() - 1)
		## ispunct-ish
		if last == 46 or last == 33 or last == 63 or last == 44 or last == 59 or last == 58:
			edit_period = false
	var need_a := name in ["Iolo", "Tracie", "Dupre", "Traveling Dan"]
	if need_a:
		s = "a " + s
	if edit_period:
		s += "."
	return s


static func match_keyword(entry: Entry, input: String, city_id: String = "") -> Dictionary:
	## Returns { "kind": REPLY_*, "text": String } or empty if engine builtins handle it.
	var in_s := input.strip_edges()
	if in_s.is_empty():
		return {}
	if not entry.topic1.is_empty() and not _TalkLocale.topic_omitted(entry.topic1, entry.name, city_id) and (
		_prefix_ci(entry.topic1, in_s)
		or _TalkLocale.match_topic_alias(entry.topic1, in_s, entry.name, city_id)
	):
		return {"kind": REPLY_TOPIC1, "text": entry.response1}
	if not entry.topic2.is_empty():
		var t2_omit := _TalkLocale.topic_omitted(entry.topic2, entry.name, city_id)
		var t2_alias := _TalkLocale.match_topic_alias(
			entry.topic2, in_s, entry.name, city_id, t2_omit
		)
		if (not t2_omit and (_prefix_ci(entry.topic2, in_s) or t2_alias)) or (t2_omit and t2_alias):
			return {"kind": REPLY_TOPIC2, "text": entry.response2}
	## Builtins: Latin + Hangul (language-independent so 직업/이름 always work).
	var bi := _TalkLocale.match_builtin_interest(in_s)
	if bi == "job" or _prefix_ci("job", in_s, 3):
		return {"kind": REPLY_JOB, "text": entry.job}
	if bi == "heal" or _prefix_ci("heal", in_s, 4):
		return {"kind": REPLY_HEALTH, "text": entry.health}
	return {}


static func question_wants_count(entry: Entry) -> bool:
	## TLK yes-slot "How many?" / "몇이오?" — not a Y/N gate (e.g. Lycaeum Tymus).
	if entry == null:
		return false
	var yes_t := str(entry.yes).replace("\n", " ").replace("\r", " ").strip_edges().to_lower()
	if yes_t in ["how many?", "how many", "몇이오?", "몇이오"]:
		return true
	return _speaker_key(entry) == "tymus"


static func count_answer_from_topic(topic2: String) -> int:
	## Classic 4-letter stems ONE … EIGHT for numeric follow-ups.
	match topic2.strip_edges().to_upper():
		"ONE":
			return 1
		"TWO":
			return 2
		"THREE":
			return 3
		"FOUR":
			return 4
		"FIVE":
			return 5
		"SIX":
			return 6
		"SEVEN":
			return 7
		"EIGHT":
			return 8
		_:
			return 0


static func should_ask_after(entry: Entry, kind: int) -> bool:
	## SKARA.TLK stores Shamino's truth question, but ask_after is 0 so classic
	## U4 never asked it. Remake asks after TRUT so Yes can offer Join.
	if (
		entry != null
		and str(entry.name).strip_edges().to_lower() == "shamino"
		and kind == REPLY_TOPIC2
	):
		return true
	if (
		entry != null
		and str(entry.name).strip_edges().to_lower() == "shawn"
		and kind == REPLY_TOPIC2
	):
		return true
	match kind:
		REPLY_JOB:
			return entry.ask_after == QT_JOB
		REPLY_HEALTH:
			return entry.ask_after == QT_HEALTH
		REPLY_TOPIC1:
			return entry.ask_after == QT_KEYWORD1
		REPLY_TOPIC2:
			return entry.ask_after == QT_KEYWORD2
		_:
			return false


static func apply_keyword_rewards(entry: Entry, kind: int) -> bool:
	## Side effects after a matched keyword line is shown (recipe learning, etc.).
	## Book-of-Wisdom “double portion” corrections (PC U4: one of each type only).
	## Returns true if a new spell recipe was learned this reply.
	if entry == null:
		return false
	var nm := _speaker_key(entry)
	var learned := false
	match nm:
		"cosima", "seanna":
			## Sleep — one spider silk (not two). Cosima REAG / Seanna SLEE.
			if kind == REPLY_TOPIC2:
				learned = GameState.mark_spell_known(Spells.SLEEP) or learned
		"starlight":
			## Magic Missile — one pearl + one ash (not two ash). MIX topic.
			if kind == REPLY_TOPIC2:
				learned = GameState.mark_spell_known(Spells.MAGIC_MISSILE) or learned
		"nigel":
			## Lycaeum Nigel — RECA lists full Resurrect reagents.
			if kind == REPLY_TOPIC2:
				learned = GameState.mark_spell_known(Spells.RESURRECT) or learned
		"mentorian":
			## Cove Mentorian — GATE lists ash, pearl, mandrake.
			if kind == REPLY_TOPIC2:
				learned = GameState.mark_spell_known(Spells.GATE) or learned
	return learned


static func apply_yesno_rewards(entry: Entry, yes: bool) -> bool:
	## Recipe corrections that live on the Y/N answer after a follow-up question.
	## Returns true if a new spell recipe was learned this answer.
	if entry == null:
		return false
	var nm := _speaker_key(entry)
	if not yes:
		if nm == "nystul":
			## LCB court mage — gift of The Book of Mystic Wisdom.
			return GameState.mark_all_spells_known()
		return false
	match nm:
		"carlyle":
			## Magic Missile — need but 1 part ash (after “believe in magic?”).
			return GameState.mark_spell_known(Spells.MAGIC_MISSILE)
		"calumny":
			## Quickness — but one bloodmoss (after “can thou cast it?”).
			return GameState.mark_spell_known(Spells.QUICKNESS)
	return false


static func has_personal_name(entry: Entry) -> bool:
	if entry == null:
		return false
	var n := str(entry.name).replace("\n", " ").replace("\r", " ").strip_edges().to_lower()
	if n.is_empty():
		return false
	return not (
		n.begins_with("a ")
		or n.begins_with("an ")
		or n.begins_with("the ")
	)


static func _speaker_key(entry: Entry) -> String:
	## TLK names may wrap ("Nigel, at thy\\nservice.") — use the first word.
	var raw := str(entry.name).replace("\r", " ").replace("\n", " ").strip_edges().to_lower()
	if raw.is_empty():
		return ""
	## "Nigel, at thy service." → "nigel"
	var first := raw.split(" ", false)
	if first.is_empty():
		return raw
	return str(first[0]).trim_suffix(",").strip_edges()


static func _prefix_ci(needle: String, hay: String, force_len: int = -1) -> bool:
	var n := needle.to_lower()
	var h := hay.to_lower()
	if force_len > 0:
		if h.length() < force_len:
			return false
		return h.substr(0, force_len) == n.substr(0, mini(force_len, n.length()))
	## Custom topic: strncasecmp(topic, input, strlen(topic)).
	if n.is_empty() or h.length() < n.length():
		return false
	return h.substr(0, n.length()) == n


static func colorize_keywords(text: String, keywords: Array) -> String:
	## Wrap keyword occurrences in NPC spoken lines (case-insensitive).
	## Latin: whole word or stem (PLAY→playing).
	## Hangul: tint only the keyword itself so particles (을/를/이/가/의…) stay plain.
	if text.is_empty() or keywords.is_empty():
		return text
	var keys: Array[String] = []
	for k in keywords:
		var s := str(k).strip_edges()
		if _colorize_key_ok(s):
			keys.append(s)
	if keys.is_empty():
		return text
	keys.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var out := ""
	var i := 0
	var lower := text.to_lower()
	while i < text.length():
		var hit := ""
		var hit_len := 0
		for k in keys:
			var kl := k.to_lower()
			if i + kl.length() > text.length():
				continue
			if lower.substr(i, kl.length()) != kl:
				continue
			var hangul_kw := _is_hangul_code(kl.unicode_at(0))
			if not _keyword_before_ok(text, i, hangul_kw, kl.length()):
				continue
			if hangul_kw:
				## Exact keyword only — never pull in 조사 / conjugations after it.
				## Also skip when the match starts a longer word (말하길 ≠ 말).
				if not _hangul_keyword_after_ok(text, i + kl.length(), kl.length()):
					continue
				if kl.length() > hit_len:
					hit = text.substr(i, kl.length())
					hit_len = kl.length()
				continue
			var after_i := i + kl.length()
			var after_ok := after_i >= text.length() or not _is_word_char(text.unicode_at(after_i))
			if after_ok:
				if kl.length() > hit_len:
					hit = text.substr(i, kl.length())
					hit_len = kl.length()
			elif _colorize_stem_ok(kl):
				## Latin stem: highlight full word starting with keyword.
				var end := after_i
				while end < text.length() and _is_word_char(text.unicode_at(end)):
					end += 1
				if end - i > hit_len:
					hit = text.substr(i, end - i)
					hit_len = end - i
		if hit_len > 0:
			out += KW_BBCODE + hit + KW_BBCODE_END
			i += hit_len
		else:
			var ch := text[i]
			if ch == "[":
				out += "[lb]"
			else:
				out += ch
			i += 1
	return out


static func keyword_first_index(text: String, keyword: String) -> int:
	## First occurrence accepted by colorize_keywords, for spoken-order menus.
	var key := keyword.strip_edges()
	if text.is_empty() or not _colorize_key_ok(key):
		return -1
	var lower := text.to_lower()
	var kl := key.to_lower()
	for i in text.length():
		if i + kl.length() > text.length():
			break
		if lower.substr(i, kl.length()) != kl:
			continue
		var hangul_kw := _is_hangul_code(kl.unicode_at(0))
		if not _keyword_before_ok(text, i, hangul_kw, kl.length()):
			continue
		if hangul_kw:
			if not _hangul_keyword_after_ok(text, i + kl.length(), kl.length()):
				continue
			return i
		var after_i := i + kl.length()
		var after_ok := (
			after_i >= text.length()
			or not _is_word_char(text.unicode_at(after_i))
		)
		if after_ok or _colorize_stem_ok(kl):
			return i
	return -1


static func _keyword_before_ok(text: String, i: int, hangul_kw: bool, kw_len: int) -> bool:
	## Word start, or a known Hangul compound (은뿔 → tint 뿔 only).
	if i <= 0:
		return true
	var prev := text.unicode_at(i - 1)
	if not _is_word_char(prev):
		return true
	## Topics must not match inside another word (말하길 → 길) except listed
	## compounds (은뿔, 흑마법).
	if hangul_kw and _is_hangul_code(prev):
		return _hangul_compound_prefix_ok(
			text.substr(i - 1, 1), text.substr(i, kw_len)
		)
	return false


static func _hangul_keyword_after_ok(text: String, after_i: int, kw_len: int = 1) -> bool:
	## Allow end / punctuation / space, or a following 조사. Reject verb stems
	## that swallow a 1-syllable topic (말하길 ≠ 말). Noun+하다 forms keep the
	## multi-syllable noun tinted (여행하는 → 여행).
	if after_i >= text.length():
		return true
	var u := text.unicode_at(after_i)
	if not _is_hangul_code(u):
		return true
	var next := text.substr(after_i, 1)
	if _hangul_particle_after_ok(next):
		return true
	if _hangul_particle_span_ok(text, after_i):
		return true
	## 여행하다 / 은신해 / 수리한 … — tint the noun, leave -하/해… plain.
	if kw_len >= 2 and next in ["하", "해", "한", "할", "했"]:
		return true
	return false


static func _hangul_particle_after_ok(syl: String) -> bool:
	match syl:
		"이", "가", "을", "를", "은", "는", "의", "과", "와", "도", "만", \
		"로", "에", "께", "랑", "며", "나", "야", "여", "요", "다", "들", \
		"뿐", "씩", "쯤", "라", "니", "면", "서":
			return true
		_:
			return false


static func _hangul_particle_span_ok(text: String, after_i: int) -> bool:
	## Two-syllable particles (마법으로 → tint 마법).
	match text.substr(after_i, 2):
		"으로", "에서", "에게", "한테", "부터", "까지":
			return true
		_:
			return false


static func _hangul_compound_prefix_ok(prev: String, keyword: String) -> bool:
	## 은뿔: tint 뿔. 흑마법: tint 마법. Do not treat connective -길 as PATH.
	match keyword:
		"뿔":
			return prev == "은"
		"마법":
			return prev == "흑"
		_:
			return false


static func _colorize_key_ok(s: String) -> bool:
	## Latin needs ≥2 letters; Hangul allows 1-syllable topics (룬, 꽃, 방…).
	if s.is_empty():
		return false
	if s.length() >= 2:
		return true
	return _is_hangul_code(s.unicode_at(0))


static func _colorize_stem_ok(kl: String) -> bool:
	## PLAY→playing (len≥3 Latin). Hangul never stem-extends (particles stay plain).
	if kl.is_empty() or _is_hangul_code(kl.unicode_at(0)):
		return false
	return kl.length() >= 3


static func _is_hangul_code(u: int) -> bool:
	return (
		(u >= 0x1100 and u <= 0x11FF)
		or (u >= 0x3130 and u <= 0x318F)
		or (u >= 0xA960 and u <= 0xA97F)
		or (u >= 0xAC00 and u <= 0xD7A3)
		or (u >= 0xD7B0 and u <= 0xD7FF)
	)


static func colorize_shop_dialogue(text: String) -> String:
	## Vendor lines: tint Buy/Sell verbs, (B)/(S)/Y/N shortcut keys,
	## and A-/B-/… catalog indexes. Existing BBCode passes through.
	if text.is_empty():
		return text
	var keys: Array[String] = SHOP_ACTION_KEYS.duplicate()
	keys.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var out := ""
	var i := 0
	var lower := text.to_lower()
	while i < text.length():
		## Pass through BBCode tags (color, /color, lb, …).
		if text[i] == "[":
			var close := text.find("]", i)
			if close >= 0:
				out += text.substr(i, close - i + 1)
				i = close + 1
				continue
			out += "[lb]"
			i += 1
			continue
		## Shortcut groups: (B), (Y/N), (B/S), (1/2/3)…
		if text[i] == "(":
			var close_p := text.find(")", i + 1)
			if close_p > i + 1:
				var inner := text.substr(i + 1, close_p - i - 1)
				if _shop_key_group_ok(inner):
					out += "("
					out += _colorize_shop_key_group(inner)
					out += ")"
					i = close_p + 1
					continue
		## Bare key groups: B/S · Y/N · F/A (not mid-word).
		var group_end := _shop_bare_key_group_end(text, i)
		if group_end > i:
			out += _colorize_shop_key_group(text.substr(i, group_end - i))
			i = group_end
			continue
		var hit := ""
		var hit_len := 0
		for k in keys:
			var kl := k.to_lower()
			if i + kl.length() > text.length():
				continue
			if lower.substr(i, kl.length()) != kl:
				continue
			var before_ok := i == 0 or not _is_word_char(text.unicode_at(i - 1))
			if not before_ok:
				continue
			var after_i := i + kl.length()
			var after_ok := after_i >= text.length() or not _is_word_char(text.unicode_at(after_i))
			if after_ok and kl.length() > hit_len:
				hit = text.substr(i, kl.length())
				hit_len = kl.length()
		if hit_len > 0:
			out += KW_BBCODE + hit + KW_BBCODE_END
			i += hit_len
			continue
		## Catalog keys: isolated letter + hyphen (A-Staff) or " - " (E - Mace).
		var u := text.unicode_at(i)
		var is_letter := (u >= 65 and u <= 90) or (u >= 97 and u <= 122)
		if is_letter:
			var before_letter := i == 0 or not _is_word_char(text.unicode_at(i - 1))
			if before_letter:
				if i + 1 < text.length() and text[i + 1] == "-":
					out += SHOP_INDEX_BBCODE + text[i] + SHOP_INDEX_BBCODE_END + "-"
					i += 2
					continue
				if i + 3 <= text.length() and text.substr(i + 1, 3) == " - ":
					out += SHOP_INDEX_BBCODE + text[i] + SHOP_INDEX_BBCODE_END + " - "
					i += 4
					continue
		out += text[i]
		i += 1
	return out


static func _shop_key_alnum(u: int) -> bool:
	return (
		(u >= 65 and u <= 90)
		or (u >= 97 and u <= 122)
		or (u >= 48 and u <= 57)
	)


static func _shop_key_group_ok(inner: String) -> bool:
	## True for B · Y/N · B/S · 1, 2 or 3-style short key lists (no spaces ok).
	if inner.is_empty() or inner.length() > 16:
		return false
	var has_key := false
	for j in inner.length():
		var u := inner.unicode_at(j)
		if _shop_key_alnum(u):
			has_key = true
			continue
		if inner[j] == "/" or inner[j] == "," or inner[j] == " ":
			continue
		return false
	return has_key


static func _colorize_shop_key_group(inner: String) -> String:
	## Tint each letter/digit; leave / , space plain.
	var out := ""
	for j in inner.length():
		var ch := inner[j]
		var u := inner.unicode_at(j)
		if _shop_key_alnum(u):
			out += SHOP_INDEX_BBCODE + ch + SHOP_INDEX_BBCODE_END
		else:
			out += ch
	return out


static func _shop_bare_key_group_end(text: String, i: int) -> int:
	## Match B/S or Y/N at i when not mid-word. Length ≥3 (X/Y).
	if i + 2 >= text.length():
		return i
	if not _shop_key_alnum(text.unicode_at(i)):
		return i
	if i > 0 and _is_word_char(text.unicode_at(i - 1)):
		return i
	var j := i + 1
	var keys_seen := 1
	while j < text.length():
		if text[j] == "/":
			if j + 1 >= text.length() or not _shop_key_alnum(text.unicode_at(j + 1)):
				break
			j += 2
			keys_seen += 1
			continue
		break
	if keys_seen < 2:
		return i
	## Boundary after group.
	if j < text.length() and _is_word_char(text.unicode_at(j)):
		return i
	return j


static func mark_weapon_icon(weapon_id: int) -> String:
	return "%sw%d%s" % [MSG_ICON_BEGIN, weapon_id, MSG_ICON_END]


static func mark_armor_icon(armor_id: int) -> String:
	return "%sa%d%s" % [MSG_ICON_BEGIN, armor_id, MSG_ICON_END]


static func mark_reagent_icon(reagent_id: int) -> String:
	return "%sr%d%s" % [MSG_ICON_BEGIN, reagent_id, MSG_ICON_END]


static func count_icon_marks(text: String) -> int:
	var n := 0
	var i := 0
	while i < text.length():
		if text.unicode_at(i) == 0x02:
			var end := text.find(MSG_ICON_END, i + 1)
			if end >= 0:
				n += 1
				i = end + 1
				continue
		i += 1
	return n


static func strip_icon_marks(text: String) -> String:
	if text.is_empty() or not text.contains(MSG_ICON_BEGIN):
		return text
	var out := ""
	var i := 0
	while i < text.length():
		if text.unicode_at(i) == 0x02:
			var end := text.find(MSG_ICON_END, i + 1)
			if end >= 0:
				i = end + 1
				continue
		out += text[i]
		i += 1
	return out


static func strip_bbcode(text: String) -> String:
	var re := RegEx.new()
	var s := text
	if re.compile("\\[[^\\]]*\\]") == OK:
		s = re.sub(s, "", true)
	s = s.replace("[lb]", "[")
	return strip_icon_marks(s)


static func _is_word_char(u: int) -> bool:
	return (
		(u >= 48 and u <= 57)
		or (u >= 65 and u <= 90)
		or (u >= 97 and u <= 122)
		or u == 95
		or u == 39
		or _is_hangul_code(u)
	) ## digits, letters, _, ', Hangul


static func is_beggar_tile(tid: int) -> bool:
	## shapes beggar 88–89.
	var base := tid
	if (tid >= 32 and tid <= 47) or (tid >= 80 and tid <= 95):
		base = tid & ~1
	return base == 88


static func is_child_tile(tid: int) -> bool:
	## shapes child 90–91.
	var base := tid
	if (tid >= 32 and tid <= 47) or (tid >= 80 and tid <= 95):
		base = tid & ~1
	return base == 90


static func is_guard_tile(tid: int) -> bool:
	## shapes guard 80–81.
	var base := tid
	if (tid >= 32 and tid <= 47) or (tid >= 80 and tid <= 95):
		base = tid & ~1
	return base == 80


static func is_undead_tile(tid: int) -> bool:
	## ghost 156, skeleton 196 families.
	var base := tid
	if tid >= 144:
		base = tid & ~3
	return base == 156 or base == 196


static func is_python_tile(tid: int) -> bool:
	var base := tid
	if tid >= 192:
		base = tid & ~3
	return base == 204
