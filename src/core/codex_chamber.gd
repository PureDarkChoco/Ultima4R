extends RefCounted

## xu4 Chamber of the Codex — 8 virtues, 3 principles, then Infinity.
## Stage is 1..12. Frames 1..11 fill the Codex symbol after each correct answer.

const _TalkLocale := preload("res://src/core/talk_locale.gd")
const _Journal := preload("res://src/core/journal.gd")
const _Shrine := preload("res://src/core/shrine.gd")
const _Virtues := preload("res://src/core/virtues.gd")

const STAGE_COUNT := 12
const PRINCIPLE_TRUTH := 0
const PRINCIPLE_LOVE := 1
const PRINCIPLE_COURAGE := 2

const QUESTION_KEYS: Array[String] = [
	"cmd_codex_q_honesty",
	"cmd_codex_q_compassion",
	"cmd_codex_q_valor",
	"cmd_codex_q_justice",
	"cmd_codex_q_sacrifice",
	"cmd_codex_q_honor",
	"cmd_codex_q_spirituality",
	"cmd_codex_q_humility",
	"cmd_codex_q_truth",
	"cmd_codex_q_love",
	"cmd_codex_q_courage",
	"cmd_codex_q_infinity",
]


static func question_key(stage: int) -> String:
	var i := stage - 1
	if i < 0 or i >= QUESTION_KEYS.size():
		return ""
	return QUESTION_KEYS[i]


static func frame_path(stage: int) -> String:
	## Show the symbol that belongs to this question (1..11), keep 11 for Infinity.
	var frame := clampi(stage, 1, 11)
	return "res://assets/ui/codex/end_%02d.png" % frame


static func answer_ok(stage: int, typed: String) -> bool:
	if stage >= 1 and stage <= 8:
		return _Shrine.virtue_input_matches(stage - 1, typed)
	if stage == 9:
		return _principle_matches(PRINCIPLE_TRUTH, typed)
	if stage == 10:
		return _principle_matches(PRINCIPLE_LOVE, typed)
	if stage == 11:
		return _principle_matches(PRINCIPLE_COURAGE, typed)
	if stage == 12:
		return _infinity_matches(typed)
	return false


static func _principle_matches(kind: int, typed: String) -> bool:
	var got := _TalkLocale.normalize_interest(typed)
	if got.is_empty():
		return false
	var en := _TalkLocale.normalize_interest(_principle_name(kind, "en"))
	if not en.is_empty():
		var n := mini(4, en.length())
		if got.length() >= n and got.substr(0, n) == en.substr(0, n):
			return true
	var ko := _TalkLocale.normalize_interest(_principle_name(kind, "ko"))
	return not ko.is_empty() and got == ko


static func _infinity_matches(typed: String) -> bool:
	var got := _TalkLocale.normalize_interest(typed)
	if got.is_empty():
		return false
	var en := _TalkLocale.normalize_interest("infinity")
	if got.length() >= 4 and got.substr(0, 4) == en.substr(0, 4):
		return true
	return got == _TalkLocale.normalize_interest("무한")


static func _principle_name(kind: int, lang: String) -> String:
	match kind:
		PRINCIPLE_TRUTH:
			return "진리" if lang == "ko" else "Truth"
		PRINCIPLE_LOVE:
			return "사랑" if lang == "ko" else "Love"
		PRINCIPLE_COURAGE:
			return "용기" if lang == "ko" else "Courage"
		_:
			return ""


static func infinity_choice_unlocked(gs: Node) -> bool:
	## Show Infinity only after the axiom word (or every virtue + principle) is known.
	if gs == null:
		return false
	if gs.talk_has_heard_word("infinity") or gs.talk_has_heard_word("무한"):
		return true
	if gs.journal_has_id("cove.circe.axiom-parts") or gs.journal_has_id("cove.circe.axiom"):
		return true
	var virtues: int = _Journal.known_virtue_mask(gs)
	var principles: int = _Journal.known_principle_mask(gs)
	return virtues == 255 and (principles & 7) == 7


static func choice_items(gs: Node, stage: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lang := "ko" if str(gs.lang_short()) == "ko" else "en"
	if stage >= 1 and stage <= 8:
		var known: int = _Journal.known_virtue_mask(gs)
		for virtue in 8:
			if (known & (1 << virtue)) == 0:
				continue
			out.append({
				"label": _Virtues.name_of(virtue, lang),
				"input": _Virtues.name_of(virtue, lang),
			})
		return out
	if stage >= 9 and stage <= 11:
		var known_p: int = _Journal.known_principle_mask(gs)
		for kind in 3:
			if (known_p & (1 << kind)) == 0:
				continue
			var name := _principle_name(kind, lang)
			out.append({"label": name, "input": name})
		return out
	if stage == 12 and infinity_choice_unlocked(gs):
		var inf := "무한" if lang == "ko" else "Infinity"
		out.append({"label": inf, "input": inf})
	return out
