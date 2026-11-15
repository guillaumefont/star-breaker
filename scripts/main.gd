extends Node3D
## Star Breaker: game loop. Logic runs at a fixed 60 ticks per second in "stage units"
## (a 224 x 126 playfield, y pointing down) and is mirrored onto low poly 3D models.
## Two modes, picked on the main menu: Normal is a campaign through the six worlds in
## `Worlds.LIST`, each ending with a boss, and the last boss leads to the ending. Endless
## loops the six worlds forever, every lap tougher, with its own best score.

const W := 224.0
const PH := 126.0
const CH := 64
const SAVE_PATH := "user://save.cfg"
## [half width, half height, hit points, score]
const DEF := {wasp = [3, 2, 1, 120], spitter = [4, 3.5, 5, 300], nest = [8, 9, 30, 1600], lancer = [5, 2.4, 3, 200],
	bulwark = [9, 7, 34, 1800], generator = [3.4, 3.4, 6, 500], drifter = [3, 3, 1, 100], turret = [4, 3.5, 3, 300], hopper = [5, 3, 2, 200], carrier = [5, 4, 5, 500], shell = [10, 7, 26, 1500],
	shard = [4, 2, 2, 150], icicle = [2.4, 4.5, 2, 120], flake = [4, 4, 4, 250], hulk = [10, 7, 30, 1600],
	drone = [3.5, 2, 2, 120], piston = [4, 4, 14, 400], crawler = [5.5, 3, 6, 400], gun = [4, 3.5, 4, 300],
	ember = [2.4, 2.4, 2, 100], seeker = [3, 2, 3, 200], sentinel = [10, 7, 34, 1800], block = [3.8, 3.8, 3, 50]}
## Big enemies: heavy explosion and screen shake.
const BIG := ["shell", "hulk", "sentinel", "nest", "bulwark"]
## Enemies fixed to the terrain (they scroll with it, `wx` is their world position).
const FIXED := ["turret", "gun", "icicle", "piston", "block", "spitter", "generator"]
## Free fliers are kept inside the cave or tunnel so they never sit inside rock.
const FLYERS := ["drifter", "carrier", "shell", "shard", "flake", "hulk", "drone", "seeker", "sentinel", "wasp", "nest", "lancer", "bulwark"]
const ACTIONS := {
	left = [KEY_LEFT, KEY_A], right = [KEY_RIGHT, KEY_D], up = [KEY_UP, KEY_W], down = [KEY_DOWN, KEY_S],
	fire = [KEY_Z, KEY_J], charge = [KEY_X, KEY_C, KEY_K, KEY_L], pod = [KEY_SPACE, KEY_V, KEY_SHIFT],
	start = [KEY_ENTER, KEY_P, KEY_ESCAPE], mute = [KEY_M],
}
const PADS := {fire = [JOY_BUTTON_A], charge = [JOY_BUTTON_B, JOY_BUTTON_X], pod = [JOY_BUTTON_Y, JOY_BUTTON_RIGHT_SHOULDER], start = [JOY_BUTTON_START]}
const CAM := Vector3(0, -9, 152)
## Fire: a tap shoots one heavy shot; holding it longer than this many ticks streams rapid fire.
const RAPID_AFTER := 12
const RAPID_EVERY := 6

var mode := "title"
var paused := false
var G: Dictionary = {}
var P: Dictionary = {}
var pod: Dictionary = {}
## The second pod (a second P item once the first is docked): it docks on whichever side is free,
## usually the tail, so the ship is covered front and back.
var pod2: Dictionary = {}
## Both pods, `pod` first.
var pods: Array = []
## Best score of the mode being played (or last chosen on the menu).
var hiscore := 0
## Best score per mode, saved; `hiscore` mirrors the current mode's entry.
var bests := {normal = 0, endless = 0}
## Mode chosen on the menu ("normal" or "endless"); kept for the next launch.
var play_mode := "normal"
var tt := 0
var shake := 0.0
var muzzle := 0
var banner_t := 0
var hint_t := 0
var muted := false
var script_list: Array = []
var fx: Array = []
var chunks: Dictionary = {}
var _uid := 0
## Extra stage units visible on each side when the screen is wider than 16:9 (spawns and
## culling move out by this much so nothing pops in or out on screen).
var xm := 0.0
var _env: Environment

var cur := {}
var prev := {}
var latch := {}

var world: Node3D
var camera: Camera3D
var hud: Hud
var audio: Sfx
var ship: Node3D
var pod_m: Node3D
var pod2_m: Node3D
var ship_glow: MeshInstance3D
## The big ship and pod on the right of the main menu; a child of the camera.
var menu_ship: Node3D
var menu_pod: Node3D
var muzzle_s: MeshInstance3D
var charge_fx: Node3D  ## the charge-up: a laser ball at the nose with the level's strands spinning round it
var charge_ph := 0.0
var stars: Array = []
var planet: MeshInstance3D
var far_rocks: Array = []
## Current world (an entry of Worlds.LIST) and the scene parts its palette recolours.
var wdef: Dictionary = Worlds.LIST[0]
var _grad: Gradient
var _rim: DirectionalLight3D
var _star_mats: Array = []
var _want_title := false
var _want_mode := ""
var _ring: Node3D


# ---------- helpers ----------

static func X(x: float) -> float:
	return x - W / 2.0


static func Y(y: float) -> float:
	return PH / 2.0 - y


static func smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func hash1(n: float) -> float:
	var s := sin(n * 127.1 + 311.7) * 43758.5453
	return s - floorf(s)


func ceil_h(wx: float) -> float:
	return Worlds.heights(wdef, wx).x


func floor_h(wx: float) -> float:
	return Worlds.heights(wdef, wx).y


## Centre of the open corridor between ceiling and floor at `wx`.
func mid_y(wx: float) -> float:
	var h := Worlds.heights(wdef, wx)
	return (h.x + PH - h.y) / 2.0


func boss_at() -> float:
	return wdef.boss_at


## Difficulty grows with each world, and in Endless by two worlds' worth per lap.
func diff() -> float:
	return float(G.get("world", 0)) + 2.0 * float(G.get("lap", 0))


func endless() -> bool:
	return G.get("mode", "") == "endless"


func uid() -> int:
	_uid += 1
	return _uid


func fmt(n: float) -> String:
	var s := str(int(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


# ---------- setup ----------

func _ready() -> void:
	Diag.start()
	Models.init()
	_setup_input()
	_setup_world()
	audio = Sfx.new()
	add_child(audio)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	hud.start_pressed.connect(func(): latch["start"] = true)
	hud.mute_pressed.connect(func(): latch["mute"] = true)
	hud.safe_toggled.connect(apply_safe)
	hud.title_pressed.connect(func(): _want_title = true)
	hud.mode_chosen.connect(func(m: String): _want_mode = m)
	hud.refresh_pressed.connect(refresh_game)
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		bests.normal = int(cfg.get_value("game", "best", 0))
		bests.endless = int(cfg.get_value("game", "best_endless", 0))
		muted = bool(cfg.get_value("game", "muted", false))
		var lm := str(cfg.get_value("game", "mode", "normal"))
		play_mode = lm if bests.has(lm) else "normal"
	hiscore = bests[play_mode]
	hud.set_bests(fmt(bests.normal), fmt(bests.endless))
	hud.select_mode(play_mode)
	audio.set_muted(muted)
	hud.set_muted_icon(muted)
	hud.set_menu("title")
	if Diag.crashed:
		hud.show_crash_notice(Diag.summary(), Diag.report())
	_warm_up()
	_check_update()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	apply_safe()


## Restarts the game from scratch so the launch-time update check loads the newest build:
## the app process restarts on Android and desktop, the page reloads in the browser.
## Tests swap `restart_fn` for a stub.
var restart_fn := func():
	if OS.has_feature("web"):
		JavaScriptBridge.eval("location.reload()")
	else:
		OS.set_restart_on_exit(true, OS.get_cmdline_args())
		get_tree().quit()


func refresh_game() -> void:
	if mode != "title":
		return
	Diag.note("REFRESH")
	_save()
	hud.set_build_state("restarting")
	# let the label show before the app goes away
	await get_tree().create_timer(0.15).timeout
	restart_fn.call()


## The build number from the running version ("b73 abc1234" -> 73), or 0.
static func build_number(version: String) -> int:
	var m := RegEx.create_from_string("^b(\\d+)").search(version)
	return int(m.get_string(1)) if m else 0


## Asks the update server (same as the launch-time updater) whether a newer build is out,
## and if so says so on the menu's build line. Quiet when offline or without an update url.
func _check_update() -> void:
	var url := str(ProjectSettings.get_setting("star_breaker/update_url", ""))
	if url == "":
		return
	var http := HTTPRequest.new()
	http.timeout = 6.0
	add_child(http)
	if http.request(url + "update.json?t=%d" % int(Time.get_unix_time_from_system())) != OK:
		http.queue_free()
		return
	var r: Array = await http.request_completed
	http.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200:
		return
	var d = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
	if d is Dictionary:
		show_update(int(d.get("build", 0)))


## Shows "new build" on the menu when `remote` is newer than the running build.
func show_update(remote: int) -> void:
	var have := build_number(str(ProjectSettings.get_setting("application/config/version", "")))
	if have > 0 and remote > have:
		hud.set_build_state("new", remote)


func _setup_input() -> void:
	for a in ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.3)
		for k in ACTIONS[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
		for b in PADS.get(a, []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(a, jb)
	for pair in [["left", JOY_AXIS_LEFT_X, -1.0], ["right", JOY_AXIS_LEFT_X, 1.0], ["up", JOY_AXIS_LEFT_Y, -1.0], ["down", JOY_AXIS_LEFT_Y, 1.0]]:
		var jm := InputEventJoypadMotion.new()
		jm.axis = pair[1]
		jm.axis_value = pair[2]
		InputMap.action_add_event(pair[0], jm)
	for pair in [["left", JOY_BUTTON_DPAD_LEFT], ["right", JOY_BUTTON_DPAD_RIGHT], ["up", JOY_BUTTON_DPAD_UP], ["down", JOY_BUTTON_DPAD_DOWN]]:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pair[1]
		InputMap.action_add_event(pair[0], jb)


func _setup_world() -> void:
	var env := Environment.new()
	_env = env
	# plain colour background + a gradient card far behind (no sky shader or radiance maps)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0c0a26")
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8f8cc4")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("120f26")
	env.fog_depth_begin = 175.0
	env.fog_depth_end = 420.0
	env.fog_depth_curve = 1.0
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in range(1, 8):
		env.set("glow_levels/%d" % i, 1.0 if i in [2, 3, 4, 5] else 0.0)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	camera = Camera3D.new()
	camera.fov = 45.0
	camera.near = 1.0
	camera.far = 700.0
	camera.position = CAM
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("fff0dd")
	sun.light_energy = 1.15
	add_child(sun)
	sun.look_at_from_position(Vector3(-60, 90, 120), Vector3.ZERO)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("ff4fa3")
	rim.light_energy = 0.45
	add_child(rim)
	rim.look_at_from_position(Vector3(80, -40, -60), Vector3.ZERO)
	_rim = rim
	var under := DirectionalLight3D.new()
	under.light_color = Color("4a2050")
	under.light_energy = 0.5
	add_child(under)
	under.look_at_from_position(Vector3(0, -100, 30), Vector3.ZERO)

	world = Node3D.new()
	add_child(world)
	_add_backdrop()

	stars = [_star_layer(260, -330, -260, 2.0, Color("9a93c8")), _star_layer(140, -240, -200, 2.5, Color("e8e4f6"))]
	planet = Models.mesh(Geo.build(Geo.ico(62, 1)), Models.M.planet, Vector3(300, 150, -400))
	add_child(planet)
	var ring := Models.mesh(Geo.build_facing(Geo.ring(80, 96, 24), Vector3.BACK), Models.M.ring, Vector3(300, 150, -400))
	ring.rotation = Vector3(1.2, 0.3, 0.2)
	add_child(ring)
	_ring = ring
	for i in 12:
		var r := Models.mesh(Models.geo("fr%d" % (i % 4), func(): return Geo.ico(1, 0)), Models.M.far_rock,
				Vector3(randf_range(-360, 360), randf_range(-150, 150), randf_range(-300, -230)))
		var s := randf_range(8, 22)
		r.scale = Vector3(s * randf_range(0.8, 1.4), s, s)
		r.set_meta("spin", randf_range(-0.004, 0.004))
		add_child(r)
		far_rocks.append(r)

	ship = Models.ship()
	world.add_child(ship)
	ship.visible = false
	_add_menu_ship()
	pod_m = Models.pod()
	world.add_child(pod_m)
	pod_m.visible = false
	ship_glow = Models.glow("ff9a40", 9)
	ship_glow.position = Vector3(-9, 0, 0)
	ship.add_child(ship_glow)
	pod_m.add_child(Models.glow("3ff0e0", 9))
	pod2_m = Models.pod()
	world.add_child(pod2_m)
	pod2_m.visible = false
	pod2_m.add_child(Models.glow("3ff0e0", 9))
	muzzle_s = Models.glow("3ff0e0", 5)
	muzzle_s.visible = false
	world.add_child(muzzle_s)
	charge_fx = Node3D.new()
	charge_fx.visible = false
	# white like the laser it charges
	for c in ["4a5470", "dfe9ff", "ffffff"]:
		charge_fx.add_child(Models.glow(c, 1.0))
	charge_fx.add_child(Models.mesh(Models.geo("orb", func(): return Geo.ico(1, 1)), Models.M.beam))
	# the strands wind loosely round the ball's surface, each one a different way round
	for st in 6:
		charge_fx.add_child(Models.mesh(coil_mesh(st, 0), pulse_mat(st)))
	for v in COIL_SHAPES:
		coil_mesh(0, v)
		coil_mesh(3, v)
	world.add_child(charge_fx)


## Draws one of everything the game can show (every enemy, bullet, effect, item, the boss
## and the hit flash) for a few frames behind the title screen, so the GPU builds all its
## pipelines up front. Otherwise each new kind of object causes a hitch the first time it
## appears in a run, and the crash report from a Pixel (PowerVR GPU) showed the game dying
## right after such hitches.
func _warm_up() -> void:
	var w := Node3D.new()
	w.position = Vector3(0, -9, 60)
	w.scale = Vector3.ONE * 0.02
	add_child(w)
	var flashed := Models.drifter()
	var list: Array = [Models.ship(), Models.pod(), Models.drifter(), Models.turret(1), Models.turret(-1), Models.hopper(), Models.shell(), flashed,
		Models.shard(), Models.icicle(), Models.flake(), Models.hulk(), Models.drone(), Models.piston(0), Models.piston(1),
		Models.crawler(), Models.gun(0), Models.gun(1), Models.ember(), Models.seeker(), Models.sentinel(),
		Models.wasp(), Models.spitter(0), Models.spitter(1), Models.nest(), Models.lancer(), Models.bulwark(), Models.generator(1)]
	for wd in Worlds.LIST:
		list.append(Models.block(Models.M[wd.rock[0]]))
		list.append(Models.gate(Models.M[wd.gate]))
	for k in ["P", "L", "S"]:
		list.append(Models.carrier(k))
		list.append(Models.item(k))
	for k in Models.M:
		var mat = Models.M[k]
		if mat is Material:
			list.append(Models.mesh(Models.geo("pt", func(): return Geo.tetra(1)), mat))
			list.append(Models.mesh(Models.geo("bo", func(): return Geo.octa(0.5)), mat))
	for c in ["ffb547", "3ff0e0", "fff1d0", "ff4fa3", "ff9a40", "4a5470", "dfe9ff", "ffffff"]:
		list.append(Models.glow(c, 5))
	list.append(Models.mesh(Models.geo("fl", func(): return Geo.ico(1, 1)), Models.add_mat("fff1c9", 1.0)))
	for n in list:
		w.add_child(n)
	Models.set_flash(flashed, true)
	var bw := Node3D.new()
	w.add_child(bw)
	var bm := Models.boss(bw)
	Models.set_flash(bm, true)
	for b in [Models.boss_prism(bw), Models.boss_titan(bw), Models.boss_heart(bw), Models.boss_queen(bw), Models.boss_bastion(bw)]:
		Models.set_flash(b, true)
	for i in 4:
		await get_tree().process_frame
	w.queue_free()
	Diag.note("WARM", "%d objects" % (list.size() + 1))


## The main menu's hero: the real ship with its crystal pod docked at the nose, seen in
## three-quarter view on the right of the screen. It hangs off the camera so it stays put.
func _add_menu_ship() -> void:
	menu_ship = Models.ship()
	var gl := Models.glow("ff9a40", 9)
	gl.position = Vector3(-9, 0, 0)
	menu_ship.add_child(gl)
	menu_pod = Models.pod()
	# on the nose tip, which sits a little below the hull's centre line
	menu_pod.position = Vector3(11.6, -0.55, 0)
	menu_pod.add_child(Models.glow("3ff0e0", 9))
	menu_ship.add_child(menu_pod)
	camera.add_child(menu_ship)
	_place_menu_ship()


func _place_menu_ship() -> void:
	var vs := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)
	var aspect := vs.x / maxf(vs.y, 1.0)
	# 52 units in front of the camera, centred about 70% of the way across the screen;
	# smaller on narrow screens so it keeps clear of the menu on the left
	var half_w := 52.0 * tan(deg_to_rad(camera.fov / 2.0)) * aspect
	var k := clampf(aspect / 1.9, 0.62, 1.0)
	var bob := sin(tt * 0.035) * 0.5
	menu_ship.scale = Vector3.ONE * k
	menu_ship.position = Vector3(half_w * 0.38 - 3.0 * (1.0 - k), -2.5 + bob, -52.0)
	menu_ship.rotation = Vector3(0.3 + sin(tt * 0.021) * 0.05, -0.95, 0.16 + sin(tt * 0.027) * 0.04)
	(menu_pod.get_meta("spin") as Node3D).rotation.x = 0.35 + tt * 0.02
	(menu_ship.get_meta("flame") as Node3D).scale = Vector3(0.8 + randf() * 0.4, 1, 1)


func _add_backdrop() -> void:
	var g := Gradient.new()
	g.set_color(0, Color("1c1046"))
	g.set_color(1, Color("071225"))
	g.add_point(0.5, Color("0c0a26"))
	_grad = g
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 4
	gt.height = 128
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = gt
	mat.disable_fog = true
	var q := QuadMesh.new()
	q.size = Vector2(4000, 2000)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.position = Vector3(0, -9, -460)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Wider than 16:9: keep the playfield height and show more on the sides. Narrower: keep
## the width and show more cave above and below.
func _on_resize() -> void:
	var vs := get_viewport().get_visible_rect().size
	var aspect := vs.x / maxf(1.0, vs.y)
	if aspect >= 16.0 / 9.0:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		xm = (aspect / (16.0 / 9.0) - 1.0) * W / 2.0
	else:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		xm = 0.0
	hud.apply_safe_area()
	Diag.note("VIEW", "%s xm=%.1f" % [vs, xm])


## Recolours the sky, fog, light, planet and stars for world `i`. Only colours change
## (no new materials), so switching worlds needs no new GPU pipelines.
func apply_world(i: int) -> void:
	wdef = Worlds.LIST[i]
	var p: Dictionary = wdef.pal
	_env.background_color = Color(p.bg)
	_env.ambient_light_color = Color(p.amb)
	_env.fog_light_color = Color(p.fog)
	_grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_grad.colors = PackedColorArray([Color(p.top), Color(p.mid), Color(p.bot)])
	_rim.light_color = Color(p.rim)
	(Models.M.planet as StandardMaterial3D).albedo_color = Color(p.planet)
	(Models.M.planet as StandardMaterial3D).emission = Color(p.planet_e)
	(Models.M.ring as StandardMaterial3D).albedo_color = Color(p.ring)
	(Models.M.far_rock as StandardMaterial3D).albedo_color = Color(p.far)
	_star_mats[0].albedo_color = Color(p.star_a)
	_star_mats[1].albedo_color = Color(p.star_b)
	(Models.M.fort_a as StandardMaterial3D).albedo_color = Color(p.plate)
	(Models.M.fort_b as StandardMaterial3D).albedo_color = Color(p.plate2)
	(Models.M.fort_light as StandardMaterial3D).albedo_color = Color(p.light) * Color(1.8, 1.8, 1.8, 1.0)
	(Models.M.fort_trim as StandardMaterial3D).albedo_color = Color(p.plate2).darkened(0.3)
	(Models.M.fort_dark as StandardMaterial3D).albedo_color = Color(p.plate2).darkened(0.62)
	(Models.M.fort_back as StandardMaterial3D).albedo_color = Color(p.bg).lerp(Color(p.plate2), 0.16)
	(Models.M.fort_win as StandardMaterial3D).albedo_color = Color(p.light) * Color(0.6, 0.6, 0.6, 1.0)
	# world 1 keeps its planet top right; later worlds move it top left, clear of the bosses
	var pp := Vector3(300, 150, -400) if i == 0 else Vector3(-270, 215, -420)
	planet.position = pp
	_ring.position = pp
	Diag.note("WORLD", "%d %s" % [i + 1, wdef.name])


func apply_safe() -> void:
	_env.glow_enabled = not Diag.safe
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if Diag.safe else Viewport.MSAA_2X


func _star_layer(n: int, z0: float, z1: float, size: float, color: Color) -> Node3D:
	# Stars are tiny quads in a MultiMesh, not GL points: point sprites are the least portable
	# primitive on Android GPUs.
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size * 0.55
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.disable_fog = true
	q.material = mat
	_star_mats.append(mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = n
	for i in n:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(randf_range(0, 900), randf_range(-180, 180), randf_range(z0, z1))))
	var grp := Node3D.new()
	for k in 2:
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.position.x = 900.0 * k
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		grp.add_child(mi)
	add_child(grp)
	return grp


# ---------- terrain ----------

## `jit` 0 gives clean machined plating (fortress sections), 1 rough rock.
func terrain_tris(hs: Array, side: int, seed: float, jit := 1.0) -> Array:
	var sg := 1.0 if side else -1.0
	var zs := [11.0, 3.0, -9.0, -26.0]
	var rec := [0.0, 3.0, 7.0, 13.0]
	var edge := func(i: int) -> float:
		if hs[i] < 0.6:
			return sg * (PH / 2.0 + 3.0)
		return PH / 2.0 - hs[i] if side else -PH / 2.0 + hs[i]
	var pt := func(i: int, j: int) -> Vector3:
		var y: float = edge.call(i)
		var jy := (hash1(seed + i * 7.1 + j * 13.3) - 0.5) * 4.0 * jit if j else 0.0
		var jx := (hash1(seed + i * 3.7 + j) - 0.5) * 4.0 * jit if (j and i > 0 and i < 8) else 0.0
		return Vector3(i * 8 + jx, y + sg * (rec[j] + jy), zs[j])
	var fr := func(i: int, k: int) -> Vector3:
		var e: float = edge.call(i)
		var off: float = [0.0, 9.0, 24.0, 70.0][k]
		var j := lerpf(0.5, hash1(seed + i * 5.3 + k * 2.1), jit) if (k > 0 and k < 3) else 0.5
		var x := i * 8 + ((hash1(seed + i + k * 9.7) - 0.5) * 5.0 * jit if (k and i > 0 and i < 8) else 0.0)
		return Vector3(x, e + sg * (off + (j - 0.5) * 6.0), zs[0] + (0.0 if k == 0 else (j - 0.5) * 10.0 - (12.0 if k == 3 else 0.0)))
	var tris := []
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		tris.append([a, b, c])
		tris.append([a, c, d])
	for i in 8:
		for k in 3:
			quad.call(fr.call(i, k), fr.call(i + 1, k), fr.call(i + 1, k + 1), fr.call(i, k + 1))
		for j in 3:
			quad.call(pt.call(i, j), pt.call(i + 1, j), pt.call(i + 1, j + 1), pt.call(i, j + 1))
	return tris


func build_chunk(c: int) -> Node3D:
	var wx0 := float(c * CH)
	var grp := Node3D.new()
	var any := false
	var fort_hs := [null, null]
	for side in [0, 1]:
		var hs := []
		var mx := 0.0
		for i in 9:
			var hv := Worlds.heights(wdef, wx0 + i * 8)
			var h := hv.x if side else hv.y
			hs.append(h)
			mx = maxf(mx, h)
		if mx < 0.6:
			continue
		any = true
		var fort := Worlds.in_fort(wdef, wx0 + 32.0)
		var mesh := Geo.build_facing(terrain_tris(hs, side, c * 31 + side * 977, 0.0 if fort else 1.0), Vector3(0, 0.15 if side == 0 else -0.15, 1).normalized())
		if fort:
			# fortress plating: alternate panel colours, a strip of lights along the edge
			grp.add_child(Models.mesh(mesh, Models.M.fort_a if c % 2 else Models.M.fort_b))
			fort_hs[side] = hs
			if FortDeco.enabled:
				continue
			var sgn := 1.0 if side else -1.0
			for i in [1, 4, 7]:
				var base: float = PH / 2.0 - hs[i] if side else -PH / 2.0 + hs[i]
				var lt := Models.mesh(Models.geo("fl8", func(): return Geo.box(4, 1.2, 1.2)), Models.M.fort_light)
				lt.position = Vector3(i * 8, base + sgn * 1.4, 10.4)
				grp.add_child(lt)
			continue
		grp.add_child(Models.mesh(mesh, Models.M[wdef.rock[0] if hash1(c + side * 5) > 0.5 else wdef.rock[1]]))
		for i in range(1, 8):
			if hs[i] < 5.0 or hash1(c * 17 + i * 3 + side) < 0.55:
				continue
			var h := 3.0 + hash1(c + i) * 2.5
			var sg := 1.0 if side else -1.0
			var dm: Material = Models.M[wdef.deco_mats[0] if hash1(c * 3 + i) > 0.5 else wdef.deco_mats[1]]
			var cr: MeshInstance3D
			match wdef.deco:
				"spike":
					cr = Models.mesh(Models.geo("icy", func(): return Geo.cone(1.1, 1, 3)), dm)
					h *= 1.8
					cr.scale = Vector3(1, h, 1)
				"strut":
					cr = Models.mesh(Models.geo("strut", func(): return Geo.box(1.6, 1, 1.6)), dm)
					cr.scale = Vector3(1, h, 1)
					cr.rotation.y = 0.6
				_:
					cr = Models.mesh(Models.geo("cry", func(): return Geo.cone(1.3, 1, 4)), dm)
					cr.scale = Vector3(1, h, 1)
			if side:
				cr.rotation.z = PI
			var base: float = PH / 2.0 - hs[i] if side else -PH / 2.0 + hs[i]
			cr.position = Vector3(i * 8 + (hash1(i + c) - 0.5) * 4.0, base - sg * (h / 2.0 - 1.6), -4.0 - hash1(c * 9 + i) * 10.0)
			grp.add_child(cr)
	if not any:
		grp.free()
		return null
	if FortDeco.enabled and fort_hs[0] != null and fort_hs[1] != null:
		FortDeco.new().build(grp, c, fort_hs[1], fort_hs[0], wdef)
	world.add_child(grp)
	return grp


## Chunks reach back to the fortress back wall (FortDeco.BACK_Z), and the deeper a plane, the
## wider the slice of it the camera sees: chunks are built and freed this far beyond the
## edges of the play plane so nothing pops in or out on screen, whatever the screen shape.
func chunk_pad() -> float:
	return 8.0 + (W / 2.0 + xm) * (-FortDeco.BACK_Z + 2.0) / CAM.z


func update_chunks(scroll: float) -> void:
	var pad := chunk_pad()
	var a := floori((scroll - pad - xm) / CH)
	var b := floori((scroll + W + pad + xm) / CH)
	for c in chunks.keys():
		if c < a or c > b:
			if chunks[c]:
				chunks[c].queue_free()
			chunks.erase(c)
	for c in range(a, b + 1):
		if not chunks.has(c):
			chunks[c] = build_chunk(c)
		var g: Node3D = chunks[c]
		if g:
			g.position.x = c * CH - scroll - W / 2.0


func clear_chunks() -> void:
	for c in chunks:
		if chunks[c]:
			chunks[c].queue_free()
	chunks.clear()


# ---------- input ----------

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton:
		if event.is_echo():
			return
		for a in ACTIONS:
			if event.is_action_pressed(a):
				latch[a] = true
				if a != "start" and a != "mute":
					get_viewport().set_input_as_handled()


func poll_input() -> void:
	prev = cur
	cur = {}
	var t := hud.touch
	for a in ACTIONS:
		cur[a] = Input.is_action_pressed(a) or latch.get(a, false) or t.held.get(a, false) or t.latched.get(a, false)
	latch.clear()
	t.latched.clear()


func held(a: String) -> bool:
	return cur.get(a, false)


func hit(a: String) -> bool:
	return cur.get(a, false) and not prev.get(a, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		latch["start"] = true
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		Diag.note("RESUME")
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Diag.note("QUIT")
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		Diag.note("SUSPEND")
		if hud:
			hud.touch.reset()
		if mode == "play" and not paused:
			set_paused(true)


# ---------- game flow ----------

func new_game(world := 0, m := "") -> void:
	if m != "":
		play_mode = m
	hiscore = bests[play_mode]
	G = {score = 0, lives = 2, world = world, next_extend = 20000, mode = play_mode, lap = 0}
	P = {x = -10.0, y = 63.0, hw = 2.5, hh = 1.5, alive = true, inv = 0, entering = true, exiting = false, charge = 0, charge_held = false,
		rapid_cd = 0, fire_hold = 0, laser = 0, speed = 0, respawn = 0, vy = 0.0, ready_lv = 0}
	pod = {state = "none", x = 0.0, y = 0.0, hw = 3.6, hh = 3.6, tx = 0.0, grab_cd = 0, hit_cd = 0}
	pod2 = pod.duplicate()
	pods = [pod, pod2]
	Diag.note("PLAY", "%s world %d" % [play_mode, world + 1])
	mode = "play"
	paused = false
	hud.set_menu("play")
	hud.touch.playing = true
	start_stage()
	hint_t = 480
	hud.show_hints(true)


## Starts (or restarts) the current world `G.world` from its beginning.
func start_stage() -> void:
	if G.has("enemies"):
		for arr in [G.enemies, G.eb, G.pb, G.items, G.gates]:
			for o in arr:
				o.m.queue_free()
	if G.get("boss"):
		remove_boss()
	clear_chunks()
	clear_fx()
	apply_world(G.world)
	script_list = Worlds.script(G.world)
	G.merge({scroll = 0.0, t = 0, si = 0, enemies = [], eb = [], pb = [], items = [], gates = [], boss = null, warned = false, warn_t = 0, clear_t = 0, bparts = []}, true)
	P.merge({x = -10.0, y = 63.0, entering = true, exiting = false, alive = true, inv = 60, charge = 0}, true)
	for p in pods:
		if p.state != "none":
			dock_pod(p, "front" if p == pod else "back")
	show_banner(wdef.name, ("Endless · Lap %d · %s" % [G.lap + 1, wdef.sub]) if endless() else wdef.sub, 170)
	audio.music(wdef.song)
	hud.fade(false)


func last_world() -> bool:
	return G.world >= Worlds.LIST.size() - 1


## Enemy bullet speed: +10% a world, capped so late Endless laps stay readable.
const BM_MAX := 1.9


func bm() -> float:
	return minf(1.0 + 0.1 * diff(), BM_MAX)


func game_over() -> void:
	Diag.note("GAMEOVER")
	mode = "over"
	G.over_t = 0
	audio.music("")
	_save()
	hud.set_over(fmt(G.score), fmt(hiscore), G.world, G.lap if endless() else -1)
	hud.set_menu("over")
	hud.touch.playing = false
	hud.touch.reset()


## After the last boss: the ending screen.
func ending() -> void:
	Diag.note("ENDING")
	var score: int = G.score
	teardown()
	G = {score = score, over_t = 0}
	mode = "end"
	if score > hiscore:
		hiscore = score
	_save()
	audio.music("ending")
	hud.set_ending(fmt(score), fmt(hiscore))
	hud.set_menu("end")
	hud.touch.playing = false
	hud.touch.reset()


func _save() -> void:
	bests[play_mode] = maxi(bests[play_mode], hiscore)
	hud.set_bests(fmt(bests.normal), fmt(bests.endless))
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", bests.normal)
	cfg.set_value("game", "best_endless", bests.endless)
	cfg.set_value("game", "mode", play_mode)
	cfg.set_value("game", "muted", muted)
	cfg.save(SAVE_PATH)


## Back to the main menu (after a run, the ending, or quitting from pause).
func to_menu() -> void:
	mode = "title"
	apply_world(0)
	audio.music("")
	hud.select_mode(play_mode)
	hud.set_menu("title")
	hud.touch.playing = false
	hud.touch.reset()


func set_paused(v: bool) -> void:
	paused = v
	hud.set_menu("pause" if v else "play")
	hud.touch.playing = not v
	hud.touch.reset()
	audio.set_paused(v)


func show_banner(t: String, sub: String, frames: int, warn := false) -> void:
	hud.banner(t, sub, warn)
	banner_t = frames


func teardown() -> void:
	if G.is_empty():
		return
	for arr in [G.enemies, G.eb, G.pb, G.items, G.gates]:
		for o in arr:
			o.m.queue_free()
	if G.boss:
		remove_boss()
	clear_chunks()
	clear_fx()
	hud.fade(false)
	ship.visible = false
	pod_m.visible = false
	pod2_m.visible = false
	charge_fx.visible = false
	muzzle_s.visible = false
	hud.hide_banner()
	hud.show_hints(false)
	hud.show_boss(false)
	hint_t = 0
	G = {}


# ---------- spawning ----------

func E(type: String, x: float, y: float, o := {}) -> Dictionary:
	var d: Array = DEF[type]
	var e := {id = uid(), type = type, x = x, y = y, hw = d[0], hh = d[1], hp = ceilf(d[2] * (1.0 + 0.2 * diff())), score = d[3],
		t = 0, flash = 0, dead = false, drop = "", side = 0}
	e.merge(o, true)
	match type:
		"drifter": e.m = Models.drifter()
		"turret": e.m = Models.turret(e.side)
		"hopper": e.m = Models.hopper()
		"carrier": e.m = Models.carrier(e.drop)
		"shard": e.m = Models.shard()
		"icicle": e.m = Models.icicle()
		"flake": e.m = Models.flake()
		"hulk": e.m = Models.hulk()
		"drone": e.m = Models.drone()
		"piston": e.m = Models.piston(e.side)
		"crawler": e.m = Models.crawler()
		"gun": e.m = Models.gun(e.side)
		"ember": e.m = Models.ember()
		"seeker": e.m = Models.seeker()
		"sentinel": e.m = Models.sentinel()
		"block": e.m = Models.block(Models.M[wdef.rock[0]])
		"wasp": e.m = Models.wasp()
		"spitter": e.m = Models.spitter(e.side)
		"nest": e.m = Models.nest()
		"lancer": e.m = Models.lancer()
		"bulwark": e.m = Models.bulwark()
		"generator": e.m = Models.generator(e.side)
		_: e.m = Models.shell()
	world.add_child(e.m)
	Diag.once("spawn " + type)
	G.enemies.append(e)
	sync_e(e)
	return e


func spawn(s: Dictionary) -> void:
	# entries are spawned when they reach the right edge; y < 0 means "the corridor centre"
	var ex := W + 8 + xm
	var sy: float = s.get("y", 63.0)
	if sy < 0.0:
		sy = mid_y(G.scroll + ex + 8)
	match s.type:
		"wave":
			for i in s.n:
				E("drifter", ex + i * 13, sy, {by = sy, ph = i * 0.6, amp = s.amp})
		"turret", "gun":
			var h := ceil_h(s.x) if s.side else floor_h(s.x)
			if h > 6.0:
				E(s.type, ex, 0, {wx = s.x, side = s.side, rate = maxi(60, 120 - 12 * int(diff())) + int(fmod(s.x, 37.0))})
		"piston":
			var h := ceil_h(s.x) if s.side else floor_h(s.x)
			if h > 4.0:
				E("piston", ex, 0, {wx = s.x, side = s.side, ext = 0.0, ph = fmod(s.x * 0.37, TAU)})
		"icicle":
			if ceil_h(s.x) > 4.0:
				E("icicle", ex, 0, {wx = s.x, side = 1, vy = 0.0, falling = false})
		"crawler":
			E("crawler", ex + 4, 0, {wx = G.scroll + ex + 4})
		"carrier":
			E("carrier", ex + 2, sy, {by = sy, drop = s.drop})
		"shell", "hulk", "sentinel":
			E(s.type, ex + 6, sy, {by = sy, stay = 260})
		"hopper":
			var y := 98.0 if P.y < 63 else 28.0
			for i in s.n:
				E("hopper", -8 - xm - i * 16, y + (8.0 if i % 2 else -8.0), {vx = 1.7})
		"shards":
			for i in s.n:
				E("shard", ex + i * 16, sy + (i % 2) * 10.0 - 5.0, {stop = W - 46.0 - i * 14.0, vx = -2.2, vy = 0.0, st = 0})
		"flake":
			E("flake", ex + 2, sy, {by = sy})
		"drones":
			for i in s.n:
				E("drone", ex + i * 14, sy, {vx = -2.4, vy = 0.0, turn = 0})
		"embers":
			for i in s.n:
				var x := randf_range(W * 0.35, W - 10.0)
				E("ember", x, PH + 6 + i * 18, {vx = randf_range(-1.1, -0.4), vy = randf_range(-2.9, -2.3)})
		"seekers":
			for i in s.n:
				E("seeker", ex + i * 18, sy + (i % 2) * 14.0 - 7.0, {vx = -1.3, vy = 0.0})
		"gate":
			add_gate(s)
		"tower":
			var t := s.duplicate()
			t.mode = "tower"
			add_gate(t)
		"flyers":
			# the world's own small fliers, on the corridor line (fortress rooms)
			var f := {x = s.x, type = wdef.flyer, y = s.get("y", -1.0), n = 4, amp = 8.0}
			if f.type == "waves":
				f.type = "wave"
			spawn(f)
		"wasps":
			for i in s.n:
				E("wasp", ex + i * 10, sy + (i % 3 - 1) * 6.0, {by = sy + (i % 3 - 1) * 6.0, ph = i * 0.9, st = 0, vx = 0.0, vy = 0.0})
		"lancers":
			for i in s.n:
				E("lancer", ex + 4, 0, {st = 0, hold = 30 + i * 34, vx = 0.0})
		"nest", "bulwark":
			E(s.type, ex + 6, sy, {by = sy, stay = 300})
		"spitter":
			var h := ceil_h(s.x) if s.side else floor_h(s.x)
			if h > 5.0:
				E("spitter", ex, 0, {wx = s.x, side = s.side})
		"wall":
			var h := Worlds.heights(wdef, s.x)
			var y: float = h.x + 3.0
			var bottom: float = PH - h.y - 3.0
			while y <= bottom:
				E("block", ex, y, {wx = s.x, by = y})
				y += 7.6


# ---------- gates ----------
## A gate is a wall across the corridor with one opening (centre `gy`, half height `gh`).
## "slide" gates move the opening up and down, "shutter" gates open and close it.

func add_gate(s: Dictionary) -> void:
	var g := {wx = s.x, x = s.x - G.scroll, hw = 3.5, base = mid_y(s.x) + s.get("off", 0.0), gh0 = s.get("gh", 14.0), mode = s.get("mode", "fixed"),
		amp = s.get("amp", 0.0), rate = s.get("rate", 0.0), dead = false}
	g.gy = g.base
	g.gh = g.gh0
	g.m = Models.gate(Models.M[wdef.gate])
	world.add_child(g.m)
	Diag.once("gate " + g.mode)
	G.gates.append(g)
	match g.mode:
		"tower":
			# one pillar from the floor (side 0) or the ceiling (side 1), a gun on its tip;
			# it always leaves a 34-unit way past
			var h := Worlds.heights(wdef, s.x)
			var th := maxf(8.0, PH - h.x - h.y - 34.0)
			var top_end := -300.0
			var bot_start := PH + 300.0
			if s.get("side", 0):
				top_end = h.x + th
			else:
				bot_start = PH - h.y - th
			g.gy = (top_end + bot_start) / 2.0
			g.gh = (bot_start - top_end) / 2.0
			g.gh0 = g.gh
			g.mode = "fixed"
			g.hw = 5.0
			var side: int = s.get("side", 0)
			E("gun", W + 8 + xm, 0, {wx = s.x, side = side, my = (top_end + 3.0) if side else (bot_start - 3.0),
				rate = maxi(70, 120 - 10 * int(diff()))})
		"locked":
			# closed by an energy field until the generator on its top lip is destroyed
			g.locked = true
			g.key = uid()
			g.gh = -1.0
			E("generator", W + 8 + xm, 0, {wx = s.x - 7.0, side = 1, my = g.gy - g.gh0 + 3.4, key = g.key})
	update_gate(g)


func update_gate(g: Dictionary) -> void:
	g.x = g.wx - G.scroll
	match g.mode:
		"slide":
			g.gy = g.base + g.amp * sin(G.t * g.rate + g.wx)
		"shutter":
			g.gh = lerpf(2.0, g.gh0, clampf(0.5 + 0.8 * sin(G.t * g.rate + g.wx), 0.0, 1.0))
		"locked":
			if g.locked and not G.enemies.any(func(e): return e.type == "generator" and not e.dead and e.key == g.key):
				g.locked = false
				Diag.once("gate unlocked")
				audio.play("pod")
			if not g.locked:
				g.gh = move_toward(g.gh, g.gh0, 0.6)
	if g.x < -30 - xm:
		g.dead = true


## The gate whose pillars cover point (x, y), or an empty dictionary.
func gate_at(x: float, y: float, pad: float) -> Dictionary:
	if G.is_empty() or not G.has("gates"):
		return {}
	for g in G.gates:
		if absf(x - g.x) < g.hw and (y < g.gy - g.gh + pad or y > g.gy + g.gh - pad):
			return g
	return {}


## Pillars run from just inside the rock to the opening, in front of the cave walls.
func sync_gate(g: Dictionary) -> void:
	var u: Dictionary = g.m.get_meta("u")
	var h := Worlds.heights(wdef, g.wx)
	var vis_gh: float = g.gh0 if g.get("locked", false) else g.gh
	var top_end: float = g.gy - vis_gh
	var bot_start: float = g.gy + vis_gh
	var f: Node3D = u.field
	f.visible = g.get("locked", false)
	if f.visible:
		f.scale = Vector3(g.hw * 1.4, vis_gh * 2.0, 3)
		f.position = Vector3(X(g.x), Y(g.gy), 3)
	var top0: float = (h.x - 8.0) if h.x > 1.0 else -10.0
	var bot1: float = (PH - h.y + 8.0) if h.y > 1.0 else PH + 10.0
	var top: MeshInstance3D = u.top
	var bot: MeshInstance3D = u.bot
	top.scale = Vector3(g.hw * 2.0, maxf(0.1, top_end - top0), 12)
	top.position = Vector3(X(g.x), Y((top_end + top0) / 2.0), 3)
	bot.scale = Vector3(g.hw * 2.0, maxf(0.1, bot1 - bot_start), 12)
	bot.position = Vector3(X(g.x), Y((bot_start + bot1) / 2.0), 3)
	for k in ["top", "bot"]:
		var pil: MeshInstance3D = u[k]
		for d in ["_rib", "_strip"]:
			(u[k + d] as Node3D).transform = pil.transform
		var col: Node3D = u[k + "_collar"]
		col.scale = Vector3(g.hw * 2.0 + 1.6, 2.6, 13.2)
		col.position = Vector3(X(g.x), Y(top_end - 7.0 if k == "top" else bot_start + 7.0), 3)
		col.visible = pil.scale.y > 10.0
	(u.top_lip as Node3D).position = Vector3(X(g.x), Y(top_end - 1.0), 3)
	(u.bot_lip as Node3D).position = Vector3(X(g.x), Y(bot_start + 1.0), 3)


func aim(x: float, y: float, s: float) -> void:
	if not P.alive:
		return
	var a := atan2(P.y - y, P.x - x)
	bullet(x, y, cos(a) * s * bm(), sin(a) * s * bm())


func fan(x: float, y: float, s: float, n: int, spread: float) -> void:
	var a0 := atan2(P.y - y, P.x - x)
	for i in n:
		var a := a0 + (i - (n - 1) / 2.0) * spread
		bullet(x, y, cos(a) * s * bm(), sin(a) * s * bm())


func ring(x: float, y: float, n: int, s: float) -> void:
	var o := randf()
	for i in n:
		var a := o + float(i) / n * TAU
		bullet(x, y, cos(a) * s * bm(), sin(a) * s * bm())


## `grav` pulls the bullet down each tick (arcing lobs).
func bullet(x: float, y: float, vx: float, vy: float, grav := 0.0) -> void:
	var b := {x = x, y = y, vx = vx, vy = vy, hw = 1.3, hh = 1.3, dead = false, g = grav}
	b.m = Models.mesh(Models.geo("eb", func(): return Geo.octa(1.7)), Models.M.ebullet)
	b.m.add_child(Models.glow("ffb547", 7))
	world.add_child(b.m)
	G.eb.append(b)


# ---------- player weapons ----------

func shot(x: float, y: float, vx: float, vy: float, mat: Material, d := 1) -> void:
	var b := {x = x, y = y, vx = vx, vy = vy, hw = 3.0, hh = 1.4 if d > 1 else 0.9, dmg = d, beam = false, dead = false}
	var m := Models.mesh(Models.geo("shot", func(): return Geo.box(6, 0.9, 0.9)), mat)
	m.rotation.z = atan2(-vy, vx)
	if d > 1:
		m.scale = Vector3(1.15, 1.8, 1.8)
	var g := Models.glow("ffb547" if mat == Models.M.pod_shot else "3ff0e0", 7.0 if d > 1 else 5.0)
	g.scale = Vector3(g.scale.x / m.scale.x, g.scale.y / m.scale.y, 1)
	m.add_child(g)
	b.m = m
	world.add_child(m)
	G.pb.append(b)


func fire_shot(rapid: bool) -> void:
	var n := 0
	for b in G.pb:
		if not b.beam:
			n += 1
	if n > 18:
		return
	var nx: float = P.x + 8
	var y: float = P.y
	var d := 1 if rapid else 2
	var m: Material = Models.M.shot if rapid else Models.M.heavy
	if P.laser == 0:
		shot(nx, y, 5.2, 0, m, d)
	else:
		shot(nx, y - 2, 5.2, 0, m, d)
		shot(nx, y + 2, 5.2, 0, m, d)
	if P.laser >= 2:
		# the angled pair never carries the heavy shot's double damage
		shot(nx - 2, y, 4.6, -1.5, Models.M.shot, 1)
		shot(nx - 2, y, 4.6, 1.5, Models.M.shot, 1)
	for p in pods:
		if p.state == "back":
			shot(p.x - 4, p.y, -5, 0, Models.M.pod_shot, 1)
		elif p.state != "none":
			shot(p.x + 4, p.y, 5, 0, Models.M.pod_shot, 1)
	muzzle = 3 if rapid else 5
	audio.play("rapid" if rapid else "shot")


## Ticks (60 per second) the Charge button must be held for each stage. Stage 4, the Nova
## lance, takes 4 seconds: a real commitment, with a beam that also burns away bullets.
const CHARGE_AT := [0, 50, 100, 160, 240]
const CHARGE_MAX := 240
const NOVA := 4
## Ticks between two rams of the pod into an enemy (1 damage each): it shields more than it kills.
const POD_RAM_CD := 8


## Docks pod `p` on `side` ("front" or "back") of the ship.
func dock_pod(p: Dictionary, side: String) -> void:
	p.state = side
	p.x = P.x + (11 if side == "front" else -11)
	p.y = P.y


## The side a pod flying back docks on: the one it is nearer to, unless the other pod holds it.
func dock_side(p: Dictionary) -> String:
	var side := "front" if p.x >= P.x else "back"
	var other: Dictionary = pod2 if p == pod else pod
	if other.state == side:
		side = "back" if side == "front" else "front"
	return side


## Moves one pod for a tick: docked, flying out, or flying back; catches it when it reaches the ship.
func update_pod(p: Dictionary) -> void:
	if p.grab_cd > 0:
		p.grab_cd -= 1
	if p.hit_cd > 0:
		p.hit_cd -= 1
	match p.state:
		"front":
			p.x = P.x + 11
			p.y = P.y
		"back":
			p.x = P.x - 11
			p.y = P.y
		"free":
			p.x += clampf((p.tx - p.x) * 0.08, -3, 3)
			if P.alive:
				p.y += (P.y - p.y) * 0.035
		"return":
			var dx: float = P.x - p.x
			var dyy: float = P.y - p.y
			var d := Vector2(dx, dyy).length()
			if d > 3:
				p.x += dx / d * 3.2
				p.y += dyy / d * 3.2
	if (p.state == "free" or p.state == "return") and P.alive and not P.entering and p.grab_cd <= 0 and Vector2(p.x - P.x, p.y - P.y).length() < 12:
		p.state = dock_side(p)
		audio.play("dock")


## Places a pod's model: spins around its long axis, faster in flight; turns around when docked behind.
func sync_pod(m: Node3D, p: Dictionary) -> void:
	m.visible = p.state != "none"
	m.position = Vector3(X(p.x), Y(p.y), 0)
	if not paused:
		var spin := 0.32 if (p.state == "free" or p.state == "return") else 0.09
		# a pod docked at the nose spins up while Charge is held
		if p.state == "front" and P.alive and P.charge > 10:
			spin += 0.75 * float(P.charge) / CHARGE_MAX
		(m.get_meta("spin") as Node3D).rotation.x += spin
		var face := PI if p.state == "back" else 0.0
		m.rotation.y = lerp_angle(m.rotation.y, face, 0.25)


## The charge-up: a small laser ball at the nose (or the docked pod's nose) that grows as it
## charges, with the level's strands coiled round it pulsing in, staggered out of phase: none at level 1, white at 2, cyan and white at 3, pink, cyan and white at the Nova.
## They are the strands the beam will fire at that level.
func sync_charge_fx(lv: int) -> void:
	var k: float = float(P.charge) / CHARGE_MAX
	# with a pod docked at the nose there is no ball: the strands coil round the spinning pod
	var fp := front_pod()
	var podded := not fp.is_empty()
	var src := Vector2(fp.x, fp.y) if podded else beam_src() + Vector2(1.0, 0)
	charge_fx.position = Vector3(X(src.x), Y(src.y), 2 if not podded else 0)
	if not paused:
		charge_ph += 0.12 + k * 0.25
	var rad := 1.1 + k * 2.2
	var haze: MeshInstance3D = charge_fx.get_child(0)
	var glow: MeshInstance3D = charge_fx.get_child(1)
	var core: MeshInstance3D = charge_fx.get_child(2)
	var ball: MeshInstance3D = charge_fx.get_child(3)
	haze.scale = Vector3.ONE * rad * 4.0 * (1.0 + sin(tt * 0.37) * 0.08)
	glow.scale = Vector3.ONE * rad * 2.4 * (1.0 + sin(tt * 0.9) * 0.1)
	core.scale = Vector3.ONE * rad * 1.0 * (1.0 + sin(tt * 1.7) * 0.12)
	ball.scale = Vector3.ONE * rad * 0.5
	for n in [glow, core, ball]:
		n.visible = not podded
	if podded:
		haze.scale = Vector3(1.6, 1, 1) * (5.0 + k * 4.0) * 2.0
	# each strand comes as corkscrew pulses closing in on the ball, staggered like the beam's
	var on: Array = STRANDS[lv]
	for st in 6:
		var m: MeshInstance3D = charge_fx.get_child(4 + st)
		m.visible = on.has(st % 3)
		if not m.visible:
			continue
		# each pulse closes in from a little way out until it hugs the ball, then starts again
		var ph := fposmod((P.charge + PULSE_LAG[st] * 2.0) / CHARGE_PULSE, 1.0)
		var hug := 0.75 + 0.55 * (1.0 - ph) * (1.0 - ph)
		var r := (POD_COIL_R * (0.85 + 0.15 * k) if podded else rad) * (hug if not podded else 0.75 + hug * 0.3) * (1.0 if st < 3 else 1.1)
		m.position = Vector3.ZERO
		# round the pod the coil is stretched along its length
		m.scale = Vector3(r * (1.5 if podded else 1.0), r, r)
		# the winding keeps changing: looser and tighter, bending one way then the other
		m.mesh = coil_mesh(st, int(floor(tt * COIL_MORPH * (1.0 + 0.25 * (st % 3)) + st * 5)) % COIL_SHAPES)
		m.rotation = Vector3(-charge_ph * (1.0 + 0.3 * (st % 3)) + (st % 3) * TAU / 3.0 + (0.0 if st < 3 else PI / 3.0),
				0, 0.3 * (st % 3))


## Shapes a charge strand's winding cycles through, and how many of them go by each tick.
const COIL_SHAPES := 24
const COIL_MORPH := 0.4


## Charge strand mesh: shape `v` of the cycle, a hard strand (st < 3) or its haze.
func coil_mesh(st: int, v: int) -> ArrayMesh:
	var hard := st < 3
	return Geo.cached("coil%s%d" % ["h" if hard else "z", v], func():
		var t := float(v) / COIL_SHAPES * TAU
		return Geo.build_wound(Geo.ball_coil(1.25 + 0.35 * sin(t), 0.07 if hard else 0.2, 48, 4 if hard else 6,
				0.0, 1.4 * sin(t * 2.0 + 0.7), t)))


## Radius of the charge strands coiled round a docked pod (its crystal and shards).
const POD_COIL_R := 4.2
## Ticks for one charge-up pulse to close in on the laser ball.
const CHARGE_PULSE := 24.0
## Strands of the charge laser at each level: 0 pink, 1 cyan, 2 white.
const STRANDS := [[], [], [2], [1, 2], [0, 1, 2]]


## Twister strand `st`: 0-2 the hard pink, cyan and white strands, 3-5 the haze strand riding
## with each of them, set between them round the beam.
func pulse_mesh(st: int) -> ArrayMesh:
	return Geo.cached("pulse%d" % st, func(): return Geo.build_wound(Geo.helix(PULSE_LEN,
			TWIST_R if st < 3 else TWIST_R + 1.5, TWIST_PITCH, 0.65 if st < 3 else 2.4, 4 if st < 3 else 6, (st % 3) * TAU / 3.0 + (0.0 if st < 3 else PI / 3.0))))


func pulse_mat(st: int) -> Material:
	return [Models.M.twist_a, Models.M.twist_b, Models.M.twist_w, Models.M.twist_ga, Models.M.twist_gb, Models.M.twist_gw][st]


static func charge_lv(c: float) -> int:
	for lv in range(NOVA, 0, -1):
		if c >= CHARGE_AT[lv]:
			return lv
	return 0


## The pod docked at the ship's nose, or an empty dictionary.
func front_pod() -> Dictionary:
	for p in pods:
		if p.state == "front":
			return p
	return {}


## How far below the ship's centre line its nose tip is, in stage units (see `Models.ship()`).
const NOSE_DY := 0.55


## Where the laser line leaves from: the nose of the pod docked in front, else the ship's.
func beam_src() -> Vector2:
	var fp := front_pod()
	if not fp.is_empty():
		return Vector2(fp.x + 5, fp.y)
	# the nose tip sits a little below the hull's centre line (stage y points down)
	return Vector2(P.x + 9, P.y + NOSE_DY)


## Ticks the laser line stays on, per charge level.
const BEAM_LIFE := [0, 12, 16, 20, 40]
## The Nova twister pulses: radius of the hard strands and length of one pulse (one turn; the
## haze strands sit a little wider, half way between the hard ones), how many pulses a beam
## can show at once, ticks between two pulses and how fast they travel.
const TWIST_R := 7.0
const TWIST_PITCH := 30.0
const PULSES := 5
const PULSE_GAP := 12
const PULSE_SPEED := 6.0
const PULSE_LEN := 20.0
## Ticks each twister strand's pulses lag behind the first: pink, cyan, white hard strands,
## then the haze strand that rides with each of them. Length of one pulse along the beam.
const PULSE_LAG := [0, 4, 8, 0, 4, 8]



## Releasing Charge unleashes a laser line from the nose (or the docked pod) to the edge of the
## screen or the first wall. It follows the ship while it lasts and hits each enemy once.
## Thicker per level; the Nova (level 4) adds a pink and cyan twister round the beam.
func fire_beam(lv: int) -> void:
	var hh: float = [0.0, 1.6, 2.8, 4.6, 7.5][lv]
	var nova := lv == NOVA
	var src := beam_src()
	var b := {x = src.x, y = src.y, vx = 0.0, vy = 0.0, hw = 0.5, hh = hh, dmg = [0, 4, 9, 18, 40][lv], beam = true, line = true,
		nova = nova, lv = lv, hits = {}, dead = false, t = 0, spin = 0.0, life = BEAM_LIFE[lv], sx = src.x, ex = src.x, wall = false}
	var g := Node3D.new()
	var rod := Models.geo("bline", func(): return Geo.xf(Geo.cyl(0.5, 0.5, 1.0, 6), Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(0.5, 0, 0))))
	# the laser itself stays white at every level; only its twister strands are coloured
	var core := Models.mesh(rod, Models.M.beam)
	var sheath := Models.mesh(rod, Models.M.laser_glow)
	var col := "dfe9ff"
	var haze := Models.glow(col, 1.0)
	var flare := Models.glow(col, 1.0)
	var tip := Models.glow(col, 1.0)
	for n in [core, sheath, haze, flare, tip]:
		g.add_child(n)
	var parts := {core = core, sheath = sheath, haze = haze, flare = flare, tip = tip}
	if lv >= 2:
		# the twister: corkscrew pulses shooting along the beam, one stream per strand of this
		# level (each hard strand with its haze), staggered in time so they leave out of phase
		var pulses := []
		for st in 6:
			if not (STRANDS[lv] as Array).has(st % 3):
				continue
			for i in PULSES:
				var pl := Models.mesh(pulse_mesh(st), pulse_mat(st))
				pl.set_meta("lag", PULSE_LAG[st])
				g.add_child(pl)
				pulses.append(pl)
		parts.pulses = pulses
	b.parts = parts
	b.m = g
	world.add_child(g)
	aim_line(b)
	sync_line(b)
	G.pb.append(b)
	Diag.once("nova" if nova else "beam")
	audio.play("beam", lv)
	shake = maxf(shake, 12.0 if nova else lv * 2.0)
	if nova:
		muzzle = 12
		for i in 8:
			spark(src.x + randf_range(-3, 3), src.y + randf_range(-6, 6))


## Points a laser line from its source to the first wall (or past the screen edge).
func aim_line(b: Dictionary) -> void:
	var src := beam_src()
	var far := W + xm + 8.0
	var ex := src.x
	while ex < far and not in_wall(ex, src.y, 0):
		ex += 2.5
	b.sx = src.x
	b.ex = maxf(ex, src.x + 1.0)
	b.y = src.y
	b.x = (b.sx + b.ex) / 2.0
	b.hw = (b.ex - b.sx) / 2.0
	b.wall = ex < far


## Thickness of a laser line over its life: a flash as it opens, then it narrows away.
static func line_fade(t: int, life: int) -> float:
	var f := 1.0 + maxf(0.0, 3.0 - t) * 0.15
	return f * clampf((life - t) / 8.0, 0.0, 1.0)


func sync_line(b: Dictionary) -> void:
	var p: Dictionary = b.parts
	var len: float = b.ex - b.sx
	var f := line_fade(b.t, b.life)
	var hh: float = b.hh
	var wide: float = [1.0, 1.0, 0.8, 0.6, 0.45][b.lv]  # slimmer cores so the twister shows
	(b.m as Node3D).position = Vector3(X(b.sx), Y(b.y), 0)
	(p.core as Node3D).scale = Vector3(len, hh * 0.8 * wide * f + 0.01, hh * 0.8 * wide * f + 0.01)
	(p.sheath as Node3D).scale = Vector3(len, hh * 1.9 * wide * f + 0.01, hh * 1.9 * wide * f + 0.01)
	var haze: Node3D = p.haze
	haze.position = Vector3(len / 2.0, 0, -0.5)
	haze.scale = Vector3(len * 1.1, hh * 4.0 * wide * f + 0.01, 1)
	var flare: Node3D = p.flare
	var fs := hh * (4.0 + sin(b.t * 1.7)) * f + 0.01
	flare.scale = Vector3(fs * 1.3, fs, 1)
	var tip: Node3D = p.tip
	tip.visible = b.wall
	tip.position = Vector3(len, 0, 1)
	tip.scale = Vector3.ONE * (hh * 3.5 * f + 0.01)
	if p.has("pulses"):
		for j in (p.pulses as Array).size():
			var pl: Node3D = p.pulses[j]
			var i := j % PULSES
			var t: int = b.t - int(pl.get_meta("lag"))
			# slot i shows this strand's latest pulse n with n % PULSES == i
			var n: int = floori(float(t) / PULSE_GAP) - posmod(floori(float(t) / PULSE_GAP) - i, PULSES)
			var x := (t - n * PULSE_GAP) * PULSE_SPEED
			pl.visible = t >= 0 and n >= 0 and x + PULSE_LEN < len
			if not pl.visible:
				continue
			# each pulse opens up a little as it travels, spinning as it goes
			var grow: float = (0.75 + 0.35 * minf(1.0, x / 120.0)) * f * [0.0, 0.0, 0.55, 0.72, 1.0][b.lv]
			pl.position = Vector3(x, 0, 0)
			pl.scale = Vector3(1, grow, grow)
			pl.rotation.x = -b.spin


# ---------- fx ----------

func glow_fx(color: String, x3: float, y3: float, z: float, s: float, life: int, vx := 0.0, vy := 0.0, drag := 1.0, pulse := false) -> void:
	var sp := Models.glow(color, s)
	sp.position = Vector3(x3, y3, z)
	world.add_child(sp)
	fx.append({m = sp, kind = "glow", s = s, life = life, t = 0, vx = vx, vy = vy, drag = drag, pulse = pulse})


func boom(x: float, y: float, r: float, big := false) -> void:
	Diag.once("explosion")
	var n := mini(26, 4 + int(r * 1.3))
	var mats := [Models.M.part_o, Models.M.part_p, Models.M.part_w]
	for i in n:
		var m := Models.mesh(Models.geo("pt", func(): return Geo.tetra(1)), mats[i % 3], Vector3(X(x), Y(y), 0))
		m.scale = Vector3.ONE * randf_range(0.4, 1.1) * (1.6 if big else 1.0)
		world.add_child(m)
		var a := randf_range(0, TAU)
		var v := randf_range(0.3, 1.4) * (1.6 if big else 1.0)
		fx.append({m = m, kind = "part", vx = cos(a) * v, vy = sin(a) * v, vz = randf_range(-1, 1.2), life = randi_range(22, 39), t = 0, spin = randf_range(-0.3, 0.3)})
	glow_fx("fff1d0", X(x), Y(y), 3, r * 3.4, 20, 0, 0, 1, true)
	for i in mini(12, 3 + int(r / 2)):
		var a := randf_range(0, TAU)
		var v := randf_range(0.5, 1.7) * (1.4 if big else 1.0)
		glow_fx("ff4fa3" if i % 2 else "ffb547", X(x), Y(y), 2, randf_range(2.5, 5), randi_range(18, 31), cos(a) * v, sin(a) * v, 0.93)
	var fm := Models.add_mat("fff1c9", 1.0)
	var f := Models.mesh(Models.geo("fl", func(): return Geo.ico(1, 1)), fm, Vector3(X(x), Y(y), 2))
	world.add_child(f)
	fx.append({m = f, kind = "flash", r = r, life = 16, t = 0, mat = fm})


func spark(x: float, y: float) -> void:
	var m := Models.mesh(Models.geo("pt", func(): return Geo.tetra(1)), Models.M.part_c, Vector3(X(x), Y(y), 0))
	m.scale = Vector3.ONE * 0.5
	world.add_child(m)
	fx.append({m = m, kind = "part", vx = randf_range(-0.6, 0.2), vy = randf_range(-0.6, 0.6), vz = 0.0, life = 10, t = 0, spin = 0.3})


func update_fx() -> void:
	var i := fx.size() - 1
	while i >= 0:
		var f: Dictionary = fx[i]
		f.t += 1
		var m: Node3D = f.m
		var k: float = float(f.t) / f.life
		match f.kind:
			"glow":
				m.position.x += f.vx
				m.position.y += f.vy
				f.vx *= f.drag
				f.vy *= f.drag
				var sc: float = f.s * sin(minf(1.0, k * 1.25) * PI) + 0.01 if f.pulse else f.s * (1.0 - k * 0.92)
				m.scale = Vector3(sc, sc, 1)
			"flash":
				m.scale = Vector3.ONE * f.r * (0.4 + k)
				(f.mat as StandardMaterial3D).albedo_color.a = 1.0 - k
			_:
				m.position += Vector3(f.vx, f.vy, f.vz)
				f.vx *= 0.96
				f.vy *= 0.96
				m.rotation.x += f.spin
				m.rotation.y += f.spin
				if f.t > f.life * 0.6:
					m.scale *= 0.9
		if f.t >= f.life:
			m.queue_free()
			fx.remove_at(i)
		i -= 1


func clear_fx() -> void:
	for f in fx:
		f.m.queue_free()
	fx.clear()


# ---------- scoring / damage ----------

func add_score(n: int) -> void:
	G.score += n
	if G.score >= G.next_extend:
		G.lives += 1
		G.next_extend += 30000
		audio.play("oneup")
		show_banner("1 Up", "", 70)
	if G.score > hiscore:
		hiscore = G.score


func kill_e(e: Dictionary) -> void:
	e.dead = true
	add_score(e.score)
	var sh: bool = e.type in BIG
	boom(e.x, e.y, 12.0 if sh else 6.0, sh)
	audio.play("boom" if sh else "small")
	if sh:
		shake = 8.0
	if e.drop != "":
		drop_item(e.x, e.y, e.drop)


func dmg_e(e: Dictionary, d: int) -> void:
	e.hp -= d
	e.flash = 3
	if e.hp <= 0:
		kill_e(e)
	else:
		audio.play("hit")


func drop_item(x: float, y: float, k: String) -> void:
	var it := {x = x, y = y, kind = k, t = 0, hw = 4.0, hh = 4.0, dead = false}
	Diag.once("item")
	it.m = Models.item(k)
	world.add_child(it.m)
	G.items.append(it)


func kill_player() -> void:
	if not P.alive or P.inv > 0:
		return
	P.alive = false
	boom(P.x, P.y, 14, true)
	audio.play("die")
	shake = 14.0
	P.respawn = 110
	P.charge = 0
	# Losing a ship costs the power-ups: lasers back to the single shot, one speed step, and
	# the pod falls off as a P item drifting back - fly through it after respawning to get it back.
	P.laser = 0
	P.speed = maxi(0, P.speed - 1)
	# With two pods only one falls off: the second is lost for good.
	var lost: Array = pods.filter(func(p): return p.state != "none")
	if not lost.is_empty():
		drop_item(clampf(lost[0].x, 20.0, W - 10.0), clampf(lost[0].y, 12.0, PH - 12.0), "P")
		Diag.once("pod lost")
	for p in pods:
		p.state = "none"


# ---------- boss ----------

func spawn_boss() -> void:
	audio.music(wdef.boss_song)
	hud.show_boss(true, wdef.boss_name)
	Diag.once("boss " + wdef.boss)
	if wdef.boss != "bloom":
		spawn_gboss(wdef.boss)
		return
	var k := 1.0
	var petals := []
	var angles := [-2.35, -1.3, 1.3, 2.35]
	for i in 4:
		petals.append({id = uid(), a = angles[i], hp = 14 * k, max = 14 * k, alive = true, flash = 0, cd = 70 + i * 28, x = 0.0, y = 0.0})
	G.boss = {kind = "bloom", x = W + 46 + xm, y = 63.0, t = 0, bt = 0, enter = true, phase2 = false, dying = 0,
		core = {id = uid(), hp = 70 * k, max = 70 * k, flash = 0, open = false, ot = 0, lid = 0.0},
		petals = petals,
		tent = {id = uid(), n = 13, hp = 28 * k, max = 28 * k, alive = true, flash = 0, cd = 150, segs = [], drop = 0}}
	G.boss.m = Models.boss(world)


func boss_damage(part: Dictionary, d: int) -> void:
	var B: Dictionary = G.boss
	if B.kind != "bloom":
		gboss_damage(part.o, d)
		return
	match part.kind:
		"petal":
			var p: Dictionary = part.o
			p.hp -= d
			p.flash = 3
			if p.hp <= 0:
				p.alive = false
				boom(p.x, p.y, 9, true)
				audio.play("boom")
				add_score(1000)
			else:
				audio.play("hit")
		"tip":
			var T: Dictionary = B.tent
			T.hp -= d
			T.flash = 3
			if T.hp <= 0:
				T.alive = false
				boom(part.x, part.y, 9, true)
				audio.play("boom")
				add_score(2000)
			else:
				audio.play("hit")
		"core":
			var c: Dictionary = B.core
			c.hp -= d
			c.flash = 3
			audio.play("hit")
			if c.hp <= 0:
				B.dying = 1
				add_score(10000)
				for b in G.eb:
					b.m.queue_free()
				G.eb = []
				audio.play("boom")
				shake = 16.0


func update_boss() -> void:
	var B: Dictionary = G.boss
	B.t += 1
	if B.dying:
		B.dying += 1
		if B.dying % 5 == 0:
			boom(B.x + randf_range(-24, 18), B.y + randf_range(-24, 24), randf_range(6, 13), true)
		if B.dying % 16 == 0:
			audio.play("boom")
			shake = 8.0
		if B.dying == 150:
			boom(B.x, B.y, 30, true)
			shake = 22.0
			remove_boss()
			G.clear_t = 1
			add_score(G.lives * 2000)
			show_banner(("Lap Clear" if endless() else "Final Clear") if last_world() else "World Clear", wdef.clear, 280)
		return
	if B.kind != "bloom":
		update_gboss(B)
		return
	if B.enter:
		B.x -= 0.45
		if B.x <= W - 42:
			B.x = W - 42
			B.enter = false
	else:
		B.bt += 1
		B.y = 63.0 + sin(B.bt * 0.013) * 24.0
	var alive := 0
	for p in B.petals:
		var a: float = p.a + sin(B.t * 0.03) * 0.12
		p.x = B.x + cos(a) * 21.0
		p.y = B.y + sin(a) * 21.0
		if p.flash:
			p.flash -= 1
		if not p.alive:
			continue
		alive += 1
		if not B.enter:
			p.cd -= 1
			if p.cd <= 0:
				aim(p.x, p.y, 1.15)
				p.cd = 115
	var c: Dictionary = B.core
	if c.flash:
		c.flash -= 1
	if alive == 0:
		if not B.phase2:
			B.phase2 = true
			c.ot = 0
			audio.play("alarm")
		c.ot += 1
		var cyc: int = c.ot % 230
		var was: bool = c.open
		c.open = cyc > 40 and cyc < 190
		if c.open and not was:
			ring(B.x - 6, B.y, 10, 0.85)
		if c.open and cyc % 48 == 20:
			fan(B.x - 8, B.y, 1.25, 3, 0.26)
		if c.ot % 210 == 100:
			E("drifter", B.x - 16, B.y, {by = B.y, ph = 0.0, amp = 12.0, score = 0})
	elif not B.enter and B.t % 320 == 160:
		ring(B.x - 6, B.y, 7, 0.7)
	c.lid += ((1.0 if c.open else 0.0) - c.lid) * 0.15
	var T: Dictionary = B.tent
	if T.flash:
		T.flash -= 1
	var px: float = B.x - 12
	var py: float = B.y
	T.segs = []
	for i in T.n:
		var ang := PI + 0.9 * sin(B.t * 0.021 - i * 0.42) * minf(1.0, (i + 1) / 4.0)
		px += cos(ang) * 6.4
		py += sin(ang) * 6.4
		T.segs.append({id = uid(), x = px, y = py, r = maxf(2.6, 4.6 - i * 0.15)})
	if T.alive:
		var tip: Dictionary = T.segs[T.n - 1]
		if not B.enter:
			T.cd -= 1
			if T.cd <= 0:
				fan(tip.x, tip.y, 0.9, 2, 0.35)
				T.cd = 130
	else:
		T.drop += 1
		if T.drop % 6 == 0 and T.n > 0:
			var s: Dictionary = T.segs[T.n - 1]
			boom(s.x, s.y, 5)
			audio.play("small")
			T.n -= 1
	var parts := []
	for p in B.petals:
		if p.alive:
			parts.append({o = p, x = p.x, y = p.y, r = 6.0, kind = "petal"})
	for i in T.n:
		var s: Dictionary = T.segs[i]
		var is_tip: bool = T.alive and i == T.n - 1
		parts.append({o = T if is_tip else s, x = s.x, y = s.y, r = 5.0 if is_tip else s.r, kind = "tip" if is_tip else "seg"})
	parts.append({o = c, x = B.x, y = B.y, r = 13.0, kind = "core" if c.open else "shield"})
	if c.open:
		parts.append({o = c, x = B.x - 8, y = B.y, r = 7.0, kind = "core"})
	G.bparts = parts


func remove_boss() -> void:
	var u: Dictionary = G.boss.m.get_meta("u")
	G.boss.m.queue_free()
	if G.boss.kind == "bloom":
		for m in u.petals + u.stalks + u.segs + [u.tip]:
			m.queue_free()
	G.bparts = []
	hud.show_boss(false)


func sync_boss() -> void:
	var B: Dictionary = G.boss
	if B.kind != "bloom":
		sync_gboss(B)
		return
	var u: Dictionary = B.m.get_meta("u")
	B.m.position = Vector3(X(B.x), Y(B.y), 0)
	B.m.rotation.y = sin(B.t * 0.01) * 0.15
	u.core.rotation.z = B.t * 0.004
	var op: float = B.core.lid
	u.lidT.rotation.x = -op * 1.3
	u.lidB.rotation.x = PI + op * 1.3
	if P.alive:
		var dx: float = P.x - (B.x - 3)
		var dy: float = P.y - B.y
		var d := maxf(0.001, Vector2(dx, dy).length())
		u.pupil.position = Vector3(dx / d * 2.4 * op, -dy / d * 2.4 * op, lerpf(1.5, 5.0, op))
	var cf: bool = B.core.flash > 0 and B.core.open
	Models.set_flash(u.core, cf)
	Models.set_flash(u.eye, cf)
	for i in 4:
		var p: Dictionary = B.petals[i]
		var pm: Node3D = u.petals[i]
		var st: Node3D = u.stalks[i]
		pm.visible = p.alive
		st.visible = p.alive
		if not p.alive:
			continue
		var ang := atan2(-(p.y - B.y), p.x - B.x) - PI / 2.0
		pm.position = Vector3(X(p.x), Y(p.y), 2)
		pm.rotation = Vector3(0, B.t * 0.03, ang)
		var mx: float = (p.x + B.x) / 2.0
		var my: float = (p.y + B.y) / 2.0
		st.position = Vector3(X(mx), Y(my), -1)
		st.scale.y = Vector2(p.x - B.x, p.y - B.y).length()
		st.rotation.z = ang
		Models.set_flash(pm, p.flash > 0)
	var T: Dictionary = B.tent
	for i in u.segs.size():
		var m: Node3D = u.segs[i]
		var show: bool = i < T.n and not (T.alive and i == T.n - 1)
		m.visible = show
		if i < T.segs.size():
			var s: Dictionary = T.segs[i]
			m.position = Vector3(X(s.x), Y(s.y), 0)
			m.rotation = Vector3(B.t * 0.02 + i, i, 0)
	u.tip.visible = T.alive and T.n > 0
	if u.tip.visible:
		var s: Dictionary = T.segs[T.n - 1]
		u.tip.position = Vector3(X(s.x), Y(s.y), 1)
		u.tip.rotation.z = B.t * 0.05
		Models.set_flash(u.tip, T.flash > 0)
	var hp: float = B.core.hp
	var mxh: float = B.core.max
	for p in B.petals:
		hp += maxf(0.0, p.hp)
		mxh += p.max
	hp += maxf(0.0, T.hp)
	mxh += T.max
	hud.set_boss(0.0 if B.dying else clampf(hp / mxh, 0.0, 1.0) * 100.0)


# ---------- bosses of worlds 2 to 4 ----------
## These share one shape: a dictionary of parts (each with hp, a hit radius and a position
## worked out every tick). Armoured parts deflect shots; destroying the "core" part kills the
## boss. Each boss guards its core differently.

func _part(key: String, hp: float, r: float, o := {}) -> Dictionary:
	var p := {id = uid(), key = key, hp = hp, max = hp, r = r, alive = true, flash = 0, x = 0.0, y = 0.0, core = false, armour = false, cd = 0, burst = 0}
	p.merge(o, true)
	return p


func spawn_gboss(kind: String) -> void:
	var k := 1.0 + 0.1 * diff()
	var B := {kind = kind, x = W + 50 + xm, y = 63.0, t = 0, bt = 0, enter = true, phase2 = false, phase3 = false, dying = 0, lid = 0.0, open = false, parts = {}}
	var list: Array = []
	match kind:
		"prism":
			B.home = W - 44.0
			list = [_part("top", 26 * k, 7.5, {oy = -27.0, cd = 70}), _part("bot", 26 * k, 7.5, {oy = 27.0, cd = 145}),
				_part("core", 90 * k, 10.0, {core = true, armour = true})]
			B.m = Models.boss_prism(world)
		"titan":
			B.home = W - 30.0
			list = [_part("hullA", 9999, 13.0, {armour = true, oy = -12.0}), _part("hullB", 9999, 13.0, {armour = true, oy = 12.0}),
				_part("top", 30 * k, 7.0, {oy = -28.0, cd = 90}), _part("bot", 30 * k, 7.0, {oy = 28.0, cd = 150}),
				_part("core", 120 * k, 7.5, {core = true, armour = true})]
			B.m = Models.boss_titan(world)
		"queen":
			B.home = W - 48.0
			list = [_part("top", 28 * k, 9.0, {oy = -25.0, cd = 80}), _part("bot", 28 * k, 9.0, {oy = 25.0, cd = 145}),
				_part("sac", 40 * k, 11.0, {cd = 120}), _part("core", 110 * k, 8.5, {core = true, armour = true})]
			B.m = Models.boss_queen(world)
		"bastion":
			B.home = W - 44.0
			B.rot = 0.0
			for i in 4:
				list.append(_part("p%d" % i, 9999, 7.0, {armour = true, i = i}))
			for i in 4:
				list.append(_part("g%d" % i, 16 * k, 5.5, {i = i, oy = [-44.0, -22.0, 22.0, 44.0][i], cd = 60 + i * 30}))
			list.append(_part("core", 150 * k, 9.0, {core = true}))
			B.m = Models.boss_bastion(world)
		_:
			B.home = W - 56.0
			for i in 8:
				list.append(_part("n%d" % i, 10 * k, 5.0, {i = i, cd = 60 + i * 17}))
			list.append(_part("core", 160 * k, 12.0, {core = true, armour = true}))
			B.m = Models.boss_heart(world)
	for p in list:
		B.parts[p.key] = p
	B.list = list
	G.boss = B
	update_gboss(B)


func gboss_damage(p: Dictionary, d: int) -> void:
	var B: Dictionary = G.boss
	p.hp -= d
	p.flash = 3
	if p.hp > 0:
		audio.play("hit")
		return
	if p.core:
		B.dying = 1
		add_score(10000 + 5000 * int(diff()))
		for b in G.eb:
			b.m.queue_free()
		G.eb = []
		audio.play("boom")
		shake = 16.0
	else:
		p.alive = false
		boom(p.x, p.y, 9, true)
		audio.play("boom")
		shake = maxf(shake, 6.0)
		add_score(1500)


func update_gboss(B: Dictionary) -> void:
	if B.enter:
		B.x -= 0.5
		if B.x <= B.home:
			B.x = B.home
			B.enter = false
	else:
		B.bt += 1
	var P2: Dictionary = B.parts
	for p in B.list:
		if p.flash:
			p.flash -= 1
	match B.kind:
		"prism":
			if not B.enter:
				B.y = 63.0 + sin(B.bt * 0.012) * 16.0
				B.x = B.home + sin(B.bt * 0.007) * 8.0
			var guards := 0
			for key in ["top", "bot"]:
				var p: Dictionary = P2[key]
				p.x = B.x - 2.0
				p.y = B.y + p.oy * (1.0 + 0.08 * sin(B.t * 0.05))
				if not p.alive:
					continue
				guards += 1
				if B.enter:
					continue
				p.cd -= 1
				if p.cd <= 0 and p.burst == 0:
					p.burst = 5
					p.cd = 150
				if p.burst > 0 and B.t % 6 == 0:
					aim(p.x - 4, p.y, 1.7)
					p.burst -= 1
			var c: Dictionary = P2.core
			c.x = B.x
			c.y = B.y
			c.armour = guards > 0
			if guards == 0:
				if not B.phase2:
					B.phase2 = true
					audio.play("alarm")
				var cyc: int = B.t % 300
				if cyc < 130 and B.t % 7 == 0:
					var a: float = B.t * 0.11
					for j in 3:
						bullet(c.x, c.y, cos(a + j * TAU / 3.0) * 0.85 * bm(), sin(a + j * TAU / 3.0) * 0.85 * bm())
				if cyc == 200:
					fan(c.x - 8, c.y, 1.3, 5, 0.2)
				if B.t % 360 == 300:
					for j in 2:
						E("shard", c.x - 6, c.y + (j * 2 - 1) * 14.0, {stop = W - 90.0 - j * 20.0, vx = -1.6, vy = 0.0, st = 0, score = 0})
			elif not B.enter and B.t % 260 == 130:
				ring(c.x, c.y, 8, 0.7)
		"titan":
			if not B.enter:
				B.y = 63.0 + sin(B.bt * 0.01) * 14.0
			var guns := 0
			for key in ["top", "bot"]:
				var p: Dictionary = P2[key]
				p.x = B.x - 14.0
				p.y = B.y + p.oy
				if not p.alive:
					continue
				guns += 1
				if B.enter:
					continue
				p.cd -= 1
				if p.cd <= 0:
					fan(p.x - 6, p.y, 1.1, 3, 0.24)
					p.cd = 110
			for key in ["hullA", "hullB"]:
				var p: Dictionary = P2[key]
				p.x = B.x + 4.0
				p.y = B.y + p.oy
			# the furnace hatch opens on a cycle; it stays open longer once both guns are gone
			var c: Dictionary = P2.core
			c.x = B.x - 16.0
			c.y = B.y
			var cyc: int = B.t % 280
			var was: bool = B.open
			B.open = not B.enter and (cyc > 40 and cyc < 220 if guns == 0 else cyc > 70 and cyc < 180)
			c.armour = not B.open
			if B.open and not was:
				ring(c.x, c.y, 12, 0.8)
				for j in 2:
					E("drone", c.x - 4, c.y + (j * 2 - 1) * 10.0, {vx = -2.0, vy = 0.0, turn = 0, score = 0})
			if B.open and cyc % 40 == 20:
				aim(c.x - 4, c.y, 1.4)
			B.lid += ((1.0 if B.open else 0.0) - B.lid) * 0.15
		"queen":
			if not B.enter:
				B.y = 63.0 + sin(B.bt * 0.014) * 20.0
				B.x = B.home + sin(B.bt * 0.009) * 10.0
			var wings := 0
			for key in ["top", "bot"]:
				var p: Dictionary = P2[key]
				p.x = B.x + 2.0
				p.y = B.y + p.oy + sin(B.t * 0.3) * 1.5
				if not p.alive:
					continue
				wings += 1
				if B.enter:
					continue
				p.cd -= 1
				if p.cd <= 0:
					fan(p.x - 4, p.y, 1.0, 5, 0.22)
					p.cd = 130
			var sac: Dictionary = P2.sac
			sac.x = B.x + 16.0
			sac.y = B.y
			if sac.alive and not B.enter:
				sac.cd -= 1
				if sac.cd <= 0 and G.enemies.size() < 30:
					for j in 3:
						E("wasp", sac.x - 4, sac.y + (j - 1) * 10.0, {by = sac.y + (j - 1) * 10.0, ph = j * 1.1, st = 0, vx = 0.0, vy = 0.0, score = 0})
					sac.cd = 200
			var c: Dictionary = P2.core
			c.x = B.x - 14.0
			c.y = B.y
			c.armour = wings > 0
			if wings == 0:
				if not B.phase2:
					B.phase2 = true
					audio.play("alarm")
				var cyc: int = B.t % 240
				if cyc < 120 and B.t % 12 == 0:
					fan(c.x - 6, c.y, 1.4, 3, 0.18)
				if cyc == 180:
					for j in 7:
						bullet(c.x, c.y, -0.5 - j * 0.18, -1.6, 0.022)
			elif not B.enter and B.t % 240 == 200:
				aim(c.x - 6, c.y, 1.3)
		"bastion":
			if not B.enter:
				B.y = 63.0 + sin(B.bt * 0.008) * 8.0
			var guns := 0
			for i in 4:
				var p: Dictionary = P2["g%d" % i]
				p.x = B.x + 4.0
				p.y = B.y + p.oy
				if not p.alive:
					continue
				guns += 1
				if B.enter:
					continue
				p.cd -= 1
				if p.cd <= 0:
					aim(p.x - 5, p.y, 1.2)
					p.cd = 120
			B.rot += 0.03 if guns == 0 else 0.015
			for i in 4:
				var p: Dictionary = P2["p%d" % i]
				var a: float = i * TAU / 4.0 + B.rot
				p.x = B.x - 6.0 + cos(a) * 19.0
				p.y = B.y + sin(a) * 19.0
			var c: Dictionary = P2.core
			c.x = B.x - 6.0
			c.y = B.y
			if guns == 0:
				if not B.phase2:
					B.phase2 = true
					audio.play("alarm")
				var cyc: int = B.t % 200
				if cyc < 36 and cyc % 6 == 0:
					aim(c.x, c.y, 2.0)
				if cyc == 120:
					ring(c.x, c.y, 12, 0.8)
			elif not B.enter and B.t % 260 == 130:
				ring(c.x, c.y, 8, 0.7)
		_:
			var nodes := 0
			for i in 8:
				var p: Dictionary = P2["n%d" % i]
				var a: float = i * TAU / 8.0 + B.t * 0.012
				p.x = B.x + cos(a) * 26.0
				p.y = B.y + sin(a) * 26.0
				if not p.alive:
					continue
				nodes += 1
				if B.enter:
					continue
				p.cd -= 1
				if p.cd <= 0:
					aim(p.x, p.y, 1.1)
					p.cd = 150
			var c: Dictionary = P2.core
			c.armour = nodes > 0
			if nodes > 0:
				if not B.enter:
					B.y = 63.0 + sin(B.bt * 0.01) * 10.0
					if B.t % 240 == 120:
						ring(B.x, B.y, 10, 0.7)
			else:
				if not B.phase2:
					B.phase2 = true
					B.bt = 0
					audio.play("alarm")
					show_banner("Warning", "The heart is exposed", 120, true)
				if not B.phase3 and c.hp < c.max * 0.4:
					B.phase3 = true
					audio.play("alarm")
				var tx: float = B.home - 6.0 + sin(B.bt * 0.009) * 26.0
				var ty: float = 63.0 + sin(B.bt * 0.018) * 32.0
				B.x += (tx - B.x) * 0.05
				B.y += (ty - B.y) * 0.05
				var cyc: int = B.t % 260
				var arms := 3 if B.phase3 else 2
				if cyc < 150 and B.t % (5 if B.phase3 else 6) == 0:
					var a: float = B.t * 0.09
					for j in arms:
						bullet(B.x, B.y, cos(a + j * TAU / arms) * 0.8 * bm(), sin(a + j * TAU / arms) * 0.8 * bm())
				if cyc == 200:
					ring(B.x, B.y, 14, 0.75)
				if B.t % 330 == 160:
					for j in 2:
						E("seeker", B.x - 10, B.y + (j * 2 - 1) * 12.0, {vx = -1.0, vy = (j * 2 - 1) * 0.6, score = 0})
				if B.phase3 and B.t % 170 == 0:
					spawn({x = 0.0, type = "embers", n = 2})
			c.x = B.x
			c.y = B.y
	var parts := []
	for p in B.list:
		if p.alive:
			parts.append({o = p, x = p.x, y = p.y, r = p.r, kind = "shield" if p.armour else ("core" if p.core else "part")})
	G.bparts = parts


func sync_gboss(B: Dictionary) -> void:
	var u: Dictionary = B.m.get_meta("u")
	var P2: Dictionary = B.parts
	var c: Dictionary = P2.core
	var hp := 0.0
	var mx := 0.0
	for p in B.list:
		if p.max < 9999:
			hp += maxf(0.0, p.hp)
			mx += p.max
	hud.set_boss(0.0 if B.dying else clampf(hp / mx, 0.0, 1.0) * 100.0)
	match B.kind:
		"prism":
			var core: Node3D = u.core
			core.position = Vector3(X(c.x), Y(c.y), 0)
			core.rotation = Vector3(0, B.t * 0.02, sin(B.t * 0.02) * 0.2)
			Models.set_flash(core, c.flash > 0 and not c.armour)
			for key in ["top", "bot"]:
				var p: Dictionary = P2[key]
				var n: Node3D = u[key]
				var beam: Node3D = u[key + "_beam"]
				n.visible = p.alive
				beam.visible = p.alive
				n.position = Vector3(X(p.x), Y(p.y), 1)
				n.rotation.y = B.t * 0.04
				Models.set_flash(n, p.flash > 0)
				beam.position = Vector3(X((p.x + c.x) / 2.0), Y((p.y + c.y) / 2.0), -2)
				beam.scale = Vector3(1.6, absf(p.y - c.y), 1.6)
		"titan":
			var hull: Node3D = u.hull
			hull.position = Vector3(X(B.x + 4), Y(B.y), -4)
			var core: Node3D = u.core
			core.position = Vector3(X(c.x), Y(c.y), 2)
			core.rotation.z = B.t * 0.05
			Models.set_flash(core, c.flash > 0 and not c.armour)
			(u.lidT as Node3D).position = Vector3(X(c.x - 3), Y(c.y - 4.5 - B.lid * 8.0), 6)
			(u.lidB as Node3D).position = Vector3(X(c.x - 3), Y(c.y + 4.5 + B.lid * 8.0), 6)
			for key in ["top", "bot"]:
				var p: Dictionary = P2[key]
				var n: Node3D = u[key]
				n.visible = p.alive
				n.position = Vector3(X(p.x), Y(p.y), 3)
				(n.get_meta("piv") as Node3D).rotation.z = atan2(-(P.y - p.y), P.x - p.x) - PI
				Models.set_flash(n, p.flash > 0)
		"queen":
			var head: Node3D = u.core
			head.position = Vector3(X(c.x), Y(c.y), 2)
			head.rotation.y = sin(B.t * 0.03) * 0.3
			Models.set_flash(head, c.flash > 0 and not c.armour)
			var sac: Dictionary = P2.sac
			var sn: Node3D = u.sac
			sn.visible = sac.alive
			sn.position = Vector3(X(sac.x), Y(sac.y), -2)
			sn.scale = Vector3.ONE * (1.0 + sin(B.t * 0.08) * 0.05)
			Models.set_flash(sn, sac.flash > 0)
			for key in ["top", "bot"]:
				var p: Dictionary = P2[key]
				var n: Node3D = u[key]
				n.visible = p.alive
				n.position = Vector3(X(p.x), Y(B.y), 0)
				n.rotation.x = sin(B.t * 0.6) * 0.5
				Models.set_flash(n, p.flash > 0)
		"bastion":
			var core: Node3D = u.core
			core.position = Vector3(X(c.x), Y(c.y), 0)
			core.rotation.z = -B.rot * 2.0
			Models.set_flash(core, c.flash > 0)
			(u.frame as Node3D).position = Vector3(X(B.x + 10), Y(B.y), -6)
			for i in 4:
				var p: Dictionary = P2["p%d" % i]
				var pl: Node3D = u.plates[i]
				pl.position = Vector3(X(p.x), Y(p.y), 4)
				pl.rotation.z = -(i * TAU / 4.0 + B.rot)
				var g: Dictionary = P2["g%d" % i]
				var gn: Node3D = u.guns[i]
				gn.visible = g.alive
				gn.position = Vector3(X(g.x), Y(g.y), 2)
				Models.set_flash(gn, g.flash > 0)
		_:
			var core: Node3D = u.core
			core.position = Vector3(X(c.x), Y(c.y), 0)
			(u.spikes as Node3D).rotation.z = B.t * 0.01
			core.rotation.y = B.t * 0.01
			(u.shell as Node3D).visible = c.armour
			Models.set_flash(core, c.flash > 0 and not c.armour)
			for i in 8:
				var p: Dictionary = P2["n%d" % i]
				var n: Node3D = u.nodes[i]
				n.visible = p.alive
				n.position = Vector3(X(p.x), Y(p.y), 2)
				n.rotation = Vector3(B.t * 0.03, B.t * 0.02, 0)
				Models.set_flash(n, p.flash > 0)


# ---------- update ----------

static func ov(a: Dictionary, b: Dictionary) -> bool:
	return absf(a.x - b.x) < a.hw + b.hw and absf(a.y - b.y) < a.hh + b.hh


static func ov_c(a: Dictionary, p: Dictionary) -> bool:
	return absf(a.x - p.x) < a.hw + p.r and absf(a.y - p.y) < a.hh + p.r


func in_wall(x: float, y: float, pad: float) -> bool:
	var h := Worlds.heights(wdef, G.scroll + x)
	if y < h.x - 1.0 + pad or y > PH - h.y + 1.0 - pad:
		return true
	return not gate_at(x, y, pad).is_empty()


func step() -> void:
	G.t += 1
	if G.t % 60 == 0:
		Diag.note("TICK", "t=%d scroll=%d fps=%d nodes=%d objs=%d mem=%.0fMB vmem=%.0fMB draws=%d enemies=%d fx=%d" % [G.t, G.scroll,
			Engine.get_frames_per_second(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT),
			OS.get_static_memory_usage() / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), G.enemies.size(), fx.size()])
	if G.scroll < boss_at():
		G.scroll = minf(boss_at(), G.scroll + 0.5)
	while G.si < script_list.size() and script_list[G.si].x <= G.scroll + W + 8 + xm:
		spawn(script_list[G.si])
		G.si += 1
	for g in G.gates:
		update_gate(g)
	if not G.warned and G.scroll >= boss_at() - 100:
		G.warned = true
		G.warn_t = 200
		audio.music("")
		audio.play("alarm")
		show_banner("Warning", wdef.boss_name + " approaching", 200, true)
	if G.warn_t > 0:
		G.warn_t -= 1
		if G.warn_t == 0:
			spawn_boss()

	# player
	var tp := hud.touch
	if not P.alive:
		P.respawn -= 1
		if P.respawn <= 0:
			if G.lives <= 0:
				game_over()
				return
			G.lives -= 1
			# respawn on the corridor centre: in a tunnel or fortress 63 may be inside a wall
			P.merge({alive = true, x = -10.0, y = mid_y(G.scroll + 28.0), entering = true, inv = 150, charge_held = false}, true)
			for p in pods:
				if p.state == "free":
					p.state = "return"
	else:
		if P.inv > 0:
			P.inv -= 1
		if not (P.inv > 0 and (tt >> 2) % 2):
			glow_fx("ff9a40", X(P.x - 10), Y(P.y) + randf_range(-0.4, 0.4), -0.5, randf_range(3.5, 5), 14, -0.9, 0, 0.97)
		var dy := 0.0
		if P.exiting:
			# world cleared: the ship boosts off to the right
			P.x += minf(4.0, 0.6 + (G.clear_t - 150) * 0.05)
			P.y += (63.0 - P.y) * 0.02
			P.inv = maxi(P.inv, 2)
		elif P.entering:
			P.x += 1.2
			if P.x >= 28:
				P.entering = false
		else:
			var sp: float = [1.15, 1.45, 1.75][P.speed]
			var dx := (1.0 if held("right") else 0.0) - (1.0 if held("left") else 0.0)
			dy = (1.0 if held("down") else 0.0) - (1.0 if held("up") else 0.0)
			var ax := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
			var ay := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
			if Vector2(ax, ay).length() > 0.3:
				dx = ax
				dy = ay
			elif dx and dy:
				dx *= 0.7071
				dy *= 0.7071
			if tp.stick_id != -1:
				var m := Vector2(tp.ax, tp.ay).length()
				if m > 0.12:
					dx = tp.ax / maxf(1.0, m)
					dy = tp.ay / maxf(1.0, m)
			P.x = clampf(P.x + dx * sp, 8, W - 10)
			P.y = clampf(P.y + dy * sp, 4, PH - 4)
		P.vy += (dy - P.vy) * 0.2
		if P.rapid_cd > 0:
			P.rapid_cd -= 1
		if P.exiting:
			pass
		elif hit("fire"):
			fire_shot(false)
			P.fire_hold = 0
		elif held("fire"):
			P.fire_hold += 1
			if P.fire_hold > RAPID_AFTER and P.rapid_cd <= 0 and not P.entering:
				fire_shot(true)
				P.rapid_cd = RAPID_EVERY
		else:
			P.fire_hold = 0
		var ch := held("charge")
		if ch:
			P.charge = mini(CHARGE_MAX, P.charge + 1)
			var lv := charge_lv(P.charge)
			if lv > P.ready_lv:
				P.ready_lv = lv
				audio.play("ready", lv)
				if lv == NOVA:
					Diag.once("nova ready")
					shake = maxf(shake, 3.0)
		if not ch and P.charge_held:
			var lv := charge_lv(P.charge)
			if lv:
				fire_beam(lv)
		if not ch:
			P.charge = 0
			P.ready_lv = 0
		P.charge_held = ch
		if hit("pod"):
			# one button for both pods: recall any pod in flight, otherwise launch every docked
			# pod (the front one forwards, the rear one backwards)
			var out: Array = pods.filter(func(p): return p.state == "free")
			if not out.is_empty():
				for p in out:
					p.state = "return"
				audio.play("pod")
			else:
				var launched := false
				for p in pods:
					if p.state == "front" or p.state == "back":
						p.tx = W - 56 if p.state == "front" else 12.0
						p.state = "free"
						p.grab_cd = 30
						launched = true
				if launched:
					audio.play("pod")
		if not P.exiting and (in_wall(P.x - 4, P.y, 1.5) or in_wall(P.x + 4, P.y, 1.5) or in_wall(P.x, P.y, 1.5)):
			if P.inv > 0:
				# invincible (just respawned): slide into the opening instead of dying
				var wx: float = G.scroll + P.x
				for gx in [P.x - 4, P.x, P.x + 4]:
					var g := gate_at(gx, P.y, 1.5)
					if not g.is_empty():
						P.y += clampf(g.gy - P.y, -3.0, 3.0)
						break
				P.y = clampf(P.y, ceil_h(wx) + 4, PH - floor_h(wx) - 4)
			else:
				kill_player()

	# pods
	for p in pods:
		update_pod(p)

	# player bullets
	for b in G.pb:
		if b.get("line", false):
			b.t += 1
			if b.t >= b.life or not P.alive:
				b.dead = true
				continue
			aim_line(b)
			b.spin += 0.32
			if b.wall and b.t % 4 == 0:
				spark(b.ex, b.y)
		else:
			b.x += b.vx
			b.y += b.vy
		if b.x > W + 30 + xm or b.x < -30 - xm or b.y < -10 or b.y > PH + 10:
			b.dead = true
			continue
		if not b.beam and in_wall(b.x, b.y, 0):
			b.dead = true
			spark(b.x, b.y)
			continue
		if b.get("nova", false):
			for e in G.eb:
				if not e.dead and ov(b, e):
					e.dead = true
					spark(e.x, e.y)
		for e in G.enemies:
			if e.dead or not ov(b, e):
				continue
			if b.beam:
				if not b.hits.has(e.id):
					b.hits[e.id] = true
					dmg_e(e, b.dmg)
			else:
				dmg_e(e, b.dmg)
				b.dead = true
				break
		if b.dead or not G.boss or G.boss.dying:
			continue
		for p in G.bparts:
			if not ov_c(b, p):
				continue
			var armour: bool = p.kind == "seg" or p.kind == "shield"
			if b.beam:
				if b.hits.has(p.o.id):
					continue
				b.hits[p.o.id] = true
				if armour:
					audio.play("tink")
				else:
					boss_damage(p, b.dmg)
			else:
				b.dead = true
				if armour:
					spark(b.x, b.y)
					audio.play("tink")
				else:
					boss_damage(p, b.dmg)
				break

	# enemies
	for e in G.enemies:
		if e.dead:
			continue
		e.t += 1
		if e.flash:
			e.flash -= 1
		match e.type:
			"drifter":
				e.x -= 1.0
				e.ph += 0.07
				e.y = e.by + sin(e.ph) * e.amp
				if G.world >= 2 and e.t % 140 == 70:
					aim(e.x, e.y, 1)
			"turret", "gun":
				e.x = e.wx - G.scroll
				if e.has("my"):
					e.y = e.my
				else:
					e.y = ceil_h(e.wx) + 3 if e.side else PH - floor_h(e.wx) - 3
				if e.x > 14 and e.x < W - 6 and e.t % e.rate == e.rate - 1:
					if e.type == "gun" and e.t % (e.rate * 2) == e.rate * 2 - 1:
						fan(e.x, e.y + (2.0 if e.side else -2.0), 1.0, 3, 0.25)
					else:
						aim(e.x, e.y + (2.0 if e.side else -2.0), 1.05)
			"block":
				e.x = e.wx - G.scroll
			"generator":
				e.x = e.wx - G.scroll
				e.y = e.my
			"spitter":
				# wall pod: lobs three arcing blobs at the ship
				e.x = e.wx - G.scroll
				e.y = ceil_h(e.wx) + 3.5 if e.side else PH - floor_h(e.wx) - 3.5
				if e.x > 16 and e.x < W - 6 and e.t % 130 == 90 and P.alive:
					var dx: float = P.x - e.x
					var up := -1.4 if not e.side else 0.2
					for k in 3:
						bullet(e.x, e.y, clampf(dx / 80.0, -1.2, 1.2) + (k - 1) * 0.25, up, 0.022)
			"wasp":
				# buzzes in on a zigzag, then dives at the ship once
				if e.st == 0:
					e.x -= 1.5
					e.y = e.by + sin(e.t * 0.12 + e.ph) * 9.0
					if e.t == 50 + int(e.ph * 6.0) and P.alive:
						var a := atan2(P.y - e.y, P.x - e.x)
						e.vx = cos(a) * 2.2
						e.vy = sin(a) * 2.2
						e.st = 1
				else:
					e.x += e.vx
					e.y += e.vy
			"lancer":
				# appears at the right edge, holds while it lines up with the ship, then dashes
				match e.st:
					0:
						e.x = lerpf(e.x, W - 14.0 + xm, 0.1)
						if P.alive:
							e.y += clampf(P.y - e.y, -0.9, 0.9) if e.t > 1 else (P.y - e.y)
						if e.t >= e.hold:
							e.st = 1
							e.t = 0
					1:
						if e.t > 24:
							e.st = 2
							Diag.once("lancer dash")
					_:
						e.vx = maxf(-4.2, e.vx - 0.3)
						e.x += e.vx
			"piston":
				# slams out of the wall, holds, pulls back; the hitbox is rod + head
				e.x = e.wx - G.scroll
				var h := ceil_h(e.wx) if e.side else floor_h(e.wx)
				var room := PH - ceil_h(e.wx) - floor_h(e.wx)
				var k := clampf(sin(e.t * 0.035 + e.ph) * 1.6, 0.0, 1.0)
				e.ext = k * room * 0.52
				var wall: float = h if e.side else PH - h
				var sg := 1.0 if e.side else -1.0
				e.hh = 3.0 + e.ext / 2.0
				e.y = wall + sg * (e.hh - 1.0)
			"icicle":
				e.x = e.wx - G.scroll
				if not e.falling:
					e.y = ceil_h(e.wx) + 4.0
					if P.alive and absf(P.x - e.x) < 24.0 and P.y > e.y and e.x > P.x - 6.0:
						e.falling = true
						Diag.once("icicle drop")
				else:
					e.vy = minf(3.2, e.vy + 0.09)
					e.y += e.vy
					if e.y > PH - floor_h(e.wx) - 3.0:
						e.dead = true
						boom(e.x, e.y, 4)
						audio.play("tink")
			"shard":
				# glide in, stop, lock on, lunge
				match e.st:
					0:
						e.x += e.vx
						e.vx = minf(-0.3, e.vx * 0.985)
						if e.x <= e.stop:
							e.st = 1
							e.t = 0
					1:
						if e.t == 36:
							var a := atan2(P.y - e.y, P.x - e.x)
							e.vx = cos(a) * 3.0
							e.vy = sin(a) * 3.0
							e.st = 2
					_:
						e.x += e.vx
						e.y += e.vy
			"flake":
				e.x -= 0.6
				e.y = e.by + sin(e.t * 0.035) * 12.0
				if e.t % 95 == 60 and e.x < W - 6:
					var o := 0.0 if int(e.t / 95.0) % 2 else PI / 4.0
					for i in 4:
						var a := o + i * PI / 2.0
						bullet(e.x, e.y, cos(a) * 0.8 * bm(), sin(a) * 0.8 * bm())
			"drone":
				# dives in fast, swerves at the ship, then peels back out to the right
				e.x += e.vx
				if e.t > 28:
					e.vx = minf(2.6, e.vx + 0.07)
					e.vy += (clampf(P.y - e.y, -1.0, 1.0) * 0.9 - e.vy) * 0.08
					if e.turn == 0:
						e.turn = 1
						if e.x < W - 10:
							aim(e.x, e.y, 1.1)
				e.y += e.vy
				if e.t > 60 and e.x > W + 12 + xm:
					e.dead = true
			"crawler":
				e.wx -= 0.25
				e.x = e.wx - G.scroll
				e.y = PH - floor_h(e.wx) - e.hh
				if e.x > 10 and e.x < W - 6 and e.t % 100 == 70:
					aim(e.x, e.y - 3.0, 1.0)
			"ember":
				e.x += e.vx
				e.vy += 0.035
				e.y += e.vy
				if e.vy > 0 and e.y > PH + 16:
					e.dead = true
			"seeker":
				var a := atan2(P.y - e.y, P.x - e.x) if P.alive and e.t < 360 else atan2(e.vy, e.vx)
				var cur_a := atan2(e.vy, e.vx)
				var turn := clampf(wrapf(a - cur_a, -PI, PI), -0.035, 0.035)
				var sp := minf(1.5, 0.9 + e.t * 0.004)
				e.vx = cos(cur_a + turn) * sp
				e.vy = sin(cur_a + turn) * sp
				e.x += e.vx
				e.y += e.vy
			"hopper":
				if e.t > 50:
					e.vx = maxf(-1.9, e.vx - 0.035)
				e.x += e.vx
				if e.t > 40:
					e.y += clampf(P.y - e.y, -0.55, 0.55)
			"carrier":
				e.x -= 0.45
				e.y = e.by + sin(e.t * 0.05) * 7.0
			"shell", "hulk", "sentinel", "nest", "bulwark":
				if e.x > W - 48 and e.stay > 0:
					e.x -= 0.6
				elif e.stay > 0:
					e.stay -= 1
					if e.type == "nest":
						if e.stay % 100 == 50 and G.enemies.size() < 40:
							for k in 3:
								E("wasp", e.x - 6, e.y + (k - 1) * 8.0, {by = e.y + (k - 1) * 8.0, ph = k * 1.3, st = 0, vx = 0.0, vy = 0.0, score = 0})
					elif e.type == "bulwark" and e.stay % 90 == 45:
						ring(e.x - 6, e.y, 8 + int(e.stay / 90.0) % 2 * 4, 0.7)
					elif e.type == "bulwark":
						pass
					elif e.stay % 70 == 35:
						if e.type == "sentinel" and e.stay % 140 == 35:
							ring(e.x - 4, e.y, 10, 0.75)
						else:
							fan(e.x - 10, e.y, 1.1, 5 if e.type == "hulk" else 3, 0.22 if e.type == "hulk" else 0.3)
				else:
					e.x -= 0.75
				e.y = e.by + sin(e.t * 0.03) * 10.0
		if e.type in FLYERS and not (e.type == "shard" and e.st == 2):
			# keep free fliers out of the rock (tunnels are narrower than the waves)
			var hv := Worlds.heights(wdef, G.scroll + e.x)
			var lo: float = hv.x + e.hh + 1.0
			var hi: float = PH - hv.y - e.hh - 1.0
			if hi > lo:
				e.y = clampf(e.y, lo, hi)
		if e.x < -26 - xm and (e.type != "hopper" or e.t > 60):
			e.dead = true
		if e.y < -40 or (e.y > PH + 40 and e.type != "ember"):
			e.dead = true
		if e.x > W + 70 + xm:
			e.dead = true
		if e.dead:
			continue
		if P.alive and ov(P, e):
			kill_player()
		for p in pods:
			if p.state != "none" and p.hit_cd <= 0 and ov(p, e) and not e.dead:
				dmg_e(e, 1)
				p.hit_cd = POD_RAM_CD

	# boss
	if G.boss:
		update_boss()
		if G.boss and not G.boss.dying:
			for p in G.bparts:
				if P.alive and Vector2(P.x - p.x, P.y - p.y).length() < p.r + 2:
					kill_player()
				for q in pods:
					if G.boss and q.state != "none" and q.hit_cd <= 0 and Vector2(q.x - p.x, q.y - p.y).length() < p.r + 3.5 and p.kind != "seg" and p.kind != "shield":
						boss_damage(p, 1)
						q.hit_cd = POD_RAM_CD + 2
		if G.clear_t:
			G.boss = null

	# enemy bullets
	for b in G.eb:
		b.vy += b.g
		b.x += b.vx
		b.y += b.vy
		if b.x < -8 - xm or b.x > W + 8 + xm or b.y < -8 or b.y > PH + 8 or in_wall(b.x, b.y, 0):
			b.dead = true
			continue
		if pods.any(func(p): return p.state != "none" and ov(b, p)):
			b.dead = true
			spark(b.x, b.y)
			continue
		if P.alive and ov(b, P):
			b.dead = true
			kill_player()

	# items
	for it in G.items:
		it.t += 1
		it.x -= 0.4
		it.y += sin(it.t * 0.08) * 0.3
		if it.x < -10 - xm:
			it.dead = true
			continue
		if P.alive and absf(it.x - P.x) < 9 and absf(it.y - P.y) < 8:
			it.dead = true
			audio.play("pick")
			add_score(200)
			if it.kind == "P":
				if pod.state == "none":
					dock_pod(pod, "back" if pod2.state == "front" else "front")
					show_banner("Pod", "Tap top right to launch or recall" if hud.touch.enabled else "Space to launch or recall", 140)
				elif pod2.state == "none":
					dock_pod(pod2, "front" if pod.state == "back" else "back")
					show_banner("Second pod", "Covers your tail · one tap launches both", 140)
					Diag.once("second pod")
				elif P.laser < 2:
					P.laser += 1
				else:
					add_score(1000)
			elif it.kind == "L":
				if P.laser < 2:
					P.laser += 1
				else:
					add_score(1000)
			elif P.speed < 2:
				P.speed += 1
			else:
				add_score(1000)

	# world clear: the ship flies off, the screen fades, the next world (or the ending) starts
	if G.clear_t:
		G.clear_t += 1
		if G.clear_t == 150 and P.alive:
			P.exiting = true
			P.charge = 0
			audio.play("pod")
		if G.clear_t == 280:
			hud.fade(true)
		if G.clear_t > 330:
			if last_world() and not endless():
				ending()
				return
			if last_world():
				# Endless: back to the first world, one lap tougher
				G.lap += 1
				G.world = 0
				Diag.note("LAP", str(G.lap + 1))
				_save()
			else:
				G.world += 1
			start_stage()
	# cull
	for k in ["pb", "eb", "enemies", "items", "gates"]:
		var arr: Array = G[k]
		var i := arr.size() - 1
		while i >= 0:
			if arr[i].dead:
				arr[i].m.queue_free()
				arr.remove_at(i)
			i -= 1


func update() -> void:
	poll_input()
	tt += 1
	if hit("mute"):
		muted = not muted
		audio.set_muted(muted)
		hud.set_muted_icon(muted)
		_save()
	match mode:
		"title":
			# main menu: left/right (or up/down) picks a mode, Enter/Fire plays it; a tap or
			# click on a mode card plays that one
			if hit("left") or hit("up"):
				hud.select_mode("normal")
			if hit("right") or hit("down"):
				hud.select_mode("endless")
			if _want_mode != "":
				hud.select_mode(_want_mode)
				new_game(0, _want_mode)
			elif hit("start") or hit("fire"):
				new_game(0, hud.selected_mode)
		"over":
			# Play/Fire continues from the world reached in Normal (score back to 0), or
			# restarts in Endless and in world 1; the Menu button goes back to the menu.
			G.over_t += 1
			update_fx()
			if G.over_t > 50 and (_want_title or hit("start") or hit("fire")):
				var w: int = 0 if endless() else G.world
				var to_title := _want_title
				teardown()
				if to_title:
					to_menu()
				else:
					Diag.note("CONTINUE", "world %d" % (w + 1))
					new_game(w)
		"end":
			G.over_t += 1
			update_fx()
			if G.over_t > 90 and (_want_title or hit("start") or hit("fire")):
				G = {}
				to_menu()
		"play":
			if paused and _want_title:
				# Menu button on the pause screen: abandon the run
				Diag.note("QUIT_RUN")
				_save()
				audio.set_paused(false)
				paused = false
				teardown()
				to_menu()
				_want_title = false
				return
			elif hit("start"):
				set_paused(not paused)
			if not paused:
				step()
				if mode != "play":
					return
				update_fx()
				if banner_t > 0:
					banner_t -= 1
					if banner_t == 0:
						hud.hide_banner()
				if hint_t > 0:
					hint_t -= 1
					if hint_t == 0:
						hud.show_hints(false)
	_want_title = false
	_want_mode = ""
	if shake > 0.0:
		shake *= 0.85


func _exit_tree() -> void:
	Diag.note("QUIT")


func _physics_process(_delta: float) -> void:
	update()


# ---------- render sync ----------

func sync_e(e: Dictionary) -> void:
	var m: Node3D = e.m
	m.position = Vector3(X(e.x), Y(e.y), 0)
	match e.type:
		"drifter":
			m.rotation = Vector3(e.t * 0.05, e.t * 0.07, 0)
		"turret", "gun", "crawler":
			(m.get_meta("piv") as Node3D).rotation.z = atan2(-(P.y - e.y), P.x - e.x)
		"shard":
			m.rotation.z = atan2(-e.vy, e.vx) - PI if e.st == 2 else (atan2(-(P.y - e.y), P.x - e.x) - PI if e.st == 1 else 0.0)
			m.rotation.x = e.t * 0.1
		"flake":
			m.rotation.z = e.t * 0.04
			m.rotation.y = sin(e.t * 0.03) * 0.4
		"drone":
			m.rotation.y = PI if e.vx > 0 else 0.0
			m.rotation.x = e.vy * 0.3
		"piston":
			var sg := 1.0 if e.side else -1.0
			var wall: float = e.y - sg * (e.hh - 1.0)
			# model origin sits on the wall; rod stretches, head rides on the tip
			m.position = Vector3(X(e.x), Y(wall), 0)
			var reach: float = e.hh * 2.0 - 2.0
			var rod: Node3D = m.get_meta("rod")
			rod.scale.y = maxf(0.1, reach)
			rod.position.y = -sg * reach / 2.0
			(m.get_meta("head") as Node3D).position.y = -sg * (reach - 1.0)
		"ember":
			m.rotation = Vector3(e.t * 0.2, e.t * 0.13, 0)
		"seeker":
			m.rotation.z = atan2(-e.vy, e.vx)
		"sentinel":
			m.rotation.y = sin(e.t * 0.02) * 0.25
			(m.get_meta("ring") as Node3D).rotation.z = e.t * 0.03
		"hulk":
			m.rotation = Vector3(0, sin(e.t * 0.02) * 0.25, sin(e.t * 0.03) * 0.1)
		"wasp":
			var wings: Array = m.get_meta("wings")
			for i in wings.size():
				wings[i].rotation.x = (0.5 + sin(e.t * 1.3) * 0.5) * (1.0 if i == 0 else -1.0)
			m.rotation = Vector3(0, PI, clampf(e.vy * 0.35, -0.7, 0.7) if e.st == 1 else sin(e.t * 0.12) * 0.3)
		"spitter":
			var bulb: Node3D = m.get_meta("bulb")
			var k := 1.0 + maxf(0.0, sin(e.t * TAU / 130.0 - 1.2)) * 0.25
			bulb.scale = Vector3(k, k, k)
		"nest":
			m.rotation = Vector3(0, sin(e.t * 0.02) * 0.4, sin(e.t * 0.05) * 0.08)
		"lancer":
			m.rotation.x = e.t * 0.08 if e.st < 2 else 0.0
			(m.get_meta("flame") as Node3D).scale = Vector3.ONE * (2.2 if e.st == 2 else (1.0 + sin(e.t * 0.6) * 0.3))
			m.rotation.y = PI
		"bulwark":
			m.rotation.y = sin(e.t * 0.02) * 0.2
		"generator":
			(m.get_meta("core") as Node3D).rotation.y = e.t * 0.08
			(m.get_meta("core") as Node3D).scale = Vector3.ONE * (1.0 + sin(e.t * 0.2) * 0.15)
		"hopper":
			m.rotation.y = PI if e.vx < 0 else 0.0
			var legs: Array = m.get_meta("legs")
			for i in legs.size():
				legs[i].rotation.x = sin(e.t * 0.4 + i + 1) * 0.5
		"carrier":
			var a := sin(e.t * 0.25) * 0.9
			var w: Array = m.get_meta("w")
			w[0].rotation.x = a
			w[1].rotation.x = -a
			m.rotation.z = sin(e.t * 0.05) * 0.15
		"shell":
			m.rotation = Vector3(0, sin(e.t * 0.02) * 0.25, sin(e.t * 0.03) * 0.1)
	Models.set_flash(m, e.flash > 0)


func _process(_delta: float) -> void:
	var sc: float = G.get("scroll", tt * 0.5)
	stars[0].position.x = -fmod(sc * 0.08, 900.0) - 450.0
	stars[1].position.x = -fmod(sc * 0.16, 900.0) - 450.0
	var drift := 0.5 if (mode == "title" or mode == "end" or G.get("scroll", 0.0) < boss_at()) else 0.15
	if paused:
		drift = 0.0
	for r in far_rocks:
		r.position.x -= drift * 0.35
		if r.position.x < -420:
			r.position.x += 840
		var spin: float = r.get_meta("spin")
		r.rotation.x += spin
		r.rotation.y += spin
	planet.rotation.y += 0.0008
	menu_ship.visible = mode == "title"
	if menu_ship.visible:
		_place_menu_ship()
	if not G.is_empty() and (mode == "play" or mode == "over"):
		update_chunks(G.scroll)
		ship.visible = P.alive and not (P.inv > 0 and (tt >> 2) % 2)
		ship.position = Vector3(X(P.x), Y(P.y), 0)
		(ship.get_meta("body") as Node3D).rotation.x = -P.vy * 0.45
		(ship.get_meta("flame") as Node3D).scale = Vector3(0.8 + randf() * 0.5, 1, 1)
		var lv := charge_lv(P.charge)
		muzzle_s.visible = P.alive and muzzle > 0
		if muzzle > 0 and not paused:
			muzzle -= 1
			muzzle_s.position = Vector3(X(P.x + 10), Y(P.y), 2)
			var ms := 5.0 + muzzle * 1.5
			muzzle_s.scale = Vector3(ms, ms, 1)
		charge_fx.visible = P.alive and P.charge > 10
		if charge_fx.visible:
			sync_charge_fx(lv)
		sync_pod(pod_m, pod)
		sync_pod(pod2_m, pod2)
		for e in G.enemies:
			sync_e(e)
		for g in G.gates:
			sync_gate(g)
		for b in G.pb:
			if b.get("line", false):
				sync_line(b)
			else:
				b.m.position = Vector3(X(b.x), Y(b.y), 0)
		for b in G.eb:
			b.m.position = Vector3(X(b.x), Y(b.y), 1)
			if not paused:
				b.m.rotation.y += 0.2
				b.m.rotation.x += 0.13
		for it in G.items:
			it.m.position = Vector3(X(it.x), Y(it.y), 0)
			if not paused:
				(it.m.get_meta("core") as Node3D).rotation.y += 0.05
		if G.boss:
			sync_boss()
		hud.update_hud(fmt(G.score), fmt(hiscore), P.laser + 1, P.speed + 1, G.lives, float(P.charge) / CHARGE_MAX, lv)
	else:
		hud.set_hi(fmt(hiscore))
	var j := Vector3.ZERO
	if shake > 0.3:
		j = Vector3(randf_range(-shake, shake), randf_range(-shake, shake), 0) * 0.25
	camera.position = CAM + j


## Test hook: jump the stage forward to world position `x`.
func warp(x: float) -> void:
	G.scroll = x
	G.si = script_list.size()
	for i in script_list.size():
		if script_list[i].x > x + W + 8 + xm:
			G.si = i
			break
