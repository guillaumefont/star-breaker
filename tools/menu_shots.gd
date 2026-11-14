extends SceneTree
## Screenshots of the main menu and the Endless mode screens for reviews.
## xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 2400x1080 --script tools/menu_shots.gd -- OUT_DIR [touch] [crash]

var main: Node3D
var out := "user://shots"


func snap(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func run(n: int) -> void:
	for i in n:
		if not main.P.is_empty():
			main.P.inv = 2
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
	var tag := "%dx%d" % [root.get_visible_rect().size.x, root.get_visible_rect().size.y]
	if args.has("touch"):
		main.hud.set_touch_mode(true)
		tag += "_touch"
	if args.has("crash"):
		main.hud.show_crash_notice("Last line: 7.00 TICK t=240  ·  last new thing: spawn carrier", "report")
		tag += "_crash"
	main.bests = {normal = 184250, endless = 96400}
	main.hud.set_bests(main.fmt(184250), main.fmt(96400))
	main.hud.select_mode("normal")
	await snap("menu_" + tag)
	if args.has("touch") or args.has("crash"):
		quit()
		return
	main.hud.select_mode("endless")
	await snap("menu_endless_selected")
	main.new_game(0, "endless")
	main.G.lap = 1
	main.start_stage()
	await run(40)
	await snap("endless_lap2_banner")
	main.G.score = 123450
	main.G.world = 2
	main.G.lives = 0
	main.P.inv = 0
	main.kill_player()
	await run(150)
	await snap("endless_game_over")
	main.teardown()
	main.to_menu()
	main.new_game(0, "normal")
	await run(30)
	main.set_paused(true)
	await snap("pause_quit_to_menu")
	quit()
