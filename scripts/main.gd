extends Node
## Autoload "Main": global UI layers that live above every scene (from the
## first prototype's root node): dialogue (20), Pau button + hint bubble (25)
## and overlays (30: settings, Nota Alif, Beg Alif, calm moment, toasts).
## Game.main points here, so Game.say(), pau_say(), toast() work anywhere.

const UI = preload("res://scripts/ui/ui.gd")
const DialogueBox = preload("res://scripts/ui/dialogue_box.gd")
const PauButton = preload("res://scripts/ui/pau_button.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const NotaPanel = preload("res://scripts/ui/nota_panel.gd")
const BegPanel = preload("res://scripts/ui/beg_panel.gd")
const CalmOverlay = preload("res://scripts/ui/calm_overlay.gd")
const MapOverlay = preload("res://scripts/ui/map_overlay.gd")
const ProfilePanel = preload("res://scripts/ui/profile_panel.gd")
const PapanPanel = preload("res://scripts/ui/papan_panel.gd")

var dialog_layer: CanvasLayer
var pau_layer: CanvasLayer
var overlay_layer: CanvasLayer
var dialog_box: Control
var pau_button: Control
var bubble: PanelContainer
var bubble_label: Label
var toast_box: VBoxContainer
var _bubble_timer: Timer


func _ready() -> void:
	Game.main = self
	get_tree().root.theme = Game.theme  # dyslexia-friendly fonts everywhere
	dialog_layer = _layer(20)
	pau_layer = _layer(25)
	overlay_layer = _layer(30)

	dialog_box = DialogueBox.new()
	dialog_box.theme = Game.theme
	dialog_layer.add_child(dialog_box)

	var pau_root := Control.new()
	UI.full(pau_root)
	pau_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pau_root.theme = Game.theme
	pau_layer.add_child(pau_root)
	pau_button = PauButton.new()
	pau_root.add_child(pau_button)
	pau_button.tapped.connect(_on_pau_tap)
	pau_button.held.connect(open_calm)
	bubble = UI.panel("Bubble")
	bubble.visible = false
	bubble.custom_minimum_size = Vector2(420, 0)
	var bb := UI.hbox(10)
	bubble_label = UI.label("", "Ink", true)
	bubble_label.custom_minimum_size.x = 340
	bubble_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bb.add_child(bubble_label)
	var speak := UI.icon_button("res://assets/icons/suara.png", "Blue", Vector2(60, 56))
	speak.tooltip_text = "Baca dengan suara"
	speak.pressed.connect(func(): Tts.speak(bubble_label.text))
	bb.add_child(speak)
	bubble.add_child(bb)
	bubble.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			bubble.visible = false)
	pau_root.add_child(bubble)
	_bubble_timer = Timer.new()
	_bubble_timer.one_shot = true
	_bubble_timer.timeout.connect(func(): bubble.visible = false)
	add_child(_bubble_timer)

	var ov := Control.new()
	UI.full(ov)
	ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.theme = Game.theme
	overlay_layer.add_child(ov)
	toast_box = UI.vbox(8)
	toast_box.position = Vector2(390, 96)
	toast_box.custom_minimum_size = Vector2(500, 0)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(toast_box)

	_place_pau()
	set_pau_visible(false)
	Game.settings_changed.connect(func():
		get_tree().root.theme = Game.theme
		_place_pau())
	if "--autotest" in OS.get_cmdline_user_args():
		add_child(load("res://scripts/dev/autotest.gd").new())


## with on-screen controls (Tetapan > Kawalan) the bottom corners belong to
## the thumbs, so Pau moves up (left side for left-handed: the pad is right)
func _place_pau() -> void:
	if not Game.controls_on_screen():
		pau_button.position = Vector2(1280 - 130, 720 - 140)
	elif Game.settings.get("left_handed", false):
		pau_button.position = Vector2(16, 166)
	else:
		pau_button.position = Vector2(1280 - 130, 150)


func _layer(n: int) -> CanvasLayer:
	var l := CanvasLayer.new()
	l.layer = n
	add_child(l)
	return l


func overlay_root() -> Control:
	return overlay_layer.get_child(0) as Control


# ------------------------------------------------------------------ dialogue
func dialogue(key_or_lines: Variant) -> void:
	var arr: Array = []
	if key_or_lines is String:
		arr = Game.lines(key_or_lines)
		if not Game.save["seen"].has(key_or_lines):
			Game.save["seen"].append(key_or_lines)
	elif key_or_lines is Array:
		arr = key_or_lines
	if arr.is_empty():
		return
	for l in arr:
		Game.add_figure(str(l.get("s", "")))
	Game.lock_input()
	MusicDirector.duck(true)
	await dialog_box.play(arr)
	MusicDirector.duck(false)
	Game.unlock_input()


func is_dialogue_open() -> bool:
	return dialog_box.visible


# ------------------------------------------------------------------ Pau
func set_pau_visible(v: bool) -> void:
	pau_button.visible = v
	bubble.visible = false  # every screen calls this on entry: no leftover bubble


func pau_say(text: String, seconds: float = 7.0) -> void:
	pau_button.happy()
	Sfx.play("pop", -8.0, 1.3)
	if Game.active_puzzle != null and is_instance_valid(Game.active_puzzle) and Game.active_puzzle.has_method("show_pau_hint"):
		Game.active_puzzle.show_pau_hint(text)
		return
	bubble_label.text = text
	bubble.visible = true
	bubble.reset_size()
	var bx := pau_button.size.x + 20.0 if pau_button.position.x < 640 else -20.0 - bubble.size.x  # Pau on the left: bubble opens right
	bubble.position = pau_button.position + Vector2(bx, 10 - (bubble.size.y if pau_button.position.y > 360 else 0.0))
	_bubble_timer.start(seconds)
	if bool(Game.settings.get("auto_read", false)):
		Tts.speak(text)


func _on_pau_tap() -> void:
	Game.pau_pressed.emit()
	if Game.active_puzzle != null and is_instance_valid(Game.active_puzzle):
		Game.active_puzzle.call("request_hint")
		return
	if is_dialogue_open():
		return
	var t := Game.context_hint
	if t == "":
		t = "Aku kat sini! Ketik aku untuk petunjuk. Tekan lama kalau nak bertenang."
	pau_say(t)


func open_calm() -> void:
	overlay_root().add_child(CalmOverlay.new())


# ------------------------------------------------------------------ overlays
func open_settings() -> Control:
	var p := SettingsPanel.new()
	overlay_root().add_child(p)
	return p


## zone: open on that mission's first page (e.g. "1_3"), else the newest Bab
func open_nota(zone: String = "") -> Control:
	var p := NotaPanel.new()
	p.start_zone = zone
	overlay_root().add_child(p)
	return p


## A yes/no card over everything. Returns true for yes.
func ask(text: String, yes_text: String = "Ya", no_text: String = "Tak") -> bool:
	Game.lock_input()
	var root := Control.new()
	UI.full(root)
	root.theme = Game.theme
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(UI.dim(0.5))
	var card := UI.panel("Paper")
	card.custom_minimum_size = Vector2(620, 0)
	var col := UI.vbox(16)
	var l := UI.label(tr(text), "Ink", true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	var row := UI.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var no := UI.button(tr(no_text), "", 200)
	var yes := UI.button(tr(yes_text), "Primary", 200)
	row.add_child(no)
	row.add_child(yes)
	col.add_child(row)
	card.add_child(col)
	root.add_child(UI.center(card))
	overlay_root().add_child(root)
	yes.grab_focus()
	var pick := [false]
	var done := func(v: bool):
		pick[0] = v
		root.set_meta("done", true)
	yes.pressed.connect(done.bind(true))
	no.pressed.connect(done.bind(false))
	while is_instance_valid(root) and not root.has_meta("done"):
		await get_tree().process_frame
	Sfx.play("select", -6.0)
	root.queue_free()
	Game.unlock_input()
	return pick[0]


## Beg Alif: the artifacts found so far and the Kad Tokoh
func open_beg() -> Control:
	var p := BegPanel.new()
	overlay_root().add_child(p)
	return p


## Profil & Kedai (tab 0 = profile, 1 = skin shop)
func open_profile(tab: int = 0) -> Control:
	var p := ProfilePanel.new()
	p.start_tab = tab
	overlay_root().add_child(p)
	return p


## Papan Markah (leaderboard): Seluruh / Negeri / Rakan.
func open_papan(tab: int = 0) -> Control:
	var p := PapanPanel.new()
	p.start_tab = tab
	overlay_root().add_child(p)
	return p


## Full world map with legend (world scene only).
func open_map(world: Node) -> Control:
	var p := MapOverlay.new()
	p.world = world
	overlay_root().add_child(p)
	return p


func toast(text: String, color: Color = UI.GOLD) -> void:
	var p := UI.panel()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UI.label(text, "", true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	p.add_child(l)
	toast_box.add_child(p)
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


func shake(strength: float = 8.0, duration: float = 0.4) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var tw := create_tween()
	for i in int(duration / 0.04):
		tw.tween_property(cam, "offset", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)) / cam.zoom.x, 0.04)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.04)
