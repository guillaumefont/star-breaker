extends SceneTree
## Renders the game's real pod (the cyan crystal with its ring and pink shards) at a three
## quarter angle on a transparent background: store/pod.png, the artwork tools/icon.py builds
## the app icons from. Run it again after changing the pod model, then tools/icon.py.
## xvfb-run -a -s "-screen 0 1400x1200x24" godot --path . --rendering-method gl_compatibility \
##     --resolution 1024x1024 --script tools/icon_shots.gd

const OUT := "res://store/pod.png"


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1024, 1024))
	root.size = Vector2i(1024, 1024)
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
	cam.fov = 40.0
	scene.add_child(cam)
	cam.position = Vector3(7, 4, 13)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("saved ", OUT, " ", img.get_size())
	quit()
