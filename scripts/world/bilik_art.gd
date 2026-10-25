class_name BilikArt
extends RefCounted
## Bilik Alif, drawn: a Malaysian teenager's bedroom on the 20x11 interior
## grid (320x180, 16 px cells), morning light through a louvre window.
## The PixelLab picture assets/backgrounds/bg_int_bilik_alif.png is the whole
## furnished room (made over this layout, so the collision cells still fit);
## then only the bag stays a separate sprite, since Alif picks it up. Without
## that picture every piece is drawn here in native pixels (crisp at the 4x
## camera), and assets/objects/bilik/<id>.png can replace one piece of it
## (bottom-centre on the piece's footprint, see PIECES).
## Layout (cells): bed 3-5 x 3-5, side table 6,3, bookshelf 12-13,3, fan 14,3,
## wardrobe 15-16 x 3-4, desk 15-16 x 6-7, chair 14,7, bag 12,7, shoes 12,9,
## sejadah 3-4 x 7-8, rug 8-11 x 5-7, door 9-10,10.

const SHELL_ART := "res://assets/backgrounds/bg_int_bilik_alif.png"
const PIECE_ART := "res://assets/objects/bilik/%s.png"
## pieces that stay separate when the room picture already has the furniture
const LOOSE := ["beg"]
## id -> footprint Rect2i in cells (bottom row = where it stands for y-sorting)
const PIECES := {
	"katil": Rect2i(3, 3, 3, 3),
	"meja_sisi": Rect2i(6, 3, 1, 1),
	"rak_buku": Rect2i(12, 3, 2, 1),
	"kipas": Rect2i(14, 3, 1, 1),
	"almari": Rect2i(15, 3, 2, 2),
	"meja_belajar": Rect2i(15, 6, 2, 2),
	"kerusi": Rect2i(14, 7, 1, 1),
	"beg": Rect2i(12, 7, 1, 1),
	"kasut": Rect2i(12, 9, 1, 1),
}

const OUT := Color("1c2130")
const WALL := Color("a9d6c9")
const WALL_D := Color("8fc0b2")
const WALL_TOP := Color("efe6d2")
const WALL_TOP_D := Color("c9bea4")
const TRIM := Color("f4efe2")
const WOOD := Color("8a5a36")
const WOOD_L := Color("a8774a")
const WOOD_D := Color("5a3a20")
const TILE_A := Color("e8d8b8")
const TILE_B := Color("e2d0ad")
const GROUT := Color("c9b48f")
const INK := Color("2a2230")


## Adds the room to an interior scene: shell behind everything, furniture into
## the y-sorted Objects node, sunlight and dust in front. Returns id -> node.
static func build(room: Node2D, objects: Node2D) -> Dictionary:
	var painted := ResourceLoader.exists(SHELL_ART)
	var shell := Shell.new()
	shell.drawn = not painted
	room.add_child(shell)
	room.move_child(shell, 1)  # right after the Background sprite
	var out := {}
	for id in PIECES:
		if painted and not id in LOOSE:
			continue
		var r: Rect2i = PIECES[id]
		var bottom := Vector2((r.position.x + r.size.x / 2.0) * 16.0, r.end.y * 16.0)
		var n: Node2D
		if ResourceLoader.exists(PIECE_ART % id):
			var s := Sprite2D.new()
			s.texture = load(PIECE_ART % id)
			s.offset = CharacterFrames.visible_bottom_offset(s.texture)
			n = s
		else:
			var p := Piece.new()
			p.id = id
			n = p
		n.position = bottom
		n.name = "Bilik_" + id
		objects.add_child(n)
		out[id] = n
	room.add_child(Light.new())
	return out


# ------------------------------------------------------------------ room shell
class Shell extends Node2D:
	var drawn := true

	func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
		draw_rect(Rect2(x, y, w, h), c)

	func _draw() -> void:
		if not drawn:
			return
		_r(0, 0, 320, 180, OUT)
		# back wall (rows 0-2) with ceiling edge and skirting
		_r(48, 0, 224, 48, WALL)
		_r(48, 0, 224, 3, WALL_D)
		for x in range(52, 272, 12):  # soft painted texture
			_r(x, 6 + (x / 12) % 3 * 11, 1, 1, WALL_D)
		_r(48, 43, 224, 5, WOOD)
		_r(48, 43, 224, 1, WOOD_L)
		# tiled floor (rows 3-9) and the door gap
		for y in range(3, 10):
			for x in range(3, 17):
				_r(x * 16, y * 16, 16, 16, TILE_A if (x + y) % 2 == 0 else TILE_B)
				_r(x * 16, y * 16, 16, 1, GROUT)
				_r(x * 16, y * 16, 1, 16, GROUT)
		_r(144, 160, 32, 16, TILE_A)
		_r(48, 48, 224, 3, Color(0, 0, 0, 0.12))  # shade under the wall
		# side and front walls, seen from above
		_r(40, 0, 8, 168, WALL_TOP)
		_r(272, 0, 8, 168, WALL_TOP)
		_r(40, 160, 104, 10, WALL_TOP)
		_r(176, 160, 104, 10, WALL_TOP)
		_r(40, 168, 104, 3, WALL_TOP_D)
		_r(176, 168, 104, 3, WALL_TOP_D)
		_r(47, 0, 1, 168, WALL_TOP_D)
		_r(272, 0, 1, 168, WALL_TOP_D)
		_r(140, 160, 4, 18, WOOD)   # door frame
		_r(176, 160, 4, 18, WOOD)
		_window()
		_wall_decor()
		_rug()
		_sejadah()
		# doormat (kain pengesat kaki)
		_r(148, 163, 24, 11, Color("8a6a4a"))
		for x in range(150, 171, 4):
			_r(x, 164, 2, 9, Color("a8865e"))

	## glass louvres behind a white grille, floral curtains, a coconut tree outside
	func _window() -> void:
		for y in range(8, 40):  # morning sky
			_r(134, y, 52, 1, Color("8fd0f0").lerp(Color("fde7b5"), (y - 8) / 32.0))
		draw_circle(Vector2(174, 16), 5, Color("fff3c4"))
		draw_colored_polygon(PackedVector2Array([Vector2(134, 40), Vector2(134, 31), Vector2(150, 27), Vector2(168, 32), Vector2(186, 28), Vector2(186, 40)]), Color("6fae78"))
		_r(146, 18, 2, 22, Color("6b4a2e"))  # kelapa trunk
		for f in [Vector2(-9, 3), Vector2(-6, -3), Vector2(0, -5), Vector2(7, -2), Vector2(9, 4)]:
			draw_line(Vector2(147, 18), Vector2(147, 18) + f, Color("2f6b3a"), 2.0)
		for y in range(10, 40, 4):  # louvre slats
			_r(134, y, 52, 1, Color(1, 1, 1, 0.35))
		_r(132, 6, 56, 2, TRIM)
		_r(132, 40, 56, 3, TRIM)
		_r(132, 6, 2, 36, TRIM)
		_r(186, 6, 2, 36, TRIM)
		for x in range(140, 186, 9):  # jeriji (grille)
			_r(x, 8, 1, 32, Color("e9e4d8"))
		_r(134, 23, 52, 1, Color("e9e4d8"))
		# curtain rod and langsir
		_r(120, 3, 80, 2, WOOD_D)
		for sx in [122, 186]:
			_r(sx, 5, 14, 39, Color("e88aa0"))
			for y in range(8, 42, 6):
				for x in range(sx + 2, sx + 13, 5):
					_r(x + (y / 6) % 2 * 2, y, 2, 2, Color("f6c6d1"))
			_r(sx, 5, 1, 39, Color("c96a82"))
			_r(sx, 30, 14, 2, Color("c9a24a"))  # tie-back

	func _wall_decor() -> void:
		# khat (calligraphy frame) over the bed
		_r(58, 9, 28, 18, Color("c9a24a"))
		_r(60, 11, 24, 14, Color("2f4f3a"))
		draw_arc(Vector2(66, 19), 3, PI, TAU, 6, Color("e6c96a"), 1.0)
		draw_line(Vector2(69, 19), Vector2(78, 15), Color("e6c96a"), 1.0)
		draw_arc(Vector2(76, 19), 3, 0, PI, 6, Color("e6c96a"), 1.0)
		# wall clock over the side table
		draw_circle(Vector2(104, 15), 6, INK)
		draw_circle(Vector2(104, 15), 5, Color("fbfaf5"))
		draw_line(Vector2(104, 15), Vector2(104, 11), INK, 1.0)
		draw_line(Vector2(104, 15), Vector2(107, 16), Color("c0392b"), 1.0)
		# calendar (the SPM date ringed in red)
		_r(113, 8, 14, 20, Color("fbfaf5"))
		_r(113, 8, 14, 4, Color("d9534f"))
		for y in range(14, 27, 3):
			for x in range(115, 126, 3):
				_r(x, y, 1, 1, Color("8a8a8a"))
		draw_arc(Vector2(121.5, 20.5), 2.5, 0, TAU, 8, Color("d9534f"), 1.0)
		# posters over the bookshelf: Harimau Malaya and a study timetable
		_r(194, 6, 15, 24, INK)
		_r(195, 7, 13, 22, Color("f0a030"))
		for y in range(9, 28, 4):
			_r(195, y, 4, 1, INK)
			_r(204, y + 2, 4, 1, INK)
		_r(199, 13, 5, 5, Color("fbe3b0"))
		_r(200, 14, 1, 1, INK)
		_r(202, 14, 1, 1, INK)
		_r(211, 9, 14, 19, Color("fbfaf5"))
		_r(211, 9, 14, 3, Color("3b6fb6"))
		for y in range(14, 27, 3):
			_r(212, y, 12, 1, Color("b9c4d6"))

	## a songket-style rug under the middle of the room
	func _rug() -> void:
		_r(132, 84, 56, 40, Color("b8362e"))
		_r(135, 87, 50, 34, Color("e9c46a"))
		for y in range(91, 120, 8):
			for x in range(139, 182, 8):
				var c := Vector2(x + (y / 8) % 2 * 4, y)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -3), c + Vector2(3, 0), c + Vector2(0, 3), c + Vector2(-3, 0)]), Color("b8362e"))
		for x in range(133, 188, 3):
			_r(x, 82, 1, 2, TRIM)
			_r(x, 124, 1, 2, TRIM)

	## sejadah laid in the corner (Alif walks around it)
	func _sejadah() -> void:
		_r(52, 114, 24, 30, Color("c9a24a"))
		_r(54, 116, 20, 26, Color("2f6b4a"))
		draw_colored_polygon(PackedVector2Array([Vector2(56, 128), Vector2(56, 122), Vector2(64, 117), Vector2(72, 122), Vector2(72, 128)]), Color("7a1f2b"))
		_r(63, 120, 2, 3, Color("c9a24a"))
		for y in range(131, 141, 3):
			_r(57, y, 14, 1, Color("3f8a60"))
		for x in range(52, 76, 2):
			_r(x, 144, 1, 2, TRIM)


# ------------------------------------------------------------------ furniture
class Piece extends Node2D:
	var id := ""
	var _t := 0.0

	func _process(delta: float) -> void:
		if id == "kipas":  # the fan keeps turning
			_t += delta
			queue_redraw()

	func _draw() -> void:
		# draw in room pixels: this node sits at the piece's bottom-centre
		draw_set_transform(-position)
		match id:
			"katil": _bed()
			"meja_sisi": _side_table()
			"rak_buku": _bookshelf()
			"kipas": _fan()
			"almari": _wardrobe()
			"meja_belajar": _desk()
			"kerusi": _chair()
			"beg": _bag()
			"kasut": _shoes()

	func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
		draw_rect(Rect2(x, y, w, h), c)

	func _bed() -> void:
		_r(52, 94, 44, 4, Color(0, 0, 0, 0.18))  # shadow
		_r(48, 34, 48, 18, WOOD)  # headboard
		_r(48, 34, 48, 3, WOOD_L)
		_r(54, 39, 1, 10, WOOD_D)
		_r(89, 39, 1, 10, WOOD_D)
		_r(49, 50, 46, 46, WOOD_D)  # frame
		_r(50, 50, 44, 44, Color("f3f1ea"))  # sheet
		_r(56, 52, 28, 12, Color("cfcac0"))  # pillow
		_r(57, 52, 26, 11, Color("fbfaf5"))
		_r(57, 57, 26, 1, Color("d9e6f2"))
		_r(86, 56, 7, 28, Color("cdbf9e"))  # bantal peluk
		_r(87, 57, 5, 26, Color("f5e9d0"))
		_r(50, 66, 44, 28, Color("3b7fa6"))  # batik selimut
		_r(50, 66, 44, 4, Color("5a9cc0"))
		for y in range(73, 93, 6):
			for x in range(53, 92, 6):
				var c := Vector2(x + (y / 6) % 2 * 3, y)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -2), c + Vector2(2, 0), c + Vector2(0, 2), c + Vector2(-2, 0)]), Color("8ec7e0"))
				_r(c.x, c.y, 1, 1, Color("f3d36a"))
		_r(49, 94, 46, 2, WOOD)

	func _side_table() -> void:
		_r(98, 50, 13, 4, WOOD_L)
		_r(98, 54, 13, 10, WOOD)
		_r(99, 58, 11, 1, WOOD_D)
		_r(104, 56, 1, 1, Color("e6c96a"))
		_r(99, 44, 5, 7, Color("c9a24a"))  # family photo
		_r(100, 45, 3, 5, Color("9fd0e0"))
		_r(105, 46, 5, 5, Color("d9534f"))  # alarm clock
		_r(106, 47, 3, 3, Color("fbfaf5"))

	func _bookshelf() -> void:
		_r(194, 40, 28, 24, WOOD)
		_r(194, 40, 28, 3, WOOD_L)
		var cols := [Color("d9534f"), Color("3b6fb6"), Color("f0c24a"), Color("5fae6a"), Color("8e6cc0"), Color("e88aa0"), Color("4aa3a3")]
		for row in 2:
			var x := 196
			var i := row * 3
			while x < 220:
				var w := 2 + (i * 7) % 3
				_r(x, 45 + row * 9, w, 7 - (i % 2), cols[i % cols.size()])
				x += w + 1
				i += 1
		_r(213, 34, 5, 6, Color("e6c96a"))  # a little trophy
		_r(214, 33, 3, 2, Color("e6c96a"))

	func _fan() -> void:
		draw_circle(Vector2(232, 62), 5, Color("9aa4ab"))
		draw_circle(Vector2(232, 61), 4, Color("bfc6cc"))
		_r(231, 42, 2, 19, Color("dfe3e6"))
		draw_circle(Vector2(232, 35), 8, Color("9aa4ab"))
		draw_circle(Vector2(232, 35), 7, Color("e6eef2"))
		for k in 3:
			var a := _t * 14.0 + k * TAU / 3.0
			draw_line(Vector2(232, 35), Vector2(232, 35) + Vector2.from_angle(a) * 6.0, Color("7fb2e0"), 3.0)
		draw_circle(Vector2(232, 35), 2, Color("4a7fc0"))
		draw_arc(Vector2(232, 35), 7, 0, TAU, 16, Color("b5bfc6"), 1.0)

	func _wardrobe() -> void:
		_r(246, 21, 16, 6, Color("c84a3a"))  # a suitcase on top
		_r(246, 21, 16, 1, Color("e06a5a"))
		_r(242, 26, 30, 54, WOOD_D)
		_r(243, 27, 28, 4, WOOD_L)
		_r(243, 31, 28, 48, Color("9c6a3c"))
		_r(256, 31, 1, 48, WOOD_D)
		_r(245, 34, 9, 42, Color("bfe0ea"))  # mirror
		draw_line(Vector2(247, 40), Vector2(252, 34), Color(1, 1, 1, 0.7), 1.0)
		draw_line(Vector2(247, 48), Vector2(253, 40), Color(1, 1, 1, 0.5), 1.0)
		_r(254, 52, 1, 5, Color("e6c96a"))
		_r(259, 52, 1, 5, Color("e6c96a"))
		_r(244, 80, 28, 2, Color(0, 0, 0, 0.18))

	func _desk() -> void:
		_r(240, 96, 32, 32, WOOD_D)
		_r(241, 97, 30, 30, Color("c99a63"))
		_r(245, 104, 15, 10, Color("6b4a2e"))  # open textbook
		_r(246, 104, 6, 9, Color("fbfaf5"))
		_r(253, 104, 6, 9, Color("fbfaf5"))
		for y in range(106, 112, 2):
			_r(247, y, 4, 1, Color("9aa0aa"))
			_r(254, y, 4, 1, Color("9aa0aa"))
		_r(262, 100, 7, 3, Color("3b6fb6"))  # book pile
		_r(262, 103, 7, 3, Color("d9534f"))
		_r(263, 106, 6, 3, Color("5fae6a"))
		_r(245, 118, 11, 4, Color("e05a5a"))  # pencil case
		_r(258, 118, 4, 5, Color("fbfaf5"))  # mug
		_r(262, 120, 1, 2, Color("fbfaf5"))
		draw_circle(Vector2(266, 118), 3, Color("4a7fc0"))  # desk lamp
		draw_circle(Vector2(266, 118), 1, Color("ffe9a0"))

	func _chair() -> void:
		_r(226, 114, 12, 12, WOOD)
		_r(227, 115, 10, 10, WOOD_L)
		_r(225, 110, 3, 18, WOOD_D)

	func _bag() -> void:
		_r(196, 126, 12, 2, Color(0, 0, 0, 0.2))
		_r(195, 113, 13, 14, Color("1b2a44"))
		_r(196, 114, 11, 12, Color("3b6fb6"))
		_r(196, 114, 11, 5, Color("5a8fd6"))
		_r(200, 118, 3, 2, Color("ffd24a"))
		_r(198, 111, 7, 2, Color("1b2a44"))  # handle
		draw_circle(Vector2(206, 123), 2, Color("f5e9d0"))  # a Pau keychain

	func _shoes() -> void:
		_r(194, 152, 14, 7, WOOD)
		_r(194, 152, 14, 2, WOOD_L)
		for x in [195, 201]:
			_r(x, 146, 5, 7, Color("9a9a92"))
			_r(x, 146, 4, 6, Color("f7f7f2"))
			_r(x + 1, 147, 2, 1, Color("c9c9c0"))


## morning sun through the louvres, with dust floating in it
class Light extends Node2D:
	var _t := 0.0

	func _ready() -> void:
		z_index = 10

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(134, 44), Vector2(186, 44), Vector2(168, 122), Vector2(108, 122)]), Color(1, 0.94, 0.7, 0.10))
		for i in 9:
			var p := Vector2(140 + fmod(i * 23.0 + _t * 3.0, 40.0), 50 + fmod(i * 17.0 + _t * 5.0, 66.0))
			p.x -= (p.y - 44) * 0.3
			draw_rect(Rect2(p.floor(), Vector2.ONE), Color(1, 0.97, 0.85, 0.35 + 0.3 * sin(_t * 2.0 + i)))
