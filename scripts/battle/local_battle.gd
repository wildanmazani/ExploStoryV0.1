class_name LocalBattle
extends Node
## Offline Bilik Pertarungan: you against 2-4 classmate bots on this device.
## Works without any server. Same state shape as OnlineBattle, so the battle
## screen (scripts/screens/pertarungan.gd) does not care which one it has.
##
## state = {status: "question"|"reveal"|"over", round, q: {q, options},
##          answer (reveal only), explain, time_left, players: [...], hits: [...],
##          winner: id ("" = draw)}

signal state_changed(state: Dictionary)

const BOTS := [
	{"name": "Aisyah", "avatar": "pelajar_2", "skin": "alif_melayu"},
	{"name": "Ravi", "avatar": "pelajar_3", "skin": "alif_sukan"},
	{"name": "Mei Ling", "avatar": "pelajar_2", "skin": "alif_pengakap"},
	{"name": "Daniel", "avatar": "pelajar_4", "skin": "alif_bomba"},
]

var state: Dictionary = {}
var my_id := "me"
var _questions: Array = []
var _qi := -1
var _t := 0.0
var _bot_plan := {}   ## bot id -> {at: seconds, answer: int}
var _reveal_left := 0.0


func setup(bot_count: int) -> void:
	bot_count = clampi(bot_count, BattleRules.MIN_FRIENDS, BattleRules.MAX_FRIENDS)
	var prof: Dictionary = Game.save["profile"]
	var players: Array = [{
		"id": my_id, "name": str(prof.get("display_name", prof["username"])), "avatar": str(prof.get("avatar", "pelajar_1")),
		"skin": Game.skin_folder(), "me": true, "bot": false, "acc": 1.0,
	}]
	var bots := BOTS.duplicate()
	bots.shuffle()
	for i in bot_count:
		var b: Dictionary = bots[i].duplicate()
		b["id"] = "bot%d" % i
		b["me"] = false
		b["bot"] = true
		b["acc"] = randf_range(0.45, 0.7)  # good classmates, not perfect
		players.append(b)
	for p in players:
		p["hp"] = BattleRules.HP
		p["alive"] = true
		p["target"] = ""
	for p in players:
		p["target"] = BattleRules.auto_target(players, p["id"])
	_questions = BattleRules.bank().duplicate()
	_questions.shuffle()
	state = {"status": "", "round": 0, "players": players, "hits": [], "winner": ""}


func start() -> void:
	_next_round()


func me() -> Dictionary:
	return BattleRules.find(state["players"], my_id)


## --- player actions (same API as OnlineBattle)
func set_target(id: String) -> void:
	var t := BattleRules.find(state["players"], id)
	if not t.is_empty() and t["alive"] and id != my_id:
		me()["target"] = id
		state_changed.emit(state)


func answer(i: int) -> void:
	var m := me()
	if state["status"] != "question" or not m["alive"] or int(m["answer"]) >= 0:
		return
	m["answer"] = i
	m["answered_at"] = _t
	m["answered"] = true
	state_changed.emit(state)
	_check_round_end()


func leave() -> void:
	queue_free()


# ------------------------------------------------------------------ rounds
func _next_round() -> void:
	_qi = (_qi + 1) % _questions.size()
	var q: Dictionary = _questions[_qi]
	_t = 0.0
	state["round"] = int(state["round"]) + 1
	state["status"] = "question"
	state["q"] = {"q": q["q"], "options": q["options"]}
	state.erase("answer")
	state["explain"] = ""
	state["hits"] = []
	state["time_left"] = BattleRules.ROUND_TIME
	_bot_plan.clear()
	for p in state["players"]:
		p["answer"] = -1
		p["answered"] = false
		p["answered_at"] = INF
		p["correct"] = false
		if p["alive"] and p["bot"]:
			var right := randf() < float(p["acc"])
			var wrong := (int(q["answer"]) + randi_range(1, 3)) % 4
			_bot_plan[p["id"]] = {"at": randf_range(4.0, 18.0), "answer": int(q["answer"]) if right else wrong}
			# bots spread their attacks (no ganging up on the player)
			p["target"] = _random_target(p["id"])
		var t := BattleRules.find(state["players"], str(p["target"]))
		if t.is_empty() or not t["alive"]:
			p["target"] = BattleRules.auto_target(state["players"], p["id"])
	state_changed.emit(state)


func _random_target(from_id: String) -> String:
	var opts: Array = BattleRules.alive(state["players"]).filter(func(p): return p["id"] != from_id)
	return opts.pick_random()["id"] if not opts.is_empty() else ""


func _process(delta: float) -> void:
	match str(state.get("status", "")):
		"question":
			_t += delta
			state["time_left"] = maxf(0.0, BattleRules.ROUND_TIME - _t)
			for id in _bot_plan:
				var b := BattleRules.find(state["players"], id)
				if not b["answered"] and _t >= float(_bot_plan[id]["at"]):
					b["answer"] = _bot_plan[id]["answer"]
					b["answered_at"] = _t
					b["answered"] = true
					state_changed.emit(state)
			if state["time_left"] <= 0.0:
				_reveal()
			else:
				_check_round_end()
		"reveal":
			_reveal_left -= delta
			if _reveal_left <= 0.0:
				_after_reveal()


func _check_round_end() -> void:
	if state["status"] != "question":
		return
	for p in BattleRules.alive(state["players"]):
		if not p["answered"]:
			return
	_reveal()


func _reveal() -> void:
	var q: Dictionary = _questions[_qi]
	state["answer"] = int(q["answer"])
	state["explain"] = str(q.get("explain", ""))
	state["hits"] = BattleRules.resolve(state["players"], int(q["answer"]))
	state["status"] = "reveal"
	_reveal_left = BattleRules.REVEAL_TIME
	state_changed.emit(state)


func _after_reveal() -> void:
	var standing := BattleRules.alive(state["players"])
	if standing.size() > 1:
		_next_round()
		return
	state["status"] = "over"
	state["winner"] = standing[0]["id"] if standing.size() == 1 else ""
	_reward()
	state_changed.emit(state)


func _reward() -> void:
	var b: Dictionary = Game.save["battle"]
	b["played"] = int(b.get("played", 0)) + 1
	var won: bool = state["winner"] == my_id
	if won:
		b["wins"] = int(b.get("wins", 0)) + 1
	state["level_up"] = Game.add_reward(BattleRules.REWARD_EXP, BattleRules.REWARD_COINS if won else 0)
	Game.persist()
