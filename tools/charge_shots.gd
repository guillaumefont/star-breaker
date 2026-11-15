extends SceneTree
## Review shots of the charge weapon: the charge-up (swirl at the nose, then with the pod
## docked) and the laser line at every level, including the Nova twister.
## xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 1600x720 --script tools/charge_shots.gd -- OUT_DIR

var main: Node3D
var out := "user://charge_shots"
var no_pod := true


func snap(name: String) -> void:
	main.P.inv = 0
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func hold(n: int) -> void:
	for i in n:
		if not main.G.is_empty() and not main.P.is_empty():
			main.P.inv = 2
			main.G.lives = 5
			for b in main.G.eb:
				b.dead = true
			main.P.y = 63.0
			main.P.x = 40.0
			if no_pod:
				main.pod.state = "none"
		await physics_frame


func charge_and_fire(tag: String, lv: int) -> void:
	Input.action_press("charge")
	await hold(main.CHARGE_AT[lv] + 6)
	await snap("%s_charge%d" % [tag, lv])
	Input.action_release("charge")
	await hold(5)
	await snap("%s_beam%d" % [tag, lv])
	await hold(70)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	main.latch["start"] = true
	await hold(120)
	for lv in [1, 2, 3, 4]:
		await charge_and_fire("nopod", lv)
	no_pod = false
	main.drop_item(main.P.x + 2, main.P.y, "P")
	await hold(30)
	for lv in [1, 2, 3, 4]:
		await charge_and_fire("pod", lv)
	quit()
