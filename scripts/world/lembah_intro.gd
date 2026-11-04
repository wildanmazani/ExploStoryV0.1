extends RefCounted
## The first minutes in Lembah Kebangkitan (Bab 2), played once: up the road
## a British officer (Kapten John, possessed by Nirbana) pulls a girl in white into the fog. Alif runs after
## them, but they are gone. Pak Wahab, who saw it all, tells him what he saw:
## a girl in white pulled along by an orang putih in uniform. Was it Aisyah?
## Four clues along Bab 2 will tell (klu_aisyah.gd). Text: data/story.json
## (lembah_*). Quitting halfway plays it again: "lembah_intro" is saved at
## the end.

const KampungIntro = preload("res://scripts/world/kampung_intro.gd")
const PAKCIK := "pakcik_lembah"
const OFFICER_FROM := Vector2i(95, 31)  ## up the road from the gate...
const OFFICER_GONE := 6                 ## ...and this many steps east into the fog
const CHASE_TO := Vector2i(94, 31)


static func needed(w: Node) -> bool:
	return Game.chapter_done(1) and not Game.save["seen"].has("lembah_intro") and w.player.cell.x >= w.LEMBAH_X


static func play(w: Node) -> void:
	var player: Player = w.player
	player.can_move = false
	w.hud.visible = false
	await w.get_tree().create_timer(0.9).timeout
	await Game.say("bab2_arrive")

	# up the road: an officer in white drags a girl in white along
	var from: Vector2i = w._nearest_walkable(OFFICER_FROM)
	var officer := Npc.new()
	officer.setup("kapten_john", from, "east")  # Kapten John, under Nirbana
	var girl := Npc.new()
	girl.setup("rakan_aisyah", from + Vector2i(-1, 0), "east")
	girl.modulate = Color(1.15, 1.15, 1.2, 0.9)  # pale, half lost in the fog already
	for n in [girl, officer]:
		w.objects.add_child(n)
	KampungIntro._emote(w, "!")
	await w.get_tree().create_timer(0.6).timeout
	w.emote.visible = false
	await Game.say("lembah_nampak")

	MusicDirector.play("debar", 0.6)
	var road: Array = []
	for i in OFFICER_GONE:
		road.append(from + Vector2i(i + 1, 0))
	officer.script_walk(road, 0.3)
	girl.script_walk([from] + road.slice(0, road.size() - 1), 0.3)
	_struggle(w, girl)
	var path: Array = Pathfind.find(w, player.cell, w._nearest_walkable(CHASE_TO))
	await player.script_walk(path, 0.15)
	await w.get_tree().create_timer(0.5).timeout
	# swallowed by the fog
	var fade := w.create_tween().set_parallel()
	for n in [officer, girl]:
		fade.tween_property(n, "modulate:a", 0.0, 0.8)
	await fade.finished
	officer.queue_free()
	girl.queue_free()
	player.facing = "east"
	await Game.say("lembah_hilang")

	# the old man who saw it all
	var pak: Npc = w.npc_node(PAKCIK)
	if pak:
		var home := pak.cell
		await KampungIntro._npc_to(w, pak, w._free_neighbour(player.cell), 0.3)
		pak.face_towards(player.cell)
		player.face_cell(pak.cell)
		await Game.say("lembah_pakcik")
		await KampungIntro._npc_to(w, pak, home, 0.3)
		pak.face_towards(player.cell)
	else:
		await Game.say("lembah_pakcik")

	Game.save["seen"].append("lembah_intro")
	Game.persist()
	MusicDirector.stinger("st_zone")
	Game.toast(TranslationServer.translate("MISI BARU: Cari 4 klu tentang Aisyah"), Color("ffe08a"))
	w.hud.visible = true
	player.can_move = true
	w.busy = false
	w._enter_area_at(player.cell)


## she pulls back, again and again
static func _struggle(w: Node, girl: Npc) -> void:
	for i in 4:
		await w.get_tree().create_timer(0.45).timeout
		if not is_instance_valid(girl):
			return
		var t := girl.create_tween()
		t.tween_property(girl._sprite, "position:x", -3.0, 0.08)
		t.tween_property(girl._sprite, "position:x", 0.0, 0.12)
