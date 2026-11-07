extends Control
## Kotak bintang: a small, optional 1-5 star rating with an optional comment.
## Opened from the star button in the HUD (a small box under the button), and
## once after Misi 1.1 and once after Bab 1 (centred). "Nanti" always closes
## it without rating. Sent anonymously with Backend.send_rating
## (supabase/patch_penilaian.sql).

const UI = preload("res://scripts/ui/ui.gd")

signal closed

var context := "hud"                 ## where it was asked: hud, misi_1_1, bab_1
var heading := "Nilai ExploStory?"
var anchor := Vector2(-1, -1)        ## HUD: the button's bottom-right corner; -1 = centred
var stars := 0
var _stars: Array[Star] = []
var _send: Button
var _comment: LineEdit
var _box: PanelContainer


## Once per save for each place (misi_1_1, bab_1): returns when it is closed.
static func ask_once(ctx: String, text: String) -> void:
	var asked: Array = Game.save.get("rating_asked", [])
	if asked.has(ctx):
		return
	asked.append(ctx)
	Game.save["rating_asked"] = asked
	Game.persist()
	var k = load("res://scripts/ui/kotak_bintang.gd").new()
	k.context = ctx
	k.heading = text
	Game.main.overlay_root().add_child(k)
	await k.closed


func _ready() -> void:
	UI.full(self)
	theme = Game.theme
	mouse_filter = Control.MOUSE_FILTER_STOP
	Game.lock_input()
	var centred := anchor.x < 0
	var shade := UI.dim(0.5 if centred else 0.0)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	if not centred:  # a tap outside the small box closes it
		shade.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed:
				close())
	add_child(shade)

	_box = UI.panel("Paper")
	_box.name = "KotakBintang"
	_box.custom_minimum_size = Vector2(360 if not centred else 460, 0)
	var col := UI.vbox(10)
	var h := UI.label(tr(heading), "InkHeading", true)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(h)
	var row := UI.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 5:
		var s := Star.new()
		s.custom_minimum_size = Vector2(44, 44)
		s.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		s.name = "Bintang_%d" % (i + 1)
		s.mouse_entered.connect(_light.bind(i + 1))
		s.mouse_exited.connect(func(): _light(stars))
		s.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				pick(i + 1))
		_stars.append(s)
		row.add_child(s)
	col.add_child(row)
	_comment = LineEdit.new()
	_comment.placeholder_text = tr("Komen (tak wajib)")
	_comment.max_length = 300
	col.add_child(_comment)
	var btns := UI.hbox(10)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	var later := UI.button(tr("Nanti"), "", 130)
	later.pressed.connect(close)
	btns.add_child(later)
	_send = UI.button(tr("Hantar"), "Primary", 130)
	_send.disabled = true
	_send.pressed.connect(_submit)
	btns.add_child(_send)
	col.add_child(btns)
	_box.add_child(col)
	Sfx.play("pop", -8.0, 1.2)
	if centred:
		add_child(UI.center(_box))
		return
	# small, right under the HUD star: sized once its contents are measured
	_box.modulate.a = 0.0
	add_child(_box)
	await get_tree().process_frame
	if not is_instance_valid(_box):
		return
	_box.size = _box.get_combined_minimum_size()
	_box.position = Vector2(maxf(8.0, anchor.x - _box.size.x), anchor.y + 8)
	_box.modulate.a = 1.0


func pick(n: int) -> void:
	stars = clampi(n, 1, 5)
	_light(stars)
	_send.disabled = false
	Sfx.play("select", -8.0, 0.9 + 0.08 * stars)


func _light(n: int) -> void:
	for i in _stars.size():
		_stars[i].on = i < n
		_stars[i].queue_redraw()


func _submit() -> void:
	if stars < 1:
		return
	Backend.send_rating(stars, _comment.text.strip_edges(), context)
	Game.save["rated"] = stars
	Game.persist()
	Game.main.toast(tr("Terima kasih!"))
	close()


func close() -> void:
	if is_queued_for_deletion():
		return
	Game.unlock_input()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		close()
		get_viewport().set_input_as_handled()


## a five-pointed star, gold when on
class Star extends Control:
	var on := false

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.48
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI / 2.0 + i * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.42))
		draw_colored_polygon(pts, Color("f0c24a") if on else Color(0.62, 0.56, 0.46))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.33, 0.2, 0.1), 2.0)
