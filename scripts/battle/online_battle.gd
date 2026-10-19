class_name OnlineBattle
extends Node
## Online Bilik Pertarungan with friends, through Supabase (see
## supabase/multiplayer.sql). The server holds the room and applies the
## damage (BattleRules numbers), so nobody can cheat by editing their game.
## The client polls battle_state once a second (works in the web build).
##
## NOTE: written and documented but not tested yet: it needs a Supabase
## project (config/backend.json). The offline LocalBattle is the demo path.

signal state_changed(state: Dictionary)
signal failed(message: String)

const POLL := 1.0

var state: Dictionary = {}
var my_id := ""
var code := ""
var _poll_t := 0.0
var _busy := false
var _rewarded := false


func join(room_code: String) -> void:
	code = room_code
	my_id = Backend.user_id
	await _poll()


func me() -> Dictionary:
	return BattleRules.find(state.get("players", []), my_id)


func set_target(id: String) -> void:
	if id == my_id:
		return
	me()["target"] = id  # show it at once; the server keeps the real one
	state_changed.emit(state)
	await Backend.db_call("battle_target", {"p_code": code, "p_target": id})


func answer(i: int) -> void:
	var m := me()
	if m.is_empty() or int(m.get("answer", -1)) >= 0:
		return
	m["answer"] = i
	state_changed.emit(state)
	await Backend.db_call("battle_answer", {"p_code": code, "p_round": int(state.get("round", 0)), "p_answer": i, "p_target": m.get("target") if str(m.get("target", "")) != "" else null})


func leave() -> void:
	Backend.db_call("battle_leave", {"p_code": code})
	queue_free()


func _process(delta: float) -> void:
	if state.has("time_left"):
		state["time_left"] = maxf(0.0, float(state["time_left"]) - delta)
	_poll_t += delta
	if _poll_t >= POLL and not _busy:
		_poll_t = 0.0
		_poll()


func _poll() -> void:
	_busy = true
	var r: Dictionary = await Backend.db_call("battle_state", {"p_code": code})
	_busy = false
	if not r["ok"] or not (r["data"] is Dictionary):
		failed.emit(tr("Sambungan ke bilik terputus."))
		return
	var s: Dictionary = r["data"]
	# the bank lives in the game; the server sends only the question number
	if s.has("qid"):
		var q: Dictionary = BattleRules.bank()[int(s["qid"]) % BattleRules.bank().size()]
		s["q"] = {"q": q["q"], "options": q["options"]}
		s["explain"] = str(q.get("explain", ""))
	for p in s.get("players", []):
		p["me"] = str(p["id"]) == my_id
		p["answered"] = bool(p.get("answered", false))
		if p["me"] and state.has("players") and int(s.get("round", 0)) == int(state.get("round", -1)):
			var old := me()
			if int(p.get("answer", -1)) < 0 and int(old.get("answer", -1)) >= 0:
				p["answer"] = old["answer"]  # our answer may not have arrived yet
	state = s
	if str(s.get("status", "")) == "over" and not _rewarded:
		_rewarded = true
		var b: Dictionary = Game.save["battle"]
		b["played"] = int(b.get("played", 0)) + 1
		var won: bool = str(s.get("winner", "")) == my_id
		if won:
			b["wins"] = int(b.get("wins", 0)) + 1
		Game.add_reward(BattleRules.REWARD_EXP, BattleRules.REWARD_COINS if won else 0)
		Game.persist()
	state_changed.emit(state)
