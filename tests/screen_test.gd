extends SceneTree
## Crash report and screen fill: a log without a clean ending is reported and turns on safe
## graphics (Compatibility renderer from the next launch); wide and narrow screens are
## filled with the camera and spawn margin adjusted.

var fails := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		fails += 1


func _initialize() -> void:
	print("Star Breaker crash report + screen fill test")
	# a previous session that died mid-game
	var f := FileAccess.open(Diag.PATH, FileAccess.WRITE)
	f.store_string("   0.01 START test\n   3.20 PLAY \n   6.80 FIRST spawn carrier\n   7.00 TICK t=240\n")
	f.close()
	Diag.set_safe(false)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	await process_frame
	check(Diag.crashed, "an unfinished log is detected as a crash")
	check(Diag.safe, "safe graphics switched on after a crash")
	check(FileAccess.file_exists(Diag.OVERRIDE) and FileAccess.get_file_as_string(Diag.OVERRIDE).contains("gl_compatibility"),
		"Compatibility renderer requested for the next launch")
	check(Diag.summary().contains("spawn carrier"), "summary names the last new thing: " + Diag.summary())
	check(Diag.report().contains("TICK t=240"), "report holds the previous log")
	check(main.hud._crash.visible, "title screen shows the crash notice")
	check(not main._env.glow_enabled and main.get_viewport().msaa_3d == Viewport.MSAA_DISABLED, "glow and MSAA off in safe mode")
	main.hud._btn_gfx.pressed.emit()
	check(not Diag.safe and not FileAccess.file_exists(Diag.OVERRIDE) and main._env.glow_enabled, "toggle back to full graphics")
	check(FileAccess.get_file_as_string(Diag.PATH).contains("START"), "this session is logging")

	# screen shapes
	for sz in [Vector2i(2400, 1080), Vector2i(1280, 720), Vector2i(1024, 768)]:
		root.size = sz
		await process_frame
		main._on_resize()
		var vs: Vector2 = main.get_viewport().get_visible_rect().size
		var aspect: float = vs.x / vs.y
		check(absf(aspect - float(sz.x) / sz.y) < 0.02, "%s: canvas expands to the screen shape (%.2f)" % [sz, aspect])
		if aspect > 1.8:
			check(main.xm > 20.0 and main.camera.keep_aspect == Camera3D.KEEP_HEIGHT, "%s: wider view, margin %.1f" % [sz, main.xm])
			# the spawn edge must be off screen
			var cam: Camera3D = main.camera
			var edge := cam.unproject_position(Vector3(main.X(main.W + main.xm), main.Y(63), 0))
			check(edge.x >= main.get_viewport().get_visible_rect().size.x - 2, "%s: spawns happen off screen (%.0f)" % [sz, edge.x])
		else:
			check(main.xm == 0.0, "%s: no side margin" % sz)
	main.hud.apply_safe_area()

	Diag.note("QUIT")
	Diag.set_safe(false)
	print("FAILED %d" % fails if fails else "ALL PASSED")
	quit(1 if fails else 0)
