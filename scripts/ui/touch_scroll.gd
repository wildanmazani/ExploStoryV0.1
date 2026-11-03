class_name TouchScroll
extends Node
## Phones: drag a finger anywhere on a ScrollContainer to scroll it, also when
## the finger lands on a button or a panel (those keep the drag to themselves,
## so the list would not move). A short tap still presses the button; once
## the finger has moved, the button under it is let go without pressing.
##   TouchScroll.attach(scroll)

const START := 14.0   ## how far the finger moves before it counts as a scroll

var _scroll: ScrollContainer
var _touch := -1
var _from := Vector2.ZERO
var _dragging := false
var _letting_go := false


static func attach(s: ScrollContainer) -> void:
	var t := TouchScroll.new()
	t._scroll = s
	s.add_child(t, false, Node.INTERNAL_MODE_BACK)


func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			if _touch == -1 and _scroll.is_visible_in_tree() and _scroll.get_global_rect().has_point(e.position):
				_touch = e.index
				_from = e.position
				_dragging = false
		elif e.index == _touch:
			_touch = -1
			if _dragging:
				_dragging = false
				get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag and e.index == _touch:
		if not _dragging:
			var moved: Vector2 = e.position - _from
			if absf(moved.y) < START or absf(moved.y) < absf(moved.x):
				return
			# only the list the finger is on (not a list under an open window)
			var over := get_viewport().gui_get_hovered_control()
			if over == null or not (over == _scroll or _scroll.is_ancestor_of(over)):
				_touch = -1
				return
			_dragging = true
			call_deferred("_let_go")
		_scroll.scroll_vertical -= int(e.relative.y)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion and _dragging and not _letting_go:
		get_viewport().set_input_as_handled()  # the same finger as a mouse: scroll once, not twice


## the button the finger first pressed: move the "mouse" off it and release it
## there, so it goes back to normal without counting as a press
func _let_go() -> void:
	_letting_go = true
	var away := InputEventMouseMotion.new()
	away.position = Vector2(-9999, -9999)
	away.global_position = away.position
	get_viewport().push_input(away)
	_letting_go = false
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(-9999, -9999)
	up.global_position = up.position
	get_viewport().push_input(up)
