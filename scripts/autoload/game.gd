extends Node
## Global game state (autoload "Game"): content data, save file, settings,
## progression (Module 5), screen navigation and the shared theme.

const UI = preload("res://scripts/ui/ui.gd")

signal settings_changed
signal stats_changed
signal skin_changed
signal pau_pressed
signal hint_requested(tier: int)

## full scenes (the explorable world and cinematic prologue)
const SCENES := {
	"title": "res://scenes/title.tscn",
	"prolog": "res://scenes/prologue.tscn",
	"peta": "res://scenes/world/world.tscn",
	"world": "res://scenes/world/world.tscn",
}
## menu-style screens from the first prototype, hosted by scenes/screen_host.tscn
const SCREENS := {
	"login": "res://scripts/screens/login.gd",
	"register": "res://scripts/screens/register.gd",
	"zone_summary": "res://scripts/screens/zone_summary.gd",
	"penutup": "res://scripts/screens/penutup.gd",
	"ujian": "res://scripts/screens/ujian_bab.gd",
	"lobby": "res://scripts/screens/lobby.gd",
	"arka": "res://scripts/screens/arka.gd",
	"gelanggang": "res://scripts/screens/gelanggang.gd",
	"pertarungan": "res://scripts/screens/pertarungan.gd",
}

## every zone of every open chapter, in play order (filled from data/chapters.json)
var ZONES: Array = []
const EXP_PER_LEVEL := 200
const SETTINGS_PATH := "user://tetapan.json"
## for Papan Markah (leaderboard by negeri)
const NEGERI := [
	"Johor", "Kedah", "Kelantan", "Melaka", "Negeri Sembilan", "Pahang", "Perak", "Perlis",
	"Pulau Pinang", "Sabah", "Sarawak", "Selangor", "Terengganu",
	"WP Kuala Lumpur", "WP Labuan", "WP Putrajaya",
]

const DEFAULT_SETTINGS := {
	"font": "lexend", "text_size": 1, "text_speed": 1, "auto_read": false,
	"muted": false, "music": 0.8, "sfx": 0.8, "voice": 0.8, "lang": "ms",
	"controls": "auto", "pad_size": 1, "pad_alpha": 0.7, "left_handed": false,
}
const I18N_PATH := "res://data/i18n/en.json"  ## BM menu text -> English

var main: Node = null
var theme: Theme
var settings: Dictionary = {}
var save: Dictionary = {}
var characters: Dictionary = {}
var chapters: Dictionary = {}
var story: Dictionary = {}
var _zone_cache: Dictionary = {}
var _skins: Array = []
var _tr_en: Translation
var input_lock: int = 0
## screen waiting to be shown by scenes/screen_host.tscn
var pending_screen: String = ""
var pending_params: Dictionary = {}
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
	_load_translations()
	characters = load_json("res://data/characters.json")
	chapters = load_json("res://data/chapters.json")
	for ch in chapter_list():
		ZONES.append_array(ch.get("zones", []))
	story = load_json("res://data/story.json")
	new_save("Tetamu", "guest")
	apply_audio.call_deferred()


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
		if id == "alif" and not save.is_empty():  # Alif talks in the outfit he wears
			var sk := "res://assets/portraits/alif_%s_%s.png" % [str(save.get("skin", "sekolah")), e]
			if ResourceLoader.exists(sk):
				return sk
		var p := "res://assets/portraits/%s%s.png" % [base, e]
		if ResourceLoader.exists(p):
			return p
		return "res://assets/portraits/%s%s.png" % [base, c.get("default_expr", "neutral")]
	var own := "res://assets/portraits/%s.png" % base
	if not ResourceLoader.exists(own) and c.has("stand_in"):  # new character, art not dropped in yet
		return "res://assets/portraits/%s.png" % str(c["stand_in"].get("portrait", base))
	return own


func sprite_path(id: String) -> String:
	return "res://assets/proto/sprites/%s.png" % id


# ------------------------------------------------------------------ settings
func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	write_json_user(SETTINGS_PATH, settings)
	UI.apply_settings(theme, settings)
	apply_audio()
	if key == "lang":
		_set_language(str(value))
	settings_changed.emit()


## Menus can be in English; history content stays in BM (see data/i18n/en.json).
func _load_translations() -> void:
	_tr_en = Translation.new()
	_tr_en.locale = "en"
	var d = JSON.parse_string(FileAccess.get_file_as_string(I18N_PATH))
	if d is Dictionary:
		for k in d:
			if not str(k).begins_with("_"):
				_tr_en.add_message(str(k), str(d[k]))
	_set_language(str(settings.get("lang", "ms")))


## The English table is only registered while English is chosen: Godot falls
## back to English for any locale without its own table, so BM would show English.
func _set_language(lang: String) -> void:
	if lang == "en":
		TranslationServer.add_translation(_tr_en)
	else:
		TranslationServer.remove_translation(_tr_en)
	TranslationServer.set_locale(lang)


func apply_audio() -> void:
	AudioServer.set_bus_mute(0, bool(settings.get("muted", false)))
	for bus in [["Music", "music"], ["SFX", "sfx"], ["Ambient", "sfx"], ["Voice", "voice"]]:
		var i := AudioServer.get_bus_index(bus[0])
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(float(settings.get(bus[1], 0.8)), 0.001)))


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
	_ensure_fields()


## Fields added after the first release; old saves get them on load.
func _ensure_fields() -> void:
	var defaults := {
		"player_id": "", "skins_owned": ["sekolah", "melayu"], "skin": "sekolah",
		"battle": {"played": 0, "wins": 0}, "ujian": [],
	}
	for k in defaults:
		if not save.has(k):
			save[k] = defaults[k].duplicate() if defaults[k] is Array or defaults[k] is Dictionary else defaults[k]
	if str(save["player_id"]) == "":
		save["player_id"] = _new_player_id()
	for k in ["display_name", "motto", "negeri"]:
		if not save["profile"].has(k):
			save["profile"][k] = save["profile"]["username"] if k == "display_name" else ""


## 6 characters, no look-alikes (0/O, 1/I) so it is easy to read out to a friend
func _new_player_id() -> String:
	const CH := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var s := ""
	for i in 6:
		s += CH[randi() % CH.length()]
	return s


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
	_ensure_fields()
	persist()


func persist() -> void:
	write_json_user(save_path_for(str(save["profile"]["username"])), save)
	Backend.push_progress(save)


func reset_progress() -> void:
	# Bab 1 starts again; the player keeps their ID, profile and bought skins
	var keep := {"profile": save["profile"], "player_id": save["player_id"], "skins_owned": save["skins_owned"], "skin": save["skin"], "battle": save["battle"]}
	var p: Dictionary = save["profile"]
	new_save(str(p["username"]), str(p["mode"]), str(p["role"]), str(p["avatar"]), str(p.get("email", "")))
	for k in keep:
		save[k] = keep[k]
	persist()


# ------------------------------------------------------------------ skins and shop
func skins() -> Array:
	if _skins.is_empty():
		_skins = load_json("res://data/skins.json").get("skins", [])
	return _skins


func skin_def(id: String) -> Dictionary:
	for s in skins():
		if str(s["id"]) == id:
			return s
	return skins()[0]


## Character folder for the equipped skin (falls back to plain Alif).
func skin_folder() -> String:
	var f := str(skin_def(str(save.get("skin", "sekolah")))["folder"])
	return f if ResourceLoader.exists("res://assets/characters32/%s/%s_south.png" % [f, f]) else "alif"


func spend(amount: int) -> bool:
	if int(save["coins"]) < amount:
		return false
	save["coins"] = int(save["coins"]) - amount
	stats_changed.emit()
	return true


## "" when bought, otherwise why not
func buy_skin(id: String) -> String:
	if save["skins_owned"].has(id):
		return "Sudah dimiliki"
	var price := int(skin_def(id)["price"])
	if not spend(price):
		return tr("Syiling tak cukup. Perlu %d lagi.") % (price - int(save["coins"]))
	save["skins_owned"].append(id)
	persist()
	return ""


func equip_skin(id: String) -> void:
	if save["skins_owned"].has(id):
		save["skin"] = id
		persist()
		skin_changed.emit()
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
	var ch := chapter_of(id)
	var list := chapter_zones(ch)
	var i := list.find(id)
	if i < 0:
		return false
	if i == 0:
		return ch <= 1 or chapter_done(ch - 1)
	return zone_done(list[i - 1])


## the mission before zid in the same chapter ("" for a chapter's first one)
func prev_zone(zid: String) -> String:
	var list := chapter_zones(chapter_of(zid))
	var i := list.find(zid)
	return list[i - 1] if i > 0 else ""


func next_zone() -> String:
	for z in ZONES:
		if not zone_done(z):
			return z
	return ""


func chapter_done(no: int) -> bool:
	return save["chapters_done"].has(no) or save["chapters_done"].has(float(no))


## every mission of the chapter is finished (its Ujian Bab may still be ahead)
func chapter_zones_done(no: int) -> bool:
	var list := chapter_zones(no)
	if list.is_empty():
		return false
	for z in list:
		if not zone_done(z):
			return false
	return true


## the Ujian Bab is waiting: missions done, chapter not closed yet
func ujian_pending(no: int) -> bool:
	return chapter_zones_done(no) and not chapter_done(no) and not ujian_def(no).is_empty()


var _ujian := {}


func ujian_def(no: int) -> Dictionary:
	if _ujian.is_empty():
		_ujian = load_json("res://data/ujian.json")
	return _ujian.get(str(no), {})


## n random questions from the chapter's bank, answers shuffled (only_zones:
## just the questions of those missions, e.g. the ones already finished)
func ujian_questions(no: int, n: int, only_zones: Array = []) -> Array:
	var bank: Array = BattleRules.bank_of(no).duplicate(true)
	if not only_zones.is_empty():
		bank = bank.filter(func(q): return only_zones.has(str(q.get("zon", ""))))
	bank.shuffle()
	var out: Array = []
	for q in bank.slice(0, n):
		var opts: Array = q["options"]
		var right: String = opts[int(q["answer"])]
		var mixed := opts.duplicate()
		mixed.shuffle()
		out.append({"q": q["q"], "options": mixed, "answer": mixed.find(right), "explain": q.get("explain", ""), "zon": q.get("zon", "")})
	return out


## Tingkatan 4 chapters from data/chapters.json (dictionaries with no, title, zones)
func chapter_list() -> Array:
	var arcs: Array = chapters.get("arcs", [])
	return arcs[0].get("chapters", []) if arcs.size() > 0 else []


func chapter_info(no: int) -> Dictionary:
	for ch in chapter_list():
		if int(ch["no"]) == no:
			return ch
	return {}


func chapter_zones(no: int) -> Array:
	return chapter_info(no).get("zones", [])


## "2_5" -> 2
func chapter_of(zid: String) -> int:
	return int(zid.get_slice("_", 0))


## true when zid is the last mission of its chapter
func is_last_zone(zid: String) -> bool:
	var list := chapter_zones(chapter_of(zid))
	return list.size() > 0 and list[-1] == zid


## highest chapter the player may play now (1 + finished chapters in a row)
func current_chapter() -> int:
	var n := 1
	while chapter_done(n) and not chapter_zones(n + 1).is_empty():
		n += 1
	return n


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
	input_lock = 0
	if SCENES.has(screen):
		GameState.go_to(SCENES[screen])
		return
	pending_screen = screen
	pending_params = params
	GameState.go_to("res://scenes/screen_host.tscn")


func lock_input() -> void:
	input_lock += 1


func unlock_input() -> void:
	input_lock = max(0, input_lock - 1)


func is_locked() -> bool:
	return input_lock > 0


## on-screen controller for walking (Tetapan > Kawalan): "dpad", "joystick" or
## "none". Automatik = D-pad on phones/tablets, nothing on a laptop.
func touch_mode() -> String:
	var m := str(settings.get("controls", "auto"))
	if m == "auto":
		return "dpad" if DisplayServer.is_touchscreen_available() else "none"
	return m if m in ["dpad", "joystick"] else "none"


func controls_on_screen() -> bool:
	return touch_mode() != "none"


func toast(text: String, color: Color = UI.GOLD) -> void:
	if main and main.has_method("toast"):
		main.toast(text, color)


func say(key_or_lines: Variant) -> void:
	## Show a dialogue (array of lines or story key) and wait for it to finish.
	if main and main.has_method("dialogue"):
		await main.dialogue(key_or_lines)


# ------------------------------------------------------------------ input
const DEFAULT_KEYS := {
	"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
	"interact": [KEY_E, KEY_SPACE, KEY_ENTER, KEY_Z], "pau": [KEY_H], "menu": [KEY_ESCAPE], "map": [KEY_M],
	"run": [KEY_SHIFT, KEY_X],
	# Gelanggang (brawl)
	"attack_punch": [KEY_J], "attack_kick": [KEY_K], "jump": [KEY_SPACE], "grab": [KEY_L],
	"block": [KEY_I], "special": [KEY_U],
}
## Gelanggang keyboard layouts (Jeda > Kekunci). "wasd": left hand walks,
## right hand fights. "panah": right hand on the arrows, every fight key in
## one block under the left hand (Z X C / A S D).
const BRAWL_KEYS := {
	"wasd": {
		"move_left": [KEY_A], "move_right": [KEY_D], "move_up": [KEY_W], "move_down": [KEY_S],
		"attack_punch": [KEY_J], "attack_kick": [KEY_K], "jump": [KEY_SPACE], "grab": [KEY_L],
		"block": [KEY_I], "special": [KEY_U], "run": [KEY_SHIFT],
	},
	"panah": {
		"move_left": [KEY_LEFT], "move_right": [KEY_RIGHT], "move_up": [KEY_UP], "move_down": [KEY_DOWN],
		"attack_punch": [KEY_Z], "attack_kick": [KEY_X], "jump": [KEY_C, KEY_SPACE], "grab": [KEY_A],
		"block": [KEY_S], "special": [KEY_D], "run": [KEY_SHIFT],
	},
}


func _setup_input() -> void:
	for action in DEFAULT_KEYS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		_bind(action, DEFAULT_KEYS[action])


func _bind(action: String, keys: Array) -> void:
	InputMap.action_erase_events(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


## the Gelanggang layout picked in its pause menu ("wasd" or "panah")
func brawl_scheme() -> String:
	var s := str(settings.get("brawl_keys", "wasd"))
	return s if BRAWL_KEYS.has(s) else "wasd"


## on = use the Gelanggang layout; off = back to the normal keys
func use_brawl_keys(on: bool) -> void:
	var scheme: Dictionary = BRAWL_KEYS[brawl_scheme()]
	for action in scheme:
		_bind(action, scheme[action] if on else DEFAULT_KEYS[action])


## readable key names for an action in the current Gelanggang layout
func brawl_key_names(action: String) -> String:
	var names: Array = []
	for k in BRAWL_KEYS[brawl_scheme()].get(action, []):
		names.append({KEY_SPACE: "Space", KEY_SHIFT: "Shift", KEY_LEFT: tr("Kiri"), KEY_RIGHT: tr("Kanan"), KEY_UP: tr("Atas"), KEY_DOWN: tr("Bawah")}.get(k, OS.get_keycode_string(k)))
	return " / ".join(names)
