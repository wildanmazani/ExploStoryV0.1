extends Control
## Module 1: Daftar akaun (FR-AUTH-02) with role and starting avatar.

const UI = preload("res://scripts/ui/ui.gd")

var params: Dictionary = {}
var _name: LineEdit
var _email: LineEdit
var _pass: LineEdit
var _pass2: LineEdit
var _go: Button
var _status: Label
var _avatar: String = "pelajar_1"
var _role: String = "student"
var _negeri: OptionButton


func _ready() -> void:
	UI.full(self)
	Game.main.set_pau_visible(false)
	add_child(UI.bg_image("res://assets/backgrounds/bg_skrin_tajuk.png", Color(0.75, 0.78, 0.8)))
	var frame := UI.panel()
	frame.custom_minimum_size = Vector2(640, 0)
	var col := UI.vbox(8)
	var title := UI.label("DAFTAR AKAUN", "Heading")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	_name = _field(grid, "NAMA PENGGUNA", "cth: Alif")
	_email = _field(grid, "E-MEL", "cth: alif@sekolah.edu.my")
	_pass = _field(grid, "KATA LALUAN", "sekurang-kurangnya 6 aksara")
	_pass.secret = true
	_pass.secret_character = "*"
	_pass2 = _field(grid, "SAHKAN KATA LALUAN", "")
	_pass2.secret = true
	_pass2.secret_character = "*"
	col.add_child(grid)

	# the profile picture now comes from Alif's outfit; ask for the negeri
	# instead (Papan Markah ranks by negeri too)
	var neg_row := UI.hbox(10)
	neg_row.alignment = BoxContainer.ALIGNMENT_CENTER
	neg_row.add_child(UI.label("NEGERI", "Small"))
	_negeri = OptionButton.new()
	_negeri.custom_minimum_size = Vector2(320, 48)
	_negeri.add_item(tr("(Pilih negeri)"))
	for n in Game.NEGERI:
		_negeri.add_item(n)
	neg_row.add_child(_negeri)
	col.add_child(neg_row)

	var roles := UI.hbox(30)
	roles.alignment = BoxContainer.ALIGNMENT_CENTER
	var g := ButtonGroup.new()
	var s := CheckBox.new()
	s.text = "PELAJAR"
	s.button_group = g
	s.button_pressed = true
	s.pressed.connect(func(): _role = "student")
	roles.add_child(s)
	var t := CheckBox.new()
	t.text = "GURU"
	t.button_group = g
	t.pressed.connect(func(): _role = "teacher")
	roles.add_child(t)
	col.add_child(roles)

	_status = UI.label("", "Bad", true)
	_status.custom_minimum_size.x = 600
	col.add_child(_status)
	var row := UI.hbox(12)
	var back := UI.button("« KEMBALI")
	back.pressed.connect(func(): Game.goto("login"))
	row.add_child(back)
	_go = UI.button("DAFTAR", "Primary")
	_go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_go.disabled = true
	_go.pressed.connect(_submit)
	row.add_child(_go)
	col.add_child(row)
	var mode := UI.label(Backend.mode_text(), "Small", true)
	mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(mode)
	frame.add_child(col)
	add_child(UI.center(frame))
	_name.grab_focus()


func _field(grid: GridContainer, label_text: String, ph: String) -> LineEdit:
	grid.add_child(UI.label(label_text, "Small"))
	var e := LineEdit.new()
	e.placeholder_text = ph
	e.custom_minimum_size.x = 340
	e.text_changed.connect(func(_t): _validate())
	grid.add_child(e)
	return e


func _errors() -> Dictionary:
	var e := {}
	if _name.text.strip_edges().length() < 3:
		e["name"] = "Nama pengguna sekurang-kurangnya 3 aksara."
	var em := _email.text.strip_edges()
	if not (em.contains("@") and em.contains(".") and em.length() >= 6):
		e["email"] = "Format e-mel tidak betul."
	if _pass.text.length() < 6:
		e["pass"] = "Kata laluan sekurang-kurangnya 6 aksara."
	if _pass2.text != _pass.text:
		e["pass2"] = "Kata laluan tidak sepadan."
	return e


func _validate() -> void:
	var e := _errors()
	_go.disabled = not e.is_empty()
	_name.theme_type_variation = "Invalid" if e.has("name") and _name.text != "" else ""
	_email.theme_type_variation = "Invalid" if e.has("email") and _email.text != "" else ""
	_pass.theme_type_variation = "Invalid" if e.has("pass") and _pass.text != "" else ""
	_pass2.theme_type_variation = "Invalid" if e.has("pass2") and _pass2.text != "" else ""
	var shown := ""
	for k in ["name", "email", "pass", "pass2"]:
		var le: LineEdit = {"name": _name, "email": _email, "pass": _pass, "pass2": _pass2}[k]
		if e.has(k) and le.text != "":
			shown = e[k]
			break
	_status.theme_type_variation = "Bad"
	_status.text = shown


func _submit() -> void:
	if not _errors().is_empty():
		return
	_go.disabled = true
	_status.theme_type_variation = "Small"
	_status.text = "Sedang mendaftar..."
	var r: Dictionary = await Backend.sign_up(_name.text.strip_edges(), _email.text.strip_edges(), _pass.text, _role, _avatar)
	if not r.get("ok", false):
		_status.theme_type_variation = "Bad"
		_status.text = str(r.get("error", "Pendaftaran gagal."))
		_go.disabled = false
		return
	if r.has("confirm"):
		_status.theme_type_variation = "Good"
		_status.text = str(r["confirm"])
		return
	var mode := "online" if Backend.is_online() else "local"
	Game.load_profile(str(r["username"]), mode, _role, _avatar, str(r.get("email", "")))
	if _negeri.selected > 0:
		Game.save["profile"]["negeri"] = Game.NEGERI[_negeri.selected - 1]
		Game.persist()
	Game.goto("prolog")
