extends SceneTree
## Renders the game's real pod (the cyan crystal with its ring and pink shards) at a three
## quarter angle on a transparent background, then the ship docked behind it (the pod on its
## nose, as in the game). store/pod.png is the pod alone, 1024 px; store/ship-pod.png is the
## ship and pod on a canvas three times wider with the same projection (its centre 1024 px are
## pixel for pixel the pod shot), so the ship can reach past the pod's frame. tools/icon.py
## builds the app icons from both. Run it again after changing a model, then tools/icon.py.
## xvfb-run -a -s "-screen 0 1400x1200x24" godot --path . --rendering-method gl_compatibility \
##     --resolution 3072x3072 --script tools/icon_shots.gd   (needs a 3072 px screen:
##     xvfb-run -a -s "-screen 0 3200x3200x24")

const OUT := "res://store/pod.png"
const SHIP_OUT := "res://store/ship-pod.png"
const K := 3  # canvas size in pod frames


func _initialize() -> void:
	var size := 1024 * K
	DisplayServer.window_set_size(Vector2i(size, size))
	root.size = Vector2i(size, size)
	root.transparent_bg = true
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	await process_frame
	Models.init()
	var scene := Node3D.new()
	root.add_child(scene)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8f8cc4")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	scene.add_child(we)
	# the game's lights: warm sun, pink rim, violet fill from below
	for l in [["fff0dd", 1.25, Vector3(-40, 90, 120)], ["ff4fa3", 0.6, Vector3(80, -40, -60)], ["4a2050", 0.5, Vector3(0, -100, 30)]]:
		var d := DirectionalLight3D.new()
		d.light_color = Color(l[0])
		d.light_energy = l[1]
		scene.add_child(d)
		d.look_at_from_position(l[2], Vector3.ZERO)
	var pod := Models.pod()
	(pod.get_meta("spin") as Node3D).rotation.x = 0.35
	scene.add_child(pod)
	var cam := Camera3D.new()
	# the 40 degree pod shot, widened K times around the same centre
	cam.fov = rad_to_deg(2.0 * atan(K * tan(deg_to_rad(20.0))))
	scene.add_child(cam)
	cam.position = Vector3(7, 4, 13)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.get_region(Rect2i(1024 * (K - 1) / 2, 1024 * (K - 1) / 2, 1024, 1024)).save_png(ProjectSettings.globalize_path(OUT))
	# the ship, nose on the pod, its engine flame off
	var ship := Models.ship()
	ship.position = Vector3(-11.6, 0.55, 0)
	(ship.get_meta("flame") as Node3D).visible = false
	scene.add_child(ship)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SHIP_OUT))
	print("saved ", OUT, " and ", SHIP_OUT)
	quit()
