extends CanvasLayer
## On-screen D-pad + A (act) / B (run) for phones. Uses TouchScreenButton so
## it presses the same input actions as the keyboard, and only shows on
## touchscreens.

const SIZE := 96          ## D-pad arrow size (screen px, 1280x720 space)
const BTN := 112          ## A/B button diameter
const MARGIN := 36


func _ready() -> void:
	layer = 20
	visible = DisplayServer.is_touchscreen_available()
	var pad_center := Vector2(MARGIN + SIZE * 1.5, 720 - MARGIN - SIZE * 1.5)
	_add_button("move_up", _arrow_tex(0), pad_center + Vector2(-SIZE / 2.0, -SIZE * 1.5))
	_add_button("move_down", _arrow_tex(2), pad_center + Vector2(-SIZE / 2.0, SIZE * 0.5))
	_add_button("move_left", _arrow_tex(3), pad_center + Vector2(-SIZE * 1.5, -SIZE / 2.0))
	_add_button("move_right", _arrow_tex(1), pad_center + Vector2(SIZE * 0.5, -SIZE / 2.0))
	_add_button("interact", _round_tex("A", Color("e8b04a")), Vector2(1280 - MARGIN - BTN, 720 - MARGIN - BTN * 1.45), "A")
	_add_button("run", _round_tex("B", Color("7aa7d9")), Vector2(1280 - MARGIN - BTN * 2.1, 720 - MARGIN - BTN * 0.9), "B")


func _add_button(action: String, tex: Texture2D, pos: Vector2, label := "") -> void:
	var b := TouchScreenButton.new()
	b.texture_normal = tex
	b.action = action
	b.position = pos
	b.passby_press = true  # slide a thumb across the D-pad without lifting
	b.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	b.modulate = Color(1, 1, 1, 0.7)
	add_child(b)
	if label != "":
		var l := Label.new()
		l.text = label
		l.size = tex.get_size()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 44)
		l.add_theme_color_override("font_color", Color(0.17, 0.11, 0.06))
		b.add_child(l)


## rounded square with a triangle pointing up/right/down/left (0..3)
func _arrow_tex(dir: int) -> Texture2D:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var bg := Color(0.12, 0.08, 0.05, 0.55)
	var fg := Color(1, 0.95, 0.8, 0.95)
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x, y) - Vector2(SIZE, SIZE) / 2.0
			if absf(p.x) < SIZE * 0.46 and absf(p.y) < SIZE * 0.46:
				img.set_pixel(x, y, bg)
			var q := p.rotated(-dir * PI / 2.0)  # draw an "up" triangle in rotated space
			if q.y > -SIZE * 0.22 and q.y < SIZE * 0.14 and absf(q.x) < (q.y + SIZE * 0.22) * 0.75:
				img.set_pixel(x, y, fg)
	return ImageTexture.create_from_image(img)


func _round_tex(_letter: String, color: Color) -> Texture2D:
	var img := Image.create(BTN, BTN, false, Image.FORMAT_RGBA8)
	var r := BTN / 2.0
	for y in BTN:
		for x in BTN:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(r, r))
			if d < r - 1:
				img.set_pixel(x, y, color.darkened(0.25) if d > r - 7 else color)
	return ImageTexture.create_from_image(img)
