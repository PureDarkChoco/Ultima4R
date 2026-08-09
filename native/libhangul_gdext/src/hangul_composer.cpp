#include "hangul_composer.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void HangulComposer::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_keyboard", "id"), &HangulComposer::set_keyboard);
	ClassDB::bind_method(D_METHOD("get_keyboard"), &HangulComposer::get_keyboard);
	ClassDB::bind_method(D_METHOD("process_key", "ascii"), &HangulComposer::process_key);
	ClassDB::bind_method(D_METHOD("backspace"), &HangulComposer::backspace);
	ClassDB::bind_method(D_METHOD("flush"), &HangulComposer::flush);
	ClassDB::bind_method(D_METHOD("reset"), &HangulComposer::reset);
	ClassDB::bind_method(D_METHOD("get_preedit"), &HangulComposer::get_preedit);
	ClassDB::bind_method(D_METHOD("is_empty"), &HangulComposer::is_empty);
	ADD_PROPERTY(PropertyInfo(Variant::STRING, "keyboard"), "set_keyboard", "get_keyboard");
}

HangulComposer::HangulComposer() {
	context = hangul_ic_new(keyboard_id.utf8().get_data());
}

HangulComposer::~HangulComposer() {
	if (context != nullptr) {
		hangul_ic_delete(context);
		context = nullptr;
	}
}

String HangulComposer::from_ucs4(const ucschar *text) {
	String result;
	if (text == nullptr) {
		return result;
	}
	for (const ucschar *p = text; *p != 0; ++p) {
		result += String::chr(*p);
	}
	return result;
}

Dictionary HangulComposer::state(bool consumed, const String &commit) const {
	Dictionary result;
	result["consumed"] = consumed;
	result["commit"] = commit;
	result["preedit"] = get_preedit();
	return result;
}

void HangulComposer::set_keyboard(const String &id) {
	if (context == nullptr || id.is_empty()) {
		return;
	}
	hangul_ic_reset(context);
	keyboard_id = id;
	CharString id_utf8 = id.utf8();
	hangul_ic_select_keyboard(context, id_utf8.get_data());
}

String HangulComposer::get_keyboard() const {
	return keyboard_id;
}

Dictionary HangulComposer::process_key(int32_t ascii) {
	if (context == nullptr || ascii < 0 || ascii > 0x7f) {
		return state(false);
	}
	const bool consumed = hangul_ic_process(context, ascii);
	return state(consumed, from_ucs4(hangul_ic_get_commit_string(context)));
}

Dictionary HangulComposer::backspace() {
	if (context == nullptr) {
		return state(false);
	}
	return state(hangul_ic_backspace(context));
}

String HangulComposer::flush() {
	if (context == nullptr) {
		return String();
	}
	return from_ucs4(hangul_ic_flush(context));
}

void HangulComposer::reset() {
	if (context != nullptr) {
		hangul_ic_reset(context);
	}
}

String HangulComposer::get_preedit() const {
	if (context == nullptr) {
		return String();
	}
	return from_ucs4(hangul_ic_get_preedit_string(context));
}

bool HangulComposer::is_empty() const {
	return context == nullptr || hangul_ic_is_empty(context);
}
