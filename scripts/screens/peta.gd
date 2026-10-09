extends "res://scripts/world/walk_area.gd"
## Peta Jejak Pembelajaran (Module 2 overworld): 10 flags for Sejarah
## Tingkatan 4 (only Bendera 1 open), the 4 Bab 1 zone buildings, Muzium,
## Arena (Module 6 lobby) and the locked gate to Tingkatan 5.

var layout: Dictionary
var _flag1: Sprite2D


func _build() -> void:
	layout = Game.load_json("res://data/peta_layout.json")
	var spawn_arr: Array = layout["special"]["spawn"]
	var spawn := Vector2(spawn_arr[0], spawn_arr[1])
	var mp: Array = Game.save.get("map_pos", [])
	if mp.size() == 2:
		spawn = Vector2(mp[0], mp[1])
	setup_area("res://assets/bg/peta_jejak.png", Rect2(40, 90, 2480, 1240), spawn,
		"PETA JEJAK PEMBELAJARAN", "Sejarah Tingkatan 4", false)
	var arc: Dictionary = Game.chapters["arcs"][0]
	var chs: Array = arc["chapters"]
	var flags: Array = layout["flags"]
	# glowing road from Bendera 1 to Bendera 2 once Bab 1 is complete
	if Game.chapter_done(1):
		var road := Line2D.new()
		road.width = 26
		road.default_color = Color(1.0, 0.85, 0.3, 0.55)
		road.add_point(Vector2(flags[0][0], flags[0][1]))
		road.add_point(Vector2(flags[1][0], flags[1][1]))
		road.z_index = -5
		add_child(road)
		var rt := create_tween().set_loops()
		rt.tween_property(road, "modulate:a", 0.4, 0.8)
		rt.tween_property(road, "modulate:a", 1.0, 0.8)
	for i in chs.size():
		var ch: Dictionary = chs[i]
		var pos := Vector2(flags[i][0], flags[i][1])
		var open := bool(ch.get("open", false))
		var s := add_texture_obj("flag_%d" % (i + 1), "res://assets/objects/bendera_%s.png" % ("aktif" if open else "kunci"), pos, 4,
			"Bendera %d: %s" % [i + 1, ch["title"]])
		if i == 0:
			_flag1 = s
			if Game.chapter_done(1):
				var ft := create_tween().set_loops()
				ft.tween_property(s, "skew", 0.12, 0.35)
				ft.tween_property(s, "skew", -0.08, 0.35)
		# chapter number + era icon
		var tag := Label.new()
		tag.text = str(i + 1)
		tag.theme = Game.theme
		tag.theme_type_variation = "Heading"
		tag.add_theme_font_size_override("font_size", 30)
		tag.position = pos + Vector2(-46, -40)
		tag.z_index = 40
		world.add_child(tag)
		var ic := Sprite2D.new()
		ic.texture = UI.tex("res://assets/icons/%s.png" % ch.get("icon", "bendera"))
		ic.scale = Vector2(2, 2)
		ic.position = pos + Vector2(44, -20)
		ic.modulate = Color.WHITE if open else Color(0.5, 0.5, 0.55)
		world.add_child(ic)
		if not open:
			var lock := Sprite2D.new()
			lock.texture = UI.tex("res://assets/icons/kunci.png")
			lock.scale = Vector2(2, 2)
			lock.position = pos + Vector2(10, -100)
			lock.z_index = 30
			world.add_child(lock)
	# Bab 1 zone buildings
	for z in Game.ZONES:
		var zd := Game.zone_data(z)
		var zp: Array = layout["zones"][z]
		var pos := Vector2(zp[0], zp[1])
		var b := add_texture_obj("zone_" + z, "res://assets/objects/bangunan_%s.png" % z, pos, 4, "Zon %s: %s" % [zd["no"], zd["title"]])
		if not Game.zone_unlocked(z):
			b.modulate = Color(0.55, 0.55, 0.6)
		if Game.zone_done(z):
			var star := Sprite2D.new()
			star.texture = UI.tex("res://assets/icons/bintang.png")
			star.scale = Vector2(2, 2)
			star.position = pos + Vector2(80, -170)
			star.z_index = 30
			world.add_child(star)
	var sp: Dictionary = layout["special"]
	add_texture_obj("muzium", "res://assets/objects/bangunan_muzium.png", Vector2(sp["muzium"][0], sp["muzium"][1]), 4, "Muzium Peribadi")
	add_texture_obj("arena", "res://assets/objects/bangunan_arena.png", Vector2(sp["arena"][0], sp["arena"][1]), 4, "Arena Ulang Kaji")
	add_texture_obj("t5", "res://assets/objects/bangunan_t5.png", Vector2(sp["t5"][0], sp["t5"][1]), 4, "Sejarah Tingkatan 5 (berkunci)")
	_refresh_markers()
	if params.get("first", false):
		await get_tree().create_timer(0.6).timeout
		await Game.say("peta_first")


func _refresh_markers() -> void:
	var nz := Game.next_zone()
	for z in Game.ZONES:
		set_marker("zone_" + z, z == nz)
	set_marker("flag_1", nz == "" and not Game.chapter_done(1))
	if nz != "":
		var zd := Game.zone_data(nz)
		Game.context_hint = "Pergi ke Zon %s: %s. Cari bangunan yang ada tanda seru." % [zd["no"], zd["title"]]
	else:
		Game.context_hint = "Bab 1 selesai! Buka Nota Alif untuk ulang kaji, atau lawati Muzium."


func on_interact(it: Dictionary) -> void:
	var id: String = it["id"]
	Game.save["map_pos"] = [player.global_position.x, player.global_position.y]
	if id.begins_with("zone_"):
		var z := id.trim_prefix("zone_")
		if Game.zone_unlocked(z):
			Game.persist()
			Game.goto("zone_prep", {"zone": z})
		else:
			await Game.say("zone_locked")
	elif id == "flag_1":
		await Game.say("flag_1_done" if Game.chapter_done(1) else "flag_1")
		if not Game.chapter_done(1) and Game.next_zone() == "":
			Game.goto("penutup")
	elif id.begins_with("flag_"):
		await Game.say("flag_locked")
	elif id == "muzium":
		Game.main.open_muzium()
	elif id == "arena":
		await Game.say("arena_locked")
		Game.persist()
		Game.goto("lobby")
	elif id == "t5":
		await Game.say("t5_locked")
