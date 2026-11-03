extends Control
## Module 1: Log masuk (FR-AUTH-01, FR-AUTH-03) + Guest mode (UR-LO-01).

const UI = preload("res://scripts/ui/ui.gd")
const TitleBackdrop = preload("res://scripts/ui/title_backdrop.gd")

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
	bd.tint = Color(0.75, 0.78, 0.8)
	add_child(bd)
	var frame := UI.panel()
	frame.custom_minimum_size = Vector2(520, 0)
	var col := UI.vbox(12)
	var title := UI.label("LOG MASUK", "Heading")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	# signed in on this device before: one tap to carry on, or type another account below
	if Backend.has_saved_session():
		var who := Backend.saved_session_email()
		var cont := UI.button(tr("TERUSKAN SEBAGAI %s") % who if who != "" else tr("TERUSKAN AKAUN TADI"), "Primary")
		cont.pressed.connect(func():
			cont.disabled = true
			_resume())
		col.add_child(cont)
		var other := UI.label(tr("Atau log masuk dengan akaun lain:"), "Small", true)
		other.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		other.custom_minimum_size.x = 480
		col.add_child(other)

	col.add_child(UI.label("E-MEL ATAU NAMA PENGGUNA"))
	var r1 := UI.hbox(8)
	r1.add_child(UI.icon("res://assets/icons/orang.png", 40))
	_user = LineEdit.new()
	_user.placeholder_text = "cth: alif@sekolah.edu.my"
	_user.set_meta("typing_label", "E-mel atau nama pengguna")
	_user.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_user.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_user.text_changed.connect(func(_t): _validate())
	r1.add_child(_user)
	col.add_child(r1)

	col.add_child(UI.label("KATA LALUAN"))
	var r2 := UI.hbox(8)
	r2.add_child(UI.icon("res://assets/icons/kunci.png", 40))
	_pass = LineEdit.new()
	_pass.secret = true
	_pass.secret_character = "*"
	_pass.set_meta("typing_label", "Kata laluan")
	_pass.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	_pass.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pass.text_changed.connect(func(_t): _validate())
	_pass.text_submitted.connect(func(_t): _do_login())
	r2.add_child(_pass)
	col.add_child(r2)

	var forgot := LinkButton.new()
	forgot.text = "Lupa kata laluan?"
	forgot.size_flags_horizontal = Control.SIZE_SHRINK_END
	forgot.pressed.connect(_forgot)
	col.add_child(forgot)

	_status = UI.label("", "Bad", true)
	_status.custom_minimum_size.x = 480
	col.add_child(_status)

	_login = UI.button("LOG MASUK", "Primary")
	_login.disabled = true
	_login.pressed.connect(_do_login)
	col.add_child(_login)
	var reg := UI.button("DAFTAR AKAUN BAHARU")
	reg.pressed.connect(func(): Game.goto("register"))
	col.add_child(reg)
	var guest := UI.button("Main sebagai Tetamu", "Flat")
	guest.pressed.connect(_guest)
	col.add_child(guest)
	for t in [Backend.mode_text(), Backend.guest_text()]:
		var mode := UI.label(t, "Small", true)
		mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mode.custom_minimum_size.x = 480
		col.add_child(mode)
	frame.add_child(col)
	add_child(UI.center(frame))
	var logo := UI.label("EXPLO-STORY", "Logo")
	logo.position = Vector2(30, 20)
	add_child(logo)
	if not DisplayServer.is_touchscreen_available():  # a phone opens its keyboard only on a tap
		_user.grab_focus()


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
	_user.theme_type_variation = ""
	_pass.theme_type_variation = ""
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
		_user.theme_type_variation = "Invalid"
		_pass.theme_type_variation = "Invalid"
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
	if Backend.is_online() and not await Main.ask(Backend.guest_text() + "\n\n" + tr("Teruskan sebagai Tetamu?"), "Main", "Batal"):
		return
	_start_guest()


func _start_guest() -> void:
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
