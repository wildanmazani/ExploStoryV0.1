extends Control
## Gelanggang Pesta Silat: the side-view brawl screen. Each round: a question
## card (arena frozen) -> who got Semangat -> AKSI! (live fight, 10 s).
## params: {"format": "1v1"|"2v2"|"1v2"|"1v3", "level": "mudah"|"biasa"|"sukar"}
## The rules live in scripts/brawl/ (BrawlMatch, BrawlFighter, BrawlAI).

const UI = preload("res://scripts/ui/ui.gd")
const TouchControls = preload("res://scripts/ui/touch_controls.gd")
const LETTERS := ["A", "B", "C", "D"]
const BG := "res://assets/backgrounds/bg_gelanggang.png"
const BG_FALLBACK := "res://assets/backgrounds/bg_zon1_3_balai_penghadapan.png"

var params: Dictionary = {}
var match_node: BrawlMatch
var _rows := {}            ## fighter id -> {hp: ProgressBar, badge: Label, row}
var _round: Label
var _phase: Label
var _clock: Label
var _card: PanelContainer
var _q: Label
var _q_timer: ProgressBar
var _q_status: Label
var _buttons: Array[Button] = []
var _banner: PanelContainer
var _banner_box: VBoxContainer
var _hint: Label
var _big: Label
var _touch: CanvasLayer
var _result: Control


func _ready() -> void:
	UI.full(self)
	Game.main.set_pau_visible(false)
	MusicDirector.play("melaka")
	MusicDirector.puzzle(true)
	var bg := UI.bg_image(BG if ResourceLoader.exists(BG) else BG_FALLBACK, Color(1, 1, 1) if ResourceLoader.exists(BG) else Color(0.55, 0.5, 0.55))
	add_child(bg)
	add_child(Mat.new())
	match_node = BrawlMatch.new()
	match_node.setup(str(params.get("format", "1v1")), str(params.get("level", "biasa")))
	match_node.me_autopilot = bool(params.get("autopilot", false))
	add_child(match_node)
	_build_hud()
	_build_card()
	_build_banner()
	_touch = TouchControls.new()
	_touch.brawl = true
	add_child(_touch)
	match_node.phase_changed.connect(_on_phase)
	match_node.changed.connect(_refresh)
	match_node.start()


# ------------------------------------------------------------------ HUD
func _build_hud() -> void:
	var top := UI.hbox(12)
	top.position = Vector2(16, 10)
	top.size = Vector2(1248, 0)
	for t in 2:
		var panel := UI.panel()
		panel.custom_minimum_size = Vector2(430, 0)
		var col := UI.vbox(4)
		var title := UI.label("PASUKAN KAU" if t == 0 else "LAWAN", "Small")
		title.add_theme_color_override("font_color", UI.GOLD if t == 0 else Color("ff8a7a"))
		col.add_child(title)
		for f in match_node.fighters:
			if f.team != t:
				continue
			var row := UI.hbox(8)
			var head := UI.head_icon(f.skin, 34)
			row.add_child(head)
			var nm := UI.label(f.display_name + (tr(" (kau)") if f.is_me else ""), "Small")
			nm.custom_minimum_size.x = 130
			nm.clip_text = true
			row.add_child(nm)
			var hp := ProgressBar.new()
			hp.theme_type_variation = "Good"
			hp.max_value = BrawlRules.HP
			hp.value = f.hp
			hp.show_percentage = false
			hp.custom_minimum_size = Vector2(150, 16)
			hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(hp)
			var badge := UI.label("", "Small")
			badge.custom_minimum_size.x = 90
			row.add_child(badge)
			col.add_child(row)
			_rows[f.id] = {"hp": hp, "badge": badge, "row": row}
		panel.add_child(col)
		if t == 1:
			var mid := UI.vbox(0)
			mid.alignment = BoxContainer.ALIGNMENT_CENTER
			var mid_panel := UI.panel()
			mid_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mid_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			mid_panel.add_child(mid)
			_round = UI.label("", "Heading")
			_round.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mid.add_child(_round)
			_clock = UI.label("", "Title")
			_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mid.add_child(_clock)
			_phase = UI.label("", "Small")
			_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mid.add_child(_phase)
			top.add_child(mid_panel)
		top.add_child(panel)
	add_child(top)
	var out := UI.button("Keluar", "", 0)
	out.position = Vector2(1280 - 118, 194)
	out.pressed.connect(_leave)
	add_child(out)
	_hint = UI.label("", "Small", true)
	_hint.position = Vector2(20, 682)
	_hint.size = Vector2(1100, 30)
	add_child(_hint)
	_big = UI.label("", "Title")
	_big.add_theme_font_size_override("font_size", 96)
	_big.add_theme_color_override("font_color", UI.GOLD)
	_big.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.03))
	_big.add_theme_constant_override("outline_size", 14)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.position = Vector2(0, 250)
	_big.size = Vector2(1280, 130)
	_big.pivot_offset = Vector2(640, 65)
	_big.modulate.a = 0.0
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_big)


func _process(_d: float) -> void:
	if match_node == null:
		return
	var left := 0.0
	match match_node.phase:
		"soalan":
			left = BrawlRules.ASK_TIME - match_node.phase_t
			_q_timer.value = left
		"aksi":
			left = BrawlRules.FIGHT_TIME - match_node.phase_t
	_clock.text = "%d" % ceili(maxf(left, 0.0)) if match_node.phase in ["soalan", "aksi"] else ""
	_clock.add_theme_color_override("font_color", Color("ff6a5a") if match_node.phase == "aksi" and left < 3.0 else UI.GOLD)
	if _touch:
		_touch.suspended = match_node.phase != "aksi" or not match_node.me.alive()


func _refresh() -> void:
	for f in match_node.fighters:
		var r: Dictionary = _rows.get(f.id, {})
		if r.is_empty():
			continue
		var hp: ProgressBar = r["hp"]
		create_tween().tween_property(hp, "value", float(f.hp), 0.25)
		hp.theme_type_variation = "Good" if f.hp > BrawlRules.HP / 2 else ("Warn" if f.hp > BrawlRules.HP / 4 else "")
		var badge: Label = r["badge"]
		if not f.alive():
			badge.text = tr("PENGSAN")
			badge.add_theme_color_override("font_color", Color("c9a0ff"))
			(r["row"] as Control).modulate.a = 0.55
		elif match_node.phase == "soalan":
			badge.text = tr("sudah jawab") if match_node.answers.has(f.id) else ""
			badge.add_theme_color_override("font_color", Color("9fe8a0"))
		elif match_node.phase in ["keputusan", "aksi"]:
			badge.text = (tr("JURUS!") if f.special_ready else tr("SEMANGAT")) if f.answered_right else tr("LEMAH")
			badge.add_theme_color_override("font_color", UI.GOLD if f.answered_right else Color("a8b0bc"))
	_round.text = tr("Pusingan %d") % match_node.round_no
	if match_node.phase == "soalan" and match_node.answers.has(match_node.me.id):
		_q_status.text = tr("Jawapan dihantar. Menunggu yang lain...")


# ------------------------------------------------------------------ question card
func _build_card() -> void:
	_card = UI.panel("Paper")
	_card.custom_minimum_size = Vector2(1100, 0)
	var col := UI.vbox(10)
	_q_timer = ProgressBar.new()
	_q_timer.show_percentage = false
	_q_timer.max_value = BrawlRules.ASK_TIME
	_q_timer.custom_minimum_size = Vector2(0, 14)
	col.add_child(_q_timer)
	var qrow := UI.hbox(10)
	_q = UI.label("", "InkHeading", true)
	_q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qrow.add_child(_q)
	var sp := UI.icon_button("res://assets/icons/suara.png", "Blue", Vector2(60, 52))
	sp.tooltip_text = "Baca soalan"
	sp.pressed.connect(func(): Tts.speak(_q.text))
	qrow.add_child(sp)
	col.add_child(qrow)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	for i in 4:
		var b := UI.button("")
		b.custom_minimum_size = Vector2(535, 58)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_answer.bind(i))
		grid.add_child(b)
		_buttons.append(b)
	col.add_child(grid)
	_q_status = UI.label("", "InkSmall", true)
	col.add_child(_q_status)
	_card.add_child(col)
	_card.position = Vector2(90, 150)
	_card.visible = false
	add_child(_card)


func _answer(i: int) -> void:
	if match_node.phase != "soalan" or match_node.answers.has(match_node.me.id) or not match_node.me.alive():
		return
	match_node.answer(i)
	for j in _buttons.size():
		_buttons[j].disabled = true
		_buttons[j].theme_type_variation = "Blue" if j == i else ""
	Sfx.play("select")


func _unhandled_input(e: InputEvent) -> void:
	if match_node and match_node.phase == "soalan" and e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.keycode - KEY_1
		if k >= 0 and k < 4:
			_answer(k)


# ------------------------------------------------------------------ banner (who got Semangat)
func _build_banner() -> void:
	_banner = UI.panel()
	_banner.custom_minimum_size = Vector2(700, 0)
	_banner_box = UI.vbox(6)
	_banner.add_child(_banner_box)
	_banner.position = Vector2(290, 170)
	_banner.visible = false
	add_child(_banner)


func _on_phase(p: String) -> void:
	_card.visible = p == "soalan"
	_banner.visible = p == "keputusan"
	match p:
		"soalan":
			_q.text = str(match_node.q["q"])
			for i in _buttons.size():
				var b := _buttons[i]
				b.text = "%s.  %s" % [LETTERS[i], match_node.q["options"][i]]
				b.disabled = not match_node.me.alive()
				b.theme_type_variation = ""
				b.modulate = Color.WHITE
			_q_status.text = tr("Jawab betul untuk dapat SEMANGAT (serangan penuh) dan senjata sekolah!") if match_node.me.alive() else tr("Kau pengsan. Tengok rakan sepasukan berjuang!")
			_phase.text = tr("SOALAN")
			_hint.text = ""
			Sfx.play("pop", -6.0)
			if bool(Game.settings.get("auto_read", false)):
				Tts.speak(_q.text)
		"keputusan":
			for c in _banner_box.get_children():
				c.queue_free()
			var head := UI.label(tr("Jawapan: %s. %s") % [LETTERS[match_node.answer_index], match_node.q["options"][match_node.answer_index]], "Heading", true)
			_banner_box.add_child(head)
			if match_node.explain != "":
				_banner_box.add_child(UI.label(match_node.explain, "Small", true))
			for r in match_node.results:
				var txt: String = "%s%s:  %s" % [r["name"], tr(" (kau)") if r["me"] else "", tr("BETUL, SEMANGAT!") if r["right"] else tr("salah, lemah")]
				if r["fastest"]:
					txt += "  +" + tr("JURUS KILAT (tekan U)")
				var l := UI.label(txt, "")
				l.add_theme_color_override("font_color", UI.GOLD if r["right"] else Color("a8b0bc"))
				_banner_box.add_child(l)
			_phase.text = tr("KEPUTUSAN")
			if match_node.me.answered_right:
				MusicDirector.stinger("st_correct")
		"aksi":
			_phase.text = tr("AKSI!")
			_flash_big(tr("AKSI!"))
			if match_node.round_no <= 2:
				_hint.text = tr("J Tumbuk · K Sepak · J J K Kombo · Space Lompat (+K Tendang Terbang) · L Ambil/Baling · I Tangkis · U Jurus · Shift Lari")
		"tamat":
			_hint.text = ""
			_show_result()
	_refresh()


func _flash_big(text: String) -> void:
	_big.text = text
	_big.scale = Vector2(1.6, 1.6)
	_big.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(_big, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.5)
	t.tween_property(_big, "modulate:a", 0.0, 0.3)


# ------------------------------------------------------------------ result
func _show_result() -> void:
	MusicDirector.puzzle(false)
	var won := match_node.winner_team == 0
	_result = Control.new()
	UI.full(_result)
	_result.add_child(UI.dim(0.55))
	var card := UI.panel("Paper")
	card.custom_minimum_size = Vector2(640, 0)
	var c := UI.vbox(12)
	c.add_child(UI.center(UI.icon("res://assets/icons/%s.png" % ("mahkota" if won else "bendera"), 96)))
	var t := UI.label(tr("PASUKAN KAU MENANG!") if won else tr("PASUKAN LAWAN MENANG"), "InkHeading")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(t)
	var reward := "+%d EXP" % BrawlRules.REWARD_EXP + (("   +%d " % BrawlRules.REWARD_COINS) + tr("Syiling") if won else "")
	var r := UI.label(reward, "Ink")
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(r)
	var note := UI.label(tr("Syabas! Setiap soalan yang kau jawab ialah ulang kaji Bab 1.") if won else tr("Takpe, cuba lagi! Lagi banyak jawapan betul, lagi kuat serangan kau."), "InkSmall", true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(note)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var again := UI.button("Main lagi", "Primary", 200)
	again.pressed.connect(func(): Game.goto("gelanggang", params))
	row.add_child(again)
	var back := UI.button("Kembali", "", 200)
	back.pressed.connect(func(): Game.goto("lobby"))
	row.add_child(back)
	c.add_child(row)
	card.add_child(c)
	_result.add_child(UI.center(card))
	add_child(_result)
	MusicDirector.stinger("st_levelup" if won else "st_zone")
	if won:
		Game.toast("+%d Syiling" % BrawlRules.REWARD_COINS)
	_flash_big(tr("MENANG!") if won else tr("KALAH"))


func _leave() -> void:
	MusicDirector.puzzle(false)
	Engine.time_scale = 1.0
	Game.goto("lobby")


## the silat mat on the floor (a trapezoid, so the floor reads as depth)
class Mat extends Control:
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f := BrawlRules.SCREEN_FLOOR
		var top := f.position.y - 38
		var bot := f.end.y + 24
		var pts := PackedVector2Array([Vector2(f.position.x + 60, top), Vector2(f.end.x - 60, top), Vector2(f.end.x + 40, bot), Vector2(f.position.x - 40, bot)])
		draw_colored_polygon(pts, Color(0.62, 0.16, 0.14, 0.92))
		var inner := PackedVector2Array([Vector2(f.position.x + 110, top + 18), Vector2(f.end.x - 110, top + 18), Vector2(f.end.x - 20, bot - 18), Vector2(f.position.x + 20, bot - 18)])
		draw_colored_polygon(inner, Color(0.16, 0.3, 0.55, 0.95))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.95, 0.85, 0.55), 4.0)
		var mid := Vector2((f.position.x + f.end.x) / 2.0, (top + bot) / 2.0)
		draw_set_transform(mid, 0, Vector2(1, 0.32))
		draw_arc(Vector2.ZERO, 120, 0, TAU, 48, Color(0.95, 0.85, 0.55, 0.8), 4.0, true)
		draw_set_transform(Vector2.ZERO)
