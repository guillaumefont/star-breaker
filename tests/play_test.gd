extends SceneTree
## Headless playthrough of world 1: title -> The Hollow Moon (every enemy type, items, pod,
## charge beam, tunnel and gates) -> Bloom Mother -> world 2 starts -> game over, continue,
## back to the title. Fails on any assertion. The rest of the campaign is in campaign_test.gd.

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
	main.hud.select_mode("normal")
	press("start")
	tick()
	check(main.mode == "play", "Play starts a run")
	tick(80)
	check(not main.P.entering, "ship flies in and takes control")

	# weapons
	var before: int = main.G.pb.size()
	Input.action_press("fire")
	tick()
	Input.action_release("fire")
	var after_tap: int = main.G.pb.size()
	check(after_tap == before + 1 and main.G.pb[-1].dmg == 2, "tapping Fire shoots one heavy shot")
	tick(20)
	check(main.G.pb.size() == after_tap, "a tap never turns into rapid fire")
	Input.action_press("fire")
	tick(40)
	Input.action_release("fire")
	check(main.G.pb.size() >= after_tap + 4 and main.G.pb[-1].dmg == 1, "holding Fire streams rapid shots")
	Input.action_press("charge")
	tick(105)
	check(main.charge_lv(main.P.charge) == 2, "charging is slower: 105 ticks only reach level 2")
	tick(60)
	check(main.charge_lv(main.P.charge) == 3, "charge reaches level 3")
	Input.action_release("charge")
	tick()
	var beams: Array = main.G.pb.filter(func(b): return b.beam)
	check(beams.size() == 1 and not beams[0].nova and beams[0].dmg == 18, "releasing charge fires a piercing beam")
	var line: Dictionary = beams[0]
	check(line.line and absf(line.sx - (main.P.x + 9)) < 0.01 and line.ex > main.P.x + 60 and line.y == main.P.y,
			"the beam is a laser line from the nose across the screen")
	main.P.y += 6
	tick()
	check(line.y == main.P.y and not line.dead, "the laser line follows the ship while it lasts")
	check(not line.parts.has("tw"), "levels 1 to 3 have no twister")
	tick(main.BEAM_LIFE[3])
	check(line.dead, "the laser line switches off after its time")
	check(main.line_fade(0, 20) > main.line_fade(10, 20) and main.line_fade(20, 20) == 0.0, "the line flashes open and narrows away")
	tick(20)

	# Nova: the extra fourth stage after 4 seconds; a bigger beam that burns enemy bullets away
	Input.action_press("charge")
	tick(main.CHARGE_AT[4] - 1)
	check(main.charge_lv(main.P.charge) == 3, "the Nova stage isn't ready a tick early")
	tick()
	check(main.charge_lv(main.P.charge) == 4, "holding 4 seconds reaches the Nova stage")
	main._process(0.016)
	check(main.swirl.visible and main.charge_orb.material_override == Models.M.nova_orb, "the charge swirl turns pink when the Nova is ready")
	check(main.swirl.get_children().all(func(n): return n.visible), "the swirl is at its fullest at the Nova stage")
	tick(60)
	check(main.P.charge == main.CHARGE_MAX, "charge stops at the Nova stage")
	var n_eb: int = main.G.eb.size()
	for i in 3:
		main.bullet(main.P.x + 20 + i * 8, main.P.y, -0.5, 0)
	var mine: Array = main.G.eb.slice(n_eb)
	Input.action_release("charge")
	tick()
	var novas: Array = main.G.pb.filter(func(b): return b.beam and b.nova)
	check(novas.size() == 1 and novas[0].dmg > 18 and novas[0].hh > 4.6, "releasing at the Nova stage fires the Nova lance")
	main._process(0.016)
	check(not main.swirl.visible and not main.charge_orb.visible, "the charge swirl goes away once fired")
	check(novas[0].parts.has("tw"), "the Nova laser has the twister")
	tick(8)
	check(mine.all(func(b): return b.dead), "the Nova lance burns away enemy bullets in its path")

	# pod
	main.drop_item(main.P.x + 4, main.P.y, "P")
	tick(2)
	check(main.pod.state == "front", "P item docks the pod in front")
	var spin: Node3D = main.pod_m.get_meta("spin")
	var r0 := spin.rotation.x
	tick(10)
	check(absf(spin.rotation.x - r0) > 0.5 and spin.rotation.y == 0.0 and spin.rotation.z == 0.0, "pod spins around its long axis only")
	check(main.pod_m.global_basis.x.normalized().dot(Vector3.RIGHT) > 0.99, "pod's axis runs along the ship, emitter forward")
	var idle := absf(spin.rotation.x - r0) / 10.0
	Input.action_press("charge")
	tick(main.CHARGE_AT[3])
	r0 = spin.rotation.x
	tick(10)
	check(absf(spin.rotation.x - r0) / 10.0 > idle * 3.0, "a docked pod spins up while charging")
	Input.action_release("charge")
	tick()
	var pod_line: Array = main.G.pb.filter(func(b): return b.get("line", false))
	check(pod_line.size() == 1 and absf(pod_line[0].sx - (main.pod.x + 5)) < 0.01, "with the pod docked in front the laser leaves from the pod")
	tick(30)
	main.pod.state = "back"
	tick(20)
	check(main.pod_m.global_basis.x.normalized().dot(Vector3.LEFT) > 0.99, "pod docked behind turns to face backwards")
	main.pod.state = "front"
	tick(20)
	press("pod")
	tick()
	check(main.pod.state == "free", "pod launches")
	tick(40)
	press("pod")
	tick()
	check(main.pod.state == "return", "pod is recalled")
	tick(90)
	check(main.pod.state == "front" or main.pod.state == "back", "pod docks again")
	main.P.laser = 0
	main.P.speed = 0
	main.drop_item(main.P.x + 4, main.P.y, "L")
	main.drop_item(main.P.x + 4, main.P.y, "S")
	tick(2)
	check(main.P.laser == 1 and main.P.speed == 1, "L and S items upgrade laser and speed (%d, %d)" % [main.P.laser, main.P.speed])

	# fly the whole stage with rapid fire and a weaving ship
	var seen := {}
	var killed_score: int = main.G.score
	Input.action_press("fire")
	var fort_seen := false
	for i in 16000:
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
		fort_seen = fort_seen or Worlds.in_fort(main.wdef, main.G.scroll + main.P.x)
		if main.G.boss:
			break
	Input.action_release("up")
	Input.action_release("down")
	var five := ["drifter", "turret", "hopper", "carrier", "shell"]
	check(five.all(func(t): return seen.has(t)), "all five moon enemy types appear: %s" % ", ".join(seen.keys()))
	check(seen.has("gun") and seen.has("generator"), "fortress towers (with guns) and locked gates (with generators) appear")
	check(fort_seen, "the level passes through fortress sections")
	check(main.G.t > 13000, "the level lasts much longer than before (%d s)" % (main.G.t / 60))
	check(main.G.score > killed_score, "shooting enemies scores (%d)" % main.G.score)
	check(main.G.warned and main.G.boss != null, "warning shows, then Bloom Mother arrives")
	check(main.chunks.size() > 0, "cave terrain streams in")
	check(Diag._seen.has("gate fixed") and Diag._seen.has("gate slide"), "the tunnel's gates appeared")

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
	check(main.G.boss == null and main.G.clear_t > 0, "World Clear")
	tick(200)
	check(main.P.exiting and main.P.x > 60, "the ship flies off after the boss")
	tick(140)
	check(main.G.world == 1 and main.G.scroll < 40 and main.wdef.name == "Frost Rift", "world 2 starts (%s), no loop" % main.wdef.name)
	check(main.G.score > 10000, "score carries over between worlds")
	Input.action_release("fire")

	# game over in world 2: continue from world 2, score reset
	main.G.lives = 0
	main.P.inv = 0
	main.kill_player()
	tick(130, false)
	check(main.mode == "over", "losing the last ship ends the run")
	tick(60, false)
	press("start")
	tick(1, false)
	check(main.mode == "play" and main.G.world == 1 and main.G.score == 0, "Continue restarts world 2 with the score reset")
	main.G.lives = 0
	main.P.inv = 0
	main.kill_player()
	tick(190, false)
	main.hud.title_pressed.emit()
	tick(1, false)
	check(main.mode == "title", "the Title button goes back to the title")
	tick(1, false)
	press("start")
	tick(1, false)
	check(main.mode == "play", "a second run starts cleanly")

	print("%d failure(s)" % fails)
	quit(1 if fails else 0)
