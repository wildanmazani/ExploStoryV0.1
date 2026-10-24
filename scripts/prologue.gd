extends Control
## Prologue (GDS section 2): a cutscene, nothing to press (lines move on by
## themselves, Langkau skips it all), told so players see their own nights:
##  1. cold open: the class group chat at 11:47 PM (scripts/ui/phone_chat.gd)
##  2. Alif's room: he looks at the calendar, his trial paper, Mak's message,
##     the window (Tok's stories) and Pau, each glowing in turn
##  3. reading: key words fly into "Ingatan Alif", but it only holds two and
##     the letters keep scrambling: "satu pun tak melekat" (dyslexia, and
##     anyone drowning in facts)
##  4. he dozes off; golden pages carry us into a dream: his classmates at an
##     old port forget each other in the Kabus Lupa, then Gua Warisan where
##     Nirbana breaks the Telaga Batu inscription into four Serpihan (the goal
##     of Bab 1). Then Dunia Explo-Story (world intro continues in world.gd).
## Text: data/prologue_room.json and data/dialogue/prologue.json.

const UI = preload("res://scripts/ui/ui.gd")
const PhoneChat = preload("res://scripts/ui/phone_chat.gd")
const WORLD := "res://scenes/world/world.tscn"
const DATA := "res://data/prologue_room.json"
const MIRROR := {"b": "d", "d": "b", "p": "q", "q": "p", "m": "w", "w": "m", "n": "u", "u": "n"}
const FRIENDS := ["aisyah", "ravi", "meiling", "daniel"]

var phase := ""  ## what is on screen: phone, room, reading, doze, port, gua

var _data: Dictionary
var _skipping := false
var _tick_gap := 1.0
var _ticking := false
var _heart_gap := 0.0  ## 0 = no heartbeat
var _tokens: Array = []  ## paragraph pieces {text, kw}
var _memory: Array = []  ## key words Alif still remembers (token index), oldest first
var _words_read := 0
var _amount := 0.0       ## how scrambled the page is, 0..1
var _jar: HBoxContainer

@onready var room: TextureRect = $Room
@onready var lamp: ColorRect = $LampGlow
@onready var vignette: TextureRect = $Vignette
@onready var caption: Label = $Caption
@onready var book: PanelContainer = $Book
@onready var book_text: RichTextLabel = $Book/Text
@onready var pau: TextureRect = $Pau
@onready var lid_top: ColorRect = $LidTop
@onready var lid_bottom: ColorRect = $LidBottom
@onready var pages: CPUParticles2D = $Pages
@onready var flash: ColorRect = $Flash
@onready var skip: Button = $SkipLayer/Skip


func _ready() -> void:
	Main.set_pau_visible(false)
	MusicDirector.play("bilik", 2.5)
	skip.pressed.connect(_skip)
	pages.texture = _page_texture()
	_data = Game.load_json(DATA)
	Main.dialog_box.auto_advance = true
	book.modulate.a = 0.0
	caption.modulate.a = 0.0
	_run()


# --- the sequence ---------------------------------------------------------
func _run() -> void:
	_lamp_loop()
	_desk_phone()
	await _phone_open()
	if _skipping: return
	_clock_loop()
	_heart_loop()
	caption.text = str(_data.get("caption", ""))
	await _fade(caption, 1.0, 1.0)
	await _wait(1.6)
	await _fade(caption, 0.0, 0.8)
	await _room_tour()
	await _reading()
	await _doze()
	await _dream()
	if _skipping: return
	await _fade(flash, 1.0, 0.8)
	_go_to_world()


## 11:47 PM, the class group chat: everyone is as lost as Alif
func _phone_open() -> void:
	phase = "phone"
	var chat := PhoneChat.new()
	add_child(chat)
	move_child(chat, flash.get_index())
	chat.setup(_data.get("chat", {}))
	await chat.done
	if _skipping: return
	var t := create_tween()
	t.tween_property(chat, "modulate:a", 0.0, 0.6)
	await t.finished
	chat.queue_free()


## the room picture has no phone: one lies on the desk, screen still glowing
func _desk_phone() -> void:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", UI.sb(Color("1b1d24"), Color("3a3d48"), 2, 4, 0))
	p.position = Vector2(318, 444)
	p.size = Vector2(54, 22)
	p.rotation = -0.08
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var screen := ColorRect.new()
	screen.color = Color("8fd8ff")
	screen.position = Vector2(5, 4)
	screen.size = Vector2(44, 14)
	p.add_child(screen)
	add_child(p)
	move_child(p, vignette.get_index())
	var t := screen.create_tween().set_loops()
	t.tween_property(screen, "modulate:a", 0.45, 1.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(screen, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)


## Alif looks around his room: each thing glows while he talks about it
func _room_tour() -> void:
	if _skipping: return
	phase = "room"
	await _say("pro_room")
	for s in _data.get("room", []):
		if _skipping: return
		var glow := _glow(s)
		await _wait(0.6)
		_spot_fx(str(s["id"]))
		await _say(str(s.get("say", "")))
		if _skipping: return
		var t := create_tween()
		t.tween_property(glow, "modulate:a", 0.0, 0.3)
		t.tween_callback(glow.queue_free)
		await _wait(0.4)


## a soft gold outline (and its name) around the thing Alif is looking at
func _glow(s: Dictionary) -> Control:
	var r: Array = s["rect"]
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", UI.sb(Color(UI.GOLD, 0.12), UI.GOLD, 4, 14, 0))
	p.position = Vector2(r[0], r[1])
	p.size = Vector2(r[2], r[3])
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag := UI.label(str(s.get("label", "")))
	tag.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.15))
	tag.add_theme_constant_override("outline_size", 8)
	tag.position = Vector2(4, -36)
	p.add_child(tag)
	add_child(p)
	move_child(p, flash.get_index())
	p.modulate.a = 0.0
	create_tween().tween_property(p, "modulate:a", 1.0, 0.3)
	var pulse := p.create_tween().set_loops()
	pulse.tween_property(p, "self_modulate:a", 0.5, 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(p, "self_modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	return p


func _spot_fx(id: String) -> void:
	match id:
		"pau":
			_squish_pau()
		"kalendar":
			_heart_gap = 1.4  # and it stays with him
			Sfx.play("heartbeat", -2.0)
		"telefon":
			Sfx.play("pop", -4.0)
		_:
			Sfx.play("select", -6.0)


## Reading: key words fly into Alif's memory, but it only holds two and the
## page keeps scrambling, so they fall out again as fast as they go in
func _reading() -> void:
	if _skipping: return
	phase = "reading"
	_tokens = _parse(str(_data.get("paragraph", "")))
	_render_book()
	var jar := _build_jar()
	await _fade(book, 1.0, 0.8)
	await _say("pro_read")
	_tick_gap = 0.7
	_heart_gap = 1.1
	var keys: Array = []
	for i in _tokens.size():
		if _tokens[i]["kw"]:
			keys.append(i)
	var words := mini(int(_data.get("read_words", 6)), keys.size())
	var every := float(_data.get("word_every", 1.3))
	var thoughts: Dictionary = _data.get("thoughts", {})
	for n in words:
		if _skipping: return
		_remember(keys[n])
		for k in 4:  # the letters keep moving while he reads
			_amount = minf(1.0, 0.1 + n * 0.12 + k * 0.03)
			_render_book()
			await _wait(every / 4.0)
		if thoughts.has(str(n + 1)):
			await _say(str(thoughts[str(n + 1)]))
	if _skipping: return

	# everything slides off the page
	while not _memory.is_empty():
		_forget(_memory.pop_front())
	_amount = 1.0
	_render_book()
	_tick_gap = 0.45
	_heart_gap = 0.7
	_shake_room(true)
	await _say("pro_scramble")
	_shake_room(false)
	_fade(jar, 0.0, 0.6)
	await _fade(book, 0.0, 0.6)
	jar.queue_free()


func _parse(p: String) -> Array:
	var out := []
	var re := RegEx.new()
	re.compile("\\{([^}]*)\\}")
	var at := 0
	for m in re.search_all(p):
		if m.get_start() > at:
			out.append({"text": p.substr(at, m.get_start() - at), "kw": false})
		out.append({"text": m.get_string(1), "kw": true})
		at = m.get_end()
	if at < p.length():
		out.append({"text": p.substr(at), "kw": false})
	return out


func _render_book() -> void:
	var out := ""
	for i in _tokens.size():
		var tk: Dictionary = _tokens[i]
		if not tk["kw"]:
			out += _scramble(tk["text"], _amount * 0.6)
		elif _memory.has(i):
			out += "[color=#c9a040]%s[/color]" % tk["text"]
		else:
			out += "[u][color=#a0521d]%s[/color][/u]" % _scramble(tk["text"], _amount * 0.4)
	book_text.text = "[shake rate=%d level=%d]%s[/shake]" % [10 + int(_amount * 16), int(_amount * 8), out]


func _build_jar() -> PanelContainer:
	var p := UI.panel("Paper")
	p.position = Vector2(200, 430)
	p.size = Vector2(880, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_jar = UI.hbox(10)
	_jar.add_child(UI.label("Ingatan Alif:", "InkHeading"))
	p.add_child(_jar)
	add_child(p)
	move_child(p, flash.get_index())
	p.modulate.a = 0.0
	_fade(p, 1.0, 0.8)
	return p


## the word flies from the page into Alif's memory
func _remember(i: int) -> void:
	_words_read += 1
	_memory.append(i)
	Sfx.play("chime", -8.0, 1.0 + _memory.size() * 0.1)
	var word := str(_tokens[i]["text"])
	var chip := UI.panel()
	chip.add_theme_stylebox_override("panel", UI.sb(Color("fff1c4"), UI.GOLD, 2, 8, 6))
	chip.set_meta("word", i)
	chip.add_child(UI.label(word, "Ink"))
	chip.modulate.a = 0.0
	_jar.add_child(chip)
	var ghost := UI.label(word, "Title")
	ghost.position = book.global_position + Vector2(randf_range(60, book.size.x - 220), randf_range(40, book.size.y - 80))
	add_child(ghost)
	var t := create_tween()
	t.tween_property(ghost, "position", _jar.global_position + Vector2(180 + _jar.get_child_count() * 60, 0), 0.4).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(ghost, "modulate:a", 0.0, 0.4)
	t.tween_callback(ghost.queue_free)
	t.tween_property(chip, "modulate:a", 1.0, 0.2)
	if _memory.size() > int(_data.get("memory_size", 2)):
		_forget(_memory.pop_front())


## ...and the oldest one falls out again
func _forget(i: int) -> void:
	for chip in _jar.get_children():
		if chip.has_meta("word") and int(chip.get_meta("word")) == i:
			chip.reparent(self)
			var t := create_tween().set_parallel()
			t.tween_property(chip, "position:y", chip.position.y + 90, 0.7).set_ease(Tween.EASE_IN)
			t.tween_property(chip, "rotation", randf_range(-0.6, 0.6), 0.7)
			t.tween_property(chip, "modulate:a", 0.0, 0.7)
			t.chain().tween_callback(chip.queue_free)
			Sfx.play("swish", -6.0)
			return


## Alif gives up, squeezes Pau and dozes off; golden pages carry him away
func _doze() -> void:
	if _skipping: return
	phase = "doze"
	for i in 2:
		_squish_pau(1.0 + i * 0.1)
		await _wait(0.5)
	_tick_gap = 0.9
	_heart_gap = 1.4
	await _say("pro_pau")

	# drowsy: the clock slows, eyelids close... silence
	_tick_gap = 1.6
	_heart_gap = 0.0
	await _blink(0.55, 0.7)
	await _blink(0.85, 1.0)
	_ticking = false
	await _lids(1.0, 1.4)
	await _wait(1.2)

	if _skipping: return
	MusicDirector.stop(2.0)
	Sfx.play("whoosh")
	Sfx.play("chime", -2.0)
	pages.emitting = true
	var t2 := create_tween()
	t2.tween_property(lid_top, "color", Color(1, 0.93, 0.7), 1.2)
	t2.parallel().tween_property(lid_bottom, "color", Color(1, 0.93, 0.7), 1.2)
	await _wait(1.6)
	Sfx.play("sparkle")
	await _fade(flash, 1.0, 0.8)


func _squish_pau(pitch := 1.0) -> void:
	Sfx.play("squish", -4.0, pitch)
	var t := create_tween()
	t.tween_property(pau, "scale", Vector2(1.25, 0.75), 0.12)
	t.tween_property(pau, "scale", Vector2(1, 1), 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## The dream: his classmates at an old port forget each other in the Kabus
## Lupa, then the cave, Nirbana and the four Serpihan.
func _dream() -> void:
	if _skipping: return
	phase = "port"
	var bg := _scene_image("res://assets/backgrounds/bg_pelabuhan_huru.png")
	bg.modulate = Color(1.0, 0.75, 0.7)
	var alif := _sprite("res://assets/characters32/%s/%s_south.png" % [Game.skin_folder(), Game.skin_folder()], Vector2(640, 610), 6)
	var feet := [Vector2(250, 560), Vector2(430, 650), Vector2(850, 650), Vector2(1030, 560)]
	var pals: Array[TextureRect] = []
	for i in FRIENDS.size():
		pals.append(_sprite(_rakan(FRIENDS[i], "south"), feet[i], 5))
	MusicDirector.play("siguntang", 1.0)
	flash.color = Color(1, 1, 1)
	await _fade(flash, 0.0, 0.8)
	room.position = Vector2.ZERO
	await _say("pro_friends_1")
	if _skipping: return

	# the Kabus Lupa rolls in: they turn away from him...
	var fog := ColorRect.new()
	fog.color = Color(0.35, 0.15, 0.5, 0.0)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.size = Vector2(1280, 720)
	add_child(fog)
	move_child(fog, bg.get_index() + 1)
	Sfx.play("whoosh", -4.0, 0.7)
	var k := create_tween().set_parallel()
	k.tween_property(fog, "color:a", 0.4, 1.4)
	for i in pals.size():
		k.tween_property(pals[i], "modulate", Color(0.8, 0.65, 1.0), 1.4)
		pals[i].texture = UI.tex(_rakan(FRIENDS[i], "north"))
	await k.finished
	await _say("pro_friends_2")
	if _skipping: return
	# ...then on each other
	var faces := ["east", "west", "east", "west"]
	for i in pals.size():
		pals[i].texture = UI.tex(_rakan(FRIENDS[i], faces[i]))
		_hop(pals[i])
	Sfx.play("bump", -4.0)
	await _say("pro_friends_3")
	if _skipping: return
	_shake_node(bg, 1.6)
	Sfx.play("bump", -2.0)
	await _say("pro_huru")
	if _skipping: return

	# run into the cave
	var run := create_tween()
	run.tween_property(alif, "position:x", 1300.0, 0.7).set_ease(Tween.EASE_IN)
	Sfx.play("whoosh")
	flash.color = Color.BLACK
	await _fade(flash, 1.0, 0.6)
	if run.is_running():
		await run.finished
	phase = "gua"
	for p in pals:
		p.queue_free()
	fog.queue_free()
	bg.texture = UI.tex("res://assets/backgrounds/bg_gua_warisan.png")
	bg.modulate = Color.WHITE
	alif.position = Vector2(300 - alif.size.x / 2.0, 640 - alif.size.y)
	alif.texture = UI.tex("res://assets/characters32/%s/%s_east.png" % [Game.skin_folder(), Game.skin_folder()])
	await _fade(flash, 0.0, 0.8)
	await _say("pro_gua_1")
	if _skipping: return
	# Nirbana gathers out of the mist
	var nir := _sprite("res://assets/characters32/nirbana/nirbana_south.png", Vector2(900, 640), 7)
	nir.modulate = Color(0.6, 0.4, 0.9, 0.0)
	Sfx.play("whoosh", -4.0, 0.6)
	var t := create_tween()
	t.tween_property(nir, "modulate", Color.WHITE, 1.2)
	await t.finished
	var bob := create_tween().set_loops()
	bob.tween_property(nir, "position:y", nir.position.y - 8, 1.0).set_trans(Tween.TRANS_SINE)
	bob.tween_property(nir, "position:y", nir.position.y, 1.0).set_trans(Tween.TRANS_SINE)
	await _say("pro_gua_2")
	if _skipping: return
	# the inscription cracks into four shards that fly out of the cave
	Sfx.play("bump", 0.0, 0.6)
	_shake_node(bg, 0.6)
	flash.color = Color(1, 1, 1)
	flash.modulate.a = 0.0
	var f := create_tween()
	f.tween_property(flash, "modulate:a", 0.8, 0.08)
	f.tween_property(flash, "modulate:a", 0.0, 0.4)
	await _shards()
	await _say("pro_gua_3")
	bob.kill()


func _rakan(who: String, facing: String) -> String:
	return "res://assets/characters32/rakan_%s/rakan_%s_%s.png" % [who, who, facing]


func _hop(n: Control) -> void:
	var t := create_tween()
	t.tween_property(n, "position:y", n.position.y - 12, 0.1)
	t.tween_property(n, "position:y", n.position.y, 0.15)


func _scene_image(path: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UI.tex(path)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = Vector2(1280, 720)
	add_child(r)
	move_child(r, flash.get_index())
	return r


## a character sprite standing with its feet at `feet`, `sc` times bigger
func _sprite(path: String, feet: Vector2, sc: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = UI.tex(path)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = r.texture.get_size() * sc
	r.position = feet - Vector2(r.size.x / 2.0, r.size.y)
	add_child(r)
	move_child(r, flash.get_index())
	return r


func _shards() -> void:
	var centre := Vector2(640, 330)
	var targets := [Vector2(-100, 100), Vector2(1380, 120), Vector2(-100, 640), Vector2(1380, 660)]
	var last: Tween
	for i in 4:
		var s := ColorRect.new()
		s.color = Color(1, 0.86, 0.4)
		s.size = Vector2(22, 30)
		s.position = centre
		s.rotation = randf_range(-0.6, 0.6)
		add_child(s)
		move_child(s, flash.get_index())
		last = create_tween()
		last.tween_property(s, "position", centre + Vector2(randf_range(-60, 60), randf_range(-60, 20)), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		last.tween_property(s, "position", targets[i], 0.8).set_ease(Tween.EASE_IN)
		Sfx.play("sparkle", -6.0, 1.0 + i * 0.15)
		await _wait(0.15)
	if last:
		await last.finished


func _shake_node(n: Control, seconds: float) -> void:
	var t := 0.0
	while t < seconds and not _skipping and is_inside_tree():
		n.position = Vector2(randf_range(-5, 5), randf_range(-5, 5))
		await get_tree().create_timer(0.04).timeout
		t += 0.04
	n.position = Vector2.ZERO


# --- helpers ----------------------------------------------------------------
func _say(id: String) -> void:
	if _skipping: return
	await Game.say(Dialogue.lines(id))


func _wait(seconds: float) -> void:
	if _skipping: return
	await get_tree().create_timer(seconds).timeout


func _fade(node: CanvasItem, alpha: float, seconds: float) -> void:
	if _skipping: return
	var t := create_tween()
	t.tween_property(node, "modulate:a", alpha, seconds)
	await t.finished


func _show_caption(text: String) -> void:
	caption.text = text
	caption.modulate.a = 0.0
	_fade(caption, 1.0, 0.5)


func _clock_loop() -> void:
	_ticking = true
	var tock := false
	while _ticking and not _skipping:
		Sfx.play("tock" if tock else "tick", -6.0)
		tock = not tock
		await get_tree().create_timer(_tick_gap).timeout


func _heart_loop() -> void:
	while not _skipping and is_inside_tree():
		if _heart_gap > 0.0:
			Sfx.play("heartbeat", -3.0)
			var t := create_tween()
			t.tween_property(vignette, "modulate:a", 1.0, 0.08)
			t.tween_property(vignette, "modulate:a", 0.55, 0.4)
			await get_tree().create_timer(_heart_gap).timeout
		else:
			await get_tree().create_timer(0.2).timeout


func _lamp_loop() -> void:
	while not _skipping and is_inside_tree():
		lamp.modulate.a = randf_range(0.85, 1.0)
		await get_tree().create_timer(randf_range(0.05, 0.25)).timeout


var _shaking := false
func _shake_room(on: bool) -> void:
	_shaking = on
	while _shaking and not _skipping and is_inside_tree():
		room.position = Vector2(randf_range(-3, 3), randf_range(-3, 3))
		await get_tree().create_timer(0.04).timeout
	room.position = Vector2.ZERO


func _blink(close_to: float, seconds: float) -> void:
	await _lids(close_to, seconds)
	await _lids(0.25, seconds * 0.6)


## 0 = eyes open, 1 = fully closed
func _lids(closed: float, seconds: float) -> void:
	if _skipping: return
	var h := 360.0 * closed
	var t := create_tween().set_parallel()
	t.tween_property(lid_top, "size:y", h, seconds).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(lid_bottom, "position:y", 720.0 - h, seconds).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(lid_bottom, "size:y", h, seconds).set_ease(Tween.EASE_IN_OUT)
	await t.finished


## dyslexia-style scramble: mirrored letters and shuffled word middles
func _scramble(text: String, amount: float) -> String:
	var words := text.split(" ")
	for i in words.size():
		if randf() > amount:
			continue
		var w: String = words[i]
		var chars := w.split("")
		for c in chars.size():
			if MIRROR.has(chars[c]) and randf() < 0.6:
				chars[c] = MIRROR[chars[c]]
		if chars.size() > 3:
			var a := randi_range(1, chars.size() - 2)
			var b := randi_range(1, chars.size() - 2)
			var tmp := chars[a]
			chars[a] = chars[b]
			chars[b] = tmp
		words[i] = "".join(chars)
	return " ".join(words)


func _page_texture() -> Texture2D:
	var img := Image.create(6, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0.96, 0.82))
	for x in 6:
		img.set_pixel(x, 0, Color(0.85, 0.75, 0.5))
	for y in [3, 5]:
		for x in range(1, 5):
			img.set_pixel(x, y, Color(0.7, 0.6, 0.45))
	return ImageTexture.create_from_image(img)


func _skip() -> void:
	if _skipping:
		return
	_skipping = true
	Sfx.play("select")
	Main.dialog_box.cancel()
	_go_to_world()


var _leaving := false
func _go_to_world() -> void:
	if _leaving:
		return
	_leaving = true
	Main.dialog_box.auto_advance = false  # world.gd turns it on again for the wake-up
	Game.save["prolog_done"] = true
	Game.persist()
	GameState.flags["world_intro"] = true
	GameState.go_to(WORLD, Color(1, 0.97, 0.88))
