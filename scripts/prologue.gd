extends Control
## Prologue (GDS section 2): a cutscene, nothing to press (lines move on by
## themselves, Langkau skips it all), told so players see their own nights:
##  1. cold open: the class group chat at 11:47 PM (scripts/ui/phone_chat.gd)
##  2. through Alif's eyes, sitting at his desk: he looks at the calendar, his
##     notes, Mak's message, the window (Tok's stories) and Pau, the bun Mak
##     left him on a plate (it only comes alive in the dream), each glowing in turn
##  3. he looks down at the textbook and his eyes read along the lines, in
##     quick jumps with blinks: key words fly into "Ingatan Alif", but it only holds two and
##     the letters keep scrambling: "satu pun tak melekat" (dyslexia, and
##     anyone drowning in facts)
##  4. he dozes off; golden pages carry us into a dream: his classmates at an
##     old port forget each other in the Kabus Lupa, then Gua Warisan where
##     Nirbana breaks the Telaga Batu inscription into four Serpihan (the goal
##     of Bab 1). Then Alif wakes up in his room in Dunia Explo-Story, where
##     Pau explains everything (scripts/world/bilik_alif.gd).
## Text: data/prologue_room.json and data/dialogue/prologue.json.

const UI = preload("res://scripts/ui/ui.gd")
const PhoneChat = preload("res://scripts/ui/phone_chat.gd")
const BILIK := "res://scenes/interior/bilik_alif.tscn"
const DATA := "res://data/prologue_room.json"
## first person, on the chair: looking across the desk, and down at the open
## book. Both 16:9; the glow rects in prologue_room.json fit the first one.
const VIEW_DESK := "res://assets/backgrounds/bg_meja_pov.png"
const VIEW_BOOK := "res://assets/backgrounds/bg_meja_buku.png"
const PAU_FOOD := "res://assets/ui/pau_piring.png"  ## his favourite, on a plate from Mak
const SCREEN := Vector2(1280, 720)
const PAU_ON_DESK := Rect2(104, 504, 128, 128)
const PAU_BY_BOOK := Rect2(74, 356, 150, 150)
const PAGE_LEFT := Rect2(392, 240, 216, 280)   ## the flat part of the page the paragraph is on
const PAGE_RIGHT := Rect2(660, 240, 216, 280)
const READ_ZOOM := 1.35
const READ_CENTER := Vector2(500, 420)  ## the whole page stays between the memory bar and the dialogue box
const GAZE_MOVE := 0.18  ## how far the view follows the eyes while reading
const LINE_H := 24.0
const MIRROR := {"b": "d", "d": "b", "p": "q", "q": "p", "m": "w", "w": "m", "n": "u", "u": "n"}
const FRIENDS := ["aisyah", "ravi", "meiling", "daniel"]
## the dream: where each friend is stuck, on the verandah of a different
## stilt house in bg_pelabuhan_huru: [feet, left end, right end] of the floor
const HOUSES := [
	[Vector2(110, 462), 76.0, 166.0],
	[Vector2(462, 468), 432.0, 494.0],
	[Vector2(948, 408), 930.0, 964.0],
	[Vector2(1078, 410), 1050.0, 1102.0],
]
var _pacing := false  ## the friends walk their verandahs looking for a way out

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
var _cam := SCREEN / 2.0  ## the point of the picture Alif looks at
var _zoom := 1.08
var _micro := Vector2.ZERO  ## tiny eye jumps while he looks at one thing
var _shake := Vector2.ZERO
var _sway := 0.0
var _eyes_on := false       ## the eye loops run (blinks, small jumps)
var _reading_eyes := false  ## his gaze follows the lines

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
	Game.lock_16_9(true)
	tree_exited.connect(func(): Game.lock_16_9(false))
	Main.set_pau_visible(false)
	room.texture = load(VIEW_DESK)
	room.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	room.stretch_mode = TextureRect.STRETCH_SCALE
	room.position = Vector2.ZERO
	room.size = SCREEN
	pau.reparent(room, false)  # part of the desk: it moves with the view
	pau.texture = load(PAU_FOOD)
	pau.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pau.modulate = Color(0.9, 0.82, 0.72)  # lit like the rest of the desk
	_place_pau(PAU_ON_DESK)
	book.reparent(room, false)
	book.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	book.position = PAGE_LEFT.position
	book.size = PAGE_LEFT.size
	book_text.add_theme_font_size_override("normal_font_size", 16)
	book_text.add_theme_constant_override("line_separation", 6)
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
	await _phone_open()
	if _skipping: return
	_clock_loop()
	_heart_loop()
	_eyes_on = true
	_blink_loop()
	_micro_loop()
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


# --- Alif's eyes ---------------------------------------------------------------
func _place_pau(r: Rect2) -> void:
	pau.position = r.position
	pau.size = r.size
	pau.pivot_offset = Vector2(r.size.x / 2.0, r.size.y)


## the picture moves under the eyes: never past its edges
func _process(delta: float) -> void:
	_sway += delta
	var z := maxf(_zoom, 1.02)
	var half := SCREEN / (2.0 * z)
	var look := _cam + _micro + Vector2(sin(_sway * 0.7) * 3.0, sin(_sway * 0.43) * 2.0)  # breathing
	look.x = clampf(look.x, half.x, SCREEN.x - half.x)
	look.y = clampf(look.y, half.y, SCREEN.y - half.y)
	room.scale = Vector2(z, z)
	room.position = SCREEN / 2.0 - look * z + _shake


## eyes first, in one quick jump; the head comes after and settles
func _look(at: Vector2, zoom: float, head := 0.7) -> void:
	if _skipping: return
	var t := create_tween()
	t.tween_property(self, "_cam", _cam.lerp(at, 0.8), 0.1).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "_cam", at, head).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "_zoom", zoom, head).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


## a person blinks every few seconds: down fast, up a little slower
func _blink_loop() -> void:
	while _eyes_on and not _skipping and is_inside_tree():
		await get_tree().create_timer(randf_range(2.2, 5.0)).timeout
		if _eyes_on and not _skipping:
			await _lids(1.0, 0.06)
			await _lids(0.0, 0.11)


## even staring at one spot, the eyes make small jumps
func _micro_loop() -> void:
	while _eyes_on and not _skipping and is_inside_tree():
		await get_tree().create_timer(randf_range(0.35, 1.1)).timeout
		if not _reading_eyes:
			var t := create_tween()
			t.tween_property(self, "_micro", Vector2(randf_range(-9, 9), randf_range(-6, 6)), 0.05)


## reading: stops along a line in quick jumps, now and then back a word, then
## the long jump to the start of the next line
func _read_eyes() -> void:
	_reading_eyes = true
	_micro = Vector2.ZERO
	var line := 0
	var lines := int(PAGE_LEFT.size.y / LINE_H) - 1
	while _reading_eyes and not _skipping and is_inside_tree():
		var y := PAGE_LEFT.position.y + LINE_H * (line + 0.5)
		var x := PAGE_LEFT.position.x + 20.0
		while x < PAGE_LEFT.end.x - 20.0 and _reading_eyes:
			await _eye_jump(Vector2(x, y), 0.04)
			await _wait(randf_range(0.18, 0.34) + _amount * 0.2)
			if _amount > 0.2 and randf() < 0.3:  # lost the word: back again
				x -= 30.0
				await _eye_jump(Vector2(x, y), 0.04)
				await _wait(randf_range(0.2, 0.4))
			x += randf_range(30.0, 50.0)
		line = (line + 1) % lines
		await _eye_jump(Vector2(PAGE_LEFT.position.x + 20.0, y + LINE_H), 0.1)


func _eye_jump(at: Vector2, seconds: float) -> void:
	if _skipping: return
	var t := create_tween()
	t.tween_property(self, "_cam", READ_CENTER + (at - PAGE_LEFT.get_center()) * GAZE_MOVE, seconds).set_ease(Tween.EASE_OUT)
	await t.finished


## Alif looks around from his chair: each thing glows while he talks about it
func _room_tour() -> void:
	if _skipping: return
	phase = "room"
	await _say("pro_room")
	for s in _data.get("room", []):
		if _skipping: return
		var r: Array = s["rect"]
		await _look(Vector2(r[0] + r[2] / 2.0, r[1] + r[3] / 2.0), float(s.get("zoom", 1.5)))
		var glow := _glow(s)
		await _wait(0.5)
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
	room.add_child(p)  # stays on the thing as the eyes move
	p.modulate.a = 0.0
	create_tween().tween_property(p, "modulate:a", 1.0, 0.3)
	var pulse := p.create_tween().set_loops()
	pulse.tween_property(p, "self_modulate:a", 0.5, 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(p, "self_modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	return p


func _spot_fx(id: String) -> void:
	match id:
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
	# he looks down, a blink, and the page fills his view
	await _look(Vector2(655, 575), 1.7, 0.6)
	await _lids(1.0, 0.1)
	room.texture = load(VIEW_BOOK)
	_place_pau(PAU_BY_BOOK)
	_zoom = 1.25
	_cam = Vector2(640, 380)
	_page_lines()
	book.modulate.a = 1.0
	await _lids(0.0, 0.2)
	await _wait(0.9)  # the whole desk: book, notes, Pau
	await _look(READ_CENTER, READ_ZOOM, 0.9)
	var jar := _build_jar()
	_read_eyes()
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
	_reading_eyes = false
	await _fade(jar, 0.0, 0.6)
	jar.queue_free()


## the facing page: the rest of the text, too small to read from here
func _page_lines() -> void:
	var lines := Control.new()
	lines.position = PAGE_RIGHT.position
	lines.size = PAGE_RIGHT.size
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.draw.connect(func():
		seed(7)
		for i in 10:
			var w := randf_range(0.8, 1.0) * lines.size.x
			lines.draw_rect(Rect2(0, i * LINE_H + 8, w, 5), Color(0.3, 0.22, 0.14, 0.45))
		randomize())
	room.add_child(lines)


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
	p.position = Vector2(40, 20)
	p.size = Vector2(980, 0)
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


## Alif gives up, looks over at his pau and dozes off; golden pages carry him away
func _doze() -> void:
	if _skipping: return
	phase = "doze"
	await _look(PAU_BY_BOOK.get_center() + Vector2(90, 0), 1.6)  # the pau he has not eaten yet
	await _wait(0.9)
	_tick_gap = 0.9
	_heart_gap = 1.4
	await _say("pro_pau")

	# drowsy: the clock slows, eyelids close... silence
	_tick_gap = 1.6
	_heart_gap = 0.0
	_eyes_on = false
	create_tween().tween_property(self, "_cam:y", _cam.y + 60.0, 4.0).set_trans(Tween.TRANS_SINE)  # the head nods down
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


## The dream: his classmates at an old port forget each other in the Kabus
## Lupa, then the cave, Nirbana and the four Serpihan.
func _dream() -> void:
	if _skipping: return
	phase = "port"
	var bg := _scene_image("res://assets/backgrounds/bg_pelabuhan_huru.png")
	bg.modulate = Color(1.0, 0.75, 0.7)
	# Alif among the reeds on the shore, his back to us, looking out at the stilt houses
	var me := Game.skin_folder()
	var alif := _sprite("res://assets/characters32/%s/%s_north.png" % [me, me], Vector2(300, 728), 5)
	# each friend stuck on the verandah of a different house over the water
	var pals: Array[TextureRect] = []
	for i in FRIENDS.size():
		var at: Vector2 = HOUSES[i][0]
		pals.append(_sprite(_rakan(FRIENDS[i], "south"), at, 2))
	MusicDirector.play("siguntang", 1.0)
	flash.color = Color(1, 1, 1)
	_pacing = true
	for i in pals.size():
		_pace(pals[i], FRIENDS[i], HOUSES[i][1], HOUSES[i][2], i * 0.6)
	await _fade(flash, 0.0, 0.8)
	for i in pals.size():
		_emote(pals[i], "?", Color.WHITE)
		await _wait(0.25)
	_step_up(alif)
	await _say("pro_friends_1")
	if _skipping: return

	# the Kabus Lupa rolls in: they stop, see each other across the water...
	_pacing = false
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
	await k.finished
	# ...and turn on one another: Aisyah and Ravi on the left, Mei Ling and Daniel on the right
	var faces := ["east", "west", "east", "west"]
	for i in pals.size():
		pals[i].texture = UI.tex(_rakan(FRIENDS[i], faces[i]))
		_emote(pals[i], "!", Color("ff6a5a"))
		_hop(pals[i])
		await _wait(0.15)
	await _say("pro_friends_2")
	if _skipping: return
	for i in [0, 1]:
		_shove(pals[i], 1 if faces[i] == "east" else -1)
		_anger(pals[i])
	Sfx.play("bump", -4.0)
	for i in [2, 3]:
		_shove(pals[i], 1 if faces[i] == "east" else -1)
		_anger(pals[i])
	await _say("pro_friends_3")
	if _skipping: return
	# one by one they go inside and slam the door
	for i in [3, 0, 2, 1]:
		pals[i].texture = UI.tex(_rakan(FRIENDS[i], "north"))
		await _wait(0.2)
		var go := create_tween()
		go.tween_property(pals[i], "modulate:a", 0.0, 0.18)
		Sfx.play("bump", -3.0, 0.8)
		_shake_node(bg, 0.15)
		await _wait(0.35)
	_shake_node(bg, 1.6)
	Sfx.play("bump", -2.0)
	alif.texture = UI.tex("res://assets/characters32/%s/%s_south.png" % [me, me])
	_hop(alif)
	await _say("pro_huru")
	if _skipping: return

	# run into the cave: he turns and runs off, a hop on every stride
	alif.texture = UI.tex("res://assets/characters32/%s/%s_east.png" % [me, me])
	var run := create_tween()
	run.tween_property(alif, "position:x", 1300.0, 0.9).set_ease(Tween.EASE_IN)
	var stride := create_tween().set_loops(5)
	stride.tween_property(alif, "position:y", alif.position.y - 14, 0.09)
	stride.tween_property(alif, "position:y", alif.position.y, 0.09)
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
	var nir := _sprite("res://assets/characters32/nirbana/nirbana_south.png", Vector2(900, 640), 8)
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


## a friend walks up and down the verandah, stops at each end to look out
## (south) for a way off the house, then walks back; small steps bob
func _pace(n: TextureRect, who: String, left: float, right: float, delay: float) -> void:
	await _wait(delay)
	var home_y := n.position.y
	var going_right := randf() < 0.5
	while _pacing and is_inside_tree() and not _skipping:
		var to := (right if going_right else left) - n.size.x / 2.0
		n.texture = UI.tex(_rakan(who, "east" if going_right else "west"))
		var secs := absf(to - n.position.x) / 38.0 + 0.1
		var walk := create_tween()
		walk.tween_property(n, "position:x", to, secs)
		var steps := int(secs / 0.22)
		for s in steps:
			if not _pacing:
				break
			var b := create_tween()
			b.tween_property(n, "position:y", home_y - 2.0, 0.11)
			b.tween_property(n, "position:y", home_y, 0.11)
			await b.finished
		if walk.is_running():
			await walk.finished
		if not _pacing:
			break
		n.texture = UI.tex(_rakan(who, "south"))
		await get_tree().create_timer(randf_range(0.6, 1.2)).timeout
		going_right = not going_right
	n.position.y = home_y


## a little speech mark over a sprite's head ("?", "!"): pops, floats, fades
func _emote(n: Control, text: String, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 8)
	l.size = Vector2(40, 36)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = n.position + Vector2(n.size.x / 2.0 - 20, n.size.y * 0.15 - 30)
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(0.2, 0.2)
	add_child(l)
	move_child(l, flash.get_index())
	var t := create_tween()
	t.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "position:y", l.position.y - 10, 0.9)
	t.tween_property(l, "modulate:a", 0.0, 0.3)
	t.tween_callback(l.queue_free)


## an angry mark (four red strokes) that throbs over a head for a while
func _anger(n: Control) -> void:
	var m := Control.new()
	m.size = Vector2(24, 24)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.position = n.position + Vector2(n.size.x * 0.75 - 12, n.size.y * 0.1 - 18)
	m.pivot_offset = m.size / 2.0
	m.draw.connect(func():
		var c := Color("ff3b30")
		for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var o: Vector2 = Vector2(12, 12) + s * 5.0
			m.draw_line(o, o + Vector2(s.x * 6.0, 0), c, 3.0)
			m.draw_line(o, o + Vector2(0, s.y * 6.0), c, 3.0))
	add_child(m)
	move_child(m, flash.get_index())
	var t := create_tween().set_loops(4)
	t.tween_property(m, "scale", Vector2(1.3, 1.3), 0.15)
	t.tween_property(m, "scale", Vector2.ONE, 0.15)
	t.finished.connect(m.queue_free)


## a stamp-and-lean towards the other house while shouting, then back
func _shove(n: Control, dir: int) -> void:
	var x := n.position.x
	var t := create_tween()
	for i in 2:
		t.tween_property(n, "position:x", x + dir * 6.0, 0.07)
		t.tween_property(n, "position:x", x, 0.12)
	_hop(n)


## Alif takes two steps towards the water's edge
func _step_up(n: Control) -> void:
	var y := n.position.y
	var t := create_tween()
	for i in 2:
		t.tween_property(n, "position:y", y - 10 * (i + 1) - 6, 0.12)
		t.tween_property(n, "position:y", y - 10 * (i + 1), 0.12)


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
		# the same picture the player later earns for this Serpihan (zone ganjaran)
		var icon := str(Game.zone_data("1_%d" % (i + 1)).get("ganjaran", {}).get("icon", "bintang"))
		var s := _shard(icon)
		s.position = centre - s.size / 2.0
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


## one flying Serpihan: its reward icon on a soft gold glow
func _shard(icon: String) -> Control:
	var box := Control.new()
	box.size = Vector2(72, 72)
	box.pivot_offset = box.size / 2.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.draw.connect(func():
		for k in 4:
			box.draw_circle(box.size / 2.0, 36.0 - k * 7.0, Color(1, 0.86, 0.4, 0.12 + k * 0.06)))
	var r := TextureRect.new()
	r.texture = load("res://assets/icons/%s.png" % icon)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size = Vector2(56, 56)
	r.position = Vector2(8, 8)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(r)
	return box


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
		_shake = Vector2(randf_range(-3, 3), randf_range(-3, 3))
		await get_tree().create_timer(0.04).timeout
	_shake = Vector2.ZERO


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
	Main.dialog_box.auto_advance = false  # the wake-up in the room is read at your own pace
	Game.save["prolog_done"] = true
	Game.persist()
	GameState.flags["bilik_intro"] = true
	GameState.go_to(BILIK, Color(1, 0.97, 0.88))
