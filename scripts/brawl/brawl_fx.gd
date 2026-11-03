class_name BrawlFx
extends Node2D
## Cartoon hit effects for the Gelanggang, all drawn in code: impact stars,
## comic words (PAK! DUSH! POW!), dust puffs, paper bits when an item breaks,
## damage numbers. Never blood.

const WORD_FONT := "res://assets/fonts/pixelify-sans-latin-700-normal.woff2"

var _items: Array = []   ## {kind, pos, t, life, ...}
var _font: Font


func _ready() -> void:
	z_index = 100
	_font = load(WORD_FONT) if ResourceLoader.exists(WORD_FONT) else ThemeDB.fallback_font


func star(pos: Vector2, big := false) -> void:
	_items.append({"kind": "star", "pos": pos, "t": 0.0, "life": 0.22 if not big else 0.32, "r": 34.0 if not big else 56.0, "rot": randf() * TAU})


## the shock of a hit: a ring that opens out, speed lines bursting from the
## point of impact and a spray of sparks (sideways, away from the attacker)
func impact(pos: Vector2, dir: float, col: Color, big := false) -> void:
	_items.append({"kind": "ring", "pos": pos, "t": 0.0, "life": 0.28 if not big else 0.4,
		"r": 60.0 if not big else 100.0, "col": col})
	var lines := 8 if not big else 12
	for i in lines:
		var ang := TAU * i / lines + randf_range(-0.15, 0.15)
		_items.append({"kind": "line", "pos": pos, "t": 0.0, "life": randf_range(0.14, 0.22) * (1.4 if big else 1.0),
			"ang": ang, "len": randf_range(38, 62) * (1.5 if big else 1.0)})
	for i in (10 if not big else 18):
		var v := Vector2(dir * randf_range(120, 380), randf_range(-320, -60))
		_items.append({"kind": "spark", "pos": pos, "t": 0.0, "life": randf_range(0.25, 0.45), "vel": v,
			"col": col.lerp(Color.WHITE, randf() * 0.6)})
	if big:
		_items.append({"kind": "flash", "pos": pos, "t": 0.0, "life": 0.12})


func word(pos: Vector2, text: String, col := Color("ffe066"), big := false) -> void:
	_items.append({"kind": "word", "pos": pos + Vector2(randf_range(-14, 14), 0), "t": 0.0, "life": 0.7,
		"text": text, "col": col, "size": 30 if big else 20, "rot": randf_range(-0.25, 0.25)})


func number(pos: Vector2, n: int, col: Color) -> void:
	_items.append({"kind": "word", "pos": pos + Vector2(randf_range(-10, 10), -20), "t": 0.0, "life": 0.9,
		"text": "-%d" % n, "col": col, "size": 18, "rot": 0.0, "rise": 70.0})


func dust(pos: Vector2, amount := 1.0) -> void:
	for i in int(6 * amount) + 2:
		_items.append({"kind": "dust", "pos": pos + Vector2(randf_range(-30, 30), randf_range(-4, 4)), "t": 0.0,
			"life": randf_range(0.35, 0.6), "vel": Vector2(randf_range(-70, 70), randf_range(-50, -10)), "r": randf_range(6, 12)})


func poof(pos: Vector2, col: Color) -> void:
	for i in 12:
		_items.append({"kind": "bit", "pos": pos, "t": 0.0, "life": randf_range(0.5, 0.9),
			"vel": Vector2.from_angle(randf() * TAU) * randf_range(80, 220), "col": col.lerp(Color.WHITE, randf() * 0.5), "rot": randf() * TAU})
	word(pos + Vector2(0, -20), "PUF!", Color(0.95, 0.95, 1.0))


func _process(delta: float) -> void:
	for it in _items:
		it["t"] += delta
		if it.has("vel"):
			it["pos"] += it["vel"] * delta
			it["vel"].y += 380.0 * delta
	_items = _items.filter(func(it): return it["t"] < it["life"])
	queue_redraw()


func _draw() -> void:
	for it in _items:
		var k: float = it["t"] / it["life"]
		match it["kind"]:
			"star":
				var r: float = it["r"] * (0.5 + k * 0.7)
				var pts := PackedVector2Array()
				for i in 16:
					var rr := r if i % 2 == 0 else r * 0.42
					pts.append(it["pos"] + Vector2.from_angle(it["rot"] + i * PI / 8) * rr)
				draw_colored_polygon(pts, Color(1, 1, 0.85, 1.0 - k))
				draw_circle(it["pos"], r * 0.3, Color(1, 1, 1, 1.0 - k))
			"word":
				var a := 1.0 - maxf(0.0, (k - 0.6) / 0.4)
				var p: Vector2 = it["pos"] + Vector2(0, -it.get("rise", 40.0) * k)
				var s: float = 1.0 + (0.4 * (1.0 - minf(k * 6.0, 1.0)))
				draw_set_transform(p, it["rot"], Vector2(s, s))
				var size: int = it["size"]
				var w := _font.get_string_size(it["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				draw_string_outline(_font, Vector2(-w / 2.0, 0), it["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(0.1, 0.05, 0.05, a))
				draw_string(_font, Vector2(-w / 2.0, 0), it["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(it["col"], a))
				draw_set_transform(Vector2.ZERO)
			"dust":
				draw_circle(it["pos"], it["r"] * (1.0 + k), Color(0.85, 0.8, 0.7, 0.55 * (1.0 - k)))
			"bit":
				draw_set_transform(it["pos"], it["rot"] + k * 8.0, Vector2.ONE)
				draw_rect(Rect2(-5, -3, 10, 6), Color(it["col"], 1.0 - k))
				draw_set_transform(Vector2.ZERO)
			"ring":
				var e := 1.0 - pow(1.0 - k, 3.0)   # fast out, slow end
				draw_set_transform(it["pos"], 0, Vector2(1, 0.6))
				draw_arc(Vector2.ZERO, it["r"] * (0.25 + 0.75 * e), 0, TAU, 36, Color(it["col"], 0.9 * (1.0 - k)), 6.0 * (1.0 - k) + 1.0, true)
				draw_set_transform(Vector2.ZERO)
			"line":
				var d := Vector2.from_angle(it["ang"])
				var a0: float = 18.0 + 60.0 * k
				var a1: float = a0 + it["len"] * (1.0 - k)
				draw_line(it["pos"] + d * a0, it["pos"] + d * a1, Color(1, 1, 0.9, 1.0 - k), 4.0 * (1.0 - k) + 1.0)
			"spark":
				var v: Vector2 = it["vel"]
				draw_line(it["pos"], it["pos"] - v.normalized() * 10.0, Color(it["col"], 1.0 - k), 3.0)
			"flash":
				draw_circle(it["pos"], 140.0 * (0.6 + k), Color(1, 1, 0.9, 0.35 * (1.0 - k)))
