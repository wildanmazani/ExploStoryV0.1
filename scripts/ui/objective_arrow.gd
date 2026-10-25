extends Control
## Anak panah penunjuk in the world: when the objective (world.objective())
## is off screen, a gold arrow sits on the screen edge pointing at it, with
## the mission and how many steps away. On screen, a small arrow bobs over
## the place (the "!" marker is there too when it is a mission step). Hidden
## while there is no objective, Alif has arrived, or a cutscene / puzzle /
## dialogue is on.

const UI = preload("res://scripts/ui/ui.gd")
const MARGIN := 70.0

var world: Node
var _t := 0.0
var _label: Label


func _ready() -> void:
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = UI.label("", "Small")
	_label.add_theme_color_override("font_color", UI.GOLD)
	_label.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03))
	_label.add_theme_constant_override("outline_size", 6)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	_label.visible = false
	if world == null or not world.hud.visible or world.busy or world.runner.busy \
			or Game.active_puzzle != null or Main.is_dialogue_open():
		return
	var goal: Dictionary = world.objective()
	if goal.is_empty():
		return
	var steps := int(round(Vector2(world.player.cell).distance_to(goal["tile"])))
	if steps <= MapView.ARRIVED:
		return
	var ct := get_viewport().get_canvas_transform()
	var me: Vector2 = ct * world.player.global_position
	var gp: Vector2 = ct * (goal["tile"] * 16.0)  # tiles -> world px
	var view := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var inner := view.grow(-MARGIN)
	var bob := sin(_t * 5.0) * 4.0
	if view.grow(-16).has_point(gp):  # on screen: bob over the place itself
		MapView.draw_nav_arrow(self, gp + Vector2(0, -60 + bob), PI / 2.0, 16)
		return
	var dir := (gp - me).angle()
	var at := _edge(me, gp, inner) - Vector2.from_angle(dir) * bob
	MapView.draw_nav_arrow(self, at, dir, 22)
	_label.visible = true
	_label.text = "%s · %s" % [goal["name"], tr("%d langkah") % steps]
	_label.reset_size()
	var lp := at - Vector2.from_angle(dir) * 46 - _label.size / 2.0
	_label.position = Vector2(clampf(lp.x, 8, view.size.x - _label.size.x - 8), clampf(lp.y, 8, view.size.y - _label.size.y - 8))


## where the line from a towards b leaves the rect r (a may be outside it)
func _edge(a: Vector2, b: Vector2, r: Rect2) -> Vector2:
	a = a.clamp(r.position, r.end)
	var d := b - a
	var t := 1.0
	for i in 2:
		if d[i] > 0.0:
			t = minf(t, (r.end[i] - a[i]) / d[i])
		elif d[i] < 0.0:
			t = minf(t, (r.position[i] - a[i]) / d[i])
	return a + d * maxf(t, 0.0)
