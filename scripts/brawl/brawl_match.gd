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
signal want_answer(i: int)   ## online, not the host: send this answer to the host
signal roster_ready          ## online, not the host: the host's first snapshot built the fighters

## Online (scripts/screens/gelanggang.gd + RealtimeChannel): the room host runs
## the whole fight; everyone else sends their buttons and answers to the host
## and shows the host's snapshots (puppet fighters).
var online := false
var host := true
var remote_input := {}       ## fighter id -> {mv, run, blk, c: [punch, kick, jump, grab, special] press counts}
var _remote_seen := {}       ## fighter id -> press counts already used
var _events: Array = []      ## hits since the last snapshot (host)
var _roster: Array = []
var _item_uid := 0
var _items_by_uid := {}      ## client: uid -> FloorItem
var _rewarded := false

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
	var bots := Game.bot_roster(LocalBattle.BOTS)   # same order as the Lobby shows
	var people: Array = [{"id": "me", "name": str(prof.get("display_name", prof["username"])), "skin": Game.battle_look(), "team": 0, "me": true}]
	var bi := 0
	for t in 2:
		for k in int(sizes[t]) - (1 if t == 0 else 0):
			var b: Dictionary = bots[bi % bots.size()].duplicate()
			b["id"] = "bot%d" % bi
			b["team"] = t
			people.append(b)
			bi += 1
	_spawn(people)
	_questions = BattleRules.bank().duplicate()
	_questions.shuffle()


## Online room: roster = [{id, name, skin, team}] built by the host (players
## by their account id, bots "bot..."); my_id marks this player's fighter.
## Not the host: the roster arrives with the first snapshot (apply_snapshot).
func setup_online(roster: Array, my_id: String, is_host: bool, lvl: String, chapter: int) -> void:
	online = true
	host = is_host
	level = lvl if BrawlRules.LEVELS.has(lvl) else "biasa"
	scale = Vector2.ONE * BrawlRules.VIEW_SCALE
	position = BrawlRules.SCREEN_FLOOR.position
	stage = Node2D.new()
	stage.y_sort_enabled = true
	add_child(stage)
	fx = BrawlFx.new()
	add_child(fx)
	set_meta("my_id", my_id)
	if is_host:
		_spawn(_mark_me(roster, my_id))
		_questions = BattleRules.bank_of(chapter).duplicate()
		if _questions.is_empty():
			_questions = BattleRules.bank_of(1).duplicate()
		_questions.shuffle()


func _mark_me(roster: Array, my_id: String) -> Array:
	var out: Array = []
	for r in roster:
		var p: Dictionary = r.duplicate()
		p["me"] = str(p["id"]) == my_id
		out.append(p)
	return out


func _spawn(people: Array) -> void:
	_roster = people.map(func(p): return {"id": p["id"], "name": p["name"], "skin": p["skin"], "team": p["team"]})
	var my_team := 0
	for p in people:
		if p.get("me", false):
			my_team = int(p["team"])
	for p in people:
		var f := BrawlFighter.new()
		f.setup(p)
		f.arena = self
		f.my_team = my_team
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
		if online and not host:
			f.puppet = true
		if f.is_me:
			me = f
		elif not online or (host and str(f.id).begins_with("bot")):
			_ais[f.id] = BrawlAI.new(level)


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
		if f.alive() and not f.is_me and _ais.has(f.id):
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
	if online and not host:
		want_answer.emit(i)
	changed.emit()


## host: another player's answer arrived
func remote_answer(id: String, i: int) -> void:
	var f := find(id)
	if phase != "soalan" or f == null or not f.alive() or answers.has(id):
		return
	answers[id] = {"i": i, "at": phase_t}
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
	_item_uid += 1
	it.set_meta("uid", _item_uid)
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
	if _rewarded:
		return
	_rewarded = true
	var b: Dictionary = Game.save["battle"]
	b["played"] = int(b.get("played", 0)) + 1
	var won := me != null and winner_team == me.team
	if won:
		b["wins"] = int(b.get("wins", 0)) + 1
	level_up = Game.add_reward(BrawlRules.REWARD_EXP, BrawlRules.REWARD_COINS if won else 0)
	Game.persist()


func _process(delta: float) -> void:
	if online and not host:
		if phase in ["soalan", "aksi"]:
			phase_t += delta  # between snapshots, so the clocks run smoothly
		return
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
	if phase != "aksi" or (online and not host):
		return
	for f in fighters:
		if f.is_me and not me_autopilot:
			_read_player(f)
		elif online and not f.is_me and not _ais.has(f.id):
			_read_remote(f)
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


## host: another player's buttons, from the network. Presses arrive as
## counts so a quick tap between two messages is never lost.
func _read_remote(f: BrawlFighter) -> void:
	var ri: Dictionary = remote_input.get(f.id, {})
	if ri.is_empty():
		f.clear_intent()
		return
	var c: Array = ri.get("c", [0, 0, 0, 0, 0])
	var seen: Array = _remote_seen.get(f.id, [0, 0, 0, 0, 0])
	var pulse := [false, false, false, false, false]
	for k in 5:
		if int(c[k]) > int(seen[k]):
			pulse[k] = true
			seen[k] = int(seen[k]) + 1
	_remote_seen[f.id] = seen
	var mv: Array = ri.get("mv", [0, 0])
	f.intent = {
		"move": Vector2(float(mv[0]), float(mv[1])).limit_length(1.0),
		"run": bool(ri.get("run", false)), "block": bool(ri.get("blk", false)),
		"punch": pulse[0], "kick": pulse[1], "jump": pulse[2], "grab": pulse[3], "special": pulse[4],
	}


# ------------------------------------------------------------------ online snapshots
## host: the whole fight in a small dictionary, sent about ten times a second
func snapshot() -> Dictionary:
	var items: Array = []
	for it in _items:
		if is_instance_valid(it):
			items.append([it.get_meta("uid", 0), it.id, roundi(it.position.x), roundi(it.position.y), roundi(it.z), it.crate, it.flying, it.for_id])
	var shown := phase in ["keputusan", "aksi", "tamat"]
	var s := {
		"ph": phase, "pt": snappedf(phase_t, 0.05), "rn": round_no, "q": q,
		"ai": answer_index if shown else -1, "ex": explain if shown else "",
		"an": answers.keys(), "rs": results if shown else [], "wt": winner_team,
		"f": fighters.map(func(f): return f.net_state()), "it": items, "ev": _events, "ro": _roster,
	}
	_events = []
	return s


## not the host: show the host's snapshot
func apply_snapshot(s: Dictionary) -> void:
	if fighters.is_empty():
		var ro: Array = s.get("ro", [])
		if ro.is_empty():
			return
		_spawn(_mark_me(ro, str(get_meta("my_id", ""))))
		if me == null:
			return
		roster_ready.emit()
	q = s.get("q", q)
	answer_index = int(s.get("ai", -1))
	explain = str(s.get("ex", ""))
	results = s.get("rs", [])
	winner_team = int(s.get("wt", -1))
	round_no = int(s.get("rn", round_no))
	for r in results:
		r["me"] = me != null and str(r["id"]) == me.id
	var mine: Dictionary = answers.get(me.id, {}) if me else {}
	answers.clear()
	for id in s.get("an", []):
		answers[str(id)] = {}
	if not mine.is_empty():
		answers[me.id] = mine
	for a in s.get("f", []):
		var f := find(str(a[0]))
		if f:
			f.net_apply(a)
	_sync_items(s.get("it", []))
	for ev in s.get("ev", []):
		var t := find(str(ev.get("t", "")))
		var b := find(str(ev.get("b", "")))
		if t and b:
			t._flash = 0.14
			_hit_fx(t, int(ev.get("d", 1)), ev, b)
	var ph := str(s.get("ph", ""))
	if ph != phase:
		if ph == "soalan":
			answers.clear()  # a new question
		_set_phase(ph)
		if ph == "tamat":
			_reward()
	phase_t = float(s.get("pt", phase_t))
	changed.emit()


func _sync_items(list: Array) -> void:
	var keep := {}
	for a in list:
		var uid := int(a[0])
		keep[uid] = true
		var it: FloorItem = _items_by_uid.get(uid)
		if it == null:
			it = FloorItem.new()
			stage.add_child(it)
			_items_by_uid[uid] = it
		it.id = str(a[1])
		it.position = Vector2(float(a[2]), float(a[3]))
		it.z = float(a[4])
		it.crate = bool(a[5])
		it.flying = bool(a[6])
		it.for_id = str(a[7])
		it.age += 0.1
		it.queue_redraw()
	for uid in _items_by_uid.keys():
		if not keep.has(uid):
			var gone: FloorItem = _items_by_uid[uid]
			_items_by_uid.erase(uid)
			if is_instance_valid(gone):
				fx.poof(gone.position + Vector2(0, -gone.z), Color(str(BrawlRules.weapon(gone.id).get("color", "ffffff"))))
				gone.queue_free()


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
	if online:
		_events.append({"t": target.id, "b": by.id, "d": dmg, "blocked": info["blocked"], "word": str(info["word"]),
			"big": info["big"], "sfx": str(info["sfx"]), "ko": info["ko"]})
	_hit_fx(target, dmg, info, by)


func _hit_fx(target: BrawlFighter, dmg: int, info: Dictionary, by: BrawlFighter) -> void:
	var p := target.head_pos() + Vector2(0, 40)
	if info["blocked"]:
		fx.word(p, "TANGKIS", Color("9fd4ff"))
		Sfx.play("tock", -4.0)
	else:
		fx.star(p + Vector2(-target.facing * 10, 10), info["big"])
		var away := signf(target.position.x - by.position.x)
		fx.impact(p + Vector2(-target.facing * 10, 10), away if away != 0.0 else float(by.facing),
			Color("ffd24a") if by.mult >= BrawlRules.SEMANGAT else Color("c8d4e4"), info["big"])
		target.impact()
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
