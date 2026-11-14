extends "res://scripts/ui/modal.gd"
## Kempen Syiling (until 16 Nov 2026, 12:00 tengah malam):
##   Beri maklum balas (bintang + komen) = +150 syiling, for a registered,
##   e-mail-confirmed account that has played one battle (Gelanggang or
##   Bilik Pertarungan, with friends or bots).
##   Kongsi pautan game = +100 syiling, for a registered account.
## Once per account: the server keeps the claims (supabase/patch_kempen.sql).

const Star = preload("res://scripts/ui/kotak_bintang.gd").Star
const GOLD := Color("f0c24a")

var stars := 0
var _stars: Array = []
var _comment: LineEdit
var _send: Button
var _share: Button
var _left: Label
var _fb_msg: Label
var _sh_msg: Label
var _busy := false


func _init() -> void:
	title_text = "KEMPEN SYILING"
	panel_size = Vector2(1000, 600)


func _build() -> void:
	var top := UI.hbox(12)
	var sub := UI.label("Kumpul syiling percuma sebelum kempen tamat!", "", true)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sub)
	_left = UI.label("", "Small")
	_left.add_theme_color_override("font_color", GOLD)
	top.add_child(_left)
	content.add_child(top)
	var row := UI.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_feedback_card())
	row.add_child(_share_card())
	content.add_child(row)
	if not Backend.can_play_online():
		var note := UI.label("Daftar akaun dan log masuk (dalam talian) untuk sertai kempen. Tetamu tak layak.", "Small", true)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.add_theme_color_override("font_color", Color("ff9a8a"))
		content.add_child(note)
	_refresh()
	_sync()


## claims made on another device count too (no coins twice: the save has them)
func _sync() -> void:
	if not Backend.can_play_online():
		return
	for k in await Backend.kempen_status():
		Game.kempen_mark(str(k), false)
	if is_instance_valid(self) and not is_queued_for_deletion():
		_refresh()


func _process(_delta: float) -> void:
	var s := int(Game.KEMPEN_ENDS - Time.get_unix_time_from_system())
	_left.text = tr("Tamat: 16 Nov, 12:00 tengah malam") + ("   (%s)" % _countdown(s) if s > 0 else "")


func _countdown(s: int) -> String:
	if s >= 86400:
		return tr("%d hari %d jam lagi") % [s / 86400, (s % 86400) / 3600]
	if s >= 3600:
		return tr("%d jam %d minit lagi") % [s / 3600, (s % 3600) / 60]
	return tr("%d minit lagi") % maxi(1, s / 60)


func _card(title: String, coins: int, main: Color) -> Array:
	var card := PanelContainer.new()
	var box := UI.sb(Color(0.13, 0.16, 0.24, 0.96), main, 3, 12, 16)
	box.shadow_color = Color(main, 0.35)
	box.shadow_size = 8
	card.add_theme_stylebox_override("panel", box)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := UI.vbox(10)
	var head := UI.hbox(10)
	var t := UI.label(title, "Heading")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var chip := PanelContainer.new()
	var cs := UI.sb(main, main.darkened(0.4), 2, 16, 6)
	cs.content_margin_left = 12
	cs.content_margin_right = 14
	chip.add_theme_stylebox_override("panel", cs)
	var cr := UI.hbox(6)
	cr.add_child(UI.icon("res://assets/icons/syiling.png", 26))
	var cl := UI.label("+%d" % coins, "Heading")
	cl.add_theme_color_override("font_color", Color("2a1c08"))
	cr.add_child(cl)
	chip.add_child(cr)
	head.add_child(chip)
	col.add_child(head)
	card.add_child(col)
	return [card, col]


## one requirement and whether it is met: SIAP (green) / BELUM (grey)
func _need(col: VBoxContainer, text: String, ok: bool) -> void:
	var r := UI.hbox(10)
	var tag := PanelContainer.new()
	var ts := UI.sb(UI.GREEN if ok else Color(0.35, 0.36, 0.42), Color(0, 0, 0, 0), 0, 6, 4)
	ts.content_margin_left = 8
	ts.content_margin_right = 8
	tag.add_theme_stylebox_override("panel", ts)
	tag.custom_minimum_size.x = 76
	var tl := UI.label(tr("SIAP") if ok else tr("BELUM"), "Small")
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_child(tl)
	r.add_child(tag)
	var l := UI.label(text, "Small", true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	col.add_child(r)


func _feedback_card() -> Control:
	var parts := _card(tr("Beri Maklum Balas"), int(Game.KEMPEN_COINS["feedback"]), GOLD)
	var col: VBoxContainer = parts[1]
	var online := Backend.can_play_online()
	_need(col, tr("Akaun berdaftar dan e-mel disahkan"), online)
	_need(col, tr("Main sekali di Gelanggang atau Bilik Pertarungan (dengan kawan atau bot)"), Game.has_battled())
	var row := UI.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 5:
		var s := Star.new()
		s.custom_minimum_size = Vector2(46, 46)
		s.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		s.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				pick(i + 1))
		_stars.append(s)
		row.add_child(s)
	col.add_child(row)
	_comment = LineEdit.new()
	_comment.placeholder_text = tr("Tulis komen (min. 10 huruf)")
	_comment.max_length = 500
	_comment.set_meta("typing_label", "Komen")
	_comment.text_changed.connect(func(_t): _refresh())
	col.add_child(_comment)
	_fb_msg = UI.label("", "Small", true)
	_fb_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_fb_msg)
	col.add_child(UI.spacer(false))
	_send = UI.button(tr("Hantar & Tuntut 150 Syiling"), "Primary")
	_send.pressed.connect(_claim_feedback)
	col.add_child(_send)
	return parts[0]


func _share_card() -> Control:
	var parts := _card(tr("Kongsi dengan Kawan"), int(Game.KEMPEN_COINS["share"]), Color("7cc4ff"))
	var col: VBoxContainer = parts[1]
	_need(col, tr("Akaun berdaftar dan e-mel disahkan"), Backend.can_play_online())
	var how := UI.label("Kongsi pautan ExploStory dengan kawan-kawan (WhatsApp, Telegram, Instagram...).", "Small", true)
	col.add_child(how)
	var link := PanelContainer.new()
	link.add_theme_stylebox_override("panel", UI.sb(Color(0.07, 0.09, 0.14), Color("7cc4ff"), 2, 8, 10))
	var ll := UI.label(Backend._site(), "")
	ll.add_theme_color_override("font_color", Color("9fd0ff"))
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ll.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	link.add_child(ll)
	col.add_child(link)
	_sh_msg = UI.label("", "Small", true)
	_sh_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_sh_msg)
	col.add_child(UI.spacer(false))
	_share = UI.button(tr("Kongsi Pautan & Tuntut 100 Syiling"), "Blue")
	_share.pressed.connect(_claim_share)
	col.add_child(_share)
	return parts[0]


func pick(n: int) -> void:
	stars = clampi(n, 1, 5)
	for i in _stars.size():
		_stars[i].on = i < stars
		_stars[i].queue_redraw()
	Sfx.play("select", -8.0, 0.9 + 0.08 * stars)
	_refresh()


func _refresh() -> void:
	var online := Backend.can_play_online()
	var open := Game.kempen_open()
	var played := Game.has_battled()
	if Game.kempen_claimed("feedback"):
		_send.disabled = true
		_send.text = tr("Dah dituntut. Terima kasih!")
		_comment.editable = false
	else:
		_send.disabled = _busy or not (open and online and played and stars > 0 and _comment.text.strip_edges().length() >= 10)
	if Game.kempen_claimed("share"):
		_share.disabled = true
		_share.text = tr("Dah dituntut. Terima kasih!")
	else:
		_share.disabled = _busy or not (open and online)


func _claim_feedback() -> void:
	_busy = true
	_refresh()
	_fb_msg.text = tr("Menghantar...")
	var r := await Backend.kempen_claim("feedback", stars, _comment.text.strip_edges())
	_busy = false
	_done(r, "feedback", _fb_msg)


func _claim_share() -> void:
	_busy = true
	_refresh()
	_share_link()
	_sh_msg.text = tr("Pautan disalin. Tampal dan hantar kepada kawan!")
	var r := await Backend.kempen_claim("share")
	_busy = false
	_done(r, "share", _sh_msg)


## the phone's share sheet when there is one, and always a copy to paste
func _share_link() -> void:
	var url := Backend._site()
	var text := tr("Jom main ExploStory, game sejarah SPM! %s") % url
	DisplayServer.clipboard_set(text)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (navigator.share) { navigator.share({title: 'ExploStory', text: %s, url: %s}).catch(function(){}); }"
			% [JSON.stringify(tr("Jom main ExploStory, game sejarah SPM!")), JSON.stringify(url)])


func _done(r: String, kind: String, msg: Label) -> void:
	if not is_instance_valid(msg):
		return
	match r:
		"ok":
			Game.kempen_mark(kind, true)
			MusicDirector.stinger("st_item")
			Game.toast(tr("+%d syiling! Terima kasih.") % int(Game.KEMPEN_COINS[kind]))
			msg.text = ""
		"already":
			Game.kempen_mark(kind, false)
			msg.text = tr("Akaun ini dah tuntut ganjaran ini.")
		"ended":
			msg.text = tr("Kempen dah tamat.")
		"unverified":
			msg.text = tr("Sahkan e-mel anda dahulu (semak peti masuk).")
		"short":
			msg.text = tr("Pilih bintang dan tulis komen sekurang-kurangnya 10 huruf.")
		_:
			msg.text = tr("Tak dapat sambung ke pelayan. Cuba lagi.")
	_refresh()
