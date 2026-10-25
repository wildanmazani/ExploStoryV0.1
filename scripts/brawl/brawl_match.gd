class_name BrawlMatch
extends Node2D
## Gelanggang Pesta Silat, the match itself (offline, you + classmate bots).
## Phases: "soalan" (everyone answers, arena frozen) -> "keputusan" (who got
## Semangat, school items drop, fastest gets Jurus Kilat) -> "aksi" (live
## brawl for FIGHT_TIME) -> next round ... -> "tamat". The screen
## (scripts/screens/gelanggang.gd) draws the question card and HUD from the
## signals; this node owns the fighters, items and effects.

signal phase_changed(phase: String)
signal changed
signal hit_landed(by: BrawlFighter, target: BrawlFighter, dmg: int)

var format := "1v1"
var level := "biasa"
var fighters: Array[BrawlFighter] = []
var me: BrawlFighter
var me_autopilot := false    ## autotest: a bot plays for you
var phase := ""
var phase_t := 0.0
var round_no := 0
var q: Dictionary = {}       ## {q, options} (no answer until keputusan)
var answer_index := -1       ## right answer, shown in keputusan
var explain := ""
var answers := {}            ## fighter id -> {i, at}
var results: Array = []      ## [{id, name, right, fastest}] for the banner
var winner_team := -1
var level_up := false

var stage: Node2D            ## y-sorted: fighters + items
var fx: BrawlFx
var _ais := {}               ## fighter id -> BrawlAI
var _bot_plan := {}          ## fighter id -> {at, i}
var _questions: Array = []
var _qi := -1
var _items: Array = []       ## FloorItem


func setup(fmt: String, lvl: String) -> void:
	format = fmt if BrawlRules.FORMATS.has(fmt) else "1v1"
	level = lvl if BrawlRules.LEVELS.has(lvl) else "biasa"
	scale = Vector2.ONE * BrawlRules.VIEW_SCALE
	position = BrawlRules.SCREEN_FLOOR.position
	stage = Node2D.new()
	stage.y_sort_enabled = true
	add_child(stage)
	fx = BrawlFx.new()
	add_child(fx)
	var sizes: Array = BrawlRules.FORMATS[format]
	var prof: Dictionary = Game.save["profile"]
	var bots := LocalBattle.BOTS.duplicate()   # same order as the Lobby shows
	var people: Array = [{"id": "me", "name": str(prof.get("display_name", prof["username"])), "skin": Game.skin_folder(), "team": 0, "me": true}]
	var bi := 0
	for t in 2:
		for k in int(sizes[t]) - (1 if t == 0 else 0):
			var b: Dictionary = bots[bi % bots.size()].duplicate()
			b["id"] = "bot%d" % bi
			b["team"] = t
			people.append(b)
			bi += 1
	for p in people:
		var f := BrawlFighter.new()
		f.setup(p)
		f.arena = self
		var mates := people.filter(func(o): return o["team"] == p["team"])
		var k := mates.find(p)
		var fl := BrawlRules.FLOOR
		var x := fl.position.x + fl.size.x * 0.16 - k * 50.0 if p["team"] == 0 else fl.end.x - fl.size.x * 0.16 + k * 50.0
		var y := BrawlRules.FLOOR.position.y + BrawlRules.FLOOR.size.y * (0.5 + (k - (mates.size() - 1) / 2.0) * 0.32)
		f.position = Vector2(x, y)
		f.facing = 1 if p["team"] == 0 else -1
		f.hit.connect(_on_hit.bind(f))
		stage.add_child(f)
		fighters.append(f)
		if f.is_me:
			me = f
		else:
			_ais[f.id] = BrawlAI.new(level)
	_questions = BattleRules.bank().duplicate()
	_questions.shuffle()


func start() -> void:
	_next_round()


# ------------------------------------------------------------------ queries (fighters use these)
func enemies_of(f: BrawlFighter) -> Array:
	return fighters.filter(func(o): return o.team != f.team and o.alive())


func team_alive(t: int) -> Array:
	return fighters.filter(func(o): return o.team == t and o.alive())


func attackers_on(target: BrawlFighter, except: BrawlFighter) -> int:
	var n := 0
	for id in _ais:
		var ai: BrawlAI = _ais[id]
		var f := find(id)
		if f and f != except and f.alive() and ai.target == target and f.position.distance_to(target.position) < 170:
			n += 1
	return n


func find(id: String) -> BrawlFighter:
	for f in fighters:
		if f.id == id:
			return f
	return null


## closest floor item a fighter may take (dropped for them, or for nobody)
func weapon_near(f: BrawlFighter, within := BrawlFighter.PICK_RANGE) -> Node2D:
	var best: Node2D = null
	var bd := within
	for it in _items:
		if it.flying or it.z > 4.0 or (it.for_id != "" and it.for_id != f.id and it.age < 4.0):
			continue
		var d := Vector2(it.position.x - f.position.x, (it.position.y - f.position.y) * 1.6).length()
		if d < bd:
			bd = d
			best = it
	return best


func take_weapon(it: Node2D, f: BrawlFighter) -> void:
	f.weapon_id = it.id
	f.weapon_uses = int(BrawlRules.weapon(it.id)["uses"])
	_items.erase(it)
	it.queue_free()


func throw_weapon(f: BrawlFighter) -> void:
	var it := FloorItem.new()
	it.id = f.weapon_id
	it.position = f.position
	it.z = 64.0
	it.flying = true
	it.vx = 760.0 * f.facing
	it.thrower = f
	stage.add_child(it)
	_items.append(it)
	Sfx.play("swish", -4.0, 0.8)


func fx_word(pos: Vector2, text: String, col := Color("ffe066")) -> void:
	fx.word(pos, text, col)


func fx_dust(pos: Vector2, amount := 1.0) -> void:
	fx.dust(pos, amount)


func fx_poof(pos: Vector2, col_hex: String) -> void:
	fx.poof(pos, Color(col_hex))
	Sfx.play("pop", -2.0, 0.8)


# ------------------------------------------------------------------ phases
func _set_phase(p: String) -> void:
	phase = p
	phase_t = 0.0
	phase_changed.emit(p)
	changed.emit()


func _next_round() -> void:
	round_no += 1
	if round_no > BrawlRules.MAX_ROUNDS:
		_finish(_team_by_hp())
		return
	for f in fighters:
		f.frozen = true
		f.clear_intent()
	_qi = (_qi + 1) % _questions.size()
	var item: Dictionary = _questions[_qi]
	q = {"q": item["q"], "options": item["options"]}
	answer_index = int(item["answer"])
	explain = str(item.get("explain", ""))
	answers.clear()
	results.clear()
	_bot_plan.clear()
	for f in fighters:
		if f.alive() and not f.is_me:
			var acc := randf_range(BrawlRules.LEVELS[level]["acc"][0], BrawlRules.LEVELS[level]["acc"][1])
			var right := randf() < acc
			_bot_plan[f.id] = {"at": randf_range(3.0, 11.0), "i": answer_index if right else (answer_index + randi_range(1, 3)) % 4}
	if me_autopilot and me.alive():
		_bot_plan[me.id] = {"at": 1.0, "i": answer_index}
	_set_phase("soalan")


## the player's answer (A-D = 0-3)
func answer(i: int) -> void:
	if phase != "soalan" or not me.alive() or answers.has(me.id):
		return
	answers[me.id] = {"i": i, "at": phase_t}
	changed.emit()


func _keputusan() -> void:
	var fastest := ""
	var best := INF
	for f in fighters:
		if not f.alive():
			continue
		var a: Dictionary = answers.get(f.id, {})
		var right: bool = not a.is_empty() and int(a["i"]) == answer_index
		f.answered_right = right
		f.mult = BrawlRules.SEMANGAT if right else BrawlRules.LEMAH
		f.special_ready = false
		if right and float(a["at"]) < best:
			best = float(a["at"])
			fastest = f.id
		results.append({"id": f.id, "name": f.display_name, "right": right, "fastest": false, "team": f.team, "me": f.is_me})
	for r in results:
		if r["id"] == fastest:
			r["fastest"] = true
			find(fastest).special_ready = true
	# a school item drops near everyone who got it right (a few on the floor at most)
	for f in fighters:
		if f.alive() and f.answered_right and f.weapon_id == "" and _items.size() < BrawlRules.MAX_FLOOR_WEAPONS:
			_drop_item(f)
	_set_phase("keputusan")


func _drop_item(f: BrawlFighter) -> void:
	var it := FloorItem.new()
	it.id = BrawlRules.weapon_ids().pick_random()
	it.for_id = f.id
	var x := clampf(f.position.x + f.facing * 60.0, BrawlRules.FLOOR.position.x + 20, BrawlRules.FLOOR.end.x - 20)
	it.position = Vector2(x, f.position.y + 6)
	it.z = 520.0   # falls from the sky in a little crate
	it.crate = true
	stage.add_child(it)
	_items.append(it)


func _team_by_hp() -> int:
	var hp := [0, 0]
	for f in fighters:
		hp[f.team] += f.hp
	return 0 if hp[0] >= hp[1] else 1


func _finish(team: int) -> void:
	winner_team = team
	for f in fighters:
		f.frozen = true
		f.clear_intent()
	_reward()
	_set_phase("tamat")


func _reward() -> void:
	var b: Dictionary = Game.save["battle"]
	b["played"] = int(b.get("played", 0)) + 1
	var won := winner_team == 0
	if won:
		b["wins"] = int(b.get("wins", 0)) + 1
	level_up = Game.add_reward(BrawlRules.REWARD_EXP, BrawlRules.REWARD_COINS if won else 0)
	Game.persist()


func _process(delta: float) -> void:
	if phase == "" or phase == "tamat":
		return
	phase_t += delta
	match phase:
		"soalan":
			for id in _bot_plan:
				if not answers.has(id) and phase_t >= float(_bot_plan[id]["at"]):
					answers[id] = {"i": int(_bot_plan[id]["i"]), "at": phase_t}
					changed.emit()
			var all := true
			for f in fighters:
				if f.alive() and not answers.has(f.id):
					all = false
			if all or phase_t >= BrawlRules.ASK_TIME:
				_keputusan()
		"keputusan":
			if phase_t >= BrawlRules.BANNER_TIME:
				for f in fighters:
					f.frozen = not f.alive()
				Sfx.play("bell", -4.0)
				_set_phase("aksi")
		"aksi":
			if team_alive(1).is_empty():
				_finish(0)
			elif team_alive(0).is_empty():
				_finish(1)
			elif phase_t >= BrawlRules.FIGHT_TIME:
				Sfx.play("bell", -6.0, 0.8)
				_next_round()


func _physics_process(delta: float) -> void:
	# intents first (this node runs before its children: the fighters)
	if phase != "aksi":
		return
	for f in fighters:
		if f.is_me and not me_autopilot:
			_read_player(f)
		elif _ais.has(f.id):
			_ais[f.id].think(f, delta, self)
		elif f.is_me:
			if not _ais.has("me"):
				_ais["me"] = BrawlAI.new("sukar")
			_ais["me"].think(f, delta, self)
	for it in _items.duplicate():
		_update_item(it, delta)


func _read_player(f: BrawlFighter) -> void:
	f.intent = {
		"move": Input.get_vector("move_left", "move_right", "move_up", "move_down"),
		"run": Input.is_action_pressed("run"),
		"punch": Input.is_action_just_pressed("attack_punch"),
		"kick": Input.is_action_just_pressed("attack_kick"),
		"jump": Input.is_action_just_pressed("jump"),
		"grab": Input.is_action_just_pressed("grab"),
		"block": Input.is_action_pressed("block"),
		"special": Input.is_action_just_pressed("special"),
	}


func _update_item(it: FloorItem, delta: float) -> void:
	it.age += delta
	if it.flying:
		it.position.x += it.vx * delta
		for e in fighters:
			if it.thrower and e.team != it.thrower.team and e.can_be_hit() \
					and absf(e.position.x - it.position.x) < 44 and absf(e.position.y - it.position.y) < BrawlRules.DEPTH_BAND:
				var w := BrawlRules.weapon(it.id)
				e.take_hit(it.thrower, {"dmg": w.get("throw_dmg", 8), "kb": 300, "stun": 0.45, "word": "BUK!", "sfx": "thwack",
					"down": w.get("down", false)})
				_land_thrown(it, true)
				return
		var f := BrawlRules.FLOOR
		if it.position.x < f.position.x - 40 or it.position.x > f.end.x + 40:
			_land_thrown(it, false)
	elif it.z > 0.0:
		it.vz -= 1700.0 * delta
		it.z = maxf(0.0, it.z + it.vz * delta)
		if it.z == 0.0:
			it.vz = 0.0
			if it.crate:
				it.crate = false
				fx.dust(it.position, 0.8)
				Sfx.play("bump", -6.0, 1.3)
	it.queue_redraw()


func _land_thrown(it: FloorItem, hit_someone: bool) -> void:
	if BrawlRules.weapon(it.id).get("bounce", false):
		it.flying = false
		it.vx = 0.0
		it.thrower = null
		it.for_id = ""
		it.vz = 260.0 if hit_someone else 0.0
		it.position.x = clampf(it.position.x, BrawlRules.FLOOR.position.x, BrawlRules.FLOOR.end.x)
		return
	fx.poof(it.position + Vector2(0, -it.z), Color(str(BrawlRules.weapon(it.id).get("color", "ffffff"))))
	_items.erase(it)
	it.queue_free()


func _on_hit(target: BrawlFighter, dmg: int, info: Dictionary, by: BrawlFighter) -> void:
	var p := target.head_pos() + Vector2(0, 40)
	if info["blocked"]:
		fx.word(p, "TANGKIS", Color("9fd4ff"))
		Sfx.play("tock", -4.0)
	else:
		fx.star(p + Vector2(-target.facing * 10, 10), info["big"])
		# one word per attack, even when it hits several people
		if by.get_meta("word_attack", -1) != by.attack_no:
			by.set_meta("word_attack", by.attack_no)
			fx.word(p + Vector2(0, -30), str(info["word"]), Color("ffe066") if by.team == 0 else Color("ffb0a0"), info["big"])
		Sfx.play_varied(str(info["sfx"]), -2.0, 0.12)
		if info["big"] or info["ko"]:
			_slowmo()
	fx.number(target.head_pos(), dmg, Color("ffd24a") if by.is_me else (Color("ff7a6a") if target.is_me else Color.WHITE))
	if target.is_me or by.is_me:
		_shake(7.0 if info["big"] else 4.0)
	if info["ko"]:
		fx.word(target.head_pos() + Vector2(0, -20), "PENGSAN!", Color("c9a0ff"), true)
	hit_landed.emit(by, target, dmg)
	changed.emit()


func _slowmo() -> void:
	if Engine.time_scale != 1.0:
		return   # autotest runs fast, leave it alone
	Engine.time_scale = 0.35
	# a connection, not an await: if the match is freed mid slow-mo (Keluar)
	# the call is dropped instead of resuming on a freed node
	get_tree().create_timer(0.15, true, false, true).timeout.connect(_end_slowmo)


func _end_slowmo() -> void:
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _shake(s: float) -> void:
	var home := BrawlRules.SCREEN_FLOOR.position
	var t := create_tween()
	for i in 4:
		t.tween_property(self, "position", home + Vector2(randf_range(-s, s), randf_range(-s, s)), 0.03)
	t.tween_property(self, "position", home, 0.03)


## A school item on the floor (or flying, after a throw). Drops in a crate.
class FloorItem extends Node2D:
	var id := ""
	var for_id := ""     ## dropped for this fighter (others can take it after 4 s)
	var z := 0.0
	var vz := 0.0
	var vx := 0.0
	var flying := false
	var crate := false
	var age := 0.0
	var thrower: BrawlFighter

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.3))
		draw_circle(Vector2.ZERO, 22, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO)
		var p := Vector2(0, -12 - z)
		if crate:
			draw_rect(Rect2(p + Vector2(-22, -22), Vector2(44, 40)), Color("b07a3a"))
			draw_rect(Rect2(p + Vector2(-22, -22), Vector2(44, 40)), Color(0.2, 0.12, 0.05), false, 3.0)
			draw_line(p + Vector2(-22, -2), p + Vector2(22, -2), Color(0.2, 0.12, 0.05), 2.0)
			draw_arc(p + Vector2(0, -40), 26, PI, TAU, 16, Color.WHITE, 3.0)   # little parachute
			return
		var w := BrawlRules.weapon(id)
		var spin := age * 14.0 if flying else 0.0
		if not flying and for_id != "" and age < 4.0:
			draw_arc(Vector2.ZERO + Vector2(0, -2), 30, 0, TAU, 24, Color(1, 0.9, 0.4, 0.5 + 0.4 * sin(age * 6.0)), 3.0)
		draw_set_transform(p + Vector2(-20, 0), spin, Vector2(0.8, 0.8))
		WeaponArt.draw_item(self, id, Color(str(w.get("color", "ffffff"))))
		draw_set_transform(Vector2.ZERO)
