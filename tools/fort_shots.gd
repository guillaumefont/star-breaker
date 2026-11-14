extends SceneTree
## Screenshots of the fortress sections of every world, for reviewing their decoration.
## xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 1600x720 --script tools/fort_shots.gd -- OUT_DIR

var main: Node3D
var out := "user://forts"


func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


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
	for i in 30:
		await physics_frame
	for wi in Worlds.LIST.size():
		main.teardown()
		main.new_game(wi)
		main.P.laser = 2
		var fo: Dictionary = main.wdef.terrain.forts[0]
		for k in 2:
			main.warp(fo.a + (260.0 if k == 0 else 700.0))
			Input.action_press("fire")
			for i in 200:
				main.P.inv = 2
				main.P.y = main.mid_y(main.G.scroll + main.P.x)
				await physics_frame
			Input.action_release("fire")
			await snap("w%d_fort%d" % [wi + 1, k + 1])
	quit()
