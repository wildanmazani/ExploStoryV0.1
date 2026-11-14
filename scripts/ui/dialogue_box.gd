extends Control
## NPC / Pau dialogue box with portrait, typewriter text and a read-aloud
## button on every line. Cream background, short lines, no time limit.

const UI = preload("res://scripts/ui/ui.gd")
## name plate colour per speaker (others: wood brown)
const PLATE := {
	"alif": Color("3b6fb6"), "pau": Color("d98a2b"), "nirbana": Color("5b3a7a"),
	"panglima": Color("9c2f2f"), "gabenor": Color("6b6b6b"),
}
const PORTRAIT_BOX := 144.0
## speakers drawn on the left (the player's side)
const LEFT_SIDE := ["alif", "pau"]

signal finished

## Animal Crossing-style voice blips while text types: pitch per speaker
const VOICE := {
	"alif": 1.0, "pau": 1.7, "penjaga": 0.62, "tunperak": 0.66, "syahbandar": 1.18,
	"sapurba": 0.78, "demang": 0.74, "makcik": 1.3, "nelayan": 0.88, "chengho": 0.84,
	"mak": 1.22, "aisyah": 1.4, "ravi": 0.94, "meiling": 1.5, "daniel": 1.08,
	"guru_silat": 0.7, "pesilat_amir": 1.12, "pesilat_hafiz": 1.02,
}

## cutscenes (the intro): each line moves on by itself once there has been
## time to read it; a tap still goes faster
var auto_advance := false
var _hold := 0.0

var _lines: Array = []
var _i: int = 0
var _typing: bool = false
var _shown: float = 0.0
var _panel: PanelContainer
var _portrait: TextureRect
var _portrait_frame: PanelContainer
var _portrait_r: TextureRect
var _portrait_r_frame: PanelContainer
var _plate: PanelContainer
var _more: Control
var _name: Label
var _text: Label
var _next: Button
var _tag: Label
var _who := ""
var _last_who := ""
var _blip_at := 0
var _last_narr := ""
## the narrator's card: deep night blue, gold frame, soft shadow
static var NARRATOR_PANEL: StyleBoxFlat = _narrator_panel()


static func _narrator_panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.07, 0.13, 0.95)
	s.border_color = Color("d9a93a")
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(22)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 10
	return s


func _ready() -> void:
	UI.full(self)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.18)
	UI.full(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_panel = UI.panel("Paper")
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 40
	_panel.offset_right = -150
	_panel.offset_top = -230
	_panel.offset_bottom = -20
	add_child(_panel)
	var row := UI.hbox(18)
	_panel.add_child(row)

	# portrait on the left for Alif and Pau, on the right for everyone else,
	# so it is always clear who is talking
	_portrait_frame = _make_frame()
	_portrait = _portrait_frame.get_child(0)
	row.add_child(_portrait_frame)
	_portrait_r_frame = _make_frame()
	_portrait_r = _portrait_r_frame.get_child(0)

	var col := UI.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := UI.hbox(12)
	_plate = PanelContainer.new()
	_name = UI.label("", "Heading")
	_name.add_theme_color_override("font_color", Color.WHITE)
	_plate.add_child(_name)
	name_row.add_child(_plate)
	_tag = UI.label("", "InkSmall")
	name_row.add_child(_tag)
	col.add_child(name_row)
	_text = UI.label("", "Ink", true)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(560, 110)
	col.add_child(_text)
	_more = MoreArrow.new()
	_more.custom_minimum_size = Vector2(20, 14)
	_more.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(_more)
	row.add_child(col)
	row.add_child(_portrait_r_frame)

	var btns := UI.vbox(10)
	_next = UI.button("»", "Primary")
	_next.custom_minimum_size = Vector2(72, 64)
	_next.tooltip_text = "Seterusnya"
	_next.pressed.connect(_advance)
	btns.add_child(_next)
	row.add_child(btns)


func _enter_tree() -> void:
	if not Game.skin_changed.is_connected(_on_skin):
		Game.skin_changed.connect(_on_skin)


func _on_skin() -> void:
	if visible and _who == "alif":
		_set_portrait(_portrait, UI.tex(Game.portrait_path("alif", str(_lines[_i].get("e", "")))))


func play(lines_arr: Array) -> void:
	_lines = lines_arr
	_i = 0
	_last_narr = ""
	visible = true
	_show_line()
	await finished


func _show_line() -> void:
	var line: Dictionary = _lines[_i]
	var who: String = str(line.get("s", "narator"))
	_who = who
	_blip_at = 0
	_name.text = Game.char_name(who)
	_plate.visible = _name.text != ""
	_plate.add_theme_stylebox_override("panel", UI.sb(PLATE.get(who, UI.WOOD), PLATE.get(who, UI.WOOD).darkened(0.35), 3, 6, 4))
	_tag.text = "(dialog rekaan)" if line.get("rekaan", false) else ""
	var p := Game.portrait_path(who, str(line.get("e", "")))
	var left := who in LEFT_SIDE
	var frame := _portrait_frame if left else _portrait_r_frame
	_set_portrait(_portrait if left else _portrait_r, UI.tex(p))
	_portrait_frame.visible = p != "" and left
	_portrait_r_frame.visible = p != "" and not left
	if p != "" and (who != _last_who or _i == 0):
		frame.pivot_offset = frame.size / 2.0
		frame.scale = Vector2(0.9, 0.9)
		create_tween().tween_property(frame, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_last_who = who
	_text.text = str(line.get("t", ""))
	if who == "narator":
		# the story voice: a dark storybook card with a gold frame, big
		# centred text and a CERITA plate, not a speaker's cream paper
		_panel.add_theme_stylebox_override("panel", NARRATOR_PANEL)
		_name.text = tr("CERITA")
		_plate.visible = true
		_plate.add_theme_stylebox_override("panel", UI.sb(Color("7a5a1e"), UI.GOLD, 2, 6, 4))
		_text.theme_type_variation = "Narrator"
		_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if who != _last_narr:
			_panel.modulate.a = 0.0
			create_tween().tween_property(_panel, "modulate:a", 1.0, 0.25)
	else:
		_panel.remove_theme_stylebox_override("panel")
		_text.theme_type_variation = "Ink"
		_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_last_narr = who
	var spd := Game.type_speed()
	if spd <= 0.0:
		_text.visible_characters = -1
		_typing = false
	else:
		_text.visible_characters = 0
		_shown = 0.0
		_typing = true
	if bool(Game.settings.get("auto_read", false)):
		Tts.speak(_text.text)
	_hold = 1.2 + _text.text.length() * 0.045  # time to read it after it has typed out
	_next.grab_focus()


func _process(delta: float) -> void:
	_more.visible = visible and not _typing
	if not _typing:
		if auto_advance and visible:
			_hold -= delta
			if _hold <= 0.0:
				_advance()
		return
	_shown += delta * Game.type_speed()
	_text.visible_characters = int(_shown)
	if _text.visible_characters >= _blip_at + 2:
		_blip_at = _text.visible_characters
		_babble(_blip_at)
	if _text.visible_characters >= _text.text.length():
		_text.visible_characters = -1
		_typing = false


## Fast, unclear, cute "talking": one syllable for every two letters typed,
## the vowel taken from the words themselves, at the speaker's pitch.
## The narrator types instead (typewriter keys). Silent in read-aloud mode
## (a real voice reads then).
func _babble(at: int) -> void:
	if bool(Game.settings.get("auto_read", false)):
		return
	var ch := _text.text.substr(at - 1, 1)
	if _who == "" or _who == "narator":  # the narrator writes: typewriter keys
		if ch == " ":
			Sfx.voice("taip_space", -8.0, randf_range(0.95, 1.05))
		elif ch.strip_edges() != "":
			Sfx.voice("taip_%d" % randi_range(1, 4), -7.0, randf_range(0.92, 1.08))
		return
	if ch.strip_edges() == "" or ".,!?;:-\"'()".contains(ch):
		return
	var v := "a"
	var rest := _text.text.substr(at - 1, 6).to_lower()
	for c in rest:
		if "aeiou".contains(c):
			v = c
			break
	Sfx.voice("babble_" + v, -6.0, voice_pitch(_who) * randf_range(0.93, 1.08))


## the speaker's voice: set ones in VOICE, any other a steady pitch from its name
static func voice_pitch(who: String) -> float:
	if VOICE.has(who):
		return float(VOICE[who])
	return 0.8 + float(abs(who.hash()) % 50) / 100.0


func _advance() -> void:
	if _typing:
		_typing = false
		_text.visible_characters = -1
		return
	_i += 1
	if _i >= _lines.size():
		visible = false
		Tts.stop()
		finished.emit()
	else:
		_show_line()


## close immediately (used by Skip buttons)
func cancel() -> void:
	if not visible:
		return
	_typing = false
	visible = false
	Tts.stop()
	finished.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact"):
		_advance()
		get_viewport().set_input_as_handled()


## portraits keep whole-number pixels: the largest integer scale that fits
## the 144 px slot (64 px art -> 128, 48 px art -> 144)
func _set_portrait(r: TextureRect, tex: Texture2D) -> void:
	r.texture = tex
	if tex:
		var side := maxf(tex.get_width(), tex.get_height())
		r.custom_minimum_size = Vector2.ONE * side * maxf(1.0, floorf(PORTRAIT_BOX / side))


func _make_frame() -> PanelContainer:
	var f := UI.panel("Slot")
	f.custom_minimum_size = Vector2(160, 160)
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.custom_minimum_size = Vector2(PORTRAIT_BOX, PORTRAIT_BOX)
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	f.add_child(t)
	return f


## Blinking down arrow: the line is fully shown, tap to go on.
class MoreArrow extends Control:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if fmod(_t, 0.9) > 0.6:
			return
		var y := sin(_t * 6.0) * 2.0
		draw_colored_polygon(PackedVector2Array([Vector2(2, y + 2), Vector2(18, y + 2), Vector2(10, y + 12)]), Color(0.45, 0.27, 0.12))
