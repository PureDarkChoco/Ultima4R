class_name U6FrameStyle
extends RefCounted

## Ultima VI–inspired chrome palette (wood bezel, gold trim, stone panels).

const WOOD_SHADOW := Color("1c120c")
const WOOD_DARK := Color("3a2418")
const WOOD_MID := Color("6a4228")
const WOOD_LIGHT := Color("8f5a32")
const WOOD_HIGHLIGHT := Color("b07848")
const GOLD := Color("c9a227")
const GOLD_DIM := Color("8a6e1c")
const STONE := Color("2a2622")
const STONE_LIGHT := Color("3c3832")
const INK := Color("0e0c0a")
const SCROLL_PAPER := Color("1a1814")


static func make_wood_strip(horizontal: bool, length: int, thickness: int) -> ImageTexture:
	var w := length if horizontal else thickness
	var h := thickness if horizontal else length
	var img := Image.create(maxi(w, 1), maxi(h, 1), false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var along := float(x) / float(maxi(w - 1, 1)) if horizontal else float(y) / float(maxi(h - 1, 1))
			var across := float(y) / float(maxi(h - 1, 1)) if horizontal else float(x) / float(maxi(w - 1, 1))
			var c := WOOD_MID
			# Plank bands
			var band := int(across * 5.0) % 2
			c = WOOD_LIGHT if band == 0 else WOOD_MID
			# Bevel edges across the strip short axis
			if across < 0.12:
				c = WOOD_HIGHLIGHT
			elif across > 0.88:
				c = WOOD_SHADOW
			elif across > 0.72:
				c = WOOD_DARK
			# Subtle grain noise
			var n := int(along * 97.0 + across * 13.0) % 7
			if n == 0:
				c = c.lightened(0.06)
			elif n == 3:
				c = c.darkened(0.08)
			# Outer gold edge on the "outside" of the frame strip — top/left used by caller placement
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func make_corner(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(center) / float(size)
			var c := WOOD_MID
			if d > 0.48:
				c = Color(0, 0, 0, 0)
			elif d > 0.42:
				c = GOLD
			elif d > 0.34:
				c = WOOD_SHADOW
			elif d > 0.22:
				c = WOOD_LIGHT
			else:
				c = GOLD_DIM if d < 0.10 else WOOD_DARK
			# Boss stud highlight
			if p.distance_to(center) < size * 0.08:
				c = GOLD
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func make_inner_trim(horizontal: bool, length: int, thickness: int = 3) -> ImageTexture:
	var w := length if horizontal else thickness
	var h := thickness if horizontal else length
	var img := Image.create(maxi(w, 1), maxi(h, 1), false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var t := float(y if horizontal else x) / float(maxi((h if horizontal else w) - 1, 1))
			var c := GOLD if t < 0.35 else (GOLD_DIM if t < 0.7 else WOOD_SHADOW)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
