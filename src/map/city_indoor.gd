extends Object

## Hand-listed indoor cells. No rain on those tiles.
## Letter cells: AA=0 … AP=15, BA=16 … BP=31 (X/Y).
## INDOOR ranges: ["AB/BH", "AK/BO"] inclusive.
## OUTDOOR ranges punch holes after INDOOR (courtyards, streets).
## WHOLE_INDOOR: entire 32×32.

const WIDTH := 32
const HEIGHT := 32
const TILE_COUNT := WIDTH * HEIGHT

const WHOLE_INDOOR := {}

const INDOOR := {
	"moonglow.ult": [
		["AB/BH", "AK/BO"],
		["AO/AA", "BP/AI"],
		["BH/AL", "BO/BC"],
		["BG/BF", "BN/BN"],
	],
	"britain.ult": [
		["AB/AB", "AK/AJ"],
		["BA/AA", "BP/AI"],
		["BF/AJ", "BP/AP"],
		["AA/BE", "AD/BG"],
		["AA/BH", "AI/BP"],
	],
	"jhelom.ult": [
		["AA/AA", "AE/AE"],
		["BL/AA", "BP/AE"],
		["AA/BL", "AE/BP"],
		["BL/BL", "BP/BP"],
		["AC/AB", "BO/BO"],
	],
	"yew.ult": [
		["AM/AE", "BL/AO"],
		["AE/BE", "AM/BL"],
		["BD/BF", "BL/BL"],
	],
	"minoc.ult": [
		["AA/AA", "BF/AI"],
		["BH/AA", "BP/AK"],
		["AL/BH", "BF/BP"],
		["BG/BJ", "BN/BP"],
	],
	"trinsic.ult": [
		["AA/AA", "BP/AI"],
		["BB/BB", "BL/BL"],
		["AA/AJ", "AA/AN"],
		["AA/BB", "AA/BO"],
		["AA/BP", "BP/BP"],
		["BP/AJ", "BP/BO"],
	],
	"skara.ult": [
		["BD/AK", "BN/BE"],
	],
	"lcb_1.ult": [
		["AA/AA", "AG/AG"],
		["AH/AB", "AI/AC"],
		["BI/AA", "BO/AG"],
		["AA/BJ", "AG/BP"],
		["BI/BJ", "BO/BP"],
		["AD/AD", "BL/BM"],
	],
	"lcb_2.ult": [
		["AA/AA", "AG/AG"],
		["BI/AA", "BO/AG"],
		["AA/BJ", "AG/BP"],
		["BI/BJ", "BO/BP"],
		["AD/AD", "BL/BM"],
	],
	"empath.ult": [
		["AA/AA", "AG/AG"],
		["AD/AD", "AP/AJ"],
		["AD/AK", "BO/BA"],
		["AD/BB", "BL/BJ"],
		["AA/BJ", "AG/BP"],
		["BI/BJ", "BO/BP"],
	],
	"lycaeum.ult": [
		["AA/AA", "AI/AJ"],
		["BA/AA", "BM/BA"],
		["AD/AC", "BL/BM"],
		["AA/BJ", "AG/BP"],
		["BI/BJ", "BO/BP"],
	],
	"serpent.ult": [
		["AA/AA", "AG/AG"],
		["BI/AA", "BO/AG"],
		["AA/BJ", "AG/BP"],
		["BI/BJ", "BO/BP"],
		["AD/AD", "BL/BL"],
		["AH/BM", "AL/BM"],
		["BD/BM", "BH/BM"],
	],
	"cove.ult": [
		["BF/AA", "BP/AE"],
		["BH/AF", "BP/AM"],
		["BI/AN", "BO/AN"],
		["BF/BG", "BM/BM"],
	],
	"paws.ult": [
		["AE/AC", "AL/AC"],
		["BE/AC", "BL/AC"],
		["AD/AD", "BC/AJ"],
		["BD/AD", "BM/AK"],
		["AP/BD", "BE/BK"],
	],
	"vesper.ult": [
		["AK/AI", "BF/BC"],
		["AE/BD", "BL/BI"],
		["AF/BJ", "BK/BJ"],
		["AI/BK", "BH/BM"],
	],
	"den.ult": [
		["AF/AE", "AL/AK"],
		["BD/AE", "BK/BD"],
		["BL/AF", "BL/AJ"],
		["BE/BE", "BJ/BE"],
		["AI/BD", "AN/BE"],
		["AF/BF", "BA/BK"],
		["AG/BL", "AP/BL"],
		["AH/BM", "AO/BM"],
	],
}

const OUTDOOR := {
	"jhelom.ult": [
		["AH/AK", "BC/BE"],
		["BD/AM", "BL/BA"],
		["BD/BB", "BF/BE"],
	],
}


static func normalize_fname(fname: String) -> String:
	return fname.get_file().to_lower()


static func cell(code: String) -> int:
	var s := code.strip_edges().to_upper()
	if s.length() != 2:
		return -1
	var a := s.unicode_at(0) - 65
	var b := s.unicode_at(1) - 65
	if a < 0 or a > 1 or b < 0 or b > 15:
		return -1
	return a * 16 + b


static func parse_xy(token: String) -> Vector2i:
	var parts := token.strip_edges().to_upper().split("/")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	var x := cell(parts[0])
	var y := cell(parts[1])
	if x < 0 or y < 0:
		return Vector2i(-1, -1)
	return Vector2i(x, y)


static func is_indoor_at(fname: String, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT:
		return false
	var bits := mask_for(fname)
	if bits.size() < TILE_COUNT:
		return false
	return bits[y * WIDTH + x] != 0


static func mask_for(fname: String) -> PackedByteArray:
	var key := normalize_fname(fname)
	var out := PackedByteArray()
	out.resize(TILE_COUNT)
	if bool(WHOLE_INDOOR.get(key, false)):
		out.fill(1)
	else:
		out.fill(0)
	var rects: Variant = INDOOR.get(key, [])
	if typeof(rects) == TYPE_ARRAY:
		for raw in rects:
			_fill_rect(out, raw, 1)
	var holes: Variant = OUTDOOR.get(key, [])
	if typeof(holes) == TYPE_ARRAY:
		for raw in holes:
			_fill_rect(out, raw, 0)
	return out


static func image_for(fname: String) -> Image:
	var bits := mask_for(fname)
	var img := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	for y in HEIGHT:
		for x in WIDTH:
			if bits[y * WIDTH + x] != 0:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	return img


static func row_bits_for(fname: String) -> PackedInt32Array:
	var bits := mask_for(fname)
	var rows := PackedInt32Array()
	rows.resize(HEIGHT)
	for y in HEIGHT:
		var row := 0
		for x in WIDTH:
			if bits[y * WIDTH + x] != 0:
				row |= (1 << x)
		rows[y] = row
	return rows


static func _fill_rect(out: PackedByteArray, raw: Variant, value: int) -> void:
	var x0 := -1
	var y0 := -1
	var x1 := -1
	var y1 := -1
	if typeof(raw) == TYPE_ARRAY:
		var r: Array = raw
		if r.size() >= 2 and typeof(r[0]) == TYPE_STRING:
			var a := parse_xy(str(r[0]))
			var b := parse_xy(str(r[1]))
			if a.x < 0 or b.x < 0:
				return
			x0 = a.x
			y0 = a.y
			x1 = b.x
			y1 = b.y
		elif r.size() >= 4:
			x0 = int(r[0])
			y0 = int(r[1])
			x1 = int(r[2])
			y1 = int(r[3])
		else:
			return
	else:
		return
	x0 = clampi(x0, 0, WIDTH - 1)
	y0 = clampi(y0, 0, HEIGHT - 1)
	x1 = clampi(x1, 0, WIDTH - 1)
	y1 = clampi(y1, 0, HEIGHT - 1)
	if x1 < x0:
		var tx := x0
		x0 = x1
		x1 = tx
	if y1 < y0:
		var ty := y0
		y0 = y1
		y1 = ty
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			out[y * WIDTH + x] = value
