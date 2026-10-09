extends Node
## Root node. Owns the current screen plus global layers:
## dialogue (20), Pau (25) and overlays (30: settings, notes, calm, fade, toast).

const UI = preload("res://scripts/ui/ui.gd")
const DialogueBox = preload("res://scripts/ui/dialogue_box.gd")
const PauButton = preload("res://scripts/ui/pau_button.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const NotaPanel = preload("res://scripts/ui/nota_panel.gd")
const MuziumPanel = preload("res://scripts/ui/muzium_panel.gd")
const CalmOverlay = preload("res://scripts/ui/calm_overlay.gd")

var screen_root: Node
var current: Node = null
var current_name: String = ""
var dialog_layer: CanvasLayer
var pau_layer: CanvasLayer
var overlay_layer: CanvasLayer
var dialog_box: Control
var pau_button: Control
var bubble: PanelContainer
var bubble_label: Label
var fade: ColorRect
var toast_box: VBoxContainer
var _bubble_timer: Timer
var _switching: bool = false


func _ready() -> void:
	Game.main = self
	screen_root = Node.new()
	screen_root.name = "Screen"
	add_child(screen_root)
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
	bubble.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bubble.position = Vector2(1280 - 560, 720 - 280)
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
	fade = ColorRect.new()
	fade.color = Color(0.05, 0.05, 0.1, 1)
	UI.full(fade)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(fade)

	set_pau_visible(false)
	show_screen("title", {})
	if "--autotest" in OS.get_cmdline_user_args():
		add_child(load("res://scripts/dev/autotest.gd").new())


func _layer(n: int) -> CanvasLayer:
	var l := CanvasLayer.new()
	l.layer = n
	add_child(l)
	return l


func overlay_root() -> Control:
	return overlay_layer.get_child(0) as Control


# ------------------------------------------------------------------ screens
func show_screen(screen: String, params: Dictionary = {}) -> void:
	if _switching:
		return
	_switching = true
	if current != null:
		var tw := create_tween()
		tw.tween_property(fade, "color:a", 1.0, 0.25)
		await tw.finished
		current.queue_free()
		current = null
	Tts.stop()
	bubble.visible = false
	Game.active_puzzle = null
	Game.context_hint = ""
	Game.input_lock = 0
	var script: Script = load(Game.SCREENS[screen])
	var node: Node = script.new()
	node.set("params", params)
	if node is Control:
		(node as Control).theme = Game.theme
	current = node
	current_name = screen
	screen_root.add_child(node)
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.35)
	_switching = false


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
	await dialog_box.play(arr)
	Game.unlock_input()


func is_dialogue_open() -> bool:
	return dialog_box.visible


# ------------------------------------------------------------------ Pau
func set_pau_visible(v: bool) -> void:
	pau_button.visible = v
	if not v:
		bubble.visible = false


func pau_say(text: String, seconds: float = 7.0) -> void:
	pau_button.happy()
	if Game.active_puzzle != null and is_instance_valid(Game.active_puzzle) and Game.active_puzzle.has_method("show_pau_hint"):
		Game.active_puzzle.show_pau_hint(text)
		return
	bubble_label.text = text
	bubble.visible = true
	bubble.reset_size()
	bubble.position = Vector2(1280 - 150 - bubble.size.x, 720 - 140 - bubble.size.y)
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
		t = "Aku di sini! Ketik aku untuk petunjuk. Tekan lama untuk bertenang."
	pau_say(t)


func open_calm() -> void:
	var c := CalmOverlay.new()
	overlay_root().add_child(c)


# ------------------------------------------------------------------ overlays
func open_settings() -> void:
	var p := SettingsPanel.new()
	overlay_root().add_child(p)


func open_nota() -> void:
	var p := NotaPanel.new()
	overlay_root().add_child(p)


func open_muzium() -> void:
	var p := MuziumPanel.new()
	overlay_root().add_child(p)


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
	if current is Node2D or current is Control:
		var node: CanvasItem = current
		var orig: Vector2 = node.position
		var tw := create_tween()
		var steps := int(duration / 0.04)
		for i in steps:
			tw.tween_property(node, "position", orig + Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.04)
		tw.tween_property(node, "position", orig, 0.04)
