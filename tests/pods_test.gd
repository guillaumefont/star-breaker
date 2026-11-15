extends SceneTree
## Two pods: a second P item docks a pod on the tail, one Pod tap launches both and another
## recalls them, both shoot and block bullets, and a lost ship drops only one of them.

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


func press(a: String) -> void:
	main.latch[a] = true


func pick(k: String) -> void:
	main.drop_item(main.P.x, main.P.y, k)
	tick(2)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	await process_frame
	print("Star Breaker two pods test")

	main.new_game(0, "normal")
	tick(120)
	main.G.enemies.map(func(e): e.dead = true)
	main.P.inv = 9999

	# first P docks the nose pod, the second docks a pod on the tail
	pick("P")
	check(main.pod.state == "front" and main.pod2.state == "none", "first P item docks one pod in front")
	pick("P")
	check(main.pod2.state == "back", "second P item docks a second pod at the back")
	check(main.pod2.x < main.P.x and main.pod.x > main.P.x, "one pod sits on the nose, the other on the tail")
	tick(20)
	check(main.pod_m.visible and main.pod2_m.visible, "both pods are drawn")
	check(main.pod2_m.global_basis.x.normalized().dot(Vector3.LEFT) > 0.99, "the rear pod faces backwards")
	var laser: int = main.P.laser
	pick("P")
	check(main.P.laser == laser + 1, "a third P item upgrades the laser instead")

	# both pods shoot: one forward, one backward
	main.G.pb.map(func(b): b.dead = true)
	tick()
	main.fire_shot(false)
	var back: Array = main.G.pb.filter(func(b): return b.vx < 0)
	check(back.size() == 1, "the rear pod shoots backwards")

	# the rear pod blocks bullets from behind
	main.bullet(main.pod2.x - 8, main.pod2.y, 2.0, 0.0)
	var b: Dictionary = main.G.eb[-1]
	main.P.inv = 0
	tick(5)
	check(b.dead and main.P.alive, "the rear pod blocks a bullet from behind")
	main.P.inv = 9999

	# one tap launches both, the next recalls both
	main.P.x = 110.0
	tick()
	press("pod")
	tick()
	check(main.pod.state == "free" and main.pod2.state == "free", "one Pod tap launches both pods")
	tick(30)
	check(main.pod.x > main.P.x + 20 and main.pod2.x < main.P.x - 5, "the front pod flies forward, the rear pod backwards")
	press("pod")
	tick()
	check(main.pod.state == "return" and main.pod2.state == "return", "the next tap recalls both")
	for i in 200:
		tick()
		if main.pod.state in ["front", "back"] and main.pod2.state in ["front", "back"]:
			break
	check(main.pod.state in ["front", "back"] and main.pod2.state in ["front", "back"] and main.pod.state != main.pod2.state,
		"both pods dock again, one on each side (%s, %s)" % [main.pod.state, main.pod2.state])

	# a lost ship drops only one pod
	main.G.items.map(func(it): it.dead = true)
	tick()
	main.P.inv = 0
	main.kill_player()
	check(main.pod.state == "none" and main.pod2.state == "none", "a lost ship loses both pods")
	var drops: Array = main.G.items.filter(func(it): return it.kind == "P" and not it.dead)
	check(drops.size() == 1, "only one pod falls off as a P item (%d)" % drops.size())

	# a new world starts with the pods docked front and back
	main.P.alive = true
	main.P.inv = 9999
	main.pod.state = "free"
	main.pod2.state = "front"
	main.start_stage()
	check(main.pod.state == "front" and main.pod2.state == "back", "a new world docks the first pod in front and the second behind")

	print("FAILED: %d" % fails if fails else "ALL OK")
	quit(1 if fails else 0)
