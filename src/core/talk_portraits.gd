class_name TalkPortraits
extends RefCounted

## Painted town faces under assets/portraits/npcs/<city>/.
## Always reads the current PNG bytes so hand-edits apply without a reimport.

const NPC_ROOT := "res://assets/portraits/npcs"
const COMPANION_DIR := "res://assets/portraits/companions"
const AVATAR_DIR := "res://assets/portraits/avatars"

const AVATAR_CLASS_NAMES := [
	"mage", "bard", "fighter", "druid", "tinker", "paladin", "ranger", "shepherd",
]
const COMPANION_SLUGS := [
	"mariah", "iolo", "geoffrey", "jaana", "julia", "dupre", "shamino", "katrina",
]

## topic2 (classic 4-letter) → file slug when several NPCs share a name.
const TOPIC_SLUGS := {
	"lcb/lieg": "guard_liege",
	"lcb/cast": "guard_castle",
	"lcb/trea": "guard_treasure",
	"lycaeum/hour": "guard_sleepy",
	"lycaeum/woun": "injured_fighter",
	"yew/cour": "guard_2",
	"yew/felo": "guard_3",
	"yew/just": "guard_15",
}

## city/slugified TLK name → file slug when tokens do not match the PNG.
const NAME_SLUGS := {
	"cove/rabindranath_tagore": "rabindranath",
	"den/jeremy_james_scirlock": "scirlock",
	"lycaeum/father_antos": "antos",
	"lycaeum/lord_terence": "terence",
	"lycaeum/a_fighter": "injured_fighter",
	"skara/the_ankh_of_spirituality": "ankh",
	"yew/druid": "wandering_druid",
	"yew/a_ranger": "female_ranger",
}

static var _city_dir_names: Dictionary = {} ## lower city -> on-disk folder
static var _city_files: Dictionary = {} ## lower city -> { lower slug -> on-disk slug }
static var _companion_names: Dictionary = {} ## lower slug -> on-disk slug
static var _tex_cache: Dictionary = {} ## path -> Texture2D


static func reload() -> void:
	_city_dir_names.clear()
	_city_files.clear()
	_companion_names.clear()
	_tex_cache.clear()
	_scan_all_cities()
	_ensure_companions()


static func npc_texture(
	city_id: String,
	npc_name: String,
	discourse_index: int = -1,
	topic2: String = "",
	person_slot: int = -1
) -> Texture2D:
	var path := npc_path(city_id, npc_name, discourse_index, topic2, person_slot)
	if path.is_empty():
		return null
	return load_texture(path)


static func avatar_texture(klass: int, sex: String) -> Texture2D:
	var k := clampi(klass, 0, AVATAR_CLASS_NAMES.size() - 1)
	var sex_key := "female" if sex == "female" else "male"
	return load_texture("%s/%s_%s.png" % [AVATAR_DIR, AVATAR_CLASS_NAMES[k], sex_key])


static func companion_texture(klass: int) -> Texture2D:
	if klass < 0 or klass >= COMPANION_SLUGS.size():
		return null
	var path := _companion_file(COMPANION_SLUGS[klass])
	if path.is_empty():
		return null
	return load_texture(path)


static func load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _tex_cache.has(path):
		return _tex_cache[path] as Texture2D
	## Editor: read the live PNG so hand-edits apply without a reimport.
	## Export: fall back to the imported Texture2D inside the PCK.
	var img: Image = null
	var abs_path := ProjectSettings.globalize_path(path)
	if abs_path != path and FileAccess.file_exists(abs_path):
		img = Image.load_from_file(abs_path)
	if img == null or img.is_empty():
		var packed := ResImage.load_rgba8(path)
		if packed != null and not packed.is_empty():
			var packed_tex := ImageTexture.create_from_image(packed)
			_tex_cache[path] = packed_tex
			return packed_tex
		var res := ResourceLoader.load(path) as Texture2D
		if res != null:
			_tex_cache[path] = res
			return res
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[path] = tex
	return tex


static func npc_path(
	city_id: String,
	npc_name: String,
	discourse_index: int = -1,
	topic2: String = "",
	person_slot: int = -1
) -> String:
	_ensure_city(city_id)
	var city := city_id.strip_edges().to_lower()
	var topic := topic2.strip_edges().to_lower()
	if topic.length() > 4:
		topic = topic.substr(0, 4)
	var topic_key := "%s/%s" % [city, topic]
	if TOPIC_SLUGS.has(topic_key) and _is_generic_name(npc_name):
		var topic_slug := str(TOPIC_SLUGS[topic_key])
		var topic_path := _city_file(city, topic_slug)
		if not topic_path.is_empty():
			return topic_path
	var name_key := "%s/%s" % [city, _slugify(npc_name)]
	if NAME_SLUGS.has(name_key):
		var named := _city_file(city, str(NAME_SLUGS[name_key]))
		if not named.is_empty():
			return named
	var variants := _slug_variants(npc_name)
	for idx in _lookup_indices(discourse_index, person_slot):
		for slug in variants:
			var indexed := _city_file(city, "%s_%d" % [slug, idx])
			if not indexed.is_empty():
				return indexed
	for slug in variants:
		var exact := _city_file(city, slug)
		if not exact.is_empty():
			return exact
	for slug in variants:
		var prefixed := _city_file_unique_prefix(city, slug)
		if not prefixed.is_empty():
			return prefixed
	for slug in variants:
		var suffixed := _city_file_unique_suffix(city, slug)
		if not suffixed.is_empty():
			return suffixed
	## Companion faces double as town portraits when the town file is missing.
	for slug in variants:
		var companion := _companion_file(slug)
		if not companion.is_empty():
			return companion
	if city == "lcb":
		for slug in variants:
			if slug.find("british") >= 0 or slug == "lb":
				var lb := _city_file("lcb", "lord_british")
				if not lb.is_empty():
					return lb
			if slug.find("hawk") >= 0:
				var hawk := _city_file("lcb", "hawkwind")
				if not hawk.is_empty():
					return hawk
	return ""


static func _lookup_indices(discourse_index: int, person_slot: int) -> Array[int]:
	## Files use 0- or 1-based .TLK slots and sometimes the .ULT person slot.
	var out: Array[int] = []
	for base in [discourse_index, person_slot]:
		if base < 0:
			continue
		for raw in [base, base + 1]:
			if raw < 0 or out.has(raw):
				continue
			out.append(raw)
	return out


static func _is_generic_name(npc_name: String) -> bool:
	var raw := _slugify(npc_name)
	if raw.is_empty():
		return false
	for prefix in ["a_", "an_", "the_"]:
		if raw.begins_with(prefix):
			raw = raw.substr(prefix.length())
			break
	var parts := raw.split("_", false)
	var role := parts[parts.size() - 1] if parts.size() > 0 else raw
	return role in ["guard", "child", "fighter", "ranger"]


static func _slug_variants(npc_name: String) -> Array[String]:
	var raw := _slugify(npc_name)
	var out: Array[String] = []
	_add_unique(out, raw)
	for prefix in ["a_", "an_", "the_"]:
		if raw.begins_with(prefix):
			_add_unique(out, raw.substr(prefix.length()))
	## "a nameless prisoner" → nameless_prisoner
	if raw.begins_with("a_nameless_"):
		_add_unique(out, raw.substr(2))
	if raw.begins_with("an_"):
		_add_unique(out, raw.substr(3))
	for hon: String in ["lord", "lady", "sir", "father", "brother", "sister", "frater"]:
		var hon_pre := hon + "_"
		if raw.begins_with(hon_pre):
			_add_unique(out, raw.substr(hon_pre.length()))
	var parts := raw.split("_", false)
	if parts.size() >= 2:
		_add_unique(out, parts[0])
		_add_unique(out, parts[parts.size() - 1])
		_add_unique(out, "%s_%s" % [parts[0], parts[1]])
	return out


static func _slugify(name: String) -> String:
	var t := name.strip_edges().to_lower()
	t = t.replace("'", "")
	t = t.replace("’", "")
	t = t.replace(".", "")
	var buf := ""
	for i in t.length():
		var ch := t.unicode_at(i)
		var is_alnum := (
			(ch >= 48 and ch <= 57)
			or (ch >= 97 and ch <= 122)
		)
		if is_alnum:
			buf += char(ch)
		elif buf.is_empty() or buf[buf.length() - 1] == "_":
			continue
		else:
			buf += "_"
	while buf.ends_with("_"):
		buf = buf.substr(0, buf.length() - 1)
	return buf


static func _add_unique(out: Array[String], slug: String) -> void:
	if slug.is_empty():
		return
	if out.has(slug):
		return
	out.append(slug)


static func _norm_key(s: String) -> String:
	return s.strip_edges().to_lower()


static func _portrait_path(city: String, slug: String) -> String:
	return "%s/%s/%s_portrait.png" % [NPC_ROOT, _city_dir(city), slug]


static func _city_dir(city: String) -> String:
	_index_npc_root()
	var key := _norm_key(city)
	if _city_dir_names.has(key):
		return str(_city_dir_names[key])
	return key


static func _city_slug_map(city: String) -> Dictionary:
	var key := _norm_key(city)
	if not _city_files.has(key):
		return {}
	var mapped: Dictionary = _city_files[key]
	return mapped


static func _city_file(city: String, slug: String) -> String:
	if city.is_empty() or slug.is_empty():
		return ""
	_ensure_city(city)
	var files := _city_slug_map(city)
	var slug_key := _norm_key(slug)
	if files.has(slug_key):
		return _portrait_path(city, str(files[slug_key]))
	return ""


static func _city_file_unique_suffix(city: String, slug: String) -> String:
	if city.is_empty() or slug.is_empty():
		return ""
	_ensure_city(city)
	var files := _city_slug_map(city)
	var slug_key := _norm_key(slug)
	var tail := "_%s" % slug_key
	var hits: Array[String] = []
	for actual_v in files.values():
		var actual := str(actual_v)
		var actual_l := actual.to_lower()
		if actual_l == slug_key or actual_l.ends_with(tail):
			hits.append(actual)
	if hits.size() == 1:
		return _portrait_path(city, hits[0])
	return ""


static func _city_file_unique_prefix(city: String, slug: String) -> String:
	if city.is_empty() or slug.is_empty():
		return ""
	_ensure_city(city)
	var files := _city_slug_map(city)
	var slug_key := _norm_key(slug)
	var prefix := "%s_" % slug_key
	var hits: Array[String] = []
	for actual_v in files.values():
		var actual := str(actual_v)
		var actual_l := actual.to_lower()
		if actual_l == slug_key or actual_l.begins_with(prefix):
			hits.append(actual)
	if hits.size() == 1:
		return _portrait_path(city, hits[0])
	return ""


static func _companion_file(slug: String) -> String:
	_ensure_companions()
	var key := _norm_key(slug)
	if key.is_empty() or not _companion_names.has(key):
		return ""
	return "%s/%s_portrait.png" % [COMPANION_DIR, str(_companion_names[key])]


static func _portrait_slug_from_filename(fname: String) -> String:
	var n := fname.get_file()
	var n_l := n.to_lower()
	if n_l.ends_with(".png"):
		n = n.substr(0, n.length() - 4)
		n_l = n.to_lower()
	if n_l.ends_with("_portrait"):
		return n.substr(0, n.length() - "_portrait".length())
	return ""


static func _remember_slug(slugs: Dictionary, actual: String) -> void:
	if actual.is_empty():
		return
	var key := actual.to_lower()
	if not slugs.has(key):
		slugs[key] = actual


static func _remember_city_dir(actual: String) -> void:
	var name := actual.strip_edges().trim_suffix("/")
	if name.is_empty() or name.begins_with("."):
		return
	var key := name.to_lower()
	if not _city_dir_names.has(key):
		_city_dir_names[key] = name


static func _index_npc_root() -> void:
	if not _city_dir_names.is_empty():
		return
	if ResourceLoader.has_method("list_directory"):
		for entry_v in ResourceLoader.list_directory(NPC_ROOT):
			var entry := String(entry_v)
			if entry.ends_with("/"):
				_remember_city_dir(entry)
	var root_abs := ProjectSettings.globalize_path(NPC_ROOT)
	if not DirAccess.dir_exists_absolute(root_abs):
		return
	var dir := DirAccess.open(root_abs)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if dir.current_is_dir() and not fname.begins_with("."):
			_remember_city_dir(fname)
		fname = dir.get_next()
	dir.list_dir_end()


static func _ensure_city(city_id: String) -> void:
	var city := _norm_key(city_id)
	if city.is_empty() or _city_files.has(city):
		return
	_index_npc_root()
	var slugs: Dictionary = {}
	var dir_path := "%s/%s" % [NPC_ROOT, _city_dir(city)]
	for fname in ResImage.list_png_names(dir_path):
		_remember_slug(slugs, _portrait_slug_from_filename(String(fname)))
	## Loose files (editor / hand-edits) when the import index is stale.
	var abs_dir := ProjectSettings.globalize_path(dir_path)
	if DirAccess.dir_exists_absolute(abs_dir):
		var dir := DirAccess.open(abs_dir)
		if dir != null:
			dir.list_dir_begin()
			var fname := dir.get_next()
			while fname != "":
				if not dir.current_is_dir():
					_remember_slug(slugs, _portrait_slug_from_filename(fname))
				fname = dir.get_next()
			dir.list_dir_end()
	_city_files[city] = slugs


static func _ensure_companions() -> void:
	if not _companion_names.is_empty():
		return
	for fname in ResImage.list_png_names(COMPANION_DIR):
		_remember_slug(_companion_names, _portrait_slug_from_filename(String(fname)))
	var abs_dir := ProjectSettings.globalize_path(COMPANION_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	var dir := DirAccess.open(abs_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			_remember_slug(_companion_names, _portrait_slug_from_filename(fname))
		fname = dir.get_next()
	dir.list_dir_end()


static func _scan_all_cities() -> void:
	_index_npc_root()
	for city_v in _city_dir_names.keys():
		_ensure_city(str(city_v))
