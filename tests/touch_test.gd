extends SceneTree
## Touch controls: tapping a mode card starts, floating stick on the left moves the ship,
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
	check(main.mode == "title", "a tap beside the mode cards doesn't start a run")
	var card: Rect2 = main.hud._cards.normal.button.get_global_rect()
	check(main.hud.card_at(card.get_center()) == "normal", "the Normal card is under its own centre")
	touch(0, card.get_center(), true)
	touch(0, card.get_center(), false)
	tick()
	check(main.mode == "play" and not main.endless(), "tapping the Normal card starts a campaign run")
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
	var fire_at := Vector2(vs.x * 0.75, vs.y * 0.85)
	var charge_at := Vector2(vs.x * 0.75, vs.y * 0.5)
	for fx in [0.55, 0.75, 0.95]:
		check(TouchPad.zone_at(fx, 0.9) == "fire" and TouchPad.zone_at(fx, 0.7) == "fire"
			and TouchPad.zone_at(fx, 0.5) == "charge" and TouchPad.zone_at(fx, 0.2) == "pod"
			and TouchPad.zone_at(fx, 0.02) == "pod",
			"right side stacks Fire, Charge, Pod bottom up at x=%.2f" % fx)
	touch(2, fire_at, true)
	touch(2, fire_at, false)
	tick()
	check(main.G.pb.size() == n + 1, "a quick tap in the Fire zone shoots once")

	touch(3, fire_at, true)
	tick(40)
	check(main.G.pb.size() >= n + 5, "holding the Fire zone streams rapid fire")
	touch(3, fire_at, false)

	touch(4, charge_at, true)
	tick(105)
	check(main.charge_lv(main.P.charge) == 3, "holding the Charge zone charges")
	touch(4, charge_at, false)
	tick()
	check(main.G.pb.any(func(b): return b.beam), "releasing Charge fires the beam")

	main.drop_item(main.P.x, main.P.y, "P")
	tick(2)
	touch(5, Vector2(vs.x * 0.75, vs.y * 0.2), true)
	touch(5, Vector2(vs.x * 0.75, vs.y * 0.2), false)
	tick()
	check(main.pod.state == "free", "tapping the top-right zone launches the pod")

	var pause_btn: Button = main.hud._btn_pause
	var bp := pause_btn.get_global_rect().get_center()
	touch(6, bp, true)
	touch(6, bp, false)
	tick()
	check(main.pod.state == "free", "touching the HUD buttons never fires the pod zone")

	print("%d failure(s)" % fails)
	quit(1 if fails else 0)
