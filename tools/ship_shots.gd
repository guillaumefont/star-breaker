extends SceneTree
## Close-ups of the player ship and pod for design reviews.
## xvfb-run godot --path . --rendering-method gl_compatibility --script tools/ship_shots.gd -- OUT_DIR

var main: Node3D
var out := "user://ship_shots"


func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)


func hold(n: int) -> void:
	for i in n:
		main.P.inv = 0
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
	main.latch["start"] = true
	await hold(90)
	main.drop_item(main.P.x + 2, main.P.y, "P")
	await hold(20)
	# in-game framing, pod docked in front
	await snap("ingame")
	var cam := Camera3D.new()
	cam.fov = 40.0
	main.add_child(cam)
	cam.current = true
	var target := Vector3(main.X(main.P.x) + 5, main.Y(main.P.y), 0)
	for v in [["side", Vector3(0, 4, 42)], ["three_quarter", Vector3(-26, 16, 30)], ["top", Vector3(-6, 40, 14)], ["rear", Vector3(-38, 8, 16)]]:
		cam.position = target + (v[1] as Vector3)
		cam.look_at(target)
		await hold(1)
		await snap(v[0])
	main.camera.current = true
	# pod launched, mid-flight
	Input.action_press("pod")
	await hold(2)
	Input.action_release("pod")
	await hold(24)
	await snap("launched")
	quit()
