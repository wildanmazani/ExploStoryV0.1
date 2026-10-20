class_name WeaponArt
extends RefCounted
## Draws the Gelanggang school items. Uses the PixelLab picture in
## assets/brawl/<id>.png when there is one, otherwise simple cartoon shapes.
## Items are drawn pointing along +x from the hand (handle at the origin).

const DIR := "res://assets/brawl/"
static var _tex := {}


static func texture(id: String) -> Texture2D:
	if not _tex.has(id):
		var p := DIR + id + ".png"
		_tex[id] = load(p) if ResourceLoader.exists(p) else null
	return _tex[id]


static func draw_item(ci: CanvasItem, id: String, col: Color) -> void:
	var t := texture(id)
	if t:
		var s := 2.6
		ci.draw_texture_rect(t, Rect2(Vector2(-6, -t.get_height() * s / 2.0), t.get_size() * s), false)
		return
	var ink := Color(0.12, 0.08, 0.05)
	match id:
		"pembaris":
			ci.draw_rect(Rect2(0, -6, 92, 12), col)
			ci.draw_rect(Rect2(0, -6, 92, 12), ink, false, 2.0)
			for i in range(8, 90, 10):
				ci.draw_line(Vector2(i, -6), Vector2(i, -1 if i % 20 else 1), ink, 1.5)
		"buku":
			ci.draw_rect(Rect2(0, -18, 40, 36), col)
			ci.draw_rect(Rect2(34, -18, 6, 36), Color(0.95, 0.92, 0.85))
			ci.draw_rect(Rect2(0, -18, 40, 36), ink, false, 2.0)
			ci.draw_line(Vector2(8, -6), Vector2(28, -6), Color(1, 0.9, 0.5), 3.0)
		"penyapu":
			ci.draw_line(Vector2(0, 0), Vector2(84, 0), Color("8a5a2a"), 6.0)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(80, -6), Vector2(118, -20), Vector2(122, 20), Vector2(80, 6)]), col)
			for i in 5:
				ci.draw_line(Vector2(84, 0), Vector2(120, -16 + i * 8), ink, 1.2)
		"beg":
			ci.draw_rect(Rect2(10, -20, 40, 40), col)
			ci.draw_rect(Rect2(10, -20, 40, 40), ink, false, 2.0)
			ci.draw_line(Vector2(0, 0), Vector2(14, -14), ink, 4.0)
			ci.draw_rect(Rect2(18, -4, 24, 14), col.lightened(0.25))
		"bola":
			ci.draw_circle(Vector2(26, 0), 22, col)
			ci.draw_arc(Vector2(26, 0), 22, 0, TAU, 24, ink, 2.0)
			ci.draw_line(Vector2(4, 0), Vector2(48, 0), ink, 1.5)
			ci.draw_arc(Vector2(26, 0), 12, -PI / 2, PI / 2, 12, ink, 1.5)
		"bantal":
			ci.draw_rect(Rect2(0, -16, 56, 32), col)
			ci.draw_rect(Rect2(0, -16, 56, 32), Color(0.6, 0.6, 0.65), false, 2.0)
			ci.draw_line(Vector2(6, 0), Vector2(50, 0), Color(0.8, 0.8, 0.85), 1.5)
		_:
			ci.draw_rect(Rect2(0, -6, 60, 12), col)
