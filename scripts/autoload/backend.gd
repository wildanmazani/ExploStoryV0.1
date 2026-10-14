extends Node
## Backend (autoload "Backend") for Module 1 (accounts) and cloud sync.
##
## Online: Supabase (Auth + PostgREST). Fill res://config/backend.json or let
## CI write it from the SUPABASE_URL / SUPABASE_ANON_KEY secrets.
## Offline (no config): accounts are kept on this device only, so the game
## always works, including on itch.io without a backend.

const CONFIG_PATH := "res://config/backend.json"
const LOCAL_ACCOUNTS := "user://akaun.json"

var url: String = ""
var anon_key: String = ""
var access_token: String = ""
var user_id: String = ""
var _push_pending: bool = false
var _push_timer: Timer


func _ready() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		var cfg = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if cfg is Dictionary:
			url = str(cfg.get("supabase_url", "")).strip_edges().trim_suffix("/")
			anon_key = str(cfg.get("supabase_anon_key", "")).strip_edges()
	_push_timer = Timer.new()
	_push_timer.one_shot = true
	_push_timer.wait_time = 3.0
	_push_timer.timeout.connect(_do_push)
	add_child(_push_timer)


func is_online() -> bool:
	return url != "" and anon_key != ""


func is_signed_in() -> bool:
	return access_token != ""


func mode_text() -> String:
	if is_online():
		return "Dalam talian: kemajuan disimpan di awan."
	return "Luar talian: akaun disimpan pada peranti ini sahaja."


# ------------------------------------------------------------------ HTTP
func _headers(auth: bool = false) -> PackedStringArray:
	var h := PackedStringArray(["Content-Type: application/json", "apikey: " + anon_key])
	if auth and access_token != "":
		h.append("Authorization: Bearer " + access_token)
	else:
		h.append("Authorization: Bearer " + anon_key)
	return h


func _request(path: String, method: int, body: Variant = null, auth: bool = false, extra: PackedStringArray = PackedStringArray()) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var headers := _headers(auth)
	headers.append_array(extra)
	var payload := "" if body == null else JSON.stringify(body)
	var err := http.request(url + path, headers, method, payload)
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "data": null}
	var res: Array = await http.request_completed
	http.queue_free()
	var code: int = res[1]
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var data = null
	if text != "":
		data = JSON.parse_string(text)
	return {"ok": res[0] == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300, "code": code, "data": data}


func _err_text(r: Dictionary, fallback: String) -> String:
	if r.get("code", 0) == 0:
		return "Tiada sambungan internet. Cuba lagi atau main sebagai tetamu."
	var d = r.get("data")
	if d is Dictionary:
		var m := str(d.get("msg", d.get("error_description", d.get("message", ""))))
		if m.to_lower().contains("invalid login"):
			return "E-mel atau kata laluan tidak betul."
		if m.to_lower().contains("already registered"):
			return "E-mel ini sudah didaftarkan."
		if m != "":
			return m
	return fallback


# ------------------------------------------------------------------ accounts (FR-AUTH-02 / 03)
## Returns {"ok": bool, "error": String, "username": String, "role": String, "avatar": String, "email": String}
func sign_up(username: String, email: String, password: String, role: String, avatar: String) -> Dictionary:
	if is_online():
		var r := await _request("/auth/v1/signup", HTTPClient.METHOD_POST, {
			"email": email, "password": password,
			"data": {"username": username, "role": role, "avatar": avatar},
		})
		if not r["ok"]:
			return {"ok": false, "error": _err_text(r, "Pendaftaran gagal.")}
		var d: Dictionary = r["data"] if r["data"] is Dictionary else {}
		if d.has("access_token"):
			_take_session(d)
			return {"ok": true, "error": "", "username": username, "role": role, "avatar": avatar, "email": email}
		return {"ok": true, "error": "", "username": username, "role": role, "avatar": avatar, "email": email,
			"confirm": "Akaun dicipta. Sila sahkan e-mel anda, kemudian log masuk."}
	var accts := _local_accounts()
	var key := username.to_lower()
	if accts.has(key):
		return {"ok": false, "error": "Nama pengguna sudah digunakan pada peranti ini."}
	for a in accts.values():
		if str(a.get("email", "")).to_lower() == email.to_lower():
			return {"ok": false, "error": "E-mel ini sudah didaftarkan pada peranti ini."}
	accts[key] = {"username": username, "email": email, "hash": _hash(username, password), "role": role, "avatar": avatar}
	Game.write_json_user(LOCAL_ACCOUNTS, accts)
	return {"ok": true, "error": "", "username": username, "role": role, "avatar": avatar, "email": email}


func sign_in(login_id: String, password: String) -> Dictionary:
	if is_online():
		if not login_id.contains("@"):
			return {"ok": false, "error": "Dalam talian, sila log masuk dengan e-mel."}
		var r := await _request("/auth/v1/token?grant_type=password", HTTPClient.METHOD_POST, {"email": login_id, "password": password})
		if not r["ok"]:
			return {"ok": false, "error": _err_text(r, "Log masuk gagal.")}
		var d: Dictionary = r["data"]
		_take_session(d)
		var meta: Dictionary = d.get("user", {}).get("user_metadata", {})
		var result := {"ok": true, "error": "", "email": login_id,
			"username": str(meta.get("username", login_id.get_slice("@", 0))),
			"role": str(meta.get("role", "student")), "avatar": str(meta.get("avatar", "pelajar_1"))}
		var cloud = await pull_progress()
		if cloud is Dictionary and not cloud.is_empty():
			result["cloud_save"] = cloud
		return result
	var accts := _local_accounts()
	var found: Dictionary = {}
	for a in accts.values():
		if str(a.get("username", "")).to_lower() == login_id.to_lower() or str(a.get("email", "")).to_lower() == login_id.to_lower():
			found = a
	if found.is_empty():
		return {"ok": false, "error": "Akaun tidak dijumpai pada peranti ini. Daftar dahulu."}
	if found.get("hash", "") != _hash(str(found["username"]), password):
		return {"ok": false, "error": "Kata laluan tidak betul."}
	return {"ok": true, "error": "", "username": found["username"], "role": found.get("role", "student"),
		"avatar": found.get("avatar", "pelajar_1"), "email": found.get("email", "")}


func reset_password(email: String) -> String:
	if not is_online():
		return "Mod luar talian: kata laluan tidak boleh ditetapkan semula. Daftar akaun baharu atau main sebagai tetamu."
	var r := await _request("/auth/v1/recover", HTTPClient.METHOD_POST, {"email": email})
	if r["ok"]:
		return "Pautan tetapan semula telah dihantar ke e-mel anda."
	return _err_text(r, "Tidak dapat menghantar e-mel.")


func sign_out() -> void:
	access_token = ""
	user_id = ""


func _take_session(d: Dictionary) -> void:
	access_token = str(d.get("access_token", ""))
	user_id = str(d.get("user", {}).get("id", ""))


func _local_accounts() -> Dictionary:
	var a = Game.load_json_user(LOCAL_ACCOUNTS)
	return a if a is Dictionary else {}


func _hash(username: String, password: String) -> String:
	return ("explostory:" + username.to_lower() + ":" + password).sha256_text()


# ------------------------------------------------------------------ progress sync (FR-PROG-04)
func push_progress(_save: Dictionary) -> void:
	if not (is_online() and is_signed_in()):
		return
	_push_pending = true
	if _push_timer.is_stopped():
		_push_timer.start()


func _do_push() -> void:
	if not _push_pending:
		return
	_push_pending = false
	var s: Dictionary = Game.save
	await _request("/rest/v1/player_progress", HTTPClient.METHOD_POST, {
		"user_id": user_id,
		"current_level": int(s.get("level", 1)),
		"total_coins": int(s.get("coins", 0)),
		"total_exp": int(s.get("exp", 0)),
		"save_data": s,
	}, true, PackedStringArray(["Prefer: resolution=merge-duplicates,return=minimal"]))
	var rows: Array = []
	for z in s.get("zones", {}).keys():
		var st: Dictionary = s["zones"][z]
		if int(st.get("total", 0)) > 0:
			rows.append({"user_id": user_id, "topic_id": "t4_b1_" + str(z),
				"correct_answers": int(st.get("first_try", 0)), "incorrect_answers": int(st.get("retries", 0)),
				"mastery_percentage": Game.mastery_percent(z)})
	if rows.size() > 0:
		await _request("/rest/v1/syllabus_mastery?on_conflict=user_id,topic_id", HTTPClient.METHOD_POST, rows, true,
			PackedStringArray(["Prefer: resolution=merge-duplicates,return=minimal"]))


func pull_progress() -> Variant:
	if not (is_online() and is_signed_in()):
		return null
	var r := await _request("/rest/v1/player_progress?select=save_data&user_id=eq." + user_id, HTTPClient.METHOD_GET, null, true)
	if r["ok"] and r["data"] is Array and r["data"].size() > 0:
		return r["data"][0].get("save_data", null)
	return null


## Anonymous hint usage for teacher analytics (no user id stored).
func log_hint(puzzle_id: String, tier: int) -> void:
	if not is_online():
		return
	_request("/rest/v1/hint_usage", HTTPClient.METHOD_POST, {"puzzle_id": puzzle_id, "tier": tier}, false,
		PackedStringArray(["Prefer: return=minimal"]))
