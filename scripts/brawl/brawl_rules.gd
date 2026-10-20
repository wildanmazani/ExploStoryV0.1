class_name BrawlRules
extends RefCounted
## Gelanggang Pesta Silat: the numbers. Every round is SOALAN (everyone
## answers one Bab 1 question) -> KEPUTUSAN (who got Semangat) -> AKSI (a
## short live brawl). Right answer = full damage + a school weapon drops for
## you; fastest right = Jurus Kilat; wrong = Lemah (30% damage). Last team
## standing wins. Frame data lives in data/brawl/moves.json.

const HP := 140
const ASK_TIME := 15.0
const BANNER_TIME := 2.2
const FIGHT_TIME := 10.0
const MAX_ROUNDS := 8
const SEMANGAT := 1.0
const LEMAH := 0.3
const BLOCK_TAKE := 0.2
const REWARD_COINS := 20
const REWARD_EXP := 30
const MAX_FLOOR_WEAPONS := 4

## team sizes [yours, theirs]
const FORMATS := {"1v1": [1, 1], "2v2": [2, 2], "1v2": [1, 2], "1v3": [1, 3]}
## bot answer accuracy range and fighting style
const LEVELS := {
	"mudah": {"name": "Mudah", "acc": [0.4, 0.55], "speed": 0.72, "block": 0.12, "cd": [1.0, 1.7], "combo": 0.25},
	"biasa": {"name": "Biasa", "acc": [0.55, 0.72], "speed": 0.88, "block": 0.3, "cd": [0.6, 1.2], "combo": 0.5},
	"sukar": {"name": "Sukar", "acc": [0.72, 0.88], "speed": 1.0, "block": 0.5, "cd": [0.35, 0.8], "combo": 0.75},
}

## The arena is simulated in "fight units" (fighters drawn 4x) and shown
## VIEW_SCALE bigger on the floor of the hall background (SCREEN_FLOOR).
const VIEW_SCALE := 1.25
const SCREEN_FLOOR := Rect2(120, 515, 1040, 175)
## the floor fighters stand on, in fight units: x left-right, y = depth
const FLOOR := Rect2(0, 0, 832, 140)
const DEPTH_BAND := 28.0   ## how far apart in depth a hit still connects
const SCALE := 4.0         ## sprites are drawn 4x

const MOVES_PATH := "res://data/brawl/moves.json"
static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(MOVES_PATH))
	return _data


static func move(name: String) -> Dictionary:
	return data()["moves"].get(name, {})


static func weapon(id: String) -> Dictionary:
	return data()["weapons"].get(id, {})


static func weapon_ids() -> Array:
	return data()["weapons"].keys()
