extends SceneTree
## Frames of the charge weapon in motion: charge to each level and fire with no pod, then
## charge to the Nova and fire with the pod docked at the nose. One PNG every `EVERY` ticks.
## xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script tools/charge_anim.gd -- OUT_DIR

const EVERY := 3
var main: Node3D
var out := "user://charge_anim"
var frame := 0
var tick := 0
var no_pod := true


func step(n: int, record := true) -> void:
	for i in n:
		if not main.G.is_empty() and not main.P.is_empty():
			main.P.inv = 0
			main.G.lives = 5
			main.G.si = main.script_list.size()
			for e in main.G.enemies:
				e.x = -500.0
			for b in main.G.eb:
				b.dead = true
			main.P.y = 63.0
			main.P.x = 40.0
			if no_pod:
				main.pod.state = "none"
				main.pod2.state = "none"
		await physics_frame
		tick += 1
		if record and tick % EVERY == 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("f%04d.png" % frame))
			frame += 1


func charge_and_fire(lv: int) -> void:
	Input.action_press("charge")
	await step(main.CHARGE_AT[lv] + 25)
	Input.action_release("charge")
	await step(50)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(args[0])
	out = args[0]
	Engine.max_physics_steps_per_frame = 1
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	main.latch["start"] = true
	await step(200, false)
	for lv in [1, 2, 3, 4]:
		await charge_and_fire(lv)
	no_pod = false
	main.drop_item(main.P.x + 2, main.P.y, "P")
	await step(20, false)
	await charge_and_fire(4)
	quit()
