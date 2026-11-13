extends SceneTree
## Renders a few screenshots of the game (title, stage, boss) for reviews.
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
	for i in 260:
		main.P.inv = 2
		if i == 150:
			Input.action_release("fire")
			Input.action_press("charge")
		await physics_frame
	await snap("stage")
	Input.action_release("charge")
	await run(4)
	await snap("beam")
	main.warp(3290)
	for i in 700:
		main.P.inv = 2
		await physics_frame
	await snap("boss")
	quit()
