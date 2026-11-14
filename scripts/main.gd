extends Node3D
## Star Breaker: game loop. Logic runs at a fixed 60 ticks per second in "stage units"
## (a 224 x 126 playfield, y pointing down) and is mirrored onto low poly 3D models.

const W := 224.0
const PH := 126.0
const BOSS_AT := 3400.0
const CH := 64
const SAVE_PATH := "user://save.cfg"
const DEF := {drifter = [3, 3, 1, 100], turret = [4, 3.5, 3, 300], hopper = [5, 3, 2, 200], carrier = [5, 4, 5, 500], shell = [10, 7, 26, 1500]}
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
var hiscore := 0
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
var ship_glow: MeshInstance3D
var muzzle_s: MeshInstance3D
var charge_orb: MeshInstance3D
var stars: Array = []
var planet: MeshInstance3D
var far_rocks: Array = []


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


static func ramp(wx: float) -> float:
	return smooth(500, 700, wx) * (1.0 - smooth(3100, 3300, wx))


static func bump(wx: float) -> float:
	return 1.0 + 0.35 * smooth(1800, 1950, wx) * (1.0 - smooth(2350, 2500, wx))


static func ceil_h(wx: float) -> float:
	var a := ramp(wx)
	if a <= 0.0:
		return 0.0
	return a * bump(wx) * (13.0 + 7.0 * sin(wx * 0.019) + 5.0 * sin(wx * 0.051 + 1.3))


static func floor_h(wx: float) -> float:
	var a := ramp(wx)
	if a <= 0.0:
		return 0.0
	return a * bump(wx) * (13.0 + 7.0 * sin(wx * 0.017 + 2.0) + 5.0 * sin(wx * 0.043 + 0.4))


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
	script_list = build_script()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		hiscore = int(cfg.get_value("game", "best", 0))
		muted = bool(cfg.get_value("game", "muted", false))
	audio.set_muted(muted)
	hud.set_muted_icon(muted)
	hud.set_menu("title")
	if Diag.crashed:
		hud.show_crash_notice(Diag.summary(), Diag.report())
	_warm_up()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	apply_safe()


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
	pod_m = Models.pod()
	world.add_child(pod_m)
	pod_m.visible = false
	ship_glow = Models.glow("ff9a40", 9)
	ship_glow.position = Vector3(-9, 0, 0)
	ship.add_child(ship_glow)
	pod_m.add_child(Models.glow("ffb547", 10))
	muzzle_s = Models.glow("3ff0e0", 5)
	muzzle_s.visible = false
	world.add_child(muzzle_s)
	charge_orb = Models.mesh(Models.geo("orb", func(): return Geo.ico(1, 1)), Models.M.charge_orb)
	charge_orb.visible = false
	charge_orb.add_child(Models.glow("3ff0e0", 2.2))
	world.add_child(charge_orb)


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
	var list: Array = [Models.ship(), Models.pod(), Models.drifter(), Models.turret(1), Models.turret(-1), Models.hopper(), Models.shell(), flashed]
	for k in ["P", "L", "S"]:
		list.append(Models.carrier(k))
		list.append(Models.item(k))
	for k in Models.M:
		var mat = Models.M[k]
		if mat is Material:
			list.append(Models.mesh(Models.geo("pt", func(): return Geo.tetra(1)), mat))
			list.append(Models.mesh(Models.geo("bo", func(): return Geo.octa(0.5)), mat))
	for c in ["ffb547", "3ff0e0", "fff1d0", "ff4fa3", "ff9a40"]:
		list.append(Models.glow(c, 5))
	list.append(Models.mesh(Models.geo("fl", func(): return Geo.ico(1, 1)), Models.add_mat("fff1c9", 1.0)))
	for n in list:
		w.add_child(n)
	Models.set_flash(flashed, true)
	var bw := Node3D.new()
	w.add_child(bw)
	var bm := Models.boss(bw)
	Models.set_flash(bm, true)
	for i in 4:
		await get_tree().process_frame
	w.queue_free()
	Diag.note("WARM", "%d objects" % (list.size() + 1))


func _add_backdrop() -> void:
	var g := Gradient.new()
	g.set_color(0, Color("1c1046"))
	g.set_color(1, Color("071225"))
	g.add_point(0.5, Color("0c0a26"))
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

func terrain_tris(hs: Array, side: int, seed: float) -> Array:
	var sg := 1.0 if side else -1.0
	var zs := [11.0, 3.0, -9.0, -26.0]
	var rec := [0.0, 3.0, 7.0, 13.0]
	var edge := func(i: int) -> float:
		if hs[i] < 0.6:
			return sg * (PH / 2.0 + 3.0)
		return PH / 2.0 - hs[i] if side else -PH / 2.0 + hs[i]
	var pt := func(i: int, j: int) -> Vector3:
		var y: float = edge.call(i)
		var jy := (hash1(seed + i * 7.1 + j * 13.3) - 0.5) * 4.0 if j else 0.0
		var jx := (hash1(seed + i * 3.7 + j) - 0.5) * 4.0 if (j and i > 0 and i < 8) else 0.0
		return Vector3(i * 8 + jx, y + sg * (rec[j] + jy), zs[j])
	var fr := func(i: int, k: int) -> Vector3:
		var e: float = edge.call(i)
		var off: float = [0.0, 9.0, 24.0, 70.0][k]
		var j := hash1(seed + i * 5.3 + k * 2.1) if (k > 0 and k < 3) else 0.5
		var x := i * 8 + ((hash1(seed + i + k * 9.7) - 0.5) * 5.0 if (k and i > 0 and i < 8) else 0.0)
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
	for side in [0, 1]:
		var hs := []
		var mx := 0.0
		for i in 9:
			var h := ceil_h(wx0 + i * 8) if side else floor_h(wx0 + i * 8)
			hs.append(h)
			mx = maxf(mx, h)
		if mx < 0.6:
			continue
		any = true
		var mesh := Geo.build_facing(terrain_tris(hs, side, c * 31 + side * 977), Vector3(0, 0.15 if side == 0 else -0.15, 1).normalized())
		grp.add_child(Models.mesh(mesh, Models.M.rock if hash1(c + side * 5) > 0.5 else Models.M.rock2))
		for i in range(1, 8):
			if hs[i] < 5.0 or hash1(c * 17 + i * 3 + side) < 0.55:
				continue
			var h := 3.0 + hash1(c + i) * 2.5
			var sg := 1.0 if side else -1.0
			var cr := Models.mesh(Models.geo("cry", func(): return Geo.cone(1.3, 1, 4)),
					Models.M.crystal_c if hash1(c * 3 + i) > 0.5 else Models.M.crystal_m)
			cr.scale = Vector3(1, h, 1)
			if side:
				cr.rotation.z = PI
			var base: float = PH / 2.0 - hs[i] if side else -PH / 2.0 + hs[i]
			cr.position = Vector3(i * 8 + (hash1(i + c) - 0.5) * 4.0, base - sg * (h / 2.0 - 1.6), -4.0 - hash1(c * 9 + i) * 10.0)
			grp.add_child(cr)
	if not any:
		grp.free()
		return null
	world.add_child(grp)
	return grp


func update_chunks(scroll: float) -> void:
	var a := floori((scroll - 8.0 - xm) / CH)
	var b := floori((scroll + W + 8.0 + xm) / CH)
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


# ---------- script ----------

func build_script() -> Array:
	var s := []
	var add := func(x: float, type: String, o := {}) -> void:
		var d := {x = x, type = type}
		d.merge(o)
		s.append(d)
	var wave := func(x: float, y: float, n := 5, amp := 14.0) -> void:
		add.call(x, "wave", {y = y, n = n, amp = amp})
	wave.call(150, 40); wave.call(250, 86); add.call(340, "carrier", {y = 62, drop = "P"}); wave.call(430, 30); wave.call(500, 96, 6, 18)
	var k := 0
	var x := 650
	while x < 3080:
		add.call(x, "turret", {side = k % 2})
		x += 88
		k += 1
	wave.call(620, 63, 5, 24); add.call(760, "carrier", {y = 50, drop = "L"}); wave.call(840, 44); wave.call(900, 82)
	add.call(990, "shell", {y = 63}); add.call(1120, "hopper", {n = 3}); wave.call(1200, 42, 6); wave.call(1260, 86, 6)
	add.call(1380, "carrier", {y = 70, drop = "S"}); wave.call(1460, 63, 7, 24); add.call(1570, "hopper", {n = 3}); add.call(1650, "shell", {y = 46}); add.call(1720, "shell", {y = 82})
	wave.call(1830, 52); wave.call(1890, 76); add.call(1970, "carrier", {y = 63, drop = "L"}); add.call(2070, "hopper", {n = 4}); wave.call(2150, 46, 6, 14); wave.call(2210, 80, 6, 14)
	add.call(2310, "shell", {y = 63}); wave.call(2430, 63, 8, 22); add.call(2530, "carrier", {y = 58, drop = "S"}); add.call(2610, "hopper", {n = 4}); wave.call(2710, 42); wave.call(2770, 86); add.call(2840, "shell", {y = 58})
	wave.call(2960, 63, 8, 30); add.call(3060, "carrier", {y = 63, drop = "P"})
	s.sort_custom(func(a, b): return a.x < b.x)
	return s


# ---------- game flow ----------

func new_game() -> void:
	G = {score = 0, lives = 2, loop = 1, next_extend = 20000}
	P = {x = -10.0, y = 63.0, hw = 2.5, hh = 1.5, alive = true, inv = 0, entering = true, charge = 0, charge_held = false,
		rapid_cd = 0, fire_hold = 0, laser = 0, speed = 0, respawn = 0, vy = 0.0, ready_lv = 0}
	pod = {state = "none", x = 0.0, y = 0.0, hw = 3.6, hh = 3.6, tx = 0.0, grab_cd = 0, hit_cd = 0}
	Diag.note("PLAY")
	mode = "play"
	paused = false
	hud.set_menu("play")
	hud.touch.playing = true
	start_stage()
	hint_t = 480
	hud.show_hints(true)


func start_stage() -> void:
	if G.has("enemies"):
		for arr in [G.enemies, G.eb, G.pb, G.items]:
			for o in arr:
				o.m.queue_free()
	if G.get("boss"):
		remove_boss()
	clear_chunks()
	clear_fx()
	G.merge({scroll = 0.0, t = 0, si = 0, enemies = [], eb = [], pb = [], items = [], boss = null, warned = false, warn_t = 0, clear_t = 0, bparts = []}, true)
	P.merge({x = -10.0, y = 63.0, entering = true, alive = true, inv = 60, charge = 0}, true)
	if pod.state != "none":
		pod.state = "front"
	show_banner("Loop %d" % G.loop if G.loop > 1 else "Stage 1", "The Hollow Moon", 170)
	audio.music("stage")


func bm() -> float:
	return 1.0 + 0.18 * (G.loop - 1)


func game_over() -> void:
	Diag.note("GAMEOVER")
	mode = "over"
	G.over_t = 0
	audio.music("")
	_save()
	hud.set_over(fmt(G.score), fmt(hiscore))
	hud.set_menu("over")
	hud.touch.playing = false
	hud.touch.reset()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", hiscore)
	cfg.set_value("game", "muted", muted)
	cfg.save(SAVE_PATH)


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
	for arr in [G.enemies, G.eb, G.pb, G.items]:
		for o in arr:
			o.m.queue_free()
	if G.boss:
		remove_boss()
	clear_chunks()
	clear_fx()
	ship.visible = false
	pod_m.visible = false
	charge_orb.visible = false
	muzzle_s.visible = false
	hud.hide_banner()
	hud.show_hints(false)
	hud.show_boss(false)
	hint_t = 0
	G = {}


# ---------- spawning ----------

func E(type: String, x: float, y: float, o := {}) -> Dictionary:
	var d: Array = DEF[type]
	var e := {id = uid(), type = type, x = x, y = y, hw = d[0], hh = d[1], hp = ceilf(d[2] * (1.0 + 0.25 * (G.loop - 1))), score = d[3],
		t = 0, flash = 0, dead = false, drop = "", side = 0}
	e.merge(o, true)
	match type:
		"drifter": e.m = Models.drifter()
		"turret": e.m = Models.turret(e.side)
		"hopper": e.m = Models.hopper()
		"carrier": e.m = Models.carrier(e.drop)
		_: e.m = Models.shell()
	world.add_child(e.m)
	Diag.once("spawn " + type)
	G.enemies.append(e)
	sync_e(e)
	return e


func spawn(s: Dictionary) -> void:
	match s.type:
		"wave":
			for i in s.n:
				E("drifter", W + 8 + xm + i * 13, s.y, {by = s.y, ph = i * 0.6, amp = s.amp})
		"turret":
			var h := ceil_h(s.x) if s.side else floor_h(s.x)
			if h > 6.0:
				E("turret", W + 8 + xm, 0, {wx = s.x, side = s.side, rate = maxi(60, 120 - 18 * (G.loop - 1)) + int(fmod(s.x, 37.0))})
		"carrier":
			E("carrier", W + 10 + xm, s.y, {by = s.y, drop = s.drop})
		"shell":
			E("shell", W + 14 + xm, s.y, {by = s.y, stay = 260})
		"hopper":
			var y := 98.0 if P.y < 63 else 28.0
			for i in s.n:
				E("hopper", -8 - xm - i * 16, y + (8.0 if i % 2 else -8.0), {vx = 1.7})


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


func bullet(x: float, y: float, vx: float, vy: float) -> void:
	var b := {x = x, y = y, vx = vx, vy = vy, hw = 1.3, hh = 1.3, dead = false}
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
		shot(nx - 2, y, 4.6, -1.5, m, d)
		shot(nx - 2, y, 4.6, 1.5, m, d)
	if pod.state == "back":
		shot(pod.x - 4, pod.y, -5, 0, Models.M.pod_shot, 1)
	elif pod.state != "none":
		shot(pod.x + 4, pod.y, 5, 0, Models.M.pod_shot, 1)
	muzzle = 3 if rapid else 5
	audio.play("rapid" if rapid else "shot")


static func charge_lv(c: float) -> int:
	return 3 if c >= 100 else (2 if c >= 65 else (1 if c >= 35 else 0))


func fire_beam(lv: int) -> void:
	var len: float = [0.0, 14.0, 22.0, 34.0][lv]
	var hh: float = [0.0, 1.6, 2.8, 4.6][lv]
	var b := {x = P.x + 6 + len / 2.0, y = P.y, vx = 5.5, vy = 0.0, hw = len / 2.0, hh = hh, dmg = [0, 4, 9, 18][lv], beam = true, hits = {}, dead = false}
	var g := Node3D.new()
	var c := Models.mesh(Models.geo("bo", func(): return Geo.octa(0.5)), Models.M.beam)
	c.scale = Vector3(len * 1.3, hh * 1.6, hh * 1.6)
	var o := Models.mesh(Models.geo("bo", func(): return Geo.octa(0.5)), Models.M.beam_glow)
	o.scale = Vector3(len * 1.6 + 6, hh * 3, hh * 3)
	g.add_child(c)
	g.add_child(o)
	var gl := Models.glow("3ff0e0", hh * 5.0)
	gl.scale = Vector3(len * 1.4, hh * 5.0, 1)
	g.add_child(gl)
	b.m = g
	world.add_child(g)
	G.pb.append(b)
	Diag.once("beam")
	audio.play("beam", lv)
	shake = maxf(shake, lv * 2.0)


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
	var sh: bool = e.type == "shell"
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
	P.laser = maxi(0, P.laser - 1)
	if pod.state == "front" or pod.state == "back":
		pod.state = "free"
		pod.tx = pod.x


# ---------- boss ----------

func spawn_boss() -> void:
	var k: float = 1.0 + 0.3 * (G.loop - 1)
	var petals := []
	var angles := [-2.35, -1.3, 1.3, 2.35]
	for i in 4:
		petals.append({id = uid(), a = angles[i], hp = 14 * k, max = 14 * k, alive = true, flash = 0, cd = 70 + i * 28, x = 0.0, y = 0.0})
	G.boss = {x = W + 46 + xm, y = 63.0, t = 0, bt = 0, enter = true, phase2 = false, dying = 0,
		core = {id = uid(), hp = 70 * k, max = 70 * k, flash = 0, open = false, ot = 0, lid = 0.0},
		petals = petals,
		tent = {id = uid(), n = 13, hp = 28 * k, max = 28 * k, alive = true, flash = 0, cd = 150, segs = [], drop = 0}}
	Diag.once("boss")
	G.boss.m = Models.boss(world)
	audio.music("boss")
	hud.show_boss(true)


func boss_damage(part: Dictionary, d: int) -> void:
	var B: Dictionary = G.boss
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
			show_banner("Stage Clear", "Bloom Mother cut down", 280)
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
				p.cd = maxi(60, 115 - 18 * (G.loop - 1))
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
				T.cd = maxi(80, 130 - 15 * (G.loop - 1))
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
	for m in u.petals + u.stalks + u.segs + [u.tip]:
		m.queue_free()
	G.bparts = []
	hud.show_boss(false)


func sync_boss() -> void:
	var B: Dictionary = G.boss
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


# ---------- update ----------

static func ov(a: Dictionary, b: Dictionary) -> bool:
	return absf(a.x - b.x) < a.hw + b.hw and absf(a.y - b.y) < a.hh + b.hh


static func ov_c(a: Dictionary, p: Dictionary) -> bool:
	return absf(a.x - p.x) < a.hw + p.r and absf(a.y - p.y) < a.hh + p.r


func in_wall(x: float, y: float, pad: float) -> bool:
	var wx: float = G.scroll + x
	return y < ceil_h(wx) - 1.0 + pad or y > PH - floor_h(wx) + 1.0 - pad


func step() -> void:
	G.t += 1
	if G.t % 60 == 0:
		Diag.note("TICK", "t=%d scroll=%d fps=%d nodes=%d objs=%d mem=%.0fMB vmem=%.0fMB draws=%d enemies=%d fx=%d" % [G.t, G.scroll,
			Engine.get_frames_per_second(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT),
			OS.get_static_memory_usage() / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), G.enemies.size(), fx.size()])
	if G.scroll < BOSS_AT:
		G.scroll = minf(BOSS_AT, G.scroll + 0.5)
	while G.si < script_list.size() and script_list[G.si].x <= G.scroll + W + 8 + xm:
		spawn(script_list[G.si])
		G.si += 1
	if not G.warned and G.scroll >= BOSS_AT - 100:
		G.warned = true
		G.warn_t = 200
		audio.music("")
		audio.play("alarm")
		show_banner("Warning", "Bloom Mother approaching", 200, true)
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
			P.merge({alive = true, x = -10.0, y = 63.0, entering = true, inv = 150, charge_held = false}, true)
			if pod.state == "free":
				pod.state = "return"
	else:
		if P.inv > 0:
			P.inv -= 1
		if not (P.inv > 0 and (tt >> 2) % 2):
			glow_fx("ff9a40", X(P.x - 10), Y(P.y) + randf_range(-0.4, 0.4), -0.5, randf_range(3.5, 5), 14, -0.9, 0, 0.97)
		var dy := 0.0
		if P.entering:
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
		if hit("fire"):
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
			P.charge = mini(100, P.charge + 1)
			var lv := charge_lv(P.charge)
			if lv > P.ready_lv:
				P.ready_lv = lv
				audio.play("ready")
		if not ch and P.charge_held:
			var lv := charge_lv(P.charge)
			if lv:
				fire_beam(lv)
		if not ch:
			P.charge = 0
			P.ready_lv = 0
		P.charge_held = ch
		if hit("pod"):
			if pod.state == "front" or pod.state == "back":
				pod.tx = W - 56 if pod.state == "front" else 30.0
				pod.state = "free"
				pod.grab_cd = 30
				audio.play("pod")
			elif pod.state == "free":
				pod.state = "return"
				audio.play("pod")
		if in_wall(P.x - 4, P.y, 1.5) or in_wall(P.x + 4, P.y, 1.5) or in_wall(P.x, P.y, 1.5):
			if P.inv > 0:
				var wx: float = G.scroll + P.x
				P.y = clampf(P.y, ceil_h(wx) + 4, PH - floor_h(wx) - 4)
			else:
				kill_player()

	# pod
	if pod.grab_cd > 0:
		pod.grab_cd -= 1
	if pod.hit_cd > 0:
		pod.hit_cd -= 1
	match pod.state:
		"front":
			pod.x = P.x + 11
			pod.y = P.y
		"back":
			pod.x = P.x - 11
			pod.y = P.y
		"free":
			pod.x += clampf((pod.tx - pod.x) * 0.08, -3, 3)
			if P.alive:
				pod.y += (P.y - pod.y) * 0.035
		"return":
			var dx: float = P.x - pod.x
			var dyy: float = P.y - pod.y
			var d := Vector2(dx, dyy).length()
			if d > 3:
				pod.x += dx / d * 3.2
				pod.y += dyy / d * 3.2
	if (pod.state == "free" or pod.state == "return") and P.alive and not P.entering and pod.grab_cd <= 0 and Vector2(pod.x - P.x, pod.y - P.y).length() < 12:
		pod.state = "front" if pod.x >= P.x else "back"
		audio.play("dock")

	# player bullets
	for b in G.pb:
		b.x += b.vx
		b.y += b.vy
		if b.x > W + 30 + xm or b.x < -30 - xm or b.y < -10 or b.y > PH + 10:
			b.dead = true
			continue
		if not b.beam and in_wall(b.x, b.y, 0):
			b.dead = true
			spark(b.x, b.y)
			continue
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
				if G.loop > 1 and e.t % 140 == 70:
					aim(e.x, e.y, 1)
			"turret":
				e.x = e.wx - G.scroll
				e.y = ceil_h(e.wx) + 3 if e.side else PH - floor_h(e.wx) - 3
				if e.x > 14 and e.x < W - 6 and e.t % e.rate == e.rate - 1:
					aim(e.x, e.y + (2.0 if e.side else -2.0), 1.05)
			"hopper":
				if e.t > 50:
					e.vx = maxf(-1.9, e.vx - 0.035)
				e.x += e.vx
				if e.t > 40:
					e.y += clampf(P.y - e.y, -0.55, 0.55)
			"carrier":
				e.x -= 0.45
				e.y = e.by + sin(e.t * 0.05) * 7.0
			"shell":
				if e.x > W - 48 and e.stay > 0:
					e.x -= 0.6
				elif e.stay > 0:
					e.stay -= 1
					if e.stay % 70 == 35:
						fan(e.x - 10, e.y, 1.1, 3, 0.3)
				else:
					e.x -= 0.75
				e.y = e.by + sin(e.t * 0.03) * 10.0
		if e.x < -26 - xm and (e.type != "hopper" or e.t > 60):
			e.dead = true
		if e.x > W + 70 + xm:
			e.dead = true
		if e.dead:
			continue
		if P.alive and ov(P, e):
			kill_player()
		if pod.state != "none" and pod.hit_cd <= 0 and ov(pod, e):
			dmg_e(e, 2)
			pod.hit_cd = 5

	# boss
	if G.boss:
		update_boss()
		if G.boss and not G.boss.dying:
			for p in G.bparts:
				if P.alive and Vector2(P.x - p.x, P.y - p.y).length() < p.r + 2:
					kill_player()
				if pod.state != "none" and pod.hit_cd <= 0 and Vector2(pod.x - p.x, pod.y - p.y).length() < p.r + 3.5 and p.kind != "seg" and p.kind != "shield":
					boss_damage(p, 2)
					pod.hit_cd = 6
		if G.clear_t:
			G.boss = null

	# enemy bullets
	for b in G.eb:
		b.x += b.vx
		b.y += b.vy
		if b.x < -8 - xm or b.x > W + 8 + xm or b.y < -8 or b.y > PH + 8 or in_wall(b.x, b.y, 0):
			b.dead = true
			continue
		if pod.state != "none" and ov(b, pod):
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
					pod.state = "front"
					pod.x = P.x + 11
					pod.y = P.y
					show_banner("Pod", "Tap top right to launch or recall" if hud.touch.enabled else "Space to launch or recall", 140)
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

	# stage clear
	if G.clear_t:
		G.clear_t += 1
		if G.clear_t > 330:
			G.loop += 1
			start_stage()
	# cull
	for k in ["pb", "eb", "enemies", "items"]:
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
			if hit("start") or hit("fire"):
				new_game()
		"over":
			G.over_t += 1
			update_fx()
			if G.over_t > 50 and (hit("start") or hit("fire")):
				mode = "title"
				teardown()
				hud.set_menu("title")
		"play":
			if hit("start"):
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
		"turret":
			(m.get_meta("piv") as Node3D).rotation.z = atan2(-(P.y - e.y), P.x - e.x)
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
	var sc: float = G.scroll if not G.is_empty() else tt * 0.5
	stars[0].position.x = -fmod(sc * 0.08, 900.0) - 450.0
	stars[1].position.x = -fmod(sc * 0.16, 900.0) - 450.0
	var drift := 0.5 if (mode == "title" or (not G.is_empty() and G.scroll < BOSS_AT)) else 0.15
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
	if not G.is_empty() and mode != "title":
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
		charge_orb.visible = P.alive and P.charge > 14
		charge_orb.position = Vector3(X(P.x + 9), Y(P.y), 1)
		charge_orb.scale = Vector3.ONE * (0.8 + P.charge / 100.0 * 3.0) * (1.0 + sin(tt * 0.8) * 0.2 if lv == 3 else 1.0)
		pod_m.visible = pod.state != "none"
		pod_m.position = Vector3(X(pod.x), Y(pod.y), 0)
		if not paused:
			# spins around its long axis, faster in flight; turns around when docked behind
			(pod_m.get_meta("spin") as Node3D).rotation.x += 0.32 if (pod.state == "free" or pod.state == "return") else 0.09
			var face := PI if pod.state == "back" else 0.0
			pod_m.rotation.y = lerp_angle(pod_m.rotation.y, face, 0.25)
		for e in G.enemies:
			sync_e(e)
		for b in G.pb:
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
		hud.update_hud(fmt(G.score), fmt(hiscore), P.laser + 1, P.speed + 1, G.lives, P.charge, lv)
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
