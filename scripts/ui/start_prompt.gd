extends Control
## "Do this first" indicator for the start of the game: a blinking key-cap
## card ("Tekan [E] untuk ambil beg") with a gold arrow bobbing over the
## thing to use. It follows that spot on screen and fades out with done()
## once the player has done it. The card says "Ketik" on touch screens.

const UI = preload("res://scripts/ui/ui.gd")

var target: Node2D          ## the thing to use (its position is the arrow tip)
var lift := 26.0            ## world px above target.position for the arrow
var key := "E"              ## keyboard key on the card
var action_text := ""       ## "untuk ambil beg"

var _t := 0.0
var _card: PanelContainer
var _done := false


func _ready() -> void:
	UI.full(self)
	theme = Game.theme
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = UI.panel("Paper")
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UI.hbox(10)
	if Game.controls_on_screen():
		row.add_child(UI.label(tr("Ketik"), "InkHeading"))
	else:
		row.add_child(UI.label(tr("Tekan"), "InkHeading"))
		var cap := UI.panel()  # the key, as a dark key-cap
		var k := UI.label(key, "Heading")
		k.add_theme_color_override("font_color", UI.GOLD)
		cap.add_child(k)
		row.add_child(cap)
	row.add_child(UI.label(tr(action_text), "InkHeading"))
	_card.add_child(row)
	add_child(_card)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
	Sfx.play("pop", -8.0, 1.2)


## the player did it: fade out and go
func done() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	visible = not Main.is_dialogue_open()  # never on top of a conversation
	if not is_instance_valid(target):
		return
	_card.modulate.a = 0.78 + 0.22 * sin(_t * 4.0)  # a gentle blink, always readable
	_card.reset_size()
	var tip := _tip()
	_card.position = Vector2(clampf(tip.x - _card.size.x / 2.0, 8, size.x - _card.size.x - 8), maxf(tip.y - 52 - _card.size.y, 8))
	queue_redraw()


func _tip() -> Vector2:
	return get_viewport().get_canvas_transform() * (target.global_position + Vector2(0, -lift))


func _draw() -> void:
	if is_instance_valid(target):
		MapView.draw_nav_arrow(self, _tip() + Vector2(0, -22 + sin(_t * 5.0) * 5.0), PI / 2.0, 22)
