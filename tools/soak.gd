extends SceneTree
## Real-time soak run with simulated touch play (stick, Fire taps and holds, Charge, Pod),
## no invincibility. Prints progress; any crash or script error shows in the log.
## godot --path . --script tools/soak.gd -- SECONDS [WORLD]   (WORLD 1-4, default 1)

var main: Node3D
var vs := Vector2(1280, 720)


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
	var secs := 40.0
	var start_world := 0
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		secs = float(args[0])
	if args.size() > 1:
		start_world = clampi(int(args[1]) - 1, 0, 3)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	vs = root.get_visible_rect().size
	var t0 := Time.get_ticks_msec()
	var frame := 0
	var stick := Vector2(vs.x * 0.2, vs.y * 0.6)
	var fire_down := false
	var charge_down := false
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		frame += 1
		if main.mode != "play" and start_world > 0 and main.mode == "title":
			main.new_game(start_world)
		elif main.mode != "play":
			touch(9, vs * 0.5, true)
			touch(9, vs * 0.5, false)
		else:
			if frame % 90 == 1:
				touch(1, stick, true)
			drag(1, stick + Vector2(cos(frame * 0.05), sin(frame * 0.031)) * 80.0)
			if frame % 90 == 80:
				touch(1, stick, false)
			if frame % 25 == 0:
				fire_down = not fire_down
				touch(2, Vector2(vs.x * 0.86, vs.y * 0.7), fire_down)
			if frame % 150 == 0:
				charge_down = true
				touch(3, Vector2(vs.x * 0.62, vs.y * 0.7), true)
			if charge_down and frame % 150 == 110:
				charge_down = false
				touch(3, Vector2(vs.x * 0.62, vs.y * 0.7), false)
			if frame % 200 == 100:
				touch(4, Vector2(vs.x * 0.8, vs.y * 0.3), true)
				touch(4, Vector2(vs.x * 0.8, vs.y * 0.3), false)
		if frame % 120 == 0:
			print("t=%.1fs world=%s scroll=%d mode=%s score=%s lives=%s enemies=%d fx=%d nodes=%d" % [(Time.get_ticks_msec() - t0) / 1000.0, main.G.get("world", -1) + 1, main.G.get("scroll", 0), main.mode,
				main.G.get("score", 0), main.G.get("lives", 0), main.G.get("enemies", []).size(), main.fx.size(), main.world.get_child_count()])
		await process_frame
	print("soak done")
	quit()
