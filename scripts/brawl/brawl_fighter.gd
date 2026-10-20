class_name BrawlFighter
extends Node2D
## One fighter in the Gelanggang: moves on a 2.5D floor (x, depth) and jumps
## (z), punches / kicks with combos, blocks, picks up and swings or throws
## school items, gets hurt, knocked down and finally PENGSAN (fainted, dizzy
## stars). Driven by `intent` (filled by the player's keys or BrawlAI), so
## people and bots use exactly the same rules. No blood: hits show stars and
## comic words, low HP shows a plaster and a bruise.

signal hit(target: BrawlFighter, dmg: int, info: Dictionary)

const WALK := Vector2(250, 150)
const RUN_MUL := 1.65
const JUMP_V := 560.0
const GRAVITY := 1700.0
const CHAIN := 0.42        ## seconds to press the next combo button
const DOWN_TIME := 0.9
const GETUP_TIME := 0.5
const BLOCK_MAX := 2.2     ## hold block longer than this and you get dizzy
const PICK_RANGE := 70.0

const TEAM_COLORS := [Color("f0c040"), Color("e05a4a")]  # your team gold, theirs red
const ALLY_COLOR := Color("6aa7e8")

var id := ""
var display_name := ""
var team := 0
var is_me := false
var skin := "alif"
var arena: Node            ## BrawlMatch: enemies, weapons, fx
var hp := BrawlRules.HP
var mult := BrawlRules.LEMAH
var special_ready := false
var frozen := true
var facing := 1
var z := 0.0
var vz := 0.0
var vel := Vector2.ZERO    ## knockback / lunge, fades out
var state := "idle"
var state_t := 0.0
var weapon_id := ""
var weapon_uses := 0
var intent := {}
var hitpause := 0.0
var invuln := 0.0
var answered_right := false
var attack_no := 0         ## counts attacks (bots react once per attack)

var _move := {}
var _move_name := ""
var _hit_ids := {}
var _last_attack := ""
var _last_attack_end := -10.0
var _queued := ""
var _clock := 0.0
var _stun := 0.0
var _block_t := 0.0
var _flash := 0.0
var _sprite: AnimatedSprite2D
var _held: Node2D
var _tag: Label
var _has := {}             ## anim -> has real frames
var _feet := 0.0


func setup(p: Dictionary) -> void:
	id = str(p["id"])
	display_name = str(p["name"])
	team = int(p["team"])
	is_me = bool(p.get("me", false))
	skin = str(p.get("skin", "alif"))
	clear_intent()


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = CharacterFrames.build_fight(skin)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * BrawlRules.SCALE
	add_child(_sprite)
	for a in CharacterFrames.FIGHT_ANIMS:
		_has[a] = CharacterFrames.has_fight_anim(skin, a)
	# feet on the node origin
	var tex: Texture2D = load("%s%s/%s_east.png" % [CharacterFrames.BASE, skin, skin])
	_feet = CharacterFrames.visible_bottom_offset(tex).y * BrawlRules.SCALE
	_held = Node2D.new()
	_held.draw.connect(_draw_weapon)
	add_child(_held)
	# only you get a tag ("KAU"); team rings + the HUD name everyone else, so a
	# crowded fight doesn't turn into a pile of names
	_tag = Label.new()
	_tag.text = tr("KAU")
	_tag.visible = is_me
	_tag.add_theme_font_size_override("font_size", 20)
	_tag.add_theme_color_override("font_color", _team_color())
	_tag.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
	_tag.add_theme_constant_override("outline_size", 6)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.size = Vector2(180, 28)
	add_child(_tag)
	_play("stance")


func _team_color() -> Color:
	if is_me:
		return TEAM_COLORS[0]
	return ALLY_COLOR if team == 0 else TEAM_COLORS[1]


func clear_intent() -> void:
	intent = {"move": Vector2.ZERO, "run": false, "punch": false, "kick": false, "jump": false,
		"grab": false, "block": false, "special": false}


func alive() -> bool:
	return state != "pengsan"


func can_be_hit() -> bool:
	return alive() and invuln <= 0.0 and state != "down"


## in the match's own coordinates (the arena is drawn scaled)
func head_pos() -> Vector2:
	return position + Vector2(0, -118 - z)


# ------------------------------------------------------------------ loop
func _physics_process(delta: float) -> void:
	_clock += delta
	if hitpause > 0.0:
		hitpause -= delta
		_sprite.speed_scale = 0.0
		return
	if _sprite.speed_scale == 0.0:
		_sprite.speed_scale = 1.0
	state_t += delta
	invuln = maxf(0.0, invuln - delta)
	_flash = maxf(0.0, _flash - delta)
	var move_v := Vector2.ZERO
	if not frozen:
		move_v = _think_state(delta)
	elif state in ["walk", "block", "attack"] and z == 0.0:
		_set_state("idle")
	# physics: knockback + walking, jump arc, stay on the floor
	position += (move_v + vel) * delta
	vel = vel.move_toward(Vector2.ZERO, 1400.0 * delta)
	var f := BrawlRules.FLOOR
	position.x = clampf(position.x, f.position.x, f.end.x)
	position.y = clampf(position.y, f.position.y, f.end.y)
	if z > 0.0 or vz != 0.0:
		vz -= GRAVITY * delta
		z += vz * delta
		if z <= 0.0:
			z = 0.0
			vz = 0.0
			_landed()
	_update_visual()


func _think_state(delta: float) -> Vector2:
	match state:
		"idle", "walk":
			return _free(delta)
		"attack":
			_attack_tick()
		"hurt":
			if state_t >= _stun:
				_set_state("idle")
		"down":
			if state_t >= DOWN_TIME and z == 0.0:
				_set_state("getup")
				invuln = GETUP_TIME + 0.4
		"getup":
			if state_t >= GETUP_TIME:
				_set_state("idle")
		"block":
			_block_t += delta
			if not intent["block"]:
				_set_state("idle")
			elif _block_t > BLOCK_MAX:
				_stun = 1.0
				_set_state("hurt")
				arena.fx_word(head_pos(), "PENING", Color("c9a0ff"))
		"pickup":
			if state_t >= 0.32:
				_set_state("idle")
		"dizzy":
			if state_t >= 1.0:
				_set_state("idle")
	return Vector2.ZERO


## standing / walking: read the intent
func _free(_delta: float) -> Vector2:
	var m: Vector2 = intent["move"]
	if intent["block"] and z == 0.0:
		_block_t = 0.0
		_set_state("block")
		return Vector2.ZERO
	if intent["special"] and special_ready:
		special_ready = false
		_start("special")
		return Vector2.ZERO
	if intent["grab"]:
		if weapon_id != "":
			_start("throw")
		else:
			var w = arena.weapon_near(self)
			if w:
				arena.take_weapon(w, self)
				_set_state("pickup")
				Sfx.play("pop", -6.0, 1.1)
		return Vector2.ZERO
	if intent["jump"] and z == 0.0:
		vz = JUMP_V
		Sfx.play("swish", -8.0, 0.8)
	if intent["punch"] or _queued == "punch":
		_queued = ""
		_start(_pick_punch(m))
		return Vector2.ZERO
	if intent["kick"] or _queued == "kick":
		_queued = ""
		_start(_pick_kick())
		return Vector2.ZERO
	if m.length() > 0.1:
		if absf(m.x) > 0.1:
			facing = 1 if m.x > 0 else -1
		var run: bool = intent["run"]
		if state != "walk" and z == 0.0:
			_set_state("walk")
		return m.limit_length(1.0) * WALK * (RUN_MUL if run else 1.0)
	if state != "idle" and z == 0.0:
		_set_state("idle")
	return Vector2.ZERO


func _pick_punch(m: Vector2) -> String:
	if weapon_id != "":
		return "swing"
	var chained := _clock - _last_attack_end < CHAIN
	if intent["run"] and m.length() > 0.1 and z == 0.0:
		return "dash"
	if chained and _last_attack == "jab":
		return "jab2"
	if chained and _last_attack == "jab2":
		return "straight"
	return "jab"


func _pick_kick() -> String:
	if z > 0.0:
		return "flykick"
	if _clock - _last_attack_end < CHAIN and _last_attack == "jab2":
		return "roundhouse"   # P, P, K
	return "kick"


func _start(name: String) -> void:
	_move = BrawlRules.move(name)
	_move_name = name
	attack_no += 1
	_hit_ids.clear()
	_set_state("attack")
	var anim: String = _move.get("anim", "jab")
	_play(anim)
	var n := _sprite.sprite_frames.get_frame_count(anim)
	_sprite.speed_scale = maxf(0.2, float(n) / (float(_move["time"]) * 10.0))
	if _move.has("lunge"):
		vel.x += float(_move["lunge"]) * facing
	Sfx.play("swish", -10.0, randf_range(0.9, 1.2))


func _attack_tick() -> void:
	var t: float = state_t / float(_move["time"])
	if _move_name == "throw":
		if t >= float(_move["release"]) and weapon_id != "":
			arena.throw_weapon(self)
			weapon_id = ""
	elif _move.has("active"):
		var a: Array = _move["active"]
		if t >= float(a[0]) and t <= float(a[1]):
			_hit_test()
		# a button pressed late in the move is remembered for the combo
		if t > float(a[1]):
			if intent["punch"]:
				_queued = "punch"
			elif intent["kick"]:
				_queued = "kick"
	if state_t >= float(_move["time"]):
		_last_attack = _move_name
		_last_attack_end = _clock
		_set_state("idle")


func _hit_test() -> void:
	var w := BrawlRules.weapon(weapon_id) if _move_name == "swing" else {}
	var reach: Array = _move.get("reach", [0, 80])
	var far: float = float(reach[1]) + (float(w.get("reach", 0)) if not w.is_empty() else 0.0)
	var sweep: bool = w.get("sweep", false)
	var landed := false
	for e in arena.enemies_of(self):
		if _hit_ids.has(e) or not e.can_be_hit():
			continue
		if sweep and _hit_ids.size() >= 2:
			break
		var dx: float = (e.position.x - position.x) * facing
		var dy: float = absf(e.position.y - position.y)
		var ok := false
		if _move.has("radius"):
			ok = Vector2(dx, dy * 2.0).length() <= float(_move["radius"])
		else:
			ok = dx >= float(reach[0]) and dx <= far and dy <= BrawlRules.DEPTH_BAND
		if ok and absf(e.z - z) > 70.0 and not _move.get("air", false):
			ok = false   # jumped over it
		if not ok:
			continue
		_hit_ids[e] = true
		var info := _move.duplicate()
		if not w.is_empty():
			info["dmg"] = w["dmg"]
			info["kb"] = w.get("kb", _move["kb"])
			info["word"] = "PAP!"
			info["stun"] = w.get("stun", _move.get("stun", 0.35))
			info["down"] = w.get("down", false)
		e.take_hit(self, info)
		landed = true
		if not w.is_empty() and (not sweep or _hit_ids.size() == 1):
			weapon_uses -= 1
	if landed and weapon_id != "" and weapon_uses <= 0:
		arena.fx_poof(position + Vector2(facing * 50, -70), BrawlRules.weapon(weapon_id).get("color", "ffffff"))
		weapon_id = ""


## damage = move damage x the attacker's Semangat (1.0) or Lemah (0.3)
func take_hit(by: BrawlFighter, info: Dictionary) -> void:
	var from := signi(int(by.position.x - position.x))
	if from == 0:
		from = -by.facing
	var blocked := state == "block" and from == facing
	var dmg := float(info.get("dmg", 4)) * by.mult
	if blocked:
		dmg *= BrawlRules.BLOCK_TAKE
	var d := maxi(1, roundi(dmg))
	hp = maxi(0, hp - d)
	facing = from
	var kb := float(info.get("kb", 100)) * (0.3 if blocked else 1.0)
	vel.x = -from * kb
	hitpause = 0.07
	by.hitpause = 0.05
	_flash = 0.14
	if hp <= 0:
		_set_state("pengsan")
		vz = 280.0
		frozen = true
	elif blocked:
		pass
	elif info.get("down", false):
		_set_state("down")
		vz = 300.0
	else:
		_stun = float(info.get("stun", 0.3))
		_set_state("hurt")
	by.hit.emit(self, d, {"blocked": blocked, "word": info.get("word", "PAK"), "big": info.get("big", false),
		"sfx": info.get("sfx", "punch"), "ko": hp <= 0})


func _landed() -> void:
	if state in ["down", "pengsan"]:
		Sfx.play("fall", -4.0)
		arena.fx_dust(position)
	elif state != "attack":
		arena.fx_dust(position, 0.5)


func _set_state(s: String) -> void:
	if state == "pengsan":
		return
	state = s
	state_t = 0.0
	match s:
		"idle", "block", "dizzy":
			_play("stance")
		"walk":
			_play("walk")
		"hurt":
			_play("hurt")
		"down", "pengsan":
			_play("fall")
		"getup":
			_play("getup")
		"pickup":
			_play("pickup")


func _play(anim: String) -> void:
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)
	_sprite.speed_scale = 1.0


# ------------------------------------------------------------------ look
func _update_visual() -> void:
	_sprite.flip_h = facing < 0
	_sprite.position = Vector2(0, _feet - z)
	_sprite.rotation = 0.0
	_sprite.modulate = Color.WHITE
	# cartoon fallbacks while an animation has no PixelLab frames yet
	match state:
		"attack":
			var anim: String = _move.get("anim", "")
			if not _has.get(anim, false):
				var t: float = clampf(state_t / float(_move.get("time", 0.3)), 0.0, 1.0)
				_sprite.position.x = facing * sin(t * PI) * 18.0
				_sprite.rotation = facing * sin(t * PI) * (0.25 if anim in ["kick", "roundhouse", "flykick"] else 0.08)
				if anim == "special":
					_sprite.rotation = state_t * 18.0 * facing
		"hurt":
			if not _has.get("hurt", false):
				_sprite.position.x = -facing * 6.0
		"down", "pengsan":
			if not _has.get("fall", false):
				_sprite.rotation = -facing * PI / 2.0
				_sprite.position.y = -20.0 - z
		"getup":
			if not _has.get("getup", false):
				_sprite.rotation = -facing * PI / 2.0 * (1.0 - state_t / GETUP_TIME)
		"block":
			_sprite.modulate = Color(0.75, 0.85, 1.0)
		"dizzy":
			_sprite.rotation = sin(state_t * 12.0) * 0.08
	if _flash > 0.0:
		_sprite.modulate = Color(1.6, 1.6, 1.6)
	if state == "pengsan":
		_sprite.modulate = Color(0.7, 0.7, 0.75)
	if invuln > 0.0 and state != "pengsan":
		_sprite.modulate.a = 0.55 if int(_clock * 20.0) % 2 == 0 else 1.0
	_tag.position = Vector2(-90, -170 - z)
	_tag.modulate.a = 0.45 if state == "pengsan" else 1.0
	_held.queue_redraw()
	queue_redraw()


func _draw() -> void:
	# shadow + team ring on the floor
	var s := 1.0 - minf(z / 300.0, 0.5)
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 46 * s, Color(0, 0, 0, 0.35))
	if alive():
		draw_arc(Vector2.ZERO, 54 * s, 0, TAU, 40, Color(_team_color(), 0.85), 5.0, true)
	draw_set_transform(Vector2.ZERO)
	var head := Vector2(4 * facing, -106 - z)
	if state == "pengsan":
		head = Vector2(-facing * 70, -26 - z)
	# low HP: plaster, then a bruise and sweat (cartoon, never blood)
	if hp < BrawlRules.HP * 0.4:
		var p := head + Vector2(-14 * facing, -6)
		draw_set_transform(p, 0.5 * facing, Vector2.ONE)
		draw_rect(Rect2(-13, -5, 26, 10), Color("f3d2a2"))
		draw_rect(Rect2(-4, -5, 8, 10), Color("e2b98a"))
		draw_rect(Rect2(-13, -5, 26, 10), Color("b98a5a"), false, 1.5)
		draw_set_transform(Vector2.ZERO)
	if hp < BrawlRules.HP * 0.2:
		draw_circle(head + Vector2(12 * facing, 8), 7, Color(0.55, 0.35, 0.75, 0.55))
		if alive():
			var sy := fmod(_clock * 30.0, 18.0)
			draw_circle(head + Vector2(26 * facing, -8 + sy), 3.5, Color(0.6, 0.85, 1.0, 0.8))
	# dizzy stars over fainted / dizzy heads
	if state in ["pengsan", "dizzy"] or (state == "hurt" and _stun >= 0.9):
		for i in 3:
			var a := _clock * 4.0 + i * TAU / 3.0
			var c := head + Vector2(cos(a) * 26, -24 + sin(a) * 8)
			_star(c, 7.0, Color("ffe066"))
	if state == "pengsan":
		draw_string(ThemeDB.fallback_font, head + Vector2(20, -46), "Zzz", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.8))


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(-PI / 2 + i * PI / 5) * rr)
	draw_colored_polygon(pts, col)


## the school item in Alif's hand (drawn, so any skin can hold any item)
func _draw_weapon() -> void:
	if weapon_id == "" or not alive():
		return
	var w := BrawlRules.weapon(weapon_id)
	var col := Color(str(w.get("color", "ffffff")))
	var hand := Vector2(22 * facing, -66 - z)
	var ang := -0.9
	if state == "attack" and _move_name == "swing":
		ang = lerpf(-2.2, 0.9, clampf(state_t / float(_move["time"]), 0.0, 1.0))
	_held.draw_set_transform(hand, ang * facing + (0.0 if facing > 0 else PI), Vector2.ONE)
	WeaponArt.draw_item(_held, weapon_id, col)
	_held.draw_set_transform(Vector2.ZERO)
