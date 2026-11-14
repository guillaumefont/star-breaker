extends SceneTree
## Difficulty once powered up: power-ups are spaced out, a lost ship costs the pod and the
## lasers (the pod can be caught again), the pod shields more than it kills, the spread's
## angled shots stay light, and later worlds hit harder.

var main: Node3D
var fails := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		fails += 1


func tick(n := 1) -> void:
	for i in n:
		main.update()
		main._process(1.0 / 60.0)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	await process_frame
	print("Star Breaker balance test")

	# power-ups: spaced out in every world, first pod still early in world 1
	for wi in Worlds.LIST.size():
		var xs: Array = []
		for e in Worlds.script(wi):
			if e.type == "carrier":
				xs.append(e.x)
		var gap := INF
		for k in range(1, xs.size()):
			gap = minf(gap, xs[k] - xs[k - 1])
		check(xs.size() >= 3 and xs.size() <= 6 and gap >= Worlds.DROP_GAP,
			"world %d: %d power-ups, at least %d units apart (closest %d)" % [wi + 1, xs.size(), Worlds.DROP_GAP, gap])
		var kinds: Array = Worlds.script(wi).filter(func(e): return e.type == "carrier").map(func(e): return e.drop)
		check(kinds.slice(0, 3) == ["P", "L", "S"], "world %d drops the pod, then a laser, then speed (%s)" % [wi + 1, kinds])
	var w1: Array = Worlds.script(0).filter(func(e): return e.type == "carrier")
	check(w1[0].x < 600, "world 1 still hands out the pod in its first seconds")

	main.new_game(0, "normal")
	tick(80)
	main.G.enemies.map(func(e): e.dead = true)

	# losing a ship costs the power-ups
	main.drop_item(main.P.x, main.P.y, "P")
	tick(2)
	main.P.laser = 2
	main.P.speed = 2
	main.P.inv = 0
	var px: float = main.P.x
	main.kill_player()
	check(main.P.laser == 0 and main.P.speed == 1, "a lost ship drops the lasers to one shot and loses a speed step")
	check(main.pod.state == "none", "a lost ship loses the pod")
	var drops: Array = main.G.items.filter(func(it): return it.kind == "P")
	check(drops.size() == 1, "the pod falls off as a P item")
	# fly back through it after respawning to get it back
	for i in 400:
		if main.P.alive and not main.P.entering and not drops[0].dead:
			main.P.x = drops[0].x
			main.P.y = drops[0].y
		tick()
		if main.pod.state != "none":
			break
	check(main.pod.state == "front" or main.pod.state == "back", "flying through the dropped pod docks it again")

	# the pod shields but rams for little
	var e: Dictionary = main.E("shell", main.pod.x, main.pod.y, {stay = 9999, by = 60.0})
	var hp0: float = e.hp
	for i in 60:
		e.x = main.pod.x
		e.y = main.pod.y
		main.P.inv = 2
		tick()
	check(hp0 - e.hp >= 4 and hp0 - e.hp <= 60.0 / main.POD_RAM_CD + 1, "pod ram does about %d damage a second (%d)" % [60 / main.POD_RAM_CD, hp0 - e.hp])
	e.dead = true

	# the laser spread: only the straight shots carry the heavy shot's damage
	main.G.pb.map(func(b): b.dead = true)
	tick()
	main.pod.state = "none"
	main.P.laser = 2
	main.fire_shot(false)
	var angled: Array = main.G.pb.filter(func(b): return b.vy != 0.0)
	var straight: Array = main.G.pb.filter(func(b): return b.vy == 0.0)
	check(angled.size() == 2 and angled.all(func(b): return b.dmg == 1), "angled spread shots do 1 damage")
	check(straight.size() == 2 and straight.all(func(b): return b.dmg == 2), "straight heavy shots still do 2")

	# later worlds hit harder
	var h1: float = main.E("shell", 300, 60, {stay = 9999, by = 60.0}).hp
	var b1: float = main.bm()
	main.G.world = 5
	var h6: float = main.E("shell", 300, 60, {stay = 9999, by = 60.0}).hp
	check(h6 >= h1 * 1.9, "world 6 enemies have about twice world 1's hit points (%d vs %d)" % [h6, h1])
	check(main.bm() >= b1 * 1.45, "world 6 bullets are 50%% faster (%.2f)" % main.bm())
	main.G.lap = 20
	check(main.bm() == main.BM_MAX, "bullet speed is capped on late Endless laps")

	print("FAILED: %d" % fails if fails else "ALL OK")
	quit(1 if fails else 0)
