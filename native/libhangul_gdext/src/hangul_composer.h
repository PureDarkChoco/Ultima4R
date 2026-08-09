#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

#include <hangul.h>

namespace godot {

class HangulComposer : public RefCounted {
	GDCLASS(HangulComposer, RefCounted)

	HangulInputContext *context = nullptr;
	String keyboard_id = "2";

	static String from_ucs4(const ucschar *text);
	Dictionary state(bool consumed, const String &commit = String()) const;

protected:
	static void _bind_methods();

public:
	HangulComposer();
	~HangulComposer();

	void set_keyboard(const String &id);
	String get_keyboard() const;
	Dictionary process_key(int32_t ascii);
	Dictionary backspace();
	String flush();
	void reset();
	String get_preedit() const;
	bool is_empty() const;
};

} // namespace godot
