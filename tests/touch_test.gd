extends SceneTree
## Touch controls: tap anywhere starts, floating stick on the left moves the ship,
## invisible zones on the right fire, rapid fire, charge and launch the pod.

var main: Node3D
var fails := 0


func check(cond: bool, what: String) -> void:
	print("  ok   " if cond else "  FAIL ", what)
	if not cond:
		fails += 1


func tick(n := 1) -> void:
	for i in n:
		if not main.P.is_empty():
			main.P.inv = maxi(main.P.inv, 2)
		main.update()
		main._process(1.0 / 60.0)


func touch(i: int, pos: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = pos
	e.pressed = down
	root.push_input(e, true)


func drag(i: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = pos
	root.push_input(e, true)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	await process_frame
	var vs: Vector2 = root.get_visible_rect().size
	print("Touch test (viewport %s)" % vs)
	var tp: TouchPad = main.hud.touch
	touch(0, vs * 0.5, true)
	touch(0, vs * 0.5, false)
	check(tp.enabled, "first touch switches to touch controls")
	tick()
	check(main.mode == "play", "tapping the title starts a run")
	tick(80)

	var x0: float = main.P.x
	touch(1, Vector2(vs.x * 0.2, vs.y * 0.6), true)
	check(tp.stick_id == 1, "stick appears where the left thumb lands")
	drag(1, Vector2(vs.x * 0.2 + 200, vs.y * 0.6))
	check(tp.ax > 0.95 and absf(tp.ay) < 0.05, "stick reads full right")
	check(tp.origin.x > vs.x * 0.2, "stick base follows the thumb past its rim")
	tick(20)
	check(main.P.x > x0 + 15, "ship moves with the stick")
	touch(1, Vector2(vs.x * 0.2 + 200, vs.y * 0.6), false)
	check(tp.stick_id == -1, "stick disappears on release")

	var n: int = main.G.pb.size()
	touch(2, Vector2(vs.x * 0.57, vs.y * 0.7), true)
	touch(2, Vector2(vs.x * 0.57, vs.y * 0.7), false)
	tick()
	check(main.G.pb.size() > n, "a quick tap in the Fire zone shoots")

	touch(3, Vector2(vs.x * 0.74, vs.y * 0.7), true)
	tick(30)
	check(main.G.pb.size() >= n + 4, "holding the Rapid zone keeps firing")
	touch(3, Vector2(vs.x * 0.74, vs.y * 0.7), false)

	touch(4, Vector2(vs.x * 0.9, vs.y * 0.7), true)
	tick(105)
	check(main.charge_lv(main.P.charge) == 3, "holding the Charge zone charges")
	touch(4, Vector2(vs.x * 0.9, vs.y * 0.7), false)
	tick()
	check(main.G.pb.any(func(b): return b.beam), "releasing Charge fires the beam")

	main.drop_item(main.P.x, main.P.y, "P")
	tick(2)
	touch(5, Vector2(vs.x * 0.75, vs.y * 0.3), true)
	touch(5, Vector2(vs.x * 0.75, vs.y * 0.3), false)
	tick()
	check(main.pod.state == "free", "tapping the top-right strip launches the pod")

	var pause_btn: Button = main.hud._btn_pause
	var bp := pause_btn.get_global_rect().get_center()
	touch(6, bp, true)
	touch(6, bp, false)
	tick()
	check(main.pod.state == "free", "touching the HUD buttons never fires the pod zone")

	print("%d failure(s)" % fails)
	quit(1 if fails else 0)
