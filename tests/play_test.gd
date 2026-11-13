extends SceneTree
## Headless playthrough: title -> stage 1 (every enemy type, items, pod, charge beam)
## -> Bloom Mother -> stage clear -> loop 2 -> game over. Fails on any assertion.

var main: Node3D
var fails := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		fails += 1


func tick(n := 1, god := true) -> void:
	for i in n:
		if god and not main.P.is_empty():
			main.P.inv = maxi(main.P.inv, 2)
		main.update()
		main._process(1.0 / 60.0)


func press(a: String) -> void:
	main.latch[a] = true


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	await process_frame
	print("Star Breaker play test")
	check(main.mode == "title", "starts on the title screen")
	press("start")
	tick()
	check(main.mode == "play", "Play starts a run")
	tick(80)
	check(not main.P.entering, "ship flies in and takes control")

	# weapons
	var before: int = main.G.pb.size()
	press("fire")
	tick()
	check(main.G.pb.size() > before, "single fire shoots a heavy shot")
	Input.action_press("rapid")
	tick(30)
	Input.action_release("rapid")
	check(main.G.pb.size() >= 4, "rapid fire keeps shooting while held")
	Input.action_press("charge")
	tick(105)
	check(main.charge_lv(main.P.charge) == 3, "charge reaches level 3")
	Input.action_release("charge")
	tick()
	var beams: Array = main.G.pb.filter(func(b): return b.beam)
	check(beams.size() == 1, "releasing charge fires a piercing beam")

	# pod
	main.drop_item(main.P.x + 4, main.P.y, "P")
	tick(2)
	check(main.pod.state == "front", "P item docks the pod in front")
	press("pod")
	tick()
	check(main.pod.state == "free", "pod launches")
	tick(40)
	press("pod")
	tick()
	check(main.pod.state == "return", "pod is recalled")
	tick(90)
	check(main.pod.state == "front" or main.pod.state == "back", "pod docks again")
	main.drop_item(main.P.x + 4, main.P.y, "L")
	main.drop_item(main.P.x + 4, main.P.y, "S")
	tick(2)
	check(main.P.laser == 1 and main.P.speed == 1, "L and S items upgrade laser and speed")

	# fly the whole stage with rapid fire and a weaving ship
	var seen := {}
	var killed_score: int = main.G.score
	Input.action_press("rapid")
	for i in 7600:
		var up := (i / 90) % 2 == 0
		if up:
			Input.action_release("down")
			Input.action_press("up")
		else:
			Input.action_release("up")
			Input.action_press("down")
		tick()
		for e in main.G.enemies:
			seen[e.type] = true
		if main.G.boss:
			break
	Input.action_release("up")
	Input.action_release("down")
	check(seen.size() == 5, "all five enemy types appear: %s" % ", ".join(seen.keys()))
	check(main.G.score > killed_score, "shooting enemies scores (%d)" % main.G.score)
	check(main.G.warned and main.G.boss != null, "warning shows, then Bloom Mother arrives")
	check(main.chunks.size() > 0, "cave terrain streams in")

	# boss: break petals, tentacle tip, then the eye
	var B: Dictionary = main.G.boss
	tick(260)
	check(not B.enter, "boss settles on the right")
	for p in B.petals:
		p.hp = 0.5
	B.tent.hp = 0.5
	var t := 0
	while t < 2000 and (B.petals.any(func(p): return p.alive) or B.tent.alive):
		t += 1
		for part in main.G.bparts:
			if part.kind == "petal" or part.kind == "tip":
				main.boss_damage(part, 1)
				break
		tick()
	check(not B.petals.any(func(p): return p.alive), "all four petals destroyed")
	check(not B.tent.alive, "tentacle tip destroyed")
	t = 0
	while t < 600 and not B.core.open:
		t += 1
		tick()
	check(B.phase2 and B.core.open, "eye opens in phase two")
	var loop_before: int = main.G.loop
	t = 0
	while t < 600 and not B.dying:
		t += 1
		for part in main.G.bparts:
			if part.kind == "core":
				main.boss_damage(part, 5)
				break
		tick()
	check(B.dying > 0, "the eye can be destroyed")
	tick(160)
	check(main.G.boss == null and main.G.clear_t > 0, "Stage Clear")
	tick(340)
	check(main.G.loop == loop_before + 1 and main.G.scroll < 40, "stage loops harder (loop %d)" % main.G.loop)
	Input.action_release("rapid")

	# game over
	main.G.lives = 0
	main.P.inv = 0
	main.kill_player()
	tick(130, false)
	check(main.mode == "over", "losing the last ship ends the run")
	tick(60, false)
	press("start")
	tick(1, false)
	check(main.mode == "title", "game over returns to the title")
	tick(1, false)
	press("start")
	tick(1, false)
	check(main.mode == "play", "a second run starts cleanly")

	print("%d failure(s)" % fails)
	quit(1 if fails else 0)
