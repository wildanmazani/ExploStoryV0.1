extends Control
## Gua Kabus (Ujian Bab 2): the officer stands frozen in the fog with three
## girls in white. Which one is Aisyah? The four clues of Bab 2 tell (tudung
## putih, baju kurung biru muda, kain biru, muka hitam manis). A wrong pick:
## Pau reminds Alif of the clue it breaks. Emits picked when he finds her.

const UI = preload("res://scripts/ui/ui.gd")
const AisyahLook = preload("res://scripts/ui/aisyah_look.gd")

signal picked

## the right one first; the order on screen is shuffled
const GIRLS := [
	{"swaps": {}, "why": ""},
	{"swaps": {"tudung": Color("4a78c8"), "kain": Color("3a3a44")},
		"why": "Bukan. Klu pertama: tudung dia putih. Klu ketiga: dia pakai kain, bukan seluar."},
	{"swaps": {"baju": Color("f4f4f4"), "kulit": Color("ffe6d6")},
		"why": "Bukan. Ingat klu kedua: baju kurung biru muda. Klu keempat pula: muka hitam manis."},
]

var cards: Array[Button] = []  ## the girls' buttons, in screen order
var _busy := false


func _ready() -> void:
	UI.full(self)
	var fog := ColorRect.new()
	fog.color = Color(0.85, 0.86, 0.9, 0.35)
	UI.full(fog)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fog)
	var col := UI.vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := UI.label(tr("Yang mana Aisyah?"), "Title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.15))
	title.add_theme_constant_override("outline_size", 10)
	col.add_child(title)
	var sub := UI.label(tr("Ingat empat klu: tudung, baju, kain dan wajah."))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.15))
	sub.add_theme_constant_override("outline_size", 8)
	col.add_child(sub)
	var row := UI.hbox(28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var order := [0, 1, 2]
	order.shuffle()
	for i in order:
		var b := Button.new()
		b.custom_minimum_size = Vector2(220, 260)
		b.icon = AisyahLook.texture(AisyahLook.PARTS, GIRLS[i]["swaps"])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("girl", i)
		b.pressed.connect(_pick.bind(b))
		b.pivot_offset = b.custom_minimum_size / 2.0
		row.add_child(b)
		cards.append(b)
	col.add_child(row)
	add_child(UI.center(col))


func _pick(b: Button) -> void:
	if _busy:
		return
	_busy = true
	var i := int(b.get_meta("girl"))
	if i == 0:
		Sfx.play("chime")
		var t := create_tween()
		t.tween_property(b, "scale", Vector2(1.12, 1.12), 0.15).set_trans(Tween.TRANS_BACK)
		t.tween_interval(0.6)
		await t.finished
		picked.emit()
		return
	Sfx.play("bump", -4.0)
	var x := b.position.x
	var s := create_tween()
	for k in 3:
		s.tween_property(b, "position:x", x - 8, 0.05)
		s.tween_property(b, "position:x", x + 8, 0.05)
	s.tween_property(b, "position:x", x, 0.05)
	b.disabled = true
	b.modulate = Color(1, 1, 1, 0.45)
	await Game.say([{"s": "pau", "e": "scared", "t": tr(str(GIRLS[i]["why"]))}])
	_busy = false
