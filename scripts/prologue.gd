extends Control
## Prologue, Babak 1 (GDS section 2): Alif's room at night, 3 days before SPM.
## The paragraph's letters scramble so the player feels what reading is like
## for Alif, the clock and heartbeat speed up, he squeezes Pau and dozes off,
## then golden pages carry us into a dream: a port in chaos, then Gua Warisan
## where Nirbana breaks the Telaga Batu inscription into four Serpihan (the
## goal of Bab 1). Then Dunia Explo-Story (world intro continues in world.gd).
## Skippable at any time.

const UI = preload("res://scripts/ui/ui.gd")
const WORLD := "res://scenes/world/world.tscn"
const PARAGRAPH := "Kesultanan Melayu Melaka diasaskan oleh Parameswara pada awal abad ke-15. Melaka mempunyai ciri-ciri negara bangsa iaitu kerajaan, rakyat, kedaulatan, wilayah pengaruh, undang-undang dan lambang kebesaran."
const MIRROR := {"b": "d", "d": "b", "p": "q", "q": "p", "m": "w", "w": "m", "n": "u", "u": "n"}

var _skipping := false
var _tick_gap := 1.0
var _ticking := false
var _heart_gap := 0.0  ## 0 = no heartbeat

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
	book.modulate.a = 0.0
	caption.modulate.a = 0.0
	_run()


# --- the sequence ---------------------------------------------------------
func _run() -> void:
	_clock_loop()
	_heart_loop()
	_lamp_loop()
	await _fade(caption, 1.0, 1.0)
	await _wait(2.0)
	await _fade(caption, 0.0, 0.8)

	book_text.text = PARAGRAPH
	await _fade(book, 1.0, 0.8)
	await _wait(1.2)
	await _say("pro_read")

	# the letters start to drift and swap
	_tick_gap = 0.7
	_heart_gap = 1.1
	for i in 26:
		if _skipping: return
		var amount := i / 25.0
		book_text.text = "[shake rate=%d level=%d]%s[/shake]" % [10 + i, int(amount * 9), _scramble(PARAGRAPH, amount * 0.55)]
		await _wait(0.16)
	_tick_gap = 0.45
	_heart_gap = 0.7
	_shake_room(true)
	await _say("pro_scramble")

	# Alif gives up, squeezes Pau
	_shake_room(false)
	await _fade(book, 0.0, 0.6)
	for i in 2:
		Sfx.play("squish", -4.0, 1.0 + i * 0.1)
		var t := create_tween()
		t.tween_property(pau, "scale", Vector2(1.25, 0.75), 0.12)
		t.tween_property(pau, "scale", Vector2(1, 1), 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
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

	# golden pages carry him away
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
	await _dream()
	if _skipping: return
	await _fade(flash, 1.0, 0.8)
	_go_to_world()


## The dream: chaos at an old port, the cave, Nirbana and the four Serpihan.
func _dream() -> void:
	if _skipping: return
	var bg := _scene_image("res://assets/backgrounds/bg_pelabuhan_huru.png")
	bg.modulate = Color(1.0, 0.75, 0.7)
	var alif := _sprite("res://assets/characters32/%s/%s_south.png" % [Game.skin_folder(), Game.skin_folder()], Vector2(640, 610), 6)
	MusicDirector.play("siguntang", 1.0)
	flash.color = Color(1, 1, 1)
	await _fade(flash, 0.0, 0.8)
	room.position = Vector2.ZERO
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
	Game.save["prolog_done"] = true
	Game.persist()
	GameState.flags["world_intro"] = true
	GameState.go_to(WORLD, Color(1, 0.97, 0.88))
