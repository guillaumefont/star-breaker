extends SceneTree
## Fortress decoration (FortDeco): every world's fortress chunks get dressing, a back wall
## and lit windows for a handful of extra draw calls; nothing in front of the play plane
## reaches into the corridor; cave chunks stay undecorated; tower pillars carry their strips.

var main: Node3D
var fails := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		fails += 1


func meshes(g: Node3D) -> Array:
	return g.get_children().filter(func(n): return n is MeshInstance3D)


func mats(list: Array) -> Array:
	return list.map(func(n): return (n as MeshInstance3D).get_surface_override_material(0))


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	await process_frame
	print("Star Breaker fortress decoration test")
	for wi in Worlds.LIST.size():
		main.new_game(wi)
		var w: Dictionary = main.wdef
		check(w.has("fdeco"), "%s: has a fortress theme" % w.name)
		var worst := 0.0
		var extra_max := 0
		var walls := 0
		for fo in w.terrain.forts:
			for c in range(ceili((fo.a + 40.0) / main.CH), floori((fo.b - 40.0) / main.CH)):
				var g: Node3D = main.build_chunk(c)
				var deco := meshes(g).filter(func(n): return not (n.get_surface_override_material(0) in [Models.M.fort_a, Models.M.fort_b]))
				extra_max = maxi(extra_max, deco.size())
				if Models.M.fort_back in mats(deco):
					walls += 1
				for n in deco:
					var verts: PackedVector3Array = (n as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
					for v in verts:
						if v.z < -10.0:
							continue  # props and the back wall stand behind the play plane
						var hv: Vector2 = Worlds.heights(w, c * main.CH + v.x)
						var top: float = main.PH / 2.0 - hv.x
						var bot: float = -main.PH / 2.0 + hv.y
						var d := minf(top - v.y, v.y - bot)
						if d > 0.6 and d > worst:
							print("   in corridor: c=%d mat=%s v=%s top=%.1f bot=%.1f" % [c, n.get_surface_override_material(0).albedo_color, v, top, bot])
						worst = maxf(worst, d)
				g.queue_free()
		check(extra_max >= 4 and extra_max <= 7, "%s: dressing adds %d draw calls per chunk at most" % [w.name, extra_max])
		check(walls > 10, "%s: fortress chunks have a back wall (%d chunks)" % [w.name, walls])
		check(worst < 0.6, "%s: nothing in front of the play plane reaches into the corridor (worst %.2f)" % [w.name, worst])
	# cave chunks stay as they were
	main.new_game(0)
	var cave: Node3D = main.build_chunk(int(1200.0 / main.CH))
	var cm := mats(meshes(cave))
	check(not (Models.M.fort_back in cm) and not (Models.M.fort_trim in cm), "cave chunks get no fortress dressing")
	cave.queue_free()
	# tower pillars carry their grooves and lit strip
	var fo0: Dictionary = main.wdef.terrain.forts[0]
	main.warp(fo0.a + 100.0)
	var t := 0
	while main.G.gates.is_empty() and t < 1500:
		main.P.inv = 2
		main.update()
		main._process(1.0 / 60.0)
		t += 1
	check(not main.G.gates.is_empty(), "a fortress gate shows up")
	if not main.G.gates.is_empty():
		var u: Dictionary = main.G.gates[0].m.get_meta("u")
		check((u.top_strip as Node3D).transform == (u.top as Node3D).transform and (u.bot_rib as Node3D).transform == (u.bot as Node3D).transform,
			"gate pillars carry their strips")
	# no pop-in at the screen edges: at every screen shape, the chunks built cover all of the
	# deepest plane (the back wall) the camera can see
	main.new_game(0)
	var fo1: Dictionary = main.wdef.terrain.forts[0]
	var depth: float = main.CAM.z - FortDeco.BACK_Z
	var tv := tan(deg_to_rad(main.camera.fov) / 2.0)
	for aspect in [4.0 / 3.0, 16.0 / 9.0, 2410.0 / 1080.0, 21.0 / 9.0]:
		main.xm = maxf(0.0, aspect / (16.0 / 9.0) - 1.0) * main.W / 2.0
		var hw := tv * maxf(aspect, 16.0 / 9.0) * depth
		var ok := true
		var scroll: float = fo1.a
		while scroll < fo1.a + 400.0:
			main.update_chunks(scroll)
			var keys: Array = main.chunks.keys()
			var left: float = keys.min() * main.CH - scroll - main.W / 2.0
			var right: float = (keys.max() + 1) * main.CH - scroll - main.W / 2.0
			ok = ok and left <= -hw and right >= hw
			scroll += 3.0
		check(ok, "aspect %.2f: chunks cover the whole visible back wall (%.0f units each side)" % [aspect, hw])
	main.xm = 0.0
	print("fortress decoration test: ", "PASS" if fails == 0 else "%d FAIL" % fails)
	quit(1 if fails else 0)
