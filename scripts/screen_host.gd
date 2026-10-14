extends Control
## Hosts one menu screen from the first prototype (login, register, lobby,
## zone summary, penutup). Game.goto(name, params) sets Game.pending_screen
## and changes to this scene.


func _ready() -> void:
	theme = Game.theme
	var screen := Game.pending_screen
	if not Game.SCREENS.has(screen):
		push_error("Unknown screen: " + screen)
		return
	var node: Node = load(Game.SCREENS[screen]).new()
	node.set("params", Game.pending_params)
	if node is Control:
		(node as Control).theme = Game.theme
	add_child(node)
