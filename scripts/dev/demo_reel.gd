extends Node
## Gameplay demonstration, played by itself and recorded with Godot's Movie Maker.
## Run (records a video; the cursor, captions and key badges are drawn in-game):
##   godot --path . --write-movie demo.avi --fixed-fps 30 -- --demo-reel --day
## Parts (--from=<part> starts later, for quick checks):
##   masuk   log in fails (no account), sign up a new account "Alif"
##   cerita  the prologue, Alif's room and Kampung Jejak, fast-forwarded
##   ujian1  walk to the first test of Misi 1.1 and pass it
##   silat   Gelanggang Pesta Silat, 1 lwn 1 against a bot, won
##   warisan Pesta Warisan: Galah Panjang, then Gasing, then Dam Haji
##   bos     the final boss of Bab 1 (Ujian Bab 1, Panglima Derhaka)
##   maklum  the feedback after the boss: Bendera 1, Nota Alif, star rating

const UI = preload("res://scripts/ui/ui.gd")
const PARTS := ["masuk", "cerita", "ujian1", "silat", "warisan", "bos", "maklum"]

var _fast := 1.0                 ## Engine.time_scale while fast-forwarding
var _dwell := 0.0                ## seconds the current dialogue line has been fully shown
var _auto_dialogue := true
var _layer: CanvasLayer
var _cursor: Node2D
var _caption: PanelContainer
var _caption_label: Label
var _ff: PanelContainer
var _ff_label: Label
var _keys: PanelContainer
var _keys_label: Label
var _end_card: Control


# ------------------------------------------------------------------ overlay
class Cursor extends Node2D:
	var press := 0.0
	var ring := 0.0

	func _process(delta: float) -> void:
		press = maxf(0.0, press - delta * 4.0)
		ring = maxf(0.0, ring - delta * 2.2)
		queue_redraw()

	func _draw() -> void:
		if ring > 0.0:
			var r := (1.0 - ring) * 34.0 + 6.0
			draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(1, 0.85, 0.2, ring), 4.0)
		var s := 1.0 - press * 0.18
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, 26), Vector2(7, 20), Vector2(12, 31),
			Vector2(17, 29), Vector2(12, 18), Vector2(21, 18)])
		for i in pts.size():
			pts[i] *= s
		var shadow := PackedVector2Array()
		for p in pts:
			shadow.append(p + Vector2(2, 3))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
		draw_colored_polygon(pts, Color.WHITE)
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, Color.BLACK, 2.0, true)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	_run()


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 120
	add_child(_layer)
	var th: Theme = Game.theme
	_caption = PanelContainer.new()
	_caption.theme = th
	_caption.add_theme_stylebox_override("panel", UI.sb(Color(0.08, 0.07, 0.12, 0.86), UI.GOLD, 3, 14, 12))
	_caption_label = Label.new()
	_caption_label.add_theme_font_size_override("font_size", 26)
	_caption_label.add_theme_color_override("font_color", Color("ffe9a8"))
	_caption.add_child(_caption_label)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.modulate.a = 0.0
	_layer.add_child(_caption)
	_ff = PanelContainer.new()
	_ff.theme = th
	_ff.add_theme_stylebox_override("panel", UI.sb(Color(0.75, 0.15, 0.15, 0.9), Color.WHITE, 3, 12, 8))
	_ff_label = Label.new()
	_ff_label.add_theme_font_size_override("font_size", 24)
	_ff_label.add_theme_color_override("font_color", Color.WHITE)
	_ff.add_child(_ff_label)
	_ff.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ff.visible = false
	_layer.add_child(_ff)
	_keys = PanelContainer.new()
	_keys.theme = th
	_keys.add_theme_stylebox_override("panel", UI.sb(Color(0.1, 0.1, 0.14, 0.88), Color("8fd0ff"), 3, 10, 8))
	_keys_label = Label.new()
	_keys_label.add_theme_font_size_override("font_size", 24)
	_keys_label.add_theme_color_override("font_color", Color.WHITE)
	_keys.add_child(_keys_label)
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys.visible = false
	_layer.add_child(_keys)
	_cursor = Cursor.new()
	_cursor.position = Vector2(900, 600)
	_cursor.visible = false
	_layer.add_child(_cursor)


func caption(text: String) -> void:
	_caption_label.text = text
	_caption.reset_size()
	await get_tree().process_frame
	_caption.position = Vector2((Game.screen_w() - _caption.size.x) / 2.0, 672 - _caption.size.y)
	var t := create_tween()
	t.tween_property(_caption, "modulate:a", 1.0, 0.25)
	t.tween_interval(3.2)
	t.tween_property(_caption, "modulate:a", 0.0, 0.4)


func fast(scale: float) -> void:
	_fast = scale
	Engine.time_scale = scale
	_ff.visible = scale > 1.01
	_ff_label.text = ">> %dx" % int(scale)
	_ff.reset_size()
	_ff.position = Vector2(Game.screen_w() - _ff.size.x - 18, 84)


func keys(text: String) -> void:
	_keys.visible = text != ""
	_keys_label.text = text
	_keys.reset_size()
	_keys.position = Vector2(18, 640 - _keys.size.y)


# ------------------------------------------------------------------ helpers
func wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, false).timeout


func scene() -> Node:
	return get_tree().current_scene


func screen_name() -> String:
	var s := scene()
	if s == null:
		return ""
	var n := s.scene_file_path.get_file().get_basename()
	return Game.pending_screen if n == "screen_host" else n


func hosted() -> Node:
	return scene().get_child(scene().get_child_count() - 1)


func wait_screen(name: String, limit := 60.0) -> void:
	var t := 0.0
	while screen_name() != name and t < limit:
		await wait(0.1)
		t += 0.1
	if screen_name() != name:
		printerr("DEMO: screen %s never came (at %s)" % [name, screen_name()])
	await wait(0.3)


func find_button(root: Node, prefix: String) -> Button:
	if root == null:
		return null
	for c in root.get_children():
		if c is Button and (c as Button).is_visible_in_tree() and (c as Button).text.begins_with(prefix):
			return c
		var r := find_button(c, prefix)
		if r:
			return r
	return null


func wait_button(root_fn: Callable, prefix: String, limit := 30.0) -> Button:
	var t := 0.0
	while t < limit:
		var b := find_button(root_fn.call(), prefix)
		if b:
			return b
		await wait(0.1)
		t += 0.1
	printerr("DEMO: no button " + prefix)
	return null


func move_cursor(to: Vector2, dur := 0.45) -> void:
	_cursor.visible = true
	var t := create_tween()
	t.tween_property(_cursor, "position", to, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	_mouse_event(to, -1)


## a real mouse event at a screen position (down = 1, up = 0, -1 = just a move)
func _mouse_event(at: Vector2, down: int) -> void:
	get_viewport().warp_mouse(at)
	if down == -1:
		var mv := InputEventMouseMotion.new()
		mv.position = at
		mv.global_position = at
		Input.parse_input_event(mv)
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down == 1
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down == 1 else 0
	ev.position = at
	ev.global_position = at
	Input.parse_input_event(ev)


func click_at(at: Vector2, dur := 0.45) -> void:
	await move_cursor(at, dur)
	await wait(0.12)
	_cursor.press = 1.0
	_cursor.ring = 1.0
	_mouse_event(at, 1)
	await get_tree().process_frame
	await get_tree().process_frame
	_mouse_event(at, 0)
	await wait(0.15)


func click(c: Control, dur := 0.45) -> void:
	if c == null or not is_instance_valid(c):
		return
	await click_at(c.get_global_rect().get_center(), dur)


func click_button(root_fn: Callable, prefix: String, dur := 0.45) -> void:
	var b := await wait_button(root_fn, prefix)
	if b == null:
		return
	var was_pressed := [false]
	var cb := func(): was_pressed[0] = true
	b.pressed.connect(cb)
	await click(b, dur)
	if is_instance_valid(b):
		b.pressed.disconnect(cb)
		if not was_pressed[0] and b.is_visible_in_tree() and not b.disabled:
			b.pressed.emit()   # the event missed (something on top for a frame): press it anyway


func type_into(le: LineEdit, text: String, per_char := 0.06) -> void:
	await click(le)
	le.grab_focus()
	for ch in text:
		le.insert_text_at_caret(ch)
		le.text_changed.emit(le.text)
		await wait(per_char)


func press_action(action: String, hold: float) -> void:
	Input.action_press(action)
	await wait(hold)
	Input.action_release(action)


func _tap_action(action: String) -> void:
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)
		await get_tree().process_frame


## dialogue: quick taps while fast-forwarding, otherwise read at a human pace
func _process(delta: float) -> void:
	if not _auto_dialogue or not Main.dialog_box.visible:
		_dwell = 0.0
		return
	var box = Main.dialog_box
	if box._typing:
		_dwell = 0.0
		if _fast > 1.01:
			box._advance()
		return
	_dwell += delta
	var text_len: int = box._text.get_total_character_count() if box._text else 40
	var need := 0.12 if _fast > 1.01 else clampf(0.9 + text_len * 0.028, 1.4, 3.6)
	if _dwell >= need:
		_dwell = 0.0
		box._advance()


func close_preps() -> void:
	for c in Main.overlay_root().get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("zone_prep.gd") and not c.is_queued_for_deletion():
			var was := _fast
			fast(1.0)
			await wait(1.4)
			var b := find_button(c, "MULA")
			if b:
				await click_button(func(): return c, "MULA")
			elif is_instance_valid(c):
				c._close()
			fast(was)
			await wait(0.4)


func wait_idle(limit := 120.0) -> void:
	var t := 0.0
	while t < limit:
		await close_preps()
		var s := scene()
		var busy: bool = Main.dialog_box.visible or Game.is_locked()
		if s and "busy" in s and s.busy:
			busy = true
		if s and "runner" in s and s.runner.busy:
			busy = true
		if not busy:
			return
		await wait(0.1)
		t += 0.1


# ------------------------------------------------------------------ the reel
func _run() -> void:
	var from := "masuk"
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			from = a.trim_prefix("--from=")
		if a.begins_with("--part="):
			only = a.trim_prefix("--part=")
			from = only
	# a fresh device: no accounts, no saves
	var d := DirAccess.open("user://")
	if d:
		for f in d.get_files():
			if f.begins_with("simpan_") or f == "akaun.json" or f.begins_with("sesi"):
				d.remove(f)
	await wait(0.5)
	var start := PARTS.find(from)
	if start > 0:
		await wait_screen("title")
		Game.load_profile("Alif", "local")
		Game.save["prolog_done"] = true
		for s in ["beg_alif", "bilik_tutorial", "kampung_intro", "gelanggang_cara"]:
			if not Game.save["seen"].has(s):
				Game.save["seen"].append(s)
		if from == "ujian1":
			Game.goto("world")
	for i in range(maxi(0, start), PARTS.size()):
		print("DEMO part ", PARTS[i])
		await call("_part_" + PARTS[i])
		if only != "" and PARTS[i] != "masuk" and PARTS[i] != "bos":
			break
		if only == "masuk" and PARTS[i] == "cerita" or only == "bos" and PARTS[i] == "maklum":
			break
	await _the_end()
	print("DEMO DONE")
	get_tree().quit(0)


func _part_masuk() -> void:
	await wait_screen("title")
	await wait(4.5)   # the partner logos, then the title
	caption("Explo-Story  |  Demo permainan")
	await wait(2.5)
	await click_at(Vector2(640, 560))
	await wait_screen("login")
	caption("1  Log masuk / Daftar akaun")
	await wait(0.6)
	var login := hosted()
	await type_into(login._user, "Alif")
	await type_into(login._pass, "sejarah123")
	await wait(0.3)
	await click(login._login)
	await wait(2.2)   # "Akaun tidak dijumpai pada peranti ini. Daftar dahulu."
	await click_button(hosted, "DAFTAR AKAUN")
	await wait_screen("register")
	var reg := hosted()
	await type_into(reg._name, "Alif")
	await type_into(reg._email, "alif@sekolah.edu.my", 0.04)
	await type_into(reg._pass, "sejarah123")
	await type_into(reg._pass2, "sejarah123")
	await click(reg._negeri)
	await wait(0.6)
	var popup: PopupMenu = reg._negeri.get_popup()
	var idx := Game.NEGERI.find("Selangor") + 1
	if popup.visible:
		popup.hide()
	reg._negeri.select(maxi(1, idx))
	await wait(0.4)
	await click(reg._go)
	await wait(0.8)


func _part_cerita() -> void:
	await wait_screen("prologue", 30)
	caption("2  Jalan cerita (dipercepatkan)")
	_cursor.visible = false
	await wait(1.5)
	fast(10.0)
	var t := 0.0
	while screen_name() == "prologue" and t < 600.0:
		await wait(0.2)
		t += 0.2
	await wait_screen("bilik_alif", 120)
	var b := scene()
	t = 0.0
	while not b._waiting_bag and t < 300.0:
		await wait(0.2)
		t += 0.2
	fast(1.0)
	await wait(0.6)
	# Alif picks up his school bag
	b.player.place_at(Vector2i(12, 8), "north")
	keys("E  ambil beg")
	await wait(0.6)
	b._interact(Vector2i(12, 7))
	await wait(0.4)
	keys("")
	fast(10.0)
	await wait_screen("world", 120)
	var w := scene()
	t = 0.0
	while t < 300.0:
		var map: Node = null
		for c in Main.overlay_root().get_children():
			if c.get("view") != null and c.get("title_text") == "PETA BAB 1":
				map = c
		if map:
			fast(1.0)
			await wait(1.6)
			map.close()
			break
		await wait(0.2)
		t += 0.2
	fast(10.0)
	await wait_idle(120)
	fast(1.0)
	await wait(0.6)


func _part_ujian1() -> void:
	await wait_screen("world")
	await wait_idle()
	var w := scene()
	caption("3  Ujian pertama: Misi 1.1 Gerbang Masa")
	await wait(1.2)
	var step: Dictionary = Game.zone_data("1_1")["steps"][0]
	var target := _target_of(w, str(step["at"]))
	if target.x == -999:
		printerr("DEMO: no spot for the first test")
		return
	# click-to-walk there (sped up on the way)
	keys("Klik untuk berjalan")
	await click_at(Vector2(860, 300))
	keys("")
	fast(3.0)
	w._tap(target)
	var t := 0.0
	while Game.active_puzzle == null and t < 120.0:
		target = _target_of(w, str(step["at"]))   # the guide may have walked a little
		if t > 1.0 and not w._input_blocked() and not Main.dialog_box.visible and w.player._path.is_empty():
			if (w.player.cell - target).length() <= 1.01 and w.player.cell != target:
				w.player.face_cell(target)
				w._interact(target)
			else:
				w._tap(target)
		if Main.dialog_box.visible:
			fast(1.0)
		await close_preps()
		await wait(0.2)
		t += 0.2
	fast(1.0)
	await wait(1.2)
	var p = Game.active_puzzle
	if p == null:
		return
	# drag-and-match: pick each card, then its place on the time line
	var order := ["funan", "champa", "srivijaya", "melaka", "johor"]
	var by_id := {}
	for c in p.cards:
		by_id[str(c.item["id"])] = c
	for id in order:
		var c = by_id.get(id)
		if c == null:
			continue
		await click(c, 0.5)
		await wait(0.35)
		await click(p.targets[str(c.item["target"])], 0.55)
		await wait(0.9)
	t = 0.0
	while not p._finished and t < 10.0:
		await wait(0.1)
		t += 0.1
	await wait(2.0)
	var go := find_button(p, "Teruskan")
	if go:
		await click(go)
	else:
		p.completed.emit(p.stats)
	await wait(0.5)
	await wait_idle(60)
	await wait(1.0)


func _target_of(s: Node, id: String) -> Vector2i:
	if "interact" in s:
		for c in s.interact:
			if str(s.interact[c]["id"]) == id:
				return c
	if s.has_method("spot_ids") and "spots" in s and s.spots.has(id):
		var sp: Dictionary = s.spots[id]
		return Vector2i(sp["pos"][0], sp["pos"][1])
	if "npcs" in s:
		for at in s.npcs:
			if s.npcs[at].id == id:
				return at
	return Vector2i(-999, -999)


func _part_silat() -> void:
	caption("4  Berbilang pemain: Gelanggang Pesta Silat, 1 lwn 1")
	BattleRules.chapter = 1
	Game.goto("lobby")
	await wait_screen("lobby")
	await wait(1.2)
	await click_button(hosted, "1 lwn 1")
	await wait(0.3)
	await click_button(hosted, "Mudah")
	await wait(0.4)
	await click_button(hosted, "MASUK GELANGGANG")
	await wait_screen("gelanggang")
	var g := hosted()
	if g._pause:
		await wait(1.5)
		var mula := find_button(g, "Mula")
		if mula:
			await click(mula)
	var m: BrawlMatch = g.match_node
	var t := 0.0
	var answered_round := -1
	while m.phase != "tamat" and t < 240.0:
		if m.phase == "soalan" and answered_round != m.round_no and m.phase_t > 1.6:
			answered_round = m.round_no
			m.me_autopilot = false
			fast(1.0)
			await click(g._buttons[m.answer_index], 0.5)
			keys("")
		elif m.phase == "aksi":
			if not m.me_autopilot:
				keys("J tumbuk   K sepak   Space lompat   L ambil / baling")
			m.me_autopilot = true
			_cursor.visible = false
			if m.round_no >= 3 and _fast < 1.5:
				fast(2.0)
		elif m.phase == "keputusan" and m.round_no >= 3 and _fast < 1.5:
			fast(2.0)
		await wait(0.1)
		t += 0.1
	keys("")
	fast(1.0)
	await wait(3.5)
	var back := find_button(g, "Kembali")
	if back:
		await click(back)
	await wait(1.0)


func _part_warisan() -> void:
	caption("5  Pesta Warisan: permainan tradisional")
	Game.goto("pesta")
	await wait_screen("pesta")
	await wait(1.6)
	# ---- Galah Panjang
	await click_button(hosted, "MAIN")   # the first card: Galah Panjang
	await wait(1.5)
	var g := hosted()
	if g.get("state") == "pilih":
		await click_button(func(): return g, "Mudah")
	await wait(1.4)
	g = hosted()
	keys("W  maju")
	await press_action("move_up", 0.7)
	keys("A  ke kiri")
	await press_action("move_left", 0.6)
	keys("Shift + W  lari")
	Input.action_press("run")
	await press_action("move_up", 0.6)
	Input.action_release("run")
	keys("D  ke kanan")
	await press_action("move_right", 0.8)
	keys("")
	# into a guard: a question card
	var t := 0.0
	if g.state == "main" and not g.guards.is_empty():
		g._shield = 0.0
		var gd: Dictionary = g.guards[0]
		keys("W  maju")
		Input.action_press("move_up")
		while g.state == "main" and t < 4.0:
			await wait(0.1)
			t += 0.1
		Input.action_release("move_up")
		if g.state == "main":
			g.pos = Vector2(gd["x"], gd["y"])
		keys("")
	await _answer_warisan(g)
	if g.state == "main":
		keys("Shift + W  lari")
		Input.action_press("run")
		await press_action("move_up", 0.8)
		Input.action_release("run")
		keys("A  elak ke kiri")
		await press_action("move_left", 0.6)
		keys("W  maju")
		await press_action("move_up", 0.9)
		keys("D  elak ke kanan")
		await press_action("move_right", 0.7)
	keys("")
	await _answer_warisan(g)
	await wait(0.6)
	# ---- switch: Gasing
	caption("Tukar permainan: Gasing")
	Game.goto("pesta")
	await wait_screen("pesta")
	await wait(0.8)
	await _click_game_card("gasing")
	await wait(1.5)
	var s := hosted()
	if s.get("state") == "pilih":
		await click_button(func(): return s, "Mudah")
	await wait(1.2)
	await _answer_warisan(s)
	t = 0.0
	while s.state != "lilit" and t < 4.0:
		await wait(0.1)
		t += 0.1
	await wait(0.9)
	keys("Space  lempar gasing")
	await _tap_action("interact")
	await wait(0.8)
	keys("A  kemudi ke kiri")
	await press_action("move_left", 0.8)
	keys("D  kemudi ke kanan")
	await press_action("move_right", 1.0)
	keys("W  serang!")
	await press_action("move_up", 0.8)
	keys("")
	await wait(2.0)
	# ---- switch: Dam Haji
	caption("Tukar permainan: Dam Haji")
	Game.goto("pesta")
	await wait_screen("pesta")
	await wait(0.8)
	await _click_game_card("dam")
	await wait(1.5)
	var dm := hosted()
	if dm.get("state") == "pilih":
		await click_button(func(): return dm, "Mudah")
	await wait(1.2)
	for i in 3:
		t = 0.0
		while dm.state != "giliran" and t < 8.0:
			if dm.state == "soalan":
				await _answer_warisan(dm)
			await wait(0.1)
			t += 0.1
		if dm.state != "giliran" or dm.legal.is_empty():
			break
		var mv: Dictionary = dm.legal[randi() % dm.legal.size()]
		await click_at(_dam_screen_pos(dm, int(mv["from"])))
		await wait(0.3)
		await click_at(_dam_screen_pos(dm, int(mv["path"][-1])))
		await wait(1.8)
	await wait(1.0)


func _click_game_card(id: String) -> void:
	var p := hosted()
	var i := 0
	for gdef in WarisanRules.GAMES:
		if str(gdef["id"]) == id:
			break
		i += 1
	var mains: Array = []
	_collect_buttons(p, "MAIN", mains)
	if i < mains.size():
		await click(mains[i])
		await wait(0.3)
		if screen_name() == "pesta":
			mains[i].pressed.emit()
	else:
		Game.goto(id)


func _collect_buttons(n: Node, prefix: String, out: Array) -> void:
	for c in n.get_children():
		if c is Button and (c as Button).text.begins_with(prefix):
			out.append(c)
		_collect_buttons(c, prefix, out)


## the Dam Haji board cell on screen (2D: the play node; 3D: the stage camera)
func _dam_screen_pos(dm: Node, cell: int) -> Vector2:
	var local: Vector2 = dm.centre(cell)
	if dm.stage != null:
		return dm.stage._camera.unproject_position(dm.stage.to3(local))
	return dm._board.get_global_transform_with_canvas() * local


## a Pesta Warisan question card: pick the right answer, then Teruskan
func _answer_warisan(game: Node) -> void:
	var t := 0.0
	while game.get("state") != "soalan" and t < 5.0:
		await wait(0.1)
		t += 0.1
	if game.get("state") != "soalan" or game._overlay == null:
		return
	await wait(1.6)
	var q: Dictionary = game._questions[-1]
	var bs: Array = []
	_collect_all_buttons(game._overlay, bs)
	await click(bs[int(q["answer"])], 0.5)
	await wait(1.6)
	var go := find_button(game._overlay, "Teruskan") if game._overlay else null
	if go == null and game._overlay:
		var all: Array = []
		_collect_all_buttons(game._overlay, all)
		go = all[-1] if not all.is_empty() else null
	if go:
		await click(go)
	await wait(0.4)


func _collect_all_buttons(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Button:
			out.append(c)
		_collect_all_buttons(c, out)


func _part_bos() -> void:
	caption("6  Bos terakhir Bab 1: Panglima Derhaka")
	# the four missions of Bab 1 are done (skipped for the demo): the boss waits
	for z in Game.chapter_zones(1):
		var st := Game.zone_state(z)
		st["done"] = true
		st["steps"] = []
		for step in Game.zone_data(z).get("steps", []):
			st["steps"].append(step["puzzle"])
		if not Game.save["artifacts"].has(z):
			Game.save["artifacts"].append(z)
	var cfg := Game.ujian_def(1)
	var at := Vector2i(int(cfg["pos"][0]), int(cfg["pos"][1]))
	Game.save["map_pos"] = [at.x + 6, at.y]
	Game.persist()
	Game.goto("world")
	await wait_screen("world")
	await wait_idle()
	var w := scene()
	await wait(0.8)
	await click_at(Vector2(560, 360))
	var t0 := 0.0
	while screen_name() == "world" and t0 < 90.0:
		if not w._input_blocked() and not Main.dialog_box.visible and w.player._path.is_empty():
			var npc_at := _target_of(w, "1")
			if (w.player.cell - npc_at).length() <= 1.01:
				w.player.face_cell(npc_at)
				w._interact(npc_at)
			else:
				w._tap(npc_at)
		await close_preps()
		await wait(0.3)
		t0 += 0.3
	await wait_screen("ujian", 60)
	var p = null
	var t := 0.0
	while Game.active_puzzle == null and t < 90.0:
		await wait(0.2)
		t += 0.2
	p = Game.active_puzzle
	if p == null:
		return
	await wait(1.0)
	var n := 0
	var need := int(cfg["need"])
	var wrong_done := false
	while is_instance_valid(p) and not p._finished and n < 20:
		while p._cutting:
			await wait(0.1)
		await wait(1.2)
		var ans := int(p._q()["answer"])
		var pick := ans
		if not wrong_done and n == 1:
			pick = (ans + 1) % 4   # one mistake: a heart goes, the right answer is shown
			wrong_done = true
		await click(p._buttons[pick], 0.5)
		n += 1
		await wait(0.3)
		while is_instance_valid(p) and p._cutting:
			await wait(0.1)
		await wait(1.6 if pick != ans else 0.8)
		if not is_instance_valid(p) or p._finished:
			break
		if p._next.visible:
			await click(p._next, 0.35)
	await wait(2.5)
	var go := find_button(scene(), "Teruskan")
	if go:
		await click(go)
	print("DEMO boss beaten in ", n, " answers (need ", need, ")")


func _part_maklum() -> void:
	await wait_screen("penutup", 90)
	caption("7  Maklum balas selepas Bab 1")
	var t := 0.0
	while screen_name() == "penutup" and t < 200.0:
		var kb: Node = null
		var nota: Node = null
		for c in Main.overlay_root().get_children():
			if c.has_method("_read_page"):
				nota = c
			if c.get_script() and str(c.get_script().resource_path).ends_with("kotak_bintang.gd") and not c.is_queued_for_deletion():
				kb = c
		if kb:
			await wait(1.4)
			var stars: Array = kb._stars
			for i in stars.size():
				await move_cursor(stars[i].get_global_rect().get_center(), 0.18)
			await click(stars[-1], 0.2)
			await wait(0.5)
			await type_into(kb._comment, "Seronok belajar Sejarah macam ni!", 0.035)
			await wait(0.5)
			await click(kb._send)
			await wait(2.5)
			if is_instance_valid(kb) and kb.is_inside_tree():
				kb.close()
			break
		elif nota:
			await wait(2.5)
			if nota.get("_scroll"):
				var tw := create_tween()
				tw.tween_property(nota._scroll, "scroll_vertical", 500, 2.0)
				await tw.finished
				await wait(1.2)
			var close_b := find_button(nota, "Tutup")
			if close_b:
				await click(close_b)
			if is_instance_valid(nota) and nota.is_inside_tree():
				nota.close()
			await wait(0.6)
		elif not Main.dialog_box.visible:
			var b := find_button(hosted(), "Teruskan")
			if b:
				await wait(2.0)
				await click(b)
		await wait(0.2)
		t += 0.2
	await wait(1.0)


func _the_end() -> void:
	_cursor.visible = false
	keys("")
	_end_card = ColorRect.new()
	(_end_card as ColorRect).color = Color(0.05, 0.05, 0.09, 0.0)
	_end_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_card.size = Vector2(Game.screen_w(), 720)
	_layer.add_child(_end_card)
	var l := Label.new()
	l.theme = Game.theme
	l.text = "Explo-Story\nSejarah KSSM Tingkatan 4"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 52)
	l.add_theme_color_override("font_color", Color("ffe9a8"))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.size = _end_card.size
	l.modulate.a = 0.0
	_end_card.add_child(l)
	var tw := create_tween()
	tw.tween_property(_end_card, "color:a", 0.95, 1.0)
	tw.tween_property(l, "modulate:a", 1.0, 0.6)
	await tw.finished
	await wait(3.0)
