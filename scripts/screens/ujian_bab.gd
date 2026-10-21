extends Control
## Ujian Bab: the final test of a chapter (params.chapter). The chapter's
## boss stands between Alif and the next map. Random questions from
## data/soalan/bab<n>.json, no timer, 3 hearts; knock the boss's HP to 0 to
## pass. Passing goes on to the penutup (which marks the chapter done);
## failing offers a retry with new questions or a trip back to revise.

const UI = preload("res://scripts/ui/ui.gd")
const Objektif = preload("res://scripts/puzzles/objektif.gd")

var params: Dictionary = {}
var _ch := 1
var _cfg: Dictionary = {}
var _layer: Control
var _tries := 0


func _ready() -> void:
	UI.full(self)
	_ch = int(params.get("chapter", 1))
	_cfg = Game.ujian_def(_ch)
	Game.main.set_pau_visible(true)
	MusicDirector.play("tajuk")
	Game.context_hint = "Ujian Bab %d. Tiada had masa. Ketik aku kalau perlukan petunjuk." % _ch
	add_child(UI.bg_image(str(_cfg.get("background", "")), Color(0.45, 0.4, 0.5)))
	var root := UI.vbox(10)
	UI.full(root)
	var info := Game.chapter_info(_ch)
	root.add_child(UI.header_bar(tr("UJIAN BAB %d") % _ch, str(info.get("title", ""))))
	var mid := CenterContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := UI.vbox(10)
	var boss := TextureRect.new()
	boss.texture = UI.tex("res://assets/characters32/%s/%s_south.png" % [_cfg.get("npc", ""), _cfg.get("npc", "")])
	boss.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boss.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boss.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	boss.custom_minimum_size = Vector2(240, 240)
	col.add_child(boss)
	var bn := UI.label(str(_cfg.get("boss", "")).to_upper(), "Title")
	bn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bn.add_theme_color_override("font_color", Color("ffb0a0"))
	col.add_child(bn)
	var rule := UI.label(tr("Jawab dengan betul untuk tumbangkan dia. Kau ada 3 nyawa. Tiada had masa."), "", true)
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule.custom_minimum_size.x = 760
	col.add_child(rule)
	mid.add_child(col)
	root.add_child(mid)
	add_child(root)
	_layer = Control.new()
	UI.full(_layer)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	var t := create_tween().set_loops()
	t.tween_property(boss, "modulate", Color(1.25, 0.9, 1.1), 0.8)
	t.tween_property(boss, "modulate", Color.WHITE, 0.8)
	_start.call_deferred()


func _start() -> void:
	await get_tree().create_timer(0.4).timeout
	await Game.say(str(_cfg.get("before", "")))
	_round()


func _round() -> void:
	_tries += 1
	var def := {
		"type": "objektif",
		"title": tr("Ujian Bab %d: Lawan %s") % [_ch, _cfg.get("boss", "")],
		"instruction": tr("Setiap jawapan betul melemahkan %s. Jawapan salah = hilang satu nyawa, tapi kau akan tahu jawapan betulnya.") % _cfg.get("boss", ""),
		"boss": _cfg.get("boss", ""),
		"hearts": int(_cfg.get("hearts", 3)),
		"need": int(_cfg.get("need", 7)),
		"hint": "Baca semua pilihan dulu. Buang yang kau pasti salah.",
		"done_text": tr("%s tumbang! Bab %d kau dah kuasai.") % [_cfg.get("boss", ""), _ch],
		"questions": Game.ujian_questions(_ch, int(_cfg.get("questions", 12))),
	}
	var p := Objektif.new()
	p.theme = Game.theme
	p.set("def", def)
	p.set("puzzle_id", "ujian_%d" % _ch)
	MusicDirector.puzzle(true)
	_layer.add_child(p)
	Game.active_puzzle = p
	var stats: Dictionary = await p.completed
	Game.active_puzzle = null
	MusicDirector.puzzle(false)
	p.queue_free()
	if stats.get("passed", false):
		await _passed(stats)
	else:
		await _failed()


func _passed(stats: Dictionary) -> void:
	Sfx.play("whoosh")
	MusicDirector.stinger("st_zone")
	var ft := int(stats.get("first_try", 0))
	Game.add_reward(80 + ft * 10, 40)
	Game.toast("+%d EXP   +40 Syiling" % (80 + ft * 10))
	if not Game.save["ujian"].has(_ch):
		Game.save["ujian"].append(_ch)
	Game.persist()
	await Game.say(str(_cfg.get("win", "")))
	Game.goto("penutup", {"chapter": _ch})


func _failed() -> void:
	await Game.say(str(_cfg.get("fail", "")))
	var cover := UI.dim(0.6)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(cover)
	var card := UI.panel("Paper")
	card.custom_minimum_size = Vector2(700, 0)
	var c := UI.vbox(14)
	var t := UI.label(tr("Belum kali ini"), "InkHeading")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(t)
	var b := UI.label(tr("Tak apa. Setiap cubaan dapat soalan baru. Kau boleh cuba sekarang, atau ulang kaji Nota Alif dulu dan datang balik ke %s.") % _cfg.get("where", ""), "Ink", true)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(b)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var nota := UI.icon_button("res://assets/icons/nota.png", "", Vector2(200, 64), " NOTA")
	nota.pressed.connect(func(): Game.main.open_nota())
	row.add_child(nota)
	var back := UI.button(tr("Ulang kaji dulu"), "", 240)
	back.pressed.connect(func(): Game.goto("peta"))
	row.add_child(back)
	var again := UI.button(tr("Cuba lagi »"), "Primary", 240)
	row.add_child(again)
	c.add_child(row)
	card.add_child(c)
	var cc := UI.center(card)
	_layer.add_child(cc)
	again.grab_focus()
	await again.pressed
	cover.queue_free()
	cc.queue_free()
	_round()

