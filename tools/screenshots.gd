extends SceneTree
## Renders screenshots of the game for reviews: title, world 1 (stage at charge LV 3, Nova ready, Nova lance, boss), then a
## tunnel and the boss of every other world, and the ending.
## xvfb-run godot --path . --rendering-method gl_compatibility --script tools/screenshots.gd -- OUT_DIR

var main: Node3D
var out := "user://shots"


func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("saved ", name)


func run(n: int) -> void:
	for i in n:
		if not main.P.is_empty():
			main.P.inv = maxi(main.P.inv, 2) if main.P.inv > 2 else 0
		await physics_frame


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	await snap("title")
	main.latch["start"] = true
	await run(60)
	await snap("start")
	main.warp(1500)
	main.drop_item(main.P.x + 2, main.P.y, "P")
	main.drop_item(main.P.x + 2, main.P.y, "L")
	Input.action_press("fire")
	for i in 400:
		main.P.inv = 2
		if i == 150:
			Input.action_release("fire")
			Input.action_press("charge")
		if i == 150 + 170:
			await snap("stage")  # charged to LV 3
		await physics_frame
	await snap("nova_ready")  # held 4 s: the Nova stage
	Input.action_release("charge")
	await run(4)
	await snap("beam")  # the Nova lance
	main.warp(3290)
	for i in 700:
		main.P.inv = 2
		await physics_frame
	await snap("boss")
	for wi in range(1, Worlds.LIST.size()):
		main.teardown()
		main.new_game(wi)
		main.P.laser = 2
		var tu: Dictionary = main.wdef.terrain.tunnels[0]
		# just before the first gate inside the first tunnel
		var gx: float = tu.b
		for s in main.script_list:
			if s.type == "gate" and s.x > tu.a:
				gx = s.x
				break
		main.warp(gx - 300.0)
		Input.action_press("fire")
		for i in 330:
			main.P.inv = 2
			main.P.y = main.mid_y(main.G.scroll + main.P.x)
			await physics_frame
		Input.action_release("fire")
		await snap("w%d_tunnel" % (wi + 1))
		# a fortress room: towers, a locked gate or a gun line
		var fo: Dictionary = main.wdef.terrain.forts[0]
		main.warp(fo.a + 260.0)
		Input.action_press("fire")
		for i in 240:
			main.P.inv = 2
			main.P.y = main.mid_y(main.G.scroll + main.P.x)
			await physics_frame
		Input.action_release("fire")
		await snap("w%d_fort" % (wi + 1))
		main.warp(main.wdef.boss_at - 110.0)
		for i in 700:
			main.P.inv = 2
			await physics_frame
		await snap("w%d_boss" % (wi + 1))
	main.ending()
	for i in 60:
		await physics_frame
	await snap("ending")
	quit()
