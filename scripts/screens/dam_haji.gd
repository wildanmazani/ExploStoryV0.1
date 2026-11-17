extends "res://scripts/screens/warisan_game.gd"
## Dam Haji (Pesta Warisan): Malay draughts, against a classmate.
## An 8 x 8 board, twelve pieces (buah) a side on the dark squares; Alif's
## start at the bottom and go up.
##   a buah            one square diagonally forward; it eats (makan) by
##                     jumping forward over a rival next to it onto the empty
##                     square behind, and goes on jumping while it can
##   eating            is a must (wajib makan): when a buah can eat, only
##                     eating moves are allowed
##   the far row       the buah becomes a HAJI: any distance along a diagonal,
##                     forwards or back, eating from afar
##   the end           a side with no buah, or no move, has lost
## When the rival eats one of Alif's buah a revision question comes: answer
## right and one buah comes back to life on his home row (three times a game).
## Mouse / finger: a buah, then where it goes. Keys / controller: move the
## white cursor (arrows, WASD, D-pad, stick), then Space / Enter / A.
##
## board[row * 8 + col]: 0 empty, 1 Alif's buah, 2 his haji, -1 / -2 the rival's.

const KEYS := [["pick", "Pilih buah, petak"], ["pause", "Jeda"]]
const CELL := 58.0
const ORIGIN := Vector2(408, 126)
const RIVAL := "rakan_meiling"
const RIVAL_NAME := "Mei Ling"
const DEPTH := [1, 2, 4]      ## how far the rival thinks ahead
const CARELESS := [0.5, 0.0, 0.0]   ## how often it plays any move at all instead
const LIFELINES := 3
const STEP := 0.24            ## seconds a jump
const MAX_PLIES := 160        ## a game that will not end goes to whoever has more

var level := 1
var state := "pilih"          ## pilih, giliran (Alif picks), gerak (a buah is moving), lawan, soalan, tamat
var board: Array = []
var sel := -1
var cur := -1                 ## the square the keys / controller are on (-1: not used yet)
var legal: Array = []         ## Alif's moves this turn: {from, path, caps}
var lifelines := LIFELINES
var right := 0
var time := 0.0
var won := false
var plies := 0
var last: Array = []          ## the squares of the last move, to show it

var _board: Node2D
var _info: Label
var _life: Label
var _buah3: Array = []        ## HD-2D: the pieces as discs [node, crown]


func _ready() -> void:
	setup_game(Color("4f9a4a"))
	_board = Papan.new()
	_board.game = self
	add_child(_board)
	for who in [[RIVAL, -18.0, "idle_south"], [Game.skin_folder(), CELL * 8.0 + 74.0, "idle_north"]]:
		var s := AnimatedSprite2D.new()
		s.sprite_frames = CharacterFrames.build(who[0], false)
		s.offset = CharacterFrames.feet_offset(who[0])
		s.scale = Vector2(2.6, 2.6)
		s.position = ORIGIN + Vector2(CELL * 4.0, who[1])
		s.play(who[2])
		_board.add_child(s)
	_reset()
	var painter := Papan.new()
	painter.game = self
	painter.ground = true
	if make_stage(_board, painter, Rect2(ORIGIN - Vector2(22, 22), Vector2(CELL * 8.0 + 44.0, CELL * 8.0 + 44.0))):
		_dress_stage()

	var side := UI.panel()
	side.position = Vector2(24, 110)
	side.custom_minimum_size = Vector2(300, 0)
	var col := UI.vbox(10)
	col.add_child(UI.label("DAM HAJI", "Heading"))
	_info = UI.label("", "", true)
	_info.custom_minimum_size.x = 270
	col.add_child(_info)
	_life = UI.label("", "Small", true)
	_life.custom_minimum_size.x = 270
	col.add_child(_life)
	col.add_child(HSeparator.new())
	col.add_child(controls(KEYS))
	var rule := UI.label(tr("Boleh makan? Wajib makan.
Sampai hujung papan: HAJI."), "Small", true)
	rule.custom_minimum_size.x = 270
	col.add_child(rule)
	col.add_child(exit_button())
	side.add_child(col)
	add_child(side)
	if params.has("level"):
		_start(int(params["level"]))
	else:
		_level_card()


## HD-2D: the board lies on the ground, the buah are real discs on it
func _dress_stage() -> void:
	stage.cam_offset = Vector3(0, 26.0, 17.0)
	stage.cam_look_up = 0.0
	stage.look_at_px(ORIGIN + Vector2(CELL * 4.0 - 90.0, CELL * 4.0 + 6.0), true)
	for it in [["rumah_merah", -260, -90], ["palm", -40, -110], ["tree_rambutan", 560, -120], ["wakaf_padang", 790, -60], ["palm", 700, 380], ["gerai_buah", -330, 430]]:
		stage.prop(load("res://assets/objects/%s.png" % it[0]), ORIGIN + Vector2(it[1], it[2]), 3.0)
	var r: float = CELL * Stage.K * 0.4
	for i in 24:
		var n := Node3D.new()
		var disc := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = r * 0.92
		mesh.bottom_radius = r
		mesh.height = r * 0.5
		disc.mesh = mesh
		disc.material_override = StandardMaterial3D.new()
		disc.position.y = r * 0.25
		n.add_child(disc)
		var crown := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r * 0.5
		cm.bottom_radius = r * 0.62
		cm.height = r * 0.42
		crown.mesh = cm
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color("ffd64d")
		crown.material_override = gold
		crown.position.y = r * 0.7
		n.add_child(crown)
		stage.add_child(n)
		_buah3.append([n, crown])


func _level_card() -> void:
	state = "pilih"
	level_card("DAM HAJI", tr("Gerakkan buah kau menyerong ke depan. Lompat buah lawan untuk makan; kalau boleh makan, wajib makan. Buah yang sampai ke hujung papan menjadi HAJI dan boleh bergerak jauh.\n\nBuah kau dimakan? Jawab soalan Sejarah: betul, satu buah hidup semula di barisan belakang (tiga kali satu permainan).\n\nHabiskan buah lawan untuk menang."), _start, KEYS)


func _reset() -> void:
	board = []
	for i in 64:
		var dark: bool = (i / 8 + i % 8) % 2 == 1
		board.append((-1 if i < 24 else (1 if i >= 40 else 0)) if dark else 0)
	sel = -1
	legal = []
	last = []
	lifelines = LIFELINES
	right = 0
	time = 0.0
	plies = 0


func _start(lv: int) -> void:
	level = clampi(lv, 0, 2)
	close_card()
	_reset()
	_my_turn()


# ---------------------------------------------------------------- rules

static func _inside(r: int, c: int) -> bool:
	return r >= 0 and r < 8 and c >= 0 and c < 8


## every jump sequence of the piece at `pos`, complete ones only
static func _jumps(b: Array, pos: int, who: int, haji: bool, taken: Array, path: Array, out: Array, from: int) -> void:
	var found := false
	var dirs := [[-who, -1], [-who, 1]]
	if haji:
		dirs = [[-1, -1], [-1, 1], [1, -1], [1, 1]]
	for d in dirs:
		var r: int = pos / 8 + d[0]
		var c: int = pos % 8 + d[1]
		if haji:   # slide to the first piece on this diagonal
			while _inside(r, c) and (b[r * 8 + c] == 0 or r * 8 + c == from):
				r += d[0]
				c += d[1]
		if not _inside(r, c):
			continue
		var over := r * 8 + c
		if signi(b[over]) != -who or taken.has(over):
			continue
		r += d[0]
		c += d[1]
		while _inside(r, c) and (b[r * 8 + c] == 0 or r * 8 + c == from):
			found = true
			_jumps(b, r * 8 + c, who, haji, taken + [over], path + [r * 8 + c], out, from)
			if not haji:
				break
			r += d[0]
			c += d[1]
	if not found and not taken.is_empty():
		out.append({"from": from, "path": path, "caps": taken})


## the legal moves of `who` (1 Alif, -1 the rival): the eating ones only, when there are any
static func moves(b: Array, who: int) -> Array:
	var eat: Array = []
	var plain: Array = []
	for i in 64:
		if signi(b[i]) != who:
			continue
		var haji: bool = absi(b[i]) == 2
		_jumps(b, i, who, haji, [], [], eat, i)
		var dirs := [[-who, -1], [-who, 1]]
		if haji:
			dirs = [[-1, -1], [-1, 1], [1, -1], [1, 1]]
		for d in dirs:
			var r: int = i / 8 + d[0]
			var c: int = i % 8 + d[1]
			while _inside(r, c) and b[r * 8 + c] == 0:
				plain.append({"from": i, "path": [r * 8 + c], "caps": []})
				if not haji:
					break
				r += d[0]
				c += d[1]
	return eat if not eat.is_empty() else plain


static func played(b0: Array, m: Dictionary) -> Array:
	var b := b0.duplicate()
	var to: int = m["path"][-1]
	var piece: int = b[m["from"]]
	b[m["from"]] = 0
	for c in m["caps"]:
		b[c] = 0
	if (piece == 1 and to / 8 == 0) or (piece == -1 and to / 8 == 7):
		piece *= 2   # haji
	b[to] = piece
	return b


## how good the board is for the rival
static func _value(b: Array) -> float:
	var v := 0.0
	for i in 64:
		match b[i]:
			-1: v += 1.0 + 0.04 * (i / 8)
			-2: v += 2.6
			1: v -= 1.0 + 0.04 * (7 - i / 8)
			2: v -= 2.6
	return v


static func _search(b: Array, who: int, depth: int, alpha: float, beta: float) -> float:
	var ms := moves(b, who)
	if ms.is_empty():
		return 99.0 * who   # `who` cannot move: he has lost (the rival is -1, so good for him when Alif is stuck)
	if depth <= 0:
		return _value(b)
	if who == -1:
		var best := -999.0
		for m in ms:
			best = maxf(best, _search(played(b, m), 1, depth - 1, alpha, beta))
			alpha = maxf(alpha, best)
			if alpha >= beta:
				break
		return best
	var low := 999.0
	for m in ms:
		low = minf(low, _search(played(b, m), -1, depth - 1, alpha, beta))
		beta = minf(beta, low)
		if alpha >= beta:
			break
	return low


## the best move for `who`, looking `depth` plies ahead (0: any)
static func best_move(b: Array, who: int, depth: int) -> Dictionary:
	var ms := moves(b, who)
	if depth <= 0:
		return ms.pick_random()
	ms.shuffle()
	var pick: Dictionary = ms[0]
	var top := -9999.0
	for m in ms:
		var v := _search(played(b, m), -who, depth - 1, -999.0, 999.0) * -who
		if v > top:
			top = v
			pick = m
	return pick


# ---------------------------------------------------------------- turns

func count(who: int) -> int:
	var n := 0
	for v in board:
		if signi(v) == who:
			n += 1
	return n


func _my_turn() -> void:
	legal = moves(board, 1)
	sel = -1
	if legal.is_empty():
		return _finish(false, tr("Kau tiada langkah lagi."))
	if plies >= MAX_PLIES:
		return _finish(count(1) > count(-1), tr("Permainan terlalu panjang: yang lebih banyak buah menang."))
	state = "giliran"
	if _auto:   # the dev bot thinks two plies ahead
		_play.call_deferred(best_move(board, 1, 2), 1)


## a square was clicked: pick a buah, or send the picked one there
func click(cell: int) -> void:
	if state != "giliran" or cell < 0:
		return
	if sel >= 0:
		for m in legal:
			if m["from"] == sel and m["path"][-1] == cell:
				_play(m, 1)
				return
	var mine := legal.filter(func(m): return m["from"] == cell)
	if not mine.is_empty():
		sel = cell
		Sfx.play("tick", -6.0)
	elif signi(board[cell]) == 1:
		sel = -1
		Game.toast(tr("Wajib makan! Pilih buah yang boleh makan.") if not legal[0]["caps"].is_empty() else tr("Buah itu tidak boleh bergerak."), Color("e0705f"))


## the piece hops along its path; then the other side
func _play(m: Dictionary, who: int) -> void:
	state = "gerak" if who == 1 else "lawan"
	sel = -1
	plies += 1
	var at: int = m["from"]
	last = [at]
	for i in m["path"].size():
		var to: int = m["path"][i]
		board[to] = board[at]
		board[at] = 0
		if i < m["caps"].size():
			board[m["caps"][i]] = 0
			if not _auto:
				Sfx.play("thwack", -4.0)
		elif not _auto:
			Sfx.play("pop", -8.0)
		at = to
		last.append(at)
		if not _auto:
			await get_tree().create_timer(STEP).timeout
			if not is_inside_tree():
				return
	if (board[at] == 1 and at / 8 == 0) or (board[at] == -1 and at / 8 == 7):
		board[at] *= 2
		if not _auto:
			Sfx.play("chime")
			Game.toast(tr("HAJI! Buah itu kini boleh bergerak jauh."), Color("f2c14e") if who == 1 else Color("e0705f"))
	if who == 1:
		_rival_turn()
	elif not m["caps"].is_empty() and lifelines > 0 and count(1) > 0:
		state = "soalan"
		question_card(tr("BUAH DIMAKAN!"), tr("Betul! Satu buah hidup semula di barisan belakang."), "", func(ok: bool):
			if ok:
				right += 1
				_revive()
			_my_turn())
	else:
		_my_turn()


## one of Alif's buah back on the board: the emptiest spot nearest his home row
func _revive() -> void:
	for r in [7, 6, 5]:
		for c in [1, 3, 5, 7, 0, 2, 4, 6]:
			var i: int = r * 8 + c
			if (r + c) % 2 == 1 and board[i] == 0:
				board[i] = 1
				lifelines -= 1
				last = [i]
				Sfx.play("sparkle")
				return


func _rival_turn() -> void:
	state = "lawan"
	if count(-1) == 0:
		return _finish(true, "")
	var ms := moves(board, -1)
	if ms.is_empty():
		return _finish(true, "")
	if not _auto:
		await get_tree().create_timer(0.6).timeout
		if not is_inside_tree():
			return
	_play(best_move(board, -1, 0 if randf() < CARELESS[level] else DEPTH[level]), -1)


func _finish(victory: bool, why: String) -> void:
	state = "tamat"
	won = victory
	var res := WarisanRules.finish("dam", victory, level, right, time)
	var text := (why + " " if why != "" else "") + tr("%s menang kali ini. Tak apa, cuba lagi: jaga buah di tepi, dan kejar gelaran haji.") % RIVAL_NAME
	if victory:
		Sfx.play("sparkle")
		MusicDirector.stinger("st_levelup" if res["level_up"] else "st_correct")
		text = (why + " " if why != "" else "") + tr("Kau menang dengan %d buah berbaki!\n\n+%d EXP   +%d Syiling (%d soalan betul)") % [count(1), res["exp"], res["coins"], right]
	result_card(tr("MENANG!") if victory else tr("KALAH!"), text, _level_card)
	print("dam: won=%s level=%d buah=%d-%d plies=%d right=%d" % [victory, level, count(1), count(-1), plies, right])


# ---------------------------------------------------------------- input, screen

func cell_at(p: Vector2) -> int:
	var q := (p - ORIGIN) / CELL
	if q.x < 0.0 or q.y < 0.0 or q.x >= 8.0 or q.y >= 8.0:
		return -1
	return int(q.y) * 8 + int(q.x)


func centre(cell: int) -> Vector2:
	return ORIGIN + Vector2(cell % 8 + 0.5, cell / 8 + 0.5) * CELL


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cur = -1
		click(cell_at(pointer_on(_board)))
	elif state == "giliran" and not event.is_echo():
		var d := Vector2i.ZERO
		if event.is_action_pressed("move_left"): d.x = -1
		elif event.is_action_pressed("move_right"): d.x = 1
		elif event.is_action_pressed("move_up"): d.y = -1
		elif event.is_action_pressed("move_down"): d.y = 1
		if d != Vector2i.ZERO:
			if cur < 0:   # first press: start on a buah that can move
				cur = legal[0]["from"]
			else:
				cur = clampi(cur / 8 + d.y, 0, 7) * 8 + clampi(cur % 8 + d.x, 0, 7)
			Sfx.play("tick", -10.0)
		elif event.is_action_pressed("interact") and cur >= 0:
			click(cur)


func _process(delta: float) -> void:
	if state in ["giliran", "gerak", "lawan"]:
		time += delta
	_info.text = "%s\n%s: %d    %s: %d" % [
		{"giliran": tr("Giliran kau"), "gerak": tr("Giliran kau"), "lawan": tr("Giliran %s") % RIVAL_NAME}.get(state, ""),
		"Alif", count(1), RIVAL_NAME, count(-1)]
	_life.text = tr("Hidup semula: %d lagi") % lifelines
	_board.queue_redraw()
	if stage:
		var k := 0
		for i in 64:
			if board[i] == 0:
				continue
			var n: Node3D = _buah3[k][0]
			n.visible = true
			n.position = stage.to3(centre(i))
			(n.get_child(0) as MeshInstance3D).material_override.albedo_color = Color("e8b83a") if board[i] > 0 else Color("9a2e2a")
			_buah3[k][1].visible = absi(board[i]) == 2
			k += 1
		for j in range(k, _buah3.size()):
			_buah3[j][0].visible = false


## the board: its squares, what may be clicked, and (in 2D) the buah
class Papan extends Node2D:
	var game: Control
	var ground := false   ## HD-2D: the board only (the buah are 3D discs)

	func _draw() -> void:
		var o: Vector2 = game.ORIGIN
		var s: float = game.CELL
		draw_rect(Rect2(o - Vector2(22, 16), Vector2(s * 8.0 + 44.0, s * 8.0 + 44.0)), Color("3a2413"))
		draw_rect(Rect2(o - Vector2(18, 18), Vector2(s * 8.0 + 36.0, s * 8.0 + 36.0)), Color("96623a"))
		draw_rect(Rect2(o - Vector2(4, 4), Vector2(s * 8.0 + 8.0, s * 8.0 + 8.0)), Color("5a381e"))
		for i in 64:
			var at := o + Vector2(i % 8, i / 8) * s
			var dark: bool = (i / 8 + i % 8) % 2 == 1
			draw_rect(Rect2(at, Vector2(s, s)), Color("7a4a28") if dark else Color("f0dcae"))
			if game.last.has(i):
				draw_rect(Rect2(at, Vector2(s, s)), Color(1.0, 0.84, 0.3, 0.28))
		if game.state == "giliran":
			for m in game.legal:
				var c: Vector2 = game.centre(m["from"])
				draw_arc(c, s * 0.46, 0, TAU, 32, Color("ffd64d") if m["from"] == game.sel else Color(1, 0.84, 0.3, 0.55), 5.0 if m["from"] == game.sel else 3.0, true)
				if m["from"] == game.sel:
					draw_circle(game.centre(m["path"][-1]), s * 0.2, Color(0.45, 0.95, 0.5, 0.85))
					for cap in m["caps"]:
						draw_arc(game.centre(cap), s * 0.46, 0, TAU, 32, Color("ff6a5a"), 4.0, true)
		if game.cur >= 0 and game.state == "giliran":   # where the keys / controller are
			var k := o + Vector2(game.cur % 8, game.cur / 8) * s
			draw_rect(Rect2(k + Vector2(3, 3), Vector2(s - 6, s - 6)), Color.WHITE, false, 4.0)
		if ground:
			return
		for i in 64:
			var v: int = game.board[i]
			if v == 0:
				continue
			var c: Vector2 = game.centre(i)
			var body := Color("e8b83a") if v > 0 else Color("9a2e2a")
			draw_circle(c + Vector2(0, 4), s * 0.4, Color("2b1c10"))
			draw_circle(c, s * 0.4, Color("2b1c10"))
			draw_circle(c, s * 0.36, body)
			draw_arc(c, s * 0.27, 0, TAU, 28, body.darkened(0.25), 3.0, true)
			draw_arc(c, s * 0.33, PI * 1.1, PI * 1.6, 10, Color(1, 1, 1, 0.5), 3.0, true)
			if absi(v) == 2:   # haji: a gold crown
				draw_circle(c, s * 0.19, Color("2b1c10"))
				draw_circle(c, s * 0.15, Color("ffd64d"))
				draw_string(ThemeDB.fallback_font, c + Vector2(-s * 0.2, 7), "H", HORIZONTAL_ALIGNMENT_CENTER, s * 0.4, 18, Color("2b1c10"))
