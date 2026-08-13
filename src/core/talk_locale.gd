class_name TalkLocale
extends RefCounted

## Town discourse overlays (Korean etc.) keyed by classic English TLK lines.
## Packs: res://assets/locale/talk/<city>.json
## Original en_u4 stays in GOG .TLK; this layer only affects display / keyword aliases.
## KO topic/alias policy: short nouns only (no verb stems, conjugations, or particles on the keyword).
## Dialogue may read naturally but should include those nouns so highlight/input stay aligned.
## See .cursor/rules/talk-locale-ko-nouns.mdc

const DIR := "res://assets/locale/talk"

const _SHELL_KO := {
	"Your Interest:": "관심사:",
	"That I cannot\nhelp thee with.": "그것은 내가\n도울 수 없습니다.",
	"That I cannot help thee with.": "그것은 내가 도울 수 없습니다.",
	"How much?": "얼마를?",
	"Yes or no!": "예 또는 아니!",
	"Thou hast not that much gold!": "그만한 금은 없구나!",
	"I am honored to join thee!": "함께하게 되어 영광이오!",
	"Thou art not experienced enough for me to join thee.": "아직 경험이 부족해 함께할 수 없소.",
	"Bye.": "안녕.",
}

static var _cities: Dictionary = {} ## city_id -> true
static var _lines: Dictionary = {} ## norm(en) -> ko
static var _aliases: Dictionary = {} ## "CARE" -> Array of lowercase aliases
static var _hl: Dictionary = {} ## "CARE" -> highlight words


static func _lang() -> String:
	if Engine.get_main_loop() != null:
		var gs = Engine.get_main_loop().root.get_node_or_null("/root/GameState")
		if gs != null:
			return str(gs.language)
	return "en_us"


static func is_korean() -> bool:
	return _lang() == "ko"


## Interest-keyword builtins (English stem + Korean). No language gate — Hangul input always matches.
const BUILTIN_INTERESTS := {
	"job": ["job", "직업"],
	"heal": ["heal", "health", "건강", "상태"],
	"name": ["name", "이름", "성명", "성함"],
	"look": ["look", "모습", "외모"],
	"give": ["give", "주기", "기부"],
	"join": ["join", "합류", "동료"],
	"bye": ["bye", "안녕", "작별", "바이"],
}


static func normalize_interest(s: String) -> String:
	## Lowercase + strip + drop punctuation/invisible IME marks.
	## Finally decompose Hangul syllables so NFC ("이름") and NFD
	## (이름, visually identical after shaping) compare equally.
	var t := s.strip_edges().to_lower()
	for invisible in ["\u200b", "\u200c", "\u200d", "\u2060", "\ufeff"]:
		t = t.replace(invisible, "")
	while t.ends_with("?") or t.ends_with("!") or t.ends_with(".") or t.ends_with(","):
		t = t.substr(0, t.length() - 1).strip_edges()
	return _hangul_decomposed_key(t)


static func _hangul_decomposed_key(s: String) -> String:
	## Unicode Hangul decomposition, without requiring an NFC/NFD addon.
	## AC00 + ((L * 21 + V) * 28 + T)
	const S_BASE := 0xAC00
	const S_END := 0xD7A3
	const L_BASE := 0x1100
	const V_BASE := 0x1161
	const T_BASE := 0x11A7
	const V_COUNT := 21
	const T_COUNT := 28
	var out := ""
	for i in s.length():
		var u := s.unicode_at(i)
		if u < S_BASE or u > S_END:
			out += String.chr(u)
			continue
		var index := u - S_BASE
		var l_index: int = int(index / (V_COUNT * T_COUNT))
		var v_index: int = int((index % (V_COUNT * T_COUNT)) / T_COUNT)
		var t_index: int = index % T_COUNT
		out += String.chr(L_BASE + l_index)
		out += String.chr(V_BASE + v_index)
		if t_index > 0:
			out += String.chr(T_BASE + t_index)
	return out


static func interest_matches_any(input: String, stems: Array) -> bool:
	var h := normalize_interest(input)
	if h.is_empty():
		return false
	for stem in stems:
		var s := normalize_interest(str(stem))
		if s.is_empty():
			continue
		if h == s:
			return true
		## Prefix: "job…" / "직업은" etc. Hangul stems use full stem length (not 1-letter Latin).
		if h.length() >= s.length() and h.substr(0, s.length()) == s:
			return true
	return false


static func match_builtin_interest(input: String) -> String:
	## Returns "job"|"heal"|"name"|"look"|"give"|"join"|"bye"|"".
	for key in BUILTIN_INTERESTS.keys():
		var list: Array = BUILTIN_INTERESTS[key]
		if interest_matches_any(input, list):
			return str(key)
	return ""


static func city_id_from_path(ult_or_tlk_path: String) -> String:
	var base := ult_or_tlk_path.get_file().to_lower()
	if base.ends_with(".ult") or base.ends_with(".tlk"):
		base = base.get_basename()
	if base == "lcb_1" or base == "lcb_2":
		return "lcb"
	return base


static func ensure_city_for_path(ult_path: String) -> void:
	ensure_city(city_id_from_path(ult_path))


static func ensure_city(city_id: String) -> void:
	var id := city_id.strip_edges().to_lower()
	if id.is_empty() or _cities.has(id):
		return
	_cities[id] = true
	var path := DIR.path_join("%s.json" % id)
	if not FileAccess.file_exists(path):
		return
	var raw := FileAccess.get_file_as_string(path)
	if raw.is_empty():
		return
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("TalkLocale: bad JSON %s" % path)
		return
	var npcs: Variant = (data as Dictionary).get("npcs", [])
	if typeof(npcs) != TYPE_ARRAY:
		return
	for item in npcs:
		if typeof(item) == TYPE_DICTIONARY:
			_ingest_npc(item as Dictionary)


static func line(en: String) -> String:
	if en.is_empty() or not is_korean():
		return en
	return _translate_line(en)


static func match_topic_alias(topic: String, input: String) -> bool:
	if topic.is_empty() or input.is_empty():
		return false
	var stem := topic.strip_edges().to_upper()
	if stem.is_empty() or stem == "A":
		return false
	var h := normalize_interest(input)
	var n := stem.to_lower()
	## Classic 4-letter stem (and longer full words).
	if h.length() >= n.length() and h.substr(0, n.length()) == n:
		return true
	var als: Array = _aliases.get(stem, [])
	for a in als:
		var al := normalize_interest(str(a))
		if al.is_empty():
			continue
		if h.length() >= al.length() and h.substr(0, al.length()) == al:
			return true
	return false


static func highlight_extras(topic1: String, topic2: String) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for t in [topic1, topic2]:
		var stem := str(t).strip_edges().to_upper()
		if stem.is_empty():
			continue
		var words: Array = _hl.get(stem, [])
		for w in words:
			var k := str(w).to_lower()
			if k.is_empty() or seen.has(k):
				continue
			seen[k] = true
			out.append(str(w))
	if is_korean():
		var builtins: Array[String] = ["직업", "건강", "이름", "모습", "주기", "합류", "관심사"]
		for w in builtins:
			var k2: String = w.to_lower()
			if not seen.has(k2):
				seen[k2] = true
				out.append(w)
	return out


static func _ingest_npc(npc: Dictionary) -> void:
	var ko: Variant = npc.get("ko", {})
	if typeof(ko) != TYPE_DICTIONARY:
		return
	var ko_d: Dictionary = ko
	for field in [
		"name", "pronoun", "look", "job", "health",
		"response1", "response2", "question", "yes", "no",
	]:
		var en_s := _unescape(str(npc.get(field, "")))
		var ko_s := _unescape(str(ko_d.get(field, "")))
		if en_s.is_empty() or ko_s.is_empty():
			continue
		_lines[_norm(en_s)] = ko_s
	for ti: String in ["topic1", "topic2"]:
		var stem := str(npc.get(ti, "")).strip_edges().to_upper()
		if stem.is_empty() or stem == "A":
			continue
		var als: Array = [stem.to_lower()]
		var akey: String = ti + "_aliases"
		if ko_d.has(akey) and typeof(ko_d[akey]) == TYPE_ARRAY:
			for a in ko_d[akey]:
				als.append(str(a).strip_edges().to_lower())
		elif ko_d.has(ti) and not str(ko_d[ti]).is_empty():
			als.append(str(ko_d[ti]).strip_edges().to_lower())
		_merge_alias(stem, als)
		var hls: Array = []
		for a in als:
			if not str(a).is_empty():
				hls.append(str(a))
		if ko_d.has(ti) and not str(ko_d[ti]).is_empty():
			hls.append(str(ko_d[ti]))
		_merge_hl(stem, hls)


static func _unescape(s: String) -> String:
	return s.replace("\\n", "\n").replace("\\t", "\t")


static func _norm(s: String) -> String:
	return s.replace("\r\n", "\n").replace("\r", "\n")


static func _merge_alias(stem: String, als: Array) -> void:
	var key := stem.to_upper()
	var cur: Array = _aliases.get(key, [])
	for a in als:
		var s := str(a).strip_edges()
		if s.is_empty() or cur.has(s):
			continue
		cur.append(s)
	_aliases[key] = cur


static func _merge_hl(stem: String, words: Array) -> void:
	var key := stem.to_upper()
	var cur: Array = _hl.get(key, [])
	for w in words:
		var s := str(w).strip_edges()
		if s.is_empty() or cur.has(s):
			continue
		cur.append(s)
	_hl[key] = cur


static func _translate_line(en: String) -> String:
	var n := _norm(en)
	if _SHELL_KO.has(n):
		return str(_SHELL_KO[n])
	if _lines.has(n):
		return str(_lines[n])
	const MEET := "You meet "
	if n.begins_with(MEET):
		var look := n.substr(MEET.length())
		var look_ko := str(_lines.get(_norm(look), look))
		## look packs are descriptive predicates ("…다."); "You meet" needs an object clause.
		return _you_encounter_ko(look_ko, true)
	const SEE := "You see "
	if n.begins_with(SEE):
		var look2 := n.substr(SEE.length())
		var look2_ko := str(_lines.get(_norm(look2), look2))
		return _you_encounter_ko(look2_ko, false)
	var says_i := n.find(" says: I am ")
	if says_i > 0:
		var pronoun := n.substr(0, says_i)
		var name := n.substr(says_i + " says: I am ".length())
		var p_ko := str(_lines.get(_norm(pronoun), pronoun))
		var n_ko := str(_lines.get(_norm(name), name))
		return "%s 말하길: 나는 %s" % [p_ko, n_ko]
	if n.ends_with(" turns away!"):
		var p2 := n.substr(0, n.length() - " turns away!".length())
		return "%s 몸을 돌린다!" % str(_lines.get(_norm(p2), p2))
	const GUARD := " says: On guard! Fool!"
	if n.ends_with(GUARD):
		var p3 := n.substr(0, n.length() - GUARD.length())
		return "%s 말하길: 정신 차려라, 이 바보야!" % str(_lines.get(_norm(p3), p3))
	const NO_GOLD := " says: I do not need thy gold.  Keep it!"
	if n.ends_with(NO_GOLD):
		var p4 := n.substr(0, n.length() - NO_GOLD.length())
		return "%s 말하길: 금은 필요 없소. 간직하시오!" % str(_lines.get(_norm(p4), p4))
	const THANKS_GOLD := " says: Oh Thank thee! I shall never forget thy kindness!"
	if n.ends_with(THANKS_GOLD):
		var p5 := n.substr(0, n.length() - THANKS_GOLD.length())
		return "%s 말하길: 오, 고맙소! 그 친절을 결코 잊지 않겠소!" % str(
			_lines.get(_norm(p5), p5)
		)
	const NO_JOIN := " says: I cannot join thee."
	if n.ends_with(NO_JOIN):
		var p6 := n.substr(0, n.length() - NO_JOIN.length())
		return "%s 말하길: 함께할 수 없소." % str(_lines.get(_norm(p6), p6))
	if n.begins_with("Thou art not ") and n.ends_with(" enough for me to join thee."):
		var mid := n.substr(
			"Thou art not ".length(),
			n.length() - "Thou art not ".length() - " enough for me to join thee.".length()
		)
		return "나와 함께하기엔 %s이(가) 부족하구나." % mid
	return en


static func _you_encounter_ko(look_ko: String, meet: bool) -> String:
	## "You meet/see {look}." → not "당신은 {look이다}" (that reads as "you ARE …").
	var noun := _look_ko_to_noun(look_ko)
	if noun.is_empty():
		return look_ko
	var particle := _object_particle(noun)
	if meet:
		return "당신은 %s%s 만났다." % [noun, particle]
	return "당신은 %s%s 보았다." % [noun, particle]


static func _look_ko_to_noun(look_ko: String) -> String:
	## Strip sentence punctuation and predicate endings that packs use for LOOK.
	## Packs use "…다." / "…이다." — do not treat 아이다 as 아+이다 (→ 아) or 대장장이다 as 대장장.
	var s := look_ko.strip_edges()
	while not s.is_empty() and s.unicode_at(s.length() - 1) in [ord("."), ord("!"), ord("?")]:
		s = s.substr(0, s.length() - 1).strip_edges()
	if s.is_empty():
		return s
	if not s.ends_with("다") or s.length() < 2:
		return s
	## Remove copula 다 first ("마법사다", "아이다", "여인이다").
	var stem := s.substr(0, s.length() - 1).strip_edges()
	if stem.is_empty():
		return s
	## Residual 이 of 이다 after a batchim stem ("여인이다" → "여인이" → "여인").
	## Keep open-syllable 이 that belongs to the noun ("아이", "대장장이").
	if stem.ends_with("이") and stem.length() >= 2 and not _look_stem_ends_with_open_i_noun(stem):
		var before_i := stem.unicode_at(stem.length() - 2)
		if before_i >= 0xAC00 and before_i <= 0xD7A3 and ((before_i - 0xAC00) % 28) != 0:
			stem = stem.substr(0, stem.length() - 1).strip_edges()
	return stem


static func _look_stem_ends_with_open_i_noun(stem: String) -> bool:
	## Noun tails that end in 이 (not the 이 of 이다).
	const TAILS: Array[String] = ["아이", "장이"]
	for t in TAILS:
		if stem.ends_with(t):
			return true
	return false


static func _object_particle(word: String) -> String:
	if word.is_empty():
		return "를"
	var last := word.unicode_at(word.length() - 1)
	## Hangul syllable with batchim → 을, else 를.
	if last >= 0xAC00 and last <= 0xD7A3 and ((last - 0xAC00) % 28) != 0:
		return "을"
	return "를"
