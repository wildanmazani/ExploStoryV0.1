class_name WarisanRules
extends RefCounted
## Pesta Warisan (the traditional games): the list of games, their questions
## and their rewards. A game with a screen in Game.SCREENS under its id can be
## played; the others show AKAN DATANG on the fair's board.

const GAMES := [
	{"id": "galah", "icon": "galah", "name": "Galah Panjang",
		"desc": "Lepasi empat garisan yang dijaga rakan sekelas, sampai hujung, dan balik semula."},
	{"id": "upih", "icon": "upih", "name": "Tarik Upih",
		"desc": "Tarik Pau di atas upih pinang. Ikut rentak, jangan sampai dia tergolek!"},
	{"id": "gasing", "icon": "gasing", "name": "Gasing",
		"desc": "Lilit, lempar, dan biar gasing uri paling lama. Atau pangkah gasing lawan."},
	{"id": "wau", "icon": "wau", "name": "Wau Bulan",
		"desc": "Bina wau, kemudian kawal talinya ikut angin Pantai Timur."},
	{"id": "raga", "icon": "bola_raga", "name": "Sepak Raga",
		"desc": "Timang bola rotan dalam bulatan. Berapa kali sebelum jatuh?"},
]
const LEVELS := ["Mudah", "Biasa", "Sukar"]
const REWARD_EXP := 20
const COINS := [15, 25, 40]       ## a win, by level
const COINS_PER_ANSWER := 5       ## each question answered right on the way


## Revision questions for the games: from the subtopics already finished, in
## every open chapter (all of Bab 1 until the first mission is done), shuffled.
static func questions() -> Array:
	var done: Array = Game.ZONES.filter(func(z): return Game.zone_done(z))
	var out: Array = []
	for n in range(1, 11):
		out.append_array(BattleRules.bank_of(n).filter(func(q): return done.has(str(q.get("zon", "")))))
	if out.is_empty():
		out = BattleRules.bank_of(1).duplicate()
	out.shuffle()
	return out


## A game is over: counts it, pays a win, saves. Returns {exp, coins, level_up, best}.
static func finish(game: String, won: bool, level: int, right: int, seconds: float) -> Dictionary:
	if not Game.save.has("warisan"):
		Game.save["warisan"] = {}
	var st: Dictionary = Game.save["warisan"].get(game, {"main": 0, "menang": 0, "terbaik": 0.0})
	st["main"] = int(st.get("main", 0)) + 1
	var res := {"exp": 0, "coins": 0, "level_up": false, "best": false}
	if won:
		st["menang"] = int(st.get("menang", 0)) + 1
		if float(st.get("terbaik", 0.0)) <= 0.0 or seconds < float(st["terbaik"]):
			st["terbaik"] = snappedf(seconds, 0.1)
			res["best"] = true
		res["exp"] = REWARD_EXP
		res["coins"] = COINS[clampi(level, 0, 2)] + COINS_PER_ANSWER * right
		res["level_up"] = Game.add_reward(res["exp"], res["coins"])
	Game.save["warisan"][game] = st
	Game.persist()
	return res
