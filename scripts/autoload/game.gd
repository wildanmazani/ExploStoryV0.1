extends Node
## Global game state (autoload "Game"): content data, save file, settings,
## progression (Module 5), screen navigation and the shared theme.

const UI = preload("res://scripts/ui/ui.gd")

signal settings_changed
signal stats_changed
signal pau_pressed
signal hint_requested(tier: int)

const SCREENS := {
	"title": "res://scripts/screens/title.gd",
	"login": "res://scripts/screens/login.gd",
	"register": "res://scripts/screens/register.gd",
	"prolog": "res://scripts/screens/prolog.gd",
	"peta": "res://scripts/screens/peta.gd",
	"zone_prep": "res://scripts/screens/zone_prep.gd",
	"zone": "res://scripts/screens/zone_area.gd",
	"zone_summary": "res://scripts/screens/zone_summary.gd",
	"penutup": "res://scripts/screens/penutup.gd",
	"lobby": "res://scripts/screens/lobby.gd",
}

const ZONES := ["1_1", "1_2", "1_3", "1_4"]
const EXP_PER_LEVEL := 200
const SETTINGS_PATH := "user://tetapan.json"
const DEFAULT_SETTINGS := {
	"font": "lexend", "text_size": 1, "text_speed": 1, "auto_read": false,
	"muted": false, "music": 0.8, "sfx": 0.8,
}

var main: Node = null
var theme: Theme
var settings: Dictionary = {}
var save: Dictionary = {}
var characters: Dictionary = {}
var chapters: Dictionary = {}
var story: Dictionary = {}
var _zone_cache: Dictionary = {}
var input_lock: int = 0
## Set by the active screen so Pau can give a context hint outside puzzles.
var context_hint: String = ""
## Puzzle currently on screen (receives Pau hints), or null.
var active_puzzle: Node = null


func _ready() -> void:
	_setup_input()
	settings = DEFAULT_SETTINGS.duplicate()
	var s = load_json_user(SETTINGS_PATH)
	if s is Dictionary:
		for k in s.keys():
			settings[k] = s[k]
	theme = UI.build_theme(settings)
	characters = load_json("res://data/characters.json")
	chapters = load_json("res://data/chapters.json")
	story = load_json("res://data/story.json")
	new_save("Tetamu", "guest")


# ------------------------------------------------------------------ data
func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Fail tidak dijumpai: " + path)
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(txt)
	if data is Dictionary:
		return data
	push_error("JSON rosak: " + path)
	return {}


func load_json_user(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func write_json_user(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func zone_data(id: String) -> Dictionary:
	if not _zone_cache.has(id):
		_zone_cache[id] = load_json("res://data/zon_%s.json" % id)
	return _zone_cache[id]


func lines(key: String) -> Array:
	var l = story.get(key, [])
	return l if l is Array else []


func char_name(id: String) -> String:
	return str(characters.get(id, {}).get("name", id))


func portrait_path(id: String, expr: String = "") -> String:
	var c: Dictionary = characters.get(id, {})
	var base: String = str(c.get("portrait", ""))
	if base == "":
		return ""
	if base.ends_with("_"):
		var e := expr if expr != "" else str(c.get("default_expr", "neutral"))
		var p := "res://assets/portraits/%s%s.png" % [base, e]
		if ResourceLoader.exists(p):
			return p
		return "res://assets/portraits/%s%s.png" % [base, c.get("default_expr", "neutral")]
	return "res://assets/portraits/%s.png" % base


func sprite_path(id: String) -> String:
	return "res://assets/sprites/%s.png" % id


# ------------------------------------------------------------------ settings
func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	write_json_user(SETTINGS_PATH, settings)
	UI.apply_settings(theme, settings)
	AudioServer.set_bus_mute(0, bool(settings.get("muted", false)))
	settings_changed.emit()


func type_speed() -> float:
	## characters per second; 0 = instant
	return [28.0, 55.0, 0.0][clampi(int(settings.get("text_speed", 1)), 0, 2)]


# ------------------------------------------------------------------ save / profile
func new_save(username: String, mode: String, role: String = "student", avatar: String = "pelajar_1", email: String = "") -> void:
	save = {
		"version": 1,
		"profile": {"username": username, "mode": mode, "role": role, "avatar": avatar, "email": email},
		"level": 1, "exp": 0, "coins": 0,
		"prolog_done": false,
		"zones": {},
		"chapters_done": [],
		"artifacts": [],
		"figures": [],
		"hint_log": {},
		"seen": [],
		"map_pos": [],
		"reflection": "",
	}


func save_path_for(username: String) -> String:
	var safe := username.to_lower().validate_filename().replace(" ", "_")
	return "user://simpan_%s.json" % safe


func load_profile(username: String, mode: String, role: String = "student", avatar: String = "pelajar_1", email: String = "") -> void:
	var data = load_json_user(save_path_for(username))
	if data is Dictionary and data.has("profile"):
		save = data
		save["profile"]["mode"] = mode
		if email != "":
			save["profile"]["email"] = email
	else:
		new_save(username, mode, role, avatar, email)
	persist()


func persist() -> void:
	write_json_user(save_path_for(str(save["profile"]["username"])), save)
	Backend.push_progress(save)


func reset_progress() -> void:
	var p: Dictionary = save["profile"]
	new_save(str(p["username"]), str(p["mode"]), str(p["role"]), str(p["avatar"]), str(p.get("email", "")))
	persist()
	stats_changed.emit()


# ------------------------------------------------------------------ progression (Module 5)
func level_for(exp_total: int) -> int:
	return 1 + exp_total / EXP_PER_LEVEL


func add_reward(exp_gain: int, coin_gain: int) -> bool:
	## returns true when the player levels up
	var before := int(save["level"])
	save["exp"] = int(save["exp"]) + exp_gain
	save["coins"] = int(save["coins"]) + coin_gain
	save["level"] = level_for(int(save["exp"]))
	stats_changed.emit()
	return int(save["level"]) > before


func zone_state(id: String) -> Dictionary:
	if not save["zones"].has(id):
		save["zones"][id] = {"done": false, "steps": [], "first_try": 0, "retries": 0, "hints": 0, "total": 0}
	return save["zones"][id]


func zone_done(id: String) -> bool:
	return bool(zone_state(id).get("done", false))


func zone_unlocked(id: String) -> bool:
	var i := ZONES.find(id)
	if i <= 0:
		return true
	return zone_done(ZONES[i - 1])


func next_zone() -> String:
	for z in ZONES:
		if not zone_done(z):
			return z
	return ""


func chapter_done(no: int) -> bool:
	return save["chapters_done"].has(no)


func add_figure(id: String) -> void:
	if characters.get(id, {}).get("tokoh", false) and not save["figures"].has(id):
		save["figures"].append(id)


func add_artifact(id: String) -> void:
	if not save["artifacts"].has(id):
		save["artifacts"].append(id)


func log_hint(puzzle_id: String, tier: int) -> void:
	## anonymous count of Pau hint use, for teachers (no personal data)
	var hl: Dictionary = save["hint_log"]
	if not hl.has(puzzle_id):
		hl[puzzle_id] = {"1": 0, "2": 0, "3": 0}
	hl[puzzle_id][str(tier)] = int(hl[puzzle_id].get(str(tier), 0)) + 1
	Backend.log_hint(puzzle_id, tier)


func mastery_percent(zone_id: String) -> float:
	var z := zone_state(zone_id)
	var total := int(z.get("total", 0))
	if total == 0:
		return 0.0
	return 100.0 * float(z.get("first_try", 0)) / float(total)


# ------------------------------------------------------------------ navigation
func goto(screen: String, params: Dictionary = {}) -> void:
	if main and main.has_method("show_screen"):
		main.show_screen(screen, params)


func lock_input() -> void:
	input_lock += 1


func unlock_input() -> void:
	input_lock = max(0, input_lock - 1)


func is_locked() -> bool:
	return input_lock > 0


func toast(text: String, color: Color = UI.GOLD) -> void:
	if main and main.has_method("toast"):
		main.toast(text, color)


func say(key_or_lines: Variant) -> void:
	## Show a dialogue (array of lines or story key) and wait for it to finish.
	if main and main.has_method("dialogue"):
		await main.dialogue(key_or_lines)


# ------------------------------------------------------------------ input
func _setup_input() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"interact": [KEY_E, KEY_SPACE, KEY_ENTER], "pau": [KEY_H], "menu": [KEY_ESCAPE],
	}
	for action in map.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
