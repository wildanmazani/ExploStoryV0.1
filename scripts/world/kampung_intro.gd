extends RefCounted
## The story between Alif's room and Misi 1.1, played once in Kampung Jejak:
## Aisyah runs from him, he trips at Mak Som's house, she calls Guru Jalal, and
## Mak Som gives him the stone map of Bab 1 (ui/peta_batu.gd). Text: data/story.json
## (intro_*). Quitting halfway replays it from the door: "bilik_tutorial" goes
## into the save only at the end, and saves that already have it never see it.

const PetaBatu = preload("res://scripts/ui/peta_batu.gd")
const DOOR := Vector2i(22, 43)          ## outside Rumah Alif (bilik_alif.tscn return_cell_world)
const AISYAH_FROM := Vector2i(27, 44)
const AISYAH_LOOK := Vector2i(25, 44)  ## Alif walks up to here...
const AISYAH_GONE := Vector2i(40, 31)  ## ...she runs off down the kampung road
const RUN_UP := Vector2i(25, 32)       ## he comes along the road heading east...
const ROCK_CELL := Vector2i(27, 32)    ## ...hits this rock...
const FALL_CELL := Vector2i(28, 32)    ## ...and lands here, in front of Mak Som's house
const MAK_STOP := Vector2i(28, 31)
const GURU_STOP := Vector2i(30, 32)    ## past his head: he lies with it to the east
const CHASE_STEP := 0.13
const FACE_DOWN := 1.48                ## radians: flat on his face, heading east


static func needed() -> bool:
	var seen: Array = Game.save["seen"]
	return seen.has("beg_alif") and not seen.has("bilik_tutorial")


static func play(w: Node) -> void:
	var player: Player = w.player
	player.can_move = false
	player.place_at(DOOR, "south")  # also after quitting halfway
	w.pau.place_at(w._free_neighbour(DOOR))
	await w.get_tree().create_timer(1.2).timeout  # the fade in, and the map photo

	var aisyah := Npc.new()
	aisyah.setup("rakan_aisyah", AISYAH_FROM, "west")
	w.objects.add_child(aisyah)
	await player.script_walk(_path(w, player.cell, AISYAH_LOOK))
	player.face_cell(aisyah.cell)
	aisyah.face_towards(player.cell)
	await Game.say("intro_aisyah")

	# she panics and is gone; he runs after her and trips
	_flee(w, aisyah)
	await w.get_tree().create_timer(0.4).timeout
	await Game.say("intro_kejar")
	var rock := _rock(w)
	await player.script_walk(_path(w, player.cell, RUN_UP), CHASE_STEP)
	await player.script_walk([RUN_UP + Vector2i(1, 0)], CHASE_STEP)
	await _trip(w, player)

	var mak: Npc = w.npc_node("makcik")
	await _npc_to(w, mak, MAK_STOP, 0.3)
	mak.face_towards(player.cell)
	_emote(w, "!")
	await w.get_tree().create_timer(0.5).timeout
	w.emote.visible = false
	await Game.say("intro_tahan")

	var guru: Npc = w.npc_node("guru_silat")
	var guru_home := guru.cell
	var guru_face := guru.facing
	await _npc_to(w, guru, GURU_STOP, 0.2)
	guru.face_towards(player.cell)
	await _get_up(w, player)
	player.face_cell(guru.cell)
	await Game.say("intro_guru")

	player.face_cell(mak.cell)
	await Game.say("intro_mak_som")
	MusicDirector.stinger("st_item")
	Game.toast(TranslationServer.translate("Dapat: Peta Batu Bab 1!"))
	var stone := PetaBatu.new()
	stone.world = w
	Main.overlay_root().add_child(stone)
	await stone.closed
	await Game.say("intro_lepas_peta")

	await _npc_to(w, guru, guru_home, 0.16)
	guru.facing = guru_face
	guru.face_towards(guru_home + (Vector2i(1, 0) if guru_face == "east" else Vector2i(0, 1)))
	await _npc_to(w, mak, Vector2i(mak.home), 0.3)
	rock.queue_free()
	_begin_mission(w)


static func _path(w: Node, from: Vector2i, to: Vector2i) -> Array:
	var cells: Array = Pathfind.find(w, from, w._nearest_walkable(to))
	return cells


static func _flee(w: Node, aisyah: Npc) -> void:
	await aisyah.script_walk(_path(w, aisyah.cell, AISYAH_GONE), 0.1)
	var t := aisyah.create_tween()
	t.tween_property(aisyah, "modulate:a", 0.0, 0.4)
	t.tween_callback(aisyah.queue_free)


## walks a registered NPC there; with no way through, it just arrives
static func _npc_to(w: Node, npc: Npc, to: Vector2i, step: float) -> void:
	if npc.cell == to:
		return
	var cells: Array = Pathfind.find(w, npc.cell, to)
	if cells.is_empty():
		w.move_npc(npc, to)
		npc.cell = to
		npc.position = Player.cell_to_pos(to)
		return
	await npc.script_walk(cells, step, w)


## a small rock in the road, only for this scene
static func _rock(w: Node) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/objects/rocks.png")
	s.scale = Vector2(0.45, 0.45)
	s.offset = CharacterFrames.visible_bottom_offset(s.texture)
	s.position = Player.cell_to_pos(ROCK_CELL)
	w.objects.add_child(s)
	return s


## his foot catches the rock: he pitches forward over it and lands flat on his
## face, sliding a little in a puff of dust
static func _trip(w: Node, player: Player) -> void:
	var from := player.cell
	player.facing = "east"
	player.sprite.play("idle_east")
	player.cell = FALL_CELL
	player.step_started.emit(from, FALL_CELL, 0.34)
	Sfx.play("bump", -4.0, 1.3)
	_dust(w, Player.cell_to_pos(ROCK_CELL), 10)
	var land := Player.cell_to_pos(FALL_CELL)
	var t := w.create_tween().set_parallel()
	t.tween_property(player.sprite, "rotation", FACE_DOWN, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(player, "position", land - Vector2(5, 0), 0.3)
	await t.finished
	Sfx.play("bump")
	Main.shake(4.0, 0.3)
	_dust(w, land + Vector2(10, -2), 26)
	var slide := w.create_tween()
	slide.tween_property(player, "position", land, 0.22).set_ease(Tween.EASE_OUT)
	await slide.finished
	await w.get_tree().create_timer(0.6).timeout


static func _dust(w: Node, at: Vector2, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.z_index = 5
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.8
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.gravity = Vector2(0, 26)
	p.initial_velocity_min = 16.0
	p.initial_velocity_max = 46.0
	p.damping_min = 18.0
	p.damping_max = 30.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.6
	var fade := Gradient.new()
	fade.set_color(0, Color(0.82, 0.68, 0.46, 0.9))
	fade.set_color(1, Color(0.82, 0.68, 0.46, 0.0))
	p.color_ramp = fade
	w.objects.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## up on his hands and back on his feet, on the cell he fell to
static func _get_up(w: Node, player: Player) -> void:
	var t := w.create_tween()
	t.tween_property(player.sprite, "rotation", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished


static func _emote(w: Node, text: String) -> void:
	w.emote.text = text
	w.emote.visible = true
	Sfx.play("pop", 0.0, 1.4)


## the map is in his hands: the maps and the gold arrow come on, Misi 1.1 starts
static func _begin_mission(w: Node) -> void:
	Game.save["seen"].append("bilik_tutorial")
	Game.persist()
	w.hud.visible = true
	w.player.can_move = true
	w.busy = false
	var zid := Game.next_zone()
	if zid != "":
		MusicDirector.stinger("st_zone")
		Game.toast(TranslationServer.translate("MISI %s BERMULA: %s") % [zid.replace("_", "."), str(Game.zone_data(zid).get("title", ""))], Color("8fe08a"))
		Game.context_hint = TranslationServer.translate("Ikut anak panah emas ke misi pertama.")
	w._enter_area_at(w.player.cell)
	w._controls_tip()
