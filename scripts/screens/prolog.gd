extends Control
## Prolog (3-5 min): Alif's room -> waking in Dunia Explo-Story -> Bendera 1.

const UI = preload("res://scripts/ui/ui.gd")
const PARAGRAPH := "Negara bangsa ialah sebuah negara yang berdaulat dan didiami oleh satu bangsa. Kerajaan Alam Melayu seperti Funan, Champa dan Srivijaya mempunyai ciri-ciri negara bangsa: raja, undang-undang, wilayah pengaruh dan rakyat."

var params: Dictionary = {}
var _bg: TextureRect
var _stage: Control
var _fade: ColorRect
var _read_panel: PanelContainer
var _para: Label
var _scramble: float = 0.0
var _scr_t: float = 0.0
var _taps: int = 0
var _waiting: String = ""
var _pau_desk: TextureRect
var _vignette: ColorRect
var _skip: Button

signal step_done


func _ready() -> void:
	UI.full(self)
	Game.main.set_pau_visible(false)
	_bg = UI.bg_image("res://assets/bg/bilik_alif.png")
	add_child(_bg)
	_stage = Control.new()
	UI.full(_stage)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_vignette = ColorRect.new()
	_vignette.color = Color(0.6, 0.05, 0.08, 0.0)
	UI.full(_vignette)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	UI.full(_fade)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_skip = UI.button("Langkau »", "", 0)
	_skip.position = Vector2(1280 - 180, 16)
	_skip.pressed.connect(_finish)
	add_child(_skip)
	_run()


func _sprite(sheet: String, col: int, row: int, pos: Vector2, sc: float, w: int = 16, h: int = 24) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UI.sheet_frame(sheet, col, row, w, h)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = Vector2(w, h) * sc
	r.position = pos - Vector2(w * sc / 2.0, h * sc)
	r.pivot_offset = Vector2(w * sc / 2.0, h * sc)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(r)
	return r


func _fade_to(a: float, t: float = 0.6) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", a, t)
	await tw.finished


func _caption(text: String, seconds: float) -> void:
	var l := UI.label(text, "Title")
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", UI.CREAM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, 320)
	l.size = Vector2(1280, 80)
	l.z_index = 10
	add_child(l)
	l.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.5)
	tw.tween_interval(seconds)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	await tw.finished
	l.queue_free()


func _wait_for(what: String) -> void:
	_waiting = what
	await step_done
	_waiting = ""


# ------------------------------------------------------------------ script
func _run() -> void:
	# ---- Babak 1: Bilik Alif
	var cal := UI.panel()
	cal.add_theme_stylebox_override("panel", UI.sb(Color(1, 1, 1, 0.0), Color(0, 0, 0, 0), 0, 0, 0))
	var cl := UI.label("SPM SEJARAH:\n3 HARI LAGI", "Bad")
	cl.add_theme_font_size_override("font_size", 15)
	cl.add_theme_color_override("font_color", UI.RED)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cal.add_child(cl)
	cal.position = Vector2(516, 132)
	cal.size = Vector2(144, 90)
	_stage.add_child(cal)
	var alif := _sprite("res://assets/sprites/alif.png", 0, 3, Vector2(620, 560), 6)
	_pau_desk = _sprite("res://assets/sprites/pau.png", 0, 0, Vector2(800, 412), 3, 16, 16)
	await _fade_to(0.0, 1.0)
	await _caption("Malam. 3 hari sebelum SPM Sejarah.", 1.6)
	await Game.say("prolog_1a")
	_open_reading()
	await _wait_for("read")
	await Game.say("prolog_1b")
	# squeeze Pau
	var hint := UI.label("Ketik Pau di atas meja", "Heading")
	hint.position = Vector2(700, 330)
	add_child(hint)
	var tw := create_tween().set_loops()
	tw.tween_property(_pau_desk, "modulate", Color(1.6, 1.5, 0.8), 0.4)
	tw.tween_property(_pau_desk, "modulate", Color.WHITE, 0.4)
	await _wait_for("pau")
	tw.kill()
	hint.queue_free()
	_pau_desk.modulate = Color.WHITE
	var sq := create_tween()
	sq.tween_property(_pau_desk, "scale", Vector2(1.4, 0.6), 0.15)
	sq.tween_property(_pau_desk, "scale", Vector2(0.9, 1.15), 0.15)
	sq.tween_property(_pau_desk, "scale", Vector2.ONE, 0.15)
	await sq.finished
	await Game.say("prolog_1c")
	# heartbeat + clock
	for i in 3:
		var hb := create_tween()
		hb.tween_property(_vignette, "color:a", 0.35, 0.18)
		hb.tween_property(_vignette, "color:a", 0.05, 0.4)
		Game.main.shake(6.0 + i * 3.0, 0.3)
		var tick := UI.label("TIK... TOK..." if i % 2 == 0 else "DUP... DAP...", "Title")
		tick.add_theme_font_size_override("font_size", 36 + i * 18)
		tick.position = Vector2(820, 60 + i * 50)
		add_child(tick)
		var tt := create_tween()
		tt.tween_property(tick, "modulate:a", 0.0, 0.9)
		tt.tween_callback(tick.queue_free)
		await get_tree().create_timer(0.75).timeout
	var slump := create_tween()
	slump.tween_property(alif, "rotation", 0.25, 0.8)
	await _fade_to(1.0, 1.4)
	await _caption("Alif terlelap di atas buku teks...", 1.4)
	_vignette.color.a = 0.0
	for c in _stage.get_children():
		c.queue_free()

	# ---- Babak 2: Terjaga di Dunia Explo-Story
	_bg.texture = UI.tex("res://assets/bg/bukit_peta.png")
	var alif2 := _sprite("res://assets/sprites/alif.png", 0, 0, Vector2(520, 640), 5)
	await _fade_to(0.0, 1.2)
	var jump := create_tween()
	jump.tween_property(alif2, "position:y", alif2.position.y - 20, 0.12)
	jump.tween_property(alif2, "position:y", alif2.position.y, 0.12)
	await jump.finished
	var pau := _sprite("res://assets/sprites/pau.png", 3, 0, Vector2(540, 600), 4, 16, 16)
	var pj := create_tween()
	pj.tween_property(pau, "position", Vector2(600, 480), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pj.tween_property(pau, "position", Vector2(620, 576), 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await pj.finished
	await Game.say("prolog_2a")
	# picture signboard
	var sign := UI.panel("Paper")
	var srow := UI.hbox(26)
	for pair in [["mahkota", "Raja"], ["kumpulan", "Rakyat"], ["peta", "Wilayah"], ["timbangan", "Undang-undang"]]:
		var c := UI.vbox(4)
		c.add_child(UI.icon("res://assets/icons/%s.png" % pair[0], 88))
		var l := UI.label(pair[1], "Ink")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(l)
		srow.add_child(c)
	var sp := UI.icon_button("res://assets/icons/suara.png", "Blue", Vector2(64, 56))
	sp.pressed.connect(func(): Tts.speak("Raja. Rakyat. Wilayah. Undang-undang."))
	srow.add_child(sp)
	sign.add_child(srow)
	sign.position = Vector2(700, 380)
	sign.modulate.a = 0.0
	add_child(sign)
	create_tween().tween_property(sign, "modulate:a", 1.0, 0.5)
	await Game.say("prolog_2b")
	create_tween().tween_property(sign, "modulate:a", 0.0, 0.4)
	await Game.say("prolog_2c")
	sign.queue_free()

	# ---- Babak 3: Bendera pertama
	var glow := Control.new()
	glow.position = Vector2(400, 330)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.draw.connect(func():
		glow.draw_circle(Vector2.ZERO, 30, Color(1, 0.85, 0.3, 0.45))
		glow.draw_arc(Vector2.ZERO, 34, 0, TAU, 32, UI.GOLD, 4.0))
	_stage.add_child(glow)
	var gt := create_tween().set_loops()
	gt.tween_property(glow, "scale", Vector2(1.35, 1.35), 0.6)
	gt.tween_property(glow, "scale", Vector2.ONE, 0.6)
	await Game.say("prolog_3")
	gt.kill()
	_finish()


func _finish() -> void:
	if _skip.disabled:
		return
	_skip.disabled = true
	Game.save["prolog_done"] = true
	Game.persist()
	Game.goto("peta", {"first": true})


# ------------------------------------------------------------------ reading
func _open_reading() -> void:
	_read_panel = UI.panel("Paper")
	_read_panel.custom_minimum_size = Vector2(760, 0)
	_read_panel.position = Vector2(260, 120)
	var c := UI.vbox(10)
	c.add_child(UI.label("Buku Teks Sejarah Tingkatan 4 - Bab 1", "InkHeading"))
	_para = UI.label(PARAGRAPH, "Ink", true)
	_para.custom_minimum_size.x = 720
	c.add_child(_para)
	var hint := UI.label("Ketik perenggan untuk cuba membaca.", "InkSmall")
	c.add_child(hint)
	_read_panel.add_child(c)
	_read_panel.gui_input.connect(_on_read_tap)
	add_child(_read_panel)
	_scramble = 0.15


func _on_read_tap(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed) or _taps >= 3:
		return
	_taps += 1
	_scramble = 0.15 + 0.25 * _taps
	Game.main.shake(3.0, 0.2)
	if _taps >= 3:
		await get_tree().create_timer(0.8).timeout
		_read_panel.queue_free()
		_read_panel = null
		step_done.emit()


func _process(delta: float) -> void:
	if _read_panel == null or _para == null or not is_instance_valid(_para):
		return
	_scr_t += delta
	if _scr_t < 0.14:
		return
	_scr_t = 0.0
	var words := PARAGRAPH.split(" ")
	var out: PackedStringArray = []
	for w in words:
		if w.length() > 3 and randf() < _scramble:
			var chars: Array = []
			for ch in w:
				chars.append(ch)
			var i := randi_range(1, w.length() - 3)
			var tmp = chars[i]
			chars[i] = chars[i + 1]
			chars[i + 1] = tmp
			if randf() < _scramble * 0.5:
				var j := randi_range(1, w.length() - 2)
				chars[j] = {"b": "d", "d": "b", "p": "q", "q": "p", "n": "u", "u": "n", "m": "w"}.get(chars[j], chars[j])
			out.append("".join(PackedStringArray(chars)))
		else:
			out.append(w)
	_para.text = " ".join(out)
	_para.position.x = randf_range(-1.5, 1.5) * _scramble * 4.0


func _gui_input(event: InputEvent) -> void:
	if _waiting == "pau" and event is InputEventMouseButton and event.pressed:
		var r := Rect2(_pau_desk.position - Vector2(30, 30), _pau_desk.size + Vector2(60, 60))
		if r.has_point(event.position):
			step_done.emit()
