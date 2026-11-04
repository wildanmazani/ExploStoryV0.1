extends RefCounted
## Aisyah's sprite taken apart into the four things the Bab 2 clues are about
## (tudung, baju, kain, kulit), so that the Klu Aisyah poster can stay a dark
## shape until a clue shows that part, and the Gua Kabus line-up can dress
## other girls differently (scripts/ui/aisyah_pilih.gd).

const SPRITE := "res://assets/characters32/rakan_aisyah/rakan_aisyah_south.png"
const PARTS := ["tudung", "baju", "kain", "kulit"]  ## the order of the clues
const HIDDEN := Color(0.16, 0.13, 0.22)


## which clue a pixel belongs to ("" = outline, hair, straps, shoes)
static func part(c: Color, x: int, y: int) -> String:
	if c.a < 0.1:
		return ""
	var warm := c.r > c.b + 0.08 and c.r >= c.g
	if warm and c.s > 0.2 and c.v > 0.55:
		return "kulit"
	var light := c.s < 0.25 and c.v > 0.68
	var bluish := c.b > c.r + 0.1 and c.v > 0.3
	if y <= 17:
		if light and y >= 11 and y <= 14 and x >= 12 and x <= 23:
			return ""  # the whites of her eyes
		return "tudung" if light or bluish else ""
	if light and y <= 21:
		return "tudung"
	if bluish:
		return "baju" if y <= 24 else "kain"
	return ""


## shown: the parts drawn as they are (the rest is a dark shape; the details
## of the face come with "kulit"). swaps: part -> colour to dress it in instead.
static func texture(shown: Array, swaps := {}) -> Texture2D:
	var src: Image = load(SPRITE).get_image()
	src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var out := Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a < 0.1:
				continue
			var p := part(c, x, y)
			var key := p if p != "" else "kulit"
			var dark := c.v < 0.15  # the outline stays
			if swaps.has(p):
				var to: Color = swaps[p]
				c = Color(to.r * (0.55 + 0.45 * c.v), to.g * (0.55 + 0.45 * c.v), to.b * (0.55 + 0.45 * c.v), c.a)
			elif not dark and not shown.has(key):
				c = Color(HIDDEN, c.a)
			out.set_pixel(x, y, c)
	return ImageTexture.create_from_image(out)
