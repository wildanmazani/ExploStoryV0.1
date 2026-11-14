extends Control
## Module 1: Log masuk (FR-AUTH-01, FR-AUTH-03) + Guest mode (UR-LO-01).

const UI = preload("res://scripts/ui/ui.gd")
const TitleBackdrop = preload("res://scripts/ui/title_backdrop.gd")
const Glass = preload("res://scripts/ui/glass.gd")

var params: Dictionary = {}
var _user: LineEdit
var _pass: LineEdit
var _login: Button
var _status: Label


func _ready() -> void:
	UI.full(self)
	Game.main.set_pau_visible(false)
	MusicDirector.play("tajuk")
	var bd := TitleBackdrop.new()
	bd.tint = Color(0.86, 0.86, 0.86)
	add_child(bd)
	add_child(Glass.shade())
	add_child(Glass.logo())
	var frame := Glass.panel()
	frame.custom_minimum_size = Vector2(470, 0)
	var col := UI.vbox(10)
	var title := UI.label("Selamat kembali!", "Heading")
	Glass.text(title)
	col.add_child(title)
	var sub := UI.label("Log masuk untuk sambung kembara kau.", "Small")
	Glass.text(sub)
	col.add_child(sub)

	# signed in on this device before: one tap to carry on, or type another account below
	if Backend.has_saved_session():
		var who := Backend.saved_session_email()
		var cont := UI.button(tr("TERUSKAN SEBAGAI %s") % who if who != "" else tr("TERUSKAN AKAUN TADI"), "Primary")
		Glass.gold(cont)
		cont.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cont.pressed.connect(func():
			cont.disabled = true
			_resume())
		col.add_child(cont)
		var other := UI.label(tr("Atau log masuk dengan akaun lain:"), "Small", true)
		Glass.text(other)
		other.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		other.custom_minimum_size.x = 410
		col.add_child(other)

	col.add_child(_lab("E-MEL ATAU NAMA PENGGUNA"))
	var r1 := UI.hbox(8)
	r1.add_child(UI.icon("res://assets/icons/orang.png", 40))
	_user = LineEdit.new()
	_user.placeholder_text = "cth: alif@sekolah.edu.my"
	_user.set_meta("typing_label", "E-mel atau nama pengguna")
	_user.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_user.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_user.text_changed.connect(func(_t): _validate())
	Glass.field(_user)
	r1.add_child(_user)
	col.add_child(r1)

	col.add_child(_lab("KATA LALUAN"))
	var r2 := UI.hbox(8)
	r2.add_child(UI.icon("res://assets/icons/kunci.png", 40))
	_pass = LineEdit.new()
	_pass.secret = true
	_pass.secret_character = "*"
	_pass.set_meta("typing_label", "Kata laluan")
	_pass.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	_pass.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pass.text_changed.connect(func(_t): _validate())
	Glass.field(_pass)
	_pass.text_submitted.connect(func(_t): _do_login())
	r2.add_child(_pass)
	col.add_child(r2)

	var forgot := LinkButton.new()
	forgot.text = "Lupa kata laluan?"
	forgot.size_flags_horizontal = Control.SIZE_SHRINK_END
	forgot.pressed.connect(_forgot)
	Glass.link(forgot)
	col.add_child(forgot)

	_status = UI.label("", "Bad", true)
	_status.custom_minimum_size.x = 410
	_status.add_theme_color_override("font_shadow_color", Glass.SHADOW)
	_status.add_theme_constant_override("shadow_offset_y", 2)
	col.add_child(_status)

	_login = UI.button("LOG MASUK", "Primary")
	_login.disabled = true
	_login.pressed.connect(_do_login)
	Glass.gold(_login)
	col.add_child(_login)
	var reg := UI.button("DAFTAR AKAUN BAHARU")
	reg.pressed.connect(func(): Game.goto("register"))
	Glass.outline(reg)
	col.add_child(reg)
	var guest := UI.button("Main sebagai Tetamu", "Flat")
	guest.pressed.connect(_guest)
	Glass.link(guest)
	col.add_child(guest)
	frame.add_child(col)
	# the card on the right, the logo on the left (design "Kaca Senja")
	add_child(Glass.right(frame, 470 + 64 * 2))
	if not DisplayServer.is_touchscreen_available():  # a phone opens its keyboard only on a tap
		_user.grab_focus()
	if not Backend.recovery.is_empty():
		_show_recovery()


func _lab(t: String) -> Label:
	var l := UI.label(t, "Small")
	Glass.text(l)
	return l


## opened from the "Lupa kata laluan" e-mail: type the new password here
func _show_recovery() -> void:
	var rec: Dictionary = Backend.recovery
	if rec.has("error"):
		_status.theme_type_variation = "Bad"
		_status.text = str(rec["error"])
		Backend.recovery = {}
		return
	_user.text = str(rec.get("email", ""))
	var layer := Control.new()
	layer.name = "KataLaluanBaharu"
	UI.full(layer)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(UI.dim(0.6))
	var box := UI.panel()
	box.custom_minimum_size = Vector2(520, 0)
	var col := UI.vbox(12)
	var title := UI.label("KATA LALUAN BAHARU", "Heading")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	if str(rec.get("email", "")) != "":
		var who := UI.label(str(rec["email"]), "Small")
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(who)
	var p1 := _secret_field("Kata laluan baharu")
	var p2 := _secret_field("Taip sekali lagi")
	col.add_child(p1)
	col.add_child(p2)
	var msg := UI.label("", "Small", true)
	msg.custom_minimum_size.x = 480
	col.add_child(msg)
	var save := UI.button("TUKAR KATA LALUAN", "Primary")
	col.add_child(save)
	var cancel := UI.button("Batal", "Flat")
	cancel.pressed.connect(func():
		Backend.recovery = {}
		layer.queue_free())
	col.add_child(cancel)
	box.add_child(col)
	layer.add_child(UI.center(box))
	add_child(layer)
	save.pressed.connect(func():
		msg.theme_type_variation = "Bad"
		if p1.text.length() < 6:
			msg.text = "Kata laluan terlalu pendek. Guna sekurang-kurangnya 6 aksara."
			return
		if p1.text != p2.text:
			msg.text = "Kedua-dua kata laluan tidak sama."
			return
		save.disabled = true
		msg.theme_type_variation = "Small"
		msg.text = "Sedang menukar..."
		var err: String = await Backend.set_new_password(str(rec["token"]), p1.text)
		if err != "":
			msg.theme_type_variation = "Bad"
			msg.text = err
			save.disabled = false
			return
		layer.queue_free()
		_pass.text = ""
		_status.theme_type_variation = "Small"
		_status.text = "Kata laluan ditukar. Log masuk dengan kata laluan baharu."
		_pass.grab_focus())
	p1.grab_focus()


func _secret_field(hint: String) -> LineEdit:
	var e := LineEdit.new()
	e.secret = true
	e.secret_character = "*"
	e.placeholder_text = hint
	e.set_meta("typing_label", hint)
	e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	return e


## "Teruskan sebagai ...": back into the account kept on this device
func _resume() -> void:
	_login.disabled = true
	_status.theme_type_variation = "Small"
	_status.text = tr("Menyambung semula akaun...")
	var r: Dictionary = await Backend.restore_session()
	if r.get("ok", false):
		_finish(r)
		return
	_status.text = str(r.get("error", ""))
	_validate_keep_status()


func _validate_keep_status() -> void:
	_login.disabled = _user.text.strip_edges() == "" or _pass.text == ""


func _validate() -> void:
	_login.disabled = _user.text.strip_edges() == "" or _pass.text == ""
	Glass.mark(_user, false)
	Glass.mark(_pass, false)
	_status.text = ""


func _do_login() -> void:
	if _login.disabled:
		return
	_login.disabled = true
	_status.theme_type_variation = "Small"
	_status.text = "Sedang log masuk..."
	var r: Dictionary = await Backend.sign_in(_user.text.strip_edges(), _pass.text)
	if not r.get("ok", false):
		_status.theme_type_variation = "Bad"
		_status.text = str(r.get("error", "Log masuk gagal."))
		Glass.mark(_user, true)
		Glass.mark(_pass, true)
		_login.disabled = false
		return
	_finish(r)


func _finish(r: Dictionary) -> void:
	var mode := "online" if Backend.is_online() else "local"
	Game.load_profile(str(r["username"]), mode, str(r.get("role", "student")), str(r.get("avatar", "pelajar_1")), str(r.get("email", "")))
	# the cloud copy, unless this device played on after it (no internet then)
	var cloud = r.get("cloud_save")
	if cloud is Dictionary and cloud.has("profile") and float(cloud.get("saved_at", 0)) >= float(Game.save.get("saved_at", 0)) - 1.0:
		Game.save = cloud
		Game.save["profile"]["mode"] = mode
		Game._ensure_fields()
	Game.persist()  # the device copy, and the cloud gets the newer one
	if Backend.can_play_online():
		Backend.sync_player_code()  # friends add you by the server's Player ID
	_enter_game()


func _guest() -> void:
	if not await Main.ask("Main sebagai Tetamu: progres anda TIDAK disimpan!", "Faham, main", "Daftar akaun", true):
		Game.goto("register")
		return
	_start_guest()


## a guest always starts fresh: nothing of an earlier guest is kept
func _start_guest() -> void:
	Game.write_json_user(Game.save_path_for("Tetamu"), {})
	Game.load_profile("Tetamu", "guest")
	_enter_game()


func _enter_game() -> void:
	if bool(Game.save.get("prolog_done", false)):
		Game.goto("arka")
	else:
		Game.goto("prolog")


func _forgot() -> void:
	var e := _user.text.strip_edges()
	if not e.contains("@"):
		_status.theme_type_variation = "Small"
		_status.text = "Taip e-mel anda dahulu, kemudian klik \"Lupa kata laluan?\"."
		return
	_status.theme_type_variation = "Small"
	_status.text = await Backend.reset_password(e)
