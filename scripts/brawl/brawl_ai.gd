class_name BrawlAI
extends RefCounted
## A classmate bot in the Gelanggang. Picks an enemy, walks to stand beside
## it, throws short combos, sometimes blocks, grabs the school item that
## dropped for it. Fair play: at most 2 bots attack the same fighter at once
## (the others hover around), so 1 vs 3 stays winnable.

var lv: Dictionary
var target: BrawlFighter
var _retarget := 0.0
var _cd := 0.6
var _seq: Array = []
var _seq_t := 0.0
var _block_left := 0.0
var _reacted := {}     ## attacker -> the attack we already reacted to
var _hover := Vector2.ZERO


func _init(level: String) -> void:
	lv = BrawlRules.LEVELS.get(level, BrawlRules.LEVELS["biasa"])
	_cd = randf_range(0.3, 0.9)
	_hover = Vector2(randf_range(160, 230), randf_range(-60, 60))


func think(f: BrawlFighter, delta: float, m: BrawlMatch) -> void:
	f.clear_intent()
	if not f.alive() or f.state in ["down", "hurt", "getup", "pickup", "dizzy"]:
		_seq.clear()
		return
	_cd -= delta
	_retarget -= delta
	_seq_t -= delta
	if _block_left > 0.0:
		_block_left -= delta
		f.intent["block"] = true
		return
	if _react(f, m):
		return
	if not _seq.is_empty():
		if _seq_t <= 0.0:
			f.intent[_seq.pop_front()] = true
			_seq_t = 0.17
		return
	if _retarget <= 0.0 or target == null or not target.alive():
		target = _pick_target(f, m)
		_retarget = randf_range(1.0, 1.8)
	if target == null:
		return
	# a school item lying close by (ours, or nobody's): go and take it
	if f.weapon_id == "":
		var w = m.weapon_near(f, 240.0)
		if w:
			var d: Vector2 = w.position - f.position
			if d.length() < BrawlFighter.PICK_RANGE - 10:
				f.intent["grab"] = true
			else:
				f.intent["move"] = d.normalized() * lv["speed"]
			return
	var side := -1 if f.position.x < target.position.x else 1
	var crowded := m.attackers_on(target, f) >= 2 and absf(f.position.x - target.position.x) > 120
	var spot := target.position + Vector2(side * 76.0, 0)
	if crowded:
		spot = target.position + Vector2(side * _hover.x, _hover.y)   # wait for a turn
	var d := spot - f.position
	if absf(d.x) > 20 or absf(d.y) > 10:
		f.intent["move"] = d.normalized() * float(lv["speed"])
		f.intent["run"] = absf(d.x) > 320
		return
	f.facing = -side
	if crowded or _cd > 0.0:
		return
	_cd = randf_range(lv["cd"][0], lv["cd"][1])
	if f.special_ready and randf() < 0.7:
		f.intent["special"] = true
	elif f.weapon_id != "":
		_seq = ["punch"]
	elif randf() < float(lv["combo"]):
		_seq = [["punch", "punch", "kick"], ["punch", "punch", "punch"], ["jump", "kick"]].pick_random()
	else:
		_seq = [["punch"], ["kick"], ["punch", "punch"]].pick_random()
	_seq_t = 0.0


## see a punch coming? sometimes block it
func _react(f: BrawlFighter, m: BrawlMatch) -> bool:
	for e in m.enemies_of(f):
		if e.state != "attack" or _reacted.get(e, -1) == e.attack_no:
			continue
		_reacted[e] = e.attack_no
		var dx: float = e.position.x - f.position.x
		if absf(dx) < 140 and absf(e.position.y - f.position.y) < 30 and signf(-dx) == float(e.facing):
			if randf() < float(lv["block"]):
				f.facing = 1 if dx > 0 else -1
				_block_left = 0.45
				f.intent["block"] = true
				return true
	return false


func _pick_target(f: BrawlFighter, m: BrawlMatch) -> BrawlFighter:
	var best: BrawlFighter = null
	var best_score := INF
	for e in m.enemies_of(f):
		if not e.alive():
			continue
		var score: float = f.position.distance_to(e.position) + e.hp + m.attackers_on(e, f) * 260.0
		if score < best_score:
			best_score = score
			best = e
	return best
