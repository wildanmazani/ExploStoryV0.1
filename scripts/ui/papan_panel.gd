extends "res://scripts/ui/modal.gd"
## Papan Markah (leaderboard): Seluruh (everyone on the server), Negeri (your
## state, chosen in Profil) and Rakan (your friends). Ranked by total EXP,
## then battle wins. Online it asks the server (supabase/leaderboard.sql);
## offline it shows sample classmates (data/leaderboard_sample.json) with a
## clear "Contoh" banner, ranked together with your real numbers.

const TABS := ["Seluruh", "Negeri", "Rakan"]
const SCOPES := ["all", "negeri", "friends"]
const SAMPLE_PATH := "res://data/leaderboard_sample.json"

var start_tab: int = 0
var _tab: int = 0
var _tab_row: HBoxContainer
var _body: VBoxContainer
var _req := 0  ## ignores answers from an older tab when switching fast


func _init() -> void:
	title_text = "PAPAN MARKAH"
	panel_size = Vector2(1180, 660)


func _build() -> void:
	var top := UI.hbox(8)
	_tab_row = UI.hbox(8)
	for i in TABS.size():
		var b := UI.button(TABS[i], "", 170)
		b.pressed.connect(_show.bind(i))
		_tab_row.add_child(b)
	top.add_child(_tab_row)
	top.add_child(UI.spacer())
	var how := UI.label("Kedudukan ikut jumlah EXP, kemudian menang pertarungan.", "Small")
	how.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(how)
	content.add_child(top)
	_body = UI.vbox(10)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_body)
	_show(start_tab)


func _show(i: int) -> void:
	_tab = i
	_req += 1
	for j in _tab_row.get_child_count():
		(_tab_row.get_child(j) as Button).theme_type_variation = "Primary" if j == i else ""
	_clear()
	var negeri := str(Game.save["profile"].get("negeri", ""))
	if SCOPES[i] == "negeri" and negeri == "":
		_ask_negeri()
		return
	if Backend.can_play_online():
		_body.add_child(UI.label("Memuatkan...", "Small"))
		var req := _req
		var data: Dictionary = await Backend.leaderboard(SCOPES[i])
		if req != _req or not is_inside_tree():
			return
		_clear()
		if data.is_empty():
			_body.add_child(UI.label("Tak dapat sambung ke pelayan. Cuba lagi nanti.", "", true))
			return
		_fill(data.get("rows", []), data.get("me"), false)
	else:
		var rows := sample_rows(SCOPES[i])
		var me: Dictionary = {}
		for r in rows:
			if r["me"]:
				me = r
		_fill(rows, me, true)


func _clear() -> void:
	for c in _body.get_children():
		c.queue_free()


func _ask_negeri() -> void:
	var box := UI.vbox(14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var l := UI.label("Kau belum pilih negeri. Pilih dalam Profil, lepas tu tengok siapa paling hebat di negeri kau!", "", true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = 900
	box.add_child(UI.center(l))
	var b := UI.button("Pilih negeri di Profil", "Primary", 340)
	b.pressed.connect(func():
		close()
		Game.main.open_profile())
	box.add_child(UI.center(b))
	_body.add_child(box)


## Offline: sample classmates + you, ranked the same way as the server.
static func sample_rows(scope: String) -> Array:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAMPLE_PATH))
	var prof: Dictionary = Game.save["profile"]
	var negeri := str(prof.get("negeri", ""))
	var rows: Array = []
	for p in (data.get("players", []) if data is Dictionary else []):
		if scope == "negeri" and str(p["negeri"]) != negeri:
			continue
		if scope == "friends" and not p.get("friend", false):
			continue
		rows.append({"name": str(p["name"]), "skin": str(p["skin"]), "negeri": str(p["negeri"]),
			"exp": int(p["exp"]), "wins": int(p["wins"]), "me": false})
	rows.append({"name": str(prof.get("display_name", prof["username"])), "skin": Game.skin_folder(), "negeri": negeri,
		"exp": int(Game.save.get("exp", 0)), "wins": int(Game.save.get("battle", {}).get("wins", 0)), "me": true})
	rows.sort_custom(func(a, b): return a["exp"] > b["exp"] or (a["exp"] == b["exp"] and (a["wins"] > b["wins"] or (a["wins"] == b["wins"] and a["me"]))))
	var rank := 0
	for i in rows.size():
		if i == 0 or rows[i]["exp"] != rows[i - 1]["exp"] or rows[i]["wins"] != rows[i - 1]["wins"]:
			rank = i + 1
		rows[i]["rank"] = rank
	return rows


func _fill(rows: Array, me: Variant, sample: bool) -> void:
	if sample:
		var banner := UI.label("CONTOH: ini pemain contoh sebab permainan belum disambung ke pelayan. Markah kau sendiri adalah betul.", "Small", true)
		banner.add_theme_color_override("font_color", UI.GOLD)
		banner.custom_minimum_size.x = 1100
		_body.add_child(banner)
	if rows.is_empty():
		_body.add_child(UI.label("Belum ada pemain di sini.", ""))
		return
	var row := UI.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_podium(rows))
	var right := UI.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := UI.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for r in rows.slice(3):
		list.add_child(_row(r))
	if rows.size() <= 3:
		list.add_child(UI.label("Itu sahaja buat masa ni. Ajak kawan main!", "Small"))
	scroll.add_child(list)
	right.add_child(scroll)
	# your own place, always visible at the bottom
	if me is Dictionary and not (me as Dictionary).is_empty():
		var mine := _row(me)
		right.add_child(mine)
	row.add_child(right)
	_body.add_child(row)


## top 3 on a podium: 2nd | 1st | 3rd, with their heads big
func _podium(rows: Array) -> Control:
	var p := UI.hbox(8)
	p.alignment = BoxContainer.ALIGNMENT_CENTER
	p.custom_minimum_size = Vector2(450, 0)
	var order := [1, 0, 2]
	var heights := {0: 150.0, 1: 110.0, 2: 80.0}
	var colors := {0: UI.GOLD, 1: Color("c9d3dc"), 2: Color("d49a6a")}
	for i in order:
		if i >= rows.size():
			continue
		var r: Dictionary = rows[i]
		var col := UI.vbox(4)
		col.alignment = BoxContainer.ALIGNMENT_END
		col.custom_minimum_size.x = 140
		if i == 0:
			col.add_child(UI.center(UI.icon("res://assets/icons/mahkota.png", 44)))
		var head := UI.panel("Slot")
		head.add_child(UI.head_icon(str(r["skin"]), 96 if i == 0 else 80))
		col.add_child(UI.center(head))
		var n := UI.label(str(r["name"]), "Heading")  # you = gold name
		n.add_theme_font_size_override("font_size", 22)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.clip_text = true
		n.custom_minimum_size.x = 140
		if r.get("me", false):
			n.add_theme_color_override("font_color", UI.GOLD)
		col.add_child(n)
		var e := UI.label("%d EXP" % int(r["exp"]), "Small")
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(e)
		var block := PanelContainer.new()
		block.add_theme_stylebox_override("panel", UI.sb(Color(colors[i], 0.85), Color(colors[i]).darkened(0.4), 3, 6, 4))
		block.custom_minimum_size = Vector2(130, heights[i])
		var num := UI.label("%d" % int(r["rank"]), "Title")
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.add_theme_color_override("font_color", Color(0.17, 0.11, 0.06))
		block.add_child(num)
		col.add_child(UI.center(block))
		p.add_child(col)
	return p


func _row(r: Dictionary) -> Control:
	var me: bool = r.get("me", false)
	var panel := UI.panel("SlotGood" if me else "Slot")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UI.hbox(12)
	var rank := UI.label("#%d" % int(r["rank"]), "Heading")
	rank.custom_minimum_size.x = 70
	h.add_child(rank)
	h.add_child(UI.head_icon(str(r["skin"]), 48))
	var nc := UI.vbox(0)
	nc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UI.label(str(r["name"]) + (tr(" (kau)") if me else ""), "")
	n.clip_text = true
	if me:
		n.add_theme_color_override("font_color", UI.GOLD)
	nc.add_child(n)
	var neg := str(r.get("negeri", ""))
	nc.add_child(UI.label(neg if neg != "" else tr("(tiada negeri)"), "Small"))
	h.add_child(nc)
	var stats := UI.vbox(0)
	var lvl := UI.label(tr("Tahap %d  ·  %d EXP") % [Game.level_for(int(r["exp"])), int(r["exp"])], "")
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.add_child(lvl)
	var w := UI.label(tr("%d menang") % int(r["wins"]), "Small")
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.add_child(w)
	h.add_child(stats)
	panel.add_child(h)
	return panel
