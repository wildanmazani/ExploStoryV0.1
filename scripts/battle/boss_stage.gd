extends Control
## The Ujian Bab battlefield: Alif and the boss face each other over the
## question panel. A right answer pushes the camera in for a combo, a wrong one
## lets the boss strike back, and the last hit is a slow finisher.
## Everything here is drawn over a plain Control, so it works on any screen width.

const UI = preload("res://scripts/ui/ui.gd")
const ROW_Y := 226.0            ## ground line while a question is on screen
const ROW_SCALE := 0.62
const COMBOS := [["jab", "cross"], ["kick", "roundhouse"], ["flykick"]]
const WORDS := ["POW!", "BAM!", "DUSH!", "KRAK!"]

var _bg: TextureRect
var _actors: Node2D
var _alif: AnimatedSprite2D
var _boss: AnimatedSprite2D
var _flash: ColorRect
var _feet := 640.0     ## ground line in the close-up, where the art's floor is
var _fighter := false  ## the boss has fight frames: he fights like Alif does
var _down := false
var _idle: Tween


func setup(bg_path: String, npc: String, ground := 640.0) -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feet = ground
	_fighter = CharacterFrames.has_fight_anim(npc, "stance")
	var under := ColorRect.new()  # shows where the background slides up
	under.color = Color(0.05, 0.04, 0.07)
	UI.full(under)
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(under)
	_bg = UI.bg_image(bg_path, Color.WHITE if _fighter else Color(1.15, 1.1, 1.2))
	add_child(_bg)
	add_child(_embers())
	_actors = Node2D.new()
	add_child(_actors)
	var skin: String = Game.skin_folder()
	_alif = AnimatedSprite2D.new()
	_alif.sprite_frames = CharacterFrames.build_fight(skin)
	_alif.offset = CharacterFrames.feet_offset(skin)
	_alif.scale = Vector2(7, 7)
	_alif.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_alif.animation_finished.connect(func(): _alif.play("stance"))
	_actors.add_child(_alif)
	_boss = AnimatedSprite2D.new()
	_boss.sprite_frames = CharacterFrames.build_fight(npc) if _fighter else CharacterFrames.build(npc)
	_boss.offset = CharacterFrames.feet_offset(npc)
	_boss.scale = Vector2(7, 7) if _fighter else Vector2(9, 9)
	_boss.flip_h = _fighter  # his frames face east, Alif is on the left
	_boss.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_actors.add_child(_boss)
	_boss.play("stance" if _fighter else "idle_south")
	if _fighter:
		_boss.animation_finished.connect(func():
			if not _down:
				_boss.play("stance"))
	_alif.play("stance")
	_flash = ColorRect.new()
	UI.full(_flash)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_place()


func _ready() -> void:
	get_viewport().size_changed.connect(_place)
	_boss_float()


func _alif_home() -> Vector2:
	return Vector2(Game.screen_w() * 0.22, _feet)


func _boss_home() -> Vector2:
	return Vector2(Game.screen_w() * 0.74, _feet if _fighter else _feet - 20.0)


func _place() -> void:
	_alif.position = _alif_home()
	_boss.position = _boss_home()
	_actors.position = _row_pos()
	_bg.position.y = _row_bg_y()


## the background slides up with the fighters, so they stay on the ground
func _row_bg_y() -> float:
	return ROW_Y - _feet


func _row_pos() -> Vector2:
	return Vector2(Game.screen_w() * (1.0 - ROW_SCALE) / 2.0, ROW_Y - _feet * ROW_SCALE)


func _boss_float() -> void:
	if _fighter:
		return
	_idle = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_idle.tween_property(_boss, "offset:y", _boss.offset.y - 2.0, 0.9)
	_idle.tween_property(_boss, "offset:y", _boss.offset.y, 0.9)


func _embers() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.position = Vector2(640, 730)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(900, 10)
	p.direction = Vector2(0, -1)
	p.spread = 14.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = Color(1.0, 0.35, 0.45, 0.8)
	return p


# ---------------------------------------------------------------- camera
## full view for the fighting; the panel leaves first
func to_close() -> void:
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_actors, "scale", Vector2.ONE, 0.22)
	t.tween_property(_actors, "position", Vector2.ZERO, 0.22)
	t.tween_property(_bg, "position:y", 0.0, 0.22)
	await t.finished


## back above the question panel
func to_row() -> void:
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_actors, "scale", Vector2.ONE * ROW_SCALE, 0.28)
	t.tween_property(_actors, "position", _row_pos(), 0.28)
	t.tween_property(_bg, "position:y", _row_bg_y(), 0.28)
	await t.finished


func show_close_now() -> void:
	_actors.scale = Vector2.ONE
	_actors.position = Vector2.ZERO
	_bg.position.y = 0.0


# ---------------------------------------------------------------- moments
## the entrance: Alif lands, the boss forms out of the dark
func entrance(title: String) -> void:
	show_close_now()
	_boss.modulate = Color(0, 0, 0, 0)
	_alif.position.x = -160.0
	_alif.play("walk")
	var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_alif, "position", _alif_home(), 0.7)
	await t.finished
	_alif.play("stance")
	Sfx.play("heartbeat", -2.0)
	var b := create_tween()
	b.tween_property(_boss, "modulate", Color(0.4, 0.1, 0.5, 1.0), 0.9)
	await b.finished
	Sfx.play("kick", 0.0)
	flash(Color(0.7, 0.2, 0.9), 0.75, 0.5)
	shake(16.0, 0.5)
	burst(_boss.position + Vector2(0, -160), Color("b04ae0"), 60)
	_boss.modulate = Color.WHITE
	var l := UI.label(title, "Title")
	l.add_theme_color_override("font_color", Color("ffb0a0"))
	l.add_theme_constant_override("outline_size", 14)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.1))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(Game.screen_w(), 100)
	l.position = Vector2(0, 60)
	l.pivot_offset = Vector2(Game.screen_w() / 2.0, 50)
	l.scale = Vector2(3, 3)
	l.modulate.a = 0.0
	add_child(l)
	var s := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	s.tween_property(l, "scale", Vector2.ONE, 0.3)
	s.tween_property(l, "modulate:a", 1.0, 0.15)
	await get_tree().create_timer(1.3).timeout
	var o := create_tween()
	o.tween_property(l, "modulate:a", 0.0, 0.3)
	await o.finished
	l.queue_free()


## a right answer. n = hit number, so the combos change as the boss weakens
func hit(n: int, final: bool) -> void:
	var near := _boss.position + Vector2(-150, 0) if _fighter else _boss.position + Vector2(-190, 20)
	await _dash(near, 0.16)
	if final:
		await _finisher()
		await _dash(_alif_home(), 0.3)
		return
	for move in COMBOS[(n - 1) % COMBOS.size()]:
		_alif.play(move)
		await get_tree().create_timer(0.14).timeout
		_impact(n)
		await get_tree().create_timer(0.16).timeout
	await _dash(_alif_home(), 0.22)
	_alif.play("stance")


func _impact(n: int) -> void:
	Sfx.play_varied("kick" if n % 2 == 0 else "punch", -1.0)
	var at := _boss.position + Vector2(-60, -160)
	burst(at, Color("ffd76a"), 24)
	word(WORDS[randi() % WORDS.size()], at + Vector2(randf_range(-50, 50), randf_range(-80, 0)), Color("ffe08a"))
	shake(10.0 + n, 0.2)
	flash(Color.WHITE, 0.2, 0.12)
	if _fighter:
		_boss.play("hurt")
	_boss.modulate = Color(4, 4, 4)
	var t := create_tween()
	t.tween_property(_boss, "position:x", _boss_home().x + 46.0, 0.06)
	t.parallel().tween_property(_boss, "modulate", Color(1.5, 0.5, 0.6), 0.1)
	t.tween_property(_boss, "position:x", _boss_home().x, 0.22).set_trans(Tween.TRANS_BACK)
	t.parallel().tween_property(_boss, "modulate", Color.WHITE, 0.22)


## the last hit: the world slows, the boss cracks with light and shatters
func _finisher() -> void:
	flash(Color("ffd76a"), 0.5, 0.4)
	Sfx.play("whoosh", 0.0)
	_alif.play("special")
	for i in 5:
		await get_tree().create_timer(0.13).timeout
		_impact(5)
	Engine.time_scale = 0.35
	word("TUMBANG!", _boss.position + Vector2(-40, -340), Color("ff7a6a"), 2.0)
	await get_tree().create_timer(0.3 * 0.35).timeout
	Engine.time_scale = 1.0
	for i in 6:
		_boss.modulate = Color(5, 5, 5) if i % 2 == 0 else Color(0.6, 0.1, 0.8)
		burst(_boss.position + Vector2(randf_range(-70, 70), randf_range(-280, 0)), Color("b04ae0"), 20)
		Sfx.play_varied("thwack", -3.0)
		await get_tree().create_timer(0.1).timeout
	if _fighter:
		_down = true
		_boss.modulate = Color.WHITE
		_boss.play("fall")
		var fly := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly.tween_property(_boss, "position:x", _boss_home().x + 150.0, 0.6)
		Sfx.play("fall", 2.0)
		shake(24.0, 0.7)
		flash(Color.WHITE, 0.7, 0.6)
		burst(_boss.position + Vector2(0, -30), Color("c8b48a"), 50)
		await get_tree().create_timer(1.0).timeout
		return
	Sfx.play("fall", 2.0)
	shake(26.0, 0.8)
	flash(Color.WHITE, 1.0, 0.9)
	burst(_boss.position + Vector2(0, -160), Color("e9c8ff"), 90)
	if _idle:
		_idle.kill()
	var t := create_tween().set_parallel()
	t.tween_property(_boss, "scale", Vector2(14, 3), 0.5)
	t.tween_property(_boss, "modulate:a", 0.0, 0.5)
	await t.finished


## a wrong answer: he rushes Alif, or the dark boss blasts him
func hurt() -> void:
	if _fighter:
		await _boss_rush()
		return
	var c := create_tween()
	c.tween_property(_boss, "modulate", Color(2.4, 0.5, 0.7), 0.2)
	await c.finished
	Sfx.play("swish", 0.0)
	var orb := Orb.new()
	orb.position = _boss.position + Vector2(-70, -180)
	_actors.add_child(orb)
	var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(orb, "position", _alif_home() + Vector2(0, -120), 0.28)
	await t.finished
	orb.queue_free()
	Sfx.play("thwack", 0.0)
	_alif.play("hurt")
	flash(Color(0.9, 0.05, 0.1), 0.6, 0.4)
	shake(18.0, 0.35)
	burst(_alif_home() + Vector2(0, -120), Color("b04ae0"), 34)
	word("ADUH!", _alif_home() + Vector2(0, -260), Color("ff8a8a"))
	create_tween().tween_property(_boss, "modulate", Color.WHITE, 0.3)
	var k := create_tween()
	k.tween_property(_alif, "position:x", _alif_home().x - 60.0, 0.1)
	k.tween_property(_alif, "position:x", _alif_home().x, 0.3)
	await get_tree().create_timer(0.7).timeout
	_alif.play("stance")


func _boss_rush() -> void:
	Sfx.play("swish", -2.0)
	_boss.play("walk")
	var go := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	go.tween_property(_boss, "position", _alif_home() + Vector2(150, 0), 0.26)
	await go.finished
	for move in COMBOS[randi() % COMBOS.size()]:
		_boss.play(move)
		await get_tree().create_timer(0.16).timeout
		Sfx.play_varied("kick", 0.0)
		_alif.play("hurt")
		var at := _alif_home() + Vector2(10, -150)
		burst(at, Color("ff6a5a"), 26)
		word("ADUH!", at + Vector2(randf_range(-60, 30), -90), Color("ff8a8a"))
		flash(Color(0.9, 0.05, 0.1), 0.45, 0.25)
		shake(16.0, 0.25)
		var k := create_tween()
		k.tween_property(_alif, "position:x", _alif_home().x - 70.0, 0.08)
		k.tween_property(_alif, "position:x", _alif_home().x, 0.24)
		await get_tree().create_timer(0.3).timeout
	_boss.play("walk")
	var back := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	back.tween_property(_boss, "position", _boss_home(), 0.3)
	await back.finished
	_boss.play("stance")
	_alif.play("stance")


func _dash(to: Vector2, seconds: float) -> void:
	Sfx.play("swish", -3.0)
	var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_alif, "position", to, seconds)
	for i in 4:  # fading echoes behind the dash
		_echo()
		await get_tree().create_timer(seconds / 4.0).timeout
	if t.is_running():
		await t.finished


func _echo() -> void:
	var tex := _alif.sprite_frames.get_frame_texture(_alif.animation, _alif.frame)
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.offset = _alif.offset
	s.scale = _alif.scale
	s.flip_h = _alif.flip_h
	s.position = _alif.position
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.modulate = Color(0.6, 0.85, 1.0, 0.55)
	_actors.add_child(s)
	var t := s.create_tween()
	t.tween_property(s, "modulate:a", 0.0, 0.22)
	t.tween_callback(s.queue_free)


# ---------------------------------------------------------------- effects
func flash(col: Color, strength: float, seconds: float) -> void:
	_flash.color = Color(col, strength)
	create_tween().tween_property(_flash, "color:a", 0.0, seconds)


func shake(strength: float, seconds: float) -> void:
	var t := create_tween()
	var steps := maxi(int(seconds / 0.04), 2)
	for i in steps:
		var k := 1.0 - float(i) / steps
		t.tween_property(self, "position", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * k, 0.04)
	t.tween_property(self, "position", Vector2.ZERO, 0.04)


func burst(at: Vector2, col: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.55
	p.position = at
	p.spread = 180.0
	p.gravity = Vector2(0, 500)
	p.initial_velocity_min = 180.0
	p.initial_velocity_max = 520.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	p.color = col
	_actors.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func word(text: String, at: Vector2, col: Color, size_k := 1.0) -> void:
	var l := Label.new()
	l.text = text
	l.theme = Game.theme
	l.add_theme_font_size_override("font_size", int(58 * size_k))
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.08))
	l.add_theme_constant_override("outline_size", 14)
	l.position = at
	l.scale = Vector2(0.4, 0.4)
	l.z_index = 5
	_actors.add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.25)
	t.tween_property(l, "modulate:a", 0.0, 0.2)
	t.tween_callback(l.queue_free)


## the boss's dark blast
class Orb extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var r := 34.0 + sin(_t * 40.0) * 5.0
		draw_circle(Vector2.ZERO, r + 14.0, Color(0.5, 0.1, 0.7, 0.4))
		draw_circle(Vector2.ZERO, r, Color(0.16, 0.03, 0.22))
		draw_circle(Vector2.ZERO, r * 0.45, Color(1.0, 0.35, 0.3))
