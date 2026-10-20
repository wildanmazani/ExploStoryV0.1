class_name BattleRules
extends RefCounted
## Rules of the Bilik Pertarungan, shared by the offline battle (bots) and the
## online one (supabase/multiplayer.sql implements the same numbers).
##
## Each round: every player still standing picks a target and answers the
## same question. A correct answer hits the target for DAMAGE (the fastest
## correct answer adds BONUS). A wrong answer does nothing, no punishment.
## At 0 HP a player is out. The last one standing wins REWARD syiling.

const HP := 100
const DAMAGE := 25
const BONUS := 5
const ROUND_TIME := 30.0     ## seconds to answer (generous: read-aloud is there)
const REVEAL_TIME := 4.0     ## seconds showing the answer and the hits
const REWARD_COINS := 20
const REWARD_EXP := 30       ## everyone who plays gets this much EXP
const MIN_FRIENDS := 2       ## room = you + 2 to 4 friends (or bots)
const MAX_FRIENDS := 4
const BANK := "res://data/soalan/bab%d.json"
## which chapter the next battle asks about (0 = every finished chapter mixed)
static var chapter := 1

static var _bank: Array = []
static var _bank_for := -1


## Questions for the chosen chapter. The online room always uses Bab 1, the
## answer key the server holds (supabase/multiplayer.sql).
static func bank() -> Array:
	if _bank_for != chapter:
		_bank = []
		var nos: Array = [chapter]
		if chapter == 0:
			nos = []
			for n in range(1, 11):
				if n == 1 or Game.chapter_done(n) or Game.chapter_done(n - 1):
					nos.append(n)
		for n in nos:
			_bank.append_array(bank_of(n))
		_bank_for = chapter
	return _bank


static func chapter_name() -> String:
	return tr_safe("semua bab") if chapter == 0 else tr_safe("Bab %d") % chapter


static func tr_safe(s: String) -> String:
	return TranslationServer.translate(s)


static func bank_of(no: int) -> Array:
	var path := BANK % no
	if not FileAccess.file_exists(path):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d.get("questions", []) if d is Dictionary else []


## chapters that have a question bank and are open to this player
static func chapters_open() -> Array:
	var out: Array = []
	for n in range(1, 11):
		if FileAccess.file_exists(BANK % n) and Game.zone_unlocked(str(Game.chapter_zones(n)[0]) if not Game.chapter_zones(n).is_empty() else "%d_1" % n):
			out.append(n)
	return out


static func alive(players: Array) -> Array:
	return players.filter(func(p): return p["alive"])


## Default target: the weakest other player still standing.
static func auto_target(players: Array, from_id: String) -> String:
	var best := ""
	var best_hp := 99999
	for p in players:
		if p["alive"] and p["id"] != from_id and int(p["hp"]) < best_hp:
			best = p["id"]
			best_hp = int(p["hp"])
	return best


static func find(players: Array, id: String) -> Dictionary:
	for p in players:
		if p["id"] == id:
			return p
	return {}


## Applies one round. players[i] needs: id, hp, alive, answer (-1 = none),
## answered_at (seconds, smaller = faster), target. Returns the hits.
static func resolve(players: Array, correct: int) -> Array:
	var hits: Array = []
	var fastest := ""
	var fastest_t := INF
	for p in players:
		p["correct"] = p["alive"] and int(p.get("answer", -1)) == correct
		if p["correct"] and float(p.get("answered_at", INF)) < fastest_t:
			fastest_t = float(p["answered_at"])
			fastest = p["id"]
	for p in players:
		if not p["correct"]:
			continue
		var t := find(players, str(p.get("target", "")))
		if t.is_empty() or not t["alive"] or t["id"] == p["id"]:
			t = find(players, auto_target(players, p["id"]))
		if t.is_empty():
			continue
		var dmg := DAMAGE + (BONUS if p["id"] == fastest else 0)
		hits.append({"from": p["id"], "to": t["id"], "dmg": dmg})
	# damage lands at the same moment for everyone
	for h in hits:
		var t := find(players, h["to"])
		t["hp"] = maxi(0, int(t["hp"]) - int(h["dmg"]))
	for p in players:
		if p["alive"] and int(p["hp"]) <= 0:
			p["alive"] = false
	return hits
