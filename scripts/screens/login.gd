extends Control
## Module 1: Log masuk (FR-AUTH-01, FR-AUTH-03) + Guest mode (UR-LO-01).

const UI = preload("res://scripts/ui/ui.gd")

var params: Dictionary = {}
var _user: LineEdit
var _pass: LineEdit
var _login: Button
var _status: Label


func _ready() -> void:
	UI.full(self)
	Game.main.set_pau_visible(false)
	MusicDirector.play("tajuk")
	add_child(UI.bg_image("res://assets/backgrounds/bg_skrin_tajuk.png", Color(0.75, 0.78, 0.8)))
	var frame := UI.panel()
	frame.custom_minimum_size = Vector2(520, 0)
	var col := UI.vbox(12)
	var title := UI.label("LOG MASUK", "Heading")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	col.add_child(UI.label("E-MEL ATAU NAMA PENGGUNA"))
	var r1 := UI.hbox(8)
	r1.add_child(UI.icon("res://assets/icons/orang.png", 40))
	_user = LineEdit.new()
	_user.placeholder_text = "cth: alif@sekolah.edu.my"
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
	var mode := UI.label(Backend.mode_text(), "Small", true)
	mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode.custom_minimum_size.x = 480
	col.add_child(mode)
	frame.add_child(col)
	add_child(UI.center(frame))
	var logo := UI.label("EXPLO-STORY", "Title")
	logo.position = Vector2(30, 20)
	add_child(logo)
	_user.grab_focus()


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
	var mode := "online" if Backend.is_online() else "local"
	Game.load_profile(str(r["username"]), mode, str(r.get("role", "student")), str(r.get("avatar", "pelajar_1")), str(r.get("email", "")))
	if r.has("cloud_save") and r["cloud_save"] is Dictionary and r["cloud_save"].has("profile"):
		Game.save = r["cloud_save"]
	_enter_game()


func _guest() -> void:
	Game.load_profile("Tetamu", "guest")
	_enter_game()


func _enter_game() -> void:
	if bool(Game.save.get("prolog_done", false)):
		Game.goto("peta")
	else:
		Game.goto("prolog")


func _forgot() -> void:
	var e := _user.text.strip_edges()
	if not e.contains("@"):
		_status.theme_type_variation = "Small"
		_status.text = "Taip e-mel anda dahulu, kemudian ketik \"Lupa kata laluan?\"."
		return
	_status.theme_type_variation = "Small"
	_status.text = await Backend.reset_password(e)
