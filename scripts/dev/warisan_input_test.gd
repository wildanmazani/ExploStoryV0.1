extends Node
## Dev test: the Pesta Warisan games played through real input, not the bot.
## Run:  godot --path . -- --warisan-input [--2d]
## Keys go in as input actions and events, clicks as mouse events at the place
## of the button, so this checks what a player's hands reach: moving, running,
## the step / throw / pull / kick buttons, answering a question by clicking it
## (right and wrong). Prints WARISAN INPUT PASS and quits (exit 1 on a failure).
## It saves like a real game does (a guest save).

var _fails: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _screen() -> Node:
	var host := get_tree().current_scene
	return host.get_child(host.get_child_count() - 1) if host and host.get_child_count() > 0 else null


func _open(screen: String) -> Node:
	for a in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "run"]:
		Input.action_release(a)
	Game.goto(screen, {"level": 0})
	await _wait(2.0)
	print(screen)
	return _screen()


## a key, as the event a keyboard sends (for _unhandled_input)
func _tap(action: String) -> void:
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)
		await get_tree().process_frame


func _mouse(at: Vector2, down: bool) -> void:
	get_viewport().warp_mouse(at)   # (the game asks the viewport where the mouse is)
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	await get_tree().process_frame
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)
	await get_tree().process_frame


func _click(c: Control) -> void:
	var at := c.global_position + c.size / 2.0
	await _mouse(at, true)
	await _mouse(at, false)


func _buttons(n: Node, out: Array) -> Array:
	for c in n.get_children():
		if c is Button:
			out.append(c)
		_buttons(c, out)
	return out


## answers the question card on screen by clicking: an option, then Teruskan
func _answer(game: Node, right: bool) -> void:
	await _wait(0.4)
	var q: Dictionary = game._questions[-1]
	var bs := _buttons(game._overlay, [])
	var pick := int(q["answer"])
	if not right:
		pick = (pick + 1) % q["options"].size()
	await _click(bs[pick])
	await _wait(0.4)
	await _click(bs[q["options"].size()])
	await _wait(0.4)


func _run() -> void:
	await _wait(1.0)
	# ---- Galah Panjang
	var g := await _open("galah")
	var y0: float = g.pos.y   # (a short walk: the first line is just ahead, and its guard)
	Input.action_press("ui_down")
	await _wait(0.2)
	Input.action_release("ui_down")
	_check(g.pos.y > y0 + 15.0 and g.state == "main", "down walks Alif down the court (%.0f -> %.0f)" % [y0, g.pos.y])
	var x0: float = g.pos.x
	Input.action_press("ui_left")
	await _wait(0.5)
	var walked: float = x0 - g.pos.x
	Input.action_press("run")
	x0 = g.pos.x
	await _wait(0.5)
	Input.action_release("run")
	Input.action_release("ui_left")
	_check(x0 - g.pos.x > walked * 1.3 and g.stamina < 0.9, "Shift runs faster and uses stamina (%.0f px vs %.0f, stamina %.2f)" % [x0 - g.pos.x, walked, g.stamina])
	g.pos = Vector2(60.0, g.H - g.GAP / 2.0)
	await _wait(0.2)
	x0 = g.pos.x
	await _mouse(Vector2(Game.screen_w() - 150.0, 610.0), true)
	await _wait(0.6)
	_check(g._pointer, "a click on the court reaches the game (%s, x %.0f, hover %s)" % [g.state, g.pos.x, str(get_viewport().gui_get_hovered_control())])
	await _mouse(Vector2(Game.screen_w() - 150.0, 610.0), false)
	_check(g.pos.x > x0 + 40.0, "holding the mouse walks Alif towards it (%.0f -> %.0f)" % [x0, g.pos.x])
	g._shield = 0.0
	g.pos = Vector2(g.guards[3]["x"], g.guards[3]["y"])
	await _wait(0.3)
	_check(g.state == "soalan", "a guard's touch brings a question")
	await _answer(g, false)
	_check(g.lives == g.LIVES - 1 and g.state == "main", "a wrong answer costs a life (%d left)" % g.lives)
	g._shield = 0.0
	g.pos = Vector2(g.guards[3]["x"], g.guards[3]["y"])
	await _wait(0.3)
	await _answer(g, true)
	_check(g.lives == g.LIVES - 1 and g.guards[3]["frozen"] > 0.0 and g.state == "main", "a right answer frees him and freezes the guard (lives %d, frozen %.1f, %s)" % [g.lives, g.guards[3]["frozen"], g.state])

	# ---- Tarik Upih
	var u := await _open("upih")
	await _wait(3.4)
	_check(u.state == "main", "the race starts after the count")
	for i in 10:
		await _tap("ui_left" if i % 2 == 0 else "ui_right")
		await _wait(0.27)
	_check(u.me["steps"] == 10 and u.me["x"] > 150.0 and u.me["fallen"] <= 0.0, "left, right in rhythm pulls the upih (%d steps, %.0f px)" % [u.me["steps"], u.me["x"]])
	var before: int = u.me["steps"]
	await _click(u._left)
	_check(u.me["steps"] == before + 1, "the KIRI button is a step")
	for i in 14:
		await _tap("ui_left" if i % 2 == 0 else "ui_right")
	await _wait(0.2)
	_check(u.me["fallen"] > 0.0, "hasty steps roll Pau off")

	# ---- Gasing
	var s := await _open("gasing")
	_check(s.state == "soalan", "a round opens with a question")
	await _answer(s, true)
	_check(s.state == "lilit" and s.bonus, "a right answer: the bar, with the bonus")
	await _tap("ui_accept")
	_check(s.state == "pusing" and s.me["spin"] > 0.5, "Space throws the top (spin %.2f)" % s.me["spin"])
	Input.action_press("ui_left")
	await _wait(0.5)
	Input.action_release("ui_left")
	_check(s.me["p"].x < -15.0, "left steers the top (x %.0f)" % s.me["p"].x)

	# ---- Dam Haji
	var d := await _open("dam")
	_check(d.state == "giliran" and d.legal.size() == 7, "Alif moves first, seven moves to choose from (%d)" % d.legal.size())
	var m: Dictionary = d.legal[0]
	d.click(m["from"])
	_check(d.sel == m["from"], "a click picks a buah")
	get_viewport().warp_mouse(Vector2.ZERO)
	var mine: int = d.count(1)
	d.click(m["path"][-1])
	await _wait(2.0)
	_check(d.board[m["path"][-1]] == 1 and d.board[m["from"]] == 0 and d.plies >= 2, "a second click moves it, then the rival moves")
	# set up a board where the rival must eat, and answer its question right
	for i in 64:
		d.board[i] = 0
	d.board[5 * 8 + 2] = 1
	d.board[7 * 8 + 0] = 1
	d.board[3 * 8 + 4] = -1
	d.board[0 * 8 + 7] = -1
	d.state = "giliran"
	d.legal = d.moves(d.board, 1)
	d.click(5 * 8 + 2)
	d.click(4 * 8 + 3)   # under the rival's nose: it has to eat
	await _wait(2.2)
	_check(d.state == "soalan" and d.count(1) == 1, "a buah eaten brings a question (%s, %d left)" % [d.state, d.count(1)])
	await _answer(d, true)
	_check(d.count(1) == 2 and d.lifelines == d.LIFELINES - 1, "a right answer brings a buah back (%d on the board, %d lifelines)" % [d.count(1), d.lifelines])

	# ---- Sepak Raga
	var r := await _open("raga")
	var t := 0.0
	while t < 12.0 and not (r.state == "main" and r.ball["to"] == 0 and r.ball["T"] - r.ball["t"] <= 0.06):
		await get_tree().process_frame
		t += get_process_delta_time()
	await _tap("ui_accept")
	_check(r.kicks == 1 and r.timang >= 1, "Space at the landing is a kick (%d timang)" % r.timang)
	t = 0.0
	while t < 20.0 and r.lives == r.LIVES:
		await get_tree().process_frame
		t += get_process_delta_time()
	_check(r.lives == r.LIVES - 1, "a ball nobody kicks costs a life")
	t = 0.0
	while t < 12.0 and not (r.state == "main" and r.ball["to"] == 0 and r.ball["T"] - r.ball["t"] <= 0.06):
		await get_tree().process_frame
		t += get_process_delta_time()
	before = r.kicks
	await _click(r._kick)
	_check(r.kicks == before + 1, "the SEPAK button is a kick")

	if _fails.is_empty():
		print("WARISAN INPUT PASS")
		get_tree().quit(0)
	else:
		print("WARISAN INPUT FAIL: %d  %s" % [_fails.size(), str(_fails)])
		get_tree().quit(1)
